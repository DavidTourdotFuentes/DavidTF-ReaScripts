-- @noindex

local Sys_RTPCtracks = {}


-- EXTERNAL FUNCTIONS

function Sys_RTPCtracks.AddRTPCTrack()
    -- Vérifie si une piste parent est sélectionnée
    if not parent_track then
        reaper.ShowMessageBox("Aucune piste Wwise Timeline trouvée.", "Erreur", 0)
        return
    end

    local retval, track_name = reaper.GetUserInputs("Link to Wwise RTPC", 1, "RTPC Name :", "")

    if not retval then
        return
    end

    -- Récupère l'index de la piste parent
    local parent_ID = reaper.GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1

    -- Insère une nouvelle piste juste après la piste parent
    reaper.InsertTrackAtIndex(parent_ID + 1, true)
    local child_track = reaper.GetTrack(0, parent_ID + 1)

    -- Définit la nouvelle piste enfant comme une continuation du dossier
    reaper.SetMediaTrackInfo_Value(child_track, "I_FOLDERDEPTH", 0)

    -- Naming de la track
    reaper.GetSetMediaTrackInfo_String(child_track, "P_NAME", track_name, true)

    -- Ajout du FX Slider
    reaper.TrackFX_AddByName(child_track, "slider.jsfx", false, 1)

    -- Récupération des donnés du RTPC
    local output, rtpc = Sys_waapi.GetRTPCInfo(track_name)

    -- Envoi des valeurs du RTPC Wwise dans le plugin
    if output.state == "INFO" then
        reaper.TrackFX_SetParam(child_track, 0, 0, rtpc.min)
        reaper.TrackFX_SetParam(child_track, 0, 1, rtpc.max)
        reaper.TrackFX_SetParam(child_track, 0, 2, (rtpc.value - rtpc.min) / (rtpc.max - rtpc.min))
    end

    -- Création de l'envelope d'automation de "value"
    local fx_envelope = reaper.GetFXEnvelope(child_track, 0, 2, true)
    local _, _, value, _, _, _ = reaper.GetEnvelopePoint(fx_envelope, 0)
    reaper.SetEnvelopePoint(fx_envelope, 0, 0, value, 1, 0, false, true)

    local point = {}
    table.insert(point, {time = 0, value = value})

    for _, v in pairs(rtpc_table) do
        if v.track == child_track then
            v.points = point
            break
        end
    end


    local BR_env = reaper.BR_EnvAlloc(fx_envelope, true)

    reaper.BR_EnvSetProperties(BR_env, true, true, true, false, 10, 1, false)
    reaper.BR_EnvFree(BR_env, true)

    Sys_gui.AddLog(output.desc)

    -- Met à jour l'affichage
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()
end

function Sys_RTPCtracks.UpdatePluginValues(track)

    -- Récupération des donnés du RTPC
    local _, track_name = reaper.GetTrackName(track)
    local output, rtpc = Sys_waapi.GetRTPCInfo(track_name)

    -- Envoi des valeurs du RTPC Wwise dans le plugin
    if output.state == "INFO" then
        reaper.TrackFX_SetParam(track, 0, 0, rtpc.min)
        reaper.TrackFX_SetParam(track, 0, 1, rtpc.max)
        reaper.TrackFX_SetParam(track, 0, 2, (rtpc.value - rtpc.min) / (rtpc.max - rtpc.min))
    end

    return output
end


-- INTERNAL FUNCTIONS

