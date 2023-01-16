__This article applies to V5.2.0 and later. If you intend to use the sync functionality it's strongly recommended to upgrade to this version or later.__
# General remarks
Downloading metadata from Photo Station / Photos (hereafter called `PS`, if both systems are meant) to Lightroom (Lr) enables distributed/collaborative editing/maintainance of photo/video metadata via Lr and PS. One typical scenario of such a collaboration is where the photographer maintains and develops his photos in Lr and then publishs them to PS. Once the photos are in PS, the family may want to add some tags/keywords or ratings to the photos. Finally, the photographers syncs back all the tags and ratings from the PS to Lr and has an up-to-date view of the whole family's work. :-)

As with all distributed/collaborative work, there are some questions that have to be answered:
- which metadata items can be synced
- when will they be uploaded
- when will they be downloaded
- what happens if a metadata item is modified in parallel on both sides to different values (e.g. photographer rates a photo 2 stars, family says: 3 stars)
- what happens if someone removes a metadata item

In a nutshell: the general policy of Photo StatLr is:
- Lr is the master of all metadata 
- it allows metadata additions and modifications via PS, but it prevents metadata removal via PS

Need more details? Here we go ...

# Supported metadata
The goal of Photo StatLr is to support the two-way synchronization of all photo/video metadata that can be edited in PS plus some of the vital Lr metadata that are currently not supported by PS, but are translated by Photo StatLr. Here is the list of currently supported items:
- __title__ (single value metadata)
- __description__ (single value metadata)
- __general tags / keywords__ (multiple value metadata)
- `Photo Station`: __person tags / face regions__ (multiple value metadata): since there is no Lr API to import face regions, PS person tags are download __to the orginal photo__ (via exiftool). You will need to __reload the metadata for those photos to Lr__ afterwards manually. Be sure, that you have enabled the general Lr setting __'[x] Automatically write changes to XMP'__, otherwise you will loose your metadata modifications when reloading the metadata.
- `Photos`: __person tags__ (multiple value metadata): Person tags in `Photos` consist of a face thumbnail and an optional name, but not face region information. The name - if set - may be synced as keyword between Lr and Photos. 
- __color label__ (translated single value metadata): translated to a PS general tag '+color' (e.g. '+yellow', '+red', etc.)
- __rating__ (native for Photo Station 6.5 and above and Photos 1.1 and above) (single value metadata): --\> will be synced to photo and downloaded to the Comments panel 
<br>exclusive or<br>
- __rating tag__ (useful for Photo Station below V6.5 or Photos 1.0: to a PS general tag '*', ..., '*****') (single value metadata): --\> will be synced to photo and downloaded to the Comments panel
- __GPS info__ in `Photo Station`: GPS coords can be added in Photo Station via the Location Tag panel: enter a location name / address and let Google look up the coords (blue pin) or position a red pin in the map view via right-click. Photo Station will write red pin coords also to the photo itself. Red pin coords have preference over blue pin coords when downloading GPS info. Please note: location tags (e.g. __address, city, country__) added in Photo Station will __not be synched to Lr__. Also, when a photo/video is uploaded from Lr to Photo Station, __Lr location tags__ (city, state, country) will __not be visible__ in the Location panel in __Photo Station__. Location tags of photos in Photo Station will not be overwriten when the photo is uploaded again from Lr, but __location tags of videos in Photo Station will be overwriten__ when the video is uploaded again from Lr.<br><br>
- __comments__ (multiple value metadata): downloaded only to the Comments panel of a published photo in Lr, not synced to the photo itself

Note, that you can __only download__ metadata items, that are __also configured for upload__! The reason for that will hopefully become clearer when you've read the whole story.

# When will metadata be uploaded
Metadata upload will be done automatically during photo/video upload. In addition, there are 3 metadata translations that can be configured for upload for each individual Published Collection:
- face regions (only for Photo Station, not applicable for videos)
- color labels
- rating tags (useful for Photo Station below V6.5 or Photos 1.0)

