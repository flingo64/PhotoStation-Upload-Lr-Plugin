--[[----------------------------------------------------------------------------

PSExportServiceProvider.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2015-2024, Martin Messmer

Export service provider description for Lightroom Photo StatLr

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

This code is derived from the Lr SDK FTP Export and Flickr sample code. Copyright: see below
--------------------------------------------------------------------------------

ADOBE SYSTEMS INCORPORATED
 Copyright 2007-2008 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.

------------------------------------------------------------------------------]]

-- Photo StatLr plug-in
require "PSUtilities"
require "PSUploadExportDialogSections"
require "PSPublishSupport"
require "PSUploadTask"

--============================================================================--

local exportServiceProvider = {}

-- get all Publish hooks
-- this approach allows us to document the publish-specific hooks separately.

for name, value in pairs( PSPublishSupport ) do
	exportServiceProvider[ name ] = value
end

-- supportsIncrementalPublish
-- If not present, this plug-in is available in Export only.
-- When true, this plug-in can be used for both Export and Publish.
-- When set to the string "only", the plug-in is visible only in Publish.
exportServiceProvider.supportsIncrementalPublish = true

---------------- Export Service Provider Hooks
exportServiceProvider.hideSections = { 'exportLocation' }

exportServiceProvider.allowFileFormats = nil -- nil equates to all available formats

exportServiceProvider.allowColorSpaces = nil -- nil equates to all color spaces

exportServiceProvider.canExportVideo = true	-- yes, we can

exportServiceProvider.exportPresetFields = {
		-- Photo Server parameters
		{ key = 'proto', 			default = 'http' },	-- transport protocol for Photo Server upload
		{ key = 'servername', 		default = '' },		-- name/address of the Photo Server, may include ':port' extension
		{ key = 'psPath', 			default = '/photo/' },		-- Standard or Personal Photo Server path
		{ key = 'serverTimeout', 	default = 10 },		-- http timeout
		{ key = 'serverUrl', 		default = '' },		-- proto + servername
		{ key = 'psUrl', 			default = '' },		-- serverUrl + Photo Server path (used for synopsis)
		{ key = 'usePersonalPS', 	default = false },	-- upload to Personal Photo Server
		{ key = 'personalPSOwner', 	default = '' },		-- owner of the Personal Photo Server to upload to
		{ key = 'username', 		default = '' },		-- account for Photo Server upload
		{ key = 'password', 		default = '' },		-- guess what...
		{ key = 'psVersion', 		default = 68 },		-- Photo Server version: default PS 6.8
		{ key = 'uploadTimestamp',	default = 'capture' },-- file timestamp for uploaded photos: 'capture', 'upload' or 'mixed' (photos=upload, videos=capture)

		-- target album parameters
		{ key = 'copyTree', 		default = false },	-- upload method: flat copy or tree mirror
		{ key = 'srcRoot', 			default = '' },		-- local path to root of picture folders (only used if copyTree)
		{ key = 'storeDstRoot', 	default = true },	-- enter destination Album in Export dialog or later
		{ key = 'dstRoot', 			default = '' },		-- destination Album on Photo Server: no leading or trailing slash required
		{ key = 'createDstRoot', 	default = false },	-- create Destination album (if not exist)
		{ key = 'sortPhotos',		default = false },	-- sort photos in Photo Server acc. to collection sort order

		-- upload options / exif translation parameters
		{ key = 'exifXlatFaceRegions',	default = false },	-- translate Lr/Picasa face regions to PS face regions
		{ key = 'exifXlatLabel', 		default = false },	-- translate Lr label (red, green, ...) to PS keyword
		{ key = 'exifXlatRating', 		default = false},	-- translate Lr star rating (XMP:rating) to PS keywords
		{ key = 'exifTranslate', 		default = false },	-- set if any of the above translations is set: requires exiftool

		{ key = 'xlatLocationTags',		default = false},					-- translate Lr location tags to single PS locaton tag
		{ key = 'locationTagSeperator',	default = '-' },					-- output seperator for locaton tags
		{ key = 'locationTagField1',	default = '{LrFM:isoCountryCode}' },-- field 1 of location tag template
		{ key = 'locationTagField2',	default = '{LrFM:country}' }, 		-- field 2 of location tag template
		{ key = 'locationTagField3',	default = '{LrFM:stateProvince}' }, -- field 3 of location tag template
		{ key = 'locationTagField4',	default = '{LrFM:city}' }, 			-- field 4 of location tag template
		{ key = 'locationTagField5',	default = '{LrFM:location}' }, 		-- field 5 of location tag template
		{ key = 'locationTagTemplate',	default = '' },						-- the resulting location tag template

		-- thumbnail parameters
		{ key = 'thumbGenerate',	default = true },	-- generate thumbs: yes or nos
		{ key = 'largeThumbs', 		default = true },	-- generate large thumbs or small thumbs
		{ key = 'thumbQuality', 	default = 80 },		-- conversion quality in percent
		{ key = 'thumbSharpness', 	default = 'MED' },	-- sharpening for thumbs

		-- target filename parameters
		{ key = 'renameDstFile',	default = false },	-- rename photo when uploading
		{ key = 'dstFilename',		default = '' },		-- rename photo to this filename (containing placeholders)
		{ key = 'RAWandJPG',		default = false },	-- allow to upload RAW+JPG to same album

		-- video parameters
		{ key = 'orgVideoForceConv',	default = false },  -- force orig video conversion even if video format is supported by PS
		{ key = 'orgVideoQuality',		default = 3 },  	-- video conversion quality for orig video
		{ key = 'hardRotate', 			default = false }, 	-- Hard-rotate soft-rotated or meta-rotated videos

		{ key = 'addVideoQuality',		default = 2 },  	-- video conversion quality for the additional video
		{ key = 'addVideoUltra', 		default = 'None' },	-- additional video resolution for ULTRA res videos
		{ key = 'addVideoHigh', 		default = 'None' },	-- additional video resolution for HIGH res videos
		{ key = 'addVideoMed',			default = 'None' }, -- additional video resolution for MEDIUM res videos
		{ key = 'addVideoLow', 			default = 'None' },	-- additional video resolution for LOW res videos

		-- logging/debugging parameters
		{ key = 'logLevel', 		default = 2 },		-- loglevel

		-- Secondary Server
		{ key = 'useSecondAddress',		default = false },		-- specify a secondoray (external) server address
		{ key = 'proto2', 				default = 'https' },	-- transport protocol for secondary Photo Server upload
		{ key = 'servername2', 			default = '' },			-- name/address of the secondary Photo Server, may include ':port' extension
		{ key = 'psPath2', 				default = '/photo/' },	-- Standard or Personal Photo Server path
		{ key = 'serverTimeout2',	 	default = 10 },			-- http timeout

		{ key = 'publishMode', 			default = 'Publish' },	-- publish operation mode: Normal, CheckExisting, ...
}

exportServiceProvider.startDialog = PSUploadExportDialogSections.startDialog
exportServiceProvider.sectionsForTopOfDialog = PSUploadExportDialogSections.sectionsForTopOfDialog
exportServiceProvider.sectionsForBottomOfDialog = PSUploadExportDialogSections.sectionsForBottomOfDialog

exportServiceProvider.updateExportSettings = PSUploadTask.updateExportSettings
exportServiceProvider.processRenderedPhotos = PSUploadTask.processRenderedPhotos

--------------------------------------------------------------------------------

return exportServiceProvider
