--[[
  Sanrio Shop (Cash + Passes)
  Location: StarterPlayer > StarterPlayerScripts
  Notes:
    - Responsive 3/2/1 grid with min–max card width
    - Safe-area padding via GuiService:GetSafeZoneInsets()
    - Aspect-locked hero image (16:9)
    - Hover scale via UIScale (no position tween)
    - Skeleton shimmer for image and price while loading
    - Pill badges (Owned / Price) and focus ring
    - Button spinner + outcome banners
    - Throttled grid recompute; only a single scroll container per page
    - Client prompts purchases; server must grant via ProcessReceipt
]]

-- Services
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:FindFirstChild("TycoonRemotes")

-- ====================================================================
-- Theme Tokens
-- ====================================================================
local Theme = {
  colors = {
    bg = Color3.fromRGB(253, 252, 250),
    surface = Color3.fromRGB(255, 255, 255),
    surfaceAlt = Color3.fromRGB(246, 248, 252),
    stroke = Color3.fromRGB(222, 226, 235),
    text = Color3.fromRGB(35, 38, 46),
    textSecondary = Color3.fromRGB(120, 126, 140),
    accent = Color3.fromRGB(255, 64, 129),
    success = Color3.fromRGB(76, 175, 80),
    danger = Color3.fromRGB(244, 67, 54),
    info = Color3.fromRGB(99, 139, 255),
    cinna = Color3.fromRGB(186, 214, 255),
    kuromi = Color3.fromRGB(200, 190, 255),
  },
  radius = { r10 = UDim.new(0, 10), r16 = UDim.new(0, 16), r24 = UDim.new(0, 24) },
  spacing = { s8 = 8, s12 = 12, s16 = 16, s24 = 24 },
  type = { h32 = 32, h24 = 24, b16 = 16, b14 = 14, c12 = 12 },
}

local CONSTANTS = {
  panelSize = Vector2.new(1140, 860),
  panelSizeMobile = Vector2.new(920, 720),
  gridMinCardWidth = 300,
  gridMaxCardWidth = 560,
  gridGutter = 20, -- fixed gutters 18–24px
  animFast = 0.15,
  animMed = 0.22,
  animBounce = 0.24,
  purchaseTimeout = 15,
}

-- ====================================================================
-- Lightweight cache
-- ====================================================================
local function now()
  return os.clock()
end

local function newCache(ttlSeconds)
  return {
    ttl = ttlSeconds or 300,
    data = {},
    set = function(self, key, value)
      self.data[key] = { value = value, t = now() }
    end,
    get = function(self, key)
      local entry = self.data[key]
      if not entry then return nil end
      if now() - entry.t > self.ttl then
        self.data[key] = nil
        return nil
      end
      return entry.value
    end,
    clear = function(self, key)
      if key then self.data[key] = nil else self.data = {} end
    end
  }
end

local productInfoCache = newCache(300)
local ownershipCache = newCache(60)

-- ====================================================================
-- Sound System
-- ====================================================================
local SoundSystem = { sounds = {}, enabled = true }
function SoundSystem:init()
  local map = {
    click = { id = "rbxassetid://876939830", volume = 0.45 },
    hover = { id = "rbxassetid://10066936758", volume = 0.20 },
    open = { id = "rbxassetid://452267918", volume = 0.50 },
    close = { id = "rbxassetid://452267918", volume = 0.50 },
    success = { id = "rbxassetid://1843521758", volume = 0.50 },
    error = { id = "rbxassetid://138090596", volume = 0.50 },
  }
  local preload = {}
  for name, cfg in pairs(map) do
    local s = Instance.new("Sound")
    s.Name = "Sanrio_" .. name
    s.SoundId = cfg.id
    s.Volume = cfg.volume
    s.RollOffMode = Enum.RollOffMode.InverseTapered
    s.Parent = SoundService
    self.sounds[name] = s
    table.insert(preload, s)
  end
  task.spawn(function()
    pcall(function() ContentProvider:PreloadAsync(preload) end)
  end)
end
function SoundSystem:play(name)
  if self.enabled and self.sounds[name] then
    self.sounds[name]:Play()
  end
end

-- ====================================================================
-- Data (Products + Passes)
-- ====================================================================
local Data = {}
Data.products = {
  cash = {
    { id = 3366419712, amount = 1000,  name = "1,000 Cash",  description = "A small boost to get you started", icon = "rbxassetid://10709728059", price = 0 },
    { id = 3366420012, amount = 5000,  name = "5,000 Cash",  description = "Perfect for mid-game expansion",   icon = "rbxassetid://10709728059", price = 0 },
    { id = 3366420478, amount = 10000, name = "10,000 Cash", description = "Accelerate your progress",          icon = "rbxassetid://10709728059", price = 0 },
    { id = 3366420800, amount = 25000, name = "25,000 Cash", description = "Great value bundle",                 icon = "rbxassetid://10709728059", price = 0 },
  },
  gamepasses = {
    { id = 1412171840, name = "Auto Collect", description = "Automatically collect all cash drops", icon = "rbxassetid://10709727148", price = 99, hasToggle = true },
    { id = 1398974710, name = "2x Cash",      description = "Double all cash earned permanently",   icon = "rbxassetid://10709727148", price = 199, hasToggle = false },
  }
}

