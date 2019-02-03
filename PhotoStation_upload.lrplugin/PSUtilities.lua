--[[----------------------------------------------------------------------------

PSUtilities.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2017, Martin Messmer

Utilities for Lightroom Photo StatLr

exported functions:
	- JSON.onDecodeError
	- JSON.onDecodeNilError
	- JSON.onDecodeHtmlError
	
	- ifnil
	- iif
	- split
	- trim
	
	- cmdlineQuote()
	- shellEscape
	
	- findInAttrValueTable
	- findInStringTable
	- getTableExtract
	- getTableDiff
		
	- getNullFilename
	- getProgExt
	
	- openLogfile
	- writeLogfile
	- writeTableLogfile
	- closeLogfile
	- getLogFilename
	- getLogLevel
	- changeLogLevel
		
	- waitSemaphore
	- signalSemaphore
	
	- mkLegalFilename
	- mkSafeFilename
	- normalizeDirname
	
	- urlencode
	
	- openSession
	- closeSession
	
	- promptForMissingSettings
	- showFinalMessage	
	
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
]]
--------------------------------------------------------------------------------

-- Lightroom API
local LrApplication 	= import 'LrApplication'
local LrDate 			= import 'LrDate'
local LrDialogs 		= import 'LrDialogs'
local LrFileUtils 		= import 'LrFileUtils'
local LrHttp	 		= import 'LrHttp'
local LrPathUtils 		= import 'LrPathUtils'
local LrPrefs	 		= import 'LrPrefs'
-- local LrProgressScope = import 'LrProgressScope'
local LrShell 			= import 'LrShell'
local LrTasks 			= import 'LrTasks'
local LrView 			= import 'LrView'

require "PSLrUtilities"

JSON = assert(loadfile (LrPathUtils.child(_PLUGIN.path, 'JSON.lua')))()

--============================================================================--

tmpdir = LrPathUtils.getStandardFilePath("temp")

----------------------- JSON helper --------------------------------------------------------------
-- Overwrite JSON.assert() to redirect output to logfile
--[[
JSON.assert = function (assert, message)
	writeLogfile(4, string.format("JSON-Assert: msg=%s\n",ifnil(message, '<Nil>')))
end
]]

-- overwriting of onDecodeError did not work (requires new JSON object ???)
--[[
]]
JSON.onDecodeError = function (message, text, location, etc) 
	writeLogfile(3, string.format("JSON-DecodeError: msg=%s, txt=%s\n", 
									ifnil(message, '<Nil>'), ifnil(text, '<Nil>')))
	writeLogfile(4, string.format("JSON-DecodeError: loc=%s, etc=%s\n", 
									ifnil(location, '<Nil>'),ifnil(etc, '<Nil>')))
end
JSON.onDecodeOfNilError  = JSON.onDecodeError
JSON.onDecodeOfHTMLError = JSON.onDecodeError

---------------------- useful helpers ----------------------------------------------------------

function ifnil(str, subst)
	return ((str == nil) and subst) or str
end 

function iif(condition, thenExpr, elseExpr)
	return (condition and thenExpr) or (not condition and elseExpr)
end 

--------------------------------------------------------------------------------------------
-- split(inputstr, sep)
-- splits a string into a table, sep must be a single character 
function split(inputstr, sep)
	if not inputstr then return nil end
	 
    if sep == nil then sep = "%s" end

    local t={} ; i=1
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            t[i] = str
            i = i + 1
    end
    return t
end

--------------------------------------------------------------------------------------------
-- trim(s)
-- trims leading and trailing white spaces from a string
function trim(s)
 	return (string.gsub(s,"^%s*(.-)%s*$", "%1"))
end

---------------------- shell encoding routines ---------------------------------------------------------

function cmdlineQuote()
	if WIN_ENV then
		return '"'
	elseif MAC_ENV then
		return ''
	else
		return ''
	end
end

function shellEscape(str)
	if WIN_ENV then
--		return(string.gsub(str, '>', '^>'))
		return(string.gsub(string.gsub(str, '%^ ', '^^ '), '>', '^>'))
	elseif MAC_ENV then
--		return("'" .. str .. "'")
		return(string.gsub(string.gsub(string.gsub(str, '>', '\\>'), '%(', '\\('), '%)', '\\)'))
	else
		return str
	end
end

---------------------- table operations ----------------------------------------------------------

-- tableShallowCopy (origTable)
-- make a shallow copy of a table
function tableShallowCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
--			writeLogfile(4, string.format("tableCopy: copying orig_key %s, orig_value %s\n", orig_key, tostring(orig_value)))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

