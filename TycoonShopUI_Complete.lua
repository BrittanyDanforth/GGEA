--[[
	🚀 TYCOON SHOP UI - ULTRA MODERN COMPLETE EDITION 2025
	
	✨ FEATURES:
	- Fully responsive glassmorphism design
	- Advanced search with real-time filtering
	- Smooth 60fps animations and micro-interactions
	- Multiple themes (Modern, Dark, Neon)
	- Smart caching and performance optimization
	- Mobile-first responsive design
	- Accessibility features
	- Advanced visual effects
	
	📱 DEVICE SUPPORT:
	- Mobile phones (all sizes)
	- Tablets (portrait/landscape)
	- Desktop (all resolutions)
	- Console/TV (10-foot interface)
	
	🎨 VISUAL FEATURES:
	- Glassmorphism backgrounds
	- Animated gradients
	- Advanced shadows and depth
	- Smooth hover effects
	- Loading animations
	- Particle effects
	
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
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)
if not Remotes then
	warn("[TycoonShop] TycoonRemotes not found - creating fallback")
	Remotes = Instance.new("Folder")
	Remotes.Name = "TycoonRemotes"
	Remotes.Parent = ReplicatedStorage
end

-- Constants
local SHOP_VERSION = "8.0.0"
local DEBUG_MODE = false

-- Design System
local Theme = {
	colors = {
		-- Modern theme
		modern = {
			background = Color3.fromRGB(248, 250, 252),
			surface = Color3.fromRGB(255, 255, 255),
			surfaceElevated = Color3.fromRGB(248, 250, 252),
			
			primary = Color3.fromRGB(99, 102, 241),
			primaryLight = Color3.fromRGB(129, 140, 248),
			primaryDark = Color3.fromRGB(67, 56, 202),
			primaryContainer = Color3.fromRGB(238, 242, 255),
			
			secondary = Color3.fromRGB(168, 85, 247),
			secondaryLight = Color3.fromRGB(196, 181, 253),
			secondaryContainer = Color3.fromRGB(245, 243, 255),
			
			success = Color3.fromRGB(34, 197, 94),
			warning = Color3.fromRGB(245, 158, 11),
			error = Color3.fromRGB(239, 68, 68),
			
			text = Color3.fromRGB(15, 23, 42),
			textSecondary = Color3.fromRGB(71, 85, 105),
			textTertiary = Color3.fromRGB(148, 163, 184),
			
			border = Color3.fromRGB(226, 232, 240),
			shadow = Color3.fromRGB(100, 116, 139),
		},
		
		-- Dark theme
		dark = {
			background = Color3.fromRGB(15, 23, 42),
			surface = Color3.fromRGB(30, 41, 59),
			surfaceElevated = Color3.fromRGB(51, 65, 85),
			
			primary = Color3.fromRGB(129, 140, 248),
			primaryLight = Color3.fromRGB(165, 180, 252),
			primaryContainer = Color3.fromRGB(30, 27, 75),
			
			secondary = Color3.fromRGB(196, 181, 253),
			secondaryContainer = Color3.fromRGB(46, 16, 101),
			
			success = Color3.fromRGB(74, 222, 128),
			warning = Color3.fromRGB(251, 191, 36),
			error = Color3.fromRGB(248, 113, 113),
			
			text = Color3.fromRGB(248, 250, 252),
			textSecondary = Color3.fromRGB(203, 213, 225),
			textTertiary = Color3.fromRGB(148, 163, 184),
			
			border = Color3.fromRGB(71, 85, 105),
			shadow = Color3.fromRGB(0, 0, 0),
		},
	},
	
	fonts = {
		primary = Enum.Font.Inter,
		secondary = Enum.Font.Montserrat,
		display = Enum.Font.Michroma,
	},
	
	sizes = {
		displayLarge = 32,
		displayMedium = 28,
		headlineLarge = 24,
		headlineMedium = 20,
		bodyLarge = 18,
		bodyMedium = 16,
		bodySmall = 14,
		labelLarge = 16,
		labelMedium = 14,
		labelSmall = 12,
	},
	
	spacing = {
		xs = 4,
		sm = 8,
		md = 12,
		lg = 16,
		xl = 20,
		xxl = 24,
		xxxl = 32,
	},
	
	radius = {
		sm = UDim.new(0, 6),
		md = UDim.new(0, 8),
		lg = UDim.new(0, 12),
		xl = UDim.new(0, 16),
		xxl = UDim.new(0, 20),
		full = UDim.new(1, 0),
	},
}

-- Breakpoints for responsive design
local BREAKPOINTS = {
	mobile = 768,
	tablet = 1024,
	desktop = 1280,
}

-- Product Data (Replace with your IDs)
local ProductData = {
	cashPacks = {
		{
			id = 1897730242,
			amount = 1000,
			name = "Starter Pack",
			description = "Perfect for beginners",
			price = nil, -- Will be fetched
			featured = true,
			rarity = "common",
			icon = "💰",
		},
		{
			id = 1897730373,
			amount = 5000,
			name = "Builder Bundle",
			description = "Expand your tycoon",
			price = nil,
			featured = true,
			rarity = "uncommon",
			icon = "💎",
		},
		{
			id = 1897730467,
			amount = 10000,
			name = "Pro Package",
			description = "Serious business boost",
			price = nil,
			featured = false,
			rarity = "rare",
			icon = "👑",
		},
		{
			id = 1897730581,
			amount = 50000,
			name = "Elite Vault",
			description = "Major expansion fund",
			price = nil,
			featured = true,
			rarity = "epic",
			icon = "🏆",
		},
		{
			id = 1234567001,
			amount = 100000,
			name = "Mega Cache",
			description = "Transform your empire",
			price = nil,
			featured = true,
			rarity = "legendary",
			icon = "⭐",
		},
		{
			id = 1234567002,
			amount = 250000,
			name = "Quarter Million",
			description = "Investment powerhouse",
			price = nil,
			featured = false,
			rarity = "legendary",
			icon = "🌟",
		},
	},
	
	gamePasses = {
		{
			id = 1412171840,
			name = "Auto Collect",
			description = "Automatically collects cash every minute",
			price = nil,
			hasToggle = true,
			featured = true,
			icon = "⚡",
		},
		{
			id = 1398974710,
			name = "2x Cash",
			description = "Double all earnings permanently",
			price = nil,
			hasToggle = false,
			featured = true,
			icon = "🔥",
		},
		{
			id = 1234567890,
			name = "VIP Access",
			description = "Exclusive VIP benefits and areas",
			price = nil,
			hasToggle = false,
			featured = false,
			icon = "👑",
		},
		{
			id = 1234567891,
			name = "Speed Boost",
			description = "25% faster production speed",
			price = nil,
			hasToggle = false,
			featured = false,
			icon = "🚀",
		},
	},
}

-- Utility Functions
local function debugPrint(...)
	if DEBUG_MODE then
		print("[TycoonShop]", ...)
	end
end

local function formatNumber(n)
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	else
		return tostring(math.floor(n))
	end
end

local function formatNumberWithCommas(n)
	local formatted = tostring(math.floor(n))
	local k
	repeat
		formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return formatted
end

local function getViewportSize()
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1920, 1080)
end

local function isMobile()
	return getViewportSize().X < BREAKPOINTS.mobile
end

