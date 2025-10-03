--[[
    SANRIO SHOP SYSTEM - FIXED VERSION
    Place this as a LocalScript in StarterPlayer > StarterPlayerScripts
    Name it: SanrioShop
    
    This version fixes:
    1. Layout property error
    2. Sound asset loading
    3. Product visibility issues
--]]

-- Services
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)

-- ========================================
-- CORE MODULE (Embedded)
-- ========================================
local Core = {}

Core.VERSION = "3.0.0"
Core.DEBUG = false

-- Constants
Core.CONSTANTS = {
	PANEL_SIZE = Vector2.new(1140, 860),
	PANEL_SIZE_MOBILE = Vector2.new(920, 720),
	CARD_SIZE = Vector2.new(520, 300),
	CARD_SIZE_MOBILE = Vector2.new(480, 280),

	ANIM_FAST = 0.15,
	ANIM_MEDIUM = 0.25,
	ANIM_SLOW = 0.35,
	ANIM_BOUNCE = 0.3,
	ANIM_SMOOTH = 0.4,

	Z_BACKGROUND = 1,
	Z_CONTENT = 10,
	Z_OVERLAY = 20,
	Z_MODAL = 30,
	Z_TOOLTIP = 40,
	Z_NOTIFICATION = 50,

	CACHE_PRODUCT_INFO = 300,
	CACHE_OWNERSHIP = 60,

	PURCHASE_TIMEOUT = 15,
	RETRY_DELAY = 2,
	MAX_RETRIES = 3,
}

-- State Management
Core.State = {
	isOpen = false,
	isAnimating = false,
	currentTab = "Home",
	purchasePending = {},
	ownershipCache = {},
	productCache = {},
	initialized = false,
	settings = {
		animationsEnabled = true,
		reducedMotion = false,
		autoRefresh = true,
	}
}

-- Event System
Core.Events = {
	handlers = {},
}

function Core.Events:on(eventName, handler)
	if not self.handlers[eventName] then
		self.handlers[eventName] = {}
	end
	table.insert(self.handlers[eventName], handler)
	return function()
		local index = table.find(self.handlers[eventName], handler)
		if index then
			table.remove(self.handlers[eventName], index)
		end
	end
end

function Core.Events:emit(eventName, ...)
	if self.handlers[eventName] then
		for _, handler in ipairs(self.handlers[eventName]) do
			task.spawn(handler, ...)
		end
	end
end

-- Cache System
local Cache = {}
Cache.__index = Cache

function Cache.new(duration)
	return setmetatable({
		data = {},
		duration = duration or 300,
	}, Cache)
end

function Cache:set(key, value)
	self.data[key] = {
		value = value,
		timestamp = tick(),
	}
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
	if key then
		self.data[key] = nil
	else
		self.data = {}
	end
end

Core.Cache = Cache

-- Initialize caches
local productCache = Cache.new(Core.CONSTANTS.CACHE_PRODUCT_INFO)
local ownershipCache = Cache.new(Core.CONSTANTS.CACHE_OWNERSHIP)

-- Utility Functions
Core.Utils = {}

function Core.Utils.isMobile()
	local camera = workspace.CurrentCamera
	if not camera then return false end
	local viewportSize = camera.ViewportSize
	return viewportSize.X < 1024 or GuiService:IsTenFootInterface()
end

function Core.Utils.formatNumber(number)
	local formatted = tostring(number)
	local k = 1
	while k ~= 0 do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
	end
	return formatted
end

function Core.Utils.lerp(a, b, t)
	return a + (b - a) * t
end

function Core.Utils.clamp(value, min, max)
	return math.max(min, math.min(max, value))
end

function Core.Utils.blend(a, b, alpha)
	alpha = Core.Utils.clamp(alpha, 0, 1)
	return Color3.new(
		a.R + (b.R - a.R) * alpha,
		a.G + (b.G - a.G) * alpha,
		a.B + (b.B - a.B) * alpha
	)
end

function Core.Utils.debounce(func, delay)
	local lastCall = 0
	return function(...)
		local now = tick()
		if now - lastCall < delay then return end
		lastCall = now
		return func(...)
	end
end

-- Animation System
Core.Animation = {}

function Core.Animation.tween(object, properties, duration, easingStyle, easingDirection)
	if not Core.State.settings.animationsEnabled then
		for property, value in pairs(properties) do
			object[property] = value
		end
		return
	end

	duration = duration or Core.CONSTANTS.ANIM_MEDIUM
	easingStyle = easingStyle or Enum.EasingStyle.Quad
	easingDirection = easingDirection or Enum.EasingDirection.Out

	local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection)
	local tween = TweenService:Create(object, tweenInfo, properties)
	tween:Play()
	return tween
end

-- Data Management
Core.DataManager = {}

Core.DataManager.products = {
	cash = {
		{
			id = 1897730242,
			amount = 1000,
			name = "1,000 Cash",
			description = "A small boost to get you started",
			icon = "rbxassetid://10709728059",
			featured = false,
			price = 0,
		},
		{
			id = 1897730373,
			amount = 5000,
			name = "5,000 Cash",
			description = "Perfect for mid-game expansion",
			icon = "rbxassetid://10709728059",
			featured = true,
			price = 0,
		},
		{
			id = 1897730467,
			amount = 10000,
			name = "10,000 Cash",
			description = "Accelerate your progress significantly",
			icon = "rbxassetid://10709728059",
			featured = false,
			price = 0,
		},
		{
			id = 1897730581,
			amount = 50000,
			name = "50,000 Cash",
			description = "Maximum value for serious players",
			icon = "rbxassetid://10709728059",
			featured = true,
			price = 0,
		},
	},
	gamepasses = {
		{
			id = 1412171840,
			name = "Auto Collect",
			description = "Automatically collect all cash drops",
			icon = "rbxassetid://10709727148",
			price = 99,
			features = {
				"Hands-free collection",
				"Works while AFK",
				"Saves time",
			},
			hasToggle = true,
		},
		{
			id = 1398974710,
			name = "2x Cash",
			description = "Double all cash earned permanently",
			icon = "rbxassetid://10709727148",
			price = 199,
			features = {
				"2x multiplier",
				"Stacks with events",
				"Best value",
			},
			hasToggle = false,
		},
	},
}

function Core.DataManager.getProductInfo(productId)
	local cached = productCache:get(productId)
	if cached then return cached end

	local success, info = pcall(function()
		return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
	end)

	if success and info then
		productCache:set(productId, info)
		return info
	end

	return nil
end

function Core.DataManager.getGamePassInfo(passId)
	local cached = productCache:get("pass_" .. passId)
	if cached then return cached end

	local success, info = pcall(function()
		return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
	end)

	if success and info then
		productCache:set("pass_" .. passId, info)
		return info
	end

	return nil
end

function Core.DataManager.checkOwnership(passId)
	local cacheKey = Player.UserId .. "_" .. passId
	local cached = ownershipCache:get(cacheKey)
	if cached ~= nil then return cached end

	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, passId)
	end)

	if success then
		ownershipCache:set(cacheKey, owns)
		return owns
	end

	return false
end

function Core.DataManager.refreshPrices()
	for _, product in ipairs(Core.DataManager.products.cash) do
		local info = Core.DataManager.getProductInfo(product.id)
		if info then
			product.price = info.PriceInRobux or 0
		end
	end

	for _, pass in ipairs(Core.DataManager.products.gamepasses) do
		local info = Core.DataManager.getGamePassInfo(pass.id)
		if info and info.PriceInRobux then
			pass.price = info.PriceInRobux
		end
	end
