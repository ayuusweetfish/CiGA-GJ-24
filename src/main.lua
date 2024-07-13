W = 1280
H = 720

local isMobile = (love.system.getOS() == 'Android' or love.system.getOS() == 'iOS')
local isWeb = (love.system.getOS() == 'Web')

love.window.setMode(
  isWeb and (W / 3 * 2) or W,
  isWeb and (H / 3 * 2) or H,
  { fullscreen = false, highdpi = true }
)

local globalScale, Wx, Hx, offsX, offsY

local updateLogicalDimensions = function ()
  love.window.setTitle('Wrinkle')
  local wDev, hDev = love.graphics.getDimensions()
  globalScale = math.min(wDev / W, hDev / H)
  Wx = wDev / globalScale
  Hx = hDev / globalScale
  offsX = (Wx - W) / 2
  offsY = (Hx - H) / 2
end
updateLogicalDimensions()

-- Load font
local fontSizeFactory = function (path, preload)
  local font = {}
  if preload ~= nil then
    for i = 1, #preload do
      local size = preload[i]
      if path == nil then
        font[size] = love.graphics.newFont(size)
      else
        font[size] = love.graphics.newFont(path, size)
      end
    end
  end
  return function (size)
    if font[size] == nil then
      if path == nil then
        font[size] = love.graphics.newFont(size)
      else
        font[size] = love.graphics.newFont(path, size)
      end
    end
    return font[size]
  end
end
_G['global_font'] = fontSizeFactory('fnt/ChillRoundGothic_Regular_subset.ttf', {28, 36})
_G['numbers_font'] = fontSizeFactory('fnt/BorelRegular_subset.ttf', {28, 36})
love.graphics.setFont(_G['global_font'](40))

_G['scene_intro'] = require 'scene_intro'
_G['scene_setup'] = require 'scene_setup'
_G['scene_gameplay'] = require 'scene_gameplay'

local audio = require 'audio'

local curScene = scene_setup() -- scene_gameplay()
local lastScene = nil
local transitionTimer = 0
local currentTransition = nil
local transitions = {}
_G['transitions'] = transitions

local ptx, pty = W / 2, H / 2

_G['replaceScene'] = function (newScene, transition)
  lastScene = curScene
  curScene = newScene
  transitionTimer = 0
  currentTransition = transition or transitions['fade'](0.9, 0.9, 0.9)
  if newScene.enter_hover then
    newScene.enter_hover(ptx, pty)
  end
end

local leftShiftHeld = false
_G['trackpadMode'] = false
_G['scrollRate'] = 1  -- Will be updated at `scene_setup`
local scrollYAccum = 0

local mouseScene = nil
function love.mousepressed(x, y, button, istouch, presses)
  ptx, pty = (x - offsX) / globalScale, (y - offsY) / globalScale
  if button ~= 1 then return end
  if lastScene ~= nil then return end
  mouseScene = curScene
  curScene.press(ptx, pty)
end
function love.mousemoved(x, y, button, istouch)
  ptx, pty = (x - offsX) / globalScale, (y - offsY) / globalScale
  curScene.hover(ptx, pty)
  if mouseScene ~= curScene then return end
  curScene.move(ptx, pty)
end
function love.mousereleased(x, y, button, istouch, presses)
  ptx, pty = (x - offsX) / globalScale, (y - offsY) / globalScale
  if button ~= 1 then return end
  if mouseScene ~= curScene then return end
  local fn = curScene.release
  if leftShiftHeld then fn = curScene.cancel end
  if fn then fn(ptx, pty) end
  mouseScene = nil
end

function love.wheelmoved(x, y)
  local x_raw, y_raw = x, y
  if _G['trackpadMode'] then
    -- print(scrollYAccum, y)
    if math.abs(y) > math.abs(scrollYAccum) then
      y, scrollYAccum = y - scrollYAccum, y
    else
      y = 0
    end
  end
  y = y * scrollRate
  if curScene.wheel then curScene.wheel(x, y, x_raw, y_raw) end
end

-- Emulate scroll with touch
local touch_as_pointer = false
local touch_count = 0
local touch_accum_dy = 0
local touches_y = {}
function love.touchpressed(id, x, y, dx, dy, pressure)
  x, y = (x - offsX) / globalScale, (y - offsY) / globalScale
  touches_y[id] = y
  touch_count = touch_count + 1
  if touch_count == 1 then
    -- First touch
    touch_as_pointer = true
  elseif touch_as_pointer then
    -- Cancel pointer event
    touch_as_pointer = false
    mouseScene.cancel(x, y)
    mouseScene = nil
    touch_accum_dy = 0
  end
end
function love.touchmoved(id, x, y, dx, dy, pressure)
  x, y = (x - offsX) / globalScale, (y - offsY) / globalScale
  if not touch_as_pointer then
    local touch_scroll_step = H / 20
    touch_accum_dy = touch_accum_dy + (y - touches_y[id])
    local n = math.floor(touch_accum_dy / touch_scroll_step + 0.5)
    if n ~= 0 then
      touch_accum_dy = touch_accum_dy - n * touch_scroll_step
      love.wheelmoved(0, n)
    end
  end
  touches_y[id] = y
end
function love.touchreleased(id, x, y, dx, dy, pressure)
  x, y = (x - offsX) / globalScale, (y - offsY) / globalScale
  touches_y[id] = nil
  touch_count = touch_count - 1
  if touch_count == 0 then
    touch_as_pointer = false
    touch_accum_dy = 0
  end
end

local T = 0
local timeStep = 1 / 240

function love.update(dt)
  T = T + dt
  local count = 0
  while T > timeStep and count < 12 do
    T = T - timeStep
    count = count + 1
    if lastScene ~= nil then
      lastScene:update()
      -- At most 4 ticks per update for transitions
      if count <= 4 then
        transitionTimer = transitionTimer + 1
      end
    else
      curScene:update()
    end

    scrollYAccum = scrollYAccum * 0.99
    if scrollYAccum > 0.01 then scrollYAccum = scrollYAccum - 0.01
    elseif scrollYAccum < -0.01 then scrollYAccum = scrollYAccum + 0.01
    else scrollYAccum = 0 end
  end
end

transitions['fade'] = function (r, g, b)
  return {
    dur = 120,
    draw = function (x)
      local opacity = 0
      if x < 0.5 then
        lastScene:draw()
        opacity = x * 2
      else
        curScene:draw()
        opacity = 2 - x * 2
      end
      love.graphics.setColor(r, g, b, opacity)
      love.graphics.rectangle('fill', -offsX, -offsY, Wx, Hx)
    end
  }
end

function love.draw()
  love.graphics.scale(globalScale)
  love.graphics.setColor(1, 1, 1)
  love.graphics.push()
  love.graphics.translate(offsX, offsY)
  if lastScene ~= nil then
    local x = transitionTimer / currentTransition.dur
    currentTransition.draw(x)
    if x >= 1 then
      if lastScene.destroy then lastScene.destroy() end
      lastScene = nil
    end
  else
    curScene.draw()
  end
  love.graphics.pop()
end

function love.keypressed(key)
  if key == 'lshift' then leftShiftHeld = true end
  if false and key == 'lshift' then
    if not isMobile and not isWeb then
      love.window.setFullscreen(not love.window.getFullscreen())
      updateLogicalDimensions()
    end
  end
end
function love.keyreleased(key)
  if key == 'lshift' then leftShiftHeld = false end
end
