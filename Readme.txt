PhotoStation Upload (Lightroom plugin)
======================================
Version 2.8
2015/02/27
Copyright(c) 2015, Martin Messmer

Description:
=============
PhotoStation Upload is a Lightroom ExportServiceProvider Plugin. It adds a new Export target "PhotoStation Upload" to the "Export" dialog that enables the export of pictures and videos from Lightroom directly to a Synology PhotoStation. It will not only upload the selected photos/videos but also create and upload all required thumbnails and accompanying additional video files.
This plugin uses the same converters and the same upload API as the official "Synology PhotoStation Uploader" tool, but will not use the Uploader itself. The upload API is http-based, so you have to specify the target PhotoStation by protocol (http/https) and servename (IP@, hostname, FQDN).

PhotoStation Upload supports two different upload methods:
	- flat upload: 
	  upload all selected pictures/videos to a named Album on the PhotoStation
	  The named Album must exist on the PhotoStation.
	  The root Album is defined by an empty string. In general, Albums are specified by "<folder>{/<folder>}" (no leading or trailing slashes required)
	- tree mirror upload: 
	  preserves the directory path of each photo/video relative to a given local base path on the PhotoStation below a named (existing) target Album.
	  All directories within the source path of the picture/video will be created recursively.
	  The directory tree is mirrored relative to a given local base path. Example:
	  Local base path:	C:\users\john\pictures
	  To Album:			Test
	  Photo to export:	C:\users\john\pictures\2010\10\img1.jpg
	  --> upload to:	Test/2010/10/img1.jpg
	  In other words:	<local-base-path>\<relative-path>\file -- upload to --> <Target Album>/<relative-path>/file

PhotoStation Upload can upload to the Standard PhotoStation or to a Personal PhotoStation. Make sure the Personal PhotoStation feature is enabled for the given Personal Station owner.

PhotoStation can optimize the upload for PhotoStation 6 by not uploading the THUMB_L thumbnail.

Important notice:
Passwords entered in the export settings are not stored encrypted, so they might be accessible by other plugins or other people that have access to your system. So, if you mind storing your password in the export settings, you may leave the password field in the export settings empty so that you will be prompted to enter username/password when the export starts.

Requirements:
=============
	- Windows OS or Mac, tested with:
		- Windows 7  Windows 8 
		- MacOS 10.7.5
		- MacOS 10.10
	- Lightroom 5, tested with:
		- tested with Lr 5.6(Mac) and Lr 5.7 (Mac and Win)
	- Synology PhotoStation, tested with:
		PhotoStation 6
	- Synology PhotoStation Uploader, required components:
		- ImageMagick/convert.exe
		- ffmpeg/ffmpeg.exe
		- ffmpeg/qt-faststart.exe
	
Features:
=========

Version 2.2 (initial public release):
-------------------------------------
- Generic upload features:
	- support for http and https
	- support for non-standard ports (specified by a ":portnumber" suffix in the servername setting)
	- support for pathnames incl. blanks and non-standard characters (e.g.umlauts) (via url-encoding)
	- uses the following PhotoStation http-based APIs:
		- Login
		- Create Folder
		- Upload File
	- supports the PhotoStation upload batching mechanism
	- optimization for PhotoStation 6 (no need for THUM_L)

- Folder management
	- support for flat copy and tree copy (incl. directory creation)

- Upload of Photos to PhotoStation:
	- upload of Lr-rendered photos
	- generation (via ImageMagick convert) and upload of all required thumbs

- Upload of Videos to PhotoStation:
	- upload of Lr-rendered videos 
	- generation (via ffpmeg and ImageMagick convert) and upload of all required thumbs
	- generation (via ffpmeg) and upload of a PhotoStation-playable low-res video
	- support for "DateTimeOriginal" for videos on PhotoStation 

