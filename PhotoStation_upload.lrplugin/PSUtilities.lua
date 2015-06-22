--[[----------------------------------------------------------------------------

PSUtiliites.lua
Utilities for Lightroom PhotoStation Upload
Copyright(c) 2015, Martin Messmer

useful functions:
	- ifnil
	- iif
	- mkSaveFilename
	
	- openLogfile
	- writeLogfile
	-  closeLogfile
	
	- initializeEnv
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
-- local LrFileUtils 	= import 'LrFileUtils'
local LrHttp	 		= import 'LrHttp'
local LrPathUtils 		= import 'LrPathUtils'
-- local LrProgressScope = import 'LrProgressScope'
-- local LrShell 		= import 'LrShell'
local LrPrefs	 		= import 'LrPrefs'
local LrView 			= import 'LrView'

--============================================================================--

local tmpdir = LrPathUtils.getStandardFilePath("temp")

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

----------------------- logging ---------------------------------------------------------
-- had some issues with LrLogger in cojunction with LrTasks, so we do our own file logging

-- we can store some variables in 'global' local variables safely:
-- each export task will get its own copy of these variables
local tmpdir = LrPathUtils.getStandardFilePath("temp")

local logfilename
local loglevel
--[[loglevel:
	0 -	nothing
	1 - errors
	2 - info
	3 - tracing
	4 - debug
]]	

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

	if logfilename then return end
	
	-- if logfilename not yet set: truncate any existing previous logfile
	logfilename = LrPathUtils.child(tmpdir, "PhotoStationUpload.log")
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

-- closeLogfile: write the end timestamp and time consumed
function closeLogfile()
	local logfile = io.open(logfilename, "a")
	local now = LrDate.currentTime()
	io.close (logfile)
end

---------------------- filename encoding routines ---------------------------------------------------------

function mkSaveFilename(str)
	if (str) then
		-- substitute blanks, '(' and ')' by '-'
		str = string.gsub (str, "[%s%(%)]", "-") 
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

---------------------- session environment ----------------------------------------------------------

-- initialzeEnv (exportParams) ---------------
-- initialize PhotoStation-API, FileStation API and Convert
function initializeEnv (exportParams)
	writeLogfile(2, "initializeEnv starting:\n")
	local FileStationUrl = exportParams.protoFileStation .. '://' .. string.gsub(exportParams.servername, ":%d+", "") .. ":" .. exportParams.portFileStation

	return (PSUploadAPI.initialize(exportParams.serverUrl, iif(exportParams.usePersonalPS, exportParams.personalPSOwner, nil)) and 
			PSFileStationAPI.initialize(FileStationUrl, iif(exportParams.usePersonalPS, exportParams.personalPSOwner, nil),
										iif(exportParams.differentFSUser, exportParams.usernameFileStation, exportParams.username)) and 
			PSConvert.initialize(exportParams.PSUploaderPath))
end

-- copyCollectionSettingsToExportParams(collectionSettings, exportParams)
-- copy temporarily the collections settings to exportParams, so that we can work solely with exportParams  
function copyCollectionSettingsToExportParams(collectionSettings, exportParams)
	exportParams.storeDstRoot 	= true
	exportParams.dstRoot 		= collectionSettings.dstRoot
	exportParams.createDstRoot 	= collectionSettings.createDstRoot
	exportParams.copyTree 		= collectionSettings.copyTree
	exportParams.srcRoot 		= collectionSettings.srcRoot
	exportParams.publishMode 	= collectionSettings.publishMode
end

-- openSession(exportParams, publishMode)
-- login to PhotoStation and FileStation, if required
function openSession(exportParams, publishMode)
	-- if "use secondary server was choosen, temporarily overwrite primary address
	if exportParams.useSecondAddress then
		exportParams.proto = exportParams.proto2
		exportParams.servername = exportParams.servername2
		exportParams.serverUrl = exportParams.proto .. "://" .. exportParams.servername
		exportParams.protoFileStation = exportParams.protoFileStation2
		exportParams.portFileStation = exportParams.portFileStation2
	end
	
	-- generate global environment settings
	if not initializeEnv (exportParams) then
		writeLogfile(2, "openSession: cannot initialize environment!\n" )
		return false
	end

	-- Get missing settings, if not stored in preset.
	if promptForMissingSettings(exportParams, publishMode) == 'cancel' then
		return false
	end
	publishMode = exportParams.publishMode
	
	-- Publish or Delete: Login to FileStation
	if publishMode == 'Publish' or publishMode == 'CheckExisting' or publishMode == 'Delete' then
		local FileStationUrl = exportParams.protoFileStation .. '://' .. string.gsub(exportParams.servername, ":%d+", "") .. ":" .. exportParams.portFileStation
		local usernameFS = iif(exportParams.differentFSUser, exportParams.usernameFileStation, exportParams.username)
		local passwordFS = iif(exportParams.differentFSUser, exportParams.passwordFileStation, exportParams.password)

		writeLogfile(3, "Login to FileStation(user: "  .. usernameFS .. ").\n")
		local result, reason = PSFileStationAPI.login(usernameFS, passwordFS)
		if not result then
			writeLogfile(1, "FileStation Login (" .. FileStationUrl .. ") failed, reason:" .. reason .. "\n")
			closeLogfile()
			LrDialogs.message( LOC "$$$/PSUpload/Upload/Errors/FSLoginError= FileStation Login failed", reason)
			return false
		end
		writeLogfile(2, "FileStation Login(" .. FileStationUrl .. ") OK.\n")
	end

	-- Publish or Export: Login to PhotoStation
	if publishMode == 'Publish' or publishMode == 'CheckExisting' or publishMode == 'Export' then
		local result, reason = PSUploadAPI.login(exportParams.username, exportParams.password)
		if not result then
			writeLogfile(1, "PhotoStation Login (" .. exportParams.serverUrl .. ") failed, reason:" .. reason .. "\n")
			closeLogfile()
			LrDialogs.message( LOC "$$$/PSUpload/Upload/Errors/LoginError=Login to " .. 
								iif(exportParams.usePersonalPS, "Personal PhotoStation of ", "Standard PhotoStation") .. 
								iif(exportParams.usePersonalPS and exportParams.personalPSOwner,exportParams.personalPSOwner, "") .. " failed.", reason)
			return false 
		end
		writeLogfile(2, "Login to " .. iif(exportParams.usePersonalPS, "Personal PhotoStation of ", "Standard PhotoStation") .. 
								iif(exportParams.usePersonalPS and exportParams.personalPSOwner,exportParams.personalPSOwner, "") .. 
								 "(" .. exportParams.serverUrl .. ") OK\n")
	end

	return true
end

-- closeSession(exportParams, publishMode)
-- logout from PhotoStation and FileStation, if required
function closeSession(exportParams, publishMode)
	writeLogfile(3,"closeSession(" .. publishMode .. "):...\n")

	-- Publish or Delete: Logout from FileStation
	if publishMode == 'Publish' or publishMode == 'CheckExisting' or publishMode == 'Delete' then
		if not PSFileStationAPI.logout() then
			writeLogfile(1,"FileStation Logout failed\n")
			return false
		end
	end
	
	-- Publish or Export: Logout from PhotoStation
	if publishMode == 'Publish' or publishMode == 'CheckExisting' or publishMode == 'Export' then
		if not PSUploadAPI.logout () then
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
	
	writeLogfile(2,message .. '\n')

	if appVersion.major < 5 then 
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
