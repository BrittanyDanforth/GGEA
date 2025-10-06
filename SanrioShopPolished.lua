--[[
  SANRIO SHOP SYSTEM - POLISHED & RESPONSIVE
  Location: StarterPlayer > StarterPlayerScripts
  Script name: SanrioShop
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
local HapticService = game:GetService("HapticService")
local ContextActionService = game:GetService("ContextActionService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:FindFirstChild("TycoonRemotes")

-- ========================================
-- CORE
-- ========================================
local Core = {}

Core.CONSTANTS = {
	-- Layout
	MIN_CARD_WIDTH = 300,
	MAX_CARD_WIDTH = 560,
	CARD_ASPECT_RATIO = 16/9,
	GUTTER_DESKTOP = 24,
	GUTTER_MOBILE = 18,
	
	-- Design tokens
	RADIUS = {small = 10, medium = 16, large = 24},
	ELEVATION = {z1 = 0.06, z2 = 0.12},
	SPACING = {xs = 8, sm = 12, md = 16, lg = 24},
	TYPOGRAPHY = {h1 = 32, h2 = 24, body = 16, small = 14, tiny = 12},
	
	-- Animation
	ANIM_FAST = 0.12,
	ANIM_MEDIUM = 0.18,
	ANIM_BOUNCE = 0.24,
	SCALE_HOVER = 1.02,
	
	-- Cache & Timeouts
	CACHE_PRODUCT_INFO = 300,
	CACHE_OWNERSHIP = 60,
	PURCHASE_TIMEOUT = 15,
	DEBOUNCE_PURCHASE = 15,
	THROTTLE_GRID = 0.1,
}

Core.State = {
	isOpen = false,
	isAnimating = false,
	purchasePending = {},
	purchaseDebounce = {},
	settings = { 
		soundEnabled = true, 
		animationsEnabled = true,
		reducedMotion = false,
		haptics = true
	},
	currentFocus = nil,
	gridCards = {},
	connections = {},
}

-- Cache implementation
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
	if not entry then return end
	if tick() - entry.timestamp > self.duration then 
		self.data[key] = nil 
		return 
	end
	return entry.value 
end
function Cache:clear(key) 
	if key then 
		self.data[key] = nil 
	else 
		self.data = {} 
	end 
end

local productCache = Cache.new(Core.CONSTANTS.CACHE_PRODUCT_INFO)
local ownershipCache = Cache.new(Core.CONSTANTS.CACHE_OWNERSHIP)

-- Utils
Core.Utils = {}
function Core.Utils.isMobile()
	local camera = workspace.CurrentCamera
	if not camera then return false end
	local viewport = camera.ViewportSize
	return viewport.X < 1024 or GuiService:IsTenFootInterface()
end

function Core.Utils.getSafeArea()
	local insets = GuiService:GetSafeZoneInsets()
	return {
		top = insets.Top.Y,
		bottom = insets.Bottom.Y,
		left = insets.Left.X,
		right = insets.Right.X
	}
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

function Core.Utils.disconnect(connection)
	if connection and typeof(connection) == "RBXScriptConnection" then
		connection:Disconnect()
	end
end

function Core.Utils.disconnectAll(connections)
	for _, conn in pairs(connections) do
		Core.Utils.disconnect(conn)
	end
	table.clear(connections)
end

-- Animation system
Core.Animation = {}
function Core.Animation.tween(instance, props, duration, style, direction, callback)
	if not instance or not instance.Parent then return end
	
	if not Core.State.settings.animationsEnabled or Core.State.settings.reducedMotion then 
		for k, v in pairs(props) do 
			pcall(function() instance[k] = v end)
		end
		if callback then callback() end
		return 
	end
	
	local tweenInfo = TweenInfo.new(
		duration or Core.CONSTANTS.ANIM_MEDIUM,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out
	)
	
	local tween = TweenService:Create(instance, tweenInfo, props)
	if callback then
		tween.Completed:Connect(callback)
	end
	tween:Play()
	return tween
end

-- Sound system
Core.SoundSystem = {sounds = {}}
function Core.SoundSystem.initialize()
	local config = {
		click = {"rbxassetid://876939830", 0.35},
		hover = {"rbxassetid://10066936758", 0.15},
		open = {"rbxassetid://452267918", 0.4},
		close = {"rbxassetid://452267918", 0.4},
		success = {"rbxassetid://876939830", 0.5},
		error = {"rbxassetid://876939830", 0.4},
		tab = {"rbxassetid://876939830", 0.25}
	}
	
	local preloadList = {}
	for name, data in pairs(config) do
		local sound = Instance.new("Sound")
		sound.Name = "SanrioShop_" .. name
		sound.SoundId = data[1]
		sound.Volume = data[2]
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.Parent = SoundService
		Core.SoundSystem.sounds[name] = sound
		table.insert(preloadList, sound)
	end
	
	task.spawn(function() 
		pcall(function() ContentProvider:PreloadAsync(preloadList) end) 
	end)
end

function Core.SoundSystem.play(name) 
	if Core.State.settings.soundEnabled and Core.SoundSystem.sounds[name] then 
		Core.SoundSystem.sounds[name]:Play() 
	end 
end

-- Haptics
Core.Haptics = {}
function Core.Haptics.tap()
	if Core.State.settings.haptics and HapticService:IsSupported(Enum.UserInputType.Gamepad1) then
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0.1)
		task.wait(0.05)
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
	end
end

-- Data Manager
Core.DataManager = {}
Core.DataManager.products = {
	cash = {
		{ id = 3366419712, amount = 1000,  name = "1,000 Cash",  benefit = "Jump-start your empire", icon = "rbxassetid://10709728059", price = 0, tag = nil },
		{ id = 3366420012, amount = 5000,  name = "5,000 Cash",  benefit = "Accelerate expansion", icon = "rbxassetid://10709728059", price = 0, tag = nil },
		{ id = 3366420478, amount = 10000, name = "10,000 Cash", benefit = "Premium growth pack", icon = "rbxassetid://10709728059", price = 0, tag = "POPULAR" },
		{ id = 3366420800, amount = 25000, name = "25,000 Cash", benefit = "Ultimate value bundle", icon = "rbxassetid://10709728059", price = 0, tag = "BEST VALUE" },
	},
	gamepasses = {
		{ id = 1412171840, name = "Auto Collect", benefit = "Never miss a drop", icon = "rbxassetid://10709727148", price = 99, hasToggle = true },
		{ id = 1398974710, name = "2x Cash", benefit = "Double all earnings", icon = "rbxassetid://10709727148", price = 199, hasToggle = false, tag = "ESSENTIAL" },
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
			glass = Color3.fromRGB(255, 255, 255),
			stroke = Color3.fromRGB(222, 226, 235),
			strokeLight = Color3.fromRGB(240, 242, 246),
			text = Color3.fromRGB(35, 38, 46),
			textSecondary = Color3.fromRGB(120, 126, 140),
			accent = Color3.fromRGB(255, 64, 129),
			success = Color3.fromRGB(76, 175, 80),
			error = Color3.fromRGB(239, 83, 80),
			warning = Color3.fromRGB(255, 167, 38),
			cinna = Color3.fromRGB(186, 214, 255),
			kuromi = Color3.fromRGB(200, 190, 255),
			focus = Color3.fromRGB(66, 133, 244),
			shimmer = Color3.fromRGB(245, 245, 245),
		},
		dark = {
			background = Color3.fromRGB(18, 20, 24),
			surface = Color3.fromRGB(26, 28, 34),
			surfaceAlt = Color3.fromRGB(34, 36, 44),
			glass = Color3.fromRGB(30, 32, 38),
			stroke = Color3.fromRGB(48, 52, 62),
			strokeLight = Color3.fromRGB(38, 42, 50),
			text = Color3.fromRGB(255, 255, 255),
			textSecondary = Color3.fromRGB(180, 186, 200),
			accent = Color3.fromRGB(255, 64, 129),
			success = Color3.fromRGB(76, 175, 80),
			error = Color3.fromRGB(239, 83, 80),
			warning = Color3.fromRGB(255, 167, 38),
			cinna = Color3.fromRGB(186, 214, 255),
			kuromi = Color3.fromRGB(200, 190, 255),
			focus = Color3.fromRGB(66, 133, 244),
			shimmer = Color3.fromRGB(45, 47, 55),
		}
	}
}

function UI.Theme:get(key) 
	return self.themes[self.current][key] 
end

function UI.Theme:switch(theme)
	if self.themes[theme] then
		self.current = theme
		-- Trigger UI repaint here if needed
	end
end

-- Component system
local Component = {}
Component.__index = Component

function Component.new(className, props) 
	return setmetatable({
		instance = Instance.new(className), 
		props = props or {},
		connections = {}
	}, Component) 
end

function Component:render()
	for key, value in pairs(self.props) do
		if key ~= "children" and key ~= "parent" and key ~= "onClick" and 
		   key ~= "cornerRadius" and key ~= "stroke" and key ~= "layout" and 
		   key ~= "padding" and key ~= "aspectRatio" and key ~= "scale" then 
			pcall(function() self.instance[key] = value end) 
		end
	end
	
	if self.props.cornerRadius then 
		local corner = Instance.new("UICorner")
		corner.CornerRadius = self.props.cornerRadius
		corner.Parent = self.instance
	end
	
	if self.props.stroke then 
		local stroke = Instance.new("UIStroke")
		stroke.Color = self.props.stroke.color or UI.Theme:get("stroke")
		stroke.Thickness = self.props.stroke.thickness or 1
		stroke.Transparency = self.props.stroke.transparency or 0
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = self.instance
	end
	
	if self.props.aspectRatio then
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = self.props.aspectRatio
		aspect.Parent = self.instance
	end
	
	if self.props.scale then
		local scale = Instance.new("UIScale")
		scale.Scale = self.props.scale
		scale.Parent = self.instance
	end
	
	if self.props.parent then 
		self.instance.Parent = self.props.parent 
	end
	
	-- Cleanup on removal
	local conn = self.instance.AncestryChanged:Connect(function()
		if not self.instance.Parent then
			self:destroy()
		end
	end)
	table.insert(self.connections, conn)
	
	return self.instance
end

function Component:destroy()
	Core.Utils.disconnectAll(self.connections)
	if self.instance then
		self.instance:Destroy()
	end
end

UI.Components = {}

function UI.Components.Frame(props)
	local defaults = { 
		BackgroundColor3 = UI.Theme:get("surface"), 
		BorderSizePixel = 0, 
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = props.clips or false
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
		
		-- Auto-update scrolling canvas size
		local function updateCanvas()
			if instance.Parent and instance.Parent:IsA("ScrollingFrame") then
				local scrollFrame = instance.Parent
				if layoutType == "List" then
					if scrollFrame.ScrollingDirection == Enum.ScrollingDirection.X then
						scrollFrame.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X + 20, 0, 0)
					else
						scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
					end
				else
					scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
				end
			end
		end
		
		local conn = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
		table.insert(Core.State.connections, conn)
		task.defer(updateCanvas)
	end
	
	if props.padding then
		local padding = Instance.new("UIPadding")
		if props.padding.top then padding.PaddingTop = props.padding.top end
		if props.padding.bottom then padding.PaddingBottom = props.padding.bottom end
		if props.padding.left then padding.PaddingLeft = props.padding.left end
		if props.padding.right then padding.PaddingRight = props.padding.right end
		padding.Parent = instance
	end
	
	return { instance = instance, component = component }
end

function UI.Components.TextLabel(props)
	local defaults = { 
		BackgroundTransparency = 1, 
		TextColor3 = UI.Theme:get("text"), 
		Font = Enum.Font.Gotham, 
		TextWrapped = true,
		TextScaled = false,
		TextTruncate = props.truncate or Enum.TextTruncate.None
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
		Size = UDim2.fromOffset(120, 44),
		AutoButtonColor = false,
		TextScaled = false
	}
	
	for k, v in pairs(defaults) do 
		if props[k] == nil then props[k] = v end 
	end
	
	local component = Component.new("TextButton", props)
	local instance = component:render()
	
	-- Scale animation on hover
	local scaleInstance = Instance.new("UIScale")
	scaleInstance.Scale = 1
	scaleInstance.Parent = instance
	
	local mouseEnterConn = instance.MouseEnter:Connect(function()
		Core.SoundSystem.play("hover")
		Core.Haptics.tap()
		Core.Animation.tween(scaleInstance, {Scale = Core.CONSTANTS.SCALE_HOVER}, Core.CONSTANTS.ANIM_FAST)
	end)
	
	local mouseLeaveConn = instance.MouseLeave:Connect(function() 
		Core.Animation.tween(scaleInstance, {Scale = 1}, Core.CONSTANTS.ANIM_FAST) 
	end)
	
	table.insert(component.connections, mouseEnterConn)
	table.insert(component.connections, mouseLeaveConn)
	
	if props.onClick then 
		local clickConn = instance.MouseButton1Click:Connect(function()
			Core.SoundSystem.play("click")
			Core.Haptics.tap()
			props.onClick()
		end)
		table.insert(component.connections, clickConn)
	end
	
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

function UI.Components.ScrollingFrame(props)
	local defaults = {
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UI.Theme:get("stroke"),
		ScrollBarImageTransparency = 0.5,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true
	}
	
	for k, v in pairs(defaults) do 
		if props[k] == nil then props[k] = v end 
	end
	
	return Component.new("ScrollingFrame", props)
end

function UI.Components.LoadingShimmer(props)
	local container = UI.Components.Frame({
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Theme:get("shimmer"),
		BackgroundTransparency = 0,
		cornerRadius = props.cornerRadius or UDim.new(0, 8),
		parent = props.parent
	}).instance
	
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.new(0.95, 0.95, 0.95)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))
	})
	gradient.Rotation = 45
	gradient.Parent = container
	
	-- Animate shimmer
	local shimmerTween
	local function startShimmer()
		gradient.Offset = Vector2.new(-1, 0)
		shimmerTween = Core.Animation.tween(
			gradient, 
			{Offset = Vector2.new(1, 0)}, 
			1.5, 
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.InOut,
			function()
				if container.Parent then
					startShimmer()
				end
			end
		)
	end
	
	startShimmer()
	
	return {
		instance = container,
		stop = function()
			if shimmerTween then
				shimmerTween:Cancel()
			end
		end
	}