end

-- ========================================
-- UI MODULE (Embedded)
-- ========================================
local UI = {}

-- Theme System
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
			accentAlt = Color3.fromRGB(186, 214, 255),
			success = Color3.fromRGB(76, 175, 80),
			warning = Color3.fromRGB(255, 152, 0),
			error = Color3.fromRGB(244, 67, 54),

			kitty = Color3.fromRGB(255, 64, 64),
			melody = Color3.fromRGB(255, 187, 204),
			kuromi = Color3.fromRGB(200, 190, 255),
			cinna = Color3.fromRGB(186, 214, 255),
			pompom = Color3.fromRGB(255, 220, 110),
		}
	}
}

function UI.Theme:get(key)
	return self.themes[self.current][key] or Color3.new(1, 1, 1)
end

-- Component Factory
UI.Components = {}

-- Base Component Class
local Component = {}
Component.__index = Component

function Component.new(className, props)
	local self = setmetatable({}, Component)
	self.instance = Instance.new(className)
	self.props = props or {}
	self.children = {}
	self.eventConnections = {}
	return self
end

function Component:applyProps()
	for key, value in pairs(self.props) do
		-- Skip special properties
		if key ~= "children" and key ~= "parent" and key ~= "onClick" and 
			key ~= "cornerRadius" and key ~= "stroke" and key ~= "shadow" and 
			key ~= "layout" and key ~= "padding" then

			if type(value) == "function" and key:sub(1, 2) == "on" then
				local eventName = key:sub(3)
				local connection = self.instance[eventName]:Connect(value)
				table.insert(self.eventConnections, connection)
			else
				-- Only set if property exists
				pcall(function()
					self.instance[key] = value
				end)
			end
		end
	end

	-- Handle onClick separately for buttons
	if self.props.onClick and self.instance:IsA("TextButton") then
		local connection = self.instance.MouseButton1Click:Connect(self.props.onClick)
		table.insert(self.eventConnections, connection)
	end
end

function Component:render()
	self:applyProps()

	if self.props.children then
		for _, child in ipairs(self.props.children) do
			if typeof(child) == "table" and child.render then
				child:render()
				child.instance.Parent = self.instance
			elseif typeof(child) == "Instance" then
				child.Parent = self.instance
			end
		end
	end

	if self.props.parent then
		self.instance.Parent = self.props.parent
	end

	return self.instance
end

function Component:destroy()
	for _, connection in ipairs(self.eventConnections) do
		connection:Disconnect()
	end
	self.instance:Destroy()
end

-- Frame Component
function UI.Components.Frame(props)
	local defaultProps = {
		BackgroundColor3 = UI.Theme:get("surface"),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}

	for key, value in pairs(defaultProps) do
		if props[key] == nil then
			props[key] = value
		end
	end

	local component = Component.new("Frame", props)

	if props.cornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = props.cornerRadius
		corner.Parent = component.instance
	end

	if props.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = props.stroke.color or UI.Theme:get("stroke")
		stroke.Thickness = props.stroke.thickness or 1
		stroke.Transparency = props.stroke.transparency or 0
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = component.instance
	end

	return component
end

-- Text Label Component
function UI.Components.TextLabel(props)
	local defaultProps = {
		BackgroundTransparency = 1,
		TextColor3 = UI.Theme:get("text"),
		Font = Enum.Font.Gotham,
		TextScaled = false,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 1),
	}

	for key, value in pairs(defaultProps) do
		if props[key] == nil then
			props[key] = value
		end
	end

	return Component.new("TextLabel", props)
end

-- Button Component
function UI.Components.Button(props)
	local defaultProps = {
		BackgroundColor3 = UI.Theme:get("accent"),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamMedium,
		TextScaled = false,
		Size = UDim2.fromOffset(120, 40),
		AutoButtonColor = false,
	}

	for key, value in pairs(defaultProps) do
		if props[key] == nil then
			props[key] = value
		end
	end

	local component = Component.new("TextButton", props)

	-- Add corner radius if specified
	if props.cornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = props.cornerRadius
		corner.Parent = component.instance
	end

	-- Add stroke if specified
	if props.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = props.stroke.color or UI.Theme:get("stroke")
		stroke.Thickness = props.stroke.thickness or 1
		stroke.Transparency = props.stroke.transparency or 0
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = component.instance
	end

	-- Add hover effects
	local originalSize = props.Size or defaultProps.Size
	local hoverScale = props.hoverScale or 1.05

	component.instance.MouseEnter:Connect(function()
		Core.Animation.tween(component.instance, {
			Size = UDim2.new(
				originalSize.X.Scale * hoverScale,
				originalSize.X.Offset * hoverScale,
				originalSize.Y.Scale * hoverScale,
				originalSize.Y.Offset * hoverScale
			)
		}, Core.CONSTANTS.ANIM_FAST)
	end)

	component.instance.MouseLeave:Connect(function()
		Core.Animation.tween(component.instance, {
			Size = originalSize
		}, Core.CONSTANTS.ANIM_FAST)
	end)

	return component
end

-- Image Component
function UI.Components.Image(props)
	local defaultProps = {
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(100, 100),
	}

	for key, value in pairs(defaultProps) do
		if props[key] == nil then
			props[key] = value
		end
	end

	return Component.new("ImageLabel", props)
end

-- ScrollingFrame Component
function UI.Components.ScrollingFrame(props)
	local defaultProps = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UI.Theme:get("stroke"),
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollingDirection = props.ScrollingDirection or Enum.ScrollingDirection.Y,
	}

	for key, value in pairs(defaultProps) do
		if props[key] == nil then
			props[key] = value
		end
	end

	local component = Component.new("ScrollingFrame", props)

	-- Add layout if specified
	if props.layout then
		local layoutType = props.layout.type or "List"
		local layout = Instance.new("UI" .. layoutType .. "Layout")

		for key, value in pairs(props.layout) do
			if key ~= "type" then
				pcall(function()
					layout[key] = value
				end)
			end
		end

		layout.Parent = component.instance

		-- Auto-size canvas
		task.defer(function()
			if layoutType == "List" then
				layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
					if props.ScrollingDirection == Enum.ScrollingDirection.X then
						component.instance.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X + 20, 0, 0)
					else
						component.instance.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
					end
				end)
			elseif layoutType == "Grid" then
				layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
					component.instance.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
				end)
			end
		end)
	end

	-- Add padding if specified
	if props.padding then
		local padding = Instance.new("UIPadding")
		if props.padding.top then padding.PaddingTop = props.padding.top end
		if props.padding.bottom then padding.PaddingBottom = props.padding.bottom end
		if props.padding.left then padding.PaddingLeft = props.padding.left end
		if props.padding.right then padding.PaddingRight = props.padding.right end
		padding.Parent = component.instance
	end

	return component
end

-- Layout Utilities
UI.Layout = {}

function UI.Layout.stack(parent, direction, spacing, padding)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction or Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, spacing or 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent

	if padding then
		local uiPadding = Instance.new("UIPadding")
		uiPadding.PaddingTop = UDim.new(0, padding.top or 0)
		uiPadding.PaddingBottom = UDim.new(0, padding.bottom or 0)
		uiPadding.PaddingLeft = UDim.new(0, padding.left or 0)
		uiPadding.PaddingRight = UDim.new(0, padding.right or 0)
		uiPadding.Parent = parent
	end

	return layout
