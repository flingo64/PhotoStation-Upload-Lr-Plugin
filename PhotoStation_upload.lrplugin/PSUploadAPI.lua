--[[----------------------------------------------------------------------------

PSUploadAPI.lua
PhotoStation Upload primitives:
	- initialize
	- login
	- logout
	- createDir
	- uploadPicFile
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
]]
--------------------------------------------------------------------------------

-- Lightroom API
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrHttp = import 'LrHttp'
local LrDate = import 'LrDate'

--============================================================================--

PSUploadAPI = {}

-- we can store some variables in 'global' local variables safely:
-- each export task will get its own copy of these variables

local serverUrl
local loginPath
local uploadPath

---------------------------------------------------------------------------------------------------------

-- initialize: set serverUrl, loginPath and uploadPath
function PSUploadAPI.initialize( server, personalPSOwner)
	writeLogfile(4, "PSUploadAPI.initialize(serverUrl=" .. server ..", " .. iif(personalPSOwner, "Personal PS(" .. ifnil(personalPSOwner,"<Nil>") .. ")", "Standard PS") .. ")\n")

	serverUrl = server

	if personalPSOwner then -- connect to Personal PhotoStation
		loginPath = '/~' .. personalPSOwner .. '/blog/login.php'
		uploadPath = '/~' .. personalPSOwner .. '/photo/include/asst_file_upload.php'
	else
		loginPath = '/blog/login.php'
		uploadPath = '/photo/include/asst_file_upload.php'
	end

	return true
end
		
---------------------------------------------------------------------------------------------------------

-- login(username, passowrd)
-- does, what it says
function PSUploadAPI.login(username, password)
	local postHeaders = {
		{ 
			field = 'Content-Type', value = 'application/x-www-form-urlencoded' ,
--			field = 'Cookie', value = 'PHPSESSID=',  -- remove cookie: doesn't work
		},
	}
	local postBody = 'action=login&username=' .. urlencode(username) .. '&passwd=' .. urlencode(password)

	writeLogfile(4, "login: LrHttp.post(" .. serverUrl .. uploadPath .. ",...)\n")
	local respBody, respHeaders = LrHttp.post(serverUrl .. loginPath, postBody, postHeaders, 'POST', 5, string.len(postBody))
--	local respBody, respHeaders = LrHttp.post(serverUrl .. loginPath, postBody, nil, 'POST', 5, string.len(postBody)) -- get rid of the old cookie: doesn't work
	
	if not respBody then
		if respHeaders then
			writeLogfile(3, "LrHttp failed\n  errorCode: " .. 	trim(ifnil(respHeaders["error"].errorCode, '<Nil>')) .. 
										 "\n  name: " .. 		trim(ifnil(respHeaders["error"].name, '<Nil>')) ..
										 "\n  nativeCode: " .. 	trim(ifnil(respHeaders["error"].nativeCode, '<Nil>')) .. "\n")
			return false, 'Error "' .. ifnil(respHeaders["error"].errorCode, 'Unknown') .. '" on http request:\n' .. 
					trim(ifnil(respHeaders["error"].name, 'Unknown error description'))
		else
			writeLogfile(3, 'LrHttp failed, no Infos!\n')
			return false, 'Unknown error on http request"'
		end
	end
	writeLogfile(4, "Got Body:\n" .. respBody .. "\n")
	
--[[
	if respHeaders then
		local h
		writeLogfile(4, "Got Headers:\n")
		for h = 1, #respHeaders do
			writeLogfile(4, 'Field: ' .. respHeaders[h].field .. ' Value: ' .. respHeaders[h].value .. '\n')
		end
	else
		writeLogfile(4, "Got no Headers\n")
	end
]]

	return string.find(respBody, '\"success\":true', 1, true), 'Username or password incorrect'

end

---------------------------------------------------------------------------------------------------------

-- logout()
-- nothing to do here, invalidating the cookie would be perfect here
function PSUploadAPI.logout ()
	return true
end

---------------------------------------------------------------------------------------------------------

