--[[
    SANRIO SHOP SYSTEM - PASTEL DREAM REVAMP
    A soft, gentle shopping experience with pastel aesthetics
    Place this as a LocalScript in StarterPlayer > StarterPlayerScripts
    Name it: SanrioShop_Pastel

    ✨ Soft Design Features:
    • Gentle pastel color palette
    • Subtle glassmorphism without harsh effects
    • Rounded corners and soft shadows
    • Smooth, calming animations
    • Clean, friendly interface
    • Sanrio character-inspired soft colors
--]]

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
local Debris = game:GetService("Debris")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)

-- ========================================
-- CORE MODULE (Embedded)
-- ========================================
local Core = {}

Core.VERSION = "5.0.0"
Core.DEBUG = false

-- Constants
Core.CONSTANTS = {
	PANEL_SIZE = Vector2.new(1280, 820),
	PANEL_SIZE_MOBILE = Vector2.new(1000, 760),
	CARD_SIZE = Vector2.new(320, 380),
	CARD_SIZE_MOBILE = Vector2.new(280, 340),

	ANIM_FAST = 0.2,
	ANIM_MEDIUM = 0.3,
	ANIM_SLOW = 0.4,
	ANIM_BOUNCE = 0.5,
	ANIM_SMOOTH = 0.6,

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
		soundEnabled = true,
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
	easingStyle = easingStyle or Enum.EasingStyle.Quart
	easingDirection = easingDirection or Enum.EasingDirection.Out

	local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection)
	local tween = TweenService:Create(object, tweenInfo, properties)
	tween:Play()
	return tween
end

