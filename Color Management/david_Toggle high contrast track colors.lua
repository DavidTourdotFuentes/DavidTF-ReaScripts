--@description Toggle high contrast track colors
--@author DavidTF
--@version 1.0
--@changelog
--    First commit
--@about
--    First commit

local function int_to_hex(color)
    local r = (color >> 16) & 0xFF
    local g = (color >> 8) & 0xFF
    local b = color & 0xFF

    return string.format("#%02X%02X%02X", r, g, b)
end

local function hex_to_int(hex)
    hex = hex:gsub("#", "")

    return tonumber(hex, 16)
end

local function rgb_to_bgr(hex)
    hex = hex:gsub("#", "")

    local r = hex:sub(1, 2)
    local g = hex:sub(3, 4)
    local b = hex:sub(5, 6)

    return string.format("#%s%s%s", b, g, r)
end

local function hex_to_hsb(hex)
    hex = hex:gsub("#", "") -- Retire le caractère '#' si présent
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255

    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local delta = max - min

    -- Calcul de la teinte (Hue)
    local hue = 0
    if delta > 0 then
        if max == r then
            hue = (g - b) / delta % 6
        elseif max == g then
            hue = (b - r) / delta + 2
        elseif max == b then
            hue = (r - g) / delta + 4
        end
        hue = hue * 60
        if hue < 0 then hue = hue + 360 end
    end

    -- Saturation
    local saturation = (max == 0) and 0 or (delta / max)

    -- Luminosité
    local brightness = max

    return hue, saturation, brightness
end

local function hsb_to_hex(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c

    local r, g, b
    if h < 60 then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end

    local r_hex = math.floor((r + m) * 255)
    local g_hex = math.floor((g + m) * 255)
    local b_hex = math.floor((b + m) * 255)

    return string.format("#%02X%02X%02X", r_hex, g_hex, b_hex)
end

local function invert_color(hex)
    -- Convertit la couleur hex en HSB
    local h, s, v = hex_to_hsb(hex)

    -- Inverse la teinte (ajout de 180° pour obtenir l'opposé sur la roue chromatique)
    h = (h + 360) % 360

    -- Inverse la luminosité (si v est clair, rendre sombre, et vice versa)
    v = 1 - v

    -- Reconstruit la couleur en hexadécimal
    return hsb_to_hex(h, s, v)
end

local function invert_track_colors()
    local track_count = reaper.CountTracks(0)
    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(0, i)
        local track_color = reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR") & 0xFFFFFF
        local hex_track_color = rgb_to_bgr(int_to_hex(track_color))

        local inverted_color = invert_color(hex_track_color)
        reaper.SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", hex_to_int(inverted_color) | 0x1000000)
    end
end


reaper.Undo_BeginBlock()
invert_track_colors()
reaper.Undo_EndBlock("Toggle high contrast track colors", -1)
reaper.UpdateArrange()
