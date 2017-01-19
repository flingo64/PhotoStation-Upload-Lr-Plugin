--[[----------------------------------------------------------------------------

PSDialogs.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2017, Martin Messmer

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
local LrBinding		= import 'LrBinding'
local LrView 		= import 'LrView'
local LrPathUtils 	= import 'LrPathUtils'
local LrFileUtils	= import 'LrFileUtils'
local LrPrefs	 	= import 'LrPrefs'
local LrShell 		= import 'LrShell'

require "PSUtilities"
require "PSDialogs"

--============================================================================--

PSUploadExportDialogSections = {}

-------------------------------------------------------------------------------

-------------------------------------------------------------------------------

-- updatExportStatus: do some sanity check on dialog settings
local function updateExportStatus( propertyTable )
	local prefs = LrPrefs.prefsForPlugin()
	
	local message = nil
	
	repeat
		-- Use a repeat loop to allow easy way to "break" out.
		-- (It only goes through once.)
		
		if propertyTable.thumbGenerate and not PSDialogs.validatePSUploadProgPath(nil, prefs.PSUploaderPath) then
			message = LOC "$$$/PSUpload/Dialogs/Messages/PSUploadPathMissing=Missing or wrong Synology Photo Station Uploader path. Fix it in Plugin Manager settings section." 
			break
		end

		if propertyTable.servername == "" or propertyTable.servername == nil  then
			message = LOC "$$$/PSUpload/Dialogs/Messages/ServernameMissing=Enter a servername"
			break
		end

		if propertyTable.username == "" or propertyTable.username == nil  then
			message = LOC "$$$/PSUpload/Dialogs/Messages/UsernameMissing=Enter a username"
			break
		end

		if propertyTable.copyTree and not PSDialogs.validateDirectory(nil, propertyTable.srcRoot) then
			message = LOC "$$$/PSUpload/Dialogs/Messages/EnterSubPath=Enter a source path"
			break
		end
				
		if propertyTable.usePersonalPS and (propertyTable.personalPSOwner == "" or propertyTable.personalPSOwner == nil ) then
			message = LOC "$$$/PSUpload/Dialogs/Messages/EnterPersPSUser=Enter the owner of the Personal Photo Station to upload to"
			break
		end

		-- Check file format: PSD not supported by Photo Station, DNG only supported w/ embedded full-size jpg preview
		if (propertyTable.LR_format == 'PSD') or  (propertyTable.LR_format == 'DNG' and ifnil(propertyTable.LR_DNG_previewSize, '') ~= 'large') then
			message = LOC "$$$/PSUpload/Dialogs/Messages/FileFormatNoSupp=File format not supported! Select: [JPEG], [TIFF], [DNG w/ full-size JPEG preview] or [Original]."
			break
		end

		-- renaming: either Lr or plugin renaming can be active
		if not propertyTable.LR_isExportForPublish and propertyTable.LR_renamingTokensOn and propertyTable.renameDstFile then
			message = LOC "$$$/PSUpload/Dialogs/Messages/RenameOption=Use either Lr File Renaming or Photo StatLr File Renaming, not both!"
			break
		end

		-- renaming: renaming dstFilename must contain at least one metadata placeholder
		if propertyTable.renameDstFile and not PSDialogs.validateMetadataPlaceholder(nil, propertyTable.dstFilename) then
			message = LOC "$$$/PSUpload/Dialogs/Messages/RenamePatternInvalid=Rename Photos: Missing placeholders or unbalanced { }!"
			break
		end

		-- Publish Servic Provider start

		if propertyTable.LR_isExportForPublish and propertyTable.LR_renamingTokensOn then
			message = LOC "$$$/PSUpload/Dialogs/Messages/RenameNoSupp= Lr File Renaming option not supported in Publish mode!"
			break
		end

		if propertyTable.useSecondAddress and ifnil(propertyTable.servername2, "") == "" then
			message = LOC "$$$/PSUpload/Dialogs/Messages/Servername2Missing=Enter a secondary servername"
			break
		end

		-- Publish Service Provider end

		-- Exif translation start
		
		-- if at least one translation is activated then set exifTranslate
		if propertyTable.exifXlatFaceRegions or propertyTable.exifXlatLabel or propertyTable.exifXlatRating then
			propertyTable.exifTranslate = true
		end
		
		-- if no translation is activated then set exifTranslate to off
		if not (propertyTable.exifXlatFaceRegions or propertyTable.exifXlatLabel or propertyTable.exifXlatRating) then
			propertyTable.exifTranslate = false
		end
				
		if propertyTable.exifTranslate and not PSDialogs.validateProgram(nil, prefs.exiftoolprog) then
			message = LOC "$$$/PSUpload/Dialogs/Messages/EnterExiftool=Missing or wrong exiftool path. Fix it in Plugin Manager settings section."
			break
		end
		-- Exif translation end

		propertyTable.serverUrl = 	propertyTable.proto .. "://" .. propertyTable.servername
		propertyTable.psPath = 		iif(propertyTable.usePersonalPS, "/~" .. ifnil(propertyTable.personalPSOwner, "unknown") .. "/photo/", "/photo/")
		propertyTable.psUrl = 		propertyTable.serverUrl .. propertyTable.psPath
		propertyTable.isPS6 = 		iif(propertyTable.psVersion >= 60, true, false)
	until true
	
	if message then
		propertyTable.message = message
		propertyTable.hasError = true
		propertyTable.hasNoError = false
		propertyTable.LR_cantExportBecause = 'Booo!! ' .. message
	else
		propertyTable.message = nil
		propertyTable.hasError = false
		propertyTable.hasNoError = true
		propertyTable.LR_cantExportBecause = nil
	end
	
end

-------------------------------------------------------------------------------

function PSUploadExportDialogSections.startDialog( propertyTable )
	
	propertyTable:addObserver( 'thumbGenerate', updateExportStatus )

	propertyTable:addObserver( 'proto', updateExportStatus )
	propertyTable:addObserver( 'servername', updateExportStatus )
	propertyTable:addObserver( 'username', updateExportStatus )
	propertyTable:addObserver( 'srcRoot', updateExportStatus )
	propertyTable:addObserver( 'copyTree', updateExportStatus )
	propertyTable:addObserver( 'usePersonalPS', updateExportStatus )
	propertyTable:addObserver( 'personalPSOwner', updateExportStatus )
	propertyTable:addObserver( 'psVersion', updateExportStatus )

	propertyTable:addObserver( 'useSecondAddress', updateExportStatus )
	propertyTable:addObserver( 'servername2', updateExportStatus )

	propertyTable:addObserver( 'exifXlatFaceRegions', updateExportStatus )
	propertyTable:addObserver( 'exifXlatLabel', updateExportStatus )
	propertyTable:addObserver( 'exifXlatRating', updateExportStatus )

	propertyTable:addObserver( 'renameDstFile', updateExportStatus )
	propertyTable:addObserver( 'dstFilename', updateExportStatus )

	propertyTable:addObserver( 'LR_renamingTokensOn', updateExportStatus )
	propertyTable:addObserver( 'LR_tokens', updateExportStatus )
	
	propertyTable:addObserver( 'LR_format', updateExportStatus )
	propertyTable:addObserver( 'LR_DNG_previewSize', updateExportStatus )

	updateExportStatus( propertyTable )
	
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
