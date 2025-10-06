-- ========================================
-- SANRIO SHOP SYSTEM - POLISHED VERSION
-- ========================================
-- Location: StarterPlayer > StarterPlayerScripts
-- Features: Responsive grid, safe areas, accessibility, performance optimizations

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
local HapticService = game:GetService("HapticService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:FindFirstChild("TycoonRemotes")

-- ========================================
-- CORE SYSTEM
-- ========================================
local Core = {}

Core.CONSTANTS = {
	-- Layout constraints
	CARD_MIN_WIDTH = 300,
	CARD_MAX_WIDTH = 560,
	CARD_ASPECT_RATIO = 16/9,
	GRID_GUTTER = 20,
	GRID_PADDING = 24,

	-- Panel sizes (responsive)
	PANEL_SIZE_DESKTOP = Vector2.new(1140, 860),
	PANEL_SIZE_MOBILE = Vector2.new(920, 720),

	-- Animation timings
	ANIM_FAST = 0.15,
	ANIM_MEDIUM = 0.25,
	ANIM_BOUNCE = 0.3,
	ANIM_SKELETON = 0.8,

	-- Cache durations
	CACHE_PRODUCT_INFO = 300,
	CACHE_OWNERSHIP = 60,
	PURCHASE_TIMEOUT = 15,
}

Core.State = {
	isOpen = false,
	isAnimating = false,
	purchasePending = {},
	settings = {
		soundEnabled = true,
		animationsEnabled = true,
		reducedMotion = false
	},
	focusedCard = nil,
}

-- Enhanced cache system
local Cache = {}
Cache.__index = Cache
function Cache.new(duration)
	return setmetatable({data = {}, duration = duration or 300}, Cache)
end
function Cache:set(key, value)
	self.data[key] = {value = value, timestamp = tick()}
end
function Cache:get(key)
	local entry = self.data[key]
	if not entry then return nil end
	if tick() - entry.timestamp > self.duration then
		self.data[key] = nil
		return nil
	end
	return entry.value
end
function Cache:clear(key)
	if key then self.data[key] = nil else self.data = {} end
end

local productCache = Cache.new(Core.CONSTANTS.CACHE_PRODUCT_INFO)
local ownershipCache = Cache.new(Core.CONSTANTS.CACHE_OWNERSHIP)

-- Utilities
Core.Utils = {}
function Core.Utils.isMobile()
	local camera = workspace.CurrentCamera
	if not camera then return false end
	local viewport = camera.ViewportSize
	return viewport.X < 1024 or GuiService:IsTenFootInterface()
end
function Core.Utils.formatNumber(n)
	local s = tostring(n)
	local k = 1
	while k ~= 0 do
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	end
	return s
end
function Core.Utils.blend(a, b, t)
	t = math.clamp(t, 0, 1)
	return Color3.new(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t
	)
end
function Core.Utils.getSafeAreaInsets()
	local insets = GuiService:GetSafeZoneInsets()
	return {
		top = insets.Top,
		bottom = insets.Bottom,
		left = insets.Left,
		right = insets.Right
	}
end

-- Enhanced animation system
Core.Animation = {}
function Core.Animation.tween(instance, properties, duration, style, direction)
	if not Core.State.settings.animationsEnabled then
		for k, v in pairs(properties) do
			instance[k] = v
		end
		return
	end

	local tweenInfo = TweenInfo.new(
		duration or Core.CONSTANTS.ANIM_MEDIUM,
		style or (Core.State.settings.reducedMotion and Enum.EasingStyle.Linear or Enum.EasingStyle.Quad),
		direction or Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(instance, tweenInfo, properties)
	tween:Play()
	return tween
end

-- Enhanced sound system
Core.SoundSystem = {sounds = {}}
function Core.SoundSystem.initialize()
	local config = {
		click = {"rbxassetid://876939830", 0.45},
		hover = {"rbxassetid://10066936758", 0.2},
		open = {"rbxassetid://452267918", 0.5},
		close = {"rbxassetid://452267918", 0.5},
		success = {"rbxassetid://876939830", 0.6},
		error = {"rbxassetid://876939830", 0.5},
	}

	local preloadAssets = {}
	for name, data in pairs(config) do
		local sound = Instance.new("Sound")
		sound.Name = "SanrioShop_" .. name
		sound.SoundId = data[1]
		sound.Volume = data[2]
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.Parent = SoundService
		Core.SoundSystem.sounds[name] = sound
		table.insert(preloadAssets, sound)
	end

	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(preloadAssets)
		end)
	end)
end
function Core.SoundSystem.play(name)
	if Core.State.settings.soundEnabled and Core.SoundSystem.sounds[name] then
		Core.SoundSystem.sounds[name]:Play()
	end
end

