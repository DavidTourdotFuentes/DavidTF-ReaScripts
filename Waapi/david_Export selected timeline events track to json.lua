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
    for i=0, reaper.CountSelectedTracks(0) - 1 do
        currentTrack = reaper.GetSelectedTrack(0, i)
        noteItemCount = reaper.CountTrackMediaItems(currentTrack)
        
        for j = 0, noteItemCount - 1 do
            currentItem = reaper.GetTrackMediaItem(currentTrack, j)
            
            _, note = reaper.GetSetMediaItemInfo_String(currentItem, "P_NOTES", "", false)
            pos = reaper.GetMediaItemInfo_Value(currentItem, "D_POSITION")
            
            if note ~= "" then
                event, vol, pitch = FormatNote(note)
                AddObject(event, pos, vol, pitch)
            end
        end
    end
    
    SortItems(renderedObjects, "position")
    
    WriteExportFile()
end

function FormatNote(note)
    local event = ""
    local volume = 1.0
    local pitch = 0

    local lines = {}
    for line in note:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    event = lines[1]
    if lines[2] or lines[2] ~= "" then
        volume = tonumber(lines[2]) or 1.0
    end
    if lines[3] or lines[3] ~= "" then
        pitch = tonumber(lines[3]) or 0
    end

    return event, volume, pitch
end

function SortItems(t,...)
  local a = {...}
  table.sort(t, function (u,v)
    for i in pairs(a) do
      if u[a[i]] > v[a[i]] then return false end
      if u[a[i]] < v[a[i]] then return true end
    end
  end)
end

function GetItemInfo(item)
    return pos, note, vol
end

function AddObject(event, position, volume, pitch)
    newObject = { event = event, position = position, volume = volume, pitch = pitch}
    table.insert(renderedObjects, newObject)
end

function WriteExportFile()
    -- Conversion de la liste d'objets en format JSON
    local _, filename = reaper.JS_Dialog_BrowseForSaveFile("Choisir le fichier JSON", "", "export.json", "Fichier JSON (*.json)")
    
    -- Écriture des données JSON dans un fichier
    if filename ~= "" then
        local file = io.open(filename, "w")
        if file then
            file:write(TableToJson(renderedObjects))
            file:close()
        else
            reaper.ShowMessageBox("Erreur lors de l'ouverture du fichier", "Error !", 0)
        end
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
