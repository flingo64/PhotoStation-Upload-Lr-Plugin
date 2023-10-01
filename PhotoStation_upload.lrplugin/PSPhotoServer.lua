--[[----------------------------------------------------------------------------

PSPhotoServer.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2015-2023, Martin Messmer

Definitions for southbound PhotoServer (PhotoStation or Photos) API

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

]]
--------------------------------------------------------------------------------

-- list of all supported southbound API provider

require "PSPhotoStationAPI"
require "PSPhotosAPI"

--======PhotoServer operation modes ===========================================--

PHOTOSERVER_USE_CACHE = true

--======PhotoServer capabilities ==============================================--

-- metadata support --
PHOTOSERVER_METADATA_TITLE 		    = "'META_TITLE'"            -- title
PHOTOSERVER_METADATA_DESCRIPTION	= "'META_DECRIPTION'"       -- description/caption
PHOTOSERVER_METADATA_RATING			= "'META_RATING'"           -- rating
PHOTOSERVER_METADATA_LABEL_PRIV 	= "'META_LABEL_PRIV'"       -- color labels in private/logged-in view
PHOTOSERVER_METADATA_LABEL_PUB		= "'META_LABEL_PUB'"        -- color labels in public/shared view
PHOTOSERVER_METADATA_GPS			= "'META_GPS'"              -- GPS coords
PHOTOSERVER_METADATA_TAG			= "'META_TAG'"              -- generic/description or person (w/o face region) tag/keyword
PHOTOSERVER_METADATA_LOCATION		= "'META_LOCATION'"         -- location tag (reverse geocoded address)
PHOTOSERVER_METADATA_FACE			= "'META_FACE'"             -- person tag w/ face region
PHOTOSERVER_METADATA_COMMENT_PRIV	= "'META_COMMENT_PRIV'"     -- comments in private/logged-in view
PHOTOSERVER_METADATA_COMMENT_PUB	= "'META_COMMENT_PUB'"      -- comments in public/shared view

-- list of uploadable photo items  --
PHOTOSERVER_UPLOAD_THUMBS 		    = "'UPLOAD_THUMBS'"
PHOTOSERVER_UPLOAD_TITLE			= "'UPLOAD_TITLE_FILE'"
PHOTOSERVER_UPLOAD_VIDEO_ADD		= "'UPLOAD_VIDEO_ADDITIONAL'"

-- album management capabilities  --
PHOTOSERVER_ALBUM_SORT	            = "'ALBUM_SORT'"

-- photo area capabilities  --
PHOTOSERVER_PERSONALAREA             = "'PERSONALAREA'"           -- support for personal area
PHOTOSERVER_PERSONALAREA_XUPLOAD     = "'PERDONALAREA_XUPLOAD'"   -- support for upload to personal area of different user

-- shared album support  --
PHOTOSERVER_SHAREDALBUM	            = "'SHAREDALBUM'"
PHOTOSERVER_SHAREDALBUM_ADVANCED	= "'SHAREDALBUM_ADVANCED'"

--======PhotoServer versions ==============================================--

PHOTOSERVER_API = {}

PHOTOSERVER_API[50] =  {
    name	        =   'Photo Station 5',
    API 	        =   PhotoStation,
    capabilities    =   PHOTOSERVER_METADATA_TITLE .. PHOTOSERVER_METADATA_DESCRIPTION .. PHOTOSERVER_METADATA_GPS ..
                        PHOTOSERVER_METADATA_TAG .. PHOTOSERVER_METADATA_LOCATION .. PHOTOSERVER_METADATA_FACE ..
                        PHOTOSERVER_METADATA_COMMENT_PRIV .. PHOTOSERVER_METADATA_COMMENT_PUB ..
                        PHOTOSERVER_UPLOAD_THUMBS ..
                        PHOTOSERVER_UPLOAD_TITLE .. PHOTOSERVER_UPLOAD_VIDEO_ADD,
    thumbs    = {
        XL          =   "1280",
        L           =   "800",
        B           =   "640",
        M           =   "320",
        S           =   "120",
    }
}

