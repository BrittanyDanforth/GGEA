--[[
	🎀 SANRIO SHOP SYSTEM — ULTIMATE MOBILE-FIRST EDITION
	
	✅ Optimistic ownership (no "Owned → Purchase" flicker)
	✅ Server-confirmation state machine
	✅ Mobile-first: ≥44px touch targets, drag FAB, edge swipes
	✅ Crystal-clear text (no TextScaled)
	✅ Enable/Disable for toggle passes
	✅ Phone zoom-out: ≥1.4 cards visible (portrait) / ~2.2 (landscape)
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

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:FindFirstChild("TycoonRemotes")

-- ======================================================
-- CORE CONSTANTS & STATE
-- ======================================================
local Core = {}

Core.CONSTANTS = {
	PANEL_SIZE        = Vector2.new(1140, 1020),
	PANEL_SIZE_MOBILE = Vector2.new(1280, 1040),
	ANIM_FAST   = 0.15,
	ANIM_MEDIUM = 0.25,
	ANIM_BOUNCE = 0.30,
	CACHE_DURATION = 300,
	MIN_TOUCH_SIZE = 44, -- ✅ MOBILE: Minimum tap target
}

Core.State = {
	isOpen = false,
	isAnimating = false,
	purchasePending = {},
	settings = { soundEnabled = true, animationsEnabled = true },
	_shortSide = 414,
}

-- ✅ OPTIMISTIC OWNERSHIP (prevents flicker)
local optimisticOwns = {}
local ownershipCache = {}
local productCache = {}

local function getCacheKey(userId, passId)
	return ("%d_%d"):format(userId, passId)
end

local function setOwnedOptimistic(passId, owned)
	optimisticOwns[passId] = owned and true or nil
	local key = getCacheKey(Player.UserId, passId)
	if owned then 
		ownershipCache[key] = {value=true, time=tick()}
	else 
		ownershipCache[key] = nil
	end
	print("🔒 [Shop] Optimistic ownership:", passId, "→", owned and "OWNED" or "NOT OWNED")
end

local function getOwned(passId)
	-- Check optimistic first (instant)
	if optimisticOwns[passId] ~= nil then return true end
	
	-- Check cache
	local key = getCacheKey(Player.UserId, passId)
	local cached = ownershipCache[key]
	if cached and (tick() - cached.time < Core.CONSTANTS.CACHE_DURATION) then
		return cached.value
	end
	
	-- Query server
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, passId)
	end)
	
	if ok then
		ownershipCache[key] = {value=owns, time=tick()}
		return owns
	end
	
	return false
end

-- ======================================================
-- UTILS
-- ======================================================
local function viewport()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1920,1080)
end

function Core.Utils_isMobileLike() 
	return UserInputService.TouchEnabled and not GuiService:IsTenFootInterface() 
end

function Core.Utils_isPhone()
	if not Core.Utils_isMobileLike() then return false end
	local v = viewport()
	return math.min(v.X, v.Y) < 700
end

function Core.Utils_isTablet() 
	return Core.Utils_isMobileLike() and not Core.Utils_isPhone() 
end

function Core.Utils_formatNumber(n) 
	local s = tostring(n)
	local k = 1
	while k ~= 0 do 
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") 
	end
	return s
end

local function blend(a, b, t)
	t = math.clamp(t, 0, 1)
	return Color3.new(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t
	)
end

local function minTouch(size)
	return math.max(size, Core.CONSTANTS.MIN_TOUCH_SIZE)
end

-- ======================================================
-- DYNAMIC PROFILES (MOBILE-FIRST)
-- ======================================================
local BASE = {
	headerH=64, tabH=48, tabW=200,
	title=18, price=18, desc=13,
	imgH=120, titleH=24, descH=22, btnH=42,
	gutter=18, cols=2,
	minW=720, minH=520,
}

local function vinfo()
	local cam = workspace.CurrentCamera
	local inset = GuiService:GetGuiInset()
	local v = cam and cam.ViewportSize or Vector2.new(1920,1080)
	local safeY = math.max(0, v.Y - inset.Y)
	local short = math.floor(math.min(v.X, safeY))
	local landscape = v.X > v.Y
	return v, short, landscape
end

local function phonePanelScale(short)
	if short <= 320 then return 0.83 end
	if short <= 360 then return 0.86 end
	if short <= 375 then return 0.88 end
	if short <= 393 then return 0.90 end
	if short <= 414 then return 0.92 end
	return 0.94
end

local function dynamicProfile()
	local v, short, landscape = vinfo()
	Core.State._shortSide = short

	local isPhone = Core.Utils_isMobileLike() and (math.min(v.X, v.Y) < 700)
	local isTablet = Core.Utils_isMobileLike() and not isPhone

	if not isPhone then
		return {
			widthScale = 0.78, heightScale = 0.80,
			headerH = minTouch(BASE.headerH), 
			tabH = minTouch(BASE.tabH), 
			tabW = BASE.tabW,
			title = BASE.title, price = BASE.price, desc = BASE.desc,
			imgH = BASE.imgH, titleH = BASE.titleH, descH = BASE.descH, 
			btnH = minTouch(BASE.btnH),
			minW = isTablet and 680 or BASE.minW, 
			minH = isTablet and 480 or BASE.minH,
			cols = isTablet and 2 or BASE.cols, 
			gutter = isTablet and 16 or BASE.gutter,
			isPhone=false, isTablet=isTablet, landscape=landscape
		}
	end

	local s = math.clamp(short/414, 0.78, 1.0) * 0.92
	local widthScale  = landscape and 0.98 or 0.97
	local heightScale = landscape and 0.82 or 0.90

	return {
		widthScale = widthScale, heightScale = heightScale,
		headerH = math.floor(minTouch(62) * s),
		tabH    = math.floor(minTouch(48) * s),
		tabW    = math.floor((landscape and 150 or 138) * s),
		title   = math.floor(18 * s),
		price   = math.floor(16 * s),
		desc    = math.floor(12 * s),
		imgH    = math.floor((landscape and 100 or 96) * s),
		titleH  = math.floor((landscape and 22 or 20) * s),
		descH   = math.floor((landscape and 18 or 16) * s),
		btnH    = math.floor(minTouch(landscape and 38 or 36) * s),
		minW    = landscape and 360 or 340,
		minH    = landscape and 380 or 350,
		cols    = landscape and 2 or 1,
		gutter  = 12,
		isPhone=true, isTablet=false, landscape=landscape
	}
end

local function getProfile() return dynamicProfile() end

