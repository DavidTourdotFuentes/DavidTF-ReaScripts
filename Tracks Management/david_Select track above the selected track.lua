--@description Select track above the selected track
--@author DavidTF
--@version 1.0
--@about
--  Inital commit

if reaper.CountSelectedTracks(0) > 0 then
    sel_track = reaper.GetSelectedTrack(0, 0)
    sel_track_id = reaper.GetMediaTrackInfo_Value(sel_track, 'IP_TRACKNUMBER')
    
    if sel_track_id > 1 then
        reaper.SetTrackSelected(sel_track, false)
        new_sel_track = reaper.GetTrack(0, sel_track_id - 2)
        reaper.SetTrackSelected(new_sel_track, true)
    end
end
