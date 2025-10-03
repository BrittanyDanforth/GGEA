--[[
  TYCOON SHOP — MODERN CUTE EDITION (LocalScript)
  Place in: StarterPlayer > StarterPlayerScripts

  Goals
  - Clean, modern-cute aesthetic (pastels, rounded, light depth) — not futuristic
  - Mobile-first, scale-based layout; no card clipping; AutomaticCanvasSize for scroll
  - Two sections: Cash Packs (up to 10 tiers) and Game Passes (Auto Collect, 2x Cash)
  - Gamepass ownership reflect + elegant toggle for Auto Collect (in Settings or Card)
  - Minimal distractions: no emoji spam, optional hero banner, clear close control
  - Purchase logic preserved; prices loaded via MarketplaceService:GetProductInfo
  - Safe client: no outbound HTTP; only Marketplace + your own remotes

  Key Bindings
  - M or controller X to toggle
  - ESC or X button in header to close

  Server Remotes (create in ReplicatedStorage > TycoonRemotes):
  - RemoteEvent  : GrantProductCurrency(productId) — server grants currency for dev products
  - RemoteEvent  : GamepassPurchased(passId)      — optional server confirm after purchase
  - RemoteEvent  : AutoCollectToggle(state:boolean)
  - RemoteFunction: GetAutoCollectState() -> boolean

  Notes
  - Replace ICON_* asset ids with your own
  - Replace PRODUCT / PASS ids with your actual ids
  - Test on multiple devices using Device Emulator
]]

-- Services ------------------------------------------------------------------
local Players               = game:GetService("Players")
local MarketplaceService    = game:GetService("MarketplaceService")
local TweenService          = game:GetService("TweenService")
local UserInputService      = game:GetService("UserInputService")
local GuiService            = game:GetService("GuiService")
local ReplicatedStorage     = game:GetService("ReplicatedStorage")
local Lighting              = game:GetService("Lighting")
local RunService            = game:GetService("RunService")
local SoundService          = game:GetService("SoundService")
local Debris                = game:GetService("Debris")

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)

-- Core / Config --------------------------------------------------------------
local Core = {}
Core.VERSION = "5.0.0"
Core.DEBUG   = false

Core.CONSTANTS = {
	ANIM_FAST   = 0.12,
	ANIM_MED    = 0.22,
	ANIM_SLOW   = 0.35,
	PURCHASE_TIMEOUT = 15,
	REFRESH_INTERVAL = 30,
	CACHE_TTL_PRICE = 300,
	CACHE_TTL_OWNERSHIP = 60,
}

Core.State = {
	isOpen = false,
	isAnimating = false,
	currentTab = "Cash",
	purchasePending = {},
	initialized = false,
	settings = {
		animationsEnabled = true,
		soundEnabled = true,
	},
	viewportSize = Vector2.new(1920, 1080),
	safeInsets = {top = 0, bottom = 0, left = 0, right = 0},
	gridColumns = 3,
}

-- Simple Event Bus -----------------------------------------------------------
Core.Events = { _handlers = {} }
function Core.Events:on(name, callback)
	self._handlers[name] = self._handlers[name] or {}
	table.insert(self._handlers[name], callback)
	return function()
		local handlers = self._handlers[name]
		if not handlers then return end
		local index = table.find(handlers, callback)
		if index then table.remove(handlers, index) end
	end
end
function Core.Events:emit(name, ...)
	local handlers = self._handlers[name]
	if not handlers then return end
	for _, callback in ipairs(handlers) do 
		task.spawn(callback, ...) 
	end
end

-- Cache (time-based) ---------------------------------------------------------
local Cache = {}
Cache.__index = Cache
function Cache.new(ttl)
	return setmetatable({ ttl = ttl or 300, data = {} }, Cache)
end
function Cache:set(key, value)
	self.data[key] = { value = value, time = os.clock() }
end
function Cache:get(key)
	local entry = self.data[key]
	if not entry then return nil end
	if os.clock() - entry.time > self.ttl then 
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

local productCache   = Cache.new(Core.CONSTANTS.CACHE_TTL_PRICE)
local ownershipCache = Cache.new(Core.CONSTANTS.CACHE_TTL_OWNERSHIP)

-- Utils ----------------------------------------------------------------------
local Utils = {}
function Utils.isConsole()
	return GuiService:IsTenFootInterface()
end
function Utils.isSmallViewport()
	local camera = workspace.CurrentCamera
	if not camera then return false end
	local viewport = camera.ViewportSize
	return viewport.X < 1024 or Utils.isConsole()
end
function Utils.getViewportSize()
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1920, 1080)
end
function Utils.getGridColumns()
	local width = Utils.getViewportSize().X
	if width < 600 then return 1
	elseif width < 950 then return 2
	else return 3 end
end
function Utils.clamp(value, min, max)
	if value < min then return min end
	if value > max then return max end
	return value
end
function Utils.formatNumber(num)
	local str = tostring(num)
	local result, replacements
	repeat 
		str, replacements = str:gsub("^(%-?%d+)(%d%d%d)", "%1,%2") 
	until replacements == 0
	return str
end
function Utils.applyPadding(instance, padding)
	if not padding then return end
	local uiPadding = Instance.new("UIPadding")
	if padding.top    then uiPadding.PaddingTop    = padding.top    end
	if padding.bottom then uiPadding.PaddingBottom = padding.bottom end
	if padding.left   then uiPadding.PaddingLeft   = padding.left   end
	if padding.right  then uiPadding.PaddingRight  = padding.right  end
	uiPadding.Parent = instance
end
function Utils.debounce(func, delay)
	local lastCall = 0
	return function(...)
		local now = os.clock()
		if now - lastCall < delay then return end
		lastCall = now
		return func(...)
	end
end
function Utils.getSafeInsets()
	local insets = GuiService:GetGuiInset()
	return {
		top = insets.Y,
		bottom = 0,
		left = 0,
		right = 0
	}
end

-- Theme (Modern Cute) --------------------------------------------------------
local Theme = {
	palette = {
		bg          = Color3.fromRGB(252, 250, 248),
		surface     = Color3.fromRGB(255, 255, 255),
		surfaceAlt  = Color3.fromRGB(248, 245, 252),
		stroke      = Color3.fromRGB(226, 218, 224),
		text        = Color3.fromRGB(44, 40, 56),
		text2       = Color3.fromRGB(118, 110, 134),
		mint        = Color3.fromRGB(180, 226, 216),  -- cash accent
		mintDark    = Color3.fromRGB(148, 194, 184),
		lav         = Color3.fromRGB(208, 198, 255),  -- pass accent
		lavDark     = Color3.fromRGB(176, 166, 223),
		sky         = Color3.fromRGB(188, 216, 255),
		warn        = Color3.fromRGB(247, 203, 122),
		ok          = Color3.fromRGB(127, 196, 146),
		danger      = Color3.fromRGB(255, 122, 142),
		shadow      = Color3.fromRGB(200, 190, 210),
	},
	
	corner = {
		small  = UDim.new(0, 8),
		medium = UDim.new(0, 12),
		large  = UDim.new(0, 16),
		xlarge = UDim.new(0, 20),
		round  = UDim.new(1, 0),
	},
	
	padding = {
		tiny   = 4,
		small  = 8,
		medium = 12,
		large  = 16,
		xlarge = 24,
	},
	
	font = {
		regular   = Enum.Font.Gotham,
		medium    = Enum.Font.GothamMedium,
		semibold  = Enum.Font.GothamSemibold,
		bold      = Enum.Font.GothamBold,
	},
	
	textSize = {
		small   = 14,
		regular = 16,
		medium  = 18,
		large   = 20,
		xlarge  = 24,
		title   = 28,
	}
}

-- Sound Manager --------------------------------------------------------------
local SoundManager = {}
SoundManager.sounds = {}

