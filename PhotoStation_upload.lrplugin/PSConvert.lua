--[[----------------------------------------------------------------------------

PSConvert.lua
conversion primitives:
	- convertPic
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
]]
--------------------------------------------------------------------------------

-- Lightroom API
-- local LrFileUtils = import 'LrFileUtils'
local LrDate = import 'LrDate'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'

--============================================================================--

PSConvert = {}


-- we can store some variables in 'global' local variables safely:
-- each export task will get its own copy of these variables
local tmpdir = LrPathUtils.getStandardFilePath("temp")

local conv
local ffmpeg
local qtfstart
-- local exiftool

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

---------------------- filename encoding routines ---------------------------------------------------------
--[[
function unblankFilename(str)
	if (str) then
		str = string.gsub (str, " ", "-")
	end
	return str
end 
]]

------------------------ initialie ---------------------------------------------------------------------------------

-- initialize: set serverUrl, loginPath and uploadPath
function PSConvert.initialize(PSUploaderPath)
	writeLogfile(4, "PSConvert.initialize: PSUploaderPath= " .. PSUploaderPath .. "\n")

	local convertprog = 'convert'
	local ffmpegprog = 'ffmpeg'
	local qtfstartprog = 'qt-faststart'

	if WIN_ENV  then
		local progExt = 'exe'
		convertprog = LrPathUtils.addExtension(convertprog, progExt)
		ffmpegprog = LrPathUtils.addExtension(ffmpegprog, progExt)
		qtfstartprog = LrPathUtils.addExtension(qtfstartprog, progExt)
	end
	
	conv = LrPathUtils.child(LrPathUtils.child(PSUploaderPath, 'ImageMagick'), convertprog)
	ffmpeg = LrPathUtils.child(LrPathUtils.child(PSUploaderPath, 'ffmpeg'), ffmpegprog)
	qtfstart = LrPathUtils.child(LrPathUtils.child(PSUploaderPath, 'ffmpeg'), qtfstartprog)

--[[
	-- exiftool is not required
	if  LrFileUtils.exists(exiftoolprog)  ~= 'file' then
		exiftool = nil 
	else
		exiftool = exiftoolprog
	end
]]
	writeLogfile(4, "PSConvert.initialize:\nconv: " .. conv .. "\nffmpeg: ".. ffmpeg .. "\nqt-faststart: " .. qtfstart)
	return true
end

---------------------- picture conversion functions ----------------------------------------------------------

-- convertPic(srcFilename, size, quality, unsharp, dstFilename)
-- converts a picture file using the ImageMagick convert tool
--[[
function PSConvert.convertPic(srcFilename, size, quality, unsharp, dstFilename)
	local cmdline = cmdlineQuote() .. 
				'"' .. conv .. '" "' .. srcFilename .. '" -resize ' .. shellEscape(size) .. ' -quality ' .. quality .. ' -unsharp ' .. unsharp .. ' "' .. dstFilename .. '"' ..
				cmdlineQuote()

	writeLogfile(4,cmdline .. "\n")
	if LrTasks.execute(cmdline) > 0 then
		writeLogfile(3,"... failed!\n")
		writeLogfile(1, "convertPic: " .. srcFilename .. " to " .. dstFilename .. " failed!\n")
		return false
	end

	return true
end
]]

-- convertPicConcurrent(srcFilename, convParams, xlSize, xlFile, lSize, lFile, bSize, bFile, mSize, mFile, sSize, sFile)
-- converts a picture file using the ImageMagick convert tool into 5 thumbs in one run
function PSConvert.convertPicConcurrent(srcFilename, convParams, xlSize, xlFile, lSize, lFile, bSize, bFile, mSize, mFile, sSize, sFile)
	local cmdline = cmdlineQuote() .. '"' .. conv .. '" "' .. srcFilename .. '" ' ..
			shellEscape(
				'( -clone 0 -define jpeg:size=' .. xlSize .. ' -thumbnail '  .. xlSize .. ' ' .. convParams .. ' -write "' .. xlFile .. '" ) -delete 0 ' ..
				'( +clone   -define jpeg:size=' ..  lSize .. ' -thumbnail '  ..  lSize .. ' ' .. convParams .. ' -write "' ..  lFile .. '" +delete ) ' ..
				'( +clone   -define jpeg:size=' ..  bSize .. ' -thumbnail '  ..  bSize .. ' ' .. convParams .. ' -write "' ..  bFile .. '" +delete ) ' ..
				'( +clone   -define jpeg:size=' ..  mSize .. ' -thumbnail '  ..  mSize .. ' ' .. convParams .. ' -write "' ..  mFile .. '" +delete ) ' ..
						   '-define jpeg:size=' ..  sSize .. ' -thumbnail '  ..  sSize .. ' ' .. convParams .. ' "' 	   ..  sFile .. '"'
			) .. cmdlineQuote()
	writeLogfile(4, cmdline .. "\n")
	if LrTasks.execute(cmdline) > 0 then
		writeLogfile(3,"... failed!\n")
		writeLogfile(1, "convertPicConcurrent: " .. srcFilename  .. " failed!\n")
		return false
	end

	return true
