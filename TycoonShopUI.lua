--[[
	TYCOON SHOP UI - MODERN CUTE EDITION 2025
	A comprehensive, production-ready shop interface with zero warnings
	
	Features:
	- Mobile-first responsive design with dynamic grid columns
	- Modern-cute aesthetic (soft pastels, rounded corners, subtle depth)
	- Full gamepass ownership detection with auto-collect toggle
	- Smooth animations and transitions with world blur
	- Safe area handling for notches and Roblox UI
	- Comprehensive caching and performance optimization
	- Scale-based sizing (no fixed offsets except tiny paddings)
	
	Place in: StarterPlayer > StarterPlayerScripts
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

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Wait for remotes with timeout
local Remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)
if not Remotes then
	warn("[TycoonShop] Could not find TycoonRemotes folder")
	Remotes = Instance.new("Folder")
end

-- Constants
local SHOP_VERSION = "6.0.0"
local DEBUG_MODE = false

local ANIMATION_SPEEDS = {
	INSTANT = 0,
	FAST = 0.15,
	MEDIUM = 0.25,
	SLOW = 0.4,
	VERY_SLOW = 0.6
}

local CACHE_DURATIONS = {
	PRICE = 300,      -- 5 minutes
	OWNERSHIP = 60,   -- 1 minute
	PLAYER_DATA = 30  -- 30 seconds
}

local UI_CONSTANTS = {
	MOBILE_BREAKPOINT = 768,
	TABLET_BREAKPOINT = 1024,
	GRID_BREAKPOINT_1 = 600,
	GRID_BREAKPOINT_2 = 950,
	MIN_BUTTON_SIZE = 48,    -- Mobile touch target
	SAFE_AREA_PADDING = 8,   -- Extra padding for safe areas
	HEADER_HEIGHT = 72,
	NAV_WIDTH_DESKTOP = 240,
	NAV_HEIGHT_MOBILE = 64,
	BLUR_SIZE = 24,
	PURCHASE_TIMEOUT = 15,
	REFRESH_INTERVAL = 30,
}

-- Design System
local Theme = {
	colors = {
		-- Backgrounds
		background = Color3.fromRGB(252, 250, 248),
		surface = Color3.fromRGB(255, 255, 255),
		surfaceVariant = Color3.fromRGB(248, 245, 250),
		overlay = Color3.fromRGB(0, 0, 0),
		
		-- Strokes and dividers
		outline = Color3.fromRGB(226, 220, 228),
		outlineVariant = Color3.fromRGB(238, 234, 240),
		
		-- Text
		onBackground = Color3.fromRGB(44, 40, 52),
		onSurface = Color3.fromRGB(44, 40, 52),
		onSurfaceVariant = Color3.fromRGB(118, 110, 130),
		
		-- Primary (Mint for cash)
		primary = Color3.fromRGB(180, 226, 216),
		primaryVariant = Color3.fromRGB(148, 194, 184),
		onPrimary = Color3.fromRGB(255, 255, 255),
		primaryContainer = Color3.fromRGB(220, 246, 240),
		
		-- Secondary (Lavender for passes)
		secondary = Color3.fromRGB(208, 198, 255),
		secondaryVariant = Color3.fromRGB(176, 166, 223),
		onSecondary = Color3.fromRGB(255, 255, 255),
		secondaryContainer = Color3.fromRGB(235, 230, 255),
		
		-- Semantic colors
		success = Color3.fromRGB(127, 196, 146),
		warning = Color3.fromRGB(247, 203, 122),
		error = Color3.fromRGB(255, 122, 142),
		info = Color3.fromRGB(188, 216, 255),
		
		-- Shadows
		shadow = Color3.fromRGB(200, 190, 210),
		shadowLight = Color3.fromRGB(220, 215, 230),
	},
	
	typography = {
		fontFamily = {
			regular = Enum.Font.Gotham,
			medium = Enum.Font.GothamMedium,
			bold = Enum.Font.GothamBold,
		},
		
		scale = {
			-- Display
			displayLarge = 32,
			displayMedium = 28,
			displaySmall = 24,
			
			-- Headlines
			headlineLarge = 24,
			headlineMedium = 20,
			headlineSmall = 18,
			
			-- Body
			bodyLarge = 18,
			bodyMedium = 16,
			bodySmall = 14,
			
			-- Labels
			labelLarge = 16,
			labelMedium = 14,
			labelSmall = 12,
		}
	},
	
	spacing = {
		none = 0,
		xs = 4,
		sm = 8,
		md = 12,
		lg = 16,
		xl = 24,
		xxl = 32,
		xxxl = 48,
	},
	
	radius = {
		none = UDim.new(0, 0),
		xs = UDim.new(0, 4),
		sm = UDim.new(0, 8),
		md = UDim.new(0, 12),
		lg = UDim.new(0, 16),
		xl = UDim.new(0, 20),
		xxl = UDim.new(0, 28),
		full = UDim.new(1, 0),
	},
	
	elevation = {
		level0 = {transparency = 1, offset = 0},
		level1 = {transparency = 0.95, offset = 2},
		level2 = {transparency = 0.92, offset = 4},
		level3 = {transparency = 0.88, offset = 8},
		level4 = {transparency = 0.85, offset = 12},
		level5 = {transparency = 0.82, offset = 16},
	}
}

-- Asset IDs (Replace with your own)
local Assets = {
	icons = {
		cash = "rbxassetid://14978048121",      -- Coin icon
		gamepass = "rbxassetid://14978047952",   -- Diamond icon
		shop = "rbxassetid://14978048006",       -- Shop icon
		close = "rbxassetid://14978047806",      -- X icon
		check = "rbxassetid://14978047859",      -- Checkmark
		settings = "rbxassetid://14978048064",   -- Gear icon
		sparkle = "rbxassetid://14978048177",    -- Sparkle effect
	},
	
	sounds = {
		click = "rbxassetid://876939830",
		hover = "rbxassetid://12221967",
		open = "rbxassetid://9113880610",
		close = "rbxassetid://9113881154",
		purchase = "rbxassetid://203785492",
		error = "rbxassetid://2767090566",
	}
}

-- Product Data (Replace IDs with your own)
local ProductData = {
	cashPacks = {
		{id = 1897730242, amount = 1000,     name = "Starter Pack",    description = "Perfect for beginners"},
		{id = 1897730373, amount = 5000,     name = "Builder Bundle",  description = "Expand your tycoon"},
		{id = 1897730467, amount = 10000,    name = "Pro Package",     description = "Serious business boost"},
		{id = 1897730581, amount = 50000,    name = "Elite Vault",     description = "Major expansion fund"},
		{id = 1234567001, amount = 100000,   name = "Mega Cache",      description = "Transform your empire"},
		{id = 1234567002, amount = 250000,   name = "Quarter Mil",     description = "Investment powerhouse"},
		{id = 1234567003, amount = 500000,   name = "Half Million",    description = "Tycoon acceleration"},
		{id = 1234567004, amount = 1000000,  name = "Millionaire",     description = "Join the elite club"},
		{id = 1234567005, amount = 5000000,  name = "Magnate Pack",    description = "Industry domination"},
		{id = 1234567006, amount = 10000000, name = "Ultimate Wealth", description = "Maximum power"},
	},
	
	gamePasses = {
		{id = 1412171840, name = "Auto Collect", description = "Collects cash automatically every minute", hasToggle = true},
		{id = 1398974710, name = "2x Cash",      description = "Double all earnings permanently", hasToggle = false},
		{id = 1234567890, name = "VIP Access",   description = "Exclusive VIP benefits and areas", hasToggle = false},
		{id = 1234567891, name = "Speed Boost",  description = "25% faster production speed", hasToggle = false},
	}
}

-- Utility Functions
local function debugPrint(...)
	if DEBUG_MODE then
		print("[TycoonShop]", ...)
	end
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function formatNumber(n)
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	else
		return tostring(n)
	end
end

local function formatNumberWithCommas(n)
	local formatted = tostring(n)
	local k
	repeat
		formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return formatted
end

local function getDeviceType()
	if GuiService:IsTenFootInterface() then
		return "Console"
	elseif UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return "Mobile"
	elseif UserInputService.TouchEnabled and UserInputService.MouseEnabled then
		return "Tablet"
	else
		return "Desktop"
	end
end

local function getViewportSize()
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1920, 1080)
end