function SoundManager:preload()
	local soundIds = {
		click = "rbxassetid://876939830",
		hover = "rbxassetid://12221967",
		purchase = "rbxassetid://203785492",
		open = "rbxassetid://9113880610",
		close = "rbxassetid://9113881154",
	}
	
	for name, id in pairs(soundIds) do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = 0.1
		sound.Parent = SoundService
		self.sounds[name] = sound
	end
end

function SoundManager:play(name)
	if not Core.State.settings.soundEnabled then return end
	local sound = self.sounds[name]
	if sound then sound:Play() end
end

SoundManager:preload()

-- UI Factory -----------------------------------------------------------------
local UI = {}

local Component = {}
Component.__index = Component
function Component.new(className, props)
	local self = setmetatable({}, Component)
	self.instance = Instance.new(className)
	self.props = props or {}
	self.connections = {}
	self.children = {}
	return self
end

local function applyVisuals(instance, props)
	if props.corner then
		local uiCorner = Instance.new("UICorner")
		uiCorner.CornerRadius = props.corner
		uiCorner.Parent = instance
	end
	if props.stroke then
		local uiStroke = Instance.new("UIStroke")
		uiStroke.Color = props.stroke.Color or Theme.palette.stroke
		uiStroke.Thickness = props.stroke.Thickness or 1
		uiStroke.Transparency = props.stroke.Transparency or 0.25
		uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		uiStroke.Parent = instance
	end
	if props.padding then 
		Utils.applyPadding(instance, props.padding) 
	end
	if props.gradient then
		local uiGradient = Instance.new("UIGradient")
		for key, value in pairs(props.gradient) do 
			pcall(function() uiGradient[key] = value end) 
		end
		uiGradient.Parent = instance
	end
	if props.shadow and props.shadow.enabled then
		-- Create shadow effect with layered frames
		local shadowFrame = Instance.new("Frame")
		shadowFrame.Name = "Shadow"
		shadowFrame.BackgroundColor3 = props.shadow.Color or Theme.palette.shadow
		shadowFrame.BackgroundTransparency = props.shadow.Transparency or 0.85
		shadowFrame.Size = UDim2.new(1, props.shadow.Spread or 4, 1, props.shadow.Spread or 4)
		shadowFrame.Position = UDim2.new(0, props.shadow.OffsetX or 2, 0, props.shadow.OffsetY or 2)
		shadowFrame.ZIndex = instance.ZIndex - 1
		shadowFrame.Parent = instance.Parent
		
		if props.corner then
			local shadowCorner = Instance.new("UICorner")
			shadowCorner.CornerRadius = props.corner
			shadowCorner.Parent = shadowFrame
		end
		
		instance.Parent = instance.Parent -- Re-parent to ensure correct z-order
	end
	if props.aspectRatio then
		local uiAspect = Instance.new("UIAspectRatioConstraint")
		uiAspect.AspectRatio = props.aspectRatio
		if props.dominantAxis then
			uiAspect.DominantAxis = props.dominantAxis
		end
		uiAspect.Parent = instance
	end
end

function Component:render()
	for key, value in pairs(self.props) do
		local skipKeys = {
			"children", "parent", "onClick", "onHover", "onLeave", 
			"corner", "stroke", "padding", "gradient", "shadow", "aspectRatio",
			"dominantAxis"
		}
		if not table.find(skipKeys, key) then
			pcall(function() self.instance[key] = value end)
		end
	end
	
	applyVisuals(self.instance, self.props)
	
	if self.props.onClick and self.instance:IsA("GuiButton") then
		table.insert(self.connections, self.instance.MouseButton1Click:Connect(function()
			SoundManager:play("click")
			self.props.onClick()
		end))
	end
	
	if self.props.onHover and (self.instance:IsA("GuiButton") or self.instance:IsA("GuiObject")) then
		table.insert(self.connections, self.instance.MouseEnter:Connect(function()
			SoundManager:play("hover")
			self.props.onHover()
		end))
	end
	
	if self.props.onLeave and (self.instance:IsA("GuiButton") or self.instance:IsA("GuiObject")) then
		table.insert(self.connections, self.instance.MouseLeave:Connect(self.props.onLeave))
	end
	
	if self.props.children then
		for _, child in ipairs(self.props.children) do
			if typeof(child) == "table" and child.render then
				child:render()
				child.instance.Parent = self.instance
				table.insert(self.children, child)
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
	for _, connection in ipairs(self.connections) do 
		connection:Disconnect() 
	end
	for _, child in ipairs(self.children) do
		if child.destroy then child:destroy() end
	end
	self.instance:Destroy()
end

function UI.Frame(props)
	props = props or {}
	if props.BackgroundColor3 == nil then props.BackgroundColor3 = Theme.palette.surface end
	if props.BorderSizePixel == nil then props.BorderSizePixel = 0 end
	return Component.new("Frame", props)
end

function UI.Text(props)
	props = props or {}
	if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
	if props.TextColor3 == nil then props.TextColor3 = Theme.palette.text end
	if props.Font == nil then props.Font = Theme.font.regular end
	if props.TextWrapped == nil then props.TextWrapped = true end
	if props.TextSize == nil then props.TextSize = Theme.textSize.regular end
	return Component.new("TextLabel", props)
end

function UI.Button(props)
	props = props or {}
	if props.BackgroundColor3 == nil then props.BackgroundColor3 = Theme.palette.mint end
	if props.TextColor3 == nil then props.TextColor3 = Color3.new(1,1,1) end
	if props.Font == nil then props.Font = Theme.font.medium end
	if props.AutoButtonColor == nil then props.AutoButtonColor = false end
	if props.Size == nil then props.Size = UDim2.fromOffset(140, 44) end
	if props.TextSize == nil then props.TextSize = Theme.textSize.medium end
	return Component.new("TextButton", props)
end

function UI.Image(props)
	props = props or {}
	if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
	if props.ScaleType == nil then props.ScaleType = Enum.ScaleType.Fit end
	return Component.new("ImageLabel", props)
end

function UI.Scroll(props)
	props = props or {}
	if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
	if props.BorderSizePixel == nil then props.BorderSizePixel = 0 end
	if props.ScrollBarThickness == nil then props.ScrollBarThickness = 6 end
	if props.ScrollBarImageColor3 == nil then props.ScrollBarImageColor3 = Theme.palette.stroke end
	if props.ScrollBarImageTransparency == nil then props.ScrollBarImageTransparency = 0.5 end
	if props.Size == nil then props.Size = UDim2.fromScale(1,1) end
	if props.CanvasSize == nil then props.CanvasSize = UDim2.new(0,0,0,0) end
	if props.AutomaticCanvasSize == nil then props.AutomaticCanvasSize = Enum.AutomaticSize.Y end
	return Component.new("ScrollingFrame", props)
end

-- Tween Helper ---------------------------------------------------------------
local function tween(object, properties, duration, style, direction)
	if not Core.State.settings.animationsEnabled then
		for key, value in pairs(properties) do 
			object[key] = value 
		end
		return
	end
	local tweenInfo = TweenInfo.new(
		duration or Core.CONSTANTS.ANIM_MED, 
		style or Enum.EasingStyle.Quad, 
		direction or Enum.EasingDirection.Out
	)
	local tweenObj = TweenService:Create(object, tweenInfo, properties)
	tweenObj:Play()
	return tweenObj
end

-- Data Manager ---------------------------------------------------------------
local Data = {}

-- Replace with your own icons
local ICON_CASH = "rbxassetid://18420350532"  -- placeholder coin icon
local ICON_PASS = "rbxassetid://18420350433"  -- placeholder badge icon
local ICON_SHOP = "rbxassetid://17398522865"  -- placeholder shop logo
local ICON_CLOSE = "rbxassetid://7400468522" -- close icon
local ICON_CHECK = "rbxassetid://9753762469" -- checkmark

-- Your actual product/pass ids here
local PASS_AUTO_COLLECT = 1412171840
local PASS_2X_CASH      = 1398974710

