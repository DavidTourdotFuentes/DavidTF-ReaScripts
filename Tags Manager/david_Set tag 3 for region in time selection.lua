-- @description Set tag 3 for region in time selection
-- @author david
-- @version 1.0
-- @provides
--    [nomain] Utilities/*.lua
-- @about Set tag 3 for region in time selection

package.path = package.path..';'..debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;"

Storage = require('Utilities/Storage')
Utils = require('Utilities/Utils')

local tag = Storage.GetTagByID(3)

local regions_in_selection = {}

regions_in_selection = Utils.GetRegionInTimeSelection()

if #regions_in_selection ~= 0 then
    for _, r in ipairs(regions_in_selection) do
        reaper.SetProjExtState(0, Storage.section, r.guid, tag.tag)
    end

    Utils.UpdateRegions(tag)
end