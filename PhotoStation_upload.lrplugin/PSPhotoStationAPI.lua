--[[----------------------------------------------------------------------------

PSPhotoStationAPI.lua
Photo Station Upload primitives:
	- initialize
	- getErrorMsg
	- login
	- logout

	- getAlbumUrl
	- getPhotoUrl

	- listAlbum
	- deletePic
	- existsPic
	- sortPics

	- addPhotoComments
	- getPhotoComments
	
	- getPhotoInfos
	- getPhotoExifs
	
	- getTags
	- getPhotoTags
	
	- editPhoto
	
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
	[599] = 'No such task No such task of the file operation',
	[1001]  = 'Http error: no response body, no response header',
	[1002]  = 'Http error: no response data, no errorcode in response header',
	[1003]  = 'Http error: No JSON response data',
	[12007] = 'Http error: cannotFindHost',
	[12029] = 'Http error: cannotConnectToHost',
	[12038] = 'Http error: serverCertificateHasUnknownRoot',
}

--[[ 
getAlbumId(albumPath)
	returns the AlbumId of a given Album path (not leading and trailing slashes) in Photo Station
	AlbumId looks like:
	album_<AlbumPathInHex>
	E.g. Album Path:
		Albums-->Test/2007
	yields AlbumId:
		album_546573742f32303037
]]
local function getAlbumId(albumPath)
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
local function getPhotoId(photoPath, isVideo)
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
callSynoAPI (h, synoAPI, formData)
	calls the named synoAPI with the respective parameters in formData
	returns nil, on http error
	returns the decoded JSON response as table on success
]]
local function callSynoAPI (h, synoAPI, formData) 
	local postHeaders = {
		{ field = 'Content-Type', value = 'application/x-www-form-urlencoded' },
	}

	local postBody = 'api=' .. synoAPI .. '&' .. formData

	if synoAPI == 'SYNO.PhotoStation.Auth' then
		writeLogfile(4, "callSynoAPI: LrHttp.post(" .. h.serverUrl .. h.psWebAPI .. h.apiInfo[synoAPI].path .. ",...)\n")
	else
		writeLogfile(4, string.format("callSynoAPI: LrHttp.post(%s%s%s, api=%s&%s\n", h.serverUrl, h.psWebAPI, h.apiInfo[synoAPI].path, synoAPI, formData))
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
	writeLogfile(4, "Got Body:\n" .. respBody .. "\n")
	
	local respArray = JSON:decode(respBody)

	if not respArray then return nil, 1003 end 

	if respArray.error then 
		local errorCode = tonumber(respArray.error.code)
		writeLogfile(1, string.format('PSPhotoStationAPI.callSynoAPI: %s returns error %d\n', synoAPI, errorCode))
		return nil, errorCode
	end
	
	return respArray
end

--====== global functions ====================================================--

PSPhotoStationAPI = {}

---------------------------------------------------------------------------------------------------------
-- getErrorMsg(errorCode)
-- translates errorCode to ErrorMsg
function PSPhotoStationAPI.getErrorMsg(errorCode)
	if PSAPIerrorMsgs[errorCode] == nil then
		-- we don't have a documented  message for that code
		return string.format("ErrorCode: %d", errorCode)
	end
	return PSAPIerrorMsgs[errorCode]
end

---------------------------------------------------------------------------------------------------------
-- initialize: set serverUrl, loginPath and uploadPath
function PSPhotoStationAPI.initialize(server, personalPSOwner, serverTimeout)
	local h = {} -- the handle
	local apiInfo = {}
	local psBasePath

	writeLogfile(4, "PSPhotoStationAPI.initialize(serverUrl=" .. server ..", " .. iif(personalPSOwner, "Personal PS(" .. ifnil(personalPSOwner,"<Nil>") .. ")", "Standard PS") .. ")\n")

	h.serverUrl = server
	h.serverTimeout = serverTimeout

	if personalPSOwner then -- connect to Personal Photo Station
		psBasePath = '/~' .. personalPSOwner .. '/photo'
	else
		psBasePath = '/photo'
	end

	h.psAlbumRoot	= 	psBasePath .. '/#!Albums'
	h.psWebAPI 		= 	psBasePath .. '/webapi/'
	h.uploadPath 	=	psBasePath .. '/include/asst_file_upload.php'

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
			 
	local respArray, errorCode = callSynoAPI (h, 'SYNO.API.Info', formData)

	if not respArray then return nil, errorCode end 

	-- rewrite the apiInfo table with API infos retrieved via SYNO.API.Info
	h.apiInfo = respArray.data
