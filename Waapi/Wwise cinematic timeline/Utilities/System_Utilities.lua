-- @noindex

local Sys_utils = {}

----- SETTINGS -----
local result = 0

local events_list = {}

Sys_utils.recordersSlots = {}
local plugin_ID_table = {}
local silence_source_ID = 0

-- Preview Settings
local detect_precision = 0.02 --> Range of detection between marker (in seconds) default : 0.02 (20ms)
local marker_proximity_detector = 3 --> Precision of proximity factor (scale) default : 2 (2 x detectPrecision)
local debug_already_detected_marker = true --> Show console message when marker was detected multiple times
local reset_cache_time = 0.2 -->  Detection of same marker rate in seconds (looping on the marker or playing transport multiple times) default : 1 sec

local valid_color = {r = 144, g = 238, b = 144}
local invalid_color = {r = 255, g = 79, b = 79}

local item_table = {}
local rtpc_table = {}
local time_start = 0
Sys_utils.last_detection_pos = -1
Sys_utils.last_detection_time = 0
local is_playing = 0
local is_looping = 1
local preview_logs = {}
local parent_track = nil
local tracks_list = {}

local RTPC_changing_value_tick = 0
local RTPC_changing_max_value_tick = 30


-- EXTERNAL FUNCTIONS

function Sys_utils.Init()
    parent_track = Sys_utils.FindTrackByName("Wwise Timeline")

    if parent_track then
        RefreshEventsAndRTPCTables()
    else
        reaper.InsertTrackInProject(0, 0, 0)
        parent_track = reaper.GetTrack(0, 0)
        _, _ = reaper.GetSetMediaTrackInfo_String(parent_track, "P_NAME", "Wwise Timeline", true)
    end
end

function Sys_utils.Loop()
     -- Preview RTPC changes
     if RTPC_changing_value_tick >= 0 and RTPC_changing_value_tick < RTPC_changing_max_value_tick then
         RTPC_changing_value_tick = RTPC_changing_value_tick + 1
     else
        RTPC_changing_value_tick = 0

        local is_changed, track = Sys_utils.UpdatePreviewCurves(true)

        if track then
            Sys_RTPCtracks.GenerateInterpolatedCurve(track)
        end

     end
end

function Sys_utils.InitializePreview()

    time_start = reaper.time_precise()
    Sys_utils.lastDetectionPos = -1
    Sys_utils.lastDetectionTime = 0

    if parent_track then

        RefreshEventsAndRTPCTables()

        local output = {state = "INFO", desc = "Preview started : Events now play on reaper timeline"}
        return output
    else
        local output = {state = "ERROR", desc = "Track 'Wwise Timeline' not found."}
        return output
    end
end

function Sys_utils.PreviewLoop()

    local output = {}
    local is_playing = reaper.GetPlayState()

    if is_playing == 1 then

        local cur_pos = reaper.GetPlayPosition()

        for i, item in ipairs(item_table) do

            local item_pos, item_name, itemVol =  Sys_utils.GetItemInfo(item)

            if (cur_pos >= item_pos - detect_precision) and (cur_pos <= item_pos + detect_precision) then

                if (cur_pos < Sys_utils.lastDetectionPos - (detect_precision * marker_proximity_detector)) or (cur_pos > Sys_utils.lastDetectionPos + (detect_precision * marker_proximity_detector)) then
                    Sys_utils.lastDetectionPos = cur_pos
                    output = Sys_utils.OnEvent(item_name)

                    if output.state == "ERROR" then
                        reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", 23817199.0)
                    else
                        reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", 0.0)
                    end

                    reaper.UpdateArrange()

                    -- Reset du cache après un certain temps
                    Sys_utils.lastDetectionTime = reaper.time_precise()
                else
                    if debug_already_detected_marker then
                        output = {state = "WARNING", desc = "Event " .. item_name .. " already detected"}
                    end
                end
            end
        end

        for _, rtpc in ipairs(rtpc_table) do
            local _, track_name = reaper.GetTrackName(rtpc.track)

            for _, point in ipairs(rtpc.points) do
                if (cur_pos >= point.time - detect_precision) and (cur_pos <= point.time + detect_precision) then
                    if (cur_pos < Sys_utils.last_detection_pos - (detect_precision * marker_proximity_detector)) or (cur_pos > Sys_utils.last_detection_pos + (detect_precision * marker_proximity_detector)) then
                        Sys_utils.last_detection_pos = cur_pos
                        local min = reaper.TrackFX_GetParam(rtpc.track, 0, 0)
                        local max = reaper.TrackFX_GetParam(rtpc.track, 0, 1)
                        local value =  min + (max - min) * point.value
                        output = Sys_waapi.SetRTPC(track_name, value)

                        if output.state == "ERROR" then
                            reaper.SetTrackColor(rtpc.track, Sys_utils.ColorHexToReaper(invalid_color))
                        else
                            reaper.SetTrackColor(rtpc.track, Sys_utils.ColorHexToReaper(valid_color))
                        end

                        reaper.UpdateArrange()

                        -- Reset du cache après un certain temps
                        Sys_utils.last_detection_time = reaper.time_precise()
                    else
                        if debug_already_detected_marker then
                            output = {state = "WARNING", desc = "RTPC " .. track_name .. " already detected"}
                        end
                    end
                end
            end
        end

        if Sys_utils.last_detection_pos > -1 then
            if (reaper.time_precise() - Sys_utils.last_detection_time) > reset_cache_time then
                Sys_utils.last_detection_pos = -1
                Sys_utils.last_detection_time = 0
            end
        end
    end

    return output