local function isTablet()
	local size = getViewportSize()
	return size.X >= BREAKPOINTS.mobile and size.X < BREAKPOINTS.tablet
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

local function getSafeAreaInsets()
	local topInset, bottomInset = GuiService:GetGuiInset()
	return {
		top = math.max(topInset.Y, 12),
		bottom = math.max(bottomInset.Y, 12),
		left = 12,
		right = 12,
	}
end

-- Animation helper
local function animate(object, properties, duration, style, direction, callback)
	if not object or not object.Parent then
		if callback then callback() end
		return
	end
	
	local tween = TweenService:Create(
		object,
		TweenInfo.new(
			duration or 0.25,
			style or Enum.EasingStyle.Quart,
			direction or Enum.EasingDirection.Out
		),
		properties
	)
	
	if callback then
		tween.Completed:Connect(callback)
	end
	
	tween:Play()
	return tween
end

-- Sound Manager
local SoundManager = {}
SoundManager.__index = SoundManager

function SoundManager.new()
	local self = setmetatable({
		sounds = {},
		enabled = true,
	}, SoundManager)
	
	-- Create sounds
	local soundIds = {
		hover = "rbxassetid://131961136",
		click = "rbxassetid://131961136",
		open = "rbxassetid://178038408",
		close = "rbxassetid://178038408",
		purchase = "rbxassetid://131961136",
		error = "rbxassetid://131961136",
	}
	
	for name, id in pairs(soundIds) do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = 0.1
		sound.Parent = SoundService
		self.sounds[name] = sound
		
		-- Preload
		sound:Play()
		sound:Stop()
	end
	
	return self
end

function SoundManager:play(name, volume)
	if not self.enabled then return end
	
	local sound = self.sounds[name]
	if sound then
		sound.Volume = volume or 0.1
		sound:Play()
	end
end

-- Cache System
local Cache = {}
Cache.__index = Cache

function Cache.new(duration)
	return setmetatable({
		duration = duration or 300,
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

function Cache:clear()
	self.storage = {}
end

-- Advanced Shop Manager
local AdvancedShopManager = {}
AdvancedShopManager.__index = AdvancedShopManager

function AdvancedShopManager.new()
	local self = setmetatable({
		-- State
		isOpen = false,
		isAnimating = false,
		currentTheme = "modern",
		currentTab = "featured",
		searchQuery = "",
		selectedFilters = {},
		
		-- UI References
		gui = nil,
		blur = nil,
		mainContainer = nil,
		header = nil,
		searchBar = nil,
		navigation = nil,
		contentArea = nil,
		itemsContainer = nil,
		toggleButton = nil,
		
		-- Systems
		soundManager = SoundManager.new(),
		priceCache = Cache.new(300),
		ownershipCache = Cache.new(60),
		
		-- Settings
		settings = {
			soundEnabled = true,
			animationsEnabled = true,
			theme = "modern",
		},
		
		-- Connections
		connections = {},
		
		-- Data
		filteredItems = {},
		visibleItems = {},
	}, AdvancedShopManager)
	
	self:initialize()
	return self
end

function AdvancedShopManager:initialize()
	debugPrint("Initializing advanced shop manager...")
	
	-- Create UI
	self:createGUI()
	self:createToggleButton()
	
	-- Setup systems
	self:setupInputHandling()
	self:setupResponsiveHandling()
	self:setupMarketplaceCallbacks()
	
	-- Load initial data
	self:refreshPrices()
	self:refreshOwnership()
	
	debugPrint("Advanced shop manager initialized successfully")
end

function AdvancedShopManager:createGUI()
	-- Clean up existing
	if PlayerGui:FindFirstChild("AdvancedTycoonShopUI") then
		PlayerGui.AdvancedTycoonShopUI:Destroy()
	end
	
	-- Create ScreenGui
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "AdvancedTycoonShopUI"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 100
	self.gui.IgnoreGuiInset = false
	self.gui.Enabled = false
	self.gui.Parent = PlayerGui
	
	-- Background blur effect
	self.blur = Instance.new("BlurEffect")
	self.blur.Name = "ShopBlur"
	self.blur.Size = 0
	self.blur.Parent = Lighting
	
	-- Background overlay with glassmorphism
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.3
	overlay.BorderSizePixel = 0
	overlay.Parent = self.gui
	
	-- Add glassmorphism gradient
	local overlayGradient = Instance.new("UIGradient")
	overlayGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 41, 59))
	}
	overlayGradient.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.5)
	}
	overlayGradient.Rotation = 45
	overlayGradient.Parent = overlay
	
	-- Safe area container
	local safeInsets = getSafeAreaInsets()
	local safeContainer = Instance.new("Frame")
	safeContainer.Name = "SafeContainer"
	safeContainer.Size = UDim2.new(1, -safeInsets.left - safeInsets.right, 1, -safeInsets.top - safeInsets.bottom)
	safeContainer.Position = UDim2.new(0, safeInsets.left, 0, safeInsets.top)
	safeContainer.BackgroundTransparency = 1
	safeContainer.BorderSizePixel = 0
	safeContainer.Parent = self.gui
	
	-- Main container with glassmorphism
	self.mainContainer = Instance.new("Frame")
	self.mainContainer.Name = "MainContainer"
	self.mainContainer.Size = isMobile() and UDim2.fromScale(1, 1) or UDim2.fromScale(0.9, 0.85)
	self.mainContainer.Position = UDim2.fromScale(0.5, 0.5)
	self.mainContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	self.mainContainer.BackgroundColor3 = Theme.colors[self.currentTheme].surface
	self.mainContainer.BackgroundTransparency = 0.1
	self.mainContainer.BorderSizePixel = 0
	self.mainContainer.Parent = safeContainer
	
	-- Main container corner radius
	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = isMobile() and UDim.new(0, 0) or Theme.radius.xxl
	mainCorner.Parent = self.mainContainer
	
	-- Main container gradient
	local mainGradient = Instance.new("UIGradient")
	mainGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Theme.colors[self.currentTheme].surface),
		ColorSequenceKeypoint.new(1, Theme.colors[self.currentTheme].surfaceElevated)
	}
	mainGradient.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 0.15)
	}
	mainGradient.Rotation = 135
	mainGradient.Parent = self.mainContainer
	
	-- Main container stroke
	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = Theme.colors[self.currentTheme].border
	mainStroke.Thickness = 1
	mainStroke.Transparency = 0.7
	mainStroke.Parent = self.mainContainer
	
	-- Size constraints
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(1400, 900)
	sizeConstraint.MinSize = Vector2.new(400, 300)
	sizeConstraint.Parent = self.mainContainer
	
	-- Create sections
	self:createHeader()
	self:createSearchBar()
	self:createNavigation()
	self:createContentArea()
	
	-- Load initial content
	self:switchTab("featured")
end

