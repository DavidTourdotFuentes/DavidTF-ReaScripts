-- @noindex

local Waapi = {}

Waapi.issues = {}
Waapi.connected = false

---@class Msg
---@field state string The state of the message
---@field desc string The description of the message
local Msg = {state = "", desc = ""}

--- Send an Wwise API Call and get status and result
---@param _cmd string Waapi command
---@param _arg number Waapi arguments
---@param _options number Waapi options
---@return {} status,  {} result State of the call and result
function Waapi.Call(_cmd, _arg, _options)
    local result = reaper.AK_Waapi_Call(_cmd, _arg, _options)
    local status = reaper.AK_AkJson_GetStatus(result)
    return status, result
end

--- Remove a Wwise object based on his name and type, or his ID if "_id" is not nil
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
    
    local sourceChildrens = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(sourceChildrens, source)
    
    local child = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(child, "type", reaper.AK_AkVariant_String("Sound"))
    reaper.AK_AkJson_Map_Set(child, "name", reaper.AK_AkVariant_String(name))
    reaper.AK_AkJson_Map_Set(child, "children", sourceChildrens)
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
    
    local fieldsToReturn = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(fieldsToReturn, reaper.AK_AkVariant_String("id"))
    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fieldsToReturn)

    local status, result = Waapi.Call("ak.wwise.core.object.set", arguments, options)
    
    if status then
        local returnData = reaper.AK_AkJson_Map_Get(result, "objects")
        local obj = reaper.AK_AkJson_Array_Get(returnData, 0)
        local objChild = reaper.AK_AkJson_Array_Get(reaper.AK_AkJson_Map_Get(obj, "children"), 0)
        local objChildID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(objChild, "id"))
        
        local output = {state = "INFO", desc = "Silent sfx created"}
        return output, objChildID
    else
        local errorMessage = reaper.AK_AkJson_Map_Get(result, "message")
        local errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)
        
        local output = {state = "ERROR", desc = errorMessageStr}
        return output, ""
    end

end

--- Get ID of the Master Bus
---@return Msg output, string masterID State of the "Get" call and ID Master Bus
function Waapi.GetMasterBusID()
    local masterID = ""
    
    local arguments = reaper.AK_AkJson_Map()
    
    local waqlSearch = reaper.AK_AkVariant_String('$ "Bus:Master Audio Bus"')
    reaper.AK_AkJson_Map_Set(arguments, "waql", waqlSearch)
    
    local fieldsToReturn = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(fieldsToReturn, reaper.AK_AkVariant_String("id"))
    
    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fieldsToReturn)

    local status, result = Waapi.Call("ak.wwise.core.object.get", arguments, options)

    local output = {}
    if status then
        local returnData = reaper.AK_AkJson_Map_Get(result, "return")
        if reaper.AK_AkJson_Array_Size(returnData) == 1 then
            local obj = reaper.AK_AkJson_Array_Get(returnData, 0)
            masterID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(obj, "id"))
            output = {state = "INFO", desc = '"Master Audio Bus" found'}
        end
   
        if masterID == "" then
            output = {state = "ERROR", desc = 'No "Master Audio Bus" on this session'}
        end
    else
        local errorMessage = reaper.AK_AkJson_Map_Get(result, "message")
        local errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)

        output = {state = "ERROR", desc = "Error on Master Audio Bus : " .. errorMessageStr}
    end
    
    return output, masterID
end