end

function UI.Components.Pill(props)
	local pill = UI.Components.Frame({
		Size = props.Size or UDim2.fromOffset(80, 24),
		BackgroundColor3 = props.color or UI.Theme:get("accent"),
		BackgroundTransparency = props.transparency or 0.1,
		cornerRadius = UDim.new(0.5, 0),
		parent = props.parent
	}).instance
	
	UI.Components.TextLabel({
		Text = props.text,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = Core.CONSTANTS.TYPOGRAPHY.tiny,
		TextColor3 = props.textColor or props.color or UI.Theme:get("accent"),
		parent = pill
	}):render()
	
	return pill
end

function UI.Components.Banner(props)
	local banner = UI.Components.Frame({
		Size = UDim2.new(1, -48, 0, 56),
		Position = UDim2.fromOffset(24, -80),
		BackgroundColor3 = props.color or UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, 12),
		stroke = {color = props.strokeColor or props.color, thickness = 1, transparency = 0.8},
		parent = props.parent
	}).instance
	
	local icon = UI.Components.TextLabel({
		Text = props.icon or "✓",
		Size = UDim2.fromOffset(40, 56),
		Position = UDim2.fromOffset(0, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		TextColor3 = props.iconColor or props.color,
		parent = banner
	}):render()
	
	local message = UI.Components.TextLabel({
		Text = props.message,
		Size = UDim2.new(1, -100, 1, 0),
		Position = UDim2.fromOffset(40, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = Core.CONSTANTS.TYPOGRAPHY.small,
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = banner
	}):render()
	
	if props.action then
		local actionBtn = UI.Components.Button({
			Text = props.actionText or "Retry",
			Size = UDim2.fromOffset(60, 32),
			Position = UDim2.new(1, -12, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = props.color,
			cornerRadius = UDim.new(0, 6),
			Font = Enum.Font.GothamBold,
			TextSize = Core.CONSTANTS.TYPOGRAPHY.tiny,
			onClick = props.action,
			parent = banner
		}):render()
	end
	
	-- Animate in
	Core.Animation.tween(banner, {Position = UDim2.fromOffset(24, 24)}, Core.CONSTANTS.ANIM_BOUNCE, Enum.EasingStyle.Back)
	
	-- Auto-dismiss after delay
	if props.duration then
		task.wait(props.duration)
		Core.Animation.tween(banner, {Position = UDim2.fromOffset(24, -80)}, Core.CONSTANTS.ANIM_FAST, nil, nil, function()
			banner:Destroy()
		end)
	end
	
	return banner
end

-- ========================================
-- SHOP IMPLEMENTATION
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
	self.gridThrottle = 0
	self.focusController = nil
	
	self:initialize()
	return self
end

function Shop:initialize()
	Core.SoundSystem.initialize()
	Core.DataManager.refreshPrices()
	self:preloadAssets()
	self:createToggleButton()
	self:createMainInterface()
	self:setupInputHandlers()
	self:setupControllerSupport()
end

function Shop:preloadAssets()
	local assetIds = {
		"rbxassetid://17398522865",
		"rbxassetid://10709728059",
		"rbxassetid://10709727148"
	}
	
	for _, product in ipairs(Core.DataManager.products.cash) do
		if product.icon then table.insert(assetIds, product.icon) end
	end
	
	for _, product in ipairs(Core.DataManager.products.gamepasses) do
		if product.icon then table.insert(assetIds, product.icon) end
	end
	
	task.spawn(function() 
		pcall(function() ContentProvider:PreloadAsync(assetIds) end) 
	end)
end

function Shop:createToggleButton()
	local screenGui = PlayerGui:FindFirstChild("SanrioShopToggle") or Instance.new("ScreenGui")
	screenGui.Name = "SanrioShopToggle"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 999
	screenGui.Parent = PlayerGui
	
	local safeArea = Core.Utils.getSafeArea()
	
	self.toggleButton = UI.Components.Button({
		Text = "",
		Size = UDim2.fromOffset(180, 60),
		Position = UDim2.new(1, -(20 + safeArea.right), 1, -(20 + safeArea.bottom)),
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
		TextSize = 20,
		parent = self.toggleButton
	}):render()
end

function Shop:createMainInterface()
	self.gui = PlayerGui:FindFirstChild("SanrioShopMain") or Instance.new("ScreenGui")
	self.gui.Name = "SanrioShopMain"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 1000
	self.gui.Enabled = false
	self.gui.Parent = PlayerGui
	
	self.blur = Lighting:FindFirstChild("SanrioShopBlur") or Instance.new("BlurEffect")
	self.blur.Name = "SanrioShopBlur"
	self.blur.Size = 0
	self.blur.Parent = Lighting
	
	-- Background dimmer
	local dimmer = UI.Components.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		parent = self.gui
	}).instance
	
	dimmer.Active = true
	local dimmerConn = dimmer.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:close()
		end
	end)
	table.insert(Core.State.connections, dimmerConn)
	
	-- Main panel with glass effect
	local safeArea = Core.Utils.getSafeArea()
	self.mainPanel = UI.Components.Frame({
		Size = UDim2.new(1, -(safeArea.left + safeArea.right + 40), 1, -(safeArea.top + safeArea.bottom + 40)),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UI.Theme:get("glass"),
		BackgroundTransparency = 0.02,
		cornerRadius = UDim.new(0, Core.CONSTANTS.RADIUS.large),
		stroke = {color = UI.Theme:get("strokeLight"), thickness = 1, transparency = 0.85},
		parent = self.gui
	}).instance
	
	-- Responsive constraints
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(1400, 900)
	sizeConstraint.MinSize = Vector2.new(600, 400)
	sizeConstraint.Parent = self.mainPanel
	
	-- Glass header
	local header = UI.Components.Frame({
		Size = UDim2.new(1, -48, 0, 80),
		Position = UDim2.fromOffset(24, 24),
		BackgroundColor3 = UI.Theme:get("glass"),
		BackgroundTransparency = 0.94,
		cornerRadius = UDim.new(0, Core.CONSTANTS.RADIUS.medium),
		stroke = {color = UI.Theme:get("strokeLight"), thickness = 1, transparency = 0.85},
		parent = self.mainPanel
	}).instance
	
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
		TextSize = Core.CONSTANTS.TYPOGRAPHY.h1,
		parent = header
	}):render()
	
	-- Settings button
	local settingsBtn = UI.Components.Button({
		Text = "⚙",
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.new(1, -116, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = UI.Theme:get("surfaceAlt"),
		TextColor3 = UI.Theme:get("text"),
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		cornerRadius = UDim.new(0.5, 0),
		parent = header,
		onClick = function() self:openSettings() end
	}):render()
	
	-- Close button
	UI.Components.Button({
		Text = "✕",
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.new(1, -64, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = UI.Theme:get("accent"),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		cornerRadius = UDim.new(0.5, 0),
		parent = header,
		onClick = function() self:close() end
	}):render()
	
	-- Tab container
	self.tabContainer = UI.Components.Frame({
		Size = UDim2.new(1, -48, 0, 48),
		Position = UDim2.fromOffset(24, 116),
		BackgroundTransparency = 1,
		parent = self.mainPanel,
		layout = {
			type = "List",
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Core.CONSTANTS.SPACING.sm),
			SortOrder = Enum.SortOrder.LayoutOrder
		}
	}).instance
	
	-- Create tabs
	local tabData = {
		{id = "Cash", name = "Cash", icon = "rbxassetid://10709728059", color = UI.Theme:get("cinna")},
		{id = "Gamepasses", name = "Passes", icon = "rbxassetid://10709727148", color = UI.Theme:get("kuromi")},
	}
	
	for i, data in ipairs(tabData) do
		local tab = UI.Components.Button({
			Text = "",
			Size = UDim2.fromOffset(160, 48),
			BackgroundColor3 = UI.Theme:get("surface"),
			cornerRadius = UDim.new(0.5, 0),
			stroke = {color = UI.Theme:get("stroke"), thickness = 1},
			LayoutOrder = i,
			parent = self.tabContainer,
			onClick = function() self:selectTab(data.id) end
		}):render()
		
		local content = UI.Components.Frame({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			parent = tab,
			layout = {
				type = "List",
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, Core.CONSTANTS.SPACING.xs),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center
			}
		}).instance
		
		local icon = UI.Components.Image({
			Image = data.icon,
			Size = UDim2.fromOffset(24, 24),
			LayoutOrder = 1,
			parent = content
		}):render()
		
		local label = UI.Components.TextLabel({
			Text = data.name,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Font = Enum.Font.GothamMedium,
			TextSize = Core.CONSTANTS.TYPOGRAPHY.body,
			LayoutOrder = 2,
			parent = content
		}):render()
		
		self.tabs[data.id] = {
			button = tab,
			data = data,
			icon = icon,
			label = label,
			stroke = tab:FindFirstChildOfClass("UIStroke")
		}
	end
	
	-- Content container
	self.contentContainer = UI.Components.Frame({
		Size = UDim2.new(1, -48, 1, -180),
		Position = UDim2.fromOffset(24, 176),
		BackgroundTransparency = 1,
		clips = true,
		parent = self.mainPanel
	}).instance
	
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
	}).instance
	
	local cashScroll = UI.Components.ScrollingFrame({
		Size = UDim2.fromScale(1, 1),
		parent = cashPage
	}):render()
	
	local cashGrid = self:createResponsiveGrid(cashScroll)
	
	for i, product in ipairs(Core.DataManager.products.cash) do
		self:createProductCard(product, "cash", cashGrid.container, i)
	end
	
	-- Gamepasses page
	local passPage = UI.Components.Frame({
		Name = "GamepassesPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		parent = self.contentContainer
	}).instance
	
	local passScroll = UI.Components.ScrollingFrame({
		Size = UDim2.fromScale(1, 1),
		parent = passPage
	}):render()
	
	local passGrid = self:createResponsiveGrid(passScroll)
	
	for i, gamepass in ipairs(Core.DataManager.products.gamepasses) do
		self:createProductCard(gamepass, "gamepass", passGrid.container, i + 10)
	end
	
	self.pages = {
		Cash = cashPage,
		Gamepasses = passPage
	}
