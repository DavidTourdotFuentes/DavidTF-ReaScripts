--@description david_Wwise timeline cinematic (system)
--@author DavidTF
--@version 0.2
--@changelog Add item color coding based on log message
--@about Main functions systems for cinematic timeline creation

----- SETTINGS -----
result = 0

eventsList = {}
issues = {}

recordersSlots = {}
pluginIDTable = {}
silenceSourceID = 0

-- Preview Settings
detectPrecision = 0.02 --> Range of detection between marker (in seconds) default : 0.02 (20ms)
markerProximityDetector = 3 --> Precision of proximity factor (scale) default : 2 (2 x detectPrecision)
debugAlreadyDetectedMarker = true --> Show console message when marker was detected multiple times
resetCacheTime = 1 -->  Detection of same marker rate in seconds (looping on the marker or playing transport multiple times) default : 1 sec

itemTable = {}
time_start = 0
lastDetectionPos = -1
lastDetectionTime = 0
isPlaying = 0
isLooping = 1
previewLogs = {}

----- FUNCTIONS -----
function WaapiCall(_cmd, _arg, _options)
    local result = reaper.AK_Waapi_Call(_cmd, _arg, _options)
    local status = reaper.AK_AkJson_GetStatus(result)
    
    return status, result
end

function InitializePreview()
    
    time_start = reaper.time_precise()
    lastDetectionPos = -1
    lastDetectionTime = 0
    
    local tracksList = {}
    local track = FindTrackByName("Wwise Timeline")
    if track then
        AddTrackAndChildrenToList(track, tracksList)
        -- Afficher les noms des pistes trouvées pour vérification
        for _, t in ipairs(tracksList) do
            local _, name = reaper.GetTrackName(t)
            
            noteItemCount = reaper.CountTrackMediaItems(t)
            for i=0, noteItemCount - 1 do
                table.insert(itemTable, reaper.GetTrackMediaItem(t, i))
            end
        end
        
        if #itemTable == 0 then
          CreateTextItem(track, 0, 1, "Your event here !")
        end
        
        output = {state = "INFO", desc = "Preview started : Events now play on reaper timeline"}
        return output
    else
        output = {state = "ERROR", desc = "Track 'Wwise Timeline' not found."}
        return output
    end
end

function GetItemInfo(item)
    _, name = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
    pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    vol = reaper.GetMediaItemInfo_Value(item, "D_VOL")
    return pos, name, vol
end

