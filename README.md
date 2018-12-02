Photo StatLr (Lightroom plugin)
======================================
Version 6.6.0<br>
__[Important note for updating to V3.6.x and above](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/releases/tag/v3.6.0)__<br>
__[Important note for updating to V5.0 and above](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/releases/tag/v5.0.0)__<br>

[Release Notes](https://github.com//flingo64/PhotoStation-Upload-Lr-Plugin/releases)<br>
[FAQs](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/wiki)<br>

Forum threads: 
- [English Synology forum](http://forum.synology.com/enu/viewtopic.php?f=17&t=96477)
- [German Synology forum](http://www.synology-forum.de/showthread.html?62754-Lightroom-Export-Plugin-PhotoStation-Upload)

[Support Page](https://messmer-online.de/index.php/software/11-photo-statlr)<br>
[Donate to a good cause](https://messmer-online.de/index.php/software/donate-for-photo-statlr)<br>
[Get involved: Let Photo StatLr speak your language](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/wiki/Contributions:-How-to-contribute-a-translation-for-Photo-StatLr.)<br>
 
Copyright(c) 2018, Martin Messmer<br>

Overview
=========
Photo StatLr (aka PhotoStation Upload) is a Lightroom Publish and Export Service Provider Plugin. It adds a new Publish Service and an Export target called "Photo StatLr" to the "Publish Services" panel / "Export" dialog. 
Both the Publish service as well as the Export service enable the export of photos and videos from Lightroom directly to a Synology Photo Station. It will not only upload the selected photos/videos but also create 
and upload all required thumbnails and accompanying additional video files.<br>
Photo StatLr also supports the Lightroom "Get Comments" and "Get Rating" feature which will download comments and ratings from Photo Station to the Lightroom Comments panel (Library mode: bottom right panel).
Besides that Photo StatLr can do a real two-way synchronization of various metadata, including title, description/caption, tags/keywords, color label, rating, person tags/faces regions and GPS info. 

This plugin uses the same converters and the same upload API as the official "Synology Photo Station Uploader" tool, but does not use the Uploader itself. The Photo Station API is http-based, so you have to specify the target Photo Station by protocol (http/https) and servename (IP@, hostname, FQDN).

Requirements
=============
* OS (Windows or Mac OS X):
	- Windows 7
	- Windows 8.0, 8.1
	- Windows 10
	- MacOS X 7.5
	- MacOS X 8.5
	- MacOS X 9.5	
	- MacOS X 10.2, 10.3, 10.4, 10.5 
	- MacOS X 11.0, 11.1, 11.2, 11.3, 11.4, 11.5, 11.6
	- MacOS X 12.0, 12.1, 12.2, 12.3, 12.4, 12.5, 12.6
	- MacOS X 13.0, 13.1, 13.2, 13.3, 13.4
* Lightroom: 
  	- Lr 4.2, 4.3, 4.4, 4.4.1
	- Lr 5.0, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.7.1 
	- Lr 6.0, 6.0.1, 6.1, 6.1.1, 6.2, 6.2.1, 6.3, 6.4, 6.5, 6.5.1, 6.6, 6.6.1, 6.7, 6.8, 6.9, 6.10, 6.10.1, 6.12, 6.13, 6.14
	- Lr Classic 7.0, 7.1, 7.2, 7.3, 7.3.1, 7.4, 7.5
	- Lr Classic 8.0
* Synology Photo Station:
	Photo Station 5, Photo Station 6, 6.5, 6.6, 6.7, 6.8
* For local thumbnail generation and for video upload: Synology Photo Station Uploader, required components:
	- ImageMagick/convert(.exe)
	- ImageMagick/dcraw.exe (Win) or dcraw/dcraw (MacOS)
	- ffmpeg/ffmpeg(.exe)
	- ffmpeg/qt-faststart(.exe)
* For Metatdata translations (e.g Lr/Picasa face regions, ratings and color labels):
	- exiftool: Version 10.0.2.0 (tested) and later should be fine
	
Installation
=============
- install Synology Photo Station Uploader, if not already done
- install exiftool (see credits below), if not already done<br>
  On Windows, __don't use "Run this program as administrator"__ setting (otherwise a command box will open everytime it is used and the plugin will not be able to get the output from exiftool)!<br>
  On Windows, use __'exiftool.exe'__ instead of __'exiftool(-k).exe'__ as program name (otherwise the plugin can't terminate the exiftool background process when done)! 
- unzip the downloaded archive
- copy the subdirectory "PhotoStation_upload.lrplugin" to the machine where Lightroom is installed
- In Lightroom:
	*File* --\> *Plugin Manager* --\> *Add*: Enter the path to the directory 
		"PhotoStation_upload.lrplugin" 
![](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/blob/master/Screenshots-Windows/01-Install-Plugin.jpg)
 - Select the 'Photo StatLr' plugin, open the section 'General Settings' and make sure the paths to the required tools are correct.
 ![](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/blob/master/Screenshots-Windows/03-Install_OK.jpg)

Description
============

Export vs. Publish Service - general remarks
---------------------------------------------
Exporting in Lightroom is a simple one-time processe: you define the photos to export by selecting the photos or folders to export in library view and then choose "Export". 
Lightroom does not keep track of exports, thus if you want to re-export changed or added photos or remove deleted photos form the target (e.g. a Photo Station album) later, you will have to keep track yourself for those changes, addtions or deletions.

Publishing in Lightroom on the other hand is meant for synchonizing local photo collections with a remote target (e.g. a Photo Station album). To publish a photo collection you have to do two things:

- define the settings for the Publish Service
- define the Published Collection and the settings for that Published Collection

As soon as you've done this, Lightroom will keep track of which photo from the collection has to been published, needs to be re-published (when it was modified locally) or deleted. 
Besides that basic functions, some publish services can also re-import certain infos such as tags, comments or ratings back from the publish target.

Export vs. Publish Service - Photo StatLr
-------------------------------------------------
The main functionality of Photo StatLr is basicly the same in Export and in Publish mode: uploading pictures/videos to a Synology Photo Station. 
On top of this the Publish mode also implements the basic publishing function, so that Lr can keep track of added, modified and deleted photos/videos.<br>
As of V5.0.0 Photo StatLr also supports downloading of certain metadata, so that changes to photos in Photo Station can be synched back to Lightroom. 

Due to the different handling of exporting and publishing in Lightroom the Export and the Publish dialog of Photo StatLr have some but not all of their settings in common. 

### Export Dialog
The Export dialog includes settings for:

a) the target Photo Station (server, login, Standard/Personal Photo Station)<br>
b) target Album within the target Photo Station and Upload method<br>
c) quality parameters for thumbs and additional videos<br>
![](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/blob/master/Screenshots-Windows/05-Export_Tree_StandardPS.jpg)

### Publish Service Dialog
The Publish Service dialog on the other hand includes settings for:

a) the target Photo Station (server, login, Standard/Personal Photo Station)<br>
b) -- no --<br>
c) quality parameters for thumbs and additional videos<br>
![](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/blob/master/Screenshots-Windows/10-Publish-Services.jpg)