local function formatNumber(n)
  local s = tostring(n)
  local k = 1
  while k ~= 0 do
    s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
  end
  return s
end

function Data:getProductInfo(id)
  local c = productInfoCache:get(id)
  if c then return c end
  local ok, info = pcall(function()
    return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
  end)
  if ok and info then
    productInfoCache:set(id, info)
    return info
  end
end

function Data:getGamePassInfo(id)
  local key = "pass_" .. tostring(id)
  local c = productInfoCache:get(key)
  if c then return c end
  local ok, info = pcall(function()
    return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
  end)
  if ok and info then
    productInfoCache:set(key, info)
    return info
  end
end

function Data:checkOwnership(passId)
  local key = ("%d_%d"):format(LocalPlayer.UserId, passId)
  local c = ownershipCache:get(key)
  if c ~= nil then return c end
  local ok, owns = pcall(function()
    return MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, passId)
  end)
  if ok then
    ownershipCache:set(key, owns)
    return owns
  end
  return false
end

function Data:refreshPrices()
  for _, p in ipairs(self.products.cash) do
    local info = self:getProductInfo(p.id)
    if info and info.PriceInRobux then
      p.price = info.PriceInRobux
    end
  end
  for _, gp in ipairs(self.products.gamepasses) do
    local info = self:getGamePassInfo(gp.id)
    if info and info.PriceInRobux then
      gp.price = info.PriceInRobux
    end
  end
end

-- ====================================================================
-- UI Helpers
-- ====================================================================
local function tween(o, props, d, style, dir)
  local info = TweenInfo.new(d or CONSTANTS.animMed, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
  local t = TweenService:Create(o, info, props)
  t:Play()
  return t
end

local function addCorner(parent, radius)
  local c = Instance.new("UICorner")
  c.CornerRadius = radius or Theme.radius.r16
  c.Parent = parent
  return c
end

local function addStroke(parent, color, thickness, transparency)
  local s = Instance.new("UIStroke")
  s.Color = color or Theme.colors.stroke
  s.Thickness = thickness or 1
  s.Transparency = transparency or 0.15
  s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
  s.Parent = parent
  return s
end

local function addPadding(parent, t, r, b, l)
  local p = Instance.new("UIPadding")
  if t then p.PaddingTop = UDim.new(0, t) end
  if r then p.PaddingRight = UDim.new(0, r) end
  if b then p.PaddingBottom = UDim.new(0, b) end
  if l then p.PaddingLeft = UDim.new(0, l) end
  p.Parent = parent
  return p
end

local function addListLayout(parent, direction, padding)
  local layout = Instance.new("UIListLayout")
  layout.FillDirection = direction or Enum.FillDirection.Vertical
  layout.Padding = UDim.new(0, padding or Theme.spacing.s12)
  layout.SortOrder = Enum.SortOrder.LayoutOrder
  layout.Parent = parent
  return layout
end

local function addAspect(parent, ratio)
  local a = Instance.new("UIAspectRatioConstraint")
  a.AspectRatio = ratio or 16/9
  a.Parent = parent
  return a
end

local function addUIScale(parent, scale)
  local s = Instance.new("UIScale")
  s.Scale = scale or 1
  s.Parent = parent
  return s
end

-- Outcome Banner
local function showBanner(root, text, kind)
  local color = Theme.colors.info
  if kind == "success" then color = Theme.colors.success end
  if kind == "error" then color = Theme.colors.danger end
  local banner = Instance.new("Frame")
  banner.Name = "Banner"
  banner.BackgroundColor3 = color
  banner.Size = UDim2.new(1, -48, 0, 40)
  banner.Position = UDim2.fromOffset(24, 24)
  banner.AnchorPoint = Vector2.new(0, 0)
  banner.BackgroundTransparency = 0.05
  banner.Parent = root
  addCorner(banner, Theme.radius.r10)
  addStroke(banner, Color3.new(1, 1, 1), 1, 0.7)

  local label = Instance.new("TextLabel")
  label.BackgroundTransparency = 1
  label.Text = text
  label.Font = Enum.Font.GothamBold
  label.TextSize = Theme.type.b14
  label.TextColor3 = Color3.new(1, 1, 1)
  label.TextXAlignment = Enum.TextXAlignment.Center
  label.TextYAlignment = Enum.TextYAlignment.Center
  label.Size = UDim2.fromScale(1, 1)
  label.Parent = banner

  banner.BackgroundTransparency = 1
  banner.Visible = true
  tween(banner, { BackgroundTransparency = 0.05 }, 0.12)
  task.delay(2.0, function()
    if banner and banner.Parent then
      tween(banner, { BackgroundTransparency = 1 }, 0.12)
      task.delay(0.14, function()
        if banner then banner:Destroy() end
      end)
    end
  end)
end

-- Spinner helper for buttons
local function attachSpinner(button)
  local holder = Instance.new("Frame")
  holder.Name = "Spinner"
  holder.BackgroundTransparency = 1
  holder.Size = UDim2.fromOffset(16, 16)
  holder.AnchorPoint = Vector2.new(1, 0.5)
  holder.Position = UDim2.new(1, -8, 0.5, 0)
  holder.Visible = false
  holder.Parent = button

  local circle = Instance.new("ImageLabel")
  circle.BackgroundTransparency = 1
  circle.Image = "rbxassetid://9943163532" -- generic spinner asset
  circle.ImageColor3 = Color3.new(1, 1, 1)
  circle.Size = UDim2.fromScale(1, 1)
  circle.Parent = holder

  local connection
  local api = {}
  function api:start()
    if holder.Visible then return end
    holder.Visible = true
    local angle = 0
    connection = RunService.RenderStepped:Connect(function(dt)
      angle += dt * 360 * 1.5
      circle.Rotation = angle % 360
    end)
  end
  function api:stop()
    holder.Visible = false
    if connection then connection:Disconnect() end
    circle.Rotation = 0
  end
  function api:destroy()
    if connection then connection:Disconnect() end
    holder:Destroy()
  end
  return api
end

-- Skeleton shimmer helper
local function addSkeleton(parent)
  local sk = Instance.new("Frame")
  sk.BackgroundColor3 = Theme.colors.stroke:lerp(Theme.colors.surfaceAlt, 0.35)
  sk.BackgroundTransparency = 0
  sk.Size = UDim2.fromScale(1, 1)
  sk.Name = "Skeleton"
  sk.Parent = parent
  addCorner(sk, Theme.radius.r10)

  local grad = Instance.new("UIGradient")
  grad.Rotation = 0
  grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(230, 232, 238)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(250, 251, 253)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(230, 232, 238)),
  })
  grad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0.0, 0.25),
    NumberSequenceKeypoint.new(0.5, 0.0),
    NumberSequenceKeypoint.new(1.0, 0.25),
  })
  grad.Parent = sk

  local anim
  local api = {}
  function api:start()
    if anim then return end
    local offset = 1
    grad.Offset = Vector2.new(-offset, 0)
    anim = RunService.RenderStepped:Connect(function(dt)
      local o = grad.Offset.X + dt * 1.2
      if o > offset then o = -offset end
      grad.Offset = Vector2.new(o, 0)
    end)
  end
  function api:stopAndRemove()
    if anim then anim:Disconnect() end
    if sk then sk:Destroy() end
  end
  return api
