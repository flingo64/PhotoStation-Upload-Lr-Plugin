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
	schemaVersion = 15,
	
	metadataFieldsForPhotos = {
		{
			id = 'sharedAlbums',
--			title = "Shared Albums",
--			dataType = 'string',
		},

		{
			id 			= 'lastCommentTime',
			title 		= LOC "$$$/PSUpload/Metadat/LastCommentTime=Last Comment Time",
			dataType 	= 'string',
			searchable	= true,
			browsable	= true,
			readOnly	= true,
		},

		{
			id 			= 'lastCommentType',
			title 		= LOC "$$$/PSUpload/Metadat/LastCommentType=Last Comment Type",
			dataType 	= 'enum',
			values 		= {
    			{
    				value = 'private',
    				title = "Private"
    			},
    			{
    				value = 'public',
    				title = "Public"
    			},
			},
			
			searchable	= true,
			browsable	= true,
			readOnly	= true,
		},

		{
			id 			= 'lastCommentSource',
			title 		= LOC "$$$/PSUpload/Metadat/LastCommentSource=Last Comment From",
			dataType 	= 'string',
			searchable	= true,
			browsable	= true,
			readOnly	= true,
		},

	},
}
