--[[
  Tycoon Shop UI - Modern Cute PRO 2025
  Drop this LocalScript in StarterPlayer > StarterPlayerScripts

  Highlights
  - True responsive layout (mobile-first) with dynamic grid columns
  - Safe-area aware (Roblox top bar, notches) + overlay click-to-close
  - Ownership caching + concurrency-guarded purchase flow with timeout spinner
  - Visual polish: owned pill, hover/press states, skeleton shimmer while loading
  - Gamepad-ready: selection ring, B to close, X to toggle, focus landing
  - Settings sync for Auto Collect across all toggles + session persistence (Attributes)
  - Gentle world blur and subtle depth; content preloading for snappy first open

  Notes
  - Replace dev product and gamepass IDs in ProductData with yours
  - Expects remotes in ReplicatedStorage: TycoonRemotes/{AutoCollectToggle:RemoteEvent,
    GetAutoCollectState:RemoteFunction, GrantProductCurrency:RemoteEvent, GamepassPurchased:RemoteEvent}
]]

-- Services
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ContextActionService = game:GetService("ContextActionService")
local ContentProvider = game:GetService("ContentProvider")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Remotes (soft)
local Remotes = ReplicatedStorage:FindFirstChild("TycoonRemotes")

-- Versioning / Flags
local SHOP_VERSION = "7.2.0"
local DEBUG = false

local function dprint(...)
	if DEBUG then print("[Shop]", ...) end
end

-- Timings
local SPEED = {
	FAST = 0.15,
	MED = 0.25,
	SLOW = 0.40,
}

local DURATIONS = {
	PRICE = 300,
	OWNERSHIP = 60,
	PLAYER = 30,
	PURCHASE_TIMEOUT = 18,
	REFRESH = 30,
}

-- Theme
local Theme = {
	colors = {
		bg = Color3.fromRGB(252, 250, 248),
		surface = Color3.fromRGB(255, 255, 255),
		surface2 = Color3.fromRGB(248, 245, 250),
		text = Color3.fromRGB(44, 40, 52),
		muted = Color3.fromRGB(118, 110, 130),

		primary = Color3.fromRGB(180, 226, 216), -- mint
		primaryDark = Color3.fromRGB(148, 194, 184),
		primaryContainer = Color3.fromRGB(220, 246, 240),
		onPrimary = Color3.fromRGB(255, 255, 255),

		secondary = Color3.fromRGB(208, 198, 255), -- lavender
		secondaryDark = Color3.fromRGB(176, 166, 223),
		secondaryContainer = Color3.fromRGB(235, 230, 255),
		onSecondary = Color3.fromRGB(255, 255, 255),

		success = Color3.fromRGB(127, 196, 146),
		error = Color3.fromRGB(255, 122, 142),
		outline = Color3.fromRGB(226, 220, 228),
		outline2 = Color3.fromRGB(238, 234, 240),
		shadow = Color3.fromRGB(200, 190, 210),
	},
	font = {
		regular = Enum.Font.Gotham,
		medium = Enum.Font.GothamMedium,
		bold = Enum.Font.GothamBold,
	},
	typo = {
		display = 28,
		head = 20,
		headSm = 18,
		body = 16,
		bodySm = 14,
		label = 14,
	},
	radius = {
		xs = UDim.new(0, 6),
		sm = UDim.new(0, 10),
		md = UDim.new(0, 14),
		lg = UDim.new(0, 20),
		full = UDim.new(1, 0),
	},
}

-- Assets (swap to yours)
local Assets = {
	icons = {
		cash = "rbxassetid://14978048121",
		gamepass = "rbxassetid://14978047952",
		shop = "rbxassetid://14978048006",
		close = "rbxassetid://14978047806",
		check = "rbxassetid://14978047859",
		settings = "rbxassetid://14978048064",
		sparkle = "rbxassetid://14978048177",
		spinner = "rbxassetid://10901325041", -- simple ring
	},
	sfx = {
		click = "rbxassetid://876939830",
		hover = "rbxassetid://12221967",
		open = "rbxassetid://9113880610",
		close = "rbxassetid://9113881154",
		purchase = "rbxassetid://203785492",
		error = "rbxassetid://2767090566",
	},
}

-- Product Data (replace IDs)
local ProductData = {
	cash = {
		{id = 1897730242, amount = 1000, name = "Starter Pack", description = "Perfect for beginners"},
		{id = 1897730373, amount = 5000, name = "Builder Bundle", description = "Expand your tycoon"},
		{id = 1897730467, amount = 10000, name = "Pro Package", description = "Serious business boost"},
		{id = 1897730581, amount = 50000, name = "Elite Vault", description = "Major expansion fund"},
		{id = 1234567001, amount = 100000, name = "Mega Cache", description = "Transform your empire"},
		{id = 1234567002, amount = 250000, name = "Quarter Mil", description = "Investment powerhouse"},
		{id = 1234567003, amount = 500000, name = "Half Million", description = "Tycoon acceleration"},
		{id = 1234567004, amount = 1000000, name = "Millionaire", description = "Join the elite club"},
	},
	passes = {
		{id = 1412171840, name = "Auto Collect", description = "Collects cash automatically every minute", hasToggle = true},
		{id = 1398974710, name = "2x Cash", description = "Double all earnings permanently"},
		{id = 1234567890, name = "VIP Access", description = "Exclusive VIP benefits and areas"},
		{id = 1234567891, name = "Speed Boost", description = "25% faster production speed"},
	},
}

-- Utilities
local function formatNumber(n)
	if n >= 1e9 then
		return string.format("%.1fB", n/1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n/1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n/1e3)
	end
	return tostring(n)
end

local function formatCommas(n)
	local s = tostring(n)
	local k
	repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
	return s
end

local function viewport()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1920, 1080)
end

