-- @description Set tag 5 for region in time selection
-- @author david
-- @version 1.2
-- @about Set tag 5 for region in time selection

package.path = package.path..';'..debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;"

Storage = require('Utilities/TMU_Storage')
Utils = require('Utilities/TMU_Utils')

local tag = Storage.GetTagByID(5)

local regions_in_selection = {}

regions_in_selection = Utils.GetRegionInTimeSelection()

if #regions_in_selection ~= 0 then
    for _, r in ipairs(regions_in_selection) do
        reaper.SetProjExtState(0, Storage.section, r.guid, tag.tag)
    end

    Utils.UpdateRegionsColor(tag)
end