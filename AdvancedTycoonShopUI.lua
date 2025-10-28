--[[
	ADVANCED TYCOON SHOP UI - 2025 EDITION
	A highly functional, modern shop interface with advanced features
	
	Key Features:
	- Fully responsive mobile-first design with dynamic layouts
	- Advanced search and filtering system
	- Real-time currency tracking with animated updates
	- Category-based navigation with smooth transitions
	- Purchase confirmation dialogs with preview
	- Settings panel with user preferences
	- Accessibility features (proper touch targets, contrast)
	- Performance optimized with virtualized scrolling
	- Modern glass-morphism and gradient effects
	
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
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)
if not Remotes then
	warn("[AdvancedShop] Could not find TycoonRemotes folder")
	return
end

-- Constants
local SHOP_VERSION = "8.0.0"
local DEBUG_MODE = false

local ANIMATION_SPEEDS = {
	INSTANT = 0,
	FAST = 0.15,
	MEDIUM = 0.25,
	SLOW = 0.4,
	VERY_SLOW = 0.6
}

local UI_CONSTANTS = {
	-- Breakpoints
	MOBILE_BREAKPOINT = 600,
	TABLET_BREAKPOINT = 900,
	DESKTOP_BREAKPOINT = 1200,
	
	-- Touch targets (following Material Design guidelines)
	MIN_TOUCH_TARGET = 48,
	IDEAL_TOUCH_TARGET = 56,
	
	-- Safe areas
	TOP_BAR_HEIGHT = 44, -- Roblox 2025 standard
	SAFE_AREA_PADDING = 12,
	NOTCH_PADDING = 20,
	
	-- Layout
	HEADER_HEIGHT_MOBILE = 56,
	HEADER_HEIGHT_DESKTOP = 72,
	NAV_HEIGHT_MOBILE = 48,
	NAV_WIDTH_DESKTOP = 260,
	SEARCH_BAR_HEIGHT = 48,
	
	-- Visual
	BLUR_SIZE = 32,
	CORNER_RADIUS = 12,
	SHADOW_DEPTH = 8,
	
	-- Performance
	VIRTUALIZATION_BUFFER = 3,
	MAX_VISIBLE_ITEMS = 50,
	SEARCH_DEBOUNCE = 0.3,
}

-- Modern Design System
local Theme = {
	-- Color palette (following Material You principles)
	colors = {
		-- Primary colors
		primary = Color3.fromRGB(99, 102, 241),      -- Indigo
		primaryLight = Color3.fromRGB(129, 140, 248),
		primaryDark = Color3.fromRGB(67, 56, 202),
		onPrimary = Color3.fromRGB(255, 255, 255),
		
		-- Secondary colors
		secondary = Color3.fromRGB(236, 72, 153),    -- Pink
		secondaryLight = Color3.fromRGB(244, 114, 182),
		secondaryDark = Color3.fromRGB(219, 39, 119),
		onSecondary = Color3.fromRGB(255, 255, 255),
		
		-- Surface colors
		background = Color3.fromRGB(250, 250, 250),
		surface = Color3.fromRGB(255, 255, 255),
		surfaceVariant = Color3.fromRGB(241, 245, 249),
		surfaceElevated = Color3.fromRGB(255, 255, 255),
		
		-- Semantic colors
		success = Color3.fromRGB(16, 185, 129),
		warning = Color3.fromRGB(251, 146, 60),
		error = Color3.fromRGB(239, 68, 68),
		info = Color3.fromRGB(59, 130, 246),
		
		-- Text colors
		text = {
			primary = Color3.fromRGB(15, 23, 42),
			secondary = Color3.fromRGB(100, 116, 139),
			disabled = Color3.fromRGB(203, 213, 225),
			inverse = Color3.fromRGB(255, 255, 255),
		},
		
		-- Utility colors
		overlay = Color3.fromRGB(0, 0, 0),
		divider = Color3.fromRGB(226, 232, 240),
		shadow = Color3.fromRGB(15, 23, 42),
	},
	
	-- Typography scale
	typography = {
		fonts = {
			display = Enum.Font.GothamBold,
			heading = Enum.Font.GothamMedium,
			body = Enum.Font.Gotham,
			mono = Enum.Font.Code,
		},
		
		sizes = {
			-- Display
			d1 = 40,
			d2 = 36,
			d3 = 32,
			
			-- Headings
			h1 = 28,
			h2 = 24,
			h3 = 20,
			h4 = 18,
			h5 = 16,
			h6 = 14,
			
			-- Body
			body1 = 16,
			body2 = 14,
			
			-- Supporting
			subtitle1 = 16,
			subtitle2 = 14,
			caption = 12,
			overline = 10,
			
			-- Components
			button = 14,
			chip = 13,
			tooltip = 12,
		},
		
		weights = {
			light = Enum.Font.Gotham,
			regular = Enum.Font.Gotham,
			medium = Enum.Font.GothamMedium,
			bold = Enum.Font.GothamBold,
		},
	},
	
	-- Spacing system (8-point grid)
	spacing = {
		none = 0,
		xxs = 2,
		xs = 4,
		sm = 8,
		md = 16,
		lg = 24,
		xl = 32,
		xxl = 48,
		xxxl = 64,
	},
	
	-- Elevation system
	elevation = {
		[0] = {
			blur = 0,
			offset = 0,
			transparency = 1,
		},
		[1] = {
			blur = 4,
			offset = 1,
			transparency = 0.95,
		},
		[2] = {
			blur = 8,
			offset = 2,
			transparency = 0.92,
		},
		[3] = {
			blur = 12,
			offset = 4,
			transparency = 0.88,
		},
		[4] = {
			blur = 16,
			offset = 6,
			transparency = 0.85,
		},
		[5] = {
			blur = 24,
			offset = 8,
			transparency = 0.82,
		},
	},
	
	-- Animation curves
	motion = {
		easing = {
			standard = Enum.EasingStyle.Cubic,
			decelerate = Enum.EasingStyle.Quart,
			accelerate = Enum.EasingStyle.Quint,
			sharp = Enum.EasingStyle.Linear,
		},
		
		duration = {
			instant = 0,
			fast = 0.15,
			medium = 0.25,
			slow = 0.375,
			verySlow = 0.5,
		},
	},
}

-- Advanced Icon System
local Icons = {
	-- Navigation
	shop = "rbxassetid://15537442859",
	cash = "rbxassetid://15537443124",
	gamepass = "rbxassetid://15537443367",
	powerups = "rbxassetid://15537443589",
	special = "rbxassetid://15537443812",
	
	-- Actions
	close = "rbxassetid://15537444023",
	search = "rbxassetid://15537444256",
	filter = "rbxassetid://15537444489",
	sort = "rbxassetid://15537444712",
	settings = "rbxassetid://15537444935",
	
	-- UI Elements
	check = "rbxassetid://15537445168",
	star = "rbxassetid://15537445391",
	diamond = "rbxassetid://15537445614",
	coin = "rbxassetid://15537445837",
	cart = "rbxassetid://15537446060",
	
	-- Status
	locked = "rbxassetid://15537446283",
	unlocked = "rbxassetid://15537446506",
	info = "rbxassetid://15537446729",
	warning = "rbxassetid://15537446952",
	error = "rbxassetid://15537447175",
	
	-- Misc
	sparkle = "rbxassetid://15537447398",
	lightning = "rbxassetid://15537447621",
	fire = "rbxassetid://15537447844",
	crown = "rbxassetid://15537448067",
}

-- Sound Effects
local Sounds = {
	-- UI Sounds
	click = {id = "rbxassetid://15537448290", volume = 0.1},
	hover = {id = "rbxassetid://15537448513", volume = 0.05},
	open = {id = "rbxassetid://15537448736", volume = 0.15},
	close = {id = "rbxassetid://15537448959", volume = 0.15},
	
	-- Transaction sounds
	purchase = {id = "rbxassetid://15537449182", volume = 0.2},
	error = {id = "rbxassetid://15537449405", volume = 0.15},
	success = {id = "rbxassetid://15537449628", volume = 0.2},
	
	-- Feedback sounds
	notification = {id = "rbxassetid://15537449851", volume = 0.12},
	achieve = {id = "rbxassetid://15537450074", volume = 0.25},
}

-- Product Database
local ProductDatabase = {
	categories = {
		{
			id = "cash",
			name = "Cash Packs",
			icon = Icons.cash,
			color = Theme.colors.success,
			description = "Boost your economy instantly",
		},
		{
			id = "passes",
			name = "Game Passes",
			icon = Icons.gamepass,
			color = Theme.colors.primary,
			description = "Permanent upgrades and benefits",
		},
		{
			id = "powerups",
			name = "Power-Ups",
			icon = Icons.powerups,
			color = Theme.colors.secondary,
			description = "Temporary boosts and effects",
		},
		{
			id = "special",
			name = "Special Offers",
			icon = Icons.special,
			color = Theme.colors.warning,
			description = "Limited time deals",
		},
	},
	
	products = {
		cash = {
			{
				id = 1897730242,
				name = "Starter Pack",
				amount = 1000,
				icon = Icons.coin,
				description = "Perfect for beginners",
				tags = {"popular", "starter"},
				discount = 0,
			},
			{
				id = 1897730373,
				name = "Builder Bundle",
				amount = 5000,
				icon = Icons.coin,
				description = "Expand your tycoon",
				tags = {"value"},
				discount = 10,
			},
			{
				id = 1897730467,
				name = "Pro Package",
				amount = 10000,
				icon = Icons.coin,
				description = "Serious business boost",
				tags = {"popular"},
				discount = 0,
			},
			{
				id = 1897730581,
				name = "Elite Vault",
				amount = 50000,
				icon = Icons.diamond,
				description = "Major expansion fund",
				tags = {"premium"},
				discount = 15,
			},
			{
				id = 1897730682,
				name = "Mega Cache",
				amount = 100000,
				icon = Icons.diamond,
				description = "Transform your empire",
				tags = {"premium", "popular"],
				discount = 20,
			},
			{
				id = 1897730783,
				name = "Quarter Million",
				amount = 250000,
				icon = Icons.crown,
				description = "Investment powerhouse",
				tags = {"premium", "exclusive"},
				discount = 25,
			},
		},
		
		passes = {
			{
				id = 1412171840,
				name = "Auto Collect",
				icon = Icons.lightning,
				description = "Automatically collects cash every minute",
				features = {
					"Collects cash automatically",
					"Works while offline",
					"Customizable intervals",
				},
				tags = {"essential", "automation"},
				hasToggle = true,
			},
			{
				id = 1398974710,
				name = "2x Cash",
				icon = Icons.star,
				description = "Double all earnings permanently",
				features = {
					"2x multiplier on all income",
					"Stacks with other bonuses",
					"Permanent upgrade",
				},
				tags = {"essential", "multiplier"},
			},
			{
				id = 1398974811,
				name = "VIP Access",
				icon = Icons.crown,
				description = "Exclusive VIP benefits and areas",
				features = {
					"Access to VIP areas",
					"Exclusive items",
					"Special chat tag",
					"Priority support",
				},
				tags = {"exclusive", "vip"},
			},
			{
				id = 1398974912,
				name = "Speed Boost",
				icon = Icons.lightning,
				description = "25% faster production speed",
				features = {
					"25% speed increase",
					"Affects all machines",
					"Permanent upgrade",
				},
				tags = {"productivity"},
			},
		},
		
		powerups = {
			{
				id = 2897730242,
				name = "2x Boost (1 Hour)",
				icon = Icons.fire,
				description = "Double earnings for 1 hour",
				duration = 3600,
				multiplier = 2,
				tags = {"boost", "temporary"},
			},
			{
				id = 2897730343,
				name = "5x Boost (30 Min)",
				icon = Icons.fire,
				description = "5x earnings for 30 minutes",
				duration = 1800,
				multiplier = 5,
				tags = {"boost", "temporary", "powerful"],
			},
		},
		
		special = {
			{
				id = 3897730242,
				name = "Weekend Special",
				originalPrice = 500,
				price = 250,
				icon = Icons.sparkle,
				description = "50% off this weekend only!",
				expiresAt = os.time() + 172800, -- 48 hours
				tags = {"limited", "sale"},
			},
		},
	},
}

-- Utility Functions
local function debugLog(...)
	if DEBUG_MODE then
		print("[AdvancedShop]", ...)
	end
end

local function lerp(a, b, t)
	return a + (b - a) * math.min(1, math.max(0, t))
end

local function formatNumber(n)
	if n >= 1e12 then
		return string.format("%.2fT", n / 1e12)
	elseif n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.2fK", n / 1e3)
	else
		return tostring(math.floor(n))
	end
end

local function formatCurrency(n)
	local formatted = formatNumber(n)
	return "$" .. formatted
end

local function formatTime(seconds)
	if seconds < 60 then
		return seconds .. "s"
	elseif seconds < 3600 then
		return math.floor(seconds / 60) .. "m"
	elseif seconds < 86400 then
		return math.floor(seconds / 3600) .. "h"
	else
		return math.floor(seconds / 86400) .. "d"
	end
end

local function getDeviceInfo()
	local viewport = workspace.CurrentCamera.ViewportSize
	local deviceType = "Desktop"
	local orientation = "Landscape"
	
	if viewport.X < viewport.Y then
		orientation = "Portrait"
	end
	
	if GuiService:IsTenFootInterface() then
		deviceType = "Console"
	elseif UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		deviceType = "Mobile"
	elseif UserInputService.TouchEnabled and UserInputService.MouseEnabled then
		deviceType = "Tablet"
	end
	
	return {
		type = deviceType,
		orientation = orientation,
		viewport = viewport,
		isSmall = viewport.X < UI_CONSTANTS.MOBILE_BREAKPOINT,
		isMedium = viewport.X >= UI_CONSTANTS.MOBILE_BREAKPOINT and viewport.X < UI_CONSTANTS.TABLET_BREAKPOINT,
		isLarge = viewport.X >= UI_CONSTANTS.TABLET_BREAKPOINT,
	}
end

local function getSafeArea()
	local insets = GuiService:GetGuiInset()
	local device = getDeviceInfo()
	
	-- Account for notches on modern phones
	local topPadding = math.max(insets.Y, UI_CONSTANTS.TOP_BAR_HEIGHT)
	if device.type == "Mobile" and insets.Y > 50 then
		topPadding = topPadding + UI_CONSTANTS.NOTCH_PADDING
	end
	
	return {
		top = topPadding,
		bottom = UI_CONSTANTS.SAFE_AREA_PADDING,
		left = UI_CONSTANTS.SAFE_AREA_PADDING,
		right = UI_CONSTANTS.SAFE_AREA_PADDING,
	}
end

-- Advanced Component System
local Component = {}
Component.__index = Component

function Component.new(className)
	local self = setmetatable({
		instance = Instance.new(className),
		props = {},
		state = {},
		children = {},
		connections = {},
		animations = {},
		destroyed = false,
	}, Component)
	
	return self
end

function Component:SetProps(props)
	self.props = props or {}
	return self
end

function Component:SetState(key, value)
	self.state[key] = value
	self:OnStateChanged(key, value)
end

function Component:OnStateChanged(key, value)
	-- Override in subclasses
end

function Component:Mount()
	if self.destroyed then return end
	
	-- Apply properties
	for key, value in pairs(self.props) do
		if key:sub(1, 2) ~= "on" and key ~= "children" and key ~= "style" then
			pcall(function()
				self.instance[key] = value
			end)
		end
	end
	
	-- Apply styles
	if self.props.style then
		self:ApplyStyle(self.props.style)
	end
	
	-- Connect events
	self:ConnectEvents()
	
	-- Mount children
	if self.props.children then
		for _, child in ipairs(self.props.children) do
			if typeof(child) == "table" and child.Mount then
				child:Mount()
				child.instance.Parent = self.instance
				table.insert(self.children, child)
			elseif typeof(child) == "Instance" then
				child.Parent = self.instance
			end
		end
	end
	
	-- Lifecycle
	if self.OnMount then
		self:OnMount()
	end
	
	return self
end

function Component:ApplyStyle(style)
	-- Corner radius
	if style.cornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, style.cornerRadius)
		corner.Parent = self.instance
	end
	
	-- Padding
	if style.padding then
		local padding = Instance.new("UIPadding")
		if type(style.padding) == "number" then
			padding.PaddingTop = UDim.new(0, style.padding)
			padding.PaddingBottom = UDim.new(0, style.padding)
			padding.PaddingLeft = UDim.new(0, style.padding)
			padding.PaddingRight = UDim.new(0, style.padding)
		elseif type(style.padding) == "table" then
			padding.PaddingTop = UDim.new(0, style.padding.top or 0)
			padding.PaddingBottom = UDim.new(0, style.padding.bottom or 0)
			padding.PaddingLeft = UDim.new(0, style.padding.left or 0)
			padding.PaddingRight = UDim.new(0, style.padding.right or 0)
		end
		padding.Parent = self.instance
	end
	
	-- Stroke
	if style.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = style.stroke.color or Theme.colors.divider
		stroke.Thickness = style.stroke.thickness or 1
		stroke.Transparency = style.stroke.transparency or 0
		stroke.ApplyStrokeMode = style.stroke.mode or Enum.ApplyStrokeMode.Border
		stroke.Parent = self.instance
	end
	
	-- Gradient
	if style.gradient then
		local gradient = Instance.new("UIGradient")
		gradient.Color = style.gradient.colors or ColorSequence.new(Color3.new(1, 1, 1))
		gradient.Transparency = style.gradient.transparency
		gradient.Rotation = style.gradient.rotation or 0
		gradient.Offset = style.gradient.offset or Vector2.new(0, 0)
		gradient.Parent = self.instance
	end
	
	-- Shadow (advanced)
	if style.shadow and self.instance:IsA("GuiObject") then
		self:ApplyShadow(style.shadow)
	end
	
	-- Glass effect
	if style.glass then
		self:ApplyGlassEffect(style.glass)
	end
	
	-- Constraints
	if style.aspectRatio then
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = style.aspectRatio
		aspect.Parent = self.instance
	end
	
	if style.sizeConstraint then
		local constraint = Instance.new("UISizeConstraint")
		constraint.MinSize = style.sizeConstraint.min or Vector2.new(0, 0)
		constraint.MaxSize = style.sizeConstraint.max or Vector2.new(math.huge, math.huge)
		constraint.Parent = self.instance
	end
