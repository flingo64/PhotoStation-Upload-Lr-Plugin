--[[----------------------------------------------------------------------------

PSPublishSupport.lua
Publish support for Lightroom Photo StatLr
Copyright(c) 2015, Martin Messmer

This file is part of Photo StatLr - Lightroom plugin.

Photo StatLr is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Photo StatLr is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Photo StatLr.  If not, see <http://www.gnu.org/licenses/>.

Photo StatLr uses the following free software to do its job:
	- convert.exe,			see: http://www.imagemagick.org/
	- ffmpeg.exe, 			see: https://www.ffmpeg.org/
	- qt-faststart.exe, 	see: http://multimedia.cx/eggs/improving-qt-faststart/

This code is derived from the Lr SDK FTP Export and Flickr sample code. Copyright: see below
--------------------------------------------------------------------------------

ADOBE SYSTEMS INCORPORATED
 Copyright 2007-2010 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.

------------------------------------------------------------------------------]]

	-- Lightroom SDK
local LrApplication =		import 'LrApplication'
local LrBinding	= 			import 'LrBinding'
local LrColor = 			import 'LrColor'
local LrFunctionContext =	import 'LrFunctionContext'
local LrDate = 				import 'LrDate'
local LrDialogs = 			import 'LrDialogs'
local LrHttp = 				import 'LrHttp'
local LrPathUtils = 		import 'LrPathUtils'
local LrPrefs =				import 'LrPrefs'
local LrProgressScope =		import 'LrProgressScope'
local LrView = 				import 'LrView'

local bind 				= LrView.bind
local share 			= LrView.share
local conditionalItem 	= LrView.conditionalItem

require "PSDialogs"
require "PSUtilities"

--===========================================================================--

local publishServiceProvider = {}

--------------------------------------------------------------------------------
--- (string) Plug-in defined value is the filename of the icon to be displayed
 -- for this publish service provider, in the Publish Services panel, the Publish 
 -- Manager dialog, and in the header shown when a published collection is selected.
 -- The icon must be in PNG format and no more than 24 pixels wide or 19 pixels tall.

--publishServiceProvider.small_icon = 'PhotoStation.png'
publishServiceProvider.small_icon = 'PhotoStatLr.png'

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the behavior of the
 -- Description entry in the Publish Manager dialog. If the user does not provide
 -- an explicit name choice, Lightroom can provide one based on another entry
 -- in the publishSettings property table. This entry contains the name of the
 -- property that should be used in this case.
	
-- publishServiceProvider.publish_fallbackNameBinding = 'fullname'

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- collection to match the terminology used on the service you are targeting.
 -- <p>This string is typically used in combination with verbs that take action on
 -- the published collection, such as "Create ^1" or "Rename ^1".</p>
 -- <p>If not provided, Lightroom uses the default name, "Published Collection." </p>
	
publishServiceProvider.titleForPublishedCollection = LOC "$$$/PSPublish/TitleForPublishedCollection=Published Collection"

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- collection to match the terminology used on the service you are targeting.
 -- <p>Unlike <code>titleForPublishedCollection</code>, this string is typically
 -- used by itself. In English, these strings nay be the same, but in
 -- other languages (notably German), you may have to use a different form
 -- of the name to be gramatically correct. If you are localizing your plug-in,
 -- use a separate translation key to make this possible.</p>
 -- <p>If not provided, Lightroom uses the value of
 -- <code>titleForPublishedCollection</code> instead.</p>

publishServiceProvider.titleForPublishedCollection_standalone = LOC "$$$/PSPublish/TitleForPublishedCollection/Standalone=Published Collection"

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- collection set to match the terminology used on the service you are targeting.
 -- <p>This string is typically used in combination with verbs that take action on
 -- the published collection set, such as "Create ^1" or "Rename ^1".</p>
 -- <p>If not provided, Lightroom uses the default name, "Published Collection Set." </p>
	
publishServiceProvider.titleForPublishedCollectionSet = LOC "$$$/PSPublish/TitleForPublishedCollection=Published Collection Set"

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- collection to match the terminology used on the service you are targeting.
 -- <p>Unlike <code>titleForPublishedCollectionSet</code>, this string is typically
 -- used by itself. In English, these strings may be the same, but in
 -- other languages (notably German), you may have to use a different form
 -- of the name to be gramatically correct. If you are localizing your plug-in,
 -- use a separate translation key to make this possible.</p>
 -- <p>If not provided, Lightroom uses the value of
 -- <code>titleForPublishedCollectionSet</code> instead.</p>

publishServiceProvider.titleForPublishedCollectionSet_standalone = LOC "$$$/PSPublish/TitleForPublishedCollection/Standalone=Published Collection Set"

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- smart collection to match the terminology used on the service you are targeting.
 -- <p>This string is typically used in combination with verbs that take action on
 -- the published smart collection, such as "Create ^1" or "Rename ^1".</p>
 -- <p>If not provided, Lightroom uses the default name, "Published Smart Collection." </p>

publishServiceProvider.titleForPublishedSmartCollection = LOC "$$$/PSPublish/TitleForPublishedSmartCollection=Published Smart Collection"

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- smart collection to match the terminology used on the service you are targeting.
 -- <p>Unlike <code>titleForPublishedSmartCollection</code>, this string is typically
 -- used by itself. In English, these strings may be the same, but in
 -- other languages (notably German), you may have to use a different form
 -- of the name to be gramatically correct. If you are localizing your plug-in,
 -- use a separate translation key to make this possible.</p>
 -- <p>If not provided, Lightroom uses the value of
 -- <code>titleForPublishedSmartCollectionSet</code> instead.</p>

publishServiceProvider.titleForPublishedSmartCollection_standalone = LOC "$$$/PSPublish/TitleForPublishedSmartCollection/Standalone=Published Smart Collection"

--------------------------------------------------------------------------------
-- This (optional) plug-in defined callback function is called when publishing has been initiated, 
-- and should simply return true or false to indicate whether any deletion of photos from the service 
-- should take place before any publishing of new images and updating of previously published images.
function publishServiceProvider.deleteFirstOnPublish()
	return false
end

--------------------------------------------------------------------------------
--- (optional) If you provide this plug-in defined callback function, Lightroom calls it to
 -- retrieve the default collection behavior for this publish service, then use that information to create
 -- a built-in <i>default collection</i> for this service (if one does not yet exist). 
 
function publishServiceProvider.getCollectionBehaviorInfo( publishSettings )

	return {
		defaultCollectionName = LOC "$$$/PSPublish/DefaultCollectionName/Collection=Default Collection",
		defaultCollectionCanBeDeleted = true,
		canAddCollection = true,
	}
	
end

--------------------------------------------------------------------------------
--- When set to the string "disable", the "Go to Published Collection" context-menu item
 -- is disabled (dimmed) for this publish service.

publishServiceProvider.titleForGoToPublishedCollection = LOC "$$$/PSPublish/TitleForGoToPublishedCollection=Show in Photo Station"

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user chooses
 -- the "Go to Published Collection" context-menu item.
function publishServiceProvider.goToPublishedCollection( publishSettings, info )
	local albumPath, albumUrl 

	-- make sure logfile is opened
	openLogfile(publishSettings.logLevel)

	albumPath = PSLrUtilities.getCollectionUploadPath(info.publishedCollection)
	
	if PSLrUtilities.isDynamicAlbumPath(albumPath)then 
		showFinalMessage("Photo StatLr: GoToPublishedCollection failed!", "Cannot open dynamic album path: '" .. albumPath .. "'", "critical")
		closeLogfile()
		return
	end

	-- open session: initialize environment, get missing params and login
	local sessionSuccess, reason = openSession(publishSettings, info.publishedCollection, 'GoToPublishedCollection')
	if not sessionSuccess then
		if reason ~= 'cancel' then
			showFinalMessage("Photo StatLr: GoToPublishedCollection failed!", reason, "critical")
		end
		closeLogfile()
		return
	end
	
	albumUrl = PSPhotoStationAPI.getAlbumUrl(publishSettings.uHandle, albumPath)

	LrHttp.openUrlInBrowser(albumUrl)
end

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value overrides the label for the 
 -- "Go to Published Photo" context-menu item, allowing you to use something more appropriate to
 -- your service. Set to the special value "disable" to disable (dim) the menu item for this service. 

publishServiceProvider.titleForGoToPublishedPhoto = LOC "$$$/PSPublish/TitleForGoToPublishedCollection=Show in Photo Station"

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user chooses the
 -- "Go to Published Photo" context-menu item.