function Core.Animation.pulse(object, scale, duration)
	local originalSize = object.Size
	local targetSize = UDim2.new(
		originalSize.X.Scale * scale,
		originalSize.X.Offset * scale,
		originalSize.Y.Scale * scale,
		originalSize.Y.Offset * scale
	)

	Core.Animation.tween(object, {Size = targetSize}, duration / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	task.wait(duration / 2)
	Core.Animation.tween(object, {Size = originalSize}, duration / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
end

-- ========================================
-- UI MODULE - PASTEL DREAM DESIGN
-- ========================================
local UI = {}

-- Soft Pastel Theme System
UI.Theme = {
	current = "pastel",
	themes = {
		pastel = {
			-- Soft, gentle background colors
			background = Color3.fromRGB(250, 248, 255),
			surface = Color3.fromRGB(255, 255, 255),
			surfaceAlt = Color3.fromRGB(248, 245, 255),
			surfaceSoft = Color3.fromRGB(245, 242, 255),

			-- Subtle stroke colors
			stroke = Color3.fromRGB(220, 215, 235),
			strokeBright = Color3.fromRGB(200, 195, 220),
			strokeSoft = Color3.fromRGB(235, 230, 245),

			-- Gentle text colors
			text = Color3.fromRGB(60, 55, 80),
			textSecondary = Color3.fromRGB(120, 115, 140),
			textMuted = Color3.fromRGB(160, 155, 180),

			-- Soft accent colors inspired by Sanrio characters
			accent = Color3.fromRGB(255, 120, 180),     -- Soft pink
			accentAlt = Color3.fromRGB(180, 160, 255),  -- Soft purple
			accentSoft = Color3.fromRGB(255, 180, 200), -- Very soft pink

			-- Status colors (soft versions)
			success = Color3.fromRGB(120, 220, 150),
			warning = Color3.fromRGB(255, 200, 120),
			error = Color3.fromRGB(255, 120, 140),

			-- Sanrio character soft colors
			kitty = Color3.fromRGB(255, 140, 180),     -- Hello Kitty soft pink
			melody = Color3.fromRGB(255, 160, 200),    -- My Melody soft pink
			kuromi = Color3.fromRGB(180, 140, 220),    -- Kuromi soft purple
			cinna = Color3.fromRGB(160, 200, 255),     -- Cinnamoroll soft blue
			pompom = Color3.fromRGB(255, 200, 140),    -- Pompompurin soft yellow

			-- Soft gradient colors
			gradient1 = Color3.fromRGB(255, 180, 220),
			gradient2 = Color3.fromRGB(180, 160, 255),
			gradient3 = Color3.fromRGB(160, 200, 255),

			-- Glass morphism (very subtle)
			glass = Color3.fromRGB(255, 255, 255),
			glassBg = Color3.fromRGB(255, 255, 255),

			-- Soft accent variations
			softPink = Color3.fromRGB(255, 160, 200),
			softPurple = Color3.fromRGB(200, 160, 255),
			softBlue = Color3.fromRGB(160, 200, 255),
		}
	}
}

function UI.Theme:get(key)
	return self.themes[self.current][key] or Color3.new(1, 1, 1)
end

-- Enhanced Component Factory with Soft Pastels
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
			key ~= "cornerRadius" and key ~= "stroke" and key ~= "shadow" and
			key ~= "layout" and key ~= "padding" and key ~= "glass" and key ~= "gradient" then

			if type(value) == "function" and key:sub(1, 2) == "on" then
				local eventName = key:sub(3)
				local connection = self.instance[eventName]:Connect(value)
				table.insert(self.eventConnections, connection)
			else
				pcall(function()
					self.instance[key] = value
				end)
			end
		end
	end

	-- Handle onClick for buttons
	if self.props.onClick and self.instance:IsA("TextButton") then
		local connection = self.instance.MouseButton1Click:Connect(self.props.onClick)
		table.insert(self.eventConnections, connection)
	end
end

function Component:render()
	self:applyProps()

	-- Glassmorphism effect (subtle)
	if self.props.glass then
		local glassEffect = Instance.new("Frame")
		glassEffect.Name = "GlassEffect"
		glassEffect.BackgroundTransparency = self.props.glass.transparency or 0.05
		glassEffect.BackgroundColor3 = self.props.glass.color or UI.Theme:get("glass")
		glassEffect.BorderSizePixel = 0
		glassEffect.Size = UDim2.fromScale(1, 1)
		glassEffect.ZIndex = -1
		glassEffect.Parent = self.instance

		-- Very subtle gradient overlay
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		})
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.95),
			NumberSequenceKeypoint.new(1, 0.98),
		})
		gradient.Parent = glassEffect
	end

	-- Corner radius
	if self.props.cornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = self.props.cornerRadius
		corner.Parent = self.instance
	end

	-- Stroke
	if self.props.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = self.props.stroke.color or UI.Theme:get("stroke")
		stroke.Thickness = self.props.stroke.thickness or 1
		stroke.Transparency = self.props.stroke.transparency or 0
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = self.instance
	end

	-- Drop shadow (soft)
	if self.props.shadow then
		local shadow = Instance.new("Frame")
		shadow.Name = "Shadow"
		shadow.BackgroundColor3 = Color3.new(0, 0, 0)
		shadow.BackgroundTransparency = self.props.shadow.transparency or 0.15
		shadow.BorderSizePixel = 0
		shadow.Size = UDim2.fromScale(1, 1)
		shadow.Position = UDim2.fromOffset(self.props.shadow.offset or 3, self.props.shadow.offset or 3)
		shadow.ZIndex = self.instance.ZIndex - 1

		if self.props.cornerRadius then
			local shadowCorner = Instance.new("UICorner")
			shadowCorner.CornerRadius = self.props.cornerRadius
			shadowCorner.Parent = shadow
		end

		shadow.Parent = self.instance.Parent
		self.instance.Changed:Connect(function(property)
			if property == "ZIndex" then
				shadow.ZIndex = self.instance.ZIndex - 1
			end
		end)
	end

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

-- Soft Frame Component
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

	return component
end

-- Soft Text Label Component
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

	local component = Component.new("TextLabel", props)

	return component
end

