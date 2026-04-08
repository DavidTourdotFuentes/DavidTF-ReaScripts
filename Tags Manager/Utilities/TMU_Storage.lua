--@noindex
--@description Storage
--@author david
--@about All storage

local Storage = {}

Storage.defaultTags = {
  { tag = "Done", color = 20036608, show = true},
  { tag = "Wip", color = 30590491, show = true},
  { tag = "ToDo", color = 30752318, show = true},
  { tag = "Deleted", color = 29425664, show = false},
  { tag = "AMB", color = 17816476, show = false},
  { tag = "MX", color = 30752466, show = false},
  { tag = "SFX", color = 31296000, show = false},
  { tag = "Y", color = 33488638, show = false},
  { tag = "N", color = 18290455, show = false},
}

Storage.section = "david_TagsManager"
Storage.TagsListKey = "TagList"
Storage.DefaultTagTemplateText =  "[<tag>]"

function Storage.SetDefaultTags()
    local tags = {}

	reaper.PreventUIRefresh(1)

    -- Scan ruler lanes
    local landID = 0
    local lastLaneFound = false
    while (landID < 16) or (not lastLaneFound) do
        local retval, valuestrNeedBig = reaper.GetSetProjectInfo_String(0, "RULER_LANE_NAME:1", "", false)

        if not retval then
            lastLaneFound = true
            break
        end

		reaper.Main_OnCommand(43524, 0)

        landID = landID + 1
    end

	for i, curTag in ipairs(Storage.defaultTags) do
		reaper.Main_OnCommand(43541, 0)
		
		Utils.UpdateTagName(i, curTag.tag)
		Utils.UpdateTagColor(i, curTag)
		Utils.UpdateTagVisibility(i, curTag.show)
	end

	-- Remove ruler lane 10
	reaper.Main_OnCommand(43533, 0)

	reaper.PreventUIRefresh(-1)

    return tags
end

function Storage.CheckRuleLanesChanges(curTags)

  local curLanes = {}

  -- Scan ruler lanes
  local landID = 0
  local lastLaneFound = false
  while (landID < 16) or (not lastLaneFound) do
    local retval, valuestrNeedBig = reaper.GetSetProjectInfo_String(0, "RULER_LANE_NAME:"..landID, "", false)
    local rulerLaneColor = reaper.GetSetProjectInfo(0, "RULER_LANE_COLOR:"..landID, 0, false)
    local rulerLaneVisibility = reaper.GetSetProjectInfo(0, "RULER_LANE_HIDDEN:"..landID, 0, false) == 0

    if not retval then
      lastLaneFound = true
      break
    end

    table.insert(curLanes, {tag = valuestrNeedBig, color =  0x1000000 | reaper.ImGui_ColorConvertNative(rulerLaneColor), show = rulerLaneVisibility})

    landID = landID + 1
  end

  SyncLanesToTags(curLanes, curTags)

end

function SyncLanesToTags(curLanes, curTags)
    -- Créer un index par nom pour accès rapide
    local tagsByName = {}
    for _, tag in ipairs(curTags) do
        tagsByName[tag.tag] = tag
    end

    local lanesByName = {}
    for _, lane in ipairs(curLanes) do
		lanesByName[lane.tag] = lane
    end

    -- Ajouter les lanes manquantes dans curTags
    for i, lane in ipairs(curLanes) do
        if curTags[i] == nil or curTags[i].tag ~= lane.name then
            curTags[i] = { tag = lane.tag, color = lane.color, show = lane.show }
        end
    end

    -- Retirer les tags en trop
    for i = #curTags, #curLanes + 1, -1 do
        table.remove(curTags, i)
    end
end

return Storage
