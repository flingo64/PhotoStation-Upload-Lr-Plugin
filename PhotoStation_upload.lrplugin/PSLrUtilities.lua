--[[----------------------------------------------------------------------------

PSLrUtilities.lua
Lightroom utilities:
	- getCollectionPath
	- getCollectionUploadPath
	- evaluateAlbumPath

Copyright(c) 2016, Martin Messmer

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

]]
--------------------------------------------------------------------------------

-- Lightroom API
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
-- local LrHttp = import 'LrHttp'
local LrDate = import 'LrDate'

--====== local functions =====================================================--

--====== global functions ====================================================--

PSLrUtilities = {}

---------------------- isVideo() ----------------------------------------------------------
--
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
-- tries various methods to get the info including Lr metadata, exiftool (if enabled), file infos
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

-- function getPublishPath(srcPhoto, renderedExtension, exportParams, dstRoot) 
-- 	return relative local path of the srcPhoto and destination path of the rendered photo: remotePath = dstRoot + (localpath - srcRoot), 
--	returns:
-- 		localPath - relative local path as unix-path
-- 		remotePath - absolute remote path as unix-path
function PSLrUtilities.getPublishPath(srcPhoto, renderedExtension, exportParams, dstRoot)
	local srcPhotoPath = srcPhoto:getRawMetadata('path')
	local srcPhotoExtension = LrPathUtils.extension(srcPhotoPath)
	local localRenderedPath
	local localPath
	local remotePath

	-- if is virtual copy: add last three characters of photoId as suffix to filename
	if srcPhoto:getRawMetadata('isVirtualCopy') then
		srcPhotoPath = LrPathUtils.addExtension(LrPathUtils.removeExtension(srcPhotoPath) .. '-' .. string.sub(srcPhoto:getRawMetadata('uuid'), -3), 
												srcPhotoExtension)
		writeLogfile(3, 'isVirtualCopy: new srcPhotoPath is: ' .. srcPhotoPath .. '"\n')				
	end

	-- check if extension of rendered photo is different from original photo
	if not srcPhoto:getRawMetadata("isVideo") and exportParams.RAWandJPG and (string.lower(srcPhotoExtension) ~= string.lower(renderedExtension)) then
		-- if original and rendered photo extensions are different, use rendered photo extension
		-- optionally append original extension to photoname (e.g. '_rw2.jpg')
		srcPhotoPath = LrPathUtils.addExtension(LrPathUtils.removeExtension(srcPhotoPath) .. '_' .. srcPhotoExtension, renderedExtension)
	end
	-- Source and rendered photo w/ same extension, pay attention to uppe/lowercase setting of 				
	srcPhotoPath = LrPathUtils.replaceExtension(srcPhotoPath, renderedExtension)
		
	localRenderedPath = srcPhotoPath
			
	if exportParams.copyTree then
		localPath = 		string.gsub(LrPathUtils.makeRelative(srcPhotoPath, exportParams.srcRoot), "\\", "/")
		localRenderedPath = string.gsub(LrPathUtils.makeRelative(localRenderedPath, exportParams.srcRoot), "\\", "/")
	else
		localPath = 		LrPathUtils.leafName(srcPhotoPath)
		localRenderedPath = LrPathUtils.leafName(localRenderedPath)
	end
	remotePath = iif(dstRoot ~= '', dstRoot .. '/' .. localRenderedPath, localRenderedPath)
	writeLogfile(3, string.format("getPublishPath(%s, %s,%s %s)\n    returns %s %s\n", 
					srcPhoto:getRawMetadata('path'), renderedExtension, iif(exportParams.copyTree, 'Tree', 'Flat'), dstRoot,
					localPath, remotePath))
	return localPath, remotePath
end
-----------------

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
	
	return collectionPath
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
		collectionPath 	= collectionSettings.dstRoot
	else
		local collectionSetSettings = publishedCollection:getCollectionSetInfoSummary().collectionSettings
		collectionPath 	= collectionSetSettings.baseDir
	end
	
	parentCollectionSet  = publishedCollection:getParent()
	while parentCollectionSet do
		local parentSettings = parentCollectionSet:getCollectionSetInfoSummary().collectionSettings
		if parentSettings and ifnil(normalizeDirname(parentSettings.baseDir), '') ~= '' then
			collectionPath = normalizeDirname(parentSettings.baseDir) .. "/" .. collectionPath	
		end
		parentCollectionSet  = parentCollectionSet:getParent()
	end
	writeLogfile(4, "getCollectionUploadPath() returns " .. ifnil(collectionPath, '<Nil>') .. "\n")
	
	return collectionPath
