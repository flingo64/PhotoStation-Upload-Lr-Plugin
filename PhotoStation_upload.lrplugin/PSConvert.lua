--[[----------------------------------------------------------------------------

PSConvert.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2021, Martin Messmer

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

]]
--------------------------------------------------------------------------------

-- Lightroom API
-- local LrFileUtils = import 'LrFileUtils'
local LrDate 		= import 'LrDate'
local LrDialogs 		= import 'LrDialogs'
local LrFileUtils 	= import 'LrFileUtils'
local LrPathUtils 	= import 'LrPathUtils'
local LrPrefs	 	= import 'LrPrefs'
local LrShell 		= import 'LrShell'
local LrTasks 		= import 'LrTasks'

require "PSUtilities"

--================== locals =========================================================--

-- videoConversion defines the conversion parameters based on the requested target dimension
-- must be sorted from lowest to highest resolution
local videoConversion = {
	{
		id = 'MOBILE',
		upToHeight 	= 240,
	},

	{
		id = 'LOW',
		upToHeight 	= 360,
	},

	{
		id = 'MEDIUM',
		upToHeight 	= 720,
	},

	{
		id = 'HIGH',
		upToHeight	= 1080,
	},

	{
		id = 'ULTRA',
		upToHeight	= 2160,
	},
}

-- getRawParams(picExt, srcPhoto, exportFormat) ---------------------
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

-- ffmpegGetRotateParams(hardRotate, vrotation, mrotation, dimension, aspectRatio) --------------------------------------
--		h			- converter handle
--  	hardRotate	- should the video be hard-rotated
-- 		vrotation	- rotation as set in video stream metadata
--		mrotation	- meta-rotation as defined in Keyword 'Rotate-nn'
--		dimension	- original dimension
-- 		aspectRatio	- original aspect ratio
-- returns resulting ffmpeg options:
--		autorotate flag
--		rotation options,
--		dimension
--		aspectRatio
local function ffmpegGetRotateParams(hardRotate, vrotation, mrotation, dimension, aspectRatio)
	local autorotateOpt 	= iif(hardRotate, '', '-noautorotate')
	local rotateOpt 		= ''
	local newDimension		= dimension
	local newAspectRatio	= aspectRatio
	local totalRotation		= tostring((tonumber(vrotation) + tonumber(mrotation)) % 360)
	writeLogfile(4, string.format("ffmpegGetRotateParams: hardRotate: %s, v-rotation: %s, m-rotation: %s --> total rotation: %s\n", tostring(hardRotate), vrotation, mrotation, totalRotation))

	if hardRotate then
		-- newDimension and newAspectRatio depends on totalRotation
		if (totalRotation == '90') or (totalRotation == '270') then
				newDimension = string.format("%sx%s",
											string.sub(dimension, string.find(dimension,'x') + 1, -1),
											string.sub(dimension, 1, string.find(dimension,'x') - 1))
				newAspectRatio = string.gsub(newDimension, 'x', ':')
			writeLogfile(4, string.format("ffmpegGetRotateParams: total rotation: %s --> newDim: %s, newAspect: %s\n", totalRotation, newDimension, newAspectRatio))
		end

		-- vrotation will be handled by ffmpgeg's autorotate feature
		-- mrotation will be handled by us: rotate video stream, calculate rotated dimension
		if mrotation == "90" then
			rotateOpt = ',transpose=1'
			writeLogfile(4, "ffmpegGetRotateParams: hard rotate video by 90\n")
		elseif mrotation == "270" then
			rotateOpt = ',transpose=2'
			writeLogfile(4, "ffmpegGetRotateParams: hard rotate video by 270\n")
		elseif mrotation == "180" then
			rotateOpt = ',hflip,vflip'
			writeLogfile(4, "ffmpegGetRotateParams: hard rotate video by 180\n")
		end
	else
		-- soft-rotation for meta-rotation: add /replace rotation flag to stream metadata: will not work for ffmpeg >= 3.3.x
		if (tonumber(mrotation) > 0) then
			rotateOpt = ' -metadata:s:v:0 rotate=' .. tostring(totalRotation)
			writeLogfile(4, "ffmpegGetRotateParams: soft rotate video by " .. tostring(totalRotation) .. "\n")
		end
	end
	return autorotateOpt, rotateOpt, newDimension, newAspectRatio