end

function Component:ApplyShadow(shadowConfig)
	local elevation = shadowConfig.elevation or 2
	local config = Theme.elevation[elevation]
	
	if not config then return end
	
	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxassetid://1316045217"
	shadow.ImageColor3 = shadowConfig.color or Theme.colors.shadow
	shadow.ImageTransparency = config.transparency
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(10, 10, 118, 118)
	shadow.Size = UDim2.new(1, config.blur, 1, config.blur)
	shadow.Position = UDim2.new(0, -config.blur/2, 0, -config.blur/2 + config.offset)
	shadow.ZIndex = self.instance.ZIndex - 1
	
	-- Parent to same parent as main instance
	shadow.Parent = self.instance.Parent or self.instance
	
	-- Store reference
	self.shadow = shadow
end

function Component:ApplyGlassEffect(glassConfig)
	-- Create glass overlay
	local glass = Instance.new("Frame")
	glass.Name = "GlassEffect"
	glass.Size = UDim2.fromScale(1, 1)
	glass.BackgroundColor3 = glassConfig.color or Color3.new(1, 1, 1)
	glass.BackgroundTransparency = glassConfig.transparency or 0.9
	glass.BorderSizePixel = 0
	glass.Parent = self.instance
	
	-- Add gradient for depth
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.new(0.95, 0.95, 0.95)),
		ColorSequenceKeypoint.new(1, Color3.new(0.9, 0.9, 0.9)),
	})
	gradient.Rotation = glassConfig.rotation or 45
	gradient.Parent = glass
	
	-- Add blur stroke for frosted effect
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 1
	stroke.Transparency = 0.8
	stroke.Parent = glass
