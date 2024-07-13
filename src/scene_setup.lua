local draw = require 'draw_utils'
local button = require 'button'
local timeline_scroll = require 'timeline_scroll'

local slider = function (w, h, fn)
  local s = {}

  s.x = 0
  s.y = 0
  s.v = 0

  local held = false
  local held_initial_v
  -- local held_offs_x, held_offs_y

  s.press = function (x, y)
    if x >= s.x - w/2 and x <= s.x + w/2 and
       y >= s.y - h/2 and y <= s.y + h/2 then
      held = true
      held_initial_v = s.v
      s.move(x, y)
      return true
    else
      return false
    end
  end

  s.cancel = function (x, y)
    if held then s.v = held_initial_v end
    held = false
    fn()
  end

  s.move = function (x, y)
    if not held then return false end
    s.v = math.max(-0.5, math.min(0.5, (x - s.x) / w))
    fn()
    return true
  end

  s.release = function (x, y)
    if not held then return false end
    held = false
    return true
  end

  s.update = function ()
  end

  s.draw = function (r, g, b)
    local cx, cy = s.x + w * s.v, s.y
    local track_h = 10
    love.graphics.setColor(r/4, g/4, b/4)
    love.graphics.rectangle('fill', s.x - w/2, s.y - track_h/2, w, track_h)
    love.graphics.circle('fill', s.x - w/2, s.y, track_h/2)
    love.graphics.circle('fill', s.x + w/2, s.y, track_h/2)
    love.graphics.setColor(r/2, g/2, b/2)
    love.graphics.circle('fill', cx + 1, cy + 1, 16)
    love.graphics.setColor(r, g, b)
    love.graphics.circle('fill', cx, cy, 16)
  end

  return s
end