-- Soft Button Component with Gentle Animations
function UI.Components.Button(props)
	local defaultProps = {
		BackgroundColor3 = UI.Theme:get("accent"),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextScaled = false,
		Size = UDim2.fromOffset(140, 45),
		AutoButtonColor = false,
	}

	for key, value in pairs(defaultProps) do
		if props[key] == nil then
			props[key] = value
		end
	end

	local component = Component.new("TextButton", props)

	-- Soft gradient background
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, component.props.BackgroundColor3 or UI.Theme:get("accent")),
		ColorSequenceKeypoint.new(1, Core.Utils.blend(component.props.BackgroundColor3 or UI.Theme:get("accent"), Color3.new(1, 1, 1), 0.1)),
	})
	gradient.Rotation = 45
	gradient.Parent = component.instance

	-- Hover animations (gentle)
	local originalSize = component.props.Size or defaultProps.Size
	local hoverScale = component.props.hoverScale or 1.03

	component.instance.MouseEnter:Connect(function()
		Core.Animation.tween(component.instance, {
			Size = UDim2.new(
				originalSize.X.Scale * hoverScale,
				originalSize.X.Offset * hoverScale,
				originalSize.Y.Scale * hoverScale,
				originalSize.Y.Offset * hoverScale
			)
		}, Core.CONSTANTS.ANIM_FAST)

		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Core.Utils.blend(component.props.BackgroundColor3 or UI.Theme:get("accent"), Color3.new(1, 1, 1), 0.15)),
			ColorSequenceKeypoint.new(1, component.props.BackgroundColor3 or UI.Theme:get("accent")),
		})
	end)

	component.instance.MouseLeave:Connect(function()
		Core.Animation.tween(component.instance, {
			Size = originalSize
		}, Core.CONSTANTS.ANIM_FAST)

		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, component.props.BackgroundColor3 or UI.Theme:get("accent")),
			ColorSequenceKeypoint.new(1, Core.Utils.blend(component.props.BackgroundColor3 or UI.Theme:get("accent"), Color3.new(1, 1, 1), 0.1)),
		})
	end)

	component.instance.MouseButton1Down:Connect(function()
		Core.Animation.tween(component.instance, {
			Size = UDim2.new(
				originalSize.X.Scale * 0.97,
				originalSize.X.Offset * 0.97,
				originalSize.Y.Scale * 0.97,
				originalSize.Y.Offset * 0.97
			)
		}, 0.05)
	end)

	component.instance.MouseButton1Up:Connect(function()
		Core.Animation.tween(component.instance, {
			Size = originalSize
		}, 0.05)
	end)

	return component
end

-- Soft Image Component
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

-- Soft ScrollingFrame Component
function UI.Components.ScrollingFrame(props)
	local defaultProps = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UI.Theme:get("strokeSoft"),
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollingDirection = component.props.ScrollingDirection or Enum.ScrollingDirection.Y,
	}

	for key, value in pairs(defaultProps) do
		if props[key] == nil then
			props[key] = value
		end
	end

	local component = Component.new("ScrollingFrame", props)

	-- Custom soft scrollbar styling
	local scrollbar = component.instance:FindFirstChild("ScrollBar")
	if scrollbar then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = scrollbar

		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, UI.Theme:get("accent")),
			ColorSequenceKeypoint.new(1, UI.Theme:get("gradient2")),
		})
		gradient.Parent = scrollbar
	end

	-- Layout
	if component.props.layout then
		local layoutType = component.props.layout.type or "List"
		local layout = Instance.new("UI" .. layoutType .. "Layout")

		for key, value in pairs(component.props.layout) do
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
					if component.props.ScrollingDirection == Enum.ScrollingDirection.X then
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

	-- Padding
	if component.props.padding then
		local padding = Instance.new("UIPadding")
		if component.props.padding.top then padding.PaddingTop = component.props.padding.top end
		if component.props.padding.bottom then padding.PaddingBottom = component.props.padding.bottom end
		if component.props.padding.left then padding.PaddingLeft = component.props.padding.left end
		if component.props.padding.right then padding.PaddingRight = component.props.padding.right end
		padding.Parent = component.instance
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

-- Data Management
Core.DataManager = {}

