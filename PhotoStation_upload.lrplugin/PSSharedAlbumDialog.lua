--[[----------------------------------------------------------------------------

PSSharedAlbumDialog.lua
This file is part of Photo StatLr - Lightroom plugin.
Copyright(c) 2017, Martin Messmer

Management of Photo Station Shared Albums for Lightroom Photo StatLr

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

------------------------------------------------------------------------------]]

-- Lightroom SDK
local LrApplication		= import 'LrApplication'
local LrBinding			= import 'LrBinding'
local LrColor			= import 'LrColor'
local LrDate			= import 'LrDate'
local LrDialogs			= import 'LrDialogs'
local LrFileUtils		= import 'LrFileUtils'
local LrFunctionContext	= import 'LrFunctionContext'
local LrHttp 			= import 'LrHttp'
local LrPathUtils 		= import 'LrPathUtils'
local LrPrefs			= import 'LrPrefs'
local LrTasks	 		= import 'LrTasks'
local LrView 			= import 'LrView'

local bind 				= LrView.bind
local share 			= LrView.share
local conditionalItem 	= LrView.conditionalItem
local negativeOfKey 	= LrBinding.negativeOfKey

-- Photo StatLr plug-in
require "PSDialogs"
require "PSUtilities"
require "PSSharedAlbumMgmt"

--============================================================================--

-- the following keys can be modified in active album view and should trigger updateActiveAlbumStatus() 
local observedKeys = {'publishServiceName', 'sharedAlbumName', 'startTime', 'stopTime'}

local allPublishServiceNames
local allSharedAlbums				-- all Shared Albums

local rowsPropertyTable 	= {}	-- the visible rows in the dialog
local nExtraRows 			= 5		-- add this number of rows for additions 

local columnWidth = {
	-- header section
	header			= 300,
	label			= 80,
	data			= 250,
	url				= 400,
	password		= 166,
	
	-- list section
	delete			= 30,
	albumName		= 170,
	publishService	= 120,
	public			= 40,
	start			= 70,
	stop			= 70,
	area 			= 35,
	comments		= 60,
	colors			= 100,
	sync			= 40,

	total			= 740,

	color			= 16,
	scrollbar		= 50,
}

-------------------------------------------------------------------------------
-- updateActiveAlbumStatus:
-- 
local function updateActiveAlbumStatus( propertyTable )
	local message = nil

	repeat
		-- Use a repeat loop to allow easy way to "break" out.
		-- (It only goes through once.)

		if ifnil(propertyTable.publishServiceName, '') == '' then
			message = LOC "$$$/PSUpload/SharedAlbumMgmt/Messages/PublishServiceMissing=Please select a Publish Service!" 
			break
		end

		if ifnil(propertyTable.sharedAlbumName, '') == '' then
			message = LOC "$$$/PSUpload/SharedAlbumMgmt/Messages/SharedAlbumNameMissing=Please enter a Shared Album Name!" 
			break
		end

		-- if this is a new entry: check if Album does not yet exist
		if propertyTable.wasAdded then
			for i = 1, #allSharedAlbums do
				if 	propertyTable.publishServiceName == allSharedAlbums[i].publishServiceName
				and	propertyTable.sharedAlbumName == allSharedAlbums[i].sharedAlbumName
				then
        			message = LOC "$$$/PSUpload/SharedAlbumMgmt/Messages/SharedAlbumAlreadyExist=Shared Album already exists!" 
        			break
				end
			end
		end
		
		if ifnil(propertyTable.startTime, '') ~= '' and not PSSharedAlbumDialog.validateDate(nil, propertyTable.startTime) then
			message = LOC "$$$/PSUpload/SharedAlbumMgmt/Messages/DateIncorrect=Date must be 'YYYY-mm-dd'!" 
			break
		end

		if ifnil(propertyTable.stopTime, '') ~= '' and not PSSharedAlbumDialog.validateDate(nil, propertyTable.stopTime) then
			message = LOC "$$$/PSUpload/SharedAlbumMgmt/Messages/DateIncorrect=Date must be 'YYYY-mm-dd'!" 
			break
		end

	until true
	
	if message then
		propertyTable.message = message
		propertyTable.hasError = true
		propertyTable.hasNoError = false
	else
		propertyTable.message = nil
		propertyTable.hasError = false
		propertyTable.hasNoError = true
	end
end

