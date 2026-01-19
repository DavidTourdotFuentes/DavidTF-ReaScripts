-- @description Remove tag for region in time selection
-- @author david
-- @version 1.2
-- @about Remove tag for region in time selection

package.path = package.path..';'..debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;"

Storage = require('Utilities/TMU_Storage')
Utils = require('Utilities/TMU_Utils')

local tag = Storage.GetTagByID(1)

Utils.ClearInvalidData()

local regions_in_selection = {}

regions_in_selection = Utils.GetRegionInTimeSelection()

if #regions_in_selection ~= 0 then
    for _, r in ipairs(regions_in_selection) do

        reaper.SetProjExtState(0, Storage.section, r.guid, "")

        local _, num_markers, num_regions = reaper.CountProjectMarkers(0)

        for i = 0, num_markers + num_regions - 1 do
            local _, isrgn, pos, rgnend, name, idx = reaper.EnumProjectMarkers(i)

            local _, guid = reaper.GetSetProjectInfo_String(0, "MARKER_GUID:" .. idx, "", false)

            if isrgn and (r.guid == guid) then
                reaper.SetProjectMarkerByIndex(0, i, true, pos, rgnend, idx, name, reaper.ColorToNative(80, 133, 133) | 0x1000000)
            end
        end
    end
end
