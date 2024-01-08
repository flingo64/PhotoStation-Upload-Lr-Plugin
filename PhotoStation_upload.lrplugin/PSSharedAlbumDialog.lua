--[[----------------------------------------------------------------------------

PSSharedAlbumDialog.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2015-2023, Martin Messmer

Management of Photo Server Shared Albums for Lightroom Photo StatLr

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

-- Lightroom SDK
local LrBinding			= import 'LrBinding'
local LrColor			= import 'LrColor'
local LrDate			= import 'LrDate'
local LrDialogs			= import 'LrDialogs'
local LrFunctionContext	= import 'LrFunctionContext'
local LrHttp 			= import 'LrHttp'
local LrTasks	 		= import 'LrTasks'
local LrView 			= import 'LrView'

local bind 				= LrView.bind
local conditionalItem 	= LrView.conditionalItem

-- Photo StatLr plug-in
require "PSDialogs"
require "PSUtilities"
require "PSSharedAlbumMgmt"

--============================================================================--

-- the following keys can be modified in active album view and should trigger updateActiveAlbumStatus()
local observedKeys = {'publishServiceName', 'sharedAlbumName', 'startTime', 'stopTime'}

local allPublishServiceNames
local allPublishServiceVersions
local allSharedAlbums				-- all Shared Albums

local rowsPropertyTable 	= {}	-- the visible rows in the dialog
local nExtraRows 			= 5		-- add this number of rows for additions

local columnWidth = {
	-- header section
	header			   	= 300,
	label			    = 80,
	data			    = 250,
	url				    = 400,
	password		    = 166,

	-- list section
	delete			    = 30,
	albumName		    = 170,
	publishService	    = 120,
	publicPermissions   = 80,
	public			    = 40,
	start			    = 75,
	stop			    = 75,
	area 			    = 35,
	comments		    = 60,
	colors			    = 100,
	donwload		    = 60,

	total			    = 850,

	color			    = 16,
	scrollbar		    = 50,
}

-------------------------------------------------------------------------------
-- updateActiveAlbumStatus:
--
local function updateActiveAlbumStatus( propertyTable )
	local message = nil

	repeat
		-- Use a repeat loop to allow easy way to "break" out.
		-- (It only goes through once.)

		if ifnil(propertyTable.sharedAlbumName, '') == '' then
			message = LOC "$$$/PSUpload/SharedAlbumDialog/Message/SharedAlbumNameMissing=Please enter a Shared Album Name!"
			break
		end

		-- if this is a new entry: check if Album does not yet exist
		if propertyTable.wasAdded then
			for i = 1, #allSharedAlbums do
				if 	propertyTable.publishServiceName == allSharedAlbums[i].publishServiceName
				and	propertyTable.sharedAlbumName == allSharedAlbums[i].sharedAlbumName
				then
        			message = LOC "$$$/PSUpload/SharedAlbumDialog/Message/SharedAlbumAlreadyExist=Shared Album already exists!"
        			break
				end
			end
		end

		if ifnil(propertyTable.startTime, '') ~= '' and not PSSharedAlbumDialog.validateDate(nil, propertyTable.startTime) then
			message = LOC "$$$/PSUpload/SharedAlbumDialog/Message/DateIncorrect=Date must be 'YYYY-mm-dd'!"
			break
		end

		if ifnil(propertyTable.stopTime, '') ~= '' and not PSSharedAlbumDialog.validateDate(nil, propertyTable.stopTime) then
			message = LOC "$$$/PSUpload/SharedAlbumDialog/Message/DateIncorrect=Date must be 'YYYY-mm-dd'!"
			break
		end

	until true

	if message then
		propertyTable.message = message
		propertyTable.hasError = true
		propertyTable.hasNoError = false
		-- ignore a new entry as long as there is an error
		if propertyTable.wasAdded then
			propertyTable.isEntry = false
		end
	else
		propertyTable.message = nil
		propertyTable.hasError = false
		propertyTable.hasNoError = true
		if propertyTable.wasAdded then
			propertyTable.isEntry = true
		end
	end
end

-------------------------------------------------------------------------------
-- updateGlobalRowsSelected: select/unselect all rows
local function updateGlobalRowsSelected( propertyTable )
	writeLogfile(2, "updateGlobalRowsSelected() started\n")
	for i = 1, #rowsPropertyTable do
		if rowsPropertyTable[i].isAdvanced then
			rowsPropertyTable[i].isSelected = propertyTable.selectAll
		end
	end
end

-------------------------------------------------------------------------------
-- saveActiveRow()
-- 		save the Active Album settings into its row
local function saveActiveRow(propertyTable)
	if not propertyTable.hasError then
		local activeRowProps = rowsPropertyTable[propertyTable.activeRowIndex]

		for key, _ in pairs(PSSharedAlbumMgmt.sharedAlbumDefaults) do
			if activeRowProps[key] ~= propertyTable[key] then
				activeRowProps[key] = propertyTable[key]
				activeRowProps.wasModified = true
			end
		end
		-- in case the current album is about to be added, do not forget to store publish service and album name
		activeRowProps.isEntry 				= true
		activeRowProps.publishServiceName 	= propertyTable.publishServiceName
		activeRowProps.sharedAlbumName		= propertyTable.sharedAlbumName
	end
end

-------------------------------------------------------------------------------
-- loadRow()
-- 		load the given row into Active Album settings section
local function loadRow(propertyTable, i)
	propertyTable.activeRowIndex		= i

	for key, _ in pairs(PSSharedAlbumMgmt.sharedAlbumDefaults) do
		propertyTable[key] = rowsPropertyTable[i][key]
	end
	propertyTable.wasAdded              = rowsPropertyTable[i].wasAdded
    propertyTable.sharedAlbumName       = rowsPropertyTable[i].sharedAlbumName
    propertyTable.publishServiceName    = rowsPropertyTable[i].publishServiceName

	updateActiveAlbumStatus(propertyTable)

	for j = 1, #rowsPropertyTable do
		rowsPropertyTable[j].isActive = false
	end
	rowsPropertyTable[i].isActive 	= true
end

-------------------------------------------------------------------------------
-- findEmptyRow()
-- 		find next empty row
local function findEmptyRow()
	for i = 1, #rowsPropertyTable do
		if not rowsPropertyTable[i].isEntry then
			return i
		end
	end
	return -1
end

--============================================================================--

PSSharedAlbumDialog = {}

--============================ validate functions ===========================================================

-------------------------------------------------------------------------------
-- validateDate: check if a string is a valide date string YYYY-mm-dd
function PSSharedAlbumDialog.validateDate( view, value )
-- 	if string.match(value, '^(%d%d%d%d%-%d%d%-%d%d)$') ~= value then
--		return false, value
--	end

	local year, month, day = string.match(value, '^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
	if not year then
		return false, value
	end

	local timestamp = LrDate.timeFromComponents(tonumber(year), tonumber(month), tonumber(day), 0, 0, 0, 'local')
	if not timestamp or timestamp == 0 then
		return false, value
	end

	return true, value
end

--============================ dialog functions ===========================================================

-------------------------------------------------------------------------------
-- showDialog(f, propertyTable, context)
-- create the dialog contents view and open it as modal dialog
function PSSharedAlbumDialog.showDialog(f, propertyTable, context)
	local scrollRows = {}

	-----------------------------------------------------------------
	-- Data rows
	-----------------------------------------------------------------
	for i = 1, #rowsPropertyTable do
		local scrollRow = conditionalItem(rowsPropertyTable[i],
    		f:row {
        		bind_to_object	= rowsPropertyTable[i],
        		width 			= columnWidth.total,
           		font			= '<system/small>',

        		f:checkbox {
        			value 			= bind 'wasDeleted',
	      			checked_value	= false,
	        		visible			= bind 'isEntry',
    				width 			= columnWidth.delete,
        		},

        		f:view {
					visible			= bind {
						keys = {
							{	key = 'isEntry' },
							{	key = 'wasDeleted'},
						},
						operation = function( _, values, _ )
							return values.isEntry and not values.wasDeleted
						end,
					},

		       		f:row {
                		f:static_text {
                	  		title 			= bind 'sharedAlbumName',
                    		alignment		= 'left',
							text_color		= bind {
								keys = {
									{	key = 'wasAdded' },
									{	key = 'wasModified'},
								},
								operation = function( _, values, _ )
									if values.wasAdded or values.wasModified then
										return LrColor('blue')
									else
										return LrColor('black')
									end
								end,
							},
            				width 			= columnWidth.albumName,
            				mouse_down		= function()
            					return loadRow(propertyTable, i)
            				end,
                	   },

                		f:static_text {
                	  		title 			= bind 'publishServiceName',
                    		alignment		= 'left',
            				width 			= columnWidth.publishService,
            				mouse_down		= function()
            					return loadRow(propertyTable, i)
            				end,
                	   },

                		f:checkbox {
                			value 			= bind 'isPublic',
							enabled 		= false,
	           				width 			= columnWidth.public,
                		},

                		f:static_text {
                	  		title 			= bind 'publicPermissions',
							visible			= bind 'isPublic',
							alignment		= 'left',
            				width 			= columnWidth.publicPermissions,
            				mouse_down		= function()
            					return loadRow(propertyTable, i)
            				end,
                	   },

                		f:static_text {
              				title 			= bind 'startTime',
                            visible			= bind 'isAdvanced',
                    		alignment		= 'left',
                    		font			= '<system/small>',
            				width 			= columnWidth.start,
                	   },

                		f:static_text {
              				title 			= bind 'stopTime',
                   			visible			= bind 'isPublic',
                    		alignment		= 'left',
                    		font			= '<system/small>',
                    		width 			= columnWidth.stop,
                	   },

						-- TODO: check if isAdvanced
                		f:checkbox {
                			value 			= bind 'areaTool',
							enabled 		= false,
                            visible			= bind 'isAdvanced',
            				width 			= columnWidth.area,
                		},

                		f:checkbox {
                			value 			= bind 'comments',
							enabled 		= false,
                   			visible			= bind 'isAdvanced',
            				width 			= columnWidth.comments,
                		},

 --               		f:row {
 --           				width 			= columnWidth.colors,

                    		f:checkbox {
                    			value 			= bind 'colorRed',
								enabled 		= false,
            	       			visible			= bind 'isAdvanced',
                				width 			= columnWidth.color,
                    		},

                    		f:checkbox {
                    			value 			= bind 'colorYellow',
								enabled 		= false,
            	       			visible			= bind 'isAdvanced',
                				width 			= columnWidth.color,
                    		},

                    		f:checkbox {
                    			value 			= bind 'colorGreen',
								enabled 		= false,
            	       			visible			= bind 'isAdvanced',
                				width 			= columnWidth.color,
                    		},

                    		f:checkbox {
                    			value 			= bind 'colorBlue',
								enabled 		= false,
            	       			visible			= bind 'isAdvanced',
                				width 			= columnWidth.color,
                    		},

                    		f:checkbox {
                    			value 			= bind 'colorPurple',
								enabled 		= false,
            	       			visible			= bind 'isAdvanced',
                				width 			= columnWidth.color,
                    		},
--                		},

                		f:checkbox {
                			title 			= "",
                			value 			= bind 'isSelected',
							visible			= bind 'isAdvanced',
            				width_in_chars	= 0,
                		},
            		},
        		},
        	}
		)
    	table.insert(scrollRows, scrollRow)
	end

	local scrollView = f:scrolled_view {
		horizontal_scroller = false,
		vertical_scroller	= true,
   		width = columnWidth.total + columnWidth.scrollbar,

 		unpack(scrollRows),

	}

	local publishServiceItems = {}
    for i = 1, #allPublishServiceNames	do
    	table.insert(publishServiceItems, {
    		title	= allPublishServiceNames[i],
    		value	= allPublishServiceNames[i],
    	})
    end
	-----------------------------------------------------------------
	-- Dialog Head
	-----------------------------------------------------------------
	local dialogContents = f:view {
		bind_to_object 	=	propertyTable,

   		f:row {
			width 			= columnWidth.total,
   			f:column {
   				PSDialogs.photoStatLrSmallView(f, nil),
   			},

   			f:column {
	   			fill_horizontal = 1,
	   			fill_vertical = 1,
				f:group_box {
		   			title			= LOC "$$$/PSUpload/SharedAlbumDialog/Group/EditSharedAlbum=Edit Shared Album",
		   			fill_horizontal = 1,
		   			fill_vertical	= 1,

					f:row {
						f:static_text  {
							title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/PublishService=Publish Service"
													.. ":",
	           				width 			= columnWidth.label,
						},

						f:popup_menu {
							items 			= publishServiceItems,
							alignment 		= 'left',
							value 			= bind 'publishServiceName',
							enabled 		= false,
            				width 			= columnWidth.data,
						},
					},

					f:row {
            			f:static_text {
					  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/SharedAlbum=Shared Album"
					  								.. ":",
                    		alignment		= 'left',
            				width 			= columnWidth.label,
            		   },

            			f:edit_field {
            		  		value 			= bind 'sharedAlbumName',
               				enabled 		= bind 'wasAdded',
            		  		immediate		= true,
                    		alignment		= 'left',
            				width 			= columnWidth.data,
            		   },
           			},

            		f:row {
            			f:view {
            				width 			= columnWidth.public,

                			f:static_text {
    					  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/Public=Public",
                        		alignment		= 'left',
                			},

                    		f:checkbox {
                    			value 			= bind 'isPublic',
                        		alignment		= 'center',
                    		},
    					},

            			f:view {
							width	= columnWidth.password,

            				f:static_text {
            		  			title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/Permissions=Permissions",
            					visible		    	= bind 'isPublic',
                    			alignment		= 'left',
        					},

                			f:popup_menu {
                				items 			    = PSSharedAlbumMgmt.sharedAlbumPermissionItems,
                				value 			    = bind 'publicPermissions',
            					visible		    	= bind 'isPublic',
                				alignment 		    = 'left',
								fill_horizontal 	= 1,
                			},
                        },

            			f:view {
							width	= columnWidth.password,

            				f:static_text {
            		  			title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/Password=Password",
                    			alignment		= 'left',
            					visible			= bind 'isPublic',
        					},

                    		f:edit_field {
                  				value 			= bind 'sharedAlbumPassword',
            					visible			= bind 'isPublic',
                   				immediate 		= true,
                        		alignment		= 'left',
                	       		font			= '<system/small>',
               				},
						},

            			f:view {
							width	= columnWidth.start,

                			f:static_text {
			    		  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/StartTime=From",
                        		alignment		= 'left',
            					visible			= bind {
            						keys = {
            							{	key = 'isAdvanced' },
            							{	key = 'isPublic'},
            						},
            						operation = function( _, values, _ )
            							return values.isAdvanced and values.isPublic
            						end,
            					},
                			},

                			f:edit_field {
                		  		value 			= bind 'startTime',
            					visible			= bind {
            						keys = {
            							{	key = 'isAdvanced' },
            							{	key = 'isPublic'},
            						},
            						operation = function( _, values, _ )
            							return values.isAdvanced and values.isPublic
            						end,
            					},
                		  		immediate		= true,
                        		alignment		= 'left',
                        		font			= '<system/small>',
                				width 			= columnWidth.start,
                		   },
            			},

            			f:view {
							width	= columnWidth.stop,

                			f:static_text {
			    		  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/StopTime=Until",
                        		alignment		= 'left',
            					visible			= bind 'isPublic',
                			},

                			f:edit_field {
                		  		value 			= bind 'stopTime',
            					visible			= bind {
            						keys = {
            							{	key = 'isPublic'},
            						},
            						operation = function( _, values, _ )
            							return values.isPublic
            						end,
            					},
                		  		immediate		= true,
                        		alignment		= 'left',
                        		font			= '<system/small>',
                				width 			= columnWidth.stop,
                			},
            			},

						f:view {
                			f:static_text {
                				width 			= columnWidth.area,
                		  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/AreaTool=Area",
								  visible			= bind {
            						keys = {
            							{	key = 'isAdvanced' },
            							{	key = 'isPublic'},
            						},
            						operation = function( _, values, _ )
            							return values.isAdvanced and values.isPublic
            						end,
            					},
                        		alignment		= 'left',
                			},

                    		f:checkbox {
                    			value 			= bind 'areaTool',
            					visible			= bind {
            						keys = {
            							{	key = 'isAdvanced' },
            							{	key = 'isPublic'},
            						},
            						operation = function( _, values, _ )
            							return values.isAdvanced and values.isPublic
            						end,
            					},
                				width 			= columnWidth.area,
                    		},
						},

						f:view {
                			f:static_text {
                				width 			= columnWidth.comments,
                		  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/Comments=Comments",
                        		alignment		= 'left',
            					visible			= bind {
            						keys = {
            							{	key = 'isAdvanced' },
            							{	key = 'isPublic'},
            						},
            						operation = function( _, values, _ )
            							return values.isAdvanced and values.isPublic
            						end,
            					},
                			},

                    		f:checkbox {
                    			value 			= bind 'comments',
            					visible			= bind {
            						keys = {
            							{	key = 'isAdvanced' },
            							{	key = 'isPublic'},
            						},
            						operation = function( _, values, _ )
            							return values.isAdvanced and values.isPublic
            						end,
            					},
                				width 			= columnWidth.comments,
                    		},
						},

            			f:view {
            				f:row {
                				width 			= columnWidth.colors,
            	   				f:color_well {
               						value			= LrColor('red'),
               						enabled			= false,
									   visible			= bind {
										keys = {
											{	key = 'isAdvanced' },
											{	key = 'isPublic'},
										},
										operation = function( _, values, _ )
											return values.isAdvanced and values.isPublic
										end,
									},
										width 			= columnWidth.color,
               					},

            	   				f:color_well {
               						value			= LrColor('yellow'),
               						enabled			= false,
									   visible			= bind {
										keys = {
											{	key = 'isAdvanced' },
											{	key = 'isPublic'},
										},
										operation = function( _, values, _ )
											return values.isAdvanced and values.isPublic
										end,
									},
										width 			= columnWidth.color,
               					},

            	   				f:color_well {
               						value			= LrColor('green'),
               						enabled			= false,
									   visible			= bind {
										keys = {
											{	key = 'isAdvanced' },
											{	key = 'isPublic'},
										},
										operation = function( _, values, _ )
											return values.isAdvanced and values.isPublic
										end,
									},
										width 			= columnWidth.color,
               					},

            	   				f:color_well {
               						value			= LrColor('blue'),
               						enabled			= false,
									   visible			= bind {
										keys = {
											{	key = 'isAdvanced' },
											{	key = 'isPublic'},
										},
										operation = function( _, values, _ )
											return values.isAdvanced and values.isPublic
										end,
									},
										width 			= columnWidth.color,
               					},

            	   				f:color_well {
               						value			= LrColor('purple'),
               						enabled			= false,
									   visible			= bind {
										keys = {
											{	key = 'isAdvanced' },
											{	key = 'isPublic'},
										},
										operation = function( _, values, _ )
											return values.isAdvanced and values.isPublic
										end,
									},
										width 			= columnWidth.color,
               					},
            				},

                    		f:row {
                				width 			= columnWidth.colors,

                        		f:checkbox {
                        			value 			= bind 'colorRed',
                					visible			= bind {
                						keys = {
                							{	key = 'isAdvanced' },
                							{	key = 'isPublic'},
                						},
                						operation = function( _, values, _ )
                							return values.isAdvanced and values.isPublic
                						end,
                					},
                    				width 			= columnWidth.color,
                        		},

                        		f:checkbox {
                        			value 			= bind 'colorYellow',
                					visible			= bind {
                						keys = {
                							{	key = 'isAdvanced' },
                							{	key = 'isPublic'},
                						},
                						operation = function( _, values, _ )
                							return values.isAdvanced and values.isPublic
                						end,
                					},
                    				width 			= columnWidth.color,
                        		},

                        		f:checkbox {
                        			value 			= bind 'colorGreen',
                					visible			= bind {
                						keys = {
                							{	key = 'isAdvanced' },
                							{	key = 'isPublic'},
                						},
                						operation = function( _, values, _ )
                							return values.isAdvanced and values.isPublic
                						end,
                					},
                    				width 			= columnWidth.color,
                        		},

                        		f:checkbox {
                        			value 			= bind 'colorBlue',
                					visible			= bind {
                						keys = {
                							{	key = 'isAdvanced' },
                							{	key = 'isPublic'},
                						},
                						operation = function( _, values, _ )
                							return values.isAdvanced and values.isPublic
                						end,
                					},
                    				width 			= columnWidth.color,
                        		},

                        		f:checkbox {
                        			value 			= bind 'colorPurple',
                					visible			= bind {
                						keys = {
                							{	key = 'isAdvanced' },
                							{	key = 'isPublic'},
                						},
                						operation = function( _, values, _ )
                							return values.isAdvanced and values.isPublic
                						end,
                					},
                    				width 			= columnWidth.color,
                        		},
                    		},
						},

            			f:view {
							width	= columnWidth.sync,
                       		fill_horizontal = 1,

                			f:static_text {
    					  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/Advanced=Advanced",
                                visible         = bind 'isAdvanced',
                        		alignment		= 'right',
                        		fill_horizontal = 1
                			},

                    		f:checkbox {
                    			value 			= bind 'isAdvanced',
                                visible         = bind 'isAdvanced',
                    			enabled			= false,
                        		alignment		= 'right',
                        		place_horizontal = 1
                    		},
        				},
					},

					f:row {
						f:push_button {
							title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Button/SaveChanges=Save Changes",
							font			= '<system/small>',
							enabled			= bind 'hasNoError',
							action 			= function()
								saveActiveRow(propertyTable)
							end,
						},
					},
					
					f:separator { fill_horizontal = 1 },

					f:row {
            			f:static_text {
            		  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/PrivateUrl=Private URL:",
                    		alignment		= 'left',
            				width 			= columnWidth.label,
            			},

                		f:static_text {
                	  		title 			= bind 'privateUrl',
                    		alignment		= 'left',
            				width 			= columnWidth.url,
            				text_color		= LrColor("blue"),
                    		font			= '<system/small>',
            				mouse_down		= function()
								if propertyTable.privateUrl ~= '' then LrHttp.openUrlInBrowser(propertyTable.privateUrl) end
           					end,
                		},
       				},

       				f:row {
            			f:static_text {
            		  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/PublicUrl=Public URL:",
                    		alignment		= 'left',
            				width 			= columnWidth.label,
            			},

                		f:static_text {
                	  		title 			= bind 'publicUrl',
                    		alignment		= 'left',
            				text_color		= LrColor("blue"),
                    		font			= '<system/small>',
            				width 			= columnWidth.url,
            				mouse_down		= function()
           						if propertyTable.publicUrl ~= '' then LrHttp.openUrlInBrowser(propertyTable.publicUrl) end
           					end,
                		},
       				},

       				f:row {
            			f:static_text {
            		  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/PublicUrl2=Public URL 2:",
                    		alignment		= 'left',
            				width 			= columnWidth.label,
            			},

                		f:static_text {
                	  		title 			= bind 'publicUrl2',
                    		alignment		= 'left',
            				text_color		= LrColor("blue"),
                    		font			= '<system/small>',
            				width 			= columnWidth.url,
            				mouse_down		= function()
								if propertyTable.publicUrl2 ~= '' then LrHttp.openUrlInBrowser(propertyTable.publicUrl2) end
							end,
                		},
       				},
				},
   			},
		},

    	-----------------------------------------------------------------
    	-- List box
    	-----------------------------------------------------------------
		f:group_box {
       		fill_horizontal = 1,
			title			= LOC "$$$/PSUpload/SharedAlbumDialog/Group/SelectSharedAlbum=Select Shared Album",

    		f:row {
    			width = columnWidth.total,

    			f:static_text {
    				width 			= columnWidth.delete,
    		  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/Delete=Delete",
            		alignment		= 'left',
    			},

    			f:static_text {
    		  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/SharedAlbum=Shared Album",
            		alignment		= 'left',
    				width 			= columnWidth.albumName,
    		  	},

    			f:static_text {
    		  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/PublishService=Publish Service",
            		alignment		= 'left',
    				width 			= columnWidth.publishService,
    		  	},

    			f:static_text {
    		  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/Public=Public",
            		alignment		= 'left',
    				width 			= columnWidth.public,
    		  	},

    			f:static_text {
    		  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/Permissions=Permissions",
            		alignment		= 'left',
    				width 			= columnWidth.publicPermissions,
    		  	},

    			f:static_text {
    				width 			= columnWidth.start,
    		  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/StartTime=From",
            		alignment		= 'left',
    		  	},

    			f:static_text {
    				width 			= columnWidth.stop,
    		  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/StopTime=Until",
            		alignment		= 'left',
    		   	},

    			f:static_text {
    				width 			= columnWidth.area,
       		  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/AreaTool=Area",
            		alignment		= 'left',
    		  	},

    			f:static_text {
    				width 			= columnWidth.comments,
    		  		title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/Comments=Comments",
            		alignment		= 'left',
    		  	},

    		   	f:view {
    				f:row {
--        				width 			= columnWidth.colors,
    	   				f:color_well {
       						value			= LrColor('red'),
       						enabled			= false,
    						width 			= columnWidth.color,
       					},

    	   				f:color_well {
       						value			= LrColor('yellow'),
       						enabled			= false,
    						width 			= columnWidth.color,
       					},

    	   				f:color_well {
       						value			= LrColor('green'),
       						enabled			= false,
    						width 			= columnWidth.color,
       					},

    	   				f:color_well {
       						value			= LrColor('blue'),
       						enabled			= false,
    						width 			= columnWidth.color,
       					},

    	   				f:color_well {
       						value			= LrColor('purple'),
       						enabled			= false,
    						width 			= columnWidth.color,
       					},
    				},
  				},

    			f:view {
        			f:row {
          				width 			= columnWidth.download,
               			f:static_text  {
               				title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Label/Download=Download",
            				tooltip 		= LOC "$$$/PSUpload/SharedAlbumDialog/Label/DownloadTT=Download Color Labels from Shared Album",
						},
    				},
				},
    		},

        	-----------------------------------------------------------------
        	-- Srcoll row area
        	-----------------------------------------------------------------
    		scrollView,

			f:row {
				f:static_text  {
					title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Text/AddAlbum=Add Shared Album to Publish Service:",
				},

				f:popup_menu {
					items 			= publishServiceItems,
					alignment 		= 'left',
					value			= bind 'newPublishServiceName'
				},

				f:push_button {
					title 			= LOC "$$$/PSUpload/SharedAlbumDialog/Button/AddAlbum=Add ...",
					font			= '<system/small>',
					action 			= function()
						local newRowId = findEmptyRow()
						-- TODO check newRowId ~= -1
						local rowProps = rowsPropertyTable[newRowId]
						rowProps.wasAdded 			= true
						rowProps.publishServiceName = propertyTable.newPublishServiceName
						local sharedAlbumDefaults = PHOTOSERVER_API[allPublishServiceVersions[propertyTable.newPublishServiceName]].API.sharedAlbumDefaults
						if sharedAlbumDefaults then
							for key, value in pairs(sharedAlbumDefaults) do
								rowProps[key] = value
							end
							loadRow(propertyTable, newRowId)
						end
					end,
				},
			},
		},

		f:spacer {	fill_horizontal = 1,},

    	-----------------------------------------------------------------
    	-- Dialog Footer
    	-----------------------------------------------------------------
		f:row {
			fill_horizontal = 1,
			fill_vertical 	= 1,

			f:static_text {
				title 			= bind 'message',
				text_color 		= LrColor("red"),
				font			= '<system/bold>',
				alignment		= 'center',
				fill_horizontal = 1,
				visible 		= bind 'hasError'
			},
		},
	}

	return LrDialogs.presentModalDialog(
		{
			title 		= LOC "$$$/PSUpload/SharedAlbumDialog/Title=Manage Shared Albums",
			contents 	= dialogContents,
			actionVerb 	=  LOC "$$$/PSUpload/SharedAlbumDialog/Button/ApplyPS=Apply changes to Lr and PhotoServer (online)",
			actionBinding = {
				enabled = {
					bind_to_object 	= propertyTable,
					key 			= 'hasNoError'
				},
			},
			otherVerb	=  LOC "$$$/PSUpload/SharedAlbumDialog/Button/ApplyLocal=Apply changes to Lr (offline)",
		}
	)

end

-------------------------------------------------------------------------------
-- PSSharedAlbumDialog.doDialog(  )
function PSSharedAlbumDialog.doDialog( )
	writeLogfile(4, "PSSharedAlbumDialog.doDialog\n")
	local f = LrView.osFactory()


	LrFunctionContext.callWithContext("showCustomDialog", function( context )
		local props = LrBinding.makePropertyTable(context)
		props.selectAll = false
		props:addObserver('selectAll', updateGlobalRowsSelected)
		props.showPasswords				= false
		props.activeRowIndex			= nil
		props.sharedAlbumName 			= nil
		props.hasError					= false

    	for i = 1, #observedKeys  do
    		props:addObserver(observedKeys[i], updateActiveAlbumStatus)
    	end

		local allPublishServices
		allPublishServiceNames, allPublishServiceVersions, allSharedAlbums = PSSharedAlbumMgmt.readSharedAlbumsFromLr()

		-- set default PublishServiceName for new Shared Albums
		props.newPublishServiceName = allPublishServiceNames[1]

    	-- initialize all rows, both filled and empty
    	for i = 1, #allSharedAlbums + nExtraRows do
	    	rowsPropertyTable[i] = LrBinding.makePropertyTable(context)
			rowsPropertyTable[i].isEntry		= false
			rowsPropertyTable[i].wasAdded		= false
			rowsPropertyTable[i].wasModified	= false
			rowsPropertyTable[i].wasDeleted		= false
			rowsPropertyTable[i].isActive		= false
			rowsPropertyTable[i].isSelected		= false
			rowsPropertyTable[i].isPublic 		= false
	    	rowsPropertyTable[i].index 			= i
	    end

	    -- copy sharedAlbumParams
    	for i = 1, #allSharedAlbums  do
    		rowsPropertyTable[i].isEntry 		= true

	    	for key, value in pairs(allSharedAlbums[i]) do
	    		rowsPropertyTable[i][key] = value
	    	end
    	end

--		writeTableLogfile(4, "allSharedAlbums", allSharedAlbums, false, 'Password')
		loadRow(props, 1)

		local saveSharedAlbums 		= false
		local downloadColorLabels 	= false
		local retcode = PSSharedAlbumDialog.showDialog(f, props, context)

		-- if not canceled: copy params back from rowsPropertyTable to allShardAlbums
		if retcode ~= 'cancel' then
	    	for i = 1,#rowsPropertyTable do
	    		local rowProps = rowsPropertyTable[i]
				if not allSharedAlbums[rowProps.index] then
					allSharedAlbums[rowProps.index] = {}
				end
				local sharedAlbum = allSharedAlbums[rowProps.index]

				if rowProps.isEntry then
    				for key, value in rowProps:pairs() do
    					if not string.find('isActive', key, 1, true) then
    						sharedAlbum[key] = value
    					end
    				end
    				if 			(sharedAlbum.wasAdded or sharedAlbum.wasModified or sharedAlbum.wasDeleted)
						and not (sharedAlbum.wasAdded and sharedAlbum.wasDeleted)
					then
    					saveSharedAlbums = true
    				end
    				if 	sharedAlbum.isSelected and not sharedAlbum.wasDeleted
    				and	(sharedAlbum.colorRed or sharedAlbum.colorYellow or sharedAlbum.colorGreen or sharedAlbum.colorBlue or sharedAlbum.colorPurple)
    				then
    					downloadColorLabels = true
    				end
				end
			end
		end

		if (retcode == 'ok' or retcode == 'other') and saveSharedAlbums then
       		PSSharedAlbumMgmt.writeSharedAlbumsToLr(allSharedAlbums)
       	end

		if retcode == 'ok' and saveSharedAlbums then
			-- uodate Shared Albums in Photo Server
       		PSSharedAlbumMgmt.writeSharedAlbumsToPS(allSharedAlbums)
		end

		if downloadColorLabels then
			local downloadSharedAlbums = {}
			writeLogfile(3, "Starting Download Comments\n")
			-- group selected Shared Albums by Publish Service ...
			for i = 1, #allSharedAlbums do
				if allSharedAlbums[i].isEntry and allSharedAlbums[i].isSelected then
					if not downloadSharedAlbums[allSharedAlbums[i].publishServiceName] then
						downloadSharedAlbums[allSharedAlbums[i].publishServiceName] = {}
					end
					local downloadSharedAlbum = downloadSharedAlbums[rowsPropertyTable[i].publishServiceName]
					downloadSharedAlbum[#downloadSharedAlbum + 1] = rowsPropertyTable[i]
					writeLogfile(3, string.format("Download Comments: Adding %s / %s\n", rowsPropertyTable[i].publishServiceName, rowsPropertyTable[i].sharedAlbumName))
				end
			end

			-- copy downloadSharedAlbums hash table to countable (indexed) table
			local downloadSharedAlbumList = {}
        	for publishServiceName, sharedAlbums in pairs(downloadSharedAlbums) do
        		downloadSharedAlbumList[#downloadSharedAlbumList + 1] = {
        			publishServiceName	= publishServiceName,
        			sharedAlbums		= sharedAlbums,
        		}
        	end

			-- ... and download comments for them
			if #downloadSharedAlbumList > 0 then
				PSSharedAlbumMgmt.downloadColorLabels(context, downloadSharedAlbumList)
			end
       	end
	end )
end

-------------------------------------------------------------------------------
-- PSSharedAlbumDialog.doDialogTask(  )
function PSSharedAlbumDialog.doDialogTask( )
	openLogfile(4)
	writeLogfile(4, "PSSharedAlbumDialog.doDialogTask\n")
	local oldLoglevel = getLogLevel()
	changeLogLevel(4)
	LrTasks.startAsyncTask(PSSharedAlbumDialog.doDialog, "Photo StatLr: Shared Album Mgmt")
	changeLogLevel(oldLoglevel)
end
--------------------------------------------------------------------------------

PSSharedAlbumDialog.doDialogTask()
