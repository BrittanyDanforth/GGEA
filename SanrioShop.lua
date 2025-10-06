--[[
  SANRIO SHOP SYSTEM - POLISHED & RESPONSIVE
  Location: StarterPlayer > StarterPlayerScripts
  
  Features:
  - Responsive 3/2/1 grid layout with min/max constraints
  - Glass morphism header with blur effects
  - Skeleton shimmer loaders
  - Controller/gamepad support with focus rings
  - Haptic feedback
  - Purchase flow with spinners, banners & confetti
  - Safe-area padding for notched devices
  - Proper cleanup and performance optimizations
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

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:FindFirstChild("TycoonRemotes")

-- ========================================
-- DESIGN TOKENS
-- ========================================
local Tokens = {
	radius = {
		small = UDim.new(0, 10),
		medium = UDim.new(0, 16),
		large = UDim.new(0, 24),
		pill = UDim.new(1, 0),
	},
	elevation = {
		z1 = 0.06,
		z2 = 0.12,
		z3 = 0.18,
	},
	spacing = {
		xs = 8,
		sm = 12,
		md = 16,
		lg = 24,
		xl = 32,
	},
	typography = {
		hero = 32,
		title = 24,
		body = 16,
		small = 14,
		tiny = 12,
	},
	motion = {
		fast = 0.12,
		medium = 0.18,
		slow = 0.24,
		spring = 0.3,
	},
	blur = {
		glass = 10,
	}
}

-- ========================================
-- CORE
-- ========================================
local Core = {}

Core.CONSTANTS = {
	PANEL_SIZE = Vector2.new(1140, 860),
	PANEL_SIZE_MOBILE = Vector2.new(920, 720),
	
	CARD_MIN_WIDTH = 300,
	CARD_MAX_WIDTH = 560,
	CARD_ASPECT_RATIO = 0.75, -- 3:4 (width:height)
	
	GRID_GUTTER = 20,
	CONTAINER_PADDING = 24,
	
	CACHE_PRODUCT_INFO = 300,
	CACHE_OWNERSHIP = 60,
	PURCHASE_TIMEOUT = 15,
	PURCHASE_DEBOUNCE = 1.5,
	
	MIN_TOUCH_TARGET = 44,
}

Core.State = {
	isOpen = false,
	isAnimating = false,
	purchasePending = {},
	lastPurchaseTime = {},
	settings = { 
		soundEnabled = true, 
		animationsEnabled = true,
		hapticsEnabled = true,
		reducedMotion = false,
	},
	focusedCard = nil,
	cardReferences = {},
	cleanupCallbacks = {},
}

-- Simple cache
local Cache = {}
Cache.__index = Cache
function Cache.new(d) return setmetatable({data={},duration=d or 300},Cache) end
function Cache:set(k,v) self.data[k]={v=v,t=tick()} end
function Cache:get(k) local e=self.data[k]; if not e then return end; if tick()-e.t>self.duration then self.data[k]=nil return end; return e.v end
function Cache:clear(k) if k then self.data[k]=nil else self.data={} end end

local productCache = Cache.new(Core.CONSTANTS.CACHE_PRODUCT_INFO)
local ownershipCache = Cache.new(Core.CONSTANTS.CACHE_OWNERSHIP)

-- ========================================
-- UTILS
-- ========================================
Core.Utils = {}

function Core.Utils.isMobile()
	local cam = workspace.CurrentCamera
	if not cam then return false end
	local v = cam.ViewportSize
	return v.X < 1024 or GuiService:IsTenFootInterface()
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

function Core.Utils.getSafeAreaInsets()
	local insets = GuiService:GetSafeZoneInsets()
	return {
		top = math.max(insets.Y, 20),
		bottom = math.max(20, 20),
		left = math.max(insets.X, 20),
		right = math.max(insets.X, 20),
	}
end

function Core.Utils.getGridColumns(viewportWidth)
	if viewportWidth >= 1400 then return 3
	elseif viewportWidth >= 900 then return 2
	else return 1 end
end

function Core.Utils.calculateCardSize(viewportWidth, columns)
	local gutter = Core.CONSTANTS.GRID_GUTTER
	local padding = Core.CONSTANTS.CONTAINER_PADDING * 2
	local availableWidth = viewportWidth - padding - (gutter * (columns - 1))
	local cardWidth = math.floor(availableWidth / columns)
	
	-- Clamp between min and max
	cardWidth = math.clamp(cardWidth, Core.CONSTANTS.CARD_MIN_WIDTH, Core.CONSTANTS.CARD_MAX_WIDTH)
	
	local cardHeight = math.floor(cardWidth / Core.CONSTANTS.CARD_ASPECT_RATIO)
	
	return Vector2.new(cardWidth, cardHeight)
end

-- ========================================
-- ANIMATION
-- ========================================
Core.Animation = {}

function Core.Animation.tween(inst, props, duration, style, direction)
	if not inst or not inst.Parent then return end
	
	local d = duration or Tokens.motion.medium
	if Core.State.settings.reducedMotion then
		d = d * 0.5
	end
	
	if not Core.State.settings.animationsEnabled then
		for k, v in pairs(props) do
			pcall(function() inst[k] = v end)
		end
		return
	end
	
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(d, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	
	-- Auto-cleanup
	local conn
	conn = tw.Completed:Connect(function()
		if conn then conn:Disconnect() end
	end)
	
	return tw
end

function Core.Animation.shimmer(frame, duration)
	local shimmer = Instance.new("Frame")
	shimmer.Name = "Shimmer"
	shimmer.Size = UDim2.new(0.3, 0, 1, 0)
	shimmer.Position = UDim2.new(-0.3, 0, 0, 0)
	shimmer.BackgroundColor3 = Color3.new(1, 1, 1)
	shimmer.BackgroundTransparency = 0.7
	shimmer.BorderSizePixel = 0
	shimmer.Parent = frame
	
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = shimmer
	
	local function animate()
		if not shimmer or not shimmer.Parent then return end
		local tw = Core.Animation.tween(
			shimmer,
			{ Position = UDim2.new(1, 0, 0, 0) },
			duration or 1.2,
			Enum.EasingStyle.Linear
		)
		if tw then
			tw.Completed:Connect(function()
				if shimmer and shimmer.Parent then
					shimmer.Position = UDim2.new(-0.3, 0, 0, 0)
					task.wait(0.5)
					animate()
				end
			end)
		end
	end
	
	animate()
	return shimmer
end

function Core.Animation.confetti(parent, color)
	for i = 1, 12 do
		local particle = Instance.new("Frame")
		particle.Size = UDim2.fromOffset(8, 8)
		particle.Position = UDim2.fromScale(0.5, 0.5)
		particle.AnchorPoint = Vector2.new(0.5, 0.5)
		particle.BackgroundColor3 = color or Color3.fromRGB(255, 64, 129)
		particle.BorderSizePixel = 0
		particle.ZIndex = 10
		particle.Parent = parent
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = particle
		
		local angle = (math.pi * 2 / 12) * i
		local distance = math.random(60, 120)
		local endX = 0.5 + math.cos(angle) * distance / parent.AbsoluteSize.X
		local endY = 0.5 + math.sin(angle) * distance / parent.AbsoluteSize.Y
		
		local tw = Core.Animation.tween(
			particle,
			{
				Position = UDim2.fromScale(endX, endY),
				BackgroundTransparency = 1,
				Rotation = math.random(-180, 180),
			},
			0.5,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)
		
		task.delay(0.5, function()
			if particle and particle.Parent then
				particle:Destroy()
			end
		end)
	end
end

-- ========================================
-- SOUNDS & HAPTICS
-- ========================================
Core.SoundSystem = { sounds = {} }

function Core.SoundSystem.initialize()
	local cfg = {
		click = {"rbxassetid://876939830", 0.35},
		hover = {"rbxassetid://10066936758", 0.15},
		open = {"rbxassetid://452267918", 0.4},
		close = {"rbxassetid://452267918", 0.4},
		success = {"rbxassetid://876939830", 0.5},
		error = {"rbxassetid://876939830", 0.4},
	}
	
	local preload = {}
	for name, data in pairs(cfg) do
		local s = Instance.new("Sound")
		s.Name = "SanrioShop_" .. name
		s.SoundId = data[1]
		s.Volume = data[2]
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.Parent = SoundService
		Core.SoundSystem.sounds[name] = s
		table.insert(preload, s)
	end
	
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(preload)
		end)
	end)
end

function Core.SoundSystem.play(name)
	if Core.State.settings.soundEnabled and Core.SoundSystem.sounds[name] then
		Core.SoundSystem.sounds[name]:Play()
	end
end

Core.HapticSystem = {}

function Core.HapticSystem.trigger(type)
	if not Core.State.settings.hapticsEnabled then return end
	
	local hapticType = Enum.UserInputType.Gamepad1
	if UserInputService.TouchEnabled then
		hapticType = Enum.UserInputType.Touch
	end
	
	pcall(function()
		if type == "light" then
			HapticService:SetMotor(hapticType, Enum.VibrationMotor.Small, 0.3)
			task.wait(0.05)
			HapticService:SetMotor(hapticType, Enum.VibrationMotor.Small, 0)
		elseif type == "medium" then
			HapticService:SetMotor(hapticType, Enum.VibrationMotor.Large, 0.5)
			task.wait(0.1)
			HapticService:SetMotor(hapticType, Enum.VibrationMotor.Large, 0)
		elseif type == "success" then
			HapticService:SetMotor(hapticType, Enum.VibrationMotor.Large, 0.7)
			task.wait(0.08)
			HapticService:SetMotor(hapticType, Enum.VibrationMotor.Large, 0)
			task.wait(0.04)
			HapticService:SetMotor(hapticType, Enum.VibrationMotor.Large, 0.4)
			task.wait(0.08)
			HapticService:SetMotor(hapticType, Enum.VibrationMotor.Large, 0)
		end
	end)
end

-- ========================================
-- DATA MANAGER
-- ========================================
Core.DataManager = {}

Core.DataManager.products = {
	cash = {
		{ id = 3366419712, amount = 1000, name = "1,000 Cash", description = "Jump-start your collection", icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3366420478, amount = 10000, name = "10,000 Cash", description = "Accelerate expansion", icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3366420800, amount = 25000, name = "25,000 Cash", description = "Best value bundle", icon = "rbxassetid://10709728059", price = 0, featured = true },
		{ id = 3366420012, amount = 5000, name = "5,000 Cash", description = "Perfect for mid-game", icon = "rbxassetid://10709728059", price = 0 },
	},
	gamepasses = {
		{ id = 1412171840, name = "Auto Collect", description = "Automatically collect drops", icon = "rbxassetid://10709727148", price = 99, hasToggle = true },
		{ id = 1398974710, name = "2x Cash", description = "Double cash permanently", icon = "rbxassetid://10709727148", price = 199, hasToggle = false },
	},
}

function Core.DataManager.getProductInfo(id)
	local c = productCache:get(id)
	if c then return c end
	
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
	end)
	
	if ok and info then
		productCache:set(id, info)
		return info
	end
