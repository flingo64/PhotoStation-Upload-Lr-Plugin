--[[----------------------------------------------------------------------------

PSDialogs.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2017, Martin Messmer

Dialogs and validations for Photo StatLr
	- validatePort
	- validateDirectory
	- validateProgram
	- validatePSUploadProgPath
	
	- psUploaderProgView
	- exiftoolProgView
	
	- targetPhotoStationView
	- thumbnailOptionsView
	- videoOptionsView
	- dstRootView
	- targetAlbumView
	- uploadOptionsView
	- downloadOptionsView
	- publishModeView
	- downloadModeView
	- loglevelView 
		
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
local LrColor 		= import 'LrColor'
local LrDialogs		= import 'LrDialogs'
local LrFileUtils	= import 'LrFileUtils'
local LrHttp 		= import 'LrHttp'
local LrLocalization= import 'LrLocalization'
local LrPathUtils 	= import 'LrPathUtils'
local LrPrefs 		= import 'LrPrefs'
local LrShell 		= import 'LrShell'
local LrView 		= import 'LrView'

require "PSUtilities"
require "PSUpdate"

local bind 				= LrView.bind
local share 			= LrView.share
local negativeOfKey 	= LrBinding.negativeOfKey
local conditionalItem 	= LrView.conditionalItem


--============================================================================--

PSDialogs = {}

--============================ validate functions ===========================================================

-------------------------------------------------------------------------------
-- validatePort: check if a string is numeric
function PSDialogs.validatePort( view, value )
	if string.match(value, '(%d+)') ~= value then 
		return false, value
	end
	
	return true, value
end

-------------------------------------------------------------------------------
-- validateAlbumPath: check if a given path is a valid Album path:
-- no leading/trailing ' ' in each path component
-- no '\'
-- no '//'
function PSDialogs.validateAlbumPath( view, path )
	if 	string.match(path, '^ ') or
	 	string.match(path, ' $') or
	 	string.match(path, ' /') or
	 	string.match(path, '/ ') or
	 	string.match(path, '\\') or
	 	string.match(path, '//') 
	 then
		return false, path
	end
	
	return true, path
end

-------------------------------------------------------------------------------
-- validateDirectory: check if a given path points to a local directory
function PSDialogs.validateDirectory( view, path )
	if LrFileUtils.exists(path) ~= 'directory' then 
		return false, path
	end
	
	return true, LrPathUtils.standardizePath(path)
end

-------------------------------------------------------------------------------
-- validateProgram: check if a given path points to a local program
function PSDialogs.validateProgram( view, path )
	if LrFileUtils.exists(path) ~= 'file'
	or getProgExt() and string.lower(LrPathUtils.extension( path )) ~= getProgExt() then
		return false, path
	end

	return true, LrPathUtils.standardizePath(path)	
end

-------------------------------------------------------------------------------
-- validatePSUploadProgPath:
--	check if a given path points to the root directory of the Synology Photo Station Uploader tool 
--		we require the following converters that ship with the Uploader:
--			- ImageMagick/convert(.exe)
--			- ffmpeg/ffpmeg(.exe)
--			- ffpmpeg/qt-faststart(.exe)
function PSDialogs.validatePSUploadProgPath(view, path)
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
-- validateMetadataPlaceholder: check if a given strings includes metadata placeholders
function PSDialogs.validateMetadataPlaceholder( view, string )
	-- validate at least one metadata placeholders:
	-- check up to 3 balanced '{', '}' 
	if	not string.match(string, '^[^{}]*%b{}[^{}]*$')  
	and	not string.match(string, '^[^{}]*%b{}[^{}]*%b{}[^{}]*$') 
	and	not string.match(string, '^[^{}]*%b{}[^{}]*%b{}[^{}]*%b{}.*$') then 
		return false, string
	end
	
	return true, string
end

--============================ views ===================================================================

-------------------------------------------------------------------------------
-- photoStatLrView(f, propertyTable)
function PSDialogs.photoStatLrSmallView(f, propertyTable)
	return 
		f:view { 
      		f:picture {
    			value		= _PLUGIN:resourceId( "PhotoStatLr-large.png" ),
    			width		= 160,
    			height		= 115,
    			alignment	= 'right',
    		},
    
    		f:static_text {
    			title 			= iif(LrLocalization.currentLanguage() == 'en', '', LOC "$$$/PSUpload/TranslationBy=translated by: get your name here"),
    			alignment		= 'left	',
    			size			= 'mini', 
    			fill_horizontal = 1,
    		},
		}
end

-------------------------------------------------------------------------------
-- photoStatLrView(f, propertyTable)
function PSDialogs.photoStatLrView(f, propertyTable)
	return
		f:view { 
      		f:picture {
    			value		= _PLUGIN:resourceId( "PhotoStatLr-large.png" ),
    			width		= 230,
    			height		= 165,
    			alignment	= 'right',
    		},
    
    		f:static_text {
    			title 			= iif(LrLocalization.currentLanguage() == 'en', '', LOC "$$$/PSUpload/TranslationBy=translated by: get your name here"),
    			alignment		= 'right',
    			size			= 'mini', 
    			fill_horizontal = 1,
    		},
		}
end

-------------------------------------------------------------------------------
-- photoStatLrHeaderView(f, propertyTable)
function PSDialogs.photoStatLrHeaderView(f, propertyTable)
	local prefs = LrPrefs.prefsForPlugin()

	return
		f:row {
   			fill_horizontal = 1,

    		f:column {
    			fill_horizontal = 1,
    
				f:row {
					f:static_text {
    					title 			= "S: We got our money's worth tonight.\nW: But we paid nothing.\nS: That's what we got!\n",
    					font			= '<system/bold>', 
					},
				},
				
				f:row {
					f:static_text {
    					title 			= LOC "$$$/PSUpload/Dialogs/Header/WorthIt=Martin: Well, if you disagree with Mr. S\nand find this software helpful,\nI would be most happy if you donate to a good cause.\nHere are my favourite charity projects:\n"
					},
				},
				
				f:row {
					f:static_text {
    					title 			= LOC "$$$/PSUpload/Dialogs/Header/PhotoStatLrDonation=Photo StatLr's donation website\n",
    					tooltip			= 'Click to open in Browser',
    					font			= '<system/bold>', 
        				alignment		= 'center',
		    			fill_horizontal = 1,
        				mouse_down		= function()
       						LrHttp.openUrlInBrowser(ifnil(prefs.supportUrl, PSUpdate.defaultSupportUrl))
        				end,
					},
				},
				
				f:row {
					f:static_text {
        				title 			= LOC "$$$/PSUpload/Dialogs/Header/Donate=Let me know about your donation, I'll double it (max. 10 Euros)!\n",
        				alignment		= 'center',
		    			fill_horizontal = 1,
					},
				},
				
				f:row {
        			f:push_button {
        				title 			= "Double or nothing, next week's show?",
        				tooltip 		= LOC "$$$/PSUpload/Dialogs/Header/Donate=Let me know about your donation, I'll double it (max. 10 Euros)!\n",
        				alignment 		= 'center',
    					font			= '<system/bold>', 
        				fill_horizontal = 1,
        				action 			= function()
       						LrHttp.openUrlInBrowser(ifnil(prefs.feedbackUrl, PSUpdate.defaultFeedbackUrl))
        				end,
        			},   			
				
				},
				
    		},
    		
			f:spacer { 
    			fill_horizontal = 0.1,				
			},
			
    		f:column {
    			fill_horizontal = 1,
    			alignment	= 'right',
    			PSDialogs.photoStatLrView(f, propertyTable),	
    		}, 
		}
end

-------------------------------------------------------------------------------
-- collectionHeaderView(f, propertyTable, isDefaultCollection, defCollectionName)
function PSDialogs.collectionHeaderView(f, propertyTable, isDefaultCollection, defCollectionName)
	local dialogCaptionText
	
	if isDefaultCollection then
		dialogCaptionText = LOC "$$$/PSUpload/CollectionSettings/Header/Default=This is the Default Collection for this Service:\nSettings of this Collection will be the default\nfor all new collections within in this Service!"
	elseif defCollectionName then
		dialogCaptionText = LOC("$$$/PSUpload/CollectionSettings/Header/NotDefault=Note:\nTo change the default settings for\nnew Collections within this Service,\nedit the Default Collection\n'^1'.", defCollectionName)
	else
		dialogCaptionText = ""
	end
	
	return 
		f:view {
    		f:row {
    			fill_hoizontal = 1,
    			
    			f:column {
    				PSDialogs.photoStatLrSmallView(f, propertyTable),
    				fill_hoizontal = 0.4,
    			},
    			
    			f:column {
    				fill_hoizontal = 0.6,
    				f:row {
            			f:static_text {
            				title 		= "Why would he want to remember this?\n\n",
            				alignment 	= 'center',
        					font		= '<system/bold>', 
            			},
            		},
            		
    				f:row {
            			f:static_text {
            				title 		= dialogCaptionText,
            				text_color	= iif(isDefaultCollection, LrColor("red"), LrColor("black")),
        					font		= iif(defCollectionName, '<system/small>', '<system>'), 
            				alignment	= 'left',
            			},
    				},
    			},
    		},
    	}
end
	
-------------------------------------------------------------------------------
-- missingParamsHeaderView(f, propertyTable, operation)
function PSDialogs.missingParamsHeaderView(f, propertyTable, operation)
	return 
		f:view {
    		f:row {
    			fill_hoizontal = 1,
    			
    			f:column {
    				PSDialogs.photoStatLrSmallView(f, propertyTable),
    				fill_hoizontal = 0.4,
    			},
    			
    			f:column {
    				fill_hoizontal = 0.6,
    				f:row {
            			f:static_text {
            				title 		= "If you had half a mind, you wouldn't be here!\n\n",
            				alignment 	= 'left',
        					font		= '<system/bold>', 
            			},
            		},
            		
    				f:row {
            			f:static_text {
            				title = LOC "$$$/PSUpload/MissingParams/Header/EnterMissing=Please enter missing parameters for:\n\n",
            				alignment = 'left',
            			},
    				},

    				f:row {
            			f:static_text {
            				title = operation,
            				alignment = 'left',
        					font		= '<system/bold>', 
            			},
    				},
    			},
    		},
    	}
end
	
-------------------------------------------------------------------------------
-- psUploaderProgView(f, propertyTable)
function PSDialogs.psUploaderProgView(f, propertyTable)
	return
        f:group_box {
			title	= 'Synology Photo Station Uploader',
			fill_horizontal = 1,
			
    		f:row {
    			f:static_text {
    				title 			= LOC "$$$/PSUpload/PluginDialog/PSUploaderDescription=Enter the path where 'Synology Photo Station Uploader' is installed.\nRequired, if you want to generate thumbs locally or upload videos.\n", 
    			},
    		},
    
    		f:row {
    			f:static_text {
    				title 			= "Synology PS Uploader:",
    				alignment 		= 'right',
    				width 			= share 'labelWidth',
    			},
    
    			f:edit_field {
    				truncation 		= 'middle',
    				immediate 		= true,
    				fill_horizontal = 1,
    				value 			= bind 'PSUploaderPath',
    				validate 		= PSDialogs.validatePSUploadProgPath,
    			},
    		},
    
    		f:row {   			
     			f:push_button {
    				title 			= LOC "$$$/PSUpload/PluginDialog/ProgDefault=Default",
    				tooltip 		= LOC "$$$/PSUpload/PluginDialog/ProgDefaultTT=Set to Default.",
    				alignment 		= 'right',
    				fill_horizontal = 1,
    				action 			= function()
    					propertyTable.PSUploaderPath = PSConvert.defaultInstallPath
    				end,
    			},   			

    			f:push_button {
    				title 			= LOC "$$$/PSUpload/PluginDialog/ProgSearch=Search",
    				tooltip 		= LOC "$$$/PSUpload/PluginDialog/ProgSearchTT=Search program in Explorer/Finder.",
    				alignment 		= 'right',
    				fill_horizontal = 1,
    				action 			= function()
    					LrShell.revealInShell(getRootPath())
    				end,
    			},   			

    			f:push_button {
    				title 			= LOC "$$$/PSUpload/PluginDialog/ProgDownload=Download",
    				tooltip 		= LOC "$$$/PSUpload/PluginDialog/ProgDownloadTT=Download program from Web.",
    				alignment 		= 'right',
    				fill_horizontal = 1,
    				action 			= function()
   						LrHttp.openUrlInBrowser(PSConvert.downloadUrl)
    				end,
    			},   			
    		},
    	}
end

-------------------------------------------------------------------------------
-- convertPhotosView(f, propertyTable)
function PSDialogs.convertPhotosView(f, propertyTable)
	return
        f:group_box {
			title	= LOC "$$$/PSUpload/PluginDialog/Convert=Convert published photos to Photo StatLr format",
			fill_horizontal = 1,

    		f:row {
    			f:static_text {
    				title 			= LOC "$$$/PSUpload/PluginDialog/ConvertPhotosDescription=If you are upgrading from PhotoStation Upload to Photo StatLr and you intend to use\nthe download options of Photo StatLr,then you have to convert the photos of\nthose Published Collections that should be configured with the download options.\nYou can convert all photos here, or you can do it for individual Published Collections\nvia publish mode 'Convert'.\n", 
    				alignment 		= 'center',
					fill_horizontal = 1,
    			},
    		},

    		f:row {   			
	
				f: spacer {	fill_horizontal = 1,}, 
				
     			f:push_button {
    				title 			= LOC "$$$/PSUpload/PluginDialog/ConvertAll=Convert all photos",
    				tooltip 		= LOC "$$$/PSUpload/PluginDialog/ConvertAllTT=Convert all published photos to new format.",
    				alignment 		= 'center',
    				fill_horizontal = 1,
    				action 			= function ()
    								propertyTable.convertAllPhotos = true
    								LrDialogs.message('Photo StatLr', 'Conversion will start after closing the Plugin Manager dialog.', 'info')
    								
    				end,
    			},   			

				f: spacer {	fill_horizontal = 1,}, 
				
			},
		}
end

-------------------------------------------------------------------------------
-- exiftoolProgView(f, propertyTable)
function PSDialogs.exiftoolProgView(f, propertyTable)
	return
        f:group_box {
   			title	= 'Exiftool',
			fill_horizontal = 1,
    			
    		f:row {
    			f:static_text {
    				title			= LOC "$$$/PSUpload/PluginDialog/exiftoolDesc=Enter the path where 'exiftool' is installed.\nRequired, if you want to use metadata translations (face regions, color labels, ratings).\n" 
    			},
    		},
    
    		f:row {
    			f:static_text {
    				title 			= "exiftool:",
    				alignment 		= 'right',
    				width 			= share 'labelWidth',
    			},
    
    			f:edit_field {
    				truncation 		= 'middle',
    				immediate 		= true,
    				fill_horizontal = 1,
    				value 			= bind 'exiftoolprog',
    				validate 		= PSDialogs.validateProgram,
    			},
    		},
    
    		f:row {
    			f:push_button {
    				title 			= LOC "$$$/PSUpload/PluginDialog/ProgDefault=Default",
    				tooltip 		= LOC "$$$/PSUpload/PluginDialog/ProgDefaultTT=Set to Default.",
    				alignment 		= 'right',
    				fill_horizontal = 1,
    				action 			= function()
    					propertyTable.exiftoolprog = PSExiftoolAPI.defaultInstallPath
    				end,
    			},   			

    			f:push_button {
    				title 			= LOC "$$$/PSUpload/PluginDialog/ProgSearch=Search",
    				tooltip 		= LOC "$$$/PSUpload/PluginDialog/ProgSearchTT=Search program in Explorer/Finder.",
    				alignment 		= 'right',
    				fill_horizontal = 1,
    				action 			= function()
    					LrShell.revealInShell(getRootPath())
    				end,
    			},   			

    			f:push_button {
    				title 			= LOC "$$$/PSUpload/PluginDialog/ProgDownload=Download",
    				tooltip 		= LOC "$$$/PSUpload/PluginDialog/ProgDownloadTT=Download program from Web.",
    				alignment 		= 'right',
    				fill_horizontal = 1,
    				action 			= function()
   						LrHttp.openUrlInBrowser(PSExiftoolAPI.downloadUrl)
    				end,
    			},   			
    		},
    	}
end

-------------------------------------------------------------------------------
-- targetPhotoStationView(f, propertyTable)
function PSDialogs.targetPhotoStationView(f, propertyTable)
	local protocolItems = {
        { title	= 'http',   value 	= 'http' },
		{ title	= 'https',	value 	= 'https' },
	}
	
	local timeoutItems = {
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
	}

	local versionItems = {
        { title	= 'Photo Station 5',   value 	= 50 },
        { title	= 'Photo Station 6',   value 	= 60 },
        { title	= 'Photo Station 6.5', value 	= 65 },
        { title	= 'Photo Station 6.6', value 	= 66 },
	}
	
	return
        f:group_box {
        	fill_horizontal = 1,
        	title = LOC "$$$/PSUpload/ExportDialog/TargetPS=Target Photo Station",
        
        	f:row {
				f:static_text {
					title 			= LOC "$$$/PSUpload/ExportDialog/PSVersion=Version:",
					alignment 		= 'right',
        			width 			= share 'labelWidth',
				},
				
        		f:popup_menu {
        			tooltip			= LOC "$$$/PSUpload/ExportDialog/PSVersionListTT=Photo Station Version",
        			items 			= versionItems,
        			value 			= bind 'psVersion',
        		},
        
        	}, 

        	f:row {
        		f:radio_button {
        			title 			= LOC "$$$/PSUpload/ExportDialog/Servername=Server Address:",
        			alignment 		= 'left',
        			width 			= share 'labelWidth',
        			value 			= bind 'useSecondAddress',
        			checked_value	= false,
        		},
        
        		f:popup_menu {
        			tooltip			= LOC "$$$/PSUpload/ExportDialog/ProtocolTT=Protocol",
        			items 			= protocolItems,
        			value 			= bind 'proto',
        			enabled 		= negativeOfKey 'useSecondAddress',
        		},
        
        		f:edit_field {
        			tooltip 		= LOC "$$$/PSUpload/ExportDialog/ServernameTT=Enter the IP address or hostname of the Photo Station.\nNon-standard port may be appended as :port",
        			truncation 		= 'middle',
        			immediate 		= true,
        			fill_horizontal = 0.6,
        			value 			= bind 'servername',
        			enabled 		= negativeOfKey 'useSecondAddress',
        		},
        
				f:static_text {
					title 			= bind 'psPath',
        			truncation 		= 'middle',
        			immediate 		= true,
        			fill_horizontal = 0.4,
        			enabled 		= negativeOfKey 'useSecondAddress',
        		},
        
        		f:row {
        			alignment 		= 'right',
        			fill_horizontal = 0.5,
        
        			f:static_text {
        				title 		= LOC "$$$/PSUpload/ExportDialog/ServerTimeout=Timeout:",
        				alignment 	= 'right',
        			},
        
        			f:popup_menu {
        				tooltip 		= LOC "$$$/PSUpload/ExportDialog/ServerTimeoutTT=HTTP(S) connect timeout, recommended value: 10s\nUse higher value (> 40s), if you experience problems due to disks in standby mode",
        				items 			= timeoutItems,
        				alignment 		= 'left',
        				fill_horizontal = 1,
        				value 			= bind 'serverTimeout',
        				enabled 		= negativeOfKey 'useSecondAddress',
        			},
        		},
        	}, 
        	
        	f:row {
        		f:radio_button {
        			title 			= LOC "$$$/PSUpload/ExportDialog/Servername2=2nd Server Address:",
        			alignment 		= 'right',
        			width 			= share 'labelWidth',
        			value 			= bind 'useSecondAddress',
        			checked_value 	= true,
        		},
        
        		f:popup_menu {
        			tooltip 		= LOC "$$$/PSUpload/ExportDialog/ProtocolTT=Protocol",
        			items			= protocolItems,
        			value 			= bind 'proto2',
        			enabled 		= bind 'useSecondAddress',
        		},
        
        		f:edit_field {
        			tooltip 		= LOC "$$$/PSUpload/ExportDialog/Servername2TT=Enter the secondary IP address or hostname.\nNon-standard port may be appended as :port",
        			truncation 		= 'middle',
        			immediate 		= true,
        			fill_horizontal = 0.6,
        			value 			= bind 'servername2',
        			enabled 		= bind 'useSecondAddress',
        		},
        
				f:static_text {
					title 			= bind 'psPath',
        			truncation 		= 'middle',
        			immediate 		= true,
        			fill_horizontal = 0.4,
        			enabled 		= bind 'useSecondAddress',
        		},
        
        		f:row {
        			alignment 		= 'right',
        			fill_horizontal = 0.5,
        
        			f:static_text {
        				title 		= LOC "$$$/PSUpload/ExportDialog/ServerTimeout=Timeout:",
        				alignment 	= 'right',
        			},
        
        			f:popup_menu {
        				tooltip 		= LOC "$$$/PSUpload/ExportDialog/ServerTimeoutTT=HTTP(S) connect timeout, recommended value: 10s\nUse higher value (> 40s), if you experience problems due to disks in standby mode",
        				items 			= timeoutItems,
        				alignment 		= 'left',
        				fill_horizontal = 1,
        				value 			= bind 'serverTimeout2',
        				enabled 		= bind 'useSecondAddress',
        			},
        		},
        	},

			f:separator { fill_horizontal = 1 },

			f:row {
				f:radio_button {
					title 			= LOC "$$$/PSUpload/ExportDialog/StandardPS=Std Photo Station",
					alignment 		= 'left',
					width 			= share 'labelWidth',
					value 			= bind 'usePersonalPS',
					checked_value 	= false,
				},

				f:radio_button {
					title 			= LOC "$$$/PSUpload/ExportDialog/PersonalPS=Personal Photo Station of User:",
					alignment 		= 'left',
					value 			= bind 'usePersonalPS',
					checked_value 	= true,
				},

				f:edit_field {
					tooltip 		= LOC "$$$/PSUpload/ExportDialog/PersonalPSTT=Enter the name of the owner of the Personal Photo Station you want to upload to.",
					truncation 		= 'middle',
					immediate 		= true,
					fill_horizontal = 1,
					value 			= bind 'personalPSOwner',
					enabled 		= bind 'usePersonalPS',
					visible 		= bind 'usePersonalPS',
				},
			},

			f:row {
				f:static_text {
					title 			= LOC "$$$/PSUpload/ExportDialog/Username=Username:",
					alignment 		= 'right',
					width 			= share 'labelWidth'
				},
	
				f:edit_field {
					tooltip 		= LOC "$$$/PSUpload/ExportDialog/UsernameTT=Enter the username for Photo Station access.",
					truncation 		= 'middle',
					immediate 		= true,
					fill_horizontal = 1,
					value 			= bind 'username',
				},

				f:static_text {
					title 			= LOC "$$$/PSUpload/ExportDialog/Password=Password:",
					alignment 		= 'right',
				},
	
				f:password_field {
					tooltip 		= LOC "$$$/PSUpload/ExportDialog/PasswordOptTT=Enter the password for Photo Station access.\nLeave this field blank, if you don't want to store the password.\nYou will be prompted for the password later.",
					truncation 		= 'middle',
					immediate 		= true,
					fill_horizontal = 1,
					value 			= bind 'password',
				},
			},
		}
end

-------------------------------------------------------------------------------
-- thumbnailOptionsView(f, propertyTable)
function PSDialogs.thumbnailOptionsView(f, propertyTable)
	local thumbQualityItems = {
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
	}
	
	local thumbSharpnessItems = {
		{ title	= 'None',	value 	= 'None' },
		{ title	= 'Low',	value 	= 'LOW' },
		{ title	= 'Medium',	value 	= 'MED' },
		{ title	= 'High',	value 	= 'HIGH' },
	}
	
	return
		f:group_box {
			title 			= LOC "$$$/PSUpload/ExportDialog/Thumbnails=Thumbnail Options",
			fill_horizontal = 1,

			f:row {
				f:checkbox {
					title 			= LOC "$$$/PSUpload/ExportDialog/GenerateThumbs=Do thumbs:",
					tooltip 		= LOC "$$$/PSUpload/ExportDialog/GenerateThumbsTT=Generate thumbs:\nUnselect only, if you want the diskstation to generate the thumbs\nor if you export to an unindexed folder and you don't need thumbs.\nThis will speed up photo uploads.",
					fill_horizontal = 1,
					value 			= bind 'thumbGenerate',
				},

				f:row {
					fill_horizontal = 1,

					f:radio_button {
						title 			= LOC "$$$/PSUpload/ExportDialog/SmallThumbs=Small",
						tooltip 		= LOC "$$$/PSUpload/ExportDialog/SmallThumbsTT=Recommended for output on low-resolution monitors",
						alignment 		= 'left',
						fill_horizontal = 1,
						value 			= bind 'largeThumbs',
						checked_value 	= false,
						visible 		= bind 'thumbGenerate',
					},

					f:radio_button {
						title 			= LOC "$$$/PSUpload/ExportDialog/LargeThumbs=Large",
						tooltip			= LOC "$$$/PSUpload/ExportDialog/LargeThumbsTT=Recommended for output on Full HD monitors",
						alignment 		= 'right',
						fill_horizontal = 1,
						value 			= bind 'largeThumbs',
						checked_value 	= true,
						visible 		= bind 'thumbGenerate',
					},
				},
				
				f:row {
					alignment 		= 'right',
					fill_horizontal = 1,

					f:static_text {
						title	 	= LOC "$$$/PSUpload/ExportDialog/ThumbQuality=Quality:",
						alignment 	= 'right',
						visible 	= bind 'thumbGenerate',
					},

					f:popup_menu {
						tooltip 		= LOC "$$$/PSUpload/ExportDialog/QualityTT=Thumb conversion quality, recommended value: 80%",
						items 			= thumbQualityItems,
						alignment 		= 'left',
						fill_horizontal = 1,
						value 			= bind 'thumbQuality',
						visible 		= bind 'thumbGenerate',
					},
				},

				f:row {
					alignment 		= 'right',
					fill_horizontal = 1,

					f:static_text {
						title 		= LOC "$$$/PSUpload/ExportDialog/ThumbSharpness=Sharpening:",
						alignment	= 'right',
						visible 	= bind 'thumbGenerate',
					},

					f:popup_menu {
						tooltip 		= LOC "$$$/PSUpload/ExportDialog/ThumbSharpnessTT=Thumbnail sharpening, recommended value: Medium",
						items 			= thumbSharpnessItems,
						alignment 		= 'left',
						fill_horizontal = 1,
						value 			= bind 'thumbSharpness',
						visible 		= bind 'thumbGenerate',
					},
				},
			},
		}
end

-------------------------------------------------------------------------------
-- videoOptionsView(f, propertyTable)
function PSDialogs.videoOptionsView(f, propertyTable)
	local lowResAddVideoItems	= {
		{ title	= 'None',			value 	= 'None' },
		{ title	= 'Mobile/240p',		value 	= 'MOBILE' },
	}
	
	local medResAddVideoItems	= tableShallowCopy(lowResAddVideoItems)
	table.insert(medResAddVideoItems,
		{ title	= 'Low/360p',		value 	= 'LOW' })
	
	local highResAddVideoItems	= tableShallowCopy(medResAddVideoItems)
	table.insert(highResAddVideoItems,
		{ title	= 'Medium/720p',		value 	= 'MEDIUM' })

	local ultraResAddVideoItems	= tableShallowCopy(highResAddVideoItems)
	table.insert(ultraResAddVideoItems, 
		{ title	= 'High/1080p',		value 	= 'HIGH' })

	return
		f:group_box {
			title 			= LOC "$$$/PSUpload/ExportDialog/Videos=Video Upload Options: Additional video resolutions for ...-Res Videos",
			fill_horizontal = 1,

			f:row {
				fill_horizontal = 1,
				f:row {
					alignment = 'left',
					fill_horizontal = 1,

					f:static_text {
						title 			= LOC "$$$/PSUpload/ExportDialog/VideoUltra=Ultra:",
						alignment 		= 'right',
					},
					
					f:popup_menu {
						tooltip 		= LOC "$$$/PSUpload/ExportDialog/VideoUltraTT=Generate additional video for Ultra-Hi-Res (2160p) videos",
						items 			= ultraResAddVideoItems,
						alignment 		= 'left',
						fill_horizontal = 1,
						value 			= bind 'addVideoUltra',
					},
				},					

				f:row {
					alignment = 'left',
					fill_horizontal = 1,

					f:static_text {
						title 			= LOC "$$$/PSUpload/ExportDialog/VideoHigh=High:",
						alignment 		= 'right',
					},
					
					f:popup_menu {
						tooltip 		= LOC "$$$/PSUpload/ExportDialog/VideoHighTT=Generate additional video for Hi-Res (1080p) videos",
						items 			= highResAddVideoItems,
						alignment 		= 'left',
						fill_horizontal = 1,
						value 			= bind 'addVideoHigh',
					},
				},					

				f:row {
					alignment 			= 'right',
					fill_horizontal 	= 1,

					f:static_text {
						title 			= LOC "$$$/PSUpload/ExportDialog/VideoMed=Medium:",
						alignment 		= 'right',
					},
					
					f:popup_menu {
						tooltip 		= LOC "$$$/PSUpload/ExportDialog/VideoMedTT=Generate additional video for Medium-Res (720p) videos",
						items 			= medResAddVideoItems,
						alignment 		= 'left',
						fill_horizontal = 1,
						value 			= bind 'addVideoMed',
					},
				},					

				f:row {
					alignment 			= 'right',
					fill_horizontal 	= 1,

					f:static_text {
						title 			= LOC "$$$/PSUpload/ExportDialog/VideoLow=Low:",
						alignment 		= 'right',
					},
					
					f:popup_menu {
						tooltip 		= LOC "$$$/PSUpload/ExportDialog/VideoLowTT=Generate additional video for Low-Res (360p) videos",
						items 			= lowResAddVideoItems,
						alignment 		= 'left',
						fill_horizontal = 1,
						value 			= bind 'addVideoLow',
					},
				},					
			},
			
			f:row {
				f:checkbox {
					title 			= LOC "$$$/PSUpload/ExportDialog/HardRotate=Hard-rotation",
					tooltip 		= LOC "$$$/PSUpload/ExportDialog/HardRotateTT=Use hard-rotation for better player compatibility,\nwhen a video is soft-rotated or meta-rotated\n(keywords include: 'Rotate-90', 'Rotate-180' or 'Rotate-270')",
					alignment 		= 'left',
					fill_horizontal = 1,
					value 			= bind 'hardRotate',
				},
			},
		}
end

-------------------------------------------------------------------------------
-- dstRootView(f, propertyTable)
--
function PSDialogs.dstRootView(f, propertyTable, isAskForMissingParams)
	return 
		f:row {
--			fill_horizontal = 1,

			iif(isAskForMissingParams or propertyTable.isCollection,
    			f:static_text {
    				title 		= LOC "$$$/PSUpload/ExportDialog/StoreDstRoot=Target Album:",
    				alignment 	= 'right',
    				width 		= share 'labelWidth'
    			},
				-- else
				f:checkbox {
    				title 		= LOC "$$$/PSUpload/ExportDialog/StoreDstRoot=Target Album:",
    				tooltip 	= LOC "$$$/PSUpload/ExportDialog/StoreDstRootTT=Enter Target Album here or you will be prompted for it when the upload starts.",
    				alignment 	= 'left',
    				width 		= share 'labelWidth',
    				value 		= bind 'storeDstRoot',
    				enabled 	=  negativeOfKey 'isCollection',
				}
			),

			f:edit_field {
					tooltip = LOC "$$$/PSUpload/ExportDialog/DstRootTT=Enter the target directory below the diskstation share '/photo' or '/home/photo'\n(may be different from the Album name shown in Photo Station)",
				truncation 		= 'middle',
--				width_in_chars 	= 16,
				immediate 		= true,
				fill_horizontal = 0.9,
				value 			= bind 'dstRoot',
				enabled 		= iif(isAskForMissingParams, true, bind 'storeDstRoot'),
				visible 		= iif(isAskForMissingParams, true, bind 'storeDstRoot'),
				validate 		= PSDialogs.validateAlbumPath,
			},

			f:checkbox {
				title 			= LOC "$$$/PSUpload/ExportDialog/CreateDstRoot=Create Album, if needed",
				alignment 		= 'left',
				fill_horizontal = 0.1,
				value 			= bind 'createDstRoot',
				enabled 		= iif(isAskForMissingParams, true, bind 'storeDstRoot'),
				visible 		= iif(isAskForMissingParams, true, bind 'storeDstRoot'),
			},
		}

end

-------------------------------------------------------------------------------
-- dstRootForSetView(f, propertyTable)
--
function PSDialogs.dstRootForSetView(f, propertyTable)
	return 
		f:row {
--			fill_horizontal = 1,

			f:static_text {
				title = LOC "$$$/PSUpload/ExportDialog/StoreDstRoot=Target Album:",
				alignment = 'right',
				width = share 'labelWidth'
			},

			f:edit_field {
				tooltip = LOC "$$$/PSUpload/ExportDialog/DstRootTT=Enter the target directory below the diskstation share '/photo' or '/home/photo'\n(may be different from the Album name shown in Photo Station)",
				value = bind 'baseDir',
				truncation = 'middle',
				immediate = true,
				fill_horizontal = 1,
			},
		}
end

-------------------------------------------------------------------------------
-- targetAlbumView(f, propertyTable)
--
function PSDialogs.targetAlbumView(f, propertyTable)
	return f:view {
		fill_horizontal = 1,

		f:group_box {
			title 			= LOC "$$$/PSUpload/ExportDialog/TargetAlbum=Target Album and Upload Method",
			fill_horizontal = 1,

			PSDialogs.dstRootView(f, propertyTable), 

			f:row {

				f:radio_button {
					title 			= LOC "$$$/PSUpload/ExportDialog/FlatCopy=Flat Copy",
					tooltip 		= LOC "$$$/PSUpload/ExportDialog/FlatCopyTT=All photos/videos will be copied to the Target Album",
					alignment 		= 'left',
--					width 			= share 'labelWidth',
					value 			= bind 'copyTree',
					checked_value 	= false,
				},

				f:radio_button {
					title 			= LOC "$$$/PSUpload/ExportDialog/CopyTree=Mirror Tree relative to:",
					tooltip 		= LOC "$$$/PSUpload/ExportDialog/CopyTreeTT=All photos/videos will be copied to a mirrored directory below the Target Album",
					alignment 		= 'left',
					value 			= bind 'copyTree',
					checked_value 	= true,
				},

				f:edit_field {
					tooltip 		= LOC "$$$/PSUpload/ExportDialog/CopyTreeBaseTT=Enter the local path that is the root of the directory tree you want to mirror below the Target Album.",
					truncation 		= 'middle',
					immediate 		= true,
					fill_horizontal = 1,
					value 			= bind 'srcRoot',
					validate 		= PSDialogs.validateDirectory,
					enabled 		= bind 'copyTree',
					visible 		= bind 'copyTree',
				},
			},

			f:row {
				f:checkbox {
					title 			= LOC "$$$/PSUpload/ExportDialog/SortPhotos=Sort Photos",
					tooltip 		= LOC "$$$/PSUpload/ExportDialog/SortPhotosTT=Sort photos in Photo Station according to sort order of Published Collection.\nNote: Sorting is only possible for collections with 'Sort: Custom Order' when uploading to a flat album.",
					alignment 		= 'left',
					fill_horizontal = 1,
					value 			= bind 'sortPhotos',
					enabled 		= negativeOfKey 'copyTree',
				},	
			},

		},
		
	} 
end	

-------------------------------------------------------------------------------
-- photoNamingView(f, propertyTable)
--
function PSDialogs.photoNamingView(f, propertyTable)
	return f:view {
		fill_horizontal = 1,
		f:group_box {
			title 			= LOC "$$$/PSUpload/ExportDialog/TargetPhoto=Target Photo Naming Options",
			fill_horizontal = 1,

			f:row {
				f:checkbox {
    				title 		= LOC "$$$/PSUpload/ExportDialog/RenamePhoto=Rename To:",
    				tooltip 	= LOC "$$$/PSUpload/ExportDialog/RenamePhotoTT=Rename photos in Photo Station acc. to a unique naming schema.",
    				alignment 	= 'left',
    				width 		= share 		'labelWidth',
    				value 		= bind 			'renameDstFile',
				},

    			f:edit_field {
    				tooltip 		= LOC "$$$/PSUpload/ExportDialog/RenamePhotoPatternTT=Enter filename renaming pattern for target photo filename.\nMust include at least one metadata placeholder!",
    				truncation 		= 'middle',
    				immediate 		= true,
					validate 		= PSDialogs.validateMetadataPlaceholder,
    				fill_horizontal = 0.9,
    				value 			= bind 'dstFilename',
    				enabled 		= bind 'renameDstFile',
    				visible 		= bind 'renameDstFile',
    			},

				f:checkbox {
					title 			= LOC "$$$/PSUpload/ExportDialog/RAWandJPG=RAW+JPG to same Album",
					tooltip 		= LOC "$$$/PSUpload/ExportDialog/RAWandJPGTT=Allow Lr-developed RAW+JPG from camera to be uploaded to same Album.\nNote: All Non-JPEG photos will be renamed in Photo Station to <photoname>_<OrigExtension>.<OutputExtension>. E.g.:\nIMG-001.RW2 --> IMG-001_RW2.JPG\nIMG-001.JPG --> IMG-001.JPG",
					alignment 		= 'left',
					fill_horizontal = 0.1,
					value 			= bind 'RAWandJPG',
				},
			},
		},
	}
end

-------------------------------------------------------------------------------
-- uploadOptionsView(f, propertyTable)
function PSDialogs.uploadOptionsView(f, propertyTable)
	return	f:group_box {
		fill_horizontal = 1,
		title = LOC "$$$/PSUpload/ExportDialog/UploadOpt=Metadata Upload Options /Translations (To Photo Station)",

		conditionalItem(propertyTable.isCollection, 
			f:row {
    			f:checkbox {
    				title 			= LOC "$$$/PSUpload/ExportDialog/TitleUpload=Title (always)",
    				fill_horizontal = 1,
    				value 			= true,
    				enabled 		= false,
    			},
    
    			f:checkbox {
    				title 			= LOC "$$$/PSUpload/ExportDialog/CaptionUpload=Decription (always)",
    				fill_horizontal = 1,
    				value 			= true,
    				enabled 		= false,
    			},
    
    			f:checkbox {
    				title 			= LOC "$$$/PSUpload/ExportDialog/LocationUpload=GPS (always)",
    				fill_horizontal = 1,
    				value 			= true,
    				enabled 		= false,
    			},
    
    			f:checkbox {
    				title 			= LOC "$$$/PSUpload/ExportDialog/RatingUpload=Rating (always)",
    				fill_horizontal = 1,
    				value 			= true,
    				enabled 		= false,
    			},
    
    		}
		), 
		
		f:row {
			f:checkbox {
				title 			= LOC "$$$/PSUpload/ExportDialog/KeywordUpload=Keywords (always)",
				fill_horizontal = 1,
				value 			= true,
				enabled 		= false,
			},

			f:checkbox {
				title 			= LOC "$$$/PSUpload/ExportDialog/TranslateFaceRegions=Faces",
				tooltip 		= LOC "$$$/PSUpload/ExportDialog/TranslateFaceRegionsTT=Translate Lr face regions to Photo Station person tags\n(Useful for Photo Station version < 6.5)",
				fill_horizontal = 1,
				value 			= bind 'exifXlatFaceRegions',
			},
		
			f:checkbox {
				title 			= LOC "$$$/PSUpload/ExportDialog/TranslateLabel=Color Label Tag",
				tooltip 		= LOC "$$$/PSUpload/ExportDialog/TranslateLabelTT=Translate Lr color label (red, green, ...) to Photo Station '+color' general tag",
				fill_horizontal = 1,
				value 			= bind 'exifXlatLabel',
			},

			f:checkbox {
				title 			= LOC "$$$/PSUpload/ExportDialog/TranslateRating=Rating Tag",
				tooltip 		= LOC "$$$/PSUpload/ExportDialog/TranslateRatingTT=Translate Lr rating (*stars*) to Photo Station '***' general tag\n(Useful for Photo Station version < 6.5)",
				fill_horizontal = 1,
				value 			= bind 'exifXlatRating',
			},
		},
		
		conditionalItem(propertyTable.isCollection, f:separator { fill_horizontal = 1 }),

		conditionalItem(propertyTable.isCollection, f:row {
    			f:checkbox {
    				title 			= LOC "$$$/PSUpload/ExportDialog/CommentsUpload=Comments (always)",
    				fill_horizontal = 1,
    				value 			= true,
    				enabled 		= false,
    			},
        	}
		),
	}

end

-------------------------------------------------------------------------------
-- downloadOptionsView(f, propertyTable)
function PSDialogs.downloadOptionsView(f, propertyTable)
	return	f:group_box {
		bind_to_object = propertyTable,

		fill_horizontal = 1,
		title = LOC "$$$/PSUpload/ExportDialog/DownloadOpt=Metadata Download Options / Translations  (From Photo Station)",

		f:row {
			f:checkbox {
				title 			= LOC "$$$/PSUpload/CollectionSettings/TitleDownload=Title",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/TitleDownloadTT=Download photo title tag from Photo Station",
				fill_horizontal = 1,
				value 			= bind 'titleDownload',
			},

			f:checkbox {
				title 			= LOC "$$$/PSUpload/CollectionSettings/CaptionDownload=Description",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/CaptionDownloadTT=Download photo description (caption) from Photo Station",
				fill_horizontal = 1,
				value 			= bind 'captionDownload',
			},

			f:row {
    			fill_horizontal = 1,
    			f:checkbox {
    				title 			= LOC "$$$/PSUpload/CollectionSettings/LocationDownload=GPS (red)",
    				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/LocationDownloadTT=Download GPS info of the photo (red pin) from Photo Station",
    				value 			= bind 'locationDownload',
    			},
    			f:checkbox {
    				title 			= LOC "$$$/PSUpload/CollectionSettings/LocationTagDownload=GPS (blue)",
    				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/LocationTagDownloadTT=Download GPS info of the photo's location tag (blue pin) from Photo Station.\nRed pin has preference over blue pin. Download of blue pin GPS takes significantly more time!",
    				value 			= bind 'locationTagDownload',
    				enabled			= bind 'locationDownload',
    			},
    		},

			f:checkbox {
				title 			= LOC "$$$/PSUpload/CollectionSettings/RatingDownload=Rating",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/RatingDownloadTT=Download rating from Photo Station\n(Requires Photo Station 6.5 or later)",
				fill_horizontal = 1,
				value 			= bind 'ratingDownload',
				enabled			= iif(ifnil(propertyTable.psVersion, 65) >= 65, true, false),
			},

		},

		f:row {
			f:checkbox {
				title 			= LOC "$$$/PSUpload/CollectionSettings/TagsDownload=Tags/Keywords",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/TagsDownloadTT=Download tags from Photo Station to Lr keywords",
				fill_horizontal = 1,
				value 			= bind 'tagsDownload',
			},

			f:checkbox {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/CollectionSettings/PSTranslateFaces=Faces",
				tooltip = LOC "$$$/PSUpload/CollectionSettings/PSTranslateFacesTT=Download and translate Photo Station People Tags to Lightroom Faces\nNote: Faces will be written to original photo and photo metadata must be re-loaded into Lr\n!!! Make sure, you configured 'Automatically write changes into XMP, otherwise\nyou will loose you Lr changes when re-loading faces metadata!!!'",
				value = bind 'PS2LrFaces',
				enabled = bind 'exifXlatFaceRegions',
			},

			f:checkbox {
				title 			= LOC "$$$/PSUpload/CollectionSettings/PSTranslateLabel=Color Label Tag",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/PSTranslateLabelTT=Translate Photo Station '+color' general tag to Lr color label (red, green, ...)",
				fill_horizontal = 1,
				value 			= bind 'PS2LrLabel',
				enabled 		= bind 'exifXlatLabel',
			},

			f:checkbox {
				title 			= LOC "$$$/PSUpload/CollectionSettings/PSTranslateRating=Rating Tag",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/PSTranslateRatingTT=Translate Photo Station '***' general tag to Lr rating\n(Useful for Photo Station version < 6.5)",
				fill_horizontal = 1,
				value 			= bind 'PS2LrRating',
				enabled 		= bind 'exifXlatRating',
			},
		},
		
		f:separator { fill_horizontal = 1 },
		
		f:row {
			f:checkbox {
				title 			= LOC "$$$/PSUpload/CollectionSettings/CommentsDownload=Private Comments",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/CommentsDownloadTT=Download photo comments from Photo Station (internal) to Lr Comments panel",
				fill_horizontal = 1,
				value 			= bind 'commentsDownload',
			},

			f:checkbox {
				title 			= LOC "$$$/PSUpload/CollectionSettings/PublicCommentsDownload=Public Comments",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/PublicCommentsDownloadTT=Download photo comments from Photo Station public shares to Lr Comments panel",
				fill_horizontal = 1,
				value 			= bind 'pubCommentsDownload',
			},
		},
	}
end

-------------------------------------------------------------------------------
-- publishModeView(f, propertyTable, isAskForMissingParams)
function PSDialogs.publishModeView(f, propertyTable, isAskForMissingParams)
	local publishModeItems = {
		{ title	= LOC "$$$/PSUpload/Dialogs/ListBox/OptAsk=Ask me later",																					value 	= 'Ask' },
		{ title	= LOC "$$$/PSUpload/CollectionSettings/PublishModeOptUpload=Upload: Normal publishing of photos",														value 	= 'Publish' },
		{ title	= LOC "$$$/PSUpload/CollectionSettings/PublishModeOptChkEx=CheckExisting: Set Unpublished to Published if existing in Photo Station.",					value 	= 'CheckExisting' },
		{ title	= LOC "$$$/PSUpload/CollectionSettings/PublishModeOptChkMv=CheckMoved: Set Published to Unpublished if moved locally.",									value 	= 'CheckMoved' },
		{ title	= LOC "$$$/PSUpload/CollectionSettings/PublishModeOptMove=MovePhotos: Move photos in Photo Station (for photos moved in Lr or changed target album).",	value 	= 'MovePhotos' },
		{ title	= LOC "$$$/PSUpload/CollectionSettings/PublishModeOptConv=Convert: Convert collection to current version.",												value 	= 'Convert' },
	}
	
	if isAskForMissingParams then
		table.remove(publishModeItems, 1)
	end

    return
		f:row {
			alignment 		= 'left',
			fill_horizontal = 1,

			f:static_text {
				title		= LOC "$$$/PSUpload/CollectionSettings/PublishMode=Publish Mode:",
				alignment 	= 'right',
				width 		= share 'labelWidth',
			},

			f:popup_menu {
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/PublishModeTT=How to publish",
				items 			= publishModeItems,
				alignment 		= 'left',
--				fill_horizontal = 1,
				value 			= bind 'publishMode',
			},
		}
end

-------------------------------------------------------------------------------
-- downloadModeView(f, propertyTable, isAskForMissingParams)
function PSDialogs.downloadModeView(f, propertyTable, isAskForMissingParams)
	local downloadModeItems = {
		{ title	= LOC "$$$/PSUpload/Dialogs/ListBox/OptAsk=Ask me later",		value 	= 'Ask' },
		{ title	= LOC "$$$/PSUpload/Dialogs/ListBox/OptEnabled=Yes (enabled)",	value 	= 'Yes' },
		{ title	= LOC "$$$/PSUpload/Dialogs/ListBox/OptDisabled=No (disabled)",	value 	= 'No'  },
	}
	
	if isAskForMissingParams then
		table.remove(downloadModeItems, 1)
	end

    return
		f:row {
			alignment 		= 'left',
			fill_horizontal = 1,

			f:static_text {
				title		= LOC "$$$/PSUpload/CollectionSettings/DownloadMode=Metadata Download:",
				alignment 	= 'right',
				width 		= share 'labelWidth',
			},

			f:popup_menu {
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/DownloadModeTT=Enable metadata download",
				items 			= downloadModeItems,
				alignment 		= 'left',
--				fill_horizontal = 1,
				value 			= bind 'downloadMode',
			},
		}
end

-------------------------------------------------------------------------------
-- loglevelView(f, propertyTable, isAskForMissingParams)
function PSDialogs.loglevelView(f, propertyTable, isAskForMissingParams)
	local loglevelItems = {
		{ title	= LOC "$$$/PSUpload/Dialogs/ListBox/OptAsk=Ask me later",				value 	= 9999 },
		{ title	= LOC "$$$/PSUpload/CollectionSettings/LoglevelOptNothing=Nothing",		value 	= 0 },
		{ title	= LOC "$$$/PSUpload/CollectionSettings/LoglevelOptErrors=Errors",		value 	= 1 },
		{ title	= LOC "$$$/PSUpload/CollectionSettings/LoglevelOptNormal=Normal",		value 	= 2 },
		{ title	= LOC "$$$/PSUpload/CollectionSettings/LoglevelOptTrace=Trace",			value 	= 3 },
		{ title	= LOC "$$$/PSUpload/CollectionSettings/LoglevelOptDebug=Debug",			value 	= 4 },
	}
	
	if isAskForMissingParams then
		table.remove(loglevelItems, 1)
	end

	return 
		f:row {
			fill_horizontal = 1,
			f:static_text {
				title 			= LOC "$$$/PSUpload/DialogsFooter/Loglevel=Loglevel:",
				alignment 		= 'right',
				width			= share 'labelWidth'
			},

			f:popup_menu {
				tooltip 		= LOC "$$$/PSUpload/DialogsFooter/LoglevelTT=The level of log details",
				items 			= loglevelItems,		
				fill_horizontal = 0, 
				value 			= bind 'logLevel',
			},
			
			f:spacer { fill_horizontal = 1,	},
			
			f:push_button {
				title 			= LOC "$$$/PSUpload/DialogsFooter/Logfile=Show Logfile",
				tooltip 		= LOC "$$$/PSUpload/DialogsFooter/LogfileTT=Show Photo StatLr Logfile in Explorer/Finder.",
				alignment 		= 'right',
				fill_horizontal = 1,
				action 			= function()
					LrShell.revealInShell(getLogFilename())
				end,
			},    		
    	}
end