end

-- ====================================================================
-- Shop UI
-- ====================================================================
local Shop = {}
Shop.__index = Shop

function Shop.new()
  local self = setmetatable({}, Shop)
  self.gui = nil
  self.toggleButton = nil
  self.mainPanel = nil
  self.tabButtons = {}
  self.pages = {}
  self.cardRefs = { Cash = {}, Gamepasses = {} }
  self._connections = {}
  self._pending = {}
  self._gridBusy = false
  self._lastCols = 0
  self._lastFocus = nil
  self:initialize()
  return self
end

function Shop:_safeInsets()
  local insets = GuiService:GetSafeZoneInsets()
  return insets
end

function Shop:_isMobile()
  local cam = workspace.CurrentCamera
  if not cam then return false end
  local v = cam.ViewportSize
  return v.X < 1024 or GuiService:IsTenFootInterface()
end

function Shop:_panelTargetSize()
  local mobile = self:_isMobile()
  return mobile and CONSTANTS.panelSizeMobile or CONSTANTS.panelSize
end

function Shop:_preloadAssets()
  local ids = {
    "rbxassetid://17398522865", -- shop icon
    "rbxassetid://10709728059",
    "rbxassetid://10709727148",
    "rbxassetid://9943163532", -- spinner
  }
  for _, p in ipairs(Data.products.cash) do if p.icon then table.insert(ids, p.icon) end end
  for _, p in ipairs(Data.products.gamepasses) do if p.icon then table.insert(ids, p.icon) end end
  task.spawn(function() pcall(function() ContentProvider:PreloadAsync(ids) end) end)
end

function Shop:initialize()
  SoundSystem:init()
  Data:refreshPrices()
  self:_preloadAssets()
  self:_createToggleButton()
  self:_createMain()
  self:_wireGlobalInput()
end

function Shop:_createToggleButton()
  local sg = PlayerGui:FindFirstChild("SanrioShopToggle") or Instance.new("ScreenGui")
  sg.Name = "SanrioShopToggle"
  sg.ResetOnSpawn = false
  sg.DisplayOrder = 999
  sg.Parent = PlayerGui

  local btn = Instance.new("TextButton")
  btn.Name = "OpenShop"
  btn.Text = ""
  btn.AutoButtonColor = false
  btn.Size = UDim2.fromOffset(180, 60)
  btn.AnchorPoint = Vector2.new(1, 1)
  btn.Position = UDim2.new(1, -20, 1, -20)
  btn.BackgroundColor3 = Theme.colors.surface
  btn.TextColor3 = Color3.new(1,1,1)
  btn.Font = Enum.Font.GothamBold
  btn.TextSize = Theme.type.b16
  btn.Parent = sg
  addCorner(btn, UDim.new(1, 0))
  addStroke(btn, Theme.colors.accent, 2, 0)

  local icon = Instance.new("ImageLabel")
  icon.BackgroundTransparency = 1
  icon.Image = "rbxassetid://17398522865"
  icon.Size = UDim2.fromOffset(32, 32)
  icon.Position = UDim2.fromOffset(16, 14)
  icon.Parent = btn

  local label = Instance.new("TextLabel")
  label.BackgroundTransparency = 1
  label.Text = "Shop"
  label.TextColor3 = Theme.colors.text
  label.Font = Enum.Font.GothamBold
  label.TextSize = 20
  label.TextXAlignment = Enum.TextXAlignment.Left
  label.Position = UDim2.fromOffset(56, 0)
  label.Size = UDim2.new(1, -64, 1, 0)
  label.Parent = btn

  btn.MouseButton1Click:Connect(function()
    SoundSystem:play("click")
    self:toggle()
  end)

  self.toggleButton = btn
