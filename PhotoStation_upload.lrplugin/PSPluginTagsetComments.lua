--[[----------------------------------------------------------------------------

PSPluginTagsetComments.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2021, Martin Messmer

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
	title = "Photo StatLr: " .. LOC "$$$/PSUpload/Tagsets/Comments/Title=Just Comments",
	id = 'photoStatLrTagsetComments',

	items = {
        { 'com.adobe.label', label = "Photo StatLr" },
		'de.messmer-online.lightroom.export.photostation_upload.lastCommentText',
		'de.messmer-online.lightroom.export.photostation_upload.lastCommentAuthor',
		'de.messmer-online.lightroom.export.photostation_upload.lastCommentDate',
		'de.messmer-online.lightroom.export.photostation_upload.lastCommentUrl',
		'de.messmer-online.lightroom.export.photostation_upload.lastCommentType',
		'de.messmer-online.lightroom.export.photostation_upload.lastCommentSource',
		'de.messmer-online.lightroom.export.photostation_upload.commentCount',

	},
}