end

function Sys_utils.OnEvent(item_name)
    local state, result = Sys_utils.DetectValueType(item_name)

    if state == "" then
        if item_name ~= "" then
            local output = Sys_waapi.PlayEvent(item_name)
            return output
        end
    end
    if state == "[PLAY]" then
        if result[2] then
            local output = Sys_waapi.PlayEvent(result[2])
            return output
        end
    end
    if state == "[STOPALL]" then
        local output = Sys_waapi.StopAll()
        return output
    end
    if state == "[RTPC]" then
        if result[2] and result[3] then
            local output = Sys_waapi.SetRTPC(result[2], result[3])
            return output
        end
    end
    if state == "[STATE]" then
        if result[2] and result[3] then
            local output = Sys_waapi.SetState(result[2], result[3])
            return output
        end
    end
    if state == "[SWITCH]" then
        if result[2] and result[3] then
            local output = Sys_waapi.SetSwitch(result[2], result[3])
            return output
        end
    end

    local output = {state = "WARNING", desc = "Invalid comand in node"}
    return output
end

function Sys_utils.CreateItemAtCursor(length, text)
    local cursor_pos = reaper.GetCursorPosition()
    reaper.Undo_BeginBlock()
    CreateTextItem(parent_track, cursor_pos, 1, "Event name")
    reaper.Undo_EndBlock("Create Wwise event item", 0)
end

function Sys_utils.GetFXValue()
    local track = reaper.GetSelectedTrack(0, 0)
    local min, _, _ = reaper.TrackFX_GetParam(track, 0, 0)
    local max, _, _ = reaper.TrackFX_GetParam(track, 0, 1)
    local value, _, _ = reaper.TrackFX_GetParam(track, 0, 2)
end

--- Compare if automation curves for Interpolation parameter of Wwise Parameter plugin changed
---@param fix_diff boolean Set fix_diff to true to update internal parameter values based on what changed
---@return boolean is_different, {} track Return true if one curve changed and the track who changed (nil if nothing changed)
function Sys_utils.UpdatePreviewCurves(fix_diff)

    local is_different = false
    local modified_track = nil

    for i, t in ipairs(tracks_list) do

        -- filter les tracks qui ont le plugin RTPC
        local _, t_name = reaper.GetTrackName(t)

        for _, rtpc in ipairs(rtpc_table) do

            if rtpc.track == t then
                local points = GetPointsFromTrack(t)

                if Tablelength(rtpc.points) == Tablelength(points) then
                    for i, _ in ipairs(rtpc.points) do
                        if (rtpc.points[i].time ~= points[i].time) or (rtpc.points[i].value ~= points[i].value) then

                            is_different = true

                            modified_track = t

                            if fix_diff then
                                rtpc.points[i].time = points[i].time
                                rtpc.points[i].value = points[i].value
                            end
                        end
                    end
                else
                    for i, _ in ipairs(points) do
                        is_different = true

                        modified_track = t

                        if fix_diff then
                            local point = { points[i].time, points[i].value }
                            table.insert(rtpc.points, point)
                        end
                    end
                end
            end
        end
    end

    return is_different, modified_track
end

function Sys_utils.FindTrackByName(_name)
    local num_tracks = reaper.CountTracks(0)
    for i = 0, num_tracks - 1 do
        local track = reaper.GetTrack(0, i)
        local _, track_name = reaper.GetTrackName(track)
        if track_name == _name then
            return track
        end
    end
    return nil
end