local function smallScreen()
	return viewport().X < 768
end

local function gridColumns()
	local w = viewport().X
	if w < 600 then return 1 end
	if w < 950 then return 2 end
	return 3
end

local function getSafeInsets()
	local inset = GuiService:GetGuiInset()
	return {
		top = inset.Y,
		bottom = 8,
		left = 8,
		right = 8,
	}
end

-- Lightweight cache
local Cache = {}
Cache.__index = Cache
function Cache.new(ttl)
	return setmetatable({ttl = ttl, map = {}}, Cache)
end
function Cache:get(key)
	local e = self.map[key]
	if not e then return nil end
	if (tick() - e.t) > self.ttl then self.map[key] = nil; return nil end
	return e.v
end
function Cache:set(key, val)
	self.map[key] = {v = val, t = tick()}
end
function Cache:clear(key)
	if key then self.map[key] = nil else self.map = {} end
end

-- Sounds
local Sfx = {}
Sfx.__index = Sfx
function Sfx.new()
	local self = setmetatable({sounds = {}, enabled = true}, Sfx)
	for n, id in pairs(Assets.sfx) do
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = 0.1
		s.Parent = SoundService
		self.sounds[n] = s
		-- prime
		s:Play(); s:Stop()
	end
	return self
end
function Sfx:play(name, vol)
	if not self.enabled then return end
	local s = self.sounds[name]
	if s then s.Volume = vol or 0.1; s:Play() end
end

-- Tiny UI helper factory
local function make(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		pcall(function() inst[k] = v end)
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	return inst
end

local function corner(radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	return c
end

local function stroke(color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.colors.outline
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

local function padding(all)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, all)
	p.PaddingBottom = UDim.new(0, all)
	p.PaddingLeft = UDim.new(0, all)
	p.PaddingRight = UDim.new(0, all)
	return p
end

local function shimmer(parent)
	-- simple skeleton shimmer bar filling parent background
	local g = Instance.new("Frame")
	g.BackgroundColor3 = Theme.colors.outline2
	g.BackgroundTransparency = 0.3
	g.BorderSizePixel = 0
	g.Parent = parent
	g.Size = UDim2.fromScale(1, 1)
	g.Name = "_Shimmer"
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(240,240,246)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,255,255)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(240,240,246)),
	})
	grad.Rotation = 0
	grad.Offset = Vector2.new(-1, 0)
	grad.Parent = g
	-- animate
	task.spawn(function()
		while g.Parent do
			TweenService:Create(grad, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Offset = Vector2.new(1, 0)}):Play()
			task.wait(1.2)
			grad.Offset = Vector2.new(-1, 0)
		end
	end)
	return g
end

local function spinner(parent)
	local img = make("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Assets.icons.spinner,
		ImageColor3 = Theme.colors.muted,
		Size = UDim2.fromOffset(20, 20),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 10,
	})
	img.Parent = parent
	-- rotate forever
	task.spawn(function()
		local angle = 0
		while img.Parent do
			angle += 360
			TweenService:Create(img, TweenInfo.new(0.8, Enum.EasingStyle.Linear), {Rotation = angle}):Play()
			task.wait(0.8)
		end
	end)
	return img
end

-- Shop Manager
local Shop = {}
Shop.__index = Shop

function Shop.new()
	local self = setmetatable({}, Shop)
	self.isOpen = false
	self.animating = false
	self.tab = "cash"

	self.sfx = Sfx.new()
	self.priceCache = Cache.new(DURATIONS.PRICE)
	self.ownCache = Cache.new(DURATIONS.OWNERSHIP)
	self.inFlight = {} -- [id] = true while prompting

	self.gui = nil
	self.blur = nil
	self.header = nil
	self.nav = {}
	self.pages = {}
	self.selection = nil
	self.autoCollectToggle = nil

	self.settings = {
		autoRefresh = true,
		animations = true,
		selectedIndex = 1,
	}

	self:_build()
	self:_setupInputs()
	self:_preload()
	self:_refreshPrices()
	return self
end

function Shop:_preload()
	local list = {}
	for _, id in pairs(Assets.icons) do table.insert(list, id) end
	for _, id in pairs(Assets.sfx) do table.insert(list, id) end
	pcall(function() ContentProvider:PreloadAsync(list) end)
end

