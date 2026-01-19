-- @description Open tags Editor
-- @author david
-- @version 1.2
-- @provides
--    [nomain] Utilities/*.lua
-- @about Open tags editor

-- Global Variables
ScriptVersion = "v1.0"
ScriptName = 'Tags Manager'
Settings = {
}

-- Load Utilities
dofile(reaper.GetResourcePath() ..
       '/Scripts/ReaTeam Extensions/API/imgui.lua')
  ('0.9.0.2')
package.path = package.path..';'..debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;"
Storage = require('Utilities/TMU_Storage')
Gui = require('Utilities/TMU_GUI')
Utils = require('Utilities/TMU_Utils')

Gui.Init()

reaper.defer(Gui.Loop)