Synology Photo Station and Media server relies heavily on thumbnails (small previews of the original photo) in various dimensions.
When uploading photos from Lr to Photo Station via a standard HDD export, only the photo will be uploaded to the PhotoStation. In this case a process on the diskstation will be triggered to generate the thumbnails. Depending on the diskstation model this process will be somewhere between slow and annoying lame. Especially the DS 1xx and 2xx series are known to be very lame: thumbnail generation takes about a minute or more for one photo. This "speed" is inacceptable if we are talking about thousands of photos. 
In that sense, Photo StatLr does pretty much the same as the Synology Photo Station Upload application: it generates the thumbs on your PC/notebook and uploads both the original photo and the thumbs to the PhotoStation so that as soon as you uploaded the photo, it is visible in the Photo Station (and via Mediaserver through DLNA).

Besides that the plugin offers some real nice features, such as:
- integration into Lr as Export or Publish provider
- configurable small or large thumb set 
- configurable jpeg quality for the thumbnails
- support for photos in any colorspace 
- configurable sharpening of the thumbs
- configurable additional video resolution depending on the original video resolution
- support for video hard-rotation
- configurable video conversion settings
- photo upload as flat copy or mirroring of the source folder structure
- dynamic definition of target Album and renaming of photos based on photo metadata

A second focus of Photo StatLr is to preserve or translate as much metadata as possible when photos or videos are uploaded to the Photo Station:
- the capture date of videos
- title and description are propagated to the corresponding tags in Photo Station
- ratings may be translated to a general tag in Photo Station (useful for Photo Station versions < 6.5)
- color labels may be translated to a general tag in Photo Station
- keywords / keyword hierarchies (in particular for videos)
- face regions may be translated from Lr format to the Photo Station compatible format (useful for Photo Station versions < 6.5)
- GPS info (in particular for videos)
- Lr location tags (country, state, city, etc.) can be combined to a single PS location tag

Also, Photo StatLr allows you to synch back metadata that were added to a photo/video in Photo Station:
- title and description
- ratings and color labels
- keywords / keyword hierarchies
- face regions
- GPS info

Photo StatLr also supports the synchronization of comments added via Photo Station - either private comments or public  comments on public shared photos. 