end

function Shop:_applySafeAreaPadding(container)
  local insets = self:_safeInsets()
  addPadding(container, math.floor(insets.Top + 0.5), math.floor(insets.Right + 0.5), math.floor(insets.Bottom + 0.5), math.floor(insets.Left + 0.5))
end

function Shop:_createMain()
  local gui = PlayerGui:FindFirstChild("SanrioShopMain") or Instance.new("ScreenGui")
  gui.Name = "SanrioShopMain"
  gui.ResetOnSpawn = false
  gui.DisplayOrder = 1000
  gui.Enabled = false
  gui.Parent = PlayerGui

  -- Backdrop + blur
  local blur = Lighting:FindFirstChild("SanrioShopBlur") or Instance.new("BlurEffect")
  blur.Name = "SanrioShopBlur"
  blur.Size = 0
  blur.Parent = Lighting
  self._blur = blur

  local dim = Instance.new("Frame")
  dim.BackgroundColor3 = Color3.new(0, 0, 0)
  dim.BackgroundTransparency = 0.35
  dim.Size = UDim2.fromScale(1, 1)
  dim.Active = true
  dim.Parent = gui
  dim.ZIndex = 1
  dim.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
      self:close()
    end
  end)

  local panel = Instance.new("Frame")
  panel.Name = "Panel"
  panel.BackgroundColor3 = Theme.colors.bg
  panel.Size = UDim2.fromOffset(self:_panelTargetSize().X, self:_panelTargetSize().Y)
  panel.AnchorPoint = Vector2.new(0.5, 0.5)
  panel.Position = UDim2.fromScale(0.5, 0.5)
  panel.Parent = gui
  panel.ZIndex = 2
  addCorner(panel, Theme.radius.r24)
  addStroke(panel, Theme.colors.stroke, 1, 0)

  -- Header (glass-like)
  local header = Instance.new("Frame")
  header.Name = "Header"
  header.BackgroundColor3 = Theme.colors.surfaceAlt
  header.Size = UDim2.new(1, -48, 0, 80)
  header.Position = UDim2.fromOffset(24, 24)
  header.Parent = panel
  addCorner(header, Theme.radius.r16)
  addStroke(header, Theme.colors.stroke, 1, 0.35)

  local logo = Instance.new("ImageLabel")
  logo.BackgroundTransparency = 1
  logo.Image = "rbxassetid://17398522865"
  logo.Size = UDim2.fromOffset(60, 60)
  logo.Position = UDim2.fromOffset(16, 10)
  logo.Parent = header

  local title = Instance.new("TextLabel")
  title.BackgroundTransparency = 1
  title.Text = "Sanrio Shop"
  title.TextColor3 = Theme.colors.text
  title.Font = Enum.Font.GothamBold
  title.TextSize = Theme.type.h24
  title.TextXAlignment = Enum.TextXAlignment.Left
  title.Size = UDim2.new(1, -200, 1, 0)
  title.Position = UDim2.fromOffset(92, 0)
  title.Parent = header

  local closeBtn = Instance.new("TextButton")
  closeBtn.Text = "X"
  closeBtn.AutoButtonColor = false
  closeBtn.Size = UDim2.fromOffset(48, 48)
  closeBtn.AnchorPoint = Vector2.new(0, 0.5)
  closeBtn.Position = UDim2.new(1, -64, 0.5, 0)
  closeBtn.BackgroundColor3 = Theme.colors.accent
  closeBtn.TextColor3 = Color3.new(1, 1, 1)
  closeBtn.Font = Enum.Font.GothamBold
  closeBtn.TextSize = Theme.type.b16
  closeBtn.Parent = header
  addCorner(closeBtn, UDim.new(0.5, 0))
  closeBtn.MouseButton1Click:Connect(function()
    SoundSystem:play("click")
    self:close()
  end)

  -- Tabs
  local tabs = Instance.new("Frame")
  tabs.BackgroundTransparency = 1
  tabs.Size = UDim2.new(1, -48, 0, 48)
  tabs.Position = UDim2.fromOffset(24, 116)
  tabs.Parent = panel
  addListLayout(tabs, Enum.FillDirection.Horizontal, 12)

  local function makeTab(id, labelText, iconId, tint)
    local btn = Instance.new("TextButton")
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Size = UDim2.fromOffset(160, 48)
    btn.BackgroundColor3 = Theme.colors.surface
    btn.Parent = tabs
    addCorner(btn, UDim.new(0.5, 0))
    addStroke(btn, Theme.colors.stroke, 1, 0.2)

    local inner = Instance.new("Frame")
    inner.BackgroundTransparency = 1
    inner.Size = UDim2.fromScale(1, 1)
    inner.Parent = btn
    addPadding(inner, 0, Theme.spacing.s16, 0, Theme.spacing.s16)
    addListLayout(inner, Enum.FillDirection.Horizontal, 8)

    local ico = Instance.new("ImageLabel")
    ico.BackgroundTransparency = 1
    ico.Image = iconId
    ico.Size = UDim2.fromOffset(24, 24)
    ico.Parent = inner

    local lab = Instance.new("TextLabel")
    lab.BackgroundTransparency = 1
    lab.Text = labelText
    lab.TextColor3 = Theme.colors.text
    lab.Font = Enum.Font.GothamMedium
    lab.TextSize = Theme.type.b14
    lab.TextXAlignment = Enum.TextXAlignment.Left
    lab.Size = UDim2.new(1, -32, 1, 0)
    lab.Parent = inner

    self.tabButtons[id] = { button = btn, icon = ico, label = lab, tint = tint }

    btn.MouseButton1Click:Connect(function()
      SoundSystem:play("click")
      self:selectTab(id)
    end)
  end

  makeTab("Cash", "Cash", "rbxassetid://10709728059", Theme.colors.cinna)
  makeTab("Gamepasses", "Passes", "rbxassetid://10709727148", Theme.colors.kuromi)

  -- Content container with safe-area padding
  local content = Instance.new("Frame")
  content.BackgroundTransparency = 1
  content.Name = "Content"
  content.Size = UDim2.new(1, -48, 1, -180)
  content.Position = UDim2.fromOffset(24, 156)
  content.Parent = panel
  self:_applySafeAreaPadding(content)

  -- Pages
  local cashPage = self:_createPage(content, "Cash")
  local passPage = self:_createPage(content, "Gamepasses")
  self.pages.Cash = cashPage
  self.pages.Gamepasses = passPage

  self.gui = gui
  self.mainPanel = panel

  -- Default tab
  task.defer(function()
    self:selectTab("Cash")
  end)