-- Data management
Core.DataManager = {}
Core.DataManager.products = {
	cash = {
		{
			id = 3366419712,
			amount = 1000,
			name = "1,000 Cash",
			description = "A small boost to get you started",
			icon = "rbxassetid://10709728059",
			price = 0
		},
		{
			id = 3366420012,
			amount = 5000,
			name = "5,000 Cash",
			description = "Perfect for mid-game expansion",
			icon = "rbxassetid://10709728059",
			price = 0
		},
		{
			id = 3366420478,
			amount = 10000,
			name = "10,000 Cash",
			description = "Accelerate your progress",
			icon = "rbxassetid://10709728059",
			price = 0
		},
		{
			id = 3366420800,
			amount = 25000,
			name = "25,000 Cash",
			description = "Great value bundle",
			icon = "rbxassetid://10709728059",
			price = 0
		},
	},
	gamepasses = {
		{
			id = 1412171840,
			name = "Auto Collect",
			description = "Automatically collect all cash drops",
			icon = "rbxassetid://10709727148",
			price = 99,
			hasToggle = true
		},
		{
			id = 1398974710,
			name = "2x Cash",
			description = "Double all cash earned permanently",
			icon = "rbxassetid://10709727148",
			price = 199,
			hasToggle = false
		},
	},
}

function Core.DataManager.getProductInfo(id)
	local cached = productCache:get(id)
	if cached then return cached end

	local success, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
	end)

	if success and info then
		productCache:set(id, info)
		return info
	end
end

function Core.DataManager.getGamePassInfo(id)
	local key = "pass_" .. id
	local cached = productCache:get(key)
	if cached then return cached end

	local success, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
	end)

	if success and info then
		productCache:set(key, info)
		return info
	end
end

function Core.DataManager.checkOwnership(passId)
	local key = ("%d_%d"):format(Player.UserId, passId)
	local cached = ownershipCache:get(key)
	if cached ~= nil then return cached end

	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, passId)
	end)

	if success then
		ownershipCache:set(key, owns)
		return owns
	end
	return false
end

function Core.DataManager.refreshPrices()
	for _, product in ipairs(Core.DataManager.products.cash) do
		local info = Core.DataManager.getProductInfo(product.id)
		if info and info.PriceInRobux then
			product.price = info.PriceInRobux
		end
	end

	for _, gamepass in ipairs(Core.DataManager.products.gamepasses) do
		local info = Core.DataManager.getGamePassInfo(gamepass.id)
		if info and info.PriceInRobux then
			gamepass.price = info.PriceInRobux
		end
	end
end

-- ========================================
-- UI SYSTEM
-- ========================================
local UI = {}

UI.Theme = {
	current = "light",
	themes = {
		light = {
			background = Color3.fromRGB(253, 252, 250),
			surface = Color3.fromRGB(255, 255, 255),
			surfaceAlt = Color3.fromRGB(246, 248, 252),
			stroke = Color3.fromRGB(222, 226, 235),
			text = Color3.fromRGB(35, 38, 46),
			textSecondary = Color3.fromRGB(120, 126, 140),
			accent = Color3.fromRGB(255, 64, 129),
			success = Color3.fromRGB(76, 175, 80),
			cinna = Color3.fromRGB(186, 214, 255),
			kuromi = Color3.fromRGB(200, 190, 255),
		}
	}
}

function UI.Theme:get(key)
	return self.themes[self.current][key]
end

UI.Tokens = {
	radius = { small = 10, medium = 16, large = 24 },
	elevation = { z1 = 0.06, z2 = 0.12 },
	spacing = { xs = 8, sm = 12, md = 16, lg = 24 },
	typography = { h1 = 32, h2 = 24, body = 16, caption = 14, small = 12 }
}

-- Base component system
local Component = {}
Component.__index = Component

function Component.new(className, props)
	return setmetatable({instance = Instance.new(className), props = props or {}}, Component)
end

function Component:render()
	local instance = self.instance
	local props = self.props

	for k, v in pairs(props) do
		if k ~= "children" and k ~= "parent" and k ~= "onClick" and k ~= "cornerRadius" and
		   k ~= "stroke" and k ~= "layout" and k ~= "padding" and k ~= "clipsDescendants" then
			pcall(function() instance[k] = v end)
		end
	end

	if props.cornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = props.cornerRadius
		corner.Parent = instance
	end

	if props.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = props.stroke.color or UI.Theme:get("stroke")
		stroke.Thickness = props.stroke.thickness or 1
		stroke.Transparency = props.stroke.transparency or 0
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = instance
	end

	if props.clipsDescendants then
		instance.ClipsDescendants = true
	end

	if props.parent then
		instance.Parent = props.parent
	end

	return instance
end

UI.Components = {}

function UI.Components.Frame(props)
	local defaults = {
		BackgroundColor3 = UI.Theme:get("surface"),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1)
	}

	for k, v in pairs(defaults) do
		if props[k] == nil then props[k] = v end
	end

	local component = Component.new("Frame", props)
	local instance = component:render()

	if props.layout then
		local layoutType = props.layout.type or "List"
		local layout = Instance.new("UI" .. layoutType .. "Layout")

		for k, v in pairs(props.layout) do
			if k ~= "type" then
				pcall(function() layout[k] = v end)
			end
		end

		layout.Parent = instance

		if props.layout.updateCanvasSize then
			local function updateCanvas()
				if instance.Parent and instance.Parent:IsA("ScrollingFrame") then
					local contentSize = layout.AbsoluteContentSize
					instance.Parent.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 20)
				end
			end
			layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
			task.defer(updateCanvas)
		end
	end

	if props.padding then
		local padding = Instance.new("UIPadding")
		if props.padding.top then padding.PaddingTop = UDim.new(0, props.padding.top) end
		if props.padding.bottom then padding.PaddingBottom = UDim.new(0, props.padding.bottom) end
		if props.padding.left then padding.PaddingLeft = UDim.new(0, props.padding.left) end
		if props.padding.right then padding.PaddingRight = UDim.new(0, props.padding.right) end
		padding.Parent = instance
	end

	return { instance = instance, render = function() return instance end }