end

-- Responsive Design
UI.Responsive = {}

function UI.Responsive.scale(instance)
	local camera = workspace.CurrentCamera
	if not camera then return end

	local scale = Instance.new("UIScale")
	scale.Parent = instance

	local function updateScale()
		local viewportSize = camera.ViewportSize
		local scaleFactor = math.min(viewportSize.X / 1920, viewportSize.Y / 1080)
		scaleFactor = Core.Utils.clamp(scaleFactor, 0.5, 1.5)

		if Core.Utils.isMobile() then
			scaleFactor = scaleFactor * 0.85
		end

		scale.Scale = scaleFactor
	end

	updateScale()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

	return scale
end

-- ========================================
-- MAIN SHOP IMPLEMENTATION - MODERN DESIGN
-- ========================================
local Shop = {}
Shop.__index = Shop

function Shop.new()
	local self = setmetatable({}, Shop)

	self.gui = nil
	self.mainPanel = nil
	self.tabContainer = nil
	self.contentContainer = nil
	self.currentTab = "Home"
	self.tabs = {}
	self.pages = {}
	self.toggleButton = nil
	self.blur = nil

	self:initialize()

	return self
end

function Shop:initialize()
	Core.DataManager.refreshPrices()

	self:createToggleButton()
	self:createMainInterface()
	self:setupRemoteHandlers()
	self:setupInputHandlers()

	Core.State.initialized = true
	Core.Events:emit("shopInitialized")
end

function Shop:createToggleButton()
	local toggleScreen = PlayerGui:FindFirstChild("SanrioShopToggle") or Instance.new("ScreenGui")
	toggleScreen.Name = "SanrioShopToggle"
	toggleScreen.ResetOnSpawn = false
	toggleScreen.DisplayOrder = 999
	toggleScreen.Parent = PlayerGui

	self.toggleButton = UI.Components.Button({
		Name = "ShopToggle",
		Text = "",
		Size = UDim2.fromOffset(180, 60),
		Position = UDim2.new(1, -20, 1, -20),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(1, 0),
		stroke = {
			color = UI.Theme:get("accent"),
			thickness = 2,
		},
		parent = toggleScreen,
		onClick = function()
			self:toggle()
		end,
	}):render()

	local icon = UI.Components.Image({
		Name = "Icon",
		Image = "rbxassetid://17398522865",
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(16, 14),
		parent = self.toggleButton,
	}):render()

	local label = UI.Components.TextLabel({
		Name = "Label",
		Text = "Shop",
		Size = UDim2.new(1, -64, 1, 0),
		Position = UDim2.fromOffset(56, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		parent = self.toggleButton,
	}):render()

	self:addPulseAnimation(self.toggleButton)
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

	local dimBackground = UI.Components.Frame({
		Name = "DimBackground",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		parent = self.gui,
	}):render()

	local panelSize = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE

	self.mainPanel = UI.Components.Frame({
		Name = "MainPanel",
		Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(2, 6, 23),
		cornerRadius = UDim.new(0, 36),
		stroke = {
			color = Color3.fromRGB(147, 51, 234),
			thickness = 3,
		},
		parent = self.gui,
	}):render()

	-- Glassmorphism background with animated gradient
	local panelGradient = Instance.new("UIGradient")
	panelGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 12, 35)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(6, 10, 30)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(4, 8, 25)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(2, 6, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 4, 15)),
	})
	panelGradient.Rotation = 45
	panelGradient.Parent = self.mainPanel

	-- Animated background pattern
	local bgPattern = Instance.new("ImageLabel")
	bgPattern.Name = "BackgroundPattern"
	bgPattern.BackgroundTransparency = 1
	bgPattern.Image = "rbxassetid://8992230672"
	bgPattern.ImageColor3 = Color3.fromRGB(147, 51, 234)
	bgPattern.ImageTransparency = 0.85
	bgPattern.ScaleType = Enum.ScaleType.Tile
	bgPattern.TileSize = UDim2.fromOffset(80, 80)
	bgPattern.Size = UDim2.fromScale(1, 1)
	bgPattern.ZIndex = 1
	bgPattern.Parent = self.mainPanel

	-- Floating accent orbs
	local orb1 = Instance.new("Frame")
	orb1.Name = "Orb1"
	orb1.BackgroundColor3 = Color3.fromRGB(147, 51, 234)
	orb1.BackgroundTransparency = 0.9
	orb1.BorderSizePixel = 0
	orb1.Size = UDim2.fromOffset(120, 120)
	orb1.Position = UDim2.new(0, -60, 0, -60)
	orb1.ZIndex = 2
	orb1.Parent = self.mainPanel

	local orb1Corner = Instance.new("UICorner")
	orb1Corner.CornerRadius = UDim.new(0.5, 0)
	orb1Corner.Parent = orb1

	local orb2 = Instance.new("Frame")
	orb2.Name = "Orb2"
	orb2.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
	orb2.BackgroundTransparency = 0.9
	orb2.BorderSizePixel = 0
	orb2.Size = UDim2.fromOffset(100, 100)
	orb2.Position = UDim2.new(1, -50, 1, -50)
	orb2.AnchorPoint = Vector2.new(1, 1)
	orb2.ZIndex = 2
	orb2.Parent = self.mainPanel

	local orb2Corner = Instance.new("UICorner")
	orb2Corner.CornerRadius = UDim.new(0.5, 0)
	orb2Corner.Parent = orb2

	UI.Responsive.scale(self.mainPanel)

	self:createHeader()
	self:createTabBar()

	self.contentContainer = UI.Components.Frame({
		Name = "ContentContainer",
		Size = UDim2.new(1, -48, 1, -180),
		Position = UDim2.fromOffset(24, 156),
		BackgroundTransparency = 1,
		parent = self.mainPanel,
	}):render()

	self:createPages()
	self:selectTab("Home")
end

