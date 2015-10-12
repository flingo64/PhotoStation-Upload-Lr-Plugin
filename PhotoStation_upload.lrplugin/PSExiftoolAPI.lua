--[[----------------------------------------------------------------------------

PSExiftoolAPI.lua
Utilities for Lightroom PhotoStation Upload
Copyright(c) 2015, Martin Messmer

exports:
	- open
	- close
	
	- doExifTranslations
	
Copyright(c) 2015, Martin Messmer

This file is part of PhotoStation Upload - Lightroom plugin.

PhotoStation Upload is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

PhotoStation Upload is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PhotoStation Upload.  If not, see <http://www.gnu.org/licenses/>.

PhotoStation Upload uses the following free software to do its job:
	- convert.exe,			see: http://www.imagemagick.org/
	- ffmpeg.exe, 			see: https://www.ffmpeg.org/
	- qt-faststart.exe, 	see: http://multimedia.cx/eggs/improving-qt-faststart/
	- exiftool.exe
]]
--------------------------------------------------------------------------------

-- Lightroom API
--local LrApplication 	= import 'LrApplication'
local LrDate 			= import 'LrDate'
local LrFileUtils 		= import 'LrFileUtils'
local LrPathUtils 		= import 'LrPathUtils'
--local LrPrefs	 		= import 'LrPrefs'
local LrTasks 			= import 'LrTasks'
--local LrView 			= import 'LrView'

require "PSUtilities"

--============================================================================--

PSExiftoolAPI = {}

local noWhitespaceConversion = true	-- do not convert whitespaces to \n 

local exiftool						-- exiftool pathname
local etCommandFile					-- exiftool command file
local etLogFile						-- exiftool log output

local cmdNumber			 			-- sequence number of last pending command

---------------------- startExiftoolListener ---------------------------------------------------------

-- function startExiftoolListener()
-- Start exiftool in listen mode
-- when exiftool was stopped, clean up the commandFile and logFile
local function startExiftoolListener()
	local cmdline = cmdlineQuote() .. 
					'"' .. exiftool .. '" ' ..
					'-stay_open True -e -fast2 -m -n ' .. 
					'-@ "' .. etCommandFile .. '" ' ..
					'> "' .. etLogFile .. '"' ..
					cmdlineQuote()
	local retcode
	
	writeLogfile(4, "startExiftoolListener: Starting task " .. cmdline .. ".\n")
	
	cmdNumber = 0
	local exitStatus = LrTasks.execute(cmdline)
	if exitStatus > 0 then
		writeLogfile(1, "exiftool Listener: terminated with error ".. tostring(exitStatus) .. "!\n")
		retcode = false
	else
		writeLogfile(2, "exiftool Listener: terminated.\n")
		retcode = true
	end

	LrFileUtils.delete(etCommandFile)
	LrFileUtils.delete(etLogFile)
	
	return retcode
end 

---------------------- sendCmd ----------------------------------------------------------------------

-- function sendCmd(cmd, noWsConv)
-- send a command to exiftool listener by appending the command to the commandFile
local function sendCmd(cmd, noWsConv)
	-- all commands/parameters/options have to seperated by \n, therefore substitute whitespaces by \n 
	-- terminate command with \n 
	local cmdlines = iif(noWsConv, cmd .. "\n", string.gsub(cmd,"%s", "\n") .. "\n")
	writeLogfile(4, "sendCmd:\n" .. cmdlines)
	
	local cmdFile = io.open(etCommandFile, "a")
	if not cmdFile then return false end
	
	cmdFile:write(cmdlines)
	io.close(cmdFile)
	return true;
end

 --------------------- setOverwrite ----------------------------------------------------------------------

-- function setOverwrite()
-- send a set overwrite original command
local function setOverwrite()
	local setOverwriteCmd = '-overwrite_original'
	return sendCmd(setOverwriteCmd)
end

---------------------- setSeperator ----------------------------------------------------------------------

-- function setSeperator(sep)
-- send a set seperator command to exiftool
local function setSeperator(sep)
	local sepCmd = "-sep ".. sep
	return sendCmd(sepCmd)
end

---------------------- executeCmds ----------------------------------------------------------------------