function Shop:_build()
	if PlayerGui:FindFirstChild("TycoonShopUI") then PlayerGui.TycoonShopUI:Destroy() end

	self.gui = make("ScreenGui", {
		Name = "TycoonShopUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 100,
		Enabled = false,
	})
	self.gui.Parent = PlayerGui

	-- Selection image for gamepad
	local sel = make("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = Theme.colors.secondaryDark,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100,100,100,100),
		ImageTransparency = 0.15,
	})
	self.gui.SelectionImageObject = sel
	self.selection = sel

	-- Blur
	self.blur = Instance.new("BlurEffect")
	self.blur.Name = "ShopBlur"
	self.blur.Size = 0
	self.blur.Parent = Lighting

	local insets = getSafeInsets()

	-- Overlay that also closes when clicked
	local overlay = make("TextButton", {
		Name = "Overlay",
		BackgroundColor3 = Color3.new(0,0,0),
		BackgroundTransparency = 0.35,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1,1),
		ZIndex = 0,
	})
	overlay.Parent = self.gui
	overlay.MouseButton1Click:Connect(function()
		if self.isOpen and not self.animating then self:close() end
	end)

	-- Safe area wrapper
	local wrapper = make("Frame", {
		Name = "Wrapper",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -insets.left-insets.right, 1, -(insets.top+insets.bottom)),
		Position = UDim2.new(0, insets.left, 0, insets.top),
	})
	wrapper.Parent = self.gui

	-- Main container
	local container = make("Frame", {
		Name = "Container",
		BackgroundColor3 = Theme.colors.surface,
		Size = UDim2.fromScale(0.95, 0.9),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Selectable = true,
		SelectionGroup = true,
		ZIndex = 2,
	})
	container.Parent = wrapper
	corner(Theme.radius.lg).Parent = container
	stroke(Theme.colors.outline, 1, 0.6).Parent = container

	-- Header
	local header = make("Frame", {
		Name = "Header",
		BackgroundColor3 = Theme.colors.surface2,
		Size = UDim2.new(1, 0, 0, 72),
		ZIndex = 3,
	})
	header.Parent = container
	corner(Theme.radius.lg).Parent = header
	padding(16).Parent = header

	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, 12)
	headerLayout.Parent = header

	local icon = make("ImageLabel", {
		Image = Assets.icons.shop,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(36,36),
		ImageColor3 = Theme.colors.primary,
		LayoutOrder = 1,
	})
	icon.Parent = header

	local title = make("TextLabel", {
		Text = "Tycoon Shop",
		BackgroundTransparency = 1,
		Font = Theme.font.bold,
		TextSize = Theme.typo.head,
		TextColor3 = Theme.colors.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -120, 1, 0),
		LayoutOrder = 2,
	})
	title.Parent = header

	local closeBtn = make("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.error,
		Size = UDim2.fromOffset(40,40),
		LayoutOrder = 3,
		Selectable = true,
	})
	closeBtn.Parent = header
	corner(Theme.radius.full).Parent = closeBtn

	local closeIcon = make("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Assets.icons.close,
		ImageColor3 = Theme.colors.onPrimary,
		Size = UDim2.fromScale(0.6, 0.6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})
	closeIcon.Parent = closeBtn

	closeBtn.MouseEnter:Connect(function()
		self.sfx:play("hover", 0.05)
		TweenService:Create(closeBtn, TweenInfo.new(SPEED.FAST, Enum.EasingStyle.Back), {Size = UDim2.fromOffset(46,46), BackgroundColor3 = Color3.fromRGB(235, 102, 122)}):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(SPEED.FAST), {Size = UDim2.fromOffset(40,40), BackgroundColor3 = Theme.colors.error}):Play()
	end)
	closeBtn.MouseButton1Click:Connect(function() self:close() end)

	-- Navigation (left or top depending on screen)
	self:_buildNavigation(container)
	self:_buildPages(container)

	self.header = header
	self.container = container

	-- Floating toggle button
	self:_buildToggle()

	-- initial tab
	self:_switchTab("cash")
end

function Shop:_buildNavigation(container)
	local isMobile = smallScreen()
	local navSize = isMobile and UDim2.new(1, -32, 0, 64) or UDim2.new(0, 240, 1, -72-16)
	local navPos = isMobile and UDim2.new(0,16,0,72+8) or UDim2.new(0,16,0,72+8)

	local nav = make("Frame", {
		Name = "Navigation",
		BackgroundColor3 = Theme.colors.surface2,
		Size = navSize,
		Position = navPos,
		ZIndex = 2,
	})
	nav.Parent = container
	corner(Theme.radius.md).Parent = nav
	padding(12).Parent = nav

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = isMobile and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	layout.HorizontalAlignment = isMobile and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = nav

	local items = {
		{id = "cash", name = "Cash Packs", icon = Assets.icons.cash, color = Theme.colors.primary},
		{id = "passes", name = "Game Passes", icon = Assets.icons.gamepass, color = Theme.colors.secondary},
	}

	self.nav.buttons = {}
	for _, it in ipairs(items) do
		local btn = make("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.colors.surface,
			Size = isMobile and UDim2.new(0.5, -4, 1, 0) or UDim2.new(1, 0, 0, 56),
			Selectable = true,
		})
		btn.Parent = nav
		corner(Theme.radius.md).Parent = btn

		local bLayout = Instance.new("UIListLayout")
		bLayout.FillDirection = Enum.FillDirection.Horizontal
		bLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		bLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		bLayout.Padding = UDim.new(0, 8)
		bLayout.Parent = btn

		local ic = make("ImageLabel", {Image = it.icon, BackgroundTransparency = 1, Size = UDim2.fromOffset(24,24), ImageColor3 = Theme.colors.muted})
		ic.Parent = btn
		local lb = make("TextLabel", {Text = it.name, BackgroundTransparency = 1, Font = Theme.font.medium, TextSize = Theme.typo.label, TextColor3 = Theme.colors.muted, Size = UDim2.new(0, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center})
		lb.Parent = btn
		lb.Size = UDim2.new(0, lb.TextBounds.X, 1, 0)

		btn.MouseEnter:Connect(function()
			if self.tab ~= it.id then
				self.sfx:play("hover", 0.05)
				TweenService:Create(btn, TweenInfo.new(SPEED.FAST), {BackgroundColor3 = Color3.fromRGB(244,244,247)}):Play()
				TweenService:Create(ic, TweenInfo.new(SPEED.FAST), {ImageColor3 = it.color}):Play()
				TweenService:Create(lb, TweenInfo.new(SPEED.FAST), {TextColor3 = it.color}):Play()
			end
		end)
		btn.MouseLeave:Connect(function()
			if self.tab ~= it.id then
				TweenService:Create(btn, TweenInfo.new(SPEED.FAST), {BackgroundColor3 = Theme.colors.surface}):Play()
				TweenService:Create(ic, TweenInfo.new(SPEED.FAST), {ImageColor3 = Theme.colors.muted}):Play()
				TweenService:Create(lb, TweenInfo.new(SPEED.FAST), {TextColor3 = Theme.colors.muted}):Play()
			end
		end)
		btn.MouseButton1Click:Connect(function() self:_switchTab(it.id) end)

		self.nav.buttons[it.id] = {button = btn, icon = ic, label = lb, color = it.color}
	end

	self.nav.frame = nav
end

function Shop:_buildPages(container)
	local isMobile = smallScreen()
	local contentSize = isMobile and UDim2.new(1, -32, 1, -72-64-32) or UDim2.new(1, -240-48, 1, -72-16)
	local contentPos = isMobile and UDim2.new(0,16,0,72+64+16) or UDim2.new(0,240+32,0,72+8)

	local area = make("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = contentSize,
		Position = contentPos,
		ZIndex = 2,
	})
	area.Parent = container

	-- pages
	self.pages.cash = self:_buildCashPage(area)
	self.pages.passes = self:_buildPassPage(area)

	for _, p in pairs(self.pages) do p.Visible = false end
	self.contentArea = area