function Waapi.AddRecorder(_masterID, _outputPath, _slot)
    local arguments = reaper.AK_AkJson_Map()
    
    local effect = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(effect, "type", reaper.AK_AkVariant_String("Effect"))
    reaper.AK_AkJson_Map_Set(effect, "name", reaper.AK_AkVariant_String("Wwise Recorder"))
    reaper.AK_AkJson_Map_Set(effect, "classId", reaper.AK_AkVariant_Int(8650755))
    reaper.AK_AkJson_Map_Set(effect, "@AuthoringFilename", reaper.AK_AkVariant_String(_outputPath))
    reaper.AK_AkJson_Map_Set(effect, "@DownmixToStereo", reaper.AK_AkVariant_Bool(gui.stereo_downmix))
    
    local effects = reaper.AK_AkJson_Array()
    local effectsMap = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(effectsMap, "type", reaper.AK_AkVariant_String("EffectSlot"))
    reaper.AK_AkJson_Map_Set(effectsMap, "name", reaper.AK_AkVariant_String(""))
    reaper.AK_AkJson_Map_Set(effectsMap, "@Effect", effect)
    
    reaper.AK_AkJson_Array_Add(effects, effectsMap)
    
    local object = reaper.AK_AkJson_Array()
    local objectMap = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(objectMap, "object", reaper.AK_AkVariant_String(_masterID))
    reaper.AK_AkJson_Map_Set(objectMap, "@Effects", effects)
    
    reaper.AK_AkJson_Array_Add(object, objectMap)
    
    reaper.AK_AkJson_Map_Set(arguments, "objects", object)
    
    local options = reaper.AK_AkJson_Map()
    
    local status, result = Waapi.Call("ak.wwise.core.object.set", arguments, options)
    
    if not status then
        local errorMessage = reaper.AK_AkJson_Map_Get(result, "message")
        local errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)
        
        local output = {state = "ERROR", desc = "Error on adding recorder : " .. errorMessageStr}
        return output
    else
        
        local output = {state = "INFO", desc = "Recorder added slot " .. _slot}
        return output
    end
end

function Waapi.CleanMasterEffectRack(_masterID, _outputPath)
    
    local arguments = reaper.AK_AkJson_Map()
    
    local waqlSearch = reaper.AK_AkVariant_String('$ "'.._masterID..'"')
    reaper.AK_AkJson_Map_Set(arguments, "waql", waqlSearch)
    
    local fieldsToReturn = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(fieldsToReturn, reaper.AK_AkVariant_String("effects.effect.pluginName"))
    reaper.AK_AkJson_Array_Add(fieldsToReturn, reaper.AK_AkVariant_String("effects.id"))
    
    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fieldsToReturn)

    local status, result = Waapi.Call("ak.wwise.core.object.get", arguments, options)
    
    if status then
        local returnTable = reaper.AK_AkJson_Map_Get(result, "return")
        
        local pluginNameTable = reaper.AK_AkJson_Map_Get(reaper.AK_AkJson_Array_Get(returnTable, 0), "effects.effect.pluginName")
        local pluginIDTable = reaper.AK_AkJson_Map_Get(reaper.AK_AkJson_Array_Get(returnTable, 0), "effects.id")
        
        local pluginNameTableNum = reaper.AK_AkJson_Array_Size(pluginNameTable)
        
        -- Count Recorders
        local recordersIndex = 0
        local recordersID = ""
        for slot = 0, pluginNameTableNum - 1 do
            local effectName = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(pluginNameTable, slot))
            local effectID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(pluginIDTable, slot))
            if effectName == "Wwise Recorder" then
                table.insert(sys_utils.recordersSlots, slot)
            end
        end
        
        if #sys_utils.recordersSlots >= 1 then
            local outputMsg = {}
            for i=1, #sys_utils.recordersSlots do
                recordersIndex = sys_utils.recordersSlots[i]
                recordersID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(pluginIDTable, recordersIndex))
                
                local output = Waapi.Remove("Recorder", "Effect", recordersID)
                table.insert(outputMsg, output)
            end
            
            local output = Waapi.AddRecorder(_masterID, _outputPath, pluginNameTableNum - 1)
            table.insert(outputMsg, output)
            
            return outputMsg, recordersIndex
        else
            local outputMsg = {}
            local output = Waapi.AddRecorder(_masterID, _outputPath, pluginNameTableNum)
            table.insert(outputMsg, output)
            
            recordersIndex = pluginNameTableNum
            recordersID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(pluginIDTable, recordersIndex - 1))
            
            return outputMsg, recordersIndex
        end
    else
        local outputMsg = {}
        local output = {state = "ERROR", desc = "Error on Master effect track cleaning"}
        table.insert(outputMsg, output)
        
        return outputMsg, -1
    end
end

