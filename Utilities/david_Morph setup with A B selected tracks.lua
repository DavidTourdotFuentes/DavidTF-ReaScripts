--@description Morph setup with A B selected tracks
--@author DavidTF
--@version 1.0
--@changelog
--    First commit
--@about
--    Create morph track, add Morph VST and route A track to 1/2 and B track to 3/4 input of Morph Track

reaper.Undo_BeginBlock()

-- CONFIG
local VST_NAME = "MORPH 3 PRO (Zynaptiq)"

-- Vérifie que le VST existe
local vst_index = reaper.TrackFX_AddByName(reaper.GetMasterTrack(0), VST_NAME, false, 0)

-- Retire le test FX du master
reaper.TrackFX_Delete(reaper.GetMasterTrack(0), vst_index)

-- Vérifie la sélection
local sel_count = reaper.CountSelectedTracks(0)
if sel_count ~= 2 then
    reaper.ShowMessageBox("Please select exactly 2 tracks.", "Error", 0)
    return
end

local track1 = reaper.GetSelectedTrack(0,0)
local track2 = reaper.GetSelectedTrack(0,1)

-- Position
local idx = reaper.GetMediaTrackInfo_Value(track1, "IP_TRACKNUMBER") - 1

-- Crée Morph Track
reaper.InsertTrackAtIndex(idx, true)
local morph = reaper.GetTrack(0, idx)

reaper.GetSetMediaTrackInfo_String(morph, "P_NAME", "Morph Track", true)

-- 4 channels
reaper.SetMediaTrackInfo_Value(morph, "I_NCHAN", 4)

-- Déplace les tracks sous le folder
reaper.ReorderSelectedTracks(idx+1, 0)

-- Folder start
reaper.SetMediaTrackInfo_Value(morph, "I_FOLDERDEPTH", 1)

-- Folder end
reaper.SetMediaTrackInfo_Value(track2, "I_FOLDERDEPTH", -1)

-- Désactive master send
reaper.SetMediaTrackInfo_Value(track1, "B_MAINSEND", 0)
reaper.SetMediaTrackInfo_Value(track2, "B_MAINSEND", 0)

-- Send track1 -> Morph 1/2
local send1 = reaper.CreateTrackSend(track1, morph)
reaper.SetTrackSendInfo_Value(track1, 0, send1, "I_SRCCHAN", 0)
reaper.SetTrackSendInfo_Value(track1, 0, send1, "I_DSTCHAN", 0)

-- Send track2 -> Morph 3/4
local send2 = reaper.CreateTrackSend(track2, morph)
reaper.SetTrackSendInfo_Value(track2, 0, send2, "I_SRCCHAN", 0)
reaper.SetTrackSendInfo_Value(track2, 0, send2, "I_DSTCHAN", 2)

-- Ajoute le VST Morph
reaper.TrackFX_AddByName(morph, VST_NAME, false, -1)

reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()

reaper.Undo_EndBlock("Create Morph Track with Morph VST", -1)
