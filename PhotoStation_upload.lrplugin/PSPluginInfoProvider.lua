--[[----------------------------------------------------------------------------

PSPluginInfoProvider.lua
Plugin info provider description for Lightroom PhotoStation Upload
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

------------------------------------------------------------------------------]]

-- Lightroom SDK
local LrBinding		= import 'LrBinding'
local LrHttp 		= import 'LrHttp'
local LrView 		= import 'LrView'
local LrPathUtils 	= import 'LrPathUtils'
local LrFileUtils	= import 'LrFileUtils'
local LrPrefs		= import 'LrPrefs'
local LrTasks		= import 'LrTasks'
local progExt = nil			-- .exe for WIN_ENV


-- PhotoStation Upload plug-in
require "PSUtilities"
require "PSPublishSupport"
require "PSUploadTask"
require "PSUpdate"

--============================================================================--

local pluginInfoProvider = {}


-- TODO: Uploader program path should be a plugin setting, not an export/publish setting
-- validatePSUploadProgPath: 
--[[	check if a given path points to the root directory of the Synology PhotoStation Uploader tool 
		we require the following converters that ship with the Uploader:
			- ImageMagick/convert(.exe)
			- ffmpeg/ffpmeg(.exe)
			- ffpmpeg/qt-faststart(.exe)
local function validatePSUploadProgPath( view, path )
	local convertprog = 'convert'
	local ffmpegprog = 'ffmpeg'
	local qtfstartprog = 'qt-faststart'
	if progExt then
		convertprog = LrPathUtils.addExtension(convertprog, progExt)
		ffmpegprog = LrPathUtils.addExtension(ffmpegprog, progExt)
		qtfstartprog = LrPathUtils.addExtension(qtfstartprog, progExt)
	end
	
	if LrFileUtils.exists(path) ~= 'directory' 
	or not LrFileUtils.exists(LrPathUtils.child(LrPathUtils.child(path, 'ImageMagick'), convertprog))
	or not LrFileUtils.exists(LrPathUtils.child(LrPathUtils.child(path, 'ffmpeg'), ffmpegprog)) 
	or not LrFileUtils.exists(LrPathUtils.child(LrPathUtils.child(path, 'ffmpeg'), qtfstartprog)) then
		return false, path
	end

	return true, LrPathUtils.standardizePath(path)
end
]]

-- TODO: Uploader program path should be a plugin setting, not an export/publish setting

-- updatePluginStatus: do some sanity check on dialog settings
--[[
local function updatePluginStatus( propertyTable )
	
	local message = nil
	
	repeat
		-- Use a repeat loop to allow easy way to "break" out.
		-- (It only goes through once.)
		
		if not validatePSUploadProgPath(nil, propertyTable.PSUploaderPath) then
			message = LOC "$$$/PSUpload/PluginDialog/Messages/PSUploadPathMissing=Enter the installation path (base) of the Synology PhotoStation Uploader or Synology Assistant"
			break
		end

	until true
	
	if message then
		propertyTable.message = message
		propertyTable.hasError = true
		propertyTable.hasNoError = false
	else
		propertyTable.message = nil
		propertyTable.hasError = false
		propertyTable.hasNoError = true
	end
	
end
]]
-------------------------------------------------------------------------------

function pluginInfoProvider.startDialog( propertyTable )
	local prefs = LrPrefs.prefsForPlugin()
	
	openLogfile(2)
	writeLogfile(4, "pluginInfoProvider.startDialog\n")
	LrTasks.startAsyncTaskWithoutErrorHandler( PSUpdate.checkForUpdate, "PSUploadCheckForUpdate")

	-- TODO: Uploader program path should be a plugin setting, not an export/publish setting
	--[[ 
	if WIN_ENV  then
		progExt = 'exe'
	end
	
	if prefs.PSUploaderPath == nil then
		prefs.PSUploaderPath = iif(WIN_ENV, 
						'C:\\\Program Files (x86)\\\Synology\\\Photo Station Uploader',
						'/Applications/Synology Photo Station Uploader.app/Contents/MacOS')
	end
	
	prefs:addObserver( 'PSUploaderPath', updatePluginStatus )
	updatePluginStatus( prefs )
	]]
