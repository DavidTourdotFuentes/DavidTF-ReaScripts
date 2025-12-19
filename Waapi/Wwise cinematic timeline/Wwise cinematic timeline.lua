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
Gui = require('Utilities/GUI')
Sys_gui = require("Utilities/System_GUI")
Sys_utils = require("Utilities/System_Utilities")
Sys_waapi = require("Utilities/System_Waapi")
Sys_RTPCtracks = require("Utilities/System_RTPCTracks")
App_state = "Starting"


--local connexion = sys_waapi.Connect()
reaper.defer(Sys_waapi.Connect)

reaper.defer(Gui.Loop)
reaper.atexit(Sys_gui.SetButtonState)