function Shop:createHeader()
	local header = UI.Components.Frame({
		Name = "Header",
		Size = UDim2.new(1, -48, 0, 90),
		Position = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.05,
		cornerRadius = UDim.new(0, 20),
		parent = self.mainPanel,
	}):render()

	-- Glassmorphism header with blur effect
	local headerBlur = Instance.new("Frame")
	headerBlur.Name = "HeaderBlur"
	headerBlur.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	headerBlur.BackgroundTransparency = 0.95
	headerBlur.BorderSizePixel = 0
	headerBlur.Size = UDim2.fromScale(1, 1)
	headerBlur.Position = UDim2.fromOffset(0, 0)
	headerBlur.ZIndex = header.ZIndex - 1
	headerBlur.Parent = header

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 20)
	headerCorner.Parent = headerBlur

	-- Modern header border glow
	local headerBorder = Instance.new("UIStroke")
	headerBorder.Color = Color3.fromRGB(147, 51, 234)
	headerBorder.Thickness = 2
	headerBorder.Transparency = 0.7
	headerBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	headerBorder.Parent = header

	local logoContainer = UI.Components.Frame({
		Size = UDim2.fromOffset(70, 70),
		Position = UDim2.fromOffset(15, 10),
		BackgroundColor3 = Color3.fromRGB(147, 51, 234),
		cornerRadius = UDim.new(0.5, 0),
		parent = header,
	}):render()

	-- Pulsing logo effect
	local logoPulse = Instance.new("UIGradient")
	logoPulse.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(147, 51, 234)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(168, 85, 247)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(147, 51, 234)),
	})
	logoPulse.Parent = logoContainer

	local logo = UI.Components.Image({
		Name = "Logo",
		Image = "rbxassetid://17398522865",
		Size = UDim2.fromScale(0.85, 0.85),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		parent = logoContainer,
	}):render()

	local title = UI.Components.TextLabel({
		Name = "Title",
		Text = "SANRIO SHOP",
		Size = UDim2.new(1, -200, 1, 0),
		Position = UDim2.fromOffset(100, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 34,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		parent = header,
	}):render()

	-- Subtitle with modern styling
	local subtitle = UI.Components.TextLabel({
		Name = "Subtitle",
		Text = "Premium Items & Upgrades",
		Size = UDim2.new(1, -200, 0, 20),
		Position = UDim2.fromOffset(100, 45),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		parent = header,
	}):render()

	local closeButton = UI.Components.Button({
		Name = "CloseButton",
		Text = "×",
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.new(1, -70, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(239, 68, 68),
		BackgroundTransparency = 0.1,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		cornerRadius = UDim.new(0.5, 0),
		parent = header,
		onClick = function()
			self:close()
		end,
	}):render()

	-- Modern glassmorphism close button
	local closeBlur = Instance.new("Frame")
	closeBlur.Name = "CloseBlur"
	closeBlur.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
	closeBlur.BackgroundTransparency = 0.8
	closeBlur.BorderSizePixel = 0
	closeBlur.Size = UDim2.fromScale(1, 1)
	closeBlur.Position = UDim2.fromOffset(0, 0)
	closeBlur.ZIndex = closeButton.ZIndex - 1
	closeBlur.Parent = closeButton

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0.5, 0)
	closeCorner.Parent = closeBlur

	-- Close button glow effect
	local closeGlow = Instance.new("UIStroke")
	closeGlow.Color = Color3.fromRGB(239, 68, 68)
	closeGlow.Thickness = 2
	closeGlow.Transparency = 0.5
	closeGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	closeGlow.Parent = closeButton

	-- Enhanced hover effects
	closeButton.MouseEnter:Connect(function()
		Core.Animation.tween(closeButton, {
			BackgroundTransparency = 0,
			Size = UDim2.fromOffset(60, 60)
		}, Core.CONSTANTS.ANIM_FAST)
	end)

	closeButton.MouseLeave:Connect(function()
		Core.Animation.tween(closeButton, {
			BackgroundTransparency = 0.1,
			Size = UDim2.fromOffset(50, 50)
		}, Core.CONSTANTS.ANIM_FAST)
	end)
end

function Shop:createTabBar()
	self.tabContainer = UI.Components.Frame({
		Name = "TabContainer",
		Size = UDim2.new(1, -48, 0, 70),
		Position = UDim2.fromOffset(24, 130),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.05,
		cornerRadius = UDim.new(0, 18),
		parent = self.mainPanel,
	}):render()

	-- Glassmorphism tab container
	local tabBlur = Instance.new("Frame")
	tabBlur.Name = "TabBlur"
	tabBlur.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	tabBlur.BackgroundTransparency = 0.95
	tabBlur.BorderSizePixel = 0
	tabBlur.Size = UDim2.fromScale(1, 1)
	tabBlur.Position = UDim2.fromOffset(0, 0)
	tabBlur.ZIndex = self.tabContainer.ZIndex - 1
	tabBlur.Parent = self.tabContainer

	local tabCorner = Instance.new("UICorner")
	tabCorner.CornerRadius = UDim.new(0, 18)
	tabCorner.Parent = tabBlur

	-- Modern tab border
	local tabBorder = Instance.new("UIStroke")
	tabBorder.Color = Color3.fromRGB(147, 51, 234)
	tabBorder.Thickness = 2
	tabBorder.Transparency = 0.8
	tabBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tabBorder.Parent = self.tabContainer

	UI.Layout.stack(self.tabContainer, Enum.FillDirection.Horizontal, 24)

	local tabData = {
		{id = "Home", name = "HOME", icon = "rbxassetid://17398522865", color = Color3.fromRGB(147, 51, 234)},
		{id = "Cash", name = "CASH", icon = "rbxassetid://10709728059", color = Color3.fromRGB(59, 130, 246)},
		{id = "Gamepasses", name = "PASSES", icon = "rbxassetid://10709727148", color = Color3.fromRGB(16, 185, 129)},
	}

	for _, data in ipairs(tabData) do
		self:createTab(data)
	end
end

function Shop:createTab(data)
	local tab = UI.Components.Button({
		Name = data.id .. "Tab",
		Text = "",
		Size = UDim2.fromOffset(160, 45),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.1,
		cornerRadius = UDim.new(0, 12),
		stroke = {
			color = data.color,
			thickness = 2,
			transparency = 0.6,
		},
		LayoutOrder = #self.tabs + 1,
		parent = self.tabContainer,
		onClick = function()
			self:selectTab(data.id)
		end,
	}):render()

	-- Glassmorphism tab background
	local tabBlur = Instance.new("Frame")
	tabBlur.Name = "TabBlur"
	tabBlur.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	tabBlur.BackgroundTransparency = 0.9
	tabBlur.BorderSizePixel = 0
	tabBlur.Size = UDim2.fromScale(1, 1)
	tabBlur.Position = UDim2.fromOffset(0, 0)
	tabBlur.ZIndex = tab.ZIndex - 1
	tabBlur.Parent = tab

	local tabCorner = Instance.new("UICorner")
	tabCorner.CornerRadius = UDim.new(0, 12)
	tabCorner.Parent = tabBlur

	-- Tab accent glow
	local tabGlow = Instance.new("UIStroke")
	tabGlow.Color = data.color
	tabGlow.Thickness = 1
	tabGlow.Transparency = 0.8
	tabGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tabGlow.Parent = tab

	local content = UI.Components.Frame({
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		parent = tab,
	}):render()

	UI.Layout.stack(content, Enum.FillDirection.Horizontal, 10, {left = 16, right = 16})

	local icon = UI.Components.Image({
		Name = "Icon",
		Image = data.icon,
		Size = UDim2.fromOffset(24, 24),
		LayoutOrder = 1,
		parent = content,
	}):render()

	local label = UI.Components.TextLabel({
		Name = "Label",
		Text = data.name,
		Size = UDim2.new(1, -32, 1, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		LayoutOrder = 2,
		parent = content,
	}):render()

	self.tabs[data.id] = {
		button = tab,
		data = data,
		icon = icon,
		label = label,
	}
end

function Shop:createPages()
	self.pages.Home = self:createHomePage()
	self.pages.Cash = self:createCashPage()
	self.pages.Gamepasses = self:createGamepassesPage()
end

function Shop:createHomePage()
	local page = UI.Components.Frame({
		Name = "HomePage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		parent = self.contentContainer,
	}):render()

	local scrollFrame = UI.Components.ScrollingFrame({
		Size = UDim2.fromScale(1, 1),
		layout = {
			type = "List",
			Padding = UDim.new(0, 24),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		},
		padding = {
			top = UDim.new(0, 12),
			bottom = UDim.new(0, 12),
		},
		parent = page,
	}):render()

	local hero = self:createHeroSection(scrollFrame)

	local featuredTitle = UI.Components.TextLabel({
		Text = "Featured Items",
		Size = UDim2.new(1, 0, 0, 40),
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		parent = scrollFrame,
	}):render()

	local featuredContainer = UI.Components.Frame({
		Size = UDim2.new(1, 0, 0, 320),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		parent = scrollFrame,
	}):render()

	local featuredScroll = UI.Components.ScrollingFrame({
		Size = UDim2.fromScale(1, 1),
		ScrollingDirection = Enum.ScrollingDirection.X,
		layout = {
			type = "List",
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 16),
		},
		parent = featuredContainer,
	}):render()

	local featured = {}
	for _, product in ipairs(Core.DataManager.products.cash) do
		if product.featured then
			table.insert(featured, {type = "cash", data = product})
		end
	end

	for _, item in ipairs(featured) do
		self:createProductCard(item.data, item.type, featuredScroll)
	end

	return page
end

function Shop:createCashPage()
	local page = UI.Components.Frame({
		Name = "CashPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		parent = self.contentContainer,
	}):render()

	local scrollFrame = UI.Components.ScrollingFrame({
		Size = UDim2.fromScale(1, 1),
		layout = {
			type = "Grid",
			CellSize = Core.Utils.isMobile() and 
				UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE_MOBILE.X, Core.CONSTANTS.CARD_SIZE_MOBILE.Y) or
				UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y),
			CellPadding = UDim2.fromOffset(20, 20),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		},
		padding = {
			top = UDim.new(0, 12),
			bottom = UDim.new(0, 12),
			left = UDim.new(0, 12),
			right = UDim.new(0, 12),
		},
		parent = page,
	}):render()

	for _, product in ipairs(Core.DataManager.products.cash) do
		self:createProductCard(product, "cash", scrollFrame)
	end

	return page
