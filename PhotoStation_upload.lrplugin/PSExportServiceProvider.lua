--[[----------------------------------------------------------------------------

PSExportServiceProvider.lua
Export service provider description for Lightroom PhotoStation Upload
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

-- PhotoStation Upload plug-in
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
		{ key = 'PSUploaderPath', default = 		-- local path to Synology PhotoStation Uploader
					iif(WIN_ENV, 
						'C:\\\Program Files (x86)\\\Synology\\\Photo Station Uploader',
						'/Applications/Synology Photo Station Uploader.app/Contents/MacOS') 
		},											
		-- PhotoStation parameters
		{ key = 'proto', 			default = 'http' },	-- transport protocol for PhotoStation upload
		{ key = 'servername', 		default = '' },		-- name/address of the PhotoStation, may include ':port' extension
		{ key = 'serverTimeout', 	default = 10 },		-- http timeout
		{ key = 'serverUrl', 		default = '' },		-- proto + servername
		{ key = 'psUrl', 			default = '' },		-- serverUrl + destination album (used for synopsis)
		{ key = 'usePersonalPS', 	default = false },	-- upload to Personal PhotoStation
		{ key = 'personalPSOwner', 	default = '' },		-- owner of the Personal PhotoStation to upload to
		{ key = 'username', 		default = '' },		-- account for PhotoStation upload
		{ key = 'password', 		default = '' },		-- guess what...

		-- target album parameters
		{ key = 'copyTree', 		default = false },	-- upload method: flat copy or tree mirror
		{ key = 'srcRoot', 			default = '' },		-- local path to root of picture folders (only used if copyTree)
		{ key = 'storeDstRoot', 	default = true },	-- enter destination Album in Export dialog or later
		{ key = 'dstRoot', 			default = '' },		-- destination Album on PhotoStation: no leading or trailing slash required
		{ key = 'createDstRoot', 	default = false },	-- create Destination album (if not exist)

		-- exif translation parameters
		{ key = 'exiftoolprog',		 	default = 			-- path to exiftool
			iif(WIN_ENV, 'C:\\\Windows\\\exiftool.exe', '/usr/local/bin/exiftool') 
		},											
		{ key = 'exifTranslate', 		default = true },	-- make exif translations: requires exiftool
		{ key = 'exifXlatFaceRegions',	default = true },	-- translate Lr/Picasa face regions to PS face regions
		{ key = 'exifXlatRating', 		default = true },	-- translate Lr star rating (XMP:rating) to PS keywords

		-- thumbnail parameters
		{ key = 'thumbGenerate',	default = true },	-- generate thumbs: yes or nos
		{ key = 'largeThumbs', 		default = true },	-- generate large thumbs or small thumbs
		{ key = 'thumbQuality', 	default = 80 },		-- conversion quality in percent
		{ key = 'thumbSharpness', 	default = 'MED' },	-- sharpening for thumbs
		{ key = 'isPS6', 			default = false },	-- use upload optimization for PhotoStation 6 (not THUMB_L required)

		-- video parameters
		{ key = 'addVideoHigh', 	default = 'None' },	-- additional video resolution for HIGH res videos
		{ key = 'addVideoMed',		default = 'None' }, -- additional video resolution for MEDIUM res videos
		{ key = 'addVideoLow', 		default = 'None' },	-- additional video resolution for LOW res videos	
		{ key = 'hardRotate', 		default = false }, 	-- Hard-rotate soft-rotated or meta-rotated videos 

		-- logging/debugging parameters
		{ key = 'logLevel', 		default = 2 },		-- loglevel 

		-- Publish Service Provider presets
		{ key = 'useFileStation',   	default = true },		-- use FileStation API for extended features via prim. server
		{ key = 'protoFileStation',		default = 'http' },		-- transport protocol for FileStation WEBAPI
		{ key = 'portFileStation',		default = '5000' },		-- port of the FileStation WEBAPI
		{ key = 'differentFSUser', 		default = false },		-- use a different user/password for FileStation WEBAPI
		{ key = 'usernameFileStation', 	default = '' },			-- account for FileStation WEBAPI
		{ key = 'passwordFileStation', 	default = '' },			-- guess what...

		{ key = 'useSecondAddress',		default = false },		-- specify a secondoray (external) server address
		{ key = 'proto2', 				default = 'https' },	-- transport protocol for secondary PhotoStation upload
		{ key = 'servername2', 			default = '' },			-- name/address of the secondary PhotoStation, may include ':port' extension
		{ key = 'serverTimeout2',	 	default = 10 },			-- http timeout
		{ key = 'useFileStation2',   	default = false },		-- use FileStation API for extended features via second. server
		{ key = 'protoFileStation2',	default = 'https' },	-- transport protocol for secondary FileStation WEBAPI
		{ key = 'portFileStation2',		default = '' },			-- port of the secondary FileStation WEBAPI

		{ key = 'publishMode', 			default = 'Publish' },	-- publish operation mode: Normal, CheckExisting, ...
}

exportServiceProvider.startDialog = PSUploadExportDialogSections.startDialog
exportServiceProvider.sectionsForBottomOfDialog = PSUploadExportDialogSections.sectionsForBottomOfDialog
	
exportServiceProvider.updateExportSettings = PSUploadTask.updateExportSettings
exportServiceProvider.processRenderedPhotos = PSUploadTask.processRenderedPhotos

--------------------------------------------------------------------------------

return exportServiceProvider
