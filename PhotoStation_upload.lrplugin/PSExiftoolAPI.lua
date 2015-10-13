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

---------------------- sendCmd ----------------------------------------------------------------------

-- function sendCmd(h, cmd, noWsConv)
-- send a command to exiftool listener by appending the command to the commandFile
local function sendCmd(h, cmd, noWsConv)
	-- all commands/parameters/options have to seperated by \n, therefore substitute whitespaces by \n 
	-- terminate command with \n 
	local cmdlines = iif(noWsConv, cmd .. "\n", string.gsub(cmd,"%s", "\n") .. "\n")
	writeLogfile(4, "sendCmd:\n" .. cmdlines)
	
	local cmdFile = io.open(h.etCommandFile, "a")
	if not cmdFile then return false end
	
	cmdFile:write(cmdlines)
	io.close(cmdFile)
	return true;
end

 --------------------- setOverwrite ----------------------------------------------------------------------

-- function setOverwrite(h)
-- send a set overwrite original command
local function setOverwrite(h)
	local setOverwriteCmd = '-overwrite_original'
	return sendCmd(h, setOverwriteCmd)
end

---------------------- setSeperator ----------------------------------------------------------------------

-- function setSeperator(h, sep)
-- send a set seperator command to exiftool
local function setSeperator(h, sep)
	local sepCmd = "-sep ".. sep
	return sendCmd(h, sepCmd)
end

---------------------- executeCmds ----------------------------------------------------------------------

-- function executeCmds(h)
-- send a execute command to exiftool listener by appending the command to the commandFile
-- wait for the corresponding result
local function executeCmds(h)
	h.cmdNumber = h.cmdNumber + 1
	
	if not sendCmd(h, string.format("-execute%04d\n", h.cmdNumber)) then
		return nil
	end
	
	-- wait for exiftool to acknowledge the command
	local cmdResult = nil
	local startTime = LrDate.currentTime()
	local now = startTime
	local expectedResult = iif(h.cmdNumber == 1, 
								string.format(					"(.*){ready%04d}",	  			    h.cmdNumber),
								string.format("{ready%04d}[\r\n]+(.*){ready%04d}", h.cmdNumber - 1, h.cmdNumber))
								
	
	while not cmdResult  and (now < (startTime + 5)) do
		LrTasks.yield()
		if LrFileUtils.exists(h.etLogFile) and LrFileUtils.isReadable(h.etLogFile) then 
			local resultStrings
--			resultStrings = LrFileUtils.readFile(h.etLogFile) -- won't work, because file is still opened by exiftool
			local logfile = io.input (h.etLogFile)
			resultStrings = logfile:read("*a")
			io.close(logfile)
			if resultStrings then
--				writeLogfile(4, "executeCmds(): got response file contents: " .. resultStrings .. "\n")
				cmdResult = string.match(resultStrings, expectedResult) 
			end
		end
		now = LrDate.currentTime()
	end
	writeLogfile(3, string.format("executeCmds(%s, cmd %d) got:\n%s\n", h.etLogFile, h.cmdNumber, ifnil(cmdResult, '<Nil>', cmdResult)))
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

-- function queryFaceRegionList(h)
-- query <mwg-rs:RegionList> elements: Picasa and Lr store detected face regions here
local function queryFaceRegionList(h)
	return sendCmd(h, "-XMP-mwg-rs:RegionAreaH -XMP-mwg-rs:RegionAreaW -XMP-mwg-rs:RegionAreaX -XMP-mwg-rs:RegionAreaY ".. 
						  "-XMP-mwg-rs:RegionName -XMP-mwg-rs:RegionType")  
end

---------------------- insertFaceRegions -------------------------------------------------------------

