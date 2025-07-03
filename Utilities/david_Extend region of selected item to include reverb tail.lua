--@description Extend region of selected item to include reverb tail
--@author DavidTF
--@version 1.0
--@changelog
--    First commit
--@about
--    Extends the region containing the selected item to include the reverb tails


local item = reaper.GetSelectedMediaItem(0, 0)

if not item then
  reaper.ShowMessageBox("Please select an item", "No item selected", 0)
  return
end
local track = reaper.GetMediaItem_Track(item)

local region_id = 0

local state = "Waiting"

local offVolumeThreshold = 0.0001

local ctx = reaper.ImGui_CreateContext('Overlay')

function PlayTransport()
  local start_time = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

  _, region_id = reaper.GetLastMarkerAndCurRegion(0, start_time)

  reaper.SetEditCurPos(start_time, true, false)

  _, _ = reaper.GetSet_LoopTimeRange2(0, true, false, start_time, start_time, false)

  reaper.OnPlayButton()
end
 
function DrawOverlay()

  local x, y, h, w = GetSelectedItemTCPRect()

  x = (x < 0) and 0 or x
  y = (y < 0) and 0 or y
  h = (h < 0) and 0 or h
  w = (w < 0) and 0 or w

  reaper.ImGui_SetNextWindowSize(ctx, w, h)
  reaper.ImGui_SetNextWindowPos(ctx, x, y)

  -- COLOR
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), 0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), 0x43ff6433)

  local window_flags = reaper.ImGui_WindowFlags_NoTitleBar() |
                      reaper.ImGui_WindowFlags_NoResize() |
                      reaper.ImGui_WindowFlags_NoScrollbar() |
                      reaper.ImGui_WindowFlags_NoInputs()

  reaper.ImGui_Begin(ctx, "Overlay", true, window_flags)

  reaper.ImGui_End(ctx)

  reaper.ImGui_PopStyleColor(ctx, 2)
end


function GetSelectedItemTCPRect()

    local y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")
    local h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")

    local ruler_window = reaper.JS_Window_FindChildByID(reaper.GetMainHwnd(), 1000)

    local _, _, top, _, _ = reaper.JS_Window_GetRect(ruler_window)

    -- Get window
    local arrange = reaper.JS_Window_FindChildByID(reaper.GetMainHwnd(), 1000)

    -- Convert time on screen pixel position
    local arrange_start_time, arrange_end_time = reaper.GetSet_ArrangeView2(0, false, 0, 0)
    local _, ruler_x, _, _, _ = reaper.JS_Window_GetRect(arrange)
    local zoom = reaper.GetHZoomLevel()

    -- Play cursor X
    local playPos_sec = reaper.GetPlayPosition()
    local play_cursor_x = math.floor(ruler_x + (playPos_sec - arrange_start_time) * zoom)

    -- Item X
    local item_pos_sec = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

    local item_x = math.floor(ruler_x + (item_pos_sec - arrange_start_time) * zoom)

    local width = 0
    if item_x < ruler_x then
      item_x = ruler_x
      width = 0
    else
      width = play_cursor_x - item_x
    end

    return item_x, y + top, h, width
end


function MainLoop()
  local peakDB = reaper.Track_GetPeakInfo(track, 0)
  local peakDB_R = reaper.Track_GetPeakInfo(track, 1)
  local peakDBAverage = (peakDB + peakDB_R) / 2

  if (state == "Working") then
    if (peakDBAverage >= offVolumeThreshold) and (state == "Working") then
      
      local play_state = reaper.GetPlayState()

      if play_state & 1 == 1 then
        
        DrawOverlay()

        reaper.defer(MainLoop)
      end
    else
      local pos = reaper.GetPlayPosition()

      local retval, _, rgnstart, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers2(0, region_id)
      reaper.SetProjectMarker2(0, markrgnindexnumber, true, rgnstart, pos + 0.4, name)

    end
  elseif (state == "Waiting") then
    if (peakDBAverage >= offVolumeThreshold) then

      state = "Working"
      reaper.defer(MainLoop)

    else
      reaper.defer(MainLoop)
    end
  end

end

PlayTransport()

MainLoop()