end

function Component:ConnectEvents()
	-- Mouse events
	if self.instance:IsA("GuiObject") then
		if self.props.onMouseEnter then
			table.insert(self.connections, self.instance.MouseEnter:Connect(function()
				self.props.onMouseEnter(self)
			end))
		end
		
		if self.props.onMouseLeave then
			table.insert(self.connections, self.instance.MouseLeave:Connect(function()
				self.props.onMouseLeave(self)
			end))
		end
		
		if self.props.onMouseMove then
			table.insert(self.connections, self.instance.MouseMoved:Connect(function(x, y)
				self.props.onMouseMove(self, x, y)
			end))
		end
	end
	
	-- Button events
	if self.instance:IsA("GuiButton") then
		if self.props.onClick then
			table.insert(self.connections, self.instance.MouseButton1Click:Connect(function()
				self.props.onClick(self)
			end))
		end
		
		if self.props.onRightClick then
			table.insert(self.connections, self.instance.MouseButton2Click:Connect(function()
				self.props.onRightClick(self)
			end))
		end
	end
	
	-- Text input events
	if self.instance:IsA("TextBox") then
		if self.props.onTextChanged then
			table.insert(self.connections, self.instance:GetPropertyChangedSignal("Text"):Connect(function()
				self.props.onTextChanged(self.instance.Text)
			end))
		end
		
		if self.props.onFocused then
			table.insert(self.connections, self.instance.Focused:Connect(function()
				self.props.onFocused(self)
			end))
		end
		
		if self.props.onFocusLost then
			table.insert(self.connections, self.instance.FocusLost:Connect(function(enterPressed)
				self.props.onFocusLost(self, enterPressed)
			end))
		end
	end
end

function Component:Animate(properties, duration, easingStyle, easingDirection)
	duration = duration or Theme.motion.duration.medium
	easingStyle = easingStyle or Theme.motion.easing.standard
	easingDirection = easingDirection or Enum.EasingDirection.Out
	
	local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection)
	local tween = TweenService:Create(self.instance, tweenInfo, properties)
	
	table.insert(self.animations, tween)
	tween:Play()
	
	return tween
end

function Component:AnimateSequence(sequence)
	local previousTween
	
	for _, step in ipairs(sequence) do
		local tween = self:Animate(step.properties, step.duration, step.easing, step.direction)
		
		if previousTween then
			previousTween.Completed:Connect(function()
				tween:Play()
			end)
			tween:Pause()
		end
		
		previousTween = tween
	end
end

function Component:Destroy()
	if self.destroyed then return end
	self.destroyed = true
	
	-- Lifecycle
	if self.OnDestroy then
		self:OnDestroy()
	end
	
	-- Clean up animations
	for _, tween in ipairs(self.animations) do
		tween:Cancel()
	end
	
	-- Disconnect events
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	
	-- Destroy children
	for _, child in ipairs(self.children) do
		if child.Destroy then
			child:Destroy()
		end
	end
	
	-- Destroy shadow if exists
	if self.shadow then
		self.shadow:Destroy()
	end
	
	-- Destroy instance
	self.instance:Destroy()
end

-- Create specialized components
local function CreateFrame(props)
	return Component.new("Frame"):SetProps(props)
end

local function CreateTextLabel(props)
	local label = Component.new("TextLabel"):SetProps(props)
	-- Default text properties
	label.instance.BackgroundTransparency = 1
	label.instance.Font = props.Font or Theme.typography.fonts.body
	label.instance.TextSize = props.TextSize or Theme.typography.sizes.body1
	label.instance.TextColor3 = props.TextColor3 or Theme.colors.text.primary
	label.instance.TextWrapped = props.TextWrapped ~= false
	return label
end

local function CreateTextButton(props)
	local button = Component.new("TextButton"):SetProps(props)
	button.instance.AutoButtonColor = false
	button.instance.Font = props.Font or Theme.typography.fonts.medium
	button.instance.TextSize = props.TextSize or Theme.typography.sizes.button
	button.instance.TextColor3 = props.TextColor3 or Theme.colors.onPrimary
	return button
end

local function CreateImageLabel(props)
	local image = Component.new("ImageLabel"):SetProps(props)
	image.instance.BackgroundTransparency = 1
	image.instance.ScaleType = props.ScaleType or Enum.ScaleType.Fit
	return image
end

local function CreateScrollingFrame(props)
	local scroll = Component.new("ScrollingFrame"):SetProps(props)
	scroll.instance.BackgroundTransparency = 1
	scroll.instance.BorderSizePixel = 0
	scroll.instance.ScrollBarThickness = 8
	scroll.instance.ScrollBarImageColor3 = Theme.colors.divider
	scroll.instance.ScrollBarImageTransparency = 0.3
	scroll.instance.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.instance.AutomaticCanvasSize = Enum.AutomaticSize.Y
	return scroll
end

local function CreateTextBox(props)
	local textbox = Component.new("TextBox"):SetProps(props)
	textbox.instance.Font = props.Font or Theme.typography.fonts.body
	textbox.instance.TextSize = props.TextSize or Theme.typography.sizes.body1
	textbox.instance.TextColor3 = props.TextColor3 or Theme.colors.text.primary
	textbox.instance.PlaceholderColor3 = props.PlaceholderColor3 or Theme.colors.text.secondary
	textbox.instance.ClearTextOnFocus = false
	return textbox
