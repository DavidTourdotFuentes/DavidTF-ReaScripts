--@description Analyse and display resonance frequencies
--@author david
--@version 1.0
--@changelog
--  Initial script
--@about
--  Import the selected clip and analyse frequencies to find resonances
--  Some slider to tweak analyse parameters


-- GUI REFERENCIES --
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

loadfile(libPath .. "scythe.lua")()

local GUI = require("gui.core")

-- MAIN WINDOW --
local GUI = require("gui.core")
local Window = require("gui.window")
local Radio = require("gui.elements.Radio")

-- WINDOW --
local window = GUI.createWindow({
  name = "Main Window",
  w = 500,
  h = 350,
})

-- GUI CALCULATION FUNCTIONS --
function Lerp(percentage, min, max)
    value = min + (max - min) * percentage
    return value
end

function InverseLerp(value, min, max)
    percentage = (value - min)/(max - min)
    return percentage
end

-- VARIABLES --
btn_W = 150
btn_H = 30
btn_X = (window.w - btn_W) / 2

selectedItem = nil
isFxBypassed = false
fx_index = 0
currentSelectedFreq = 0
isItemImported = false

findedResonancesArray = { }
itemLabelText = " Please select an item"

-- GUI ELEMENTS --
local mainLayer = GUI.createLayer({name = "MainLayer"})