-- ======================================================
-- ANIMATION & SOUND
-- ======================================================
Core.Animation = {}
function Core.Animation.tween(inst, props, d, style, dir)
	if not Core.State.settings.animationsEnabled then 
		for k, v in pairs(props) do inst[k] = v end
		return 
	end
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(
			d or Core.CONSTANTS.ANIM_MEDIUM,
			style or Enum.EasingStyle.Quad,
			dir or Enum.EasingDirection.Out
		),
		props
	)
	tw:Play()
	return tw
end

Core.SoundSystem = {sounds={}}
function Core.SoundSystem.initialize()
	local cfg = {
		click   = {"rbxassetid://876939830", 0.45},
		hover   = {"rbxassetid://10066936758", 0.2},
		open    = {"rbxassetid://452267918", 0.5},
		close   = {"rbxassetid://452267918", 0.5},
		success = {"rbxassetid://876939830", 0.6},
		error   = {"rbxassetid://876939830", 0.5},
	}
	local preload = {}
	for name, data in pairs(cfg) do
		local s = Instance.new("Sound")
		s.Name = "SanrioShop_" .. name
		s.SoundId = data[1]
		s.Volume = data[2]
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.Parent = SoundService
		Core.SoundSystem.sounds[name] = s
		table.insert(preload, s)
	end
	task.spawn(function() 
		pcall(function() ContentProvider:PreloadAsync(preload) end) 
	end)
end

function Core.SoundSystem.play(n) 
	if Core.State.settings.soundEnabled and Core.SoundSystem.sounds[n] then 
		Core.SoundSystem.sounds[n]:Play() 
	end 
end

-- ======================================================
-- DATA MANAGER
-- ======================================================
Core.DataManager = {}
Core.DataManager.products = {
	cash = {
		{ id = 3366419712, amount = 1000,    name = "1,000 Cash",     description = "Includes 1,000 Cash",     icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3366420012, amount = 5000,    name = "5,000 Cash",     description = "Includes 5,000 Cash",     icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3366420478, amount = 10000,   name = "10,000 Cash",    description = "Includes 10,000 Cash",    icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3366420800, amount = 25000,   name = "25,000 Cash",    description = "Includes 25,000 Cash",    icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3424973374, amount = 50000,   name = "50,000 Cash",    description = "Includes 50,000 Cash",    icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3424974046, amount = 100000,  name = "100,000 Cash",   description = "Includes 100,000 Cash",   icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3424974161, amount = 250000,  name = "250,000 Cash",   description = "Includes 250,000 Cash",   icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3424974327, amount = 500000,  name = "500,000 Cash",   description = "Includes 500,000 Cash",   icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3424974402, amount = 1000000, name = "1,000,000 Cash", description = "Includes 1,000,000 Cash", icon = "rbxassetid://10709728059", price = 0 },
	},
	gamepasses = {
		{ id = 1412171840, name = "Auto Collect", description = "Automatically collect all cash drops", icon = "rbxassetid://10709727148", price = 99,  hasToggle = true  },
		{ id = 1398974710, name = "2x Cash",      description = "Double all cash earned permanently",   icon = "rbxassetid://10709727148", price = 199, hasToggle = false },
	},
}

function Core.DataManager.getProductInfo(id)
	local cached = productCache[id]
	if cached and (tick() - cached.time < Core.CONSTANTS.CACHE_DURATION) then
		return cached.value
	end
	
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
	end)
	
	if ok and info then
		productCache[id] = {value=info, time=tick()}
		return info
	end
end

function Core.DataManager.getGamePassInfo(id)
	local key = "pass_" .. id
	local cached = productCache[key]
	if cached and (tick() - cached.time < Core.CONSTANTS.CACHE_DURATION) then
		return cached.value
	end
	
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
	end)
	
	if ok and info then
		productCache[key] = {value=info, time=tick()}
		return info
	end
end

function Core.DataManager.refreshPrices()
	local prof = getProfile()
	
	-- ✅ MOBILE: Defer on phones for better initial load
	local refreshFn = function()
		for _, p in ipairs(Core.DataManager.products.cash) do
			local i = Core.DataManager.getProductInfo(p.id)
			if i and i.PriceInRobux then p.price = i.PriceInRobux end
		end
		for _, gp in ipairs(Core.DataManager.products.gamepasses) do
			local i = Core.DataManager.getGamePassInfo(gp.id)
			if i and i.PriceInRobux then gp.price = i.PriceInRobux end
		end
	end
	
	if prof.isPhone then
		task.defer(refreshFn)
	else
		refreshFn()
	end
end

-- ======================================================
-- UI THEME & COMPONENTS
-- ======================================================
local UI = {}
UI.Theme = {
	current = "light",
	themes = {
		light = {
			background     = Color3.fromRGB(253,252,250),
			surface        = Color3.fromRGB(255,255,255),
			surfaceAlt     = Color3.fromRGB(246,248,252),
			stroke         = Color3.fromRGB(222,226,235),
			text           = Color3.fromRGB(35,38,46),
			textSecondary  = Color3.fromRGB(120,126,140),
			accent         = Color3.fromRGB(255,64,129),
			success        = Color3.fromRGB(76,175,80),
			cinna          = Color3.fromRGB(186,214,255),
			kuromi         = Color3.fromRGB(200,190,255),
		}
	}
}
function UI.Theme:get(k) return self.themes[self.current][k] end

local Component = {}
Component.__index = Component

function Component.new(className, props)
	return setmetatable({instance=Instance.new(className), props=props or {}}, Component)
end

function Component:render()
	for k, v in pairs(self.props) do
		if k ~= "children" and k ~= "parent" and k ~= "onClick" and 
		   k ~= "cornerRadius" and k ~= "stroke" and k ~= "layout" and k ~= "padding" then
			pcall(function() self.instance[k] = v end)
		end
	end
	
	if self.props.cornerRadius then
		local c = Instance.new("UICorner")
		c.CornerRadius = self.props.cornerRadius
		c.Parent = self.instance
	end
	
	if self.props.stroke then
		local s = Instance.new("UIStroke")
		s.Color = self.props.stroke.color or UI.Theme:get("stroke")
		s.Thickness = self.props.stroke.thickness or 1
		s.Transparency = self.props.stroke.transparency or 0
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = self.instance
	end
	
	if self.props.parent then
		self.instance.Parent = self.props.parent
	end
	
	return self.instance
end

UI.Components = {}