### Collection Settings
The Album settings ( b) ) are not stored within the Publish settings but within the Published Collections settings. Therefore, you don't need to define a different Publish Service for each Published Collection you want to publish. In most cases you will only have one Publish Service definition and a bunch of Published Collections below it. An additional Publish Service definition is only required, if you want to upload to a different Photo Station or if you want to use different upload quality settings.<br>
![](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/blob/master/Screenshots-Windows/11-Publish-Collection.jpg)

Export Funtionality
--------------------
- Upload to the __Standard Photo Station__ or to a __Personal Photo Station__<br>
(make sure the Personal Photo Station feature is enabled for the given Personal Station owner)
- Definition of a __secondary server address__<br>
You may want to publish to your Photo Station from at home or via the Internet. 
Therefore, the Export/Publish Service dialog lets you define two server addresses, with one of them being active. 
This eases the consistent definition of the Export/Publish settings for both access paths.  

- __Two different upload methods__:
	- __Flat Upload__:<br> 
	  This method uploads all selected pictures/videos to a named Album (use the folder name, not the Album name) on the Photo Station
	  The named Album may exist on the Photo Station or may be created during export
	  The root Album is defined by an empty string. In general, Albums are specified by "\<folder\>{/\<folder\>}" (no leading or trailing slashes required)
	- __Tree Mirror Upload__:<br> 
	  This method preserves the directory path of each photo/video relative to a given local base path on the Photo Station below a named target Album.
	  All directories within the source path of the picture/video will be created recursively.
	  The directory tree is mirrored relative to a given local base path. Example:<br>
	  Local base path:	C:\users\john\pictures<br>
	  To Album:			Test<br>
	  Photo to export:	C:\users\john\pictures\2010\10\img1.jpg<br>
	  --\> upload to:	Test/2010/10/img1.jpg<br>
	  In other words:	\<local-base-path\>\\\<relative-path\>\\file -- upload to --\> \<Target Album\>/\<relative-path\>/file<br>