-- Main Layer Elements --
mainLayer:addElements( GUI.createElements(
 {
      name = "frmDivider",
      type = "Frame",
      x = Lerp(0.5, 0, window.w),
      y = 0,
      w = 1,
      h = window.h
  },
  {
      name = "Scan_Selected_Item_Button",
      type = "Button",
      x = Lerp(0.5, 0, window.w / 2 - btn_W),
      y = Lerp(0.05, 0, window.h - btn_H),
      w = btn_W,
      h = btn_H,
      caption = "Import selected item",
      func = function () Main() end
  },
  {
      name = "Selected_Item_Label",
      type = "Label",
      x = Lerp(0.5, 0, window.w / 2 - btn_W),
      y = Lerp(0.18, 0, window.h - btn_H),
      w = btn_W,
      h = btn_H,
      caption = itemLabelText,
      size = 1
  },
  {
      name = "Precision_Slider",
      type = "Slider",
      x = Lerp(0.5, 0, window.w / 2 - btn_W),
      y = Lerp(0.35, 0, window.h - btn_H),
      w = btn_W,
      h = btn_H,
      caption = "Precision",
      min = 0,
      max = 100,
      defaults = 50
  },
  {
      name = "Threshold_Slider",
      type = "Slider",
      x = Lerp(0.5, 0, window.w / 2 - btn_W),
      y = Lerp(0.55, 0, window.h - btn_H),
      w = btn_W,
      h = btn_H,
      caption = "Threshold",
      min = 0,
      max = 50,
      defaults = 25
  },
  {
      name = "WindowSize_Slider",
      type = "Slider",
      x = Lerp(0.5, 0, window.w / 2 - btn_W),
      y = Lerp(0.75, 0, window.h - btn_H),
      w = btn_W,
      h = btn_H,
      caption = "Window Size",
      min = 1,
      max = 500,
      defaults = 200
  },
  {
      name = "CancelWindow_Button",
      type = "Button",
      x = Lerp(0.5, 0, window.w / 2 - btn_W),
      y = Lerp(0.95, 0, window.h - btn_H),
      w = btn_W,
      h = btn_H,
      caption = "Cancel",
      func = function () CloseWindow() end
  },
  {
      name = "FindResonnances_Button",
      type = "Button",
      x = Lerp(0.5,  window.w / 2, window.w - btn_W),
      y = Lerp(0.05, 0, window.h - btn_H),
      w = btn_W,
      h = btn_H,
      caption = "Find Resonnances",
      func = function () Scan() end
  },
  {
      name = "FindedResonances_RadioBox",
      type = "Radio",
      x = Lerp(0.5,  window.w / 2, window.w - btn_W),
      y = Lerp(0.23, 0, window.h - btn_H),
      w = btn_W,
      h = Lerp(InverseLerp(#findedResonancesArray, 1, 8), window.h / 8, window.h / 1.65),
      caption = "Resonances",
      options = findedResonancesArray
  },
  {
      name = "AudioPreview_Checkbox",
      type = "Checklist",
      x = Lerp(1, window.w / 2, window.w - btn_W),
      y = Lerp(0.95, 0, window.h - btn_H),
      w = btn_W,
      h = btn_H,
      caption = "",
      options = {"Preview"},
      frame = false,
      selectedOptions = {}
  })
)
function mainWindow()
    -- Declare GUI --
    window:addLayers(mainLayer)
    window:open()
    
    GUI.func = MainLoop
    
    -- How often (in seconds) to run GUI.func. 0 = every loop.
    GUI.funcTime = 0.1
    
    -- Start the main loop
    GUI.Main()
end

function MainLoop()
    -- Prevent the user from resizing the window
    if window.state.resized then
      -- If the window's size has been changed, reopen it
      -- at the current position with the size we specified
      window:reopen({w = window.w, h = window.h})
    end
    
    valCheckBox = GUI.Val("AudioPreview_Checkbox")
    
    if selectedItem ~= nil then
        fx_index = GetEqPluginID(selectedItem, "ReaEQ")
    end
    
    currentSelectedFreq = GetSelectedFreq()
    
    -- Detect radiobox state for "Finded Resonances"
    if GetSelectedFreq() ~= oldSelectedFreq then
        oldSelectedFreq = GetSelectedFreq()
        AudioPreview()
    end
    
    -- Detect checkbox state for switch "Preview"
    if valCheckBox[1] == true and isFxBypassed == false then
        if selectedItem ~= nil then
            BypassEQ(selectedItem, fx_index, true)
        end
        isFxBypassed = true
    elseif valCheckBox[1] == false and isFxBypassed == true then 
        if selectedItem ~= nil then
            BypassEQ(selectedItem, fx_index, false)
        end
        isFxBypassed = false
    end
    
    oldSelectedFreq = currentSelectedFreq
end
-- BUTTONS FUNCTIONS --
function CloseWindow()
    window:close()
end

--------------------------------------------------------------------------------------------------------------------

---------------------GET FFT SCRIPT---------------------
local function get_script_path()
  local filename = debug.getinfo(1, "S").source:match("^@?(.+)$")
  return filename:match("^(.*)[\\/](.-)$")
end

local function add_to_package_path(subpath) package.path = subpath .. "/david_Analyse and display resonance frequencies/?.lua;" .. package.path end

add_to_package_path(get_script_path())
---------------------------------------------------------

------------------------VARIABLES------------------------
local luafft = require "luafft"

local signal = {}
local size = luafft.next_possible_size(2*2048+1)
local frequency = 1024
local length = size / frequency

scaleX = 20000
scaleY = 0.2
offsetX = 0
offsetY = 0

local precision = 1
local threshold = 1 --50
local windowSize = 10  --200
---------------------------------------------------------

function Scan()
    if isItemImported then
        precisionValue = math.floor(Lerp(InverseLerp(GUI.Val("Precision_Slider"), 0, 100),1000,1) + 0.5)
        -- Detect and store Peaks frequencies
        resonancePeaks = DetectPeaks(spec, GUI.Val("Threshold_Slider"), GUI.Val("WindowSize_Slider"), precisionValue)
        
        ShowOutput(spec, resonancePeaks)
        
        GUI.findElementByName("FindedResonances_RadioBox").options = findedResonancesArray
        GUI.findElementByName("FindedResonances_RadioBox").h = Lerp(InverseLerp(#findedResonancesArray, 1, 8), window.h / 8, window.h / 1.65)
    end
end

-- Transform linear scale values to logarithmic scale values
function LinearToLogarithmic(value)
    if value <= 0 then
        return nil
    end
    
    -- Calcul du logarithme en base 10 de la valeur
    local logarithmicValue = math.log(value) / math.log(10)
    
    return logarithmicValue
end

-- Return table of audio files samples from a media item
function GetSamples(item)
    local take = reaper.GetActiveTake(item)
    if reaper.TakeIsMIDI( take ) then return end
    local src = reaper.GetMediaItemTake_Source(take)
    local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local samplerate =  reaper.GetMediaSourceSampleRate( src )
    local buf_samples = math.ceil(len * samplerate)
    local numchannels = 1
    local buf = reaper.new_array(math.min(buf_samples * numchannels, 2^21))
    local accessor = reaper.CreateTakeAudioAccessor( take )
    reaper.GetAudioAccessorSamples( accessor, 
                              samplerate, 
                              numchannels, 
                              0,--starttime_sec, 
                              buf_samples,--numsamplesperchannel, 
                              buf)--samplebuffer )
    local t = buf.table()
    buf.clear()
    reaper.DestroyAudioAccessor( accessor )
    return t,samplerate
end

-- Fonction pour détecter les pics dans le spectre fréquentiel avec une fenêtre, stockant la fréquence et la position
function DetectPeaks(spectrum, threshold, windowSize, precision)
    local peaks = {}

    for i = windowSize + 1, #spectrum - windowSize, precision do
        local windowStartIndex = i - windowSize
        local windowEndIndex = i + windowSize

        local window = {}
        for j = windowStartIndex, windowEndIndex do
            table.insert(window, spectrum[j]:abs())
        end

        local maxIndex = windowStartIndex + GetMaxIndex(window)

        if spectrum[maxIndex]:abs() > threshold then
            local peakFrequency = (maxIndex - 1) / #spectrum
            local peakPosition = maxIndex

            -- Vérifier si la fréquence n'est pas déjà présente dans le tableau
            if not IsFrequencyAlreadyPresentInPeaks(peaks, peakFrequency) and #peaks < 8 then
                if peakPosition < 20000 then
                    table.insert(peaks, {frequency = peakFrequency, position = peakPosition})
                end
            end
        end
    end

    return peaks
end
-- Fonction utilitaire pour obtenir l'index du maximum dans un tableau
function GetMaxIndex(array)
    local maxIndex = 1
    local maxValue = array[1]

    for i = 2, #array do
        if array[i] > maxValue then
            maxIndex = i
            maxValue = array[i]
        end
    end

    return maxIndex
end
-- Fonction utilitaire pour vérifier si une fréquence est déjà présente dans le tableau de pics
function IsFrequencyAlreadyPresentInPeaks(array, frequency)
    for _, peak in ipairs(array) do
        if math.abs(peak.frequency - frequency) < 0.01 then
            return true
        end
    end
    return false
end

-- Make preview window and show frequencies on GUI
function ShowOutput(table, resonancePeaks)

    findedResonancesArray = { }
    
    length = #table / frequency
    
    for i, peak in ipairs(resonancePeaks) do
        findedResonancesArray[i] = tostring(peak.position .. " Hz")
    end
end

function GetSelectedFreq()
    valFindedResonances = GUI.findElementByName("FindedResonances_RadioBox")

    for i = 1, #findedResonancesArray do
        if valFindedResonances:isOptionSelected(i) == true then
            id = i
        end
    end
    
    return id
end

function GetEqPluginID(item, fxName)
    take = reaper.GetActiveTake(item)
    for i = 0, reaper.TakeFX_GetCount(take) - 1 do
        retval, buf = reaper.TakeFX_GetFXName(take, i)
        
        if string.find(buf, fxName) then
            return i
        end
    end
end

function AddTakeEQ(item, freq)

    take = reaper.GetActiveTake(item)
    
    fxIndex = reaper.TakeFX_AddByName(take, "ReaEq", 1)
    
    reaper.TakeFX_SetPreset(take, fxIndex, "User 1 Band Pass 1000")
    
    --freqClamped = InverseLerp(freq, 20, 20000)
    
    reaper.TakeFX_SetParam(take, 0, 0, freq) -- Set Frequency
    reaper.TakeFX_SetEnabled(take, fxIndex, false)
end

function SetTakeEQ(item, freq, eqID)

    take = reaper.GetActiveTake(item)
 
    reaper.TakeFX_SetParam(take, eqID, 0, freq) -- Set Frequency
end

function BypassEQ(item, fxIndex, state)
    if fxIndex == nil then return end
    if state == true then
        reaper.TakeFX_SetEnabled(reaper.GetActiveTake(item), fxIndex, state)
    else
        reaper.TakeFX_SetEnabled(reaper.GetActiveTake(item), fxIndex, state)
    end
end

function DeletePlugin(item, fxIndex)
    reaper.TakeFX_Delete(reaper.GetActiveTake(item), fxIndex)
end


function AudioPreview()
    freqInput = resonancePeaks[currentSelectedFreq].position
    
    freq = math.log((freqInput - 20) / (24000 - 20) * 400 + 1) / math.log(401)
    
    eqID = GetEqPluginID(selectedItem, "ReaEQ")
    
    if eqID ~= nil then
        SetTakeEQ(selectedItem, freq, eqID)
    else
        AddTakeEQ(selectedItem, freq)
    end
end

-- Transform linear scale values to logarithmic scale values
function LinearToLogarithmic(value)
    if value <= 0 then
        return nil
    end
    
    -- Calcul du logarithme en base 10 de la valeur
    local logarithmicValue = math.log(value) / math.log(10)
    
    return logarithmicValue
end


function Main()
    if reaper.CountSelectedMediaItems(0) > 0 then
    
        selectedItem = (reaper.GetSelectedMediaItem(0,0)) -- Store selected item for all the script
        -- Create a signal from media item
        sampleTable, frequency = GetSamples(selectedItem)
        
        -- Carry out fast fourier transformation and store result in "spec"
        spec = luafft.fft(sampleTable, false)
        
        isItemImported = true
        
        itemLabelText = "Item"
         
        mediaItemName = reaper.GetTakeName(reaper.GetActiveTake(selectedItem))
        GUI.findElementByName("Selected_Item_Label"):val(mediaItemName)
    end
end

---------------------------------------------------------

reaper.atexit(function ()
    if selectedItem ~= nil then
        DeletePlugin(selectedItem, fx_index)
    end
end)



-- MAIN SCRIPT EXECUTION --
reaper.ClearConsole()
reaper.PreventUIRefresh(1)
mainWindow()
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()