end

function Shop:createGamepassesPage()
	local page = UI.Components.Frame({
		Name = "GamepassesPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		parent = self.contentContainer,
	}):render()

	local scrollFrame = UI.Components.ScrollingFrame({
		Size = UDim2.fromScale(1, 1),
		layout = {
			type = "Grid",
			CellSize = Core.Utils.isMobile() and 
				UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE_MOBILE.X, Core.CONSTANTS.CARD_SIZE_MOBILE.Y) or
				UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y),
			CellPadding = UDim2.fromOffset(20, 20),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		},
		padding = {
			top = UDim.new(0, 12),
			bottom = UDim.new(0, 12),
			left = UDim.new(0, 12),
			right = UDim.new(0, 12),
		},
		parent = page,
	}):render()

	for _, pass in ipairs(Core.DataManager.products.gamepasses) do
		self:createProductCard(pass, "gamepass", scrollFrame)
	end

	return page
end

function Shop:createHeroSection(parent)
	local hero = UI.Components.Frame({
		Name = "HeroSection",
		Size = UDim2.new(1, 0, 0, 220),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.05,
		cornerRadius = UDim.new(0, 24),
		LayoutOrder = 1,
		parent = parent,
	}):render()

	-- Glassmorphism hero background
	local heroBlur = Instance.new("Frame")
	heroBlur.Name = "HeroBlur"
	heroBlur.BackgroundColor3 = Color3.fromRGB(147, 51, 234)
	heroBlur.BackgroundTransparency = 0.9
	heroBlur.BorderSizePixel = 0
	heroBlur.Size = UDim2.fromScale(1, 1)
	heroBlur.Position = UDim2.fromOffset(0, 0)
	heroBlur.ZIndex = hero.ZIndex - 1
	heroBlur.Parent = hero

	local heroCorner = Instance.new("UICorner")
	heroCorner.CornerRadius = UDim.new(0, 24)
	heroCorner.Parent = heroBlur

	-- Hero border glow
	local heroBorder = Instance.new("UIStroke")
	heroBorder.Color = Color3.fromRGB(147, 51, 234)
	heroBorder.Thickness = 2
	heroBorder.Transparency = 0.7
	heroBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	heroBorder.Parent = hero

	-- Hero accent line
	local heroAccent = Instance.new("Frame")
	heroAccent.Name = "Accent"
	heroAccent.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
	heroAccent.BackgroundTransparency = 0.8
	heroAccent.BorderSizePixel = 0
	heroAccent.Size = UDim2.new(1, 0, 0, 2)
	heroAccent.Position = UDim2.fromOffset(0, 0)
	heroAccent.ZIndex = 3
	heroAccent.Parent = hero


	local content = UI.Components.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		parent = hero,
	}):render()

	UI.Layout.stack(content, Enum.FillDirection.Horizontal, 40, {
		left = 50,
		right = 50,
		top = 40,
		bottom = 40,
	})

	local textContainer = UI.Components.Frame({
		Size = UDim2.new(0.7, 0, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		parent = content,
	}):render()

	local heroTitle = UI.Components.TextLabel({
		Text = "SANRIO SHOP",
		Size = UDim2.new(1, 0, 0, 50),
		Font = Enum.Font.GothamBold,
		TextSize = 36,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = textContainer,
	}):render()

	local heroDesc = UI.Components.TextLabel({
		Text = "Premium items and exclusive upgrades await. Browse our collection of cash bundles and powerful gamepasses to enhance your tycoon experience.",
		Size = UDim2.new(1, 0, 0, 70),
		Position = UDim2.fromOffset(0, 60),
		Font = Enum.Font.Gotham,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(200, 210, 220),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		parent = textContainer,
	}):render()

	local ctaButton = UI.Components.Button({
		Text = "EXPLORE STORE",
		Size = UDim2.fromOffset(220, 55),
		Position = UDim2.fromOffset(0, 140),
		BackgroundColor3 = Color3.fromRGB(59, 130, 246),
		BackgroundTransparency = 0.1,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		cornerRadius = UDim.new(0, 14),
		parent = textContainer,
		onClick = function()
			self:selectTab("Cash")
		end,
	}):render()

	-- Glassmorphism CTA button
	local ctaBlur = Instance.new("Frame")
	ctaBlur.Name = "CTABlur"
	ctaBlur.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
	ctaBlur.BackgroundTransparency = 0.8
	ctaBlur.BorderSizePixel = 0
	ctaBlur.Size = UDim2.fromScale(1, 1)
	ctaBlur.Position = UDim2.fromOffset(0, 0)
	ctaBlur.ZIndex = ctaButton.ZIndex - 1
	ctaBlur.Parent = ctaButton

	local ctaCorner = Instance.new("UICorner")
	ctaCorner.CornerRadius = UDim.new(0, 14)
	ctaCorner.Parent = ctaBlur

	-- CTA button glow
	local ctaGlow = Instance.new("UIStroke")
	ctaGlow.Color = Color3.fromRGB(59, 130, 246)
	ctaGlow.Thickness = 2
	ctaGlow.Transparency = 0.6
	ctaGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ctaGlow.Parent = ctaButton

	-- Enhanced hover effects
	ctaButton.MouseEnter:Connect(function()
		Core.Animation.tween(ctaButton, {
			BackgroundTransparency = 0,
			Size = UDim2.fromOffset(230, 60)
		}, Core.CONSTANTS.ANIM_FAST)
	end)

	ctaButton.MouseLeave:Connect(function()
		Core.Animation.tween(ctaButton, {
			BackgroundTransparency = 0.1,
			Size = UDim2.fromOffset(220, 55)
		}, Core.CONSTANTS.ANIM_FAST)
	end)

	return hero
end

function Shop:createProductCard(product, productType, parent)
	local isGamepass = productType == "gamepass"
	local cardColor = isGamepass and UI.Theme:get("kuromi") or UI.Theme:get("cinna")

	-- Calculate responsive card size
	local cardWidth = Core.Utils.isMobile() and 280 or 320
	local cardHeight = Core.Utils.isMobile() and 380 or 420

	local card = UI.Components.Frame({
		Name = product.name .. "Card",
		Size = UDim2.fromOffset(cardWidth, cardHeight),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.05,
		cornerRadius = UDim.new(0, 20),
		stroke = {
			color = cardColor,
			thickness = 3,
			transparency = 0.7,
		},
		parent = parent,
	}):render()

	-- Glassmorphism card background
	local cardBlur = Instance.new("Frame")
	cardBlur.Name = "CardBlur"
	cardBlur.BackgroundColor3 = cardColor
	cardBlur.BackgroundTransparency = 0.9
	cardBlur.BorderSizePixel = 0
	cardBlur.Size = UDim2.fromScale(1, 1)
	cardBlur.Position = UDim2.fromOffset(0, 0)
	cardBlur.ZIndex = card.ZIndex - 1
	cardBlur.Parent = card

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 20)
	cardCorner.Parent = cardBlur

	-- Card border glow
	local cardGlow = Instance.new("UIStroke")
	cardGlow.Color = cardColor
	cardGlow.Thickness = 2
	cardGlow.Transparency = 0.8
	cardGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cardGlow.Parent = card

	-- Multiple shadow layers for premium depth
	local cardShadow1 = Instance.new("Frame")
	cardShadow1.Name = "Shadow1"
	cardShadow1.BackgroundColor3 = Color3.new(0, 0, 0)
	cardShadow1.BackgroundTransparency = 0.85
	cardShadow1.BorderSizePixel = 0
	cardShadow1.Size = UDim2.new(1, 10, 1, 10)
	cardShadow1.Position = UDim2.fromOffset(5, 5)
	cardShadow1.ZIndex = card.ZIndex - 3
	cardShadow1.Parent = parent

	local cardShadow2 = Instance.new("Frame")
	cardShadow2.Name = "Shadow2"
	cardShadow2.BackgroundColor3 = Color3.new(0, 0, 0)
	cardShadow2.BackgroundTransparency = 0.92
	cardShadow2.BorderSizePixel = 0
	cardShadow2.Size = UDim2.new(1, 6, 1, 6)
	cardShadow2.Position = UDim2.fromOffset(3, 3)
	cardShadow2.ZIndex = card.ZIndex - 2
	cardShadow2.Parent = parent

	local shadowCorner1 = Instance.new("UICorner")
	shadowCorner1.CornerRadius = UDim.new(0, 20)
	shadowCorner1.Parent = cardShadow1

	local shadowCorner2 = Instance.new("UICorner")
	shadowCorner2.CornerRadius = UDim.new(0, 20)
	shadowCorner2.Parent = cardShadow2

	self:addCardHoverEffect(card)

	local content = UI.Components.Frame({
		Size = UDim2.new(1, -24, 1, -24),
		Position = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		parent = card,
	}):render()

	-- Modern image container with glassmorphism
	local imageContainer = UI.Components.Frame({
		Size = UDim2.new(1, 0, 0, 160),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.1,
		cornerRadius = UDim.new(0, 16),
		parent = content,
	}):render()

	-- Image container blur effect
	local imageBlur = Instance.new("Frame")
	imageBlur.Name = "ImageBlur"
	imageBlur.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	imageBlur.BackgroundTransparency = 0.9
	imageBlur.BorderSizePixel = 0
	imageBlur.Size = UDim2.fromScale(1, 1)
	imageBlur.Position = UDim2.fromOffset(0, 0)
	imageBlur.ZIndex = imageContainer.ZIndex - 1
	imageBlur.Parent = imageContainer

	local imageCorner = Instance.new("UICorner")
	imageCorner.CornerRadius = UDim.new(0, 16)
	imageCorner.Parent = imageBlur

	-- Image border glow
	local imageGlow = Instance.new("UIStroke")
	imageGlow.Color = cardColor
	imageGlow.Thickness = 1
	imageGlow.Transparency = 0.8
	imageGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	imageGlow.Parent = imageContainer

	local productImage = UI.Components.Image({
		Image = product.icon or "rbxassetid://10709728059",
		Size = UDim2.fromScale(0.85, 0.85),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ScaleType = Enum.ScaleType.Fit,
		parent = imageContainer,
	}):render()

	-- Image inner glow effect
	local imageInnerGlow = Instance.new("UIGradient")
	imageInnerGlow.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, cardColor:Lerp(Color3.new(1, 1, 1), 0.2)),
		ColorSequenceKeypoint.new(0.5, cardColor:Lerp(Color3.new(1, 1, 1), 0.1)),
		ColorSequenceKeypoint.new(1, cardColor:Lerp(Color3.new(1, 1, 1), 0.2)),
	})
	imageInnerGlow.Parent = productImage

	local infoContainer = UI.Components.Frame({
		Size = UDim2.new(1, 0, 1, -200),
		Position = UDim2.fromOffset(0, 200),
		BackgroundTransparency = 1,
		parent = content,
	}):render()

	-- Modern title styling
	local title = UI.Components.TextLabel({
		Text = product.name,
		Size = UDim2.new(1, 0, 0, 35),
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		parent = infoContainer,
	}):render()

	-- Modern description styling
	local description = UI.Components.TextLabel({
		Text = product.description,
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.fromOffset(0, 40),
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(180, 190, 200),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		parent = infoContainer,
	}):render()

	-- Modern price display
	local priceText = isGamepass and
		("R$" .. tostring(product.price or 0)) or
		("R$" .. tostring(product.price or 0) .. " • " .. Core.Utils.formatNumber(product.amount) .. " Cash")

	local priceLabel = UI.Components.TextLabel({
		Text = priceText,
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 95),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = cardColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		parent = infoContainer,
	}):render()

	local isOwned = isGamepass and Core.DataManager.checkOwnership(product.id)

	local purchaseButton = UI.Components.Button({
		Text = isOwned and "OWNED" or "PURCHASE",
		Size = UDim2.new(1, -20, 0, 50),
		Position = UDim2.fromOffset(10, 0, 1, -50),
		BackgroundColor3 = isOwned and Color3.fromRGB(16, 185, 129) or cardColor,
		BackgroundTransparency = 0.1,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		cornerRadius = UDim.new(0, 12),
		parent = infoContainer,
		onClick = function()
			if not isOwned then
				self:promptPurchase(product, productType)
			elseif product.hasToggle then
				self:toggleGamepass(product)
			end
		end,
	}):render()

	-- Glassmorphism button background
	local buttonBlur = Instance.new("Frame")
	buttonBlur.Name = "ButtonBlur"
	buttonBlur.BackgroundColor3 = isOwned and Color3.fromRGB(16, 185, 129) or cardColor
	buttonBlur.BackgroundTransparency = 0.8
	buttonBlur.BorderSizePixel = 0
	buttonBlur.Size = UDim2.fromScale(1, 1)
	buttonBlur.Position = UDim2.fromOffset(0, 0)
	buttonBlur.ZIndex = purchaseButton.ZIndex - 1
	buttonBlur.Parent = purchaseButton

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 12)
	buttonCorner.Parent = buttonBlur

	-- Button glow effect
	local buttonGlow = Instance.new("UIStroke")
	buttonGlow.Color = isOwned and Color3.fromRGB(16, 185, 129) or cardColor
	buttonGlow.Thickness = 2
	buttonGlow.Transparency = 0.7
	buttonGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	buttonGlow.Parent = purchaseButton

	if isOwned and product.hasToggle then
		self:addToggleSwitch(product, infoContainer)
	end

	product.cardInstance = card
	product.purchaseButton = purchaseButton

	return card
