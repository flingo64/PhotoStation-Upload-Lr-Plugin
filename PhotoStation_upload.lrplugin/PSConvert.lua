--[[----------------------------------------------------------------------------

PSConvert.lua
conversion primitives:
	- initialize
	- convertPicConcurrent
	- convertVideo
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
-- local LrFileUtils = import 'LrFileUtils'
local LrDate = import 'LrDate'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'

require "PSUtilities"

--============================================================================--

PSConvert = {}


-- !!! don't use local variable for settings that may differ for export sessions!
-- only w/ "reload plug-in on each export", each export task will get its own copy of these variables
--[[
local conv
local dcraw
local ffmpeg
local qtfstart
]]

-- ffmpeg encoder to use depends on OS
local encoderOpt

---------------------- shell encoding routines ---------------------------------------------------------

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

------------------------ initialize ---------------------------------------------------------------------------------

-- initialize: set serverUrl, loginPath and uploadPath
function PSConvert.initialize(PSUploaderPath)
	local h = {} -- the handle

	writeLogfile(4, "PSConvert.initialize: PSUploaderPath= " .. PSUploaderPath .. "\n")

	local convertprog = 'convert'
	local dcrawprog = 'dcraw'
	local ffmpegprog = 'ffmpeg'
	local qtfstartprog = 'qt-faststart'

	if WIN_ENV  then
		local progExt = 'exe'
		convertprog = LrPathUtils.addExtension(convertprog, progExt)
		dcrawprog = LrPathUtils.addExtension(dcrawprog, progExt)
		ffmpegprog = LrPathUtils.addExtension(ffmpegprog, progExt)
		qtfstartprog = LrPathUtils.addExtension(qtfstartprog, progExt)
	end
	
	h.conv = LrPathUtils.child(LrPathUtils.child(PSUploaderPath, 'ImageMagick'), convertprog)
	h.dcraw = LrPathUtils.child(LrPathUtils.child(PSUploaderPath, 'ImageMagick'), dcrawprog)
	h.ffmpeg = LrPathUtils.child(LrPathUtils.child(PSUploaderPath, 'ffmpeg'), ffmpegprog)
	h.qtfstart = LrPathUtils.child(LrPathUtils.child(PSUploaderPath, 'ffmpeg'), qtfstartprog)

	encoderOpt = iif(WIN_ENV, '-acodec libvo_aacenc',  '-strict experimental -acodec aac')
	
	writeLogfile(4, "PSConvert.initialize:\n\t\t\tconv: " .. h.conv .. "\n\t\t\tdcraw: " .. h.dcraw .. 
										 "\n\t\t\tffmpeg: " .. h.ffmpeg .. "\n\t\t\tqt-faststart: " .. h.qtfstart .. "\n")
	return h
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
--		or picExt == 'srw'								-- Samsung --> not supported by PhotoStation
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

		local cmdline = cmdlineQuote() .. '"' .. h.dcraw .. '" ' .. rawConvParams .. '-c "' .. srcFilename .. '" > "' .. srcJpgFilename .. '"' .. cmdlineQuote()
		writeLogfile(4, cmdline .. "\n")
		
		if LrTasks.execute(cmdline) > 0 then
			writeLogfile(3,cmdline .. "... failed!\n")
			writeLogfile(1, "convertPicConcurrent: " .. srcFilename  .. " failed!\n")
			return false
		end
	else
		srcJpgFilename = srcFilename
	end
	
	local cmdline = cmdlineQuote() .. '"' .. h.conv .. '" "' .. srcJpgFilename .. '" ' ..
			shellEscape(
						 '( -clone 0 -define jpeg:size=' .. xlSize .. ' -thumbnail '  .. xlSize .. ' ' .. convParams .. ' -write "' .. xlFile .. '" ) -delete 0 ' ..
		iif(lFile ~= '', '( +clone   -define jpeg:size=' ..  lSize .. ' -thumbnail '  ..  lSize .. ' ' .. convParams .. ' -write "' ..  lFile .. '" +delete ) ', '') ..
						 '( +clone   -define jpeg:size=' ..  bSize .. ' -thumbnail '  ..  bSize .. ' ' .. convParams .. ' -write "' ..  bFile .. '" +delete ) ' ..
						 '( +clone   -define jpeg:size=' ..  mSize .. ' -thumbnail '  ..  mSize .. ' ' .. convParams .. ' -write "' ..  mFile .. '" +delete ) ' ..
								    '-define jpeg:size=' ..  sSize .. ' -thumbnail '  ..  sSize .. ' ' .. convParams .. ' "' 	   ..  sFile .. '"'
			) .. cmdlineQuote()
	writeLogfile(4, cmdline .. "\n")
	if LrTasks.execute(cmdline) > 0 then
		writeLogfile(3,cmdline .. "... failed!\n")
		writeLogfile(1, "convertPicConcurrent: " .. srcFilename  .. " failed!\n")
		return false
	end

	return true
end

---------------------- video functions ----------------------------------------------------------

-- ffmpegGetAdditionalInfo(h, srcVideoFilename) ---------------------------------------------------------
--[[
	get the capture date, duration, video format, resolution and aspect ratio of a video via ffmpeg. Lr won't give you this information
	returns: 
	  nil of vinfo:
		dateTimeOrig 	as unix timestamp
		duration 		in seconds
		vformat			as string: 'h264', 'mjpeg', ...
		dimension		as pixel dimension 'NxM'
		sar				as aspect ratio 'N:M' 
		dar				as aspect ratio 'N:M'
		rotation		as string '0', '90', '180', '270'
]]
function PSConvert.ffmpegGetAdditionalInfo(h, srcVideoFilename)
	-- returns DateTimeOriginal / creation_time retrieved via ffmpeg  as Cocoa timestamp
	local picBasename = LrPathUtils.removeExtension(LrPathUtils.leafName(srcVideoFilename))
	local outfile =  LrPathUtils.child(tmpdir, LrPathUtils.addExtension(picBasename .. '_ffmpeg', 'txt'))
	-- LrTask.execute() will call cmd.exe /c cmdline, so we need additional outer quotes
	local cmdline = cmdlineQuote() .. '"' .. h.ffmpeg .. '" -i "' .. srcVideoFilename .. '" 2> "' .. outfile .. '"' .. cmdlineQuote()
	local v,w,x,z -- iteration variables for string.gmatch()
	local vinfo = {}
	
	writeLogfile(4, cmdline .. "\n")
	LrTasks.execute(cmdline)
	-- ignore errorlevel of ffmpeg here (is 1) , just check the outfile
	
	if not LrFileUtils.exists(outfile) then
		writeLogfile(3, "  error on: " .. cmdline .. "\n")
		return nil
	end

	local ffmpegReport = LrFileUtils.readFile(outfile)
	writeLogfile(4, "ffmpeg report:\n" .. ffmpegReport)
	
	-------------- DateTimeOriginal search for avp: 'date            : 2014-07-14T21:35:04-0700'
	local dateCaptureString, dateCapture
	for v in string.gmatch(ffmpegReport, "date%s+:%s+([%d%p]+T[%d%p]+)") do
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
		writeLogfile(4, "  ffmpeg-dateCapture: " .. LrDate.timeToUserFormat(dateCapture, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
		dateCapture = LrDate.timeToPosixDate(dateCapture)
		break
     end
	
	-------------- DateTimeOriginal: search for avp: 'creation_time : date' -------------------------
	local creationTimeString, creationTime
	for v in string.gmatch(ffmpegReport, "creation_time%s+:%s+([%d%p]+%s[%d%p]+)") do
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
		writeLogfile(4, "  ffmpeg-creationTime: " .. LrDate.timeToUserFormat(creationTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
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
		writeLogfile(4, string.format(" duration: %.2f\n", vinfo.duration))
     end
	 
	-------------- resolution: search for avp like:  -------------------------
	-- Video: mjpeg (MJPG / 0x47504A4D), yuvj422p, 640x480, 30 tbr, 30 tbn, 30 tbc
	-- Video: h264 (Main) (avc1 / 0x31637661), yuv420p, 1440x1080 [SAR 4:3 DAR 16:9], 12091 kb/s, 29.97 fps, 29.97 tbr, 30k tbn, 59.94 tbc
	for z, v, w, x in string.gmatch(ffmpegReport, "Video:%s+(%w+)[%s%w%(%)/]+,[%s%w]+,%s+([%dx]+)%s*%[*%w*%s*([%d:]*)%s*%w*%s*([%w:]*)%]*,") do
		vinfo.vformat = z
		vinfo.dimension = v
		vinfo.sar = w
		vinfo.dar = x
		writeLogfile(4, string.format("dimension: %s vformat: %s [SAR: %s DAR: %s]\n", vinfo.dimension, vinfo.vformat, ifnil(vinfo.sar, '<Nil>'), ifnil(vinfo.dar, '<Nil>')))
    end
	 
	-- Video: h264 (High) (avc1 / 0x31637661), yuv420p, 1920x1080, 17474 kb/s, SAR 65536:65536 DAR 16:9, 28.66 fps, 29.67 tbr, 90k tbn, 180k tbc
	-- get sar (sample aspect ratio) and dar (display aspect ratio)
	if not vinfo.sar or (vinfo.sar == '') then
		for w, x in string.gmatch(ffmpegReport, "Video:[%s%w%(%)/]+,[%s%w]+,[%s%w]+,[%s%w/]+,%s+SAR%s+([%d:]+)%s+DAR%s+([%d:]+)") do
			vinfo.sar = w
			vinfo.dar = x
			writeLogfile(4, string.format("SAR: %s, DAR: %s\n", ifnil(vinfo.sar, '<Nil>'), ifnil(vinfo.dar, '<Nil>')))
		end
	end

	-------------- rotation: search for avp like:  -------------------------
	-- rotate          : 90
	vinfo.rotation = '0'
	for v in string.gmatch(ffmpegReport, "rotate%s+:%s+([%d]+)") do
		vinfo.rotation = v
		writeLogfile(4, string.format("rotation: %s\n", vinfo.rotation))
	end
	
	LrFileUtils.delete(outfile)

	if dateCapture and dateCapture < creationTime then
		vinfo.dateTimeOrig = dateCapture
	else
		vinfo.dateTimeOrig = creationTime
	end
	
	return vinfo
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
			rotateOpt = '-vf "transpose=1" -metadata:s:v:0 rotate=0'
			newDimension = string.format("%sx%s", 
										string.sub(dimension, string.find(dimension,'x') + 1, -1),
										string.sub(dimension, 1, string.find(dimension,'x') - 1))
			newAspectRatio = string.gsub(newDimension, 'x', ':')
			writeLogfile(4, "ffmpegGetRotateParams: hard rotate video by 90\n")
		elseif rotation == "270" then
			rotateOpt = '-vf "transpose=2" -metadata:s:v:0 rotate=0'
			newDimension = string.format("%sx%s", 
										string.sub(dimension, string.find(dimension,'x') + 1, -1),
										string.sub(dimension, 1, string.find(dimension,'x') - 1))
			newAspectRatio = string.gsub(newDimension, 'x', ':')
			writeLogfile(4, "ffmpegGetRotateParams: hard rotate video by 270\n")
		elseif rotation == "180" then
			rotateOpt = '-vf "hflip,vflip" -metadata:s:v:0 rotate=0'
			writeLogfile(4, "ffmpegGetRotateParams: hard rotate video by 180\n")
		end
	else
		-- soft-rotation: add rotation flag to metadata
		if rotation == "90" then
			rotateOpt = '-metadata:s:v:0 rotate=90'
			writeLogfile(4, "ffmpegGetRotateParams: soft rotate video by 90\n")
		elseif rotation == "180" then
			rotateOpt = '-metadata:s:v:0 rotate=180'
			writeLogfile(4, "ffmpegGetRotateParams: soft rotate video by 180\n")
		elseif rotation == "270" then
			rotateOpt = '-metadata:s:v:0 rotate=270'
			writeLogfile(4, "ffmpegGetRotateParams: soft rotate video by 270\n")
		end 
	end
	return rotateOpt, newDimension, newAspectRatio
end

-- ffmpegGetThumbFromVideo(srcVideoFilename, thumbFilename, dimension, rotation) ---------------------------------------------------------
function PSConvert.ffmpegGetThumbFromVideo (h, srcVideoFilename, thumbFilename, dimension, rotation, duration)
	local outfile =  LrPathUtils.replaceExtension(srcVideoFilename, 'txt')
	local rotateOpt, nweDim, aspectRatio
	local snapshotTime = iif(duration < 4, '00:00:00', '00:00:03') 
	
	rotateOpt, newDim, aspectRatio = PSConvert.ffmpegGetRotateParams(h, true, rotation, dimension, string.gsub(dimension, 'x', ':'))
	
	writeLogfile(3, string.format("ffmpegGetThumbFromVideo: %s dim %s rotation %s --> newDim: %s aspectR: %s\n", 
								srcVideoFilename, dimension, rotation, newDim, aspectRatio))
	
	-- generate first thumb from video
	local cmdline = cmdlineQuote() ..
						'"' .. h.ffmpeg .. 
						'" -i "' .. srcVideoFilename .. 
						'" -y -vframes 1 -ss ' .. snapshotTime .. ' -an -qscale 0 -f mjpeg '.. rotateOpt .. ' ' ..
						'-s ' .. newDim .. ' -aspect ' .. aspectRatio .. 
						' "' .. thumbFilename .. '" 2> "' .. outfile .. '"' ..
					cmdlineQuote()

	writeLogfile(4, cmdline .. "\n")
	if LrTasks.execute(cmdline) > 0 or not LrFileUtils.exists(thumbFilename) then
		writeLogfile(3, "  error on: " .. cmdline .. "\n")
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
		
		pass1Params =	"-ar 44100 -b:a 64k -ac 2 -pass 1 -vcodec libx264 -b:v 256k -bt 256k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 0 -vprofile baseline -vsync 2 -level 13 -coder 0 -refs 1 -bf 0 -subq 1 -trellis 0 -me_method epzs -partitions 0 -f mp4",
		
		pass2Params =	"-ar 44100 -b:a 64k -ac 2 -pass 2 -vcodec libx264 -b:v 256k -bt 256k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 0 -vprofile baseline -vsync 2 -level 13 -coder 0 -refs 1 -bf 0 -subq 5 -trellis 0 -me_method hex -partitions +parti4x4+parti8x8+partp4x4+partp8x8+partb8x8 -f mp4",
	},

	{	
		id = 'LOW',
		upToHeight 	= 360,
		
		pass1Params = 	"-ar 44100 -b:a 96k -ac 2 -pass 1 -vcodec libx264 -b:v 256k -bt 256k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 0 -vprofile baseline -vsync 2 -level 13 -coder 0 -refs 1 -bf 0 -subq 1 -trellis 0 -me_method epzs -partitions 0 -f mp4",

		pass2Params = 	"-ar 44100 -b:a 96k -ac 2 -pass 2 -vcodec libx264 -b:v 256k -bt 256k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 0 -vprofile baseline -vsync 2 -level 13 -coder 0 -refs 1 -bf 0 -subq 5 -trellis 0 -me_method hex -partitions +parti4x4+parti8x8+partp4x4+partp8x8+partb8x8 -f mp4",
	},

	{	
		id = 'MEDIUM',
		upToHeight 	= 720,
		
		pass1Params = 	"-ar 44100 -b:a 96k -ac 2 -pass 1 -vcodec libx264 -b:v 1000k -bt 1000k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 0 -vsync 2 -level 31 -coder 0 -refs 4 -bf 2 -b_qfactor 1.30 -b-pyramid none -b_strategy 1 -b-bias 0 -direct-pred 1 -weightb 1 -subq 1 -trellis 0 -me_method epzs -partitions 0 -f mp4",

		pass2Params = 	"-ar 44100 -b:a 96k -ac 2 -pass 2 -vcodec libx264 -b:v 1000k -bt 1000k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 0 -vsync 2 -level 31 -coder 0 -refs 4 -bf 2 -b_qfactor 1.30 -b-pyramid none -b_strategy 1 -b-bias 0 -direct-pred 1 -weightb 1 -subq 5 -trellis 0 -me_method hex -partitions +parti4x4+parti8x8+partp4x4+partp8x8+partb8x8 -f mp4",
	},

	{	
		id = 'HIGH',
		upToHeight	= 1080,
		
		pass1Params = 	"-ar 44100 -b:a 96k -ac 2 -pass 1 -vcodec libx264 -b:v 2000k -bt 2000k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 1 -vsync 2 -level 41 -coder 1 -refs 3 -bf 2 -b_qfactor 1.30 -b-pyramid none -b_strategy 1 -b-bias 0 -direct-pred 1 -weightb 1 -subq 1 -trellis 0 -me_method epzs -partitions 0 -f mp4",

		pass2Params = 	"-ar 44100 -b:a 96k -ac 2 -pass 2 -vcodec libx264 -b:v 2000k -bt 2000k -flags +loop -mixed-refs 1 -me_range 16 -cmp chroma -chromaoffset 0 -g 60 -keyint_min 25 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.60 -qmin 10 -qmax 51 -qdiff 4 -cplxblur 20.0 -qblur 0.5 -i_qfactor 0.71 -8x8dct 1 -vsync 2 -level 41 -coder 1 -refs 3 -bf 2 -b_qfactor 1.30 -b-pyramid none -b_strategy 1 -b-bias 0 -direct-pred 1 -weightb 1 -subq 5 -trellis 1 -me_method hex -partitions +parti4x4+parti8x8+partp4x4+partp8x8+partb8x8 -f mp4",
	},	
}

---------------- getResolutionId --------------------------------------------------------------------
function PSConvert.getConvertKey(h, height)
	
	for i = 1, #videoConversion do
		if height <= videoConversion[i].upToHeight then 
			return videoConversion[i].id
		end
	end

	return videoConversion[#videoConversion].id

end

-- convertVideo(h, srcVideoFilename, srcDateTime, aspectRatio, dstHeight, hardRotate, rotation, dstVideoFilename) --------------------------
--[[ 
	converts a video to an mp4 with a given resolution using the ffmpeg and qt-faststart tool
	srcVideoFilename	the src video file
	aspectRatio			aspect ration as N:M
	dstHeight			target height in pixel
	dstVideoFilename	the target video file
]]
function PSConvert.convertVideo(h, srcVideoFilename, srcDateTime, aspectRatio, dstHeight, hardRotate, rotation, dstVideoFilename)
	local tmpVideoFilename = LrPathUtils.replaceExtension(LrPathUtils.removeExtension(dstVideoFilename) .. '_TMP', LrPathUtils.extension(dstVideoFilename))
	local outfile =  LrPathUtils.replaceExtension(tmpVideoFilename, 'txt')
	local passLogfile =  LrPathUtils.replaceExtension(tmpVideoFilename, 'passlog')
	local arw = tonumber(string.sub(aspectRatio, 1, string.find(aspectRatio,':') - 1))
	local arh = tonumber(string.sub(aspectRatio, string.find(aspectRatio,':') + 1, -1))
	local dstWidth = (dstHeight * arw / arh) + 0.5
	local dstDim = string.format("%dx%d", dstWidth, dstHeight)
	local dstAspect = string.gsub(dstDim, 'x', ':')
	local convKey = PSConvert.getConvertKey(h, dstHeight) 		-- get the conversionParams

	writeLogfile(3, string.format("convertVideo: %s aspectR %s, dstHeight: %d hardRotate %s rotation %s using conversion %d/%s (%dp)\n", 
								srcVideoFilename, aspectRatio, dstHeight, tostring(hardRotate), rotation,
								convKey, videoConversion[convKey].id, videoConversion[convKey].upToHeight))
	
	-- get rotation params based on rotate flag 
	local rotateOpt
	rotateOpt, dstDim, dstAspect = PSConvert.ffmpegGetRotateParams(h, hardRotate, rotation, dstDim, dstAspect)

	-- add creation_time metadata to destination video
	local createTimeOpt = '-metadata creation_time=' .. LrDate.timeToUserFormat(LrDate.timeFromPosixDate(srcDateTime), '"%Y-%m-%d %H:%M:%S"', false)
		
--	LrFileUtils.copy(srcVideoFilename, srcVideoFilename ..".bak")
	local cmdline =  cmdlineQuote() ..
				'"' .. h.ffmpeg .. '" -i "' .. 
				srcVideoFilename .. 
				'" -y ' .. encoderOpt .. ' ' ..
				createTimeOpt .. ' ' .. rotateOpt .. ' ' ..
				videoConversion[convKey].pass1Params .. ' ' ..
				'-s ' .. dstDim .. ' -aspect ' .. dstAspect .. ' ' ..
				'-passlogfile "' .. passLogfile .. '"' .. 
				' "' .. tmpVideoFilename .. '" 2> "' .. outfile .. '"' ..
				cmdlineQuote()
				
	writeLogfile(4, cmdline .. "\n")
	if LrTasks.execute(cmdline) > 0 or not LrFileUtils.exists(tmpVideoFilename) then
		writeLogfile(3, "  error on: " .. cmdline .. "\n")
		LrFileUtils.delete(outfile)
		LrFileUtils.delete(tmpVideoFilename)
		return false
	end

	cmdline =   cmdlineQuote() ..
				'"' .. h.ffmpeg .. '" -i "' .. 
				srcVideoFilename .. 
				'" -y ' .. encoderOpt .. ' ' ..
				createTimeOpt .. ' ' .. rotateOpt .. ' ' ..
				videoConversion[convKey].pass2Params .. ' ' ..
				'-s ' .. dstDim .. ' -aspect ' .. dstAspect .. ' ' ..
				'-passlogfile "' .. passLogfile .. '"' .. 
				' "' .. tmpVideoFilename .. '" 2> "' .. outfile ..'"' ..
				cmdlineQuote()

	writeLogfile(4, cmdline .. "\n")
	if LrTasks.execute(cmdline) > 0 or not LrFileUtils.exists(tmpVideoFilename) then
		writeLogfile(3, "  error on: " .. cmdline .. "\n")
		LrFileUtils.delete(outfile)
		LrFileUtils.delete(tmpVideoFilename)
		return false
	end

--	LrFileUtils.copy(tmpVideoFilename, tmpVideoFilename ..".bak")
	cmdline = 	cmdlineQuote() ..
					'"' .. h.qtfstart .. '" "' ..  tmpVideoFilename .. '" "' .. dstVideoFilename .. '" 2> "' .. outfile ..'"' ..
				cmdlineQuote()

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
