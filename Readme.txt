PhotoStation Upload (Lightroom plugin)
======================================
Version 2.4
2015/02/10
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
Password entered in the export settings are not stored encrypted, so the might be accessible by other plugin or other people that have access to your system. So, if you mind storing your password in the export settings, you may leave the password field in the export settings empty so that you will be prompted to enter username/password when the export starts.

Requirements:
=============
	- Windows OS or Mac, tested with:
		- Windows 7 (fully compatible)
		- Mac OS-X ? (problems with videos)
	- Lightroom 5, tested with:
		- tested with Lr 5.6(Mac) and Lr 5.7 (Win)
	- Synology PhotoStation, tested with:
		PhotoStation 6
	- Synology Assistant or Synology PhotoStation Uploader, required components:
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

Installation:
=============
- unzip the downloaded archive
- move subdirectory "PhotoStation_upload.lrplugin" to machine where Lightroom is installed
- In Lightroom:
	File --> Plugin Manager --> Add: Enter the path to the directory 
		"PhotoStation_upload.lrplugin" 

Open issues:
============
- Videos couldn't be exported on Mac, got an error on ffmpeg phase 1 conversion

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

