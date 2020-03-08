--[[----------------------------------------------------------------------------

PSUploadTask.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2019, Martin Messmer

Upload photos to Synology Photo Station via HTTP(S) WebService

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
require "PSUploadAPI"
require "PSPhotoStationAPI"
require "PSPhotoStationUtils"
require "PSExiftoolAPI"
require "PSSharedAlbumMgmt"

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
			writeLogfile(2,"Create dir - parent: '" .. parentDir .. "' newDir: '" .. newDir .. "' newPath: '" .. newPath .. "'\n")
			
			local paramParentDir
			if parentDir == "" then paramParentDir = "/" else paramParentDir = parentDir  end
			if not PSUploadAPI.createFolder (uHandle, paramParentDir, newDir) then
				writeLogfile(1,"Create dir - parent: '" .. paramParentDir .. "' newDir: '" .. newDir .. "' failed!\n")
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
	local title_Filename  = iif(string.match(exportParams.LR_embeddedMetadataOption, 'all.*') and ifnil(srcPhoto:getFormattedMetadata("title"), '') ~= '', 
							LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_TITLE', 'txt')), nil)
	local dstFileTimestamp = iif(ifnil(exportParams.uploadTimestamp, 'capture') == 'capture', 
								 PSLrUtilities.getDateTimeOriginal(srcPhoto), 
								 LrDate.timeToPosixDate(LrDate.currentTime()))
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
	or ((exportParams.exifXlatFaceRegions or exifXlatLabelCmd or exportParams.exifXlatRating) 
		and not PSExiftoolAPI.doExifTranslations(exportParams.eHandle, renderedPhotoPath, exifXlatLabelCmd))
--	or (exportParams.exifTranslate and not PSExiftoolAPI.doExifTranslations(exportParams.eHandle, renderedPhotoPath, exifXlatLabelCmd))

	-- wait for Photo Station semaphore
	or not waitSemaphore("PhotoStation", dstFilename)

	-- delete old before uploading new
--	or not PSPhotoStationAPI.deletePhoto (exportParams.uHandle, dstDir .. '/' .. dstFilename, false) 
	
	-- upload thumbnails and original file
	or exportParams.thumbGenerate and (
		   not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_B_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_B', 'image/jpeg', 'FIRST') 
		or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_M_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_M', 'image/jpeg', 'MIDDLE') 
		or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_S_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_S', 'image/jpeg', 'MIDDLE') 
		or (not exportParams.isPS6 and not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_L_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_L', 'image/jpeg', 'MIDDLE'))
		or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_XL_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_XL', 'image/jpeg', 'MIDDLE')
	) 
	or (title_Filename and not PSUploadAPI.uploadPictureFile(exportParams.uHandle, title_Filename, dstFileTimestamp, dstDir, dstFilename, 'CUST_TITLE', 'text', 'MIDDLE'))
	or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, renderedPhotoPath, dstFileTimestamp, dstDir, dstFilename, 'ORIG_FILE', 'image/jpeg', 'LAST')
	then
		signalSemaphore("PhotoStation", dstFilename)
		retcode = false
	else
		signalSemaphore("PhotoStation", dstFilename)
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
-- uploadVideo(renderedVideoPath, srcPhoto, dstDir, dstFilename, exportParams, vinfo) 
--[[
	generate all required thumbnails, at least one video with alternative resolution (if we don't do, Photo Station will do)
	and upload thumbnails, alternative video and the original video as a batch.
	The upload batch must start with any of the thumbs and end with the original video.
	When uploading to Photo Station 6, we don't need to upload the THUMB_L
]]
local function uploadVideo(renderedVideoPath, srcPhoto, dstDir, dstFilename, exportParams, vinfo) 
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
	local title_Filename  	= iif(string.match(exportParams.LR_embeddedMetadataOption, 'all.*') and ifnil(srcPhoto:getFormattedMetadata("title"), '') ~= '', 
							  LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_TITLE', 'txt')), nil)	

	local convParams = { 
		ULTRA =  	{ height = 2160,	type = 'HIGH',		filename = vid_HIGH_Filename },
		HIGH =  	{ height = 1080,	type = 'HIGH',		filename = vid_HIGH_Filename },
		MEDIUM = 	{ height = 720, 	type = 'MEDIUM',	filename = vid_MED_Filename },
		LOW =		{ height = 360, 	type = 'LOW',		filename = vid_LOW_Filename },
		MOBILE =	{ height = 240,		type = 'MOBILE',	filename = vid_MOB_Filename },
	}
	
	writeLogfile(3, string.format("uploadVideo: addVideoQuality is %d\n", exportParams.addVideoQuality)) 

	--  user selected additional video resolutions based or original video resolution
	local addVideoResolution = {
		ULTRA = 	iif(exportParams.addVideoQuality > 0, exportParams.addVideoUltra, 'None'),
		HIGH = 		iif(exportParams.addVideoQuality > 0, exportParams.addVideoHigh, 'None'),
		MEDIUM = 	iif(exportParams.addVideoQuality > 0, exportParams.addVideoMed, 'None'),
		LOW = 		iif(exportParams.addVideoQuality > 0, exportParams.addVideoLow, 'None'),
		MOBILE = 	'None',
	}
	
	local retcode
	local convKeyOrig, convKeyAdd
	local vid_Orig_Filename, vid_Replace_Filename, vid_Add_Filename
	
	writeLogfile(3, string.format("uploadVideo: %s\n", renderedVideoPath)) 

	-- upload file timestamp: PS uses the file timestamp as capture date for videos
	local dstFileTimestamp
	if string.find('capture,mixed', ifnil(exportParams.uploadTimestamp, 'capture'), 1, true) then
 		writeLogfile(3, string.format("uploadVideo: %s - using capture date as file timestamp\n", renderedVideoPath)) 
    	dstFileTimestamp = vinfo.srcDateTime 
	else
 		writeLogfile(3, string.format("uploadVideo: %s - using current timestamp as file timestamp\n", renderedVideoPath)) 
		dstFileTimestamp = LrDate.timeToPosixDate(LrDate.currentTime())
	end

	-- get the right conversion settings (depending on Height)
	_, convKeyOrig = PSConvert.getConvertKey(exportParams.cHandle, tonumber(vinfo.height))
	vid_Replace_Filename = convParams[convKeyOrig].filename
	convKeyAdd = addVideoResolution[convKeyOrig]
	if convKeyAdd ~= 'None' then
		vid_Add_Filename = convParams[convKeyAdd].filename
	end

	-- replace original video if:
	--		- srcVideo is to be rotated (meta or hard)
	-- 		- srcVideo is mp4, but not h264 (PS would try to open, but does only support h264)
	--		- srcVideo is mp4, but has no audio stream (PS would ignore it)
	--		- exportParams.orgVideoForceConv was set
	local replaceOrgVideo = false
	if tonumber(vinfo.rotation) > 0 
	or tonumber(vinfo.mrotation) > 0
	or (PSConvert.videoIsNativePSFormat(vidExtOrg) and vinfo.vformat ~= 'h264')
	or vinfo.aFormat == nil 
	or exportParams.orgVideoForceConv then
		replaceOrgVideo = true
		vid_Orig_Filename = vid_Replace_Filename
	else
		vid_Orig_Filename = renderedVideoPath
	end

	-- Additional MP4 in orig dimension if video is not MP4
	-- Non-MP4 will not be opened by PS, so it's safe to upload the original version plus an additional MP4
	local addOrigAsMp4 = false
	if not PSConvert.videoIsNativePSFormat(vidExtOrg) and not replaceOrgVideo then
		addOrigAsMp4 = true
	end
	
	if exportParams.thumbGenerate and ( 
		-- generate first thumb from video, rotation has to be done regardless of the hardRotate setting
		not PSConvert.ffmpegGetThumbFromVideo (exportParams.cHandle, renderedVideoPath, vinfo, thmb_ORG_Filename)

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

	-- generate mp4 in original size if srcVideo is not already mp4/h264 or if video is rotated
	or ((replaceOrgVideo or addOrigAsMp4) and not PSConvert.convertVideo(exportParams.cHandle, renderedVideoPath, vinfo, vinfo.height, exportParams.hardRotate, exportParams.orgVideoQuality, vid_Replace_Filename))
	
	-- generate additional video, if requested
	or ((convKeyAdd ~= 'None') and not PSConvert.convertVideo(exportParams.cHandle, renderedVideoPath, vinfo, convParams[convKeyAdd].height, exportParams.hardRotate, exportParams.addVideoQuality, vid_Add_Filename))

	-- if photo has a title: generate a title file  	
	or (title_Filename and not PSConvert.writeTitleFile(title_Filename, srcPhoto:getFormattedMetadata("title")))

	-- wait for Photo Station semaphore
	or not waitSemaphore("PhotoStation", dstFilename)
	
	-- delete old before uploading new
	or not PSPhotoStationAPI.deletePhoto (exportParams.uHandle, dstDir .. '/' .. dstFilename, true) 
	or exportParams.thumbGenerate and (
		-- upload thumbs, preview videos and original file
		   not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_B_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_B', 'image/jpeg', 'FIRST') 
		or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_M_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_M', 'image/jpeg', 'MIDDLE') 
		or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_S_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_S', 'image/jpeg', 'MIDDLE') 
		or (not exportParams.isPS6 and not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_L_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_L', 'image/jpeg', 'MIDDLE')) 
		or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_XL_Filename, dstFileTimestamp, dstDir, dstFilename, 'THUM_XL', 'image/jpeg', 'MIDDLE')
	) 
	or ((convKeyAdd ~= 'None') and not PSUploadAPI.uploadPictureFile(exportParams.uHandle, vid_Add_Filename, dstFileTimestamp, dstDir, dstFilename, 'MP4_'.. convParams[convKeyAdd].type, 'video/mpeg', 'MIDDLE'))
	-- add mp4 version in original resolution fo Non-MP4s 
	or (addOrigAsMp4	 	   and not PSUploadAPI.uploadPictureFile(exportParams.uHandle, vid_Replace_Filename, dstFileTimestamp, dstDir, dstFilename, 'MP4_'.. convParams[convKeyOrig].type, 'video/mpeg', 'MIDDLE'))
	-- upload at least one mp4 file to avoid the generation of a flash video by synomediaparserd 
	or ((convKeyAdd == 'None') 	and not addOrigAsMp4
	 	   						and not PSUploadAPI.uploadPictureFile(exportParams.uHandle, vid_Orig_Filename, dstFileTimestamp, dstDir, dstFilename, 'MP4_'.. convParams[convKeyOrig].type, 'video/mpeg', 'MIDDLE'))
	or (title_Filename and not PSUploadAPI.uploadPictureFile(exportParams.uHandle, title_Filename, dstFileTimestamp, dstDir, dstFilename, 'CUST_TITLE', 'text', 'MIDDLE'))
	or 					   not PSUploadAPI.uploadPictureFile(exportParams.uHandle, vid_Orig_Filename, dstFileTimestamp, dstDir, dstFilename, 'ORIG_FILE', 'video/mpeg', 'LAST') 
	then 
		signalSemaphore("PhotoStation", dstFilename)
		retcode = false
	else 
		signalSemaphore("PhotoStation", dstFilename)
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
	local isVideo 			= srcPhoto:getRawMetadata("isVideo")
	local dstAlbum 			= ifnil(string.match(dstPath , '(.*)\/[^\/]+'), '/')
	local psPhotoInfos 		= PSPhotoStationUtils.getPhotoInfoFromList(exportParams.uHandle, 'album', dstAlbum, dstPath, isVideo, true)
	local psPhotoTags 		= PSPhotoStationAPI.getPhotoTags(exportParams.uHandle, dstPath, isVideo)
	local keywordsPS 		= getTableExtract(psPhotoTags, nil, 'type', 'desc')
	local facesPS 			= getTableExtract(psPhotoTags, nil, 'type', 'people')
	local locationsPS		= getTableExtract(psPhotoTags, nil, 'type', 'geo')
	local photoParams 		= {}
	local LrExportMetadata	= (    exportParams.LR_embeddedMetadataOption and string.match(exportParams.LR_embeddedMetadataOption, 'all.*')) or
						 	  (not exportParams.LR_embeddedMetadataOption and not exportParams.LR_minimizeEmbeddedMetadata)
	local LrExportPersons	= not exportParams.LR_removeFaceMetadata
	local LrExportLocations	= not exportParams.LR_removeLocationMetadata
	
	local logMessagePref 	= string.format("Metadata Upload for '%s'", dstPath)
	
	if not psPhotoInfos then 
		writeLogfile(1, string.format("%s - photo not yet in Photo Station, use 'Upload' mode --> failed!\n", logMessagePref))
		return false 
	end
	
	if not LrExportMetadata then 
		writeLogfile(1, string.format("%s - Lr Metadata export disabled --> skipped.\n", logMessagePref))
		return true 
	end
	
	-- check title ----------------------------------------------------------------
	local titleData = ifnil(srcPhoto:getFormattedMetadata("title"), '')
	local psTitle = iif(psPhotoInfos.info.title == LrPathUtils.removeExtension(LrPathUtils.leafName(dstPath)), '', ifnil(psPhotoInfos.info.title, ''))
	if titleData ~= psTitle then
		table.insert(photoParams, { attribute =  'title', value = ifnil(titleData, '') })
	end

	-- check caption ----------------------------------------------------------------
	local captionData = ifnil(srcPhoto:getFormattedMetadata("caption"), '') 
	if captionData ~= psPhotoInfos.info.description then
		table.insert(photoParams, { attribute =  'description', value = captionData })
	end

	-- check rating: only for PS6.5 and later ----------------------------------------
	local ratingData = ifnil(srcPhoto:getFormattedMetadata("rating"), 0)
	if exportParams.psVersion >= 65 and ratingData ~= psPhotoInfos.info.rating then
		table.insert(photoParams, { attribute =  'rating', value = tostring(ratingData) })
	end
	
	-- check GPS and location tags: only if allowed by Lr export/pubish settings ----- 
	local latitude, longitude = '0', '0'
	local locationTagNamesAdd, locationTagNamesRemove, locationTagIdsRemove
	if LrExportLocations then
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
    	
    	if (math.abs(tonumber(latitude) - tonumber(ifnil(psPhotoInfos.info.lat, 0))) > 0.00001) or (math.abs(tonumber(longitude) - tonumber(ifnil(psPhotoInfos.info.lng, 0))) > 0.00001) then
    		table.insert(photoParams, { attribute =  'gps_lat', value = latitude })
    		table.insert(photoParams, { attribute =  'gps_lng', value = longitude }) 
    	end
			
		-- check location tags, if upload/translation option is set -----------------------
		if exportParams.xlatLocationTags then
			-- there may be more than one PS location tag, but only one Lr location tag
			local locationTagsLrUntrimmed = PSLrUtilities.evaluatePlaceholderString(exportParams.locationTagTemplate, srcPhoto, 'tag', nil)
			local locationTagsLrTrimmed = trim(locationTagsLrUntrimmed, exportParams.locationTagSeperator)
			local locationTagsLrCleaned = unduplicate(locationTagsLrTrimmed, exportParams.locationTagSeperator)
			local locationTagsLr = iif(locationTagsLrCleaned == '', {}, { { name = locationTagsLrCleaned }})
			
			local locationTagsAdd		= getTableDiff(locationTagsLr, locationsPS, 'name')
			local locationTagsRemove	= getTableDiff(locationsPS, locationTagsLr, 'name')

			locationTagNamesAdd		 	= getTableExtract(locationTagsAdd, 'name')
			locationTagNamesRemove	 	= getTableExtract(locationTagsRemove, 'name')
			locationTagIdsRemove 		= getTableExtract(locationTagsRemove, 'item_tag_id')
		end 
	end
		
	-- check keywords ------------------------------------------------------------------------
	local keywordsLr, keywordsAdd, keywordNamesAdd, keywordsRemove, keywordNamesRemove, keywordItemTagIdsRemove = {} 
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
		table.insert(keywordsLr, { name = PSPhotoStationUtils.rating2Stars(ratingData)})
	end

	keywordsAdd 			= getTableDiff(keywordsLr, keywordsPS, 'name')
	keywordsRemove			= getTableDiff(keywordsPS, keywordsLr, 'name')

	keywordNamesAdd		 	= getTableExtract(keywordsAdd, 'name')
	keywordNamesRemove	 	= getTableExtract(keywordsRemove, 'name')
	keywordItemTagIdsRemove = getTableExtract(keywordsRemove, 'item_tag_id')
	
	-- check faces: only if allowed by Lr export/pubish settings and if upload option is set ---- 
	local facesAdd, faceNamesAdd, facesRemove, faceNamesRemove, faceItemTagIdsRemove
	facesRemove 	= facesPS
	faceNamesRemove = getTableExtract(facesRemove, 'name')
	faceItemTagIdsRemove = getTableExtract(facesRemove, 'item_tag_id')
	
	if 	LrExportPersons and
    	exportParams.exifXlatFaceRegions and not isVideo then
		local facesLr, _ = PSExiftoolAPI.queryLrFaceRegionList(exportParams.eHandle, srcPhoto:getRawMetadata('path'))
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
			
			faceNamesAdd 		= getTableExtract(facesAdd, 'name')
			faceNamesRemove 	= getTableExtract(facesRemove, 'name')
			faceItemTagIdsRemove = getTableExtract(facesRemove, 'item_tag_id')
		end 
	end

	-- check if any changes to be published --------------------------------------------------
	local logChanges = ''

	for i = 1, #photoParams do
		logChanges = logChanges .. photoParams[i].attribute .. ": '" .. photoParams[i].value .. "',"
	end 
	if (keywordNamesAdd and #keywordNamesAdd > 0) then
		logChanges = logChanges .. 	"+tags: '" .. table.concat(keywordNamesAdd, "','") .. "' "
	end
	if (keywordNamesRemove and #keywordNamesRemove  > 0) then
		logChanges = logChanges .. 	"-tags: '" .. table.concat(keywordNamesRemove, "','")  .. "' "
	end
	if facesAdd and #facesAdd > 0 then
		logChanges = logChanges .. 	"+faces: '" .. table.concat(faceNamesAdd, "','") .. "' "
	end
	if  facesRemove and #facesRemove > 0 then
		logChanges = logChanges .. 	"-faces: '" .. table.concat(faceNamesRemove, "','") .. "' "
	end 
	if locationTagNamesAdd and #locationTagNamesAdd > 0 then
		logChanges = logChanges .. 	"+loc: '" .. table.concat(locationTagNamesAdd, "','") .. "' "
	end
	if locationTagNamesRemove and #locationTagNamesRemove > 0 then
		logChanges = logChanges .. 	"-loc: '" .. table.concat(locationTagNamesRemove, "','") .. "' "
	end
	
	if logChanges == '' then
		writeLogfile(2, string.format("%s - no changes --> done.\n", logMessagePref))
		return true
	end 

	-- publish changes
	if (not waitSemaphore("PhotoStation", dstPath)
		 or (#photoParams > 0	and not PSPhotoStationAPI.editPhoto(exportParams.uHandle, dstPath, isVideo, photoParams))
		 or	(keywordNamesRemove and #keywordNamesRemove > 0  
								and not PSPhotoStationUtils.removePhotoTagList(exportParams.uHandle, dstPath, isVideo, 'desc', keywordItemTagIdsRemove))
		 or	(keywordNamesAdd and #keywordNamesAdd > 0  
								and not PSPhotoStationUtils.createAndAddPhotoTagList(exportParams.uHandle, dstPath, isVideo, 'desc', keywordNamesAdd))
		 or	(facesRemove and #facesRemove > 0  
								and not PSPhotoStationUtils.removePhotoTagList(exportParams.uHandle, dstPath, isVideo, 'people', faceItemTagIdsRemove, facesRemove))
		 or	(facesAdd and #facesAdd > 0  
								and not PSPhotoStationUtils.createAndAddPhotoTagList(exportParams.uHandle, dstPath, isVideo, 'people', faceNamesAdd, facesAdd))
		 or (locationTagNamesRemove and #locationTagNamesRemove > 0 
		 							and not PSPhotoStationUtils.removePhotoTagList(exportParams.uHandle, dstPath, isVideo, 'geo', locationTagIdsRemove, nil))
		 or (locationTagNamesAdd	and #locationTagNamesAdd > 0
		 							and not PSPhotoStationUtils.createAndAddPhotoTagList(exportParams.uHandle, dstPath, isVideo, 'geo', locationTagNamesAdd, nil))
	   )
	then
		signalSemaphore("PhotoStation", dstPath)	
		writeLogfile(1, string.format("%s - %s --> failed!!!\n", logMessagePref, logChanges))
		retcode = false
	else
		signalSemaphore("PhotoStation", dstPath)
		writeLogfile(2, string.format("%s - %s --> done.\n", logMessagePref, logChanges))
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
		local photoThere 
		local maxWait = 60
		
		progressScope:setCaption(LrPathUtils.leafName(srcPhoto:getRawMetadata("path")))

		while not photoThere and maxWait > 0 do
			local dstAlbum 			= ifnil(string.match(dstFilename , '(.*)\/[^\/]+'), '/')
			local dontUseCache = false
			if not PSPhotoStationUtils.getPhotoInfoFromList(exportParams.uHandle, 'album', dstAlbum, dstFilename, isVideo, dontUseCache) then
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
					or not PSPhotoStationAPI.movePhoto(exportParams.uHandle, publishedPhotoId, dstDir, srcPhoto:getRawMetadata('isVideo')) then
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
							   and LOC( "$$$/PSUpload/Progress/Upload=Uploading ^1 photos to Photo Station", nPhotos )
							   or LOC "$$$/PSUpload/Progress/Upload/One=Uploading one photo to Photo Station",
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
	local skipPhoto = false 		-- continue flag
	
	for _, rendition in exportContext:renditions{ stopIfCanceled = true } do
		local publishedPhotoId = rendition.publishedPhotoId		-- the remote photo path: required for publishing
		local newPublishedPhotoId = nil							-- the new remote photo path
		
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
			
			writeLogfile(4, string.format("  sanitized dstRoot: %s, dstFilename %s\n", dstRoot, dstFilename))
			
			local localPath, newPublishedPhotoId
			
			if skipPhoto then
				writeLogfile(2, string.format("%s: Skipping '%s' due to invalid target album '%s' or remote filename '%s'\n", 
										publishMode, srcPhoto:getFormattedMetadata("fileName"), dstRoot, dstFilename))
				
				table.insert( failures, srcPath )
			else
				-- generate a unique remote id for later modifications or deletions and for reference for metadata upload for videos
				-- use the relative destination pathname, so we are able to identify moved pictures
	    		localPath, newPublishedPhotoId = PSLrUtilities.getPublishPath(srcPhoto, dstFilename, exportParams, dstRoot)
				
				writeLogfile(3, string.format("Old publishedPhotoId: '%s', New publishedPhotoId: '%s'\n",
				 								ifnil(publishedPhotoId, '<Nil>'), newPublishedPhotoId))
				-- if photo was moved ... 
				if ifnil(publishedPhotoId, newPublishedPhotoId) ~= newPublishedPhotoId then
					-- remove photo at old location
					if publishMode == 'Publish' and not PSPhotoStationAPI.deletePhoto(exportParams.uHandle, publishedPhotoId, srcPhoto:getRawMetadata('isVideo')) then
						writeLogfile(1, 'Cannot delete remote photo at old path: ' .. publishedPhotoId .. ', check Photo Station permissions!\n')
    					table.insert( failures, srcPath )
						skipPhoto = true 					
					elseif publishMode == 'Metadata' then
						writeLogfile(1, "Metadata Upload for '" .. publishedPhotoId .. "' - failed, photo must be uploaded to '" .. newPublishedPhotoId .."' at first!\n")
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
				local dstAlbum = ifnil(string.match(publishedPhotoId , '(.*)\/[^\/]+'), '/')
				local useCache = true
				local photoInfos, errorCode = PSPhotoStationUtils.getPhotoInfoFromList(exportParams.uHandle, 'album', dstAlbum, publishedPhotoId, 
																						srcPhoto:getRawMetadata('isVideo'), useCache)
				if photoInfos then
					writeLogfile(2, string.format('CheckExisting: No upload needed for "%s" to "%s" \n', srcPhoto:getRawMetadata('path'), publishedPhotoId))
					ackRendition(rendition, publishedPhotoId, publishedCollection.localIdentifier)
					nNotCopied = nNotCopied + 1
					PSSharedAlbumMgmt.noteSharedAlbumUpdates(sharedAlbumUpdates, sharedPhotoUpdates, srcPhoto, publishedPhotoId, publishedCollection.localIdentifier, exportParams) 
				elseif not photoInfos and not errorCode then
					-- do not acknowledge, so it will be left as "need copy"
					nNeedCopy = nNeedCopy + 1
					writeLogfile(2, 'CheckExisting: Upload required for "' .. srcPhoto:getRawMetadata('path') .. '" to "' .. newPublishedPhotoId .. '\n')
				else -- error
					table.insert( failures, srcPath )
					break 
				end	
			elseif string.find('Export,Publish,Metadata', publishMode, 1, true) then
				
				if publishMode == 'Metadata' then
					dstDir = string.match(publishedPhotoId , '(.*)\/[^\/]+')
				else
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
				end

				local vinfo
				if srcPhoto:getRawMetadata("isVideo") then 
					-- if publishMode is 'Metadata' we just extract metadata 
					-- else we extract metadata plus video infos from the rendered video 
					vinfo = PSConvert.ffmpegGetAdditionalInfo(exportParams.cHandle, srcPhoto,  
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
					if string.find('Export,Publish', publishMode, 1, true) then writeLogfile(1, "Upload of '" .. srcPhoto:getRawMetadata('path') .. "' to '" .. dstDir .. "/" .. dstFilename .. "' failed!!!\n") end
					table.insert( failures, srcPath )
				else
					if publishedCollection then
						PSSharedAlbumMgmt.noteSharedAlbumUpdates(sharedAlbumUpdates, sharedPhotoUpdates, srcPhoto, publishedPhotoId, publishedCollection.localIdentifier, exportParams)
					end 
					if string.find('Export,Publish', publishMode, 1, true) then writeLogfile(2, "Upload of '" .. srcPhoto:getRawMetadata('path') .. "' to '" .. dstDir .. "/" .. dstFilename .. "' done\n") end
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
