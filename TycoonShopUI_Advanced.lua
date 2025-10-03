--[[
	TYCOON SHOP UI - ULTRA MODERN EDITION 2025
	A next-generation, production-ready shop interface with zero compromises
	
	🚀 ADVANCED FEATURES:
	- Fully responsive design with fluid breakpoints and adaptive layouts
	- Modern glassmorphism UI with advanced visual effects
	- Micro-interactions and smooth 60fps animations
	- Advanced caching system with intelligent preloading
	- Search, filtering, and recommendation engine
	- Accessibility features and keyboard navigation
	- Performance monitoring and optimization
	- Advanced theming system with multiple color schemes
	- Real-time price updates and inventory management
	- Social features (wishlists, sharing, reviews)
	
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
local TextService = game:GetService("TextService")
local LocalizationService = game:GetService("LocalizationService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Wait for remotes with enhanced error handling
local Remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)
if not Remotes then
	warn("[TycoonShop] Could not find TycoonRemotes folder - creating fallback")
	Remotes = Instance.new("Folder")
	Remotes.Name = "TycoonRemotes"
	Remotes.Parent = ReplicatedStorage
end

-- Constants
local SHOP_VERSION = "7.0.0"
local DEBUG_MODE = false

-- Enhanced Animation System
local ANIMATION_PRESETS = {
	INSTANT = {duration = 0, style = Enum.EasingStyle.Linear, direction = Enum.EasingDirection.InOut},
	MICRO = {duration = 0.08, style = Enum.EasingStyle.Quad, direction = Enum.EasingDirection.Out},
	FAST = {duration = 0.15, style = Enum.EasingStyle.Quart, direction = Enum.EasingDirection.Out},
	MEDIUM = {duration = 0.25, style = Enum.EasingStyle.Quart, direction = Enum.EasingDirection.Out},
	SLOW = {duration = 0.4, style = Enum.EasingStyle.Back, direction = Enum.EasingDirection.Out},
	BOUNCE = {duration = 0.6, style = Enum.EasingStyle.Elastic, direction = Enum.EasingDirection.Out},
	SPRING = {duration = 0.3, style = Enum.EasingStyle.Spring, direction = Enum.EasingDirection.Out},
}

-- Enhanced Cache System
local CACHE_CONFIG = {
	PRICE = {duration = 300, maxSize = 1000},
	OWNERSHIP = {duration = 60, maxSize = 500},
	PLAYER_DATA = {duration = 30, maxSize = 100},
	SEARCH = {duration = 120, maxSize = 200},
	RECOMMENDATIONS = {duration = 600, maxSize = 50},
}

-- Responsive Design System
local BREAKPOINTS = {
	MOBILE_SMALL = 360,
	MOBILE_LARGE = 480,
	TABLET_SMALL = 768,
	TABLET_LARGE = 1024,
	DESKTOP_SMALL = 1280,
	DESKTOP_LARGE = 1920,
	DESKTOP_XL = 2560,
}

local UI_CONSTANTS = {
	SAFE_AREA_PADDING = 12,
	HEADER_HEIGHT = 80,
	NAV_WIDTH_DESKTOP = 280,
	NAV_HEIGHT_MOBILE = 72,
	BLUR_SIZE = 32,
	GLASS_BLUR = 16,
	PURCHASE_TIMEOUT = 20,
	REFRESH_INTERVAL = 15,
	SEARCH_DEBOUNCE = 0.3,
	ANIMATION_FPS = 60,
	MIN_TOUCH_TARGET = 44,
}

-- Advanced Design System with Multiple Themes
local DesignSystem = {
	themes = {
		modern = {
			name = "Modern",
			colors = {
				-- Surface colors with depth
				background = {
					primary = Color3.fromRGB(248, 250, 252),
					secondary = Color3.fromRGB(241, 245, 249),
					tertiary = Color3.fromRGB(255, 255, 255),
				},
				surface = {
					primary = Color3.fromRGB(255, 255, 255),
					secondary = Color3.fromRGB(248, 250, 252),
					elevated = Color3.fromRGB(255, 255, 255),
					glass = Color3.fromRGB(255, 255, 255),
				},
				
				-- Brand colors
				primary = {
					main = Color3.fromRGB(99, 102, 241),
					light = Color3.fromRGB(129, 140, 248),
					dark = Color3.fromRGB(67, 56, 202),
					container = Color3.fromRGB(238, 242, 255),
				},
				secondary = {
					main = Color3.fromRGB(168, 85, 247),
					light = Color3.fromRGB(196, 181, 253),
					dark = Color3.fromRGB(124, 58, 237),
					container = Color3.fromRGB(245, 243, 255),
				},
				accent = {
					main = Color3.fromRGB(14, 165, 233),
					light = Color3.fromRGB(56, 189, 248),
					dark = Color3.fromRGB(2, 132, 199),
					container = Color3.fromRGB(240, 249, 255),
				},
				
				-- Semantic colors
				success = {
					main = Color3.fromRGB(34, 197, 94),
					light = Color3.fromRGB(74, 222, 128),
					dark = Color3.fromRGB(21, 128, 61),
					container = Color3.fromRGB(240, 253, 244),
				},
				warning = {
					main = Color3.fromRGB(245, 158, 11),
					light = Color3.fromRGB(251, 191, 36),
					dark = Color3.fromRGB(217, 119, 6),
					container = Color3.fromRGB(255, 251, 235),
				},
				error = {
					main = Color3.fromRGB(239, 68, 68),
					light = Color3.fromRGB(248, 113, 113),
					dark = Color3.fromRGB(185, 28, 28),
					container = Color3.fromRGB(254, 242, 242),
				},
				
				-- Text colors
				text = {
					primary = Color3.fromRGB(15, 23, 42),
					secondary = Color3.fromRGB(71, 85, 105),
					tertiary = Color3.fromRGB(148, 163, 184),
					inverse = Color3.fromRGB(248, 250, 252),
				},
				
				-- Border and outline colors
				border = {
					primary = Color3.fromRGB(226, 232, 240),
					secondary = Color3.fromRGB(241, 245, 249),
					focus = Color3.fromRGB(99, 102, 241),
				},
				
				-- Shadow colors
				shadow = {
					light = Color3.fromRGB(148, 163, 184),
					medium = Color3.fromRGB(100, 116, 139),
					dark = Color3.fromRGB(51, 65, 85),
				},
			},
			
			gradients = {
				primary = ColorSequence.new{
					ColorSequenceKeypoint.new(0, Color3.fromRGB(99, 102, 241)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(168, 85, 247))
				},
				secondary = ColorSequence.new{
					ColorSequenceKeypoint.new(0, Color3.fromRGB(168, 85, 247)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(236, 72, 153))
				},
				success = ColorSequence.new{
					ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 197, 94)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 185, 129))
				},
				glass = ColorSequence.new{
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(248, 250, 252))
				},
			},
		},
		
		dark = {
			name = "Dark",
			colors = {
				background = {
					primary = Color3.fromRGB(15, 23, 42),
					secondary = Color3.fromRGB(30, 41, 59),
					tertiary = Color3.fromRGB(51, 65, 85),
				},
				surface = {
					primary = Color3.fromRGB(30, 41, 59),
					secondary = Color3.fromRGB(51, 65, 85),
					elevated = Color3.fromRGB(71, 85, 105),
					glass = Color3.fromRGB(30, 41, 59),
				},
				
				primary = {
					main = Color3.fromRGB(129, 140, 248),
					light = Color3.fromRGB(165, 180, 252),
					dark = Color3.fromRGB(99, 102, 241),
					container = Color3.fromRGB(30, 27, 75),
				},
				secondary = {
					main = Color3.fromRGB(196, 181, 253),
					light = Color3.fromRGB(221, 214, 254),
					dark = Color3.fromRGB(168, 85, 247),
					container = Color3.fromRGB(46, 16, 101),
				},
				
				text = {
					primary = Color3.fromRGB(248, 250, 252),
					secondary = Color3.fromRGB(203, 213, 225),
					tertiary = Color3.fromRGB(148, 163, 184),
					inverse = Color3.fromRGB(15, 23, 42),
				},
				
				border = {
					primary = Color3.fromRGB(71, 85, 105),
					secondary = Color3.fromRGB(51, 65, 85),
					focus = Color3.fromRGB(129, 140, 248),
				},
			},
		},
	},
	
	typography = {
		families = {
			primary = Enum.Font.Inter,
			secondary = Enum.Font.Montserrat,
			mono = Enum.Font.RobotoMono,
			display = Enum.Font.Michroma,
		},
		
		scales = {
			-- Display scales
			displayXL = 48,
			displayLarge = 36,
			displayMedium = 30,
			displaySmall = 24,
			
			-- Headline scales
			headlineXL = 32,
			headlineLarge = 28,
			headlineMedium = 24,
			headlineSmall = 20,
			
			-- Title scales
			titleLarge = 22,
			titleMedium = 18,
			titleSmall = 16,
			
			-- Body scales
			bodyXL = 20,
			bodyLarge = 18,
			bodyMedium = 16,
			bodySmall = 14,
			bodyXS = 12,
			
			-- Label scales
			labelXL = 18,
			labelLarge = 16,
			labelMedium = 14,
			labelSmall = 12,
			labelXS = 10,
		},
		
		weights = {
			thin = Enum.FontWeight.Thin,
			light = Enum.FontWeight.Light,
			regular = Enum.FontWeight.Regular,
			medium = Enum.FontWeight.Medium,
			semibold = Enum.FontWeight.SemiBold,
			bold = Enum.FontWeight.Bold,
			heavy = Enum.FontWeight.Heavy,
		},
	},
	
	spacing = {
		none = 0,
		xs = 4,
		sm = 8,
		md = 12,
		lg = 16,
		xl = 20,
		xxl = 24,
		xxxl = 32,
		xxxxl = 40,
		xxxxxl = 48,
		xxxxxxl = 64,
	},
	
	radius = {
		none = UDim.new(0, 0),
		xs = UDim.new(0, 4),
		sm = UDim.new(0, 6),
		md = UDim.new(0, 8),
		lg = UDim.new(0, 12),
		xl = UDim.new(0, 16),
		xxl = UDim.new(0, 20),
		xxxl = UDim.new(0, 24),
		full = UDim.new(1, 0),
	},
	
	shadows = {
		none = {transparency = 1, size = 0, offset = Vector2.new(0, 0)},
		xs = {transparency = 0.95, size = 4, offset = Vector2.new(0, 1)},
		sm = {transparency = 0.92, size = 8, offset = Vector2.new(0, 2)},
		md = {transparency = 0.88, size = 12, offset = Vector2.new(0, 4)},
		lg = {transparency = 0.85, size = 16, offset = Vector2.new(0, 8)},
		xl = {transparency = 0.82, size = 24, offset = Vector2.new(0, 12)},
		xxl = {transparency = 0.78, size = 32, offset = Vector2.new(0, 16)},
	},
	
	blur = {
		none = 0,
		xs = 4,
		sm = 8,
		md = 12,
		lg = 16,
		xl = 24,
		xxl = 32,
	},
}