---@return {} child Set le bypass ou non de l'effet recorder
function Waapi.RecorderActionByPass(_name, _masterID, _slot, _bypass, _position)

    local child = reaper.AK_AkJson_Map()
    
    reaper.AK_AkJson_Map_Set(child, "name", reaper.AK_AkVariant_String(_name))
    reaper.AK_AkJson_Map_Set(child, "type", reaper.AK_AkVariant_String("Action"))
    reaper.AK_AkJson_Map_Set(child, "@ActionType", reaper.AK_AkVariant_Int(50))
    reaper.AK_AkJson_Map_Set(child, "@Target", reaper.AK_AkVariant_String(_masterID))
    reaper.AK_AkJson_Map_Set(child, "@Delay", reaper.AK_AkVariant_Double(_position))
    reaper.AK_AkJson_Map_Set(child, "@BypassFlag", reaper.AK_AkVariant_Bool(_bypass))
    reaper.AK_AkJson_Map_Set(child, "@EffectSlot", reaper.AK_AkVariant_Int(_slot))
    
    return child
end

--- Recherche l'objet wwise a partir de son nom et de son type et retourne son ID
---@param _objType string Type de l'objet wwise recherché
---@param _name string Nom de l'objet wwise recherché
---@return {} output, number child Statut de l'opération ainsi suivi de l'identifiant trouvé (0 si non trouvé)
function Waapi.GetObjectID(_objType, _name)

    ---@type boolean
    local arguments = reaper.AK_AkJson_Map()
    
    local waqlSearch = reaper.AK_AkVariant_String('$ "'.._objType..'" select descendants where name = "'.._name..'"')
    reaper.AK_AkJson_Map_Set(arguments, "waql", waqlSearch)
    
    local options = reaper.AK_AkJson_Map()

    local status, result  = Waapi.Call("ak.wwise.core.object.get", arguments, options)
    
    local output = {}
    if status then
        local returnData = reaper.AK_AkJson_Map_Get(result, "return")
        if reaper.AK_AkJson_Array_Size(returnData) == 1 then
            local first = reaper.AK_AkJson_Array_Get(returnData, 0)
            local id = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(first, "id"))
            
            output = {state = "INFO", desc = "ID get"}
            return output, id
        else
            if reaper.AK_AkJson_Array_Size(returnData) == 0 then
                local output = {state = "ERROR", desc = "Object '".._name.."' not found"}
                return output, 0
            end
            if reaper.AK_AkJson_Array_Size(returnData) > 1 then
                local first = reaper.AK_AkJson_Array_Get(returnData, 0)
                local id = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(first, "id"))
                output = {state = "ERROR", desc = "'".._name.."' more than once in Wwise project (check PostEvent reference to fix occasional bugs)"}
                return output, id
            end
        end
    else
        local errorMessage = reaper.AK_AkJson_Map_Get(result, "message")
        local errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)
        output = {state = "ERROR", desc = "Error on Get ".. _name .." ID : " .. errorMessageStr}
        return output, 0
    end

    return output, 0
end

-- Retourne le contenu Json d'un objet
function Waapi.MapChildContent(_name, _actionType, _target, _delay, _parameterValue, _bypass, _bypassValue)
    
    local child = reaper.AK_AkJson_Map()
    
    reaper.AK_AkJson_Map_Set(child, "name", reaper.AK_AkVariant_String(_name..math.random(0, 10000000)))
    reaper.AK_AkJson_Map_Set(child, "type", reaper.AK_AkVariant_String("Action"))
    reaper.AK_AkJson_Map_Set(child, "@ActionType", reaper.AK_AkVariant_Int(_actionType))
    reaper.AK_AkJson_Map_Set(child, "@Target", reaper.AK_AkVariant_String(_target))
    reaper.AK_AkJson_Map_Set(child, "@Delay", reaper.AK_AkVariant_Double(_delay))
    
    if _parameterValue then
        reaper.AK_AkJson_Map_Set(child, "@GameParameterValue", reaper.AK_AkVariant_Double(tonumber(_parameterValue)))
    end
    if _bypass then
        reaper.AK_AkJson_Map_Set(child, "@Bypass", reaper.AK_AkVariant_Bool(_bypassValue))
    end

    return child