end

function Shop:addCardHoverEffect(card)
	local originalPosition = card.Position
	local originalStroke = card:FindFirstChildOfClass("UIStroke")

	card.MouseEnter:Connect(function()
		-- Modern hover effect with scale, lift, and glow
		Core.Animation.tween(card, {
			Position = UDim2.new(
				originalPosition.X.Scale,
				originalPosition.X.Offset,
				originalPosition.Y.Scale,
				originalPosition.Y.Offset - 8
			),
			Size = UDim2.fromOffset(card.Size.X.Offset * 1.03, card.Size.Y.Offset * 1.03)
		}, Core.CONSTANTS.ANIM_FAST)

		-- Enhanced glow on hover
		if originalStroke then
			Core.Animation.tween(originalStroke, {
				Thickness = 4,
				Transparency = 0.3
			}, Core.CONSTANTS.ANIM_FAST)
		end

		-- Add hover blur enhancement
		local hoverBlur = card:FindFirstChild("CardBlur")
		if hoverBlur then
			Core.Animation.tween(hoverBlur, {
				BackgroundTransparency = 0.85
			}, Core.CONSTANTS.ANIM_FAST)
		end
	end)

	card.MouseLeave:Connect(function()
		Core.Animation.tween(card, {
			Position = originalPosition,
			Size = UDim2.fromOffset(card.Size.X.Offset, card.Size.Y.Offset)
		}, Core.CONSTANTS.ANIM_FAST)

		-- Restore original effects
		if originalStroke then
			Core.Animation.tween(originalStroke, {
				Thickness = 3,
				Transparency = 0.7
			}, Core.CONSTANTS.ANIM_FAST)
		end

		-- Restore hover blur
		local hoverBlur = card:FindFirstChild("CardBlur")
		if hoverBlur then
			Core.Animation.tween(hoverBlur, {
				BackgroundTransparency = 0.9
			}, Core.CONSTANTS.ANIM_FAST)
		end
	end)
