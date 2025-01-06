-- @noindex

local Gui = {}

-- Shared variables
Gui.ctx = reaper.ImGui_CreateContext('Wwise Timeline cinematic creation tool')
Gui.log = {}
Gui.show_popup = false
Gui.auto_record = true
Gui.event_name = "Play_event_01"
Gui.event_length = 2
Gui.main_event_name = "Play_Linear_Timeline"
Gui.output_path = reaper.GetProjectPath().."\\"..Gui.main_event_name..".wav"
Gui.is_started = false
Gui.start_time = 0
Gui.event_duration = 10000
Gui.info_logs = true
Gui.warning_logs = true
Gui.error_logs = true

-- Local variables
local window_name = ScriptName..' - '..ScriptVersion
local winW, winH = 800, 600
local posX, posY = 0, 0
local is_open = false
local frame_padding = reaper.ImGui_StyleVar_FramePadding()
local pin = false
local FONT = reaper.ImGui_CreateFont('sans-serif', 15)
reaper.ImGui_Attach(Gui.ctx, FONT)
local BIG_FONT = reaper.ImGui_CreateFont('sans-serif', 25)
reaper.ImGui_Attach(Gui.ctx, BIG_FONT)
local show_settings = false
local visible = false

local progress_value = 0
local progressbar_space_h = 22.0

Gui.stereo_downmix = true
local set_events = false
local preview_mode = false

function Gui.Loop()
    Gui.PushTheme()

    -- Window Settings --
    local window_flags = reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_NoTitleBar() | reaper.ImGui_WindowFlags_NoScrollbar()-- | reaper.ImGui_WindowFlags_NoResize()

    if preview_mode then
        reaper.ImGui_PushStyleColor(Gui.ctx, reaper.ImGui_Col_WindowBg(), reaper.ImGui_ColorConvertDouble4ToU32(0.2,0,0,0.95))
    end

    if set_events then
        reaper.ImGui_PushStyleColor(Gui.ctx, reaper.ImGui_Col_WindowBg(), reaper.ImGui_ColorConvertDouble4ToU32(0.0,0.15,0,0.95))
    end

    if pin then
        window_flags = window_flags | reaper.ImGui_WindowFlags_TopMost()
    end

    reaper.ImGui_SetNextWindowSize(Gui.ctx, winW, winH, reaper.ImGui_Cond_Once())
    -- Font --
    reaper.ImGui_PushFont(Gui.ctx, FONT)
    -- Begin --
    visible, is_open = reaper.ImGui_Begin(Gui.ctx, window_name, true, window_flags)

    if visible then
        winW, winH = reaper.ImGui_GetWindowSize(Gui.ctx)
        posX, posY = reaper.ImGui_GetWindowPos(Gui.ctx)
        if show_popup then
            Gui.GuiPopup()
            if reaper.ImGui_GetTime(Gui.ctx) > Gui.start_time + 0.1 then
                sys_waapi.Disconnect()
                is_open = false
            end
        end

        if preview_mode then
            reaper.ImGui_PopStyleColor(Gui.ctx)
        end
        if set_events then
            reaper.ImGui_PopStyleColor(Gui.ctx)
        end

        if ThreadConnect then
            local is_finished, logs = ThreadConnect()
            if is_finished then
                ThreadConnect = nil
                sys_gui.AddLog(logs)
            end
        end

        Gui.TopBar()

        Gui.MainComponents()

        reaper.ImGui_End(Gui.ctx)
    end
    --demo.PopStyle(Gui.ctx)
    Gui.PopTheme()
    reaper.ImGui_PopFont(Gui.ctx)

    if is_open then
        reaper.defer(Gui.Loop)
    else
        local time = reaper.ImGui_GetTime(Gui.ctx)
        sys_gui.Close(time)
    end

    if preview_mode then
        local output = sys_utils.PreviewLoop()
        sys_gui.AddLog(output)
    end

    if Gui.is_started then
        local current_time = reaper.ImGui_GetTime(Gui.ctx) - Gui.start_time

        progress_value = current_time / Gui.event_duration

        if reaper.ImGui_GetTime(Gui.ctx) - Gui.start_time >= Gui.event_duration then
            local import = sys_waapi.Stop(gui.output_path)
            sys_gui.AddLog(import)

            Gui.is_started = false
            Gui.start_time = 0
            Gui.event_duration = 10000
        end
    end