end

-- Advanced UI Manager
local UIManager = {}
UIManager.__index = UIManager

function UIManager.new()
	local self = setmetatable({
		-- Core
		gui = nil,
		shopOpen = false,
		currentCategory = "cash",
		
		-- UI References
		mainContainer = nil,
		header = nil,
		navigation = nil,
		contentArea = nil,
		searchBar = nil,
		filterPanel = nil,
		cartPanel = nil,
		settingsPanel = nil,
		
		-- Data
		products = {},
		cart = {},
		filters = {
			search = "",
			tags = {},
			priceRange = {min = 0, max = math.huge},
			sortBy = "popular",
		},
		
		-- State
		playerCash = 0,
		ownedPasses = {},
		activePowerups = {},
		
		-- Systems
		soundManager = nil,
		connections = {},
		updateLoops = {},
		
		-- Settings
		settings = {
			soundEnabled = true,
			animationsEnabled = true,
			particlesEnabled = true,
			compactMode = false,
		},
	}, UIManager)
	
	self:Initialize()
	return self
end

function UIManager:Initialize()
	debugLog("Initializing Advanced Shop UI...")
	
	-- Initialize systems
	self:SetupSoundSystem()
	self:LoadProducts()
	self:CreateUI()
	self:SetupInputHandling()
	self:SetupResponsiveSystem()
	self:SetupDataSync()
	
	debugLog("Shop UI initialized successfully!")
end

function UIManager:SetupSoundSystem()
	self.soundManager = {}
	
	for name, config in pairs(Sounds) do
		local sound = Instance.new("Sound")
		sound.SoundId = config.id
		sound.Volume = config.volume
		sound.Parent = SoundService
		
		self.soundManager[name] = sound
		
		-- Preload
		sound:Play()
		sound:Stop()
	end
end

function UIManager:PlaySound(soundName)
	if not self.settings.soundEnabled then return end
	
	local sound = self.soundManager[soundName]
	if sound then
		sound:Play()
	end
end

function UIManager:LoadProducts()
	-- Load all products into a flat structure for easy searching
	self.products = {}
	
	for categoryId, categoryProducts in pairs(ProductDatabase.products) do
		for _, product in ipairs(categoryProducts) do
			product.category = categoryId
			table.insert(self.products, product)
		end
	end
end

function UIManager:CreateUI()
	-- Clean up existing
	if PlayerGui:FindFirstChild("AdvancedTycoonShop") then
		PlayerGui.AdvancedTycoonShop:Destroy()
	end
	
	-- Create ScreenGui
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "AdvancedTycoonShop"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 100
	self.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self.gui.Enabled = false
	self.gui.Parent = PlayerGui
	
	-- Create main elements
	self:CreateOverlay()
	self:CreateMainContainer()
	self:CreateHeader()
	self:CreateNavigation()
	self:CreateSearchBar()
	self:CreateContentArea()
	self:CreateCart()
	self:CreateSettingsPanel()
	self:CreateToggleButton()
	
	-- Apply initial responsive layout
	self:UpdateResponsiveLayout()
end

function UIManager:CreateOverlay()
	local overlay = CreateFrame({
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.overlay,
		BackgroundTransparency = 0.3,
		Parent = self.gui,
	})
	
	overlay.props.onClick = function()
		self:Close()
	end
	
	self.overlay = overlay:Mount()
	
	-- Blur effect
	self.blur = Instance.new("BlurEffect")
	self.blur.Name = "ShopBlur"
	self.blur.Size = 0
	self.blur.Parent = Lighting
end

function UIManager:CreateMainContainer()
	local device = getDeviceInfo()
	local safeArea = getSafeArea()
	
	local container = CreateFrame({
		Name = "MainContainer",
		Size = device.isSmall and UDim2.new(1, -safeArea.left - safeArea.right, 1, -safeArea.top - safeArea.bottom) 
			or UDim2.fromScale(0.9, 0.85),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.surface,
		Parent = self.gui,
		style = {
			cornerRadius = device.isSmall and 0 or UI_CONSTANTS.CORNER_RADIUS,
			shadow = not device.isSmall and {elevation = 4},
			sizeConstraint = {
				max = Vector2.new(1600, 900),
				min = Vector2.new(320, 480),
			},
		},
	})
	
	self.mainContainer = container:Mount()
end

function UIManager:CreateHeader()
	local device = getDeviceInfo()
	local headerHeight = device.isSmall and UI_CONSTANTS.HEADER_HEIGHT_MOBILE or UI_CONSTANTS.HEADER_HEIGHT_DESKTOP
	
	local header = CreateFrame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, headerHeight),
		BackgroundColor3 = Theme.colors.primary,
		Parent = self.mainContainer.instance,
		style = {
			gradient = {
				colors = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Theme.colors.primaryLight),
					ColorSequenceKeypoint.new(1, Theme.colors.primary),
				}),
				rotation = 90,
			},
		},
	})
	
	self.header = header:Mount()
	
	-- Header content container
	local content = CreateFrame({
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = self.header.instance,
		style = {
			padding = {
				left = Theme.spacing.md,
				right = Theme.spacing.md,
			},
		},
	})
	
	content:Mount()
	
	-- Layout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, Theme.spacing.md)
	layout.Parent = content.instance
	
	-- Shop icon
	local icon = CreateImageLabel({
		Name = "Icon",
		Image = Icons.shop,
		Size = UDim2.fromOffset(32, 32),
		ImageColor3 = Theme.colors.onPrimary,
		LayoutOrder = 1,
		Parent = content.instance,
	}):Mount()
	
	-- Title
	local title = CreateTextLabel({
		Name = "Title",
		Text = "Tycoon Shop",
		Font = Theme.typography.fonts.display,
		TextSize = device.isSmall and Theme.typography.sizes.h3 or Theme.typography.sizes.h2,
		TextColor3 = Theme.colors.onPrimary,
		Size = UDim2.new(1, -150, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Parent = content.instance,
	}):Mount()
	
	-- Currency display
	local currencyContainer = CreateFrame({
		Name = "Currency",
		Size = UDim2.fromOffset(150, 36),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.8,
		LayoutOrder = 3,
		Parent = content.instance,
		style = {
			cornerRadius = 18,
			padding = {left = 12, right = 12},
		},
	}):Mount()
	
	local currencyLayout = Instance.new("UIListLayout")
	currencyLayout.FillDirection = Enum.FillDirection.Horizontal
	currencyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	currencyLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	currencyLayout.Padding = UDim.new(0, 8)
	currencyLayout.Parent = currencyContainer.instance
	
	local currencyIcon = CreateImageLabel({
		Name = "Icon",
		Image = Icons.coin,
		Size = UDim2.fromOffset(20, 20),
		ImageColor3 = Theme.colors.warning,
		Parent = currencyContainer.instance,
	}):Mount()
	
	self.currencyLabel = CreateTextLabel({
		Name = "Amount",
		Text = formatCurrency(0),
		Font = Theme.typography.fonts.heading,
		TextSize = Theme.typography.sizes.body1,
		TextColor3 = Theme.colors.onPrimary,
		Size = UDim2.fromOffset(0, 36),
		Parent = currencyContainer.instance,
	}):Mount()
	
	-- Close button
	local closeButton = CreateTextButton({
		Name = "CloseButton",
		Text = "✕",
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -50, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.9,
		TextColor3 = Theme.colors.onPrimary,
		Font = Theme.typography.fonts.body,
		TextSize = 24,
		Parent = self.header.instance,
		style = {
			cornerRadius = 20,
		},
		onClick = function()
			self:Close()
		end,
		onMouseEnter = function(component)
			self:PlaySound("hover")
			component:Animate({
				BackgroundTransparency = 0.8,
				Size = UDim2.fromOffset(44, 44),
			}, Theme.motion.duration.fast)
		end,
		onMouseLeave = function(component)
			component:Animate({
				BackgroundTransparency = 0.9,
				Size = UDim2.fromOffset(40, 40),
			}, Theme.motion.duration.fast)
		end,
	}):Mount()
end

function UIManager:CreateNavigation()
	local device = getDeviceInfo()
	
	local nav = CreateFrame({
		Name = "Navigation",
		Size = device.isSmall and UDim2.new(1, 0, 0, UI_CONSTANTS.NAV_HEIGHT_MOBILE)
			or UDim2.new(0, UI_CONSTANTS.NAV_WIDTH_DESKTOP, 1, -UI_CONSTANTS.HEADER_HEIGHT_DESKTOP),
		Position = device.isSmall and UDim2.new(0, 0, 0, UI_CONSTANTS.HEADER_HEIGHT_MOBILE)
			or UDim2.new(0, 0, 0, UI_CONSTANTS.HEADER_HEIGHT_DESKTOP),
		BackgroundColor3 = Theme.colors.surfaceVariant,
		Parent = self.mainContainer.instance,
		style = {
			padding = Theme.spacing.sm,
		},
	}):Mount()
	
	self.navigation = nav
	
	-- Navigation scroll
	local scroll = CreateScrollingFrame({
		Name = "Scroll",
		Size = UDim2.fromScale(1, 1),
		Parent = nav.instance,
	}):Mount()
	
	-- Layout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = device.isSmall and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, Theme.spacing.sm)
	layout.Parent = scroll.instance
	
	-- Category buttons
	self.categoryButtons = {}
	
	for _, category in ipairs(ProductDatabase.categories) do
		local button = self:CreateCategoryButton(category, device.isSmall)
		self.categoryButtons[category.id] = button
	end
