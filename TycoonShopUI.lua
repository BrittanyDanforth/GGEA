--[[
	═══════════════════════════════════════════════════════════════════════
	TYCOON SHOP UI — MODERN CUTE EDITION
	═══════════════════════════════════════════════════════════════════════
	
	Place: StarterPlayer > StarterPlayerScripts
	Version: 6.0.0 (2025 Complete Rewrite)
	
	FEATURES:
	✓ Mobile-first responsive design (1/2/3 column grid with breakpoints)
	✓ Modern-cute aesthetic (soft pastels, rounded corners, subtle depth)
	✓ Safe-zone aware (respects notches, top bar, mobile controls)
	✓ Gamepass ownership + elegant toggle system
	✓ Smooth animations (slide/fade open, world blur, hover feedback)
	✓ Production-quality code (no warnings, proper error handling)
	
	CONTROLS:
	• M or Gamepad X — Toggle shop
	• ESC — Close shop
	• Click floating button — Toggle shop
	
	SERVER REMOTES (ReplicatedStorage/TycoonRemotes):
	• RemoteEvent: GrantProductCurrency(productId)
	• RemoteEvent: GamepassPurchased(passId)
	• RemoteEvent: AutoCollectToggle(state)
	• RemoteFunction: GetAutoCollectState() -> boolean
	
	TODO: Replace asset IDs with your own:
	• ICON_CASH, ICON_PASS, ICON_SHOP
	• Product IDs (lines 180-191)
	• Gamepass IDs (lines 193-196)
]]

-- ═══════════════════════════════════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Wait for remotes folder (with timeout)
local Remotes
task.spawn(function()
	Remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)
	if not Remotes then
		warn("[TycoonShop] TycoonRemotes folder not found in ReplicatedStorage")
	end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- CONFIGURATION & CONSTANTS
-- ═══════════════════════════════════════════════════════════════════════

local CONFIG = {
	VERSION = "6.0.0",
	DEBUG = false,
	
	-- Timing
	ANIM_FAST = 0.15,
	ANIM_NORMAL = 0.25,
	ANIM_SLOW = 0.4,
	
	-- Purchase
	PURCHASE_TIMEOUT = 15,
	PRICE_REFRESH_INTERVAL = 30,
	
	-- Cache TTL (seconds)
	PRICE_CACHE_TTL = 300,
	OWNERSHIP_CACHE_TTL = 60,
	
	-- Responsive breakpoints (viewport width)
	BREAKPOINT_SMALL = 600,
	BREAKPOINT_MEDIUM = 950,
	
	-- Safe zone margins (percentage)
	SAFE_MARGIN_X = 0.06,
	SAFE_MARGIN_Y = 0.06,
}

-- ═══════════════════════════════════════════════════════════════════════
-- THEME SYSTEM (Modern Cute)
-- ═══════════════════════════════════════════════════════════════════════

local Theme = {
	-- Color Palette (Soft Pastels)
	colors = {
		-- Base
		bg = Color3.fromRGB(251, 248, 246),
		surface = Color3.fromRGB(255, 255, 255),
		surfaceHover = Color3.fromRGB(249, 244, 248),
		surfaceAlt = Color3.fromRGB(247, 243, 250),
		
		-- Strokes & Borders
		stroke = Color3.fromRGB(229, 220, 229),
		strokeLight = Color3.fromRGB(240, 235, 240),
		
		-- Text
		text = Color3.fromRGB(45, 41, 58),
		textSecondary = Color3.fromRGB(122, 112, 138),
		textTertiary = Color3.fromRGB(165, 158, 178),
		textWhite = Color3.fromRGB(255, 255, 255),
		
		-- Accents
		mint = Color3.fromRGB(168, 218, 207),      -- Cash primary
		mintDark = Color3.fromRGB(142, 198, 187),  -- Cash hover
		
		lavender = Color3.fromRGB(203, 194, 255),  -- Pass primary
		lavenderDark = Color3.fromRGB(183, 174, 235), -- Pass hover
		
		sky = Color3.fromRGB(186, 214, 255),       -- Info
		peach = Color3.fromRGB(255, 209, 194),     -- Warm accent
		
		-- Status
		success = Color3.fromRGB(130, 199, 151),
		warning = Color3.fromRGB(250, 207, 133),
		danger = Color3.fromRGB(255, 127, 147),
		
		-- Overlays
		dim = Color3.fromRGB(0, 0, 0),
	},
	
	-- Typography
	fonts = {
		regular = Enum.Font.Gotham,
		medium = Enum.Font.GothamMedium,
		semibold = Enum.Font.GothamSemibold,
		bold = Enum.Font.GothamBold,
	},
	
	-- Sizing Scale
	sizes = {
		xs = 14,
		sm = 16,
		base = 18,
		lg = 20,
		xl = 24,
		xxl = 28,
	},
	
	-- Spacing Scale
	spacing = {
		xs = 4,
		sm = 8,
		md = 12,
		lg = 16,
		xl = 20,
		xxl = 24,
	},
	
	-- Corner Radius
	radius = {
		sm = 8,
		md = 12,
		lg = 16,
		xl = 20,
		pill = 999,
	},
	
	-- Shadows (via layered frames if needed)
	shadows = {
		sm = {0.95, 2},
		md = {0.92, 4},
		lg = {0.88, 8},
	},
}

-- ═══════════════════════════════════════════════════════════════════════
-- DATA & ASSETS
-- ═══════════════════════════════════════════════════════════════════════

-- TODO: Replace with your actual asset IDs
local ASSETS = {
	ICON_CASH = "rbxassetid://18420350532",
	ICON_PASS = "rbxassetid://18420350433",
	ICON_SHOP = "rbxassetid://17398522865",
	VIGNETTE = "rbxassetid://7743879747",
}

-- TODO: Replace with your actual gamepass IDs
local GAMEPASS_IDS = {
	AUTO_COLLECT = 1412171840,
	DOUBLE_CASH = 1398974710,
}

