**Q: I get a Lr message box "...recordPublishedPhotoUrl: must be called after recordPublishedPhotoId" when I'm publishing photos. What does it mean?**

**A:** The message is a little bit misleading (see [Rob Cole's post](https://feedback.photoshop.com/photoshop_family/topics/lightroom_sdk_rendition_recordpublishedphotoid_url) on this issue). 
In fact, you'll get this error when you try to publish two or more photos with the same filename to the same target album in Photo Station. If more than one photo with the same filename is uploaded to the same target album in Photo Station, it will conflict in two places:
- the photos will overwrite each others in Photo Station (the last published photo will survive)
- recordPublishedPhotoId() won't work, but that method has no treatable return code, so the following recordPublishedPhotoUrl() will raise the exception

Most likely, this happens because of one of the following conditions:
  1. you are publishing __different photo versions__ (with the same filename) __from a local directory structure__ to a __flat target album__ in Photo Station
  2. you are uploading a __RAW and JPG__ version of the same photo to the same target album. 
  3. you are uploading a photo and/or belonging __virtual copies__ with missing or conflicting copy names
  4. you are using __metadata placeholders__ in the 'Target Album' and/or 'Rename To' setting and the __resulting destination paths are not unique__ for all photos in your Published Collection
  5. after publishing an initial set of photos from a published collection you did some __local photo renaming__ so that a the local pathname of one not yet published photo is identical to the former local pathname of an already published photo (eh, what?)

If you cannot figure out which photos are causing the exception, try this:
- make sure you have Photo StatLr v6.1.6 or later installed
- select all photos of the respectice Published (Smart) Collection and apply "Mark to Republish" in the context menu
- Publish all photos using Publish mode "Check Existing"
- when the error message "recordPublishedPhotoUrl:..." appears, do not click the 'OK' button, but open the Photo StatLr logfile
- copy the destination path shown in the last line of the logfile, e.g.:<br>
19:37:32, INFO : CheckExisting: No upload needed for "_\<source path\>_" to "_\<destination path\>_" 
- click 'OK' in the error message box and let the "CheckExisting" process finish its job
- re-open the logfile again and search for the copied destination path 
- you will find two lines with that particular destination path: check the belonging source paths:<br>
     - the source paths are identical: the virtual copy issue --\> Adjust the virtual copy names to be unique for the photo
     - the source paths are identical except the filename extension: Use 'RAW+JPG to same Album' to solve the issue
     - the source paths are different: 
          - condition 1: make the local filenames unique or switch from 'Flat' to 'Mirror' 
          - condition 4: adjust the 'Target Album:' and/or the 'Rename To:' settings of the collection so that no two photos of your collection will be uploaded to the same destination path
          - condition 5: remove and re-add the conflicting renamed photos from/to the Published Collection