end

function UI.Components.TextLabel(props)
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = UI.Theme:get("text"),
		Font = Enum.Font.Gotham,
		TextWrapped = true
	}

	for k, v in pairs(defaults) do
		if props[k] == nil then props[k] = v end
	end

	return Component.new("TextLabel", props)
end

function UI.Components.Button(props)
	local defaults = {
		BackgroundColor3 = UI.Theme:get("accent"),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamMedium,
		Size = UDim2.fromOffset(120, 44), -- Minimum touch target
		AutoButtonColor = false
	}

	for k, v in pairs(defaults) do
		if props[k] == nil then props[k] = v end
	end

	local component = Component.new("TextButton", props)
	local instance = component:render()

	-- Enhanced hover effects
	local originalSize = instance.Size
	local hoverScale = props.hoverScale or 1.02

	instance.MouseEnter:Connect(function()
		Core.SoundSystem.play("hover")
		if not Core.State.settings.reducedMotion then
			Core.Animation.tween(instance, {Size = UDim2.new(
				originalSize.X.Scale * hoverScale,
				originalSize.X.Offset * hoverScale,
				originalSize.Y.Scale * hoverScale,
				originalSize.Y.Offset * hoverScale
			)}, Core.CONSTANTS.ANIM_FAST)
		end
	end)

	instance.MouseLeave:Connect(function()
		Core.Animation.tween(instance, {Size = originalSize}, Core.CONSTANTS.ANIM_FAST)
	end)

	-- Click handling
	if props.onClick then
		instance.MouseButton1Click:Connect(props.onClick)
	end
	instance.MouseButton1Click:Connect(function()
		Core.SoundSystem.play("click")
		if HapticService then
			pcall(function() HapticService:PlayLocalHaptic("Light") end)
		end
	end)

	return component
end

function UI.Components.Image(props)
	local defaults = {
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit
	}

	for k, v in pairs(defaults) do
		if props[k] == nil then props[k] = v end
	end

	return Component.new("ImageLabel", props)
end

-- Layout helpers
UI.Layout = {}
function UI.Layout.grid(parent, config)
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(config.gutter or Core.CONSTANTS.GRID_GUTTER, config.gutter or Core.CONSTANTS.GRID_GUTTER)
	grid.CellSize = UDim2.fromOffset(config.cellWidth or 300, config.cellHeight or 200)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = parent

	-- Responsive column calculation
	local function updateGrid()
		local containerWidth = parent.AbsoluteSize.X
		local availableWidth = containerWidth - (config.padding or Core.CONSTANTS.GRID_PADDING) * 2
		local gutter = config.gutter or Core.CONSTANTS.GRID_GUTTER
		local minWidth = config.minCellWidth or Core.CONSTANTS.CARD_MIN_WIDTH
		local maxWidth = config.maxCellWidth or Core.CONSTANTS.CARD_MAX_WIDTH

		local cols = math.floor((availableWidth + gutter) / (minWidth + gutter))
		cols = math.clamp(cols, 1, 3) -- 3/2/1 grid

		local cellWidth = (availableWidth - (cols - 1) * gutter) / cols
		cellWidth = math.clamp(cellWidth, minWidth, maxWidth)

		grid.CellSize = UDim2.fromOffset(cellWidth, cellWidth * (config.aspectRatio or 1))
	end

	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateGrid)
	task.defer(updateGrid)

	grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if parent.Parent and parent.Parent:IsA("ScrollingFrame") then
			parent.Parent.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 20)
		end
	end)

	return grid
end

-- Responsive scaling
UI.Responsive = {}
function UI.Responsive.scale(instance)
	local camera = workspace.CurrentCamera
	if not camera then return end

	local scale = Instance.new("UIScale")
	scale.Parent = instance

	local function update()
		local viewport = camera.ViewportSize
		local baseScale = math.min(viewport.X / 1920, viewport.Y / 1080)
		baseScale = math.clamp(baseScale, 0.5, 1.35)

		if Core.Utils.isMobile() then
			baseScale = baseScale * 0.9
		end

		scale.Scale = baseScale
	end

	update()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
end

-- Safe area handling
function UI.Responsive.applySafeArea(parent)
	local insets = Core.Utils.getSafeAreaInsets()

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, insets.top)
	padding.PaddingBottom = UDim.new(0, insets.bottom)
	padding.PaddingLeft = UDim.new(0, insets.left)
	padding.PaddingRight = UDim.new(0, insets.right)
	padding.Parent = parent
