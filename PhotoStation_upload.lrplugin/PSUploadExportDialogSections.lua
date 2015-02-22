--[[----------------------------------------------------------------------------

PSUploadExportDialogSections.lua
Export dialog customization for Lightroom PhotoStation Upload
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

This code is derived from the Lr SDK FTP Upload sample code. Copyright: see below
--------------------------------------------------------------------------------

ADOBE SYSTEMS INCORPORATED
 Copyright 2007 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.

------------------------------------------------------------------------------]]

-- Lightroom SDK
local LrView 		= import 'LrView'
local LrPathUtils 	= import 'LrPathUtils'
local LrFileUtils	= import 'LrFileUtils'
local LrShell 		= import 'LrShell'
local progExt = nil			-- .exe for WIN_ENV


--============================================================================--

PSUploadExportDialogSections = {}

-------------------------------------------------------------------------------

-- validateDirectory: check if a given path points to a local directory
local function validateDirectory( view, path )
	local message = nil
	
	if LrFileUtils.exists(path) ~= 'directory' then 
		message = LOC "$$$/PSUpload/ExportDialog/Messages/SrcDirNoExist=Local path is not an existing directory."
		return false, path
	end
	
	return true, LrPathUtils.standardizePath(path)
end

-- validateProgram: check if a given path points to a local program
local function validateProgram( view, path )
	if LrFileUtils.exists(path) ~= 'file'
	or progExt and string.lower(LrPathUtils.extension( path )) ~= progExt then
		return false, path
	end

	return true, LrPathUtils.standardizePath(path)	
end

-- validatePSUploadProgPath: 
--[[	check if a given path points to the root directory of the Synology PhotoStation Uploader tool 
		we require the following converters that ship with the Uploader:
			- ImageMagick/convert(.exe)
			- ffmpeg/ffpmeg(.exe)
			- ffpmpeg/qt-faststart(.exe)
]]
local function validatePSUploadProgPath( view, path )
	local convertprog = 'convert'
	local ffmpegprog = 'ffmpeg'
	local qtfstartprog = 'qt-faststart'
	if progExt then
		convertprog = LrPathUtils.addExtension(convertprog, progExt)
		ffmpegprog = LrPathUtils.addExtension(ffmpegprog, progExt)
		qtfstartprog = LrPathUtils.addExtension(qtfstartprog, progExt)
	end
	
	if LrFileUtils.exists(path) ~= 'directory' 
	or not LrFileUtils.exists(LrPathUtils.child(LrPathUtils.child(path, 'ImageMagick'), convertprog))
	or not LrFileUtils.exists(LrPathUtils.child(LrPathUtils.child(path, 'ffmpeg'), ffmpegprog)) 
	or not LrFileUtils.exists(LrPathUtils.child(LrPathUtils.child(path, 'ffmpeg'), qtfstartprog)) then
		return false, path
	end

	return true, LrPathUtils.standardizePath(path)
end

-------------------------------------------------------------------------------

-- updatExportStatus: do some sanity check on dialog settings
local function updateExportStatus( propertyTable )
	
	local message = nil
	
	repeat
		-- Use a repeat loop to allow easy way to "break" out.
		-- (It only goes through once.)
		
		if not validatePSUploadProgPath(nil, propertyTable.PSUploaderPath) then
			message = LOC "$$$/PSUpload/ExportDialog/Messages/PSUploadPathMissing=Enter the installation path (base) of the Synology PhotoStation Uploader or Synology Assistant"
			break
		end

		if propertyTable.proto ~= "http" and propertyTable.proto ~= "https"  then
			message = LOC "$$$/PSUpload/ExportDialog/Messages/ServenameMissing=Choose http or https"
			break
		end

		if propertyTable.servername == "" or propertyTable.servername == nil  then
			message = LOC "$$$/PSUpload/ExportDialog/Messages/ServernameMissing=Enter a servername"
			break
		end

		if propertyTable.username == "" or propertyTable.username == nil  then
			message = LOC "$$$/PSUpload/ExportDialog/Messages/UsernameMissing=Enter a username"
			break
		end

		if propertyTable.copyTree and not validateDirectory(nil, propertyTable.srcRoot) then
			message = LOC "$$$/PSUpload/ExportDialog/Messages/EnterSubPath=Enter a source path"
			break
		end
				
		if propertyTable.usePersonalPS and (propertyTable.personalPSOwner == "" or propertyTable.personalPSOwner == nil ) then
			message = LOC "$$$/PSUpload/ExportDialog/Messages/EnterPersPSUser=Enter the owner of the Personal PhotoStation to upload to"
			break
		end

		propertyTable.serverUrl = propertyTable.proto .. "://" .. propertyTable.servername
		propertyTable.psUrl = propertyTable.serverUrl .. " --> ".. 
							iif(propertyTable.usePersonalPS,"Personal", "Standard") .. " Album: " .. 
							iif(propertyTable.usePersonalPS and propertyTable.personalPSOwner,propertyTable.personalPSOwner, "") .. ":" ..
							iif(propertyTable.dstRoot, propertyTable.dstRoot, "") 

	until true
	
	if message then
		propertyTable.message = message
		propertyTable.hasError = true
		propertyTable.hasNoError = false
		propertyTable.LR_cantExportBecause = message
	else
		propertyTable.message = nil
		propertyTable.hasError = false
		propertyTable.hasNoError = true
		propertyTable.LR_cantExportBecause = nil
	end
	