end

--===================public =================================================================--

PSConvert = {}
PSConvert_mt = { __index = PSConvert }

PSConvert.downloadUrlIMConvert			= 'https://imagemagick.org/script/download.php'
PSConvert.defaultInstallPathIMConvert 	= iif(WIN_ENV,
    										'C:/Program Files/ImageMagick-7.1.0-Q16-HDRI/convert.exe',
    										'/usr/local/bin/convert')

PSConvert.downloadUrlDcraw				= 'http://www.dechifro.org/dcraw/'
PSConvert.defaultInstallPathDcraw 		= iif(WIN_ENV,
    										'C:/Program Files/ImageMagick-7.1.0-Q16-HDRI/convert.exe/dcraw.exe',
    										'/usr/local/bin/dcraw')

PSConvert.downloadUrlFfmpeg				= 'https://ffmpeg.org/download.html'
PSConvert.defaultInstallPathFfmpeg 		= iif(WIN_ENV,
    										'C:/Windows/ffmpeg.exe',
    										'/usr/local/bin/ffmpeg')

PSConvert.defaultVideoPresetsFn = "PSVideoConversions.json"
PSConvert.convOptions			= nil

------------------------ new ---------------------------------------------------------------------------------
-- new: initialize convert program paths
function PSConvert.new(includeVideos)
	local prefs 			= LrPrefs.prefsForPlugin()
	local convertprog 		= prefs.convertprog
	local dcrawprog 		= prefs.dcrawprog
	local ffmpegprog 		= prefs.ffmpegprog
	local videoConvPath 	= LrPathUtils.child(_PLUGIN.path, prefs.videoConversionsFn)
	local h 				= {} -- the handle

	if 		not PSDialogs.validateProgram(nil, convertprog)
		or 	not PSDialogs.validateProgram(nil, dcrawprog)
		or 	(includeVideos and not PSDialogs.validateProgram(nil, ffmpegprog))
	then
		writeLogfile(1, string.format("PSConvert.new: one or more missing tools: convert: '%s', dcraw '%s', ffmpeg: '%s'\n", convertprog, dcrawprog, iif(includeVideos, 'not required', ffmpegprog)))
		return nil
	end

	h.conv =		convertprog
	h.dcraw = 		dcrawprog
	h.ffmpeg = 		ffmpegprog

	PSConvert.convOptions = PSConvert.getVideoConvPresets()

	if not PSConvert.convOptions then
		writeLogfile(1, string.format("PSConvert.new: video preset file '%s' is not a valid JSON file!\n",  videoConvPath))
		local action = LrDialogs.confirm("Video Conversion", 'Booo!!\n' .. "Invalid video presets file", "Go to Logfile", "Never mind")
		if action == "ok" then
			LrShell.revealInShell(getLogFilename())
		end
		return nil
	end

	writeTableLogfile(4, "VideoConvPresets", PSConvert.convOptions)

	writeLogfile(3, "PSConvert.new:\n\t\tconv:         '" .. h.conv ..   "'\n\t\tdcraw:        '" .. h.dcraw .. "'" ..
										 "\n\t\tffmpeg:       '" .. h.ffmpeg .. "'\n")
	return setmetatable(h, PSConvert_mt)
end

------------------------ getVideoConvPresets ---------------------------------------------------------------------------------
-- getVideoConvPresets: get video concversion presets
function PSConvert.getVideoConvPresets()
	local prefs = LrPrefs.prefsForPlugin()
	local videoConvPath = LrPathUtils.child(_PLUGIN.path, prefs.videoConversionsFn)

	return JSON:decode(LrFileUtils.readFile(videoConvPath), prefs.videoConversionsFn)
end
---------------------- picture conversion functions ----------------------------------------------------------
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
							h.dcraw .. '" ' .. rawConvParams .. '-O "'  .. srcJpgFilename .. '" "'.. srcFilename ..
							'" 2>> "' .. iif(getLogLevel() >= 4, getLogFilename(), getNullFilename()) .. '"'
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
		iif(bFile ~= '', '( +clone   -define jpeg:size=' ..  bSize .. ' -thumbnail '  ..  bSize .. ' ' .. convParams .. ' -write "' ..  bFile .. '" +delete ) ', '') ..
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

