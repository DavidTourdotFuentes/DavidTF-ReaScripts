-- @description Show time selection informations
-- @author Delta
-- @version 2.0
-- @about
--    This scripts get time selection values and convert them automatically in 
--    HOUR:MINUTES:SECONDS.MILLISECONDS and MESURES.BEATS.FRAMES and show values in a gfx window
--    Click on window to copy values to clipboard


-- GET CURRENT SELECTION VALUES
function SetupVariables()
    start, stop = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    length = stop - start
end

function Lerp(percent, min, max)
    result = (max - min) / (1/percent)
    return result
end

-- CONVERTION FUNCTION
function ConvertVariables()
    
    start_hms = OrganizeTimeValues(start)
    stop_hms = OrganizeTimeValues(stop)
    length_hms = OrganizeTimeValues(length)
    
    start_b, start_a, _, start_c, _  = reaper.TimeMap2_timeToBeats(0, start)
    stop_b, stop_a, _, stop_c, _ = reaper.TimeMap2_timeToBeats(0, stop)
    length_b, length_a, _, length_c, _ = reaper.TimeMap2_timeToBeats(0, length)
    OrganizeBeatValues()
    
    start_beat = start_a.."."..start_b.."."..start_c
    stop_beat = stop_a.."."..stop_b.."."..stop_c
    length_beat = length_a.."."..length_b.."."..length_c
    
end

-- CONVERT TIME VALUES IN SECONDS TO TIME VALUES IN H:MIN:SEC.MSEC
function OrganizeTimeValues(timeSeconds)
    timeSeconds = tonumber(timeSeconds)

    if timeSeconds < 0 then
        return "0:00:00.000";
    else
        hours = string.format("%01.f", math.floor(timeSeconds/3600));
        mins = string.format("%02.f", math.floor(timeSeconds/60 - (hours*60)));
        secs = string.format("%02.f", math.floor(timeSeconds - hours*3600 - mins *60));
        ms_raw = timeSeconds - math.floor(timeSeconds)
        msec = string.format("%03.f", math.floor(ms_raw*1000));
        
        if hours == "0" then
            resultString = mins..":"..secs.."."..msec
        else
            resultString = hours..":"..mins..":"..secs.."."..msec
        end
    end
    
    return resultString
end

-- CONVERT TIME VALUES IN BEAT TO TIME VALUES IN MESURES:BEAT:FRAMES
function OrganizeBeatValues(timeBeat)
    start_a = start_a + 1
    start_b = math.floor(start_b + 1)
    start_c = string.format("%02.f", math.floor(100 *(start_c - math.floor(start_c)) + 0.5))
    
    stop_a = stop_a + 1
    stop_b = math.floor(stop_b + 1)
    stop_c = string.format("%02.f", math.floor(100 *(stop_c - math.floor(stop_c)) + 0.5))
    
    length_b = math.floor(length_b)
    length_c = string.format("%02.f", math.floor(100 *(length_c - math.floor(length_c))+ 0.5))
end

-- DRAW VALUES IN THE GFX WINDOW
function DrawWindow()

    gfx.setfont(1, "sans-serif", Lerp(0.25, 0, gfx.h), 0x879393)

    -- Hour Minutes Seconds Milliseconds values positionning
    gfx.x=4; gfx.y=Lerp(0.05, 0, gfx.h);
    gfx.drawstr("Start : " ..start_hms, 0, gfx.w, gfx.h)
    
    gfx.x=4; gfx.y=Lerp(0.4, 0, gfx.h);
    gfx.drawstr("End : " ..stop_hms, gfx.w, gfx.h)
    
    gfx.x=4; gfx.y=Lerp(0.80, 0, gfx.h - Lerp(0.10, 0, gfx.h));
    gfx.drawstr("Length : " ..length_hms, 0, gfx.w, gfx.h)
  
    
    -- Mesures Beats Frames values positionning
    gfx.x=Lerp(0.5, 0, gfx.w); gfx.y=Lerp(0.05, 0, gfx.h);
    gfx.drawstr("Beat Start : " .. start_beat, 256, gfx.w, gfx.h)
    
    gfx.x=Lerp(0.5, 0, gfx.w); gfx.y=Lerp(0.4, 0, gfx.h);
    gfx.drawstr("Beat End : " .. stop_beat, 256, gfx.w, gfx.h)
    
    gfx.x=Lerp(0.5, 0, gfx.w); gfx.y=Lerp(0.80, 0, gfx.h - Lerp(0.10, 0, gfx.h));
    gfx.drawstr("Beat Length : " .. length_beat, 256, gfx.w, gfx.h)

end

function MsgTooltip(text)
    local x, y = reaper.GetMousePosition()
    reaper.TrackCtl_SetToolTip(text, x, y, true) -- spaced out // topmost true
end

clickState = false

-- MAIN LOOP FUNCTION
function main()
    SetupVariables()
    ConvertVariables()
    DrawWindow()
    
    if gfx.mouse_cap == 1 and clickState == false then
        copyValue = start_hms .. " / " .. stop_hms .. " / " .. length_hms .. "\n" .. start_beat .. " / " .. stop_beat .. " / " .. length_beat
        reaper.CF_SetClipboard(copyValue)
        MsgTooltip("Value copied in clipboard !")
        clickState = true
    end
    
    if gfx.mouse_cap == 0 then
        clickState = false
    end
    
    reaper.runloop(main)
end

--START-------------------------------------------------------------------
gfx.init("Time Selection Window", 700, 160, 1, 100, 100)
gfx.setfont(1, "sans-serif", 15, 0x879393)
gfx.clear = 0x2b2b2b
reaper.Main_OnCommand(41600, 0)
main()
--END---------------------------------------------------------------------
