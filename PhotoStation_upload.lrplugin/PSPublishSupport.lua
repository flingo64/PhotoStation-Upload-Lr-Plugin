--[[----------------------------------------------------------------------------

PSPublishSupport.lua
Publish support for Lightroom PhotoStation Upload
Copyright(c) 2015, Martin Messmer

This file is part of PhotoStation Upload - Lightroom plugin.

PhotoStation Upload is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

PhotoStation Upload is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PhotoStation Upload.  If not, see <http://www.gnu.org/licenses/>.

PhotoStation Upload uses the following free software to do its job:
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
local LrApplication =	import 'LrApplication'
local LrBinding	= 		import 'LrBinding'
local LrColor = 		import 'LrColor'
local LrDate = 			import 'LrDate'
local LrDialogs = 		import 'LrDialogs'
local LrHttp = 			import 'LrHttp'
local LrPathUtils = 	import 'LrPathUtils'
local LrView = 			import 'LrView'

require "PSConvert"
require "PSUtilities"
require 'PSUploadTask'
require 'PSUploadExportDialogSections'

--===========================================================================--

local publishServiceProvider = {}

--------------------------------------------------------------------------------
--- (string) Plug-in defined value is the filename of the icon to be displayed
 -- for this publish service provider, in the Publish Services panel, the Publish 
 -- Manager dialog, and in the header shown when a published collection is selected.
 -- The icon must be in PNG format and no more than 24 pixels wide or 19 pixels tall.

publishServiceProvider.small_icon = 'PhotoStation.png'

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
--		maxCollectionSetDepth = 0,
			-- Collection sets are not supported through the PhotoStation Upload plug-in.
	}
	
end

--------------------------------------------------------------------------------
--- When set to the string "disable", the "Go to Published Collection" context-menu item
 -- is disabled (dimmed) for this publish service.

publishServiceProvider.titleForGoToPublishedCollection = LOC "$$$/PSPublish/TitleForGoToPublishedCollection=Show in PhotoStation"

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user chooses
 -- the "Go to Published Collection" context-menu item.
function publishServiceProvider.goToPublishedCollection( publishSettings, info )
	local albumPath, albumUrl 

	-- make sure logfile is opened
	openLogfile(publishSettings.logLevel)

	albumPath = PSLrUtilities.getCollectionUploadPath(info.publishedCollection)
	
	if PSLrUtilities.isDynamicAlbumPath(albumPath)then 
		showFinalMessage("PhotoStation Upload: GoToPublishedCollection failed!", "Cannot open dynamic album path: '" .. albumPath .. "'", "critical")
		closeLogfile()
		return
	end

	-- open session: initialize environment, get missing params and login
	local sessionSuccess, reason = openSession(publishSettings, info.publishedCollection, 'GoToPublishedCollection')
	if not sessionSuccess then
		if reason ~= 'cancel' then
			showFinalMessage("PhotoStation Upload: GoToPublishedCollection failed!", reason, "critical")
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

publishServiceProvider.titleForGoToPublishedPhoto = LOC "$$$/PSPublish/TitleForGoToPublishedCollection=Show in PhotoStation"

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
			showFinalMessage("PhotoStation Upload: goToPublishedPhoto failed!", reason, "critical")
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
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.didCreateNewPublishService( publishSettings, info )
end

--]]

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user creates
 -- a new publish service via the Publish Manager dialog. It allows your plug-in
 -- to perform additional initialization.
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.didUpdatePublishService( publishSettings, info )
end

]]--

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has attempted to delete the publish service from Lightroom.
 -- It provides an opportunity for you to customize the confirmation dialog.
 -- @return (string) 'cancel', 'delete', or nil (to allow Lightroom's default
 -- dialog to be shown instead)
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.shouldDeletePublishService( publishSettings, info )
end

]]--

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has confirmed the deletion of the publish service from Lightroom.
 -- It provides a final opportunity for	you to remove private data
 -- immediately before the publish service is removed from the Lightroom catalog.
