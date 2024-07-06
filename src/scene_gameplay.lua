local draw = require 'draw_utils'

local timeline_scroll = function ()
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

    if s.dx < x_min then
      s.dx_disp = ticks[x_min] - math.min(0.5, ticks[x_min + 1] - ticks[x_min]) * (x_min - s.dx)
      s.sel_tag = tags[x_min]
      s.blur_disp = 0
    elseif s.dx >= x_max then
      s.dx_disp = ticks[x_max] + math.min(0.5, ticks[x_max] - ticks[x_max - 1]) * (s.dx - x_max)
      s.sel_tag = tags[x_max]
      s.blur_disp = 0
    else
      local i = math.floor(s.dx)
      s.dx_disp = ticks[i] + (ticks[i + 1] - ticks[i]) * (s.dx - i)
      i = math.floor(s.dx + 0.5)
      s.sel_tag = tags[i]
      s.blur_disp = math.abs(s.dx - i) * 2
    end
  end

  return s
end

return function ()
  local s = {}
  local W, H = W, H
  local font = _G['global_font']

  local album_ticks = {0, 0.25, 0.5, 0.75, 1, [20] = -100}

  local objs_in_album = {
    [1] = {
      {x = 0.4*W, y = 0.7*H, rx = 100, ry = 120, img = 'bee'},
      {x = 0.4*W, y = 0.5*H, rx = 80, ry = 80, img = 'bee', unlock = 20},
    },
    [2] = {
      {x = 0.7*W, y = 0.4*H, rx = 120, ry = 100, img = 'bee'},
    },
    [3] = {
      {x = 0.5*W, y = 0.5*H, rx = 60, ry = 60, img = 'bee'},
      {x = 0.5*W, y = 0.7*H, rx = 80, ry = 80, img = 'bee', unlock = 20},
    },
    [5] = {
      {x = 0.6*W, y = 0.4*H, rx = 30, ry = 30, img = 'bee'},
    },
    [20] = {
      {x = 0.8*W, y = 0.5*H, rx = 30, ry = 30, img = 'bee'},
    },
  }
  local album_idx = 1
  local objs = objs_in_album[album_idx]

  local PT_INITIAL_R = W * 0.01
  local PT_HELD_R = W * 0.03

  local px, py = W/2, H/2
  local pr = PT_INITIAL_R
  local p_hold_time, p_rel_time = -1, -1
  local px_rel, py_rel

  local zoom_obj = nil
  local zoom_in_time, zoom_out_time = -1, -1
  local zoom_pressed = false

  local tl = timeline_scroll()
  tl.add_tick(album_ticks[1], 1)
  tl.add_tick(album_ticks[2], 2)
  tl.add_tick(album_ticks[5], 5)

  local tl_obj_unlock

  s.press = function (x, y)
    if zoom_obj ~= nil then
      if zoom_in_time >= 120 then
        zoom_pressed = true
      end
      return true
    end

    p_hold_time, p_rel_time = 0, -1
    px, py = x, y
  end

  s.hover = function (x, y)
    if p_hold_time == -1 then px, py = x, y end
  end

  s.move = function (x, y)
  end

  -- https://stackoverflow.com/a/46007540
  local dist_ellipse = function (a, b, px, py)
    if (px*b)*(px*b) + (py*a)*(py*a) <= a*a*b*b then return 0 end
    px = math.abs(px)
    py = math.abs(py)
    local px0, py0 = px, py
    local tx = math.sqrt(2)
    local ty = math.sqrt(2)
    for i = 1, 3 do
      local x = a * tx
      local y = b * ty
      local ex = (a*a - b*b) * (tx*tx*tx) / a
      local ey = (b*b - a*a) * (ty*ty*ty) / b
      local rx = x - ex
      local ry = y - ey
      local qx = px - ex
      local qy = py - ey
      local r = math.sqrt(rx*rx + ry*ry)
      local q = math.sqrt(qx*qx + qy*qy)
      tx = math.min(1, math.max(0, (qx * r / q + ex) / a))
      ty = math.min(1, math.max(0, (qy * r / q + ey) / b))
      t = math.sqrt(tx*tx + ty*ty)
      tx = tx / t
      ty = ty / t
    end
    dx = px0 - a * tx
    dy = py0 - b * ty
    return math.sqrt(dx*dx + dy*dy)
  end

  s.release = function (x, y)
    if zoom_obj ~= nil then
      if zoom_pressed then
        zoom_in_time, zoom_out_time = -1, 0
        if zoom_obj.unlock then
          if album_idx == zoom_obj.unlock then
            if not tl.find_tag(zoom_obj.unlock) then
              tl.add_tick(album_ticks[zoom_obj.unlock], zoom_obj.unlock)
            end
            -- Synchronise timelines
            tl.tx = tl.find_tag(zoom_obj.unlock)
            tl.dx = tl.tx
          end
          tl_obj_unlock = nil
        end
      end
      zoom_pressed = false
      return true
    end

    p_hold_time, p_rel_time = -1, 0
    for i = 1, #objs do
      local o = objs[i]
      local dist = dist_ellipse(o.rx, o.ry, px - o.x, py - o.y)
      if dist <= pr then
        -- Activate object
        zoom_obj = o
        zoom_in_time, zoom_out_time = 0, -1
        -- Object unlocks a tick in the album?
        if o.unlock --[[ and not tl.find_tag(o.unlock) ]] then
          tl_obj_unlock = timeline_scroll()
          tl_obj_unlock.add_tick(album_ticks[album_idx], album_idx)
          tl_obj_unlock.add_tick(album_ticks[o.unlock], o.unlock)
        end
      end
    end
    px_rel, py_rel = px, py
    px, py = x, y
  end

  s.update = function ()
    if zoom_in_time >= 0 then zoom_in_time = zoom_in_time + 1
    elseif zoom_out_time >= 0 then
      zoom_out_time = zoom_out_time + 1
      if zoom_out_time == 120 then
        zoom_obj = nil
        zoom_out_time = -1
      end
    end

    if p_hold_time >= 0 then
      pr = pr + (PT_HELD_R - pr) * 0.01
    elseif pr ~= PT_INITIAL_R then
      pr = pr + (PT_INITIAL_R - pr) * 0.05
      if math.abs(pr - PT_INITIAL_R) < 0.1 then
        pr = PT_INITIAL_R
      end
    end

    if p_hold_time >= 0 then p_hold_time = p_hold_time + 1
    elseif p_rel_time >= 0 then
      p_rel_time = p_rel_time + 1
      if p_rel_time >= 120 then p_rel_time = -1 end
    end

    tl.update()
    album_idx = tl.sel_tag
    if tl_obj_unlock then
      tl_obj_unlock.update()
      album_idx = tl_obj_unlock.sel_tag
    end
    objs = objs_in_album[album_idx]
  end

  s.draw = function ()
    love.graphics.clear(1, 1, 0.99)
    love.graphics.setColor(1, 1, 1)
    draw.img('intro_bg', W / 2, H / 2, W, H)

    if zoom_obj ~= nil then
      local o_alpha, move_prog
      if zoom_in_time >= 0 then
        local x = math.min(1, zoom_in_time / 120)
        o_alpha = 1 - (1 - x) * (1 - x)
        move_prog = (1 - x) * math.exp(-3 * x)
      else
        local x = math.min(1, zoom_out_time / 120)
        o_alpha = (1 - x) * (1 - x) * (1 - x)
        if x < 0.5 then move_prog = x * x * x * 4
        else move_prog = 1 - (1 - x) * (1 - x) * (1 - x) * 4 end
      end
      love.graphics.setColor(1, 1, 1, o_alpha)
      local x_target, y_target = W * 0.275, H * 0.5
      local scale = 0.3 + 0.3 * math.sqrt(math.sqrt(o_alpha))
      draw.img(zoom_obj.img,
        x_target + (zoom_obj.x - x_target) * move_prog,
        y_target + (zoom_obj.y - y_target) * move_prog,
        H * scale, H * scale)
    end

    local p_alpha = 0
    local px_anim, py_anim = px, py
    if p_rel_time >= 0 then
      local x = math.max(0, 1 - p_rel_time / 120)
      p_alpha = x * x
      x = 1 - x ^ 6
      px_anim = px_rel + (px - px_rel) * x
      py_anim = py_rel + (py - py_rel) * x
    elseif p_hold_time >= 0 then
      p_alpha = math.min(1, p_hold_time / 60)
      p_alpha = 1 - (1 - p_alpha) * (1 - p_alpha)
    end
    love.graphics.setColor(1, 0.8, 0.7, 1 - p_alpha)
    love.graphics.setLineWidth(2)
    love.graphics.circle('line', px_anim, py_anim, pr)
    love.graphics.setColor(1, 0.8, 0.7, p_alpha)
    love.graphics.circle('fill', px_anim, py_anim, pr)

    love.graphics.setColor(1, 0.8, 0.7, 0.3)
    for i = 1, #objs do
      local o = objs[i]
      love.graphics.ellipse('fill', o.x, o.y, o.rx, o.ry)
    end

    -- Blur
    local tl0 = tl
    local tl = tl_obj_unlock or tl
    if tl.blur_disp > 0.2 then
      local alpha = (tl.blur_disp - 0.2) / 0.8
      alpha = alpha^(1/3)
      love.graphics.setColor(0.04, 0.04, 0.04, alpha)
      love.graphics.rectangle('fill', 0, 0, W, H)
    end
    -- Timeline
    local timeline_min = tl0.ticks[1]
    local timeline_max = tl0.ticks[#tl0.ticks]
    if tl_obj_unlock then
      timeline_min = math.min(timeline_min, tl_obj_unlock.dx_disp)
      timelaxe_max = math.max(timeline_max, tl_obj_unlock.dx_disp)
    end
    local scale = 0
    if tl.dx_disp < -0.1 and timeline_min < 0 then
      scale = -tl.dx_disp - 0.1
    end
    local y = function (t)
      local y = (t + scale) / (scale * 2 + 1)
      return H * (0.15 + y * 0.7)
    end
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.setLineWidth(4)
    love.graphics.line(W * 0.85, y(timeline_min), W * 0.85, y(timeline_max))
    for i = 1, #tl0.ticks do
      if tl0.tags[i] > 0 then
        love.graphics.circle('fill', W * 0.85, y(tl0.ticks[i]), 12)
      end
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle('fill', W * 0.85, y(tl.dx_disp), 20)
  end

  s.wheel = function (x, y)
    if zoom_obj ~= nil then
      if zoom_in_time >= 120 and tl_obj_unlock
        and zoom_obj.unlock ~= album_idx
      then
        tl_obj_unlock.push(y)
      end
    else
      tl.push(y)
    end
  end

  s.destroy = function ()
  end

  return s
end
