--[[----------------------------------------------------------------------------

PSPhotosAPI.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2015-2023, Martin Messmer

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

    - getSharedAlbumId
    - createSharedAlbum
    - createAndAddPhotosToSharedAlbum
    - removePhotosFromSharedAlbum

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
-- ########################## Photos object ######################################################
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
    -- SYNO.Photos.Album (416-425)
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
	[641]	= 'Folder or file already exists',

	[803]	= 'No permission to use this function (probably a session timeout)',

    -- Plugin internal error codes
    [1001]  = 'Http error: no response body, no response header',
    [1002]  = 'Http error: no response data, no errorcode in response header',
    [1003]  = 'Http error: No JSON response data',

    -- Lr HTTP errors
    -- MacOS: negative error codes
    [-1001] = 'Http error: timedOut - check IP address, port and TLS/SSL settings on Diskstation - "Intermediate compatibility" is recommended',
    [-1003] = 'Http error: cannotFindHost - check servername / domainname',
    [-1004] = 'SSL/TLS error: cannotConnectToHost - check IP address, port and TLS/SSL settings on Diskstation - "Intermediate compatibility" is recommended',
    [-1200] = 'SSL/TLS error: security error - could not establish SSL/TLS connection, check protocol and port',
    [-1202] = 'SSL/TLS error: security error - hostname in server certificate is invalid or does not match servername',

    -- Windows: error codes 12xxx
    [12002] = 'Http error: requestTimeout',
    [12007] = 'Http error: cannotFindHost - check servername / domainname',
    [12029] = 'SSL/TLS error: cannotConnectToHost - check IP address, port and TLS/SSL settings on Diskstation - "Intermediate compatibility" is recommended',
    [12038] = 'SSL/TLS error: serverCertificateHasUnknownRoot - hostname in server certificate is invalid or does not match servername',
    [12157] = 'SSL/TLS error: could not establish SSL/TLS connection, check protocol and port',

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
	    writeTableLogfile(3, 'respHeaders', respHeaders, true, 'password')
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
-- ########################## folder management  #######################################################
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
-- Photos_listFolderElements(h, folderPath, folderId, elementType)
-- returns all items (photos/videos) or subfolders of a given folder
-- returns
--		itemList/subfolderList: table of item infos / subfolders, if success, otherwise nil
--		errorcode:		errorcode, if not success
local function Photos_listFolderElements(h, folderPath, folderId, elementType)
    local functionName = iif(elementType == 'item', 'Photos_listFolderItems', 'Photos_listFolderSubfolders')
	local realFolderId = folderId or h:getFolderId(folderPath, false)
	if not realFolderId	then
		writeTableLogfile(1, string.format("%s('%s') could not get folderId, returning <nil>\n", functionName, folderPath))
		return nil, 1
	end
	local apiParams

    if elementType == 'item' then
        apiParams= {
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
    else
        apiParams = {
			id				= realFolderId,
			additional		= "[]",
			sort_direction	= "asc",
			offset			= 0,
			limit			= 2000,
			api				= "SYNO.FotoTeam.Browse.Folder",
			method			= "list",
			version			= 1
	    }
    end

	local respArray, errorCode, tryCount = nil, nil, 0

    while tryCount < 2 do
        respArray, errorCode = Photos_API(h, apiParams)
        -- check if session is still active
        if not respArray and errorCode == 803 then
            writeLogfile(3, string.format("%s('%s', '%s') returns error 803, trying again after re-login\n", functionName, folderPath, ifnil(folderId, '<nil>')))
            h:login()
            tryCount = tryCount + 1
        elseif not respArray then
            return nil, errorCode
        else
            writeLogfile(3, string.format("%s('%s', '%s') returns %d items\n", functionName, folderPath, ifnil(folderId, '<nil>'), #respArray.data.list))
            writeTableLogfile(5, string.format("functionName('%s', '%s'):\n", functionName, folderPath, ifnil(folderId, '<nil>')),respArray.data.list)
            return respArray.data.list
        end
    end

    return nil, errorCode
end

---------------------------------------------------------------------------------------------------------
-- Photos_listFolderSubfolders: returns all subfolders of a given folder
-- returns
--		subfolderList:	table of subfolder infos, if success, otherwise nil
--		errorcode:		errorcode, if not success
local function Photos_listFolderSubfolders(h, folderPath, folderId)
    return Photos_listFolderElements(h, folderPath, folderId, 'folder')
end

---------------------------------------------------------------------------------------------------------
-- Photos_listFolderItems: returns all items (photos/videos) of a given folder
-- returns
--		itemList:		table of item infos, if success, otherwise nil
--		errorcode:		errorcode, if not success
local function Photos_listFolderItems(h, folderPath, folderId)
    return Photos_listFolderElements(h, folderPath, folderId, 'item')
end

-- #####################################################################################################
-- ###################################### pathIdCache ##################################################
-- #####################################################################################################
-- The path id cache holds ids of folders and items (photo/video) as used by the PhotosAPI.
-- Items are case-insensitive in Photos, so we store and compare them lowercase
-- to have a unique representation and to find any lowercase/uppercase variation of an item name
-- layout:
--		pathIdCache = {
--          timeout,
--          listSubfolders
--          listItems
-- 
--			cache[userid] (0 for Team Folders) = {
--                  folder[folderPath] = {
--                      id
--					    item[itemName] = { id, type, addinfo }
--                      itemsValidUntil,
--					    subfolder[folderName] = { id, type }
--                      subfoldersValidUntil,
--			        }
--          }
local pathIdCache = {
	timeout			= 300,
	listSubfolders  = Photos_listFolderSubfolders,
	listItems		= Photos_listFolderItems,
	cache 			= {}
}

---------------------------------------------------------------------------------------------------------
-- pathIdCacheNormalizePathname: normalize pathnames for the cache:
--		- make sure a path starts with a '/'
-- 		- items (files) are case-insensitive in Photos, so we store them in lowercase
local function pathIdCacheNormalizePathname(path, type)
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
local function pathIdCacheInitialize(h)
    local userid = h.userid
	writeLogfile(3, string.format("pathIdCacheInitialize(user='%s')\n", userid))
	pathIdCache.cache[userid] = {}
    pathIdCache.cache[userid].folder = {}

	return true
end

---------------------------------------------------------------------------------------------------------
-- pathIdCacheGetEntry(h, path, type, wantsInfo)
--	get pathIdCache entry for the given user/path/type
--  if wantsInfo (only for items), then info element must be available also, otherwise the id is sufficient
--  If the path is not found in the cache immediately, the function will 
--  recursively add all missing parent folders and finally 
--  add all items or subfolders (depending on search type) of its immediate parent folder 
--  returns:
--      cache object    including id, if path was found (may involve a cache update)
--   or nil             if path was not found, even after cache update (folder/item does not exist)
local function pathIdCacheGetEntry(h, path, type, wantsInfo)
    local userid  = h.userid
    path    = pathIdCacheNormalizePathname(path, type)
	writeLogfile(5, string.format("pathIdCacheGetEntry(userid:%s, path:'%s', '%s', wantsInfo:%s)...\n", userid, path, type, wantsInfo))

    -- check if typ is valid
    if not string.find('folder,item', type) then return nil end

    -- chek if root folder was given
    local folderCache   = pathIdCache.cache[userid].folder
    if type == 'folder' and path == '/' then
        -- no need to check validity
        return { id = folderCache and folderCache[path].id, type = 'folder' }
    end

    -- Check for the given path in the cache object of its parent folder
    local parentFolder  = ifnil(LrPathUtils.parent(path), '/')
    local leafName      = LrPathUtils.leafName(path)

    if not  folderCache[parentFolder]
    or (
            type == 'folder'
        and (
                not folderCache[parentFolder].subfoldersValidUntil
            or      folderCache[parentFolder].subfoldersValidUntil < LrDate.currentTime()
            or not  folderCache[parentFolder].subfolder
        )
    ) or (
            type == 'item'
        and (
                not folderCache[parentFolder].itemsValidUntil
            or      folderCache[parentFolder].itemsValidUntil < LrDate.currentTime()
            or not  folderCache[parentFolder].item
            or (        wantsInfo
                and     folderCache[parentFolder].item[leafName]
                and not folderCache[parentFolder].item[leafName].addinfo
            )
        )
    ) then
        -- path was not yet cached or cache entry is outdated: update subfolder list of parentFolder
        writeLogfile(4, string.format("pathIdCacheGetEntry(userid:%s, path:'%s'): cache update required ... \n", userid, path))
        local parentFolderId = folderCache[parentFolder] and folderCache[parentFolder].id
        if not parentFolderId then
            local cachedParentFolderObject = pathIdCacheGetEntry(h, parentFolder, 'folder', nil)
            parentFolderId = cachedParentFolderObject and cachedParentFolderObject.id
        end
        if not parentFolderId then
            return nil
        end

        if type == 'folder' then
            local subfolderList, errorCode  = pathIdCache.listSubfolders(h, parentFolder, parentFolderId)
            if not subfolderList then
                writeLogfile(1, string.format("pathIdCacheGetEntry(userid:%s, path:'%s') listSubfolders('%s') returned <nil> (%s)\n", userid, path, parentFolder, Photos.getErrorMsg(errorCode)))
                return nil
            end

            writeLogfile(4, string.format("pathIdCacheGetEntry(userid:%s, path:'%s') listSubfolders found %d subfolders in '%s'\n", userid, path, #subfolderList, parentFolder))
            folderCache[parentFolder].subfolder = {}
            for i = 1, #subfolderList do
                folderCache[parentFolder].subfolder[LrPathUtils.leafName(subfolderList[i].name)] = {
                    id  = subfolderList[i].id,
                    type    = 'folder'
                }
                folderCache[subfolderList[i].name] = { id = subfolderList[i].id }
            end
            folderCache[parentFolder].subfoldersValidUntil = LrDate.currentTime() + pathIdCache.timeout

        elseif type == 'item' then
            local itemList, errorCode = pathIdCache.listItems(h, parentFolder, parentFolderId)
            if not itemList then
                writeLogfile(1, string.format("pathIdCacheGetEntry(userid:%s, path:'%s') listItems('%s') returned <nil> (%s)\n", userid, path, parentFolder, Photos.getErrorMsg(errorCode)))
                return nil
            end

            writeLogfile(4, string.format("pathIdCacheGetEntry(userid:%s, path:'%s') listItems('%s') found %d items\n", userid, path, parentFolder, #itemList))
            folderCache[parentFolder].item = {}
            for i = 1, #itemList do
                folderCache[parentFolder].item[string.lower(itemList[i].filename)] = {
                    id      = itemList[i].id,
                    type    = 'item',
                    addinfo = itemList[i]
                }
            end
            folderCache[parentFolder].itemsValidUntil = LrDate.currentTime() + pathIdCache.timeout
        end
    end

    if type == 'folder' then
        return folderCache[parentFolder].subfolder[leafName]
    else
        return folderCache[parentFolder].item[leafName]
    end
end

---------------------------------------------------------------------------------------------------------
-- pathIdCacheAddEntry(h, path, id, type, addinfo)
--	add a single item or folder path to the pathIdCache
--  This function must be called, whenever the plugin creates a folder or an item,
--  We can assume that the entry for the parentFolder already exists.
--  This function will not change the validity time for the parentFolder
--  addinfo is only valid for items, it contains additional item info (metadata, tags, ...)
local function pathIdCacheAddEntry(h, path, id, type, addinfo)
    local userid = h.userid
	path = pathIdCacheNormalizePathname(path, type)
	writeLogfile(3, string.format("pathIdCacheAddEntry(user='%s', path='%s', '%s', id=%d)\n", userid, path, type, id))
	if not pathIdCache.cache[userid] then pathIdCacheInitialize(h) end
	local folderCache = pathIdCache.cache[userid].folder

    local parentFolder  = ifnil(LrPathUtils.parent(path), '/')
    local leafName      = LrPathUtils.leafName(path)

    if  type == 'folder' then
        -- folder: generate the folder entry w/o subfolders or items
         folderCache[path] = {
            id      = id
        }

        -- add folder entry to parentFolder if this is not the root folder
        if path ~= '/' then
            if not folderCache[parentFolder].subfolder then
                folderCache[parentFolder].subfolder = {}
            end
            folderCache[parentFolder].subfolder[leafName] = {
                id = id,
                type = 'folder'
            }
        end
    elseif type == 'item' then
        -- add item entry to parentFolder
        if not folderCache[parentFolder].item then
            folderCache[parentFolder].item = {}
        end
        folderCache[parentFolder].item[leafName] = {
            id      = id,
            type    = 'item',
            addinfo = addinfo
        }
    else
        writeLogfile(1, string.format("pathIdCacheAddEntry(user='%s', path='%s', '%s', id=%d) --> invalid type!\n", userid, path, type, id))
    end
end

---------------------------------------------------------------------------------------------------------
-- pathIdCacheRemoveEntry(h, path, type)
--	delete a folder or item from the pathIdCache
--  This function must be called whenever a remote folder or item was deleted
--  This function will not change the validity time for the parentFolder
local function pathIdCacheRemoveEntry(h, path, type)
    local userid = h.userid
	path = pathIdCacheNormalizePathname(path, type)
	writeLogfile(3, string.format("pathIdCacheRemoveEntry(user='%s', path='%s', type='%s')\n", userid, path, type))
	local folderCache = pathIdCache.cache[userid] and pathIdCache.cache[userid].folder

    if not folderCache then return end

    local parentFolder  = ifnil(LrPathUtils.parent(path), '/')
    local leafName      = LrPathUtils.leafName(path)

    if type == 'folder' then
        if path ~= '/' and folderCache[path] then
		    folderCache[path] = nil
            folderCache[parentFolder].subfolder[leafName] = nil
        end
    elseif type == 'item' then
        folderCache[parentFolder].item[leafName] = nil
    else
        writeLogfile(1, string.format("pathIdCacheRemoveEntry(user='%s', path='%s', '%s') --> invalid type!\n", userid, path, type))
	end
end

---------------------------------------------------------------------------------------------------------
-- pathIdCacheInvalidateFolder(h, path, type)
--	age out a folder's scan result for the given subelement type ('item' or 'folder')
local function pathIdCacheInvalidateFolder(h, path, type)
    local userid = h.userid
	path = pathIdCacheNormalizePathname(path, type)
    writeLogfile(3, string.format("pathIdCacheInvalidateFolder(user='%s', path='%s', '%s')\n", userid, path, type))
	
	if pathIdCache.cache[userid] and pathIdCache.cache[userid].folder and pathIdCache.cache[userid].folder[path] then
        local cachedFolder = pathIdCache.cache[userid].folder[path]
		if type == 'folder' then
			cachedFolder.subfolder = nil
			cachedFolder.subfoldersValidUntil = nil
		else
			cachedFolder.item = nil
			cachedFolder.itemsValidUntil = nil
		end
	end
end


-- #####################################################################################################
-- ######################## Photo and Folder Id Mgmt / pathIdCache #####################################
-- #####################################################################################################
local Photos_createFolder

---------------------------------------------------------------------------------------------------------
-- Photos.getFolderId(h, path, doCreate)
--  returns the id for a given folderPath in Photos.
--  The folder is searched in the pathIdCache
--  If the folder is found return its id,
--  else if doCreate is set: create (recursively) the folder and return its id
function Photos.getFolderId(h, path, doCreate)
    path = pathIdCacheNormalizePathname(path, 'folder')
	writeLogfile(5, string.format("getFolderId(userid:%s, path:'%s') ...\n", h.userid, path))

	local cachedPathInfo = pathIdCacheGetEntry(h, path, 'folder', nil)
	local folderId
	if cachedPathInfo then
		writeLogfile(3, string.format("getFolderId(userid:%s, path:'%s') returns '%d' from cache\n", h.userid, path, cachedPathInfo.id))
		return cachedPathInfo.id
    end
	
    if not doCreate then
		writeLogfile(3, string.format("getFolderId(userid:%s, path:'%s') returns <nil>\n", h.userid, path))
		return nil
	end

    -- folder does not exist but doCreate was set
    local parentFolder  = ifnil(LrPathUtils.parent(path), '/')
    local leafName      = LrPathUtils.leafName(path)
    local errorCode
    folderId, errorCode = Photos_createFolder(h, parentFolder, h:getFolderId(parentFolder, doCreate), leafName)
    -- Photos_createFolder() will add the folderPath to the pathIdCache

    writeLogfile(iif(folderId, 3, 1), string.format("getFolderId(userid:%s, path '%s') returns '%s' (after creating folder)\n", h.userid, path, ifnil(folderId, '<nil>')))
	return folderId

end

---------------------------------------------------------------------------------------------------------
-- getPhotoId(h, path, isVideo, wantsInfo)
-- 	returns the id and - if wantsInfo - additional info for a given item (photo/video) path in Photos
--  The fitem is searched in the pathIdCache
function Photos.getPhotoId(h, path, isVideo, wantsInfo)
    path = pathIdCacheNormalizePathname(path, 'item')
	writeLogfile(5, string.format("getPhotoId(userid:%s, path:'%s') ...\n", h.userid, path))

	local cachedPathInfo = pathIdCacheGetEntry(h, path, 'item', wantsInfo)
	if cachedPathInfo then
		writeLogfile(3, string.format("getPhotoId(userid:%s, path:'%s') returns id '%d' from cache\n", h.userid, path, cachedPathInfo.id))
		return cachedPathInfo.id, cachedPathInfo.addinfo
	end

    return nil
end

---------------------------------------------------------------------------------------------------------
-- getPhotoInfoFromList(h, albumType, albumName, dstFilename, isVideo, useCache)
-- return photo infos for a photo in a given folder list (folder, shared album or public shared album)
-- returns:
-- 		photoInfos				if remote photo was found
-- 		nil,					if remote photo was not found
-- 		nil,		errorCode	on error
function Photos.getPhotoInfoFromList(h, folderType, folderPath, photoPath, isVideo, useCache)
    if folderType == 'sharedAlbum' then
		writeLogfile(3, string.format("getPhotoInfoFromList('%s', '%s', '%s', useCache %s) returning nil to force re-adding of photo\n", folderType, folderPath, photoPath, useCache))
        return nil
    end

	if not useCache then pathIdCacheInvalidateFolder(h, folderPath, 'item') end

    -- get photo id plus addinfo
	local photoId, addinfo = h:getPhotoId(photoPath, isVideo, true)
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
	local folderId	= h:getFolderId(folderPath, false)

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
	writeLogfile(3, string.format("getPhotoUrl(server='%s', userid='%s', path='%s'\n)",
				h.serverUrl, h.userid, photoPath))
	local folderId	= h:getFolderId(ifnil(LrPathUtils.parent(photoPath),'/'), false)
	local itemId 	= h:getPhotoId(photoPath, isVideo, false)

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
	local port			=    string.match(servername, '[^:]+:(%d+)$')
                          or string.match(servername, '[^:]+:(%d+)/.+$')
	local slash 		= string.match(servername, '[^/]+(/)')
	local aliasPath 	= string.match(servername, '[^/]+/([^%?/]+)$')
    local launchAppPath = string.match(servername, '[^/]+/(%?launchApp=SYNO.Foto.AppInstance#)$')

	writeLogfile(5, string.format("Photos.validateServername('%s'): port '%s' aliasPath '%s' launchAppPath '%s'\n", servername, ifnil(port, '<nil>'), ifnil(aliasPath, '<nil>'), ifnil(launchAppPath, '<nil>')))

	return	(    (colon and  port) and     slash and     (aliasPath or launchAppPath))
        or  (    (colon and	 port) and not slash and not (aliasPath or launchAppPath))
		or	(not (colon or   port) and	   slash and     (aliasPath or launchAppPath))
        or  (not (colon or   port) and not slash and not (aliasPath or launchAppPath)),
		servername
end

---------------------------------------------------------------------------------------------------------
-- basedir(serverUrl, area, owner)
-- returns the basedir for the API calls.
-- This depends on whether the API is called via standard (DSM) port (5000/5001)
-- or via an alias port or alias path as defined in Login Portal configuration
-- The basedir looks like:
--		<API_prefix>/[shared|personal]_space/
-- 	  where <API_prefix> is:
--		'/?launchApp=SYNO.Foto.AppInstance#'    - if <psPort> is a standard port (5000, 5001) or
--		'/#'									- if <psPort> is a non-standard/alternative port configured in 'Login Portal'
--		'/#'									- if <psPort> is not given and an aliasPath is given as configured in 'Login Portal'
function Photos.basedir (serverUrl, area, owner)
	local port		    = string.match(serverUrl, 'http[s]*://[^:]+:(%d+)')
    local launchAppPath = string.match(serverUrl, 'http[s]*://[^/]+/(%?launchApp=SYNO.Foto.AppInstance#)$')

	return	iif(launchAppPath,
                "",
                iif(port and (port == '5000' or port == '5001'),
                    "/?launchApp=SYNO.Foto.AppInstance#",
                    "/#")) ..
			iif(area == 'personal', "/personal_space/", "/shared_space/")
end

---------------------------------------------------------------------------------------------------------
-- getErrorMsg(errorCode)
-- translates errorCode to ErrorMsg
function Photos.getErrorMsg(errorCode)
	if errorCode == nil then
		return string.format("No ErrorCode")
	end
	if PSAPIerrorMsgs[errorCode] == nil then
		-- we don't have a documented  message for that code
		return string.format("Unknown ErrorCode: %d", errorCode)
	end
	return PSAPIerrorMsgs[errorCode]
end

---------------------------------------------------------------------------------------------------------
-- Photos.new: initialize a Photos API object
function Photos.new(serverUrl, usePersonalPS, personalPSOwner, serverTimeout, version, username, password)
	local h = {} -- the handle
	local apiInfo = {}

	writeLogfile(4, string.format("Photos.new(url=%s, personal=%s, persUser=%s, timeout=%d, version=%d, username=%s, password=***)\n", 
                                    serverUrl, usePersonalPS, personalPSOwner, serverTimeout, version, username))

	h.serverUrl 	= serverUrl
	h.serverTimeout = serverTimeout
	h.serverVersion	= version
    h.username	    = username
    h.password	    = password

	if usePersonalPS then
		h.userid 		= personalPSOwner
	else
		h.userid		= 0
	end
	pathIdCacheInitialize(h)

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
	h.thumbs 			 = PHOTOSERVER_API[version].thumbs
	h.Photo 	= PhotosPhoto.new()

	writeLogfile(3, string.format("Photos.new(url=%s, personal=%s, persUser=%s, timeout=%d) returns\n%s\n",
						serverUrl, usePersonalPS, personalPSOwner, serverTimeout, string.gsub(JSON:encode(h), '"password":"[^"]+"', '"password":"***"')))

	-- rewrite the apiInfo table with API infos retrieved via SYNO.API.Info
	h.apiInfo 	= respArray.data

	return setmetatable(h, Photos_mt)
end

---------------------------------------------------------------------------------------------------------
-- login(h)
-- does, what it says
function Photos.login(h)
	local apiParams = {
		api 				= "SYNO.API.Auth",
		version 			= "7",
		method 				= "login",
		session 			= "webui",
		account				= urlencode(h.username),
		passwd				= urlencode(h.password),
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
	pathIdCacheAddEntry(h, "/", rootFolderId, "folder", nil)

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
-- Photos_createFolder (h, parentDir, parentDirId, newDir)
-- parentDir must exit
-- newDir may or may not exist, will be created
function Photos_createFolder (h, parentDir, parentDirId, newDir)
	writeLogfile(3, string.format("Photos_createFolder('%s', '%s', '%s') ...\n", parentDir, ifnil(parentDirId, '<nil>'), newDir))
	local apiParams = {
		api 				= "SYNO.FotoTeam.Browse.Folder",
		version 			= "1",
		method 				= "create",
		target_id			= parentDirId or h:getFolderId(parentDir, false),
		name				= '"' .. urlencode(newDir) .. '"'
	}
	local respArray, errorCode = Photos_API(h, apiParams)

	if not respArray and errorCode == 641 then
		writeLogfile(3, string.format("Photos_createFolder('%s', '%s', '%s'): folder already exists, returning folderId from cache\n", parentDir, ifnil(parentDirId, '<nil>'), newDir))
		return h:getFolderId(LrPathUtils.child(parentDir, newDir), false)
	elseif not respArray then
		writeLogfile(3, string.format("Photos_createFolder('%s', '%s', '%s'): return <nil>, %s\n", parentDir, ifnil(parentDirId, '<nil>'), newDir, Photos.getErrorMsg(errorCode)))
		return nil, errorCode
	end

	local folderId = respArray.data.folder.id

    pathIdCacheAddEntry(h, LrPathUtils.child(parentDir, newDir), folderId, "folder", nil)

	writeLogfile(3, string.format("Photos_createFolder('%s', '%s', '%s') returns %d\n", parentDir, ifnil(parentDirId, '<nil>'), newDir, folderId))

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
	local folderId, errorCode = h:getFolderId(dstDir, true)

	if folderId then
		return dstDir
	end

	return nil, errorCode
end

---------------------------------------------------------------------------------------------------------
-- Photos_deleteFolder(h, folderPath)
local function Photos_deleteFolder (h, folderPath)
	local folderId = h:getFolderId(folderPath, false)
	if not folderId then
		writeLogfile(3, string.format('Photos_deleteFolder(%s): does not exist, returns OK\n', folderPath))
		return true
	end

	local apiParams = {
		id		= "[" .. folderId  .. "]",
		api		= "SYNO.FotoTeam.Browse.Folder",
		method	="delete",
		version=1
	}

	local respArray, errorCode = Photos_API(h, apiParams)

	if not respArray then return false, errorCode end

    pathIdCacheRemoveEntry(h, folderPath, 'folder')

    writeLogfile(3, string.format('Photos_deleteFolder(%s) returns OK\n', folderPath))
	return respArray.success, errorCode
end

---------------------------------------------------------------------------------------------------------
-- deleteEmptyAlbumAndParents(h, folderPath)
-- delete an folder and all its parents as long as they are empty
-- Do not use the pathIdCache.
-- return count of deleted folders
function Photos.deleteEmptyAlbumAndParents(h, folderPath)
	local nDeletedFolders = 0
	local currentFolderPath

	currentFolderPath = folderPath
	while currentFolderPath do
		local photoInfos =  Photos_listFolderItems(h, currentFolderPath)
		local subfolders =  Photos_listFolderSubfolders(h, currentFolderPath)

    	-- if not empty, we are ready
    	if 		(photoInfos and #photoInfos > 0)
    		or 	(subfolders	and	#subfolders > 0)
    	then
   			writeLogfile(3, string.format('deleteEmptyAlbumAndParents(%s) - was not empty: not deleted.\n', currentFolderPath))
    		return nDeletedFolders
		elseif not Photos_deleteFolder (h, currentFolderPath) then
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

	local targetFolderId = h:getFolderId(dstDir, false)
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
				value	= targetFolderId
			},
			iif(thumbGenerate and thmb_XL_Filename ~= '',
			{
				name		= 'thumb_xl',
				fileName	= 'thumb_xl',
				filePath	= thmb_XL_Filename,
				contentType	= 'image/jpeg',
			}, nil),
			iif(thumbGenerate and thmb_M_Filename ~= '',
			{
				name		= 'thumb_m',
				fileName	= 'thumb_m',
				filePath	= thmb_M_Filename,
				contentType	= 'image/jpeg',
			}, nil),
			iif(thumbGenerate and thmb_S_Filename ~= '',
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
	local dstFilePath = LrPathUtils.child(dstDir, dstFilename)

	local oldPhotoId, oldPhotoInfo = h:getPhotoId(dstFilePath, false, true)
	if oldPhotoId and oldPhotoInfo then
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
		pathIdCacheAddEntry(h, dstFilePath, photoId, 'item', nil)
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
	local dstFilePath = LrPathUtils.child(dstDir, dstFilename)

	local oldPhotoId, oldPhotoInfo = h:getPhotoId(dstFilePath, true, true)
	if oldPhotoId and oldPhotoInfo then
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
		pathIdCacheAddEntry(h, dstFilePath, videoId, 'item', nil)
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
	local photoId = h:getPhotoId(photoPath, nil, false)
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
	pathIdCacheAddEntry(h, photoPath, photoId, 'item', nil)

	if not respArray then return nil, errorCode end

	writeLogfile(3, string.format('editPhoto(%s) returns OK\n', photoPath))
	return respArray.success, errorCode
end

---------------------------------------------------------------------------------------------------------
-- movePhoto (h, srcFilename, dstFolder, isVideo)
function Photos.movePhoto(h, srcPhotoPath, dstFolder, isVideo)
	local photoId = h:getPhotoId(srcPhotoPath, isVideo, false)
	if not photoId then
		writeLogfile(3, string.format('movePhoto(%s): does not exist, returns false\n', srcPhotoPath))
		return false
	end
	local srcFolderId = h:getFolderId(LrPathUtils.parent(srcPhotoPath), false)
	local dstFolderId = h:getFolderId(dstFolder, false)
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

    pathIdCacheRemoveEntry(h, srcPhotoPath, 'item')
    pathIdCacheAddEntry(h, LrPathUtils.child(dstFolder, LrPathUtils.leafName(srcPhotoPath)), photoId, 'item', nil)

	writeLogfile(3, string.format('movePhoto(%s, %s) returns OK\n', srcPhotoPath, dstFolder))
	return respArray.success, errorCode
end

---------------------------------------------------------------------------------------------------------
-- deletePhoto (h, path[, isVideo[, optPhotoId]])
function Photos.deletePhoto (h, path, isVideo, optPhotoId)
	local photoId = optPhotoId or h:getPhotoId(path, isVideo, false)
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

	pathIdCacheRemoveEntry(h, path, 'item')

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
	['desc']	= {}, -- general tags
	['person']	= {}, -- person tags
	['people']	= {}, -- person with face region tags
	['geo']		= {}, -- GPS coords tags
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

	if not respArray then return nil, errorCode end

	writeLogfile(3, string.format('Photos_getTagIds returns %d tags.\n', #respArray.data.list))
	return respArray.data.list
end

---------------------------------------------------------------------------------------------------------
-- Photos_createTag (h, type, name)
-- create a new tagId/tagString mapping of given type: desc, people, geo
local function Photos_createTag(h, type, name)
	-- TODO: evaluate type
	writeLogfile(3, string.format("Photos_createTag('%s', '%s') ...\n", type, name))
    local api
    if type == 'person' then
        api = "SYNO.FotoTeam.Browse.Person"
    else
        api	= "SYNO.FotoTeam.Browse.GeneralTag"
    end
	local apiParams = {
		api 				= api,
		version 			= "1",
		method 				= "create",
		name				= '"' .. urlencode(name) ..'"'
	}
	local respArray, errorCode = Photos_API(h, apiParams)

	if not respArray then return false, errorCode end

	writeLogfile(3, string.format("Photos_createTag('%s', '%s') returns id %d \n", type, name, respArray.data.tag.id))
	return respArray.data.tag.id
end

---------------------------------------------------------------------------------------------------------
-- Photos_addPhotoTag (h, photoPath, type, tagId, addinfo)
-- add a new tag (general,people,geo) to a photo
local function Photos_addPhotoTag(h, photoPath, type, tagId, addinfo)
	-- TODO: evaluate type
	writeLogfile(4, string.format("Photos_addPhotoTag('%s', '%s') ...\n", photoPath, tagId))
	local photoId = h:getPhotoId(photoPath, nil, false)
	local apiParams = {
		api 				= "SYNO.FotoTeam.Browse.Item",
		version 			= "1",
		method 				= "add_tag",
		id					= "[" .. photoId .. "]",
		tag					= "[" .. tagId .. "]",
	}

	local respArray, errorCode = Photos_API(h,apiParams)

	-- add the id w/o photoInfo to the cache, so getPhotoId() can return the id from cache, but will need to re-scan the album if photoInfo is required
	pathIdCacheAddEntry(h, photoPath, photoId, 'item', nil)

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
	local photoId = h:getPhotoId(photoPath, nil, false)
	local apiParams = {
		api 				= "SYNO.FotoTeam.Browse.Item",
		version 			= "1",
		method 				= "remove_tag",
		id					= "[" .. photoId .. "]",
		tag					= "[" .. tagId .. "]",
	}

	local respArray, errorCode = Photos_API(h,apiParams)

	-- add the id w/o photoInfo to the cache, so getPhotoId() can return the id from cache, but will need to re-scan the album if photoInfo is required
	pathIdCacheAddEntry(h, photoPath, photoId, 'item', nil)

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
-- ########################################## albumIdCache #############################################
-- #####################################################################################################
local Photos_listAlbums

-- the albumIdCache holds the list of album name / album id mappings
local albumIdCache = {
	['local']	= {},   -- normal/conditional albums - not shared
	['shared']	= {},   -- normal/conditional albums - shared
}

---------------------------------------------------------------------------------------------------------
-- albumIdCacheUpdate(h, type)
local function albumIdCacheUpdate(h, type)
	writeLogfile(3, string.format('albumIdCacheUpdate(%s).\n', type))
	albumIdCache[type] = Photos_listAlbums(h, type)
	return albumIdCache[type]
end

---------------------------------------------------------------------------------------------------------
-- albumIdCacheGetEntry(h, type, name)
-- returns:
--      id 
--      full album info
local function albumIdCacheGetEntry(h, type, name)
	writeLogfile(4, string.format("albumIdCacheGetEntry(%s, %s)...\n", type, name))
	local albumsOfType = albumIdCache[type]

	if #albumsOfType == 0 and not albumIdCacheUpdate(h, type) then
		return nil
	end
	albumsOfType = albumIdCache[type]

	for i = 1, #albumsOfType do
		if albumsOfType[i].name == name then
			writeLogfile(3, string.format("albumIdCacheGetEntry(%s, '%s') found  %s.\n", type, name, albumsOfType[i].id))
			return albumsOfType[i].id, albumsOfType[i]
		end
	end

	writeLogfile(3, string.format("albumIdCacheGetEntry(%s, '%s') not found.\n", type, name))
	return nil
end

-- #####################################################################################################
-- ########################## shared album management ##################################################
-- #####################################################################################################

Photos.sharedAlbumDefaults = {
	isAdvanced			= false,
	isPublic			= true,
    publicPermissions   = 'View',
    sharedAlbumPassword	= '',
	startTime			= '',
	stopTime 			= '',
	colorRed			= false,
	colorYellow			= false,
	colorGreen			= false,
	colorBlue			= false,
	colorPurple			= false,
	comments			= false,
	areaTool			= false,
	privateUrl			= '',
	publicUrl			= '',
	publicUrl2			= '',
}

---------------------------------------------------------------------------------------------------------
-- Photos_listAlbums(h, albumType)
-- returns all albums
-- returns
--		itemList/subfolderList: table of item infos / subfolders, if success, otherwise nil
--		errorcode:		errorcode, if not success
function Photos_listAlbums(h, albumType)
    writeLogfile(4, string.format("Photos_listAlbums('%s')...\n", albumType))
    local apiParams= {
        api				= "SYNO.Foto.Browse.Album",
        method			= "list",
        version			= 2,
        offset			= 0,
        limit			= 5000,
        sort_by			= "album_name",
        sort_direction	= "asc",
        additional		= '["sharing_info"]',
-- 		additional		= '["thumbnail", "sharing_info"]',
        category        = iif(albumType == 'shared', albumType, '')
    }
   
	local respArray, errorCode, tryCount = nil, nil, 0

    while tryCount < 2 do
        respArray, errorCode = Photos_API(h, apiParams)
        -- check if session is still active
        if not respArray and errorCode == 803 then
            writeLogfile(3, string.format("Photos_listAlbums('%s') returns error 803, trying again after re-login\n", albumType))
            h:login()
            tryCount = tryCount + 1
        elseif not respArray then
            return nil, errorCode
        else
            writeLogfile(3, string.format("Photos_listAlbums('%s') returns %d albums\n", albumType, #respArray.data.list))
            writeTableLogfile(5, string.format("Photos_listAlbums('%s'):\n", respArray.data.list))
            return respArray.data.list
        end
    end

    return nil, errorCode
end


---------------------------------------------------------------------------------------------------------
-- Photos_getAlbumInfo(h, type, albumName, useCache)
-- 	returns the album id and info  of an Album w/ given type
local function Photos_getAlbumInfo(h, type, albumName, useCache)
    writeLogfile(4, string.format("Photos_getAlbumInfo(userid:%s, name:'%s', '%s') ...\n", h.userid, albumName, type))
	if not useCache then albumIdCacheUpdate(h, 'shared') end
	return albumIdCacheGetEntry(h, type, albumName)
end

---------------------------------------------------------------------------------------------------------
-- getSharedAlbumId(h, albumName)
-- 	returns the id and - if wantsInfo - additional info for a given shared album in Photos
--  The item is searched in the albumIdCache
function Photos.getSharedAlbumId(h, albumName)
    return Photos_getAlbumInfo(h, 'shared', albumName, true)
end

---------------------------------------------------------------------------------------------------------
-- getSharedAlbumUrls(h, publishSettings, albumName)
-- 	returns three URLsfor the given album
function Photos.getSharedAlbumUrls(h, publishSettings, albumName)
    writeLogfile(4, string.format("Photos.getSharedAlbumUrls('%s') ...\n", albumName))
	local albumId, albumInfo = Photos_getAlbumInfo(h, 'shared', albumName, true)
	local privateUrl, publicUrl, publicUrl2
	
	if  not (albumId and albumInfo) then
		writeLogfile(4, string.format("Photos.getSharedAlbumUrls('%s') found no albumInfo\n", albumName))
		return nil, nil, nil
	end

	privateUrl 	= publishSettings.proto  .. "://" .. publishSettings.servername .. '/#/album/' .. albumId
	publicUrl 	= publishSettings.proto  .. "://" .. publishSettings.servername .. '/mo/sharing/' .. albumInfo.passphrase
	publicUrl2 	= publishSettings.proto2 .. "://" .. publishSettings.servername2 .. '/mo/sharing/' .. albumInfo.passphrase

    writeLogfile(3, string.format("Photos.getSharedAlbumUrls('%s') returns '%s', '%s', '%s'\n", albumName, privateUrl, publicUrl, publicUrl2))
	return privateUrl, publicUrl, publicUrl2
end

---------------------------------------------------------------------------------------------------------
-- Photos_createAlbum (h, albumName, albumType)
-- create a new album of given type w/ standard attributes and no photos
-- return albumId  + albumInfo or nil + errorCode
local function Photos_createAlbum(h, albumName, albumType)
	writeLogfile(4, string.format("Photos_createAlbum('%s') ...\n", albumName))

    local apiParams = {
		api 			= "SYNO.Foto.Browse.NormalAlbum",
		method 			= "create",
		version 		= "1",
		name			= '"' .. urlencode(albumName) ..'"',
        item            = '[]',
        shared          = iif(albumType == 'shared' , "true", "false")
	}
	local respArray, errorCode = Photos_API(h, apiParams)
	local albumId, albumInfo
	
	if respArray then
		albumId 	= respArray.data.album.id
		albumInfo	= respArray.data.album
	elseif not respArray and errorCode == 641 then
		writeLogfile(3, string.format("Photos_createAlbum('%s'): album already exists, using cached info\n", albumName))
		albumId, albumInfo = Photos_getAlbumInfo(h, 'shared', albumName, true)
	elseif not respArray then
		writeLogfile(1, string.format("Photos_createAlbum('%s'): return <nil>, %s\n", albumName, Photos.getErrorMsg(errorCode)))
		return nil, errorCode
	end

	writeLogfile(3, string.format("Photos_createAlbum('%s'): returning %d\n", albumName, albumId))
	return albumId, albumInfo
end

---------------------------------------------------------------------------------------------------------
-- Photos_deleteAlbum (h, albumName)
-- delete an album
-- return true or false + errorCode
local function Photos_deleteAlbum(h, albumId)
	writeLogfile(4, string.format("Photos_deleteAlbum(%d') ...\n", albumId))

    local apiParams = {
		api 			= "SYNO.Foto.Browse.Album",
		method 			= "delete",
		version 		= "1",
        id				= '['.. albumId .. ']',
	}
	local respArray, errorCode = Photos_API(h, apiParams)
	
	if not respArray then
		writeLogfile(1, string.format("Photos_deleteAlbum(%d') returns error %d\n", albumId, errorCode))
		return false, errorCode
	end

	writeLogfile(2, string.format("Photos_deleteAlbum(%d') returns OK\n", albumId, errorCode))
	return true
end

---------------------------------------------------------------------------------------------------------
-- Photos_setAlbumAttributes (h, pubAlbumName, sharedAlbumParams)
-- create a new shared album w/ standard attributes and no photos
-- return true or false # errorCode
local function Photos_setAlbumAttributes(h, pubAlbumName, sharedAlbumParams)
	-- if is public shared album: configure public album settings
	if sharedAlbumParams.isPublic then
		local expireTimestamp
		if sharedAlbumParams.stopTime == '' then
			expireTimestamp = 0
		else
			local year, month, day = string.match(sharedAlbumParams.stopTime, "(%d+)-(%d+)-(%d+)")
			expireTimestamp = LrDate.timeToPosixDate(LrDate.timeFromComponents( year, month, day, 23, 59, 59, 'local'))
		end
		local apiParams = {
			api 			= "SYNO.Foto.Sharing.Passphrase",
			method 			= "update",
			version 		= "1",
			passphrase		= '"' .. pubAlbumName ..'"',
			password		= sharedAlbumParams.sharedAlbumPassword,
			expiration		= expireTimestamp,
			permission		= '[{"action":"update","role":"' .. string.lower(sharedAlbumParams.publicPermissions) .. '","member":{"type":"public"}}]'
		}
		local respArray, errorCode = Photos_API(h, apiParams)
		if not respArray then
			writeLogfile(1, string.format("Photos_setAlbumAttributes('%s'/'%s') Passphrase update returns %d\n", sharedAlbumParams.sharedAlbumName, pubAlbumName, errorCode))
			return false, errorCode
		end
	end

	writeLogfile(3, string.format("Photos_setAlbumAttributes('%s') returns OK\n", sharedAlbumParams.sharedAlbumName))
	return true
end

---------------------------------------------------------------------------------------------------------
-- Photos_addPhotosToAlbum(h, albumId, photoIds)
-- add photos to an Album
local function Photos_addPhotosToAlbum(h, albumId, photoIds)
	writeLogfile(4, string.format('Photos_addPhotosToSharedAlbum(%d, %d photos):\n', albumId, #photoIds))

	local itemList = table.concat(photoIds, ',')

    local apiParams= {
        api				= "SYNO.Foto.Browse.NormalAlbum",
        method			= "add_item",
        version			= 1,
        id			    = albumId,
        item            = '[' .. itemList ..']'
    }

	local respArray, errorCode = Photos_API(h,apiParams)
    if not respArray then
        writeLogfile(1, string.format("Photos_addPhotosToSharedAlbum(%d, %d photos) failed (%d: %s)\n", albumId, #photoIds, errorCode, Photos.getErrorMsg(errorCode)))
        return false, errorCode
    end

	writeLogfile(3, string.format("Photos_addPhotosToSharedAlbum(%d, %d photos) returns OK\n", albumId, #photoIds))
	return true
end

---------------------------------------------------------------------------------------------------------
-- Photos_removePhotosFromAlbum(h, albumId, photoIds)
-- add photos to an Album
local function Photos_removePhotosFromAlbum(h, albumId, photoIds)
	writeLogfile(4, string.format('Photos_removePhotosFromAlbum(%d, %d photos):\n', albumId, #photoIds))

	local itemList = table.concat(photoIds, ',')

    local apiParams= {
        api				= "SYNO.Foto.Browse.NormalAlbum",
        method			= "delete_item",
        version			= 1,
        id			    = albumId,
        item            = '[' .. itemList ..']',
    }

	local respArray, errorCode = Photos_API(h,apiParams)
    if not respArray then
        writeLogfile(1, string.format('Photos_removePhotosFromAlbum(%d, %d photos): failed (%d: %s)\n', albumId, #photoIds, errorCode, Photos.getErrorMsg(errorCode)))
        return false, errorCode
    end

	writeLogfile(3, string.format("Photos_removePhotosFromAlbum(%d, %d photos) returns OK\n", albumId, #photoIds))
	return true
end

---------------------------------------------------------------------------------------------------------
-- createSharedAlbum(h, sharedAlbumParams)
-- create a Shared Album w/o any photos 
-- returns sharedAlbumInfo or nil and errorCode
function Photos.createSharedAlbum(h, sharedAlbumParams)
	writeLogfile(4, string.format("createSharedAlbum('%s')...\n", sharedAlbumParams.sharedAlbumName))

	local albumId, albumInfo = Photos_getAlbumInfo(h, 'shared', sharedAlbumParams.sharedAlbumName, true)
	local success, errorCode

	-- if album not in cache, create it as empty album w/ standard params
    if not albumId then
        -- shared album not found: create it w/ given photos
        writeLogfile(3, string.format("createAndAddPhotosToSharedAlbum('%s): album not found, create it\n", sharedAlbumParams.sharedAlbumName))
        albumId, albumInfo = Photos_createAlbum(h, sharedAlbumParams.sharedAlbumName, 'shared')
        if not albumId then
			errorCode = albumInfo
            writeLogfile(1, string.format("createSharedAlbum('%s'): failed to create album (%d: %s)!\n", sharedAlbumParams.sharedAlbumName, errorCode, Photos.getErrorMsg(errorCode)))
            return nil, errorCode
		end
	end

	-- always set album attributes
	---@diagnostic disable-next-line: need-check-nil
	success, errorCode = Photos_setAlbumAttributes(h, albumInfo.passphrase, sharedAlbumParams)
	if not success then
		return nil, errorCode
	end

	albumIdCacheUpdate(h, 'shared')

	---@diagnostic disable-next-line: need-check-nil
	writeLogfile(2, string.format("createSharedAlbum('%s') returns albumInfo(%d)\n", sharedAlbumParams.sharedAlbumName, albumInfo.id))
	return albumInfo
end

---------------------------------------------------------------------------------------------------------
-- createAndAddPhotosToSharedAlbum(h, sharedAlbumParams, photos)
-- create a Shared Album and add a list of photos to it
-- returns sharedAlbumInfo or nil and errorCode
function Photos.createAndAddPhotosToSharedAlbum(h, sharedAlbumParams, photos)
	local albumInfo, success, errorCode
	writeLogfile(4, string.format("createAndAddPhotosToSharedAlbum('%s', %d photos)...\n", sharedAlbumParams.sharedAlbumName, #photos))

	albumInfo, errorCode = Photos.createSharedAlbum(h, sharedAlbumParams)
	if not albumInfo then
		return nil, errorCode
	end

	-- if a list of photos is given, add it to the album
	if #photos > 0 then
		local photoIds = {}
		for i = 1, #photos do
			photoIds[i] = Photos.getPhotoId(h, photos[i].dstFilename, photos[i].isVideo, false)
		end
		success, errorCode = Photos_addPhotosToAlbum(h, albumInfo.id, photoIds)
    end

	if not success then
		return nil, errorCode
	end

	writeLogfile(2, string.format("createAndAddPhotosToSharedAlbum('%s', %d photos) returns albumInfo(%d)\n", sharedAlbumParams.sharedAlbumName, #photos, albumInfo.id))
	return albumInfo
end

---------------------------------------------------------------------------------------------------------
-- deleteSharedAlbum(h, sharedAlbumName)
-- delete a Shared Album
-- returns true or false + errorCode
function Photos.deleteSharedAlbum(h, sharedAlbumName)
	writeLogfile(4, string.format("deleteSharedAlbum('%s')...\n", sharedAlbumName))
	local albumId, _ = Photos_getAlbumInfo(h, 'shared', sharedAlbumName, false)
	local success, errorCode

	-- if album not found, return success
    if not albumId then
		writeLogfile(2, string.format("deleteSharedAlbum('%s') does not exist, returning OK.\n", sharedAlbumName))
		return true
	end

	return Photos_deleteAlbum(h, albumId)
end

---------------------------------------------------------------------------------------------------------
-- Photos.removePhotosFromSharedAlbum(h, sharedAlbumName, photos)
-- remove photos from Shared Album
function Photos.removePhotosFromSharedAlbum(h, sharedAlbumName, photos)
	writeLogfile(4, string.format("removePhotosFromSharedAlbum('%s', %d photos)...\n", sharedAlbumName, #photos))
	local albumId, _ = Photos_getAlbumInfo(h, 'shared', sharedAlbumName, true)
	if not albumId then
		writeLogfile(3, string.format('removePhotosFromSharedAlbum(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end

	local photoIds = {}
	for i = 1, #photos do
		photoIds[i] = Photos.getPhotoId(h, photos[i].dstFilename, photos[i].isVideo, false)
	end

	return Photos_removePhotosFromAlbum(h, albumId, photoIds)
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
		-- called from Photos.new()
		return setmetatable({}, PhotosPhoto_mt)
	end

	if string.find(infoTypeList, 'photo') then
		local photoInfoFromList, errorCode = photoServer:getPhotoInfoFromList('album', pathIdCacheNormalizePathname(LrPathUtils.parent(photoPath)), photoPath, nil, useCache)
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

-- getTags(): get all general and person tags: treat person tags as general tags due to missing face region support in Photos
function PhotosPhoto:getTags()
	local tagList = {}
	if self.additional and self.additional.tag then
		tagList = {}
		for i = 1, #self.additional.tag do
			local tag = {}
			tag.id 	 	= self.additional.tag[i].id
			tag.name 	= self.additional.tag[i].name
			tag.type 	= self.additional.tag[i].type or 'desc'
			table.insert(tagList, tag)
		end
	end

    -- Get person tags also 
    if self.additional and self.additional.person then
		tagList = tagList or {}
		for i = 1, #self.additional.person do
			local tag = {}
			tag.id 	 	= self.additional.person[i].id
			tag.name 	= self.additional.person[i].name
			tag.type 	= self.additional.person[i].type or 'person'
			table.insert(tagList, tag)
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

-- -------------- set functions: prepare metadata  in internal structure, will be pushed out to Photo Server via updateMetadata()

-- setDescription(): set the description/caption
function PhotosPhoto:setDescription(description)
	if not self.changes then self.changes = {} end
	if not self.changes.metadata then self.changes.metadata = {} end

	self.changes.metadata.description = description
	return true
end

-- setGPS(): set the GPS coords - not yet supported
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

-- setRating(): set the GPS coords - not yet supported
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

-- -------------- add/remove tag functions: prepare tag lists in internal structure, will be pushed out to Photo Server via updateTags()
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

-- -------------- show changed modified metadata and keywords
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

-- -------------- apply modified metadata
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

-- -------------- apply modified keywords
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
