--[[
	🏪 TYCOON SHOP UI - MODERN EDITION 2025
	
	A completely revamped, visually stunning shop interface for Roblox tycoon games.
	Built with modern design principles, responsive layouts, and smooth animations.
	
	✨ Features:
	• Modern-cute aesthetic with soft pastels and rounded corners
	• Mobile-first responsive design with proper safe zones
	• Smooth animations and micro-interactions
	• Comprehensive purchase system with proper error handling
	• Beautiful card layouts with perfect spacing
	• Advanced toggle system for gamepasses
	• Cross-platform input support (M key, gamepad X, ESC to close)
	
	📱 Responsive Design:
	• < 600px: 1 column grid
	• 600-950px: 2 column grid  
	• ≥ 950px: 3 column grid
	• Automatic safe zone detection and padding
	
	🎨 Design System:
	• Consistent 8px grid system
	• Harmonious color palette with accessibility in mind
	• Proper typography hierarchy with Gotham font family
	• Subtle shadows and depth without heavy 3D effects
	
	Place in: StarterPlayer > StarterPlayerScripts
	
	Required Server Setup:
	Create folder "TycoonRemotes" in ReplicatedStorage with:
	- RemoteEvent: GrantProductCurrency
	- RemoteEvent: GamepassPurchased  
	- RemoteEvent: AutoCollectToggle
	- RemoteFunction: GetAutoCollectState
]]

-- ============================================================================
-- SERVICES & SETUP
-- ============================================================================

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Wait for remotes with timeout
local Remotes = nil
task.spawn(function()
	local success, result = pcall(function()
		return ReplicatedStorage:WaitForChild("TycoonRemotes", 10)
	end)
	if success then
		Remotes = result
	else
		warn("[TycoonShop] TycoonRemotes folder not found in ReplicatedStorage")
	end
end)

-- ============================================================================
-- DESIGN SYSTEM & THEME
-- ============================================================================

local DesignSystem = {
	-- Modern Color Palette (Soft & Accessible)
	Colors = {
		-- Base Colors
		Background = Color3.fromRGB(248, 250, 252),     -- Soft white-blue
		Surface = Color3.fromRGB(255, 255, 255),        -- Pure white
		SurfaceElevated = Color3.fromRGB(252, 254, 255), -- Slightly elevated
		SurfaceVariant = Color3.fromRGB(243, 247, 251),  -- Subtle variant
		
		-- Border & Stroke
		Border = Color3.fromRGB(226, 232, 240),         -- Soft gray border
		BorderHover = Color3.fromRGB(203, 213, 225),    -- Darker on hover
		Divider = Color3.fromRGB(241, 245, 249),        -- Subtle divider
		
		-- Text Colors
		TextPrimary = Color3.fromRGB(15, 23, 42),       -- Almost black
		TextSecondary = Color3.fromRGB(71, 85, 105),    -- Medium gray
		TextTertiary = Color3.fromRGB(148, 163, 184),   -- Light gray
		TextInverse = Color3.fromRGB(255, 255, 255),    -- White text
		
		-- Accent Colors (Modern & Vibrant)
		Primary = Color3.fromRGB(99, 102, 241),         -- Indigo primary
		PrimaryHover = Color3.fromRGB(79, 70, 229),     -- Darker indigo
		PrimaryLight = Color3.fromRGB(238, 242, 255),   -- Light indigo bg
		
		-- Cash Theme (Warm Gold/Green)
		Cash = Color3.fromRGB(34, 197, 94),             -- Emerald green
		CashHover = Color3.fromRGB(22, 163, 74),        -- Darker green
		CashLight = Color3.fromRGB(236, 253, 245),      -- Light green bg
		CashAccent = Color3.fromRGB(251, 191, 36),      -- Gold accent
		
		-- Gamepass Theme (Cool Purple/Blue)
		Gamepass = Color3.fromRGB(147, 51, 234),        -- Purple
		GamepassHover = Color3.fromRGB(126, 34, 206),   -- Darker purple
		GamepassLight = Color3.fromRGB(250, 245, 255),  -- Light purple bg
		GamepassAccent = Color3.fromRGB(59, 130, 246),  -- Blue accent
		
		-- Status Colors
		Success = Color3.fromRGB(34, 197, 94),          -- Green
		Warning = Color3.fromRGB(251, 146, 60),         -- Orange
		Error = Color3.fromRGB(239, 68, 68),            -- Red
		Info = Color3.fromRGB(59, 130, 246),            -- Blue
		
		-- Special Effects
		Shadow = Color3.fromRGB(0, 0, 0),               -- For shadows
		Overlay = Color3.fromRGB(0, 0, 0),              -- For overlays
	},
	
	-- Typography Scale
	Typography = {
		-- Font Families
		FontRegular = Enum.Font.Gotham,
		FontMedium = Enum.Font.GothamMedium, 
		FontSemiBold = Enum.Font.GothamSemibold,
		FontBold = Enum.Font.GothamBold,
		
		-- Font Sizes (Responsive)
		Size12 = 12,  -- Caption
		Size14 = 14,  -- Small text
		Size16 = 16,  -- Body text
		Size18 = 18,  -- Large body
		Size20 = 20,  -- Subtitle
		Size24 = 24,  -- Title
		Size28 = 28,  -- Large title
		Size32 = 32,  -- Display
		Size40 = 40,  -- Large display
	},
	
	-- Spacing Scale (8px grid system)
	Spacing = {
		XS = 4,   -- 0.25rem
		SM = 8,   -- 0.5rem  
		MD = 16,  -- 1rem
		LG = 24,  -- 1.5rem
		XL = 32,  -- 2rem
		XXL = 48, -- 3rem
		XXXL = 64, -- 4rem
	},
	
	-- Border Radius Scale
	Radius = {
		XS = 4,   -- Small elements
		SM = 8,   -- Buttons, inputs
		MD = 12,  -- Cards
		LG = 16,  -- Panels
		XL = 20,  -- Large panels
		XXL = 24, -- Extra large
		Full = 9999, -- Fully rounded
	},
	
	-- Animation Timing
	Animation = {
		Fast = 0.15,     -- Quick feedback
		Medium = 0.25,   -- Standard transitions
		Slow = 0.4,      -- Complex animations
		Bounce = 0.6,    -- Bounce effects
	},
	
	-- Z-Index Layers
	ZIndex = {
		Background = 1,
		Content = 2,
		Elevated = 3,
		Overlay = 4,
		Modal = 5,
		Tooltip = 6,
		Notification = 7,
	},
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local Utils = {}

-- Device Detection
function Utils.getDeviceType()
	local camera = workspace.CurrentCamera
	if not camera then return "Desktop" end
	
	local viewportSize = camera.ViewportSize
	local isTenFoot = GuiService:IsTenFootInterface()
	
	if isTenFoot then
		return "Console"
	elseif viewportSize.X < 768 then
		return "Mobile"
	elseif viewportSize.X < 1024 then
		return "Tablet" 
	else
		return "Desktop"
	end
end

-- Responsive Breakpoints
function Utils.getBreakpoint()
	local camera = workspace.CurrentCamera
	if not camera then return "lg" end
	
	local width = camera.ViewportSize.X
	if width < 600 then
		return "sm"  -- 1 column
	elseif width < 950 then
		return "md"  -- 2 columns
	else
		return "lg"  -- 3 columns
	end
end

-- Safe Area Calculation
function Utils.getSafeAreaInsets()
	local topInset, bottomInset = GuiService:GetGuiInset()
	return {
		Top = topInset.Y,
		Bottom = bottomInset.Y,
		Left = 0,
		Right = 0,
	}
end

-- Number Formatting
function Utils.formatNumber(number)
	local formatted = tostring(number)
	local k
	repeat
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return formatted
end

-- Currency Formatting
function Utils.formatCurrency(amount)
	if amount >= 1000000 then
		return string.format("%.1fM", amount / 1000000)
	elseif amount >= 1000 then
		return string.format("%.1fK", amount / 1000)
	else
		return Utils.formatNumber(amount)
	end
end

-- Color Utilities
function Utils.lightenColor(color, factor)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s * (1 - factor), math.min(1, v + factor))
end

