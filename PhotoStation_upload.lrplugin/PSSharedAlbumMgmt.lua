--[[----------------------------------------------------------------------------

PSSharedAlbumMgmt.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2015-2023, Martin Messmer

Management of Photo Server Shared Albums for Lightroom Photo StatLr

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

------------------------------------------------------------------------------]]

-- Lightroom SDK
local LrApplication		= import 'LrApplication'
local LrDate			= import 'LrDate'
local LrDialogs			= import 'LrDialogs'
local LrPathUtils 		= import 'LrPathUtils'
local LrProgressScope 	= import 'LrProgressScope'
local LrPrefs			= import 'LrPrefs'

-- Photo StatLr plug-in
require "PSUtilities"

--============================================================================--

PSSharedAlbumMgmt = {}

--------------------------------------------------------------------------------------------
-- sharedAlbumDefaults
PSSharedAlbumMgmt.sharedAlbumDefaults = {
	isAdvanced			= false,
	isPublic			= true,
    publicPermissions   = 'View',
    sharedAlbumPassword	= '',
	startTime			= '',
	stopTime 			= '',
	colorRed			= true,
	colorYellow			= true,
	colorGreen			= true,
	colorBlue			= true,
	colorPurple			= true,
	comments			= true,
	areaTool			= true,
	privateUrl			= '',
	publicUrl			= '',
	publicUrl2			= '',
}

PSSharedAlbumMgmt.sharedAlbumPermissionItems = {
    { title	= 'View',       value 	= 'View' },
    { title	= 'Download',	value 	= 'Download' },
}
--------------------------------------------------------------------------------------------
-- getSharedAlbumKeywordPath(pubServiceName, sharedAlbumName)
--   returns keyword path of the given Shared Album within the given Publish Service, i.e:
--    "Photo StatLr"|"Shared Albums|<puServiceName>|<sharedAlbumName"
function PSSharedAlbumMgmt.getSharedAlbumKeywordPath(pubServiceName, sharedAlbumName)
	if sharedAlbumName then
		return "Photo StatLr|Shared Albums|" .. pubServiceName .. "|" .. sharedAlbumName
	else
		return "Photo StatLr|Shared Albums|" .. pubServiceName
	end
end

--------------------------------------------------------------------------------------------
-- loadSharedAlbumParams(sharedAlbumKeyword, publishSettings)
--   returns SharedAlbum params for the given Shared Album keyword as stored in plugin prefs
function PSSharedAlbumMgmt.loadSharedAlbumParams(sharedAlbumKeyword, publishSettings)
	local myPrefs 			    = LrPrefs.prefsForPlugin()
    local sharedAlbumId		    = sharedAlbumKeyword.localIdentifier
    local sharedAlbumName 	    = sharedAlbumKeyword:getName()
    local sharedAlbumDefaults   = publishSettings and PHOTOSERVER_API[publishSettings.psVersion].API.sharedAlbumDefaults

	local sharedAlbumParams = {
			sharedAlbumName 	= sharedAlbumName,
	}

    -- if SharedAlbum is already stored in plugin prefs, fetch them
    local sharedAlbumPrefs = (myPrefs.sharedAlbums and myPrefs.sharedAlbums[sharedAlbumId]) or {}
    -- load only keys mentioned in SharedAlbumDefaults
    for key, defaultValue in pairs(sharedAlbumDefaults) do
        sharedAlbumParams[key] = ifnil(sharedAlbumPrefs[key], defaultValue)
    end

    writeTableLogfile(3, 'loadSharedAlbumParams: returns', sharedAlbumParams, true, 'sharedAlbumPassword')

	return sharedAlbumParams
end

--------------------------------------------------------------------------------------------
-- storeSharedAlbumParams(sharedAlbumKeyword, sharedAlbumParams)
--   store SharedAlbum params in plugin prefs
function PSSharedAlbumMgmt.storeSharedAlbumParams(sharedAlbumKeyword, sharedAlbumParams)
	local myPrefs 			    = LrPrefs.prefsForPlugin()
    local sharedAlbumId		    = sharedAlbumKeyword.localIdentifier

    writeTableLogfile(3, 'PSSharedAlbumMgmt.storeSharedAlbumParams', sharedAlbumParams, true, 'sharedAlbumPassword')
    if not myPrefs.sharedAlbums                 then myPrefs.sharedAlbums = {} end
    if not myPrefs.sharedAlbums[sharedAlbumId]  then myPrefs.sharedAlbums[sharedAlbumId] = {} end
    local sharedAlbumPrefs = myPrefs.sharedAlbums[sharedAlbumId]

    -- store only keys mentioned in SharedAlbumDefaults
    for key, _ in pairs(PSSharedAlbumMgmt.sharedAlbumDefaults) do
        sharedAlbumPrefs[key] = sharedAlbumParams[key]
    end
    
    -- do self-assignment to force Lr to store the prefs
    myPrefs.sharedAlbums[sharedAlbumId] = myPrefs.sharedAlbums[sharedAlbumId]
    myPrefs.sharedAlbums = myPrefs.sharedAlbums

end

--------------------------------------------------------------------------------------------
-- removeSharedAlbumParams(sharedAlbumKeyword)
--   remove SharedAlbum params from plugin prefs
function PSSharedAlbumMgmt.removeSharedAlbumParams(sharedAlbumKeyword)
	local myPrefs 			    = LrPrefs.prefsForPlugin()
    local sharedAlbumId		    = sharedAlbumKeyword.localIdentifier

    writeLogfile(3, string.format("PSSharedAlbumMgmt.removeSharedAlbumParams('%s')", sharedAlbumKeyword:getName()))
    if myPrefs.sharedAlbums and myPrefs.sharedAlbums[sharedAlbumId] then 
        myPrefs.sharedAlbums[sharedAlbumId] = {}
    end

    -- do self-assignment to force Lr to store the prefs
    myPrefs.sharedAlbums = myPrefs.sharedAlbums