end

-- Skeleton loading component
function UI.Components.Skeleton(props)
	local component = Component.new("Frame", {
		BackgroundColor3 = UI.Theme:get("surfaceAlt"),
		BorderSizePixel = 0,
		Size = props.size or UDim2.fromScale(1, 1),
		parent = props.parent,
		cornerRadius = props.cornerRadius
	})

	local instance = component:render()

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(240, 240, 240)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))
	}
	gradient.Parent = instance

	-- Shimmer animation
	if not Core.State.settings.reducedMotion then
		local function animate()
			gradient.Offset = Vector2.new(-1, 0)
			Core.Animation.tween(gradient, {Offset = Vector2.new(1, 0)}, Core.CONSTANTS.ANIM_SKELETON, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
		end

		local shimmer = function()
			task.wait(math.random(10, 30) / 10)
			while instance.Parent do
				animate()
				task.wait(Core.CONSTANTS.ANIM_SKELETON + 0.5)
			end
		end

		task.spawn(shimmer)
	end

	return component
end

-- ========================================
-- SHOP SYSTEM
-- ========================================
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
	self.focusedCardIndex = 1
	self.cardRefs = {}
	self.connections = {}

	return self
end

function Shop:preloadAssets()
	local assetIds = {"rbxassetid://17398522865"}

	for _, product in ipairs(Core.DataManager.products.cash) do
		if product.icon then table.insert(assetIds, product.icon) end
	end

	for _, gamepass in ipairs(Core.DataManager.products.gamepasses) do
		if gamepass.icon then table.insert(assetIds, gamepass.icon) end
	end

	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(assetIds)
		end)
	end)
end

function Shop:initialize()
	Core.SoundSystem.initialize()
	Core.DataManager.refreshPrices()
	self:preloadAssets()
	self:createToggleButton()
	self:createMainInterface()
	self:setupInputHandlers()
	self:setupConnections()
end

