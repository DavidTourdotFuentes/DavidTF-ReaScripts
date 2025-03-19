--@description Renumber region IDs
--@author DavidTF
--@version 1.0
--@changelog
--    Initial release
--@about
--    Renumber region ID keeping RRM referencies

function TableCopy(table) --returns a copy of a table, enables passing by value behavior
    local new_table = {}
    for i, k in pairs(table) do
        new_table[i] = k
    end
    return new_table
end

function GetRrTracksFromRegion(index)
    local tracks = {}

    local t = 0
    while reaper.EnumRegionRenderMatrix(0, index, t) do
        local track_guid = reaper.GetTrackGUID(reaper.EnumRegionRenderMatrix(0, index, t))

        --makes sure master is recallable after session is closed and reopened
        if reaper.GetTrackGUID(reaper.GetMasterTrack(0)) == track_guid then
            track_guid = "{master}"
        end

        table.insert(tracks, track_guid)

        t = t + 1
    end

    return tracks
end

function GetRegions() --returns a table of regions in order to get real region indexes
    local marker_count = reaper.CountProjectMarkers(0)
    local region_table = {}
    for i = 0, marker_count do
        local _, is_region, pos, rgnend, name, index, color = reaper.EnumProjectMarkers3(0, i)

        if is_region then
            -- Get Tracks assigned in RRM
            table.insert(region_table, {index = index, start = pos, end_pos = rgnend, name = name, color = color, tracks = GetRrTracksFromRegion(index)})
        end
    end
    return region_table
end


function CreateAllRegions(region_table)
    for i, region in ipairs(region_table) do
        local region_id = reaper.AddProjectMarker2(0, true, region.start, region.end_pos, region.name, -1, region.color)

        for j, track in ipairs(region.tracks) do
            local curr_track = track == "{master}" and reaper.GetMasterTrack(0) or reaper.BR_GetMediaTrackByGUID(0, track)
            if curr_track then reaper.SetRegionRenderMatrix(0, region_id, curr_track, 1) end
        end
    end
end


function RemoveAllRegions(region_table)
    for i, region in ipairs(region_table) do
        reaper.DeleteProjectMarker(0, region.index, true)
    end
end

-- MAIN EXECUTION
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local regions = GetRegions()

RemoveAllRegions(regions)

CreateAllRegions(regions)

reaper.Undo_EndBlock("Renumber region IDs", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