-- function insertFaceRegions(h, listNames, listRectangles, sep)
-- insert <MPRI:Regions> elements: PhotoStation stores detected face regions here
local function insertFaceRegions(h, listNames, listRectangles, sep)
	local optionLine = '-XMP-MP:RegionPersonDisplayName='
	
	listNames = ifnil(listNames, {}, listNames)
	writeLogfile(3, string.format("insertFaceRegions: inserting %d names, %d areas.\n", #listNames, #listRectangles))
	for i = 1, #listNames do
		if i > 1 then optionLine = optionLine .. sep end
		optionLine = optionLine .. listNames[i]
	end
	sendCmd(h, optionLine)

	optionLine = '-XMP-MP:RegionRectangle='
	for i = 1, #listRectangles do
		if i > 1 then optionLine = optionLine .. sep end
		optionLine = optionLine .. listRectangles[i]
	end
	return sendCmd(h, optionLine, noWhitespaceConversion)
end

---------------------- queryRating ---------------------------------------------------------------

-- function queryRating(h)
-- query <xmp:Rating> element
local function queryRating(h)
	return sendCmd(h, "-XMP:Rating")  
end

---------------------- addSubject -------------------------------------------------------------

-- function addSubject(h, subject)
-- add <XMP:dc:Subject> element
local function addSubject(h, subject)
	local optionLine = '-XMP:Subject+=' .. subject
	
	writeLogfile(3, string.format("addSubject: adding '%s'.\n", subject))
	return sendCmd(h, optionLine)
end

---------------------- open -------------------------------------------------------------------------

-- function PSExiftoolAPI.open(exportParams)
-- Start exiftool listener in background: one for each export/publish thread
function PSExiftoolAPI.open(exportParams)
	local h = {} -- the handle
	
	h.exiftool = exportParams.exiftoolprog
	if not LrFileUtils.exists(h.exiftool) then 
		writeLogfile(1, "PSExiftoolAPI.open: Cannot start exifTool Listener: " .. h.exiftool .. " not found!\n")
		return false 
	end
	
	-- the commandFile and logFile must be unique for each exiftool listener
	h.etCommandFile = LrPathUtils.child(tmpdir, "ExiftoolCmds-" .. tostring(LrDate.currentTime()) .. ".txt")
	h.etLogFile = LrPathUtils.replaceExtension(h.etCommandFile, "log")

	-- open and truncate commands file
	local cmdFile = io.open(h.etCommandFile, "w")
	io.close (cmdFile)

	
	LrTasks.startAsyncTask ( function()
			-- Start exiftool in listen mode
			-- when exiftool was stopped, clean up the commandFile and logFile
        	
        	local cmdline = cmdlineQuote() .. 
        					'"' .. h.exiftool .. '" ' ..
        					'-stay_open True -e -fast2 -m -n ' .. 
        					'-@ "' .. h.etCommandFile .. '" ' ..
        					'> "' .. h.etLogFile .. '"' ..
        					cmdlineQuote()
        	local retcode
        	
        	writeLogfile(2, string.format("exiftool Listener(%s): starting ...\n", h.etCommandFile))
        	h.cmdNumber = 0
        	local exitStatus = LrTasks.execute(cmdline)
        	if exitStatus > 0 then
        		writeLogfile(1, string.format("exiftool Listener(%s): terminated with error %s!\n", h.etCommandFile, tostring(exitStatus)))
        		retcode = false
        	else
        		writeLogfile(2, string.format("exiftool Listener(%s): terminated.\n", h.etCommandFile))
        		retcode = true
        	end
        
        	LrFileUtils.delete(h.etCommandFile)
        	LrFileUtils.delete(h.etLogFile)
        	
        	return retcode
        end 
	)	
	
	return h
end

---------------------- close -------------------------------------------------------------------------

-- function PSExiftoolAPI.close(h)
-- Stop exiftool listener by sending a terminate command to its commandFile
function PSExiftoolAPI.close(h)
	if not h then return false end
	
	writeLogfile(4, "PSExiftoolAPI.close: terminating exiftool.\n")
	sendCmd(h, "-stay_open False")
	
	return true
end


---------------------- doExifTranslations -------------------------------------------------------------

-- function PSExiftoolAPI.doExifTranslations(h, photoFilename, exportParams)
-- do all configured exif adjustments
function PSExiftoolAPI.doExifTranslations(h, photoFilename, exportParams)
	if not h then return false end

	local sep = ';'		-- seperator for list elements
	
	-- ------------- query all requested exif parameters first -----
	
	if not setSeperator(h, sep)
	or (exportParams.exifXlatFaceRegions and not queryFaceRegionList(h))
	or (exportParams.exifXlatRating and not queryRating(h))
	or not sendCmd(h, photoFilename, noWhitespaceConversion)
	then
		writeLogfile(3, "PSExiftoolAPI.doExifTranslations: send query data failed\n")
		return false
	end

	local queryResults = executeCmds(h) 

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

	if not setSeperator(h, sep)
	or not setOverwrite(h)
	or (foundFaceRegions and not insertFaceRegions(h, listName, listRectangle, sep))
	or (foundRating and not addSubject(h, ratingSubject))
	or not sendCmd(h, photoFilename, noWhitespaceConversion)
	or not executeCmds(h) 
	then
		return false
	end

	return true
end