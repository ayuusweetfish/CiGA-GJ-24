return function (drawable, fn)
  local s = {}
  local W, H = W, H

  s.x = 0
  s.y = 0
  s.s = 1
  s.enabled = true

  local w, h = drawable:getDimensions()
  local scale = 1

  local held = false
  local inside = false

  s.press = function (x, y)
    if not s.enabled then return false end
    if x >= s.x - w/2 and x <= s.x + w/2 and
       y >= s.y - h/2 and y <= s.y + h/2 then
      held = true
      inside = true
      return true
    else
      return false
    end
  end

  s.cancel = function (x, y)
    held, inside = false, false
  end

  s.move = function (x, y)
    if not held then return false end
    inside =
      x >= s.x - w/2 and x <= s.x + w/2 and
      y >= s.y - h/2 and y <= s.y + h/2
    return true
  end

  s.release = function (x, y)
    if not held then return false end
    if inside then fn() inside = false end
    held = false
    return true
  end

  s.update = function ()
    local target = (inside and 1.12 or 1)
    if math.abs(target - scale) <= 0.005 then
      scale = target
    else
      scale = scale + (target - scale) * 0.1
    end
  end

  s.draw = function (x_offs, y_offs)
    local sc = scale * s.s
    local x = s.x - w/2 * sc + (x_offs or 0)
    local y = s.y - h/2 * sc + (y_offs or 0)
    if drawable.draw then
      drawable:draw(x, y, sc)
    else
      love.graphics.draw(drawable, x, y, 0, sc)
    end
  end

  return s
end