end

function Shop:_buildCashPage(parent)
	local page = make("Frame", {Name = "CashPage", BackgroundTransparency = 1, Size = UDim2.fromScale(1,1)})
	page.Parent = parent

	local header = make("Frame", {BackgroundColor3 = Theme.colors.primaryContainer, Size = UDim2.new(1,0,0,60)})
	header.Parent = page
	corner(Theme.radius.md).Parent = header
	padding(16).Parent = header

	local hLayout = Instance.new("UIListLayout")
	hLayout.FillDirection = Enum.FillDirection.Horizontal
	hLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	hLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	hLayout.Padding = UDim.new(0,12)
	hLayout.Parent = header

	local icon = make("ImageLabel", {Image = Assets.icons.cash, BackgroundTransparency = 1, Size = UDim2.fromOffset(28,28), ImageColor3 = Theme.colors.primary})
	icon.Parent = header

	local title = make("TextLabel", {Text = "Cash Packs", BackgroundTransparency = 1, Font = Theme.font.bold, TextSize = Theme.typo.head, TextColor3 = Theme.colors.text, Size = UDim2.new(0.5,-40,1,0), TextXAlignment = Enum.TextXAlignment.Left})
	title.Parent = header

	local balance = make("TextLabel", {Name = "Balance", Text = "Balance: $0", BackgroundTransparency = 1, Font = Theme.font.medium, TextSize = Theme.typo.body, TextColor3 = Theme.colors.muted, Size = UDim2.new(0.5,0,1,0), TextXAlignment = Enum.TextXAlignment.Right})
	balance.Parent = header

	local scroll = make("ScrollingFrame", {BackgroundTransparency = 1, Size = UDim2.new(1,0,1,-70), Position = UDim2.new(0,0,0,70), ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y})
	scroll.Parent = page
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(12,12)
	grid.CellSize = UDim2.new(1/3, -8, 0, 240)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.FillDirectionMaxCells = gridColumns()
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	page._grid = grid

	for i, pack in ipairs(ProductData.cash) do
		self:_cashCard(scroll, grid, pack, i)
	end

	return page
end