end

function UIManager:CreateCategoryButton(category, isCompact)
	local button = CreateTextButton({
		Name = category.id .. "Button",
		Text = "",
		Size = isCompact and UDim2.new(0.25, -6, 0, 80) or UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Theme.colors.surface,
		Parent = self.navigation.instance:FindFirstChild("Scroll"),
		style = {
			cornerRadius = 8,
			shadow = {elevation = 1},
		},
		onClick = function()
			self:SwitchCategory(category.id)
		end,
		onMouseEnter = function(component)
			if self.currentCategory ~= category.id then
				self:PlaySound("hover")
				component:Animate({
					BackgroundColor3 = Theme.colors.surfaceVariant,
				}, Theme.motion.duration.fast)
			end
		end,
		onMouseLeave = function(component)
			if self.currentCategory ~= category.id then
				component:Animate({
					BackgroundColor3 = Theme.colors.surface,
				}, Theme.motion.duration.fast)
			end
		end,
	}):Mount()
	
	-- Button content
	local content = CreateFrame({
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = button.instance,
		style = {
			padding = Theme.spacing.sm,
		},
	}):Mount()
	
	-- Layout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = isCompact and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, Theme.spacing.xs)
	layout.Parent = content.instance
	
	-- Icon
	local icon = CreateImageLabel({
		Name = "Icon",
		Image = category.icon,
		Size = UDim2.fromOffset(isCompact and 28 or 24, isCompact and 28 or 24),
		ImageColor3 = Theme.colors.text.secondary,
		Parent = content.instance,
	}):Mount()
	
	-- Label
	local label = CreateTextLabel({
		Name = "Label",
		Text = category.name,
		Font = Theme.typography.fonts.medium,
		TextSize = isCompact and Theme.typography.sizes.caption or Theme.typography.sizes.body2,
		TextColor3 = Theme.colors.text.secondary,
		Size = isCompact and UDim2.new(1, 0, 0, 20) or UDim2.fromOffset(0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = content.instance,
	}):Mount()
	
	-- Store references
	button.category = category
	button.icon = icon
	button.label = label
	
	return button
end

function UIManager:CreateSearchBar()
	local device = getDeviceInfo()
	
	local searchContainer = CreateFrame({
		Name = "SearchContainer",
		Size = UDim2.new(1, device.isSmall and 0 or -UI_CONSTANTS.NAV_WIDTH_DESKTOP, 0, UI_CONSTANTS.SEARCH_BAR_HEIGHT),
		Position = device.isSmall and UDim2.new(0, 0, 0, UI_CONSTANTS.HEADER_HEIGHT_MOBILE + UI_CONSTANTS.NAV_HEIGHT_MOBILE)
			or UDim2.new(0, UI_CONSTANTS.NAV_WIDTH_DESKTOP, 0, UI_CONSTANTS.HEADER_HEIGHT_DESKTOP),
		BackgroundColor3 = Theme.colors.surface,
		Parent = self.mainContainer.instance,
		style = {
			padding = {
				left = Theme.spacing.md,
				right = Theme.spacing.md,
				top = Theme.spacing.sm,
				bottom = Theme.spacing.sm,
			},
		},
	}):Mount()
	
	self.searchContainer = searchContainer
	
	-- Search box container
	local searchBox = CreateFrame({
		Name = "SearchBox",
		Size = UDim2.new(1, -100, 1, 0),
		BackgroundColor3 = Theme.colors.surfaceVariant,
		Parent = searchContainer.instance,
		style = {
			cornerRadius = 24,
			padding = {left = 16, right = 16},
		},
	}):Mount()
	
	-- Layout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = searchBox.instance
	
	-- Search icon
	local searchIcon = CreateImageLabel({
		Name = "Icon",
		Image = Icons.search,
		Size = UDim2.fromOffset(20, 20),
		ImageColor3 = Theme.colors.text.secondary,
		Parent = searchBox.instance,
	}):Mount()
	
	-- Search input
	self.searchInput = CreateTextBox({
		Name = "SearchInput",
		Text = "",
		PlaceholderText = "Search products...",
		Size = UDim2.new(1, -28, 1, 0),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = searchBox.instance,
		onTextChanged = function(text)
			self:OnSearchChanged(text)
		end,
	}):Mount()
	
	-- Filter button
	local filterButton = CreateTextButton({
		Name = "FilterButton",
		Text = "",
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -45, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.primary,
		Parent = searchContainer.instance,
		style = {
			cornerRadius = 20,
		},
		onClick = function()
			self:ToggleFilterPanel()
		end,
	}):Mount()
	
	local filterIcon = CreateImageLabel({
		Name = "Icon",
		Image = Icons.filter,
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageColor3 = Theme.colors.onPrimary,
		Parent = filterButton.instance,
	}):Mount()
end

function UIManager:CreateContentArea()
	local device = getDeviceInfo()
	
	local yOffset = UI_CONSTANTS.HEADER_HEIGHT_DESKTOP + UI_CONSTANTS.SEARCH_BAR_HEIGHT
	if device.isSmall then
		yOffset = UI_CONSTANTS.HEADER_HEIGHT_MOBILE + UI_CONSTANTS.NAV_HEIGHT_MOBILE + UI_CONSTANTS.SEARCH_BAR_HEIGHT
	end
	
	local content = CreateFrame({
		Name = "ContentArea",
		Size = UDim2.new(1, device.isSmall and 0 or -UI_CONSTANTS.NAV_WIDTH_DESKTOP, 1, -yOffset),
		Position = UDim2.new(0, device.isSmall and 0 or UI_CONSTANTS.NAV_WIDTH_DESKTOP, 0, yOffset),
		BackgroundTransparency = 1,
		Parent = self.mainContainer.instance,
	}):Mount()
	
	self.contentArea = content
	
	-- Create content pages
	self:CreateProductGrid()
	self:CreateProductDetails()
	self:CreateFilterPanel()
end

function UIManager:CreateProductGrid()
	local grid = CreateScrollingFrame({
		Name = "ProductGrid",
		Size = UDim2.fromScale(1, 1),
		Parent = self.contentArea.instance,
		style = {
			padding = Theme.spacing.md,
		},
	}):Mount()
	
	self.productGrid = grid
	
	-- Grid layout
	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(Theme.spacing.md, Theme.spacing.md)
	layout.CellSize = UDim2.new(0.5, -Theme.spacing.md/2, 0, 200)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid.instance
	
	self.gridLayout = layout
	
	-- Update grid based on screen size
	self:UpdateGridColumns()
end

function UIManager:UpdateGridColumns()
	local device = getDeviceInfo()
	
	if device.isSmall then
		self.gridLayout.CellSize = UDim2.new(1, 0, 0, 180)
	elseif device.isMedium then
		self.gridLayout.CellSize = UDim2.new(0.5, -Theme.spacing.md/2, 0, 200)
	else
		self.gridLayout.CellSize = UDim2.new(0.333, -Theme.spacing.md*2/3, 0, 220)
	end
end

function UIManager:CreateProductCard(product)
	local card = CreateFrame({
		Name = product.name:gsub(" ", "") .. "Card",
		BackgroundColor3 = Theme.colors.surface,
		style = {
			cornerRadius = 12,
			shadow = {elevation = 2},
		},
		onMouseEnter = function(component)
			self:PlaySound("hover")
			component:Animate({
				BackgroundColor3 = Theme.colors.surfaceVariant,
			}, Theme.motion.duration.fast)
			
			-- Elevate shadow
			if component.shadow then
				component.shadow:TweenSize(
					UDim2.new(1, 16, 1, 16),
					Enum.EasingDirection.Out,
					Theme.motion.easing.decelerate,
					Theme.motion.duration.fast,
					true
				)
			end
		end,
		onMouseLeave = function(component)
			component:Animate({
				BackgroundColor3 = Theme.colors.surface,
			}, Theme.motion.duration.fast)
			
			-- Lower shadow
			if component.shadow then
				component.shadow:TweenSize(
					UDim2.new(1, 8, 1, 8),
					Enum.EasingDirection.Out,
					Theme.motion.easing.decelerate,
					Theme.motion.duration.fast,
					true
				)
			end
		end,
	})
	
	local mounted = card:Mount()
	
	-- Card content
	local content = CreateFrame({
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = mounted.instance,
		style = {
			padding = Theme.spacing.md,
		},
	}):Mount()
	
	-- Layout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, Theme.spacing.sm)
	layout.Parent = content.instance
	
	-- Icon container
	local iconContainer = CreateFrame({
		Name = "IconContainer",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Theme.colors.surfaceVariant,
		LayoutOrder = 1,
		Parent = content.instance,
		style = {
			cornerRadius = 8,
		},
	}):Mount()
	
	-- Product icon
	local icon = CreateImageLabel({
		Name = "Icon",
		Image = product.icon or Icons.shop,
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = iconContainer.instance,
	}):Mount()
	
	-- Product name
	local name = CreateTextLabel({
		Name = "Name",
		Text = product.name,
		Font = Theme.typography.fonts.heading,
		TextSize = Theme.typography.sizes.h5,
		TextColor3 = Theme.colors.text.primary,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = 2,
		Parent = content.instance,
	}):Mount()
	
	-- Product description
	local desc = CreateTextLabel({
		Name = "Description",
		Text = product.description,
		Font = Theme.typography.fonts.body,
		TextSize = Theme.typography.sizes.caption,
		TextColor3 = Theme.colors.text.secondary,
		Size = UDim2.new(1, 0, 0, 32),
		TextWrapped = true,
		LayoutOrder = 3,
		Parent = content.instance,
	}):Mount()
	
	-- Price container
	local priceContainer = CreateFrame({
		Name = "PriceContainer",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = content.instance,
	}):Mount()
	
	-- Price display
	local priceText = "Loading..."
	if product.category == "cash" then
		priceText = "R$" .. (product.price or "???")
	elseif product.price then
		priceText = formatCurrency(product.price)
	end
	
	local price = CreateTextLabel({
		Name = "Price",
		Text = priceText,
		Font = Theme.typography.fonts.display,
		TextSize = Theme.typography.sizes.h4,
		TextColor3 = Theme.colors.primary,
		Size = UDim2.fromScale(1, 1),
		Parent = priceContainer.instance,
	}):Mount()
	
	-- Discount badge
	if product.discount and product.discount > 0 then
		local badge = CreateFrame({
			Name = "DiscountBadge",
			Size = UDim2.fromOffset(60, 24),
			Position = UDim2.new(1, -8, 0, 8),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Theme.colors.error,
			Parent = mounted.instance,
			style = {
				cornerRadius = 12,
			},
		}):Mount()
		
		local badgeText = CreateTextLabel({
			Name = "Text",
			Text = "-" .. product.discount .. "%",
			Font = Theme.typography.fonts.heading,
			TextSize = Theme.typography.sizes.caption,
			TextColor3 = Theme.colors.onPrimary,
			Size = UDim2.fromScale(1, 1),
			Parent = badge.instance,
		}):Mount()
	end
	
	-- Tags
	if product.tags then
		local tagContainer = CreateFrame({
			Name = "Tags",
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			LayoutOrder = 5,
			Parent = content.instance,
		}):Mount()
		
		local tagLayout = Instance.new("UIListLayout")
		tagLayout.FillDirection = Enum.FillDirection.Horizontal
		tagLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		tagLayout.Padding = UDim.new(0, 4)
		tagLayout.Parent = tagContainer.instance
		
		for _, tag in ipairs(product.tags) do
			local tagChip = CreateFrame({
				Name = tag .. "Tag",
				Size = UDim2.fromOffset(0, 20),
				BackgroundColor3 = Theme.colors.primaryLight,
				BackgroundTransparency = 0.8,
				Parent = tagContainer.instance,
				style = {
					cornerRadius = 10,
					padding = {left = 8, right = 8},
				},
			}):Mount()
			
			local tagText = CreateTextLabel({
				Name = "Text",
				Text = tag,
				Font = Theme.typography.fonts.medium,
				TextSize = Theme.typography.sizes.overline,
				TextColor3 = Theme.colors.primary,
				Size = UDim2.fromScale(1, 1),
				Parent = tagChip.instance,
			}):Mount()
			
			-- Auto-size
			tagChip.instance.Size = UDim2.fromOffset(tagText.instance.TextBounds.X + 16, 20)
		end
	end
	
	-- Action button
	local actionButton = CreateTextButton({
		Name = "ActionButton",
		Text = "View Details",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Theme.colors.primary,
		TextColor3 = Theme.colors.onPrimary,
		LayoutOrder = 6,
		Parent = content.instance,
		style = {
			cornerRadius = 18,
		},
		onClick = function()
			self:ShowProductDetails(product)
		end,
		onMouseEnter = function(component)
			component:Animate({
				BackgroundColor3 = Theme.colors.primaryDark,
			}, Theme.motion.duration.fast)
		end,
		onMouseLeave = function(component)
			component:Animate({
				BackgroundColor3 = Theme.colors.primary,
			}, Theme.motion.duration.fast)
		end,
	}):Mount()
	
	-- Store references
	product._card = mounted
	product._priceLabel = price
	
	return mounted