end

-- GUI ELEMENTS FOR TOP BAR
function Gui.TopBar()
    -- GUI Menu Bar --
    local table_flags = reaper.ImGui_TableFlags_None() --reaper.ImGui_TableFlags_BordersOuter()
    if reaper.ImGui_BeginTable(Gui.ctx, "table_top_bar", 2, table_flags) then
        reaper.ImGui_TableNextRow(Gui.ctx)
        reaper.ImGui_TableNextColumn(Gui.ctx)
        reaper.ImGui_Text(Gui.ctx, window_name)

        reaper.ImGui_TableNextColumn(Gui.ctx)
        local x, _ = reaper.ImGui_GetContentRegionAvail(Gui.ctx)
        local text_x, _ = reaper.ImGui_CalcTextSize(Gui.ctx, "SX")
        reaper.ImGui_SetCursorPosX(Gui.ctx, reaper.ImGui_GetCursorPosX(Gui.ctx) + (x - text_x - 24))

        if reaper.ImGui_Button(Gui.ctx, "S") then
            show_settings = not show_settings
        end
        reaper.ImGui_SameLine(Gui.ctx)
        if reaper.ImGui_Button(Gui.ctx, "X") then
            sys_gui.SetButtonState()
            is_open = false
        end

        reaper.ImGui_EndTable(Gui.ctx)
    end
end