function Utils.darkenColor(color, factor)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, v * (1 - factor))
end

-- Animation Helper
function Utils.tween(object, properties, duration, easingStyle, easingDirection, callback)
	duration = duration or DesignSystem.Animation.Medium
	easingStyle = easingStyle or Enum.EasingStyle.Quad
	easingDirection = easingDirection or Enum.EasingDirection.Out
	
	local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection)
	local tween = TweenService:Create(object, tweenInfo, properties)
	
	if callback then
		tween.Completed:Connect(callback)
	end
	
	tween:Play()
	return tween
end

-- Sound Helper
function Utils.playSound(soundId, volume, pitch)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.Pitch = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

-- ============================================================================
-- UI COMPONENT SYSTEM
-- ============================================================================

local Components = {}

-- Base Component Class
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

function Component:applyProps()
	for key, value in pairs(self.props) do
		if key ~= "children" and key ~= "ref" and key ~= "onClick" and key ~= "onHover" then
			local success, error = pcall(function()
				self.instance[key] = value
			end)
			if not success then
				warn("Failed to set property " .. key .. ": " .. error)
			end
		end
	end
end

function Component:addChild(child)
	table.insert(self.children, child)
	if typeof(child) == "Instance" then
		child.Parent = self.instance
	elseif child.instance then
		child.instance.Parent = self.instance
	end
end

function Component:destroy()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	for _, child in ipairs(self.children) do
		if child.destroy then
			child:destroy()
		elseif typeof(child) == "Instance" then
			child:Destroy()
		end
	end
	self.instance:Destroy()
end

-- Frame Component
function Components.Frame(props)
	props = props or {}
	
	-- Default props
	if props.BackgroundColor3 == nil then props.BackgroundColor3 = DesignSystem.Colors.Surface end
	if props.BorderSizePixel == nil then props.BorderSizePixel = 0 end
	if props.Size == nil then props.Size = UDim2.fromScale(1, 1) end
	
	local component = Component.new("Frame", props)
	component:applyProps()
	
	return component
end

-- Text Component  
function Components.Text(props)
	props = props or {}
	
	-- Default props
	if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
	if props.Font == nil then props.Font = DesignSystem.Typography.FontRegular end
	if props.TextColor3 == nil then props.TextColor3 = DesignSystem.Colors.TextPrimary end
	if props.TextSize == nil then props.TextSize = DesignSystem.Typography.Size16 end
	if props.TextWrapped == nil then props.TextWrapped = true end
	if props.TextXAlignment == nil then props.TextXAlignment = Enum.TextXAlignment.Center end
	if props.TextYAlignment == nil then props.TextYAlignment = Enum.TextYAlignment.Center end
	
	local component = Component.new("TextLabel", props)
	component:applyProps()
	
	return component
end

-- Button Component
function Components.Button(props)
	props = props or {}
	
	-- Default props
	if props.BackgroundColor3 == nil then props.BackgroundColor3 = DesignSystem.Colors.Primary end
	if props.Font == nil then props.Font = DesignSystem.Typography.FontSemiBold end
	if props.TextColor3 == nil then props.TextColor3 = DesignSystem.Colors.TextInverse end
	if props.TextSize == nil then props.TextSize = DesignSystem.Typography.Size16 end
	if props.AutoButtonColor == nil then props.AutoButtonColor = false end
	if props.BorderSizePixel == nil then props.BorderSizePixel = 0 end
	
	local component = Component.new("TextButton", props)
	component:applyProps()
	
	-- Add hover effects
	local originalColor = props.BackgroundColor3 or DesignSystem.Colors.Primary
	local hoverColor = Utils.darkenColor(originalColor, 0.1)
	
	table.insert(component.connections, component.instance.MouseEnter:Connect(function()
		Utils.tween(component.instance, {
			BackgroundColor3 = hoverColor,
		}, DesignSystem.Animation.Fast)
	end))
	
	table.insert(component.connections, component.instance.MouseLeave:Connect(function()
		Utils.tween(component.instance, {
			BackgroundColor3 = originalColor,
		}, DesignSystem.Animation.Fast)
	end))
	
	-- Click handler
	if props.onClick then
		table.insert(component.connections, component.instance.MouseButton1Click:Connect(props.onClick))
	end
	
	return component
end

-- Image Component
function Components.Image(props)
	props = props or {}
	
	-- Default props
	if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
	if props.ScaleType == nil then props.ScaleType = Enum.ScaleType.Fit end
	if props.BorderSizePixel == nil then props.BorderSizePixel = 0 end
	
	local component = Component.new("ImageLabel", props)
	component:applyProps()
	
	return component
end

-- ScrollingFrame Component
function Components.ScrollingFrame(props)
	props = props or {}
	
	-- Default props
	if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
	if props.BorderSizePixel == nil then props.BorderSizePixel = 0 end
	if props.ScrollBarThickness == nil then props.ScrollBarThickness = 8 end
	if props.ScrollBarImageColor3 == nil then props.ScrollBarImageColor3 = DesignSystem.Colors.Border end
	if props.ScrollBarImageTransparency == nil then props.ScrollBarImageTransparency = 0.3 end
	if props.AutomaticCanvasSize == nil then props.AutomaticCanvasSize = Enum.AutomaticSize.Y end
	if props.CanvasSize == nil then props.CanvasSize = UDim2.new(0, 0, 0, 0) end
	
	local component = Component.new("ScrollingFrame", props)
	component:applyProps()
	
	return component
