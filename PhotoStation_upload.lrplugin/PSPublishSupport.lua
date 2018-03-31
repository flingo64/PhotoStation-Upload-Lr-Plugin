--[[----------------------------------------------------------------------------

PSPublishSupport.lua
Publish support for Lightroom Photo StatLr
Copyright(c) 2017, Martin Messmer

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
require "PSSharedAlbumMgmt"

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
	
publishServiceProvider.titleForPublishedCollection = LOC "$$$/PSUpload/TitleForPublishedCollection=Published Collection"

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

publishServiceProvider.titleForPublishedCollection_standalone = LOC "$$$/PSUpload/TitleForPublishedCollection/Standalone=Published Collection"

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- collection set to match the terminology used on the service you are targeting.
 -- <p>This string is typically used in combination with verbs that take action on
 -- the published collection set, such as "Create ^1" or "Rename ^1".</p>
 -- <p>If not provided, Lightroom uses the default name, "Published Collection Set." </p>
	
publishServiceProvider.titleForPublishedCollectionSet = LOC "$$$/PSUpload/TitleForPublishedCollectionSet=Published Collection Set"

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

publishServiceProvider.titleForPublishedCollectionSet_standalone = LOC "$$$/PSUpload/TitleForPublishedCollectionSet/Standalone=Published Collection Set"

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- smart collection to match the terminology used on the service you are targeting.
 -- <p>This string is typically used in combination with verbs that take action on
 -- the published smart collection, such as "Create ^1" or "Rename ^1".</p>
 -- <p>If not provided, Lightroom uses the default name, "Published Smart Collection." </p>

publishServiceProvider.titleForPublishedSmartCollection = LOC "$$$/PSUpload/TitleForPublishedSmartCollection=Published Smart Collection"

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

publishServiceProvider.titleForPublishedSmartCollection_standalone = LOC "$$$/PSUpload/TitleForPublishedSmartCollection/Standalone=Published Smart Collection"

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
		defaultCollectionName = LOC "$$$/PSUpload/DefaultCollectionName/Collection=Default Collection",
		defaultCollectionCanBeDeleted = false,
		canAddCollection = true,
	}
	
end

--------------------------------------------------------------------------------
--- When set to the string "disable", the "Go to Published Collection" context-menu item
 -- is disabled (dimmed) for this publish service.

publishServiceProvider.titleForGoToPublishedCollection = LOC "$$$/PSUpload/TitleForGoToPublishedCollection=Show Album in Photo Station"

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user chooses
 -- the "Go to Published Collection" context-menu item.
function publishServiceProvider.goToPublishedCollection( publishSettings, info )
	local albumPath, albumUrl 

	-- make sure logfile is opened
	openLogfile(publishSettings.logLevel)

	albumPath = PSLrUtilities.getCollectionUploadPath(info.publishedCollection)
	
	if PSLrUtilities.isDynamicAlbumPath(albumPath)then 
		showFinalMessage("Photo StatLr: GoToPublishedCollection failed!", "Show Album '" .. info.publishedCollection:getName() .. "' in Photo Station: can't open a dynamic target album!", "info")
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
	
	albumUrl = PSPhotoStationUtils.getAlbumUrl(publishSettings.uHandle, albumPath)

	LrHttp.openUrlInBrowser(albumUrl)
end

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value overrides the label for the 
 -- "Go to Published Photo" context-menu item, allowing you to use something more appropriate to
 -- your service. Set to the special value "disable" to disable (dim) the menu item for this service. 

publishServiceProvider.titleForGoToPublishedPhoto = LOC "$$$/PSUpload/TitleForGoToPublishedPhoto=Show Photo in Photo Station"

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
			showFinalMessage("Photo StatLr: GoToPublishedPhoto failed!", reason, "critical")
		end
		closeLogfile()
		return
	end
	
	photoUrl = PSPhotoStationUtils.getPhotoUrl(publishSettings.uHandle, info.publishedPhoto:getRemoteId(), info.photo:getRawMetadata('isVideo'))
	LrHttp.openUrlInBrowser(photoUrl)
end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user creates
 -- a new publish service via the Publish Manager dialog. It allows your plug-in
 -- to perform additional initialization.

function publishServiceProvider.didCreateNewPublishService( publishSettings, info )
	local sharedAlbumKeywordRoot = PSSharedAlbumMgmt.getSharedAlbumKeywordPath(info.connectionName, nil)
	writeLogfile(2, string.format("didCreateNewPublishService: adding Shared Album Keyword Hierarchy '%s'\n", sharedAlbumKeywordRoot))

	local createIfMissing, includeOnExport = true, false
	local keywordId, keyword = PSLrUtilities.getKeywordByPath(sharedAlbumKeywordRoot, createIfMissing, includeOnExport)

end


--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user creates
 -- a new publish service via the Publish Manager dialog. It allows your plug-in
 -- to perform additional initialization.

function publishServiceProvider.didUpdatePublishService( publishSettings, info )
	local sharedAlbumKeywordRoot = PSSharedAlbumMgmt.getSharedAlbumKeywordPath(info.connectionName, nil)
	writeLogfile(2, string.format("didUpdatePublishService: adding Shared Album Keyword Hierarchy '%s'\n", sharedAlbumKeywordRoot))

	local createIfMissing, includeOnExport = true, false
	local keywordId, keyword = PSLrUtilities.getKeywordByPath(sharedAlbumKeywordRoot, createIfMissing, includeOnExport)

end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has attempted to delete the publish service from Lightroom.
 -- It provides an opportunity for you to customize the confirmation dialog.
 -- @return (string) 'cancel', 'delete', or nil (to allow Lightroom's default
 -- dialog to be shown instead)
--
--[[ Not used for Photo StatLr plug-in.

function publishServiceProvider.shouldDeletePublishService( publishSettings, info )
end

]]

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has confirmed the deletion of the publish service from Lightroom.
 -- It provides a final opportunity for	you to remove private data
 -- immediately before the publish service is removed from the Lightroom catalog.

function publishServiceProvider.willDeletePublishService( publishSettings, info )
	-- we would like to remove the belonging Shared Album keyword hierarchy here
	-- but: there is no API to remove keywords ...
	
	LrDialogs.message("Photo StatLr: Delete Publish Service", 
					LOC("$$$/PSUpload/FinalMsg/DeletePublishService/RemoveSharedAlbum=Please consider removing the following service-related keyword hierarchy:\n'^1'.",
						"Photo StatLr|Shared Albums|" .. info.connectionName), 'info') 
end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has attempted to delete one or more published collections defined by your
 -- plug-in from Lightroom. It provides an opportunity for you to customize the
 -- confirmation dialog.
 -- @return (string) "ignore", "cancel", "delete", or nil
 -- (If you return nil, Lightroom's default dialog will be displayed.)
--[[ Not used for Photo StatLr plug-in.

function publishServiceProvider.shouldDeletePublishedCollection( publishSettings, info )
end
]]


--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has attempted to delete one or more photos from the Lightroom catalog that are
 -- published through your service. It provides an opportunity for you to customize
 -- the confirmation dialog.
function publishServiceProvider.shouldDeletePhotosFromServiceOnDeleteFromCatalog( publishSettings, nPhotos )
	-- ask the user for confirmation
	return nil
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
		
		
		if PSPhotoStationAPI.deletePhoto (publishSettings.uHandle, photoId, PSLrUtilities.isVideo(photoId)) then
			writeLogfile(2, "deletePhotosFromPublishedCollection: '" .. photoId .. "': successfully deleted.\n")
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
		nDeletedAlbums = nDeletedAlbums + PSPhotoStationUtils.deleteEmptyAlbumAndParents(publishSettings.uHandle, currentAlbum.albumPath)
		currentAlbum = currentAlbum.next
	end

	local timeUsed 	= LrDate.currentTime() - startTime
	local picPerSec = nProcessed / timeUsed
	local message = LOC ("$$$/PSUpload/FinalMsg/DeletePhotosFromPublishedCollection=Deleted ^1 of ^2 pics and ^3 empty albums in ^4 seconds (^5 pics/sec).\n", 
					nProcessed, nPhotos, nDeletedAlbums, string.format("%.1f", timeUsed + 0.5), string.format("%.1f", picPerSec))

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
			message = LOC "$$$/PSUpload/Dialogs/Messages/EnterSubPath=Enter a source path"
			break
		end
				
		if not PSDialogs.validateAlbumPath(nil, collectionSettings.dstRoot) then
			message = LOC "$$$/PSUpload/Dialogs/Messages/InvalidAlbumPath=Target Album path is invalid"
			break
		end
				
		-- renaming: renaming dstFilename must contain at least one metadata placeholder
		if collectionSettings.renameDstFile  and not PSDialogs.validateMetadataPlaceholder(nil, collectionSettings.dstFilename) then 
			message = LOC "$$$/PSUpload/Dialogs/Messages/RenamePatternInvalid=Rename Photos: Missing placeholders or unbalanced { }!"
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
			message = LOC "$$$/PSUpload/Dialogs/Messages/EnterExiftool=Missing or wrong exiftool path. Fix it in Plugin Manager settings section."
			break
		end

		-- downloading translated tags makes only sense if we upload them also, otherwise they would dissappear after re-publish
		if not collectionSettings.exifXlatFaceRegions 	then collectionSettings.PS2LrFaces = false end
		if not collectionSettings.exifXlatLabel 		then collectionSettings.PS2LrLabel = false end
		if not collectionSettings.exifXlatRating 		then collectionSettings.PS2LrRating = false end
		
		-- Exif translation end

		-- exclusive or: rating download or rating tag download
		if collectionSettings.ratingDownload and collectionSettings.PS2LrRating then 
			message = LOC "$$$/PSUpload/Dialogs/Messages/RatingOrRatingTag=You may either download the native rating or the translated rating tag from Photo Station."
			break
		end
		
		-- location tag download (blue pin): only possible if location download is enabled
		if not collectionSettings.locationDownload then  collectionSettings.locationTagDownload = false end
		 
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
	
    local pluginDefaultCollectionSettings = {
		hasError 			= false,
		isCollection 		= true,
		psVersion 			= publishSettings.psVersion,

		storeDstRoot 		= true,
    	dstRoot 			= '',
    	createDstRoot		= false,
    	copyTree			= false,
    	srcRoot				= '',
    
    	renameDstFile		= false,
    	dstFilename			= '',
    	RAWandJPG			= false,
    	sortPhotos			= false,
    
    	exifTranslate		= publishSettings.exifTranslate,
    	exifXlatFaceRegions	= publishSettings.exifXlatFaceRegions,
    	exifXlatRating		= publishSettings.exifXlatRating,
    	exifXlatLabel		= publishSettings.exifXlatLabel,
    
    	titleDownload		= false,
    	captionDownload		= false,
    	locationDownload	= false,
    	locationTagDownload	= false,
    	ratingDownload		= false,
    
    	tagsDownload		= false,
    	PS2LrFaces			= false,
    	PS2LrLabel			= false,
    	PS2LrRating			= false,
    
    	commentsDownload	= false,
    	pubCommentsDownload	= false,
    	pubColorDownload	= true,
    
    	publishMode 		= 'Publish',
    	downloadMode		= 'Yes',
    }
	
	-- make sure logfile is opened
	openLogfile(iif(publishSettings.logLevel == 9999, 2, publishSettings.logLevel))	
	
	-- if we are not the defaultCollection, find the defaultColletionSettings for initializing our settings 
	local serviceDefaultCollectionName, serviceDefaultCollectionSettings 
	if not info.isDefaultCollection then
		serviceDefaultCollectionName, serviceDefaultCollectionSettings = PSLrUtilities.getDefaultCollectionSettings(info.publishService)
	end
	
	if serviceDefaultCollectionSettings then
		writeLogfile(3,string.format("Found Default Collection '%s' for service:\nApplying plugin defaults to unitialized values of Service Default Collection\n", serviceDefaultCollectionName))
		applyDefaultsIfNeededFromTo(pluginDefaultCollectionSettings, serviceDefaultCollectionSettings)
		writeLogfile(3,string.format("Applying defaults from Service Default Collection to unitialized values of current collection\n"))
		applyDefaultsIfNeededFromTo(serviceDefaultCollectionSettings, collectionSettings)
	else
		writeLogfile(3,string.format("Found no Default Collection for service: Applying plugin defaults to unitialized values of current collection\n"))
		applyDefaultsIfNeededFromTo(pluginDefaultCollectionSettings, collectionSettings)
	end
		
	--============= observe changes in collection setiings dialog ==============
	collectionSettings:addObserver( 'srcRoot', updateCollectionStatus )
	collectionSettings:addObserver( 'dstRoot', updateCollectionStatus )
	collectionSettings:addObserver( 'copyTree', updateCollectionStatus )
	collectionSettings:addObserver( 'publishMode', updateCollectionStatus )
	collectionSettings:addObserver( 'renameDstFile', updateCollectionStatus )
	collectionSettings:addObserver( 'dstFilename', updateCollectionStatus )
	collectionSettings:addObserver( 'exifXlatFaceRegions', updateCollectionStatus )
	collectionSettings:addObserver( 'exifXlatLabel', updateCollectionStatus )
	collectionSettings:addObserver( 'exifXlatRating', updateCollectionStatus )
	collectionSettings:addObserver( 'locationDownload', updateCollectionStatus )
	collectionSettings:addObserver( 'ratingDownload', updateCollectionStatus )
	collectionSettings:addObserver( 'PS2LrRating', updateCollectionStatus )
	
	updateCollectionStatus( collectionSettings )
	
	-- manual suggests group_box as outmost container, but nested group_boxes will get an invisible title 
	--	return f:group_box {
	return f:view {
		size = 'small',
		fill_horizontal = 1,
		bind_to_object = assert( collectionSettings ),
		
    	f:column {
    		fill_horizontal = 1,
    		spacing = f:label_spacing(),
			PSDialogs.collectionHeaderView(f, collectionSettings, info.isDefaultCollection, serviceDefaultCollectionName),
			
			PSDialogs.targetAlbumView(f, collectionSettings),

			PSDialogs.photoNamingView(f, collectionSettings),

            PSDialogs.uploadOptionsView(f, collectionSettings),
 
            PSDialogs.downloadOptionsView(f, collectionSettings),
 
            PSDialogs.downloadModeView(f, collectionSettings),

            PSDialogs.publishModeView(f, collectionSettings),

   			f:spacer { fill_horizontal = 1,	},
			
    		f:row {
    			alignment = 'center',
    
    			f:static_text {
    				title 			= bind 'message',
    				text_color 		= LrColor("red"),
   					font			= '<system/bold>',
   					alignment		= 'center', 
    				fill_horizontal = 1,
    				visible 		= bind 'hasError'
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
	return true
--[[	
	local message = nil

	if message then
		collectionSetSettings.hasError = true
		collectionSetSettings.message = message
		collectionSetSettings.LR_canSaveCollection = false
	else
		collectionSetSettings.hasError = false
		collectionSetSettings.message = nil
		collectionSetSettings.LR_canSaveCollection = true
	end
]]	
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

	return f:view {
--		size = 'small',
		fill_horizontal = 1,
		bind_to_object = assert( collectionSetSettings ),
		
		f:column {
			fill_horizontal = 1,
			spacing = f:label_spacing(),

			PSDialogs.collectionHeaderView(f, collectionSetSettings, false, nil),
			
			PSDialogs.dstRootForSetView(f, collectionSetSettings),
			
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
	
	PSPhotoStationAPI.sortAlbumPhotos(publishSettings.uHandle, albumPath, remoteIdSequence)

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
			showFinalMessage("Photo StatLr: DeletePublishedCollection failed!", reason, "critical")
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
							title = LOC( "$$$/PSUpload/Progress/DeletingCollectionAndContents=Deleting collection ^[^1^] with ^2 photos", info.name, nPhotos),
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

		progressScope:setCaption(publishedPath)

		writeLogfile(3, string.format("deletePublishedCollection: deleting %s from  %s\n", publishedPath, info.name ))

		if PSPhotoStationAPI.deletePhoto(publishSettings.uHandle, publishedPath, PSLrUtilities.isVideo(publishedPath)) then
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
		nDeletedAlbums = nDeletedAlbums + PSPhotoStationUtils.deleteEmptyAlbumAndParents(publishSettings.uHandle, currentAlbum.albumPath)
		currentAlbum = currentAlbum.next
	end
	
	progressScope:done()
	
	local timeUsed 	= LrDate.currentTime() - startTime
	local picPerSec = nProcessed / timeUsed
	local message = LOC ("$$$/PSUpload/FinalMsg/DeletePublishedColletion=Deleted ^1 of ^2 pics and ^3 empty albums in ^4 seconds (^5 pics/sec).\n", 
					nProcessed, nPhotos, nDeletedAlbums, string.format("%.1f",timeUsed + 0.5), string.format("%.1f",picPerSec))

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
	local publishServiceName
	local publishedCollection, publishedCollectionName
	local nProcessed 	= 0 
	local nComments 	= 0 
	local nColorLabel	= 0 
	
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

	if publishSettings.downloadMode == 'No' or not (publishSettings.commentsDownload or publishSettings.pubCommentsDownload or publishSettings.pubColorDownload) then
		writeLogfile(2, string.format("Get comments: comments not enabled for this collection.\n"))
		closeLogfile()
		return
	end
		
	publishedCollectionName = publishedCollection:getName()
	publishServiceName		= publishedCollection:getService():getName()
	writeLogfile(2, string.format("Get comments for %d photos in collection %s (%s).\n", nPhotos, publishedCollectionName, publishServiceName))

	local startTime = LrDate.currentTime()

	local progressScope = LrProgressScope( 
								{ 	title = LOC( "$$$/PSUpload/Progress/GetCommentsFromPublishedCollection=Downloading comments for ^1 photos in collection ^[^2^]", nPhotos, publishedCollection:getName()),
--							 		functionContext = context 
							 	})  
	
	-- if pubComemntDownload: download a comment list for all shared albums of this publish service						 	
	local serviceSharedAlbumComments = {}

	-- get all Shared Albums belonging to this service
	if publishSettings.pubColorDownload or publishSettings.pubCommentsDownload then
		local pubServiceSharedAlbums = PSSharedAlbumMgmt.getPublishServiceSharedAlbums(publishServiceName)

		-- download colors and/or comment list for all shared albums of this publish service
		for _, sharedAlbum in ipairs(pubServiceSharedAlbums) do
			if sharedAlbum.isPublic then
				serviceSharedAlbumComments[sharedAlbum.sharedAlbumName] = PSPhotoStationAPI.getPublicSharedAlbumLogList(publishSettings.uHandle, sharedAlbum.sharedAlbumName)
			end
		end
	end
	
	for i, photoInfo in ipairs( arrayOfPhotoInfo ) do
		if progressScope:isCanceled() then break end

		local srcPhoto = photoInfo.photo
		progressScope:setCaption(LrPathUtils.leafName(srcPhoto:getRawMetadata("path")))

   		local lastCommentTimestamp 
   		local commentInfo = {}
   		local commentListLr = {} 

		-- get photo comments from PS albums
		if publishSettings.commentsDownload then 
    		local commentsPS = PSPhotoStationAPI.getPhotoComments(publishSettings.uHandle, photoInfo.remoteId, srcPhoto:getRawMetadata('isVideo'))
    		
    		if not commentsPS then
    			writeLogfile(1, string.format("Get comments: %s failed!\n", photoInfo.remoteId))
    		elseif  #commentsPS > 0 then
        
       			writeLogfile(3, string.format("Get comments: %s - found %d comments in private Album\n", photoInfo.remoteId, #commentsPS))
    			for _, comment in ipairs( commentsPS ) do
    				local year, month, day, hour, minute, second = string.match(comment.date, '(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d)')
    				local commentTimestamp = LrDate.timeFromComponents(year, month, day, hour, minute, second, 'local')
    				
    				local commentLr = {
    								commentId = string.match(comment.id, 'comment_(%d+)'),
    								commentText = comment.comment,
    								dateCreated = commentTimestamp,
       								username = ifnil(comment.email, ''),
      								realname = ifnil(comment.name, '') .. '@PS (Photo Station internal)',
    							}
    				table.insert(commentListLr, commentLr)
   
       				if commentTimestamp > ifnil(lastCommentTimestamp, 0) then
       					lastCommentTimestamp			= commentTimestamp
       					
       					commentInfo.lastCommentType 	= 'private'
       					commentInfo.lastCommentSource	= publishServiceName .. '/' .. publishedCollectionName
       					commentInfo.lastCommentUrl		= PSPhotoStationUtils.getPhotoUrl(publishSettings.uHandle, photoInfo.remoteId, srcPhoto:getRawMetadata('isVideo'))
       					commentInfo.lastCommentAuthor	= ifnil(comment.name, '')
       					commentInfo.lastCommentText		= commentLr.commentText
       					
    				end
    			end			
    
    		end	
		end

		if publishSettings.pubColorDownload or publishSettings.pubCommentsDownload then
    		-- get photo comments from PS public shared albums, if photo is member of any shared album
    		local photoSharedAlbums = PSSharedAlbumMgmt.getPhotoPluginMetaLinkedSharedAlbums(srcPhoto)
    		if photoSharedAlbums then
    		
       			writeLogfile(4, string.format("Get comments: %s - found %d Shared Albums\n", photoInfo.remoteId, #photoSharedAlbums))
    			for i = 1, #photoSharedAlbums do
  					-- download color label and or comments from this shared album only if:
  					--  - the shared album belongs to this collection
  					-- 	- the shared album is public
  					-- 	- photo is in sharedAlbumCommentList
    				local collectionId, sharedAlbumName = string.match(photoSharedAlbums[i], '(%d+):(.+)')
    				local psSharedPhotoId 		= PSPhotoStationUtils.getPhotoId(photoInfo.remoteId, srcPhoto:getRawMetadata('isVideo'))
	    			local psSharedPhotoLogFound	= findInAttrValueTable(serviceSharedAlbumComments[sharedAlbumName], 'item_id', psSharedPhotoId, 'name')
	    			 
    				if 		tonumber(collectionId) == publishedCollection.localIdentifier 
    					and	PSPhotoStationUtils.isSharedAlbumPublic(publishSettings.uHandle, sharedAlbumName)
	    				and psSharedPhotoLogFound
					then
						
						if publishSettings.pubColorDownload then
							local psPubColorLabel = PSPhotoStationUtils.getPublicSharedPhotoColorLabel(publishSettings.uHandle, sharedAlbumName, photoInfo.remoteId, srcPhoto:getRawMetadata('isVideo'))
        		   			writeLogfile(3, string.format("Get comments: %s - found color label '%s' in Shared Album '%s'\n", 
    		   							photoInfo.remoteId, ifnil(psPubColorLabel, '<nil>'), sharedAlbumName))
    		   				nColorLabel = nColorLabel + 1
							-- TODO: set label in Lr
--[[
							-- all label actions (labeling and unlabeling) are stored in the photo log, so we have to find the last action
							local psSharedPhotoLabelColor, psSharedPhotoLabelDate 
							local psSharedAlbumLog = serviceSharedAlbumComments[sharedAlbumName]
							
							for i = 1, #psSharedAlbumLog do
								local psSharedPhotoLog =  psSharedAlbumLog[i]
								if psSharedPhotoLog.item_id == psSharedPhotoId and psSharedPhotoLog.category == 'label' then
	            		   			writeLogfile(3, string.format("Get comments: %s - found label action '%s (%s)' in Shared Album '%s'\n", 
	            		   							photoInfo.remoteId, psSharedPhotoLog.log, psSharedPhotoLog.date, sharedAlbumName))
									if not psSharedPhotoLabelDate or psSharedPhotoLog.date > psSharedPhotoLabelDate then
										psSharedPhotoLabelDate = psSharedPhotoLog.date
										psSharedPhotoLabelColor = string.match(psSharedPhotoLog.log, '.*%[(%w+)%]')
		            		   			writeLogfile(3, string.format("Get comments: %s - note label '%s' (%s) in Shared Album '%s'\n", 
	            		   							photoInfo.remoteId, ifnil(psSharedPhotoLabelColor, '<nil>'), psSharedPhotoLog.date, sharedAlbumName))
	            		   			end
								end
							end
							-- if we found one ...
							if psSharedPhotoLabelDate then
            		   			writeLogfile(3, string.format("Get comments: %s - using label '%s (%s)' in Shared Album '%s'\n", 
        		   							photoInfo.remoteId, ifnil(psSharedPhotoLabelColor, '<nil>'), psSharedPhotoLabelDate, sharedAlbumName))
        		   				nColorLabel = nColorLabel + 1
								-- TODO: set label in Lr
							end
]]
						end
							
						if publishSettings.pubCommentsDownload then
            				local sharedCommentsPS 	= PSPhotoStationAPI.getPublicSharedPhotoComments(publishSettings.uHandle, sharedAlbumName, photoInfo.remoteId, srcPhoto:getRawMetadata('isVideo'))
            
                    		if sharedCommentsPS and #sharedCommentsPS > 0 then
            		   			writeLogfile(3, string.format("Get comments: %s - found %d comments in Shared Album '%s'\n", photoInfo.remoteId, #sharedCommentsPS, sharedAlbumName))
                    
                    			for j, comment in ipairs( sharedCommentsPS ) do
                    				local year, month, day, hour, minute, second = string.match(comment.date, '(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d)')
    			    				local commentTimestamp = LrDate.timeFromComponents(year, month, day, hour, minute, second, 'local')
                    
                    				local commentLr = {
                    								commentId = photoSharedAlbums[i] .. '_' .. comment.date, -- we need something unique
                    								commentText = comment.comment,
                    								dateCreated = commentTimestamp,
                	   								username = ifnil(comment.email, ''),
                	  								realname = ifnil(comment.name, '') .. '@' .. sharedAlbumName .. ' (Public Shared Album)',
                    							}
                    							
                    				table.insert(commentListLr, commentLr)
    
                       				if commentTimestamp > ifnil(lastCommentTimestamp, 0) then
                       					lastCommentTimestamp	= commentTimestamp
    
                       					commentInfo.lastCommentType 	= 'public'
                       					commentInfo.lastCommentSource	= publishServiceName .. '/' .. publishedCollectionName
                       					commentInfo.lastCommentUrl		= PSPhotoStationUtils.getSharedPhotoPublicUrl(publishSettings.uHandle, sharedAlbumName, 
                       																							 photoInfo.remoteId, srcPhoto:getRawMetadata('isVideo'))
                       					commentInfo.lastCommentAuthor	= ifnil(comment.name, '')
                       					commentInfo.lastCommentText		= commentLr.commentText
                    				end
                    			end
        					end
                		end	
					end
    			end
    		end
		end

		writeLogfile(2, string.format("Get comments: %s - %d comments\n", photoInfo.remoteId, #commentListLr))
		
		local lastCommentDate 
		if lastCommentTimestamp then
			commentInfo.lastCommentDate= LrDate.timeToUserFormat(lastCommentTimestamp, "%Y-%m-%d", false)
			commentInfo.commentCount = #commentListLr
		end
		PSLrUtilities.setPhotoPluginMetaCommentInfo(srcPhoto, commentInfo)
		
		writeTableLogfile(4, "commentListLr", commentListLr)
		-- if we do not call commentCallback, the photo goes to 'To re-publish'
--		if publishSettings.commentsDownload or publishSettings.pubCommentsDownload then 
			commentCallback({publishedPhoto = photoInfo, comments = commentListLr})
			nComments = nComments + #commentListLr
--		end
    	
   		nProcessed = nProcessed + 1
   		progressScope:setPortionComplete(nProcessed, nPhotos) 						    
	end 
	progressScope:done()

	local timeUsed 	= LrDate.currentTime() - startTime
	local picPerSec = nProcessed / timeUsed
	local message = LOC ("$$$/PSUpload/FinalMsg/GetCommentsFromPublishedCollection=Got ^1 comments for ^2 of ^3 pics in ^4 seconds (^5 pics/sec).", 
					nComments, nProcessed, nPhotos, string.format("%.1f", timeUsed + 0.5), string.format("%.1f", picPerSec))

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

publishServiceProvider.titleForPhotoRating = LOC "$$$/PSUpload/TitleForPhotoRating=Photo Rating"

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
	local publishedCollection, publishedCollectionName
	local nProcessed 		= 0 
	local nChanges 			= 0 
	local nRejectedChanges	= 0 
	local nFailed			= 0 
	
	-- make sure logfile is opened
	openLogfile(publishSettings.logLevel)

	if publishSettings.operationCanceled then
		writeLogfile(2, string.format("Get ratings/metadata: canceled by user\n"))
		return
	end
	
	if nPhotos == 0 then
		writeLogfile(2, string.format("Get ratings/metadata: nothing to do.\n"))
		closeLogfile()
		return
	elseif arrayOfPhotoInfo[1].url == nil then
		showFinalMessage("Photo StatLr: Get ratings/metadata failed!", 'Cannot sync ratings on old-style collection.\nPlease convert this collection first!', "critical")
		closeLogfile()
		return
	end

	-- the remoteUrl contains the local collection identifier
	publishedCollection = LrApplication.activeCatalog():getPublishedCollectionByLocalIdentifier(tonumber(string.match(arrayOfPhotoInfo[1].url, '(%d+)')))
	if not publishedCollection then
		showFinalMessage("Photo StatLr: Get ratings/metadata failed!", 'Cannot sync ratings on corrupted collection.\nPlease convert this collection first!', "critical")
		closeLogfile()
		return
	end	
	
	-- open session: initialize environment, get missing params and login
	local sessionSuccess, reason = openSession(publishSettings, publishedCollection, 'GetRatingsFromPublishedCollection')
	if not sessionSuccess then
		if reason ~= 'cancel' then
			showFinalMessage("Photo StatLr: Get ratings/metadata failed!", reason, "critical")
		else
			writeLogfile(2, string.format("Get ratings/metadata: canceled by user\n"))
			publishSettings.operationCanceled = true
		end
		closeLogfile()
		return
	end
	writeLogfile(2, string.format("Get ratings/metadata: options(title: %s, caption: %s, location: %s, locationTag: %s rating: %s, tags: %s, face xlat: %s, label xlat: %s, rating xlat: %s)\n",
							publishSettings.titleDownload, publishSettings.captionDownload, publishSettings.locationDownload, publishSettings.locationTagDownload, publishSettings.ratingDownload, 
							publishSettings.tagsDownload, publishSettings.PS2LrFaces, publishSettings.PS2LrLabel, publishSettings.PS2LrRating))
	
--	local collectionSettings = publishedCollection:getCollectionInfoSummary().collectionSettings
	-- collectionSettings were copied to publishSettings during openSession()
	local collectionSettings = publishSettings

	if			collectionSettings.downloadMode == 'No' or
		(	not collectionSettings.titleDownload 
		and not collectionSettings.captionDownload 
		and not collectionSettings.locationDownload 
		and not collectionSettings.locationTagDownload 
		and not collectionSettings.ratingDownload 
		and not collectionSettings.tagsDownload 
		and not collectionSettings.PS2LrFaces 
		and not collectionSettings.PS2LrLabel 
		and not collectionSettings.PS2LrRating
	 	)
	then
		writeLogfile(2, string.format("Get ratings/metadata: Metadata download is not enabled for this collection.\n"))
		closeLogfile()
		return
	end
		
	publishedCollectionName = publishedCollection:getName()
	writeLogfile(2, string.format("Get ratings for %d photos in collection %s.\n", nPhotos, publishedCollectionName))

	local reloadPhotos = {}
	local startTime = LrDate.currentTime()

	local catalog = LrApplication.activeCatalog()
	local progressScope = LrProgressScope( 
								{ 	title = LOC( "$$$/PSUpload/Progress/GetRatingsFromPublishedCollection=Downloading ratings/metadata for ^1 photos in collection ^[^2^]", nPhotos, publishedCollection:getName()),
--							 		functionContext = context 
							 	})    
	for i, photoInfo in ipairs( arrayOfPhotoInfo ) do
		if progressScope:isCanceled() then break end

		local srcPhoto 		= photoInfo.photo
		local isVideo		= srcPhoto:getRawMetadata('isVideo')
		
		progressScope:setCaption(LrPathUtils.leafName(srcPhoto:getRawMetadata("path")))

		local titlePS,		titleChanged
		local captionPS, 	captionChanged
		local ratingPS, 	ratingChanged
		local gpsPS,		gpsChanged = { latitude = 0, longitude = 0, }		-- GPS data from photo or from location tag (second best) 
		local ratingTagPS, 	ratingTagChanged
		local labelPS,		labelChanged
		local tagsPS, 		tagsChanged = {}
		local facesPS, 		facesChanged = {}
		local origPhotoDimension
		local keywordNamesAdd, keywordNamesRemove, keywordsRemove
		local facesAdd, facesRemove, faceNamesAdd, faceNamesRemove
		local resultText = ''
		local changesRejected, changesFailed = 0, 0		
		
		local needRepublish = false
		
		local photoLastUpload = string.match(photoInfo.url, '%d+/(%d+)')
		
		if photoInfo.publishedPhoto:getEditedFlag() then
			-- do not download infos to original photo for unpublished photos
			writeLogfile(2, string.format("Get ratings/metadata: %s - latest version not published, skip download.\n", photoInfo.remoteId))
		elseif tonumber(ifnil(photoLastUpload, '0')) > (LrDate.currentTime() - 60) then 
			writeLogfile(2, string.format("Get ratings/metadata: %s - recently uploaded, skip download.\n", photoInfo.remoteId))
		else		 
    		
    		------------------------------------------------------------------------------------------------------
    		-- get title, caption, rating, location from Photo Station (via album list API)

    		if 		collectionSettings.titleDownload 
    			or  collectionSettings.captionDownload 
    			or  collectionSettings.ratingDownload
    			or  collectionSettings.locationDownload
    		then
    			local useCache = true
    			local albumName 		= ifnil(string.match(photoInfo.remoteId , '(.*)\/[^\/]+'), '/')
    			local psPhotoInfos 		= PSPhotoStationUtils.getPhotoInfoFromList(publishSettings.uHandle, 'album', albumName, photoInfo.remoteId, isVideo, useCache)
    			local psPhotoInfo, psPhotoAdditional

				if psPhotoInfos then
					psPhotoInfo 		= psPhotoInfos.info 
					psPhotoAdditional 	= psPhotoInfos.additional
				end

        		if psPhotoInfo then
        			if collectionSettings.titleDownload 	then titlePS = psPhotoInfo.title end 
        			if collectionSettings.captionDownload	then captionPS = psPhotoInfo.description end 
        			if collectionSettings.ratingDownload	then ratingPS = tonumber(psPhotoInfo.rating) end 
        			if collectionSettings.locationDownload	then 
        				-- gps coords from photo/video: best choice for GPS
        				if psPhotoInfo.lat and psPhotoInfo.lng then
            				gpsPS.latitude	= tonumber(psPhotoInfo.lat)
            				gpsPS.longitude	= tonumber(psPhotoInfo.lng)
            				gpsPS.type		= 'red'

            			-- psPhotoInfo.gps: GPS info of videos is stored here
            			elseif psPhotoInfo.gps and psPhotoInfo.gps.lat and psPhotoInfo.gps.lng then
            				gpsPS.latitude	= tonumber(psPhotoInfo.gps.lat)
            				gpsPS.longitude	= tonumber(psPhotoInfo.gps.lng)
            				gpsPS.type		= 'red'
            			
            			-- psPhotoAdditional.photo_exif.gps: should be identical to psPhotoInfo
            			elseif 	psPhotoAdditional and psPhotoAdditional.photo_exif and psPhotoAdditional.photo_exif.gps 
            				and psPhotoAdditional.photo_exif.gps.lat and psPhotoAdditional.photo_exif.gps.lng then
            				gpsPS.latitude	= tonumber(psPhotoAdditional.photo_exif.gps.lat)
            				gpsPS.longitude	= tonumber(psPhotoAdditional.photo_exif.gps.lng)
            				gpsPS.type		= 'red'
            			end 
        			end
        		end
    		end
    		
    		------------------------------------------------------------------------------------------------------
    		-- get tags and translated tags (rating, label) from Photo Station if configured (via photo_tag API)
    		if 		collectionSettings.tagsDownload
    			-- GPS coords from locations only if no photo gps available
    			or  (collectionSettings.locationTagDownload and  gpsPS.latitude == 0 and gpsPS.longitude == 0)
    			or  collectionSettings.PS2LrFaces 
    			or  collectionSettings.PS2LrLabel 
    			or  collectionSettings.PS2LrRating 
    		then
    			local photoTags = PSPhotoStationAPI.getPhotoTags(publishSettings.uHandle, photoInfo.remoteId, isVideo)
    		
        		if not photoTags then
        			writeLogfile(1, string.format("Get ratings/metadata: %s failed!\n", photoInfo.remoteId))
        		elseif photoTags and #photoTags > 0 then
    				for i = 1, #photoTags do
    					local photoTag = photoTags[i]
    					writeLogfile(4, string.format("Get ratings/metadata: found tag type %s name %s\n", photoTag.type, photoTag.name))
    					
        				-- a people tag has a face region in additional.info structure
        				if collectionSettings.PS2LrFaces and photoTag.type == 'people' then
--    						table.insert(facesPS, photoTag.additional.info)
    						table.insert(facesPS, photoTag)
        				
        				-- a color label looks like '+red, '+yellow, '+green', '+blue', '+purple' (case-insensitive)
    					elseif collectionSettings.PS2LrLabel and photoTag.type == 'desc' and string.match(photoTag.name, '%+(%a+)') then
    						labelPS = string.match(string.lower(photoTag.name), '%+(%a+)')
    
       					-- ratings look like general tag '*', '**', ... '*****'
        				elseif collectionSettings.PS2LrRating and photoTag.type == 'desc' and string.match(photoTag.name, '([%*]+)') then
    						ratingTagPS = math.min(string.len(photoTag.name), 5)
    					
    					-- any other general tag is taken as-is
    					elseif collectionSettings.tagsDownload and photoTag.type == 'desc' and not string.match(photoTag.name, '%+(%a+)') and not string.match(photoTag.name, '([%*]+)') then
    						table.insert(tagsPS, photoTag.name)
    					
    					-- gps coords belonging to a location tag 
    					elseif collectionSettings.locationTagDownload and photoTag.type == 'geo' and (photoTag.additional.info.lat or photoTag.additional.info.lng) then
            				gpsPS.latitude	= tonumber(ifnil(photoTag.additional.info.lat, 0))
            				gpsPS.longitude	= tonumber(ifnil(photoTag.additional.info.lng, 0))
            				gpsPS.type		= 'blue'
    					end 
        			end
        		end
        					
    		end

    		if collectionSettings.ratingDownload or collectionSettings.PS2LrRating then 
    			ratingCallback({ publishedPhoto = photoInfo, rating = iif(collectionSettings.PS2LrRating, ratingTagPS, ratingPS) or 0 })
    		end
    
    		writeLogfile(3, string.format("Get ratings/metadata: %s - title '%s' caption '%s', location '%s/%s (%s)' rating %d ratingTag %d, label '%s', %d general tags, %d faces\n", 
   							photoInfo.remoteId, ifnil(titlePS, ''), ifnil(captionPS, ''), tostring(gpsPS.latitude), tostring(gpsPS.longitude), ifnil(gpsPS.type, ''),
    							ifnil(ratingPS, 0), ifnil(ratingTagPS, 0), ifnil(labelPS, ''), #tagsPS, #facesPS))

    		------------------------------------------------------------------------------------------------------
			if collectionSettings.titleDownload then
        		local defaultTitlePS = LrPathUtils.removeExtension(LrPathUtils.leafName(photoInfo.remoteId))
--[[
	    		-- title can be stored in two places in PS: in title tag (when entered by PS user) and in exif 'Object Name' (when set by Lr)
   				-- title tag overwrites exif tag, get Object Name only, if no title was found
        		if (not titlePS or titlePS == '' or titlePS == defaultTitlePS) then
    				local exifsPS = PSPhotoStationAPI.getPhotoExifs(publishSettings.uHandle, photoInfo.remoteId, isVideo)
    				if exifsPS then 
    					local namePS = findInAttrValueTable(exifsPS, 'label', 'Object Name', 'value')
    					if namePS then 
    						writeLogfile(3, string.format("Get ratings/metadata: %s - found title %s in exifs\n", photoInfo.remoteId, namePS))
    						titlePS = namePS 
    					end
    				end
    			end
]]
    			
        		-- check if PS title is not empty, is not the Default PS title (filename) and is different to Lr
        		if titlePS and titlePS ~= '' and titlePS ~= defaultTitlePS and titlePS ~= ifnil(srcPhoto:getFormattedMetadata('title'), '') then
        			titleChanged = true
        			nChanges = nChanges + 1
        			resultText = resultText ..  string.format(" title changed from '%s' to '%s',", 
        												ifnil(srcPhoto:getFormattedMetadata('title'), ''), titlePS)
        			writeLogfile(3, string.format("Get ratings/metadata: %s - title changed from '%s' to '%s'\n", 
        											photoInfo.remoteId, ifnil(srcPhoto:getFormattedMetadata('title'), ''), titlePS))
        											
        		elseif (not titlePS or titlePS == '' or titlePS == defaultTitlePS) and ifnil(srcPhoto:getFormattedMetadata('title'), '') ~= '' then
        			resultText = resultText ..  string.format(" title %s removal ignored,", srcPhoto:getFormattedMetadata('title'))
        			writeLogfile(3, string.format("Get ratings/metadata: %s - title %s was removed, setting photo to edited.\n", 
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
        			writeLogfile(3, string.format("Get ratings/metadata: %s - caption changed from '%s' to '%s'\n", 
        											photoInfo.remoteId, ifnil(srcPhoto:getFormattedMetadata('caption'), ''), captionPS))
        		elseif ifnil(captionPS, '') == '' and ifnil(srcPhoto:getFormattedMetadata('caption'), '') ~= '' then
        			resultText = resultText ..  string.format(" caption %s removal ignored,", srcPhoto:getFormattedMetadata('caption'))
        			writeLogfile(3, string.format("Get ratings/metadata: %s - caption %s was removed, setting photo to edited.\n", 
        										photoInfo.remoteId, srcPhoto:getFormattedMetadata('caption')))
        			needRepublish = true        		
        			changesRejected = changesRejected + 1        		
        			nRejectedChanges = nRejectedChanges + 1        		
        		end
    		end
    
    		------------------------------------------------------------------------------------------------------
			if collectionSettings.ratingDownload then
        		-- check if PS rating is not empty and is different to Lr
        		if ratingPS and ratingPS ~= 0 and ratingPS ~= ifnil(photoInfo.photo:getRawMetadata('rating'), 0) then
        			ratingChanged = true
        			nChanges = nChanges + 1  
        			resultText = resultText ..  string.format(" rating changed from %d to %d,", ifnil(srcPhoto:getRawMetadata('rating'), 0), ifnil(ratingPS, 0))
        			writeLogfile(3, string.format("Get ratings/metadata: %s - rating tag changed from %d to %d\n", 
        										photoInfo.remoteId, ifnil(srcPhoto:getRawMetadata('rating'), 0), ifnil(ratingPS, 0)))
        		elseif (not ratingPS or ratingPS == 0) and ifnil(photoInfo.photo:getRawMetadata('rating'), 0)  > 0 then
        			resultText = resultText ..  string.format(" rating %d removal ignored,", ifnil(srcPhoto:getRawMetadata('rating'), 0))
        			writeLogfile(3, string.format("Get ratings/metadata: %s - rating %d was removed, setting photo to edited.\n", 
      											photoInfo.remoteId, ifnil(srcPhoto:getRawMetadata('rating'), 0)))
        			needRepublish = true
        			changesRejected = changesRejected + 1        		
        			nRejectedChanges = nRejectedChanges + 1
        		end
    		end
    
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
        			writeLogfile(3, string.format("Get ratings/metadata: %s - location changed from '%s/%s' to '%s/%s'\n", 
        											photoInfo.remoteId, 
       												tostring(gpsLr.latitude), tostring(gpsLr.longitude),
       												tostring(gpsPS.latitude), tostring(gpsPS.longitude)))

        		elseif	(gpsPS.latitude == 0 and  gpsPS.longitude == 0) 
        		and 	(gpsLr.latitude ~= 0 or gpsLr.longitude ~= 0) then
        			resultText = resultText ..  string.format(" location removal ignored,")
        			writeLogfile(3, string.format("Get ratings/metadata: %s - location was removed, setting photo to edited.\n", 
        										photoInfo.remoteId))
        			needRepublish = true        		
        			changesRejected = changesRejected + 1        		
        			nRejectedChanges = nRejectedChanges + 1        		
        		end
    		end

    		------------------------------------------------------------------------------------------------------
    		if collectionSettings.PS2LrLabel then
	    		-- check if PS label is not empty and is different to Lr
        		if labelPS and labelPS ~= photoInfo.photo:getRawMetadata('colorNameForLabel') then
        			labelChanged = true
        			nChanges = nChanges + 1  
        			resultText = resultText ..  string.format(" label changed from %s to %s,", 
        												srcPhoto:getRawMetadata('colorNameForLabel'), labelPS)
        			writeLogfile(3, string.format("Get ratings/metadata: %s - label changed from %s to %s\n", 
        										photoInfo.remoteId, srcPhoto:getRawMetadata('colorNameForLabel'), labelPS))
        		elseif not labelPS and photoInfo.photo:getRawMetadata('colorNameForLabel') ~= 'grey' then
        			resultText = resultText ..  string.format(" label %s removal ignored,", srcPhoto:getRawMetadata('colorNameForLabel'))
        			writeLogfile(3, string.format("Get ratings/metadata: %s - label %s was removed, setting photo to edited.\n", 
        										photoInfo.remoteId, srcPhoto:getRawMetadata('colorNameForLabel')))
        			needRepublish = true
        			changesRejected = changesRejected + 1        		
        			nRejectedChanges = nRejectedChanges + 1        		
        		end
    		end
    
    		------------------------------------------------------------------------------------------------------
    		if collectionSettings.PS2LrRating then
        		-- check if PS rating tag is not empty and is different to Lr
        		if ratingTagPS and ratingTagPS ~= ifnil(photoInfo.photo:getRawMetadata('rating'), 0) then
        			ratingTagChanged = true
        			nChanges = nChanges + 1  
        			resultText = resultText ..  string.format(" rating tag changed from %d to %d,", ifnil(srcPhoto:getRawMetadata('rating'), 0), ifnil(ratingTagPS, 0))
        			writeLogfile(3, string.format("Get ratings/metadata: %s - rating tag changed from %d to %d\n", 
        										photoInfo.remoteId, ifnil(srcPhoto:getRawMetadata('rating'), 0), ifnil(ratingTagPS, 0)))
        		elseif not ratingTagPS and ifnil(photoInfo.photo:getRawMetadata('rating'), 0)  > 0 then
        			resultText = resultText ..  string.format(" rating tag %d removal ignored,", ifnil(srcPhoto:getRawMetadata('rating'), 0))
        			writeLogfile(3, string.format("Get ratings/metadata: %s - rating tag %d was removed, setting photo to edited.\n", 
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
   				keywordsRemove 	= PSLrUtilities.getPhotoKeywordObjects(srcPhoto, keywordNamesRemove)
    			
    			-- allow update of keywords only if keyword were added or changed, not if keywords were removed
    			-- compare w/ effectively removed keywords 
    			if (#keywordNamesAdd > 0) and (#keywordNamesAdd >= #keywordsRemove) then
    				tagsChanged = true
    				nChanges = nChanges + #keywordNamesAdd + #keywordNamesRemove 
    				if #keywordNamesAdd > 0 then resultText = resultText ..  string.format(" tags to add: '%s',", table.concat(keywordNamesAdd, "','")) end
    				if #keywordNamesRemove > 0 then resultText = resultText ..  string.format(" tags to remove: '%s',", table.concat(keywordNamesRemove, "','")) end
    				writeLogfile(3, string.format("Get ratings/metadata: %s - tags to add: '%s', tags to remove: '%s'\n", 
    										photoInfo.remoteId, table.concat(keywordNamesAdd, "','"), table.concat(keywordNamesRemove, "','")))
				elseif #keywordNamesAdd < #keywordsRemove then
        			resultText = resultText ..  string.format(" keywords %s removal ignored,", table.concat(keywordNamesRemove, "','"))
        			writeLogfile(3, string.format("Get ratings/metadata: %s - keywords %s were removed in PS, setting photo to edited (removal rejected).\n", 
      											photoInfo.remoteId, table.concat(keywordNamesRemove, "','")))
        			needRepublish = true
        			changesRejected = changesRejected + 1
        			nRejectedChanges = nRejectedChanges + 1
				elseif #keywordNamesRemove > #keywordsRemove then
        			resultText = resultText ..  string.format(" keywords to remove '%s' include synonyms or parent keyword (not allowed), removal ignored,", table.concat(keywordNamesRemove, "','"))
        			writeLogfile(3, string.format("Get ratings/metadata: %s - keywords '%s' removed in PS include synonyms or parent keyword (not allowed), setting photo to edited (removal rejected).\n", 
      											photoInfo.remoteId, table.concat(keywordNamesRemove, "','")))
        			needRepublish = true
        			changesRejected = changesRejected + 1        		
        			nRejectedChanges = nRejectedChanges + 1
    			end
    		end
    		
    		------------------------------------------------------------------------------------------------------
    		if collectionSettings.PS2LrFaces and not isVideo then
				-- get face regions in local photo
				local facesLr 
				facesLr, origPhotoDimension = PSExiftoolAPI.queryLrFaceRegionList(publishSettings.eHandle, srcPhoto:getRawMetadata('path'))
				
        		if facesLr and #facesLr > 0 then
        			local j, faceLrNorm = 0, {}
        			for i = 1, #facesLr do
        				-- exclude all unnamed face regions, because PS does not support them
        				if ifnil(facesLr[i].name, '') ~= '' then
        					j = j + 1
        					faceLrNorm[j] = PSUtilities.normalizeArea(facesLr[i]);
        				end
        			end
    
        			-- compare only names, not the area itself
        			facesAdd 			= getTableDiff(facesPS, faceLrNorm, 'name')
        			facesRemove 		= getTableDiff(faceLrNorm, facesPS, 'name')

        			if facesAdd and facesRemove then
    	       			writeLogfile(3, string.format("Get ratings/metadata: %s - Lr faces: %d, PS faces: %d, Add: %d, Remove: %d\n", 
        	  											photoInfo.remoteId, #facesLr, #facesPS, #facesAdd, #facesRemove))
        			end
				else
					facesAdd = facesPS
					facesRemove = {}
				end
       			faceNamesAdd 		= getTableExtract(facesAdd, 'name')
       			faceNamesRemove 	= getTableExtract(facesRemove, 'name')
								
    			-- allow update of faces only if faces were added or changed, not if faces were removed 
    			if (#facesAdd > 0) and (#facesAdd >= #facesRemove) then
    				facesChanged = true
    				table.insert(reloadPhotos, srcPhoto:getRawMetadata('path'))
    				nChanges = nChanges + #facesAdd + #facesRemove 
    				if #facesAdd > 0 then resultText = resultText ..  string.format(" faces to add: '%s',", table.concat(faceNamesAdd, "','")) end
    				if #facesRemove > 0 then resultText = resultText ..  string.format(" faces to remove: '%s',", table.concat(faceNamesRemove, "','")) end
    				writeLogfile(3, string.format("Get ratings/metadata: %s - faces to add: %s, faces to remove: %s\n", 
    										photoInfo.remoteId, table.concat(faceNamesAdd, ','), table.concat(faceNamesRemove, ',')))
				elseif #facesAdd < #facesRemove then
        			resultText = resultText ..  string.format(" faces %s removal ignored,", table.concat(faceNamesRemove, "','"))
        			writeLogfile(3, string.format("Get ratings/metadata: %s - faces %s were removed in PS, setting photo to edited (removal rejected).\n", 
      											photoInfo.remoteId, table.concat(faceNamesRemove, "','")))
        			needRepublish = true
        			changesRejected = changesRejected + 1        		
        			nRejectedChanges = nRejectedChanges + 1
        		end
    		end
    		
    		------------------------------------------------------------------------------------------------------

    		-- if anything changed in Photo Station, change value in Lr
    		if titleChanged 
    		or captionChanged 
    		or ratingChanged 
     		or gpsChanged 
    		or labelChanged 
    		or ratingTagChanged 
    		or tagsChanged 
    		or needRepublish then
        		catalog:withWriteAccessDo( 
        			'SetCaptionLabelRating',
        			function(context)
        				if titleChanged			then srcPhoto:setRawMetadata('title', titlePS) end
        				if captionChanged		then srcPhoto:setRawMetadata('caption', captionPS) end
         				if gpsChanged			then srcPhoto:setRawMetadata('gps', gpsPS) end
        				if labelChanged			then srcPhoto:setRawMetadata('colorNameForLabel', labelPS) end
        				if ratingChanged		then srcPhoto:setRawMetadata('rating', ratingPS) end
        				if ratingTagChanged		then srcPhoto:setRawMetadata('rating', ratingTagPS) end
        				if tagsChanged then 
    						for i = 1, #keywordNamesAdd do PSLrUtilities.createAndAddPhotoKeywordHierarchy(srcPhoto, keywordNamesAdd[i])	end
    						for i = 1, #keywordsRemove 	do srcPhoto:removeKeyword(keywordsRemove[i])	end
        				end 
        				if needRepublish 		then photoInfo.publishedPhoto:setEditedFlag(true) end
        			end,
        			{timeout=5}
        		)

   				writeLogfile(3, string.format("Get ratings/metadata: %s - changes done.\n", photoInfo.remoteId))
				-- if keywords were updated: check if resulting Lr keyword list matches PS keyword list (might be different due to parent keywords)
				if tagsChanged then
        			-- get all exported keywords including parent keywords and synonnyms, excluding those that are to be exported
    				local keywordsForExport = trimTable(split(srcPhoto:getFormattedMetadata("keywordTagsForExport"), ','))
        		
        			-- get delta lists: which keywords need to be added or removed in PS
        			local keywordNamesNeedRemoveinPS	= getTableDiff(tagsPS, keywordsForExport) 
        			local keywordNamesNeedAddinPS 	 	= getTableDiff(keywordsForExport, tagsPS)
        			if #keywordNamesNeedRemoveinPS > 0 or #keywordNamesNeedAddinPS > 0 then
	    				writeLogfile(3, string.format("Get ratings/metadata: %s - must sync keywords to PS, add: '%s', remove '%s'\n", 
	    												photoInfo.remoteId,
	    												table.concat(keywordNamesNeedAddinPS, "','"),
	    												table.concat(keywordNamesNeedRemoveinPS, "','")))
        				needRepublish = true
        			end
				end
				
				if not needRepublish then
    				writeLogfile(3, string.format("Get ratings/metadata: %s - set to Published\n", photoInfo.remoteId))
    				 
            		catalog:withWriteAccessDo( 
            			'ResetEdited',
            			function(context) photoInfo.publishedPhoto:setEditedFlag(false) end,
            			{timeout=5}
            		)
				end
    		end
    		
   			-- overwrite all existing face regions in local photo
    		if facesChanged then
				if not origPhotoDimension then
        			writeLogfile(3, string.format("Get ratings/metadata: %s - cannot download added face regions, no local XMP data file!\n", 
      											photoInfo.remoteId))
        			changesFailed = changesFailed + 1        		
        			nFailed = nFailed + 1				
    			else
    				-- take over the complete PS face list
        			local facesLrAdd = {}
        			for i = 1, #facesPS do
        				facesLrAdd[i] = PSUtilities.denormalizeArea(facesPS[i].additional.info, origPhotoDimension)
        			end
        			if not PSExiftoolAPI.setLrFaceRegionList(publishSettings.eHandle, srcPhoto, facesLrAdd, origPhotoDimension) then
    	   				nChanges = nChanges - (#facesAdd + #facesRemove)
       					changesFailed = changesFailed +1
       					nFailed = nFailed + 1
       				end 
				end
	    	end  

    		if titleChanged	or captionChanged or ratingChanged or labelChanged or ratingTagChanged or tagsChanged or facesChanged or gpsChanged then
        		writeLogfile(2, string.format("Get ratings/metadata: %s - %s %s%s%s.\n", 
        												photoInfo.remoteId, resultText,
        												iif(changesFailed > 0, 'failed', 'done'), 
        												iif(changesRejected > 0, ', ' .. tostring(changesRejected) .. ' rejected changes', ''),
        												iif(needRepublish, ', Re-publish needed', '')))
    		else
    			writeLogfile(2, string.format("Get ratings/metadata: %s - no changes%s.\n", 
    													photoInfo.remoteId, 
        												iif(changesRejected > 0, ', ' .. tostring(changesRejected) .. ' rejected changes', '')))
    		end
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
		message = LOC ("$$$/PSUpload/FinalMsg/GetRatingsFromPublishedCollection/Error=^1 added/modified, ^2 failed and ^3 rejected removed metadata items for ^4 of ^5 pics in ^6 seconds (^7 pics/sec).", 
					nChanges, nFailed, nRejectedChanges, nProcessed, nPhotos, string.format("%.1f", timeUsed + 0.5), string.format("%.1f", picPerSec))
		showFinalMessage("Photo StatLr: Get ratings/metadata done", message, "critical")
	else
		message = LOC ("$$$/PSUpload/FinalMsg/GetRatingsFromPublishedCollection=^1 added/modified metadata items for ^2 of ^3 pics in ^4 seconds (^5 pics/sec).", 
					nChanges, nProcessed, nPhotos, string.format("%.1f", timeUsed + 0.5), string.format("%.1f", picPerSec))
		if #reloadPhotos > 0 then
			message = message .. string.format("\nThe following photos must be reloaded (added faces):\n%s", table.concat(reloadPhotos, '\n'))
			showFinalMessage("Photo StatLr: Get ratings/metadata done", message, "warning")
		else
			showFinalMessage("Photo StatLr: Get ratings/metadata done", message, "info")
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

	-- add comment to photo in Photo Station album, comments to public share is not possible 
	return PSPhotoStationAPI.addPhotoComment(publishSettings.uHandle, remotePhotoId, PSLrUtilities.isVideo(remotePhotoId), commentText, publishSettings.username .. '@Lr')
end
--------------------------------------------------------------------------------

PSPublishSupport = publishServiceProvider