local function isSmallScreen()
	local viewport = getViewportSize()
	return viewport.X < UI_CONSTANTS.MOBILE_BREAKPOINT
end

local function getGridColumns()
	local width = getViewportSize().X
	if width < UI_CONSTANTS.GRID_BREAKPOINT_1 then
		return 1
	elseif width < UI_CONSTANTS.GRID_BREAKPOINT_2 then
		return 2
	else
		return 3
	end
end

local function getSafeAreaPadding()
	local insets = GuiService:GetGuiInset()
	return {
		top = math.max(insets.Y, UI_CONSTANTS.SAFE_AREA_PADDING),
		bottom = UI_CONSTANTS.SAFE_AREA_PADDING,
		left = UI_CONSTANTS.SAFE_AREA_PADDING,
		right = UI_CONSTANTS.SAFE_AREA_PADDING,
	}
end

-- Simple Cache Implementation
local Cache = {}
Cache.__index = Cache

function Cache.new(duration)
	return setmetatable({
		duration = duration,
		storage = {},
	}, Cache)
end

function Cache:set(key, value)
	self.storage[key] = {
		value = value,
		timestamp = tick(),
	}
end

function Cache:get(key)
	local entry = self.storage[key]
	if not entry then return nil end
	
	if tick() - entry.timestamp > self.duration then
		self.storage[key] = nil
		return nil
	end
	
	return entry.value
end

function Cache:clear(key)
	if key then
		self.storage[key] = nil
	else
		self.storage = {}
	end
end

-- Event System
local EventEmitter = {}
EventEmitter.__index = EventEmitter

function EventEmitter.new()
	return setmetatable({
		events = {},
		connections = {},
	}, EventEmitter)
end

function EventEmitter:on(event, callback)
	if not self.events[event] then
		self.events[event] = {}
	end
	
	local connection = {
		callback = callback,
		connected = true,
	}
	
	table.insert(self.events[event], connection)
	
	return {
		Disconnect = function()
			connection.connected = false
		end
	}
end

function EventEmitter:emit(event, ...)
	local handlers = self.events[event]
	if not handlers then return end
	
	for i = #handlers, 1, -1 do
		local handler = handlers[i]
		if handler.connected then
			task.spawn(handler.callback, ...)
		else
			table.remove(handlers, i)
		end
	end
end

function EventEmitter:destroy()
	self.events = {}
	self.connections = {}
end

-- Sound Manager
local SoundManager = {}
SoundManager.__index = SoundManager

function SoundManager.new()
	local self = setmetatable({
		sounds = {},
		enabled = true,
	}, SoundManager)
	
	self:loadSounds()
	return self
end

function SoundManager:loadSounds()
	for name, id in pairs(Assets.sounds) do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = 0.1
		sound.Parent = SoundService
		self.sounds[name] = sound
		
		-- Preload
		sound:Play()
		sound:Stop()
	end
end

function SoundManager:play(soundName, volume)
	if not self.enabled then return end
	
	local sound = self.sounds[soundName]
	if sound then
		sound.Volume = volume or 0.1
		sound:Play()
	end
end

function SoundManager:setEnabled(enabled)
	self.enabled = enabled
end

-- Component System
local Component = {}
Component.__index = Component

function Component.new(className, props)
	local self = setmetatable({
		instance = Instance.new(className),
		props = props or {},
		children = {},
		connections = {},
		destroyed = false,
	}, Component)
	
	return self
end

function Component:applyProps()
	for key, value in pairs(self.props) do
		local skipProps = {
			"Parent", "parent",
			"Children", "children",
			"OnClick", "onClick",
			"OnHover", "onHover",
			"OnLeave", "onLeave",
			"OnChange", "onChange",
			"Style", "style",
		}
		
		local shouldSkip = false
		for _, skipProp in ipairs(skipProps) do
			if key == skipProp then
				shouldSkip = true
				break
			end
		end
		
		if not shouldSkip then
			pcall(function()
				self.instance[key] = value
			end)
		end
	end
end

function Component:applyStyle()
	local style = self.props.style or self.props.Style
	if not style then return end
	
	-- Corner radius
	if style.cornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = style.cornerRadius
		corner.Parent = self.instance
	end
	
	-- Stroke
	if style.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = style.stroke.color or Theme.colors.outline
		stroke.Thickness = style.stroke.thickness or 1
		stroke.Transparency = style.stroke.transparency or 0
		stroke.ApplyStrokeMode = style.stroke.mode or Enum.ApplyStrokeMode.Border
		stroke.Parent = self.instance
	end
	
	-- Padding
	if style.padding then
		local padding = Instance.new("UIPadding")
		local p = style.padding
		
		if type(p) == "number" then
			padding.PaddingTop = UDim.new(0, p)
			padding.PaddingBottom = UDim.new(0, p)
			padding.PaddingLeft = UDim.new(0, p)
			padding.PaddingRight = UDim.new(0, p)
		elseif type(p) == "table" then
			padding.PaddingTop = p.top or UDim.new(0, 0)
			padding.PaddingBottom = p.bottom or UDim.new(0, 0)
			padding.PaddingLeft = p.left or UDim.new(0, 0)
			padding.PaddingRight = p.right or UDim.new(0, 0)
		end
		
		padding.Parent = self.instance
	end
	
	-- Gradient
	if style.gradient then
		local gradient = Instance.new("UIGradient")
		gradient.Color = style.gradient.color or ColorSequence.new(Color3.new(1,1,1))
		gradient.Transparency = style.gradient.transparency
		gradient.Rotation = style.gradient.rotation or 0
		gradient.Offset = style.gradient.offset or Vector2.new(0, 0)
		gradient.Parent = self.instance
	end
	
	-- Shadow (using ImageLabel technique)
	if style.shadow and self.instance:IsA("GuiObject") then
		local shadow = Instance.new("ImageLabel")
		shadow.Name = "Shadow"
		shadow.BackgroundTransparency = 1
		shadow.Image = "rbxassetid://1316045217"
		shadow.ImageColor3 = style.shadow.color or Theme.colors.shadow
		shadow.ImageTransparency = style.shadow.transparency or 0.8
		shadow.ScaleType = Enum.ScaleType.Slice
		shadow.SliceCenter = Rect.new(10, 10, 118, 118)
		shadow.Size = UDim2.new(1, style.shadow.blur or 20, 1, style.shadow.blur or 20)
		shadow.Position = UDim2.new(0, -(style.shadow.blur or 20)/2, 0, -(style.shadow.blur or 20)/2)
		shadow.ZIndex = self.instance.ZIndex - 1
		shadow.Parent = self.instance.Parent
		
		self.instance.Parent = self.instance.Parent -- Re-parent to fix Z-order
	end
	
	-- Layout constraints
	if style.aspectRatio then
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = style.aspectRatio.ratio
		aspect.AspectType = style.aspectRatio.type or Enum.AspectType.FitWithinMaxSize
		aspect.DominantAxis = style.aspectRatio.dominantAxis or Enum.DominantAxis.Width
		aspect.Parent = self.instance
	end
	
	if style.sizeConstraint then
		local constraint = Instance.new("UISizeConstraint")
		constraint.MaxSize = style.sizeConstraint.max or Vector2.new(math.huge, math.huge)
		constraint.MinSize = style.sizeConstraint.min or Vector2.new(0, 0)
		constraint.Parent = self.instance
	end
end

function Component:connectEvents()
	-- Click events
	if self.props.onClick and self.instance:IsA("GuiButton") then
		table.insert(self.connections, self.instance.MouseButton1Click:Connect(function()
			self.props.onClick(self)
		end))
	end
	
	-- Hover events
	if self.props.onHover and self.instance:IsA("GuiObject") then
		table.insert(self.connections, self.instance.MouseEnter:Connect(function()
			self.props.onHover(self)
		end))
	end
	
	if self.props.onLeave and self.instance:IsA("GuiObject") then
		table.insert(self.connections, self.instance.MouseLeave:Connect(function()
			self.props.onLeave(self)
		end))
	end
	
	-- Change events
	if self.props.onChange then
		if self.instance:IsA("TextBox") then
			table.insert(self.connections, self.instance:GetPropertyChangedSignal("Text"):Connect(function()
				self.props.onChange(self.instance.Text)
			end))
		end
	end