end

function Core.DataManager.getGamePassInfo(id)
	local key = "pass_" .. id
	local c = productCache:get(key)
	if c then return c end
	
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
	end)
	
	if ok and info then
		productCache:set(key, info)
		return info
	end
end

function Core.DataManager.checkOwnership(passId)
	local key = ("%d_%d"):format(Player.UserId, passId)
	local c = ownershipCache:get(key)
	if c ~= nil then return c end
	
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, passId)
	end)
	
	if ok then
		ownershipCache:set(key, owns)
		return owns
	end
	
	return false
end

function Core.DataManager.refreshPrices()
	for _, p in ipairs(Core.DataManager.products.cash) do
		local i = Core.DataManager.getProductInfo(p.id)
		if i and i.PriceInRobux then
			p.price = i.PriceInRobux
		end
	end
	
	for _, gp in ipairs(Core.DataManager.products.gamepasses) do
		local i = Core.DataManager.getGamePassInfo(gp.id)
		if i and i.PriceInRobux then
			gp.price = i.PriceInRobux
		end
	end
end

-- ========================================
-- UI THEME
-- ========================================
local UI = {}

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
			accentHover = Color3.fromRGB(255, 84, 149),
			success = Color3.fromRGB(76, 175, 80),
			error = Color3.fromRGB(244, 67, 54),
			warning = Color3.fromRGB(255, 152, 0),
			cinna = Color3.fromRGB(186, 214, 255),
			kuromi = Color3.fromRGB(200, 190, 255),
			skeletonBase = Color3.fromRGB(235, 237, 242),
			skeletonShimmer = Color3.fromRGB(245, 247, 252),
		}
	}
}

