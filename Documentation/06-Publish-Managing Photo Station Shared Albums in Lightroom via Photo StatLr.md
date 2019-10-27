## What is a Photo Station Shared Album
A Shared Album in Photo Station is comparable to a Lightroom Collection. You can link photos from a normal Photo Station Album to one or more Shared Albums. Photos in Shared Albums are not a copy, but just a reference to the original photo in the normal Album.

## So, I define a Shared Album as a new kind of Photo StatLr Published Collection within Lightroom?
No, there is no new type of Photo StatLr Published Collection.
As stated above, photos in Shared Albums are bound to physical photos in normal Albums. Thus, you would need to define two Published Collections: one for the normal photo upload and a second one for the linked/shared photos of a particular Shared Album. Besides the issue of keeping both collections in sync regarding the included photos you would also have to always publish the two collections together in the right order.

## OK, so how is it done?
Shared Albums are modeled as Lr keywords. So, it is easily possible to add a photo to more than one Shared Album by simply assigning all corresponding Shared Album keywords to the photo.
Photo StatLr looks for Shared Album keywords at a specific place in your keyword hierarchy:<br>
* Photo StatLr<br>
    * Shared Albums<br>
	    * \<_Publish Service Name_\><br>
                  * \<_Shared Album 1_\><br>
                  * \<_Shared Album 2_\><br>

where _Publish Service Name_ is the name of your Photo StatLr Publish Service where the original photos are uploaded and the Shared Albums are generated.

## So, I have to create the keyword hierarchy by myself?
No. Well, you could do it by yourself, but it's easier to let Photo StatLr do it for you: whenever you create a new Photo StatLr Publish Service or modify an existing one, Photo StatLr will automatically generate the corresponding keyword hierarchy down to the Publish Service level. You then can add new Shared Album keywords below it.

Unfortunately, it is not possible to automatically rename or remove Shared Album keyword hierarchies in case you rename or remove a Publish Service. So, you will have to do some housekeeping in that case.

## Do I need to upload all photos again to add them to a Shared Album?
Photos that you want to put into a Shared Album or remove from a Shared Album, need to be published or re-published via Photo StatLr. You may use Publish mode "Upload" or "CheckExisting" to update Shared Albums. So, if your photos are already uploaded, and you only want to add them to or remove them from a Shared Album, the fastest way is to use Publish mode "CheckExisting".

## May I define whether the Shared Album is private or public?
Yes. By default all Shared Albums will be made public, i.e. have a share link, that's accessible without Login. If you don't want the Shared Album to be public, simply add the synonym "private" to it and Photo StatLr will make the Shared Album private, i.e. only you will see the Shared Album when you are logged in to the Photo Station (not even other logged-in users).

## May I define a password for the share link of a public Shared Album?
Yes. Photo Station 6.6 and above supports advanced Shared Albums including features such as comments, color labels, highlight area tool and password for public Shared Album and so does Photo StatLr. Be sure to configure the right Photo Station version in the Publish Service settings and add the password as keword synonym "password:\<AlbumPasswordHere\>'. 

## Is there a way to find the URL of a public Shared Album?
After you have published photos to a Shared Album you will find the private link and the share link (if public) in the corresponding Shared Album keyword as synonyms.

## Which attributes should the Shared Album keywords have?
It's advisable to set "Include on Export" for the Shared Album keywords, because Lr will then set photos to "Modified to Re-publish" when the Shared Album keyword is added to or remove from a photo. It's typicalley not a good idea to set "Export Synonyms", because this will reveal all those mostly private information stored in the synonyms as stated above. Checking "Export Containing Keywords" will also export the parent and ancestor keywords, i.e. the Publish Service name and "Photo StatLr" as root keywords, which may or may nort be helpful.

## Is it possible to feed one Shared Album from multiple Published Collections?
Yes. Shared Albums are defined at the Publish Service level. Any Published Collection within the Publish Service may contribute photos to all the Shared Albums of that Publish Service. But keep in mind: if you have a photo in more than one Published Collection of the same Publish Service, all of its uploaded versions will be linked to the Shared Album.