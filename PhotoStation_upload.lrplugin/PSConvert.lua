--[[----------------------------------------------------------------------------

PSConvert.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2019, Martin Messmer

conversion primitives:
	- initialize

	- convertPicConcurrent

	- ffmpegGetAdditionalInfo
	- ffmpegGetRotateParams
	- ffmpegGetThumbFromVideo
	- getConvertKey
	- videoIsNativePSFormat
	- convertVideo

	- writeTitleFile
	
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
]]
--------------------------------------------------------------------------------

-- Lightroom API
-- local LrFileUtils = import 'LrFileUtils'
local LrDate 		= import 'LrDate'
local LrFileUtils 	= import 'LrFileUtils'
local LrPathUtils 	= import 'LrPathUtils'
local LrPrefs	 	= import 'LrPrefs'
local LrTasks 		= import 'LrTasks'

require "PSUtilities"

--============================================================================--

PSConvert = {}

PSConvert.downloadUrl 			= 'https://www.synology.com/support/download' 
PSConvert.defaultInstallPath 	= iif(WIN_ENV, 
    								'C:/Program Files (x86)/Synology/Photo Station Uploader',
    								'/Applications/Synology Photo Station Uploader.app/Contents/MacOS')
PSConvert.defaultVideoPresetsFn = "PSVideoConversions.json"
PSConvert.convOptions			= nil

------------------------ initialize ---------------------------------------------------------------------------------
-- initialize: initialize convert program paths
function PSConvert.initialize()
	local prefs = LrPrefs.prefsForPlugin()
	local PSUploaderPath = prefs.PSUploaderPath
	local h = {} -- the handle

	writeLogfile(4, "PSConvert.initialize: PSUploaderPath= " .. PSUploaderPath .. "\n")
	if not PSDialogs.validatePSUploadProgPath(nil, PSUploaderPath) then
		writeLogfile(1, "PSConvert.initialize: Bad PSUploaderPath= " .. PSUploaderPath .. "!\n")
		return nil
	end

	local convertprog = 'convert'
	local dcrawprog = 'dcraw'
	local ffmpegprog = 'ffmpeg'
	local qtfstartprog = 'qt-faststart'

	if getProgExt() then
 		local progExt = getProgExt()
		convertprog = LrPathUtils.addExtension(convertprog, progExt)
		dcrawprog = LrPathUtils.addExtension(dcrawprog, progExt)
		ffmpegprog = LrPathUtils.addExtension(ffmpegprog, progExt)
		qtfstartprog = LrPathUtils.addExtension(qtfstartprog, progExt)
	end
	
	h.conv = LrPathUtils.child(LrPathUtils.child(PSUploaderPath, 'ImageMagick'), convertprog)
	h.dcraw = iif(WIN_ENV, 
					LrPathUtils.child(LrPathUtils.child(PSUploaderPath, 'ImageMagick'), dcrawprog),
					LrPathUtils.child(LrPathUtils.child(PSUploaderPath, 'dcraw'), dcrawprog))
	h.ffmpeg = LrPathUtils.child(LrPathUtils.child(PSUploaderPath, 'ffmpeg'), ffmpegprog)
	h.qtfstart = LrPathUtils.child(LrPathUtils.child(PSUploaderPath, 'ffmpeg'), qtfstartprog)

	PSConvert.convOptions = PSConvert.getVideoConvPresets()
	
	if not PSConvert.convOptions then
		writeLogfile(1, string.format("PSConvert.initialize: video preset file '%s' is not a valid JSON file!\n",  videoConvPath))
		return nil
	end
	writeTableLogfile(4, "VideoConvPresets", PSConvert.convOptions)

	writeLogfile(4, "PSConvert.initialize:\n\t\t\tconv: " .. h.conv .. "\n\t\t\tdcraw: " .. h.dcraw .. 
										 "\n\t\t\tffmpeg: " .. h.ffmpeg .. "\n\t\t\tqt-faststart: " .. h.qtfstart .. "\n")
	return h
end

------------------------ initialize ---------------------------------------------------------------------------------
-- initialize: initialize convert program paths
function PSConvert.getVideoConvPresets()
	local prefs = LrPrefs.prefsForPlugin()
	local videoConvPath = LrPathUtils.child(_PLUGIN.path, prefs.videoConversionsFn)

	return JSON:decode(LrFileUtils.readFile(videoConvPath))