end

--------------------------------------------------------------------------------------------
-- setSharedAlbumUrls(publishServiceName, sharedAlbumParams, publishSettings)
--   adds the private and public Shared Album URLs to the Shared Album params in Lr Plugin prefs
function PSSharedAlbumMgmt.setSharedAlbumUrls(publishServiceName, sharedAlbumParams, publishSettings)
	local myPrefs 			    	= LrPrefs.prefsForPlugin()
	local sharedAlbumKeywordPath	= PSSharedAlbumMgmt.getSharedAlbumKeywordPath(publishServiceName, sharedAlbumParams.sharedAlbumName)
	local sharedAlbumId, _			= PSLrUtilities.getKeywordByPath(sharedAlbumKeywordPath, false)

    writeLogfile(4, string.format("PSSharedAlbumMgmt.setSharedAlbumUrls('%s') ...", sharedAlbumParams.sharedAlbumName))
	if not openSession(publishSettings, nil, 'ManageSharedAlbums') or not sharedAlbumId then
		return
	end
	local privateUrl, publicUrl, publicUrl2 	= publishSettings.photoServer:getSharedAlbumUrls(publishSettings, sharedAlbumParams.sharedAlbumName)
	local sharedAlbumPrefs = myPrefs.sharedAlbums[sharedAlbumId]

	sharedAlbumPrefs.privateUrl = privateUrl
	sharedAlbumPrefs.publicUrl  = publicUrl
	sharedAlbumPrefs.publicUrl2 = publicUrl2
	
	-- do self-assignment to force Lr to store the prefs
	myPrefs.sharedAlbums[sharedAlbumId] = myPrefs.sharedAlbums[sharedAlbumId]
	myPrefs.sharedAlbums = myPrefs.sharedAlbums
    writeLogfile(3, string.format("PSSharedAlbumMgmt.setSharedAlbumUrls('%s'): added '%s', '%s', '%s' to myPrefs[%d].\n",
								sharedAlbumParams.sharedAlbumName, privateUrl, publicUrl, publicUrl2, sharedAlbumId))
end

--------------------------------------------------------------------------------------------
-- getPublishServiceSharedAlbums(pubServiceName)
--   returns a list of all Shared Album for a Publish Service, i.e. derived from keywords below "Photo StatLr"|"Shared Albums"
function PSSharedAlbumMgmt.getPublishServiceSharedAlbums(pubServiceName)
	local sharedAlbumParamsList					= {}
	local pubService 							= PSLrUtilities.getPublishServiceByName(pubServiceName)
	local pubServiceSettings 					= pubService and pubService:getPublishSettings()
	local pubServiceSharedAlbumPath 			= PSSharedAlbumMgmt.getSharedAlbumKeywordPath(pubServiceName, nil)
	local _, pubServiceSharedAlbumRootKeyword	= PSLrUtilities.getKeywordByPath(pubServiceSharedAlbumPath)

	if not pubServiceSharedAlbumRootKeyword then return sharedAlbumParamsList end

	local pubServiceKeywords = pubServiceSharedAlbumRootKeyword:getChildren()
	for i = 1, #pubServiceKeywords do
		local keyword = pubServiceKeywords[i]
		sharedAlbumParamsList[i] = PSSharedAlbumMgmt.loadSharedAlbumParams(keyword, pubServiceSettings)
	end
	writeLogfile(3, string.format("getPublishServiceSharedAlbums(%s): found Shared Albums: '%s'\n",
									pubServiceName, table.concat(getTableExtract(sharedAlbumParamsList, 'sharedAlbumName'), ',')))
	return sharedAlbumParamsList

end

--------------------------------------------------------------------------------------------
-- getPhotoSharedAlbums(srcPhoto, pubServiceName)
--   returns a list of all Shared Album params for a photo in within the scope of a given Publish Service
function PSSharedAlbumMgmt.getPhotoSharedAlbums(srcPhoto, pubServiceName)
	local photoKeywords 			= srcPhoto:getRawMetadata("keywords")
	local sharedAlbumParamsList 	= {}
	local numSharedAlbumKeywords 	= 0
	local pubService 				= PSLrUtilities.getPublishServiceByName(pubServiceName)
	local pubServiceSettings 		= pubService and pubService:getPublishSettings()
	local pubServiceSharedAlbumPath 			= PSSharedAlbumMgmt.getSharedAlbumKeywordPath(pubServiceName, nil)
	local _, pubServiceSharedAlbumRootKeyword	= PSLrUtilities.getKeywordByPath(pubServiceSharedAlbumPath)

	for i = 1, #photoKeywords do
		local keyword = photoKeywords[i]

		if	keyword:getParent() and keyword:getParent() == pubServiceSharedAlbumRootKeyword then
    		numSharedAlbumKeywords = numSharedAlbumKeywords + 1
			sharedAlbumParamsList[numSharedAlbumKeywords] = PSSharedAlbumMgmt.loadSharedAlbumParams(keyword, pubServiceSettings)
		end
	end
	writeLogfile(3, string.format("getPhotoSharedAlbums(%s, %s): found Shared Albums: '%s'\n",
									srcPhoto:getFormattedMetadata('fileName'), pubServiceName, table.concat(getTableExtract(sharedAlbumParamsList, 'sharedAlbumName'), ',')))
	return sharedAlbumParamsList

end

