--@noindex
--@description GUIlib
--@author david
--@about All GUI

local Gui = {}

-- Shared variables
Gui.ctx = reaper.ImGui_CreateContext('Tags Manager')

-- Local variables
local window_name = ScriptName..' - '..ScriptVersion
local win_W, win_H = 300, 353
local is_open = false
local visible = true
local FONT = reaper.ImGui_CreateFont('sans-serif', 15)
reaper.ImGui_Attach(Gui.ctx, FONT)
local BIG_FONT = reaper.ImGui_CreateFont('sans-serif', 25)
reaper.ImGui_Attach(Gui.ctx, BIG_FONT)

local show_tag_bool = false
local curTags = {}

function Gui.Init()

end

function Gui.Loop()
    Gui.PushTheme()

    -- Check for rules lanes changes --
    Storage.CheckRuleLanesChanges(curTags)

    -- Window Settings --
    local window_flags = reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_NoTitleBar() | reaper.ImGui_WindowFlags_NoScrollbar() | reaper.ImGui_WindowFlags_NoResize()

    reaper.ImGui_SetNextWindowSize(Gui.ctx, win_W, win_H, reaper.ImGui_Cond_Once())

    -- Font --
    reaper.ImGui_PushFont(Gui.ctx, FONT)
    -- Begin --
    visible, is_open = reaper.ImGui_Begin(Gui.ctx, window_name, true, window_flags)

    if visible then
        win_W, win_H = reaper.ImGui_GetWindowSize(Gui.ctx)
        pos_X, pos_Y = reaper.ImGui_GetWindowPos(Gui.ctx)

        Gui.TopBar()

        Gui.MainComponents()

        reaper.ImGui_End(Gui.ctx)
    end

    Gui.PopTheme()
    reaper.ImGui_PopFont(Gui.ctx)

    if is_open then
        reaper.defer(Gui.Loop)
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
        local text_x, _ = reaper.ImGui_CalcTextSize(Gui.ctx, " X ")

        reaper.ImGui_SetCursorPosX(Gui.ctx, (x  * 2) - 10)

        if reaper.ImGui_Button(Gui.ctx, " X ") then
            is_open = false
        end

        reaper.ImGui_EndTable(Gui.ctx)
    end
end

function Gui.MainComponents()

    reaper.ImGui_Dummy(Gui.ctx, 0, 1)

    reaper.ImGui_BeginChild(Gui.ctx, "table_scroll", 285, 265)

        if reaper.ImGui_BeginTable(Gui.ctx, 'tags_list', 5, reaper.ImGui_TableFlags_SizingStretchProp()) then

            for i, curTag in ipairs(curTags) do
                reaper.ImGui_TableNextRow(Gui.ctx)
                reaper.ImGui_TableNextColumn(Gui.ctx)

                reaper.ImGui_Text(Gui.ctx, i)

                reaper.ImGui_TableNextColumn(Gui.ctx)

                local _, is_show = reaper.ImGui_Checkbox(Gui.ctx, '##tag_' .. i .. '_is_show', curTag.show)
                if is_show ~= curTag.show then
                    curTag.show = is_show
                    Utils.UpdateTagVisibility(i, is_show)
                end

                reaper.ImGui_TableNextColumn(Gui.ctx)

                reaper.ImGui_PushItemWidth(Gui.ctx, -1)
                local _, new_tag = reaper.ImGui_InputText(Gui.ctx, '##tag_' .. i .. '_txt', curTag.tag)

                if new_tag ~= curTag.tag then
                    local alreadySet = false
                    for i, scannedTag in ipairs(curTags) do
                        if new_tag == scannedTag.tag and new_tag ~= curTag.tag then
                            alreadySet = true
                        end
                    end

                    if alreadySet then
                        new_tag = curTag.tag
                    else
                        Utils.UpdateTagName(i, new_tag)

                        curTag.tag = new_tag
                        curTags[i].tag = new_tag
                    end
                end
                reaper.ImGui_TableNextColumn(Gui.ctx)

                local _, newColor = reaper.ImGui_ColorEdit3(Gui.ctx, '##tag_' .. i .. '_col', curTag.color, reaper.ImGui_ColorEditFlags_NoInputs())
                if newColor ~= curTag.color then
                    curTag.color = newColor
                    curTags[i].color = newColor

                    Utils.UpdateTagColor(i, curTag)
                end

                reaper.ImGui_TableNextColumn(Gui.ctx)

                if reaper.ImGui_Button(Gui.ctx, 'x##tag_' .. i .. '_remove') then
                    if 43523 + i <= 43539 then
                        reaper.Main_OnCommand(43523 + i, 0)
                    end
                end
            end
            reaper.ImGui_EndTable(Gui.ctx)
        end

    reaper.ImGui_EndChild(Gui.ctx)

    local availWidth, _ = reaper.ImGui_GetContentRegionAvail(Gui.ctx)
    if reaper.ImGui_Button(Gui.ctx, "Add", (availWidth * 0.33) - 5) then
        table.insert(curTags, {tag = "New tag", color = 0, show = true})

        -- Add rule lane
        reaper.Main_OnCommand(43541, 0)
    end

    reaper.ImGui_SameLine(Gui.ctx)

    if reaper.ImGui_Button(Gui.ctx, "Default Template", (availWidth * 0.66)) then
        Storage.SetDefaultTags()
    end
end

function Gui.PushTheme()
    -- Vars
    reaper.ImGui_PushStyleVar(Gui.ctx, reaper.ImGui_StyleVar_WindowRounding(),   4)
    reaper.ImGui_PushStyleVar(Gui.ctx, reaper.ImGui_StyleVar_ChildRounding(),    2)
    reaper.ImGui_PushStyleVar(Gui.ctx, reaper.ImGui_StyleVar_PopupRounding(),    2)
    reaper.ImGui_PushStyleVar(Gui.ctx, reaper.ImGui_StyleVar_FrameRounding(),    2)
    -- Colors
    reaper.ImGui_PushStyleColor(Gui.ctx, reaper.ImGui_Col_WindowBg(), 0x111111FF)
    reaper.ImGui_PushStyleColor(Gui.ctx, reaper.ImGui_Col_Text(), 0XFFFFFFFF)
end

function Gui.PopTheme()
    reaper.ImGui_PopStyleVar(Gui.ctx, 4)
    reaper.ImGui_PopStyleColor(Gui.ctx, 2)
end

return Gui