end

function Shop:_createPage(parent, id)
  local page = Instance.new("Frame")
  page.Name = id .. "Page"
  page.BackgroundTransparency = 1
  page.Visible = false
  page.Size = UDim2.fromScale(1, 1)
  page.Parent = parent

  local sf = Instance.new("ScrollingFrame")
  sf.Name = "Scroll"
  sf.BackgroundTransparency = 1
  sf.BorderSizePixel = 0
  sf.ScrollBarThickness = 8
  sf.ScrollBarImageColor3 = Theme.colors.stroke
  sf.Size = UDim2.fromScale(1, 1)
  sf.CanvasSize = UDim2.new(0, 0, 0, 0)
  sf.Parent = page

  local grid = Instance.new("UIGridLayout")
  grid.CellPadding = UDim2.fromOffset(CONSTANTS.gridGutter, CONSTANTS.gridGutter)
  grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
  grid.SortOrder = Enum.SortOrder.LayoutOrder
  grid.Parent = sf

  -- Compute CanvasSize when content changes
  grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    sf.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + Theme.spacing.s16)
  end)

  -- Bind grid responsiveness
  self:_bindGrid(sf, grid, id)

  -- Build cards
  if id == "Cash" then
    for _, p in ipairs(Data.products.cash) do
      local card = self:_createProductCard(p, "cash", sf)
      table.insert(self.cardRefs.Cash, card)
    end
  else
    for _, p in ipairs(Data.products.gamepasses) do
      local card = self:_createProductCard(p, "gamepass", sf)
      table.insert(self.cardRefs.Gamepasses, card)
    end
  end

  return page
end

-- Responsive grid with throttled recompute and D-pad navigation
function Shop:_bindGrid(scrollingFrame, grid, id)
  local function computeColumns(containerWidth)
    local gutter = CONSTANTS.gridGutter
    local minW, maxW = CONSTANTS.gridMinCardWidth, CONSTANTS.gridMaxCardWidth
    local cols = math.clamp(math.floor((containerWidth + gutter) / (minW + gutter)), 1, 3)
    local ideal = (containerWidth - gutter * (cols - 1)) / cols
    local cardW = math.clamp(math.floor(ideal + 0.5), minW, maxW)
    return cols, cardW
  end

  local function applyLayout()
    if self._gridBusy then return end
    self._gridBusy = true
    task.delay(0.05, function()
      if not scrollingFrame.Parent then return end
      local w = scrollingFrame.AbsoluteSize.X
      local cols, cardW = computeColumns(w)
      grid.CellSize = UDim2.fromOffset(cardW, math.floor(cardW * 0.576) + 160) -- 16:9 image + info area
      self:_assignGridNavigation(id, cols)
      self._lastCols = cols
      self._gridBusy = false
    end)
  end

  table.insert(self._connections, scrollingFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout))
  table.insert(self._connections, grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + Theme.spacing.s16)
  end))

  task.defer(applyLayout)
end

function Shop:_assignGridNavigation(id, cols)
  local list = self.cardRefs[id]
  if not list or #list == 0 then return end
  cols = cols or self._lastCols
  if cols <= 0 then return end
  for i, card in ipairs(list) do
    if card and card.root then
      card.root.Selectable = true
      local up = i - cols
      local down = i + cols
      local left = i - 1
      local right = i + 1
      if list[up] and list[up].root then card.root.NextSelectionUp = list[up].root end
      if list[down] and list[down].root then card.root.NextSelectionDown = list[down].root end
      if i % cols ~= 1 and list[left] and list[left].root then card.root.NextSelectionLeft = list[left].root end
      if i % cols ~= 0 and list[right] and list[right].root then card.root.NextSelectionRight = list[right].root end
    end
  end