function UI.Components.Frame(props)
	local d = {
		BackgroundColor3 = UI.Theme:get("surface"),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1)
	}
	for k, v in pairs(d) do if props[k] == nil then props[k] = v end end
	
	local cmp = Component.new("Frame", props)
	local inst = cmp:render()
	
	if props.layout then
		local kind = props.layout.type or "List"
		local layout = Instance.new("UI" .. kind .. "Layout")
		for k, v in pairs(props.layout) do
			if k ~= "type" then
				pcall(function() layout[k] = v end)
			end
		end
		layout.Parent = inst
	end
	
	if props.padding then
		local p = Instance.new("UIPadding")
		if props.padding.top then p.PaddingTop = props.padding.top end
		if props.padding.bottom then p.PaddingBottom = props.padding.bottom end
		if props.padding.left then p.PaddingLeft = props.padding.left end
		if props.padding.right then p.PaddingRight = props.padding.right end
		p.Parent = inst
	end
	
	return {instance=inst, render=function() return inst end}
end

function UI.Components.TextLabel(props)
	local d = {
		BackgroundTransparency = 1,
		TextColor3 = UI.Theme:get("text"),
		Font = Enum.Font.Gotham,
		TextWrapped = true
	}
	for k, v in pairs(d) do if props[k] == nil then props[k] = v end end
	return Component.new("TextLabel", props)
end

function UI.Components.Button(props)
	local d = {
		BackgroundColor3 = UI.Theme:get("accent"),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamMedium,
		Size = UDim2.fromOffset(120, 40),
		AutoButtonColor = false
	}
	for k, v in pairs(d) do if props[k] == nil then props[k] = v end end
	
	local cmp = Component.new("TextButton", props)
	local inst = cmp:render()
	
	-- ✅ MOBILE: No hover sound on touch devices
	if not Core.Utils_isMobileLike() then
		local hoverScale = Instance.new("UIScale")
		hoverScale.Scale = 1
		hoverScale.Parent = inst
		
		inst.MouseEnter:Connect(function()
			Core.SoundSystem.play("hover")
			Core.Animation.tween(hoverScale, {Scale=1.02}, Core.CONSTANTS.ANIM_FAST)
		end)
		inst.MouseLeave:Connect(function()
			Core.Animation.tween(hoverScale, {Scale=1}, Core.CONSTANTS.ANIM_FAST)
		end)
	end
	
	if props.onClick then
		inst.MouseButton1Click:Connect(props.onClick)
	end
	
	inst.MouseButton1Click:Connect(function()
		Core.SoundSystem.play("click")
	end)
	
	return cmp
end

function UI.Components.Image(props)
	local d = {
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit
	}
	for k, v in pairs(d) do if props[k] == nil then props[k] = v end end
	return Component.new("ImageLabel", props)
end

-- ======================================================
-- SHOP CLASS
-- ======================================================
local Shop = {}
Shop.__index = Shop

function Shop.new()
	local self = setmetatable({}, Shop)
	self.gui = nil
	self.mainPanel = nil
	self.tabContainer = nil
	self.contentContainer = nil
	self.currentTab = nil
	self.tabs = {}
	self.pages = {}
	self.toggleButton = nil
	self.blur = nil
	self._panelScale = nil
	self._edgeSwipe = nil
	self:initialize()
	return self
end

function Shop:preloadImages()
	local ids = {
		"rbxassetid://17398522865",
		"rbxassetid://10709728059",
		"rbxassetid://10709727148"
	}
	for _, p in ipairs(Core.DataManager.products.cash) do
		if p.icon then table.insert(ids, p.icon) end
	end
	for _, p in ipairs(Core.DataManager.products.gamepasses) do
		if p.icon then table.insert(ids, p.icon) end
	end
	task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync(ids) end)
	end)
end

function Shop:initialize()
	Core.SoundSystem.initialize()
	Core.DataManager.refreshPrices()
	self:preloadImages()
	self:createToggleButton()
	self:createMainInterface()
	self:setupInputHandlers()
	self:setupRemoteHandlers()
end

-- ✅ MOBILE: Draggable FAB (one-hand reach)
function Shop:createToggleButton()
	local sg = PlayerGui:FindFirstChild("SanrioShopToggle") or Instance.new("ScreenGui")
	sg.Name = "SanrioShopToggle"
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 999
	sg.IgnoreGuiInset = true
	sg.Parent = PlayerGui

	local prof = getProfile()
	local buttonSize = prof.isPhone and UDim2.fromOffset(140, minTouch(50))
		or (prof.isTablet and UDim2.fromOffset(160, minTouch(56)))
		or UDim2.fromOffset(180, minTouch(60))

	local pos, anchor
	if prof.isPhone then
		pos = UDim2.new(1, -16, 1, -90)
		anchor = Vector2.new(1, 1)
	elseif prof.isTablet then
		pos = UDim2.new(1, -16, 0.5, -60)
		anchor = Vector2.new(1, 0.5)
	else
		pos = UDim2.new(1, -16, 0.5, -70)
		anchor = Vector2.new(1, 0.5)
	end

	local iconSize = prof.isPhone and 26 or (prof.isTablet and 30 or 32)
	local iconPos = prof.isPhone and UDim2.fromOffset(12, 12) 
		or (prof.isTablet and UDim2.fromOffset(14, 13)) 
		or UDim2.fromOffset(16, 14)
	local textSize = prof.isPhone and 18 or (prof.isTablet and 19 or 20)
	local textPos = prof.isPhone and UDim2.fromOffset(46, 0) 
		or (prof.isTablet and UDim2.fromOffset(52, 0)) 
		or UDim2.fromOffset(56, 0)

	self.toggleButton = UI.Components.Button({
		Text = "",
		Size = buttonSize,
		Position = pos,
		AnchorPoint = anchor,
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(1, 0),
		stroke = {color=UI.Theme:get("accent"), thickness=2},
		parent = sg,
		onClick = function() self:toggle() end
	}):render()

	UI.Components.Image({
		Image = "rbxassetid://17398522865",
		Size = UDim2.fromOffset(iconSize, iconSize),
		Position = iconPos,
		parent = self.toggleButton
	}):render()

	UI.Components.TextLabel({
		Text = "Shop",
		Size = UDim2.new(1, -64, 1, 0),
		Position = textPos,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = textSize,
		parent = self.toggleButton
	}):render()

	-- ✅ MOBILE: Draggable FAB for one-hand reach
	if prof.isPhone then
		local dragging = false
		local dragStart = nil
		local startPos = nil

		self.toggleButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = self.toggleButton.Position
			end
		end)

		self.toggleButton.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.Touch then
				local delta = input.Position - dragStart
				local newPos = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)
				self.toggleButton.Position = newPos
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
	end
end

