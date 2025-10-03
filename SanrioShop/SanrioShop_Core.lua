--[[
    SANRIO SHOP SYSTEM - CORE MODULE
    Professional Shop System with Modern Architecture
    
    Features:
    - Modular design with clean separation of concerns
    - Advanced state management
    - Optimized performance with caching
    - Smooth animations and transitions
    - Full mobile support
    - Robust error handling
--]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Module Table
local SanrioShop = {
	VERSION = "3.0.0",
	DEBUG = false,
}

-- Constants
local CONSTANTS = {
	-- UI Sizing
	PANEL_SIZE = Vector2.new(1140, 860),
	PANEL_SIZE_MOBILE = Vector2.new(920, 720),
	CARD_SIZE = Vector2.new(520, 300),
	CARD_SIZE_MOBILE = Vector2.new(480, 280),

	-- Animation Timings
	ANIM_FAST = 0.15,
	ANIM_MEDIUM = 0.25,
	ANIM_SLOW = 0.35,
	ANIM_BOUNCE = 0.3,
	ANIM_SMOOTH = 0.4,

	-- Z-Index Layers
	Z_BACKGROUND = 1,
	Z_CONTENT = 10,
	Z_OVERLAY = 20,
	Z_MODAL = 30,
	Z_TOOLTIP = 40,
	Z_NOTIFICATION = 50,

	-- Cache Durations
	CACHE_PRODUCT_INFO = 300, -- 5 minutes
	CACHE_OWNERSHIP = 60, -- 1 minute

	-- Purchase Timeouts
	PURCHASE_TIMEOUT = 15,
	RETRY_DELAY = 2,
	MAX_RETRIES = 3,
}

-- State Management
local State = {
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
local Events = {
	handlers = {},
}

function Events:on(eventName, handler)
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

function Events:emit(eventName, ...)
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

-- Initialize caches
local productCache = Cache.new(CONSTANTS.CACHE_PRODUCT_INFO)
local ownershipCache = Cache.new(CONSTANTS.CACHE_OWNERSHIP)

-- Utility Functions
local Utils = {}

function Utils.isMobile()
	local camera = workspace.CurrentCamera
	if not camera then return false end
	local viewportSize = camera.ViewportSize
	return viewportSize.X < 1024 or GuiService:IsTenFootInterface()
end

function Utils.formatNumber(number)
	local formatted = tostring(number)
	local k = 1
	while k ~= 0 do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
	end
	return formatted
end

function Utils.lerp(a, b, t)
	return a + (b - a) * t
end

function Utils.clamp(value, min, max)
	return math.max(min, math.min(max, value))
end

function Utils.blend(a, b, alpha)
	alpha = Utils.clamp(alpha, 0, 1)
	return Color3.new(
		a.R + (b.R - a.R) * alpha,
		a.G + (b.G - a.G) * alpha,
		a.B + (b.B - a.B) * alpha
	)
end

function Utils.deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			copy[k] = Utils.deepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

function Utils.debounce(func, delay)
	local lastCall = 0
	return function(...)
		local now = tick()
		if now - lastCall < delay then return end
		lastCall = now
		return func(...)
	end
end

function Utils.throttle(func, delay)
	local lastCall = 0
	local args
	local scheduled = false

	local function callFunc()
		func(unpack(args))
		lastCall = tick()
		scheduled = false
	end

	return function(...)
		args = {...}
		local now = tick()
		local timeSinceLastCall = now - lastCall

		if timeSinceLastCall >= delay then
			callFunc()
		elseif not scheduled then
			scheduled = true
			task.wait(delay - timeSinceLastCall)
			callFunc()
		end
	end
end

-- Animation System
local Animation = {}

function Animation.tween(object, properties, duration, easingStyle, easingDirection)
	if not State.settings.animationsEnabled then
		for property, value in pairs(properties) do
			object[property] = value
		end
		return
	end

	duration = duration or CONSTANTS.ANIM_MEDIUM
	easingStyle = easingStyle or Enum.EasingStyle.Quad
	easingDirection = easingDirection or Enum.EasingDirection.Out

	local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection)
	local tween = TweenService:Create(object, tweenInfo, properties)
	tween:Play()
	return tween
end

function Animation.spring(object, properties, dampingRatio, frequency)
	dampingRatio = dampingRatio or 0.5
	frequency = frequency or 4

	local tweenInfo = TweenInfo.new(
		0.5,
		Enum.EasingStyle.Elastic,
		Enum.EasingDirection.Out,
		0,
		false,
		0
	)

	local tween = TweenService:Create(object, tweenInfo, properties)
	tween:Play()
	return tween
end

function Animation.sequence(animations)
	local function runNext(index)
		if index > #animations then return end

		local anim = animations[index]
		local tween = Animation.tween(
			anim.object,
			anim.properties,
			anim.duration,
			anim.easingStyle,
			anim.easingDirection
		)

		if tween then
			tween.Completed:Connect(function()
				runNext(index + 1)
			end)
		else
			runNext(index + 1)
		end
	end

	runNext(1)
end

-- Sound System
local SoundSystem = {}

function SoundSystem.initialize()
	-- Using working sound IDs
	local sounds = {
		click = {id = "rbxassetid://876939830", volume = 0.4},
		hover = {id = "rbxassetid://10066936758", volume = 0.2},
		open = {id = "rbxassetid://452267918", volume = 0.5},
		close = {id = "rbxassetid://452267918", volume = 0.5},
		success = {id = "rbxassetid://876939830", volume = 0.6},
		error = {id = "rbxassetid://876939830", volume = 0.5},
		notification = {id = "rbxassetid://876939830", volume = 0.5},
	}

	SoundSystem.sounds = {}

	for name, config in pairs(sounds) do
		local sound = Instance.new("Sound")
		sound.Name = "SanrioShop_" .. name
		sound.SoundId = config.id
		sound.Volume = config.volume
		sound.Parent = SoundService
		SoundSystem.sounds[name] = sound
	end
end

function SoundSystem.play(soundName)
	if not State.settings.soundEnabled then return end

	local sound = SoundSystem.sounds[soundName]
	if sound then
		sound:Play()
	end
end

-- Data Management
local DataManager = {}

DataManager.products = {
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

function DataManager.getProductInfo(productId)
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

function DataManager.getGamePassInfo(passId)
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

function DataManager.checkOwnership(passId)
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

function DataManager.refreshPrices()
	-- Update cash product prices
	for _, product in ipairs(DataManager.products.cash) do
		local info = DataManager.getProductInfo(product.id)
		if info then
			product.price = info.PriceInRobux or 0
		end
	end

	-- Update gamepass prices
	for _, pass in ipairs(DataManager.products.gamepasses) do
		local info = DataManager.getGamePassInfo(pass.id)
		if info and info.PriceInRobux then
			pass.price = info.PriceInRobux
		end
	end
end

-- Error Handler
local function handleError(context, err)
	warn("[SanrioShop]", context, "-", err)

	if SanrioShop.DEBUG then
		Events:emit("error", {
			context = context,
			error = err,
			timestamp = tick(),
		})
	end
end

-- Protected Call Wrapper
local function protectedCall(func, context)
	local success, result = pcall(func)
	if not success then
		handleError(context or "Unknown", result)
	end
	return success, result
end

-- Export Module
SanrioShop.CONSTANTS = CONSTANTS
SanrioShop.State = State
SanrioShop.Events = Events
SanrioShop.Cache = Cache
SanrioShop.Utils = Utils
SanrioShop.Animation = Animation
SanrioShop.SoundSystem = SoundSystem
SanrioShop.DataManager = DataManager
SanrioShop.handleError = handleError
SanrioShop.protectedCall = protectedCall

return SanrioShop
