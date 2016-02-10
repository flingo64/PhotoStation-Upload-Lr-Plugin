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
local LrBinding		= import 'LrBinding'
local LrView 		= import 'LrView'
local LrPathUtils 	= import 'LrPathUtils'
local LrFileUtils	= import 'LrFileUtils'
local LrShell 		= import 'LrShell'

require "PSUtilities"

--============================================================================--

PSDialogs = {}

-- validateProgram: check if a given path points to a local program
function PSDialogs.validateProgram( view, path )
	if LrFileUtils.exists(path) ~= 'file'
	or getProgExt() and string.lower(LrPathUtils.extension( path )) ~= getProgExt() then
		return false, path
	end

	return true, LrPathUtils.standardizePath(path)	
end


-------------------------------------------------------------------------------
-- targetAlbumView(f, propertyTable)
--
function PSDialogs.targetAlbumView(f, propertyTable)
	local bind = LrView.bind
	local share = LrView.share
	local negativeOfKey = LrBinding.negativeOfKey

	return f:view {
		fill_horizontal = 1,

		f:group_box {
			fill_horizontal = 1,
			title = LOC "$$$/PSUpload/ExportDialog/TargetAlbum=Target Album and Upload Method",

			f:row {
				f:checkbox {
					title = LOC "$$$/PSUpload/ExportDialog/StoreDstRoot=Target Album:",
					tooltip = LOC "$$$/PSUpload/ExportDialog/StoreDstRootTT=Enter Target Album here or you will be prompted for it when the upload starts.",
					alignment = 'right',
					width = share 'labelWidth',
					value = bind 'storeDstRoot',
					enabled =  negativeOfKey 'isCollection',
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
					value = bind 'createDstRoot',
					enabled = bind 'storeDstRoot',
					visible = bind 'storeDstRoot',
					fill_horizontal = 1,
				},
			},
		
			f:row {

				f:radio_button {
					title = LOC "$$$/PSUpload/ExportDialog/FlatCp=Flat Copy to Target",
					tooltip = LOC "$$$/PSUpload/ExportDialog/FlatCpTT=All photos/videos will be copied to the Target Album",
					alignment = 'right',
					value = bind 'copyTree',
					checked_value = false,
					width = share 'labelWidth',
				},

				f:radio_button {
					title = LOC "$$$/PSUpload/ExportDialog/CopyTree=Mirror Tree relative to local Path:",
					tooltip = LOC "$$$/PSUpload/ExportDialog/CopyTreeTT=All photos/videos will be copied to a mirrored directory below the Target Album",
					alignment = 'left',
					value = bind 'copyTree',
					checked_value = true,
				},

				f:edit_field {
					value = bind 'srcRoot',
					tooltip = LOC "$$$/PSUpload/ExportDialog/CopyTreeTT=Enter the local path that is the root of the directory tree you want to mirror below the Target Album.",
					enabled = bind 'copyTree',
					visible = bind 'copyTree',
					validate = validateDirectory,
					truncation = 'middle',
					immediate = true,
					fill_horizontal = 1,
				},
			},

			f:separator { fill_horizontal = 1 },

			f:row {
				f:checkbox {
					title = LOC "$$$/PSUpload/ExportDialog/RAWandJPG=RAW+JPG to same Album",
					tooltip = LOC "$$$/PSUpload/ExportDialog/RAWandJPGTT=Allow Lr-developed RAW+JPG from camera to be uploaded to same Album.\n" ..
									"Note: All Non-JPEG photos will be renamed in PhotoStation to <photoname>_<OrigExtension>.<OutputExtension>. E.g.:\n" ..
									"IMG-001.RW2 --> IMG-001_RW2.JPG\n" .. 
									"IMG-001.JPG --> IMG-001.JPG",
					alignment = 'left',
					value = bind 'RAWandJPG',
					fill_horizontal = 1,
				},

				f:checkbox {
					title = LOC "$$$/PSUpload/ExportDialog/SortPhotos=Sort Photos",
					tooltip = LOC "$$$/PSUpload/ExportDialog/SortPhotosTT=Sort photos in PhotoStation according to sort order of Published Collection.\n" ..
									"Note: Sorting is not possible for dynamic Target Albums (including metadata placeholders)\n",
					alignment = 'left',
					value = bind 'sortPhotos',
					enabled =  negativeOfKey 'copyTree',
					fill_horizontal = 1,
				},	
			},
		},
	} 
end	