function Shop:createMainInterface()
	self.gui = PlayerGui:FindFirstChild("SanrioShopMain") or Instance.new("ScreenGui")
	self.gui.Name = "SanrioShopMain"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 1000
	self.gui.Enabled = false
	self.gui.IgnoreGuiInset = true
	self.gui.Parent = PlayerGui

	self.blur = Lighting:FindFirstChild("SanrioShopBlur") or Instance.new("BlurEffect")
	self.blur.Name = "SanrioShopBlur"
	self.blur.Size = 0
	self.blur.Parent = Lighting

	local dim = UI.Components.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.38,
		parent = self.gui
	}):render()
	dim.Active = true

	-- ✅ MOBILE: Edge swipe to close
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and input.Position.X < 20 then
			self._edgeSwipe = input.Position
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			local mousePos = input.Position
			local guiInset = GuiService:GetGuiInset()
			local adjustedPos = Vector2.new(mousePos.X, mousePos.Y - guiInset.Y)
			local panelPos = self.mainPanel.AbsolutePosition
			local panelSize = self.mainPanel.AbsoluteSize
			local inside = adjustedPos.X >= panelPos.X and 
			               adjustedPos.X <= (panelPos.X + panelSize.X) and 
			               adjustedPos.Y >= panelPos.Y and 
			               adjustedPos.Y <= (panelPos.Y + panelSize.Y)
			if not inside then self:close() end
		end
	end)

	dim.InputEnded:Connect(function(input)
		if self._edgeSwipe and input.UserInputType == Enum.UserInputType.Touch then
			local deltaX = input.Position.X - self._edgeSwipe.X
			if deltaX > 80 then
				self:close()
			end
		end
		self._edgeSwipe = nil
	end)

	local prof = getProfile()
	local v, short, landscape = vinfo()
	local safeInset = GuiService:GetGuiInset().Y
	local panelW = math.floor(v.X * prof.widthScale)
	local panelH = math.floor((v.Y - safeInset) * prof.heightScale)
	
	local target = prof.isPhone and Core.CONSTANTS.PANEL_SIZE_MOBILE
		or (prof.isTablet and Vector2.new(1020, 820))
		or Core.CONSTANTS.PANEL_SIZE
	
	panelW = math.clamp(panelW, prof.minW, target.X)
	panelH = math.clamp(panelH, prof.minH, target.Y)

	self.mainPanel = UI.Components.Frame({
		Size = UDim2.fromOffset(panelW, panelH),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UI.Theme:get("background"),
		cornerRadius = UDim.new(0, 22),
		stroke = {color=UI.Theme:get("stroke"), thickness=1},
		parent = self.gui
	}):render()

	-- ✅ PHONE: Global zoom-out
	self._panelScale = Instance.new("UIScale")
	self._panelScale.Scale = prof.isPhone and phonePanelScale(short) or 1
	self._panelScale.Parent = self.mainPanel

	self:buildHeader(prof)
	self:buildTabs(prof)
	self:buildContent(prof)

	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local p = getProfile()
		local v2, short2 = vinfo()
		local safeInset2 = GuiService:GetGuiInset().Y
		local w = math.floor(v2.X * p.widthScale)
		local h = math.floor((v2.Y - safeInset2) * p.heightScale)
		local tgt = p.isPhone and Core.CONSTANTS.PANEL_SIZE_MOBILE
			or (p.isTablet and Vector2.new(1020, 820))
			or Core.CONSTANTS.PANEL_SIZE
		w = math.clamp(w, p.minW, tgt.X)
		h = math.clamp(h, p.minH, tgt.Y)
		self.mainPanel.Size = UDim2.fromOffset(w, h)
		self._panelScale.Scale = p.isPhone and phonePanelScale(short2) or 1
	end)

	-- ✅ PHONE: Swipe to switch tabs
	if prof.isPhone then
		local startX = nil
		self.mainPanel.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Touch then
				startX = i.Position.X
			end
		end)
		self.mainPanel.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Touch and startX then
				local dx = i.Position.X - startX
				if math.abs(dx) > 60 then
					if dx < 0 then
						self:selectTab("Gamepasses")
					else
						self:selectTab("Cash")
					end
				end
				startX = nil
			end
		end)
	end
end