Data.products = {
	cash = {
		{ id = 1897730242, amount = 1_000,    name = "Starter Pouch",     description = "Kickstart your tycoon upgrades.", icon = ICON_CASH },
		{ id = 1897730373, amount = 5_000,    name = "Festival Bundle",   description = "Dress up your production floors.", icon = ICON_CASH },
		{ id = 1897730467, amount = 10_000,   name = "Showcase Chest",    description = "Unlock premium tycoon wings.", icon = ICON_CASH },
		{ id = 1897730581, amount = 50_000,   name = "Grand Vault",       description = "Full expansion funding package.", icon = ICON_CASH },
		{ id = 1234567001, amount = 100_000,  name = "Mega Safe",         description = "Major tycoon transformation fund.", icon = ICON_CASH },
		{ id = 1234567002, amount = 250_000,  name = "Quarter Million",   description = "Serious business investment pack.", icon = ICON_CASH },
		{ id = 1234567003, amount = 500_000,  name = "Half Million",      description = "Fast-track your empire builds.", icon = ICON_CASH },
		{ id = 1234567004, amount = 1_000_000,name = "Millionaire Pack",  description = "Dominate the tycoon leaderboard.", icon = ICON_CASH },
		{ id = 1234567005, amount = 5_000_000,name = "Tycoon Titan",      description = "Complete your empire instantly.", icon = ICON_CASH },
		{ id = 1234567006, amount = 10_000_000,name="Ultimate Vault",     description = "Max out everything at once.", icon = ICON_CASH },
	},
	gamepasses = {
		{ id = PASS_AUTO_COLLECT, name = "Auto Collect", description = "Hands-free register sweep every minute.", icon = ICON_PASS, hasToggle = true },
		{ id = PASS_2X_CASH,      name = "2x Cash",      description = "Double every sale forever.",         icon = ICON_PASS, hasToggle = false },
	}
}

function Data.getProductInfo(productId)
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

function Data.getPassInfo(passId)
	local cached = productCache:get("pass_"..passId)
	if cached then return cached end
	
	local success, info = pcall(function()
		return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
	end)
	
	if success and info then 
		productCache:set("pass_"..passId, info) 
		return info 
	end
	return nil
end

function Data.refreshPrices()
	for _, product in ipairs(Data.products.cash) do
		local info = Data.getProductInfo(product.id)
		if info then 
			product.price = info.PriceInRobux or 0 
		end
	end
	for _, gamepass in ipairs(Data.products.gamepasses) do
		local info = Data.getPassInfo(gamepass.id)
		if info then 
			gamepass.price = info.PriceInRobux or gamepass.price or 0 
		end
	end
end

function Data.userOwnsPass(passId)
	local key = Player.UserId .. ":" .. passId
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

-- Shop UI -------------------------------------------------------------------
local Shop = {}
Shop.__index = Shop

local shop -- forward declaration

function Shop.new()
	local self = setmetatable({}, Shop)
	self.gui        = nil
	self.blur       = nil
	self.panel      = nil
	self.header     = nil
	self.nav        = nil
	self.content    = nil
	self.pages      = {}
	self.tabButtons = {}
	self.autoToggleInSettings = nil
	self.connections = {}
	self.refreshTimer = nil
	
	self:build()
	self:connectInputs()
	self:setupResponsive()
	
	Core.State.initialized = true
	Core.Events:emit("shopInitialized")
	return self
end

-- Backdrop & Shell -----------------------------------------------------------
function Shop:createGui()
	local gui = PlayerGui:FindFirstChild("TycoonShopUI")
	if gui then gui:Destroy() end
	
	gui = Instance.new("ScreenGui")
	gui.Name = "TycoonShopUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.IgnoreGuiInset = false
	gui.Enabled = false
	gui.Parent = PlayerGui
	
	-- Dim background with gradient vignette
	local dim = UI.Frame({
		Name = "Dim",
		Size = UDim2.fromScale(1,1),
		BackgroundColor3 = Color3.new(0,0,0),
		BackgroundTransparency = 0.3,
		parent = gui
	}):render()
	
	-- Vignette gradient
	local vignetteGradient = Instance.new("UIGradient")
	vignetteGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 0.8)
	})
	vignetteGradient.Parent = dim
	
	-- Apply safe insets
	local safeInsets = Utils.getSafeInsets()
	Core.State.safeInsets = safeInsets
	
	-- Main Panel wrapper (for safe area padding)
	local panelWrapper = UI.Frame({
		Name = "PanelWrapper",
		Size = UDim2.new(1, 0, 1, -safeInsets.top),
		Position = UDim2.new(0, 0, 0, safeInsets.top),
		BackgroundTransparency = 1,
		parent = gui
	}):render()
	
	-- Main Panel (scale-based size)
	self.panel = UI.Frame({
		Name = "Panel",
		Size = UDim2.new(0.9, 0, 0.85, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.palette.surface,
		corner = Theme.corner.xlarge,
		stroke = { 
			Color = Theme.palette.stroke, 
			Thickness = 2,
			Transparency = 0.5 
		},
		shadow = {
			enabled = true,
			Color = Theme.palette.shadow,
			Transparency = 0.9,
			OffsetX = 0,
			OffsetY = 4,
			Spread = 8
		},
		parent = panelWrapper
	}):render()
	
	-- Size constraints
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(1200, 800)
	sizeConstraint.MinSize = Vector2.new(400, 500)
	sizeConstraint.Parent = self.panel
	
	-- Aspect ratio for ultra-wide screens
	local aspectRatio = Instance.new("UIAspectRatioConstraint")
	aspectRatio.AspectRatio = 1.5
	aspectRatio.AspectType = Enum.AspectType.ScaleWithParentSize
	aspectRatio.DominantAxis = Enum.DominantAxis.Height
	aspectRatio.Parent = self.panel
	
	-- Blur world subtly on open
	self.blur = Lighting:FindFirstChild("ShopBlur")
	if self.blur then self.blur:Destroy() end
	
	self.blur = Instance.new("BlurEffect")
	self.blur.Name = "ShopBlur"
	self.blur.Size = 0
	self.blur.Parent = Lighting
	
	self.gui = gui
end

-- Header ---------------------------------------------------------------------
function Shop:createHeader()
	self.header = UI.Frame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundColor3 = Theme.palette.surfaceAlt,
		corner = Theme.corner.xlarge,
		parent = self.panel
	}):render()
	
	-- Only round top corners
	local headerMask = UI.Frame({
		Name = "HeaderMask",
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -20),
		BackgroundColor3 = Theme.palette.surfaceAlt,
		BorderSizePixel = 0,
		parent = self.header
	}):render()
	
	Utils.applyPadding(self.header, { 
		left = UDim.new(0, Theme.padding.xlarge), 
		right = UDim.new(0, Theme.padding.xlarge) 
	})
	
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, Theme.padding.medium)
	layout.Parent = self.header
	
	-- Logo/Icon
	local logo = UI.Image({
		Image = ICON_SHOP,
		Size = UDim2.fromOffset(44, 44),
		ScaleType = Enum.ScaleType.Fit,
		LayoutOrder = 1,
		parent = self.header
	}):render()
	
	-- Title
	local title = UI.Text({
		Text = "Tycoon Shop",
		Font = Theme.font.bold,
		TextSize = Theme.textSize.title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -140, 1, 0),
		LayoutOrder = 2,
		parent = self.header
	}):render()
	
	-- Close Button
	local closeBtn = UI.Button({
		Text = "",
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Theme.palette.danger,
		TextColor3 = Color3.new(1,1,1),
		Font = Theme.font.bold,
		TextSize = Theme.textSize.xlarge,
		AutoButtonColor = false,
		corner = Theme.corner.round,
		LayoutOrder = 3,
		parent = self.header,
		onClick = function() self:close() end
	}):render()
	
	-- Close icon
	local closeIcon = UI.Image({
		Image = ICON_CLOSE,
		Size = UDim2.fromScale(0.6, 0.6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageColor3 = Color3.new(1,1,1),
		ScaleType = Enum.ScaleType.Fit,
		parent = closeBtn
	}):render()
	
	-- Close button hover effect
	closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, {BackgroundColor3 = Color3.fromRGB(235, 102, 122)}, Core.CONSTANTS.ANIM_FAST)
		tween(closeBtn, {Size = UDim2.fromOffset(48, 48)}, Core.CONSTANTS.ANIM_FAST, Enum.EasingStyle.Back)
	end)
	closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, {BackgroundColor3 = Theme.palette.danger}, Core.CONSTANTS.ANIM_FAST)
		tween(closeBtn, {Size = UDim2.fromOffset(44, 44)}, Core.CONSTANTS.ANIM_FAST)
	end)