end

---------------------- album path evaluation routines --------------------------------------------------

-- isDynamicAlbumPath(path)
-- 	return true if album path contains metadata placeholders 

function PSLrUtilities.isDynamicAlbumPath(path)
	if (path and string.find(path, "{", 1, true)) then
		return true
	end
	return false	
end

-- evaluateAlbumPath(path, srcPhoto)
--[[
-- 	Substitute metadata placeholders by actual values from the photo and sanitize a given directory path.
	Metadata placeholders look in general like: {<category>:<type> <options>|<defaultValue_or_mandatory>}
	'?' stands for mandatory, no default available. 
	- unrecognized placeholders will be left unchanged, they might be intended path components
	- undefined mandatory metadata will be substituted by ?
	- undefined optional metadata will be substituted by their default or '' if no default
]]  

function PSLrUtilities.evaluateAlbumPath(path, srcPhoto)

	if (not path or not string.find(path, "{", 1, true)) then
		return normalizeDirname(path)
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
				
				writeLogfile(3, string.format("evaluateAlbumPath: date format %s --> %s\n", ifnil(dateFormat, '<Nil>'), ifnil(dateString, '<Nil>'))) 
				return iif(ifnil(dateString, '') ~= '',  dateString, ifnil(dataDefault, '')) 
			end);
	end
	
	-- get formatted metadata, if required
	if string.find(path, "{LrFM:", 1, true) then
		local srcPhotoFMetadata = srcPhoto:getFormattedMetadata()

    	-- substitute Lr Formatted Metadata tokens: {LrFM:<metadataName>}, only string, number or boolean type allowed
    	path = string.gsub (path, '({LrFM:[^}]*})', function(metadataParam)
    			local metadataName, dataDefault = string.match(metadataParam, "{LrFM:(.*)|(.*)}")
    			if not metadataName then
    				metadataName = string.match(metadataParam, "{LrFM:(.*)}")
    			end
    			local metadataString = iif(ifnil(srcPhotoFMetadata[metadataName], '') ~= '', srcPhotoFMetadata[metadataName], ifnil(dataDefault, ''))
    			if metadataString ~= '?' then metadataString = mkLegalFilename(metadataString) end
    			writeLogfile(3, string.format("evaluateAlbumPath: key %s --> %s \n", ifnil(metadataName, '<Nil>'), metadataString)) 
    			return metadataString
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
				local dataType, dataFilter, dataDefault = string.match(contCollParam, '{LrCC:(%w+)%s*(.*)|(.*)}')
				if not dataType then
					dataType, dataFilter = string.match(contCollParam, '{LrCC:(%w+)%s*(.*)}')
				end
				if not dataType then
					dataType = string.match(contCollParam, '{LrCC:(%w+)}')
				end

-- 				writeLogfile(4, string.format("evaluateAlbumPath: %s: type %s filter %s\n", ifnil(contCollParam, '<Nil>'), ifnil(dataType, '<Nil>'), ifnil(dataFilter, '<Nil>'))) 
				
				if not dataType or not string.find('name,path', dataType, 1, true) then 
					writeLogfile(3, string.format("evaluateAlbumPath:  %s: type %s not valid  --> %s \n", ifnil(contCollParam, '<Nil>'), ifnil(dataType, '<Nil>'), contCollParam)) 
					return contCollParam 
				end
				
				if not containedCollectionPath or not containedCollectionPath[1] then
					writeLogfile(4, string.format("evaluateAlbumPath:  %s: no collections  --> '' \n", ifnil(contCollParam, '<Nil>'))) 
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
						writeLogfile(3, string.format("evaluateAlbumPath: %s  --> %s \n", ifnil(contCollParam, '<Nil>'), ifnil(dataString, ''))) 
						return ifnil(dataString, '')
					end 
				end
				writeLogfile(3, string.format("evaluateAlbumPath:  %s: no match  --> '' \n", ifnil(contCollParam, '<Nil>'))) 
				return ifnil(dataDefault,'')  
			end);
	end
	
	return normalizeDirname(path)
end 