end

-- ============================================================================
-- UI EFFECTS & MODIFIERS
-- ============================================================================

local Effects = {}

-- Add Corner Radius
function Effects.addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or DesignSystem.Radius.MD)
	corner.Parent = instance
	return corner
end

-- Add Stroke/Border
function Effects.addStroke(instance, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or DesignSystem.Colors.Border
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

-- Add Padding
function Effects.addPadding(instance, padding)
	local uiPadding = Instance.new("UIPadding")
	
	if typeof(padding) == "number" then
		-- Uniform padding
		uiPadding.PaddingTop = UDim.new(0, padding)
		uiPadding.PaddingBottom = UDim.new(0, padding)
		uiPadding.PaddingLeft = UDim.new(0, padding)
		uiPadding.PaddingRight = UDim.new(0, padding)
	elseif typeof(padding) == "table" then
		-- Custom padding
		uiPadding.PaddingTop = UDim.new(0, padding.top or padding.vertical or padding.all or 0)
		uiPadding.PaddingBottom = UDim.new(0, padding.bottom or padding.vertical or padding.all or 0)
		uiPadding.PaddingLeft = UDim.new(0, padding.left or padding.horizontal or padding.all or 0)
		uiPadding.PaddingRight = UDim.new(0, padding.right or padding.horizontal or padding.all or 0)
	end
	
	uiPadding.Parent = instance
	return uiPadding
end

-- Add Gradient
function Effects.addGradient(instance, colorSequence, transparency, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = colorSequence
	if transparency then gradient.Transparency = transparency end
	if rotation then gradient.Rotation = rotation end
	gradient.Parent = instance
	return gradient
end

-- Add Shadow Effect
function Effects.addShadow(instance, color, offset, blur)
	-- Create shadow frame behind the main instance
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = color or DesignSystem.Colors.Shadow
	shadow.BackgroundTransparency = 0.85
	shadow.BorderSizePixel = 0
	shadow.Size = instance.Size
	shadow.Position = UDim2.new(
		instance.Position.X.Scale,
		instance.Position.X.Offset + (offset and offset.X or 0),
		instance.Position.Y.Scale, 
		instance.Position.Y.Offset + (offset and offset.Y or 4)
	)
	shadow.ZIndex = instance.ZIndex - 1
	shadow.Parent = instance.Parent
	
	-- Match corner radius if present
	local corner = instance:FindFirstChildOfClass("UICorner")
	if corner then
		local shadowCorner = corner:Clone()
		shadowCorner.Parent = shadow
	end
	
	return shadow
end

-- Add List Layout
function Effects.addListLayout(instance, direction, alignment, padding)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction or Enum.FillDirection.Vertical
	layout.HorizontalAlignment = alignment or Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, padding or DesignSystem.Spacing.MD)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = instance
	return layout
end

-- Add Grid Layout
function Effects.addGridLayout(instance, cellSize, cellPadding, fillDirection)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = cellSize or UDim2.new(0, 200, 0, 200)
	layout.CellPadding = cellPadding or UDim2.new(0, DesignSystem.Spacing.MD, 0, DesignSystem.Spacing.MD)
	layout.FillDirection = fillDirection or Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = instance
	return layout
end

-- ============================================================================
-- DATA MANAGEMENT
-- ============================================================================

local DataManager = {}
DataManager.cache = {
	products = {},
	ownership = {},
	prices = {},
}
DataManager.cacheTimeout = 300 -- 5 minutes

-- Asset IDs (Replace with your own)
local Assets = {
	Icons = {
		Shop = "rbxassetid://7733911828",
		Cash = "rbxassetid://7733674079", 
		Gamepass = "rbxassetid://7733674135",
		Close = "rbxassetid://7734053495",
		Settings = "rbxassetid://7734042071",
		Check = "rbxassetid://7733674214",
		Lock = "rbxassetid://7733674389",
	},
	Sounds = {
		Click = "rbxassetid://131961136",
		Success = "rbxassetid://131961136", 
		Error = "rbxassetid://131961136",
		Hover = "rbxassetid://131961136",
	}
}

-- Product Data
DataManager.products = {
	cash = {
		{id = 1897730242, amount = 1000, name = "Starter Pack", description = "Perfect for beginners", icon = Assets.Icons.Cash},
		{id = 1897730373, amount = 5000, name = "Growth Bundle", description = "Accelerate your progress", icon = Assets.Icons.Cash},
		{id = 1897730467, amount = 15000, name = "Success Kit", description = "Unlock new possibilities", icon = Assets.Icons.Cash},
		{id = 1897730581, amount = 50000, name = "Entrepreneur Pack", description = "Build your empire", icon = Assets.Icons.Cash},
		{id = 1234567001, amount = 125000, name = "Business Elite", description = "Premium expansion fund", icon = Assets.Icons.Cash},
		{id = 1234567002, amount = 300000, name = "Tycoon Master", description = "Dominate the competition", icon = Assets.Icons.Cash},
		{id = 1234567003, amount = 750000, name = "Empire Builder", description = "Massive growth potential", icon = Assets.Icons.Cash},
		{id = 1234567004, amount = 1500000, name = "Millionaire Club", description = "Elite status unlocked", icon = Assets.Icons.Cash},
		{id = 1234567005, amount = 3500000, name = "Fortune Maker", description = "Unlimited possibilities", icon = Assets.Icons.Cash},
		{id = 1234567006, amount = 10000000, name = "Ultimate Tycoon", description = "The pinnacle of success", icon = Assets.Icons.Cash},
	},
	gamepasses = {
		{id = 1412171840, name = "Auto Collect", description = "Automatically collect cash from your tycoon", icon = Assets.Icons.Gamepass, hasToggle = true},
		{id = 1398974710, name = "2x Cash Multiplier", description = "Double all cash earned from your tycoon", icon = Assets.Icons.Gamepass, hasToggle = false},
	}
}

-- Get product info with caching
function DataManager.getProductInfo(productId)
	local cacheKey = "product_" .. productId
	local cached = DataManager.cache.products[cacheKey]
	
	if cached and (os.clock() - cached.timestamp) < DataManager.cacheTimeout then
		return cached.data
	end
	
	local success, info = pcall(function()
		return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
	end)
	
	if success and info then
		DataManager.cache.products[cacheKey] = {
			data = info,
			timestamp = os.clock()
		}
		return info
	end
	
	return nil
end

-- Get gamepass info with caching
function DataManager.getGamepassInfo(gamepassId)
	local cacheKey = "gamepass_" .. gamepassId
	local cached = DataManager.cache.products[cacheKey]
	
	if cached and (os.clock() - cached.timestamp) < DataManager.cacheTimeout then
		return cached.data
	end
	
	local success, info = pcall(function()
		return MarketplaceService:GetProductInfo(gamepassId, Enum.InfoType.GamePass)
	end)
	
	if success and info then
		DataManager.cache.products[cacheKey] = {
			data = info,
			timestamp = os.clock()
		}
		return info
	end
	
	return nil
end

-- Check gamepass ownership with caching
function DataManager.checkOwnership(gamepassId)
	local cacheKey = Player.UserId .. "_" .. gamepassId
	local cached = DataManager.cache.ownership[cacheKey]
	
	if cached and (os.clock() - cached.timestamp) < 60 then -- 1 minute cache for ownership
		return cached.data
	end
	
	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, gamepassId)
	end)
	
	if success then
		DataManager.cache.ownership[cacheKey] = {
			data = owns,
			timestamp = os.clock()
		}
		return owns
	end
	
	return false
