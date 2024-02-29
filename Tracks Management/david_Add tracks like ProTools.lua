-- INITIALISATION --
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end
loadfile(libPath .. "scythe.lua")()

-- MAIN WINDOW --
local GUI = require("gui.core")
local Window = require("gui.window")
local Listbox = require("gui.elements.Listbox")
local Color = require("public.color")

-- VARIABLES --
function Lerp(percentage, min, max)
    value = min + (max - min) * percentage
    return value
end

function InverseLerp(value, min, max)
    percentage = (value - min)/(max - min)
    return percentage
end

window_W = 600
window_H = 120

generic_H = 20
nmbField_W = 40
nameField_W = 200
createBtn_W = 100
folderField_W = 150
baseColor = Color.fromRgba(129, 137, 137, 1)

sectionCount = 1
gap = 3

-- WINDOW --
local window = GUI.createWindow({
  name = "Main Window",
  w = window_W,
  h = window_H,
})

-- GUI ELEMENTS --
local mainLayer = GUI.createLayer({name = "MainLayer"})
local itemLayers = table.pack( GUI.createLayers(
  {name = "ItemLayer1"},
  {name = "ItemLayer2"},
  {name = "ItemLayer3"},
  {name = "ItemLayer4"},
  {name = "ItemLayer5"},
  {name = "ItemLayer6"},
  {name = "ItemLayer7"},
  {name = "ItemLayer8"},
  {name = "ItemLayer9"},
  {name = "ItemLayer10"}
))

local folderLayer = GUI.createLayer({name = "FolderLayer"})

-- Main Layer Elements --
mainLayer:addElements( GUI.createElements(
  {
    name = "btn_addSection",
    type = "Button",
    x = Lerp(0.25, 0, window_W - createBtn_W),
    y = window_H - generic_H - 20,
    w = createBtn_W,
    h = generic_H,
    pad = 10,
    caption = "Add Section",
    func = function () AddSection() end
  },
  {
    name = "btn_removeSection",
    type = "Button",
    x = Lerp(0.5, 0, window_W - createBtn_W),
    y = window_H - generic_H - 20,
    w = createBtn_W,
    h = generic_H,
    pad = 10,
    caption = "Remove Section",
    func = function () RemoveSection() end
  },
  {
    name = "btn_create",
    type = "Button",
    x = Lerp(0.75, 0, window_W - createBtn_W),
    y = window_H - generic_H - 20,
    w = createBtn_W,
    h = generic_H,
    pad = 10,
    caption = "Create",
    func = function () Create() end
  })
)

for i=1, 10 do
    itemLayers[i]:addElements( GUI.createElements(
      {
        name = "field_number_"..i,
        type = "Textbox",
        x = Lerp(0.25, 0, (window_W / 2) - nmbField_W),
        y = (3*generic_H * i) - (2 * generic_H),
        w = nmbField_W,
        h = generic_H,
        caption = "Create",
        captionPosition = "left",
        pad = 10,
        validator = function () CheckInputType(i) return true end,
        retval = 1
      },
      {
        name = "field_name_"..i,
        type = "Textbox",
        x = Lerp(0.65, 0, (window_W / 2) - nmbField_W),
        y = (3*generic_H * i) - (2 * generic_H),
        w = nameField_W,
        h = generic_H,
        caption = "Name",
        captionPosition = "left",
        pad = 10,
        retval = "Track"
      },
      {
        name = "color_picker_"..i,
        type = "ColorPicker",
        x = Lerp(0.75, 0, window_W - generic_H),
        y = (3*generic_H * i) - (2 * generic_H),
        w = generic_H,
        h = generic_H,
        pad = 10,
        caption = "Color",
        color = baseColor
      },
      {
        name = "checkbox_folder_"..i,
        type = "Checklist",
        x = Lerp(0.98, 0, window_W - createBtn_W),
        y = (3*generic_H * i) - (2 * generic_H) - (generic_H / 1.45),
        w = createBtn_W,
        h = generic_H * 2,
        pad = 10,
        caption = "",
        options = {"Folder"},
        frame = false
      },
      {
        name = "frme_"..i,
        type = "Frame",
        x = Lerp(0, 0, window_W),
        y = 3*generic_H * i,
        w = window_W,
        h = 1
      })
  )