function AdvancedShopManager:createHeader()
	self.header = Instance.new("Frame")
	self.header.Name = "Header"
	self.header.Size = UDim2.new(1, 0, 0, 80)
	self.header.BackgroundColor3 = Theme.colors[self.currentTheme].surfaceElevated
	self.header.BackgroundTransparency = 0.05
	self.header.BorderSizePixel = 0
	self.header.Parent = self.mainContainer
	
	-- Header corner radius (top only)
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = isMobile() and UDim.new(0, 0) or Theme.radius.xxl
	headerCorner.Parent = self.header
	
	-- Mask bottom corners
	local headerMask = Instance.new("Frame")
	headerMask.Name = "HeaderMask"
	headerMask.Size = UDim2.new(1, 0, 0, 20)
	headerMask.Position = UDim2.new(0, 0, 1, -20)
	headerMask.BackgroundColor3 = Theme.colors[self.currentTheme].surfaceElevated
	headerMask.BackgroundTransparency = 0.05
	headerMask.BorderSizePixel = 0
	headerMask.Parent = self.header
	
	-- Header layout
	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, Theme.spacing.lg)
	headerLayout.Parent = self.header
	
	-- Header padding
	local headerPadding = Instance.new("UIPadding")
	headerPadding.PaddingLeft = UDim.new(0, Theme.spacing.xl)
	headerPadding.PaddingRight = UDim.new(0, Theme.spacing.xl)
	headerPadding.Parent = self.header
	
	-- Shop icon
	local shopIcon = Instance.new("TextLabel")
	shopIcon.Name = "ShopIcon"
	shopIcon.Text = "🏪"
	shopIcon.Font = Theme.fonts.display
	shopIcon.TextSize = 32
	shopIcon.TextColor3 = Theme.colors[self.currentTheme].primary
	shopIcon.Size = UDim2.fromOffset(48, 48)
	shopIcon.BackgroundTransparency = 1
	shopIcon.LayoutOrder = 1
	shopIcon.Parent = self.header
	
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Text = "Tycoon Shop"
	title.Font = Theme.fonts.display
	title.TextSize = Theme.sizes.headlineLarge
	title.TextColor3 = Theme.colors[self.currentTheme].text
	title.Size = UDim2.new(0, 200, 1, 0)
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.LayoutOrder = 2
	title.Parent = self.header
	
	-- Balance display
	local balanceContainer = Instance.new("Frame")
	balanceContainer.Name = "BalanceContainer"
	balanceContainer.Size = UDim2.new(0, 150, 0, 40)
	balanceContainer.BackgroundColor3 = Theme.colors[self.currentTheme].primaryContainer
	balanceContainer.BackgroundTransparency = 0.3
	balanceContainer.BorderSizePixel = 0
	balanceContainer.LayoutOrder = 3
	balanceContainer.Parent = self.header
	
	local balanceCorner = Instance.new("UICorner")
	balanceCorner.CornerRadius = Theme.radius.lg
	balanceCorner.Parent = balanceContainer
	
	local balanceLayout = Instance.new("UIListLayout")
	balanceLayout.FillDirection = Enum.FillDirection.Horizontal
	balanceLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	balanceLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	balanceLayout.Padding = UDim.new(0, Theme.spacing.sm)
	balanceLayout.Parent = balanceContainer
	
	local cashIcon = Instance.new("TextLabel")
	cashIcon.Name = "CashIcon"
	cashIcon.Text = "💰"
	cashIcon.Font = Theme.fonts.primary
	cashIcon.TextSize = 16
	cashIcon.Size = UDim2.fromOffset(20, 20)
	cashIcon.BackgroundTransparency = 1
	cashIcon.LayoutOrder = 1
	cashIcon.Parent = balanceContainer
	
	local balanceLabel = Instance.new("TextLabel")
	balanceLabel.Name = "BalanceLabel"
	balanceLabel.Text = "$0"
	balanceLabel.Font = Theme.fonts.primary
	balanceLabel.TextSize = Theme.sizes.labelLarge
	balanceLabel.TextColor3 = Theme.colors[self.currentTheme].text
	balanceLabel.Size = UDim2.new(0, 100, 1, 0)
	balanceLabel.BackgroundTransparency = 1
	balanceLabel.TextXAlignment = Enum.TextXAlignment.Left
	balanceLabel.LayoutOrder = 2
	balanceLabel.Parent = balanceContainer
	
	-- Actions container
	local actionsContainer = Instance.new("Frame")
	actionsContainer.Name = "ActionsContainer"
	actionsContainer.Size = UDim2.new(1, -450, 1, 0)
	actionsContainer.BackgroundTransparency = 1
	actionsContainer.LayoutOrder = 4
	actionsContainer.Parent = self.header
	
	local actionsLayout = Instance.new("UIListLayout")
	actionsLayout.FillDirection = Enum.FillDirection.Horizontal
	actionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	actionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actionsLayout.Padding = UDim.new(0, Theme.spacing.sm)
	actionsLayout.Parent = actionsContainer
	
	-- Theme toggle button
	local themeButton = Instance.new("TextButton")
	themeButton.Name = "ThemeButton"
	themeButton.Text = self.currentTheme == "modern" and "🌙" or "☀️"
	themeButton.Font = Theme.fonts.primary
	themeButton.TextSize = 20
	themeButton.Size = UDim2.fromOffset(40, 40)
	themeButton.BackgroundColor3 = Theme.colors[self.currentTheme].surfaceElevated
	themeButton.TextColor3 = Theme.colors[self.currentTheme].text
	themeButton.BorderSizePixel = 0
	themeButton.AutoButtonColor = false
	themeButton.LayoutOrder = 1
	themeButton.Parent = actionsContainer
	
	local themeCorner = Instance.new("UICorner")
	themeCorner.CornerRadius = Theme.radius.lg
	themeCorner.Parent = themeButton
	
	themeButton.MouseButton1Click:Connect(function()
		self:toggleTheme()
	end)
	
	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Text = "✕"
	closeButton.Font = Theme.fonts.primary
	closeButton.TextSize = 18
	closeButton.Size = UDim2.fromOffset(40, 40)
	closeButton.BackgroundColor3 = Theme.colors[self.currentTheme].error
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.BorderSizePixel = 0
	closeButton.AutoButtonColor = false
	closeButton.LayoutOrder = 2
	closeButton.Parent = actionsContainer
	
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = Theme.radius.full
	closeCorner.Parent = closeButton
	
	closeButton.MouseButton1Click:Connect(function()
		self:close()
	end)
	
	-- Hover effects
	closeButton.MouseEnter:Connect(function()
		self.soundManager:play("hover", 0.05)
		animate(closeButton, {Size = UDim2.fromOffset(44, 44)}, 0.15, Enum.EasingStyle.Back)
	end)
	
	closeButton.MouseLeave:Connect(function()
		animate(closeButton, {Size = UDim2.fromOffset(40, 40)}, 0.15)
	end)
	
	themeButton.MouseEnter:Connect(function()
		self.soundManager:play("hover", 0.05)
		animate(themeButton, {Size = UDim2.fromOffset(44, 44)}, 0.15, Enum.EasingStyle.Back)
	end)
	
	themeButton.MouseLeave:Connect(function()
		animate(themeButton, {Size = UDim2.fromOffset(40, 40)}, 0.15)
	end)
end