end

-- Card creation
function Shop:_createProductCard(product, kind, parent)
  local isGamepass = (kind == "gamepass")
  local tint = isGamepass and Theme.colors.kuromi or Theme.colors.cinna

  local root = Instance.new("Frame")
  root.Name = product.name .. "Card"
  root.AutomaticSize = Enum.AutomaticSize.None
  root.Size = UDim2.fromOffset(CONSTANTS.gridMinCardWidth, 300)
  root.BackgroundColor3 = Theme.colors.surface
  root.BorderSizePixel = 0
  root.ClipsDescendants = true
  root.Parent = parent
  addCorner(root, Theme.radius.r16)
  addStroke(root, tint, 2, 0.5)

  -- Hover scale (no lift)
  local uiScale = addUIScale(root, 1)
  root.MouseEnter:Connect(function()
    SoundSystem:play("hover")
    tween(uiScale, { Scale = 1.02 }, CONSTANTS.animFast)
  end)
  root.MouseLeave:Connect(function()
    tween(uiScale, { Scale = 1.0 }, CONSTANTS.animFast)
  end)

  -- Focus ring
  local focusStroke = addStroke(root, tint, 2, 0.0)
  focusStroke.Enabled = false
  root.SelectionGained:Connect(function()
    focusStroke.Enabled = true
  end)
  root.SelectionLost:Connect(function()
    focusStroke.Enabled = false
  end)

  local content = Instance.new("Frame")
  content.BackgroundTransparency = 1
  content.Size = UDim2.new(1, -24, 1, -24)
  content.Position = UDim2.fromOffset(12, 12)
  content.Parent = root

  -- Image area (16:9)
  local imageContainer = Instance.new("Frame")
  imageContainer.BackgroundColor3 = Theme.colors.surfaceAlt
  imageContainer.Size = UDim2.new(1, 0, 0, 0)
  imageContainer.AutomaticSize = Enum.AutomaticSize.Y
  imageContainer.Parent = content
  addCorner(imageContainer, Theme.radius.r12 or Theme.radius.r16)
  addAspect(imageContainer, 16/9)

  local hero = Instance.new("ImageLabel")
  hero.BackgroundTransparency = 1
  hero.ScaleType = Enum.ScaleType.Fit
  hero.Size = UDim2.fromScale(1, 1)
  hero.Image = product.icon or "rbxassetid://0"
  hero.Parent = imageContainer

  -- Skeleton shimmer for hero
  local heroSkeleton = addSkeleton(imageContainer)
  heroSkeleton:start()

  -- Info area
  local info = Instance.new("Frame")
  info.BackgroundTransparency = 1
  info.Size = UDim2.new(1, 0, 0, 120)
  info.Position = UDim2.fromOffset(0, 8)
  info.Parent = content

  local nameLabel = Instance.new("TextLabel")
  nameLabel.BackgroundTransparency = 1
  nameLabel.Text = product.name
  nameLabel.TextColor3 = Theme.colors.text
  nameLabel.Font = Enum.Font.GothamBold
  nameLabel.TextSize = Theme.type.b16
  nameLabel.TextXAlignment = Enum.TextXAlignment.Left
  nameLabel.Size = UDim2.new(1, 0, 0, 24)
  nameLabel.Parent = info

  local benefit = isGamepass and (product.description or "") or ("Includes " .. formatNumber(product.amount) .. " Cash")
  local desc = Instance.new("TextLabel")
  desc.BackgroundTransparency = 1
  desc.Text = benefit
  desc.TextColor3 = Theme.colors.textSecondary
  desc.Font = Enum.Font.Gotham
  desc.TextSize = Theme.type.b14
  desc.TextXAlignment = Enum.TextXAlignment.Left
  desc.TextWrapped = true
  desc.Size = UDim2.new(1, 0, 0, 34)
  desc.Position = UDim2.fromOffset(0, 26)
  desc.Parent = info

  -- Price / Owned pill (top-right overlay)
  local pill = Instance.new("TextLabel")
  pill.Name = "Pill"
  pill.BackgroundColor3 = tint
  pill.TextColor3 = Color3.new(1,1,1)
  pill.Font = Enum.Font.GothamMedium
  pill.TextSize = Theme.type.c12
  pill.Text = ""
  pill.AutomaticSize = Enum.AutomaticSize.X
  pill.Size = UDim2.fromOffset(60, 22)
  pill.Position = UDim2.new(1, -66, 0, 8)
  pill.AnchorPoint = Vector2.new(0, 0)
  pill.Parent = content
  addCorner(pill, Theme.radius.r10)
  addPadding(pill, 2, 8, 2, 8)

  local owned = isGamepass and Data:checkOwnership(product.id) or false
  if isGamepass then
    pill.Text = owned and "OWNED" or (product.price and ("R$" .. tostring(product.price)) or "")
    pill.BackgroundColor3 = owned and Theme.colors.success or tint
  else
    pill.Text = (product.price and ("R$" .. tostring(product.price))) or ""
    pill.BackgroundColor3 = tint
  end

  -- Price label (for skeleton fade-in)
  local priceLabel = Instance.new("TextLabel")
  priceLabel.BackgroundTransparency = 1
  priceLabel.Text = isGamepass and "Tap to purchase" or "Tap to purchase"
  priceLabel.TextColor3 = tint
  priceLabel.Font = Enum.Font.GothamBold
  priceLabel.TextSize = Theme.type.b14
  priceLabel.TextXAlignment = Enum.TextXAlignment.Left
  priceLabel.Size = UDim2.new(1, 0, 0, 20)
  priceLabel.Position = UDim2.fromOffset(0, 64)
  priceLabel.Parent = info

  local priceSkeleton = addSkeleton(priceLabel)
  priceSkeleton:start()

  -- Purchase button
  local button = Instance.new("TextButton")
  button.Text = owned and "Owned" or "Purchase"
  button.AutoButtonColor = false
  button.Size = UDim2.new(1, 0, 0, 40)
  button.Position = UDim2.new(0, 0, 1, -40)
  button.BackgroundColor3 = owned and Theme.colors.success or tint
  button.TextColor3 = Color3.new(1, 1, 1)
  button.Font = Enum.Font.GothamBold
  button.TextSize = Theme.type.b16
  button.Parent = info
  addCorner(button, Theme.radius.r10)

  local spinner = attachSpinner(button)

  if owned then
    button.Active = false
  end

  -- Toggle switch for Auto Collect (if owned and hasToggle)
  if isGamepass and product.hasToggle and owned then
    local container = Instance.new("Frame")
    container.Name = "ToggleContainer"
    container.Size = UDim2.fromOffset(56, 28)
    container.Position = UDim2.new(1, -64, 0, 8)
    container.BackgroundColor3 = Theme.colors.stroke
    container.BorderSizePixel = 0
    container.Parent = imageContainer
    addCorner(container, UDim.new(0.5, 0))

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(24, 24)
    knob.Position = UDim2.fromOffset(2, 2)
    knob.BackgroundColor3 = Theme.colors.surface
    knob.Parent = container
    addCorner(knob, UDim.new(0.5, 0))

    local click = Instance.new("TextButton")
    click.BackgroundTransparency = 1
    click.Text = ""
    click.Size = UDim2.fromScale(1, 1)
    click.Parent = container

    local state = false
    if Remotes then
      local rf = Remotes:FindFirstChild("GetAutoCollectState")
      if rf and rf:IsA("RemoteFunction") then
        local ok, val = pcall(function()
          return rf:InvokeServer()
        end)
        if ok and type(val) == "boolean" then state = val end
      end
    end

    local function renderToggle()
      container.BackgroundColor3 = state and Theme.colors.success or Theme.colors.stroke
      tween(knob, { Position = state and UDim2.fromOffset(30, 2) or UDim2.fromOffset(2, 2) }, CONSTANTS.animFast)
    end
    renderToggle()

    click.MouseButton1Click:Connect(function()
      state = not state
      renderToggle()
      if Remotes then
        local ev = Remotes:FindFirstChild("AutoCollectToggle")
        if ev and ev:IsA("RemoteEvent") then ev:FireServer(state) end
      end
      SoundSystem:play("click")
    end)
  end

  -- Button click: prompt purchase
  button.MouseButton1Click:Connect(function()
    if owned then return end
    button.Active = false
    button.Text = "Processing..."
    spinner:start()
    SoundSystem:play("click")
    self:_promptPurchase(product, kind, button, spinner)
  end)

  -- After a brief moment, hide skeletons (post preload/prices)
  task.delay(0.35, function()
    heroSkeleton:stopAndRemove()
    priceSkeleton:stopAndRemove()
  end)

  return { root = root, button = button }
