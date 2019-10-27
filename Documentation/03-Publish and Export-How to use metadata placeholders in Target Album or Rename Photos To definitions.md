## General notes
Metadata placeholders are used to define a __Metadata-based PhotoStation Album layout__ or a __Metadata-based Photo renaming schema__, which may be completely different from the local folder layout within the Lightroom Library or the photo's local filename. 
They can be used anywhere within a **Target Album** or **Rename Photos To** definition, which can be found in the "**Export**" dialog, the "**Published Collection**" and the "**Published Collection Set**" definition. Placeholders are evaluated during export/publish for each processed photo/video, so that the actual target album and/or target filename depends on the photo's attributes and may be different for each processed photo/video.<br>

Placeholders look like:<br>
__{\<category\>:\<type\> \<options\>|\<default value\> or ?}__<br>
Depending on the specific placeholder the \<type\> or \<options\> may be missing. The part beginning with the '|' is also optional.
If the __actual value__ of a placeholder __cannot be determined__ for a photo, the following rules apply for the substitution:
- if the placeholder defines __no default value ({...})__, placeholder is substituted by "" (empty string)
- if the placeholder defines a __Default Value ({...|Default Value})__, placeholder is substituted by the default value
- if the placeholder defines a metadata that is __Required ('{...|?}__, placeholder is substituted by '?' and uploading is prevented

Here are some examples substitutions for a photo without the metadata 'Foobar' (in fact, I don't even know the metadata Foobar):
- __{Foobar}__	--\> ""
- __{Foobar|John Doe}__ --\> "John Doe"
- __{Foobar|?}__		--\> "?", won't be uploaded

## Metadata Placeholders
Following is the list of metadata placeholders, not showing the above mentioned general substitution options 'Default Value' and 'Required':<br>
* __{Date \<format\>}__: Capture Date<br>
where __\<format\>__ is a date-time format string that may contain the following special strings representing various date elements:<br>
__%B, %b, %m, %d, %e, %j, %y, %Y, %H, %1H, %I, %1I, %M, %S, %p, %P, %%__<br><br>
This placeholder will be substituted by the specified date elements of the capture date (DateTimeOriginal) of the processed photo/video.<br>
For a detailed description of the special formating strings, please refer to the documentation of the<br>
__[Lightroom SDK 6](http://www.adobe.com/devnet/photoshoplightroom/sdk/eula_lr6.html): LrDate.timeToUserFormat()__ ((c) by Adobe Systems Incorporated).<br>

* __{Path:\<level\>}__<br>
 __{Path:\<level\> \<extract pattern\>}__<br>
where __\<level\>__ is a number <br>
and __\<extract pattern\>__ is a Lua regular expression with zero or one capture.<br><br>
This placeholder will be substituted by the (extract of the) \<level\>st directory name of the photo's pathname.<br>
For a detailed description of the Lua regular expression syntax, please refer to:<br>
__[Lua pattern](http://www.lua.org/manual/5.2/manual.html#6.4.1)__ .<br>

* __{LrFM:\<key\>}__: Lightroom Formatted Metadata<br> 
  __{LrFM:\<key\> \<extract pattern\>}__: Lightroom Formatted Metadata extract<br> 
where __\<key\>__ is a valid Lightroom formatted metadata key<br>
and __\<extract pattern\>__ is a Lua regular expression with zero or one capture.<br>
__\<key\>__ may be any of the following strings:<br>
__keywordTags, keywordTagsForExport, fileName, copyName, folderName, fileSize, fileType, rating, label, title, caption, dimensions, croppedDimensions, exposure, shutterSpeed, aperture, brightnessValue, exposureBias, flash, exposureProgram, meteringMode, isoSpeedRating, focalLength, focalLength35mm, lens, subjectDistance, dateTimeOriginal, dateTimeDigitized, dateTime, cameraMake, cameraModel, cameraSerialNumber, artist, software, gps, gpsAltitude, creator, creatorJobTitle, creatorAddress, creatorCity, creatorStateProvince, creatorPostalCode, creatorCountry, creatorPhone, creatorEmail, creatorUrl, headline, iptcSubjectCode, descriptionWriter, iptcCategory, iptcOtherCategories, dateCreated, intellectualGenre, scene, location, city, stateProvince, country, isoCountryCode, jobIdentifier, instructions, provider, source, copyright, copyrightState, rightsUsageTerms, copyrightInfoUrl, personShown, nameOfOrgShown, codeOfOrgShown, event, additionalModelInfo, modelAge, minorModelAge, modelReleaseStatus, modelReleaseID, com.adobe.imageSupplierImageId, maxAvailWidth, maxAvailHeight, sourceType, propertyReleaseID, propertyReleaseStatus, digImageGUID, plusVersion__<br><br>
This placeholder will be substituted by the specified formatted metadata of the processed photo/video. If an extract pattern is given, then the metadata will be matched against the pattern and the respective matched pattern or capture (if given) will be extracted.<br>
For a detailed description of the meaning of the keys, please refer to the documentation of the<br>
__[Lightroom SDK 6](http://www.adobe.com/devnet/photoshoplightroom/sdk/eula_lr6.html): LrPhoto - photo:getFormattedMetadata()__ ((c) by Adobe Systems Incorporated).<br>
For a detailed description of the Lua regular expression syntax, please refer to:<br>
__[Lua pattern](http://www.lua.org/manual/5.2/manual.html#6.4.1)__ .<br>

* __{LrRM:\<key\>}__: Lightroom Raw Metadata<br> 
  __{LrRM:\<key\> \<extract pattern\>}__: Lightroom Raw Metadata extract<br> 
where __\<key\>__ is a valid Lightroom raw metadata key<br>
and __\<extract pattern\>__ is a Lua regular expression with zero or one capture.<br>
__\<key\>__ may be any of the following strings:<br>
__fileSize, rating, shutterSpeed, aperture, exposureBias, flash, isoSpeedRating, focalLength, focalLength35mm, dateTimeOriginal, dateTimeDigitized, dateTime, gpsAltitude, countVirtualCopies, isVirtualCopy, countStackInFolderMembers, isInStackInFolder, stackInFolderIsCollapsed, stackPositionInFolder, colorNameForLabel, fileFormat, width, height, aspectRatio, isCropped, dateTimeOriginalISO8601, dateTimeDigitizedISO8601, dateTimeISO8601, lastEditTime, editCount, copyrightState, uuid, path, isVideo, durationInSeconds, pickStatus, trimmedDurationInSeconds, locationIsPrivate, gpsImgDirection__<br><br>
This placeholder will be substituted by the specified raw metadata of the processed photo/video. If an extract pattern is given, then the metadata will be matched against the pattern and the respective matched pattern or capture (if given) will be extracted.<br>
For a detailed description of the meaning of the keys, please refer to the documentation of the<br>
__[Lightroom SDK 6](http://www.adobe.com/devnet/photoshoplightroom/sdk/eula_lr6.html): LrPhoto - photo:getRawMetadata()__ ((c) by Adobe Systems Incorporated).<br>
For a detailed description of the Lua regular expression syntax, please refer to:<br>
__[Lua pattern](http://www.lua.org/manual/5.2/manual.html#6.4.1)__ .<br>

* __{LrCC:path|name}__: Lightroom Contained Collection<br> 
__{LrCC:path|name \<extract pattern\>}__<br>
where __\<extract pattern\>__ is a Lua regular expression with zero or one capture.<br>
This placeholder may be used to mirror an existing Standard Collection Set hierarchy to the PhotoStation<br>
The placeholder will be substituted by the name or the hierarchy path of the first Standard Collection that contains the processed photo and matches the optional extract pattern. The hierarchy path is built by concatenating the names of all parent Collection Sets and Collection itself seperated by '/' (just like a Linux pathname without leading and trailing '/'). If an extract pattern is given, then the metadata will be matched against the pattern and the respective matched pattern or capture (if given) will be extracted.<br>
Make sure, that all photos in your (Smart) Published Collection using this placeholder are either member of exactly one Standard Collection or that your match pattern will identify exactly one containing collection for each photo. Otherwise the result of the substitution will be un-deterministic.<br><br>
__Note__: Collection and Collection Set names may include characters that are illegal within a pathname. Therefore, all __illegal characters will be substituted by their hexadecimal ascii value__ as string '0xnn'. Illegal characters are:<br>
       __\ / : ? * " < > |__<br>
Due to a bug (as of Aug. 2017) in the Photo Station Upload API (error when uploading a photo a second time) the following characters should also be avoided:<br>
      __[ ]__<br>
__Second note__: Photo StatLr will not be notified by Lightroom if a photo was moved from one collection to another or was removed from a collection. This means, you'll have to take care by yourself to re-publish photos that were moved to or removed from a collection after initial publishing.<br>
__Third note__: This placeholder only works for __Standard Collections, not for Smart Collections__.<br>

* __{LrPC:path|name}__: Lightroom Published Collection<br> 
__{LrPC:path|name \<extract pattern\>}__<br>
where __\<extract pattern\>__ is a Lua regular expression with zero or one capture.<br>
This placeholder may be used to mirror an existing Published Collection Set hierarchy to the PhotoStation<br>
The placeholder will be substituted by the name or the hierarchy path of the Published Collection of the processed photo. The hierarchy path is built by concatenating the names of all parent Published Collection Sets and Published Collection itself seperated by '/' (just like a Linux pathname without leading and trailing '/'). If an extract pattern is given, then the metadata will be matched against the pattern and the respective matched pattern or capture (if given) will be extracted.<br>
__Note__: Collection and Collection Set names may include characters that are illegal within a pathname. Therefore, all __illegal characters will be substituted by their hexadecimal ascii value__ as string '0xnn'. Illegal characters are:<br>
       __\ / : ? * " < > |__<br>
Due to a bug (as of Aug. 2017) in the Photo Station Upload API (error when uploading a photo a second time) the following characters should also be avoided:<br>
      __[ ]__<br>

## Examples
* Target Album: __{Date %Y}/{Date %m}__<br>If photo was captured 2015/07/06<br>--\> Upload to Album: '__2015/07__'<br>
* Target Album: __{Date %Y/%m}__<br>If photo was captured 2015/07/06<br>--\> Upload to Album: '__2015/07__' <br>
* Target Album: __{Date %y-%b}/{Date %d}__<br>If photo was captured 2015/07/06<br>--\> Upload to Album: '__15-Jul/06__'<br>
* Target Album: __{Path:5}-{Path:6}-{Path:7}__<br>
 If original photo is 'c:\users\martin\pictures\2016\01\vacation\img123.jpg'<br>--> Upload to Album: '2016-01-vacation'	
* Target Album: __{LrFM:cameraModel}/{isoSpeedRating}__<br>If photo: camera=Canon EOS 6D, ISO: 125<br>--\> Upload to Album: '__Canon EOS 6D/ISO 125__'<br>
* Target Album: __{LrCC:name 2015$}__<br>If photo is member of collections: 'ByYear/2015/Xmas' and 'TopRated/2015'<br>--\> Upload to Album: 'TopRated/2015'<br>
* Target Album: __{LrCC:path ^Top}__<br>If photo is member of collections: 'ByYear/2015/Xmas' and 'TopRated/2015'<br>--\> Upload to Album: 'TopRated/2015'<br>
* Target Album: __{LrCC:path 2015}__<br>If photo is member of collections: 'ByYear/2015/Xmas' and 'TopRated/2015'<br>--\> Upload to Album: __undeterministic__ either 'ByYear/2015/Xmas' or 'TopRated/2015' <br>
* Target Album: __{LrCC:path ^ByYear/(.+/.+)}__<br>If photo is member of collections: 'ByYear/2015/12'<br>--\> Upload to Album: '2015/12'<br>
* Target Album: __{LrPC:path}__<br>If photo is member of published collections: 'ByYear/2015'<br>--\> Upload to Album: 'ByYear/2015'<br>
* Rename To: __{LrFM:fileName (.+)%.%w+}-{LrFM:folderName}__<br>If original photo path is: c:\users\martin\pictures\2015\12\Xmas\BlackWhite\img0815.jpg <br>--\> Renamed Photo: 'img0815-BlackWhite.jpg'<br>
* Rename To: __{Date %Y%m%d-%H%M}-{LrFM:cameraModel}-{LrFM:fileName .*\[^%d\](%d+)%.%w+}__<br>If  photo was captured 2015/07/06 17:15:00, camera: Canon EOS 6D, orignal filename: img0815.jpg<br>--\> Renamed Photo: '20150706-1715-Canon EOS 6D-0815.jpg'<br>
* Rename To: __{LrFM:fileName (.+)%.%w+}-{LrRM:uuid}__<br>This will append the Lr unique identifier of the photo to the filename. E.g. if filename is 'img_001.jpg' and photo uuid is '5384E52C-F5CB-40C4-8EBA-171F66990210'<br>--\> Renamed Photo: 'img_001-5384E52C-F5CB-40C4-8EBA-171F66990210.jpg'<br>
* Rename To: __{LrFM:fileName (.+)%.%w+}{LrRM:stackPositionInFolder ^1([^%d]*)$|?}__<br>This will prevent any photo burried in a stack from being uploaded (photo stays in state 'New photo to Publish'). <br>

## How to test
Metadata placeholders are geek stuff and sometimes it is not obvious how they work. The easiest way to test them is to 
- create a Published Collection or Published Smart Collection
- define the 'Target Album' or 'Rename Photo To' definition based on metadata placeholders
- set Publish Mode to "Ask me later" or "Check Existing"
- put some representative photos into the collection
- publish the photos via Publish Mode "Check Existing"
- consult the logfile to see where the photos would go and/or how it would be renamed

