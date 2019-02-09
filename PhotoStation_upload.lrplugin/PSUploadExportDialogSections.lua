--[[----------------------------------------------------------------------------

PSDialogs.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2019, Martin Messmer

Export dialog customization for Lightroom Photo StatLr

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

This code is derived from the Lr SDK FTP Upload sample code. Copyright: see below
--------------------------------------------------------------------------------

ADOBE SYSTEMS INCORPORATED
 Copyright 2007 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.

------------------------------------------------------------------------------]]

-- Lightroom SDK
local LrBinding			= import 'LrBinding'
local LrExportSettings 	= import 'LrExportSettings'
local LrView 			= import 'LrView'
local LrPathUtils 		= import 'LrPathUtils'
local LrFileUtils		= import 'LrFileUtils'
local LrPrefs	 		= import 'LrPrefs'
local LrShell 			= import 'LrShell'

require "PSUtilities"
require "PSDialogs"

--============================================================================--

PSUploadExportDialogSections = {}

-------------------------------------------------------------------------------
-- startDialog 
function PSUploadExportDialogSections.startDialog( propertyTable )
	-- check if my custom video output presets are already installed 
	local myVideoExportPresets = LrExportSettings.videoExportPresetsForPlugin( _PLUGIN )

	if myVideoExportPresets and #myVideoExportPresets > 0 then
	   	-- make sure, no older version of Video presets are installed
		LrExportSettings.removeVideoExportPreset('ALL', _PLUGIN)
--		writeLogfile(2, 'PSUploadExportDialogSections.startDialog(): found my custom video export presets.\n')
  	end
 
 	-- (re-)install my video export presets 	
	local pluginDir = _PLUGIN.path
	local presetFile = 'OrigSizeHiBit.epr'
	local presetFile2 = 'OrigSizeMedBit.epr'
--	writeLogfile(2, 'PSUploadExportDialogSections.startDialog(): adding video export preset ' ..  LrPathUtils.child(pluginDir, presetFile) .. '\n')
	
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
		writeLogfile(1, "PSUploadExportDialogSections.startDialog(): Could not add custom video export presets!\n")
	else
		writeLogfile(2, "PSUploadExportDialogSections.startDialog(): Successfully added " .. #origSizeVideoPreset .. " custom video export presets.\n")
	end

	PSDialogs.addObservers( propertyTable )
	
end

-------------------------------------------------------------------------------
-- function PSUploadExportDialogSections.sectionsForTopOfDialog( _, propertyTable )
function PSUploadExportDialogSections.sectionsForTopOfDialog( f, propertyTable )
	return 	{
		{
			title = "Photo StatLr",
    		synopsis = "Yeah, but they can't put a moon on a man!",
    		
    		-- ================== Photo StatLr header ==================================================================

   			PSDialogs.photoStatLrHeaderView(f, propertyTable),	
    
		}
	}	
end

-------------------------------------------------------------------------------
-- function PSUploadExportDialogSections.sectionsForBottomOfDialog( _, propertyTable )
function PSUploadExportDialogSections.sectionsForBottomOfDialog( f, propertyTable )

--	local f = LrView.osFactory()
	local bind = LrView.bind
	local share = LrView.share
	local conditionalItem = LrView.conditionalItem
	
	if propertyTable.isCollection == nil then
		propertyTable.isCollection = false
	end
	
	-- config section for Export or Publish dialog
	local result = {
	
		{
			title = "Photo Station",
			
			synopsis = bind { key = 'psUrl', object = propertyTable },


			-- ================== Target Photo Station ==========================================================

			PSDialogs.targetPhotoStationView(f, propertyTable),

			-- ================== Target Album and Upload Method ===============================================
			
			conditionalItem(not propertyTable.LR_isExportForPublish, PSDialogs.targetAlbumView(f, propertyTable)),
			
			-- ================== Phote renaming options======== ===============================================
			
			conditionalItem(not propertyTable.LR_isExportForPublish, PSDialogs.photoNamingView(f, propertyTable)),
			
			-- ================== Thumbnail Options =============================================================

			PSDialogs.thumbnailOptionsView(f, propertyTable),

			-- ================== Video Options =================================================================

			PSDialogs.videoOptionsView(f, propertyTable),

            -- ================== Upload Options ================================================================
            
            conditionalItem(not propertyTable.LR_isExportForPublish, PSDialogs.uploadOptionsView(f, propertyTable)),

			-- ================== Log Options ===================================================================

			PSDialogs.loglevelView(f, propertyTable),
		},
	}

	return result
end
