--[[----------------------------------------------------------------------------

PSUploadTask.lua
Upload photos to Synology PhotoStation via HTTP(S) WebService
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
-- local LrProgressScope = import 'LrProgressScope'
local LrShell = import 'LrShell'
local LrPrefs = import 'LrPrefs'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'

require "PSUtilities"
require "PSConvert"
require "PSUpdate"
require "PSUploadAPI"
require "PSPhotoStationAPI"
require "PSExiftoolAPI"

--============================================================================--
		
PSUploadTask = {}

------------- getDateTimeOriginal -------------------------------------------------------------------

-- getDateTimeOriginal(srcFilename, srcPhoto)
-- get the DateTimeOriginal (capture date) of a photo or whatever comes close to it
-- tries various methods to get the info including Lr metadata, exiftool (if enabled), file infos
-- returns a unix timestamp and a boolean indicating if we found a real DateTimeOrig
function getDateTimeOriginal(srcFilename, srcPhoto)
	local srcDateTime = nil
	local isOrigDateTime = false
	
	if srcPhoto:getRawMetadata("dateTimeOriginal") then
		srcDateTime = srcPhoto:getRawMetadata("dateTimeOriginal")
		isOrigDateTime = true
		writeLogfile(3, "  dateTimeOriginal: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
	elseif srcPhoto:getRawMetadata("dateTimeOriginalISO8601") then
		srcDateTime = srcPhoto:getRawMetadata("dateTimeOriginalISO8601")
		isOrigDateTime = true
		writeLogfile(3, "  dateTimeOriginalISO8601: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
	elseif srcPhoto:getRawMetadata("dateTimeDigitized") then
		srcDateTime = srcPhoto:getRawMetadata("dateTimeDigitized")
		writeLogfile(3, "  dateTimeDigitized: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
	elseif srcPhoto:getRawMetadata("dateTimeDigitizedISO8601") then
		srcDateTime = srcPhoto:getRawMetadata("dateTimeDigitizedISO8601")
		writeLogfile(3, "  dateTimeDigitizedISO8601: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
	elseif srcPhoto:getFormattedMetadata("dateCreated") and srcPhoto:getFormattedMetadata("dateCreated") ~= '' then
		local srcDateTimeStr = srcPhoto:getFormattedMetadata("dateCreated")
		local year,month,day,hour,minute,second,tzone
		local foundDate = false -- avoid empty dateCreated
		
		-- iptcDateCreated: date is mandatory, time as whole, seconds and timezone may or may not be present
		for year,month,day,hour,minute,second,tzone in string.gmatch(srcDateTimeStr, "(%d+)-(%d+)-(%d+)T*(%d*):*(%d*):*(%d*)Z*(%w*)") do
			writeLogfile(4, string.format("dateCreated: %s Year: %s Month: %s Day: %s Hour: %s Minute: %s Second: %s Zone: %s\n",
											srcDateTimeStr, year, month, day, ifnil(hour, "00"), ifnil(minute, "00"), ifnil(second, "00"), ifnil(tzone, "local")))
			srcDateTime = LrDate.timeFromComponents(tonumber(year), tonumber(month), tonumber(day),
													tonumber(ifnil(hour, "0")),
													tonumber(ifnil(minute, "0")),
													tonumber(ifnil(second, "0")),
													iif(not tzone or tzone == "", "local", tzone))
			foundDate = true
		end
		if foundDate then writeLogfile(3, "  dateCreated: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n") end
	
	-- dateTime is typically the date of the Lightroom import --> worst choice
--[[ 
	elseif srcPhoto:getRawMetadata("dateTime") then
		srcDateTime = srcPhoto:getRawMetadata("dateTime")
		writeLogfile(3, "  RawMetadate datetime\n")
		writeLogfile(3, "  dateTime: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
]]
	end
	
	-- if nothing found in srcPhoto: take the fileCreationDate
	if not srcDateTime then
		local fileAttr = LrFileUtils.fileAttributes( srcFilename )
--		srcDateTime = exiftoolGetDateTimeOrg(srcFilename)
--		if srcDateTime then 
--			writeLogfile(3, "  exiftoolDateTimeOrg: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
--		elseif fileAttr["fileCreationDate"] then
		if fileAttr["fileCreationDate"] then
			srcDateTime = fileAttr["fileCreationDate"]
			writeLogfile(3, "  fileCreationDate: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
--[[
]]
		else
			srcDateTime = LrDate.currentTime()
			writeLogfile(3, "  no date found, using current date: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
		end
	end
	return LrDate.timeToPosixDate(srcDateTime), isOrigDateTime
end

-----------------

-- function getPublishPath(srcPhotoPath, srcPhoto, exportParams, dstRoot) 
-- 	return relative local path of the srcPhoto and destination path of the rendered photo: remotePath = dstRoot + (localpath - srcRoot), 
--	returns:
-- 		localPath - relative local path as unix-path
-- 		remotePath - absolute remote path as unix-path
function getPublishPath(srcPhotoPath, srcPhoto, exportParams, dstRoot) 
	local srcPhotoExtension = LrPathUtils.extension(srcPhotoPath)
	local localRenderedPath, localRenderedExtension
	local localPath
	local remotePath
	
	-- if is virtual copy: add last three characters of photoId as suffix to filename
	if srcPhoto:getRawMetadata('isVirtualCopy') then
		srcPhotoPath = LrPathUtils.addExtension(LrPathUtils.removeExtension(srcPhotoPath) .. '-' .. string.sub(srcPhoto:getRawMetadata('uuid'), -3), 
												srcPhotoExtension)
		writeLogfile(3, 'isVirtualCopy: new srcPhotoPath is: ' .. srcPhotoPath .. '"\n')				
	end

	-- for photos: check if extension of rendered photo is different from original photo
	if not srcPhoto:getRawMetadata('isVideo') then
    	if exportParams.LR_format == 'ORIGINAL' then
    		localRenderedExtension = LrPathUtils.extension(srcPhotoPath)
    	else
    		localRenderedExtension = iif(exportParams.LR_format == 'JPEG', 'JPG', exportParams.LR_format)   
    		localRenderedExtension = iif(exportParams.LR_extensionCase == 'lowercase', string.lower(localRenderedExtension), localRenderedExtension)
    	end
    	
    	if string.lower(srcPhotoExtension) ~= string.lower(localRenderedExtension) then
    		-- if original and rendered photo extensions are different, use rendered photo extension
    		-- optionally append original extension to photoname (e.g. '_rw2.jpg')
    		if exportParams.RAWandJPG then
    			srcPhotoPath = LrPathUtils.addExtension(LrPathUtils.removeExtension(srcPhotoPath) .. '_' .. srcPhotoExtension, localRenderedExtension)
    		else
    			srcPhotoPath = LrPathUtils.replaceExtension(srcPhotoPath, localRenderedExtension)
    		end
    		writeLogfile(3, string.format("'Orig %s <> rendered extension %s: new srcPhotoPath is: %s\n", srcPhotoExtension, localRenderedExtension, srcPhotoPath))				
    	end
	end
		
	localRenderedPath = srcPhotoPath
			
	if exportParams.copyTree then
		localPath = 		string.gsub(LrPathUtils.makeRelative(srcPhotoPath, exportParams.srcRoot), "\\", "/")
		localRenderedPath = string.gsub(LrPathUtils.makeRelative(localRenderedPath, exportParams.srcRoot), "\\", "/")
	else
		localPath = 		LrPathUtils.leafName(srcPhotoPath)
		localRenderedPath = LrPathUtils.leafName(localRenderedPath)
	end
	remotePath = iif(dstRoot ~= '', dstRoot .. '/' .. localRenderedPath, localRenderedPath)
	return localPath, remotePath
end
-----------------

-- function createTree(uHandle, srcDir, srcRoot, dstRoot, dirsCreated, readOnly) 
-- 	derive destination folder: dstDir = dstRoot + (srcRoot - srcDir), 
--	create each folder recursively if not already created
-- 	store created directories in dirsCreated
-- 	return created dstDir or nil on error
function createTree(uHandle, srcDir, srcRoot, dstRoot, dirsCreated, readOnly) 
	writeLogfile(4, "  createTree: Src Path: " .. srcDir .. " from: " .. srcRoot .. " to: " .. dstRoot .. "\n")

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
			if not readOnly and not PSUploadAPI.createFolder (uHandle, paramParentDir, newDir) then
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
-- uploadPhoto(origFilename, srcFilename, srcPhoto, dstDir, dstFilename, exportParams) 
--[[
	generate all required thumbnails and upload thumbnails and the original picture as a batch.
	The upload batch must start with any of the thumbs and end with the original picture.
	When uploading to PhotoStation 6, we don't need to upload the THUMB_L
]]
function uploadPhoto(origFilename, srcFilename, srcPhoto, dstDir, dstFilename, exportParams) 
	local picBasename = mkSaveFilename(LrPathUtils.removeExtension(LrPathUtils.leafName(srcFilename)))
	local picExt = 'jpg'
	local picDir = LrPathUtils.parent(srcFilename)
	local thmb_XL_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_XL', picExt))
	local thmb_L_Filename = iif(not exportParams.isPS6, LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_L', picExt)), '')
	local thmb_M_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_M', picExt))
	local thmb_B_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_B', picExt))
	local thmb_S_Filename = LrPathUtils.child(picDir, LrPathUtils.addExtension(picBasename .. '_S', picExt))
	local srcDateTime = getDateTimeOriginal(origFilename, srcPhoto)
	local retcode
	
	-- generate thumbs	
	if exportParams.thumbGenerate and ( 
			( not exportParams.largeThumbs and not PSConvert.convertPicConcurrent(exportParams.cHandle, srcFilename, srcPhoto, exportParams.LR_format,
								'-flatten -quality '.. tostring(exportParams.thumbQuality) .. ' -auto-orient '.. thumbSharpening[exportParams.thumbSharpness], 
								'1280x1280>', thmb_XL_Filename,
								'800x800>',    thmb_L_Filename,
								'640x640>',    thmb_B_Filename,
								'320x320>',    thmb_M_Filename,
								'120x120>',    thmb_S_Filename) )
		or ( exportParams.largeThumbs and not PSConvert.convertPicConcurrent(exportParams.cHandle, srcFilename, srcPhoto, exportParams.LR_format,
								'-flatten -quality '.. tostring(exportParams.thumbQuality) .. ' -auto-orient '.. thumbSharpening[exportParams.thumbSharpness], 
								'1280x1280>^', thmb_XL_Filename,
								'800x800>^',   thmb_L_Filename,
								'640x640>^',   thmb_B_Filename,
								'320x320>^',   thmb_M_Filename,
								'120x120>^',   thmb_S_Filename) )
	)
	
	-- exif translations	
	or ( exportParams.exifTranslate and not PSExiftoolAPI.doExifTranslations(exportParams.eHandle, srcFilename))

	-- wait for PhotoStation semaphore
	or not waitSemaphore("PhotoStation", dstFilename)
	-- upload thumbnails and original file
	or exportParams.thumbGenerate and (
		   not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_B_Filename, srcDateTime, dstDir, dstFilename, 'THUM_B', 'image/jpeg', 'FIRST') 
		or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_M_Filename, srcDateTime, dstDir, dstFilename, 'THUM_M', 'image/jpeg', 'MIDDLE') 
		or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_S_Filename, srcDateTime, dstDir, dstFilename, 'THUM_S', 'image/jpeg', 'MIDDLE') 
		or (not exportParams.isPS6 and not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_L_Filename, srcDateTime, dstDir, dstFilename, 'THUM_L', 'image/jpeg', 'MIDDLE'))
		or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, thmb_XL_Filename, srcDateTime, dstDir, dstFilename, 'THUM_XL', 'image/jpeg', 'MIDDLE')
	) 
	or not PSUploadAPI.uploadPictureFile(exportParams.uHandle, srcFilename, srcDateTime, dstDir, dstFilename, 'ORIG_FILE', 'image/jpeg', 'LAST') 
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
	end
	
	return retcode
end

-----------------
-- uploadVideo(origVideoFilename, srcVideoFilename, srcPhoto, dstDir, dstFilename, exportParams, addVideo) 
--[[
	generate all required thumbnails, at least one video with alternative resolution (if we don't do, PhotoStation will do)
	and upload thumbnails, alternative video and the original video as a batch.
	The upload batch must start with any of the thumbs and end with the original video.
	When uploading to PhotoStation 6, we don't need to upload the THUMB_L
]]
function uploadVideo(origVideoFilename, srcVideoFilename, srcPhoto, dstDir, dstFilename, exportParams, addVideo) 
	local picBasename = mkSaveFilename(LrPathUtils.removeExtension(LrPathUtils.leafName(srcVideoFilename)))
	local vidExtOrg = LrPathUtils.extension(srcVideoFilename)
	local picDir = LrPathUtils.parent(srcVideoFilename)
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
	local realDimension
	local retcode
	local convKeyOrig, convKeyAdd
	local vid_Orig_Filename, vid_Replace_Filename, vid_Add_Filename
	
	writeLogfile(3, string.format("uploadVideo: %s\n", srcVideoFilename)) 

	local convParams = { 
		HIGH =  	{ height = 1080,	filename = vid_HIGH_Filename },
		MEDIUM = 	{ height = 720, 	filename = vid_MED_Filename },
		LOW =		{ height = 360, 	filename = vid_LOW_Filename },
		MOBILE =	{ height = 240,		filename = vid_MOB_Filename },
	}
	
	-- get video infos: DateTimeOrig, duration, dimension, sample aspect ratio, display aspect ratio
	local vinfo = PSConvert.ffmpegGetAdditionalInfo(exportParams.cHandle, srcVideoFilename)
	if not vinfo then
		return false
	end
	
	-- look also for DateTimeOriginal in Metadata: if metadata include DateTimeOrig, then this will 
	-- overwrite the ffmpeg DateTimeOrig 
	local metaDateTime, isOrigDateTime = getDateTimeOriginal(origVideoFilename, srcPhoto)
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
		vid_Orig_Filename = srcVideoFilename
	end

	-- Additional MP4 in orig dimension if video is not MP4
	local addOrigAsMp4 = false
	if not PSConvert.videoIsNativePSFormat(vidExtOrg) and not replaceOrgVideo then
		addOrigAsMp4 = true
	end
	
	if exportParams.thumbGenerate and ( 
		-- generate first thumb from video, rotation has to be done regardless of the hardRotate setting
		not PSConvert.ffmpegGetThumbFromVideo (exportParams.cHandle, srcVideoFilename, thmb_ORG_Filename, realDimension, vinfo.rotation, vinfo.duration)

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
	or ((replaceOrgVideo or addOrigAsMp4) and not PSConvert.convertVideo(exportParams.cHandle, srcVideoFilename, vinfo.srcDateTime, vinfo.dar, srcHeight, exportParams.hardRotate, videoRotation, vid_Replace_Filename))
	
	-- generate additional video, if requested
	or ((convKeyAdd ~= 'None') and not PSConvert.convertVideo(exportParams.cHandle, srcVideoFilename, vinfo.srcDateTime, vinfo.dar, convParams[convKeyAdd].height, exportParams.hardRotate, videoRotation, vid_Add_Filename))

	-- wait for PhotoStation semaphore
	or not waitSemaphore("PhotoStation", dstFilename)
	
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
	end
	
	return retcode
end

--------------------------------------------------------------------------------

-- checkMoved(publishedCollection, exportContext, exportParams)
-- check all photos in a collection if locally moved
-- all moved photos get status "to be re-published"
-- return:
-- 		nPhotos		- # of photos in collection
--		nProcessed 	- # of photos checked
--		nMoved		- # of photos found to be moved
function checkMoved(publishedCollection, exportContext, exportParams)
--	local exportParams = exportContext.propertyTable
	local catalog = LrApplication.activeCatalog()
	local publishedPhotos = publishedCollection:getPublishedPhotos() 
	local nPhotos = #publishedPhotos
	local nProcessed = 0
	local nMoved = 0 

	-- Set progress title.
	local progressScope = exportContext:configureProgress {
						title = nPhotos > 1
							and LOC( "$$$/PSUpload/Upload/Progress=Checking ^1 photos for movement", nPhotos )
							or LOC "$$$/PSUpload/Upload/Progress/One=Checking one photo for movement",
						renderPortion = 1 / nPhotos,
					}
					
	for i = 1, nPhotos do
		if progressScope:isCanceled() then break end
		
		local pubPhoto = publishedPhotos[i]
		local srcPhoto = pubPhoto:getPhoto()
		local srcPhotoPath = srcPhoto:getRawMetadata('path')
		local publishedPath = ifnil(pubPhoto:getRemoteId(), '<Nil>')
		local edited = pubPhoto:getEditedFlag()
		local dstRoot = PSLrUtilities.evaluateAlbumPath(exportParams.dstRoot, srcPhoto)
		
		local localPath, remotePath = getPublishPath(srcPhotoPath, srcPhoto, exportParams, dstRoot)
		writeLogfile(3, "CheckMoved(" .. tostring(i) .. ", s= "  .. srcPhotoPath  .. ", r =" .. remotePath .. ", lastRemote= " .. publishedPath .. ", edited= " .. tostring(edited) .. ")\n")
		-- ignore extension: might be different 
		if LrPathUtils.removeExtension(remotePath) ~= LrPathUtils.removeExtension(publishedPath) then
			writeLogfile(2, "CheckMoved(" .. localPath .. " must be moved at target from " .. publishedPath .. 
							" to " .. remotePath .. ", edited= " .. tostring(edited) .. ")\n")
			catalog:withWriteAccessDo( 
				'SetEdited',
				function(context)
					pubPhoto:setEditedFlag(true)
				end,
				{timeout=5}
			)
			nMoved = nMoved + 1
		else
			writeLogfile(2, "CheckMoved(" .. localPath .. ") not moved.\n")
		end
		nProcessed = i
		progressScope:setPortionComplete(nProcessed, nPhotos)
	end 
	progressScope:done()
	
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
	-- Make a local copy of the export parameters.
--	local origExportParams = exportContext.propertyTable
--	local exportParams = tableShallowCopy(origExportParams["< contents >"])
	
	local message
	local nPhotos
	local nProcessed = 0
	local nNotCopied = 0 	-- Publish / CheckExisting: num of pics not copied
	local nNeedCopy = 0 	-- Publish / CheckExisting: num of pics that need to be copied
	local timeUsed
	local timePerPic, picPerSec
	local readOnly = false
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
		publishMode = exportParams.publishMode
	else
		publishMode = 'Export'
		exportParams.publishMode = 'Export'
	end
		
	-- open session: initialize environment, get missing params and login
	local sessionSuccess, reason = openSession(exportParams, publishMode, publishedCollection)
	if not sessionSuccess then
		if reason ~= 'cancel' then
			showFinalMessage("PhotoStation Upload: processRenderedPhotos failed!", reason, "critical")
		end
		closeLogfile()
		return
	end

	-- publishMode may have changed from 'Ask' to something different
	publishMode = exportParams.publishMode
	writeLogfile(2, "processRenderedPhotos(mode: " .. publishMode .. ").\n")

	local startTime = LrDate.currentTime()

	if publishMode == "CheckMoved" then
		-- Publish mode CheckMoved: makes no sense if not mirror tree mode
		local nMoved
		if not exportParams.copyTree then
			message = LOC ("$$$/PSUpload/Upload/Errors/CheckMovedNotNeeded=PhotoStation Upload (Check Moved): No mirror tree copy, no need to check for moved pics.\n")
		else
			nPhotos, nProcessed, nMoved = checkMoved(publishedCollection, exportContext, exportParams)
			timeUsed = 	LrDate.currentTime() - startTime
			picPerSec = nProcessed / timeUsed
			message = LOC ("$$$/PSUpload/Upload/Errors/CheckMoved=" .. 
							string.format("PhotoStation Upload (Check Moved): Checked %d of %d pics in %d seconds (%.1f pic/sec). Found %d moved pics.\n", 
							nProcessed, nPhotos, timeUsed + 0.5, picPerSec, nMoved))
		end
		showFinalMessage("PhotoStation CheckMoved done", message, "info")
		closeLogfile()
		closeSession(exportParams)
		return
	end

	-- Set progress title.
	nPhotos = exportSession:countRenditions()

	local progressScope = exportContext:configureProgress {
						title = nPhotos > 1
							   and LOC( "$$$/PSUpload/Upload/Progress=Uploading ^1 photos to PhotoStation", nPhotos )
							   or LOC "$$$/PSUpload/Upload/Progress/One=Uploading one photo to PhotoStation",
					}

	writeLogfile(2, "--------------------------------------------------------------------\n")
	

	-- if is Publish process and publish mode is 'CheckExisting' ...
	if publishMode == 'CheckExisting' then
		-- remove all photos from rendering process to speed up the process
		readOnly = true
		for i, rendition in exportSession:renditions() do
			rendition:skipRender()
		end 
	end
	-- Iterate through photo renditions.
	local failures = {}
	local dirsCreated = {}
	local skipPhoto = false 	-- continue flag
	
	for _, rendition in exportContext:renditions{ stopIfCanceled = true } do
		local publishedPhotoId = rendition.publishedPhotoId		-- only required for publishing
		local newPublishedPhotoId = nil
		
		-- Wait for next photo to render.

		local success, pathOrMessage = rendition:waitForRender()
		
		-- Check for cancellation again after photo has been rendered.
		
		if progressScope:isCanceled() then break end
		
		if success then
			writeLogfile(3, "Next photo: " .. pathOrMessage .. "\n")
			
			local srcPhoto = rendition.photo
			local renderedFilename = LrPathUtils.leafName( pathOrMessage )
			local srcFilename = srcPhoto:getRawMetadata("path") 
			local dstRoot
			local dstDir
		
			nProcessed = nProcessed + 1
			
			-- evaluate and sanitize dstRoot: 
			--   substitute metadata tokens
			--   replace \ by /, remove leading and trailings slashes
			dstRoot = PSLrUtilities.evaluateAlbumPath(exportParams.dstRoot, srcPhoto)
			writeLogfile(4, "  sanitized dstRoot: " .. dstRoot .. "\n")
			
			local localPath, newPublishedPhotoId
			
			if publishMode ~= 'Export' then
				-- publish process: generate a unique remote id for later modifications or deletions
				-- use the relative destination pathname, so we are able to identify moved pictures
				localPath, newPublishedPhotoId = getPublishPath(srcFilename, srcPhoto, exportParams, dstRoot)
				
				writeLogfile(3, 'Old publishedPhotoId:' .. ifnil(publishedPhotoId, '<Nil>') .. ',  New publishedPhotoId:  ' .. newPublishedPhotoId .. '"\n')
				-- if photo was moved ... 
				if ifnil(publishedPhotoId, newPublishedPhotoId) ~= newPublishedPhotoId then
					-- remove photo at old location
					if publishMode == 'Publish' and not PSPhotoStationAPI.deletePic(exportParams.uHandle, publishedPhotoId, srcPhoto:getRawMetadata('isVideo')) then
						writeLogfile(1, 'Cannot delete remote photo at old path: ' .. publishedPhotoId .. ', check PhotoStation permissions!\n')
    					table.insert( failures, srcFilename )
						skipPhoto = true 					
					else
						writeLogfile(2, iif(publishMode == 'Publish', 'Deleting', 'CheckExisting: Would delete') .. ' remote photo at old path: ' .. publishedPhotoId .. '\n')							
					end
				end
				publishedPhotoId = newPublishedPhotoId
				renderedFilename = LrPathUtils.leafName(publishedPhotoId)
			end
			
			if skipPhoto then
				-- continue w/ next photo
				skipPhoto = false
			elseif publishMode == 'CheckExisting' then
				-- check if photo already in PhotoStation
--				local foundPhoto = PSFileStationAPI.existsPic(exportParams.fHandle, publishedPhotoId)
				local foundPhoto = PSPhotoStationAPI.existsPic(exportParams.uHandle, publishedPhotoId, srcPhoto:getRawMetadata('isVideo'))
				if foundPhoto == 'yes' then
					rendition:recordPublishedPhotoId(publishedPhotoId)
					nNotCopied = nNotCopied + 1
					writeLogfile(2, 'CheckExisting: No Upload needed for "' .. LrPathUtils.leafName(localPath) .. '" to "' .. publishedPhotoId .. '\n')
				elseif foundPhoto == 'no' then
					-- do not acknowledge, so it will be left as "need copy"
					nNeedCopy = nNeedCopy + 1
					writeLogfile(2, 'CheckExisting: Upload required for "' .. LrPathUtils.leafName(localPath) .. '" to "' .. ifnil(LrPathUtils.parent(publishedPhotoId), "/") .. '\n')
				else -- error
					table.insert( failures, srcFilename )
					break 
				end	
			elseif publishMode == 'Export' or publishMode == 'Publish' then
				-- normal publish or export process 
				-- check if target Album (dstRoot) should be created 
				if exportParams.createDstRoot and dstRoot ~= '' and 
					not createTree(exportParams.uHandle, './' .. dstRoot,  ".", "", dirsCreated, readOnly) then
					table.insert( failures, srcFilename )
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
					dstDir = createTree(exportParams.uHandle, LrPathUtils.parent(srcFilename), exportParams.srcRoot, dstRoot, 
										dirsCreated, readOnly) 
				end
				
				if not dstDir then 	
					table.insert( failures, srcFilename )
					break 
				end

				if srcPhoto:getRawMetadata("isVideo") then
					writeLogfile(4, pathOrMessage .. ": is video\n") 
					if not uploadVideo(srcFilename, pathOrMessage, srcPhoto, dstDir, renderedFilename, exportParams, additionalVideos) then
						writeLogfile(1, 'Upload of "' .. renderedFilename .. '" to "' .. dstDir .. '" failed!!!\n')
						table.insert( failures, dstDir .. "/" .. renderedFilename )
					else
						if publishedCollection then rendition:recordPublishedPhotoId(publishedPhotoId) end
						writeLogfile(2, 'Upload of "' .. renderedFilename .. '" to "' .. dstDir .. '" done\n')
					end
				else
					if not uploadPhoto(srcFilename, pathOrMessage, srcPhoto, dstDir, renderedFilename, exportParams) then
						writeLogfile(1, 'Upload of "' .. renderedFilename .. '" to "' ..  dstDir .. '" failed!!!\n')
						table.insert( failures, dstDir .. "/" .. renderedFilename )
					else
						if publishedCollection then rendition:recordPublishedPhotoId(publishedPhotoId) end
						writeLogfile(2, 'Upload of "' .. renderedFilename .. '" to "' .. dstDir .. '" done\n')
					end
				end
			end
			
			LrFileUtils.delete( pathOrMessage )
		end
	end

	writeLogfile(2,"--------------------------------------------------------------------\n")
	closeSession(exportParams)
	
	timeUsed = 	LrDate.currentTime() - startTime
	timePerPic = timeUsed / nProcessed
	picPerSec = nProcessed / timeUsed
	
	if #failures > 0 then
		message = LOC ("$$$/PSUpload/Upload/Errors/SomeFileFailed=" .. 
						string.format("PhotoStation Upload: Processed %d of %d pics in %d seconds (%.1f secs/pic). %d failed to upload.\n", 
						nProcessed, nPhotos, timeUsed, timePerPic, #failures))
		local action = LrDialogs.confirm(message, table.concat( failures, "\n" ), "Go to Logfile", "Never mind")
		if action == "ok" then
			LrShell.revealInShell(getLogFilename())
		end
	else
		if publishMode == 'CheckExisting' then
			message = LOC ("$$$/PSUpload/Upload/Errors/CheckExistOK=" .. 
							 string.format("PhotoStation Upload (Check Existing): Checked %d of %d files in %d seconds (%.1f pics/sec). %d already there, %d need export.", 
											nProcessed, nPhotos, timeUsed + 0.5, picPerSec, nNotCopied, nNeedCopy))
		else
			message = LOC ("$$$/PSUpload/Upload/Errors/UploadOK=" ..
							 string.format("PhotoStation Upload: Uploaded %d of %d files in %d seconds (%.1f secs/pic).", 
											nProcessed, nPhotos, timeUsed + 0.5, timePerPic))
		end
		showFinalMessage("PhotoStation Upload done", message, "info")
		closeLogfile()
	end
end