end

function Component:render()
	if self.destroyed then return end
	
	self:applyProps()
	self:applyStyle()
	self:connectEvents()
	
	-- Render children
	local children = self.props.children or self.props.Children
	if children then
		for _, child in ipairs(children) do
			if typeof(child) == "Instance" then
				child.Parent = self.instance
			elseif type(child) == "table" and child.render then
				child:render()
				child.instance.Parent = self.instance
				table.insert(self.children, child)
			end
		end
	end
	
	-- Set parent last
	local parent = self.props.parent or self.props.Parent
	if parent then
		self.instance.Parent = parent
	end
	
	return self
end

function Component:destroy()
	if self.destroyed then return end
	self.destroyed = true
	
	-- Disconnect events
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	
	-- Destroy children
	for _, child in ipairs(self.children) do
		if child.destroy then
			child:destroy()
		end
	end
	
	-- Destroy instance
	self.instance:Destroy()
end

-- UI Builder Functions
local function Frame(props)
	props = props or {}
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.colors.surface
	props.BorderSizePixel = 0
	return Component.new("Frame", props)
end

local function ScrollFrame(props)
	props = props or {}
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.ScrollBarThickness = props.ScrollBarThickness or 6
	props.ScrollBarImageColor3 = props.ScrollBarImageColor3 or Theme.colors.outline
	props.ScrollBarImageTransparency = props.ScrollBarImageTransparency or 0.5
	props.CanvasSize = props.CanvasSize or UDim2.new(0, 0, 0, 0)
	props.AutomaticCanvasSize = props.AutomaticCanvasSize or Enum.AutomaticSize.Y
	return Component.new("ScrollingFrame", props)
end

local function Text(props)
	props = props or {}
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or Theme.colors.onSurface
	props.Font = props.Font or Theme.typography.fontFamily.regular
	props.TextSize = props.TextSize or Theme.typography.scale.bodyMedium
	props.TextWrapped = props.TextWrapped == nil and true or props.TextWrapped
	props.TextScaled = props.TextScaled or false
	props.BorderSizePixel = 0
	return Component.new("TextLabel", props)
end

local function Button(props)
	props = props or {}
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.colors.primary
	props.TextColor3 = props.TextColor3 or Theme.colors.onPrimary
	props.Font = props.Font or Theme.typography.fontFamily.medium
	props.TextSize = props.TextSize or Theme.typography.scale.labelLarge
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	return Component.new("TextButton", props)
end

local function Image(props)
	props = props or {}
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.ScaleType = props.ScaleType or Enum.ScaleType.Fit
	props.BorderSizePixel = 0
	return Component.new("ImageLabel", props)
end

local function ImageButton(props)
	props = props or {}
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.ScaleType = props.ScaleType or Enum.ScaleType.Fit
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	return Component.new("ImageButton", props)
end

-- Tween helper with easing
local function tween(object, properties, duration, easingStyle, easingDirection, callback)
	local tweenInfo = TweenInfo.new(
		duration or ANIMATION_SPEEDS.MEDIUM,
		easingStyle or Enum.EasingStyle.Quart,
		easingDirection or Enum.EasingDirection.Out,
		0,
		false,
		0
	)
	
	local tweenObject = TweenService:Create(object, tweenInfo, properties)
	
	if callback then
		tweenObject.Completed:Connect(callback)
	end
	
	tweenObject:Play()
	return tweenObject
end

-- Shop Manager
local ShopManager = {}
ShopManager.__index = ShopManager

function ShopManager.new()
	local self = setmetatable({
		-- State
		isOpen = false,
		isAnimating = false,
		currentTab = "cash",
		purchaseQueue = {},
		
		-- UI References
		gui = nil,
		blur = nil,
		mainContainer = nil,
		header = nil,
		navigation = nil,
		contentArea = nil,
		pages = {},
		toggleButton = nil,
		
		-- Systems
		soundManager = SoundManager.new(),
		eventEmitter = EventEmitter.new(),
		priceCache = Cache.new(CACHE_DURATIONS.PRICE),
		ownershipCache = Cache.new(CACHE_DURATIONS.OWNERSHIP),
		
		-- Connections
		connections = {},
		
		-- Settings
		settings = {
			soundEnabled = true,
			animationsEnabled = true,
			autoRefresh = true,
		},
	}, ShopManager)
	
	self:initialize()
	return self
end

function ShopManager:initialize()
	debugPrint("Initializing shop...")
	
	-- Create UI
	self:createGUI()
	self:createToggleButton()
	
	-- Setup systems
	self:setupInputHandling()
	self:setupResponsiveHandling()
	self:setupMarketplaceCallbacks()
	
	-- Initial data load
	self:refreshPrices()
	
	debugPrint("Shop initialized successfully")
end

function ShopManager:createGUI()
	-- Clean up existing
	if PlayerGui:FindFirstChild("TycoonShopUI") then
		PlayerGui.TycoonShopUI:Destroy()
	end
	
	-- Create ScreenGui
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "TycoonShopUI"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 100
	self.gui.IgnoreGuiInset = false
	self.gui.Enabled = false
	self.gui.Parent = PlayerGui
	
	-- Background overlay
	local overlay = Frame({
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.overlay,
		BackgroundTransparency = 0.3,
		Parent = self.gui,
	}):render()
	
	-- Get safe area
	local safeArea = getSafeAreaPadding()
	
	-- Main container with safe area padding
	local containerWrapper = Frame({
		Name = "ContainerWrapper",
		Size = UDim2.new(1, 0, 1, -safeArea.top),
		Position = UDim2.new(0, 0, 0, safeArea.top),
		BackgroundTransparency = 1,
		Parent = self.gui,
	}):render()
	
	-- Actual shop container
	self.mainContainer = Frame({
		Name = "MainContainer",
		Size = UDim2.fromScale(0.95, 0.9),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.surface,
		Parent = containerWrapper.instance,
		style = {
			cornerRadius = Theme.radius.xl,
			shadow = {
				blur = 30,
				transparency = 0.8,
				color = Theme.colors.shadow,
			},
			sizeConstraint = {
				max = Vector2.new(1400, 900),
				min = Vector2.new(400, 500),
			},
		},
	}):render()
	
	-- Blur effect
	self.blur = Instance.new("BlurEffect")
	self.blur.Name = "ShopBlur"
	self.blur.Size = 0
	self.blur.Parent = Lighting
	
	-- Create main sections
	self:createHeader()
	self:createNavigation()
	self:createContent()
	
	-- Load initial tab
	self:switchTab("cash")
end

