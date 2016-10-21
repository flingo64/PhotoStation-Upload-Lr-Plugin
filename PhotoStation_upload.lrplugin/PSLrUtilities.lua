--[[----------------------------------------------------------------------------

PSLrUtilities.lua
Lightroom utilities:
	- isVideo
	- isRAW
	
	- getDateTimeOriginal
	
	- getPublishPath
	- getCollectionPath
	- getCollectionUploadPath
	
	- isDynamicAlbumPath
	- evaluatePathOrFilename

	- noteAlbumForCheckEmpty
	
	- getKeywordObjects
	- addKeywordHierarchyToCatalogAndPhoto
	- renameKeyword
	
	- getSharedAlbumKeywords
	
	- convertCollection
	- convertAllPhotos
	
Copyright(c) 2016, Martin Messmer

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

]]
--------------------------------------------------------------------------------

-- Lightroom API
local LrApplication 	= import 'LrApplication'
local LrDate 			= import 'LrDate'
local LrDialogs 		= import 'LrDialogs'
local LrFileUtils 		= import 'LrFileUtils'
local LrPathUtils 		= import 'LrPathUtils'
local LrProgressScope 	= import 'LrProgressScope'

--====== local functions =====================================================--

--====== global functions ====================================================--

PSLrUtilities = {}

---------------------- isRAW() ----------------------------------------------------------
-- isRAW(filename)
-- returns true if filename extension is one of the Lr supported RAW photo formats  
function PSLrUtilities.isRAW(filename)
	return iif(string.find('3fr,arw,cr2,dng,dcr,erf,mef,mrw,nef,orf,pef,raf,raw,rw2,srw,x3f', 
							string.lower(LrPathUtils.extension(filename)), 1, true), 
				true, false)
end

---------------------- isVideo() ----------------------------------------------------------
-- isVideo(filename)
-- returns true if filename extension is one of the Lr supported video extensions  
function PSLrUtilities.isVideo(filename)
	return iif(string.find('3gp,3gpp,avchd,avi,m2t,m2ts,m4v,mov,mp4,mpe,mpg,mts', 
							string.lower(LrPathUtils.extension(filename)), 1, true), 
				true, false)
end

