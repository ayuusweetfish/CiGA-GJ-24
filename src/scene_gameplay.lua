local draw = require 'draw_utils'
local audio = require 'audio'
local scroll = require 'scroll'

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

return function ()
  local s = {}
  local W, H = W, H
  local font = _G['global_font']

  local album_ticks = {0, 0.25, 0.5, 0.75, 1, [20] = -100, [21] = 90}
  local album_backgrounds = {
    'intro_bg', 'intro_bg', 'intro_bg', 'intro_bg', 'intro_bg',
    [20] = 'intro_bg',
    [21] = 'intro_bg',
  }
  local album_backgrounds_alter = {
    [2] = 'bee',
    [4] = 'bee',
    [5] = 'bee',
  }

  local objs_in_album = {
    [1] = {
      {x = 0.4*W, y = 0.7*H, rx = 100, ry = 120, zoom_img = 'bee'},
      {x = 0.4*W, y = 0.5*H, rx = 80, ry = 80, zoom_img = 'bee', unlock = 3, unlock_seq = {'intro_bg', 'bee', 'intro_bg', 'bee', 'intro_bg'}, unlocked_img = 'bee'},
    },
    [2] = {
      {x = 0.7*W, y = 0.4*H, rx = 120, ry = 100, zoom_img = 'bee'},
      {x = 0.8*W, y = 0.4*H, rx = 120, ry = 100, zoom_img = 'bee'},
      {x = 0.9*W, y = 0.4*H, rx = 120, ry = 100, zoom_img = 'bee', night_interactable = true},
      {x = 0.6*W, y = 0.4*H, rx = 40, ry = 40, switch = true},
    },
    [3] = {
      {x = 0.5*W, y = 0.5*H, rx = 60, ry = 60, zoom_img = 'bee'},
      {x = 0.2*W, y = 0.3*H, rx = 50, ry = 60, scene_sprites = {'bee', 'intro_bg'}, sprite_w = 50, index = 1, musical_box = 'orchid'},
      {x = 0.5*W, y = 0.7*H, rx = 80, ry = 80, zoom_img = 'bee', unlock = 20, unlock_seq = {'intro_bg', 'bee', 'intro_bg', 'bee', 'intro_bg'}, unlocked_img = 'bee'},
      {x = 0.3*W, y = 0.2*H, rx = 120, ry = 80, zoom_img = 'bee', star_sack = true, child =
        {x = 0.3*W, y = 0.2*H, rx = 120, ry = 80, zoom_img = 'bee', unlock = 4, unlock_seq = {'intro_bg', 'bee', 'intro_bg', 'bee', 'intro_bg'}, unlocked_img = 'bee'}},
    },
    [4] = {
      {x = 0.5*W, y = 0.5*H, rx = 50, ry = 50, zoom_img = 'bee'},
      {x = 0.2*W, y = 0.4*H, rx = 50, ry = 60, scene_sprites = {'bee', 'intro_bg'}, sprite_w = 50, index = 1, musical_box = 'orchid_broken'},
      {x = 0.6*W, y = 0.7*H, rx = 80, ry = 80, zoom_img = 'bee', unlock = 21, unlock_seq = {'intro_bg', 'bee', 'intro_bg', 'bee', 'intro_bg'}, unlocked_img = 'bee'},
    },
    [5] = {
      {x = 0.6*W, y = 0.4*H, rx = 30, ry = 30, zoom_img = 'bee', text = '不知道是什么'},
      {x = 0.2*W, y = 0.4*H, rx = 30, ry = 120, zoom_img = 'bee', cont_scroll = H * 2, letter_initial = true},
      {x = 0.1*W, y = 0.5*H, rx = 30, ry = 120, zoom_img = 'bee', cont_scroll = H * 2, letter_after = true},
      -- {x = 0.3*W, y = 0.5*H, rx = 30, ry = 120, zoom_img = 'bee', text = '知道是什么', letter_after = true},
      {x = 0.4*W, y = 0.6*H, rx = 80, ry = 80, zoom_img = 'bee', text = '不知道是什么', unlock = 1, unlock_seq = {'intro_bg', 'bee', 'intro_bg', 'bee', 'intro_bg'}, unlocked_img = 'bee', letter_after = true},
      {x = 0.5*W, y = 0.5*H, rx = 100, ry = 120, scene_sprites = {'bee', 'intro_bg'}, sprite_w = 100, index = 1},
    },
    [20] = {
      {x = 0.8*W, y = 0.5*H, rx = 30, ry = 30, zoom_img = 'bee'},
    },
    [21] = {
      {x = 0.2*W, y = 0.5*H, rx = 30, ry = 30, zoom_img = 'bee'},
    },
  }
  local album_idx = 5
  local objs = objs_in_album[album_idx]

  local light_on = true     -- Scene 2
  local letter_read = {[4] = false, [5] = false}

  local STAR_SACK_BTNS = {
    {x = W*0.5, y = H*0.5, r = 100, img = 'bee', key = true},
    {x = W*0.4, y = H*0.5, r = 100, img = 'bee', key = true},
    {x = W*0.5, y = H*0.6, r = 100, img = 'bee', key = true},
    {x = W*0.4, y = H*0.6, r = 100, img = 'bee', key = false},
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

  local zoom_text
  local zoom_scroll
  local UNLOCK_SEQ_PROG_RATE = 6
  local zoom_seq_prog

  local sack_btn = nil
  local sack_key_match_time = -1

  local tl = timeline_scroll()
  tl.add_tick(album_ticks[5], 5)

  local tl_obj_unlock

  local s4_seq_time = -1

  s.press = function (x, y)
    if sack_key_match_time >= 0 then return end
    if s4_seq_time >= 0 then return end
    if zoom_obj ~= nil then
      if zoom_in_time >= 120 then
        if zoom_obj.star_sack then
          -- Sack
          local best_dist, best_btn = 1e9, nil
          for i = 1, #STAR_SACK_BTNS do
            local b = STAR_SACK_BTNS[i]
            local dist = (x - b.x) * (x - b.x) + (y - b.y) * (y - b.y)
            if dist < b.r * b.r and dist < best_dist then
              best_dist, best_btn = dist, b
            end
          end
          if best_btn ~= nil then
            sack_btn = best_btn
          else
            zoom_pressed = true
          end
        elseif zoom_scroll ~= nil then
          zoom_scroll.press(y, x)
        else
          zoom_pressed = true
        end
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
    if zoom_scroll ~= nil then zoom_scroll.move(y, x) end
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

  local synchronise_tl = function ()
    local unlock = album_idx
    if not tl.find_tag(unlock) then
      tl.add_tick(album_ticks[unlock], unlock)
    end
    -- Synchronise timelines
    tl.tx = tl.find_tag(unlock)
    tl.dx = tl.tx
    tl.update()
    tl_obj_unlock = nil
  end

  s.release = function (x, y)
    if sack_key_match_time >= 0 then return end
    if s4_seq_time >= 0 then return end
    if zoom_obj ~= nil then
      if zoom_pressed then
        zoom_in_time, zoom_out_time = -1, 0
        if zoom_obj.unlock and album_idx == zoom_obj.unlock then
          synchronise_tl()
        end
        zoom_pressed = false
        audio.sfx('object_close')
      elseif sack_btn then
        local b = sack_btn
        local dist = (x - b.x) * (x - b.x) + (y - b.y) * (y - b.y)
        if dist < b.r * b.r then
          -- Pressed sack button
          b.active = not b.active
          -- Check key match
          local key_match = true
          for i = 1, #STAR_SACK_BTNS do
            if (STAR_SACK_BTNS[i].active or false) ~= STAR_SACK_BTNS[i].key then
              key_match = false
              break
            end
          end
          if key_match then
            zoom_obj.sack_open = true
            sack_key_match_time = 0
            audio.sfx('sack_open')
          else
            audio.sfx('sack_click')
          end
        end
        sack_btn = false
      elseif zoom_scroll then
        if zoom_scroll.release(y, x) == 2 then
          zoom_in_time, zoom_out_time = -1, 0
          if zoom_obj.unlock and album_idx == zoom_obj.unlock then
            synchronise_tl()
          end
          audio.sfx('object_close')
        end
      end
      return true
    end

    p_hold_time, p_rel_time = -1, 0
    local best_dist, best_obj = pr, nil
    for i = 1, #objs do
      local o = objs[i]
      -- Handle scene 2 where objects' interactivity depends on light state
      local valid = (album_idx ~= 2 or o.switch or (light_on == not o.night_interactable))
      -- Handle scenes 4, 5 where objects' interactivity depends on whether the letter has been read
      if letter_read[album_idx] ~= nil then
        local disable_match = nil
        if o.letter_initial then disable_match = true
        elseif o.letter_after then disable_match = false end
        valid = valid and letter_read[album_idx] ~= disable_match
      end
      if valid then
        local dist = dist_ellipse(o.rx, o.ry, px - o.x, py - o.y)
        if dist < best_dist then
          best_dist, best_obj = dist, o
        end
      end
    end
    if best_obj ~= nil then
      local o = best_obj
      -- Activate object
      if o.zoom_img then
        -- Zoom-in; possibly unlocks new album scene
        -- Use the object contained in the sack, if the latter is open (unlocked)
        if o.star_sack and o.sack_open then o = o.child end
        zoom_obj = o
        zoom_in_time, zoom_out_time = 0, -1
        -- Text
        if o.text ~= nil then
          zoom_text = love.graphics.newText(font(42), o.text)
        end
        -- Scrolling
        if o.cont_scroll ~= nil then
          zoom_scroll = scroll({
            x_min = -(o.cont_scroll - H),
            x_max = 0,
          })
        end
        -- Object unlocks a tick in the album?
        if o.unlock --[[ and not tl.find_tag(o.unlock) ]] then
          tl_obj_unlock = timeline_scroll()
          tl_obj_unlock.add_tick(album_ticks[album_idx], album_idx)
          tl_obj_unlock.add_tick(album_ticks[o.unlock], o.unlock)
          zoom_seq_prog = 0
        end
        if o.cont_scroll then
          audio.sfx('letter_paper')
        else
          audio.sfx('object_activate')
        end
      elseif o.scene_sprites then
        -- In-scene image
        o.index = (o.index == #o.scene_sprites and 1 or o.index + 1)
        if o.musical_box then
          -- Music!
          if o.index == 2 then
            audio.sfx(o.musical_box, nil, o.musical_box == 'orchid')
          else
            audio.sfx_stop(o.musical_box)
          end
        end
      elseif o.switch then
        -- Light switch
        light_on = not light_on
      end
      if o.letter_initial then
        letter_read[album_idx] = true
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
        if zoom_text then
          zoom_text:release()
          zoom_text = nil
        end
        zoom_scroll = nil
        tl_obj_unlock = nil
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
    local last_album_idx = album_idx
    album_idx = tl.sel_tag
    if tl_obj_unlock then
      tl_obj_unlock.update()
      album_idx = tl_obj_unlock.sel_tag
    end
    if album_idx ~= last_album_idx then
      -- Stop sounds
      for i = 1, #objs do
        local o = objs[i]
        if o.musical_box then
          audio.sfx_stop(o.musical_box)
          o.index = 1   -- Turn off
        end
      end
      -- Update objects
      objs = objs_in_album[album_idx]
    end

    if zoom_scroll ~= nil then
      zoom_scroll.update()
    end

    if sack_key_match_time >= 0 then
      sack_key_match_time = sack_key_match_time + 1
      if sack_key_match_time >= 600 then
        sack_key_match_time = -1
        zoom_in_time, zoom_out_time = -1, 0
      end
    end

    -- Special case: entering album scene 4
    if s4_seq_time == -1 and tl_obj_unlock and zoom_obj.unlock == 4 then
      local i = tl_obj_unlock.find_tag(4)
      if (tl_obj_unlock.dx - 1.5) * (i - 1.5) >= 0 then
        s4_seq_time = 0   -- This disables further interactions
        zoom_obj = nil
        zoom_in_time, zoom_out_time = -1, -1
        if zoom_text then -- XXX: to determine whether this is needed
          zoom_text:release()
          zoom_text = nil
        end
      end
    end

    if s4_seq_time >= 0 then
      s4_seq_time = s4_seq_time + 1
      if s4_seq_time == 240 then
        audio.sfx('thunder')
      end
      if s4_seq_time == 480 then
        s4_seq_time = -2  -- Played
        synchronise_tl()
      end
    end
  end

  s.draw = function ()
    love.graphics.clear(1, 1, 0.99)
    love.graphics.setColor(1, 1, 1)
    local background = album_backgrounds[album_idx]
    if album_idx == 2 and not light_on then
      background = album_backgrounds_alter[album_idx]
    elseif letter_read[album_idx] then
      background = album_backgrounds_alter[album_idx]
    end
    draw.img(background, W / 2, H / 2, W, H)

    -- In-scene objects
    love.graphics.setColor(1, 1, 1)
    for i = 1, #objs do
      local o = objs[i]
      if o.scene_sprites then
        draw.img(o.scene_sprites[o.index], o.x, o.y, o.sprite_w)
      end
    end
    love.graphics.setColor(1, 0.8, 0.7, 0.3)
    for i = 1, #objs do
      local o = objs[i]
      love.graphics.ellipse('fill', o.x, o.y, o.rx, o.ry)
    end

    -- Zoom-in
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
      if zoom_text == nil then
        x_target = W * 0.5
      end
      if zoom_scroll ~= nil then
        y_target = H * 0.5 + zoom_scroll.dx
      end
      local scale = 0.3 + 0.3 * math.sqrt(math.sqrt(o_alpha))
      local img = zoom_obj.zoom_img
      if zoom_obj.unlocked_img and album_idx == zoom_obj.unlock then
        img = zoom_obj.unlocked_img
      elseif zoom_obj.unlock_seq and zoom_seq_prog >= 10 then
        img = zoom_obj.unlock_seq[math.floor(zoom_seq_prog / UNLOCK_SEQ_PROG_RATE)]
      end
      local x_cen = x_target + (zoom_obj.x - x_target) * move_prog
      local y_cen = y_target + (zoom_obj.y - y_target) * move_prog
      local scale_x, scale_y = scale, scale
      if zoom_obj.star_sack then
        local t = sack_key_match_time / 600
        local ampl = (1 - t) * math.exp(-t * 5) * 0.3
        scale_x = scale * (1 + math.sin(t * 3 * (math.pi * 2)) * ampl * 0.25)
        scale_y = scale * (1 + math.sin(t * 5 * (math.pi * 2)) * ampl)
      end
      draw.img(img, x_cen, y_cen, H * scale_x, H * scale_y)
      -- Text
      if zoom_text then
        draw.shadow(0.9, 0.9, 0.9, o_alpha, zoom_text, W * 0.67, H * 0.5)
      end

      -- Star sack?
      if zoom_obj.star_sack then
        for i = 1, #STAR_SACK_BTNS do
          local b = STAR_SACK_BTNS[i]
          if b.active then
            local x_offs = b.x - W / 2
            local y_offs = b.y - H / 2
            local rel_scale_x = scale_x / 0.6
            local rel_scale_y = scale_y / 0.6
            x_offs = x_offs * rel_scale_x
            y_offs = y_offs * rel_scale_y
            local w, h = draw.get(b.img):getDimensions()
            draw.img(b.img, x_cen + x_offs, y_cen + y_offs,
              w * rel_scale_x,
              h * rel_scale_y)
          end
        end
      end
    end

    -- Pointer
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

    -- Blur
    local blur_alpha = 0
    local tl0 = tl
    local tl = tl_obj_unlock or tl
    if tl.blur_disp > 0.2 then
      blur_alpha = (tl.blur_disp - 0.2) / 0.8
      blur_alpha = blur_alpha^(1/3)
    end
    if s4_seq_time >= 0 then
      blur_alpha = 1
      if s4_seq_time >= 200 and s4_seq_time < 280 then blur_alpha = 0 end
    end
    if blur_alpha > 0 then
      love.graphics.setColor(0.04, 0.04, 0.04, blur_alpha)
      love.graphics.rectangle('fill', 0, 0, W, H)
    end
    -- Audio volume
    for i = 1, #objs do
      local o = objs[i]
      if o.musical_box then
        audio.sfx_vol(o.musical_box, 1 - blur_alpha)
      end
    end

    -- Timeline
    local timeline_min = tl0.ticks[1]
    local timeline_max = tl0.ticks[#tl0.ticks]
    if tl_obj_unlock then
      timeline_min = math.min(timeline_min,
        math.max(tl_obj_unlock.ticks[1], tl_obj_unlock.dx_disp))
      timeline_max = math.max(timeline_max,
        math.min(tl_obj_unlock.ticks[#tl_obj_unlock.ticks], tl_obj_unlock.dx_disp))
    end
    local scale = 0
    if tl.dx_disp < -0.1 and timeline_min < 0 then
      scale = -tl.dx_disp - 0.1
      local w = (1 - math.exp(-(-tl.dx_disp - 0.1) * 0.1))
      scale = scale * (1 - w * 0.01)
    elseif tl.dx_disp > 1.1 and timeline_max > 1 then
      scale = tl.dx_disp - 1.1
      local w = (1 - math.exp(-(tl.dx_disp - 1.1) * 0.1))
      scale = scale * (1 - w * 0.01)
    end
    local y = function (t)
      local y = (t + scale) / (scale * 2 + 1)
      return H * (0.15 + y * 0.7)
    end
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.setLineWidth(4)
    local x = W * 0.9
    love.graphics.line(x, y(timeline_min), x, y(timeline_max))
    for i = 1, #tl0.ticks do
      if tl0.tags[i] > 0 then
        love.graphics.circle('fill', x, y(tl0.ticks[i]), 12)
      end
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle('fill', x, y(tl.dx_disp), 20)
  end

  s.wheel = function (x, y)
    if sack_key_match_time >= 0 then return end
    if s4_seq_time >= 0 then return end
    if zoom_obj ~= nil then
      if zoom_in_time >= 120 then
        if tl_obj_unlock and zoom_obj.unlock ~= album_idx then
          if zoom_seq_prog < #zoom_obj.unlock_seq * UNLOCK_SEQ_PROG_RATE
            and y * (album_ticks[zoom_obj.unlock] - album_ticks[album_idx]) > 0
          then
            zoom_seq_prog = math.min(
              #zoom_obj.unlock_seq * UNLOCK_SEQ_PROG_RATE,
              zoom_seq_prog + math.abs(y))
          else
            tl_obj_unlock.push(y)
          end
        elseif zoom_scroll then
          zoom_scroll.impulse(y * 3)
        end
      end
    else
      tl.push(y)
    end
  end

  s.destroy = function ()
  end

  return s
end
