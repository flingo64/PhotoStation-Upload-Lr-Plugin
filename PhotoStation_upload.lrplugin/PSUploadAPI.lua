--[[----------------------------------------------------------------------------

PSUploadAPI.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2017, Martin Messmer

Photo Station Upload primitives:
	- createDir
	- uploadPicFile

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

]]
--------------------------------------------------------------------------------

-- Lightroom API
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrHttp = import 'LrHttp'
-- local LrDate = import 'LrDate'

local lastPhoto

require "PSUtilities"

--====== local functions =====================================================--

---------------------------------------------------------------------------------------------------------
-- checkPSUploadAPIAnswer(funcAndParams, respHeaders, respBody)
--   returns success, errorMsg
local function checkPSUploadAPIAnswer(funcAndParams, respHeaders, respBody)
	local success, errorMsg = true, nil  

	if not respBody then
        if respHeaders then
        	errorMsg = 'Error "' .. ifnil(respHeaders["error"].errorCode, 'Unknown') .. '" on http request:\n' .. 
              				trim(ifnil(respHeaders["error"].name, 'Unknown error description'))
			writeTableLogfile(3, 'respHeaders', respHeaders)
        else
        	errorMsg = 'Unknown error on http request'
        end
	   	writeLogfile(1, string.format("%s failed: %s!\n", funcAndParams, errorMsg))
        return false, errorMsg
	end
	writeLogfile(4, "Got Body:\n" .. respBody .. "\n")	

	local respArray = JSON:decode(respBody)

	if not respArray then
		success = false
		errorMsg = PSPhotoStationUtils.getErrorMsg(1003)
 	elseif not respArray.success then
 		success = false
    	errorMsg = respArray.err_msg
 	end
 	
 	if not success then
	   	writeLogfile(1, string.format("%s failed: %s!\n", funcAndParams, errorMsg))
 	end 

	return success, errorMsg
end

--====== global functions ====================================================--

PSUploadAPI = {}


-- createFolder (h, parentDir, newDir) 
-- parentDir must exit
-- newDir may or may not exist, will be created 
function PSUploadAPI.createFolder (h, parentDir, newDir) 
	local postHeaders = {
		{ field = 'Content-Type',			value = 'application/x-www-form-urlencoded' },
		{ field = 'X-PATH', 				value = urlencode(parentDir) },
--		{ field = 'X-DUPLICATE', 			value = 'OVERWRITE' },
		{ field = 'X-DUPLICATE', 			value = 'SKIP' },
		{ field = 'X-ORIG-FNAME', 			value =  urlencode(newDir) }, 
		{ field = 'X-UPLOAD-TYPE',			value = 'FOLDER' },
	}
	local postBody = ''
	local respBody, respHeaders = LrHttp.post(h.serverUrl .. h.uploadPath, postBody, postHeaders, 'POST', h.serverTimeout, 0)
	
	writeLogfile(4, "createFolder: LrHttp.post(" .. h.serverUrl .. h.uploadPath .. ",...)\n")
	writeTableLogfile(4, 'postHeaders', postHeaders, true)
	
	return checkPSUploadAPIAnswer(string.format("PSUploadAPI.createFolder('%s', '%s')", parentDir, newDir),
									respHeaders, respBody)
end