end

function Shop:createResponsiveGrid(parent)
	local container = UI.Components.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		parent = parent,
		padding = {
			top = UDim.new(0, Core.CONSTANTS.SPACING.md),
			bottom = UDim.new(0, Core.CONSTANTS.SPACING.md),
			left = UDim.new(0, Core.CONSTANTS.SPACING.md),
			right = UDim.new(0, Core.CONSTANTS.SPACING.md)
		}
	}).instance
	
	local grid = Instance.new("UIGridLayout")
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Top
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = container
	
	-- Responsive grid calculation
	local function updateGrid()
		if tick() - self.gridThrottle < Core.CONSTANTS.THROTTLE_GRID then return end
		self.gridThrottle = tick()
		
		local containerWidth = container.AbsoluteSize.X
		local isMobile = Core.Utils.isMobile()
		local gutter = isMobile and Core.CONSTANTS.GUTTER_MOBILE or Core.CONSTANTS.GUTTER_DESKTOP
		
		-- Calculate columns: 3 for desktop, 2 for tablet, 1 for mobile
		local columns = 3
		if containerWidth < 800 then
			columns = 1
		elseif containerWidth < 1200 then
			columns = 2
		end
		
		-- Calculate card width with min/max constraints
		local availableWidth = containerWidth - (gutter * (columns - 1))
		local cardWidth = math.floor(availableWidth / columns)
		cardWidth = math.clamp(cardWidth, Core.CONSTANTS.MIN_CARD_WIDTH, Core.CONSTANTS.MAX_CARD_WIDTH)
		
		-- Set grid properties
		grid.CellPadding = UDim2.fromOffset(gutter, gutter)
		grid.CellSize = UDim2.fromOffset(cardWidth, cardWidth / Core.CONSTANTS.CARD_ASPECT_RATIO)
		
		-- Update canvas size
		parent.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 40)
	end
	
	local conn1 = container:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateGrid)
	local conn2 = grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		parent.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 40)
	end)
	
	table.insert(Core.State.connections, conn1)
	table.insert(Core.State.connections, conn2)
	
	task.defer(updateGrid)
	
	return {
		container = container,
		grid = grid,
		update = updateGrid
	}