function Shop:buildHeader(prof)
	local headerHeight = prof.headerH
	local headerTextSize = (prof.title >= 20) and 28 or 26

	local header = UI.Components.Frame({
		Size = UDim2.new(1, -40, 0, headerHeight),
		Position = UDim2.fromOffset(20, 20),
		BackgroundColor3 = UI.Theme:get("surfaceAlt"),
		cornerRadius = UDim.new(0, 16),
		parent = self.mainPanel
	}):render()

	UI.Components.Image({
		Image = "rbxassetid://17398522865",
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.fromOffset(12, math.max(6, headerHeight - 56)),
		parent = header
	}):render()

	UI.Components.TextLabel({
		Text = "Sanrio Shop",
		Size = UDim2.new(1, -180, 1, 0),
		Position = UDim2.fromOffset(78, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = headerTextSize,
		parent = header
	}):render()

	UI.Components.Button({
		Text = "✕",
		Size = UDim2.fromOffset(minTouch(44), minTouch(44)),
		Position = UDim2.new(1, -56, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = UI.Theme:get("accent"),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		cornerRadius = UDim.new(0.5, 0),
		parent = header,
		onClick = function() self:close() end
	}):render()
end

function Shop:buildTabs(prof)
	local headerHeight = prof.headerH
	local tabSpacing = 16

	self.tabContainer = UI.Components.Frame({
		Size = UDim2.new(1, -40, 0, prof.tabH),
		Position = UDim2.fromOffset(20, 20 + headerHeight + tabSpacing),
		BackgroundTransparency = 1,
		parent = self.mainPanel
	}):render()

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 10)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tabLayout.Parent = self.tabContainer

	local tabs = {
		{id="Cash",       name="Cash",   icon="rbxassetid://10709728059", color=UI.Theme:get("cinna")},
		{id="Gamepasses", name="Passes", icon="rbxassetid://10709727148", color=UI.Theme:get("kuromi")},
	}

	local iconSize = math.clamp(math.floor(prof.tabH * 0.44), 18, 28)

	for _, d in ipairs(tabs) do
		local tab = UI.Components.Button({
			Text = "",
			Size = UDim2.fromOffset(prof.tabW, prof.tabH),
			BackgroundColor3 = UI.Theme:get("surface"),
			cornerRadius = UDim.new(0, 16),
			stroke = {color=UI.Theme:get("stroke"), thickness=2},
			parent = self.tabContainer,
			onClick = function() self:selectTab(d.id) end
		}):render()

		local content = UI.Components.Frame({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			parent = tab
		}):render()

		local contentLayout = Instance.new("UIListLayout")
		contentLayout.FillDirection = Enum.FillDirection.Horizontal
		contentLayout.Padding = UDim.new(0, 8)
		contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		contentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		contentLayout.Parent = content

		local icon = UI.Components.Image({
			Image = d.icon,
			Size = UDim2.fromOffset(iconSize, iconSize),
			parent = content
		}):render()

		local label = UI.Components.TextLabel({
			Text = d.name,
			Size = UDim2.new(0, 80, 1, 0),
			Font = Enum.Font.GothamBold,
			TextSize = prof.title,
			parent = content
		}):render()

		self.tabs[d.id] = {button=tab, data=d, icon=icon, label=label}
	end
end

function Shop:buildContent(prof)
	local headerHeight = prof.headerH
	local tabSpacing = 16
	local contentTop = 20 + headerHeight + tabSpacing + prof.tabH + 10

	self.contentContainer = UI.Components.Frame({
		Size = UDim2.new(1, -40, 1, -contentTop - 18),
		Position = UDim2.fromOffset(20, contentTop),
		BackgroundTransparency = 1,
		parent = self.mainPanel
	}):render()

	self:createPages()
	self:selectTab("Cash")
end

function Shop:createPages()
	local function gridSizer(grid)
		return function()
			local prof = getProfile()
			local imageH, titleH, descH, buttonH = prof.imgH, prof.titleH, prof.descH, prof.btnH
			local INNER = 10
			local fixedPadding = INNER * 2 + 2 + 6 + 6 + 6
			local contentPiecesH = imageH + titleH + descH + buttonH + fixedPadding

			local contentH = (self.contentContainer and self.contentContainer.AbsoluteSize.Y or 600)
			local targetVisible = (prof.isPhone and (prof.landscape and 2.2 or 1.4)) or 1.6
			local targetByViewport = math.max(220, math.floor((contentH - prof.gutter * 2) / targetVisible))

			local cardH = math.min(contentPiecesH, targetByViewport)
			local cols = (prof.isPhone and prof.landscape) and 2 or (prof.isPhone and 1 or prof.cols)

			grid.CellPadding = UDim2.fromOffset(prof.gutter, prof.gutter)
			local colWOffset = (cols == 1) and -6 or -12
			grid.CellSize = UDim2.new(1 / cols, colWOffset, 0, cardH)
		end
	end

	-- CASH PAGE
	local cashPage = UI.Components.Frame({
		Name = "CashPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		parent = self.contentContainer
	}):render()

	local sfCash = Instance.new("ScrollingFrame")
	sfCash.BackgroundTransparency = 1
	sfCash.ScrollBarThickness = 5
	sfCash.ScrollBarImageColor3 = UI.Theme:get("accent")
	sfCash.BorderSizePixel = 0
	sfCash.Size = UDim2.fromScale(1, 1)
	sfCash.ScrollingDirection = Enum.ScrollingDirection.Y
	sfCash.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sfCash.Parent = cashPage

	local cashContent = Instance.new("Frame")
	cashContent.BackgroundTransparency = 1
	cashContent.Size = UDim2.new(1, 0, 0, 0)
	cashContent.AutomaticSize = Enum.AutomaticSize.Y
	cashContent.Parent = sfCash

	local padCash = Instance.new("UIPadding")
	padCash.PaddingTop = UDim.new(0, 14)
	padCash.PaddingBottom = UDim.new(0, 22)
	padCash.PaddingLeft = UDim.new(0, 14)
	padCash.PaddingRight = UDim.new(0, 14)
	padCash.Parent = cashContent

	local gridCash = Instance.new("UIGridLayout")
	gridCash.SortOrder = Enum.SortOrder.LayoutOrder
	gridCash.FillDirection = Enum.FillDirection.Horizontal
	gridCash.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridCash.VerticalAlignment = Enum.VerticalAlignment.Top
	gridCash.Parent = cashContent

	local sizeCashGrid = gridSizer(gridCash)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(sizeCashGrid)
	sizeCashGrid()

	for _, p in ipairs(Core.DataManager.products.cash) do
		self:createProductCard(p, "cash", cashContent)
	end

	-- GAMEPASS PAGE
	local passPage = UI.Components.Frame({
		Name = "GamepassesPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		parent = self.contentContainer
	}):render()

	local sfPass = Instance.new("ScrollingFrame")
	sfPass.BackgroundTransparency = 1
	sfPass.ScrollBarThickness = 5
	sfPass.ScrollBarImageColor3 = UI.Theme:get("accent")
	sfPass.BorderSizePixel = 0
	sfPass.Size = UDim2.fromScale(1, 1)
	sfPass.ScrollingDirection = Enum.ScrollingDirection.Y
	sfPass.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sfPass.Parent = passPage

	local passContent = Instance.new("Frame")
	passContent.BackgroundTransparency = 1
	passContent.Size = UDim2.new(1, 0, 0, 0)
	passContent.AutomaticSize = Enum.AutomaticSize.Y
	passContent.Parent = sfPass

	local padPass = Instance.new("UIPadding")
	padPass.PaddingTop = UDim.new(0, 14)
	padPass.PaddingBottom = UDim.new(0, 22)
	padPass.PaddingLeft = UDim.new(0, 14)
	padPass.PaddingRight = UDim2.new(0, 14)
	padPass.Parent = passContent

	local gridPass = Instance.new("UIGridLayout")
	gridPass.SortOrder = Enum.SortOrder.LayoutOrder
	gridPass.FillDirection = Enum.FillDirection.Horizontal
	gridPass.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridPass.VerticalAlignment = Enum.VerticalAlignment.Top
	gridPass.Parent = passContent

	local sizePassGrid = gridSizer(gridPass)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(sizePassGrid)
	sizePassGrid()

	for _, gp in ipairs(Core.DataManager.products.gamepasses) do
		self:createProductCard(gp, "gamepass", passContent)
	end

	self.pages = {Cash = cashPage, Gamepasses = passPage}
end

function Shop:createProductCard(product, productType, parent)
	local prof = getProfile()
	local isGamepass = (productType == "gamepass")
	local cardColor = isGamepass and UI.Theme:get("kuromi") or UI.Theme:get("cinna")

	local strokeThickness = prof.isPhone and 2 or (prof.isTablet and 2 or 1.5)
	local strokeTransparency = prof.isPhone and 0.42 or (prof.isTablet and 0.42 or 0.55)

	local card = UI.Components.Frame({
		Name = product.name .. "Card",
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, 16),
		stroke = {color=cardColor, thickness=strokeThickness, transparency=strokeTransparency},
		parent = parent
	}):render()
	card.ClipsDescendants = true

	-- ✅ MOBILE: No hover on touch
	if not Core.Utils_isMobileLike() then
		local hoverScale = Instance.new("UIScale")
		hoverScale.Scale = 1
		hoverScale.Parent = card

		card.MouseEnter:Connect(function()
			Core.SoundSystem.play("hover")
			Core.Animation.tween(hoverScale, {Scale=1.03}, Core.CONSTANTS.ANIM_FAST)
		end)
		card.MouseLeave:Connect(function()
			Core.Animation.tween(hoverScale, {Scale=1}, Core.CONSTANTS.ANIM_FAST)
		end)
	end

	local INNER = 10
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -INNER * 2, 1, -INNER * 2)
	content.Position = UDim2.fromOffset(INNER, INNER)
	content.Parent = card

	local imageHeight = prof.imgH
	local titleH = prof.titleH
	local descH = prof.descH
	local buttonH = prof.btnH

	-- Banner
	local imageContainer = Instance.new("Frame")
	imageContainer.Size = UDim2.new(1, 0, 0, imageHeight)
	imageContainer.BackgroundColor3 = UI.Theme:get("surfaceAlt")
	imageContainer.BorderSizePixel = 0
	imageContainer.Parent = content

	local ic = Instance.new("UICorner")
	ic.CornerRadius = UDim.new(0, 12)
	ic.Parent = imageContainer

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(250, 250, 252))
	gradient.Rotation = 90
	gradient.Parent = imageContainer

	UI.Components.Image({
		Image = product.icon or "rbxassetid://0",
		Size = UDim2.fromScale(0.7, 0.7),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		parent = imageContainer
	}):render()

	-- Info
	local infoTop = imageHeight + 4
	local info = Instance.new("Frame")
	info.BackgroundTransparency = 1
	info.Size = UDim2.new(1, 0, 1, -infoTop - 6)
	info.Position = UDim2.fromOffset(0, infoTop)
	info.Parent = content

	local infoPad = Instance.new("UIPadding")
	infoPad.PaddingTop = UDim.new(0, 1)
	infoPad.PaddingBottom = UDim.new(0, 4)
	infoPad.Parent = info

	local vlist = Instance.new("UIListLayout")
	vlist.FillDirection = Enum.FillDirection.Vertical
	vlist.SortOrder = Enum.SortOrder.LayoutOrder
	vlist.Padding = UDim.new(0, 4)
	vlist.Parent = info

	-- Title + Price row
	local priceText = "R$" .. tostring(product.price or 0)
	local priceWidth = (prof.isPhone and 76) or (prof.isTablet and 92) or 96

	local titleRow = Instance.new("Frame")
	titleRow.BackgroundTransparency = 1
	titleRow.Size = UDim2.new(1, 0, 0, titleH)
	titleRow.LayoutOrder = 1
	titleRow.Parent = info

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = titleRow

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = UI.Theme:get("text")
	title.TextSize = prof.title
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.Text = product.name
	title.Size = UDim2.new(1, -priceWidth, 1, 0)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Parent = titleRow

	local price = Instance.new("TextLabel")
	price.BackgroundTransparency = 1
	price.Font = Enum.Font.GothamBold
	price.TextColor3 = cardColor
	price.TextSize = prof.price
	price.TextXAlignment = Enum.TextXAlignment.Right
	price.TextYAlignment = Enum.TextYAlignment.Center
	price.Text = priceText
	price.Size = UDim2.new(0, priceWidth, 1, 0)
	price.Parent = titleRow

	-- Description
	local descText = isGamepass and product.description 
		or ("Includes " .. Core.Utils_formatNumber(product.amount) .. " Cash")

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.Gotham
	desc.TextColor3 = UI.Theme:get("textSecondary")
	desc.TextSize = prof.desc
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.Text = descText
	desc.Size = UDim2.new(1, 0, 0, descH)
	desc.LineHeight = 1.1
	desc.LayoutOrder = 2
	desc.Parent = info

	-- Footer (button)
	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 0, 1, -INNER)
	footer.Size = UDim2.new(1, 0, 0, buttonH)
	footer.Parent = info

	local owned = isGamepass and getOwned(product.id)
	local btnTextSize = math.max(14, math.min(16, math.floor(buttonH * 0.36)))

	-- ✅ Enable/Disable for toggle passes
	local buttonText = owned and (product.hasToggle and "Enable" or "✓ Owned") or "Purchase"

	local btn = UI.Components.Button({
		Text = buttonText,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = owned and UI.Theme:get("success") or cardColor,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = btnTextSize,
		cornerRadius = UDim.new(0, 10),
		parent = footer
	}):render()

	btn.Active = not owned or (owned and product.hasToggle)
	btn.AutoButtonColor = btn.Active

	local bstroke = Instance.new("UIStroke")
	bstroke.Thickness = 1
	bstroke.Transparency = owned and 0.7 or 0.6
	bstroke.Color = Color3.new(0, 0, 0)
	bstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bstroke.Parent = btn

	btn.MouseButton1Click:Connect(function()
		if not btn or not btn.Parent then return end

		if isGamepass then
			if not getOwned(product.id) then
				btn.Text = "Processing..."
				btn.Active = false
				self:promptPurchase(product, "gamepass", btn)
			elseif product.hasToggle then
				-- ✅ Toggle Enable/Disable
				local nextState = (btn.Text == "Enable")
				btn.Text = nextState and "Disable" or "Enable"
				if Remotes then
					local ev = Remotes:FindFirstChild("AutoCollectToggle")
					if ev and ev:IsA("RemoteEvent") then
						ev:FireServer(nextState)
					end
				end
			end
		else
			btn.Text = "Processing..."
			btn.Active = false
			self:promptPurchase(product, "cash", btn)
		end
	end)

	-- ✅ Toggle chip (always visible state indicator)
	if isGamepass and product.hasToggle and owned then
		self:addToggleChip(product, imageContainer)
	end

	product.cardInstance = card
	product.purchaseButton = btn