function PreviewLoop()

    local output = {}

    isPlaying = reaper.GetPlayState()
  
    if isPlaying == 1 then
        for i, item in ipairs(itemTable) do
            
            curPos = reaper.GetPlayPosition()
             
            --markerPos, markerName, markerId = GetMarkerInfo(marker)
            itemPos, itemName, itemVol = GetItemInfo(item)
            
            if (curPos >= itemPos - detectPrecision) and (curPos <= itemPos + detectPrecision) then
                if (curPos < lastDetectionPos - (detectPrecision * markerProximityDetector)) or (curPos > lastDetectionPos + (detectPrecision * markerProximityDetector)) then
                    lastDetectionPos = curPos
                    output = OnEvent(itemPos, itemName, itemVol)
                    
                    --reaper.ShowConsoleMsg("\n"..tostring(reaper.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")))
                    
                    if output.state == "ERROR" then
                        reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", 23817199.0)
                    else
                        reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", 0.0)
                    end
                    
                    reaper.UpdateArrange()
                    
                    -- Reset du cache après un certain temps
                    lastDetectionTime = reaper.time_precise()
                else
                    if debugAlreadyDetectedMarker then
                        output = {state = "WARNING", desc = itemName .. " already detected"}
                    end
                end
            end
        end 
        
        if lastDetectionPos > -1 then
            if (reaper.time_precise() - lastDetectionTime) > resetCacheTime then
                lastDetectionPos = -1
                lastDetectionTime = 0
            end
        end
    end
    
    if output then
        return output
    end
end

function OnEvent(itemPos, itemName, itemVol)
    state, result = DetectValueType(itemName)
    
    if state == "" then
        if makerName ~= "" and itemName ~= "" then
            output = WaapiPlayEvent(itemName)
            return output
        end
    end
    if state == "[PLAY]" then
        if result[2] then
            WaapiPlayEvent(result[2])
            return output
        end
    end
    if state == "[STOPALL]" then
        WaapiStopAll()
        return output
    end
    if state == "[RTPC]" then
        if result[2] and result[3] then
            WaapiSetRTPC(result[2], result[3])
            return output
        end
    end
    if state == "[STATE]" then
        if result[2] and result[3] then
            WaapiSetState(result[2], result[3])
            return output
        end
    end
    if state == "[SWITCH]" then
        if result[2] and result[3] then
            WaapiSetSwitch(result[2], result[3])
            return output
        end
    end
    
    return output
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

function WwiseRemove(_name, _type, _id)
    
    local arguments = reaper.AK_AkJson_Map()
    if _id then
        reaper.AK_AkJson_Map_Set(arguments, "object", reaper.AK_AkVariant_String(_id))
    else
        reaper.AK_AkJson_Map_Set(arguments, "object", reaper.AK_AkVariant_String(_type..":".._name))
    end
    
    local options = reaper.AK_AkJson_Map()
    
    status, result = WaapiCall("ak.wwise.core.object.delete", arguments, options)
    
    if status then
        output = {state = "INFO", desc = _type .. ":".. _name .." cleared"}
        return output
    else
        output = {state = "WARNING", desc = "Object ".. _name .. " not found"}
        return output
    end
end

function WaapiCreateSilentSource(_name)
    local arguments = reaper.AK_AkJson_Map()
    
    local source = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(source, "name", reaper.AK_AkVariant_String("Silence"))
    reaper.AK_AkJson_Map_Set(source, "type", reaper.AK_AkVariant_String("SourcePlugin"))
    reaper.AK_AkJson_Map_Set(source, "classId", reaper.AK_AkVariant_Int("6619138"))
    
    local sourceChildrens = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(sourceChildrens, source)
    
    local child = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(child, "type", reaper.AK_AkVariant_String("Sound"))
    reaper.AK_AkJson_Map_Set(child, "name", reaper.AK_AkVariant_String(_name))
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

    status, result = WaapiCall("ak.wwise.core.object.set", arguments, options)
    
    if status then
        returnData = reaper.AK_AkJson_Map_Get(result, "objects")
        obj = reaper.AK_AkJson_Array_Get(returnData, 0)
        objChild = reaper.AK_AkJson_Array_Get(reaper.AK_AkJson_Map_Get(obj, "children"), 0)
        objChildID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(objChild, "id"))
        
        output = {state = "INFO", desc = "Silent sfx created"}
        return output, objChildID
    else
        errorMessage = reaper.AK_AkJson_Map_Get(result, "message")
        errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)
        
        output = {state = "ERROR", desc = errorMessageStr}
        return output, ""
    end

end

function WaapiGetMasterBusID()
    masterID = false
    
    local arguments = reaper.AK_AkJson_Map()
    
    waqlSearch = reaper.AK_AkVariant_String('$ "Bus:Master Audio Bus"')
    reaper.AK_AkJson_Map_Set(arguments, "waql", waqlSearch)
    
    local fieldsToReturn = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(fieldsToReturn, reaper.AK_AkVariant_String("id"))
    
    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fieldsToReturn)

    status, result = WaapiCall("ak.wwise.core.object.get", arguments, options)

    local output = {}
    if status then
        returnData = reaper.AK_AkJson_Map_Get(result, "return")
        if reaper.AK_AkJson_Array_Size(returnData) == 1 then
            obj = reaper.AK_AkJson_Array_Get(returnData, 0)
            masterID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(obj, "id"))
            output = {state = "INFO", desc = '"Master Audio Bus" found'}
        end
   
        if masterID == false then
            output = {state = "ERROR", desc = 'No "Master Audio Bus" on this session'}
        end
    else
        errorMessage = reaper.AK_AkJson_Map_Get(result, "message")
        errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)

        output = {state = "ERROR", desc = "Error on Master Audio Bus : " .. errorMessageStr}
    end
    
    return output, masterID
end

