--[[----------------------------------------------------------------------------

PSUtilities.lua
Utilities for Lightroom Photo StatLr
Copyright(c) 2015, Martin Messmer

exported functions:
	- JSON.onDecodeError
	- JSON.onDecodeNilError
	- JSON.onDecodeHtmlError
	
	- ifnil
	- iif
	- split
	- trim
	
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
-- local LrShell 		= import 'LrShell'
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
	if str == nil then
		return subst
	else
		return str
	end
end 

function iif(condition, thenExpr, elseExpr)
	if condition then
		return thenExpr
	else
		return elseExpr
	end
end 

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

function trim(s)
  return (string.gsub(s,"^%s*(.-)%s*$", "%1"))
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
function changeLoglevel (level)
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
		local logfile = io.open(logfilename, "a")
		logfile:write(LrDate.formatMediumTime(LrDate.currentTime()) .. ", " .. ifnil(loglevelname[level], tostring(level)) .. ": " .. msg)
		io.close (logfile)
	end
end

-- writeTableLogfile (level, tableName, printTable)
-- output a table to logfile, max one level of nested tables
function writeTableLogfile(level, tableName, printTable)
	if type(printTable) ~= 'table' then
		writeLogfile(level, tableName .. ' is not a table, but ' .. type(printTable) .. '\n')
		return
	end
	
	writeLogfile(level, '"' .. tableName .. '":{\n')
	for key, value in pairs( printTable ) do
		if type(value) == 'table' then
			writeLogfile(level, '	"' .. key .. '":{\n')
			for key2, value2 in pairs( value ) do
				writeLogfile(level, '		"' .. key2 ..'":"' .. tostring(ifnil(value2, '<Nil>')) ..'"\n')
			end
			writeLogfile(level, '	}\n')
		else
			writeLogfile(level, '	"' .. key ..'":"' .. tostring(ifnil(value, '<Nil>')) ..'"\n')
		end
	end
	writeLogfile(level, '}\n')
end

-- closeLogfile: write the end timestamp and time consumed
function closeLogfile()
	local logfile = io.open(logfilename, "a")
	local now = LrDate.currentTime()
	io.close (logfile)
end

---------------------- semaphore operations -----------------------------------------

function waitSemaphore(semaName, info)
	local semaphoreFn = LrPathUtils.child(tmpdir, LrPathUtils.addExtension(semaName, 'sema'))

	while LrFileUtils.exists(semaphoreFn) do
		writeLogfile(3, info .. ": waiting for semaphore " .. semaName .. "\n")
		-- make sure we are not waiting forever for an orphaned semaphore file
		local fileAttr = LrFileUtils.fileAttributes(semaphoreFn)
		if fileAttr and (fileAttr.fileCreationDate < LrDate.currentTime() - 300) then
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
		writeLogfile(4, string.format("mkLegalFilename: was %s\n", str)) 
		-- illegal filename characters: '\', '/', ':', '?', '*',  '"', '<', '>', '|'  
		str = string.gsub (str, '([\\\/:%?%*"<>|])', function (c)
								return string.format ("%%%02X", string.byte(c))
         end) 
		writeLogfile(4, string.format("mkLegalFilename: now %s\n", str)) 
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

---------------------- table operations ----------------------------------------------------------

-- tableShallowCopy (origTable)
-- make a shallow copy of a table
--[[
function tableShallowCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
			writeLogfile(2, string.format("tableCopy: copying orig_key %s, orig_value %s\n", orig_key, tostring(orig_value)))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

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

---------------------- session environment ----------------------------------------------------------

-- openSession(exportParams, publishedCollection, operation)
-- 	- copy all relevant settings into exportParams 
-- 	- initialize all required APIs: Convert, Upload, Exiftool
-- 	- login to Photo Station, if required
--	- start exiftool listener, if required
function openSession(exportParams, publishedCollection, operation)
	-- if "use secondary server" was choosen, temporarily overwrite primary address
	writeLogfile(4, string.format("openSession: operation = %s , publishMode = %s\n", operation, exportParams.publishMode))
	if exportParams.useSecondAddress then
		writeLogfile(4, "openSession: copy second server parameters\n")
		exportParams.proto = exportParams.proto2
		exportParams.servername = exportParams.servername2
		exportParams.serverTimeout = exportParams.serverTimeout2
		exportParams.serverUrl = exportParams.proto .. "://" .. exportParams.servername
	end
	
	-- if is Publish process, temporarily overwrite exportParams w/ CollectionSettings for Target Album
	if publishedCollection and publishedCollection:type() == 'LrPublishedCollection' then
    	local collectionSettings = publishedCollection:getCollectionInfoSummary().collectionSettings
		writeLogfile(4, "openSession: copy collection settings\n")
    	
    	exportParams.storeDstRoot 	= true			-- dstRoot must be set in a Published Collection
    	exportParams.dstRoot 		= PSLrUtilities.getCollectionUploadPath(publishedCollection)
    	exportParams.createDstRoot 	= collectionSettings.createDstRoot
    	exportParams.copyTree 		= collectionSettings.copyTree
    	exportParams.srcRoot 		= collectionSettings.srcRoot
    	exportParams.RAWandJPG 		= collectionSettings.RAWandJPG
    	exportParams.sortPhotos 	= collectionSettings.sortPhotos
    	exportParams.exifTranslate 			= collectionSettings.exifTranslate
    	exportParams.exifXlatFaceRegions 	= collectionSettings.exifXlatFaceRegions
    	exportParams.exifXlatLabel 			= collectionSettings.exifXlatLabel
    	exportParams.exifXlatRating 		= collectionSettings.exifXlatRating
    	
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
	if promptForMissingSettings(exportParams, operation) == 'cancel' then
		return false, 'cancel'
	end

	-- ConvertAPI: required if Export/Publish and thumb generation is configured
	if operation == 'ProcessRenderedPhotos' and string.find('Export,Publish', exportParams.publishMode, 1, true) and exportParams.thumbGenerate and not exportParams.cHandle then
			exportParams.cHandle = PSConvert.initialize()
			if not exportParams.cHandle then return false, 'Cannot initialize converters, check path for Syno Photo Station Uploader' end
	end

	-- Login to Photo Station: not required for CheckMoved
	if exportParams.publishMode ~= 'CheckMoved' and not exportParams.uHandle then
		local result, errorCode
		exportParams.uHandle, errorCode = PSPhotoStationAPI.initialize(exportParams.serverUrl, 
														iif(exportParams.usePersonalPS, exportParams.personalPSOwner, nil),
														exportParams.serverTimeout)
		if not exportParams.uHandle then
			local errorMsg = string.format("Initialization of %s %s at\n%s\nfailed!\nReason: %s\n",
									iif(exportParams.usePersonalPS, "Personal Photo Station of ", "Standard Photo Station"), 
									iif(exportParams.usePersonalPS and exportParams.personalPSOwner,exportParams.personalPSOwner, ""), 
									exportParams.serverUrl,
									PSPhotoStationAPI.getErrorMsg(errorCode))
			writeLogfile(1, errorMsg)
			return 	false, errorMsg
		end
		
		result, errorCode = PSPhotoStationAPI.login(exportParams.uHandle, exportParams.username, exportParams.password)
		if not result then
			local errorMsg = string.format("Login to %s %s at\n%s\nfailed!\nReason: %s\n",
									iif(exportParams.usePersonalPS, "Personal Photo Station of ", "Standard Photo Station"), 
									iif(exportParams.usePersonalPS and exportParams.personalPSOwner,exportParams.personalPSOwner, ""), 
									exportParams.serverUrl,
									PSPhotoStationAPI.getErrorMsg(errorCode))
			writeLogfile(1, errorMsg)
			 exportParams.uHandle = nil
			return 	false, errorMsg
					
		end
		writeLogfile(2, "Login to " .. iif(exportParams.usePersonalPS, "Personal Photo Station of ", "Standard Photo Station") .. 
								iif(exportParams.usePersonalPS and exportParams.personalPSOwner,exportParams.personalPSOwner, "") .. 
								 "(" .. exportParams.serverUrl .. ") OK\n")
	end

	-- exiftool: required if Export/Publish and and any exif translation was selected
	if operation == 'ProcessRenderedPhotos' and string.find('Export,Publish', exportParams.publishMode, 1, true) and exportParams.exifTranslate and not exportParams.eHandle then 
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

-- promptForMissingSettings(exportParams, operation)
-- check for parameters set to "Ask me later" and open a dialog to get values for them
function promptForMissingSettings(exportParams, operation)
	local f = LrView.osFactory()
	local bind = LrView.bind
	local share = LrView.share
	local conditionalItem = LrView.conditionalItem
	local needPw = (ifnil(exportParams.password, "") == "")
	local needDstRoot = not exportParams.storeDstRoot
	local needPublishMode = false
	local needLoglevel = false
	local isAskForMissingParams = true

	if operation == 'ProcessRenderedPhotos' and ifnil(exportParams.publishMode, 'Ask') == 'Ask' then
		exportParams.publishMode = 'Publish'
		needPublishMode = true
	end
		
	-- logLevel 9999 means  'Ask me later'
	if exportParams.logLevel == 9999 then
		exportParams.logLevel = 2 			-- Normal
		needLoglevel = true
	end
	
	if not (needPw or needDstRoot or needPublishMode or needLoglevel) then
		return "ok"
	end
	
	local passwdView = f:view {
		f:row {
			f:static_text {
				title = LOC "$$$/PSUpload/ExportDialog/USERNAME=Photo Station Login:",
				alignment = 'right',
				width = share 'labelWidth',
			},

			f:edit_field {
				value = bind 'username',
				tooltip = LOC "$$$/PSUpload/ExportDialog/USERNAMETT=Enter the username for Photo Station access.",
				truncation = 'middle',
				immediate = true,
				width_in_chars = 16,
				fill_horizontal = 1,
			},
		},
		
		f:spacer {	height = 5, },

		f:row {
			f:static_text {
				title = LOC "$$$/PSUpload/ExportDialog/PASSWORD=Photo Station Password:",
				alignment = 'right',
				width = share 'labelWidth',
			},

			f:password_field {
				value = bind 'password',
				tooltip = LOC "$$$/PSUpload/ExportDialog/PASSWORDTT=Enter the password for Photo Station access.",
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
		conditionalItem(needLoglevel, 	 PSDialogs.loglevelView(f, exportParams, isAskForMissingParams)), 
	}

	local result = LrDialogs.presentModalDialog {
			title = "Photo StatLr",
			contents = c
		}
	
	if result == 'ok' and needLoglevel then
		changeLoglevel(exportParams.logLevel)
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
		updateNotice = 'This is a very moving moment: Version ' .. prefs.updateAvailable .. ' available!\n'
		updateAvail = true
	end
	
	writeLogfile(2, title .. ": " .. message .. '\n')

	if msgType == 'critical' then 
		LrDialogs.message(title, 'Booo!! ' .. message, msgType)
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