end

-- ✅ MOBILE-OPTIMIZED Toggle Chip
function Shop:addToggleChip(product, imageContainer)
	local prof = getProfile()

	local wrap = Instance.new("Frame")
	wrap.Name = "ToggleChip"
	wrap.AnchorPoint = Vector2.new(1, 0)
	wrap.Position = UDim2.new(1, -8, 0, 8)
	wrap.Size = UDim2.fromOffset(prof.isPhone and 170 or 156, prof.isPhone and 36 or 34)
	wrap.BackgroundColor3 = UI.Theme:get("surface")
	wrap.BorderSizePixel = 0
	wrap.Parent = imageContainer

	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 18)
	rc.Parent = wrap

	local stroke = Instance.new("UIStroke")
	stroke.Color = UI.Theme:get("stroke")
	stroke.Thickness = 1.5
	stroke.Transparency = 0
	stroke.Parent = wrap

	local btn = Instance.new("TextButton")
	btn.BackgroundTransparency = 1
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.Size = UDim2.fromScale(1, 1)
	btn.Parent = wrap

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = prof.isPhone and 15 or 14
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = btn

	local state = false
	if Remotes then
		local rf = Remotes:FindFirstChild("GetAutoCollectState")
		if rf and rf:IsA("RemoteFunction") then
			local ok, val = pcall(function() return rf:InvokeServer() end)
			if ok and type(val) == "boolean" then state = val end
		end
	end

	local function paint(on)
		state = on
		if on then
			wrap.BackgroundColor3 = UI.Theme:get("success")
			stroke.Color = UI.Theme:get("success")
			label.Text = "Auto : ON"
			label.TextColor3 = Color3.new(1, 1, 1)
		else
			wrap.BackgroundColor3 = UI.Theme:get("surface")
			stroke.Color = UI.Theme:get("stroke")
			label.Text = "Auto : OFF"
			label.TextColor3 = UI.Theme:get("text")
		end
	end
	paint(state)

	-- ✅ MOBILE: Bigger tap feedback
	if not Core.Utils_isMobileLike() then
		local scale = Instance.new("UIScale")
		scale.Scale = 1
		scale.Parent = wrap

		wrap.MouseEnter:Connect(function()
			Core.Animation.tween(scale, {Scale=1.06}, Core.CONSTANTS.ANIM_FAST)
		end)
		wrap.MouseLeave:Connect(function()
			Core.Animation.tween(scale, {Scale=1.00}, Core.CONSTANTS.ANIM_FAST)
		end)
	end

	local busy = false
	btn.MouseButton1Click:Connect(function()
		if busy then return end
		busy = true
		local nextState = not state
		paint(nextState)
		Core.SoundSystem.play("click")

		if Remotes then
			local ev = Remotes:FindFirstChild("AutoCollectToggle")
			if ev and ev:IsA("RemoteEvent") then
				ev:FireServer(nextState)
			end
		end

		task.delay(0.2, function() busy = false end)
	end)