--[[
-- tableDeepCopy (origTable)
-- make a deep copy of a table
function tableDeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[tableDeepCopy(orig_key)] = tableDeepCopy(orig_value)
        end
        setmetatable(copy, tableDeepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end
]]

--------------------------------------------------------------------------------------------
-- trimTable(inputTable)
-- trims leading and trailing white spaces from all strings in a table
function trimTable(inputTable)
	if not inputTable then return nil end

	local trimmedTable = {}
	for i = 1, #inputTable do
		table.insert(trimmedTable, trim(inputTable[i]))
	end
	return trimmedTable
end

--------------------------------------------------------------------------------------------
-- findInAttrValueTable(inputTable, indexField, indexValue, valueField)
function findInAttrValueTable(inputTable, indexField, indexValue, valueField)
	if not inputTable then return nil end
	
	for i = 1, #inputTable do
		if inputTable[i][indexField] == indexValue then return inputTable[i][valueField] end
	end
	
	return nil
end

--------------------------------------------------------------------------------------------
-- findInStringTable(inputTable, string)
function findInStringTable(inputTable, string)
	if not inputTable then return nil end
	
	for i = 1, #inputTable do
		if inputTable[i] == string then return i end
	end
	
	return nil
end

--------------------------------------------------------------------------------------------
-- getTableExtract(inputTable, tableField, filterAttr, filterPattern)
--  returns a table extract consisting of:
--   - the elements 'tableField' or the whole structure
--   - all elements matching filteAttr / filterPattern or all 
function getTableExtract(inputTable, tableField, filterAttr, filterPattern)
	if not inputTable then return nil end

	local j, tableExtract = 1, {}
	
	for i = 1, #inputTable do
		if not filterAttr or string.match(inputTable[i][filterAttr], filterPattern) then
			if tableField then 
				tableExtract[j] = inputTable[i][tableField]
			else
				tableExtract[j] = inputTable[i]
			end
			j = j + 1
		end
	end

	return tableExtract
end

--------------------------------------------------------------------------------------------
-- getTableDiff(table1, table2, keyName, isSameCheck)
--  returns a table of elements in table1, but not in table2
--  if keyName is given, then tables of structure are compared based on keyName
--  if isSameCheck function is given, use it as compar operator  
function getTableDiff(table1, table2, keyName, isSameCheck)
	local tableDiff

	if not table1 or #table1 == 0 or not table2 or #table2 == 0 then
		table1 = ifnil(table1, {})
		table2 = ifnil(table2, {})
		tableDiff = tableShallowCopy(table1)
	else
    	tableDiff = {}
    	local nDiff = 0
    	
    	for i = 1, #table1 do
    		local found = false 
    		
    		for j = 1, #table2 do
    			if 	(not keyName and table1[i] == table2[j]) or
    				(	 keyName and 
    					(not isSameCheck and table1[i][keyName] == table2[j][keyName]) or
    					(	 isSameCheck and isSameCheck(table1[i], table2[j]))) 
    			then
    				found = true
    				break
    			end
    		end
    		if not found then
    			nDiff = nDiff + 1
    			tableDiff[nDiff] = table1[i]
    		end
    	end
	end
	
	if keyName then
		writeLogfile(3, string.format("getTableDiff: t1(%d: '%s') - t2(%d: '%s') = tDiff(%d: '%s')\n", 
				#table1,	table.concat(getTableExtract(table1, 'name'), "','"), 
				#table2,	table.concat(getTableExtract(table2, 'name'), "','"), 
				#tableDiff, table.concat(getTableExtract(tableDiff, 'name'), "','")))
	else
		writeLogfile(3, string.format("getTableDiff: t1(%d: '%s') - t2(%d: '%s') = tDiff(%d: '%s')\n", 
				#table1,	table.concat(table1, "','"), 
				#table2,	table.concat(table2, "','"), 
				#tableDiff,	table.concat(tableDiff, "','")))
	end

	return tableDiff
end


----------------------- logging ---------------------------------------------------------
-- we can store some variables in 'global' local variables safely:
-- each export task will get its own copy of these variables

local logfilename
local loglevel
--[[loglevel:
	0 -	nothing
	1 - errors
	2 - info
	3 - tracing
	4 - debug
]]	

local loglevelname = {
	'ERROR',
	'INFO ',
	'TRACE',
	'DEBUG',
}

-- getLogFilename: return the filename of the logfile
function getLogFilename()
	return LrPathUtils.child(tmpdir, "PhotoStatLr.log")
end

-- getLogLogLevel: return the current loglevel
function getLogLevel()
	return loglevel
end

-- changeLoglevel: change the loglevel (after promptForMissingSettings)
function changeLogLevel (level)
	loglevel = level
end

-- openLogfile: clear the logfile, reopen and put in a start timestamp
function openLogfile (level)
	-- may be called twice (DeletePhotoFromCollection() and ProcessRenderedPhotos())
	-- so make sure, the file will not be truncated

	-- openLogfile may be called more than once w/ different loglevel, so change loglevel first
	loglevel = level

	logfilename = getLogFilename()
	
	-- if logfile does not exist: nothing to do, logfile will be created on first writeLogfile()
	if not LrFileUtils.exists(logfilename) then return end

	-- if logfile exists and is younger than 60 secs: do not truncate, it may be in use by a parallel export/publish process
	local logfileAttrs = LrFileUtils.fileAttributes(logfilename)
	if logfileAttrs and logfileAttrs.fileModificationDate > (LrDate.currentTime() - 300) then return end
	
	-- else: truncate existing logfile
	local logfile = io.open(logfilename, "w")
	io.close (logfile)
	
end

-- writeLogfile: always open, write, close, otherwise output will get lost in case of unexpected errors
function writeLogfile (level, msg)
	if level <= ifnil(loglevel, 2) then
		local logfile = io.open(getLogFilename(), "a")
		if logfile then
			logfile:write(LrDate.formatMediumTime(LrDate.currentTime()) .. ", " .. ifnil(loglevelname[level], tostring(level)) .. ": " .. msg)
			io.close (logfile)
		end
	end
end

-- getAttrValueOutputString(key, value, pwKeyPattern, hideKeyPattern)
-- returns the output string of an key-value-pair according to given keyname pattern for passwords
-- and for keys to hide
local function getAttrValueOutputString(key, value, pwKeyPattern, hideKeyPattern)
	if hideKeyPattern and string.match(key, hideKeyPattern) then
		return nil
	elseif pwKeyPattern and string.match(key, pwKeyPattern) then
		return '"' .. key ..'":"***"'
	else
		return '"' .. key ..'":"' .. tostring(ifnil(value, '<Nil>')) ..'"'
	end
end

-- writeTableLogfile (level, tableName, printTable, compact, pwKeyPattern, hideKeyPattern, isObservableTable)
-- output a table to logfile, max one level of nested tables
--   do not output keys matching hideKeyPattern
--   obfuscate value for keys matching pwKeyPattern
function writeTableLogfile(level, tableName, printTable, compact, pwKeyPattern, hideKeyPattern, isObservableTable)
	if level > ifnil(loglevel, 2) then return end
	
	local tableCompactOutputLine = {}
	
	if type(printTable) ~= 'table' then
		writeLogfile(level, tableName .. ' is not a table, but ' .. type(printTable) .. '\n')
		return
	end
	
	-- the pairs() iterator is different for observebale tables
	local pairs_r1, pairs_r2, pairs_r3
	if isObservableTable then
		pairs_r1, pairs_r2, pairs_r3 = printTable:pairs()
	else
		pairs_r1, pairs_r2, pairs_r3 = pairs(printTable)
	end
	
	if not compact then writeLogfile(level, '"' .. tableName .. '":{\n') end
--	for key, value in pairs( printTable ) do
	for key, value in pairs_r1, pairs_r2, pairs_r3 do
		if type(key) == 'table' then
			local outputLine = {}
			if not compact then
				writeLogfile(level, '\t<table>' .. ':{' ..  iif(compact, ' ', '\n'))
			end
			for key2, value2 in pairs( key ) do
				local attrValueString = getAttrValueOutputString(key2, value2, pwKeyPattern, hideKeyPattern)
				
				if compact then
					table.insert(outputLine, attrValueString)
				else	
					writeLogfile(level, '\t\t' .. attrValueString .. '\n')
				end
			end
			if attrValueString then
				if compact then
					table.sort(outputLine)
					table.insert(tableCompactOutputLine, '\n\t\t<table> : {' .. table.concat(outputLine, ', ') .. '}')
				else				
					writeLogfile(level, '\t}\n')
				end
			end
		elseif type(value) == 'table' and not (hideKeyPattern and string.match(key, hideKeyPattern)) then
			local outputLine = {}
			if not compact then
				writeLogfile(level, '\t"' .. key .. '":{' ..  iif(compact, ' ', '\n'))
			end
			for key2, value2 in pairs( value ) do
				local attrValueString = getAttrValueOutputString(key2, value2, pwKeyPattern, hideKeyPattern)
				if attrValueString then
					if compact then
						table.insert(outputLine, attrValueString)
					else	
						 writeLogfile(level, '\t\t' .. attrValueString .. '\n') 
					end
				end
			end
			if compact then
				table.sort(outputLine)
				table.insert(tableCompactOutputLine, '\n\t\t"' .. key .. '":{' .. table.concat(outputLine, ', ') .. '}')
			else				
				writeLogfile(level, '\t}\n')
			end
		else
			local attrValueString = getAttrValueOutputString(key, value, pwKeyPattern, hideKeyPattern)
			if attrValueString then
				if compact then 
					table.insert(tableCompactOutputLine, attrValueString)
				else
					writeLogfile(level, '	' .. attrValueString .. '\n')
				end
			end
		end
	end

	if compact then
		table.sort(tableCompactOutputLine)
		writeLogfile(level, '"' .. tableName .. '":{' .. table.concat(tableCompactOutputLine, ', ') .. '\n\t}\n')
	else
		writeLogfile(level, '}\n')
	end
end

-- closeLogfile: do nothing 
function closeLogfile()
--[[
	local logfile = io.open(logfilename, "a")
	local now = LrDate.currentTime()
	io.close (logfile)
]]
end

---------------------- semaphore operations -----------------------------------------
--[[
function waitSemaphore(semaName, info)
	local semaphoreFn = LrPathUtils.child(tmpdir, LrPathUtils.addExtension(semaName, 'sema'))

	while LrFileUtils.exists(semaphoreFn) do
		writeLogfile(3, info .. ": waiting for semaphore " .. semaName .. "\n")
		-- make sure we are not waiting forever for an orphaned semaphore file
		local fileAttr = LrFileUtils.fileAttributes(semaphoreFn)
		if fileAttr and fileAttr.fileCreationDate and (fileAttr.fileCreationDate < LrDate.currentTime() - 300) then
			writeLogfile(3, info .. ": removing orphanded semaphore " .. semaName .. "\n")
			signalSemaphore(semaName)
		else
			LrTasks.sleep(1)
		end	
	end

	local semaphoreFile = io.open(semaphoreFn, "w")
	semaphoreFile:write(LrDate.formatMediumTime(LrDate.currentTime()))
	io.close (semaphoreFile)
	return true
end

function signalSemaphore(semaName)
	local semaphoreFn = LrPathUtils.child(tmpdir, LrPathUtils.addExtension(semaName, 'sema'))

	LrFileUtils.delete(semaphoreFn)
end
]]

local semaphores = {}

function waitSemaphore(semaName, owner)
	while semaphores[semaName] do
		writeLogfile(3, string.format("waitSemaphore('%s'): '%s' is occupied by '%s' since %d sec\n", 
							owner, semaName, semaphores[semaName].owner, LrDate.currentTime() - semaphores[semaName].timestamp))
		-- warn user and exit if we are waiting too long  for a possibly orphaned semaphore
		if semaphores[semaName].timestamp < LrDate.currentTime() - 300 then
			writeLogfile(1, string.format("waitSemaphore('%s'): '%s' is blocked by '%s' since %d sec! Please, restart Lr if it this is not going to end!\n", 
							owner, semaName, semaphores[semaName].owner, LrDate.currentTime() - semaphores[semaName].timestamp))
			return false
		end	
		LrTasks.sleep(1)
	end

	semaphores[semaName] = {
		timestamp = LrDate.currentTime(),
		owner = owner,
	}
	return true
end

function signalSemaphore(semaName, owner)
	-- make sure, we do not remove a semaphore which we don't possess
	if semaphores[semaName] and semaphores[semaName].owner == owner then
		semaphores[semaName] = nil
	end 
end


---------------------- OS specific infos -----------------------------------------------------------------------------

---------------------------------------------------------------------------------------
-- getRootPath: get the OS specific filename of the NULL file
function getRootPath()
	if WIN_ENV then
		return 'C:\\'
	else
		return '/'
	end
end

---------------------------------------------------------------------------------------
-- getNullFilename: get the OS specific filename of the NULL file
function getNullFilename()
	if WIN_ENV then
		return 'NUL'
	else
		return '/dev/null'
	end
end

---------------------------------------------------------------------------------------
-- getProgExt: get the OS specifiy filename extension for programs
function getProgExt()
	if WIN_ENV then
		return 'exe'
	else
		return nil
	end
end

---------------------- filename/dirname sanitizing routines ---------------------------------------------------------

---------------------------------------------------------------------------------------
-- mkLegalFilename: substitute illegal filename char by their %nnn representation
-- This function should be used when a arbitrary string shall be used as filename or dirname 
function mkLegalFilename(str)
	if (str) then
		local newStr
		-- illegal filename characters: '\', '/', ':', '?', '*',  '"', '<', '>', '|'  
		newStr = string.gsub (str, '([\\\/:%?%*"<>|])', function (c)
								return string.format ("%%%02X", string.byte(c))
         end) 
		if newStr ~= str then
			writeLogfile(4, string.format("mkLegalFilename(%s) = %s\n", str, newStr))
		end
		str = newStr
	end
	return str
end 

---------------------------------------------------------------------------------------
-- mkSafeFilename: substitute illegal and critical characters by '-'
-- may only be used for temp. files!
function mkSafeFilename(str)
	if (str) then
		-- illegal filename characters: '\', ':', '?', '*',  '"', '<', '>', '|'  
		-- critical characters '(', ')', and ' '
--		writeLogfile(4, string.format("mkSafeFilename: was %s\n", str)) 
		str = string.gsub (str, '[\\:%?%*"<>|%s%(%)]', '-') 
--		writeLogfile(4, string.format("mkSafeFilename: now %s\n", str)) 
	end
	return str
end 

-- normalizeDirname(str)
-- sanitize dstRoot: replace \ by /, remove leading and trailings slashes

function normalizeDirname(str)
	if (str) then
		-- substitute '\' by '/' , remove leading and trailing '/'
		str = string.gsub(string.gsub(string.gsub (str, "\\", "/"), "^/", ""), "\/$", "")
	end
	return str
end 

---------------------- http encoding routines ---------------------------------------------------------

function urlencode(str)
	if (str) then
		str = string.gsub (str, "\n", "\r\n")
		str = string.gsub (str, "([^%w ])",function (c) return string.format ("%%%02X", string.byte(c)) end)
		str = string.gsub (str, " ", "%%20")
	end
	return str
end 

---------------------------------------------------------------------------------------------------- 
-- applyDefaultsIfNeededFromTo(srcTable, dstTable
-- For all all nil elements in dstTable, copy corresponding value from srcTable
function applyDefaultsIfNeededFromTo(srcTable, dstTable)
    for orig_key, orig_value in pairs(srcTable) do
		if dstTable[orig_key] == nil then 
			dstTable[orig_key] = orig_value 
			writeLogfile(4, string.format("applyDefaultsIfNeededFromTo: copying orig_key %s, orig_value '%s'\n", orig_key, tostring(orig_value)))
		end
    end
end

---------------------- session environment ----------------------------------------------------------

-- openSession(exportParams, publishedCollection, operation)
-- 	- copy all relevant settings into exportParams 
-- 	- initialize all required APIs: Convert, Upload, Exiftool
-- 	- login to Photo Station, if required
--	- start exiftool listener, if required
function openSession(exportParams, publishedCollection, operation)
	writeLogfile(4, string.format("openSession: operation = %s, publishMode = %s\n", operation, exportParams.publishMode))

	-- if "use secondary server" was choosen, temporarily overwrite primary address
	if exportParams.useSecondAddress then
		writeLogfile(4, "openSession: copy second server parameters\n")
--		exportParams.proto = exportParams.proto2
--		exportParams.servername = exportParams.servername2
		exportParams.serverTimeout = exportParams.serverTimeout2
		exportParams.serverUrl = exportParams.proto2 .. "://" .. exportParams.servername2
	end
	
	local collectionSettings
	
	-- if is Publish process, temporarily overwrite exportParams w/ collectionSettings
	if publishedCollection and publishedCollection:type() == 'LrPublishedCollection' then
    	collectionSettings = publishedCollection:getCollectionInfoSummary().collectionSettings
		writeLogfile(4, "openSession: copy collection settings\n")
    	
    	exportParams.storeDstRoot 	= true			-- dstRoot must be set in a Published Collection
    	exportParams.dstRoot 		= PSLrUtilities.getCollectionUploadPath(publishedCollection)
    	exportParams.createDstRoot 	= collectionSettings.createDstRoot
    	exportParams.copyTree 		= collectionSettings.copyTree
    	exportParams.srcRoot 		= collectionSettings.srcRoot
    	exportParams.renameDstFile	= collectionSettings.renameDstFile
    	exportParams.dstFilename	= collectionSettings.dstFilename
    	exportParams.RAWandJPG 		= collectionSettings.RAWandJPG
    	exportParams.sortPhotos 	= collectionSettings.sortPhotos
    	exportParams.exifTranslate 			= collectionSettings.exifTranslate
    	exportParams.exifXlatFaceRegions 	= collectionSettings.exifXlatFaceRegions
    	exportParams.exifXlatLabel 			= collectionSettings.exifXlatLabel
    	exportParams.exifXlatRating 		= collectionSettings.exifXlatRating
    	exportParams.locationTagTemplate	= collectionSettings.locationTagTemplate

		-- copy download options to exportParams only for GetComments(), so promptForMissingSettings() will only be called once  
    	if operation == 'GetCommentsFromPublishedCollection' then
			writeLogfile(4, "openSession: copy download settings\n")
        	exportParams.downloadMode	 		= collectionSettings.downloadMode
        	exportParams.commentsDownload 		= collectionSettings.commentsDownload
        	exportParams.pubCommentsDownload	= collectionSettings.pubCommentsDownload
        	exportParams.titleDownload	 		= collectionSettings.titleDownload
        	exportParams.captionDownload 		= collectionSettings.captionDownload
        	exportParams.tagsDownload	 		= collectionSettings.tagsDownload
        	exportParams.locationDownload 		= collectionSettings.locationDownload
        	exportParams.locationTagDownload	= collectionSettings.locationTagDownload
        	exportParams.ratingDownload	 		= collectionSettings.ratingDownload
        	exportParams.PS2LrFaces	 			= collectionSettings.PS2LrFaces
        	exportParams.PS2LrLabel	 			= collectionSettings.PS2LrLabel
        	exportParams.PS2LrRating	 		= collectionSettings.PS2LrRating
    	end

 		if string.find('ProcessRenderedPhotos', operation, 1, true) then
			exportParams.publishMode 	= collectionSettings.publishMode
		else
			-- avoid prompt for PublishMode if operation is not ProcessRenderedPhotos
			exportParams.publishMode 	= 'Publish'
		end
	end
	
	if not exportParams.exifTranslate then
    	exportParams.exifXlatFaceRegions 	= false
    	exportParams.exifXlatLabel 			= false
    	exportParams.exifXlatRating 		= false
	end
	
	-- Get missing settings, if not stored in preset.
	if promptForMissingSettings(exportParams, publishedCollection, operation) == 'cancel' then
		return false, 'cancel'
	end

	-- dump current session parameters to logfile
--	writeTableLogfile(2, 'exportParams', exportParams["< contents >"], 	iif(getLogLevel() > 2, false, true), 'password', iif(getLogLevel() > 3, NULL, "^LR_"))
	writeTableLogfile(2, 'exportParams', exportParams, 	iif(getLogLevel() > 2, false, true), 'password', iif(getLogLevel() > 3, NULL, "^LR_"), true)

	-- ConvertAPI: required if Export/Publish/Metadata 
	if operation == 'ProcessRenderedPhotos' and string.find('Export,Publish,Metadata', exportParams.publishMode, 1, true) and not exportParams.cHandle then
			exportParams.cHandle = PSConvert.initialize()
			if not exportParams.cHandle then return false, 'Cannot initialize converters, check path for Syno Photo Station Uploader' end
	end

	-- Login to Photo Station: not required for CheckMoved, not required on Download if Download was disabled
	if not 	exportParams.uHandle 
	and 	exportParams.publishMode ~= 'CheckMoved' 
	and not (string.find('GetCommentsFromPublishedCollection,GetRatingsFromPublishedCollection', operation) and exportParams.downloadMode == 'No') then
		local result, errorCode
		exportParams.uHandle, errorCode = PSPhotoStationAPI.initialize(exportParams.serverUrl,
														iif(exportParams.usePersonalPS, "/~" .. ifnil(exportParams.personalPSOwner, "unknown") .. "/photo/", "/photo/"),
														exportParams.serverTimeout)
		if not exportParams.uHandle then
			local errorMsg = string.format("Initialization of %s %s at\n%s\nfailed!\nReason: %s\n",
									iif(exportParams.usePersonalPS, "Personal Photo Station of ", "Standard Photo Station"), 
									iif(exportParams.usePersonalPS and exportParams.personalPSOwner,exportParams.personalPSOwner, ""), 
									exportParams.serverUrl,
									PSPhotoStationUtils.getErrorMsg(errorCode))
			writeLogfile(1, errorMsg)
			return 	false, errorMsg
		end

		result, errorCode = PSPhotoStationAPI.login(exportParams.uHandle, exportParams.username, exportParams.password)
		if not result then
			local errorMsg = string.format("Login to %s %s at\n%s\nfailed!\nReason: %s\n",
									iif(exportParams.usePersonalPS, "Personal Photo Station of ", "Standard Photo Station"), 
									iif(exportParams.usePersonalPS and exportParams.personalPSOwner,exportParams.personalPSOwner, ""), 
									exportParams.serverUrl,
									PSPhotoStationUtils.getErrorMsg(errorCode))
			writeLogfile(1, errorMsg)
			 exportParams.uHandle = nil
			return 	false, errorMsg
					
		end
		writeLogfile(2, "Login to " .. iif(exportParams.usePersonalPS, "Personal Photo Station of ", "Standard Photo Station") .. 
								iif(exportParams.usePersonalPS and exportParams.personalPSOwner,exportParams.personalPSOwner, "") .. 
								 "(" .. exportParams.serverUrl .. ") OK\n")
	end

	-- exiftool: required if Export/Publish and exif translation was selected, or if downloading faces
	if 	(	(operation == 'ProcessRenderedPhotos' and string.find('Export,Publish,Metadata', exportParams.publishMode, 1, true) and exportParams.exifTranslate)
		 or	(operation == 'GetRatingsFromPublishedCollection' and exportParams.PS2LrFaces)
		)
	and not exportParams.eHandle then 
		exportParams.eHandle= PSExiftoolAPI.open(exportParams) 
		return iif(exportParams.eHandle, true, false), "Cannot start exiftool!" 
	end
	
	return true
end

-- closeSession(exportParams)
-- terminate exiftool
function closeSession(exportParams)
	writeLogfile(3,"closeSession() starting\n")

	if exportParams.eHandle then 
		PSExiftoolAPI.close(exportParams.eHandle)
		exportParams.eHandle = nil 
	end
		
	writeLogfile(3,"closeSession() done.\n")

	return true
end

---------------------- Dialog functions ----------------------------------------------------------

-- promptForMissingSettings(exportParams, publishedCollection, operation)
-- check for parameters set to "Ask me later" and open a dialog to get values for them
function promptForMissingSettings(exportParams, publishedCollection, operation)
	local f = LrView.osFactory()
	local bind = LrView.bind
	local share = LrView.share
	local conditionalItem = LrView.conditionalItem
	local needPw = (ifnil(exportParams.password, "") == "")
	local needDstRoot = not exportParams.storeDstRoot
	local needPublishMode = false
	local needDownloadMode = false
	local needLoglevel = false
	local isAskForMissingParams = true
	local pubCollectionName

	if operation == 'ProcessRenderedPhotos' and ifnil(exportParams.publishMode, 'Ask') == 'Ask' then
		exportParams.publishMode = 'Publish'
		needPublishMode = true
	end
		
	if string.find('GetCommentsFromPublishedCollection,GetRatingsFromPublishedCollection', operation, 1, true) and ifnil(exportParams.downloadMode, 'Ask') == 'Ask' then
		exportParams.downloadMode = 'Yes'
		needDownloadMode = true
	end
		
	-- logLevel 9999 means  'Ask me later'
	if exportParams.logLevel == 9999 then
		exportParams.logLevel = 2 			-- Normal
		needLoglevel = true
	end
	
	if not (needPw or needDstRoot or needPublishMode or needDownloadMode or needLoglevel) then
		return "ok"
	end
	
	if publishedCollection then
		pubCollectionName = publishedCollection:getName()
	end 
	
	local passwdView = f:view {
		f:row {
			f:static_text {
				title = LOC "$$$/PSUpload/ExportDialog/Username=Username:",
				alignment = 'right',
				width = share 'labelWidth',
			},

			f:edit_field {
				value = bind 'username',
				tooltip = LOC "$$$/PSUpload/ExportDialog/UsernameTT=Enter the username for Photo Station access.",
				truncation = 'middle',
				immediate = true,
				width_in_chars = 16,
				fill_horizontal = 1,
			},
		},
		
		f:spacer {	height = 5, },

		f:row {
			f:static_text {
				title = LOC "$$$/PSUpload/ExportDialog/Password=Password:",
				alignment = 'right',
				width = share 'labelWidth',
			},

			f:password_field {
				value = bind 'password',
				tooltip = LOC "$$$/PSUpload/ExportDialog/PasswordTT=Enter the password for Photo Station access.",
				truncation = 'middle',
				immediate = true,
				width = share 'labelWidth',
				fill_horizontal = 1,
			},
		},
	}

	-- Create the contents for the dialog.
	local c = f:view {
		bind_to_object = exportParams,

		PSDialogs.missingParamsHeaderView(f, exportParams, operation), 
		f:spacer {	height = 10, },
		conditionalItem(needPw, passwdView), 
		f:spacer {	height = 10, },
		conditionalItem(needDstRoot, 	 PSDialogs.dstRootView(f, exportParams, isAskForMissingParams)), 
		f:spacer {	height = 10, },
		conditionalItem(needPublishMode, PSDialogs.publishModeView(f, exportParams, isAskForMissingParams)), 
		f:spacer {	height = 10, },
		conditionalItem(needDownloadMode, PSDialogs.downloadOptionsView(f, exportParams, isAskForMissingParams)), 
		f:spacer {	height = 10, },
		conditionalItem(needLoglevel, 	 PSDialogs.loglevelView(f, exportParams, isAskForMissingParams)), 
	}

	local result = LrDialogs.presentModalDialog {
			title = "Photo StatLr" .. iif(pubCollectionName, ": Published Collection '" .. ifnil(pubCollectionName, '') .. "'", ""),
			contents = c
		}
	
	if result == 'ok' and needLoglevel then
		changeLogLevel(exportParams.logLevel)
	end
	
	return result
end

-- showFinalMessage -------------------------------------------

function showFinalMessage (title, message, msgType)
	local appVersion = LrApplication.versionTable()
	local prefs = LrPrefs.prefsForPlugin()
	local updateAvail = false
	local updateNotice
	
	if ifnil(prefs.updateAvailable, '') ~= '' and ifnil(prefs.updateAvailable, '') ~= pluginVersion then
		updateNotice = 'This is a very moving moment: Version ' .. prefs.updateAvailable .. ' is available!\n'
		updateAvail = true
	end
	
	writeLogfile(2, title .. ": " .. message .. '\n')

	if msgType == 'critical' or msgType == 'warning' then 
--		LrDialogs.message(title, 'Booo!! ' .. message, msgType)
		local action = LrDialogs.confirm(title, iif(msgType == 'critical', 'Booo!!\n', ' Well, that was different:\n') .. message, "Go to Logfile", "Never mind")
		if action == "ok" then
			LrShell.revealInShell(getLogFilename())
		end	
	elseif appVersion.major >= 5 then
		-- showBezel not supported in Lr4 and below  
		LrDialogs.showBezel('Boooor-ing! ' .. message, 10)
	end
	
	if updateAvail then
		writeLogfile(2,updateNotice .. '\n')
		if LrDialogs.promptForActionWithDoNotShow( {
				message 		= 'Photo StatLr: update available',
				info 			= updateNotice,
				actionPrefKey 	= 'updateAvailableNote',
				verbBtns 		= {
					{ label = 'Go to Update URL', verb = 'yes', },
					{ label = 'Thanks, not now', verb = 'no', },
				}
			} ) == 'yes' then
			LrHttp.openUrlInBrowser(prefs.downloadUrl)
		end
	end
end

PSUtilities = {}

-- PSUtilities.normalizeArea(area) -------------------------------------------
-- rotate area if required, add UpperLeft coords
function PSUtilities.normalizeArea(area)
	local areaNew
	if not area then return nil end
	
	areaNew = tableShallowCopy(area)
	-- rotate area if required (rotation ~= 0):
	if area.rotation ~= 0 then
		--		1) mirror y to get orthogonal coords
		--		2) shift area (0:1, 0:1) to (-0.5:0.5, -0.5:0.5) (centered)
		--		3) rotate according to rotation matrix:
		--			x' = x * cosA - y * sinA 
		--			y' = x * sinA + y * cosA 
		-- 		4) shift area (-0.5:0.5, -0.5:0.5) back to (0:1, 0:1) 
		-- 		5) mirror y to get original coords
		local sinA = math.sin(area.rotation)
		local cosA = math.cos(area.rotation)
		
		-- 1)
		local x,y = area.xCenter, 1 - area.yCenter
		
		-- 2) - 4)
		areaNew.xCenter	= 		((x - 0.5) * cosA - (y - 0.5) * sinA) + 0.5
		-- 2) - 5)
		areaNew.yCenter	= 1 -  (((x - 0.5) * sinA + (y - 0.5) * cosA) + 0.5)
		
		areaNew.width		= math.abs(area.width * cosA - area.height * sinA)
		areaNew.height		= math.abs(area.width * sinA + area.height * cosA)