Every time you publish or export a photo all standard (not configurable) and configured translated metadata will be uploaded. If the photo was re-published, any previous metadata of that photo in the PS will be overwritten.

# When will metadata/comments be downloaded
Metadata download is configurable on a per-metadata-item basis for each individual Published Collection. By default, metadata download is disabled for all collections and all metadata items.

Metadata download was integrated into the Lr mechanism for getting comments and ratings. Thus, it is controlled via the "Publish" button and the "Refresh comments" button in the Comments panel on the right lower corner of Lr in the Library module. Download of metadata -if enabled for the Published Collection - will take place:

- For every published photo in the Published Collection each time any photo in the collection is published or re-published immediately after the publish process.
- For every published photo in the Published Collection when the user clicks the 'Refresh Comments' button in the Comments panel.
- After the user has added a new comment to a photo in the Comments panel and the comment was uploaded.

As you can imaging, this approach can be very time-consuming for large Published Collections, so you probably won't enable the download options for those collections permanently, but perhaps only occasionally when you know that there have been changes to photo metadata in PS.

# Collision handling
Since neither Lr nor PS track the time when a metadata item was added, modified or deleted, there is no way to synchronize those changes automatically. There are a few situations where modified metadata may be overwriten:
- When a photo/video is re-published, it will overwrite any metadata in PS for that photo. This means, that if any metadata of a photo was modified via PS between 2 publishings of that photo, these change will be lost. 
- as long as a photo is in state 'To re-publish' there is no download of metadata (but still download of comments) for this photo from PS. On the one hand, this prevents the overwriting of metadata recently changed in Lr but not yet published with metadata from the PS. On the other hand, when that photo is published the next time, it will overwrite all metadata in PS that were modified in the meantime in PS.
- if a photo is published via more than one Published Collection, and you change a metadata of the photo in both places in the PS to different values, one of these change will eventually be overwritten by the other: the last "Refresh Comments" will win.

Two take-aways:
- Do not start editing metadata in PS as long as photos of that collection are in state 'To Re-publish'
- General rule: in any case of collision the status of the metadata of Lr will win.

# What happens if a metadata was removed
- comments can only be removed via PS, when you "'Refresh Comments' in Lr they will be removed in Lr also
- if a (single or multiple value) metadata was removed from a photo in Lr, it will also be removed in the PS when it is re-published 
- if a single value metadata is removed in PS and metadata for that photo are downloaded to Lr via 'Refresh Comments' the removal will be rejected and the photo changes its state to 'To Re-publish', because the photo is no longer in sync with the PS version of the photo. This is your chance to view the logfile for the rejected change and decide whether to remove the metadata also in Lr or not.
- if you remove/add/change a value for multiple value metadata (e.g. general tags/keywords or face regions) in the PS, the handling during "Refresh Comments" depends on the count of values in Lr and PS:
	- if there are equal or more values in the PS version of the photo, this will be accepted and synced
	- if there are less values in the PS version of the photo, this will be rejected and the photo changes its state to 'To Re-publish' (see above)

## I get a message saying 'n rejected removed metadata items' and published photos move to "To Re-publish" although no metadata were removed in PS. What happened?
There are situations where there was no metadata removal on the PS side and you still get this error. In particular, if you uploaded a bunch of photos to a slow diskstation. Now, when Photo StatLr asks for the photo metadata and the diskstation has not yet completed the indexing of the metadata of the recently uploaded photos, it will return empty metadata and thus Photo StatLr interprets it as removed metadata which it will reject.

To circumvent this situation, it's advisable to (buy a faster diskstation or) set Metadata Download to "Ask me later" or "No", so that you (may) skip the metadata download after the upload phase of each Publishing job. You may still use the download metadata feature when you know there are some changes in PS via the "Refresh Comments" button in the Comment panel.