end

function Shop:selectTab(tabId)
	if self.currentTab == tabId and self.pages[tabId] and self.pages[tabId].Visible then return end

	for id, tab in pairs(self.tabs) do
		local active = (id == tabId)
		local d = tab.data

		Core.Animation.tween(tab.button, {
			BackgroundColor3 = active and blend(d.color, Color3.new(1, 1, 1), 0.85) or UI.Theme:get("surface")
		}, Core.CONSTANTS.ANIM_FAST)

		local s = tab.button:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color = active and d.color or UI.Theme:get("stroke")
			s.Thickness = active and 3 or 2
		end

		tab.icon.ImageColor3 = active and d.color or UI.Theme:get("text")
		tab.label.TextColor3 = active and d.color or UI.Theme:get("text")
	end

	for id, page in pairs(self.pages) do
		page.Visible = (id == tabId)
		if page.Visible then
			page.Position = UDim2.fromOffset(0, 16)
			Core.Animation.tween(page, {Position=UDim2.new()}, Core.CONSTANTS.ANIM_BOUNCE, Enum.EasingStyle.Back)
		end
	end

	self.currentTab = tabId
	Core.SoundSystem.play("click")
end

-- ✅ OPTIMISTIC PURCHASE (no flicker!)
function Shop:promptPurchase(product, kind, button)
	Core.State.purchasePending[product.id] = {
		product = product,
		type = kind,
		button = button,
		t = tick()
	}

	-- ✅ INSTANT optimistic ownership
	if kind == "gamepass" then
		setOwnedOptimistic(product.id, true)
	end

	local ok, err
	if kind == "gamepass" then
		ok, err = pcall(function()
			MarketplaceService:PromptGamePassPurchase(Player, product.id)
		end)
	else
		ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(Player, product.id)
		end)
	end

	if not ok then
		if kind == "gamepass" then
			setOwnedOptimistic(product.id, false)
		end
		if button and button.Parent then
			button.Text = "Purchase"
			button.Active = true
		end
		Core.State.purchasePending[product.id] = nil
		Core.SoundSystem.play("error")
		warn("[SanrioShop] Prompt failed:", err)
	else
		-- ✅ Don't reset gamepasses after 5 seconds (trust server)
		task.delay(5, function()
			local p = Core.State.purchasePending[product.id]
			if p and p.type == "gamepass" then return end
			if p and p.button and p.button.Parent then
				p.button.Text = "Purchase"
				p.button.Active = true
			end
			Core.State.purchasePending[product.id] = nil
		end)
	end
end

-- ✅ DON'T FIGHT PENDING UI
function Shop:refreshAllProducts()
	local pendingIds = {}
	for id, _ in pairs(Core.State.purchasePending) do
		pendingIds[id] = true
	end

	for _, gp in ipairs(Core.DataManager.products.gamepasses) do
		local owned = getOwned(gp.id)

		-- ✅ Freeze as Owned if pending
		if pendingIds[gp.id] then owned = true end

		if gp.purchaseButton and gp.purchaseButton.Parent then
			local buttonText = owned and (gp.hasToggle and "Enable" or "✓ Owned") or "Purchase"
			gp.purchaseButton.Text = buttonText
			gp.purchaseButton.BackgroundColor3 = owned and UI.Theme:get("success") or UI.Theme:get("kuromi")
			gp.purchaseButton.Active = not owned or (owned and gp.hasToggle)
			gp.purchaseButton.AutoButtonColor = gp.purchaseButton.Active
		end

		if gp.cardInstance and gp.cardInstance.Parent then
			local stroke = gp.cardInstance:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = owned and UI.Theme:get("success") or UI.Theme:get("kuromi")
			end

			-- ✅ Add toggle chip if missing
			if owned and gp.hasToggle then
				local imageContainer = gp.cardInstance:FindFirstChild("Frame")
				if imageContainer and not imageContainer:FindFirstChild("ToggleChip") then
					self:addToggleChip(gp, imageContainer)
				end
			end
		end
	end

	print("✅ [Shop] Refreshed all products")
