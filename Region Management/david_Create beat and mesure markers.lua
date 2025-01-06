local _, bpi = reaper.GetProjectTimeSignature()

local sel_start, sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)

local _, sel_start_mesure, _, sel_start_beat, _ = reaper.TimeMap2_timeToBeats(0, sel_start)
local _, sel_end_mesure, _, sel_end_beat, _ = reaper.TimeMap2_timeToBeats(0, sel_end)

local idx = 0
for i = sel_start_beat, sel_end_beat do
    local time = reaper.TimeMap2_beatsToTime(0, i)
    reaper.AddProjectMarker2(0, false, time, 0, "Beat", idx, 0)
    idx = idx + 1
end

local idx = 0
for i = sel_start_mesure, sel_end_mesure do
    local time = reaper.TimeMap2_beatsToTime(0, i * bpi)
    reaper.AddProjectMarker2(0, false, time, 0, "Mesure", idx, 0)
    idx = idx + 1
end