end

function Waapi.GenerateEventContent(_id, _name, _eventPosition)
    local currChild = reaper.AK_AkJson_Map()
 
    local state, words = sys_utils.DetectValueType(_name)
    
    if state == "" then
        local output, targetID = Waapi.GetObjectID("Events", _name)
        if output.state ~= "INFO" then
            return output, currChild
        end
        
        currChild = Waapi.MapChildContent(words[1], 41, targetID, _eventPosition)
    end
    
    if state == "[PLAY]" then
        local output, targetID = Waapi.GetObjectID("Events", words[2])
        if output.state ~= "INFO" then
            return output, currChild
        end
        
        currChild = Waapi.MapChildContent(words[2], 41, targetID, _eventPosition)
    end
    
    if state == "[STOPALL]" then
        local output, targetID = Waapi.GetObjectID("Events", _name)
        if output.state ~= "INFO" then
            return output, currChild
        end
        
        currChild = Waapi.MapChildContent(words[1], 3, targetID, _eventPosition)
    end
    
    if state == "[RTPC]" then
        local output, targetID = Waapi.GetObjectID("Game Parameters", words[2])
        if output.state ~= "INFO" then
            return output, currChild
        end
        
        currChild = Waapi.MapChildContent(words[2], 38, targetID, _eventPosition, tonumber(words[3]))
    end
    
    if state == "[STATE]" then
        local output, targetID = Waapi.GetObjectID("States", words[3])
        if output.state ~= "INFO" then
            return output, currChild
        end
        
        currChild = Waapi.MapChildContent(words[2].."_".._id, 22, targetID, _eventPosition)
    end
    
    if state == "[SWITCH]" then
        local output, targetID = Waapi.GetObjectID("Switches", words[3])
        if output.state ~= "INFO" then
            return output, currChild
        end
        
        currChild = Waapi.MapChildContent(words[2].."_".._id, 23, targetID, _eventPosition)
    end
    
    local output = {state = "INFO", desc = "Event content sucessfully created !"}
    return output, currChild

end

