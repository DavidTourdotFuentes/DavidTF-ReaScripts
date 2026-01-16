-- @noindex

local Gui = {}

-- Shared variables
Gui.ctx = reaper.ImGui_CreateContext('Tags Manager')

-- Local variables
local window_name = ScriptName..' - '..ScriptVersion
local win_W, win_H = 300, 360
local pos_X, pos_Y = 80, 0
local is_open = false
local visible = true
local frame_padding = reaper.ImGui_StyleVar_FramePadding()
local pin = false
local FONT = reaper.ImGui_CreateFont('sans-serif', 15)
reaper.ImGui_Attach(Gui.ctx, FONT)
local BIG_FONT = reaper.ImGui_CreateFont('sans-serif', 25)
reaper.ImGui_Attach(Gui.ctx, BIG_FONT)

local show_tag_bool = false
local tag_pattern = ""
local PREFIX = "["
local SUFFIX = "]"
local cur_tags = {}

function Gui.Init()
    -- Load Reaper settings
    cur_tags = Storage.LoadTagColors()

    Utils.ClearInvalidData()

    show_tag_bool = Storage.LoadShowTagValue()
    tag_pattern = Storage.LoadTagPatternValue()
    PREFIX, SUFFIX = tag_pattern:match("^(.-)<tag>(.*)$")

    if #cur_tags == 0 then
        Storage.InitializeTags()
    end
end

function Gui.Loop()
    Gui.PushTheme()

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
        local win_x = select(1, reaper.ImGui_GetWindowSize(Gui.ctx))
        reaper.ImGui_SetCursorPosX(Gui.ctx, win_x - (text_x * 2))

        if reaper.ImGui_Button(Gui.ctx, " X ") then
            is_open = false
        end

        reaper.ImGui_EndTable(Gui.ctx)
    end
end

function Gui.MainComponents()

    reaper.ImGui_Dummy(Gui.ctx, 0, 1)

    local _, new_show_tag_bool = reaper.ImGui_Checkbox(Gui.ctx, " Show tag", show_tag_bool)
    if new_show_tag_bool ~= show_tag_bool then
        if new_show_tag_bool then
            Utils.ShowHideTagsInRegionNames(PREFIX, SUFFIX, false)
            reaper.SetExtState(Storage.section, "ShowTags", "true", true)
        else
            Utils.ShowHideTagsInRegionNames(PREFIX, SUFFIX, true)
            reaper.SetExtState(Storage.section, "ShowTags", "false", true)
        end
        show_tag_bool = new_show_tag_bool
    end

    reaper.ImGui_SameLine(Gui.ctx, 0, 10)
    reaper.ImGui_PushItemWidth(Gui.ctx, 145)
    local _, new_tag_pattern = reaper.ImGui_InputText(Gui.ctx, '##showtag_string', tag_pattern)

    reaper.ImGui_SameLine(Gui.ctx, 0, -1)
    if reaper.ImGui_Button(Gui.ctx, " R ") then
        new_tag_pattern = Storage.DefaultTagTemplateText .. " "
    end

    if new_tag_pattern ~= tag_pattern then
        local new_prefix, new_suffix = new_tag_pattern:match("^(.-)<tag>(.*)$")

        if (new_prefix ~= nil) and (new_suffix ~= nil) then
            Utils.RenameTagPrefixInRegionNames(PREFIX, SUFFIX, new_prefix, new_suffix)
            tag_pattern = new_tag_pattern
            PREFIX = new_prefix
            SUFFIX = new_suffix

            reaper.SetExtState(Storage.section, "TagPattern", tag_pattern, true)
        end
    end

    reaper.ImGui_Dummy(Gui.ctx, 0, 1)
    reaper.ImGui_Separator(Gui.ctx)
    reaper.ImGui_Dummy(Gui.ctx, 0, 1)

    if reaper.ImGui_BeginTable(Gui.ctx, 'tags_list', 3, reaper.ImGui_TableFlags_SizingStretchProp()) then

        for i, curTag in ipairs(cur_tags) do
            reaper.ImGui_TableNextRow(Gui.ctx)
            reaper.ImGui_TableNextColumn(Gui.ctx)

            reaper.ImGui_Text(Gui.ctx, i)

            reaper.ImGui_TableNextColumn(Gui.ctx)

            reaper.ImGui_PushItemWidth(Gui.ctx, -1)
            local _, new_tag = reaper.ImGui_InputText(Gui.ctx, '##tag_' .. i .. '_txt', curTag.tag)

            if new_tag ~= curTag.tag then
                local alreadySet = false
                for i, scannedTag in ipairs(cur_tags) do
                    if new_tag == scannedTag.tag and new_tag ~= curTag.tag then
                        alreadySet = true
                    end
                end

                if alreadySet then
                    new_tag = curTag.tag
                else
                    Utils.RenameTagNameInRegionNames(PREFIX, SUFFIX, curTag.tag, new_tag)
                    Utils.UpdateRegionsTags(curTag.tag, new_tag)

                    curTag.tag = new_tag
                    cur_tags[i].tag = new_tag
                    Storage.SaveTagsList(cur_tags)
                end
            end
            reaper.ImGui_TableNextColumn(Gui.ctx)
            local currentColor = reaper.ColorToNative(curTag.color[1], curTag.color[2], curTag.color[3])
            local _, newColor = reaper.ImGui_ColorEdit3(Gui.ctx, '##tag_' .. i .. '_col', currentColor,reaper.ImGui_ColorEditFlags_NoInputs()
            
            )
            if newColor ~= currentColor then
                local r, g, b = reaper.ColorFromNative(newColor)
                curTag.color = {r, g , b}
                cur_tags[i].color = {r, g , b}
                Storage.SaveTagsList(cur_tags)

                Utils.UpdateRegionsColor(curTag)
            end
        end
        reaper.ImGui_EndTable(Gui.ctx)
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