function Shop:_cashCard(scroll, grid, pack, order)
	local card = make("Frame", {BackgroundColor3 = Theme.colors.surface, LayoutOrder = order})
	card.Parent = scroll
	corner(Theme.radius.md).Parent = card
	stroke(Theme.colors.primary, 2, 0.8).Parent = card
	padding(16).Parent = card

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.Padding = UDim.new(0, 8)
	list.Parent = card

	local iconWrap = make("Frame", {BackgroundColor3 = Theme.colors.primaryContainer, Size = UDim2.new(1,0,0,64)})
	iconWrap.Parent = card
	corner(Theme.radius.md).Parent = iconWrap

	local ic = make("ImageLabel", {Image = Assets.icons.cash, BackgroundTransparency = 1, Size = UDim2.fromOffset(48,48), AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5), ImageColor3 = Theme.colors.primary})
	ic.Parent = iconWrap

	local name = make("TextLabel", {Text = pack.name, BackgroundTransparency = 1, Font = Theme.font.bold, TextSize = Theme.typo.body, TextColor3 = Theme.colors.text, Size = UDim2.new(1,0,0,24)})
	name.Parent = card

	local desc = make("TextLabel", {Text = pack.description, BackgroundTransparency = 1, Font = Theme.font.regular, TextSize = Theme.typo.bodySm, TextColor3 = Theme.colors.muted, Size = UDim2.new(1,0,0,32)})
	desc.Parent = card

	local amt = make("TextLabel", {Text = string.format("%s Cash", formatCommas(pack.amount)), BackgroundTransparency = 1, Font = Theme.font.medium, TextSize = Theme.typo.body, TextColor3 = Theme.colors.primaryDark, Size = UDim2.new(1,0,0,20)})
	amt.Parent = card

	local price = make("TextLabel", {Name = "Price", Text = "R$???", BackgroundTransparency = 1, Font = Theme.font.bold, TextSize = Theme.typo.headSm, TextColor3 = Theme.colors.text, Size = UDim2.new(1,0,0,24)})
	price.Parent = card
	shimmer(price) -- until loaded

	local btn = make("TextButton", {Text = "Purchase", AutoButtonColor = false, BackgroundColor3 = Theme.colors.primary, TextColor3 = Theme.colors.onPrimary, Font = Theme.font.bold, TextSize = Theme.typo.label, Size = UDim2.new(1,0,0,40), Selectable = true})
	btn.Parent = card
	corner(Theme.radius.md).Parent = btn

	btn.MouseEnter:Connect(function()
		TweenService:Create(ic, TweenInfo.new(SPEED.FAST, Enum.EasingStyle.Back), {Size = UDim2.fromOffset(52,52)}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(ic, TweenInfo.new(SPEED.FAST), {Size = UDim2.fromOffset(48,48)}):Play()
	end)

	btn.MouseButton1Down:Connect(function()
		TweenService:Create(btn, TweenInfo.new(SPEED.FAST), {Size = UDim2.new(1,0,0,38)}):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(btn, TweenInfo.new(SPEED.FAST, Enum.EasingStyle.Back), {Size = UDim2.new(1,0,0,40)}):Play()
	end)

	btn.MouseButton1Click:Connect(function()
		self:_purchaseProduct(pack, btn)
	end)

	pack._price = price
	pack._button = btn
end

function Shop:_buildPassPage(parent)
	local page = make("Frame", {Name = "PassPage", BackgroundTransparency = 1, Size = UDim2.fromScale(1,1)})
	page.Parent = parent

	local header = make("Frame", {BackgroundColor3 = Theme.colors.secondaryContainer, Size = UDim2.new(1,0,0,60)})
	header.Parent = page
	corner(Theme.radius.md).Parent = header
	padding(16).Parent = header

	local hLayout = Instance.new("UIListLayout")
	hLayout.FillDirection = Enum.FillDirection.Horizontal
	hLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	hLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	hLayout.Padding = UDim.new(0,12)
	hLayout.Parent = header

	local icon = make("ImageLabel", {Image = Assets.icons.gamepass, BackgroundTransparency = 1, Size = UDim2.fromOffset(28,28), ImageColor3 = Theme.colors.secondary})
	icon.Parent = header

	local title = make("TextLabel", {Text = "Game Passes", BackgroundTransparency = 1, Font = Theme.font.bold, TextSize = Theme.typo.head, TextColor3 = Theme.colors.text, Size = UDim2.new(1,-40,1,0), TextXAlignment = Enum.TextXAlignment.Left})
	title.Parent = header

	local content = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1,0,1,-70), Position = UDim2.new(0,0,0,70)})
	content.Parent = page

	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(16,16)
	grid.CellSize = UDim2.new(0.5, -8, 0, 260)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = content

	for i, pass in ipairs(ProductData.passes) do
		self:_passCard(content, pass, i)
	end

	-- Quick settings row
	local settings = make("Frame", {BackgroundColor3 = Theme.colors.surface2, Size = UDim2.new(1,0,0,70), Position = UDim2.new(0,0,1,-70)})
	settings.Parent = page
	corner(Theme.radius.md).Parent = settings
	padding(16).Parent = settings

	local sLayout = Instance.new("UIListLayout")
	sLayout.FillDirection = Enum.FillDirection.Horizontal
	sLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	sLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	sLayout.Padding = UDim.new(0, 12)
	sLayout.Parent = settings

	local sIcon = make("ImageLabel", {Image = Assets.icons.settings, BackgroundTransparency = 1, Size = UDim2.fromOffset(24,24), ImageColor3 = Theme.colors.muted})
	sIcon.Parent = settings
	local sTitle = make("TextLabel", {Text = "Quick Settings", BackgroundTransparency = 1, Font = Theme.font.medium, TextSize = Theme.typo.body, TextColor3 = Theme.colors.text, Size = UDim2.new(0.5,-30,1,0), TextXAlignment = Enum.TextXAlignment.Left})
	sTitle.Parent = settings

	self.autoCollectToggle = self:_toggle(settings, "Auto Collect", function(state)
		self:_setAutoCollect(state)
	end)
	self.autoCollectToggle.Visible = false

	return page
end