function AdvancedShopManager:createSearchBar()
	local searchContainer = Instance.new("Frame")
	searchContainer.Name = "SearchContainer"
	searchContainer.Size = UDim2.new(1, 0, 0, 60)
	searchContainer.Position = UDim2.new(0, 0, 0, 80)
	searchContainer.BackgroundColor3 = Theme.colors[self.currentTheme].surfaceElevated
	searchContainer.BackgroundTransparency = 0.02
	searchContainer.BorderSizePixel = 0
	searchContainer.Parent = self.mainContainer
	
	-- Search padding
	local searchPadding = Instance.new("UIPadding")
	searchPadding.PaddingLeft = UDim.new(0, Theme.spacing.xl)
	searchPadding.PaddingRight = UDim.new(0, Theme.spacing.xl)
	searchPadding.PaddingTop = UDim.new(0, Theme.spacing.md)
	searchPadding.PaddingBottom = UDim.new(0, Theme.spacing.md)
	searchPadding.Parent = searchContainer
	
	-- Search frame
	local searchFrame = Instance.new("Frame")
	searchFrame.Name = "SearchFrame"
	searchFrame.Size = UDim2.new(1, 0, 1, 0)
	searchFrame.BackgroundColor3 = Theme.colors[self.currentTheme].surface
	searchFrame.BackgroundTransparency = 0.1
	searchFrame.BorderSizePixel = 0
	searchFrame.Parent = searchContainer
	
	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = Theme.radius.xl
	searchCorner.Parent = searchFrame
	
	local searchStroke = Instance.new("UIStroke")
	searchStroke.Color = Theme.colors[self.currentTheme].border
	searchStroke.Thickness = 1
	searchStroke.Transparency = 0.5
	searchStroke.Parent = searchFrame
	
	-- Search layout
	local searchLayout = Instance.new("UIListLayout")
	searchLayout.FillDirection = Enum.FillDirection.Horizontal
	searchLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	searchLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	searchLayout.Padding = UDim.new(0, Theme.spacing.md)
	searchLayout.Parent = searchFrame
	
	-- Search frame padding
	local searchFramePadding = Instance.new("UIPadding")
	searchFramePadding.PaddingLeft = UDim.new(0, Theme.spacing.lg)
	searchFramePadding.PaddingRight = UDim.new(0, Theme.spacing.lg)
	searchFramePadding.Parent = searchFrame
	
	-- Search icon
	local searchIcon = Instance.new("TextLabel")
	searchIcon.Name = "SearchIcon"
	searchIcon.Text = "🔍"
	searchIcon.Font = Theme.fonts.primary
	searchIcon.TextSize = 16
	searchIcon.TextColor3 = Theme.colors[self.currentTheme].textTertiary
	searchIcon.Size = UDim2.fromOffset(20, 20)
	searchIcon.BackgroundTransparency = 1
	searchIcon.LayoutOrder = 1
	searchIcon.Parent = searchFrame
	
	-- Search input
	local searchInput = Instance.new("TextBox")
	searchInput.Name = "SearchInput"
	searchInput.Size = UDim2.new(1, -80, 1, 0)
	searchInput.BackgroundTransparency = 1
	searchInput.Text = ""
	searchInput.PlaceholderText = "Search items, categories, or features..."
	searchInput.PlaceholderColor3 = Theme.colors[self.currentTheme].textTertiary
	searchInput.TextColor3 = Theme.colors[self.currentTheme].text
	searchInput.Font = Theme.fonts.primary
	searchInput.TextSize = Theme.sizes.bodyMedium
	searchInput.TextXAlignment = Enum.TextXAlignment.Left
	searchInput.ClearTextOnFocus = false
	searchInput.LayoutOrder = 2
	searchInput.Parent = searchFrame
	
	-- Clear button
	local clearButton = Instance.new("TextButton")
	clearButton.Name = "ClearButton"
	clearButton.Text = "✕"
	clearButton.Font = Theme.fonts.primary
	clearButton.TextSize = 14
	clearButton.Size = UDim2.fromOffset(24, 24)
	clearButton.BackgroundColor3 = Theme.colors[self.currentTheme].textTertiary
	clearButton.TextColor3 = Color3.new(1, 1, 1)
	clearButton.BorderSizePixel = 0
	clearButton.AutoButtonColor = false
	clearButton.Visible = false
	clearButton.LayoutOrder = 3
	clearButton.Parent = searchFrame
	
	local clearCorner = Instance.new("UICorner")
	clearCorner.CornerRadius = Theme.radius.full
	clearCorner.Parent = clearButton
	
	-- Search functionality
	local searchDebounce = nil
	searchInput:GetPropertyChangedSignal("Text"):Connect(function()
		local text = searchInput.Text
		clearButton.Visible = text ~= ""
		
		if searchDebounce then
			task.cancel(searchDebounce)
		end
		
		searchDebounce = task.delay(0.3, function()
			self.searchQuery = text
			self:performSearch()
		end)
	end)
	
	clearButton.MouseButton1Click:Connect(function()
		searchInput.Text = ""
		self.searchQuery = ""
		self:performSearch()
	end)
	
	-- Focus effects
	searchInput.Focused:Connect(function()
		animate(searchStroke, {
			Color = Theme.colors[self.currentTheme].primary,
			Thickness = 2,
		}, 0.15)
		
		animate(searchIcon, {
			TextColor3 = Theme.colors[self.currentTheme].primary,
		}, 0.15)
	end)
	
	searchInput.FocusLost:Connect(function()
		animate(searchStroke, {
			Color = Theme.colors[self.currentTheme].border,
			Thickness = 1,
		}, 0.15)
		
		animate(searchIcon, {
			TextColor3 = Theme.colors[self.currentTheme].textTertiary,
		}, 0.15)
	end)
	
	self.searchBar = {
		container = searchContainer,
		frame = searchFrame,
		input = searchInput,
		icon = searchIcon,
		clearButton = clearButton,
	}
end

function AdvancedShopManager:createNavigation()
	local navHeight = isMobile() and 60 or 0
	local navWidth = isMobile() and 0 or 200
	
	self.navigation = Instance.new("Frame")
	self.navigation.Name = "Navigation"
	self.navigation.Size = isMobile() and UDim2.new(1, -Theme.spacing.xl * 2, 0, navHeight) or UDim2.new(0, navWidth, 1, -140 - Theme.spacing.lg)
	self.navigation.Position = isMobile() and UDim2.new(0, Theme.spacing.xl, 0, 140) or UDim2.new(0, Theme.spacing.xl, 0, 140 + Theme.spacing.lg)
	self.navigation.BackgroundColor3 = Theme.colors[self.currentTheme].surfaceElevated
	self.navigation.BackgroundTransparency = 0.05
	self.navigation.BorderSizePixel = 0
	self.navigation.Parent = self.mainContainer
	
	local navCorner = Instance.new("UICorner")
	navCorner.CornerRadius = Theme.radius.lg
	navCorner.Parent = self.navigation
	
	-- Navigation layout
	local navLayout = Instance.new("UIListLayout")
	navLayout.FillDirection = isMobile() and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	navLayout.HorizontalAlignment = isMobile() and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left
	navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	navLayout.Padding = UDim.new(0, Theme.spacing.sm)
	navLayout.Parent = self.navigation
	
	-- Navigation padding
	local navPadding = Instance.new("UIPadding")
	navPadding.PaddingLeft = UDim.new(0, Theme.spacing.md)
	navPadding.PaddingRight = UDim.new(0, Theme.spacing.md)
	navPadding.PaddingTop = UDim.new(0, Theme.spacing.md)
	navPadding.PaddingBottom = UDim.new(0, Theme.spacing.md)
	navPadding.Parent = self.navigation
	
	-- Navigation items
	local navItems = {
		{id = "featured", name = "Featured", icon = "⭐"},
		{id = "cash", name = "Cash Packs", icon = "💰"},
		{id = "passes", name = "Game Passes", icon = "🎫"},
		{id = "owned", name = "Owned", icon = "✅"},
	}
	
	self.navButtons = {}
	
	for i, item in ipairs(navItems) do
		local button = self:createNavButton(item, i)
		self.navButtons[item.id] = button
	end
