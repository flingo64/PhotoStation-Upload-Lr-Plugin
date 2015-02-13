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
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'

require "PSUploadAPI"

--============================================================================--

PSUploadTask = {}

-- we can store some variables in 'global' local variables safely:
-- each export task will get its own copy of these variables
local tmpdir = LrPathUtils.getStandardFilePath("temp")
local conv
local ffmpeg
local qtfstart
-- local exiftool
local logfilename

local serverUrl
local loginPath
local uploadPath

--[[loglevel:
	0 -	nothing
	1 - errors
	2 - info
	3 - tracing
	4 - debug
]]	
local loglevel

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

---------------------- encoding routines ---------------------------------------------------------

function trim(s)
  return (string.gsub(s,"^%s*(.-)%s*$", "%1"))
end

function urlencode(str)
	if (str) then
		str = string.gsub (str, "\n", "\r\n")
		str = string.gsub (str, "([^%w ])",function (c) return string.format ("%%%02X", string.byte(c)) end)
		str = string.gsub (str, " ", "%%20")
	end
	return str
end 

function unblankFilename(str)
	if (str) then
		str = string.gsub (str, " ", "-")
	end
	return str
end 

function cmdlineQuote()
	if WIN_ENV then
		return '"'
	elseif MAC_ENV then
		return ''
	else
		return ''
	end
end

function shellEscape(str)
	if WIN_ENV then
--		return(string.gsub(str, '>', '^>'))
		return(string.gsub(string.gsub(str, '%^ ', '^^ '), '>', '^>'))
	elseif MAC_ENV then
--		return("'" .. str .. "'")
		return(string.gsub(string.gsub(string.gsub(str, '>', '\\>'), '%(', '\\('), '%)', '\\)'))
	else
		return str
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

	PSUploadAPI.initialize(exportParams.serverUrl, iif(exportParams.usePersonalPS, exportParams.personalPSOwner, nil))

	local convertprog = 'convert'
	local ffmpegprog = 'ffmpeg'
	local qtfstartprog = 'qt-faststart'

	if WIN_ENV  then
		local progExt = 'exe'
		convertprog = LrPathUtils.addExtension(convertprog, progExt)
		ffmpegprog = LrPathUtils.addExtension(ffmpegprog, progExt)
		qtfstartprog = LrPathUtils.addExtension(qtfstartprog, progExt)
	end
	
	conv = LrPathUtils.child(LrPathUtils.child(exportParams.PSUploaderPath, 'ImageMagick'), convertprog)
	ffmpeg = LrPathUtils.child(LrPathUtils.child(exportParams.PSUploaderPath, 'ffmpeg'), ffmpegprog)
	qtfstart = LrPathUtils.child(LrPathUtils.child(exportParams.PSUploaderPath, 'ffmpeg'), qtfstartprog)

--[[
	-- exiftool is not required
	if  LrFileUtils.exists(exiftoolprog)  ~= 'file' then
		exiftool = nil 
	else
		exiftool = exiftoolprog
	end
]]
	writeLogfile(4, "initializeEnv: \nconv: " .. conv .. "\nffmpeg: ".. ffmpeg .. "\nqt-faststart: " .. qtfstart)
	return true
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

---------------------- Exiftool functions ----------------------------------------------------------
--[[
function exiftoolGetDateTimeOrg(srcFilename)
	-- returns DateTimeOriginal / creation_time retrieved via exiftool as Cocoa timestamp
	local outfile = LrFileUtils.chooseUniqueFileName(LrPathUtils.child(tmpdir, "exifDateTime.txt"))
	local cmdline 
	
	if exiftool then
		cmdline = '"' .. exiftool .. '" -s3 -d %s -datetimeoriginal ' .. srcFilename .. ' > ' .. outfile
	else
		return nil
	end
	
	writeLogfile(4,cmdline .. "\n")
	if LrTasks.execute(cmdline) > 0 then
		writeLogfile(3,"... failed!\n")
		return nil
	end

	local datetimeOrg = LrFileUtils.readFile( outfile )
	LrFileUtils.delete(outfile)
	
	return LrDate.timeFromPosixDate(datetimeOrg)
end
]]

