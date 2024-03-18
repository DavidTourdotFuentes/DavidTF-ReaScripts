--- THIS SCRIPT NEED ReaWwise https://github.com/Audiokinetic/Reaper-Tools/raw/main/index.xml ---
--reaper.ShowMessageBox('No ReaWwise package found !\nPlease install it with the followed link :\nhttps://github.com/Audiokinetic/Reaper-Tools/raw/main/index.xml', 'Error !',0)
--- SETTINGS ---
detectPrecision = 0.02 --> Range of detection between marker (in seconds) default : 0.02 (20ms)
markerProximityDetector = 2 --> Precision of proximity factor (scale) default : 2 (2 x detectPrecision)
debugAlreadyDetectedMarker = false --> Show console message when marker was detected multiple times
debugWaapiEventState = false --> Show console message when event was triggered
resetCacheTime = 1 -->  Detection of same marker rate in seconds (looping on the marker or playing transport multiple times) default : 1 sec

--- SYSTEM VARIABLES ---
scriptName = "david_Toggle Play Wwise event based on trigger marker name"
markerTable = {}
isLooping = 1
isPlaying = 0
waapiState = false

--- FUNCTIONS ---

function WaapiInitializeObjects()

    -- Register Listener Game Object
    local id = reaper.AK_AkVariant_Int(1)
    local name = reaper.AK_AkVariant_String("Reaper Listener")
    
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", id)
    reaper.AK_AkJson_Map_Set(arguments, "name",name)
     
    local options = reaper.AK_AkJson_Map()
     
    WaapiCall("ak.soundengine.registerGameObj", arguments, options)
     
     
    -- Register Emitter Game Object
    local id = reaper.AK_AkVariant_Int(2)
    local name = reaper.AK_AkVariant_String("Reaper Emitter")
  
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", id)
    reaper.AK_AkJson_Map_Set(arguments, "name", name)
    
    local options = reaper.AK_AkJson_Map()
     
    WaapiCall("ak.soundengine.registerGameObj", arguments, options)
    
    -- Set Listener
    local emitter = reaper.AK_AkVariant_Int(2)
    local listeners = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(listeners, reaper.AK_AkVariant_Int(1))
     
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "emitter", emitter)
    reaper.AK_AkJson_Map_Set(arguments, "listeners", listeners)
     
    local options = reaper.AK_AkJson_Map()
   
    WaapiCall("ak.soundengine.setListeners", arguments, options)
end

function WaapiClearObjects()
    -- Unregister Game Object
    local id = reaper.AK_AkVariant_Int(1)
    
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", id)
    
    local options = reaper.AK_AkJson_Map()
     
    WaapiCall("ak.soundengine.unregisterGameObj", arguments, options)
    
    -- Unregister Game Object
    local id = reaper.AK_AkVariant_Int(2)
    
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", id)
    
    local options = reaper.AK_AkJson_Map()
     
    WaapiCall("ak.soundengine.unregisterGameObj", arguments, options)
    
    
    -- Unregister Game Object
    local id = reaper.AK_AkVariant_Int(3333)
    
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", id)
    
    local options = reaper.AK_AkJson_Map()
     
    WaapiCall("ak.soundengine.unregisterGameObj", arguments, options)
    
    
    -- Unregister Game Object
    local id = reaper.AK_AkVariant_Int(4444)
    
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "gameObject", id)
    
    local options = reaper.AK_AkJson_Map()
     
    WaapiCall("ak.soundengine.unregisterGameObj", arguments, options)
end

function WaapiPlayEvent(eventName)

    if waapiState then
        
        -- Play Event
        local event = reaper.AK_AkVariant_String(eventName)
        local gameObject = reaper.AK_AkVariant_Int(2)
 
        local arguments = reaper.AK_AkJson_Map()
        reaper.AK_AkJson_Map_Set(arguments, "event", event)
        reaper.AK_AkJson_Map_Set(arguments, "gameObject", gameObject)
        
        local options = reaper.AK_AkJson_Map()
        
        if not WaapiCall("ak.soundengine.postEvent", arguments, options) then
            reaper.ShowMessageBox("Incorrect marker event name", "Error !", 0)
        end
    end