-- createFolder (parentDir, newDir) 
-- parentDir must exit
-- newDir may or may not exist, will be created 
function PSUploadAPI.createFolder (parentDir, newDir) 
	local postHeaders = {
		{ field = 'Content-Type',			value = 'application/x-www-form-urlencoded' },
		{ field = 'X-PATH', 				value = urlencode(parentDir) },
		{ field = 'X-DUPLICATE', 			value = 'OVERWRITE' },
		{ field = 'X-ORIG-FNAME', 			value =  urlencode(newDir) }, 
		{ field = 'X-UPLOAD-TYPE',			value = 'FOLDER' },
		{ field = 'X-IS-BATCH-LAST-FILE', 	value = '1' },
	}
	local postBody = ''
	local respBody, respHeaders = LrHttp.post(serverUrl .. uploadPath, postBody, postHeaders, 'POST', 5, 0)
	
	writeLogfile(4, "createFolder: LrHttp.post(" .. serverUrl .. uploadPath .. ",...)\n")
	if not respBody then
		if respHeaders then
			writeLogfile(3, "LrHttp failed\n  errorCode: " .. 	trim(ifnil(respHeaders["error"].errorCode, '<Nil>')) .. 
										 "\n  name: " .. 		trim(ifnil(respHeaders["error"].name, '<Nil>')) ..
										 "\n  nativeCode: " .. 	trim(ifnil(respHeaders["error"].nativeCode, '<Nil>')) .. "\n")
			return false, 'Error "' .. ifnil(respHeaders["error"].errorCode, 'Unknown') .. '" on http request:\n' .. 
					trim(ifnil(respHeaders["error"].name, 'Unknown error description'))
		else
			writeLogfile(3, 'LrHttp failed, no Infos!\n')
			return false, 'Unknown error on http request"'
		end
	end
	writeLogfile(4, "Got Body:\n" .. respBody .."\n")

--[[	
	if respHeaders then
		local h
		writeLogfile(4, "Got Headers:\n")
		for h = 1, #respHeaders do
			writeLogfile(4, 'Field: ' .. respHeaders[h].field .. ' Value: ' .. respHeaders[h].value .. '\n')
		end
	else
		writeLogfile(4, "Got no Headers\n")
	end
]]

	return string.find(respBody, '\"success\":true', 1, true)

end

---------------------------------------------------------------------------------------------------------

--[[ 
uploadPictureFile(srcFilename, srcDateTime, dstDir, dstFilename, picType, mimeType, position) 
upload a single file to PhotoStation
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
function PSUploadAPI.uploadPictureFile(srcFilename, srcDateTime, dstDir, dstFilename, picType, mimeType, position) 
	local seqOption
	local datetimeOption
	local retcode,reason
	
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

	writeLogfile(4, "uploadPictureFile: LrHttp.post(" .. serverUrl .. uploadPath .. "\n")

	local h
	writeLogfile(4, "postHeaders:\n")
	for h = 1, #postHeaders do
		writeLogfile(4, 'Field: ' .. postHeaders[h].field .. ' Value: ' .. postHeaders[h].value .. '\n')
	end

	local respBody, respHeaders = LrHttp.post(serverUrl .. uploadPath, 
								LrFileUtils.readFile(srcFilename), postHeaders, 'POST', 60, 
								LrFileUtils.fileAttributes(srcFilename).fileSize)
	
	if not respBody then
		retcode = false
		if respHeaders then
			writeLogfile(3, "LrHttp failed\n  errorCode: " .. 	trim(ifnil(respHeaders["error"].errorCode, '<Nil>')) .. 
										 "\n  name: " .. 		trim(ifnil(respHeaders["error"].name, '<Nil>')) ..
										 "\n  nativeCode: " .. 	trim(ifnil(respHeaders["error"].nativeCode, '<Nil>')) .. "\n")
			reason = 'Error "' .. ifnil(respHeaders["error"].errorCode, 'Unknown') .. '" on http request:\n' .. 
					trim(ifnil(respHeaders["error"].name, 'Unknown error description'))
		else
			writeLogfile(3, 'LrHttp failed, no Infos!\n')
			reason = 'Unknown error on http request"'
		end
	else
		writeLogfile(4, "Got Body:\n" .. respBody .. "\n")
		
--[[
		if respHeaders then
			local h
			writeLogfile(4, "Got Headers:\n")
			for h = 1, #respHeaders do
				writeLogfile(4, 'Field: ' .. respHeaders[h].field .. ' Value: ' .. respHeaders[h].value .. '\n')
			end
		else
			writeLogfile(4, "Got no Headers\n")
		end
]]

		retcode = string.find(respBody, '\"success\":true', 1, true)
		if not retcode then reason = 'Got negative response from PhotoStation' end
	end
	
	if not retcode then
		writeLogfile(1,"uploadPictureFile: " .. srcFilename .. " to " .. dstDir .. "/" .. dstFilename .. " failed!\n")
	end
	return retcode, reason
end
