--[[----------------------------------------------------------------------------

PSPhotoStationUtils.lua
Photo Station utilities:
	- getErrorMsg

	- getAlbumId
	- getPhotoId
	
	- getAlbumUrl
	- getPhotoUrl

	- existsPic
	- getPhotoInfo
	
	- createAndAddPhotoTag
	- createAndAddPhotoTagList

	- createAndAddPhotosToSharedAlbum
	- removePhotosFromSharedAlbum
	
	- removePhotosFromSharedAlbum
	
	- rating2Stars
	
	
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
	[100] = 'Unknown error ',
    [101] = 'No parameter of API, method or version',
    [102] = 'The requested API does not exist',
    [103] = 'The requested method does not exist',
    [104] = 'The requested version does not support the functionality',
    [105] = 'The logged in session does not have permission',
    [106] = 'Session timeout',
    [107] = 'Session interrupted by duplicate login',
	[400] = 'Invalid parameter',
	[401] = 'Unknown error of file operation',
	[402] = 'System is too busy',
	[403] = 'Invalid user does this file operation',
	[404] = 'Invalid group does this file operation',
	[405] = 'Invalid user and group does this file operation',
	[406] = 'Can’t get user/group information from the account server',
	[407] = 'Operation not permitted',
	[408] = 'No such file or directory',
	[409] = 'Non-supported file system',
	[410] = 'Failed to connect internet-based file system (ex: CIFS)',
	[411] = 'Read-only file system',
	[412] = 'Filename too long in the non-encrypted file system',
	[413] = 'Filename too long in the encrypted file system',
	[414] = 'File already exists',
	[415] = 'Disk quota exceeded',
	[416] = 'No space left on device',
	[417] = 'Input/output error',
	[418] = 'Illegal name or path',
	[419] = 'Illegal file name',
	[420] = 'Illegal file name on FAT filesystem',
	[421] = 'Device or resource busy',
	[467] = 'No such tag',
	[468] = 'Duplicate tag',
	[470] = 'No such file',
	[555] = 'No such shared album',
	[599] = 'No such task of the file operation',
	[1001]  = 'Http error: no response body, no response header',
	[1002]  = 'Http error: no response data, no errorcode in response header',
	[1003]  = 'Http error: No JSON response data',
	[12007] = 'Http error: cannotFindHost',
	[12029] = 'Http error: cannotConnectToHost',
	[12038] = 'Http error: serverCertificateHasUnknownRoot',
}

-- ========================================== Album cache ==============================================
-- the Album cache holds Album lists for the least recently read albums

local albumCache = {}
local albumCacheTimeout = 60	-- 60 seconds cache time
 
---------------------------------------------------------------------------------------------------------
-- albumCacheCleanup: remove old entries from cache
local function albumCacheCleanup()
	for i = #albumCache, 1, -1 do
		local cachedAlbum = albumCache[i]
		if cachedAlbum.validUntil < LrDate.currentTime() then 
			writeLogfile(3, string.format("albumCacheCleanup(); removing %s\n", cachedAlbum.albumPath))
			table.remove(albumCache, i)
		end
	end
end

---------------------------------------------------------------------------------------------------------
-- albumCacheList: returns all photos/videos and optionally albums in a given album via album cache
-- returns
--		albumItems:		table of photo infos, if success, otherwise nil
--		errorcode:		errorcode, if not success
local function albumCacheList(h, dstDir, listItems)
	albumCacheCleanup()
	
	for i = 1, #albumCache do
		local cachedAlbum = albumCache[i]
		if cachedAlbum.albumPath == dstDir then 
			return cachedAlbum.albumItems
		end
	end
	
	-- not found in cache: get it from Photo Station
	local albumItems, errorCode = PSPhotoStationAPI.listAlbum(h, dstDir, listItems)
	if not albumItems then
		writeLogfile(2, string.format('albumCacheList: Error on listAlbum: %d\n', errorCode))
	   	return nil, errorCode
	end
	
	local cacheEntry = {}
	cacheEntry.albumPath = dstDir
	cacheEntry.albumItems = albumItems
	cacheEntry.validUntil = LrDate.currentTime() + albumCacheTimeout
	table.insert(albumCache, 1, cacheEntry)
	
	writeLogfile(3, string.format("albumCacheList(%s): added to cache\n", dstDir))
	
	return albumItems
end

-- ===================================== sharedAlbumMapping ==============================================
-- the Shared Album mapping holds the list of album name / album id mappings

local sharedAlbumMapping = {}
 
---------------------------------------------------------------------------------------------------------
-- sharedAlbumMappingUpdate(h) 
local function sharedAlbumMappingUpdate(h)
	writeLogfile(3, string.format('sharedAlbumMappingUpdate().\n'))
	sharedAlbumMapping = PSPhotoStationAPI.getSharedAlbums(h)
	return sharedAlbumMapping
end

---------------------------------------------------------------------------------------------------------
-- sharedAlbumMappingFind(h, name) 
local function sharedAlbumMappingFind(h, name)
	if (#sharedAlbumMapping == 0) and not sharedAlbumMappingUpdate(h) then
		return nil 
	end
	
	for i = 1, #sharedAlbumMapping do
		if sharedAlbumMapping[i].name == name then 
			writeLogfile(3, string.format('sharedAlbumMappingFind(%s) found  %s.\n', name, sharedAlbumMapping[i].id))
			return sharedAlbumMapping[i].id 
		end
	end

	writeLogfile(3, string.format('sharedAlbumMappingFind(%s) not found.\n', name))
	return nil
end

-- ======================================= tagMapping ==============================================
-- the tagMapping holds the list of tag name / tag id mappings

local tagMapping = {
	['desc']	= {},
	['person']	= {},
	['geo']		= {},
}

---------------------------------------------------------------------------------------------------------
-- tagMappingUpdate(h, type) 
local function tagMappingUpdate(h, type)
	writeLogfile(3, string.format('tagMappingUpdate(%s).\n', type))
	tagMapping[type] = PSPhotoStationAPI.getTags(h, type)
	return tagMapping[type]
end

---------------------------------------------------------------------------------------------------------
-- tagMappingFind(h, type, name) 
local function tagMappingFind(h, type, name)
	local tagsOfType = tagMapping[type]

	if (#tagsOfType == 0) and not tagMappingUpdate(h, type) then
		return nil 
	end
	tagsOfType = tagMapping[type]
	
	for i = 1, #tagsOfType do
		if tagsOfType[i].name == name then 
			writeLogfile(3, string.format('tagMappingFind(%s, %s) found  %s.\n', type, name, tagsOfType[i].id))
			return tagsOfType[i].id 
		end
	end

	writeLogfile(3, string.format('tagMappingFind(%s, %s) not found.\n', type, name))
	return nil
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


--[[ 
PSPhotoStationUtils.getAlbumId(albumPath)
	returns the AlbumId of a given Album path (not leading and trailing slashes) in Photo Station
	AlbumId looks like:
	album_<AlbumPathInHex>
	E.g. Album Path:
		Albums-->Test/2007
	yields AlbumId:
		album_546573742f32303037
]]
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

--[[ 
getPhotoId(photoPath, isVideo)
	returns the PhotoId of a given photo path in Photo Station
	PhotoId looks like:
		photo_<AlbumPathInHex>_<PhotoPathInHex> or 
		video_<AlbumPathInHex>_<PhotoPathInHex> or
	E.g. Photo Path:
		Albums --> Test/2007/2007_08_13_IMG_7415.JPG
	yields PhotoId:
		photo_546573742f32303037_323030375f30385f31335f494d475f373431352e4a5047
]]
function PSPhotoStationUtils.getPhotoId(photoPath, isVideo)
	local i
	local photoDir, photoFilename = string.match(photoPath , '(.*)\/([^\/]+)')
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
	
	local albumDir, _ = string.match(photoPath, '(.+)\/([^\/]+)')
	
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
-- existsPic(dstFilename, isVideo) - check if a photo exists in Photo Station
-- 	returns true, if filename 	
function PSPhotoStationUtils.existsPic(h, dstFilename, isVideo)
	local _, _, dstDir = string.find(dstFilename, '(.*)\/', 1, false)
	dstDir = ifnil(dstDir, '') 
	writeLogfile(4, string.format('existsPic: dstFilename %s --> dstDir %s\n', dstFilename, dstDir))
	
	local albumItems, errorCode = albumCacheList(h, dstDir, 'photo,video')
	if not albumItems and errorCode ~= 408 then -- 408: no such file or dir
		writeLogfile(3, string.format('existsPic: Error on listAlbum: %d\n', errorCode))
	   	return 'error'
	end

	for i = 1, #albumItems do
		if albumItems[i].id == PSPhotoStationUtils.getPhotoId(dstFilename, isVideo) then return 'yes' end
	end
	
	return 'no'
end

---------------------------------------------------------------------------------------------------------
-- getPhotoInfo (h, dstFilename, isVideo, useCache) 
-- photo infos are returned in the respective album
function PSPhotoStationUtils.getPhotoInfo(h, dstFilename, isVideo, useCache)
	local dstAlbum = ifnil(string.match(dstFilename , '(.*)\/[^\/]+'), '/')
	local photoInfos, errorCode
	if useCache then
		photoInfos, errorCode=  albumCacheList(h, dstAlbum, 'photo,video')
	else
		photoInfos, errorCode=  PSPhotoStationAPI.listAlbum(h, dstAlbum, 'photo,video')
	end
	
	if not photoInfos then return false, errorCode end 

	local photoId = PSPhotoStationUtils.getPhotoId(dstFilename, isVideo)
	for i = 1, #photoInfos do
		if photoInfos[i].id == photoId then
			writeLogfile(3, string.format('getPhotoInfo(%s, useCache %s) found infos.\n', dstFilename, useCache))
			return photoInfos[i].info, photoInfos[i].additional
		end
	end
	
	writeLogfile(3, string.format('getPhotoInfo(%s, useCache %s) found no infos.\n', dstFilename, useCache))
	return nil
end

---------------------------------------------------------------------------------------------------------
-- createAndAddPhotoTag (h, dstFilename, isVideo, type, name) 
-- create and add a new tag (desc,people,geo) to a photo
function PSPhotoStationUtils.createAndAddPhotoTag(h, dstFilename, isVideo, type, name)
	local tagId = tagMappingFind(h, type, name)
	if not tagId then 
		tagId = PSPhotoStationAPI.createTag(h, type, name)
		tagMappingUpdate(h, type)
	end
		
	
	if not tagId then return false end
	
	local photoTagIds, errorCode = PSPhotoStationAPI.addPhotoTag(h, dstFilename, isVideo, type, tagId)
	
	if not photoTagIds and errorCode == 467 then
		-- tag was deleted, cache wasn't up to date
		tagId = PSPhotoStationAPI.createTag(h, type, name)
		tagMappingUpdate(h, type)
	 	photoTagIds, errorCode = PSPhotoStationAPI.addPhotoTag(h, dstFilename, isVideo, type, tagId)
	end 
	
	-- errorCode 468: duplicate tag (tag already there)
	if not photoTagIds and errorCode ~= 468 then return false end
	
	writeLogfile(3, string.format('createAndAddPhotoTag(%s, %s, %s) returns OK.\n', dstFilename, type, name))
	return true	
end

---------------------------------------------------------------------------------------------------------
-- createAndAddPhotoTagList (h, dstFilename, isVideo, type, tagList) 
-- create and add a list of new tags (general,people,geo) to a photo
function PSPhotoStationUtils.createAndAddPhotoTagList(h, dstFilename, isVideo, type, tagList)
	
	for i = 1, #tagList do
		if not PSPhotoStationUtils.createAndAddPhotoTag(h, dstFilename, isVideo, type, tagList[i]) then
			return false
		end
	end
	 
	writeLogfile(3, string.format('createAndAddPhotoTagList(%s) returns OK.\n', dstFilename))
	return true	
end

---------------------------------------------------------------------------------------------------------
-- createAndAddPhotosToSharedAlbum(h, sharedAlbumName, mkSharedAlbumPublic, photos) 
-- create a Shared Album and add a list of photos to it
function PSPhotoStationUtils.createAndAddPhotosToSharedAlbum(h, sharedAlbumName,  mkSharedAlbumPublic, photos)
	local sharedAlbumId = sharedAlbumMappingFind(h, sharedAlbumName)
	local shareResult
	if not sharedAlbumId then 
		sharedAlbumId = PSPhotoStationAPI.createSharedAlbum(h, sharedAlbumName)
		sharedAlbumMappingUpdate(h)
	end
	
	local photoIds = {}
	for i = 1, #photos do
		photoIds[i] = PSPhotoStationUtils.getPhotoId(photos[i].dstFilename, photos[i].isVideo)
	end
	
	if not sharedAlbumId then return false end
	
	local success, errorCode = PSPhotoStationAPI.addPhotosToSharedAlbum(h, sharedAlbumId, photoIds)
	
	if not success and errorCode == 555 then
		-- shared album was deleted, mapping wasn't up to date
		sharedAlbumId = PSPhotoStationAPI.createSharedAlbum(h, sharedAlbumName)
		sharedAlbumMappingUpdate(h)
		if not sharedAlbumId then return false end
	 	success, errorCode = PSPhotoStationAPI.addPhotosToSharedAlbum(h, sharedAlbumId, photoIds)
	end 
	
	if not success then return false end 
	
	shareResult = PSPhotoStationAPI.makeSharedAlbumPublic(h, sharedAlbumId, mkSharedAlbumPublic) 

	if not shareResult then  return false end
	
	writeLogfile(3, string.format('createAndAddPhotosToSharedAlbum(%s, %s, %d photos) returns OK.\n', sharedAlbumName, iif(mkSharedAlbumPublic, 'public', 'private'), #photos))
	return true, shareResult.public_share_url	
end

---------------------------------------------------------------------------------------------------------
-- removePhotosFromSharedAlbum(h, sharedAlbumName, photos) 
-- remove a a list of photos from a Shared Album
function PSPhotoStationUtils.removePhotosFromSharedAlbum(h, sharedAlbumName, photos)
	local sharedAlbumId = sharedAlbumMappingFind(h, sharedAlbumName)
	if not sharedAlbumId then 
		writeLogfile(3, string.format('removePhotosFromSharedAlbum(%s, %d photos): Shared album not found, returning OK.\n', sharedAlbumName, #photos))
		return true
	end
	
	local photoIds = {}
	for i = 1, #photos do
		photoIds[i] = PSPhotoStationUtils.getPhotoId(photos[i].dstFilename, photos[i].isVideo)
	end
	
	local success, errorCode = PSPhotoStationAPI.removePhotosFromSharedAlbum(h, sharedAlbumId, photoIds)
	
	if not success and errorCode == 555 then
		-- shared album was deleted, mapping wasn't up to date
		sharedAlbumMappingUpdate(h)
		writeLogfile(3, string.format('removePhotosFromSharedAlbum(%s, %d photos): Shared album already deleted, returning OK.\n', sharedAlbumName, #photos))
		return true
	end 
	
	if not success then return false end 
	
	writeLogfile(3, string.format('removePhotosFromSharedAlbum(%s, %d photos) returns OK.\n', sharedAlbumName, #photos))
	return true	
end

---------------------------------------------------------------------------------------------------------
-- deleteAllEmptyAlbums (h, albumPath, albumsDeleted, photosLeft) 
-- deletes recursively all empty albums below albumPath.
-- fills albumsDeleted and photosLeft 
-- returns:
-- 		success - the Album itself can be deleted (is empty) 

--[[
function PSPhotoStationUtils.deleteAllEmptyAlbums(h, albumPath, albumsDeleted, photosLeft)
	writeLogfile(3, string.format('deleteEmptyAlbums(%s): starting\n', albumPath))
	
	local albumItems, errorCode = PSPhotoStationAPI.listAlbum(h, albumPath, 'photo,video,album')
	local canDeleteThisAlbum = true
		
	for i = 1, #albumItems do
		local itemPath = albumPath .. '/' .. albumItems[i].info.name
		if albumItems[i].type ~= 'album' then
			table.insert(photosLeft, itemPath) 
			canDeleteThisAlbum = false
		else 
			if PSPhotoStationUtils.deleteAllEmptyAlbums(h, itemPath, albumsDeleted, photosLeft) then
				PSPhotoStationAPI.deleteAlbum (h, itemPath)
				table.insert(albumsDeleted, itemPath) 
			else
				canDeleteThisAlbum = false
			end
		end
	end
	writeLogfile(3, string.format('deleteAllEmptyAlbums(%s): returns canDelete %s\n', albumPath, tostring(canDeleteThisAlbum)))
	return canDeleteThisAlbum
end
]]

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
		currentAlbumPath = string.match(currentAlbumPath , '(.+)\/[^\/]+')
	end
	
	return nDeletedAlbums 
end

---------------------------------------------------------------------------------------------------------
-- rating2Stars (h, dstFilename, isVideo, field, value) 
function PSPhotoStationUtils.rating2Stars(rating)
	return string.rep ('*', rating)
end