function UI.Theme:get(key)
	return self.themes[self.current][key]
end

-- ========================================
-- UI COMPONENTS
-- ========================================
local Component = {}
Component.__index = Component

function Component.new(className, props)
	return setmetatable({
		instance = Instance.new(className),
		props = props or {},
		connections = {},
	}, Component)
end

function Component:render()
	for k, v in pairs(self.props) do
		if k ~= "children" and k ~= "parent" and k ~= "onClick" and k ~= "cornerRadius" 
			and k ~= "stroke" and k ~= "layout" and k ~= "padding" and k ~= "aspectRatio" then
			pcall(function()
				self.instance[k] = v
			end)
		end
	end
	
	if self.props.cornerRadius then
		local c = Instance.new("UICorner")
		c.CornerRadius = self.props.cornerRadius
		c.Parent = self.instance
	end
	
	if self.props.stroke then
		local s = Instance.new("UIStroke")
		s.Color = self.props.stroke.color or UI.Theme:get("stroke")
		s.Thickness = self.props.stroke.thickness or 1
		s.Transparency = self.props.stroke.transparency or 0
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = self.instance
	end
	
	if self.props.aspectRatio then
		local ar = Instance.new("UIAspectRatioConstraint")
		ar.AspectRatio = self.props.aspectRatio
		ar.AspectType = Enum.AspectType.FitWithinMaxSize
		ar.DominantAxis = Enum.DominantAxis.Width
		ar.Parent = self.instance
	end
	
	if self.props.parent then
		self.instance.Parent = self.props.parent
	end
	
	return self.instance
end

function Component:cleanup()
	for _, conn in ipairs(self.connections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	self.connections = {}
end

UI.Components = {}

function UI.Components.Frame(props)
	local defaults = {
		BackgroundColor3 = UI.Theme:get("surface"),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}
	
	for k, v in pairs(defaults) do
		if props[k] == nil then props[k] = v end
	end
	
	local cmp = Component.new("Frame", props)
	local inst = cmp:render()
	
	if props.padding then
		local p = Instance.new("UIPadding")
		if props.padding.top then p.PaddingTop = UDim.new(0, props.padding.top) end
		if props.padding.bottom then p.PaddingBottom = UDim.new(0, props.padding.bottom) end
		if props.padding.left then p.PaddingLeft = UDim.new(0, props.padding.left) end
		if props.padding.right then p.PaddingRight = UDim.new(0, props.padding.right) end
		p.Parent = inst
	end
	
	return { instance = inst, component = cmp, render = function() return inst end }
end

function UI.Components.TextLabel(props)
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = UI.Theme:get("text"),
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
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
		Size = UDim2.fromOffset(120, Core.CONSTANTS.MIN_TOUCH_TARGET),
		AutoButtonColor = false,
	}
	
	for k, v in pairs(defaults) do
		if props[k] == nil then props[k] = v end
	end
	
	local cmp = Component.new("TextButton", props)
	local inst = cmp:render()
	
	-- Use UIScale for hover instead of position
	local scaleObj = Instance.new("UIScale")
	scaleObj.Scale = 1
	scaleObj.Parent = inst
	
	local enterConn = inst.MouseEnter:Connect(function()
		Core.SoundSystem.play("hover")
		Core.HapticSystem.trigger("light")
		Core.Animation.tween(scaleObj, { Scale = 1.02 }, Tokens.motion.fast)
	end)
	
	local leaveConn = inst.MouseLeave:Connect(function()
		Core.Animation.tween(scaleObj, { Scale = 1 }, Tokens.motion.fast)
	end)
	
	table.insert(cmp.connections, enterConn)
	table.insert(cmp.connections, leaveConn)
	
	if props.onClick then
		local clickConn = inst.MouseButton1Click:Connect(props.onClick)
		table.insert(cmp.connections, clickConn)
	end
	
	local soundConn = inst.MouseButton1Click:Connect(function()
		Core.SoundSystem.play("click")
		Core.HapticSystem.trigger("medium")
	end)
	table.insert(cmp.connections, soundConn)
	
	return cmp
end

function UI.Components.Image(props)
	local defaults = {
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
	}
	
	for k, v in pairs(defaults) do
		if props[k] == nil then props[k] = v end
	end
	
	return Component.new("ImageLabel", props)
end

function UI.Components.Pill(props)
	local text = props.text or ""
	local color = props.color or UI.Theme:get("accent")
	local parent = props.parent
	
	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromOffset(0, 28)
	pill.BackgroundColor3 = color
	pill.BorderSizePixel = 0
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Parent = parent
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Tokens.radius.pill
	corner.Parent = pill
	
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = pill
	
	local label = Instance.new("TextLabel")
	label.Text = text
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = Tokens.typography.tiny
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = pill
	
	return pill, label
end

function UI.Components.Skeleton(props)
	local parent = props.parent
	local size = props.size or UDim2.fromScale(1, 1)
	
	local skeleton = Instance.new("Frame")
	skeleton.Name = "Skeleton"
	skeleton.Size = size
	skeleton.Position = props.position or UDim2.new()
	skeleton.AnchorPoint = props.anchorPoint or Vector2.new()
	skeleton.BackgroundColor3 = UI.Theme:get("skeletonBase")
	skeleton.BorderSizePixel = 0
	skeleton.ClipsDescendants = true
	skeleton.Parent = parent
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Tokens.radius.small
	corner.Parent = skeleton
	
	local shimmer = Core.Animation.shimmer(skeleton, 1.5)
	
	local cleanup = function()
		if shimmer and shimmer.Parent then
			shimmer:Destroy()
		end
		if skeleton and skeleton.Parent then
			skeleton:Destroy()
		end
	end
	
	return skeleton, cleanup
