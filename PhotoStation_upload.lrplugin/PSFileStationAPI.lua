--[[----------------------------------------------------------------------------

PSFileStationAPI.lua
PhotoStation FileStation primitives:
	- initialize
	- login
	- logout
	- existsPic
	- deletePic
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

]]
--------------------------------------------------------------------------------

-- Lightroom API
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrHttp = import 'LrHttp'
local LrDate = import 'LrDate'

require "PSUtilities"

--============================================================================--

PSFileStationAPI = {}

-- we can store some variables in 'global' local variables safely:
-- each export task will get its own copy of these variables

local serverUrl
local loginPath
local fileStationPath
local photoPathPrefix

---------------------- FileStation API error codes ---------------------------------------------------------
local FSAPIerrorCode = {
	[0]   = 'No error',
	[400] = 'Invalid parameter',
	[401] = 'Unknown error of file operation',
	[402] = 'System is too busy',
	[403] = 'Invalid user does this file operation',
	[404] = 'Invalid group does this file operation',
	[405] = 'Invalid user and group does this file operation',
	[406] = 'Can’t get user/group information from the account server',
	[407] = 'Operation not permitted',
	[408] = 'No such file or directory',
	[409] = 'Non-supported file system',
	[410] = 'Failed to connect internet-based file system (ex: CIFS)',
	[411] = 'Read-only file system',
	[412] = 'Filename too long in the non-encrypted file system',
	[413] = 'Filename too long in the encrypted file system',
	[414] = 'File already exists',
	[415] = 'Disk quota exceeded',
	[416] = 'No space left on device',
	[417] = 'Input/output error',
	[418] = 'Illegal name or path',
	[419] = 'Illegal file name',
	[420] = 'Illegal file name on FAT filesystem',
	[421] = 'Device or resource busy',
	[599] = 'No such task No such task of the file operation',
}

---------------------- FileStation API specific encoding routines ---------------------------------------------------------
local function FSAPIescape(str)
	if (str) then
--		writeLogfile(4, "FSAPIescape(" .. str ..")\n")
		str = string.gsub (str, ",", "\\\,")
--		writeLogfile(4, "FSAPIescape --> " .. str .."\n")
	end
	return str
end 

---------------------------------------------------------------------------------------------------------

-- initialize: set serverUrl, loginPath and fileStationPath
function PSFileStationAPI.initialize(server, personalPSOwner, loginUser)
	writeLogfile(4, "PSFileStationAPI.initialize(serverUrl=" .. server .. ")\n")

	serverUrl = 	server
	loginPath = 		'/webapi/auth.cgi'
	fileStationPath = '/webapi/FileStation'

	if personalPSOwner then -- connect to Personal PhotoStation
		-- if published by owner: use share /home/photo
		if loginUser == personalPSOwner then
			photoPathPrefix = "/home/photo/"
		else
			photoPathPrefix = "/homes/" .. personalPSOwner .. "/photo/"
		end
	else
		photoPathPrefix = "/photo/"
	end
		
	return true
end
		
---------------------------------------------------------------------------------------------------------
-- login(username, passowrd)
-- does, what it says
function PSFileStationAPI.login(username, password)
	local postHeaders = {
		{ 
			field = 'Content-Type', value = 'application/x-www-form-urlencoded' ,
		},
	}
	local postBody = 'api=SYNO.API.Auth&version=3&method=login&account=' .. 
					urlencode(username) .. '&passwd=' .. urlencode(password) .. '&session=FileStation&format=cookie' 

	writeLogfile(4, "login: LrHttp.post(" .. serverUrl .. ",...)\n")
	local respBody, respHeaders = LrHttp.post(serverUrl .. loginPath, postBody, postHeaders, 'POST', 5, string.len(postBody))
	
	if not respBody then
		writeTableLogfile(3, 'respHeaders', respHeaders)
		if respHeaders then
			return false, 'Error "' .. ifnil(respHeaders["error"].errorCode, 'Unknown') .. '" on http request:\n' .. 
					trim(ifnil(respHeaders["error"].name, 'Unknown error description'))
		else
			return false, 'Unknown error on http request"'
		end
	end
	writeLogfile(4, "Got Body:\n" .. respBody .. "\n")
	
	local respArray = JSON:decode(respBody)
	local errorCode = 0 
	if respArray.error then errorCode = tonumber(respArray.error.code) end
	
	return respArray.success, string.format('Error: %s (%d)\n', ifnil(FSAPIerrorCode[errorCode], 'Unknown error code'), errorCode)
