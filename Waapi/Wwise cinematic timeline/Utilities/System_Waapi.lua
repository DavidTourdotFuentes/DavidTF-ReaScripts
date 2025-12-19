-- @noindex

local Waapi = {}

Waapi.issues = {}
Waapi.connected = nil

---@class Msg
---@field state string The state of the message
---@field desc string The description of the message
local Msg = {state = "", desc = ""}

--- Send an Wwise API Call and get status and result
---@param cmd string Waapi command
---@param arg number Waapi arguments
---@param options number Waapi options
---@return {} status,  {} result State of the call and result
function Waapi.Call(cmd, arg, options)
    local result = reaper.AK_Waapi_Call(cmd, arg, options)
    local status = reaper.AK_AkJson_GetStatus(result)
    return status, result
end

function GetErrorMessage(result)
    local error_msg = reaper.AK_AkJson_Map_Get(result, "message")
    local error_msg_str = reaper.AK_AkVariant_GetString(error_msg)

    return error_msg_str
end

--- Remove a Wwise object based on his name and type, or his ID if "id" is not nil
---@param name string Name of the Wwise object
---@param type string Type of the Wwise object
---@return Msg output State of the "Remove" call
function Waapi.Remove(name, type, id)

    local arguments = reaper.AK_AkJson_Map()
    if id then
        reaper.AK_AkJson_Map_Set(arguments, "object", reaper.AK_AkVariant_String(id))
    else
        reaper.AK_AkJson_Map_Set(arguments, "object", reaper.AK_AkVariant_String(type..":"..name))
    end

    local options = reaper.AK_AkJson_Map()

    local status, result = Waapi.Call("ak.wwise.core.object.delete", arguments, options)

    if status then
        local output = {state = "INFO", desc = type .. ":".. name .." cleared"}
        return output
    else
        local output = {state = "WARNING", desc = "Object ".. name .. " not found"}
        return output
    end
end

--- Create Wwise SFX with silent audio source
---@param name string Name of the Wwise object
---@return Msg output, string masterID State of the "Create" call and ID of the created object
function Waapi.CreateSilentSource(name)
    local arguments = reaper.AK_AkJson_Map()

    local source = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(source, "name", reaper.AK_AkVariant_String("Silence"))
    reaper.AK_AkJson_Map_Set(source, "type", reaper.AK_AkVariant_String("SourcePlugin"))
    reaper.AK_AkJson_Map_Set(source, "classId", reaper.AK_AkVariant_Int("6619138"))

    local source_childrens = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(source_childrens, source)

    local child = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(child, "type", reaper.AK_AkVariant_String("Sound"))
    reaper.AK_AkJson_Map_Set(child, "name", reaper.AK_AkVariant_String(name))
    reaper.AK_AkJson_Map_Set(child, "children", source_childrens)
    reaper.AK_AkJson_Map_Set(child, "@IsLoopingEnabled",  reaper.AK_AkVariant_Bool(true))

    local children = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(children, child)

    local object = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(object, "object", reaper.AK_AkVariant_String("\\Actor-Mixer Hierarchy\\Default Work Unit"))
    reaper.AK_AkJson_Map_Set(object, "children", children)

    local objects = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(objects, object)

    reaper.AK_AkJson_Map_Set(arguments, "objects", objects)
    reaper.AK_AkJson_Map_Set(arguments, "onNameConflict", reaper.AK_AkVariant_String("merge"))

    local fields_to_return = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(fields_to_return, reaper.AK_AkVariant_String("id"))
    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fields_to_return)

    local status, result = Waapi.Call("ak.wwise.core.object.set", arguments, options)

    if status then
        local return_data = reaper.AK_AkJson_Map_Get(result, "objects")
        local obj = reaper.AK_AkJson_Array_Get(return_data, 0)
        local obj_child = reaper.AK_AkJson_Array_Get(reaper.AK_AkJson_Map_Get(obj, "children"), 0)
        local obj_child_ID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(obj_child, "id"))

        local output = {state = "INFO", desc = "Silent sfx created"}
        return output, obj_child_ID
    else
        local output = {state = "ERROR", desc = GetErrorMessage(result)}
        return output, ""
    end

end