return function ()
  local s = {}
  local W, H = W, H
  local font = _G['global_font']

  local t1 = love.graphics.newText(font(36), '游玩使用的是……')
  local t2a = love.graphics.newText(font(36), '滚动灵敏度')
  local t2b = love.graphics.newText(font(36), '滚动灵敏度（固定）')
  local t3a = love.graphics.newText(font(28), '请尝试在任意处滚动滚轮')
  local t3b = love.graphics.newText(font(28), '请尝试在任意处用双指上下滑动')

  local mode_sel = 1
  local sld_sens

  local tl = timeline_scroll()
  for i = 1, 100 do tl.add_tick(i, i) end
  tl.tx = 10
  tl.dx = 10

  local scroll_accum = 0
  local SCROLL_ACCUM_LIMIT = 8
  local tl_last = nil

  local update_options = function ()
    _G['trackpadMode'] = (mode_sel == 2)
    if mode_sel == 3 then
      _G['scrollRate'] = 1
    else
      -- Map -0.5 ~ 0 ~ 0.5 to 0 ~ 1 ~ 4
      local v = (sld_sens.v + 0.5) * 2
      if v > 1 then v = v * (v + 2) / 3 end
      _G['scrollRate'] = 0.1 + v * (mode_sel == 2 and 0.1 or 0.9)
    end
    _G['is_touch'] = (mode_sel == 3)
  end

  local btn_mouse = button(
    draw.enclose(love.graphics.newText(font(36), '鼠标'), 160, 70),
    function () mode_sel = 1 update_options() end
  )
  btn_mouse.x, btn_mouse.y = W * 0.45, H * 0.30
  local btn_trackpad = button(
    draw.enclose(love.graphics.newText(font(36), '触控板'), 160, 70),
    function () mode_sel = 2 update_options() end
  )
  btn_trackpad.x, btn_trackpad.y = W * 0.625, H * 0.30
  local btn_touchscreen = button(
    draw.enclose(love.graphics.newText(font(36), '触屏'), 160, 70),
    function () mode_sel = 3 update_options() end
  )
  btn_touchscreen.x, btn_touchscreen.y = W * 0.8, H * 0.30

  sld_sens = slider(W * 0.4, H * 0.1, update_options)
  sld_sens.x, sld_sens.y = W * 0.625, H * 0.50

  local btn_start = button(
    draw.enclose(love.graphics.newText(font(36), '进入游戏'), 200, 70),
    function () replaceScene(_G['scene_gameplay'](), transitions['fade'](0.1, 0.1, 0.1)) end
  )
  btn_start.x, btn_start.y = W * 0.5, H * 0.71
  local buttons = { btn_mouse, btn_trackpad, btn_touchscreen, btn_start }

  update_options()

  s.press = function (x, y)
    for i = 1, #buttons do if buttons[i].press(x, y) then return true end end
    if mode_sel ~= 3 and sld_sens.press(x, y) then return true end
  end

  s.cancel = function (x, y)
    for i = 1, #buttons do buttons[i].cancel(x, y) end
    sld_sens.cancel(x, y)
  end

  s.hover = function (x, y)
  end

  s.move = function (x, y)
    for i = 1, #buttons do if buttons[i].move(x, y) then return true end end
    if mode_sel ~= 3 and sld_sens.move(x, y) then return true end
  end

  s.release = function (x, y)
    for i = 1, #buttons do if buttons[i].release(x, y) then return true end end
    if mode_sel ~= 3 and sld_sens.release(x, y) then return true end
  end

  s.update = function ()
    for i = 1, #buttons do buttons[i].update() end
    sld_sens.update()

    scroll_accum = math.max(0, scroll_accum * 0.95 - 0.1)
    tl.update()
    local delta = (tl.tx - 10) % 4 + 10 - tl.tx
    tl.dx = tl.dx + delta
    tl.tx = tl.tx + delta
    local tl_cur = math.floor(tl.dx + 0.5)
    if tl_cur ~= tl_last then
      tl_last = tl_cur
      scroll_accum = SCROLL_ACCUM_LIMIT
    end
  end

  s.draw = function ()
    love.graphics.clear(0.1, 0.1, 0.1)
    love.graphics.setColor(1, 1, 1)

    draw.shadow(0.95, 0.95, 0.95, 1, t1, W * 0.1, H * 0.30, nil, nil, 0, 0.5)
    local mode_btns = {btn_mouse, btn_trackpad, btn_touchscreen}
    for i = 1, #mode_btns do
      -- Shadow
      if i == mode_sel then love.graphics.setColor(0.475, 0.475, 0.475)
      else love.graphics.setColor(0.25, 0.25, 0.25) end
      mode_btns[i].draw()
      -- Real
      if i == mode_sel then love.graphics.setColor(0.95, 0.95, 0.95)
      else love.graphics.setColor(0.5, 0.5, 0.5) end
      mode_btns[i].draw()
    end

    if mode_sel ~= 3 then
      draw.shadow(0.95, 0.95, 0.95, 1, t2a, W * 0.1, H * 0.48, nil, nil, 0, 0.5)
      draw.shadow(0.95, 0.95, 0.95, 1, t3a, W * 0.1, H * 0.55, nil, nil, 0, 0.5)
    else
      draw.shadow(0.95, 0.95, 0.95, 1, t2b, W * 0.1, H * 0.48, nil, nil, 0, 0.5)
      draw.shadow(0.95, 0.95, 0.95, 1, t3b, W * 0.1, H * 0.55, nil, nil, 0, 0.5)
    end

    if mode_sel ~= 3 then
      sld_sens.draw(0.95, 0.95, 0.95)
    end

    local cx, cy, cr = W * 0.2, H * 0.62, H * 0.05
    -- local a = tl.dx % 2 * math.pi
    -- love.graphics.circle('fill', cx + math.cos(a) * cr, cy + math.sin(a) * cr, 10)
    local a = math.abs(1 - tl.dx % 2) * 2 - 1
    love.graphics.setColor(0.25, 0.25, 0.25)
    love.graphics.circle('fill', cx - cr, cy, 8)
    love.graphics.circle('fill', cx + cr, cy, 8)
    love.graphics.rectangle('fill', cx - cr, cy - 4, cr * 2, 8)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.circle('fill', cx + a * cr, cy, 10)

    love.graphics.setColor(0.475, 0.475, 0.475) btn_start.draw(1, 1)
    love.graphics.setColor(0.950, 0.950, 0.950) btn_start.draw()
    btn_start.draw()
  end

  s.wheel = function (x, y, x_raw, y_raw)
    -- XXX: DRY!
    local limit = SCROLL_ACCUM_LIMIT - scroll_accum
    if y < -limit then y = -limit
    elseif y > limit then y = limit end
    scroll_accum = scroll_accum + math.abs(y)

    tl.push(y)
  end

  s.destroy = function ()
  end

  return s
end
