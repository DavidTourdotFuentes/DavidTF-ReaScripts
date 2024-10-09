--@description Rename first selected track
--@author DavidTF
--@version 1.0
--@changelog First commit.
--@about Rename first selected track


function Round(n)
    return n % 1 >= 0.5 and (n+1 - n%1) or n//1
david_Rename first selected track end

function Main()
    local track = reaper.GetSelectedTrack(0, 0)
    local _, max_x, _, _, _ = reaper.JS_Window_GetClientRect(reaper.JS_Window_Find( "trackview", true )) -- Find track width position
    
    local _, _, _, _, start_h = reaper.JS_Window_GetClientRect(reaper.JS_Window_Find("Main toolbar", false)) -- Find min and max height position

    local min_h = reaper.GetMediaTrackInfo_Value(track, "I_TCPY") + start_h
    local max_h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH") + min_h

    local final_x = Round(max_x / 2)
    local final_y = Round((min_h + max_h) / 2)
    
    reaper.JS_Mouse_SetPosition(final_x, final_y)
    
end

local base_x, base_y = reaper.GetMousePosition()

Main()

reaper.Main_OnCommand(reaper.NamedCommandLookup("_26dcb613f414d246b29dd2bd981de664"), 0)