local DATA = {
	cashPacks = {
		{id = 1897730242, amount = 1000,       name = "Starter Pouch",    desc = "Perfect for your first upgrades",          icon = ASSETS.ICON_CASH},
		{id = 1897730373, amount = 5000,       name = "Small Bundle",     desc = "Accelerate your early game",               icon = ASSETS.ICON_CASH},
		{id = 1897730467, amount = 10000,      name = "Medium Pack",      desc = "Unlock new areas faster",                  icon = ASSETS.ICON_CASH},
		{id = 1897730581, amount = 50000,      name = "Large Vault",      desc = "Major expansion capital",                  icon = ASSETS.ICON_CASH},
		{id = 1234567001, amount = 100000,     name = "Grand Safe",       desc = "Full tycoon renovation",                   icon = ASSETS.ICON_CASH},
		{id = 1234567002, amount = 250000,     name = "Quarter Million",  desc = "Serious investment package",               icon = ASSETS.ICON_CASH},
		{id = 1234567003, amount = 500000,     name = "Half Million",     desc = "Fast-track to completion",                 icon = ASSETS.ICON_CASH},
		{id = 1234567004, amount = 1000000,    name = "Millionaire Pack", desc = "Dominate every upgrade",                   icon = ASSETS.ICON_CASH},
		{id = 1234567005, amount = 5000000,    name = "Tycoon Titan",     desc = "Max out everything instantly",             icon = ASSETS.ICON_CASH},
		{id = 1234567006, amount = 10000000,   name = "Ultimate Vault",   desc = "The final word in wealth",                 icon = ASSETS.ICON_CASH},
	},
	
	gamepasses = {
		{id = GAMEPASS_IDS.AUTO_COLLECT, name = "Auto Collect",  desc = "Automatically collect cash from your tycoon", icon = ASSETS.ICON_PASS, hasToggle = true},
		{id = GAMEPASS_IDS.DOUBLE_CASH,  name = "2x Cash",       desc = "Double all cash earned from sales",          icon = ASSETS.ICON_PASS, hasToggle = false},
	},
}

-- ═══════════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════

local Utils = {}

function Utils.formatNumber(num)
	if num >= 1000000000 then
		return string.format("%.1fB", num / 1000000000)
	elseif num >= 1000000 then
		return string.format("%.1fM", num / 1000000)
	elseif num >= 1000 then
		return string.format("%.1fK", num / 1000)
	end
	return tostring(num)
end

function Utils.formatCurrency(num)
	local str = tostring(num)
	local formatted = ""
	local count = 0
	for i = #str, 1, -1 do
		count = count + 1
		formatted = str:sub(i, i) .. formatted
		if count % 3 == 0 and i > 1 then
			formatted = "," .. formatted
		end
	end
	return formatted
end

function Utils.getViewportWidth()
	local camera = workspace.CurrentCamera
	if not camera then return 1024 end
	return camera.ViewportSize.X
end

function Utils.getColumnCount()
	local width = Utils.getViewportWidth()
	if width < CONFIG.BREAKPOINT_SMALL then
		return 1
	elseif width < CONFIG.BREAKPOINT_MEDIUM then
		return 2
	else
		return 3
	end
end

function Utils.isMobile()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Utils.isConsole()
	return GuiService:IsTenFootInterface()
end

function Utils.lerp(a, b, t)
	return a + (b - a) * t
end

function Utils.clamp(value, min, max)
	if value < min then return min end
	if value > max then return max end
	return value
end

-- ═══════════════════════════════════════════════════════════════════════
-- CACHE SYSTEM
-- ═══════════════════════════════════════════════════════════════════════

local Cache = {}
Cache.__index = Cache

function Cache.new(ttl)
	local self = setmetatable({
		ttl = ttl or 300,
		store = {},
	}, Cache)
	return self
end

function Cache:set(key, value)
	self.store[key] = {
		value = value,
		timestamp = os.clock(),
	}
end

function Cache:get(key)
	local entry = self.store[key]
	if not entry then return nil end
	
	if os.clock() - entry.timestamp > self.ttl then
		self.store[key] = nil
		return nil
	end
	
	return entry.value
end

function Cache:clear(key)
	if key then
		self.store[key] = nil
	else
		self.store = {}
	end
end

-- Create cache instances
local priceCache = Cache.new(CONFIG.PRICE_CACHE_TTL)
local ownershipCache = Cache.new(CONFIG.OWNERSHIP_CACHE_TTL)

-- ═══════════════════════════════════════════════════════════════════════
-- MARKETPLACE SERVICE
-- ═══════════════════════════════════════════════════════════════════════

local Marketplace = {}

function Marketplace.getProductInfo(productId)
	local cached = priceCache:get(productId)
	if cached then return cached end
	
	local success, info = pcall(function()
		return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
	end)
	
	if success and info then
		priceCache:set(productId, info)
		return info
	end
	
	return nil
end

function Marketplace.getGamePassInfo(passId)
	local cacheKey = "pass_" .. passId
	local cached = priceCache:get(cacheKey)
	if cached then return cached end
	
	local success, info = pcall(function()
		return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
	end)
	
	if success and info then
		priceCache:set(cacheKey, info)
		return info
	end
	
	return nil
end

function Marketplace.userOwnsGamePass(passId)
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

function Marketplace.refreshPrices()
	-- Refresh cash pack prices
	for _, pack in ipairs(DATA.cashPacks) do
		local info = Marketplace.getProductInfo(pack.id)
		if info then
			pack.price = info.PriceInRobux or 0
		end
	end
	
	-- Refresh gamepass prices
	for _, pass in ipairs(DATA.gamepasses) do
		local info = Marketplace.getGamePassInfo(pass.id)
		if info then
			pass.price = info.PriceInRobux or 0
		end
	end
end

-- ═══════════════════════════════════════════════════════════════════════
-- TWEEN UTILITIES
-- ═══════════════════════════════════════════════════════════════════════

local Animator = {}

function Animator.tween(instance, properties, duration, style, direction)
	duration = duration or CONFIG.ANIM_NORMAL
	style = style or Enum.EasingStyle.Quad
	direction = direction or Enum.EasingDirection.Out
	
	local tweenInfo = TweenInfo.new(duration, style, direction)
	local tween = TweenService:Create(instance, tweenInfo, properties)
	tween:Play()
	return tween
end

function Animator.fadeIn(instance, duration)
	instance.Visible = true
	return Animator.tween(instance, {BackgroundTransparency = 0}, duration or CONFIG.ANIM_NORMAL)
end

function Animator.fadeOut(instance, duration)
	local tween = Animator.tween(instance, {BackgroundTransparency = 1}, duration or CONFIG.ANIM_NORMAL)
	tween.Completed:Connect(function()
		instance.Visible = false
	end)
	return tween
