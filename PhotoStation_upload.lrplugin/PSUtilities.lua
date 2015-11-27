--[[----------------------------------------------------------------------------

PSUtilities.lua
Utilities for Lightroom PhotoStation Upload
Copyright(c) 2015, Martin Messmer

useful functions:
	- ifnil
	- iif
	- mkSaveFilename
	
	- openLogfile
	- writeLogfile
	- closeLogfile
	
	- copyCollectionSettingsToExportParams
	- openSession
	- closeSession
	
	- promptForMissingSettings
	- showFinalMessage	
	
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
]]
--------------------------------------------------------------------------------

-- Lightroom API
local LrApplication 	= import 'LrApplication'
local LrDate 			= import 'LrDate'
local LrDialogs 		= import 'LrDialogs'
local LrFileUtils 		= import 'LrFileUtils'
local LrHttp	 		= import 'LrHttp'
local LrPathUtils 		= import 'LrPathUtils'
-- local LrProgressScope = import 'LrProgressScope'
-- local LrShell 		= import 'LrShell'
local LrPrefs	 		= import 'LrPrefs'
local LrTasks 			= import 'LrTasks'
local LrView 			= import 'LrView'

JSON = assert(loadfile (LrPathUtils.child(_PLUGIN.path, 'JSON.lua')))()

--============================================================================--

tmpdir = LrPathUtils.getStandardFilePath("temp")

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

-- getLogFilename: return the filename of the logfile
function getLogFilename()
	return LrPathUtils.child(tmpdir, "PhotoStationUpload.log")
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

	-- if logfilename already set: nothing to do, logfile was already opened (and truncated)
	if logfilename then return end
	
	logfilename = getLogFilename()
	
	-- if logfile does not exist: nothing to do, logfile will be created on first writeLogfile()
	if not LrFileUtils.exists(logfilename) then return end

	-- if logfile exists and is younger than 60 secs: do not truncate, it may be in use by a parallel export/publish process
	local logfileAttrs = LrFileUtils.fileAttributes(logfilename)
	if logfileAttrs and logfileAttrs.fileModificationDate > (LrDate.currentTime() - 60) then return end
	
	-- else: truncate existing logfile
	local logfile = io.open(logfilename, "w")
	io.close (logfile)
	
end

-- writeLogfile: always open, write, close, otherwise output will get lost in case of unexpected errors
function writeLogfile (level, msg)
	if level <= loglevel then
		local logfile = io.open(logfilename, "a")
		logfile:write(LrDate.formatMediumTime(LrDate.currentTime()) .. ": " .. msg)
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

---------------------- filename encoding routines ---------------------------------------------------------

function mkSaveFilename(str)
	if (str) then
		-- substitute blanks, '(' and ')' by '-'
		str = string.gsub (str, "[%s%(%)]", "-") 
	end
	return str
end 

---------------------- directory name normalizing routine --------------------------------------------------

function normalizeDirname(str)
	if (str) then
		-- substitute '\' by '/' , remove leading and trailing '/'
		str = string.gsub(string.gsub(string.gsub (str, "\\", "/"), "^/", ""), "\/$", "")
	end
	return str
end 

---------------------- http encoding routines ---------------------------------------------------------

function trim(s)
  return (string.gsub(s,"^%s*(.-)%s*$", "%1"))
end

function urlencode(str)
	if (str) then
		str = string.gsub (str, "\n", "\r\n")
		str = string.gsub (str, "([^%w ])",function (c) return string.format ("%%%02X", string.byte(c)) end)
		str = string.gsub (str, " ", "%%20")
	end
	return str
end 

----------------------- JSON helper --------------------------------------------------------------
function JSON:onDecodeError(message, text, location, etc)
	writeLogfile(4, string.format("JSON-DecodeError: msg=%s, txt=%s, loc=%s, etc=%s\n", 
									ifnil(message, '<Nil>'), ifnil(text, '<Nil>'),
									ifnil(location, '<Nil>'),ifnil(etc, '<Nil>')))
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