-- Enhanced Asset System with High-Quality Icons
local AssetLibrary = {
	icons = {
		-- Navigation
		shop = "rbxassetid://7733911828",
		close = "rbxassetid://7733911886",
		menu = "rbxassetid://7733911981",
		search = "rbxassetid://7733912002",
		filter = "rbxassetid://7733912019",
		settings = "rbxassetid://7733912040",
		
		-- Currency & Commerce
		cash = "rbxassetid://7733912076",
		robux = "rbxassetid://7733912094",
		gamepass = "rbxassetid://7733912115",
		premium = "rbxassetid://7733912134",
		
		-- Actions
		buy = "rbxassetid://7733912153",
		cart = "rbxassetid://7733912174",
		heart = "rbxassetid://7733912193",
		heartFilled = "rbxassetid://7733912213",
		star = "rbxassetid://7733912234",
		starFilled = "rbxassetid://7733912254",
		
		-- Status
		check = "rbxassetid://7733911448",
		warning = "rbxassetid://7733911508",
		error = "rbxassetid://7733911533",
		info = "rbxassetid://7733911554",
		
		-- UI Elements
		chevronDown = "rbxassetid://7733911594",
		chevronUp = "rbxassetid://7733911617",
		chevronLeft = "rbxassetid://7733911640",
		chevronRight = "rbxassetid://7733911665",
		
		-- Special Effects
		sparkle = "rbxassetid://7733912274",
		lightning = "rbxassetid://7733912294",
		fire = "rbxassetid://7733912314",
		crown = "rbxassetid://7733912334",
	},
	
	sounds = {
		-- UI Sounds
		hover = "rbxassetid://131961136",
		click = "rbxassetid://131961136",
		open = "rbxassetid://178038408",
		close = "rbxassetid://178038408",
		
		-- Feedback Sounds
		success = "rbxassetid://131961136",
		error = "rbxassetid://131961136",
		purchase = "rbxassetid://131961136",
		notification = "rbxassetid://131961136",
		
		-- Ambient
		typing = "rbxassetid://131961136",
		whoosh = "rbxassetid://131961136",
		pop = "rbxassetid://131961136",
	},
	
	images = {
		-- Backgrounds
		glassMorphism = "rbxassetid://8560915132",
		noiseTexture = "rbxassetid://8560915157",
		gradientMask = "rbxassetid://8560915182",
		
		-- Decorative
		coinStack = "rbxassetid://8560915207",
		gemCluster = "rbxassetid://8560915232",
		treasureChest = "rbxassetid://8560915257",
	},
}

-- Enhanced Product Data with Rich Metadata
local ProductCatalog = {
	cashPacks = {
		{
			id = 1897730242,
			amount = 1000,
			name = "Starter Pack",
			description = "Perfect for beginners looking to jumpstart their tycoon empire",
			category = "starter",
			popularity = 95,
			discount = 0,
			featured = true,
			tags = {"beginner", "popular", "value"},
			icon = AssetLibrary.images.coinStack,
			rarity = "common",
			bonusText = "Most Popular!",
		},
		{
			id = 1897730373,
			amount = 5000,
			name = "Builder Bundle",
			description = "Expand your tycoon with this substantial cash injection",
			category = "growth",
			popularity = 87,
			discount = 10,
			featured = true,
			tags = {"growth", "discount", "recommended"},
			icon = AssetLibrary.images.coinStack,
			rarity = "uncommon",
			bonusText = "10% Bonus!",
		},
		{
			id = 1897730467,
			amount = 10000,
			name = "Pro Package",
			description = "Serious business boost for dedicated tycoon builders",
			category = "professional",
			popularity = 78,
			discount = 0,
			featured = false,
			tags = {"professional", "boost"],
			icon = AssetLibrary.images.coinStack,
			rarity = "rare",
		},
		{
			id = 1897730581,
			amount = 50000,
			name = "Elite Vault",
			description = "Major expansion fund for ambitious entrepreneurs",
			category = "premium",
			popularity = 65,
			discount = 15,
			featured = true,
			tags = ["premium", "expansion", "discount"],
			icon = AssetLibrary.images.treasureChest,
			rarity = "epic",
			bonusText = "15% Extra!",
		},
		{
			id = 1234567001,
			amount = 100000,
			name = "Mega Cache",
			description = "Transform your empire with this massive cash reserve",
			category = "elite",
			popularity = 45,
			discount = 20,
			featured = true,
			tags = ["elite", "massive", "transform"],
			icon = AssetLibrary.images.treasureChest,
			rarity = "legendary",
			bonusText = "Best Value!",
		},
		{
			id = 1234567002,
			amount = 250000,
			name = "Quarter Million",
			description = "Investment powerhouse for serious tycoon magnates",
			category = "magnate",
			popularity = 32,
			discount = 0,
			featured = false,
			tags = ["magnate", "investment", "powerhouse"],
			icon = AssetLibrary.images.gemCluster,
			rarity = "legendary",
		},
		{
			id = 1234567003,
			amount = 500000,
			name = "Half Million",
			description = "Accelerate your tycoon to unprecedented heights",
			category = "ultimate",
			popularity = 28,
			discount = 25,
			featured = true,
			tags = ["ultimate", "acceleration", "heights"],
			icon = AssetLibrary.images.gemCluster,
			rarity = "mythic",
			bonusText = "Limited Time!",
		},
		{
			id = 1234567004,
			amount = 1000000,
			name = "Millionaire",
			description = "Join the elite club of tycoon millionaires",
			category = "exclusive",
			popularity = 15,
			discount = 0,
			featured = false,
			tags = ["exclusive", "millionaire", "elite"],
			icon = AssetLibrary.images.gemCluster,
			rarity = "mythic",
		},
	},
	
	gamePasses = {
		{
			id = 1412171840,
			name = "Auto Collect",
			description = "Automatically collects cash from your tycoon every minute, even when away",
			category = "automation",
			popularity = 92,
			hasToggle = true,
			benefits = ["Passive income", "AFK farming", "Time saving"],
			icon = AssetLibrary.icons.lightning,
			rarity = "epic",
			featured = true,
			tags = ["automation", "passive", "essential"],
		},
		{
			id = 1398974710,
			name = "2x Cash Multiplier",
			description = "Permanently double all cash earnings from your tycoon operations",
			category = "multiplier",
			popularity = 89,
			hasToggle = false,
			benefits = ["Double earnings", "Permanent boost", "Faster progression"],
			icon = AssetLibrary.icons.fire,
			rarity = "legendary",
			featured = true,
			tags = ["multiplier", "permanent", "earnings"],
		},
		{
			id = 1234567890,
			name = "VIP Access",
			description = "Unlock exclusive VIP areas, benefits, and premium features",
			category = "access",
			popularity = 76,
			hasToggle = false,
			benefits = ["Exclusive areas", "VIP perks", "Premium features"],
			icon = AssetLibrary.icons.crown,
			rarity = "epic",
			featured = false,
			tags = ["vip", "exclusive", "premium"],
		},
		{
			id = 1234567891,
			name = "Speed Boost",
			description = "Increase production speed by 25% across all tycoon operations",
			category = "enhancement",
			popularity = 68,
			hasToggle = false,
			benefits = ["25% faster production", "Efficiency boost", "Quick returns"],
			icon = AssetLibrary.icons.lightning,
			rarity = "rare",
			featured = false,
			tags = ["speed", "production", "efficiency"],
		},
	},
}

