--[[----------------------------------------------------------------------------

PSPluginTagsetCompact.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2015-2024, Martin Messmer

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

------------------------------------------------------------------------------]]

return {
	title = "Photo StatLr: " .. LOC "$$$/PSUpload/Tagsets/Compact/Title=Compact",
	id = 'photoStatLrTagsetCompact',

	items = {
         'com.adobe.filename',
        'com.adobe.folder',
        'com.adobe.captureTime',
        'com.adobe.duration',
        'com.adobe.captureDate',
        'com.adobe.GPS',

        'com.adobe.separator',
        'com.adobe.title',
        'com.adobe.caption',
        'com.adobe.copyright',
        'com.adobe.colorLabels',
        'com.adobe.rating',

        'com.adobe.separator',
--        { 'com.adobe.label', label = "Exif" },
        'com.adobe.model',
        'com.adobe.lens',
        'com.adobe.exposure',
        'com.adobe.focalLength',
        'com.adobe.focalLength35mm',
        'com.adobe.ISOSpeedRating',

        'com.adobe.separator',
--        { 'com.adobe.label', label = "Photo StatLr" },
		'de.messmer-online.lightroom.export.photostation_upload.lastCommentText',
		'de.messmer-online.lightroom.export.photostation_upload.lastCommentAuthor',
		'de.messmer-online.lightroom.export.photostation_upload.lastCommentUrl',

	},
}