--[[ Not used for PhotoStation Upload plug-in.

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
--[[ Not used for PhotoStation Upload plug-in.
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
			showFinalMessage("PhotoStation Upload: DeletePhotosFromPublishedCollection failed!", reason, "critical")
		end
		closeLogfile()
		return
	end

	local startTime = LrDate.currentTime()
	local nPhotos = #arrayOfPhotoIds
	local nProcessed = 0 

	for i, photoId in ipairs( arrayOfPhotoIds ) do
		if PSPhotoStationAPI.deletePic (publishSettings.uHandle, photoId, PSLrUtilities.isVideo(photoId)) then
			writeLogfile(2, photoId .. ': successfully deleted.\n')
			nProcessed = nProcessed + 1
			deletedCallback( photoId )
		else
			writeLogfile(1, photoId .. ': deletion failed!\n')
		end
	end

	local collectionPath =  PSLrUtilities.getCollectionUploadPath(publishedCollection)
	
	local albumsDeleted = {}
	local photosLeft = {}
	
	if not PSLrUtilities.isDynamicAlbumPath(collectionPath) then
		_ = PSPhotoStationAPI.deleteEmptyAlbums(publishSettings.uHandle, collectionPath, albumsDeleted, photosLeft)
		
		if #albumsDeleted > 0 then
			writeLogfile(2, string.format("PhotoStation Upload: DeletePhotosFromPublishedCollection:\n\tDeleted Albums:\n\t\t%s\n",
										table.concat(albumsDeleted, "\n\t\t")))
		end
	end										

	local timeUsed 	= LrDate.currentTime() - startTime
	local picPerSec = nProcessed / timeUsed
	local message = LOC ("$$$/PSUpload/Upload/Errors/CheckMoved=" .. 
					string.format("Deleted %d of %d pics in %d seconds (%.1f pics/sec).\n", 
					nProcessed, nPhotos, timeUsed + 0.5, picPerSec))

	showFinalMessage("PhotoStation Upload: DeletePhotosFromPublishedCollection done", message, "info")
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
	
	local message = nil
	
	repeat
		-- Use a repeat loop to allow easy way to "break" out.
		-- (It only goes through once.)
		
		if collectionSettings.copyTree and not validateDirectory(nil, collectionSettings.srcRoot) then
			message = LOC "$$$/PSUpload/CollectionDialog/Messages/EnterSubPath=Enter a source path"
			break
		end
				
		if not collectionSettings.copyTree and collectionSettings.publishMode == 'CheckMoved' then
			message = LOC ("$$$/PSUpload/CollectionDialog/CheckMovedNotNeeded=CheckMoved not supported if not mirror tree copy.\n")
			break
		end
	until true
	
	if message then
		collectionSettings.hasError = true
		collectionSettings.message = message
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
	local bind = LrView.bind
	local share = LrView.share

	local collectionSettings = assert( info.collectionSettings )

	-- observe settings to enablle/disable "Store" button
	if collectionSettings.hasError == nil then
		collectionSettings.hasError = false
	end

	collectionSettings:addObserver( 'srcRoot', updateCollectionStatus )
	collectionSettings:addObserver( 'copyTree', updateCollectionStatus )
	collectionSettings:addObserver( 'publishMode', updateCollectionStatus )
	updateCollectionStatus( collectionSettings )
		
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

	if collectionSettings.publishMode == nil then
		collectionSettings.publishMode = 'Publish'
	end

	return f:view {
		size = 'small',
		fill_horizontal = 1,
		bind_to_object = assert( collectionSettings ),
		
    	f:column {
    		fill_horizontal = 1,
    		spacing = f:label_spacing(),

    		f:group_box {
    			title = LOC "$$$/PSUpload/ExportDialog/TargetAlbum=Target Album and Upload Method",
       			fill_horizontal = 1,
    
    			f:row {
    				f:static_text {
    					title = LOC "$$$/PSUpload/ExportDialog/StoreDstRoot=Enter Target Album:",
    					alignment = 'right',
    					width = share 'labelWidth'
    				},
    
    				f:edit_field {
    					tooltip = LOC "$$$/PSUpload/ExportDialog/DstRootTT=Enter the target directory below the diskstation share '/photo' or '/home/photo'\n(may be different from the Album name shown in PhotoStation)",
    					value = bind 'dstRoot',
    					truncation = 'middle',
    					immediate = true,
    					fill_horizontal = 1,
    				},
    
    				f:checkbox {
    					title = LOC "$$$/PSUpload/ExportDialog/createDstRoot=Create Album, if needed",
    					alignment = 'left',
    					width = share 'labelWidth',
    					value = bind 'createDstRoot',
    					fill_horizontal = 1,
    				},
    			}, -- row
    			
    			f:row {
    				f:radio_button {
    					title = LOC "$$$/PSUpload/ExportDialog/FlatCp=Flat copy to Target Album",
    					tooltip = LOC "$$$/PSUpload/ExportDialog/FlatCpTT=All photos/videos will be copied to the Target Album",
    					alignment = 'right',
    					value = bind 'copyTree',
    					checked_value = false,
    					width = share 'labelWidth',
    				},
    
    				f:radio_button {
    					title = LOC "$$$/PSUpload/ExportDialog/CopyTree=Mirror tree relative to Local Path:",
    					tooltip = LOC "$$$/PSUpload/ExportDialog/CopyTreeTT=All photos/videos will be copied to a mirrored directory below the Target Album",
    					alignment = 'left',
    					value = bind 'copyTree',
    					checked_value = true,
    				},
    
    				f:edit_field {
    					value = bind 'srcRoot',
    					tooltip = LOC "$$$/PSUpload/ExportDialog/CopyTreeTT=Enter the local path that is the root of the directory tree you want to mirror below the Target Album.",
    					enabled = bind 'copyTree',
    					visible = bind 'copyTree',
    					validate = validateDirectory,
    					truncation = 'middle',
    					immediate = true,
    					fill_horizontal = 1,
    				},
    			}, -- row
    
    			f:separator { fill_horizontal = 1 },
    
    			f:row {
    				f:checkbox {
    					title = LOC "$$$/PSUpload/ExportDialog/RAWandJPG=RAW+JPG to same Album",
    					tooltip = LOC "$$$/PSUpload/ExportDialog/RAWandJPGTT=Allow Lr-developed RAW+JPG from camera to be uploaded to same Album.\n" ..
    									"Non-JPEG photo will be renamed to <photoname>_<OrigExtension>.<OutputExtension>. E.g.:\n" ..
    									"IMG-001.RW2 --> IMG-001_RW2.JPG\n" .. 
    									"IMG-001.JPG --> IMG-001.JPG",
    					alignment = 'left',
    					value = bind 'RAWandJPG',
    					fill_horizontal = 1,
    				},
    
    				f:checkbox {
    					title = LOC "$$$/PSUpload/ExportDialog/SortPhotos=Sort Photos in PhotoStation",
    					tooltip = LOC "$$$/PSUpload/ExportDialog/SortPhotosTT=Sort photos in PhotoStation according to sort order of Published Collection.\n" ..
    									"Note: Sorting is not possible for dynamic Target Albums (including metadata placeholders)\n",
    					alignment = 'left',
    					value = bind 'sortPhotos',
    					enabled =  LrBinding.negativeOfKey('copyTree'),
    					fill_horizontal = 1,
    				},
    			}, -- row
    		}, -- group
    	
    		f:spacer { height = 10, },
    
    		f:row {
    			alignment = 'left',
    			fill_horizontal = 1,
    
    			f:static_text {
    				title = LOC "$$$/PSUpload/CollectionSettings/PublishMode=Publish Mode:",
    				alignment = 'right',
    				width = share 'labelWidth',
    			},
    
    			f:popup_menu {
    				tooltip = LOC "$$$/PSUpload/CollectionSettings/PublishModeTT=How to publish",
    				value = bind 'publishMode',
    				alignment = 'left',
    				fill_horizontal = 1,
    				items = {
    					{ title	= 'Ask me later',																value 	= 'Ask' },
    					{ title	= 'Normal',																		value 	= 'Publish' },
    					{ title	= 'CheckExisting: Set Unpublished to Published if existing in PhotoStation.',	value 	= 'CheckExisting' },
    					{ title	= 'CheckMoved: Set Published to Unpublished if moved locally.',					value 	= 'CheckMoved' },
    				},
    			},
			}, -- row
	
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
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.endDialogForCollectionSettings( publishSettings, info )
	-- not used for PhotoStation Upload plug-in
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
	local bind = LrView.bind
	local share = LrView.share

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
		title = "PhotoStation Upload Settings",  -- this should be localized via LOC
		size = 'small',
		fill_horizontal = 1,
		bind_to_object = assert( collectionSetSettings ),
		
		f:column {
			fill_horizontal = 1,
			spacing = f:label_spacing(),

			f:row {
				f:static_text {
					title = LOC "$$$/PSUpload/ExportDialog/StoreDstRoot=Enter Target Album:",
					alignment = 'right',
					width = share 'labelWidth'
				},

				f:edit_field {
					tooltip = LOC "$$$/PSUpload/ExportDialog/DstRootTT=Enter the target directory below the diskstation share '/photo' or '/home/photo'\n(may be different from the Album name shown in PhotoStation)",
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
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.endDialogForCollectionSetSettings( publishSettings, info )
	-- not used for PhotoStation Upload plug-in
end

--]]

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has changed the per-collection set settings defined via the <code>viewForCollectionSetSettings</code>
 -- callback. It is your opportunity to update settings on your web service to
 -- match the new settings.
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.updateCollectionSetSettings( publishSettings, info )
end

--]]

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when new or updated
 -- photos are about to be published to the service. It allows you to specify whether
 -- the user-specified sort order should be followed as-is or reversed.
--[[ Not used for PhotoStation Upload plug-in.

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
	-- get publishedCollections: 
	--   remoteCollectionId is the only collectionId we have here, so it must be equal to localCollectionId to retrieve the publishedCollection!!!
	local publishedCollection = LrApplication.activeCatalog():getPublishedCollectionByLocalIdentifier(info.remoteCollectionId)
	local albumPath = PSLrUtilities.getCollectionUploadPath(publishedCollection)

	-- make sure logfile is opened
	openLogfile(publishSettings.logLevel)

	writeLogfile(3, "imposeSortOrderOnPublishedCollection: starting\n")

	-- open session: initialize environment, get missing params and login
	local sessionSuccess, reason = openSession(publishSettings, publishedCollection, 'ImposeSortOrderOnPublishedCollection')
	if not sessionSuccess then
		if reason ~= 'cancel' then
			showFinalMessage("PhotoStation Upload: Sort Photos in Album failed!", reason, "critical")
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

	showFinalMessage("PhotoStation Upload: Sort Photos in Album done", "Sort Photos in Album done.", "info")

	closeLogfile(publishSettings)

	return true
end

-------------------------------------------------------------------------------
--- This plug-in defined callback function is called when the user attempts to change the name
 -- of a collection, to validate that the new name is acceptable for this service.
--[[ Not used for PhotoStation Upload plug-in.

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

--[[ Not used for PhotoStation Upload plug-in.

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
			showFinalMessage("PhotoStation Upload: deletePublishedCollection failed!", reason, "critical")
		end
		closeLogfile()
		return
	end

	writeLogfile(3, "deletePublishedCollection: starting\n")
	local startTime = LrDate.currentTime()
	local publishedPhotos = info.publishedCollection:getPublishedPhotos() 
	local nPhotos = #publishedPhotos
	local nProcessed = 0 
	
	writeLogfile(2, string.format("deletePublishedCollection: deleting %d published photos from collection %s\n", nPhotos, info.name ))

	-- Set progress title.
	import 'LrFunctionContext'.callWithContext( 'publishServiceProvider.deletePublishedCollection', function( context )
	
		local progressScope = LrDialogs.showModalProgressDialog {
							title = LOC( "$$$/PSPublish/DeletingCollectionAndContents=Deleting collection ^[^1^]", info.name ),
							functionContext = context }
						
		for i = 1, nPhotos do
			if progressScope:isCanceled() then break end
			
			local pubPhoto = publishedPhotos[i]
			local publishedPath = pubPhoto:getRemoteId()

			writeLogfile(2, string.format("deletePublishedCollection: deleting %s from  %s\n ", publishedPath, info.name ))

--			if publishedPath ~= nil then PSFileStationAPI.deletePic(publishSettings.fHandle, publishedPath) end
			if PSPhotoStationAPI.deletePic(publishSettings.uHandle, publishedPath, PSLrUtilities.isVideo(publishedPath)) then
				writeLogfile(2, publishedPath .. ': successfully deleted.\n')
				nProcessed = nProcessed + 1
			else
				writeLogfile(1, publishedPath .. ': deletion failed!\n')
			end
			progressScope:setPortionComplete(nProcessed, nPhotos)
		end 
		progressScope:done()
	end )
		
	local collectionPath =  PSLrUtilities.getCollectionUploadPath(info.publishedCollection)
	
	local albumsDeleted = {}
	local photosLeft = {}
	local albumDeleted = false
	
	if not PSLrUtilities.isDynamicAlbumPath(collectionPath) then
		local canDeleteAlbum = PSPhotoStationAPI.deleteEmptyAlbums(publishSettings.uHandle, collectionPath, albumsDeleted, photosLeft)
		
		writeLogfile(2, string.format("DeletePublishedCollection --> can delete this album: %s\n\tDeleted Albums:\n\t\t%s\n\tPhotos left:\n\t\t%s\n",
										canDeleteAlbum, 
										table.concat(albumsDeleted, "\n\t\t"),
										table.concat(photosLeft, "\n\t\t")))
										
		-- only delete root dir of publish collection, if empty and album creation is allowed in settings 
		if canDeleteAlbum and publishSettings.createDstRoot then
			albumDeleted = PSPhotoStationAPI.deleteAlbum(publishSettings.uHandle, collectionPath)
		end
	end
	
	local timeUsed 	= LrDate.currentTime() - startTime
	local picPerSec = nProcessed / timeUsed
	local message = LOC ("$$$/PSUpload/Upload/Errors/DeletePublishedColletion=" .. 
					string.format("Deleted %d of %d pics in %d seconds (%.1f pics/sec).\n%d albums deleted, %d photos left in PhotoStation, Target Album was %sdeleted.", 
					nProcessed, nPhotos, timeUsed + 0.5, picPerSec, #albumsDeleted, #photosLeft, iif(albumDeleted, "", "not ")))

	showFinalMessage("PhotoStation Upload: DeletePublishedCollection done", message, "info")
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
	local containedPublishedCollections = arrayOfPhotoInfo[1].photo:getContainedPublishedCollections() 
	local publishedCollection
	
	
	for i=1, #containedPublishedCollections do
		if containedPublishedCollections[i]:getService():getPluginId() == plugin_TkId then
			-- TODO: check if collection supports comments
			publishedCollection = containedPublishedCollections[i]
		end
	end
	-- make sure logfile is opened
	openLogfile(publishSettings.logLevel)

	if #arrayOfPhotoInfo > 100 then
		showFinalMessage("PhotoStation Upload: GetCommentsFromPublishedCollection failed!", 'Too many photos', "critical")
		closeLogfile()
		return
	end
	
	-- open session: initialize environment, get missing params and login
	local sessionSuccess, reason = openSession(publishSettings, publishedCollection, 'GetCommentsFromPublishedCollection')
	if not sessionSuccess then
		if reason ~= 'cancel' then
			showFinalMessage("PhotoStation Upload: GetCommentsFromPublishedCollection failed!", reason, "critical")
		end
		closeLogfile()
		return
	end

	for i, photoInfo in ipairs( arrayOfPhotoInfo ) do

		local success, comments = PSPhotoStationAPI.getComments(publishSettings.uHandle, photoInfo.remoteId, photoInfo.photo:getRawMetadata('isVideo'))
		if not success then
			writeLogfile(1, string.format("GetCommentsFromPublishedCollection: %s failed!\n", photoInfo.remoteId))
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
	  								realname = comment.name,
    								url = PSPhotoStationAPI.getPhotoUrl(publishSettings.uHandle, photoInfo.remoteId, photoInfo.photo:getRawMetadata('isVideo'))
    							} )
    
    			end			
    
    		end	
			writeLogfile(2, string.format("GetCommentsFromPublishedCollection: %s - %d comments\n", photoInfo.remoteId, #commentList))
			writeTableLogfile(4, "commentList", commentList)
    		commentCallback( {publishedPhoto = photoInfo, comments = commentList} )						    
		end
	end
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
  -- <ul>
    -- <li>For every photo in the published collection each time <i>any</i> photo
	-- in the collection is published or re-published.</li>
 	-- <li>When the user clicks the Refresh button in the Library module's Comments panel.</li>
	-- <li>After the user adds a new comment to a photo in the Library module's Comments panel.</li>
  -- </ul>
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.getRatingsFromPublishedCollection( publishSettings, arrayOfPhotoInfo, ratingCallback )

	for i, photoInfo in ipairs( arrayOfPhotoInfo ) do

		local rating = FlickrAPI.getNumOfFavorites( publishSettings, { photoId = photoInfo.remoteId } )
		if type( rating ) == 'string' then rating = tonumber( rating ) end

		ratingCallback{ publishedPhoto = photoInfo, rating = rating or 0 }

	end
end
]]	

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
			showFinalMessage("PhotoStation Upload: AddCommentToPublishedPhoto failed!", reason, "critical")
		end
		closeLogfile()
		return
	end
--	changeLoglevel(4)

	writeLogfile(2, string.format("AddCommentToPublishedPhoto: %s - %s\n", remotePhotoId, commentText))
	return PSPhotoStationAPI.addComment(publishSettings.uHandle, remotePhotoId, PSLrUtilities.isVideo(remotePhotoId), commentText, publishSettings.username .. '@Lr')
end
--------------------------------------------------------------------------------

PSPublishSupport = publishServiceProvider