--- Get ID of the Master Bus
---@return Msg output, string masterID State of the "Get" call and ID Master Bus
function Waapi.GetMasterBusID()
    local master_ID = ""

    local arguments = reaper.AK_AkJson_Map()

    local waql_search = reaper.AK_AkVariant_String('$ "Bus:Master Audio Bus"')
    reaper.AK_AkJson_Map_Set(arguments, "waql", waql_search)

    local fields_to_return = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(fields_to_return, reaper.AK_AkVariant_String("id"))

    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fields_to_return)

    local status, result = Waapi.Call("ak.wwise.core.object.get", arguments, options)

    local output = {}
    if status then
        local return_data = reaper.AK_AkJson_Map_Get(result, "return")
        if reaper.AK_AkJson_Array_Size(return_data) == 1 then
            local obj = reaper.AK_AkJson_Array_Get(return_data, 0)
            master_ID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(obj, "id"))
            output = {state = "INFO", desc = '"Master Audio Bus" found'}
        end

        if master_ID == "" then
            output = {state = "ERROR", desc = 'No "Master Audio Bus" on this session'}
        end
    else
        output = {state = "ERROR", desc = "Error on Master Audio Bus : " .. GetErrorMessage(result)}
    end

    return output, master_ID
end

function Waapi.AddRecorder(master_ID, output_path, slot)
    local arguments = reaper.AK_AkJson_Map()

    local effect = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(effect, "type", reaper.AK_AkVariant_String("Effect"))
    reaper.AK_AkJson_Map_Set(effect, "name", reaper.AK_AkVariant_String("Wwise Recorder"))
    reaper.AK_AkJson_Map_Set(effect, "classId", reaper.AK_AkVariant_Int(8650755))
    reaper.AK_AkJson_Map_Set(effect, "@AuthoringFilename", reaper.AK_AkVariant_String(output_path))
    reaper.AK_AkJson_Map_Set(effect, "@DownmixToStereo", reaper.AK_AkVariant_Bool(Gui.stereo_downmix))

    local effects = reaper.AK_AkJson_Array()
    local effects_map = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(effects_map, "type", reaper.AK_AkVariant_String("EffectSlot"))
    reaper.AK_AkJson_Map_Set(effects_map, "name", reaper.AK_AkVariant_String(""))
    reaper.AK_AkJson_Map_Set(effects_map, "@Effect", effect)

    reaper.AK_AkJson_Array_Add(effects, effects_map)

    local object = reaper.AK_AkJson_Array()
    local object_map = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(object_map, "object", reaper.AK_AkVariant_String(master_ID))
    reaper.AK_AkJson_Map_Set(object_map, "@Effects", effects)

    reaper.AK_AkJson_Array_Add(object, object_map)

    reaper.AK_AkJson_Map_Set(arguments, "objects", object)

    local options = reaper.AK_AkJson_Map()

    local status, result = Waapi.Call("ak.wwise.core.object.set", arguments, options)

    if not status then
        local output = {state = "ERROR", desc = "Error on adding recorder : " .. GetErrorMessage(result)}
        return output
    else

        local output = {state = "INFO", desc = "Recorder added slot " .. slot}
        return output
    end
end

