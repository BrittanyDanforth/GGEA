--[[
    SANRIO SHOP SYSTEM - MODERN UI REDESIGN
    Place this as a LocalScript in StarterPlayer > StarterPlayerScripts
    Name it: SanrioShop
    
    Features:
    - Modern glassmorphism design
    - Smooth animations and transitions
    - Premium card layouts
    - Particle effects
    - Responsive design
--]]

-- Services
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)

-- ========================================
-- CORE MODULE
-- ========================================
local Core = {}

Core.VERSION = "4.0.0"
Core.DEBUG = false

-- Constants
Core.CONSTANTS = {
	PANEL_SIZE = Vector2.new(1200, 900),
	PANEL_SIZE_MOBILE = Vector2.new(950, 750),
	CARD_SIZE = Vector2.new(340, 420),
	CARD_SIZE_MOBILE = Vector2.new(300, 380),

	ANIM_FAST = 0.2,
	ANIM_MEDIUM = 0.35,
	ANIM_SLOW = 0.5,
	ANIM_BOUNCE = 0.4,

	Z_BACKGROUND = 1,
	Z_CONTENT = 10,
	Z_OVERLAY = 20,
	Z_MODAL = 30,
	Z_TOOLTIP = 40,

	CACHE_PRODUCT_INFO = 300,
	CACHE_OWNERSHIP = 60,

	PURCHASE_TIMEOUT = 15,
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
		soundEnabled = true,
		animationsEnabled = true,
		particlesEnabled = true,
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

-- Sound System
Core.SoundSystem = {}

function Core.SoundSystem.initialize()
	local sounds = {
		click = {id = "rbxassetid://876939830", volume = 0.5},
		hover = {id = "rbxassetid://10066936758", volume = 0.3},
		open = {id = "rbxassetid://452267918", volume = 0.6},
		close = {id = "rbxassetid://452267918", volume = 0.6},
		success = {id = "rbxassetid://876939830", volume = 0.7},
		swoosh = {id = "rbxassetid://876939830", volume = 0.4},
	}

	Core.SoundSystem.sounds = {}

	for name, config in pairs(sounds) do
		local sound = Instance.new("Sound")
		sound.Name = "SanrioShop_" .. name
		sound.SoundId = config.id
		sound.Volume = config.volume
		sound.Parent = SoundService
		Core.SoundSystem.sounds[name] = sound
	end
end

function Core.SoundSystem.play(soundName)
	if not Core.State.settings.soundEnabled then return end

	local sound = Core.SoundSystem.sounds[soundName]
	if sound then
		sound:Play()
	end
end

-- Data Management
Core.DataManager = {}

Core.DataManager.products = {
	cash = {
		{
			id = 1897730242,
			amount = 1000,
			name = "Starter Pack",
			description = "Perfect for beginners",
			icon = "rbxassetid://10709728059",
			featured = false,
			price = 0,
			gradient = {Color3.fromRGB(255, 158, 197), Color3.fromRGB(255, 192, 213)},
		},
		{
			id = 1897730373,
			amount = 5000,
			name = "Growth Bundle",
			description = "Accelerate your progress",
			icon = "rbxassetid://10709728059",
			featured = true,
			price = 0,
			gradient = {Color3.fromRGB(165, 142, 251), Color3.fromRGB(196, 181, 253)},
		},
		{
			id = 1897730467,
			amount = 10000,
			name = "Pro Package",
			description = "For serious players",
			icon = "rbxassetid://10709728059",
			featured = false,
			price = 0,
			gradient = {Color3.fromRGB(129, 230, 217), Color3.fromRGB(169, 250, 240)},
		},
		{
			id = 1897730581,
			amount = 50000,
			name = "Ultimate Pack",
			description = "Maximum value bundle",
			icon = "rbxassetid://10709728059",
			featured = true,
			price = 0,
			gradient = {Color3.fromRGB(252, 214, 118), Color3.fromRGB(253, 230, 169)},
		},
	},
	gamepasses = {
		{
			id = 1412171840,
			name = "Auto Collect",
			description = "Collect cash automatically",
			icon = "rbxassetid://10709727148",
			price = 99,
			gradient = {Color3.fromRGB(88, 86, 214), Color3.fromRGB(139, 135, 255)},
			features = {
				"🤖 Hands-free collection",
				"⚡ Works while AFK",
				"⏱️ Saves time",
			},
			hasToggle = true,
		},
		{
			id = 1398974710,
			name = "2x Cash",
			description = "Double your earnings",
			icon = "rbxassetid://10709727148",
			price = 199,
			gradient = {Color3.fromRGB(240, 82, 100), Color3.fromRGB(255, 132, 146)},
			features = {
				"💰 2x multiplier",
				"🎯 Stacks with events",
				"⭐ Best value",
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
-- UI MODULE
-- ========================================
local UI = {}

-- Modern Theme System
UI.Theme = {
	current = "modern",
	themes = {
		modern = {
			-- Base colors
			background = Color3.fromRGB(15, 18, 28),
			surface = Color3.fromRGB(23, 27, 42),
			surfaceLight = Color3.fromRGB(31, 37, 56),
			surfaceGlass = Color3.fromRGB(255, 255, 255),
			
			-- Text colors
			text = Color3.fromRGB(255, 255, 255),
			textSecondary = Color3.fromRGB(156, 163, 175),
			textMuted = Color3.fromRGB(107, 114, 128),
			
			-- Accent colors
			accent = Color3.fromRGB(139, 92, 246),
			accentBright = Color3.fromRGB(167, 139, 250),
			success = Color3.fromRGB(52, 211, 153),
			warning = Color3.fromRGB(251, 191, 36),
			error = Color3.fromRGB(248, 113, 113),
			
			-- Gradient colors
			gradientPurple = {Color3.fromRGB(139, 92, 246), Color3.fromRGB(219, 39, 119)},
			gradientBlue = {Color3.fromRGB(59, 130, 246), Color3.fromRGB(147, 51, 234)},
			gradientGreen = {Color3.fromRGB(52, 211, 153), Color3.fromRGB(59, 130, 246)},
			gradientPink = {Color3.fromRGB(236, 72, 153), Color3.fromRGB(239, 68, 68)},
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
		if key ~= "children" and key ~= "parent" and key ~= "onClick" and 
			key ~= "cornerRadius" and key ~= "stroke" and key ~= "gradient" and 
			key ~= "glassmorphism" and key ~= "glow" and key ~= "layout" and key ~= "padding" then

			if type(value) == "function" and key:sub(1, 2) == "on" then
				local eventName = key:sub(3)
				pcall(function()
					local connection = self.instance[eventName]:Connect(value)
					table.insert(self.eventConnections, connection)
				end)
			else
				pcall(function()
					self.instance[key] = value
				end)
			end
		end
	end

	if self.props.onClick and self.instance:IsA("TextButton") then
		local connection = self.instance.MouseButton1Click:Connect(self.props.onClick)
		table.insert(self.eventConnections, connection)
	end
end

function Component:render()
	self:applyProps()

	-- Corner radius
	if self.props.cornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = self.props.cornerRadius
		corner.Parent = self.instance
	end

	-- Stroke
	if self.props.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = self.props.stroke.color or UI.Theme:get("surfaceLight")
		stroke.Thickness = self.props.stroke.thickness or 1
		stroke.Transparency = self.props.stroke.transparency or 0
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = self.instance
	end

	-- Gradient
	if self.props.gradient then
		local gradient = Instance.new("UIGradient")
		if type(self.props.gradient) == "table" and #self.props.gradient == 2 then
			gradient.Color = ColorSequence.new(self.props.gradient[1], self.props.gradient[2])
		end
		gradient.Rotation = self.props.gradientRotation or 45
		gradient.Parent = self.instance
	end

	-- Glassmorphism effect
	if self.props.glassmorphism then
		self.instance.BackgroundTransparency = 0.3
		
		local blur = Instance.new("ImageLabel")
		blur.Name = "BlurEffect"
		blur.Size = UDim2.fromScale(1, 1)
		blur.BackgroundTransparency = 1
		blur.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
		blur.ImageTransparency = 0.95
		blur.ZIndex = self.instance.ZIndex - 1
		blur.Parent = self.instance
	end

	-- Glow effect
	if self.props.glow then
		local glow = Instance.new("ImageLabel")
		glow.Name = "Glow"
		glow.Size = UDim2.fromScale(1.2, 1.2)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.BackgroundTransparency = 1
		glow.Image = "rbxassetid://4560909609"
		glow.ImageColor3 = self.props.glow.color or UI.Theme:get("accent")
		glow.ImageTransparency = self.props.glow.transparency or 0.7
		glow.ZIndex = self.instance.ZIndex - 1
		glow.Parent = self.instance
	end

	-- Layout
	if self.props.layout then
		local layoutType = self.props.layout.type or "List"
		local layout = Instance.new("UI" .. layoutType .. "Layout")

		for key, value in pairs(self.props.layout) do
			if key ~= "type" then
				pcall(function()
					layout[key] = value
				end)
			end
		end

		layout.Parent = self.instance
	end

	-- Padding
	if self.props.padding then
		local padding = Instance.new("UIPadding")
		if type(self.props.padding) == "number" then
			padding.PaddingTop = UDim.new(0, self.props.padding)
			padding.PaddingBottom = UDim.new(0, self.props.padding)
			padding.PaddingLeft = UDim.new(0, self.props.padding)
			padding.PaddingRight = UDim.new(0, self.props.padding)
		else
			if self.props.padding.top then padding.PaddingTop = UDim.new(0, self.props.padding.top) end
			if self.props.padding.bottom then padding.PaddingBottom = UDim.new(0, self.props.padding.bottom) end
			if self.props.padding.left then padding.PaddingLeft = UDim.new(0, self.props.padding.left) end
			if self.props.padding.right then padding.PaddingRight = UDim.new(0, self.props.padding.right) end
		end
		padding.Parent = self.instance
	end

	-- Children
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

	return Component.new("Frame", props)
end

-- Text Label Component
function UI.Components.TextLabel(props)
	local defaultProps = {
		BackgroundTransparency = 1,
		TextColor3 = UI.Theme:get("text"),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
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
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		Size = UDim2.fromOffset(120, 40),
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}

	for key, value in pairs(defaultProps) do
		if props[key] == nil then
			props[key] = value
		end
	end

	return Component.new("TextButton", props)
end

-- Image Component
function UI.Components.Image(props)
	local defaultProps = {
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(100, 100),
		BorderSizePixel = 0,
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
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UI.Theme:get("accent"),
		ScrollBarImageTransparency = 0.5,
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

	-- Auto-size canvas with layout
	if props.layout then
		task.defer(function()
			local layout = component.instance:FindFirstChildOfClass("UIListLayout") or 
				component.instance:FindFirstChildOfClass("UIGridLayout")
			
			if layout then
				layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
					if props.ScrollingDirection == Enum.ScrollingDirection.X then
						component.instance.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X + 20, 0, 0)
					else
						component.instance.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
					end
				end)
			end
		end)
	end

	return component
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
		scaleFactor = Core.Utils.clamp(scaleFactor, 0.6, 1.2)

		if Core.Utils.isMobile() then
			scaleFactor = scaleFactor * 0.9
		end

		scale.Scale = scaleFactor
	end

	updateScale()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

	return scale
end

-- ========================================
-- MAIN SHOP IMPLEMENTATION
-- ========================================
local Shop = {}
Shop.__index = Shop

function Shop.new()
	local self = setmetatable({}, Shop)

	self.gui = nil
	self.mainPanel = nil
	self.contentContainer = nil
	self.currentTab = "Home"
	self.tabs = {}
	self.pages = {}
	self.toggleButton = nil
	self.blur = nil
	self.particles = {}

	self:initialize()

	return self
end

function Shop:initialize()
	Core.SoundSystem.initialize()
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

	-- Main button with glassmorphism
	self.toggleButton = UI.Components.Button({
		Name = "ShopToggle",
		Text = "",
		Size = UDim2.fromOffset(220, 70),
		Position = UDim2.new(1, -30, 1, -30),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = UI.Theme:get("surfaceGlass"),
		BackgroundTransparency = 0.2,
		cornerRadius = UDim.new(0, 20),
		stroke = {
			color = UI.Theme:get("accent"),
			thickness = 2,
			transparency = 0.3,
		},
		parent = toggleScreen,
		onClick = function()
			self:toggle()
		end,
	}):render()

	-- Gradient overlay
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(UI.Theme:get("accent"), UI.Theme:get("accentBright"))
	gradient.Rotation = 135
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	gradient.Parent = self.toggleButton

	-- Glow effect
	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.Size = UDim2.fromScale(1.3, 1.3)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundTransparency = 1
	glow.Image = "rbxassetid://4560909609"
	glow.ImageColor3 = UI.Theme:get("accent")
	glow.ImageTransparency = 0.6
	glow.ZIndex = self.toggleButton.ZIndex - 1
	glow.Parent = self.toggleButton

	-- Icon
	local iconContainer = UI.Components.Frame({
		Name = "IconContainer",
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = UI.Theme:get("accent"),
		cornerRadius = UDim.new(0, 15),
		parent = self.toggleButton,
	}):render()

	local iconGradient = Instance.new("UIGradient")
	iconGradient.Color = ColorSequence.new(UI.Theme:get("accent"), UI.Theme:get("accentBright"))
	iconGradient.Rotation = 45
	iconGradient.Parent = iconContainer

	local icon = UI.Components.Image({
		Name = "Icon",
		Image = "rbxassetid://17398522865",
		Size = UDim2.fromScale(0.7, 0.7),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		parent = iconContainer,
	}):render()

	-- Text container
	local textContainer = UI.Components.Frame({
		Name = "TextContainer",
		Size = UDim2.new(1, -80, 1, 0),
		Position = UDim2.fromOffset(70, 0),
		BackgroundTransparency = 1,
		parent = self.toggleButton,
	}):render()

	local label = UI.Components.TextLabel({
		Name = "Label",
		Text = "SHOP",
		Size = UDim2.fromScale(1, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1),
		parent = textContainer,
	}):render()

	local sublabel = UI.Components.TextLabel({
		Name = "Sublabel",
		Text = "Open Store",
		Size = UDim2.fromScale(1, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = UI.Theme:get("textSecondary"),
		parent = textContainer,
	}):render()

	-- Animated glow pulse
	self:addGlowPulse(glow)
end

function Shop:addGlowPulse(glow)
	task.spawn(function()
		while glow and glow.Parent do
			Core.Animation.tween(glow, {
				ImageTransparency = 0.3,
				Size = UDim2.fromScale(1.4, 1.4),
			}, 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(2)

			if not glow or not glow.Parent then break end

			Core.Animation.tween(glow, {
				ImageTransparency = 0.7,
				Size = UDim2.fromScale(1.3, 1.3),
			}, 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(2)
		end
	end)
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

	-- Dim background
	local dimBackground = UI.Components.Frame({
		Name = "DimBackground",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.2,
		parent = self.gui,
	}):render()

	-- Animated gradient background
	local gradientBg = UI.Components.Frame({
		Name = "GradientBackground",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.95,
		gradient = UI.Theme:get("gradientPurple"),
		gradientRotation = 135,
		parent = self.gui,
	}):render()

	-- Main panel
	local panelSize = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE

	self.mainPanel = UI.Components.Frame({
		Name = "MainPanel",
		Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UI.Theme:get("surface"),
		BackgroundTransparency = 0.1,
		cornerRadius = UDim.new(0, 30),
		stroke = {
			color = UI.Theme:get("surfaceLight"),
			thickness = 2,
			transparency = 0.5,
		},
		parent = self.gui,
	}):render()

	-- Panel glow
	local panelGlow = Instance.new("ImageLabel")
	panelGlow.Name = "PanelGlow"
	panelGlow.Size = UDim2.fromScale(1.1, 1.1)
	panelGlow.Position = UDim2.fromScale(0.5, 0.5)
	panelGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	panelGlow.BackgroundTransparency = 1
	panelGlow.Image = "rbxassetid://4560909609"
	panelGlow.ImageColor3 = UI.Theme:get("accent")
	panelGlow.ImageTransparency = 0.8
	panelGlow.ZIndex = self.mainPanel.ZIndex - 1
	panelGlow.Parent = self.mainPanel

	UI.Responsive.scale(self.mainPanel)

	self:createHeader()
	self:createNavBar()

	self.contentContainer = UI.Components.Frame({
		Name = "ContentContainer",
		Size = UDim2.new(1, -60, 1, -210),
		Position = UDim2.fromOffset(30, 180),
		BackgroundTransparency = 1,
		parent = self.mainPanel,
	}):render()

	self:createPages()
	self:selectTab("Home")

	-- Add floating particles if enabled
	if Core.State.settings.particlesEnabled then
		self:createParticles()
	end
end

function Shop:createHeader()
	local header = UI.Components.Frame({
		Name = "Header",
		Size = UDim2.new(1, -60, 0, 100),
		Position = UDim2.fromOffset(30, 30),
		BackgroundColor3 = UI.Theme:get("surfaceLight"),
		BackgroundTransparency = 0.3,
		cornerRadius = UDim.new(0, 20),
		parent = self.mainPanel,
	}):render()

	-- Header gradient
	local headerGradient = Instance.new("UIGradient")
	headerGradient.Color = ColorSequence.new(UI.Theme:get("accent"), UI.Theme:get("accentBright"))
	headerGradient.Rotation = 90
	headerGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0.95),
	})
	headerGradient.Parent = header

	-- Logo container
	local logoContainer = UI.Components.Frame({
		Name = "LogoContainer",
		Size = UDim2.fromOffset(70, 70),
		Position = UDim2.fromOffset(15, 15),
		BackgroundColor3 = UI.Theme:get("accent"),
		cornerRadius = UDim.new(0, 18),
		gradient = UI.Theme:get("gradientPurple"),
		parent = header,
	}):render()

	local logo = UI.Components.Image({
		Name = "Logo",
		Image = "rbxassetid://17398522865",
		Size = UDim2.fromScale(0.7, 0.7),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		parent = logoContainer,
	}):render()

	-- Title section
	local titleContainer = UI.Components.Frame({
		Name = "TitleContainer",
		Size = UDim2.new(1, -250, 1, 0),
		Position = UDim2.fromOffset(105, 0),
		BackgroundTransparency = 1,
		parent = header,
	}):render()

	local title = UI.Components.TextLabel({
		Name = "Title",
		Text = "Sanrio Shop",
		Size = UDim2.fromScale(1, 0.55),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 36,
		parent = titleContainer,
	}):render()

	local subtitle = UI.Components.TextLabel({
		Name = "Subtitle",
		Text = "✨ Premium Items & Power-ups",
		Size = UDim2.fromScale(1, 0.45),
		Position = UDim2.fromScale(0, 0.55),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = UI.Theme:get("textSecondary"),
		parent = titleContainer,
	}):render()

	-- Close button
	local closeButton = UI.Components.Button({
		Name = "CloseButton",
		Text = "✕",
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.new(1, -80, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = UI.Theme:get("error"),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 28,
		cornerRadius = UDim.new(0, 18),
		parent = header,
		onClick = function()
			self:close()
		end,
	}):render()

	-- Close button hover effect
	closeButton.MouseEnter:Connect(function()
		Core.SoundSystem.play("hover")
		Core.Animation.tween(closeButton, {
			Size = UDim2.fromOffset(65, 65),
			BackgroundColor3 = Core.Utils.blend(UI.Theme:get("error"), Color3.new(1, 1, 1), 0.2),
		}, Core.CONSTANTS.ANIM_FAST)
	end)

	closeButton.MouseLeave:Connect(function()
		Core.Animation.tween(closeButton, {
			Size = UDim2.fromOffset(60, 60),
			BackgroundColor3 = UI.Theme:get("error"),
		}, Core.CONSTANTS.ANIM_FAST)
	end)
end

function Shop:createNavBar()
	local navBar = UI.Components.Frame({
		Name = "NavBar",
		Size = UDim2.new(1, -60, 0, 60),
		Position = UDim2.fromOffset(30, 145),
		BackgroundColor3 = UI.Theme:get("surfaceLight"),
		BackgroundTransparency = 0.5,
		cornerRadius = UDim.new(0, 18),
		padding = 10,
		layout = {
			type = "List",
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},
		parent = self.mainPanel,
	}):render()

	local tabData = {
		{id = "Home", name = "🏠 Home", gradient = UI.Theme:get("gradientPurple")},
		{id = "Cash", name = "💰 Cash Packs", gradient = UI.Theme:get("gradientGreen")},
		{id = "Gamepasses", name = "⭐ Power-ups", gradient = UI.Theme:get("gradientPink")},
	}

	for _, data in ipairs(tabData) do
		self:createTab(data, navBar)
	end
end

function Shop:createTab(data, parent)
	local tab = UI.Components.Button({
		Name = data.id .. "Tab",
		Text = data.name,
		Size = UDim2.fromOffset(200, 44),
		BackgroundColor3 = UI.Theme:get("surface"),
		TextColor3 = UI.Theme:get("text"),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		cornerRadius = UDim.new(0, 12),
		stroke = {
			color = UI.Theme:get("surfaceLight"),
			thickness = 1.5,
			transparency = 0.6,
		},
		parent = parent,
		onClick = function()
			self:selectTab(data.id)
		end,
	}):render()

	-- Tab hover effect
	tab.MouseEnter:Connect(function()
		if self.currentTab ~= data.id then
			Core.SoundSystem.play("hover")
			Core.Animation.tween(tab, {
				BackgroundColor3 = UI.Theme:get("surfaceLight"),
				Size = UDim2.fromOffset(205, 46),
			}, Core.CONSTANTS.ANIM_FAST)
		end
	end)

	tab.MouseLeave:Connect(function()
		if self.currentTab ~= data.id then
			Core.Animation.tween(tab, {
				BackgroundColor3 = UI.Theme:get("surface"),
				Size = UDim2.fromOffset(200, 44),
			}, Core.CONSTANTS.ANIM_FAST)
		end
	end)

	self.tabs[data.id] = {
		button = tab,
		data = data,
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
			Padding = UDim.new(0, 30),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		},
		padding = 15,
		parent = page,
	}):render()

	-- Hero banner
	self:createHeroBanner(scrollFrame)

	-- Featured section
	local featuredTitle = UI.Components.TextLabel({
		Text = "⚡ Featured Items",
		Size = UDim2.new(1, 0, 0, 50),
		Font = Enum.Font.GothamBold,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		parent = scrollFrame,
	}):render()

	local featuredContainer = UI.Components.Frame({
		Size = UDim2.new(1, 0, 0, 450),
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
			Padding = UDim.new(0, 20),
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
			CellPadding = UDim2.fromOffset(25, 25),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		},
		padding = 15,
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
			CellPadding = UDim2.fromOffset(25, 25),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		},
		padding = 15,
		parent = page,
	}):render()

	for _, pass in ipairs(Core.DataManager.products.gamepasses) do
		self:createProductCard(pass, "gamepass", scrollFrame)
	end

	return page
end

function Shop:createHeroBanner(parent)
	local hero = UI.Components.Frame({
		Name = "HeroSection",
		Size = UDim2.new(1, 0, 0, 250),
		BackgroundColor3 = UI.Theme:get("surfaceLight"),
		cornerRadius = UDim.new(0, 24),
		LayoutOrder = 1,
		parent = parent,
	}):render()

	-- Hero gradient
	local heroGradient = Instance.new("UIGradient")
	heroGradient.Color = ColorSequence.new(UI.Theme:get("accent"), UI.Theme:get("accentBright"))
	heroGradient.Rotation = 135
	heroGradient.Parent = hero

	-- Content
	local content = UI.Components.Frame({
		Size = UDim2.new(1, -60, 1, -60),
		Position = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		parent = hero,
	}):render()

	local heroTitle = UI.Components.TextLabel({
		Text = "Welcome to Sanrio Shop! 🌸",
		Size = UDim2.new(1, 0, 0, 60),
		Font = Enum.Font.GothamBold,
		TextSize = 42,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = content,
	}):render()

	local heroDesc = UI.Components.TextLabel({
		Text = "Unlock exclusive items and power-ups to boost your tycoon!",
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.fromOffset(0, 70),
		Font = Enum.Font.Gotham,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = content,
	}):render()

	local ctaButton = UI.Components.Button({
		Text = "🛍️ Browse All Items",
		Size = UDim2.fromOffset(240, 60),
		Position = UDim2.fromOffset(0, 140),
		BackgroundColor3 = Color3.new(1, 1, 1),
		TextColor3 = UI.Theme:get("accent"),
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		cornerRadius = UDim.new(0, 16),
		parent = content,
		onClick = function()
			self:selectTab("Cash")
		end,
	}):render()

	-- CTA button hover
	ctaButton.MouseEnter:Connect(function()
		Core.SoundSystem.play("hover")
		Core.Animation.tween(ctaButton, {
			Size = UDim2.fromOffset(250, 65),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		}, Core.CONSTANTS.ANIM_FAST)
	end)

	ctaButton.MouseLeave:Connect(function()
		Core.Animation.tween(ctaButton, {
			Size = UDim2.fromOffset(240, 60),
			BackgroundColor3 = Color3.new(1, 1, 1),
		}, Core.CONSTANTS.ANIM_FAST)
	end)

	return hero
end

function Shop:createProductCard(product, productType, parent)
	local isGamepass = productType == "gamepass"

	-- Main card
	local card = UI.Components.Frame({
		Name = product.name .. "Card",
		Size = UDim2.fromOffset(
			Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.X or Core.CONSTANTS.CARD_SIZE.X,
			Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.Y or Core.CONSTANTS.CARD_SIZE.Y
		),
		BackgroundColor3 = UI.Theme:get("surface"),
		BackgroundTransparency = 0.2,
		cornerRadius = UDim.new(0, 24),
		stroke = {
			color = product.gradient and product.gradient[1] or UI.Theme:get("accent"),
			thickness = 2,
			transparency = 0.5,
		},
		parent = parent,
	}):render()

	-- Card glow
	local cardGlow = Instance.new("ImageLabel")
	cardGlow.Name = "CardGlow"
	cardGlow.Size = UDim2.fromScale(1.15, 1.15)
	cardGlow.Position = UDim2.fromScale(0.5, 0.5)
	cardGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	cardGlow.BackgroundTransparency = 1
	cardGlow.Image = "rbxassetid://4560909609"
	cardGlow.ImageColor3 = product.gradient and product.gradient[1] or UI.Theme:get("accent")
	cardGlow.ImageTransparency = 0.85
	cardGlow.ZIndex = card.ZIndex - 1
	cardGlow.Parent = card

	-- Content container
	local content = UI.Components.Frame({
		Size = UDim2.new(1, -30, 1, -30),
		Position = UDim2.fromOffset(15, 15),
		BackgroundTransparency = 1,
		parent = card,
	}):render()

	-- Image section with gradient background
	local imageSection = UI.Components.Frame({
		Size = UDim2.new(1, 0, 0, 200),
		BackgroundColor3 = Color3.new(1, 1, 1),
		cornerRadius = UDim.new(0, 18),
		gradient = product.gradient,
		parent = content,
	}):render()

	local productImage = UI.Components.Image({
		Image = product.icon or "rbxassetid://0",
		Size = UDim2.fromScale(0.6, 0.6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ScaleType = Enum.ScaleType.Fit,
		parent = imageSection,
	}):render()

	-- Info section
	local infoSection = UI.Components.Frame({
		Size = UDim2.new(1, 0, 1, -220),
		Position = UDim2.fromOffset(0, 220),
		BackgroundTransparency = 1,
		parent = content,
	}):render()

	-- Title
	local title = UI.Components.TextLabel({
		Text = product.name,
		Size = UDim2.new(1, 0, 0, 35),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = infoSection,
	}):render()

	-- Description
	local description = UI.Components.TextLabel({
		Text = product.description,
		Size = UDim2.new(1, 0, 0, 45),
		Position = UDim2.fromOffset(0, 40),
		Font = Enum.Font.Gotham,
		TextSize = 15,
		TextColor3 = UI.Theme:get("textSecondary"),
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = infoSection,
	}):render()

	-- Features (for gamepasses)
	if isGamepass and product.features then
		local featuresContainer = UI.Components.Frame({
			Size = UDim2.new(1, 0, 0, 60),
			Position = UDim2.fromOffset(0, 90),
			BackgroundTransparency = 1,
			layout = {
				type = "List",
				Padding = UDim.new(0, 6),
			},
			parent = infoSection,
		}):render()

		for _, feature in ipairs(product.features) do
			local featureLabel = UI.Components.TextLabel({
				Text = feature,
				Size = UDim2.new(1, 0, 0, 18),
				Font = Enum.Font.Gotham,
				TextSize = 13,
				TextColor3 = UI.Theme:get("textSecondary"),
				TextXAlignment = Enum.TextXAlignment.Left,
				parent = featuresContainer,
			}):render()
		end
	end

	-- Price and button container
	local bottomSection = UI.Components.Frame({
		Size = UDim2.new(1, 0, 0, 55),
		Position = UDim2.new(0, 0, 1, -55),
		BackgroundTransparency = 1,
		parent = infoSection,
	}):render()

	-- Price label
	local priceText = isGamepass and 
		("R$" .. tostring(product.price or 0)) or 
		("R$" .. tostring(product.price or 0))
	
	local amountText = not isGamepass and 
		("\n" .. Core.Utils.formatNumber(product.amount) .. " Cash") or ""

	local priceLabel = UI.Components.TextLabel({
		Text = priceText .. amountText,
		Size = UDim2.new(0.4, 0, 1, 0),
		Font = Enum.Font.GothamBold,
		TextSize = isGamepass and 24 or 20,
		TextColor3 = product.gradient and product.gradient[1] or UI.Theme:get("accent"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		parent = bottomSection,
	}):render()

	-- Purchase button
	local isOwned = isGamepass and Core.DataManager.checkOwnership(product.id)

	local purchaseButton = UI.Components.Button({
		Text = isOwned and "✓ Owned" or "Purchase",
		Size = UDim2.new(0.55, 0, 1, 0),
		Position = UDim2.new(0.45, 0, 0, 0),
		BackgroundColor3 = isOwned and UI.Theme:get("success") or 
			(product.gradient and product.gradient[1] or UI.Theme:get("accent")),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		cornerRadius = UDim.new(0, 14),
		parent = bottomSection,
		onClick = function()
			if not isOwned then
				self:promptPurchase(product, productType)
			elseif product.hasToggle then
				self:toggleGamepass(product)
			end
		end,
	}):render()

	-- Button gradient
	if product.gradient and not isOwned then
		local buttonGradient = Instance.new("UIGradient")
		buttonGradient.Color = ColorSequence.new(product.gradient[1], product.gradient[2])
		buttonGradient.Rotation = 45
		buttonGradient.Parent = purchaseButton
	end

	-- Button hover effect
	purchaseButton.MouseEnter:Connect(function()
		if not isOwned or product.hasToggle then
			Core.SoundSystem.play("hover")
			Core.Animation.tween(purchaseButton, {
				Size = UDim2.new(0.58, 0, 1.1, 0),
			}, Core.CONSTANTS.ANIM_FAST)
		end
	end)

	purchaseButton.MouseLeave:Connect(function()
		Core.Animation.tween(purchaseButton, {
			Size = UDim2.new(0.55, 0, 1, 0),
		}, Core.CONSTANTS.ANIM_FAST)
	end)

	-- Card hover effect
	self:addCardHoverEffect(card, cardGlow)

	-- Toggle switch for gamepasses with toggle
	if isOwned and product.hasToggle then
		self:addToggleSwitch(product, infoSection)
	end

	product.cardInstance = card
	product.purchaseButton = purchaseButton

	return card
end

function Shop:addCardHoverEffect(card, glow)
	local originalPosition = card.Position

	card.MouseEnter:Connect(function()
		Core.Animation.tween(card, {
			Position = UDim2.new(
				originalPosition.X.Scale,
				originalPosition.X.Offset,
				originalPosition.Y.Scale,
				originalPosition.Y.Offset - 10
			)
		}, Core.CONSTANTS.ANIM_FAST)

		Core.Animation.tween(glow, {
			ImageTransparency = 0.7,
		}, Core.CONSTANTS.ANIM_FAST)
	end)

	card.MouseLeave:Connect(function()
		Core.Animation.tween(card, {
			Position = originalPosition
		}, Core.CONSTANTS.ANIM_FAST)

		Core.Animation.tween(glow, {
			ImageTransparency = 0.85,
		}, Core.CONSTANTS.ANIM_FAST)
	end)
end

function Shop:addToggleSwitch(product, parent)
	local toggleContainer = UI.Components.Frame({
		Name = "ToggleContainer",
		Size = UDim2.fromOffset(70, 35),
		Position = UDim2.new(1, -70, 0, 92),
		BackgroundColor3 = UI.Theme:get("surfaceLight"),
		cornerRadius = UDim.new(1, 0),
		parent = parent,
	}):render()

	local toggleButton = UI.Components.Frame({
		Name = "ToggleButton",
		Size = UDim2.fromOffset(29, 29),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		cornerRadius = UDim.new(1, 0),
		parent = toggleContainer,
	}):render()

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
			toggleContainer.BackgroundColor3 = UI.Theme:get("success")
			Core.Animation.tween(toggleButton, {
				Position = UDim2.fromOffset(38, 3)
			}, Core.CONSTANTS.ANIM_FAST)
		else
			toggleContainer.BackgroundColor3 = UI.Theme:get("surfaceLight")
			Core.Animation.tween(toggleButton, {
				Position = UDim2.fromOffset(3, 3)
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

		Core.SoundSystem.play("click")
	end)
end

function Shop:createParticles()
	-- Create floating particles in the background
	for i = 1, 15 do
		local particle = Instance.new("Frame")
		particle.Name = "Particle" .. i
		particle.Size = UDim2.fromOffset(math.random(4, 10), math.random(4, 10))
		particle.Position = UDim2.fromScale(math.random(), math.random())
		particle.BackgroundColor3 = UI.Theme:get("accent")
		particle.BackgroundTransparency = math.random(70, 90) / 100
		particle.BorderSizePixel = 0
		particle.ZIndex = 0
		particle.Parent = self.mainPanel

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = particle

		table.insert(self.particles, particle)

		-- Animate particle
		task.spawn(function()
			while particle and particle.Parent do
				local duration = math.random(30, 60) / 10
				Core.Animation.tween(particle, {
					Position = UDim2.fromScale(math.random(), math.random()),
					BackgroundTransparency = math.random(60, 95) / 100,
				}, duration, Enum.EasingStyle.Sine)
				task.wait(duration)
			end
		end)
	end
end

function Shop:selectTab(tabId)
	if self.currentTab == tabId then return end

	for id, tab in pairs(self.tabs) do
		local isActive = id == tabId

		if isActive then
			-- Active tab styling
			Core.Animation.tween(tab.button, {
				BackgroundColor3 = tab.data.gradient and tab.data.gradient[1] or UI.Theme:get("accent"),
				Size = UDim2.fromOffset(205, 46),
			}, Core.CONSTANTS.ANIM_FAST)

			local stroke = tab.button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = tab.data.gradient and tab.data.gradient[1] or UI.Theme:get("accent")
				stroke.Transparency = 0
			end

			-- Add gradient to active tab
			if not tab.button:FindFirstChildOfClass("UIGradient") and tab.data.gradient then
				local gradient = Instance.new("UIGradient")
				gradient.Color = ColorSequence.new(tab.data.gradient[1], tab.data.gradient[2])
				gradient.Rotation = 45
				gradient.Parent = tab.button
			end
		else
			-- Inactive tab styling
			Core.Animation.tween(tab.button, {
				BackgroundColor3 = UI.Theme:get("surface"),
				Size = UDim2.fromOffset(200, 44),
			}, Core.CONSTANTS.ANIM_FAST)

			local stroke = tab.button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = UI.Theme:get("surfaceLight")
				stroke.Transparency = 0.6
			end

			-- Remove gradient from inactive tab
			local gradient = tab.button:FindFirstChildOfClass("UIGradient")
			if gradient then
				gradient:Destroy()
			end
		end
	end

	-- Switch pages with animation
	for id, page in pairs(self.pages) do
		if id == tabId then
			page.Visible = true
			page.Position = UDim2.fromOffset(0, 30)
			Core.Animation.tween(page, {
				Position = UDim2.new()
			}, Core.CONSTANTS.ANIM_MEDIUM, Enum.EasingStyle.Back)
		else
			page.Visible = false
		end
	end

	self.currentTab = tabId
	Core.SoundSystem.play("swoosh")
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
			product.purchaseButton.Text = isOwned and "✓ Owned" or "Purchase"
			product.purchaseButton.BackgroundColor3 = isOwned and 
				UI.Theme:get("success") or 
				(product.gradient and product.gradient[1] or UI.Theme:get("accent"))
			product.purchaseButton.Active = not isOwned
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

	-- Animate blur
	Core.Animation.tween(self.blur, {
		Size = 20
	}, Core.CONSTANTS.ANIM_MEDIUM)

	-- Animate panel entrance
	self.mainPanel.Position = UDim2.fromScale(0.5, 0.6)
	self.mainPanel.Size = UDim2.fromOffset(
		self.mainPanel.Size.X.Offset * 0.85,
		self.mainPanel.Size.Y.Offset * 0.85
	)

	local panelSize = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE
	
	Core.Animation.tween(self.mainPanel, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(panelSize.X, panelSize.Y)
	}, Core.CONSTANTS.ANIM_BOUNCE, Enum.EasingStyle.Back)

	Core.SoundSystem.play("open")

	task.wait(Core.CONSTANTS.ANIM_BOUNCE)
	Core.State.isAnimating = false

	Core.Events:emit("shopOpened")
end

function Shop:close()
	if not Core.State.isOpen or Core.State.isAnimating then return end

	Core.State.isAnimating = true
	Core.State.isOpen = false

	-- Animate blur
	Core.Animation.tween(self.blur, {
		Size = 0
	}, Core.CONSTANTS.ANIM_FAST)

	-- Animate panel exit
	Core.Animation.tween(self.mainPanel, {
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromOffset(
			self.mainPanel.Size.X.Offset * 0.85,
			self.mainPanel.Size.Y.Offset * 0.85
		)
	}, Core.CONSTANTS.ANIM_FAST)

	Core.SoundSystem.play("close")

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
			Core.SoundSystem.play("success")
		end)
	end

	local productGrant = Remotes:FindFirstChild("ProductGranted") or Remotes:FindFirstChild("GrantProductCurrency")
	if productGrant and productGrant:IsA("RemoteEvent") then
		productGrant.OnClientEvent:Connect(function(productId, amount)
			Core.SoundSystem.play("success")
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
			pending.product.purchaseButton.Text = "✓ Owned"
			pending.product.purchaseButton.BackgroundColor3 = UI.Theme:get("success")
			pending.product.purchaseButton.Active = false
		end

		Core.SoundSystem.play("success")

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
		Core.SoundSystem.play("success")

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

print("[SanrioShop] Modern UI v4.0.0 initialized successfully! ✨")

return shop
