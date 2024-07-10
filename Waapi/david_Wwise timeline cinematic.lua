--@description david_Wwise timeline cinematic
--@author DavidTF
--@version 0.4
--@changelog Detection of reawwise on appdata folder
--@about Main GUI for cinematic timeline creation

function getAppDataPath()
    -- Utiliser os.getenv pour obtenir la variable d'environnement APPDATA
    local appDataPath = os.getenv("APPDATA")
    return appDataPath
end

-- Fonction pour vérifier l'existence d'un fichier
function fileExists(filePath)
    local file = io.open(filePath, "r")
    if file then
        file:close()
        return true
    else
        return false
    end
end

-- Appeler la fonction pour obtenir le chemin AppData
local appDataPath = getAppDataPath()
if appDataPath then
    -- Construire le chemin complet vers le fichier à vérifier
    local filePath = appDataPath .. "\\REAPER\\UserPlugins\\reaper_reawwise.dll"
    
    -- Vérifier si le fichier existe
    if not fileExists(filePath) then
        reaper.ShowMessageBox("Reawwise is not installed, please install ReaWwise\n(Github URL copied to clipboard)", "ReaWwise missing", 0)
        reaper.CF_SetClipboard("https://github.com/Audiokinetic/Reaper-Tools/raw/main/index.xml")
        return
    end
else
    reaper.ShowMessageBox("Impossible de récupérer le chemin vers le dossier AppData", "Erreur", 0)
    return
end

local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "david_Wwise timeline cinematic (system).lua"

local script = require(package.path)

