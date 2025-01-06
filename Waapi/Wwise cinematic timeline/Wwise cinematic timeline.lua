-- @noindex

-- @description Wwise cinematic timeline
-- @author david
-- @version 0.0.1
-- @provides
--    [nomain] Utilities/*.lua
-- @changelog WIP: Fix crash if no tracks in project.
-- @about GUI to manage wwise event and record sequenced wwise events

-- Global Variables
ScriptVersion = "v1.0"
ScriptName = 'Wwise cinematic timeline'
Settings = {
}
------
-- Load Utilities
dofile(reaper.GetResourcePath() ..
       '/Scripts/ReaTeam Extensions/API/imgui.lua')
  ('0.9.0.2')
package.path = package.path..';'..debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;"
gui = require('Utilities/GUI')
sys_gui = require("Utilities/System_GUI")
sys_utils = require("Utilities/System_Utilities")
sys_waapi = require("Utilities/System_Waapi")

--local connexion = sys_waapi.Connect()
reaper.defer(sys_waapi.Connect)

reaper.defer(gui.Loop)
reaper.atexit(sys_gui.SetButtonState)