end

function Shop:createProductCard(product, productType, parent, order)
	local isGamepass = productType == "gamepass"
	local cardColor = isGamepass and UI.Theme:get("kuromi") or UI.Theme:get("cinna")
	
	-- Card container
	local card = UI.Components.Frame({
		Name = product.name .. "Card",
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, Core.CONSTANTS.RADIUS.medium),
		stroke = {color = cardColor, thickness = 2, transparency = 0.5},
		clips = true,
		LayoutOrder = order,
		parent = parent
	}).instance
	
	-- Scale animation setup
	local scaleInstance = Instance.new("UIScale")
	scaleInstance.Scale = 1
	scaleInstance.Parent = card
	
	-- Focus ring for controller
	local focusRing = Instance.new("UIStroke")
	focusRing.Color = UI.Theme:get("focus")
	focusRing.Thickness = 3
	focusRing.Transparency = 1
	focusRing.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	focusRing.Parent = card
	
	-- Store card reference for navigation
	table.insert(Core.State.gridCards, {
		instance = card,
		product = product,
		type = productType,
		focusRing = focusRing,
		scale = scaleInstance
	})
	
	-- Image container with aspect ratio
	local imageContainer = UI.Components.Frame({
		Size = UDim2.new(1, 0, 0.6, 0),
		BackgroundColor3 = UI.Theme:get("surfaceAlt"),
		aspectRatio = Core.CONSTANTS.CARD_ASPECT_RATIO,
		parent = card
	}).instance
	
	-- Loading shimmer
	local shimmer = UI.Components.LoadingShimmer({
		Size = UDim2.fromScale(1, 1),
		cornerRadius = UDim.new(0, 0),
		parent = imageContainer
	})
	
	-- Product image
	local productImage = UI.Components.Image({
		Image = product.icon or "rbxassetid://0",
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		parent = imageContainer
	}):render()
	
	-- Hide shimmer when image loads
	productImage.ImageTransparency = 1
	task.spawn(function()
		task.wait(math.random() * 0.5 + 0.3) -- Simulate loading
		shimmer.stop()
		shimmer.instance:Destroy()
		Core.Animation.tween(productImage, {ImageTransparency = 0}, Core.CONSTANTS.ANIM_FAST)
	end)
	
	-- Price/Owned pill
	local pillText = "Loading..."
	local pillColor = UI.Theme:get("stroke")
	
	if isGamepass then
		local owned = Core.DataManager.checkOwnership(product.id)
		if owned then
			pillText = "OWNED"
			pillColor = UI.Theme:get("success")
		else
			pillText = product.price > 0 and ("R$" .. tostring(product.price)) or "FREE"
			pillColor = cardColor
		end
	else
		-- For cash products, fetch price
		task.spawn(function()
			local info = Core.DataManager.getProductInfo(product.id)
			if info and info.PriceInRobux then
				pillText = "R$" .. tostring(info.PriceInRobux)
			end
		end)
	end
	
	local pricePill = UI.Components.Pill({
		text = pillText,
		color = pillColor,
		Size = UDim2.fromOffset(80, 24),
		Position = UDim2.new(1, -12, 0, 12),
		AnchorPoint = Vector2.new(1, 0),
		parent = imageContainer
	})
	
	-- Tag badge (BEST VALUE, POPULAR, etc.)
	if product.tag then
		local tagPill = UI.Components.Pill({
			text = product.tag,
			color = UI.Theme:get("warning"),
			textColor = Color3.new(1, 1, 1),
			transparency = 0,
			Size = UDim2.fromOffset(100, 24),
			Position = UDim2.fromOffset(12, 12),
			parent = imageContainer
		})
	end
	
	-- Content area
	local content = UI.Components.Frame({
		Size = UDim2.new(1, -24, 0.4, -12),
		Position = UDim2.new(0, 12, 0.6, 0),
		BackgroundTransparency = 1,
		parent = card
	}).instance
	
	-- Product name (max 2 lines)
	local nameLabel = UI.Components.TextLabel({
		Text = product.name,
		Size = UDim2.new(1, 0, 0, 40),
		Font = Enum.Font.GothamBold,
		TextSize = Core.CONSTANTS.TYPOGRAPHY.body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		truncate = Enum.TextTruncate.AtEnd,
		parent = content
	}):render()
	
	-- Benefit text (1 line)
	local benefitLabel = UI.Components.TextLabel({
		Text = product.benefit or "",
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 44),
		Font = Enum.Font.Gotham,
		TextSize = Core.CONSTANTS.TYPOGRAPHY.small,
		TextColor3 = UI.Theme:get("textSecondary"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		truncate = Enum.TextTruncate.AtEnd,
		parent = content
	}):render()
	
	-- Purchase button
	local owned = isGamepass and Core.DataManager.checkOwnership(product.id)
	local purchaseButton = UI.Components.Button({
		Text = owned and "Owned" or "Purchase",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 1, -40),
		BackgroundColor3 = owned and UI.Theme:get("success") or cardColor,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = Core.CONSTANTS.TYPOGRAPHY.body,
		cornerRadius = UDim.new(0, Core.CONSTANTS.RADIUS.small),
		parent = content
	}):render()
	
	purchaseButton.Active = not owned
	
	-- Loading spinner for purchase
	local spinner = Instance.new("ImageLabel")
	spinner.Image = "rbxassetid://4835236874" -- Circular loading icon
	spinner.Size = UDim2.fromOffset(20, 20)
	spinner.Position = UDim2.new(0.5, -40, 0.5, 0)
	spinner.AnchorPoint = Vector2.new(0.5, 0.5)
	spinner.BackgroundTransparency = 1
	spinner.ImageTransparency = 1
	spinner.Parent = purchaseButton
	
	local spinnerRotation
	local function startSpinner()
		spinner.ImageTransparency = 0
		spinner.Rotation = 0
		spinnerRotation = RunService.Heartbeat:Connect(function()
			spinner.Rotation = spinner.Rotation + 5
		end)
	end
	
	local function stopSpinner()
		if spinnerRotation then
			spinnerRotation:Disconnect()
			spinnerRotation = nil
		end
		spinner.ImageTransparency = 1
	end
	
	-- Purchase handler
	local purchaseConn = purchaseButton.MouseButton1Click:Connect(function()
		if not purchaseButton.Active then return end
		
		-- Debounce check
		local now = tick()
		local lastPurchase = Core.State.purchaseDebounce[product.id] or 0
		if now - lastPurchase < Core.CONSTANTS.DEBOUNCE_PURCHASE then
			self:showBanner({
				message = "Please wait before trying again",
				color = UI.Theme:get("warning"),
				icon = "⏱",
				duration = 2
			})
			return
		end
		
		Core.State.purchaseDebounce[product.id] = now
		
		purchaseButton.Text = "Processing..."
		purchaseButton.Active = false
		startSpinner()
		
		self:promptPurchase(product, productType, purchaseButton, stopSpinner)
	end)
	
	table.insert(Core.State.connections, purchaseConn)
	
	-- Hover effects
	local mouseEnterConn = card.MouseEnter:Connect(function()
		if not Core.State.settings.animationsEnabled then return end
		Core.Animation.tween(scaleInstance, {Scale = Core.CONSTANTS.SCALE_HOVER}, Core.CONSTANTS.ANIM_FAST)
	end)
	
	local mouseLeaveConn = card.MouseLeave:Connect(function()
		Core.Animation.tween(scaleInstance, {Scale = 1}, Core.CONSTANTS.ANIM_FAST)
	end)
	
	table.insert(Core.State.connections, mouseEnterConn)
	table.insert(Core.State.connections, mouseLeaveConn)
	
	-- Auto-collect toggle for gamepasses
	if isGamepass and product.hasToggle and owned then
		self:addToggleSwitch(product, imageContainer)
	end
	
	-- Store references
	product.cardInstance = card
	product.purchaseButton = purchaseButton
	product.pricePill = pricePill