end

-- Refresh all product prices
function DataManager.refreshPrices()
	for _, product in ipairs(DataManager.products.cash) do
		local info = DataManager.getProductInfo(product.id)
		if info then
			product.price = info.PriceInRobux or 0
		end
	end
	
	for _, gamepass in ipairs(DataManager.products.gamepasses) do
		local info = DataManager.getGamepassInfo(gamepass.id)
		if info then
			gamepass.price = info.PriceInRobux or 0
		end
	end
end

-- ============================================================================
-- SHOP UI COMPONENTS
-- ============================================================================

local ShopComponents = {}

-- Toggle Switch Component
function ShopComponents.createToggle(props)
	props = props or {}
	local isEnabled = props.enabled or false
	local onToggle = props.onToggle or function() end
	local label = props.label or "Toggle"
	
	-- Container
	local container = Components.Frame({
		Size = UDim2.new(0, 200, 0, 32),
		BackgroundTransparency = 1,
	})
	
	-- Label
	local labelText = Components.Text({
		Text = label,
		Size = UDim2.new(0, 120, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = DesignSystem.Colors.TextSecondary,
		Font = DesignSystem.Typography.FontMedium,
		TextSize = DesignSystem.Typography.Size14,
		Parent = container.instance,
	})
	
	-- Toggle Track
	local track = Components.Frame({
		Size = UDim2.new(0, 48, 0, 24),
		Position = UDim2.new(1, -48, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = isEnabled and DesignSystem.Colors.Success or DesignSystem.Colors.Border,
		Parent = container.instance,
	})
	Effects.addCorner(track.instance, DesignSystem.Radius.Full)
	
	-- Toggle Thumb
	local thumb = Components.Frame({
		Size = UDim2.new(0, 20, 0, 20),
		Position = UDim2.new(0, isEnabled and 26 or 2, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = DesignSystem.Colors.Surface,
		Parent = track.instance,
	})
	Effects.addCorner(thumb.instance, DesignSystem.Radius.Full)
	Effects.addStroke(thumb.instance, DesignSystem.Colors.Border, 1, 0.5)
	
	-- Toggle Button (Invisible)
	local button = Components.Button({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Parent = track.instance,
		onClick = function()
			isEnabled = not isEnabled
			
			-- Animate track color
			Utils.tween(track.instance, {
				BackgroundColor3 = isEnabled and DesignSystem.Colors.Success or DesignSystem.Colors.Border
			}, DesignSystem.Animation.Fast)
			
			-- Animate thumb position
			Utils.tween(thumb.instance, {
				Position = UDim2.new(0, isEnabled and 26 or 2, 0.5, 0)
			}, DesignSystem.Animation.Fast)
			
			-- Play sound
			Utils.playSound(Assets.Sounds.Click, 0.3)
			
			-- Callback
			onToggle(isEnabled)
		end
	})
	
	-- Public methods
	container.setEnabled = function(enabled)
		isEnabled = enabled
		track.instance.BackgroundColor3 = isEnabled and DesignSystem.Colors.Success or DesignSystem.Colors.Border
		thumb.instance.Position = UDim2.new(0, isEnabled and 26 or 2, 0.5, 0)
	end
	
	container.getEnabled = function()
		return isEnabled
	end
	
	return container
end

-- Product Card Component
function ShopComponents.createProductCard(product, cardType)
	cardType = cardType or "cash"
	
	-- Main Card Container
	local card = Components.Frame({
		Size = UDim2.new(1, 0, 0, 0), -- Height will be set by aspect ratio
		BackgroundColor3 = DesignSystem.Colors.Surface,
	})
	Effects.addCorner(card.instance, DesignSystem.Radius.LG)
	Effects.addStroke(card.instance, DesignSystem.Colors.Border, 1, 0.8)
	
	-- Aspect Ratio Constraint
	local aspectRatio = Instance.new("UIAspectRatioConstraint")
	aspectRatio.AspectRatio = 1.2 -- Width:Height ratio
	aspectRatio.DominantAxis = Enum.DominantAxis.Width
	aspectRatio.Parent = card.instance
	
	-- Card Content Container
	local content = Components.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = card.instance,
	})
	Effects.addPadding(content.instance, DesignSystem.Spacing.LG)
	Effects.addListLayout(content.instance, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center, DesignSystem.Spacing.MD)
	
	-- Header Section (Icon + Title)
	local header = Components.Frame({
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = content.instance,
	})
	
	local headerLayout = Effects.addListLayout(header.instance, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, DesignSystem.Spacing.SM)
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	
	-- Product Icon
	local icon = Components.Image({
		Image = product.icon or Assets.Icons.Cash,
		Size = UDim2.new(0, 40, 0, 40),
		LayoutOrder = 1,
		Parent = header.instance,
	})
	Effects.addCorner(icon.instance, DesignSystem.Radius.SM)
	
	-- Product Title
	local title = Components.Text({
		Text = product.name or "Product",
		Size = UDim2.new(1, -48, 1, 0),
		Font = DesignSystem.Typography.FontSemiBold,
		TextSize = DesignSystem.Typography.Size18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = DesignSystem.Colors.TextPrimary,
		LayoutOrder = 2,
		Parent = header.instance,
	})
	
	-- Description
	local description = Components.Text({
		Text = product.description or "No description available",
		Size = UDim2.new(1, 0, 0, 36),
		Font = DesignSystem.Typography.FontRegular,
		TextSize = DesignSystem.Typography.Size14,
		TextColor3 = DesignSystem.Colors.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Parent = content.instance,
	})
	
	-- Price Section
	local priceContainer = Components.Frame({
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = content.instance,
	})
	
	local priceText = ""
	if cardType == "cash" then
		local price = product.price or 0
		priceText = string.format("R$%d • %s Cash", price, Utils.formatCurrency(product.amount or 0))
	else
		local price = product.price or 0
		priceText = string.format("R$%d", price)
	end
	
	local priceLabel = Components.Text({
		Text = priceText,
		Size = UDim2.fromScale(1, 1),
		Font = DesignSystem.Typography.FontSemiBold,
		TextSize = DesignSystem.Typography.Size16,
		TextColor3 = cardType == "cash" and DesignSystem.Colors.Cash or DesignSystem.Colors.Gamepass,
		LayoutOrder = 1,
		Parent = priceContainer.instance,
	})
	
	-- Action Button
	local buttonColor = cardType == "cash" and DesignSystem.Colors.Cash or DesignSystem.Colors.Gamepass
	local buttonText = "Purchase"
	
	-- Check ownership for gamepasses
	if cardType == "gamepass" then
		local owned = DataManager.checkOwnership(product.id)
		if owned then
			buttonText = "Owned"
			buttonColor = DesignSystem.Colors.Success
		end
	end
	
	local actionButton = Components.Button({
		Text = buttonText,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = buttonColor,
		Font = DesignSystem.Typography.FontSemiBold,
		TextSize = DesignSystem.Typography.Size16,
		LayoutOrder = 4,
		Parent = content.instance,
	})
	Effects.addCorner(actionButton.instance, DesignSystem.Radius.SM)
	
	-- Toggle for Auto Collect (if applicable)
	local toggle = nil
	if cardType == "gamepass" and product.hasToggle and DataManager.checkOwnership(product.id) then
		toggle = ShopComponents.createToggle({
			label = "Enable " .. product.name,
			enabled = false, -- Will be set from server
			onToggle = function(enabled)
				if Remotes then
					local toggleRemote = Remotes:FindFirstChild("AutoCollectToggle")
					if toggleRemote and toggleRemote:IsA("RemoteEvent") then
						toggleRemote:FireServer(enabled)
					end
				end
			end
		})
		toggle.instance.Size = UDim2.new(1, 0, 0, 32)
		toggle.instance.LayoutOrder = 5
		toggle.instance.Parent = content.instance
	end
	
	-- Hover Effects
	local originalColor = card.instance.BackgroundColor3
	local hoverColor = Utils.lightenColor(originalColor, 0.03)
	
	card.instance.MouseEnter:Connect(function()
		Utils.tween(card.instance, {
			BackgroundColor3 = hoverColor,
		}, DesignSystem.Animation.Fast)
		
		Utils.tween(card.instance, {
			Size = UDim2.new(1, 0, 0, card.instance.AbsoluteSize.Y * 1.02)
		}, DesignSystem.Animation.Fast)
	end)
	
	card.instance.MouseLeave:Connect(function()
		Utils.tween(card.instance, {
			BackgroundColor3 = originalColor,
		}, DesignSystem.Animation.Fast)
		
		Utils.tween(card.instance, {
			Size = UDim2.new(1, 0, 0, 0) -- Reset to aspect ratio controlled
		}, DesignSystem.Animation.Fast)
	end)
	
	-- Store references for updates
	card.priceLabel = priceLabel
	card.actionButton = actionButton
	card.toggle = toggle
	card.product = product
	
	return card
end

-- ============================================================================
-- MAIN SHOP INTERFACE
-- ============================================================================

local TycoonShop = {}
TycoonShop.__index = TycoonShop

function TycoonShop.new()
	local self = setmetatable({}, TycoonShop)
	
	-- State
	self.isOpen = false
	self.isAnimating = false
	self.currentTab = "cash"
	self.purchasePending = {}
	
	-- UI References
	self.gui = nil
	self.backdrop = nil
	self.panel = nil
	self.blur = nil
	self.cashCards = {}
	self.gamepassCards = {}
	
	-- Responsive state
	self.currentBreakpoint = Utils.getBreakpoint()
	self.gridLayout = nil
	
	self:createUI()
	self:setupResponsive()
	self:setupInput()
	self:setupMarketplace()
	
	-- Initial data refresh
	DataManager.refreshPrices()
	self:refreshUI()
	
	return self
end

function TycoonShop:createUI()
	-- Main ScreenGui
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "TycoonShopUI"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 100
	self.gui.IgnoreGuiInset = false
	self.gui.Enabled = false
	self.gui.Parent = PlayerGui
	
	-- Backdrop
	self.backdrop = Components.Frame({
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = DesignSystem.Colors.Overlay,
		BackgroundTransparency = 0.4,
		Parent = self.gui,
	})
	
	-- Blur Effect
	self.blur = Instance.new("BlurEffect")
	self.blur.Name = "ShopBlur"
	self.blur.Size = 0
	self.blur.Parent = Lighting
	
	-- Main Panel
	self.panel = Components.Frame({
		Name = "ShopPanel", 
		Size = UDim2.new(0.92, 0, 0.88, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = DesignSystem.Colors.Background,
		Parent = self.gui,
	})
	Effects.addCorner(self.panel.instance, DesignSystem.Radius.XL)
	Effects.addStroke(self.panel.instance, DesignSystem.Colors.Border, 1, 0.6)
	
	-- Apply safe area padding
	local safeInsets = Utils.getSafeAreaInsets()
	Effects.addPadding(self.panel.instance, {
		top = math.max(safeInsets.Top, DesignSystem.Spacing.LG),
		bottom = math.max(safeInsets.Bottom, DesignSystem.Spacing.LG),
		left = math.max(safeInsets.Left, DesignSystem.Spacing.LG),
		right = math.max(safeInsets.Right, DesignSystem.Spacing.LG),
	})
	
	-- Panel Layout
	Effects.addListLayout(self.panel.instance, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center, 0)
	
	self:createHeader()
	self:createNavigation()
	self:createContent()
end

function TycoonShop:createHeader()
	-- Header Container
	local header = Components.Frame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundColor3 = DesignSystem.Colors.Surface,
		LayoutOrder = 1,
		Parent = self.panel.instance,
	})
	Effects.addCorner(header.instance, DesignSystem.Radius.LG)
	Effects.addStroke(header.instance, DesignSystem.Colors.Border, 1, 0.4)
	Effects.addPadding(header.instance, DesignSystem.Spacing.LG)
	
	-- Header Layout
	local headerLayout = Effects.addListLayout(header.instance, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, DesignSystem.Spacing.MD)
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	
	-- Shop Icon
	local shopIcon = Components.Image({
		Image = Assets.Icons.Shop,
		Size = UDim2.new(0, 48, 0, 48),
		LayoutOrder = 1,
		Parent = header.instance,
	})
	Effects.addCorner(shopIcon.instance, DesignSystem.Radius.MD)
	
	-- Title Section
	local titleContainer = Components.Frame({
		Size = UDim2.new(1, -160, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = header.instance,
	})
	Effects.addListLayout(titleContainer.instance, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, 4)
	
	local title = Components.Text({
		Text = "Tycoon Shop",
		Size = UDim2.new(1, 0, 0, 28),
		Font = DesignSystem.Typography.FontBold,
		TextSize = DesignSystem.Typography.Size24,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = DesignSystem.Colors.TextPrimary,
		LayoutOrder = 1,
		Parent = titleContainer.instance,
	})
	
	local subtitle = Components.Text({
		Text = "Purchase upgrades and boosts for your tycoon",
		Size = UDim2.new(1, 0, 0, 20),
		Font = DesignSystem.Typography.FontRegular,
		TextSize = DesignSystem.Typography.Size14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = DesignSystem.Colors.TextSecondary,
		LayoutOrder = 2,
		Parent = titleContainer.instance,
	})
	
	-- Close Button
	local closeButton = Components.Button({
		Text = "✕",
		Size = UDim2.new(0, 48, 0, 48),
		BackgroundColor3 = DesignSystem.Colors.Error,
		Font = DesignSystem.Typography.FontBold,
		TextSize = DesignSystem.Typography.Size20,
		LayoutOrder = 3,
		Parent = header.instance,
		onClick = function()
			self:close()
		end
	})
	Effects.addCorner(closeButton.instance, DesignSystem.Radius.Full)
end

function TycoonShop:createNavigation()
	-- Navigation Container
	local nav = Components.Frame({
		Name = "Navigation",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = DesignSystem.Colors.SurfaceVariant,
		LayoutOrder = 2,
		Parent = self.panel.instance,
	})
	Effects.addCorner(nav.instance, DesignSystem.Radius.LG)
	Effects.addPadding(nav.instance, DesignSystem.Spacing.SM)
	
	-- Tab Container
	local tabContainer = Components.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = nav.instance,
	})
	Effects.addListLayout(tabContainer.instance, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, DesignSystem.Spacing.SM)
	
	-- Tab Buttons
	self.tabButtons = {}
	
	local tabs = {
		{id = "cash", name = "Cash Packs", icon = Assets.Icons.Cash, color = DesignSystem.Colors.Cash},
		{id = "gamepasses", name = "Game Passes", icon = Assets.Icons.Gamepass, color = DesignSystem.Colors.Gamepass},
	}
	
	for i, tab in ipairs(tabs) do
		local isActive = tab.id == self.currentTab
		
		local button = Components.Button({
			Text = "",
			Size = UDim2.new(0.5, -4, 1, 0),
			BackgroundColor3 = isActive and tab.color or DesignSystem.Colors.Surface,
			LayoutOrder = i,
			Parent = tabContainer.instance,
			onClick = function()
				self:switchTab(tab.id)
			end
		})
		Effects.addCorner(button.instance, DesignSystem.Radius.MD)
		
		-- Button Content
		local buttonContent = Components.Frame({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = button.instance,
		})
		Effects.addPadding(buttonContent.instance, DesignSystem.Spacing.MD)
		Effects.addListLayout(buttonContent.instance, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, DesignSystem.Spacing.SM)
		
		local icon = Components.Image({
			Image = tab.icon,
			Size = UDim2.new(0, 24, 0, 24),
			ImageColor3 = isActive and DesignSystem.Colors.TextInverse or DesignSystem.Colors.TextSecondary,
			LayoutOrder = 1,
			Parent = buttonContent.instance,
		})
		
		local label = Components.Text({
			Text = tab.name,
			Size = UDim2.new(0, 100, 1, 0),
			Font = DesignSystem.Typography.FontSemiBold,
			TextSize = DesignSystem.Typography.Size16,
			TextColor3 = isActive and DesignSystem.Colors.TextInverse or DesignSystem.Colors.TextSecondary,
			LayoutOrder = 2,
			Parent = buttonContent.instance,
		})
		
		self.tabButtons[tab.id] = {
			button = button,
			icon = icon,
			label = label,
			color = tab.color
		}
	end
