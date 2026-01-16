-- @noindex
local Utils = {}

package.path = package.path..';'..debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;"

Storage = require('Utilities/Storage')

function Utils.UpdateRegionsColor(tagToChange)

    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)

    for i = 0, num_markers + num_regions - 1 do
        local retval, isrgn, pos, rgnend, name, idx = reaper.EnumProjectMarkers(i)
        if isrgn then            
            local _, guid = reaper.GetSetProjectInfo_String(0, "MARKER_GUID:" .. idx, "", false)

            local region_tag = select(2, reaper.GetProjExtState(0, Storage.section, guid))

            if tagToChange.tag == region_tag then

                local r = tagToChange.color[1]
                local g = tagToChange.color[2]
                local b = tagToChange.color[3]

                reaper.SetProjectMarkerByIndex(0, i, true, pos, rgnend, idx, name, reaper.ColorToNative(b, g, r) | 0x1000000)
            end
        end
    end
end

local function escape_lua_pattern(s)
    return s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

function Utils.ShowHideTagsInRegionNames(prefix, suffix, clear)
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)

    for i = 0, num_markers + num_regions - 1 do
        local _, isrgn, pos, rgnend, name, idx = reaper.EnumProjectMarkers(i)
        if isrgn then
            local _, guid = reaper.GetSetProjectInfo_String(0, "MARKER_GUID:" .. idx, "", false)

            local region_tag = select(2, reaper.GetProjExtState(0, Storage.section, guid))

            if region_tag then
                if not clear then
                    local new_name = prefix .. region_tag .. suffix .. name
                    reaper.SetProjectMarker(idx, isrgn, pos, rgnend, new_name)
                else
                    local restored_name = name
                    local pattern = "^" .. escape_lua_pattern(prefix .. region_tag .. suffix)
                    restored_name = restored_name:gsub(pattern, "", 1)
                    reaper.SetProjectMarker(idx, isrgn, pos, rgnend, restored_name)
                end
            end
        end
    end
end

function Utils.RenameTagNameInRegionNames(prefix, suffix, old_tag, new_tag)
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)

    for i = 0, num_markers + num_regions - 1 do
        local _, isrgn, pos, rgnend, name, idx = reaper.EnumProjectMarkers(i)
        if isrgn and name ~= "" then
            -- Vérifier si le nom commence par prefix..region_tag..suffix
            local pattern = "^" .. escape_lua_pattern(prefix .. old_tag .. suffix)

            if name:match(pattern) then
                -- Remplacer region_tag par new_region_tag
                local new_name = name:gsub(pattern, prefix .. new_tag .. suffix, 1)
                reaper.SetProjectMarker(idx, isrgn, pos, rgnend, new_name)
            end
        end
    end
end

function Utils.RenameTagPrefixInRegionNames(prefix, suffix, new_prefix, new_suffix)
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)

    for i = 0, num_markers + num_regions - 1 do
        local _, isrgn, pos, rgnend, name, idx = reaper.EnumProjectMarkers(i)
        if isrgn and name ~= "" then
            local _, guid = reaper.GetSetProjectInfo_String(0, "MARKER_GUID:" .. idx, "", false)
            local region_tag = select(2, reaper.GetProjExtState(0, Storage.section, guid))

            if region_tag then
                local p = escape_lua_pattern(prefix)
                local s = escape_lua_pattern(suffix)

                -- Limiter à 1 remplacement
                local output = name:gsub(p .. "(.-)" .. s, function(tag)
                    return new_prefix .. tag .. new_suffix
                end, 1)

                reaper.SetProjectMarker(idx, isrgn, pos, rgnend, output)
            end
        end
    end
end

function Utils.UpdateRegionsTags(old_tag, new_tag)
    local last = false
    local i = 0
    while (last == false) and (i <= 10000) do
        local retval, guid, tag = reaper.EnumProjExtState(0, Storage.section, i)
        
        if retval then

            if tag == old_tag then
                reaper.SetProjExtState(0, Storage.section, guid, new_tag)
            end

        else
            last = true
        end

        i = i + 1
    end
end

function Utils.GetRegionInTimeSelection()

    Utils.ClearInvalidData()

    local regions_in_selection = {}

    local time_sel_start, time_sel_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

    if time_sel_start == time_sel_end then
        reaper.ShowMessageBox("Aucune sélection temporelle active.", "Info", 0)
        return {}
    end


    -- Compte marqueurs/régions
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)

    -- Parcourt tous les marqueurs et garde seulement les régions
    for i = 0, num_markers + num_regions - 1 do
        local retval, isrgn, pos, rgnend, name, idx = reaper.EnumProjectMarkers(i)
        if isrgn then
            local found, guid = reaper.GetSetProjectInfo_String(0, "MARKER_GUID:" .. idx, "", false)

            if pos >= time_sel_start and rgnend <= time_sel_end then
                table.insert(regions_in_selection, {
                    guid = guid,
                    index = idx,
                    name = name,
                    start_pos = pos,
                    end_pos = rgnend
                })
            end
        end
    end

    return regions_in_selection
end

function Utils.ClearInvalidData()

    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)

    local last = false
    local i = 0
    while (last == false) and (i <= 10000) do
        local retval, guid, tag = reaper.EnumProjExtState(0, Storage.section, i)
        
        if retval then
            local found = false

            -- Parcourt tous les marqueurs et garde seulement les régions
            for j = 0, num_markers + num_regions - 1 do
                local _, isrgn, _, _, _, idx = reaper.EnumProjectMarkers(j)
                if isrgn then
                    local _, region_guid = reaper.GetSetProjectInfo_String(0, "MARKER_GUID:" .. idx, "", false)

                    if guid == region_guid then
                        found = true
                        break
                    end
                end
            end

            if not found then reaper.SetProjExtState(0, Storage.section, guid, "") end

        else
            last = true
        end

        i = i + 1
    end
end

return Utils