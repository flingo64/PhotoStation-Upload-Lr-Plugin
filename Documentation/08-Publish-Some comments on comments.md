
## Share your photos and talk about them
Why would we share our photos with our family and friends if not to talk about them? Photo Station allows you to share photos and gives your friends a way to comment on them. Photo StatLr enables Lr to import comments back to your catalog, the place where you manage your photos. So far, so good. But have you ever tried to find the latest comments on your shared photos in Photo Station or in Lightroom? You might have noticed, that there is no way to search/filter photos with comments in Lr or PS. Unbelievable, isn't it! For private comments in Photo Station you'll probably get an email notification, but for comments entered via public shared albums: nothing, nada, niente! Imagine, you shared some great photos and your friends were excited about them and posted some cool comments and you didn't even notice it! :-(

__OK, here is where Photo StatLr comes into play!__

But let's get some things clear, first:

## What is the difference between private and public comments?
A private comment is a comment that was entered by user logged in to Photo Station. A private comment can be added to a photo/video either via the Album it is stored in or via a Shared Album it is linked to. No matter where you added the comment, it will be visible in both locations.<br>
A public comment on the other hand can only be added to photos in a public Shared Album via its share link. To enter a public comment you don't need to login to Photo Station, but you probably need to enter the password for the share link.<br>
Public and private comments are completely separated in Photo Station: when you visit the public share, you will only see the public comments, whereas when you log in to Photo Station and view the Albums and (private) Shared Albums you will only see the private comments. Sounds strange but it's true.

## Can I download both private and public comments from Photo Station to Lr?
Yes, you can configure for each Published (Smart) Collection to download private and/or public comments. You can also configure to do it every time or only on demand. Downloading of public comments is quite fast, because Photo Station allows the plugin to ask for a list of existing comments. Downloading private comments is quite slow (appr. 2 photos/sec), because the plugin has to ask for comments for each individual photo. So, if you plan to sync private comments you should work with small Published Collections.

## How can I identify in Lr if a comment from Photo Station is private or public?
In the Comment Panel the author's name will be suffixed by:<br>
- (Photo Station internal) or
- @\<Shared Album Name\> (Public Shared Album)

to indicate the source of the comment.

## Can I add private and public comments to a photo from within Lightroom?
Currently, you can only add a private comment to a photo via the Comment panel, but you will see how you can easily navigate to the photo in the public Shared Album from within Ligtroom, later.

## How can I find photo comments in Lightroom? 
Well, the Comment panel works only when you select photos within a Published Collection. It won't show comments when you navigate through your photos in your photo folders or collections. And even if you select photos in a Published Collection, there is no way to find photo comments in the Comment panel other than clicking each individual photo. Wow! Exciting!

Therefore, Photo StatLr introduced in V6.3 a bunch of photo plugin metadata to keep information about photo comments. In particular:
- Number of comments
- Last comment time
- Last comment text
- Last comment author
- Last comment type (private or public)
- Last comment collection: the Published Collection via it was received and which you will need select to see all comments of the photo
- Last comment link: the URL to view the photo with the comment in Photo Station

Most of these plugin metadata are available as filter in the library filter panel or as filter in the Smart Collection settings dialog. This enable you to search for those comment criterias everywhere in the Library module.

## Is it possible to view these comment infos in the Metadata panel?
Yes, Photo StatLr comes with a handful of Metadata Presets including more or less of the comment fields. You will find the following presets in the Metadata panel:
- Photo StatLr: Compact
- Photo StatLr: Just Comments
- Photo StatLr: Long
When you select one of those presets you'll see some or all of the comment fields plus some more or less common metadata fields in the Metadata panel. The field _Last Comment Link_ can be clicked to open the photo in the corresponding Album/Shared Album in your Browser.

__Now you really can share your photos and get in talks about them!__