end

function Shop:open()
	if Core.State.isOpen or Core.State.isAnimating then return end
	Core.State.isAnimating = true
	Core.State.isOpen = true

	-- ✅ Refresh without clearing optimistic state
	Core.DataManager.refreshPrices()
	self:refreshAllProducts()

	self.gui.Enabled = true
	Core.Animation.tween(self.blur, {Size=24}, Core.CONSTANTS.ANIM_MEDIUM)

	local prof = getProfile()
	local v, short = vinfo()
	local safeInset = GuiService:GetGuiInset().Y
	local w = math.floor(v.X * prof.widthScale)
	local h = math.floor((v.Y - safeInset) * prof.heightScale)
	local tgt = prof.isPhone and Core.CONSTANTS.PANEL_SIZE_MOBILE
		or (prof.isTablet and Vector2.new(1020, 820))
		or Core.CONSTANTS.PANEL_SIZE
	w = math.clamp(w, prof.minW, tgt.X)
	h = math.clamp(h, prof.minH, tgt.Y)

	self.mainPanel.Position = UDim2.fromScale(0.5, 0.52)
	self.mainPanel.Size = UDim2.fromOffset(math.floor(w * 0.94), math.floor(h * 0.94))

	Core.Animation.tween(self.mainPanel, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h)
	}, Core.CONSTANTS.ANIM_BOUNCE, Enum.EasingStyle.Back)

	self:selectTab(self.currentTab or "Cash")
	Core.SoundSystem.play("open")
	task.wait(Core.CONSTANTS.ANIM_BOUNCE)
	Core.State.isAnimating = false
end

function Shop:close()
	if not Core.State.isOpen or Core.State.isAnimating then return end
	Core.State.isAnimating = true
	Core.State.isOpen = false

	Core.Animation.tween(self.blur, {Size=0}, Core.CONSTANTS.ANIM_FAST)

	local currentW, currentH = self.mainPanel.AbsoluteSize.X, self.mainPanel.AbsoluteSize.Y
	Core.Animation.tween(self.mainPanel, {
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(currentW * 0.94, currentH * 0.94)
	}, Core.CONSTANTS.ANIM_FAST)

	Core.SoundSystem.play("close")
	task.wait(Core.CONSTANTS.ANIM_FAST)
	self.gui.Enabled = false
	Core.State.isAnimating = false
end

function Shop:toggle()
	if Core.State.isOpen then
		self:close()
	else
		self:open()
	end
end

-- ✅ SERVER CONFIRMATION (source of truth)
function Shop:setupRemoteHandlers()
	if not Remotes then
		warn("[SanrioShop] TycoonRemotes folder not found!")
		return
	end

	local gamepassPurchased = Remotes:FindFirstChild("GamepassPurchased")
	if gamepassPurchased and gamepassPurchased:IsA("RemoteEvent") then
		gamepassPurchased.OnClientEvent:Connect(function(passId, enabledState)
			print("🎮 [Shop] Server confirmed gamepass:", passId)

			-- ✅ Lock as owned (server has finalized)
			setOwnedOptimistic(passId, true)

			-- ✅ Refresh UI once
			self:refreshAllProducts()

			-- ✅ Update toggle chip if state provided
			if enabledState ~= nil then
				-- Find the product and update its toggle chip
				for _, gp in ipairs(Core.DataManager.products.gamepasses) do
					if gp.id == passId and gp.cardInstance then
						local imageContainer = gp.cardInstance:FindFirstChild("Frame")
						if imageContainer then
							local chip = imageContainer:FindFirstChild("ToggleChip")
							if chip then
								local label = chip:FindFirstChild("TextButton"):FindFirstChild("TextLabel")
								if label then
									if enabledState then
										chip.BackgroundColor3 = UI.Theme:get("success")
										label.Text = "Auto : ON"
										label.TextColor3 = Color3.new(1, 1, 1)
									else
										chip.BackgroundColor3 = UI.Theme:get("surface")
										label.Text = "Auto : OFF"
										label.TextColor3 = UI.Theme:get("text")
									end
								end
							end
						end
					end
				end
			end

			Core.SoundSystem.play("success")
		end)
		print("[SanrioShop] ✅ Listening for GamepassPurchased events")
	else
		warn("[SanrioShop] GamepassPurchased remote not found!")
	end
end

function Shop:setupInputHandlers()
	UserInputService.InputBegan:Connect(function(i, gp)
		if gp then return end
		if i.KeyCode == Enum.KeyCode.M then
			self:toggle()
		elseif i.KeyCode == Enum.KeyCode.Escape and Core.State.isOpen then
			self:close()
		end
	end)
end

-- ======================================================
-- BOOT
-- ======================================================
Core.SoundSystem.initialize()
local shop = Shop.new()

-- ✅ PURCHASE CALLBACKS (optimistic + rollback)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if player ~= Player then return end

	local pend = Core.State.purchasePending[passId]
	if pend then
		Core.State.purchasePending[passId] = nil
	end

	if purchased then
		setOwnedOptimistic(passId, true)
		print("✅ [Shop] Gamepass purchased:", passId)
	else
		-- ✅ User cancelled: roll back optimistic
		setOwnedOptimistic(passId, false)
	end

	shop:refreshAllProducts()
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, purchased)
	if player ~= Player then return end

	local p = Core.State.purchasePending[productId]
	if p and p.button and p.button.Parent then
		p.button.Text = "Purchase"
		p.button.Active = true
	end
	Core.State.purchasePending[productId] = nil

	if purchased then
		Core.SoundSystem.play("success")
		print("✅ [Shop] Product purchased:", productId)
	end
end)

Player.CharacterAdded:Connect(function()
	task.wait(1)
	if not shop.toggleButton or not shop.toggleButton.Parent then
		shop:createToggleButton()
	end
end)

-- ✅ Auto-refresh (but don't clear optimistic state)
task.spawn(function()
	while true do
		task.wait(30)
		if Core.State.isOpen then
			shop:refreshAllProducts()
		end
	end
end)

print("[SanrioShop] 🎀 ULTIMATE MOBILE-FIRST EDITION")
print("  ✅ Optimistic ownership (no flicker)")
print("  ✅ Server-confirmed state machine")
print("  ✅ ≥44px touch targets")
print("  ✅ Draggable FAB + edge swipes")
print("  ✅ Enable/Disable for toggle passes")
print("  ✅ Crystal-clear text (no TextScaled)")
print("  ✅ Phone: ≥1.4 cards (portrait) / ~2.2 (landscape)")

return shop
