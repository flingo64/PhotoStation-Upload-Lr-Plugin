--[[----------------------------------------------------------------------------

PSUploadTask.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2015-2022, Martin Messmer

Upload photos to Synology Photo Station / Photos via HTTP(S) WebService

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

This code is derived from the Lr SDK FTP Upload sample code. Copyright: see below
--------------------------------------------------------------------------------

ADOBE SYSTEMS INCORPORATED
 Copyright 2007 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.

------------------------------------------------------------------------------]]


-- Lightroom API
local LrApplication		= import 'LrApplication'
local LrFileUtils		= import 'LrFileUtils'
local LrPathUtils		= import 'LrPathUtils'
local LrDate			= import 'LrDate'
local LrDialogs			= import 'LrDialogs'
local LrProgressScope 	= import 'LrProgressScope'
local LrShell 			= import 'LrShell'
local LrPrefs			= import 'LrPrefs'
local LrTasks			= import 'LrTasks'
local LrView			= import 'LrView'

require "PSUtilities"
require "PSLrUtilities"
require "PSConvert"
require "PSUpdate"
require "PSExiftoolAPI"
require "PSSharedAlbumMgmt"

--============================================================================--

PSUploadTask = {}

-----------------
-- getDirAndBasename(photoPath)
local function getDirAndBasename(photoPath)
	local picDir = LrPathUtils.parent(photoPath)
	local picBasename = mkSafeFilename(LrPathUtils.removeExtension(LrPathUtils.leafName(photoPath)))

	return picDir, picBasename
end

-----------------
-- getTitleFilename(photoPath, photoServer)
local function getTitleFilename(photoPath, photoServer)
	if photoServer:supports(PHOTOSERVER_UPLOAD_TITLE) then
		local picDir, picBasename = getDirAndBasename(photoPath)
		return LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_TITLE', 'txt'))
	end
	return nil
end

-----------------
-- getThumbSettings(photoPath, photoServer, doLargeThumbs, thumbQuality, thumbSharpness)
-- get thumb settings for a photo based on photoServer and export params
local function getThumbSettings(photoPath, photoServer, doLargeThumbs, thumbQuality, thumbSharpness)
	if not photoServer.thumbs then return nil end

	local picDir, picBasename = getDirAndBasename(photoPath)
	local picExt = 'jpg'

	local thumbSharpening = {
		None 	= 	'',
		LOW 	= 	'-unsharp 0.5x0.5+0.5+0.008',
		MED 	= 	'-unsharp 0.5x0.5+1.25+0.0',
		HIGH 	= 	'-unsharp 0.5x0.5+2.0+0.0',
	}

	local thumbSettings = {
		quality		= tostring(thumbQuality),
		sharpening	= thumbSharpening[thumbSharpness],

		XL_Dim		= '0x0',
		XL_Filename	= '',
		L_Dim		= '0x0',
		L_Filename	= '',
		M_Dim		= '0x0',
		M_Filename	= '',
		B_Dim		= '0x0',
		B_Filename	= '',
		S_Dim		= '0x0',
		S_Filename	= ''
	}

	if photoServer.thumbs.XL then
		thumbSettings.XL_Dim		= photoServer.thumbs.XL .. 'x' .. photoServer.thumbs.XL ..'>' .. iif(doLargeThumbs, '^', '')
		thumbSettings.XL_Filename	= LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_XL', picExt))
	end
	if photoServer.thumbs.L then
		thumbSettings.L_Dim			= photoServer.thumbs.L .. 'x' .. photoServer.thumbs.L ..'>' .. iif(doLargeThumbs, '^', '')
		thumbSettings.L_Filename	= LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_L', picExt))
	end
	if photoServer.thumbs.M then
		thumbSettings.M_Dim			= photoServer.thumbs.M .. 'x' .. photoServer.thumbs.M ..'>' .. iif(doLargeThumbs, '^', '')
		thumbSettings.M_Filename	= LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_M', picExt))
	end
	if photoServer.thumbs.B then
		thumbSettings.B_Dim			= photoServer.thumbs.B .. 'x' .. photoServer.thumbs.B ..'>' .. iif(doLargeThumbs, '^', '')
		thumbSettings.B_Filename	= LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_B', picExt))
	end
	if photoServer.thumbs.S then
		thumbSettings.S_Dim			= photoServer.thumbs.S .. 'x' .. photoServer.thumbs.S ..'>' .. iif(doLargeThumbs, '^', '')
		thumbSettings.S_Filename	= LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_S', picExt))
	end

	return thumbSettings
end

-----------------
-- uploadPhoto(renderedPhotoPath, srcPhoto, dstDir, dstFilename, exportParams)
--[[
	generate all required thumbnails and upload thumbnails and the original picture as a batch.
	The upload batch must start with any of the thumbs and end with the original picture.
	When uploading to Photo Station 6, we don't need to upload the THUMB_L
	When uploading to Synology Photos, we don't need to upload the THUMB_B
]]
local function uploadPhoto(renderedPhotoPath, srcPhoto, dstDir, dstFilename, exportParams)
	local photoServer = exportParams.photoServer

	local dstFileTimestamp = iif(ifnil(exportParams.uploadTimestamp, 'capture') == 'capture',
								 PSLrUtilities.getDateTimeOriginal(srcPhoto),
								 LrDate.timeToPosixDate(LrDate.currentTime()))
	local exifXlatLabelCmd = iif(exportParams.exifXlatLabel and not string.find('none,grey', string.lower(srcPhoto:getRawMetadata('colorNameForLabel'))), "-XMP:Subject+=" .. '+' .. srcPhoto:getRawMetadata('colorNameForLabel'), nil)
	local retcode

	-- get title_Filename if required
	local title_Filename =
					ifnil(srcPhoto:getFormattedMetadata("title"), '') ~= ''
				and string.match(exportParams.LR_embeddedMetadataOption, 'all.*')
				and	getTitleFilename(renderedPhotoPath, photoServer)

	-- get thumb settings if required
	local thumbSettings =
					photoServer:supports(PHOTOSERVER_UPLOAD_THUMBS)
				and exportParams.thumbGenerate
				and getThumbSettings(renderedPhotoPath, photoServer, exportParams.largeThumbs, exportParams.thumbQuality, exportParams.thumbSharpness)

	-- generate thumbs if required
	if (thumbSettings and not exportParams.converter:convertPicConcurrent(renderedPhotoPath, srcPhoto, exportParams.LR_format,
								'-flatten -quality '.. thumbSettings.quality .. ' -auto-orient '.. thumbSettings.sharpening,
								thumbSettings.XL_Dim, thumbSettings.XL_Filename,
								thumbSettings.L_Dim,  thumbSettings.L_Filename,
								thumbSettings.B_Dim,  thumbSettings.B_Filename,
								thumbSettings.M_Dim,  thumbSettings.M_Filename,
								thumbSettings.S_Dim,  thumbSettings.S_Filename)
		)

	-- if photo has a title: generate a title file
	or (title_Filename and not exportParams.converter.writeTitleFile(title_Filename, srcPhoto:getFormattedMetadata("title")))

	-- exif translations: avoid calling doExifTranslations() if nothing's there to translate
	or ((exportParams.exifXlatFaceRegions or exifXlatLabelCmd or exportParams.exifXlatRating)
		and not exportParams.exifTool:doExifTranslations(renderedPhotoPath, exifXlatLabelCmd))

	-- wait for Photo Server semaphore
	or not waitSemaphore("PhotoServer", dstFilename)

	-- upload thumbnails and original file
	or not exportParams.photoServer:uploadPhotoFiles(dstDir, dstFilename, dstFileTimestamp, exportParams.thumbGenerate,
												renderedPhotoPath, title_Filename, thumbSettings.XL_Filename, thumbSettings.L_Filename, thumbSettings.B_Filename, thumbSettings.M_Filename, thumbSettings.S_Filename)
	then
		signalSemaphore("PhotoServer", dstFilename)
		retcode = false
	else
		signalSemaphore("PhotoServer", dstFilename)
		retcode = true
	end

	if thumbSettings then
		if thumbSettings.XL_Filename ~= ''	then LrFileUtils.delete(thumbSettings.XL_Filename) end
		if thumbSettings.L_Filename ~= '' 	then LrFileUtils.delete(thumbSettings.L_Filename) end
		if thumbSettings.M_Filename ~= '' 	then LrFileUtils.delete(thumbSettings.M_Filename) end
		if thumbSettings.B_Filename ~= '' 	then LrFileUtils.delete(thumbSettings.B_Filename) end
		if thumbSettings.S_Filename ~= ''	then LrFileUtils.delete(thumbSettings.S_Filename) end
	end
	if title_Filename then LrFileUtils.delete(title_Filename) end
	-- orig photo will be deleted in main loop

	return retcode