end

---------------------------------------------------------------------------------------------------------

-- logout()
-- nothing to do here, invalidating the cookie would be perfect here
function PSFileStationAPI.logout ()
	return true
end

---------------------------------------------------------------------------------------------------------
-- existsPic(dstFilename)
function PSFileStationAPI.existsPic(dstFilename)
	local postHeaders = {
		{ field = 'Content-Type',			value = 'application/x-www-form-urlencoded' },
	}
	local apiPath = fileStationPath .. '/file_share.cgi'
	local fullPicPath = photoPathPrefix .. dstFilename
--	local postBody = 'api=SYNO.FileStation.List&version=1&method=getinfo&additional=' .. urlencode('real_path,size,time') .. '&path=' .. urlencode(FSAPIescape(fullPicPath))
	local postBody = 'api=SYNO.FileStation.List&version=1&method=getinfo&path=' .. urlencode(FSAPIescape(fullPicPath))
	
	local respBody, respHeaders = LrHttp.post(serverUrl .. apiPath, postBody, postHeaders, 'POST', 5, 0)
	
	writeLogfile(4, "picExists: LrHttp.post(" .. serverUrl .. apiPath .. ", " .. postBody .. ")\n")
	if not respBody then
		writeTableLogfile(3, 'respHeaders', respHeaders)
		if respHeaders then
			return false, 'Error "' .. ifnil(respHeaders["error"].errorCode, 'Unknown') .. '" on http request:\n' .. 
					trim(ifnil(respHeaders["error"].name, 'Unknown error description'))
		else
			return false, 'Unknown error on http request"'
		end
	end
	writeLogfile(4, "Got Body:\n" .. respBody .."\n")

	local respArray = JSON:decode(respBody)
	local errorCode = 0 
	if respArray.error then errorCode = respArray.error.code end
	
	if respArray.success and respArray.data and respArray.data.files then
		if respArray.data.files[1].name then
			return 'yes'
		elseif ifnil(respArray.data.files[1].code, 0) == 408 then
			return 'no'
		else
			errorCode = ifnil(respArray.data.files[1].code, 999)
		end
	end
	writeLogfile(3, string.format('existsPic: Error: %s (%d)\n', ifnil(FSAPIerrorCode[errorCode], 'Unknown error code'), errorCode))

	return 'error'
end

---------------------------------------------------------------------------------------------------------

-- deletePic (dstFilename) 
function PSFileStationAPI.deletePic (dstFilename) 
	local postHeaders = {
		{ field = 'Content-Type',			value = 'application/x-www-form-urlencoded' },
	}
	local apiPath = fileStationPath .. '/file_delete.cgi'
	local fullPicPath = photoPathPrefix .. dstFilename
	local postBody = 'api=SYNO.FileStation.Delete&version=1&method=delete&path=' .. urlencode(FSAPIescape(fullPicPath))
	
	local respBody, respHeaders = LrHttp.post(serverUrl .. apiPath, postBody, postHeaders, 'POST', 5, 0)
	
	writeLogfile(4, "deletePic: LrHttp.post(" .. serverUrl .. apiPath .. ", " .. postBody .. ")\n")
	if not respBody then
		writeTableLogfile(3, 'respHeaders', respHeaders)
		if respHeaders then
			return false, 'Error "' .. ifnil(respHeaders["error"].errorCode, 'Unknown') .. '" on http request:\n' .. 
					trim(ifnil(respHeaders["error"].name, 'Unknown error description'))
		else
			return false, 'Unknown error on http request"'
		end
	end
	writeLogfile(4, "Got Body:\n" .. respBody .."\n")

	local respArray = JSON:decode(respBody)
	
	if respArray.error then 
		local errorCode = respArray.error.errors[1].code 
		writeLogfile(3, string.format('deletePic: Error: %s (%d)\n', ifnil(FSAPIerrorCode[errorCode], 'Unknown error code'), errorCode))
	end

	return respArray.success
end