-------------------------------------------------------------------------------
-- updateGlobalRowsSelected: select/unselect all rows
local function updateGlobalRowsSelected( propertyTable )
	writeLogfile(2, "updateGlobalRowsSelected() started\n")	
	for i = 1, #rowsPropertyTable do
		rowsPropertyTable[i].isSelected = propertyTable.selectAll
	end
	
end

--[[
-------------------------------------------------------------------------------
-- updateActiveSharedAlbumParams: 
-- 		set Modify-Flag, 
-- 		update sharedAlbum params in belonging row 
local function updateActiveSharedAlbumParams( propertyTable )
--	local message = nil

	writeLogfile(2, string.format("updateActiveSharedAlbumParams(%s) started\n", propertyTable.sharedAlbumName))
	local rowProps = rowsPropertyTable[propertyTable.activeRowIndex]
	
	for _, key in ipairs(activeAlbumModifyKeys) do
		rowProps[key] = propertyTable[key]
	end
	
	rowProps.wasModified = true
	
end
]]

-------------------------------------------------------------------------------
-- activateRow()
-- 		activate the given row in dialog rows area 
local function activateRow(propertyTable, i)
	if not propertyTable.hasError then  
    	-- save old values
    	if ifnil(propertyTable.activeRowIndex, i)  ~= i then
    		local lastRowProps = rowsPropertyTable[propertyTable.activeRowIndex]
    		
    		if lastRowProps.sharedAlbumName ~= propertyTable.sharedAlbumName then
    			if not lastRowProps.wasRenamed then
    				lastRowProps.oldSharedAlbumName	= lastRowProps.sharedAlbumName
    			end
    			lastRowProps.wasRenamed = true
    		end
    		
    		for key, _ in pairs(PSSharedAlbumMgmt.sharedAlbumDefaults) do
        		if lastRowProps[key] ~= propertyTable[key] then
    				writeLogfile(3, string.format("activateRow(%s/%s): key %s changed from %s to %s\n", 
    										lastRowProps.publishServiceName, lastRowProps.sharedAlbumeName, key, lastRowProps[key], propertyTable[key]))		
        			lastRowProps[key] = propertyTable[key]
        			lastRowProps.wasModified = true
        		end
    		end
    	end
	end

	-- load new values
	propertyTable.activeRowIndex		= i		

	for key, _ in pairs(PSSharedAlbumMgmt.sharedAlbumDefaults) do
		propertyTable[key] = rowsPropertyTable[i][key]
	end
	propertyTable.wasAdded = rowsPropertyTable[i].wasAdded
	
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
            				width 			= columnWidth.albumName,
            				mouse_down		= function()
            					return activateRow(propertyTable, i)
            				end,
                	   },
                
                		f:static_text {
                	  		title 			= bind 'publishServiceName',
                    		alignment		= 'left',
            				width 			= columnWidth.publishService,
            				mouse_down		= function()
            					return activateRow(propertyTable, i)
            				end,
                	   },
                	   
                		f:checkbox {
                			value 			= bind 'isPublic',
							enabled 		= false,
	           				width 			= columnWidth.public,
                		},
                
                		f:edit_field {
              				value 			= bind 'startTime',
							enabled 		= false,
                   			visible			= bind 'isPublic',
               				immediate 		= true,
               				validate		= PSSharedAlbumDialog.validateDate,
                    		alignment		= 'left',
                    		font			= '<system/small>',
            				width 			= columnWidth.start,
                	   },
                
                		f:edit_field {
              				value 			= bind 'stopTime',
							enabled 		= false,
                   			visible			= bind 'isPublic',
               				immediate 		= true,
               				validate		= PSSharedAlbumDialog.validateDate,
                    		alignment		= 'left',
                    		font			= '<system/small>',
                    		width 			= columnWidth.stop,
                	   },
                
						-- TODO: check if isAdvanced                
                		f:checkbox {
                			value 			= bind 'areaTool',
							enabled 		= false,
                   			visible			= bind 'isPublic',
            				width 			= columnWidth.area,
                		},
            				
                		f:checkbox {
                			value 			= bind 'comments',
							enabled 		= false,
                   			visible			= bind 'isPublic',
            				width 			= columnWidth.comments,
                		},
            				
 --               		f:row {
 --           				width 			= columnWidth.colors,
            
                    		f:checkbox {
                    			value 			= bind 'colorRed',
								enabled 		= false,
            	       			visible			= bind 'isPublic',
                				width 			= columnWidth.color,
                    		},
            				
                    		f:checkbox {
                    			value 			= bind 'colorYellow',
								enabled 		= false,
            	       			visible			= bind 'isPublic',
                				width 			= columnWidth.color,
                    		},
            				
                    		f:checkbox {
                    			value 			= bind 'colorGreen',
								enabled 		= false,
            	       			visible			= bind 'isPublic',
                				width 			= columnWidth.color,
                    		},
            				
                    		f:checkbox {
                    			value 			= bind 'colorBlue',
								enabled 		= false,
            	       			visible			= bind 'isPublic',
                				width 			= columnWidth.color,
                    		},
            				
                    		f:checkbox {
                    			value 			= bind 'colorPurple',
								enabled 		= false,
            	       			visible			= bind 'isPublic',
                				width 			= columnWidth.color,
                    		},
--                		},

                		f:checkbox {
                			title 			= "",
                			value 			= bind 'isSelected',
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
--	   			fill_horizontal = 1,
   				PSDialogs.photoStatLrSmallView(f, nil),
   			},
   			
   			f:column {
	   			fill_horizontal = 1,
	   			fill_vertical = 1,
				f:group_box {
		   			title			= LOC "$$$/PSUpload/SharedAlbumMgmt/activeSharedAlbum=Active Shared Album",
		   			fill_horizontal = 1,
		   			fill_vertical	= 1,
		   			
               		f:row {
            			f:static_text {
					  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/SharedAlbum=Shared Album"
					  								.. ":",
                    		alignment		= 'left',
            				width 			= columnWidth.label,
            		   },
    
            			f:edit_field {
            		  		value 			= bind 'sharedAlbumName',
               				enabled 		= bind 'wasAdded',
            		  		immediate		= true,
                    		alignment		= 'left',
--                    		font			= '<system/bold>',
            				width 			= columnWidth.data,
            		   },

 		           		f:row {
							width				= columnWidth.data,
							fill_horizontal 	= 1,
							
                   			f:static_text  {
                		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/PublishService=Publish Service"
                		  							   .. ":",
    --            				width 			= columnWidth.label,
                   			},
                   			 
                			f:popup_menu {
                				items 			= publishServiceItems,
                				alignment 		= 'left',
                --				fill_horizontal = 1,
                				value 			= bind 'publishServiceName',
                				enabled 		= bind 'wasAdded',
								fill_horizontal 	= 1,
                			},
            			},

    				},
    				
       				f:row {
            			f:static_text {
            		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/privateUrl=Private URL:",
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
           						LrHttp.openUrlInBrowser(propertyTable.privateUrl)
           					end,
                	   },
       				},
    
       				f:row {
            			f:static_text {
            		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/publicUrl=Public URL:",
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
           						LrHttp.openUrlInBrowser(propertyTable.publicUrl)
           					end,
                	   },
                	   
       				},
    
       				f:row {
            			f:static_text {
            		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/publicUrl2=Public URL 2:",
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
            					LrHttp.openUrlInBrowser(propertyTable.publicUrl2)
           					end,
                		},
       				},  				

            		f:row {
            			f:view {
							width	= columnWidth.password,

            				f:static_text {
            		  			title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/Password=Password",
                    			alignment		= 'left',
            					visible			= bind 'isAdvanced',	
        					},
    
                    		f:edit_field {
                  				value 			= bind 'sharedAlbumPassword',
            					visible			= bind {
            						keys = {
            							{	key = 'isAdvanced' },
            							{	key = 'isPublic'},
            						},
            						operation = function( _, values, _ )
            							return values.isAdvanced and values.isPublic
            						end,
            					},	
                   				immediate 		= true,
                        		alignment		= 'left',
                	       		font			= '<system/small>',
               				},
						},

            			f:view {
            				width 			= columnWidth.public,
    
                			f:static_text {
    					  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/Public=Public",
                        		alignment		= 'left',
                			},

                    		f:checkbox {
                    			value 			= bind 'isPublic',
                        		alignment		= 'center',
                    		},
    					},

            			f:view {
							width	= columnWidth.start,

                			f:static_text {
			    		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/StartTime=From",
                        		alignment		= 'left',
            					visible			= bind 'isAdvanced',	
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
			    		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/StopTime=Until",
                        		alignment		= 'left',
            					visible			= bind 'isAdvanced',	
                			},
        
                			f:edit_field {
                		  		value 			= bind 'stopTime',
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
                				width 			= columnWidth.stop,
                			},
            			},

						f:view {
                			f:static_text {
                				width 			= columnWidth.area,
                		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/AreaTool=Area",
            					visible			= bind 'isAdvanced',	
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
                		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/Comments=Comments",
                        		alignment		= 'left',
            					visible			= bind 'isAdvanced',	
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
	            					visible			= bind 'isAdvanced',	
            						width 			= columnWidth.color,
               					},
            	
            	   				f:color_well {
               						value			= LrColor('yellow'),
               						enabled			= false,
	            					visible			= bind 'isAdvanced',	
            						width 			= columnWidth.color,
               					},
            	
            	   				f:color_well {
               						value			= LrColor('green'),
               						enabled			= false,
	            					visible			= bind 'isAdvanced',	
            						width 			= columnWidth.color,
               					},
            	
            	   				f:color_well {
               						value			= LrColor('blue'),
               						enabled			= false,
	            					visible			= bind 'isAdvanced',	
            						width 			= columnWidth.color,
               					},
            	
            	   				f:color_well {
               						value			= LrColor('purple'),
               						enabled			= false,
	            					visible			= bind 'isAdvanced',	
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
    					  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/Advanced=Advanced",
                        		alignment		= 'right',
                        		fill_horizontal = 1
                			},

                    		f:checkbox {
                    			value 			= bind 'isAdvanced',
                    			enabled			= false,
                        		alignment		= 'right',
                        		place_horizontal = 1
                    		},
        				},
					},
				},
   			},
		},

    	-----------------------------------------------------------------
    	-- Column Header
    	-----------------------------------------------------------------
		f:group_box {
       		fill_horizontal = 1,

    		f:row {
    			width = columnWidth.total,
    			
    			f:static_text {
    				width 			= columnWidth.delete,
    		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/AddDelete=Delete",
            		alignment		= 'left',
    			},
    
    			f:static_text {
    		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/SharedAlbum=Shared Album",
            		alignment		= 'left',
    				width 			= columnWidth.albumName,
    		  	},
    		   
    			f:static_text {
    		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/PublishService=Publish Service",
            		alignment		= 'left',
    				width 			= columnWidth.publishService,
    		  	},
    		   
    			f:static_text {
    		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/Public=Public",
            		alignment		= 'left',
    				width 			= columnWidth.public,
    		  	},
    		   
    			f:static_text {
    				width 			= columnWidth.start,
    		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/StartTime=From",
            		alignment		= 'left',
    		  	},
    		   
    			f:static_text {
    				width 			= columnWidth.stop,
    		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/StopTime=Until",
            		alignment		= 'left',
    		   	},
    		   
    			f:static_text {
    				width 			= columnWidth.area,
       		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/AreaTool=Area",
            		alignment		= 'left',
    		  	},
    		   
    			f:static_text {
    				width 			= columnWidth.comments,
    		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/Comments=Comments",
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
          				width 			= columnWidth.sync,
               			f:static_text  {
               				title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/DownloadColor=Sync",
--               				width 			= columnWidth.sync,
               			},
    				},
           			
        			f:row {
                   		width 			= columnWidth.sync,
            			f:checkbox {
            				tooltip 		= LOC "$$$/PSUpload/SharedAlbumMgmt/DownloadColorTT=Select All",
            				width_in_chars	= 0,
            				value 			= bind 'selectAll',
            			},
    				},
				},
    		},
    		
        	-----------------------------------------------------------------
        	-- Srcoll row area
        	-----------------------------------------------------------------
    		scrollView,	
		}, 
		f:spacer {	fill_horizontal = 1,}, 
		
    	-----------------------------------------------------------------
    	-- Dialog Footer
    	-----------------------------------------------------------------
		f:row {
			fill_horizontal = 1,
			fill_vertical 	= 1,
			
			f:column {
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
			
			f:column {
				fill_horizontal = 1,
				fill_vertical 	= 1,
			},
			
			f:column {
				fill_horizontal = 1,
				fill_vertical 	= 1,
				f:group_box {
					title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/ApplyActions=Apply Changes",
					alignment 		= right,
					place_horizontal	= 1,
--					fill_horizontal	= 1,
					fill_vertical	= 1,
					
					f:row {
            			f:push_button {
            				title 			= "Add Shared Album",
        					font			= '<system/small>', 
--    	    				place_horizontal= 1,
--    	    				place_vertical	= 0.8,
        					fill_horizontal	= 1,
            				action 			= function()
           						local emptyRowIndex = findEmptyRow()
           						-- TODO check emptyRowIndex ~= -1
           						local rowProps = rowsPropertyTable[emptyRowIndex]
        						rowProps.isEntry 			= true 
        						rowProps.wasAdded 			= true 
        						rowProps.wasModified		= true
								for key, value in pairs(PSSharedAlbumMgmt.sharedAlbumDefaults) do
									rowProps[key] = value
								end
    							activateRow(propertyTable, emptyRowIndex)
            				end,
            			},   			
					}, 
    			},
			},
		},
	}
	
	return LrDialogs.presentModalDialog(
		{
			title 		= "Manage Photo Station Shared Albums",
			contents 	= dialogContents,
			actionVerb 	=  LOC "$$$/PSUpload/SharedAlbumMgmt/ApplyPS=Apply to Lr and PS (online)",
			otherVerb	=  LOC "$$$/PSUpload/SharedAlbumMgmt/ApplyLocal=Apply to Lr (offline)",
		}
	)
	
