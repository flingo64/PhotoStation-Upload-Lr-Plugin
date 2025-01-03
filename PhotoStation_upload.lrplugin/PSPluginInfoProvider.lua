--[[----------------------------------------------------------------------------

PSPluginInfoProvider.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2015-2024, Martin Messmer

Plugin info provider description for Lightroom Photo StatLr

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

------------------------------------------------------------------------------]]

-- Lightroom SDK
local LrBinding			= import 'LrBinding'
local LrHttp 			= import 'LrHttp'
local LrView 			= import 'LrView'
local LrPathUtils 		= import 'LrPathUtils'
local LrFileUtils		= import 'LrFileUtils'
local LrFunctionContext	= import 'LrFunctionContext'
local LrPrefs			= import 'LrPrefs'
local LrTasks			= import 'LrTasks'

local bind 				= LrView.bind
local conditionalItem 	= LrView.conditionalItem

-- Photo StatLr plug-in
require "PSDialogs"
require "PSUtilities"
require "PSUpdate"

--============================================================================--

local pluginInfoProvider = {}

-------------------------------------------------------------------------------
-- updatePluginStatus: do some sanity check on dialog settings
local function updatePluginStatus( propertyTable )

	local message = nil

	repeat
		-- Use a repeat loop to allow easy way to "break" out.
		-- (It only goes through once.)

		if PSDialogs.validateProgram(nil, propertyTable.convertprog) then
			message = LOC "$$$/PSUpload/Dialogs/Messages/ConvertPathMissing=Incorrect convert path."
			break
		end

		if PSDialogs.validateProgram(nil, propertyTable.dcrawprog) then
			message = LOC "$$$/PSUpload/Dialogs/Messages/DcrawPathMissing=Incorrect dcraw path."
			break
		end

		if PSDialogs.validateProgram(nil, propertyTable.exiftoolprog) then
			message = LOC "$$$/PSUpload/Dialogs/Messages/ExifToolPathMissing=Incorrect exiftool path."
			break
		end

		if not PSDialogs.validateProgram(nil, propertyTable.ffmpegprog) then
			message = LOC "$$$/PSUpload/Dialogs/Messages/VideoFfmpegMissing=Incorrect ffmpeg path."
			break
		end

		if not PSDialogs.validatePluginFile(nil, propertyTable.videoConversionsFn) then
			message = LOC "$$$/PSUpload/Dialogs/Messages/VideoPresetsMissing=Incorrect video presets file."
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

-------------------------------------------------------------------------------
-- pluginInfoProvider.startDialog( propertyTable )
function pluginInfoProvider.startDialog( propertyTable )
	local prefs = LrPrefs.prefsForPlugin()

	openLogfile(4)
--	writeLogfile(4, "pluginInfoProvider.startDialog\n")
	LrTasks.startAsyncTaskWithoutErrorHandler(PSUpdate.checkForUpdate, "PSUploadCheckForUpdate")

	-- ImageMagick convert program path: required for thumb generation and video handling
	propertyTable.convertprog = prefs.convertprog

	-- dcraw program path: required for thumb generation and video handling
	propertyTable.dcrawprog = prefs.dcrawprog
	-- exiftool program path: used for metadata translations on upload
	propertyTable.exiftoolprog = prefs.exiftoolprog
	-- ffmpeg program path: default is <PSUploaderPath>/ffmpeg/ffmpeg(.exe)
	propertyTable.ffmpegprog = prefs.ffmpegprog

	-- video presets file: used for video conversions
	propertyTable.videoConversionsFn = prefs.videoConversionsFn

	propertyTable:addObserver('convertprog', updatePluginStatus )
	propertyTable:addObserver('dcrawprog', updatePluginStatus )
	propertyTable:addObserver('exiftoolprog', updatePluginStatus )
	propertyTable:addObserver('ffmpegprog', updatePluginStatus )
	propertyTable:addObserver('videoConversionsFn', updatePluginStatus )

	updatePluginStatus(propertyTable)
end