-- function executeCmds()
-- send a execute command to exiftool listener by appending the command to the commandFile
-- wait for the corresponding result
local function executeCmds()
	cmdNumber = cmdNumber + 1
	
	if not sendCmd(string.format("-execute%04d\n", cmdNumber)) then
		return nil
	end
	
	-- wait for exiftool to acknowledge the command
	local cmdResult = nil
	local startTime = LrDate.currentTime()
	local now = startTime
	local expectedResult = iif(cmdNumber == 1, 
								string.format(					"(.*){ready%04d}", 			   cmdNumber),
								string.format("{ready%04d}[\r\n]+(.*){ready%04d}", cmdNumber - 1, cmdNumber))
								
	
	while not cmdResult  and (now < (startTime + 5)) do
		LrTasks.yield()
		if LrFileUtils.exists(etLogFile) and LrFileUtils.isReadable(etLogFile) then 
			local resultStrings
--			resultStrings = LrFileUtils.readFile(etLogFile) -- won't work, because file is still opened by exiftool
			local logfile = io.input (etLogFile)
			resultStrings = logfile:read("*a")
			io.close(logfile)
			if resultStrings then
--				writeLogfile(4, "executeCmds(): got response file contents: " .. resultStrings .. "\n")
				cmdResult = string.match(resultStrings, expectedResult) 
			end
		end
		now = LrDate.currentTime()
	end
	writeLogfile(3, "executeCmds() got:\n" .. ifnil(cmdResult, '<Nil>', cmdResult) .. "\n")
	return cmdResult 
end

---------------------- parseResponse ----------------------------------------------------------------

-- function parseResponse(photoFilename, tag, sep)
-- parse an exiftool response for a given tag
-- 		response	- the query response
-- syntax of response is:
--		<tag>		: <value>{;<value>}
local function parseResponse(response, tag, sep)
	if (not response) then return nil end
		
	writeTableLogfile(4, tag, split(string.match(response, tag .. "%s+:%s+([^\r\n]+)"), sep))
	return split(string.match(response, tag .. "%s+:%s+([^\r\n]+)"), sep)
end 

---------------------- queryRegionList---------------------------------------------------------------

-- function queryFaceRegionList()
-- query <mwg-rs:RegionList> elements: Picasa and Lr store detected face regions here
local function queryFaceRegionList()
	return sendCmd("-XMP-mwg-rs:RegionAreaH -XMP-mwg-rs:RegionAreaW -XMP-mwg-rs:RegionAreaX -XMP-mwg-rs:RegionAreaY ".. 
						  "-XMP-mwg-rs:RegionName -XMP-mwg-rs:RegionType")  
end

---------------------- insertFaceRegions -------------------------------------------------------------

