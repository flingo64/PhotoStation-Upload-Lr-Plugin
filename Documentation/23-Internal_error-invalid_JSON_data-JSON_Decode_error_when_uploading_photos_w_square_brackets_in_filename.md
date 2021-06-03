**Q: I get a Lr message box "Internal error: invalid JSON data / JSON Decode error" when publishing photos with '[' or ']' in the filename. What's the reason, what can I do?**

**A:** The exception is caused by server side code of the Photo Station Upload API running on the Synology Diskstation. Square brackets ('[', ']') have a special meaning in PHP function used by the Upload API code and must be properly escaped to be interpreted literally. Unfortunately, the code behind the Upload API doesn't escape the square brackets correctly and will response with a non-JSON error message.

There are different ways to circumvent this issue:
- rename the photos locally, so they do not include square brackets in their filename or
- use the renaming feature of Photo StatLr to rename the photos during upload so the target filenames look proper or
- patch the Photo Station Upload API code as described by HendriXML in issue [#52](https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/issues/52)