function ShopManager:createHeader()
	self.header = Frame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, UI_CONSTANTS.HEADER_HEIGHT),
		BackgroundColor3 = Theme.colors.surfaceVariant,
		Parent = self.mainContainer.instance,
		style = {
			cornerRadius = Theme.radius.xl,
			padding = Theme.spacing.lg,
		},
	}):render()
	
	-- Header mask to hide bottom corners
	local headerMask = Frame({
		Name = "HeaderMask",
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -20),
		BackgroundColor3 = Theme.colors.surfaceVariant,
		BorderSizePixel = 0,
		Parent = self.header.instance,
	}):render()
	
	-- Header layout
	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, Theme.spacing.md)
	headerLayout.Parent = self.header.instance
	
	-- Shop icon
	local shopIcon = Image({
		Name = "ShopIcon",
		Image = Assets.icons.shop,
		Size = UDim2.fromOffset(40, 40),
		LayoutOrder = 1,
		Parent = self.header.instance,
	}):render()
	
	-- Title
	local title = Text({
		Name = "Title",
		Text = "Tycoon Shop",
		Font = Theme.typography.fontFamily.bold,
		TextSize = Theme.typography.scale.headlineLarge,
		Size = UDim2.new(1, -100, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Parent = self.header.instance,
	}):render()
	
	-- Close button
	local closeButton = Button({
		Name = "CloseButton",
		Text = "",
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Theme.colors.error,
		LayoutOrder = 3,
		Parent = self.header.instance,
		onClick = function()
			self:close()
		end,
		style = {
			cornerRadius = Theme.radius.full,
		},
	}):render()
	
	-- Close icon
	local closeIcon = Image({
		Name = "CloseIcon",
		Image = Assets.icons.close,
		Size = UDim2.fromScale(0.6, 0.6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageColor3 = Theme.colors.onPrimary,
		Parent = closeButton.instance,
	}):render()
	
	-- Close button hover
	closeButton.instance.MouseEnter:Connect(function()
		self.soundManager:play("hover", 0.05)
		tween(closeButton.instance, {
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = Color3.fromRGB(235, 102, 122),
		}, ANIMATION_SPEEDS.FAST, Enum.EasingStyle.Back)
	end)
	
	closeButton.instance.MouseLeave:Connect(function()
		tween(closeButton.instance, {
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = Theme.colors.error,
		}, ANIMATION_SPEEDS.FAST)
	end)
end

function ShopManager:createNavigation()
	local isMobile = isSmallScreen()
	
	self.navigation = Frame({
		Name = "Navigation",
		Size = isMobile and UDim2.new(1, -32, 0, UI_CONSTANTS.NAV_HEIGHT_MOBILE) or UDim2.new(0, UI_CONSTANTS.NAV_WIDTH_DESKTOP, 1, -UI_CONSTANTS.HEADER_HEIGHT - 16),
		Position = isMobile and UDim2.new(0, 16, 0, UI_CONSTANTS.HEADER_HEIGHT + 8) or UDim2.new(0, 16, 0, UI_CONSTANTS.HEADER_HEIGHT + 8),
		BackgroundColor3 = Theme.colors.surfaceVariant,
		Parent = self.mainContainer.instance,
		style = {
			cornerRadius = Theme.radius.md,
			padding = Theme.spacing.md,
		},
	}):render()
	
	-- Navigation layout
	local navLayout = Instance.new("UIListLayout")
	navLayout.FillDirection = isMobile and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	navLayout.HorizontalAlignment = isMobile and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left
	navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	navLayout.Padding = UDim.new(0, Theme.spacing.sm)
	navLayout.Parent = self.navigation.instance
	
	-- Navigation items
	local navItems = {
		{id = "cash", name = "Cash Packs", icon = Assets.icons.cash, color = Theme.colors.primary},
		{id = "passes", name = "Game Passes", icon = Assets.icons.gamepass, color = Theme.colors.secondary},
	}
	
	self.navButtons = {}
	
	for _, item in ipairs(navItems) do
		local navButton = self:createNavButton(item, isMobile)
		self.navButtons[item.id] = navButton
	end
end

function ShopManager:createNavButton(item, isMobile)
	local button = Button({
		Name = item.id .. "NavButton",
		Text = "",
		Size = isMobile and UDim2.new(0.5, -4, 1, 0) or UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = Theme.colors.surface,
		Parent = self.navigation.instance,
		onClick = function()
			self:switchTab(item.id)
		end,
		style = {
			cornerRadius = Theme.radius.md,
		},
	}):render()
	
	-- Button layout
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	buttonLayout.Padding = UDim.new(0, Theme.spacing.sm)
	buttonLayout.Parent = button.instance
	
	-- Icon
	local icon = Image({
		Name = "Icon",
		Image = item.icon,
		Size = UDim2.fromOffset(24, 24),
		ImageColor3 = Theme.colors.onSurfaceVariant,
		LayoutOrder = 1,
		Parent = button.instance,
	}):render()
	
	-- Label
	local label = Text({
		Name = "Label",
		Text = item.name,
		Font = Theme.typography.fontFamily.medium,
		TextSize = Theme.typography.scale.labelLarge,
		TextColor3 = Theme.colors.onSurfaceVariant,
		Size = UDim2.new(0, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Parent = button.instance,
	}):render()
	
	-- Auto-size label
	label.instance.Size = UDim2.new(0, label.instance.TextBounds.X, 1, 0)
	
	-- Store references
	button.icon = icon
	button.label = label
	button.color = item.color
	
	-- Hover effects
	button.instance.MouseEnter:Connect(function()
		if self.currentTab ~= item.id then
			self.soundManager:play("hover", 0.05)
			tween(button.instance, {BackgroundColor3 = Color3.new(0.95, 0.95, 0.95)}, ANIMATION_SPEEDS.FAST)
			tween(icon.instance, {ImageColor3 = item.color}, ANIMATION_SPEEDS.FAST)
			tween(label.instance, {TextColor3 = item.color}, ANIMATION_SPEEDS.FAST)
		end
	end)
	
	button.instance.MouseLeave:Connect(function()
		if self.currentTab ~= item.id then
			tween(button.instance, {BackgroundColor3 = Theme.colors.surface}, ANIMATION_SPEEDS.FAST)
			tween(icon.instance, {ImageColor3 = Theme.colors.onSurfaceVariant}, ANIMATION_SPEEDS.FAST)
			tween(label.instance, {TextColor3 = Theme.colors.onSurfaceVariant}, ANIMATION_SPEEDS.FAST)
		end
	end)
	
	return button
end

function ShopManager:createContent()
	local isMobile = isSmallScreen()
	
	self.contentArea = Frame({
		Name = "ContentArea",
		Size = isMobile and UDim2.new(1, -32, 1, -UI_CONSTANTS.HEADER_HEIGHT - UI_CONSTANTS.NAV_HEIGHT_MOBILE - 32) or UDim2.new(1, -UI_CONSTANTS.NAV_WIDTH_DESKTOP - 48, 1, -UI_CONSTANTS.HEADER_HEIGHT - 16),
		Position = isMobile and UDim2.new(0, 16, 0, UI_CONSTANTS.HEADER_HEIGHT + UI_CONSTANTS.NAV_HEIGHT_MOBILE + 16) or UDim2.new(0, UI_CONSTANTS.NAV_WIDTH_DESKTOP + 32, 0, UI_CONSTANTS.HEADER_HEIGHT + 8),
		BackgroundTransparency = 1,
		Parent = self.mainContainer.instance,
	}):render()
	
	-- Create pages
	self.pages.cash = self:createCashPage()
	self.pages.passes = self:createPassesPage()
	
	-- Hide all pages initially
	for _, page in pairs(self.pages) do
		page.instance.Visible = false
	end
end

function ShopManager:createCashPage()
	local page = Frame({
		Name = "CashPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = self.contentArea.instance,
	}):render()
	
	-- Page header
	local header = Frame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundColor3 = Theme.colors.primaryContainer,
		Parent = page.instance,
		style = {
			cornerRadius = Theme.radius.md,
			padding = Theme.spacing.lg,
		},
	}):render()
	
	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, Theme.spacing.md)
	headerLayout.Parent = header.instance
	
	-- Icon
	local icon = Image({
		Name = "Icon",
		Image = Assets.icons.cash,
		Size = UDim2.fromOffset(32, 32),
		ImageColor3 = Theme.colors.primary,
		LayoutOrder = 1,
		Parent = header.instance,
	}):render()
	
	-- Title
	local title = Text({
		Name = "Title",
		Text = "Cash Packs",
		Font = Theme.typography.fontFamily.bold,
		TextSize = Theme.typography.scale.headlineMedium,
		TextColor3 = Theme.colors.onSurface,
		Size = UDim2.new(0.5, -40, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Parent = header.instance,
	}):render()
	
	-- Balance display
	local balance = Text({
		Name = "Balance",
		Text = "Balance: $0",
		Font = Theme.typography.fontFamily.medium,
		TextSize = Theme.typography.scale.bodyLarge,
		TextColor3 = Theme.colors.onSurfaceVariant,
		Size = UDim2.new(0.5, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		LayoutOrder = 3,
		Parent = header.instance,
	}):render()
	
	-- Scroll container
	local scrollContainer = ScrollFrame({
		Name = "ScrollContainer",
		Size = UDim2.new(1, 0, 1, -70),
		Position = UDim2.new(0, 0, 0, 70),
		Parent = page.instance,
		style = {
			padding = Theme.spacing.sm,
		},
	}):render()
	
	-- Grid layout
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(Theme.spacing.md, Theme.spacing.md)
	grid.CellSize = UDim2.new(1/3, -Theme.spacing.md * 2/3, 0, 240)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.FillDirectionMaxCells = getGridColumns()
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scrollContainer.instance
	
	-- Store grid reference
	page.grid = grid
	
	-- Create cash pack cards
	for i, pack in ipairs(ProductData.cashPacks) do
		self:createCashCard(pack, scrollContainer.instance, i)
	end
	
	return page
end

function ShopManager:createCashCard(pack, parent, order)
	local card = Frame({
		Name = pack.name:gsub(" ", "") .. "Card",
		BackgroundColor3 = Theme.colors.surface,
		LayoutOrder = order,
		Parent = parent,
		style = {
			cornerRadius = Theme.radius.md,
			stroke = {
				color = Theme.colors.primary,
				thickness = 2,
				transparency = 0.8,
			},
			shadow = {
				blur = 10,
				transparency = 0.95,
				color = Theme.colors.primary,
			},
		},
	}):render()
	
	-- Card layout
	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Vertical
	cardLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardLayout.Padding = UDim.new(0, Theme.spacing.sm)
	cardLayout.Parent = card.instance
	
	-- Add padding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, Theme.spacing.lg)
	padding.PaddingBottom = UDim.new(0, Theme.spacing.lg)
	padding.PaddingLeft = UDim.new(0, Theme.spacing.lg)
	padding.PaddingRight = UDim.new(0, Theme.spacing.lg)
	padding.Parent = card.instance
	
	-- Icon container
	local iconContainer = Frame({
		Name = "IconContainer",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Theme.colors.primaryContainer,
		LayoutOrder = 1,
		Parent = card.instance,
		style = {
			cornerRadius = Theme.radius.md,
		},
	}):render()
	
	-- Icon
	local icon = Image({
		Name = "Icon",
		Image = Assets.icons.cash,
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageColor3 = Theme.colors.primary,
		Parent = iconContainer.instance,
	}):render()
	
	-- Name
	local name = Text({
		Name = "Name",
		Text = pack.name,
		Font = Theme.typography.fontFamily.bold,
		TextSize = Theme.typography.scale.bodyLarge,
		TextColor3 = Theme.colors.onSurface,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = 2,
		Parent = card.instance,
	}):render()
	
	-- Description
	local description = Text({
		Name = "Description",
		Text = pack.description,
		Font = Theme.typography.fontFamily.regular,
		TextSize = Theme.typography.scale.bodySmall,
		TextColor3 = Theme.colors.onSurfaceVariant,
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = 3,
		Parent = card.instance,
	}):render()
	
	-- Amount
	local amount = Text({
		Name = "Amount",
		Text = formatNumberWithCommas(pack.amount) .. " Cash",
		Font = Theme.typography.fontFamily.medium,
		TextSize = Theme.typography.scale.bodyMedium,
		TextColor3 = Theme.colors.primary,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 4,
		Parent = card.instance,
	}):render()
	
	-- Price
	local price = Text({
		Name = "Price",
		Text = "R$" .. (pack.price or "???"),
		Font = Theme.typography.fontFamily.bold,
		TextSize = Theme.typography.scale.headlineSmall,
		TextColor3 = Theme.colors.onSurface,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = 5,
		Parent = card.instance,
	}):render()
	
	-- Buy button
	local buyButton = Button({
		Name = "BuyButton",
		Text = "Purchase",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Theme.colors.primary,
		TextColor3 = Theme.colors.onPrimary,
		Font = Theme.typography.fontFamily.bold,
		TextSize = Theme.typography.scale.labelLarge,
		LayoutOrder = 6,
		Parent = card.instance,
		onClick = function()
			self:purchaseProduct(pack)
		end,
		style = {
			cornerRadius = Theme.radius.md,
		},
	}):render()
	
	-- Store references
	pack._card = card
	pack._priceLabel = price
	pack._buyButton = buyButton
	
	-- Hover effects
	card.instance.MouseEnter:Connect(function()
		tween(card.instance, {BackgroundColor3 = Theme.colors.surfaceVariant}, ANIMATION_SPEEDS.FAST)
		tween(icon.instance, {Size = UDim2.fromOffset(52, 52)}, ANIMATION_SPEEDS.FAST, Enum.EasingStyle.Back)
	end)
	
	card.instance.MouseLeave:Connect(function()
		tween(card.instance, {BackgroundColor3 = Theme.colors.surface}, ANIMATION_SPEEDS.FAST)
		tween(icon.instance, {Size = UDim2.fromOffset(48, 48)}, ANIMATION_SPEEDS.FAST)
	end)
	
	-- Special effects for featured items
	if order <= 3 then
		task.spawn(function()
			while card.instance.Parent do
				local stroke = card.instance:FindFirstChildOfClass("UIStroke")
				if stroke then
					tween(stroke, {Transparency = 0.5}, 2, Enum.EasingStyle.Sine)
					task.wait(2)
					tween(stroke, {Transparency = 0.8}, 2, Enum.EasingStyle.Sine)
					task.wait(2)
				else
					task.wait(1)
				end
			end
		end)
	end
end

function ShopManager:createPassesPage()
	local page = Frame({
		Name = "PassesPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = self.contentArea.instance,
	}):render()
	
	-- Page header
	local header = Frame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundColor3 = Theme.colors.secondaryContainer,
		Parent = page.instance,
		style = {
			cornerRadius = Theme.radius.md,
			padding = Theme.spacing.lg,
		},
	}):render()
	
	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, Theme.spacing.md)
	headerLayout.Parent = header.instance
	
	-- Icon
	local icon = Image({
		Name = "Icon",
		Image = Assets.icons.gamepass,
		Size = UDim2.fromOffset(32, 32),
		ImageColor3 = Theme.colors.secondary,
		LayoutOrder = 1,
		Parent = header.instance,
	}):render()
	
	-- Title
	local title = Text({
		Name = "Title",
		Text = "Game Passes",
		Font = Theme.typography.fontFamily.bold,
		TextSize = Theme.typography.scale.headlineMedium,
		TextColor3 = Theme.colors.onSurface,
		Size = UDim2.new(1, -40, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Parent = header.instance,
	}):render()
	
	-- Content wrapper
	local contentWrapper = Frame({
		Name = "ContentWrapper",
		Size = UDim2.new(1, 0, 1, -70),
		Position = UDim2.new(0, 0, 0, 70),
		BackgroundTransparency = 1,
		Parent = page.instance,
	}):render()
	
	-- Passes container
	local passesContainer = Frame({
		Name = "PassesContainer",
		Size = UDim2.new(1, 0, 1, -80),
		BackgroundTransparency = 1,
		Parent = contentWrapper.instance,
		style = {
			padding = Theme.spacing.sm,
		},
	}):render()
	
	-- Grid layout
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(Theme.spacing.lg, Theme.spacing.lg)
	grid.CellSize = UDim2.new(0.5, -Theme.spacing.lg/2, 0, 260)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Top
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = passesContainer.instance
	
	-- Create pass cards
	for i, pass in ipairs(ProductData.gamePasses) do
		self:createPassCard(pass, passesContainer.instance, i)
	end
	
	-- Settings panel
	local settingsPanel = Frame({
		Name = "SettingsPanel",
		Size = UDim2.new(1, 0, 0, 70),
		Position = UDim2.new(0, 0, 1, -70),
		BackgroundColor3 = Theme.colors.surfaceVariant,
		Parent = contentWrapper.instance,
		style = {
			cornerRadius = Theme.radius.md,
			padding = Theme.spacing.lg,
		},
	}):render()
	
	local settingsLayout = Instance.new("UIListLayout")
	settingsLayout.FillDirection = Enum.FillDirection.Horizontal
	settingsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	settingsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	settingsLayout.Padding = UDim.new(0, Theme.spacing.md)
	settingsLayout.Parent = settingsPanel.instance
	
	-- Settings icon
	local settingsIcon = Image({
		Name = "SettingsIcon",
		Image = Assets.icons.settings,
		Size = UDim2.fromOffset(24, 24),
		ImageColor3 = Theme.colors.onSurfaceVariant,
		LayoutOrder = 1,
		Parent = settingsPanel.instance,
	}):render()
	
	-- Settings title
	local settingsTitle = Text({
		Name = "SettingsTitle",
		Text = "Quick Settings",
		Font = Theme.typography.fontFamily.medium,
		TextSize = Theme.typography.scale.bodyLarge,
		TextColor3 = Theme.colors.onSurface,
		Size = UDim2.new(0.5, -30, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Parent = settingsPanel.instance,
	}):render()
	
	-- Auto-collect toggle
	self.autoCollectToggle = self:createToggle({
		Name = "AutoCollectToggle",
		Label = "Auto Collect",
		Parent = settingsPanel.instance,
		LayoutOrder = 3,
		onChange = function(state)
			self:setAutoCollect(state)
		end,
	})
	
	-- Initially hide settings toggle
	self.autoCollectToggle.instance.Visible = false
	
	return page
end

function ShopManager:createPassCard(pass, parent, order)
	local card = Frame({
		Name = pass.name:gsub(" ", "") .. "Card",
		BackgroundColor3 = Theme.colors.surface,
		LayoutOrder = order,
		Parent = parent,
		style = {
			cornerRadius = Theme.radius.md,
			stroke = {
				color = Theme.colors.secondary,
				thickness = 2,
				transparency = 0.8,
			},
			shadow = {
				blur = 10,
				transparency = 0.95,
				color = Theme.colors.secondary,
			},
		},
	}):render()
	
	-- Card layout
	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Vertical
	cardLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardLayout.Padding = UDim.new(0, Theme.spacing.md)
	cardLayout.Parent = card.instance
	
	-- Add padding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, Theme.spacing.xl)
	padding.PaddingBottom = UDim.new(0, Theme.spacing.xl)
	padding.PaddingLeft = UDim.new(0, Theme.spacing.xl)
	padding.PaddingRight = UDim.new(0, Theme.spacing.xl)
	padding.Parent = card.instance
	
	-- Icon container
	local iconContainer = Frame({
		Name = "IconContainer",
		Size = UDim2.new(1, 0, 0, 80),
		BackgroundColor3 = Theme.colors.secondaryContainer,
		LayoutOrder = 1,
		Parent = card.instance,
		style = {
			cornerRadius = Theme.radius.md,
		},
	}):render()
	
	-- Icon
	local icon = Image({
		Name = "Icon",
		Image = Assets.icons.gamepass,
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageColor3 = Theme.colors.secondary,
		Parent = iconContainer.instance,
	}):render()
	
	-- Name
	local name = Text({
		Name = "Name",
		Text = pass.name,
		Font = Theme.typography.fontFamily.bold,
		TextSize = Theme.typography.scale.headlineSmall,
		TextColor3 = Theme.colors.onSurface,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = 2,
		Parent = card.instance,
	}):render()
	
	-- Description
	local description = Text({
		Name = "Description",
		Text = pass.description,
		Font = Theme.typography.fontFamily.regular,
		TextSize = Theme.typography.scale.bodyMedium,
		TextColor3 = Theme.colors.onSurfaceVariant,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 3,
		Parent = card.instance,
	}):render()
	
	-- Price
	local price = Text({
		Name = "Price",
		Text = "R$" .. (pass.price or "???"),
		Font = Theme.typography.fontFamily.bold,
		TextSize = Theme.typography.scale.headlineMedium,
		TextColor3 = Theme.colors.secondary,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = 4,
		Parent = card.instance,
	}):render()
	
	-- Buy button
	local buyButton = Button({
		Name = "BuyButton",
		Text = "Purchase",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Theme.colors.secondary,
		TextColor3 = Theme.colors.onSecondary,
		Font = Theme.typography.fontFamily.bold,
		TextSize = Theme.typography.scale.labelLarge,
		LayoutOrder = 5,
		Parent = card.instance,
		onClick = function()
			self:purchaseGamePass(pass)
		end,
		style = {
			cornerRadius = Theme.radius.md,
		},
	}):render()
	
	-- Toggle for auto-collect
	if pass.hasToggle then
		local toggleContainer = Frame({
			Name = "ToggleContainer",
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			LayoutOrder = 6,
			Parent = card.instance,
		}):render()
		
		pass._toggle = self:createToggle({
			Name = "Toggle",
			Label = "Enable",
			Parent = toggleContainer.instance,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			onChange = function(state)
				self:setAutoCollect(state)
			end,
		})
		
		pass._toggle.instance.Visible = false
	end
	
	-- Store references
	pass._card = card
	pass._priceLabel = price
	pass._buyButton = buyButton
	pass._icon = icon
	
	-- Check ownership
	local owned = self:checkOwnership(pass.id)
	if owned then
		self:updatePassOwned(pass)
	end
	
	-- Hover effects
	card.instance.MouseEnter:Connect(function()
		tween(card.instance, {BackgroundColor3 = Theme.colors.surfaceVariant}, ANIMATION_SPEEDS.FAST)
		tween(icon.instance, {Size = UDim2.fromOffset(60, 60)}, ANIMATION_SPEEDS.FAST, Enum.EasingStyle.Back)
	end)
	
	card.instance.MouseLeave:Connect(function()
		tween(card.instance, {BackgroundColor3 = Theme.colors.surface}, ANIMATION_SPEEDS.FAST)
		tween(icon.instance, {Size = UDim2.fromOffset(56, 56)}, ANIMATION_SPEEDS.FAST)
	end)
end

function ShopManager:createToggle(props)
	local container = Frame({
		Name = props.Name or "Toggle",
		Size = UDim2.fromOffset(160, 36),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	}):render()
	
	-- Label
	local label = Text({
		Name = "Label",
		Text = props.Label or "Toggle",
		Font = Theme.typography.fontFamily.medium,
		TextSize = Theme.typography.scale.bodyMedium,
		TextColor3 = Theme.colors.onSurfaceVariant,
		Size = UDim2.fromOffset(90, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = container.instance,
	}):render()
	
	-- Toggle background
	local toggleBg = Frame({
		Name = "ToggleBackground",
		Size = UDim2.fromOffset(52, 28),
		Position = UDim2.fromOffset(100, 4),
		BackgroundColor3 = Theme.colors.outline,
		Parent = container.instance,
		style = {
			cornerRadius = Theme.radius.full,
		},
	}):render()
	
	-- Toggle knob
	local knob = Frame({
		Name = "Knob",
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Theme.colors.surface,
		Parent = toggleBg.instance,
		style = {
			cornerRadius = Theme.radius.full,
			shadow = {
				blur = 4,
				transparency = 0.9,
			},
		},
	}):render()
	
	-- State
	local state = false
	
	-- Toggle button
	local toggleButton = Button({
		Name = "ToggleButton",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = container.instance,
		onClick = function()
			state = not state
			self:updateToggleVisual(toggleBg.instance, knob.instance, state)
			self.soundManager:play("click", 0.08)
			if props.onChange then
				props.onChange(state)
			end
		end,
	}):render()
	
	-- Methods
	container.setState = function(newState)
		state = newState
		self:updateToggleVisual(toggleBg.instance, knob.instance, state)
	end
	
	container.getState = function()
		return state
	end
	
	return container
end

function ShopManager:updateToggleVisual(bg, knob, state)
	if state then
		tween(bg, {BackgroundColor3 = Theme.colors.primary}, ANIMATION_SPEEDS.FAST)
		tween(knob, {Position = UDim2.fromOffset(26, 2)}, ANIMATION_SPEEDS.FAST, Enum.EasingStyle.Back)
	else
		tween(bg, {BackgroundColor3 = Theme.colors.outline}, ANIMATION_SPEEDS.FAST)
		tween(knob, {Position = UDim2.fromOffset(2, 2)}, ANIMATION_SPEEDS.FAST, Enum.EasingStyle.Back)
	end
end

function ShopManager:createToggleButton()
	-- Clean up existing
	if PlayerGui:FindFirstChild("TycoonShopToggle") then
		PlayerGui.TycoonShopToggle:Destroy()
	end
	
	local toggleGui = Instance.new("ScreenGui")
	toggleGui.Name = "TycoonShopToggle"
	toggleGui.ResetOnSpawn = false
	toggleGui.DisplayOrder = 50
	toggleGui.Parent = PlayerGui
	
	self.toggleButton = ImageButton({
		Name = "ToggleButton",
		Image = Assets.icons.shop,
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.new(1, -80, 1, -80),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.surface,
		ImageColor3 = Theme.colors.primary,
		Parent = toggleGui,
		onClick = function()
			self:toggle()
		end,
		style = {
			cornerRadius = Theme.radius.full,
			stroke = {
				color = Theme.colors.primary,
				thickness = 2,
				transparency = 0.7,
			},
			shadow = {
				blur = 20,
				transparency = 0.85,
			},
		},
	}):render()
	
	-- Hover effects
	self.toggleButton.instance.MouseEnter:Connect(function()
		self.soundManager:play("hover", 0.05)
		tween(self.toggleButton.instance, {
			Size = UDim2.fromOffset(72, 72),
			BackgroundColor3 = Theme.colors.primary,
		}, ANIMATION_SPEEDS.FAST, Enum.EasingStyle.Back)
		tween(self.toggleButton.instance, {
			ImageColor3 = Theme.colors.onPrimary,
		}, ANIMATION_SPEEDS.FAST)
	end)
	
	self.toggleButton.instance.MouseLeave:Connect(function()
		tween(self.toggleButton.instance, {
			Size = UDim2.fromOffset(64, 64),
			BackgroundColor3 = Theme.colors.surface,
		}, ANIMATION_SPEEDS.FAST)
		tween(self.toggleButton.instance, {
			ImageColor3 = Theme.colors.primary,
		}, ANIMATION_SPEEDS.FAST)
	end)
	
	-- Floating animation
	task.spawn(function()
		while self.toggleButton and self.toggleButton.instance.Parent do
			tween(self.toggleButton.instance, {
				Position = UDim2.new(1, -80, 1, -85),
			}, 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(3)
			tween(self.toggleButton.instance, {
				Position = UDim2.new(1, -80, 1, -75),
			}, 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(3)
		end
	end)
end

function ShopManager:setupInputHandling()
	-- Keyboard
	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.M then
			self:toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and self.isOpen then
			self:close()
		end
	end))
	
	-- Gamepad
	ContextActionService:BindAction("ToggleShop", function(actionName, inputState, inputObject)
		if inputState == Enum.UserInputState.Begin then
			self:toggle()
		end
	end, false, Enum.KeyCode.ButtonX)
end

function ShopManager:setupResponsiveHandling()
	local function updateLayout()
		if not self.mainContainer then return end
		
		local viewport = getViewportSize()
		local isMobile = viewport.X < UI_CONSTANTS.MOBILE_BREAKPOINT
		local columns = getGridColumns()
		
		-- Update navigation
		if self.navigation then
			if isMobile then
				self.navigation.instance.Size = UDim2.new(1, -32, 0, UI_CONSTANTS.NAV_HEIGHT_MOBILE)
				self.navigation.instance.Position = UDim2.new(0, 16, 0, UI_CONSTANTS.HEADER_HEIGHT + 8)
				
				local navLayout = self.navigation.instance:FindFirstChildOfClass("UIListLayout")
				if navLayout then
					navLayout.FillDirection = Enum.FillDirection.Horizontal
					navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				end
				
				-- Update nav button sizes
				for _, button in pairs(self.navButtons) do
					button.instance.Size = UDim2.new(0.5, -4, 1, 0)
				end
			else
				self.navigation.instance.Size = UDim2.new(0, UI_CONSTANTS.NAV_WIDTH_DESKTOP, 1, -UI_CONSTANTS.HEADER_HEIGHT - 16)
				self.navigation.instance.Position = UDim2.new(0, 16, 0, UI_CONSTANTS.HEADER_HEIGHT + 8)
				
				local navLayout = self.navigation.instance:FindFirstChildOfClass("UIListLayout")
				if navLayout then
					navLayout.FillDirection = Enum.FillDirection.Vertical
					navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
				end
				
				-- Update nav button sizes
				for _, button in pairs(self.navButtons) do
					button.instance.Size = UDim2.new(1, 0, 0, 56)
				end
			end
		end
		
		-- Update content area
		if self.contentArea then
			if isMobile then
				self.contentArea.instance.Size = UDim2.new(1, -32, 1, -UI_CONSTANTS.HEADER_HEIGHT - UI_CONSTANTS.NAV_HEIGHT_MOBILE - 32)
				self.contentArea.instance.Position = UDim2.new(0, 16, 0, UI_CONSTANTS.HEADER_HEIGHT + UI_CONSTANTS.NAV_HEIGHT_MOBILE + 16)
			else
				self.contentArea.instance.Size = UDim2.new(1, -UI_CONSTANTS.NAV_WIDTH_DESKTOP - 48, 1, -UI_CONSTANTS.HEADER_HEIGHT - 16)
				self.contentArea.instance.Position = UDim2.new(0, UI_CONSTANTS.NAV_WIDTH_DESKTOP + 32, 0, UI_CONSTANTS.HEADER_HEIGHT + 8)
			end
		end
		
		-- Update grids
		if self.pages.cash and self.pages.cash.grid then
			self.pages.cash.grid.FillDirectionMaxCells = columns
			self.pages.cash.grid.CellSize = UDim2.new(1/columns, -Theme.spacing.md * (columns-1)/columns, 0, columns == 1 and 280 or 240)
		end
	end
	
	-- Initial update
	updateLayout()
	
	-- Listen for changes
	local camera = workspace.CurrentCamera
	if camera then
		table.insert(self.connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout))
	end
end

function ShopManager:setupMarketplaceCallbacks()
	-- Game pass purchase finished
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if player ~= Player then return end
		
		debugPrint("Game pass purchase finished:", passId, wasPurchased)
		
		if wasPurchased then
			self.ownershipCache:clear()
			self:refreshOwnership()
			self.soundManager:play("purchase", 0.2)
			
			-- Notify server
			if Remotes then
				local event = Remotes:FindFirstChild("GamepassPurchased")
				if event and event:IsA("RemoteEvent") then
					event:FireServer(passId)
				end
			end
		end
	end)
	
	-- Product purchase finished
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, wasPurchased)
		if player ~= Player then return end
		
		debugPrint("Product purchase finished:", productId, wasPurchased)
		
		if wasPurchased and Remotes then
			local event = Remotes:FindFirstChild("GrantProductCurrency")
			if event and event:IsA("RemoteEvent") then
				event:FireServer(productId)
			end
			
			self.soundManager:play("purchase", 0.2)
		end
	end)