end

function TycoonShop:createContent()
	-- Content Container
	local content = Components.Frame({
		Name = "Content",
		Size = UDim2.new(1, 0, 1, -152), -- Remaining space after header and nav
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = self.panel.instance,
	})
	
	-- Cash Page
	self.cashPage = self:createCashPage(content.instance)
	
	-- Gamepasses Page  
	self.gamepassPage = self:createGamepassPage(content.instance)
	
	-- Show initial tab
	self:switchTab(self.currentTab)
end

function TycoonShop:createCashPage(parent)
	local page = Components.Frame({
		Name = "CashPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})
	Effects.addPadding(page.instance, {top = DesignSystem.Spacing.LG})
	
	-- Page Header
	local pageHeader = Components.Frame({
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		Parent = page.instance,
	})
	
	local headerTitle = Components.Text({
		Text = "Cash Packs",
		Size = UDim2.new(0.7, 0, 1, 0),
		Font = DesignSystem.Typography.FontSemiBold,
		TextSize = DesignSystem.Typography.Size20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = DesignSystem.Colors.TextPrimary,
		Parent = pageHeader.instance,
	})
	
	local headerSubtitle = Components.Text({
		Text = string.format("%d items available", #DataManager.products.cash),
		Size = UDim2.new(0.3, 0, 1, 0),
		Font = DesignSystem.Typography.FontRegular,
		TextSize = DesignSystem.Typography.Size14,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = DesignSystem.Colors.TextSecondary,
		Parent = pageHeader.instance,
	})
	
	-- Scrolling Container
	local scrollFrame = Components.ScrollingFrame({
		Size = UDim2.new(1, 0, 1, -56),
		Position = UDim2.new(0, 0, 0, 56),
		Parent = page.instance,
	})
	Effects.addPadding(scrollFrame.instance, DesignSystem.Spacing.MD)
	
	-- Grid Layout
	self.cashGrid = Effects.addGridLayout(
		scrollFrame.instance,
		UDim2.new(1, 0, 0, 200), -- Will be updated by responsive system
		UDim2.new(0, DesignSystem.Spacing.LG, 0, DesignSystem.Spacing.LG),
		Enum.FillDirection.Horizontal
	)
	
	-- Create product cards
	self.cashCards = {}
	for i, product in ipairs(DataManager.products.cash) do
		local card = ShopComponents.createProductCard(product, "cash")
		card.instance.LayoutOrder = i
		card.instance.Parent = scrollFrame.instance
		table.insert(self.cashCards, card)
		
		-- Add purchase handler
		card.actionButton.instance.MouseButton1Click:Connect(function()
			self:purchaseProduct(product)
		end)
	end
	
	return page
end

function TycoonShop:createGamepassPage(parent)
	local page = Components.Frame({
		Name = "GamepassPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})
	Effects.addPadding(page.instance, {top = DesignSystem.Spacing.LG})
	
	-- Page Header
	local pageHeader = Components.Frame({
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		Parent = page.instance,
	})
	
	local headerTitle = Components.Text({
		Text = "Game Passes",
		Size = UDim2.new(0.7, 0, 1, 0),
		Font = DesignSystem.Typography.FontSemiBold,
		TextSize = DesignSystem.Typography.Size20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = DesignSystem.Colors.TextPrimary,
		Parent = pageHeader.instance,
	})
	
	local headerSubtitle = Components.Text({
		Text = string.format("%d passes available", #DataManager.products.gamepasses),
		Size = UDim2.new(0.3, 0, 1, 0),
		Font = DesignSystem.Typography.FontRegular,
		TextSize = DesignSystem.Typography.Size14,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = DesignSystem.Colors.TextSecondary,
		Parent = pageHeader.instance,
	})
	
	-- Scrolling Container
	local scrollFrame = Components.ScrollingFrame({
		Size = UDim2.new(1, 0, 1, -56),
		Position = UDim2.new(0, 0, 0, 56),
		Parent = page.instance,
	})
	Effects.addPadding(scrollFrame.instance, DesignSystem.Spacing.MD)
	
	-- Grid Layout  
	self.gamepassGrid = Effects.addGridLayout(
		scrollFrame.instance,
		UDim2.new(1, 0, 0, 200), -- Will be updated by responsive system
		UDim2.new(0, DesignSystem.Spacing.LG, 0, DesignSystem.Spacing.LG),
		Enum.FillDirection.Horizontal
	)
	
	-- Create gamepass cards
	self.gamepassCards = {}
	for i, gamepass in ipairs(DataManager.products.gamepasses) do
		local card = ShopComponents.createProductCard(gamepass, "gamepass")
		card.instance.LayoutOrder = i
		card.instance.Parent = scrollFrame.instance
		table.insert(self.gamepassCards, card)
		
		-- Add purchase handler
		card.actionButton.instance.MouseButton1Click:Connect(function()
			if not DataManager.checkOwnership(gamepass.id) then
				self:purchaseGamepass(gamepass)
			end
		end)
	end
	
	return page
end

function TycoonShop:setupResponsive()
	local function updateLayout()
		local breakpoint = Utils.getBreakpoint()
		local columns = 1
		
		if breakpoint == "md" then
			columns = 2
		elseif breakpoint == "lg" then
			columns = 3
		end
		
		-- Update grid layouts
		if self.cashGrid then
			self.cashGrid.FillDirectionMaxCells = columns
		end
		if self.gamepassGrid then
			self.gamepassGrid.FillDirectionMaxCells = columns
		end
		
		self.currentBreakpoint = breakpoint
	end
	
	-- Initial update
	updateLayout()
	
	-- Listen for viewport changes
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
end

function TycoonShop:setupInput()
	-- Keyboard input
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.M then
			self:toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and self.isOpen then
			self:close()
		end
	end)
	
	-- Gamepad input
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.ButtonX then
			self:toggle()
		end
	end)
	
	-- Backdrop click to close
	self.backdrop.instance.MouseButton1Click:Connect(function()
		self:close()
	end)
end

function TycoonShop:setupMarketplace()
	-- Product purchase finished
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, purchased)
		if player ~= Player then return end
		
		local pendingData = self.purchasePending[productId]
		if not pendingData then return end
		
		self.purchasePending[productId] = nil
		
		if purchased then
			-- Success feedback
			Utils.playSound(Assets.Sounds.Success, 0.7)
			
			-- Fire server remote
			if Remotes then
				local grantRemote = Remotes:FindFirstChild("GrantProductCurrency")
				if grantRemote and grantRemote:IsA("RemoteEvent") then
					grantRemote:FireServer(productId)
				end
			end
		else
			-- Reset button state
			local card = pendingData.card
			if card and card.actionButton then
				card.actionButton.instance.Text = "Purchase"
				card.actionButton.instance.BackgroundColor3 = DesignSystem.Colors.Cash
			end
		end
	end)
	
	-- Gamepass purchase finished
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, purchased)
		if player ~= Player then return end
		
		local pendingData = self.purchasePending[gamepassId]
		if not pendingData then return end
		
		self.purchasePending[gamepassId] = nil
		
		if purchased then
			-- Success feedback
			Utils.playSound(Assets.Sounds.Success, 0.7)
			
			-- Update ownership cache
			DataManager.cache.ownership[Player.UserId .. "_" .. gamepassId] = {
				data = true,
				timestamp = os.clock()
			}
			
			-- Refresh UI
			self:refreshUI()
			
			-- Fire server remote
			if Remotes then
				local purchaseRemote = Remotes:FindFirstChild("GamepassPurchased")
				if purchaseRemote and purchaseRemote:IsA("RemoteEvent") then
					purchaseRemote:FireServer(gamepassId)
				end
			end
		else
			-- Reset button state
			local card = pendingData.card
			if card and card.actionButton then
				card.actionButton.instance.Text = "Purchase"
				card.actionButton.instance.BackgroundColor3 = DesignSystem.Colors.Gamepass
			end
		end
	end)