- __Dynamic Target Album__ definition by using  __metadata placeholders__:<br>
	Metadata placeholders are evaluated for each uploaded photo/video, so that the actual target album may be different for each individual photo/video.
	Metadata placeholders can be used to define a metadata-based Photo Station album layout, which is completely independent of the local directory layout.
	Metadata placeholders can also be used to define a Photo Station album layout, which is identical to an existing Collection Set hierarchy.
	Metadata placeholders look like:<br>
	  - {Date %Y}
	  - {Date %Y-%m-%d}
	  - {LrFM:cameraModel}
	  - {LrFM:isoRating}
	  - {LrRM:uuid}
	  - {Path:5}
	  - {LrCC:path ^Yearly Collections}
	  - {LrCC:name}
	  - {LrPC:name}<br>
  To learn more about the use of metadata placeholders and how they work, take a look at the [Wiki](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/wiki/Publish-and-Export:-How-to-use-metadata-placeholders-in-'Target-Album'-or-'Rename-Photos-To'-definitions) 

- __Rename photos__ in target album using __metadata placehoders__:<br>
     Rename photos to a unique naming schema in the target album 

- __Photo-plus-Thumbnail Upload__ (default) for faster Photo Station fill-up and to minimize load on the diskstation  

- __Photo-only Upload__ (optional) for a faster Upload:<br>
	This upload option makes sense, when you have a fast diskstation and you want the diskstation to do the thumbnail generation. 
	It also makes sense to upload w/ Photo-only option when you don't need the thumbnails on the diskstation (e.g. upload photos for backup purpose) and you upload to an un-indexed folder, so that no thumb conversion will be done on the diskstation. 
	Important note: It is not possible to keep already uploaded thumbs and just upload the photo itself. When you use the photo-only option, any belonging, already existing thumb on the diskstation will be removed! (Sorry, I wish I could do better)  

- __Optimize the upload for Photo Station 6__ by not generating/uploading the THUMB_L thumbnail.

- Upload of __photo metadata__ including title, description, keywords and gps info (from Lr or video header)

- __Metadata translations on upload:__<br>
	- Translation of __Face regions__ generated by Lr or Picasa face detection to Photo Station Person tags (useful for Photo Station below version 6.5)<br>
	- Translation of __Star Rating (* to *****)__  to Photo Station General tags (useful for Photo Station below version 6.5)<br>
	- Translation of __Color Label (yellow, red, etc.)__  to Photo Station General tags(+yellow, +red, etc.) <br>

- Upload of __original or processed videos__ and accompanying videos with a lower resolution__

- Upload of __video metadata__ including title, description, keywords, rating, label and gps info (both from Lr or video header) 