function Waapi.CleanMasterEffectRack(master_ID, output_path)

    local arguments = reaper.AK_AkJson_Map()

    local waql_search = reaper.AK_AkVariant_String('$ "'..master_ID..'"')
    reaper.AK_AkJson_Map_Set(arguments, "waql", waql_search)

    local fields_to_return = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(fields_to_return, reaper.AK_AkVariant_String("effects.effect.pluginName"))
    reaper.AK_AkJson_Array_Add(fields_to_return, reaper.AK_AkVariant_String("effects.id"))

    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fields_to_return)

    local status, result = Waapi.Call("ak.wwise.core.object.get", arguments, options)

    if status then
        local return_table = reaper.AK_AkJson_Map_Get(result, "return")

        local plugin_name_table = reaper.AK_AkJson_Map_Get(reaper.AK_AkJson_Array_Get(return_table, 0), "effects.effect.pluginName")
        local plugin_ID_table = reaper.AK_AkJson_Map_Get(reaper.AK_AkJson_Array_Get(return_table, 0), "effects.id")

        local plugin_name_table_num = reaper.AK_AkJson_Array_Size(plugin_ID_table)

        -- Count Recorders
        local recorders_ID = 0
        local recorders_name = ""
        for slot = 0, plugin_name_table_num - 1 do
            local effect_name = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(plugin_name_table, slot))
            local effect_ID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(plugin_ID_table, slot))
            if effect_name == "Wwise Recorder" then
                table.insert(Sys_utils.recordersSlots, slot)
            end
        end

        if #Sys_utils.recordersSlots >= 1 then
            local output_msg = {}
            for i=1, #Sys_utils.recordersSlots do
                recorders_ID = Sys_utils.recordersSlots[i]
                recorders_name = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(plugin_ID_table, recorders_ID))

                local output = Waapi.Remove("Recorder", "Effect", recorders_name)
                table.insert(output_msg, output)
            end

            local output = Waapi.AddRecorder(master_ID, output_path, plugin_name_table_num - 1)
            table.insert(output_msg, output)

            return output_msg, recorders_ID
        else
            local output_msg = {}
            local output = Waapi.AddRecorder(master_ID, output_path, plugin_name_table_num)
            table.insert(output_msg, output)

            recorders_ID = plugin_name_table_num
            recorders_name = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(plugin_ID_table, recorders_ID - 1))

            return output_msg, recorders_ID
        end
    else
        local output_msg = {}
        local output = {state = "ERROR", desc = "Error on Master effect track cleaning"}
        table.insert(output_msg, output)

        return output_msg, -1
    end
end

---@param name string Effect name
---@param master_ID string Wwise Master Bus ID
---@param slot number number of the effect slot
---@param bypass boolean Type de l'objet wwise recherché
---@param position integer Position in time
---@return {} child Set bypass or not for recorder effect
function Waapi.RecorderActionByPass(name, master_ID, slot, bypass, position)

    local child = reaper.AK_AkJson_Map()

    reaper.AK_AkJson_Map_Set(child, "name", reaper.AK_AkVariant_String(name))
    reaper.AK_AkJson_Map_Set(child, "type", reaper.AK_AkVariant_String("Action"))
    reaper.AK_AkJson_Map_Set(child, "@ActionType", reaper.AK_AkVariant_Int(50))
    reaper.AK_AkJson_Map_Set(child, "@Target", reaper.AK_AkVariant_String(master_ID))
    reaper.AK_AkJson_Map_Set(child, "@Delay", reaper.AK_AkVariant_Double(position))
    reaper.AK_AkJson_Map_Set(child, "@BypassFlag", reaper.AK_AkVariant_Bool(bypass))
    reaper.AK_AkJson_Map_Set(child, "@EffectSlot", reaper.AK_AkVariant_Int(slot))

    return child
end

--- Recherche l'objet wwise a partir de son nom et de son type et retourne son ID
---@param obj_type string Type de l'objet wwise recherché
---@param name string Nom de l'objet wwise recherché
---@return {} output, number child Statut de l'opération ainsi suivi de l'identifiant trouvé (0 si non trouvé)
function Waapi.GetObjectID(obj_type, name)

    local arguments = reaper.AK_AkJson_Map()

    local waql_search = reaper.AK_AkVariant_String('$ "'..obj_type..'" select descendants where name = "'..name..'"')
    reaper.AK_AkJson_Map_Set(arguments, "waql", waql_search)

    local options = reaper.AK_AkJson_Map()

    local status, result  = Waapi.Call("ak.wwise.core.object.get", arguments, options)

    local output = {}
    if status then
        local return_data = reaper.AK_AkJson_Map_Get(result, "return")
        if reaper.AK_AkJson_Array_Size(return_data) == 1 then
            local first = reaper.AK_AkJson_Array_Get(return_data, 0)
            local id = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(first, "id"))

            output = {state = "INFO", desc = "ID get"}
            return output, id
        else
            if reaper.AK_AkJson_Array_Size(return_data) == 0 then
                local output = {state = "ERROR", desc = "Object '"..name.."' not found"}
                return output, 0
            end
            if reaper.AK_AkJson_Array_Size(return_data) > 1 then
                local first = reaper.AK_AkJson_Array_Get(return_data, 0)
                local id = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(first, "id"))
                output = {state = "ERROR", desc = "'"..name.."' more than once in Wwise project (check PostEvent reference to fix occasional bugs)"}
                return output, id
            end
        end
    else
        output = {state = "ERROR", desc = "Error on Get ".. name .." ID : " .. GetErrorMessage(result)}
        return output, 0
    end

    return output, 0