end

-- ============================================================================
-- SHOP METHODS
-- ============================================================================

function TycoonShop:open()
	if self.isOpen or self.isAnimating then return end
	
	self.isAnimating = true
	self.isOpen = true
	
	-- Refresh data
	DataManager.refreshPrices()
	self:refreshUI()
	
	-- Show GUI
	self.gui.Enabled = true
	
	-- Animate backdrop
	self.backdrop.instance.BackgroundTransparency = 1
	Utils.tween(self.backdrop.instance, {
		BackgroundTransparency = 0.4
	}, DesignSystem.Animation.Medium)
	
	-- Animate blur
	Utils.tween(self.blur, {
		Size = 24
	}, DesignSystem.Animation.Medium)
	
	-- Animate panel
	self.panel.instance.Position = UDim2.fromScale(0.5, 0.6)
	self.panel.instance.Size = UDim2.new(0.8, 0, 0.8, 0)
	
	Utils.tween(self.panel.instance, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0.88, 0)
	}, DesignSystem.Animation.Slow, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function()
		self.isAnimating = false
	end)
	
	-- Play sound
	Utils.playSound(Assets.Sounds.Click, 0.6)
end

function TycoonShop:close()
	if not self.isOpen or self.isAnimating then return end
	
	self.isAnimating = true
	self.isOpen = false
	
	-- Animate backdrop
	Utils.tween(self.backdrop.instance, {
		BackgroundTransparency = 1
	}, DesignSystem.Animation.Fast)
	
	-- Animate blur
	Utils.tween(self.blur, {
		Size = 0
	}, DesignSystem.Animation.Fast)
	
	-- Animate panel
	Utils.tween(self.panel.instance, {
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.new(0.8, 0, 0.8, 0)
	}, DesignSystem.Animation.Fast, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function()
		self.gui.Enabled = false
		self.isAnimating = false
	end)
	
	-- Play sound
	Utils.playSound(Assets.Sounds.Click, 0.4)