-- ================== Upload Options ============================================================
function PSDialogs.UploadOptionsView(f, propertyTable)
	local bind = LrView.bind
	local share = LrView.share
	local conditionalItem = LrView.conditionalItem
	local negativeOfKey = LrBinding.negativeOfKey
			
	return	f:group_box {
		fill_horizontal = 1,
		title = LOC "$$$/PSUpload/ExportDialog/UploadOpt=Metadata Upload Options /Translations (To PhotoStation)",

		f:row {
			f:checkbox {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/exifTranslate=Translate Tags:",
				tooltip = LOC "$$$/PSUpload/ExportDialog/exifTranslateTT=Translate Lightroom tags to PhotoStation tags",
				value = bind 'exifTranslate',
			},
		
			f:checkbox {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/exifXlatFaceRegions=Faces",
				tooltip = LOC "$$$/PSUpload/ExportDialog/exifXlatFaceRegionsTT=Translate Lightroom or Picasa Face Regions to PhotoStation Person Tags",
				value = bind 'exifXlatFaceRegions',
				visible = bind 'exifTranslate',
			},
		
			f:checkbox {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/exifXlatLabel=Color Label",
				tooltip = LOC "$$$/PSUpload/ExportDialog/exifXlatLabelTT=Translate Lightroom color label (red, green, ...) to PhotoStation General Tag '+color'",
				value = bind 'exifXlatLabel',
				visible = bind 'exifTranslate',
			},

			f:checkbox {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/exifXlatRating=Rating",
				tooltip = LOC "$$$/PSUpload/ExportDialog/exifXlatRatingTT=Translate Lightroom (XMP) rating (*stars*) to PhotoStation General Tag '***'",
				value = bind 'exifXlatRating',
				visible = bind 'exifTranslate',
			},
		},
		
		f:row {
			f:checkbox {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/CommentsUpload=Comments (always uploaded)",
				value = true,
				enabled = false,
			},

			f:checkbox {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/CaptionUpload=Decription (always uploaded)",
				value = true,
				enabled = false,
			},

		}, 
		
		f:row {
			f:static_text {
				title = LOC "$$$/PSUpload/ExportDialog/exiftoolprog=ExifTool program:",
				alignment = 'right',
				visible = bind 'exifTranslate',
				width = share 'labelWidth'
			},

			f:edit_field {
				value = bind 'exiftoolprog',
				truncation = 'middle',
				validate = PSDialogs.validateProgram,
				visible = bind 'exifTranslate',
				immediate = true,
				fill_horizontal = 1,
			},
		},
	}
end

-- ================== Download Options ============================================================
function PSDialogs.DownloadOptionsView(f, propertyTable)
	local bind = LrView.bind
	local share = LrView.share
	local negativeOfKey = LrBinding.negativeOfKey
			
	return	f:group_box {
		fill_horizontal = 1,
		title = LOC "$$$/PSUpload/ExportDialog/DownloadOpt=Metadata Download Options / Translations  (From PhotoStation)",

		f:row {
			f:checkbox {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/TagsDownload=Tags",
				tooltip = LOC "$$$/PSUpload/ExportDialog/TagsDownloadTT=Download tags from PhotoStation",
				value = bind 'tagsDownload',
			},

			f:checkbox {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/PS2LrNotSupp=Faces (no support)",
				tooltip = LOC "$$$/PSUpload/ExportDialog/PS2LrNotSuppTT=Download of faces from PhotoStation not supported",
				value = false,
				enabled = false,
				visible = bind 'tagsDownload',
			},

-- no way to set face regions in Lr
--[[
			f:checkbox {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/PS2LrFaces=Faces",
				tooltip = LOC "$$$/PSUpload/ExportDialog/PS2LrFacesTT=Translate PhotoStation People Tag to Lightroom Faces",
				value = bind 'PS2LrFaces',
				enabled = bind 'exifXlatFaceRegions',
				visible = bind 'tagsDownload',
			},
]]
			f:checkbox {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/PS2LrLabel=Color Label",
				tooltip = LOC "$$$/PSUpload/ExportDialog/PS2LrLabelTT=Translate PhotoStation General Tag '+color' to Lightroom color label (red, green, ...)",
				value = bind 'PS2LrLabel',
				enabled = bind 'exifXlatLabel',
				visible = bind 'tagsDownload',
			},

			f:checkbox {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/PS2LrRating=Rating",
				tooltip = LOC "$$$/PSUpload/ExportDialog/PS2LrRatingTT=Translate PhotoStation general tag '***' to Lightroom rating",
				value = bind 'PS2LrRating',
				enabled = bind 'exifXlatRating',
				visible = bind 'tagsDownload',
			},

		},
		
		f:row {
			f:checkbox {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/CommentsDownload=Comments",
				tooltip = LOC "$$$/PSUpload/ExportDialog/commentsDownloadTT=Download comments from PhotoStation",
				value = bind 'commentsDownload',
			},

			f:checkbox {
				fill_horizontal = 1,
				title = LOC "$$$/PSUpload/ExportDialog/CaptionDownload=Description",
				tooltip = LOC "$$$/PSUpload/ExportDialog/CaptionDownloadTT=Download description (caption) from PhotoStation",
				value = bind 'captionDownload',
			},
		},
	}
end

