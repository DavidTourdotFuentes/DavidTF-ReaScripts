--@description Select track below the selected track
--@author DavidTF
--@version 1.1
--@changelog Bugfix: Clear selection before selecting new track
--@about Select track below the selected track

if reaper.CountSelectedTracks(0) > 0 then
    local sel_track = reaper.GetSelectedTrack(0, 0)
    local sel_track_id = reaper.GetMediaTrackInfo_Value(sel_track, 'IP_TRACKNUMBER')
    
    reaper.Main_OnCommand(40297, 0) -- Unselect (clear) selection of tracks
    
    if sel_track_id < reaper.CountTracks() then
        local new_sel_track = reaper.GetTrack(0, sel_track_id)
        reaper.SetTrackSelected(new_sel_track, true)
    end
end
