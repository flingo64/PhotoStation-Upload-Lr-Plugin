--[[----------------------------------------------------------------------------

PSSharedAlbumMgmt.lua
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
local LrDialogs			= import 'LrDialogs'
local LrFileUtils		= import 'LrFileUtils'
local LrFunctionContext	= import 'LrFunctionContext'
local LrHttp 			= import 'LrHttp'
local LrPathUtils 		= import 'LrPathUtils'
local LrPrefs			= import 'LrPrefs'
local LrTasks	 		= import 'LrTasks'
local LrView 			= import 'LrView'

local bind = LrView.bind
local share = LrView.share
local conditionalItem = LrView.conditionalItem
local negativeOfKey 	= LrBinding.negativeOfKey

-- Photo StatLr plug-in
require "PSDialogs"
require "PSUtilities"

--============================================================================--

local sharedAlbumMgmt = {}

-- the following Shared Album attributes are stored in plugin preferences
local sharedAlbumPrefKeys = {'colorRed', 'colorYellow', 'colorGreen', 'colorBlue', 'colorPurple', 'comments', 'areaTool', 'startTime', 'stopTime'}
-- the following Shared Album attributes are stored in plugin preferences
local sharedAlbumKeywordKeys = {'keywordId', 'sharedAlbumName', 'sharedAlbumPassword', 'isPublic', 'privateUrl', 'publicUrl', 'publicUrl2'}
-- the following keys may be modified and shall trigger updateRowSharedAlbumParams
local modifyKeys = {'sharedAlbumPassword', 'isPublic', 'colorRed', 'colorYellow', 'colorGreen', 'colorBlue', 'colorPurple', 'comments', 'areaTool', 'startTime', 'stopTime'}

local sharedAlbumDefaults = {
	sharedAlbumPassword	= '',
	isPublic			= true,
	colorRed			= true,
	colorYellow			= true,
	colorGreen			= true,
	colorBlue			= true,
	colorPurple			= true,
	comments			= true,
	areaTool			= true,
	startTime			= nil,
	stopTime 			= nil,
	privateUrl			= nil,
	publicUrl			= nil,
	publicUrl2			= nil,
}

local activeCatalog
local publishServices
local publishServiceNames

local allSharedAlbums			-- all Shared Albums
local rowsPropertyTable = {}	-- the visible rows in the dialog
local nExtraRows 		= 5		-- add this number of rows for additions 
-- local maxRows 			= 10 

local columnWidth = {
	-- header section
	header			= 300,
	label			= 100,
	data			= 400,
	
	-- list section
	select			= 20,
	albumName		= 150,
	publishService	= 120,
	password		= 60,
	public			= 40,
	colors			= 100,
	comments		= 70,
	area 			= 35,
	start			= 70,
	stop			= 70,
	delete			= 60,

	total			= 800,

	color			= 16,
	scrollbar		= 50,
}

-------------------------------------------------------------------------------
-- showDialog(f, propertyTable, context)
-- create the dialog contents view and open it as modal dialog
function sharedAlbumMgmt.showDialog(f, propertyTable, context)
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
    
                		f:checkbox {
                			title 			= "",
                			value 			= bind 'isSelected',
            				width_in_chars	= 0,
                		},
                
                		f:static_text {
                	  		title 			= bind 'sharedAlbumName',
                    		alignment		= 'left',
            				width 			= columnWidth.albumName,
            				mouse_down		= function()
            					return sharedAlbumMgmt.activateRow(propertyTable, i)
            				end,
                	   },
                
                		f:static_text {
                	  		title 			= bind 'publishServiceName',
                    		alignment		= 'left',
            				width 			= columnWidth.publishService,
            				mouse_down		= function()
            					return sharedAlbumMgmt.activateRow(propertyTable, i)
            				end,
                	   },
                	   
                		f:view {
               				width 			= columnWidth.public,
            				fill_horizontal	= 1,
                    		f:checkbox {
                    			value 			= bind 'isPublic',
								enabled 		= bind 'isActive',
        	       				immediate 		= true,
                        		alignment		= 'center',
                        		width_in_chars	= 0,
                    		},
            			},
                
                		f:edit_field {
              				value 			= bind 'startTime',
							enabled 		= bind 'isActive',
                   			visible			= bind 'isPublic',
               				immediate 		= true,
                    		alignment		= 'left',
                    		font			= '<system/small>',
            				width 			= columnWidth.start,
            				-- TODO: validate date input
                	   },
                
                		f:edit_field {
              				value 			= bind 'stopTime',
							enabled 		= bind 'isActive',
                   			visible			= bind 'isPublic',
               				immediate 		= true,
                    		alignment		= 'left',
                    		font			= '<system/small>',
                    		width 			= columnWidth.stop,
            				-- TODO: validate date input
                	   },
                
                		f:edit_field {
              				value 			= bind 'sharedAlbumPassword',
							enabled 		= bind 'isActive',
        					visible			= bind {
        						keys = {
        							{
            							key = 'showPasswords',
            							bind_to_object	= propertyTable,
        							},
        							{	key = 'isEntry' },
        							{	key = 'isPublic' },
        						},
        						operation = function( _, values, _ )
        							return values.showPasswords and values.isEntry and values.isPublic
        						end
        					},	
               				immediate 		= true,
                    		alignment		= 'left',
            	       		font			= '<system/small>',
        					width 			= columnWidth.password,
           				},
                
                		f:checkbox {
                			value 			= bind 'areaTool',
							enabled 		= bind 'isActive',
                   			visible			= bind 'isPublic',
                    		alignment		= 'center',
            				width 			= columnWidth.area,
                		},
            				
                		f:checkbox {
                			value 			= bind 'comments',
							enabled 		= bind 'isActive',
                   			visible			= bind 'isPublic',
                    		alignment		= 'center',
                       		width_in_chars	= 0,
            				width 			= columnWidth.comments,
                		},
            				
                		f:row {
            				width 			= columnWidth.colors,
            
                    		f:checkbox {
                    			value 			= bind 'colorRed',
								enabled 		= bind 'isActive',
            	       			visible			= bind 'isPublic',
            	        		alignment		= 'center',
                				width 			= columnWidth.color,
                    		},
            				
                    		f:checkbox {
                    			value 			= bind 'colorYellow',
								enabled 		= bind 'isActive',
            	       			visible			= bind 'isPublic',
            	        		alignment		= 'center',
                				width 			= columnWidth.color,
                    		},
            				
                    		f:checkbox {
                    			value 			= bind 'colorGreen',
								enabled 		= bind 'isActive',
            	       			visible			= bind 'isPublic',
            	        		alignment		= 'center',
                				width 			= columnWidth.color,
                    		},
            				
                    		f:checkbox {
                    			value 			= bind 'colorBlue',
								enabled 		= bind 'isActive',
            	       			visible			= bind 'isPublic',
            	        		alignment		= 'center',
                				width 			= columnWidth.color,
                    		},
            				
                    		f:checkbox {
                    			value 			= bind 'colorPurple',
								enabled 		= bind 'isActive',
            	       			visible			= bind 'isPublic',
            	        		alignment		= 'center',
                				width 			= columnWidth.color,
                    		},
                		},
            		},
        		},
        		f:checkbox {
        			value 			= bind 'wasDeleted',
	        		visible			= bind 'isEntry',
	        		alignment		= 'center',
    				width 			= columnWidth.delete,
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
					  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/SharedAlbum=Shared Album",
                    		alignment		= 'left',
            				width 			= columnWidth.label,
            		   },
    
            			f:edit_field {
            		  		value 			= bind 'activeSharedAlbumName',
--[[
            		  		value 			= bind {
            		  			keys = {'activeSharedAlbumName'},
            		  			operation = function (_, values, _)
           		  					return ifnil(	values.activeSharedAlbumName,
           		  									LOC "$$$/PSUpload/SharedAlbumMgmt/SelectAlbum=Please select a Shared Album"
												)
            		  			end,
            		  			transform = function (value, fromTable)
            		  				return value
            		  			end,
            		  		},
]]
            		  		enabled			= bind {
            		  			keys = {'activeSharedAlbumName'},
            		  			operation = function (_, values, _)
           		  					return iif(ifnil(values.activeSharedAlbumName, false), true, false)
            		  			end,
            		  		},
            		  		immediate		= true,
                    		alignment		= 'left',
                    		font			= '<system/bold>',
            				width 			= columnWidth.data,
            		   },
    				},
    				
       				f:row {
            			f:static_text {
            		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/privateUrl=Private URL:",
                    		alignment		= 'left',
            				width 			= columnWidth.label,
            		   },
    
                		f:static_text {
                	  		title 			= bind 'activePrivateUrl',
                    		alignment		= 'left',
            				width 			= columnWidth.data,
            				text_color		= LrColor("blue"),
                    		font			= '<system/small>',
            				mouse_down		= function()
           						LrHttp.openUrlInBrowser(propertyTable.activePrivateUrl)
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
                	  		title 			= bind 'activePublicUrl',
                    		alignment		= 'left',
            				text_color		= LrColor("blue"),
                    		font			= '<system/small>',
            				width 			= columnWidth.data,
            				mouse_down		= function()
           						LrHttp.openUrlInBrowser(propertyTable.activePublicUrl)
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
                	  		title 			= bind 'activePublicUrl2',
                    		alignment		= 'left',
            				text_color		= LrColor("blue"),
                    		font			= '<system/small>',
            				width 			= columnWidth.data,
            				mouse_down		= function()
            					LrHttp.openUrlInBrowser(propertyTable.activePublicUrl2)
           					end,
                		},
       				},  				
				},
   			},

			f:column {
				fill_horizontal	= 1,
				fill_vertical	= 1,
				f:group_box {
					fill_horizontal	= 1,
					fill_vertical	= 1,
        			f:push_button {
        				title 			= "Add Shared Album",
    					font			= '<system/small>', 
	    				place_horizontal= 1,
	    				place_vertical	= 0.8,
    					fill_horizontal	= 1,
        				action 			= function()
        					if sharedAlbumMgmt.showAddAlbumDialog(f, propertyTable, context) == 'ok' then
        						local emptyRowIndex = sharedAlbumMgmt.findEmptyRow()
        						-- TODO check emptyRowIndex ~= -1
        						local rowProps = rowsPropertyTable[emptyRowIndex]

        						rowProps.sharedAlbumName 	= propertyTable.activeSharedAlbumName
        						rowProps.publishServiceName = propertyTable.activePublishServiceName
        						rowProps.isEntry 			= true 
        						rowProps.wasAdded 			= true 
								for key, value in pairs(sharedAlbumDefaults) do
									rowProps[key] = value
								end
								sharedAlbumMgmt.activateRow(propertyTable, emptyRowIndex)
        					end
        				end,
        			},   			

--[[
        			f:push_button {
        				title 			= "Rename Shared Album",
    					font			= '<system/small>',
--    					enabled			= bind 'activeSharedAlbumName',
    					enabled			= bind {
    										keys = {
			        							{ key = 'activeSharedAlbumName' },
        									},
        									operation = function( _, values, _ )
        										return iif(values.activeSharedAlbumName, true, false)
        									end
        								},	
	    				place_horizontal= 1,
	    				place_vertical	= 1,
    					fill_horizontal	= 1,
        				action 			= function()
                			if sharedAlbumMgmt.showRenameDialog(f, propertyTable, context ) == 'ok' then
                				rowsPropertyTable[propertyTable.activeRowIndex].oldSharedAlbumName	=  rowsPropertyTable[propertyTable.activeRowIndex].sharedAlbumName
                				rowsPropertyTable[propertyTable.activeRowIndex].sharedAlbumName 	=  propertyTable.renameSharedAlbumName
                			end
        				end,
        			},
]]   			
    			},
    		},
		},

    	-----------------------------------------------------------------
    	-- Column Header
    	-----------------------------------------------------------------
		f:row {
			width = columnWidth.total,
			
			f:checkbox {
				title 			= "",
				tooltip 		= LOC "$$$/PSUpload/SharedAlbumMgmt/SelecAllTT=Select All",
           		width_in_chars	= 0,
				text_color		= LrColor("red"),
				value 			= bind 'selectAll',
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
		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/StartTime=Begin",
        		alignment		= 'left',
		   },
		   
			f:static_text {
				width 			= columnWidth.stop,
		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/StartTime=End",
        		alignment		= 'left',
		   },
		   
			f:column {
   				width 			= columnWidth.password,
				f:row {
    				f:static_text {
    		  			title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/Password=Password",
            			alignment		= 'left',
    					width 			= columnWidth.password,
					},
				},
				
				f:row {
        			-- TODO: Make this a Show/Hide button
        			f:checkbox {
        				title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/ShowPasswords=Show",
        				value 			= bind 'showPasswords',
        			},
				},
    		   
			},
					   
			f:static_text {
				width 			= columnWidth.area,
		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/AreaTool=Area^nTool",
        		alignment		= 'left',
		   },
		   
			f:static_text {
				width 			= columnWidth.comments,
		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/Comments=Comments",
        		alignment		= 'left',
		   },
		   
			f:column {
				width 			= columnWidth.colors,
				f:row {
        			f:static_text {
        		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/AllowedColors=Colors",
                		alignment		= 'left',
        		   },
				},
				
				f:row {
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
			
			f:static_text {
				width 			= columnWidth.delete,
		  		title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/Delete=Delete",
        		alignment		= 'left',
		   },
		},
		
    	-----------------------------------------------------------------
    	-- Srcoll row area
    	-----------------------------------------------------------------
		scrollView,		
		
    	-----------------------------------------------------------------
    	-- Dialog Footer
    	-----------------------------------------------------------------
		f:row {
			fill_horizontal = 1,
			fill_vertical 	= 1,
			
			f:column {
				fill_horizontal = 1,
				fill_vertical 	= 1,
				f:group_box {
					title = LOC "$$$/PSUpload/SharedAlbumMgmt/ActionForSelection=Action for selection",
--					fill_horizontal	= 1,
					fill_vertical	= 1,
					
					f:row {
            			f:push_button {
            				title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/DownloadColors=Download Color Labels",
        					font			= '<system/small>', 
							fill_horizontal	= 1,
            				action 			= function()
            					-- TODO: Download Colors
            				end,
            			},   			
					},

					f:row {
            			f:push_button {
            				title 			= LOC "$$$/PSUpload/SharedAlbumMgmt/DownloadComments=Download Comments",
        					font			= '<system/small>', 
							fill_horizontal	= 1,
            				action 			= function()
            					-- TODO: Download Public Comments
            				end,
            			},   			
					},
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
            				title 				= LOC "$$$/PSUpload/SharedAlbumMgmt/ApplyLocal=Apply to Lr (offline)",
        					font				= '<system/small>', 
        					fill_horizontal		= 1,
            				action 				= function()
            				end,
            			},   			
					},
					
					f:row {
            			f:push_button {
            				title 				= LOC "$$$/PSUpload/SharedAlbumMgmt/ApplyPS=Apply to Lr and PS (online)",
        					font				= '<system/small>', 
        					fill_horizontal		= 1,
            				action 				= function()
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

-------------------------------------------------------------------------------
-- showAddAlbumDialog
function sharedAlbumMgmt.showAddAlbumDialog(f, propertyTable, context)
	writeLogfile(4, "showAddAlbumDialog(): starting ...\n")

	local publishServiceItems = {}
    for i = 1, #publishServiceNames	do
    	table.insert(publishServiceItems, {
    		title	= publishServiceNames[i],
    		value	= publishServiceNames[i],
    	})
    end
	writeLogfile(4, "showAddAlbumDialog(): copied " .. tostring(#publishServiceNames) .. " Publish Service Names.\n")
    	
	
	local dialogContents = f:view {
		bind_to_object 	=	propertyTable,
	
   		f:row {
   			f:static_text  {
   				title 	= LOC "$$$/PSUpload/SharedAlbumMgmt/SharedAlbum=Shared Album",
   				width 	= share 'labelWidth',
   			},
   			 
   			f:edit_field {
   			value	= bind 'activeSharedAlbumName',
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

-------------------------------------------------------------------------------
-- updateGlobalRowsSelected: select/unselect all rows
function sharedAlbumMgmt.updateGlobalRowsSelected( propertyTable )
-- 	local message = nil

	writeLogfile(2, "updateGlobalRowsSelected() started\n")	
	for i = 1, #rowsPropertyTable do
		rowsPropertyTable[i].isSelected = propertyTable.selectAll
	end
	
--[[
	if message then
		propertyTable.message = message
		propertyTable.hasError = true
		propertyTable.hasNoError = false
	else
		propertyTable.message = nil
		propertyTable.hasError = false
		propertyTable.hasNoError = true
	end
]]	
end

-------------------------------------------------------------------------------
-- updateGlobalSharedAlbumName: 
-- 		set Rename-Flag, 
-- 		update sharedAlbumName in belonging row 
function sharedAlbumMgmt.updateGlobalSharedAlbumName( propertyTable )
--	local message = nil

	writeLogfile(2, string.format("updateGlobalSharedAlbumName(%s) started\n", propertyTable.activeSharedAlbumName))
	local rowProps = rowsPropertyTable[propertyTable.activeRowIndex]
	
	if rowProps.sharedAlbumName == propertyTable.activeSharedAlbumName then return end
	
	if not rowProps.wasRenamed  then
		rowProps.oldSharedAlbumName	= rowProps.sharedAlbumName
		rowProps.wasRenamed = true
	end
	rowProps.sharedAlbumName 	= propertyTable.activeSharedAlbumName
	
--[[
	repeat
		writeLogfile(2, "updateGlobalSharedAlbumName(): selected = " .. tostring(propertyTable.isSelected) .. "\n")	
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
]]		
end

-------------------------------------------------------------------------------
-- updateRowSharedAlbumParams:
-- 		set Modified-Flag, 
function sharedAlbumMgmt.updateRowSharedAlbumParams( propertyTable )
--	local message = nil

	writeLogfile(2, string.format("updateRowSharedAlbumParams(%s) started\n", propertyTable.sharedAlbumName))
	propertyTable.wasModified = true

--[[
	repeat
		writeLogfile(2, "updateRowSharedAlbumParams(): selected = " .. tostring(propertyTable.isSelected) .. "\n")	
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
]]
end

-------------------------------------------------------------------------------
-- activateRow()
-- 		activate the given row in dialog rows area 
function sharedAlbumMgmt.activateRow(propertyTable, i) 
   	writeLogfile(3, string.format("activateRow: %d\n", i))
	propertyTable.activeRowIndex		= i		
	propertyTable.activeSharedAlbumName	= rowsPropertyTable[i].sharedAlbumName
	propertyTable.activePrivateUrl		= rowsPropertyTable[i].privateUrl
	propertyTable.activePublicUrl		= rowsPropertyTable[i].publicUrl
	propertyTable.activePublicUrl2		= rowsPropertyTable[i].publicUrl2

	for j = 1, #rowsPropertyTable do
		rowsPropertyTable[j].isActive = false
	end
	rowsPropertyTable[i].isActive 	= true
	
end

-------------------------------------------------------------------------------
-- findEmptyRow()
-- 		find next empty row 
function sharedAlbumMgmt.findEmptyRow() 
	for i = 1, #rowsPropertyTable do
		if not rowsPropertyTable[i].isEntry then
			return i
		end
	end	
	return -1
end

-------------------------------------------------------------------------------
-- sharedAlbumMgmt.readAllSharedAlbumsFromLr()
function sharedAlbumMgmt.readAllSharedAlbumsFromLr()
	activeCatalog = LrApplication.activeCatalog()
	publishServices = activeCatalog:getPublishServices(_PLUGIN.id)
	publishServiceNames = {}
	local myPrefs = LrPrefs.prefsForPlugin(_PLUGIN)
	local nAlbums = 0

	allSharedAlbums = {}
	
    for i = 1, #publishServices	do
    	local publishService = publishServices[i]
		publishServiceNames[i] = publishService:getName()
    	local publishServiceSettings= publishService:getPublishSettings()
   	
    	local psVersion = publishServiceSettings.psVersion
    	
    	writeLogfile(3, string.format("getAllSharedAlbums: publish service %s: psVersion: %d\n", publishService:getName(), psVersion))
    	
    	local sharedAlbumKeywords = PSLrUtilities.getServiceSharedAlbumKeywords(publishService, psVersion)
		
		if sharedAlbumKeywords then
			for j = 1, #sharedAlbumKeywords do
    			nAlbums = nAlbums + 1
				allSharedAlbums[nAlbums] = {}
				local sharedAlbum = allSharedAlbums[nAlbums]
				
    			sharedAlbum.wasModified			= false
    			sharedAlbum.wasDeleted	 		= false
    			sharedAlbum.wasRenamed	 		= false
    			sharedAlbum.publishService 		= publishService
    			sharedAlbum.publishServiceName 	= publishService:getName()
    			
    			for _, key in ipairs(sharedAlbumKeywordKeys) do
    				sharedAlbum[key] = sharedAlbumKeywords[j][key]
    			end
				
    			if myPrefs.sharedAlbums and myPrefs.sharedAlbums[sharedAlbumKeywords[j].keywordId] then
    				local sharedAlbumPrefs = myPrefs.sharedAlbums[sharedAlbumKeywords[j].keywordId]
	    			for _, key in ipairs(sharedAlbumPrefKeys) do
	    				sharedAlbum[key] = sharedAlbumPrefs[key]
	    			end
				else
	    			for _, key in ipairs(sharedAlbumPrefKeys) do
	    				sharedAlbum[key] = true
	    			end
				end
			end
		end
	end 		
end

-------------------------------------------------------------------------------
-- sharedAlbumMgmt.writeAllSharedAlbumsToLr()
function sharedAlbumMgmt.writeAllSharedAlbumsToLr()
	local isPattern = true
	local myPrefs = LrPrefs.prefsForPlugin(_PLUGIN)
	
	for i = 1, #allSharedAlbums do
		local sharedAlbum = allSharedAlbums[i]
		
		if sharedAlbum.wasDeleted then
			writeLogfile(2, string.format("sharedAlbumMgmt.writeAllSharedAlbumsToLr: PubServ %s, ShAlbum: %s: deleting Album\n",
								sharedAlbum.publishServiceName, sharedAlbum.sharedAlbumName))
			-- TODO: delete album
		end
		
		if sharedAlbum.wasAdded then
			writeLogfile(2, string.format("sharedAlbumMgmt.writeAllSharedAlbumsToLr: PubServ %s, ShAlbum: %s: adding Album\n",
								sharedAlbum.publishServiceName, sharedAlbum.sharedAlbumName))
			-- TODO: add album
		end

		if sharedAlbum.wasRenamed then
			writeLogfile(2, string.format("sharedAlbumMgmt.writeAllSharedAlbumsToLr: PubServ %s, ShAlbum: %s: renaming Album to %s\n",
								sharedAlbum.publishServiceName, sharedAlbum.oldSharedAlbumName, sharedAlbum.sharedAlbumName))
			PSLrUtilities.renameKeywordById(sharedAlbum.keywordId, sharedAlbum.sharedAlbumName)
		end

		if sharedAlbum.wasModified then
			writeLogfile(2, string.format("sharedAlbumMgmt.writeAllSharedAlbumsToLr: PubServ %s, ShAlbum: %s: storing modified params\n",
								sharedAlbum.publishServiceName, sharedAlbum.sharedAlbumName))

			-- write back attribute to Shared Album keyword synonyms: private/public and password
			if not sharedAlbum.isPublic then
				PSLrUtilities.addKeywordSynonyms(sharedAlbum.keywordId, {"private"})
			else
				PSLrUtilities.removeKeywordSynonyms(sharedAlbum.keywordId, {"private"})
			end
			if ifnil(sharedAlbum.sharedAlbumPassword, '') ~= '' then
				PSLrUtilities.addKeywordSynonyms(sharedAlbum.keywordId, {"password:" .. sharedAlbum.sharedAlbumPassword})
			else
				PSLrUtilities.removeKeywordSynonyms(sharedAlbum.keywordId, {"password:.*"}, isPattern)
			end
			
			-- write back attributes to Shared Album plugin prefs:
			--   colors, comments, start/stoptime
			if not myPrefs.sharedAlbums then myPrefs.sharedAlbums = {} end
			if not myPrefs.sharedAlbums[sharedAlbum.keywordId] then myPrefs.sharedAlbums[sharedAlbum.keywordId] = {} end
			
			local sharedAlbumPrefs = myPrefs.sharedAlbums[sharedAlbum.keywordId]
			for _, key in ipairs(sharedAlbumPrefKeys) do
				sharedAlbumPrefs[key] = sharedAlbum[key]
			end
			myPrefs.sharedAlbums[sharedAlbum.keywordId] = myPrefs.sharedAlbums[sharedAlbum.keywordId]
			myPrefs.sharedAlbums = myPrefs.sharedAlbums
		end
	end	
end

-------------------------------------------------------------------------------
-- sharedAlbumMgmt.writeAllSharedAlbumsToPS()
-- update all modified/added/deleted Photo Station Shared Albums
function sharedAlbumMgmt.writeAllSharedAlbumsToPS()
	local numDeletes, numAdds, numRenames, numModifies = 0, 0, 0, 0
	local numFailDeletes, numFailAdds, numFailRenames, numFailModifies = 0, 0, 0, 0
	
	for i = 1, #allSharedAlbums do
		local sharedAlbum 		= allSharedAlbums[i]
		local publishSettings	= sharedAlbum.publishService:getPublishSettings()

		if sharedAlbum.wasAdded or sharedAlbum.wasDeleted or sharedAlbum.wasRenamed or sharedAlbum.wasModified then
    	-- open session: initialize environment, get missing params and login
        	local sessionSuccess, reason = openSession(publishSettings, nil, 'ManageSharedAlbums')
        	if not sessionSuccess then
        		if reason ~= 'cancel' then
        			showFinalMessage("Photo StatLr: Update Photo Station SharedAlbums failed!", reason, "critical")
        		end
        		closeLogfile()
        		writeLogfile(3, "sharedAlbumMgmt.writeAllSharedAlbumsToPS(): nothing to do\n")
        		return
        	end
		end 
		
		if sharedAlbum.wasDeleted then
			-- delete Shared Album in Photo Station
			writeLogfile(3, string.format('writeAllSharedAlbumsToPS: deleting %s.\n', sharedAlbum.sharedAlbumName))
			-- TODO: delete album in PS
			numDeletes = numDeletes + 1
			break
		end
		
		if sharedAlbum.wasAdded then
			-- add Shared Album in Photo Station
			-- TODO: add album in PS
			if shareResult then
				numAdds = numAdds + 1
			else
				numFailAdds = numAdds + 1
			end

		end 		

		if sharedAlbum.wasRenamed then
			-- rename Shared Album in Photo Station
			writeLogfile(3, string.format('writeAllSharedAlbumsToPS: rename %s to %s.\n', sharedAlbum.oldSharedAlbumName, sharedAlbum.sharedAlbumName))
			local success, errorCode = PSPhotoStationAPI.renameSharedAlbum(publishSettings.uHandle, sharedAlbum.oldSharedAlbumName, sharedAlbum.sharedAlbumName) 
	
			writeLogfile(2, string.format('writeAllSharedAlbumsToPS(%s):renameSharedAlbum to %s returns %s.\n', 
											sharedAlbum.oldSharedAlbumName, sharedAlbum.sharedAlbumName, iif(success, 'OK', tostring(ifnil(errorCode, '<nil>')))))
			if success then
				numRenames = numRenames + 1
			else
				numFailRenames = numFailRenames + 1
			end
		end

		if sharedAlbum.wasModified then
			-- modify Shared Album in Photo Station
			writeLogfile(3, string.format('writeAllSharedAlbumsToPS: updating %s.\n', sharedAlbum.sharedAlbumName))
			local sharedAlbumAttributes = {}
			
			sharedAlbumAttributes.is_shared 	= sharedAlbum.isPublic
   			-- TODO: check if PS Version is 66 or above
   			sharedAlbumAttributes.is_advanced 	= true

			if sharedAlbum.isPublic then
    			if ifnil(sharedAlbum.sharedAlbumPassword, '') ~= '' then
    				sharedAlbumAttributes.enable_password = true
    				sharedAlbumAttributes.password = sharedAlbum.sharedAlbumPassword
    			else
    				sharedAlbumAttributes.enable_password = false
    			end

				if ifnil(sharedAlbum.startTime, '') ~= '' then
					sharedAlbumAttributes.start_time = sharedAlbum.startTime
				end
				  
				if ifnil(sharedAlbum.stopTime, '') ~= '' then
				sharedAlbumAttributes.end_time 		= sharedAlbum.stopTime
				end
    			
    			sharedAlbumAttributes.enable_marquee_tool	= sharedAlbum.areaTool
        		sharedAlbumAttributes.enable_comment 		= sharedAlbum.comments
     
        		sharedAlbumAttributes.enable_color_label	= sharedAlbum.colorRed or sharedAlbum.colorYellow or sharedAlbum.colorGreen or
        													  sharedAlbum.colorBlue or sharedAlbum.colorPurple
        		if sharedAlbumAttributes.enable_color_label then
	        		sharedAlbumAttributes.color_label_1		= iif(sharedAlbum.colorRed, "red", '')
    	    		sharedAlbumAttributes.color_label_2		= iif(sharedAlbum.colorYellow, "yellow", '')
        			sharedAlbumAttributes.color_label_3		= iif(sharedAlbum.colorGreen, "green", '')
        			sharedAlbumAttributes.color_label_4		= ''
        			sharedAlbumAttributes.color_label_5		= iif(sharedAlbum.colorBlue, "blue", '')
        			sharedAlbumAttributes.color_label_6		= iif(sharedAlbum.colorPurple, "purple", '')
        		end
        	end
			
			local shareResult = PSPhotoStationAPI.editSharedAlbum(publishSettings.uHandle, sharedAlbum.sharedAlbumName, sharedAlbumAttributes) 
	
			writeLogfile(2, string.format('writeAllSharedAlbumsToPS(%s) returns %s.\n', sharedAlbum.sharedAlbumName, iif(shareResult, 'OK', tostring(ifnil(shareResult.errorCode, '<nil>')))))
			
			if shareResult then
				numModifies = numModifies + 1
			else
				numFailModifies = numFailModifies + 1
			end
		end
	end
	
	local message = LOC ("$$$/PSUpload/FinalMsg/UpdatePSSharedAlbums=Update Shared Albums: Add: ^1 OK / ^2 Fail, Rename: ^3 OK / ^4 Fail, Modify: ^5 OK / ^6 Fail, Delete: ^7 OK / ^8 Fail\n", 
					numAdds, numFailAdds, numRenames, numFailRenames, numModifies, numFailModifies, numDeletes, numFailDeletes)
	local messageType = iif(numFailAdds > 0 or numFailRenames > 0 or numFailModifies > 0 or numFailDeletes > 0, 'critical', 'info')
	showFinalMessage ("Photo StatLr: Update Shared Albums done", message, messageType)
end

-------------------------------------------------------------------------------
-- sharedAlbumMgmt.doDialog(  )
function sharedAlbumMgmt.doDialog( )
	writeLogfile(4, "sharedAlbumMgmt.doDialog\n")
	local f = LrView.osFactory()

	
	LrFunctionContext.callWithContext("showCustomDialog", function( context )
		local props = LrBinding.makePropertyTable(context)
		props.selectAll = false
		props:addObserver('selectAll', sharedAlbumMgmt.updateGlobalRowsSelected)
		props.showPasswords				= false		
		props.activeRowIndex			= nil		
		props.activeSharedAlbumName 	= nil
		props:addObserver('activeSharedAlbumName', sharedAlbumMgmt.updateGlobalSharedAlbumName)

       	sharedAlbumMgmt.readAllSharedAlbumsFromLr()
    	
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
	    
    	for i = 1, #allSharedAlbums  do
    		rowsPropertyTable[i].isEntry 		= true
    		rowsPropertyTable[i].isSelected 	= false
	    	for key, value in pairs(allSharedAlbums[i]) do
	    		rowsPropertyTable[i][key] = value
	    	end
			rowsPropertyTable[i].sharedAlbumNameOld	= rowsPropertyTable[i].sharedAlbumName	    	
    	end

    	for i = 1,#rowsPropertyTable do
	    	for j = 1, #modifyKeys  do
	    		rowsPropertyTable[i]:addObserver(modifyKeys[j], sharedAlbumMgmt.updateRowSharedAlbumParams)
	    	end
	    end
		
		local retcode = sharedAlbumMgmt.showDialog(f, props, context)
		
		-- if not canceled: copy params back from rowsPropertyTable to allShardAlbums 
		if retcode ~= 'cancel' then
	    	for i = 1,#rowsPropertyTable do
	    		local rowProps = rowsPropertyTable[i]
				local sharedAlbum = allSharedAlbums[rowProps.index]
	
				for key, value in rowProps:pairs() do
					if rowProps.isEntry and not string.find('isActive,isSelected', key, 1, true) then
						sharedAlbum[key] = value
					end
				end
			end
		end
		
		if retcode == 'ok' or retcode == 'other' then
       		sharedAlbumMgmt.writeAllSharedAlbumsToLr()
       	end
       	
		if retcode == 'ok'  then
			-- uodate Shared Albums in Photo Station
       		sharedAlbumMgmt.writeAllSharedAlbumsToPS()
		end
		
	end )
end

-------------------------------------------------------------------------------
-- sharedAlbumMgmt.doDialogTask(  )
function sharedAlbumMgmt.doDialogTask( )
	openLogfile(4)
	writeLogfile(4, "sharedAlbumMgmt.doDialogTask\n")
	LrTasks.startAsyncTask(sharedAlbumMgmt.doDialog, "Photo StatLr: Shared Album Mgmt")
end
--------------------------------------------------------------------------------

sharedAlbumMgmt.doDialogTask()
