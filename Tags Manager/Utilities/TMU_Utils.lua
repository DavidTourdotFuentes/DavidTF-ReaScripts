--@noindex
--@description Utils
--@author david
--@about All Utilities

local Utils = {}

package.path = package.path..';'..debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;"

Storage = require('Utilities/TMU_Storage')

function Utils.UpdateTagColor(index, tagToChange)
    reaper.GetSetProjectInfo(0, "RULER_LANE_COLOR:"..(index - 1), 0x1000000 | reaper.ImGui_ColorConvertNative(tagToChange.color), true)
end

function Utils.UpdateTagVisibility(index, visible)
    if visible then
        reaper.GetSetProjectInfo(0, "RULER_LANE_HIDDEN:"..(index - 1), 0, true)
    else
        reaper.GetSetProjectInfo(0, "RULER_LANE_HIDDEN:"..(index - 1), 1, true)
    end
end

function Utils.UpdateTagName(index, new_name)
    reaper.GetSetProjectInfo_String(0, "RULER_LANE_NAME:"..(index - 1), new_name, true)
end

return Utils