end

--- Retourne tous les RTPC existant dans Wwise
---@return {} output, {} rtpc_list Statut de l'opération ainsi suivi de la liste des RTPC (rtpc.id et rtpc.name)
function Waapi.GetAllRTPCs()

    local output = {}
    local rtpc_list = {}

    local arguments = reaper.AK_AkJson_Map()

    local waql_search = reaper.AK_AkVariant_String('$ from type GameParameter')
    reaper.AK_AkJson_Map_Set(arguments, "waql", waql_search)

    local fields_to_return = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(fields_to_return, reaper.AK_AkVariant_String("id"))
    reaper.AK_AkJson_Array_Add(fields_to_return, reaper.AK_AkVariant_String("name"))

    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fields_to_return)

    local status, result  = Waapi.Call("ak.wwise.core.object.get", arguments, options)

    if status then
        local return_data = reaper.AK_AkJson_Map_Get(result, "return")
        for i = 0, reaper.AK_AkJson_Array_Size(return_data) - 1 do
            local current_RTPC = reaper.AK_AkJson_Array_Get(return_data, i)
            local current_ID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(current_RTPC, "id"))
            local current_name = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(current_RTPC, "name"))
            table.insert(rtpc_list, {id = current_ID, name = current_name})
        end

        output = {state = "INFO", desc = "RTPC list successfully getted"}

    else
        output = {state = "ERROR", desc = "Error on Get : " .. GetErrorMessage(result)}
    end

    return output, rtpc_list
end

--- Retourne min, max et value d'un RTPC Wwwise
---@param rptc_name string Nom du RTPC
---@return {} output, {} rtpc Statut de l'opération ainsi suivi de l'objet RTPC retourné
function Waapi.GetRTPCInfo(rptc_name)

    local output = {}
    local rtpc = {}

    local arguments = reaper.AK_AkJson_Map()

    local waql_search = reaper.AK_AkVariant_String('$ from object "GameParameter:' .. rptc_name .. '"')
    reaper.AK_AkJson_Map_Set(arguments, "waql", waql_search)

    local fields_to_return = reaper.AK_AkJson_Array()

    reaper.AK_AkJson_Array_Add(fields_to_return, reaper.AK_AkVariant_String("initialValue"))
    reaper.AK_AkJson_Array_Add(fields_to_return, reaper.AK_AkVariant_String("min"))
    reaper.AK_AkJson_Array_Add(fields_to_return, reaper.AK_AkVariant_String("max"))
    reaper.AK_AkJson_Array_Add(fields_to_return, reaper.AK_AkVariant_String("RTPCRamping"))
    reaper.AK_AkJson_Array_Add(fields_to_return, reaper.AK_AkVariant_String("SlewRateDown"))
    reaper.AK_AkJson_Array_Add(fields_to_return, reaper.AK_AkVariant_String("SlewRateUp"))
    reaper.AK_AkJson_Array_Add(fields_to_return, reaper.AK_AkVariant_String("FilterTimeDown"))
    reaper.AK_AkJson_Array_Add(fields_to_return, reaper.AK_AkVariant_String("FilterTimeUp"))

    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fields_to_return)

    local status, result  = Waapi.Call("ak.wwise.core.object.get", arguments, options)

    if status then

        local return_table = reaper.AK_AkJson_Map_Get(result, "return")

        local rtpc_item = reaper.AK_AkJson_Array_Get(return_table, 0)
        local value = reaper.AK_AkVariant_GetDouble(reaper.AK_AkJson_Map_Get(rtpc_item, "initialValue"))
        local min = reaper.AK_AkVariant_GetDouble(reaper.AK_AkJson_Map_Get(rtpc_item, "min"))
        local max = reaper.AK_AkVariant_GetDouble(reaper.AK_AkJson_Map_Get(rtpc_item, "max"))
        local ramping = reaper.AK_AkVariant_GetInt(reaper.AK_AkJson_Map_Get(rtpc_item, "RTPCRamping"))
        local slew_rate_down = reaper.AK_AkVariant_GetDouble(reaper.AK_AkJson_Map_Get(rtpc_item, "SlewRateDown"))
        local slew_rate_up = reaper.AK_AkVariant_GetDouble(reaper.AK_AkJson_Map_Get(rtpc_item, "SlewRateUp"))
        local filter_time_down = reaper.AK_AkVariant_GetDouble(reaper.AK_AkJson_Map_Get(rtpc_item, "FilterTimeDown"))
        local filter_time_up = reaper.AK_AkVariant_GetDouble(reaper.AK_AkJson_Map_Get(rtpc_item, "FilterTimeUp"))

        output = {state = "INFO", desc = "RTPC list successfully getted"}
        rtpc = {value = value, min = min, max = max, ramping = ramping, slew_rate_down = slew_rate_down, slew_rate_up = slew_rate_up, filter_time_down = filter_time_down, filter_time_up = filter_time_up}

    else
        output = {state = "ERROR", desc = "Error on Get ".. rptc_name .." ID : " .. GetErrorMessage(result)}
    end

    return output, rtpc
