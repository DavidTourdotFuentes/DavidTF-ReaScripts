--@description Select track below the selected track
--@author DavidTF
--@version 1.0
--@about
--  Inital commit

if reaper.CountSelectedTracks(0) > 0 then
    sel_track = reaper.GetSelectedTrack(0, 0)
    sel_track_id = reaper.GetMediaTrackInfo_Value(sel_track, 'IP_TRACKNUMBER')
    
    if sel_track_id < reaper.CountTracks() then
        reaper.SetTrackSelected(sel_track, false)
        new_sel_track = reaper.GetTrack(0, sel_track_id)
        reaper.SetTrackSelected(new_sel_track, true)
    end
end
