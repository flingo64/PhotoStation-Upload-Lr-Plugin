--[[----------------------------------------------------------------------------

PSUploadTask.lua
Upload photos to Synology Photo Station via HTTP(S) WebService
Copyright(c) 2015, Martin Messmer

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

Photo StatLr uses the following free software to do its job:
	- convert.exe,			see: http://www.imagemagick.org/
	- ffmpeg.exe, 			see: https://www.ffmpeg.org/
	- qt-faststart.exe, 	see: http://multimedia.cx/eggs/improving-qt-faststart/

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
local LrApplication = import 'LrApplication'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrDate = import 'LrDate'
local LrDialogs = import 'LrDialogs'
local LrProgressScope = import 'LrProgressScope'
local LrShell = import 'LrShell'
local LrPrefs = import 'LrPrefs'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'

require "PSUtilities"
require "PSLrUtilities"
require "PSConvert"
require "PSUpdate"
require "PSUploadAPI"
require "PSPhotoStationAPI"
require "PSPhotoStationUtils"
require "PSExiftoolAPI"

--============================================================================--
		
PSUploadTask = {}

-----------------


-- function createTree(uHandle, srcDir, srcRoot, dstRoot, dirsCreated) 
-- 	derive destination folder: dstDir = dstRoot + (srcRoot - srcDir), 
--	create each folder recursively if not already created
-- 	store created directories in dirsCreated
-- 	return created dstDir or nil on error
local function createTree(uHandle, srcDir, srcRoot, dstRoot, dirsCreated) 
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
	local dstDir = dstRoot .."/" .. dstDirRel

	writeLogfile(4,"  createTree: dstDir is: " .. dstDir .. "\n")
	
	local parentDir = dstRoot
	local restDir = dstDirRel
	
	while restDir do
		local slashPos = ifnil(string.find(restDir,"/", 1, true), 0)
		local newDir = string.sub(restDir,1, slashPos-1)
		local newPath = parentDir .. "/" .. newDir

		if not dirsCreated[newPath] then
			writeLogfile(2,"Create dir - parent: " .. parentDir .. " newDir: " .. newDir .. " newPath: " .. newPath .. "\n")
			
			local paramParentDir
			if parentDir == "" then paramParentDir = "/" else paramParentDir = parentDir  end  
			if not PSUploadAPI.createFolder (uHandle, paramParentDir, newDir) then
				writeLogfile(1,"Create dir - parent: " .. paramParentDir .. " newDir: " .. newDir .. " failed!\n")
				return nil
			end
			dirsCreated[newPath] = true
		else
			writeLogfile(4,"  Directory: " .. newPath .. " already created\n")						
		end
	
		parentDir = newPath
		if slashPos == 0 then
			restDir = nil
		else
			restDir = string.sub(restDir, slashPos + 1)
		end
	end
	
	return dstDir
end

----------------- thumbnail conversion presets 

local thumbSharpening = {
	None 	= 	'',
	LOW 	= 	'-unsharp 0.5x0.5+0.5+0.008',
	MED 	= 	'-unsharp 0.5x0.5+1.25+0.0',
	HIGH 	= 	'-unsharp 0.5x0.5+2.0+0.0',
}

-----------------
-- uploadPhoto(renderedPhotoPath, srcPhoto, dstDir, dstFilename, exportParams) 
--[[
	generate all required thumbnails and upload thumbnails and the original picture as a batch.
	The upload batch must start with any of the thumbs and end with the original picture.
	When uploading to Photo Station 6, we don't need to upload the THUMB_L
]]
local function uploadPhoto(renderedPhotoPath, srcPhoto, dstDir, dstFilename, exportParams) 
	local picBasename = mkSafeFilename(LrPathUtils.removeExtension(LrPathUtils.leafName(renderedPhotoPath)))
	local picExt = 'jpg'
	local picDir = LrPathUtils.parent(renderedPhotoPath)
	local thmb_XL_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_XL', picExt))
	local thmb_L_Filename = iif(not exportParams.isPS6, LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_L', picExt)), '')
	local thmb_M_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_M', picExt))
	local thmb_B_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_B', picExt))
	local thmb_S_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_S', picExt))
	local title_Filename  = iif(ifnil(srcPhoto:getFormattedMetadata("title"), '') ~= '', 
							LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_TITLE', 'txt')), nil)
	local srcDateTime = PSLrUtilities.getDateTimeOriginal(srcPhoto)
	local exifXlatLabelCmd = iif(exportParams.exifXlatLabel and not string.find('none,grey', string.lower(srcPhoto:getRawMetadata('colorNameForLabel'))), "-XMP:Subject+=" .. '+' .. srcPhoto:getRawMetadata('colorNameForLabel'), nil)
	local retcode
	
	-- generate thumbs	
	if exportParams.thumbGenerate and ( 
			( not exportParams.largeThumbs and not PSConvert.convertPicConcurrent(exportParams.cHandle, renderedPhotoPath, srcPhoto, exportParams.LR_format,
								'-flatten -quality '.. tostring(exportParams.thumbQuality) .. ' -auto-orient '.. thumbSharpening[exportParams.thumbSharpness], 
								'1280x1280>', thmb_XL_Filename,
								'800x800>',    thmb_L_Filename,
								'640x640>',    thmb_B_Filename,
								'320x320>',    thmb_M_Filename,
								'120x120>',    thmb_S_Filename) )
		or ( exportParams.largeThumbs and not PSConvert.convertPicConcurrent(exportParams.cHandle, renderedPhotoPath, srcPhoto, exportParams.LR_format,
								'-flatten -quality '.. tostring(exportParams.thumbQuality) .. ' -auto-orient '.. thumbSharpening[exportParams.thumbSharpness], 
								'1280x1280>^', thmb_XL_Filename,
								'800x800>^',   thmb_L_Filename,
								'640x640>^',   thmb_B_Filename,
								'320x320>^',   thmb_M_Filename,
								'120x120>^',   thmb_S_Filename) )
	)
	
	-- if photo has a title: generate a title file  	
	or (title_Filename and not PSConvert.writeTitleFile(title_Filename, srcPhoto:getFormattedMetadata("title")))

	-- exif translations: avoid calling doExifTranslations() if nothing's there to translate
	or ((exifXlatLabelCmd or exportParams.exifXlatFaceRegions or exportParams.exifXlatRating) 
		and not PSExiftoolAPI.doExifTranslations(exportParams.eHandle, renderedPhotoPath, exifXlatLabelCmd))
--	or (exportParams.exifTranslate and not PSExiftoolAPI.doExifTranslations(exportParams.eHandle, renderedPhotoPath, exifXlatLabelCmd))

	-- wait for Photo Station semaphore
	or not waitSemaphore("PhotoStation", dstFilename)

	-- delete old before uploading new
--	or not PSPhotoStationAPI.deletePic (exportParams.uHandle, dstDir .. '/' .. dstFilename, false) 
	
	-- upload thumbnails and original file
	or exportParams.thumbGenerate and (
		   not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_B_Filename, srcDateTime, dstDir, dstFilename, 'THUM_B', 'image/jpeg', 'FIRST') 
		or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_M_Filename, srcDateTime, dstDir, dstFilename, 'THUM_M', 'image/jpeg', 'MIDDLE') 
		or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_S_Filename, srcDateTime, dstDir, dstFilename, 'THUM_S', 'image/jpeg', 'MIDDLE') 
		or (not exportParams.isPS6 and not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_L_Filename, srcDateTime, dstDir, dstFilename, 'THUM_L', 'image/jpeg', 'MIDDLE'))
		or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_XL_Filename, srcDateTime, dstDir, dstFilename, 'THUM_XL', 'image/jpeg', 'MIDDLE')
	) 
	or (title_Filename and not PSUploadAPI.uploadPictureFile(exportParams.uHandle, title_Filename, srcDateTime, dstDir, dstFilename, 'CUST_TITLE', 'text', 'MIDDLE'))
	or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, renderedPhotoPath, srcDateTime, dstDir, dstFilename, 'ORIG_FILE', 'image/jpeg', 'LAST')
	then
		signalSemaphore("PhotoStation")
		retcode = false
	else
		signalSemaphore("PhotoStation")
		retcode = true
	end

	if exportParams.thumbGenerate then
		LrFileUtils.delete(thmb_B_Filename)
		LrFileUtils.delete(thmb_M_Filename)
		LrFileUtils.delete(thmb_S_Filename)
		if not exportParams.isPS6 then LrFileUtils.delete(thmb_L_Filename) end
		LrFileUtils.delete(thmb_XL_Filename)
		if title_Filename then LrFileUtils.delete(title_Filename) end
	end
	
	return retcode