-- 	writeTableLogfile(4, 'apiInfo', h.apiInfo)
	
	return h
end

---------------------------------------------------------------------------------------------------------
-- login(h, username, passowrd)
-- does, what it says
function PSPhotoStationAPI.login(h, username, password)
	local formData = 'method=login&' ..
					 'version=1&' .. 
					 'username=' .. urlencode(username) .. '&' .. 
					 'password=' .. urlencode(password)

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Auth', formData)
	
	if not respArray then return false, errorCode end 
	
	return respArray.success
end

---------------------------------------------------------------------------------------------------------

-- logout(h)
-- nothing to do here, invalidating the cookie would be perfect here
function PSPhotoStationAPI.logout (h)
	return true
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
function PSPhotoStationAPI.getAlbumUrl(h, albumPath) 
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
		subDirUrl = getAlbumId(subDirPath) 
		albumUrl = albumUrl .. '/' .. subDirUrl
	end
	
	writeLogfile(3, string.format("PSPhotoStationAPI.getAlbumUrl(%s, %s) returns %s\n", h.serverUrl .. h.psAlbumRoot, albumPath, albumUrl))
	
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
function PSPhotoStationAPI.getPhotoUrl(h, photoPath, isVideo) 
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
		subDirUrl = getAlbumId(subDirPath) 
		photoUrl = photoUrl .. '/' .. subDirUrl
	end
	
	photoUrl = photoUrl .. '/' .. getPhotoId(photoPath, isVideo)
	
	writeLogfile(3, string.format("PSPhotoStationAPI.getPhotoUrl(%s, %s) returns %s\n", h.serverUrl .. h.psAlbumRoot, photoPath, photoUrl))
	
	return photoUrl
end

---------------------------------------------------------------------------------------------------------
-- listAlbum: returns all photos/videos and optionally albums in a given album
-- returns
--		success: 		true, false 
--		errorcode:		errorcode, if not success
--		files:			array of files, if success
function PSPhotoStationAPI.listAlbum(h, dstDir, listItems)
	-- recursive doesn't seem to work
	local formData = 'method=list&' ..
					 'version=1&' .. 
					 'id=' .. getAlbumId(dstDir) .. '&' ..
					 'type=' .. listItems .. '&' ..   
					 'offset=0&' .. 
					 'limit=-1&' ..
					 'recursive=false&'.. 
					 'additional=album_permission'
--					 'additional=album_permission,photo_exif,video_codec,video_quality,thumb_size,file_location'

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Album', formData)
	
	if not respArray then return nil, errorCode end 

	writeTableLogfile(4, 'listAlbum', respArray.data.items)
	return respArray.data.items
end

---------------------------------------------------------------------------------------------------------
-- directory cache for existsPic()
-- one directory will be cached at any time
local psDirInCache = nil 	-- pathname of directory in cache
local psDirCache = nil		-- the directory cache

local function findInCache(filename, isVideo)
	if psDirCache == nil then return false end
	
	for i = 1, #psDirCache do
		if psDirCache[i].id == getPhotoId(filename, isVideo) then return true end
	end
	return false
end

