--[[----------------------------------------------------------------------------

PSInitPlugin.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2019, Martin Messmer

plugin initialization:
	- load Lr video presets
	
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
]]
--------------------------------------------------------------------------------

-- Lightroom SDK
local LrExportSettings 	= import 'LrExportSettings'
local LrPathUtils 		= import 'LrPathUtils'
local LrPrefs			= import 'LrPrefs'

require "PSUtilities"

--========== Initialize plugin preference ==================================================================--
local prefs = LrPrefs.prefsForPlugin()

-- local path to Synology Photo Station Uploader: required for thumb generation an video handling
if not prefs.PSUploaderPath then 
   	prefs.PSUploaderPath =  PSConvert.defaultInstallPath
end
	
-- exiftool program path: used for metadata translations on upload
if not prefs.exiftoolprog then
	prefs.exiftoolprog = PSExiftoolAPI.defaultInstallPath
end

-- ffmpeg program path: default is <PSUploaderPath>/ffmpeg/ffmpeg(.exe)
if not prefs.ffmpegprog then
	if getProgExt() then
		prefs.ffmpegprog = LrPathUtils.child(LrPathUtils.child(prefs.PSUploaderPath, 'ffmpeg'), LrPathUtils.addExtension('ffmpeg', getProgExt()))
	else
		prefs.ffmpegprog = LrPathUtils.child(LrPathUtils.child(prefs.PSUploaderPath, 'ffmpeg'), 'ffmpeg')
	end
end

-- video presets file: used for video conversions
if not prefs.videoConversionsFn then
	prefs.videoConversionsFn = PSConvert.defaultVideoPresetsFn
end

writeLogfile(2, string.format("PSInitPlugin:\n\t\tPSUploader: '%s'\n\t\texiftool:   '%s'\n\t\tffmpeg:     '%s'\n", prefs.PSUploaderPath, prefs.exiftoolprog, prefs.ffmpegprog))

--=========== Install Lr video conversion presets =================================================================--

-- check if my custom video output presets are already installed 
local myVideoExportPresets = LrExportSettings.videoExportPresetsForPlugin( _PLUGIN )

if myVideoExportPresets and #myVideoExportPresets > 0 then
   	-- make sure, no older version of Video presets are installed
	LrExportSettings.removeVideoExportPreset('ALL', _PLUGIN)
--		writeLogfile(2, 'PSInitPlugin: found my custom video export presets.\n')
  	end
 
-- (re-)install my video export presets 	
local pluginDir = _PLUGIN.path
local presetFile = 'OrigSizeHiBit.epr'
local presetFile2 = 'OrigSizeMedBit.epr'
--	writeLogfile(2, 'PSInitPlugin: adding video export preset ' ..  LrPathUtils.child(pluginDir, presetFile) .. '\n')

local origSizeVideoPreset = LrExportSettings.addVideoExportPresets( {
	[ 'Original Size - High Bitrate' ] = {
		-- The format identifier for the video export format that this preset
		-- corresponds to. This identifier must be equal to the 'formatName'
		-- entry in one of the entries in the table returned by
		-- LrExportSettings.supportableVideoExportFormats, i.e. 'h.264'.
		format = 'h.264',

		-- Must be an absolute path
		presetPath = LrPathUtils.child(pluginDir, presetFile),

		-- To be displayed as target info in export dialog.
		targetInfo =  LOC "$$$/PSUpload/ExportDialog/VideoSection/OrigSizePreset/TargetInfo=original resolution, high bitrate",
 	}, 

	[ 'Original Size - Medium Bitrate' ] = {
		format = 'h.264',

		-- Must be an absolute path
		presetPath = LrPathUtils.child(pluginDir, presetFile2),

		-- To be displayed as target info in export dialog.
		targetInfo =  LOC "$$$/PSUpload/ExportDialog/VideoSection/OrigSizePreset2/TargetInfo=original resolution, medium bitrate",
 	}, 
 },	_PLUGIN
)

if not origSizeVideoPreset then
	writeLogfile(1, "PSInitPlugin: Could not add custom video export presets!\n")
else
	writeLogfile(2, "PSInitPlugin: Successfully added " .. #origSizeVideoPreset .. " custom video export presets.\n")
end