Core.DataManager.products = {
	cash = {
		{
			id = 1897730242,
			amount = 1000,
			name = "Sweet Starter Pack",
			description = "A gentle beginning to your pastel collection journey",
			icon = "rbxassetid://10709728059",
			featured = false,
			price = 0,
		},
		{
			id = 1897730373,
			amount = 5000,
			name = "Cozy Comfort Bundle",
			description = "Expand your collection with warm, comforting items",
			icon = "rbxassetid://10709728059",
			featured = true,
			price = 0,
		},
		{
			id = 1897730467,
			amount = 10000,
			name = "Dream Collection Set",
			description = "Build your dream collection with premium items",
			icon = "rbxassetid://10709728059",
			featured = false,
			price = 0,
		},
		{
			id = 1897730581,
			amount = 50000,
			name = "Ultimate Pastel Treasury",
			description = "The complete collection for true pastel enthusiasts",
			icon = "rbxassetid://10709728059",
			featured = true,
			price = 0,
		},
	},
	gamepasses = {
		{
			id = 1412171840,
			name = "Gentle Auto-Collect",
			description = "Peacefully gather resources while you relax",
			icon = "rbxassetid://10709727148",
			price = 99,
			features = {
				"Automatic gentle collection",
				"Works while you're away",
				"Calming background process",
			},
			hasToggle = true,
		},
		{
			id = 1398974710,
			name = "2x Gentle Boost",
			description = "Double your collection rate with soft pastel magic",
			icon = "rbxassetid://10709727148",
			price = 199,
			features = {
				"2x multiplier on all items",
				"Permanent gentle enhancement",
				"Stacks with seasonal events",
			},
			hasToggle = false,
		},
	}
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

-- Sound System
Core.SoundSystem = {}

function Core.SoundSystem.initialize()
	local sounds = {
		click = { id = "rbxassetid://876939830", volume = 0.4 },
		hover = { id = "rbxassetid://10066936758", volume = 0.2 },
		open = { id = "rbxassetid://452267918", volume = 0.5 },
		close = { id = "rbxassetid://452267918", volume = 0.5 },
		success = { id = "rbxassetid://876939830", volume = 0.6 },
		error = { id = "rbxassetid://876939830", volume = 0.5 },
		notification = { id = "rbxassetid://876939830", volume = 0.5 },
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

-- ========================================
-- SHOP SYSTEM - PASTEL DREAM
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

	self.toggleButton = UI.Components.Frame({
		Name = "ShopToggle",
		Size = UDim2.fromOffset(180, 65),
		Position = UDim2.new(1, -20, 1, -20),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = UI.Theme:get("surfaceSoft"),
		cornerRadius = UDim.new(0, 32),
		glass = {
			transparency = 0.05,
			color = UI.Theme:get("glass")
		},
		stroke = {
			color = UI.Theme:get("kitty"),
			thickness = 2,
			transparency = 0.3,
		},
		shadow = {
			transparency = 0.2,
			offset = 4,
		},
		parent = toggleScreen,
	}):render()

	-- Soft animated background gradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, UI.Theme:get("gradient1")),
		ColorSequenceKeypoint.new(0.5, UI.Theme:get("gradient2")),
		ColorSequenceKeypoint.new(1, UI.Theme:get("gradient3")),
	})
	gradient.Parent = self.toggleButton

	-- Gentle pulsing animation
	task.spawn(function()
		while self.toggleButton and self.toggleButton.Parent do
			Core.Animation.pulse(self.toggleButton, 1.04, 2.5)
			task.wait(2.5)
		end
	end)

	-- Icon and label container
	local content = UI.Components.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		parent = self.toggleButton,
	}):render()

	local icon = UI.Components.Image({
		Name = "Icon",
		Image = "rbxassetid://17398522865",
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(16, 16),
		parent = content,
	}):render()

	local label = UI.Components.TextLabel({
		Name = "Label",
		Text = "💕 Sanrio Shop",
		Size = UDim2.new(1, -64, 1, 0),
		Position = UDim2.fromOffset(56, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		parent = content,
	}):render()

	-- Click handler
	local clickArea = Instance.new("TextButton")
	clickArea.Text = ""
	clickArea.BackgroundTransparency = 1
	clickArea.Size = UDim2.fromScale(1, 1)
	clickArea.Parent = self.toggleButton

	clickArea.MouseButton1Click:Connect(function()
		self:toggle()
	end)
end

function Shop:toggle()
	if Core.State.isOpen then
		self:close()
	else
		self:open()
	end
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

	Core.SoundSystem.play("open")

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

	Core.SoundSystem.play("close")

	task.wait(Core.CONSTANTS.ANIM_FAST)
	self.gui.Enabled = false
	Core.State.isAnimating = false

	Core.Events:emit("shopClosed")
end

function Shop:refreshAllProducts()
	ownershipCache:clear()

	for _, pass in ipairs(Core.DataManager.products.gamepasses) do
		self:refreshProduct(pass, "gamepass")
	end

	Core.Events:emit("productsRefreshed")
end

function Shop:refreshProduct(product, productType)
	if productType == "gamepass" then
		local isOwned = Core.DataManager.checkOwnership(product.id)

		if product.purchaseButton then
			product.purchaseButton.Text = isOwned and "✅ Owned" or "🛒 Purchase"
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
			product.purchaseButton.Text = "🛒 Purchase"
			product.purchaseButton.Active = true
			Core.State.purchasePending[product.id] = nil
		end

		task.delay(Core.CONSTANTS.PURCHASE_TIMEOUT, function()
			if Core.State.purchasePending[product.id] then
				product.purchaseButton.Text = "🛒 Purchase"
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

function Shop:toggleGamepass(product)
	if not product.hasToggle then return end
	if Remotes then
		local toggleRemote = Remotes:FindFirstChild("AutoCollectToggle")
		if toggleRemote and toggleRemote:IsA("RemoteEvent") then
			toggleRemote:FireServer()
		end
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
		productGrant.OnClientEvent:Connect(function()
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

function Shop:createMainInterface()
	self.gui = PlayerGui:FindFirstChild("SanrioShopMain") or Instance.new("ScreenGui")
	self.gui.Name = "SanrioShopMain"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 1000
	self.gui.Enabled = false
	self.gui.Parent = PlayerGui

	-- Soft blur effect
	self.blur = Lighting:FindFirstChild("SanrioShopBlur") or Instance.new("BlurEffect")
	self.blur.Name = "SanrioShopBlur"
	self.blur.Size = 0
	self.blur.Parent = Lighting

	-- Soft background
	local background = UI.Components.Frame({
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Theme:get("background"),
		parent = self.gui,
	}):render()

	-- Very subtle animated gradient background
	local bgGradient = Instance.new("UIGradient")
	bgGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, UI.Theme:get("background")),
		ColorSequenceKeypoint.new(0.3, Core.Utils.blend(UI.Theme:get("background"), UI.Theme:get("surfaceSoft"), 0.1)),
		ColorSequenceKeypoint.new(0.7, Core.Utils.blend(UI.Theme:get("background"), UI.Theme:get("gradient1"), 0.05)),
		ColorSequenceKeypoint.new(1, UI.Theme:get("background")),
	})
	bgGradient.Parent = background

	local panelSize = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE

	self.mainPanel = UI.Components.Frame({
		Name = "MainPanel",
		Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UI.Theme:get("surfaceSoft"),
		cornerRadius = UDim.new(0, 28),
		glass = {
			transparency = 0.03,
			color = UI.Theme:get("glass")
		},
		stroke = {
			color = UI.Theme:get("strokeSoft"),
			thickness = 2,
			transparency = 0.4,
		},
		shadow = {
			transparency = 0.15,
			offset = 8,
		},
		parent = self.gui,
	}):render()

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
		Size = UDim2.new(1, -48, 0, 80),
		Position = UDim2.fromOffset(24, 24),
		BackgroundColor3 = UI.Theme:get("surfaceAlt"),
		cornerRadius = UDim.new(0, 20),
		glass = {
			transparency = 0.05,
			color = UI.Theme:get("glass")
		},
		stroke = {
			color = UI.Theme:get("strokeBright"),
			thickness = 1,
			transparency = 0.6,
		},
		parent = self.mainPanel,
	}):render()

	-- Subtle gradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, UI.Theme:get("gradient1")),
		ColorSequenceKeypoint.new(1, UI.Theme:get("gradient2")),
	})
	gradient.Parent = header

	local logo = UI.Components.Image({
		Name = "Logo",
		Image = "rbxassetid://17398522865",
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.fromOffset(16, 10),
		parent = header,
	}):render()

	local titleContainer = UI.Components.Frame({
		Size = UDim2.new(1, -200, 1, 0),
		Position = UDim2.fromOffset(92, 0),
		BackgroundTransparency = 1,
		parent = header,
	}):render()

	local title = UI.Components.TextLabel({
		Text = "💕 Sanrio Shop",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
		TextSize = 32,
		parent = titleContainer,
	}):render()

	local subtitle = UI.Components.TextLabel({
		Text = "Sweet items and gentle upgrades for your peaceful tycoon",
		Size = UDim2.new(1, 0, 0, 25),
		Position = UDim2.fromOffset(0, 50),
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = UI.Theme:get("textSecondary"),
		parent = titleContainer,
	}):render()

	local closeButton = UI.Components.Button({
		Text = "✕",
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.new(1, -66, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = UI.Theme:get("error"),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		cornerRadius = UDim.new(0.5, 0),
		parent = header,
		onClick = function()
			self:close()
		end,
	}):render()
end

function Shop:createTabBar()
	self.tabContainer = UI.Components.Frame({
		Name = "TabContainer",
		Size = UDim2.new(1, -48, 0, 50),
		Position = UDim2.fromOffset(24, 116),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, 15),
		stroke = {
			color = UI.Theme:get("stroke"),
			thickness = 1,
			transparency = 0.6,
		},
		parent = self.mainPanel,
	}):render()

	local tabData = {
		{id = "Home", name = "🏠 Home", icon = "rbxassetid://17398522865", color = UI.Theme:get("kitty")},
		{id = "Cash", name = "💰 Cash", icon = "rbxassetid://10709728059", color = UI.Theme:get("cinna")},
		{id = "Gamepasses", name = "🎫 Passes", icon = "rbxassetid://10709727148", color = UI.Theme:get("kuromi")},
	}

	for _, data in ipairs(tabData) do
		self:createTab(data)
	end