function Shop:createToggleButton()
	local screenGui = PlayerGui:FindFirstChild("SanrioShopToggle") or Instance.new("ScreenGui")
	screenGui.Name = "SanrioShopToggle"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 999
	screenGui.Parent = PlayerGui

	self.toggleButton = UI.Components.Button({
		Text = "",
		Size = UDim2.fromOffset(180, 60),
		Position = UDim2.new(1, -20, 1, -20),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(1, 0),
		stroke = {color = UI.Theme:get("accent"), thickness = 2},
		parent = screenGui,
		onClick = function() self:toggle() end
	}):render()

	UI.Components.Image({
		Image = "rbxassetid://17398522865",
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(16, 14),
		parent = self.toggleButton
	}):render()

	UI.Components.TextLabel({
		Text = "Shop",
		Size = UDim2.new(1, -64, 1, 0),
		Position = UDim2.fromOffset(56, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = UI.Tokens.typography.h2,
		parent = self.toggleButton
	}):render()

	UI.Responsive.applySafeArea(screenGui)
end

function Shop:createMainInterface()
	self.gui = PlayerGui:FindFirstChild("SanrioShopMain") or Instance.new("ScreenGui")
	self.gui.Name = "SanrioShopMain"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 1000
	self.gui.Enabled = false
	self.gui.Parent = PlayerGui

	-- Blur effect
	self.blur = Lighting:FindFirstChild("SanrioShopBlur") or Instance.new("BlurEffect")
	self.blur.Name = "SanrioShopBlur"
	self.blur.Size = 0
	self.blur.Parent = Lighting

	-- Backdrop
	local backdrop = UI.Components.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		parent = self.gui
	}):render()
	backdrop.Active = true
	backdrop.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:close()
		end
	end)

	-- Main panel
	local panelSize = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE_DESKTOP
	self.mainPanel = UI.Components.Frame({
		Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UI.Theme:get("background"),
		cornerRadius = UDim.new(0, UI.Tokens.radius.large),
		stroke = {color = UI.Theme:get("stroke"), thickness = 1},
		clipsDescendants = true,
		parent = self.gui
	}):render()

	UI.Responsive.scale(self.mainPanel)

	-- Glass header effect
	local header = UI.Components.Frame({
		Size = UDim2.new(1, -48, 0, 80),
		Position = UDim2.fromOffset(24, 24),
		BackgroundColor3 = UI.Theme:get("surfaceAlt"),
		cornerRadius = UDim.new(0, UI.Tokens.radius.medium),
		parent = self.mainPanel
	}):render()

	-- Inner shadow for glass effect
	local headerStroke = Instance.new("UIStroke")
	headerStroke.Color = UI.Theme:get("stroke")
	headerStroke.Thickness = 1
	headerStroke.Transparency = 0.3
	headerStroke.Parent = header

	local headerGradient = Instance.new("UIGradient")
	headerGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 245, 255))
	}
	headerGradient.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.1)
	}
	headerGradient.Parent = header

	-- Header content
	UI.Components.Image({
		Image = "rbxassetid://17398522865",
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.fromOffset(16, 10),
		parent = header
	}):render()

	UI.Components.TextLabel({
		Text = "Sanrio Shop",
		Size = UDim2.new(1, -200, 1, 0),
		Position = UDim2.fromOffset(92, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = UI.Tokens.typography.h1,
		parent = header
	}):render()

	UI.Components.Button({
		Text = "×",
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.new(1, -64, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = UI.Theme:get("accent"),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = UI.Tokens.typography.h2,
		cornerRadius = UDim.new(0.5, 0),
		parent = header,
		onClick = function() self:close() end
	}):render()

	-- Tabs
	self.tabContainer = UI.Components.Frame({
		Size = UDim2.new(1, -48, 0, 48),
		Position = UDim2.fromOffset(24, 116),
		BackgroundTransparency = 1,
		parent = self.mainPanel
	}):render()

	UI.Layout.stack(self.tabContainer, Enum.FillDirection.Horizontal, UI.Tokens.spacing.md)

	local tabs = {
		{ id = "Cash", name = "Cash", icon = "rbxassetid://10709728059", color = UI.Theme:get("cinna") },
		{ id = "Gamepasses", name = "Passes", icon = "rbxassetid://10709727148", color = UI.Theme:get("kuromi") },
	}

	for _, tabData in ipairs(tabs) do
		local tab = UI.Components.Button({
			Text = "",
			Size = UDim2.fromOffset(160, 48),
			BackgroundColor3 = UI.Theme:get("surface"),
			cornerRadius = UDim.new(0.5, 0),
			stroke = {color = UI.Theme:get("stroke"), thickness = 1},
			parent = self.tabContainer,
			onClick = function() self:selectTab(tabData.id) end
		}):render()

		local content = UI.Components.Frame({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			parent = tab
		}):render()

		UI.Layout.stack(content, Enum.FillDirection.Horizontal, UI.Tokens.spacing.sm, {left = 16, right = 16})

		local icon = UI.Components.Image({
			Image = tabData.icon,
			Size = UDim2.fromOffset(24, 24),
			parent = content
		}):render()

		local label = UI.Components.TextLabel({
			Text = tabData.name,
			Size = UDim2.new(1, -32, 1, 0),
			Font = Enum.Font.GothamMedium,
			TextSize = UI.Tokens.typography.body,
			parent = content
		}):render()

		self.tabs[tabData.id] = {button = tab, data = tabData, icon = icon, label = label}
	end

	-- Content container
	self.contentContainer = UI.Components.Frame({
		Size = UDim2.new(1, -48, 1, -180),
		Position = UDim2.fromOffset(24, 156),
		BackgroundTransparency = 1,
		parent = self.mainPanel
	}):render()

	self:createPages()
	self:selectTab("Cash")
end

function Shop:createPages()
	-- Cash page
	local cashPage = UI.Components.Frame({
		Name = "CashPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		parent = self.contentContainer
	}):render()

	local cashScroll = Instance.new("ScrollingFrame")
	cashScroll.BackgroundTransparency = 1
	cashScroll.ScrollBarThickness = 8
	cashScroll.ScrollBarImageColor3 = UI.Theme:get("stroke")
	cashScroll.Size = UDim2.fromScale(1, 1)
	cashScroll.Parent = cashPage

	UI.Layout.grid(cashScroll, {
		gutter = Core.CONSTANTS.GRID_GUTTER,
		minCellWidth = Core.CONSTANTS.CARD_MIN_WIDTH,
		maxCellWidth = Core.CONSTANTS.CARD_MAX_WIDTH,
		padding = Core.CONSTANTS.GRID_PADDING
	})

	for _, product in ipairs(Core.DataManager.products.cash) do
		self:createProductCard(product, "cash", cashScroll)
	end

	-- Gamepasses page
	local passPage = UI.Components.Frame({
		Name = "GamepassesPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		parent = self.contentContainer
	}):render()

	local passScroll = Instance.new("ScrollingFrame")
	passScroll.BackgroundTransparency = 1
	passScroll.ScrollBarThickness = 8
	passScroll.ScrollBarImageColor3 = UI.Theme:get("stroke")
	passScroll.Size = UDim2.fromScale(1, 1)
	passScroll.Parent = passPage

	UI.Layout.grid(passScroll, {
		gutter = Core.CONSTANTS.GRID_GUTTER,
		minCellWidth = Core.CONSTANTS.CARD_MIN_WIDTH,
		maxCellWidth = Core.CONSTANTS.CARD_MAX_WIDTH,
		padding = Core.CONSTANTS.GRID_PADDING
	})

	for _, gamepass in ipairs(Core.DataManager.products.gamepasses) do
		self:createProductCard(gamepass, "gamepass", passScroll)
	end

	self.pages = { Cash = cashPage, Gamepasses = passPage }
end

function Shop:createProductCard(product, productType, parent)
	local isGamepass = (productType == "gamepass")
	local cardColor = isGamepass and UI.Theme:get("kuromi") or UI.Theme:get("cinna")

	local card = UI.Components.Frame({
		Name = product.name .. "Card",
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, UI.Tokens.radius.medium),
		stroke = {color = cardColor, thickness = 2, transparency = 0.5},
		clipsDescendants = true,
		parent = parent
	}):render()

	-- Focus ring for accessibility
	local focusRing = Instance.new("UIStroke")
	focusRing.Color = UI.Theme:get("accent")
	focusRing.Thickness = 2
	focusRing.Transparency = 1
	focusRing.Parent = card

	card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			Core.SoundSystem.play("hover")
		end
	end)

	-- Card content
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -24, 1, -24)
	content.Position = UDim2.fromOffset(12, 12)
	content.Parent = card

	-- Image container with aspect ratio
	local imageContainer = Instance.new("Frame")
	imageContainer.Size = UDim2.new(1, 0, 0, 140)
	imageContainer.BackgroundColor3 = UI.Theme:get("surfaceAlt")
	imageContainer.Parent = content

	local imageCorner = Instance.new("UICorner")
	imageCorner.CornerRadius = UDim.new(0, UI.Tokens.radius.small)
	imageCorner.Parent = imageContainer

	-- Aspect ratio constraint
	local aspectRatio = Instance.new("UIAspectRatioConstraint")
	aspectRatio.AspectRatio = Core.CONSTANTS.CARD_ASPECT_RATIO
	aspectRatio.Parent = imageContainer

	-- Skeleton loading for image
	local skeleton = UI.Components.Skeleton({
		size = UDim2.fromScale(1, 1),
		cornerRadius = UDim.new(0, UI.Tokens.radius.small),
		parent = imageContainer
	}):render()

	local image = UI.Components.Image({
		Image = product.icon or "rbxassetid://0",
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		parent = imageContainer
	}):render()

	-- Fade in animation when loaded
	image.ImageRectOffset = Vector2.new(0, 0)
	image.ImageRectSize = Vector2.new(0, 0)

	local function onImageLoaded()
		skeleton:Destroy()
		Core.Animation.tween(image, {ImageTransparency = 0}, Core.CONSTANTS.ANIM_MEDIUM)
	end

	if image.Image ~= "rbxassetid://0" then
		local success = pcall(function()
			image.ImageRectSize = Vector2.new(1, 1)
		end)
		if success then
			onImageLoaded()
		end
	end

	-- Product info
	local info = Instance.new("Frame")
	info.BackgroundTransparency = 1
	info.Size = UDim2.new(1, 0, 1, -160)
	info.Position = UDim2.fromOffset(0, 160)
	info.Parent = content

	UI.Components.TextLabel({
		Text = product.name,
		Size = UDim2.new(1, 0, 0, 28),
		Font = Enum.Font.GothamBold,
		TextSize = UI.Tokens.typography.body,
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = info
	}):render()

	local description = isGamepass and product.description or ("Includes " .. Core.Utils.formatNumber(product.amount) .. " Cash")
	UI.Components.TextLabel({
		Text = description,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 32),
		Font = Enum.Font.Gotham,
		TextSize = UI.Tokens.typography.caption,
		TextColor3 = UI.Theme:get("textSecondary"),
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = info
	}):render()

	-- Price badge
	local priceText = isGamepass and ("R$" .. tostring(product.price or 0)) or "Tap to purchase"
	local priceBadge = UI.Components.Frame({
		Size = UDim2.fromOffset(80, 24),
		Position = UDim2.new(1, -84, 0, 76),
		BackgroundColor3 = cardColor,
		cornerRadius = UDim.new(0, UI.Tokens.radius.small),
		parent = info
	}):render()

	UI.Components.TextLabel({
		Text = priceText,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = UI.Tokens.typography.small,
		TextColor3 = Color3.new(1, 1, 1),
		parent = priceBadge
	}):render()

	-- Purchase button
	local owned = isGamepass and Core.DataManager.checkOwnership(product.id)
	local button = UI.Components.Button({
		Text = owned and "Owned" or "Purchase",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 1, -40),
		BackgroundColor3 = owned and UI.Theme:get("success") or cardColor,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = UI.Tokens.typography.body,
		cornerRadius = UDim.new(0, UI.Tokens.radius.small),
		parent = info
	}):render()

	button.Active = not owned

	-- Store references for navigation
	table.insert(self.cardRefs, {card = card, button = button, focusRing = focusRing})

	button.MouseButton1Click:Connect(function()
		if not button or not button.Parent then return end
		if isGamepass then
			if Core.DataManager.checkOwnership(product.id) then return end
			self:promptPurchase(product, "gamepass", button)
		else
			self:promptPurchase(product, "cash", button)
		end
	end)

	-- Toggle switch for owned gamepasses
	if isGamepass and product.hasToggle and owned then
		self:addToggleSwitch(product, imageContainer)
	end

	product.cardInstance = card
	product.purchaseButton = button