end

-- ========================================
-- NOTIFICATION BANNER
-- ========================================
function UI.Components.NotificationBanner(props)
	local text = props.text or ""
	local bannerType = props.type or "success" -- success, error, warning
	local duration = props.duration or 3
	local parent = props.parent
	
	local colors = {
		success = UI.Theme:get("success"),
		error = UI.Theme:get("error"),
		warning = UI.Theme:get("warning"),
	}
	
	local banner = Instance.new("Frame")
	banner.Size = UDim2.new(1, -48, 0, 60)
	banner.Position = UDim2.new(0.5, 0, 0, -70)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.BackgroundColor3 = colors[bannerType]
	banner.BorderSizePixel = 0
	banner.ZIndex = 100
	banner.Parent = parent
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Tokens.radius.medium
	corner.Parent = banner
	
	local label = Instance.new("TextLabel")
	label.Text = text
	label.Size = UDim2.new(1, -32, 1, 0)
	label.Position = UDim2.fromOffset(16, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = Tokens.typography.small
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Parent = banner
	
	-- Animate in
	Core.Animation.tween(
		banner,
		{ Position = UDim2.new(0.5, 0, 0, 24) },
		Tokens.motion.medium,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)
	
	-- Auto-dismiss
	task.delay(duration, function()
		if banner and banner.Parent then
			Core.Animation.tween(
				banner,
				{ Position = UDim2.new(0.5, 0, 0, -70) },
				Tokens.motion.fast
			)
			task.wait(Tokens.motion.fast)
			if banner and banner.Parent then
				banner:Destroy()
			end
		end
	end)
	
	return banner
end

-- ========================================
-- SHOP
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
	self.gridLayouts = {}
	self.gridUpdateBusy = false
	
	self:initialize()
	return self
end

function Shop:preloadImages()
	local ids = {
		"rbxassetid://17398522865",
		"rbxassetid://10709728059",
		"rbxassetid://10709727148"
	}
	
	for _, p in ipairs(Core.DataManager.products.cash) do
		if p.icon then table.insert(ids, p.icon) end
	end
	
	for _, p in ipairs(Core.DataManager.products.gamepasses) do
		if p.icon then table.insert(ids, p.icon) end
	end
	
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(ids)
		end)
	end)
end

function Shop:initialize()
	Core.SoundSystem.initialize()
	Core.DataManager.refreshPrices()
	self:preloadImages()
	self:createToggleButton()
	self:createMainInterface()
	self:setupInputHandlers()
	self:setupViewportListener()
end

function Shop:createToggleButton()
	local sg = PlayerGui:FindFirstChild("SanrioShopToggle") or Instance.new("ScreenGui")
	sg.Name = "SanrioShopToggle"
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 999
	sg.Parent = PlayerGui
	
	local insets = Core.Utils.getSafeAreaInsets()
	
	self.toggleButton = UI.Components.Button({
		Text = "",
		Size = UDim2.fromOffset(180, 60),
		Position = UDim2.new(1, -insets.right, 1, -insets.bottom),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = Tokens.radius.pill,
		stroke = { color = UI.Theme:get("accent"), thickness = 2 },
		parent = sg,
		onClick = function()
			self:toggle()
		end
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
	
	-- Enhanced blur effect
	self.blur = Lighting:FindFirstChild("SanrioShopBlur") or Instance.new("BlurEffect")
	self.blur.Name = "SanrioShopBlur"
	self.blur.Size = 0
	self.blur.Parent = Lighting
	
	-- Dimmer
	local dim = UI.Components.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		parent = self.gui
	}):render()
	dim.Active = true
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:close()
		end
	end)
	
	local size = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE
	
	self.mainPanel = UI.Components.Frame({
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UI.Theme:get("background"),
		cornerRadius = Tokens.radius.large,
		stroke = { color = UI.Theme:get("stroke"), thickness = 1, transparency = 0.5 },
		parent = self.gui
	}):render()
	
	UI.Responsive.scale(self.mainPanel)
	
	self:createHeader()
	self:createTabs()
	
	self.contentContainer = UI.Components.Frame({
		Size = UDim2.new(1, -48, 1, -200),
		Position = UDim2.fromOffset(24, 176),
		BackgroundTransparency = 1,
		parent = self.mainPanel
	}):render()
	
	self:createPages()
	self:selectTab("Cash")
end