end

-- Navigation -----------------------------------------------------------------
function Shop:createNav()
	local isSmallScreen = Utils.isSmallViewport()
	
	self.nav = UI.Frame({
		Name = "Nav",
		Size = isSmallScreen and UDim2.new(1, -32, 0, 60) or UDim2.new(0, 220, 1, -88),
		Position = isSmallScreen and UDim2.fromOffset(16, 80) or UDim2.fromOffset(16, 80),
		BackgroundColor3 = Theme.palette.surfaceAlt,
		corner = Theme.corner.large,
		stroke = { 
			Color = Theme.palette.stroke, 
			Thickness = 1,
			Transparency = 0.6 
		},
		parent = self.panel
	}):render()
	
	local list = Instance.new("UIListLayout")
	list.FillDirection = isSmallScreen and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	list.HorizontalAlignment = isSmallScreen and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, Theme.padding.small)
	list.Parent = self.nav
	
	Utils.applyPadding(self.nav, {
		top = UDim.new(0, Theme.padding.medium), 
		bottom = UDim.new(0, Theme.padding.medium), 
		left = UDim.new(0, Theme.padding.medium), 
		right = UDim.new(0, Theme.padding.medium)
	})
	
	local tabs = {
		{ id = "Cash",       name = "Cash Packs",   icon = ICON_CASH, accent = Theme.palette.mint },
		{ id = "Gamepasses", name = "Game Passes",  icon = ICON_PASS, accent = Theme.palette.lav },
	}
	
	for _, tab in ipairs(tabs) do
		local button = UI.Button({
			Text = "",
			Size = isSmallScreen and UDim2.new(0.5, -6, 1, 0) or UDim2.new(1, 0, 0, 54),
			BackgroundColor3 = Theme.palette.surface,
			TextColor3 = Theme.palette.text,
			Font = Theme.font.semibold,
			TextSize = Theme.textSize.medium,
			AutoButtonColor = false,
			corner = Theme.corner.medium,
			parent = self.nav,
			onClick = function() self:selectTab(tab.id) end
		}):render()
		
		-- Tab content layout
		local tabLayout = Instance.new("UIListLayout")
		tabLayout.FillDirection = Enum.FillDirection.Horizontal
		tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		tabLayout.Padding = UDim.new(0, Theme.padding.small)
		tabLayout.Parent = button
		
		-- Tab icon
		local icon = UI.Image({
			Image = tab.icon,
			Size = UDim2.fromOffset(24, 24),
			ImageColor3 = Theme.palette.text2,
			LayoutOrder = 1,
			parent = button
		}):render()
		
		-- Tab text
		local text = UI.Text({
			Text = tab.name,
			Font = Theme.font.semibold,
			TextSize = Theme.textSize.medium,
			TextColor3 = Theme.palette.text2,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = 2,
			parent = button
		}):render()
		text.Size = UDim2.new(0, text.TextBounds.X, 1, 0)
		
		-- Hover / active feedback
		button.MouseEnter:Connect(function()
			if Core.State.currentTab ~= tab.id then
				tween(button, {BackgroundColor3 = Color3.new(0.95, 0.95, 0.95)}, Core.CONSTANTS.ANIM_FAST)
				tween(icon, {ImageColor3 = tab.accent}, Core.CONSTANTS.ANIM_FAST)
				tween(text, {TextColor3 = tab.accent}, Core.CONSTANTS.ANIM_FAST)
			end
		end)
		button.MouseLeave:Connect(function()
			local isActive = Core.State.currentTab == tab.id
			tween(button, {BackgroundColor3 = isActive and tab.accent or Theme.palette.surface}, Core.CONSTANTS.ANIM_FAST)
			tween(icon, {ImageColor3 = isActive and Color3.new(1,1,1) or Theme.palette.text2}, Core.CONSTANTS.ANIM_FAST)
			tween(text, {TextColor3 = isActive and Color3.new(1,1,1) or Theme.palette.text2}, Core.CONSTANTS.ANIM_FAST)
		end)
		
		self.tabButtons[tab.id] = {
			button = button, 
			icon = icon,
			text = text,
			accent = tab.accent
		}
	end
end

-- Content Root ---------------------------------------------------------------
function Shop:createContent()
	local isSmallScreen = Utils.isSmallViewport()
	
	self.content = UI.Frame({
		Name = "Content",
		BackgroundTransparency = 1,
		Size = isSmallScreen and UDim2.new(1, -32, 1, -160) or UDim2.new(1, -252, 1, -96),
		Position = isSmallScreen and UDim2.fromOffset(16, 148) or UDim2.fromOffset(244, 88),
		parent = self.panel
	}):render()
	
	-- Pages
	self.pages.Cash       = self:createCashPage(self.content)
	self.pages.Gamepasses = self:createPassPage(self.content)
	
	self:selectTab(Core.State.currentTab)
end

-- Cash Page ------------------------------------------------------------------
function Shop:createCashPage(parent)
	local page = UI.Frame({ 
		Name = "CashPage", 
		BackgroundTransparency = 1, 
		Size = UDim2.fromScale(1,1), 
		parent = parent 
	}):render()
	
	-- Header strip
	local header = UI.Frame({ 
		Size = UDim2.new(1, 0, 0, 56), 
		BackgroundColor3 = Theme.palette.surfaceAlt, 
		corner = Theme.corner.medium,
		stroke = { 
			Color = Theme.palette.mint, 
			Thickness = 2,
			Transparency = 0.7 
		},
		parent = page 
	}):render()
	
	Utils.applyPadding(header, { 
		left = UDim.new(0, Theme.padding.large), 
		right = UDim.new(0, Theme.padding.large) 
	})
	
	-- Header content
	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, Theme.padding.medium)
	headerLayout.Parent = header
	
	UI.Image({ 
		Image = ICON_CASH, 
		Size = UDim2.fromOffset(32, 32),
		ImageColor3 = Theme.palette.mint,
		LayoutOrder = 1,
		parent = header 
	}):render()
	
	UI.Text({ 
		Text = "Cash Packs", 
		Font = Theme.font.bold, 
		TextSize = Theme.textSize.xlarge, 
		TextColor3 = Theme.palette.text,
		Size = UDim2.new(0.5, 0, 1, 0), 
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2, 
		parent = header 
	}):render()
	
	-- Player balance (optional - requires your currency system)
	local balanceText = UI.Text({ 
		Text = "Balance: $0", 
		Font = Theme.font.semibold, 
		TextSize = Theme.textSize.medium,
		TextColor3 = Theme.palette.text2,
		Size = UDim2.new(0, 200, 1, 0), 
		TextXAlignment = Enum.TextXAlignment.Right,
		LayoutOrder = 3,
		parent = header 
	}):render()
	
	-- Scroll grid
	local scroll = UI.Scroll({
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.new(1, 0, 1, -68),
		Position = UDim2.fromOffset(0, 64),
		parent = page
	}):render()
	
	Utils.applyPadding(scroll, {
		top = UDim.new(0, Theme.padding.small),
		bottom = UDim.new(0, Theme.padding.small),
		left = UDim.new(0, Theme.padding.small),
		right = UDim.new(0, Theme.padding.small)
	})
	
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellPadding = UDim2.fromOffset(Theme.padding.medium, Theme.padding.medium)
	grid.CellSize = UDim2.new(1/3, -Theme.padding.medium, 0, 220)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.FillDirectionMaxCells = Core.State.gridColumns
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroll
	
	page.grid = grid -- Store reference for responsive updates
	
	for index, product in ipairs(Data.products.cash) do
		self:createCashCard(product, scroll, index)
	end
	
	return page