end

-------------------------------------------------------------------------------

function PSUploadExportDialogSections.startDialog( propertyTable )
	
	if WIN_ENV  then
		progExt = 'exe'
	end
	
--	propertyTable:addObserver( 'items', updateExportStatus )
	propertyTable:addObserver( 'PSUploaderPath', updateExportStatus )
--	propertyTable:addObserver( 'exiftoolprog', updateExportStatus )
	propertyTable:addObserver( 'proto', updateExportStatus )
	propertyTable:addObserver( 'servername', updateExportStatus )
	propertyTable:addObserver( 'username', updateExportStatus )
	propertyTable:addObserver( 'srcRoot', updateExportStatus )
	propertyTable:addObserver( 'copyTree', updateExportStatus )
	propertyTable:addObserver( 'usePersonalPS', updateExportStatus )
	propertyTable:addObserver( 'personalPSOwner', updateExportStatus )
--	propertyTable:addObserver( 'logLevelStr', updateExportStatus )

	updateExportStatus( propertyTable )
	
end

-------------------------------------------------------------------------------

-- function PSUploadExportDialogSections.sectionsForBottomOfDialog( _, propertyTable )
function PSUploadExportDialogSections.sectionsForBottomOfDialog( f, propertyTable )

--	local f = LrView.osFactory()
	local bind = LrView.bind
	local share = LrView.share

	local result = {
	
		{
			title = LOC "$$$/PSUpload/ExportDialog/PsSettings=PhotoStation Server",
			
			synopsis = bind { key = 'psUrl', object = propertyTable },

			f:row {
				f:static_text {
					title = LOC "$$$/PSUpload/ExportDialog/PSUPLOAD=Syno PhotoStation Uploader:",
					alignment = 'right',
					width = share 'labelWidth'
				},
	
				f:edit_field {
					value = bind 'PSUploaderPath',
					tooltip = LOC "$$$/PSUpload/ExportDialog/PSUPLOADTT=Enter the installation path of the Synology PhotoStation Uploader or the Snology Assistant",
					truncation = 'middle',
					validate = validatePSUploadProgPath,
					immediate = true,
					fill_horizontal = 1,
				},
			},

--[[ this may become important in future version, since exiftool gives access to some metadata that Lr won't give
		f:row {
				f:static_text {
					title = LOC "$$$/PSUpload/ExportDialog/EXIFTOOL=ExifTool program:",
					alignment = 'right',
					width = share 'labelWidth'
				},
	
				f:edit_field {
					value = bind 'exiftoolprog',
					truncation = 'middle',
					validate = validateProgram,
					immediate = true,
					fill_horizontal = 1,
				},

		},
]]
			f:row {
				f:static_text {
					title = LOC "$$$/PSUpload/ExportDialog/SERVERNAME=Server:",
					alignment = 'right',
					width = share 'labelWidth'
				},
	
				f:popup_menu {
					title = LOC "$$$/PSUpload/ExportDialog/PROTOCOL=Protocol:",
					value = bind 'proto',
					items = {
						{ title	= 'http',   value 	= 'http' },
						{ title	= 'https',	value 	= 'https' },
					},
				},

				f:edit_field {
					tooltip = LOC "$$$/PSUpload/ExportDialog/SERVERNAMETT=Enter the IP Address or Hostname of the PhotoStation.\nNon-standard ports may be appended as :port",
					value = bind 'servername',
					truncation = 'middle',
					width = share 'labelWidth',
					immediate = true,
					fill_horizontal = 1,
				},

			},

			f:row {
				f:static_text {
					title = LOC "$$$/PSUpload/ExportDialog/USERNAME=Login as:",
					alignment = 'right',
					width = share 'labelWidth'
				},
	
				f:edit_field {
					value = bind 'username',
					truncation = 'middle',
					immediate = true,
					fill_horizontal = 1,
				},

				f:static_text {
					title = LOC "$$$/PSUpload/ExportDialog/PASSWORD=Password:",
					alignment = 'right',
				},
	
				f:password_field {
					value = bind 'password',
					tooltip = LOC "$$$/PSUpload/ExportDialog/PASSWORDTT=Leave this field blank, if you don't want to store the password.\nYou will be prompted for the password later.",
					truncation = 'middle',
					immediate = true,
					fill_horizontal = 1,
				},

			},

			f:group_box {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/TargetPS=Target PhotoStation",

				f:row {
					f:radio_button {
						title = LOC "$$$/PSUpload/ExportDialog/PersonalPS=Standard PhotoStation",
						alignment = 'left',
						width = share 'labelWidth',
						value = bind 'usePersonalPS',
						checked_value = false,
					},

					f:radio_button {
						title = LOC "$$$/PSUpload/ExportDialog/PersonalPS=Personal PhotoStation of User:",
						alignment = 'left',
						value = bind 'usePersonalPS',
						checked_value = true,
					},

					f:edit_field {
						tooltip = LOC "$$$/PSUpload/ExportDialog/PersonalPSTT=Enter the name of the owner of the Personal PhotoStation you want to upload to.",
						value = bind 'personalPSOwner',
						enabled = bind 'usePersonalPS',
						visible = bind 'usePersonalPS',
						truncation = 'middle',
						immediate = true,
						fill_horizontal = 1,
					},
				},
			},
			
			f:row {
				f:checkbox {
					title = LOC "$$$/PSUpload/ExportDialog/StoreDstRoot=Enter Target Album:",
					tooltip = LOC "$$$/PSUpload/ExportDialog/StoreDstRootTT=Enter Target Album here or you will be prompted for it when the upload starts.",
					alignment = 'right',
					width = share 'labelWidth',
					value = bind 'storeDstRoot',
				},

				f:edit_field {
					tooltip = LOC "$$$/PSUpload/ExportDialog/DstRootTT=Enter the target directory below the diskstation share '/photo' or '/home/photo'\n(may be different from the Album name shown in PhotoStation)",
					value = bind 'dstRoot',
					truncation = 'middle',
					enabled = bind 'storeDstRoot',
					visible = bind 'storeDstRoot',
					immediate = true,
					fill_horizontal = 1,
				},

				f:checkbox {
					title = LOC "$$$/PSUpload/ExportDialog/createDstRoot=Create Album, if needed",
					alignment = 'left',
					width = share 'labelWidth',
					value = bind 'createDstRoot',
					enabled = bind 'storeDstRoot',
					visible = bind 'storeDstRoot',
					fill_horizontal = 1,
				},
			},
			
			f:group_box {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/UploadMethod=Upload Method",

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
						tooltip = LOC "$$$/PSUpload/ExportDialog/CopyTreeTT=Enter the local Path that is the root of the directory tree you want to mirror below the Target Album.",
						enabled = bind 'copyTree',
						visible = bind 'copyTree',
						validate = validateDirectory,
						truncation = 'middle',
						immediate = true,
						fill_horizontal = 1,
					},
				},
			},
			
			f:group_box {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/Thumbnails=Thumbnail Options",

				f:row {
					f:checkbox {
						fill_horizontal = 1,
						title = LOC "$$$/PSUpload/ExportDialog/isPS6=Optimize for PhotoStation 6",
						tooltip = LOC "$$$/PSUpload/ExportDialog/isPS6TT=Do not generate and upload Thumb_L",
						value = bind 'isPS6',
					},

					f:row {
						fill_horizontal = 1,
						f:radio_button {
							title = LOC "$$$/PSUpload/ExportDialog/SmallThumbs=Small Thumbs",
							tooltip = LOC "$$$/PSUpload/ExportDialog/SmallThumbsTT=Recommended for output on low-resolution monitors",
							alignment = 'left',
							fill_horizontal = 1,
							value = bind 'largeThumbs',
							checked_value = false,
						},

						f:radio_button {
							title = LOC "$$$/PSUpload/ExportDialog/LargeThumbs=Large Thumbs",
							tooltip = LOC "$$$/PSUpload/ExportDialog/LargeThumbsTT=Recommended for output on Full HD monitors",
							alignment = 'right',
							fill_horizontal = 1,
							value = bind 'largeThumbs',
							checked_value = true,
						},
					},
					
					f:row {
						alignment = 'right',
						fill_horizontal = 1,

						f:static_text {
							title = LOC "$$$/PSUpload/ExportDialog/ThumbQuality=Quality:",
							alignment = 'right',
						},

						f:popup_menu {
							tooltip = LOC "$$$/PSUpload/ExportDialog/QualityTT=Thumb conversion quality, recommended value: 80%",
							value = bind 'thumbQuality',
							alignment = 'left',
							fill_horizontal = 1,
							items = {
								{ title	= '10%',	value 	= 10 },
								{ title	= '20%',	value 	= 20 },
								{ title	= '30%',	value 	= 30 },
								{ title	= '40%',	value 	= 40 },
								{ title	= '50%',	value 	= 50 },
								{ title	= '60%',	value 	= 60 },
								{ title	= '70%',	value 	= 70 },
								{ title	= '80%',	value 	= 80 },
								{ title	= '90%',	value 	= 90 },
								{ title	= '100%',	value 	= 100 },
							},
						},
					},

				},
			},

			f:group_box {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/Videos=Upload additional video resolutions for...",

				f:row {
					f:row {
						alignment = 'left',
						fill_horizontal = 1,

						f:static_text {
							title = LOC "$$$/PSUpload/ExportDialog/VideoHigh=High-Res Videos:",
							alignment = 'right',
						},
						f:popup_menu {
							tooltip = LOC "$$$/PSUpload/ExportDialog/VideoHighTT=Generate additional video for Hi-Res (1080p) videos",
							value = bind 'addVideoHigh',
							alignment = 'left',
							fill_horizontal = 1,
							items = {
								{ title	= 'None',			value 	= 'None' },
								{ title	= 'Mobile (240p)',	value 	= 'MOBILE' },
								{ title	= 'Low (360p)',		value 	= 'LOW' },
								{ title	= 'Medium (720p)',	value 	= 'MEDIUM' },
							},
						},
					},					

					f:row {
						alignment = 'right',
						fill_horizontal = 1,

						f:static_text {
							title = LOC "$$$/PSUpload/ExportDialog/VideoMed=Medium-Res Videos:",
							alignment = 'right',
						},
						f:popup_menu {
							tooltip = LOC "$$$/PSUpload/ExportDialog/VideoMedTT=Generate additional video for Medium-Res (720p) videos",
							value = bind 'addVideoMed',
							alignment = 'left',
							fill_horizontal = 1,
							items = {
								{ title	= 'None',			value 	= 'None' },
								{ title	= 'Mobile (240p)',	value 	= 'MOBILE' },
								{ title	= 'Low (360p)',		value 	= 'LOW' },
							},
						},
					},					

					f:row {
						alignment = 'right',
						fill_horizontal = 1,

						f:static_text {
							title = LOC "$$$/PSUpload/ExportDialog/VideoLow=Low-Res Videos:",
							alignment = 'right',
						},
						f:popup_menu {
							tooltip = LOC "$$$/PSUpload/ExportDialog/VideoLowTT=Generate additional video for Low-Res (360p) videos",
							value = bind 'addVideoLow',
							alignment = 'left',
							fill_horizontal = 1,
							items = {
								{ title	= 'None',			value 	= 'None' },
								{ title	= 'Mobile (240p)',	value 	= 'MOBILE' },
							},
						},
					},					
				},
			},

			f:row {
				f:static_text {
					title = LOC "$$$/PSUpload/ExportDialog/LOGLEVEL=Loglevel:",
					alignment = 'right',
					width = share 'labelWidth'
				},
	
				f:popup_menu {
					title = LOC "$$$/PSUpload/ExportDialog/LOGLEVEL=Loglevel:",
					value = bind 'logLevel',
					fill_horizontal = 0, 
					items = {
						{ title	= 'Nothing',value 	= 0 },
						{ title	= 'Errors',	value 	= 1 },
						{ title	= 'Normal',	value 	= 2 },
						{ title	= 'Trace',	value 	= 3 },
						{ title	= 'Debug',	value 	= 4 },
					},
				},
				
				f:spacer {
					fill_horizontal = 1
				},
				
				f:push_button {
					title = LOC "$$$/PSUpload/ExportDialog/Logfile=Goto Logfile of last Export",
					alignment = 'right',
					action = function()
						LrShell.revealInShell(LrPathUtils.child(LrPathUtils.getStandardFilePath("temp"), "PhotoStationUpload.log"))
					end,
				},
			}, 
			
			f:column {
				place = 'overlapping',
				fill_horizontal = 1,
				
				f:row {
					f:static_text {
						fill_horizontal = 1,
						title = bind 'message',
						visible = bind 'hasError',
					},
				},
			},
		},
	}
	
	return result
	
end