-- copyCollectionSettingsToExportParams(publishedCollection, exportParams)
-- copy temporarily the collections settings to exportParams, so that we can work solely with exportParams;  
function copyCollectionSettingsToExportParams(publishedCollection, exportParams)
	local collectionSettings = publishedCollection:getCollectionInfoSummary().collectionSettings
	local parentCollectionSet
	
	exportParams.storeDstRoot 	= true			-- must be fixed in a Published Collection
	
	-- Build the directory path by recursively traversing the parent collection sets and prepend each directory
	exportParams.dstRoot 		= collectionSettings.dstRoot
	parentCollectionSet  = publishedCollection:getParent()
	while parentCollectionSet do
		local parentSettings = parentCollectionSet:getCollectionSetInfoSummary().collectionSettings
		if parentSettings and ifnil(normalizeDirname(parentSettings.baseDir), '') ~= '' then
			exportParams.dstRoot 		= normalizeDirname(parentSettings.baseDir) .. "/" .. exportParams.dstRoot	
		end
		parentCollectionSet  = parentCollectionSet:getParent()
	end
	writeLogfile(4, "copyCollectionSettings...(): dstRoot = " .. exportParams.dstRoot .."\n")
	
	exportParams.createDstRoot 	= collectionSettings.createDstRoot
	exportParams.copyTree 		= collectionSettings.copyTree
	exportParams.srcRoot 		= collectionSettings.srcRoot
	exportParams.publishMode 	= collectionSettings.publishMode
end

-- openSession(exportParams, publishMode)
-- initialize all required APIs: Convert, Upload, FileStation, Exiftool
-- login to PhotoStation and FileStation, if required
function openSession(exportParams, publishMode)

	-- if "use secondary server was choosen, temporarily overwrite primary address
	writeLogfile(4, "openSession: publishMode = " .. publishMode .."\n")
	if exportParams.useSecondAddress then
		writeLogfile(4, "openSession: copy second server parameters\n")
		exportParams.proto = exportParams.proto2
		exportParams.servername = exportParams.servername2
		exportParams.servername = exportParams.serverTimeout2
		exportParams.serverUrl = exportParams.proto .. "://" .. exportParams.servername
		exportParams.useFileStation = exportParams.useFileStation2
		exportParams.protoFileStation = exportParams.protoFileStation2
		exportParams.portFileStation = exportParams.portFileStation2
	end
	
	-- Get missing settings, if not stored in preset.
	if promptForMissingSettings(exportParams, publishMode) == 'cancel' then
		return false, 'cancel'
	end
	publishMode = iif(publishMode == 'Delete', 'Delete', exportParams.publishMode)
	
	-- ConvertAPI: required if thumb generation is configured
	if exportParams.thumbGenerate then
			exportParams.cHandle = PSConvert.initialize(exportParams.PSUploaderPath)
	end
	
	-- CheckExisting or Delete: Login to FileStation required
	if (publishMode == 'CheckExisting' or publishMode == 'Delete') and not exportParams.useFileStation then
		local errorMsg = string.format("Publish(%s): Login to FileStation required, but not configured!\n", publishMode)
		writeLogfile(1, errorMsg)
		return false, errorMsg
	end

	-- FileStation access is also required for publishing photos that have been moved
	if publishMode ~= 'Export' and exportParams.useFileStation then
		local FileStationUrl = exportParams.protoFileStation .. '://' .. string.gsub(exportParams.servername, ":%d+", "") .. ":" .. exportParams.portFileStation
		local usernameFS = iif(exportParams.differentFSUser, exportParams.usernameFileStation, exportParams.username)
		local passwordFS = iif(exportParams.differentFSUser, exportParams.passwordFileStation, exportParams.password)
		exportParams.fHandle = PSFileStationAPI.initialize(FileStationUrl, 
															iif(exportParams.usePersonalPS, exportParams.personalPSOwner, nil),
															usernameFS)

		writeLogfile(3, "Login to FileStation(user: "  .. usernameFS .. ").\n")
		local result, reason = PSFileStationAPI.login(exportParams.fHandle, usernameFS, passwordFS)
		if not result then
			local errorMsg = string.format('FileStation Login failed!\nReason: %s\n', reason)
			writeLogfile(1, errorMsg)
			return false, errorMsg
		end
		writeLogfile(2, "FileStation Login(" .. FileStationUrl .. ") OK.\n")
	end

	-- Publish or Export: Login to PhotoStation
	if publishMode == 'Publish' or publishMode == 'CheckExisting' or publishMode == 'Export' then
		exportParams.uHandle = PSUploadAPI.initialize(exportParams.serverUrl, 
														iif(exportParams.usePersonalPS, exportParams.personalPSOwner, nil),
														exportParams.serverTimeout)
		local result, reason = PSUploadAPI.login(exportParams.uHandle, exportParams.username, exportParams.password)
		if not result then
			local errorMsg = string.format("Login to %s %s failed!\nReason: %s\n",
									iif(exportParams.usePersonalPS, "Personal PhotoStation of ", "Standard PhotoStation"), 
									iif(exportParams.usePersonalPS and exportParams.personalPSOwner,exportParams.personalPSOwner, ""), reason)
			writeLogfile(1, errorMsg)
			return 	false, errorMsg
					
		end
		writeLogfile(2, "Login to " .. iif(exportParams.usePersonalPS, "Personal PhotoStation of ", "Standard PhotoStation") .. 
								iif(exportParams.usePersonalPS and exportParams.personalPSOwner,exportParams.personalPSOwner, "") .. 
								 "(" .. exportParams.serverUrl .. ") OK\n")
	end

	-- exiftool: required if not Delete and any exif translation was selected
	if publishMode ~= 'Delete' and exportParams.exifTranslate then 
		exportParams.eHandle= PSExiftoolAPI.open(exportParams) 
		return iif(exportParams.eHandle, true, false), "Cannot start exiftool!" 
	end
	
	return true