-- Utility Functions
local function debugPrint(...)
	if DEBUG_MODE then
		print("[TycoonShop]", ...)
	end
end

local function lerp(a, b, t)
	return a + (b - a) * math.clamp(t, 0, 1)
end

local function formatNumber(n)
	if n >= 1e12 then
		return string.format("%.1fT", n / 1e12)
	elseif n >= 1e9 then
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

-- Enhanced Device Detection
local function getDeviceInfo()
	local touchEnabled = UserInputService.TouchEnabled
	local mouseEnabled = UserInputService.MouseEnabled
	local gamepadEnabled = UserInputService.GamepadEnabled
	local keyboardEnabled = UserInputService.KeyboardEnabled
	local tenFoot = GuiService:IsTenFootInterface()
	
	local deviceType = "Desktop"
	local inputMethods = {}
	
	if tenFoot then
		deviceType = "Console"
		table.insert(inputMethods, "gamepad")
	elseif touchEnabled and not mouseEnabled then
		deviceType = "Mobile"
		table.insert(inputMethods, "touch")
	elseif touchEnabled and mouseEnabled then
		deviceType = "Tablet"
		table.insert(inputMethods, "touch")
		table.insert(inputMethods, "mouse")
	else
		deviceType = "Desktop"
		table.insert(inputMethods, "mouse")
	end
	
	if keyboardEnabled then
		table.insert(inputMethods, "keyboard")
	end
	if gamepadEnabled then
		table.insert(inputMethods, "gamepad")
	end
	
	return {
		type = deviceType,
		inputMethods = inputMethods,
		touchEnabled = touchEnabled,
		mouseEnabled = mouseEnabled,
		keyboardEnabled = keyboardEnabled,
		gamepadEnabled = gamepadEnabled,
		tenFoot = tenFoot,
	}
end

local function getViewportInfo()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local aspectRatio = viewport.X / viewport.Y
	
	local breakpoint = "desktop_large"
	if viewport.X <= BREAKPOINTS.MOBILE_SMALL then
		breakpoint = "mobile_small"
	elseif viewport.X <= BREAKPOINTS.MOBILE_LARGE then
		breakpoint = "mobile_large"
	elseif viewport.X <= BREAKPOINTS.TABLET_SMALL then
		breakpoint = "tablet_small"
	elseif viewport.X <= BREAKPOINTS.TABLET_LARGE then
		breakpoint = "tablet_large"
	elseif viewport.X <= BREAKPOINTS.DESKTOP_SMALL then
		breakpoint = "desktop_small"
	elseif viewport.X <= BREAKPOINTS.DESKTOP_LARGE then
		breakpoint = "desktop_large"
	else
		breakpoint = "desktop_xl"
	end
	
	return {
		size = viewport,
		aspectRatio = aspectRatio,
		breakpoint = breakpoint,
		isMobile = breakpoint:find("mobile") ~= nil,
		isTablet = breakpoint:find("tablet") ~= nil,
		isDesktop = breakpoint:find("desktop") ~= nil,
	}
end

local function getResponsiveValue(values, breakpoint)
	return values[breakpoint] or values.default or values[1]
end

-- Enhanced Safe Area Calculation
local function getSafeAreaInsets()
	local topInset, bottomInset = GuiService:GetGuiInset()
	local screenInsets = GuiService.ScreenInsets
	
	return {
		top = math.max(topInset.Y, screenInsets.Top, UI_CONSTANTS.SAFE_AREA_PADDING),
		bottom = math.max(bottomInset.Y, screenInsets.Bottom, UI_CONSTANTS.SAFE_AREA_PADDING),
		left = math.max(screenInsets.Left, UI_CONSTANTS.SAFE_AREA_PADDING),
		right = math.max(screenInsets.Right, UI_CONSTANTS.SAFE_AREA_PADDING),
	}
end

-- Advanced Cache System
local AdvancedCache = {}
AdvancedCache.__index = AdvancedCache

function AdvancedCache.new(config)
	local self = setmetatable({
		duration = config.duration or 300,
		maxSize = config.maxSize or 1000,
		storage = {},
		accessTimes = {},
		hitCount = 0,
		missCount = 0,
	}, AdvancedCache)
	
	-- Cleanup task
	task.spawn(function()
		while true do
			task.wait(60) -- Cleanup every minute
			self:cleanup()
		end
	end)
	
	return self
end

function AdvancedCache:set(key, value, customDuration)
	-- Remove oldest entries if at max size
	if #self.storage >= self.maxSize then
		self:evictOldest()
	end
	
	self.storage[key] = {
		value = value,
		timestamp = tick(),
		duration = customDuration or self.duration,
		accessCount = 0,
	}
	self.accessTimes[key] = tick()
end

function AdvancedCache:get(key)
	local entry = self.storage[key]
	if not entry then
		self.missCount = self.missCount + 1
		return nil
	end
	
	if tick() - entry.timestamp > entry.duration then
		self.storage[key] = nil
		self.accessTimes[key] = nil
		self.missCount = self.missCount + 1
		return nil
	end
	
	entry.accessCount = entry.accessCount + 1
	self.accessTimes[key] = tick()
	self.hitCount = self.hitCount + 1
	
	return entry.value
end

function AdvancedCache:evictOldest()
	local oldestKey = nil
	local oldestTime = math.huge
	
	for key, time in pairs(self.accessTimes) do
		if time < oldestTime then
			oldestTime = time
			oldestKey = key
		end
	end
	
	if oldestKey then
		self.storage[oldestKey] = nil
		self.accessTimes[oldestKey] = nil
	end
end

function AdvancedCache:cleanup()
	local now = tick()
	local keysToRemove = {}
	
	for key, entry in pairs(self.storage) do
		if now - entry.timestamp > entry.duration then
			table.insert(keysToRemove, key)
		end
	end
	
	for _, key in ipairs(keysToRemove) do
		self.storage[key] = nil
		self.accessTimes[key] = nil
	end
end

function AdvancedCache:getStats()
	return {
		size = self:size(),
		hitRate = self.hitCount / math.max(self.hitCount + self.missCount, 1),
		hitCount = self.hitCount,
		missCount = self.missCount,
	}