end

function Shop:addToggleSwitch(product, imageContainer)
	local container = Instance.new("Frame")
	container.Name = "ToggleContainer"
	container.Size = UDim2.fromOffset(56, 28)
	container.Position = UDim2.new(1, -64, 0, 8)
	container.BackgroundColor3 = UI.Theme:get("stroke")
	container.BorderSizePixel = 0
	container.ZIndex = 2
	container.Parent = imageContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = container

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.fromOffset(24, 24)
	knob.Position = UDim2.fromOffset(2, 2)
	knob.BackgroundColor3 = UI.Theme:get("surface")
	knob.BorderSizePixel = 0
	knob.Parent = container

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(0.5, 0)
	knobCorner.Parent = knob

	local clickButton = Instance.new("TextButton")
	clickButton.BackgroundTransparency = 1
	clickButton.Text = ""
	clickButton.Size = UDim2.fromScale(1, 1)
	clickButton.Parent = container

	local state = false
	if Remotes then
		local remoteFunction = Remotes:FindFirstChild("GetAutoCollectState")
		if remoteFunction and remoteFunction:IsA("RemoteFunction") then
			local success, value = pcall(function() return remoteFunction:InvokeServer() end)
			if success and type(value) == "boolean" then
				state = value
			end
		end
	end

	local function render()
		if state then
			container.BackgroundColor3 = UI.Theme:get("success")
			Core.Animation.tween(knob, {Position = UDim2.fromOffset(30, 2)}, Core.CONSTANTS.ANIM_FAST)
		else
			container.BackgroundColor3 = UI.Theme:get("stroke")
			Core.Animation.tween(knob, {Position = UDim2.fromOffset(2, 2)}, Core.CONSTANTS.ANIM_FAST)
		end
	end

	render()

	clickButton.MouseButton1Click:Connect(function()
		state = not state
		render()
		if Remotes then
			local remoteEvent = Remotes:FindFirstChild("AutoCollectToggle")
			if remoteEvent and remoteEvent:IsA("RemoteEvent") then
				remoteEvent:FireServer(state)
			end
		end
		Core.SoundSystem.play("click")
	end)