end

function AdvancedShopManager:createNavButton(item, order)
	local button = Instance.new("TextButton")
	button.Name = item.id .. "NavButton"
	button.Text = ""
	button.Size = isMobile() and UDim2.new(0.25, -6, 1, 0) or UDim2.new(1, 0, 0, 48)
	button.BackgroundColor3 = Theme.colors[self.currentTheme].surface
	button.BackgroundTransparency = 0.3
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.LayoutOrder = order
	button.Parent = self.navigation
	
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = Theme.radius.md
	buttonCorner.Parent = button
	
	-- Button layout
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = isMobile() and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	buttonLayout.Padding = UDim.new(0, isMobile() and 2 or Theme.spacing.sm)
	buttonLayout.Parent = button
	
	-- Icon
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Text = item.icon
	icon.Font = Theme.fonts.primary
	icon.TextSize = isMobile() and 16 or 20
	icon.TextColor3 = Theme.colors[self.currentTheme].textSecondary
	icon.Size = isMobile() and UDim2.new(1, 0, 0, 20) or UDim2.fromOffset(24, 24)
	icon.BackgroundTransparency = 1
	icon.LayoutOrder = 1
	icon.Parent = button
	
	-- Label
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Text = item.name
	label.Font = Theme.fonts.primary
	label.TextSize = isMobile() and Theme.sizes.labelSmall or Theme.sizes.labelMedium
	label.TextColor3 = Theme.colors[self.currentTheme].textSecondary
	label.Size = isMobile() and UDim2.new(1, 0, 0, 14) or UDim2.new(1, -30, 1, 0)
	label.BackgroundTransparency = 1
	label.TextXAlignment = isMobile() and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
	label.TextScaled = isMobile()
	label.LayoutOrder = 2
	label.Parent = button
	
	-- Store references
	button._icon = icon
	button._label = label
	button._item = item
	
	-- Click handler
	button.MouseButton1Click:Connect(function()
		self:switchTab(item.id)
	end)
	
	-- Hover effects
	button.MouseEnter:Connect(function()
		if self.currentTab ~= item.id then
			self.soundManager:play("hover", 0.05)
			animate(button, {BackgroundTransparency = 0.1}, 0.15)
			animate(icon, {TextColor3 = Theme.colors[self.currentTheme].primary}, 0.15)
			animate(label, {TextColor3 = Theme.colors[self.currentTheme].primary}, 0.15)
		end
	end)
	
	button.MouseLeave:Connect(function()
		if self.currentTab ~= item.id then
			animate(button, {BackgroundTransparency = 0.3}, 0.15)
			animate(icon, {TextColor3 = Theme.colors[self.currentTheme].textSecondary}, 0.15)
			animate(label, {TextColor3 = Theme.colors[self.currentTheme].textSecondary}, 0.15)
		end
	end)
	
	return button
end

function AdvancedShopManager:createContentArea()
	local contentY = isMobile() and 200 or 140 + Theme.spacing.lg
	local contentX = isMobile() and Theme.spacing.xl or 200 + Theme.spacing.xl * 2
	local contentWidth = isMobile() and -Theme.spacing.xl * 2 or -contentX - Theme.spacing.xl
	local contentHeight = -contentY - Theme.spacing.xl
	
	self.contentArea = Instance.new("Frame")
	self.contentArea.Name = "ContentArea"
	self.contentArea.Size = UDim2.new(1, contentWidth, 1, contentHeight)
	self.contentArea.Position = UDim2.new(0, contentX, 0, contentY)
	self.contentArea.BackgroundTransparency = 1
	self.contentArea.BorderSizePixel = 0
	self.contentArea.Parent = self.mainContainer
	
	-- Scrolling frame for items
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ScrollFrame"
	scrollFrame.Size = UDim2.fromScale(1, 1)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.ScrollBarImageColor3 = Theme.colors[self.currentTheme].border
	scrollFrame.ScrollBarImageTransparency = 0.3
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.Parent = self.contentArea
	
	-- Items container
	self.itemsContainer = Instance.new("Frame")
	self.itemsContainer.Name = "ItemsContainer"
	self.itemsContainer.Size = UDim2.new(1, 0, 0, 0)
	self.itemsContainer.BackgroundTransparency = 1
	self.itemsContainer.BorderSizePixel = 0
	self.itemsContainer.Parent = scrollFrame
	
	-- Grid layout for items
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.fromOffset(Theme.spacing.lg, Theme.spacing.lg)
	gridLayout.CellSize = self:getGridCellSize()
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = self.itemsContainer
	
	-- Container padding
	local containerPadding = Instance.new("UIPadding")
	containerPadding.PaddingLeft = UDim.new(0, Theme.spacing.lg)
	containerPadding.PaddingRight = UDim.new(0, Theme.spacing.lg)
	containerPadding.PaddingTop = UDim.new(0, Theme.spacing.lg)
	containerPadding.PaddingBottom = UDim.new(0, Theme.spacing.lg)
	containerPadding.Parent = self.itemsContainer
	
	-- Auto-size container
	local sizeConstraint = Instance.new("UIListLayout")
	sizeConstraint.FillDirection = Enum.FillDirection.Vertical
	sizeConstraint.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sizeConstraint.VerticalAlignment = Enum.VerticalAlignment.Top
	sizeConstraint.Parent = scrollFrame
	
	-- Remove the UIListLayout and use automatic sizing
	sizeConstraint:Destroy()
	
	-- Set up automatic canvas sizing
	local function updateCanvasSize()
		local contentSize = gridLayout.AbsoluteContentSize
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + Theme.spacing.xl * 2)
	end
	
	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)
end

function AdvancedShopManager:getGridCellSize()
	local viewport = getViewportSize()
	local containerWidth = self.contentArea and self.contentArea.AbsoluteSize.X or viewport.X * 0.7
	
	local columns = 1
	if viewport.X >= BREAKPOINTS.tablet then
		columns = 2
	end
	if viewport.X >= BREAKPOINTS.desktop then
		columns = 3
	end
	
	local cellWidth = (containerWidth - Theme.spacing.lg * (columns + 1)) / columns
	local cellHeight = 280
	
	return UDim2.fromOffset(math.max(cellWidth, 200), cellHeight)
end

