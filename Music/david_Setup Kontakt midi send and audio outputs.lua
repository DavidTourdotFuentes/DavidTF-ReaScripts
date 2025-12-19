--@description Setup Kontakt midi send and audio outputs
--@author DavidTF
--@version 1.0
--@changelog
--    First commit
--@about
--    First commit

-- Rechercher la première piste nommée "Kontakt"
local target_name = "Kontakt"
local kontakt_track = nil

function GetKontaktTrack(target_name)

    local found_track = nil

    local track_count = reaper.CountTracks(0)

    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(0, i)
        local _, name = reaper.GetTrackName(track)
    
        if name == target_name then
            found_track = track
            break
        end
    end

    return found_track
end

function ClearTrackSendsReceives(track)

    -- SUPPRIMER LES SENDS (category = 0)
    local sendCount = reaper.GetTrackNumSends(track, 0) -- 0 = sends
    for i = sendCount - 1, 0, -1 do
        reaper.RemoveTrackSend(track, 0, i)
    end

    -- SUPPRIMER LES RECEIVES (category = -1)
    local recvCount = reaper.GetTrackNumSends(track, -1) -- -1 = receives
    for i = recvCount - 1, 0, -1 do
        reaper.RemoveTrackSend(track, -1, i)
    end
end 

function AddSendsReceives(_kontakt_track, _track, i)

    local receive_id = reaper.CreateTrackSend(_track, _kontakt_track)

    reaper.ShowConsoleMsg("\nReceive ID [" .. tostring(receive_id).."]")

    -- Set no audio send
    local success = reaper.SetTrackSendInfo_Value(_kontakt_track, -1, i - 1, "I_SRCCHAN", -1)
    reaper.ShowConsoleMsg(" - S : " .. tostring(success))

    -- Set midi channel 1 - i = 1 + (i << 5)
    local success = reaper.SetTrackSendInfo_Value(_kontakt_track, -1, i - 1, "I_MIDIFLAGS", 1 + (i << 5))
    reaper.ShowConsoleMsg(" - M : " ..    tostring(success))


    local send_id = reaper.CreateTrackSend(_kontakt_track, _track)

    reaper.ShowConsoleMsg("\nSend ID [".. tostring(send_id).. "]")

    -- Set audio channel I_SRCCHAN = offset + (channel_count << 10)
    local success = reaper.SetTrackSendInfo_Value(_track, -1, 0, "I_SRCCHAN", (i - 1) * 2)
    reaper.ShowConsoleMsg(" - S : " .. tostring(success))

    -- Set no midi channel
    local success = reaper.SetTrackSendInfo_Value(_track, -1, 0, "I_MIDIFLAGS", -1)
    reaper.ShowConsoleMsg(" - M : " .. tostring(success))
end

kontakt_track = GetKontaktTrack(target_name)

if kontakt_track == nil then
    reaper.ShowConsoleMsg("Kontakt track 'Kontakt' not found")
    return
end

ClearTrackSendsReceives(kontakt_track)

local track_count = reaper.CountSelectedTracks(0)

local invalid_selection = false
for i = 0, track_count - 1 do
    local curr_track = reaper.GetSelectedTrack(0, i)
    if curr_track == kontakt_track then
        invalid_selection = true
        break
    end
end

if invalid_selection then
    reaper.ShowConsoleMsg("Kontakt track must not be part of the selected tracks")
    return
end

for i = 0, track_count - 1 do
    local curr_track = reaper.GetSelectedTrack(0, i)

    AddSendsReceives(kontakt_track, curr_track, i + 1)
end