end

function Shop:selectTab(tabId)
	if self.currentTab == tabId and self.pages[tabId] and self.pages[tabId].Visible then return end

	for id, tab in pairs(self.tabs) do
		local active = (id == tabId)
		local tabData = tab.data

		Core.Animation.tween(tab.button, {
			BackgroundColor3 = active and Core.Utils.blend(tabData.color, Color3.new(1, 1, 1), 0.9) or UI.Theme:get("surface")
		}, Core.CONSTANTS.ANIM_FAST)

		local stroke = tab.button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = active and tabData.color or UI.Theme:get("stroke")
		end

		tab.icon.ImageColor3 = active and tabData.color or UI.Theme:get("text")
		tab.label.TextColor3 = active and tabData.color or UI.Theme:get("text")
	end

	for id, page in pairs(self.pages) do
		page.Visible = (id == tabId)
		if page.Visible then
			page.Position = UDim2.fromOffset(0, 20)
			Core.Animation.tween(page, {Position = UDim2.new()}, Core.CONSTANTS.ANIM_BOUNCE, Enum.EasingStyle.Back)
		end
	end

	self.currentTab = tabId
	Core.SoundSystem.play("click")
end

function Shop:promptPurchase(product, kind, button)
	Core.State.purchasePending[product.id] = { product = product, type = kind, button = button }

	-- Show loading state
	button.Text = "Processing..."
	button.Active = false

	local success, errorMessage
	if kind == "gamepass" then
		success = pcall(function() MarketplaceService:PromptGamePassPurchase(Player, product.id) end)
	else
		success = pcall(function() MarketplaceService:PromptProductPurchase(Player, product.id) end)
	end

	if not success then
		if button and button.Parent then
			button.Text = "Purchase"
			button.Active = true
		end
		Core.State.purchasePending[product.id] = nil
		Core.SoundSystem.play("error")
		warn("[SanrioShop] Purchase prompt failed:", errorMessage)
		self:showBanner("Purchase Failed", "Please try again.", "error")
	else
		-- Set timeout for purchase completion
		task.delay(Core.CONSTANTS.PURCHASE_TIMEOUT, function()
			local pending = Core.State.purchasePending[product.id]
			if pending and pending.button and pending.button.Parent then
				pending.button.Text = "Purchase"
				pending.button.Active = true
			end
			Core.State.purchasePending[product.id] = nil
		end)
	end
end