end

function TycoonShop:toggle()
	if self.isOpen then
		self:close()
	else
		self:open()
	end
end

function TycoonShop:switchTab(tabId)
	if self.currentTab == tabId then return end
	
	self.currentTab = tabId
	
	-- Update tab buttons
	for id, tabData in pairs(self.tabButtons) do
		local isActive = id == tabId
		
		Utils.tween(tabData.button.instance, {
			BackgroundColor3 = isActive and tabData.color or DesignSystem.Colors.Surface
		}, DesignSystem.Animation.Fast)
		
		Utils.tween(tabData.icon.instance, {
			ImageColor3 = isActive and DesignSystem.Colors.TextInverse or DesignSystem.Colors.TextSecondary
		}, DesignSystem.Animation.Fast)
		
		Utils.tween(tabData.label.instance, {
			TextColor3 = isActive and DesignSystem.Colors.TextInverse or DesignSystem.Colors.TextSecondary
		}, DesignSystem.Animation.Fast)
	end
	
	-- Show/hide pages
	self.cashPage.instance.Visible = (tabId == "cash")
	self.gamepassPage.instance.Visible = (tabId == "gamepasses")
	
	-- Play sound
	Utils.playSound(Assets.Sounds.Hover, 0.3)
end

function TycoonShop:refreshUI()
	-- Update cash cards
	for _, card in ipairs(self.cashCards) do
		local product = card.product
		local info = DataManager.getProductInfo(product.id)
		if info then
			product.price = info.PriceInRobux or 0
			local priceText = string.format("R$%d • %s Cash", product.price, Utils.formatCurrency(product.amount))
			card.priceLabel.instance.Text = priceText
		end
	end
	
	-- Update gamepass cards
	for _, card in ipairs(self.gamepassCards) do
		local gamepass = card.product
		local info = DataManager.getGamepassInfo(gamepass.id)
		if info then
			gamepass.price = info.PriceInRobux or 0
			card.priceLabel.instance.Text = string.format("R$%d", gamepass.price)
		end
		
		-- Update ownership status
		local owned = DataManager.checkOwnership(gamepass.id)
		if owned then
			card.actionButton.instance.Text = "Owned"
			card.actionButton.instance.BackgroundColor3 = DesignSystem.Colors.Success
			
			-- Show toggle if applicable
			if card.toggle and gamepass.hasToggle then
				card.toggle.instance.Visible = true
				
				-- Get toggle state from server
				if Remotes then
					local stateRemote = Remotes:FindFirstChild("GetAutoCollectState")
					if stateRemote and stateRemote:IsA("RemoteFunction") then
						local success, enabled = pcall(function()
							return stateRemote:InvokeServer()
						end)
						if success and typeof(enabled) == "boolean" then
							card.toggle.setEnabled(enabled)
						end
					end
				end
			end
		else
			card.actionButton.instance.Text = "Purchase"
			card.actionButton.instance.BackgroundColor3 = DesignSystem.Colors.Gamepass
			if card.toggle then
				card.toggle.instance.Visible = false
			end
		end
	end
