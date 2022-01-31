Photo StatLr Changelog
======================
Version 7.2.0
-------------
### Bugfixes:
- Photos:
  - Fixed an upload exception for MacOS: in fact, uploading was disabled by mistake for MacOS since 7.0.0, now it is enabled
  - Fixed issue #56 (Login error 402), which was introduced in Version 7.1.1</br>
  - Use the correct username in cache when uploading to Personal Area
  - Log the correct Photos error code / error message when upload failed
  - Fixed an exception when uploading photos to root folder
  - Fixed a cache logging issue when uploading to the personal area
  - Fixed an exception when 'Show Photo in Photo Server' was called for a photo in the root folder

Version 7.1.1
-------------
### Bugfixes:
- All PhotoServers:
  - Fixed issue #55
  - Make sure exiftool is started only if an exif translation (faces, color label, rating label) is configured and supported
### Changes:
- Photos:
  - Added error messages for Synology error codes 100 - 150 and 400 - 411
  - Reduced Syno.API.Info query from 'all' to 'SYNO.API.,SYNO.Foto.,SYNO.FotoTeam.'
  - Removed unused parameters from Login API call

Version 7.1.0
-------------
### New features:
- All PhotoServers:
  - Export/Publish Service dialog: 
    - Added PhotoSever-specific validation of servername
    - Visibility of 'Owner of Personal Area' is now PhotoServer-specific:Photos does not support uploading to the personal area of a different user
- Synology Photos:
  - Added support for Photos API access via alternative port or alias path (as configured in DSM -> Control Panel -> Login Portal -> Applications)
### Changes:
  - Readme: Updated description and screenshot of Export/Publish Service dialog
- Less logging (up to TRACE) during initialization, if Loglevel is set to 'Ask me later'
- Sort Photos: avoid Login to Photo Server, if sorting is not possible or required
### Bugfixes:
- All PhotoServers:
  - Fixed an issue where publishing w/ mode 'CheckExisting' would stop after detecting a photo or its folder being missing on the photo server
- Photos: 
  - Filenames (not folder names) are now handles case-insensitive due to Photos's file handling strategy
  - Published Collection Settings: Location Tag settings are no longer visible
  - Fixed an issue where publishing w/ mode 'MetadataUpload' would not upload modified caption/description or rating
  - Various bugfixes concerning the internal cache

Version 7.0.0
-------------
This is the first alpha release that supports both Synology Photo Station and Synology Photos (DSM7). While the PhotoStation support has been tested quite thoroughly, support for Synology Photos is quite fresh and might not have been tested in all common scenarios. So, the aplha attribute mostly refers to the Synology Photos support. 

Since the feature set and the API of Synology Photos is quite different to the Photo Station API and some of the real cool features of Photo Station are not or not yet supported, some of the cool features of Photo StatLr are also not available for Synology Photos. 

### New Features for Photo Station and Synology Photos:
- Publish: Delete empty folders after Normal Upload<br>
  Empty folders might occure due to photos being moved to another target folder. Until now, empty folders were only removed after deleting photos or collections or when using publish mode MovePhotos

Following is a non-comprehensive list of Photo StatLr features for Synology Photos:
### Export Features:
- Upload of photos with or without accompanying thumbnails
- Overwriting of existing photos
- Upload of videos (accompamying videos w/ lower resolution are currently not supported)
- Creation of folders and folder hierarchies on Photos, if required
- Flat or tree-mirror upload mode
- Upload to Shared Space or Personal Space
### Publish Features:
- Delete photos / videos, if no longer in Published Collection
- Delete Empty Folders after deleting or moving photos/videos
- Show Photo in Synology Photos (this will fail the first time, if the Browser session is not yet authenticated)
- Show Published Collection Album in Synology Photos
- Upload Modes:
  - Upload: Normal Upload of photos/videos
  - MetadataUpload: Upload only Metadata for photos/videos already uploaded:
    - Description
    - Tags / Keywords
    - Rating
    - Rating Tags('*' - '*****'): only useful for Photos 1.0 (w/o native rating support)
    - Color Label Tags('+red', '+green',...)
  - CheckExisting: no upload, just check if photo/video is already there
  - MovePhotos: move photos/videos in Photos if moved locally or target folder was changed
