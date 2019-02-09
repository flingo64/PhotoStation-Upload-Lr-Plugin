--[[----------------------------------------------------------------------------

PSExiftoolAPI.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2019, Martin Messmer

Exiftool API for Lightroom Photo StatLr

exports:
	- open
	- close
	
	- doExifTranslations
	- queryLrFaceRegionList
	- setLrFaceRegionList
	
Photo StatLr is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Photo StatLr is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Photo StatLr.  If not, see <http://www.gnu.org/licenses/>.

Photo StatLr uses the following free software to do its job:
	- convert.exe,			see: http://www.imagemagick.org/
	- ffmpeg.exe, 			see: https://www.ffmpeg.org/
	- qt-faststart.exe, 	see: http://multimedia.cx/eggs/improving-qt-faststart/
	- exiftool.exe			see: http://www.sno.phy.queensu.ca/~phil/exiftool/
]]
--------------------------------------------------------------------------------

-- Lightroom API
--local LrApplication 	= import 'LrApplication'
local LrDate 			= import 'LrDate'
local LrFileUtils 		= import 'LrFileUtils'
local LrPathUtils 		= import 'LrPathUtils'
local LrPrefs	 		= import 'LrPrefs'
local LrTasks 			= import 'LrTasks'
--local LrView 			= import 'LrView'

require "PSUtilities"

--============================================================================--

PSExiftoolAPI = {}


PSExiftoolAPI.downloadUrl = 'http://www.sno.phy.queensu.ca/~phil/exiftool/' 
PSExiftoolAPI.defaultInstallPath = iif(WIN_ENV, 
								'C:\\\Windows\\\exiftool.exe', 
								'/usr/local/bin/exiftool') 

--========================= locals =================================================================================

local noWhitespaceConversion = true	-- do not convert whitespaces to \n 
local etConfigFile = LrPathUtils.child(_PLUGIN.path, 'PSExiftool.conf')

---------------------- sendCmd ----------------------------------------------------------------------
-- function sendCmd(h, cmd, noWsConv)
-- send a command to exiftool listener by appending the command to the commandFile
local function sendCmd(h, cmd, noWsConv)
	if not h then return false end

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
								
	
	while not cmdResult  and (now < (startTime + 10)) do
		LrTasks.yield()
		if LrFileUtils.exists(h.etLogFile) and LrFileUtils.isReadable(h.etLogFile) then 
			local resultStrings
--			resultStrings = LrFileUtils.readFile(h.etLogFile) -- won't work, because file is still opened by exiftool
			local logfile = io.input (h.etLogFile)
			resultStrings = logfile:read("*a")
			io.close(logfile)
			if resultStrings then
--				writeLogfile(4, "executeCmds(): got response file contents:\n" .. resultStrings .. "\n")
				cmdResult = string.match(resultStrings, expectedResult) 
			end
		end
		now = LrDate.currentTime()
	end
	writeLogfile(3, string.format("executeCmds(%s, cmd %d) took %d secs, got:\n%s\n", h.etLogFile, h.cmdNumber, now - startTime, ifnil(cmdResult, '<Nil>', cmdResult)))
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
	
	local value = string.match(response, tag .. "%s+:%s+([^\r\n]+)")
		
	if sep then
		-- if separator given: return a table of trimmed values
		local valueList = split(value, sep)
		if valueList then
			for i = 1, #valueList do
				valueList[i] = trim(valueList[i])
			end
		end
		writeTableLogfile(4, tag, valueList)
		return valueList
	end	

	writeLogfile(4, string.format("tag: %s --> value: %s\n", tag, value))
	return value
end 

---------------------- open -------------------------------------------------------------------------

