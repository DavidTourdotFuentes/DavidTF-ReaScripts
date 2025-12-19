function Print(msg)
    reaper.ShowConsoleMsg("\n"..msg)
end

local sel_tracks_count = reaper.CountSelectedTracks(0)

 for i = 1, sel_tracks_count do
    local cur_track = reaper.GetSelectedTrack(0, i - 1)
    local retval, buf = reaper.GetTrackName(cur_track)

    Print(buf)
end