end

function Animator.slideIn(instance, targetPosition, duration)
	instance.Visible = true
	return Animator.tween(instance, {Position = targetPosition}, duration or CONFIG.ANIM_SLOW, Enum.EasingStyle.Back)
end

function Animator.scaleHover(instance, scale)
	scale = scale or 1.05
	Animator.tween(instance, {Size = instance.Size * scale}, CONFIG.ANIM_FAST, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

function Animator.scaleNormal(instance, originalSize)
	Animator.tween(instance, {Size = originalSize}, CONFIG.ANIM_FAST, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

-- ═══════════════════════════════════════════════════════════════════════
-- UI FACTORY
-- ═══════════════════════════════════════════════════════════════════════

local UI = {}

function UI.new(className, properties)
	local instance = Instance.new(className)
	
	for property, value in pairs(properties or {}) do
		if property == "Parent" then
			-- Set parent last
		elseif property == "Corner" then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = value
			corner.Parent = instance
		elseif property == "Stroke" then
			local stroke = Instance.new("UIStroke")
			stroke.Color = value.Color or Theme.colors.stroke
			stroke.Thickness = value.Thickness or 1
			stroke.Transparency = value.Transparency or 0
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = instance
		elseif property == "Padding" then
			local padding = Instance.new("UIPadding")
			padding.PaddingTop = value.Top or UDim.new(0, 0)
			padding.PaddingBottom = value.Bottom or UDim.new(0, 0)
			padding.PaddingLeft = value.Left or UDim.new(0, 0)
			padding.PaddingRight = value.Right or UDim.new(0, 0)
			padding.Parent = instance
		elseif property == "Gradient" then
			local gradient = Instance.new("UIGradient")
			gradient.Color = value.Color or ColorSequence.new(Color3.new(1, 1, 1))
			gradient.Transparency = value.Transparency or NumberSequence.new(0)
			gradient.Rotation = value.Rotation or 0
			gradient.Parent = instance
		else
			pcall(function()
				instance[property] = value
			end)
		end
	end
	
	if properties and properties.Parent then
		instance.Parent = properties.Parent
	end
	
	return instance
end

function UI.frame(props)
	local defaults = {
		BackgroundColor3 = Theme.colors.surface,
		BorderSizePixel = 0,
	}
	return UI.new("Frame", Utils.merge(defaults, props))
end

function UI.text(props)
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = Theme.colors.text,
		Font = Theme.fonts.regular,
		TextSize = Theme.sizes.base,
		TextWrapped = true,
		RichText = false,
	}
	return UI.new("TextLabel", Utils.merge(defaults, props))
end

function UI.button(props)
	local defaults = {
		BackgroundColor3 = Theme.colors.mint,
		TextColor3 = Theme.colors.textWhite,
		Font = Theme.fonts.semibold,
		TextSize = Theme.sizes.base,
		BorderSizePixel = 0,
		AutoButtonColor = false,
	}
	return UI.new("TextButton", Utils.merge(defaults, props))
end

function UI.image(props)
	local defaults = {
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		BorderSizePixel = 0,
	}
	return UI.new("ImageLabel", Utils.merge(defaults, props))
end

function UI.scroll(props)
	local defaults = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.stroke,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}
	return UI.new("ScrollingFrame", Utils.merge(defaults, props))
end

-- Merge two tables
function Utils.merge(base, override)
	local result = {}
	for k, v in pairs(base) do
		result[k] = v
	end
	for k, v in pairs(override or {}) do
		result[k] = v
	end
	return result
end

-- ═══════════════════════════════════════════════════════════════════════
-- SHOP STATE MANAGER
-- ═══════════════════════════════════════════════════════════════════════

local ShopState = {
	isOpen = false,
	isAnimating = false,
	currentTab = "cash",
	purchasesPending = {},
	connections = {},
	autoCollectEnabled = false,
}

function ShopState:setPurchasePending(id, isPending)
	self.purchasesPending[id] = isPending
end

function ShopState:isPurchasePending(id)
	return self.purchasesPending[id] == true
end

function ShopState:cleanup()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
end

-- ═══════════════════════════════════════════════════════════════════════
-- TOGGLE COMPONENT (Modern Pill Switch)
-- ═══════════════════════════════════════════════════════════════════════

local Toggle = {}
Toggle.__index = Toggle

function Toggle.new(parent, initialState, onChanged)
	local self = setmetatable({
		state = initialState or false,
		onChanged = onChanged,
	}, Toggle)
	
	-- Container
	self.container = UI.frame({
		Size = UDim2.fromOffset(52, 28),
		BackgroundColor3 = self.state and Theme.colors.mint or Theme.colors.stroke,
		Corner = UDim.new(1, 0),
		Parent = parent,
	})
	
	-- Knob
	self.knob = UI.frame({
		Size = UDim2.fromOffset(22, 22),
		Position = self.state and UDim2.new(1, -25, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.colors.textWhite,
		Corner = UDim.new(1, 0),
		Parent = self.container,
	})
	
	-- Button overlay
	self.button = UI.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Parent = self.container,
	})
	
	self.button.MouseButton1Click:Connect(function()
		self:toggle()
	end)
	
	return self
end

function Toggle:toggle()
	self.state = not self.state
	self:update()
	if self.onChanged then
		self.onChanged(self.state)
	end
end

function Toggle:setState(newState)
	if self.state == newState then return end
	self.state = newState
	self:update()
end