end

--[[
-------------------------------------------------------------------------------
-- showAddAlbumDialog
function PSSharedAlbumDialog.showAddAlbumDialog(f, propertyTable, context)
	writeLogfile(4, "showAddAlbumDialog(): starting ...\n")

	local publishServiceItems = {}
    for i = 1, #allPublishServiceNames	do
    	table.insert(publishServiceItems, {
    		title	= allPublishServiceNames[i],
    		value	= allPublishServiceNames[i],
    	})
    end
	writeLogfile(4, "showAddAlbumDialog(): copied " .. tostring(#allPublishServiceNames) .. " Publish Service Names.\n")
    	
	
	local dialogContents = f:view {
		bind_to_object 	=	propertyTable,
	
   		f:row {
   			f:static_text  {
   				title 	= LOC "$$$/PSUpload/SharedAlbumMgmt/SharedAlbum=Shared Album",
   				width 	= share 'labelWidth',
   			},
   			 
   			f:edit_field {
   			value	= bind 'sharedAlbumName',
   			},
   		},

   		f:row {
   			f:static_text  {
		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/PublishService=Publish Service",
   				width 	= share 'labelWidth',
   			},
   			 
			f:popup_menu {
				items 			= publishServiceItems,
				alignment 		= 'left',
--				fill_horizontal = 1,
				value 			= bind 'activePublishServiceName',
			},
   		},
   	}

	writeLogfile(4, "showAddAlbumDialog(): calling presentModalDialog() ...\n")
	return LrDialogs.presentModalDialog(
		{
			title 		= "Add Shared Album",
			contents 	= dialogContents,
		}
	) 	
   	
end
]]

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
		
       	allPublishServiceNames, allSharedAlbums = PSSharedAlbumMgmt.readSharedAlbumsFromLr()
    	
    	-- initialize all rows, both filled and empty
    	for i = 1, #allSharedAlbums + nExtraRows do
	    	rowsPropertyTable[i] = LrBinding.makePropertyTable(context)
			rowsPropertyTable[i].isEntry		= false
			rowsPropertyTable[i].wasAdded		= false
			rowsPropertyTable[i].wasRenamed		= false
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
	    	
			rowsPropertyTable[i].sharedAlbumNameOld	= rowsPropertyTable[i].sharedAlbumName	    	
    	end

		activateRow(props, 1)

		local saveSharedAlbums 		= false
		local downloadColorLabels 	= false
		local retcode = PSSharedAlbumDialog.showDialog(f, props, context)
		
		-- if not canceled: copy params back from rowsPropertyTable to allShardAlbums 
		if retcode ~= 'cancel' then
			-- write back active row
			activateRow(props, findEmptyRow())
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
    				if sharedAlbum.wasAdded or sharedAlbum.wasModified or sharedAlbum.wasRenamed or sharedAlbum.wasDeleted then
    					saveSharedAlbums = true
    				end
    				if 	sharedAlbum.isSelected 
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
			-- uodate Shared Albums in Photo Station
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
	LrTasks.startAsyncTask(PSSharedAlbumDialog.doDialog, "Photo StatLr: Shared Album Mgmt")
end
--------------------------------------------------------------------------------

PSSharedAlbumDialog.doDialogTask()
