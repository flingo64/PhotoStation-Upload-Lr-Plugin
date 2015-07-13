--[[----------------------------------------------------------------------------

PSUpdate.lua
PhotoStation Upload update check:
	- checkForUpdate()
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
local LrApplication 	= import 'LrApplication'
local LrDate 			= import 'LrDate'
local LrDialogs 		= import 'LrDialogs'
local LrFileUtils 		= import 'LrFileUtils'
local LrHttp 			= import 'LrHttp'
local LrLocalization 	= import'LrLocalization'
local LrMD5 			= import 'LrMD5'
local LrPathUtils 		= import 'LrPathUtils'
local LrPrefs	 		= import 'LrPrefs'
local LrSystemInfo 		= import 'LrSystemInfo'

require "Info"
require "PSUtilities"

--============================================================================--

PSUpdate = {}

-- we can store some variables in 'global' local variables safely:
-- each export task will get its own copy of these variables

local serverUrl='http://messmer-online.de/LrPSUploadCheckForUpdate.php'

---------------------------------------------------------------------------------------------------------

-- checkForUpdate: check  for updates once per day
function PSUpdate.checkForUpdate()
	local prefs = LrPrefs.prefsForPlugin()
	local pluginVersion = plugin_major .. '.' .. plugin_minor .. '.' .. plugin_rev .. '.' .. plugin_build
	local lrVersion = LrApplication.versionString()
	local osVersion = LrSystemInfo.osVersion()
	local lang = LrLocalization.currentLanguage()
	local uid = prefs.uid
	
		
	writeLogfile(2, string.format("Environment: plugin: %s Lr: %s OS: %s Lang: %s\n", pluginVersion, lrVersion, osVersion, lang))
	
	-- reset update status, if current version matches last available update version
	if pluginVersion == prefs.updateAvailable then
		writeLogfile(3, "CheckForUpdate: resetting Update status\n")
		prefs.updateAvailable = ''
		prefs.downloadUrl = ''
		LrDialogs.resetDoNotShowFlag('updateAvailableNote')
	end
	
	if prefs.uid == nil then
		prefs.uid = '0'
	end

	-- semaphore to prevent race conditions
	if prefs.activeCheck == nil then
		prefs.activeCheck = LrDate.timeFromComponents( 2015, 06, 01, 00, 00, 00, "local" )
	end
	
	if prefs.lastCheck == nil then
		prefs.lastCheck = LrDate.timeFromComponents( 2015, 06, 01, 00, 00, 00, "local" )
	end
	
	if prefs.updateAvailable == nil then
		prefs.updateAvailable = ""
	end
	
	if prefs.downloadUrl == nil then
		prefs.downloadUrl = ""
	end
	
	-- TestAndSet semaphore
	if (prefs.activeCheck > LrDate.currentTime() - 60)  then
		return true
	end
	prefs.activeCheck = LrDate.currentTime()
	
	-- Only check once per day
--	if LrDate.currentTime() < (tonumber(prefs.lastCheck) + 10) then
	if LrDate.currentTime() < (tonumber(prefs.lastCheck) + 86400) then
		return true
	end
	
	local checkUpdateRequest = 'pluginversion=' .. urlencode(pluginVersion) .. 
					'&osversion=' .. urlencode(osVersion) .. 
					'&lrversion=' .. urlencode(lrVersion) .. 
					'&lang=' .. urlencode(lang) ..
					'&uid=' .. urlencode(uid) ..
					'&sec=' .. LrMD5.digest(lrVersion .. pluginVersion .. osVersion .. lang .. uid .. plugin_TkId)

	local result, response = sendCheckUpdate(checkUpdateRequest)
	
	if not result then
		writeLogfile(3, "CheckForUpdate failed: " .. ifnil(response, '<No response>') .. "\n")
		return false
	end
	
	local res = string.match(response, '%g*res=([%a%d]*);')
	local newUid = string.match(response, '%g*uid=([%a%d]*);')
	local sec = string.match(response, '%g*sec=([%a%d]*);')
	local latestVersion = string.match(response, '%g*latestversion=([%a%d%.]*);')
	local downloadUrl = string.match(response, '%g*downloadurl=([%a%d%:%/%_%.%-%?]*);')
	if uid == '0' then
		uid = newUid
	end
	local checksum = LrMD5.digest(uid .. plugin_TkId)
	
	writeLogfile(4, "  got back: uid= " .. ifnil(newUid, '<Nil>') .. 
								", res= " .. ifnil(res, '<Nil>') .. 
								", sec= " .. ifnil(sec, '<Nil>') .. 
								", checksum(local)= " .. checksum ..
								", latestVersion= " .. ifnil(latestVersion, '<Nil>') .. 
								", downloadUrl= " .. ifnil(downloadUrl, '<Nil>') ..
								"\n")
								
	if checksum ~= ifnil(sec, '') then
		writeLogfile(3, "CheckForUpdate invalid response: uid=" .. ifnil(newUid, '<No uid>') .. "; sec =" .. sec .. "; checksum=" .. checksum .. "\n")
		return false
	end
	
	if ifnil(res, '') ~= 'OK' then
		writeLogfile(3, "CheckForUpdate returns: " .. res .. "\n")
		return false
	end
	
	-- update check was successful
	prefs.lastCheck = LrDate.currentTime()

	if newUid then
		writeLogfile(4, "  got newUid: " .. newUid .. "\n")
		prefs.uid = newUid
	end

	if latestVersion then
		writeLogfile(2, "  update available: " .. latestVersion .. " at " .. ifnil(downloadUrl, 'unknown URL') .. "\n")
		prefs.updateAvailable = latestVersion
		prefs.downloadUrl = ifnil(downloadUrl, 'unknown URL')
	else
		if 	prefs.updateAvailable ~= '' then
			LrDialogs.resetDoNotShowFlag('updateAvailableNote')
		end
		prefs.updateAvailable = ''
		prefs.downloadUrl = ''
	end

	return true
end

function sendCheckUpdate(checkUpdateRequest)
	local postHeaders = {
		{ 
			field = 'Content-Type', value = 'application/x-www-form-urlencoded' ,
		},
	}

	writeLogfile(4, "sendCheckUpdate: LrHttp.post(" .. serverUrl .. "-->" .. checkUpdateRequest .. ")\n")
	local respBody, respHeaders = LrHttp.post(serverUrl, checkUpdateRequest, postHeaders, 'POST', 5, string.len(checkUpdateRequest))
	
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

	return true, respBody
end
