--@description Set "Automatic record-arm when track selected" on all track with instrument in fx list
--@author DavidTF
--@version 1.1
--@about
--  Removed debug

tracks_count = reaper.CountTracks(0)
for i=0, tracks_count - 1 do
    current_track = reaper.GetTrack(0, i)
    instrument_index = reaper.TrackFX_GetInstrument(current_track)
    
    if instrument_index ~= -1 then
        _, track_name = reaper.GetTrackName(current_track)
        result = reaper.SetMediaTrackInfo_Value(current_track, "B_AUTO_RECARM", 1)
    end
end
