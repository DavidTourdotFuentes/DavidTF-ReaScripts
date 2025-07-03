-- @description Toggle Display JS Window ID
-- @author Delta
-- @version 1.0
-- @about
--    This scripts toggle debug mode for reaper windows, showing the ID of the window behind the mouse

local ctx = reaper.ImGui_CreateContext('Overlay')

local font_size = 24  -- Taille du texte en pixels
local font = reaper.ImGui_CreateFont('sans-serif', font_size)
reaper.ImGui_Attach(ctx, font)

function DrawOverlay()

    local id, x, y, width, height = GetSubWindowData()

    reaper.ImGui_SetNextWindowSize(ctx, width, height)
    reaper.ImGui_SetNextWindowPos(ctx, x, y)

    -- COLOR
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), 0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x000000FF)

    if id ~= 0 then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), 0x43ff6433)
    else
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), 0x43ff6400)
        
    end

    local window_flags = reaper.ImGui_WindowFlags_NoTitleBar() |
                        reaper.ImGui_WindowFlags_NoResize() |
                        reaper.ImGui_WindowFlags_NoScrollbar() |
                        reaper.ImGui_WindowFlags_NoInputs()

    reaper.ImGui_Begin(ctx, "Overlay", true, window_flags)

    reaper.ImGui_PushFont(ctx, font)
    reaper.ImGui_Text(ctx, id)
    reaper.ImGui_PopFont(ctx)

    reaper.ImGui_End(ctx)

    reaper.ImGui_PopStyleColor(ctx, 3)

    reaper.defer(DrawOverlay)
end

function GetSubWindowData()

    local id = reaper.JS_Window_GetLong(reaper.JS_Window_FromPoint(reaper.GetMousePosition()), "ID")

    if id == "0.0" then return 0, 0, 0, 0, 0 end

    local ruler_window = reaper.JS_Window_FindChildByID(reaper.GetMainHwnd(), id) -- Trouve la fenêtre de la règle du temps

    -- Récupérer la position et la taille de la règle du temps
    local _, left, top, right, bottom = reaper.JS_Window_GetRect(ruler_window)

    return id, left, top, right - left, bottom - top -- Position et taille en pixels
end

DrawOverlay()