end

function Shop:addToggleSwitch(product, parent)
	local container = UI.Components.Frame({
		Size = UDim2.fromOffset(56, 28),
		Position = UDim2.new(1, -12, 1, -12),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = UI.Theme:get("stroke"),
		cornerRadius = UDim.new(0.5, 0),
		parent = parent
	}).instance
	
	local knob = UI.Components.Frame({
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0.5, 0),
		parent = container
	}).instance
	
	local clickArea = Instance.new("TextButton")
	clickArea.BackgroundTransparency = 1
	clickArea.Text = ""
	clickArea.Size = UDim2.fromScale(1, 1)
	clickArea.Parent = container
	
	local state = false
	
	-- Get initial state from server
	if Remotes then
		local getStateRemote = Remotes:FindFirstChild("GetAutoCollectState")
		if getStateRemote and getStateRemote:IsA("RemoteFunction") then
			local success, value = pcall(function() 
				return getStateRemote:InvokeServer() 
			end)
			if success and type(value) == "boolean" then
				state = value
			end
		end
	end
	
	local function updateToggle()
		if state then
			container.BackgroundColor3 = UI.Theme:get("success")
			Core.Animation.tween(knob, {Position = UDim2.fromOffset(30, 2)}, Core.CONSTANTS.ANIM_FAST)
		else
			container.BackgroundColor3 = UI.Theme:get("stroke")
			Core.Animation.tween(knob, {Position = UDim2.fromOffset(2, 2)}, Core.CONSTANTS.ANIM_FAST)
		end
	end
	
	updateToggle()
	
	local toggleConn = clickArea.MouseButton1Click:Connect(function()
		state = not state
		updateToggle()
		
		Core.SoundSystem.play("click")
		Core.Haptics.tap()
		
		if Remotes then
			local toggleRemote = Remotes:FindFirstChild("AutoCollectToggle")
			if toggleRemote and toggleRemote:IsA("RemoteEvent") then
				toggleRemote:FireServer(state)
			end
		end
	end)
	
	table.insert(Core.State.connections, toggleConn)