end

function ShopManager:switchTab(tabId)
	if self.currentTab == tabId then return end
	
	debugPrint("Switching to tab:", tabId)
	
	self.currentTab = tabId
	self.soundManager:play("click", 0.08)
	
	-- Update navigation buttons
	for id, button in pairs(self.navButtons) do
		local isActive = id == tabId
		
		tween(button.instance, {
			BackgroundColor3 = isActive and button.color or Theme.colors.surface,
		}, ANIMATION_SPEEDS.FAST)
		
		tween(button.icon.instance, {
			ImageColor3 = isActive and Theme.colors.onPrimary or Theme.colors.onSurfaceVariant,
		}, ANIMATION_SPEEDS.FAST)
		
		tween(button.label.instance, {
			TextColor3 = isActive and Theme.colors.onPrimary or Theme.colors.onSurfaceVariant,
		}, ANIMATION_SPEEDS.FAST)
	end
	
	-- Update page visibility
	for id, page in pairs(self.pages) do
		page.instance.Visible = id == tabId
	end
	
	-- Emit event
	self.eventEmitter:emit("tabChanged", tabId)
end

function ShopManager:open()
	if self.isOpen or self.isAnimating then return end
	
	debugPrint("Opening shop")
	
	self.isAnimating = true
	self.isOpen = true
	
	-- Refresh data
	self:refreshPrices()
	self:refreshOwnership()
	
	-- Enable GUI
	self.gui.Enabled = true
	self.soundManager:play("open", 0.15)
	
	-- Animate blur
	tween(self.blur, {Size = UI_CONSTANTS.BLUR_SIZE}, ANIMATION_SPEEDS.MEDIUM)
	
	-- Animate main container
	self.mainContainer.instance.Position = UDim2.fromScale(0.5, 0.55)
	self.mainContainer.instance.Size = UDim2.fromScale(0.9, 0.85)
	
	tween(self.mainContainer.instance, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.95, 0.9),
	}, ANIMATION_SPEEDS.SLOW, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function()
		self.isAnimating = false
		self.eventEmitter:emit("shopOpened")
	end)
	
	-- Start auto-refresh
	if self.settings.autoRefresh then
		self:startAutoRefresh()
	end