- __Different video rotation options:__<br>
	- __Hard-rotation for soft-rotated videos__ for better player compatibility:<br>
	  Soft-rotated videos (portrait videos) are typically stored as as landscape video marked w/ a rotation flag in the mpeg header. Most player do not support this kind of rotation, so you will see the video unrotated / landscape. 	  Photo Station supports soft-rotated videos only by generating an additional hard-rotated flash-video.  This may be OK for small videos, but overloads the DiskStation CPU for a period of time.  Thus, it is more desirable to hard-rotate the videos on the PC before uploading.<br>
	  Hard-rotated videos with (then) potrait orientation work well in VLC, but not at all in MS Media Player. So, if you intend to use MS Media Player, you should stay with the soft-rotated video to see at least a mis-rotated video. 	In all other cases hard-rotation is probably more feasable for you.
	- __Soft-rotation or Hard-rotation for "meta-rotated" videos__:<br>
	  If you have older (e.g. .mov or .avi) __mis-rotated videos__ (like I have lots of from my children's first video experiments), these videos typically have __no rotation indication in the video header__. Thus, the described hard-rotation support won't work for those videos.<br> 
	  To overcome this, the Uploader supports rotation indication via metadata maintained in Lr. 
	  To inidicate the desired rotation for a video, simply add one of the following __keywords__ to the video in __Lr__:
		- __Rotate-90__		--\> for videos that need 90 degree clockwise rotation
  		- __Rotate-180__	--\> for videos that need 180 degree rotation
		- __Rotate-270__	--\> for videos that need 90 degree counterclockwise rotation
	  Meta-rotated videos may be soft-rotated (by adding the rotation flag in the uploaded mp4-video) or hard-rotated.<br>
	  Please note, that if you use meta-rotation, the (soft- or hard-) rotated video will be uploaded as MP4 video, instead of the original video, which may have a different format/coding (e.g. .mov/mjpeg).<br>
![](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/blob/master/Screenshots-Windows/09-Video-Meta-to-Hard-Rotation.jpg)

- Processed __RAW+JPG to same Album__:<br>
	Most cameras support RAW+JPG output, where both files have the same basename, but different extensions (e.g. .rw2 and -jpg). If for any reason you wish to upload processed versions of both files, both files would map to the same upload filename (*.jpg) and
	thus override each others during upload. To circumvent this collision, this option will rename all non-jpg files to <orig-filename><orig-extension>.jpg.   


Publish Functionality:
---------------------

![](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/blob/master/Screenshots-Windows/12-Publish-Action.jpg)

- All Export Functions are supported in Publish mode

- Support for __Published Collections and Published Smart Collections__ 

- Support for __Published Collection Sets__
 
- __Different Publish modes__ (Published Collection dialog):
	- __Upload__:<br>
 	  Upload unpublished photos to target Album in target Photo Station. This is the expected normal publish method.
	- __MetadataUpload__:<br>
	  Upload only modified metadata (title, description, rating, color label, keywords/tags, GPS coords, face regions) to Photo Station. This publish mode is useful when photos have been tagged, but not edited after the last publishing, because uploading of metadata is must faster than uploading of a photo plus its thumbnails. Note, that the plugin cannot identify whether the photo was edited (has modified development settings) or just tagged. So, if you use this publish mode for an edited photo, only the modified tags will be uploaded to Photo Station, but not the changed photo itself. 
	- __CheckExisting__:<br>
  	  Unpublished or To re-publish photos will not be uploaded, but will be checked whether they already exist in the target Album and if so, set them to 'Published'. 
  	  This operation mode is useful when initializing a new Published Collection: if you have exported the latest version of thoses photos before to the defined target but not through the newly defined Published Collection (e.g. via Export).
	  CheckExisting is approx. 50 times faster (__~ 15 photos/sec__) than a normal Publish, since no thumbnail creation and upload is required.
  	  Note, that CheckExisting can not determine, whether the photo in the target Album is the latest version.
	- __CheckMoved__:<br>
	  Check if any photo within a Published Collection has moved locally and if so, mark it 'To re-publish'
	  If your Published Collection is to be tree-mirrored to the target Album, it is important to notice when a photo was moved locally between directories, since these movements have to be propagated to the target Album (i.e., the photo has to be deleted at the target Album at its old location and re-published at the new location).
	  Unfortunately, Lightroom will not mark moved photos for 'to Re-publish'. Therefore, this mode is a workaround for this missing Lr feature. To use it, you have to set at least one photo 'To re-publish', otherwise you won't be able to push the "Publish" button.
	  CheckMoved is very fast (__\>100 photos/sec__) since it only checks locally whether the local path of a photo has changed in comparison to its published location. There is no communication to the Photo Station involved.<br>
	- __MovePhotos__:<br>
  	  Unpublished and 'To re-publish' photos will not be uploaded, but will be moved within the Photo Station in case their current upload path is different from the upload path that would apply if they would be uploaded now. This mode is good for various scenarios:<br>
  	  a) After uploading photos to a specific target album (flat copy) you decide to change the target album for those photos<br>
  	  b) After uploading photos using the tree copy mode you decide to move those photos locally to a different directory (you may use CheckMoved to find those photos)<br>
  	  c) After uploading photos to a dynamic target album (using metadata placeholders) any of the referenced metadata has changed.   
  	  Photos not yet published will remain Unpublished. The MovePhotos mode avoids re-generating and uploading of thumbs and thus is faster than a normal upload.
	- __Convert__:<br>
	  This mode is used to convert photos in a an old-style (e.g. \<5.0.0) Published Collection to Published Collection which supports comments and ratings (v.5.0.0 and above)<br>
	- __Ask me later__:<br>
	  This is not a publish mode itself but let's you postpone the publish mode decision to the point in time where the actual publish action is started (e.g. when you click the "Publish" button)<br>