---------------------------------------------------------------------------------------------------------
-- existsPic(dstFilename, isVideo) - check if a photo exists in Photo Station
-- 	- if directory of photo is not in cache, reloads cache w/ directory via listAlbum()
-- 	- searches for filename in a local directory cache (findInCache())
-- 	returns true, if filename 	
function PSPhotoStationAPI.existsPic(h, dstFilename, isVideo)
	local _, _, dstDir = string.find(dstFilename, '(.*)\/', 1, false)
	dstDir = ifnil(dstDir, '') 
	writeLogfile(4, string.format('existsPic: dstFilename %s --> dstDir %s\n', dstFilename, dstDir))
	
	-- check if folder of current photo is in cache
	if dstDir ~= psDirInCache then
		-- if not: refresh cach w/ folder of current photo
		local errorCode
		
		psDirCache, errorCode = PSPhotoStationAPI.listAlbum(h, dstDir, 'photo,video')
		if not psDirCache and errorCode ~= 408 then -- 408: no such file or dir
			writeLogfile(3, string.format('existsPic: Error on listAlbum: %d\n', errorCode))
		   	return 'error'
		end
		psDirInCache = dstDir
	end 
	
	return iif(findInCache(dstFilename, isVideo), 'yes', 'no')
end

---------------------------------------------------------------------------------------------------------
-- deletePic (h, dstFilename) 
function PSPhotoStationAPI.deletePic (h, dstFilename, isVideo) 
	local formData = 'method=delete&' ..
					 'version=1&' .. 
					 'id=' .. getPhotoId(dstFilename, isVideo) .. '&'

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Photo', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('deletePic(%s) returns OK\n', dstFilename))
	return respArray.success
end

---------------------------------------------------------------------------------------------------------
-- deleteAlbum(h, albumPath) 
function PSPhotoStationAPI.deleteAlbum (h, albumPath) 
	local formData = 'method=delete&' ..
					 'version=1&' .. 
					 'id=' .. getAlbumId(albumPath) .. '&'

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Album', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('deleteAlbum(%s) returns OK\n', albumPath))
	return respArray.success
end

---------------------------------------------------------------------------------------------------------
-- sortPics (h, albumPath, sortedPhotos) 
function PSPhotoStationAPI.sortPics (h, albumPath, sortedPhotos) 
	local formData = 'method=arrangeitem&' ..
					 'version=1&' .. 
					 'offset=0&' .. 
					 'limit='.. #sortedPhotos .. '&' .. 
					 'id=' .. getAlbumId(albumPath) .. '&'
	local i, photoPath, item_ids = {}
	
	for i, photoPath in ipairs(sortedPhotos) do
		if i == 1 then
			item_ids = getPhotoId(sortedPhotos[i])
		else
			item_ids = item_ids .. ',' .. getPhotoId(sortedPhotos[i])
		end
	end	
	
	formData = formData .. 'item_id=' .. item_ids
	
	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Album', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('sortPics(%s) returns OK.\n', albumPath))
	return respArray.success
end

---------------------------------------------------------------------------------------------------------
-- addPhotoComment (h, dstFilename, isVideo, comment, username) 
function PSPhotoStationAPI.addPhotoComment (h, dstFilename, isVideo, comment, username) 
	local formData = 'method=create&' ..
					 'version=1&' .. 
					 'id=' .. getPhotoId(dstFilename, isVideo) .. '&' .. 
					 'name=' .. username .. '&' .. 
					 'comment='.. urlencode(comment) 

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Comment', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('addPhotoComment(%s, %s, %s) returns OK.\n', dstFilename, comment, username))
	return respArray.success
end

---------------------------------------------------------------------------------------------------------
-- getPhotoComments (h, dstFilename, isVideo) 
function PSPhotoStationAPI.getPhotoComments (h, dstFilename, isVideo) 
	local formData = 'method=list&' ..
					 'version=1&' .. 
					 'id=' .. getPhotoId(dstFilename, isVideo) 

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Comment', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('getPhotoComments(%s) returns OK.\n', dstFilename))
	return respArray.data.comments
end

---------------------------------------------------------------------------------------------------------
-- getPhotoInfo (h, dstFilename, isVideo) 
-- photo infos are returned in the respective album
function PSPhotoStationAPI.getPhotoInfo(h, dstFilename, isVideo)
	local dstAlbum = ifnil(string.match(dstFilename , '(.*)\/[^\/]+'), '/')
	local photoInfos, errorCode =  PSPhotoStationAPI.listAlbum(h, dstAlbum, 'photo,video')
	
	if not photoInfos then return false, errorCode end 

	local photoId = getPhotoId(dstFilename, isVideo)
	for i = 1, #photoInfos do
		if photoInfos[i].id == photoId then
			writeLogfile(3, string.format('getPhotoInfo(%s) found infos.\n', dstFilename))
			return photoInfos[i].info
		end
	end
	
	writeLogfile(3, string.format('getPhotoInfo(%s) found no infos.\n', dstFilename))
	return nil