function WaapiAddRecorder(_masterID, _outputPath, _stereoDownmix, _slot)
    local arguments = reaper.AK_AkJson_Map()
    
    local effect = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(effect, "type", reaper.AK_AkVariant_String("Effect"))
    reaper.AK_AkJson_Map_Set(effect, "name", reaper.AK_AkVariant_String("Wwise Recorder"))
    reaper.AK_AkJson_Map_Set(effect, "classId", reaper.AK_AkVariant_Int(8650755))
    reaper.AK_AkJson_Map_Set(effect, "@AuthoringFilename", reaper.AK_AkVariant_String(_outputPath))
    reaper.AK_AkJson_Map_Set(effect, "@DownmixToStereo", reaper.AK_AkVariant_Bool(_stereoDownmix))
    
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
    
    status, result = WaapiCall("ak.wwise.core.object.set", arguments, options)
    
    if not status then
        errorMessage = reaper.AK_AkJson_Map_Get(result, "message")
        errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)
        
        output = {state = "ERROR", desc = "Error on adding recorder : " .. errorMessageStr}
        return output
    else
        
        output = {state = "INFO", desc = "Recorder added slot " .. _slot}
        return output
    end
end

function WaapiCleanMasterEffectRack(_masterID, _outputPath, _stereoDownmix)
    
    local arguments = reaper.AK_AkJson_Map()
    
    waqlSearch = reaper.AK_AkVariant_String('$ "'.._masterID..'"')
    reaper.AK_AkJson_Map_Set(arguments, "waql", waqlSearch)
    
    local fieldsToReturn = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(fieldsToReturn, reaper.AK_AkVariant_String("effects.effect.pluginName"))
    reaper.AK_AkJson_Array_Add(fieldsToReturn, reaper.AK_AkVariant_String("effects.id"))
    
    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fieldsToReturn)

    status, result = WaapiCall("ak.wwise.core.object.get", arguments, options)
    
    if status then
        local returnTable = reaper.AK_AkJson_Map_Get(result, "return")
        
        pluginNameTable = reaper.AK_AkJson_Map_Get(reaper.AK_AkJson_Array_Get(returnTable, 0), "effects.effect.pluginName")
        pluginIDTable = reaper.AK_AkJson_Map_Get(reaper.AK_AkJson_Array_Get(returnTable, 0), "effects.id")
        
        pluginNameTableNum = reaper.AK_AkJson_Array_Size(pluginNameTable)
        
        -- Count Recorders
        recordersIndex = 0
        recordersID = ""
        for slot = 0, pluginNameTableNum - 1 do
            effectName = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(pluginNameTable, slot))
            effectID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(pluginIDTable, slot))
            if effectName == "Wwise Recorder" then
                table.insert(recordersSlots, slot)
            end
        end
        
        if #recordersSlots >= 1 then
            local outputMsg = {}
            for i=1, #recordersSlots do
                recordersIndex = recordersSlots[i]
                recordersID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(pluginIDTable, recordersIndex))
                
                output = WwiseRemove("Recorder", "Effect", recordersID)
            end
            
            local output = WaapiAddRecorder(_masterID, _outputPath, _stereoDownmix, pluginNameTableNum - 1)
            table.insert(outputMsg, output)
            
            return outputMsg, recordersIndex
        else
            local outputMsg = {}
            local output = WaapiAddRecorder(_masterID, _outputPath, _stereoDownmix, pluginNameTableNum)
            table.insert(outputMsg, output)
            
            recordersIndex = pluginNameTableNum
            recordersID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(pluginIDTable, recordersIndex - 1))
            
            return outputMsg, recordersIndex
        end
    else
        local outputMsg = {}
        output = {state = "ERROR", desc = "Error on Master effect track cleaning"}
        table.insert(outputMsg, output)
        
        return outputMsg, -1
    end
end

function WaapiRecorderActionByPass(_name, _masterID, _slot, _bypass, _position)

    child = reaper.AK_AkJson_Map()
    
    reaper.AK_AkJson_Map_Set(child, "name", reaper.AK_AkVariant_String(_name))
    reaper.AK_AkJson_Map_Set(child, "type", reaper.AK_AkVariant_String("Action"))
    reaper.AK_AkJson_Map_Set(child, "@ActionType", reaper.AK_AkVariant_Int(50))
    reaper.AK_AkJson_Map_Set(child, "@Target", reaper.AK_AkVariant_String(_masterID))
    reaper.AK_AkJson_Map_Set(child, "@Delay", reaper.AK_AkVariant_Double(_position))
    reaper.AK_AkJson_Map_Set(child, "@BypassFlag", reaper.AK_AkVariant_Bool(_bypass))
    reaper.AK_AkJson_Map_Set(child, "@EffectSlot", reaper.AK_AkVariant_Int(_slot))
    
    return child