end

function Shop:createTab(data)
	local tab = UI.Components.Button({
		Name = data.id .. "Tab",
		Text = "",
		Size = UDim2.new(1/#self.tabs - 0.02, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundColor3 = UI.Theme:get("surfaceAlt"),
		cornerRadius = UDim.new(0, 12),
		stroke = {
			color = data.color,
			thickness = 2,
			transparency = 0.7,
		},
		parent = self.tabContainer,
		onClick = function()
			self:selectTab(data.id)
		end,
	}):render()

	local content = UI.Components.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		parent = tab,
	}):render()

	local icon = UI.Components.Image({
		Image = data.icon,
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.fromOffset(16, 13),
		parent = content,
	}):render()

	local label = UI.Components.TextLabel({
		Text = data.name,
		Size = UDim2.new(1, -50, 1, 0),
		Position = UDim2.fromOffset(48, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
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
		Text = "✨ Featured Items",
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

function Shop:createHeroSection(parent)
	local hero = UI.Components.Frame({
		Name = "HeroSection",
		Size = UDim2.new(1, 0, 0, 240),
		BackgroundColor3 = UI.Theme:get("surfaceAlt"),
		cornerRadius = UDim.new(0, 20),
		LayoutOrder = 1,
		glass = {
			transparency = 0.05,
			color = UI.Theme:get("glass")
		},
		stroke = {
			color = UI.Theme:get("kitty"),
			thickness = 2,
			transparency = 0.5,
		},
		parent = parent,
	}):render()

	-- Soft gradient background
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, UI.Theme:get("gradient1")),
		ColorSequenceKeypoint.new(0.5, UI.Theme:get("gradient2")),
		ColorSequenceKeypoint.new(1, UI.Theme:get("gradient3")),
	})
	gradient.Parent = hero

	local content = UI.Components.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		parent = hero,
	}):render()

	local textContainer = UI.Components.Frame({
		Size = UDim2.new(0.65, 0, 1, 0),
		BackgroundTransparency = 1,
		parent = content,
	}):render()

	local heroTitle = UI.Components.TextLabel({
		Text = "Welcome to Sanrio Shop! 💕",
		Size = UDim2.new(1, 0, 0, 45),
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
		TextColor3 = UI.Theme:get("text"),
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = textContainer,
	}):render()

	local heroDesc = UI.Components.TextLabel({
		Text = "Discover sweet items and gentle upgrades to make your tycoon extra special!",
		Size = UDim2.new(1, 0, 0, 70),
		Position = UDim2.fromOffset(0, 55),
		Font = Enum.Font.Gotham,
		TextSize = 18,
		TextColor3 = UI.Theme:get("textSecondary"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		parent = textContainer,
	}):render()

	local ctaButton = UI.Components.Button({
		Text = "🛍️ Start Shopping",
		Size = UDim2.fromOffset(200, 50),
		Position = UDim2.fromOffset(0, 135),
		BackgroundColor3 = UI.Theme:get("kitty"),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		cornerRadius = UDim.new(0, 15),
		parent = textContainer,
		onClick = function()
			self:selectTab("Cash")
		end,
	}):render()

	-- Hero character
	local imageContainer = UI.Components.Frame({
		Size = UDim2.new(0.35, 0, 1, 0),
		Position = UDim2.new(0.65, 0, 0, 0),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, 18),
		parent = content,
	}):render()

	local heroImage = UI.Components.Image({
		Image = "rbxassetid://17398522865",
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		parent = imageContainer,
	}):render()

	return hero
