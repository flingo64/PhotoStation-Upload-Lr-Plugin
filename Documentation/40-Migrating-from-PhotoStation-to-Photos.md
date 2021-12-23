# Migration from Photo Station to Photos
There two steps for migrating your photos/videos from Photo Station to Photos:
1) migrate your photos/videos (optional)
2) migrate the Photo StatLr Publish Service(s) and Published Collections
  
## 1) Migrating your photos/videos
Please follow the guidelines from Synology how to migrate your photos/videos from Photo Station to Photos. Hopefully, the migration process will migrate all photos/videos including thumbnails and additional video resolutions to Photos and do a complete indexing thereafter.

## 2) Migrating the Published Collections of the Photo StatLr
There are two possible ways of migrating the Photo StatLr Publish Services and Published Collections:
- Modify your existing Publish Service(s) to point to the Photos server
- Duplicate your existing Publish Service(s) and all of its Published Collections and Published Collection Sets

### Modify your existing Publish Service(s)
This approach makes sense if you already migrated your photos. Here are the steps to take:
- within the Photo StatLr Publish Service(s):
    - change the Photo Server version from 'Photo Station 6.x' to 'Photos 1.x'
    - change the address to something like 'http://my-dsm7:5000' or 'https://my-dsm7:5001'
    - make sure the timeout value is >= 30 seconds, since some of the Photos API calls may take longer than the Photo Station API calls
    - save the canges
    - click 'Republish all' to let Lr change the state of all photos to 'Modified Photos to Re-publish'
    - for all Published Collection:
        - do a Publish with Publish Mode 'CheckExisting' to make sure all photos were migrated successfully, so they will change their state to 'Published'
        - if you find photos not beeing migrated successfully, publish them with Publish Mode 'Upload'

### Duplicate your existing Publish Service(s)
If you want to build a copy of your gallery so you can use Photo Station and Photos in parallel (e.g. to make sure Photos meets your expectations), take the following steps:
- create a duplicate of your Photo StatLr Publish Service(s) with the exact same settings except the server version, address and timeout (see above)
- copy all Published (Smart) Collection and Publish Collection Sets from the old to the new Publish Service: use the "Export/Import Collection" feature of Lightroom for this purpose
- __Important note__: although exporting/importing Published Collections will copy all collection settings, you still have to __open them once and save them__, otherwise the collection settings will not be effective
- if you have migrated your photos/videos alredy, do a Publish with Publish Mode 'CheckExisting'
- if you did not migrate your photos/videos, do a Publish with Publish Mode 'Upload' and take a cup of tea ... ;-)