function Waapi.CreateTimelineEvent()
    
    local eventsList = {}

    -- LOOP ON EACH ITEMS TO CREATE CHILD EVENTS IN CHILDRENS ARRAY
    local childrens = reaper.AK_AkJson_Array()
    
    local tracksList = {}
    local track = sys_utils.FindTrackByName("Wwise Timeline")
    if track then
        sys_utils.AddTrackAndChildrenToList(track, tracksList)
        local i = 0
        for _, t in ipairs(tracksList) do
            local _, name = reaper.GetTrackName(t)
            
            local noteItemCount = reaper.CountTrackMediaItems(t)
            for j=0, noteItemCount - 1 do
                local currItem = reaper.GetTrackMediaItem(t, j)
                local text = reaper.ULT_GetMediaItemNote(currItem)
                local pos = reaper.GetMediaItemInfo_Value(currItem, "D_POSITION")
                
                table.insert(eventsList, {id = i..j, item = currItem, text = text, position = pos})
            end
            i = i + 1
        end
    else
        sys_gui.AddLog({state = "ERROR", desc = "Track 'Wwise Timeline' not found."})
        return 0
    end
    
    -- TRI DE LA LISTE PAR ORDRE D'APPARITION
    table.sort(eventsList, function(a, b)
        return a.position < b.position
    end)
    
    -- MasterTrack Recorder
    local output, masterID = Waapi.GetMasterBusID()
    sys_gui.AddLog(output)
    if output.state ~= "INFO" then
         return 0
    end
    
    local outputTable, recorderSlot = Waapi.CleanMasterEffectRack(masterID, gui.output_path)
    for i=1, #outputTable do
        sys_gui.AddLog(outputTable[i])
    
        if outputTable[i].state == "ERROR" then
             return 0
        end
    end

    -- Create Silent SFX
    local output, silenceSourceID = Waapi.CreateSilentSource("Timeline SFX Source")
    sys_gui.AddLog(output)
    if output.state ~= "INFO" then
         return 0
    end
    
    -- Add Recorder ByPass OFF Action
    reaper.AK_AkJson_Array_Add(childrens, Waapi.RecorderActionByPass("Enable Recorder", masterID, recorderSlot, false, 0))

    -- Add Play Silent Source Action
    local silentPlay = Waapi.MapChildContent("Play silent object", 1, silenceSourceID, 0)

    reaper.AK_AkJson_Array_Add(childrens, silentPlay)

    local lastPosition = 0
    -- BOUCLER SUR TOUS LES EVENEMENTS
    for _, event in ipairs(eventsList) do
    
        local output, child = Waapi.GenerateEventContent(event.id, event.text, event.position)
        if output.state ~= "INFO" then
            sys_gui.AddLog(output)
        end

        reaper.AK_AkJson_Array_Add(childrens, child)

        lastPosition = event.position
    end

    -- Add Recorder ByPass ON Action
    reaper.AK_AkJson_Array_Add(childrens, Waapi.RecorderActionByPass("Disable Recorder", masterID, recorderSlot, true, lastPosition + gui.event_length))

    -- Add Stop Silent Source Action
    local silentStop = Waapi.MapChildContent("Stop silent object", 2, silenceSourceID, lastPosition + gui.event_length)

    reaper.AK_AkJson_Array_Add(childrens, silentStop)

    -- CREATION DE L'OBJET TIMELINE
    local eParent = reaper.AK_AkVariant_String("\\Events\\Default Work Unit")
    local eName = reaper.AK_AkVariant_String(gui.event_name)
    local eType = reaper.AK_AkVariant_String("Event")
    local eConflicts = reaper.AK_AkVariant_String("replace")

    local arguments = reaper.AK_AkJson_Map()

    reaper.AK_AkJson_Map_Set(arguments, "parent", eParent)
    reaper.AK_AkJson_Map_Set(arguments, "name", eName)
    reaper.AK_AkJson_Map_Set(arguments, "type", eType)
    reaper.AK_AkJson_Map_Set(arguments, "onNameConflict", eConflicts)
    reaper.AK_AkJson_Map_Set(arguments, "children", childrens)

    local options = reaper.AK_AkJson_Map()
    
    local status, result = Waapi.Call("ak.wwise.core.object.create", arguments, options)
    
    if status then
        sys_gui.AddLog({state = "INFO", desc = "Event Timeline created"})
        return lastPosition + gui.event_length
    else
        local msg = ""
        for _, issue in ipairs(Waapi.issues) do
            msg = msg.." : "..issue
        end
        
        local errorMessage = reaper.AK_AkJson_Map_Get(result, "message")
        local errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)

        sys_gui.AddLog({state = "ERROR", desc = msg.."No timeline created cause of error(s) : " .. errorMessageStr})

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
        local errorMessage = reaper.AK_AkJson_Map_Get(result, "message")
        local errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)
        
        local output = {state = "ERROR", desc = errorMessageStr}
        return output
    end
end

function Waapi.Record()

    local outputMsg = {}
    
    -- Play de l'event timeline
    
    local output = Waapi.PlayEvent(gui.main_event_name)
    table.insert(outputMsg, output)
    if output.state ~= "INFO" then
        return outputMsg
    end
    
    table.insert(outputMsg, {state = "WARNING", desc = "Recording : Please don't stop the event on Wwise"})
    return outputMsg
end