--		writeLogfile(3, string.format("PSUtilities.normalizeArea: sinA:%f, cosA:%f w:%f/%f, h:%f/%f\n", 
--										sinA, cosA, area.width, areaNew.width, area.height, areaNew.height)) 
		areaNew.rotation 	= 0
	end
	
	areaNew.xLeft	= areaNew.xCenter - (areaNew.width / 2)
	areaNew.yUp		= areaNew.yCenter - (areaNew.height / 2)

	writeLogfile(3, string.format("PSUtilities.normalizeArea: '%s' --> xC:%f/xL:%f yC:%f/yU:%f, w:%f, h:%f\n", 
										areaNew.name,
										areaNew.xCenter,
										areaNew.xLeft,
										areaNew.yCenter,
										areaNew.yUp,
										areaNew.width,
										areaNew.height	
									))
	return areaNew
end

-- PSUtilities.denormalizeArea(area) -------------------------------------------
-- rotate and de-crop a normalized area (from PS) to fit a photo which might be rotated in Lr
function PSUtilities.denormalizeArea(area, photoDimension)
	if not area or not photoDimension or not photoDimension.orient then return nil end

	writeLogfile(3, string.format("PSUtilities.denormalizeArea: photo - Orient: %s, Crop: %s, Top: %f, Bottom: %f, Left: %f, Right: %f\n", 
									photoDimension.orient, photoDimension.hasCrop, photoDimension.cropTop, photoDimension.cropBottom, photoDimension.cropLeft, photoDimension.cropRight)) 

	writeLogfile(3, string.format("                             area  - x: %f, y: %f, width: %f, height: %f\n", 
									area.x, area.y, area.width, area.height)) 

	local areaNew = tableShallowCopy(area)
	local photoRotation = string.format("%1.5f", 0)
	
	if string.find(photoDimension.orient, 'Horizontal') then
		photoRotation	= string.format("%1.5f", 0)
	elseif string.find(photoDimension.orient, '90') then
		photoRotation = string.format("%1.5f", math.rad(90))
	elseif string.find(photoDimension.orient, '180') then
		photoRotation	= string.format("%1.5f", math.rad(180))
	elseif string.find(photoDimension.orient, '270') then
		photoRotation = string.format("%1.5f", math.rad(-90))
	end

	--	 transform upper left to center coords
	areaNew.xCenter = areaNew.x + (areaNew.width / 2)
	areaNew.yCenter = areaNew.y + (areaNew.height / 2)
	
	-- de-crop
	if photoDimension.hasCrop then
		areaNew.width	= areaNew.width   * (photoDimension.cropRight - photoDimension.cropLeft) 
		areaNew.xCenter = areaNew.xCenter * (photoDimension.cropRight - photoDimension.cropLeft) + photoDimension.cropLeft 
		areaNew.height 	= areaNew.height  * (photoDimension.cropBottom - photoDimension.cropTop)
		areaNew.yCenter = areaNew.yCenter * (photoDimension.cropBottom - photoDimension.cropTop) + photoDimension.cropTop
	end
	 
	-- if orig photo is rotated:
	if photoRotation ~= 0 then
		--		1) mirror y to get orthogonal coords
		--		2) shift area (0:1, 0:1) to (-0.5:0.5, -0.5:0.5) (centered)
		--		3) rotate according to rotation matrix:
		--			x' = x * cosA - y * sinA 
		--			y' = x * sinA + y * cosA 
		-- 		4) shift area (-0.5:0.5, -0.5:0.5) back to (0:1, 0:1) 
		-- 		5) mirror y to get original coords
		local sinA = math.sin(photoRotation)
		local cosA = math.cos(photoRotation)
		
		-- 1)
		local x,y, width, height = areaNew.xCenter, 1 - areaNew.yCenter, areaNew.width, areaNew.height 
		
		-- 2) - 4)
		areaNew.xCenter	= 		((x - 0.5) * cosA - (y - 0.5) * sinA) + 0.5
		-- 2) - 5)
		areaNew.yCenter	= 1 -  (((x - 0.5) * sinA + (y - 0.5) * cosA) + 0.5)
		
		areaNew.width		= math.abs(width * cosA - height * sinA)
		areaNew.height		= math.abs(width * sinA + height * cosA)
		areaNew.rotation 	= 0
	end
	
	writeLogfile(3, string.format("PSUtilities.denormalizeArea: '%s' --> xC:%f, yC:%f, w:%f, h:%f\n", 
										areaNew.name,
										areaNew.xCenter,
										areaNew.yCenter,
										areaNew.width,
										areaNew.height	
									))
	return areaNew