end

function ShopManager:close()
	if not self.isOpen or self.isAnimating then return end
	
	debugPrint("Closing shop")
	
	self.isAnimating = true
	self.isOpen = false
	
	-- Stop auto-refresh
	self:stopAutoRefresh()
	
	self.soundManager:play("close", 0.15)
	
	-- Animate blur
	tween(self.blur, {Size = 0}, ANIMATION_SPEEDS.FAST)
	
	-- Animate main container
	tween(self.mainContainer.instance, {
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.9, 0.85),
	}, ANIMATION_SPEEDS.FAST, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function()
		self.gui.Enabled = false
		self.isAnimating = false
		self.eventEmitter:emit("shopClosed")
	end)
end

function ShopManager:toggle()
	if self.isOpen then
		self:close()
	else
		self:open()
	end
end

function ShopManager:refreshPrices()
	debugPrint("Refreshing prices")
	
	-- Cash packs
	for _, pack in ipairs(ProductData.cashPacks) do
		local cachedPrice = self.priceCache:get("product_" .. pack.id)
		if not cachedPrice then
			local success, info = pcall(function()
				return MarketplaceService:GetProductInfo(pack.id, Enum.InfoType.Product)
			end)
			
			if success and info then
				pack.price = info.PriceInRobux
				self.priceCache:set("product_" .. pack.id, info.PriceInRobux)
			end
		else
			pack.price = cachedPrice
		end
		
		-- Update UI
		if pack._priceLabel then
			pack._priceLabel.instance.Text = "R$" .. (pack.price or "???")
		end
	end
	
	-- Game passes
	for _, pass in ipairs(ProductData.gamePasses) do
		local cachedPrice = self.priceCache:get("pass_" .. pass.id)
		if not cachedPrice then
			local success, info = pcall(function()
				return MarketplaceService:GetProductInfo(pass.id, Enum.InfoType.GamePass)
			end)
			
			if success and info then
				pass.price = info.PriceInRobux
				self.priceCache:set("pass_" .. pass.id, info.PriceInRobux)
			end
		else
			pass.price = cachedPrice
		end
		
		-- Update UI
		if pass._priceLabel then
			pass._priceLabel.instance.Text = "R$" .. (pass.price or "???")
		end
	end