end
---------------------- picture conversion functions ----------------------------------------------------------
-- getRawParams(picExt, srcPhoto, exportFormat)
-- 	picExt			- filename extension of the photo
--	srcPhoto		- Lr data structure including Metadate such as camera make and model
--  exportFormat	- Lr export file format setting: JPEG, PSD, TIFF, DNG, PSD or ORIGINAL	
--
--	returns optimal dcraw conversion params depending on file format or nil if is not a supported raw format 
local function getRawConvParams(picExt, srcPhoto, exportFormat)
	if 	   picExt == 'jpg' then
		return nil
	end
	
	-- get camera vendor
	local cMake = string.upper(ifnil(srcPhoto:getFormattedMetadata('cameraMake'), ''))
	
	if 	   picExt == 'arw'								-- Sony
		or picExt == 'cr2'								-- Canon
		or (picExt == 'dng' and exportFormat == 'DNG')	-- digital negative: Lr developed photo
		or (picExt == 'dng'	and cMake == 'PENTAX')		-- digital negative: Pentax
		or picExt == 'dcr'								-- Kodak
		or picExt == 'mef'								-- Mamiya
--		or picExt == 'mos'								-- Aptus --> not supported by Lr
		or picExt == 'nef'								-- Nikon
		or picExt == 'orf'								-- Olympus
		or picExt == 'pef'								-- Pentax
		or picExt == 'raf'								-- Fuji
		or (picExt == 'raw' and cMake == 'PANASONIC')	-- Panasonic 
		or picExt == 'rw2'								-- Panasonic
--		or picExt == 'srw'								-- Samsung --> not supported by Photo Station
		or picExt == 'x3f'								-- Polaroid, Sigma
	then 
		writeLogfile(3, string.format("getRawConvParams: %s %s %s --> %s\n", picExt, cMake, exportFormat, '-e -w'));
		return '-e -w '			-- use embedded preview w/ white balance adjustment
	elseif picExt == '3fr'								-- Hasselblad
		or picExt == 'dng'								-- digital negative: Leica, Ricoh, Nokia
		or picExt == 'erf'								-- Epson
		or picExt == 'mef'								-- Mamiya
		or picExt == 'mrw'								-- Minolta
		or picExt == 'raw'								-- Leica
		or picExt == 'sr2'								-- Sony
	then 
		writeLogfile(3, string.format("getRawConvParams: %s %s %s --> %s\n", picExt, cMake, exportFormat, '-w'));
		return '-w '			-- use raw image w/ white balance adjustment
	else 
		return nil
	end
end

-- convertPicConcurrent(h, srcFilename, srcPhoto, exportFormat, convParams, xlSize, xlFile, lSize, lFile, bSize, bFile, mSize, mFile, sSize, sFile)
-- converts a picture file using the ImageMagick convert tool into 5 thumbs in one run
function PSConvert.convertPicConcurrent(h, srcFilename, srcPhoto, exportFormat, convParams, xlSize, xlFile, lSize, lFile, bSize, bFile, mSize, mFile, sSize, sFile)
	-- if image is in DNG format extract the embedded jpg
	local srcJpgFilename
	local orgExt = string.lower(LrPathUtils.extension(srcFilename))

	-- if RAW image format, get the correct dcraw conversion params
	local rawConvParams = getRawConvParams(orgExt, srcPhoto, exportFormat)
	if rawConvParams then
		srcJpgFilename = (LrPathUtils.replaceExtension(srcFilename, 'jpg'))

		local cmdline = cmdlineQuote() .. '"' .. 
							h.dcraw .. '" ' .. rawConvParams .. '-c "' .. srcFilename .. '" > "' .. srcJpgFilename .. '"' ..
							' 2>> "' .. iif(getLogLevel() >= 4, getLogFilename(), getNullFilename()) .. '"' 	 
						cmdlineQuote()
		writeLogfile(3, cmdline .. "\n")
		
		if LrTasks.execute(cmdline) > 0 then
			writeLogfile(3,cmdline .. "... failed!\n")
			writeLogfile(1, "convertPicConcurrent: " .. srcFilename  .. " failed!\n")
			return false
		end
	else
		srcJpgFilename = srcFilename
	end
	
	local cmdline = 
		cmdlineQuote() .. '"' .. 
			h.conv .. '" "' .. 
			srcJpgFilename .. '" ' ..
			shellEscape(
						 '( -clone 0 -define jpeg:size=' .. xlSize .. ' -thumbnail '  .. xlSize .. ' ' .. convParams .. ' -write "' .. xlFile .. '" ) -delete 0 ' ..
		iif(lFile ~= '', '( +clone   -define jpeg:size=' ..  lSize .. ' -thumbnail '  ..  lSize .. ' ' .. convParams .. ' -write "' ..  lFile .. '" +delete ) ', '') ..
						 '( +clone   -define jpeg:size=' ..  bSize .. ' -thumbnail '  ..  bSize .. ' ' .. convParams .. ' -write "' ..  bFile .. '" +delete ) ' ..
						 '( +clone   -define jpeg:size=' ..  mSize .. ' -thumbnail '  ..  mSize .. ' ' .. convParams .. ' -write "' ..  mFile .. '" +delete ) ' ..
								    '-define jpeg:size=' ..  sSize .. ' -thumbnail '  ..  sSize .. ' ' .. convParams .. ' "' 	   ..  sFile .. '"'
			) ..
			' 2>> "' .. iif(getLogLevel() >= 4, getLogFilename(), getNullFilename()) .. '"' 
		cmdlineQuote()

	writeLogfile(3, cmdline .. "\n")
	if LrTasks.execute(cmdline) > 0 then
		writeLogfile(3,cmdline .. "... failed!\n")
		writeLogfile(1, "convertPicConcurrent: " .. srcFilename  .. " failed!\n")
		return false
	end

	return true