-------------------------------------------------------------------------------
-- pluginInfoProvider.endDialog( propertyTable )
function pluginInfoProvider.endDialog( propertyTable )
--	writeLogfile(4, "pluginInfoProvider.endDialog\n")
	local prefs = LrPrefs.prefsForPlugin()

	prefs.convertprog			= propertyTable.convertprog
	prefs.dcrawprog				= propertyTable.dcrawprog
	prefs.exiftoolprog 			= propertyTable.exiftoolprog
	prefs.ffmpegprog 			= propertyTable.ffmpegprog
	prefs.videoConversionsFn 	= propertyTable.videoConversionsFn

	if propertyTable.convertAllPhotos then
--		LrTasks.startAsyncTask(PSLrUtilities.convertAllPhotos, 'ConvertAllPhotos')
		LrFunctionContext.postAsyncTaskWithContext('ConvertAllPhotos', PSLrUtilities.convertAllPhotos)
	end
end

--------------------------------------------------------------------------------
-- pluginInfoProvider.sectionsForTopOfDialog( f, propertyTable )
function pluginInfoProvider.sectionsForTopOfDialog( f, propertyTable )
	local prefs = LrPrefs.prefsForPlugin()
	local updateAvail
	local synops

	if prefs.updateAvailable == nil then
		synops = "You plan to like this show?"
		updateAvail = false
	elseif prefs.updateAvailable == '' or prefs.updateAvailable == PLUGIN_VERSION then
		synops = 	"Nothing, just thought I'd mention it: " ..
					LOC "$$$/PSUpload/PluginDialog/Header/NoUpdateAvail=Plugin is up-to-date"
		updateAvail = false
	else
		synops =	"This is a very moving moment: " ..
					LOC("$$$/PSUpload/PluginDialog/Header/UpdateAvail=Version ^1 is available!", prefs.updateAvailable)
		updateAvail = true
	end

	local noUpdateAvailableView = f:view {
		fill_horizontal = 1,

		f:column {
			f:static_text {
				title 		= synops,
				alignment 	= 'right',
			},
		},
	}

	local updateAvailableView = f:view {
		fill_horizontal = 1,

		f:row {
			f:static_text {
				title = synops,
				alignment = 'left',
				fill_horizontal = 0.6,
			},

			f:push_button {
				title = LOC "$$$/PSUpload/PluginDialog/GetUpdate=Go to Update URL",
				tooltip = LOC "$$$/PSUpload/PluginDialog/GetUpdateTT=Open Update URL in browser",
				alignment = 'right',
				fill_horizontal = 0.4,
				action = function()
					LrHttp.openUrlInBrowser(prefs.downloadUrl)
				end,
			},
		},
	}
	local result = {

		{
			title = "Photo StatLr",

			synopsis = synops,
			f:row {
				fill_horizontal = 1,

				conditionalItem(updateAvail, updateAvailableView),
				conditionalItem(not updateAvail, noUpdateAvailableView),
			},

			f:row {
				PSDialogs.photoStatLrHeaderView(f, propertyTable),
    		},
		},
	}

	return result

end

--------------------------------------------------------------------------------
-- pluginInfoProvider.sectionsForBottomOfDialog( f, propertyTable )
function pluginInfoProvider.sectionsForBottomOfDialog(f, propertyTable )
	return {
		{
    		title = 	LOC "$$$/PSUpload/PluginDialog/PsSettings=Geneneral Settings",
    		synopsis = 	LOC "$$$/PSUpload/PluginDialog/PsSettingsSynopsis=Set program paths",
			bind_to_object = propertyTable,

    		f:view {
				fill_horizontal = 1,

    			PSDialogs.converterToolsView(f, propertyTable),
				PSDialogs.exiftoolProgView(f, propertyTable),
				PSDialogs.videoConvSettingsView(f, propertyTable),
				PSDialogs.convertPhotosView(f, propertyTable),
    		}
		}
	}

end

--------------------------------------------------------------------------------

return pluginInfoProvider