function Sys_utils.AddTrackAndChildrenToList()
    local tracks_list = {}

    table.insert(tracks_list, parent_track)
    local track_ID = reaper.GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
    local depth = reaper.GetTrackDepth(parent_track)
    local num_tracks = reaper.CountTracks(0)
    for i = track_ID + 1, num_tracks - 1 do
        local child_track = reaper.GetTrack(0, i)
        if reaper.GetTrackDepth(child_track) <= depth then
            break
        end
        table.insert(tracks_list, child_track)
    end

    return tracks_list
end

function Sys_utils.GetAppDataPath()
    local app_data_path = os.getenv("APPDATA")
    return app_data_path
end

function Sys_utils.GetItemInfo(item)
    local _, name = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local vol = reaper.GetMediaItemInfo_Value(item, "D_VOL")
    return pos, name, vol
end

-- Fonction pour vérifier l'existence d'un fichier
function Sys_utils.FileExists(file_path)
    local file = io.open(file_path, "r")
    if file then
        file:close()
        return true
    else
        return false
    end
end

function Sys_utils.DetectValueType(_text)
    local result = {}
        for word in string.gmatch(_text, "%S+") do
            table.insert(result, word)
        end

    if #result == 0 then
            return "", {}
        end

    local state = ""

    if result[1] == "[PLAY]" then
        state = result[1]
    end
    if result[1] == "[RTPC]" then
        state = result[1]
    end
    if result[1] == "[STATE]" then
        state = result[1]
    end
    if result[1] == "[SWITCH]" then
        state = result[1]
    end
    if result[1] == "[STOPALL]" then
        state = result[1]
    end
    return state, result
end

--- Convert un Color RGB object on color double for reaper colors
---@param color {} Color Object {Color.r, Color.g, Color.b}
---@return number output_color Color in double
function Sys_utils.ColorHexToReaper(color)
    local output_color = color.r + (color.g << 8) + (color.b << 16)
    return output_color
end


-- INTERNAL FUNCTIONS

function RefreshEventsAndRTPCTables()

    item_table = {}
    rtpc_table = {}

    tracks_list = Sys_utils.AddTrackAndChildrenToList()

    for _, t in ipairs(tracks_list) do
        -- ITEMs
        local note_item_count = reaper.CountTrackMediaItems(t)
        for i=0, note_item_count - 1 do

            local item = reaper.GetTrackMediaItem(t, i )

            local take = reaper.GetTake(item, 0)
            if not take then
                table.insert(item_table, item)
            end
        end

        -- RTPCs
        local fx_ID = reaper.TrackFX_AddByName(t, "wwise param slider", false, 0)
        local points = {}

        local min = reaper.TrackFX_GetParam(t, 0, 0)
        local max = reaper.TrackFX_GetParam(t, 0, 1)

        if fx_ID ~= -1 then
            Sys_RTPCtracks.UpdatePluginValues(t)
            local track_FX_env = reaper.GetFXEnvelope(t, fx_ID, 2, false)
            local env_points_count = reaper.CountEnvelopePoints(track_FX_env)
            for i = 0, env_points_count - 1 do
                local _, time, value, _, _, _ = reaper.GetEnvelopePoint(track_FX_env, i)

                table.insert(points, {time = time, value = value})
                --reaper.ShowConsoleMsg("\n" ..t_name .. " : New point [" .. tostring(time) .. ", " .. tostring(value) .. "]")
            end

            table.insert(rtpc_table, {track = t, points = points})
        end
    end
end

function GetPointsFromTrack(track)
    local points = {}

    local fx_ID = reaper.TrackFX_AddByName(track, "wwise param slider", false, 0)

    if fx_ID then
        local track_FX_env = reaper.GetFXEnvelope(track, fx_ID, 2, false)
        local env_points_count = reaper.CountEnvelopePoints(track_FX_env)
        for i = 0, env_points_count - 1 do
            local _, time, value, _, _, _ = reaper.GetEnvelopePoint(track_FX_env, i)

            table.insert(points, {time = time, value = value})
        end
    end

    return points
end

function CreateTextItem(track, position, length, text)

    local item = reaper.AddMediaItemToTrack(track)

    reaper.SetMediaItemInfo_Value(item, "D_POSITION", position)
    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", length)

    if text ~= nil then
      reaper.ULT_SetMediaItemNote(item, text)
    end

    return item

 end

--- Return the size of a table
-- @param a (number) : Le premier nombre.
-- @param b (number) : Le second nombre.
-- @return (number) : La somme de a et b.
function Tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

return Sys_utils