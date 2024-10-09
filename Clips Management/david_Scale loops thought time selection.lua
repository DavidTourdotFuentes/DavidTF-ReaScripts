-- @noindex

reaper.ClearConsole()

function GetItemsMinMax(_first_item, _second_item)
    local items_start = reaper.GetMediaItemInfo_Value(_first_item, "D_POSITION")
    local items_end = reaper.GetMediaItemInfo_Value(_second_item, "D_POSITION") + reaper.GetMediaItemInfo_Value(_second_item, "D_LENGTH")
     
    return items_start, items_end
end

local function ScaleLoopItems(_sel_start, _sel_end, _first_item, _second_item)

    local items_start, items_end = GetItemsMinMax(_first_item, _second_item)
    local loop_length = items_end - items_start
    local second_start = reaper.GetMediaItemInfo_Value(_second_item, "D_POSITION") - items_start
    local first_end = reaper.GetMediaItemInfo_Value(_first_item, "D_POSITION") + reaper.GetMediaItemInfo_Value(_first_item, "D_LENGTH") - items_start
    local crossfade_start = second_start / loop_length
    local crossfade_end = first_end / loop_length
    reaper.ShowConsoleMsg("\nPERCENT : "..crossfade_start.." / "..crossfade_end)
    local sel_length = _sel_end - _sel_start


    reaper.SetMediaItemSelected(_first_item, true)
    reaper.SetMediaItemSelected(_second_item, false)

    reaper.ApplyNudge(0, 1, 2, 1, _sel_start, false, 0)
    

    reaper.SetMediaItemSelected(_first_item, false)
    reaper.SetMediaItemSelected(_second_item, true)

    local item_pos = reaper.GetMediaItemInfo_Value(_second_item, "D_POSITION")
    local item_length = reaper.GetMediaItemInfo_Value(_second_item, "D_LENGTH")

    local transformation_value = _sel_end - (item_pos + item_length)
    
    reaper.SetMediaItemInfo_Value(_second_item, "D_POSITION", item_pos + transformation_value)
    reaper.ApplyNudge(0, 1, 1, 1, item_pos, false, 0)

    reaper.SetMediaItemSelected(_first_item, true)
    reaper.SetMediaItemSelected(_second_item, true)
end

local function locate(table, value)
    for i = 1, #table do
        if table[i] == value then return true end
    end
    return false
end

function Main()

    local items_count = reaper.CountSelectedMediaItems(0)
    reaper.ShowConsoleMsg(items_count)

    local sel_start, sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)

    if items_count %2 == 0 then

        local tracks = {}

        for i = 0, items_count - 1 do
            if i % 2 == 0 then
                local curr_track = reaper.GetMediaItem_Track(reaper.GetSelectedMediaItem(0, i))
                
                if not locate(tracks, curr_track) then

                    local first_item = reaper.GetSelectedMediaItem(0, i)
                    local second_item = reaper.GetSelectedMediaItem(0, i + 1)

                    ScaleLoopItems(sel_start, sel_end, first_item, second_item)

                    table.insert(tracks, curr_track)
                end
            end
        end
    end

end

function Test()
    --LEFT EDGE
    --reaper.ApplyNudge(0, 1, 2, 1, 5, false, 0)
    
    -- Position start = old_start + différence
    -- RIGHT TRIM
    reaper.ApplyNudge(0, 1, 1, 1, 5, false, 0)
    
end

Main()

--Test()

reaper.UpdateArrange()