--[[ 
uploadPictureFile(h, srcFilename, srcDateTime, dstDir, dstFilename, picType, mimeType, position) 
upload a single file to Photo Station
	srcFilename	- local path to file
	srcDateTime	- DateTimeOriginal (exposure date), only needed for the originals, not accompanying files
	dstDir		- destination album/folder (must exist)
	dstFilename - destination filename (the filename of the ORIG_FILE it belongs to
	picType		- describes the type of upload file:
		THUM_B, THUM_S, THUM_M THUM_L, THUM_XL - accompanying thumbnail
		MP4_MOB, MP4_LOW, MP4_MED, MP4_HIGH  - accompanying video in alternative resolution
		ORIG_FILE	- the original picture or video
	mimeType	- Mime type for the Http body part, not realy required but helpful in Wireshark
	position	- the chronological position of the file within the batch of uploaded files
		FIRST	- any of the thumbs should be the first
		MIDDLE	- any file except the original
		LAST	- the original file must always be the last
	The files belonging to one batch must be send in the right chronological order and tagged accordingly
]]
function PSUploadAPI.uploadPictureFile(h, srcFilename, srcDateTime, dstDir, dstFilename, picType, mimeType, position) 
	local seqOption
	local datetimeOption
	local retcode,reason
	
	local thisPhoto = dstDir .. '/' .. dstFilename
	if thisPhoto ~= lastPhoto then
		if position ~= 'FIRST' then 
			writeLogfile(1, string.format("uploadPictureFile(%s) to (%s - %s - %s) interrupts upload of %s\n", 
										LrPathUtils.leafName(srcFilename), thisPhoto, position, picType, lastPhoto))
		end
		lastPhoto = thisPhoto
	end
	
	datetimeOption = nil
	seqOption = nil
	if position == 'FIRST' then
		seqOption = 		{ field = 'X-IS-BATCH-FIRST-FILE', 	value = '1'}
	elseif position == 'LAST' then
		seqOption = 		{ field = 'X-IS-BATCH-LAST-FILE', 	value = '1'}
		datetimeOption = 	{ field = 'X-LAST-MODIFIED-TIME',	value = srcDateTime }
	end
		
	local postHeaders = {
		{ field = 'Content-Type',	value = mimeType }, 
		{ field = 'X-PATH',			value = urlencode(dstDir) },
		{ field = 'X-DUPLICATE',	value = 'OVERWRITE' },
		{ field = 'X-ORIG-FNAME',	value = urlencode(dstFilename) },
		{ field = 'X-UPLOAD-TYPE',	value = picType },
		seqOption,
		datetimeOption,
	}

	-- calculate max. upload time for LrHttp.post()
	-- we expect a minimum of 10 MBit/s upload speed --> 1.25 MByte/s
	local fileSize = LrFileUtils.fileAttributes(srcFilename).fileSize
	local timeout = math.floor(fileSize / 1250000)
	if timeout < 30 then timeout = 30 end
	
	-- string.format does not %ld, which would be required for fileSize; in case of huge files
	writeLogfile(3, string.format("uploadPictureFile: %s dstDir %s dstFn %s type %s pos %s size " .. fileSize .. " timeout %d --> %s\n", 
								srcFilename, dstDir, dstFilename, picType, position, timeout, h.serverUrl .. h.uploadPath))
	writeTableLogfile(4, 'postHeaders', postHeaders, true)

	local respBody, respHeaders
	-- MacOS issue: LrHttp.post() doesn't seem to work with callback
	if not WIN_ENV then
		-- remember: LrFileUtils.readFile() can't handle huge files, e.g videos > 2GB, at least on Windows
 		respBody, respHeaders = LrHttp.post(h.serverUrl .. h.uploadPath, LrFileUtils.readFile(srcFilename), postHeaders, 'POST', timeout, fileSize)
	else
    	-- use callback function returning 10MB chunks to feed LrHttp.post() 
    	local postFile = io.open(srcFilename, "rb")
    	if not postFile then return false, "Cannot open " .. srcFilename ..' for reading' end
        --[[ testing for MacOS
        	local respBody, respHeaders = 
        		LrHttp.post(h.serverUrl .. h.uploadPath, 
        				function ()
        --					local readBuf = postFile:read(10000000)
        					local readBuf = postFile:read(30000)
        					if readBuf then 
        						writeLogfile(4, "uploadPictureFile: postFile reader returns " .. #readBuf .. " bytes\n") 
        					else
        						writeLogfile(4, "uploadPictureFile: postFile reader returns <nil>\n") 
        					end 
        					return readBuf
        				end, 
        				postHeaders, 'POST', timeout, fileSize)
         ]]
    	respBody, respHeaders = LrHttp.post(h.serverUrl .. h.uploadPath, function () return postFile:read(10000000) end, postHeaders, 'POST', timeout, fileSize)
     	postFile:close()
	end 
	
	return checkPSUploadAPIAnswer(string.format("PSUploadAPI.uploadPictureFile('%s', '%s', '%s')", srcFilename, dstDir, dstFilename), 
									respHeaders, respBody)
end