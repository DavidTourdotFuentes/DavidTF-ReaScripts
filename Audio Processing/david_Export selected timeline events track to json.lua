--@description Exports selected timeline events track to json
--@author david
--@version 1.0
--@changelog
--  Initial commit
--@about
--  Select a timeline track and export all wwise event data to json file

itemTable = {}
renderedObjects = {}

function InitItemTable()
    timelineTrack = reaper.GetSelectedTrack(0, 0)
    noteItemCount = reaper.CountTrackMediaItems(timelineTrack)
    for i=0, noteItemCount - 1 do
        tempPos, tempName, tempVol = GetItemInfo(reaper.GetTrackMediaItem(timelineTrack, i))
        AddObject(tempName, tempPos, tempVol)
    end
    
    WriteIndExportFile()
end

function GetItemInfo(item)
    _, name = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
    pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    vol = reaper.GetMediaItemInfo_Value(item, "D_VOL")
    return pos, name, vol
end

function AddObject(event, position, volume)
    newObject = { event = event, position = position, volume = volume}
    table.insert(renderedObjects, newObject)
end

function WriteIndExportFile()
    -- Conversion de la liste d'objets en format JSON
    
    -- Écriture des données JSON dans un fichier
    local file = io.open("C:\\Users\\david\\Desktop\\export.json", "w")
    if file then
        file:write(TableToJson(renderedObjects))
        file:close()
        reaper.ShowConsoleMsg("Données JSON écrites dans le fichier.")
    else
        reaper.ShowConsoleMsg("Erreur lors de l'ouverture du fichier.")
    end
end


function TableToJson(tbl)
    local function escapeStr(s)
        return '"' .. string.gsub(s, '"', '\\"') .. '"'
    end

    local function convert(val)
        if type(val) == "string" then
            return escapeStr(val)
        elseif type(val) == "number" then
            return tostring(val)
        elseif type(val) == "table" then
            return TableToJson(val)
        else
            return "\""..tostring(val).."\"" -- Convert other types to string
        end
    end

    local jsonStr = "{"
    local sep = ""
    for k, v in pairs(tbl) do
        jsonStr = jsonStr .. sep .. escapeStr(k) .. ":" .. convert(v)
        sep = ","
    end
    return jsonStr .. "}"
end

InitItemTable()