end

-- getVideoSettings(videoPath, vinfo, photoServer, converter, orgVideoForceConv, addVideoQuality, addVideoUltra, addVideoHigh, addVideoMed, addVideoLow)
-- get additional video settings for a photo based on photoServer and export params
local function getVideoSettings(videoPath, vinfo, photoServer, converter, orgVideoForceConv, addVideoQuality, addVideoUltra, addVideoHigh, addVideoMed, addVideoLow)
	local picDir, picBasename 	= getDirAndBasename(videoPath)
	local vidExtOrg 			= LrPathUtils.extension(videoPath)
	local vidExt 				= 'mp4'

	local videoSettings = {
		MOB_Filename	= LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_MOB', vidExt)), 	--  240p
		LOW_Filename	= LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_LOW', vidExt)),	--  360p
		MED_Filename	= LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_MED', vidExt)),	--  720p
		HIGH_Filename	= LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_HIGH', vidExt)),	-- 1080p
	}

	videoSettings.convParams = {
		ULTRA =  	{ height = 2160,	type = 'HIGH',		filename = videoSettings.HIGH_Filename },
		HIGH =  	{ height = 1080,	type = 'HIGH',		filename = videoSettings.HIGH_Filename },
		MEDIUM = 	{ height = 720, 	type = 'MEDIUM',	filename = videoSettings.MED_Filename },
		LOW =		{ height = 360, 	type = 'LOW',		filename = videoSettings.LOW_Filename },
		MOBILE =	{ height = 240,		type = 'MOBILE',	filename = videoSettings.MOB_Filename },
	}

	--  user selected additional video resolutions based on original video resolution
	local addVideoResolution = {
		ULTRA = 	iif(photoServer:supports(PHOTOSERVER_UPLOAD_VIDEO_ADD) and addVideoQuality > 0, addVideoUltra, 'None'),
		HIGH = 		iif(photoServer:supports(PHOTOSERVER_UPLOAD_VIDEO_ADD) and addVideoQuality > 0, addVideoHigh, 'None'),
		MEDIUM = 	iif(photoServer:supports(PHOTOSERVER_UPLOAD_VIDEO_ADD) and addVideoQuality > 0, addVideoMed, 'None'),
		LOW = 		iif(photoServer:supports(PHOTOSERVER_UPLOAD_VIDEO_ADD) and addVideoQuality > 0, addVideoLow, 'None'),
		MOBILE = 	'None',
	}

	-- get the right conversion settings (depending on Height)
	_, videoSettings.convKeyOrig = converter:getConvertKey(tonumber(vinfo.height))
	videoSettings.Replace_Filename = videoSettings.convParams[videoSettings.convKeyOrig].filename
	videoSettings.convKeyAdd = addVideoResolution[videoSettings.convKeyOrig]
	if videoSettings.convKeyAdd ~= 'None' then
		videoSettings.Add_Filename = videoSettings.convParams[videoSettings.convKeyAdd].filename
	end

	-- replace original video if:
	--		- srcVideo is to be rotated (meta or hard)
	-- 		- srcVideo is mp4, but not h264 (PS would try to open, but does only support h264)
	--		- srcVideo is mp4, but has no audio stream (PS would ignore it)
	--		- exportParams.orgVideoForceConv was set
	if tonumber(vinfo.rotation) > 0
	or tonumber(vinfo.mrotation) > 0
	or (converter.videoIsNativePSFormat(vidExtOrg) and vinfo.vformat ~= 'h264')
	or vinfo.aFormat == nil
	or orgVideoForceConv then
		videoSettings.replaceOrgVideo = true
		videoSettings.Orig_Filename = videoSettings.Replace_Filename
	else
		videoSettings.replaceOrgVideo = false
		videoSettings.Orig_Filename = videoPath
	end

	-- Additional MP4 in orig dimension if video is not MP4
	-- Non-MP4 will not be opened by PS, so it's safe to upload the original version plus an additional MP4
	if not converter.videoIsNativePSFormat(vidExtOrg) and not videoSettings.replaceOrgVideo then
	else
		videoSettings.addOrigAsMp4 = true
	end

	return videoSettings
end