function AddLog(_output)
    time = os.date("*t")
    strTime = ("%02d:%02d:%02d"):format(time.hour, time.min, time.sec)
    if info_logs and _output.state == "INFO" then
        log[#log + 1] = "[".. strTime .."] : [" .. _output.state .. "] : " .. _output.desc
    end
    if warning_logs and _output.state == "WARNING" then
        log[#log + 1] = "[".. strTime .."] : [" .. _output.state .. "] : " .. _output.desc
    end
    if error_logs and _output.state == "ERROR" then
        log[#log + 1] = "[".. strTime .."] : [" .. _output.state .. "] : " .. _output.desc
    end
end

function GuiInit()
    ctx = reaper.ImGui_CreateContext('Wwise Timeline cinematic creation tool')
    FONT = reaper.ImGui_CreateFont('sans-serif', 15)
    reaper.ImGui_Attach(ctx, FONT)
    BIG_FONT = reaper.ImGui_CreateFont('sans-serif', 25)
    reaper.ImGui_Attach(ctx, BIG_FONT)
    winW, winH = 800, 520
    posX, posY = 0, 0
    is_closed = false
    frame_padding = reaper.ImGui_StyleVar_FramePadding()
    log = {}
    progress_value = 0
    progressbar_space_h = 22.0
    show_popup = false
    
    event_name = "Play_Linear_Timeline"
    output_path = reaper.GetProjectPath().."\\"..event_name..".wav"
    event_length = 2
    auto_record = true
    stereo_downmix = true
    set_events = false
    events_name = "Play_event_01"
    
    is_started = false
    start_time = 0
    event_duration = 10000
    preview_mode = false
    
    info_logs = true
    warning_logs = true
    error_logs = true
    
    mouse = 0
    
    -- CONNEXION WITH WWISE
    connexion = script.ConnectToWwise()
    AddLog(connexion)
end

function GuiElements()
    if reaper.ImGui_BeginTable(ctx, 'table_event_name', 3, reaper.ImGui_TableFlags_SizingStretchProp()) then
        reaper.ImGui_TableNextRow(ctx) 
        reaper.ImGui_TableNextColumn(ctx)
        reaper.ImGui_Text(ctx, 'Timeline Event Name : '); reaper.ImGui_SameLine(ctx)
        w, h = reaper.ImGui_GetContentRegionAvail(ctx)
        _, event_name = reaper.ImGui_InputText(ctx, '##inputText_event_name', event_name)

        reaper.ImGui_TableNextColumn(ctx)
        reaper.ImGui_Text(ctx, 'Last Event Length (s) : '); reaper.ImGui_SameLine(ctx)
        w, h = reaper.ImGui_GetContentRegionAvail(ctx)
        reaper.ImGui_PushItemWidth(ctx, w/1.3)
        _, event_length = reaper.ImGui_InputText(ctx, '##inputText_event_length', event_length, reaper.ImGui_InputTextFlags_CharsDecimal())
        reaper.ImGui_PopItemWidth(ctx)
    
        reaper.ImGui_EndTable(ctx)
    end
    
    if reaper.ImGui_BeginTable(ctx, 'table_recorder_path', 3, reaper.ImGui_TableFlags_SizingStretchProp()) then
        reaper.ImGui_TableNextRow(ctx)
        reaper.ImGui_TableNextColumn(ctx)
        old_w, h = reaper.ImGui_GetContentRegionAvail(ctx)
        _, auto_record = reaper.ImGui_Checkbox(ctx, 'Auto Record', auto_record)
        
        reaper.ImGui_TableNextColumn(ctx)
        _, stereo_downmix = reaper.ImGui_Checkbox(ctx, 'Stereo Downmix', stereo_downmix)
        
        reaper.ImGui_TableNextColumn(ctx)
        reaper.ImGui_Text(ctx, 'Path : '); reaper.ImGui_SameLine(ctx)
        _, output_path = reaper.ImGui_InputText(ctx, '##inputText_output_path', output_path); reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, 'BROWSE', old_w) then
            button_BROWSE()
        end
        
        reaper.ImGui_EndTable(ctx)
    end
    
    reaper.ImGui_Separator(ctx)
    
    if reaper.ImGui_BeginTable(ctx, 'table_log_options', 5) then
        reaper.ImGui_TableNextRow(ctx)
        reaper.ImGui_TableNextColumn(ctx)
        
        old_w, h = reaper.ImGui_GetContentRegionAvail(ctx)
        _, info_logs = reaper.ImGui_Checkbox(ctx, 'Show Info Logs', info_logs)
        
        reaper.ImGui_TableNextColumn(ctx)
        _, warning_logs = reaper.ImGui_Checkbox(ctx, 'Show Warning Logs', warning_logs)
        
        reaper.ImGui_TableNextColumn(ctx)
        _, error_logs = reaper.ImGui_Checkbox(ctx, 'Show Error Logs', error_logs)
        
        reaper.ImGui_TableNextColumn(ctx)
        if reaper.ImGui_Button(ctx, 'Clear Logs', old_w) then
            button_CLEAR_LOGS()
        end
        
        reaper.ImGui_TableNextColumn(ctx)
        if reaper.ImGui_Button(ctx, 'Clean Wwise Project', old_w) then
            button_CLEAN_WWISE()
        end
        
        reaper.ImGui_EndTable(ctx)
    end
    
    reaper.ImGui_Separator(ctx)
    
    if reaper.ImGui_BeginTable(ctx, 'table_preview_mode', 3, reaper.ImGui_TableFlags_SizingStretchProp()) then
        reaper.ImGui_TableNextRow(ctx)
        reaper.ImGui_TableNextColumn(ctx)
        w, h = reaper.ImGui_GetContentRegionAvail(ctx)
        retval, preview_mode = reaper.ImGui_Checkbox(ctx, 'Preview Mode', preview_mode)
        if retval then
            set_events = false
            if preview_mode then
                init = script.InitializePreview()
                AddLog(init)
            else
                AddLog({state = "INFO", desc = "Preview stopped"})
            end
        end
        
        reaper.ImGui_TableNextColumn(ctx)
        retval, set_events = reaper.ImGui_Checkbox(ctx, 'Set clip events', set_events)
        if retval then
            preview_mode = false
            
            if set_events then
                AddLog({state = "INFO", desc = "Item events creation started : Left click on track to create events item"})
            else
                AddLog({state = "INFO", desc = "Item events creation stopped"})
            end
        end
        reaper.ImGui_TableNextColumn(ctx)
        reaper.ImGui_Text(ctx, 'Events name : '); reaper.ImGui_SameLine(ctx)
        _, events_name = reaper.ImGui_InputText(ctx, '##inputText_events_name', events_name); reaper.ImGui_SameLine(ctx)
        
        reaper.ImGui_EndTable(ctx)
    end

    if is_started then
        reaper.ImGui_ProgressBar(ctx, progress_value)
        progressbar_space_h = 0
    else
        progressbar_space_h = 21
    end
    
    if reaper.ImGui_BeginChild(ctx, 'child_log', winW - frame_padding * 1.4, (winH / 1.8) + progressbar_space_h + (frame_padding * 2), reaper.ImGui_ChildFlags_Border()) then
        if reaper.ImGui_BeginTable(ctx, 'table_log', 1) then
            for i = 1, #log do
                reaper.ImGui_TableNextRow(ctx)
                reaper.ImGui_TableNextColumn(ctx)
                cur_log = log[i]
                
                if string.find(log[i], "[ERROR]", 1, true) then
                    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), reaper.ImGui_ColorConvertDouble4ToU32(1,0,0,1))
                elseif string.find(log[i], "[WARNING]", 1, true) then
                    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), reaper.ImGui_ColorConvertDouble4ToU32(1,1,0,1))
                else
                    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), reaper.ImGui_ColorConvertDouble4ToU32(1,1,1,1))
                end
                reaper.ImGui_TextWrapped(ctx, log[i])
                reaper.ImGui_PopStyleColor(ctx)
            end
            
            reaper.ImGui_EndTable(ctx)
        end
        reaper.ImGui_EndChild(ctx)
    end
    
    if reaper.ImGui_BeginChild(ctx, 'child_buttons', winW - frame_padding * 1.4, winH / 12) then
        if reaper.ImGui_BeginTable(ctx, 'table_buttons', 2, reaper.ImGui_TableColumnFlags_WidthStretch()) then
            reaper.ImGui_TableNextRow(ctx)
            reaper.ImGui_TableNextColumn(ctx)
            w, h = reaper.ImGui_GetContentRegionAvail(ctx)
            if reaper.ImGui_Button(ctx, 'CLOSE', w, h) then
                button_CLOSE()
            end
            
            if is_started then
                reaper.ImGui_BeginDisabled(ctx)
                
                reaper.ImGui_TableNextColumn(ctx)
                w, h = reaper.ImGui_GetContentRegionAvail(ctx)
                if reaper.ImGui_Button(ctx, 'GENERATE', w, h) then
                    button_GENERATE()
                end
                reaper.ImGui_EndDisabled(ctx)
            else
                reaper.ImGui_TableNextColumn(ctx)
                w, h = reaper.ImGui_GetContentRegionAvail(ctx)
                if reaper.ImGui_Button(ctx, 'GENERATE', w, h) then
                    button_GENERATE()
                end
            end
            
            reaper.ImGui_EndTable(ctx)
        end
        
        reaper.ImGui_EndChild(ctx)
    end