end

function Shop:selectTab(tabId)
	if self.currentTab == tabId then return end
	
	for id, tab in pairs(self.tabs) do
		local isActive = id == tabId
		local data = tab.data
		
		-- Animate tab appearance
		Core.Animation.tween(
			tab.button, 
			{BackgroundColor3 = isActive and Core.Utils.blend(data.color, Color3.new(1, 1, 1), 0.9) or UI.Theme:get("surface")}, 
			Core.CONSTANTS.ANIM_FAST
		)
		
		if tab.stroke then
			tab.stroke.Color = isActive and data.color or UI.Theme:get("stroke")
		end
		
		tab.icon.ImageColor3 = isActive and data.color or UI.Theme:get("text")
		tab.label.TextColor3 = isActive and data.color or UI.Theme:get("text")
	end
	
	-- Page transitions with fade + translate
	for id, page in pairs(self.pages) do
		if id == tabId then
			page.Visible = true
			page.Position = UDim2.fromOffset(0, 12)
			page.GroupTransparency = 1
			
			Core.Animation.tween(
				page, 
				{Position = UDim2.new(), GroupTransparency = 0}, 
				Core.CONSTANTS.ANIM_MEDIUM,
				Enum.EasingStyle.Back
			)
		else
			if page.Visible then
				Core.Animation.tween(
					page, 
					{Position = UDim2.fromOffset(0, -12), GroupTransparency = 1}, 
					Core.CONSTANTS.ANIM_FAST,
					nil,
					nil,
					function()
						page.Visible = false
					end
				)
			end
		end
	end
	
	self.currentTab = tabId
	Core.SoundSystem.play("tab")
	
	-- Reset grid cards for controller navigation
	Core.State.gridCards = {}
	task.wait(Core.CONSTANTS.ANIM_MEDIUM)
	
	-- Rebuild grid card references
	local currentPage = self.pages[tabId]
	if currentPage then
		local cards = currentPage:GetDescendants()
		for _, desc in ipairs(cards) do
			if desc.Name and desc.Name:match("Card$") then
				-- Re-add to grid cards
			end
		end
	end