function GenerateInterpolatedCurve(track)

    local _, track_name = reaper.GetTrackName(track)
    local output, rtpc = Sys_waapi.GetRTPCInfo(track_name)

    local temp_prev_value = -1

    if output.state == "INFO" then
        local fx_env = reaper.GetFXEnvelope(track, 0, 2, false)

        if rtpc.ramping ~= 0 then
            local fx_id = reaper.TrackFX_GetByName(track, "wwise param slider", true)
            local fx_interpolated_env = reaper.GetFXEnvelope(track, fx_id, 3, true)
            reaper.DeleteEnvelopePointRange(fx_interpolated_env, 0, 100000)
            local points_count = reaper.CountEnvelopePoints(fx_env)
            for i = 0, points_count - 1 do
                local _, prev_time, prev_value, _, _, _ = reaper.GetEnvelopePoint(fx_env, i - 1)
                local _, current_time, current_value, _, _, _ = reaper.GetEnvelopePoint(fx_env, i)
                local _, next_time, next_value, _, _, _ = reaper.GetEnvelopePoint(fx_env, i + 1)

                local prev_scaled_value = 0
                if temp_prev_value ~=-1 then
                    prev_scaled_value = rtpc.min + (rtpc.max - rtpc.min) * temp_prev_value
                else
                    prev_scaled_value = rtpc.min + (rtpc.max - rtpc.min) * prev_value
                end
                local current_scaled_value = rtpc.min + (rtpc.max - rtpc.min) * current_value

                if rtpc.ramping == 1 then

                    local new_time, next_value, completed = SlewRateInterpolation(current_time, prev_scaled_value, next_time, current_scaled_value, rtpc.slew_rate_up, rtpc.slew_rate_down)

                    if completed then
                        reaper.InsertEnvelopePoint(fx_interpolated_env, current_time, prev_value, 0, 0, false, true)
                        temp_prev_value = -1
                    else
                        temp_prev_value = (next_value - rtpc.min) / (rtpc.max - rtpc.min)
                    end

                    reaper.InsertEnvelopePoint(fx_interpolated_env, new_time, (next_value - rtpc.min) / (rtpc.max - rtpc.min), 0, 0, false, false)
                end

                if rtpc.ramping == 2 then

                    local new_time, new_value, completed = FilteringOverTimeInterpolation(current_time, prev_scaled_value, next_time, current_scaled_value, rtpc.filter_time_up, rtpc.filter_time_down)

                    if completed then
                        reaper.InsertEnvelopePoint(fx_interpolated_env, current_time, prev_value, 3, 0, false, true)
                        temp_prev_value = -1
                    else
                        temp_prev_value = (new_value - rtpc.min) / (rtpc.max - rtpc.min)
                    end

                    reaper.InsertEnvelopePoint(fx_interpolated_env, new_time, (new_value - rtpc.min) / (rtpc.max - rtpc.min), 3, 0, false, false)
                end
            end

            local _, stringNeedBig = reaper.GetSetEnvelopeInfo_String(fx_interpolated_env, "VISIBLE", "1", false)
            reaper.ShowConsoleMsg("\n" .. tostring(_) .. " / " .. tostring(stringNeedBig))
            --[[if stringNeedBig == "0" then
                local _, _ = reaper.GetSetEnvelopeInfo_String(fx_interpolated_env, "SHOWLANE", "1", true)
                local _, _ = reaper.GetSetEnvelopeInfo_String(fx_interpolated_env, "VISIBLE ", "1", true)
                reaper.ShowConsoleMsg("\nNew Show: " .. tostring(stringNeedBig))
                reaper.TrackList_AdjustWindows(false)
            end
            ]]
        else
            local fx_id = reaper.TrackFX_GetByName(track, "wwise param slider", true)
            local fx_interpolated_env = reaper.GetFXEnvelope(track, fx_id, 3, false)
            local _, stringNeedBig = reaper.GetSetEnvelopeInfo_String(fx_interpolated_env, "VISIBLE ", "1", false)
            reaper.ShowConsoleMsg("\n" .. tostring(_) .. " / " .. tostring(stringNeedBig))
            --[[
            if stringNeedBig == "1" then
                local _, _ = reaper.GetSetEnvelopeInfo_String(fx_interpolated_env, "SHOWLANE", "0", true)
                local _, _ = reaper.GetSetEnvelopeInfo_String(fx_interpolated_env, "VISIBLE ", "0", true)
                reaper.ShowConsoleMsg("\nNew Hide: " .. tostring(stringNeedBig))

                reaper.TrackList_AdjustWindows(false)
            end
            ]]
        end
    else

        reaper.ShowConsoleMsg(output.desc)
    end
end

function SlewRateInterpolation(current_time, current_value, target_time, target_value, ascend_speed, descend_speed)
    -- Vérifie si les vitesses sont valides
    if ascend_speed <= 0 or descend_speed <= 0 then
        error("Les vitesses doivent être strictement positives.")
    end

    -- Calcul de la différence de valeur
    local value_difference = target_value - current_value

    -- Déterminer la vitesse en fonction de la direction
    local speed = 0
    if value_difference > 0 then
        speed = ascend_speed or descend_speed
    else
        speed = descend_speed
    end

    -- Temps nécessaire pour atteindre la cible
    local time_to_reach = math.abs(value_difference) / speed

    -- Si la valeur atteint la cible avant le temps cible
    if time_to_reach <= (target_time - current_time) then
        -- Moment où la valeur atteint la cible
        local plateau_start_time = current_time + time_to_reach

        return plateau_start_time, target_value, true
    else
        -- Transition partielle si la cible ne peut pas être atteinte
        --[[
        local direction = value_difference > 0 and 1 or -1
        local max_distance = (target_time - current_time) * speed
        local new_value = current_value + direction * max_distance]]

        local elapsed_time = target_time - current_time
        local partial_distance = speed * elapsed_time
        local direction = value_difference > 0 and 1 or -1
        local new_value = current_value + direction * partial_distance

        return target_time, new_value, false
    end
end

function FilteringOverTimeInterpolation(current_time, current_value, target_time, target_value, ascend_speed, descend_speed)
    -- Vérifie si les temps de transition sont valides
    if ascend_speed < 0 or descend_speed < 0 then
        error("Speed need to be >= 0")
    end

    -- Calcul de la différence de valeur
    local value_difference = target_value - current_value

    -- Déterminer le temps de transition en fonction de la direction
    local unit_time = value_difference > 0 and ascend_speed or descend_speed

    -- Temps nécessaire pour effectuer la transition complète
    local time_to_reach = unit_time

    -- Si la transition est complète avant le temps cible
    if time_to_reach <= (target_time - current_time) then
        -- Moment où la valeur atteint la cible
        local plateau_start_time = current_time + time_to_reach
        return plateau_start_time, target_value, true
    else
        -- Transition partielle si la cible ne peut pas être atteinte
        --[[
        local time_fraction = (target_time - current_time) / transition_time
        local new_value = current_value + value_difference * time_fraction]]--

        local elapsed_time = target_time - current_time
        local distance_fraction = elapsed_time / time_to_reach
        local partial_distance = distance_fraction * value_difference
        local new_value = current_value + partial_distance

        return target_time, new_value, false
    end
end

return Sys_RTPCtracks