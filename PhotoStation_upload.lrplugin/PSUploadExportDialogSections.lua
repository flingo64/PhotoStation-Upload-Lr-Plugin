--[[----------------------------------------------------------------------------

PSDialogs.lua
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

PhotoStation Upload uses the following free software to do its job:
	- convert.exe,			see: http://www.imagemagick.org/
	- ffmpeg.exe, 			see: https://www.ffmpeg.org/
	- qt-faststart.exe, 	see: http://multimedia.cx/eggs/improving-qt-faststart/

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
local LrBinding		= import 'LrBinding'
local LrView 		= import 'LrView'
local LrPathUtils 	= import 'LrPathUtils'
local LrFileUtils	= import 'LrFileUtils'
local LrShell 		= import 'LrShell'

require "PSUtilities"
require "PSDialogs"

--============================================================================--

PSUploadExportDialogSections = {}

-------------------------------------------------------------------------------

-- validatePort: check if a string is numeric
local function validatePort( view, value )
	local message = nil
	
	if string.match(value, '(%d+)') ~= value then 
		message = LOC "$$$/PSUpload/ExportDialog/Messages/PortNotNumeric=Port must be numeric value."
		return false, value
	end
	
	return true, value
end

-- validateDirectory: check if a given path points to a local directory
function validateDirectory( view, path )
	local message = nil
	
	if LrFileUtils.exists(path) ~= 'directory' then 
		message = LOC "$$$/PSUpload/ExportDialog/Messages/SrcDirNoExist=Local path is not an existing directory."
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
	if getProgExt() then
		local progExt = getProgExt()
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
		
		if propertyTable.thumbGenerate and not validatePSUploadProgPath(nil, propertyTable.PSUploaderPath) then
			message = LOC "$$$/PSUpload/ExportDialog/Messages/PSUploadPathMissing=Enter the installation path (base) of the Synology PhotoStation Uploader or Synology Assistant"
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

		-- Check file format: PSD not supported by PhotoStation, DNG only supported w/ embedded full-size jpg preview
		if (propertyTable.LR_format == 'PSD') or  (propertyTable.LR_format == 'DNG' and ifnil(propertyTable.LR_DNG_previewSize, '') ~= 'large') then
			message = LOC "$$$/PSUpload/ExportDialog/Messages/FileFormatNoSupp=File format not supported! Select: [JPEG], [TIFF], [DNG w/ full-size JPEG preview] or [Original]."
			break
		end

		-- Publish Servic Provider start

		if propertyTable.LR_isExportForPublish and propertyTable.LR_renamingTokensOn then
			message = LOC "$$$/PSUpload/ExportDialog/Messages/RenameNoSupp= File renaming option not supported in Publish mode!"
			break
		end

		if propertyTable.useSecondAddress and ifnil(propertyTable.servername2, "") == "" then
			message = LOC "$$$/PSUpload/ExportDialog/Messages/Servername2Missing=Enter a secondary servername"
			break
		end

		-- Publish Service Provider end

		-- Exif translation start
		if propertyTable.exifTranslate and not PSDialogs.validateProgram( _, propertyTable.exiftoolprog ) then
			message = LOC "$$$/PSUpload/ExportDialog/Messages/EnterExiftool=Enter path to exiftool"
			break
		end
		-- Exif translation end

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
	
	propertyTable:addObserver( 'thumbGenerate', updateExportStatus )
	propertyTable:addObserver( 'PSUploaderPath', updateExportStatus )

	propertyTable:addObserver( 'servername', updateExportStatus )
	propertyTable:addObserver( 'username', updateExportStatus )
	propertyTable:addObserver( 'srcRoot', updateExportStatus )
	propertyTable:addObserver( 'copyTree', updateExportStatus )
	propertyTable:addObserver( 'usePersonalPS', updateExportStatus )
	propertyTable:addObserver( 'personalPSOwner', updateExportStatus )

	propertyTable:addObserver( 'exiftoolprog', updateExportStatus )
	propertyTable:addObserver( 'exifTranslate', updateExportStatus )

	propertyTable:addObserver( 'useSecondAddress', updateExportStatus )
	propertyTable:addObserver( 'servername2', updateExportStatus )

	propertyTable:addObserver( 'LR_renamingTokensOn', updateExportStatus )
	
	propertyTable:addObserver( 'LR_format', updateExportStatus )
	propertyTable:addObserver( 'LR_DNG_previewSize', updateExportStatus )

	updateExportStatus( propertyTable )
	
end

-------------------------------------------------------------------------------
-- function PSUploadExportDialogSections.sectionsForBottomOfDialog( _, propertyTable )
function PSUploadExportDialogSections.sectionsForBottomOfDialog( f, propertyTable )

--	local f = LrView.osFactory()
	local bind = LrView.bind
	local share = LrView.share
	local conditionalItem = LrView.conditionalItem
	
	if propertyTable.isCollection == nil then
		propertyTable.isCollection = false
	end
	
	-- config section for Export or Publish dialog
	local result = {
	
		{
			title = LOC "$$$/PSUpload/ExportDialog/PsSettings=PhotoStation Server",
			
			synopsis = bind { key = 'psUrl', object = propertyTable },

			-- ================== Target PhotoStation =================================================================

			f:group_box {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/TargetPS=Target PhotoStation",

				f:row {
        			f:radio_button {
        				title = LOC "$$$/PSUpload/ExportDialog/SERVERNAME=Server Address:",
        				alignment = 'right',
        				width = share 'labelWidth',
        				value = bind 'useSecondAddress',
        				checked_value = false,
        			},

					f:popup_menu {
						title = LOC "$$$/PSUpload/ExportDialog/PROTOCOL=Protocol:",
						value = bind 'proto',
						enabled =  LrBinding.negativeOfKey('useSecondAddress'),
						items = {
							{ title	= 'http',   value 	= 'http' },
							{ title	= 'https',	value 	= 'https' },
						},
					},

					f:edit_field {
						tooltip = LOC "$$$/PSUpload/ExportDialog/SERVERNAMETT=Enter the IP address or hostname of the PhotoStation.\nNon-standard port may be appended as :port",
						value = bind 'servername',
						enabled =  LrBinding.negativeOfKey('useSecondAddress'),
						truncation = 'middle',
						immediate = true,
						fill_horizontal = 1,
					},

        			f:row {
        				alignment = 'right',
        				fill_horizontal = 0.5,
        
        				f:static_text {
        					title = LOC "$$$/PSUpload/ExportDialog/ServerTimeout=Timeout:",
        					alignment = 'right',
        				},
        
        				f:popup_menu {
        					tooltip = LOC "$$$/PSUpload/ExportDialog/ServerTimeoutTT=HTTP(S) connect timeout, recommended value: 10s\nuse higher value (>= 40s), if you experience problems due to disks in standby mode",
        					value = bind 'serverTimeout',
							enabled =  LrBinding.negativeOfKey('useSecondAddress'),
        					alignment = 'left',
        					fill_horizontal = 1,
        					items = {
        						{ title	= '10s',	value 	= 10 },
        						{ title	= '20s',	value 	= 20 },
        						{ title	= '30s',	value 	= 30 },
        						{ title	= '40s',	value 	= 40 },
        						{ title	= '50s',	value 	= 50 },
        						{ title	= '60s',	value 	= 60 },
        						{ title	= '70s',	value 	= 70 },
        						{ title	= '80s',	value 	= 80 },
        						{ title	= '90s',	value 	= 90 },
        						{ title	= '100s',	value 	= 100 },
        					},
        				},
        			},
        		}, 
        		
        		f:row {
        			f:radio_button {
        				title = LOC "$$$/PSUpload/ExportDialog/SERVERNAME2=Second Server Address:",
        				alignment = 'right',
        				width = share 'labelWidth',
        				value = bind 'useSecondAddress',
        				checked_value = true,
        			},
        
        			f:popup_menu {
        				title = LOC "$$$/PSUpload/ExportDialog/PROTOCOL2=Protocol:",
        				value = bind 'proto2',
        				enabled = bind 'useSecondAddress',
        				items = {
        					{ title	= 'http',   value 	= 'http' },
        					{ title	= 'https',	value 	= 'https' },
        				},
        			},
        
        			f:edit_field {
        				tooltip = LOC "$$$/PSUpload/ExportDialog/SERVERNAME2TT=Enter the secondary IP address or hostname.\nNon-standard port may be appended as :port",
        				value = bind 'servername2',
        				truncation = 'middle',
        				enabled = bind 'useSecondAddress',
        				immediate = true,
        				fill_horizontal = 1,
        			},
        
        			f:row {
        				alignment = 'right',
        				fill_horizontal = 0.5,
        
        				f:static_text {
        					title = LOC "$$$/PSUpload/ExportDialog/ServerTimeout=Timeout:",
        					alignment = 'right',
        				},
        
        				f:popup_menu {
        				tooltip = LOC "$$$/PSUpload/ExportDialog/ServerTimeoutTT=HTTP(S) connect timeout, recommended value: 10s\nuse higher value (>= 40s), if you experience problems due to disks in standby mode",
        					value = bind 'serverTimeout2',
        					enabled = bind 'useSecondAddress',
        					alignment = 'left',
        					fill_horizontal = 1,
        					items = {
        						{ title	= '10s',	value 	= 10 },
        						{ title	= '20s',	value 	= 20 },
        						{ title	= '30s',	value 	= 30 },
        						{ title	= '40s',	value 	= 40 },
        						{ title	= '50s',	value 	= 50 },
        						{ title	= '60s',	value 	= 60 },
        						{ title	= '70s',	value 	= 70 },
        						{ title	= '80s',	value 	= 80 },
        						{ title	= '90s',	value 	= 90 },
        						{ title	= '100s',	value 	= 100 },
        					},
        				},
        			},
        		},

				f:separator { fill_horizontal = 1 },

				f:row {
					f:radio_button {
						title = LOC "$$$/PSUpload/ExportDialog/StandardPS=Standard PhotoStation",
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

				f:row {
					f:static_text {
						title = LOC "$$$/PSUpload/ExportDialog/USERNAME=PhotoStation Login:",
						alignment = 'right',
						width = share 'labelWidth'
					},
		
					f:edit_field {
						value = bind 'username',
						tooltip = LOC "$$$/PSUpload/ExportDialog/USERNAMETT=Enter the username for PhotoStation access.",
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
						tooltip = LOC "$$$/PSUpload/ExportDialog/PASSWORDTT=Enter the password for PhotoStation access.\nLeave this field blank, if you don't want to store the password.\nYou will be prompted for the password later.",
						truncation = 'middle',
						immediate = true,
						fill_horizontal = 1,
					},
				},
			},
			
			-- ================== Target Album and Upload Method ===============================================
			
			conditionalItem(not propertyTable.LR_isExportForPublish, PSDialogs.targetAlbumView(f, propertyTable)),
			
			-- ================== Thumbnail Options ================================================

			f:group_box {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/Thumbnails=Thumbnail Options",

				f:row {
					f:checkbox {
						fill_horizontal = 1,
						title = LOC "$$$/PSUpload/ExportDialog/thumbGenerate=Do thumbs:",
						tooltip = LOC "$$$/PSUpload/ExportDialog/thumbGenerateTT=Generate thumbs:\nUnselect only, if you want the diskstation to generate the thumbs\n" .. 
										"or if you export to an unindexed folder and you don't need thumbs.\n" .. 
										"This will speed up export.",
						value = bind 'thumbGenerate',
					},

					f:checkbox {
						fill_horizontal = 1,
						title = LOC "$$$/PSUpload/ExportDialog/isPS6=For PS 6",
						tooltip = LOC "$$$/PSUpload/ExportDialog/isPS6TT=PhotoStation 6: Do not generate and upload Thumb_L",
						value = bind 'isPS6',
						visible = bind 'thumbGenerate',
					},

					f:row {
						fill_horizontal = 1,

						f:radio_button {
							title = LOC "$$$/PSUpload/ExportDialog/SmallThumbs=Small",
							tooltip = LOC "$$$/PSUpload/ExportDialog/SmallThumbsTT=Recommended for output on low-resolution monitors",
							alignment = 'left',
							fill_horizontal = 1,
							value = bind 'largeThumbs',
							visible = bind 'thumbGenerate',
							checked_value = false,
						},

						f:radio_button {
							title = LOC "$$$/PSUpload/ExportDialog/LargeThumbs=Large",
							tooltip = LOC "$$$/PSUpload/ExportDialog/LargeThumbsTT=Recommended for output on Full HD monitors",
							alignment = 'right',
							fill_horizontal = 1,
							value = bind 'largeThumbs',
							visible = bind 'thumbGenerate',
							checked_value = true,
						},
					},
					
					f:row {
						alignment = 'right',
						fill_horizontal = 1,

						f:static_text {
							title = LOC "$$$/PSUpload/ExportDialog/ThumbQuality=Quality:",
							alignment = 'right',
							visible = bind 'thumbGenerate',
						},

						f:popup_menu {
							tooltip = LOC "$$$/PSUpload/ExportDialog/QualityTT=Thumb conversion quality, recommended value: 80%",
							value = bind 'thumbQuality',
							alignment = 'left',
							fill_horizontal = 1,
							visible = bind 'thumbGenerate',
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

					f:row {
						alignment = 'right',
						fill_horizontal = 1,

						f:static_text {
							title = LOC "$$$/PSUpload/ExportDialog/ThumbSharpness=Sharpening:",
							alignment = 'right',
							visible = bind 'thumbGenerate',
						},

						f:popup_menu {
							tooltip = LOC "$$$/PSUpload/ExportDialog/ThumbSharpnessTT=Thumbnail sharpening, recommended value: Medium",
							value = bind 'thumbSharpness',
							alignment = 'left',
							fill_horizontal = 1,
							visible = bind 'thumbGenerate',
							items = {
								{ title	= 'None',	value 	= 'None' },
								{ title	= 'Low',	value 	= 'LOW' },
								{ title	= 'Medium',	value 	= 'MED' },
								{ title	= 'High',	value 	= 'HIGH' },
							},
						},
					},
				},

    			f:row {
    				f:static_text {
    					title = LOC "$$$/PSUpload/ExportDialog/PSUPLOAD=Synology PS Uploader:",
    					alignment = 'right',
						visible = bind 'thumbGenerate',
    					width = share 'labelWidth'
    				},
    	
    				f:edit_field {
    					value = bind 'PSUploaderPath',
    					tooltip = LOC "$$$/PSUpload/ExportDialog/PSUPLOADTT=Enter the installation path of the Synology PhotoStation Uploader.",
    					truncation = 'middle',
						visible = bind 'thumbGenerate',
    					validate = validatePSUploadProgPath,
    					immediate = true,
    					fill_horizontal = 1,
    				},
    			},

			},

			-- ================== Video Options =================================================================

			f:group_box {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/Videos=Video Upload Options: Additional video resolutions for ...-Res Videos",

				f:row {
					f:row {
						alignment = 'left',
						fill_horizontal = 1,

						f:static_text {
							title = LOC "$$$/PSUpload/ExportDialog/VideoHigh=High:",
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
							title = LOC "$$$/PSUpload/ExportDialog/VideoMed=Medium:",
							alignment = 'right',
						},
						f:popup_menu {
							tooltip = LOC "$$$/PSUpload/ExportDialog/VideoMedTT=Generate additional video for Medium-Res (720p) videos",
							value = bind 'addVideoMed',
							alignment = 'left',
							fill_horizontal = 1,
							items = {
								{ title	= 'None',		value 	= 'None' },
								{ title	= 'Mobile',		value 	= 'MOBILE' },
								{ title	= 'Low',		value 	= 'LOW' },
							},
						},
					},					

					f:row {
						alignment = 'right',
						fill_horizontal = 1,

						f:static_text {
							title = LOC "$$$/PSUpload/ExportDialog/VideoLow=Low:",
							alignment = 'right',
						},
						f:popup_menu {
							tooltip = LOC "$$$/PSUpload/ExportDialog/VideoLowTT=Generate additional video for Low-Res (360p) videos",
							value = bind 'addVideoLow',
							alignment = 'left',
							fill_horizontal = 1,
							items = {
								{ title	= 'None',		value 	= 'None' },
								{ title	= 'Mobile',		value 	= 'MOBILE' },
							},
						},
					},					
					
					f:checkbox {
						title = LOC "$$$/PSUpload/ExportDialog/hardRotate=Use hard-rotation",
						tooltip = LOC "$$$/PSUpload/ExportDialog/hardRotateTT=Use hard-rotation for better player compatibility,\nwhen a video is soft-rotated or meta-rotated\n(keywords include: 'Rotate-90', 'Rotate-180' or 'Rotate-270')",
						alignment = 'left',
						value = bind 'hardRotate',
						fill_horizontal = 1,
					},
				},
			},

            -- ================== Upload Options ============================================================
            
            conditionalItem(not propertyTable.LR_isExportForPublish, PSDialogs.UploadOptionsView(f, propertyTable)),

			-- ================== Log Options =================================================================

			f:row {
				f:static_text {
					title = LOC "$$$/PSUpload/ExportDialog/LOGLEVEL=Loglevel:",
					alignment = 'right',
--					width = share 'labelWidth'
				},
	
				f:popup_menu {
					title = LOC "$$$/PSUpload/ExportDialog/LOGLEVEL=Loglevel:",
					tooltip = LOC "$$$/PSUpload/ExportDialog/LOGLEVELTT=The level of log details",
					value = bind 'logLevel',
					fill_horizontal = 0, 
					items = {
						{ title	= 'Ask me later',	value 	= 9999 },
						{ title	= 'Nothing',		value 	= 0 },
						{ title	= 'Errors',			value 	= 1 },
						{ title	= 'Normal',			value 	= 2 },
						{ title	= 'Trace',			value 	= 3 },
						{ title	= 'Debug',			value 	= 4 },
					},
				},
				
				f:spacer {
					fill_horizontal = 1,
				},
				
				f:push_button {
					title = LOC "$$$/PSUpload/ExportDialog/Logfile=Go to Logfile of last Export",
					tooltip = LOC "$$$/PSUpload/ExportDialog/Logfile=Open PhotoStation Upload Logfile in Explore/Finder.",
					alignment = 'right',
					fill_horizontal = 1,
					action = function()
						LrShell.revealInShell(getLogFilename())
					end,
				},
			}, 
		},
	}
	
	return result
	
end