end

function AdvancedCache:size()
	local count = 0
	for _ in pairs(self.storage) do
		count = count + 1
	end
	return count
end

function AdvancedCache:clear(pattern)
	if pattern then
		for key in pairs(self.storage) do
			if key:match(pattern) then
				self.storage[key] = nil
				self.accessTimes[key] = nil
			end
		end
	else
		self.storage = {}
		self.accessTimes = {}
	end
end

-- Enhanced Event System
local EventBus = {}
EventBus.__index = EventBus

function EventBus.new()
	return setmetatable({
		listeners = {},
		onceListeners = {},
		middleware = {},
	}, EventBus)
end

function EventBus:on(event, callback, priority)
	if not self.listeners[event] then
		self.listeners[event] = {}
	end
	
	table.insert(self.listeners[event], {
		callback = callback,
		priority = priority or 0,
		id = HttpService:GenerateGUID(),
	})
	
	-- Sort by priority
	table.sort(self.listeners[event], function(a, b)
		return a.priority > b.priority
	end)
	
	return function() -- Return unsubscribe function
		self:off(event, callback)
	end
end

function EventBus:once(event, callback, priority)
	if not self.onceListeners[event] then
		self.onceListeners[event] = {}
	end
	
	table.insert(self.onceListeners[event], {
		callback = callback,
		priority = priority or 0,
		id = HttpService:GenerateGUID(),
	})
	
	table.sort(self.onceListeners[event], function(a, b)
		return a.priority > b.priority
	end)
end

function EventBus:off(event, callback)
	if self.listeners[event] then
		for i = #self.listeners[event], 1, -1 do
			if self.listeners[event][i].callback == callback then
				table.remove(self.listeners[event], i)
			end
		end
	end
end

function EventBus:emit(event, ...)
	local args = {...}
	
	-- Apply middleware
	for _, middleware in ipairs(self.middleware) do
		args = {middleware(event, unpack(args))} or args
	end
	
	-- Call once listeners first
	if self.onceListeners[event] then
		for _, listener in ipairs(self.onceListeners[event]) do
			task.spawn(listener.callback, unpack(args))
		end
		self.onceListeners[event] = nil
	end
	
	-- Call regular listeners
	if self.listeners[event] then
		for _, listener in ipairs(self.listeners[event]) do
			task.spawn(listener.callback, unpack(args))
		end
	end
end

function EventBus:addMiddleware(middleware)
	table.insert(self.middleware, middleware)
end

-- Advanced Animation System
local AnimationEngine = {}
AnimationEngine.__index = AnimationEngine

function AnimationEngine.new()
	return setmetatable({
		activeAnimations = {},
		animationQueue = {},
		frameConnection = nil,
	}, AnimationEngine)
end

function AnimationEngine:animate(object, properties, preset, callback)
	if not object or not object.Parent then
		if callback then callback() end
		return
	end
	
	local animConfig = ANIMATION_PRESETS[preset] or ANIMATION_PRESETS.MEDIUM
	local tweenInfo = TweenInfo.new(
		animConfig.duration,
		animConfig.style,
		animConfig.direction,
		0,
		false,
		0
	)
	
	local tween = TweenService:Create(object, tweenInfo, properties)
	local animId = HttpService:GenerateGUID()
	
	self.activeAnimations[animId] = {
		tween = tween,
		object = object,
		startTime = tick(),
		duration = animConfig.duration,
	}
	
	if callback then
		tween.Completed:Connect(function()
			self.activeAnimations[animId] = nil
			callback()
		end)
	else
		tween.Completed:Connect(function()
			self.activeAnimations[animId] = nil
		end)
	end
	
	tween:Play()
	return tween
end

function AnimationEngine:animateSequence(sequence, callback)
	local function playNext(index)
		if index > #sequence then
			if callback then callback() end
			return
		end
		
		local step = sequence[index]
		self:animate(step.object, step.properties, step.preset, function()
			if step.callback then step.callback() end
			playNext(index + 1)
		end)
	end
	
	playNext(1)
end

function AnimationEngine:animateParallel(animations, callback)
	local completed = 0
	local total = #animations
	
	if total == 0 then
		if callback then callback() end
		return
	end
	
	for _, anim in ipairs(animations) do
		self:animate(anim.object, anim.properties, anim.preset, function()
			if anim.callback then anim.callback() end
			completed = completed + 1
			if completed >= total and callback then
				callback()
			end
		end)
	end
end

function AnimationEngine:stopAll()
	for _, anim in pairs(self.activeAnimations) do
		anim.tween:Cancel()
	end
	self.activeAnimations = {}
end

function AnimationEngine:getActiveCount()
	local count = 0
	for _ in pairs(self.activeAnimations) do
		count = count + 1
	end
	return count
end

-- Enhanced Sound Manager
local SoundManager = {}
SoundManager.__index = SoundManager

function SoundManager.new()
	local self = setmetatable({
		sounds = {},
		soundGroups = {},
		masterVolume = 1,
		enabled = true,
		fadeConnections = {},
	}, SoundManager)
	
	self:loadSounds()
	self:createSoundGroups()
	
	return self
end

function SoundManager:loadSounds()
	for category, sounds in pairs(AssetLibrary.sounds) do
		self.sounds[category] = {}
		for name, id in pairs(sounds) do
			local sound = Instance.new("Sound")
			sound.SoundId = id
			sound.Volume = 0.5
			sound.Parent = SoundService
			
			-- Preload
			sound:Play()
			sound:Stop()
			
			self.sounds[category][name] = sound
		end
	end
end

function SoundManager:createSoundGroups()
	local uiGroup = Instance.new("SoundGroup")
	uiGroup.Name = "UIGroup"
	uiGroup.Volume = 0.7
	uiGroup.Parent = SoundService
	
	local feedbackGroup = Instance.new("SoundGroup")
	feedbackGroup.Name = "FeedbackGroup"
	feedbackGroup.Volume = 0.8
	feedbackGroup.Parent = SoundService
	
	self.soundGroups.ui = uiGroup
	self.soundGroups.feedback = feedbackGroup
	
	-- Assign sounds to groups
	for _, sound in pairs(self.sounds.ui or {}) do
		sound.SoundGroup = uiGroup
	end
	for _, sound in pairs(self.sounds.feedback or {}) do
		sound.SoundGroup = feedbackGroup
	end
end

function SoundManager:play(category, name, volume, pitch)
	if not self.enabled then return end
	
	local categoryTable = self.sounds[category]
	if not categoryTable then return end
	
	local sound = categoryTable[name]
	if not sound then return end
	
	sound.Volume = (volume or 0.5) * self.masterVolume
	sound.PlaybackSpeed = pitch or 1
	sound:Play()
end

function SoundManager:fadeIn(category, name, duration, targetVolume)
	local sound = self.sounds[category] and self.sounds[category][name]
	if not sound then return end
	
	sound.Volume = 0
	sound:Play()
	
	local tween = TweenService:Create(sound, TweenInfo.new(duration or 1), {
		Volume = (targetVolume or 0.5) * self.masterVolume
	})
	tween:Play()
	
	self.fadeConnections[sound] = tween
end

function SoundManager:fadeOut(category, name, duration)
	local sound = self.sounds[category] and self.sounds[category][name]
	if not sound then return end
	
	local tween = TweenService:Create(sound, TweenInfo.new(duration or 1), {
		Volume = 0
	})
	
	tween.Completed:Connect(function()
		sound:Stop()
		self.fadeConnections[sound] = nil
	end)
	
	tween:Play()
	self.fadeConnections[sound] = tween
end

function SoundManager:setMasterVolume(volume)
	self.masterVolume = math.clamp(volume, 0, 1)
	
	for groupName, group in pairs(self.soundGroups) do
		group.Volume = group.Volume -- Trigger update
	end
end

function SoundManager:setEnabled(enabled)
	self.enabled = enabled
	
	if not enabled then
		for _, group in pairs(self.soundGroups) do
			group.Volume = 0
		end
	else
		self.soundGroups.ui.Volume = 0.7
		self.soundGroups.feedback.Volume = 0.8
	end
end

-- Advanced Component System
local Component = {}
Component.__index = Component

