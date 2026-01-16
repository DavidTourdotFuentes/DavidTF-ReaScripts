-- @description Tags Manager Storage
-- @author David
-- @version 1.0

local Storage = {}

Storage.defaultTags = {
  { tag = "Default", color = {221, 138, 0}},
  { tag = "Stereo", color = {0, 200, 150}},
  { tag = "Mono", color = {255, 215, 0}},
  { tag = "Deleted", color = {255, 75, 75}},
  { tag = "AMB", color = {80, 220, 100}},
  { tag = "MX", color = {80, 170, 255}},
  { tag = "SFX", color = {0, 90, 200}},
  { tag = "Y", color = {150, 80, 200}},
  { tag = "N", color = {255, 90, 200}},
}

Storage.section = "david_TagsManager"
Storage.TagsListKey = "TagList"
Storage.DefaultTagTemplateText =  "[<tag>]"

function Storage.InitializeTags()

  local tagList = {}
  for _, entry in ipairs(Storage.defaultTags) do
    reaper.ShowConsoleMsg("\nInitializing... " .. entry.tag)

    table.insert(tagList, entry.tag)
    reaper.SetExtState(Storage.section, entry.tag, table.concat(entry.color, ","), true)
  end
  reaper.SetExtState(Storage.section, Storage.TagsListKey, table.concat(tagList, ","), true)
end

function Storage.ClearOldTagColors()
    local oldTagList = reaper.GetExtState(Storage.section, Storage.TagsListKey)

    if oldTagList ~= "" then
        for tag in string.gmatch(oldTagList, "[^,]+") do
            reaper.DeleteExtState(Storage.section, tag, true)
        end
        reaper.SetExtState(Storage.section, Storage.TagsListKey, "", true)
    end
end

function Storage.SaveTagsList(tagColors)

  Storage.ClearOldTagColors()

  local tagList = {}
  for _, entry in ipairs(tagColors) do
    table.insert(tagList, entry.tag)
    reaper.SetExtState(Storage.section, entry.tag, table.concat(entry.color, ","), true)
  end
  reaper.SetExtState(Storage.section, Storage.TagsListKey, table.concat(tagList, ","), true)
end

function Storage.GetTagByID(id)
  local tags = {}
  local tagList = reaper.GetExtState(Storage.section, Storage.TagsListKey)
  if tagList == "" then return tags end

  for tag in string.gmatch(tagList, "[^,]+") do
    local colorString = reaper.GetExtState(Storage.section, tag)
    local r,g,b = colorString:match("(%d+),(%d+),(%d+)")
    if r and g and b then
      table.insert(tags, {
        tag = tag,
        color = {tonumber(r), tonumber(g), tonumber(b)}
      })
    end
  end
  return tags[id]
end

function Storage.LoadTagColors()
  local tags = {}
  local tagList = reaper.GetExtState(Storage.section, Storage.TagsListKey)
  if tagList == "" then return tags end

  for tag in string.gmatch(tagList, "[^,]+") do
    local colorString = reaper.GetExtState(Storage.section, tag)
    local r,g,b = colorString:match("(%d+),(%d+),(%d+)")
    if r and g and b then
      table.insert(tags, {
        tag = tag,
        color = {tonumber(r), tonumber(g), tonumber(b)}
      })
    end
  end
  return tags
end

function Storage.LoadShowTagValue()
    local showtag_value = reaper.GetExtState(Storage.section, "ShowTags")
    if showtag_value == "true" then
        return true
    elseif showtag_value == "false" then
        return false
    end
end

function Storage.LoadTagPatternValue()
    local showtag_value = reaper.GetExtState(Storage.section, "TagPattern")
    if showtag_value ~= "" then
        return showtag_value
    else
        reaper.SetExtState(Storage.section, "TagPattern", Storage.DefaultTagTemplateText, true)
        return Storage.DefaultTagTemplateText
    end
end

return Storage