------------- getDateTimeOriginal -------------------------------------------------------------------
-- getDateTimeOriginal(srcPhoto)
-- get the DateTimeOriginal (capture date) of a photo or whatever comes close to it
-- tries various methods to get the info including Lr metadata, file infos
-- returns a unix timestamp and a boolean indicating if we found a real DateTimeOrig
function PSLrUtilities.getDateTimeOriginal(srcPhoto)
	local srcDateTime = nil
	local isOrigDateTime = false

	if srcPhoto:getRawMetadata("dateTimeOriginal") then
		srcDateTime = srcPhoto:getRawMetadata("dateTimeOriginal")
		isOrigDateTime = true
		writeLogfile(3, "  dateTimeOriginal: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
	elseif srcPhoto:getRawMetadata("dateTimeOriginalISO8601") then
		srcDateTime = srcPhoto:getRawMetadata("dateTimeOriginalISO8601")
		isOrigDateTime = true
		writeLogfile(3, "  dateTimeOriginalISO8601: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
	elseif srcPhoto:getRawMetadata("dateTimeDigitized") then
		srcDateTime = srcPhoto:getRawMetadata("dateTimeDigitized")
		writeLogfile(3, "  dateTimeDigitized: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
	elseif srcPhoto:getRawMetadata("dateTimeDigitizedISO8601") then
		srcDateTime = srcPhoto:getRawMetadata("dateTimeDigitizedISO8601")
		writeLogfile(3, "  dateTimeDigitizedISO8601: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
	elseif srcPhoto:getFormattedMetadata("dateCreated") and srcPhoto:getFormattedMetadata("dateCreated") ~= '' then
		local srcDateTimeStr = srcPhoto:getFormattedMetadata("dateCreated")
		local year,month,day,hour,minute,second,tzone
		local foundDate = false -- avoid empty dateCreated
		
		-- iptcDateCreated: date is mandatory, time as whole, seconds and timezone may or may not be present
		for year,month,day,hour,minute,second,tzone in string.gmatch(srcDateTimeStr, "(%d+)-(%d+)-(%d+)T*(%d*):*(%d*):*(%d*)Z*(%w*)") do
			writeLogfile(4, string.format("dateCreated: %s Year: %s Month: %s Day: %s Hour: %s Minute: %s Second: %s Zone: %s\n",
											srcDateTimeStr, year, month, day, ifnil(hour, "00"), ifnil(minute, "00"), ifnil(second, "00"), ifnil(tzone, "local")))
			srcDateTime = LrDate.timeFromComponents(tonumber(year), tonumber(month), tonumber(day),
													tonumber(ifnil(hour, "0")),
													tonumber(ifnil(minute, "0")),
													tonumber(ifnil(second, "0")),
													iif(not tzone or tzone == "", "local", tzone))
			foundDate = true
		end
		if foundDate then writeLogfile(3, "  dateCreated: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n") end
	end
	
	-- if nothing found in metadata of srcPhoto: take the fileCreationDate
	if not srcDateTime then
		local srcFilename = ifnil(srcPhoto:getRawMetadata("path"), "")
		local fileAttr = LrFileUtils.fileAttributes(srcFilename)

		if fileAttr["fileCreationDate"] then
			srcDateTime = fileAttr["fileCreationDate"]
			writeLogfile(3, "  fileCreationDate: " .. LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false ) .. "\n")
		else
			srcDateTime = LrDate.currentTime()
			writeLogfile(3, string.format("  no date found for %s, using current date: %s\n",
										 srcFilename, LrDate.timeToUserFormat(srcDateTime, "%Y-%m-%d %H:%M:%S", false)))
		end
	end
	return LrDate.timeToPosixDate(srcDateTime), isOrigDateTime
end

---------------------- Get Publish Path --------------------------------------------------
-- function getPublishPath(srcPhoto, dstFilename, exportParams, dstRoot) 
-- 	return relative local path of the srcPhoto and destination path of the rendered photo: remotePath = dstRoot + (localpath - srcRoot), 
--	returns:
-- 		localRelativePath 	- relative local path as unix-path
-- 		remoteAbsPath 		- absolute remote path as unix-path
function PSLrUtilities.getPublishPath(srcPhoto, dstFilename, exportParams, dstRoot)
	local srcPhotoPath 			= srcPhoto:getRawMetadata('path')
	local srcPhotoDir 			= LrPathUtils.parent(srcPhotoPath)
	local srcPhotoExtension 	= LrPathUtils.extension(srcPhotoPath)
	
	local localRenderedPath 	= LrPathUtils.child(srcPhotoDir, dstFilename)
	local renderedExtension 	= LrPathUtils.extension(dstFilename)
	
	local localRelativePath
	local remoteAbsPath

	-- if is virtual copy: add copyName as suffix to filename (to make the filename unique)
	if srcPhoto:getRawMetadata('isVirtualCopy') then
		localRenderedPath = LrPathUtils.addExtension(LrPathUtils.removeExtension(localRenderedPath) .. '-' .. srcPhoto:getFormattedMetadata('copyName'), 
												renderedExtension)
		writeLogfile(3, 'isVirtualCopy: new localRenderedPath is: ' .. localRenderedPath .. '"\n')				
	end

	-- if original and rendered photo extensions are different and 'RAW+JPG to same album' is set, ...
	if not srcPhoto:getRawMetadata("isVideo") and exportParams.RAWandJPG and (string.lower(srcPhotoExtension) ~= string.lower(renderedExtension)) then
		-- then append original extension to photoname (e.g. '_rw2.jpg')
		localRenderedPath = LrPathUtils.addExtension(
								LrPathUtils.removeExtension(localRenderedPath) .. '_' .. srcPhotoExtension, renderedExtension)
		writeLogfile(3, 'different extentions and RAW+JPG set: new localRenderedPath is: ' .. localRenderedPath .. '"\n')				
	end

	if exportParams.copyTree then
		localRelativePath =	string.gsub(LrPathUtils.makeRelative(localRenderedPath, exportParams.srcRoot), "\\", "/")
	else
		localRelativePath =	LrPathUtils.leafName(localRenderedPath)
	end
	remoteAbsPath = iif(dstRoot ~= '', dstRoot .. '/' .. localRelativePath, localRelativePath)
	writeLogfile(3, string.format("getPublishPath('%s', %s, %s, '%s')\n    returns '%s', '%s'\n", 
					srcPhoto:getRawMetadata('path'), renderedExtension, iif(exportParams.copyTree, 'Tree', 'Flat'), dstRoot,
					localRelativePath, remoteAbsPath))
	return localRelativePath, remoteAbsPath
end

---------------------- getCollectionPath --------------------------------------------------
-- getCollectionPath(collection)
-- 	return collection hierarchy path of a (Published) Collection by recursively traversing the collection and all of its parents
--  returns a path like: <CollectionSetName>/<CollectionSetName>/.../>CollectionName>
function PSLrUtilities.getCollectionPath(collection)
	local parentCollectionSet
	local collectionPath
	
	if not collection then return '' end
	
	-- Build the directory path by recursively traversing the parent collection sets and prepend each directory
	collectionPath	= collection:getName()
	parentCollectionSet  = collection:getParent()
	while parentCollectionSet do
		collectionPath = mkLegalFilename(parentCollectionSet:getName()) .. "/" .. collectionPath	
		parentCollectionSet  = parentCollectionSet:getParent()
	end
	writeLogfile(4, "getCollectionPath() returns " .. collectionPath .. "\n")
	
	return normalizeDirname(collectionPath)
end


---------------------- getCollectionUploadPath --------------------------------------------------
-- getCollectionUploadPath(publishedCollection)
-- 	return the target album path path of a PSUpload Published Collection by recursively traversing the collection and all of its parents
function PSLrUtilities.getCollectionUploadPath(publishedCollection)
	local parentCollectionSet
	local collectionPath
	
	-- Build the directory path by recursively traversing the parent collection sets and prepend each directory
	if publishedCollection:type() == 'LrPublishedCollection' then
		local collectionSettings = publishedCollection:getCollectionInfoSummary().collectionSettings
		collectionPath 	= ifnil(collectionSettings.dstRoot, '')
	else
		local collectionSetSettings = publishedCollection:getCollectionSetInfoSummary().collectionSettings
		collectionPath 	= ifnil(collectionSetSettings.baseDir, '')
	end
	
	parentCollectionSet  = publishedCollection:getParent()
	while parentCollectionSet do
		local parentSettings = parentCollectionSet:getCollectionSetInfoSummary().collectionSettings
		if parentSettings and ifnil(normalizeDirname(parentSettings.baseDir), '') ~= '' then
			collectionPath = normalizeDirname(parentSettings.baseDir) .. "/" .. collectionPath	
		end
		parentCollectionSet  = parentCollectionSet:getParent()
	end
	writeLogfile(4, "getCollectionUploadPath() returns '" .. collectionPath .. "'\n")
	
	return normalizeDirname(collectionPath)
end

---------------------- isDynamicAlbumPath --------------------------------------------------
-- isDynamicAlbumPath(path)
-- 	return true if album path contains metadata placeholders 
function PSLrUtilities.isDynamicAlbumPath(path)
	if (path and string.find(path, "{", 1, true)) then
		return true
	end
	return false	
end

--------------------------------------------------------------------------------------------
-- evaluatePathOrFilename(path, srcPhoto, type)
-- 	Substitute metadata placeholders by actual values from the photo and sanitize a given directory path.
--	Metadata placeholders look in general like: {<category>:<type> <options>|<defaultValue_or_mandatory>}
--	'?' stands for mandatory, no default available. 
--	- unrecognized placeholders will be left unchanged, they might be intended path components
--	- undefined mandatory metadata will be substituted by ?
--	- undefined optional metadata will be substituted by their default or '' if no default
function PSLrUtilities.evaluatePathOrFilename(path, srcPhoto, type)

	if (not path or not string.find(path, "{", 1, true)) then
		return normalizeDirname(path)
	end

	if 	type == 'filename' 
	and (string.find(path, "/", 1, true) or string.find(path, "\\", 1, true)) then
		writeLogfile(3, string.format("evaluatePathOrFilename: filenane %s must not contain / or \\ \n", path)) 
		return '?'
	end

	-- get capture date, if required
	if string.find(path, "{Date", 1, true) then
		local srcPhotoDate = LrDate.timeFromPosixDate(PSLrUtilities.getDateTimeOriginal(srcPhoto))
		
		-- substitute date tokens: {Date <formatString>}
		path = string.gsub (path, '({Date[^}]*})', function(dateParams)
				local dateFormat, dataDefault = string.match(dateParams, "{Date%s*(.*)|(.*)}")
				if not dateFormat then
					dateFormat = string.match(dateParams, "{Date%s(.*)}")
				end
				local dateString = LrDate.timeToUserFormat(ifnil(srcPhotoDate, 0), dateFormat, false)
				
				writeLogfile(3, string.format("evaluatePathOrFilename: date format %s --> %s\n", ifnil(dateFormat, '<Nil>'), ifnil(dateString, '<Nil>'))) 
				return iif(ifnil(dateString, '') ~= '',  dateString, ifnil(dataDefault, '')) 
			end);
	end
	
	-- get formatted metadata, if required
	if string.find(path, "{LrFM:", 1, true) then
		local srcPhotoFMetadata = srcPhoto:getFormattedMetadata()

    	-- substitute Lr Formatted Metadata tokens: {LrFM:<key>} or {LrFM:<key> <extract pattern>}, only string, number or boolean type allowed
    	path = string.gsub (path, '({LrFM:[^}]*})', function(metadataParam)
    			local metadataNameAndPattern, dataDefault = string.match(metadataParam, "{LrFM:(.*)|(.*)}")
    			if not metadataNameAndPattern then
    				metadataNameAndPattern = string.match(metadataParam, "{LrFM:(.*)}")
    			end
    			local metadataName, metadataPattern = string.match(metadataNameAndPattern, "(%w+)%s+(.*)")
    			if not metadataName then
    				metadataName = metadataNameAndPattern
    			end
    			
    			local metadataString = ifnil(srcPhotoFMetadata[metadataName], '')
    			local metadataStringExtracted = metadataString
    			if metadataString == '' then
    				metadataStringExtracted = ifnil(dataDefault, '')
    			else
    				if metadataPattern then
    					metadataStringExtracted = string.match(metadataString, metadataPattern)
    				end 
					if not metadataStringExtracted then 
  						metadataStringExtracted = ifnil(dataDefault, '')
    				else
    					metadataStringExtracted = mkLegalFilename(metadataStringExtracted)
    				end 
    			end
    			writeLogfile(3, string.format("evaluatePathOrFilename: LrFM:%s = %s, pattern %s --> %s\n", ifnil(metadataName, '<Nil>'), ifnil(metadataString, '<Nil>'), ifnil(metadataPattern, '<Nil>'), metadataStringExtracted)) 
    			return metadataStringExtracted
    		end);
	end
	
	-- get pathname, if required
	if string.find(path, "{Path:", 1, true) then
		local srcPhotoPath = srcPhoto:getRawMetadata('path')

    	-- substitute Pathname tokens: {Path:<level>} or {Path:<key> <extract pattern>}to the (extract of the) <level>st subdir name of the path 
    	path = string.gsub (path, '({Path:[^}]*})', function(pathParam)
    			local pathLevelAndPattern, dataDefault = string.match(pathParam, "{Path:(.*)|(.*)}")
    			if not pathLevelAndPattern then
    				pathLevelAndPattern = string.match(pathParam, "{Path:(.*)}")
    			end
    			local pathLevel, pathPattern = string.match(pathLevelAndPattern, "(%d+)%s+(.*)")
    			if not pathLevel then
    				pathLevel = pathLevelAndPattern
    			end
    			pathLevel = tonumber(pathLevel)
    			
    			local pathDirnames = split(normalizeDirname(srcPhotoPath), '/')
    			local pathLevelString = iif(pathDirnames and pathLevel < #pathDirnames and ifnil(pathDirnames[pathLevel], '') ~= '', pathDirnames[pathLevel], '')
    			local pathLevelExtracted = pathLevelString
    			if pathLevelString == '' then 
    				pathLevelExtracted = ifnil(dataDefault, '')
    			else
    				if pathPattern then
    					pathLevelExtracted = string.match(pathLevelString, pathPattern)
    				end 
  					if not pathLevelExtracted then 
  						pathLevelExtracted = ifnil(dataDefault, '')
    				else
    					pathLevelExtracted = mkLegalFilename(pathLevelExtracted)
    				end 
    			end
    			writeLogfile(3, string.format("evaluatePathOrFilename: {Path %d}('%s') = %s, pattern %s --> %s\n", pathLevel, srcPhotoPath, ifnil(pathLevelString, '<Nil>'), ifnil(pathPattern, '<Nil>'), pathLevelExtracted)) 
    			return pathLevelExtracted
    		end);
	end
	
	-- get contained collections, if required
	if string.find(path, "{LrCC:", 1, true) then
		local srcPhotoContainedCollection = srcPhoto:getContainedCollections()
		local containedCollectionPath = {}
		
		for i = 1, #srcPhotoContainedCollection do
			containedCollectionPath[i] = PSLrUtilities.getCollectionPath(srcPhotoContainedCollection[i])
		end
		
		-- substitute Lr contained collection name or path: {LrCC:<name>|<path> <filter>}
		path = string.gsub (path, '({LrCC:[^}]*})', function(contCollParam)
				local dataTypeAndFilter, dataDefault = string.match(contCollParam, '{LrCC:(.*)|(.*)}')
				if not dataTypeAndFilter then
					dataTypeAndFilter = string.match(contCollParam, '{LrCC:(.*)}')
				end
				local dataType, dataFilter = string.match(dataTypeAndFilter, '(%w+)%s+(.*)')
				if not dataType then
					dataType = dataTypeAndFilter
				end

 				writeLogfile(4, string.format("evaluatePathOrFilename: %s: type %s filter %s\n", ifnil(contCollParam, '<Nil>'), ifnil(dataType, '<Nil>'), ifnil(dataFilter, '<Nil>'))) 
				
				if not dataType or not string.find('name,path', dataType, 1, true) then 
					writeLogfile(3, string.format("evaluatePathOrFilename:  %s: type %s not valid  --> %s \n", ifnil(contCollParam, '<Nil>'), ifnil(dataType, '<Nil>'), contCollParam)) 
					return contCollParam 
				end
				
				if not containedCollectionPath or not containedCollectionPath[1] then
					writeLogfile(4, string.format("evaluatePathOrFilename:  %s: no collections  --> '' \n", ifnil(contCollParam, '<Nil>'))) 
					return ifnil(dataDefault,'')  
				end
				
				for i = 1, #containedCollectionPath do
					local dataString
					
					if dataType == 'name' then
						local parents, leaf = string.match(containedCollectionPath[i], "(.*)/([^\/]+)")
						if not parents then leaf = containedCollectionPath[i] end
						dataString = leaf
					else
						dataString = containedCollectionPath[i]
					end
				
					if not dataFilter or string.match(dataString, dataFilter) then
						writeLogfile(3, string.format("evaluatePathOrFilename: %s  --> %s \n", ifnil(contCollParam, '<Nil>'), ifnil(dataString, ''))) 
						return ifnil(dataString, '')
					end 
				end
				writeLogfile(3, string.format("evaluatePathOrFilename:  %s: no match  --> '' \n", ifnil(contCollParam, '<Nil>'))) 
				return ifnil(dataDefault,'')  
			end);
	end
	
	return normalizeDirname(path)
end 

--------------------------------------------------------------------------------------------
-- noteAlbumForCheckEmpty(photoPath)
-- Note the album of a photo in the albumCheckList
-- make sure, each album exists only once and the albumCheckList is sorted by pathname length desc (longest pathnames first)
function PSLrUtilities.noteAlbumForCheckEmpty(albumCheckList, photoPath)
	local albumPath, _ = string.match(photoPath , '(.+)\/([^\/]+)')
	if not albumPath then 
		-- photo in root
		writeLogfile(4, string.format("noteAlbumForCheckEmpty(%s): root will not be noted.\n", photoPath))
		return albumCheckList 	
	end
	
	local newAlbum = {}
	newAlbum.albumPath	= albumPath
	
	local previousAlbum, currentAlbum = nil, albumCheckList
	
	while currentAlbum do
		if string.find(currentAlbum.albumPath, albumPath, 1, true) == 1 then 
			writeLogfile(4, string.format("noteAlbumForCheckEmpty(%s): %s already in list\n", albumPath, currentAlbum.albumPath))
			return albumCheckList
		elseif string.len(currentAlbum.albumPath) <= string.len(albumPath) then
			newAlbum.next = currentAlbum
			if previousAlbum then
				previousAlbum.next = newAlbum
			else		 
				albumCheckList = newAlbum 
			end
			writeLogfile(4, string.format("noteAlbumForCheckEmpty(%s): insert before %s\n", albumPath, currentAlbum.albumPath))
			return albumCheckList
		else
			previousAlbum = currentAlbum
			currentAlbum = currentAlbum.next			
		end
	end
	
	newAlbum.next		= nil
	if not previousAlbum then 
		writeLogfile(4, string.format("noteAlbumForCheckEmpty(%s): insert as first in list\n", albumPath))
		albumCheckList 		= newAlbum
	else
		previousAlbum.next	= newAlbum
		writeLogfile(4, string.format("noteAlbumForCheckEmpty(%s): insert as last in list\n", albumPath))
	end
		
	return albumCheckList	
end

--------------------------------------------------------------------------------------------
-- addKeywordSynonyms(keywordId, synonyms)
-- adds a list of synonyms to a keyword
function PSLrUtilities.addKeywordSynonyms(keywordId, synonyms)
	local catalog = LrApplication.activeCatalog()
	local keywords = catalog:getKeywordsByLocalId( { keywordId } )
	
	if not keywords or not keywords[1] then
		return false
	end
	
	local keyword = keywords[1]
	local keywordSynonyms = keyword:getSynonyms()
	local foundNewSynonyms = false
	
	for i = 1, #synonyms do
		if not findInStringTable(keywordSynonyms, synonyms[i]) then
			table.insert(keywordSynonyms, synonyms[i])
			foundNewSynonyms = true 
		end
	end
	
	if foundNewSynonyms then
    	catalog:withWriteAccessDo( 
    		'AddShareUrl to SharedAlbumKeyword ',
    		function(context)
    			keyword:setAttributes({synonyms = keywordSynonyms})
    		end,
    		{timeout=5}
    	)
	end
	
	return true
end

--------------------------------------------------------------------------------------------
-- removeKeywordSynonyms(keywordId, synonyms)
-- remove a list of synonym patterns from a keyword
function PSLrUtilities.removeKeywordSynonyms(keywordId, synonyms)
	local catalog = LrApplication.activeCatalog()
	local keywords = catalog:getKeywordsByLocalId( { keywordId } )
	
	if not keywords or not keywords[1] then
		return false
	end
	
	local keyword = keywords[1]
	local keywordSynonyms = keyword:getSynonyms()
	local synonymsRemoved = false
	
	for i = 1, #keywordSynonyms do
		for j = 1, #synonyms do
    		if string.match(keywordSynonyms[i], synonyms[j]) then
    			table.remove(keywordSynonyms, i)
    			synonymsRemoved = true
    			break
    		end
		end
	end

	if synonymsRemoved then
    	catalog:withWriteAccessDo( 
    		'RemoveShareUrl from SharedAlbumKeyword ',
    		function(context)
    			keyword:setAttributes({synonyms = keywordSynonyms})
    		end,
    		{timeout=5}
    	)
	end 
	return true
end

--------------------------------------------------------------------------------------------
-- getKeywordObjects(srcPhoto, keywordNameTable)
-- returns the keyword objects belonging to the keywords in the keywordTable
-- will only return exportable leaf keywords (synonyms and parent keywords are not returned)
function PSLrUtilities.getKeywordObjects(srcPhoto, keywordNameTable)
	-- get all leaf keywords
	local keywords = srcPhoto:getRawMetadata("keywords")  
	local keywordsFound, nFound = {}, 0 	
	
	for i = 1, #keywords do
		local found = false 
		
		if keywords[i]:getAttributes().includeOnExport then
    		for j = 1, #keywordNameTable do
    			if keywords[i]:getName() == keywordNameTable[j] then
    				found = true
    				break
    			end
    		end
    		if found then
    			nFound = nFound + 1
    			keywordsFound[nFound] = keywords[i]  
    		end
		end
	end
					
	writeLogfile(3, string.format("getKeywordObjects(%s, '%s') returns %d leaf keyword object\n", 
									srcPhoto:getRawMetadata('path'), table.concat(keywordNameTable, ','), nFound))
	return keywordsFound
end

--------------------------------------------------------------------------------------------
-- addKeywordHierarchyToCatalogAndPhoto(keywordPath, srcPhoto)
-- create (if not existing) a keyword hierarchy and add it to a photo if given. 
-- keyword hierarchies look like: '{parentKeyword|}keyword
--  returns the created leaf keyword
function PSLrUtilities.addKeywordHierarchyToCatalogAndPhoto(keywordPath, srcPhoto)
	local catalog = LrApplication.activeCatalog()
	local keywordHierarchy = split(keywordPath, '|')
	local keyword, parentKeyword = nil, nil
	
	writeLogfile(3, string.format("addKeywordHierarchyToCatalogAndPhoto('%s')\n", table.concat(keywordHierarchy, '->')))
	
	for i = 1, #keywordHierarchy do
		writeLogfile(3, string.format("addKeywordHierarchyToCatalogAndPhoto('%s'): add '%s'\n", table.concat(keywordHierarchy, '->'), keywordHierarchy[i]))
		keyword = catalog:createKeyword(keywordHierarchy[i], {}, true, parentKeyword, true)
		parentKeyword = keyword
	end
	if srcPhoto then srcPhoto:addKeyword(keyword) end 

	return keyword
end

--------------------------------------------------------------------------------------------
-- renameKeyword(rootKeywords, keywordParent, oldKeywordName, newKeywordName)
function PSLrUtilities.renameKeyword(rootKeywords, keywordParent, oldKeywordName, newKeywordName)
	writeLogfile(3, string.format("renameKeyword('%s', '%s', '%s', '%s')\n", table.concat(ifnil(rootKeywords, {}), '|'), ifnil(keywordParent, ''), oldKeywordName, newKeywordName))
	local keywordHierarchy = split(keywordParent, '|')

	if not keywordHierarchy then
    	for i = 1, #rootKeywords do
    		if rootKeywords[i]:getName() == oldKeywordName then
				writeLogfile(3, string.format("renameKeyword() found'%', rename to '%s'\n", oldKeywordName, newKeywordName))
    			rootKeywords[i]:setAttributes({keywordName = newKeywordName})
    			return true
   			end
    	end
    	-- keyword not found
    	return false
	end
	
	-- keyword hierarchy is not empty
	for i = 1, #rootKeywords do
		if rootKeywords[i]:getName() == keywordHierarchy[1] then
			return PSLrUtilities.renameKeyword(rootKeywords[i]:getChildren(), table.concat(keywordHierarchy, '|', 2))	
		end	
	end
	
	return true
end

--------------------------------------------------------------------------------------------
-- getSharedAlbumKeywords(srcPhoto, pubServiceName)
--   returns a list of all Shared Album keywords. i.e. keywords below "Photo StatLr"|"Shared Albums"
function PSLrUtilities.getSharedAlbumKeywords(srcPhoto, pubServiceName)
	local keywords 					= srcPhoto:getRawMetadata("keywords")  
	local sharedAlbumKeywords 		= {} 	
	local numSharedAlbumKeywords 	= 0

	writeLogfile(3, string.format("getSharedAlbumKeywords(%s, %s) starting\n", 
									srcPhoto:getRawMetadata('path'), pubServiceName))
	for i = 1, #keywords do
		local keyword = keywords[i]
		
		if	keyword:getParent() and keyword:getParent():getName() == pubServiceName
		and keyword:getParent():getParent() and keyword:getParent():getParent():getName() == 'Shared Albums'
		and keyword:getParent():getParent():getParent() and keyword:getParent():getParent():getParent():getName() == 'Photo StatLr' then
    		numSharedAlbumKeywords = numSharedAlbumKeywords + 1
    		sharedAlbumKeywords[numSharedAlbumKeywords] = {
    				sharedAlbumName 	= keyword:getName(), 
    				mkSharedAlbumPublic	= iif(findInStringTable(keyword:getSynonyms(), 'private'), false, true),
    				keywordId			= keyword.localIdentifier,
    		}
		end
	end
	writeLogfile(3, string.format("getSharedAlbumKeywords(%s, %s): found Shared Albums: '%s'\n", 
									srcPhoto:getRawMetadata('path'), pubServiceName, table.concat(getTableExtract(sharedAlbumKeywords, 'sharedAlbumName'), ',')))
	return sharedAlbumKeywords   		

end

--------------------------------------------------------------------------------------------
-- getLinkedSharedAlbums(srcPhoto)
--   returns a list of all Shared Album the photo was linked to as stored in private plugin metadata
function PSLrUtilities.getLinkedSharedAlbums(srcPhoto)
	local sharedAlbumPluginMetadata = srcPhoto:getPropertyForPlugin(_PLUGIN, 'sharedAlbums', nil, true)
	local sharedAlbumsPS

	-- format of plugin metadata: <collectionId>:<sharedAlbumName>/{<collectionId>:<sharedAlbumName>}
	if ifnil(sharedAlbumPluginMetadata, '') ~= '' then
		sharedAlbumsPS = split(sharedAlbumPluginMetadata, '/')
	end
	writeLogfile(3, string.format("getLinkedSharedAlbums(%s): found Shared Albums: '%s'\n", 
									srcPhoto:getRawMetadata('path'), ifnil(sharedAlbumPluginMetadata, '')))    		
	return sharedAlbumsPS
end 

--------------------------------------------------------------------------------------------
-- setLinkedSharedAlbums(srcPhoto, sharedAlbums)
--   store a list of all Shared Album the photo was linked to in private plugin metadata
function PSLrUtilities.setLinkedSharedAlbums(srcPhoto, sharedAlbums)
	local activeCatalog 				= LrApplication.activeCatalog()
	local oldSharedAlbumPluginMetadata 	= srcPhoto:getPropertyForPlugin(_PLUGIN, 'sharedAlbums', nil, true)
	table.sort(sharedAlbums)
	local newSharedAlbumPluginMetadata 	= table.concat(sharedAlbums, '/')
	
	writeLogfile(3, string.format("setLinkedSharedAlbums(%s): '%s'\n", 
									srcPhoto:getRawMetadata('path'), ifnil(newSharedAlbumPluginMetadata, '')))    		
	if newSharedAlbumPluginMetadata ~= oldSharedAlbumPluginMetadata then
		activeCatalog:withWriteAccessDo( 
				'Update Plugin Metadata for Shared Albums',
				function(context)
					srcPhoto:setPropertyForPlugin(_PLUGIN, 'sharedAlbums', newSharedAlbumPluginMetadata)
				end,
				{timeout=5}
		)
		writeLogfile(3, string.format("setLinkedSharedAlbums(%s): updated plugin metadata to '%s'\n", 
									srcPhoto:getRawMetadata('path'), newSharedAlbumPluginMetadata))    		
		return 1
	end

	return 0
end 

--------------------------------------------------------------------------------------------
-- noteSharedAlbumUpdates(sharedAlbumUpdates, sharedPhotoUpdates, srcPhoto, publishedPhotoId, publishedCollectionId, exportParams)
-- 	  sharedAlbumUpdates holds the list of required Shared Album updates (adds and removes)
-- 	  sharedPhotoUpdates holds the list of required plugin metadata updates
-- 
--   returns a list of all Shared Album the photo was linked to via the given Published Collection as stored in plugin metadata
function PSLrUtilities.noteSharedAlbumUpdates(sharedAlbumUpdates, sharedPhotoUpdates, srcPhoto, publishedPhotoId, publishedCollectionId, exportParams)
	local pubServiceName = LrApplication.activeCatalog():getPublishedCollectionByLocalIdentifier(publishedCollectionId):getService():getName()
	local sharedAlbumsLr 	= PSLrUtilities.getSharedAlbumKeywords(srcPhoto, pubServiceName)
	local oldSharedAlbumsPS	= ifnil(PSLrUtilities.getLinkedSharedAlbums(srcPhoto), {})
	local newSharedAlbumsPS	= tableShallowCopy(oldSharedAlbumsPS)
	
	-- add photo to all given Shared Albums that it is not already member of
	for i = 1, #sharedAlbumsLr do
		local sharedAlbumName		= sharedAlbumsLr[i].sharedAlbumName
		local mkSharedAlbumPublic 	= sharedAlbumsLr[i].mkSharedAlbumPublic
		local keywordId				= sharedAlbumsLr[i].keywordId
		local photoSharedAlbum = publishedCollectionId .. ':' .. sharedAlbumName
		
		local sharedAlbumUpdate = nil
		
		for k = 1, #sharedAlbumUpdates do
			if sharedAlbumUpdates[k].sharedAlbumName == sharedAlbumName then
				sharedAlbumUpdate = sharedAlbumUpdates[k]
				break
			end
		end
		if not sharedAlbumUpdate then
			writeLogfile(3, string.format("noteSharedAlbumUpdates(%s): adding Shared Album %s as node %d for addPhoto\n", publishedPhotoId, sharedAlbumName, #sharedAlbumUpdates + 1))
			sharedAlbumUpdate = {sharedAlbumName = sharedAlbumName, mkSharedAlbumPublic = mkSharedAlbumPublic, keywordId = keywordId, addPhotos = {}, removePhotos = {} }
			sharedAlbumUpdates[#sharedAlbumUpdates + 1] = sharedAlbumUpdate
		end
		local addPhotos = sharedAlbumUpdate.addPhotos
		addPhotos[#addPhotos+1] = { dstFilename = publishedPhotoId, isVideo = srcPhoto:getRawMetadata('isVideo') }
		
		if not findInStringTable(newSharedAlbumsPS, photoSharedAlbum) then
			table.insert(newSharedAlbumsPS, photoSharedAlbum)
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
    			writeLogfile(3, string.format("noteSharedAlbumUpdates(%s): adding Shared Album %s as node %d for removePhoto\n", publishedPhotoId, sharedAlbumName, #sharedAlbumUpdates + 1))
    			sharedAlbumUpdate = {sharedAlbumName = sharedAlbumName, addPhotos = {}, removePhotos = {} }
    			sharedAlbumUpdates[#sharedAlbumUpdates + 1] = sharedAlbumUpdate
    		end
    		local removePhotos = sharedAlbumUpdate.removePhotos
    		removePhotos[#removePhotos+1] = { dstFilename = publishedPhotoId, isVideo = srcPhoto:getRawMetadata('isVideo') }
    		
    		local removeId = findInStringTable(newSharedAlbumsPS, oldSharedAlbumsPS[i])
    		table.remove(newSharedAlbumsPS, removeId)
 		end 
	end

	if table.concat(oldSharedAlbumsPS, '/') ~= table.concat(newSharedAlbumsPS, '/') then
		writeLogfile(3, string.format("noteSharedAlbumUpdates(%s): adding plugin metadata %s to sharedPhotoUpdates\n", publishedPhotoId, table.concat(newSharedAlbumsPS, '/')))
		local sharedPhotoUpdate = { srcPhoto = srcPhoto, sharedAlbums = newSharedAlbumsPS }
		table.insert(sharedPhotoUpdates, sharedPhotoUpdate)
	end
	
	return true 
end

--------------------------------------------------------------------------------------------
-- getAllPublishedCollectionsFromPublishedCollectionSet(publishedCollectionSet, allPublishedCollections)
local function getAllPublishedCollectionsFromPublishedCollectionSet(publishedCollectionSet, allPublishedCollections)
	local publishedCollections = publishedCollectionSet:getChildCollections()
	local childPublishedCollectionSets = publishedCollectionSet:getChildCollectionSets()
	writeLogfile(3, string.format("getAllPublishedCollectionsFromPublishedCollectionSet: set %s has %d collections and %d collection sets\n", 
									publishedCollectionSet:getName(), #publishedCollections, #childPublishedCollectionSets))
	
	for i = 1, #publishedCollections do
		local publishedCollection = publishedCollections[i]
		table.insert(allPublishedCollections, publishedCollection)
   		writeLogfile(3, string.format("getAllPublishedCollectionsFromPublishedCollection: published collection %s, total %d\n", publishedCollection:getName(), #allPublishedCollections))
	end
		
	for i = 1, #childPublishedCollectionSets do
		getAllPublishedCollectionsFromPublishedCollectionSet(childPublishedCollectionSets[i], allPublishedCollections)
	end
end

--------------------------------------------------------------------------------------------
-- convertCollection(functionContext, publishedCollection)
function PSLrUtilities.convertCollection(functionContext, publishedCollection)
	local activeCatalog 	= LrApplication.activeCatalog()
	local publishedPhotos 	= publishedCollection:getPublishedPhotos() 
	local nPhotos 			= #publishedPhotos
	local nConverted 		= 0
	local nProcessed 		= 0
	
	-- Set progress title.
	local progressScope = LrProgressScope( 
								{ 	
								 	title = LOC("$$$/PSUpload/Progress/ConvertCollection=Converting ^1 photos in collection '^2'", nPhotos, publishedCollection:getName()),
							 		functionContext = functionContext
							 	})    
					
	for i = 1, nPhotos do
		if progressScope:isCanceled() then break end
		
		local pubPhoto = publishedPhotos[i]

		-- check if backlink to the containing Published Collection must be adjusted
		if string.match(ifnil(pubPhoto:getRemoteUrl(), ''), '(%d+)') ~= tostring(publishedCollection.localIdentifier) then
   			nConverted = nConverted + 1
   			activeCatalog:withWriteAccessDo( 
    				'Update Backlink',
    				function(context)
						pubPhoto:setRemoteUrl(tostring(publishedCollection.localIdentifier) .. '/' .. tostring(LrDate.currentTime()))
    				end,
    				{timeout=5}
    			)
   			writeLogfile(2, "Convert(" .. publishedCollection:getName() .. " - " .. pubPhoto:getRemoteId() .. "): converted to new format.\n")
		else
			writeLogfile(2, string.format("Convert( %s - %s): already converted, lastEdited %s, lastPublished %s.\n", 
											publishedCollection:getName(), pubPhoto:getRemoteId(),
											LrDate.timeToUserFormat(pubPhoto:getPhoto():getRawMetadata('lastEditTime'), 			'%Y-%m-%d %H:%M:%S', false), 
											LrDate.timeToUserFormat(tonumber(string.match(pubPhoto:getRemoteUrl(), '%d+/(%d+)')), 	'%Y-%m-%d %H:%M:%S', false)
										))
		end
		nProcessed = i
		progressScope:setPortionComplete(nProcessed, nPhotos)
	end 
	progressScope:done()
	
	return nPhotos, nProcessed, nConverted
end

--------------------------------------------------------------------------------------------
-- printError()
-- Cleanup handler for a function context
function PSLrUtilities.printError(success, message)
    if not success then 
		writeLogfile(1, 	string.format("That does it, I'm leaving! Internal error: '%s'\n", ifnil(message, 'Unknown error')))
    end
end

--------------------------------------------------------------------------------------------
-- convertAllPhotos()
function PSLrUtilities.convertAllPhotos(functionContext)
	writeLogfile(2, string.format("ConvertAllPhotos: starting %s functionContext\n", iif(functionContext, 'with', 'without')))
	local activeCatalog = LrApplication.activeCatalog()
--	local publishedCollections = activeCatalog:getPublishedCollections()  -- doesn't work
	local publishServices = activeCatalog:getPublishServices(_PLUGIN.id)
	local allPublishedCollections = {}

	if functionContext then
		LrDialogs.attachErrorDialogToFunctionContext(functionContext)
		functionContext:addOperationTitleForError("Photo StatLr: That does it, I'm leaving!")
		functionContext:addCleanupHandler(PSLrUtilities.printError)
	end
	
	if not publishServices then
		writeLogfile(2, string.format("ConvertAllPhotos: No publish services found, done.\n"))
		return
	end
	
	writeLogfile(3, string.format("ConvertAllPhotos: found %d publish services\n", #publishServices))
	
	-- first: collect all published collection
    for i = 1, #publishServices	do
    	local publishService = publishServices[i]
    	local publishedCollections = publishService:getChildCollections()
    	local publishedCollectionSets = publishService:getChildCollectionSets()   	
    	
    	writeLogfile(3, string.format("ConvertAllPhotos: publish service %s has %d collections and %d collection sets\n", 
    									publishService:getName(), #publishedCollections, #publishedCollectionSets))
    	
    	-- note all immediate published collections
    	for j = 1, #publishedCollections do
    		local publishedCollection = publishedCollections[j]
    		
    		table.insert(allPublishedCollections, publishedCollection)
    		writeLogfile(3, string.format("ConvertAllPhotos: service %s -  published collection %s, total %d\n", publishService:getName(), publishedCollection:getName(), #allPublishedCollections))
    	end
    	
    	--  note all Published Collections from all Published Collection Sets
    	for j = 1, #publishedCollectionSets do
    		local publishedCollectionSet = publishedCollectionSets[j]
    		writeLogfile(2, string.format("ConvertAllPhotos: service %s -  published collection set %s\n", publishService:getName(), publishedCollectionSet:getName()))
    		getAllPublishedCollectionsFromPublishedCollectionSet(publishedCollectionSet, allPublishedCollections)
 		end   	
	end

   	writeLogfile(2, string.format("ConvertAllPhotos: Found %d published collections in %d publish service\n", #allPublishedCollections,  #publishServices))
	
	local startTime = LrDate.currentTime()

	-- now convert them
	local progressScope = LrProgressScope( 
								{ 	title = LOC("$$$/PSUpload/Progress/ConvertAll=Photo StatLr: Converting all ^1 collections", #allPublishedCollections),
							 		functionContext = functionContext 
							 	})    

	local nPhotosTotal, nProcessedTotal, nConvertedTotal = 0, 0, 0
	
	for i = 1, #allPublishedCollections do
		if progressScope:isCanceled() then break end
		
		local nPhotos, nProcessed, nConverted = PSLrUtilities.convertCollection(functionContext, allPublishedCollections[i])
	
		nPhotosTotal  	= nPhotosTotal 		+ nPhotos
		nProcessedTotal = nProcessedTotal 	+ nProcessed
		nConvertedTotal = nConvertedTotal 	+ nConverted
					
   		progressScope:setPortionComplete(i, #allPublishedCollections) 						    
	end 
	progressScope:done()	

	local timeUsed =  LrDate.currentTime() - startTime
	local picPerSec = nProcessedTotal / timeUsed

	local message = LOC ("$$$/PSUpload/FinalMsg/ConvertAll=Photo StatLr: Processed ^1 of ^2 photos in ^3 collections, ^4 converted in ^5 seconds (^6 pics/sec).", 
											nProcessedTotal, nPhotosTotal, #allPublishedCollections, nConvertedTotal, string.format("%.1f", timeUsed + 0.5), string.format("%.1f", picPerSec))
	showFinalMessage("Photo StatLr: Conversion done", message, "info")

end

--------------------------------------------------------------------------------------------
-- getDefaultCollectionSettings(publishServiceOrCollectiomSet)
function PSLrUtilities.getDefaultCollectionSettings(publishServiceOrCollectionSet)
	if not publishServiceOrCollectionSet then
		writeLogfile(1, string.format("getDefaultCollectionSettings: publishService is <nil>!\n"))
		return nil
	end
	
	local publishedCollections = publishServiceOrCollectionSet:getChildCollections()
	local publishedCollectionSets = publishServiceOrCollectionSet:getChildCollectionSets()   	
	writeLogfile(4, string.format("getDefaultCollectionSettings(%s): found %d collections and %d collection sets\n", publishServiceOrCollectionSet:getName(), #publishedCollections, #publishedCollectionSets))
	
	for i = 1, #publishedCollections do
		local publishedCollection = publishedCollections[i]
		if publishedCollection:getCollectionInfoSummary().isDefaultCollection then
			writeLogfile(3, string.format("getDefaultCollectionSettings(%s): Found Default Collection '%s'\n", publishServiceOrCollectionSet:getName(), publishedCollection:getName()))
			return publishedCollection:getName(), publishedCollection:getCollectionInfoSummary().collectionSettings
		else
			writeLogfile(4, string.format("getDefaultCollectionSettings(%s): Is not Default Collection is %s\n", publishServiceOrCollectionSet:getName(), publishedCollection:getName()))
		end
	end
	
	--  defaultCollection not yet found: traverse the Collection Sets recursively
	for i = 1, #publishedCollectionSets do
		local defCollectionName, defCollectionSettings = PSLrUtilities.getDefaultCollectionSettings(publishedCollectionSets[i])
		if defCollectionSettings then return defCollectionName, defCollectionSettings end
	end
	
	writeLogfile(4, string.format("getDefaultCollectionSettings(%s): Default Collection not found\n", publishServiceOrCollectionSet:getName()))
	return nil
end
