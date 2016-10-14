--[[----------------------------------------------------------------------------

PSPluginMetadata.lua
Summary information for Photo StatLr
Copyright(c) 2016, Martin Messmer

This file is part of Photo StatLr - Lightroom plugin.

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
	
	metadataFieldsForPhotos = {
		{
			id = 'sharedAlbums',
			title = "Shared Albums",
--			dataType = 'string',
		},
	},
	
	schemaVersion = 1,
}