end

-----------------
-- uploadVideo(renderedVideoPath, srcPhoto, dstDir, dstFilename, exportParams, addVideo, orgVideoInfo) 
--[[
	generate all required thumbnails, at least one video with alternative resolution (if we don't do, Photo Station will do)
	and upload thumbnails, alternative video and the original video as a batch.
	The upload batch must start with any of the thumbs and end with the original video.
	When uploading to Photo Station 6, we don't need to upload the THUMB_L
]]
local function uploadVideo(renderedVideoPath, srcPhoto, dstDir, dstFilename, exportParams, addVideo, orgVideoInfo) 
	local picBasename = mkSafeFilename(LrPathUtils.removeExtension(LrPathUtils.leafName(renderedVideoPath)))
	local vidExtOrg = LrPathUtils.extension(renderedVideoPath)
	local picDir = LrPathUtils.parent(renderedVideoPath)
	local picExt = 'jpg'
	local vidExt = 'mp4'
	local thmb_ORG_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename, picExt))
	local thmb_XL_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_XL', picExt))
	local thmb_L_Filename = iif(not exportParams.isPS6, LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_L', picExt)), '')
	local thmb_M_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_M', picExt))
	local thmb_B_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_B', picExt))
	local thmb_S_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_S', picExt))
	local vid_MOB_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_MOB', vidExt)) 	--  240p
	local vid_LOW_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_LOW', vidExt))	--  360p
	local vid_MED_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_MED', vidExt))	--  720p
	local vid_HIGH_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_HIGH', vidExt))	-- 1080p
	local title_Filename  	= iif(ifnil(srcPhoto:getFormattedMetadata("title"), '') ~= '', 
							  LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_TITLE', 'txt')), nil)
	local realDimension
	local retcode
	local convKeyOrig, convKeyAdd
	local vid_Orig_Filename, vid_Replace_Filename, vid_Add_Filename
	
	writeLogfile(3, string.format("uploadVideo: %s\n", renderedVideoPath)) 

	local convParams = { 
		HIGH =  	{ height = 1080,	filename = vid_HIGH_Filename },
		MEDIUM = 	{ height = 720, 	filename = vid_MED_Filename },
		LOW =		{ height = 360, 	filename = vid_LOW_Filename },
		MOBILE =	{ height = 240,		filename = vid_MOB_Filename },
	}
	
	-- there is no way to identify whether the video is exported as original or rendered
	-- --> get both video infos 
	-- get rendered video infos: DateTimeOrig, duration, dimension, sample aspect ratio, display aspect ratio
	local vinfo = PSConvert.ffmpegGetAdditionalInfo(exportParams.cHandle, renderedVideoPath)
	if not (vinfo and orgVideoInfo) then
		return false
	end
	
	-- restore the capture time for the rendered video
	vinfo.srcDateTime = orgVideoInfo.srcDateTime
	-- look also for DateTimeOriginal in Metadata: if metadata include DateTimeOrig, then this will 
	-- overwrite the ffmpeg DateTimeOrig 
	local metaDateTime, isOrigDateTime = PSLrUtilities.getDateTimeOriginal(srcPhoto)
	if isOrigDateTime or not vinfo.srcDateTime then
		vinfo.srcDateTime = metaDateTime
	end
	
	-- get the real dimension: may be different from dimension if dar is set
	-- dimension: NNNxMMM
	local srcHeight = tonumber(string.sub(vinfo.dimension, string.find(vinfo.dimension,'x') + 1, -1))
	if (ifnil(vinfo.dar, '') == '') or (ifnil(vinfo.sar,'') == '1:1') then
		realDimension = vinfo.dimension
		-- aspectRatio: NNN:MMM
		vinfo.dar = string.gsub(vinfo.dimension, 'x', ':')
	else
		local darWidth = tonumber(string.sub(vinfo.dar, 1, string.find(vinfo.dar,':') - 1))
		local darHeight = tonumber(string.sub(vinfo.dar, string.find(vinfo.dar,':') + 1, -1))
		local realSrcWidth = math.floor(((srcHeight * darWidth / darHeight) + 0.5) / 2) * 2 -- make sure width is an even integer
		realDimension = string.format("%dx%d", realSrcWidth, srcHeight)
	end
	
	-- get the right conversion settings (depending on Height)
	_, convKeyOrig = PSConvert.getConvertKey(exportParams.cHandle, srcHeight)
	vid_Replace_Filename = convParams[convKeyOrig].filename
	convKeyAdd = addVideo[convKeyOrig]
	if convKeyAdd ~= 'None' then
		vid_Add_Filename = convParams[convKeyAdd].filename
	end

	-- search for "Rotate-nn" in keywords, this will add/overwrite rotation infos from mpeg header
	local addRotate = false
	local keywords = srcPhoto:getRawMetadata("keywords")
	for i = 1, #keywords do
		if string.find(keywords[i]:getName(), 'Rotate-', 1, true) then
			local metaRotation = string.sub (keywords[i]:getName(), 8)
			if metaRotation ~= vinfo.rotation then
				vinfo.rotation = metaRotation
				addRotate = true
				break
			end
			writeLogfile(3, string.format("Keyword[%d]= %s, rotation= %s\n", i, keywords[i]:getName(), vinfo.rotation))
		end
	end

	-- video rotation only if requested by export param or by keyword (meta-rotation)
	local videoRotation = '0'
	if exportParams.hardRotate or addRotate then
		videoRotation = vinfo.rotation
	end
	
	-- replace original video if srcVideo is to be rotated (meta or hard)
	local replaceOrgVideo = false
	if videoRotation ~= '0' then
		replaceOrgVideo = true
		vid_Orig_Filename = vid_Replace_Filename
	else
		vid_Orig_Filename = renderedVideoPath
	end

	-- Additional MP4 in orig dimension if video is not MP4
	local addOrigAsMp4 = false
	if not PSConvert.videoIsNativePSFormat(vidExtOrg) and not replaceOrgVideo then
		addOrigAsMp4 = true
	end
	
	if exportParams.thumbGenerate and ( 
		-- generate first thumb from video, rotation has to be done regardless of the hardRotate setting
		not PSConvert.ffmpegGetThumbFromVideo (exportParams.cHandle, renderedVideoPath, thmb_ORG_Filename, realDimension, vinfo.rotation, vinfo.duration)

		-- generate all other thumb from first thumb
		or ( not exportParams.largeThumbs and not PSConvert.convertPicConcurrent(exportParams.cHandle, thmb_ORG_Filename, srcPhoto, exportParams.LR_format,
--								'-strip -flatten -quality '.. tostring(exportParams.thumbQuality) .. ' -auto-orient -colorspace RGB -unsharp 0.5x0.5+1.25+0.0 -colorspace sRGB', 
								'-flatten -quality '.. tostring(exportParams.thumbQuality) .. ' -auto-orient '.. thumbSharpening[exportParams.thumbSharpness], 
								'1280x1280>', thmb_XL_Filename,
								'800x800>',    thmb_L_Filename,
								'640x640>',    thmb_B_Filename,
								'320x320>',    thmb_M_Filename,
								'120x120>',    thmb_S_Filename) )
	
		or ( exportParams.largeThumbs and not PSConvert.convertPicConcurrent(exportParams.cHandle, thmb_ORG_Filename, srcPhoto, exportParams.LR_format,
--								'-strip -flatten -quality '.. tostring(exportParams.thumbQuality) .. ' -auto-orient -colorspace RGB -unsharp 0.5x0.5+1.25+0.0 -colorspace sRGB', 
								'-flatten -quality '.. tostring(exportParams.thumbQuality) .. ' -auto-orient '.. thumbSharpening[exportParams.thumbSharpness], 
								'1280x1280>^', thmb_XL_Filename,
								'800x800>^',   thmb_L_Filename,
								'640x640>^',   thmb_B_Filename,
								'320x320>^',   thmb_M_Filename,
								'120x120>^',   thmb_S_Filename) )
	)

	-- generate mp4 in original size if srcVideo is not already mp4 or if video is rotated
	or ((replaceOrgVideo or addOrigAsMp4) and not PSConvert.convertVideo(exportParams.cHandle, renderedVideoPath, vinfo.srcDateTime, vinfo.dar, srcHeight, exportParams.hardRotate, videoRotation, vid_Replace_Filename))
	
	-- generate additional video, if requested
	or ((convKeyAdd ~= 'None') and not PSConvert.convertVideo(exportParams.cHandle, renderedVideoPath, vinfo.srcDateTime, vinfo.dar, convParams[convKeyAdd].height, exportParams.hardRotate, videoRotation, vid_Add_Filename))

	-- if photo has a title: generate a title file  	
	or (title_Filename and not PSConvert.writeTitleFile(title_Filename, srcPhoto:getFormattedMetadata("title")))

	-- wait for Photo Station semaphore
	or not waitSemaphore("PhotoStation", dstFilename)
	
	-- delete old before uploading new
	or not PSPhotoStationAPI.deletePic (exportParams.uHandle, dstDir .. '/' .. dstFilename, true) 

	or exportParams.thumbGenerate and (
		-- upload thumbs, preview videos and original file
		   not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_B_Filename, vinfo.srcDateTime, dstDir, dstFilename, 'THUM_B', 'image/jpeg', 'FIRST') 
		or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_M_Filename, vinfo.srcDateTime, dstDir, dstFilename, 'THUM_M', 'image/jpeg', 'MIDDLE') 
		or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_S_Filename, vinfo.srcDateTime, dstDir, dstFilename, 'THUM_S', 'image/jpeg', 'MIDDLE') 
		or (not exportParams.isPS6 and not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_L_Filename, vinfo.srcDateTime, dstDir, dstFilename, 'THUM_L', 'image/jpeg', 'MIDDLE')) 
		or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_XL_Filename, vinfo.srcDateTime, dstDir, dstFilename, 'THUM_XL', 'image/jpeg', 'MIDDLE')
	) 
	or ((convKeyAdd ~= 'None') and not PSUploadAPI.uploadPictureFile(exportParams.uHandle, vid_Add_Filename, vinfo.srcDateTime, dstDir, dstFilename, 'MP4_'.. convKeyAdd, 'video/mpeg', 'MIDDLE'))
	or (addOrigAsMp4	 	   and not PSUploadAPI.uploadPictureFile(exportParams.uHandle, vid_Replace_Filename, vinfo.srcDateTime, dstDir, dstFilename, 'MP4_'.. convKeyOrig, 'video/mpeg', 'MIDDLE'))
	-- upload at least one mp4 file to avoid the generation of a flash video by synomediaparserd
	or ((convKeyAdd == 'None') and not addOrigAsMp4
	 	   						and not PSUploadAPI.uploadPictureFile(exportParams.uHandle, vid_Orig_Filename, vinfo.srcDateTime, dstDir, dstFilename, 'MP4_'.. convKeyOrig, 'video/mpeg', 'MIDDLE'))
	or (title_Filename and not PSUploadAPI.uploadPictureFile(exportParams.uHandle, title_Filename, vinfo.srcDateTime, dstDir, dstFilename, 'CUST_TITLE', 'text', 'MIDDLE'))
	or 							   not PSUploadAPI.uploadPictureFile(exportParams.uHandle, vid_Orig_Filename, vinfo.srcDateTime, dstDir, dstFilename, 'ORIG_FILE', 'video/mpeg', 'LAST') 
	then 
		signalSemaphore("PhotoStation")
		retcode = false
	else 
		signalSemaphore("PhotoStation")
		retcode = true
	end
	
	if exportParams.thumbGenerate then
    	LrFileUtils.delete(thmb_ORG_Filename)
    	LrFileUtils.delete(thmb_B_Filename)
    	LrFileUtils.delete(thmb_M_Filename)
    	LrFileUtils.delete(thmb_S_Filename)
    	if not exportParams.isPS6 then LrFileUtils.delete(thmb_L_Filename) end
    	LrFileUtils.delete(thmb_XL_Filename)
    	LrFileUtils.delete(vid_Orig_Filename)
    	if vid_Add_Filename then LrFileUtils.delete(vid_Add_Filename) end
		if title_Filename then LrFileUtils.delete(title_Filename) end
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
-- noteVideoUpload(videosUploaded, rendition, publishedPhotoId, videoInfo, publishedCollectionId)
local function noteVideoUpload(videosUploaded, rendition, publishedPhotoId, videoInfo, publishedCollectionId)
	local videoUploaded = {}
	
	writeLogfile(3, string.format("noteVideoUpload(%s)\n", publishedPhotoId))
	videoUploaded.rendition 			= rendition
	videoUploaded.publishedPhotoId 		= publishedPhotoId
	videoUploaded.publishedCollectionId = publishedCollectionId
	videoUploaded.latitude 				= videoInfo.latitude
	videoUploaded.longitude 			= videoInfo.longitude
	table.insert(videosUploaded, videoUploaded)
	
	return true
