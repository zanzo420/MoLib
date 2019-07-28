--[[
  MoLib (GUI part) -- (c) 2019 moorea@ymail.com (MooreaTv)
  Covered by the GNU General Public License version 3 (GPLv3)
  NO WARRANTY
  (contact the author if you need a different license)
]] --
-- our name, our empty default (and unused) anonymous ns
local addonName, _ns = ...

local ML = _G[addonName]

-- use 2 or 4 for sizes so there are 1/2, 1/4 points
function ML:round(x, precision)
  precision = precision or 1
  local i, _f = math.modf(math.floor(x / precision + 0.5)) * precision
  return i
end

-- for sizes, don't shrink but also... 0.9 because floating pt math
-- also works symmetrically for negative numbers (ie round up -1.3 -> -2)
function ML:roundUp(x, precision)
  precision = precision or 1
  local sign = 1
  if x < 0 then
    sign = -1
    x = -x
  end
  local i, _f = math.modf(math.ceil(x / precision - 0.1)) * precision
  return sign * i
end

function ML:scale(x, s, precision)
  return ML:round(x * s, precision) / s
end

function ML:scaleUp(x, s, precision)
  return ML:roundUp(x * s, precision) / s
end

-- Makes sure the frame has the right pixel alignment and same padding with respect to
-- bottom right corner that it has on top left with its children objects.
-- returns a new scale to potentially be used if not recalculating the bottom right margins
function ML:SnapFrame(f)
  return self:PixelPerfectSnap(f, 2, true) -- 2 so we get dividable by 2 dimensions, true = from top and not bottom corner
  --[[   local s = f:GetScale() -- assumes our parent is the PixelPerfectFrame so getrect coords * s are in pixels
  local point, relTo, relativePoint, xOfs, yOfs = f:GetPoint()
  local x, y, w, h = f:GetRect()
  self:Debug(6, "Before: % % % %    % %   % %", x, y, w, h, point, relativePoint, xOfs, yOfs)
  local nw = self:scaleUp(w, s, 2)
  local nh = self:scaleUp(h, s, 2)
  self:Debug(6, "new WxH: % %", nw, nh)
  if self.NO_SNAPSCALE then
    self:DebugStack("NO_SNAPSCALE: Not SNAPing tp w % x h %", nw, nh)
    return
  end
  f:SetWidth(nw)
  f:SetHeight(nh)
  x, y, w, h = f:GetRect()
  self:Debug(6, "Mid: % % % % : %", x, y, w, h, f:GetScale())
  f:ClearAllPoints()
  local nx = self:scale(x, s)
  local ny = self:scale(y, s)
  local ns = nh / h
  local deltaX = nx - x
  local deltaY = ny - y
  f:SetPoint(point, relTo, relativePoint, xOfs + deltaX, yOfs + deltaY)
  self:Debug(5, "ns % : % % % % ( % % ): %", ns, x, y, nw, nh, deltaX, deltaY, f:GetScale())
  return f:GetScale() * ns
 ]]
end

-- WARNING, Y axis is such as positive is down, unlike rest of the wow api which has + offset going up
-- but all the negative numbers all over, just for Y axis, got to me