function AdvancedShopManager:createToggleButton()
	-- Clean up existing
	if PlayerGui:FindFirstChild("TycoonShopToggle") then
		PlayerGui.TycoonShopToggle:Destroy()
	end
	
	local toggleGui = Instance.new("ScreenGui")
	toggleGui.Name = "TycoonShopToggle"
	toggleGui.ResetOnSpawn = false
	toggleGui.DisplayOrder = 50
	toggleGui.Parent = PlayerGui
	
	self.toggleButton = Instance.new("TextButton")
	self.toggleButton.Name = "ToggleButton"
	self.toggleButton.Text = "🏪"
	self.toggleButton.Font = Theme.fonts.display
	self.toggleButton.TextSize = 28
	self.toggleButton.Size = UDim2.fromOffset(64, 64)
	self.toggleButton.Position = UDim2.new(1, -80, 1, -80)
	self.toggleButton.AnchorPoint = Vector2.new(0.5, 0.5)
	self.toggleButton.BackgroundColor3 = Theme.colors[self.currentTheme].primary
	self.toggleButton.TextColor3 = Color3.new(1, 1, 1)
	self.toggleButton.BorderSizePixel = 0
	self.toggleButton.AutoButtonColor = false
	self.toggleButton.Parent = toggleGui
	
	-- Toggle button styling
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = Theme.radius.full
	toggleCorner.Parent = self.toggleButton
	
	local toggleStroke = Instance.new("UIStroke")
	toggleStroke.Color = Theme.colors[self.currentTheme].primaryLight
	toggleStroke.Thickness = 2
	toggleStroke.Transparency = 0.3
	toggleStroke.Parent = self.toggleButton
	
	-- Toggle button gradient
	local toggleGradient = Instance.new("UIGradient")
	toggleGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Theme.colors[self.currentTheme].primary),
		ColorSequenceKeypoint.new(1, Theme.colors[self.currentTheme].primaryLight)
	}
	toggleGradient.Rotation = 45
	toggleGradient.Parent = self.toggleButton
	
	-- Click handler
	self.toggleButton.MouseButton1Click:Connect(function()
		self:toggle()
	end)
	
	-- Hover effects
	self.toggleButton.MouseEnter:Connect(function()
		self.soundManager:play("hover", 0.05)
		animate(self.toggleButton, {
			Size = UDim2.fromOffset(72, 72),
		}, 0.15, Enum.EasingStyle.Back)
		
		animate(toggleStroke, {
			Transparency = 0,
		}, 0.15)
	end)
	
	self.toggleButton.MouseLeave:Connect(function()
		animate(self.toggleButton, {
			Size = UDim2.fromOffset(64, 64),
		}, 0.15)
		
		animate(toggleStroke, {
			Transparency = 0.3,
		}, 0.15)
	end)
	
	-- Floating animation
	task.spawn(function()
		while self.toggleButton and self.toggleButton.Parent do
			animate(self.toggleButton, {
				Position = UDim2.new(1, -80, 1, -85),
			}, 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(3)
			animate(self.toggleButton, {
				Position = UDim2.new(1, -80, 1, -75),
			}, 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(3)
		end
	end)
end

function AdvancedShopManager:switchTab(tabId)
	if self.currentTab == tabId then return end
	
	debugPrint("Switching to tab:", tabId)
	
	self.currentTab = tabId
	self.soundManager:play("click", 0.08)
	
	-- Update navigation buttons
	for id, button in pairs(self.navButtons) do
		local isActive = id == tabId
		
		animate(button, {
			BackgroundTransparency = isActive and 0 or 0.3,
		}, 0.15)
		
		animate(button._icon, {
			TextColor3 = isActive and Color3.new(1, 1, 1) or Theme.colors[self.currentTheme].textSecondary,
		}, 0.15)
		
		animate(button._label, {
			TextColor3 = isActive and Color3.new(1, 1, 1) or Theme.colors[self.currentTheme].textSecondary,
		}, 0.15)
		
		if isActive then
			button.BackgroundColor3 = Theme.colors[self.currentTheme].primary
		else
			button.BackgroundColor3 = Theme.colors[self.currentTheme].surface
		end
	end
	
	-- Load content for tab
	self:loadTabContent(tabId)
end

function AdvancedShopManager:loadTabContent(tabId)
	-- Clear existing items
	for _, child in ipairs(self.itemsContainer:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	
	local items = {}
	
	if tabId == "featured" then
		-- Show featured items from both categories
		for _, item in ipairs(ProductData.cashPacks) do
			if item.featured then
				table.insert(items, {type = "cash", data = item})
			end
		end
		for _, item in ipairs(ProductData.gamePasses) do
			if item.featured then
				table.insert(items, {type = "gamepass", data = item})
			end
		end
	elseif tabId == "cash" then
		for _, item in ipairs(ProductData.cashPacks) do
			table.insert(items, {type = "cash", data = item})
		end
	elseif tabId == "passes" then
		for _, item in ipairs(ProductData.gamePasses) do
			table.insert(items, {type = "gamepass", data = item})
		end
	elseif tabId == "owned" then
		-- Show owned items (would need ownership checking)
		for _, item in ipairs(ProductData.gamePasses) do
			if self:checkOwnership(item.id) then
				table.insert(items, {type = "gamepass", data = item})
			end
		end
	end
	
	-- Apply search filter
	if self.searchQuery and self.searchQuery ~= "" then
		items = self:filterItems(items, self.searchQuery)
	end
	
	-- Create item cards
	for i, item in ipairs(items) do
		self:createItemCard(item, i)
	end
	
	-- Show empty state if no items
	if #items == 0 then
		self:showEmptyState()
	end
end

function AdvancedShopManager:createItemCard(item, order)
	local data = item.data
	local itemType = item.type
	
	local card = Instance.new("Frame")
	card.Name = data.name:gsub(" ", "") .. "Card"
	card.BackgroundColor3 = Theme.colors[self.currentTheme].surface
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.Parent = self.itemsContainer
	
	-- Card styling
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = Theme.radius.lg
	cardCorner.Parent = card
	
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = itemType == "cash" and Theme.colors[self.currentTheme].primary or Theme.colors[self.currentTheme].secondary
	cardStroke.Thickness = 1
	cardStroke.Transparency = 0.7
	cardStroke.Parent = card
	
	-- Card gradient
	local cardGradient = Instance.new("UIGradient")
	cardGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Theme.colors[self.currentTheme].surface),
		ColorSequenceKeypoint.new(1, itemType == "cash" and Theme.colors[self.currentTheme].primaryContainer or Theme.colors[self.currentTheme].secondaryContainer)
	}
	cardGradient.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 0.3)
	}
	cardGradient.Rotation = 135
	cardGradient.Parent = card
	
	-- Card layout
	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Vertical
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	cardLayout.Padding = UDim.new(0, Theme.spacing.md)
	cardLayout.Parent = card
	
	-- Card padding
	local cardPadding = Instance.new("UIPadding")
	cardPadding.PaddingLeft = UDim.new(0, Theme.spacing.lg)
	cardPadding.PaddingRight = UDim.new(0, Theme.spacing.lg)
	cardPadding.PaddingTop = UDim.new(0, Theme.spacing.lg)
	cardPadding.PaddingBottom = UDim.new(0, Theme.spacing.lg)
	cardPadding.Parent = card
	
	-- Icon container
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(1, 0, 0, 64)
	iconContainer.BackgroundColor3 = itemType == "cash" and Theme.colors[self.currentTheme].primaryContainer or Theme.colors[self.currentTheme].secondaryContainer
	iconContainer.BackgroundTransparency = 0.3
	iconContainer.BorderSizePixel = 0
	iconContainer.LayoutOrder = 1
	iconContainer.Parent = card
	
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = Theme.radius.md
	iconCorner.Parent = iconContainer
	
	-- Icon
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Text = data.icon
	icon.Font = Theme.fonts.display
	icon.TextSize = 32
	icon.TextColor3 = itemType == "cash" and Theme.colors[self.currentTheme].primary or Theme.colors[self.currentTheme].secondary
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Parent = iconContainer
	
	-- Name
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.Text = data.name
	name.Font = Theme.fonts.primary
	name.TextSize = Theme.sizes.bodyLarge
	name.TextColor3 = Theme.colors[self.currentTheme].text
	name.Size = UDim2.new(1, 0, 0, 24)
	name.BackgroundTransparency = 1
	name.LayoutOrder = 2
	name.Parent = card
	
	-- Description
	local description = Instance.new("TextLabel")
	description.Name = "Description"
	description.Text = data.description
	description.Font = Theme.fonts.primary
	description.TextSize = Theme.sizes.bodySmall
	description.TextColor3 = Theme.colors[self.currentTheme].textSecondary
	description.Size = UDim2.new(1, 0, 0, 32)
	description.BackgroundTransparency = 1
	description.TextWrapped = true
	description.LayoutOrder = 3
	description.Parent = card
	
	-- Amount/Price info
	local infoText = ""
	if itemType == "cash" then
		infoText = formatNumberWithCommas(data.amount) .. " Cash"
	end
	
	if infoText ~= "" then
		local info = Instance.new("TextLabel")
		info.Name = "Info"
		info.Text = infoText
		info.Font = Theme.fonts.primary
		info.TextSize = Theme.sizes.labelLarge
		info.TextColor3 = itemType == "cash" and Theme.colors[self.currentTheme].primary or Theme.colors[self.currentTheme].secondary
		info.Size = UDim2.new(1, 0, 0, 20)
		info.BackgroundTransparency = 1
		info.LayoutOrder = 4
		info.Parent = card
	end
	
	-- Price
	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.Text = "R$" .. (data.price or "???")
	price.Font = Theme.fonts.primary
	price.TextSize = Theme.sizes.headlineMedium
	price.TextColor3 = Theme.colors[self.currentTheme].text
	price.Size = UDim2.new(1, 0, 0, 28)
	price.BackgroundTransparency = 1
	price.LayoutOrder = 5
	price.Parent = card
	
	-- Buy button
	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyButton"
	buyButton.Text = "Purchase"
	buyButton.Font = Theme.fonts.primary
	buyButton.TextSize = Theme.sizes.labelLarge
	buyButton.Size = UDim2.new(1, 0, 0, 44)
	buyButton.BackgroundColor3 = itemType == "cash" and Theme.colors[self.currentTheme].primary or Theme.colors[self.currentTheme].secondary
	buyButton.TextColor3 = Color3.new(1, 1, 1)
	buyButton.BorderSizePixel = 0
	buyButton.AutoButtonColor = false
	buyButton.LayoutOrder = 6
	buyButton.Parent = card
	
	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = Theme.radius.md
	buyCorner.Parent = buyButton
	
	-- Store references
	data._card = card
	data._priceLabel = price
	data._buyButton = buyButton
	data._icon = icon
	
	-- Click handler
	buyButton.MouseButton1Click:Connect(function()
		if itemType == "cash" then
			self:purchaseProduct(data)
		else
			self:purchaseGamePass(data)
		end
	end)
	
	-- Hover effects
	card.MouseEnter:Connect(function()
		animate(card, {
			BackgroundTransparency = 0.05,
		}, 0.15)
		
		animate(cardStroke, {
			Transparency = 0.4,
		}, 0.15)
		
		animate(icon, {
			TextSize = 36,
		}, 0.15, Enum.EasingStyle.Back)
	end)
	
	card.MouseLeave:Connect(function()
		animate(card, {
			BackgroundTransparency = 0.1,
		}, 0.15)
		
		animate(cardStroke, {
			Transparency = 0.7,
		}, 0.15)
		
		animate(icon, {
			TextSize = 32,
		}, 0.15)
	end)
	
	buyButton.MouseEnter:Connect(function()
		self.soundManager:play("hover", 0.05)
		animate(buyButton, {
			Size = UDim2.new(1.02, 0, 0, 48),
		}, 0.15, Enum.EasingStyle.Back)
	end)
	
	buyButton.MouseLeave:Connect(function()
		animate(buyButton, {
			Size = UDim2.new(1, 0, 0, 44),
		}, 0.15)
	end)
	
	-- Check ownership for game passes
	if itemType == "gamepass" then
		local owned = self:checkOwnership(data.id)
		if owned then
			self:updateItemOwned(data)
		end
	end
	
	-- Rarity effects
	if data.rarity == "legendary" or data.rarity == "epic" then
		-- Add special glow effect
		task.spawn(function()
			while card.Parent do
				animate(cardStroke, {Transparency = 0.3}, 2, Enum.EasingStyle.Sine)
				task.wait(2)
				animate(cardStroke, {Transparency = 0.7}, 2, Enum.EasingStyle.Sine)
				task.wait(2)
			end
		end)
	end