end

function Shop:addToggleSwitch(product, parent)
	local toggleContainer = UI.Components.Frame({
		Name = "ToggleContainer",
		Size = UDim2.fromOffset(70, 35),
		Position = UDim2.new(1, -70, 0, 85),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.1,
		cornerRadius = UDim.new(0.5, 0),
		parent = parent,
	}):render()

	-- Glassmorphism toggle background
	local toggleBlur = Instance.new("Frame")
	toggleBlur.Name = "ToggleBlur"
	toggleBlur.BackgroundColor3 = Color3.fromRGB(100, 100, 110)
	toggleBlur.BackgroundTransparency = 0.8
	toggleBlur.BorderSizePixel = 0
	toggleBlur.Size = UDim2.fromScale(1, 1)
	toggleBlur.Position = UDim2.fromOffset(0, 0)
	toggleBlur.ZIndex = toggleContainer.ZIndex - 1
	toggleBlur.Parent = toggleContainer

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0.5, 0)
	toggleCorner.Parent = toggleBlur

	-- Toggle border glow
	local toggleGlow = Instance.new("UIStroke")
	toggleGlow.Color = Color3.fromRGB(147, 51, 234)
	toggleGlow.Thickness = 1
	toggleGlow.Transparency = 0.8
	toggleGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	toggleGlow.Parent = toggleContainer

	local toggleButton = UI.Components.Frame({
		Name = "ToggleButton",
		Size = UDim2.fromOffset(31, 31),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.1,
		cornerRadius = UDim.new(0.5, 0),
		parent = toggleContainer,
	}):render()

	-- Toggle button glassmorphism
	local toggleButtonBlur = Instance.new("Frame")
	toggleButtonBlur.Name = "ToggleButtonBlur"
	toggleButtonBlur.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	toggleButtonBlur.BackgroundTransparency = 0.9
	toggleButtonBlur.BorderSizePixel = 0
	toggleButtonBlur.Size = UDim2.fromScale(1, 1)
	toggleButtonBlur.Position = UDim2.fromOffset(0, 0)
	toggleButtonBlur.ZIndex = toggleButton.ZIndex - 1
	toggleButtonBlur.Parent = toggleButton

	local toggleButtonCorner = Instance.new("UICorner")
	toggleButtonCorner.CornerRadius = UDim.new(0.5, 0)
	toggleButtonCorner.Parent = toggleButtonBlur

	-- Toggle button glow
	local toggleButtonGlow = Instance.new("UIStroke")
	toggleButtonGlow.Color = Color3.fromRGB(255, 255, 255)
	toggleButtonGlow.Thickness = 1
	toggleButtonGlow.Transparency = 0.7
	toggleButtonGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	toggleButtonGlow.Parent = toggleButton

	local toggleState = false
	if Remotes then
		local getStateRemote = Remotes:FindFirstChild("GetAutoCollectState")
		if getStateRemote and getStateRemote:IsA("RemoteFunction") then
			local success, state = pcall(function()
				return getStateRemote:InvokeServer()
			end)
			if success and type(state) == "boolean" then
				toggleState = state
			end
		end
	end

	local function updateToggleVisual()
		if toggleState then
			Core.Animation.tween(toggleContainer, {
				BackgroundColor3 = Color3.fromRGB(16, 185, 129)
			}, Core.CONSTANTS.ANIM_FAST)
			Core.Animation.tween(toggleButton, {
				Position = UDim2.fromOffset(37, 2)
			}, Core.CONSTANTS.ANIM_FAST)
		else
			Core.Animation.tween(toggleContainer, {
				BackgroundColor3 = Color3.fromRGB(100, 100, 110)
			}, Core.CONSTANTS.ANIM_FAST)
			Core.Animation.tween(toggleButton, {
				Position = UDim2.fromOffset(2, 2)
			}, Core.CONSTANTS.ANIM_FAST)
		end
	end

	updateToggleVisual()

	local toggleClickArea = Instance.new("TextButton")
	toggleClickArea.Text = ""
	toggleClickArea.BackgroundTransparency = 1
	toggleClickArea.Size = UDim2.fromScale(1, 1)
	toggleClickArea.Parent = toggleContainer

	toggleClickArea.MouseButton1Click:Connect(function()
		toggleState = not toggleState
		updateToggleVisual()

		if Remotes then
			local toggleRemote = Remotes:FindFirstChild("AutoCollectToggle")
			if toggleRemote and toggleRemote:IsA("RemoteEvent") then
				toggleRemote:FireServer(toggleState)
			end
		end

	end)
end