function ML.Frame(addon, name, global) -- to not shadow self below but really call with Addon:Frame(name)
  local f = CreateFrame("Frame", global, addon:PixelPerfectFrame())
  f:SetSize(1, 1) -- need a starting size for most operations
  if addon.debug and addon.debug >= 8 then
    addon:Debug(8, "Debug level 8 is on, putting debug background on frame %", name)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetIgnoreParentAlpha(true)
    f.bg:SetAlpha(.2)
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(.1, .2, .7)
  end
  f.name = name
  f.children = {}
  f.numObjects = 0

  f.Snap = function(w)
    addon:SnapFrame(w)
    w:setSizeToChildren()
  end

  f.Scale = function(w, ...)
    w:setScale(...)
  end

  f.ChangeScale = function(w, newScale)
    addon:ChangeScale(w, newScale)
  end

  f.Init = function(self)
    addon:Debug("Calling Init() on all % children", #self.children)
    for _, v in ipairs(self.children) do
      v:Init()
    end
  end

  -- returns opposite corners 4 coordinates:
  -- BottomRight(x,y) , TopLeft(x,y)
  f.calcCorners = function(self)
    local minX = 99999999
    local maxX = 0
    local minY = 99999999
    local maxY = 0
    local numChildren = 0
    for _, v in ipairs(self.children) do
      local x = v:GetRight()
      local y = v:GetBottom()
      local l = v:GetLeft()
      local t = v:GetTop()
      maxX = math.max(maxX, x or 0)
      minX = math.min(minX, l or 0)
      maxY = math.max(maxY, t or 0)
      minY = math.min(minY, y or 0)
      numChildren = numChildren + 1
    end
    addon:Debug(6, "Found corners for % children to be topleft % , % to bottomright %, %", numChildren, maxX, minY,
                minX, maxY)
    return maxX, minY, minX, maxY
  end

  f.setSizeToChildren = function(self)
    local mx, my, l, t = self:calcCorners()
    local x = self:GetLeft()
    local y = self:GetTop()
    if not x or not y then
      addon:Debug("Frame has no left or top! % %", x, y)
    end
    local w = mx - l
    local h = t - my
    local paddingX = 2 * (l - x)
    local paddingY = 2 * (y - t)
    addon:Debug(7, "Calculated bottom right x % y % -> w % h % padding % x %", x, y, w, h, paddingX, paddingY)
    self:SetWidth(w + paddingX)
    self:SetHeight(h + paddingY)
  end

  -- Scales a frame so the children objects fill up the frame in width or height
  -- (aspect ratio isn't changed) while also keeping the snap to pixel effect of SnapFrame
  f.setScale = function(self, overridePadding)
    local mx, my, l, t = self:calcCorners()
    local x = self:GetLeft()
    local y = self:GetTop()
    if not x or not y then
      addon:DebugStack("Frame has no left or top! % % in setScale", x, y)
    end
    local w = mx - l
    local h = t - my
    local paddingX = 2 * (l - x)
    local paddingY = 2 * (y - t)
    addon:Debug(6, "setScale bottom right x % y % -> w % h % padding % x %", x, y, w, h, paddingX, paddingY)
    local nw = w
    local nh = h
    if overridePadding ~= nil then
      --[[       local firstChild = self.children[1]
      local pt1, _, pt2, x, y = firstChild:GetPoint()
      if pt1:match("TOP") then
        addon:Debug("Adjusting first child top y anchor from % to %", y, overridePadding)
        y = -overridePadding
        firstChild:SetPoint(pt1, self, pt2, x, y)
      end
      if pt1:match("LEFT") then
        addon:Debug("Adjusting first child left x anchor from % to %", x, overridePadding)
        firstChild:SetPoint(pt1, self, pt2, overridePadding, y) -- use the adjusted y for TOPLEFT
      end
 ]]
      paddingX = 2 * overridePadding
      paddingY = 2 * overridePadding
    end
    nw = nw + paddingX
    nh = nh + paddingY
    local cw = self:GetWidth() -- current
    local ch = self:GetHeight()
    local sX = cw / nw
    local sY = ch / nh
    local scale = math.min(sX, sY)
    if addon.NO_SNAPSCALE then
      addon:DebugStack("NO_SNAPSCALE: not changing SCALE to % (sx % sy %)", scale, sX, sY)
      return
    end
    self:ChangeScale(self:GetScale() * scale)
    addon:Debug(5, "calculated scale x % scale y % for nw % nh % -> % -> %", sX, sY, nw, nh, scale, self:GetScale())
  end

  -- Used instead of SetPoint directly to move 2 linked object (eg textures for animation group) together
  local setPoint = function(sf, pt, ...)
    addon:Debug(8, "setting point %", pt)
    sf:SetPoint(pt, ...)
    if sf.linked then
      sf.linked:SetPoint(pt, ...)
    end
  end

  -- place inside the parent at offset x,y from corner of parent
  local placeInside = function(sf, x, y, point)
    point = point or "TOPLEFT"
    x = x or 16
    y = y or 16
    sf:setPoint(point, x, -y)
    return sf
  end
  -- place below (previously placed item typically)
  local placeBelow = function(sf, below, x, y, point1, point2)
    x = x or 0
    y = y or 8
    sf:setPoint(point1 or "TOPLEFT", below, point2 or "BOTTOMLEFT", x, -y)
    return sf
  end
  -- place to the right of last widget
  local placeRight = function(sf, nextTo, x, y, point1, point2)
    x = x or 16
    y = y or 0
    sf:setPoint(point1 or "TOPLEFT", nextTo, point2 or "TOPRIGHT", x, -y)
    return sf
  end
  -- place to the left of last widget
  local placeLeft = function(sf, nextTo, x, y, point1, point2)
    x = x or -16
    y = y or 0
    sf:setPoint(point1 or "TOPRIGHT", nextTo, point2 or "TOPLEFT", x, -y)
    return sf
  end

  -- Place (below) relative to previous one. optOffsetX is relative to the left margin
  -- established by first widget placed (placeInside)
  -- such as changing the order of widgets doesn't change the left/right offset
  -- in other words, offsetX is absolute to the left margin instead of relative to the previously placed object
  f.Place = function(self, object, optOffsetX, optOffsetY, point1, point2)
    self.numObjects = self.numObjects + 1
    addon:Debug(7, "called Place % n % o %", self.name, self.numObjects, self.leftMargin)
    if self.numObjects == 1 then
      -- first object: place inside
      object:placeInside(optOffsetX, optOffsetY, point1)
      self.leftMargin = 0
    else
      optOffsetX = optOffsetX or 0
      -- subsequent, place after the previous one but relative to initial left margin
      object:placeBelow(self.lastAdded, optOffsetX - self.leftMargin, optOffsetY, point1, point2)
      self.leftMargin = optOffsetX
    end
    self.lastAdded = object
    self.lastLeft = object
    return object
  end

  f.PlaceRight = function(self, object, optOffsetX, optOffsetY, point1, point2)
    self.numObjects = self.numObjects + 1
    if self.numObjects == 1 then
      addon:ErrorAndThrow("PlaceRight() should not be the first call, Place() should")
    end
    -- place to the right of previous one on the left
    -- if the previous widget has text, add the text length (eg for check buttons)
    local x = (optOffsetX or 16) + (self.lastLeft.extraWidth or 0)
    object:placeRight(self.lastLeft, x, optOffsetY, point1, point2)
    self.lastLeft = object
    return object
  end

  -- doesn't change lastLeft, meant to be called to put 1 thing to the left of a centered object atm
  f.PlaceLeft = function(self, object, optOffsetX, optOffsetY, point1, point2)
    self.numObjects = self.numObjects + 1
    if self.numObjects == 1 then
      addon:ErrorAndThrow("PlaceLeft() should not be the first call, Place() should")
    end
    -- place to the left of previous one
    -- if the previous widget has text, add the text length (eg for check buttons)
    local x = (optOffsetX or -16)
    object:placeLeft(self.lastLeft, x, optOffsetY, point1, point2)
    -- self.lastLeft = object
    return object
  end

  -- To be used by the various factories/sub widget creation to add common methods to them
  -- (learned after coming up with this pattern on my own that that this seems to be
  -- called Mixins in blizzard code, though that doesn't cover forwarding or children tracking)
  function f:addMethods(widget)
    widget.setPoint = setPoint
    widget.placeInside = placeInside
    widget.placeBelow = placeBelow
    widget.placeRight = placeRight
    widget.placeLeft = placeLeft
    widget.parent = self
    widget.Place = function(...)
      -- add missing parent as first arg
      widget.parent:Place(...)
      return widget -- because :Place is typically last, so don't return parent/self but the widget
    end
    widget.PlaceRight = function(...)
      widget.parent:PlaceRight(...)
      return widget
    end
    widget.PlaceLeft = function(...)
      widget.parent:PlaceLeft(...)
      return widget
    end
    if not widget.Init then
      widget.Init = function(w)
        addon:Debug(7, "Nothing special to init in %", w:GetObjectType())
      end
    end
    -- piggy back on 1 to decide both as it doesn't make sense to only define one of the two
    if not widget.DoDisable then
      widget.DoDisable = widget.Disable
      widget.DoEnable = widget.Enable
    end
    widget.Snap = function(w)
      addon:SnapFrame(w)
      w:setSizeToChildren()
    end
    table.insert(self.children, widget) -- keep track of children objects
  end

  f.addText = function(self, text, font)
    font = font or self.defaultFont or "GameFontHighlightSmall" -- different default?
    local fontObj = nil
    if type(font) ~= "string" then
      fontObj = font
      font = nil
    end
    local t = self:CreateFontString(nil, "ARTWORK", font)
    if fontObj then
      t:SetFontObject(fontObj)
    end
    if self.defaultTextColor then
      t:SetTextColor(unpack(self.defaultTextColor))
    end
    t:SetText(text)
    t:SetJustifyH("LEFT")
    t:SetJustifyV("TOP")
    self:addMethods(t)
    return t
  end

  --[[   f.drawRectangle = function(self, layer)
    local r = self:CreateTexture(nil, layer or "BACKGROUND")
    self:addMethods(r)
    return r
  end
 ]]

  -- adds a line of given thickness and color
  f.addLine = function(self, thickness, r, g, b, a, layer, dontaddtochildren)
    local l = self:CreateLine(nil, layer or "BACKGROUND")
    l.originalThickness = thickness or 1
    l:SetThickness(l.originalThickness)
    l:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
    if not dontaddtochildren then
      self:addMethods(l)
    end
    return l
  end

  -- adds a border, thickness is in pixels (will be altered based on scale)
  -- the border isn't added to regular children
  f.addBorder = function(self, padX, padY, thickness, r, g, b, alpha, layer)
    padX = padX or 0.5
    padY = padY or 0.5
    layer = layer or "BACKGROUND"
    r = r or 1
    g = g or 1
    b = b or 1
    alpha = alpha or 1
    thickness = thickness or 1
    if not f.border then
      f.border = {}
    end
    -- true argument to addLine == only store the line in the border list, so it doesn't get wiped/handled like regular children
    local top = self:addLine(thickness, r, g, b, alpha, layer, true)
    top:SetStartPoint("TOPLEFT", padX, -padY)
    top:SetEndPoint("TOPRIGHT", -padX, -padY)
    top:SetIgnoreParentAlpha(true)
    table.insert(f.border, top)
    local left = self:addLine(thickness, r, g, b, alpha, layer, true)
    left:SetStartPoint("TOPLEFT", padX, -padY)
    left:SetEndPoint("BOTTOMLEFT", padX, padY)
    left:SetIgnoreParentAlpha(true)
    table.insert(f.border, left)
    local bottom = self:addLine(thickness, r, g, b, alpha, layer, true)
    bottom:SetStartPoint("BOTTOMLEFT", padX, padY)
    bottom:SetEndPoint("BOTTOMRIGHT", -padX, padY)
    bottom:SetIgnoreParentAlpha(true)
    table.insert(f.border, bottom)
    local right = self:addLine(thickness, r, g, b, alpha, layer, true)
    right:SetStartPoint("BOTTOMRIGHT", -padX, padY)
    right:SetEndPoint("TOPRIGHT", -padX, -padY)
    right:SetIgnoreParentAlpha(true)
    table.insert(f.border, right)
    self:updateBorder()
  end

  f.updateBorder = function(self)
    if not self.border or #self.border == 0 then
      return
    end
    local s = self:GetScale()
    for _, b in ipairs(self.border) do
      b:SetThickness(b.originalThickness / s)
    end
  end

  -- creates a texture so it can be placed
  -- (arguments are optional)
  f.addTexture = function(self, layer)
    local t = self:CreateTexture(nil, layer or "BACKGROUND")
    addon:Debug(8, "textures starts with % points", t:GetNumPoints())
    self:addMethods(t)
    return t
  end

  -- Add an animation of 2 textures (typically glow)
  f.addAnimatedTexture = function(self, baseId, glowId, duration, glowAlpha, looping, layer)
    local base = self:addTexture(layer)
    base:SetTexture(baseId)
    if not base:IsObjectLoaded() then
      addon:Warning("Texture % not loaded yet... use ML:PreloadTextures()...", baseId)
      base:SetSize(64, 64)
    end
    addon:Debug("Setting base texture % - height = %", baseId, base:GetHeight())
    local glow = self:CreateTexture(nil, layer or "BACKGROUND")
    glow:SetTexture(glowId)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0) -- start with no change
    glow:SetIgnoreParentAlpha(true)
    local ag = glow:CreateAnimationGroup()
    base.animationGroup = ag
    local anim = ag:CreateAnimation("Alpha")
    anim:SetFromAlpha(0)
    anim:SetToAlpha(glowAlpha or 0.2)
    ag:SetLooping(looping or "BOUNCE")
    anim:SetDuration(duration or 2)
    base.linked = glow
    ag:Play()
    return base
  end

  f.addCheckBox = function(self, text, tooltip)
    -- local name= "self.cb.".. tostring(self.id) -- not needed
    local c = CreateFrame("CheckButton", nil, self, "InterfaceOptionsCheckButtonTemplate")
    addon:Debug(8, "check box starts with % points", c:GetNumPoints())
    c.Text:SetText(text)
    if tooltip then
      c.tooltipText = tooltip
    end
    self:addMethods(c)
    c.extraWidth = c.Text:GetWidth()
    return c
  end

  -- create a slider with the range [minV...maxV] and optional step, low/high labels and optional
  -- strings to print in parenthesis after the text title
  f.addSlider = function(self, text, tooltip, minV, maxV, step, lowL, highL, valueLabels)
    minV = minV or 0
    maxV = maxV or 10
    step = step or 1
    lowL = lowL or tostring(minV)
    highL = highL or tostring(maxV)
    local s = CreateFrame("Slider", nil, self, "OptionsSliderTemplate")
    s.DoDisable = BlizzardOptionsPanel_Slider_Disable -- what does enable/disable do ? seems we need to call these
    s.DoEnable = BlizzardOptionsPanel_Slider_Enable
    s:SetValueStep(step)
    s:SetStepsPerPage(step)
    s:SetMinMaxValues(minV, maxV)
    s:SetObeyStepOnDrag(true)
    s.Text:SetFontObject(GameFontNormal)
    -- not centered, so changing (value) doesn't wobble the whole thing
    -- (justifyH left alone didn't work because the point is also centered)
    s.Text:SetPoint("LEFT", s, "TOPLEFT", 6, 0)
    s.Text:SetJustifyH("LEFT")
    s.Text:SetText(text)
    if tooltip then
      s.tooltipText = tooltip
    end
    s.Low:SetText(lowL)
    s.High:SetText(highL)
    s:SetScript("OnValueChanged", function(w, value)
      local sVal
      if valueLabels and valueLabels[value] then
        sVal = valueLabels[value]
      else
        sVal = tostring(ML:round(value, 0.001))
        if value == minV then
          sVal = lowL
        elseif value == maxV then
          sVal = highL
        end
      end
      w.Text:SetText(text .. ": " .. sVal)
      if w.callBack then
        w:callBack(value)
      end
    end)
    self:addMethods(s)
    return s
  end

  -- the call back is either a function or a command to send to addon.Slash
  f.addButton = function(self, text, tooltip, cb)
    -- local name= "addon.cb.".. tostring(self.id) -- not needed
    local c = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    c.Text:SetText(text)
    c:SetWidth(c.Text:GetStringWidth() + 20) -- need some extra spaces for corners
    if tooltip then
      c.tooltipText = tooltip -- TODO: style/font of tooltip for button is wrong
    end
    self:addMethods(c)
    local callback = cb
    if type(cb) == "string" then
      addon:Debug(4, "Setting callback for % to call Slash(%)", text, cb)
      callback = function()
        addon.Slash(cb)
      end
    else
      addon:Debug(4, "Keeping original function for %", text)
    end
    c:SetScript("OnClick", callback)
    return c
  end

  local function dropdownInit(d)
    addon:Debug("drop down init called initDone=%", d.initDone)
    if d.initDone then
      return
    end
    addon:Debug("drop down first time init called")
    d.initDone = true
    UIDropDownMenu_JustifyText(d, "CENTER")
    UIDropDownMenu_Initialize(d, function(_w, _level, _menuList)
      for _, v in ipairs(d.options) do
        addon:Debug(5, "Creating dropdown entry %", v)
        local info = UIDropDownMenu_CreateInfo() -- don't put it outside the loop!
        info.tooltipOnButton = true
        info.text = v.text
        info.tooltipTitle = v.text
        info.tooltipText = v.tooltip
        info.value = v.value
        info.func = function(entry)
          if d.cb then
            d.cb(entry.value)
          end
          UIDropDownMenu_SetSelectedID(d, entry:GetID())
        end
        UIDropDownMenu_AddButton(info)
      end
    end)
    UIDropDownMenu_SetText(d, d.text)
    -- Uh? one global for all dropdowns?? also possible taint issues
    local width = _G["DropDownList1"] and _G["DropDownList1"].maxWidth or 0
    addon:Debug("Found dropdown width to be %", width)
    if width > 0 then
      UIDropDownMenu_SetWidth(d, width)
    end
  end

  -- Note that trying to reuse the blizzard dropdown code instead of duplicating it cause some tainting
  -- because said code uses a bunch of globals notably UIDROPDOWNMENU_MENU_LEVEL
  -- create/show those widgets as late as possible
  f.addDrop = function(self, text, tooltip, cb, options)
    -- local name = self.name .. "drop" .. self.numObjects
    local d = CreateFrame("Frame", nil, self, "UIDropDownMenuTemplate")
    d.tooltipTitle = "Testing dropdown tooltip 1" -- not working/showing (so far)
    d.tooltipText = tooltip
    d.options = options
    d.cb = cb
    d.text = text
    d.tooltipOnButton = true
    d.Init = dropdownInit
    self:addMethods(d)
    self.lastDropDown = d
    return d
  end

  if ML.widgetDemo then
    f:addText("Testing 1 2 3... demo widgets:"):Place(50, 20)
    local _cb1 = f:addCheckBox("A test checkbox", "A sample tooltip"):Place(0, 20) -- A: not here
    local cb2 = f:addCheckBox("Another checkbox", "Another tooltip"):Place()
    cb2:SetChecked(true)
    local s2 = f:addSlider("Test slider", "Test slide tooltip", 1, 4, 1, "Test low", "Test high",
                           {"Value 1", "Value 2", "Third one", "4th value"}):Place(16, 30)
    s2:SetValue(4)
    f:addText("Real UI:"):Place(50, 40)
  end

  return f
end

---
-- Changes the scale without changing the anchor
function ML:ChangeScale(f, newScale)
  local pt1, parent, pt2, x, y = f:GetPoint()
  local oldScale = f:GetScale()
  local ptMult = oldScale / newScale -- correction for point
  self:Debug(7, "Changing scale from % to % for pt % / % x % y % - point multiplier %", oldScale, newScale, pt1, pt2, x,
             y, ptMult)
  f:SetScale(newScale)
  f:SetPoint(pt1, parent, pt2, x * ptMult, y * ptMult)
  f:updateBorder()
  return oldScale
end

-- Frame to attach all textures for (async) preloading: TODO actually wait for them to be loaded
ML.MoLibTexturesPreLoadFrame = CreateFrame("Frame")

-- ML.debug = 1
function ML:PreloadTextures(texture, ...)
  local t = ML.MoLibTexturesPreLoadFrame:CreateTexture(texture)
  local ret = t:SetTexture(texture)
  ML:Debug(1, "Preloading % : %", texture, ret)
  if not ret then
    error("Can't create texture %", texture)
  end
  if select("#", ...) == 0 then
    return
  end
  ML:PreloadTextures(...)
end

-- Wipes a frame and it's children to reduce memory usage to a minimum
-- (note this is not a pool but could be modified to do resetting of object in pool)
function ML:WipeFrame(f, ...)
  if not f then
    return -- nothing to wipe
  end
  f:Hide() -- first hide before we change children etc
  if f.UnregisterAllEvents then
    f:UnregisterAllEvents()
  end
  local oType = f:GetObjectType()
  local name = f:GetName() -- likely nil for our stuff
  self:Debug(6, "Wiping % name %", oType, name)
  -- depth first: children then us then siblings
  if f.GetChildren then
    self:WipeFrame(f:GetChildren())
  else
    assert(not f.children)
  end
  if name then
    _G[name] = nil
  end
  f:SetScale(1)
  f:ClearAllPoints()
  local status, err = pcall(function()
    f:SetParent(nil)
  end)
  if not status then
    self:Debug(7, "(Expected) Error clearing Parent on % %: %", oType, name, err)
  end
  wipe(f)
  self:WipeFrame(...)
  return nil
end

--- Test / debug functions

-- classic compatible
function ML:GetCVar(...)
  local f
  if C_CVar then
    f = C_CVar.GetCVar
  else
    f = GetCVar
  end
  return f(...)
end

function ML:DisplayInfo(x, y, scale)
  local f = ML:Frame()
  f.defaultTextColor = {.5, .6, 1, 1}
  f.defaultFont = "Game13FontShadow"
  f:SetFrameStrata("FULLSCREEN")
  f:SetPoint("CENTER", x, -y)
  local p = f:GetParent()
  local ps = 1
  if p then
    ps = p:GetScale()
  end
  f:SetScale((scale or 1) / ps)
  f:SetAlpha(0.95)
  f:addText("Dimensions snapshot by MoLib:"):Place()
  f:addText(string.format("UI parent: %.3f x %.3f (scale %.5f eff.scale %.5f)", UIParent:GetWidth(),
                          UIParent:GetHeight(), UIParent:GetScale(), UIParent:GetEffectiveScale())):Place()
  f:addText(string.format("WorldFrame: %.3f x %.3f (scale %.5f eff.scale %.5f)", WorldFrame:GetWidth(),
                          WorldFrame:GetHeight(), WorldFrame:GetScale(), WorldFrame:GetEffectiveScale())):Place()
  local w, h = GetPhysicalScreenSize()
  f:addText(ML:format("Actual pixels % x %", w, h)):Place()
  f:addText(ML:format("Renderscale % uiScale %", self:GetCVar("RenderScale"), self:GetCVar("uiScale"))):Place()
  local aX = 16
  local aY, aYi = self:AspectRatio(aX)
  f:addText(ML:format("Aspect ratio is ~ %:% (%:%)", aX, aY, aX, aYi)):Place()
  --[[   f:addText(
    string.format("This pos: %.3f x %.3f (scale %.5f eff.scale %.5f)", x, y, f:GetScale(), f:GetEffectiveScale()))
    :Place()
 ]]
  f:Show()
  self:Debug("done with % % %", x, y, scale)
  return f
end

--- Grid demo for pixel perfect (used by PixelPerfectAlign)

ML.drawn = 0

function ML:DrawPixel(f, x, y, color, layer)
  local t = f:CreateTexture(nil, layer or "BACKGROUND")
  x = math.floor(x)
  y = math.floor(y)
  t:SetSize(1, 1)
  t:SetColorTexture(unpack(color))
  t:SetPoint("BOTTOMLEFT", x, y)
  self.drawn = self.drawn + 1
  return t
end

-- Draws 2 line crossing in center x,y either vertical/horizontal if off2 is 0
-- or diagonally if off2 is == off1
function ML:DrawCross(f, x, y, off1, off2, thickness, color)
  if off1 < 1 and thickness <= 1 then
    ML:DrawPixel(f, x, y, color)
    return
  end
  local l = f:CreateLine(nil, "BACKGROUND")
  l:SetThickness(thickness)
  l:SetColorTexture(unpack(color))
  l:SetStartPoint("BOTTOMLEFT", x - off1, y - off2)
  l:SetEndPoint("BOTTOMLEFT", x + off1, y + off2)
  l = f:CreateLine(nil, "BACKGROUND")
  l:SetThickness(thickness)
  l:SetColorTexture(unpack(color))
  l:SetStartPoint("BOTTOMLEFT", x + off2, y - off1)
  l:SetEndPoint("BOTTOMLEFT", x - off2, y + off1)
  self.drawn = self.drawn + 2
end

ML.gold = {1, 0.8, 0.05, 0.5}
ML.red = {1, .1, .1, .8}

function ML:FineGrid(numX, numY, length, name, parent)
  local pp = self:pixelPerfectFrame(name, parent) -- potentially a shiny new frame
  local f = pp
  if name then
    -- if parent is one of the named one then make a new child, otherwise use the one we just made
    f = CreateFrame("Frame", nil, pp)
  end
  f:SetFlattensRenderLayers(true)
  f:SetPoint("BOTTOMLEFT", 0, 0) -- BOTTOMLEFT is where 0,0 is
  -- consider change offset for odd vs even for the center cross
  local w, h = GetPhysicalScreenSize()
  f:SetSize(w, h)
  local th = 1 -- thickness
  length = length or 16
  -- we round up most cases except for special 1 pixel request
  local off1 = math.ceil(length / 2) + 0.5
  if length == 1 then
    off1 = 0.5
  end
  local color
  local seenCenter = false
  self:Debug(1, "Making % x % (+1) crosses of length %", numX, numY, off1)
  for i = 0, numX do
    for j = 0, numY do
      local x = math.floor(i * (w - 1) / numX) + 0.5
      local y = math.floor(j * (h - 1) / numY) + 0.5
      color = self.gold
      local off2 = 0
      if i == numX / 2 and j == numY / 2 then
        -- center, make a red side cross instead
        seenCenter = true
        color = self.red
        if length ~= 1 then -- special case for 1 pixel in center
          off2 = off1 + 0.5
          x = x - 0.5
          y = y - 0.5
        end
      end
      self:DrawCross(f, x, y, off1, off2, th, color)
    end
  end
  if not seenCenter then
    local x = math.floor(w / 2)
    local y = math.floor(h / 2)
    local off2 = off1 + 0.5
    if length == 1 then -- another special case for 1 pixel long center
      x = x - 0.5
      y = y - 0.5
      off2 = 0
    end
    self:DrawCross(f, x, y, off1, off2, th, self.red)
  end
  return f
end

function ML:Demo()
  local sum = 0
  local num = 0
  local before = self.drawn
  for i = 96, 126 do
    ML:FineGrid(i, i, 1, "MoLib_PP_Demo", WorldFrame)
    sum = sum + ((i + 1) * (i + 1) + math.fmod(i, 2))
    num = num + 1
  end
  local msg = self:format("created % (%, % total) textures across % frames", sum, self.drawn - before, self.drawn, num)
  self:PrintDefault(msg)
  return msg
end

-- Returns nY closest int in proportion to aspect ratio
-- eg on a 16:9 screen passing in 16 will return 9
-- also returns the not rounded one
function ML:AspectRatio(nX)
  local w, h = GetPhysicalScreenSize()
  local nY = self:round(h / w * nX, 0.01)
  local nYi = self:round(nY, 1)
  self:Debug(2, "Aspect ratio %:% - rounded to %:%", nX, nY, nX, nYi)
  return nYi, nY
end

-- Sets the scale to match physical pixels
function ML:PixelPerfectScale(f)
  local w, h = GetPhysicalScreenSize()
  -- use width as divisor as that's (typically) the largest numbers so better precision
  f:SetSize(w, h)
  local p = f:GetParent() or WorldFrame
  local sx = p:GetWidth() / w
  local sy = p:GetHeight() / h
  f:SetScale(sx)
  self:Debug(1, "Set Pixel Perfect w % h % scale sx % (sy %) rect %", w, h, sx, sy, {f:GetRect()})
end

function ML.OnPPEvent(frame, event, ...)
  ML:Debug(1, "frame % got %: %", frame:GetName(), event, {...})
  ML:PixelPerfectScale(frame)
end

-- Creates/Returns a frame taking the whole screen and for which every whole coordinate is a physical pixel
-- Thus any children frame of this one is always pixel perfect/aligned when using whole numbers + 0.5
-- Makes 2 frames, on child of UIParent for most UI and one, if passed true, of WorldFrame so it can be
-- shown always.
function ML:PixelPerfectFrame(worldFrame)
  local name = "MoLibPixelPerfect"
  local parent = UIParent
  if worldFrame then
    name = name .. "World"
    parent = WorldFrame
  end
  name = name .. "Frame"
  return self:pixelPerfectFrame(name, parent)
end

function ML:pixelPerfectFrame(name, parent)
  if name and _G[name] then
    self:Debug(8, "ppf returning existing % whose parent is %", name, _G[name]:GetParent())
    return _G[name]
  end
  local f = CreateFrame("Frame", name, parent)
  f:SetPoint("BOTTOMLEFT", 0, 0) -- BOTTOMLEFT is where 0,0 is/starts
  self:PixelPerfectScale(f)
  f:Show()
  f:SetScript("OnEvent", self.OnPPEvent)
  f:RegisterEvent("DISPLAY_SIZE_CHANGED")
  if parent ~= nil and parent ~= WorldFrame then
    -- nil and world ppf are based of fixed x768 parent so doesn't need UI scale changed events
    f:RegisterEvent("UI_SCALE_CHANGED")
  end
  return f -- same as _G[name]
end

-- Moves a frame to have pixel perfect alignment. Doesn't fix the scale, only the boundaries
function ML:PixelPerfectSnap(f, resolution, top)
  resolution = resolution or 1 -- should be 2, 1 or 0.5
  local fs = f:GetEffectiveScale()
  local ps = self:PixelPerfectFrame():GetEffectiveScale()
  -- get the rect in pixel perfect coordinates
  local ppx, ppy, ppw, pph = self:Map(function(v)
    return v * fs / ps
  end, f:GetRect())
  local point1 = "BOTTOMLEFT" -- natural point with 0,0 bottom left
  if top then
    -- switch which point is calculated/rounded
    ppy = ppy + pph
    point1 = "TOPLEFT"
  end
  -- round the bottom corner to nearest 1/2 pixel
  ppx = self:round(ppx, resolution)
  ppy = self:round(ppy, resolution)
  -- round the width/heigh up to 1/2 pixel dimension
  -- (not that 0.55 still rounds "up" to 0.5 and 0.56 is the first to round to 1.0)
  ppw = self:roundUp(ppw, resolution)
  pph = self:roundUp(pph, resolution)
  -- change the frame
  self:Debug("About to change from x % y % w % h %", f:GetRect())
  self:Debug("ps % fs % to x % y % w % h % -> scaled back to wf x % y % - new w % h %", ps, fs, ppx, ppy, ppw, pph,
             ppx * ps, ppy * ps, ppw * ps, pph * ps)
  self:Debug("size before % %", f:GetSize())
  f:ClearAllPoints()
  local mult = ps / fs -- put back in screen+frame's scale/coordinate
  f:SetPoint(point1, nil, "BOTTOMLEFT", ppx * mult, ppy * mult)
  f:SetSize(ppw * mult, pph * mult)
  -- f:SetPoint(point2, nil, "BOTTOMLEFT", (ppx + ppw) * mult, (ppy + pph) * mult)
  self:Debug("scale after %, size after % %", f:GetScale(), f:GetSize())
  return ps, ppw, pph
end
---
-- C_Timer.After(1, function()
--  ML:FineGrid(16, 8)
-- end)
---

function ML:minimapButton(pos)
  local b = CreateFrame("Button", nil, Minimap)
  b:SetFrameStrata("HIGH")
  if pos then
    local pt, xOff, yOff = unpack(pos)
    b:SetPoint(pt, nil, pt, xOff, yOff) -- dragging gives position from nil (screen)
  else
    b:SetPoint("CENTER", -71, 37)
  end
  b:SetSize(32, 32)
  -- b:SetFrameLevel(8)
  b:RegisterForClicks("AnyUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture(136477) -- interface/minimap/ui-minimap-zoombutton-highlight
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(24, 24)
  bg:SetTexture(136467) -- interface/minimap/ui-minimap-background
  bg:SetPoint("CENTER", 1, 1)
  local o = b:CreateTexture(nil, "OVERLAY")
  o:SetSize(54, 54)
  o:SetTexture(136430) -- interface/minimap/minimap-trackingborder
  o:SetPoint("TOPLEFT")
  self:Debug("Created minimap button %", b)
  return b
end

-- initially from DynamicBoxer DBoxUI.lua

function ML:ShowToolTip(f, anchor)
  self:Debug("Show tool tip...")
  if f.tooltipText then
    GameTooltip:SetOwner(f, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetText(f.tooltipText, 0.9, 0.9, 0.9, 1, false)
  else
    self:Debug("No .tooltipText set on %", f:GetName())
  end
end

-- callback will be called with (f, pos, scale)
function ML:MakeMoveable(f, callback, dragButton)
  f.afterMoveCallBack = callback
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:RegisterForDrag(dragButton or "LeftButton")
  f:SetScript("OnDragStart", function(w)
    w:StartMoving()
    w:SetUserPlaced(false) -- TODO consider using that mechanism to save our pos?
  end)
  f:SetScript("OnDragStop", function(w, ...)
    w:StopMovingOrSizing(...)
    self:SavePosition(w) -- must be first to get the points relative to nearest screen point
    self:PixelPerfectSnap(w) -- then snap for perfect pixels
  end)
end

function ML:SavePosition(f)
  -- we must extract the position before snap changes the anchor point,
  -- so we keep getting pos "closest to correct part of the screen"
  f:StartMoving()
  f:SetUserPlaced(false)
  f:StopMovingOrSizing()
  local point, relTo, relativePoint, xOfs, yOfs = f:GetPoint()
  local scale = f:GetScale()
  self:Debug("Stopped moving/scaling widget % % % % relative to % % - scale %", point, relativePoint, xOfs, yOfs, relTo,
             relTo and relTo:GetName(), scale)
  local pos = {point, xOfs, yOfs} -- relativePoint seems to always be same as point, when called at the right time
  if f.afterMoveCallBack then
    f:afterMoveCallBack(pos, scale)
  else
    self:Debug("No after move callback for %", f)
  end
end

function ML:RestorePosition(f, pos, scale)
  self:Debug("Restoring % %", pos, scale)
  if scale then
    f:SetScale(scale)
  end
  f:ClearAllPoints()
  f:SetPoint(unpack(pos))
  -- if our widget we use the widget function, otherwise the generic snap
  -- todo: why is the outcome different for dbox ?
  if f.Snap then
    f:Snap()
  else
    self:SnapFrame(f)
  end
end

-- Returns coordinates (pixelX, pixelY, uicoordX, uicoordY)
-- in actual pixels and in UIParent's coordinates
function ML:GetCursorCoordinates()
  local pw = GetPhysicalScreenSize()
  local sw = WorldFrame:GetWidth() / pw
  local uis = UIParent:GetScale()
  local x, y = GetCursorPosition()
  return ML:round(x / sw), ML:round(y / sw), x / uis, y / uis
end

---
ML:Debug("MoLib UI file loaded")