end

function Shop:createProductCard(product, productType, parent)
	local isGamepass = productType == "gamepass"
	local cardColor = isGamepass and UI.Theme:get("kuromi") or UI.Theme:get("cinna")

	local card = UI.Components.Frame({
		Name = product.name .. "Card",
		Size = UDim2.fromOffset(
			Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.X or Core.CONSTANTS.CARD_SIZE.X,
			Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.Y or Core.CONSTANTS.CARD_SIZE.Y
		),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, 18),
		glass = {
			transparency = 0.05,
			color = UI.Theme:get("glass")
		},
		stroke = {
			color = cardColor,
			thickness = 2,
			transparency = 0.5,
		},
		shadow = {
			transparency = 0.2,
			offset = 6,
		},
		parent = parent,
	}):render()

	self:addCardHoverEffect(card)

	local imageContainer = UI.Components.Frame({
		Size = UDim2.new(1, -20, 0, 140),
		Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = UI.Theme:get("surfaceAlt"),
		cornerRadius = UDim.new(0, 14),
		parent = card,
	}):render()

	local productImage = UI.Components.Image({
		Image = product.icon or "rbxassetid://0",
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ScaleType = Enum.ScaleType.Fit,
		parent = imageContainer,
	}):render()

	local infoContainer = UI.Components.Frame({
		Size = UDim2.new(1, -20, 1, -160),
		Position = UDim2.fromOffset(10, 160),
		BackgroundTransparency = 1,
		parent = card,
	}):render()

	local title = UI.Components.TextLabel({
		Text = product.name,
		Size = UDim2.new(1, 0, 0, 30),
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = infoContainer,
	}):render()

	local description = UI.Components.TextLabel({
		Text = product.description,
		Size = UDim2.new(1, 0, 0, 45),
		Position = UDim2.fromOffset(0, 35),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = UI.Theme:get("textSecondary"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		parent = infoContainer,
	}):render()

	local priceText = isGamepass and
		("💎 R$" .. tostring(product.price or 0)) or
		("💰 R$" .. tostring(product.price or 0) .. " for " .. Core.Utils.formatNumber(product.amount) .. " Cash")

	local priceLabel = UI.Components.TextLabel({
		Text = priceText,
		Size = UDim2.new(1, 0, 0, 25),
		Position = UDim2.fromOffset(0, 85),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = cardColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = infoContainer,
	}):render()

	local isOwned = isGamepass and Core.DataManager.checkOwnership(product.id)

	local purchaseButton = UI.Components.Button({
		Text = isOwned and "✅ Owned" or "🛒 Purchase",
		Size = UDim2.new(1, 0, 0, 45),
		Position = UDim2.new(0, 0, 1, -45),
		BackgroundColor3 = isOwned and UI.Theme:get("success") or cardColor,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		cornerRadius = UDim.new(0, 12),
		stroke = {
			color = UI.Theme:get("strokeBright"),
			thickness = 1,
		},
		parent = infoContainer,
		onClick = function()
			if not isOwned then
				self:promptPurchase(product, productType)
			elseif product.hasToggle then
				self:toggleGamepass(product)
			end
		end,
	}):render()

	if isOwned and product.hasToggle then
		self:addToggleSwitch(product, infoContainer)
	end

	product.cardInstance = card
	product.purchaseButton = purchaseButton

	return card
end

function Shop:addCardHoverEffect(card)
	local originalPosition = card.Position

	card.MouseEnter:Connect(function()
		Core.Animation.tween(card, {
			Position = UDim2.new(
				originalPosition.X.Scale,
				originalPosition.X.Offset,
				originalPosition.Y.Scale,
				originalPosition.Y.Offset - 8
			)
		}, Core.CONSTANTS.ANIM_FAST)

		-- Enhance stroke on hover
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			Core.Animation.tween(stroke, {
				Transparency = 0.2,
				Thickness = 3,
			}, Core.CONSTANTS.ANIM_FAST)
		end
	end)

	card.MouseLeave:Connect(function()
		Core.Animation.tween(card, {
			Position = originalPosition
		}, Core.CONSTANTS.ANIM_FAST)

		-- Reset stroke
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			Core.Animation.tween(stroke, {
				Transparency = 0.5,
				Thickness = 2,
			}, Core.CONSTANTS.ANIM_FAST)
		end
	end)
end

function Shop:addToggleSwitch(product, parent)
	local toggleContainer = UI.Components.Frame({
		Name = "ToggleContainer",
		Size = UDim2.fromOffset(65, 32),
		Position = UDim2.new(1, -65, 0, 85),
		BackgroundColor3 = UI.Theme:get("surfaceAlt"),
		cornerRadius = UDim.new(0.5, 0),
		stroke = {
			color = UI.Theme:get("stroke"),
			thickness = 1,
		},
		parent = parent,
	}):render()

	local toggleButton = UI.Components.Frame({
		Name = "ToggleButton",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0.5, 0),
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
				Position = UDim2.fromOffset(35, 2),
				BackgroundColor3 = UI.Theme:get("success")
			}, Core.CONSTANTS.ANIM_FAST)
		else
			toggleContainer.BackgroundColor3 = UI.Theme:get("surfaceAlt")
			Core.Animation.tween(toggleButton, {
				Position = UDim2.fromOffset(2, 2),
				BackgroundColor3 = UI.Theme:get("surface")
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

function Shop:selectTab(tabId)
	if self.currentTab == tabId then return end

	for id, tab in pairs(self.tabs) do
		local isActive = id == tabId
		local data = tab.data

		Core.Animation.tween(tab.button, {
			BackgroundColor3 = isActive and
				Core.Utils.blend(data.color, Color3.new(1, 1, 1), 0.1) or
				UI.Theme:get("surfaceAlt")
		}, Core.CONSTANTS.ANIM_FAST)

		local stroke = tab.button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = isActive and data.color or data.color
			stroke.Transparency = isActive and 0.4 or 0.7
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

-- Include remaining functionality (same as before but with soft pastel styling)
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

-- Include all the remaining shop functionality (purchase handling, etc.)
-- ... (keeping the same implementation but with the soft pastel styling)

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

-- Marketplace callbacks
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if player ~= Player then return end

	local pending = Core.State.purchasePending[passId]
	if not pending then return end

	Core.State.purchasePending[passId] = nil

	if purchased then
		ownershipCache:clear()

		if pending.product.purchaseButton then
			pending.product.purchaseButton.Text = "✅ Owned"
			pending.product.purchaseButton.BackgroundColor3 = UI.Theme:get("success")
			pending.product.purchaseButton.Active = false
		end

		Core.SoundSystem.play("success")

		task.wait(0.5)
		shop:refreshAllProducts()
	else
		if pending.product.purchaseButton then
			pending.product.purchaseButton.Text = "🛒 Purchase"
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

-- Handle character respawn
Player.CharacterAdded:Connect(function()
	task.wait(1)
	if not shop.toggleButton or not shop.toggleButton.Parent then
		shop:createToggleButton()
	end
end)

print("[SanrioShop] 💕 Pastel Dream UI initialized successfully!")

return shop