--------------------------------------------------------------------------------------------
-- getPhotoPluginMetaLinkedSharedAlbums(srcPhoto)
--   returns a list of all Shared Album the photo was linked to as stored in private plugin metadata
function PSSharedAlbumMgmt.getPhotoPluginMetaLinkedSharedAlbums(srcPhoto)
	local sharedAlbumPluginMetadata = srcPhoto:getPropertyForPlugin(_PLUGIN, 'sharedAlbums', nil, true)
	local sharedAlbumsPS

	-- format of plugin metadata: <collectionId>:<sharedAlbumName>/{<collectionId>:<sharedAlbumName>}
	if ifnil(sharedAlbumPluginMetadata, '') ~= '' then
		sharedAlbumsPS = split(sharedAlbumPluginMetadata, '/')
	end
	writeLogfile(3, string.format("getPhotoPluginMetaLinkedSharedAlbums(%s): Shared Albums plugin metadata: '%s'\n",
									srcPhoto:getRawMetadata('path'), ifnil(sharedAlbumPluginMetadata, '')))
	return sharedAlbumsPS
end

--------------------------------------------------------------------------------------------
-- setPhotoPluginMetaLinkedSharedAlbums(srcPhoto, sharedAlbums)
--   store a list of '/'-separated Shared Albums the photo was linked to into private plugin metadata 'sharedAlbums'
--   each sharedAlbum is coded as <publishedCollectionId>:<sharedAlbumName>
function PSSharedAlbumMgmt.setPhotoPluginMetaLinkedSharedAlbums(srcPhoto, sharedAlbums)
	local activeCatalog 				= LrApplication.activeCatalog()
	local oldSharedAlbumPluginMetadata 	= srcPhoto:getPropertyForPlugin(_PLUGIN, 'sharedAlbums', nil, true)
	table.sort(sharedAlbums)
	local newSharedAlbumPluginMetadata 	= table.concat(sharedAlbums, '/')

	if newSharedAlbumPluginMetadata ~= oldSharedAlbumPluginMetadata then
		activeCatalog:withWriteAccessDo(
				'Update Plugin Metadata for Shared Albums',
				function(context)
					srcPhoto:setPropertyForPlugin(_PLUGIN, 'sharedAlbums', iif(#newSharedAlbumPluginMetadata == 0, nil, newSharedAlbumPluginMetadata))
				end,
				{timeout=5}
		)
		writeLogfile(3, string.format("setPhotoPluginMetaLinkedSharedAlbums(%s): updated Shared Albums plugin metadata to '%s'\n",
									srcPhoto:getRawMetadata('path'), newSharedAlbumPluginMetadata))
		return 1
	end

	return 0
end

--------------------------------------------------------------------------------------------
-- removePhotoPluginMetaLinkedSharedAlbumForCollection(srcPhoto, collectionId)
--   remove all Shared Albums of a given collection from private plugin metadata 'sharedAlbums'
function PSSharedAlbumMgmt.removePhotoPluginMetaLinkedSharedAlbumForCollection(srcPhoto, collectionId)
	local sharedAlbums 			= PSSharedAlbumMgmt.getPhotoPluginMetaLinkedSharedAlbums(srcPhoto)
	local sharedAlbumsRemoved	= false

	writeLogfile(4, string.format("removePhotoPluginMetaLinkedSharedAlbumForCollection(%s, {%s}): removing all Shared Albums for colletion '%d'\n",
									srcPhoto:getRawMetadata('path'), table.concat(ifnil(sharedAlbums, {}), ","), collectionId))

	if sharedAlbums then
    	for i = #sharedAlbums, 1, -1 do
    		if string.match(sharedAlbums[i], tostring(collectionId) .. ':.*') then
    			table.remove(sharedAlbums, i)
    			sharedAlbumsRemoved = true
    		end
    	end

    	if sharedAlbumsRemoved then
    		return PSSharedAlbumMgmt.setPhotoPluginMetaLinkedSharedAlbums(srcPhoto, sharedAlbums)
    	end
	end
	return 0
end

-------------------------------------------------------------------------------
-- PSSharedAlbumMgmt.readSharedAlbumsFromLr()
function PSSharedAlbumMgmt.readSharedAlbumsFromLr()
	local activeCatalog 		 = LrApplication.activeCatalog()
	local publishServices 		 = activeCatalog:getPublishServices(_PLUGIN.id)
	local publishServiceNames 	 = {}
	local publishServiceVersions = {}
    local sharedAlbumDefaults
	local nAlbums = 0

	local sharedAlbums = {}

	local k = 0

    for i = 1, #publishServices	do
    	local publishService 		 = publishServices[i]
    	local publishServiceSettings = publishService:getPublishSettings()

		if PHOTOSERVER_API.supports (publishServiceSettings.psVersion, PHOTOSERVER_SHAREDALBUM) then
            sharedAlbumDefaults = PHOTOSERVER_API[publishServiceSettings.psVersion].API.sharedAlbumDefaults
			writeLogfile(3, string.format("readSharedAlbumsFromLr: publish service '%s': psVersion: %d\n", publishService:getName(), publishServiceSettings.psVersion))
			k = k + 1
			publishServiceNames[k] 		= publishService:getName()
			publishServiceVersions[publishServiceNames[k]] = publishServiceSettings.psVersion

			local pubServiceSharedAlbums = PSSharedAlbumMgmt.getPublishServiceSharedAlbums(publishServiceNames[k])

			if pubServiceSharedAlbums then
				for j = 1, #pubServiceSharedAlbums do
					nAlbums = nAlbums + 1
					sharedAlbums[nAlbums] = {}
					local sharedAlbum = sharedAlbums[nAlbums]

					sharedAlbum.isEntry				= true
					sharedAlbum.wasAdded			= false
					sharedAlbum.wasModified			= false
					sharedAlbum.wasDeleted	 		= false

                    -- copy only SharedAlbum params mentioned in sharedAlbumDefaults
                    for key, defaultValue in pairs(sharedAlbumDefaults) do
						sharedAlbum[key] = ifnil(pubServiceSharedAlbums[j][key], defaultValue)
					end
					sharedAlbum.sharedAlbumName 	= pubServiceSharedAlbums[j].sharedAlbumName
					sharedAlbum.publishServiceName 	= publishService:getName()
				end
			end
		end
	end

	return publishServiceNames, publishServiceVersions, sharedAlbums
end

-------------------------------------------------------------------------------
-- PSSharedAlbumMgmt.writeSharedAlbumsToLr(sharedAlbumParamsList)
function PSSharedAlbumMgmt.writeSharedAlbumsToLr(sharedAlbumParamsList)
    local includeOnExport = true
	
	for i = 1, #sharedAlbumParamsList do
        local sharedAlbum = sharedAlbumParamsList[i]

		if sharedAlbum.isEntry then
            local sharedAlbumKeyword
            local sharedAlbumKeywordPath 				= PSSharedAlbumMgmt.getSharedAlbumKeywordPath(sharedAlbum.publishServiceName, sharedAlbum.sharedAlbumName)
            sharedAlbum.keywordId, sharedAlbumKeyword	= PSLrUtilities.getKeywordByPath(sharedAlbumKeywordPath, not sharedAlbum.wasDeleted, includeOnExport)
    
            -- only keys mentioned in sharedAlbumDefaults have to be stored in plugin prefs
            -- so, copy only those keys from sharedAlbum to sharedAlbumParams
            local sharedAlbumParams = {}
            for key, defaultValue in pairs(PSSharedAlbumMgmt.sharedAlbumDefaults) do
                ---@diagnostic disable-next-line: need-check-nil
                sharedAlbumParams[key] = sharedAlbum[key]
            end

            -- if album was deleted: remove SharedAlbum metadata from all associated photos
    		if sharedAlbum.wasDeleted and not sharedAlbum.wasAdded then
    			writeLogfile(2, string.format("PSSharedAlbumMgmt.writeSharedAlbumsToLr: PubServ %s, ShAlbum: %s: deleting Album\n",
    								sharedAlbum.publishServiceName, sharedAlbum.sharedAlbumName))

                -- remove shared album plugin metadata from all belonging photos
    			local srcPhotos = PSLrUtilities.getKeywordPhotos(sharedAlbum.keywordId)
    			for j = 1, #srcPhotos do
                    ---@diagnostic disable-next-line: need-check-nil
    				local srcPhoto = srcPhotos[j]
    				local sharedAlbums = PSSharedAlbumMgmt.getPhotoPluginMetaLinkedSharedAlbums(srcPhoto)
        			if sharedAlbums then
        				local numOldSharedAlbumsPS = #sharedAlbums

        				for k = #sharedAlbums, 1, -1 do
        					if string.match(sharedAlbums[k],  '%d+:(.+)')  == sharedAlbum.sharedAlbumName then
    							writeLogfile(2, string.format("PSSharedAlbumMgmt.writeSharedAlbumsToLr: srcPhoto %s, removing Shared Album '%s' from Plugin Metadata\n",
    								srcPhoto:getFormattedMetadata('fileName'), sharedAlbums[k]))
        						table.remove(sharedAlbums, k);
        					end
        				end
        				-- if number of shared albums has changed: update src photo plugin metadata
        				if #sharedAlbums ~= numOldSharedAlbumsPS then
        					PSSharedAlbumMgmt.setPhotoPluginMetaLinkedSharedAlbums(srcPhoto, sharedAlbums)
        				end
        			end

    				-- remove shared album keyword from photo
        			PSLrUtilities.removePhotoKeyword(srcPhoto, sharedAlbum.keywordId)

    			end

    			-- delete album from Lr keyword hierarchy (currently not supported by Lr)
    			PSLrUtilities.deleteKeyword(sharedAlbum.keywordId, sharedAlbumKeywordPath)
				LrDialogs.message("Remove Keyword!",
									LOC("$$$/PSUpload/SharedAlbumDialog/Info/RemoveSharedAlbumKeyword=Please remove keyword\n'^1'\n after the Shared Album was deleted!", sharedAlbumKeywordPath),
									'info')

                PSSharedAlbumMgmt.removeSharedAlbumParams(sharedAlbumKeyword)
    		end

    		if sharedAlbum.wasAdded and not sharedAlbum.wasDeleted then
    			writeLogfile(2, string.format("PSSharedAlbumMgmt.writeSharedAlbumsToLr: PubServ %s, ShAlbum: %s: adding Album\n",
    								sharedAlbum.publishServiceName, sharedAlbum.sharedAlbumName))

    			local keywordAttributes = sharedAlbumKeyword and sharedAlbumKeyword:getAttributes()
	   			writeTableLogfile(2, "PSSharedAlbumMgmt.writeSharedAlbumsToLr: keywordAttributes", keywordAttributes, true)
    		end

    		if (sharedAlbum.wasAdded or sharedAlbum.wasModified) and not sharedAlbum.wasDeleted then
    			writeLogfile(2, string.format("PSSharedAlbumMgmt.writeSharedAlbumsToLr: PubServ: '%s', ShAlbum: '%s': storing modified params\n",
    								sharedAlbum.publishServiceName, sharedAlbum.sharedAlbumName))

                PSSharedAlbumMgmt.storeSharedAlbumParams(sharedAlbumKeyword, sharedAlbumParams)
    		end
    	end
	end
end

-------------------------------------------------------------------------------
-- PSSharedAlbumMgmt.writeSharedAlbumsToPS(sharedAlbumParamsList)
-- update all modified/added/deleted Photo Server Shared Albums
function PSSharedAlbumMgmt.writeSharedAlbumsToPS(sharedAlbumParamsList)
	local numDeletes, numAddOrMods, numRenames = 0, 0, 0
	local numFailDeletes, numFailAddOrMods, numFailRenames = 0, 0, 0
	
    -- cache for publish settings
    local activePublishing = {
			publishServiceName	= nil,
			publishSettings		= nil,
		}

	-- TODO: sort shared albums by publishService
	for i = 1, #sharedAlbumParamsList do
		local sharedAlbum 		= sharedAlbumParamsList[i]
		local publishService 	= PSLrUtilities.getPublishServiceByName(sharedAlbum.publishServiceName)
		local publishSettings

		if 	 sharedAlbum.isEntry and
			(sharedAlbum.wasAdded or sharedAlbum.wasDeleted or sharedAlbum.wasModified) then

    		-- open session only if publish service if different from last album or session not yet opened
			if 		activePublishing.publishServiceName ~= sharedAlbum.publishServiceName
				or 	not	activePublishing.publishSettings
				or 	not	activePublishing.publishSettings.photoServer then
    	    	-- open session: initialize environment, get missing params and login
				publishSettings					= publishService and publishService:getPublishSettings()
            	local sessionSuccess, reason	= openSession(publishSettings, nil, 'ManageSharedAlbums')
            	if not sessionSuccess then
            		if reason ~= 'cancel' then
            			showFinalMessage("Photo StatLr: Update Photo Server SharedAlbums failed!", reason, "critical")
            		end
            		closeLogfile()
            		writeLogfile(3, "PSSharedAlbumMgmt.writeSharedAlbumsToPS(): nothing to do\n")
            		return
            	end
            	activePublishing.publishServiceName = sharedAlbum.publishServiceName
            	activePublishing.publishSettings = publishSettings
            else
            	publishSettings = activePublishing.publishSettings
			end
		end

        if sharedAlbum.wasDeleted then
			if  not sharedAlbum.wasAdded then
    			-- delete Shared Album in Photo Server
    			writeLogfile(3, string.format('writeSharedAlbumsToPS: deleting %s.\n', sharedAlbum.sharedAlbumName))
                ---@diagnostic disable-next-line: need-check-nil
    			if publishSettings.photoServer:deleteSharedAlbum(sharedAlbum.sharedAlbumName) then
    				numDeletes = numDeletes + 1
    			else
    				numFailDeletes = numFailDeletes + 1
    			end
			end
		elseif sharedAlbum.wasAdded or sharedAlbum.wasModified then
			---@diagnostic disable-next-line: need-check-nil
			sharedAlbum.isAdvanced = iif(publishSettings.photoServer:supports(PHOTOSERVER_SHAREDALBUM_ADVANCED), true, false)
			-- add/modify Shared Album in Photo Server
			---@diagnostic disable-next-line: need-check-nil
			local sharedAlbumInfo, errorCode = publishSettings.photoServer:createSharedAlbum(sharedAlbum)
			if sharedAlbumInfo then
				writeLogfile(2, string.format('writeSharedAlbumsToPS(%s): add/modify returns OK.\n', sharedAlbum.sharedAlbumName))
				numAddOrMods = numAddOrMods + 1
	   			PSSharedAlbumMgmt.setSharedAlbumUrls(sharedAlbum.publishServiceName, sharedAlbum, publishSettings)
			else
				writeLogfile(1, string.format('writeSharedAlbumsToPS(%s) add/modify returns error %s.\n', sharedAlbum.sharedAlbumName, tostring(errorCode)))
				numFailAddOrMods = numFailAddOrMods + 1
			end
		end
	end

	local message = LOC ("$$$/PSUpload/FinalMsg/UpdatePSSharedAlbums=Update Shared Albums: Add/Modify: ^1 OK / ^2 Fail, Rename: ^3 OK / ^4 Fail, Delete: ^5 OK / ^6 Fail\n",
					numAddOrMods, numFailAddOrMods, numRenames, numFailRenames, numDeletes, numFailDeletes)
	local messageType = iif(numFailAddOrMods > 0 or numFailRenames > 0 or numFailDeletes > 0, 'critical', 'info')
	showFinalMessage ("Photo StatLr: Update Shared Albums done", message, messageType)
end

--------------------------------------------------------------------------------------------
-- noteSharedAlbumUpdates(sharedAlbumUpdates, sharedPhotoUpdates, srcPhoto, publishedPhotoId, publishedCollectionId, exportParams, publishServiceName)
-- 	  sharedAlbumUpdates holds the list of required Shared Album updates (adds and removes)
-- 	  sharedPhotoUpdates holds the list of required plugin metadata updates
function PSSharedAlbumMgmt.noteSharedAlbumUpdates(sharedAlbumUpdates, sharedPhotoUpdates, srcPhoto, publishedPhotoId, publishedCollectionId, exportParams, publishServiceName)
	local pubServiceName = LrApplication.activeCatalog():getPublishedCollectionByLocalIdentifier(publishedCollectionId):getService():getName()
	local sharedAlbumsLr 	= PSSharedAlbumMgmt.getPhotoSharedAlbums(srcPhoto, pubServiceName)
	local oldSharedAlbumsPS	= ifnil(PSSharedAlbumMgmt.getPhotoPluginMetaLinkedSharedAlbums(srcPhoto), {})
	local newSharedAlbumsPS	= tableShallowCopy(oldSharedAlbumsPS)

	-- add photo to all given Shared Albums that it is not already member of
	for i = 1, #sharedAlbumsLr do
		local sharedAlbumName		= sharedAlbumsLr[i].sharedAlbumName
		local photoSharedAlbum 		= publishedCollectionId .. ':' .. sharedAlbumName

		if 		not findInStringTable(newSharedAlbumsPS, photoSharedAlbum)
			or	not exportParams.photoServer:getPhotoInfoFromList('sharedAlbum', sharedAlbumName, publishedPhotoId, srcPhoto:getRawMetadata('isVideo'), true)
		then
    		local sharedAlbumUpdate = nil

    		for k = 1, #sharedAlbumUpdates do
    			if sharedAlbumUpdates[k].sharedAlbumName == sharedAlbumName then
    				sharedAlbumUpdate = sharedAlbumUpdates[k]
    				break
    			end
    		end
    		if not sharedAlbumUpdate then
    			writeLogfile(3, string.format("noteSharedAlbumUpdates(%s): note Shared Album '%s'/'%s' as entry %d due to addPhoto\n", publishedPhotoId, publishServiceName, sharedAlbumName, #sharedAlbumUpdates + 1))
    			sharedAlbumUpdate = {
					publishServiceName		= publishServiceName,
    				sharedAlbumName			= sharedAlbumName,
    				addPhotos 				= {},
    				removePhotos 			= {},
    			}
	   			sharedAlbumUpdates[#sharedAlbumUpdates + 1] = sharedAlbumUpdate
    		end

			if not sharedAlbumUpdate.sharedAlbumParams then
				sharedAlbumUpdate.sharedAlbumParams = {}
				for key, value in pairs(sharedAlbumsLr[i]) do
					sharedAlbumUpdate.sharedAlbumParams[key] = value
				end
			end

    		local addPhotos = sharedAlbumUpdate.addPhotos
    		addPhotos[#addPhotos+1] = { dstFilename = publishedPhotoId, isVideo = srcPhoto:getRawMetadata('isVideo') }
   			writeLogfile(3, string.format("noteSharedAlbumUpdates(%s): note in entry '%s'/'%s' --> addPhotos[%d]\n", publishedPhotoId, publishServiceName, sharedAlbumName, #addPhotos))

   			if not findInStringTable(newSharedAlbumsPS, photoSharedAlbum) then
   				table.insert(newSharedAlbumsPS, photoSharedAlbum)
   			end
		end
	end

	-- remove photo from all Shared Albums that it is not member of
	for i = 1, #oldSharedAlbumsPS do
		local collId, sharedAlbumName = string.match(oldSharedAlbumsPS[i], '(%d+):(.*)')
		local sharedAlbumUpdate = nil

		if collId == tostring(publishedCollectionId) and not findInAttrValueTable(sharedAlbumsLr, 'sharedAlbumName', sharedAlbumName, 'sharedAlbumName') then
    		for k = 1, #sharedAlbumUpdates do
    			if sharedAlbumUpdates[k].sharedAlbumName == sharedAlbumName then
    				sharedAlbumUpdate = sharedAlbumUpdates[k]
    				break
    			end
    		end

    		if not sharedAlbumUpdate then
    			writeLogfile(3, string.format("noteSharedAlbumUpdates(%s): note Shared Album '%s'/'%s' as entry %d due to removePhoto\n", publishedPhotoId, publishServiceName, sharedAlbumName, #sharedAlbumUpdates + 1))
    			sharedAlbumUpdate = {
					publishServiceName		= publishServiceName,
    				sharedAlbumName			= sharedAlbumName,
    				addPhotos 				= {},
    				removePhotos 			= {},
    			}

    			sharedAlbumUpdates[#sharedAlbumUpdates + 1] = sharedAlbumUpdate
    		end
    		local removePhotos = sharedAlbumUpdate.removePhotos
    		removePhotos[#removePhotos+1] = { dstFilename = publishedPhotoId, isVideo = srcPhoto:getRawMetadata('isVideo') }
   			writeLogfile(3, string.format("noteSharedAlbumUpdates(%s): note in entry '%s' --> removePhotos[%d]\n", publishedPhotoId, sharedAlbumName, #removePhotos))

    		local removeId = findInStringTable(newSharedAlbumsPS, oldSharedAlbumsPS[i])
    		table.remove(newSharedAlbumsPS, removeId)
 		end
	end

	if table.concat(oldSharedAlbumsPS, '/') ~= table.concat(newSharedAlbumsPS, '/') then
		writeLogfile(3, string.format("noteSharedAlbumUpdates(%s): adding modified plugin metadata '%s' to sharedPhotoUpdates\n", publishedPhotoId, table.concat(newSharedAlbumsPS, '/')))
		local sharedPhotoUpdate = { srcPhoto = srcPhoto, sharedAlbums = newSharedAlbumsPS }
		table.insert(sharedPhotoUpdates, sharedPhotoUpdate)
	end

	return true
end

-----------------
-- updateSharedAlbums(functionContext, sharedAlbumUpdates, sharedPhotoUpdates, exportParams)
-- update Shared Albums for photos/videos just uploaded
-- 	  sharedAlbumUpdates contains the list of required Shared Album updates (adds and removes)
-- 	  sharedPhotoUpdates contains the list of required plugin metadata updates
function PSSharedAlbumMgmt.updateSharedAlbums(functionContext, sharedAlbumUpdates, sharedPhotoUpdates, exportParams)
	local catalog = LrApplication.activeCatalog()
	local nUpdateItems =  #sharedAlbumUpdates + #sharedPhotoUpdates
	local nProcessed 		= 0

	writeLogfile(3, string.format("updateSharedAlbums: updating %d shared album and %d photo metadata\n", #sharedAlbumUpdates, #sharedPhotoUpdates))
	local progressScope = LrProgressScope(
								{ 	title = LOC( "$$$/PSUpload/Progress/UpdateSharedAlbums=Updating ^1 shared albums with ^2 photos",  #sharedAlbumUpdates,  #sharedPhotoUpdates),
							 		functionContext = functionContext
							 	})
	for i = 1, #sharedAlbumUpdates do
		if progressScope:isCanceled() then break end
		local sharedAlbumUpdate  = sharedAlbumUpdates[i]
		local publishServiceName = sharedAlbumUpdate.publishServiceName
		local sharedAlbumParams  = sharedAlbumUpdate.sharedAlbumParams

		progressScope:setCaption(sharedAlbumUpdate.sharedAlbumName)

		if #sharedAlbumUpdate.addPhotos > 0 then
            local sharedAlbumInfo, errorCode = exportParams.photoServer:createAndAddPhotosToSharedAlbum(sharedAlbumParams, sharedAlbumUpdate.addPhotos)
			if sharedAlbumInfo then
				PSSharedAlbumMgmt.setSharedAlbumUrls(publishServiceName, sharedAlbumParams, exportParams)
			else
				writeLogfile(1, string.format('Shared Album "%s": could not set Shared Album URLs (%s).\n',sharedAlbumUpdate.sharedAlbumName, exportParams.photoServer:getErrorMsg(errorCode)))
			end
		end

		if #sharedAlbumUpdate.removePhotos > 0 then exportParams.photoServer:removePhotosFromSharedAlbum(sharedAlbumUpdate.sharedAlbumName, sharedAlbumUpdate.removePhotos) end
		writeLogfile(2, string.format('Shared Album "%s": added %d photos, removed %d photos.\n',
										sharedAlbumUpdate.sharedAlbumName, #sharedAlbumUpdate.addPhotos, #sharedAlbumUpdate.removePhotos))
		nProcessed = nProcessed + 1
   		progressScope:setPortionComplete(nProcessed, nUpdateItems)
	end

	for i = 1, #sharedPhotoUpdates do
		if progressScope:isCanceled() then break end
		local sharedPhotoUpdate = sharedPhotoUpdates[i]

		progressScope:setCaption(LrPathUtils.leafName(sharedPhotoUpdate.srcPhoto:getRawMetadata("path")))

		PSSharedAlbumMgmt.setPhotoPluginMetaLinkedSharedAlbums(sharedPhotoUpdate.srcPhoto, sharedPhotoUpdate.sharedAlbums)
		writeLogfile(3, string.format("%s: updated plugin metadata.\n",	sharedPhotoUpdate.srcPhoto:getRawMetadata('path')))
   		nProcessed = nProcessed + 1
   		progressScope:setPortionComplete(nProcessed, nUpdateItems)
	end

	progressScope:done()

	return true
end

---------------------------------------------------------------------------------------------------
-- getColorLabelsFromPublishService(functionContext, publishServiceName, arrayOfPhotoInfo)
local function getColorLabelsFromPublishService(functionContext, publishServiceName, arrayOfPhotoInfo)
	local publishService = PSLrUtilities.getPublishServiceByName(publishServiceName)
	local publishSettings = publishService and publishService:getPublishSettings()
	local nPhotos =  #arrayOfPhotoInfo
	local nProcessed 	= 0
	local nColorLabels	= 0

	if not publishSettings then
		writeLogfile(2, string.format("Get color labels: Cannot get publishSettings (should not happen)!\n"))
		closeLogfile()
		return
	end

	-- make sure logfile is opened
	openLogfile(publishSettings.logLevel)

	if nPhotos == 0 then
		writeLogfile(2, string.format("Get color labels: nothing to do.\n"))
		closeLogfile()
		return
	end

	-- TODO: check which infos should be downloaded
	publishSettings.downloadMode 		= 'Yes'
	publishSettings.pubColorDownload 	= publishSettings.photoServer:supports(PHOTOSERVER_METADATA_COMMENT_PUB)
	publishSettings.commentsDownload	= publishSettings.photoServer:supports(PHOTOSERVER_METADATA_LABEL_PUB)

	-- open session: initialize environment, get missing params and login
	local sessionSuccess, reason = openSession(publishSettings, nil, 'GetColorLabelsFromPublishService')
	if not sessionSuccess then
		if reason ~= 'cancel' then
			showFinalMessage("Photo StatLr: Get color labels failed!", reason, "critical")
		else
			writeLogfile(2, string.format("Get color labels: canceled by user\n"))
		end
		closeLogfile()
		return
	end

	writeLogfile(2, string.format("Get color labels for %d photos in Publish Service '%s'.\n", nPhotos, publishServiceName))

	local startTime = LrDate.currentTime()

	local progressScope = LrProgressScope(
								{ 	title = LOC( "$$$/PSUpload/Progress/GetColorLabelsFromPublishService=Downloading color labels for ^1 photos in Publish Service ^[^2^]", nPhotos, publishServiceName),
							 		functionContext = functionContext
							 	})

	local serviceSharedAlbumComments = {}

	-- get all Shared Albums belonging to this service
	local pubServiceSharedAlbums = PSSharedAlbumMgmt.getPublishServiceSharedAlbums(publishServiceName)

	for i, photoInfo in ipairs( arrayOfPhotoInfo ) do
		if progressScope:isCanceled() then break end

		local srcPhoto = photoInfo.photo
		progressScope:setCaption(LrPathUtils.leafName(srcPhoto:getFormattedMetadata("fileName")))

		-- get photo comments from PS public shared albums, if photo is member of any shared album
		local photoSharedAlbums = PSSharedAlbumMgmt.getPhotoPluginMetaLinkedSharedAlbums(srcPhoto)
		if photoSharedAlbums then

   			writeLogfile(4, string.format("Get color labels: %s - found %d Shared Albums\n", photoInfo.remoteId, #photoSharedAlbums))
			for j = 1, #photoSharedAlbums do
				-- download color label from this shared album only if the shared album is public
				local sharedAlbumName = string.match(photoSharedAlbums[j], '%d+:(.+)')
				local psSharedPhotoId 		= publishSettings.photoServer:getPhotoId(photoInfo.remoteId, srcPhoto:getRawMetadata('isVideo'))

				if publishSettings.photoServer:isSharedAlbumPublic(sharedAlbumName)
				then
					local psPubColorLabel = publishSettings.photoServer:getPublicSharedPhotoColorLabel(sharedAlbumName, photoInfo.remoteId, srcPhoto:getRawMetadata('isVideo'))
					local colorLabelPS = ifnil(publishSettings.photoServer.colorMapping[tonumber(psPubColorLabel)], 'none')
					local colorLabelLr = srcPhoto:getRawMetadata('colorNameForLabel')
		   			writeLogfile(3, string.format("Get color labels: %s - found color label '%s'(%s) in Shared Album '%s', Lr color is '%s'\n",
	   							photoInfo.remoteId, colorLabelPS, psPubColorLabel, sharedAlbumName, colorLabelLr))
					if colorLabelLr ~= iif(colorLabelPS == 'none', 'grey', colorLabelPS) then
		   				nColorLabels = nColorLabels + 1
						LrApplication.activeCatalog():withWriteAccessDo(
							'ChangeColorLabel',
                    		function(context)
                    			srcPhoto:setRawMetadata('colorNameForLabel', colorLabelPS)
                      		end,
                    		{timeout=5}
                    	)
                    end
				end
			end
		end

   		nProcessed = nProcessed + 1
   		progressScope:setPortionComplete(nProcessed, nPhotos)
	end
	progressScope:done()

	local timeUsed 	= LrDate.currentTime() - startTime
	local picPerSec = nProcessed / timeUsed
	local message = LOC ("$$$/PSUpload/FinalMsg/GetColorLabelsFromPublishService=Got ^1 color labels for ^2 of ^3 pics in ^4 seconds (^5 pics/sec).",
					nColorLabels, nProcessed, nPhotos, string.format("%.1f", timeUsed + 0.5), string.format("%.1f", picPerSec))

	showFinalMessage("Photo StatLr: Get color labels done", message, "info")
	return true
end

---------------------------------------------------------------------------------------------------
-- downloadColorLabels(functionContext, downloadSharedAlbums)
-- download color labels for given grouped list of Shared Albums
function PSSharedAlbumMgmt.downloadColorLabels(functionContext, downloadSharedAlbums)
	local downloadSharedPhotos = {}

	writeLogfile(3, string.format("downloadColorLabels: starting: %d Publish Services\n", #downloadSharedAlbums))

	local colorLabelDownloadProgressScope = LrProgressScope(
								{ 	title 			= LOC( "$$$/PSUpload/Progress/ColorLabelsRetrievePublishService=Retrieving public shared photos from ^1 Publish Services",  #downloadSharedAlbums),
							 		functionContext = functionContext,
							 	})

	writeLogfile(3, string.format("downloadColorLabels: going to loop\n"))

	for h = 1, #downloadSharedAlbums do
		local downloadSharedAlbum = downloadSharedAlbums[h]
		writeLogfile(3, string.format("downloadColorLabels: %d. Publish Service\n", h))
		writeLogfile(3, string.format("downloadColorLabels: Publish Service '%s' --> %d Shared Albums\n", downloadSharedAlbum.publishServiceName, #(downloadSharedAlbum.sharedAlbums)))

		if colorLabelDownloadProgressScope:isCanceled() then break end
		colorLabelDownloadProgressScope:setCaption(downloadSharedAlbum.publishServiceName)

		downloadSharedPhotos[h] = {
			publishServiceName 	= downloadSharedAlbum.publishServiceName,
			photoInfos				= {},
		}

		local publishedCollections = PSLrUtilities.getPublishedCollections(PSLrUtilities.getPublishServiceByName(downloadSharedAlbum.publishServiceName))
		if publishedCollections and #publishedCollections > 0 then

        	local colorLabelCollectionDownloadProgressScope = LrProgressScope(
        								{ 	title 			= LOC( "$$$/PSUpload/Progress/ColorLabelsRetrievePublishedCollection=Retrieving public shared photos from ^1 Published Collections",  #publishedCollections),
--        									parent			= colorLabelDownloadProgressScope,
        							 		functionContext = functionContext,
        							 	})

			for i = 1, #publishedCollections do
				local publishedCollection = publishedCollections[i]
				local publishedPhotos = publishedCollection:getPublishedPhotos()

        		if colorLabelCollectionDownloadProgressScope:isCanceled() then break end
        		colorLabelCollectionDownloadProgressScope:setCaption(publishedCollection:getName())

				for j = 1, #publishedPhotos do
					local pubPhoto = publishedPhotos[j]
					local photo = pubPhoto:getPhoto()
					local photoKeywords = photo:getRawMetadata('keywords')
					if photoKeywords then
						for k = 1, #photoKeywords do
							for l = 1, #(downloadSharedAlbum.sharedAlbums) do
								if photoKeywords[k].localIdentifier == downloadSharedAlbum.sharedAlbums[l].keywordId then
									local photoInfo = {
										publishedPhoto	= pubPhoto,
										photo			= pubPhoto:getPhoto(),
										remoteId		= pubPhoto:getRemoteId(),
										url				= pubPhoto:getRemoteUrl(),
										commentCount	= 0
									}
									table.insert(downloadSharedPhotos[h].photoInfos, photoInfo)
									break
								end
							end
						end
					end
				end
				colorLabelCollectionDownloadProgressScope:setPortionComplete(i, #publishedCollections)
			end
			colorLabelCollectionDownloadProgressScope:done()
		end
		colorLabelDownloadProgressScope:setPortionComplete(h, #downloadSharedAlbums)

	end
	colorLabelDownloadProgressScope:done()



	for i = 1, #downloadSharedPhotos do
		writeLogfile(3, string.format("downloadColorLabels: Publish Service '%s' --> %d photos\n", downloadSharedPhotos[i].publishServiceName, #(downloadSharedPhotos[i].photoInfos)))
		getColorLabelsFromPublishService(functionContext, downloadSharedPhotos[i].publishServiceName, downloadSharedPhotos[i].photoInfos)
	end
end
