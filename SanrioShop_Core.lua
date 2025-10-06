--[[
    SANRIO SHOP - CORE MODULE
    Place this as a ModuleScript inside CreateMoneyShop LocalScript
    Name: SanrioShop_Core
--]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")

local Player = Players.LocalPlayer

local Core = {}

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
local productCache = Cache.new(300)
local ownershipCache = Cache.new(60)

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

function Core.Utils.deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			copy[k] = Core.Utils.deepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
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

-- Sound System
Core.SoundSystem = {}

function Core.SoundSystem.initialize()
	local sounds = {
		click = {id = "rbxassetid://876939830", volume = 0.4},
		hover = {id = "rbxassetid://10066936758", volume = 0.2},
		open = {id = "rbxassetid://9113651986", volume = 0.5},
		close = {id = "rbxassetid://9113651910", volume = 0.5},
		success = {id = "rbxassetid://9113647847", volume = 0.6},
		error = {id = "rbxassetid://9113647521", volume = 0.5},
		notification = {id = "rbxassetid://9113881312", volume = 0.5},
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
			description = "A small boost to get you started",
			icon = "rbxassetid://14978146073",
			featured = false,
		},
		{
			id = 1897730373,
			amount = 5000,
			name = "Growth Bundle",
			description = "Perfect for mid-game expansion",
			icon = "rbxassetid://14978146182",
			featured = true,
		},
		{
			id = 1897730467,
			amount = 10000,
			name = "Premium Package",
			description = "Accelerate your progress significantly",
			icon = "rbxassetid://14978146297",
			featured = false,
		},
		{
			id = 1897730581,
			amount = 50000,
			name = "Ultimate Bundle",
			description = "Maximum value for serious players",
			icon = "rbxassetid://14978146412",
			featured = true,
		},
	},
	gamepasses = {
		{
			id = 1412171840,
			name = "Auto Collect",
			description = "Automatically collect all cash drops",
			icon = "rbxassetid://14978147123",
			price = 99,
			hasToggle = true,
		},
		{
			id = 1398974710,
			name = "2x Cash",
			description = "Double all cash earned permanently",
			icon = "rbxassetid://14978147234",
			price = 199,
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

return Core