end

---------------------- video functions ----------------------------------------------------------

-- ffmpegGetAdditionalInfo(srcVideoFilename) ---------------------------------------------------------
--[[
	get the capture date, duration, resolution and aspect ratio of a video via ffmpeg. Lr won't give you this information
	returns:
		success			as boolean
		dateTimeOrig 	as unix timestamp
		duration 		in seconds
		dimension		as pixel dimension 'NxM'
		sar				as aspect ratio 'N:M' 
		dar				as aspect ratio 'N:M'
]]
function PSConvert.ffmpegGetAdditionalInfo(srcVideoFilename)
	-- returns DateTimeOriginal / creation_time retrieved via ffmpeg  as Cocoa timestamp
	local picBasename = LrPathUtils.removeExtension(LrPathUtils.leafName(srcVideoFilename))
	local outfile =  LrPathUtils.child(tmpdir, LrPathUtils.addExtension(picBasename .. '_ffmpeg', 'txt'))
	-- LrTask.execute() will call cmd.exe /c cmdline, so we need additional outer quotes
	local cmdline = cmdlineQuote() .. '"' .. ffmpeg .. '" -i "' .. srcVideoFilename .. '" 2> "' .. outfile .. '"' .. cmdlineQuote()

	writeLogfile(4, cmdline .. "\n")
	LrTasks.execute(cmdline)
	-- ignore errorlevel of ffmpeg here (is 1) , just check the outfile
	
	if not LrFileUtils.exists(outfile) then
		writeLogfile(3, "  error on: " .. cmdline .. "\n")
		return false
	end

	local ffmpegReport = LrFileUtils.readFile(outfile)
	writeLogfile(4, "ffmpeg report:\n" .. ffmpegReport)
	
	-------------- DateTimeOriginal: search for avp: 'creation_time : date' -------------------------
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
		writeLogfile(4, "  ffmpegDateTimeOrig: " .. LrDate.timeToUserFormat(dateTimeOrig, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
		dateTimeOrig = LrDate.timeToPosixDate(dateTimeOrig)
     end

	-------------- duration: search for avp: 'Duration: <HH:MM:ss.msec>,' -------------------------
	local durationString, duration = nil
	for v in string.gmatch(ffmpegReport, "Duration:%s+([%d%p]+),") do
		durationString = v
		writeLogfile(4, "durationString: " .. durationString .. "\n")
		-- translate from  HH:MM:ss.msec to seconds
		duration = 	tonumber(string.sub(durationString,1,2)) * 3600 +
					tonumber(string.sub(durationString,4,5)) * 60 +
					tonumber(string.sub(durationString,7,11))
		writeLogfile(4, string.format(" duration: %.2f\n", duration))
     end
	 
	-------------- resolution: search for avp like:  -------------------------
	-- Video: mjpeg (MJPG / 0x47504A4D), yuvj422p, 640x480, 30 tbr, 30 tbn, 30 tbc
	-- Video: h264 (Main) (avc1 / 0x31637661), yuv420p, 1440x1080 [SAR 4:3 DAR 16:9], 12091 kb/s, 29.97 fps, 29.97 tbr, 30k tbn, 59.94 tbc
	-- Video: h264 (Main) (avc1 / 0x31637661), yuv420p, 1920x1080 [SAR 1:1 DAR 16:9], 19497 kb/s, 28.70 fps, 30 tbr, 30k tbn, 60k tbc
	local w, x, dimension, sar, dar
	for v, w, x in string.gmatch(ffmpegReport, "Video:[%s%w%(%)/]+,[%s%w]+,%s+([%dx]+)%s*%[*%w*%s*([%d:]*)%s*%w*%s*([%w:]*)%]*,") do
		dimension = v
		sar = w
		dar = x
		writeLogfile(4, string.format("dimension: %s, sar: %s, dar: %s\n", dimension, ifnil(sar, '<Nil>'), ifnil(dar, '<Nil>')))
     end
	 
	 LrFileUtils.delete(outfile)

	 return true, dateTimeOrig, duration, dimension, sar, dar
end

-- ffmpegGetThumbFromVideo(srcVideoFilename) ---------------------------------------------------------
function PSConvert.ffmpegGetThumbFromVideo (srcVideoFilename, thumbFilename, dimension)
	local outfile =  LrPathUtils.replaceExtension(srcVideoFilename, 'txt')
	-- generate first thumb from video
	local cmdline = cmdlineQuote() ..
						'"' .. ffmpeg .. 
						'" -i "' .. srcVideoFilename .. 
						'" -y -vframes 1 -ss 00:00:01 -an -qscale 0 -f mjpeg -s ' ..
						dimension .. ' -aspect ' .. string.gsub(dimension, 'x', ':') .. 
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
function PSConvert.getConvertKey(height)
	
	for i = 1, #videoConversion do
		if height <= videoConversion[i].upToHeight then 
			return i, videoConversion[i].id
		end
	end

	return #videoConversion, videoConversion[#videoConversion].id

end

-- convertVideo(srcVideoFilename, aspectRatio, dstHeight, dstVideoFilename) --------------------------
--[[ 
	converts a video to an mp4 with a given resolution using the ffmpeg and qt-faststart tool
	srcVideoFilename	the src video file
	aspectRatio			aspect ration as N:M
	dstHeight			target height in pixel
	dstVideoFilename	the target video file
]]
function PSConvert.convertVideo(srcVideoFilename, aspectRatio, dstHeight, dstVideoFilename)
	local tmpVideoFilename = LrPathUtils.replaceExtension(LrPathUtils.removeExtension(dstVideoFilename) .. '_TMP', LrPathUtils.extension(dstVideoFilename))
	local outfile =  LrPathUtils.replaceExtension(tmpVideoFilename, 'txt')

	writeLogfile(3, string.format("convertVideo: srcVideo: %s aspectRatio %s, dstHeight: %d dstVideo: %s\n", srcVideoFilename, aspectRatio, dstHeight, dstVideoFilename))
	local arw = tonumber(string.sub(aspectRatio, 1, string.find(aspectRatio,':') - 1))
	local arh = tonumber(string.sub(aspectRatio, string.find(aspectRatio,':') + 1, -1))
	local dstWidth = dstHeight * arw / arh
	local dstDim = string.format("%dx%d", dstWidth, dstHeight)
	local dstAspect = string.format("%d:%d", dstWidth, dstHeight)
	writeLogfile(3, string.format("convertVideo: aspectRatio %d:%d, dstHeight: %d --> dstWidth: %d --> dim: %s ar: %s\n", arw, arh, dstHeight, dstWidth, dstDim, dstAspect))

	local encOpt
	if WIN_ENV then
		encOpt = '-acodec libvo_aacenc'
	else
		encOpt = '-strict experimental -acodec aac'
	end
	
	-- get the conversionParams
	local convKey = PSConvert.getConvertKey(dstHeight)
	writeLogfile(3, string.format("convertVideo: using conversion %d/%s (%dp)\n", convKey, videoConversion[convKey].id, videoConversion[convKey].upToHeight)) 
		
--	LrFileUtils.copy(srcVideoFilename, srcVideoFilename ..".bak")
	local cmdline =  cmdlineQuote() ..
				'"' .. ffmpeg .. '" -i "' .. 
				srcVideoFilename .. 
				'" -y ' .. encOpt .. ' ' ..
				videoConversion[convKey].pass1Params .. ' ' ..
				'-s ' .. dstDim .. ' -aspect ' .. dstAspect ..
				' "' .. tmpVideoFilename .. '" 2> "' .. outfile .. '"' ..
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
				'" -y ' .. encOpt .. ' ' ..
				videoConversion[convKey].pass2Params .. ' ' ..
				'-s ' .. dstDim .. ' -aspect ' .. dstAspect ..
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
					'"' .. qtfstart .. '" "' ..  tmpVideoFilename .. '" "' .. dstVideoFilename .. '" 2> "' .. outfile ..'"' ..
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