end

function ShopManager:refreshOwnership()
	debugPrint("Refreshing ownership")
	
	local hasAutoCollect = false
	
	for _, pass in ipairs(ProductData.gamePasses) do
		local owned = self:checkOwnership(pass.id)
		
		if owned then
			self:updatePassOwned(pass)
			
			if pass.id == 1412171840 then -- Auto collect ID
				hasAutoCollect = true
			end
		end
	end
	
	-- Update settings visibility
	if self.autoCollectToggle then
		self.autoCollectToggle.instance.Visible = hasAutoCollect
		
		-- Get current state from server
		if hasAutoCollect and Remotes then
			local func = Remotes:FindFirstChild("GetAutoCollectState")
			if func and func:IsA("RemoteFunction") then
				local success, state = pcall(function()
					return func:InvokeServer()
				end)
				
				if success and type(state) == "boolean" then
					self.autoCollectToggle.setState(state)
				end
			end
		end
	end
end

function ShopManager:checkOwnership(passId)
	local cacheKey = Player.UserId .. "_" .. passId
	local cached = self.ownershipCache:get(cacheKey)
	
	if cached ~= nil then
		return cached
	end
	
	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, passId)
	end)
	
	if success then
		self.ownershipCache:set(cacheKey, owns)
		return owns
	end
	
	return false