function Toggle:update()
	Animator.tween(self.container, {
		BackgroundColor3 = self.state and Theme.colors.mint or Theme.colors.stroke
	}, CONFIG.ANIM_FAST)
	
	Animator.tween(self.knob, {
		Position = self.state and UDim2.new(1, -25, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
	}, CONFIG.ANIM_FAST, Enum.EasingStyle.Back)
end

function Toggle:destroy()
	self.container:Destroy()
end

-- ═══════════════════════════════════════════════════════════════════════
-- SHOP CARD COMPONENT
-- ═══════════════════════════════════════════════════════════════════════

local ShopCard = {}
ShopCard.__index = ShopCard

function ShopCard.new(itemData, itemType, parent, onPurchase)
	local self = setmetatable({
		data = itemData,
		itemType = itemType,
		onPurchase = onPurchase,
	}, ShopCard)
	
	-- Main card container
	self.card = UI.frame({
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Theme.colors.surface,
		Corner = UDim.new(0, Theme.radius.lg),
		Stroke = {
			Color = itemType == "cash" and Theme.colors.mint or Theme.colors.lavender,
			Thickness = 2,
			Transparency = 0.7,
		},
		Parent = parent,
	})
	
	-- Aspect ratio constraint (card stays proportional)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1.0
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = self.card
	
	-- Content padding
	local content = UI.frame({
		Size = UDim2.new(1, -Theme.spacing.lg * 2, 1, -Theme.spacing.lg * 2),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = self.card,
	})
	
	-- Layout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, Theme.spacing.md)
	layout.Parent = content
	
	-- Icon
	self.icon = UI.image({
		Image = itemData.icon or ASSETS.ICON_CASH,
		Size = UDim2.fromOffset(64, 64),
		LayoutOrder = 1,
		Parent = content,
	})
	
	-- Name
	self.nameLabel = UI.text({
		Text = itemData.name,
		Font = Theme.fonts.bold,
		TextSize = Theme.sizes.lg,
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Parent = content,
	})
	
	-- Description
	self.descLabel = UI.text({
		Text = itemData.desc,
		Font = Theme.fonts.regular,
		TextSize = Theme.sizes.sm,
		TextColor3 = Theme.colors.textSecondary,
		Size = UDim2.new(1, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 3,
		Parent = content,
	})
	
	-- Price/Amount display
	if itemType == "cash" then
		local amountText = string.format("%s Cash", Utils.formatCurrency(itemData.amount))
		self.amountLabel = UI.text({
			Text = amountText,
			Font = Theme.fonts.semibold,
			TextSize = Theme.sizes.base,
			TextColor3 = Theme.colors.mint,
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = 4,
			Parent = content,
		})
	end
	
	-- Price label
	self.priceLabel = UI.text({
		Text = "R$ " .. (itemData.price or "..."),
		Font = Theme.fonts.medium,
		TextSize = Theme.sizes.sm,
		TextColor3 = Theme.colors.textSecondary,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 5,
		Parent = content,
	})
	
	-- Purchase button
	local buttonColor = itemType == "cash" and Theme.colors.mint or Theme.colors.lavender
	self.button = UI.button({
		Text = "Purchase",
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = buttonColor,
		TextColor3 = Theme.colors.textWhite,
		Font = Theme.fonts.bold,
		TextSize = Theme.sizes.base,
		Corner = UDim.new(0, Theme.radius.md),
		LayoutOrder = 6,
		Parent = content,
	})
	
	self.originalButtonColor = buttonColor
	
	-- Button click handler
	self.button.MouseButton1Click:Connect(function()
		if self.onPurchase then
			self.onPurchase(itemData, itemType)
		end
	end)
	
	-- Hover effects (desktop only)
	if not Utils.isMobile() then
		self.card.MouseEnter:Connect(function()
			Animator.tween(self.card, {BackgroundColor3 = Theme.colors.surfaceHover}, CONFIG.ANIM_FAST)
		end)
		
		self.card.MouseLeave:Connect(function()
			Animator.tween(self.card, {BackgroundColor3 = Theme.colors.surface}, CONFIG.ANIM_FAST)
		end)
		
		self.button.MouseEnter:Connect(function()
			if self.button.Active then
				local hoverColor = itemType == "cash" and Theme.colors.mintDark or Theme.colors.lavenderDark
				Animator.tween(self.button, {BackgroundColor3 = hoverColor}, CONFIG.ANIM_FAST)
			end
		end)
		
		self.button.MouseLeave:Connect(function()
			if self.button.Active then
				Animator.tween(self.button, {BackgroundColor3 = self.originalButtonColor}, CONFIG.ANIM_FAST)
			end
		end)
	end
	
	return self
end

function ShopCard:updatePrice(price)
	self.data.price = price
	self.priceLabel.Text = "R$ " .. tostring(price)
end

function ShopCard:setPurchasing(isPurchasing)
	if isPurchasing then
		self.button.Text = "Processing..."
		self.button.Active = false
		self.button.BackgroundColor3 = Theme.colors.stroke
	else
		self.button.Text = "Purchase"
		self.button.Active = true
		self.button.BackgroundColor3 = self.originalButtonColor
	end
end

function ShopCard:setOwned()
	self.button.Text = "Owned"
	self.button.Active = false
	self.button.BackgroundColor3 = Theme.colors.success
	
	local stroke = self.card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Theme.colors.success
	end
end

function ShopCard:destroy()
	self.card:Destroy()
end

-- ═══════════════════════════════════════════════════════════════════════
-- GAMEPASS CARD (Extended with Toggle)
-- ═══════════════════════════════════════════════════════════════════════

local GamePassCard = {}
GamePassCard.__index = GamePassCard
setmetatable(GamePassCard, {__index = ShopCard})

function GamePassCard.new(passData, parent, onPurchase, onToggle)
	local self = ShopCard.new(passData, "pass", parent, onPurchase)
	setmetatable(self, GamePassCard)
	
	self.toggle = nil
	
	-- Check ownership
	local owned = Marketplace.userOwnsGamePass(passData.id)
	if owned then
		self:setOwned()
		
		-- Add toggle if this pass supports it
		if passData.hasToggle then
			self:addToggle(onToggle)
		end
	end
	
	return self
end

function GamePassCard:addToggle(onToggle)
	if self.toggle then return end
	
	-- Get the content frame
	local content = self.card:FindFirstChild("Frame")
	if not content then return end
	
	-- Create toggle container
	local toggleContainer = UI.frame({
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		LayoutOrder = 7,
		Parent = content,
	})
	
	-- Label
	UI.text({
		Text = "Enable",
		Font = Theme.fonts.medium,
		TextSize = Theme.sizes.sm,
		TextColor3 = Theme.colors.textSecondary,
		Size = UDim2.new(1, -60, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = toggleContainer,
	})
	
	-- Toggle switch
	self.toggle = Toggle.new(toggleContainer, ShopState.autoCollectEnabled, function(state)
		if onToggle then
			onToggle(self.data.id, state)
		end
	end)
	
	self.toggle.container.Position = UDim2.new(1, -52, 0.5, 0)
	self.toggle.container.AnchorPoint = Vector2.new(0, 0.5)
end

function GamePassCard:setToggleState(state)
	if self.toggle then
		self.toggle:setState(state)
	end
end

-- ═══════════════════════════════════════════════════════════════════════
-- MAIN SHOP UI
-- ═══════════════════════════════════════════════════════════════════════

local Shop = {}
Shop.__index = Shop

function Shop.new()
	local self = setmetatable({
		gui = nil,
		blur = nil,
		panel = nil,
		header = nil,
		navButtons = {},
		pages = {},
		cards = {},
		settingsToggle = nil,
	}, Shop)
	
	self:createGui()
	self:createBlur()
	self:createPanel()
	self:createHeader()
	self:createNavigation()
	self:createPages()
	self:createFloatingButton()
	self:setupResponsive()
	self:setupInput()
	self:setupMarketplaceCallbacks()
	
	-- Initial price refresh
	Marketplace.refreshPrices()
	
	-- Start price refresh loop
	task.spawn(function()
		while true do
			task.wait(CONFIG.PRICE_REFRESH_INTERVAL)
			if ShopState.isOpen then
				Marketplace.refreshPrices()
				self:refreshPrices()
			end
		end
	end)
	
	return self
end

function Shop:createGui()
	self.gui = UI.new("ScreenGui", {
		Name = "TycoonShopUI",
		ResetOnSpawn = false,
		DisplayOrder = 1000,
		IgnoreGuiInset = false,
		Enabled = false,
		Parent = PlayerGui,
	})
end

function Shop:createBlur()
	self.blur = Instance.new("BlurEffect")
	self.blur.Name = "ShopBlur"
	self.blur.Size = 0
	self.blur.Parent = Lighting
end

function Shop:createPanel()
	-- Dim overlay
	self.dimOverlay = UI.image({
		Image = ASSETS.VIGNETTE,
		Size = UDim2.fromScale(1, 1),
		ImageColor3 = Theme.colors.dim,
		ImageTransparency = 0.3,
		ScaleType = Enum.ScaleType.Stretch,
		Parent = self.gui,
	})
	
	-- Main panel
	self.panel = UI.frame({
		Name = "MainPanel",
		Size = UDim2.fromScale(0.88, 0.82),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.bg,
		Corner = UDim.new(0, Theme.radius.xl),
		Stroke = {
			Color = Theme.colors.stroke,
			Thickness = 2,
			Transparency = 0.5,
		},
		Parent = self.gui,
	})
	
	-- Size constraints for very large/small screens
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(1400, 900)
	sizeConstraint.MinSize = Vector2.new(320, 480)
	sizeConstraint.Parent = self.panel
end

function Shop:createHeader()
	self.header = UI.frame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = Theme.colors.surfaceAlt,
		Corner = UDim.new(0, Theme.radius.xl),
		Parent = self.panel,
	})
	
	-- Header content
	local headerContent = UI.frame({
		Size = UDim2.new(1, -Theme.spacing.xl * 2, 1, 0),
		Position = UDim2.fromOffset(Theme.spacing.xl, 0),
		BackgroundTransparency = 1,
		Parent = self.header,
	})
	
	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, Theme.spacing.md)
	headerLayout.Parent = headerContent
	
	-- Shop icon
	UI.image({
		Image = ASSETS.ICON_SHOP,
		Size = UDim2.fromOffset(42, 42),
		LayoutOrder = 1,
		Parent = headerContent,
	})
	
	-- Title
	UI.text({
		Text = "Game Shop",
		Font = Theme.fonts.bold,
		TextSize = Theme.sizes.xxl,
		Size = UDim2.new(1, -100, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Parent = headerContent,
	})
	
	-- Close button
	local closeButton = UI.button({
		Text = "✕",
		Size = UDim2.fromOffset(42, 42),
		BackgroundColor3 = Theme.colors.surface,
		TextColor3 = Theme.colors.text,
		Font = Theme.fonts.bold,
		TextSize = Theme.sizes.lg,
		Corner = UDim.new(1, 0),
		Stroke = {
			Color = Theme.colors.stroke,
			Thickness = 1.5,
		},
		LayoutOrder = 3,
		Parent = headerContent,
	})
	
	closeButton.MouseButton1Click:Connect(function()
		self:close()
	end)
	
	if not Utils.isMobile() then
		closeButton.MouseEnter:Connect(function()
			Animator.tween(closeButton, {BackgroundColor3 = Theme.colors.danger}, CONFIG.ANIM_FAST)
			Animator.tween(closeButton, {TextColor3 = Theme.colors.textWhite}, CONFIG.ANIM_FAST)
		end)
		
		closeButton.MouseLeave:Connect(function()
			Animator.tween(closeButton, {BackgroundColor3 = Theme.colors.surface}, CONFIG.ANIM_FAST)
			Animator.tween(closeButton, {TextColor3 = Theme.colors.text}, CONFIG.ANIM_FAST)
		end)
	end
end

function Shop:createNavigation()
	self.nav = UI.frame({
		Name = "Navigation",
		Size = UDim2.new(0, 180, 1, -90),
		Position = UDim2.fromOffset(Theme.spacing.lg, 80),
		BackgroundColor3 = Theme.colors.surface,
		Corner = UDim.new(0, Theme.radius.lg),
		Stroke = {
			Color = Theme.colors.stroke,
			Thickness = 1,
			Transparency = 0.6,
		},
		Parent = self.panel,
	})
	
	local navLayout = Instance.new("UIListLayout")
	navLayout.FillDirection = Enum.FillDirection.Vertical
	navLayout.Padding = UDim.new(0, Theme.spacing.sm)
	navLayout.Parent = self.nav
	
	UI.new("UIPadding", {
		PaddingTop = UDim.new(0, Theme.spacing.md),
		PaddingBottom = UDim.new(0, Theme.spacing.md),
		PaddingLeft = UDim.new(0, Theme.spacing.md),
		PaddingRight = UDim.new(0, Theme.spacing.md),
		Parent = self.nav,
	})
	
	-- Tab data
	local tabs = {
		{id = "cash", name = "Cash Packs", icon = "💰", color = Theme.colors.mint},
		{id = "passes", name = "Game Passes", icon = "⭐", color = Theme.colors.lavender},
	}
	
	for _, tab in ipairs(tabs) do
		local button = UI.button({
			Text = tab.name,
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundColor3 = Theme.colors.surfaceAlt,
			TextColor3 = Theme.colors.text,
			Font = Theme.fonts.semibold,
			TextSize = Theme.sizes.base,
			Corner = UDim.new(0, Theme.radius.md),
			Parent = self.nav,
		})
		
		button.MouseButton1Click:Connect(function()
			self:switchTab(tab.id)
		end)
		
		if not Utils.isMobile() then
			button.MouseEnter:Connect(function()
				if ShopState.currentTab ~= tab.id then
					Animator.tween(button, {BackgroundColor3 = Theme.colors.surfaceHover}, CONFIG.ANIM_FAST)
				end
			end)
			
			button.MouseLeave:Connect(function()
				if ShopState.currentTab ~= tab.id then
					Animator.tween(button, {BackgroundColor3 = Theme.colors.surfaceAlt}, CONFIG.ANIM_FAST)
				end
			end)
		end
		
		self.navButtons[tab.id] = {button = button, color = tab.color}
	end
	
	-- Set initial tab
	self:switchTab("cash")
end

function Shop:createPages()
	-- Content container
	self.contentArea = UI.frame({
		Name = "ContentArea",
		Size = UDim2.new(1, -212, 1, -100),
		Position = UDim2.fromOffset(196, 80),
		BackgroundTransparency = 1,
		Parent = self.panel,
	})
	
	-- Cash page
	self.pages.cash = self:createCashPage()
	
	-- Passes page
	self.pages.passes = self:createPassesPage()
end

function Shop:createCashPage()
	local page = UI.frame({
		Name = "CashPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = true,
		Parent = self.contentArea,
	})
	
	-- Page header
	local pageHeader = UI.frame({
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = Theme.colors.surface,
		Corner = UDim.new(0, Theme.radius.md),
		Stroke = {
			Color = Theme.colors.mint,
			Thickness = 2,
			Transparency = 0.7,
		},
		Padding = {
			Left = UDim.new(0, Theme.spacing.lg),
			Right = UDim.new(0, Theme.spacing.lg),
		},
		Parent = page,
	})
	
	UI.text({
		Text = "Purchase Cash Packs",
		Font = Theme.fonts.bold,
		TextSize = Theme.sizes.xl,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pageHeader,
	})
	
	-- Scrolling area
	local scroll = UI.scroll({
		Size = UDim2.new(1, 0, 1, -60),
		Position = UDim2.fromOffset(0, 58),
		Parent = page,
	})
	
	-- Grid layout
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromScale(0.31, 0) -- Will be auto-sized by aspect ratio
	grid.CellPadding = UDim2.fromOffset(Theme.spacing.lg, Theme.spacing.lg)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	
	-- Store grid for responsive updates
	self.cashGrid = grid
	
	-- Padding
	UI.new("UIPadding", {
		PaddingTop = UDim.new(0, Theme.spacing.md),
		PaddingBottom = UDim.new(0, Theme.spacing.md),
		PaddingLeft = UDim.new(0, Theme.spacing.md),
		PaddingRight = UDim.new(0, Theme.spacing.md),
		Parent = scroll,
	})
	
	-- Create cards
	self.cards.cash = {}
	for i, pack in ipairs(DATA.cashPacks) do
		local card = ShopCard.new(pack, "cash", scroll, function(data, type)
			self:promptPurchase(data, type)
		end)
		card.card.LayoutOrder = i
		table.insert(self.cards.cash, card)
	end
	
	return page
end

function Shop:createPassesPage()
	local page = UI.frame({
		Name = "PassesPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = self.contentArea,
	})
	
	-- Page header
	local pageHeader = UI.frame({
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = Theme.colors.surface,
		Corner = UDim.new(0, Theme.radius.md),
		Stroke = {
			Color = Theme.colors.lavender,
			Thickness = 2,
			Transparency = 0.7,
		},
		Padding = {
			Left = UDim.new(0, Theme.spacing.lg),
			Right = UDim.new(0, Theme.spacing.lg),
		},
		Parent = page,
	})
	
	UI.text({
		Text = "Permanent Upgrades",
		Font = Theme.fonts.bold,
		TextSize = Theme.sizes.xl,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pageHeader,
	})
	
	-- Scrolling area
	local scroll = UI.scroll({
		Size = UDim2.new(1, 0, 1, -130),
		Position = UDim2.fromOffset(0, 58),
		Parent = page,
	})
	
	-- Grid layout
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromScale(0.31, 0)
	grid.CellPadding = UDim2.fromOffset(Theme.spacing.lg, Theme.spacing.lg)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	
	self.passGrid = grid
	
	UI.new("UIPadding", {
		PaddingTop = UDim.new(0, Theme.spacing.md),
		PaddingBottom = UDim.new(0, Theme.spacing.md),
		PaddingLeft = UDim.new(0, Theme.spacing.md),
		PaddingRight = UDim.new(0, Theme.spacing.md),
		Parent = scroll,
	})
	
	-- Create cards
	self.cards.passes = {}
	for i, pass in ipairs(DATA.gamepasses) do
		local card = GamePassCard.new(pass, scroll, 
			function(data, type)
				self:promptPurchase(data, type)
			end,
			function(passId, state)
				self:onAutoCollectToggle(passId, state)
			end
		)
		card.card.LayoutOrder = i
		table.insert(self.cards.passes, card)
	end
	
	-- Settings panel
	self:createSettingsPanel(page)
	
	return page
end

function Shop:createSettingsPanel(parent)
	local settings = UI.frame({
		Name = "Settings",
		Size = UDim2.new(1, 0, 0, 64),
		Position = UDim2.new(0, 0, 1, -68),
		BackgroundColor3 = Theme.colors.surface,
		Corner = UDim.new(0, Theme.radius.md),
		Stroke = {
			Color = Theme.colors.stroke,
			Thickness = 1,
		},
		Padding = {
			Left = UDim.new(0, Theme.spacing.lg),
			Right = UDim.new(0, Theme.spacing.lg),
		},
		Parent = parent,
	})
	
	-- Settings header
	UI.text({
		Text = "Quick Settings",
		Font = Theme.fonts.bold,
		TextSize = Theme.sizes.lg,
		Size = UDim2.new(0.5, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = settings,
	})
	
	-- Auto collect toggle container
	local toggleContainer = UI.frame({
		Size = UDim2.new(0, 200, 0, 40),
		Position = UDim2.new(1, -200, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Parent = settings,
	})
	
	UI.text({
		Text = "Auto Collect",
		Font = Theme.fonts.medium,
		TextSize = Theme.sizes.base,
		TextColor3 = Theme.colors.textSecondary,
		Size = UDim2.new(1, -60, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = toggleContainer,
	})
	
	-- Toggle
	self.settingsToggle = Toggle.new(toggleContainer, ShopState.autoCollectEnabled, function(state)
		self:onAutoCollectToggle(GAMEPASS_IDS.AUTO_COLLECT, state)
	end)
	
	self.settingsToggle.container.Position = UDim2.new(1, -52, 0.5, 0)
	self.settingsToggle.container.AnchorPoint = Vector2.new(0, 0.5)
	
	-- Hide if not owned
	local ownsAutoCollect = Marketplace.userOwnsGamePass(GAMEPASS_IDS.AUTO_COLLECT)
	settings.Visible = ownsAutoCollect
	
	self.settingsPanel = settings
end

function Shop:createFloatingButton()
	local buttonGui = UI.new("ScreenGui", {
		Name = "ShopToggleButton",
		ResetOnSpawn = false,
		DisplayOrder = 999,
		Parent = PlayerGui,
	})
	
	local button = UI.button({
		Text = "🛒 Shop",
		Size = UDim2.fromOffset(140, 50),
		Position = UDim2.new(1, -20 - CONFIG.SAFE_MARGIN_X * 1000, 1, -20 - CONFIG.SAFE_MARGIN_Y * 1000),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = Theme.colors.mint,
		TextColor3 = Theme.colors.textWhite,
		Font = Theme.fonts.bold,
		TextSize = Theme.sizes.lg,
		Corner = UDim.new(1, 0),
		Stroke = {
			Color = Theme.colors.mintDark,
			Thickness = 2,
		},
		Parent = buttonGui,
	})
	
	button.MouseButton1Click:Connect(function()
		self:toggle()
	end)
	
	if not Utils.isMobile() then
		button.MouseEnter:Connect(function()
			Animator.tween(button, {
				Size = UDim2.fromOffset(150, 54),
				BackgroundColor3 = Theme.colors.mintDark
			}, CONFIG.ANIM_FAST, Enum.EasingStyle.Back)
		end)
		
		button.MouseLeave:Connect(function()
			Animator.tween(button, {
				Size = UDim2.fromOffset(140, 50),
				BackgroundColor3 = Theme.colors.mint
			}, CONFIG.ANIM_FAST, Enum.EasingStyle.Back)
		end)
	end
	
	self.floatingButton = button
end

function Shop:setupResponsive()
	local camera = workspace.CurrentCamera
	if not camera then return end
	
	local function updateGridColumns()
		local columns = Utils.getColumnCount()
		
		-- Update cash grid
		if self.cashGrid then
			local cellScale = columns == 1 and 0.96 or (columns == 2 and 0.47 or 0.31)
			self.cashGrid.CellSize = UDim2.fromScale(cellScale, 0)
		end
		
		-- Update pass grid
		if self.passGrid then
			local cellScale = columns == 1 and 0.96 or (columns == 2 and 0.47 or 0.31)
			self.passGrid.CellSize = UDim2.fromScale(cellScale, 0)
		end
	end
	
	-- Initial update
	updateGridColumns()
	
	-- Watch for viewport changes
	local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		updateGridColumns()
	end)
	
	table.insert(ShopState.connections, connection)
end

function Shop:setupInput()
	-- Keyboard/gamepad input
	local connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.M then
			self:toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and ShopState.isOpen then
			self:close()
		elseif input.KeyCode == Enum.KeyCode.ButtonX then
			self:toggle()
		end
	end)
	
	table.insert(ShopState.connections, connection)
end

function Shop:setupMarketplaceCallbacks()
	-- Product purchase finished
	local productConnection = MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
		if userId ~= Player.UserId then return end
		
		ShopState:setPurchasePending(productId, false)
		
		-- Update UI
		for _, card in ipairs(self.cards.cash or {}) do
			if card.data.id == productId then
				card:setPurchasing(false)
				break
			end
		end
		
		-- Notify server if purchased
		if wasPurchased and Remotes then
			local grantEvent = Remotes:FindFirstChild("GrantProductCurrency")
			if grantEvent and grantEvent:IsA("RemoteEvent") then
				grantEvent:FireServer(productId)
			end
		end
	end)
	
	-- Gamepass purchase finished
	local passConnection = MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if player ~= Player then return end
		
		ShopState:setPurchasePending(passId, false)
		
		if wasPurchased then
			-- Clear ownership cache
			ownershipCache:clear()
			
			-- Update UI
			for _, card in ipairs(self.cards.passes or {}) do
				if card.data.id == passId then
					card:setOwned()
					
					-- Add toggle if this is auto collect
					if passId == GAMEPASS_IDS.AUTO_COLLECT and card.data.hasToggle then
						card:addToggle(function(id, state)
							self:onAutoCollectToggle(id, state)
						end)
						
						-- Show settings panel
						if self.settingsPanel then
							self.settingsPanel.Visible = true
						end
					end
					break
				end
			end
			
			-- Notify server
			if Remotes then
				local purchaseEvent = Remotes:FindFirstChild("GamepassPurchased")
				if purchaseEvent and purchaseEvent:IsA("RemoteEvent") then
					purchaseEvent:FireServer(passId)
				end
			end
		else
			-- Reset button
			for _, card in ipairs(self.cards.passes or {}) do
				if card.data.id == passId then
					card:setPurchasing(false)
					break
				end
			end
		end
	end)
	
	table.insert(ShopState.connections, productConnection)
	table.insert(ShopState.connections, passConnection)