end

function GuiPopup()
    reaper.ImGui_OpenPopup(ctx, "popup_disconnecting")
    reaper.ImGui_SetNextWindowPos(ctx, posX, posY)
    reaper.ImGui_SetNextWindowSize(ctx, winW, winH)
    if reaper.ImGui_BeginPopup(ctx, "popup_disconnecting") then
        reaper.ImGui_PushFont(ctx, BIG_FONT)
        _, avail = reaper.ImGui_GetContentRegionAvail(ctx)
        _, h = reaper.ImGui_CalcTextSize(ctx, "W\nD")
        reaper.ImGui_SetCursorPosY(ctx, reaper.ImGui_GetCursorPosY(ctx) + (avail - h) * 0.5)
        avail, _ = reaper.ImGui_GetContentRegionAvail(ctx)
        w, _ = reaper.ImGui_CalcTextSize(ctx, "WAAPI DISCONNECT")
        reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + (avail - w) * 0.5)
        reaper.ImGui_Text(ctx, "WAAPI DISCONNECT")
        avail, _ = reaper.ImGui_GetContentRegionAvail(ctx)
        w, _  = reaper.ImGui_CalcTextSize(ctx, "Disconnecting... Please wait.")
        reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + (avail - w) * 0.5)
        reaper.ImGui_Text(ctx, "Disconnecting... Please wait.")
        reaper.ImGui_PopFont(ctx)
        reaper.ImGui_EndPopup(ctx)
    end
end