end

function Shop:promptPurchase(product, type, button, callback)
	Core.State.purchasePending[product.id] = {
		product = product,
		type = type,
		button = button,
		callback = callback
	}
	
	local success, error
	if type == "gamepass" then
		success = pcall(function() 
			MarketplaceService:PromptGamePassPurchase(Player, product.id) 
		end)
	else
		success = pcall(function() 
			MarketplaceService:PromptProductPurchase(Player, product.id) 
		end)
	end
	
	if not success then
		if button and button.Parent then
			button.Text = "Purchase"
			button.Active = true
		end
		if callback then callback() end
		
		Core.State.purchasePending[product.id] = nil
		Core.SoundSystem.play("error")
		
		self:showBanner({
			message = "Failed to open purchase prompt",
			color = UI.Theme:get("error"),
			icon = "✕",
			duration = 3,
			action = function()
				self:promptPurchase(product, type, button, callback)
			end,
			actionText = "Retry"
		})
		
		warn("[SanrioShop] Purchase prompt failed:", error)
	else
		-- Timeout handler
		task.delay(Core.CONSTANTS.PURCHASE_TIMEOUT, function()
			local pending = Core.State.purchasePending[product.id]
			if pending and pending.button and pending.button.Parent then
				pending.button.Text = "Purchase"
				pending.button.Active = true
			end
			if pending and pending.callback then
				pending.callback()
			end
			Core.State.purchasePending[product.id] = nil
		end)
	end
end

