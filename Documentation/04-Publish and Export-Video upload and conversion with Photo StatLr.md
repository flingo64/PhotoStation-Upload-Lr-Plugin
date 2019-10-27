# Video support in Lightroom
Lightroom supports various video formats, but only in Library mode. So, you may tag videos and set various metadata or keywords for videos, or apply some limited video editing functions such as trimming, white balance adjustments or tone control. When you export videos you may decide to export the original video or the processed version of the video. If you decide to export the processed version, you may choose between DPX and H.264 and various 'quality' settings, which actually define both the output quality and resolution. If you want to export the processed version you should always choose H.264, because otherwise Photo StatLr will have to do a second conversion of the already converted video. Explanation is following.

# Video support in Photo Station
Photo Station supports uploading/downloading of videos in various formats, but may play back videos in MP4 / H.264 format only. It allows videos to be accompanied by an additional video in a different resolution, so that you may choose the resolution when you play back the video. When you download a video from Photo Station, you'll always get the primary/original video.

# Video support in Photo StatLr
Photo StatLr supports not only uploading of MP4 videos but of virtually any video format to Photo Station. Photo StatLr takes whatever it gets from the Lr video export task (see above: processed video, called the primary video here) and will automatically detect and convert Non-MP4/H.264 videos (in case you configured Lr video handling as 'Original') to MP4 videos. It will upload the primary video (let's say in avi format) plus the converted MP4/H.264 video in that case. As a consequence you may then:
- download the primary video (e.g. in avi format) from Photo Station and
- play back the converted primary MP4/H.264 video

Photo StatLr will also convert the primary video, even if it is already MP4 in the following cases:
- the video stream codec is not H.264
- the video is rotated as indicated by the embedded video metadata and you enabled hard rotation
- the video is rotated as indicated by one of the keywords 'Rotate-90', 'Rotate-180', 'Rotate-270' (so-called meta-rotated) and you enabled hard rotation
- you have choosen 'Always convert' for the original video (e.g. because you want to export a lower quality version of the original video)

In those cases, only the converted primary video will be uploded. If the primary video is to be converted, the configured quality settings for the original video will be applied.

In all other cases Photo StatLr will not convert the primary video.

Besides the upload of the primary video, you can decide to upload one additional video resolution as accompanying video to the Photo Station. You can configured the video quality of the additional video (if at all) in general and its resolution based on the original resolution. E.g.: you may decide to upload an additional video with MEDIUM quality and LOW resolution, only if the original video has HIGH or ULTRA-HIGH resolution.

# Video conversion presets in Photo StatLr
Photo StatLr adds two kinds of video conversion presets to the Export/Publish process: Lr video conversion presets and Photo StatLr video conversion presets.

## Lr video conversion presets
You will find these presets as "Custom Presets" in the "Video" section of the Export/Publish Service dialog (unfortunately, only visible with English language setting). They apply to the optional first conversion step performed by Lr. The only situation where you want to use one of those presets is when you have a video with higher than FullHD resolution (e.g. a 4K video) and you want to export the processed version of that video with the original resolution. In this case the Photo StatLr "Custom Presets" will be required, because the Lr "Default Presets" do not support the export of more than FullHD resolution.
 
## Photo StatLr video conversion presets
Photo StatLr video conversion presets are shown in the Photo StatLr section of the Export/Publish Service section as Video Quality settings (see above) and used by Photo StatLr during conversion of the primary and/or additional video. Video quality settings are stored as JSON array in a presets file in the Plugin directory. A preset includes the following parameters:
- id - its position within the JSON array
- name - shown in the Photo StatLr quality settings listboxes
- comment - just for your information (optional)
- __audio encoder options__ for ffmpeg
- __video filter options__ for ffmpeg
- __video encoder options__ for ffmpeg
- __second pass video encoder options__ for ffmpeg (optional)
- __input options__ for ffmpeg (optional)
- __output options__ for ffmpeg (optional)

Photo StatLr will build the ffmpeg command line from video-specific and configured options as follows:<br>
> ffmpeg -noautorotate [__<input_options>__] -i <input_filename> -y __<audio_encoder_options>__ [-pass 1|-pass 2] __<video_filter_options>__ <rotation_options> __<video_encoder_options>__ <size_options> <metadata_options> [__<output_options>__] <output_filename>

## Photo StatLr video conversion presets - customization
Photo StatLr comes with a reasonable number of presets allowing you to define some typical quality settings for video conversions. 
If you are familiar with ffmpeg and you want to define your own quality settings or want to use GPU accelaration of your GPU, you may change or add presets. But please keep in mind that the next Photo StatLr update will overwrite the standard presets file. So, in general it's a better idea to copy the presets file and edit the copy. To point Photo StatLr to your copied presets file, you a have to configured the filename of the new presets file within the Plugin Manager section of Photo StatLr.

Please keep also in mind that Photo StatLr references a presets by its id. So, if you want to add a new preset, put it at the end the JSON array. If you want to replace an existing preset in all Export Presets and Publish Services, replace the old preset at its original position in the JSON array.