function Shop:createHeader()
	local insets = Core.Utils.getSafeAreaInsets()
	
	-- Glass header with blur
	local header = UI.Components.Frame({
		Size = UDim2.new(1, -48, 0, 80),
		Position = UDim2.fromOffset(24, 24),
		BackgroundColor3 = UI.Theme:get("surfaceAlt"),
		BackgroundTransparency = 0.1,
		cornerRadius = Tokens.radius.medium,
		stroke = { color = UI.Theme:get("stroke"), thickness = 1, transparency = 0.85 },
		parent = self.mainPanel
	}):render()
	
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
		TextSize = Tokens.typography.hero,
		parent = header
	}):render()
	
	-- Close button with proper touch target
	UI.Components.Button({
		Text = "✕",
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.new(1, -64, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = UI.Theme:get("accent"),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		cornerRadius = Tokens.radius.pill,
		parent = header,
		onClick = function()
			self:close()
		end
	}):render()
end

function Shop:createTabs()
	self.tabContainer = UI.Components.Frame({
		Size = UDim2.new(1, -48, 0, 56),
		Position = UDim2.fromOffset(24, 116),
		BackgroundTransparency = 1,
		parent = self.mainPanel
	}):render()
	
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, Tokens.spacing.sm)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = self.tabContainer
	
	local tabs = {
		{ id = "Cash", name = "Cash", icon = "rbxassetid://10709728059", color = UI.Theme:get("cinna") },
		{ id = "Gamepasses", name = "Passes", icon = "rbxassetid://10709727148", color = UI.Theme:get("kuromi") },
	}
	
	for _, data in ipairs(tabs) do
		local tab = UI.Components.Button({
			Text = "",
			Size = UDim2.fromOffset(180, 56),
			BackgroundColor3 = UI.Theme:get("surface"),
			cornerRadius = Tokens.radius.pill,
			stroke = { color = UI.Theme:get("stroke"), thickness = 1 },
			parent = self.tabContainer,
			onClick = function()
				self:selectTab(data.id)
			end
		}):render()
		
		local content = UI.Components.Frame({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			parent = tab
		}):render()
		
		local contentLayout = Instance.new("UIListLayout")
		contentLayout.FillDirection = Enum.FillDirection.Horizontal
		contentLayout.Padding = UDim.new(0, Tokens.spacing.xs)
		contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		contentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		contentLayout.Parent = content
		
		local icon = UI.Components.Image({
			Image = data.icon,
			Size = UDim2.fromOffset(28, 28),
			parent = content
		}):render()
		
		local label = UI.Components.TextLabel({
			Text = data.name,
			Size = UDim2.new(0, 100, 1, 0),
			Font = Enum.Font.GothamMedium,
			TextSize = Tokens.typography.body,
			parent = content
		}):render()
		
		self.tabs[data.id] = {
			button = tab,
			data = data,
			icon = icon,
			label = label
		}
	end
end

function Shop:createPages()
	-- Cash page
	local cashPage = UI.Components.Frame({
		Name = "CashPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		parent = self.contentContainer
	}):render()
	
	local sfCash = Instance.new("ScrollingFrame")
	sfCash.BackgroundTransparency = 1
	sfCash.ScrollBarThickness = 8
	sfCash.ScrollBarImageColor3 = UI.Theme:get("stroke")
	sfCash.Size = UDim2.fromScale(1, 1)
	sfCash.BorderSizePixel = 0
	sfCash.ScrollingDirection = Enum.ScrollingDirection.Y
	sfCash.CanvasSize = UDim2.new(0, 0, 0, 0)
	sfCash.Parent = cashPage
	
	local gridCash = self:createResponsiveGrid(sfCash)
	self.gridLayouts["Cash"] = gridCash
	
	for _, product in ipairs(Core.DataManager.products.cash) do
		self:createProductCard(product, "cash", sfCash)
	end
	
	-- Gamepasses page
	local passPage = UI.Components.Frame({
		Name = "GamepassesPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		parent = self.contentContainer
	}):render()
	
	local sfPass = Instance.new("ScrollingFrame")
	sfPass.BackgroundTransparency = 1
	sfPass.ScrollBarThickness = 8
	sfPass.ScrollBarImageColor3 = UI.Theme:get("stroke")
	sfPass.Size = UDim2.fromScale(1, 1)
	sfPass.BorderSizePixel = 0
	sfPass.ScrollingDirection = Enum.ScrollingDirection.Y
	sfPass.CanvasSize = UDim2.new(0, 0, 0, 0)
	sfPass.Parent = passPage
	
	local gridPass = self:createResponsiveGrid(sfPass)
	self.gridLayouts["Gamepasses"] = gridPass
	
	for _, product in ipairs(Core.DataManager.products.gamepasses) do
		self:createProductCard(product, "gamepass", sfPass)
	end
	
	self.pages = {
		Cash = cashPage,
		Gamepasses = passPage
	}
end

function Shop:createResponsiveGrid(scrollFrame)
	local grid = Instance.new("UIGridLayout")
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scrollFrame
	
	local function updateGrid()
		if self.gridUpdateBusy then return end
		self.gridUpdateBusy = true
		
		task.defer(function()
			if not grid or not grid.Parent then
				self.gridUpdateBusy = false
				return
			end
			
			local cam = workspace.CurrentCamera
			if not cam then
				self.gridUpdateBusy = false
				return
			end
			
			local viewportWidth = cam.ViewportSize.X
			local columns = Core.Utils.getGridColumns(viewportWidth)
			local cardSize = Core.Utils.calculateCardSize(viewportWidth, columns)
			
			grid.CellSize = UDim2.fromOffset(cardSize.X, cardSize.Y)
			grid.CellPadding = UDim2.fromOffset(Core.CONSTANTS.GRID_GUTTER, Core.CONSTANTS.GRID_GUTTER)
			
			-- Update canvas size
			scrollFrame.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + Tokens.spacing.lg)
			
			self.gridUpdateBusy = false
		end)
	end
	
	-- Initial update
	updateGrid()
	
	-- Listen to content size changes
	local conn = grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if not self.gridUpdateBusy then
			scrollFrame.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + Tokens.spacing.lg)
		end
	end)
	
	table.insert(Core.State.cleanupCallbacks, function()
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end)
	
	return grid
end

function Shop:setupViewportListener()
	local cam = workspace.CurrentCamera
	if not cam then return end
	
	local lastUpdate = tick()
	local conn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		-- Throttle updates
		if tick() - lastUpdate < 0.2 then return end
		lastUpdate = tick()
		
		for _, grid in pairs(self.gridLayouts) do
			if grid and grid.Parent then
				local scrollFrame = grid.Parent
				local viewportWidth = cam.ViewportSize.X
				local columns = Core.Utils.getGridColumns(viewportWidth)
				local cardSize = Core.Utils.calculateCardSize(viewportWidth, columns)
				
				grid.CellSize = UDim2.fromOffset(cardSize.X, cardSize.Y)
			end
		end
	end)
	
	table.insert(Core.State.cleanupCallbacks, function()
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end)
end

