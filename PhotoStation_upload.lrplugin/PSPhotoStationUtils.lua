--[[----------------------------------------------------------------------------

PSPhotoStationUtils.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2021, Martin Messmer

Photo Station utilities:
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
	
	- rating2Stars
	
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

require "PSUtilities"

--====== local functions =====================================================--

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
	[12007] = 'Http error: cannotFindHost',
	[12029] = 'Http error: cannotConnectToHost',
	[12038] = 'Http error: serverCertificateHasUnknownRoot',
}

-- ========================================== Generic Content cache ==============================================
-- Used for Albums, Shared Albums (private) and Public Shared Albums.
-- The Album Content cache holds Album contents for the least recently read albums
local contentCache = {
	["album"] = {
		cache 			= {},
		timeout			= 60,
		listFunction	= PSPhotoStationAPI.listAlbum,
	},
	
	["sharedAlbum"] = {
		cache 			= {},
		timeout			= 60,
		listFunction	= PSPhotoStationAPI.listSharedAlbum,
	},

	["publicSharedAlbum"] = {
		cache 			= {},
		timeout			= 60,
		listFunction	= PSPhotoStationAPI.listPublicSharedAlbum,
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
	h.sharedAlbumsCache = PSPhotoStationAPI.getSharedAlbums(h)
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
	tagMapping[type] = PSPhotoStationAPI.getTags(h, type)
	return tagMapping[type]
end

--================================= global functions ====================================================--

PSPhotoStationUtils = {}

---------------------------------------------------------------------------------------------------------
-- getErrorMsg(errorCode)
-- translates errorCode to ErrorMsg
function PSPhotoStationUtils.getErrorMsg(errorCode)
	if PSAPIerrorMsgs[errorCode] == nil then
		-- we don't have a documented  message for that code
		return string.format("ErrorCode: %d", errorCode)
	end
	return PSAPIerrorMsgs[errorCode]
end


---------------------------------------------------------------------------------------------------------
-- PSPhotoStationUtils.getAlbumId(albumPath)
--	returns the AlbumId of a given Album path (not leading and trailing slashes) in Photo Station
--	AlbumId looks like:
--		album_<AlbumPathInHex>
--	E.g. Album Path:
--		Albums-->Test/2007
--  yields AlbumId:
--  	album_546573742f32303037
function PSPhotoStationUtils.getAlbumId(albumPath)
	local i
	local albumId = 'album_'

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
function PSPhotoStationUtils.getAlbumUrl(h, albumPath) 
	local i
	local albumUrl
	local subDirPath = ''
	local subDirUrl  = ''
	
	local albumDirname = split(albumPath, '/')
	
	albumUrl = h.serverUrl .. h.psAlbumRoot
	
	for i = 1, #albumDirname do
		if i > 1 then  
			subDirPath = subDirPath .. '/'
		end
		subDirPath = subDirPath .. albumDirname[i]
		subDirUrl = PSPhotoStationUtils.getAlbumId(subDirPath) 
		albumUrl = albumUrl .. '/' .. subDirUrl
	end
	
	writeLogfile(3, string.format("getAlbumUrl(%s, %s) returns %s\n", h.serverUrl .. h.psAlbumRoot, albumPath, albumUrl))
	
	return albumUrl
end

---------------------------------------------------------------------------------------------------------
-- getPhotoId(photoPath, isVideo)
-- 	returns the PhotoId of a given photo path in Photo Station
-- 	PhotoId looks like:
-- 		photo_<AlbumPathInHex>_<PhotoPathInHex> or
-- 		video_<AlbumPathInHex>_<PhotoPathInHex>
-- 	E.g. Photo Path:
--		Albums --> Test/2007/2007_08_13_IMG_7415.JPG
--  yields PhotoId:
--  	photo_546573742f32303037_323030375f30385f31335f494d475f373431352e4a5047
function PSPhotoStationUtils.getPhotoId(photoPath, isVideo)
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
-- getTagId(h, type, name) 
function PSPhotoStationUtils.getTagId(h, type, name)
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
-- getPhotoUrl(h, photoPath, isVideo)
--	returns the URL of a photo/video in the Photo Station
--	URL of a photo in PS is:
--		http(s)://<PS-Server>/<PSBasedir>/#!Albums/<AlbumId_1rstLevelDir>/<AlbumId_1rstLevelAndSecondLevelDir>/.../AlbumId_1rstToLastLevelDir>/<PhotoId>
--	E.g. Photo Path:
--		Server: http://diskstation; Standard Photo Station; Photo Breadcrumb: Albums/Test/2007/2007_08_13_IMG_7415.JPG
--	yields PS Photo-URL:
--		http://diskstation/photo/#!Albums/album_54657374/album_546573742f32303037/photo_546573742f32303037_323030375f30385f31335f494d475f373431352e4a5047
function PSPhotoStationUtils.getPhotoUrl(h, photoPath, isVideo) 
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
		subDirUrl = PSPhotoStationUtils.getAlbumId(subDirPath) 
		photoUrl = photoUrl .. '/' .. subDirUrl
	end
	
	photoUrl = photoUrl .. '/' .. PSPhotoStationUtils.getPhotoId(photoPath, isVideo)
	
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
function PSPhotoStationUtils.getPhotoInfoFromList(h, albumType, albumName, photoName, isVideo, useCache)
	local updateCache = not useCache
	local photoInfos, errorCode = contentCacheList(albumType, h, albumName, 'photo,video', updateCache)
	
	if not photoInfos then return nil, errorCode end 

	local photoId = PSPhotoStationUtils.getPhotoId(photoName, isVideo)
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
-- PSPhotoStationUtils.getSharedAlbumInfo(h, sharedAlbumName, useCache)
-- 	returns the shared album info  of a given SharedAlbum 
function PSPhotoStationUtils.getSharedAlbumInfo(h, sharedAlbumName, useCache)
	if not useCache then sharedAlbumsCacheUpdate(h) end
	return sharedAlbumsCacheFind(h, sharedAlbumName)
end

---------------------------------------------------------------------------------------------------------
-- PSPhotoStationUtils.getSharedAlbumId(h, sharedAlbumName)
-- 	returns the shared Album Id of a given SharedAlbum using the Shared Album cache
function PSPhotoStationUtils.getSharedAlbumId(h, sharedAlbumName)
	local sharedAlbumInfo = sharedAlbumsCacheFind(h, sharedAlbumName)
	
	if not sharedAlbumInfo then 
		writeLogfile(3, string.format('getSharedAlbumId(%s): Shared Album not found.\n', sharedAlbumName))
		return nil
	end

	return sharedAlbumInfo.id
end

---------------------------------------------------------------------------------------------------------
-- PSPhotoStationUtils.isSharedAlbumPublic(h, sharedAlbumName)
--  returns the public flage of a given SharedAlbum using the Shared Album cache
function PSPhotoStationUtils.isSharedAlbumPublic(h, sharedAlbumName)
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
-- PSPhotoStationUtils.getSharedAlbumShareId(h, sharedAlbumName)
-- 	returns the shareId of a given SharedAlbum using the Shared Album cache
function PSPhotoStationUtils.getSharedAlbumShareId(h, sharedAlbumName)
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
function PSPhotoStationUtils.getSharedPhotoPublicUrl(h, albumName, photoName, isVideo)
	local photoInfos, errorCode = PSPhotoStationUtils.getPhotoInfoFromList(h, 'sharedAlbum', albumName, photoName, isVideo, true)

	if not photoInfos then return nil, errorCode end 

	return photoInfos.public_share_url
end

---------------------------------------------------------------------------------------------------------
-- getPublicSharedPhotoColorLabel (h, albumName, photoName, isVideo) 
-- returns the color label of a pbulic shared photo
function PSPhotoStationUtils.getPublicSharedPhotoColorLabel(h, albumName, photoName, isVideo)
	local photoInfos, errorCode = PSPhotoStationUtils.getPhotoInfoFromList(h, 'publicSharedAlbum', albumName, photoName, isVideo, true)

	if not photoInfos then return nil, errorCode end 

	return photoInfos.info.color_label
end


---------------------------------------------------------------------------------------------------------
-- createAndAddPhotoTag (h, dstFilename, isVideo, type, name, addinfo) 
-- create and add a new tag (desc,people,geo) to a photo
function PSPhotoStationUtils.createAndAddPhotoTag(h, dstFilename, isVideo, type, name, addinfo)
	local tagId = PSPhotoStationUtils.getTagId(h, type, name)
	if not tagId then 
		tagId = PSPhotoStationAPI.createTag(h, type, name)
		tagMappingUpdate(h, type)
	end
	
	if not tagId then return false end
	
	local photoTagIds, errorCode = PSPhotoStationAPI.addPhotoTag(h, dstFilename, isVideo, type, tagId, addinfo)
	
	if not photoTagIds and errorCode == 467 then
		-- tag was deleted, cache wasn't up to date
		tagId = PSPhotoStationAPI.createTag(h, type, name)
		tagMappingUpdate(h, type)
	 	photoTagIds, errorCode = PSPhotoStationAPI.addPhotoTag(h, dstFilename, isVideo, type, tagId, addinfo)
	end 
	
	-- errorCode 468: duplicate tag (tag already there)
	if not photoTagIds and errorCode ~= 468 then return false end
	
	writeLogfile(3, string.format("createAndAddPhotoTag('%s', '%s', '%s') returns OK.\n", dstFilename, type, name))
	return true	
end

---------------------------------------------------------------------------------------------------------
-- createAndAddPhotoTagList (h, dstFilename, isVideo, type, tagList, addinfoList) 
-- create and add a list of new tags (general,people,geo) to a photo
function PSPhotoStationUtils.createAndAddPhotoTagList(h, dstFilename, isVideo, type, tagList, addinfoList)

	for i = 1, #tagList do
		if 	(	 addinfoList and not PSPhotoStationUtils.createAndAddPhotoTag(h, dstFilename, isVideo, type, tagList[i], addinfoList[i])) or
			(not addinfoList and not PSPhotoStationUtils.createAndAddPhotoTag(h, dstFilename, isVideo, type, tagList[i]))
		then
			return false
		end
	end

	writeLogfile(3, string.format("createAndAddPhotoTagList('%s', %d tags of type '%s') returns OK.\n", dstFilename, #tagList, type))
	return true	
end

---------------------------------------------------------------------------------------------------------
-- removePhotoTagList (h, dstFilename, isVideo, type, tagList) 
-- remove a list of tags of type (general,people,geo) from a photo
function PSPhotoStationUtils.removePhotoTagList(h, dstFilename, isVideo, type, tagList)
	
	for i = 1, #tagList do
		if not PSPhotoStationAPI.removePhotoTag(h, dstFilename, isVideo, type, tagList[i]) then
			return false
		end
	end
	 
	writeLogfile(3, string.format("removePhotoTagList(%s, %d tags of type '%s') returns OK.\n", dstFilename, #tagList, type))
	return true	
end

PSPhotoStationUtils.colorMapping = {
	[1] = 'red',
	[2] = 'yellow',
	[3] = 'green',
	[4] = 'none',
	[5] = 'blue',
	[6] = 'purple'
}

---------------------------------------------------------------------------------------------------------
-- createSharedAlbum(h, sharedAlbumParams, useExisting) 
-- create a Shared Album and add a list of photos to it
-- returns success and share-link (if public)
function PSPhotoStationUtils.createSharedAlbum(h, sharedAlbumParams, useExisting)
	local sharedAlbumInfo = PSPhotoStationUtils.getSharedAlbumInfo(h, sharedAlbumParams.sharedAlbumName, false)
	local isNewSharedAlbum
	local sharedAlbumAttributes = {}
	
	if sharedAlbumInfo and not useExisting then
		writeLogfile(3, string.format('createSharedAlbum(%s, useExisting %s): returns error: Album already exists!\n', 
									sharedAlbumParams.sharedAlbumName, tostring(useExisting)))
		return nil, 414
	end
	
	if not sharedAlbumInfo then 
		local sharedAlbumId, errorCode = PSPhotoStationAPI.createSharedAlbum(h, sharedAlbumParams.sharedAlbumName)
		
		if not sharedAlbumId then return nil, errorCode end
		
		sharedAlbumInfo = PSPhotoStationUtils.getSharedAlbumInfo(h, sharedAlbumParams.sharedAlbumName, false)
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

	writeTableLogfile(3, "PSPhotoStationUtils.createSharedAlbum: sharedAlbumParams", sharedAlbumParams, true, '^password')
	local shareResult, errorCode = PSPhotoStationAPI.editSharedAlbum(h, sharedAlbumParams.sharedAlbumName, sharedAlbumAttributes) 

	if not shareResult then return nil, errorCode end
	
	return shareResult
end
---------------------------------------------------------------------------------------------------------
-- createAndAddPhotosToSharedAlbum(h, sharedAlbumParams, photos) 
-- create a Shared Album and add a list of photos to it
-- returns success and share-link (if public)
function PSPhotoStationUtils.createAndAddPhotosToSharedAlbum(h, sharedAlbumParams, photos)
	local shareResult = PSPhotoStationUtils.createSharedAlbum(h, sharedAlbumParams, true)
	 
	if 		not shareResult 
		or	not PSPhotoStationAPI.addPhotosToSharedAlbum(h, sharedAlbumParams.sharedAlbumName, photos) 
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
function PSPhotoStationUtils.removePhotosFromSharedAlbum(h, sharedAlbumName, photos)
	local sharedAlbumInfo = sharedAlbumsCacheFind(h, sharedAlbumName)
	
	if not sharedAlbumInfo then 
		writeLogfile(3, string.format('removePhotosFromSharedAlbum(%s, %d photos): Shared album not found, returning OK.\n', sharedAlbumName, #photos))
		return true
	end
	
	local success, errorCode = PSPhotoStationAPI.removePhotosFromSharedAlbum(h, sharedAlbumName, photos)
	
	if not success and errorCode == 555 then
		-- shared album was deleted, mapping wasn't up to date
		sharedAlbumsCacheUpdate(h)
		writeLogfile(3, string.format('removePhotosFromSharedAlbum(%s, %d photos): Shared album already deleted, returning OK.\n', sharedAlbumName, #photos))
		return true
	end 
	
	if not success then return false end 
	
	return true	
end

---------------------------------------------------------------------------------------------------------
-- deleteEmptyAlbumAndParents(h, albumPath)
-- delete an album and all its parents as long as they are empty
-- return count of deleted albums
function PSPhotoStationUtils.deleteEmptyAlbumAndParents(h, albumPath)
	local nDeletedAlbums = 0
	local currentAlbumPath
	
	currentAlbumPath = albumPath
	while currentAlbumPath do
		local photoInfos, errorCode =  PSPhotoStationAPI.listAlbum(h, currentAlbumPath, 'photo,video,album')

    	-- if not existing or not empty or delete fails, we are ready
    	if 		not photoInfos 
    		or 	#photoInfos > 0 
    		or not PSPhotoStationAPI.deleteAlbum (h, currentAlbumPath) 
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

---------------------------------------------------------------------------------------------------------
-- rating2Stars (h, dstFilename, isVideo, field, value) 
function PSPhotoStationUtils.rating2Stars(rating)
	return string.rep ('*', rating)
end