end
-------------------------------------------------------------------------------

function pluginInfoProvider.endDialog( propertyTable )
end

--------------------------------------------------------------------------------
	
-- function pluginInfoProvider.sectionsForTopOfDialog( _, propertyTable )
function pluginInfoProvider.sectionsForTopOfDialog( f, propertyTable )
--	local f = LrView.osFactory()
	local bind = LrView.bind
	local share = LrView.share
	local conditionalItem = LrView.conditionalItem
	local prefs = LrPrefs.prefsForPlugin()
	local updateAvail
	local synops
	
	-- TODO: Uploader program path should be a plugin setting, not an export/publish setting
	--[[ 
	if prefs.message == nil then
		prefs.message = 'Settings OK'
	end
	
	if prefs.PSUploaderPath == nil then
		prefs.PSUploaderPath = iif(WIN_ENV, 
						'C:\\\Program Files (x86)\\\Synology\\\Photo Station Uploader',
						'/Applications/Synology Photo Station Uploader.app/Contents/MacOS')
	end
	]]
	
	if prefs.updateAvailable == nil then
		synops = ""
		updateAvail = false
	elseif prefs.updateAvailable == '' then
		synops = LOC "$$$/PSUpload/PluginDialog/NOUPDATE=Plugin is up-to-date"
		updateAvail = false
	else
		synops = LOC "$$$/PSUpload/PluginDialog/UPDATE=" .. "Version " .. prefs.updateAvailable ..  " available!"
		updateAvail = true
	end 
	
	local noUpdateAvailableView = f:view {
		fill_horizontal = 1,
		
		f:row {
			f:static_text {
				title = synops,
				alignment = 'right',
				width = share 'labelWidth'
			},
		},
	}

	local updateAvailableView = f:view {
		fill_horizontal = 1,
		
		f:row {
			f:static_text {
				title = synops,
				alignment = 'right',
				width = share 'labelWidth'
			},

			f:push_button {
				title = LOC "$$$/PSUpload/PluginDialog/GetUpdate=Go to Update URL",
				tooltip = LOC "$$$/PSUpload/PluginDialog/Logfile=Open Update URL in browser",
				alignment = 'right',
				action = function()
					LrHttp.openUrlInBrowser(prefs.downloadUrl)
				end,
			},
		},
	}
	local result = {
	
		{
			title = LOC "$$$/PSUpload/PluginDialog/PsSettings=PhotoStation Upload: General Settings",
			
			synopsis = synops,

			-- TODO: Uploader program path should be a plugin setting, not an export/publish setting
			--[[ 
			f:row {
				f:static_text {
					title = LOC "$$$/PSUpload/PluginDialog/PSUPLOAD=Syno PhotoStation Uploader:",
					alignment = 'right',
					width = share 'labelWidth'
				},
	
				f:edit_field {
					value = bind 'PSUploaderPath',
					tooltip = LOC "$$$/PSUpload/PluginDialog/PSUPLOADTT=Enter the installation path of the Synology PhotoStation Uploader.",
					truncation = 'middle',
					validate = validatePSUploadProgPath,
					immediate = true,
					fill_horizontal = 1,
				},
			},
			]]
			
			conditionalItem(updateAvail, updateAvailableView),
			conditionalItem(not updateAvail, noUpdateAvailableView),
		},
	}
	
	return result

end

-------------------------------------------------------------------------------

--[[
pluginInfoProvider.exportPresetFields = {
		{ key = 'PSUploaderPath', default = 		-- local path to Synology PhotoStation Uploader
					iif(WIN_ENV, 
						'C:\\\Program Files (x86)\\\Synology\\\Photo Station Uploader',
						'/Applications/Synology Photo Station Uploader.app/Contents/MacOS') 
		},											
}
]]
--------------------------------------------------------------------------------

return pluginInfoProvider