end

-- PSUtilities.areaCompare(area1, area2)
-- Compare face area in Lr style with face area in PS style
-- returns true if identical, false otherwise
function PSUtilities.areaCompare(area1, area2)
	local areaLr, areaPS
	if area1.additional then
		areaPS = area1
		areaLr = area2
	else
		areaPS = area2
		areaLr = area1
	end

	if 	areaPS.type == 'people' and
		ifnil(areaLr.name, '') == ifnil(areaPS.name, '') and
		areaPS.additional and areaPS.additional.info and
		areaPS.additional.info.x and areaPS.additional.info.y and areaPS.additional.info.width and areaPS.additional.info.height and
		math.abs(areaLr.xLeft	- areaPS.additional.info.x) < 0.05 and
		math.abs(areaLr.yUp		- areaPS.additional.info.y) < 0.05 and
		math.abs(areaLr.width	- areaPS.additional.info.width) < 0.05 and
		math.abs(areaLr.height 	- areaPS.additional.info.height) < 0.05
	then 
		writeLogfile(3, string.format("PSUtilities.areaCompare('%s', '%s') returns true\n", areaLr.name, areaPS.name))
		return true
	else 
		-- writeTableLogfile(3, 'areaPS.additional.info', areaPS.additional.info, true)
		writeLogfile(3, string.format("PSUtilities.areaCompare('%s', '%s') returns false\n", areaLr.name, areaPS.name))
		return false
	end 
end