function Shop:_toggle(parent, labelText, onChange)
	local wrap = make("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(180,36)})
	wrap.Parent = parent
	local label = make("TextLabel", {Text = labelText, BackgroundTransparency = 1, Font = Theme.font.medium, TextSize = Theme.typo.bodySm, TextColor3 = Theme.colors.muted, Size = UDim2.fromOffset(100,36), TextXAlignment = Enum.TextXAlignment.Left})
	label.Parent = wrap

	local bg = make("Frame", {BackgroundColor3 = Theme.colors.outline, Size = UDim2.fromOffset(56,28), Position = UDim2.fromOffset(110,4)})
	bg.Parent = wrap
	corner(Theme.radius.full).Parent = bg

	local knob = make("Frame", {BackgroundColor3 = Theme.colors.surface, Size = UDim2.fromOffset(24,24), Position = UDim2.fromOffset(2,2)})
	knob.Parent = bg
	corner(Theme.radius.full).Parent = knob

	local btn = make("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1,1), AutoButtonColor = false})
	btn.Parent = wrap

	local state = false
	local function update()
		if state then
			TweenService:Create(bg, TweenInfo.new(SPEED.FAST), {BackgroundColor3 = Theme.colors.primary}):Play()
			TweenService:Create(knob, TweenInfo.new(SPEED.FAST, Enum.EasingStyle.Back), {Position = UDim2.fromOffset(30,2)}):Play()
		else
			TweenService:Create(bg, TweenInfo.new(SPEED.FAST), {BackgroundColor3 = Theme.colors.outline}):Play()
			TweenService:Create(knob, TweenInfo.new(SPEED.FAST, Enum.EasingStyle.Back), {Position = UDim2.fromOffset(2,2)}):Play()
		end
	end
	btn.MouseButton1Click:Connect(function()
		state = not state
		update()
		self.sfx:play("click", 0.08)
		if onChange then onChange(state) end
	end)

	wrap.SetState = function(_, v)
		state = v and true or false
		update()
	end
	wrap.GetState = function() return state end
	return wrap
end

function Shop:_passCard(parent, pass, order)
	local card = make("Frame", {BackgroundColor3 = Theme.colors.surface, LayoutOrder = order})
	card.Parent = parent
	corner(Theme.radius.md).Parent = card
	stroke(Theme.colors.secondary, 2, 0.8).Parent = card
	padding(20).Parent = card

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.Padding = UDim.new(0, 10)
	list.Parent = card

	local iconWrap = make("Frame", {BackgroundColor3 = Theme.colors.secondaryContainer, Size = UDim2.new(1,0,0,80)})
	iconWrap.Parent = card
	corner(Theme.radius.md).Parent = iconWrap

	local ic = make("ImageLabel", {Image = Assets.icons.gamepass, BackgroundTransparency = 1, Size = UDim2.fromOffset(56,56), AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5), ImageColor3 = Theme.colors.secondary})
	ic.Parent = iconWrap

	local name = make("TextLabel", {Text = pass.name, BackgroundTransparency = 1, Font = Theme.font.bold, TextSize = Theme.typo.headSm, TextColor3 = Theme.colors.text, Size = UDim2.new(1,0,0,28)})
	name.Parent = card

	local desc = make("TextLabel", {Text = pass.description, BackgroundTransparency = 1, Font = Theme.font.regular, TextSize = Theme.typo.body, TextColor3 = Theme.colors.muted, Size = UDim2.new(1,0,0,40)})
	desc.Parent = card

	local price = make("TextLabel", {Name = "Price", Text = "R$???", BackgroundTransparency = 1, Font = Theme.font.bold, TextSize = Theme.typo.head, TextColor3 = Theme.colors.secondary, Size = UDim2.new(1,0,0,28)})
	price.Parent = card
	shimmer(price)

	local btn = make("TextButton", {Text = "Purchase", AutoButtonColor = false, BackgroundColor3 = Theme.colors.secondary, TextColor3 = Theme.colors.onSecondary, Font = Theme.font.bold, TextSize = Theme.typo.label, Size = UDim2.new(1,0,0,44), Selectable = true})
	btn.Parent = card
	corner(Theme.radius.md).Parent = btn

	-- Owned pill (initially hidden)
	local owned = make("TextLabel", {Text = "✓ Owned", BackgroundColor3 = Theme.colors.success, TextColor3 = Theme.colors.onPrimary, Font = Theme.font.medium, TextSize = Theme.typo.label, AnchorPoint = Vector2.new(1,0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(110,26)})
	owned.Parent = card
	corner(Theme.radius.full).Parent = owned
	owned.Visible = false

	btn.MouseEnter:Connect(function()
		TweenService:Create(ic, TweenInfo.new(SPEED.FAST, Enum.EasingStyle.Back), {Size = UDim2.fromOffset(60,60)}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(ic, TweenInfo.new(SPEED.FAST), {Size = UDim2.fromOffset(56,56)}):Play()
	end)
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(btn, TweenInfo.new(SPEED.FAST), {Size = UDim2.new(1,0,0,42)}):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(btn, TweenInfo.new(SPEED.FAST, Enum.EasingStyle.Back), {Size = UDim2.new(1,0,0,44)}):Play()
	end)
	btn.MouseButton1Click:Connect(function() self:_purchasePass(pass, btn) end)

	pass._price = price
	pass._button = btn
	pass._ownedPill = owned
	pass._icon = ic

	-- Ownership check
	if self:_owns(pass.id) then self:_markOwned(pass) end

	-- Toggle (auto-collect)
	if pass.hasToggle then
		local toggleWrap = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1,0,0,40)})
		toggleWrap.Parent = card
		local toggle = self:_toggle(toggleWrap, "Enable", function(state) self:_setAutoCollect(state) end)
		pass._toggle = toggle
		toggle.Visible = false
	end
end

function Shop:_buildToggle()
	if PlayerGui:FindFirstChild("TycoonShopToggle") then PlayerGui.TycoonShopToggle:Destroy() end
	local sg = Instance.new("ScreenGui")
	sg.Name = "TycoonShopToggle"
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 50
	sg.Parent = PlayerGui

	local btn = make("ImageButton", {Image = Assets.icons.shop, Size = UDim2.fromOffset(64,64), Position = UDim2.new(1, -80, 1, -80), AnchorPoint = Vector2.new(0.5,0.5), BackgroundColor3 = Theme.colors.surface, ImageColor3 = Theme.colors.primary, AutoButtonColor = false, Selectable = true})
	btn.Parent = sg
	corner(Theme.radius.full).Parent = btn
	stroke(Theme.colors.primary, 2, 0.7).Parent = btn

	btn.MouseEnter:Connect(function()
		self.sfx:play("hover", 0.05)
		TweenService:Create(btn, TweenInfo.new(SPEED.FAST, Enum.EasingStyle.Back), {Size = UDim2.fromOffset(72,72), BackgroundColor3 = Theme.colors.primary}):Play()
		TweenService:Create(btn, TweenInfo.new(SPEED.FAST), {ImageColor3 = Theme.colors.onPrimary}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(SPEED.FAST), {Size = UDim2.fromOffset(64,64), BackgroundColor3 = Theme.colors.surface}):Play()
		TweenService:Create(btn, TweenInfo.new(SPEED.FAST), {ImageColor3 = Theme.colors.primary}):Play()
	end)

	btn.MouseButton1Click:Connect(function() self:toggle() end)

	-- idle float
	task.spawn(function()
		while btn.Parent do
			TweenService:Create(btn, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Position = UDim2.new(1,-80,1,-85)}):Play(); task.wait(3)
			TweenService:Create(btn, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Position = UDim2.new(1,-80,1,-75)}):Play(); task.wait(3)
		end
	end)

	self.toggleBtn = btn
end