end

function Shop:selectTab(id)
  for key, record in pairs(self.tabButtons) do
    local active = (key == id)
    local tint = record.tint
    local bg = active and tint:lerp(Color3.new(1,1,1), 0.9) or Theme.colors.surface
    tween(record.button, { BackgroundColor3 = bg }, CONSTANTS.animFast)
    local s = record.button:FindFirstChildOfClass("UIStroke")
    if s then s.Color = active and tint or Theme.colors.stroke end
    record.icon.ImageColor3 = active and tint or Theme.colors.text
    record.label.TextColor3 = active and tint or Theme.colors.text
  end

  for key, page in pairs(self.pages) do
    local visible = (key == id)
    page.Visible = visible
    if visible then
      page.BackgroundTransparency = 1
      page.Position = UDim2.fromOffset(0, 12)
      tween(page, { BackgroundTransparency = 0, Position = UDim2.new() }, CONSTANTS.animBounce, Enum.EasingStyle.Back)
    end
  end

  -- Reassign navigation using latest columns
  if id == "Cash" then
    self:_assignGridNavigation("Cash", self._lastCols)
  else
    self:_assignGridNavigation("Gamepasses", self._lastCols)
  end
end

function Shop:_promptPurchase(product, kind, button, spinner)
  self._pending[product.id] = { button = button, spinner = spinner, kind = kind }
  local ok, err
  if kind == "gamepass" then
    ok, err = pcall(function()
      MarketplaceService:PromptGamePassPurchase(LocalPlayer, product.id)
    end)
  else
    ok, err = pcall(function()
      MarketplaceService:PromptProductPurchase(LocalPlayer, product.id)
    end)
  end
  if not ok then
    if spinner then spinner:stop() end
    if button and button.Parent then
      button.Text = "Purchase"
      button.Active = true
    end
    self._pending[product.id] = nil
    SoundSystem:play("error")
    if self.mainPanel then
      showBanner(self.mainPanel, "Could not start purchase.", "error")
    end
    warn("[SanrioShop] Prompt failed:", err)
  else
    -- timeout
    task.delay(CONSTANTS.purchaseTimeout, function()
      local p = self._pending[product.id]
      if p then
        if p.spinner then p.spinner:stop() end
        if p.button and p.button.Parent then
          p.button.Text = "Purchase"
          p.button.Active = true
        end
        self._pending[product.id] = nil
      end
    end)
  end
