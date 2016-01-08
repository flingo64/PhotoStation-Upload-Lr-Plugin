--[[----------------------------------------------------------------------------

PSUploadAPI.lua
PhotoStation Upload primitives:
	- initialize
	- login
	- logout
	- getAlbumUrl
	- getPhotoUrl
	- listPics
	- deletePic
	- existsPic
	- createDir
	- uploadPicFile
Copyright(c) 2015, Martin Messmer

This file is part of PhotoStation Upload - Lightroom plugin.

PhotoStation Upload is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

PhotoStation Upload is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PhotoStation Upload.  If not, see <http://www.gnu.org/licenses/>.

PhotoStation Upload uses the following free software to do its job:
	- convert.exe,			see: http://www.imagemagick.org/
	- ffmpeg.exe, 			see: https://www.ffmpeg.org/
	- qt-faststart.exe, 	see: http://multimedia.cx/eggs/improving-qt-faststart/

]]
--------------------------------------------------------------------------------

-- Lightroom API
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrHttp = import 'LrHttp'
local LrDate = import 'LrDate'

require "PSUtilities"

--====== local functions =====================================================--
--[[ 
getAlbumId(albumPath)
	returns the AlbumId of a given Album path (not leading and trailing slashes) in PhotoStation
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

	for i = 1, string.len(albumPath) do
		albumId = albumId .. string.format('%x', string.byte(albumPath,i))
	end

--	writeLogfile(4, string.format("getAlbumId(%s) returns %s\n", albumPath, albumId))

	return albumId
end

--[[ 
getPhotoId(photoPath, isVideo)
	returns the PhotoId of a given photo path in PhotoStation
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
		photoDir = ''
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
		writeLogfile(4, "callSynoAPI: LrHttp.post(" .. h.serverUrl .. h.psWebAPI .. h.apiInfo[synoAPI].path .. ", " .. formData .. "\n")
	end
	
	local respBody, respHeaders = LrHttp.post(h.serverUrl .. h.psWebAPI .. h.apiInfo[synoAPI].path, postBody, postHeaders, 'POST', h.serverTimeout, string.len(postBody))
	
	if not respBody then
	    writeTableLogfile(3, 'respHeaders', respHeaders)
    	if respHeaders then
      		return nil, 'Error "' .. ifnil(respHeaders["error"].errorCode, 'Unknown') .. '" on http request:\n' .. 
          			trim(ifnil(respHeaders["error"].name, 'Unknown error description'))
    	else
      		return nil, 'Unknown error on http request"'
    	end
	end
	writeLogfile(4, "Got Body:\n" .. respBody .. "\n")
	
  return JSON:decode(respBody)
end

--============================================================================--

PSUploadAPI = {}

-- local stdHttpTimeout = 10

-- !!! don't use local variable for settings that may differ for export sessions!
-- only w/ "reload plug-in on each export", each export task will get its own copy of these variables
--[[
local serverUrl
local loginPath
local uploadPath
]]
---------------------------------------------------------------------------------------------------------

-- initialize: set serverUrl, loginPath and uploadPath
function PSUploadAPI.initialize(server, personalPSOwner, serverTimeout)
	local h = {} -- the handle
	local apiInfo = {}
	local psBasePath

	writeLogfile(4, "PSUploadAPI.initialize(serverUrl=" .. server ..", " .. iif(personalPSOwner, "Personal PS(" .. ifnil(personalPSOwner,"<Nil>") .. ")", "Standard PS") .. ")\n")

	h.serverUrl = server
	h.serverTimeout = serverTimeout

	if personalPSOwner then -- connect to Personal PhotoStation
		psBasePath = '/~' .. personalPSOwner .. '/photo'
	else
		psBasePath = '/photo'
	end

	h.psWebAPI = 	psBasePath .. '/webapi/'
	h.uploadPath =	psBasePath .. '/include/asst_file_upload.php'

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
			 
	local respArray, errorMsg = callSynoAPI (h, 'SYNO.API.Info', formData)

	if not respArray then return nil, errorMsg end 

	if respArray.error then 
		errorCode = respArray.error.code
		writeLogfile(1, string.format('PSUploadAPI.initialize: SYNO.API.Info returns error %\n', errorCode))
		return nil, errorCode
	end
	
	-- rewrite the apiInfo table with API infos retrieved via SYNO.API.Info
	h.apiInfo = respArray.data
	writeTableLogfile(4, 'apiInfo', h.apiInfo)
	
	return h
end
		
---------------------------------------------------------------------------------------------------------

-- login(h, username, passowrd)
-- does, what it says
function PSUploadAPI.login(h, username, password)
	local formData = 'method=login&' ..
					 'version=1&' .. 
					 'username=' .. urlencode(username) .. '&' .. 
					 'password=' .. urlencode(password)

	local respArray, errorMsg = callSynoAPI (h, 'SYNO.PhotoStation.Auth', formData)
	
	if not respArray then return false, errorMsg end 
	
	local errorCode = 0 
	if respArray.error then errorCode = tonumber(respArray.error.code) end
  
  return respArray.success, string.format('Error: %d\n', errorCode)
end

---------------------------------------------------------------------------------------------------------

-- logout(h)
-- nothing to do here, invalidating the cookie would be perfect here
function PSUploadAPI.logout (h)
	return true
end

---------------------------------------------------------------------------------------------------------
--[[ 
getAlbumUrl(psBaseUrl, albumPath)
	returns the URL of an album in the PhotoStation
	URL of an album in PS is:
		http(s)://<PS-Server>/<PSBasedir>/#!Albums/<AlbumId_1rstLevelDir>/<AlbumId_1rstLevelAndSecondLevelDir>/.../AlbumId_1rstToLastLevelDir>
	E.g. Album Path:
		Server: http://diskstation; Standard PhotoStation; Album Breadcrumb: Albums/Test/2007
	yields PS Photo-URL:
		http://diskstation/photo/#!Albums/album_54657374/album_546573742f32303037
]]
function PSUploadAPI.getAlbumUrl(psBaseUrl, albumPath) 
	local i
	local albumUrl
	local subDirPath = ''
	local subDirUrl  = ''
	
	local albumDirname = split(albumPath, '/')
	
	albumUrl = psBaseUrl
	
	for i = 1, #albumDirname do
		if i > 1 then  
			subDirPath = subDirPath .. '/'
		end
		subDirPath = subDirPath .. albumDirname[i]
		subDirUrl = getAlbumId(subDirPath) 
		albumUrl = albumUrl .. '/' .. subDirUrl
	end
	
	writeLogfile(3, string.format("PSUploadAPI.getAlbumUrl(%s, %s) returns %s\n", psBaseUrl, albumPath, albumUrl))
	
	return albumUrl
end

--[[ 
getPhotoUrl(psBaseUrl, photoPath, isVideo)
	returns the URL of a photo/video in the PhotoStation
	URL of a photo in PS is:
		http(s)://<PS-Server>/<PSBasedir>/#!Albums/<AlbumId_1rstLevelDir>/<AlbumId_1rstLevelAndSecondLevelDir>/.../AlbumId_1rstToLastLevelDir>/<PhotoId>
	E.g. Photo Path:
		Server: http://diskstation; Standard PhotoStation; Photo Breadcrumb: Albums/Test/2007/2007_08_13_IMG_7415.JPG
	yields PS Photo-URL:
		http://diskstation/photo/#!Albums/album_54657374/album_546573742f32303037/photo_546573742f32303037_323030375f30385f31335f494d475f373431352e4a5047
]]
function PSUploadAPI.getPhotoUrl(psBaseUrl, photoPath, isVideo) 
	local i
	local subDirPath = ''
	local subDirUrl  = ''
	local photoUrl
	
	local albumDir, _ = string.match(photoPath, '(.+)\/([^\/]+)')
	
	local albumDirname = split(albumDir, '/')
	if not albumDirname then albumDirname = {} end

	photoUrl = psBaseUrl
	
	for i = 1, #albumDirname do
		if i > 1 then  
			subDirPath = subDirPath .. '/'
		end
		subDirPath = subDirPath .. albumDirname[i]
		subDirUrl = getAlbumId(subDirPath) 
		photoUrl = photoUrl .. '/' .. subDirUrl
	end
	
	photoUrl = photoUrl .. '/' .. getPhotoId(photoPath, isVideo)
	
	writeLogfile(3, string.format("PSUploadAPI.getPhotoUrl(%s, %s) returns %s\n", psBaseUrl, photoPath, photoUrl))
	
	return photoUrl
end

---------------------------------------------------------------------------------------------------------
-- listPics: returns all photos/videos in a given album
-- returns
--		success: 		true, false 
--		errorcode:		errorcode, if not success
--		files:			array of files, if success
function PSUploadAPI.listPics(h, dstDir)
	local formData = 'method=list&' ..
					 'version=1&' .. 
					 'id=' .. getAlbumId(dstDir) .. '&' ..
					 'type=photo,video&' ..  
					 'offset=0&' .. 
					 'limit=-1&' ..
					 'recursive=false&'.. 
					 'additional=album_permission,photo_exif,video_codec,video_quality,thumb_size,file_location'

	local respArray, errorMsg = callSynoAPI (h, 'SYNO.PhotoStation.Album', formData)
	
	if not respArray then return false, errorMsg end 
	
	local errorCode = 0 
	if respArray.error then 
		errorCode = tonumber(respArray.error.code)
		writeLogfile(1, string.format('listPics: Error: %d\n', errorCode))
		return false, errorCode, nil
	end
	
	writeTableLogfile(3, 'listPics', respArray.data.items)
	return true, 0, respArray.data.items
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
-- existsPic(dstFilename, isVideo) - check if a photo exists in PhotoStation
-- 	- if directory of photo is not in cache, reloads cache w/ directory via listPics()
-- 	- searches for filename in a local directory cache (findInCache())
-- 	returns true, if filename 	
function PSUploadAPI.existsPic(h, dstFilename, isVideo)
	local _, _, dstDir = string.find(dstFilename, '(.*)\/', 1, false)
--	writeLogfile(4, string.format('existsPic: dstFilename %s --> dstDir %s\n', dstFilename, dstDir))
	
	-- check if folder of current photo is in cache
	if dstDir ~= psDirInCache then
		-- if not: refresh cach w/ folder of current photo
		local success, errorCode
		
		success, errorCode, psDirCache = PSUploadAPI.listPics(h, dstDir)
		if not success and errorCode ~= 408 then -- 408: no such file or dir
			writeLogfile(3, string.format('existsPic: Error on listPics: %d\n', errorCode))
		   	return 'error'
		end
		psDirInCache = dstDir
	end 
	
	return iif(findInCache(dstFilename, isVideo), 'yes', 'no')
end

---------------------------------------------------------------------------------------------------------

-- deletePic (h, dstFilename) 
function PSUploadAPI.deletePic (h, dstFilename, isVideo) 
	local formData = 'method=delete&' ..
					 'version=1&' .. 
					 'id=' .. getPhotoId(dstFilename, isVideo) .. '&'

	local respArray, errorMsg = callSynoAPI (h, 'SYNO.PhotoStation.Photo', formData)
	
	if not respArray then return false, errorMsg end 
	if respArray.error then 
		local errorCode = respArray.error.code 
		writeLogfile(3, string.format('deletePic: Error: %s (%d)\n', ifnil(FSAPIerrorCode[errorCode], 'Unknown error code'), errorCode))
	end

	writeLogfile(3, string.format('deletePic(%s) returns %s\n', dstFilename, tostring(respArray.success)))
	return respArray.success
end

---------------------------------------------------------------------------------------------------------

-- createFolder (h, parentDir, newDir) 
-- parentDir must exit
-- newDir may or may not exist, will be created 
function PSUploadAPI.createFolder (h, parentDir, newDir) 
	local postHeaders = {
		{ field = 'Content-Type',			value = 'application/x-www-form-urlencoded' },
		{ field = 'X-PATH', 				value = urlencode(parentDir) },
		{ field = 'X-DUPLICATE', 			value = 'OVERWRITE' },
		{ field = 'X-ORIG-FNAME', 			value =  urlencode(newDir) }, 
		{ field = 'X-UPLOAD-TYPE',			value = 'FOLDER' },
		{ field = 'X-IS-BATCH-LAST-FILE', 	value = '1' },
	}
	local postBody = ''
	local respBody, respHeaders = LrHttp.post(h.serverUrl .. h.uploadPath, postBody, postHeaders, 'POST', h.serverTimeout, 0)
	
	writeLogfile(4, "createFolder: LrHttp.post(" .. h.serverUrl .. h.uploadPath .. ",...)\n")
	if not respBody then
    writeTableLogfile(3, 'respHeaders', respHeaders)
    if respHeaders then
      return false, 'Error "' .. ifnil(respHeaders["error"].errorCode, 'Unknown') .. '" on http request:\n' .. 
          trim(ifnil(respHeaders["error"].name, 'Unknown error description'))
    else
      return false, 'Unknown error on http request"'
    end
	end
	writeLogfile(4, "Got Body:\n" .. respBody .."\n")

  local respArray = JSON:decode(respBody)
  
  if not respArray.success then
    writeLogfile(3,"createFolder: " .. parentDir .. " / " .. newDir .. " failed: " .. respArray.err_msg .. "!\n")
  end

  return respArray.success, respArray.err_msg
end

---------------------------------------------------------------------------------------------------------

--[[ 
uploadPictureFile(h, srcFilename, srcDateTime, dstDir, dstFilename, picType, mimeType, position) 
upload a single file to PhotoStation
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
function PSUploadAPI.uploadPictureFile(h, srcFilename, srcDateTime, dstDir, dstFilename, picType, mimeType, position) 
	local seqOption
	local datetimeOption
	local retcode,reason
	
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
	local timeout = fileSize / 1250000
	if timeout < 30 then timeout = 30 end
	
	writeLogfile(3, string.format("uploadPictureFile: %s dstDir %s dstFn %s type %s pos %s size %d --> timeout %d\n", 
								srcFilename, dstDir, dstFilename, picType, position, fileSize, timeout))
	writeLogfile(4, "uploadPictureFile: LrHttp.post(" .. h.serverUrl .. h.uploadPath .. ", timeout: " .. timeout .. ", fileSize: " .. fileSize .. "\n")

	local i
	writeLogfile(4, "postHeaders:\n")
	for i = 1, #postHeaders do
		writeLogfile(4, 'Field: ' .. postHeaders[i].field .. ' Value: ' .. postHeaders[i].value .. '\n')
	end

	local respBody, respHeaders = LrHttp.post(h.serverUrl .. h.uploadPath, 
								LrFileUtils.readFile(srcFilename), postHeaders, 'POST', timeout, fileSize)
	
	if not respBody then
    writeTableLogfile(3, 'respHeaders', respHeaders)
    if respHeaders then
      return false, 'Error "' .. ifnil(respHeaders["error"].errorCode, 'Unknown') .. '" on http request:\n' .. 
          trim(ifnil(respHeaders["error"].name, 'Unknown error description'))
    else
      return false, 'Unknown error on http request"'
    end
	end
	writeLogfile(4, "Got Body:\n" .. respBody .. "\n")	

  local respArray = JSON:decode(respBody)
  
  if not respArray.success then
    writeLogfile(3,"uploadPictureFile: " .. srcFilename .. " to " .. dstDir .. "/" .. dstFilename .. " failed: " .. respArray.err_msg .. "!\n")
  end

  return respArray.success, respArray.err_msg
end