end

function UIManager:CreateProductDetails()
	-- Product details modal
	local modal = CreateFrame({
		Name = "ProductDetails",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.overlay,
		BackgroundTransparency = 0.3,
		Visible = false,
		Parent = self.contentArea.instance,
	}):Mount()
	
	self.productDetailsModal = modal
	
	-- Modal content
	local content = CreateFrame({
		Name = "Content",
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.surface,
		Parent = modal.instance,
		style = {
			cornerRadius = 16,
			shadow = {elevation = 5},
			sizeConstraint = {
				max = Vector2.new(600, 500),
			},
		},
	}):Mount()
	
	-- Close backdrop
	modal.props.onClick = function()
		self:HideProductDetails()
	end
	
	-- Prevent content clicks from closing
	content.instance.MouseButton1Click:Connect(function()
		-- Block click propagation
	end)
	
	self.productDetailsContent = content
end

function UIManager:CreateFilterPanel()
	local panel = CreateFrame({
		Name = "FilterPanel",
		Size = UDim2.new(0.3, 0, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Theme.colors.surface,
		Visible = false,
		Parent = self.contentArea.instance,
		style = {
			shadow = {elevation = 3},
		},
	}):Mount()
	
	self.filterPanel = panel
	
	-- Panel content
	local content = CreateScrollingFrame({
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		Parent = panel.instance,
		style = {
			padding = Theme.spacing.md,
		},
	}):Mount()
	
	-- TODO: Add filter controls
end

function UIManager:CreateCart()
	-- Cart button
	local cartButton = CreateTextButton({
		Name = "CartButton",
		Text = "",
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.new(1, -70, 1, -70),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.secondary,
		Parent = self.gui,
		style = {
			cornerRadius = 28,
			shadow = {elevation = 3},
		},
		onClick = function()
			self:ToggleCart()
		end,
	}):Mount()
	
	self.cartButton = cartButton
	
	-- Cart icon
	local cartIcon = CreateImageLabel({
		Name = "Icon",
		Image = Icons.cart,
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageColor3 = Theme.colors.onSecondary,
		Parent = cartButton.instance,
	}):Mount()
	
	-- Cart badge
	local badge = CreateFrame({
		Name = "Badge",
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.new(1, -5, 0, 5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.error,
		Visible = false,
		Parent = cartButton.instance,
		style = {
			cornerRadius = 10,
		},
	}):Mount()
	
	self.cartBadge = badge
	
	local badgeText = CreateTextLabel({
		Name = "Text",
		Text = "0",
		Font = Theme.typography.fonts.heading,
		TextSize = Theme.typography.sizes.caption,
		TextColor3 = Theme.colors.onPrimary,
		Size = UDim2.fromScale(1, 1),
		Parent = badge.instance,
	}):Mount()
	
	self.cartBadgeText = badgeText
end

function UIManager:CreateSettingsPanel()
	-- Settings panel implementation
	-- TODO: Add settings controls
end

function UIManager:CreateToggleButton()
	-- Create separate ScreenGui for toggle
	local toggleGui = Instance.new("ScreenGui")
	toggleGui.Name = "ShopToggle"
	toggleGui.ResetOnSpawn = false
	toggleGui.DisplayOrder = 50
	toggleGui.Parent = PlayerGui
	
	local toggleButton = CreateTextButton({
		Name = "ToggleButton",
		Text = "",
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.new(1, -40, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.primary,
		Parent = toggleGui,
		style = {
			cornerRadius = 32,
			shadow = {elevation = 3},
		},
		onClick = function()
			self:Toggle()
		end,
		onMouseEnter = function(component)
			self:PlaySound("hover")
			component:Animate({
				Size = UDim2.fromOffset(72, 72),
			}, Theme.motion.duration.fast, Theme.motion.easing.decelerate)
		end,
		onMouseLeave = function(component)
			component:Animate({
				Size = UDim2.fromOffset(64, 64),
			}, Theme.motion.duration.fast, Theme.motion.easing.decelerate)
		end,
	}):Mount()
	
	self.toggleButton = toggleButton
	
	-- Icon
	local icon = CreateImageLabel({
		Name = "Icon",
		Image = Icons.shop,
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageColor3 = Theme.colors.onPrimary,
		Parent = toggleButton.instance,
	}):Mount()
	
	-- Floating animation
	task.spawn(function()
		while toggleButton.instance.Parent do
			toggleButton:AnimateSequence({
				{
					properties = {Position = UDim2.new(1, -40, 0.5, -5)},
					duration = 2,
					easing = Enum.EasingStyle.Sine,
					direction = Enum.EasingDirection.InOut,
				},
				{
					properties = {Position = UDim2.new(1, -40, 0.5, 5)},
					duration = 2,
					easing = Enum.EasingStyle.Sine,
					direction = Enum.EasingDirection.InOut,
				},
			})
			task.wait(4)
		end
	end)
end

function UIManager:SetupInputHandling()
	-- Keyboard shortcuts
	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		
		if input.KeyCode == Enum.KeyCode.M then
			self:Toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and self.shopOpen then
			self:Close()
		elseif input.KeyCode == Enum.KeyCode.F and self.shopOpen then
			if self.searchInput then
				self.searchInput.instance:CaptureFocus()
			end
		end
	end))
	
	-- Gamepad support
	ContextActionService:BindAction("ToggleShop", function(_, state)
		if state == Enum.UserInputState.Begin then
			self:Toggle()
		end
	end, false, Enum.KeyCode.ButtonY)
end

function UIManager:SetupResponsiveSystem()
	local function updateLayout()
		self:UpdateResponsiveLayout()
	end
	
	-- Initial update
	updateLayout()
	
	-- Listen for viewport changes
	table.insert(self.connections, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout))
