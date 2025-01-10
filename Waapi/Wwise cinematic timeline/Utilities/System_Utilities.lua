-- @noindex

local SysUtils = {}

----- SETTINGS -----
local result = 0

local eventsList = {}

SysUtils.recordersSlots = {}
local pluginIDTable = {}
local silenceSourceID = 0

-- Preview Settings
local detectPrecision = 0.02 --> Range of detection between marker (in seconds) default : 0.02 (20ms)
local markerProximityDetector = 3 --> Precision of proximity factor (scale) default : 2 (2 x detectPrecision)
local debugAlreadyDetectedMarker = true --> Show console message when marker was detected multiple times
local resetCacheTime = 1 -->  Detection of same marker rate in seconds (looping on the marker or playing transport multiple times) default : 1 sec

local itemTable = {}
local time_start = 0
SysUtils.lastDetectionPos = -1
SysUtils.lastDetectionTime = 0
local isPlaying = 0
local isLooping = 1
local previewLogs = {}


function SysUtils.InitializePreview()
    
    time_start = reaper.time_precise()
    SysUtils.lastDetectionPos = -1
    SysUtils.lastDetectionTime = 0
    
    local tracksList = {}
    local track = SysUtils.FindTrackByName("Wwise Timeline")
    if track then
        SysUtils.AddTrackAndChildrenToList(track, tracksList)
        -- Afficher les noms des pistes trouvées pour vérification
        for _, t in ipairs(tracksList) do
            local _, name = reaper.GetTrackName(t)
            
            local noteItemCount = reaper.CountTrackMediaItems(t)
            for i=0, noteItemCount - 1 do
                table.insert(itemTable, reaper.GetTrackMediaItem(t, i))
            end
        end
        
        if #itemTable == 0 then
            SysUtils.CreateTextItem(track, 0, 1, "Your event here !")
        end
        
        local output = {state = "INFO", desc = "Preview started : Events now play on reaper timeline"}
        return output
    else
        local output = {state = "ERROR", desc = "Track 'Wwise Timeline' not found."}
        return output
    end
end

function SysUtils.PreviewLoop()

    local output = {}
    local isPlaying = reaper.GetPlayState()
  
    if isPlaying == 1 then
        for i, item in ipairs(itemTable) do
            
            local curPos = reaper.GetPlayPosition()
            
            local itemPos, itemName, itemVol =  SysUtils.GetItemInfo(item)
            
            if (curPos >= itemPos - detectPrecision) and (curPos <= itemPos + detectPrecision) then

                if (curPos < SysUtils.lastDetectionPos - (detectPrecision * markerProximityDetector)) or (curPos > SysUtils.lastDetectionPos + (detectPrecision * markerProximityDetector)) then
                    SysUtils.lastDetectionPos = curPos
                    output = SysUtils.OnEvent(itemName)
                    
                    if output.state == "ERROR" then
                        reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", 23817199.0)
                    else
                        reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", 0.0)
                    end
                    
                    reaper.UpdateArrange()
                    
                    -- Reset du cache après un certain temps
                    SysUtils.lastDetectionTime = reaper.time_precise()
                else
                    if debugAlreadyDetectedMarker then
                        output = {state = "WARNING", desc = itemName .. " already detected"}
                    end
                end
            end
        end
        
        if SysUtils.lastDetectionPos > -1 then
            if (reaper.time_precise() - SysUtils.lastDetectionTime) > resetCacheTime then
                SysUtils.lastDetectionPos = -1
                SysUtils.lastDetectionTime = 0
            end
        end
    end

    return output
end

function SysUtils.OnEvent(itemName)
    local state, result = SysUtils.DetectValueType(itemName)
    
    if state == "" then
        if itemName ~= "" then
            local output = sys_waapi.PlayEvent(itemName)
            return output
        end
    end
    if state == "[PLAY]" then
        if result[2] then
            sys_waapi.PlayEvent(result[2])
            return output
        end
    end
    if state == "[STOPALL]" then
        sys_waapi.StopAll()
        return output
    end
    if state == "[RTPC]" then
        if result[2] and result[3] then
            sys_waapi.SetRTPC(result[2], result[3])
            return output
        end
    end
    if state == "[STATE]" then
        if result[2] and result[3] then
            sys_waapi.SetState(result[2], result[3])
            return output
        end
    end
    if state == "[SWITCH]" then
        if result[2] and result[3] then
            sys_waapi.SetSwitch(result[2], result[3])
            return output
        end
    end
    
    return output
end

function SysUtils.CreateItemAtCursor(length, text)
    local track = SysUtils.FindTrackByName("Wwise Timeline")

    if track then
        local cursorPos = reaper.GetCursorPosition()
        CreateTextItem(track, cursorPos, 1, "Event name")
    end
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

function SysUtils.FindTrackByName(_name)
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

function SysUtils.AddTrackAndChildrenToList(_track, _trackList)
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

function SysUtils.GetAppDataPath()
    -- Utiliser os.getenv pour obtenir la variable d'environnement APPDATA
    local appDataPath = os.getenv("APPDATA")
    return appDataPath
end

function SysUtils.GetItemInfo(item)
    local _, name = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local vol = reaper.GetMediaItemInfo_Value(item, "D_VOL")
    return pos, name, vol
end

-- Fonction pour vérifier l'existence d'un fichier
function SysUtils.FileExists(filePath)
    local file = io.open(filePath, "r")
    if file then
        file:close()
        return true
    else
        return false
    end
end

function SysUtils.DetectValueType(_text)
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

return SysUtils