function Shop:showBanner(title, message, type)
	local banner = UI.Components.Frame({
		Size = UDim2.fromOffset(300, 60),
		Position = UDim2.fromScale(0.5, 0.1),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = type == "success" and UI.Theme:get("success") or
						  type == "error" and Color3.fromRGB(220, 53, 69) or
						  UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, UI.Tokens.radius.medium),
		stroke = {color = UI.Theme:get("stroke"), thickness = 1},
		parent = self.gui
	}):render()

	UI.Components.TextLabel({
		Text = title,
		Size = UDim2.new(1, 0, 0, 30),
		Font = Enum.Font.GothamBold,
		TextSize = UI.Tokens.typography.body,
		TextColor3 = Color3.new(1, 1, 1),
		parent = banner
	}):render()

	UI.Components.TextLabel({
		Text = message,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 30),
		Font = Enum.Font.Gotham,
		TextSize = UI.Tokens.typography.caption,
		TextColor3 = Color3.new(1, 1, 1),
		parent = banner
	}):render()

	Core.Animation.tween(banner, {BackgroundTransparency = 1}, 0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
	task.delay(3, function() if banner.Parent then banner:Destroy() end end)
end

function Shop:refreshAllProducts()
	ownershipCache:clear()

	for _, gamepass in ipairs(Core.DataManager.products.gamepasses) do
		local owned = Core.DataManager.checkOwnership(gamepass.id)
		if gamepass.purchaseButton then
			gamepass.purchaseButton.Text = owned and "Owned" or "Purchase"
			gamepass.purchaseButton.BackgroundColor3 = owned and UI.Theme:get("success") or UI.Theme:get("kuromi")
			gamepass.purchaseButton.Active = not owned
		end
	end
end

function Shop:open()
	if Core.State.isOpen or Core.State.isAnimating then return end

	Core.State.isAnimating = true
	Core.State.isOpen = true

	Core.DataManager.refreshPrices()
	self:refreshAllProducts()
	self.gui.Enabled = true

	Core.Animation.tween(self.blur, {Size = 12}, Core.CONSTANTS.ANIM_MEDIUM)

	local panelSize = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE_DESKTOP
	self.mainPanel.Position = UDim2.fromScale(0.5, 0.55)
	self.mainPanel.Size = UDim2.fromOffset(panelSize.X * 0.92, panelSize.Y * 0.92)

	Core.Animation.tween(self.mainPanel, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(panelSize.X, panelSize.Y)
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

	Core.Animation.tween(self.blur, {Size = 0}, Core.CONSTANTS.ANIM_FAST)
	Core.Animation.tween(self.mainPanel, {
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(self.mainPanel.Size.X.Offset * 0.92, self.mainPanel.Size.Y.Offset * 0.92)
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

function Shop:setupInputHandlers()
	local inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.M then
			self:toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and Core.State.isOpen then
			self:close()
		elseif input.KeyCode == Enum.KeyCode.Tab and Core.State.isOpen then
			-- Handle tab navigation for accessibility
			input.Handled = true
		end
	end)

	table.insert(self.connections, inputBeganConnection)
end

function Shop:setupConnections()
	-- Purchase completion callbacks
	local gamepassConnection = MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if player ~= Player then return end

		local pending = Core.State.purchasePending[passId]
		if pending and pending.button and pending.button.Parent then
			pending.button.Text = "Purchase"
			pending.button.Active = true
		end

		Core.State.purchasePending[passId] = nil

		if purchased then
			ownershipCache:clear()
			self:refreshAllProducts()
			Core.SoundSystem.play("success")
			self:showBanner("Purchase Successful!", "Thank you for your purchase.", "success")
		else
			self:showBanner("Purchase Cancelled", "No charges were made.", "neutral")
		end
	end)

	local productConnection = MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, purchased)
		if player ~= Player then return end

		local pending = Core.State.purchasePending[productId]
		if pending and pending.button and pending.button.Parent then
			pending.button.Text = "Purchase"
			pending.button.Active = true
		end

		Core.State.purchasePending[productId] = nil

		if purchased then
			Core.SoundSystem.play("success")
			self:showBanner("Purchase Successful!", "Your cash has been added.", "success")

			-- Grant currency server-side
			if Remotes then
				local grantRemote = Remotes:FindFirstChild("GrantProductCurrency")
				if grantRemote and grantRemote:IsA("RemoteEvent") then
					grantRemote:FireServer(productId)
				end
			end
		else
			self:showBanner("Purchase Cancelled", "No charges were made.", "neutral")
		end
	end)

	table.insert(self.connections, gamepassConnection)
	table.insert(self.connections, productConnection)

	-- Character respawn handling
	local characterConnection = Player.CharacterAdded:Connect(function()
		task.wait(1)
		if not self.toggleButton or not self.toggleButton.Parent then
			self:createToggleButton()
		end
	end)

	table.insert(self.connections, characterConnection)

	-- Periodic refresh
	local refreshConnection
	refreshConnection = RunService.Heartbeat:Connect(function()
		if Core.State.isOpen then
			-- Throttle refresh to every 30 seconds
			if not self.lastRefresh or tick() - self.lastRefresh > 30 then
				self:refreshAllProducts()
				self.lastRefresh = tick()
			end
		end
	end)

	table.insert(self.connections, refreshConnection)
end

function Shop:cleanup()
	-- Disconnect all connections
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}

	-- Clean up GUI elements
	if self.gui then self.gui:Destroy() end
	if self.toggleButton then self.toggleButton:Destroy() end
	if self.blur then self.blur:Destroy() end

	-- Clear caches
	productCache:clear()
	ownershipCache:clear()
end

-- ========================================
-- INITIALIZATION
-- ========================================
Core.SoundSystem.initialize()
local shop = Shop.new()

-- Auto-cleanup on player leaving
Player.Destroying:Connect(function()
	shop:cleanup()
end)

-- Periodic cleanup while running
task.spawn(function()
	while true do
		task.wait(60) -- Cleanup every minute
		if #shop.connections > 10 then -- If we have too many connections
			shop:cleanup()
			shop = Shop.new()
		end
	end
end)

print("[SanrioShop] Polished shop system initialized successfully!")
return shop