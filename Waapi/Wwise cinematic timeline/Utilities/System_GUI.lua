-- @noindex

local SysGui = {}

function SysGui.Close(time)
    Gui.show_popup = true
    Gui.start_time = time or 0
end

function SysGui.Generate()
    Gui.log[#Gui.log + 1] = "-----------------[ START TIMELINE GENERATION ]-----------------"

    local remove = Sys_waapi.Remove(Gui.event_name, "Event")
    SysGui.AddLog(remove)

    -- CREATE TIMELINE EVENT
    local event_duration = Sys_waapi.CreateTimelineEvent()
    Gui.event_duration = event_duration

    if Gui.auto_record then
        Gui.is_started = true
        Gui.start_time = reaper.ImGui_GetTime(Gui.ctx)
        local record = Sys_waapi.Record()

        for i = 1, #record do
            SysGui.AddLog(record[i])
        end
    end

    return event_duration
end

function SysGui.Browse()
    local retval, path = reaper.GetUserFileNameForRead(Gui.output_path, "Select a file", "")
    if retval then
        return path
    end
end

-- Ajouter un nouveau message de log dans l'interface
function SysGui.AddLog(_output)
    local output = {}
    if not _output then
        output.state = "ERROR"
        output.desc = "Unable to show log (nil value)"
    else
        output = _output
    end
    local time = os.date("*t")
    local str_time = ("%02d:%02d:%02d"):format(time.hour, time.min, time.sec)

    if (Gui.info_logs and output.state == "INFO") or (Gui.warning_logs and output.state == "WARNING") or (Gui.error_logs and output.state == "ERROR") then
        local text = "[".. str_time .."] : [" .. output.state .. "] : " .. output.desc
        table.insert(Gui.log, text)
    end
end

function SysGui.ClearLogs()
    Gui.log = {}
end

function SysGui.CleanWwise()
    local clean = Sys_waapi.CleanWwiseSession()

    for i = 1, #clean do
        SysGui.AddLog(clean)
    end
end

function SysGui.SetButtonState(set)
    local _, _, sec, cmd, _, _, _ = reaper.get_action_context()
    reaper.SetToggleCommandState(sec, cmd, set or 0)
    reaper.RefreshToolbar2(sec, cmd)
end

return SysGui