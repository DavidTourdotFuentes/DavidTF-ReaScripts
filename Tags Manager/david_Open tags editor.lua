local section = "david_TagsManager"

-- @description Open tags Editor
-- @author david
-- @version 1.0
-- @provides
--    [nomain] Utilities/*.lua
-- @about GUI to manage Tags

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
Storage = require('Utilities/Storage')
Gui = require('Utilities/GUI')
Utils = require('Utilities/Utils')

Gui.Init()

reaper.defer(Gui.Loop)