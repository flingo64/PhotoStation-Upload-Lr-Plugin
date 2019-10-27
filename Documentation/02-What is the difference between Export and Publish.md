Export is ok if you have a one-time job to upload some photos from Lr to the PhotoStation. The setup of an Export configuration is quick and easy, but there is no way to keep track of which photos have been exported so far or which photo was modified or deleted after export and probably should be modified or deleted also in PhotoStation.

If you want to keep track of photos being uploaded to the PhotoStation you should use the Publish mechanism: 
- you define a Publish service that includes the definition photo processing parameters, the target diskstation and the target PhotoStation (Standard or Personal)
- you define a collection or smart collection that should be uploaded and the target album and upload scheme (flat or tree mirror)  
Using this Publish service settings Lr is able to do the housekeeping for you: 
- photos not yet publish are in state "Unpublished" 
- photos successfully uploaded to PS go to state "Published", 
- photos changed after upload go to state "Modified Photos to Re-Publish"
- deleted photos go to state "Deleted Photos to Remove"
As soon as you click "Publish" only those photos that need upload or deletion will be uploaded or deleted.

Publishing is also cool, because you can easily interrupt the upload process (by clicking the x at the right of the progress bar) and continue the process the next day at exactly that point.
