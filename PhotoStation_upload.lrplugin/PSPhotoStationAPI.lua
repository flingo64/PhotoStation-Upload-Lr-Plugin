--[[----------------------------------------------------------------------------

PSPhotoStationAPI.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2017, Martin Messmer

Photo Station API functions:
	- initialize
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
	
	- listAlbum
	- sortAlbumPhotos
	- deleteAlbum
		
	- getSharedAlbums
	- listSharedAlbum
	- createSharedAlbum
	- editSharedAlbum
	- addPhotosToSharedAlbum
	- removePhotosFromSharedAlbum
	- renameSharedAlbum
	- deleteSharedAlbum
	
	- listPublicSharedAlbum
	- getPublicSharedAlbumLogList
	- getPublicSharedAlbumPhotoComments
	
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
		writeLogfile(3, string.format('PSPhotoStationAPI.callSynoAPI: %s returns error %d\n', synoAPI, errorCode))
		return nil, errorCode
	end
	
	return respArray
end

--====== global functions ====================================================--

PSPhotoStationAPI = {}

-- #####################################################################################################
-- ########################## session management #######################################################
-- #####################################################################################################

---------------------------------------------------------------------------------------------------------
-- initialize: set serverUrl, loginPath and uploadPath
function PSPhotoStationAPI.initialize(serverUrl, psPath, serverTimeout)
	local h = {} -- the handle
	local apiInfo = {}

	writeLogfile(4, "PSPhotoStationAPI.initialize(PhotoStationUrl=" .. serverUrl .. psPath .. ", Timeout=" .. serverTimeout .. ")\n")

	h.serverUrl = serverUrl
	h.serverTimeout = serverTimeout

	h.psAlbumRoot	= 	psPath .. '#!Albums'
	h.psWebAPI 		= 	psPath .. 'webapi/'
	h.uploadPath 	=	psPath .. 'include/asst_file_upload.php'

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
--					 'enable_syno_token=true&' .. 
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

-- #####################################################################################################
-- ########################## tag management ###########################################################
-- #####################################################################################################

---------------------------------------------------------------------------------------------------------
-- getTags (h, type) 
-- get table of tagId/tagString mappings for given type: desc, people, geo
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

	writeLogfile(3, string.format('createTag(%s, %s) returns tagId %s.\n', type, name, respArray.data.id))
	return respArray.data.id
end

-- #####################################################################################################
-- ########################## photo management #########################################################
-- #####################################################################################################

---------------------------------------------------------------------------------------------------------
-- getPhotoExifs (h, dstFilename, isVideo) 
function PSPhotoStationAPI.getPhotoExifs (h, dstFilename, isVideo) 
	local formData = 'method=getexif&' ..
					 'version=1&' .. 
					 'id=' .. PSPhotoStationUtils.getPhotoId(dstFilename, isVideo) 

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Photo', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('getPhotoExifs(%s) returns %d exifs.\n', dstFilename, respArray.data.total))
	return respArray.data.exifs
end

---------------------------------------------------------------------------------------------------------
-- editPhoto (h, dstFilename, isVideo, attrValPairs) 
-- edit specific metadata field of a photo
function PSPhotoStationAPI.editPhoto(h, dstFilename, isVideo, attrValPairs)
	local formData = 'method=edit&' ..
					 'version=1&' .. 
					 'id=' .. PSPhotoStationUtils.getPhotoId(dstFilename, isVideo)
	local logMessage = ''

	for i = 1, #attrValPairs do
	 	formData = formData .. '&' 		.. attrValPairs[i].attribute .. '=' .. attrValPairs[i].value
	 	logMessage = logMessage .. ', ' .. attrValPairs[i].attribute .. '=' .. attrValPairs[i].value  
	end

	local success, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Photo', formData)
	
	if not success then return false, errorCode end 

	writeLogfile(3, string.format('editPhoto(%s,%s) returns OK.\n', dstFilename, logMessage))
	return true
end

---------------------------------------------------------------------------------------------------------
-- getPhotoTags (h, dstFilename, isVideo) 
-- get table of tags (general,people,geo) of a photo
function PSPhotoStationAPI.getPhotoTags(h, dstFilename, isVideo)
	local formData = 'method=list&' ..
					 'version=1&' .. 
					 'type=people,geo,desc&' .. 
					 'additional=info&' ..
					 'id=' .. PSPhotoStationUtils.getPhotoId(dstFilename, isVideo) 

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
					 'id=' .. PSPhotoStationUtils.getPhotoId(dstFilename, isVideo) 

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.PhotoTag', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('addPhotoTag(%s) returns %d item_tag_ids.\n', dstFilename, #respArray.data.item_tag_ids))
	return respArray.data.item_tag_ids
end

---------------------------------------------------------------------------------------------------------
-- getPhotoComments (h, dstFilename, isVideo) 
function PSPhotoStationAPI.getPhotoComments (h, dstFilename, isVideo) 
	local formData = 'method=list&' ..
					 'version=1&' .. 
					 'id=' .. PSPhotoStationUtils.getPhotoId(dstFilename, isVideo) 

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Comment', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('getPhotoComments(%s) returns OK.\n', dstFilename))
	return respArray.data.comments
end

---------------------------------------------------------------------------------------------------------
-- addPhotoComment (h, dstFilename, isVideo, comment, username) 
function PSPhotoStationAPI.addPhotoComment (h, dstFilename, isVideo, comment, username) 
	local formData = 'method=create&' ..
					 'version=1&' .. 
					 'id=' .. PSPhotoStationUtils.getPhotoId(dstFilename, isVideo) .. '&' .. 
					 'name=' .. username .. '&' .. 
					 'comment='.. urlencode(comment) 

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Comment', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('addPhotoComment(%s, %s, %s) returns OK.\n', dstFilename, comment, username))
	return respArray.success
end

---------------------------------------------------------------------------------------------------------
-- movePhoto (h, srcFilename, dstAlbum, isVideo) 
function PSPhotoStationAPI.movePhoto(h, srcFilename, dstAlbum, isVideo)
	local formData = 'method=copy&' ..
					 'version=1&' ..
					 'mode=move&' .. 
					 'duplicate=ignore&' .. 
					 'id=' .. PSPhotoStationUtils.getPhotoId(srcFilename, isVideo) .. '&' ..
					 'sharepath=' .. PSPhotoStationUtils.getAlbumId(dstAlbum)

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Photo', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('movePhoto(%s, %s) returns OK\n', srcFilename, dstAlbum))
	return respArray.success

end

---------------------------------------------------------------------------------------------------------
-- deletePhoto (h, dstFilename, isVideo) 
function PSPhotoStationAPI.deletePhoto (h, dstFilename, isVideo) 
	local formData = 'method=delete&' ..
					 'version=1&' .. 
					 'id=' .. PSPhotoStationUtils.getPhotoId(dstFilename, isVideo)

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Photo', formData)
	
	if not respArray and errorCode ~= 101 then return false, errorCode end 

	writeLogfile(3, string.format('deletePhoto(%s) returns OK (errorCode was %d)\n', dstFilename, ifnil(errorCode, 0)))
	return respArray.success
end

-- #####################################################################################################
-- ########################## album management #########################################################
-- #####################################################################################################

---------------------------------------------------------------------------------------------------------
-- listAlbum: returns all photos/videos and optionally albums in a given album
-- returns
--		albumItems:		table of photo infos, if success, otherwise nil
--		errorcode:		errorcode, if not success
function PSPhotoStationAPI.listAlbum(h, dstDir, listItems)
	-- recursive doesn't seem to work
	local formData = 'method=list&' ..
					 'version=1&' .. 
					 'id=' .. PSPhotoStationUtils.getAlbumId(dstDir) .. '&' ..
					 'type=' .. listItems .. '&' ..   
					 'offset=0&' .. 
					 'limit=-1&' ..
					 'recursive=false&'.. 
					 'additional=album_permission,photo_exif'
--					 'additional=album_permission,photo_exif,video_codec,video_quality,thumb_size,file_location'

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Album', formData)
	
	if not respArray then return nil, errorCode end 

	writeTableLogfile(4, 'listAlbum(' .. dstDir .. ')', respArray.data.items)
	return respArray.data.items
end

---------------------------------------------------------------------------------------------------------
-- sortAlbumPhotos (h, albumPath, sortedPhotos) 
function PSPhotoStationAPI.sortAlbumPhotos (h, albumPath, sortedPhotos) 
	local formData = 'method=arrangeitem&' ..
					 'version=1&' .. 
					 'offset=0&' .. 
					 'limit='.. #sortedPhotos .. '&' .. 
					 'id=' .. PSPhotoStationUtils.getAlbumId(albumPath)
	local i, photoPath, item_ids = {}
	
	for i, photoPath in ipairs(sortedPhotos) do
		if i == 1 then
			item_ids = PSPhotoStationUtils.getPhotoId(sortedPhotos[i])
		else
			item_ids = item_ids .. ',' .. PSPhotoStationUtils.getPhotoId(sortedPhotos[i])
		end
	end	
	
	formData = formData .. 'item_id=' .. item_ids
	
	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Album', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('sortAlbumPhotos(%s) returns OK.\n', albumPath))
	return respArray.success
end

---------------------------------------------------------------------------------------------------------
-- deleteAlbum(h, albumPath) 
function PSPhotoStationAPI.deleteAlbum (h, albumPath) 
	local formData = 'method=delete&' ..
					 'version=1&' .. 
					 'id=' .. PSPhotoStationUtils.getAlbumId(albumPath)

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Album', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('deleteAlbum(%s) returns OK\n', albumPath))
	return respArray.success
end

-- #####################################################################################################
-- ########################## shared album management ##################################################
-- #####################################################################################################

---------------------------------------------------------------------------------------------------------
-- getSharedAlbums (h) 
-- get table of sharedAlbumId/sharedAlbumName mappings
function PSPhotoStationAPI.getSharedAlbums(h)
	local formData = 'method=list&' ..
					 'version=1&' .. 
					 'additional=public_share&' .. 
					 'offset=0&' ..  
					 'limit=-1' 

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.SharedAlbum', formData)
	
	if not respArray then return nil, errorCode end 

	writeLogfile(3, string.format('getSharedAlbums() returns %d albums.\n', respArray.data.total))
	return respArray.data.items
end

---------------------------------------------------------------------------------------------------------
-- listSharedAlbum: returns all photos/videos in a given shared album
-- returns
--		albumItems:		table of photo infos, if success, otherwise nil
--		errorcode:		errorcode, if not success
function PSPhotoStationAPI.listSharedAlbum(h, sharedAlbumName, listItems)
	local albumId  = PSPhotoStationUtils.getSharedAlbumId(h, sharedAlbumName)
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

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Photo', formData)
	
	if not respArray then return nil, errorCode end 

	writeTableLogfile(4, 'listAlbum', respArray.data.items)
	return respArray.data.items
end

---------------------------------------------------------------------------------------------------------
-- createSharedAlbum(h, name)
function PSPhotoStationAPI.createSharedAlbum(h, sharedAlbumName)
	local formData = 'method=create&' ..
					 'version=1&' .. 
					 'name=' .. urlencode(sharedAlbumName) 

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.SharedAlbum', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(2, string.format('createSharedAlbum(%s) returns sharedAlbumId %s.\n', sharedAlbumName, respArray.data.id))
	return respArray.data.id
end

---------------------------------------------------------------------------------------------------------
-- editSharedAlbum(h, sharedAlbumName, sharedAlbumAttributes)
function PSPhotoStationAPI.editSharedAlbum(h, sharedAlbumName, sharedAlbumAttributes)
	local albumId  = PSPhotoStationUtils.getSharedAlbumId(h, sharedAlbumName)
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
					 
	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.SharedAlbum', formData)
	
	if not respArray then return nil, errorCode end 

	writeLogfile(2, string.format('editSharedAlbum(%s, %d attributes) returns shareId %s.\n', sharedAlbumName, numAttributes, respArray.data.shareid))
	return respArray.data
end

---------------------------------------------------------------------------------------------------------
-- PhotoStation.addPhotosToSharedAlbum(h, sharedAlbumName, photos)
-- add photos to Shared Album
function PSPhotoStationAPI.addPhotosToSharedAlbum(h, sharedAlbumName, photos)
	local albumId  = PSPhotoStationUtils.getSharedAlbumId(h, sharedAlbumName)
	if not albumId then 
		writeLogfile(3, string.format('addPhotosToSharedAlbum(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end
	
	local photoIds = {}
	for i = 1, #photos do
		photoIds[i] = PSPhotoStationUtils.getPhotoId(photos[i].dstFilename, photos[i].isVideo)
	end
	local itemList = table.concat(photoIds, ',')
	local formData = 'method=add_items&' ..
				 'version=1&' .. 
				 'id=' ..  albumId .. '&' .. 
				 'item_id=' .. itemList
				 
	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.SharedAlbum', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('addPhotosToSharedAlbum(%s, %d photos) returns OK.\n', sharedAlbumName, #photos))
	return true
end

---------------------------------------------------------------------------------------------------------
-- PhotoStation.removePhotosFromSharedAlbum(h, sharedAlbumName, photos)
-- remove photos from Shared Album
function PSPhotoStationAPI.removePhotosFromSharedAlbum(h, sharedAlbumName, photos)
	local albumId  = PSPhotoStationUtils.getSharedAlbumId(h, sharedAlbumName)
	if not albumId then 
		writeLogfile(3, string.format('removePhotosFromSharedAlbum(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end
	
	local photoIds = {}
	for i = 1, #photos do
		photoIds[i] = PSPhotoStationUtils.getPhotoId(photos[i].dstFilename, photos[i].isVideo)
	end
	local itemList = table.concat(photoIds, ',')
	local formData = 'method=remove_items&' ..
				 'version=1&' .. 
				 'id=' .. albumId .. '&' .. 
				 'item_id=' .. itemList
				 
	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.SharedAlbum', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('removePhotosFromSharedAlbum(%s,%d photos) returns OK.\n', sharedAlbumName, #photos))
	return true
end

--[[ currently not needed
---------------------------------------------------------------------------------------------------------
-- addSharedPhotoComment (h, dstFilename, isVideo, comment, username, sharedAlbumName) 
function PSPhotoStationAPI.addSharedPhotoComment (h, dstFilename, isVideo, comment, username, sharedAlbumName) 
	local formData = 'method=add_comment&' ..
					 'version=1&' .. 
					 'item_id=' .. PSPhotoStationUtils.getPhotoId(dstFilename, isVideo) .. '&' .. 
					 'name=' .. username .. '&' .. 
					 'comment='.. urlencode(comment) ..'&' .. 
					 'public_share_id=' .. PSPhotoStationUtils.getSharedAlbumShareId(h, sharedAlbumName) 

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.AdvancedShare', formData)
	
	if not respArray then return false, errorCode end 

	writeLogfile(3, string.format('addSharedPhotoComment(%s, %s, %s, %s) returns OK.\n', dstFilename, sharedAlbumName, comment, username))
	return respArray.success
end
]]

---------------------------------------------------------------------------------------------------------
-- renameSharedAlbum(h, sharedAlbumName, newSharedAlbumName)
function PSPhotoStationAPI.renameSharedAlbum(h, sharedAlbumName, newSharedAlbumName)
	local albumId  = PSPhotoStationUtils.getSharedAlbumId(h, sharedAlbumName)
	if not albumId then 
		writeLogfile(3, string.format('renameSharedAlbum(%s, %s): album not found!\n', sharedAlbumName, newSharedAlbumName))
		return false, 555
	end
	
	local formData = 'method=edit&' ..
					 'version=1&' ..
					 'name='  ..  newSharedAlbumName .. '&' ..
					 'id=' .. albumId

	local success, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.SharedAlbum', formData)
	
	if not success then return false, errorCode end 

	writeLogfile(3, string.format('renameSharedAlbum(%s, %s) returns OK.\n', sharedAlbumName, newSharedAlbumName))
	return true
end

---------------------------------------------------------------------------------------------------------
-- deleteSharedAlbum(h, sharedAlbumName)
function PSPhotoStationAPI.deleteSharedAlbum(h, sharedAlbumName)
	local albumId  = PSPhotoStationUtils.getSharedAlbumId(h, sharedAlbumName)
	if not albumId then 
		writeLogfile(3, string.format('deleteSharedAlbum(%s): album not found, returning OK anyway!\n', sharedAlbumName))
		return true
	end
	
	local formData = 'method=delete&' ..
					 'version=1&' ..
					 'id=' .. albumId

	local success, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.SharedAlbum', formData)
	
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
function PSPhotoStationAPI.listPublicSharedAlbum(h, sharedAlbumName, listItems)
	local shareId  = PSPhotoStationUtils.getSharedAlbumShareId(h, sharedAlbumName)
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

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.Photo', formData)
	
	if not respArray then return nil, errorCode end 

	writeTableLogfile(4, 'listAlbum', respArray.data.items)
	return respArray.data.items
end

---------------------------------------------------------------------------------------------------------
-- getPublicSharedAlbumInfo (h, sharedAlbumName) 
function PSPhotoStationAPI.getPublicSharedAlbumInfo (h, sharedAlbumName) 
	local shareId  = PSPhotoStationUtils.getSharedAlbumShareId(h, sharedAlbumName)
	if not shareId then 
		writeLogfile(3, string.format('getPublicSharedAlbumInfo(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end
	
	local formData = 'method=getinfo_public&' ..
					 'version=1&' .. 
					 'public_share_id=' .. shareId 

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.SharedAlbum', formData)
	
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
function PSPhotoStationAPI.getPublicSharedAlbumLogList (h, sharedAlbumName) 
	local shareId  = PSPhotoStationUtils.getSharedAlbumShareId(h, sharedAlbumName)
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

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.AdvancedShare', formData)
	
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
function PSPhotoStationAPI.getPublicSharedPhotoComments (h, sharedAlbumName, dstFilename, isVideo)
	local shareId  = PSPhotoStationUtils.getSharedAlbumShareId(h, sharedAlbumName)
	if not shareId then 
		writeLogfile(3, string.format('getPublicSharedPhotoComments(%s): album not found!\n', sharedAlbumName))
		return false, 555
	end
	
	local formData = 'method=list_comment&' ..
					 'version=1&' .. 
					 'offset=0&' .. 
					 'limit=-1&' .. 
					 'item_id=' 		.. PSPhotoStationUtils.getPhotoId(dstFilename, isVideo) .. '&' ..
					 'public_share_id=' .. shareId 

	local respArray, errorCode = callSynoAPI (h, 'SYNO.PhotoStation.AdvancedShare', formData)
	
	if not respArray then return false, errorCode end 

	if respArray.data then
		writeLogfile(3, string.format('getPublicSharedPhotoComments(%s, %s) returns %d comments.\n', dstFilename, sharedAlbumName, #respArray.data))
	else
		writeLogfile(3, string.format('getPublicSharedPhotoComments(%s, %s) returns no comments.\n', dstFilename, sharedAlbumName))
	end
	return respArray.data
end