end

function WaapiCall(cmd, arg, options)
    local result = reaper.AK_Waapi_Call(cmd, arg, options)
    local status = reaper.AK_AkJson_GetStatus(result)
    
    return status
end

function StartLoop()
    
    currentScriptState = reaper.GetExtState(scriptName,"state")
    
    if (StrToBool(currentScriptState) == true) or (StrToBool(currentScriptState) == nil) then
        reaper.SetExtState(scriptName,"state", "false", true)
        Stop()
        
        ShowTooltip(scriptName.."\n".."STOPPED DETECTION")
    else
        waapiState = reaper.AK_Waapi_Connect("127.0.0.1", 8080)
        
        if waapiState then
        
            reaper.SetExtState(scriptName,"state", "true", true)
            
            WaapiInitializeObjects()
            
            time_start = reaper.time_precise()
            lastDetectionPos = -1
            lastDetectionTime = 0
            reaper.ClearConsole()
            InitMarkerTable()
            Loop()
            
            ShowTooltip(scriptName.."\n".."STARTED DETECTION")
        else
            reaper.ShowMessageBox("Please open a Wwise project", "Error !", 0)
        end
    end
end

-- Stop loop detection
function Stop()
    isLooping = 0
    
    WaapiClearObjects()
    
    reaper.AK_AkJson_ClearAll()
    reaper.AK_Waapi_Disconnect()
end

-- Convert true and false string to boolean
function StrToBool(str)
    if str == nil then
        return false
    end
    return string.lower(str) == 'true'
end

-- Initialize marker list
function InitMarkerTable()
    for i=0, reaper.CountProjectMarkers(0) do
        if IsMarker(i) then
            table.insert(markerTable, i)
        end
    end
end

function IsMarker(markerOrRegionID)
   _, isRegion, _, _, _ , _, _ = reaper.EnumProjectMarkers3(0, markerOrRegionID)
   return not isRegion
end

-- Get marker informations (position, name and id)
function GetMarkerInfo(markerId)
   _, _, pos, _, name, id, _ = reaper.EnumProjectMarkers3(0, markerId)
   return pos, name, id
end

-- Detection loop
function Loop()
    isPlaying = reaper.GetPlayState()
  
    if isPlaying == 1 then
        for i, marker in ipairs(markerTable) do
            curPos = reaper.GetPlayPosition()
            markerPos, markerName, markerId = GetMarkerInfo(marker)
            
            if (curPos >= markerPos - detectPrecision) and (curPos <= markerPos + detectPrecision) then
                if (curPos < lastDetectionPos - (detectPrecision * markerProximityDetector)) or (curPos > lastDetectionPos + (detectPrecision * markerProximityDetector)) then
                    lastDetectionPos = curPos
                    OnMarker(markerId, markerName, i)
                
                    -- Reset du cache après un certain temps
                    lastDetectionTime = reaper.time_precise()
                else
                    if debugAlreadyDetectedMarker then
                        reaper.ShowConsoleMsg("\nAlready detected !")
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
    
    if reaper.GetExtState(scriptName,"state") == "true" then
        reaper.defer(Loop)
    end
end

-- Marker event detection
function OnMarker(markerId, markerName, markerOrder)
    -- Here your events when cursor cross the marker
    -- markerId : Marker ID number
    -- markerName : Name of the marker (if marker had a name)
    -- markerOrder : Relative position order of the marker

    if makerName ~= "" then
        WaapiPlayEvent(markerName)
        
        if debugWaapiEventState then
            statusText = "\n" .. markerName
            reaper.ShowConsoleMsg(statusText)
        end
    end
end

function ShowTooltip(text)
    local x, y = reaper.GetMousePosition()
    reaper.TrackCtl_SetToolTip(text, x, y, true) -- spaced out // topmost true
end


--- MAIN ---
StartLoop()