end

-- Retourne le contenu Json d'un objet
function Waapi.MapChildContent(name, action_type, target, delay, parameter_value, bypass, bypass_value)

    local child = reaper.AK_AkJson_Map()

    reaper.AK_AkJson_Map_Set(child, "name", reaper.AK_AkVariant_String(name..math.random(0, 10000000)))
    reaper.AK_AkJson_Map_Set(child, "type", reaper.AK_AkVariant_String("Action"))
    reaper.AK_AkJson_Map_Set(child, "@ActionType", reaper.AK_AkVariant_Int(action_type))
    reaper.AK_AkJson_Map_Set(child, "@Target", reaper.AK_AkVariant_String(target))
    reaper.AK_AkJson_Map_Set(child, "@Delay", reaper.AK_AkVariant_Double(delay))

    if parameter_value then
        reaper.AK_AkJson_Map_Set(child, "@GameParameterValue", reaper.AK_AkVariant_Double(tonumber(parameter_value)))
    end
    if bypass then
        reaper.AK_AkJson_Map_Set(child, "@Bypass", reaper.AK_AkVariant_Bool(bypass_value))
    end

    return child
end

function Waapi.GenerateEventContent(id, name, event_position)
    local curr_child = reaper.AK_AkJson_Map()

    local state, words = Sys_utils.DetectValueType(name)

    if state == "" then
        local output, target_ID = Waapi.GetObjectID("Events", name)
        if output.state ~= "INFO" then
            return output, curr_child
        end

        curr_child = Waapi.MapChildContent(words[1], 41, target_ID, event_position)
    end

    if state == "[PLAY]" then
        local output, target_ID = Waapi.GetObjectID("Events", words[2])
        if output.state ~= "INFO" then
            return output, curr_child
        end

        curr_child = Waapi.MapChildContent(words[2], 41, target_ID, event_position)
    end

    if state == "[STOPALL]" then
        local output, target_ID = Waapi.GetObjectID("Events", name)
        if output.state ~= "INFO" then
            return output, curr_child
        end

        curr_child = Waapi.MapChildContent(words[1], 3, target_ID, event_position)
    end

    if state == "[RTPC]" then
        local output, target_ID = Waapi.GetObjectID("Game Parameters", words[2])
        if output.state ~= "INFO" then
            return output, curr_child
        end

        curr_child = Waapi.MapChildContent(words[2], 38, target_ID, event_position, tonumber(words[3]))
    end

    if state == "[STATE]" then
        local output, target_ID = Waapi.GetObjectID("States", words[3])
        if output.state ~= "INFO" then
            return output, curr_child
        end

        curr_child = Waapi.MapChildContent(words[2].."_"..id, 22, target_ID, event_position)
    end

    if state == "[SWITCH]" then
        local output, target_ID = Waapi.GetObjectID("Switches", words[3])
        if output.state ~= "INFO" then
            return output, curr_child
        end

        curr_child = Waapi.MapChildContent(words[2].."_"..id, 23, target_ID, event_position)
    end

    local output = {state = "INFO", desc = "Event content sucessfully created !"}
    return output, curr_child