-----------------
-- uploadVideo(renderedVideoPath, srcPhoto, dstDir, dstFilename, exportParams, vinfo)
--[[
	generate all required thumbnails, at least one video with alternative resolution (if we don't do, Photo Station will do)
	and upload thumbnails, alternative video and the original video as a batch.
	The upload batch must start with any of the thumbs and end with the original video.
	When uploading to Photo Station 6, we don't need to upload the THUMB_L
	When uploading to Synology Photos, we don't need to upload the THUMB_B
]]
local function uploadVideo(renderedVideoPath, srcPhoto, dstDir, dstFilename, exportParams, vinfo)
	local photoServer = exportParams.photoServer
	local picDir, picBasename = getDirAndBasename(renderedVideoPath)
	local picExt = 'jpg'
	local thmb_ORG_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename, picExt))

	-- upload file timestamp: PS uses the file timestamp as capture date for videos
	local dstFileTimestamp
	if string.find('capture,mixed', ifnil(exportParams.uploadTimestamp, 'capture'), 1, true) then
 		writeLogfile(3, string.format("uploadVideo: %s - using capture date as file timestamp\n", renderedVideoPath))
    	dstFileTimestamp = vinfo.srcDateTime
	else
 		writeLogfile(3, string.format("uploadVideo: %s - using current timestamp as file timestamp\n", renderedVideoPath))
		dstFileTimestamp = LrDate.timeToPosixDate(LrDate.currentTime())
	end

	-- get title_Filename if required
	local title_Filename =
					ifnil(srcPhoto:getFormattedMetadata("title"), '') ~= ''
				and string.match(exportParams.LR_embeddedMetadataOption, 'all.*')
				and	getTitleFilename(renderedVideoPath, photoServer)

	-- get thumb settings if required
	local thumbSettings =
					photoServer:supports(PHOTOSERVER_UPLOAD_THUMBS)
				and exportParams.thumbGenerate
				and getThumbSettings(renderedVideoPath, photoServer, exportParams.largeThumbs, exportParams.thumbQuality, exportParams.thumbSharpness)

	local videoSettings =
			getVideoSettings(renderedVideoPath, vinfo, photoServer, exportParams.converter,
							exportParams.orgVideoForceConv, exportParams.addVideoQuality,
							exportParams.addVideoUltra, exportParams.addVideoHigh, exportParams.addVideoMed, exportParams.addVideoLow)

	-- generate thumbs if required
	if (thumbSettings
		and (
			-- generate first thumb from video, rotation has to be done regardless of the hardRotate setting
			not exportParams.converter:ffmpegGetThumbFromVideo (renderedVideoPath, vinfo, thmb_ORG_Filename)

			-- generate all other thumb from first thumb
			or not exportParams.converter:convertPicConcurrent(thmb_ORG_Filename, srcPhoto, exportParams.LR_format,
								'-flatten -quality '.. thumbSettings.quality .. ' -auto-orient '.. thumbSettings.sharpening,
								thumbSettings.XL_Dim, thumbSettings.XL_Filename,
								thumbSettings.L_Dim,  thumbSettings.L_Filename,
								thumbSettings.B_Dim,  thumbSettings.B_Filename,
								thumbSettings.M_Dim,  thumbSettings.M_Filename,
								thumbSettings.S_Dim,  thumbSettings.S_Filename)
			)
		)

	-- generate mp4 in original size if srcVideo is not already mp4/h264 or if video is rotated
	or ((videoSettings.replaceOrgVideo or videoSettings.addOrigAsMp4) and not exportParams.converter:convertVideo(renderedVideoPath, vinfo, vinfo.height, exportParams.hardRotate, exportParams.orgVideoQuality, videoSettings.Replace_Filename))

	-- generate additional video, if requested
	or ((videoSettings.convKeyAdd ~= 'None') and not exportParams.converter:convertVideo(renderedVideoPath, vinfo, videoSettings.convParams[videoSettings.convKeyAdd].height, exportParams.hardRotate, exportParams.addVideoQuality, videoSettings.Add_Filename))

	-- if photo has a title: generate a title file
	or (title_Filename and not exportParams.converter.writeTitleFile(title_Filename, srcPhoto:getFormattedMetadata("title")))

	-- wait for Photo Server semaphore
	or not waitSemaphore("PhotoServer", dstFilename)

	-- upload thumbnails, original video and replacement/additional videos
	or not exportParams.photoServer:uploadVideoFiles(dstDir, dstFilename, dstFileTimestamp, exportParams.thumbGenerate,
			videoSettings.Orig_Filename, title_Filename, thumbSettings.XL_Filename, thumbSettings.L_Filename, thumbSettings.B_Filename, thumbSettings.M_Filename, thumbSettings.S_Filename,
			videoSettings.Add_Filename, videoSettings.Replace_Filename, videoSettings.convParams, videoSettings.convKeyOrig, videoSettings.convKeyAdd, videoSettings.addOrigAsMp4)
	then
		signalSemaphore("PhotoServer", dstFilename)
		retcode = false
	else
		signalSemaphore("PhotoServer", dstFilename)
		retcode = true
	end

	if thumbSettings then
    	LrFileUtils.delete(thmb_ORG_Filename)
		if thumbSettings.XL_Filename ~= ''	then LrFileUtils.delete(thumbSettings.XL_Filename) end
		if thumbSettings.L_Filename ~= '' 	then LrFileUtils.delete(thumbSettings.L_Filename) end
		if thumbSettings.M_Filename ~= '' 	then LrFileUtils.delete(thumbSettings.M_Filename) end
		if thumbSettings.B_Filename ~= '' 	then LrFileUtils.delete(thumbSettings.B_Filename) end
		if thumbSettings.S_Filename ~= ''	then LrFileUtils.delete(thumbSettings.S_Filename) end
	end
	if title_Filename then LrFileUtils.delete(title_Filename) end
	if (videoSettings.replaceOrgVideo or videoSettings.addOrigAsMp4) then LrFileUtils.delete(videoSettings.Replace_Filename) end
	if videoSettings.Add_Filename then LrFileUtils.delete(videoSettings.Add_Filename) end
	-- orig video will be deleted in main loop

	return retcode
end