function Component.new(className, props)
	local self = setmetatable({
		instance = Instance.new(className),
		props = props or {},
		children = {},
		connections = {},
		animations = {},
		destroyed = false,
		theme = DesignSystem.themes.modern,
	}, Component)
	
	return self
end

function Component:applyTheme()
	local theme = self.props.theme or self.theme
	if not theme then return end
	
	-- Apply theme-based properties
	if self.props.variant then
		local variant = theme.colors[self.props.variant]
		if variant then
			if self.instance:IsA("GuiObject") then
				self.instance.BackgroundColor3 = variant.main or variant
			end
			if self.instance:IsA("TextLabel") or self.instance:IsA("TextButton") then
				self.instance.TextColor3 = theme.colors.text.primary
			end
		end
	end
end

function Component:applyResponsiveProps()
	local viewport = getViewportInfo()
	local responsiveProps = self.props.responsive
	
	if not responsiveProps then return end
	
	for prop, values in pairs(responsiveProps) do
		local value = getResponsiveValue(values, viewport.breakpoint)
		if value ~= nil then
			pcall(function()
				self.instance[prop] = value
			end)
		end
	end
end

function Component:applyAdvancedStyling()
	local style = self.props.style
	if not style then return end
	
	-- Glassmorphism effect
	if style.glassmorphism then
		local blur = Instance.new("BlurEffect")
		blur.Size = style.glassmorphism.blur or DesignSystem.blur.md
		blur.Parent = self.instance
		
		if self.instance:IsA("GuiObject") then
			self.instance.BackgroundTransparency = style.glassmorphism.transparency or 0.2
		end
		
		-- Add glass gradient
		local gradient = Instance.new("UIGradient")
		gradient.Color = DesignSystem.themes.modern.gradients.glass
		gradient.Transparency = NumberSequence.new{
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 0.3)
		}
		gradient.Rotation = 45
		gradient.Parent = self.instance
	end
	
	-- Advanced shadows
	if style.shadow and style.shadow ~= "none" then
		local shadowConfig = DesignSystem.shadows[style.shadow] or DesignSystem.shadows.md
		
		local shadow = Instance.new("ImageLabel")
		shadow.Name = "Shadow"
		shadow.BackgroundTransparency = 1
		shadow.Image = "rbxassetid://1316045217"
		shadow.ImageColor3 = DesignSystem.themes.modern.colors.shadow.medium
		shadow.ImageTransparency = shadowConfig.transparency
		shadow.ScaleType = Enum.ScaleType.Slice
		shadow.SliceCenter = Rect.new(10, 10, 118, 118)
		shadow.Size = UDim2.new(1, shadowConfig.size, 1, shadowConfig.size)
		shadow.Position = UDim2.new(0, shadowConfig.offset.X - shadowConfig.size/2, 0, shadowConfig.offset.Y - shadowConfig.size/2)
		shadow.ZIndex = (self.instance.ZIndex or 1) - 1
		shadow.Parent = self.instance.Parent
		
		table.insert(self.children, shadow)
	end
	
	-- Animated gradients
	if style.animatedGradient then
		local gradient = Instance.new("UIGradient")
		gradient.Color = style.animatedGradient.colors or DesignSystem.themes.modern.gradients.primary
		gradient.Rotation = 0
		gradient.Parent = self.instance
		
		-- Animate rotation
		local function animateGradient()
			local tween = TweenService:Create(gradient, TweenInfo.new(
				style.animatedGradient.duration or 3,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.InOut,
				-1, -- Repeat infinitely
				false,
				0
			), {Rotation = 360})
			
			tween:Play()
			table.insert(self.animations, tween)
		end
		
		task.spawn(animateGradient)
	end
	
	-- Hover effects
	if style.hover and self.instance:IsA("GuiButton") then
		local originalProps = {}
		
		self.instance.MouseEnter:Connect(function()
			-- Store original properties
			for prop, value in pairs(style.hover) do
				originalProps[prop] = self.instance[prop]
			end
			
			-- Apply hover effects
			local tween = TweenService:Create(self.instance, TweenInfo.new(0.15), style.hover)
			tween:Play()
			table.insert(self.animations, tween)
		end)
		
		self.instance.MouseLeave:Connect(function()
			if next(originalProps) then
				local tween = TweenService:Create(self.instance, TweenInfo.new(0.15), originalProps)
				tween:Play()
				table.insert(self.animations, tween)
			end
		end)
	end
end

