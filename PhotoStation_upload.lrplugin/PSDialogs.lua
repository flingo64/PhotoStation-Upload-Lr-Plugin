--[[----------------------------------------------------------------------------

PSDialogs.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2015-2022, Martin Messmer

Dialogs and validations for Photo StatLr
	- validateDirectory
	- validateProgram
	- validatePSUploadProgPath

	- converterToolsView
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
require "PSPhotoServer"

local bind 				= LrView.bind
local conditionalItem 	= LrView.conditionalItem
local share 			= LrView.share

local negativeOfKey 	= LrBinding.negativeOfKey
local keyIsNot 			= LrBinding.keyIsNot
local keyIsNotNil 		= LrBinding.keyIsNotNil
local andAllKeys		= LrBinding.andAllKeys


--============================================================================--

PSDialogs = {}


--============================ complex key binding checks ===================================================
local checkPersonalAreaOwner = {
	keys 		= { 'psVersion',  'usePersonalPS' },
	operation 	= function( binder, values, fromTable )
		return 	PHOTOSERVER_API.supports(values.psVersion, PHOTOSERVER_PERSONALAREA_XUPLOAD)
				and values.usePersonalPS
	end,
}

local checkAddVideoSupport = {
	key			= 'psVersion',
	transform 	= function( value, fromTable )
		return PHOTOSERVER_API.supports(value, PHOTOSERVER_UPLOAD_VIDEO_ADD)
	end,
}

local checkAddVideoSelected = {
	keys 		= { 'psVersion',  'addVideoQuality' },
	operation 	= function( binder, values, fromTable )
		return 	PHOTOSERVER_API.supports(values.psVersion, PHOTOSERVER_UPLOAD_VIDEO_ADD)
				and values.addVideoQuality ~= -1
	end,
}

local checkTitleSupport = {
	key			= 'psVersion',
	transform 	= function( value, fromTable )
		return PHOTOSERVER_API.supports(value, PHOTOSERVER_METADATA_TITLE)
	end,
}

local checkDescriptionSupport = {
	key			= 'psVersion',
	transform 	= function( value, fromTable )
		return PHOTOSERVER_API.supports(value, PHOTOSERVER_METADATA_DESCRIPTION)
	end,
}

local checkPubLabelSupport = {
	key			= 'psVersion',
	transform 	= function( value, fromTable )
		return PHOTOSERVER_API.supports(value, PHOTOSERVER_METADATA_LABEL_PUB)
	end,
}

local checkRatingSupport = {
	key			= 'psVersion',
	transform 	= function( value, fromTable )
		return PHOTOSERVER_API.supports(value, PHOTOSERVER_METADATA_RATING)
	end,
}

local checkGPSSupport = {
	key			= 'psVersion',
	transform 	= function( value, fromTable )
		return PHOTOSERVER_API.supports(value, PHOTOSERVER_METADATA_GPS)
	end,
}

local checkLocationSupport = {
	key			= 'psVersion',
	transform 	= function( value, fromTable )
		return PHOTOSERVER_API.supports(value, PHOTOSERVER_METADATA_LOCATION)
	end,
}

local checkLocationSelected = {
	keys 		= { 'psVersion',  'xlatLocationTags' },
	operation 	= function( binder, values, fromTable )
		return 	PHOTOSERVER_API.supports(values.psVersion, PHOTOSERVER_METADATA_LOCATION)
				and values.xlatLocationTags
	end,
}

local checkFaceSupport = {
	key			= 'psVersion',
	transform 	= function( value, fromTable )
		return PHOTOSERVER_API.supports(value, PHOTOSERVER_METADATA_FACE)
	end,
}

local checkTagSupport = {
	key			= 'psVersion',
	transform 	= function( value, fromTable )
		return PHOTOSERVER_API.supports(value, PHOTOSERVER_METADATA_TAG)
	end,
}

local checkPrivCommentSupport = {
	key			= 'psVersion',
	transform 	= function( value, fromTable )
		return PHOTOSERVER_API.supports(value, PHOTOSERVER_METADATA_COMMENT_PRIV)
	end,
}

local checkPubCommentSupport = {
	key			= 'psVersion',
	transform 	= function( value, fromTable )
		return PHOTOSERVER_API.supports(value, PHOTOSERVER_METADATA_COMMENT_PUB)
	end,
}
--============================ validate functions ===========================================================

-------------------------------------------------------------------------------
-- validateSeperator: check if a string is a valid string seperator (must be exactly 1 char)
function PSDialogs.validateSeperator( view, value )
	if string.match(value, '(.)') ~= value then
		return false, string.sub(value, 1)
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
-- validateProgram: check if a given path points to a local program file
function PSDialogs.validateProgram( view, path )
	if LrFileUtils.exists(path) ~= 'file' then
		return false, path
	end

	return true, LrPathUtils.standardizePath(path)
end

-------------------------------------------------------------------------------
-- validatePluginFile: check if a given filenam exists in the PLUGIN dir
function PSDialogs.validatePluginFile( view, path )
	if LrFileUtils.exists(LrPathUtils.child(_PLUGIN.path, path)) ~= 'file' then
		return false, path
	end

	return true, path
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

--============================ Dialog control ===================================================================

-------------------------------------------------------------------------------
-- updateDialogStatus: do some sanity check on dialog settings
function PSDialogs.updateDialogStatus( propertyTable )
	local prefs = LrPrefs.prefsForPlugin()

	local message = nil

	repeat
		-- Use a repeat loop to allow easy way to "break" out.
		-- (It only goes through once.)

		-- ############### Pure Export/Publish Settings ##########################
		if not propertyTable.isCollection then
			if 		propertyTable.thumbGenerate
				and (	not PSDialogs.validateProgram(nil, prefs.convertprog)
					or 	not PSDialogs.validateProgram(nil, prefs.dcrawprog)
					)
			then
				message = LOC "$$$/PSUpload/Dialogs/Messages/ConverterPathMissing=Missing or incorrect path to converter tools. Fix it in Plugin Manager settings section."
				break
			end

			if propertyTable.servername == "" or propertyTable.servername == nil  then
				message = LOC "$$$/PSUpload/Dialogs/Messages/ServernameMissing=Enter a servername"
				break
			end

			if propertyTable.username == "" or propertyTable.username == nil  then
				message = LOC "$$$/PSUpload/Dialogs/Messages/UsernameMissing=Enter a username"
				break
			end

			if propertyTable.usePersonalPS then
				-- if PhotoServer supports uploading to Personal Area of a different owner, then the owner must be given
				if PHOTOSERVER_API.supports(propertyTable.psVersion, PHOTOSERVER_PERSONALAREA_XUPLOAD) then
					if ifnil(propertyTable.personalPSOwner, '') == '' then
						message = LOC "$$$/PSUpload/Dialogs/Messages/EnterPersPSUser=Enter the owner of the Personal Space to upload to"
						break
					end
				-- PhotoServer does not support uploading to Personal Area of a different owner: set personal owner to login username
				else
					propertyTable.personalPSOwner = propertyTable.username
				end
			end

			-- Check file format: PSD not supported by Photo Station, DNG only supported w/ embedded full-size jpg preview
			if (propertyTable.LR_format == 'PSD') or  (propertyTable.LR_format == 'DNG' and ifnil(propertyTable.LR_DNG_previewSize, '') ~= 'large') then
				message = LOC "$$$/PSUpload/Dialogs/Messages/FileFormatNoSupp=File format not supported! Select: [JPEG], [TIFF], [DNG w/ full-size JPEG preview] or [Original]."
				break
			end

			-- Export - renaming: either Lr or plugin renaming can be active
			if not propertyTable.LR_isExportForPublish and propertyTable.LR_renamingTokensOn and propertyTable.renameDstFile then
				message = LOC "$$$/PSUpload/Dialogs/Messages/RenameOption=Use either Lr File Renaming or Photo StatLr File Renaming, not both!"
				break
			end

			-- Publish Service Provider start ------------------------

			if propertyTable.LR_isExportForPublish and propertyTable.LR_renamingTokensOn then
				message = LOC "$$$/PSUpload/Dialogs/Messages/RenameNoSupp= Lr File Renaming option not supported in Publish mode!"
				break
			end

			if propertyTable.useSecondAddress and ifnil(propertyTable.servername2, "") == "" then
				message = LOC "$$$/PSUpload/Dialogs/Messages/Servername2Missing=Enter a secondary servername"
				break
			end

			-- Publish Service Provider end ---------------------

			propertyTable.serverUrl = propertyTable.proto .. "://" .. propertyTable.servername
			propertyTable.psPath 	= PHOTOSERVER_API[propertyTable.psVersion].API.basedir(propertyTable.serverUrl, iif(propertyTable.usePersonalPS, 'personal', 'shared'), iif(propertyTable.usePersonalPS, propertyTable.personalPSOwner))
			propertyTable.psUrl		= propertyTable.serverUrl .. propertyTable.psPath

			local serverUrl2		= propertyTable.proto2 .. "://" .. propertyTable.servername2
			propertyTable.psPath2 	= PHOTOSERVER_API[propertyTable.psVersion].API.basedir(serverUrl2, iif(propertyTable.usePersonalPS, 'personal', 'shared'), iif(propertyTable.usePersonalPS, propertyTable.personalPSOwner))
		end

		-- ###############  Export or Collection Settings ##########################

		if not propertyTable.LR_isExportForPublish or propertyTable.isCollection then
			if propertyTable.copyTree and not PSDialogs.validateDirectory(nil, propertyTable.srcRoot) then
				message = LOC "$$$/PSUpload/Dialogs/Messages/EnterSubPath=Enter a source path"
				break
			end

			if not PSDialogs.validateAlbumPath(nil, propertyTable.dstRoot) then
				message = LOC "$$$/PSUpload/Dialogs/Messages/InvalidAlbumPath=Target Album path is invalid"
				break
			end

			-- renaming: renaming dstFilename must contain at least one metadata placeholder
			if propertyTable.renameDstFile and not PSDialogs.validateMetadataPlaceholder(nil, propertyTable.dstFilename) then
				message = LOC "$$$/PSUpload/Dialogs/Messages/RenamePatternInvalid=Rename Photos: Missing placeholders or unbalanced { }!"
				break
			end

			-- Exif translation start -------------------

			-- if at least one translation is activated then set exifTranslate and make sure exiftoolprog is set
			propertyTable.exifTranslate = propertyTable.exifXlatFaceRegions or propertyTable.exifXlatLabel or propertyTable.exifXlatRating

			if propertyTable.exifTranslate and not PSDialogs.validateProgram(nil, prefs.exiftoolprog) then
				message = LOC "$$$/PSUpload/Dialogs/Messages/EnterExiftool=Missing or wrong exiftool path. Fix it in Plugin Manager settings section."
				break
			end

			-- Exif translation end -------------------

			-- Location tag translation -------------------
			if propertyTable.xlatLocationTags then
				if string.len(ifnil(propertyTable.locationTagSeperator, '')) > 1 then
					message = LOC "$$$/PSUpload/Dialogs/Messages/LocationTagSeperator=Tag separator must be empty or a single character"
					break
				end
				propertyTable.locationTagField2 = iif(propertyTable.locationTagField1, propertyTable.locationTagField2, false)
				propertyTable.locationTagField3 = iif(propertyTable.locationTagField2, propertyTable.locationTagField3, false)
				propertyTable.locationTagField4 = iif(propertyTable.locationTagField3, propertyTable.locationTagField4, false)
				propertyTable.locationTagField5 = iif(propertyTable.locationTagField4, propertyTable.locationTagField5, false)

				propertyTable.locationTagTemplate =
					table.concat(	{ iif(propertyTable.locationTagField1, propertyTable.locationTagField1, nil),
									  iif(propertyTable.locationTagField2, propertyTable.locationTagField2, nil),
									  iif(propertyTable.locationTagField3, propertyTable.locationTagField3, nil),
									  iif(propertyTable.locationTagField4, propertyTable.locationTagField4, nil),
									  iif(propertyTable.locationTagField5, propertyTable.locationTagField5, nil),
									},
									propertyTable.locationTagSeperator
								)
--				writeLogfile(4, string.format("updateDialogStatus: Location tag: %s\n", tostring(propertyTable.locationTagTemplate)))
			end
		end

		-- ############### Pure Collection Settings ##########################
		if propertyTable.isCollection then
			-- downloading translated tags makes only sense if we upload them also, otherwise they would dissappear after re-publish
			if not propertyTable.exifXlatFaceRegions 	then propertyTable.PS2LrFaces = false end
			if not propertyTable.exifXlatLabel 		then propertyTable.PS2LrLabel = false end
			if not propertyTable.exifXlatRating 		then propertyTable.PS2LrRating = false end

			-- exclusive or: rating download or rating tag download
			if propertyTable.ratingDownload and propertyTable.PS2LrRating then
				message = LOC "$$$/PSUpload/Dialogs/Messages/RatingOrRatingTag=You may either download the native rating or the translated rating tag from Photo Server."
				break
			end

			-- location tag download (blue pin): only possible if location download is enabled
			if not propertyTable.locationDownload then  propertyTable.locationTagDownload = false end
		end

	until true

	if message then
		propertyTable.hasError = true
		propertyTable.hasNoError = false
		propertyTable.message = 'Booo!! ' .. message
		if propertyTable.isCollection then
			propertyTable.LR_canSaveCollection = false
		else
			propertyTable.LR_cantExportBecause = 'Booo!! ' .. message
		end
	else
		propertyTable.hasError = false
		propertyTable.message = nil
		if propertyTable.isCollection then
			propertyTable.LR_canSaveCollection = true
		else
			propertyTable.hasNoError = true
			propertyTable.LR_cantExportBecause = nil
		end
	end

end

-------------------------------------------------------------------------------
-- addObservers: do some sanity check on dialog settings
function PSDialogs.addObservers( propertyTable )

	-- ############### Pure Export/Publish Settings ##########################

	if not propertyTable.isCollection then
    	propertyTable:addObserver( 'LR_renamingTokensOn', PSDialogs.updateDialogStatus )
    	propertyTable:addObserver( 'LR_tokens', PSDialogs.updateDialogStatus )
    	propertyTable:addObserver( 'LR_format', PSDialogs.updateDialogStatus )
    	propertyTable:addObserver( 'LR_DNG_previewSize', PSDialogs.updateDialogStatus )

    	propertyTable:addObserver( 'psVersion', PSDialogs.updateDialogStatus )
    	propertyTable:addObserver( 'proto', PSDialogs.updateDialogStatus )
    	propertyTable:addObserver( 'servername', PSDialogs.updateDialogStatus )
    	propertyTable:addObserver( 'useSecondAddress', PSDialogs.updateDialogStatus )
    	propertyTable:addObserver( 'servername2', PSDialogs.updateDialogStatus )
    	propertyTable:addObserver( 'username', PSDialogs.updateDialogStatus )
    	propertyTable:addObserver( 'usePersonalPS', PSDialogs.updateDialogStatus )
    	propertyTable:addObserver( 'personalPSOwner', PSDialogs.updateDialogStatus )
    	propertyTable:addObserver( 'thumbGenerate', PSDialogs.updateDialogStatus )
	end

	-- ###############  Export/Publish or Collection Settings ##########################

	propertyTable:addObserver( 'srcRoot', PSDialogs.updateDialogStatus )
	propertyTable:addObserver( 'dstRoot', PSDialogs.updateDialogStatus )
	propertyTable:addObserver( 'copyTree', PSDialogs.updateDialogStatus )
	propertyTable:addObserver( 'renameDstFile', PSDialogs.updateDialogStatus )
	propertyTable:addObserver( 'dstFilename', PSDialogs.updateDialogStatus )
	propertyTable:addObserver( 'exifXlatFaceRegions', PSDialogs.updateDialogStatus )
	propertyTable:addObserver( 'exifXlatLabel', PSDialogs.updateDialogStatus )
	propertyTable:addObserver( 'exifXlatRating', PSDialogs.updateDialogStatus )

	propertyTable:addObserver( 'xlatLocationTags', PSDialogs.updateDialogStatus )
	propertyTable:addObserver( 'locationTagSeperator', PSDialogs.updateDialogStatus )
	propertyTable:addObserver( 'locationTagField1', PSDialogs.updateDialogStatus )
	propertyTable:addObserver( 'locationTagField2', PSDialogs.updateDialogStatus )
	propertyTable:addObserver( 'locationTagField3', PSDialogs.updateDialogStatus )
	propertyTable:addObserver( 'locationTagField4', PSDialogs.updateDialogStatus )
	propertyTable:addObserver( 'locationTagField5', PSDialogs.updateDialogStatus )

	-- ############### Pure Collection Settings ##########################
	if propertyTable.isCollection then
    	propertyTable:addObserver( 'publishMode', PSDialogs.updateDialogStatus )
    	propertyTable:addObserver( 'locationDownload', PSDialogs.updateDialogStatus )
    	propertyTable:addObserver( 'ratingDownload', PSDialogs.updateDialogStatus )
    	propertyTable:addObserver( 'PS2LrRating', PSDialogs.updateDialogStatus )
	end

	PSDialogs.updateDialogStatus( propertyTable )
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
-- converterToolsView(f, propertyTable)
function PSDialogs.converterToolsView(f, propertyTable)
	return
        f:group_box {
			title	= 'Converter Tools',
			fill_horizontal = 1,

    		f:row {
    			f:static_text {
    				title 			= LOC "$$$/PSUpload/PluginDialog/ConverterDescription=Enter the paths of 'ImageMagick convert' and 'dcraw'.\nRequired, if you want to generate thumbs locally or upload videos.\n",
    			},
    		},

    		f:row {
    			f:static_text {
    				title 			= "ImageMagick convert:",
    				alignment 		= 'right',
    				width 			= share 'labelWidth',
    			},

    			f:edit_field {
    				truncation 		= 'middle',
    				immediate 		= true,
    				fill_horizontal = 1,
    				value 			= bind 'convertprog',
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
    					propertyTable.convertprog = PSConvert.defaultInstallPathIMConvert
    				end,
    			},

    			f:push_button {
    				title 			= LOC "$$$/PSUpload/PluginDialog/ProgSearch=Search",
    				tooltip 		= LOC "$$$/PSUpload/PluginDialog/ProgSearchTT=Search in Explorer/Finder.",
    				alignment 		= 'right',
    				fill_horizontal = 1,
    				action 			= function()
    					LrShell.revealInShell(getRootPath())
    				end,
    			},

    			f:push_button {
    				title 			= LOC "$$$/PSUpload/PluginDialog/ProgDownload=Download",
    				tooltip 		= LOC "$$$/PSUpload/PluginDialog/ProgDownloadTT=Download from Web.",
    				alignment 		= 'right',
    				fill_horizontal = 1,
    				action 			= function()
   						LrHttp.openUrlInBrowser(PSConvert.downloadUrlIMConvert)
    				end,
    			},
    		},

    		f:row {
    			f:static_text {
    				title 			= "dcraw:",
    				alignment 		= 'right',
    				width 			= share 'labelWidth',
    			},

    			f:edit_field {
    				truncation 		= 'middle',
    				immediate 		= true,
    				fill_horizontal = 1,
    				value 			= bind 'dcrawprog',
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
    					propertyTable.dcrawprog = PSConvert.defaultInstallPathDcraw
    				end,
    			},

    			f:push_button {
    				title 			= LOC "$$$/PSUpload/PluginDialog/ProgSearch=Search",
    				tooltip 		= LOC "$$$/PSUpload/PluginDialog/ProgSearchTT=Search in Explorer/Finder.",
    				alignment 		= 'right',
    				fill_horizontal = 1,
    				action 			= function()
    					LrShell.revealInShell(getRootPath())
    				end,
    			},

    			f:push_button {
    				title 			= LOC "$$$/PSUpload/PluginDialog/ProgDownload=Download",
    				tooltip 		= LOC "$$$/PSUpload/PluginDialog/ProgDownloadTT=Download from Web.",
    				alignment 		= 'right',
    				fill_horizontal = 1,
    				action 			= function()
   						LrHttp.openUrlInBrowser(PSConvert.downloadUrlDcraw)
    				end,
    			},
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
    				tooltip 		= LOC "$$$/PSUpload/PluginDialog/ProgSearchTT=Search in Explorer/Finder.",
    				alignment 		= 'right',
    				fill_horizontal = 1,
    				action 			= function()
    					LrShell.revealInShell(getRootPath())
    				end,
    			},

    			f:push_button {
    				title 			= LOC "$$$/PSUpload/PluginDialog/ProgDownload=Download",
    				tooltip 		= LOC "$$$/PSUpload/PluginDialog/ProgDownloadTT=Download from Web.",
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
-- videoConvSettingsView(f, propertyTable)
function PSDialogs.videoConvSettingsView(f, propertyTable)
	local prefs = LrPrefs.prefsForPlugin()

	return
        f:group_box {
			title	= "FFmpeg",
			fill_horizontal = 1,

    		f:row {
    			f:static_text {
    				title 			= LOC "$$$/PSUpload/PluginDialog/VideoConvSettingsDescription=Enter the path where the 'ffmpeg' program is installed.\nEnter the filename of the video conversion presets file (must be a JSON file in the plugin dir).\n",
    			},
    		},

    		f:row {
    			f:static_text {
    				title 			= "ffmpeg:",
    				alignment 		= 'right',
    				width 			= share 'labelWidth',
    			},

    			f:edit_field {
    				truncation 		= 'middle',
    				immediate 		= true,
    				fill_horizontal = 1,
    				value 			= bind 'ffmpegprog',
    				validate 		= PSDialogs.validateProgram,
    			},
			},
    		f:row {
    			f:static_text {
    				title 			= "Presets file:",
    				alignment 		= 'right',
    				width 			= share 'labelWidth',
    			},

    			f:edit_field {
    				truncation 		= 'middle',
    				immediate 		= true,
    				fill_horizontal = 1,
    				value 			= bind 'videoConversionsFn',
    				validate 		= PSDialogs.validatePluginFile,
    			},
    		},
    		f:row {
     			f:push_button {
    				title 			= LOC "$$$/PSUpload/PluginDialog/ProgDefault=Default",
    				tooltip 		= LOC "$$$/PSUpload/PluginDialog/ProgDefaultTT=Set to Default.",
    				alignment 		= 'right',
    				fill_horizontal = 1,
    				action 			= function()
						propertyTable.ffmpegprog = LrPathUtils.child(LrPathUtils.child(propertyTable.PSUploaderPath, 'ffmpeg'), 'ffmpeg') .. getProgExt()
    					propertyTable.videoConversionsFn = PSConvert.defaultVideoPresetsFn
    				end,
    			},

    			f:push_button {
    				title 			= LOC "$$$/PSUpload/PluginDialog/ProgSearch=Search",
    				tooltip 		= LOC "$$$/PSUpload/PluginDialog/ProgSearchTT=Search in Explorer/Finder.",
    				alignment 		= 'right',
    				fill_horizontal = 1,
    				action 			= function()
    					LrShell.revealInShell(LrPathUtils.child(_PLUGIN.path, prefs.videoConversionsFn))
    				end,
    			},

				f:push_button {
    				title 			= LOC "$$$/PSUpload/PluginDialog/ProgDownload=Download",
    				tooltip 		= LOC "$$$/PSUpload/PluginDialog/ProgDownloadTT=Download from Web.",
    				alignment 		= 'right',
    				fill_horizontal = 1,
    				action 			= function()
   						LrHttp.openUrlInBrowser(PSConvert.downloadUrlFfmpeg)
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

	local versionItems = {}
    for key, entry in pairs(PHOTOSERVER_API) do
        if isNumber(key) then
            table.insert(versionItems, { title = entry.name, value = key })
        end
    end
    table.sort(versionItems, function (a, b) return (a.value < b.value) end)

	local fileTimestampItems = {
        { title	= 'Photo Capture Date/Time', 							value = 'capture' },
        { title	= 'Upload Date/Time', 									value = 'upload' },
        { title = 'Upload Date for Photos, Capture Date for Videos',	value = 'mixed' },
	}

	return
        f:group_box {
        	fill_horizontal = 1,
        	title = LOC "$$$/PSUpload/ExportDialog/TargetPS=Photo Server",

        	f:row {
				f:static_text {
					title 			= LOC "$$$/PSUpload/ExportDialog/PSVersion=Version:",
					alignment 		= 'right',
        			width 			= share 'labelWidth',
				},

        		f:popup_menu {
        			tooltip			= LOC "$$$/PSUpload/ExportDialog/PSVersionListTT=Photo Server Version",
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
        			tooltip 		= LOC "$$$/PSUpload/ExportDialog/ServernameTT=Enter the IP address or hostname of Photo Server.\nNon-standard port may be appended as :port",
        			truncation 		= 'middle',
        			immediate 		= true,
					width_in_chars	= 18,
        			fill_horizontal = 0.8,
        			value 			= bind 'servername',
        			enabled 		= negativeOfKey 'useSecondAddress',
					validate		= PHOTOSERVER_API[propertyTable.psVersion].API.validateServername
        		},

				f:static_text {
					title 			= bind 'psPath',
        			truncation 		= 'middle',
					width_in_chars	= 20,
        			immediate 		= true,
        			fill_horizontal = 0.2,
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
        			fill_horizontal = 0.8,
					width_in_chars	= 18,
        			value 			= bind 'servername2',
        			enabled 		= bind 'useSecondAddress',
					validate		= PHOTOSERVER_API[propertyTable.psVersion].API.validateServername
        		},

				f:static_text {
					title 			= bind 'psPath2',
        			truncation 		= 'middle',
					width_in_chars	= 20,
        			immediate 		= true,
        			fill_horizontal = 0.2,
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
					title 			=	LOC "$$$/PSUpload/ExportDialog/StandardPS=Shared Space",
					alignment 		= 'left',
					width 			= share 'labelWidth',
					value 			= bind 'usePersonalPS',
					checked_value 	= false,
				},

				f:radio_button {
					title 			= LOC "$$$/PSUpload/ExportDialog/PersonalPS=Personal Space of User:",
					alignment 		= 'left',
					value 			= bind 'usePersonalPS',
					checked_value 	= true,
				},

				f:edit_field {
					tooltip 		= LOC "$$$/PSUpload/ExportDialog/PersonalPSTT=Enter the name of the owner of the Personal Space you want to upload to.",
					truncation 		= 'middle',
					immediate 		= true,
					fill_horizontal = 1,
					value 			= bind 'personalPSOwner',
					enabled 		= bind(checkPersonalAreaOwner),
					visible 		= bind(checkPersonalAreaOwner)
				},
			},

			f:row {
				f:static_text {
					title 			= LOC "$$$/PSUpload/ExportDialog/Username=Username:",
					alignment 		= 'right',
					width 			= share 'labelWidth'
				},

				f:edit_field {
					tooltip 		= LOC "$$$/PSUpload/ExportDialog/UsernameTT=Enter the username for Photo Server access.",
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
					tooltip 		= LOC "$$$/PSUpload/ExportDialog/PasswordOptTT=Enter the password for Photo Server access.\nLeave this field blank, if you don't want to store the password.\nYou will be prompted for the password later.",
					truncation 		= 'middle',
					immediate 		= true,
					fill_horizontal = 1,
					value 			= bind 'password',
				},
			},

			f:separator { fill_horizontal = 1 },

			f:row {
				f:static_text {
					title 			= LOC "$$$/PSUpload/ExportDialog/DstFileTimestamp=Upload timestamp:",
					alignment 		= 'right',
					width 			= share 'labelWidth'
				},

    			f:popup_menu {
    				tooltip 		= LOC "$$$/PSUpload/ExportDialog/DstFileTimestampTT=Choose the file timestamp for the uploaded photo/video",
    				items 			= fileTimestampItems,
    				alignment 		= 'left',
    				value 			= bind 'uploadTimestamp',
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
		{ title	= LOC "$$$/PSUpload/Dialogs/ListBox/None=None",		value 	= 'None' },
		{ title	= LOC "$$$/PSUpload/Dialogs/ListBox/Low=Low",		value 	= 'LOW' },
		{ title	= LOC "$$$/PSUpload/Dialogs/ListBox/Medium=Medium",	value 	= 'MED' },
		{ title	= LOC "$$$/PSUpload/Dialogs/ListBox/High=High",		value 	= 'HIGH' },
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
	local orgVideoForceConvItems = {
		{ title	= 'If required',		value 	= false },
		{ title	= 'Always',				value 	= true },
	}

	local lowResAddVideoItems	= {
		{ title	= 'None',			value 	= 'None' },
		{ title	= 'Mobile/240',		value 	= 'MOBILE' },
	}

	local medResAddVideoItems	= tableShallowCopy(lowResAddVideoItems)
	table.insert(medResAddVideoItems,
		{ title	= 'Low/360',		value 	= 'LOW' })

	local highResAddVideoItems	= tableShallowCopy(medResAddVideoItems)
	table.insert(highResAddVideoItems,
		{ title	= 'Medium/720',		value 	= 'MEDIUM' })

	local ultraResAddVideoItems	= tableShallowCopy(highResAddVideoItems)
	table.insert(ultraResAddVideoItems,
		{ title	= 'High/1080',		value 	= 'HIGH' })

	local videoConvQualityItems = {}
	local convOptions = PSConvert.getVideoConvPresets()

	if not convOptions then
		writeLogfile(1, "PSDialogs.videoOptionsView: video preset file is not a valid JSON file!\n")
		table.insert(videoConvQualityItems,	{ title	= 'Invalid presets file',	value 	= -1 })
		local action = LrDialogs.confirm("Video Conversion", 'Booo!!\n' .. "Invalid video presets file", "Go to Logfile", "Never mind")
		if action == "ok" then
			LrShell.revealInShell(getLogFilename())
		end
	else
		for key, val in ipairs(convOptions) do
			table.insert(videoConvQualityItems,	{ title	= val.title,	value 	= key })
		end
	end


	local addVideoConvQualityItems 	= tableShallowCopy(videoConvQualityItems)
	table.insert(addVideoConvQualityItems, 1, { title	= 'None',	value 	= -1 })

	return
		f:group_box {
			title 			= LOC "$$$/PSUpload/ExportDialog/Videos=Video Upload Options / Additional video resolutions for ...-Res Videos",
			fill_horizontal = 1,

			f:row {
				fill_horizontal = 1,

				f:row {
					fill_horizontal = 1,

					f:static_text {
						title 			= LOC "$$$/PSUpload/ExportDialog/VideoOrgConv=Convert video:",
						alignment 		= 'right',
					},

					f:popup_menu {
						tooltip 		= LOC "$$$/PSUpload/ExportDialog/VideoOrgConvTT=When to convert the original video",
						items 			= orgVideoForceConvItems,
						alignment 		= 'left',
						value 			= bind 'orgVideoForceConv',
					},
				},

				f:row {
					fill_horizontal = 1,

					f:static_text {
						title 			= LOC "$$$/PSUpload/ExportDialog/VideoOrgQuality=Quality:",
						alignment 		= 'right',
					},

					f:popup_menu {
						tooltip 		= LOC "$$$/PSUpload/ExportDialog/VideoOrgQualityTT=Video quality for converted original video",
						items 			= videoConvQualityItems,
						alignment 		= 'left',
						value 			= bind 'orgVideoQuality',
					},
				},

				f:checkbox {
					fill_horizontal = 1,
					title 			= LOC "$$$/PSUpload/ExportDialog/HardRotate=Hard-rotation",
					tooltip 		= LOC "$$$/PSUpload/ExportDialog/HardRotateTT=Use hard-rotation for better player compatibility,\nwhen a video is soft-rotated or meta-rotated\n(keywords include: 'Rotate-90', 'Rotate-180' or 'Rotate-270')",
					alignment 		= 'left',
					value 			= bind 'hardRotate',
				},

				f:separator { fill_vertical = 1, visible = bind(checkAddVideoSupport) },

				f:row {
					fill_horizontal = 1,

					f:static_text {
						title 			= LOC "$$$/PSUpload/ExportDialog/VideoAddQuality=Add. video:",
						alignment 		= 'right',
						visible			= bind(checkAddVideoSupport)
					},

					f:popup_menu {
						tooltip 		= LOC "$$$/PSUpload/ExportDialog/VideoAddQualityTT=Video quality for additional video",
						items 			= addVideoConvQualityItems,
						alignment 		= 'left',
						value 			= bind 'addVideoQuality',
						fill_horizontal = 1,
						visible			= bind(checkAddVideoSupport)
					},
				},
			},

			f:separator { fill_horizontal = 0.75, visible = bind(checkAddVideoSelected) },

			f:row {
				fill_horizontal = 1,

				f:row {
					alignment = 'left',
					fill_horizontal = 1,

					f:static_text {
						title 			= LOC "$$$/PSUpload/ExportDialog/VideoUltra=Ultra:",
						visible			= bind(checkAddVideoSelected),
						alignment 		= 'right',
					},

					f:popup_menu {
						tooltip 		= LOC "$$$/PSUpload/ExportDialog/VideoUltraTT=Generate additional video for Ultra-Hi-Res (2160p) videos",
						items 			= ultraResAddVideoItems,
						visible			= bind(checkAddVideoSelected),
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
						visible			= bind(checkAddVideoSelected),
						alignment 		= 'right',
					},

					f:popup_menu {
						tooltip 		= LOC "$$$/PSUpload/ExportDialog/VideoHighTT=Generate additional video for Hi-Res (1080p) videos",
						items 			= highResAddVideoItems,
						visible			= bind(checkAddVideoSelected),
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
						visible			= bind(checkAddVideoSelected),
						alignment 		= 'right',
					},

					f:popup_menu {
						tooltip 		= LOC "$$$/PSUpload/ExportDialog/VideoMedTT=Generate additional video for Medium-Res (720p) videos",
						items 			= medResAddVideoItems,
						visible			= bind(checkAddVideoSelected),
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
						visible			= bind(checkAddVideoSelected),
						alignment 		= 'right',
					},

					f:popup_menu {
						tooltip 		= LOC "$$$/PSUpload/ExportDialog/VideoLowTT=Generate additional video for Low-Res (360p) videos",
						items 			= lowResAddVideoItems,
						visible			= bind(checkAddVideoSelected),
						alignment 		= 'left',
						fill_horizontal = 1,
						value 			= bind 'addVideoLow',
					},
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
    				tooltip 	= LOC "$$$/PSUpload/ExportDialog/StoreDstRootTT=Enter target folder here or you will be prompted for it when the upload starts.",
    				alignment 	= 'left',
    				width 		= share 'labelWidth',
    				value 		= bind 'storeDstRoot',
    				enabled 	=  negativeOfKey 'isCollection',
				}
			),

			f:edit_field {
					tooltip = LOC "$$$/PSUpload/ExportDialog/DstRootTT=Enter the target folder.",
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
				tooltip = LOC "$$$/PSUpload/ExportDialog/DstRootTT=Enter the target folder.",
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

			conditionalItem(propertyTable.isCollection, f:row {
				f:checkbox {
					title 			= LOC "$$$/PSUpload/ExportDialog/SortPhotos=Sort Photos",
					tooltip 		= LOC "$$$/PSUpload/ExportDialog/SortPhotosTT=Sort photos in Photo Server according to sort order of Published Collection.\nNote: Sorting is only possible for collections with 'Sort: Custom Order' when uploading to a flat album.",
					alignment 		= 'left',
					fill_horizontal = 1,
					value 			= bind 'sortPhotos',
					enabled 		= negativeOfKey 'copyTree',
				},
			}),
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
    				tooltip 	= LOC "$$$/PSUpload/ExportDialog/RenamePhotoTT=Rename photos in Photo Server acc. to a unique naming schema.",
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
					tooltip 		= LOC "$$$/PSUpload/ExportDialog/RAWandJPGTT=Allow Lr-developed RAW+JPG from camera to be uploaded to same Album.\nNote: All Non-JPEG photos will be renamed in Photo Server to <photoname>_<OrigExtension>.<OutputExtension>. E.g.:\nIMG-001.RW2 --> IMG-001_RW2.JPG\nIMG-001.JPG --> IMG-001.JPG",
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
	local locationTagItems	= {
		{ title	= '',				value 	= false }, -- Note: Export Presets cannot store Nil values!
		{ title	= 'ISO Code',		value 	= '{LrFM:isoCountryCode}' },
		{ title	= 'Country',		value 	= '{LrFM:country}' },
		{ title	= 'State',			value 	= '{LrFM:stateProvince}' },
		{ title	= 'City',			value 	= '{LrFM:city}' },
		{ title	= 'Location',		value 	= '{LrFM:location}' },
	}
	local locationTagSepItems	= { ' ', '-', '_', ':', ';', '/', '|',',', '.', '+', '#' }

	return	f:group_box {
		fill_horizontal = 1,
		title = LOC "$$$/PSUpload/ExportDialog/UploadOpt=Metadata Upload Options /Translations (To Photo Server)",

		f:row {
			f:checkbox {
				title 			= LOC "$$$/PSUpload/ExportDialog/TitleUpload=Title (always)",
				fill_horizontal = 1,
				value 			= true,
				enabled 		= false,
				visible			= bind(checkTitleSupport),
			},

			f:checkbox {
				title 			= LOC "$$$/PSUpload/ExportDialog/CaptionUpload=Decription (always)",
				fill_horizontal = 1,
				value 			= true,
				enabled 		= false,
				visible			= bind(checkDescriptionSupport),
			},

			f:checkbox {
				title 			= LOC "$$$/PSUpload/ExportDialog/LocationUpload=GPS (always)",
				fill_horizontal = 1,
				value 			= true,
				enabled 		= false,
				visible			= bind(checkGPSSupport),
			},

			f:checkbox {
				title 			= LOC "$$$/PSUpload/ExportDialog/RatingUpload=Rating (always)",
				fill_horizontal = 1,
				value 			= true,
				enabled 		= false,
				visible			= bind(checkRatingSupport),
			},

		},

    	f:row {
    		f:checkbox {
    			title 			= LOC "$$$/PSUpload/ExportDialog/KeywordUpload=Keywords (always)",
    			fill_horizontal = 1,
    			value 			= true,
    			enabled 		= false,
				visible			= bind(checkTagSupport),
    		},

    		f:checkbox {
    			title 			= LOC "$$$/PSUpload/ExportDialog/TranslateFaceRegions=Faces",
    			tooltip 		= LOC "$$$/PSUpload/ExportDialog/TranslateFaceRegionsTT=Translate Lr face regions to Photo Server person tags\n(Useful for Photo Station version < 6.5)",
    			fill_horizontal = 1,
    			value 			= bind 'exifXlatFaceRegions',
				visible			= bind(checkFaceSupport),
    		},

    		f:checkbox {
    			title 			= LOC "$$$/PSUpload/ExportDialog/TranslateLabel=Color Label Tag",
    			tooltip 		= LOC "$$$/PSUpload/ExportDialog/TranslateLabelTT=Translate Lr color label (red, green, ...) to Photo Server '+color' general tag",
    			fill_horizontal = 1,
    			value 			= bind 'exifXlatLabel',
				visible			= bind(checkTagSupport),
    		},

    		f:checkbox {
    			title 			= LOC "$$$/PSUpload/ExportDialog/TranslateRating=Rating Tag",
    			tooltip 		= LOC "$$$/PSUpload/ExportDialog/TranslateRatingTT=Translate Lr rating (*stars*) to Photo Server '***' general tag\n(Useful for Photo Station version < 6.5)",
    			fill_horizontal = 1,
    			value 			= bind 'exifXlatRating',
				visible			= bind(checkTagSupport),
    		},
    	},

    	f:separator { fill_horizontal = 1 },

    	f:row {
			fill_horizontal = 1,

    		f:checkbox {
    			title 			= LOC "$$$/PSUpload/ExportDialog/TranslateLocation=Location Tag:",
    			tooltip 		= LOC "$$$/PSUpload/ExportDialog/TranslateLocationTT=Translate Lr location tags to Photo Server location tag",
    			value 			= bind 'xlatLocationTags',
   				fill_horizontal = 1,
				visible			= bind(checkLocationSupport),
			},

			f:popup_menu {
				value 			= bind 'locationTagField1',
				visible 		= bind(checkLocationSelected),
				enabled 		= keyIsNotNil 'xlatLocationTags',
				items 			= locationTagItems,
				tooltip 		 = LOC "$$$/PSUpload/ExportDialog/LocationTagFieldTT=Enter a Lr location tag to be used",
   				alignment 		= 'center',
   				fill_horizontal = 1,
			},

			f:combo_box {
				value 			= bind 			'locationTagSeperator',
				visible 		= bind			(checkLocationSelected),
				enabled			= andAllKeys	('locationTagField2'),
				items 			= locationTagSepItems,
				tooltip 		 = LOC "$$$/PSUpload/ExportDialog/LocationTagSeperatorTT=Enter a tag seperator character",
				immediate 		= true,
				validate 		= PSDialogs.validateSeperator,
   				fill_horizontal = 0.08,
			},

			f:popup_menu {
				value 			= bind 			'locationTagField2',
				visible 		= bind			(checkLocationSelected),
				enabled			= andAllKeys	('locationTagField1'),
				items 			= locationTagItems,
				tooltip 		 = LOC "$$$/PSUpload/ExportDialog/LocationTagFieldTT=Enter a Lr location tag to be used",
   				alignment 		= 'center',
   				fill_horizontal = 1,
			},

			f:static_text {
				title 			= bind 			'locationTagSeperator',
				visible 		= bind			(checkLocationSelected),
				enabled 		= andAllKeys	('xlatLocationTags', 'locationTagField3'),
   				alignment 		= 'center',
--   				fill_horizontal = 0.05,
			},

			f:popup_menu {
				value 			= bind 			'locationTagField3',
				visible 		= bind			(checkLocationSelected),
				enabled			= andAllKeys	('locationTagField2'),
				items 			= locationTagItems,
				tooltip 		 = LOC "$$$/PSUpload/ExportDialog/LocationTagFieldTT=Enter a Lr location tag to be used",
   				alignment 		= 'center',
   				fill_horizontal = 1,
			},

			f:static_text {
				title 			= bind 			'locationTagSeperator',
				visible 		= bind			(checkLocationSelected),
				enabled 		= andAllKeys	('xlatLocationTags', 'locationTagField4'),
   				alignment 		= 'center',
--   				fill_horizontal = 0.05,
			},

			f:popup_menu {
				value 			= bind 			'locationTagField4',
				visible 		= bind			(checkLocationSelected),
				enabled			= andAllKeys	('locationTagField3'),
				items 			= locationTagItems,
				tooltip 		 = LOC "$$$/PSUpload/ExportDialog/LocationTagFieldTT=Enter a Lr location tag to be used",
   				alignment 		= 'center',
   				fill_horizontal = 1,
			},

			f:static_text {
				title 			= bind 			'locationTagSeperator',
				visible 		= bind			(checkLocationSelected),
				enable 			= andAllKeys	('xlatLocationTags', 'locationTagField5'),
   				alignment 		= 'center',
--   				fill_horizontal = 0.05,
			},

			f:popup_menu {
				value 			= bind 			'locationTagField5',
				visible 		= bind			(checkLocationSelected),
				enabled			= andAllKeys	('locationTagField4'),
				items 			= locationTagItems,
				tooltip 		 = LOC "$$$/PSUpload/ExportDialog/LocationTagFieldTT=Enter a Lr location tag to be used",
   				alignment 		= 'center',
   				fill_horizontal = 1,
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
		title = LOC "$$$/PSUpload/ExportDialog/DownloadOpt=Metadata Download Options / Translations  (From Photo Server)",

		f:row {
			f:checkbox {
				title 			= LOC "$$$/PSUpload/CollectionSettings/TitleDownload=Title",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/TitleDownloadTT=Download photo title tag from Photo Server",
				fill_horizontal = 1,
				value 			= bind 'titleDownload',
				visible			= bind(checkTitleSupport),
			},

			f:checkbox {
				title 			= LOC "$$$/PSUpload/CollectionSettings/CaptionDownload=Description",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/CaptionDownloadTT=Download photo description (caption) from Photo Server",
				fill_horizontal = 1,
				value 			= bind 'captionDownload',
				visible			= bind (checkDescriptionSupport),
			},

			f:row {
    			fill_horizontal = 1,
    			f:checkbox {
    				title 			= LOC "$$$/PSUpload/CollectionSettings/LocationDownload=GPS (red)",
    				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/LocationDownloadTT=Download GPS info of the photo (red pin) from Photo Server",
    				value 			= bind 'locationDownload',
					visible			= bind (checkGPSSupport),
    			},
    			f:checkbox {
    				title 			= LOC "$$$/PSUpload/CollectionSettings/LocationTagDownload=GPS (blue)",
    				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/LocationTagDownloadTT=Download GPS info of the photo's location tag (blue pin) from Photo Server.\nRed pin has preference over blue pin. Download of blue pin GPS takes significantly more time!",
    				value 			= bind 'locationTagDownload',
    				enabled			= bind 'locationDownload',
					visible			= bind (checkGPSSupport),
    			},
    		},

			f:checkbox {
				title 			= LOC "$$$/PSUpload/CollectionSettings/RatingDownload=Rating",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/RatingDownloadTT=Download rating from Photo Server",
				fill_horizontal = 1,
				value 			= bind 'ratingDownload',
				visible			= bind(checkRatingSupport),
			},

		},

		f:row {
			f:checkbox {
				title 			= LOC "$$$/PSUpload/CollectionSettings/TagsDownload=Tags/Keywords",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/TagsDownloadTT=Download tags from Photo Server to Lr keywords",
				fill_horizontal = 1,
				value 			= bind 'tagsDownload',
				visible			= bind (checkTagSupport),
			},

			f:checkbox {
				fill_horizontal = 1,
				title 			= LOC "$$$/PSUpload/CollectionSettings/PSTranslateFaces=Faces",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/PSTranslateFacesTT=Download and translate Photo Server People Tags to Lightroom Faces\nNote: Faces will be written to original photo and photo metadata must be re-loaded into Lr\n!!! Make sure, you configured 'Automatically write changes into XMP, otherwise\nyou will loose you Lr changes when re-loading faces metadata!!!'",
				value 			= bind 'PS2LrFaces',
				enabled 		= bind 'exifXlatFaceRegions',
				visible			= bind (checkFaceSupport),
			},

			f:checkbox {
				title 			= LOC "$$$/PSUpload/CollectionSettings/PSTranslateLabel=Color Label Tag",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/PSTranslateLabelTT=Translate Photo Server '+color' general tag to Lr color label (red, green, ...)",
				fill_horizontal = 1,
				value 			= bind 'PS2LrLabel',
				enabled 		= bind 'exifXlatLabel',
				visible			= bind (checkTagSupport),
			},

			f:checkbox {
				title 			= LOC "$$$/PSUpload/CollectionSettings/PSTranslateRating=Rating Tag",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/PSTranslateRatingTT=Translate Photo Server '***' general tag to Lr rating\n(Useful for Photo Server version < 6.5)",
				fill_horizontal = 1,
				value 			= bind 'PS2LrRating',
				enabled 		= bind 'exifXlatRating',
				visible			= bind (checkTagSupport),
			},
		},

		f:separator { fill_horizontal = 1 },

		f:row {
			f:checkbox {
				title 			= LOC "$$$/PSUpload/CollectionSettings/CommentsDownload=Private Comments",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/CommentsDownloadTT=Download photo comments from Photo Server (internal) to Lr Comments panel",
				fill_horizontal = 1,
				value 			= bind 'commentsDownload',
				visible			= bind (checkPrivCommentSupport),
			},

			f:checkbox {
				title 			= LOC "$$$/PSUpload/CollectionSettings/PublicCommentsDownload=Public Comments",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/PublicCommentsDownloadTT=Download photo comments from Photo Server public shares to Lr Comments panel",
				fill_horizontal = 1,
				value 			= bind 'pubCommentsDownload',
				visible			= bind (checkPubCommentSupport),
			},

			f:checkbox {
				title 			= LOC "$$$/PSUpload/CollectionSettings/PublicColorDownload=Public Color",
				tooltip 		= LOC "$$$/PSUpload/CollectionSettings/PublicColorDownloadTT=Download photo color from Photo Server public shares to Lr Comments panel",
				fill_horizontal = 1,
				value 			= bind 'pubColorDownload',
				visible			= bind (checkPubLabelSupport),
			},
		},
	}
end

-------------------------------------------------------------------------------
-- publishModeView(f, propertyTable, isAskForMissingParams)
function PSDialogs.publishModeView(f, propertyTable, isAskForMissingParams)
	local publishModeItems = {
		{ title	= LOC "$$$/PSUpload/Dialogs/ListBox/OptAsk=Ask me later",																								value 	= 'Ask' },
		{ title	= LOC "$$$/PSUpload/CollectionSettings/PublishModeOptUpload=Upload: Normal publishing of photos",														value 	= 'Publish' },
		{ title	= LOC "$$$/PSUpload/CollectionSettings/PublishModeOptMetadata=MetadataUpload: Upload only metadata (for photos already in Photo Server)",				value 	= 'Metadata' },
		{ title	= LOC "$$$/PSUpload/CollectionSettings/PublishModeOptChkEx=CheckExisting: Set Unpublished to Published if existing in Photo Server.",					value 	= 'CheckExisting' },
		{ title	= LOC "$$$/PSUpload/CollectionSettings/PublishModeOptChkMv=CheckMoved: Set Published to Unpublished if moved locally.",									value 	= 'CheckMoved' },
		{ title	= LOC "$$$/PSUpload/CollectionSettings/PublishModeOptMove=MovePhotos: Move photos in Photo Server (for photos moved in Lr or changed target album).",	value 	= 'MovePhotos' },
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
		{ title	= LOC "$$$/PSUpload/CollectionSettings/LoglevelOptXDebug=X-Debug",		value 	= 5 },
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
