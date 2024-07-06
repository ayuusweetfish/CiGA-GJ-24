local draw = require 'draw_utils'

local timeline_scroll = function ()
  local s = {}

  s.dx = 0.5
  s.tx = 0.5

  local carousel_target

  s.push = function (dx)
    s.tx = s.tx + dx
  end

  s.update = function ()
    s.dx = s.dx + (s.tx - s.dx) * 0.3

    -- Pull towards target
    if carousel_target ~= nil then
      s.dx = s.dx + (carousel_target - s.dx) * 0.6
    else
      -- Pull into range
      if s.tx < 0 then
        s.tx = s.tx + (0 - s.tx) * 0.3
      elseif s.tx > 1 then
        s.tx = s.tx + (1 - s.tx) * 0.3
      end
    end
  end

  return s
end

return function ()
  local s = {}
  local W, H = W, H
  local font = _G['global_font']

  local objs = {
    {x = 0.4*W, y = 0.7*H, rx = 100, ry = 120, img = 'bee'},
  }

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
      end
      zoom_pressed = false
      return true
    end

    p_hold_time, p_rel_time = -1, 0
    for i = 1, #objs do
      local o = objs[i]
      local dist = dist_ellipse(o.rx, o.ry, px - o.x, py - o.y)
      if dist <= pr then
        print('hit')
        -- Activate object
        zoom_obj = o
        zoom_in_time, zoom_out_time = 0, -1
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
    love.graphics.circle('line', px_anim, py_anim, pr)
    love.graphics.setColor(1, 0.8, 0.7, p_alpha)
    love.graphics.circle('fill', px_anim, py_anim, pr)

    love.graphics.setColor(1, 0.8, 0.7, 0.3)
    for i = 1, #objs do
      local o = objs[i]
      love.graphics.ellipse('fill', o.x, o.y, o.rx, o.ry)
    end

    -- Timeline
    tl.update()
    love.graphics.setColor(1, 1, 1)
    love.graphics.line(W * 0.85, H * 0.1, W * 0.85, H * 0.9)
    love.graphics.circle('fill', W * 0.85, H * (0.1 + tl.dx * 0.8), 20)
  end

  s.wheel = function (x, y)
    tl.push(y * 0.01)
  end

  s.destroy = function ()
  end

  return s
end
