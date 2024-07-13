local draw = require 'draw_utils'
local scroll = require 'scroll'

return function ()
  local s = {}

  local ticks = {}
  local tags = {}

  s.dx = 1
  s.tx = 1
  s.ticks = ticks
  s.tags = tags
  s.dx_disp = 0
  s.sel_tag = nil
  s.blur_disp = 0

  s.add_tick = function (t, tag)
    local pos = #ticks + 1
    for i = 1, #ticks do
      if ticks[i] > t then
        pos = i
        break
      end
    end
    table.insert(ticks, pos, t)
    table.insert(tags, pos, tag)
    if #ticks >= 2 and s.tx >= pos then
      s.tx = s.tx + 1
      s.dx = s.dx + 1
    end
    s.x_max = #ticks
  end

  s.remove_tick = function (tag)
    local pos
    for i = 1, #ticks do
      if tags[i] == tag then
        pos = i
        break
      end
    end
    if pos ~= nil then
      table.remove(ticks, pos)
      table.remove(tags, pos)
      if s.tx >= pos then
        s.tx = s.tx - 1
        s.dx = s.dx - 1
      end
      s.x_max = #ticks
    end
  end

  s.find_tag = function (tag)
    for i = 1, #tags do if tags[i] == tag then return i end end
  end

  s.modify_tag = function (old_tag, new_tag)
    for i = 1, #tags do if tags[i] == old_tag then
      tags[i] = new_tag
      return
    end end
  end

  s.push = function (dx)
    s.tx = s.tx + dx * 0.05
  end

  local pull_near = function (a, b, rate)
    local diff = b - a
    if math.abs(diff) < 1e-5 then return b
    else return a + (b - a) * rate end
  end

  s.update = function ()
    local x_min, x_max = 1, #ticks

    -- Pull into range
    if s.tx < x_min then
      s.tx = pull_near(s.tx, x_min, 0.08)
    elseif s.tx > x_max then
      s.tx = pull_near(s.tx, x_max, 0.08)
    else
      local i = math.floor(s.tx)
      target = i + (s.tx < i + 0.5 and 0 or 1)
      s.tx = pull_near(s.tx, target, 0.02)
    end

    s.dx = pull_near(s.dx, s.tx, 0.08)

    if x_max == 1 then
      s.dx_disp = ticks[1]
      s.sel_tag = tags[1]
      s.blur_disp = 0
    elseif s.dx < x_min then
      s.dx_disp = ticks[x_min] - math.min(0.5, ticks[x_min + 1] - ticks[x_min]) * (x_min - s.dx)
      s.sel_tag = tags[x_min]
      s.blur_disp = 0
    elseif s.dx >= x_max then
      s.dx_disp = ticks[x_max] + math.min(0.5, ticks[x_max] - ticks[x_max - 1]) * (s.dx - x_max)
      s.sel_tag = tags[x_max]
      s.blur_disp = 0
    else
      local i = math.floor(s.dx)
      if ticks[i + 1] - ticks[i] > 1 then
        local t = s.dx - i
        -- f(0) = 0
        -- f(0.5) = 1
        -- f(1) = ticks[i + 1] - ticks[i]
        local f = function (t)
          if t < 0.5 then return t * 2
          else return (ticks[i + 1] - ticks[i] - 1) * (t - 0.5) * 2 + 1 end
        end
        if ticks[i] < 0 then
          s.dx_disp = ticks[i + 1] - f(1 - t)
        else
          s.dx_disp = ticks[i] + f(t)
        end
      else
        s.dx_disp = ticks[i] + (ticks[i + 1] - ticks[i]) * (s.dx - i)
      end
      i = math.floor(s.dx + 0.5)
      s.sel_tag = tags[i]
      s.blur_disp = math.abs(s.dx - i) * 2
    end
  end

  return s
end