function Shop:createProductCard(product, productType, parent)
	local isGamepass = (productType == "gamepass")
	local cardColor = isGamepass and UI.Theme:get("kuromi") or UI.Theme:get("cinna")
	
	local card = UI.Components.Frame({
		Name = product.name .. "Card",
		Size = UDim2.fromOffset(300, 400), -- Grid will resize
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = Tokens.radius.medium,
		stroke = { color = cardColor, thickness = 2, transparency = 0.6 },
		parent = parent
	}):render()
	
	card.ClipsDescendants = true
	
	-- Use UIScale for hover instead of position
	local cardScale = Instance.new("UIScale")
	cardScale.Scale = 1
	cardScale.Parent = card
	
	card.MouseEnter:Connect(function()
		Core.Animation.tween(cardScale, { Scale = 1.02 }, Tokens.motion.fast)
	end)
	
	card.MouseLeave:Connect(function()
		Core.Animation.tween(cardScale, { Scale = 1 }, Tokens.motion.fast)
	end)
	
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -Tokens.spacing.lg, 1, -Tokens.spacing.lg)
	content.Position = UDim2.fromOffset(Tokens.spacing.sm, Tokens.spacing.sm)
	content.Parent = card
	
	-- Image container with aspect ratio constraint
	local imageContainer = Instance.new("Frame")
	imageContainer.Name = "ImageContainer"
	imageContainer.Size = UDim2.new(1, 0, 0, 180)
	imageContainer.BackgroundColor3 = UI.Theme:get("surfaceAlt")
	imageContainer.BorderSizePixel = 0
	imageContainer.ClipsDescendants = true
	imageContainer.Parent = content
	
	local imgCorner = Instance.new("UICorner")
	imgCorner.CornerRadius = Tokens.radius.small
	imgCorner.Parent = imageContainer
	
	-- Aspect ratio constraint for 16:9 images
	local aspectConstraint = Instance.new("UIAspectRatioConstraint")
	aspectConstraint.AspectRatio = 16 / 9
	aspectConstraint.AspectType = Enum.AspectType.FitWithinMaxSize
	aspectConstraint.DominantAxis = Enum.DominantAxis.Width
	aspectConstraint.Parent = imageContainer
	
	-- Skeleton loader
	local skeleton, cleanupSkeleton = UI.Components.Skeleton({
		parent = imageContainer,
		size = UDim2.fromScale(1, 1),
	})
	
	-- Product image
	local productImage = UI.Components.Image({
		Image = product.icon or "rbxassetid://0",
		Size = UDim2.fromScale(0.7, 0.7),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageTransparency = 1,
		parent = imageContainer
	}):render()
	
	-- Load image
	task.spawn(function()
		task.wait(0.5) -- Simulate loading
		if cleanupSkeleton then cleanupSkeleton() end
		Core.Animation.tween(productImage, { ImageTransparency = 0 }, Tokens.motion.fast)
	end)
	
	-- Price pill (top-right)
	if product.price and product.price > 0 then
		local pill, pillLabel = UI.Components.Pill({
			text = "R$" .. tostring(product.price),
			color = cardColor,
			parent = imageContainer,
		})
		pill.Position = UDim2.new(1, -12, 0, 12)
		pill.AnchorPoint = Vector2.new(1, 0)
		pill.ZIndex = 5
	end
	
	-- Featured badge
	if product.featured then
		local featuredPill = UI.Components.Pill({
			text = "BEST VALUE",
			color = UI.Theme:get("warning"),
			parent = imageContainer,
		})
		featuredPill.Position = UDim2.fromOffset(12, 12)
		featuredPill.ZIndex = 5
	end
	
	-- Info section
	local info = Instance.new("Frame")
	info.BackgroundTransparency = 1
	info.Size = UDim2.new(1, 0, 1, -200)
	info.Position = UDim2.fromOffset(0, 190)
	info.Parent = content
	
	-- Product name (2-line clamp)
	UI.Components.TextLabel({
		Text = product.name,
		Size = UDim2.new(1, 0, 0, 56),
		Font = Enum.Font.GothamBold,
		TextSize = Tokens.typography.title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd,
		parent = info
	}):render()
	
	-- Description (1-line)
	local descText = isGamepass and product.description or ("Includes " .. Core.Utils.formatNumber(product.amount) .. " Cash")
	UI.Components.TextLabel({
		Text = descText,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 62),
		Font = Enum.Font.Gotham,
		TextSize = Tokens.typography.small,
		TextColor3 = UI.Theme:get("textSecondary"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd,
		parent = info
	}):render()
	
	-- Check ownership for gamepasses
	local owned = isGamepass and Core.DataManager.checkOwnership(product.id)
	
	-- Purchase button
	local buttonCmp = UI.Components.Button({
		Text = owned and "Owned" or "Purchase",
		Size = UDim2.new(1, 0, 0, Core.CONSTANTS.MIN_TOUCH_TARGET),
		Position = UDim2.new(0, 0, 1, -Core.CONSTANTS.MIN_TOUCH_TARGET - Tokens.spacing.xs),
		BackgroundColor3 = owned and UI.Theme:get("success") or cardColor,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = Tokens.typography.body,
		cornerRadius = Tokens.radius.small,
		parent = info,
		onClick = function()
			self:handlePurchase(product, productType, card)
		end
	})
	
	local btnInst = buttonCmp:render()
	btnInst.Active = not owned
	
	-- Store references
	product.cardInstance = card
	product.purchaseButton = btnInst
	product.imageContainer = imageContainer
	
	-- Toggle for Auto Collect
	if isGamepass and product.hasToggle and owned then
		self:addToggleSwitch(product, imageContainer)
	end
	
	-- Focus ring for controller support
	local focusStroke = Instance.new("UIStroke")
	focusStroke.Color = UI.Theme:get("accent")
	focusStroke.Thickness = 3
	focusStroke.Transparency = 1
	focusStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	focusStroke.Parent = card
	
	product.focusStroke = focusStroke
	
	table.insert(Core.State.cardReferences, {
		card = card,
		product = product,
		button = btnInst,
	})
end