end

-- ffmpegGetAdditionalInfo(h, srcVideoFilename) ---------------------------------------------------------
-- get the capture date, duration, video format, resolution and aspect ratio of a video via ffmpeg. Lr won't give you this information
--	returns: 
--	  nil of vinfo:
--		dateTimeOrig 	as unix timestamp
--		duration 		in seconds
--		vformat			as string: 'h264', 'mjpeg', ...
--		dimension		as pixel dimension 'NxM'
--		sar				as aspect ratio 'N:M' 
--		dar				as aspect ratio 'N:M'
--		rotation		as string '0', '90', '180', '270'
--	  ffinfo:
--	  	version			version of ffmpeg tool
function PSConvert.ffmpegGetAdditionalInfo(h, srcVideoFilename)
	-- returns DateTimeOriginal / creation_time retrieved via ffmpeg  as Cocoa timestamp
	local picBasename = LrPathUtils.removeExtension(LrPathUtils.leafName(srcVideoFilename))
	local outfile =  LrPathUtils.child(tmpdir, LrPathUtils.addExtension(picBasename .. '_ffmpeg', 'txt'))
	-- LrTask.execute() will call cmd.exe /c cmdline, so we need additional outer quotes
	local cmdline = cmdlineQuote() .. '"' .. h.ffmpeg .. '" -i "' .. srcVideoFilename .. '" 2> "' .. outfile .. '"' .. cmdlineQuote()
	local v,w,x,z -- iteration variables for string.gmatch()
	local vinfo = {}
	local ffinfo = {}
	
	writeLogfile(4, cmdline .. "\n")
	LrTasks.execute(cmdline)
	-- ignore errorlevel of ffmpeg here (is 1) , just check the outfile
	
	if not LrFileUtils.exists(outfile) then
		writeLogfile(3, "  error on: " .. cmdline .. "\n")
		return nil
	end

	local ffmpegReport = LrFileUtils.readFile(outfile)
	writeLogfile(4, "ffmpeg report:\n" .. 
					"===========================================================================\n".. 
					ffmpegReport ..
					"===========================================================================\n")
	
	writeLogfile(3, string.format("ffmpegGetAdditionalInfo(%s):\n", srcVideoFilename))
	
	-------------- ffmpeg version search for avp:
	-- ffmpeg version 1.2.1 Copyright (c) 2000-2013 the FFmpeg developers
	-- ffmpeg version N-82794-g3ab1311 Copyright (c) 2000-2016 the FFmpeg developers
	-- ffmpeg version 3.2.2 Copyright (c) 2000-2016 the FFmpeg developers
	ffinfo.version = string.match(ffmpegReport, "ffmpeg version ([^%s]+)")
	if not ffinfo.version then
		writeLogfile(3, "  error: cannot find ffmpeg version\n")
	end
	writeLogfile(3, "  ffmpeg version: " .. ffinfo.version .. "\n")
	
	-------------- DateTimeOriginal search for avp: 'date            : 2014-07-14T21:35:04-0700'
	local dateCaptureString, dateCapture
	for v in string.gmatch(ffmpegReport, "date%s+:%s+([%d%-]+[%sT][%d%:]+)") do
		dateCaptureString = v
		writeLogfile(4, "dateCaptureString: " .. dateCaptureString .. "\n")
		-- translate from  yyyy-mm-dd HH:MM:ss to timestamp
		dateCapture = LrDate.timeFromComponents(string.sub(dateCaptureString,1,4),
												string.sub(dateCaptureString,6,7),
												string.sub(dateCaptureString,9,10),
												string.sub(dateCaptureString,12,13),
												string.sub(dateCaptureString,15,16),
												string.sub(dateCaptureString,18,19),
												'local') -- ignore timezone 
		writeLogfile(3, "	ffmpeg-dateCapture: " .. LrDate.timeToUserFormat(dateCapture, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
		dateCapture = LrDate.timeToPosixDate(dateCapture)
		break
     end
	
	-------------- DateTimeOriginal: search for avp:  -------------------------
	--	'creation_time : 2014-09-10 16:09:51'
	--	'creation_time : 2014-09-10T16:09:51.000000Z'
	local creationTimeString, creationTime
	for v in string.gmatch(ffmpegReport, "creation_time%s+:%s+([%d%-]+[%sT][%d%:]+)") do
		creationTimeString = v
		writeLogfile(4, "creationTimeString: " .. creationTimeString .. "\n")
		-- translate from  yyyy-mm-dd HH:MM:ss to timestamp
		creationTime = LrDate.timeFromComponents(string.sub(creationTimeString,1,4),
												string.sub(creationTimeString,6,7),
												string.sub(creationTimeString,9,10),
												string.sub(creationTimeString,12,13),
												string.sub(creationTimeString,15,16),
												string.sub(creationTimeString,18,19),
												'local')
		writeLogfile(3, "	ffmpeg-creationTime: " .. LrDate.timeToUserFormat(creationTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
		creationTime = LrDate.timeToPosixDate(creationTime)
		break
     end

	-------------- duration: search for avp: 'Duration: <HH:MM:ss.msec>,' -------------------------
	local durationString
	for v in string.gmatch(ffmpegReport, "Duration:%s+([%d%p]+),") do
		durationString = v
		writeLogfile(4, "durationString: " .. durationString .. "\n")
		-- translate from  HH:MM:ss.msec to seconds
		vinfo.duration = 	tonumber(string.sub(durationString,1,2)) * 3600 +
					tonumber(string.sub(durationString,4,5)) * 60 +
					tonumber(string.sub(durationString,7,11))
		writeLogfile(3, string.format("\tduration: %.2f\n", vinfo.duration))
     end
	 
	-------------- resolution: search for avp like:  -------------------------
	-- Video: mjpeg (MJPG / 0x47504A4D), yuvj422p, 640x480, 30 tbr, 30 tbn, 30 tbc
	-- Video: h264 (Main) (avc1 / 0x31637661), yuv420p, 1440x1080 [SAR 4:3 DAR 16:9], 12091 kb/s, 29.97 fps, 29.97 tbr, 30k tbn, 59.94 tbc
	-- Video: h264 (High) (avc1 / 0x31637661), yuv420p(tv, bt709), 1920x1080 [SAR 1:1 DAR 16:9], 27066 kb/s, 50 fps, 50 tbr, 180k tbn, 100 tbc (default)
	-- Video: mjpeg (MJPG / 0x47504A4D), yuvj422p(pc, bt470bg/unknown/unknown), 320x240, 1898 kb/s, 15 fps, 15 tbr, 15 tbn, 15 tbc
--	for z, v, w, x in string.gmatch(ffmpegReport, "Video:%s+(%w+)[%s%w%(%)/]+,[%s%w%(%),]+,%s+([%d]+x[%d]+)%s*%[*%w*%s*([%d:]*)%s*%w*%s*([%w:]*)%]*,") do
	for z, v, w, x in string.gmatch(ffmpegReport, "Video:%s+(%w+).+,.+,%s+([%d]+x[%d]+)%s*%[*%w*%s*([%d:]*)%s*%w*%s*([%w:]*)%]*,") do
		vinfo.vformat = z
		vinfo.dimension = v
		vinfo.sar = w
		vinfo.dar = x
		writeLogfile(3, string.format("\tdimension: %s vformat: %s [SAR: %s DAR: %s]\n", vinfo.dimension, vinfo.vformat, ifnil(vinfo.sar, '<Nil>'), ifnil(vinfo.dar, '<Nil>')))
    end
	 
	-- Video: h264 (High) (avc1 / 0x31637661), yuv420p, 1920x1080, 17474 kb/s, SAR 65536:65536 DAR 16:9, 28.66 fps, 29.67 tbr, 90k tbn, 180k tbc
	-- get sar (sample aspect ratio) and dar (display aspect ratio)
	if not vinfo.sar or (vinfo.sar == '') then
		for w, x in string.gmatch(ffmpegReport, "Video:[%s%w%(%)/]+,[%s%w]+,[%s%w]+,[%s%w/]+,%s+SAR%s+([%d:]+)%s+DAR%s+([%d:]+)") do
			vinfo.sar = w
			vinfo.dar = x
			writeLogfile(3, string.format("\tSAR: %s, DAR: %s\n", ifnil(vinfo.sar, '<Nil>'), ifnil(vinfo.dar, '<Nil>')))
		end
	end

	-------------- rotation: search for avp like:  -------------------------
	-- rotate          : 90
	vinfo.rotation = '0'
	for v in string.gmatch(ffmpegReport, "rotate%s+:%s+([%d]+)") do
		vinfo.rotation = v
		writeLogfile(3, string.format("\trotation: %s\n", vinfo.rotation))
	end
	
	-------------- GPS info: search for avp like:  -------------------------
	--     location        : +52.1234+013.1234/
	--     location 	   : +33.9528-118.3960+026.000/
	vinfo.latitude, vinfo.longitude, vinfo.gpsHeight = string.match(ffmpegReport, "location%s+:%s+([%+%-]%d+%.%d+)([%+%-]%d+%.%d+)([%+%-%d%.]*)/")

	if vinfo.latitude and vinfo.longitude then
			writeLogfile(3, string.format("\tgps: %s / %s (height:%s)\n", vinfo.latitude, vinfo.longitude, vinfo.gpsHeight))
	end
	
	LrFileUtils.delete(outfile)

	if dateCapture and creationTime and dateCapture < creationTime then
		vinfo.srcDateTime = dateCapture
	else
		vinfo.srcDateTime = creationTime
	end
	
	return vinfo, ffinfo
end

-- ffmpegGetRotateParams(hardRotate, rotation, dimension, aspectRatio) ---------------------------------------------------------
-- returns resulting ffmpeg rotation options, dimension and aspectRatio
function PSConvert.ffmpegGetRotateParams(h, hardRotate, rotation, dimension, aspectRatio)
	local rotateOpt 		= ''
	local newDimension		= dimension
	local newAspectRatio	= aspectRatio
	
	if hardRotate then
		-- hard-rotation: rotate video stream, calculate rotated dimension, remove rotation flag from metadata
		if rotation == "90" then
			rotateOpt = '-vf "transpose=1" -metadata:s:v:0 rotate=0 '
			newDimension = string.format("%sx%s", 
										string.sub(dimension, string.find(dimension,'x') + 1, -1),
										string.sub(dimension, 1, string.find(dimension,'x') - 1))
			newAspectRatio = string.gsub(newDimension, 'x', ':')
			writeLogfile(4, "ffmpegGetRotateParams: hard rotate video by 90\n")
		elseif rotation == "270" then
			rotateOpt = '-vf "transpose=2" -metadata:s:v:0 rotate=0 '
			newDimension = string.format("%sx%s", 
										string.sub(dimension, string.find(dimension,'x') + 1, -1),
										string.sub(dimension, 1, string.find(dimension,'x') - 1))
			newAspectRatio = string.gsub(newDimension, 'x', ':')
			writeLogfile(4, "ffmpegGetRotateParams: hard rotate video by 270\n")
		elseif rotation == "180" then
			rotateOpt = '-vf "hflip,vflip" -metadata:s:v:0 rotate=0 '
			writeLogfile(4, "ffmpegGetRotateParams: hard rotate video by 180\n")
		end
	else
		-- soft-rotation: add rotation flag to metadata
		if rotation == "90" then
			rotateOpt = '-metadata:s:v:0 rotate=90 '
			writeLogfile(4, "ffmpegGetRotateParams: soft rotate video by 90\n")
		elseif rotation == "180" then
			rotateOpt = '-metadata:s:v:0 rotate=180 '
			writeLogfile(4, "ffmpegGetRotateParams: soft rotate video by 180\n")
		elseif rotation == "270" then
			rotateOpt = '-metadata:s:v:0 rotate=270 '
			writeLogfile(4, "ffmpegGetRotateParams: soft rotate video by 270\n")
		end 
	end
	return rotateOpt, newDimension, newAspectRatio
end

-- ffmpegGetThumbFromVideo(h, srcVideoFilename, ffinfo, thumbFilename, dimension, rotation, duration) ---------------------------------------------------------
function PSConvert.ffmpegGetThumbFromVideo (h, srcVideoFilename, ffinfo, thumbFilename, dimension, rotation, duration)
	local outfile =  LrPathUtils.replaceExtension(srcVideoFilename, 'txt')
	local rotateOpt, newDim, aspectRatio
	local snapshotTime = iif(duration < 4, '00:00:00', '00:00:03') 
	
	rotateOpt, newDim, aspectRatio = PSConvert.ffmpegGetRotateParams(h, true, rotation, dimension, string.gsub(dimension, 'x', ':'))
	
	writeLogfile(3, string.format("ffmpegGetThumbFromVideo: %s dim %s rotation %s duration %d --> newDim: %s aspectR: %s snapshot at %s\n", 
								srcVideoFilename, dimension, rotation, duration, newDim, aspectRatio, snapshotTime))
	
	-- generate first thumb from video
	local cmdline = cmdlineQuote() ..
						'"' .. h.ffmpeg .. '" ' .. 
						iif(ffinfo.version == '1.2.1', '', '-noautorotate ') ..  
						'-i "' .. srcVideoFilename .. '" ' ..
						'-y -vframes 1 -ss ' .. snapshotTime .. ' -an -qscale 0 -f mjpeg '.. rotateOpt ..
						'-s ' .. newDim .. ' -aspect ' .. aspectRatio .. ' ' ..
						'"' .. thumbFilename .. '" 2> "' .. outfile .. '"' ..
					cmdlineQuote()

	writeLogfile(4, cmdline .. "\n")
	if LrTasks.execute(cmdline) > 0 or not LrFileUtils.exists(thumbFilename) then
		writeLogfile(3, "  error on: " .. cmdline .. "\n")
		writeLogfile(3, "ffmpeg report:\n" .. 
						"===========================================================================\n".. 
						LrFileUtils.readFile(outfile) ..
						"===========================================================================\n")
		LrFileUtils.delete(outfile)
		return false
	end
	
	LrFileUtils.delete(outfile)
	
	return true
end


-- videoConversion defines the conversion parameters based on the requested target dimension
-- must be sorted from lowest to highest resolution
local videoConversion = {
	{	
		id = 'MOBILE',
		upToHeight 	= 240,
		
--		pass1Params =	"-ar 44100 -b:a 64k -ac 2 -pass 1 -vcodec libx264 -b:v 1024k -bt 1024k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 0 -vprofile baseline -vsync 2 -level 13 -coder 0 -refs 1 -bf 0 -subq 1 -trellis 0 -me_method epzs -partitions 0 -f mp4",
		pass1Params =	"-ar 44100 -b:a 64k -ac 2 -c:v libx264 -preset medium -crf 20 -f mp4",
		
--		pass2Params =	"-ar 44100 -b:a 64k -ac 2 -pass 2 -vcodec libx264 -b:v 1024k -bt 1024k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 0 -vprofile baseline -vsync 2 -level 13 -coder 0 -refs 1 -bf 0 -subq 5 -trellis 0 -me_method hex -partitions +parti4x4+parti8x8+partp4x4+partp8x8+partb8x8 -f mp4",
--		pass2Params =	"-ar 44100 -b:a 64k -ac 2 -pass 2 -vcodec libx264 -crf 23 -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 0 -vprofile baseline -vsync 2 -level 13 -coder 0 -refs 1 -bf 0 -subq 5 -trellis 0 -me_method hex -partitions +parti4x4+parti8x8+partp4x4+partp8x8+partb8x8 -f mp4",
	},

	{	
		id = 'LOW',
		upToHeight 	= 360,
		
--		pass1Params = 	"-ar 44100 -b:a 96k -ac 2 -pass 1 -vcodec libx264 -b:v 256k -bt 256k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 0 -vprofile baseline -vsync 2 -level 13 -coder 0 -refs 1 -bf 0 -subq 1 -trellis 0 -me_method epzs -partitions 0 -f mp4",
		pass1Params = 	"-ar 44100 -b:a 96k -ac 2 -c:v libx264 -preset medium -crf 20 -f mp4",

--		pass2Params = 	"-ar 44100 -b:a 96k -ac 2 -pass 2 -vcodec libx264 -b:v 256k -bt 256k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 0 -vprofile baseline -vsync 2 -level 13 -coder 0 -refs 1 -bf 0 -subq 5 -trellis 0 -me_method hex -partitions +parti4x4+parti8x8+partp4x4+partp8x8+partb8x8 -f mp4",
	},

	{	
		id = 'MEDIUM',
		upToHeight 	= 720,
		
--		pass1Params = 	"-ar 44100 -b:a 96k -ac 2 -pass 1 -vcodec libx264 -b:v 1000k -bt 1000k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 0 -vsync 2 -level 31 -coder 0 -refs 4 -bf 2 -b_qfactor 1.30 -b-pyramid none -b_strategy 1 -b-bias 0 -direct-pred 1 -weightb 1 -subq 1 -trellis 0 -me_method epzs -partitions 0 -f mp4",
		pass1Params = 	"-ar 44100 -b:a 96k -ac 2 -c:v libx264 -preset medium -crf 20 -f mp4",

--		pass2Params = 	"-ar 44100 -b:a 96k -ac 2 -pass 2 -vcodec libx264 -b:v 1000k -bt 1000k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 0 -vsync 2 -level 31 -coder 0 -refs 4 -bf 2 -b_qfactor 1.30 -b-pyramid none -b_strategy 1 -b-bias 0 -direct-pred 1 -weightb 1 -subq 5 -trellis 0 -me_method hex -partitions +parti4x4+parti8x8+partp4x4+partp8x8+partb8x8 -f mp4",
	},

	{	
		id = 'HIGH',
		upToHeight	= 1080,
		
--		pass1Params = 	"-ar 44100 -b:a 96k -ac 2 -pass 1 -vcodec libx264 -b:v 2000k -bt 2000k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 1 -vsync 2 -level 41 -coder 1 -refs 3 -bf 2 -b_qfactor 1.30 -b-pyramid none -b_strategy 1 -b-bias 0 -direct-pred 1 -weightb 1 -subq 1 -trellis 0 -me_method epzs -partitions 0 -f mp4",
		pass1Params = 	"-ar 44100 -b:a 96k -ac 2 -c:v libx264 -preset medium -crf 20 -f mp4",

--		pass2Params = 	"-ar 44100 -b:a 96k -ac 2 -pass 2 -vcodec libx264 -b:v 2000k -bt 2000k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 1 -vsync 2 -level 41 -coder 1 -refs 3 -bf 2 -b_qfactor 1.30 -b-pyramid none -b_strategy 1 -b-bias 0 -direct-pred 1 -weightb 1 -subq 5 -trellis 1 -me_method hex -partitions +parti4x4+parti8x8+partp4x4+partp8x8+partb8x8 -f mp4",
	},	

	{	
		id = 'ULTRA',
		upToHeight	= 2160,
		
		pass1Params = 	"-ar 44100 -b:a 96k -ac 2 -c:v libx264 -preset medium -f -crf 20 mp4",

--		pass2Params = 	"-ar 44100 -b:a 96k -ac 2 -pass 2 -vcodec libx264 -b:v 2000k -bt 2000k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 1 -vsync 2 -level 41 -coder 1 -refs 3 -bf 2 -b_qfactor 1.30 -b-pyramid none -b_strategy 1 -b-bias 0 -direct-pred 1 -weightb 1 -subq 5 -trellis 1 -me_method hex -partitions +parti4x4+parti8x8+partp4x4+partp8x8+partb8x8 -f mp4",
	},
}


---------------- getConvertKey --------------------------------------------------------------------
function PSConvert.getConvertKey(h, height)
	
	for i = 1, #videoConversion do
		if height <= videoConversion[i].upToHeight then 
			return i, videoConversion[i].id
		end
	end

	return #videoConversion, videoConversion[#videoConversion].id

end

---------------- videoIsNativePSFormat --------------------------------------------------------------------
-- return true if video format is natively supported by PS, i.e. it needs no conversion
function PSConvert.videoIsNativePSFormat(videoExt)
	
	if 	   string.lower(videoExt) == 'mp4'
		or string.lower(videoExt) == 'm4v'
	then
		return true
	end

	return false
end

-- convertVideo(h, srcVideoFilename, ffinfo, vinfo, dstHeight, hardRotate, rotation, videoQuality, dstVideoFilename) --------------------------
--[[ 
	converts a video to an mp4 with a given resolution using the ffmpeg and qt-faststart tool
	h					conversionHandle
	srcVideoFilename	the src video file
	ffinfo				ffmpeg tool version info
	vinfo				orig video metadata info
	dstHeight			target height in pixel
	hardrotate			do hard rotation
	rotation			rotation angle
	videoQuality	audio / video conversion options
	dstVideoFilename	the target video file
]]
function PSConvert.convertVideo(h, srcVideoFilename, ffinfo, vinfo, dstHeight, hardRotate, rotation, videoQuality, dstVideoFilename)
	local tmpVideoFilename = LrPathUtils.replaceExtension(LrPathUtils.removeExtension(dstVideoFilename) .. '_TMP', LrPathUtils.extension(dstVideoFilename))
	local outfile =  LrPathUtils.replaceExtension(tmpVideoFilename, 'txt')
	local passLogfile =  LrPathUtils.replaceExtension(tmpVideoFilename, 'passlog')
	local arw = tonumber(string.match(vinfo.dar, '(%d+):%d+'))
	local arh = tonumber(string.match(vinfo.dar, '%d+:(%d+)'))
	local dstWidth = math.floor(((dstHeight * arw / arh) + 0.5) / 2) * 2  -- make sure width is an even integer
	local dstDim = string.format("%dx%d", dstWidth, dstHeight)
	local dstAspect = string.gsub(dstDim, 'x', ':')

	writeLogfile(3, string.format("convertVideo: %s aspectR %s, dstHeight: %d hardRotate %s rotation %s\n", 
								srcVideoFilename, vinfo.dar, dstHeight, tostring(hardRotate), rotation))
	
	-- disable autorotate option of newer ffmpeg versions
	local noAutoRotateOpt = iif(ffinfo.version == '1.2.1', '', '-noautorotate ')
	
	-- get rotation params based on rotate flag 
	local rotateOpt
	rotateOpt, dstDim, dstAspect = PSConvert.ffmpegGetRotateParams(h, hardRotate, rotation, dstDim, dstAspect)

	-- add creation_time metadata to destination video
	local createTimeOpt = '-metadata creation_time=' .. LrDate.timeToUserFormat(LrDate.timeFromPosixDate(vinfo.srcDateTime), '"%Y-%m-%d %H:%M:%S" ', false)
		
	-- add location metadata to destination video: doesn't work w/ ffmpeg 3.3.2, see ffmpeg #4209
	local locationInfoOpt = ''
	if vinfo.latitude then
		 locationInfoOpt = '-metadata location="' .. vinfo.latitude .. vinfo.longitude .. ifnil(vinfo.gpsHeight, '') .. '/" '
	end
		
	-- transcoding pass 1 
--	LrFileUtils.copy(srcVideoFilename, srcVideoFilename ..".bak")

	local cmdline =  cmdlineQuote() ..
				'"' .. h.ffmpeg .. '" ' .. 
				noAutoRotateOpt ..
				'-i "' 	.. srcVideoFilename .. '" ' .. 
				'-y ' 	..  -- override output file
				createTimeOpt ..  
				locationInfoOpt ..
				rotateOpt ..
				'-pix_fmt yuv420p ' ..
				PSConvert.convOptions[videoQuality].audio_options .. ' ' ..
				iif(PSConvert.convOptions[videoQuality].video_options_pass_2, '-pass 1 ', '') ..
				PSConvert.convOptions[videoQuality].video_options .. ' ' ..
				'-s ' .. dstDim .. ' -aspect ' .. dstAspect .. ' ' ..
				'-passlogfile "' .. passLogfile .. '" ' .. 
				'"' .. tmpVideoFilename .. '" 2> "' .. outfile .. '"' ..
				cmdlineQuote()
				
	writeLogfile(3, cmdline .. "\n")
	if LrTasks.execute(cmdline) > 0 or not LrFileUtils.exists(tmpVideoFilename) then
		writeLogfile(3, "  error on: " .. cmdline .. "\n")
		writeLogfile(3, "ffmpeg report:\n" .. 
						"===========================================================================\n".. 
						LrFileUtils.readFile(outfile) ..
						"===========================================================================\n")
		LrFileUtils.delete(passLogfile)
		LrFileUtils.delete(outfile)
		LrFileUtils.delete(tmpVideoFilename)
		return false
	end

--	writeLogfile(4, "ffmpeg report:\n" .. 
--					"===========================================================================\n".. 
--					LrFileUtils.readFile(outfile) ..
--					"===========================================================================\n")

	-- transcoding pass 2 
	if videoConversion.video_options_pass_2 then
    	cmdline =   cmdlineQuote() ..
    				'"' .. h.ffmpeg .. '" ' .. 
    				noAutoRotateOpt ..
    				'-i "' ..	srcVideoFilename .. '" ' .. 
					'-y ' 	..  -- override output file
    				createTimeOpt ..  
    				locationInfoOpt ..
    				rotateOpt ..
    				'-pix_fmt yuv420p ' ..
					PSConvert.convOptions[videoQuality].audio_options .. ' ' ..
					'-pass 2 ' ..
					PSConvert.convOptions[videoQuality].video_options_pass_2 .. ' ' ..
    				'-s ' .. dstDim .. ' -aspect ' .. dstAspect .. ' ' ..
    				'-passlogfile "' .. passLogfile .. '" ' .. 
    				'"' .. tmpVideoFilename .. '" 2> "' .. outfile ..'"' ..
    				cmdlineQuote()
    
    	writeLogfile(3, cmdline .. "\n")
    	if LrTasks.execute(cmdline) > 0 or not LrFileUtils.exists(tmpVideoFilename) then
    		writeLogfile(3, "  error on: " .. cmdline .. "\n")
    		writeLogfile(3, "ffmpeg report:\n" .. 
    						"===========================================================================\n".. 
    						LrFileUtils.readFile(outfile) ..
    						"===========================================================================\n")
    		LrFileUtils.delete(passLogfile)
    		LrFileUtils.delete(outfile)
    		LrFileUtils.delete(tmpVideoFilename)
    		return false
    	end
	end
	
	cmdline = 	cmdlineQuote() ..
					'"' .. h.qtfstart .. '" "' ..  tmpVideoFilename .. '" "' .. dstVideoFilename .. '" 2> "' .. outfile ..'"' ..
				cmdlineQuote()

	writeLogfile(4, cmdline .. "\n")
	if LrTasks.execute(cmdline) > 0 then
		writeLogfile(3, "  error on: " .. cmdline .. "\n")
    	writeLogfile(3, "qtfstart report:\n" .. 
    					"===========================================================================\n".. 
    					LrFileUtils.readFile(outfile) ..
    					"===========================================================================\n")
		LrFileUtils.delete(passLogfile)
		LrFileUtils.delete(outfile)
		LrFileUtils.delete(tmpVideoFilename)
		return false
	end

	LrFileUtils.delete(passLogfile)
	LrFileUtils.delete(outfile)
	LrFileUtils.delete(tmpVideoFilename)
	return true
end

-----------------------------------------------------------
-- PSConvert.writeTitleFile(titleFilename, title)
-- writes a title into a file
function PSConvert.writeTitleFile(titleFilename, title)
	local titlefile = io.open(titleFilename, "w")
	if titlefile then
		titlefile:write(title)
		io.close (titlefile)
		return true
	end
	
	writeLogfile(3, "PSConvert.writeTitleFile: cannot open ".. titleFilename .. "\n")
	return false
	
end