end

function GetObjectID(_objType, _name)

    local arguments = reaper.AK_AkJson_Map()
    
    waqlSearch = reaper.AK_AkVariant_String('$ "'.._objType..'" select descendants where name = "'.._name..'"')
    reaper.AK_AkJson_Map_Set(arguments, "waql", waqlSearch)
    
    local options = reaper.AK_AkJson_Map()

    status, result  = WaapiCall("ak.wwise.core.object.get", arguments, options)
    
    if status then
        returnData = reaper.AK_AkJson_Map_Get(result, "return")
        if reaper.AK_AkJson_Array_Size(returnData) == 1 then
            first = reaper.AK_AkJson_Array_Get(returnData, 0)
            id = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(first, "id"))
            
            output = {state = "INFO", desc = "ID get"}
            return output, id
        else
            if reaper.AK_AkJson_Array_Size(returnData) == 0 then
                output = {state = "ERROR", desc = "Object '".._name.."' not found"}
                return output, 0
            end
            if reaper.AK_AkJson_Array_Size(returnData) > 1 then
                first = reaper.AK_AkJson_Array_Get(returnData, 0)
                id = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(first, "id"))
                output = {state = "ERROR", desc = "'".._name.."' more than once in Wwise project (check PostEvent reference to fix occasional bugs)"}
                return output, id
            end
        end
    else
        errorMessage = reaper.AK_AkJson_Map_Get(result, "message")
        errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)
        output = {state = "ERROR", desc = "Error on Get ".. _name .." ID : " .. errorMessageStr}
        return output, 0
    end
end

function DetectValueType(_text)
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


function MapChildContent(_name, _actionType, _target, _delay, _parameterValue, _bypass, _bypassValue)
    
    child = reaper.AK_AkJson_Map()
    
    reaper.AK_AkJson_Map_Set(child, "name", reaper.AK_AkVariant_String(_name..math.random(0, 10000000)))
    reaper.AK_AkJson_Map_Set(child, "type", reaper.AK_AkVariant_String("Action"))
    reaper.AK_AkJson_Map_Set(child, "@ActionType", reaper.AK_AkVariant_Int(_actionType))
    reaper.AK_AkJson_Map_Set(child, "@Target", reaper.AK_AkVariant_String(_target))
    reaper.AK_AkJson_Map_Set(child, "@Delay", reaper.AK_AkVariant_Double(_delay))
    
    if _parameterValue then
        reaper.AK_AkJson_Map_Set(child, "@GameParameterValue", reaper.AK_AkVariant_Double(tonumber(words[3])))
    end
    if _bypass then
        reaper.AK_AkJson_Map_Set(child, "@Bypass", reaper.AK_AkVariant_Bool(_bypassValue))
    end

    return child
end

function GenerateEventContent(_id, _name, _eventPosition)
    currChild = reaper.AK_AkJson_Map()
 
    state, words = DetectValueType(_name)
    
    if state == "" then
        output, targetID = GetObjectID("Events", _name)
        if output.state ~= "INFO" then
            return output, currChild
        end
        
        currChild = MapChildContent(words[1], 41, targetID, _eventPosition)
    end
    
    if state == "[PLAY]" then
        output, targetID = GetObjectID("Events", words[2])
        if output.state ~= "INFO" then
            return output, currChild
        end
        
        currChild = MapChildContent(words[2], 41, targetID, _eventPosition)
    end
    
    if state == "[STOPALL]" then
        output, targetID = GetObjectID("Events", _name)
        if output.state ~= "INFO" then
            return output, currChild
        end
        
        currChild = MapChildContent(words[1], 3, targetID, _eventPosition)
    end
    
    if state == "[RTPC]" then
        output, targetID = GetObjectID("Game Parameters", words[2])
        if output.state ~= "INFO" then
            return output, currChild
        end
        
        currChild = MapChildContent(words[2], 38, targetID, _eventPosition, tonumber(words[3]))
    end
    
    if state == "[STATE]" then
        output, targetID = GetObjectID("States", words[3])
        if output.state ~= "INFO" then
            return output, currChild
        end
        
        currChild = MapChildContent(words[2].."_".._id, 22, targetID, _eventPosition)
    end
    
    if state == "[SWITCH]" then
        output, targetID = GetObjectID("Switches", words[3])
        if output.state ~= "INFO" then
            return output, currChild
        end
        
        currChild = MapChildContent(words[2].."_".._id, 23, targetID, _eventPosition)
    end
    
    output = {state = "INFO", desc = "Event content sucessfully created !"}
    return output, currChild