function Waapi.Stop(_outputPath)
    
    local result = reaper.InsertMedia(_outputPath, 1)
    
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

    local outputMsg = {}
    
    Waapi.ClearGameObjects()
    
    local output, masterID = Waapi.GetMasterBusID()
    table.insert(outputMsg, output)
    if output.state ~= "INFO" then
        return outputMsg
    end
    
    local arguments = reaper.AK_AkJson_Map()
    
    local waqlSearch = reaper.AK_AkVariant_String('$ "'..masterID..'"')
    reaper.AK_AkJson_Map_Set(arguments, "waql", waqlSearch)
    
    local fieldsToReturn = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(fieldsToReturn, reaper.AK_AkVariant_String("effects.effect.pluginName"))
    reaper.AK_AkJson_Array_Add(fieldsToReturn, reaper.AK_AkVariant_String("effects.id"))
    
    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fieldsToReturn)

    local status, result = Waapi.Call("ak.wwise.core.object.get", arguments, options)
    
    if status then
        local returnTable = reaper.AK_AkJson_Map_Get(result, "return")
        
        local pluginNameTable = reaper.AK_AkJson_Map_Get(reaper.AK_AkJson_Array_Get(returnTable, 0), "effects.effect.pluginName")
        local pluginIDTable = reaper.AK_AkJson_Map_Get(reaper.AK_AkJson_Array_Get(returnTable, 0), "effects.id")
        
        local pluginNameTableNum = reaper.AK_AkJson_Array_Size(pluginNameTable)
        
        -- Count Recorders
        local recordersIndex = 0
        local recordersID = ""
        for slot = 0, pluginNameTableNum - 1 do
            local effectName = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(pluginNameTable, slot))
            local effectID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(pluginIDTable, slot))
            if effectName == "Wwise Recorder" then
                table.insert(sys_utils.recordersSlots, slot)
            end
        end
        
        for i=1, #sys_utils.recordersSlots do
            recordersIndex = sys_utils.recordersSlots[i]
            recordersID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(pluginIDTable, recordersIndex))
            
            output = Waapi.Remove("Recorder", "Effect", recordersID)
            table.insert(outputMsg, output)
        end
        
    else
        output = {state = "ERROR", desc = "Error on Master effect track cleaning"}
        table.insert(outputMsg, output)
    end
    
    -- $ from type Sound where name = "Timeline SFX Source"
    local arguments = reaper.AK_AkJson_Map()
    
    waqlSearch = reaper.AK_AkVariant_String('$ from type Sound where name = "Timeline SFX Source"')
    reaper.AK_AkJson_Map_Set(arguments, "waql", waqlSearch)
    
    local fieldsToReturn = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(fieldsToReturn, reaper.AK_AkVariant_String("id"))
    
    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fieldsToReturn)
    
    status, result = Waapi.Call("ak.wwise.core.object.get", arguments, options)
    
    if status then
        local returnTable = reaper.AK_AkJson_Map_Get(result, "return")
        
        local id = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(reaper.AK_AkJson_Array_Get(returnTable, 0), "id"))
        
        output = Waapi.Remove("Timeline SFX Source", "Sound", id)
        
        table.insert(outputMsg, output)
    else
        
        table.insert(outputMsg, {state = "ERROR", desc = 'No "Timeline SFX Source" on the wwise project'})
    end
    
    
    output = Waapi.Remove("Play_Linear_Timeline", "Event")
    table.insert(outputMsg, output)
    if output.state ~= "INFO" then
        return outputMsg
    end
    
    return outputMsg
end

function Waapi.ConnectTime()
    local start = reaper.time_precise()
    local start_time = reaper.time_precise()
    reaper.PreventUIRefresh(1)

    local _, logs = Waapi.Connect()
    if (reaper.time_precise() - start_time) >= 0.1 then
        reaper.PreventUIRefresh(-1)
        coroutine.yield(false, i)
        start_time = reaper.time_precise()
        reaper.PreventUIRefresh(1)
    end

    print("\n"..reaper.time_precise() - start)
    reaper.PreventUIRefresh(-1)
    return true, logs
end

function Waapi.Connect()
    local output = {}
    
    local waapiState = reaper.AK_Waapi_Connect("127.0.0.1", 8080)
    
    if waapiState then
        output = {state = "INFO", desc = "Wwise connected"}
        Waapi.connected = true
    else
        output = {state = "ERROR", desc = "Error connecting with Wwise : is project opened ?"}
        Waapi.connected = false
    end
    
    Waapi.InitializeGameObjects()
    
    return Waapi.connected, output
end

function Waapi.Disconnect()
    Waapi.ClearGameObjects()
    reaper.AK_Waapi_Disconnect()
    Waapi.connected = false
end

return Waapi