function publishServiceProvider.goToPublishedPhoto( publishSettings, info )
	local photoUrl
	
	-- make sure logfile is opened
	openLogfile(publishSettings.logLevel)

	-- open session: initialize environment, get missing params and login
	-- 		now way to get the belgonging publishedCollection here: use nil 
	local sessionSuccess, reason = openSession(publishSettings, nil, 'GoToPublishedPhoto')
	if not sessionSuccess then
		if reason ~= 'cancel' then
			showFinalMessage("Photo StatLr: goToPublishedPhoto failed!", reason, "critical")
		end
		closeLogfile()
		return
	end
	
	photoUrl = PSPhotoStationAPI.getPhotoUrl(publishSettings.uHandle, info.publishedPhoto:getRemoteId(), info.photo:getRawMetadata('isVideo'))
	LrHttp.openUrlInBrowser(photoUrl)
end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user creates
 -- a new publish service via the Publish Manager dialog. It allows your plug-in
 -- to perform additional initialization.
--[[ Not used for Photo StatLr plug-in.

function publishServiceProvider.didCreateNewPublishService( publishSettings, info )
end

--]]

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user creates
 -- a new publish service via the Publish Manager dialog. It allows your plug-in
 -- to perform additional initialization.
--[[ Not used for Photo StatLr plug-in.

function publishServiceProvider.didUpdatePublishService( publishSettings, info )
end

]]--

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has attempted to delete the publish service from Lightroom.
 -- It provides an opportunity for you to customize the confirmation dialog.
 -- @return (string) 'cancel', 'delete', or nil (to allow Lightroom's default
 -- dialog to be shown instead)
--[[ Not used for Photo StatLr plug-in.

function publishServiceProvider.shouldDeletePublishService( publishSettings, info )
end

]]--

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has confirmed the deletion of the publish service from Lightroom.
 -- It provides a final opportunity for	you to remove private data
 -- immediately before the publish service is removed from the Lightroom catalog.