end

function ShowTooltip(_text)
    local x, y = reaper.GetMousePosition()
    reaper.TrackCtl_SetToolTip(_text, x, y, true) -- spaced out // topmost true
end

function FindTrackByName(_name)
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

function AddTrackAndChildrenToList(_track, _trackList)
    table.insert(_trackList, _track)
    local trackID = reaper.GetMediaTrackInfo_Value(_track, "IP_TRACKNUMBER") - 1
    local depth = reaper.GetTrackDepth(_track)
    local numTracks = reaper.CountTracks(0)
    for i = trackID + 1, numTracks - 1 do
        local childTrack = reaper.GetTrack(0, i)
        if reaper.GetTrackDepth(childTrack) <= depth then
            break
        end
        table.insert(_trackList, childTrack)
    end
end

function CreateTimelineEvent(_eventName, _outputPath, _lastEventLenght, _stereoDownmix)

    outputMsg = {}
    
    eventsList = {}

    -- LOOP ON EACH ITEMS TO CREATE CHILD EVENTS IN CHILDRENS ARRAY
    childrens = reaper.AK_AkJson_Array()
    
    local tracksList = {}
    local track = FindTrackByName("Wwise Timeline")
    if track then
        AddTrackAndChildrenToList(track, tracksList)
        i = 0
        for _, t in ipairs(tracksList) do
            local _, name = reaper.GetTrackName(t)
            
            noteItemCount = reaper.CountTrackMediaItems(t)
            for j=0, noteItemCount - 1 do
                currItem = reaper.GetTrackMediaItem(t, j)
                text = reaper.ULT_GetMediaItemNote(currItem)
                pos = reaper.GetMediaItemInfo_Value(currItem, "D_POSITION")
                
                table.insert(eventsList, {id = i..j, item = currItem, text = text, position = pos})
            end
            i = i + 1
        end
    else
        table.insert(outputMsg, {state = "ERROR", desc = "Track 'Wwise Timeline' not found."})
        return outputMsg, 0
    end
    
    -- TRI DE LA LISTE PAR ORDRE D'APPARITION
    table.sort(eventsList, function(a, b)
        return a.position < b.position
    end)
    
    -- MasterTrack Recorder
    output, masterID = WaapiGetMasterBusID()
    table.insert(outputMsg, output)
    if output.state ~= "INFO" then
         return outputMsg, 0
    end
    
    outputTable, recorderSlot = WaapiCleanMasterEffectRack(masterID, _outputPath, _stereoDownmix)
    for i=1, #outputTable do
        table.insert(outputMsg, outputTable[i])
    
        if outputTable[i].state == "ERROR" then
             return outputMsg, 0
        end
    end

    -- Create Silent SFX
    output, silenceSourceID = WaapiCreateSilentSource("Timeline SFX Source")
    table.insert(outputMsg, output)
    if output.state ~= "INFO" then
         return outputMsg, 0
    end
    
    -- Add Recorder ByPass OFF Action
    reaper.AK_AkJson_Array_Add(childrens, WaapiRecorderActionByPass("Enable Recorder", masterID, recorderSlot, false, 0))
    
    -- Add Play Silent Source Action
    silentPlay = MapChildContent("Play silent object", 1, silenceSourceID, 0)
    reaper.AK_AkJson_Array_Add(childrens, silentPlay)
    
    lastPosition = 0
    -- BOUCLER SUR TOUS LES EVENEMENTS
    for _, event in ipairs(eventsList) do
    
        output, child = GenerateEventContent(event.id, event.text, event.position)
        if output.state ~= "INFO" then
            table.insert(outputMsg, output)
        end
        
        reaper.AK_AkJson_Array_Add(childrens, child)
        
        lastPosition = event.position
    end
    
    -- Add Recorder ByPass ON Action
    reaper.AK_AkJson_Array_Add(childrens, WaapiRecorderActionByPass("Disable Recorder", masterID, recorderSlot, true, lastPosition + _lastEventLenght))
    
    -- Add Stop Silent Source Action
    silentStop = MapChildContent("Stop silent object", 3, silenceContent, lastPosition + _lastEventLenght)
    reaper.AK_AkJson_Array_Add(childrens, silentStop)
    
    -- CREATION DE L'OBJET TIMELINE
    local eParent = reaper.AK_AkVariant_String("\\Events\\Default Work Unit")
    local eName = reaper.AK_AkVariant_String(_eventName)
    local eType = reaper.AK_AkVariant_String("Event")
    local eConflicts = reaper.AK_AkVariant_String("replace")
    
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "parent", eParent)
    reaper.AK_AkJson_Map_Set(arguments, "name", eName)
    reaper.AK_AkJson_Map_Set(arguments, "type", eType)
    reaper.AK_AkJson_Map_Set(arguments, "onNameConflict", eConflicts)
    reaper.AK_AkJson_Map_Set(arguments, "children", childrens)
    
    local options = reaper.AK_AkJson_Map()
     
    status, result = WaapiCall("ak.wwise.core.object.create", arguments, options)
    
    if status then 
        table.insert(outputMsg, {state = "INFO", desc = "Event Timeline created"})
        return outputMsg, lastPosition + _lastEventLenght
    else
    
        msg = ""
        for _, issue in ipairs(issues) do
            msg = msg.." : "..issue
        end
        
        errorMessage = reaper.AK_AkJson_Map_Get(result, "message")
        errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)
        
        table.insert(outputMsg, {state = "ERROR", desc = msg.."No timeline created cause of error(s) : " .. errorMessageStr})
        return outputMsg, 0
    end