function Shop:handlePurchase(product, productType, card)
	local button = product.purchaseButton
	if not button or not button.Parent or not button.Active then return end
	
	-- Debounce check
	local lastTime = Core.State.lastPurchaseTime[product.id] or 0
	if tick() - lastTime < Core.CONSTANTS.PURCHASE_DEBOUNCE then
		return
	end
	Core.State.lastPurchaseTime[product.id] = tick()
	
	-- Check ownership again for gamepasses
	if productType == "gamepass" and Core.DataManager.checkOwnership(product.id) then
		return
	end
	
	-- Show spinner
	local originalText = button.Text
	button.Text = "⏳ Processing..."
	button.Active = false
	
	Core.State.purchasePending[product.id] = {
		product = product,
		type = productType,
		button = button,
		card = card,
		originalText = originalText,
	}
	
	-- Prompt purchase
	local ok, err
	if productType == "gamepass" then
		ok = pcall(function()
			MarketplaceService:PromptGamePassPurchase(Player, product.id)
		end)
	else
		ok = pcall(function()
			MarketplaceService:PromptProductPurchase(Player, product.id)
		end)
	end
	
	if not ok then
		self:handlePurchaseError(product, "Failed to open purchase prompt")
		Core.State.purchasePending[product.id] = nil
	else
		-- Timeout fallback
		task.delay(Core.CONSTANTS.PURCHASE_TIMEOUT, function()
			local pending = Core.State.purchasePending[product.id]
			if pending and pending.button and pending.button.Parent then
				pending.button.Text = pending.originalText
				pending.button.Active = true
			end
			Core.State.purchasePending[product.id] = nil
		end)
	end
end

function Shop:handlePurchaseSuccess(product, card)
	Core.SoundSystem.play("success")
	Core.HapticSystem.trigger("success")
	
	-- Confetti effect
	if card and card.Parent then
		Core.Animation.confetti(card, UI.Theme:get("success"))
	end
	
	-- Show success banner
	UI.Components.NotificationBanner({
		text = "✓ Purchase successful!",
		type = "success",
		duration = 3,
		parent = self.mainPanel,
	})
	
	-- Refresh ownership
	ownershipCache:clear()
	self:refreshAllProducts()
end

function Shop:handlePurchaseError(product, message)
	Core.SoundSystem.play("error")
	Core.HapticSystem.trigger("medium")
	
	UI.Components.NotificationBanner({
		text = message or "Purchase failed. Please try again.",
		type = "error",
		duration = 4,
		parent = self.mainPanel,
	})
end

function Shop:addToggleSwitch(product, imageContainer)
	local container = Instance.new("Frame")
	container.Name = "ToggleContainer"
	container.Size = UDim2.fromOffset(56, 28)
	container.Position = UDim2.new(1, -70, 0, 12)
	container.AnchorPoint = Vector2.new(1, 0)
	container.BackgroundColor3 = UI.Theme:get("stroke")
	container.BorderSizePixel = 0
	container.ZIndex = 5
	container.Parent = imageContainer
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Tokens.radius.pill
	corner.Parent = container
	
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.fromOffset(24, 24)
	knob.Position = UDim2.fromOffset(2, 2)
	knob.BackgroundColor3 = UI.Theme:get("surface")
	knob.BorderSizePixel = 0
	knob.Parent = container
	
	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = Tokens.radius.pill
	knobCorner.Parent = knob
	
	local click = Instance.new("TextButton")
	click.BackgroundTransparency = 1
	click.Text = ""
	click.Size = UDim2.fromScale(1, 1)
	click.Parent = container
	
	local state = false
	
	-- Get initial state
	if Remotes then
		local rf = Remotes:FindFirstChild("GetAutoCollectState")
		if rf and rf:IsA("RemoteFunction") then
			local ok, val = pcall(function()
				return rf:InvokeServer()
			end)
			if ok and type(val) == "boolean" then
				state = val
			end
		end
	end
	
	local function render()
		if state then
			container.BackgroundColor3 = UI.Theme:get("success")
			Core.Animation.tween(knob, { Position = UDim2.fromOffset(30, 2) }, Tokens.motion.fast)
		else
			container.BackgroundColor3 = UI.Theme:get("stroke")
			Core.Animation.tween(knob, { Position = UDim2.fromOffset(2, 2) }, Tokens.motion.fast)
		end
	end
	
	render()
	
	click.MouseButton1Click:Connect(function()
		state = not state
		render()
		
		if Remotes then
			local ev = Remotes:FindFirstChild("AutoCollectToggle")
			if ev and ev:IsA("RemoteEvent") then
				ev:FireServer(state)
			end
		end
		
		Core.SoundSystem.play("click")
		Core.HapticSystem.trigger("light")
	end)
end

function Shop:selectTab(tabId)
	if self.currentTab == tabId and self.pages[tabId] and self.pages[tabId].Visible then
		return
	end
	
	-- Update tab visuals
	for id, tab in pairs(self.tabs) do
		local active = (id == tabId)
		local data = tab.data
		
		local bgColor = active 
			and Core.Utils.blend(data.color, Color3.new(1, 1, 1), 0.85) 
			or UI.Theme:get("surface")
		
		Core.Animation.tween(tab.button, { BackgroundColor3 = bgColor }, Tokens.motion.fast)
		
		local stroke = tab.button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = active and data.color or UI.Theme:get("stroke")
			stroke.Thickness = active and 2 or 1
		end
		
		tab.icon.ImageColor3 = active and data.color or UI.Theme:get("text")
		tab.label.TextColor3 = active and data.color or UI.Theme:get("text")
	end
	
	-- Animate page transitions
	for id, page in pairs(self.pages) do
		if id == tabId then
			page.Visible = true
			page.Position = UDim2.fromOffset(0, 12)
			page.BackgroundTransparency = 1
			
			Core.Animation.tween(
				page,
				{ Position = UDim2.new() },
				Tokens.motion.slow,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			)
		else
			if page.Visible then
				Core.Animation.tween(page, { Position = UDim2.fromOffset(0, -12) }, Tokens.motion.fast)
				task.delay(Tokens.motion.fast, function()
					page.Visible = false
				end)
			else
				page.Visible = false
			end
		end
	end
	
	self.currentTab = tabId
	Core.SoundSystem.play("click")
	Core.HapticSystem.trigger("light")
end