![](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/blob/master/Screenshots-Windows/13-AskMeLater.jpg)

- Impose __sort order of photos in Lr Published Collections__ in Photo Station:<br>
	Sort order is only supported on Published Collections w/ Custom Sort Order when uploaded as Flat Copy 

- __Deletion of published photos__, when deleted locally (from Collection or Library)

- __Deletion of complete Published Collections__

- __Deletion of empty Photo Station Albums__ after deletion of published photos or complete Published Collections

- Settings of a __Default Collection__ will serve as default for new Published Collection within the same Publish Service<br> 
  Using the Default Collection you can define your own collection setting defaults instead of using the plugin's defaults.<br> 
  __Note:__ When you create a new Photo StarLr Publish Service Lr will create a first Published Collection called "Default Collection". The Default collection is typically shown in italics.
  You may rename the Default Collection and use it for normal publishing. 
  Default Collections in Publish Services created with Photo StatLr __before v5.8.0__ however will __not__ be shown in __italics__ and may have been __moved__ to a Collection Set or even have been __removed__ completely. 
  To identify the Default Collection, just edit an existing Published Collection: the name of the Default Collection will be shown in the header section of the dialog.
  If the Default Collection has been removed before (this was possible in Photo StatLr befor v5.8.0) there is no way to create a new Default Collection for that Publish Service.     

- Manage __Photo Station Shared Albums__ via Shared Album keyword hierarchies in Lr:<br>
  Define Shared Album keywords under "Photo StatLr" | "Shared Albums" | "\<Publish Service Name\>" and assign them to photos you want to link to Photo Station Shared Albums.
  As soon as you publish the respective photos (using Publish mode "Upload" or "CheckExisting") via the given \<Publish Service\>, they will be linked to or removed from the given Shared Albums.<br>
  You may define whether a Shared Album should be public (default) or private (using __keyword synonym 'private'__)<br>
  You may define a __password__ for a public Shared Album (using __keyword synonym 'password:\<AlbumPassword\>'__) (requires Photo Station 6.6 or above)<br>
  For more infos please read the [Wiki article](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/wiki/Publish:-Managing-Photo-Station-Shared-Albums-in-Lightroom-via-Photo-StatLr).
