--[[----------------------------------------------------------------------------

PSPhotosAPI.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2021, Martin Messmer

Photos object:
	- login
	- logout

	- getTags
	- createTag

	- getPhotoExifs
	- editPhoto
	- getPhotoTags
	- addPhotoTag
	- getPhotoComments
	- addPhotoComments
	- movePhoto
	- deletePhoto

	- listAlbumItems
	- listAlbumSubfolders
	- sortAlbumPhotos
	- deleteAlbum

	- createFolder
	- uploadPicFile

	Photo Station Utilities:
	- getErrorMsg

	- getFolderId
	- getAlbumUrl
	- getPhotoId
	- getPhotoUrl

	- getPhotoInfoFromList
	
	- createAndAddPhotoTag
	- createAndAddPhotoTagList

	- deleteEmptyAlbumAndParents

Photos Photo object:
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

-- #####################################################################################################
-- ########################## PhotoStation object ######################################################
-- #####################################################################################################

Photos = {}
Photos_mt = { __index = Photos }

--====== local vars and functions ============================================--

local PSAPIerrorMsgs = {
	[0]		= 'No error',
	[641]	= 'error_file_exist',
--[[
	[100] = 'Unknown error',
    [101] = 'No parameter of API, method or version',		-- PS 6.6: no such directory 
    [102] = 'The requested API does not exist',
    [103] = 'The requested method does not exist',
    [104] = 'The requested version does not support the functionality',
    [105] = 'The logged in session does not have permission',
    [106] = 'Session timeout',
    [107] = 'Session interrupted by duplicate login',

    -- SYNO.Photos.Info (401-405)

    -- SYNO.Photos.Auth (406-415)
	[406] = 'Photos_AUTH_LOGIN_NOPRIVILEGE',
	[407] = 'Photos_AUTH_LOGIN_ERROR',
	[408] = 'Photos_AUTH_LOGIN_DISABLE_ACCOUNT',
	[409] = 'Photos_AUTH_LOGIN_GUEST_ERROR',
	[410] = 'Photos_AUTH_LOGIN_MAX_TRIES',

    -- SYNO.PhotoStaion.Album (416-425)
	[416] = 'Photos_ALBUM_PASSWORD_ERROR',
	[417] = 'Photos_ALBUM_NO_ACCESS_RIGHT',
	[418] = 'Photos_ALBUM_NO_UPLOAD_RIGHT',
	[419] = 'Photos_ALBUM_NO_MANAGE_RIGHT',
	[420] = 'Photos_ALBUM_NOT_ADMIN',
	[421] = 'Photos_ALBUM_HAS_EXIST',
	[422] = 'Photos_ALBUM_CREATE_FAIL',
	[423] = 'Photos_ALBUM_EDIT_FAIL',
	[424] = 'Photos_ALBUM_DELETE_FAIL',
	[425] = 'Photos_ALBUM_SELECT_CONFLICT',

    -- SYNO.Photos.Permission (426-435)
	[426] = 'Photos_PERMISSION_BAD_PARAMS',
	[427] = 'Photos_PERMISSION_ACCESS_DENY',

    -- SYNO.Photos.Tag (436-445)
	[436] = 'Photos_TAG_LIST_FAIL',
	[437] = 'Photos_TAG_GETINFO_FAIL',
	[438] = 'Photos_TAG_CREATE_FAIL',
	[439] = 'Photos_TAG_EDIT_FAIL',
	[440] = 'Photos_TAG_ACCESS_DENY',
	[441] = 'Photos_TAG_HAS_EXIST',
	[442] = 'Photos_TAG_SEARCH_FAIL',

    -- SYNO.Photos.SmartAlbum (446-455)
	[446] = 'Photos_SMARTALBUM_CREATE_FAIL',
	[447] = 'Photos_SMARTALBUM_EDIT_FAIL',
	[448] = 'Photos_SMARTALBUM_ACCESS_DENY',
	[449] = 'Photos_SMARTALBUM_NOT_EXIST',
	[450] = 'Photos_SMARTALBUM_TAG_NOT_EXIST',
	[451] = 'Photos_SMARTALBUM_CREATE_FAIL_EXIST',

    -- SYNO.Photos.Photo (456-465)
	[456] = 'Photos_PHOTO_BAD_PARAMS',
	[457] = 'Photos_PHOTO_ACCESS_DENY',
	[458] = 'Photos_PHOTO_SELECT_CONFLICT',

    -- SYNO.Photos.PhotoTag (466-475)
	[466] = 'Photos_PHOTO_TAG_ACCESS_DENY',
	[467] = 'Photos_PHOTO_TAG_NOT_EXIST',
	[468] = 'Photos_PHOTO_TAG_DUPLICATE',
	[469] = 'Photos_PHOTO_TAG_VIDEO_NOT_EXIST',
	[470] = 'Photos_PHOTO_TAG_ADD_GEO_DESC_FAIL',
	[471] = 'Photos_PHOTO_TAG_ADD_PEOPLE_FAIL',
	[472] = 'Photos_PHOTO_TAG_DELETE_FAIL',
	[473] = 'Photos_PHOTO_TAG_PEOPLE_TAG_CONFIRM_FAIL',

    -- SYNO.Photos.Category (476-490)
	[476] = 'Photos_CATEGORY_ACCESS_DENY',
	[477] = 'Photos_CATEGORY_WRONG_ID_FORMAT',
	[478] = 'Photos_CATEGORY_GETINFO_FAIL',
	[479] = 'Photos_CATEGORY_CREATE_FAIL',
	[480] = 'Photos_CATEGORY_DELETE_FAIL',
	[481] = 'Photos_CATEGORY_EDIT_FAIL',
	[482] = 'Photos_CATEGORY_ARRANGE_FAIL',
	[483] = 'Photos_CATEGORY_ADD_ITEM_FAIL',
	[484] = 'Photos_CATEGORY_LIST_ITEM_FAIL',
	[485] = 'Photos_CATEGORY_REMOVE_ITEM_FAIL',
	[486] = 'Photos_CATEGORY_ARRANGE_ITEM_FAIL',
	[487] = 'Photos_CATEGORY_DUPLICATE',

    -- SYNO.Photos.Comment (491-495)
	[491] = 'Photos_COMMENT_VALIDATE_FAIL',
	[492] = 'Photos_COMMENT_ACCESS_DENY',
	[493] = 'Photos_COMMENT_CREATE_FAIL',

    -- SYNO.Photos.Thumb (496-505)
	[501] = 'Photos_THUMB_BAD_PARAMS',
	[502] = 'Photos_THUMB_ACCESS_DENY',
	[503] = 'Photos_THUMB_NO_COVER',
	[504] = 'Photos_THUMB_FILE_NOT_EXISTS',

    -- SYNO.Photos.Download (506-515)
	[506] = 'Photos_DOWNLOAD_BAD_PARAMS',
	[507] = 'Photos_DOWNLOAD_ACCESS_DENY',
	[508] = 'Photos_DOWNLOAD_CHDIR_ERROR',

    -- SYNO.Photos.File (516-525)
	[516] = 'Photos_FILE_BAD_PARAMS',
	[517] = 'Photos_FILE_ACCESS_DENY',
	[518] = 'Photos_FILE_FILE_EXT_ERR',
	[519] = 'Photos_FILE_DIR_NOT_EXISTS',
	[520] = 'Photos_FILE_UPLOAD_ERROR',
	[521] = 'Photos_FILE_NO_FILE',
	[522] = 'Photos_FILE_UPLOAD_CANT_WRITE',

    -- SYNO.Photos.Cover (526-530)
	[526] = 'Photos_COVER_ACCESS_DENY',
	[527] = 'Photos_COVER_ALBUM_NOT_EXIST',
	[528] = 'Photos_COVER_PHOTO_VIDEO_NOT_EXIST',
	[529] = 'Photos_COVER_PHOTO_VIDEO_NOT_IN_ALBUM',
	[530] = 'Photos_COVER_SET_FAIL',

    -- SYNO.Photos.Rotate (531-535)
	[531] = 'Photos_ROTATE_ACCESS_DENY',
	[532] = 'Photos_ROTATE_SET_FAIL',

    -- SYNO.Photos.SlideshowMusic (536-545)
	[536] = 'Photos_SLIDESHOWMUSIC_ACCESS_DENY',
	[537] = 'Photos_SLIDESHOWMUSIC_SET_FAIL',
	[538] = 'Photos_SLIDESHOWMUSIC_FILE_EXT_ERR',
	[539] = 'Photos_SLIDESHOWMUSIC_UPLOAD_ERROR',
	[540] = 'Photos_SLIDESHOWMUSIC_NO_FILE',
	[541] = 'Photos_SLIDESHOWMUSIC_EXCEED_LIMIT',

    -- SYNO.Photos.DsmShare (546-550)
	[546] = 'Photos_DSMSHARE_UPLOAD_ERROR',
	[547] = 'Photos_DSMSHARE_ACCESS_DENY',

    -- SYNO.Photos.SharedAlbum (551-560)
	[551] = 'Photos_SHARED_ALBUM_ACCESS_DENY',
	[552] = 'Photos_SHARED_ALBUM_BAD_PARAMS',
	[553] = 'Photos_SHARED_ALBUM_HAS_EXISTED',
	[554] = 'Photos_SHARED_ALBUM_CREATE_FAIL',
	[555] = 'Photos_SHARED_ALBUM_NOT_EXISTS',
	[556] = 'Photos_SHARED_ALBUM_GET_INFO_ERROR',
	[557] = 'Photos_SHARED_ALBUM_LIST_ERROR',

    -- SYNO.Photos.Log (561-565)
	[561] = 'Photos_LOG_ACCESS_DENY',

    -- SYNO.Photos.PATH (566-570)
	[566] = 'Photos_PATH_ACCESS_DENY',

    -- SYNO.Photos.ACL (571-580)
	[571] = 'Photos_ACL_NOT_SUPPORT',
	[572] = 'Photos_ACL_CONVERT_FAIL',

    -- SYNO.Photos.AdvancedShare (581-590)
	[581] = 'Photos_PHOTO_AREA_TAG_ADD_FAIL',
	[582] = 'Photos_PHOTO_AREA_TAG_NOT_ENABLED',
	[583] = 'Photos_PHOTO_AREA_TAG_DELETE_FAIL',
]]

    -- Lr HTTP errors
	[1001]  = 'Http error: no response body, no response header',
	[1002]  = 'Http error: no response data, no errorcode in response header',
	[1003]  = 'Http error: No JSON response data',
	[12007] = 'Http error: cannotFindHost',
	[12029] = 'Http error: cannotConnectToHost',
	[12038] = 'Http error: serverCertificateHasUnknownRoot',
}

---------------------------------------------------------------------------------------------------------
-- getErrorMsg(errorCode)
-- translates errorCode to ErrorMsg
function Photos.getErrorMsg(errorCode)
	if PSAPIerrorMsgs[errorCode] == nil then
		-- we don't have a documented  message for that code
		return string.format("ErrorCode: %d", errorCode)
	end
	return PSAPIerrorMsgs[errorCode]
end

-- #####################################################################################################
-- ########################## folder management #########################################################
-- #####################################################################################################

---------------------------------------------------------------------------------------------------------
-- listAlbumSubfolders: returns all subfolders in a given folder
-- returns
--		subfolderList:	table of subfolder infos, if success, otherwise nil
--		errorcode:		errorcode, if not success
function Photos.listAlbumSubfolders(h, folderPath, folderId)
	local apiParams = {
			id				= folderId or Photos.getFolderId(h, folderPath),
			additional		= "[]",
			sort_direction	= "asc",
			offset			= 0,
			limit			= 2000,
			api				= "SYNO.FotoTeam.Browse.Folder",
			method			= "list",
			version			= 1
	}
	local respArray, errorCode = Photos.callSynoWebapi(h, apiParams)

	if not respArray then return nil, errorCode end

	writeTableLogfile(5, string.format("listAlbumSubfolders('%s') returns %d items\n", folderPath, #respArray.data.list))
	return respArray.data.list
end

---------------------------------------------------------------------------------------------------------
-- listAlbumItems: returns all items (photos/videos) in a given folder
-- returns
--		itemList:		table of item infos, if success, otherwise nil
--		errorcode:		errorcode, if not success
function Photos.listAlbumItems(h, folderPath, folderId)
	local apiParams = {
			folder_id		= folderId or Photos.getFolderId(h, folderPath),
			additional		= '["description","tag","exif","gps","video_meta","address","person"]',
			sort_by			= "takentime",
			sort_direction	= "asc",
			offset			= 0,
			limit			= 5000,
			api				= "SYNO.FotoTeam.Browse.Item",
			method			= "list",
			version			= 1
	}
			
	local respArray, errorCode = Photos.callSynoWebapi(h, apiParams)

	if not respArray then return nil, errorCode end

	writeTableLogfile(5, string.format("listAlbumItems('%s') returns %d items\n", folderPath, #respArray.data.list))
	return respArray.data.list
end

--====== Photos Utilities ==============================================================================--
-- ========================================== path Id Cache ==========================================
-- The path id cache holds ids of folders and items (photo/video) as used by the PhotosAPI
-- layout:
--		pathIdCache
--			[userid] (0 for Team Folders)
--				[path] = { id, type, addinfo (only for items), validUntil }
local pathIdCache = {
	cache = {
		-- Team folders belong to userid 0
		[0] = {	}
	},
	timeout			= 300,
	listFunction	= {
		["folder"]	= Photos.listAlbumSubfolders,
		["item"]	= Photos.listAlbumItems
	},
 	Photos.listAlbumSubfolders,
}

---------------------------------------------------------------------------------------------------------
-- pathIdCacheCleanup: remove old entries from id cache
--   if path is given, remove this cache regardless of its age
local function pathIdCacheCleanup(userid, path)
	local user_pathIdCache = pathIdCache.cache[userid]
	
	if path and string.sub(path, 1, 1) ~= "/" then path = "/" .. path end

	if not user_pathIdCache then return true end

	for key, entry in pairs(user_pathIdCache) do
		if (entry.validUntil < LrDate.currentTime())
		or (key == path) then
			writeLogfile(3, string.format("pathIdCacheCleanup(user:%s); removing path '%s'\n", userid, key))
			user_pathIdCache[key] = nil
		end
	end
	return true
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
	tagMapping[type] = h:getTags(type)
	return tagMapping[type]
end

--[[
Photos.callSynoWebapi (h, apiParams)
	calls the named synoAPI with the respective parameters in formData
	returns nil, on http error
	returns the decoded JSON response as table on success
]]
function Photos.callSynoWebapi (h, apiParams)
	local postHeaders = {
		{ field = 'X-SYNO-HHID',	value = h.hhid },
		{ field = 'Content-Type',	value = 'application/x-www-form-urlencoded' },
		iif(h.synotoken, { field = 'X-SYNO-TOKEN',	value = h.synotoken }, nil),
	}

	local synoAPI, postBody = '', ''
	for key, value in pairs(apiParams) do
		if key == 'api' then 
			if h.userid ~= 0 then value = string.gsub(value, 'FotoTeam', 'Foto') end
			synoAPI = value
		end
		postBody = postBody .. iif(string.len(postBody) > 0, '&', '') .. key .. '=' .. value
    end

	writeLogfile(4, string.format("Photos.callSynoWebapi: LrHttp.post(url='%s%s%s', API=%s params='%s')\n",
						h.serverUrl, h.psWebAPI, h.apiInfo[synoAPI].path, synoAPI,
						iif(synoAPI == 'SYNO.API.Auth', string.gsub(postBody, '(.*passwd=)([^&]*)(&.*)', '%1...%3'), postBody)))

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

	local respArray = JSON:decode(respBody, "Photos.callSynoWebapi(" .. synoAPI .. ")")

	if not respArray then return nil, 1003 end

	if respArray.error then
		local errorCode = tonumber(respArray.error.code)
		writeLogfile(3, string.format('Photos.callSynoWebapi: %s returns error %d (%s)\n', synoAPI, errorCode, Photos.getErrorMsg(errorCode)))
		return nil, errorCode
	end

	return respArray
end


-- ########################## session management #######################################################
---------------------------------------------------------------------------------------------------------
-- initialize: set serverUrl, loginPath
function Photos.new(serverUrl, usePersonalPS, personalPSOwner, serverTimeout, version)
	local h = {} -- the handle
	local apiInfo = {}

	writeLogfile(4, string.format("Photos.new(url=%s, personal=%s, persUser=%s, timeout=%d)\n", serverUrl, usePersonalPS, personalPSOwner, serverTimeout))

	h.serverUrl 	= serverUrl
	h.serverTimeout = serverTimeout
	h.serverVersion	= version

	if usePersonalPS then
		h.psFolderRoot	= 	'/?launchApp=SYNO.Foto.AppInstance#/personal_space/folder/'
		h.userid 		= personalPSOwner
	else
		h.psFolderRoot	= 	'/?launchApp=SYNO.Foto.AppInstance#/shared_space/folder/'
		h.userid		= 	0
	end

	h.psWebAPI 		= 	'/webapi/'
	h.hhid			= 	'9252' -- TODO: use random id

	-- bootstrap the apiInfo table
	apiInfo['SYNO.API.Info'] = {
		path		= "query.cgi",
		minVersion	= 1,
		maxVersion	= 1,
	}
	h.apiInfo = apiInfo

	-- get all API paths via 'SYNO.API.Info'
	local apiParams = {
		query	= 'all',
		api		= 'SYNO.API.Info',
		method	= 'query',
		version	= '1'
	}
	local respArray, errorCode = Photos.callSynoWebapi (h, apiParams)

	if not respArray then return nil, errorCode end

	h.serverCapabilities = PHOTOSERVER_API[version].capabilities
	h.Photo 	= PhotosPhoto.new()

	writeLogfile(3, 'Photos.new() returns:\n' .. JSON:encode(h) .."\n")

	-- rewrite the apiInfo table with API infos retrieved via SYNO.API.Info
	h.apiInfo 	= respArray.data

	return setmetatable(h, Photos_mt)
end

---------------------------------------------------------------------------------------------------------
-- supports(h, metadataType)
function Photos.supports (h, capabilityType)
	return PHOTOSERVER_API.supports (h.serverVersion, capabilityType)
end

---------------------------------------------------------------------------------------------------------
-- login(h, username, passowrd)
-- does, what it says
function Photos.login(h, username, password)
	local apiParams = {
		api 				= "SYNO.API.Auth",
		version 			= "7",
		method 				= "login",
		session 			= "webui",
		account				= urlencode(username),
		passwd				= urlencode(password),
		logintype			= "local",
--		otp_code			= "",
--		enable_device_token	= "no",
--		rememberme			= "0",
--		timezone			= "+01:00",
		hhid 				= h.hhid,
		enable_syno_token 	= "yes",
--		ik_message =  "MRbQfACEC4kjS1SFetrwa_LKZnrkUWGxLBjuIrk0R2oyxe363W6N32S1cUdYvWQCheg55CUS5mQKbu-j4naAKZQljStTnc6dDrQ-QmrEEbgHojpnL5zAqgLepe2b0H8F",
		launchApp 			=  "SYNO.Foto.Sharing.AppInstance",
		app_name 			=  "SYNO.Foto.Sharing.AppInstance",
		action 				= "external_login",
		folderId			= "1",
		alias 				= "photo",
	}
	local respArray, errorCode = Photos.callSynoWebapi(h, apiParams)

	if not respArray then return false, errorCode end

	h.synotoken = respArray.data.synotoken

	local rootFolderId
	if h.userid == 0 then
		rootFolderId = 1
	else
		-- if Login to Personal Photos, get folderId of personal root folder
		rootFolderId, errorCode = Photos.getPersonalRootFolderId(h)
	end
	if not rootFolderId then return false, errorCode end

	-- initialize folderId cache w/ root folder
	Photos.addPathToCache(h, "/", rootFolderId, "folder")

	return respArray.success
end

---------------------------------------------------------------------------------------------------------
-- logout(h)
-- nothing to do here, invalidating the cookie would be perfect here
function Photos.logout (h)
	return true
end

---------------------------------------------------------------------------------------------------------
-- getPersonalRootFolderId(h)
-- get folder id of personal root folder
function Photos.getPersonalRootFolderId (h)
	local apiParams = {
		id			= 0,
	-- 	additional	= ["access_permission"],
		api			= "SYNO.Foto.Browse.Folder",
		method		= "get",
		version		= 1
	}

	local respArray, errorCode = Photos.callSynoWebapi(h, apiParams)
	if not respArray then return false, errorCode end

	return respArray.data.folder.id
end

-- createFolder (h, parentDir, newDir) 
-- parentDir must exit
-- newDir may or may not exist, will be created 
function Photos.createFolder (h, parentDir, newDir)
	writeLogfile(3, string.format("Photos.createFolder('%s', '%s') ...\n", parentDir, newDir))
	local apiParams = {
		api 				= "SYNO.FotoTeam.Browse.Folder",
		version 			= "1",
		method 				= "create",
		target_id			= Photos.getFolderId(h, parentDir),
		name				= '"' .. newDir .. '"'
	}
	local respArray, errorCode = Photos.callSynoWebapi(h, apiParams)

	if not respArray and Photos.getErrorMsg(errorCode) == 'error_file_exist' then 
		return Photos.getFolderId(h, LrPathUtils.child(parentDir, newDir))
	end

	if not respArray then return false, errorCode end
	local folderId = respArray.data.folder.id
	writeLogfile(3, string.format("Photos.createFolder('%s', '%s') returns %d\n", parentDir, newDir, folderId))

	return folderId
end

-- #####################################################################################################
-- ########################## tag management ###########################################################
-- #####################################################################################################

---------------------------------------------------------------------------------------------------------
-- getTags (h, type)
-- get table of tagId/tagString mappings for given type: desc, people, geo
function Photos.getTags(h, type)
	-- TODO: evaluate type
	writeLogfile(3, string.format("Photos.getTags('%s') ...\n", type))
	local apiParams = {
		api 				= "SYNO.FotoTeam.Browse.GeneralTag",
		version 			= "1",
		method 				= "list",
		offset				= "0",
		limit				= "5000"
	}
	local respArray, errorCode = Photos.callSynoWebapi(h, apiParams)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('getTags returns %d tags.\n', #respArray.data.list))
	return respArray.data.list
end

---------------------------------------------------------------------------------------------------------
-- createTag (h, type, name)
-- create a new tagId/tagString mapping of or given type: desc, people, geo
function Photos.createTag(h, type, name)
	-- TODO: evaluate type
	writeLogfile(3, string.format("Photos.createTag('%s', '%s') ...\n", type, name))
	local apiParams = {
		api 				= "SYNO.FotoTeam.Browse.GeneralTag",
		version 			= "1",
		method 				= "create",
		name				= '"' .. name ..'"'
	}
	local respArray, errorCode = Photos.callSynoWebapi(h, apiParams)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format("createTag('%s') returns id %d \n", name, respArray.data.tag.id))
	return respArray.data.tag.id
end

-- #####################################################################################################
-- ########################## photo management #########################################################
-- #####################################################################################################

--[[
---------------------------------------------------------------------------------------------------------
-- getPhotoExifs (h, dstFilename)
function Photos.getPhotoExifs (h, dstFilename)
	local formData = 'method=getexif&' ..
					 'version=1&' ..
					 'id=' .. Photos.getPhotoId(h, dstFilename)

	local respArray, errorCode = callSynoAPI (h, 'SYNO.Photos.Photo', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('getPhotoExifs(%s) returns %d exifs.\n', dstFilename, respArray.data.total))
	return respArray.data.exifs
end
]]

---------------------------------------------------------------------------------------------------------
-- editPhoto (h, photoPath, attrValPairs)
-- edit specific metadata field of a photo
function Photos.editPhoto(h, photoPath, attrValPairs)
	writeLogfile(3, string.format("Photos.editPhoto('%s', %d items) ...\n", photoPath, #attrValPairs))
	local apiParams = {
		api 				= "SYNO.FotoTeam.Browse.Item",
		version 			= "1",
		method 				= "set",
		id					= "[" .. h:getPhotoId(photoPath) .. "]",
	}
	for i = 1, #attrValPairs do
		apiParams[attrValPairs[i].attribute] = '"' .. attrValPairs[i].value .. '"'
	end
	local respArray, errorCode = h:callSynoWebapi(apiParams)

	if not respArray then return nil, errorCode end

	writeLogfile(3, string.format('editPhoto(%s) returns OK\n', photoPath))
	return respArray.success, errorCode
end

---------------------------------------------------------------------------------------------------------
-- addPhotoTag (h, photoPath, type, tagId, addinfo)
-- add a new tag (general,people,geo) to a photo
function Photos.addPhotoTag(h, photoPath, type, tagId, addinfo)
	-- TODO: evaluate type
	writeLogfile(4, string.format("addPhotoTag('%s', '%s') ...\n", photoPath, tagId))
	local apiParams = {
		api 				= "SYNO.FotoTeam.Browse.Item",
		version 			= "1",
		method 				= "add_tag",
		id					= "[" .. h:getPhotoId(photoPath) .. "]",
		tag					= "[" .. tagId .. "]",
	}

	local respArray, errorCode = h:callSynoWebapi(apiParams)

	if not respArray then return nil, errorCode end

	writeLogfile(3, string.format("addPhotoTag('%s', '%s') returns OK\n", photoPath, tagId))
	return respArray.success, errorCode
end

---------------------------------------------------------------------------------------------------------
-- removePhotoTag(h, photoPath, tagType, tagId)
-- remove a tag from a photo
function Photos.removePhotoTag(h, photoPath, tagType, tagId)
	-- TODO: evaluate type
	writeLogfile(4, string.format("removePhotoTag('%s', '%s') ...\n", photoPath, tagId))
	local apiParams = {
		api 				= "SYNO.FotoTeam.Browse.Item",
		version 			= "1",
		method 				= "remove_tag",
		id					= "[" .. h:getPhotoId(photoPath) .. "]",
		tag					= "[" .. tagId .. "]",
	}

	local respArray, errorCode = h:callSynoWebapi(apiParams)

	if not respArray then return nil, errorCode end

	writeLogfile(3, string.format("removePhotoTag('%s', '%s') returns OK\n", photoPath, tagId))
	return respArray.success, errorCode
end

--[[
---------------------------------------------------------------------------------------------------------
-- getPhotoComments (h, dstFilename, isVideo)
function Photos.getPhotoComments (h, dstFilename, isVideo)
	local formData = 'method=list&' ..
					 'version=1&' ..
					 'id=' .. Photos.getPhotoId(h, dstFilename, isVideo)

	local respArray, errorCode = callSynoAPI (h, 'SYNO.Photos.Comment', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('getPhotoComments(%s) returns OK.\n', dstFilename))
	return respArray.data.comments
end

---------------------------------------------------------------------------------------------------------
-- addPhotoComment (h, dstFilename, isVideo, comment, username)
function Photos.addPhotoComment (h, dstFilename, isVideo, comment, username)
	local formData = 'method=create&' ..
					 'version=1&' ..
					 'id=' .. Photos.getPhotoId(h, dstFilename, isVideo) .. '&' ..
					 'name=' .. username .. '&' ..
					 'comment='.. urlencode(comment)

	local respArray, errorCode = callSynoAPI (h, 'SYNO.Photos.Comment', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('addPhotoComment(%s, %s, %s) returns OK.\n', dstFilename, comment, username))
	return respArray.success
end
]]

---------------------------------------------------------------------------------------------------------
-- movePhoto (h, srcFilename, dstFolder, isVideo)
function Photos.movePhoto(h, srcPhotoPath, dstFolder, isVideo)
	local photoId = h:getPhotoId(srcPhotoPath, isVideo)
	if not photoId then
		writeLogfile(3, string.format('movePhoto(%s): does not exist, returns false\n', srcPhotoPath))
		return false
	end
	local srcFolderId = h:getFolderId(normalizeDirname(LrPathUtils.parent(srcPhotoPath)))
	local dstFolderId = h:getFolderId(normalizeDirname(dstFolder))
	if not dstFolderId then
		writeLogfile(3, string.format('movePhoto(%s): does not exist, returns false\n', srcPhotoPath))
		return false
	end

-- target_folder_id=10&item_id=[13]&folder_id=[]&action="skip"&extra_info="{\"version\":1,\"source_folder_ids\":[1]}"&api="SYNO.FotoTeam.BackgroundTask.File"&method="move"&version=1
	local apiParams = {
		target_folder_id = dstFolderId,
		item_id		= "[" .. photoId  .. "]",
		folder_id	= "[]",
		action 		= '"skip"',
		extra_info	= '"{\"version\":1,\"source_folder_ids\":[' .. srcFolderId .. ']}',
		api			= "SYNO.FotoTeam.BackgroundTask.File",
		method		= "move",
		version		= 1
	}

	local respArray, errorCode = h:callSynoWebapi(apiParams)

	if not respArray then return nil, errorCode end

	writeLogfile(3, string.format('movePhoto(%s, %s) returns OK\n', srcPhotoPath, dstFolder))
	return respArray.success, errorCode
end

---------------------------------------------------------------------------------------------------------
-- deletePhoto (h, path, isVideo)
function Photos.deletePhoto (h, path, isVideo)
	local photoId = h:getPhotoId(path, isVideo)
	if not photoId then
		writeLogfile(3, string.format('deletePhoto(%s): does not exist, returns OK\n', path))
		return true
	end

	local apiParams = {
		id		= "[" .. photoId  .. "]",
		api		= "SYNO.FotoTeam.Browse.Item",
		method	= "delete",
		version	= 1
	}

	pathIdCacheCleanup(h.userid, path)
	
	local respArray, errorCode = h:callSynoWebapi(apiParams)

	if not respArray then return nil, errorCode end

	writeLogfile(3, string.format('deletePhoto(%s) returns OK (errorCode was %d)\n', path, ifnil(errorCode, 0)))
	return respArray.success, errorCode
end

--[[
---------------------------------------------------------------------------------------------------------
-- sortAlbumPhotos (h, folderPath, sortedPhotos)
function Photos.sortAlbumPhotos (h, folderPath, sortedPhotos)
	local formData = 'method=arrangeitem&' ..
					 'version=1&' ..
					 'offset=0&' ..
					 'limit='.. #sortedPhotos .. '&' ..
					 'id=' .. Photos.getFolderId(h, folderPath)
	local i, photoPath, item_ids = {}

	for i, photoPath in ipairs(sortedPhotos) do
		if i == 1 then
			item_ids = Photos.getPhotoId(h, sortedPhotos[i])
		else
			item_ids = item_ids .. ',' .. Photos.getPhotoId(h, sortedPhotos[i])
		end
	end

	formData = formData .. '&item_id=' .. item_ids

	local respArray, errorCode = callSynoAPI (h, 'SYNO.Photos.Folder', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('sortAlbumPhotos(%s) returns OK.\n', folderPath))
	return respArray.success
end
]]

---------------------------------------------------------------------------------------------------------
-- deleteAlbum(h, folderPath)
function Photos.deleteAlbum (h, folderPath)
	local folderId = h:getFolderId(folderPath)
	if not folderId then
		writeLogfile(3, string.format('deleteAlbum(%s): does not exist, returns OK\n', folderPath))
		return true
	end

	local apiParams = {
		id		= "[" .. folderId  .. "]",
		api		= "SYNO.FotoTeam.Browse.Folder",
		method	="delete",
		version=1
	}

	pathIdCacheCleanup(h.userid, folderPath)

	local respArray, errorCode = h:callSynoWebapi(apiParams)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('deleteAlbum(%s) returns OK\n', folderPath))
	return respArray.success, errorCode
end

---------------------------------------------------------------------------------------------------------
-- deleteEmptyAlbumAndParents(h, folderPath)
-- delete an folder and all its parents as long as they are empty
-- return count of deleted folders
function Photos.deleteEmptyAlbumAndParents(h, folderPath)
	local nDeletedFolders = 0
	local currentFolderPath

	currentFolderPath = folderPath
	while currentFolderPath do
		local photoInfos =  h:listAlbumItems(currentFolderPath)
		local subfolders =  h:listAlbumSubfolders(currentFolderPath)

    	-- if not empty, we are ready
    	if 		(photoInfos and #photoInfos > 0)
    		or 	(subfolders	and	#subfolders > 0)
    	then
   			writeLogfile(3, string.format('deleteEmptyAlbumAndParents(%s) - was not empty: not deleted.\n', currentFolderPath))
    		return nDeletedFolders
		elseif not h:deleteAlbum (currentFolderPath) then
			writeLogfile(2, string.format('deleteEmptyAlbumAndParents(%s) - was empty: delete failed!\n', currentFolderPath))
		else
			writeLogfile(2, string.format('deleteEmptyAlbumAndParents(%s) - was empty: deleted.\n', currentFolderPath))
			nDeletedFolders = nDeletedFolders + 1
		end

		currentFolderPath = string.match(currentFolderPath , '(.+)/[^/]+')
	end

	return nDeletedFolders
end

--[[
-- #####################################################################################################
-- ########################## shared album management ##################################################
-- #####################################################################################################

---------------------------------------------------------------------------------------------------------
-- getSharedAlbums (h)
-- get table of sharedAlbumId/sharedAlbumName mappings
function Photos.getSharedAlbums(h)
	local formData = 'method=list&' ..
					 'version=1&' ..
					 'additional=public_share&' ..
					 'offset=0&' ..
					 'limit=-1'

	local respArray, errorCode = callSynoAPI (h, 'SYNO.Photos.SharedAlbum', formData)

	if not respArray then return nil, errorCode end

	writeLogfile(3, string.format('getSharedAlbums() returns %d albums.\n', respArray.data.total))
	return respArray.data.items
end

---------------------------------------------------------------------------------------------------------
-- listSharedAlbum: returns all photos/videos in a given shared album
-- returns
--		albumItems:		table of photo infos, if success, otherwise nil
--		errorcode:		errorcode, if not success
function Photos.listSharedAlbum(h, sharedAlbumName)
	local albumId  = Photos.getSharedAlbumId(h, sharedAlbumName)
	if not albumId then
		writeLogfile(3, string.format('listSharedAlbum(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end

	local formData = 'method=list&' ..
					 'version=1&' ..
					 'filter_shared_album=' .. albumId .. '&' ..
					 'offset=0&' ..
					 'limit=-1&' ..
					 'recursive=false&'..
					 'additional=photo_exif'
--					 'additional=photo_exif,video_codec,video_quality,thumb_size'

	local respArray, errorCode = callSynoAPI (h, 'SYNO.Photos.Photo', formData)

	if not respArray then return nil, errorCode end

	writeTableLogfile(5, 'listSharedAlbum', respArray.data.items)
	return respArray.data.items
end

---------------------------------------------------------------------------------------------------------
-- createSharedAlbum(h, name)
function Photos.createSharedAlbum(h, sharedAlbumName)
	local formData = 'method=create&' ..
					 'version=1&' ..
					 'name=' .. urlencode(sharedAlbumName)

	local respArray, errorCode = callSynoAPI (h, 'SYNO.Photos.SharedAlbum', formData)

	if not respArray then return false, errorCode end

	writeLogfile(2, string.format('createSharedAlbum(%s) returns sharedAlbumId %s.\n', sharedAlbumName, respArray.data.id))
	return respArray.data.id
end

---------------------------------------------------------------------------------------------------------
-- editSharedAlbum(h, sharedAlbumName, sharedAlbumAttributes)
function Photos.editSharedAlbum(h, sharedAlbumName, sharedAlbumAttributes)
	local albumId  = Photos.getSharedAlbumId(h, sharedAlbumName)
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

	local respArray, errorCode = callSynoAPI (h, 'SYNO.Photos.SharedAlbum', formData)

	if not respArray then return nil, errorCode end

	writeLogfile(3, string.format('editSharedAlbum(%s, %d attributes) returns shareId %s.\n', sharedAlbumName, numAttributes, respArray.data.shareid))
	return respArray.data
end

---------------------------------------------------------------------------------------------------------
-- Photos.addPhotosToSharedAlbum(h, sharedAlbumName, photos)
-- add photos to Shared Album
function Photos.addPhotosToSharedAlbum(h, sharedAlbumName, photos)
	local albumId  = Photos.getSharedAlbumId(h, sharedAlbumName)
	if not albumId then
		writeLogfile(3, string.format('addPhotosToSharedAlbum(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end

	local photoIds = {}
	for i = 1, #photos do
		photoIds[i] = Photos.getPhotoId(h, photos[i].dstFilename, photos[i].isVideo)
	end
	local itemList = table.concat(photoIds, ',')
	local formData = 'method=add_items&' ..
				 'version=1&' ..
				 'id=' ..  albumId .. '&' ..
				 'item_id=' .. itemList

	local respArray, errorCode = callSynoAPI (h, 'SYNO.Photos.SharedAlbum', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('addPhotosToSharedAlbum(%s, %d photos) returns OK.\n', sharedAlbumName, #photos))
	return true
end

---------------------------------------------------------------------------------------------------------
-- Photos.removePhotosFromSharedAlbum(h, sharedAlbumName, photos)
-- remove photos from Shared Album
function Photos.removePhotosFromSharedAlbum(h, sharedAlbumName, photos)
	local albumId  = Photos.getSharedAlbumId(h, sharedAlbumName)
	if not albumId then
		writeLogfile(3, string.format('removePhotosFromSharedAlbum(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end

	local photoIds = {}
	for i = 1, #photos do
		photoIds[i] = Photos.getPhotoId(h, photos[i].dstFilename, photos[i].isVideo)
	end
	local itemList = table.concat(photoIds, ',')
	local formData = 'method=remove_items&' ..
				 'version=1&' ..
				 'id=' .. albumId .. '&' ..
				 'item_id=' .. itemList

	local respArray, errorCode = callSynoAPI (h, 'SYNO.Photos.SharedAlbum', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('removePhotosFromSharedAlbum(%s, %d photos) returns OK.\n', sharedAlbumName, #photos))
	return true
end
]]
--[[ currently not needed
---------------------------------------------------------------------------------------------------------
-- addSharedPhotoComment (h, dstFilename, isVideo, comment, username, sharedAlbumName)
function Photos.addSharedPhotoComment (h, dstFilename, isVideo, comment, username, sharedAlbumName)
	local formData = 'method=add_comment&' ..
					 'version=1&' ..
					 'item_id=' .. Photos.getPhotoId(h, dstFilename, isVideo) .. '&' ..
					 'name=' .. username .. '&' ..
					 'comment='.. urlencode(comment) ..'&' ..
					 'public_share_id=' .. Photos.getSharedAlbumShareId(h, sharedAlbumName)

	local respArray, errorCode = callSynoAPI (h, 'SYNO.Photos.AdvancedShare', formData)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('addSharedPhotoComment(%s, %s, %s, %s) returns OK.\n', dstFilename, sharedAlbumName, comment, username))
	return respArray.success
end
]]

--[[ currently not needed
---------------------------------------------------------------------------------------------------------
-- renameSharedAlbum(h, sharedAlbumName, newSharedAlbumName)
function Photos.renameSharedAlbum(h, sharedAlbumName, newSharedAlbumName)
	local albumId  = Photos.getSharedAlbumId(h, sharedAlbumName)
	if not albumId then
		writeLogfile(3, string.format('renameSharedAlbum(%s, %s): album not found!\n', sharedAlbumName, newSharedAlbumName))
		return false, 555
	end

	local formData = 'method=edit&' ..
					 'version=1&' ..
					 'name='  ..  newSharedAlbumName .. '&' ..
					 'id=' .. albumId

	local success, errorCode = callSynoAPI (h, 'SYNO.Photos.SharedAlbum', formData)

	if not success then return false, errorCode end

	writeLogfile(3, string.format('renameSharedAlbum(%s, %s) returns OK.\n', sharedAlbumName, newSharedAlbumName))
	return true
end

---------------------------------------------------------------------------------------------------------
-- deleteSharedAlbum(h, sharedAlbumName)
function Photos.deleteSharedAlbum(h, sharedAlbumName)
	local albumId  = Photos.getSharedAlbumId(h, sharedAlbumName)
	if not albumId then
		writeLogfile(3, string.format('deleteSharedAlbum(%s): album not found, returning OK anyway!\n', sharedAlbumName))
		return true
	end

	local formData = 'method=delete&' ..
					 'version=1&' ..
					 'id=' .. albumId

	local success, errorCode = callSynoAPI (h, 'SYNO.Photos.SharedAlbum', formData)

	if not success then return false, errorCode end

	writeLogfile(3, string.format('deleteSharedAlbum(%s) returns OK.\n', sharedAlbumName))
	return true
end

-- #####################################################################################################
-- ########################## public shared album management ###########################################
-- #####################################################################################################

---------------------------------------------------------------------------------------------------------
-- listPublicSharedAlbum: returns all photos/videos in a given public shared album
-- returns
--		albumItems:		table of photo infos, if success, otherwise nil
--		errorcode:		errorcode, if not success
function Photos.listPublicSharedAlbum(h, sharedAlbumName)
	local shareId  = Photos.getSharedAlbumShareId(h, sharedAlbumName)
	if not shareId then
		writeLogfile(3, string.format('listPublicSharedAlbum(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end

	local formData = 'method=list&' ..
					 'version=1&' ..
					 'filter_public_share=' .. shareId .. '&' ..
					 'offset=0&' ..
					 'limit=-1&' ..
					 'color_label=0,1,2,3,4,5,6&'..
					 'additional=photo_exif'

	local respArray, errorCode = callSynoAPI (h, 'SYNO.Photos.Photo', formData)

	if not respArray then return nil, errorCode end

	writeTableLogfile(5, 'listPublicSharedAlbum', respArray.data.items)
	return respArray.data.items
end

---------------------------------------------------------------------------------------------------------
-- getPublicSharedAlbumInfo (h, sharedAlbumName)
function Photos.getPublicSharedAlbumInfo (h, sharedAlbumName)
	local shareId  = Photos.getSharedAlbumShareId(h, sharedAlbumName)
	if not shareId then
		writeLogfile(3, string.format('getPublicSharedAlbumInfo(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end

	local formData = 'method=getinfo_public&' ..
					 'version=1&' ..
					 'public_share_id=' .. shareId

	local respArray, errorCode = callSynoAPI (h, 'SYNO.Photos.SharedAlbum', formData)

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
function Photos.getPublicSharedAlbumLogList (h, sharedAlbumName)
	local shareId  = Photos.getSharedAlbumShareId(h, sharedAlbumName)
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

	local respArray, errorCode = callSynoAPI (h, 'SYNO.Photos.AdvancedShare', formData)

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
function Photos.getPublicSharedPhotoComments (h, sharedAlbumName, dstFilename, isVideo)
	local shareId  = Photos.getSharedAlbumShareId(h, sharedAlbumName)
	if not shareId then
		writeLogfile(3, string.format('getPublicSharedPhotoComments(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end

	local formData = 'method=list_comment&' ..
					 'version=1&' ..
					 'offset=0&' ..
					 'limit=-1&' ..
					 'item_id=' 		.. Photos.getPhotoId(h, dstFilename, isVideo) .. '&' ..
					 'public_share_id=' .. shareId

	local respArray, errorCode = callSynoAPI (h, 'SYNO.Photos.AdvancedShare', formData)

	if not respArray then return false, errorCode end

	if respArray.data then
		writeLogfile(3, string.format('getPublicSharedPhotoComments(%s, %s) returns %d comments.\n', dstFilename, sharedAlbumName, #respArray.data))
	else
		writeLogfile(3, string.format('getPublicSharedPhotoComments(%s, %s) returns no comments.\n', dstFilename, sharedAlbumName))
	end
	return respArray.data
end
]]
-- #####################################################################################################
-- ########################## upload ###################################################################
-- #####################################################################################################

local function checkPSUploadAPIAnswer(funcAndParams, respHeaders, respBody)
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

	local respArray = JSON:decode(respBody, "checkPSUploadAPIAnswer(" .. funcAndParams .. ")")

	if not respArray then
		success = false
		errorMsg = Photos.getErrorMsg(1003)
 	elseif not respArray.success then
 		success = false
    	errorMsg = respArray.err_msg
 	end
 	
 	if not success then
	   	writeLogfile(1, string.format("%s failed: %s!\n", funcAndParams, errorMsg))
 	end 

	return success, errorMsg
end

function Photos.uploadPictureFiles(h, dstDir, dstFilename, srcDateTime, mimeType, srcFilename, thumbGenerate, thmb_XL_Filename, thmb_M_Filename, thmb_S_Filename)
	local postHeaders = {
		{ field = 'X-SYNO-HHID',	value = h.hhid },
		{ field = 'X-SYNO-TOKEN',	value = h.synotoken },
	}
	writeLogfile(3, string.format("uploadPictureFiles('%s', '%s', '%s', %s', '%s', '%s', '%s', '%s', '%s')\n",
				dstDir, dstFilename, srcDateTime, mimeType, srcFilename, thumbGenerate, thmb_XL_Filename, thmb_M_Filename, thmb_S_Filename))

	-- calculate max. upload time for LrHttp.post()
	-- we expect a minimum of 10 MBit/s upload speed --> 1.25 MByte/s
	local fileSize = LrFileUtils.fileAttributes(srcFilename).fileSize
	if not fileSize then
		local errorMsg = "uploadPictureFiles: cannot get fileSize of '" .. srcFilename .."'!"
		writeLogfile(3, errorMsg .. "\n")
		return false, errorMsg
	end
	local timeout = math.floor(fileSize / 1250000)
	if timeout < 30 then timeout = 30 end

	local respBody, respHeaders
	-- TODO: MacOS code
	-- MacOS issue: LrHttp.post() doesn't seem to work with callback
	if not WIN_ENV then
		-- remember: LrFileUtils.readFile() can't handle huge files, e.g videos > 2GB, at least on Windows
 		-- respBody, respHeaders = LrHttp.post(h.serverUrl .. h.uploadPath, LrFileUtils.readFile(srcFilename), postHeaders, 'POST', timeout, fileSize)
	else
    	-- use callback function returning 10MB chunks to feed LrHttp.post() 
    	-- local postFile = io.open(srcFilename, "rb")
    	-- if not postFile then return false, "Cannot open " .. srcFilename ..' for reading' end
		local synoAPI = iif(h.userid ~= 0, 'SYNO.Foto.Upload.Item', 'SYNO.FotoTeam.Upload.Item')
		local contentTable =  {
			{
				name	= 'api',
				value	= synoAPI
			},
			{
				name	= 'method',
				value	= 'upload_to_folder'
			},
			{
				name	= 'version',
				value	= '1'
			},
			{
				name		= 'file',
				fileName	= dstFilename,
				filePath	= srcFilename,
				contentType	= mimeType,
--				value		= function () return postFile:read(10000000) end,
--				totalSize	= fileSize
			},
			{
				name	= 'duplicate',
				value	= '"ignore"',
--				value	= '"rename"'
			},
			{
				name	= 'name',
				value	= '"' .. dstFilename .. '"'
			},
			{
				name	= 'mtime',
				value	= srcDateTime
			},
			{
				name	= 'target_folder_id',
				value	= Photos.getFolderId(h, dstDir)
			},
			iif(thumbGenerate,
			{
				name		= 'thumb_xl',
				fileName	= 'thumb_xl',
				filePath	= thmb_XL_Filename,
				contentType	= 'image/jpeg',
			}, nil),
			iif(thumbGenerate,
			{
				name		= 'thumb_m',
				fileName	= 'thumb_m',
				filePath	= thmb_M_Filename,
				contentType	= 'image/jpeg',
			}, nil),
			iif(thumbGenerate,
			{
				name		= 'thumb_sm',
				fileName	= 'thumb_sm',
				filePath	= thmb_S_Filename,
				contentType	= 'image/jpeg',
			}, nil),
		}
		writeLogfile(4, string.format("uploadPictureFiles('%s', '%s', '%s'): calling LrHttp.postMultipart()\n", srcFilename, dstDir, dstFilename))
    	respBody, respHeaders = LrHttp.postMultipart(h.serverUrl .. h.psWebAPI .. h.apiInfo[synoAPI].path, contentTable, postHeaders, timeout, nil, false)
     	-- postFile:close()
	end

	return checkPSUploadAPIAnswer(string.format("Photos.uploadPictureFiles('%s', '%s', '%s')", srcFilename, dstDir, dstFilename),
									respHeaders, respBody)
end

---------------------------------------------------------------------------------------------------------
-- Photos.addPathToCache(h, path, id, type, addinfo)
--	add a folde to the pathIdCache
function Photos.addPathToCache(h, path, id, type, addinfo)
	writeLogfile(4, string.format("addPathToCache(user='%s', path='%s', id=%d)\n", h.userid, path, id))
	if not pathIdCache.cache[h.userid] then pathIdCache.cache[h.userid] = {} end
	local user_pathIdCache = pathIdCache.cache[h.userid]
	
	if not user_pathIdCache[path] then  user_pathIdCache[path] = {} end
	local entry = user_pathIdCache[path]

	entry.id 			= id
	entry.type 			= type
	if addinfo then
		entry.addinfo 	= addinfo
	end
	-- root folder has unlimited validity, all other use the cache-specific timeout
	entry.validUntil 	= iif(path == '/', 
								LrDate.timeFromComponents(2050, 12, 31, 23, 59, 50, 'local'), 
								LrDate.currentTime() + pathIdCache.timeout)
	-- entry.parentId = parentId
end

---------------------------------------------------------------------------------------------------------
-- Photos.getFolderId(h, folderPath, doCreate)
--	returns the id of a given folderPath (w/o leading/trailing '/')
-- the folder is searched recursively in the pathIdCache until itself or one of its parents is found
-- if the folder is found return its id, 
-- else if folder is / (root) return not found
-- elseif parent is found (recursively) in cache, 
-- 			call the cache's folder listFunction to get all its childs into the cache
--	 		if the requested folder is one of its childs, 
--			then return its id
-- 			elseif doCreate is set then createFolder, add to cache and return its id
--      	else return nil (not found)
--	else recurse one level

function Photos.getFolderId(h, path, doCreate)
	writeLogfile(5, string.format("getFolderId(userid:%s, path:'%s') ...\n", h.userid, path))
	pathIdCacheCleanup(h.userid)

	if string.sub(path, 1, 1) ~= "/" then path = "/" .. path end

	local cachedPathInfo  = pathIdCache.cache[h.userid] and pathIdCache.cache[h.userid][path]
	if cachedPathInfo then
		writeLogfile(4, string.format("getFolderId(userid:%s, path:'%s') returns %d\n", h.userid, path, cachedPathInfo.id))
		return cachedPathInfo.id
	elseif path == '/' then
		-- pathIdCache for this user not yet initialized
		writeLogfile(4, string.format("getFolderId(userid:%s, path:'%s') returns <nil>\n", h.userid, path))
		return nil
	else
		local folderParent = LrPathUtils.parent(path)
		local id

		writeLogfile(5, string.format("getFolderId(userid:%s, path:'%s') descending to '%s'\n", h.userid, path, folderParent))
		local folderParentId =  Photos.getFolderId(h, folderParent, doCreate)
		if not folderParentId then return nil end
	
		local subfolderList = pathIdCache.listFunction["folder"](h, folderParent, folderParentId)
		if not subfolderList then return nil end
		writeLogfile(5, string.format("getFolderId(userid:%s, path:'%s') found %d subfolders in '%s'\n", h.userid, path, #subfolderList, folderParent))
		for i = 1, #subfolderList do
			Photos.addPathToCache(h, subfolderList[i].name, subfolderList[i].id, "folder")
			if subfolderList[i].name == path then id = subfolderList[i].id end
		end
		
		local errorCode = 0
		if not id and doCreate then
			local folderLeaf = LrPathUtils.leafName(path)
			id, errorCode = Photos.createFolder(h, folderParent, folderLeaf)
			if id then
				Photos.addPathToCache(h, path, id, "folder")
			end
		end

		writeLogfile(4, string.format("getFolderId(userid:%s, path '%s') returns %s\n", h.userid, path, ifnil(id, '<nil>')))
		return id, errorCode
	end
end

---------------------------------------------------------------------------------------------------------
-- getPhotoId(h, path)
-- 	returns the id and additional info of a given item (photo/video) path (w/o leading/trailing '/') in Photos
function Photos.getPhotoId(h, path)
	writeLogfile(5, string.format("getPhotoId(userid:%s, path:'%s') ...\n", h.userid, path))
	pathIdCacheCleanup(h.userid)

	if string.sub(path, 1, 1) ~= "/" then path = "/" .. path end

	local cachedPathInfo  = pathIdCache.cache[h.userid] and pathIdCache.cache[h.userid][path]
	if cachedPathInfo then
		writeLogfile(4, string.format("getPhotoId(userid:%s, path:'%s') returns %d\n", h.userid, path, cachedPathInfo.id))
		return cachedPathInfo.id, cachedPathInfo.addinfo
	end

	local photoFolder 	= LrPathUtils.parent(path)
	local photoFilename = LrPathUtils.leafName(path)
	local folderId, errorCode = Photos.getFolderId(h, photoFolder, false)

	if not folderId then return nil, errorCode end

	local id, photoInfo
	local itemList, errorCode = pathIdCache.listFunction["item"](h, photoFolder, folderId)
	if not itemList then return nil, errorCode end

	writeLogfile(4, string.format("getPhotoId(userid:%s, path:'%s') listFunction found %d items in '%s'\n", h.userid, path, #itemList, photoFolder))
	for i = 1, #itemList do
		Photos.addPathToCache(h, LrPathUtils.child(photoFolder, itemList[i].filename), itemList[i].id, itemList[i].type, itemList[i])
		if itemList[i].filename == photoFilename then
			id = itemList[i].id
			photoInfo = itemList[i]
		end
	end

	writeLogfile(4, string.format("getPhotoId(%s) returns %s\n", path, id))

	return id, photoInfo
end

---------------------------------------------------------------------------------------------------------
-- getTagId(h, type, name) 
function Photos.getTagId(h, type, name)
	writeLogfile(4, string.format("getTagId(%s, %s)...\n", type, name))
	local tagsOfType = tagMapping[type]

	if #tagsOfType == 0 and not tagMappingUpdate(h, type) then
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
-- getFolderUrl(h, folderPath)
--	returns the URL of an folder in Photos
--	URL of a photo in Photos is:
--		http(s)://<PS-Server>/?launchApp=SYNO.Foto.AppInstance#/shared_space/folder/<folderId>
--    or:
--		http(s)://<PS-Server>/?launchApp=SYNO.Foto.AppInstance#/personal_space/folder/<folderId>
function Photos.getAlbumUrl(h, folderPath)
	local folderUrl = h.serverUrl .. "/?launchApp=SYNO.Foto.AppInstance#/" ..
					 iif(h.userid == 0, "shared", "personal") .. "_space/folder/" ..
					 h:getFolderId(normalizeDirname(folderPath))

	 writeLogfile(3, string.format("getAlbumUrl(server='%s', userid='%s', path='%s') returns %s\n", h.serverUrl, h.userid, folderPath, folderUrl))

	return folderUrl
end

---------------------------------------------------------------------------------------------------------
-- getPhotoUrl(h, photoPath, isVideo)
--	returns the URL of a photo/video in Photos
--	URL of a photo in Photos is:
--		http(s)://<PS-Server>/?launchApp=SYNO.Foto.AppInstance#/shared_space/folder/<folderId>/item_<photoId>
--    or:
--		http(s)://<PS-Server>/?launchApp=SYNO.Foto.AppInstance#/personal_space/folder/<folderId>/item_<photoId>
function Photos.getPhotoUrl(h, photoPath, isVideo)
	local photoUrl = h.serverUrl .. "/?launchApp=SYNO.Foto.AppInstance#/" ..
					 iif(h.userid == 0, "shared", "personal") .. "_space/folder/" ..
					 h:getFolderId(normalizeDirname(LrPathUtils.parent(photoPath))) .. "/item_" .. h:getPhotoId(photoPath, isVideo)

	writeLogfile(3, string.format("getPhotoUrl(server='%s', userid='%s', path='%s') returns %s\n", h.serverUrl, h.userid, photoPath, photoUrl))

	return photoUrl
end

-- function createTree(h, srcDir, srcRoot, dstRoot, dirsCreated) 
-- 	derive destination folder: dstDir = dstRoot + (srcRoot - srcDir), 
--	create each folder recursively if not already created
-- 	store created directories in dirsCreated
-- 	return created dstDir or nil on error
function Photos.createTree(h, srcDir, srcRoot, dstRoot, dirsCreated) 
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
	local dstDir = normalizeDirname(dstRoot .."/" .. dstDirRel)

	writeLogfile(4,"  createTree: dstDir is: " .. dstDir .. "\n")
	local folderId, errorCode = Photos.getFolderId(h, dstDir, true)

	if folderId then
		return dstDir
	end
	
	return nil, errorCode
end

---------------------------------------------------------------------------------------------------------
-- uploadPhotoFiles
-- upload photo plus its thumbnails (if configured)
function Photos.uploadPhotoFiles(h, dstDir, dstFilename, dstFileTimestamp, thumbGenerate, photo_Filename, title_Filename, thmb_XL_Filename, thmb_L_Filename, thmb_B_Filename, thmb_M_Filename, thmb_S_Filename)
	return
		-- HACK: Synology Photos will not overwrite photos w/ changed metadata, but will duplicate the photo, so we have to delete it ourself
			Photos.deletePhoto(h, dstDir .. "/" .. dstFilename, false)
		and Photos.uploadPictureFiles(h, dstDir, dstFilename, dstFileTimestamp, 'image/jpeg', photo_Filename, thumbGenerate, thmb_XL_Filename, thmb_M_Filename, thmb_S_Filename)
		and	pathIdCacheCleanup(h.userid, dstDir .. "/" .. dstFilename)
end

---------------------------------------------------------------------------------------------------------
-- uploadVideoFiles
-- upload video plus its thumbnails (if configured) and add. videos)
-- exportParams.psutils.uploadVideoFiles(exportParams.uHandle, dstDir, dstFilename, dstFileTimestamp, exportParams.thumbGenerate, 
--			vid_Orig_Filename, title_Filename, thmb_XL_Filename, thmb_L_Filename, thmb_B_Filename, thmb_M_Filename, thmb_S_Filename,
--			vid_Add_Filename, vid_Replace_Filename, convParams, convKeyOrig, convKeyAdd, addOrigAsMp4)
function Photos.uploadVideoFiles(h, dstDir, dstFilename, dstFileTimestamp, thumbGenerate, video_Filename, title_Filename, 
										thmb_XL_Filename, thmb_L_Filename, thmb_B_Filename, thmb_M_Filename, thmb_S_Filename,
										vid_Add_Filename, vid_Replace_Filename, convParams, convKeyOrig, convKeyAdd, addOrigAsMp4)
	return
		-- HACK: Synology Photo will not overwrite photos w/ changed metadata, but will duplicate the photo, so we have to delete it ourself
			Photos.deletePhoto(h, dstDir .. "/" .. dstFilename, false)
		and	Photos.uploadPictureFiles(h, dstDir, dstFilename, dstFileTimestamp, 'video/mp4', video_Filename, thumbGenerate, thmb_XL_Filename, thmb_M_Filename, thmb_S_Filename)
		and	pathIdCacheCleanup(h.userid, dstDir .. "/" .. dstFilename)

end

---------------------------------------------------------------------------------------------------------
-- getPhotoInfoFromList(h, folderType, folderPath, photoPath, useCache)
-- return photo infos for a photo in a given folder list (folder, shared album or public shared album)
-- returns:
-- 		photoInfos				if remote photo was found
-- 		nil,					if remote photo was not found
-- 		nil,		errorCode	on error
--getPhotoInfoFromList('album', normalizeDirname(LrPathUtils.parent(photoPath)), photoPath, useCache)
function Photos.getPhotoInfoFromList(h, folderType, folderPath, photoPath, useCache)
	if not useCache then pathIdCacheCleanup(h.userid, photoPath) end

	local photoId, addinfo = Photos.getPhotoId(h, photoPath)
	if not photoId then
		writeLogfile(3, string.format("getPhotoInfoFromList('%s', '%s', '%s', useCache %s) found no infos.\n", folderType, folderPath, photoPath, useCache))
		return nil, addinfo
	end

	return addinfo
end
--[[
---------------------------------------------------------------------------------------------------------
-- Photos.getSharedAlbumInfo(h, sharedAlbumName, useCache)
-- 	returns the shared folder info  of a given SharedAlbum 
function Photos.getSharedAlbumInfo(h, sharedAlbumName, useCache)
	if not useCache then sharedAlbumsCacheUpdate(h) end
	return sharedAlbumsCacheFind(h, sharedAlbumName)
end

---------------------------------------------------------------------------------------------------------
-- Photos.getSharedAlbumId(h, sharedAlbumName)
-- 	returns the shared Album Id of a given SharedAlbum using the Shared Album cache
function Photos.getSharedAlbumId(h, sharedAlbumName)
	local sharedAlbumInfo = sharedAlbumsCacheFind(h, sharedAlbumName)
	
	if not sharedAlbumInfo then 
		writeLogfile(3, string.format('getSharedAlbumId(%s): Shared Album not found.\n', sharedAlbumName))
		return nil
	end

	return sharedAlbumInfo.id
end

---------------------------------------------------------------------------------------------------------
-- Photos.isSharedAlbumPublic(h, sharedAlbumName)
--  returns the public flage of a given SharedAlbum using the Shared Album cache
function Photos.isSharedAlbumPublic(h, sharedAlbumName)
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
-- Photos.getSharedAlbumShareId(h, sharedAlbumName)
-- 	returns the shareId of a given SharedAlbum using the Shared Album cache
function Photos.getSharedAlbumShareId(h, sharedAlbumName)
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
function Photos.getSharedPhotoPublicUrl(h, albumName, photoName, isVideo)
	local photoInfos, errorCode = Photos.getPhotoInfoFromList(h, 'sharedAlbum', albumName, photoName, isVideo, true)

	if not photoInfos then return nil, errorCode end 

	return photoInfos.public_share_url
end

---------------------------------------------------------------------------------------------------------
-- getPublicSharedPhotoColorLabel (h, albumName, photoName, isVideo) 
-- returns the color label of a pbulic shared photo
function Photos.getPublicSharedPhotoColorLabel(h, albumName, photoName, isVideo)
	local photoInfos, errorCode = Photos.getPhotoInfoFromList(h, 'publicSharedAlbum', albumName, photoName, isVideo, true)

	if not photoInfos then return nil, errorCode end 

	return photoInfos.info.color_label
end
]]


---------------------------------------------------------------------------------------------------------
-- createAndAddPhotoTag (h, dstFilename, type, name, addinfo) 
-- create and add a new tag (desc,people,geo) to a photo
function Photos.createAndAddPhotoTag(h, dstFilename, type, name, addinfo)
	local tagId = Photos.getTagId(h, type, name)
	if not tagId then 
		tagId = Photos.createTag(h, type, name)
		tagMappingUpdate(h, type)
	end
	
	if not tagId then return false end
	
	local photoTagIds, errorCode = Photos.addPhotoTag(h, dstFilename, type, tagId, addinfo)
	
	if not photoTagIds and errorCode == 467 then
		-- tag was deleted, cache wasn't up to date
		tagId = Photos.createTag(h, type, name)
		tagMappingUpdate(h, type)
	 	photoTagIds, errorCode = Photos.addPhotoTag(h, dstFilename, type, tagId, addinfo)
	end 
	
	-- errorCode 468: duplicate tag (tag already there)
	if not photoTagIds and errorCode ~= 468 then return false end
	
	writeLogfile(3, string.format("createAndAddPhotoTag('%s', '%s', '%s') returns OK.\n", dstFilename, type, name))
	return true	
end

--[[
Photos.colorMapping = {
	[1] = 'red',
	[2] = 'yellow',
	[3] = 'green',
	[4] = 'none',
	[5] = 'blue',
	[6] = 'purple'
}

---------------------------------------------------------------------------------------------------------
-- createSharedAlbumAdvanced(h, sharedAlbumParams, useExisting) 
-- create a Shared Album and add a list of photos to it
-- returns success and share-link (if public)
function Photos.createSharedAlbumAdvanced(h, sharedAlbumParams, useExisting)
	local sharedAlbumInfo = Photos.getSharedAlbumInfo(h, sharedAlbumParams.sharedAlbumName, false)
	local isNewSharedAlbum
	local sharedAlbumAttributes = {}
	
	if sharedAlbumInfo and not useExisting then
		writeLogfile(3, string.format('createSharedAlbumAdvanced(%s, useExisting %s): returns error: Album already exists!\n', 
									sharedAlbumParams.sharedAlbumName, tostring(useExisting)))
		return nil, 414
	end
	
	if not sharedAlbumInfo then 
		local sharedAlbumId, errorCode = Photos.createSharedAlbum(h, sharedAlbumParams.sharedAlbumName)
		
		if not sharedAlbumId then return nil, errorCode end
		
		sharedAlbumInfo = Photos.getSharedAlbumInfo(h, sharedAlbumParams.sharedAlbumName, false)
		if not sharedAlbumInfo then return nil, 555 end
	
		isNewSharedAlbum = true
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

	writeTableLogfile(3, "Photos.createSharedAlbumAdvanced: sharedAlbumParams", sharedAlbumParams, true, '^password')
	local shareResult, errorCode = Photos.editSharedAlbum(h, sharedAlbumParams.sharedAlbumName, sharedAlbumAttributes) 

	if not shareResult then return nil, errorCode end
	
	return shareResult
end
---------------------------------------------------------------------------------------------------------
-- createAndAddPhotosToSharedAlbum(h, sharedAlbumParams, photos) 
-- create a Shared Album and add a list of photos to it
-- returns success and share-link (if public)
function Photos.createAndAddPhotosToSharedAlbum(h, sharedAlbumParams, photos)
	local shareResult = Photos.createSharedAlbumAdvanced(h, sharedAlbumParams, true)
	 
	if 		not shareResult 
		or	not Photos.addPhotosToSharedAlbum(h, sharedAlbumParams.sharedAlbumName, photos) 
	then 
		return false 
	end
	
	writeLogfile(3, string.format('createAndAddPhotosToSharedAlbum(%s, %s, %s, pw: %s, %d photos) returns OK.\n', 
			sharedAlbumParams.sharedAlbumName, iif(sharedAlbumParams.isAdvanced, 'advanced', 'old'), 
			iif(sharedAlbumParams.isPublic, 'public', 'private'), iif(sharedAlbumParams.sharedAlbumPassword, 'w/ passwd', 'w/o passwd'), 
			#photos))
	return true, shareResult
end

---------------------------------------------------------------------------------------------------------
-- removePhotosFromSharedAlbum(h, sharedAlbumName, photos) 
-- remove a list of photos from a Shared Album
-- ignore error if Shared Album doesn't exist
function Photos.removePhotosFromSharedAlbum(h, sharedAlbumName, photos)
	local sharedAlbumInfo = sharedAlbumsCacheFind(h, sharedAlbumName)
	
	if not sharedAlbumInfo then 
		writeLogfile(3, string.format('removePhotosFromSharedAlbum(%s, %d photos): Shared album not found, returning OK.\n', sharedAlbumName, #photos))
		return true
	end
	
	local success, errorCode = Photos.removePhotosFromSharedAlbum(h, sharedAlbumName, photos)
	
	if not success and errorCode == 555 then
		-- shared album was deleted, mapping wasn't up to date
		sharedAlbumsCacheUpdate(h)
		writeLogfile(3, string.format('removePhotosFromSharedAlbum(%s, %d photos): Shared album already deleted, returning OK.\n', sharedAlbumName, #photos))
		return true
	end 
	
	if not success then return false end 
	
	return true	
end

]]

-- #####################################################################################################
-- ########################## Photo object #############################################################
-- #####################################################################################################

PhotosPhoto = {}
PhotosPhoto_mt = { __index = PhotosPhoto }

function PhotosPhoto.new(photoServer, photoPath, isVideo, infoTypeList, useCache)
	local photoInfo

	writeLogfile(3, string.format("PhotosPhoto:new(%s, %s, %s, %s) starting\n", photoPath, isVideo, infoTypeList, useCache))

	if not photoServer  then
		-- called from PhotoStation.new()
		return setmetatable({}, PhotosPhoto_mt)
	end

	if string.find(infoTypeList, 'photo') then
		local photoInfoFromList, errorCode = photoServer:getPhotoInfoFromList('album', normalizeDirname(LrPathUtils.parent(photoPath)), photoPath, useCache)
		if photoInfoFromList then
			photoInfo = tableDeepCopy(photoInfoFromList)
		else
			writeLogfile(3, string.format("PhotosPhoto:new(): getPhotoInfoFromList() returns nil\n"))
			return nil, errorCode
		end
	else
		photoInfo = {}
	end

	photoInfo.photoPath = photoPath

	writeLogfile(3, string.format("PhotosPhoto:new(): returns photoInfo %s\n", JSON:encode(photoInfo)))
	
	photoInfo.photoServer 	= photoServer

	return setmetatable(photoInfo, PhotosPhoto_mt)
end

function PhotosPhoto:getDescription()
	return self.additional and self.additional.description
end

function PhotosPhoto:getGPS()
	local gps = { latitude = 0, longitude = 0, type = 'blue' }

	-- gps coords from photo/video: best choice for GPS
	if self.additional and self.additional.gps then
			gps.latitude	= tonumber(self.additional.gps.latitude)
			gps.longitude	= tonumber(self.additional.gps.longitude)
			gps.type		= 'red'
	end

	return gps
end

function PhotosPhoto:getId()
	return self.id
end

function PhotosPhoto:getRating()
	return nil
end

function PhotosPhoto:getTags()
	local tagList
	if self.additional and self.additional.tag then
		tagList = {}
		for i = 1, #self.additional.tag do
			tag = {}
			tag.id 	 	= self.additional.tag[i].id
			tag.name 	= self.additional.tag[i].name
			tag.type 	= self.additional.tag[i].type or 'desc'
			tagList[i]	= tag
		end
	end
	return tagList
end

function PhotosPhoto:getTitle()
	return ''
end

function PhotosPhoto:getType()
	return self.type
end

function PhotosPhoto:setDescription(description)
	if not self.changes then self.changes = {} end
	if not self.changes.metadata then self.changes.metadata = {} end

	self.changes.metadata.description = description
	return true
end

function PhotosPhoto:setGPS(gps)
--[[
	if not self.changes then self.changes = {} end
	if not self.changes.metadata then self.changes.metadata = {} end

	self.changes.metadata.gps_lat =  gps.latitude
	self.changes.metadata.gps_lng =  gps.longitude
]]
	return true
end

function PhotosPhoto:setRating(rating)
--[[
	if not self.changes then self.changes = {} end
	if not self.changes.metadata then self.changes.metadata = {} end

	self.changes.metadata.rating = rating
]]
return true
end

function PhotosPhoto:setTitle(title)
--[[
	if not self.changes then self.changes = {} end
	if not self.changes.metadata then self.changes.metadata = {} end

	self.changes.metadata.title = title
]]
	return true
end

function PhotosPhoto:addTags(tags, type)
	if not self.changes then self.changes = {} end
	if not self.changes.tags_add then self.changes.tags_add = {} end

	if not tags then return true end

	for i = 1, #tags do
		tags[i].type = type
		table.insert(self.changes.tags_add, tags[i])
	end

	return true
end

function PhotosPhoto:removeTags(tags, type)
	if not self.changes then self.changes = {} end
	if not self.changes.tags_remove then self.changes.tags_remove = {} end

	if not tags then return true end

	for i = 1, #tags do
		tags[i].type = type
		table.insert(self.changes.tags_remove, tags[i])
	end

	return true
end

function PhotosPhoto:showUpdates()
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

function PhotosPhoto:updateMetadata()
	local metadataChanges = self.changes and self.changes.metadata
	local photoParams = {}

	if not metadataChanges then return true end

	for key, value in pairs(metadataChanges) do
		table.insert(photoParams, { attribute =  key, value = value })
	end

	if #metadataChanges > 0 then
		pathIdCacheCleanup(self.photoServer.userid, self.photoPath)
	end

	return self.photoServer:editPhoto(self.photoPath, photoParams)
end

function PhotosPhoto:updateTags()
	local tagsAdd 		= self.changes and self.changes.tags_add
	local tagsRemove 	= self.changes and self.changes.tags_remove

	writeTableLogfile(4,"updateTags[add]", tagsAdd, true)
	writeTableLogfile(4,"updateTags[remove]", tagsRemove, true)

	for i = 1, #tagsAdd do
		if 	(tagsAdd[i].type == 'people' and not self.photoServer:createAndAddPhotoTag(self.photoPath, tagsAdd[i].type, tagsAdd[i].name, tagsAdd[i])) or
			(tagsAdd[i].type ~= 'people' and not self.photoServer:createAndAddPhotoTag(self.photoPath, tagsAdd[i].type, tagsAdd[i].name))
		then
			return false
		end
	end
	writeLogfile(3, string.format("updateTags-Add('%s', %d tags) returns OK.\n", self.photoPath, #tagsAdd))

	for i = 1, #tagsRemove do
		if not self.photoServer:removePhotoTag(self.photoPath, tagsRemove[i].type, tagsRemove[i].id) then
			return false
		end
	end

	writeLogfile(3, string.format("updateTags-Remove('%s', %d tags) returns OK.\n", self.photoPath, #tagsRemove))
	if #tagsAdd > 0 or #tagsRemove > 0 then
		pathIdCacheCleanup(self.photoServer.userid, self.photoPath)
	end
	return true
end
