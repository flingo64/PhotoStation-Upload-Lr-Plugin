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

---------------------- http encoding routines ---------------------------------------------------------

function trim(s)
  return (string.gsub(s,"^%s*(.-)%s*$", "%1"))
end

function urlencode(str)
	if (str) then
		str = string.gsub (str, "\n", "\r\n")
		str = string.gsub (str, "([^%w ])",function (c) return string.format ("%%%02X", string.byte(c)) end)
		str = string.gsub (str, " ", "%%20")
	end
	return str
end 

function FSAPIescape(str)
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
	local postBody = 'api=SYNO.FileStation.List&version=1&method=getinfo&additional=' .. urlencode('real_path,size,time') .. '&path=' .. urlencode(FSAPIescape(fullPicPath))
	
	local respBody, respHeaders = LrHttp.post(serverUrl .. apiPath, postBody, postHeaders, 'POST', 5, 0)
	
	writeLogfile(4, "picExists: LrHttp.post(" .. serverUrl .. apiPath .. ", " .. postBody .. ")\n")
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

	if string.find(respBody, '\"success\":true', 1, true) and string.find(respBody, 'additional', 1, true) then
		return 'yes'
	elseif string.find(respBody, '\"success\":true', 1, true) and string.find(respBody, '408', 1, true) then
		return 'no'
	else
		return 'error'
	end
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