- Metadata Download:
  - Description
  - Tags / Keywords
  - Rating (native) or Rating Tags('*' - '*****'): only useful for Photos 1.0 (w/o native rating support)
  - Color Label Tags('+red', '+green',...)

Version 6.9.5
-------------
- Video conversion: dropped support for qt-faststart (no longer available on MacOS)
- Bugfix for Metadata Download (issue #51):
	Fixed incorrect pattern matching for label tags and rating tags: added or removed tags conaining '+' or'*' would be handled incorrectly (ignored) during Metadata Download even if downloading of label tags and rating tags was disabled
- Avoid compiler warnings: do not escape '/' in patterns

Version 6.9.4
-------------
- Use rendition:uploadFailed() to generate a Lr-compliant message box for the list of failed uploads 

Version 6.9.3
-------------
- Bugfix for video upload of Non-MP4s (Thanks to Daniel Hoover for reporting and chasing this bug)
	- Fixed an issue where a temporary video file wasn't deleted immediately after upload but only after the whole Publish process was done. 
	This could lead to a 'no space left on device' issue when publishing a lot of Non-MP4 videos in one go.
- Fixed the following two exceptions, when a 'no space left on device' situation occurs (Thanks to Daniel, again):
	- "An internal error has occurred: [string "PSConvert.lua"]:439: bad argument #1 to 'match' (string expected, got nil)"
	- "Internal error: '[string "PSUploadAPI.lua"]:156: attempt to perform arithmetic on local 'fileSize' (a nil value)'"

Version 6.9.2
-------------
- Bugfix for broken Sort Album function (broken since v6.5.0).

Version 6.9.1
-------------
- Bugfix for an exception during video upload caused by missing date info in video header (e.g. videos produced with Shotcut)

Version 6.9.0
-------------
- DJI Mavic video support:
  - support for DJI Mavic's GPS metadata notation (missing '/' after gps values)
  - support for videos w/o audio streams (e.g. the DJI Mavic 'raw' videos): since PS would ignore those videos, the plugin now checks for the existence of the audio stream and will add a silent audio stream if missing  
- Bugfix for exception '(string "PSExiftoolApi.lua"):344: bad argument #8 to 'format' (number expected , got nil)' 

Version 6.8.7
-------------
- Bugfix: Fixed broken video hard-rotation also for videos with embedded rotation tag for ffmpeg >= 3.3.x (see issue #43)
- No more support for ffmpeg < 4.x - older versions may or may not work, depending or used codec and rotation features

Version 6.8.6
-------------
- Bugfix: Fixed broken Video hard-rotation (see issue #42) 
- Added documentation folder and included Wiki posts 

Version 6.8.5
-------------
- Bugfix: Fixed an issue where an invalid/malformed video conversion presets file might cause an exception in Lr 8.x

Version 6.8.4
-------------
- Bugfix: Fixed an issue where MetadataUpload mode would not correctly upload captions or descriptions with special characters in it

Version 6.8.3
-------------
- Bugfix: Fixed exception '[string "PSDialogs.lua"]:305:bad argument #1 to len(string expected, got nil)' 
when openening a Published Collection that was saved with Location Tags enabled, but no separator specified.
- Published Collection settings dialog: disable fields also if predecessor field is blank 

Version 6.8.2
-------------
- Merged video conversion preset "Small-QSV" (support for Intel QuickSync) from stepman0 to default video presets file 

Version 6.8.1
-------------
- Bugfix: Fixed an issue where the plugin could not be loaded on MacOS, exception:<br>
"PSPluginInfoProvider.lua:120: bad argument #2 to 'addExtension' (string expected, got nil)"

Version 6.8.0
-------------
- __Video Conversion__:
	- Improved video quality and speed through changing from 2-pass ABR to 1-pass CRF conversion method
	- Support for configurable video quality for original and additional videos
	- Support for forced video conversion of original video
	- Support for user-definable video conversion presets 
	- Support for configurable conversion input and output options such as HW acceleration options
	- Configurable ffmpeg program path
- Upload file timestamp: added 'Mixed' setting (upload timestamp for photos, capture timestamp for videos)
- Bugfixes:
	- Fixed an issue where the Export dialog would exit with an Lr error message "AgPreferemces: can't store ..." when the Export provider was changed to Photo StatLr
	- Fixed an issue where the pass-2 Metadata Upload (Location Tag or Metadata for videos) would fail
	- Fixed an issue where the last Location Tag settings were not saved between two Exports. 
- This and that:
	- Moved version history from README to CHANGELOG (now order from latest to oldest)

Version 6.7.1
-------------
Fixes an issue where the Export (not Publishing) of a photo with enabled Location Tag translation fails.

Version 6.7
-----------
- Added configurable __upload file timestamp__: capture date or upload date
- Added metadata translation for __Location tags__: you can define how the Lr location tags are combined to a single PS Location tag<br>
Uploading of the combined PS Location tag is done during a second MetadataUpload pass.
- Bugfixes: 
	- Fixed an issue where the __{LrCC}__ placeholder with a matching pattern would only evaluate the first contained collection of a photo. 
Thanks to Gildas Marsaly for not only reporting the bug but also offering a patch!

Version 6.6
-----------
- Added publish mode __'MetadataUpload'__
- Video Metadata Upload: 
    - __GPS coords stored in Lr__ (not in the video itself) will now be uploaded. Lr GPS coords take precedence over GPS coords stored in the video. 
	- Lr __metadata privacy settings__ configured in the Export/Publish Service settings (e.g.'Remove Person Info') will be honored now
- Face region translations:
    - photos with __named and unnamed face regions__ will now be handled correctly: unnamed regions will be dropped, named regions will keep the correct name
	- __cropped photos__ will now be handled correctly
	- photos in __DNG format__ will now be handled correctly
- Update check now uses https

Version 6.5
-----------
- Support for mirroring of Published Collection Set hierarchies via metadata placeholder __'{LrPC:...}'__<br>
  Contributed by Filip Kis

Version 6.4
-----------
- Added support for Utra High Definition (4k) Videos:
	- Added a Custom Video Output Preset (shown in the "Video" section of the Export/Publish Service dialog) that enables the upload of rendered videos with original resolution. This is useful in particular for 4k Videos, because Lr supports upload of rendered videos only up to FullHD resolution
	- Added a seperate config setting for additional videos for UHD videos with the Export/Publish Service dialog
- Show current processed image as caption in the progess bar

Version 6.3
-----------
- Added support for __download of public comments__ from Photo Station (comments added to a public Shared Album in Photo Station)
- Configurable download options for private and/or public comments (downloading public comments is much faster than downloading private comments)
- Added plugin metadata for comments:  this allows to __search for or filter photos with comments__
- Added __Metadata tagsets__ that include Photo StatLr's comment metadata
- Added pattern matching for metadata placeholder {LrCC}: extract parts from the Contained Collection path or name
- Bugfixes:
	- Fixed an exception when a public Shared Album was modified to a private Shared Album
	- Fixed an issue where Shared Album keyword synonyms were not handled correctly
	- Fixed an issue where a comment that was removed in PS was not removed in Lr 

Version 6.2
------------
- Added	metadata placeholder __{LrRM:\<key\> \<extract pattern\>}__ to retrieve (an extract of) any metadata supported by Lightroom SDK: LrPhoto - photo:getRawMetadata(key)<br>
This placeholder was introduced in particular to support the following features:
	- __{LrRM:uuid}__ may be used in 'Rename to' to retrieve a unique, fixed, never changing identifier for any photo in the Lr catalog
	- __{LrRM:stackPositionInFolder ^1([^%d]*)$|?}__ may be used in 'Rename to' to prevent the upload of any photo burried in a stack (not the top-most photo in a stack)    
 
Version 6.1
------------
- Added __"Photo Station 6.6"__ as configurable Photo Station version
- __Removed__ setting "Generate Thumbs __For PS 6__", setting is now derived from configured Photo Station version 
- Photo Station Shared Album management: You may define a __password for the public share__ (requires Photo 6.6 or above)
- Added translations for various listboxes

Version 6.0
------------
- Added __Photo Station Shared Album__ management: Define __Shared Album keywords__ under "Photo StatLr" | "Shared Albums" | "\<Publish Service Name\>" and assign them to photos you want to link to Photo Station Shared Albums.
  As soon as you publish the respective photos (using Publish mode "Upload" or "CheckExisting") via the given \<Publish Service\>, they will be linked to or removed from the given Shared Albums
- Fully localizable version: a German and (partially) Korean translation is available. If you like to see your name in the Plugin, please contribute a translation file. Instructions for translation file contribution can be found in __[this Wiki article](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/wiki/Contributions:-How-to-contribute-a-translation-for-Photo-StatLr.)__!  
- In case of an plugin exception:
	- the progress bar will be removed
	- the exception text will be copied to the logfile
- Other minor bugfixes 

Version 5.10
------------
- Added metadata placeholder __{Path:\<level\> \<extract pattern\>}__ to retrieve the (extract of the) \<level\>st directory name of the photo's pathname.<br>

Version 5.9
-----------
- Added __Rename Photos To__ to achieve a unique naming schema for photos in the target album.<br>
  This also allows to merge photos with same names from different sub folder into a single target album.    
- Extended metadata placeholders of type {LrFM:key} to include an extract pattern:<br>
  __{LrFM:key \<extractPattern\>}__<br>
  The extract pattern (a Lua regex pattern which optional captures) allows to extract specific parts from the given metadata key
- Change the automatic renaming of virtual copies in the target album:<br>
  Before virtual copies got a suffix of the last 3 digits of the photo UUID, now they get the copy name as suffix    

Version 5.8
-----------
- Added __Default Collection__ handling: the Default Collection now serves as template for all new Published (Smart) Collections within the same Publish Service.  
- Bugfix for "Convert all photos": This bug was introduced in V5.4.0

Version 5.7
-----------
- Added new publish mode "MovePhotos" to move photo remotely in the Photo Station instead of deleting the photo at the old location and re-generating thumbs and uploading the photos again
- Addes download mode setting (Yes, No, Ask me later)
- Bugfixes / improvements:
	- Fixed a bug where after deleting photos from a Published Collection the DeleteEmptyAlbum routine was called multiple times for albums with a '-' in the path
	- Avoid the call of doExifTranslations when there is nothing to translate
	- Fixed a bug where RAW/DNG photos could not be uploaded from MacOS (due to a mis-configured program path for the dcraw tool)
	- Raised the timeout for uploading metadata for videos from 30 sec to 60 sec
	- Fixed an issue where one or more upload task would fail with an exception ("PSUtilities, 331: attempt to compare nil with number") when doing multiple upload tasks in parallel  

Version 5.6
-----------
- Support for __download of (native) rating__ for photos and videos from __Photo Station 6.5__ and above<br>
- Performance improvement __(up to 10 times faster)__ for publish mode __CheckExisting__ and __download of title, caption, rating and gps__ through introduction of a local Photo Station album cache

Version 5.5
-----------
- Support for __GPS info download__ for photos and videos<br>
GPS coords can be added in Photo Station via the Location Tag panel: enter a location name / address and let Google look up the coords (blue pin) or position a red pin in the map view via right-click. Photo Station will write red pin coords also to the photo itself. Red pin coords have preference over blue pin coords when downloading GPS info. 

Version 5.4
-----------
- Support for __GPS info upload for videos__. GPS info will be read __from Lr GPS tag__ and __from the video itself__. Videos w/ embedded GPS info (e.g __GoPro, iPhone6__) will be uploaded w/ GPS info to PS GPS tag, even though Lr does not support GPS info in videos.
If GPS info is availabe both in the video and in Lr (manually tagged), Lr GPS info has precedence.<br>
GPS upload will respect the metadata privacy settings in the metadata section of the Export / Publish Service dialog.
- Support for __person tags download__ is now also available __for RAW photos and rotated photos__. For RAW photos, the face region metadata are now written to the XMP side-car file (not to the RAW file itself), which is the correct place for all additional metadata. 
Face regions for rotated photos are now correctly back rotated. 
Face region download is not possible for virtual copies, since it would overwrite the metadata in the original photo.<br> Face region download is also __not possible for cropped photos__ due to an import incompatibility of Lr: Lr will not accept face regions from XMP for a cropped photo which was written there by Lr itself. :-(
- Sync PS general tags w/ __Lr keyword hierarchies and synonyms__
- Respect __"Include on Export"__ setting for Lr keywords when synching with PS general tags
- Support for __adding hierarchical keywords from PS__:<br>
Use '|' as delimiter for keywords, e.g. 'animal|bird|eagle'  

Version 5.3
-----------
- Support for __person tags download__ (face regions) to original photo (requires reloading the photo in Lr)
- Download: when Label is not selected for download,  Label tags (e.g. '+green') in PS will not be download as Lr keywords 
- Download: when Rating is not selected for download,  rating tags (e.g. '***') in PS will not be download as Lr keywords 
- Upload: Photo title is now also added as PS title tag on upload
- Bugfixes:
	- Rejected photos due to missing photo title was fixed
	- An exception in case of exporting (not publishing) of a video was fixed
	- An exception in case of two parallel plugin threads running was fixed 

Version 5.2
-----------
- Download of __title__
- Support for __metadata__ upload and download for __videos__  
- Introduced a strict '__Do not delete metadata__ in Lr when downloading from Photo Station__' policy 

Version 5.1
-----------
- Added "Convert all photos" to General Settings in Plugin Manager section

Version 5.0
-----------
- Plugin renamed to __Photo StatLr__ using a new icon
- Added metadata translation for Lr __color labels__ to PS general tag like __'+green', '+red',__ etc.
- Support for __Add comment__ to Published Photo and __Get Comments/Get ratings__ (optional) from Published Collection<br>
  This requires some more data in the published photo objects, therefore published photos need to be converted once to the new format in order to support this feature
- Publish Mode: __CheckMoved__ is now also available for Collection with dynamic target album definitions (i.e. including metadata placeholder)
- New Publish Mode: __Convert__ to convert published photos to V5.0 format to enable Get Comments and Get Ratings
- __Download of metadata__: description, general tags__  
- __Download and translation of special general tags: color label, rating__
- Configuration of __program install paths__ (Syno Uploader and exiftool) is now moved to the Plugin general settings in __Plugin Manager__ dialog
- Error output of convert, dcraw and exiftool are now redirected to the logfile
- Error output of JSON decoder is now redirected to the logfile instead of a message box popping up
- Bugfixes:
	- Adjustments for __Show in Photo Station__
	- Fixes for __Update Check__
  
Version 4.0
-----------
- __FileStation API no longer required: yeah, finally got rid of it!___
- Support for photo __sort order__ of Published Collections in Photo Station album on __flat uploads__
- Support for __RAW+JPG to same Album__
- '__Delete__ Photos in Published Collection' and 'Delete Published Collection' will now __remove empty albums__ on Photo Station
- Support for mirroring of local Collection Set hierarchies via metadata placeholder '{LrCC:...}'
- __Video__ Upload will now __delete__ the video in PS __before uploading__ the new video(s):<br>
	PhotosStation would otherwise keep old versions of the video which were uploaded before
- Logfile handling:
	- now includes Loglevel of messages
	- will now be truncated at the beginning of a session if logfile is older than 5 minutes 
- Bugfixes:
	- Metadata placeholder {Date ..} is now more robust: will also find DateTimeDigitized and other alternative timestamps if DateTimeOriginal is missing
	- Processed videos will now be uploaded with the correct filename extension

Version 3.7
------------
- Support for __metadata placeholders__ in __target album__ definitions (Export, Published Collection, Published Collection Set):
	- {Date \<format\>} for capture date/time (dateTimeOriginal) related metadata
	- {LrFM:\<key\>} for any metadata supported by Lightroom SDK: LrPhoto - photo:getFormattedMetadata(key)
- __Show in Photo Station__ now works for Published Photos, Collections and Collection Sets.<br>
  Will not work for Collections and Collection Sets that include metadata placeholders in the target album definition.	
- __Standard timeout__ for Photo Station communication (for Login, album creation) is now __configurable__ in Export/Publish dialog.
- Timeout calculation for uploads is now calculated based on a minimum of 10 MBit/s (was 24MBit/s before).
- Video upload:
	- besides .mp4 files now also __.m4v__ files are handle as natively supported by Photo Station, thus need __no conversion__.
	- any __not natively supported video format__ (e.g. .avi, .mov, .3gp) will be converted to .mp4 format and now be __uploaded in addition__ to the original video (rather than replacing the original video)
	- Bugfix: video dimensions will always be even integers. When videos are rotated or scaled (e.g. when additional video upload is configured), it could happen the the resulting width was an odd integer, which was not supported by ffmpeg.
	- Bugfix: thumb from video will be extracted at 00:00:00 sec for videos shorter than 4 seconds, otherwise at 00:00:03. Upload of video with duration < 1 sec failed in earlier versions due to failed thumb extraction ( at 00:00:01). 
	
Version 3.6
------------
- Support for Published Collection Sets:
	- Published Collection Sets may be associated with a target dir (format: dir{/subdir}). The target dir will be inherited by all child collections or collection sets
	- Published Collection Sets may be nested to any level
- Modified Metadata trigger for Published Collections: now any metadata change (incl. rating) will trigger a photo state change to "To be re-published"
  __Important Note__: It is likely, that a bunch of photos will change to state "To be re-published" due to the modified trigger definition. Please make sure __all photos__ of all your collections are in state __"Published" before updating__ from older versions to V3.6.x! This allows you to identify which photos are affected by this change and you may then use __"Check Existing" to quickly "re-publish"__ those photos.

- Use of '\'  is now tolerated in all target album definitions

Version 3.5
------------
- Support for Lr and Picasa face detection/recognition:<br>
Translation of the Lr/Picasa face regions to PhotoStatio Face regions / Person tags
- Support for star ratings ( * to ***** ): <br>
Translation of the XMP-rating tag to Photo Station General * tags
- Support for Photo-only Upload

Version 3.4
------------
- Second server address configurable also for Export
- FileStation API access optional for Publish:<br>
Until v3.3 FileStation API access was required for any Publish operation mode. So, if you wanted to use the Publish functionality via Internet, the FileStation had to be accessible via Internet.
Since most of us don't feel comfortable with the idea of opening the admin port of the diskstation to the Internet, publishing via Internet wasn't really an option. 
Now, you may use choose to __disable FileStation API use for the Internet access__ case.
Publish mode 'Check Existing', photo deletion and photo movement will not be possible via Internet then, but you will be able at least to __upload photos using the Publish service via Internet__. Hey, that's better than nothing, isn't it?
- Publish: Delete after Upload<br>
The order or Publish tasks was rearranged, so that you may use the Publish function via Internet w/o being stopped by photos that need to be deleted, but cannot be deleted due to disabled FileStation access (see above).
- 'Check Existing' is 4 times faster than before:<br>
A directory read cache speeds up the check for photos in Photo Station. The actual speed advantage is depending on how your photo collections are organized in your Photo Station. any kind of chronological directory structure will work fine, since Lr is processing photos in chronological order. 

Version 3.3
------------
- Support for upload of TIFF and DNG file format to Photo Station
- 3.3.2: Support for upload of varous RAW file formats (when uploading original photos):<br>
  3FR, ARW, CR2, DCR, DNG, ERF, MEF, MRW, NEF, ORF, PEF, RAF, RAW, RW2, SR2, X3F
	
Version 3.2
------------
- Configurable thumbnail sharpening (see issue #3)<br>
Note: thumbnail sharpening is independent of photo sharpening which may be configured seperately in the appropriate Lr Export/Publish dialog section.

Version 3.1
------------
- Support for photos w/ different colorspaces (see issue #4)

Version 3.0
------------
Added Publish mode

Version 2.8
------------
Added video rotation support: 
- soft-rotated videos (w/ rotation tag in mpeg header) now get the right (rotated) thumbs
- hard-rotation option for soft-rotated videos for better player compatibility
- support for "meta-rotation"
- support for soft-rotation and hard-rotation for "meta-rotated" (see above) videos 
		
Version 2.7
------------
- Bugfix for failed upload when filename includes '( 'or ')', important only for MacOS
- Quicker (15%) upload for PS6 by not generating the Thumb_L which is not uploaded anyway

Version 2.6
------------
- video upload completely reworked
- support for DateTimeOriginal (capture date) in uploaded video
- support for videos with differen aspect ratios (16:9, 4:3, 3:2, ...) 
	- recognizes the video aspect ratio by mpeg dimension tag and by mpeg dar (display aspect ratio) tag
	- generate thumbnails and videos in correct aspect ratio
- support for uploading of original videos in various formats:
	- if file is '\*.mp4', no conversion required, otherwise the original video has to be converted to mp4
- support for uploading of one additional mp4-video in a different (lower) resolution:
	- additional video resolution is configurable separately for different original video resolutions
- fixed video conversion bug under MacOS (2.6.4)
- fixed mis-alignment of other export sections (2.6.5)
- note: make sure to select "Include Video" and Format "Original" in the Video settings section 
	to avoid double transcoding and to preserve	the DateTimeOriginal (capture date) in the uploaded video

Version 2.5
------------
- Configurable thumbnail generation quality (in percent)
- Target album not required in preset; prompt for it before upload starts, if missing 

Version 2.4
------------
- Export Dialog re-design with lots of tooltips
- Support for small (Synology old-style) and large thumbnails (Synology new-style)

Version 2.3
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

Version 2.2 (initial public release)
-------------------------------------
- Generic upload features:
	- support for http and https
	- support for non-standard ports (specified by a ":portnumber" suffix in the servername setting)
	- support for pathnames incl. blanks and non-standard characters (e.g.umlauts) (via url-encoding)
	- uses the following Photo Station http-based APIs:
		- Login
		- Create Folder
		- Upload File
	- supports the Photo Station upload batching mechanism
	- optimization for Photo Station 6 (no need for THUM_L)

- Folder management
	- support for flat copy and tree copy (incl. directory creation)

- Upload of Photos to Photo Station:
	- upload of Lr-rendered photos
	- generation (via ImageMagick convert) and upload of all required thumbs

- Upload of Videos to Photo Station:
	- upload of original or Lr-rendered videos 
	- generation (via ffpmeg and ImageMagick convert) and upload of all required thumbs
	- generation (via ffpmeg) and upload of a Photo Station-playable low-res video
	- support for "DateTimeOriginal" for videos on Photo Station 