end

function Waapi.CreateTimelineEvent()

    local events_list = {}

    -- LOOP ON EACH ITEMS TO CREATE CHILD EVENTS IN CHILDRENS ARRAY
    local childrens = reaper.AK_AkJson_Array()

    local tracks_list = {}

    tracks_list = Sys_utils.AddTrackAndChildrenToList()
    local i = 0
    for _, t in ipairs(tracks_list) do
        local note_item_count = reaper.CountTrackMediaItems(t)
        for j=0, note_item_count - 1 do
            local curr_item = reaper.GetTrackMediaItem(t, j)
            local text = reaper.ULT_GetMediaItemNote(curr_item)
            local pos = reaper.GetMediaItemInfo_Value(curr_item, "D_POSITION")

            table.insert(events_list, {id = i..j, item = curr_item, text = text, position = pos})
        end
        i = i + 1
    end

    -- TRI DE LA LISTE PAR ORDRE D'APPARITION
    table.sort(events_list, function(a, b)
        return a.position < b.position
    end)

    -- MasterTrack Recorder
    local output, master_ID = Waapi.GetMasterBusID()
    Sys_gui.AddLog(output)
    if output.state ~= "INFO" then
         return 0
    end

    local output_table, recorder_slot = Waapi.CleanMasterEffectRack(master_ID, Gui.output_path)
    for i=1, #output_table do
        Sys_gui.AddLog(output_table[i])

        if output_table[i].state == "ERROR" then
             return 0
        end
    end
    -- Create Silent SFX
    local output, silence_source_ID = Waapi.CreateSilentSource("Timeline SFX Source")
    Sys_gui.AddLog(output)
    if output.state ~= "INFO" then
         return 0
    end

    -- Add Recorder ByPass OFF Action
    reaper.AK_AkJson_Array_Add(childrens, Waapi.RecorderActionByPass("Enable Recorder", master_ID, recorder_slot, false, 0))

    -- Add Play Silent Source Action
    local silent_play = Waapi.MapChildContent("Play silent object", 1, silence_source_ID, 0)

    reaper.AK_AkJson_Array_Add(childrens, silent_play)

    local last_position = 0
    -- BOUCLER SUR TOUS LES EVENEMENTS
    for _, event in ipairs(events_list) do

        local output, child = Waapi.GenerateEventContent(event.id, event.text, event.position)
        if output.state ~= "INFO" then
            Sys_gui.AddLog(output)
        end

        reaper.AK_AkJson_Array_Add(childrens, child)

        last_position = event.position
    end

    -- Add Recorder ByPass ON Action
    reaper.AK_AkJson_Array_Add(childrens, Waapi.RecorderActionByPass("Disable Recorder", master_ID, recorder_slot, true, last_position + Gui.event_length))

    -- Add Stop Silent Source Action
    local silent_stop = Waapi.MapChildContent("Stop silent object", 2, silence_source_ID, last_position + Gui.event_length)

    reaper.AK_AkJson_Array_Add(childrens, silent_stop)

    -- CREATION DE L'OBJET TIMELINE
    local e_parent = reaper.AK_AkVariant_String("\\Events\\Default Work Unit")
    local e_name = reaper.AK_AkVariant_String(Gui.event_name)
    local e_type = reaper.AK_AkVariant_String("Event")
    local e_conflicts = reaper.AK_AkVariant_String("replace")

    local arguments = reaper.AK_AkJson_Map()

    reaper.AK_AkJson_Map_Set(arguments, "parent", e_parent)
    reaper.AK_AkJson_Map_Set(arguments, "name", e_name)
    reaper.AK_AkJson_Map_Set(arguments, "type", e_type)
    reaper.AK_AkJson_Map_Set(arguments, "onNameConflict", e_conflicts)
    reaper.AK_AkJson_Map_Set(arguments, "children", childrens)

    local options = reaper.AK_AkJson_Map()

    local status, result = Waapi.Call("ak.wwise.core.object.create", arguments, options)

    if status then
        Sys_gui.AddLog({state = "INFO", desc = "Event Timeline created"})
        return last_position + Gui.event_length
    else
        local msg = ""
        for _, issue in ipairs(Waapi.issues) do
            msg = msg.." : "..issue
        end

        Sys_gui.AddLog({state = "ERROR", desc = msg.."No timeline created cause of error(s) : " .. GetErrorMessage(result)})

        return 0
    end