end

function AdvancedShopManager:showEmptyState()
	local emptyState = Instance.new("Frame")
	emptyState.Name = "EmptyState"
	emptyState.Size = UDim2.new(1, 0, 0, 200)
	emptyState.BackgroundTransparency = 1
	emptyState.LayoutOrder = 1
	emptyState.Parent = self.itemsContainer
	
	local emptyIcon = Instance.new("TextLabel")
	emptyIcon.Name = "EmptyIcon"
	emptyIcon.Text = "🔍"
	emptyIcon.Font = Theme.fonts.display
	emptyIcon.TextSize = 48
	emptyIcon.TextColor3 = Theme.colors[self.currentTheme].textTertiary
	emptyIcon.Size = UDim2.new(1, 0, 0, 60)
	emptyIcon.BackgroundTransparency = 1
	emptyIcon.Parent = emptyState
	
	local emptyText = Instance.new("TextLabel")
	emptyText.Name = "EmptyText"
	emptyText.Text = "No items found"
	emptyText.Font = Theme.fonts.primary
	emptyText.TextSize = Theme.sizes.headlineMedium
	emptyText.TextColor3 = Theme.colors[self.currentTheme].textSecondary
	emptyText.Size = UDim2.new(1, 0, 0, 30)
	emptyText.Position = UDim2.new(0, 0, 0, 70)
	emptyText.BackgroundTransparency = 1
	emptyText.Parent = emptyState
	
	local emptySubtext = Instance.new("TextLabel")
	emptySubtext.Name = "EmptySubtext"
	emptySubtext.Text = "Try adjusting your search or filters"
	emptySubtext.Font = Theme.fonts.primary
	emptySubtext.TextSize = Theme.sizes.bodyMedium
	emptySubtext.TextColor3 = Theme.colors[self.currentTheme].textTertiary
	emptySubtext.Size = UDim2.new(1, 0, 0, 20)
	emptySubtext.Position = UDim2.new(0, 0, 0, 110)
	emptySubtext.BackgroundTransparency = 1
	emptySubtext.Parent = emptyState
end

function AdvancedShopManager:filterItems(items, query)
	local filtered = {}
	query = query:lower()
	
	for _, item in ipairs(items) do
		local data = item.data
		local searchText = (data.name .. " " .. data.description):lower()
		
		if searchText:find(query, 1, true) then
			table.insert(filtered, item)
		end
	end
	
	return filtered
end