function GuiLoop()
    
    local window_flags = reaper.ImGui_WindowFlags_NoCollapse()
    reaper.ImGui_SetNextWindowSize(ctx, winW, winH, reaper.ImGui_Cond_Once())
    reaper.ImGui_PushFont(ctx, FONT)
    reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_ViewportsNoDecoration(), 0)
    
    if preview_mode then 
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), reaper.ImGui_ColorConvertDouble4ToU32(0.2,0,0,0.95))
    end
    if set_events then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), reaper.ImGui_ColorConvertDouble4ToU32(0.0,0.15,0,0.95))
    end 
    
    if set_events then
        if reaper.JS_Window_GetTitle(reaper.JS_Window_GetFocus()) == "trackview" then
            mouse_curr = reaper.JS_Mouse_GetState(1)
            if mouse ~= mouse_curr then
                if mouse_curr == 0 then
                    if reaper.CountSelectedTracks() > 0 then
                        item = script.CreateTextItem(reaper.GetSelectedTrack(0, 0), reaper.GetCursorPosition(), 0.1, events_name)
                        reaper.SetMediaItemSelected(item, true)
                        AddLog({state = "INFO", desc = "Item event created"})
                    end
                end
                mouse = mouse_curr
            end
        end
    end
    -- reaper.DeleteTrackMediaItem(reaper.GetMediaItemTrack(item), item)
    
    local visible, open = reaper.ImGui_Begin(ctx, 'Wwise Timeline cinematic creation tool', true, window_flags)
    
    if visible then
        winW, winH = reaper.ImGui_GetWindowSize(ctx)
        posX, posY = reaper.ImGui_GetWindowPos(ctx)
        if show_popup then
            GuiPopup()
            if reaper.ImGui_GetTime(ctx) > start_time + 0.1 then
                script.DisconnectToWwise()
                is_closed = true
            end
        end
        
        if preview_mode then
            reaper.ImGui_PopStyleColor(ctx)
        end
        if set_events then
            reaper.ImGui_PopStyleColor(ctx)
        end
        
        GuiElements()
        
        reaper.ImGui_End(ctx)
    end
    
    reaper.ImGui_PopFont(ctx)
    
    if open and not is_closed then
        reaper.defer(GuiLoop)
    elseif not is_closed then
        reaper.defer(GuiLoop)
        button_CLOSE()
    end
    
    if preview_mode then
        output = script.PreviewLoop()
        AddLog(output) 
    end
    
    if script.PreviewLogs then
        AddLog(script.PreviewLogs())
    end
    
    if is_started then
        current_time = reaper.ImGui_GetTime(ctx) - start_time
        
        progress_value = current_time / event_duration
    
        if reaper.ImGui_GetTime(ctx) - start_time >= event_duration then
            local import = script.Stop(output_path)
            AddLog(import)
            
            is_started = false
            start_time = 0
            event_duration = 10000
        end
    end
end

function GuiDraw()
    GuiInit()
    GuiLoop()
end

-- MAIN SCRIPT EXECUTION --
reaper.PreventUIRefresh(1)
--reaper.Undo_BeginBlock()
GuiDraw()
--reaper.Undo_EndBlock('Region Renaming Tool used', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()

--------------------------------------------------------------------------------------

function button_CLOSE()
    show_popup = true
    start_time = reaper.ImGui_GetTime(ctx)
end

function button_GENERATE()
    log[#log + 1] = "-----------------[ START TIMELINE GENERATION ]-----------------"
    
    remove = script.WwiseRemove(event_name, "Event")
    AddLog(remove)

    -- CREATE TIMELINE EVENT
    timeline, event_duration = script.CreateTimelineEvent(event_name, output_path, event_length, stereo_downmix)
    
    for i = 1, #timeline do
        AddLog(timeline[i])
    end
    
    if auto_record then
        is_started = true
        start_time = reaper.ImGui_GetTime(ctx)
        record = script.Record(event_name)
        
        for i = 1, #record do
            AddLog(record[i])
        end
    end
    
    return duration
end

function button_BROWSE()
    ret, path = reaper.GetUserFileNameForRead(output_path, "Select a file", "")
    if ret then 
        output_path = path
    end
end

function button_CLEAR_LOGS()
    log = {}
end

function button_CLEAN_WWISE()
    clean = script.CleanWwiseSession()
    
    for i = 1, #clean do
        AddLog(clean)
    end
end