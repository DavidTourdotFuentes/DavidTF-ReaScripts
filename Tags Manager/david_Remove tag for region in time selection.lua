-- @description Remove tag for region in time selection
-- @author david
-- @version 1.0
-- @provides
--    [nomain] Utilities/*.lua
-- @about Remove tag for region in time selection

package.path = package.path..';'..debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;"

Storage = require('Utilities/Storage')
Utils = require('Utilities/Utils')

local tag = Storage.GetTagByID(1)

local regions_in_selection = {}

regions_in_selection = Utils.GetRegionInTimeSelection()

if #regions_in_selection ~= 0 then
    for _, r in ipairs(regions_in_selection) do

        --local retval, tag = reaper.GetProjExtState(0, Storage.section, r.guid)
        local retval, key, val = reaper.EnumProjExtState(0, Storage.section, r.index)

        reaper.ShowConsoleMsg("Key : " .. key .. "\n")
        reaper.ShowConsoleMsg("Val : " .. val .. "\n")

        --if (tag == "") or  (tag == nil) then
        --    reaper.SetProjExtState(0, Storage.section, r.guid, "")
        --    reaper.SetProjectMarker3(0, r.index, true, r.start_pos, r.end_pos, r.name, reaper.ColorToNative(80, 133, 133) | 0x1000000)
        --    reaper.ShowConsoleMsg("Région : " .. r.name .. " - " .. tag)
        --else
        --    reaper.ShowConsoleMsg("Région déjà sans tag")
        --end

    end
end
