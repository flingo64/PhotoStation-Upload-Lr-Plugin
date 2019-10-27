# What's the problem?
Some of us have already invested a lot of time in designing and maintaining an elaborated Collection Set hierarchy that represents a well-structured collection layout according to grouping criteria that we believe to be helpful for organizing and finding photos. Now, when it comes to the point that we want to publish this well-organized structure to an external target, we realize that this work is not usable by most of the available Publish Service Providers.

Lightroom simply does not support publishing of normal (not "Published") Collections or Collection Sets to a Publish Service. One of the reasons why it isn't supported is that a normal collection is just an object with a name and a position within a Collection Set, whereas Published Collections and Publish Collection Sets may hold various service specific settings.

# Basics on Published Collections
A Published (Smart) Collection definition consists basicly of two parts:<br>
 1. its service specific settings:<br>
   Service specific settings may include target album definition and such
 2. the list of belonging photos (Published Collection) or the collection membership criteria to be met by photos to be part of it (Published Smart Collection)

# Defining a Collection Set mirror with Photo StatLr
With Photo StatLr it is possible to define a mirror of a local Collection Set hierarchy. Depending on your needs and on the Collection Set structure and contents it may be possible to define a mirror by just one single Published Collection or by multiple Published Collection using identical or similar settings. All this is achieved by the use [metadata placeholders] (https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/wiki/Publish-and-Export:-How-to-use-metadata-placeholders-in-'Target-Album'-or-'Rename-Photos-To'-definitions). As you will see in the following examples the first part of the definition is easy, whereas the second part is most of the time the hardest part. Let's start with an easy example.

__Important notes__: 
- Photo StatLr can only mirror Collection Set hierarchies containing __Standard Collections__, but __not__ Collection Set hierarchies containing __Smart Collections__.
- the Photo StatLr Publish Service (as any other Publish Service) is not notified by Lr about modified names or a modified structure of your Collection Set hierarchy. Thus, if you __change the name of a Collection or Collection Set__ to be mirrored, you will have to __re-publish__ all affected photos __manually__ to reflect to new names/structure.

## Collection Set hierarchy with multiple levels, each photo is in exactly one Collection
### Example structure
- 'Year/Year-Event'

### Typical solution
1. Define a Published Smart Collection called 'Mirror Yearly Collections'
	- select '__Flat copy to Target Album__'
	- as Target Album set: '__{LrCC:path ^[12]|?}__' and check '__Create Album, if needed__'<br>
	  'LrCC:path' means: all photos in this Published Collection (as defined in part 2) will be published to an album path that is identical to the path of the local Collection the photo belongs to. 
	  Since each photo of this Published Collection may be member of more than one source collection, we need to define a match pattern for the source collection we want to mirror. '^[12]' is a regular expression that matches any local collection path starting with '1' or '2' (e.g. 1989, 2003, 2015, etc). Last but not least we will define what should happen to photos in this Published Collection not being member of a collection matching our pattern. We use '|?' which stands for: required, do not publish if no matching collection is found. 
2. Define the match criteria for the photos of the Collection Set hierarchy to be mirrored. In our example, this is easy, because all (leaf) Collections look like 'Year-Event':
	- set __no match criteria__ (i.e. all photos of the active catalog will match) or
	- set match criteria to: 'Match __any__ of the following rules:' '__Collection__' '__starts with__' '__19__', '__+__' '__Collection__' '__starts with__' '__20__'

### Description / Notes
- With this definition you get one big Published Smart Collection containing all your photos of your local collection hierarchy starting with '1' or '2'. You could also define smaller Published Collection, let's say per decade by defining 3 collections with similar definitions and photo criteria:
   - collection 'The Nineties': Target ALbum '{LrCC:path ^199|?}
   - collection 'The 2000s': Target ALbum '{LrCC:path ^200|?}
   - collection 'The 2010s': Target ALbum '{LrCC:path ^201|?}
- Part 1 (service specific settings): 
	- if you cannot find a match pattern that includes all your local Collection Sets you want to mirror, then create a new root Collection Set, name it e.g. 'By Year' and move all desired Collection Sets below it. Now, you can use the new root Collection Set as match pattern, e.g. '^By Year'. 

- Part 2 (collection membership criteria): 
	- Lr does not support a match criteria for photos such as 'Contained Collection Sets', this is what makes part 2 so difficult when mirroring  whole Collection Sets. So, if you want to define a dynamic Published Smart Collection, the best you can do is to try to define a match for all respective contained (leaf) Collections. If you cannot find a match criteria for all (leaf) Collections to be mirrored, you may consider to use a static Published Collection rather than a dynamic Published Smart Collection
	- If your photo match criteria do not yield all photos that are part of the Collection Set to be mirrored, they will not be published and you won't see that they are missing.
	- If your photo match criteria yield more photos than those that are part of the Collection Set to be mirrored, they will be left as 'New photos to be published'. This is probably a better solution, since you now at least recognize photos missing in the source collections.

## More examples to follow