end

function Waapi.InitializeGameObjects()

    -- Register Listener Game Object 
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", reaper.AK_AkVariant_Int(1))
    reaper.AK_AkJson_Map_Set(arguments, "name", reaper.AK_AkVariant_String("Reaper Listener"))

    local options = reaper.AK_AkJson_Map()

    Waapi.Call("ak.soundengine.registerGameObj", arguments, options)

    -- Register Emitter Game Object
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", reaper.AK_AkVariant_Int(2))
    reaper.AK_AkJson_Map_Set(arguments, "name", reaper.AK_AkVariant_String("Reaper Emitter"))

    local options = reaper.AK_AkJson_Map()

    Waapi.Call("ak.soundengine.registerGameObj", arguments, options)

    -- Set Listener
    local listeners = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(listeners, reaper.AK_AkVariant_Int(1))

    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "emitter", reaper.AK_AkVariant_Int(2))
    reaper.AK_AkJson_Map_Set(arguments, "listeners", listeners)

    local options = reaper.AK_AkJson_Map()

    Waapi.Call("ak.soundengine.setListeners", arguments, options)
end

function Waapi.ClearGameObjects()
    -- Stop all remaining sounds on gameObject 2 (emmiter)
    local id = reaper.AK_AkVariant_Int(2)
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", id)

    local options = reaper.AK_AkJson_Map()

    Waapi.Call("ak.soundengine.stopAll", arguments, options)

    -- Unregister Game Object 1 (listener)
    local id = reaper.AK_AkVariant_Int(1)

    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", id)

    local options = reaper.AK_AkJson_Map()

    Waapi.Call("ak.soundengine.unregisterGameObj", arguments, options)

    -- Unregister Game Object 2 (emmiter)
    local id = reaper.AK_AkVariant_Int(2)

    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", id)

    local options = reaper.AK_AkJson_Map()

    Waapi.Call("ak.soundengine.unregisterGameObj", arguments, options)
end

function Waapi.PlayEvent(event)
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "event", reaper.AK_AkVariant_String(event))
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", reaper.AK_AkVariant_Int(2))

    local options = reaper.AK_AkJson_Map()

    local status, result = Waapi.Call("ak.soundengine.postEvent", arguments, options)

    if status then
        local output = {state = "INFO", desc = "Timeline event played"}
        return output
    else
        local output = {state = "ERROR", desc = GetErrorMessage(result)}
        return output
    end
end

function Waapi.SetRTPC(rtpc, value)
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "rtpc", reaper.AK_AkVariant_String(rtpc))
    reaper.AK_AkJson_Map_Set(arguments, "value", reaper.AK_AkVariant_Double(value))
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", reaper.AK_AkVariant_Int(2))

    local options = reaper.AK_AkJson_Map()

    local status, result = Waapi.Call("ak.soundengine.setRTPCValue", arguments, options)

    if status then
        local output = {state = "INFO", desc = "RTPC " .. rtpc .. " set to " .. tostring(value)}
        return output
    else
        local output = {state = "ERROR", desc = GetErrorMessage(result)}
        return output
    end
end

function Waapi.Record()

    local output_msg = {}

    -- Play de l'event timeline

    local output = Waapi.PlayEvent(Gui.main_event_name)
    table.insert(output_msg, output)
    if output.state ~= "INFO" then
        return output_msg
    end

    table.insert(output_msg, {state = "WARNING", desc = "Recording : Please don't stop the event on Wwise"})
    return output_msg
end

function Waapi.Stop(_output_path)

    local result = reaper.InsertMedia(_output_path, 1)

    -- Move created track on top of the project
    reaper.ReorderSelectedTracks(0, 0)

    -- Move timeline item to start at 0s
    local item = reaper.GetSelectedMediaItem(0, 0)
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", 0)

    local output = {}
    if result == 1 then
        output = {state = "INFO", desc = "Audio imported on reaper"}
    else
        output = {state = "ERROR", desc = "Audio failed to import on reaper"}
    end

    return output