-- Input & responsiveness
function Shop:_setupInputs()
	-- keyboard
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.M then self:toggle() end
		if input.KeyCode == Enum.KeyCode.Escape and self.isOpen then self:close() end
	end)
	-- controller: X to toggle, B to close
	ContextActionService:BindAction("ShopToggle", function(_, state)
		if state == Enum.UserInputState.Begin then self:toggle() end
	end, false, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction("ShopClose", function(_, state)
		if state == Enum.UserInputState.Begin and self.isOpen then self:close() end
	end, false, Enum.KeyCode.ButtonB)

	-- responsiveness
	local function relayout()
		if not self.container then return end
		local isMobile = smallScreen()

		if self.nav and self.nav.frame then
			self.nav.frame.Size = isMobile and UDim2.new(1, -32, 0, 64) or UDim2.new(0, 240, 1, -72-16)
			self.nav.frame.Position = isMobile and UDim2.new(0,16,0,72+8) or UDim2.new(0,16,0,72+8)
			local l = self.nav.frame:FindFirstChildOfClass("UIListLayout")
			if l then
				l.FillDirection = isMobile and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
				l.HorizontalAlignment = isMobile and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left
			end
			for _, item in pairs(self.nav.buttons) do
				local btn = item.button
				btn.Size = isMobile and UDim2.new(0.5, -4, 1, 0) or UDim2.new(1, 0, 0, 56)
			end
		end

		if self.contentArea then
			self.contentArea.Size = isMobile and UDim2.new(1, -32, 1, -72-64-32) or UDim2.new(1, -240-48, 1, -72-16)
			self.contentArea.Position = isMobile and UDim2.new(0,16,0,72+64+16) or UDim2.new(0,240+32,0,72+8)
		end

		if self.pages.cash and self.pages.cash._grid then
			local cols = gridColumns()
			self.pages.cash._grid.FillDirectionMaxCells = cols
			self.pages.cash._grid.CellSize = UDim2.new(1/cols, -8, 0, cols == 1 and 280 or 240)
		end
	end

	relayout()
	local cam = workspace.CurrentCamera
	if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(relayout) end
end

-- Tab switching visual state
function Shop:_switchTab(id)
	if self.tab == id then return end
	self.tab = id
	self.sfx:play("click", 0.08)

	for key, item in pairs(self.nav.buttons) do
		local active = key == id
		TweenService:Create(item.button, TweenInfo.new(SPEED.FAST), {BackgroundColor3 = active and item.color or Theme.colors.surface}):Play()
		TweenService:Create(item.icon, TweenInfo.new(SPEED.FAST), {ImageColor3 = active and Theme.colors.onPrimary or Theme.colors.muted}):Play()
		TweenService:Create(item.label, TweenInfo.new(SPEED.FAST), {TextColor3 = active and Theme.colors.onPrimary or Theme.colors.muted}):Play()
	end

	for key, page in pairs(self.pages) do page.Visible = (key == id) end
end

-- Open/Close
function Shop:open()
	if self.isOpen or self.animating then return end
	self.animating = true
	self.isOpen = true
	self.gui.Enabled = true
	self.sfx:play("open", 0.15)
	TweenService:Create(self.blur, TweenInfo.new(SPEED.MED), {Size = 24}):Play()
	self.container.Position = UDim2.fromScale(0.5, 0.55)
	self.container.Size = UDim2.fromScale(0.9, 0.85)
	TweenService:Create(self.container, TweenInfo.new(SPEED.SLOW, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.fromScale(0.5,0.5), Size = UDim2.fromScale(0.95,0.9)}):Play()

	-- refresh when opening
	self:_refreshPrices()
	self:_refreshOwnership()

	task.delay(SPEED.SLOW, function() self.animating = false end)

	if self.settings.autoRefresh then
		if self._refreshThread then task.cancel(self._refreshThread) end
		self._refreshThread = task.spawn(function()
			while self.isOpen do
				task.wait(DURATIONS.REFRESH)
				if self.isOpen then self:_refreshPrices(); self:_refreshOwnership() end
			end
		end)
	end
end

function Shop:close()
	if not self.isOpen or self.animating then return end
	self.animating = true
	self.isOpen = false
	self.sfx:play("close", 0.15)
	TweenService:Create(self.blur, TweenInfo.new(SPEED.FAST), {Size = 0}):Play()
	TweenService:Create(self.container, TweenInfo.new(SPEED.FAST, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.fromScale(0.5,0.55), Size = UDim2.fromScale(0.9,0.85)}):Play()
	task.delay(SPEED.FAST, function()
		self.gui.Enabled = false
		self.animating = false
		if self._refreshThread then task.cancel(self._refreshThread); self._refreshThread = nil end
	end)
end

function Shop:toggle()
	if self.isOpen then self:close() else self:open() end
end

-- Prices / Ownership
function Shop:_refreshPrices()
	for _, pack in ipairs(ProductData.cash) do
		local key = "p_"..pack.id
		local cached = self.priceCache:get(key)
		if not cached then
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(pack.id, Enum.InfoType.Product)
			end)
			if ok and info then
				cached = info.PriceInRobux
				self.priceCache:set(key, cached)
			end
		end
		if pack._price then
			pack._price.Text = "R$" .. (cached or "???")
			local s = pack._price:FindFirstChild("_Shimmer")
			if s then s:Destroy() end
		end
	end
	for _, pass in ipairs(ProductData.passes) do
		local key = "gp_"..pass.id
		local cached = self.priceCache:get(key)
		if not cached then
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(pass.id, Enum.InfoType.GamePass)
			end)
			if ok and info then
				cached = info.PriceInRobux
				self.priceCache:set(key, cached)
			end
		end
		if pass._price then
			pass._price.Text = "R$" .. (cached or "???")
			local s = pass._price:FindFirstChild("_Shimmer")
			if s then s:Destroy() end
		end
	end
end

function Shop:_owns(passId)
	local key = Player.UserId .. ":" .. passId
	local c = self.ownCache:get(key)
	if c ~= nil then return c end
	local ok, has = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, passId)
	end)
	if ok then self.ownCache:set(key, has); return has end
	return false
end