Version 2.3:
------------
- Fixed various (!!) installation / initialization bugs
- Fixed strange field validation behaviour in Export Dialog
- Fixed mis-aligned input fields in Export Dialog
- Added Loglevel configuration to Export Dialog section
- Added: "Goto Logfile" on failures
- Modified thumbnail creation to the "Syno PS Uploader" way:
	slightly slower but higher thumbnail quality (less sharp) (Hint from Uwe)
- Added option "Create Album, if needed"
- Added completion bezel

Version 2.4:
------------
- Export Dialog re-design with lots of tooltips
- Support for small (Synology old-style) and large thumbnails (Synology new-style)

Version 2.5:
------------
- Configurable thumbnail generation quality (in percent)
- Target album not required in preset; prompt for it before upload starts, if missing 

Version 2.6:
------------
- video upload completely reworked
- support for DateTimeOriginal (capture date) in uploaded video
- support for videos with differen aspect ratios (16:9, 4:3, 3:2, ...) 
	- recognizes the video aspect ratio by mpeg dimension tag and by mpeg dar (display aspect ratio) tag
	- generate thumbnails and videos in correct aspect ratio
- support for uploading of original videos in various formats:
	- if file is '*.mp4', no conversion required, otherwise the original video has to be converted to mp4
- support for uploading of an additional mp4-video in a different (lower) resolution:
	- additional video resolution is configurable separately different original video resolutions
- fixed video conversion bug under MacOS (2.6.4)
- fixed mis-alignment of other export sections (2.6.5)
- note: make sure to select "Include Video" and Format "Original" in the Video settings section 
	to avoid double transcoding and to preserve	the DateTimeOriginal (capture date) in the uploaded video

Version 2.7:
------------
- Bugfix for failed upload when filename includes ( or ), important only for MacOS
- Quicker (15%) upload for PS6 by not generating the unneeded Thumb_L

Version 2.8:
------------
Added video rotation support 
- soft-rotated videos (w/ rotation tag in mpeg header) now get the right (rotated) thumbs
- hard-rotation option for soft-rotated videos for better player compatibility:
  Soft-rotated videos are not rotated in most players, PhotoStation supports soft-rotated videos only by 
  generating an additional hard-rotated flash-video. This may be OK for small videos, but overloads 
  the DiskStation CPU for a period of time. 
  Thus, it is more desirable to hard-rotate the videos on the PC before uploading.
  Hard-rotated videos with (then) potrait orientation work well in VLC, but not at all in MS Media Player. 
  So, if you intend to use MS Media Player, you should stay with the soft-rotated video to see 
  at least a mis-rotated video. In all other cases hard-rotation is probably more feasable for you.
- support for "meta-rotation":
  If you have older mis-rotated videos (like I have lots of from my children's video experiments), 
  these videos typically don't have a rotation indication. So, the described hard-rotation support 
  won't work for those videos. To circumvent this, the Uploader supports rotation indications by
  metadata maintained in Lr. To tag a desired rotation for a video, simply add one of the following 
  keywords to the video in Lr:
	Rotate-90	--> for videos that need 90 degree clockwise rotation
	Rotate-180	--> for videos that need 180 degree rotation
	Rotate-270	--> for videos that need 90 degree counterclockwise rotation
- support for soft-rotation and hard-rotation for "meta-rotated" (see above) videos 
		
Installation:
=============
- unzip the downloaded archive
- copy the subdirectory "PhotoStation_upload.lrplugin" to the machine where Lightroom is installed
- In Lightroom:
	File --> Plugin Manager --> Add: Enter the path to the directory 
		"PhotoStation_upload.lrplugin" 

Open issues:
============
- issue in PhotoStation: if video aspect ratio is different from video dimension 
  (i.e. sample aspect ratio [sar] different from display aspect ratio [dar]) 
  the galery thumb of the video will be shown with a wrong aspect ratio (= sar)

Copyright:
==========
Copyright(c) 2015, Martin Messmer

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