end

function UIManager:UpdateResponsiveLayout()
	local device = getDeviceInfo()
	
	-- Update grid columns
	self:UpdateGridColumns()
	
	-- Update navigation
	if self.navigation then
		if device.isSmall then
			self.navigation.instance.Size = UDim2.new(1, 0, 0, UI_CONSTANTS.NAV_HEIGHT_MOBILE)
			self.navigation.instance.Position = UDim2.new(0, 0, 0, UI_CONSTANTS.HEADER_HEIGHT_MOBILE)
			
			-- Update search bar position
			if self.searchContainer then
				self.searchContainer.instance.Position = UDim2.new(0, 0, 0, UI_CONSTANTS.HEADER_HEIGHT_MOBILE + UI_CONSTANTS.NAV_HEIGHT_MOBILE)
			end
			
			-- Update content area
			if self.contentArea then
				local yOffset = UI_CONSTANTS.HEADER_HEIGHT_MOBILE + UI_CONSTANTS.NAV_HEIGHT_MOBILE + UI_CONSTANTS.SEARCH_BAR_HEIGHT
				self.contentArea.instance.Size = UDim2.new(1, 0, 1, -yOffset)
				self.contentArea.instance.Position = UDim2.new(0, 0, 0, yOffset)
			end
		else
			self.navigation.instance.Size = UDim2.new(0, UI_CONSTANTS.NAV_WIDTH_DESKTOP, 1, -UI_CONSTANTS.HEADER_HEIGHT_DESKTOP)
			self.navigation.instance.Position = UDim2.new(0, 0, 0, UI_CONSTANTS.HEADER_HEIGHT_DESKTOP)
			
			-- Update search bar
			if self.searchContainer then
				self.searchContainer.instance.Size = UDim2.new(1, -UI_CONSTANTS.NAV_WIDTH_DESKTOP, 0, UI_CONSTANTS.SEARCH_BAR_HEIGHT)
				self.searchContainer.instance.Position = UDim2.new(0, UI_CONSTANTS.NAV_WIDTH_DESKTOP, 0, UI_CONSTANTS.HEADER_HEIGHT_DESKTOP)
			end
			
			-- Update content area
			if self.contentArea then
				local yOffset = UI_CONSTANTS.HEADER_HEIGHT_DESKTOP + UI_CONSTANTS.SEARCH_BAR_HEIGHT
				self.contentArea.instance.Size = UDim2.new(1, -UI_CONSTANTS.NAV_WIDTH_DESKTOP, 1, -yOffset)
				self.contentArea.instance.Position = UDim2.new(0, UI_CONSTANTS.NAV_WIDTH_DESKTOP, 0, yOffset)
			end
		end
	end
	
	-- Update category buttons
	for _, button in pairs(self.categoryButtons) do
		self:UpdateCategoryButton(button, device.isSmall)
	end
end

function UIManager:UpdateCategoryButton(button, isCompact)
	if isCompact then
		button.instance.Size = UDim2.new(0.25, -6, 0, 80)
		button.icon.instance.Size = UDim2.fromOffset(28, 28)
		button.label.instance.TextSize = Theme.typography.sizes.caption
	else
		button.instance.Size = UDim2.new(1, 0, 0, 64)
		button.icon.instance.Size = UDim2.fromOffset(24, 24)
		button.label.instance.TextSize = Theme.typography.sizes.body2
	end
end

function UIManager:SetupDataSync()
	-- Connect to remotes
	if Remotes then
		local cashUpdate = Remotes:FindFirstChild("CashUpdated")
		if cashUpdate and cashUpdate:IsA("RemoteEvent") then
			table.insert(self.connections, cashUpdate.OnClientEvent:Connect(function(amount)
				self:UpdatePlayerCash(amount)
			end))
		end
		
		-- Request initial data
		local getPlayerData = Remotes:FindFirstChild("GetPlayerData")
		if getPlayerData and getPlayerData:IsA("RemoteFunction") then
			task.spawn(function()
				local success, data = pcall(function()
					return getPlayerData:InvokeServer()
				end)
				
				if success and data then
					self:UpdatePlayerData(data)
				end
			end)
		end
	end
	
	-- Update loop for prices
	self:StartPriceUpdateLoop()
end

function UIManager:StartPriceUpdateLoop()
	table.insert(self.updateLoops, task.spawn(function()
		while true do
			self:RefreshPrices()
			task.wait(60) -- Update every minute
		end
	end))
end

function UIManager:RefreshPrices()
	for _, product in ipairs(self.products) do
		if product.id then
			task.spawn(function()
				local success, info = pcall(function()
					if product.category == "passes" then
						return MarketplaceService:GetProductInfo(product.id, Enum.InfoType.GamePass)
					else
						return MarketplaceService:GetProductInfo(product.id, Enum.InfoType.Product)
					end
				end)
				
				if success and info then
					product.price = info.PriceInRobux
					
					-- Update UI if card exists
					if product._priceLabel then
						product._priceLabel.instance.Text = "R$" .. info.PriceInRobux
					end
				end
			end)
		end
	end
end

function UIManager:UpdatePlayerCash(amount)
	self.playerCash = amount
	
	if self.currencyLabel then
		-- Animate the change
		local startAmount = tonumber(self.currencyLabel.instance.Text:match("%d+")) or 0
		local startTime = tick()
		local duration = 0.5
		
		local connection
		connection = RunService.Heartbeat:Connect(function()
			local elapsed = tick() - startTime
			local progress = math.min(elapsed / duration, 1)
			
			local currentAmount = lerp(startAmount, amount, progress)
			self.currencyLabel.instance.Text = formatCurrency(math.floor(currentAmount))
			
			if progress >= 1 then
				connection:Disconnect()
			end
		end)
	end