![](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/blob/master/Screenshots-Windows/14-ManageSharedAlbums.jpg)
  
Download / Sync Functionality:
-------------------------------
- Support for download of __Comments__
	- Download of private and public comments from Photo Station
	- Lr plugin metadata for comments: __search and filter__ photos with comments<br>
	- __Metadata Tagsets__ to view comments in the Metadata panel<br>
	For more infos please read the [Wiki article on comments](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/wiki/Some-comments-on-comments).

  ![](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/blob/master/Screenshots-Windows/15-Comment-Metadata.jpg)

- __Download and two-way sync of various metadata__ for photos and videos:
	- title, description/caption
	- rating (for Photo Station 6.5 and above)
	- general tags (Keywords)
	- GPS info (added via Location Tag)
	- sync PS keywords with Lr keyword hierarchies and synonyms
	- support for adding hierachical keywords (format: {<keyword>|}keyword) from PS to Lr 
 	- Translation of __Star Rating tags (* to *****)__  to Lr rating (useful for Photo Station below version 6.5)<br>
	- Translation of __Color Label tags (+yellow, +red, etc.)__  to Lr color label <br>
	- Translation of __Person tags__  to Lr face regions (requires reloading of photo metadata from file)<br>
	
- __Different Download modes__:
	- __Yes__:<br>
	  Download of the configured metadata items will start immediately after a publish action or when you click "Refresh Comments".<br>
	- __No__:<br>
	  Download of the configured options will be suppressed. This mode is good to temporarily disable the download of the configued metadata items while keeping the download option configuration itself.<br>
	- __Ask me later__:<br>
	  This is not a download mode itself but let's you postpone the download mode decision to the point in time where the actual download action is started (e.g. after a publish action or when you click the "Refresh Comments" button).
	  This mode is useful if you do not want to download metadata after every publish action, but only occasionally.<br>

- For more detail, please read the [Wiki article on metadata two-way sync](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/wiki/Publish:-Some-words-on-the-two-way-sync-of-metadata)

Additional Funtionality
------------------------
- __Checks for updates__ in background when Exporting, Publishing or opening the Plugin section in the Plugin Manager no more than once per day.
  If a new version is available, you'll get an info message after the Export/Publish and also a note in the Plugin Manager section.
  The update check will send the following information to the update server:
	- Photo StatLr plugin version
	- Operating system version
	- Lightroom version
	- Lightroom language setting
	- a random unique identifier chosen by the update service<br>

This helps me keep track of the different environments/combinations the plugin is running in.

Important note
--------------
Passwords entered in the export settings are not stored encrypted, so they might be accessible by other plugins or other people that have access to your system. So, if you mind storing your password in the export settings, you may leave the password field in the export settings empty so that you will be prompted to enter username/password when the export starts.

Open issues
============
- issue in Photo Station: if video aspect ratio is different from video dimension 
  (i.e. sample aspect ratio [sar] different from display aspect ratio [dar]) 
  the galery thumb of the video will be shown with a wrong aspect ratio (= sar)
- due to missing Lr SDK support for face region handling, face regions downloaded from Photo Station will be written to the original file (or xmp side-car file in case of RAW photos) and wil have to be manually re-synched w/ Lr. 
Face regions can't be downloaded for cropped photos, since Lr won't accept the face region metadata if the "AppliedDimension" are not equal to the original photo dimension.
- Face regions added via XMP re-import are not properly synched w/ Lr's database: if you change or delete one of those in Lr, it won't be reflected in the XMP of the photo file. 
    
History
=======

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

Version 2.4
------------
- Export Dialog re-design with lots of tooltips
- Support for small (Synology old-style) and large thumbnails (Synology new-style)

