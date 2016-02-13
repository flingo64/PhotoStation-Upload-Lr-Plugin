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
        					' -common_args -overwrite_original -fast2 -n -m ' ..
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