--[[ Not used for Photo StatLr plug-in.

function publishServiceProvider.willDeletePublishService( publishSettings, info )
end

--]]

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has attempted to delete one or more published collections defined by your
 -- plug-in from Lightroom. It provides an opportunity for you to customize the
 -- confirmation dialog.
 -- @return (string) "ignore", "cancel", "delete", or nil
 -- (If you return nil, Lightroom's default dialog will be displayed.)
--[[ Not used for Photo StatLr plug-in.
]]--

function publishServiceProvider.shouldDeletePublishedCollection( publishSettings, info )
end


--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has attempted to delete one or more photos from the Lightroom catalog that are
 -- published through your service. It provides an opportunity for you to customize
 -- the confirmation dialog.
function publishServiceProvider.shouldDeletePhotosFromServiceOnDeleteFromCatalog( publishSettings, nPhotos )
	if nPhotos < 10 then
		return "delete"
	else
		-- ask the user for confirmation
		return nil
	end
end


--------------------------------------------------------------------------------
--- This plug-in defined callback function is called when one or more photos
 -- have been removed from a published collection and need to be removed from
 -- the service. If the service you are supporting allows photos to be deleted
 -- via its API, you should do that from this function.

function publishServiceProvider.deletePhotosFromPublishedCollection(publishSettings, arrayOfPhotoIds, deletedCallback, localCollectionId)
	publishSettings.publishMode = 'Delete'
	local publishedCollection = LrApplication.activeCatalog():getPublishedCollectionByLocalIdentifier(localCollectionId)
	
	-- make sure logfile is opened
	openLogfile(publishSettings.logLevel)

	-- open session: initialize environment, get missing params and login
	local sessionSuccess, reason = openSession(publishSettings, publishedCollection, 'DeletePhotosFromPublishedCollection')
	if not sessionSuccess then
		if reason ~= 'cancel' then
			showFinalMessage("Photo StatLr: Delete photos failed!", reason, "critical")
		end
		closeLogfile()
		return
	end

	local startTime = LrDate.currentTime()
	local nPhotos = #arrayOfPhotoIds
	local nProcessed = 0 
	local albumsForCheckEmpty
	
	for i, photoId in ipairs( arrayOfPhotoIds ) do
		if PSPhotoStationAPI.deletePic (publishSettings.uHandle, photoId, PSLrUtilities.isVideo(photoId)) then
			writeLogfile(2, photoId .. ': successfully deleted.\n')
			albumsForCheckEmpty = PSLrUtilities.noteAlbumForCheckEmpty(albumsForCheckEmpty, photoId)
			nProcessed = nProcessed + 1
			deletedCallback( photoId )
		else
			writeLogfile(1, photoId .. ': deletion failed!\n')
		end
	end

	local nDeletedAlbums = 0 
	local currentAlbum = albumsForCheckEmpty
	
	while currentAlbum do
		nDeletedAlbums = nDeletedAlbums + PSPhotoStationAPI.deleteEmptyAlbumAndParents(publishSettings.uHandle, currentAlbum.albumPath)
		currentAlbum = currentAlbum.next
	end

	local timeUsed 	= LrDate.currentTime() - startTime
	local picPerSec = nProcessed / timeUsed
	local message = LOC ("$$$/PSUpload/Upload/Errors/DeletePhotosFromPublishedCollection=" .. 
					string.format("Deleted %d of %d pics and %d empty albums in %d seconds (%.1f pics/sec).\n", 
					nProcessed, nPhotos, nDeletedAlbums, timeUsed + 0.5, picPerSec))

	showFinalMessage("Photo StatLr: Delete photos done", message, "info")
	closeLogfile()

end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called whenever a new
 -- publish service is created and whenever the settings for a publish service
 -- are changed. It allows the plug-in to specify which metadata should be
 -- considered when Lightroom determines whether an existing photo should be
 -- moved to the "Modified Photos to Re-Publish" status.
function publishServiceProvider.metadataThatTriggersRepublish( publishSettings )

	return {

		default = true,
--[[
		default = false,
		title = true,
		caption = true,
		keywords = true,
		gps = true,
		gpsAltitude = true,
		dateCreated = true,
--		path = true,		-- check for local file movements: doesn't work

		-- also (not used by Flickr sample plug-in):
			-- customMetadata = true,
			-- com.whoever.plugin_name.* = true,
			-- com.whoever.plugin_name.field_name = true,
]]
	}
end

-- updatCollectionStatus: do some sanity checks on Published Collection dialog settings
local function updateCollectionStatus( collectionSettings )
	local prefs = LrPrefs.prefsForPlugin()

	local message = nil
--	local albumPath = PSLrUtilities.getCollectionUploadPath(collectionSettings)
	
	
	repeat
		-- Use a repeat loop to allow easy way to "break" out.
		-- (It only goes through once.)
		
		if collectionSettings.copyTree and not PSDialogs.validateDirectory(nil, collectionSettings.srcRoot) then
			message = LOC "$$$/PSUpload/CollectionDialog/Messages/EnterSubPath=Enter a source path"
			break
		end
				
		-- Exif translation start
		-- if at least one translation is activated then set exifTranslate
		if collectionSettings.exifXlatFaceRegions or collectionSettings.exifXlatLabel or collectionSettings.exifXlatRating then
			collectionSettings.exifTranslate = true
		end
		
		-- if no translation is activated then set exifTranslate to off
		if not (collectionSettings.exifXlatFaceRegions or collectionSettings.exifXlatLabel or collectionSettings.exifXlatRating) then
			collectionSettings.exifTranslate = false
		end
		
		if collectionSettings.exifTranslate and not PSDialogs.validateProgram( nil, prefs.exiftoolprog ) then
			message = LOC "$$$/PSUpload/ExportDialog/Messages/EnterExiftool=Missing or wrong exiftool path. Fix it in Plugin Manager settings section."
			break
		end

		-- downloading translated tags makes only sense if we upload them also, otherwise they would dissappear after re-publish
		if not collectionSettings.exifXlatFaceRegions 	then collectionSettings.PS2LrFaces = false end
		if not collectionSettings.exifXlatLabel 		then collectionSettings.PS2LrLabel = false end
		if not collectionSettings.exifXlatRating 		then collectionSettings.PS2LrRating = false end
		
		-- Exif translation end

	until true
	
	if message then
		collectionSettings.hasError = true
		collectionSettings.message = 'Booo!! ' .. message
		collectionSettings.LR_canSaveCollection = false
	else
		collectionSettings.hasError = false
		collectionSettings.message = nil
		collectionSettings.LR_canSaveCollection = true
	end
	
end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- creates a new published collection or edits an existing one. It can add
 -- additional controls to the dialog box for editing this collection. 
function publishServiceProvider.viewForCollectionSettings( f, publishSettings, info )
	local prefs = LrPrefs.prefsForPlugin()

	local collectionSettings = assert( info.collectionSettings )

	-- observe settings to enable/disable "Store" button
	if collectionSettings.hasError == nil then
		collectionSettings.hasError = false
	end

	if collectionSettings.isCollection == nil then
		collectionSettings.isCollection = true
	end

	if collectionSettings.publishMode == nil then
		collectionSettings.publishMode = 'Publish'
	end

	--============= Album options ===================================
	if collectionSettings.storeDstRoot == nil then
		collectionSettings.storeDstRoot = true
	end

	if collectionSettings.dstRoot == nil then
		collectionSettings.dstRoot = ''
	end

	if collectionSettings.createDstRoot == nil then
		collectionSettings.createDstRoot = false
	end

	if collectionSettings.copyTree == nil then
		collectionSettings.copyTree = false
	end

	if collectionSettings.srcRoot == nil then
		collectionSettings.srcRoot = ''
	end

	if collectionSettings.RAWandJPG == nil then
		collectionSettings.RAWandJPG = false
	end

	if collectionSettings.sortPhotos == nil then
		collectionSettings.sortPhotos = false
	end

	--============= upload options ===================================
--	-- move Upload options from publish service settings to collection settings

	if collectionSettings.exifTranslate == nil then
		collectionSettings.exifTranslate = publishSettings.exifTranslate
	end

	if collectionSettings.exifXlatFaceRegions == nil then
		collectionSettings.exifXlatFaceRegions = publishSettings.exifXlatFaceRegions
	end

	if collectionSettings.exifXlatRating == nil then
		collectionSettings.exifXlatRating = publishSettings.exifXlatRating
	end

	if collectionSettings.exifXlatLabel == nil then
		collectionSettings.exifXlatLabel = publishSettings.exifXlatLabel
	end

	--============= download options ===================================
	if collectionSettings.commentsDownload == nil then
		collectionSettings.commentsDownload = false
	end

	if collectionSettings.captionDownload == nil then
		collectionSettings.captionDownload = false
	end

	if collectionSettings.tagsDownload == nil then
		collectionSettings.tagsDownload = false
	end

	if collectionSettings.locationDownload == nil then
		collectionSettings.locationDownload = false
	end

	if collectionSettings.PS2LrFaces == nil then
		collectionSettings.PS2LrFaces = false
	end

	if collectionSettings.PS2LrLabel == nil then
		collectionSettings.PS2LrLabel = false
	end

	if collectionSettings.PS2LrRating == nil then
		collectionSettings.PS2LrRating = false
	end
	
	collectionSettings:addObserver( 'srcRoot', updateCollectionStatus )
	collectionSettings:addObserver( 'copyTree', updateCollectionStatus )
	collectionSettings:addObserver( 'publishMode', updateCollectionStatus )
	collectionSettings:addObserver( 'exifXlatFaceRegions', updateCollectionStatus )
	collectionSettings:addObserver( 'exifXlatLabel', updateCollectionStatus )
	collectionSettings:addObserver( 'exifXlatRating', updateCollectionStatus )
	
	updateCollectionStatus( collectionSettings )
		
	return f:view {
--		size = 'small',
		fill_horizontal = 1,
		bind_to_object = assert( collectionSettings ),
		
    	f:column {
    		fill_horizontal = 1,
    		spacing = f:label_spacing(),
			PSDialogs.collectionHeaderView(f, collectionSettings),
			
			PSDialogs.targetAlbumView(f, collectionSettings),

    		f:spacer { height = 10, },
    
            PSDialogs.uploadOptionsView(f, collectionSettings),
 
 	  		f:spacer { height = 10, },
    
            PSDialogs.downloadOptionsView(f, collectionSettings),
 
 	  		f:spacer { height = 10, },
    
 
            PSDialogs.publishModeView(f, collectionSettings),

    		f:spacer { height = 10, },
    		
    		f:row {
    			alignment = 'left',
    
    			f:static_text {
    				title = bind 'message',
    				text_color = LrColor("red"),
    				fill_horizontal = 1,
    				visible = bind 'hasError'
    			},
    		}, --row
		}, --column
	} -- view

end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has changed the per-collection settings defined via the <code>viewForCollectionSettings</code>
 -- callback. It is your opportunity to update settings on your web service to
 -- match the new settings.

function publishServiceProvider.updateCollectionSettings(publishSettings, info)
	local collectionSettings = assert( info.collectionSettings )
end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- closes the dialog for creating a new published collection or editing an existing
 -- one. 
--[[ Not used for Photo StatLr plug-in.

function publishServiceProvider.endDialogForCollectionSettings( publishSettings, info )
	-- not used for Photo StatLr plug-in
end

--]]

-- updatCollectionSetStatus: do some sanity checks on Published Collection Set dialog settings
local function updateCollectionSetStatus( collectionSetSettings )
	
	local message = nil

--[[
	repeat
		-- Use a repeat loop to allow easy way to "break" out.
		-- (It only goes through once.)
		
		if collectionSetSettings.baseDir .... then
			message = LOC "$$$/PSUpload/CollectionDialog/Messages/EnterSubPath=Enter a source path"
			break
		end
				
	until true
]]	
	if message then
		collectionSetSettings.hasError = true
		collectionSetSettings.message = message
		collectionSetSettings.LR_canSaveCollection = false
	else
		collectionSetSettings.hasError = false
		collectionSetSettings.message = nil
		collectionSetSettings.LR_canSaveCollection = true
	end
	
end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- creates a new published collection set or edits an existing one. It can add
 -- additional controls to the dialog box for editing this collection set. 

function publishServiceProvider.viewForCollectionSetSettings( f, publishSettings, info )
	local collectionSetSettings = assert( info.collectionSettings )

	-- observe settings to enable/disable "Store" button
	if collectionSetSettings.hasError == nil then
		collectionSetSettings.hasError = false
	end

	collectionSetSettings:addObserver( 'baseDir', updateCollectionSetStatus )
	updateCollectionSetStatus( collectionSetSettings )
		
	if collectionSetSettings.baseDir == nil then
		collectionSetSettings.baseDir = ''
	end

	return f:group_box {
		title = "Photo StatLr Settings",  -- this should be localized via LOC
--		size = 'small',
		fill_horizontal = 1,
		bind_to_object = assert( collectionSetSettings ),
		
		f:column {
			fill_horizontal = 1,
			spacing = f:label_spacing(),

			f:row {
				f:static_text {
					title = LOC "$$$/PSUpload/ExportDialog/StoreDstRoot=Target Album:",
					alignment = 'right',
					width = share 'labelWidth'
				},

				f:edit_field {
					tooltip = LOC "$$$/PSUpload/ExportDialog/DstRootTT=Enter the target directory below the diskstation share '/photo' or '/home/photo'\n(may be different from the Album name shown in Photo Station)",
					value = bind 'baseDir',
					truncation = 'middle',
					immediate = true,
					fill_horizontal = 1,
				},

			},
			
			f:row {
				alignment = 'left',

				f:static_text {
					title = bind 'message',
					fill_horizontal = 1,
					visible = bind 'hasError'
				},
			}, --row
		}, --column
	} --group

end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- closes the dialog for creating a new published collection set or editing an existing
 -- one. 
--[[ Not used for Photo StatLr plug-in.

function publishServiceProvider.endDialogForCollectionSetSettings( publishSettings, info )
	-- not used for Photo StatLr plug-in
end

--]]

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has changed the per-collection set settings defined via the <code>viewForCollectionSetSettings</code>
 -- callback. It is your opportunity to update settings on your web service to
 -- match the new settings.
--[[ Not used for Photo StatLr plug-in.

function publishServiceProvider.updateCollectionSetSettings( publishSettings, info )
end

--]]

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when new or updated
 -- photos are about to be published to the service. It allows you to specify whether
 -- the user-specified sort order should be followed as-is or reversed.
--[[ Not used for Photo StatLr plug-in.

function publishServiceProvider.shouldReverseSequenceForPublishedCollection( publishSettings, collectionInfo )

	return false

end
]]

--------------------------------------------------------------------------------
--- (Boolean) If this plug-in defined property is set to true, Lightroom will
 -- enable collections from this service to be sorted manually and will call
 -- the <a href="#publishServiceProvider.imposeSortOrderOnPublishedCollection"><code>imposeSortOrderOnPublishedCollection</code></a>
 -- callback to cause photos to be sorted on the service after each Publish
publishServiceProvider.supportsCustomSortOrder = true
	
--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called after each time
 -- that photos are published via this service assuming the published collection
 -- is set to "User Order." Your plug-in should ensure that the photos are displayed
 -- in the designated sequence on the service.
function publishServiceProvider.imposeSortOrderOnPublishedCollection( publishSettings, info, remoteIdSequence )
	openLogfile(publishSettings.logLevel)
	writeLogfile(3, "imposeSortOrderOnPublishedCollection: starting\n")

	-- get publishedCollections: 
	--   remoteCollectionId is the only collectionId we have here, so it must be equal to localCollectionId to retrieve the publishedCollection!!!
	local publishedCollection = LrApplication.activeCatalog():getPublishedCollectionByLocalIdentifier(info.remoteCollectionId)
	local albumPath = PSLrUtilities.getCollectionUploadPath(publishedCollection)

	-- make sure logfile is opened

	-- open session: initialize environment, get missing params and login
	local sessionSuccess, reason = openSession(publishSettings, publishedCollection, 'ImposeSortOrderOnPublishedCollection')
	if not sessionSuccess then
		if reason ~= 'cancel' then
			showFinalMessage("Photo StatLr: Sort Photos in Album failed!", reason, "critical")
		end
		closeLogfile(publishSettings)
		return false
	end

	-- do not sort if not configured or is Tree Mirror or Target Album is dynamic 
	if not publishSettings.sortPhotos or publishSettings.copyTree then
		writeLogfile(3, "imposeSortOrderOnPublishedCollection: nothing to sort, done.\n")
		return false
	elseif PSLrUtilities.isDynamicAlbumPath(publishSettings.dstRoot) then
		writeLogfile(3, "imposeSortOrderOnPublishedCollection: Cannot sort photo: target album is dynamic!\n")
		return false
	end
	
	PSPhotoStationAPI.sortPics(publishSettings.uHandle, albumPath, remoteIdSequence)

	showFinalMessage("Photo StatLr: Sort Photos in Album done", "Sort Photos in Album done.", "info")

	closeLogfile(publishSettings)

	return true
end

-------------------------------------------------------------------------------
--- This plug-in defined callback function is called when the user attempts to change the name
 -- of a collection, to validate that the new name is acceptable for this service.
--[[ Not used for Photo StatLr plug-in.

function publishServiceProvider.validatePublishedCollectionName( proposedName )
	return true
end

--]]

-------------------------------------------------------------------------------
--- (Boolean) This plug-in defined value, when true, disables (dims) the Rename Published
 -- Collection command in the context menu of the Publish Services panel 
 -- for all published collections created by this service. 
publishServiceProvider.disableRenamePublishedCollection = false

-------------------------------------------------------------------------------
--- (Boolean) This plug-in defined value, when true, disables (dims) the Rename Published
 -- Collection Set command in the context menu of the Publish Services panel
 -- for all published collection sets created by this service. 

publishServiceProvider.disableRenamePublishedCollectionSet = false

-------------------------------------------------------------------------------
--- This plug-in callback function is called when the user has renamed a
 -- published collection via the Publish Services panel user interface. This is
 -- your plug-in's opportunity to make the corresponding change on the service.

 function publishServiceProvider.renamePublishedCollection( publishSettings, info )
	return
end

-------------------------------------------------------------------------------
--- This plug-in callback function is called when the user has reparented a
 -- published collection via the Publish Services panel user interface. This is
 -- your plug-in's opportunity to make the corresponding change on the service.

--[[ Not used for Photo StatLr plug-in.

function publishServiceProvider.reparentPublishedCollection( publishSettings, info )
end

]]--

-------------------------------------------------------------------------------
--- This plug-in callback function is called when the user has deleted a
 -- published collection via the Publish Services panel user interface. This is
 -- your plug-in's opportunity to make the corresponding change on the service.
function publishServiceProvider.deletePublishedCollection( publishSettings, info )

	-- make sure logfile is opened
	openLogfile(publishSettings.logLevel)

	-- open session: initialize environment, get missing params and login
	local sessionSuccess, reason = openSession(publishSettings, info.publishedCollection, 'DeletePublishedCollection')
	if not sessionSuccess then
		if reason ~= 'cancel' then
			showFinalMessage("Photo StatLr: deletePublishedCollection failed!", reason, "critical")
		end
		closeLogfile()
		return
	end
	
	if info.publishedCollection:type() == 'LrPublishedCollectionSet' then
		writeLogfile(2, "deletePublishedCollection: Published Collection Set - nothing to do.\n")
		return
	end
	
	writeLogfile(3, "deletePublishedCollection: starting\n")
	local publishedPhotos = info.publishedCollection:getPublishedPhotos() 
	local startTime = LrDate.currentTime()
	local nPhotos = #publishedPhotos
	local nProcessed = 0 
	
	writeLogfile(2, string.format("deletePublishedCollection: deleting %d published photos from collection %s\n", nPhotos, info.name ))

	local progressScope = LrProgressScope ( {
							title = LOC( "$$$/PSPublish/DeletingCollectionAndContents=Deleting collection ^[^1^]", info.name ),
--								functionContext = context,
						 }) 
						
	local albumsForCheckEmpty
	local canceled = false

	for i = 1, nPhotos do
		if progressScope:isCanceled() then 
			canceled = true
			break 
		end
		
		local pubPhoto = publishedPhotos[i]
		local publishedPath = pubPhoto:getRemoteId()

		writeLogfile(2, string.format("deletePublishedCollection: deleting %s from  %s\n ", publishedPath, info.name ))

--			if publishedPath ~= nil then PSFileStationAPI.deletePic(publishSettings.fHandle, publishedPath) end
		if PSPhotoStationAPI.deletePic(publishSettings.uHandle, publishedPath, PSLrUtilities.isVideo(publishedPath)) then
			writeLogfile(2, publishedPath .. ': successfully deleted.\n')
			nProcessed = nProcessed + 1
			albumsForCheckEmpty = PSLrUtilities.noteAlbumForCheckEmpty(albumsForCheckEmpty, publishedPath)
		else
			writeLogfile(1, publishedPath .. ': deletion failed!\n')
		end
		progressScope:setPortionComplete(nProcessed, nPhotos)
	end 
		
	local nDeletedAlbums = 0 
	local currentAlbum = albumsForCheckEmpty
	
	while currentAlbum do
		nDeletedAlbums = nDeletedAlbums + PSPhotoStationAPI.deleteEmptyAlbumAndParents(publishSettings.uHandle, currentAlbum.albumPath)
		currentAlbum = currentAlbum.next
	end
	
	progressScope:done()
	
	local timeUsed 	= LrDate.currentTime() - startTime
	local picPerSec = nProcessed / timeUsed
	local message = LOC ("$$$/PSUpload/Upload/Errors/DeletePublishedColletion=" .. 
					string.format("Deleted %d of %d pics and %d empty albums in %d seconds (%.1f pics/sec).\n", 
					nProcessed, nPhotos, nDeletedAlbums, timeUsed + 0.5, picPerSec))

	showFinalMessage("Photo StatLr: DeletePublishedCollection done", message, "info")
	closeLogfile()
	
end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called (if supplied)  
 -- to retrieve comments from the remote service, for a single collection of photos 
 -- that have been published through this service.
 -- 	publishSettings (table) The settings for this publish service, as specified
		-- by the user in the Publish Manager dialog. Any changes that you make in
		-- this table do not persist beyond the scope of this function call.
 --		arrayOfPhotoInfo (table) An array of tables with a member table for each photo.
		-- Each member table has these fields:
			-- photo: 			The photo object
			-- publishedPhoto:	The publishing data for that photo
			-- remoteId: (string or number) The remote systems unique identifier
					-- 	for the photo, as previously recorded by the plug-in
			-- url: (string, optional) The URL for the photo, as assigned by the
					--	remote service and previously recorded by the plug-in.
			-- commentCount: (number) The number of existing comments
					-- 	for this photo in Lightroom's catalog database.
 -- 	commentCallback (function) A callback function that your implementation should call to record
 -- 
function publishServiceProvider.getCommentsFromPublishedCollection( publishSettings, arrayOfPhotoInfo, commentCallback )
	-- get the belonging Published Collection by evaluating the first photo
	local nPhotos =  #arrayOfPhotoInfo
	local containedPublishedCollections 
	local publishedCollection, publishedCollectionName
	local nProcessed = 0 
	local nComments = 0 
	
	-- make sure logfile is opened
	openLogfile(publishSettings.logLevel)

	if publishSettings.operationCanceled then
		writeLogfile(2, string.format("Get comments: canceled by user\n"))
		return
	end
	
	if nPhotos == 0 then
		writeLogfile(2, string.format("Get comments: nothing to do.\n"))
		closeLogfile()
		return
	elseif arrayOfPhotoInfo[1].url == nil then
		showFinalMessage("Photo StatLr: Get comments failed!", 'Cannot sync comments on old-style collection.\nPlease convert this collection first!', "critical")
		closeLogfile()
		return
	end

	-- the remoteUrl contains the local collection identifier
	publishedCollection = LrApplication.activeCatalog():getPublishedCollectionByLocalIdentifier(tonumber(string.match(arrayOfPhotoInfo[1].url, '(%d+)')))
	if not publishedCollection then
		showFinalMessage("Photo StatLr: Get comments failed!", 'Cannot sync comments on corrupted collection.\nPlease convert this collection first!', "critical")
		closeLogfile()
		return
	end	
	
	if not publishedCollection:getCollectionInfoSummary().collectionSettings.commentsDownload then
		writeLogfile(2, string.format("Get comments: comments not enabled for this collection.\n"))
		closeLogfile()
		return
	end
		
	publishedCollectionName = publishedCollection:getName()
	writeLogfile(2, string.format("Get comments for %d photos in collection %s.\n", nPhotos, publishedCollectionName))

	-- open session: initialize environment, get missing params and login
	local sessionSuccess, reason = openSession(publishSettings, publishedCollection, 'GetCommentsFromPublishedCollection')
	if not sessionSuccess then
		if reason ~= 'cancel' then
			showFinalMessage("Photo StatLr: Get comments failed!", reason, "critical")
		else
			writeLogfile(2, string.format("Get comments: canceled by user\n"))
			publishSettings.operationCanceled = true
		end
		closeLogfile()
		return
	end

	local startTime = LrDate.currentTime()

	local progressScope = LrProgressScope( 
								{ 	title = LOC( "$$$/PSPublish/GetCommentsFromPublishedCollection=Downloading comments for collection ^[^1^]", publishedCollection:getName()),
--							 		functionContext = context 
							 	})    
	for i, photoInfo in ipairs( arrayOfPhotoInfo ) do
		if progressScope:isCanceled() then break end

		local comments = PSPhotoStationAPI.getPhotoComments(publishSettings.uHandle, photoInfo.remoteId, photoInfo.photo:getRawMetadata('isVideo'))
		
		if not comments then
			writeLogfile(1, string.format("Get comments: %s failed!\n", photoInfo.remoteId))
		else
    		local commentList = {}
    
    		if comments and #comments > 0 then
    
    			for _, comment in ipairs( comments ) do
    				local year, month, day, hour, minute, second = string.match(comment.date, '(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d)')
    
    				table.insert( commentList, {
    								commentId = comment.id,
    								commentText = comment.comment,
    								dateCreated = LrDate.timeFromComponents(year, month, day, hour, minute, second, 'local'),
	   								username = comment.name,
	  								realname = comment.email,
--    								url = PSPhotoStationAPI.getPhotoUrl(publishSettings.uHandle, photoInfo.remoteId, photoInfo.photo:getRawMetadata('isVideo'))
    							} )
    			end			
    
    		end	
			writeLogfile(2, string.format("Get comments: %s - %d comments\n", photoInfo.remoteId, #commentList))
			writeTableLogfile(4, "commentList", commentList)
    		commentCallback({publishedPhoto = photoInfo, comments = commentList})
    		nComments = nComments + #comments
		end
   		nProcessed = nProcessed + 1
   		progressScope:setPortionComplete(nProcessed, nPhotos) 						    
	end 
	progressScope:done()

	local timeUsed 	= LrDate.currentTime() - startTime
	local picPerSec = nProcessed / timeUsed
	local message = LOC ("$$$/PSUpload/Upload/Errors/GetCommentsFromPublishedCollection=" .. 
					string.format("Got %d comments for  %d of %d pics in %d seconds (%.1f pics/sec).", 
					nComments, nProcessed, nPhotos, timeUsed + 0.5, picPerSec))

	showFinalMessage("Photo StatLr: Get comments done", message, "info")
	return true
end

--------------------------------------------------------------------------------
--- (optional, string) This plug-in defined property allows you to customize the
 -- name of the viewer-defined ratings that are obtained from the service via
 -- <a href="#publishServiceProvider.getRatingsFromPublishedCollection"><code>getRatingsFromPublishedCollection</code></a>.
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name publishServiceProvider.titleForPhotoRating
	-- @class property

publishServiceProvider.titleForPhotoRating = LOC "$$$/PSPublish/TitleForPhotoRating=Photo Rating"

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called (if supplied)
 -- to retrieve ratings from the remote service, for a single collection of photos 
 -- that have been published through this service. This function is called:
    -- For every photo in the published collection each time any photo in the collection is published or re-published.
 	-- When the user clicks the Refresh button in the Library module's Comments panel.
	-- After the user adds a new comment to a photo in the Library module's Comments panel.
function publishServiceProvider.getRatingsFromPublishedCollection( publishSettings, arrayOfPhotoInfo, ratingCallback )
	-- get the belonging Published Collection by evaluating the first photo
	local nPhotos =  #arrayOfPhotoInfo
	local containedPublishedCollections 
	local publishedCollection, publishedCollectionName
	local nProcessed 		= 0 
	local nChanges 			= 0 
	local nRejectedChanges	= 0 
	local nFailed			= 0 
	
	-- make sure logfile is opened
	openLogfile(publishSettings.logLevel)

	if publishSettings.operationCanceled then
		writeLogfile(2, string.format("Get metadata: canceled by user\n"))
		return
	end
	
	if nPhotos == 0 then
		writeLogfile(2, string.format("Get metadata: nothing to do.\n"))
		closeLogfile()
		return
	elseif arrayOfPhotoInfo[1].url == nil then
		showFinalMessage("Photo StatLr: Get ratings failed!", 'Cannot sync ratings on old-style collection.\nPlease convert this collection first!', "critical")
		closeLogfile()
		return
	end

	-- the remoteUrl contains the local collection identifier
	publishedCollection = LrApplication.activeCatalog():getPublishedCollectionByLocalIdentifier(tonumber(string.match(arrayOfPhotoInfo[1].url, '(%d+)')))
	if not publishedCollection then
		showFinalMessage("Photo StatLr: Get ratings failed!", 'Cannot sync ratings on corrupted collection.\nPlease convert this collection first!', "critical")
		closeLogfile()
		return
	end	
	
	local collectionSettings = publishedCollection:getCollectionInfoSummary().collectionSettings
	if 		not collectionSettings.titleDownload 
		and not collectionSettings.captionDownload 
--		and not collectionSettings.locationDownload 
		and not collectionSettings.tagsDownload 
		and not collectionSettings.PS2LrFaces 
		and not collectionSettings.PS2LrLabel 
		and not collectionSettings.PS2LrRating 
	then
		writeLogfile(2, string.format("Get metadata: Metadata download is not enabled for this collection.\n"))
		closeLogfile()
		return
	end
		
	publishedCollectionName = publishedCollection:getName()
	writeLogfile(2, string.format("Get ratings for %d photos in collection %s.\n", nPhotos, publishedCollectionName))

	-- open session: initialize environment, get missing params and login
	local sessionSuccess, reason = openSession(publishSettings, publishedCollection, 'GetRatingsFromPublishedCollection')
	if not sessionSuccess then
		if reason ~= 'cancel' then
			showFinalMessage("Photo StatLr: Get ratings failed!", reason, "critical")
		else
			writeLogfile(2, string.format("Get metadata: canceled by user\n"))
			publishSettings.operationCanceled = true
		end
		closeLogfile()
		return
	end

	local reloadPhotos = {}
	local startTime = LrDate.currentTime()

	local catalog = LrApplication.activeCatalog()
	local progressScope = LrProgressScope( 
								{ 	title = LOC( "$$$/PSPublish/GetRatingsFromPublishedCollection=Downloading ratings for collection ^[^1^]", publishedCollection:getName()),
--							 		functionContext = context 
							 	})    
	for i, photoInfo in ipairs( arrayOfPhotoInfo ) do
		if progressScope:isCanceled() then break end

		local srcPhoto 		= photoInfo.photo

		local titlePS,		titleChanged
		local captionPS, 	captionChanged
--		local gpsPS,		gpsChanged = { latitude = 0, longitude = 0, }		-- GPS data from photo or from user tagging 
		local ratingPS, 	ratingChanged
		local labelPS,		labelChanged
		local tagsPS, 		tagsChanged = {}
		local facesPS, 		facesChanged = {}
		local origPhotoDimension
		local keywordNamesAdd, keywordNamesRemove, keywordsRemove
		local facesAdd, facesRemove
		local resultText = ''
		local changesRejected = 0		
		
		local needRepublish = false
		
		local photoLastUpload = string.match(photoInfo.url, '%d+/(%d+)')
		
		if photoInfo.publishedPhoto:getEditedFlag() then
			-- do not download infos to original photo for unpublished photos
			writeLogfile(2, string.format("Get metadata: %s - latest version not published, skip download.\n", photoInfo.remoteId))
		elseif tonumber(ifnil(photoLastUpload, '0')) > (LrDate.currentTime() - 60) then 
			writeLogfile(2, string.format("Get metadata: %s - recently uploaded, skip download.\n", photoInfo.remoteId))
		else		 
    		
    		------------------------------------------------------------------------------------------------------
    		-- get title and caption from Photo Station

    		if 		collectionSettings.titleDownload 
    			or  collectionSettings.captionDownload 
--    			or  collectionSettings.locationDownload
    		then
    			local photoInfo = PSPhotoStationAPI.getPhotoInfo(publishSettings.uHandle, photoInfo.remoteId, srcPhoto:getRawMetadata('isVideo'))
        		if photoInfo then
        			if collectionSettings.titleDownload 	then titlePS = photoInfo.title end 
        			if collectionSettings.captionDownload	then captionPS = photoInfo.description end 
--[[
        			if collectionSettings.locationDownload	then 
        				gpsPS.latitude	= tonumber(ifnil(photoInfo.lat, '0'))
        				gpsPS.longitude	= tonumber(ifnil(photoInfo.lng, '0'))
        			end
]]
        		end
    		end
    		
    		------------------------------------------------------------------------------------------------------
    		-- get tags and translated tags (rating, label) from Photo Station if configured
    		if 		collectionSettings.tagsDownload
--    			or  collectionSettings.locationDownload 
    			or  collectionSettings.PS2LrFaces 
    			or  collectionSettings.PS2LrLabel 
    			or  collectionSettings.PS2LrRating 
    		then
    			local photoTags = PSPhotoStationAPI.getPhotoTags(publishSettings.uHandle, photoInfo.remoteId, photoInfo.photo:getRawMetadata('isVideo'))
    		
        		if not photoTags then
        			writeLogfile(1, string.format("Get metadata: %s failed!\n", photoInfo.remoteId))
        		elseif photoTags and #photoTags > 0 then
    				for i = 1, #photoTags do
    					local photoTag = photoTags[i]
    					writeLogfile(4, string.format("Get metadata: found tag type %s name %s\n", photoTag.type, photoTag.name))
    					
        				-- a people tag has a face region in additional.info structure
        				if collectionSettings.PS2LrFaces and photoTag.type == 'people' then
    						table.insert(facesPS, photoTag.additional.info)
        				
        				-- a color label looks like '+red, '+yellow, '+green', '+blue', '+purple' (case-insensitive)
    					elseif collectionSettings.PS2LrLabel and photoTag.type == 'desc' and string.match(photoTag.name, '%+(%a+)') then
    						labelPS = string.match(string.lower(photoTag.name), '%+(%a+)')
    
       					-- ratings look like general tag '*', '**', ... '*****'
        				elseif collectionSettings.PS2LrRating and photoTag.type == 'desc' and string.match(photoTag.name, '([%*]+)') then
    						ratingPS = math.min(string.len(photoTag.name), 5)
    					
    					-- any other general tag is taken as-is
    					elseif collectionSettings.tagsDownload and photoTag.type == 'desc' and not string.match(photoTag.name, '%+(%a+)') and not string.match(photoTag.name, '([%*]+)') then
    						table.insert(tagsPS, photoTag.name)
    					
--[[
    					-- geo tag as added by a user, overwrites photo gps data from exif if existing
    					elseif collectionSettings.locationDownload and photoTag.type == 'geo' and (photoTag.additional.info.lat or photoTag.additional.info.lng) then
            				gpsPS.latitude	= tonumber(ifnil(photoTag.additional.info.lat, 0))
            				gpsPS.longitude	= tonumber(ifnil(photoTag.additional.info.lng, 0))
]]
    					end 
        			end
        		end
        					
    		end

    		ratingCallback({ publishedPhoto = photoInfo, rating = ratingPS or 0 })
    
--    		writeLogfile(3, string.format("Get metadata: %s - title '%s' caption '%s', location '%s/%s' rating %d, label '%s', %d general tags, %d faces\n", 
--   							photoInfo.remoteId, ifnil(titlePS, ''), ifnil(captionPS, ''), tostring(gpsPS.latitude), tostring(gpsPS.longitude),
--    							ifnil(ratingPS, 0), ifnil(labelPS, ''), #tagsPS, #facesPS))
    		writeLogfile(3, string.format("Get metadata: %s - title '%s' caption '%s', rating %d, label '%s', %d general tags, %d faces\n", 
    							photoInfo.remoteId, ifnil(titlePS, ''), ifnil(captionPS, ''), ifnil(ratingPS, 0), ifnil(labelPS, ''), #tagsPS, #facesPS))

    		------------------------------------------------------------------------------------------------------
    		-- title can be stored in two places in PS: in title tag (when entered by PS user) and in exif 'Object Name' (when set by Lr)
   			-- title tag overwrites exif tag, get Object Name only, if no title tag was found

    		if 	collectionSettings.titleDownload 
    		and (not titlePS or titlePS == '' or titlePS == defaultTitlePS) then
				local exifsPS = PSPhotoStationAPI.getPhotoExifs(publishSettings.uHandle, photoInfo.remoteId, photoInfo.photo:getRawMetadata('isVideo'))
				if exifsPS then 
					local namePS = findInTable(exifsPS, 'label', 'Object Name', 'value')
					if namePS then 
						writeLogfile(3, string.format("Get metadata: %s - found title %s in exifs\n", photoInfo.remoteId, namePS))
						titlePS = namePS 
					end
				end
			end


    		------------------------------------------------------------------------------------------------------
			if collectionSettings.titleDownload then
        		local defaultTitlePS = LrPathUtils.removeExtension(LrPathUtils.leafName(photoInfo.remoteId))

	    		-- title can be stored in two places in PS: in title tag (when entered by PS user) and in exif 'Object Name' (when set by Lr)
   				-- title tag overwrites exif tag, get Object Name only, if no title was found
        		if (not titlePS or titlePS == '' or titlePS == defaultTitlePS) then
    				local exifsPS = PSPhotoStationAPI.getPhotoExifs(publishSettings.uHandle, photoInfo.remoteId, photoInfo.photo:getRawMetadata('isVideo'))
    				if exifsPS then 
    					local namePS = findInTable(exifsPS, 'label', 'Object Name', 'value')
    					if namePS then 
    						writeLogfile(3, string.format("Get metadata: %s - found title %s in exifs\n", photoInfo.remoteId, namePS))
    						titlePS = namePS 
    					end
    				end
    			end
    			
        		-- check if PS title is not empty, is not the Default PS title (filename) and is different to Lr
        		if titlePS and titlePS ~= '' and titlePS ~= defaultTitlePS and titlePS ~= ifnil(srcPhoto:getFormattedMetadata('title'), '') then
        			titleChanged = true
        			nChanges = nChanges + 1
        			resultText = resultText ..  string.format(" title changed from '%s' to '%s',", 
        												ifnil(srcPhoto:getFormattedMetadata('title'), ''), titlePS)
        			writeLogfile(3, string.format("Get metadata: %s - title changed from '%s' to '%s'\n", 
        											photoInfo.remoteId, ifnil(srcPhoto:getFormattedMetadata('title'), ''), titlePS))
        											
        		elseif (not titlePS or titlePS == '' or titlePS == defaultTitlePS) and ifnil(srcPhoto:getFormattedMetadata('title'), '') ~= '' then
        			resultText = resultText ..  string.format(" title %s removal ignored,", srcPhoto:getFormattedMetadata('title'))
        			writeLogfile(3, string.format("Get metadata: %s - title %s was removed, setting photo to edited.\n", 
        										photoInfo.remoteId, srcPhoto:getFormattedMetadata('title')))
        			needRepublish = true
        			changesRejected = changesRejected + 1        		
        			nRejectedChanges = nRejectedChanges + 1        		
        		end
			end
			    
    		------------------------------------------------------------------------------------------------------
			if collectionSettings.captionDownload then
        		-- check if PS caption is not empty and is different to Lr
        		if captionPS and captionPS ~= '' and captionPS ~= ifnil(srcPhoto:getFormattedMetadata('caption'), '') then
        			captionChanged = true
        			nChanges = nChanges + 1
        			resultText = resultText ..  string.format(" caption changed from '%s' to '%s',", 
        												ifnil(srcPhoto:getFormattedMetadata('caption'), ''), captionPS)
        			writeLogfile(3, string.format("Get metadata: %s - caption changed from '%s' to '%s'\n", 
        											photoInfo.remoteId, ifnil(srcPhoto:getFormattedMetadata('caption'), ''), captionPS))
        		elseif ifnil(captionPS, '') == '' and ifnil(srcPhoto:getFormattedMetadata('caption'), '') ~= '' then
        			resultText = resultText ..  string.format(" caption %s removal ignored,", srcPhoto:getFormattedMetadata('caption'))
        			writeLogfile(3, string.format("Get metadata: %s - caption %s was removed, setting photo to edited.\n", 
        										photoInfo.remoteId, srcPhoto:getFormattedMetadata('caption')))
        			needRepublish = true        		
        			changesRejected = changesRejected + 1        		
        			nRejectedChanges = nRejectedChanges + 1        		
        		end
    		end
    
--[[
    		------------------------------------------------------------------------------------------------------
			if collectionSettings.locationDownload then
        		-- check if PS location is not empty and is different to Lr
        		local gpsLr = srcPhoto:getRawMetadata('gps')
        		if not gpsLr then gpsLr = { latitude = 0, longitude = 0 } end  
        		gpsLr.latitude = ifnil(gpsLr.latitude, 0)	
        		gpsLr.longitude = ifnil(gpsLr.longitude, 0)	

        		if 	(gpsPS.latitude ~= 0 or gpsPS.longitude ~= 0) 
        		and (math.abs(gpsPS.latitude - gpsLr.latitude) > 0.00001 or math.abs(gpsPS.longitude - gpsLr.longitude) > 0.00001) then
        			gpsChanged = true
        			nChanges = nChanges + 1
        			resultText = resultText ..  string.format(" location changed from '%s/%s' to '%s/%s',", 
        												tostring(gpsLr.latitude), tostring(gpsLr.longitude),
        												tostring(gpsPS.latitude), tostring(gpsPS.longitude))
        			writeLogfile(3, string.format("Get metadata: %s - location changed from '%s/%s' to '%s/%s'\n", 
        											photoInfo.remoteId, 
       												tostring(gpsLr.latitude), tostring(gpsLr.longitude),
       												tostring(gpsPS.latitude), tostring(gpsPS.longitude)))

        		elseif	(gpsPS.latitude == 0 and  gpsPS.longitude == 0) 
        		and 	(gpsLr.latitude ~= 0 or gpsLr.longitude ~= 0) then
        			resultText = resultText ..  string.format(" location removal ignored,")
        			writeLogfile(3, string.format("Get metadata: %s - location was removed, setting photo to edited.\n", 
        										photoInfo.remoteId))
        			needRepublish = true        		
        			changesRejected = changesRejected + 1        		
        			nRejectedChanges = nRejectedChanges + 1        		
        		end
    		end
]]    

    		------------------------------------------------------------------------------------------------------
    		if collectionSettings.PS2LrLabel then
	    		-- check if PS label is not empty and is different to Lr
        		if labelPS and labelPS ~= photoInfo.photo:getRawMetadata('colorNameForLabel') then
        			labelChanged = true
        			nChanges = nChanges + 1  
        			resultText = resultText ..  string.format(" label changed from %s to %s,", 
        												srcPhoto:getRawMetadata('colorNameForLabel'), labelPS)
        			writeLogfile(3, string.format("Get metadata: %s - label changed from %s to %s\n", 
        										photoInfo.remoteId, srcPhoto:getRawMetadata('colorNameForLabel'), labelPS))
        		elseif not labelPS and photoInfo.photo:getRawMetadata('colorNameForLabel') ~= 'grey' then
        			resultText = resultText ..  string.format(" label %s removal ignored,", srcPhoto:getRawMetadata('colorNameForLabel'))
        			writeLogfile(3, string.format("Get metadata: %s - label %s was removed, setting photo to edited.\n", 
        										photoInfo.remoteId, srcPhoto:getRawMetadata('colorNameForLabel')))
        			needRepublish = true
        			changesRejected = changesRejected + 1        		
        			nRejectedChanges = nRejectedChanges + 1        		
        		end
    		end
    
    		------------------------------------------------------------------------------------------------------
    		if collectionSettings.PS2LrRating then
        		-- check if PS rating is not empty and is different to Lr
        		if ratingPS and ratingPS ~= ifnil(photoInfo.photo:getRawMetadata('rating'), 0) then
        			ratingChanged = true
        			nChanges = nChanges + 1  
        			resultText = resultText ..  string.format(" rating changed from %d to %d,", ifnil(srcPhoto:getRawMetadata('rating'), 0), ifnil(ratingPS, 0))
        			writeLogfile(3, string.format("Get metadata: %s - rating changed from %d to %d\n", 
        										photoInfo.remoteId, ifnil(srcPhoto:getRawMetadata('rating'), 0), ifnil(ratingPS, 0)))
        		elseif not ratingPS and ifnil(photoInfo.photo:getRawMetadata('rating'), 0)  > 0 then
        			resultText = resultText ..  string.format(" rating %d removal ignored,", ifnil(srcPhoto:getRawMetadata('rating'), 0))
        			writeLogfile(3, string.format("Get metadata: %s - rating %d was removed, setting photo to edited.\n", 
      											photoInfo.remoteId, ifnil(srcPhoto:getRawMetadata('rating'), 0)))
        			needRepublish = true
        			changesRejected = changesRejected + 1        		
        			nRejectedChanges = nRejectedChanges + 1        		
        		end
    		end
    
    		------------------------------------------------------------------------------------------------------
    		if collectionSettings.tagsDownload then
    			-- get all exported keywords including parent keywords and synonnyms, excluding those that are to be exported
				local keywordsExported = trimTable(split(srcPhoto:getFormattedMetadata("keywordTagsForExport"), ','))
    		
    			-- get delta lists: which keywords were added and removed
    			keywordNamesAdd 	= getTableDiff(tagsPS, keywordsExported) 
    			keywordNamesRemove  = getTableDiff(keywordsExported, tagsPS)
    			
    			-- get list of keyword objects to be removed: only leaf keywords can be removed, cannot remove synonyms or parent keywords 
   				keywordsRemove 	= PSLrUtilities.getKeywordObjects(srcPhoto, keywordNamesRemove)
    			
    			-- allow update of keywords only if keyword were added or changed, not if keywords were removed
    			-- compare w/ effectively removed keywords 
    			if (#keywordNamesAdd > 0) and (#keywordNamesAdd >= #keywordsRemove) then
    				tagsChanged = true
    				nChanges = nChanges + #keywordNamesAdd + #keywordNamesRemove 
    				if #keywordNamesAdd > 0 then resultText = resultText ..  string.format(" tags to add: '%s',", table.concat(keywordNamesAdd, "','")) end
    				if #keywordNamesRemove > 0 then resultText = resultText ..  string.format(" tags to remove: '%s',", table.concat(keywordNamesRemove, "','")) end
    				writeLogfile(3, string.format("Get metadata: %s - tags to add: '%s', tags to remove: '%s'\n", 
    										photoInfo.remoteId, table.concat(keywordNamesAdd, "','"), table.concat(keywordNamesRemove, "','")))
				elseif #keywordNamesAdd < #keywordsRemove then
        			resultText = resultText ..  string.format(" keywords %s removal ignored,", table.concat(keywordNamesRemove, "','"))
        			writeLogfile(3, string.format("Get metadata: %s - keywords %s were removed in PS, setting photo to edited (removal rejected).\n", 
      											photoInfo.remoteId, table.concat(keywordNamesRemove, "','")))
        			needRepublish = true
        			changesRejected = changesRejected + 1
        			nRejectedChanges = nRejectedChanges + 1
				elseif #keywordNamesRemove > #keywordsRemove then
        			resultText = resultText ..  string.format(" keywords to remove '%s' include synonyms or parent keyword (not allowed), removal ignored,", table.concat(keywordNamesRemove, "','"))
        			writeLogfile(3, string.format("Get metadata: %s - keywords '%s' removed in PS include synonyms or parent keyword (not allowed), setting photo to edited (removal rejected).\n", 
      											photoInfo.remoteId, table.concat(keywordNamesRemove, "','")))
        			needRepublish = true
        			changesRejected = changesRejected + 1        		
        			nRejectedChanges = nRejectedChanges + 1
    			end
    		end
    		
    		------------------------------------------------------------------------------------------------------
    		if collectionSettings.PS2LrFaces then
				-- get face regions in local photo
				local facesLr
				facesLr, origPhotoDimension = PSExiftoolAPI.queryLrFaceRegionList(publishSettings.eHandle, srcPhoto:getRawMetadata('path'))

    			-- get delta list: which person tags were added and removed
				local faceNamesLr = getTableExtract(facesLr, 'name')
				local faceNamesPS = getTableExtract(facesPS, 'name')
    			facesAdd 	= getTableDiff(faceNamesPS, faceNamesLr)
    			facesRemove = getTableDiff(faceNamesLr, faceNamesPS)
       			writeLogfile(3, string.format("Get metadata: %s - Lr faces: %d, PS faces: %d, Add: %d, Remove: %d\n", 
      											photoInfo.remoteId, #facesLr, #facesPS, #facesAdd, #facesRemove))
    			
    			-- allow update of faces only if faces were added or changed, not if faces were removed 
    			if (#facesAdd > 0) and (#facesAdd >= #facesRemove) then
    				facesChanged = true
    				table.insert(reloadPhotos, srcPhoto:getRawMetadata('path'))
    				nChanges = nChanges + #facesAdd + #facesRemove 
    				if #facesAdd > 0 then resultText = resultText ..  string.format(" faces to add: '%s',", table.concat(facesAdd, "','")) end
    				if #facesRemove > 0 then resultText = resultText ..  string.format(" faces to remove: '%s',", table.concat(facesRemove, "','")) end
    				writeLogfile(3, string.format("Get metadata: %s - faces to add: %s, faces to remove: %s\n", 
    										photoInfo.remoteId, table.concat(facesAdd, ','), table.concat(facesRemove, ',')))
				elseif #facesAdd < #facesRemove then
        			resultText = resultText ..  string.format(" faces %s removal ignored,", table.concat(facesRemove, "','"))
        			writeLogfile(3, string.format("Get metadata: %s - faces %s were removed in PS, setting photo to edited (removal rejected).\n", 
      											photoInfo.remoteId, table.concat(facesRemove, "','")))
        			needRepublish = true
        			changesRejected = changesRejected + 1        		
        			nRejectedChanges = nRejectedChanges + 1
    			end
    		end
    		
    		------------------------------------------------------------------------------------------------------

    		-- if anything changed in Photo Station, change value in Lr
    		if titleChanged 
    		or captionChanged 
--     		or gpsChanged 
    		or labelChanged 
    		or ratingChanged 
    		or tagsChanged 
    		or needRepublish then
        		catalog:withWriteAccessDo( 
        			'SetCaptionLabelRating',
        			function(context)
        				if titleChanged			then srcPhoto:setRawMetadata('title', titlePS) end
        				if captionChanged		then srcPhoto:setRawMetadata('caption', captionPS) end
--         				if gpsChanged			then srcPhoto:setRawMetadata('gps', gpsPS) end
        				if labelChanged			then srcPhoto:setRawMetadata('colorNameForLabel', labelPS) end
        				if ratingChanged		then srcPhoto:setRawMetadata('rating', ratingPS) end
        				if tagsChanged then 
        					if #keywordNamesAdd > 0 then PSLrUtilities.addPhotoKeywordNames(srcPhoto, keywordNamesAdd) end
        					if #keywordsRemove  > 0	then PSLrUtilities.removePhotoKeywords (srcPhoto, keywordsRemove) end
        				end 
        				if needRepublish 		then photoInfo.publishedPhoto:setEditedFlag(true) end
        			end,
        			{timeout=5}
        		)

   				writeLogfile(3, string.format("Get metadata: %s - changes done.\n", photoInfo.remoteId))
				-- if keywords were updated: check if resulting Lr keyword list matches PS keyword list (might be different due to parent keywords)
				if tagsChanged then
        			-- get all exported keywords including parent keywords and synonnyms, excluding those that are to be exported
    				local keywordsForExport = trimTable(split(srcPhoto:getFormattedMetadata("keywordTagsForExport"), ','))
        		
        			-- get delta lists: which keywords need to be added or removed in PS
        			local keywordNamesNeedRemoveinPS	= getTableDiff(tagsPS, keywordsForExport) 
        			local keywordNamesNeedAddinPS 	 	= getTableDiff(keywordsForExport, tagsPS)
        			if #keywordNamesNeedRemoveinPS > 0 or #keywordNamesNeedAddinPS > 0 then
	    				writeLogfile(3, string.format("Get metadata: %s - must sync keywords to PS, add: '%s', remove '%s'\n", 
	    												photoInfo.remoteId,
	    												table.concat(keywordNamesNeedAddinPS, "','"),
	    												table.concat(keywordNamesNeedRemoveinPS, "','")))
        				needRepublish = true
        			end
				end
				
				if not needRepublish then
    				writeLogfile(3, string.format("Get metadata: %s - set to Published\n", photoInfo.remoteId))
    				 
            		catalog:withWriteAccessDo( 
            			'ResetEdited',
            			function(context) photoInfo.publishedPhoto:setEditedFlag(false) end,
            			{timeout=5}
            		)
				end
    		end
    		
   			-- overwrite all existing face regions in local photo
    		if facesChanged and not PSExiftoolAPI.setLrFaceRegionList(publishSettings.eHandle, srcPhoto, facesPS, origPhotoDimension) then
   				nChanges = nChanges - (#facesAdd + #facesRemove)
   				nFailed = nFailed + 1 
	    	end  
		end -- not skip Photo
			
		if titleChanged	or captionChanged or labelChanged or ratingChanged or tagsChanged or facesChanged then
    		writeLogfile(2, string.format("Get metadata: %s - %s %s%s%s.\n", 
    												photoInfo.remoteId, resultText,
    												iif(nFailed > 0, 'failed', 'done'), 
    												iif(changesRejected > 0, ', ' .. tostring(changesRejected) .. ' rejected changes', ''),
    												iif(needRepublish, ', Re-publish needed', '')))
		else
			writeLogfile(2, string.format("Get metadata: %s - no changes%s.\n", 
													photoInfo.remoteId, 
    												iif(changesRejected > 0, ', ' .. tostring(changesRejected) .. ' rejected changes', '')))
		end
		
   		nProcessed = nProcessed + 1
   		progressScope:setPortionComplete(nProcessed, nPhotos) 						    
	end 
	progressScope:done()

	closeSession(publishSettings)

	local timeUsed 	= LrDate.currentTime() - startTime
	local picPerSec = nProcessed / timeUsed
	local message
	
	if (nRejectedChanges > 0) or (nFailed > 0) then
		message = LOC ("$$$/PSUpload/Upload/Errors/GetRatingsFromPublishedCollection=" .. 
					string.format("%d added/modified, %d failed and %d rejected removed metadata items for %d of %d pics in %d seconds (%.1f pics/sec).", 
					nChanges, nFailed, nRejectedChanges, nProcessed, nPhotos, timeUsed + 0.5, picPerSec))
		showFinalMessage("Photo StatLr: Get metadata done", message, "critical")
	else
		message = LOC ("$$$/PSUpload/Upload/Errors/GetRatingsFromPublishedCollection=" .. 
					string.format("%d added/modified metadata items for %d of %d pics in %d seconds (%.1f pics/sec).", 
					nChanges, nProcessed, nPhotos, timeUsed + 0.5, picPerSec))
		if #reloadPhotos > 0 then
			message = message .. string.format("\nThe following photos must be reloaded (added faces):\n%s", table.concat(reloadPhotos, '\n'))
			showFinalMessage("Photo StatLr: Get metadata done", message, "warning")
		else
			showFinalMessage("Photo StatLr: Get metadata done", message, "info")
		end
	end
	return true
end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called whenever a
 -- published photo is selected in the Library module. Your implementation should
 -- return true if there is a viable connection to the publish service and
 -- comments can be added at this time. If this function is not implemented,
 -- the new comment section of the Comments panel in the Library is left enabled
 -- at all times for photos published by this service. If you implement this function,
 -- it allows you to disable the Comments panel temporarily if, for example,
 -- the connection to your server is down.
--[[
]]
function publishServiceProvider.canAddCommentsToService( publishSettings )
--	return publishSettings.supportComments
	return true
end
--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user adds 
 -- a new comment to a published photo in the Library module's Comments panel. 
 -- Your implementation should publish the comment to the service.

 function publishServiceProvider.addCommentToPublishedPhoto( publishSettings, remotePhotoId, commentText )
	-- make sure logfile is opened
	openLogfile(publishSettings.logLevel)

	-- open session: initialize environment, get missing params and login
	local sessionSuccess, reason = openSession(publishSettings, nil, 'AddCommentToPublishedPhoto')
	if not sessionSuccess then
		if reason ~= 'cancel' then
			showFinalMessage("Photo StatLr: AddCommentToPublishedPhoto failed!", reason, "critical")
		end
		closeLogfile()
		return false
	end

	writeLogfile(2, string.format("AddCommentToPublishedPhoto: %s - %s\n", remotePhotoId, commentText))
	return PSPhotoStationAPI.addPhotoComment(publishSettings.uHandle, remotePhotoId, PSLrUtilities.isVideo(remotePhotoId), commentText, publishSettings.username .. '@Lr')
end
--------------------------------------------------------------------------------

PSPublishSupport = publishServiceProvider
