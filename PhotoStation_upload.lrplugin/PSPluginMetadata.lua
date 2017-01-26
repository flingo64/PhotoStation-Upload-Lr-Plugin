--[[----------------------------------------------------------------------------

PSPluginMetadata.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2017, Martin Messmer

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
	schemaVersion = 17,
	
	metadataFieldsForPhotos = {
		{
			id = 'sharedAlbums',
--			dataType = 'string',
		},

		{
			id 			= 'commentCount',
			title 		= LOC "$$$/PSUpload/Metadat/commentCount=Comment Count",
			dataType 	= 'string',
			readOnly	= true,
			searchable	= true,
			browsable	= true,
			version		= 2
		},

		{
			id 			= 'lastCommentText',
			title 		= LOC "$$$/PSUpload/Metadat/LastCommentText=Last Comment",
			dataType 	= 'string',
			readOnly	= true,
			searchable	= true,
			browsable	= true,
		},

		{
			id 			= 'lastCommentAuthor',
			title 		= LOC "$$$/PSUpload/Metadat/LastCommentAuthor=Last Comment By",
			dataType 	= 'string',
			readOnly	= true,
			searchable	= true,
			browsable	= true,
		},

		{
			id 			= 'lastCommentDate',
			title 		= LOC "$$$/PSUpload/Metadat/LastCommentDate=Last Comment Date",
			dataType 	= 'string',
			readOnly	= true,
			searchable	= true,
			browsable	= true,
		},

		{
			id 			= 'lastCommentUrl',
			title 		= LOC "$$$/PSUpload/Metadat/LastCommentUrl=Last Comment Link",
			dataType 	= 'url',
			readOnly	= true,
			version		= 2
		},

		{
			id 			= 'lastCommentType',
			title 		= LOC "$$$/PSUpload/Metadat/LastCommentType=Last Comment Type",
			dataType 	= 'enum',
			values 		= {
    			{
    				value = 'private',
    				title = LOC "$$$/PSUpload/Metadat/LastCommentTypePrivate=Private"
    			},
    			{
    				value = 'public',
    				title = LOC "$$$/PSUpload/Metadat/LastCommentTypePublic=Public"
    			},
			},
			readOnly	= true,
			searchable	= true,
			browsable	= true,
		},

		{
			id 			= 'lastCommentSource',
			title 		= LOC "$$$/PSUpload/Metadat/LastCommentSource=Last Comment Collection",
			dataType 	= 'string',
			readOnly	= true,
			searchable	= true,
			browsable	= true,
		},
	},
}