end

function ShopManager:updatePassOwned(pass)
	if not pass._buyButton then return end
	
	-- Update button
	pass._buyButton.instance.Text = "✓ Owned"
	pass._buyButton.instance.Active = false
	pass._buyButton.instance.BackgroundColor3 = Theme.colors.success
	
	-- Add check icon
	local checkIcon = Image({
		Name = "CheckIcon",
		Image = Assets.icons.check,
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ImageColor3 = Theme.colors.onPrimary,
		Parent = pass._buyButton.instance,
	}):render()
	
	-- Update card stroke
	local stroke = pass._card.instance:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Theme.colors.success
		stroke.Transparency = 0.6
	end
	
	-- Show toggle if applicable
	if pass._toggle then
		pass._toggle.instance.Visible = true
		
		-- Get state from server
		if Remotes then
			local func = Remotes:FindFirstChild("GetAutoCollectState")
			if func and func:IsA("RemoteFunction") then
				local success, state = pcall(function()
					return func:InvokeServer()
				end)
				
				if success and type(state) == "boolean" then
					pass._toggle.setState(state)
				end
			end
		end
	end
end

function ShopManager:purchaseProduct(product)
	debugPrint("Purchasing product:", product.id)
	
	self.soundManager:play("click", 0.1)
	
	local success = pcall(function()
		MarketplaceService:PromptProductPurchase(Player, product.id)
	end)
	
	if not success then
		self.soundManager:play("error", 0.15)
	end
end

function ShopManager:purchaseGamePass(pass)
	debugPrint("Purchasing game pass:", pass.id)
	
	-- Check if already owned
	if self:checkOwnership(pass.id) then
		return
	end
	
	self.soundManager:play("click", 0.1)
	
	local success = pcall(function()
		MarketplaceService:PromptGamePassPurchase(Player, pass.id)
	end)
	
	if not success then
		self.soundManager:play("error", 0.15)
	end
end

function ShopManager:setAutoCollect(state)
	debugPrint("Setting auto collect:", state)
	
	if Remotes then
		local event = Remotes:FindFirstChild("AutoCollectToggle")
		if event and event:IsA("RemoteEvent") then
			event:FireServer(state)
		end
	end
	
	-- Sync all toggles
	if self.autoCollectToggle then
		self.autoCollectToggle.setState(state)
	end
	
	for _, pass in ipairs(ProductData.gamePasses) do
		if pass._toggle and pass.id == 1412171840 then
			pass._toggle.setState(state)
		end
	end
end

function ShopManager:startAutoRefresh()
	self:stopAutoRefresh()
	
	self.autoRefreshConnection = task.spawn(function()
		while self.isOpen do
			task.wait(UI_CONSTANTS.REFRESH_INTERVAL)
			if self.isOpen then
				self:refreshPrices()
				self:refreshOwnership()
			end
		end
	end)
end

function ShopManager:stopAutoRefresh()
	if self.autoRefreshConnection then
		task.cancel(self.autoRefreshConnection)
		self.autoRefreshConnection = nil
	end
end

function ShopManager:destroy()
	debugPrint("Destroying shop manager")
	
	-- Stop auto refresh
	self:stopAutoRefresh()
	
	-- Disconnect events
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	
	-- Unbind actions
	ContextActionService:UnbindAction("ToggleShop")
	
	-- Destroy UI
	if self.gui then
		self.gui:Destroy()
	end
	
	if self.blur then
		self.blur:Destroy()
	end
	
	if self.toggleButton then
		self.toggleButton:destroy()
	end
	
	-- Clean up systems
	self.eventEmitter:destroy()
end

-- Initialize shop
local shopManager = ShopManager.new()

-- Character respawn handling
Player.CharacterAdded:Connect(function()
	task.wait(1)
	-- Recreate toggle button if needed
	if not PlayerGui:FindFirstChild("TycoonShopToggle") then
		shopManager:createToggleButton()
	end
end)

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(player)
	if player == Player then
		shopManager:destroy()
	end
end)

print("[TycoonShop] Modern Cute UI v" .. SHOP_VERSION .. " initialized successfully!")

-- Export API
return {
	open = function() shopManager:open() end,
	close = function() shopManager:close() end,
	toggle = function() shopManager:toggle() end,
	refresh = function() 
		shopManager:refreshPrices()
		shopManager:refreshOwnership()
	end,
	destroy = function() shopManager:destroy() end,
	version = SHOP_VERSION,
}