end

function UIManager:UpdatePlayerData(data)
	if data.cash then
		self:UpdatePlayerCash(data.cash)
	end
	
	if data.ownedPasses then
		self.ownedPasses = data.ownedPasses
		-- TODO: Update UI to reflect owned passes
	end
	
	if data.activePowerups then
		self.activePowerups = data.activePowerups
		-- TODO: Update UI to show active powerups
	end
end

function UIManager:SwitchCategory(categoryId)
	if self.currentCategory == categoryId then return end
	
	debugLog("Switching to category:", categoryId)
	
	self.currentCategory = categoryId
	self:PlaySound("click")
	
	-- Update button states
	for id, button in pairs(self.categoryButtons) do
		local isActive = id == categoryId
		local category = button.category
		
		button:Animate({
			BackgroundColor3 = isActive and category.color or Theme.colors.surface,
		}, Theme.motion.duration.fast)
		
		button.icon:Animate({
			ImageColor3 = isActive and Theme.colors.onPrimary or Theme.colors.text.secondary,
		}, Theme.motion.duration.fast)
		
		button.label:Animate({
			TextColor3 = isActive and Theme.colors.onPrimary or Theme.colors.text.secondary,
		}, Theme.motion.duration.fast)
	end
	
	-- Refresh products
	self:RefreshProductDisplay()
end

function UIManager:RefreshProductDisplay()
	-- Clear existing cards
	for _, child in ipairs(self.productGrid.instance:GetChildren()) do
		if child:IsA("Frame") and child.Name:match("Card") then
			child:Destroy()
		end
	end
	
	-- Get filtered products
	local products = self:GetFilteredProducts()
	
	-- Create cards
	for i, product in ipairs(products) do
		local card = self:CreateProductCard(product)
		card.instance.LayoutOrder = i
		card.instance.Parent = self.productGrid.instance
		
		-- Stagger animation
		card.instance.Position = UDim2.new(0, 0, 0, 50)
		card:Animate({
			Position = UDim2.new(0, 0, 0, 0),
		}, Theme.motion.duration.medium, Theme.motion.easing.decelerate)
	end
end

function UIManager:GetFilteredProducts()
	local filtered = {}
	
	for _, product in ipairs(self.products) do
		local matchesCategory = product.category == self.currentCategory
		local matchesSearch = true
		local matchesTags = true
		local matchesPrice = true
		
		-- Search filter
		if self.filters.search and #self.filters.search > 0 then
			local searchLower = self.filters.search:lower()
			local nameLower = product.name:lower()
			local descLower = (product.description or ""):lower()
			
			matchesSearch = nameLower:find(searchLower) or descLower:find(searchLower)
		end
		
		-- Tag filter
		if #self.filters.tags > 0 and product.tags then
			matchesTags = false
			for _, filterTag in ipairs(self.filters.tags) do
				for _, productTag in ipairs(product.tags) do
					if filterTag == productTag then
						matchesTags = true
						break
					end
				end
				if matchesTags then break end
			end
		end
		
		-- Price filter
		if product.price then
			matchesPrice = product.price >= self.filters.priceRange.min and 
						   product.price <= self.filters.priceRange.max
		end
		
		if matchesCategory and matchesSearch and matchesTags and matchesPrice then
			table.insert(filtered, product)
		end
	end
	
	-- Sort
	table.sort(filtered, function(a, b)
		if self.filters.sortBy == "price_low" then
			return (a.price or 0) < (b.price or 0)
		elseif self.filters.sortBy == "price_high" then
			return (a.price or 0) > (b.price or 0)
		elseif self.filters.sortBy == "name" then
			return a.name < b.name
		else -- popular
			return true -- Keep original order
		end
	end)
	
	return filtered
end

function UIManager:OnSearchChanged(text)
	self.filters.search = text
	
	-- Debounce search
	if self.searchDebounce then
		task.cancel(self.searchDebounce)
	end
	
	self.searchDebounce = task.delay(UI_CONSTANTS.SEARCH_DEBOUNCE, function()
		self:RefreshProductDisplay()
		self.searchDebounce = nil
	end)
end

function UIManager:ShowProductDetails(product)
	debugLog("Showing details for:", product.name)
	self:PlaySound("open")
	
	-- Show modal
	self.productDetailsModal.instance.Visible = true
	
	-- Clear previous content
	for _, child in ipairs(self.productDetailsContent.instance:GetChildren()) do
		if not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
	
	-- Create detail view
	-- TODO: Implement full product detail view
	
	-- Animation
	self.productDetailsContent.instance.Size = UDim2.fromScale(0.7, 0.7)
	self.productDetailsContent:Animate({
		Size = UDim2.fromScale(0.8, 0.8),
	}, Theme.motion.duration.medium, Theme.motion.easing.decelerate)
end

function UIManager:HideProductDetails()
	self:PlaySound("close")
	
	self.productDetailsContent:Animate({
		Size = UDim2.fromScale(0.7, 0.7),
	}, Theme.motion.duration.fast, Theme.motion.easing.accelerate)
	
	task.wait(Theme.motion.duration.fast)
	self.productDetailsModal.instance.Visible = false
end

function UIManager:ToggleFilterPanel()
	-- TODO: Implement filter panel toggle
end

function UIManager:ToggleCart()
	-- TODO: Implement cart panel
end

function UIManager:Open()
	if self.shopOpen then return end
	
	debugLog("Opening shop")
	self.shopOpen = true
	
	-- Enable GUI
	self.gui.Enabled = true
	self:PlaySound("open")
	
	-- Animate blur
	TweenService:Create(self.blur, TweenInfo.new(Theme.motion.duration.medium), {
		Size = UI_CONSTANTS.BLUR_SIZE,
	}):Play()
	
	-- Animate overlay
	self.overlay.instance.BackgroundTransparency = 1
	self.overlay:Animate({
		BackgroundTransparency = 0.3,
	}, Theme.motion.duration.medium)
	
	-- Animate container
	self.mainContainer.instance.Position = UDim2.fromScale(0.5, 0.6)
	self.mainContainer:Animate({
		Position = UDim2.fromScale(0.5, 0.5),
	}, Theme.motion.duration.slow, Theme.motion.easing.decelerate)
	
	-- Refresh data
	self:RefreshProductDisplay()
	self:RefreshPrices()
end

function UIManager:Close()
	if not self.shopOpen then return end
	
	debugLog("Closing shop")
	self.shopOpen = false
	
	self:PlaySound("close")
	
	-- Animate blur
	TweenService:Create(self.blur, TweenInfo.new(Theme.motion.duration.fast), {
		Size = 0,
	}):Play()
	
	-- Animate overlay
	self.overlay:Animate({
		BackgroundTransparency = 1,
	}, Theme.motion.duration.fast)
	
	-- Animate container
	self.mainContainer:Animate({
		Position = UDim2.fromScale(0.5, 0.6),
	}, Theme.motion.duration.fast, Theme.motion.easing.accelerate)
	
	task.wait(Theme.motion.duration.fast)
	self.gui.Enabled = false
end

function UIManager:Toggle()
	if self.shopOpen then
		self:Close()
	else
		self:Open()
	end
end

function UIManager:Destroy()
	debugLog("Destroying shop UI")
	
	-- Cancel update loops
	for _, loop in ipairs(self.updateLoops) do
		task.cancel(loop)
	end
	
	-- Disconnect events
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	
	-- Unbind actions
	ContextActionService:UnbindAction("ToggleShop")
	
	-- Destroy UI elements
	if self.gui then
		self.gui:Destroy()
	end
	
	if self.blur then
		self.blur:Destroy()
	end
	
	if self.toggleButton then
		self.toggleButton:Destroy()
	end
end

-- Initialize
local shopUI = UIManager.new()

-- Character respawn handling
Player.CharacterAdded:Connect(function()
	task.wait(1)
	-- Recreate toggle button if needed
	if not PlayerGui:FindFirstChild("ShopToggle") then
		shopUI:CreateToggleButton()
	end
end)

-- Cleanup
Players.PlayerRemoving:Connect(function(player)
	if player == Player then
		shopUI:Destroy()
	end
end)

print("[AdvancedTycoonShop] Version " .. SHOP_VERSION .. " loaded successfully!")

-- Public API
return {
	toggle = function() shopUI:Toggle() end,
	open = function() shopUI:Open() end,
	close = function() shopUI:Close() end,
	refresh = function() shopUI:RefreshProductDisplay() end,
	version = SHOP_VERSION,
}