-- function PSExiftoolAPI.open(exportParams)
-- Start exiftool listener in background: one for each export/publish thread
function PSExiftoolAPI.open(exportParams)
	local prefs = LrPrefs.prefsForPlugin()
	local h = {} -- the handle
	
	h.exiftool = prefs.exiftoolprog
	if not LrFileUtils.exists(h.exiftool) then 
		writeLogfile(1, "PSExiftoolAPI.open: Cannot start exifTool Listener: " .. h.exiftool .. " not found!\n")
		return false 
	end
	
	-- the commandFile and logFile must be unique for each exiftool listener
	h.etCommandFile = LrPathUtils.child(tmpdir, "ExiftoolCmds-" .. tostring(LrDate.currentTime()) .. ".txt")
	h.etLogFile = LrPathUtils.replaceExtension(h.etCommandFile, "log")
	h.etErrLogFile = LrPathUtils.replaceExtension(h.etCommandFile, "error.log")

	-- open and truncate commands file
	local cmdFile = io.open(h.etCommandFile, "w")
	io.close (cmdFile)

	
	LrTasks.startAsyncTask ( function()
			-- Start exiftool in listen mode
			-- when exiftool was stopped, clean up the commandFile and logFile
        	
        	local cmdline = cmdlineQuote() .. 
        					'"' .. h.exiftool .. '" ' ..
        					'-config "' .. etConfigFile .. '" ' ..
        					'-stay_open True ' .. 
        					'-@ "' .. h.etCommandFile .. '" ' ..
        					' -common_args -charset filename=UTF8 -overwrite_original -fast2 -m ' ..
--        					' -common_args -charset filename=UTF8 -overwrite_original -fast2 -n -m ' ..
        					'> "'  .. h.etLogFile .. 	'" ' ..
        					'2> "' .. h.etErrLogFile .. '"' .. 
        					cmdlineQuote()
        	local retcode
        	
        	-- store all pre-configured translations 
			local i = 0
			h.exifXlat = {}
			if exportParams.exifXlatFaceRegions then
				i = i + 1 
				h.exifXlat[i] = '-RegionInfoMp<MyRegionMp'
			end
			if exportParams.exifXlatRating then
				i = i + 1 
				h.exifXlat[i] = '-XMP:Subject+<MyRatingSubject'
			end

        	writeLogfile(2, string.format("exiftool Listener(%s): starting ...\n", cmdline))
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
        	LrFileUtils.delete(h.etErrLogFile)
        	
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
-- function PSExiftoolAPI.doExifTranslations(h, photoFilename, additionalCmd)
-- do all configured exif adjustments
function PSExiftoolAPI.doExifTranslations(h, photoFilename, additionalCmd)
	if not h then return false end
	
	------------- add all pre-configured translations ------------------
	for i=1, #h.exifXlat do
		if not sendCmd(h, h.exifXlat[i]) then return false end
	end
	------------- add additional translations ------------------
	if (additionalCmd and not sendCmd(h, additionalCmd))
	
	--------------- write filename to processing queue -----------------
	or not sendCmd(h, photoFilename, noWhitespaceConversion)
	or not executeCmds(h) then
		return false
	end

	return true
end

----------------------------------------------------------------------------------
-- function queryLrFaceRegionList(h, photoFilename)
-- query <mwg-rs:RegionList> elements: Picasa and Lr store detected face regions here
function PSExiftoolAPI.queryLrFaceRegionList(h, photoFilename)

	-- if photo is RAW then get XMP info from sidecar file where Lr puts it
	if PSLrUtilities.isRAW(photoFilename) and string.upper(LrPathUtils.extension(photoFilename)) ~= 'DNG' then
		photoFilename = LrPathUtils.replaceExtension(photoFilename, 'xmp')
	end

	if not sendCmd(h, "-struct -j -ImageWidth -ImageHeight -Orientation -HasCrop -CropTop -CropLeft -CropBottom -CropRight -CropAngle -XMP-mwg-rs:RegionInfo")
	or not sendCmd(h, photoFilename, noWhitespaceConversion)
	then
		writeLogfile(3, string.format("queryLrFaceRegionList for %s failed: could not read XMP data, check if 'Automatically write changes into XMP' is set!\n",
							photoFilename))
		return nil
	end  

	local queryResults = executeCmds(h) 
	if not queryResults then
		writeLogfile(3, "PSExiftoolAPI.queryLrFaceRegionList: execute query data failed\n")
		return nil
	end
	
	local results = JSON:decode(queryResults)
	if not results or #results < 1 then
		writeLogfile(3, "PSExiftoolAPI.queryLrFaceRegionList: JSON decode of results failed\n")
		return nil
	end
	
	-- Face Region translations ---------
	local personTags = {}
	local photoDimension = {}
	
	photoDimension.width 		= results[1].ImageWidth
	photoDimension.height 		= results[1].ImageHeight
	photoDimension.orient 		= results[1].Orientation
	photoDimension.hasCrop 		= results[1].HasCrop
	photoDimension.cropTop 		= tonumber(ifnil(results[1].CropTop, 0))
	photoDimension.cropLeft		= tonumber(ifnil(results[1].CropLeft, 0))
	photoDimension.cropBottom 	= tonumber(ifnil(results[1].CropBottom, 1))
	photoDimension.cropRight	= tonumber(ifnil(results[1].CropRight, 1))
	photoDimension.cropAngle	= tonumber(ifnil(results[1].CropAngle, 0))

  	if results[1].RegionInfo and results[1].RegionInfo.RegionList and #results[1].RegionInfo.RegionList > 0 then 
		local regionList 			= results[1].RegionInfo.RegionList 
    
    	local photoRotation = string.format("%1.5f", 0)
    	if string.find(photoDimension.orient, 'Horizontal') then
    		photoRotation	= string.format("%1.5f", 0)
    	elseif string.find(photoDimension.orient, '90') then
    		photoRotation = string.format("%1.5f", math.rad(-90))
    	elseif string.find(photoDimension.orient, '180') then
    		photoRotation	= string.format("%1.5f", math.rad(180))
    	elseif string.find(photoDimension.orient, '270') then
    		photoRotation = string.format("%1.5f", math.rad(90))
    	end
    	
    	photoRotation = photoRotation + math.rad(photoDimension.cropAngle)
	
		local j = 0 
		for i = 1, #regionList do
			local region = regionList[i]
			if not region.Type or region.Type == 'Face' then
				local x, y, width, height = tonumber(region.Area.X), tonumber(region.Area.Y), tonumber(region.Area.W), tonumber(region.Area.H)
				-- check if person tag is completely within cropped photo area
				if 	((x - width / 2)  >= photoDimension.cropLeft) and
					((x + width / 2)  <= photoDimension.cropRight) and
					((y - height / 2) >= photoDimension.cropTop) and
					((y + height / 2) <= photoDimension.cropBottom) 
				then
					j = j + 1
    				local personTag = {}
    				
    				personTag.xCenter 	= (x - photoDimension.cropLeft) / (photoDimension.cropRight - photoDimension.cropLeft)  
    				personTag.yCenter 	= (y - photoDimension.cropTop) / (photoDimension.cropBottom - photoDimension.cropTop)
    				personTag.width 	= width / (photoDimension.cropRight - photoDimension.cropLeft) 
    				personTag.height 	= height / (photoDimension.cropBottom - photoDimension.cropTop)
    				personTag.rotation 	= photoRotation
    				personTag.trotation = region.Rotation
    				personTag.name 		= region.Name
    				
    				personTags[j] = personTag 
    				
    				writeLogfile(3, string.format("PSExiftoolAPI.queryLrFaceRegionList: Area '%s' --> xC:%f yC:%f, w:%f, h:%f, rot:%f, trot:%f\n", 
    												personTags[j].name,
    												personTags[j].xCenter,
    												personTags[j].yCenter,
    												personTags[j].width,
    												personTags[j].height,	
    												personTags[j].rotation,	
    												personTags[j].trotation	
    											))
    			else
    				writeLogfile(3, string.format("PSExiftoolAPI.queryLrFaceRegionList: Area '%s'(%s) was skipped (wrong type or cropped)\n", region.Name, region.Type))
    			end						
			end
		end
	end
	
	return personTags, photoDimension
end

----------------------------------------------------------------------------------
-- setLrFaceRegionList(h, srcPhoto, personTags, origPhotoDimension)
-- set <mwg-rs:RegionList> elements: Picasa and Lr store detected face regions here
function PSExiftoolAPI.setLrFaceRegionList(h, srcPhoto, personTags, origPhotoDimension)
	local photoFilename = srcPhoto:getRawMetadata('path')
	local personTagNames, personTagTypes, personTagRotations, personTagXs, personTagYs, personTagWs, personTagHs = '', '', '', '', '', '', ''
	local separator = ';'
	
	writeLogfile(3, "setLrFaceRegionList() starting...\n")
	writeTableLogfile(3, "personTags", personTags)

	-- if photo is RAW then put XMP info to sidecar file where Lr is expecting it
	if PSLrUtilities.isRAW(photoFilename) and string.upper(LrPathUtils.extension(photoFilename)) ~= 'DNG' then
		photoFilename = LrPathUtils.replaceExtension(photoFilename, 'xmp')
	end
	
	if srcPhoto:getRawMetadata('isVirtualCopy') then
		writeLogfile(3, string.format("setLrFaceRegionList for %s failed: virtual copy not supported!\n", photoFilename))
		return nil
	end
	
	for i = 1, #personTags do
		local sep = iif(i == 1, '', separator)
		
		personTagNames = personTagNames .. sep .. personTags[i].name
		personTagTypes = personTagTypes .. sep .. 'Face'
		personTagRotations = personTagRotations .. sep .. '0'

		personTagXs = personTagXs .. sep .. string.format("%1.5f", personTags[i].xCenter)
		personTagYs = personTagYs .. sep .. string.format("%1.5f", personTags[i].yCenter)
		personTagWs = personTagWs .. sep .. string.format("%1.5f", personTags[i].width)
		personTagHs = personTagHs .. sep .. string.format("%1.5f", personTags[i].height)
	end

	if not 	sendCmd(h, "-sep ".. separator)	
	or not 	sendCmd(h, "-XMP-mwg-rs:RegionAppliedToDimensionsW=" .. tostring(origPhotoDimension.width))
	or not 	sendCmd(h, "-XMP-mwg-rs:RegionAppliedToDimensionsH=" .. tostring(origPhotoDimension.height))
	or not 	sendCmd(h, "-XMP-mwg-rs:RegionAppliedToDimensionsUnit=pixel")
	-- Region Name may contain blanks: do not convert! 
	or not	sendCmd(h, "-XMP-mwg-rs:RegionName="	.. personTagNames, noWhitespaceConversion)
	or not	sendCmd(h, 
					"-XMP-mwg-rs:RegionType="		.. personTagTypes .. " " ..
					"-XMP-mwg-rs:RegionRotation="	.. personTagRotations .. " " ..
					"-XMP-mwg-rs:RegionAreaX=" 		.. personTagXs .. " " ..
					"-XMP-mwg-rs:RegionAreaY="		.. personTagYs .. " " ..
					"-XMP-mwg-rs:RegionAreaW="		.. personTagWs .. " " ..
					"-XMP-mwg-rs:RegionAreaH="		.. personTagHs
				)
	or not sendCmd(h, photoFilename, noWhitespaceConversion)
	then
		writeLogfile(3, string.format("setLrFaceRegionList for %s failed!\n", photoFilename)) 
		return nil
	end  

	return executeCmds(h)
end

