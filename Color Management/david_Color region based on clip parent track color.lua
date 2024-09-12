--@description Color region based on clip parent track color
--@author DavidTF
--@version 1.0
--@changelog
--    Empty
--@about
--    Color region based on clip parent track color

region_to_color = {}
colored_regions = {}

function ReturnColorsInRegion(marker_id, region_id, name, start_pos, end_pos)

    local color_list = {}

    for i = 1, reaper.CountMediaItems(0) do
        current_item = reaper.GetMediaItem(0, i - 1)
        item_start = reaper.GetMediaItemInfo_Value(current_item, "D_POSITION") + 0.01
        item_end = item_start + reaper.GetMediaItemInfo_Value(current_item, "D_LENGTH") - 0.02
        
        if item_start >= start_pos and item_end <= end_pos then
        
            take = reaper.GetActiveTake(current_item)
            source = reaper.GetMediaItemTake_Source(take)
            typebuf = reaper.GetMediaSourceType(source)

            
            if typebuf == "WAVE" then
                item_track = reaper.GetMediaItemTrack(current_item)
                parent_track = reaper.GetParentTrack(item_track)
                if parent_track then
                    track_color = reaper.GetTrackColor(parent_track)
                    _, name = reaper.GetTrackName(parent_track)
                else
                    track_color = reaper.GetTrackColor(item_track)
                    _, name = reaper.GetTrackName(item_track)
                end
                
                --reaper.ShowConsoleMsg("\n"..name)
                
                -- Search to dont all color to list if color is already in the list
                found = 0
                for i=1, #color_list do
                    if color_list[i] == track_color then
                        found = found + 1
                    end
                end
                if track_color == 0 then
                    track_color = 4285690454
                end
                if found == 0 and track_color ~= nil then
                    table.insert(color_list, track_color)
                end
            end
        end
    end
    
    table.insert(color_list, 1, marker_id)
    table.insert(color_list, 2, region_id)
    table.insert(color_list, 3, name)
    
    return color_list
end

function Main()
  
    start_TR, end_TR = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  
    num_total, num_markers, num_regions = reaper.CountProjectMarkers(0)
  
    for i=0, num_total do
        retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        
        if isrgn == true then
        
            -- If no timeline selection set, process all the regions
            if start_TR == 0 and start_TR == end_TR then
            
                -- Find clips colors
                color_list = ReturnColorsInRegion(i, markrgnindexnumber, name, pos, rgnend)
                if #color_list > 3 then
                    --reaper.ShowConsoleMsg("\n"..color_list[1].." / "..color_list[2].." / "..color_list[3].." / "..color_list[4])
                    
                    curr_retval, curr_isrgn, curr_pos, curr_rgnend, curr_name, curr_markrgnindexnumber = reaper.EnumProjectMarkers(color_list[1])
                    reaper.SetProjectMarker3(0, curr_markrgnindexnumber, curr_isrgn, curr_pos, curr_rgnend, curr_name, color_list[4])
                    
                    -- Let the user decide witch color choose on the marker color
                    table.insert(region_to_color, color_list)
                end
            -- If no timeline selection set, process all the regions
            elseif pos >= start_TR and rgnend <= end_TR then
            
                -- Find clips colors
                color_list = ReturnColorsInRegion(i, markrgnindexnumber, name, pos, rgnend)
            
                if #color_list > 3 then
                    --reaper.ShowConsoleMsg("\n"..color_list[1].." / "..color_list[2].." / "..color_list[3].." / "..color_list[4])
                
                    -- Let the user decide witch color choose on the marker color
                    table.insert(region_to_color, color_list)
                end
            end
        end
    end
end

reaper.ClearConsole()
-- SCRIPT EXECUTION --
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
Main()
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Color region based on clip color in region", 0)