end

-----------------
-- uploadVideoMetadata(functionContext, videosUploaded, exportParams, failures) 
-- upload metadata for videos just uploaded
local function uploadVideoMetadata(functionContext, videosUploaded, exportParams, failures)
	local catalog = LrApplication.activeCatalog()
	local nVideos =  #videosUploaded
	local nProcessed 		= 0 
		
	writeLogfile(3, string.format("uploadVideoMetadata: %d videos\n", nVideos))
	local catalog = LrApplication.activeCatalog()
	local progressScope = LrProgressScope( 
								{ 	title = LOC( "$$$/PSUpload/Progress/UploadVideoMeta=Uploading metadata for ^1 videos", nVideos),
							 		functionContext = functionContext 
							 	})    
	while #videosUploaded > 0 do
		local videoUploaded 			= videosUploaded[1]
		local rendition 				= videoUploaded.rendition
		local srcPhoto 					= rendition.photo
		local dstFilename 				= videoUploaded.publishedPhotoId
		local publishedCollectionId 	= videoUploaded.publishedCollectionId
		local latitude					= videoUploaded.latitude
		local longitude					= videoUploaded.longitude
		
		-- get caption if requested
		local captionParam
		local captionData = srcPhoto:getFormattedMetadata("caption")
		if ifnil(captionData, '') ~= '' then
			captionParam = { { attribute =  'description', value = captionData } }
		end

		-- get label if requested
		local labelParam
		if exportParams.exifXlatLabel then
			local labelData = srcPhoto:getRawMetadata("colorNameForLabel")
			labelParam = iif(ifnil(labelData, 'grey') ~= 'grey', '+' .. labelData, nil)
		end
		
		-- PS6.5 and later: always get rating
		local ratingParam
		local ratingData = srcPhoto:getFormattedMetadata("rating")
		if exportParams.psVersion >= 65 and ifnil(ratingData, 0) ~= 0 then
			ratingParam = { { attribute =  'rating', value = tostring(ratingData) } }
		end
		
		-- get ratingTag if requested
		local ratingTagParam
		if exportParams.exifXlatRating and ifnil(ratingData, 0) ~= 0 then
			ratingTagParam =  PSPhotoStationUtils.rating2Stars(ratingData)
		end
		
		-- get keywords if requested
		local keywordNamesAdd
		if not exportParams.LR_minimizeEmbeddedMetadata then
			keywordNamesAdd = trimTable(split(srcPhoto:getFormattedMetadata("keywordTagsForExport"), ','))
		end
		
		-- get GPS if requested
		-- Lr GPS data has precedence over video embedded GPS data
		local gpsParam
		if not exportParams.LR_removeLocationMetadata then
			local gpsData = srcPhoto:getRawMetadata("gps")
			if gpsData and gpsData.latitude and gpsData.longitude then
				gpsParam = { 
					{ attribute =  'gps_lat', value = gpsData.latitude },
					{ attribute =  'gps_lng', value = gpsData.longitude } 
				}
			elseif latitude and longitude then 
				gpsParam = { 
					{ attribute =  'gps_lat', value = latitude },
					{ attribute =  'gps_lng', value = longitude } 
				}
			end
		end
				
		-- if any metadata to add: wait for video being indexed by PS and upload metadata thereafter
		if captionParam or labelParam or ratingParam or ratingTagParam or (keywordNamesAdd and #keywordNamesAdd  > 0) or gpsParam then
			local photoThere 
			local maxWait = 60
			
			while not photoThere and maxWait > 0 do
				local isVideo, dontUseCache = true, false
				if not PSPhotoStationUtils.getPhotoInfo(exportParams.uHandle, dstFilename, isVideo, dontUseCache) then
					LrTasks.sleep(1)
					maxWait = maxWait - 1
				else
					photoThere = true
				end
			end
			
			local gpsLatLong
			if gpsParam then
				gpsLatLong = gpsParam[1].value .. '/' .. gpsParam[2].value
			end
			local logMessage = string.format("Metadata Upload for '%s' -  description: '%s', label: '%s', rating: '%d' ratingTag: '%s' keywords: '%s', gps: '%s'", 
								dstFilename, 
								ifnil(captionData, ''),
								ifnil(labelParam, ''),
								ifnil(ratingData, 0),
								ifnil(ratingTagParam, ''),
								table.concat(ifnil(keywordNamesAdd, {}), "','"),
								ifnil(gpsLatLong, ''))
			
			if (not photoThere
				 or not waitSemaphore("PhotoStation", dstFilename)
				 or (captionParam	and not PSPhotoStationAPI.editPhoto(exportParams.uHandle, dstFilename, true, captionParam))
				 or (gpsParam		and not PSPhotoStationAPI.editPhoto(exportParams.uHandle, dstFilename, true, gpsParam))
				 or (ratingParam	and not PSPhotoStationAPI.editPhoto(exportParams.uHandle, dstFilename, true, ratingParam))
				 or	(labelParam 	and not PSPhotoStationUtils.createAndAddPhotoTag(exportParams.uHandle, dstFilename, true, 'desc', labelParam))
				 or	(ratingTagParam and not PSPhotoStationUtils.createAndAddPhotoTag(exportParams.uHandle, dstFilename, true, 'desc', ratingTagParam))
				 or	(keywordNamesAdd and #keywordNamesAdd > 0  
									and not PSPhotoStationUtils.createAndAddPhotoTagList(exportParams.uHandle, dstFilename, true, 'desc', keywordNamesAdd))
				 or (publishedCollectionId and not ackRendition(rendition, dstFilename, publishedCollectionId))) 
			then
				signalSemaphore("PhotoStation")	
				table.insert(failures, srcPhoto:getRawMetadata("path"))
				writeLogfile(1, logMessage .. ' failed!!!\n')
			else
				signalSemaphore("PhotoStation")
				writeLogfile(2, logMessage .. ' done\n')
			end
		else
			-- no metadata to update, ack rendition if publish anyway
			writeLogfile(2, string.format("Metadata Upload for '%s' -  nothing to do\n", dstFilename))
			if publishedCollectionId then
				ackRendition(rendition, dstFilename, publishedCollectionId)
			end										
		end
   		table.remove(videosUploaded, 1)
   		nProcessed = nProcessed + 1
   		progressScope:setPortionComplete(nProcessed, nVideos) 						    
	end 
	progressScope:done()
	 
	return true
end

-----------------
-- updateSharedAlbums(functionContext, sharedAlbumUpdates, sharedPhotoUpdates, exportParams) 
-- update Shared Albums for photos/videos just uploaded
-- 	  sharedAlbumUpdates contains the list of required Shared Album updates (adds and removes)
-- 	  sharedPhotoUpdates contains the list of required plugin metadata updates
local function updateSharedAlbums(functionContext, sharedAlbumUpdates, sharedPhotoUpdates, exportParams)
	local catalog = LrApplication.activeCatalog()
	local nUpdateItems =  #sharedAlbumUpdates + #sharedPhotoUpdates 
	local nProcessed 		= 0 
		
	writeLogfile(3, string.format("updateSharedAlbums: updating %d shared album and %d photo metadata\n", #sharedAlbumUpdates, #sharedPhotoUpdates))
	local catalog = LrApplication.activeCatalog()
	local progressScope = LrProgressScope( 
								{ 	title = LOC( "$$$/PSUpload/Progress/UpdateSharedAlbums=Updating ^1 shared albums with ^2 photos",  #sharedAlbumUpdates + #sharedPhotoUpdates),
							 		functionContext = functionContext 
							 	})    
	for i = 1, #sharedAlbumUpdates do
		if progressScope:isCanceled() then break end
		local sharedAlbumUpdate = sharedAlbumUpdates[i]

		if #sharedAlbumUpdate.addPhotos > 0 then 
			local success, sharedAlbumId, shareUrl = PSPhotoStationUtils.createAndAddPhotosToSharedAlbum(exportParams.uHandle, sharedAlbumUpdate.sharedAlbumName, 
																							sharedAlbumUpdate.mkSharedAlbumAdvanced, sharedAlbumUpdate.mkSharedAlbumPublic, 
																							sharedAlbumUpdate.sharedAlbumPassword, sharedAlbumUpdate.addPhotos)
			if success then
        		local firstServerUrl 	= exportParams.proto .. "://" .. exportParams.servername 
        		local secondServerUrl	= iif(ifnil(exportParams.servername2, '') ~= '', exportParams.proto2 .. "://" .. exportParams.servername2, nil)
        		writeLogfile(3, string.format("updateSharedAlbum: firstServer: %s secondServer %s\n", firstServerUrl, ifnil(secondServerUrl, '<nil>')))
        		
				if sharedAlbumUpdate.mkSharedAlbumPublic and shareUrl then 
					local sharedAlbumUrls = {}
					sharedAlbumUrls[1] = exportParams.psUrl .. "/#!SharedAlbums/" .. sharedAlbumId
					if not secondServerUrl then
						sharedAlbumUrls[2] = shareUrl
					else
						local pathUrl = string.match(shareUrl, 'http[s]*://[^/]*(.*)')
						sharedAlbumUrls[2] = firstServerUrl .. pathUrl
						sharedAlbumUrls[3] = secondServerUrl .. pathUrl
					end
					PSLrUtilities.addKeywordSynonyms(sharedAlbumUpdate.keywordId, sharedAlbumUrls) 
				elseif not sharedAlbumUpdate.mkSharedAlbumPublic then
					local shareUrlPatterns = {}
					shareUrlPatterns[1] = firstServerUrl
					if secondServerUrl then shareUrlPatterns[2] = secondServerUrl end
					PSLrUtilities.removeKeywordSynonyms(sharedAlbumUpdate.keywordId, shareUrlPatterns)
				end
			end
		end
		if #sharedAlbumUpdate.removePhotos > 0 then PSPhotoStationUtils.removePhotosFromSharedAlbum(exportParams.uHandle, sharedAlbumUpdate.sharedAlbumName, sharedAlbumUpdate.removePhotos) end
		writeLogfile(2, string.format('Shared Album "%s": added %d photos, removed %d photos.\n', 
										sharedAlbumUpdate.sharedAlbumName, #sharedAlbumUpdate.addPhotos, #sharedAlbumUpdate.removePhotos))
		nProcessed = nProcessed + 1
   		progressScope:setPortionComplete(nProcessed, nUpdateItems) 						    
	end 

	for i = 1, #sharedPhotoUpdates do
		if progressScope:isCanceled() then break end
		local sharedPhotoUpdate = sharedPhotoUpdates[i]

		PSLrUtilities.setLinkedSharedAlbums(sharedPhotoUpdate.srcPhoto, sharedPhotoUpdate.sharedAlbums)
		writeLogfile(3, string.format("%s: updated plugin metadata.\n",	sharedPhotoUpdate.srcPhoto:getRawMetadata('path')))
   		nProcessed = nProcessed + 1
   		progressScope:setPortionComplete(nProcessed, nUpdateItems) 						    
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
		local dstRoot = PSLrUtilities.evaluatePathOrFilename(exportParams.dstRoot, srcPhoto, 'path')

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
-- move unpublished photos within the Photo Station to the current target album, if they were moved locally
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
					
			nProcessed = nProcessed + 1
			skipPhoto = false
			
			if not publishedPhotoId then
				writeLogfile(2, string.format('MovePhotos: Skipping "%s", was not yet published.\n', srcPhoto:getFormattedMetadata("fileName")))
				skipPhoto = true
			else
    			-- evaluate and sanitize dstRoot: 
    			dstRoot = PSLrUtilities.evaluatePathOrFilename(exportParams.dstRoot, srcPhoto, 'path')

    			-- file renaming: 
    			--	if not Photo StatLr renaming
    			--		if Export: 	use renderedFilename (Lr renaming options may have been turned on)
    			--		else:		use srcFilename
    			--	else: apply Photo StatLr renaming 
    			dstFilename =	iif(not exportParams.renameDstFile, 
    							iif(publishMode == 'Export', 			
    									renderedFilename, 
    									srcFilename),
    									PSLrUtilities.evaluatePathOrFilename(exportParams.dstFilename, srcPhoto, 'filename'))
       			dstFilename = 	LrPathUtils.replaceExtension(dstFilename, renderedExtension)
    			
    			-- check if dstRoot contains missing required metadata ('?') (which means: skip photo) 
    			skipPhoto = iif(string.find(dstRoot, '?', 1, true) or string.find(dstFilename, '?', 1, true), true, false)
				if skipPhoto then
					writeLogfile(2, string.format('MovePhotos: Skipping "%s" due to unknown target album "%s"\n', srcPhoto:getFormattedMetadata("fileName"), dstRoot))
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
					-- move photo within Photo Station
					local dstDir

     				-- check if target Album (dstRoot) should be created 
    				if exportParams.createDstRoot and dstRoot ~= '' 
    				and	not createTree(exportParams.uHandle, './' .. dstRoot,  ".", "", dirsCreated) then
						writeLogfile(1, 'MovePhotos: Cannot create album to move remote photo from "' .. publishedPhotoId .. '" to "' .. newPublishedPhotoId .. '"!\n')
						skipPhoto = true 					
    				elseif not exportParams.copyTree then    				
    					if not dstRoot or dstRoot == '' then
    						dstDir = '/'
    					else
    						dstDir = dstRoot
    					end
    				else
    					dstDir = createTree(exportParams.uHandle, LrPathUtils.parent(srcPath), exportParams.srcRoot, dstRoot, 
    										dirsCreated) 
    				end
					
					if not dstDir
					or not PSPhotoStationAPI.movePic(exportParams.uHandle, publishedPhotoId, dstDir, srcPhoto:getRawMetadata('isVideo')) then
						writeLogfile(1, 'MovePhotos: Cannot move remote photo from "' .. publishedPhotoId .. '" to "' .. newPublishedPhotoId .. '"!\n')
						skipPhoto = true 					
					else
						writeLogfile(2, 'MovePhotos: Moved photo from ' .. publishedPhotoId .. ' to ' .. newPublishedPhotoId .. '.\n')
						albumsForCheckEmpty = PSLrUtilities.noteAlbumForCheckEmpty(albumsForCheckEmpty, publishedPhotoId)
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

	local nDeletedAlbums = 0 
	local currentAlbum = albumsForCheckEmpty
	
	while currentAlbum do
		nDeletedAlbums = nDeletedAlbums + PSPhotoStationUtils.deleteEmptyAlbumAndParents(exportParams.uHandle, currentAlbum.albumPath)
		currentAlbum = currentAlbum.next
	end
	
	writeLogfile(2, string.format("MovePhotos: Deleted %d empty albums.\n", nDeletedAlbums))
	

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

	-- Start Debugging
	openLogfile(exportParams.logLevel)
	
	-- check for updates once a day
	LrTasks.startAsyncTaskWithoutErrorHandler(PSUpdate.checkForUpdate, "PSUploadCheckForUpdate")

	writeLogfile(3, "updateExportSettings: done\n" )
end

--------------------------------------------------------------------------------

-- PSUploadTask.processRenderedPhotos( functionContext, exportContext )
-- The export callback called from Lr when the export starts
function PSUploadTask.processRenderedPhotos( functionContext, exportContext )
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

	-- additionalVideo table: user selected additional video resolutions
	local additionalVideos = {
		HIGH = 		exportParams.addVideoHigh,
		MEDIUM = 	exportParams.addVideoMed,
		LOW = 		exportParams.addVideoLow,
		MOBILE = 	'None',
	}
	
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
							   and LOC( "$$$/PSUpload/Progress/Upload=Uploading ^1 photos to Photo Station", nPhotos )
							   or LOC "$$$/PSUpload/Progress/Upload/One=Uploading one photo to Photo Station",
					}

	writeLogfile(2, "--------------------------------------------------------------------\n")
	

	-- if is Publish process and publish mode is 'CheckExisting' ...
	if publishMode == 'CheckExisting' then
		-- remove all photos from rendering process to speed up the process
		for i, rendition in exportSession:renditions() do
			rendition:skipRender()
		end 
	end
	-- Iterate through photo renditions.
	local failures 				= {}
	local dirsCreated 			= {}
	local videosUploaded 		= {}	-- videos need a second run for metadata upload
	local sharedAlbumUpdates 	= {}	-- Shared Photo/Album handling is done after all uploads
	local sharedPhotoUpdates	= {}	-- Shared Photo/Album handling is done after all uploads
	local skipPhoto = false 		-- continue flag
	
	for _, rendition in exportContext:renditions{ stopIfCanceled = true } do
		local publishedPhotoId = rendition.publishedPhotoId		-- only required for publishing
		local newPublishedPhotoId = nil
		
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
			
			nProcessed = nProcessed + 1
			
			-- evaluate and sanitize dstRoot: 
			--   substitute metadata tokens
			--   replace \ by /, remove leading and trailings slashes
			dstRoot = 		PSLrUtilities.evaluatePathOrFilename(exportParams.dstRoot, srcPhoto, 'path')

			-- file renaming: 
			--	if not Photo StatLr renaming
			--		if Export: 	use renderedFilename (Lr renaming options may have been turned on)
			--		else:		use srcFilename
			--	else: apply Photo StatLr renaming 
			dstFilename =	iif(not exportParams.renameDstFile, 
							iif(publishMode == 'Export', 			
									renderedFilename, 
									srcFilename),
									PSLrUtilities.evaluatePathOrFilename(exportParams.dstFilename, srcPhoto, 'filename'))
   			dstFilename = 	LrPathUtils.replaceExtension(dstFilename, renderedExtension)
																			
			-- check if dstRoot contains missing required metadata ('?') (which means: skip photo) 
   			skipPhoto = iif(string.find(dstRoot, '?', 1, true) or string.find(dstFilename, '?', 1, true), true, false)
			
			writeLogfile(4, string.format("  sanitized dstRoot: %s, dstFilename %s\n", dstRoot, dstFilename))
			
			local localPath, newPublishedPhotoId
			
			if skipPhoto then
				writeLogfile(2, string.format('Skip photo: "%s" due to unknown target album "%s"\n', srcPhoto:getFormattedMetadata("fileName"), dstRoot))
				table.insert( failures, srcPath )
			elseif publishMode ~= 'Export' or srcPhoto:getRawMetadata("isVideo") then
				-- generate a unique remote id for later modifications or deletions and for reference for metadata upload for videos
				-- use the relative destination pathname, so we are able to identify moved pictures
	    		localPath, newPublishedPhotoId = PSLrUtilities.getPublishPath(srcPhoto, dstFilename, exportParams, dstRoot)
				
--				writeLogfile(3, 'Old publishedPhotoId: ' .. ifnil(publishedPhotoId, '<Nil>') .. ',  New publishedPhotoId: ' .. newPublishedPhotoId .. '"\n')
				writeLogfile(3, string.format("Old publishedPhotoId: '%s', New publishedPhotoId: '%s'\n",
				 								ifnil(publishedPhotoId, '<Nil>'), newPublishedPhotoId))
				-- if photo was moved ... 
				if ifnil(publishedPhotoId, newPublishedPhotoId) ~= newPublishedPhotoId then
					-- remove photo at old location
					if publishMode == 'Publish' and not PSPhotoStationAPI.deletePic(exportParams.uHandle, publishedPhotoId, srcPhoto:getRawMetadata('isVideo')) then
						writeLogfile(1, 'Cannot delete remote photo at old path: ' .. publishedPhotoId .. ', check Photo Station permissions!\n')
    					table.insert( failures, srcPath )
						skipPhoto = true 					
					else
						writeLogfile(2, iif(publishMode == 'Publish', 'Deleting', 'CheckExisting: Would delete') .. ' remote photo at old path: ' .. publishedPhotoId .. '\n')							
					end
				end
				publishedPhotoId = newPublishedPhotoId
				dstFilename = LrPathUtils.leafName(publishedPhotoId)
			end
			
			if skipPhoto then
				-- continue w/ next photo
				skipPhoto = false
			elseif publishMode == 'CheckExisting' then
				-- check if photo already in Photo Station
				local useCache = true
				local photoInfo, additionalInfo = PSPhotoStationUtils.getPhotoInfo(exportParams.uHandle, publishedPhotoId, srcPhoto:getRawMetadata('isVideo'), useCache)
				if photoInfo then
					writeLogfile(2, string.format('CheckExisting: No upload needed for "%s" to "%s" \n', srcPhoto:getRawMetadata('path'), publishedPhotoId))
					ackRendition(rendition, publishedPhotoId, publishedCollection.localIdentifier)
					nNotCopied = nNotCopied + 1
					PSLrUtilities.noteSharedAlbumUpdates(sharedAlbumUpdates, sharedPhotoUpdates, srcPhoto, publishedPhotoId, publishedCollection.localIdentifier, exportParams) 
				elseif not photoInfo and not additionalInfo then
					-- do not acknowledge, so it will be left as "need copy"
					nNeedCopy = nNeedCopy + 1
					writeLogfile(2, 'CheckExisting: Upload required for "' .. srcPhoto:getRawMetadata('path') .. '" to "' .. newPublishedPhotoId .. '\n')
				else -- error
					table.insert( failures, srcPath )
					break 
				end	
			elseif publishMode == 'Export' or publishMode == 'Publish' then
				-- normal publish or export process 
				-- check if target Album (dstRoot) should be created 
				if exportParams.createDstRoot and dstRoot ~= '' and 
					not createTree(exportParams.uHandle, './' .. dstRoot,  ".", "", dirsCreated) then
					table.insert( failures, srcPath )
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
					dstDir = createTree(exportParams.uHandle, LrPathUtils.parent(srcPath), exportParams.srcRoot, dstRoot, 
										dirsCreated) 
				end
				
				if not dstDir then 	
					table.insert( failures, srcPath )
					break 
				end

				local videoInfo
				if srcPhoto:getRawMetadata("isVideo") then videoInfo = PSConvert.ffmpegGetAdditionalInfo(exportParams.cHandle, srcPhoto:getRawMetadata('path')) end
				  
				if (srcPhoto:getRawMetadata("isVideo") 	
					and	(	not videoInfo or
							not uploadVideo(pathOrMessage, srcPhoto, dstDir, dstFilename, exportParams, additionalVideos, videoInfo)
						-- upload of metadata to recently uploaded videos must wait until PS has registered it 
						-- this may take some seconds (approx. 15s), so note the video here and defer metadata upload to a second run
						 or (    publishedCollection and not noteVideoUpload(videosUploaded, rendition, publishedPhotoId, videoInfo, publishedCollection.localIdentifier)) 
						 or (not publishedCollection and not noteVideoUpload(videosUploaded, rendition, publishedPhotoId, videoInfo, nil)) 
						)	
					)
				or (	not srcPhoto:getRawMetadata("isVideo") 
					and (
							not	uploadPhoto(pathOrMessage, srcPhoto, dstDir, dstFilename, exportParams)
						 or 	(publishedCollection and not ackRendition(rendition, publishedPhotoId, publishedCollection.localIdentifier))
						)
					)
				then
					writeLogfile(1, 'Upload of "' .. srcPhoto:getRawMetadata('path') .. '" to "' .. dstDir .. "/" .. dstFilename .. '" failed!!!\n')
					table.insert( failures, srcPath )
				else
					if publishedCollection then
						PSLrUtilities.noteSharedAlbumUpdates(sharedAlbumUpdates, sharedPhotoUpdates, srcPhoto, publishedPhotoId, publishedCollection.localIdentifier, exportParams)
					end 
					writeLogfile(2, 'Upload of "' .. srcPhoto:getRawMetadata('path') .. '" to "' .. dstDir .. "/" .. dstFilename .. '" done\n')
				end
			end
		
			-- do some video metadata upload in between
			if #videosUploaded > 9 then 
				uploadVideoMetadata(functionContext, videosUploaded, exportParams, failures) 
				videosUploaded = {}
			end
			
			LrFileUtils.delete( pathOrMessage )
		end
	end

	-- deferred metadata upload
	if #videosUploaded > 0 then uploadVideoMetadata(functionContext, videosUploaded, exportParams, failures) end
	if #sharedAlbumUpdates > 0 then updateSharedAlbums(functionContext, sharedAlbumUpdates, sharedPhotoUpdates, exportParams) end
	
	writeLogfile(2,"--------------------------------------------------------------------\n")
	closeSession(exportParams)
	
	timeUsed = 	LrDate.currentTime() - startTime
	timePerPic = timeUsed / nProcessed
	picPerSec = nProcessed / timeUsed
	
	if #failures > 0 then
		message = LOC ("$$$/PSUpload/FinalMsg/Upload/Error=Processed ^1 of ^2 pics in ^3 seconds (^4 secs/pic). ^5 failed to upload.", 
						nProcessed, nPhotos, string.format("%.1f", timeUsed + 0.5), string.format("%.1f", timePerPic), #failures)
		local action = LrDialogs.confirm(message, table.concat( failures, "\n" ), "Go to Logfile", "Never mind")
		if action == "ok" then
			LrShell.revealInShell(getLogFilename())
		end
	else
		if publishMode == 'CheckExisting' then
			message = LOC ("$$$/PSUpload/FinalMsg/CheckExist=Checked ^1 of ^2 files in ^3 seconds (^4 pics/sec). ^5 already there, ^6 need export.", 
											nProcessed, nPhotos, string.format("%.1f", timeUsed + 0.5), string.format("%.1f", picPerSec), nNotCopied, nNeedCopy)
		else
			message = LOC ("$$$/PSUpload/FinalMsg/Upload=Uploaded ^1 of ^2 files in ^3 seconds (^4 secs/pic).", 
											nProcessed, nPhotos, string.format("%.1f", timeUsed + 0.5), string.format("%.1f", timePerPic))
		end
		showFinalMessage("Photo StatLr: " .. publishMode .. " done", message, "info")
		closeLogfile()
	end
end
