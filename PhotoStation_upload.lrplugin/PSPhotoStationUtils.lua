--[[----------------------------------------------------------------------------

PSPhotoStationUtils.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2017, Martin Messmer

Photo Station utilities:
	- getErrorMsg

	- getAlbumId
	- getPhotoId
	- getSharedAlbumId
	
	- getAlbumUrl
	- getPhotoUrl

	- getPhotoInfo
	
	- createAndAddPhotoTag
	- createAndAddPhotoTagList

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
	[100] = 'Unknown error ',
    [101] = 'No parameter of API, method or version',		-- PS 6.6: no such directory 
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
		if 	errorCode ~= 408  	-- no such file or dir
		and errorCode ~= 417	-- no such dir for non-administrative users , see GitHub issue 17
		and errorCode ~= 101	-- no such dir in PS 6.6
		then
			writeLogfile(2, string.format('albumCacheList: Error on listAlbum: %d\n', errorCode))
		   	return nil, errorCode
		end
		albumItems = {} -- avoid re-requesting non-existing album 
	end
	
	local cacheEntry = {}
	cacheEntry.albumPath = dstDir
	cacheEntry.albumItems = albumItems
	cacheEntry.validUntil = LrDate.currentTime() + albumCacheTimeout
	table.insert(albumCache, 1, cacheEntry)
	
	writeLogfile(3, string.format("albumCacheList(%s): added to cache with %d items\n", dstDir, #albumItems))
	
	return albumItems
end

-- ===================================== Shared Album cache ==============================================
-- the Shared Album cache holds the list of shared album infos

local sharedAlbumCache 				= {}
local sharedAlbumCacheTimeout 		= 60	-- 60 seconds cache time
local sharedAlbumCacheValidUntil
 
---------------------------------------------------------------------------------------------------------
-- sharedAlbumCacheCleanup: cleanup cache if cache is too old
local function sharedAlbumCacheCleanup()
	if ifnil(sharedAlbumCacheValidUntil, LrDate.currentTime()) <= LrDate.currentTime() then
		sharedAlbumCache = {}
	end
	return true
end

---------------------------------------------------------------------------------------------------------
-- sharedAlbumCacheUpdate(h) 
local function sharedAlbumCacheUpdate(h)
	writeLogfile(3, string.format('sharedAlbumCacheUpdate().\n'))
	sharedAlbumCache = PSPhotoStationAPI.getSharedAlbums(h)
	sharedAlbumCacheValidUntil = LrDate.currentTime() + sharedAlbumCacheTimeout
	return sharedAlbumCache
end

---------------------------------------------------------------------------------------------------------
-- sharedAlbumCacheFind(h, name) 
local function sharedAlbumCacheFind(h, name)
	sharedAlbumCacheCleanup()
	if (#sharedAlbumCache == 0) and not sharedAlbumCacheUpdate(h) then
		return nil 
	end
	
	for i = 1, #sharedAlbumCache do
		if sharedAlbumCache[i].name == name then 
			writeLogfile(4, string.format('sharedAlbumCacheFind(%s) found  %s.\n', name, sharedAlbumCache[i].id))
			return sharedAlbumCache[i] 
		end
	end

	writeLogfile(3, string.format('sharedAlbumCacheFind(%s) not found.\n', name))
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

--[[ 
PSPhotoStationUtils.getSharedAlbumId(h, sharedAlbumName)
	returns the shareId of a given SharedAlbum using the Shared Album cache
]]
function PSPhotoStationUtils.getSharedAlbumShareId(h, sharedAlbumName)
	local sharedAlbumInfo = sharedAlbumCacheFind(h, sharedAlbumName)
	
	if not sharedAlbumInfo then 
		writeLogfile(3, string.format('getSharedAlbumId(%s): Shared album not found.\n', sharedAlbumName))
		return nil
	end
	if not sharedAlbumInfo.additional or not sharedAlbumInfo.additional.public_share or sharedAlbumInfo.additional.public_share.share_status ~= 'valid' then 
		return nil
	end

	return sharedAlbumInfo.additional.public_share.shareid
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
-- getPhotoInfo (h, dstFilename, isVideo, useCache) 
-- return photo infos for a given remote filename
-- returns:
-- 		photoInfo, 	photoAdditionalInfo		if remote photo was found
-- 		nil,		nil						if remote photo was not found
-- 		nil,		errorCode				on error
function PSPhotoStationUtils.getPhotoInfo(h, dstFilename, isVideo, useCache)
	local dstAlbum = ifnil(string.match(dstFilename , '(.*)\/[^\/]+'), '/')
	local photoInfos, errorCode
	if useCache then
		photoInfos, errorCode=  albumCacheList(h, dstAlbum, 'photo,video')
	else
		photoInfos, errorCode=  PSPhotoStationAPI.listAlbum(h, dstAlbum, 'photo,video')
	end
	
	if not photoInfos then return nil, errorCode end 

	local photoId = PSPhotoStationUtils.getPhotoId(dstFilename, isVideo)
	for i = 1, #photoInfos do
		if photoInfos[i].id == photoId then
			writeLogfile(3, string.format('getPhotoInfo(%s, useCache %s) found infos.\n', dstFilename, useCache))
			return photoInfos[i].info, photoInfos[i].additional
		end
	end
	
	writeLogfile(3, string.format('getPhotoInfo(%s, useCache %s) found no infos.\n', dstFilename, useCache))
	return nil, nil
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
-- createAndAddPhotosToSharedAlbum(h, sharedAlbumName,  mkSharedAlbumAdvanced, mkSharedAlbumPublic, sharedAlbumPassword, photos) 
-- create a Shared Album and add a list of photos to it
-- returns success, sharedAlbumId and share-link (if public)
function PSPhotoStationUtils.createAndAddPhotosToSharedAlbum(h, sharedAlbumName,  mkSharedAlbumAdvanced, mkSharedAlbumPublic, sharedAlbumPassword, photos)
	local sharedAlbumInfo = sharedAlbumCacheFind(h, sharedAlbumName)
	local isNewSharedAlbum
	local sharedAlbumId
	local sharedAlbumAttributes = {}
	local shareResult
	
	if not sharedAlbumInfo then 
		sharedAlbumId = PSPhotoStationAPI.createSharedAlbum(h, sharedAlbumName)
		sharedAlbumCacheUpdate(h)
		sharedAlbumInfo = sharedAlbumCacheFind(h, sharedAlbumName)
		isNewSharedAlbum = true
	end
	
	if not sharedAlbumInfo then return false end
	sharedAlbumId = sharedAlbumInfo.id 
	
	local photoIds = {}
	for i = 1, #photos do
		photoIds[i] = PSPhotoStationUtils.getPhotoId(photos[i].dstFilename, photos[i].isVideo)
	end
	
	local success, errorCode = PSPhotoStationAPI.addPhotosToSharedAlbum(h, sharedAlbumId, photoIds)
	
	if not success and errorCode == 555 then
		-- shared album was deleted, mapping wasn't up to date
		sharedAlbumId = PSPhotoStationAPI.createSharedAlbum(h, sharedAlbumName)
		if not sharedAlbumId then return false end
		sharedAlbumCacheUpdate(h)
		sharedAlbumInfo = sharedAlbumCacheFind(h, sharedAlbumName)
		isNewSharedAlbum = true
	 	success, errorCode = PSPhotoStationAPI.addPhotosToSharedAlbum(h, sharedAlbumId, photoIds)
	end 
	
	if not success then return false end 
	
	sharedAlbumAttributes.is_shared = mkSharedAlbumPublic
	
	--preserve old share start/time end restriction if album was and will be public
	if		mkSharedAlbumPublic 	
		and not isNewSharedAlbum 
		and sharedAlbumInfo 
		and sharedAlbumInfo.additional 
		and sharedAlbumInfo.additional.public_share 
		and sharedAlbumInfo.additional.public_share.share_status == 'valid' 
	then
		sharedAlbumAttributes.start_time 	= sharedAlbumInfo.additional.public_share.start_time
		sharedAlbumAttributes.end_time 		= sharedAlbumInfo.additional.public_share.end_time
	end
		
	if mkSharedAlbumAdvanced then
		sharedAlbumAttributes.is_advanced = true
		
		if sharedAlbumPassword then
			sharedAlbumAttributes.enable_password = true
			sharedAlbumAttributes.password = sharedAlbumPassword
		else
			sharedAlbumAttributes.enable_password = false
		end

		if isNewSharedAlbum then
    		-- a lot of default parameters ...
    		sharedAlbumAttributes.enable_marquee_tool	= true
    		sharedAlbumAttributes.enable_comment 		= true
    		sharedAlbumAttributes.enable_color_label	= true
    		sharedAlbumAttributes.color_label_1 		= "red"
    		sharedAlbumAttributes.color_label_2 		= "orange"
    		sharedAlbumAttributes.color_label_3 		= "lime green"
    		sharedAlbumAttributes.color_label_4 		= "aqua green"
    		sharedAlbumAttributes.color_label_5 		= "blue"
    		sharedAlbumAttributes.color_label_6 		= "purple"
		else
			--preserve old advcanced settings for already existing Shared Albums
			if sharedAlbumInfo and sharedAlbumInfo.additional and sharedAlbumInfo.additional.public_share and sharedAlbumInfo.additional.public_share.advanced_info then
				local advancedInfo = sharedAlbumInfo.additional.public_share.advanced_info
				
        		sharedAlbumAttributes.enable_marquee_tool	= advancedInfo.enable_marquee_tool
        		sharedAlbumAttributes.enable_comment 		= advancedInfo.enable_comment
        		sharedAlbumAttributes.enable_color_label 	= advancedInfo.enable_color_label
        		sharedAlbumAttributes.color_label_1 		= advancedInfo.color_label_1
        		sharedAlbumAttributes.color_label_2 		= advancedInfo.color_label_2
        		sharedAlbumAttributes.color_label_3 		= advancedInfo.color_label_3
        		sharedAlbumAttributes.color_label_4 		= advancedInfo.color_label_4
        		sharedAlbumAttributes.color_label_5 		= advancedInfo.color_label_5
        		sharedAlbumAttributes.color_label_6 		= advancedInfo.color_label_6
			end
		end
	end

	shareResult = PSPhotoStationAPI.editSharedAlbum(h, sharedAlbumId, sharedAlbumAttributes) 

	if not shareResult then  return false end
	
	writeLogfile(3, string.format('createAndAddPhotosToSharedAlbum(%s, %s, %s, pw: %s, %d photos) returns OK.\n', sharedAlbumName, iif(mkSharedAlbumAdvanced, 'advanced', 'old'), iif(mkSharedAlbumPublic, 'public', 'private'), iif(sharedAlbumPassword, 'w/ passwd', 'w/o passwd'), #photos))
	return true, sharedAlbumId, shareResult.public_share_url	
end

---------------------------------------------------------------------------------------------------------
-- removePhotosFromSharedAlbum(h, sharedAlbumName, photos) 
-- remove a a list of photos from a Shared Album
function PSPhotoStationUtils.removePhotosFromSharedAlbum(h, sharedAlbumName, photos)
	local sharedAlbumInfo = sharedAlbumCacheFind(h, sharedAlbumName)
	local sharedAlbumId
	
	if not sharedAlbumInfo then 
		writeLogfile(3, string.format('removePhotosFromSharedAlbum(%s, %d photos): Shared album not found, returning OK.\n', sharedAlbumName, #photos))
		return true
	end
	sharedAlbumId = sharedAlbumInfo.id
	
	local photoIds = {}
	for i = 1, #photos do
		photoIds[i] = PSPhotoStationUtils.getPhotoId(photos[i].dstFilename, photos[i].isVideo)
	end
	
	local success, errorCode = PSPhotoStationAPI.removePhotosFromSharedAlbum(h, sharedAlbumId, photoIds)
	
	if not success and errorCode == 555 then
		-- shared album was deleted, mapping wasn't up to date
		sharedAlbumCacheUpdate(h)
		writeLogfile(3, string.format('removePhotosFromSharedAlbum(%s, %d photos): Shared album already deleted, returning OK.\n', sharedAlbumName, #photos))
		return true
	end 
	
	if not success then return false end 
	
	writeLogfile(3, string.format('removePhotosFromSharedAlbum(%s, %d photos) returns OK.\n', sharedAlbumName, #photos))
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
		currentAlbumPath = string.match(currentAlbumPath , '(.+)\/[^\/]+')
	end
	
	return nDeletedAlbums 
end

---------------------------------------------------------------------------------------------------------
-- rating2Stars (h, dstFilename, isVideo, field, value) 
function PSPhotoStationUtils.rating2Stars(rating)
	return string.rep ('*', rating)
end