end


function WaapiInitializeGameObjects()

    -- Register Listener Game Object 
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", reaper.AK_AkVariant_Int(1))
    reaper.AK_AkJson_Map_Set(arguments, "name", reaper.AK_AkVariant_String("Reaper Listener"))
     
    local options = reaper.AK_AkJson_Map()
     
    WaapiCall("ak.soundengine.registerGameObj", arguments, options)
     
    -- Register Emitter Game Object
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", reaper.AK_AkVariant_Int(2))
    reaper.AK_AkJson_Map_Set(arguments, "name", reaper.AK_AkVariant_String("Reaper Emitter"))
    
    local options = reaper.AK_AkJson_Map()
     
    WaapiCall("ak.soundengine.registerGameObj", arguments, options)
    
    -- Set Listener
    local listeners = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(listeners, reaper.AK_AkVariant_Int(1))
     
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "emitter", reaper.AK_AkVariant_Int(2))
    reaper.AK_AkJson_Map_Set(arguments, "listeners", listeners)
     
    local options = reaper.AK_AkJson_Map()
   
    WaapiCall("ak.soundengine.setListeners", arguments, options)
end

function WaapiClearGameObjects()
    -- Stop all remaining sounds on gameObject 2 (emmiter)
    local id = reaper.AK_AkVariant_Int(2)
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", id)
    
    local options = reaper.AK_AkJson_Map()
    
    WaapiCall("ak.soundengine.stopAll", arguments, options)

    -- Unregister Game Object 1 (listener)
    local id = reaper.AK_AkVariant_Int(1)
    
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", id)
    
    local options = reaper.AK_AkJson_Map()
     
    WaapiCall("ak.soundengine.unregisterGameObj", arguments, options)
    
    -- Unregister Game Object 2 (emmiter)
    local id = reaper.AK_AkVariant_Int(2)
    
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", id)
    
    local options = reaper.AK_AkJson_Map()
     
    WaapiCall("ak.soundengine.unregisterGameObj", arguments, options)
end

function WaapiPlayEvent(_eventName)
    
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "event", reaper.AK_AkVariant_String(_eventName))
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", reaper.AK_AkVariant_Int(2))
    
    local options = reaper.AK_AkJson_Map()

    status, result = WaapiCall("ak.soundengine.postEvent", arguments, options)
    
    if status then
        output = {state = "INFO", desc = "Timeline event played"}
        return output
    else
        errorMessage = reaper.AK_AkJson_Map_Get(result, "message")
        errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)
        
        output = {state = "ERROR", desc = errorMessageStr}
        return output
    end
end


function Record(_eventName)

    outputMsg = {}
    
    -- Play de l'event timeline
    
    output = WaapiPlayEvent(_eventName)
    table.insert(outputMsg, output)
    if output.state ~= "INFO" then
        return outputMsg
    end
    
    table.insert(outputMsg, {state = "WARNING", desc = "Recording : Please don't stop the event on Wwise"})
    return outputMsg