end

function Shop:createCashCard(product, parent, order)
	local card = UI.Frame({
		Name = product.name .. "Card",
		BackgroundColor3 = Theme.palette.surface,
		corner = Theme.corner.large,
		stroke = { 
			Color = Theme.palette.mint, 
			Thickness = 2,
			Transparency = 0.8 
		},
		shadow = {
			enabled = true,
			Color = Theme.palette.mint,
			Transparency = 0.95,
			OffsetY = 2,
			Spread = 4
		},
		parent = parent
	}):render()
	card.LayoutOrder = order
	
	-- Card inner padding
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.new(1, -Theme.padding.large * 2, 1, -Theme.padding.large * 2)
	inner.Position = UDim2.fromOffset(Theme.padding.large, Theme.padding.large)
	inner.Parent = card
	
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, Theme.padding.small)
	layout.Parent = inner
	
	-- Icon container
	local iconContainer = UI.Frame({
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Theme.palette.mint,
		BackgroundTransparency = 0.9,
		corner = Theme.corner.medium,
		parent = inner
	}):render()
	
	local icon = UI.Image({ 
		Image = product.icon or ICON_CASH, 
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageColor3 = Theme.palette.mintDark,
		parent = iconContainer 
	}):render()
	
	-- Product name
	local name = UI.Text({ 
		Text = product.name, 
		Font = Theme.font.bold, 
		TextSize = Theme.textSize.large, 
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
		parent = inner 
	}):render()
	
	-- Description
	local desc = UI.Text({ 
		Text = product.description or "", 
		TextColor3 = Theme.palette.text2, 
		TextSize = Theme.textSize.small,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 32),
		parent = inner 
	}):render()
	
	-- Price and amount
	local priceText = string.format("R$%s", tostring(product.price or 0))
	local price = UI.Text({ 
		Text = priceText, 
		Font = Theme.font.semibold, 
		TextSize = Theme.textSize.xlarge, 
		TextColor3 = Theme.palette.mintDark,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 28),
		parent = inner 
	}):render()
	
	local amount = UI.Text({ 
		Text = Utils.formatNumber(product.amount) .. " Cash", 
		Font = Theme.font.medium, 
		TextSize = Theme.textSize.small, 
		TextColor3 = Theme.palette.text2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18),
		parent = inner 
	}):render()
	
	-- Purchase button
	local button = UI.Button({
		Text = "Purchase",
		BackgroundColor3 = Theme.palette.mint,
		TextColor3 = Color3.new(1,1,1),
		Font = Theme.font.bold,
		TextSize = Theme.textSize.medium,
		Size = UDim2.new(1, 0, 0, 42),
		corner = Theme.corner.medium,
		parent = inner,
		onClick = Utils.debounce(function() 
			self:promptPurchase(product, "product") 
		end, 1)
	}):render()
	
	-- Hover effects
	local isHovered = false
	card.MouseEnter:Connect(function()
		if Utils.isSmallViewport() then return end
		isHovered = true
		tween(card, {BackgroundColor3 = Theme.palette.surfaceAlt}, Core.CONSTANTS.ANIM_FAST)
		tween(icon, {Size = UDim2.fromOffset(52, 52)}, Core.CONSTANTS.ANIM_FAST, Enum.EasingStyle.Back)
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			tween(stroke, {Transparency = 0.5}, Core.CONSTANTS.ANIM_FAST)
		end
	end)
	card.MouseLeave:Connect(function()
		isHovered = false
		tween(card, {BackgroundColor3 = Theme.palette.surface}, Core.CONSTANTS.ANIM_FAST)
		tween(icon, {Size = UDim2.fromOffset(48, 48)}, Core.CONSTANTS.ANIM_FAST)
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			tween(stroke, {Transparency = 0.8}, Core.CONSTANTS.ANIM_FAST)
		end
	end)
	
	-- Pulse animation for featured items
	if order <= 3 then
		task.spawn(function()
			while card.Parent do
				if not isHovered then
					local stroke = card:FindFirstChildOfClass("UIStroke")
					if stroke then
						tween(stroke, {Transparency = 0.6}, 1.5, Enum.EasingStyle.Sine)
						task.wait(1.5)
						tween(stroke, {Transparency = 0.8}, 1.5, Enum.EasingStyle.Sine)
						task.wait(1.5)
					end
				else
					task.wait(0.5)
				end
			end
		end)
	end
	
	product._card = card
	product._priceLabel = price
	product._buyButton = button
end

-- Game Pass Page -------------------------------------------------------------
function Shop:createPassPage(parent)
	local page = UI.Frame({ 
		Name = "PassPage", 
		BackgroundTransparency = 1, 
		Size = UDim2.fromScale(1,1), 
		parent = parent 
	}):render()
	
	-- Header
	local header = UI.Frame({ 
		Size = UDim2.new(1, 0, 0, 56), 
		BackgroundColor3 = Theme.palette.surfaceAlt, 
		corner = Theme.corner.medium,
		stroke = { 
			Color = Theme.palette.lav, 
			Thickness = 2,
			Transparency = 0.7 
		},
		parent = page 
	}):render()
	
	Utils.applyPadding(header, { 
		left = UDim.new(0, Theme.padding.large), 
		right = UDim.new(0, Theme.padding.large) 
	})
	
	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, Theme.padding.medium)
	headerLayout.Parent = header
	
	UI.Image({ 
		Image = ICON_PASS, 
		Size = UDim2.fromOffset(32, 32),
		ImageColor3 = Theme.palette.lav,
		LayoutOrder = 1,
		parent = header 
	}):render()
	
	UI.Text({ 
		Text = "Game Passes", 
		Font = Theme.font.bold, 
		TextSize = Theme.textSize.xlarge,
		TextColor3 = Theme.palette.text,
		Size = UDim2.new(0.5, 0, 1, 0), 
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		parent = header 
	}):render()
	
	-- Content wrapper
	local contentWrapper = UI.Frame({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -64),
		Position = UDim2.fromOffset(0, 64),
		parent = page
	}):render()
	
	-- Passes grid
	local passesContainer = UI.Frame({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -88),
		parent = contentWrapper
	}):render()
	
	Utils.applyPadding(passesContainer, {
		top = UDim.new(0, Theme.padding.small),
		bottom = UDim.new(0, Theme.padding.small),
		left = UDim.new(0, Theme.padding.small),
		right = UDim.new(0, Theme.padding.small)
	})
	
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellPadding = UDim2.fromOffset(Theme.padding.large, Theme.padding.large)
	grid.CellSize = UDim2.new(0.5, -Theme.padding.large/2, 0, 240)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Top
	grid.Parent = passesContainer
	
	for index, pass in ipairs(Data.products.gamepasses) do
		self:createPassCard(pass, passesContainer, index)
	end
	
	-- Settings area
	local settings = UI.Frame({
		Name = "Settings",
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundColor3 = Theme.palette.surfaceAlt,
		corner = Theme.corner.medium,
		Position = UDim2.new(0, 0, 1, -80),
		parent = contentWrapper
	}):render()
	
	Utils.applyPadding(settings, { 
		left = UDim.new(0, Theme.padding.large), 
		right = UDim.new(0, Theme.padding.large) 
	})
	
	local settingsLayout = Instance.new("UIListLayout")
	settingsLayout.FillDirection = Enum.FillDirection.Horizontal
	settingsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	settingsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	settingsLayout.Padding = UDim.new(0, Theme.padding.medium)
	settingsLayout.Parent = settings
	
	UI.Text({ 
		Text = "Quick Settings", 
		Font = Theme.font.semibold, 
		TextSize = Theme.textSize.medium,
		TextColor3 = Theme.palette.text,
		Size = UDim2.new(0.5, 0, 1, 0), 
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		parent = settings 
	}):render()
	
	-- Auto-collect toggle
	self.autoToggleInSettings = self:createToggle(
		settings, 
		"Auto Collect", 
		false,
		function(state)
			if Remotes then
				local event = Remotes:FindFirstChild("AutoCollectToggle")
				if event and event:IsA("RemoteEvent") then 
					event:FireServer(state) 
				end
			end
		end
	)
	self.autoToggleInSettings.LayoutOrder = 2
	
	-- Check initial state and ownership
	local ownsAuto = Data.userOwnsPass(PASS_AUTO_COLLECT)
	self.autoToggleInSettings.Visible = ownsAuto
	
	if ownsAuto and Remotes then
		local remoteFunc = Remotes:FindFirstChild("GetAutoCollectState")
		if remoteFunc and remoteFunc:IsA("RemoteFunction") then
			local success, state = pcall(function() 
				return remoteFunc:InvokeServer() 
			end)
			if success and typeof(state) == "boolean" then 
				self:setToggle(self.autoToggleInSettings, state) 
			end
		end
	end
	
	return page