function Shop:addPulseAnimation(instance)
	local pulseRunning = true

	task.spawn(function()
		while pulseRunning and instance.Parent do
			Core.Animation.tween(instance, {
				Size = UDim2.fromOffset(188, 64)
			}, 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(1.5)

			if not pulseRunning or not instance.Parent then break end

			Core.Animation.tween(instance, {
				Size = UDim2.fromOffset(180, 60)
			}, 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(1.5)
		end
	end)

	instance.AncestryChanged:Connect(function()
		if not instance.Parent then
			pulseRunning = false
		end
	end)
end

function Shop:selectTab(tabId)
	if self.currentTab == tabId then return end

	for id, tab in pairs(self.tabs) do
		local isActive = id == tabId
		local data = tab.data

		Core.Animation.tween(tab.button, {
			BackgroundColor3 = isActive and 
				Core.Utils.blend(data.color, Color3.new(1, 1, 1), 0.9) or 
				UI.Theme:get("surface")
		}, Core.CONSTANTS.ANIM_FAST)

		local stroke = tab.button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = isActive and data.color or UI.Theme:get("stroke")
		end

		tab.icon.ImageColor3 = isActive and data.color or UI.Theme:get("text")
		tab.label.TextColor3 = isActive and data.color or UI.Theme:get("text")
	end

	for id, page in pairs(self.pages) do
		page.Visible = id == tabId

		if id == tabId then
			page.Position = UDim2.fromOffset(0, 20)
			Core.Animation.tween(page, {
				Position = UDim2.new()
			}, Core.CONSTANTS.ANIM_BOUNCE, Enum.EasingStyle.Back)
		end
	end

	self.currentTab = tabId
	Core.Events:emit("tabChanged", tabId)
end

function Shop:promptPurchase(product, productType)
	if productType == "gamepass" then
		if Core.DataManager.checkOwnership(product.id) then
			self:refreshProduct(product, productType)
			return
		end

		product.purchaseButton.Text = "Processing..."
		product.purchaseButton.Active = false

		Core.State.purchasePending[product.id] = {
			product = product,
			timestamp = tick(),
			type = productType,
		}

		local success = pcall(function()
			MarketplaceService:PromptGamePassPurchase(Player, product.id)
		end)

		if not success then
			product.purchaseButton.Text = "Purchase"
			product.purchaseButton.Active = true
			Core.State.purchasePending[product.id] = nil
		end

		task.delay(Core.CONSTANTS.PURCHASE_TIMEOUT, function()
			if Core.State.purchasePending[product.id] then
				product.purchaseButton.Text = "Purchase"
				product.purchaseButton.Active = true
				Core.State.purchasePending[product.id] = nil
			end
		end)
	else
		Core.State.purchasePending[product.id] = {
			product = product,
			timestamp = tick(),
			type = productType,
		}

		local success = pcall(function()
			MarketplaceService:PromptProductPurchase(Player, product.id)
		end)

		if not success then
			Core.State.purchasePending[product.id] = nil
		end
	end
end

function Shop:refreshProduct(product, productType)
	if productType == "gamepass" then
		local isOwned = Core.DataManager.checkOwnership(product.id)

		if product.purchaseButton then
			product.purchaseButton.Text = isOwned and "Owned" or "Purchase"
			product.purchaseButton.BackgroundColor3 = isOwned and 
				UI.Theme:get("success") or UI.Theme:get("kuromi")
			product.purchaseButton.Active = not isOwned
		end

		if product.cardInstance then
			local stroke = product.cardInstance:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = isOwned and UI.Theme:get("success") or UI.Theme:get("kuromi")
			end
		end
	end
end

function Shop:refreshAllProducts()
	ownershipCache:clear()

	for _, pass in ipairs(Core.DataManager.products.gamepasses) do
		self:refreshProduct(pass, "gamepass")
	end

	Core.Events:emit("productsRefreshed")
end

function Shop:open()
	if Core.State.isOpen or Core.State.isAnimating then return end

	Core.State.isAnimating = true
	Core.State.isOpen = true

	Core.DataManager.refreshPrices()
	self:refreshAllProducts()

	self.gui.Enabled = true

	Core.Animation.tween(self.blur, {
		Size = 24
	}, Core.CONSTANTS.ANIM_MEDIUM)

	self.mainPanel.Position = UDim2.fromScale(0.5, 0.55)
	self.mainPanel.Size = UDim2.fromOffset(
		self.mainPanel.Size.X.Offset * 0.9,
		self.mainPanel.Size.Y.Offset * 0.9
	)

	Core.Animation.tween(self.mainPanel, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(
			Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE.X or Core.CONSTANTS.PANEL_SIZE.X,
			Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE.Y or Core.CONSTANTS.PANEL_SIZE.Y
		)
	}, Core.CONSTANTS.ANIM_BOUNCE, Enum.EasingStyle.Back)


	task.wait(Core.CONSTANTS.ANIM_BOUNCE)
	Core.State.isAnimating = false

	Core.Events:emit("shopOpened")
end

function Shop:close()
	if not Core.State.isOpen or Core.State.isAnimating then return end

	Core.State.isAnimating = true
	Core.State.isOpen = false

	Core.Animation.tween(self.blur, {
		Size = 0
	}, Core.CONSTANTS.ANIM_FAST)

	Core.Animation.tween(self.mainPanel, {
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(
			self.mainPanel.Size.X.Offset * 0.9,
			self.mainPanel.Size.Y.Offset * 0.9
		)
	}, Core.CONSTANTS.ANIM_FAST)


	task.wait(Core.CONSTANTS.ANIM_FAST)
	self.gui.Enabled = false
	Core.State.isAnimating = false

	Core.Events:emit("shopClosed")
end

function Shop:toggle()
	if Core.State.isOpen then
		self:close()
	else
		self:open()
	end
end

function Shop:setupRemoteHandlers()
	if not Remotes then return end

	local purchaseConfirm = Remotes:FindFirstChild("GamepassPurchased")
	if purchaseConfirm and purchaseConfirm:IsA("RemoteEvent") then
		purchaseConfirm.OnClientEvent:Connect(function(passId)
			ownershipCache:clear()
			self:refreshAllProducts()
		end)
	end

	local productGrant = Remotes:FindFirstChild("ProductGranted") or Remotes:FindFirstChild("GrantProductCurrency")
	if productGrant and productGrant:IsA("RemoteEvent") then
		productGrant.OnClientEvent:Connect(function(productId, amount)
		end)
	end
end

function Shop:setupInputHandlers()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.M then
			self:toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and Core.State.isOpen then
			self:close()
		end
	end)

	if UserInputService.GamepadEnabled then
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end

			if input.KeyCode == Enum.KeyCode.ButtonX then
				self:toggle()
			end
		end)
	end
end

-- Purchase Handlers
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if player ~= Player then return end

	local pending = Core.State.purchasePending[passId]
	if not pending then return end

	Core.State.purchasePending[passId] = nil

	if purchased then
		ownershipCache:clear()

		if pending.product.purchaseButton then
			pending.product.purchaseButton.Text = "Owned"
			pending.product.purchaseButton.BackgroundColor3 = UI.Theme:get("success")
			pending.product.purchaseButton.Active = false
		end


		task.wait(0.5)
		shop:refreshAllProducts()
	else
		if pending.product.purchaseButton then
			pending.product.purchaseButton.Text = "Purchase"
			pending.product.purchaseButton.Active = true
		end
	end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, purchased)
	if player ~= Player then return end

	local pending = Core.State.purchasePending[productId]
	if not pending then return end

	Core.State.purchasePending[productId] = nil

	if purchased then

		if Remotes then
			local grantEvent = Remotes:FindFirstChild("GrantProductCurrency")
			if grantEvent and grantEvent:IsA("RemoteEvent") then
				grantEvent:FireServer(productId)
			end
		end
	end
end)

-- Initialize shop
local shop = Shop.new()

-- Handle character respawn
Player.CharacterAdded:Connect(function()
	task.wait(1)
	if not shop.toggleButton or not shop.toggleButton.Parent then
		shop:createToggleButton()
	end
end)

-- Auto-refresh ownership periodically
task.spawn(function()
	while true do
		task.wait(30)
		if Core.State.isOpen then
			shop:refreshAllProducts()
		end
	end
end)

print("[SanrioShop] System initialized successfully!")

return shop
