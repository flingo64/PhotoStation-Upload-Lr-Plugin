--[[----------------------------------------------------------------------------

PSPhotosAPI.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2015-2022, Martin Messmer

Photos object:
	- new
	- login
	- logout

	- getFolderId
	- getAlbumUrl
	- getPhotoId
	- getPhotoUrl
	- getPhotoInfoFromList

	- supports
	- validateServername
	- basedir
	- getErrorMsg

	- createTree
	- deleteEmptyAlbumAndParents

	- uploadPhotoFiles
	- uploadVideoFiles

	- editPhoto
	- movePhoto
	- deletePhoto

	- getPhotoTags

	- removePhotoTag
	- createAndAddPhotoTag

Photos Photo object:
	- new
	- getXxx
	- setXxx
	- addTags
	- removeTags
	- showUpdates
	- updateMetadata
	- updateTags

Local functions:
	- Photos_xxx		functions using the Photos API
	- pathIdCacheXxx	pathIdCache functions
	- tagIdCachaXxx		tagIdCache functions

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
local LrFileUtils 	= import 'LrFileUtils'
local LrPathUtils 	= import 'LrPathUtils'
local LrHttp 		= import 'LrHttp'
local LrDate 		= import 'LrDate'
local LrTasks		= import 'LrTasks'

-- #####################################################################################################
-- ########################## PhotoStation object ######################################################
-- #####################################################################################################

Photos = {}
Photos_mt = { __index = Photos }

--====== local vars and functions ============================================--

local PSAPIerrorMsgs = {
	[0]		= 'No error',
	-- plugin error codes
	[1]	  = 'error_folder_not_exist',

	-- Common SYNO API error codes
	[100] = 'Unknown error',
    [101] = 'No parameter of API, method or version',		-- PS 6.6: no such directory
    [102] = 'The requested API does not exist',
    [103] = 'The requested method does not exist',
    [104] = 'The requested version does not support the functionality',
    [105] = 'The logged in session does not have permission',
    [106] = 'Session timeout',
    [107] = 'Session interrupted by duplicate login',
	[108] = 'Failed to upload the file',
	[109] = 'The network connection is unstable or the system is busy',
	[110] = 'The network connection is unstable or the system is busy',
	[111] = 'The network connection is unstable or the system is busy',
	[112] = 'Preserve for other purpose',
	[113] = 'Preserve for other purpose',
	[114] = 'Lost parameters for this API',
	[115] = 'Not allowed to upload a file',
	[116] = 'Not allowed to perform for a demo site',
	[117] = 'The network connection is unstable or the system is busy',
	[118] = 'The network connection is unstable or the system is busy',
	[119] = 'Invalid session',
	[150] = 'Request source IP does not match the login IP',

    -- SYNO.API.Auth
	[400] = 'No such account or incorrect password',
	[401] = 'Disabled account',
	[402] = 'Denied permission',
	[403] = '2-factor authentication code required',
	[404] = 'Failed to authenticate 2-factor authentication code',
	[406] = 'Enforce to authenticate with 2-factor authentication code',
	[407] = 'Blocked IP source',
	[408] = 'Expired password cannot change',
	[409] = 'Expired password',
	[410] = 'Password must be changed',
	[411] = 'Account is locked',
--[[
    -- SYNO.PhotoStation.Album (416-425)
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
	-- Photos API error codes
	[620]	= 'File format not supported',
	[641]	= 'File exists',

    -- Lr HTTP errors
	[1001]  = 'Http error: no response body, no response header',
	[1002]  = 'Http error: no response data, no errorcode in response header',
	[1003]  = 'Http error: No JSON response data',
	[12007] = 'Http error: cannotFindHost',
	[12029] = 'Http error: cannotConnectToHost: check TLS/SSL settings on Diskstation - "Intermediate compatibility" is recommended',
	[12038] = 'Http error: serverCertificateHasUnknownRoot',
}

-- #####################################################################################################
-- ########################################## Synology Photos API primitives ###########################
-- #####################################################################################################

--[[
Photos_API (h, apiParams)
	calls the named synoAPI with the respective parameters in formData
	returns nil, on http error
	returns the decoded JSON response as table on success
]]
local function Photos_API (h, apiParams)
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

	writeLogfile(4, string.format("Photos_API: LrHttp.post(url='%s%s%s', API=%s params='%s')\n",
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

	local respArray = JSON:decode(respBody, "Photos_API(" .. synoAPI .. ")")

	if not respArray then return nil, 1003 end

	if respArray.error then
		local errorCode = tonumber(respArray.error.code)
		writeLogfile(3, string.format('Photos_API: %s returns error %d (%s)\n', synoAPI, errorCode, Photos.getErrorMsg(errorCode)))
		return nil, errorCode
	end

	return respArray
end

-- #####################################################################################################
-- ########################## list folder elements  ####################################################
-- #####################################################################################################

---------------------------------------------------------------------------------------------------------
-- Photos_getPersonalRootFolderId(h)
-- get folder id of personal root folder
local function Photos_getPersonalRootFolderId (h)
	local apiParams = {
		id			= 0,
	-- 	additional	= ["access_permission"],
		api			= "SYNO.Foto.Browse.Folder",
		method		= "get",
		version		= 1
	}

	local respArray, errorCode = Photos_API(h, apiParams)
	if not respArray then return false, errorCode end

	return respArray.data.folder.id
end

---------------------------------------------------------------------------------------------------------
-- Photos_listAlbumSubfolders: returns all subfolders in a given folder
-- returns
--		subfolderList:	table of subfolder infos, if success, otherwise nil
--		errorcode:		errorcode, if not success
local function Photos_listAlbumSubfolders(h, folderPath, folderId)
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
	local respArray, errorCode = Photos_API(h, apiParams)

	if not respArray then return nil, errorCode end

	writeTableLogfile(3, string.format("Photos_listAlbumSubfolders('%s') returns %d items\n", folderPath, #respArray.data.list))
	return respArray.data.list
end

---------------------------------------------------------------------------------------------------------
-- Photos_listAlbumItems: returns all items (photos/videos) in a given folder
-- returns
--		itemList:		table of item infos, if success, otherwise nil
--		errorcode:		errorcode, if not success
local function Photos_listAlbumItems(h, folderPath, folderId)
	local realFolderId = folderId or Photos.getFolderId(h, folderPath)
	if not realFolderId	then
		writeTableLogfile(1, string.format("Photos_listAlbumItems('%s') could not get folderId, returns <nil>\n", folderPath))
		return nil, 1
	end
	local apiParams = {
			folder_id		= realFolderId,
			additional		= iif(h.serverVersion == 70,
-- 								'["description","tag","exif","resolution","orientation","gps","video_meta","video_convert","thumbnail","address","geocoding_id","rating","person"]',
								'["description","tag","gps","video_meta","address","person"]',
								'["description","tag","gps","video_meta","address","rating","person"]'),
			sort_by			= "takentime",
			sort_direction	= "asc",
			offset			= 0,
			limit			= 5000,
			api				= "SYNO.FotoTeam.Browse.Item",
			method			= "list",
			version			= iif(h.serverVersion == 70, 1, 2)
	}

	local respArray, errorCode = Photos_API(h, apiParams)

	if not respArray then return nil, errorCode end

	-- no need to set the lastScan timestamp for the folder's cacheIdPath entry here,
	-- because Photos_listAlbumSubfolders() will also be called before

	writeTableLogfile(3, string.format("Photos_listAlbumItems('%s', '%s') returns %d items\n", folderPath, ifnil(folderId, '<nil>'), #respArray.data.list))
	return respArray.data.list
end

-- #####################################################################################################
-- ###################################### pathIdCache ##################################################
-- #####################################################################################################
-- The path id cache holds ids of folders and items (photo/video) as used by the PhotosAPI.
-- Items are case-insensitive in Photos, so we store and comparethem lowercase
-- to have a unique representation and to find any lowercase/uppercase variation of an item name
-- layout:
--		pathIdCache
--			cache[userid] (0 for Team Folders)
--					[itemPath] = 	{ id, type, validUntil, addinfo } or
--					[folderPath] =	{ id, type, validUntil, lastSubfolderScanValidUntil, lastItemScanValidUntil }
--			lastCleanup[userid]
local pathIdCache = {
	cache 			= {},
	lastCleanup		= {},
	timeout			= 300,
	listFunction	= {
		folder		= Photos_listAlbumSubfolders,
		item		= Photos_listAlbumItems
	},
}

---------------------------------------------------------------------------------------------------------
-- pathIdCachePathname: normalize pathnames for the cache:
--		- make sure a path starts with a '/'
-- 		- items (files) are case-insensitive in Photos, so we store them in lowercase
local function pathIdCachePathname(path, type)
	local cachePath
	if path and string.sub(path, 1, 1) ~= "/" then
		cachePath = "/" .. path
	else
		cachePath = path
	end

	if type == 'item' then
		local folderPath = ifnil(LrPathUtils.parent(cachePath), '/')
		local filename = string.lower(LrPathUtils.leafName(cachePath))
		cachePath = LrPathUtils.child(folderPath, filename)
	end
	return cachePath
end
---------------------------------------------------------------------------------------------------------
-- pathIdCacheInitialize: remove all entries from cache
local function pathIdCacheInitialize(userid)
	writeLogfile(3, string.format("pathIdCacheInitialize(user='%s')\n", userid))
	pathIdCache.cache[userid] = {}
	pathIdCache.lastCleanup[userid] = LrDate.timeFromComponents(2000, 1, 1, 0, 0, 0, 'local')
	return true
end

---------------------------------------------------------------------------------------------------------
-- pathIdCacheCleanup: remove old entries from id cache
local function pathIdCacheCleanup(userid)
--	writeLogfile(5, string.format("pathIdCacheCleanup(user='%s')\n", userid))
	local user_pathIdCache = pathIdCache.cache[userid]

	if not user_pathIdCache then return true end

	-- no need to cleanup last cleanup was just now
	if pathIdCache.lastCleanup[userid] == LrDate.currentTime() then return true end

	for key, entry in pairs(user_pathIdCache) do
		if (entry.validUntil < LrDate.currentTime()) then
			writeLogfile(3, string.format("pathIdCacheCleanup(user:%s); removing path '%s'\n", userid, key))
			user_pathIdCache[key] = nil
		end
	end

	pathIdCache.lastCleanup[userid] = LrDate.currentTime()
	return true
end

---------------------------------------------------------------------------------------------------------
-- pathIdCacheInvalidateFolder(userid, path, type)
--	age out a folder's scan result for the given subelement type ('item' or 'folder')
local function pathIdCacheInvalidateFolder(userid, path, type)
	writeLogfile(3, string.format("pathIdCacheInvalidateFolder(user='%s', path='%s', '%s')\n", userid, path, type))
	if path and string.sub(path, 1, 1) ~= "/" then path = "/" .. path end

	if pathIdCache.cache[userid] and pathIdCache.cache[userid][path] then
		if type == 'folder' then
			pathIdCache.cache[userid][path].lastSubfolderScanValidUntil = LrDate.currentTime() - 1
		else
			pathIdCache.cache[userid][path].lastItemScanValidUntil = LrDate.currentTime() - 1
		end
	end

	return true
end

---------------------------------------------------------------------------------------------------------
-- pathIdCacheAddEntry(userid, path, id, type, addinfo)
--	add a path to the pathIdCache
--  type is either 'folder' or 'item'
-- addinfo is only valid for items, it contains additional item info (metadata, tags, ...)
local function pathIdCacheAddEntry(userid, path, id, type, addinfo)
	writeLogfile(3, string.format("pathIdCacheAddEntry(user='%s', path='%s', '%s', id=%d)\n", userid, path, type, id))
	if not pathIdCache.cache[userid] then pathIdCache.cache[userid] = {} end
	local user_pathIdCache = pathIdCache.cache[userid]

	path = pathIdCachePathname(path, type)
	if not user_pathIdCache[path] then  user_pathIdCache[path] = {} end
	local entry = user_pathIdCache[path]

	entry.id 		= id
	entry.type 		= type
	entry.addinfo 	= addinfo

	-- root folder has unlimited validity, all other use the cache-specific timeout
	entry.validUntil 	= iif(path == '/',
								LrDate.timeFromComponents(2050, 12, 31, 23, 59, 50, 'local'),
								LrDate.currentTime() + pathIdCache.timeout)

	if path ~= '/' then
		-- set the lastScan timestamp for the parent folder's cacheIdPath entry
		local parentFolder = ifnil(LrPathUtils.parent(path), '/')
		if pathIdCache.cache[userid][parentFolder] then
			if type == 'folder' then
				pathIdCache.cache[userid][parentFolder].lastSubfolderScanValidUntil = LrDate.currentTime() + pathIdCache.timeout
			else
				pathIdCache.cache[userid][parentFolder].lastItemScanValidUntil = LrDate.currentTime() + pathIdCache.timeout
			end
		end
	end

	return true
end

---------------------------------------------------------------------------------------------------------
-- pathIdCacheDeleteEntry(userid, path)
--	delete a path from the pathIdCache: must be called whenever a remote folder or item was deleted
local function pathIdCacheDeleteEntry(userid, path, type)
	writeLogfile(3, string.format("pathIdCacheDeleteEntry(user='%s', path='%s', type='%s')\n", userid, path, type))

	path = pathIdCachePathname(path, type)

	if path ~= '/' and pathIdCache.cache[userid] and pathIdCache.cache[userid][path] then
		pathIdCache.cache[userid][path] = nil
	end

	return true
end

---------------------------------------------------------------------------------------------------------
-- pathIdCacheGetEntry(userid, path, type, wantsInfo)
--	get pathIdCache entry for the given user/path/type
--  if wantsInfo (only for items), then info element must be available, otherwise the id is sufficient
local function pathIdCacheGetEntry(userid, path, type, wantsInfo)
	pathIdCacheCleanup(userid)
	path 		= pathIdCachePathname(path, type)
	cacheEntry	= pathIdCache.cache[userid] and pathIdCache.cache[userid][path]

	-- if entry was not found then check whether it's really not there or just not yet cached
	if not cacheEntry then
		parentFolder = ifnil(LrPathUtils.parent(path), '/')
		if 		pathIdCache.cache[userid]
			and pathIdCache.cache[userid][parentFolder]
			and (
					(
							type == 'folder'
						and pathIdCache.cache[userid][parentFolder].lastSubfolderScanValidUntil
						and pathIdCache.cache[userid][parentFolder].lastSubfolderScanValidUntil > LrDate.currentTime()
				 	)
				 or
					(
							type == 'item'
						and pathIdCache.cache[userid][parentFolder].lastItemScanValidUntil
						and pathIdCache.cache[userid][parentFolder].lastItemScanValidUntil > LrDate.currentTime()
					)
				)
		then
			writeLogfile(4, string.format("pathIdCacheGetEntry(user='%s', path='%s', '%s') returns 'notFound'\n", userid, path, type))
			return nil, 'notFound'
		else
			writeLogfile(4, string.format("pathIdCacheGetEntry(user='%s', path='%s', '%s') returns 'notCached'\n", userid, path, type))
			return nil, 'notCached'
		end
	end

	if wantsInfo and not cacheEntry.addinfo then
		writeLogfile(4, string.format("pathIdCacheGetEntry(user='%s', path='%s'): required addinfo missing, returns 'notCached'\n", userid, path))
		return nil, 'notCached'
	end

	writeLogfile(4, string.format("pathIdCacheGetEntry(user='%s', path='%s') returns entry '%s'\n", userid, path, ifnil(cacheEntry and cacheEntry.id, '<nil>')))
	return cacheEntry
end

-- #####################################################################################################
-- ######################## Photo and Folder Id Mgmt / pathIdCache #####################################
-- #####################################################################################################
local Photos_createFolder

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
-- 			elseif doCreate is set then Photos_createFolder, add to cache and return its id
--      	else return nil (not found)
--	else recurse one level

function Photos.getFolderId(h, path, doCreate)
	writeLogfile(5, string.format("getFolderId(userid:%s, path:'%s') ...\n", h.userid, path))

	if string.sub(path, 1, 1) ~= "/" then path = "/" .. path end

	local cachedPathInfo, reason = pathIdCacheGetEntry(h.userid, path, 'folder')
	local folderId
	if cachedPathInfo then
		writeLogfile(3, string.format("getFolderId(userid:%s, path:'%s') returns '%d' from cache\n", h.userid, path, cachedPathInfo.id))
		return cachedPathInfo.id
	elseif reason == 'notFound' then
		writeLogfile(3, string.format("getFolderId(userid:%s, path:'%s') returns <nil>\n", h.userid, path))
	else
		-- path was not yet cached, or cache entry is outdated: see if we can find it on the server
		local parentFolder = LrPathUtils.parent(path)
		local parentFolderId =  Photos.getFolderId(h, parentFolder, doCreate)

		local subfolderList = pathIdCache.listFunction.folder(h, parentFolder, parentFolderId)
		if not subfolderList then
			writeLogfile(1, string.format("getFolderId(userid:%s, path:'%s') listFunction('%s') returned <nil>\n", h.userid, path, parentFolder))
			return nil
		end

		writeLogfile(3, string.format("getFolderId(userid:%s, path:'%s') listFunction found %d subfolders in '%s'\n", h.userid, path, #subfolderList, parentFolder))
		for i = 1, #subfolderList do
			pathIdCacheAddEntry(h.userid, subfolderList[i].name, subfolderList[i].id, "folder")
		end

		-- try it once more
		cachedPathInfo, reason = pathIdCacheGetEntry(h.userid, path, 'folder')
		if cachedPathInfo then folderId = cachedPathInfo.id	end
	end

	local errorCode = 0
	if not folderId and doCreate then
		local parentFolder = LrPathUtils.parent(path)
		local folderLeaf = LrPathUtils.leafName(path)
		folderId, errorCode = Photos_createFolder(h, parentFolder, folderLeaf)
		if folderId then
			pathIdCacheAddEntry(h.userid, path, folderId, "folder")
		end
	end

	writeLogfile(3, string.format("getFolderId(userid:%s, path '%s') returns '%s' (after cache update)\n", h.userid, path, ifnil(folderId, '<nil>')))
	return folderId, errorCode
end

---------------------------------------------------------------------------------------------------------
-- getPhotoId(h, path, wantsInfo)
-- 	returns the id and - if wantsInfo -additional info of a given item (photo/video) path (w/o leading/trailing '/') in Photos
function Photos.getPhotoId(h, path, wantsInfo)
	writeLogfile(5, string.format("getPhotoId(userid:%s, path:'%s') ...\n", h.userid, path))

	if string.sub(path, 1, 1) ~= "/" then path = "/" .. path end

	local cachedPathInfo, reason  = pathIdCacheGetEntry(h.userid, path, 'item', wantsInfo)
	if cachedPathInfo then
		writeLogfile(3, string.format("getPhotoId(userid:%s, path:'%s') returns id '%d' from cache\n", h.userid, path, cachedPathInfo.id))
		return cachedPathInfo.id, cachedPathInfo.addinfo
	elseif reason == 'notFound' then
		writeLogfile(3, string.format("getPhotoId(userid:%s, path:'%s') returns <nil>\n", h.userid, path))
		return nil
	end

	-- path was not yet cached, or cache entry is outdated: see if we can find it on the server
	local parentFolder	= LrPathUtils.parent(path)
	local folderId 		= Photos.getFolderId(h, parentFolder, false)

	local itemList, errorCode = pathIdCache.listFunction.item(h, parentFolder, folderId)
	if not itemList then
		writeLogfile(1, string.format("getPhotoId(userid:%s, path:'%s') listFunction('%s') returned <nil>\n", h.userid, path, parentFolder))
		return nil, errorCode
	end

	writeLogfile(3, string.format("getPhotoId(userid:%s, path:'%s') listFunction found %d items in '%s'\n", h.userid, path, #itemList, parentFolder))
	for i = 1, #itemList do
		pathIdCacheAddEntry(h.userid, LrPathUtils.child(parentFolder, itemList[i].filename), itemList[i].id, 'item', itemList[i])
	end

	-- try it once more
	cachedPathInfo, reason  = pathIdCacheGetEntry(h.userid, path, 'item', wantsInfo)
	if cachedPathInfo then
		writeLogfile(3, string.format("getPhotoId(userid:%s, path:'%s') returns id '%s' (after cache update)\n", h.userid, path, cachedPathInfo.id))
		return cachedPathInfo.id, cachedPathInfo.addinfo
	else
		writeLogfile(3, string.format("getPhotoId(userid:%s, path:'%s') returns <nil> (after cache update)\n", h.userid, path))
		return nil
	end
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
	if not useCache then pathIdCacheInvalidateFolder(h.userid, folderPath, 'item') end

	-- get photo id plus addinfo
	local photoId, addinfo = Photos.getPhotoId(h, photoPath, true)
	if not photoId then
		writeLogfile(3, string.format("getPhotoInfoFromList('%s', '%s', '%s', useCache %s) found no infos.\n", folderType, folderPath, photoPath, useCache))
		return nil, addinfo
	end

	return addinfo
end

---------------------------------------------------------------------------------------------------------
-- getFolderUrl(h, folderPath)
--	returns the URL of an folder in Photos
--	URL of a photo in Photos is:
--		http(s)://<psServer>[:<psPort>][/<aliasPath>]<basedir>/folder/<folderId>
function Photos.getAlbumUrl(h, folderPath)
	local folderId	= h:getFolderId(normalizeDirname(folderPath))

	if not folderId then
		writeLogfile(1, string.format("getAlbumUrl(server='%s', userid='%s', folderPath='%s'): folderId '%s' returns nil\n",
							h.serverUrl, h.userid, folderPath, ifnil(folderId, '<nil>')))
		return ''
	end

	local folderUrl = 	h.serverUrl ..
						Photos.basedir(h.serverUrl, iif(h.userid == 0, "shared", "personal"), h.userid) ..
						"folder/" .. folderId
	writeLogfile(3, string.format("getAlbumUrl(server='%s', userid='%s', path='%s') returns %s\n", h.serverUrl, h.userid, folderPath, folderUrl))

	return folderUrl
end

---------------------------------------------------------------------------------------------------------
-- getPhotoUrl(h, photoPath, isVideo)
--	returns the URL of a photo/video in Photos
--	URL of a photo in Photos is:
--		http(s)://<psServer>[:<psPort>][/<aliasPath>]<basedir>/folder/<folderId>/item_<photoId>
function Photos.getPhotoUrl(h, photoPath, isVideo)
	writeLogfile(3, string.format("getPhotoUrlgetPhotoUrl(server='%s', userid='%s', path='%s')",
				h.serverUrl, h.userid, photoPath))
	local folderId	= h:getFolderId(ifnil(normalizeDirname(LrPathUtils.parent(photoPath)),'/'))
	local itemId 	= h:getPhotoId(photoPath, isVideo)

	if not folderId or not itemId then
		writeLogfile(1, string.format("getPhotoUrl(server='%s', userid='%s', path='%s'): folderId '%s', itemId '%s' returns nil\n",
							h.serverUrl, h.userid, photoPath, ifnil(folderId, '<nil>'), ifnil(itemId, '<nil>')))
		return ''
	end

	local photoUrl = 	h.serverUrl ..
						Photos.basedir(h.serverUrl, iif(h.userid == 0, "shared", "personal"), h.userid) ..
						"folder/" .. folderId .. "/item_" .. itemId
	writeLogfile(3, string.format("getPhotoUrl(server='%s', userid='%s', path='%s') returns %s\n", h.serverUrl, h.userid, photoPath, photoUrl))

	return photoUrl
end

-- #####################################################################################################
-- ########################## session management #######################################################
-- #####################################################################################################

---------------------------------------------------------------------------------------------------------
-- supports(h, metadataType)
function Photos.supports (h, capabilityType)
	return PHOTOSERVER_API.supports (h.serverVersion, capabilityType)
end

---------------------------------------------------------------------------------------------------------
-- validateServername(view, servername)
-- a valid servername looks like
-- 		<name_or_ip>:<psPort> or
-- 		<name_or_ip>/<aliasPath>
function Photos.validateServername (view, servername)
	local colon			= string.match(servername, '[^:]+(:)')
	local port			= string.match(servername, '[^:]+:(%d+)$')
	local slash 		= string.match(servername, '[^/]+(/)')
	local aliasPath 	= string.match(servername, '[^/]+/([^%?]+)$')

	writeLogfile(5, string.format("Photos.validateServername('%s'): port '%s' aliasPath '%s'\n", servername, ifnil(port, '<nil>'), ifnil(aliasPath, '<nil>')))

	return	(	 colon and 	   port and not slash and not aliasPath)
		or	(not colon and not port and		slash and 	  aliasPath),
		servername
end

---------------------------------------------------------------------------------------------------------
-- basedir(serverUrl, area, owner)
-- returns the basedir for the API calls.
-- This depends on whether the API is called via standard (DSM) port (5000/5001)
-- or via an alias port or alias path as defined in Login Portal configuration
-- The basedir looks like:
--		<API_prefix>#/[shared|personal]_space/
-- 	  where <API_prefix> is:
--		'/?launchApp=SYNO.Foto.AppInstance' - if <psPort> is a standard port (5000, 5001) or
--		'/'									- if <psPort> is a non-standard/alternative port configured in 'Login Portal'
--		'/'									- if <psPort> is not given and an aliasPath is given as configured in 'Login Portal'
function Photos.basedir (serverUrl, area, owner)
	local port		= string.match(serverUrl, 'http[s]*://[^:]+:(%d+)$')
	local aliasPath = string.match(serverUrl, 'http[s]*://[^/]+(/[^%?]+)$')

	return	iif(port and (port == '5000' or port == '5001'), "/?launchApp=SYNO.Foto.AppInstance#", "/#") ..
			iif(area == 'personal', "/personal_space/", "/shared_space/")
end

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

---------------------------------------------------------------------------------------------------------
-- Photos.new: initialize a Photos API object
function Photos.new(serverUrl, usePersonalPS, personalPSOwner, serverTimeout, version)
	local h = {} -- the handle
	local apiInfo = {}

	writeLogfile(4, string.format("Photos.new(url=%s, personal=%s, persUser=%s, timeout=%d)\n", serverUrl, usePersonalPS, personalPSOwner, serverTimeout))

	h.serverUrl 	= serverUrl
	h.serverTimeout = serverTimeout
	h.serverVersion	= version

	if usePersonalPS then
		h.userid 		= personalPSOwner
	else
		h.userid		= 0
	end
	pathIdCacheInitialize(h.userid)

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
		query	= 'SYNO.API.,SYNO.Foto.,SYNO.FotoTeam.',
		api		= 'SYNO.API.Info',
		method	= 'query',
		version	= '1'
	}
	local respArray, errorCode = Photos_API (h, apiParams)

	if not respArray then return nil, errorCode end

	h.serverCapabilities = PHOTOSERVER_API[version].capabilities
	h.Photo 	= PhotosPhoto.new()

	writeLogfile(3, string.format("Photos.new(url=%s, personal=%s, persUser=%s, timeout=%d) returns\n%s\n",
						serverUrl, usePersonalPS, personalPSOwner, serverTimeout, JSON:encode(h)))

	-- rewrite the apiInfo table with API infos retrieved via SYNO.API.Info
	h.apiInfo 	= respArray.data

	return setmetatable(h, Photos_mt)
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
--		logintype			= "local",
		hhid 				= h.hhid,
		enable_syno_token 	= "yes",
--		format				= "cookie",
--		format				= "sid",
	}
	local respArray, errorCode = Photos_API(h, apiParams)

	if not respArray then return false, errorCode end

	h.synotoken = respArray.data.synotoken

	local rootFolderId
	if h.userid == 0 then
		rootFolderId = 1
	else
		-- if Login to Personal Photos, get folderId of personal root folder
		rootFolderId, errorCode = Photos_getPersonalRootFolderId(h)
	end
	if not rootFolderId then return false, errorCode end

	-- initialize folderId cache w/ root folder
	pathIdCacheAddEntry(h.userid, "/", rootFolderId, "folder")

	return respArray.success
end

---------------------------------------------------------------------------------------------------------
-- logout(h)
-- nothing to do here, invalidating the cookie would be perfect here
function Photos.logout (h)
	return true
end

-- #####################################################################################################
-- ########################## folder management ########################################################
-- #####################################################################################################

---------------------------------------------------------------------------------------------------------
-- Photos_createFolder (h, parentDir, newDir)
-- parentDir must exit
-- newDir may or may not exist, will be created
function Photos_createFolder (h, parentDir, newDir)
	writeLogfile(3, string.format("Photos_createFolder('%s', '%s') ...\n", parentDir, newDir))
	local apiParams = {
		api 				= "SYNO.FotoTeam.Browse.Folder",
		version 			= "1",
		method 				= "create",
		target_id			= Photos.getFolderId(h, parentDir),
		name				= '"' .. newDir .. '"'
	}
	local respArray, errorCode = Photos_API(h, apiParams)

	if not respArray and Photos.getErrorMsg(errorCode) == 'error_file_exist' then
		return Photos.getFolderId(h, LrPathUtils.child(parentDir, newDir))
	end

	if not respArray then return false, errorCode end
	local folderId = respArray.data.folder.id
	writeLogfile(3, string.format("Photos_createFolder('%s', '%s') returns %d\n", parentDir, newDir, folderId))

	return folderId
end

---------------------------------------------------------------------------------------------------------
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
-- Photos_deleteFolder(h, folderPath)
local function Photos_deleteFolder (h, folderPath)
	local folderId = h:getFolderId(folderPath)
	if not folderId then
		writeLogfile(3, string.format('Photos_deleteFolder(%s): does not exist, returns OK\n', folderPath))
		return true
	end

	pathIdCacheDeleteEntry(h.userid, folderPath, 'folder')

	local apiParams = {
		id		= "[" .. folderId  .. "]",
		api		= "SYNO.FotoTeam.Browse.Folder",
		method	="delete",
		version=1
	}

	local respArray, errorCode = Photos_API(h, apiParams)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('Photos_deleteFolder(%s) returns OK\n', folderPath))
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
		local photoInfos =  Photos_listAlbumItems(h, currentFolderPath)
		local subfolders =  Photos_listAlbumSubfolders(h, currentFolderPath)

    	-- if not empty, we are ready
    	if 		(photoInfos and #photoInfos > 0)
    		or 	(subfolders	and	#subfolders > 0)
    	then
   			writeLogfile(3, string.format('deleteEmptyAlbumAndParents(%s) - was not empty: not deleted.\n', currentFolderPath))
    		return nDeletedFolders
		elseif not Photos_deleteFolder (currentFolderPath) then
			writeLogfile(2, string.format('deleteEmptyAlbumAndParents(%s) - was empty: delete failed!\n', currentFolderPath))
		else
			writeLogfile(2, string.format('deleteEmptyAlbumAndParents(%s) - was empty: deleted.\n', currentFolderPath))
			nDeletedFolders = nDeletedFolders + 1
		end

		currentFolderPath = string.match(currentFolderPath , '(.+)/[^/]+')
	end

	return nDeletedFolders
end

-- #####################################################################################################
-- ########################## photo/video upload #######################################################
-- #####################################################################################################

local function Photos_uploadPictureFiles(h, dstDir, dstFilename, srcDateTime, mimeType, srcFilename, thumbGenerate, thmb_XL_Filename, thmb_M_Filename, thmb_S_Filename)
	local postHeaders = {
		{ field = 'X-SYNO-HHID',	value = h.hhid },
		{ field = 'X-SYNO-TOKEN',	value = h.synotoken },
	}
	writeLogfile(3, string.format("Photos_uploadPictureFiles('%s', '%s', '%s', %s', '%s', '%s', '%s', '%s', '%s')\n",
				dstDir, dstFilename, srcDateTime, mimeType, srcFilename, thumbGenerate, thmb_XL_Filename, thmb_M_Filename, thmb_S_Filename))

	-- calculate max. upload time for LrHttp.post()
	-- we expect a minimum of 10 MBit/s upload speed --> 1.25 MByte/s
	local fileSize = LrFileUtils.fileAttributes(srcFilename).fileSize
	if not fileSize then
		local errorMsg = "Photos_uploadPictureFiles: cannot get fileSize of '" .. srcFilename .."'!"
		writeLogfile(3, errorMsg .. "\n")
		return false, errorMsg
	end
	local timeout = math.floor(fileSize / 1250000)
	if timeout < 30 then timeout = 30 end

	local targetFolderId = Photos.getFolderId(h, dstDir)
	if not targetFolderId then
		local errorMsg = "Photos_uploadPictureFiles: cannot get folderId of '" .. dstDir .."'!"
		writeLogfile(3, errorMsg .. "\n")
		return false, errorMsg
	end

	local respBody, respHeaders, contentTableStr, funcAndParams
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
--			value		= function () return postFile:read(10000000) end,
--			totalSize	= fileSize
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
		contentTableStr = JSON:encode(contentTable)
		funcAndParams = string.format("Photos_uploadPictureFiles('%s', '%s', '%s', '%s')", srcFilename, dstDir, dstFilename, contentTableStr)
		writeLogfile(4, string.format("%s: calling LrHttp.postMultipart()\n", funcAndParams))
		respBody, respHeaders = LrHttp.postMultipart(h.serverUrl .. h.psWebAPI .. h.apiInfo[synoAPI].path, contentTable, postHeaders, timeout, nil, false)
     	-- postFile:close()

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

	local respArray = JSON:decode(respBody, funcAndParams)

	if not respArray then
		success = false
		errorMsg = Photos.getErrorMsg(1003)
	elseif not respArray.success then
		success = false
		errorMsg = Photos.getErrorMsg(respArray.error.code)
	end

	if not success then
		writeLogfile(1, string.format("%s failed: %s!\n", funcAndParams, errorMsg))
		return success, errorMsg
	end

	writeLogfile(3, string.format("%s returns '%s', '%s'\n", funcAndParams, success, respArray.data.id))
	return success, respArray.data.id
end

---------------------------------------------------------------------------------------------------------
-- uploadPhotoFiles
-- upload photo plus its thumbnails (if configured)
function Photos.uploadPhotoFiles(h, dstDir, dstFilename, dstFileTimestamp, thumbGenerate, photo_Filename, title_Filename, thmb_XL_Filename, thmb_L_Filename, thmb_B_Filename, thmb_M_Filename, thmb_S_Filename)
	dstFilePath = LrPathUtils.child(dstDir, dstFilename)

	local oldPhotoId, oldPhotoInfo = Photos.getPhotoId(h, dstFilePath, true)
	if oldPhotoId then
		if not	Photos.deletePhoto(h, dstFilePath, nil, oldPhotoId) then return false end

		-- HACK: if new filename is not upper/lowercase identical to old filename
		-- 		then we have to wait some time until Photos has deleted the old entry
		--		otherwise we will have to re-index to recover the new file ... :-(
		if dstFilename ~= oldPhotoInfo.filename then
			writeLogfile(3, string.format("uploadPhotoFiles('%s') waiting 3 seconds after deleting old file '%s' with different upper/lowercase spelling...\n", dstFilePath, oldPhotoInfo.filename))
			LrTasks.sleep(3)
		end
	end

	local success, photoId = Photos_uploadPictureFiles(h, dstDir, dstFilename, dstFileTimestamp, 'image/jpeg', photo_Filename, thumbGenerate, thmb_XL_Filename, thmb_M_Filename, thmb_S_Filename)
	if success then
		-- add the id w/o photoInfo to the cache, so getPhotoId() can return the id from cache, but will need to re-scan the album if photoInfo is required
		pathIdCacheAddEntry(h.userid, dstFilePath, photoId, 'item', nil)
	end

	return success
end

---------------------------------------------------------------------------------------------------------
-- uploadVideoFiles
-- upload video plus its thumbnails (if configured) and add. videos)
-- exportParams.psutils.uploadVideoFiles(exportParams.photoServer, dstDir, dstFilename, dstFileTimestamp, exportParams.thumbGenerate,
--			vid_Orig_Filename, title_Filename, thmb_XL_Filename, thmb_L_Filename, thmb_B_Filename, thmb_M_Filename, thmb_S_Filename,
--			vid_Add_Filename, vid_Replace_Filename, convParams, convKeyOrig, convKeyAdd, addOrigAsMp4)
function Photos.uploadVideoFiles(h, dstDir, dstFilename, dstFileTimestamp, thumbGenerate, video_Filename, title_Filename,
										thmb_XL_Filename, thmb_L_Filename, thmb_B_Filename, thmb_M_Filename, thmb_S_Filename,
										vid_Add_Filename, vid_Replace_Filename, convParams, convKeyOrig, convKeyAdd, addOrigAsMp4)
	dstFilePath = LrPathUtils.child(dstDir, dstFilename)

	local oldPhotoId, oldPhotoInfo = Photos.getPhotoId(h, dstFilePath, true)
	if oldPhotoId then
		if not	Photos.deletePhoto(h, dstFilePath, nil, oldPhotoId) then return false end

		-- HACK: if new filename is not upper/lowercase identical to old filename
		-- 		then we have to wait some time until Photos has deleted the old entry
		--		otherwise we will have to re-index to recover the new file ... :-(
		if dstFilename ~= oldPhotoInfo.filename then
			writeLogfile(3, string.format("uploadVideoFiles('%s') waiting 5 seconds after deleting old file '%s' with different upper/lowercase spelling...\n", dstFilePath, oldPhotoInfo.filename))
			LrTasks.sleep(5)
		end
	end

	local success, videoId = Photos_uploadPictureFiles(h, dstDir, dstFilename, dstFileTimestamp, 'video/mp4', video_Filename, thumbGenerate, thmb_XL_Filename, thmb_M_Filename, thmb_S_Filename)
	if success then
		-- add the id w/o photoInfo to the cache, so getPhotoId() can return the id from cache, but will need to re-scan the album if photoInfo is required
		pathIdCacheAddEntry(h.userid, dstFilePath, videoId, 'item', nil)
	end

	return success
end

-- #####################################################################################################
-- ########################## photo management #########################################################
-- #####################################################################################################

---------------------------------------------------------------------------------------------------------
-- editPhoto (h, photoPath, attrValPairs)
-- edit specific metadata field of a photo
function Photos.editPhoto(h, photoPath, attrValPairs)
	writeLogfile(3, string.format("Photos.editPhoto('%s', %d items) ...\n", photoPath, #attrValPairs))
	local photoId = h:getPhotoId(photoPath)
	local apiParams = {
		api 				= "SYNO.FotoTeam.Browse.Item",
		version 			= iif(h.serverVersion == 70, "1", "2"),
		method 				= "set",
		id					= "[" .. photoId .. "]",
	}
	for i = 1, #attrValPairs do
		if isNumber(attrValPairs[i].value) or isJson(attrValPairs[i].value) then
			apiParams[attrValPairs[i].attribute] = 		  urlencode(attrValPairs[i].value)
		else
			apiParams[attrValPairs[i].attribute] = '"' .. urlencode(attrValPairs[i].value) .. '"'
		end
	end
	local respArray, errorCode = Photos_API(h,apiParams)

	-- add the id w/o photoInfo to the cache, so getPhotoId() can return the id from cache, but will need to re-scan the album if photoInfo is required
	pathIdCacheAddEntry(h.userid, photoPath, photoId, 'item', nil)

	if not respArray then return nil, errorCode end

	writeLogfile(3, string.format('editPhoto(%s) returns OK\n', photoPath))
	return respArray.success, errorCode
end

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

	local respArray, errorCode = Photos_API(h,apiParams)

	if not respArray then return nil, errorCode end

	writeLogfile(3, string.format('movePhoto(%s, %s) returns OK\n', srcPhotoPath, dstFolder))
	return respArray.success, errorCode
end

---------------------------------------------------------------------------------------------------------
-- deletePhoto (h, path[, isVideo[, optPhotoId]])
function Photos.deletePhoto (h, path, isVideo, optPhotoId)
	local photoId = optPhotoId or h:getPhotoId(path)
	if not photoId then
		writeLogfile(3, string.format("deletePhoto('%s', '%s'): does not exist, returns OK\n", path, ifnil(optPhotoId, '<nil>')))
		return true
	end

	local apiParams = {
		id		= "[" .. photoId  .. "]",
		api		= "SYNO.FotoTeam.Browse.Item",
		method	= "delete",
		version	= 1
	}

	pathIdCacheDeleteEntry(h.userid, path, 'item')

	local respArray, errorCode = Photos_API(h,apiParams)

	if not respArray then return nil, errorCode end

	writeLogfile(3, string.format("deletePhoto('%s', '%s') returns OK (errorCode was %d)\n", path, ifnil(optPhotoId, '<nil>'), ifnil(errorCode, 0)))
	return respArray.success, errorCode
end

-- #####################################################################################################
-- ########################################## tagIdCache ##############################################
-- #####################################################################################################
local Photos_getTagIds

-- the tagIdCache holds the list of tag name / tag id mappings
local tagIdCache = {
	['desc']	= {},
	['people']	= {},
	['geo']		= {},
}

---------------------------------------------------------------------------------------------------------
-- tagIdCacheUpdate(h, type)
local function tagIdCacheUpdate(h, type)
	writeLogfile(3, string.format('tagIdCacheUpdate(%s).\n', type))
	tagIdCache[type] = Photos_getTagIds(h, type)
	return tagIdCache[type]
end

---------------------------------------------------------------------------------------------------------
-- tagIdCacheGetEntry(h, type, name)
local function tagIdCacheGetEntry(h, type, name)
	writeLogfile(4, string.format("getTagId(%s, %s)...\n", type, name))
	local tagsOfType = tagIdCache[type]

	if #tagsOfType == 0 and not tagIdCacheUpdate(h, type) then
		return nil
	end
	tagsOfType = tagIdCache[type]

	for i = 1, #tagsOfType do
		if tagsOfType[i].name == name then
			writeLogfile(3, string.format("getTagId(%s, '%s') found  %s.\n", type, name, tagsOfType[i].id))
			return tagsOfType[i].id
		end
	end

	writeLogfile(3, string.format("getTagId(%s, '%s') not found.\n", type, name))
	return nil
end

-- #####################################################################################################
-- ########################## tag management ###########################################################
-- #####################################################################################################

---------------------------------------------------------------------------------------------------------
-- Photos_getTagIds (h, type)
-- get table of tagId/tagString mappings for given type: desc, people, geo
function Photos_getTagIds(h, type)
	-- TODO: evaluate tag type
	writeLogfile(3, string.format("Photos_getTagIds('%s') ...\n", type))
	local apiParams = {
		api 				= "SYNO.FotoTeam.Browse.GeneralTag",
		version 			= "1",
		method 				= "list",
		offset				= "0",
		limit				= "5000"
	}
	local respArray, errorCode = Photos_API(h, apiParams)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format('Photos_getTagIds returns %d tags.\n', #respArray.data.list))
	return respArray.data.list
end

---------------------------------------------------------------------------------------------------------
-- Photos_createTag (h, type, name)
-- create a new tagId/tagString mapping of or given type: desc, people, geo
local function Photos_createTag(h, type, name)
	-- TODO: evaluate type
	writeLogfile(3, string.format("Photos_createTag('%s', '%s') ...\n", type, name))
	local apiParams = {
		api 				= "SYNO.FotoTeam.Browse.GeneralTag",
		version 			= "1",
		method 				= "create",
		name				= '"' .. urlencode(name) ..'"'
	}
	local respArray, errorCode = Photos_API(h, apiParams)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format("Photos_createTag('%s') returns id %d \n", name, respArray.data.tag.id))
	return respArray.data.tag.id
end

---------------------------------------------------------------------------------------------------------
-- Photos_addPhotoTag (h, photoPath, type, tagId, addinfo)
-- add a new tag (general,people,geo) to a photo
local function Photos_addPhotoTag(h, photoPath, type, tagId, addinfo)
	-- TODO: evaluate type
	writeLogfile(4, string.format("Photos_addPhotoTag('%s', '%s') ...\n", photoPath, tagId))
	local photoId = h:getPhotoId(photoPath)
	local apiParams = {
		api 				= "SYNO.FotoTeam.Browse.Item",
		version 			= "1",
		method 				= "add_tag",
		id					= "[" .. photoId .. "]",
		tag					= "[" .. tagId .. "]",
	}

	local respArray, errorCode = Photos_API(h,apiParams)

	-- add the id w/o photoInfo to the cache, so getPhotoId() can return the id from cache, but will need to re-scan the album if photoInfo is required
	pathIdCacheAddEntry(h.userid, photoPath, photoId, 'item', nil)

	if not respArray then return nil, errorCode end

	writeLogfile(3, string.format("Photos_addPhotoTag('%s', '%s') returns OK\n", photoPath, tagId))
	return respArray.success, errorCode
end

---------------------------------------------------------------------------------------------------------
-- removePhotoTag(h, photoPath, tagType, tagId)
-- remove a tag from a photo
function Photos.removePhotoTag(h, photoPath, tagType, tagId)
	-- TODO: evaluate type
	writeLogfile(4, string.format("removePhotoTag('%s', '%s') ...\n", photoPath, tagId))
	local photoId = h:getPhotoId(photoPath)
	local apiParams = {
		api 				= "SYNO.FotoTeam.Browse.Item",
		version 			= "1",
		method 				= "remove_tag",
		id					= "[" .. photoId .. "]",
		tag					= "[" .. tagId .. "]",
	}

	local respArray, errorCode = Photos_API(h,apiParams)

	-- add the id w/o photoInfo to the cache, so getPhotoId() can return the id from cache, but will need to re-scan the album if photoInfo is required
	pathIdCacheAddEntry(h.userid, photoPath, photoId, 'item', nil)

	if not respArray then return nil, errorCode end

	writeLogfile(3, string.format("removePhotoTag('%s', '%s') returns OK\n", photoPath, tagId))
	return respArray.success, errorCode
end

---------------------------------------------------------------------------------------------------------
-- createAndAddPhotoTag (h, dstFilename, type, name, addinfo)
-- create and add a new tag (desc,people,geo) to a photo
function Photos.createAndAddPhotoTag(h, dstFilename, type, name, addinfo)
	local tagId = tagIdCacheGetEntry(h, type, name)
	if not tagId then
		tagId = Photos_createTag(h, type, name)
		tagIdCacheUpdate(h, type)
	end

	if not tagId then return false end

	local photoTagIds, errorCode = Photos_addPhotoTag(h, dstFilename, type, tagId, addinfo)

	if not photoTagIds and errorCode == 467 then
		-- tag was deleted, cache wasn't up to date
		tagId = Photos_createTag(h, type, name)
		tagIdCacheUpdate(h, type)
	 	photoTagIds, errorCode = Photos_addPhotoTag(h, dstFilename, type, tagId, addinfo)
	end

	-- errorCode 468: duplicate tag (tag already there)
	if not photoTagIds and errorCode ~= 468 then return false end

	writeLogfile(3, string.format("createAndAddPhotoTag('%s', '%s', '%s') returns OK.\n", dstFilename, type, name))
	return true
end

-- #####################################################################################################
-- ########################## Photo object #############################################################
-- #####################################################################################################

PhotosPhoto = {}
PhotosPhoto_mt = { __index = PhotosPhoto }

function PhotosPhoto.new(photoServer, photoPath, isVideo, infoTypeList, useCache)
	local photoInfo

	if photoPath then writeLogfile(3, string.format("PhotosPhoto:new(%s, %s, %s, %s) starting\n", photoPath, isVideo, infoTypeList, useCache)) end

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
	return self.additional and self.additional.rating
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
	if not self.changes then self.changes = {} end
	if not self.changes.metadata then self.changes.metadata = {} end

-- as string:
-- 	self.changes.metadata.gps = gps.latitude ..',' .. gps.longitude
-- as JSON array:
--	self.changes.metadata.gps = '["' .. gps.latitude .. '","' .. gps.longitude ..'"]'

-- as JSON object
--[[
	gpsData = {
		latitude = 	gps.latitude,
		longitude = gps.longitude
	}
	self.changes.metadata.gps = JSON:encode(gpsData)
]]
	return true
end

function PhotosPhoto:setRating(rating)
	if not self.changes then self.changes = {} end
	if not self.changes.metadata then self.changes.metadata = {} end

	self.changes.metadata.rating = rating
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
	writeTableLogfile(4,"updateMetadata", metadataChanges, true)
	if not metadataChanges then return true end

	local photoParams = {}

	for key, value in pairs(metadataChanges) do
		table.insert(photoParams, { attribute =  key, value = value })
	end

	if #photoParams == 0 then
		return true
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
	return true
end