end

function Shop:createPassCard(pass, parent, order)
	local card = UI.Frame({
		Name = pass.name .. "Card",
		BackgroundColor3 = Theme.palette.surface,
		corner = Theme.corner.large,
		stroke = { 
			Color = Theme.palette.lav, 
			Thickness = 2,
			Transparency = 0.8 
		},
		shadow = {
			enabled = true,
			Color = Theme.palette.lav,
			Transparency = 0.95,
			OffsetY = 2,
			Spread = 4
		},
		parent = parent
	}):render()
	card.LayoutOrder = order
	
	-- Card inner
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.new(1, -Theme.padding.xlarge * 2, 1, -Theme.padding.xlarge * 2)
	inner.Position = UDim2.fromOffset(Theme.padding.xlarge, Theme.padding.xlarge)
	inner.Parent = card
	
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, Theme.padding.medium)
	layout.Parent = inner
	
	-- Icon container
	local iconContainer = UI.Frame({
		Size = UDim2.new(1, 0, 0, 80),
		BackgroundColor3 = Theme.palette.lav,
		BackgroundTransparency = 0.9,
		corner = Theme.corner.medium,
		parent = inner
	}):render()
	
	local icon = UI.Image({ 
		Image = pass.icon or ICON_PASS, 
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageColor3 = Theme.palette.lavDark,
		parent = iconContainer 
	}):render()
	
	-- Pass name
	local name = UI.Text({ 
		Text = pass.name, 
		Font = Theme.font.bold, 
		TextSize = Theme.textSize.xlarge, 
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 28),
		parent = inner 
	}):render()
	
	-- Description
	local desc = UI.Text({ 
		Text = pass.description or "", 
		TextColor3 = Theme.palette.text2, 
		TextSize = Theme.textSize.regular,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 36),
		parent = inner 
	}):render()
	
	-- Price
	local priceText = string.format("R$%s", tostring(pass.price or 0))
	local price = UI.Text({ 
		Text = priceText, 
		Font = Theme.font.semibold, 
		TextSize = Theme.textSize.xlarge, 
		TextColor3 = Theme.palette.lavDark,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 28),
		parent = inner 
	}):render()
	
	-- Purchase button
	local button = UI.Button({
		Text = "Purchase",
		BackgroundColor3 = Theme.palette.lav,
		TextColor3 = Color3.new(1,1,1),
		Font = Theme.font.bold,
		TextSize = Theme.textSize.medium,
		Size = UDim2.new(1, 0, 0, 44),
		corner = Theme.corner.medium,
		parent = inner,
		onClick = Utils.debounce(function() 
			self:promptPurchase(pass, "gamepass") 
		end, 1)
	}):render()
	
	-- Check ownership
	local owned = Data.userOwnsPass(pass.id)
	self:updatePassVisual(pass, owned, button, card)
	
	-- Optional inline toggle for Auto Collect
	if pass.id == PASS_AUTO_COLLECT and pass.hasToggle then
		local toggleWrapper = UI.Frame({
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 32),
			parent = inner
		}):render()
		
		local inlineToggle = self:createToggle(
			toggleWrapper, 
			"Enable", 
			false,
			function(state)
				if Remotes then
					local event = Remotes:FindFirstChild("AutoCollectToggle")
					if event and event:IsA("RemoteEvent") then 
						event:FireServer(state) 
					end
				end
				-- Sync with settings toggle
				if self.autoToggleInSettings and self.autoToggleInSettings.Visible then
					self:setToggle(self.autoToggleInSettings, state)
				end
			end
		)
		inlineToggle.Position = UDim2.fromScale(0.5, 0.5)
		inlineToggle.AnchorPoint = Vector2.new(0.5, 0.5)
		inlineToggle.Visible = owned
		
		pass._inlineToggle = inlineToggle
	end
	
	-- Hover effects
	local isHovered = false
	card.MouseEnter:Connect(function()
		if Utils.isSmallViewport() then return end
		isHovered = true
		tween(card, {BackgroundColor3 = Theme.palette.surfaceAlt}, Core.CONSTANTS.ANIM_FAST)
		tween(icon, {Size = UDim2.fromOffset(60, 60)}, Core.CONSTANTS.ANIM_FAST, Enum.EasingStyle.Back)
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			tween(stroke, {Transparency = 0.5}, Core.CONSTANTS.ANIM_FAST)
		end
	end)
	card.MouseLeave:Connect(function()
		isHovered = false
		tween(card, {BackgroundColor3 = Theme.palette.surface}, Core.CONSTANTS.ANIM_FAST)
		tween(icon, {Size = UDim2.fromOffset(56, 56)}, Core.CONSTANTS.ANIM_FAST)
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			tween(stroke, {Transparency = 0.8}, Core.CONSTANTS.ANIM_FAST)
		end
	end)
	
	pass._card = card
	pass._priceLabel = price
	pass._buyButton = button
end