-- function insertFaceRegions(listNames, listRectangles, sep)
-- insert <MPRI:Regions> elements: PhotoStation stores detected face regions here
local function insertFaceRegions(listNames, listRectangles, sep)
	local optionLine = '-XMP-MP:RegionPersonDisplayName='
	
	listNames = ifnil(listNames, {}, listNames)
	writeLogfile(3, string.format("insertFaceRegions: inserting %d names, %d areas.\n", #listNames, #listRectangles))
	for i = 1, #listNames do
		if i > 1 then optionLine = optionLine .. sep end
		optionLine = optionLine .. listNames[i]
	end
	sendCmd(optionLine)

	optionLine = '-XMP-MP:RegionRectangle='
	for i = 1, #listRectangles do
		if i > 1 then optionLine = optionLine .. sep end
		optionLine = optionLine .. listRectangles[i]
	end
	return sendCmd(optionLine, noWhitespaceConversion)
end

---------------------- queryRating ---------------------------------------------------------------

-- function queryRating()
-- query <xmp:Rating> element
local function queryRating()
	return sendCmd("-XMP:Rating")  
end

---------------------- addSubject -------------------------------------------------------------

-- function addSubject(subject)
-- add <XMP:dc:Subject> element
local function addSubject(subject)
	local optionLine = '-XMP:Subject+=' .. subject
	
	writeLogfile(3, string.format("addSubject: adding '%s'.\n", subject))
	return sendCmd(optionLine)
end

---------------------- open -------------------------------------------------------------------------

-- function PSExiftoolAPI.open()
-- Start exiftool listener in background: one for each export/publish thread
function PSExiftoolAPI.open(exportParams)

	exiftool = exportParams.exiftoolprog
	if not LrFileUtils.exists(exiftool) then 
		writeLogfile(1, "PSExiftoolAPI.open: Cannot start exifTool Listener: " .. exiftool .. " not found!\n")
		return false 
	end
	
	-- the commandFile and logFile must be unique for each exiftool listener
	etCommandFile = LrPathUtils.child(tmpdir, "ExiftoolCmds-" .. tostring(LrDate.currentTime()) .. ".txt")
	etLogFile = LrPathUtils.replaceExtension(etCommandFile, "log")

	-- open and truncate commands file
	local cmdFile = io.open(etCommandFile, "w")
	io.close (cmdFile)

	
	LrTasks.startAsyncTask(startExiftoolListener, "ExiftoolListener")
	writeLogfile(2, "PSExiftoolAPI.open: Starting exifTool Listener w/ cmd file " .. etCommandFile .. ".\n")
	return true
end

---------------------- close -------------------------------------------------------------------------

-- function PSExiftoolAPI.close()
-- Stop exiftool listener by sending a terminate command to its commandFile
function PSExiftoolAPI.close()
	writeLogfile(4, "PSExiftoolAPI.close: terminating exiftool.\n")
	sendCmd("-stay_open False")
end


---------------------- doExifTranslations -------------------------------------------------------------

-- function PSExiftoolAPI.doExifTranslations(photoFilename, exportParams)
-- do all configured exif adjustments
function PSExiftoolAPI.doExifTranslations(photoFilename, exportParams)
	local sep = ';'		-- seperator for list elements
	
	-- ------------- query all requested exif parameters first -----
	
	if not setSeperator(sep)
	or (exportParams.exifXlatFaceRegions and not queryFaceRegionList())
	or (exportParams.exifXlatRating and not queryRating())
	or not sendCmd(photoFilename, noWhitespaceConversion)
	then
		writeLogfile(3, "PSExiftoolAPI.doExifTranslations: send query data failed\n")
		return false
	end

	local queryResults = executeCmds() 

	if not queryResults then
		writeLogfile(3, "PSExiftoolAPI.doExifTranslations: execute query data failed\n")
		return false
	end
	
	-- ------------- do all requested conversions -----------------
	
	-- Face Region translations ---------
	local foundFaceRegions = false
	local listName = {}
	local listRectangle = {}
	
	if exportParams.exifXlatFaceRegions then
		local listAreaH 	= parseResponse(queryResults, 'Region Area H', sep)	
		local listAreaW 	= parseResponse(queryResults, 'Region Area W', sep)	
		local listAreaX 	= parseResponse(queryResults, 'Region Area X', sep)	
		local listAreaY 	= parseResponse(queryResults, 'Region Area Y', sep)	
		local listAreaType	= parseResponse(queryResults, 'Region Type', sep)
		local listAreaName	= parseResponse(queryResults, 'Region Name', sep)		

		if listAreaH and listAreaW and listAreaX and listAreaY then
			for i = 1, #listAreaH do
				if not listAreaType or ifnil(listAreaType[i], 'Face') == 'Face' then
					foundFaceRegions = true 
					listRectangle[i] = string.format("%f, %f, %f, %f", 
													listAreaX[i] - (listAreaW[i] / 2),
													listAreaY[i] - (listAreaH[i] / 2),
													listAreaW[i],
													listAreaH[i]	
												)
					if listAreaName then listName[i] = listAreaName[i] end
				else
					writeLogfile(3, "PSExiftoolAPI.doExifTranslations: found non-face area: " .. listAreaType[i] .. "\n")
				end						
			end
		end
	end
	
	-- Rating translation ---------------
	local foundRating = false
	local ratingSubject = ''
	
	if exportParams.exifXlatRating then
		local ratingValue = parseResponse(queryResults, 'Rating')	

		if ratingValue then
			foundRating = true 
			writeLogfile(3, "PSExiftoolAPI.doExifTranslations: found rating: " .. ratingValue[1] .. "\n")
			for i = 1, tonumber(ratingValue[1]) do
				ratingSubject = ratingSubject .. '*'
			end
		end
	end
	
	if not foundFaceRegions
	and not foundRating
	then 
		writeLogfile(4, "PSExiftoolAPI.doExifTranslations: No exif data found for translation.\n")
		return true
	end
	
	-- ------------- write back all requested conversions -----------------

	if not setSeperator(sep)
	or not setOverwrite()
	or (foundFaceRegions and not insertFaceRegions(listName, listRectangle, sep))
	or (foundRating and not addSubject(ratingSubject))
	or not sendCmd(photoFilename, noWhitespaceConversion)
	or not executeCmds() 
	then
		return false
	end

	return true
end