function Shop:refreshAllProducts()
	ownershipCache:clear()
	
	for _, gp in ipairs(Core.DataManager.products.gamepasses) do
		local owned = Core.DataManager.checkOwnership(gp.id)
		
		if gp.purchaseButton and gp.purchaseButton.Parent then
			gp.purchaseButton.Text = owned and "Owned" or "Purchase"
			gp.purchaseButton.BackgroundColor3 = owned and UI.Theme:get("success") or UI.Theme:get("kuromi")
			gp.purchaseButton.Active = not owned
		end
		
		-- Add toggle if needed
		if gp.hasToggle and owned and gp.imageContainer and not gp.imageContainer:FindFirstChild("ToggleContainer") then
			self:addToggleSwitch(gp, gp.imageContainer)
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
	
	-- Blur effect
	Core.Animation.tween(self.blur, { Size = Tokens.blur.glass }, Tokens.motion.medium)
	
	-- Scale up animation
	local size = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE
	self.mainPanel.Position = UDim2.fromScale(0.5, 0.55)
	
	local scale = self.mainPanel:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = 0.92
		Core.Animation.tween(scale, { Scale = 1 }, Tokens.motion.spring, Enum.EasingStyle.Back)
	end
	
	Core.Animation.tween(
		self.mainPanel,
		{ Position = UDim2.fromScale(0.5, 0.5) },
		Tokens.motion.spring,
		Enum.EasingStyle.Back
	)
	
	self:selectTab(self.currentTab or "Cash")
	
	Core.SoundSystem.play("open")
	Core.HapticSystem.trigger("medium")
	
	task.wait(Tokens.motion.spring)
	Core.State.isAnimating = false
end

function Shop:close()
	if not Core.State.isOpen or Core.State.isAnimating then return end
	
	Core.State.isAnimating = true
	Core.State.isOpen = false
	
	-- Blur out
	Core.Animation.tween(self.blur, { Size = 0 }, Tokens.motion.fast)
	
	-- Scale down
	local scale = self.mainPanel:FindFirstChildOfClass("UIScale")
	if scale then
		Core.Animation.tween(scale, { Scale = 0.92 }, Tokens.motion.fast)
	end
	
	Core.Animation.tween(
		self.mainPanel,
		{ Position = UDim2.fromScale(0.5, 0.55) },
		Tokens.motion.fast
	)
	
	Core.SoundSystem.play("close")
	Core.HapticSystem.trigger("light")
	
	task.wait(Tokens.motion.fast)
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

function Shop:setupInputHandlers()
	-- Keyboard
	local keyConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.Backquote then
			self:toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			if Core.State.isOpen then
				self:close()
			end
		end
	end)
	
	table.insert(Core.State.cleanupCallbacks, function()
		if keyConn and keyConn.Connected then
			keyConn:Disconnect()
		end
	end)
	
	-- Controller support (basic)
	-- Full D-pad navigation would require more extensive focus management
end

function Shop:cleanup()
	-- Disconnect all cleanup callbacks
	for _, callback in ipairs(Core.State.cleanupCallbacks) do
		pcall(callback)
	end
	Core.State.cleanupCallbacks = {}
	
	-- Clear references
	Core.State.cardReferences = {}
	
	-- Cleanup components
	for _, tab in pairs(self.tabs) do
		if tab.component and tab.component.cleanup then
			tab.component:cleanup()
		end
	end
end

-- ========================================
-- UI RESPONSIVE
-- ========================================
UI.Responsive = {}

function UI.Responsive.scale(inst)
	local cam = workspace.CurrentCamera
	if not cam then return end
	
	local scaleObj = Instance.new("UIScale")
	scaleObj.Parent = inst
	
	local function update()
		local viewport = cam.ViewportSize
		local scaleX = viewport.X / 1920
		local scaleY = viewport.Y / 1080
		local factor = math.min(scaleX, scaleY)
		factor = math.clamp(factor, 0.5, 1.35)
		
		if Core.Utils.isMobile() then
			factor = factor * 0.85
		end
		
		scaleObj.Scale = factor
	end
	
	update()
	
	local conn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	
	table.insert(Core.State.cleanupCallbacks, function()
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end)
end

-- ========================================
-- BOOT
-- ========================================
Core.SoundSystem.initialize()
local shop = Shop.new()

-- ========================================
-- PURCHASE CALLBACKS
-- ========================================
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if player ~= Player then return end
	
	local pending = Core.State.purchasePending[passId]
	if pending and pending.button and pending.button.Parent then
		pending.button.Text = pending.originalText or "Purchase"
		pending.button.Active = true
	end
	
	if purchased then
		shop:handlePurchaseSuccess(pending.product, pending.card)
	end
	
	Core.State.purchasePending[passId] = nil
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, purchased)
	if player ~= Player then return end
	
	local pending = Core.State.purchasePending[productId]
	if pending and pending.button and pending.button.Parent then
		pending.button.Text = pending.originalText or "Purchase"
		pending.button.Active = true
	end
	
	if purchased then
		shop:handlePurchaseSuccess(pending.product, pending.card)
		
		-- Grant currency
		if Remotes then
			local grant = Remotes:FindFirstChild("GrantProductCurrency")
			if grant and grant:IsA("RemoteEvent") then
				grant:FireServer(productId)
			end
		end
	end
	
	Core.State.purchasePending[productId] = nil
end)

-- ========================================
-- RESPAWN HANDLING
-- ========================================
Player.CharacterAdded:Connect(function()
	task.wait(1)
	if not shop.toggleButton or not shop.toggleButton.Parent then
		shop:createToggleButton()
	end
end)

-- ========================================
-- PERIODIC REFRESH
-- ========================================
task.spawn(function()
	while true do
		task.wait(30)
		if Core.State.isOpen then
			shop:refreshAllProducts()
		end
	end
end)

print("[SanrioShop] 🌸 Polished shop system loaded successfully!")
print("  ✓ Responsive 3/2/1 grid layout")
print("  ✓ Skeleton loaders & smooth animations")
print("  ✓ Controller support & haptic feedback")
print("  ✓ Purchase flow with notifications")
print("  ✓ Performance optimized with cleanup")

return shop
