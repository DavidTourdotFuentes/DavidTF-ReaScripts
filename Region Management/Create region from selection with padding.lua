--@description Create region from selection with padding
--@author DavidTF
--@version 1.0
--@changelog
--    Initial release
--@about
--    Create region from selection with padding


function get_time_selection()
  start_pos, end_pos = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  
  return start_pos, end_pos
end

function create_region(reg_start, reg_end, name)
  local index = reaper.AddProjectMarker2(0, true, reg_start, reg_end, name, -1, 0)
end

------------------

gap = 0.01 -- Space before and after time selection added to region


reaper.Undo_BeginBlock()

start_pos, end_pos = get_time_selection()

create_region(start_pos - gap, end_pos + gap, "")

reaper.UpdateArrange()
reaper.Undo_EndBlock("Create region from selection with padding", 0)
                 