-----------------
-- uploadMetadata(srcPhoto, vinfo, dstPath, exportParams)
-- Upload metadata of a photo or video according to upload options:
-- 	- title 			always
-- 	- description		always
-- 	- rating			always
-- 	- gps				always
-- 	- keywords			always
-- 	- faces				if option is set
-- 	- color label tags	if option is set
-- 	- rating tags		if option is set
local function uploadMetadata(srcPhoto, vinfo, dstPath, exportParams)
	local logMessagePrefix 	= string.format("Metadata Upload for '%s'", dstPath)
	local isVideo 			= srcPhoto:getRawMetadata("isVideo")
	local photoServer		= exportParams.photoServer
	local psPhoto			= photoServer.Photo.new(photoServer, dstPath, isVideo, 'photo,tag', PHOTOSERVER_USE_CACHE)
	if not psPhoto then
		writeLogfile(1, string.format("%s - photo not yet in Photo Server, use 'Upload' mode --> failed!\n", logMessagePrefix))
		return false
	end
	local psPhotoTags 		= psPhoto:getTags()
	local keywordsPS 		= getTableExtract(psPhotoTags, nil, 'type', 'desc')
	local facesPS 			= getTableExtract(psPhotoTags, nil, 'type', 'people')
	local locationsPS		= getTableExtract(psPhotoTags, nil, 'type', 'geo')
	local LrExportMetadata	= (    exportParams.LR_embeddedMetadataOption and string.match(exportParams.LR_embeddedMetadataOption, 'all.*')) or
						 	  (not exportParams.LR_embeddedMetadataOption and not exportParams.LR_minimizeEmbeddedMetadata)
	local LrExportPersons	= not exportParams.LR_removeFaceMetadata
	local LrExportLocations	= not exportParams.LR_removeLocationMetadata

	local metadataChanged, tagsAdded, tagsRemoved = 0, 0, 0

	if not LrExportMetadata then
		writeLogfile(1, string.format("%s - Lr Metadata export disabled --> skipped.\n", logMessagePrefix))
		return true
	end

	-- check title ----------------------------------------------------------------
	local titleData = ifnil(srcPhoto:getFormattedMetadata("title"), '')
	local psTitle = psPhoto:getTitle()
	if photoServer:supports(PHOTOSERVER_METADATA_TITLE) and titleData ~= psTitle then
		psPhoto:setTitle(titleData)
		metadataChanged =  metadataChanged + 1
	end

	-- check caption ----------------------------------------------------------------
	local captionData = ifnil(srcPhoto:getFormattedMetadata("caption"), '')
	if photoServer:supports(PHOTOSERVER_METADATA_DESCRIPTION) and captionData ~= psPhoto:getDescription() then
		psPhoto:setDescription(captionData)
		metadataChanged =  metadataChanged + 1
	end

	-- check rating: ----------------------------------------------------------------
	local ratingData = ifnil(srcPhoto:getFormattedMetadata("rating"), 0)
	if photoServer:supports(PHOTOSERVER_METADATA_RATING) and ratingData ~= psPhoto:getRating() then
		psPhoto:setRating(tostring(ratingData))
		metadataChanged =  metadataChanged + 1
	end

	-- check GPS and location tags: only if allowed by Lr export/pubish settings -----
	local latitude, longitude = '0', '0'
	if LrExportLocations then
		if photoServer:supports(PHOTOSERVER_METADATA_GPS) then
			if isVideo then
				if vinfo and vinfo.latitude and vinfo.longitude then
					latitude = vinfo.latitude
					longitude = vinfo.longitude
				end
			else
				local gpsData = srcPhoto:getRawMetadata("gps")
				if gpsData and gpsData.latitude and gpsData.longitude then
					latitude = gpsData.latitude
					longitude = gpsData.longitude
				end
			end

			local gpsPS = psPhoto:getGPS()
			if 		(not gpsPS and latitude and longitude)
				or 	(	 gpsPS and math.abs(tonumber(latitude) - tonumber(gpsPS.latitude)) > 0.00001) or (math.abs(tonumber(longitude) - tonumber(gpsPS.longitude)) > 0.00001)
			then
				psPhoto:setGPS( {latitude = latitude, longitude = longitude, type = 'red' })
				metadataChanged =  metadataChanged + 1
			end
		end

		-- check location tags, if upload/translation option is set -----------------------
		if exportParams.xlatLocationTags then
			-- there may be more than one PS location tag, but only one Lr location tag
			local locationTagsLrUntrimmed = PSLrUtilities.evaluatePlaceholderString(exportParams.locationTagTemplate, srcPhoto, 'tag', nil)
			local locationTagsLrTrimmed = trim(locationTagsLrUntrimmed, exportParams.locationTagSeperator)
			local locationTagsLrCleaned = unduplicate(locationTagsLrTrimmed, exportParams.locationTagSeperator)
			local locationTagsLr = iif(locationTagsLrCleaned == '', {}, { { name = locationTagsLrCleaned }})

			local locationsAdd		= getTableDiff(locationTagsLr, locationsPS, 'name')
			local locationsRemove	= getTableDiff(locationsPS, locationTagsLr, 'name')

			psPhoto:addTags(locationsAdd, 'geo')
			psPhoto:removeTags(locationsRemove, 'geo')
			tagsAdded	= tagsAdded 	+ #locationsAdd
			tagsRemoved	= tagsRemoved 	+ #locationsRemove
		end
	end

	-- check keywords ------------------------------------------------------------------------
	local keywordsLr, keywordsAdd, keywordsRemove = {}
	if photoServer:supports(PHOTOSERVER_METADATA_TAG) then
		local keywordNamesLr =trimTable(split(srcPhoto:getFormattedMetadata("keywordTagsForExport"), ','))
		if keywordNamesLr then
			for i = 1, #keywordNamesLr do
				keywordsLr[i] = {}
				keywordsLr[i].name = keywordNamesLr[i]
			end
		end

		-- check label: if upload/translation option is set --------------------------------------
		if exportParams.exifXlatLabel then
			local labelData = srcPhoto:getRawMetadata("colorNameForLabel")
			if ifnil(labelData, 'grey') ~= 'grey' then table.insert(keywordsLr, { name = '+' .. labelData}) end
		end

		-- check ratingTag if upload/translation option is set --------------------------------------
		if exportParams.exifXlatRating and ratingData ~= 0 then
			table.insert(keywordsLr, { name = PSUtilities.rating2Stars(ratingData)})
		end

		keywordsAdd 			= getTableDiff(keywordsLr, keywordsPS, 'name')
		keywordsRemove			= getTableDiff(keywordsPS, keywordsLr, 'name')

		psPhoto:addTags(keywordsAdd, 'desc')
		psPhoto:removeTags(keywordsRemove, 'desc')
		tagsAdded	= tagsAdded 	+ #keywordsAdd
		tagsRemoved	= tagsRemoved 	+ #keywordsRemove
	end

	-- check faces: only if allowed by Lr export/pubish settings and if upload option is set ----
	local facesAdd, facesRemove
	facesRemove 	= facesPS

	if 		LrExportPersons
		and	exportParams.exifXlatFaceRegions and not isVideo
	then
		local facesLr, _ = exportParams.exifTool:queryLrFaceRegionList(srcPhoto:getRawMetadata('path'))
		-- we don't need to filter faces by keyword export flag, because Lr won't write
		-- faceRegions for person keys with export flag turned off
		if facesLr and #facesLr > 0 then
			local j, facesLrNorm = 0, {}
			for i = 1, #facesLr do
				-- exclude all unnamed face regions, because PS does not support them
				if ifnil(facesLr[i].name, '') ~= '' then
					j = j + 1
					facesLrNorm[j] = PSUtilities.normalizeArea(facesLr[i]);
				end
			end

			facesAdd 			= getTableDiff(facesLrNorm, facesPS, 'name', PSUtilities.areaCompare)
			facesRemove 		= getTableDiff(facesPS, facesLrNorm, 'name', PSUtilities.areaCompare)

			psPhoto:addTags(facesAdd, 'people')
			psPhoto:removeTags(facesRemove, 'people')
			tagsAdded	= tagsAdded 	+ #facesAdd
			tagsRemoved	= tagsRemoved 	+ #facesRemove
		end
	end

	-- check if any changes to be published --------------------------------------------------
	local logChanges = psPhoto:showUpdates()
	if logChanges == '' then
		writeLogfile(2, string.format("%s - no changes --> done.\n", logMessagePrefix))
		return true
	end

	-- publish changes
	if (not waitSemaphore("PhotoServer", dstPath)
		or (metadataChanged > 0	and not psPhoto:updateMetadata())
		or ((tagsAdded > 0 or tagsRemoved > 0) and not psPhoto:updateTags())
	   )
	then
		signalSemaphore("PhotoServer", dstPath)
		writeLogfile(1, string.format("%s - %s --> failed!!!\n", logMessagePrefix, logChanges))
		retcode = false
	else
		signalSemaphore("PhotoServer", dstPath)
		writeLogfile(2, string.format("%s - %s --> done.\n", logMessagePrefix, logChanges))
		retcode = true
	end

	return retcode
end

--------------------------------------------------------------------------------
-- ackRendition(rendition, publishedPhotoId, pubCollectionId)
local function ackRendition(rendition, publishedPhotoId, publishedCollectionId)
	writeLogfile(4, string.format("ackRendition('%s', '%s')\n", ifnil(publishedPhotoId, 'nil'), ifnil(publishedCollectionId, 'nil')))
	rendition:recordPublishedPhotoId(publishedPhotoId)
	-- store a backlink to the containing Published Collection: we need it in some hooks in PSPublishSupport.lua
	rendition:recordPublishedPhotoUrl(tostring(publishedCollectionId) .. '/' .. tostring(LrDate.currentTime()))
	return true
end

-----------------
-- noteForDeferredMetadataUpload(deferredMetadataUploads, rendition, publishedPhotoId, vinfo, publishedCollectionId)
local function noteForDeferredMetadataUpload(deferredMetadataUploads, rendition, publishedPhotoId, vinfo, publishedCollectionId)
	local photoInfo = {}

	writeLogfile(3, string.format("noteForDeferredMetadataUpload(%s)\n", publishedPhotoId))
	photoInfo.rendition 			= rendition
	photoInfo.publishedPhotoId 		= publishedPhotoId
	photoInfo.publishedCollectionId = publishedCollectionId
	photoInfo.vinfo 				= vinfo
	if vinfo then
		photoInfo.isVideo			= true
		photoInfo.vinfo 			= vinfo
	else
		photoInfo.isVideo			= false
	end
	table.insert(deferredMetadataUploads, photoInfo)

	return true
end

-----------------
-- batchUploadMetadata(functionContext, deferredMetadataUploads, exportParams, failures)
-- deferred upload of metadata for videos or photos w/ location tags which were uploaded before
local function batchUploadMetadata(functionContext, deferredMetadataUploads, exportParams, failures)
	local nPhotos =  #deferredMetadataUploads
	local nProcessed 		= 0

	writeLogfile(3, string.format("batchUploadMetadata: %d photos\n", nPhotos))
	local progressScope = LrProgressScope(
								{ 	title = LOC( "$$$/PSUpload/Progress/UploadVideoMeta2=Uploading metadata for ^1 photos/videos", nPhotos),
							 		functionContext = functionContext
							 	})
	while #deferredMetadataUploads > 0 do
		local photoInfo 				= deferredMetadataUploads[1]
		local rendition 				= photoInfo.rendition
		local srcPhoto 					= rendition.photo
		local isVideo					= photoInfo.isVideo
		local vinfo						= photoInfo.vinfo
		local dstFilename 				= photoInfo.publishedPhotoId
		local publishedCollectionId 	= photoInfo.publishedCollectionId
		local photoServer				= exportParams.photoServer
		local photoThere
		local maxWait = 60

		progressScope:setCaption(LrPathUtils.leafName(srcPhoto:getRawMetadata("path")))

		while not photoThere and maxWait > 0 do
			local psPhoto = photoServer.Photo.new(photoServer, dstFilename, isVideo, 'photo', not PHOTOSERVER_USE_CACHE)
			if not psPhoto then
				LrTasks.sleep(1)
				maxWait = maxWait - 1
			else
				photoThere = true
			end
		end

		if	(not photoThere or not uploadMetadata(srcPhoto, vinfo, dstFilename, exportParams) or
			(publishedCollectionId and not ackRendition(rendition, dstFilename, publishedCollectionId)))
		then
			table.insert(failures, srcPhoto:getRawMetadata("path"))
			photoInfo.rendition:uploadFailed("Metadata Upload failed")
			writeLogfile(1, string.format("batchUploadMetadata('%s') failed!!!\n", dstFilename))
		else
			writeLogfile(3, string.format("batchUploadMetadata('%s') done.\n", dstFilename))
		end
   		table.remove(deferredMetadataUploads, 1)
   		nProcessed = nProcessed + 1
   		progressScope:setPortionComplete(nProcessed, nPhotos)
	end
	progressScope:done()

	return true