function Shop:showBanner(props)
	UI.Components.Banner({
		message = props.message,
		color = props.color,
		icon = props.icon,
		iconColor = props.iconColor or props.color,
		duration = props.duration,
		action = props.action,
		actionText = props.actionText,
		parent = self.mainPanel
	})
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
		
		if gamepass.pricePill then
			gamepass.pricePill.Text = owned and "OWNED" or ("R$" .. tostring(gamepass.price))
			gamepass.pricePill.BackgroundColor3 = owned and UI.Theme:get("success") or UI.Theme:get("kuromi")
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
	
	-- Animate blur and panel
	Core.Animation.tween(self.blur, {Size = 12}, Core.CONSTANTS.ANIM_MEDIUM)
	
	self.mainPanel.Position = UDim2.fromScale(0.5, 0.55)
	self.mainPanel.Size = UDim2.new(
		self.mainPanel.Size.X.Scale * 0.95,
		self.mainPanel.Size.X.Offset * 0.95,
		self.mainPanel.Size.Y.Scale * 0.95,
		self.mainPanel.Size.Y.Offset * 0.95
	)
	
	Core.Animation.tween(
		self.mainPanel,
		{
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -80, 1, -80)
		},
		Core.CONSTANTS.ANIM_BOUNCE,
		Enum.EasingStyle.Back
	)
	
	self:selectTab(self.currentTab or "Cash")
	Core.SoundSystem.play("open")
	
	-- Restore focus
	if Core.State.currentFocus then
		GuiService.SelectedObject = Core.State.currentFocus
	end
	
	task.wait(Core.CONSTANTS.ANIM_BOUNCE)
	Core.State.isAnimating = false
end

function Shop:close()
	if not Core.State.isOpen or Core.State.isAnimating then return end
	
	Core.State.isAnimating = true
	Core.State.isOpen = false
	
	-- Save current focus
	Core.State.currentFocus = GuiService.SelectedObject
	
	Core.Animation.tween(self.blur, {Size = 0}, Core.CONSTANTS.ANIM_FAST)
	Core.Animation.tween(
		self.mainPanel,
		{
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.new(
				self.mainPanel.Size.X.Scale * 0.95,
				self.mainPanel.Size.X.Offset * 0.95,
				self.mainPanel.Size.Y.Scale * 0.95,
				self.mainPanel.Size.Y.Offset * 0.95
			)
		},
		Core.CONSTANTS.ANIM_FAST
	)
	
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

function Shop:openSettings()
	-- Settings implementation
	local settingsPanel = UI.Components.Frame({
		Size = UDim2.fromOffset(400, 300),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, Core.CONSTANTS.RADIUS.medium),
		stroke = {color = UI.Theme:get("stroke")},
		parent = self.gui
	}).instance
	
	-- Add settings options here
	-- Sound toggle, animations toggle, reduced motion, theme switch, etc.
end

function Shop:setupInputHandlers()
	local keyboardConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.M then
			self:toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and Core.State.isOpen then
			self:close()
		end
	end)
	
	table.insert(Core.State.connections, keyboardConn)
end

function Shop:setupControllerSupport()
	-- Controller navigation implementation
	local function onGamepadInput(actionName, inputState, inputObject)
		if inputState ~= Enum.UserInputState.Begin then return end
		
		if inputObject.KeyCode == Enum.KeyCode.ButtonX then
			self:toggle()
		elseif inputObject.KeyCode == Enum.KeyCode.ButtonB and Core.State.isOpen then
			self:close()
		end
	end
	
	ContextActionService:BindAction("SanrioShopToggle", onGamepadInput, false, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonB)
end

-- Initialize shop
Core.SoundSystem.initialize()
local shop = Shop.new()

-- Purchase callbacks
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if player ~= Player then return end
	
	local pending = Core.State.purchasePending[passId]
	if pending and pending.button and pending.button.Parent then
		pending.button.Text = "Purchase"
		pending.button.Active = true
	end
	if pending and pending.callback then
		pending.callback()
	end
	
	Core.State.purchasePending[passId] = nil
	
	if purchased then
		ownershipCache:clear()
		shop:refreshAllProducts()
		Core.SoundSystem.play("success")
		
		shop:showBanner({
			message = "Purchase successful!",
			color = UI.Theme:get("success"),
			icon = "✓",
			duration = 3
		})
		
		-- Confetti effect could go here
	else
		shop:showBanner({
			message = "Purchase cancelled",
			color = UI.Theme:get("stroke"),
			icon = "ℹ",
			duration = 2
		})
	end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, purchased)
	if player ~= Player then return end
	
	local pending = Core.State.purchasePending[productId]
	if pending and pending.button and pending.button.Parent then
		pending.button.Text = "Purchase"
		pending.button.Active = true
	end
	if pending and pending.callback then
		pending.callback()
	end
	
	Core.State.purchasePending[productId] = nil
	
	if purchased then
		Core.SoundSystem.play("success")
		
		shop:showBanner({
			message = "Purchase successful!",
			color = UI.Theme:get("success"),
			icon = "✓",
			duration = 3
		})
		
		-- Server handles currency grant via ProcessReceipt
	else
		shop:showBanner({
			message = "Purchase cancelled",
			color = UI.Theme:get("stroke"),
			icon = "ℹ",
			duration = 2
		})
	end
end)

-- Character respawn handler
Player.CharacterAdded:Connect(function()
	task.wait(1)
	if not shop.toggleButton or not shop.toggleButton.Parent then
		shop:createToggleButton()
	end
end)

-- Cleanup on leave
Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == Player then
		Core.Utils.disconnectAll(Core.State.connections)
	end
end)

-- Periodic refresh
task.spawn(function()
	while true do
		task.wait(30)
		if Core.State.isOpen then
			shop:refreshAllProducts()
		end
	end
end)

print("[SanrioShop] Initialized - Polished & Responsive")
return shop