function Gui.MainComponents()

    if not sys_waapi.connected then
        reaper.ImGui_BeginDisabled(Gui.ctx)
    end

    if reaper.ImGui_BeginTable(Gui.ctx, 'table_main_event_name', 3, reaper.ImGui_TableFlags_SizingStretchProp()) then
        reaper.ImGui_TableNextRow(Gui.ctx) 
        reaper.ImGui_TableNextColumn(Gui.ctx)
        reaper.ImGui_Text(Gui.ctx, 'Timeline Event Name : '); reaper.ImGui_SameLine(Gui.ctx)
        local w, h = reaper.ImGui_GetContentRegionAvail(Gui.ctx)
        _, Gui.main_event_name = reaper.ImGui_InputText(Gui.ctx, '##inputText_main_event_name', Gui.main_event_name)

        reaper.ImGui_TableNextColumn(Gui.ctx)
        reaper.ImGui_Text(Gui.ctx, 'Last Event Length (s) : '); reaper.ImGui_SameLine(Gui.ctx)
        w, h = reaper.ImGui_GetContentRegionAvail(Gui.ctx)
        reaper.ImGui_PushItemWidth(Gui.ctx, w/1.3)
        _, Gui.event_length = reaper.ImGui_InputText(Gui.ctx, '##inputText_event_length', Gui.event_length, reaper.ImGui_InputTextFlags_CharsDecimal())
        reaper.ImGui_PopItemWidth(Gui.ctx)
    
        reaper.ImGui_EndTable(Gui.ctx)
    end
        if reaper.ImGui_BeginTable(Gui.ctx, 'table_recorder_path', 3, reaper.ImGui_TableFlags_SizingStretchProp()) then
        reaper.ImGui_TableNextRow(Gui.ctx)
        reaper.ImGui_TableNextColumn(Gui.ctx)
        local old_w, h = reaper.ImGui_GetContentRegionAvail(Gui.ctx)
        _, Gui.auto_record = reaper.ImGui_Checkbox(Gui.ctx, 'Auto Record', Gui.auto_record)
        
        reaper.ImGui_TableNextColumn(Gui.ctx)
        _, Gui.stereo_downmix = reaper.ImGui_Checkbox(Gui.ctx, 'Stereo Downmix', Gui.stereo_downmix)
        
        reaper.ImGui_TableNextColumn(Gui.ctx)
        reaper.ImGui_Text(Gui.ctx, 'Path : '); reaper.ImGui_SameLine(Gui.ctx)
        _, Gui.output_path = reaper.ImGui_InputText(Gui.ctx, '##inputText_output_path', Gui.output_path); reaper.ImGui_SameLine(Gui.ctx)
        if reaper.ImGui_Button(Gui.ctx, 'BROWSE', old_w) then
            Gui.output_path = sys_gui.Browse()
        end
        
        reaper.ImGui_EndTable(Gui.ctx)
    end

    reaper.ImGui_Separator(Gui.ctx)

    if reaper.ImGui_BeginTable(Gui.ctx, 'table_log_options', 5) then
        reaper.ImGui_TableNextRow(Gui.ctx)
        reaper.ImGui_TableNextColumn(Gui.ctx)
        
        local old_w, h = reaper.ImGui_GetContentRegionAvail(Gui.ctx)
        _, Gui.info_logs = reaper.ImGui_Checkbox(Gui.ctx, 'Show Info Logs', Gui.info_logs)
        
        reaper.ImGui_TableNextColumn(Gui.ctx)
        _, Gui.warning_logs = reaper.ImGui_Checkbox(Gui.ctx, 'Show Warning Logs', Gui.warning_logs)
        
        reaper.ImGui_TableNextColumn(Gui.ctx)
        _, Gui.error_logs = reaper.ImGui_Checkbox(Gui.ctx, 'Show Error Logs', Gui.error_logs)
        
        reaper.ImGui_TableNextColumn(Gui.ctx)
        if reaper.ImGui_Button(Gui.ctx, 'Clear Logs', old_w) then
            sys_gui.ClearLogs()
        end
        
        reaper.ImGui_TableNextColumn(Gui.ctx)
        if reaper.ImGui_Button(Gui.ctx, 'Clean Wwise Project', old_w) then
            sys_gui.CleanWwise()
        end
        
        reaper.ImGui_EndTable(Gui.ctx)
    end

    reaper.ImGui_Separator(Gui.ctx)

    if reaper.ImGui_BeginTable(Gui.ctx, 'table_preview_mode', 3, reaper.ImGui_TableFlags_SizingStretchProp()) then
        reaper.ImGui_TableNextRow(Gui.ctx)
        reaper.ImGui_TableNextColumn(Gui.ctx)
        local w, h = reaper.ImGui_GetContentRegionAvail(Gui.ctx)
        local retval, temp_preview_mode = reaper.ImGui_Checkbox(Gui.ctx, 'Preview Mode', preview_mode)
        preview_mode = temp_preview_mode
        if retval then
            set_events = false
            if preview_mode then
                local init = sys_utils.InitializePreview()
                sys_gui.AddLog(init)
            else
                sys_gui.AddLog({state = "INFO", desc = "Preview stopped"})
            end
        end
        
        reaper.ImGui_TableNextColumn(Gui.ctx)
        retval, set_events = reaper.ImGui_Checkbox(Gui.ctx, 'Set clip events', set_events)
        if retval then
            preview_mode = false
            
            if set_events then
                sys_gui.AddLog({state = "INFO", desc = "Item events creation started : Left click on track to create events item"})
            else
                sys_gui.AddLog({state = "INFO", desc = "Item events creation stopped"})
            end
        end
        reaper.ImGui_TableNextColumn(Gui.ctx)
        reaper.ImGui_Text(Gui.ctx, 'Events name : '); reaper.ImGui_SameLine(Gui.ctx)
        local _, temp_event_name = reaper.ImGui_InputText(Gui.ctx, '##inputText_events_name', Gui.event_name); reaper.ImGui_SameLine(Gui.ctx)
        Gui.event_name = temp_event_name
        
        reaper.ImGui_EndTable(Gui.ctx)
    end

    if Gui.is_started then
        reaper.ImGui_ProgressBar(Gui.ctx, progress_value)
        progressbar_space_h = 0
    else
        progressbar_space_h = 21
    end

    if not sys_waapi.connected then
        reaper.ImGui_EndDisabled(Gui.ctx)
    end

    if reaper.ImGui_BeginChild(Gui.ctx, 'child_log', winW - frame_padding * 1.4, (winH / 1.8) + progressbar_space_h + (frame_padding * 2), reaper.ImGui_ChildFlags_Border()) then
        if reaper.ImGui_BeginTable(Gui.ctx, 'table_log', 1) then
            for i = 1, #Gui.log do
                reaper.ImGui_TableNextRow(Gui.ctx)
                reaper.ImGui_TableNextColumn(Gui.ctx)
                local cur_log = Gui.log[i]
                
                if string.find(Gui.log[i], "[ERROR]", 1, true) then
                    reaper.ImGui_PushStyleColor(Gui.ctx, reaper.ImGui_Col_Text(), reaper.ImGui_ColorConvertDouble4ToU32(1,0,0,1))
                elseif string.find(Gui.log[i], "[WARNING]", 1, true) then
                    reaper.ImGui_PushStyleColor(Gui.ctx, reaper.ImGui_Col_Text(), reaper.ImGui_ColorConvertDouble4ToU32(1,1,0,1))
                else
                    reaper.ImGui_PushStyleColor(Gui.ctx, reaper.ImGui_Col_Text(), reaper.ImGui_ColorConvertDouble4ToU32(1,1,1,1))
                end
                reaper.ImGui_TextWrapped(Gui.ctx, Gui.log[i])
                reaper.ImGui_PopStyleColor(Gui.ctx)
            end
            
            reaper.ImGui_EndTable(Gui.ctx)
        end
        reaper.ImGui_EndChild(Gui.ctx)
    end

    if reaper.ImGui_BeginChild(Gui.ctx, 'child_buttons', winW - frame_padding * 1.4, winH / 12) then
        if reaper.ImGui_BeginTable(Gui.ctx, 'table_buttons', 1, reaper.ImGui_TableColumnFlags_WidthStretch()) then
            if not sys_waapi.connected then
                reaper.ImGui_TableNextColumn(Gui.ctx)
                local w, h = reaper.ImGui_GetContentRegionAvail(Gui.ctx)
                if reaper.ImGui_Button(Gui.ctx, 'RECONNECT', w, h) then
                    sys_gui.AddLog({state = "INFO", desc = "Trying to reconnect to Wwise..."})
                    
                    ThreadConnect = coroutine.wrap(sys_waapi.ConnectTime)

                    --local connexion = sys_waapi.Connect()
                    --sys_gui.AddLog(connexion)
                end
            elseif Gui.is_started then
                reaper.ImGui_BeginDisabled(Gui.ctx)
                
                reaper.ImGui_TableNextColumn(Gui.ctx)
                local w, h = reaper.ImGui_GetContentRegionAvail(Gui.ctx)
                if reaper.ImGui_Button(Gui.ctx, 'CANCEL', w, h) then
                    --button_CANCEL()
                end
                reaper.ImGui_EndDisabled(Gui.ctx)
            else
                reaper.ImGui_TableNextColumn(Gui.ctx)
                local w, h = reaper.ImGui_GetContentRegionAvail(Gui.ctx)
                if reaper.ImGui_Button(Gui.ctx, 'GENERATE', w, h) then
                    sys_gui.Generate()
                end
            end
            
            reaper.ImGui_EndTable(Gui.ctx)
        end
        
        reaper.ImGui_EndChild(Gui.ctx)
    end