end

--------------------------------------------------------------------------------
-- checkMoved(publishedCollection, exportContext, exportParams)
-- check all photos in a collection locally, if moved
-- all moved photos get status "to be re-published"
-- return:
-- 		nPhotos		- # of photos in collection
--		nProcessed 	- # of photos checked
--		nMoved		- # of photos found to be moved
local function checkMoved(publishedCollection, exportContext, exportParams)
	local catalog = LrApplication.activeCatalog()
	local publishedPhotos = publishedCollection:getPublishedPhotos()
	local nPhotos = #publishedPhotos
	local nProcessed = 0
	local nMoved = 0

	-- Set progress title.
	local progressScope = exportContext:configureProgress {
						title = nPhotos > 1
							and LOC( "$$$/PSUpload/Progress/CheckMoved=Checking ^1 photos", nPhotos )
							or LOC "$$$/PSUpload/Progress/CheckMoved/One=Checking one photo",
						renderPortion = 1 / nPhotos,
					}

	for i = 1, nPhotos do
		if progressScope:isCanceled() then break end

		local pubPhoto = publishedPhotos[i]
		local srcPhoto = pubPhoto:getPhoto()
		local srcPath = srcPhoto:getRawMetadata('path')
		local publishedPath = ifnil(pubPhoto:getRemoteId(), '<Nil>')
		local edited = pubPhoto:getEditedFlag()
		local dstRoot = PSLrUtilities.evaluatePlaceholderString(exportParams.dstRoot, srcPhoto, 'path', publishedCollection)

		progressScope:setCaption(LrPathUtils.leafName(srcPath))

		-- check if dstRoot contains missing required metadata ('?') (which means: skip photo)
		local skipPhoto = iif(string.find(dstRoot, '?', 1, true), true, false)

		if skipPhoto then
 			writeLogfile(2, string.format("CheckMoved(%s): Skip photo due to unknown target album %s\n", srcPath, dstRoot))
			catalog:withWriteAccessDo(
				'SetEdited',
				function(context)
					-- mark as 'To Re-publish'
					pubPhoto:setEditedFlag(true)
				end,
				{timeout=5}
    		)
    		nMoved = nMoved + 1
    	else
    		local localPath, remotePath = PSLrUtilities.getPublishPath(srcPhoto, LrPathUtils.leafName(publishedPath), exportParams, dstRoot)
    		writeLogfile(3, "CheckMoved(" .. tostring(i) .. ", s= "  .. srcPath  .. ", r =" .. remotePath .. ", lastRemote= " .. publishedPath .. ", edited= " .. tostring(edited) .. ")\n")
    		-- ignore leafname: might be different due to renaming options
    		if LrPathUtils.parent(remotePath) ~= LrPathUtils.parent(publishedPath) then
    			writeLogfile(2, "CheckMoved(" .. localPath .. "): Must be moved at target from " .. publishedPath ..
    							" to " .. remotePath .. ", edited= " .. tostring(edited) .. "\n")
    			catalog:withWriteAccessDo(
    				'SetEdited',
    				function(context)
						-- mark as 'To Re-publish'
    					pubPhoto:setEditedFlag(true)
    				end,
    				{timeout=5}
    			)
    			nMoved = nMoved + 1
    		else
    			writeLogfile(2, "CheckMoved(" .. localPath .. "): Not moved.\n")
    		end
   		end
		nProcessed = i
		progressScope:setPortionComplete(nProcessed, nPhotos)
	end
	progressScope:done()

	return nPhotos, nProcessed, nMoved
end

--------------------------------------------------------------------------------
-- movePhotos(publishedCollection, exportContext, exportParams)
-- move unpublished photos within the Photo Server to the current target album, if they were moved locally
-- photos that are already in the target album are counted as moved.
-- photos not yet published will stay unpublished
-- return:
-- 		nPhotos		- # of photos in collection
--		nProcessed 	- # of photos checked
--		nMoved		- # of photos moved
local function movePhotos(publishedCollection, exportContext, exportParams)
	local exportSession = exportContext.exportSession
	local nPhotos = exportSession:countRenditions()
	local nProcessed = 0
	local nMoved = 0

	-- Set progress title.
	local progressScope = exportContext:configureProgress {
						title = nPhotos > 1
							and LOC( "$$$/PSUpload/Progress/Move=Moving ^1 photos", nPhotos )
							or LOC "$$$/PSUpload/Progress/Move/One=Moving one photo",
						renderPortion = 1 / nPhotos,
					}

	-- remove all photos from rendering process to speed up the process
	for _, rendition in exportSession:renditions() do
		rendition:skipRender()
	end

	local dirsCreated = {}
	local albumsForCheckEmpty
	local skipPhoto = false 	-- continue flag

	for _, rendition in exportContext:renditions{ stopIfCanceled = true } do
		local publishedPhotoId = rendition.publishedPhotoId		-- only required for publishing
		local newPublishedPhotoId = nil

		-- Wait for next photo to render.
		local success, pathOrMessage = rendition:waitForRender()

		-- Check for cancellation again after photo has been rendered.
		if progressScope:isCanceled() then break end

		if success then
			writeLogfile(3, "MovePhotos: next photo: " .. pathOrMessage .. "\n")

			local srcPhoto = rendition.photo
			local srcPath = srcPhoto:getRawMetadata("path")
			local srcFilename = LrPathUtils.leafName(srcPath)
			local renderedFilename = LrPathUtils.leafName( pathOrMessage )
			local renderedExtension = LrPathUtils.extension(renderedFilename)
			local dstRoot
			local dstDir
			local dstFilename

			progressScope:setCaption(LrPathUtils.leafName(srcPath))

			nProcessed = nProcessed + 1
			skipPhoto = false

			if not publishedPhotoId then
				writeLogfile(2, string.format('MovePhotos: Skipping "%s", was not yet published.\n', srcPhoto:getFormattedMetadata("fileName")))
				skipPhoto = true
			else
    			-- evaluate and sanitize dstRoot:
    			dstRoot = PSLrUtilities.evaluatePlaceholderString(exportParams.dstRoot, srcPhoto, 'path', publishedCollection)

    			-- file renaming:
    			--	if not Photo StatLr renaming then use srcFilename
    			if exportParams.renameDstFile then
    				dstFilename = PSLrUtilities.evaluatePlaceholderString(exportParams.dstFilename, srcPhoto, 'filename', publishedCollection)
    			else
    				dstFilename = srcFilename
    			end
       			dstFilename = 	LrPathUtils.replaceExtension(dstFilename, renderedExtension)

    			-- check if dstRoot or dstFilename contains missing required metadata ('?') (which means: skip photo)
    			skipPhoto = iif(string.find(dstRoot, '?', 1, true) or string.find(dstFilename, '?', 1, true), true, false)
				if skipPhoto then
					writeLogfile(2, string.format("MovePhotos: Skipping '%s' due to invalid target album '%s' or remote filename '%s'\n",
											srcPhoto:getFormattedMetadata("fileName"), dstRoot, dstFilename))
    			end
			end

			if not skipPhoto then
				-- generate a unique remote id for later modifications or deletions and for reference for metadata upload for videos
				-- use the relative destination pathname, so we are able to identify moved pictures
	    		local localPath, newPublishedPhotoId = PSLrUtilities.getPublishPath(srcPhoto, dstFilename, exportParams, dstRoot)

				writeLogfile(3, string.format("Old publishedPhotoId: '%s', New publishedPhotoId: '%s'\n",
				 								ifnil(publishedPhotoId, '<Nil>'), newPublishedPhotoId))

				-- if photo was renamed locally ...
				if LrPathUtils.leafName(publishedPhotoId) ~= LrPathUtils.leafName(newPublishedPhotoId) then
						writeLogfile(1, 'MovePhotos: Cannot move renamed photo from "' .. publishedPhotoId .. '" to "' .. newPublishedPhotoId .. '"!\n')
						skipPhoto = true

				-- if photo was moved locally ...
				elseif publishedPhotoId ~= newPublishedPhotoId then
					-- move photo within Photo Server
					local dstDir

     				-- check if target Album (dstRoot) should be created
    				if exportParams.createDstRoot and dstRoot ~= ''
    				and	not exportParams.photoServer:createTree('./' .. dstRoot,  ".", "", dirsCreated) then
						writeLogfile(1, 'MovePhotos: Cannot create album to move remote photo from "' .. publishedPhotoId .. '" to "' .. newPublishedPhotoId .. '"!\n')
						skipPhoto = true
    				elseif not exportParams.copyTree then
    					if not dstRoot or dstRoot == '' then
    						dstDir = '/'
    					else
    						dstDir = dstRoot
    					end
    				else
    					dstDir = exportParams.photoServer:createTree(LrPathUtils.parent(srcPath), exportParams.srcRoot, dstRoot,
    										dirsCreated)
    				end

					if not dstDir
					or not exportParams.photoServer:movePhoto(publishedPhotoId, dstDir, srcPhoto:getRawMetadata('isVideo')) then
						writeLogfile(1, 'MovePhotos: Cannot move remote photo from "' .. publishedPhotoId .. '" to "' .. newPublishedPhotoId .. '"!\n')
						skipPhoto = true
					else
						writeLogfile(2, 'MovePhotos: Moved photo from ' .. publishedPhotoId .. ' to ' .. newPublishedPhotoId .. '.\n')
						albumsForCheckEmpty = PSUtilities.noteFolder(albumsForCheckEmpty, publishedPhotoId)
					end
				else
						writeLogfile(2, 'MovePhotos: No need to move photo "'  .. newPublishedPhotoId .. '".\n')
				end
				if not skipPhoto then
					ackRendition(rendition, newPublishedPhotoId, publishedCollection.localIdentifier)
					nMoved = nMoved + 1
				end
			end
			LrFileUtils.delete( pathOrMessage )
	-- 		progressScope:setPortionComplete(nProcessed, nPhotos)
		end
	end

	local nDeletedAlbums = PSUtilities.deleteAllEmptyFolders(exportParams, albumsForCheckEmpty)

