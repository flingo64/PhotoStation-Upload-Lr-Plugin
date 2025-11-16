--[[----------------------------------------------------------------------------

PhotoStationAPI.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2015-2025, Martin Messmer

Photo Station object:
	- new
	- login
	- logout

	- createTag

	- getPhotoExifs
	- editPhoto
	- getPhotoTags
	- addPhotoTag
	- getPhotoComments
	- addPhotoComments
	- movePhoto
	- deletePhoto

	- createAlbum
	- listAlbum
	- sortAlbumPhotos
	- deleteAlbum

	- getSharedAlbums
	- listSharedAlbum
	- createSharedAlbum
	- editSharedAlbum
	- addPhotosToSharedAlbum
	- renameSharedAlbum
	- deleteSharedAlbum

	- listPublicSharedAlbum
	- getPublicSharedAlbumLogList
	- getPublicSharedAlbumPhotoComments

	Photo Station Upload primitives:
	- createDir
	- uploadPicFile

	Photo Station Utilities:
	- getErrorMsg

	- getAlbumId
	- getAlbumUrl
	- getPhotoId
	- getPhotoUrl

	- getSharedAlbumId
	- isSharedAlbumPublic
	- getSharedAlbumShareId

	- getPhotoInfoFromList

	- getSharedPhotoPublicUrl
	- getPublicSharedPhotoColorLabel

	- createAndAddPhotoTag
	- createAndAddPhotoTagList

	- updateSharedAlbum
	- createAndAddPhotosToSharedAlbum
	- removePhotosFromSharedAlbum

	- deleteEmptyAlbumAndParents

PhotoStation Photo object:
	- new
	- getXxx
	- setXxx
	- addTags
	- removeTags
	- updateMetadata
	- updateTags


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

-- Lightroom API
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrHttp = import 'LrHttp'
local LrDate = import 'LrDate'

require "PSLrUtilities"

-- #####################################################################################################
-- ########################## PhotoStation object ######################################################
-- #####################################################################################################

PhotoStation = {}
PhotoStation_mt = { __index = PhotoStation }

--====== local vars and functions ============================================--

local PSAPIerrorMsgs = {
	[0]   = 'No error',
	[100] = 'Unknown error',
    [101] = 'No parameter of API, method or version',		-- PS 6.6: no such directory
    [102] = 'The requested API does not exist',
    [103] = 'The requested method does not exist',
    [104] = 'The requested version does not support the functionality',
    [105] = 'The logged in session does not have permission',
    [106] = 'Session timeout',
    [107] = 'Session interrupted by duplicate login',

    -- SYNO.PhotoStation.Info (401-405)

    -- SYNO.PhotoStation.Auth (406-415)
	[406] = 'PHOTOSTATION_AUTH_LOGIN_NOPRIVILEGE',
	[407] = 'PHOTOSTATION_AUTH_LOGIN_ERROR',
	[408] = 'PHOTOSTATION_AUTH_LOGIN_DISABLE_ACCOUNT',
	[409] = 'PHOTOSTATION_AUTH_LOGIN_GUEST_ERROR',
	[410] = 'PHOTOSTATION_AUTH_LOGIN_MAX_TRIES',

    -- SYNO.PhotoStaion.Album (416-425)
	[416] = 'PHOTOSTATION_ALBUM_PASSWORD_ERROR',
	[417] = 'PHOTOSTATION_ALBUM_NO_ACCESS_RIGHT',
	[418] = 'PHOTOSTATION_ALBUM_NO_UPLOAD_RIGHT',
	[419] = 'PHOTOSTATION_ALBUM_NO_MANAGE_RIGHT',
	[420] = 'PHOTOSTATION_ALBUM_NOT_ADMIN',
	[421] = 'PHOTOSTATION_ALBUM_HAS_EXIST',
	[422] = 'PHOTOSTATION_ALBUM_CREATE_FAIL',
	[423] = 'PHOTOSTATION_ALBUM_EDIT_FAIL',
	[424] = 'PHOTOSTATION_ALBUM_DELETE_FAIL',
	[425] = 'PHOTOSTATION_ALBUM_SELECT_CONFLICT',

    -- SYNO.PhotoStation.Permission (426-435)
	[426] = 'PHOTOSTATION_PERMISSION_BAD_PARAMS',
	[427] = 'PHOTOSTATION_PERMISSION_ACCESS_DENY',

    -- SYNO.PhotoStation.Tag (436-445)
	[436] = 'PHOTOSTATION_TAG_LIST_FAIL',
	[437] = 'PHOTOSTATION_TAG_GETINFO_FAIL',
	[438] = 'PHOTOSTATION_TAG_CREATE_FAIL',
	[439] = 'PHOTOSTATION_TAG_EDIT_FAIL',
	[440] = 'PHOTOSTATION_TAG_ACCESS_DENY',
	[441] = 'PHOTOSTATION_TAG_HAS_EXIST',
	[442] = 'PHOTOSTATION_TAG_SEARCH_FAIL',

    -- SYNO.PhotoStation.SmartAlbum (446-455)
	[446] = 'PHOTOSTATION_SMARTALBUM_CREATE_FAIL',
	[447] = 'PHOTOSTATION_SMARTALBUM_EDIT_FAIL',
	[448] = 'PHOTOSTATION_SMARTALBUM_ACCESS_DENY',
	[449] = 'PHOTOSTATION_SMARTALBUM_NOT_EXIST',
	[450] = 'PHOTOSTATION_SMARTALBUM_TAG_NOT_EXIST',
	[451] = 'PHOTOSTATION_SMARTALBUM_CREATE_FAIL_EXIST',

    -- SYNO.PhotoStation.Photo (456-465)
	[456] = 'PHOTOSTATION_PHOTO_BAD_PARAMS',
	[457] = 'PHOTOSTATION_PHOTO_ACCESS_DENY',
	[458] = 'PHOTOSTATION_PHOTO_SELECT_CONFLICT',

    -- SYNO.PhotoStation.PhotoTag (466-475)
	[466] = 'PHOTOSTATION_PHOTO_TAG_ACCESS_DENY',
	[467] = 'PHOTOSTATION_PHOTO_TAG_NOT_EXIST',
	[468] = 'PHOTOSTATION_PHOTO_TAG_DUPLICATE',
	[469] = 'PHOTOSTATION_PHOTO_TAG_VIDEO_NOT_EXIST',
	[470] = 'PHOTOSTATION_PHOTO_TAG_ADD_GEO_DESC_FAIL',
	[471] = 'PHOTOSTATION_PHOTO_TAG_ADD_PEOPLE_FAIL',
	[472] = 'PHOTOSTATION_PHOTO_TAG_DELETE_FAIL',
	[473] = 'PHOTOSTATION_PHOTO_TAG_PEOPLE_TAG_CONFIRM_FAIL',

    -- SYNO.PhotoStation.Category (476-490)
	[476] = 'PHOTOSTATION_CATEGORY_ACCESS_DENY',
	[477] = 'PHOTOSTATION_CATEGORY_WRONG_ID_FORMAT',
	[478] = 'PHOTOSTATION_CATEGORY_GETINFO_FAIL',
	[479] = 'PHOTOSTATION_CATEGORY_CREATE_FAIL',
	[480] = 'PHOTOSTATION_CATEGORY_DELETE_FAIL',
	[481] = 'PHOTOSTATION_CATEGORY_EDIT_FAIL',
	[482] = 'PHOTOSTATION_CATEGORY_ARRANGE_FAIL',
	[483] = 'PHOTOSTATION_CATEGORY_ADD_ITEM_FAIL',
	[484] = 'PHOTOSTATION_CATEGORY_LIST_ITEM_FAIL',
	[485] = 'PHOTOSTATION_CATEGORY_REMOVE_ITEM_FAIL',
	[486] = 'PHOTOSTATION_CATEGORY_ARRANGE_ITEM_FAIL',
	[487] = 'PHOTOSTATION_CATEGORY_DUPLICATE',

    -- SYNO.PhotoStation.Comment (491-495)
	[491] = 'PHOTOSTATION_COMMENT_VALIDATE_FAIL',
	[492] = 'PHOTOSTATION_COMMENT_ACCESS_DENY',
	[493] = 'PHOTOSTATION_COMMENT_CREATE_FAIL',

    -- SYNO.PhotoStation.Thumb (496-505)
	[501] = 'PHOTOSTATION_THUMB_BAD_PARAMS',
	[502] = 'PHOTOSTATION_THUMB_ACCESS_DENY',
	[503] = 'PHOTOSTATION_THUMB_NO_COVER',
	[504] = 'PHOTOSTATION_THUMB_FILE_NOT_EXISTS',

    -- SYNO.PhotoStation.Download (506-515)
	[506] = 'PHOTOSTATION_DOWNLOAD_BAD_PARAMS',
	[507] = 'PHOTOSTATION_DOWNLOAD_ACCESS_DENY',
	[508] = 'PHOTOSTATION_DOWNLOAD_CHDIR_ERROR',

    -- SYNO.PhotoStation.File (516-525)
	[516] = 'PHOTOSTATION_FILE_BAD_PARAMS',
	[517] = 'PHOTOSTATION_FILE_ACCESS_DENY',
	[518] = 'PHOTOSTATION_FILE_FILE_EXT_ERR',
	[519] = 'PHOTOSTATION_FILE_DIR_NOT_EXISTS',
	[520] = 'PHOTOSTATION_FILE_UPLOAD_ERROR',
	[521] = 'PHOTOSTATION_FILE_NO_FILE',
	[522] = 'PHOTOSTATION_FILE_UPLOAD_CANT_WRITE',

    -- SYNO.PhotoStation.Cover (526-530)
	[526] = 'PHOTOSTATION_COVER_ACCESS_DENY',
	[527] = 'PHOTOSTATION_COVER_ALBUM_NOT_EXIST',
	[528] = 'PHOTOSTATION_COVER_PHOTO_VIDEO_NOT_EXIST',
	[529] = 'PHOTOSTATION_COVER_PHOTO_VIDEO_NOT_IN_ALBUM',
	[530] = 'PHOTOSTATION_COVER_SET_FAIL',

    -- SYNO.PhotoStation.Rotate (531-535)
	[531] = 'PHOTOSTATION_ROTATE_ACCESS_DENY',
	[532] = 'PHOTOSTATION_ROTATE_SET_FAIL',

    -- SYNO.PhotoStation.SlideshowMusic (536-545)
	[536] = 'PHOTOSTATION_SLIDESHOWMUSIC_ACCESS_DENY',
	[537] = 'PHOTOSTATION_SLIDESHOWMUSIC_SET_FAIL',
	[538] = 'PHOTOSTATION_SLIDESHOWMUSIC_FILE_EXT_ERR',
	[539] = 'PHOTOSTATION_SLIDESHOWMUSIC_UPLOAD_ERROR',
	[540] = 'PHOTOSTATION_SLIDESHOWMUSIC_NO_FILE',
	[541] = 'PHOTOSTATION_SLIDESHOWMUSIC_EXCEED_LIMIT',

    -- SYNO.PhotoStation.DsmShare (546-550)
	[546] = 'PHOTOSTATION_DSMSHARE_UPLOAD_ERROR',
	[547] = 'PHOTOSTATION_DSMSHARE_ACCESS_DENY',

    -- SYNO.PhotoStation.SharedAlbum (551-560)
	[551] = 'PHOTOSTATION_SHARED_ALBUM_ACCESS_DENY',
	[552] = 'PHOTOSTATION_SHARED_ALBUM_BAD_PARAMS',
	[553] = 'PHOTOSTATION_SHARED_ALBUM_HAS_EXISTED',
	[554] = 'PHOTOSTATION_SHARED_ALBUM_CREATE_FAIL',
	[555] = 'PHOTOSTATION_SHARED_ALBUM_NOT_EXISTS',
	[556] = 'PHOTOSTATION_SHARED_ALBUM_GET_INFO_ERROR',
	[557] = 'PHOTOSTATION_SHARED_ALBUM_LIST_ERROR',

    -- SYNO.PhotoStation.Log (561-565)
	[561] = 'PHOTOSTATION_LOG_ACCESS_DENY',

    -- SYNO.PhotoStation.PATH (566-570)
	[566] = 'PHOTOSTATION_PATH_ACCESS_DENY',

    -- SYNO.PhotoStation.ACL (571-580)
	[571] = 'PHOTOSTATION_ACL_NOT_SUPPORT',
	[572] = 'PHOTOSTATION_ACL_CONVERT_FAIL',

    -- SYNO.PhotoStation.AdvancedShare (581-590)
	[581] = 'PHOTOSTATION_PHOTO_AREA_TAG_ADD_FAIL',
	[582] = 'PHOTOSTATION_PHOTO_AREA_TAG_NOT_ENABLED',
	[583] = 'PHOTOSTATION_PHOTO_AREA_TAG_DELETE_FAIL',

    -- Lr HTTP errors
	[1001]  = 'Http error: no response body, no response header',
	[1002]  = 'Http error: no response data, no errorcode in response header',
	[1003]  = 'Http error: No JSON response data',
	[12002] = 'Http error: requestTimeout',
	[12007] = 'Http error: cannotFindHost',
	[12029] = 'Http error: cannotConnectToHost',
	[12038] = 'Http error: serverCertificateHasUnknownRoot',
}

--[[
PhotoStation.callSynoAPI (h, synoAPI, formData)
	calls the named synoAPI with the respective parameters in formData
	returns nil, on http error
	returns the decoded JSON response as table on success
]]
function PhotoStation.callSynoAPI (h, synoAPI, formData)
	local postHeaders = {
		{ field = 'Content-Type', value = 'application/x-www-form-urlencoded' },
	}

	local postBody = 'api=' .. synoAPI .. '&' .. formData

	if synoAPI == 'SYNO.PhotoStation.Auth' then
		writeLogfile(4, "PhotoStation.callSynoAPI: LrHttp.post(" .. h.serverUrl .. h.psWebAPI .. h.apiInfo[synoAPI].path .. ",...)\n")
	else
		writeLogfile(4, string.format("PhotoStation.callSynoAPI: LrHttp.post(%s%s%s, api=%s&%s\n", h.serverUrl, h.psWebAPI, h.apiInfo[synoAPI].path, synoAPI, formData))
	end

	local respBody, respHeaders = LrHttp.post(h.serverUrl .. h.psWebAPI .. h.apiInfo[synoAPI].path, postBody, postHeaders, 'POST', h.serverTimeout, string.len(postBody))

	if not respBody then
	    writeTableLogfile(3, 'respHeaders', respHeaders)
    	if respHeaders then
      		writeLogfile(3, string.format("Error %s on http request: %s\n",
      				ifnil(respHeaders["error"].errorCode, 'Unknown'),
          			trim(ifnil(respHeaders["error"].name, 'Unknown error description'))))
    		local errorCode = tonumber(ifnil(respHeaders["error"].nativeCode, '1002'))
      		return nil, errorCode
    	else
      		return nil, 1001
    	end
	end
	writeLogfile(4, "Got Body:\n" .. string.sub(respBody, 1, 4096) .. iif(string.len(respBody) > 4096, "...", "") .. "\n")
	writeLogfile(5, "Got Body(full):\n" .. respBody .. "\n")

	local respArray = JSON:decode(respBody, "PhotoStation.callSynoAPI(" .. synoAPI .. ")")

	if not respArray then return nil, 1003 end

	if respArray.error then
		local errorCode = tonumber(respArray.error.code)
		writeLogfile(3, string.format('PhotoStation.callSynoAPI: %s returns error %d\n', synoAPI, errorCode))
		return nil, errorCode
	end

	return respArray
end


-- ########################## session management #######################################################
---------------------------------------------------------------------------------------------------------
-- new: set serverUrl, loginPath and uploadPath
function PhotoStation.new(serverUrl, usePersonalPS, personalPSOwner, serverTimeout, version, username, password, otp)
	local h = {} -- the handle
	local apiInfo = {}
	local psPath = iif(usePersonalPS, "/~" .. ifnil(personalPSOwner, "unknown") .. "/photo/", "/photo/")

	writeLogfile(4, string.format("PhotoStation.new(url=%s, personal=%s, persUser=%s, timeout=%d, version=%d, username=%s, password=***, otp=***)\n",
                                    serverUrl, usePersonalPS, personalPSOwner, serverTimeout, version, username))

	h.serverUrl 	= serverUrl
	h.serverTimeout = serverTimeout
	h.serverVersion	= version
    h.username	    = username
    h.password	    = password
    h.otp 			= otp

	h.psAlbumRoot	= psPath .. '#!Albums'
	h.psWebAPI 		= psPath .. 'webapi/'
	h.uploadPath 	= psPath .. 'include/asst_file_upload.php'

	-- bootstrap the apiInfo table
	apiInfo['SYNO.API.Info'] = {
		path		= "query.php",
		minVersion	= 1,
		maxVersion	= 1,
	}
	h.apiInfo = apiInfo

	-- get all API paths via 'SYNO.API.Info'
	local formData =
			'query=all&' ..
			'method=query&' ..
			'version=1&' ..
			'ps_username='

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.API.Info', formData)

	if not respArray then return nil, errorCode end

	h.Photo 	= PhotoStationPhoto.new()
	h.serverCapabilities = PHOTOSERVER_API[version].capabilities
	h.thumbs 			 = PHOTOSERVER_API[version].thumbs

	writeLogfile(3, 'PhotoStation.new() returns:\n' .. string.gsub(JSON:encode(h), '"password":"[^"]+"', '"password":"***"') .. "\n")

	-- rewrite the apiInfo table with API infos retrieved via SYNO.API.Info
	h.apiInfo 	= respArray.data

	return setmetatable(h, PhotoStation_mt)
end

---------------------------------------------------------------------------------------------------------
-- supports(h, metadataType)
function PhotoStation.supports (h, capabilityType)
	return PHOTOSERVER_API.supports (h.serverVersion, capabilityType)
end

---------------------------------------------------------------------------------------------------------
-- isSupportedVideoContainer(h, videoExt)
function PhotoStation.isSupportedVideoContainer (h, videoExt)
	return PHOTOSERVER_API.isSupportedVideoContainer (h.serverVersion, videoExt)
end

---------------------------------------------------------------------------------------------------------
-- isSupportedVideoCodec(h, vinfo)
function PhotoStation.isSupportedVideoCodec (h, vinfo)
	return PHOTOSERVER_API.isSupportedVideoCodec (h.serverVersion, vinfo)
end

---------------------------------------------------------------------------------------------------------
-- validateServername(view, servername)
-- a valid servername looks like
-- 		<name_or_ip> or 
-- 		<name_or_ip>:<psPort>
function PhotoStation.validateServername (view, servername)
	local colon			= string.match(servername, '[^:/]+(:)')
	local port			= string.match(servername, '[^:]+:(%d+)$')
	local slash			= string.match(servername, '(/)')

	writeLogfile(5, string.format("PhotoStation.validateServername('%s'): port '%s'\n", servername, ifnil(port, '<nil>')))

	return	(not colon and not port and not slash)
		or	(	 colon and 	   port and not slash),
		servername
end

---------------------------------------------------------------------------------------------------------
-- basedir(serverUrl, area, owner)
function PhotoStation.basedir (serverUrl, area, owner)
	if area == 'personal' then
		return "/~" .. ifnil(owner, "unknown") .. "/photo/"
	else
		return "/photo/"
	end
end


---------------------------------------------------------------------------------------------------------
-- login(h)
-- does, what it says
function PhotoStation.login(h)
	local formData = 'method=login&' ..
					 'version=1&' ..
--					 'enable_syno_token=true&' ..
					 'username=' .. urlencode(h.username) .. '&' ..
					 'password=' .. urlencode(h.password) .. '&' ..
					 'otp_code=' .. otp

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.Auth', formData)

	if not respArray then return false, errorCode end

	return respArray.success
end

---------------------------------------------------------------------------------------------------------

-- logout(h)
-- nothing to do here, invalidating the cookie would be perfect here
function PhotoStation.logout (h)
	return true
end

-- ########################## tag management ###########################################################

---------------------------------------------------------------------------------------------------------
-- PhotoStation_getTagList (h, type)
-- get table of tagId/tagString mappings for given type: desc, people, geo
function PhotoStation_getTagList(h, type)
	local formData = 'method=list&' ..
					 'version=1&' ..
					 'type=' .. type .. '&' ..
--					 'additional=info&' ..
					 'offset=0&' ..
					 'limit=-1'

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.Tag', formData)

	if not respArray then return nil, errorCode end

	writeLogfile(3, string.format('getTags returns %d tags.\n', respArray.data.total))
	return respArray.data.tags
end

---------------------------------------------------------------------------------------------------------
-- createTag (h, type, name)
-- create a new tagId/tagString mapping of or given type: desc, people, geo
function PhotoStation.createTag(h, type, name)
	local formData = 'method=create&' ..
					 'version=1&' ..
					 'type=' .. type .. '&' ..
					 'name=' .. urlencode(name)

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.Tag', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('createTag(%s, %s) returns tagId %s.\n', type, name, respArray.data.id))
	return respArray.data.id
end

-- ########################## photo management #########################################################

---------------------------------------------------------------------------------------------------------
-- getPhotoExifs (h, dstFilename, isVideo)
function PhotoStation.getPhotoExifs (h, dstFilename, isVideo)
	local formData = 'method=getexif&' ..
					 'version=1&' ..
					 'id=' .. PhotoStation.getPhotoId(h, dstFilename, isVideo)

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.Photo', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('getPhotoExifs(%s) returns %d exifs.\n', dstFilename, respArray.data.total))
	return respArray.data.exifs
end

---------------------------------------------------------------------------------------------------------
-- editPhoto (h, dstFilename, isVideo, attrValPairs)
-- edit specific metadata field of a photo
function PhotoStation.editPhoto(h, dstFilename, isVideo, attrValPairs)
	local formData = 'method=edit&' ..
					 'version=1&' ..
					 'id=' .. PhotoStation.getPhotoId(h, dstFilename, isVideo)
	local logMessage = ''

	for i = 1, #attrValPairs do
	 	formData = formData .. '&' 		.. attrValPairs[i].attribute .. '=' .. urlencode(attrValPairs[i].value)
	 	logMessage = logMessage .. ', ' .. attrValPairs[i].attribute .. '=' .. attrValPairs[i].value
	end

	local success, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.Photo', formData)

	if not success then return false, errorCode end

	writeLogfile(3, string.format('editPhoto(%s,%s) returns OK.\n', dstFilename, logMessage))
	return logMessage
end

---------------------------------------------------------------------------------------------------------
-- getPhotoTags (h, dstFilename, isVideo)
-- get table of tags (general,people,geo) of a photo
function PhotoStation.getPhotoTags(h, dstFilename, isVideo)
	local formData = 'method=list&' ..
					 'version=1&' ..
					 'type=people,geo,desc&' ..
					 'additional=info&' ..
					 'id=' .. PhotoStation.getPhotoId(h, dstFilename, isVideo)

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.PhotoTag', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('getPhotoTags(%s) returns %d tags.\n', dstFilename, #respArray.data.tags))
	return respArray.data.tags
end

---------------------------------------------------------------------------------------------------------
-- addPhotoTag (h, dstFilename, isVideo, tagId, addinfo)
-- add a new tag (general,people,geo) to a photo
function PhotoStation.addPhotoTag(h, dstFilename, isVideo, type, tagId, addinfo)
	local formData = 'method=' .. type .. '_tag&' ..
					 'version=1&' ..
					 'tag_id=' .. tagId .. '&' ..
					 'id=' .. PhotoStation.getPhotoId(h, dstFilename, isVideo)
	if type == 'people' and addinfo then
		formData = formData ..
        			 iif(addinfo.xLeft,	'&x=' 		.. ifnil(addinfo.xLeft,''), '') ..
        			 iif(addinfo.yUp,	'&y=' 		.. ifnil(addinfo.yUp,''), '')  ..
        			 iif(addinfo.width,	'&width=' 	.. ifnil(addinfo.width,''), '') ..
        			 iif(addinfo.height,'&height='	.. ifnil(addinfo.height,''), '')
	elseif type == 'geo' and addinfo then
		formData = formData ..
        			 iif(addinfo.address,	'&address='		.. ifnil(addinfo.address,''), '') ..
        			 iif(addinfo.lat,		'&lat=' 		.. ifnil(addinfo.lat,''), '') ..
        			 iif(addinfo.lng,		'&lng=' 		.. ifnil(addinfo.lng,''), '')  ..
        			 iif(addinfo.place_id,	'&place_id=' 	.. ifnil(addinfo.place_id,''), '')
	end

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.PhotoTag', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format("addPhotoTag('%s', '%s') returns %d item_tag_ids.\n", dstFilename, tagId, #respArray.data.item_tag_ids))
	return respArray.data.item_tag_ids
end

---------------------------------------------------------------------------------------------------------
-- removePhotoTag(h, dstFilename, isVideo, tagType, itemTagId)
-- remove a tag from a photo
function PhotoStation.removePhotoTag(h, dstFilename, isVideo, tagType, itemTagId)
	local formData = 'method=delete&' ..
					 'version=1&' ..
					 'item_tag_id=' .. itemTagId .. '&' ..
					 'id=' .. PhotoStation.getPhotoId(h, dstFilename, isVideo)


	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.PhotoTag', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format("removePhotoTag('%s', '%s') returns %s\n", dstFilename, itemTagId, respArray.success))
	return respArray.success
end


---------------------------------------------------------------------------------------------------------
-- getPhotoComments (h, dstFilename, isVideo)
function PhotoStation.getPhotoComments (h, dstFilename, isVideo)
	local formData = 'method=list&' ..
					 'version=1&' ..
					 'id=' .. PhotoStation.getPhotoId(h, dstFilename, isVideo)

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.Comment', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('getPhotoComments(%s) returns OK.\n', dstFilename))
	return respArray.data.comments
end

---------------------------------------------------------------------------------------------------------
-- addPhotoComment (h, dstFilename, isVideo, comment, username)
function PhotoStation.addPhotoComment (h, dstFilename, isVideo, comment, username)
	local formData = 'method=create&' ..
					 'version=1&' ..
					 'id=' .. PhotoStation.getPhotoId(h, dstFilename, isVideo) .. '&' ..
					 'name=' .. username .. '&' ..
					 'comment='.. urlencode(comment)

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.Comment', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('addPhotoComment(%s, %s, %s) returns OK.\n', dstFilename, comment, username))
	return respArray.success
end

---------------------------------------------------------------------------------------------------------
-- movePhoto (h, srcFilename, dstAlbum, isVideo)
function PhotoStation.movePhoto(h, srcFilename, dstAlbum, isVideo)
	local formData = 'method=copy&' ..
					 'version=1&' ..
					 'mode=move&' ..
					 'duplicate=ignore&' ..
					 'id=' .. PhotoStation.getPhotoId(h, srcFilename, isVideo) .. '&' ..
					 'sharepath=' .. PhotoStation.getAlbumId(h, dstAlbum)

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.Photo', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('movePhoto(%s, %s) returns OK\n', srcFilename, dstAlbum))
	return respArray.success

end

---------------------------------------------------------------------------------------------------------
-- deletePhoto (h, dstFilename, isVideo)
function PhotoStation.deletePhoto (h, dstFilename, isVideo)
	local formData = 'method=delete&' ..
					 'version=1&' ..
					 'id=' .. PhotoStation.getPhotoId(h, dstFilename, isVideo)

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.Photo', formData)

	if not respArray and errorCode ~= 101 then return false, errorCode end

	writeLogfile(3, string.format('deletePhoto(%s) returns OK (errorCode was %d)\n', dstFilename, ifnil(errorCode, 0)))
---@diagnostic disable-next-line: need-check-nil
	return respArray.success
end

-- ########################## album management #########################################################

---------------------------------------------------------------------------------------------------------
-- createAlbum(h, name)
function PhotoStation.createAlbum(h, parentAlbum, newAlbum)
	local formData = 'method=create&' ..
					 'version=1&' ..
					 'id=' .. PhotoStation.getAlbumId(h, parentAlbum) .. '&' ..
					 'name=' .. urlencode(newAlbum)

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.Album', formData)

	if not respArray and errorCode == 421 then
		writeLogfile(2, string.format("createAlbum('%s', '%s'): already exists, returns OK.\n", parentAlbum, newAlbum))
		return true
	end
	if not respArray then return false, errorCode end

	writeLogfile(2, string.format("createAlbum('%s', '%s'): new id '%s', returns OK.\n", parentAlbum, newAlbum, respArray.data.id))
	return true
end


---------------------------------------------------------------------------------------------------------
-- listAlbum: returns all photos/videos and optionally albums in a given album
-- returns
--		albumItems:		table of photo infos, if success, otherwise nil
--		errorcode:		errorcode, if not success
function PhotoStation.listAlbum(h, dstDir, listItems)
	-- recursive doesn't seem to work
	local formData = 'method=list&' ..
					 'version=1&' ..
					 'id=' .. PhotoStation.getAlbumId(h, dstDir) .. '&' ..
					 'type=' .. listItems .. '&' ..
					 'offset=0&' ..
					 'limit=-1&' ..
					 'recursive=false&'..
					 'additional=album_permission,photo_exif'
--					 'additional=album_permission,photo_exif,video_codec,video_quality,thumb_size,file_location'

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.Album', formData)

	if not respArray then return nil, errorCode end

	writeTableLogfile(5, 'listAlbum(' .. dstDir .. ')', respArray.data.items)
	return respArray.data.items
end

---------------------------------------------------------------------------------------------------------
-- sortAlbumPhotos (h, albumPath, sortedPhotos)
function PhotoStation.sortAlbumPhotos (h, albumPath, sortedPhotos)
	local formData = 'method=arrangeitem&' ..
					 'version=1&' ..
					 'offset=0&' ..
					 'limit='.. #sortedPhotos .. '&' ..
					 'id=' .. PhotoStation.getAlbumId(h, albumPath)
	local item_ids = {}

	for i, _ in ipairs(sortedPhotos) do
		if i == 1 then
			item_ids = PhotoStation.getPhotoId(h, sortedPhotos[i])
		else
			item_ids = item_ids .. ',' .. PhotoStation.getPhotoId(h, sortedPhotos[i])
		end
	end

	formData = formData .. '&item_id=' .. item_ids

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.Album', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('sortAlbumPhotos(%s) returns OK.\n', albumPath))
	return respArray.success
end

---------------------------------------------------------------------------------------------------------
-- deleteAlbum(h, albumPath)
function PhotoStation.deleteAlbum (h, albumPath)
	local formData = 'method=delete&' ..
					 'version=1&' ..
					 'id=' .. PhotoStation.getAlbumId(h, albumPath)

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.Album', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('deleteAlbum(%s) returns OK\n', albumPath))
	return respArray.success
end

-- ########################## shared album management ##################################################

PhotoStation.sharedAlbumDefaults = {
	isAdvanced			= true,
    isPublic			= true,
    publicPermissions   = 'View',
    sharedAlbumPassword	= '',
	startTime			= '',
	stopTime 			= '',
	colorRed			= true,
	colorYellow			= true,
	colorGreen			= true,
	colorBlue			= true,
	colorPurple			= true,
	comments			= true,
	areaTool			= true,
	privateUrl			= '',
	publicUrl			= '',
	publicUrl2			= '',
}

---------------------------------------------------------------------------------------------------------
-- getSharedAlbums (h)
-- get table of sharedAlbumId/sharedAlbumName mappings
function PhotoStation.getSharedAlbums(h)
	local formData = 'method=list&' ..
					 'version=1&' ..
					 'additional=public_share&' ..
					 'offset=0&' ..
					 'limit=-1'

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.SharedAlbum', formData)

	if not respArray then return nil, errorCode end

	writeLogfile(3, string.format('getSharedAlbums() returns %d albums.\n', respArray.data.total))
	return respArray.data.items
end

---------------------------------------------------------------------------------------------------------
-- listSharedAlbum: returns all photos/videos in a given shared album
-- returns
--		albumItems:		table of photo infos, if success, otherwise nil
--		errorcode:		errorcode, if not success
function PhotoStation.listSharedAlbum(h, sharedAlbumName, listItems)
	local albumId  = PhotoStation.getSharedAlbumId(h, sharedAlbumName)
	if not albumId then
		writeLogfile(3, string.format('listSharedAlbum(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end

	local formData = 'method=list&' ..
					 'version=1&' ..
					 'filter_shared_album=' .. albumId .. '&' ..
					 'type=' .. listItems .. '&' ..
					 'offset=0&' ..
					 'limit=-1&' ..
					 'recursive=false&'..
					 'additional=photo_exif'
--					 'additional=photo_exif,video_codec,video_quality,thumb_size'

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.Photo', formData)

	if not respArray then return nil, errorCode end

	writeTableLogfile(5, 'listSharedAlbum', respArray.data.items)
	return respArray.data.items
end

---------------------------------------------------------------------------------------------------------
-- PhotoStattion_createSharedAlbumSimple(h, name)
local function PhotoStation_createSharedAlbumSimple(h, sharedAlbumName)
	local formData = 'method=create&' ..
					 'version=1&' ..
					 'name=' .. urlencode(sharedAlbumName)

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.SharedAlbum', formData)

	if not respArray then return false, errorCode end

	writeLogfile(2, string.format('PhotoStation_createSharedAlbumSimple(%s) returns sharedAlbumId %s.\n', sharedAlbumName, respArray.data.id))
	return respArray.data.id
end

---------------------------------------------------------------------------------------------------------
-- editSharedAlbum(h, sharedAlbumName, sharedAlbumAttributes)
function PhotoStation.editSharedAlbum(h, sharedAlbumName, sharedAlbumAttributes)
	local albumId  = PhotoStation.getSharedAlbumId(h, sharedAlbumName)
	if not albumId then
		writeLogfile(3, string.format('editSharedAlbum(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end

	local numAttributes = 0
	local formData = 'method=edit_public_share&' ..
					 'version=1&' ..
					 'id=' .. albumId

	for attr, value in pairs(sharedAlbumAttributes) do
		formData = formData .. '&' .. attr .. '=' .. urlencode(tostring(value))
		numAttributes = numAttributes + 1
	end

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.SharedAlbum', formData)

	if not respArray then return nil, errorCode end

	writeLogfile(3, string.format('editSharedAlbum(%s, %d attributes) returns shareId %s.\n', sharedAlbumName, numAttributes, respArray.data.shareid))
	return respArray.data
end

---------------------------------------------------------------------------------------------------------
-- PhotoStation.addPhotosToSharedAlbum(h, sharedAlbumName, photos)
-- add photos to Shared Album
function PhotoStation.addPhotosToSharedAlbum(h, sharedAlbumName, photos)
	local albumId  = PhotoStation.getSharedAlbumId(h, sharedAlbumName)
	if not albumId then
		writeLogfile(3, string.format('addPhotosToSharedAlbum(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end

	local photoIds = {}
	for i = 1, #photos do
		photoIds[i] = PhotoStation.getPhotoId(h, photos[i].dstFilename, photos[i].isVideo)
	end
	local itemList = table.concat(photoIds, ',')
	local formData = 'method=add_items&' ..
				 'version=1&' ..
				 'id=' ..  albumId .. '&' ..
				 'item_id=' .. itemList

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.SharedAlbum', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('addPhotosToSharedAlbum(%s, %d photos) returns OK.\n', sharedAlbumName, #photos))
	return true
end

---------------------------------------------------------------------------------------------------------
-- PhotoStation_removePhotosFromSharedAlbum(h, albumId, photoIds)
-- remove photos from Shared Album
local function PhotoStation_removePhotosFromSharedAlbum(h, albumId, photoIds)
	writeLogfile(3, string.format('PhotoStation_removePhotosFromSharedAlbum(%d):...\n', albumId))

	local itemList = table.concat(photoIds, ',')
	local formData = 'method=remove_items&' ..
				 'version=1&' ..
				 'id=' .. albumId .. '&' ..
				 'item_id=' .. itemList

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.SharedAlbum', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('PhotoStation_removePhotosFromSharedAlbum(%d, %d photos) returns OK.\n', albumId, #photoIds))
	return true
end

--[[ currently not needed
---------------------------------------------------------------------------------------------------------
-- addSharedPhotoComment (h, dstFilename, isVideo, comment, username, sharedAlbumName)
function PhotoStation.addSharedPhotoComment (h, dstFilename, isVideo, comment, username, sharedAlbumName)
	local formData = 'method=add_comment&' ..
					 'version=1&' ..
					 'item_id=' .. PhotoStation.getPhotoId(h, dstFilename, isVideo) .. '&' ..
					 'name=' .. username .. '&' ..
					 'comment='.. urlencode(comment) ..'&' ..
					 'public_share_id=' .. PhotoStation.getSharedAlbumShareId(h, sharedAlbumName)

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.AdvancedShare', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('addSharedPhotoComment(%s, %s, %s, %s) returns OK.\n', dstFilename, sharedAlbumName, comment, username))
	return respArray.success
end
]]

---------------------------------------------------------------------------------------------------------
-- renameSharedAlbum(h, sharedAlbumName, newSharedAlbumName)
function PhotoStation.renameSharedAlbum(h, sharedAlbumName, newSharedAlbumName)
	local albumId  = PhotoStation.getSharedAlbumId(h, sharedAlbumName)
	if not albumId then
		writeLogfile(3, string.format('renameSharedAlbum(%s, %s): album not found!\n', sharedAlbumName, newSharedAlbumName))
		return false, 555
	end

	local formData = 'method=edit&' ..
					 'version=1&' ..
					 'name='  ..  newSharedAlbumName .. '&' ..
					 'id=' .. albumId

	local success, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.SharedAlbum', formData)

	if not success then return false, errorCode end

	writeLogfile(3, string.format('renameSharedAlbum(%s, %s) returns OK.\n', sharedAlbumName, newSharedAlbumName))
	return true
end

---------------------------------------------------------------------------------------------------------
-- deleteSharedAlbum(h, sharedAlbumName)
function PhotoStation.deleteSharedAlbum(h, sharedAlbumName)
	local albumId  = PhotoStation.getSharedAlbumId(h, sharedAlbumName)
	if not albumId then
		writeLogfile(3, string.format('deleteSharedAlbum(%s): album not found, returning OK anyway!\n', sharedAlbumName))
		return true
	end

	local formData = 'method=delete&' ..
					 'version=1&' ..
					 'id=' .. albumId

	local success, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.SharedAlbum', formData)

	if not success then return false, errorCode end

	writeLogfile(3, string.format('deleteSharedAlbum(%s) returns OK.\n', sharedAlbumName))
	return true
end

-- ########################## public shared album management ###########################################

---------------------------------------------------------------------------------------------------------
-- listPublicSharedAlbum: returns all photos/videos in a given public shared album
-- returns
--		albumItems:		table of photo infos, if success, otherwise nil
--		errorcode:		errorcode, if not success
function PhotoStation.listPublicSharedAlbum(h, sharedAlbumName, listItems)
	local shareId  = PhotoStation.getSharedAlbumShareId(h, sharedAlbumName)
	if not shareId then
		writeLogfile(3, string.format('listPublicSharedAlbum(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end

	local formData = 'method=list&' ..
					 'version=1&' ..
					 'filter_public_share=' .. shareId .. '&' ..
					 'type=' .. listItems .. '&' ..
					 'offset=0&' ..
					 'limit=-1&' ..
					 'color_label=0,1,2,3,4,5,6&'..
					 'additional=photo_exif'

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.Photo', formData)

	if not respArray then return nil, errorCode end

	writeTableLogfile(5, 'listPublicSharedAlbum', respArray.data.items)
	return respArray.data.items
end

---------------------------------------------------------------------------------------------------------
-- getPublicSharedAlbumInfo (h, sharedAlbumName)
function PhotoStation.getPublicSharedAlbumInfo (h, sharedAlbumName)
	local shareId  = PhotoStation.getSharedAlbumShareId(h, sharedAlbumName)
	if not shareId then
		writeLogfile(3, string.format('getPublicSharedAlbumInfo(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end

	local formData = 'method=getinfo_public&' ..
					 'version=1&' ..
					 'public_share_id=' .. shareId

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.SharedAlbum', formData)

	if not respArray then return false, errorCode end

	if respArray.data then
		writeLogfile(3, string.format('getPublicSharedAlbumInfo(%s) returns infos for album id %d.\n', sharedAlbumName, respArray.data.shared_album.id))
		return respArray.data.sharedAlbum
	else
		writeLogfile(3, string.format('getPublicSharedAlbumInfo(%s) returns no info.\n', sharedAlbumName))
		return nil
	end
end

---------------------------------------------------------------------------------------------------------
-- getPublicSharedAlbumLogList (h, sharedAlbumName)
function PhotoStation.getPublicSharedAlbumLogList (h, sharedAlbumName)
	local shareId  = PhotoStation.getSharedAlbumShareId(h, sharedAlbumName)
	if not shareId then
		writeLogfile(3, string.format('getPublicSharedAlbumLogList(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end

	local formData = 'method=list_log&' ..
					 'version=1&' ..
					 'offset=0&' ..
					 'limit=-1&' ..
					 'category=all&' ..
					 'public_share_id=' .. shareId

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.AdvancedShare', formData)

	if not respArray then return false, errorCode end

	if respArray.data then
		writeLogfile(3, string.format('getPublicSharedAlbumLogList(%s) returns %d logs.\n', sharedAlbumName, respArray.data.total))
	else
		writeLogfile(3, string.format('getPublicSharedAlbumLogList(%s) returns no logs.\n', sharedAlbumName))
	end
	return respArray.data.data
end

---------------------------------------------------------------------------------------------------------
-- getPublicSharedPhotoComments (h, sharedAlbumName, dstFilename, isVideo)
function PhotoStation.getPublicSharedPhotoComments (h, sharedAlbumName, dstFilename, isVideo)
	local shareId  = PhotoStation.getSharedAlbumShareId(h, sharedAlbumName)
	if not shareId then
		writeLogfile(3, string.format('getPublicSharedPhotoComments(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end

	local formData = 'method=list_comment&' ..
					 'version=1&' ..
					 'offset=0&' ..
					 'limit=-1&' ..
					 'item_id=' 		.. PhotoStation.getPhotoId(h, dstFilename, isVideo) .. '&' ..
					 'public_share_id=' .. shareId

	local respArray, errorCode = PhotoStation.callSynoAPI (h, 'SYNO.PhotoStation.AdvancedShare', formData)

	if not respArray then return false, errorCode end

	if respArray.data then
		writeLogfile(3, string.format('getPublicSharedPhotoComments(%s, %s) returns %d comments.\n', dstFilename, sharedAlbumName, #respArray.data))
	else
		writeLogfile(3, string.format('getPublicSharedPhotoComments(%s, %s) returns no comments.\n', dstFilename, sharedAlbumName))
	end
	return respArray.data
end

--====== PhotoStation Upload ==========================================================================--

-----------local functions -----------------------------------------------------------------
-- checkPhotoStationAnswer(funcAndParams, respHeaders, respBody)
--   returns success, errorMsg
local function checkPhotoStationAnswer(funcAndParams, respHeaders, respBody)
	local success, errorMsg = true, nil

	if not respBody then
        if respHeaders then
        	errorMsg = 'Error "' .. ifnil(respHeaders["error"].errorCode, 'Unknown') .. '" on http request:\n' ..
              				trim(ifnil(respHeaders["error"].name, 'Unknown error description'))
			writeTableLogfile(3, 'respHeaders', respHeaders)
        else
        	errorMsg = 'Unknown error on http request'
        end
	   	writeLogfile(1, string.format("%s failed: %s!\n", funcAndParams, errorMsg))
        return false, errorMsg
	end
	writeLogfile(4, "Got Body:\n" .. respBody .. "\n")

	local respArray = JSON:decode(respBody, "checkPhotoStationAnswer(" .. funcAndParams .. ")")

	if not respArray then
		success = false
		errorMsg = PhotoStation.getErrorMsg(1003)
 	elseif not respArray.success then
 		success = false
    	errorMsg = respArray.err_msg
 	end

 	if not success then
	   	writeLogfile(1, string.format("%s failed: %s!\n", funcAndParams, errorMsg))
 	end

	return success, errorMsg
end

----------- PhotoStation Upload: global functions ------------------------------------
--[[
uploadPictureFile(h, srcFilename, srcDateTime, dstDir, dstFilename, picType, mimeType, position)
upload a single file to Photo Station
	srcFilename	- local path to file
	srcDateTime	- DateTimeOriginal (exposure date), only needed for the originals, not accompanying files
	dstDir		- destination album/folder (must exist)
	dstFilename - destination filename (the filename of the ORIG_FILE it belongs to
	picType		- describes the type of upload file:
		THUM_B, THUM_S, THUM_M THUM_L, THUM_XL - accompanying thumbnail
		MP4_MOB, MP4_LOW, MP4_MED, MP4_HIGH  - accompanying video in alternative resolution
		ORIG_FILE	- the original picture or video
	mimeType	- Mime type for the Http body part, not realy required but helpful in Wireshark
	position	- the chronological position of the file within the batch of uploaded files
		FIRST	- any of the thumbs should be the first
		MIDDLE	- any file except the original
		LAST	- the original file must always be the last
	The files belonging to one batch must be send in the right chronological order and tagged accordingly
]]
function PhotoStation.uploadPictureFile(h, srcFilename, srcDateTime, dstDir, dstFilename, picType, mimeType, position)
	local seqOption
	local datetimeOption
	local retcode,reason

	local thisPhoto = dstDir .. '/' .. dstFilename
	local lastPhoto
	
	if thisPhoto ~= lastPhoto then
		if position ~= 'FIRST' then
			writeLogfile(1, string.format("uploadPictureFile(%s) to (%s - %s - %s) interrupts upload of %s\n",
										PSLrUtilities.leafName(srcFilename), thisPhoto, position, picType, lastPhoto))
		end
		lastPhoto = thisPhoto
	end

	datetimeOption = nil
	seqOption = nil
	if position == 'FIRST' then
		seqOption = 		{ field = 'X-IS-BATCH-FIRST-FILE', 	value = '1'}
	elseif position == 'LAST' then
		seqOption = 		{ field = 'X-IS-BATCH-LAST-FILE', 	value = '1'}
		datetimeOption = 	{ field = 'X-LAST-MODIFIED-TIME',	value = srcDateTime }
	end

	local postHeaders = {
		{ field = 'Content-Type',	value = mimeType },
		{ field = 'X-PATH',			value = urlencode(dstDir) },
		{ field = 'X-DUPLICATE',	value = 'OVERWRITE' },
		{ field = 'X-ORIG-FNAME',	value = urlencode(dstFilename) },
		{ field = 'X-UPLOAD-TYPE',	value = picType },
		seqOption,
		datetimeOption,
	}

	-- calculate max. upload time for LrHttp.post()
	-- we expect a minimum of 10 MBit/s upload speed --> 1.25 MByte/s
	local fileSize = LrFileUtils.fileAttributes(srcFilename).fileSize
	if not fileSize then
		local errorMsg = "uploadPictureFile: cannot get fileSize of '" .. srcFilename .."'!"
		writeLogfile(3, errorMsg .. "\n")
		return false, errorMsg
	end
	local timeout = math.floor(fileSize / 1250000)
	if timeout < 30 then timeout = 30 end

	-- string.format does not %ld, which would be required for fileSize; in case of huge files
	writeLogfile(3, string.format("uploadPictureFile: %s dstDir %s dstFn %s type %s pos %s size " .. fileSize .. " timeout %d --> %s\n",
								srcFilename, dstDir, dstFilename, picType, position, timeout, h.serverUrl .. h.uploadPath))
	writeTableLogfile(4, 'postHeaders', postHeaders, true)

	local respBody, respHeaders
	-- MacOS issue: LrHttp.post() doesn't seem to work with callback
	if not WIN_ENV then
		-- remember: LrFileUtils.readFile() can't handle huge files, e.g videos > 2GB, at least on Windows
 		respBody, respHeaders = LrHttp.post(h.serverUrl .. h.uploadPath, LrFileUtils.readFile(srcFilename), postHeaders, 'POST', timeout, fileSize)
	else
    	-- use callback function returning 10MB chunks to feed LrHttp.post()
    	local postFile = io.open(srcFilename, "rb")
    	if not postFile then return false, "Cannot open " .. srcFilename ..' for reading' end
        --[[ testing for MacOS
        	local respBody, respHeaders =
        		LrHttp.post(h.serverUrl .. h.uploadPath,
        				function ()
        --					local readBuf = postFile:read(10000000)
        					local readBuf = postFile:read(30000)
        					if readBuf then
        						writeLogfile(4, "uploadPictureFile: postFile reader returns " .. #readBuf .. " bytes\n")
        					else
        						writeLogfile(4, "uploadPictureFile: postFile reader returns <nil>\n")
        					end
        					return readBuf
        				end,
        				postHeaders, 'POST', timeout, fileSize)
         ]]
    	respBody, respHeaders = LrHttp.post(h.serverUrl .. h.uploadPath, function () return postFile:read(10000000) end, postHeaders, 'POST', timeout, fileSize)
     	postFile:close()
	end

	return checkPhotoStationAnswer(string.format("PhotoStation.uploadPictureFile('%s', '%s', '%s')", srcFilename, dstDir, dstFilename),
									respHeaders, respBody)
end

--====== PhotoStation Utilities ==============================================================================--
-- ========================================== Generic Content cache =========================
-- Used for Albums, Shared Albums (private) and Public Shared Albums.
-- The Album Content cache holds Album contents for the least recently read albums
local contentCache = {
	["album"] = {
		cache 			= {},
		timeout			= 60,
		listFunction	= PhotoStation.listAlbum,
	},

	["sharedAlbum"] = {
		cache 			= {},
		timeout			= 60,
		listFunction	= PhotoStation.listSharedAlbum,
	},

	["publicSharedAlbum"] = {
		cache 			= {},
		timeout			= 60,
		listFunction	= PhotoStation.listPublicSharedAlbum,
	},
}

---------------------------------------------------------------------------------------------------------
-- contentCacheCleanup: remove old entries from cache
local function contentCacheCleanup(cacheName, albumPath)
	local albumContentCache = contentCache[cacheName].cache

	for i = #albumContentCache, 1, -1 do
		local cachedAlbum = albumContentCache[i]
		if (cachedAlbum.validUntil < LrDate.currentTime())
		or (albumPath and cachedAlbum.albumPath == albumPath)then
			writeLogfile(3, string.format("contentCacheCleanup(%s); removing %s\n", cacheName, cachedAlbum.albumPath))
			table.remove(albumContentCache, i)
		end
	end
end

---------------------------------------------------------------------------------------------------------
-- contentCacheList: returns all photos/videos and optionally albums in a given album via album cache
-- returns
--		albumItems:		table of photo infos, if success, otherwise nil
--		errorcode:		errorcode, if not success
local function contentCacheList(cacheName, h, albumName, listItems, updateCache)
	contentCacheCleanup(cacheName, iif(updateCache, albumName, nil))
	local albumContentCache = contentCache[cacheName].cache

	for i = 1, #albumContentCache do
		local cachedAlbum = albumContentCache[i]
		if cachedAlbum.albumPath == albumName then
			return cachedAlbum.albumItems
		end
	end

	-- not found in cache: get it from Photo Station
	local albumItems, errorCode = contentCache[cacheName].listFunction(h, albumName, listItems)
	if not albumItems then
		if 	errorCode ~= 408  	-- no such file or dir
		and errorCode ~= 417	-- no such dir for non-administrative users , see GitHub issue 17
		and errorCode ~= 101	-- no such dir in PS 6.6
		then
			writeLogfile(2, string.format('contentCacheList(%s): Error on listAlbum: %d\n', cacheName, errorCode))
		   	return nil, errorCode
		end
		albumItems = {} -- avoid re-requesting non-existing album
	end

	local cacheEntry = {}
	cacheEntry.albumPath = albumName
	cacheEntry.albumItems = albumItems
	cacheEntry.validUntil = LrDate.currentTime() + contentCache[cacheName].timeout
	table.insert(albumContentCache, 1, cacheEntry)

	writeLogfile(3, string.format("contentCacheList(%s): added to cache with %d items\n", albumName, #albumItems))

	return albumItems
end

-- ===================================== Shared Albums cache ==============================================
-- the Shared Album List cache holds the list of shared Albums per session

local sharedAlbumsCacheTimeout 		= 60	-- 60 seconds cache time

---------------------------------------------------------------------------------------------------------
-- sharedAlbumsCacheCleanup: cleanup cache if cache is too old
local function sharedAlbumsCacheCleanup(h)
	if ifnil(h.sharedAlbumsCacheValidUntil, LrDate.currentTime()) <= LrDate.currentTime() then
		h.sharedAlbumsCache = {}
	end
	return true
end

---------------------------------------------------------------------------------------------------------
-- sharedAlbumsCacheUpdate(h)
local function sharedAlbumsCacheUpdate(h)
	writeLogfile(3, string.format('sharedAlbumsCacheUpdate().\n'))
	h.sharedAlbumsCache = PhotoStation.getSharedAlbums(h)
	h.sharedAlbumsCacheValidUntil = LrDate.currentTime() + sharedAlbumsCacheTimeout
	return h.sharedAlbumsCache
end

---------------------------------------------------------------------------------------------------------
-- sharedAlbumsCacheFind(h, name)
local function sharedAlbumsCacheFind(h, name)
	sharedAlbumsCacheCleanup(h)
	if (not h.sharedAlbumsCache or #h.sharedAlbumsCache == 0) and not sharedAlbumsCacheUpdate(h) then
		return nil
	end

	for i = 1, #h.sharedAlbumsCache do
		if h.sharedAlbumsCache[i].name == name then
			writeLogfile(4, string.format('sharedAlbumsCacheFind(%s) found  %s.\n', name, h.sharedAlbumsCache[i].id))
			return h.sharedAlbumsCache[i]
		end
	end

	writeLogfile(4, string.format('sharedAlbumsCacheFind(%s) not found.\n', name))
	return nil
end

-- ======================================= tagMapping ==============================================
-- the tagMapping holds the list of tag name / tag id mappings

local tagMapping = {
	['desc']	= {},
	['people']	= {},
	['geo']		= {},
}

---------------------------------------------------------------------------------------------------------
-- tagMappingUpdate(h, type)
local function tagMappingUpdate(h, type)
	writeLogfile(3, string.format('tagMappingUpdate(%s).\n', type))
	tagMapping[type] = PhotoStation_getTagList(h, type)
	return tagMapping[type]
end

--====== global functions ====================================================--


---------------------------------------------------------------------------------------------------------
-- getErrorMsg(errorCode)
-- translates errorCode to ErrorMsg
function PhotoStation.getErrorMsg(errorCode)
	if errorCode == nil then
		return string.format("No ErrorCode")
	end
	if PSAPIerrorMsgs[errorCode] == nil then
		-- we don't have a documented  message for that code
		return string.format("Unknown ErrorCode: %d", errorCode)
	end
	return PSAPIerrorMsgs[errorCode]
end

-- function createTree(h, srcDir, srcRoot, dstRoot, dirsCreated)
-- 	derive destination folder: dstDir = dstRoot + (srcRoot - srcDir),
--	create each folder recursively if not already created
-- 	store created directories in dirsCreated
-- 	return created dstDir or nil on error
function PhotoStation.createTree(h, srcDir, srcRoot, dstRoot, dirsCreated)
	writeLogfile(3, "  createTree: Src Path: " .. srcDir .. " from: " .. srcRoot .. " to: " .. dstRoot .. "\n")

	-- sanitize srcRoot: avoid trailing slash and backslash
	local lastchar = string.sub(srcRoot, string.len(srcRoot))
	if lastchar == "/" or lastchar == "\\" then srcRoot = string.sub(srcRoot, 1, string.len(srcRoot) - 1) end

	if srcDir == srcRoot then
		return normalizeDirname(dstRoot)
	end

	-- check if picture source path is below the specified local root directory
	local subDirStartPos, subDirEndPos = string.find(string.lower(srcDir), string.lower(srcRoot), 1, true)
	if subDirStartPos ~= 1 then
		writeLogfile(1, "  createTree: " .. srcDir .. " is not a subdir of " .. srcRoot .. " (startpos is " .. tostring(ifnil(subDirStartPos, '<Nil>')) .. ")\n")
		return nil
	end

	-- Valid subdir: now recurse the destination path and create directories if not already done
	-- replace possible Win '\\' in path
	local dstDirRel = normalizeDirname(string.sub(srcDir, subDirEndPos+2))

	-- sanitize dstRoot: avoid trailing slash
	dstRoot = normalizeDirname(dstRoot)
	local dstDir = dstRoot .."/" .. dstDirRel

	writeLogfile(4,"  createTree: dstDir is: " .. dstDir .. "\n")

	local parentDir = dstRoot
	local restDir
    restDir = dstDirRel

	while restDir do
		local slashPos = ifnil(string.find(restDir,"/", 1, true), 0)
		local newDir = string.sub(restDir,1, slashPos-1)
		local newPath = parentDir .. "/" .. newDir

		if not dirsCreated[newPath] then
			writeLogfile(2,"Create dir - parent: '" .. parentDir .. "' newDir: '" .. newDir .. "' newPath: '" .. newPath .. "'\n")

			local paramParentDir
			if parentDir == "" then paramParentDir = "/" else paramParentDir = parentDir  end
			if not PhotoStation.createAlbum (h, paramParentDir, newDir) then
				writeLogfile(1,"Create dir - parent: '" .. paramParentDir .. "' newDir: '" .. newDir .. "' failed!\n")
				return nil
			end
			dirsCreated[newPath] = true
		else
			writeLogfile(4,"  Directory: " .. newPath .. " already created\n")
		end

		parentDir = newPath
		if slashPos == 0 then
			restDir = nil
		else
			restDir = string.sub(restDir, slashPos + 1)
		end
	end

	return dstDir
end

---------------------------------------------------------------------------------------------------------
-- uploadPhotoFiles(errorCode)
-- upload photo plus its thumbnails (if configured)
function PhotoStation.uploadPhotoFiles(h, dstDir, dstFilename, dstFileTimestamp, thumbGenerate, photo_Filename, title_Filename, thmb_XL_Filename, thmb_L_Filename, thmb_B_Filename, thmb_M_Filename, thmb_S_Filename)
	return
			( not thumbGenerate or
				(
					PhotoStation.uploadPictureFile(h, thmb_B_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_B', 'image/jpeg', 'FIRST')
					and PhotoStation.uploadPictureFile(h, thmb_M_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_M', 'image/jpeg', 'MIDDLE')
					and PhotoStation.uploadPictureFile(h, thmb_S_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_S', 'image/jpeg', 'MIDDLE')
					and (thmb_L_Filename == '' or PhotoStation.uploadPictureFile(h, thmb_L_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_L', 'image/jpeg', 'MIDDLE'))
					and PhotoStation.uploadPictureFile(h, thmb_XL_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_XL', 'image/jpeg', 'MIDDLE')
				)
			)
		and (not title_Filename or PhotoStation.uploadPictureFile(h, title_Filename, dstFileTimestamp, dstDir, dstFilename, 'CUST_TITLE', 'text', 'MIDDLE'))
		and PhotoStation.uploadPictureFile(h, photo_Filename, dstFileTimestamp, dstDir, dstFilename, 'ORIG_FILE', 'image/jpeg', 'LAST')
end

---------------------------------------------------------------------------------------------------------
-- uploadVideoFiles(errorCode)
-- upload video plus its thumbnails (if configured) plus additional and replacement videos
function PhotoStation.uploadVideoFiles(h, dstDir, dstFilename, dstFileTimestamp, thumbGenerate, video_Filename, title_Filename, thmb_XL_Filename, thmb_L_Filename, thmb_B_Filename, thmb_M_Filename, thmb_S_Filename,
	video_Add_Filename, video_Replace_Filename, convParams, convKeyOrig, convKeyAdd, addOrigAsMp4)
	return
		-- delete old before uploading new
			PhotoStation.deletePhoto (h, dstDir .. '/' .. dstFilename, true)
		and (not thumbGenerate or
				(
						PhotoStation.uploadPictureFile(h, thmb_B_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_B', 'image/jpeg', 'FIRST')
					and PhotoStation.uploadPictureFile(h, thmb_M_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_M', 'image/jpeg', 'MIDDLE')
					and PhotoStation.uploadPictureFile(h, thmb_S_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_S', 'image/jpeg', 'MIDDLE')
					and (thmb_L_Filename == '' or PhotoStation.uploadPictureFile(h, thmb_L_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_L', 'image/jpeg', 'MIDDLE'))
					and PhotoStation.uploadPictureFile(h, thmb_XL_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_XL', 'image/jpeg', 'MIDDLE')
				)
			)
		and (not title_Filename or PhotoStation.uploadPictureFile(h, title_Filename, dstFileTimestamp, dstDir, dstFilename, 'CUST_TITLE', 'text', 'MIDDLE'))
		and ((convKeyAdd == 'None') or PhotoStation.uploadPictureFile(h, video_Add_Filename, dstFileTimestamp, dstDir, dstFilename, 'MP4_'.. convParams[convKeyAdd].type, 'video/mpeg', 'MIDDLE'))
		-- add mp4 version in original resolution fo Non-MP4s
		and (not addOrigAsMp4 or PhotoStation.uploadPictureFile(h, video_Replace_Filename, dstFileTimestamp, dstDir, dstFilename, 'MP4_'.. convParams[convKeyOrig].type, 'video/mpeg', 'MIDDLE'))
		-- upload at least one mp4 file to avoid the generation of a flash video by synomediaparserd
		and ((convKeyAdd ~= 'None') or  addOrigAsMp4
	 	   						 or PhotoStation.uploadPictureFile(h, video_Filename, dstFileTimestamp, dstDir, dstFilename, 'MP4_'.. convParams[convKeyOrig].type, 'video/mpeg', 'MIDDLE'))
		and PhotoStation.uploadPictureFile(h, video_Filename, dstFileTimestamp, dstDir, dstFilename, 'ORIG_FILE', 'video/mpeg', 'LAST')
end
---------------------------------------------------------------------------------------------------------
-- PhotoStation.getAlbumId(h, albumPath)
--	returns the AlbumId of a given Album path (not leading and trailing slashes) in Photo Station
--	AlbumId looks like:
--		album_<AlbumPathInHex>
--	E.g. Album Path:
--		Albums-->Test/2007
--  yields AlbumId:
--  	album_546573742f32303037
function PhotoStation.getAlbumId(h, albumPath)
	local i
	local albumId = 'album_'

	albumPath = string.gsub (albumPath, '/*(.*)/*', '%1')
	if ifnil(albumPath, '') == '' then return '' end

	for i = 1, string.len(albumPath) do
		albumId = albumId .. string.format('%x', string.byte(albumPath,i))
	end

--	writeLogfile(4, string.format("getAlbumId(%s) returns %s\n", albumPath, albumId))

	return albumId
end

---------------------------------------------------------------------------------------------------------
-- getAlbumUrl(h, albumPath)
--	returns the URL of an album in the Photo Station
--	URL of an album in PS is:
--		http(s)://<PS-Server>/<PSBasedir>/#!Albums/<AlbumId_1rstLevelDir>/<AlbumId_1rstLevelAndSecondLevelDir>/.../AlbumId_1rstToLastLevelDir>
--	E.g. Album Path:
--		Server: http://diskstation; Standard Photo Station; Album Breadcrumb: Albums/Test/2007
--	yields PS Photo-URL:
--		http://diskstation/photo/#!Albums/album_54657374/album_546573742f32303037
function PhotoStation.getAlbumUrl(h, albumPath)
	local i
	local albumUrl
	local subDirPath = ''
	local subDirUrl  = ''

	local albumDirname = split(albumPath, '/') or {}

	albumUrl = h.serverUrl .. h.psAlbumRoot

	for i = 1, #albumDirname do
		if i > 1 then
			subDirPath = subDirPath .. '/'
		end
		subDirPath = subDirPath .. albumDirname[i]
		subDirUrl = PhotoStation.getAlbumId(h, subDirPath)
		albumUrl = albumUrl .. '/' .. subDirUrl
	end

	writeLogfile(3, string.format("getAlbumUrl(%s, %s) returns %s\n", h.serverUrl .. h.psAlbumRoot, albumPath, albumUrl))

	return albumUrl
end

---------------------------------------------------------------------------------------------------------
-- getPhotoId(h, photoPath, isVideo)
-- 	returns the PhotoId of a given photo path in Photo Station
-- 	PhotoId looks like:
-- 		photo_<AlbumPathInHex>_<PhotoPathInHex> or
-- 		video_<AlbumPathInHex>_<PhotoPathInHex>
-- 	E.g. Photo Path:
--		Albums --> Test/2007/2007_08_13_IMG_7415.JPG
--  yields PhotoId:
--  	photo_546573742f32303037_323030375f30385f31335f494d475f373431352e4a5047
function PhotoStation.getPhotoId(h, photoPath, isVideo)
	local i
	local photoDir, photoFilename = string.match(photoPath , '(.*)/([^/]+)')
	if not photoDir then
		photoDir = '/'
		photoFilename = photoPath
	end
	local albumSubId = ''
	local photoSubId = ''
	local photoId = iif(isVideo, 'video_', 'photo_')

	for i = 1, string.len(photoDir) do
		albumSubId = albumSubId .. string.format('%x', string.byte(photoDir,i))
	end

	for i = 1, string.len(photoFilename) do
		photoSubId = photoSubId .. string.format('%x', string.byte(photoFilename,i))
	end

	photoId = photoId .. albumSubId .. '_' .. photoSubId

--	writeLogfile(4, string.format("getPhotoId(%s) returns %s\n", photoPath, photoId))

	return photoId
end

---------------------------------------------------------------------------------------------------------
-- getPhotoUrl(h, photoPath, isVideo)
--	returns the URL of a photo/video in the Photo Station
--	URL of a photo in PS is:
--		http(s)://<PS-Server>/<PSBasedir>/#!Albums/<AlbumId_1rstLevelDir>/<AlbumId_1rstLevelAndSecondLevelDir>/.../AlbumId_1rstToLastLevelDir>/<PhotoId>
--	E.g. Photo Path:
--		Server: http://diskstation; Standard Photo Station; Photo Breadcrumb: Albums/Test/2007/2007_08_13_IMG_7415.JPG
--	yields PS Photo-URL:
--		http://diskstation/photo/#!Albums/album_54657374/album_546573742f32303037/photo_546573742f32303037_323030375f30385f31335f494d475f373431352e4a5047
function PhotoStation.getPhotoUrl(h, photoPath, isVideo)
	local i
	local subDirPath = ''
	local subDirUrl  = ''
	local photoUrl

	local albumDir, _ = string.match(photoPath, '(.+)/([^/]+)')

	local albumDirname = split(albumDir, '/')
	if not albumDirname then albumDirname = {} end

	photoUrl = h.serverUrl .. h.psAlbumRoot

	for i = 1, #albumDirname do
		if i > 1 then
			subDirPath = subDirPath .. '/'
		end
		subDirPath = subDirPath .. albumDirname[i]
		subDirUrl = PhotoStation.getAlbumId(h, subDirPath)
		photoUrl = photoUrl .. '/' .. subDirUrl
	end

	photoUrl = photoUrl .. '/' .. PhotoStation.getPhotoId(h, photoPath, isVideo)

	writeLogfile(3, string.format("getPhotoUrl(%s, %s) returns %s\n", h.serverUrl .. h.psAlbumRoot, photoPath, photoUrl))

	return photoUrl
end

---------------------------------------------------------------------------------------------------------
-- getPhotoInfoFromList(h, albumType, albumName, dstFilename, isVideo, useCache)
-- return photo infos for a photo in a given album list (album, shared album or public shared album)
-- returns:
-- 		photoInfos				if remote photo was found
-- 		nil,					if remote photo was not found
-- 		nil,		errorCode	on error
function PhotoStation.getPhotoInfoFromList(h, albumType, albumName, photoName, isVideo, useCache)
	local updateCache = not useCache
	local photoInfos, errorCode = contentCacheList(albumType, h, albumName, 'photo,video', updateCache)

	if not photoInfos then return nil, errorCode end

	local photoId = PhotoStation.getPhotoId(h, photoName, isVideo)
	for i = 1, #photoInfos do
		if photoInfos[i].id == photoId then
			writeLogfile(3, string.format("getPhotoInfoFromList('%s', '%s', '%s', useCache %s) found infos.\n", albumType, albumName, photoName, useCache))
			return photoInfos[i]
		end
	end

	writeLogfile(3, string.format("getPhotoInfoFromList('%s', '%s', '%s', useCache %s) found no infos.\n", albumType, albumName, photoName, useCache))
	return nil
end

---------------------------------------------------------------------------------------------------------
-- PhotoStation_getSharedAlbumInfo(h, sharedAlbumName, useCache)
-- 	returns the shared album info  of a given SharedAlbum
local function PhotoStation_getSharedAlbumInfo(h, sharedAlbumName, useCache)
	if not useCache then sharedAlbumsCacheUpdate(h) end
	return sharedAlbumsCacheFind(h, sharedAlbumName)
end

---------------------------------------------------------------------------------------------------------
-- PhotoStation.getSharedAlbumId(h, sharedAlbumName)
-- 	returns the shared Album Id of a given SharedAlbum using the Shared Album cache
function PhotoStation.getSharedAlbumId(h, sharedAlbumName)
	local sharedAlbumInfo = sharedAlbumsCacheFind(h, sharedAlbumName)

	if not sharedAlbumInfo then
		writeLogfile(3, string.format('getSharedAlbumId(%s): Shared Album not found.\n', sharedAlbumName))
		return nil
	end

	return sharedAlbumInfo.id
end

---------------------------------------------------------------------------------------------------------
-- getSharedAlbumUrls(h, publishSettings, sharedAlbumName)
-- 	returns three URLsfor the given album
function PhotoStation.getSharedAlbumUrls(h, publishSettings, sharedAlbumName)
    writeLogfile(4, string.format("PhotoStation.getSharedAlbumUrls('%s') ...\n", sharedAlbumName))
	local albumId, albumInfo = PhotoStation_getSharedAlbumInfo(h,  sharedAlbumName, true)
	local privateUrl, publicUrl, publicUrl2 = '', '', ''
	
	if  not (albumId and albumInfo) then
		writeLogfile(4, string.format("PhotoStation.getSharedAlbumUrls('%s') found no albumInfo\n", sharedAlbumName))
		return nil, nil, nil
	end
	
	privateUrl 	= publishSettings.proto  .. "://" .. publishSettings.servername  .. publishSettings.psPath .. "#!SharedAlbums/" .. albumId
	if albumInfo.public_share_url then
		local publicSharePath = string.match(albumInfo.public_share_url, 'http[s]*://[^/]*(.*)')
		publicUrl 		= publishSettings.proto  .. "://" .. publishSettings.servername  .. publicSharePath
		publicUrl2 		= publishSettings.proto2 .. "://" .. publishSettings.servername2 .. publicSharePath
	end
    writeLogfile(3, string.format("PhotoStation.getSharedAlbumUrls('%s') returns '%s', '%s', '%s'\n", sharedAlbumName, privateUrl, publicUrl, publicUrl2))
	return privateUrl, publicUrl, publicUrl2
end

---------------------------------------------------------------------------------------------------------
-- PhotoStation.isSharedAlbumPublic(h, sharedAlbumName)
--  returns the public flage of a given SharedAlbum using the Shared Album cache
function PhotoStation.isSharedAlbumPublic(h, sharedAlbumName)
	local sharedAlbumInfo = sharedAlbumsCacheFind(h, sharedAlbumName)

	if not sharedAlbumInfo then
		writeLogfile(3, string.format('isSharedAlbumPublic(%s): Shared album not found.\n', sharedAlbumName))
		return false
	end
	if not sharedAlbumInfo.additional or not sharedAlbumInfo.additional.public_share or sharedAlbumInfo.additional.public_share.share_status ~= 'valid' then
		return false
	end

	return true
end

---------------------------------------------------------------------------------------------------------
-- PhotoStation.getSharedAlbumShareId(h, sharedAlbumName)
-- 	returns the shareId of a given SharedAlbum using the Shared Album cache
function PhotoStation.getSharedAlbumShareId(h, sharedAlbumName)
	local sharedAlbumInfo = sharedAlbumsCacheFind(h, sharedAlbumName)

	if not sharedAlbumInfo then
		writeLogfile(3, string.format('getSharedAlbumShareId(%s): Shared Album not found.\n', sharedAlbumName))
		return nil
	end

	return sharedAlbumInfo.additional.public_share.shareid
end

---------------------------------------------------------------------------------------------------------
-- getSharedPhotoPublicUrl (h, albumName, photoName, isVideo)
-- returns the public share url of a shared photo
function PhotoStation.getSharedPhotoPublicUrl(h, albumName, photoName, isVideo)
	local photoInfos, errorCode = PhotoStation.getPhotoInfoFromList(h, 'sharedAlbum', albumName, photoName, isVideo, true)

	if not photoInfos then return nil, errorCode end

	return photoInfos.public_share_url
end

---------------------------------------------------------------------------------------------------------
-- getPublicSharedPhotoColorLabel (h, albumName, photoName, isVideo)
-- returns the color label of a pbulic shared photo
function PhotoStation.getPublicSharedPhotoColorLabel(h, albumName, photoName, isVideo)
	local photoInfos, errorCode = PhotoStation.getPhotoInfoFromList(h, 'publicSharedAlbum', albumName, photoName, isVideo, true)

	if not photoInfos then return nil, errorCode end

	return photoInfos.info.color_label
end

---------------------------------------------------------------------------------------------------------
-- getTagId(h, type, name)
function PhotoStation.getTagId(h, type, name)
	local tagsOfType = tagMapping[type]

	if (#tagsOfType == 0) and not tagMappingUpdate(h, type) then
		return nil
	end
	tagsOfType = tagMapping[type]

	for i = 1, #tagsOfType do
		if tagsOfType[i].name == name then
			writeLogfile(3, string.format("getTagId(%s, '%s') found  %s.\n", type, name, tagsOfType[i].id))
			return tagsOfType[i].id
		end
	end

	writeLogfile(3, string.format("getTagId(%s, '%s') not found.\n", type, name))
	return nil
end


---------------------------------------------------------------------------------------------------------
-- createAndAddPhotoTag (h, dstFilename, isVideo, type, name, addinfo)
-- create and add a new tag (desc,people,geo) to a photo
function PhotoStation.createAndAddPhotoTag(h, dstFilename, isVideo, type, name, addinfo)
	local tagId = PhotoStation.getTagId(h, type, name)
	if not tagId then
		tagId = PhotoStation.createTag(h, type, name)
		tagMappingUpdate(h, type)
	end

	if not tagId then return false end

	local photoTagIds, errorCode = PhotoStation.addPhotoTag(h, dstFilename, isVideo, type, tagId, addinfo)

	if not photoTagIds and errorCode == 467 then
		-- tag was deleted, cache wasn't up to date
		tagId = PhotoStation.createTag(h, type, name)
		tagMappingUpdate(h, type)
	 	photoTagIds, errorCode = PhotoStation.addPhotoTag(h, dstFilename, isVideo, type, tagId, addinfo)
	end

	-- errorCode 468: duplicate tag (tag already there)
	if not photoTagIds and errorCode ~= 468 then return false end

	writeLogfile(3, string.format("createAndAddPhotoTag('%s', '%s', '%s') returns OK.\n", dstFilename, type, name))
	return true
end


PhotoStation.colorMapping = {
	[1] = 'red',
	[2] = 'yellow',
	[3] = 'green',
	[4] = 'none',
	[5] = 'blue',
	[6] = 'purple'
}

---------------------------------------------------------------------------------------------------------
-- createSharedAlbum(h, sharedAlbumParams)
-- create a Shared Album
-- returns sharedAlbumInfo or nil and errorCode
function PhotoStation.createSharedAlbum(h, sharedAlbumParams)
	local sharedAlbumInfo = PhotoStation_getSharedAlbumInfo(h, sharedAlbumParams.sharedAlbumName, false)
	local sharedAlbumAttributes = {}

	if not sharedAlbumInfo then
		local sharedAlbumId, errorCode = PhotoStation_createSharedAlbumSimple(h, sharedAlbumParams.sharedAlbumName)

		if not sharedAlbumId then return nil, errorCode end

		sharedAlbumInfo = PhotoStation_getSharedAlbumInfo(h, sharedAlbumParams.sharedAlbumName, false)
		if not sharedAlbumInfo then return nil, 555 end
	end

	sharedAlbumAttributes.is_shared = sharedAlbumParams.isPublic

	if 	sharedAlbumParams.isPublic then
--		sharedAlbumAttributes.status		= 'valid'
		sharedAlbumAttributes.start_time 	= ifnil(sharedAlbumParams.startTime, sharedAlbumInfo.additional.public_share.start_time)
		sharedAlbumAttributes.end_time 		= ifnil(sharedAlbumParams.stopTime, sharedAlbumInfo.additional.public_share.end_time)
	end

	if sharedAlbumParams.isAdvanced then
		sharedAlbumAttributes.is_advanced = true

		if sharedAlbumParams.sharedAlbumPassword then
			sharedAlbumAttributes.enable_password = true
			sharedAlbumAttributes.password = sharedAlbumParams.sharedAlbumPassword
		else
			sharedAlbumAttributes.enable_password = false
		end

		--get advanced album info from already existing Shared Albums or from defaults
		local advancedInfo
		if sharedAlbumInfo.additional and sharedAlbumInfo.additional.public_share and sharedAlbumInfo.additional.public_share.advanced_info then
			advancedInfo = sharedAlbumInfo.additional.public_share.advanced_info
		else
			advancedInfo = {
		    	enable_marquee_tool 	= true,
    			enable_comment			= true,
    			enable_color_label		= true,
    			color_label_1			= 'red',
    			color_label_2			= 'yellow',
    			color_label_3			= 'green',
		    	color_label_4			= '',
    			color_label_5			= 'blue',
		    	color_label_6			= 'purple',
			}
		end

		-- set advanced album info: use existing/default values if not defined otherwise
    	sharedAlbumAttributes.enable_marquee_tool	= ifnil(sharedAlbumParams.areaTool, 	 advancedInfo.enable_marquee_tool)
    	sharedAlbumAttributes.enable_comment 		= ifnil(sharedAlbumParams.comments, 	 advancedInfo.enable_comment)
    	-- TODO: use Lr defined color label names
    	sharedAlbumAttributes.color_label_1 		= iif(sharedAlbumParams.colorRed	== nil, advancedInfo.color_label_1, iif(sharedAlbumParams.colorRed, 	'red', ''))
    	sharedAlbumAttributes.color_label_2 		= iif(sharedAlbumParams.colorYellow == nil, advancedInfo.color_label_2, iif(sharedAlbumParams.colorYellow, 	'yellow', ''))
    	sharedAlbumAttributes.color_label_3 		= iif(sharedAlbumParams.colorGreen	== nil, advancedInfo.color_label_3, iif(sharedAlbumParams.colorGreen, 	'green', ''))
    	sharedAlbumAttributes.color_label_4 		= ''
    	sharedAlbumAttributes.color_label_5 		= iif(sharedAlbumParams.colorBlue	== nil, advancedInfo.color_label_5, iif(sharedAlbumParams.colorBlue, 	'blue', ''))
    	sharedAlbumAttributes.color_label_6 		= iif(sharedAlbumParams.colorPurple	== nil, advancedInfo.color_label_6, iif(sharedAlbumParams.colorPurple, 	'purple', ''))
    	sharedAlbumAttributes.enable_color_label	= sharedAlbumParams.colorRed or sharedAlbumParams.colorYellow or sharedAlbumParams.colorGreen or
            										  sharedAlbumParams.colorBlue or sharedAlbumParams.colorPurple or advancedInfo.enable_color_label
	end

	writeTableLogfile(3, "createSharedAlbum: sharedAlbumParams", sharedAlbumParams, true, '^password')
	local shareResult, errorCode = PhotoStation.editSharedAlbum(h, sharedAlbumParams.sharedAlbumName, sharedAlbumAttributes)

	if not shareResult then return nil, errorCode end

	return shareResult
end
---------------------------------------------------------------------------------------------------------
-- createAndAddPhotosToSharedAlbum(h, sharedAlbumParams, photos)
-- create a Shared Album and add a list of photos to it
-- returns sharedAlbumInfo or nil and errorCode
function PhotoStation.createAndAddPhotosToSharedAlbum(h, sharedAlbumParams, photos)
	local shareResult = h:createSharedAlbum(sharedAlbumParams)

	if 		not shareResult
		or	not h:addPhotosToSharedAlbum(sharedAlbumParams.sharedAlbumName, photos)
	then
		return nil
	end

	writeLogfile(3, string.format('createAndAddPhotosToSharedAlbum(%s, %s, %s, pw: %s, %d photos) returns OK.\n',
			sharedAlbumParams.sharedAlbumName, iif(sharedAlbumParams.isAdvanced, 'advanced', 'old'),
			iif(sharedAlbumParams.isPublic, 'public', 'private'), iif(sharedAlbumParams.sharedAlbumPassword, 'w/ passwd', 'w/o passwd'),
			#photos))
	return shareResult
end

---------------------------------------------------------------------------------------------------------
-- removePhotosFromSharedAlbum(h, sharedAlbumName, photos)
-- remove a list of photos from a Shared Album
-- ignore error if Shared Album doesn't exist
function PhotoStation.removePhotosFromSharedAlbum(h, sharedAlbumName, photos)
	local albumId  = PhotoStation.getSharedAlbumId(h, sharedAlbumName)

	if not albumId then
		writeLogfile(3, string.format('removePhotosFromSharedAlbum(%s, %d photos): Shared album not found, returning OK.\n', sharedAlbumName, #photos))
		return true
	end

	local photoIds = {}
	for i = 1, #photos do
		photoIds[i] = Photos.getPhotoId(h, photos[i].dstFilename, photos[i].isVideo, false)
	end

    return PhotoStation_removePhotosFromSharedAlbum(h, albumId, photoIds)
end

---------------------------------------------------------------------------------------------------------
-- deleteEmptyAlbumAndParents(h, albumPath)
-- delete an album and all its parents as long as they are empty
-- return count of deleted albums
function PhotoStation.deleteEmptyAlbumAndParents(h, albumPath)
	local nDeletedAlbums = 0
	local currentAlbumPath

	currentAlbumPath = albumPath
	while currentAlbumPath do
		local photoInfos, errorCode =  PhotoStation.listAlbum(h, currentAlbumPath, 'photo,video,album')

    	-- if not existing or not empty or delete fails, we are ready
    	if 		not photoInfos
    		or 	#photoInfos > 0
    		or not PhotoStation.deleteAlbum (h, currentAlbumPath)
    	then
    		writeLogfile(3, string.format('deleteEmptyAlbumAndParents(%s) not deleted.\n', currentAlbumPath))
    		return nDeletedAlbums
    	end

   		writeLogfile(2, string.format('deleteEmptyAlbumAndParents(%s) was empty: deleted.\n', currentAlbumPath))
		nDeletedAlbums = nDeletedAlbums + 1
		currentAlbumPath = string.match(currentAlbumPath , '(.+)/[^/]+')
	end

	return nDeletedAlbums
end

-- #####################################################################################################
-- ########################## Photo object #############################################################
-- #####################################################################################################

PhotoStationPhoto = {}
PhotoStationPhoto_mt = { __index = PhotoStationPhoto }

function PhotoStationPhoto.new(photoServer, photoPath, isVideo, infoTypeList, useCache)
	local photoInfo

	writeLogfile(3, string.format("PhotoStationPhoto:new(%s, %s, %s, %s) starting\n", photoPath, isVideo, infoTypeList, useCache))

	if not photoServer  then
		-- called from PhotoStation.new()
		return setmetatable({}, PhotoStationPhoto_mt)
	end

	if string.find(infoTypeList, 'photo') then
		local photoInfoFromList, errorCode = photoServer:getPhotoInfoFromList('album', normalizeDirname(PSLrUtilities.parent(photoPath)), photoPath, isVideo, useCache)
		if photoInfoFromList then
			photoInfo = tableDeepCopy(photoInfoFromList)
		else
			return nil, errorCode
--			photoInfo = {}
--			photoInfo.errorCode = errorCode
		end
	else
		photoInfo = {}
	end

	photoInfo.photoPath 	= photoPath

	if string.find(infoTypeList, 'tag') then
		local photoTags, errorCode = photoServer:getPhotoTags(photoPath, isVideo)
		if not photoTags and errorCode then return nil, errorCode end
		photoInfo.tags = tableDeepCopy(photoTags)
	end

	writeLogfile(3, string.format("PhotoStationPhoto:new(): returns photoInfo %s\n", JSON:encode(photoInfo)))

	photoInfo.photoServer 	= photoServer

	return setmetatable(photoInfo, PhotoStationPhoto_mt)
end

function PhotoStationPhoto:getDescription()
	return self.info and self.info.description
end

function PhotoStationPhoto:getGPS()
	local gps = { latitude = 0, longitude = 0, type = 'blue' }

	-- gps coords from photo/video: best choice for GPS
	if self.info then
		if self.info.lat and self.info.lng then
			gps.latitude	= tonumber(self.info.lat)
			gps.longitude	= tonumber(self.info.lng)
			gps.type		= 'red'
		-- psPhotoInfo.gps: GPS info of videos is stored here
		elseif self.info.gps and self.info.gps.lat and self.info.gps.lng then
			gps.latitude	= tonumber(self.info.gps.lat)
			gps.longitude	= tonumber(self.info.gps.lng)
			gps.type		= 'red'
		end
	-- psPhotoAdditional.photo_exif.gps: should be identical to psPhotoInfo
	elseif 	self.additional and self.additional.photo_exif and self.additional.photo_exif.gps
		and self.additional.photo_exif.gps.lat and self.additional.photo_exif.gps.lng then
		gps.latitude	= tonumber(self.additional.photo_exif.gps.lat)
		gps.longitude	= tonumber(self.additional.photo_exif.gps.lng)
		gps.type		= 'red'
	end

	return gps
end

function PhotoStationPhoto:getId()
	return self.id
end

function PhotoStationPhoto:getRating()
	return self.info and self.info.rating
end

function PhotoStationPhoto:getTags()
	return self.tags or {}
end

function PhotoStationPhoto:getTitle()
	if not self.info then return '' end
	-- ignore pseudo title (== filename)
	return iif(self.info.title == PSLrUtilities.removeExtension(PSLrUtilities.leafName(self.photoPath)), '', ifnil(self.info.title, ''))
end

function PhotoStationPhoto:getType()
	return self.type
end

function PhotoStationPhoto:setDescription(description)
	if not self.changes then self.changes = {} end
	if not self.changes.metadata then self.changes.metadata = {} end

	self.changes.metadata.description = description
	return true
end

function PhotoStationPhoto:setGPS(gps)
	if not self.changes then self.changes = {} end
	if not self.changes.metadata then self.changes.metadata = {} end

	self.changes.metadata.gps_lat =  gps.latitude
	self.changes.metadata.gps_lng =  gps.longitude
	return true
end

function PhotoStationPhoto:setRating(rating)
	if not self.changes then self.changes = {} end
	if not self.changes.metadata then self.changes.metadata = {} end

	self.changes.metadata.rating = rating
	return true
end

function PhotoStationPhoto:setTitle(title)
	if not self.changes then self.changes = {} end
	if not self.changes.metadata then self.changes.metadata = {} end

	self.changes.metadata.title = title
	return true
end

function PhotoStationPhoto:showUpdates()
	local metadataChanges	= self.changes.metadata
	local tagsAdd 			= self.changes.tags_add
	local tagsRemove 		= self.changes.tags_remove
	local changesList = ''

	if metadataChanges then
		for key, value in pairs(metadataChanges) do
			changesList = changesList .. key .. ":'" .. value .. "',"
		end
	end

	if tagsAdd then
		for i = 1, #tagsAdd do
			changesList = changesList .. '+tag-' .. tagsAdd[i].type .. ":'" .. tagsAdd[i].name .. "',"
		end
	end

	if tagsRemove then
		for i = 1, #tagsRemove do
			changesList = changesList .. '-tag-' .. tagsRemove[i].type .. ":'" .. tagsRemove[i].name .. "',"
		end
	end

	return changesList
end

function PhotoStationPhoto:updateMetadata()
	local metadataChanges = self.changes and self.changes.metadata
	local photoParams = {}

	if not metadataChanges then return true end

	for key, value in pairs(metadataChanges) do
		table.insert(photoParams, { attribute =  key, value = value })
	end
	return self.photoServer:editPhoto(self.photoPath, self.type == 'video', photoParams)
end

function PhotoStationPhoto:addTags(tags, type)
	if not self.changes then self.changes = {} end
	if not self.changes.tags_add then self.changes.tags_add = {} end

	if not tags then return true end

	for i = 1, #tags do
		tags[i].type = type
		table.insert(self.changes.tags_add, tags[i])
	end

	return true
end

function PhotoStationPhoto:removeTags(tags, type)
	if not self.changes then self.changes = {} end
	if not self.changes.tags_remove then self.changes.tags_remove = {} end

	if not tags then return true end

	for i = 1, #tags do
		tags[i].type = type
		table.insert(self.changes.tags_remove, tags[i])
	end

	return true
end

function PhotoStationPhoto:updateTags()
	local tagsAdd 		= self.changes and self.changes.tags_add
	local tagsRemove 	= self.changes and self.changes.tags_remove

	writeTableLogfile(4,"updateTags[add]", tagsAdd, true)
	writeTableLogfile(4,"updateTags[remove]", tagsRemove, true)

	for i = 1, #tagsAdd do
		if 	(tagsAdd[i].type == 'people' and not self.photoServer:createAndAddPhotoTag(self.photoPath, self.type == 'video', tagsAdd[i].type, tagsAdd[i].name, tagsAdd[i])) or
			(tagsAdd[i].type ~= 'people' and not self.photoServer:createAndAddPhotoTag(self.photoPath, self.type == 'video', tagsAdd[i].type, tagsAdd[i].name))
		then
			return false
		end
	end
	writeLogfile(3, string.format("updateTags-Add('%s', %d tags) returns OK.\n", self.photoPath, #tagsAdd))

	for i = 1, #tagsRemove do
		if not self.photoServer:removePhotoTag(self.photoPath, self.type == 'video', tagsRemove[i].type, tagsRemove[i].item_tag_id) then
			return false
		end
	end

	writeLogfile(3, string.format("updateTags-Remove('%s', %d tags) returns OK.\n", self.photoPath, #tagsRemove))
	return true
end