end

-- GUI FUNCTION --
function main()
    window:addLayers(mainLayer)
    window:addLayers(table.unpack(itemLayers))
    for i = 2, #itemLayers do
        itemLayers[i]:hide()
    end
    window:open()
    -- Draw GUI --
    GUI.Main()
end

function AddSection()
    if sectionCount < #itemLayers then
        itemLayers[sectionCount + 1]:show()
        sectionCount = sectionCount + 1
    end
    RecalcWindow()
end
function RemoveSection()
    if sectionCount > 1 then
        itemLayers[sectionCount]:hide()
        sectionCount = sectionCount - 1
    end
    RecalcWindow()
end
function RecalcWindow()
    newWindowH = Lerp(InverseLerp(sectionCount, 1, #itemLayers), 120, 680)
    window:reopen({w = 600, h = newWindowH})
    GUI.findElementByName("btn_addSection").y = newWindowH - generic_H - 20
    GUI.findElementByName("btn_removeSection").y = newWindowH - generic_H - 20
    GUI.findElementByName("btn_create").y = newWindowH - generic_H - 20
end
function CheckInputType(id)
    val = GUI.Val("field_number_"..tostring(id))
    if tonumber(val) == nil then
        GUI.findElementByName("field_number_"..tostring(id)).retval = "1"
    else
        if tonumber(val) >= 100 then
            GUI.findElementByName("field_number_"..tostring(id)).retval = "1"
        end
    end
end

------------------------------------------------------------------------------------

-- MAIN FUNCTIONS --
local function CreateTracks(numTracks, baseName, color, folder)
    reaper.Main_OnCommand(40297, 0) -- Deselect all tracks
    if numTracks > 0 then
        selectedTracks = {}
        local lastTrackPos = reaper.CountTracks(0) + 1 -- Position de la dernière piste dans la session
        
        -- Créer les nouvelles pistes
        for i = 1, numTracks do
            local trackName = ""
            
            if numTracks == 1 then
                trackName = baseName
            else
                trackName = baseName .. " " .. i
            end
            local trackIndex = reaper.GetNumTracks()
            reaper.InsertTrackAtIndex(trackIndex, true)
            local track = reaper.GetTrack(0, trackIndex)
            reaper.GetSetMediaTrackInfo_String(track, "P_NAME", trackName, true)
            reaper.SetTrackColor(track, color | 0x1000000)
            table.insert(selectedTracks, track)
        end
 
        -- Créer la piste de type "dossier" après la dernière piste existante
        if folder == true then
            reaper.InsertTrackAtIndex(lastTrackPos, true)
            local folderTrack = reaper.GetTrack(0, lastTrackPos)
            reaper.GetSetMediaTrackInfo_String(folderTrack, "P_NAME", baseName, true)
            reaper.SetMediaTrackInfo_Value(folderTrack, "I_FOLDERDEPTH", 1)
            reaper.SetTrackColor(folderTrack, color | 0x1000000)
        end
 
        -- Sélectionner toutes les nouvelles pistes
        for i, track in ipairs(selectedTracks) do
            reaper.SetTrackSelected(track, true)
        end
 
        -- Réorganiser les pistes sous la piste "dossier" si nécessaire
        if folder == true then
            for i = 0, numTracks + 1 do
                reaper.ReorderSelectedTracks(lastTrackPos + i - 1, 1)
            end
        end
 
        reaper.UpdateArrange()
    end
end

function Create()
    reaper.ClearConsole()
    for i = 1, sectionCount do
        trackNum = GUI.Val("field_number_"..tostring(i))
        trackName = GUI.Val("field_name_"..tostring(i))
        trackColor = GUI.Val("color_picker_"..tostring(i))
        trackFolder = GUI.Val("checkbox_folder_"..tostring(i))[1]
        if trackFolder == nil then trackFolder = false end
        if trackColor == nil then
            trackColor = baseColor
        end
        
        
        reaper.PreventUIRefresh(1)
        reaper.ClearConsole()
        CreateTracks(tonumber(trackNum), trackName, Color.toNative(trackColor), trackFolder)
        reaper.PreventUIRefresh(-1)
        reaper.UpdateArrange()
        
        window:close()
    end
end

-- MAIN SCRIPT EXECUTION --
main()