end

---------------------------------------------------------------------------------------------------------
-- getPhotoExifs (h, dstFilename, isVideo) 
function PSPhotoStationAPI.getPhotoExifs (h, dstFilename, isVideo) 
	local formData = 'method=getexif&' ..
					 'version=1&' .. 
					 'id=' .. getPhotoId(dstFilename, isVideo) 

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Photo', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('getPhotoExifs(%s) returns %d exifs.\n', dstFilename, respArray.data.total))
	return respArray.data.exifs
end

---------------------------------------------------------------------------------------------------------
-- getTags (h, type) 
-- get table of tagId/tagString mappings or given type: desc, people, geo
function PSPhotoStationAPI.getTags(h, type)
	local formData = 'method=list&' ..
					 'version=1&' .. 
					 'type=' .. type .. '&' .. 
--					 'additional=info&' .. 
					 'offset=0&' ..  
					 'limit=-1' 

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Tag', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('getTags returns %d tags.\n', respArray.data.total))
	return respArray.data.tags
end

---------------------------------------------------------------------------------------------------------
-- createTag (h, type, name) 
-- create a new tagId/tagString mapping of or given type: desc, people, geo
function PSPhotoStationAPI.createTag(h, type, name)
	local formData = 'method=create&' ..
					 'version=1&' .. 
					 'type=' .. type .. '&' .. 
					 'name=' .. urlencode(name) 

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Tag', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('createTag returns tagId %s.\n', respArray.data.id))
	return respArray.data.id
end

---------------------------------------------------------------------------------------------------------
-- getPhotoTags (h, dstFilename, isVideo) 
-- get table of tags (general,people,geo) of a photo
function PSPhotoStationAPI.getPhotoTags(h, dstFilename, isVideo)
	local formData = 'method=list&' ..
					 'version=1&' .. 
					 'type=people,geo,desc&' .. 
					 'additional=info&' ..
					 'id=' .. getPhotoId(dstFilename, isVideo) 

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.PhotoTag', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('getPhotoTags(%s) returns %d tags.\n', dstFilename, #respArray.data.tags))
	return respArray.data.tags
end

---------------------------------------------------------------------------------------------------------
-- addPhotoTag (h, dstFilename, isVideo, tagId) 
-- add a new tag (general,people,geo) to a photo
function PSPhotoStationAPI.addPhotoTag(h, dstFilename, isVideo, type, tagId)
	local formData = 'method=' .. type .. '_tag&' ..
					 'version=1&' .. 
					 'tag_id=' .. tagId .. '&' .. 
					 'id=' .. getPhotoId(dstFilename, isVideo) 

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.PhotoTag', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('addPhotoTag(%s) returns %d item_tag_ids.\n', dstFilename, #respArray.data.item_tag_ids))
	return respArray.data.item_tag_ids
end

---------------------------------------------------------------------------------------------------------
-- createAndAddPhotoTag (h, dstFilename, isVideo, type, name) 
-- create and add a new tag (desc,people,geo) to a photo
function PSPhotoStationAPI.createAndAddPhotoTag(h, dstFilename, isVideo, type, name)
	local tagId = PSPhotoStationAPI.cacheFindTag(h, type, name)
	if not tagId then 
		tagId = PSPhotoStationAPI.createTag(h, type, name)
		PSPhotoStationAPI.cacheUpdateTag(h, type)
	end
		
	
	if not tagId then return false end
	
	local photoTagIds, errorCode = PSPhotoStationAPI.addPhotoTag(h, dstFilename, isVideo, type, tagId)
	
	if not photoTagIds and errorCode == 467 then
		-- tag was deleted, cache wasn't up to date
		tagId = PSPhotoStationAPI.createTag(h, type, name)
		PSPhotoStationAPI.cacheUpdateTag(h, type)
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
function PSPhotoStationAPI.createAndAddPhotoTagList(h, dstFilename, isVideo, type, tagList)
	
	for i = 1, #tagList do
		if not PSPhotoStationAPI.createAndAddPhotoTag(h, dstFilename, isVideo, type, tagList[i]) then
			return false
		end
	end
	 
	writeLogfile(3, string.format('createAndAddPhotoTagList(%s) returns OK.\n', dstFilename))
	return true	