end

function Waapi.CleanWwiseSession()

    local output_msg = {}

    Waapi.ClearGameObjects()

    local output, master_ID = Waapi.GetMasterBusID()
    table.insert(output_msg, output)
    if output.state ~= "INFO" then
        return output_msg
    end

    local arguments = reaper.AK_AkJson_Map()

    local waql_search = reaper.AK_AkVariant_String('$ "'..master_ID..'"')
    reaper.AK_AkJson_Map_Set(arguments, "waql", waql_search)

    local fields_to_return = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(fields_to_return, reaper.AK_AkVariant_String("effects.effect.pluginName"))
    reaper.AK_AkJson_Array_Add(fields_to_return, reaper.AK_AkVariant_String("effects.id"))

    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fields_to_return)

    local status, result = Waapi.Call("ak.wwise.core.object.get", arguments, options)

    if status then
        local return_table = reaper.AK_AkJson_Map_Get(result, "return")

        local plugin_name_table = reaper.AK_AkJson_Map_Get(reaper.AK_AkJson_Array_Get(return_table, 0), "effects.effect.pluginName")
        local plugin_ID_table = reaper.AK_AkJson_Map_Get(reaper.AK_AkJson_Array_Get(return_table, 0), "effects.id")

        local plugin_name_table_num = reaper.AK_AkJson_Array_Size(plugin_name_table)

        -- Count Recorders
        local recorders_table_index = 0
        local recorders_ID = ""
        for slot = 0, plugin_name_table_num - 1 do
            local effect_name = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(plugin_name_table, slot))
            local effect_ID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(plugin_ID_table, slot))
            if effect_name == "Wwise Recorder" then
                table.insert(Sys_utils.recordersSlots, slot)
            end
        end

        for i=1, #Sys_utils.recordersSlots do
            recorders_table_index = Sys_utils.recordersSlots[i]
            recorders_ID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(plugin_ID_table, recorders_table_index))

            output = Waapi.Remove("Recorder", "Effect", recorders_ID)
            table.insert(output_msg, output)
        end

    else
        output = {state = "ERROR", desc = "Error on Master effect track cleaning"}
        table.insert(output_msg, output)
    end

    -- $ from type Sound where name = "Timeline SFX Source"
    local arguments = reaper.AK_AkJson_Map()

    waql_search = reaper.AK_AkVariant_String('$ from type Sound where name = "Timeline SFX Source"')
    reaper.AK_AkJson_Map_Set(arguments, "waql", waql_search)

    local fields_to_return = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(fields_to_return, reaper.AK_AkVariant_String("id"))

    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fields_to_return)

    status, result = Waapi.Call("ak.wwise.core.object.get", arguments, options)

    if status then
        local returnTable = reaper.AK_AkJson_Map_Get(result, "return")

        local id = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(reaper.AK_AkJson_Array_Get(returnTable, 0), "id"))

        output = Waapi.Remove("Timeline SFX Source", "Sound", id)

        table.insert(output_msg, output)
    else

        table.insert(output_msg, {state = "ERROR", desc = 'No "Timeline SFX Source" on the wwise project'})
    end


    output = Waapi.Remove("Play_Linear_Timeline", "Event")
    table.insert(output_msg, output)
    if output.state ~= "INFO" then
        return output_msg
    end

    return output_msg
end

function Waapi.Connect()
    local output = {}

    local waapi_state = reaper.AK_Waapi_Connect("127.0.0.1", 8080)

    if waapi_state then
        output = {state = "INFO", desc = "Wwise connected"}
        Waapi.connected = true

        App_state = "Working"

        Sys_gui.AddLog(output)

        Sys_utils.Init()
    else
        output = {state = "ERROR", desc = "Error connecting with Wwise : is project opened ?"}
        Waapi.connected = false

        App_state = "Disconnected"

        Sys_gui.AddLog(output)
    end

    Waapi.InitializeGameObjects()
end

function Waapi.Disconnect()
    Waapi.ClearGameObjects()
    reaper.AK_Waapi_Disconnect()
    Waapi.connected = false
end

return Waapi