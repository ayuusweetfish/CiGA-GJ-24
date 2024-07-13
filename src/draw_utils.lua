local imgs = {}

local files = love.filesystem.getDirectoryItems('img')
for i = 1, #files do
  local file = files[i]
  if file:sub(-4) == '.png' or file:sub(-4) == '.jpg' then
    local name = file:sub(1, #file - 4)
    local img = love.graphics.newImage('img/' .. file)
    imgs[name] = img
    print(name)
  end
end

local batches = {}

local loadCrunch = function (path)
  local splitPath = function (path)
    local p = #path
    local q   -- p: last '/'; q: last '.' after p
    -- ord('/') == 47, ord('.') == 46
    while p >= 1 and path:byte(p) ~= 47 do
      if path:byte(p) == 46 and q == nil then q = p end
      p = p - 1
    end
    q = q or #path + 1
    return path:sub(1, p), path:sub(p + 1, q - 1)
  end
  local wd, name = splitPath(path)

  local f, err = love.filesystem.read('img/' .. path)
  if f == nil then
    error('Cannot load sprite sheet metadata ' .. path .. ' (' .. err .. ')')
    return nil
  end

  local p = 1

  local read_int16 = function ()
    local l, h = f:byte(p, p + 1)
    p = p + 2
    local x = h * 256 + l
    if x >= 32768 then x = x - 65536 end
    return x
  end
  local read_str = function ()
    local q = p
    repeat
      local ch = f:byte(p)
      p = p + 1
      if ch == 0 then break end
    until false
    return f:sub(q, p - 2)
  end

  local texCount = read_int16()
  for texId = 1, texCount do
    local texName = read_str()
    -- local img = love.graphics.newImage(wd .. texName .. '.png')
    local img = imgs[wd .. texName]
    local batch = love.graphics.newSpriteBatch(img, nil, 'stream')
    img:setFilter('nearest', 'nearest')
    batches[#batches + 1] = batch

    local sprCount = read_int16()
    for sprId = 1, sprCount do
      local name = read_str()
      local spr = {}
      spr.batch = batch
      spr.sx = read_int16()
      spr.sy = read_int16()
      spr.sw = read_int16()
      spr.sh = read_int16()
      spr.tx = -read_int16()
      spr.ty = -read_int16()
      spr.w = read_int16()
      spr.h = read_int16()
      -- print(name, spr.sx, spr.sy, spr.sw, spr.sh, spr.tx, spr.ty, spr.w, spr.h)
      spr.quad = love.graphics.newQuad(
        spr.sx, spr.sy, spr.sw, spr.sh,
        img:getPixelDimensions())
      spr.getDimensions = function (self) return self.w, self.h end
      spr.draw = function (self, x, y, r, sx, sy, ox, oy, kx, ky)
        -- Offset -> Scale & Shear -> Rotation
        -- XXX: Rotation not handled
        local tx, ty = self.tx, self.ty
        self.batch:add(self.quad, x, y, r, sx, sy, ox - tx, oy - ty)
      end
      imgs[name] = spr
    end
  end
end

loadCrunch('ss_sack_btn.bin')
loadCrunch('stage_20_gecko.bin')

print('*finish')

local draw = function (drawable, x, y, w, h, ax, ay, r, kx, ky)
  ax = ax or 0.5
  ay = ay or 0.5
  r = r or 0
  local iw, ih = drawable:getDimensions()
  local sx = w and w / iw or 1
  local sy = h and h / ih or sx
  local fn = drawable.draw or love.graphics.draw
  fn(drawable,
    x, y, r,
    sx, sy,
    ax * iw, ay * ih,
    kx, ky)
end

local img = function (name, x, y, w, h, ax, ay, r, kx, ky)
  draw(imgs[name], x, y, w, h, ax, ay, r, kx, ky)
end

local flush = function ()
  for _, v in ipairs(batches) do
    love.graphics.draw(v, 0, 0)
    v:clear()
  end
end

local shadow = function (R, G, B, A, drawable, x, y, w, h, ax, ay, r)
  love.graphics.setColor(R / 2, G / 2, B / 2, A * A / 2)
  draw(drawable, x + 1, y + 1, w, h, ax, ay, r)
  love.graphics.setColor(R, G, B, A)
  draw(drawable, x - 1, y - 1, w, h, ax, ay, r)
end

local enclose = function (drawable, w, h, extraOffsX, extraOffsY)
  local iw, ih = drawable:getDimensions()
  local offsX = (w - iw) / 2 + (extraOffsX or 0)
  local offsY = (h - ih) / 2 + (extraOffsY or 0)  -- Font specific
  local s = {}
  s.getDimensions = function (self)
    return w, h
  end
  s.draw = function (self, x, y, sc)
    love.graphics.rectangle('line',
      x, y, w * sc, h * sc, 10)
    love.graphics.draw(drawable, x + offsX * sc, y + offsY * sc, 0, sc)
  end
  return s
end

local draw_ = {
  get = function (name) return imgs[name] end,
  img = img,
  flush = flush,
  shadow = shadow,
  enclose = enclose,
}
setmetatable(draw_, { __call = function (self, ...) draw(...) end })
return draw_
