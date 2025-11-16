--[[----------------------------------------------------------------------------

PSPluginTagsetLong.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2015-2025, Martin Messmer

Summary information for Photo StatLr

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

------------------------------------------------------------------------------]]

return {
	title = "Photo StatLr: " .. LOC "$$$/PSUpload/Tagsets/Long/Title=Long",
	id = 'photoStatLrTagsetLong',

	items = {
        'com.adobe.filename',
        'com.adobe.folder',
        'com.adobe.imageFileDimensions',
        'com.adobe.duration',
        'com.adobe.captureTime',
        'com.adobe.captureDate',
        'com.adobe.GPS',

        'com.adobe.separator',
        'com.adobe.title',
        'com.adobe.headline',
        { 'com.adobe.caption', height_in_lines = 2 },
        'com.adobe.copyright',
        'com.adobe.colorLabels',
        'com.adobe.rating',

        'com.adobe.separator',
        { 'com.adobe.label', label = "Exif" },
        'com.adobe.make',
        'com.adobe.model',
        'com.adobe.serialNumber',
        'com.adobe.lens',
        'com.adobe.exposure',
        'com.adobe.focalLength',
        'com.adobe.focalLength35mm',
        'com.adobe.ISOSpeedRating',
        'com.adobe.meteringMode',

        'com.adobe.separator',
        { 'com.adobe.label', label = "Photo StatLr" },
		'de.messmer-online.lightroom.export.photostation_upload.lastCommentText',
		'de.messmer-online.lightroom.export.photostation_upload.lastCommentAuthor',
		'de.messmer-online.lightroom.export.photostation_upload.lastCommentDate',
		'de.messmer-online.lightroom.export.photostation_upload.lastCommentUrl',
		'de.messmer-online.lightroom.export.photostation_upload.lastCommentType',
		'de.messmer-online.lightroom.export.photostation_upload.lastCommentSource',
		'de.messmer-online.lightroom.export.photostation_upload.commentCount',
--[[
		-- file info
        'com.adobe.filename',
        'com.adobe.folder',
        'com.adobe.copyname',
        'com.adobe.imageFileDimensions',
        'com.adobe.imageCroppedDimensions',
        'com.adobe.dateTimeOriginal',
        'com.adobe.dateCreated',

		-- tagging
        'com.adobe.title',
        'com.adobe.caption',
        'com.adobe.headline',
        'com.adobe.keywords',
        'com.adobe.rating',
        'com.adobe.rating.string',
        'com.adobe.colorLabels',
        'com.adobe.colorLabels.string',
        'com.adobe.copyright',
        'com.adobe.rightsUsageTerms',
        'com.adobe.copyrightInfoURL',

		-- exifs
        'com.adobe.exposure',
        'com.adobe.focalLength',
        'com.adobe.focalLength35mm',
        'com.adobe.brightnessValue',
        'com.adobe.exposureBiasValue',
        'com.adobe.subjectDistance',
        'com.adobe.ISOSpeedRating',
        'com.adobe.flash',
        'com.adobe.exposureProgram',
        'com.adobe.meteringMode',
        'com.adobe.make',
        'com.adobe.model',
        'com.adobe.serialNumber',
        'com.adobe.artist',
        'com.adobe.software',
        'com.adobe.lens',
        'com.adobe.software',

		-- location info
        'com.adobe.GPS',
        'com.adobe.GPSAltitude',
        'com.adobe.location',
        'com.adobe.city',
        'com.adobe.state',
        'com.adobe.country',
        'com.adobe.isoCountryCode',
        'com.adobe.scene',

		-- creator
        'com.adobe.creator',
        'com.adobe.creatorJobTitle',
        'com.adobe.creatorAddress',
        'com.adobe.creatorCity',
        'com.adobe.creatorState',
        'com.adobe.creatorZip',
        'com.adobe.creatorCountry',
        'com.adobe.creatorWorkPhone',
        'com.adobe.creatorWorkEmail',
        'com.adobe.creatorWorkWebsite',

		-- misc
        'com.adobe.descriptionWriter',
        'com.adobe.iptcSubjectCode',
        'com.adobe.intellectualGenre',
        'com.adobe.jobIdentifier',
        'com.adobe.instructions',
        'com.adobe.provider',
        'com.adobe.source',
]]
	},
}