end

---------------------------------------------------------------------------------------------------------
-- editPhoto (h, dstFilename, isVideo, field, value) 
-- edit specific metadata field of a photo
function PSPhotoStationAPI.editPhoto(h, dstFilename, isVideo, field, value)
	local formData = 'method=edit&' ..
					 'version=1&' .. 
					 field .. '=' .. value .. '&' .. 
					 'id=' .. getPhotoId(dstFilename, isVideo) 

	local success, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Photo', formData)
	
	if not success then return false, errorCode end 

	writeLogfile(3, string.format('editPhoto(%s, %s = %s) returns OK.\n', dstFilename, field, value))
	return true
end

---------------------------------------------------------------------------------------------------------
-- rating2Stars (h, dstFilename, isVideo, field, value) 
function PSPhotoStationAPI.rating2Stars(rating)
	return string.rep ('*', rating)
end

-- ======================= Photo Station caching functions ==============================================

local psAllTags = {
	['desc']	= {},
	['person']	= {},
	['geo']		= {},
}

---------------------------------------------------------------------------------------------------------
-- PSPhotoStationAPI.cacheFindTag(h, type, name) 
function PSPhotoStationAPI.cacheFindTag(h, type, name)
	local tagsOfType = psAllTags[type]

	if (#tagsOfType == 0) and not PSPhotoStationAPI.cacheUpdateTag(h, type) then
		return nil 
	end
	tagsOfType = psAllTags[type]
	
	for i = 1, #tagsOfType do
		if tagsOfType[i].name == name then 
			writeLogfile(3, string.format('cacheFindTag(%s, %s) found  %s.\n', type, name, tagsOfType[i].id))
			return tagsOfType[i].id 
		end
	end

	writeLogfile(3, string.format('cacheFindTag(%s, %s) not found.\n', type, name))
	return nil
end

---------------------------------------------------------------------------------------------------------
-- PSPhotoStationAPI.cacheUpdateTag(h, type) 
function PSPhotoStationAPI.cacheUpdateTag(h, type)
	writeLogfile(3, string.format('cacheUpdateTag(%s).\n', type))
	psAllTags[type] = PSPhotoStationAPI.getTags(h, type)
	return psAllTags[type]
end


---------------------------------------------------------------------------------------------------------
-- deleteAllEmptyAlbums (h, albumPath, albumsDeleted, photosLeft) 
-- deletes recursively all empty albums below albumPath.
-- fills albumsDeleted and photosLeft 
-- returns:
-- 		success - the Album itself can be deleted (is empty) 

--[[
function PSPhotoStationAPI.deleteAllEmptyAlbums(h, albumPath, albumsDeleted, photosLeft)
	writeLogfile(3, string.format('deleteEmptyAlbums(%s): starting\n', albumPath))
	
	local albumItems, errorCode = PSPhotoStationAPI.listAlbum(h, albumPath, 'photo,video,album')
	local canDeleteThisAlbum = true
		
	for i = 1, #albumItems do
		local itemPath = albumPath .. '/' .. albumItems[i].info.name
		if albumItems[i].type ~= 'album' then
			table.insert(photosLeft, itemPath) 
			canDeleteThisAlbum = false
		else 
			if PSPhotoStationAPI.deleteAllEmptyAlbums(h, itemPath, albumsDeleted, photosLeft) then
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
-- PhotoStation.deleteEmptyAlbumAndParents(h, albumPath)
-- delete an album and all its parents as long as they are empty
-- return count of deleted albums
function PSPhotoStationAPI.deleteEmptyAlbumAndParents(h, albumPath)
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