# Notes on Lr keywords
Keywords in Lr have a variety of properties:
* Lr allows you to define keyword hierarchies such as: animal - bird - eagle.
This is a very convenient method to structure hundreds or thousands of keywords. 
* Keywords may or may not be 'Included on Export', i.e will be uploaded
* Keywords may have synonyms which will be uploaded if 'Export Synonyms' is checked
* Keyword parents (e.g. animal and bird for the eagle) will also be uploaded if the keyword itself has 'Export Containing Keywords' checked and the parent keyword has the property 'Included on Export'
* in Export or Publish Provider dialog you may choose to 'Write keywords as Lr hierarchy'

On the other hand PS can only handle flat generals tags (the pendant to keywords). On upload this is what happens:
* if a photo has a keyword, depending on the above listed properties the keyword, its synonyms and its parent keywords will be uploaded as separate (flat) keywords, which will be shown as general tags in PS.
* if you have choosen to 'Write keywords as Lr hierarchy' then the respective keywords will also be written to an additional XMP Tag als complete keyword hierarchies, such as 'animal|bird|eagle'. This XMP tag is not identified by PS as general tag. So, this setting has no meaning for uploading to PS.

When it comes to downloading keywords, this is what happens:
* if you added a general tag such as "eagle" to a photo in PS (or a person tag via face rcognition in Photos), the tag will be applied as keyword to the photo in Lr. Which specific Lr keyword object will be used depends on various facts:
  * the PS tag will be searched as keyword name in the Lr keyword hierarchy from highest level to lowest level. If found, the corresponding keyword object will be used.
  * if the PS tag is not found as keyword name in the Lr keyword hierarchy:
    - before `Photo StatLr 7.3.0`: non-existing keywords were added as highest level keywords
    - `Photo StatLr 7.3.0` and later: non-existing keywords will be added under the following keyword path:\
        `Photo StatLr` -> `Imported Tags` -> `<Publish Service Name>`\
        This makes it easier to identify newly created keywords. The keywords can of course be moved to a different place in the Lr Keyword hierarchy afterwards where they will found during subsequent tag downloads.
  * if you want to add a PS tag as keyword at a specific location in the Lr keyword hierarchy you can do so be adding the whole hierarchy as one keyword in the format shown above, e.g. 'animal|bird|eagle'. This tag will be added (if not existing) to Lr as a keyword hierarchy such as 'aninmal' | 'bird' | 'eagle' and the lowest keyword will be applied to the photo. The photo will then move to status 'To Re-publish' and on the next upload the three keywords will be uploaded as three separate general tags to PS. Now, the photo is in sync again.
* Removal of a synonym or parent keyword itself without the removal of the belonging leaf keyword in PS will be rejected during download
* Removal of a leaf keyword (and belonging synonyms and parent keywords) is allowed as long as the rule '# of removals <= # of additions' is followed.
* if after applying the allowed removals and additions in Lr the resulting list of 'Keyword included on Export' is different from the current list of general tags in PS, then the photo is set to "To be re-published" since it is no longer in sync with the PS version of the photo.
* Person tags in `Photos`: 
  Persons tags in Photos can only be created and added to photos via the Photos face recognotion feature when you give an unknown face a name. Person tags will also be imported as Lr Keyword object acc. to the rules layed out earlier and applied to the respective photo. If the photo is re-published from Lr to Photos later on, this is what happens depending on the Publish Mode:
  - Normal Upload: </br>
  The photo will be overwritten in Photos, (now having the former person tags as general tags) and thus the face recognition will start again, most likely resulting in the same recognized or unrecogniozed faces again
  - Metadata Upload: </br>
  During metadata upload all Lr Keywords applied to the photo on the one side will be matched against all general tags and persons tags in Photos on the other side. That way, person tags synched from Photos to Lr won't generate duplicate general tags after re-publish.

Well, that's basically it!
