--[[----------------------------------------------------------------------------

PSDialogs.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2021, Martin Messmer

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
--	writeLogfile(2, 'sectionsForBottomOfDialog(): starting....\n')

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
			title = "Photo StatLr - Photo Server",
			
			synopsis = bind { key = 'psUrl', object = propertyTable },


			-- ================== Target Photo Server ==========================================================

			PSDialogs.targetPhotoStationView(f, propertyTable),

			-- ================== Target Album and Upload Method ===============================================
			
			conditionalItem(not propertyTable.LR_isExportForPublish, PSDialogs.targetAlbumView(f, propertyTable)),
			
			-- ================== Photo Renaming Options ========================================================
			
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

--	writeLogfile(2, 'sectionsForBottomOfDialog(): done.\n')
	return result
end