-- 	progressScope:done()

	return nPhotos, nProcessed, nMoved
end

--------------------------------------------------------------------------------
-- PSUploadTask.updateExportSettings(exportParams)
-- This plug-in defined callback function is called at the beginning
-- of each export and publish session before the rendition objects are generated.
function PSUploadTask.updateExportSettings(exportParams)
-- do some initialization stuff
-- local prefs = LrPrefs.prefsForPlugin()
--	writeLogfile(2, "updateExportSettings: starting...\n" )

	-- Start logging
	openLogfile(exportParams.logLevel)

	-- check for updates once a day
	LrTasks.startAsyncTaskWithoutErrorHandler(PSUpdate.checkForUpdate, "PSUploadCheckForUpdate")

	writeLogfile(3, "updateExportSettings: done\n" )
end

--------------------------------------------------------------------------------

-- PSUploadTask.processRenderedPhotos( functionContext, exportContext )
-- The export callback called from Lr when the export starts
function PSUploadTask.processRenderedPhotos( functionContext, exportContext )
--	writeLogfile(2, "processRenderedPhotos: starting...\n" )
	-- Make a local reference to the export parameters.
	local exportSession = exportContext.exportSession
	local exportParams = exportContext.propertyTable

	LrDialogs.attachErrorDialogToFunctionContext(functionContext)
	functionContext:addOperationTitleForError("Photo StatLr: That does it, I'm leaving!")
	functionContext:addCleanupHandler(PSLrUtilities.printError)

	local message
	local nPhotos
	local nProcessed = 0
	local nNotCopied = 0 	-- Publish / CheckExisting: num of pics not copied
	local nNeedCopy = 0 	-- Publish / CheckExisting: num of pics that need to be copied
	local timeUsed
	local timePerPic, picPerSec
	local publishMode

	writeLogfile(2, "processRenderedPhotos starting\n" )

	-- check if this rendition process is an export or a publish
	local publishedCollection = exportContext.publishedCollection
	if publishedCollection then
		-- set remoteCollectionId to localCollectionId: see PSPublishSupport.imposeSortOrderOnPublishedCollection()
		exportSession:recordRemoteCollectionId(publishedCollection.localIdentifier)
	else
		exportParams.publishMode = 'Export'
	end

	-- open session: initialize environment, get missing params and login
	local sessionSuccess, reason = openSession(exportParams, publishedCollection, "ProcessRenderedPhotos")
	if not sessionSuccess then
		if reason ~= 'cancel' then
			showFinalMessage("Photo StatLr: " .. exportParams.publishMode .. " failed!", reason, "critical")
		end
		closeLogfile()
		return
	end

	-- publishMode may have changed from 'Ask' to something different
	publishMode = exportParams.publishMode
	writeLogfile(2, "processRenderedPhotos(mode: " .. publishMode .. ").\n")

	local startTime = LrDate.currentTime()

	if publishMode == "Convert" then
		local nConverted
		nPhotos, nProcessed, nConverted = PSLrUtilities.convertCollection(functionContext, publishedCollection)

    	timeUsed =  LrDate.currentTime() - startTime
    	picPerSec = nProcessed / timeUsed

    	message = LOC ("$$$/PSUpload/FinalMsg/ConvertCollection=Processed ^1 of ^2 photos, ^3 converted in ^4 seconds (^5 pics/sec).",
    											nProcessed, nPhotos, nConverted, string.format("%.1f", timeUsed + 0.5), string.format("%.1f", picPerSec))
		showFinalMessage("Photo StatLr: " .. publishMode .. " done", message, "info")
		closeLogfile()
		closeSession(exportParams)
		return
	elseif publishMode == "CheckMoved" then
		local nMoved
		local albumPath = PSLrUtilities.getCollectionUploadPath(publishedCollection)

		if not (exportParams.copyTree or PSLrUtilities.isDynamicAlbumPath(albumPath)) then
			message = LOC ("$$$/PSUpload/FinalMsg/CheckMoved/Error/NotNeeded=Photo StatLr (CheckMoved): Makes no sense on flat copy albums to check for moved pics.\n")
		else
			nPhotos, nProcessed, nMoved = checkMoved(publishedCollection, exportContext, exportParams)
			timeUsed = 	LrDate.currentTime() - startTime
			picPerSec = nProcessed / timeUsed
			message = LOC("$$$/PSUpload/FinalMsg/CheckMoved=Checked ^1 of ^2 pics in ^3 seconds (^4 pics/sec). ^5 pics moved.\n",
											nProcessed, nPhotos, string.format("%.1f", timeUsed + 0.5), string.format("%.1f", picPerSec), nMoved)
		end
		showFinalMessage("Photo StatLr: " .. publishMode .. " done", message, "info")
		closeLogfile()
		closeSession(exportParams)
		return
	elseif publishMode == "MovePhotos" then
		local nMoved

		nPhotos, nProcessed, nMoved = movePhotos(publishedCollection, exportContext, exportParams)
		timeUsed = 	LrDate.currentTime() - startTime
		picPerSec = nProcessed / timeUsed
		message = LOC ("$$$/PSUpload/FinalMsg/Move=Processed ^1 of ^2 pics in ^3 seconds (^4 pics/sec). ^5 pics moved.\n",
										nProcessed, nPhotos, string.format("%.1f", timeUsed + 0.5), string.format("%.1f", picPerSec), nMoved)
		showFinalMessage("Photo StatLr: " .. publishMode .. " done", message, "info")
		closeLogfile()
		closeSession(exportParams)
		return
	end

	-- Set progress title.
	nPhotos = exportSession:countRenditions()

	local progressScope = exportContext:configureProgress {
						title = nPhotos > 1
							   and LOC( "$$$/PSUpload/Progress/Upload=Uploading ^1 photos to Photo Server", nPhotos )
							   or LOC "$$$/PSUpload/Progress/Upload/One=Uploading one photo to Photo Server",
					}

	writeLogfile(2, "--------------------------------------------------------------------\n")


	-- if is Publish process and publish mode is 'CheckExisting' or Metadata ...
	if string.find('CheckExisting,Metadata', publishMode, 1, true) then
		-- remove all photos from rendering process to speed up the process
		for i, rendition in exportSession:renditions() do
			rendition:skipRender()
		end
	end
	-- Iterate through photo renditions.
	local failures 					= {}
	local dirsCreated 				= {}
	local deferredMetadataUploads	= {}	-- videos and photos w/ location tags need a second run for metadata upload
	local sharedAlbumUpdates 		= {}	-- Shared Photo/Album handling is done after all uploads
	local sharedPhotoUpdates		= {}	-- Shared Photo/Album handling is done after all uploads
	local albumsForCheckEmpty				-- Album that might be empty after photos being moved to another target album
	local skipPhoto = false 		-- continue flag

	for _, rendition in exportContext:renditions{ stopIfCanceled = true } do
		local publishedPhotoId = rendition.publishedPhotoId		-- the remote photo path: required for publishing

		-- Wait for next photo to render.

		local success, pathOrMessage = rendition:waitForRender()

		-- Check for cancellation again after photo has been rendered.

		if progressScope:isCanceled() then break end

		if success then
			writeLogfile(3, "Next photo: " .. pathOrMessage .. "\n")

			local srcPhoto 			= rendition.photo
			local srcPath 			= srcPhoto:getRawMetadata("path")
			local srcFilename 		= LrPathUtils.leafName(srcPath)
			local renderedFilename 	= LrPathUtils.leafName(pathOrMessage)
			local renderedExtension = LrPathUtils.extension(renderedFilename)
			local dstRoot
			local dstDir
			local dstFilename

			progressScope:setCaption(srcFilename)

			nProcessed = nProcessed + 1

    		-- Cleanup plugin metadata for shared albums, if this is a new photo
    		if publishedCollection and not publishedPhotoId then
    			PSSharedAlbumMgmt.removePhotoPluginMetaLinkedSharedAlbumForCollection(srcPhoto, publishedCollection.localIdentifier)
    		end

			-- evaluate and sanitize dstRoot:
			--   substitute metadata tokens
			--   replace \ by /, remove leading and trailings slashes
			dstRoot = 		PSLrUtilities.evaluatePlaceholderString(exportParams.dstRoot, srcPhoto, 'path', publishedCollection)

			-- file renaming:
			--	if not Photo StatLr renaming
			--		if Export: 	use renderedFilename (Lr renaming options may have been turned on)
			--		else:		use srcFilename
			if exportParams.renameDstFile then
				dstFilename = PSLrUtilities.evaluatePlaceholderString(exportParams.dstFilename, srcPhoto, 'filename', publishedCollection)
			else
				dstFilename = iif(publishMode == 'Export', 	renderedFilename, srcFilename)
			end
   			dstFilename = 	LrPathUtils.replaceExtension(dstFilename, renderedExtension)

			-- check if dstRoot or dstFilename contains missing required metadata ('?') (which means: skip photo)
   			skipPhoto = iif(string.find(dstRoot, '?', 1, true) or string.find(dstFilename, '?', 1, true), true, false)

			writeLogfile(4, string.format("  sanitized dstRoot: '%s', dstFilename '%s'\n", dstRoot, dstFilename))

			local localPath, newPublishedPhotoId

			if skipPhoto then
				writeLogfile(2, string.format("%s: Skipping '%s' due to invalid target album '%s' or remote filename '%s'\n",
										publishMode, srcPhoto:getFormattedMetadata("fileName"), dstRoot, dstFilename))

				table.insert( failures, srcPath )
				rendition:uploadFailed("Invalid target album")
			else
				-- generate a unique remote id for later modifications or deletions and for reference for metadata upload for videos
				-- use the relative destination pathname, so we are able to identify moved pictures
	    		localPath, newPublishedPhotoId = PSLrUtilities.getPublishPath(srcPhoto, dstFilename, exportParams, dstRoot)

				writeLogfile(3, string.format("Old publishedPhotoId: '%s', New publishedPhotoId: '%s'\n",
				 								ifnil(publishedPhotoId, '<Nil>'), newPublishedPhotoId))
				-- if photo was moved ...
				if ifnil(publishedPhotoId, newPublishedPhotoId) ~= newPublishedPhotoId then
					-- remove photo at old location
					if publishMode == 'Publish' then
						if not exportParams.photoServer:deletePhoto(publishedPhotoId, srcPhoto:getRawMetadata('isVideo')) then
							writeLogfile(1, 'Cannot delete remote photo at old path: ' .. publishedPhotoId .. ', check Photo Server permissions!\n')
							table.insert( failures, srcPath )
							rendition:uploadFailed("Removal of photo at old taget failed")
							skipPhoto = true
						else
							-- note old remote album as possibly empty
							albumsForCheckEmpty = PSUtilities.noteFolder(albumsForCheckEmpty, publishedPhotoId)
						end
					elseif publishMode == 'Metadata' then
						writeLogfile(1, "Metadata Upload for '" .. publishedPhotoId .. "' - failed, photo must be uploaded to '" .. newPublishedPhotoId .."' at first!\n")
    					table.insert( failures, srcPath )
						rendition:uploadFailed("Metadata Upload failed, photo not yet uploaded")
						skipPhoto = true
					elseif publishMode == 'CheckExisting' then
						writeLogfile(2, 'CheckExisting: Would delete remote photo at old path: ' .. publishedPhotoId .. '\n')
					end
				end
				publishedPhotoId = newPublishedPhotoId
				dstFilename = LrPathUtils.leafName(publishedPhotoId)
			end

			if skipPhoto then
				-- continue w/ next photo
				skipPhoto = false
			elseif publishMode == 'CheckExisting' then
				-- check if photo already in Photo Server
				local psPhoto, errorCode = exportParams.photoServer.Photo.new(exportParams.photoServer, publishedPhotoId,
																		srcPhoto:getRawMetadata('isVideo'), 'photo', PHOTOSERVER_USE_CACHE)
				if psPhoto then
					writeLogfile(2, string.format('CheckExisting: No upload needed for "%s" to "%s" \n', srcPhoto:getRawMetadata('path'), publishedPhotoId))
					ackRendition(rendition, publishedPhotoId, publishedCollection.localIdentifier)
					nNotCopied = nNotCopied + 1
					PSSharedAlbumMgmt.noteSharedAlbumUpdates(sharedAlbumUpdates, sharedPhotoUpdates, srcPhoto, publishedPhotoId, publishedCollection.localIdentifier, exportParams)
				else -- error
					nNeedCopy = nNeedCopy + 1
					table.insert( failures, srcPath )
					rendition:uploadFailed("Check existing photo failed")
					writeLogfile(2, string.format("CheckExisting: Upload required for '%s' to '%s' (errorCode: '%s')\n",
												srcPhoto:getRawMetadata('path'), newPublishedPhotoId, ifnil(errorCode, '<nil>')))
				end
			elseif string.find('Export,Publish,Metadata', publishMode, 1, true) then

				if publishMode == 'Metadata' then
					dstDir = string.match(publishedPhotoId , '(.*)/[^/]+')
				else
    				-- normal publish or export process
    				-- check if target Album (dstRoot) should be created
    				if exportParams.createDstRoot and dstRoot ~= '' and
    					not exportParams.photoServer:createTree('./' .. dstRoot,  ".", "", dirsCreated) then
    					table.insert( failures, srcPath )
						rendition:uploadFailed("Target album creation failed")
    					break
    				end

    				-- check if tree structure should be preserved
    				if not exportParams.copyTree then
    					-- just put it into the configured destination folder
    					if not dstRoot or dstRoot == '' then
    						dstDir = '/'
    					else
    						dstDir = dstRoot
    					end
    				else
    					dstDir = exportParams.photoServer:createTree(LrPathUtils.parent(srcPath), exportParams.srcRoot, dstRoot,
    										dirsCreated)
    				end

    				if not dstDir then
    					table.insert( failures, srcPath )
						rendition:uploadFailed("Target album missing")
    					break
    				end
				end

				local vinfo
				if srcPhoto:getRawMetadata("isVideo") then
					-- if publishMode is 'Metadata' we just extract metadata
					-- else we extract metadata plus video infos from the rendered video
					vinfo = exportParams.converter:ffmpegGetAdditionalInfo(srcPhoto,
																iif(publishMode == 'Metadata', nil, pathOrMessage),
																exportParams)
				end

				if (publishMode == 'Metadata'
					and (	not	uploadMetadata(srcPhoto, vinfo, publishedPhotoId, exportParams, vinfo)
						 or not ackRendition(rendition, publishedPhotoId, publishedCollection.localIdentifier))
					)
				or (string.find('Export,Publish', publishMode, 1, true) and srcPhoto:getRawMetadata("isVideo")
					and	(	not vinfo or
							not uploadVideo(pathOrMessage, srcPhoto, dstDir, dstFilename, exportParams, vinfo)
						-- upload of metadata to recently uploaded videos must wait until PS has registered it
						-- this may take some seconds (approx. 15s), so note the video here and defer metadata upload to a second run
						 or (not publishedCollection and not noteForDeferredMetadataUpload(deferredMetadataUploads, rendition, publishedPhotoId, vinfo, nil))
						 or (    publishedCollection and not noteForDeferredMetadataUpload(deferredMetadataUploads, rendition, publishedPhotoId, vinfo, publishedCollection.localIdentifier))
						)
					)
				or (string.find('Export,Publish', publishMode, 1, true) and not srcPhoto:getRawMetadata("isVideo")
					and (
							 not	uploadPhoto(pathOrMessage, srcPhoto, dstDir, dstFilename, exportParams)
						 -- (not exportParams.xlatLocationTags and not publishedCollection) --> OK, no more actions required
						 or (not exportParams.xlatLocationTags and     publishedCollection and not ackRendition(rendition, publishedPhotoId, publishedCollection.localIdentifier))
						 or (	 exportParams.xlatLocationTags and not publishedCollection and not noteForDeferredMetadataUpload(deferredMetadataUploads, rendition, publishedPhotoId, nil, nil))
						 or (	 exportParams.xlatLocationTags and     publishedCollection and not noteForDeferredMetadataUpload(deferredMetadataUploads, rendition, publishedPhotoId, nil, publishedCollection.localIdentifier))
						)
					)
				then
					if string.find('Export,Publish', publishMode, 1, true) then	writeLogfile(1, "Upload of '" .. srcPhoto:getRawMetadata('path') .. "' to '" .. LrPathUtils.child(dstDir, dstFilename) .. "' failed!!!\n") end
					table.insert( failures, srcPath )
					rendition:uploadFailed("Upload failed")
				else
					if publishedCollection then
						PSSharedAlbumMgmt.noteSharedAlbumUpdates(sharedAlbumUpdates, sharedPhotoUpdates, srcPhoto, publishedPhotoId, publishedCollection.localIdentifier, exportParams)
					end
					if string.find('Export,Publish', publishMode, 1, true) then writeLogfile(2, "Upload of '" .. srcPhoto:getRawMetadata('path') .. "' to '" .. LrPathUtils.child(dstDir, dstFilename) .. "' done\n") end
				end
			end

			-- do some video metadata upload in between
			if #deferredMetadataUploads > 9 then
				batchUploadMetadata(functionContext, deferredMetadataUploads, exportParams, failures)
				deferredMetadataUploads = {}
			end

			LrFileUtils.delete( pathOrMessage )
		end
	end

	-- deferred metadata upload
	if #deferredMetadataUploads > 0 then batchUploadMetadata(functionContext, deferredMetadataUploads, exportParams, failures) end
	if #sharedAlbumUpdates > 0 then PSSharedAlbumMgmt.updateSharedAlbums(functionContext, sharedAlbumUpdates, sharedPhotoUpdates, exportParams) end

	-- delete all empty album: albums may be emptied through photos being moved to another target album
	PSUtilities.deleteAllEmptyFolders(exportParams, albumsForCheckEmpty)

	writeLogfile(2,"--------------------------------------------------------------------\n")
	closeSession(exportParams)

	timeUsed = 	LrDate.currentTime() - startTime
	timePerPic = timeUsed / nProcessed
	picPerSec = nProcessed / timeUsed

	if #failures > 0 then
		message = LOC ("$$$/PSUpload/FinalMsg/Upload/Error=Processed ^1 of ^2 pics in ^3 seconds (^4 secs/pic). ^5 failed to upload.",
						nProcessed, nPhotos, string.format("%.1f", timeUsed + 0.5), string.format("%.1f", timePerPic), #failures)
--		local action = LrDialogs.confirm(message, table.concat( failures, "\n" ), "Go to Logfile", "Never mind")
		local action = LrDialogs.confirm(message, "List of failed uploads follows ...\n\nAdditional info can be found in logfile.", "Go to Logfile", "Never mind")
		if action == "ok" then
			LrShell.revealInShell(getLogFilename())
		end
	else
		if publishMode == 'CheckExisting' then
			message = LOC ("$$$/PSUpload/FinalMsg/CheckExist=Checked ^1 of ^2 files in ^3 seconds (^4 pics/sec). ^5 already there, ^6 need export.",
											nProcessed, nPhotos, string.format("%.1f", timeUsed + 0.5), string.format("%.1f", picPerSec), nNotCopied, nNeedCopy)
		elseif publishMode == 'Metadata' then
			message = LOC ("$$$/PSUpload/FinalMsg/Metadata=Uploaded metadata for ^1 of ^2 files in ^3 seconds (^4 secs/pic).",
											nProcessed, nPhotos, string.format("%.1f", timeUsed + 0.5), string.format("%.1f", timePerPic))
		else
			message = LOC ("$$$/PSUpload/FinalMsg/Upload=Uploaded ^1 of ^2 files in ^3 seconds (^4 secs/pic).",
											nProcessed, nPhotos, string.format("%.1f", timeUsed + 0.5), string.format("%.1f", timePerPic))
		end
		showFinalMessage("Photo StatLr: " .. publishMode .. " done", message, "info")
		closeLogfile()
	end
-- 	writeLogfile(2, "processRenderedPhotos: done.\n" )
end