end

function Shop:switchTab(tabId)
	if ShopState.currentTab == tabId then return end
	
	ShopState.currentTab = tabId
	
	-- Update nav buttons
	for id, data in pairs(self.navButtons) do
		local isActive = (id == tabId)
		Animator.tween(data.button, {
			BackgroundColor3 = isActive and data.color or Theme.colors.surfaceAlt,
			TextColor3 = isActive and Theme.colors.textWhite or Theme.colors.text,
		}, CONFIG.ANIM_FAST)
	end
	
	-- Update pages
	for id, page in pairs(self.pages) do
		page.Visible = (id == tabId)
	end
end

function Shop:open()
	if ShopState.isOpen or ShopState.isAnimating then return end
	
	ShopState.isAnimating = true
	ShopState.isOpen = true
	
	-- Refresh data
	Marketplace.refreshPrices()
	self:refreshOwnership()
	self:refreshPrices()
	
	-- Enable GUI
	self.gui.Enabled = true
	
	-- Animate blur
	Animator.tween(self.blur, {Size = 24}, CONFIG.ANIM_NORMAL)
	
	-- Animate panel (slide + fade)
	self.panel.Position = UDim2.fromScale(0.5, 0.55)
	self.panel.BackgroundTransparency = 0.3
	
	Animator.tween(self.panel, {
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0,
	}, CONFIG.ANIM_SLOW, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	
	task.delay(CONFIG.ANIM_SLOW, function()
		ShopState.isAnimating = false
	end)
end

function Shop:close()
	if not ShopState.isOpen or ShopState.isAnimating then return end
	
	ShopState.isAnimating = true
	ShopState.isOpen = false
	
	-- Animate blur
	Animator.tween(self.blur, {Size = 0}, CONFIG.ANIM_NORMAL)
	
	-- Animate panel
	Animator.tween(self.panel, {
		Position = UDim2.fromScale(0.5, 0.55),
		BackgroundTransparency = 0.3,
	}, CONFIG.ANIM_NORMAL, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	
	task.delay(CONFIG.ANIM_NORMAL, function()
		self.gui.Enabled = false
		ShopState.isAnimating = false
	end)
end

function Shop:toggle()
	if ShopState.isOpen then
		self:close()
	else
		self:open()
	end
end

function Shop:promptPurchase(itemData, itemType)
	-- Prevent double-purchase
	if ShopState:isPurchasePending(itemData.id) then return end
	
	if itemType == "pass" then
		-- Check ownership first
		if Marketplace.userOwnsGamePass(itemData.id) then return end
		
		-- Set pending
		ShopState:setPurchasePending(itemData.id, true)
		
		-- Update UI
		for _, card in ipairs(self.cards.passes or {}) do
			if card.data.id == itemData.id then
				card:setPurchasing(true)
				break
			end
		end
		
		-- Prompt purchase
		local success = pcall(function()
			MarketplaceService:PromptGamePassPurchase(Player, itemData.id)
		end)
		
		if not success then
			ShopState:setPurchasePending(itemData.id, false)
			for _, card in ipairs(self.cards.passes or {}) do
				if card.data.id == itemData.id then
					card:setPurchasing(false)
					break
				end
			end
		end
		
		-- Timeout fallback
		task.delay(CONFIG.PURCHASE_TIMEOUT, function()
			if ShopState:isPurchasePending(itemData.id) then
				ShopState:setPurchasePending(itemData.id, false)
				for _, card in ipairs(self.cards.passes or {}) do
					if card.data.id == itemData.id then
						card:setPurchasing(false)
						break
					end
				end
			end
		end)
		
	elseif itemType == "cash" then
		-- Set pending
		ShopState:setPurchasePending(itemData.id, true)
		
		-- Prompt purchase
		local success = pcall(function()
			MarketplaceService:PromptProductPurchase(Player, itemData.id)
		end)
		
		if not success then
			ShopState:setPurchasePending(itemData.id, false)
		end
		
		-- Timeout fallback
		task.delay(CONFIG.PURCHASE_TIMEOUT, function()
			ShopState:setPurchasePending(itemData.id, false)
		end)
	end
end

function Shop:onAutoCollectToggle(passId, state)
	ShopState.autoCollectEnabled = state
	
	-- Sync all toggles
	for _, card in ipairs(self.cards.passes or {}) do
		if card.data.id == passId and card.toggle then
			card:setToggleState(state)
		end
	end
	
	if self.settingsToggle then
		self.settingsToggle:setState(state)
	end
	
	-- Notify server
	if Remotes then
		local toggleEvent = Remotes:FindFirstChild("AutoCollectToggle")
		if toggleEvent and toggleEvent:IsA("RemoteEvent") then
			toggleEvent:FireServer(state)
		end
	end
end

function Shop:refreshOwnership()
	ownershipCache:clear()
	
	for _, card in ipairs(self.cards.passes or {}) do
		local owned = Marketplace.userOwnsGamePass(card.data.id)
		if owned then
			card:setOwned()
			
			if card.data.hasToggle and not card.toggle then
				card:addToggle(function(id, state)
					self:onAutoCollectToggle(id, state)
				end)
			end
		end
	end
	
	-- Update settings panel visibility
	if self.settingsPanel then
		local ownsAutoCollect = Marketplace.userOwnsGamePass(GAMEPASS_IDS.AUTO_COLLECT)
		self.settingsPanel.Visible = ownsAutoCollect
		
		-- Fetch toggle state from server
		if ownsAutoCollect and Remotes then
			local getStateFunc = Remotes:FindFirstChild("GetAutoCollectState")
			if getStateFunc and getStateFunc:IsA("RemoteFunction") then
				local success, state = pcall(function()
					return getStateFunc:InvokeServer()
				end)
				if success and typeof(state) == "boolean" then
					ShopState.autoCollectEnabled = state
					if self.settingsToggle then
						self.settingsToggle:setState(state)
					end
				end
			end
		end
	end
end

function Shop:refreshPrices()
	-- Update cash cards
	for _, card in ipairs(self.cards.cash or {}) do
		if card.data.price then
			card:updatePrice(card.data.price)
		end
	end
	
	-- Update pass cards
	for _, card in ipairs(self.cards.passes or {}) do
		if card.data.price then
			card:updatePrice(card.data.price)
		end
	end
end

function Shop:destroy()
	ShopState:cleanup()
	
	if self.gui then
		self.gui:Destroy()
	end
	
	if self.blur then
		self.blur:Destroy()
	end
	
	if self.floatingButton and self.floatingButton.Parent then
		self.floatingButton.Parent:Destroy()
	end
end

-- ═══════════════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════

local shop = Shop.new()

-- Handle character respawns
Player.CharacterAdded:Connect(function()
	task.wait(1)
	-- Ensure floating button persists
	if not PlayerGui:FindFirstChild("ShopToggleButton") then
		shop:createFloatingButton()
	end
end)

-- Expose global functions (optional)
_G.TycoonShop = {
	Open = function() shop:open() end,
	Close = function() shop:close() end,
	Toggle = function() shop:toggle() end,
}

print(string.format("[TycoonShop] Modern Cute UI initialized (v%s) ✓", CONFIG.VERSION))

return shop