end

-- GUI ELEMENTS FOR SETTINGS WINDOW --
function Gui.SettingsWindow()
    reaper.ImGui_PushStyleColor(Gui.ctx, reaper.ImGui_Col_WindowBg(), 0x000000ff)
    -- Set Window visibility and settings --
    local settings_flags = reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_NoScrollbar()
    reaper.ImGui_SetNextWindowSize(Gui.ctx, 400, 200, reaper.ImGui_Cond_Once())
    reaper.ImGui_SetNextWindowPos(Gui.ctx, window_x + 50, window_y + 50, reaper.ImGui_Cond_Appearing())

    if not settings_open then
        show_settings = false
    end
    reaper.ImGui_PopStyleColor(Gui.ctx, 1)
end

function Gui.PushTheme()
    -- Vars
    reaper.ImGui_PushStyleVar(Gui.ctx, reaper.ImGui_StyleVar_WindowRounding(),   4)
    reaper.ImGui_PushStyleVar(Gui.ctx, reaper.ImGui_StyleVar_ChildRounding(),    2)
    reaper.ImGui_PushStyleVar(Gui.ctx, reaper.ImGui_StyleVar_PopupRounding(),    2)
    reaper.ImGui_PushStyleVar(Gui.ctx, reaper.ImGui_StyleVar_FrameRounding(),    2)
    -- Colors
    reaper.ImGui_PushStyleColor(Gui.ctx, reaper.ImGui_Col_WindowBg(), 0x111111FF)
    reaper.ImGui_PushStyleColor(Gui.ctx, reaper.ImGui_Col_Text(), 0x111111FF)
end

function Gui.PopTheme()
    reaper.ImGui_PopStyleVar(Gui.ctx, 4)
    reaper.ImGui_PopStyleColor(Gui.ctx, 2)
end

return Gui