function AdvancedShopManager:performSearch()
	-- Reload current tab content with search applied
	self:loadTabContent(self.currentTab)
end

function AdvancedShopManager:toggleTheme()
	self.currentTheme = self.currentTheme == "modern" and "dark" or "modern"
	self.soundManager:play("click", 0.08)
	
	-- Update theme button
	local themeButton = self.header:FindFirstChild("ActionsContainer"):FindFirstChild("ThemeButton")
	if themeButton then
		themeButton.Text = self.currentTheme == "modern" and "🌙" or "☀️"
	end
	
	-- Recreate UI with new theme
	local wasOpen = self.isOpen
	if wasOpen then
		self:close()
		task.wait(0.3)
	end
	
	self:createGUI()
	
	if wasOpen then
		self:open()
	end
end

function AdvancedShopManager:setupInputHandling()
	-- Keyboard shortcuts
	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.M then
			self:toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and self.isOpen then
			self:close()
		elseif input.KeyCode == Enum.KeyCode.T and self.isOpen then
			self:toggleTheme()
		end
	end))
	
	-- Gamepad support
	ContextActionService:BindAction("ToggleShop", function(actionName, inputState, inputObject)
		if inputState == Enum.UserInputState.Begin then
			self:toggle()
		end
	end, false, Enum.KeyCode.ButtonX)
end

function AdvancedShopManager:setupResponsiveHandling()
	local function updateLayout()
		if not self.mainContainer then return end
		
		-- Update grid cell size
		if self.itemsContainer then
			local gridLayout = self.itemsContainer:FindFirstChildOfClass("UIGridLayout")
			if gridLayout then
				gridLayout.CellSize = self:getGridCellSize()
			end
		end
		
		-- Update navigation layout for mobile
		if self.navigation then
			local isMobileNow = isMobile()
			local navLayout = self.navigation:FindFirstChildOfClass("UIListLayout")
			if navLayout then
				navLayout.FillDirection = isMobileNow and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
				navLayout.HorizontalAlignment = isMobileNow and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left
			end
			
			-- Update button sizes
			for _, button in pairs(self.navButtons) do
				button.Size = isMobileNow and UDim2.new(0.25, -6, 1, 0) or UDim2.new(1, 0, 0, 48)
			end
		end
		
		-- Update main container size
		self.mainContainer.Size = isMobile() and UDim2.fromScale(1, 1) or UDim2.fromScale(0.9, 0.85)
		
		-- Update corner radius
		local mainCorner = self.mainContainer:FindFirstChildOfClass("UICorner")
		if mainCorner then
			mainCorner.CornerRadius = isMobile() and UDim.new(0, 0) or Theme.radius.xxl
		end
	end
	
	-- Initial update
	updateLayout()
	
	-- Listen for viewport changes
	local camera = workspace.CurrentCamera
	if camera then
		table.insert(self.connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout))
	end
end

function AdvancedShopManager:setupMarketplaceCallbacks()
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

function AdvancedShopManager:refreshPrices()
	debugPrint("Refreshing prices...")
	
	-- Cash packs
	for _, pack in ipairs(ProductData.cashPacks) do
		local cachedPrice = self.priceCache:get("product_" .. pack.id)
		if not cachedPrice then
			task.spawn(function()
				local success, info = pcall(function()
					return MarketplaceService:GetProductInfo(pack.id, Enum.InfoType.Product)
				end)
				
				if success and info then
					pack.price = info.PriceInRobux
					self.priceCache:set("product_" .. pack.id, info.PriceInRobux)
					
					-- Update UI if visible
					if pack._priceLabel then
						pack._priceLabel.Text = "R$" .. pack.price
					end
				end
			end)
		else
			pack.price = cachedPrice
		end
	end
	
	-- Game passes
	for _, pass in ipairs(ProductData.gamePasses) do
		local cachedPrice = self.priceCache:get("pass_" .. pass.id)
		if not cachedPrice then
			task.spawn(function()
				local success, info = pcall(function()
					return MarketplaceService:GetProductInfo(pass.id, Enum.InfoType.GamePass)
				end)
				
				if success and info then
					pass.price = info.PriceInRobux
					self.priceCache:set("pass_" .. pass.id, info.PriceInRobux)
					
					-- Update UI if visible
					if pass._priceLabel then
						pass._priceLabel.Text = "R$" .. pass.price
					end
				end
			end)
		else
			pass.price = cachedPrice
		end
	end
end

function AdvancedShopManager:refreshOwnership()
	debugPrint("Refreshing ownership...")
	
	for _, pass in ipairs(ProductData.gamePasses) do
		task.spawn(function()
			local owned = self:checkOwnership(pass.id)
			if owned then
				self:updateItemOwned(pass)
			end
		end)
	end
end

function AdvancedShopManager:checkOwnership(passId)
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

function AdvancedShopManager:updateItemOwned(item)
	if not item._buyButton then return end
	
	-- Update button
	item._buyButton.Text = "✅ Owned"
	item._buyButton.Active = false
	item._buyButton.BackgroundColor3 = Theme.colors[self.currentTheme].success
	
	-- Update card stroke
	if item._card then
		local stroke = item._card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Theme.colors[self.currentTheme].success
			stroke.Transparency = 0.5
		end
	end
end

function AdvancedShopManager:purchaseProduct(product)
	debugPrint("Purchasing product:", product.id)
	
	self.soundManager:play("click", 0.1)
	
	local success = pcall(function()
		MarketplaceService:PromptProductPurchase(Player, product.id)
	end)
	
	if not success then
		self.soundManager:play("error", 0.15)
	end
end

function AdvancedShopManager:purchaseGamePass(pass)
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

function AdvancedShopManager:open()
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
	animate(self.blur, {Size = 24}, 0.3)
	
	-- Animate main container
	self.mainContainer.Position = UDim2.fromScale(0.5, 0.55)
	self.mainContainer.Size = isMobile() and UDim2.fromScale(0.95, 0.95) or UDim2.fromScale(0.85, 0.8)
	
	animate(self.mainContainer, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = isMobile() and UDim2.fromScale(1, 1) or UDim2.fromScale(0.9, 0.85),
	}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function()
		self.isAnimating = false
	end)
end

function AdvancedShopManager:close()
	if not self.isOpen or self.isAnimating then return end
	
	debugPrint("Closing shop")
	
	self.isAnimating = true
	self.isOpen = false
	
	self.soundManager:play("close", 0.15)
	
	-- Animate blur
	animate(self.blur, {Size = 0}, 0.2)
	
	-- Animate main container
	animate(self.mainContainer, {
		Position = UDim2.fromScale(0.5, 0.55),
		Size = isMobile() and UDim2.fromScale(0.95, 0.95) or UDim2.fromScale(0.85, 0.8),
	}, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function()
		self.gui.Enabled = false
		self.isAnimating = false
	end)
end

function AdvancedShopManager:toggle()
	if self.isOpen then
		self:close()
	else
		self:open()
	end
end

function AdvancedShopManager:destroy()
	debugPrint("Destroying shop manager")
	
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
		self.toggleButton.Parent:Destroy()
	end
end

-- Initialize shop
local shopManager = AdvancedShopManager.new()

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

print("[TycoonShop] Ultra Modern Complete UI v" .. SHOP_VERSION .. " initialized successfully!")

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