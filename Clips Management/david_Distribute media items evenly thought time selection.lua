-- @noindex

reaper.ClearConsole()

duplications = 1

selectedItems = {}
items = {}

function GetItemsMinMax()
    first_item = reaper.GetSelectedMediaItem(0, 0)
    items_start = reaper.GetMediaItemInfo_Value(first_item, "D_POSITION")
    
    last_item = reaper.GetSelectedMediaItem(0, reaper.CountSelectedMediaItems(0) - 1)
    items_end = reaper.GetMediaItemInfo_Value(last_item, "D_POSITION") + reaper.GetMediaItemInfo_Value(last_item, "D_LENGTH")
     
    return items_start, items_end
end

function GetSelectedItemsDatas()
    local total_lenght = 0
    
    for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local take = reaper.GetActiveTake(item)
        local start_offset = reaper.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS')
        local source = reaper.GetMediaItemTake_Source(take)
        local source_length, _ = reaper.GetMediaSourceLength(source)
        local end_offset = source_length - start_offset

        table.insert(selectedItems, {item = item, item_start = item_start, item_end = item_end, start_offset = start_offset, source_length = source_length})
    end
end

function ApplyScaling(_items_start, _sel_start, _items_end, _sel_end, expand_factor)

    for i = 1, #selectedItems do
        local take = reaper.GetActiveTake(selectedItems[i].item)
        local item_length = selectedItems[i].item_end - selectedItems[i].item_start
        local new_start = (selectedItems[i].item_start - _items_start) * expand_factor / duplications + _sel_start
        local new_end = _sel_end - _sel_start
        local new_length = item_length * expand_factor / duplications
        
        local source_start_offset_global = selectedItems[i].item_start - selectedItems[i].start_offset
        local new_source_start_offset_global = (source_start_offset_global - _items_start) * expand_factor / duplications + _sel_start

        
        if i < #selectedItems then
            reaper.ShowConsoleMsg("\nstart")
            reaper.SetMediaItemInfo_Value(selectedItems[i].item, "D_POSITION", new_start)
            reaper.SetMediaItemInfo_Value(selectedItems[i].item, "D_LENGTH", new_length)
        else
            reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", selectedItems[i].start_offset + new_source_start_offset_global)
        end
        
        table.insert(items, {item = selectedItems[i], item_start = new_start, item_end = new_end})
    end
    
    if duplications > 1 then
        reaper.ApplyNudge(0, 0, 5, 1, (_sel_end - _sel_start) / duplications, false, duplications - 1)
    else
        reaper.ApplyNudge(0, 0, 5, 1, (_sel_end - _sel_start) / duplications, false)
    end
    
end

function Main()
    
    sel_start, sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    
    total_items_lenght = 0
    
    if reaper.CountSelectedMediaItems(0) > 0 then
        
        items_start, items_end = GetItemsMinMax()
        
        GetSelectedItemsDatas()
        
        sel_size = sel_end - sel_start
        items_size = items_end - items_start
        reaper.ShowConsoleMsg("\nSelection Size : "..sel_size)
        reaper.ShowConsoleMsg("\nItems Size : "..items_size)
         
        expand_factor = sel_size / items_size
        
        reaper.ShowConsoleMsg("\nExpansion Factor : "..expand_factor)
        
        ApplyScaling(items_start, sel_start, items_end, sel_end, expand_factor)
    end

end

Main()

--reaper.UpdateArrange()