-- ffmpegGetAdditionalInfo(h, srcPhoto, renderedVideoFilename, exportParams) ---------------------------------------------------------
-- get video info both from the video via ffmpeg and from Lr.
-- Metadata is taken from the original video, technical data is taken from rendered video (if given)
--	returns:
--	  nil of vinfo:
--		dateTimeOrig 	as unix timestamp
--		duration 		in seconds
--		vformat			as string: 'h264', 'mjpeg', ...
--		width			as string
--		height			as string
--		realHeight		as string
--		dimension		as pixel dimension 'NxM'
--		realDimension	as pixel dimension 'NxM' calculated from dimension and dar
--		sar				as aspect ratio 'N:M'
--		dar				as aspect ratio 'N:M'
--		rotation		as string '0', '90', '180', '270'
--		mrotation		as string '0', '90', '180', '270' (meta-rotation from 'Rotate-nn' keyword)
--		ffmpeg_version	version of ffmpeg tool used to extract data
function PSConvert.ffmpegGetAdditionalInfo(h, srcPhoto, renderedVideoFilename, exportParams)
	local srcVideoName = srcPhoto:getRawMetadata('path')
	local picBasename = LrPathUtils.removeExtension(LrPathUtils.leafName(srcVideoName))
	local outfile1 =  LrPathUtils.child(tmpdir, LrPathUtils.addExtension(picBasename .. '_ffmpeg', 'txt'))
	local outfile2 =  LrPathUtils.child(tmpdir, LrPathUtils.addExtension(picBasename .. '_ffmpeg-2', 'txt'))
	-- LrTask.execute() will call cmd.exe /c cmdline, so we need additional outer quotes
	local cmdline1 = cmdlineQuote() .. '"' .. h.ffmpeg .. '" -i "' .. srcVideoName .. '" 2> "' .. outfile1 .. '"' .. cmdlineQuote()
	local cmdline2 = iif(renderedVideoFilename, cmdlineQuote() .. '"' .. h.ffmpeg .. '" -i "' .. ifnil(renderedVideoFilename, 'nil') .. '" 2> "' .. outfile2 .. '"' .. cmdlineQuote(), nil)
	local v,w,x,z -- iteration variables for string.gmatch()
	local vinfo = {}

	writeLogfile(4, string.format("ffmpegGetAdditionalInfo(%s, %s) starting ...\n", srcVideoName, ifnil(renderedVideoFilename, '<nil>')))
	writeLogfile(3, cmdline1 .. "\n")
	LrTasks.execute(cmdline1)
	-- ignore errorlevel of ffmpeg here (is 1) , just check the outfile

	if not LrFileUtils.exists(outfile1) then
		writeLogfile(1, "  error on: " .. cmdline1 .. "\n")
		return nil
	end

	local ffmpegReport = LrFileUtils.readFile(outfile1)
	writeLogfile(4, "ffmpeg report(original video):\n" ..
					"===========================================================================\n"..
					ffmpegReport ..
					"===========================================================================\n")


	-------------- ffmpeg version search for avp:
	-- ffmpeg version 1.2.1 Copyright (c) 2000-2013 the FFmpeg developers
	-- ffmpeg version N-82794-g3ab1311 Copyright (c) 2000-2016 the FFmpeg developers
	-- ffmpeg version 3.2.2 Copyright (c) 2000-2016 the FFmpeg developers
	vinfo.ffmpeg_version = string.match(ffmpegReport, "ffmpeg version ([^%s]+)")
	if not vinfo.ffmpeg_version then
		writeLogfile(3, "  error: cannot find ffmpeg version\n")
	end
	writeLogfile(4, "	ffmpeg version: " .. vinfo.ffmpeg_version .. "\n")

	-------------- CaptureDate search for avp: 'date            : 2014-07-14T21:35:04-0700'
	local dateCaptureString
	for v in string.gmatch(ffmpegReport, "date%s+:%s+([%d%-]+[%sT][%d%:]+)") do
		dateCaptureString = v
		writeLogfile(4, "dateCaptureString: " .. dateCaptureString .. "\n")
		-- translate from  yyyy-mm-dd HH:MM:ss to timestamp
		vinfo.dateCapture = LrDate.timeFromComponents(string.sub(dateCaptureString,1,4),
												string.sub(dateCaptureString,6,7),
												string.sub(dateCaptureString,9,10),
												string.sub(dateCaptureString,12,13),
												string.sub(dateCaptureString,15,16),
												string.sub(dateCaptureString,18,19),
												'local') -- ignore timezone
		writeLogfile(4, "	ffmpeg-dateCapture: " .. LrDate.timeToUserFormat(vinfo.dateCapture, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
		vinfo.dateCapture = LrDate.timeToPosixDate(vinfo.dateCapture)
		break
     end

	-------------- DateTimeOriginal: search for avp:  -------------------------
	--	'creation_time : 2014-09-10 16:09:51'
	--	'creation_time : 2014-09-10T16:09:51.000000Z'
	local creationTimeString
	for v in string.gmatch(ffmpegReport, "creation_time%s+:%s+([%d%-]+[%sT][%d%:]+)") do
		creationTimeString = v
		writeLogfile(4, "	creationTimeString: " .. creationTimeString .. "\n")
		-- translate from  yyyy-mm-dd HH:MM:ss to timestamp
		vinfo.dateCreation = LrDate.timeFromComponents(string.sub(creationTimeString,1,4),
												string.sub(creationTimeString,6,7),
												string.sub(creationTimeString,9,10),
												string.sub(creationTimeString,12,13),
												string.sub(creationTimeString,15,16),
												string.sub(creationTimeString,18,19),
												'local')
		writeLogfile(4, "	ffmpeg-creationTime: " .. LrDate.timeToUserFormat(vinfo.dateCreation, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
		vinfo.dateCreation = LrDate.timeToPosixDate(vinfo.dateCreation)
		break
     end

   	-- look also for DateTimeOriginal in Metadata
   	local dateTime, isMetadataDate = PSLrUtilities.getDateTimeOriginal(srcPhoto)
	if isMetadataDate then
		vinfo.dateMetadata = dateTime
	else
		vinfo.dateFileCreation = dateTime
	end

	-- take the best available dateTime as srcDateTime
	--  - dateTimeOrginal from Lr metadata (best)
	--  - date from video header 'date:'
	--  - date from video header 'creation date:'
	--  - dateTimeDigitized from Lr metadata
	--  - dateTimeCreated from Lr metadata
	--  - cration date from file
	--  - current date (worst)
	if vinfo.dateMetadata then
		vinfo.srcDateTime = vinfo.dateMetadata
	elseif vinfo.dateCapture and (not vinfo.dateCreation or vinfo.dateCapture < vinfo.dateCreation) then
		vinfo.srcDateTime = vinfo.dateCapture
	elseif vinfo.dateCreation then
		vinfo.srcDateTime = vinfo.dateCreation
	else
		vinfo.srcDateTime = vinfo.dateFileCreation
	end

	-------------- GPS info -------------------------------------------------
	-- Add GPS data: export only, if not forbidden by export params
	-- Lr GPS data has precedence over video embedded GPS data

	-------------- search for avp like:  ------------------------------------
	--     location        : +52.1234+013.1234/
	--     location 	   : +33.9528-118.3960+026.000/
	--     location	 	   : +33.9528-118.3960		(DJI Mavic)
	vinfo.latitudeVideo, vinfo.longitudeVideo, vinfo.gpsAltitudeVideo = string.match(ffmpegReport, "location%s+:%s+([%+%-]%d+%.%d+)([%+%-]%d+%.%d+)([%+%-%d%.]*)")

	local gpsData = srcPhoto:getRawMetadata("gps")
	if gpsData and gpsData.latitude and gpsData.longitude then
		vinfo.latitudeLr =  iif(tonumber(gpsData.latitude)   >= 0 , '+' .. gpsData.latitude, gpsData.latitude)
		vinfo.longitudeLr = iif(tonumber(gpsData.longitude)  >= 0 , '+' .. gpsData.longitude, gpsData.longitude)
	end

	local gpsAltData = srcPhoto:getRawMetadata("gpsAltitude")
	if gpsAltData  then
		vinfo.altitudeLr =  tostring(gpsAltData)
	end

	if not exportParams.LR_removeLocationMetadata then
		if vinfo.latitudeLr then
			vinfo.latitude =  vinfo.latitudeLr
			vinfo.longitude = vinfo.longitudeLr
			vinfo.altitude = vinfo.altitudeLr
		else
			vinfo.latitude =  vinfo.latitudeVideo
			vinfo.longitude = vinfo.longitudeVideo
			vinfo.altitude = vinfo.altitudeVideo
		end
		if vinfo.latitude and vinfo.longitude then
			writeLogfile(4, string.format("\tgps: %s / %s (altitude:%s)\n", vinfo.latitude, vinfo.longitude, vinfo.altitude))
		end
	end
	LrFileUtils.delete(outfile1)

	------------------- all other info is taken from rendered video -------------------------------
	if not cmdline2 then
		writeTableLogfile(3, "vinfo(" .. srcVideoName .. ")", vinfo, false)
		return vinfo
	end

	------------------- rendered video is given --> continue with that ----------------------------
	writeLogfile(3, cmdline2 .. "\n")
	LrTasks.execute(cmdline2)

	if not LrFileUtils.exists(outfile2) then
		writeLogfile(3, "  error on: " .. cmdline2 .. "\n")
		return nil
	end

	local ffmpegReport = LrFileUtils.readFile(outfile2)
	writeLogfile(4, "ffmpeg report(rendered video):\n" ..
					"===========================================================================\n"..
					ffmpegReport ..
					"===========================================================================\n")


	-------------- duration: search for avp: 'Duration: <HH:MM:ss.msec>,' -------------------------
	local durationString
	for v in string.gmatch(ffmpegReport, "Duration:%s+([%d%p]+),") do
		durationString = v
		writeLogfile(4, "	durationString: " .. durationString .. "\n")
		-- translate from  HH:MM:ss.msec to seconds
		vinfo.duration = 	tonumber(string.sub(durationString,1,2)) * 3600 +
					tonumber(string.sub(durationString,4,5)) * 60 +
					tonumber(string.sub(durationString,7,11))
		writeLogfile(4, string.format("\tduration: %.2f\n", vinfo.duration))
     end

	-- check if duration is available (min. requirement),
	-- stop scanning metadata if not: might be due to a missing input file / out of disk space issue
	if not vinfo.duration then
		writeLogfile(1, "  error on scanning meatadata of rendered video '" .. renderedVideoFilename .. "'\n")
		LrFileUtils.delete(outfile2)
		return nil
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
		writeLogfile(4, string.format("\tdimension: %s vformat: %s [SAR: %s DAR: %s]\n", vinfo.dimension, vinfo.vformat, ifnil(vinfo.sar, '<Nil>'), ifnil(vinfo.dar, '<Nil>')))
    end

	-- Video: h264 (High) (avc1 / 0x31637661), yuv420p, 1920x1080, 17474 kb/s, SAR 65536:65536 DAR 16:9, 28.66 fps, 29.67 tbr, 90k tbn, 180k tbc
	-- get sar (sample aspect ratio) and dar (display aspect ratio)
	if not vinfo.sar or (vinfo.sar == '') then
		for w, x in string.gmatch(ffmpegReport, "Video:[%s%w%(%)/]+,[%s%w]+,[%s%w]+,[%s%w/]+,%s+SAR%s+([%d:]+)%s+DAR%s+([%d:]+)") do
			vinfo.sar = w
			vinfo.dar = x
			writeLogfile(4, string.format("\tSAR: %s, DAR: %s\n", ifnil(vinfo.sar, '<Nil>'), ifnil(vinfo.dar, '<Nil>')))
		end
	end

	-- get the real dimension: may be different from dimension if dar is set
	-- dimension: NNNxMMM
	vinfo.width, vinfo.height = string.match(vinfo.dimension, '(%d+)x(%d+)')
	if (ifnil(vinfo.dar, '') == '') or (ifnil(vinfo.sar,'') == '1:1') then
		vinfo.realDimension = vinfo.dimension
		-- aspectRatio: NNN:MMM
		vinfo.dar = string.gsub(vinfo.dimension, 'x', ':')
	else
		local darWidth , darHeight = string.match(vinfo.dar, '(%d+):(%d+)')
		vinfo.realWidth = math.floor(((tonumber(vinfo.height) * tonumber(darWidth) / tonumber(darHeight)) + 0.5) / 2) * 2 -- make sure width is an even integer
		vinfo.realDimension = string.format("%dx%d", vinfo.realWidth, vinfo.height)
	end

	-------------- rotation: search for avp like:  -------------------------
	-- rotate          : 90
	vinfo.rotation = '0'
	for v in string.gmatch(ffmpegReport, "rotate%s+:%s+([%d]+)") do
		vinfo.rotation = v
		writeLogfile(4, string.format("\trotation: %s\n", vinfo.rotation))
	end

	-- Meta-Rotation: search for "Rotate-nn" in keywords
	vinfo.mrotation = 0
	local keywords = srcPhoto:getRawMetadata("keywords")
	for i = 1, #keywords do
		if string.find(keywords[i]:getName(), 'Rotate-', 1, true) then
			vinfo.mrotation = string.sub (keywords[i]:getName(), 8)
			writeLogfile(4, string.format("Keyword[%d]= %s, rotation= %s\n", i, keywords[i]:getName(), vinfo.mrotation))
		end
	end

	-------------- Audio: search for avp like:  -------------------------
	-- Stream #0:1(eng): Audio: aac (LC) (mp4a / 0x6134706D), 48000 Hz, mono, fltp, 96 kb/s (default)
	vinfo.aFormat = string.match(ffmpegReport, "Audio:%s+(%w+)")
	writeLogfile(4, string.format("\taFormat: %s\n", vinfo.aFormat))

	LrFileUtils.delete(outfile2)

	writeTableLogfile(3, "vinfo(" .. srcVideoName .. ")", vinfo, false)
	return vinfo
end

-- ffmpegGetThumbFromVideo(h, srcVideoFilename, vinfo, thumbFilename) ---------------------------------------------------------
function PSConvert.ffmpegGetThumbFromVideo (h, srcVideoFilename, vinfo, thumbFilename)
	local outfile =  LrPathUtils.replaceExtension(srcVideoFilename, 'txt')
	local autorotateOpt, rotateOpt, newDim, aspectRatio = ffmpegGetRotateParams(true, vinfo.rotation, vinfo.mrotation, vinfo.realDimension, string.gsub(vinfo.realDimension, 'x', ':'))
	local snapshotTime = iif(vinfo.duration < 4, '00:00:00', '00:00:03')

	writeLogfile(3, string.format("ffmpegGetThumbFromVideo: %s dim %s v-rotation %s m-rotation %s duration %d --> newDim: %s aspectR: %s snapshot at %s\n",
								srcVideoFilename, vinfo.realDimension, vinfo.rotation, vinfo.mrotation, vinfo.duration, newDim, aspectRatio, snapshotTime))

	-- generate first thumb from video
	local cmdline = cmdlineQuote() ..
						'"' .. h.ffmpeg .. '" ' ..
						autorotateOpt ..
						'-i "' .. srcVideoFilename .. '" ' ..
						'-y -vframes 1 -ss ' .. snapshotTime .. ' -an -qscale 0 -f mjpeg -vf format=yuv420p'.. rotateOpt .. ' ' ..
						'-s ' .. newDim .. ' -aspect ' .. aspectRatio .. ' ' ..
						'"' .. thumbFilename .. '" 2> "' .. outfile .. '"' ..
					cmdlineQuote()

	writeLogfile(3, cmdline .. "\n")
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

-- convertVideo(h, srcVideoFilename, vinfo, dstHeight, hardRotate, videoQuality, dstVideoFilename) --------------------------
--[[
	converts a video to an mp4 with a given resolution using the ffmpeg tool
	h					conversionHandle
	srcVideoFilename	the src video file
	vinfo				orig video metadata info
	dstHeight			target height in pixel
	hardrotate			do hard rotation
	videoQuality	audio / video conversion options
	dstVideoFilename	the target video file
]]
function PSConvert.convertVideo(h, srcVideoFilename, vinfo, dstHeight, hardRotate, videoQuality, dstVideoFilename)
	local tmpVideoFilename = LrPathUtils.replaceExtension(LrPathUtils.removeExtension(dstVideoFilename) .. '_TMP', LrPathUtils.extension(dstVideoFilename))
	local outfile =  LrPathUtils.replaceExtension(tmpVideoFilename, 'txt')
	local passLogfile =  LrPathUtils.replaceExtension(tmpVideoFilename, 'passlog')
	local arw = tonumber(string.match(vinfo.dar, '(%d+):%d+'))
	local arh = tonumber(string.match(vinfo.dar, '%d+:(%d+)'))
	local dstWidth = math.floor(((dstHeight * arw / arh) + 0.5) / 2) * 2  -- make sure width is an even integer
	local dstDim = string.format("%dx%d", dstWidth, dstHeight)
	local dstAspect = string.gsub(dstDim, 'x', ':')

	writeLogfile(3, string.format("convertVideo: %s aspectR %s, dstHeight: %d hardRotate %s v-rotation %s m-rotation %s\n",
								srcVideoFilename, vinfo.dar, dstHeight, tostring(hardRotate), vinfo.rotation, vinfo.mrotation))

	-- get rotation params based on rotate flag
	local autorotateOpt, rotateOpt
	autorotateOpt, rotateOpt, dstDim, dstAspect = ffmpegGetRotateParams(hardRotate, vinfo.rotation, vinfo.mrotation, dstDim, dstAspect)

	-- ffmpeg major version 4 is supported, anything below may or may not work
	local ffmpeg_major_version = string.match(vinfo.ffmpeg_version, '^(%d+)')
	if tonumber(ffmpeg_major_version) < 4 then
		writeLogfile(2, string.format("!!! Warning: Unsupported ffmpeg version %s may not work as expected, please use ffmpeg V 4.x or higher!!!\n", vinfo.ffmpeg_version))
		if tonumber(ffmpeg_major_version) == 1 then autorotateOpt = '' end
	end

	-- add creation_time metadata to destination video
	local createTimeOpt = '-metadata creation_time=' .. LrDate.timeToUserFormat(LrDate.timeFromPosixDate(vinfo.srcDateTime), '"%Y-%m-%d %H:%M:%S" ', false)

	-- add location metadata to destination video: doesn't work w/ ffmpeg 3.3.2, see ffmpeg #4209
	local locationInfoOpt = ''
	if vinfo.latitude then
		 locationInfoOpt = '-metadata location="' .. vinfo.latitude .. vinfo.longitude .. ifnil(vinfo.gpsHeight, '') .. '/" '
	end

	local convOptions = PSConvert.convOptions[videoQuality]
	-- transcoding pass 1
--	LrFileUtils.copy(srcVideoFilename, srcVideoFilename ..".bak")

	local cmdline =  cmdlineQuote() ..
				'"' .. h.ffmpeg .. '" ' ..
				autorotateOpt ..
				ifnil(convOptions.input_options, "") .. " " ..
				iif(vinfo.aFormat, '', '-f lavfi -i anullsrc ') ..
				'-i "' 	.. srcVideoFilename .. '" ' ..
				'-y ' 	..  -- override output file

				iif(vinfo.aFormat,'', '-shortest ') ..
				convOptions.audio_options .. ' ' ..
				iif(convOptions.video_options_pass_2, '-pass 1 ', '') ..
				convOptions.video_filters ..
				rotateOpt .. ' ' ..
				convOptions.video_options .. ' ' ..
				'-s ' .. dstDim .. ' -aspect ' .. dstAspect .. ' ' ..
				createTimeOpt ..
				locationInfoOpt ..
				ifnil(convOptions.output_options, "") .. " " ..
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
	if convOptions.video_options_pass_2 then
    	cmdline =   cmdlineQuote() ..
    				'"' .. h.ffmpeg .. '" ' ..
    				autorotateOpt ..
					ifnil(convOptions.input_options, "") .. " " ..
					iif(vinfo.aFormat, '', '-f lavfi -i anullsrc ') ..
    				'-i "' ..	srcVideoFilename .. '" ' ..
					'-y ' 	..  -- override output file

					iif(vinfo.aFormat,'', '-shortest ') ..
					PSConvert.convOptions[videoQuality].audio_options .. ' ' ..
					'-pass 2 ' ..
					convOptions.video_filters ..
					rotateOpt .. ' ' ..
					PSConvert.convOptions[videoQuality].video_options_pass_2 .. ' ' ..
    				'-s ' .. dstDim .. ' -aspect ' .. dstAspect .. ' ' ..
    				createTimeOpt ..
    				locationInfoOpt ..
					ifnil(convOptions.output_options, "") .. " " ..
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

	LrFileUtils.move( tmpVideoFilename, dstVideoFilename)

	LrFileUtils.delete(passLogfile)
	LrFileUtils.delete(outfile)

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