PHOTOSERVER_API[60] =  {
    name	        =   'Photo Station 6',
    API 	        =   PhotoStation,
    capabilities    =   PHOTOSERVER_METADATA_TITLE .. PHOTOSERVER_METADATA_DESCRIPTION .. PHOTOSERVER_METADATA_GPS ..
                        PHOTOSERVER_METADATA_TAG .. PHOTOSERVER_METADATA_LOCATION .. PHOTOSERVER_METADATA_FACE ..
                        PHOTOSERVER_METADATA_COMMENT_PRIV .. PHOTOSERVER_METADATA_COMMENT_PUB ..
                        PHOTOSERVER_UPLOAD_THUMBS ..
                        PHOTOSERVER_UPLOAD_TITLE .. PHOTOSERVER_UPLOAD_VIDEO_ADD ..
                        PHOTOSERVER_PERSONALAREA .. PHOTOSERVER_PERSONALAREA_XUPLOAD ..
                        PHOTOSERVER_ALBUM_SORT ..
                        PHOTOSERVER_SHAREDALBUM,
    thumbs    = {
        XL          =   "1280",
        B           =   "640",
        M           =   "320",
        S           =   "120",
    }
}

PHOTOSERVER_API[65] =  {
    name	        =   'Photo Station 6.5',
    API 	        =   PhotoStation,
    capabilities    =   PHOTOSERVER_API[60].capabilities ..
                        PHOTOSERVER_METADATA_RATING,
    thumbs          =   PHOTOSERVER_API[60].thumbs
}

PHOTOSERVER_API[66] =  {
    name	        =   'Photo Station 6.6',
    API 	        =   PhotoStation,
    capabilities    =   PHOTOSERVER_API[65].capabilities,
    thumbs          =   PHOTOSERVER_API[60].thumbs
}

PHOTOSERVER_API[67] =  {
    name	        =   'Photo Station 6.7',
    API 	        =   PhotoStation,
    capabilities    =   PHOTOSERVER_API[66].capabilities ..
                        PHOTOSERVER_METADATA_LABEL_PUB ..
                        PHOTOSERVER_SHAREDALBUM_ADVANCED,
    thumbs          =   PHOTOSERVER_API[60].thumbs
}

PHOTOSERVER_API[68] =  {
    name	        =   'Photo Station 6.8',
    API 	        =   PhotoStation,
    capabilities    =   PHOTOSERVER_API[67].capabilities,
    thumbs          =   PHOTOSERVER_API[60].thumbs
}

PHOTOSERVER_API[70] =  {
    name	        =   'Photos 1.0',
    API 	        =   Photos,
    capabilities    =   PHOTOSERVER_METADATA_DESCRIPTION ..
                        PHOTOSERVER_METADATA_TAG ..
                        PHOTOSERVER_UPLOAD_THUMBS ..
                        PHOTOSERVER_PERSONALAREA ..
                        PHOTOSERVER_SHAREDALBUM,
--                         PHOTOSERVER_SHAREDALBUM .. PHOTOSERVER_SHAREDALBUM_ADVANCED,
    thumbs          = {
        XL          =   "1280",
        M           =   "320",
        S           =   "240",
    }
}

PHOTOSERVER_API[71] =  {
    name	        =   'Photos 1.1',
    API 	        =   Photos,
    capabilities    =   PHOTOSERVER_API[70].capabilities ..
                        PHOTOSERVER_METADATA_RATING,
    thumbs          =   PHOTOSERVER_API[70].thumbs
}

PHOTOSERVER_API[72] =  {
    name	        =   'Photos 1.2',
    API 	        =   Photos,
    capabilities    =   PHOTOSERVER_API[71].capabilities,
    thumbs          =   PHOTOSERVER_API[70].thumbs
}

PHOTOSERVER_API[73] =  {
    name	        =   'Photos 1.3',
    API 	        =   Photos,
    capabilities    =   PHOTOSERVER_API[71].capabilities,
    thumbs          =   PHOTOSERVER_API[70].thumbs
}

---------------------------------------------------------------------------------------------------------
-- supports(h, metadataType)
function PHOTOSERVER_API.supports (version, capabilityType)
	return (string.find(PHOTOSERVER_API[version].capabilities, capabilityType) and true) or false
end