---------------------- ffmpeg functions ----------------------------------------------------------

-- ffmpegGetDateTimeOrg(srcVideoFilename)
-- get the capture date of a video via ffmpeg. Lr won't give you the capture date for videos
function ffmpegGetDateTimeOrg(srcVideoFilename)
	-- returns DateTimeOriginal / creation_time retrieved via ffmpeg  as Cocoa timestamp
	local picBasename = LrPathUtils.removeExtension(LrPathUtils.leafName(srcVideoFilename))
	local outfile =  LrPathUtils.child(tmpdir, LrPathUtils.addExtension(picBasename .. '_ffmpeg', 'txt'))
	-- LrTask.execute() will call cmd.exe /c cmdline, so we need additional outer quotes
	local cmdline = cmdlineQuote() .. '"' .. ffmpeg .. '" -i "' .. srcVideoFilename .. '" 2> ' .. outfile .. cmdlineQuote()

	writeLogfile(4, cmdline .. "\n")
	LrTasks.execute(cmdline)
	-- ignore errorlevel of ffmpeg here (is 1) , just check the outfile
	
	if not LrFileUtils.exists(outfile) then
		writeLogfile(3, "  error on: " .. cmdline .. "\n")
		return nil
	end

	local ffmpegReport = LrFileUtils.readFile(outfile)
	writeLogfile(4, "ffmpeg report:\n" .. ffmpegReport)
	
	-- search for avp: 'creation_time : date'
	local v, dateTimeOrigString, dateTimeOrig
	for v in string.gmatch(ffmpegReport, "creation_time%s+:%s+([%d%p]+%s[%d%p]+)") do
		dateTimeOrigString = v
		writeLogfile(4, "dateTimeOrigString: " .. dateTimeOrigString .. "\n")
		-- translate from  yyyy-mm-dd HH:MM:ss to timestamp
		dateTimeOrig = LrDate.timeFromComponents(string.sub(dateTimeOrigString,1,4),
												string.sub(dateTimeOrigString,6,7),
												string.sub(dateTimeOrigString,9,10),
												string.sub(dateTimeOrigString,12,13),
												string.sub(dateTimeOrigString,15,16),
												string.sub(dateTimeOrigString,18,19),
												'local')
		writeLogfile(4, "  dateTimeOrig: " .. LrDate.timeToUserFormat(dateTimeOrig, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
     end

	 LrFileUtils.delete(outfile)

	 return dateTimeOrig
end

------------- getDateTimeOriginal -------------------------------------------------------------------

-- getDateTimeOriginal(srcFilename, srcPhoto)
-- get the DateTimeOriginal (capture date) of a photo/video or whatever comes close to it
-- tries various methods to get the info including Lr metadata, ffmpeg, exiftool (if enabled), file infos
-- returns a unix timestamp 
function getDateTimeOriginal(srcFilename, srcPhoto)
	local srcDateTime = nil
	
	if srcPhoto:getRawMetadata("isVideo") then
		srcDateTime = ffmpegGetDateTimeOrg(srcFilename)
		if srcDateTime then
			writeLogfile(3, "  ffmpegDateTimeOriginal: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
		end
	else
	-- is not a video
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

---------------------- convert functions ----------------------------------------------------------

-- convertPic(srcFilename, size, quality, unsharp, dstFilename)
-- converts a picture file using the ImageMagick convert tool
function convertPic(srcFilename, size, quality, unsharp, dstFilename)
	local cmdline = cmdlineQuote() .. 
				'"' .. conv .. '" ' .. srcFilename .. ' -resize ' .. shellEscape(size) .. ' -quality ' .. quality .. ' -unsharp ' .. unsharp .. ' ' .. dstFilename ..
				cmdlineQuote()

	writeLogfile(4,cmdline .. "\n")
	if LrTasks.execute(cmdline) > 0 then
		writeLogfile(3,"... failed!\n")
		writeLogfile(1, "convertPic: " .. srcFilename .. " to " .. dstFilename .. " failed!\n")
		return false
	end

	return true
end


-- convertPicConcurrent(srcFilename, convParams, xlSize, xlFile, lSize, lFile, bSize, bFile, mSize, mFile, sSize, sFile)
-- converts a picture file using the ImageMagick convert tool into 5 thumbs in one run
function convertPicConcurrent(srcFilename, convParams, xlSize, xlFile, lSize, lFile, bSize, bFile, mSize, mFile, sSize, sFile)
	local cmdline = cmdlineQuote() .. '"' .. conv .. '" "' .. srcFilename .. '" ' ..
			shellEscape(
				'( -clone 0 -define jpeg:size=' .. xlSize .. ' -thumbnail '  .. xlSize .. ' ' .. convParams .. ' -write ' .. xlFile .. ' ) -delete 0 ' ..
				'( +clone   -define jpeg:size=' ..  lSize .. ' -thumbnail '  ..  lSize .. ' ' .. convParams .. ' -write ' ..  lFile .. ' +delete ) ' ..
				'( +clone   -define jpeg:size=' ..  bSize .. ' -thumbnail '  ..  bSize .. ' ' .. convParams .. ' -write ' ..  bFile .. ' +delete ) ' ..
				'( +clone   -define jpeg:size=' ..  mSize .. ' -thumbnail '  ..  mSize .. ' ' .. convParams .. ' -write ' ..  mFile .. ' +delete ) ' ..
						   '-define jpeg:size=' ..  sSize .. ' -thumbnail '  ..  sSize .. ' ' .. convParams .. ' ' 		  ..  sFile
			) .. cmdlineQuote()
	writeLogfile(4, cmdline .. "\n")
	if LrTasks.execute(cmdline) > 0 then
		writeLogfile(3,"... failed!\n")
		writeLogfile(1, "convertPicConcurrent: " .. srcFilename  .. " failed!\n")
		return false
	end

	return true
end

------------------

-- convertVideo(srcVideoFilename, resolution, dstVideoFilename)
--[[ 
	converts a video to an mp4 with a given resolution using the ffmpeg and qt-faststart tool
	Supported resolutions:
	MOB	(mobile)	320x180
	LOW				480x360
	MED				1280x720
	HIGH			1920x1080
	
	Note: resolution is currently ignored: always use MED resolution !!!
]]
function convertVideo(srcVideoFilename, resolution, dstVideoFilename)
	local tmpVideoFilename = LrPathUtils.replaceExtension(LrPathUtils.removeExtension(dstVideoFilename) .. '_TMP', LrPathUtils.extension(dstVideoFilename))
	local outfile =  LrPathUtils.replaceExtension(tmpVideoFilename, 'txt')

	local encOpt
	if WIN_ENV then
		encOpt = '-acodec libvo_aacenc'
	else
		encOpt = '-strict experimental -acodec aac'
	end
	
--	LrFileUtils.copy(srcVideoFilename, srcVideoFilename ..".bak")
	local cmdline =  cmdlineQuote() ..
				'"' .. ffmpeg .. '" -i "' .. 
				srcVideoFilename .. 
				'" -y ' .. encOpt .. 
				" -ar 44100 -b:a 96k -ac 2 -pass 1 -vcodec libx264 -b:v 256k -bt 256k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 0 -vprofile baseline -vsync 2 -level 13 -coder 0 -refs 1 -bf 0 -subq 1 -trellis 0 -me_method epzs -partitions 0 -f mp4 -s 480x360 -aspect 480:360 " .. 
				tmpVideoFilename .. ' 2> ' .. outfile ..
				cmdlineQuote()
				
	writeLogfile(4, cmdline .. "\n")
	if LrTasks.execute(cmdline) > 0 or not LrFileUtils.exists(tmpVideoFilename) then
		writeLogfile(3, "  error on: " .. cmdline .. "\n")
		LrFileUtils.delete(outfile)
		return false
	end

	cmdline =   cmdlineQuote() ..
				'"' .. ffmpeg .. '" -i "' .. 
				srcVideoFilename .. 
				'" -y ' .. encOpt .. 
				" -ar 44100 -b:a 96k -ac 2 -pass 2 -vcodec libx264 -b:v 256k -bt 256k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 0 -vprofile baseline -vsync 2 -level 13 -coder 0 -refs 1 -bf 0 -subq 5 -trellis 0 -me_method hex -partitions +parti4x4+parti8x8+partp4x4+partp8x8+partb8x8 -f mp4 -s 480x360 -aspect 480:360 " .. 
				tmpVideoFilename .. ' 2> ' .. outfile ..
				cmdlineQuote()

	writeLogfile(4, cmdline .. "\n")
	if LrTasks.execute(cmdline) > 0 or not LrFileUtils.exists(tmpVideoFilename) then
		writeLogfile(3, "  error on: " .. cmdline .. "\n")
		LrFileUtils.delete(outfile)
		LrFileUtils.delete(tmpVideoFilename)
		return false
	end

--	LrFileUtils.copy(tmpVideoFilename, tmpVideoFilename ..".bak")
	cmdline = 	'"' .. qtfstart .. '" ' ..  tmpVideoFilename .. ' ' .. dstVideoFilename .. ' 2> ' .. outfile

	writeLogfile(4, cmdline .. "\n")
	if LrTasks.execute(cmdline) > 0 then
		writeLogfile(3, "  error on: " .. cmdline .. "\n")
		LrFileUtils.delete(outfile)
		LrFileUtils.delete(tmpVideoFilename)
		return false
	end

	LrFileUtils.delete(outfile)
	LrFileUtils.delete(tmpVideoFilename)
	return true
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
-- uploadPicture(srcFilename, srcDateTime, dstDir, dstFilename, isPS6, largeThumbs, thumbQuality) 
--[[
	generate all required thumbnails and upload thumbnails and the original picture as a batch.
	The upload batch must start with any of the thumbs and end with the original picture.
	When uploading to PhotoStation 6, we don't need to upload the THUMB_L
]]
function uploadPicture(srcFilename, srcDateTime, dstDir, dstFilename, isPS6, largeThumbs, thumbQuality) 
	local picBasename = LrPathUtils.removeExtension(LrPathUtils.leafName(srcFilename))
	local picExt = LrPathUtils.extension(srcFilename)
	local thmb_XL_Filename = LrPathUtils.child(tmpdir, LrPathUtils.addExtension(picBasename .. '_XL', picExt))
	local thmb_L_Filename = LrPathUtils.child(tmpdir, LrPathUtils.addExtension(picBasename .. '_L', picExt))
	local thmb_M_Filename = LrPathUtils.child(tmpdir, LrPathUtils.addExtension(picBasename .. '_M', picExt))
	local thmb_B_Filename = LrPathUtils.child(tmpdir, LrPathUtils.addExtension(picBasename .. '_B', picExt))
	local thmb_S_Filename = LrPathUtils.child(tmpdir, LrPathUtils.addExtension(picBasename .. '_S', picExt))
	local cmdline
	local retcode
	
	-- generate thumbs

	-- conversion acc. to http://www.medin.name/blog/2012/04/22/thumbnail-1000s-of-photos-on-a-synology-nas-in-hours-not-months/
--[[
	if not convertPic(srcFilename, '1280x1280>', 90, '0.5x0.5+1.25+0.0', thmb_XL_Filename) 
	or not convertPic(thmb_XL_Filename, '800x800>', 90, '0.5x0.5+1.25+0.0', thmb_L_Filename) 
	or not convertPic(thmb_L_Filename, '640x640>', 90, '0.5x0.5+1.25+0.0', thmb_B_Filename) 
	or not convertPic(thmb_L_Filename, '320x320>', 90, '0.5x0.5+1.25+0.0', thmb_M_Filename) 
	or not convertPic(thmb_M_Filename, '120x120>', 90, '0.5x0.5+1.25+0.0', thmb_S_Filename) 

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
		
	if ( not largeThumbs and not convertPicConcurrent(srcFilename, 
								'-strip -flatten -quality '.. tostring(thumbQuality) .. ' -auto-orient -colorspace RGB -unsharp 0.5x0.5+1.25+0.0 -colorspace sRGB', 
								'1280x1280>', thmb_XL_Filename,
								'800x800>',    thmb_L_Filename,
								'640x640>',    thmb_B_Filename,
								'320x320>',    thmb_M_Filename,
								'120x120>',    thmb_S_Filename) )
	or ( largeThumbs and not convertPicConcurrent(srcFilename, 
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
-- uploadVideo(srcVideoFilename, srcDateTime, dstDir, dstFilename, isPS6, largeThumbs, thumbQuality) 
--[[
	generate all required thumbnails, at least one video with alternative resolution (if we don't do, PhotoStation will do)
	and upload thumbnails, alternative video and the original video as a batch.
	The upload batch must start with any of the thumbs and end with the original video.
	When uploading to PhotoStation 6, we don't need to upload the THUMB_L
]]
function uploadVideo(srcVideoFilename, srcDateTime, dstDir, dstFilename, isPS6, largeThumbs, thumbQuality) 
	local outfile =  LrPathUtils.replaceExtension(srcVideoFilename, 'txt')
	local picBasename = LrPathUtils.removeExtension(LrPathUtils.leafName(srcVideoFilename))
	local vidExt = LrPathUtils.extension(srcVideoFilename)
	local picPath = LrPathUtils.parent(srcVideoFilename)
	local picExt = 'jpg'
	local vidExt = 'mp4'
	local thmb_ORG_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename, picExt))
	local thmb_XL_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_XL', picExt))
	local thmb_L_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_L', picExt))
	local thmb_M_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_M', picExt))
	local thmb_B_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_B', picExt))
	local thmb_S_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_S', picExt))
--	local vid_MOB_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_MOB', vidExt))
	local vid_LOW_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_LOW', vidExt))
--	local vid_MED_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_MED', vidExt))
--	local vid_HIGH_Filename = LrPathUtils.child(picPath, LrPathUtils.addExtension(picBasename .. '_HIGH', vidExt))
	local cmdline
	local retcode

	-- get video infos: aspect ratio, resolution ,...

	-- generate first thumb from video
	cmdline = 	cmdlineQuote() ..
					'"' .. ffmpeg .. 
					'" -i "' .. srcVideoFilename .. 
					'" -y -vframes 1 -ss 00:00:01 -an -qscale 0 -f mjpeg -s 640x480 -aspect 640:480 ' .. 
					thmb_ORG_Filename .. ' 2> ' .. outfile ..
				cmdlineQuote()


	writeLogfile(4, cmdline .. "\n")
	if LrTasks.execute(cmdline) > 0 or not LrFileUtils.exists(thmb_ORG_Filename) then
		writeLogfile(3, "  error on: " .. cmdline .. "\n")
		LrFileUtils.delete(outfile)
		return false
	end
	LrFileUtils.delete(outfile)

	-- generate all other thumb from first thumb

	-- conversion acc. to http://www.medin.name/blog/2012/04/22/thumbnail-1000s-of-photos-on-a-synology-nas-in-hours-not-months/
--[[
	if not convertPic(thmb_ORG_Filename, '1280x1280>', 70, '0.5x0.5+1.25+0.0', thmb_XL_Filename) 
	or not convertPic(thmb_XL_Filename, '800x800>', 70, '0.5x0.5+1.25+0.0', thmb_L_Filename) 
	or not convertPic(thmb_L_Filename, '640x640>', 70, '0.5x0.5+1.25+0.0', thmb_B_Filename) 
	or not convertPic(thmb_L_Filename, '320x320>', 70, '0.5x0.5+1.25+0.0', thmb_M_Filename) 
	or not convertPic(thmb_M_Filename, '120x120>', 70, '0.5x0.5+1.25+0.0', thmb_S_Filename) 
]]	

	if ( not largeThumbs and not convertPicConcurrent(thmb_ORG_Filename, 
								'-strip -flatten -quality '.. tostring(thumbQuality) .. ' -auto-orient -colorspace RGB -unsharp 0.5x0.5+1.25+0.0 -colorspace sRGB', 
								'1280x1280>', thmb_XL_Filename,
								'800x800>',    thmb_L_Filename,
								'640x640>',    thmb_B_Filename,
								'320x320>',    thmb_M_Filename,
								'120x120>',    thmb_S_Filename) )
	or ( largeThumbs and not convertPicConcurrent(thmb_ORG_Filename, 
								'-strip -flatten -quality '.. tostring(thumbQuality) .. ' -auto-orient -colorspace RGB -unsharp 0.5x0.5+1.25+0.0 -colorspace sRGB', 
								'1280x1280>^', thmb_XL_Filename,
								'800x800>^',   thmb_L_Filename,
								'640x640>',    thmb_B_Filename,
								'320x320>^',   thmb_M_Filename,
								'120x120>',    thmb_S_Filename) )

	-- generate preview video
	or not convertVideo(srcVideoFilename, "LOW", vid_LOW_Filename) 

	-- upload thumbs, preview videos and original file
	or not PSUploadAPI.uploadPictureFile(thmb_B_Filename, srcDateTime, dstDir, dstFilename, 'THUM_B', 'image/jpeg', 'FIRST') 
	or not PSUploadAPI.uploadPictureFile(thmb_M_Filename, srcDateTime, dstDir, dstFilename, 'THUM_M', 'image/jpeg', 'MIDDLE') 
	or not PSUploadAPI.uploadPictureFile(thmb_S_Filename, srcDateTime, dstDir, dstFilename, 'THUM_S', 'image/jpeg', 'MIDDLE') 
	or (not isPS6 and not PSUploadAPI.uploadPictureFile(thmb_L_Filename, srcDateTime, dstDir, dstFilename, 'THUM_L', 'image/jpeg', 'MIDDLE')) 
	or not PSUploadAPI.uploadPictureFile(thmb_XL_Filename, srcDateTime, dstDir, dstFilename, 'THUM_XL', 'image/jpeg', 'MIDDLE') 
	or not PSUploadAPI.uploadPictureFile(vid_LOW_Filename, srcDateTime, dstDir, dstFilename, 'MP4_LOW', 'video/mpeg', 'MIDDLE') 
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
			local tmpFilename = LrPathUtils.child(LrPathUtils.parent(pathOrMessage), unblankFilename(filename))
			local srcFilename = srcPhoto:getRawMetadata("path") 
			local srcDateTime = getDateTimeOriginal(srcFilename, srcPhoto)
			local dstDir
			
			if pathOrMessage ~= tmpFilename then
				-- avoid problems caused by filenames with blanks in it
				writeLogfile(3, " unblanked: " .. tmpFilename .. "\n")
				LrFileUtils.move( pathOrMessage, tmpFilename )
			end

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
				if not uploadVideo(tmpFilename, srcDateTime, dstDir, filename, exportParams.isPS6, exportParams.largeThumbs, exportParams.thumbQuality) then
--				if not uploadVideo(srcFilename, srcDateTime, dstDir, filename, exportParams.isPS6, exportParams.largeThumbs, exportParams.thumbQuality) then
					writeLogfile(1, LrDate.formatMediumTime(LrDate.currentTime()) .. 
									': Upload of "' .. filename .. '" to "' .. dstDir .. '" failed!!!\n')
					table.insert( failures, dstDir .. "/" .. filename )
				else
					writeLogfile(2, LrDate.formatMediumTime(LrDate.currentTime()) .. 
									': Upload of "' .. filename .. '" to "' .. dstDir .. '" done\n')
				end
			else
				if not uploadPicture(tmpFilename, srcDateTime, dstDir, filename, exportParams.isPS6, exportParams.largeThumbs, exportParams.thumbQuality) then
					writeLogfile(1, LrDate.formatMediumTime(LrDate.currentTime()) .. 
									': Upload of "' .. filename .. '" to "' .. exportParams.serverUrl .. "-->" ..  dstDir .. '" failed!!!\n')
					table.insert( failures, dstDir .. "/" .. filename )
				else
					writeLogfile(2, LrDate.formatMediumTime(LrDate.currentTime()) .. 
									': Upload of "' .. filename .. '" to "' .. exportParams.serverUrl .. "-->" .. dstDir .. '" done\n')
				end
			end

			LrFileUtils.delete( tmpFilename )
					
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
