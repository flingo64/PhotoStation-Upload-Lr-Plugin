--[[----------------------------------------------------------------------------

Info.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2015-2022, Martin Messmer

Summary information for Photo StatLr

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
	- dcraw.exe, 			see: http://www.dechifro.org/dcraw/
	- exftool,				see: http://www.sno.phy.queensu.ca/~phil/exiftool/
	- ffmpeg.exe, 			see: https://www.ffmpeg.org/

This code is derived from the Lr SDK FTP Export and Flickr sample code. Copyright: see below
--------------------------------------------------------------------------------

ADOBE SYSTEMS INCORPORATED
 Copyright 2007 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.


------------------------------------------------------------------------------]]
plugin_major = 7
plugin_minor = 2
plugin_rev = 3
plugin_build = 20220808

pluginVersion = plugin_major .. '.' .. plugin_minor .. '.' ..plugin_rev .. '.' .. plugin_build
plugin_TkId = 'de.messmer-online.lightroom.export.photostation_upload'

return {

	LrSdkVersion = 5.0,
	LrSdkMinimumVersion = 4.0, -- minimum SDK version required by this plug-in

	LrToolkitIdentifier = plugin_TkId,

	LrPluginName = "Photo StatLr",

	LrInitPlugin = "PSInitPlugin.lua",

	LrPluginInfoUrl = "https://messmer-online.de/index.php/software/11-photo-statlr",

	LrPluginInfoProvider = 'PSPluginInfoProvider.lua',

	LrExportServiceProvider = {
		title = "Photo StatLr",
		file = 'PSExportServiceProvider.lua',
	},

	LrMetadataProvider 		= 'PSPluginMetadata.lua',
	LrMetadataTagsetFactory = { 'PSPluginTagsetCompact.lua',
								'PSPluginTagsetLong.lua',
								'PSPluginTagsetComments.lua', },

	LrLibraryMenuItems = {
		title = "Manage PS Shared Albums",
		file = "PSSharedAlbumDialog.lua",
	},

	VERSION = { major=plugin_major, minor=plugin_minor, revision=plugin_rev, build=plugin_build,
				-- display = '3.0.0-20150524 (Something)',
	},
}
