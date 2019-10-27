**Q: I had 6 GB free space on my hard drive, somewhere in between the processing, it used up everything and the operation got stopped. My 7000 photos use about 17GB on an external drive, so do I need 17gb free space on my local drive to perform the complete upload?**

**A:** When you export/publish a collection of photos, Lr will launch two processes: one that generates temporary copies of the photos to be exported, and a second one for the PS Upload plugin to upload the photos. The faster the first process and the slower the second one, the bigger the backlog of photos to be uploaded. The copies will be deleted when the upload is done or the export is stopped. So, in worst case you'll need the same amount of free diskspace as the collection of photos you're trying to upload uses. Uploading original rather than developed photos is critical in that sense, since the Lr process is very fast in that case.

If you cannot free up enough diskspace for the whole collection you may proceed as follows:
* Use the **Publish** instead of the **Export** mechanism
* **start with a small collection** (smart or normal): e.g. some thousand photos and publish/upload it
* **grow the collection** and publish it repeatedly until the collection is complete
* if you have **already exported a bunch of photos** via Export, you don't need to upload them again via Publish to get them to status "Published": use the **"Find existing"** publish mode instead to move photos in your collection that are already in PhotoStation from "unpublished" to "published" (this mode won't grow the photo backlog, since it is comparable fast). 