end

function TycoonShop:purchaseProduct(product)
	if self.purchasePending[product.id] then return end
	
	-- Find the card
	local card = nil
	for _, c in ipairs(self.cashCards) do
		if c.product.id == product.id then
			card = c
			break
		end
	end
	
	if not card then return end
	
	-- Update button state
	card.actionButton.instance.Text = "Processing..."
	card.actionButton.instance.BackgroundColor3 = DesignSystem.Colors.Border
	
	-- Store pending state
	self.purchasePending[product.id] = {
		card = card,
		timestamp = os.clock()
	}
	
	-- Prompt purchase
	local success = pcall(function()
		MarketplaceService:PromptProductPurchase(Player, product.id)
	end)
	
	if not success then
		-- Reset on error
		card.actionButton.instance.Text = "Purchase"
		card.actionButton.instance.BackgroundColor3 = DesignSystem.Colors.Cash
		self.purchasePending[product.id] = nil
		Utils.playSound(Assets.Sounds.Error, 0.5)
	end
end

function TycoonShop:purchaseGamepass(gamepass)
	if self.purchasePending[gamepass.id] then return end
	
	-- Find the card
	local card = nil
	for _, c in ipairs(self.gamepassCards) do
		if c.product.id == gamepass.id then
			card = c
			break
		end
	end
	
	if not card then return end
	
	-- Update button state
	card.actionButton.instance.Text = "Processing..."
	card.actionButton.instance.BackgroundColor3 = DesignSystem.Colors.Border
	
	-- Store pending state
	self.purchasePending[gamepass.id] = {
		card = card,
		timestamp = os.clock()
	}
	
	-- Prompt purchase
	local success = pcall(function()
		MarketplaceService:PromptGamePassPurchase(Player, gamepass.id)
	end)
	
	if not success then
		-- Reset on error
		card.actionButton.instance.Text = "Purchase"
		card.actionButton.instance.BackgroundColor3 = DesignSystem.Colors.Gamepass
		self.purchasePending[gamepass.id] = nil
		Utils.playSound(Assets.Sounds.Error, 0.5)
	end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Create shop instance
local shop = TycoonShop.new()

-- Periodic refresh
task.spawn(function()
	while true do
		task.wait(30) -- Refresh every 30 seconds
		if shop.isOpen then
			DataManager.refreshPrices()
			shop:refreshUI()
		end
	end
end)

-- Handle character respawn
Player.CharacterAdded:Connect(function()
	task.wait(2) -- Wait for character to load
	-- Shop persists through respawns
end)

-- Cleanup on leave
game:BindToClose(function()
	if shop.blur then
		shop.blur:Destroy()
	end
end)

-- Export for external access
_G.TycoonShop = shop

print("🏪 Tycoon Shop UI loaded successfully!")
print("📱 Press M to open shop, ESC to close")
print("🎮 Gamepad: Press X to toggle shop")

return shop