function Shop:_refreshOwnership()
	local hasAuto = false
	for _, pass in ipairs(ProductData.passes) do
		if self:_owns(pass.id) then
			self:_markOwned(pass)
			if pass.id == 1412171840 then hasAuto = true end
		end
	end

	if self.autoCollectToggle then
		self.autoCollectToggle.Visible = hasAuto
		if hasAuto and Remotes then
			local fn = Remotes:FindFirstChild("GetAutoCollectState")
			if fn and fn:IsA("RemoteFunction") then
				local ok, state = pcall(function() return fn:InvokeServer() end)
				if ok and typeof(state) == "boolean" then
					self.autoCollectToggle:SetState(state)
					Player:SetAttribute("AutoCollectEnabled", state)
				end
			end
		end
	end
end

function Shop:_markOwned(pass)
	if pass._button then
		pass._button.Text = "✓ Owned"
		pass._button.Active = false
		pass._button.AutoButtonColor = false
		pass._button.BackgroundColor3 = Theme.colors.success
	end
	if pass._ownedPill then pass._ownedPill.Visible = true end
	local st = pass._button and pass._button.Parent and pass._button.Parent:FindFirstChildOfClass("UIStroke")
	if st then st.Color = Theme.colors.success; st.Transparency = 0.6 end
	if pass._toggle then
		pass._toggle.Visible = true
		if Remotes then
			local fn = Remotes:FindFirstChild("GetAutoCollectState")
			if fn and fn:IsA("RemoteFunction") then
				local ok, state = pcall(function() return fn:InvokeServer() end)
				if ok and typeof(state) == "boolean" then pass._toggle:SetState(state) end
			end
		end
	end
end

-- Purchase flow with concurrency guard and spinner
local function setBusy(button, busy)
	if not button then return end
	if busy then
		button.Active = false
		button.AutoButtonColor = false
		if not button:FindFirstChild("_Spinner") then
			local sp = spinner(button)
			sp.Name = "_Spinner"
		end
	else
		button.Active = true
		local sp = button:FindFirstChild("_Spinner")
		if sp then sp:Destroy() end
	end
end

function Shop:_purchaseProduct(pack, button)
	if self.inFlight[pack.id] then return end
	self.sfx:play("click", 0.1)
	self.inFlight[pack.id] = true
	setBusy(button, true)

	local completed = false
	local function finish()
		if completed then return end
		completed = true
		self.inFlight[pack.id] = nil
		setBusy(button, false)
	end

	local ok = pcall(function()
		MarketplaceService:PromptProductPurchase(Player, pack.id)
	end)
	if not ok then self.sfx:play("error", 0.15); finish(); return end

	task.delay(DURATIONS.PURCHASE_TIMEOUT, finish)
end

function Shop:_purchasePass(pass, button)
	if self:_owns(pass.id) or self.inFlight[pass.id] then return end
	self.sfx:play("click", 0.1)
	self.inFlight[pass.id] = true
	setBusy(button, true)

	local completed = false
	local function finish()
		if completed then return end
		completed = true
		self.inFlight[pass.id] = nil
		setBusy(button, false)
	end

	local ok = pcall(function()
		MarketplaceService:PromptGamePassPurchase(Player, pass.id)
	end)
	if not ok then self.sfx:play("error", 0.15); finish(); return end
	task.delay(DURATIONS.PURCHASE_TIMEOUT, finish)
end

-- Marketplace callbacks
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
	if player ~= Player then return end
	-- Find current shop instance if loaded
	local shop = rawget(_G, "__TycoonShopInstance__")
	if not shop then return end
	if bought then
		shop.ownCache:clear()
		shop:_refreshOwnership()
		shop.sfx:play("purchase", 0.2)
		if Remotes then
			local ev = Remotes:FindFirstChild("GamepassPurchased")
			if ev and ev:IsA("RemoteEvent") then ev:FireServer(passId) end
		end
	end
	shop.inFlight[passId] = nil
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, bought)
	if player ~= Player then return end
	local shop = rawget(_G, "__TycoonShopInstance__")
	if not shop then return end
	if bought and Remotes then
		local ev = Remotes:FindFirstChild("GrantProductCurrency")
		if ev and ev:IsA("RemoteEvent") then ev:FireServer(productId) end
		shop.sfx:play("purchase", 0.2)
	end
	shop.inFlight[productId] = nil
end)

-- Settings
function Shop:_setAutoCollect(state)
	if Remotes then
		local ev = Remotes:FindFirstChild("AutoCollectToggle")
		if ev and ev:IsA("RemoteEvent") then ev:FireServer(state) end
	end
	Player:SetAttribute("AutoCollectEnabled", state)
	if self.autoCollectToggle then self.autoCollectToggle:SetState(state) end
	for _, pass in ipairs(ProductData.passes) do
		if pass.id == 1412171840 and pass._toggle then pass._toggle:SetState(state) end
	end
end

function Shop:destroy()
	if self._refreshThread then task.cancel(self._refreshThread) end
	ContextActionService:UnbindAction("ShopToggle")
	ContextActionService:UnbindAction("ShopClose")
	if self.gui then self.gui:Destroy() end
	if self.blur then self.blur:Destroy() end
	if self.toggleBtn then self.toggleBtn:Destroy() end
end

-- Bootstrap
local shop = Shop.new()
_G.__TycoonShopInstance__ = shop

Players.PlayerRemoving:Connect(function(p)
	if p == Player then shop:destroy() end
end)

Player.CharacterAdded:Connect(function()
	task.wait(1)
	if not PlayerGui:FindFirstChild("TycoonShopToggle") then shop:_buildToggle() end
end)

print(string.format("[TycoonShop] v%s ready", SHOP_VERSION))

return {
	open = function() shop:open() end,
	close = function() shop:close() end,
	toggle = function() shop:toggle() end,
	refresh = function() shop:_refreshPrices(); shop:_refreshOwnership() end,
	destroy = function() shop:destroy() end,
	version = SHOP_VERSION,
}