end

-- closeSession(exportParams, publishMode)
-- logout from PhotoStation and FileStation, if required
function closeSession(exportParams, publishMode)
	writeLogfile(3,"closeSession(" .. publishMode .. "):...\n")

	if  publishMode ~= 'Delete' and exportParams.exifTranslate then 
		PSExiftoolAPI.close(exportParams.eHandle) 
	end
	
	-- CheckExisting or Delete: Logout from FileStation
	if publishMode == 'CheckExisting' or publishMode == 'Delete' then
		if not PSFileStationAPI.logout(exportParams.fHandle) then
			writeLogfile(1,"FileStation Logout failed\n")
			return false
		end
	end
	
	-- Publish or Export: Logout from PhotoStation
	if publishMode == 'Publish' or publishMode == 'CheckExisting' or publishMode == 'Export' then
		if not PSUploadAPI.logout (exportParams.uHandle) then
			writeLogfile(1,"PhotoStation Logout failed\n")
			return false
		end
	end
	writeLogfile(3,"closeSession(" .. publishMode .. ") done.\n")

	return true
end

---------------------- Dialog functions ----------------------------------------------------------

-- promptForMissingSettings(exportParams, publishMode)
-- check for parameters set to "Ask me later" and open a dialog to get values for them
function promptForMissingSettings(exportParams, publishMode)
	local f = LrView.osFactory()
	local bind = LrView.bind
	local share = LrView.share
	local conditionalItem = LrView.conditionalItem
	local needPw = (ifnil(exportParams.password, "") == "")
	local needDstRoot = not exportParams.storeDstRoot
	local needPublishMode = false
	local needLoglevel = false
	local needPwFS = exportParams.LR_isExportForPublish and exportParams.differentFSUser and ifnil(exportParams.passwordFileStation, '') == ''

	if exportParams.LR_isExportForPublish and publishMode ~= 'Delete' and ifnil(exportParams.publishMode, 'Ask') == 'Ask' then
		exportParams.publishMode = 'Publish'
		needPublishMode = true
	end
		
	-- logLevel 9999 means  'Ask me later'
	if exportParams.logLevel == 9999 then
		exportParams.logLevel = 2 			-- Normal
		needLoglevel = true
	end
	
	if not (needPw or needDstRoot or needPublishMode or needLoglevel or needPwFS) then
		return "ok"
	end
	
	local passwdView = f:view {
		f:row {
			f:static_text {
				title = LOC "$$$/PSUpload/ExportDialog/USERNAME=PhotoStation Login:",
				alignment = 'right',
				width = share 'labelWidth',
			},

			f:edit_field {
				value = bind 'username',
				tooltip = LOC "$$$/PSUpload/ExportDialog/USERNAMETT=Enter the username for PhotoStation access.",
				truncation = 'middle',
				immediate = true,
--				width = share 'labelWidth',
				width_in_chars = 16,
				fill_horizontal = 1,
			},
		},
		
		f:spacer {	height = 5, },

		f:row {
			f:static_text {
				title = LOC "$$$/PSUpload/ExportDialog/PASSWORD=PhotoStation Password:",
				alignment = 'right',
				width = share 'labelWidth',
			},

			f:password_field {
				value = bind 'password',
				tooltip = LOC "$$$/PSUpload/ExportDialog/PASSWORDTT=Enter the password for PhotoStation access.",
				truncation = 'middle',
				immediate = true,
				width = share 'labelWidth',
				fill_horizontal = 1,
			},
		},
	}

	local passwdFSView = f:view {
		f:row {
			f:static_text {
				title = LOC "$$$/PSUpload/ExportDialog/USERNAMEFS=FileStation Login:",
				alignment = 'right',
				width = share 'labelWidth',
			},

			f:edit_field {
				value = bind 'usernameFileStation',
				tooltip = LOC "$$$/PSUpload/ExportDialog/USERNAMEFSTT=Enter the username for FileStation access.",
				truncation = 'middle',
				immediate = true,
--				width = share 'labelWidth',
				width_in_chars = 16,
				fill_horizontal = 1,
			},
		},
		
		f:spacer {	height = 5, },

		f:row {
			f:static_text {
				title = LOC "$$$/PSUpload/ExportDialog/PASSWORDFS=FileStation Password:",
				alignment = 'right',
				width = share 'labelWidth',
			},

			f:password_field {
				value = bind 'passwordFileStation',
				tooltip = LOC "$$$/PSUpload/ExportDialog/PASSWORDFSTT=Enter the password for FileStation access.",
				truncation = 'middle',
				immediate = true,
				width = share 'labelWidth',
				fill_horizontal = 1,
			},
		},
	}

	local dstRootView = f:view {
		f:row {
			f:static_text {
				title = LOC "$$$/PSUpload/ExportDialog/DstRoot=Target Album:",
				alignment = 'right',
				width = share 'labelWidth',
			},

			f:edit_field {
				tooltip = LOC "$$$/PSUpload/ExportDialog/DstRootTT=Enter the target directory below the diskstation share '/photo' or '/home/photo'\n(may be different from the Album name shown in PhotoStation)",
				value = bind( "dstRoot" ),
				width_in_chars = 16,
				fill_horizontal = 1,
			},
		}, 
		
		f:spacer {	height = 5, },

		f:row {
			f:checkbox {
				title = LOC "$$$/PSUpload/ExportDialog/createDstRoot=Create Album, if needed",
				alignment = 'left',
				value = bind( "createDstRoot" ),
			},
		},
	}

	local publishModeItems
	
	if exportParams.copyTree then
		publishModeItems = {
			{ title	= 'Normal',																		value 	= 'Publish' },
			{ title	= 'CheckExisting: Set Unpublished to Published if existing in PhotoStation.',	value 	= 'CheckExisting' },
			{ title	= 'CheckMoved: Set Published to Unpublished if moved locally.',					value 	= 'CheckMoved' },
		}
	else
		publishModeItems = {
			{ title	= 'Normal',																		value 	= 'Publish' },
			{ title	= 'CheckExisting: Set Unpublished to Published if existing in PhotoStation.',	value 	= 'CheckExisting' },
		}
	end
	
	local publishModeView = f:view {
		f:row {
			f:static_text {
				title = LOC "$$$/PSUpload/ExportDialog/PublishMode=Publish Mode:",
				alignment = 'right',
				width = share 'labelWidth'
			},
			f:popup_menu {
				tooltip = LOC "$$$/PSUpload/ExportDialog/PublishModeTT=How to publish",
				value = bind 'publishMode',
				alignment = 'left',
				items = publishModeItems,
			},
		},
	}
	
	local loglevelView = f:view {
		f:row {
			f:static_text {
				title = LOC "$$$/PSUpload/ExportDialog/LOGLEVEL=Loglevel:",
				alignment = 'right',
				width = share 'labelWidth'
			},

			f:popup_menu {
				title = LOC "$$$/PSUpload/ExportDialog/LOGLEVEL=Loglevel:",
				tooltip = LOC "$$$/PSUpload/ExportDialog/LOGLEVELTT=The level of log details",
				value = bind 'logLevel',
				fill_horizontal = 0, 
				items = {
					{ title	= 'Nothing',		value 	= 0 },
					{ title	= 'Errors',			value 	= 1 },
					{ title	= 'Normal',			value 	= 2 },
					{ title	= 'Trace',			value 	= 3 },
					{ title	= 'Debug',			value 	= 4 },
				},
			},
		},
	}
	-- Create the contents for the dialog.
	local c = f:view {
		bind_to_object = exportParams,

		conditionalItem(needPw, passwdView), 
		f:spacer {	height = 10, },
		conditionalItem(needPwFS, passwdFSView), 
		f:spacer {	height = 10, },
		conditionalItem(needDstRoot, dstRootView), 
		f:spacer {	height = 10, },
		conditionalItem(needPublishMode, publishModeView), 
		f:spacer {	height = 10, },
		conditionalItem(needLoglevel, loglevelView), 
	}

	local result = LrDialogs.presentModalDialog {
			title = "PhotoStation Upload: enter missing parameters",
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
	
	if ifnil(prefs.updateAvailable, '') ~= '' then
		updateNotice = 'Version ' .. prefs.updateAvailable .. ' available!\n'
		updateAvail = true
	end
	
	writeLogfile(2, message .. '\n')

	if appVersion.major < 5 or msgType == 'critical' then 
		LrDialogs.message(title, message, msgType)
	else
		LrDialogs.showBezel(message, 10)
	end
	
	if updateAvail then
		writeLogfile(2,updateNotice .. '\n')
		if LrDialogs.promptForActionWithDoNotShow( {
				message 		= 'PhotoStation Upload: update available',
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