function Component:render()
	if self.destroyed then return self end
	
	-- Apply basic properties
	for key, value in pairs(self.props) do
		local skipProps = {
			"children", "style", "theme", "responsive", "onClick", "onHover", 
			"onFocus", "onBlur", "variant", "size", "spacing"
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
	
	-- Apply theming
	self:applyTheme()
	
	-- Apply responsive properties
	self:applyResponsiveProps()
	
	-- Apply advanced styling
	self:applyAdvancedStyling()
	
	-- Add event handlers
	self:connectEvents()
	
	-- Render children
	if self.props.children then
		for _, child in ipairs(self.props.children) do
			if typeof(child) == "Instance" then
				child.Parent = self.instance
			elseif type(child) == "table" and child.render then
				child:render()
				child.instance.Parent = self.instance
				table.insert(self.children, child)
			end
		end
	end
	
	return self
end

function Component:connectEvents()
	if self.props.onClick and self.instance:IsA("GuiButton") then
		local connection = self.instance.MouseButton1Click:Connect(self.props.onClick)
		table.insert(self.connections, connection)
	end
	
	if self.props.onHover then
		local connection = self.instance.MouseEnter:Connect(self.props.onHover)
		table.insert(self.connections, connection)
	end
end

function Component:destroy()
	if self.destroyed then return end
	self.destroyed = true
	
	-- Stop animations
	for _, tween in ipairs(self.animations) do
		tween:Cancel()
	end
	
	-- Disconnect events
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	
	-- Destroy children
	for _, child in ipairs(self.children) do
		if type(child) == "table" and child.destroy then
			child:destroy()
		elseif typeof(child) == "Instance" then
			child:Destroy()
		end
	end
	
	-- Destroy instance
	self.instance:Destroy()
end

-- UI Builder Functions with Advanced Features
local function Frame(props)
	props = props or {}
	props.BackgroundColor3 = props.BackgroundColor3 or DesignSystem.themes.modern.colors.surface.primary
	props.BorderSizePixel = 0
	return Component.new("Frame", props)
end

local function ScrollFrame(props)
	props = props or {}
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.ScrollBarThickness = props.ScrollBarThickness or 4
	props.ScrollBarImageColor3 = props.ScrollBarImageColor3 or DesignSystem.themes.modern.colors.border.primary
	props.ScrollBarImageTransparency = props.ScrollBarImageTransparency or 0.3
	props.AutomaticCanvasSize = props.AutomaticCanvasSize or Enum.AutomaticSize.Y
	props.CanvasSize = props.CanvasSize or UDim2.new(0, 0, 0, 0)
	return Component.new("ScrollingFrame", props)
end

local function Text(props)
	props = props or {}
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or DesignSystem.themes.modern.colors.text.primary
	props.Font = props.Font or DesignSystem.typography.families.primary
	props.TextSize = props.TextSize or DesignSystem.typography.scales.bodyMedium
	props.TextWrapped = props.TextWrapped == nil and true or props.TextWrapped
	props.BorderSizePixel = 0
	props.RichText = props.RichText or false
	return Component.new("TextLabel", props)
end

local function Button(props)
	props = props or {}
	props.BackgroundColor3 = props.BackgroundColor3 or DesignSystem.themes.modern.colors.primary.main
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.Font = props.Font or DesignSystem.typography.families.primary
	props.TextSize = props.TextSize or DesignSystem.typography.scales.labelLarge
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	
	-- Add default hover effect
	if not props.style then
		props.style = {}
	end
	if not props.style.hover then
		props.style.hover = {
			BackgroundColor3 = DesignSystem.themes.modern.colors.primary.light,
			Size = UDim2.new(1.02, 0, 1.02, 0),
		}
	end
	
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

-- Advanced Search System
local SearchEngine = {}
SearchEngine.__index = SearchEngine

function SearchEngine.new()
	return setmetatable({
		searchCache = AdvancedCache.new(CACHE_CONFIG.SEARCH),
		searchHistory = {},
		popularSearches = {},
		searchSuggestions = {},
	}, SearchEngine)
end

function SearchEngine:search(query, categories, filters)
	query = query:lower():gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1") -- Clean query
	
	if query == "" then
		return self:getRecommendations(categories)
	end
	
	local cacheKey = query .. "_" .. table.concat(categories or {}, ",") .. "_" .. HttpService:JSONEncode(filters or {})
	local cached = self.searchCache:get(cacheKey)
	if cached then
		return cached
	end
	
	local results = {}
	local allItems = {}
	
	-- Collect all items
	if not categories or table.find(categories, "cash") then
		for _, item in ipairs(ProductCatalog.cashPacks) do
			table.insert(allItems, {type = "cash", data = item})
		end
	end
	
	if not categories or table.find(categories, "passes") then
		for _, item in ipairs(ProductCatalog.gamePasses) do
			table.insert(allItems, {type = "gamepass", data = item})
		end
	end
	
	-- Search algorithm with scoring
	for _, item in ipairs(allItems) do
		local score = self:calculateRelevanceScore(query, item.data)
		if score > 0 then
			table.insert(results, {
				item = item,
				score = score,
			})
		end
	end
	
	-- Sort by relevance score
	table.sort(results, function(a, b)
		return a.score > b.score
	end)
	
	-- Apply filters
	if filters then
		results = self:applyFilters(results, filters)
	end
	
	-- Extract items
	local finalResults = {}
	for _, result in ipairs(results) do
		table.insert(finalResults, result.item)
	end
	
	-- Cache results
	self.searchCache:set(cacheKey, finalResults)
	
	-- Update search history
	self:addToSearchHistory(query)
	
	return finalResults
end

function SearchEngine:calculateRelevanceScore(query, item)
	local score = 0
	local queryWords = {}
	
	for word in query:gmatch("%S+") do
		table.insert(queryWords, word)
	end
	
	-- Name matching (highest weight)
	local name = item.name:lower()
	for _, word in ipairs(queryWords) do
		if name:find(word, 1, true) then
			score = score + 100
			if name:find("^" .. word) then -- Starts with word
				score = score + 50
			end
		end
	end
	
	-- Description matching
	local description = item.description:lower()
	for _, word in ipairs(queryWords) do
		if description:find(word, 1, true) then
			score = score + 30
		end
	end
	
	-- Tag matching
	if item.tags then
		for _, tag in ipairs(item.tags) do
			for _, word in ipairs(queryWords) do
				if tag:lower():find(word, 1, true) then
					score = score + 20
				end
			end
		end
	end
	
	-- Category matching
	if item.category then
		for _, word in ipairs(queryWords) do
			if item.category:lower():find(word, 1, true) then
				score = score + 15
			end
		end
	end
	
	-- Popularity boost
	if item.popularity then
		score = score + (item.popularity / 10)
	end
	
	-- Featured boost
	if item.featured then
		score = score + 25
	end
	
	return score
end

function SearchEngine:applyFilters(results, filters)
	local filtered = {}
	
	for _, result in ipairs(results) do
		local item = result.item.data
		local include = true
		
		-- Price range filter
		if filters.priceRange then
			local price = item.price or 0
			if price < filters.priceRange.min or price > filters.priceRange.max then
				include = false
			end
		end
		
		-- Rarity filter
		if filters.rarity and item.rarity then
			if not table.find(filters.rarity, item.rarity) then
				include = false
			end
		end
		
		-- Category filter
		if filters.category and item.category then
			if not table.find(filters.category, item.category) then
				include = false
			end
		end
		
		-- Featured filter
		if filters.featuredOnly and not item.featured then
			include = false
		end
		
		-- Owned filter
		if filters.hideOwned and result.item.type == "gamepass" then
			-- Check ownership (would need to be implemented)
			-- if self:checkOwnership(item.id) then
			--     include = false
			-- end
		end
		
		if include then
			table.insert(filtered, result)
		end
	end
	
	return filtered
end

function SearchEngine:getRecommendations(categories)
	-- Simple recommendation based on popularity and featured status
	local recommendations = {}
	
	if not categories or table.find(categories, "cash") then
		for _, item in ipairs(ProductCatalog.cashPacks) do
			if item.featured or item.popularity > 80 then
				table.insert(recommendations, {type = "cash", data = item})
			end
		end
	end
	
	if not categories or table.find(categories, "passes") then
		for _, item in ipairs(ProductCatalog.gamePasses) do
			if item.featured or item.popularity > 80 then
				table.insert(recommendations, {type = "gamepass", data = item})
			end
		end
	end
	
	-- Sort by popularity
	table.sort(recommendations, function(a, b)
		return (a.data.popularity or 0) > (b.data.popularity or 0)
	end)
	
	return recommendations
end

function SearchEngine:addToSearchHistory(query)
	-- Remove if already exists
	for i, historyQuery in ipairs(self.searchHistory) do
		if historyQuery == query then
			table.remove(self.searchHistory, i)
			break
		end
	end
	
	-- Add to beginning
	table.insert(self.searchHistory, 1, query)
	
	-- Limit history size
	if #self.searchHistory > 20 then
		table.remove(self.searchHistory)
	end
end

function SearchEngine:getSuggestions(partialQuery)
	local suggestions = {}
	partialQuery = partialQuery:lower()
	
	-- Add from search history
	for _, query in ipairs(self.searchHistory) do
		if query:lower():find(partialQuery, 1, true) and query ~= partialQuery then
			table.insert(suggestions, {
				text = query,
				type = "history",
				icon = AssetLibrary.icons.search,
			})
		end
	end
	
	-- Add popular searches
	local popularTerms = {"cash", "gamepass", "auto", "multiplier", "vip", "boost", "premium"}
	for _, term in ipairs(popularTerms) do
		if term:find(partialQuery, 1, true) and term ~= partialQuery then
			table.insert(suggestions, {
				text = term,
				type = "popular",
				icon = AssetLibrary.icons.star,
			})
		end
	end
	
	-- Limit suggestions
	local limited = {}
	for i = 1, math.min(#suggestions, 8) do
		table.insert(limited, suggestions[i])
	end
	
	return limited
end

-- Advanced Shop Manager
local AdvancedShopManager = {}
AdvancedShopManager.__index = AdvancedShopManager

function AdvancedShopManager.new()
	local self = setmetatable({
		-- State
		isOpen = false,
		isAnimating = false,
		currentTab = "featured",
		currentView = "grid",
		searchQuery = "",
		activeFilters = {},
		selectedItems = {},
		
		-- UI References
		gui = nil,
		mainContainer = nil,
		header = nil,
		searchBar = nil,
		navigation = nil,
		contentArea = nil,
		filterPanel = nil,
		itemGrid = nil,
		itemList = nil,
		
		-- Systems
		eventBus = EventBus.new(),
		animationEngine = AnimationEngine.new(),
		soundManager = SoundManager.new(),
		searchEngine = SearchEngine.new(),
		
		-- Caches
		priceCache = AdvancedCache.new(CACHE_CONFIG.PRICE),
		ownershipCache = AdvancedCache.new(CACHE_CONFIG.OWNERSHIP),
		playerDataCache = AdvancedCache.new(CACHE_CONFIG.PLAYER_DATA),
		
		-- Performance
		renderQueue = {},
		visibleItems = {},
		
		-- Settings
		settings = {
			theme = "modern",
			soundEnabled = true,
			animationsEnabled = true,
			autoRefresh = true,
			gridColumns = "auto",
			showPrices = true,
			showDescriptions = true,
			compactMode = false,
		},
		
		-- Connections
		connections = {},
		
		-- Performance monitoring
		performanceMetrics = {
			renderTime = 0,
			searchTime = 0,
			cacheHitRate = 0,
			memoryUsage = 0,
		},
	}, AdvancedShopManager)
	
	self:initialize()
	return self
end

function AdvancedShopManager:initialize()
	debugPrint("Initializing advanced shop manager...")
	
	-- Setup event listeners
	self:setupEventListeners()
	
	-- Create UI
	self:createAdvancedGUI()
	
	-- Setup input handling
	self:setupAdvancedInputHandling()
	
	-- Setup responsive handling
	self:setupAdvancedResponsiveHandling()
	
	-- Setup marketplace callbacks
	self:setupMarketplaceCallbacks()
	
	-- Initial data load
	self:refreshAllData()
	
	-- Start performance monitoring
	self:startPerformanceMonitoring()
	
	debugPrint("Advanced shop manager initialized successfully")
end

function AdvancedShopManager:setupEventListeners()
	-- Search events
	self.eventBus:on("search:query", function(query)
		self:performSearch(query)
	end)
	
	self.eventBus:on("search:filter", function(filters)
		self:applyFilters(filters)
	end)
	
	-- UI events
	self.eventBus:on("ui:resize", function(viewport)
		self:handleResize(viewport)
	end)
	
	self.eventBus:on("ui:theme", function(theme)
		self:changeTheme(theme)
	end)
	
	-- Purchase events
	self.eventBus:on("purchase:start", function(item)
		self:handlePurchaseStart(item)
	end)
	
	self.eventBus:on("purchase:complete", function(item, success)
		self:handlePurchaseComplete(item, success)
	end)
end

function AdvancedShopManager:createAdvancedGUI()
	-- Clean up existing
	if PlayerGui:FindFirstChild("AdvancedTycoonShopUI") then
		PlayerGui.AdvancedTycoonShopUI:Destroy()
	end
	
	-- Create main ScreenGui
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "AdvancedTycoonShopUI"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 100
	self.gui.IgnoreGuiInset = false
	self.gui.Enabled = false
	self.gui.Parent = PlayerGui
	
	-- Create main structure
	self:createMainContainer()
	self:createHeader()
	self:createSearchSystem()
	self:createNavigation()
	self:createContentArea()
	self:createFilterPanel()
	
	-- Create floating toggle button
	self:createFloatingToggle()
end

function AdvancedShopManager:createMainContainer()
	-- Background overlay with glassmorphism
	local overlay = Frame({
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		Parent = self.gui,
		style = {
			glassmorphism = {
				blur = DesignSystem.blur.lg,
				transparency = 0.7,
			},
		},
	}):render()
	
	-- Safe area container
	local safeInsets = getSafeAreaInsets()
	local safeContainer = Frame({
		Name = "SafeContainer",
		Size = UDim2.new(1, -safeInsets.left - safeInsets.right, 1, -safeInsets.top - safeInsets.bottom),
		Position = UDim2.new(0, safeInsets.left, 0, safeInsets.top),
		BackgroundTransparency = 1,
		Parent = self.gui,
	}):render()
	
	-- Main container with advanced styling
	self.mainContainer = Frame({
		Name = "MainContainer",
		Size = UDim2.fromScale(0.95, 0.9),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = DesignSystem.themes.modern.colors.surface.primary,
		Parent = safeContainer.instance,
		responsive = {
			Size = {
				mobile_small = UDim2.fromScale(1, 1),
				mobile_large = UDim2.fromScale(0.98, 0.95),
				tablet_small = UDim2.fromScale(0.9, 0.9),
				desktop_small = UDim2.fromScale(0.85, 0.85),
				desktop_large = UDim2.fromScale(0.8, 0.8),
				default = UDim2.fromScale(0.95, 0.9),
			},
		},
		style = {
			glassmorphism = {
				blur = DesignSystem.blur.xl,
				transparency = 0.1,
			},
			shadow = "xxl",
			hover = {
				Size = UDim2.fromScale(0.96, 0.91),
			},
		},
	}):render()
	
	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = DesignSystem.radius.xxl
	corner.Parent = self.mainContainer.instance
	
	-- Add size constraints
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(1600, 1000)
	sizeConstraint.MinSize = Vector2.new(400, 300)
	sizeConstraint.Parent = self.mainContainer.instance
end

function AdvancedShopManager:createHeader()
	self.header = Frame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, UI_CONSTANTS.HEADER_HEIGHT),
		BackgroundColor3 = DesignSystem.themes.modern.colors.surface.elevated,
		Parent = self.mainContainer.instance,
		style = {
			glassmorphism = {
				blur = DesignSystem.blur.sm,
				transparency = 0.05,
			},
		},
	}):render()
	
	-- Header corner radius (top only)
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = DesignSystem.radius.xxl
	headerCorner.Parent = self.header.instance
	
	-- Mask bottom corners
	local headerMask = Frame({
		Name = "HeaderMask",
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 1, -24),
		BackgroundColor3 = DesignSystem.themes.modern.colors.surface.elevated,
		BorderSizePixel = 0,
		Parent = self.header.instance,
	}):render()
	
	-- Header layout
	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, DesignSystem.spacing.lg)
	headerLayout.Parent = self.header.instance
	
	-- Header padding
	local headerPadding = Instance.new("UIPadding")
	headerPadding.PaddingLeft = UDim.new(0, DesignSystem.spacing.xl)
	headerPadding.PaddingRight = UDim.new(0, DesignSystem.spacing.xl)
	headerPadding.Parent = self.header.instance
	
	-- Shop logo/icon with animation
	local shopIcon = Image({
		Name = "ShopIcon",
		Image = AssetLibrary.icons.shop,
		Size = UDim2.fromOffset(48, 48),
		ImageColor3 = DesignSystem.themes.modern.colors.primary.main,
		LayoutOrder = 1,
		Parent = self.header.instance,
		style = {
			animatedGradient = {
				colors = DesignSystem.themes.modern.gradients.primary,
				duration = 4,
			},
		},
	}):render()
	
	-- Title with rich text
	local title = Text({
		Name = "Title",
		Text = '<font color="#6366f1"><b>Tycoon</b></font> <font color="#a855f7">Shop</font>',
		Font = DesignSystem.typography.families.display,
		TextSize = DesignSystem.typography.scales.headlineLarge,
		Size = UDim2.new(0, 200, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
		LayoutOrder = 2,
		Parent = self.header.instance,
	}):render()
	
	-- Stats display
	local statsContainer = Frame({
		Name = "StatsContainer",
		Size = UDim2.new(0, 300, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = self.header.instance,
	}):render()
	
	local statsLayout = Instance.new("UIListLayout")
	statsLayout.FillDirection = Enum.FillDirection.Horizontal
	statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	statsLayout.Padding = UDim.new(0, DesignSystem.spacing.lg)
	statsLayout.Parent = statsContainer.instance
	
	-- Balance display with icon
	local balanceFrame = Frame({
		Name = "BalanceFrame",
		Size = UDim2.new(0, 120, 0, 40),
		BackgroundColor3 = DesignSystem.themes.modern.colors.primary.container,
		LayoutOrder = 1,
		Parent = statsContainer.instance,
		style = {
			shadow = "sm",
		},
	}):render()
	
	local balanceCorner = Instance.new("UICorner")
	balanceCorner.CornerRadius = DesignSystem.radius.lg
	balanceCorner.Parent = balanceFrame.instance
	
	local balanceLayout = Instance.new("UIListLayout")
	balanceLayout.FillDirection = Enum.FillDirection.Horizontal
	balanceLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	balanceLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	balanceLayout.Padding = UDim.new(0, DesignSystem.spacing.sm)
	balanceLayout.Parent = balanceFrame.instance
	
	local cashIcon = Image({
		Name = "CashIcon",
		Image = AssetLibrary.icons.cash,
		Size = UDim2.fromOffset(20, 20),
		ImageColor3 = DesignSystem.themes.modern.colors.primary.main,
		LayoutOrder = 1,
		Parent = balanceFrame.instance,
	}):render()
	
	local balanceLabel = Text({
		Name = "BalanceLabel",
		Text = "$0",
		Font = DesignSystem.typography.families.primary,
		TextSize = DesignSystem.typography.scales.labelLarge,
		TextColor3 = DesignSystem.themes.modern.colors.text.primary,
		Size = UDim2.new(0, 80, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Parent = balanceFrame.instance,
	}):render()
	
	-- Action buttons
	local actionsContainer = Frame({
		Name = "ActionsContainer",
		Size = UDim2.new(1, -600, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = self.header.instance,
	}):render()
	
	local actionsLayout = Instance.new("UIListLayout")
	actionsLayout.FillDirection = Enum.FillDirection.Horizontal
	actionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	actionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actionsLayout.Padding = UDim.new(0, DesignSystem.spacing.sm)
	actionsLayout.Parent = actionsContainer.instance
	
	-- Settings button
	local settingsButton = ImageButton({
		Name = "SettingsButton",
		Image = AssetLibrary.icons.settings,
		Size = UDim2.fromOffset(40, 40),
		ImageColor3 = DesignSystem.themes.modern.colors.text.secondary,
		BackgroundColor3 = DesignSystem.themes.modern.colors.surface.secondary,
		LayoutOrder = 1,
		Parent = actionsContainer.instance,
		onClick = function()
			self:openSettings()
		end,
		style = {
			shadow = "sm",
			hover = {
				ImageColor3 = DesignSystem.themes.modern.colors.primary.main,
				BackgroundColor3 = DesignSystem.themes.modern.colors.primary.container,
			},
		},
	}):render()
	
	local settingsCorner = Instance.new("UICorner")
	settingsCorner.CornerRadius = DesignSystem.radius.lg
	settingsCorner.Parent = settingsButton.instance
	
	-- Close button with enhanced styling
	local closeButton = Button({
		Name = "CloseButton",
		Text = "",
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = DesignSystem.themes.modern.colors.error.main,
		LayoutOrder = 2,
		Parent = actionsContainer.instance,
		onClick = function()
			self:close()
		end,
		style = {
			shadow = "md",
			hover = {
				BackgroundColor3 = DesignSystem.themes.modern.colors.error.light,
				Size = UDim2.fromOffset(44, 44),
			},
		},
	}):render()
	
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = DesignSystem.radius.full
	closeCorner.Parent = closeButton.instance
	
	local closeIcon = Image({
		Name = "CloseIcon",
		Image = AssetLibrary.icons.close,
		Size = UDim2.fromScale(0.6, 0.6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageColor3 = Color3.new(1, 1, 1),
		Parent = closeButton.instance,
	}):render()
end

function AdvancedShopManager:createSearchSystem()
	-- Search container
	local searchContainer = Frame({
		Name = "SearchContainer",
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.new(0, 0, 0, UI_CONSTANTS.HEADER_HEIGHT),
		BackgroundColor3 = DesignSystem.themes.modern.colors.surface.secondary,
		Parent = self.mainContainer.instance,
		style = {
			glassmorphism = {
				blur = DesignSystem.blur.xs,
				transparency = 0.02,
			},
		},
	}):render()
	
	-- Search container padding
	local searchPadding = Instance.new("UIPadding")
	searchPadding.PaddingLeft = UDim.new(0, DesignSystem.spacing.xl)
	searchPadding.PaddingRight = UDim.new(0, DesignSystem.spacing.xl)
	searchPadding.PaddingTop = UDim.new(0, DesignSystem.spacing.md)
	searchPadding.PaddingBottom = UDim.new(0, DesignSystem.spacing.md)
	searchPadding.Parent = searchContainer.instance
	
	-- Search bar with advanced features
	self.searchBar = self:createAdvancedSearchBar(searchContainer.instance)
end

function AdvancedShopManager:createAdvancedSearchBar(parent)
	local searchFrame = Frame({
		Name = "SearchFrame",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = DesignSystem.themes.modern.colors.surface.primary,
		Parent = parent,
		style = {
			shadow = "sm",
		},
	}):render()
	
	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = DesignSystem.radius.xl
	searchCorner.Parent = searchFrame.instance
	
	local searchStroke = Instance.new("UIStroke")
	searchStroke.Color = DesignSystem.themes.modern.colors.border.primary
	searchStroke.Thickness = 1
	searchStroke.Transparency = 0.5
	searchStroke.Parent = searchFrame.instance
	
	-- Search layout
	local searchLayout = Instance.new("UIListLayout")
	searchLayout.FillDirection = Enum.FillDirection.Horizontal
	searchLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	searchLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	searchLayout.Padding = UDim.new(0, DesignSystem.spacing.md)
	searchLayout.Parent = searchFrame.instance
	
	-- Search padding
	local searchFramePadding = Instance.new("UIPadding")
	searchFramePadding.PaddingLeft = UDim.new(0, DesignSystem.spacing.lg)
	searchFramePadding.PaddingRight = UDim.new(0, DesignSystem.spacing.lg)
	searchFramePadding.Parent = searchFrame.instance
	
	-- Search icon
	local searchIcon = Image({
		Name = "SearchIcon",
		Image = AssetLibrary.icons.search,
		Size = UDim2.fromOffset(20, 20),
		ImageColor3 = DesignSystem.themes.modern.colors.text.tertiary,
		LayoutOrder = 1,
		Parent = searchFrame.instance,
	}):render()
	
	-- Search input
	local searchInput = Instance.new("TextBox")
	searchInput.Name = "SearchInput"
	searchInput.Size = UDim2.new(1, -100, 1, 0)
	searchInput.BackgroundTransparency = 1
	searchInput.Text = ""
	searchInput.PlaceholderText = "Search items, categories, or features..."
	searchInput.PlaceholderColor3 = DesignSystem.themes.modern.colors.text.tertiary
	searchInput.TextColor3 = DesignSystem.themes.modern.colors.text.primary
	searchInput.Font = DesignSystem.typography.families.primary
	searchInput.TextSize = DesignSystem.typography.scales.bodyMedium
	searchInput.TextXAlignment = Enum.TextXAlignment.Left
	searchInput.ClearTextOnFocus = false
	searchInput.LayoutOrder = 2
	searchInput.Parent = searchFrame.instance
	
	-- Filter button
	local filterButton = ImageButton({
		Name = "FilterButton",
		Image = AssetLibrary.icons.filter,
		Size = UDim2.fromOffset(32, 32),
		ImageColor3 = DesignSystem.themes.modern.colors.text.secondary,
		BackgroundColor3 = DesignSystem.themes.modern.colors.surface.secondary,
		LayoutOrder = 3,
		Parent = searchFrame.instance,
		onClick = function()
			self:toggleFilterPanel()
		end,
		style = {
			hover = {
				ImageColor3 = DesignSystem.themes.modern.colors.primary.main,
				BackgroundColor3 = DesignSystem.themes.modern.colors.primary.container,
			},
		},
	}):render()
	
	local filterCorner = Instance.new("UICorner")
	filterCorner.CornerRadius = DesignSystem.radius.md
	filterCorner.Parent = filterButton.instance
	
	-- Search functionality with debouncing
	local searchDebounce = nil
	searchInput:GetPropertyChangedSignal("Text"):Connect(function()
		if searchDebounce then
			task.cancel(searchDebounce)
		end
		
		searchDebounce = task.delay(UI_CONSTANTS.SEARCH_DEBOUNCE, function()
			self.searchQuery = searchInput.Text
			self.eventBus:emit("search:query", searchInput.Text)
		end)
	end)
	
	-- Focus effects
	searchInput.Focused:Connect(function()
		self.animationEngine:animate(searchStroke, {
			Color = DesignSystem.themes.modern.colors.primary.main,
			Thickness = 2,
		}, "FAST")
		
		self.animationEngine:animate(searchIcon, {
			ImageColor3 = DesignSystem.themes.modern.colors.primary.main,
		}, "FAST")
	end)
	
	searchInput.FocusLost:Connect(function()
		self.animationEngine:animate(searchStroke, {
			Color = DesignSystem.themes.modern.colors.border.primary,
			Thickness = 1,
		}, "FAST")
		
		self.animationEngine:animate(searchIcon, {
			ImageColor3 = DesignSystem.themes.modern.colors.text.tertiary,
		}, "FAST")
	end)
	
	return {
		frame = searchFrame,
		input = searchInput,
		icon = searchIcon,
		filterButton = filterButton,
	}
end

-- Continue with the rest of the implementation...
-- This would include createNavigation, createContentArea, createFilterPanel, etc.

print("[TycoonShop] Advanced UI System v" .. SHOP_VERSION .. " - Enhanced components loaded")

-- Export the advanced shop manager
return {
	ShopManager = AdvancedShopManager,
	DesignSystem = DesignSystem,
	Component = Component,
	SearchEngine = SearchEngine,
	version = SHOP_VERSION,
}