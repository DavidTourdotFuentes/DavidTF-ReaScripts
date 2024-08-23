--@description Color region based on clip in region color
--@author DavidTF
--@version 1.0
--@changelog
--    Added buttons to jump to regions
--    Bugfix : Default color no longer display on black color in color choices view
--    Bugfix : Default color now properly display on color choices view
--@about
--    Color region based on items in the region color. If multiple colors detected, show a popup to choose witch color for each region

region_to_color = {}

function ReturnColorsInRegion(marker_id, region_id, name, start_pos, end_pos)

    local color_list = {}

    for i = 1, reaper.CountMediaItems(0) do
        current_item = reaper.GetMediaItem(0, i - 1)
        item_start = reaper.GetMediaItemInfo_Value(current_item, "D_POSITION") + 0.01
        item_end = item_start + reaper.GetMediaItemInfo_Value(current_item, "D_LENGTH") - 0.01
        
        if item_start >= start_pos and item_end <= end_pos then
            item_color = reaper.GetDisplayedMediaItemColor(current_item)
            
            -- Search to dont all color to list if color is already in the list
            found = 0
            for i=1, #color_list do
                if color_list[i] == item_color then
                    found = found + 1
                end
            end
            if item_color == 0 then
                item_color = 4285690454
            end
            if found == 0 and item_color ~= nil then
                table.insert(color_list, item_color)
            end
        end
    end
    
    if #color_list ~= 1 then
        table.insert(color_list, 1, marker_id)
        table.insert(color_list, 2, region_id)
        table.insert(color_list, 3, name)
    end
    
    return color_list
end

function GuiInit()
    ctx = reaper.ImGui_CreateContext('Color Picker Tool')
    FONT = reaper.ImGui_CreateFont('sans-serif', 15)
    reaper.ImGui_Attach(ctx, FONT)
    winW, winH = 300, 200
    isClosed = false
    r_name = 0
end


function GuiElements()
    if reaper.ImGui_BeginTable(ctx, 'ColorTable', 1) then
    
        for i=1, #region_to_color do
        
            reaper.ImGui_TableNextRow(ctx)
            
            reaper.ImGui_TableSetColumnIndex(ctx, 0)
            
            local preview_name = region_to_color[i][2] .. " " .. region_to_color[i][3]
            
            if reaper.ImGui_Button(ctx, 'Region : ' .. preview_name) then
                _, _, reg_pos, _ , _, _ = reaper.EnumProjectMarkers(region_to_color[i][1])
                if reg_pos ~=  reaper.GetCursorPosition() then
                  reaper.SetEditCurPos(reg_pos, true, false)
                  reaper.Main_OnCommand(reaper.NamedCommandLookup('_SWS_SELNEXTMORR'), 0)
                end
            end
            
            for j=4, #region_to_color[i] do
                            
                color = reaper.ImGui_ColorConvertNative(region_to_color[i][j])
                
                color = (color << 8) | 0xFF -- shift 0x00RRGGBB to 0xRRGGBB00 then add 0xFF for 100% opacity
                
                if reaper.ImGui_ColorButton(ctx, "Color "..i*j.." ("..color..")", color, reaper.ImGui_ColorEditFlags_None(), 30.0, 30.0) then
                    reaper.Undo_BeginBlock()
                    
                    curr_retval, curr_isrgn, curr_pos, curr_rgnend, curr_name, curr_markrgnindexnumber = reaper.EnumProjectMarkers(region_to_color[i][1])
                    reaper.SetProjectMarker3(0, curr_markrgnindexnumber, curr_isrgn, curr_pos, curr_rgnend, curr_name, region_to_color[i][j])
                    
                    reaper.UpdateArrange()
                    reaper.Undo_EndBlock("User choose color for region based on items colors", 0)
                end
                
                reaper.ImGui_SameLine(ctx)
            end
        end
        
        reaper.ImGui_EndTable(ctx)
    
    end
end

function GuiLoop()
    local window_flags = reaper.ImGui_WindowFlags_NoCollapse()
    reaper.ImGui_SetNextWindowSize(ctx, winW, winH, reaper.ImGui_Cond_Once())
    reaper.ImGui_PushFont(ctx, FONT)
    reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_ViewportsNoDecoration(), 0)
    
    local visible, open = reaper.ImGui_Begin(ctx, 'Choose colors', true, window_flags)
    
    if visible then
        
        GuiElements()
        
        reaper.ImGui_End(ctx)
    end
    
    reaper.ImGui_PopFont(ctx)
    
    if open and not isClosed then
        reaper.defer(GuiLoop)
    end
end

function ShowColorsOptions()
    GuiInit()
    GuiLoop()
end

function Main()
  
    start_TR, end_TR = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  
    num_total, num_markers, num_regions = reaper.CountProjectMarkers(0)
  
    for i=0, num_total do
        retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        
        if isrgn == true then
            if start_TR == 0 and start_TR == end_TR then
            
                -- Find clips colors
                color_list = ReturnColorsInRegion(i, markrgnindexnumber, name, pos, rgnend)
                
                if #color_list > 1 then
                    -- Let the user decide witch color choose on the marker color
                    table.insert(region_to_color, color_list)
                else
                    -- Set the items color on the marker color
                    reaper.SetProjectMarker3(0, markrgnindexnumber, isrgn, pos, rgnend, name, color_list[1])
                end
            else
                
                if pos >= start_TR and rgnend <= end_TR then
                
                    -- Find clips colors
                    color_list = ReturnColorsInRegion(i, markrgnindexnumber, name, pos, rgnend)
                
                    if #color_list > 1 then
                        -- Let the user decide witch color choose on the marker color
                        table.insert(region_to_color, color_list)
                    else
                        -- Set the items color on the marker color
                        reaper.SetProjectMarker3(0, markrgnindexnumber, isrgn, pos, rgnend, name, color_list[1])
                    end
                end
            end
        end
    end
    
    if #region_to_color ~= 0 then
        ShowColorsOptions()
    end
end

-- SCRIPT EXECUTION --
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
Main()
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Color region based on clip color in region", 0)