end

function Shop:refreshAllProducts()
  ownershipCache:clear()
  for _, record in ipairs(self.cardRefs.Gamepasses) do
    if record and record.button and record.button.Parent then
      local card = record.root
      local name = card and card.Name or ""
      local gp
      for _, item in ipairs(Data.products.gamepasses) do
        if name:find(item.name, 1, true) then gp = item break end
      end
      if gp then
        local owned = Data:checkOwnership(gp.id)
        record.button.Text = owned and "Owned" or "Purchase"
        record.button.BackgroundColor3 = owned and Theme.colors.success or Theme.colors.kuromi
        record.button.Active = not owned
      end
    end
  end
end

function Shop:open()
  if not self.gui or self.gui.Enabled then return end
  Data:refreshPrices()
  self:refreshAllProducts()
  self.gui.Enabled = true
  tween(self._blur, { Size = 10 }, CONSTANTS.animMed)
  local sz = self:_panelTargetSize()
  self.mainPanel.Size = UDim2.fromOffset(sz.X * 0.94, sz.Y * 0.94)
  self.mainPanel.Position = UDim2.fromScale(0.5, 0.52)
  tween(self.mainPanel, { Size = UDim2.fromOffset(sz.X, sz.Y), Position = UDim2.fromScale(0.5, 0.5) }, CONSTANTS.animBounce, Enum.EasingStyle.Back)
  SoundSystem:play("open")
end

function Shop:close()
  if not self.gui or not self.gui.Enabled then return end
  tween(self._blur, { Size = 0 }, CONSTANTS.animFast)
  tween(self.mainPanel, { Position = UDim2.fromScale(0.5, 0.55) }, CONSTANTS.animFast)
  task.delay(CONSTANTS.animFast, function()
    if self.gui then self.gui.Enabled = false end
  end)
  SoundSystem:play("close")
end

function Shop:toggle()
  if self.gui and self.gui.Enabled then self:close() else self:open() end
end

function Shop:_wireGlobalInput()
  UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.M then
      self:toggle()
    elseif input.KeyCode == Enum.KeyCode.Escape then
      if self.gui and self.gui.Enabled then self:close() end
    end
  end)
end

-- Lifecycle: ensure toggle persists
LocalPlayer.CharacterAdded:Connect(function()
  task.wait(1)
  if not (PlayerGui:FindFirstChild("SanrioShopToggle")) then
    -- recreate toggle
    local s = Shop
  end
end)

-- Purchase Callbacks
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
  if player ~= LocalPlayer then return end
  local pending = ShopInstance and ShopInstance._pending and ShopInstance._pending[passId]
  if pending then
    if pending.spinner then pending.spinner:stop() end
    if pending.button and pending.button.Parent then
      pending.button.Text = "Purchase"
      pending.button.Active = true
    end
    ShopInstance._pending[passId] = nil
  end
  if purchased then
    ownershipCache:clear()
    if ShopInstance then ShopInstance:refreshAllProducts() end
    if ShopInstance and ShopInstance.mainPanel then
      showBanner(ShopInstance.mainPanel, "Purchase successful!", "success")
    end
    SoundSystem:play("success")
  else
    if ShopInstance and ShopInstance.mainPanel then
      showBanner(ShopInstance.mainPanel, "Purchase cancelled.", "info")
    end
  end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, purchased)
  if player ~= LocalPlayer then return end
  local pending = ShopInstance and ShopInstance._pending and ShopInstance._pending[productId]
  if pending then
    if pending.spinner then pending.spinner:stop() end
    if pending.button and pending.button.Parent then
      pending.button.Text = "Purchase"
      pending.button.Active = true
    end
    ShopInstance._pending[productId] = nil
  end
  if purchased then
    -- Server must grant via ProcessReceipt. Client only shows success.
    if ShopInstance and ShopInstance.mainPanel then
      showBanner(ShopInstance.mainPanel, "Purchase successful!", "success")
    end
    SoundSystem:play("success")
  else
    if ShopInstance and ShopInstance.mainPanel then
      showBanner(ShopInstance.mainPanel, "Purchase cancelled.", "info")
    end
  end
end)

-- Instantiate
local ShopInstance = Shop.new()

print("[SanrioShop] Ready (Cash + Passes)")
return ShopInstance
