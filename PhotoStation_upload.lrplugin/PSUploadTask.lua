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
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrDate = import 'LrDate'
local LrDialogs = import 'LrDialogs'
local LrShell = import 'LrShell'
local LrView = import 'LrView'

require "PSConvert"
require "PSUploadAPI"

--============================================================================--

PSUploadTask = {}

-- we can store some variables in 'global' local variables safely:
-- each export task will get its own copy of these variables
local tmpdir = LrPathUtils.getStandardFilePath("temp")

local logfilename
local loglevel
--[[loglevel:
	0 -	nothing
	1 - errors
	2 - info
	3 - tracing
	4 - debug
]]	

---------------------- useful helpers ----------------------------------------------------------

function ifnil(str, subst)
	if str == nil then
		return subst
	else
		return str
	end
end 

function iif(condition, thenExpr, elseExpr)
	if condition then
		return thenExpr
	else
		return elseExpr
	end
end 

----------------------- logging ---------------------------------------------------------
-- had some issues with LrLogger in cojunction with LrTasks, so we do our own file logging
local startTime

-- openLogfile: clear the logfile, reopen and put in a start timestamp
function openLogfile (filename, level)
	logfilename = filename
	local logfile = io.open(logfilename, "w")
	
	loglevel = level
	startTime = LrDate.currentTime()
	logfile:write("Starting export at: " .. LrDate.timeToUserFormat(startTime, "%Y-%m-%d %H:%M:%S", false) .. "\n")
	io.close (logfile)
end

-- writeLogfile: always open, write, close, otherwise output will get lost in case of unexpected errors
function writeLogfile (level, msg)
	if level <= loglevel then
		local logfile = io.open(logfilename, "a")
		logfile:write(msg)
		io.close (logfile)
	end
end

-- closeLogfile: write the end timestamp and time consumed
function closeLogfile()
	local logfile = io.open(logfilename, "a")
	local now = LrDate.currentTime()
	logfile:write("Finished export at: " .. LrDate.timeToUserFormat(now, "%Y-%m-%d %H:%M:%S", false) .. ", took " .. string.format("%d", now - startTime) .. " seconds\n")
	io.close (logfile)
end

---------------------- environment ----------------------------------------------------------
function initializeEnv (exportParams)

	return (PSUploadAPI.initialize(exportParams.serverUrl, iif(exportParams.usePersonalPS, exportParams.personalPSOwner, nil)) and 
			PSConvert.initialize(exportParams.PSUploaderPath))
end

---------------------- dialog functions ----------------------------------------------------------

function promptForMissingSettings(exportParams)
	local f = LrView.osFactory()
	local bind = LrView.bind
	local share = LrView.share
	local conditionalItem = LrView.conditionalItem
	local needPw = (ifnil(exportParams.password, "") == "")
	local needDstRoot = not exportParams.storeDstRoot
	
	if not needPw and not needDstRoot then
		return "ok"
	end
	
	local passwdView = f:view {
		f:row {
			f:static_text {
				title = LOC "$$$/PSUpload/ExportDialog/USERNAME=Login as:",
				alignment = 'right',
				width = share 'labelWidth',
			},

			f:edit_field {
				value = bind 'username',
				truncation = 'middle',
				immediate = true,
--				width = share 'labelWidth',
				width_in_chars = 16,
				fill_horizontal = 1,
			},
		},
		
		f:spacer {	height = 5, },

		f:row {
			f:static_text {
				title = LOC "$$$/PSUpload/ExportDialog/PASSWORD=Password:",
				alignment = 'right',
				width = share 'labelWidth',
			},

			f:password_field {
				value = bind 'password',
				tooltip = LOC "$$$/PSUpload/ExportDialog/PASSWORDTT=Leave this field blank, if you don't want to store the password.\nYou will be prompted for the password later.",
				truncation = 'middle',
				immediate = true,
				width = share 'labelWidth',
				fill_horizontal = 1,
			},
		},
	}

	local dstRootView = f:view {
		f:row {
			f:static_text {
				title = LOC "$$$/PSUpload/ExportDialog/DstRoot=Target Album:",
				alignment = 'right',
				width = share 'labelWidth',
			},

			f:edit_field {
				tooltip = LOC "$$$/PSUpload/ExportDialog/DstRootTT=Enter the target directory below the diskstation share '/photo' or '/home/photo'\n(may be different from the Album name shown in PhotoStation)",
				value = bind( "dstRoot" ),
				width_in_chars = 16,
				fill_horizontal = 1,
			},
		}, 
		
		f:spacer {	height = 5, },

		f:row {
			f:checkbox {
				title = LOC "$$$/PSUpload/ExportDialog/createDstRoot=Create Album, if needed",
				alignment = 'left',
				value = bind( "createDstRoot" ),
			},
		},
	}

	-- Create the contents for the dialog.
	local c = f:view {
		bind_to_object = exportParams,

		conditionalItem(needPw, passwdView), 
		f:spacer {	height = 10, },
		conditionalItem(needDstRoot, dstRootView), 
	}

	return LrDialogs.presentModalDialog {
			title = "Enter missing parameters",
			contents = c
		}