Version 2.5
------------
- Configurable thumbnail generation quality (in percent)
- Target album not required in preset; prompt for it before upload starts, if missing 

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

Version 2.7
------------
- Bugfix for failed upload when filename includes '( 'or ')', important only for MacOS
- Quicker (15%) upload for PS6 by not generating the Thumb_L which is not uploaded anyway

Version 2.8
------------
Added video rotation support: 
- soft-rotated videos (w/ rotation tag in mpeg header) now get the right (rotated) thumbs
- hard-rotation option for soft-rotated videos for better player compatibility
- support for "meta-rotation"
- support for soft-rotation and hard-rotation for "meta-rotated" (see above) videos 
		
Version 3.0
------------
Added Publish mode

Version 3.1
------------
- Support for photos w/ different colorspaces (see issue #4)

Version 3.2
------------
- Configurable thumbnail sharpening (see issue #3)<br>
Note: thumbnail sharpening is independent of photo sharpening which may be configured seperately in the appropriate Lr Export/Publish dialog section.

Version 3.3
------------
- Support for upload of TIFF and DNG file format to Photo Station
- 3.3.2: Support for upload of varous RAW file formats (when uploading original photos):<br>
  3FR, ARW, CR2, DCR, DNG, ERF, MEF, MRW, NEF, ORF, PEF, RAF, RAW, RW2, SR2, X3F
	
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

Version 3.5
------------
- Support for Lr and Picasa face detection/recognition:<br>
Translation of the Lr/Picasa face regions to PhotoStatio Face regions / Person tags
- Support for star ratings ( * to ***** ): <br>
Translation of the XMP-rating tag to Photo Station General * tags
- Support for Photo-only Upload

Version 3.6
------------
- Support for Published Collection Sets:
	- Published Collection Sets may be associated with a target dir (format: dir{/subdir}). The target dir will be inherited by all child collections or collection sets
	- Published Collection Sets may be nested to any level
- Modified Metadata trigger for Published Collections: now any metadata change (incl. rating) will trigger a photo state change to "To be re-published"
  __Important Note__: It is likely, that a bunch of photos will change to state "To be re-published" due to the modified trigger definition. Please make sure __all photos__ of all your collections are in state __"Published" before updating__ from older versions to V3.6.x! This allows you to identify which photos are affected by this change and you may then use __"Check Existing" to quickly "re-publish"__ those photos.

- Use of '\'  is now tolerated in all target album definitions

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
  
Version 5.1
-----------
- Added "Convert all photos" to General Settings in Plugin Manager section

Version 5.2
-----------
- Download of __title__
- Support for __metadata__ upload and download for __videos__  
- Introduced a strict '__Do not delete metadata__ in Lr when downloading from Photo Station__' policy 

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

Version 5.5
-----------
- Support for __GPS info download__ for photos and videos<br>
GPS coords can be added in Photo Station via the Location Tag panel: enter a location name / address and let Google look up the coords (blue pin) or position a red pin in the map view via right-click. Photo Station will write red pin coords also to the photo itself. Red pin coords have preference over blue pin coords when downloading GPS info. 

Version 5.6
-----------
- Support for __download of (native) rating__ for photos and videos from __Photo Station 6.5__ and above<br>
- Performance improvement __(up to 10 times faster)__ for publish mode __CheckExisting__ and __download of title, caption, rating and gps__ through introduction of a local Photo Station album cache

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

Version 5.8
-----------
- Added __Default Collection__ handling: the Default Collection now serves as template for all new Published (Smart) Collections within the same Publish Service.  
- Bugfix for "Convert all photos": This bug was introduced in V5.4.0

Version 5.9
-----------
- Added __Rename Photos To__ to achieve a unique naming schema for photos in the target album.<br>
  This also allows to merge photos with same names from different sub folder into a single target album.    
- Extended metadata placeholders of type {LrFM:key} to include an extract pattern:<br>
  __{LrFM:key \<extractPattern\>}__<br>
  The extract pattern (a Lua regex pattern which optional captures) allows to extract specific parts from the given metadata key
- Change the automatic renaming of virtual copies in the target album:<br>
  Before virtual copies got a suffix of the last 3 digits of the photo UUID, now they get the copy name as suffix    

Version 5.10
------------
- Added metadata placeholder __{Path:\<level\> \<extract pattern\>}__ to retrieve the (extract of the) \<level\>st directory name of the photo's pathname.<br>

Version 6.0
------------
- Added __Photo Station Shared Album__ management: Define __Shared Album keywords__ under "Photo StatLr" | "Shared Albums" | "\<Publish Service Name\>" and assign them to photos you want to link to Photo Station Shared Albums.
  As soon as you publish the respective photos (using Publish mode "Upload" or "CheckExisting") via the given \<Publish Service\>, they will be linked to or removed from the given Shared Albums
- Fully localizable version: a German and (partially) Korean translation is available. If you like to see your name in the Plugin, please contribute a translation file. Instructions for translation file contribution can be found in __[this Wiki article](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/wiki/Contributions:-How-to-contribute-a-translation-for-Photo-StatLr.)__!  
- In case of an plugin exception:
	- the progress bar will be removed
	- the exception text will be copied to the logfile
- Other minor bugfixes 

Version 6.1
------------
- Added __"Photo Station 6.6"__ as configurable Photo Station version
- __Removed__ setting "Generate Thumbs __For PS 6__", setting is now derived from configured Photo Station version 
- Photo Station Shared Album management: You may define a __password for the public share__ (requires Photo 6.6 or above)
- Added translations for various listboxes

Version 6.2
------------
- Added	metadata placeholder __{LrRM:\<key\> \<extract pattern\>}__ to retrieve (an extract of) any metadata supported by Lightroom SDK: LrPhoto - photo:getRawMetadata(key)<br>
This placeholder was introduced in particular to support the following features:
	- __{LrRM:uuid}__ may be used in 'Rename to' to retrieve a unique, fixed, never changing identifier for any photo in the Lr catalog
	- __{LrRM:stackPositionInFolder ^1([^%d]*)$|?}__ may be used in 'Rename to' to prevent the upload of any photo burried in a stack (not the top-most photo in a stack)    
 
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

Version 6.4
-----------
- Added support for Utra High Definition (4k) Videos:
	- Added a Custom Video Output Preset (shown in the "Video" section of the Export/Publish Service dialog) that enables the upload of rendered videos with original resolution. This is useful in particular for 4k Videos, because Lr supports upload of rendered videos only up to FullHD resolution
	- Added a seperate config setting for additional videos for UHD videos with the Export/Publish Service dialog
- Show current processed image as caption in the progess bar

Version 6.5
-----------
- Support for mirroring of Published Collection Set hierarchies via metadata placeholder __'{LrPC:...}'__<br>
  Contributed by Filip Kis

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

Copyright
==========
Copyright(c) 2018, Martin Messmer

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

Credits
=======
Photo StatLr uses the following phantastic free software to do its job:
- convert(.exe),		see: http://www.imagemagick.org/
- dcraw(.exe),			see: https://www.cybercom.net/~dcoffin/dcraw/ (by David J. Coffin)
- ffmpeg(.exe), 		see: https://www.ffmpeg.org/
- qt-faststart(.exe), 	see: http://multimedia.cx/eggs/improving-qt-faststart/
- JSON.lua				see: http://regex.info/blog/lua/json (by Jeffrey Friedl)
- exiftool(.exe)		see: http://www.sno.phy.queensu.ca/~phil/exiftool/ (by Phil Harvey)

Thanks to all you folks providing these real valuable software gems. This plugin would be nothing without it!

Thanks for contributing code to the project:
	- Filip Kis (metadata placeholder {LrPC})

Thanks for the amazing, astounding, boooor-ing quotes from:
http://www.imdb.com/character/ch0000704/quotes ;-)
