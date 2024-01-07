## What is Shared Album in Photos
A Shared Album in Photos is comparable to a Lightroom Collection. You can link photos from a normal Photos Folder to one or more Shared Albums. Items in Shared Albums are not a copy, but just a reference to the original item in the photo folder.

## So, I define a Shared Album as a new kind of Photo StatLr Published Collection within Lightroom?
No, there is no new type of Photo StatLr Published Collection.
As stated above, photos in Shared Albums are bound to physical photos in folders. Thus, you would need to define two Published Collections: one for the normal photo upload and a second one for the linked/shared photos of a particular Shared Album. Besides the issue of keeping both collections in sync regarding the included photos you would also have to always publish the two collections together in the right order.

## OK, so how is it done?
Shared Albums are modeled as Lr keywords. So, it is easily possible to add a photo to more than one Shared Album by simply assigning all corresponding Shared Album keywords to the photo.
Photo StatLr looks for Shared Album keywords at a specific place in your keyword hierarchy:<br>
* Photo StatLr<br>
    * Shared Albums<br>
	    * \<_Publish Service Name_\><br>
                  * \<_Shared Album 1_\><br>
                  * \<_Shared Album 2_\><br>

where _Publish Service Name_ is the name of your Photo StatLr Publish Service where the original photos were uploaded and where the Shared Albums will be generated.

![](../Screenshots-Windows/14b-ManageSharedAlbums.jpg)

## So, I have to create the keyword hierarchy by myself?
No. Well, you could do it by yourself, but it's easier to let Photo StatLr do it for you: whenever you create a new Photo StatLr Publish Service or modify an existing one, Photo StatLr will automatically generate the corresponding keyword hierarchy down to the Publish Service level. You then can add new Shared Album keywords below it.

Unfortunately, it is not possible to automatically rename or remove Shared Album keyword hierarchies in case you rename or remove a Publish Service. So, you will have to do some housekeeping in that case.

## Do I need to upload all photos again to add them to a Shared Album?
Photos you want to put into a Shared Album or remove from a Shared Album, need to be published or re-published via Photo StatLr. You may use Publish mode "Upload", "CheckExisting" or "MetadataUpload" to update Shared Albums. So, if your photos are already uploaded, and you only want to add them to or remove them from a Shared Album, the fastest way is to use Publish mode "CheckExisting".

## May I define whether the Shared Album is private or public?
Yes. By default, Shared Albums added via the Lr Keyword List panel will be private (accessible only by the Photos account used by Photo StatLr). If you want the Shared Album to be public, use the __Manage Shared Album Dialog__ (Menu: __Library -> Plug-in Extras -> Manage Shared Albums__) to modify the Shared Album settings:

![](../Screenshots-Windows/14c-ManageSharedAlbums.jpg)
  

## Is there a way to find the URLs of a Shared Album?
After you have published photos to a Shared Album or created a new Shared Album via the 'Manage Shared Album' dialog you will find the private and public URLs of the Shared Album in the 'Manage Shared Album' dialog.

## Which attributes should the Shared Album keywords have?
It's advisable to set "Include on Export" for the Shared Album keywords, because Lr will then set photos to "Modified to Re-publish" when the Shared Album keyword is added to or remove from a photo. Checking "Export Containing Keywords" will also export the parent and ancestor keywords, i.e. the Publish Service name and "Photo StatLr" as root keywords, which may or may not be helpful.

## Is it possible to feed one Shared Album from multiple Published Collections?
Yes. Shared Albums are defined at the Publish Service level. Any Published Collection within the Publish Service may contribute photos to all the Shared Albums of that Publish Service. But keep in mind: if you have a photo in more than one Published Collection of the same Publish Service, all of its uploaded versions will be linked to the Shared Album.