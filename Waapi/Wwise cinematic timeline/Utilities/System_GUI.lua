-- @noindex

local SysGui = {}

function SysGui.Close(time)
    gui.show_popup = true
    gui.start_time = time or 0
end

function SysGui.Generate()
    gui.log[#gui.log + 1] = "-----------------[ START TIMELINE GENERATION ]-----------------"

    local remove = sys_waapi.Remove(gui.event_name, "Event")
    SysGui.AddLog(remove)

    -- CREATE TIMELINE EVENT
    local event_duration = sys_waapi.CreateTimelineEvent()
    gui.event_duration = event_duration

    if gui.auto_record then
        gui.is_started = true
        gui.start_time = reaper.ImGui_GetTime(gui.ctx)
        local record = sys_waapi.Record()

        for i = 1, #record do
            SysGui.AddLog(record[i])
        end
    end

    return duration
end

function SysGui.Browse()
    local retval, path = reaper.GetUserFileNameForRead(gui.output_path, "Select a file", "")
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
    local strTime = ("%02d:%02d:%02d"):format(time.hour, time.min, time.sec)

    if (gui.info_logs and output.state == "INFO") or (gui.warning_logs and output.state == "WARNING") or (gui.error_logs and output.state == "ERROR") then
        local text = "[".. strTime .."] : [" .. output.state .. "] : " .. output.desc
        table.insert(gui.log, text)
    end
end

function SysGui.ClearLogs()
    gui.log = {}
end

function SysGui.CleanWwise()
    local clean = sys_waapi.CleanWwiseSession()

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