end

------------- getDateTimeOriginal -------------------------------------------------------------------

-- getDateTimeOriginal(srcFilename, srcPhoto)
-- get the DateTimeOriginal (capture date) of a photo or whatever comes close to it
-- tries various methods to get the info including Lr metadata, exiftool (if enabled), file infos
-- returns a unix timestamp 
function getDateTimeOriginal(srcFilename, srcPhoto)
	local srcDateTime = nil
	
	if srcPhoto:getRawMetadata("dateTimeOriginal") then
		srcDateTime = srcPhoto:getRawMetadata("dateTimeOriginal")
		writeLogfile(3, "  dateTimeOriginal: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
	elseif srcPhoto:getRawMetadata("dateTimeOriginalISO8601") then
		srcDateTime = srcPhoto:getRawMetadata("dateTimeOriginalISO8601")
		writeLogfile(3, "  dateTimeOriginalISO8601: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
	elseif srcPhoto:getRawMetadata("dateTimeDigitized") then
		srcDateTime = srcPhoto:getRawMetadata("dateTimeDigitized")
		writeLogfile(3, "  dateTimeDigitized: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
	elseif srcPhoto:getRawMetadata("dateTimeDigitizedISO8601") then
		srcDateTime = srcPhoto:getRawMetadata("dateTimeDigitizedISO8601")
		writeLogfile(3, "  dateTimeDigitizedISO8601: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
	elseif srcPhoto:getFormattedMetadata("dateCreated") then
		local srcDateTimeStr = srcPhoto:getFormattedMetadata("dateCreated")
		local year,month,day,hour,minute,second,tzone
		writeLogfile(3, "dateCreated: " .. srcDateTimeStr .. "\n")
		
		-- iptcDateCreated: date is mandatory, time as whole, seconds and timezone may or may not be present
		for year,month,day,hour,minute,second,tzone in string.gmatch(srcDateTimeStr, "(%d+)-(%d+)-(%d+)T*(%d*):*(%d*):*(%d*)Z*(%w*)") do
			writeLogfile(4, string.format("dateCreated: %s Year: %s Month: %s Day: %s Hour: %s Minute: %s Second: %s Zone: %s\n",
											srcDateTimeStr, year, month, day, ifnil(hour, "00"), ifnil(minute, "00"), ifnil(second, "00"), ifnil(tzone, "local")))
			srcDateTime = LrDate.timeFromComponents(tonumber(year), tonumber(month), tonumber(day),
													tonumber(ifnil(hour, "0")),
													tonumber(ifnil(minute, "0")),
													tonumber(ifnil(second, "0")),
													iif(not tzone or tzone == "", "local", tzone))
		end
		writeLogfile(4, "  dateCreated: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
--[[
	else
		local custMetadata = srcPhoto:getRawMetadata("customMetadata")
		local i 
		writeLogfile(4, "customMetadata:\n")
		for i = 1, #custMetadata do
			writeLogfile(4, 'Id: ' .. custMetadata[i].id .. 
							' Value: ' .. ifnil(custMetadata[i].value, '<Nil>') .. 
							' sourcePlugin: ' .. ifnil(custMetadata[i].sourcePlugin, '<Nil>') .. '\n')
		end
]]
	end
	
	-- if nothing helps: take the fileCreationDate
	if not srcDateTime then
		local fileAttr = LrFileUtils.fileAttributes( srcFilename )
--		srcDateTime = exiftoolGetDateTimeOrg(srcFilename)
--		if srcDateTime then 
--			writeLogfile(3, "  exiftoolDateTimeOrg: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
--		elseif fileAttr["fileCreationDate"] then
		if fileAttr["fileCreationDate"] then
			srcDateTime = fileAttr["fileCreationDate"]
			writeLogfile(3, "  fileCreationDate: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
		elseif srcPhoto:getRawMetadata("dateTime") then
			srcDateTime = srcPhoto:getRawMetadata("dateTime")
			writeLogfile(3, "  dateTime: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
		else
			srcDateTime = LrDate.currentTime()
			writeLogfile(3, "  no date found, using current date: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
		end
	end
	return LrDate.timeToPosixDate(srcDateTime)
end

-----------------

-- function createTree(srcDir, srcRoot, dstRoot, dirsCreated) 
-- 	derive destination folder: dstDir = dstRoot + (srcRoot - srcDir), 
--	create each folder recursively if not already created
-- 	store created directories in dirsCreated
-- 	return created dstDir or nil on error
function createTree(srcDir, srcRoot, dstRoot, dirsCreated) 
	writeLogfile(4, "  createTree: Src Path: " .. srcDir .. " from: " .. srcRoot .. " to: " .. dstRoot .. "\n")

	-- sanitize srcRoot: avoid trailing slash and backslash
	local lastchar = string.sub(srcRoot, string.len(srcRoot))
	if lastchar == "/" or lastchar == "\\" then srcRoot = string.sub(srcRoot, 1, string.len(srcRoot) - 1) end

	-- check if picture source path is below the specified local root directory
	local subDirStartPos, subDirEndPos = string.find(string.lower(srcDir), string.lower(srcRoot))
	if subDirStartPos ~= 1 then
		writeLogfile(1, "  createTree: " .. srcDir .. " is not a subdir of " .. srcRoot .. "\n")
		return nil
	end

	-- Valid subdir: now recurse the destination path and create directories if not already done
	-- replace possible Win '\\' in path
	local dstDirRel = string.gsub(string.sub(srcDir, subDirEndPos+2), "\\", "/")

	-- sanitize dstRoot: avoid trailing slash
	if string.sub(dstRoot, string.len(dstRoot)) == "/" then dstRoot = string.sub(dstRoot, 1, string.len(dstRoot) - 1) end
	local dstDir = dstRoot .."/" .. dstDirRel

	writeLogfile(4,"  createTree: dstDir is: " .. dstDir .. "\n")
	
	local parentDir = dstRoot
	local restDir = dstDirRel
	
	while restDir do
		local slashPos = ifnil(string.find(restDir,"/"), 0)
		local newDir = string.sub(restDir,1, slashPos-1)
		local newPath = parentDir .. "/" .. newDir

		if not dirsCreated[newPath] then
			writeLogfile(2,"Create dir - parent: " .. parentDir .. " newDir: " .. newDir .. " newPath: " .. newPath .. "\n")
			
			local paramParentDir
			if parentDir == "" then paramParentDir = "/" else paramParentDir = parentDir  end  
			if not PSUploadAPI.createFolder (paramParentDir, newDir) then
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

-----------------
-- uploadPicture(srcFilename, srcPhoto, dstDir, dstFilename, isPS6, largeThumbs, thumbQuality) 
--[[
	generate all required thumbnails and upload thumbnails and the original picture as a batch.
	The upload batch must start with any of the thumbs and end with the original picture.
	When uploading to PhotoStation 6, we don't need to upload the THUMB_L
]]
function uploadPicture(srcFilename, srcPhoto, dstDir, dstFilename, isPS6, largeThumbs, thumbQuality) 
	local picBasename = LrPathUtils.removeExtension(LrPathUtils.leafName(srcFilename))
	local picExt = LrPathUtils.extension(srcFilename)
	local thmb_XL_Filename = LrPathUtils.child(tmpdir, LrPathUtils.addExtension(picBasename .. '_XL', picExt))
	local thmb_L_Filename = LrPathUtils.child(tmpdir, LrPathUtils.addExtension(picBasename .. '_L', picExt))
	local thmb_M_Filename = LrPathUtils.child(tmpdir, LrPathUtils.addExtension(picBasename .. '_M', picExt))
	local thmb_B_Filename = LrPathUtils.child(tmpdir, LrPathUtils.addExtension(picBasename .. '_B', picExt))
	local thmb_S_Filename = LrPathUtils.child(tmpdir, LrPathUtils.addExtension(picBasename .. '_S', picExt))
	local srcDateTime = getDateTimeOriginal(srcFilename, srcPhoto)
	local retcode
	
	-- generate thumbs

	-- conversion acc. to http://www.medin.name/blog/2012/04/22/thumbnail-1000s-of-photos-on-a-synology-nas-in-hours-not-months/
--[[
	if not PSConvert.convertPic(srcFilename, '1280x1280>', 90, '0.5x0.5+1.25+0.0', thmb_XL_Filename) 
	or not PSConvert.convertPic(thmb_XL_Filename, '800x800>', 90, '0.5x0.5+1.25+0.0', thmb_L_Filename) 
	or not PSConvert.convertPic(thmb_L_Filename, '640x640>', 90, '0.5x0.5+1.25+0.0', thmb_B_Filename) 
	or not PSConvert.convertPic(thmb_L_Filename, '320x320>', 90, '0.5x0.5+1.25+0.0', thmb_M_Filename) 
	or not PSConvert.convertPic(thmb_M_Filename, '120x120>', 90, '0.5x0.5+1.25+0.0', thmb_S_Filename) 

	-- upload thumbnails and original file
	or not PSUploadAPI.uploadPictureFile(thmb_B_Filename, srcDateTime, dstDir, dstFilename, 'THUM_B', 'image/jpeg', 'FIRST') 
	or not PSUploadAPI.uploadPictureFile(thmb_M_Filename, srcDateTime, dstDir, dstFilename, 'THUM_M', 'image/jpeg', 'MIDDLE') 
	or not PSUploadAPI.uploadPictureFile(thmb_S_Filename, srcDateTime, dstDir, dstFilename, 'THUM_S', 'image/jpeg', 'MIDDLE') 
	or (not isPS6 and not PSUploadAPI.uploadPictureFile(thmb_L_Filename, srcDateTime, dstDir, dstFilename, 'THUM_L', 'image/jpeg', 'MIDDLE'))
	or not PSUploadAPI.uploadPictureFile(thmb_XL_Filename, srcDateTime, dstDir, dstFilename, 'THUM_XL', 'image/jpeg', 'MIDDLE') 
	or not PSUploadAPI.uploadPictureFile(srcFilename, srcDateTime, dstDir, dstFilename, 'ORIG_FILE', 'image/jpeg', 'LAST') 
	then
		retcode = false
	else
		retcode = true
	end

]]
		
	if ( not largeThumbs and not PSConvert.convertPicConcurrent(srcFilename, 
								'-strip -flatten -quality '.. tostring(thumbQuality) .. ' -auto-orient -colorspace RGB -unsharp 0.5x0.5+1.25+0.0 -colorspace sRGB', 
								'1280x1280>', thmb_XL_Filename,
								'800x800>',    thmb_L_Filename,
								'640x640>',    thmb_B_Filename,
								'320x320>',    thmb_M_Filename,
								'120x120>',    thmb_S_Filename) )
	or ( largeThumbs and not PSConvert.convertPicConcurrent(srcFilename, 
								'-strip -flatten -quality '.. tostring(thumbQuality) .. ' -auto-orient -colorspace RGB -unsharp 0.5x0.5+1.25+0.0 -colorspace sRGB', 
								'1280x1280>^', thmb_XL_Filename,
								'800x800>^',   thmb_L_Filename,
								'640x640>^',   thmb_B_Filename,
								'320x320>^',   thmb_M_Filename,
								'120x120>^',   thmb_S_Filename) )

	-- upload thumbnails and original file
	or not PSUploadAPI.uploadPictureFile(thmb_B_Filename, srcDateTime, dstDir, dstFilename, 'THUM_B', 'image/jpeg', 'FIRST') 
	or not PSUploadAPI.uploadPictureFile(thmb_M_Filename, srcDateTime, dstDir, dstFilename, 'THUM_M', 'image/jpeg', 'MIDDLE') 
	or not PSUploadAPI.uploadPictureFile(thmb_S_Filename, srcDateTime, dstDir, dstFilename, 'THUM_S', 'image/jpeg', 'MIDDLE') 
	or (not isPS6 and not PSUploadAPI.uploadPictureFile(thmb_L_Filename, srcDateTime, dstDir, dstFilename, 'THUM_L', 'image/jpeg', 'MIDDLE'))
	or not PSUploadAPI.uploadPictureFile(thmb_XL_Filename, srcDateTime, dstDir, dstFilename, 'THUM_XL', 'image/jpeg', 'MIDDLE') 
	or not PSUploadAPI.uploadPictureFile(srcFilename, srcDateTime, dstDir, dstFilename, 'ORIG_FILE', 'image/jpeg', 'LAST') 
	then
		retcode = false
	else
		retcode = true
	end

	LrFileUtils.delete(thmb_B_Filename)
	LrFileUtils.delete(thmb_M_Filename)
	LrFileUtils.delete(thmb_S_Filename)
	LrFileUtils.delete(thmb_L_Filename)
	LrFileUtils.delete(thmb_XL_Filename)

	return retcode
end

-----------------
-- uploadVideo(srcVideoFilename, srcPhoto, dstDir, dstFilename, isPS6, largeThumbs, thumbQuality, addVideo) 
--[[
	generate all required thumbnails, at least one video with alternative resolution (if we don't do, PhotoStation will do)
	and upload thumbnails, alternative video and the original video as a batch.
	The upload batch must start with any of the thumbs and end with the original video.
	When uploading to PhotoStation 6, we don't need to upload the THUMB_L
]]
function uploadVideo(srcVideoFilename, srcPhoto, dstDir, dstFilename, isPS6, largeThumbs, thumbQuality, addVideo) 
	local picBasename = LrPathUtils.removeExtension(LrPathUtils.leafName(srcVideoFilename))
	local vidExtOrg = LrPathUtils.extension(srcVideoFilename)
	local picPath = LrPathUtils.parent(srcVideoFilename)
	local picExt = 'jpg'
	local vidExt = 'mp4'
	local thmb_ORG_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename, picExt))
	local thmb_XL_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_XL', picExt))
	local thmb_L_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_L', picExt))
	local thmb_M_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_M', picExt))
	local thmb_B_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_B', picExt))
	local thmb_S_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_S', picExt))
	local vid_MOB_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_MOB', vidExt)) 	--  240p
	local vid_LOW_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_LOW', vidExt))	--  360p
	local vid_MED_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_MED', vidExt))	--  720p
	local vid_HIGH_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_HIGH', vidExt))	-- 1080p
	local realDimension
	local retcode
	local convKeyOrig, convKeyAdd, dummyIndex
	local vid_Orig_Filename, vid_Add_Filename
	
	writeLogfile(3, string.format("uploadVideo: %s\n", srcVideoFilename)) 
	local convParams = { 
		HIGH =  	{ height = 1020,	filename = vid_HIGH_Filename },
		MEDIUM = 	{ height = 720, 	filename = vid_MED_Filename },
		LOW =		{ height = 360, 	filename = vid_LOW_Filename },
		MOBILE =	{ height = 240,		filename = vid_MOB_Filename },
	}
	
	-- get video infos: DateTimeOrig, duration, dimension, sample aspect ratio, display aspect ratio
	local retcode, srcDateTime, duration, dimension, sampleAR, dispAR = PSConvert.ffmpegGetAdditionalInfo(srcVideoFilename)
	if not retcode then
		return false
	end
	
	if not srcDateTime then
		srcDateTime = getDateTimeOriginal(srcFilename, srcPhoto)
	end
	
	-- get the real dimension: may be different from dimension if dar is set
	-- dimension: NNNxMMM
	local srcHeight = tonumber(string.sub(dimension, string.find(dimension,'x') + 1, -1))
	if (ifnil(dispAR, '') == '') or (ifnil(sampleAR,'') == '1:1') then
		realDimension = dimension
		-- aspectRatio: NNN:MMM
		dispAR = string.gsub(dimension, 'x', ':')
	else
		local darWidth = tonumber(string.sub(dispAR, 1, string.find(dispAR,':') - 1))
		local darHeight = tonumber(string.sub(dispAR, string.find(dispAR,':') + 1, -1))
		local realSrcWidth = srcHeight * darWidth / darHeight
		realDimension = tostring(realSrcWidth) .. 'x' .. srcHeight
	end
	
	dummyIndex, convKeyOrig = PSConvert.getConvertKey(srcHeight)
	vid_Orig_Filename = convParams[convKeyOrig].filename
	convKeyAdd = addVideo[convKeyOrig]
	if convKeyAdd ~= 'None' then
		vid_Add_Filename = convParams[convKeyAdd].filename
	end
	
	-- generate first thumb from video
	if not PSConvert.ffmpegGetThumbFromVideo (srcVideoFilename, thmb_ORG_Filename, realDimension)

	-- generate all other thumb from first thumb
	-- conversion acc. to http://www.medin.name/blog/2012/04/22/thumbnail-1000s-of-photos-on-a-synology-nas-in-hours-not-months/
--[[
	if not PSConvert.convertPic(thmb_ORG_Filename, '1280x1280>', 70, '0.5x0.5+1.25+0.0', thmb_XL_Filename) 
	or not PSConvert.convertPic(thmb_XL_Filename, '800x800>', 70, '0.5x0.5+1.25+0.0', thmb_L_Filename) 
	or not PSConvert.convertPic(thmb_L_Filename, '640x640>', 70, '0.5x0.5+1.25+0.0', thmb_B_Filename) 
	or not PSConvert.convertPic(thmb_L_Filename, '320x320>', 70, '0.5x0.5+1.25+0.0', thmb_M_Filename) 
	or not PSConvert.convertPic(thmb_M_Filename, '120x120>', 70, '0.5x0.5+1.25+0.0', thmb_S_Filename) 
]]	
	or ( not largeThumbs and not PSConvert.convertPicConcurrent(thmb_ORG_Filename, 
								'-strip -flatten -quality '.. tostring(thumbQuality) .. ' -auto-orient -colorspace RGB -unsharp 0.5x0.5+1.25+0.0 -colorspace sRGB', 
								'1280x1280>', thmb_XL_Filename,
								'800x800>',    thmb_L_Filename,
								'640x640>',    thmb_B_Filename,
								'320x320>',    thmb_M_Filename,
								'120x120>',    thmb_S_Filename) )
	or ( largeThumbs and not PSConvert.convertPicConcurrent(thmb_ORG_Filename, 
								'-strip -flatten -quality '.. tostring(thumbQuality) .. ' -auto-orient -colorspace RGB -unsharp 0.5x0.5+1.25+0.0 -colorspace sRGB', 
								'1280x1280>^', thmb_XL_Filename,
								'800x800>^',   thmb_L_Filename,
								'640x640>^',   thmb_B_Filename,
								'320x320>^',   thmb_M_Filename,
								'120x120>^',   thmb_S_Filename) )

	-- generate mp4 in original size if srcVideo is not already mp4
	or ((string.lower(vidExtOrg) ~= vidExt) and not PSConvert.convertVideo(srcVideoFilename, dispAR, srcHeight, vid_Orig_Filename))
	
	-- generate additional video, if requested
	or ((convKeyAdd ~= 'None') and not PSConvert.convertVideo(srcVideoFilename, dispAR, convParams[convKeyAdd].height, vid_Add_Filename))

	-- upload thumbs, preview videos and original file
	or not PSUploadAPI.uploadPictureFile(thmb_B_Filename, srcDateTime, dstDir, dstFilename, 'THUM_B', 'image/jpeg', 'FIRST') 
	or not PSUploadAPI.uploadPictureFile(thmb_M_Filename, srcDateTime, dstDir, dstFilename, 'THUM_M', 'image/jpeg', 'MIDDLE') 
	or not PSUploadAPI.uploadPictureFile(thmb_S_Filename, srcDateTime, dstDir, dstFilename, 'THUM_S', 'image/jpeg', 'MIDDLE') 
	or (not isPS6 and not PSUploadAPI.uploadPictureFile(thmb_L_Filename, srcDateTime, dstDir, dstFilename, 'THUM_L', 'image/jpeg', 'MIDDLE')) 
	or not PSUploadAPI.uploadPictureFile(thmb_XL_Filename, srcDateTime, dstDir, dstFilename, 'THUM_XL', 'image/jpeg', 'MIDDLE') 
	or ((string.lower(vidExtOrg) ~= vidExt) and not PSUploadAPI.uploadPictureFile(vid_Orig_Filename, srcDateTime, dstDir, dstFilename, 'MP4_'.. convKeyOrig, 'video/mpeg', 'MIDDLE'))
	or ((convKeyAdd ~= 'None') and not PSUploadAPI.uploadPictureFile(vid_Add_Filename, srcDateTime, dstDir, dstFilename, 'MP4_'.. convKeyAdd, 'video/mpeg', 'MIDDLE'))
	or not PSUploadAPI.uploadPictureFile(srcVideoFilename, srcDateTime, dstDir, dstFilename, 'ORIG_FILE', 'video/mpeg', 'LAST') 
	then 
		retcode = false
	else 
		retcode = true
	end
	
	LrFileUtils.delete(thmb_ORG_Filename)
	LrFileUtils.delete(thmb_B_Filename)
	LrFileUtils.delete(thmb_M_Filename)
	LrFileUtils.delete(thmb_S_Filename)
	LrFileUtils.delete(thmb_L_Filename)
	LrFileUtils.delete(thmb_XL_Filename)
	LrFileUtils.delete(vid_LOW_Filename)

	return retcode
end

--------------------------------------------------------------------------------

-- PSUploadTask.processRenderedPhotos( functionContext, exportContext )
-- The export callback called from Lr when the export starts
function PSUploadTask.processRenderedPhotos( functionContext, exportContext )

	-- Make a local reference to the export parameters.
	
	local exportSession = exportContext.exportSession
	local exportParams = exportContext.propertyTable

	-- Start Debugging
	local logfilename = LrPathUtils.child(tmpdir, "PhotoStationUpload.log")
	openLogfile(logfilename, exportParams.logLevel)
	
	-- generate global environment settings
	if not initializeEnv (exportParams) then
		writeLogfile(1, "ProcessRenderedPhotos: cannot initialize environment!\n" )
		return
	end


	writeLogfile(2, "ProcessRenderedPhotos starting\n" )
	
	-- Set progress title.
	local nPhotos = exportSession:countRenditions()

	local progressScope = exportContext:configureProgress {
						title = nPhotos > 1
							   and LOC( "$$$/PSUpload/Upload/Progress=Uploading ^1 photos to PhotoStation", nPhotos )
							   or LOC "$$$/PSUpload/Upload/Progress/One=Uploading one photo to PhotoStation",
					}

	-- Get missing settings (password, and target directory), if not stored in preset.
	if promptForMissingSettings(exportParams) == 'cancel' then
		return
	end
	
	-- Build addVideo table
	local addVideo = {
		HIGH = 		exportParams.addVideoHigh,
		MEDIUM = 	exportParams.addVideoMed,
		LOW = 		exportParams.addVideoLow,
		MOBILE = 	'None',
	}
	
	local startTime = LrDate.currentTime()
	local numPics = 0

	-- Login to PhotoStation.
	local result, reason = PSUploadAPI.login(exportParams.username, exportParams.password)
	if not result then
		writeLogfile(1, "Login failed, reason:" .. reason .. "\n")
		closeLogfile()
		LrDialogs.message( LOC "$$$/PSUpload/Upload/Errors/LoginError=Login to " .. 
							iif(exportParams.usePersonalPS, "Personal", "Standard") .. " PhotoStation" .. 
							iif(exportParams.usePersonalPS and exportParams.personalPSOwner,exportParams.personalPSOwner, "") .. " failed.", reason)
		return false 
	end
	writeLogfile(2, "Login to " .. iif(exportParams.usePersonalPS, "Personal", "Standard") .. " PhotoStation" .. 
							iif(exportParams.usePersonalPS and exportParams.personalPSOwner,exportParams.personalPSOwner, "") .. " OK\n")

	writeLogfile(2, "--------------------------------------------------------------------\n")

	-- Iterate through photo renditions.

	local failures = {}
	local dirsCreated = {}
	
	for _, rendition in exportContext:renditions{ stopIfCanceled = true } do
	
		-- Wait for next photo to render.

		local success, pathOrMessage = rendition:waitForRender()
		
		-- Check for cancellation again after photo has been rendered.
		
		if progressScope:isCanceled() then break end
		
		if success then
			writeLogfile(3, "\nNext photo: " .. pathOrMessage .. "\n")
			numPics = numPics + 1
			
			local srcPhoto = rendition.photo
			local filename = LrPathUtils.leafName( pathOrMessage )
			local srcFilename = srcPhoto:getRawMetadata("path") 
			local dstDir
			
			-- sanitize dstRoot: remove leading and trailings slashes
			if string.sub(exportParams.dstRoot,1,1) == "/" then exportParams.dstRoot = string.sub(exportParams.dstRoot, 2) end
			if string.sub(exportParams.dstRoot, string.len(exportParams.dstRoot)) == "/" then exportParams.dstRoot = string.sub(exportParams.dstRoot, 1, -2) end
			writeLogfile(3, "  sanitized dstRoot: " .. exportParams.dstRoot .. "\n")
			
			-- check if target Album (dstRoot) should be created 
			if exportParams.createDstRoot and not createTree( './' .. exportParams.dstRoot,  ".", "", dirsCreated ) then
				table.insert( failures, srcFilename )
				break 
			end
			
			-- check if tree structure should be preserved
			if not exportParams.copyTree then
				-- just put it into the configured destination folder
				if not exportParams.dstRoot or exportParams.dstRoot == '' then
					dstDir = '/'
				else
					dstDir = exportParams.dstRoot
				end
			else
				dstDir = createTree( LrPathUtils.parent(srcFilename), exportParams.srcRoot, exportParams.dstRoot, dirsCreated) 
			end
			
			if not dstDir then 	
				table.insert( failures, srcFilename )
				break 
			end
			
			if srcPhoto:getRawMetadata("isVideo") then
				writeLogfile(4, pathOrMessage .. ": is video\n") 
				if not uploadVideo(pathOrMessage, srcPhoto, dstDir, filename, exportParams.isPS6, exportParams.largeThumbs, exportParams.thumbQuality, addVideo) then
--				if not uploadVideo(srcFilename, srcPhoto, dstDir, filename, exportParams.isPS6, exportParams.largeThumbs, exportParams.thumbQuality, addVideo) then
					writeLogfile(1, LrDate.formatMediumTime(LrDate.currentTime()) .. 
									': Upload of "' .. filename .. '" to "' .. dstDir .. '" failed!!!\n')
					table.insert( failures, dstDir .. "/" .. filename )
				else
					writeLogfile(2, LrDate.formatMediumTime(LrDate.currentTime()) .. 
									': Upload of "' .. filename .. '" to "' .. dstDir .. '" done\n')
				end
			else
				if not uploadPicture(pathOrMessage, srcPhoto, dstDir, filename, exportParams.isPS6, exportParams.largeThumbs, exportParams.thumbQuality) then
					writeLogfile(1, LrDate.formatMediumTime(LrDate.currentTime()) .. 
									': Upload of "' .. filename .. '" to "' .. exportParams.serverUrl .. "-->" ..  dstDir .. '" failed!!!\n')
					table.insert( failures, dstDir .. "/" .. filename )
				else
					writeLogfile(2, LrDate.formatMediumTime(LrDate.currentTime()) .. 
									': Upload of "' .. filename .. '" to "' .. exportParams.serverUrl .. "-->" .. dstDir .. '" done\n')
				end
			end

			LrFileUtils.delete( pathOrMessage )
					
		end
	end

	writeLogfile(2,"--------------------------------------------------------------------\n")
	writeLogfile(2,"Logout from PhotoStation\n")
	if not PSUploadAPI.logout () then
		writeLogfile(1,"Logout failed\n")
	end
	
	local timeUsed = 	LrDate.currentTime() - startTime
	local timePerPic = timeUsed / numPics
	writeLogfile(2,string.format("Processed %d pics in %d seconds: %.1f seconds/pic\n", numPics, timeUsed, timePerPic))
	closeLogfile()
	
	if #failures > 0 then
		local message
		if #failures == 1 then
			message = LOC ("$$$/PSUpload/Upload/Errors/OneFileFailed=1 file of ^1 files failed to upload correctly.", numPics)
		else
			message = LOC ( "$$$/PSUpload/Upload/Errors/SomeFileFailed=^1 of ^2 files failed to upload correctly.", #failures, numPics)
		end
		local action = LrDialogs.confirm(message, table.concat( failures, "\n" ), "Goto Logfile", "Never mind")
		if action == "ok" then
			LrShell.revealInShell(logfilename)
		end
	else
		message = LOC ("$$$/PSUpload/Upload/Errors/UploadOK=PhotoStation Upload: All ^1 files uploaded successfully (^2 secs/pic).", numPics, string.format("%.1f", timePerPic))
		LrDialogs.showBezel(message, 5)
	end
end
