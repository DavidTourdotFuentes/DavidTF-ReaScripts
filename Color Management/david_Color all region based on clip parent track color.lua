--@description Color all region based on clip parent track color
--@author DavidTF
--@version 1.1
--@changelog
--    Remove time selection impact
--@about
--    Color all regions based on clip parent track color

local region_to_color = {}

function ReturnColorsInRegion(marker_id, region_id, name, start_pos, end_pos)

    local color_list = {}

    for i = 1, reaper.CountMediaItems(0) do
        local current_item = reaper.GetMediaItem(0, i - 1)
        local item_start = reaper.GetMediaItemInfo_Value(current_item, "D_POSITION") + 0.01
        local item_end = item_start + reaper.GetMediaItemInfo_Value(current_item, "D_LENGTH") - 0.02

        if item_start >= start_pos and item_end <= end_pos then

            local take = reaper.GetActiveTake(current_item)
            local source = reaper.GetMediaItemTake_Source(take)

            reaper.ShowConsoleMsg("\n"..typebuf)

            local item_track = reaper.GetMediaItemTrack(current_item)
            local parent_track = reaper.GetParentTrack(item_track)
            local track_color

            if parent_track then
                track_color = reaper.GetTrackColor(parent_track)
                _, name = reaper.GetTrackName(parent_track)
            else
                track_color = reaper.GetTrackColor(item_track)
                _, name = reaper.GetTrackName(item_track)
            end
            -- Search to dont all color to list if color is already in the list
            local found = 0
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
    
    table.insert(color_list, 1, marker_id)
    table.insert(color_list, 2, region_id)
    table.insert(color_list, 3, name)
    
    return color_list
end

function Main()

    local num_total, _, _ = reaper.CountProjectMarkers(0)

    for i=0, num_total do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)

        if isrgn == true then

            -- Find clips colors
            local color_list = ReturnColorsInRegion(i, markrgnindexnumber, name, pos, rgnend)
            if #color_list > 3 then
                local _, curr_isrgn, curr_pos, curr_rgnend, curr_name, curr_markrgnindexnumber = reaper.EnumProjectMarkers(color_list[1])
                reaper.SetProjectMarker3(0, curr_markrgnindexnumber, curr_isrgn, curr_pos, curr_rgnend, curr_name, color_list[4])

                -- Let the user decide witch color choose on the marker color
                table.insert(region_to_color, color_list)
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
reaper.Undo_EndBlock("Color all regions based on clip parent track color", 0)