function Shop:updatePassVisual(pass, owned, button, card)
	button = button or pass._buyButton
	card = card or pass._card
	if not button or not card then return end
	
	if owned then
		button.Text = "✓ Owned"
		button.Active = false
		button.BackgroundColor3 = Theme.palette.ok
		
		local checkIcon = UI.Image({
			Image = ICON_CHECK,
			Size = UDim2.fromOffset(20, 20),
			Position = UDim2.new(0, 8, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			ImageColor3 = Color3.new(1,1,1),
			parent = button
		}):render()
		
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then 
			stroke.Color = Theme.palette.ok 
			stroke.Transparency = 0.6
		end
		
		-- Show inline toggle if exists
		if pass._inlineToggle then
			pass._inlineToggle.Visible = true
		end
	else
		button.Text = "Purchase"
		button.Active = true
		button.BackgroundColor3 = Theme.palette.lav
		
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then 
			stroke.Color = Theme.palette.lav 
			stroke.Transparency = 0.8
		end
	end
end

-- Toggle (pill) --------------------------------------------------------------
function Shop:createToggle(parent, label, initial, onChange)
	local wrapper = Instance.new("Frame")
	wrapper.BackgroundTransparency = 1
	wrapper.Size = UDim2.fromOffset(140, 36)
	wrapper.Parent = parent
	
	-- Background
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromOffset(60, 30)
	bg.Position = UDim2.fromOffset(80, 3)
	bg.BackgroundColor3 = initial and Theme.palette.mint or Theme.palette.stroke
	bg.Parent = wrapper
	
	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(1, 0)
	bgCorner.Parent = bg
	
	-- Knob
	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(26, 26)
	knob.Position = initial and UDim2.fromOffset(32, 2) or UDim2.fromOffset(2, 2)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Parent = bg
	
	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob
	
	-- Shadow for knob
	local knobShadow = Instance.new("Frame")
	knobShadow.Size = UDim2.new(1, 2, 1, 2)
	knobShadow.Position = UDim2.fromOffset(1, 1)
	knobShadow.BackgroundColor3 = Color3.new(0, 0, 0)
	knobShadow.BackgroundTransparency = 0.8
	knobShadow.ZIndex = knob.ZIndex - 1
	knobShadow.Parent = knob
	
	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(1, 0)
	shadowCorner.Parent = knobShadow
	
	-- Label
	local labelText = UI.Text({ 
		Text = label or "Toggle", 
		TextColor3 = Theme.palette.text2, 
		TextSize = Theme.textSize.regular,
		Size = UDim2.fromOffset(75, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = wrapper 
	}):render()
	
	-- Button
	local button = Instance.new("TextButton")
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromScale(1, 1)
	button.Text = ""
	button.Parent = wrapper
	
	local state = initial and true or false
	local function updateVisual()
		tween(bg, {
			BackgroundColor3 = state and Theme.palette.mint or Theme.palette.stroke
		}, Core.CONSTANTS.ANIM_FAST)
		tween(knob, {
			Position = state and UDim2.fromOffset(32, 2) or UDim2.fromOffset(2, 2)
		}, Core.CONSTANTS.ANIM_FAST, Enum.EasingStyle.Back)
	end
	
	button.MouseButton1Click:Connect(function()
		state = not state
		updateVisual()
		SoundManager:play("click")
		if onChange then onChange(state) end
	end)
	
	updateVisual()
	wrapper:SetAttribute("_toggle_state", state)
	return wrapper
end

function Shop:setToggle(toggleWrapper, value)
	if not toggleWrapper then return end
	toggleWrapper:SetAttribute("_toggle_state", value)
	
	local bg = toggleWrapper:FindFirstChild("Frame")
	if not bg then return end
	local knob = bg:FindFirstChild("Frame")
	if not knob then return end
	
	bg.BackgroundColor3 = value and Theme.palette.mint or Theme.palette.stroke
	knob.Position = value and UDim2.fromOffset(32, 2) or UDim2.fromOffset(2, 2)
end

-- Build ----------------------------------------------------------------------
function Shop:build()
	self:createGui()
	self:createHeader()
	self:createNav()
	self:createContent()
	
	-- Initial data load
	Data.refreshPrices()
end

-- Open / Close ---------------------------------------------------------------
function Shop:open()
	if Core.State.isOpen or Core.State.isAnimating then return end
	Core.State.isAnimating = true
	Core.State.isOpen = true
	
	Data.refreshPrices()
	self:refreshVisuals()
	
	self.gui.Enabled = true
	SoundManager:play("open")
	
	-- Animations
	tween(self.blur, { Size = 24 }, Core.CONSTANTS.ANIM_MED)
	self.panel.Position = UDim2.fromScale(0.5, 0.55)
	self.panel.Size = UDim2.new(0.85, 0, 0.8, 0)
	tween(self.panel, { 
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.85, 0)
	}, Core.CONSTANTS.ANIM_SLOW, Enum.EasingStyle.Back)
	
	-- Stagger tab animations
	for _, tabData in pairs(self.tabButtons) do
		tabData.button.BackgroundTransparency = 1
		tween(tabData.button, {BackgroundTransparency = 0}, Core.CONSTANTS.ANIM_MED)
	end
	
	task.delay(Core.CONSTANTS.ANIM_SLOW, function()
		Core.State.isAnimating = false
		Core.Events:emit("shopOpened")
		
		-- Start refresh timer
		self.refreshTimer = task.spawn(function()
			while Core.State.isOpen do
				task.wait(Core.CONSTANTS.REFRESH_INTERVAL)
				if Core.State.isOpen then
					Data.refreshPrices()
					self:refreshVisuals()
				end
			end
		end)
	end)
end

function Shop:close()
	if not Core.State.isOpen or Core.State.isAnimating then return end
	Core.State.isAnimating = true
	Core.State.isOpen = false
	
	SoundManager:play("close")
	
	-- Cancel refresh timer
	if self.refreshTimer then
		task.cancel(self.refreshTimer)
		self.refreshTimer = nil
	end
	
	tween(self.blur, { Size = 0 }, Core.CONSTANTS.ANIM_FAST)
	tween(self.panel, { 
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.new(0.85, 0, 0.8, 0)
	}, Core.CONSTANTS.ANIM_FAST)
	
	task.delay(Core.CONSTANTS.ANIM_FAST, function()
		self.gui.Enabled = false
		Core.State.isAnimating = false
		Core.Events:emit("shopClosed")
	end)
end

function Shop:toggle()
	if Core.State.isOpen then 
		self:close() 
	else 
		self:open() 
	end
end

-- Select Tab -----------------------------------------------------------------
function Shop:selectTab(id)
	if Core.State.currentTab == id then
		for pageName, page in pairs(self.pages) do 
			page.Visible = (pageName == id) 
		end
		return
	end
	
	for tabName, data in pairs(self.tabButtons) do
		local isActive = (tabName == id)
		tween(data.button, {
			BackgroundColor3 = isActive and data.accent or Theme.palette.surface,
		}, Core.CONSTANTS.ANIM_FAST)
		tween(data.icon, {
			ImageColor3 = isActive and Color3.new(1,1,1) or Theme.palette.text2,
		}, Core.CONSTANTS.ANIM_FAST)
		tween(data.text, {
			TextColor3 = isActive and Color3.new(1,1,1) or Theme.palette.text2,
		}, Core.CONSTANTS.ANIM_FAST)
	end
	
	for pageName, page in pairs(self.pages) do 
		page.Visible = (pageName == id) 
	end
	
	Core.State.currentTab = id
	Core.Events:emit("tabChanged", id)
end

-- Refresh visuals (prices / ownership) ---------------------------------------
function Shop:refreshVisuals()
	ownershipCache:clear()
	
	-- Update gamepass visuals
	for _, pass in ipairs(Data.products.gamepasses) do
		local owned = Data.userOwnsPass(pass.id)
		self:updatePassVisual(pass, owned)
	end
	
	-- Update price labels for cash
	for _, product in ipairs(Data.products.cash) do
		if product._priceLabel then
			product._priceLabel.Text = string.format("R$%s", tostring(product.price or 0))
		end
	end
	
	-- Update settings toggle visibility
	local ownsAuto = Data.userOwnsPass(PASS_AUTO_COLLECT)
	if self.autoToggleInSettings then 
		self.autoToggleInSettings.Visible = ownsAuto 
	end
end

-- Purchase Flow --------------------------------------------------------------
function Shop:promptPurchase(item, kind)
	if kind == "gamepass" then
		if Data.userOwnsPass(item.id) then
			self:updatePassVisual(item, true)
			return
		end
		
		item._buyButton.Text = "Processing..."
		item._buyButton.Active = false
		Core.State.purchasePending[item.id] = { 
			item = item, 
			type = kind, 
			time = os.clock() 
		}
		
		local success = pcall(function()
			MarketplaceService:PromptGamePassPurchase(Player, item.id)
		end)
		
		if not success then
			item._buyButton.Text = "Purchase"
			item._buyButton.Active = true
			Core.State.purchasePending[item.id] = nil
		end
		
		-- Timeout fallback
		task.delay(Core.CONSTANTS.PURCHASE_TIMEOUT, function()
			if Core.State.purchasePending[item.id] then
				item._buyButton.Text = "Purchase"
				item._buyButton.Active = true
				Core.State.purchasePending[item.id] = nil
			end
		end)
	else -- dev product (cash)
		Core.State.purchasePending[item.id] = { 
			item = item, 
			type = kind, 
			time = os.clock() 
		}
		
		local success = pcall(function()
			MarketplaceService:PromptProductPurchase(Player, item.id)
		end)
		
		if not success then
			Core.State.purchasePending[item.id] = nil
		end
	end
end

-- Input ----------------------------------------------------------------------
function Shop:connectInputs()
	-- Keyboard
	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.M then 
			self:toggle() 
		end
		if input.KeyCode == Enum.KeyCode.Escape and Core.State.isOpen then 
			self:close() 
		end
	end))
	
	-- Gamepad
	if UserInputService.GamepadEnabled then
		table.insert(self.connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.KeyCode == Enum.KeyCode.ButtonX then 
				self:toggle() 
			end
		end))
	end
	
	-- Floating toggle button
	local toggleGui = PlayerGui:FindFirstChild("ShopToggle")
	if toggleGui then toggleGui:Destroy() end
	
	toggleGui = Instance.new("ScreenGui")
	toggleGui.Name = "ShopToggle"
	toggleGui.ResetOnSpawn = false
	toggleGui.DisplayOrder = 999
	toggleGui.Parent = PlayerGui
	
	local toggleButton = UI.Button({
		Text = "",
		BackgroundColor3 = Theme.palette.surface,
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.new(1, -80, 1, -80),
		AnchorPoint = Vector2.new(0.5, 0.5),
		corner = Theme.corner.round,
		stroke = {
			Color = Theme.palette.mint,
			Thickness = 2,
			Transparency = 0.7
		},
		shadow = {
			enabled = true,
			OffsetY = 3,
			Spread = 6
		},
		parent = toggleGui,
		onClick = function() self:toggle() end
	}):render()
	
	local buttonIcon = UI.Image({
		Image = ICON_SHOP,
		Size = UDim2.fromScale(0.6, 0.6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageColor3 = Theme.palette.mint,
		parent = toggleButton
	}):render()
	
	-- Hover effects
	toggleButton.MouseEnter:Connect(function()
		tween(toggleButton, {
			BackgroundColor3 = Theme.palette.mint,
			Size = UDim2.fromOffset(72, 72)
		}, Core.CONSTANTS.ANIM_FAST, Enum.EasingStyle.Back)
		tween(buttonIcon, {ImageColor3 = Color3.new(1,1,1)}, Core.CONSTANTS.ANIM_FAST)
	end)
	toggleButton.MouseLeave:Connect(function()
		tween(toggleButton, {
			BackgroundColor3 = Theme.palette.surface,
			Size = UDim2.fromOffset(64, 64)
		}, Core.CONSTANTS.ANIM_FAST)
		tween(buttonIcon, {ImageColor3 = Theme.palette.mint}, Core.CONSTANTS.ANIM_FAST)
	end)
	
	-- Floating animation
	task.spawn(function()
		while toggleButton.Parent do
			tween(toggleButton, {
				Position = UDim2.new(1, -80, 1, -85)
			}, 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(2)
			tween(toggleButton, {
				Position = UDim2.new(1, -80, 1, -75)
			}, 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(2)
		end
	end)
end

-- Responsive Design ----------------------------------------------------------
function Shop:setupResponsive()
	local function updateLayout()
		local viewportSize = Utils.getViewportSize()
		Core.State.viewportSize = viewportSize
		Core.State.gridColumns = Utils.getGridColumns()
		
		-- Update cash page grid
		local cashPage = self.pages.Cash
		if cashPage and cashPage.grid then
			cashPage.grid.FillDirectionMaxCells = Core.State.gridColumns
			
			-- Adjust cell size based on columns
			local cellWidth = 1 / Core.State.gridColumns
			cashPage.grid.CellSize = UDim2.new(
				cellWidth, 
				-Theme.padding.medium, 
				0, 
				Core.State.gridColumns == 1 and 260 or 220
			)
		end
		
		-- Update navigation layout for small screens
		local isSmallScreen = viewportSize.X < 768
		if self.nav then
			if isSmallScreen then
				-- Horizontal tabs for mobile
				self.nav.Size = UDim2.new(1, -32, 0, 60)
				self.nav.Position = UDim2.fromOffset(16, 80)
				
				local layout = self.nav:FindFirstChildOfClass("UIListLayout")
				if layout then
					layout.FillDirection = Enum.FillDirection.Horizontal
					layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				end
				
				-- Update tab button sizes
				for _, data in pairs(self.tabButtons) do
					data.button.Size = UDim2.new(0.5, -6, 1, 0)
				end
				
				-- Update content position
				if self.content then
					self.content.Size = UDim2.new(1, -32, 1, -160)
					self.content.Position = UDim2.fromOffset(16, 148)
				end
			else
				-- Vertical nav for desktop
				self.nav.Size = UDim2.new(0, 220, 1, -88)
				self.nav.Position = UDim2.fromOffset(16, 80)
				
				local layout = self.nav:FindFirstChildOfClass("UIListLayout")
				if layout then
					layout.FillDirection = Enum.FillDirection.Vertical
					layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
				end
				
				-- Update tab button sizes
				for _, data in pairs(self.tabButtons) do
					data.button.Size = UDim2.new(1, 0, 0, 54)
				end
				
				-- Update content position
				if self.content then
					self.content.Size = UDim2.new(1, -252, 1, -96)
					self.content.Position = UDim2.fromOffset(244, 88)
				end
			end
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

-- Marketplace Callbacks ------------------------------------------------------
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
	if player ~= Player then return end
	
	local pending = Core.State.purchasePending[passId]
	if not pending then return end
	
	Core.State.purchasePending[passId] = nil
	local item = pending.item
	
	if wasPurchased then
		ownershipCache:clear()
		
		-- Update visual
		if item and item._buyButton then
			item._buyButton.Text = "✓ Owned"
			item._buyButton.BackgroundColor3 = Theme.palette.ok
			item._buyButton.Active = false
		end
		
		-- Refresh all visuals
		if shop then 
			shop:refreshVisuals() 
		end
		
		-- Notify server
		if Remotes then
			local event = Remotes:FindFirstChild("GamepassPurchased")
			if event and event:IsA("RemoteEvent") then 
				event:FireServer(passId) 
			end
		end
		
		SoundManager:play("purchase")
	else
		if item and item._buyButton then 
			item._buyButton.Text = "Purchase"
			item._buyButton.Active = true 
		end
	end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, wasPurchased)
	if player ~= Player then return end
	
	local pending = Core.State.purchasePending[productId]
	if not pending then return end
	
	Core.State.purchasePending[productId] = nil
	
	if wasPurchased and Remotes then
		local grant = Remotes:FindFirstChild("GrantProductCurrency")
		if not grant then
			grant = Remotes:FindFirstChild("ProductGranted")
		end
		if grant and grant:IsA("RemoteEvent") then 
			grant:FireServer(productId) 
		end
		
		SoundManager:play("purchase")
	end
end)

-- Cleanup --------------------------------------------------------------------
function Shop:destroy()
	Core.State.isOpen = false
	
	if self.refreshTimer then
		task.cancel(self.refreshTimer)
	end
	
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	
	if self.blur then
		self.blur:Destroy()
	end
	
	if self.gui then
		self.gui:Destroy()
	end
	
	local toggleGui = PlayerGui:FindFirstChild("ShopToggle")
	if toggleGui then
		toggleGui:Destroy()
	end
end

-- Exposed API ----------------------------------------------------------------
function Core.OpenShop() 
	if shop then shop:open() end 
end

function Core.CloseShop() 
	if shop then shop:close() end 
end

function Core.ToggleShop() 
	if shop then shop:toggle() end 
end

-- Initialize -----------------------------------------------------------------
shop = Shop.new()

-- Character respawn handling
Player.CharacterAdded:Connect(function()
	task.wait(1)
	-- Ensure toggle button exists after respawn
	local toggleGui = PlayerGui:FindFirstChild("ShopToggle")
	if not toggleGui then 
		shop:connectInputs() 
	end
end)

-- Cleanup on leave
game:BindToClose(function()
	if shop then
		shop:destroy()
	end
end)

print("[TycoonShop] Modern Cute UI ready (v"..Core.VERSION..")")

return Core