end

function Stop(_outputPath)
    
    local result = reaper.InsertMedia(_outputPath, 1)
    
    -- Move created track on top of the project
    reaper.ReorderSelectedTracks(0, 0)
    
    -- Move timeline item to start at 0s
    item = reaper.GetSelectedMediaItem(0, 0)
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", 0)
    
    
    output = 0
    if result == 1 then 
        output = {state = "INFO", desc = "Audio imported on reaper"}
    else
        output = {state = "ERROR", desc = "Audio failed to import on reaper"}  
    end
    
    return output
end

function ConnectToWwise()
    output = {}
    
    waapiState = reaper.AK_Waapi_Connect("127.0.0.1", 8080)
    
    if waapiState then
        output = {state = "INFO", desc = "Wwise connected"}
    else
        output = {state = "ERROR", desc = "Error connecting with Wwise : is project opened ?"}
    end
    
    WaapiInitializeGameObjects()
    
    return output
end

function CleanWwiseSession()

    outputMsg = {}
    
    WaapiClearGameObjects()
    
    output, masterID = WaapiGetMasterBusID()
    table.insert(outputMsg, output)
    if output.state ~= "INFO" then
        return outputMsg
    end
    
    local arguments = reaper.AK_AkJson_Map()
    
    waqlSearch = reaper.AK_AkVariant_String('$ "'..masterID..'"')
    reaper.AK_AkJson_Map_Set(arguments, "waql", waqlSearch)
    
    local fieldsToReturn = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(fieldsToReturn, reaper.AK_AkVariant_String("effects.effect.pluginName"))
    reaper.AK_AkJson_Array_Add(fieldsToReturn, reaper.AK_AkVariant_String("effects.id"))
    
    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fieldsToReturn)

    status, result = WaapiCall("ak.wwise.core.object.get", arguments, options)
    
    if status then
        local returnTable = reaper.AK_AkJson_Map_Get(result, "return")
        
        pluginNameTable = reaper.AK_AkJson_Map_Get(reaper.AK_AkJson_Array_Get(returnTable, 0), "effects.effect.pluginName")
        pluginIDTable = reaper.AK_AkJson_Map_Get(reaper.AK_AkJson_Array_Get(returnTable, 0), "effects.id")
        
        pluginNameTableNum = reaper.AK_AkJson_Array_Size(pluginNameTable)
        
        -- Count Recorders
        recordersIndex = 0
        recordersID = ""
        for slot = 0, pluginNameTableNum - 1 do
            effectName = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(pluginNameTable, slot))
            effectID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(pluginIDTable, slot))
            if effectName == "Wwise Recorder" then
                table.insert(recordersSlots, slot)
            end
        end
        
        for i=1, #recordersSlots do
            recordersIndex = recordersSlots[i]
            recordersID = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Array_Get(pluginIDTable, recordersIndex))
            
            output = WwiseRemove("Recorder", "Effect", recordersID)
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
    
    status, result = WaapiCall("ak.wwise.core.object.get", arguments, options)
    
    if status then
        local returnTable = reaper.AK_AkJson_Map_Get(result, "return")
        
        id = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(reaper.AK_AkJson_Array_Get(returnTable, 0), "id"))
        
        output = WwiseRemove("Timeline SFX Source", "Sound", id)
        
        table.insert(outputMsg, output)
    else
        
        table.insert(outputMsg, {state = "ERROR", desc = 'No "Timeline SFX Source" on the wwise project'})
    end
    
    
    output = WwiseRemove("Play_Linear_Timeline", "Event")
    table.insert(outputMsg, output)
    if output.state ~= "INFO" then
        return outputMsg
    end
    
    return outputMsg
end

function DisconnectToWwise()
    WaapiClearGameObjects()
    waapiState = reaper.AK_Waapi_Disconnect()
end

return
{
    ConnectToWwise = ConnectToWwise,
    DisconnectToWwise = DisconnectToWwise,
    InitializePreview = InitializePreview,
    PreviewLoop = PreviewLoop,
    PreviewLogs = PreviewLogs,
    CreateTextItem = CreateTextItem,
    WwiseRemove = WwiseRemove,
    CreateTimelineEvent = CreateTimelineEvent,
    Record = Record,
    Stop = Stop,
    CleanWwiseSession = CleanWwiseSession
}
