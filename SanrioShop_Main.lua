--[[
    SANRIO SHOP SYSTEM - MAIN IMPLEMENTATION
    Modern, Professional Shop System with Clean Architecture

    Features:
    - Modular design with separate Core and UI modules
    - Advanced state management and caching
    - Smooth animations and transitions
    - Modern UI with effects and responsive design
    - Comprehensive error handling
    - Professional purchase flow
--]]

-- Services
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

-- Load Modules
local Core = require(script.Parent.SanrioShop_Core)
local UI = require(script.Parent.SanrioShop_UI)

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)

-- ========================================
-- SHOP IMPLEMENTATION
-- ========================================
local Shop = {}
Shop.__index = Shop

function Shop.new()
	local self = setmetatable({}, Shop)

	self.gui = nil
	self.mainPanel = nil
	self.tabContainer = nil
	self.contentContainer = nil
	self.currentTab = "Home"
	self.tabs = {}
	self.pages = {}
	self.toggleButton = nil
	self.blur = nil
	self.notifications = {}

	self:initialize()

	return self
end

function Shop:initialize()
	Core.SoundSystem.initialize()
	Core.DataManager.refreshPrices()

	self:createToggleButton()
	self:createMainInterface()
	self:setupRemoteHandlers()
	self:setupInputHandlers()
	self:setupPurchaseHandlers()

	-- Ensure Home tab is selected after initialization
	task.defer(function()
		self:selectTab("Home")
	end)

	Core.State.initialized = true
	Core.Events:emit("shopInitialized")

	print("[SanrioShop] System initialized successfully!")
end

function Shop:createToggleButton()
	local toggleScreen = PlayerGui:FindFirstChild("SanrioShopToggle") or Instance.new("ScreenGui")
	toggleScreen.Name = "SanrioShopToggle"
	toggleScreen.ResetOnSpawn = false
	toggleScreen.DisplayOrder = 999
	toggleScreen.Parent = PlayerGui

	self.toggleButton = UI.Components.Button({
		Name = "ShopToggle",
		Text = "",
		Size = UDim2.fromOffset(180, 60),
		Position = UDim2.new(1, -20, 1, -20),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(1, 0),
		stroke = {
			color = UI.Theme:get("accent"),
			thickness = 2,
		},
		parent = toggleScreen,
		onClick = function()
			self:toggle()
		end,
	}):render()

	-- Add shimmer effect to toggle button
	local shimmerEffect = UI.Effects.addShimmer(self.toggleButton, 3)

	local icon = UI.Components.Image({
		Name = "Icon",
		Image = "rbxassetid://17398522865",
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(16, 14),
		parent = self.toggleButton,
	}):render()

	local label = UI.Components.TextLabel({
		Name = "Label",
		Text = "Shop",
		Size = UDim2.new(1, -64, 1, 0),
		Position = UDim2.fromOffset(56, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		parent = self.toggleButton,
	}):render()

	self:addPulseAnimation(self.toggleButton)
end

function Shop:createMainInterface()
	self.gui = PlayerGui:FindFirstChild("SanrioShopMain") or Instance.new("ScreenGui")
	self.gui.Name = "SanrioShopMain"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 1000
	self.gui.Enabled = false
	self.gui.Parent = PlayerGui

	self.blur = Lighting:FindFirstChild("SanrioShopBlur") or Instance.new("BlurEffect")
	self.blur.Name = "SanrioShopBlur"
	self.blur.Size = 0
	self.blur.Parent = Lighting

	-- Dim background
	local dimBackground = UI.Components.Frame({
		Name = "DimBackground",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		parent = self.gui,
	}):render()

	local panelSize = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE

	self.mainPanel = UI.Components.Frame({
		Name = "MainPanel",
		Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, 28),
		parent = self.gui,
	}):render()

	-- Add sophisticated gradient background
	local panelGradient = Instance.new("UIGradient")
	panelGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(249, 250, 251)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(248, 250, 252)),
	})
	panelGradient.Parent = self.mainPanel

	-- Add subtle stroke
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = UI.Theme:get("accent")
	panelStroke.Thickness = 1
	panelStroke.Transparency = 0.9
	panelStroke.Parent = self.mainPanel

	-- Add premium shadow effect
	UI.Effects.addShadow(self.mainPanel, {
		transparency = 0.8,
		size = 25,
		offset = 12,
	})

	UI.Responsive.scale(self.mainPanel)

	self:createHeader()
	self:createTabBar()

	self.contentContainer = UI.Components.Frame({
		Name = "ContentContainer",
		Size = UDim2.new(1, -48, 1, -180),
		Position = UDim2.fromOffset(24, 156),
		BackgroundTransparency = 1,
		parent = self.mainPanel,
	}):render()

	self:createPages()
	self:selectTab("Home")
end

function Shop:createHeader()
	local header = UI.Components.Frame({
		Name = "Header",
		Size = UDim2.new(1, -48, 0, 90),
		Position = UDim2.fromOffset(24, 24),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, 20),
		parent = self.mainPanel,
	}):render()

	-- Add sophisticated gradient background
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(248, 250, 252)),
	})
	gradient.Parent = header

	-- Add subtle stroke
	local headerStroke = Instance.new("UIStroke")
	headerStroke.Color = UI.Theme:get("accent")
	headerStroke.Thickness = 1
	headerStroke.Transparency = 0.9
	headerStroke.Parent = header

	local logoContainer = UI.Components.Frame({
		Size = UDim2.fromOffset(70, 70),
		Position = UDim2.fromOffset(20, 10),
		BackgroundColor3 = UI.Theme:get("surfaceAlt"),
		cornerRadius = UDim.new(0, 16),
		parent = header,
	}):render()

	local logo = UI.Components.Image({
		Name = "Logo",
		Image = "rbxassetid://17398522865",
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		parent = logoContainer,
	}):render()

	local titleContainer = UI.Components.Frame({
		Size = UDim2.new(1, -300, 1, 0),
		Position = UDim2.fromOffset(100, 0),
		BackgroundTransparency = 1,
		parent = header,
	}):render()

	local title = UI.Components.TextLabel({
		Name = "Title",
		Text = "Sanrio Shop",
		Size = UDim2.new(1, 0, 0, 45),
		Position = UDim2.fromOffset(0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 28,
		TextColor3 = UI.Theme:get("text"),
		parent = titleContainer,
	}):render()

	local subtitle = UI.Components.TextLabel({
		Name = "Subtitle",
		Text = "Premium Items & Exclusive Upgrades",
		Size = UDim2.new(1, 0, 0, 25),
		Position = UDim2.fromOffset(0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = UI.Theme:get("textSecondary"),
		parent = titleContainer,
	}):render()

	local closeButton = UI.Components.Button({
		Name = "CloseButton",
		Text = "✕",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -60, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = UI.Theme:get("error"),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		cornerRadius = UDim.new(0.5, 0),
		parent = header,
		onClick = function()
			self:close()
		end,
	}):render()

	-- Add hover glow to close button
	local closeGlow = UI.Effects.addGlow(closeButton, UI.Theme:get("error"), 15, 0.7)
end

function Shop:createTabBar()
	local tabBarContainer = UI.Components.Frame({
		Name = "TabBarContainer",
		Size = UDim2.new(1, -48, 0, 60),
		Position = UDim2.fromOffset(24, 120),
		BackgroundColor3 = UI.Theme:get("surfaceAlt"),
		cornerRadius = UDim.new(0, 16),
		parent = self.mainPanel,
	}):render()

	-- Add gradient to tab bar
	local tabBarGradient = Instance.new("UIGradient")
	tabBarGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(248, 250, 252)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(241, 245, 249)),
	})
	tabBarGradient.Parent = tabBarContainer

	self.tabContainer = UI.Components.Frame({
		Name = "TabContainer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		parent = tabBarContainer,
	}):render()

	UI.Layout.stack(self.tabContainer, Enum.FillDirection.Horizontal, 8)

	local tabData = {
		{id = "Home", name = "🏠 Home", icon = "rbxassetid://17398522865", color = UI.Theme:get("kitty")},
		{id = "Cash", name = "💰 Cash", icon = "rbxassetid://10709728059", color = UI.Theme:get("cinna")},
		{id = "Gamepasses", name = "⭐ Passes", icon = "rbxassetid://10709727148", color = UI.Theme:get("kuromi")},
	}

	for _, data in ipairs(tabData) do
		self:createTab(data)
	end
end

function Shop:createTab(data)
	local tab = UI.Components.Button({
		Name = data.id .. "Tab",
		Text = "",
		Size = UDim2.new(0, 180, 1, -8),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, 14),
		LayoutOrder = #self.tabs + 1,
		parent = self.tabContainer,
		onClick = function()
			self:selectTab(data.id)
		end,
	}):render()

	-- Add subtle gradient to tab
	local tabGradient = Instance.new("UIGradient")
	tabGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(248, 250, 252)),
	})
	tabGradient.Parent = tab

	-- Add stroke for definition
	local tabStroke = Instance.new("UIStroke")
	tabStroke.Color = data.color
	tabStroke.Thickness = 1
	tabStroke.Transparency = 0.8
	tabStroke.Parent = tab

	local content = UI.Components.Frame({
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		parent = tab,
	}):render()

	UI.Layout.stack(content, Enum.FillDirection.Horizontal, 8, {left = 16, right = 16})

	local icon = UI.Components.Image({
		Name = "Icon",
		Image = data.icon,
		Size = UDim2.fromOffset(20, 20),
		LayoutOrder = 1,
		parent = content,
	}):render()

	local label = UI.Components.TextLabel({
		Name = "Label",
		Text = data.name,
		Size = UDim2.new(1, -28, 1, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		LayoutOrder = 2,
		parent = content,
	}):render()

	-- Add hover glow effect
	local hoverGlow = UI.Effects.addGlow(tab, data.color, 12, 0.6)
	hoverGlow.Visible = false

	tab.MouseEnter:Connect(function()
		hoverGlow.Visible = true
	end)

	tab.MouseLeave:Connect(function()
		hoverGlow.Visible = false
	end)

	self.tabs[data.id] = {
		button = tab,
		data = data,
		icon = icon,
		label = label,
		hoverGlow = hoverGlow,
	}
end

function Shop:createPages()
	self.pages.Home = self:createHomePage()
	self.pages.Cash = self:createCashPage()
	self.pages.Gamepasses = self:createGamepassesPage()
end

function Shop:createHomePage()
	local page = UI.Components.Frame({
		Name = "HomePage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		parent = self.contentContainer,
	}):render()

	local scrollFrame = UI.Components.ScrollingFrame({
		Size = UDim2.fromScale(1, 1),
		layout = {
			type = "List",
			Padding = UDim.new(0, 32),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		},
		padding = {
			top = UDim.new(0, 16),
			bottom = UDim.new(0, 16),
		},
		parent = page,
	}):render()

	-- Hero Section
	local hero = self:createHeroSection(scrollFrame)

	-- Featured Items Section
	local featuredTitle = UI.Components.TextLabel({
		Text = "Featured Items",
		Size = UDim2.new(1, 0, 0, 50),
		Font = Enum.Font.GothamBold,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		parent = scrollFrame,
	}):render()

	local featuredContainer = UI.Components.Frame({
		Size = UDim2.new(1, 0, 0, 350),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		parent = scrollFrame,
	}):render()

	local featuredScroll = UI.Components.ScrollingFrame({
		Size = UDim2.fromScale(1, 1),
		ScrollingDirection = Enum.ScrollingDirection.X,
		layout = {
			type = "List",
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 20),
		},
		parent = featuredContainer,
	}):render()

	-- Add featured items
	local featured = {}
	for _, product in ipairs(Core.DataManager.products.cash) do
		if product.featured then
			table.insert(featured, {type = "cash", data = product})
		end
	end

	for _, pass in ipairs(Core.DataManager.products.gamepasses) do
		table.insert(featured, {type = "gamepass", data = pass})
	end

	for _, item in ipairs(featured) do
		self:createProductCard(item.data, item.type, featuredScroll)
	end

	-- Quick Access Section
	local quickAccessTitle = UI.Components.TextLabel({
		Text = "Quick Access",
		Size = UDim2.new(1, 0, 0, 50),
		Font = Enum.Font.GothamBold,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 4,
		parent = scrollFrame,
	}):render()

	local quickAccessContainer = UI.Components.Frame({
		Size = UDim2.new(1, 0, 0, 200),
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		parent = scrollFrame,
	}):render()

	local quickAccessScroll = UI.Components.ScrollingFrame({
		Size = UDim2.fromScale(1, 1),
		ScrollingDirection = Enum.ScrollingDirection.X,
		layout = {
			type = "List",
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 16),
		},
		parent = quickAccessContainer,
	}):render()

	-- Quick access buttons
	local quickButtons = {
		{ text = "Cash Shop", tab = "Cash", color = UI.Theme:get("cinna") },
		{ text = "Gamepasses", tab = "Gamepasses", color = UI.Theme:get("kuromi") },
	}

	for _, buttonData in ipairs(quickButtons) do
		local quickButton = UI.Components.Button({
			Text = buttonData.text,
			Size = UDim2.fromOffset(200, 60),
			BackgroundColor3 = buttonData.color,
			TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			cornerRadius = UDim.new(0, 12),
			parent = quickAccessScroll,
			onClick = function()
				self:selectTab(buttonData.tab)
			end,
		}):render()
	end

	return page
end

function Shop:createCashPage()
	local page = UI.Components.Frame({
		Name = "CashPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		parent = self.contentContainer,
	}):render()

	local scrollFrame = UI.Components.ScrollingFrame({
		Size = UDim2.fromScale(1, 1),
		layout = {
			type = "Grid",
			CellSize = Core.Utils.isMobile() and
				UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE_MOBILE.X, Core.CONSTANTS.CARD_SIZE_MOBILE.Y) or
				UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y),
			CellPadding = UDim2.fromOffset(20, 20),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		},
		padding = {
			top = UDim.new(0, 12),
			bottom = UDim.new(0, 12),
			left = UDim.new(0, 12),
			right = UDim.new(0, 12),
		},
		parent = page,
	}):render()

	for _, product in ipairs(Core.DataManager.products.cash) do
		self:createProductCard(product, "cash", scrollFrame)
	end

	return page
end

function Shop:createGamepassesPage()
	local page = UI.Components.Frame({
		Name = "GamepassesPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		parent = self.contentContainer,
	}):render()

	local scrollFrame = UI.Components.ScrollingFrame({
		Size = UDim2.fromScale(1, 1),
		layout = {
			type = "Grid",
			CellSize = Core.Utils.isMobile() and
				UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE_MOBILE.X, Core.CONSTANTS.CARD_SIZE_MOBILE.Y) or
				UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y),
			CellPadding = UDim2.fromOffset(20, 20),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		},
		padding = {
			top = UDim.new(0, 12),
			bottom = UDim.new(0, 12),
			left = UDim.new(0, 12),
			right = UDim.new(0, 12),
		},
		parent = page,
	}):render()

	for _, pass in ipairs(Core.DataManager.products.gamepasses) do
		self:createProductCard(pass, "gamepass", scrollFrame)
	end

	return page
end

function Shop:createHeroSection(parent)
	local hero = UI.Components.Frame({
		Name = "HeroSection",
		Size = UDim2.new(1, 0, 0, 220),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, 20),
		LayoutOrder = 1,
		parent = parent,
	}):render()

	-- Add beautiful gradient background
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(147, 51, 234)), -- Purple
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(59, 130, 246)), -- Blue
		ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 185, 129)), -- Green
	})
	gradient.Parent = hero

	-- Add premium stroke
	local heroStroke = Instance.new("UIStroke")
	heroStroke.Color = Color3.fromRGB(255, 255, 255)
	heroStroke.Thickness = 2
	heroStroke.Transparency = 0.8
	heroStroke.Parent = hero

	-- Add glow effect
	UI.Effects.addGlow(hero, UI.Theme:get("accent"), 20, 0.6)

	local content = UI.Components.Frame({
		Size = UDim2.new(1, -40, 1, -40),
		Position = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		parent = hero,
	}):render()

	UI.Layout.stack(content, Enum.FillDirection.Horizontal, 32, {
		left = 0,
		right = 0,
		top = 0,
		bottom = 0,
	})

	local textContainer = UI.Components.Frame({
		Size = UDim2.new(0.65, 0, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		parent = content,
	}):render()

	local heroTitle = UI.Components.TextLabel({
		Text = "✨ Welcome to Sanrio Shop!",
		Size = UDim2.new(1, 0, 0, 50),
		Font = Enum.Font.GothamBold,
		TextSize = 36,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = textContainer,
	}):render()

	local heroDesc = UI.Components.TextLabel({
		Text = "Discover exclusive items, powerful upgrades, and premium boosts to supercharge your tycoon experience!",
		Size = UDim2.new(1, 0, 0, 70),
		Position = UDim2.fromOffset(0, 55),
		Font = Enum.Font.Gotham,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		parent = textContainer,
	}):render()

	local ctaButton = UI.Components.Button({
		Text = "🛒 Browse Collection",
		Size = UDim2.fromOffset(200, 52),
		Position = UDim2.fromOffset(0, 135),
		BackgroundColor3 = Color3.new(1, 1, 1),
		TextColor3 = UI.Theme:get("accent"),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		cornerRadius = UDim.new(0, 14),
		parent = textContainer,
		onClick = function()
			self:selectTab("Cash")
		end,
	}):render()

	-- Add shimmer effect to CTA button
	UI.Effects.addShimmer(ctaButton, 2.5)

	return hero
end

function Shop:createProductCard(product, productType, parent)
	local isGamepass = productType == "gamepass"
	local cardColor = isGamepass and UI.Theme:get("kuromi") or UI.Theme:get("cinna")

	-- Create main card with gradient background
	local card = UI.Components.Frame({
		Name = product.name .. "Card",
		Size = UDim2.fromOffset(
			Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.X or Core.CONSTANTS.CARD_SIZE.X,
			Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.Y or Core.CONSTANTS.CARD_SIZE.Y
		),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, 20),
		parent = parent,
	}):render()

	-- Add sophisticated gradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(248, 250, 252)),
	})
	gradient.Parent = card

	-- Add subtle stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = cardColor
	stroke.Thickness = 1
	stroke.Transparency = 0.8
	stroke.Parent = card

	-- Add shadow effect for depth
	UI.Effects.addShadow(card, {
		transparency = 0.85,
		size = 15,
		offset = 8,
	})

	-- Add hover effects
	self:addCardHoverEffect(card)

	local content = UI.Components.Frame({
		Size = UDim2.new(1, -32, 1, -32),
		Position = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		parent = card,
	}):render()

	-- Image container with modern design
	local imageContainer = UI.Components.Frame({
		Size = UDim2.new(1, 0, 0, 130),
		BackgroundColor3 = Color3.fromRGB(248, 250, 252),
		cornerRadius = UDim.new(0, 16),
		parent = content,
	}):render()

	-- Add subtle border to image container
	local imageStroke = Instance.new("UIStroke")
	imageStroke.Color = UI.Theme:get("stroke")
	imageStroke.Thickness = 1
	imageStroke.Transparency = 0.9
	imageStroke.Parent = imageContainer

	local productImage = UI.Components.Image({
		Image = product.icon or "rbxassetid://0",
		Size = UDim2.fromScale(0.85, 0.85),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ScaleType = Enum.ScaleType.Fit,
		parent = imageContainer,
	}):render()

	local infoContainer = UI.Components.Frame({
		Size = UDim2.new(1, 0, 1, -150),
		Position = UDim2.fromOffset(0, 150),
		BackgroundTransparency = 1,
		parent = content,
	}):render()

	-- Adjust info container if this is a gamepass with toggle
	if isGamepass and product.hasToggle then
		infoContainer.Size = UDim2.new(1, 0, 1, -190)
	end

	-- Product title with better typography
	local title = UI.Components.TextLabel({
		Text = product.name,
		Size = UDim2.new(1, 0, 0, 32),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = UI.Theme:get("text"),
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = infoContainer,
	}):render()

	-- Description with better spacing
	local description = UI.Components.TextLabel({
		Text = product.description,
		Size = UDim2.new(1, 0, 0, 45),
		Position = UDim2.fromOffset(0, 36),
		Font = Enum.Font.Gotham,
		TextSize = 15,
		TextColor3 = UI.Theme:get("textSecondary"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		parent = infoContainer,
	}):render()

	-- Price with modern styling
	local priceText = isGamepass and
		("R$" .. tostring(product.price or 0)) or
		("R$" .. tostring(product.price or 0) .. " for " .. Core.Utils.formatNumber(product.amount) .. " Cash")

	local priceLabel = UI.Components.TextLabel({
		Text = priceText,
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 85),
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = cardColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = infoContainer,
	}):render()

	local isOwned = isGamepass and Core.DataManager.checkOwnership(product.id)

	-- Modern button design
	local purchaseButton = UI.Components.Button({
		Text = isOwned and "✓ Owned" or "Purchase",
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.new(0, 0, 1, -44),
		BackgroundColor3 = isOwned and UI.Theme:get("success") or cardColor,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		cornerRadius = UDim.new(0, 12),
		parent = infoContainer,
		onClick = function()
			if not isOwned then
				self:promptPurchase(product, productType)
			elseif product.hasToggle then
				self:toggleGamepass(product)
			end
		end,
	}):render()

	-- Add button gradient for owned state
	if isOwned then
		local buttonGradient = Instance.new("UIGradient")
		buttonGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 197, 94)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 163, 74)),
		})
		buttonGradient.Parent = purchaseButton
	end

	if isOwned and product.hasToggle then
		self:addToggleSwitch(product, infoContainer)
	end

	product.cardInstance = card
	product.purchaseButton = purchaseButton

	return card
end

function Shop:addCardHoverEffect(card)
	local originalPosition = card.Position

	card.MouseEnter:Connect(function()
		Core.Animation.tween(card, {
			Position = UDim2.new(
				originalPosition.X.Scale,
				originalPosition.X.Offset,
				originalPosition.Y.Scale,
				originalPosition.Y.Offset - 8
			)
		}, Core.CONSTANTS.ANIM_FAST)
	end)

	card.MouseLeave:Connect(function()
		Core.Animation.tween(card, {
			Position = originalPosition
		}, Core.CONSTANTS.ANIM_FAST)
	end)
end

function Shop:addToggleSwitch(product, parent)
	-- Create a container for the toggle and label
	local toggleSection = UI.Components.Frame({
		Name = "ToggleSection",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 0, 120), -- Position below the price label
		BackgroundTransparency = 1,
		parent = parent,
	}):render()

	local toggleLabel = UI.Components.TextLabel({
		Name = "ToggleLabel",
		Text = "Auto Collect:",
		Size = UDim2.new(0, 100, 1, 0),
		Position = UDim2.fromOffset(0, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextColor3 = UI.Theme:get("textSecondary"),
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = toggleSection,
	}):render()

	local toggleContainer = UI.Components.Frame({
		Name = "ToggleContainer",
		Size = UDim2.fromOffset(60, 30),
		Position = UDim2.new(0, 110, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = UI.Theme:get("stroke"),
		cornerRadius = UDim.new(0.5, 0),
		parent = toggleSection,
	}):render()

	local toggleButton = UI.Components.Frame({
		Name = "ToggleButton",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0.5, 0),
		parent = toggleContainer,
	}):render()

	local toggleState = false
	if Remotes then
		local getStateRemote = Remotes:FindFirstChild("GetAutoCollectState")
		if getStateRemote and getStateRemote:IsA("RemoteFunction") then
			local success, state = Core.protectedCall(function()
				return getStateRemote:InvokeServer()
			end)
			if success and type(state) == "boolean" then
				toggleState = state
			end
		end
	end

	local function updateToggleVisual()
		if toggleState then
			toggleContainer.BackgroundColor3 = UI.Theme:get("success")
			Core.Animation.tween(toggleButton, {
				Position = UDim2.fromOffset(32, 2)
			}, Core.CONSTANTS.ANIM_FAST)
		else
			toggleContainer.BackgroundColor3 = UI.Theme:get("stroke")
			Core.Animation.tween(toggleButton, {
				Position = UDim2.fromOffset(2, 2)
			}, Core.CONSTANTS.ANIM_FAST)
		end
	end

	updateToggleVisual()

	local toggleClickArea = Instance.new("TextButton")
	toggleClickArea.Text = ""
	toggleClickArea.BackgroundTransparency = 1
	toggleClickArea.Size = UDim2.fromScale(1, 1)
	toggleClickArea.Parent = toggleContainer

	toggleClickArea.MouseButton1Click:Connect(function()
		toggleState = not toggleState
		updateToggleVisual()

		if Remotes then
			local toggleRemote = Remotes:FindFirstChild("AutoCollectToggle")
			if toggleRemote and toggleRemote:IsA("RemoteEvent") then
				Core.protectedCall(function()
					toggleRemote:FireServer(toggleState)
				end)
			end
		end

		Core.SoundSystem.play("click")
	end)
end

function Shop:addPulseAnimation(instance)
	local pulseRunning = true

	task.spawn(function()
		while pulseRunning and instance.Parent do
			Core.Animation.tween(instance, {
				Size = UDim2.fromOffset(188, 64)
			}, 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(1.5)

			if not pulseRunning or not instance.Parent then break end

			Core.Animation.tween(instance, {
				Size = UDim2.fromOffset(180, 60)
			}, 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(1.5)
		end
	end)

	instance.AncestryChanged:Connect(function()
		if not instance.Parent then
			pulseRunning = false
		end
	end)
end

function Shop:selectTab(tabId)
	-- Allow re-selection for proper initialization
	if self.currentTab == tabId and self.tabs[tabId] then
		-- Still update visuals in case they weren't set properly during initialization
		local isActive = true
		local data = self.tabs[tabId].data
		local tab = self.tabs[tabId]

		Core.Animation.tween(tab.button, {
			BackgroundColor3 = Core.Utils.blend(data.color, Color3.new(1, 1, 1), 0.9)
		}, Core.CONSTANTS.ANIM_FAST)

		local stroke = tab.button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = data.color
			stroke.Transparency = 0.3
		end

		tab.icon.ImageColor3 = Color3.new(1, 1, 1)
		tab.label.TextColor3 = Color3.new(1, 1, 1)
		tab.hoverGlow.Visible = true

		if self.pages[tabId] then
			self.pages[tabId].Visible = true
		end
		return
	end

	-- Update all tabs
	for id, tab in pairs(self.tabs) do
		local isActive = id == tabId
		local data = tab.data

		Core.Animation.tween(tab.button, {
			BackgroundColor3 = isActive and
				Core.Utils.blend(data.color, Color3.new(1, 1, 1), 0.9) or
				UI.Theme:get("surface")
		}, Core.CONSTANTS.ANIM_FAST)

		local stroke = tab.button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = isActive and data.color or UI.Theme:get("stroke")
			stroke.Transparency = isActive and 0.3 or 0.8
		end

		tab.icon.ImageColor3 = isActive and Color3.new(1, 1, 1) or UI.Theme:get("text")
		tab.label.TextColor3 = isActive and Color3.new(1, 1, 1) or UI.Theme:get("text")
		tab.hoverGlow.Visible = isActive
	end

	-- Update all pages
	for id, page in pairs(self.pages) do
		page.Visible = id == tabId

		if id == tabId and page.Visible then
			page.Position = UDim2.fromOffset(0, 20)
			Core.Animation.tween(page, {
				Position = UDim2.new()
			}, Core.CONSTANTS.ANIM_BOUNCE, Enum.EasingStyle.Back)
		end
	end

	self.currentTab = tabId
	Core.SoundSystem.play("click")
	Core.Events:emit("tabChanged", tabId)
end

function Shop:promptPurchase(product, productType)
	if productType == "gamepass" then
		if Core.DataManager.checkOwnership(product.id) then
			self:refreshProduct(product, productType)
			return
		end

		-- Check if product info is available
		local productInfo = Core.DataManager.getProductInfo(product.id)
		if not productInfo then
			self:showNotification("Error", "Product information not available", "error")
			return
		end

		product.purchaseButton.Text = "Processing..."
		product.purchaseButton.Active = false

		Core.State.purchasePending[product.id] = {
			product = product,
			timestamp = tick(),
			type = productType,
		}

		local success, errorMessage = Core.protectedCall(function()
			MarketplaceService:PromptGamePassPurchase(Player, product.id)
		end)

		if not success then
			product.purchaseButton.Text = "Purchase"
			product.purchaseButton.Active = true
			Core.State.purchasePending[product.id] = nil
			self:showNotification("Purchase Failed", errorMessage or "Something went wrong", "error")
		end

		task.delay(Core.CONSTANTS.PURCHASE_TIMEOUT, function()
			if Core.State.purchasePending[product.id] then
				product.purchaseButton.Text = "Purchase"
				product.purchaseButton.Active = true
				Core.State.purchasePending[product.id] = nil
				self:showNotification("Purchase Timeout", "Purchase took too long. Please try again.", "warning")
			end
		end)
	else
		-- Check if product info is available
		local productInfo = Core.DataManager.getProductInfo(product.id)
		if not productInfo then
			self:showNotification("Error", "Product information not available", "error")
			return
		end

		Core.State.purchasePending[product.id] = {
			product = product,
			timestamp = tick(),
			type = productType,
		}

		local success, errorMessage = Core.protectedCall(function()
			MarketplaceService:PromptProductPurchase(Player, product.id)
		end)

		if not success then
			Core.State.purchasePending[product.id] = nil
			self:showNotification("Purchase Failed", errorMessage or "Something went wrong", "error")
		end
	end
end

function Shop:refreshProduct(product, productType)
	if productType == "gamepass" then
		local isOwned = Core.DataManager.checkOwnership(product.id)

		if product.purchaseButton then
			product.purchaseButton.Text = isOwned and "Owned" or "Purchase"
			product.purchaseButton.BackgroundColor3 = isOwned and
				UI.Theme:get("success") or UI.Theme:get("kuromi")
			product.purchaseButton.Active = not isOwned
		end

		if product.cardInstance then
			local stroke = product.cardInstance:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = isOwned and UI.Theme:get("success") or UI.Theme:get("kuromi")
			end
		end
	end
end

function Shop:refreshAllProducts()
	Core.ownershipCache:clear()

	for _, pass in ipairs(Core.DataManager.products.gamepasses) do
		self:refreshProduct(pass, "gamepass")
	end

	Core.Events:emit("productsRefreshed")
end

function Shop:showNotification(title, message, notificationType)
	local notification = UI.Components.Frame({
		Name = "Notification",
		Size = UDim2.fromOffset(320, 80),
		Position = UDim2.new(0.5, 0, 0, -100),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = notificationType == "error" and UI.Theme:get("error") or
						  notificationType == "warning" and UI.Theme:get("warning") or
						  UI.Theme:get("success"),
		cornerRadius = UDim.new(0, 12),
		stroke = {
			color = Color3.new(1, 1, 1),
			thickness = 2,
		},
		parent = self.gui,
	}):render()

	local titleLabel = UI.Components.TextLabel({
		Text = title,
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.fromOffset(10, 10),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = notification,
	}):render()

	local messageLabel = UI.Components.TextLabel({
		Text = message,
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.fromOffset(10, 35),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		parent = notification,
	}):render()

	-- Animate in
	notification.Position = UDim2.new(0.5, 0, 0, -100)
	Core.Animation.tween(notification, {
		Position = UDim2.new(0.5, 0, 0, 20)
	}, Core.CONSTANTS.ANIM_MEDIUM, Enum.EasingStyle.Back)

	Core.SoundSystem.play(notificationType == "error" and "error" or
						 notificationType == "warning" and "notification" or "success")

	-- Auto remove after delay
	task.delay(4, function()
		if notification.Parent then
			Core.Animation.tween(notification, {
				Position = UDim2.new(0.5, 0, 0, -100)
			}, Core.CONSTANTS.ANIM_MEDIUM)

			task.wait(Core.CONSTANTS.ANIM_MEDIUM)
			if notification.Parent then
				notification:Destroy()
			end
		end
	end)

	table.insert(self.notifications, notification)
end

function Shop:open()
	if Core.State.isOpen or Core.State.isAnimating then return end

	Core.State.isAnimating = true
	Core.State.isOpen = true

	Core.DataManager.refreshPrices()
	self:refreshAllProducts()

	self.gui.Enabled = true

	Core.Animation.tween(self.blur, {
		Size = 24
	}, Core.CONSTANTS.ANIM_MEDIUM)

	self.mainPanel.Position = UDim2.fromScale(0.5, 0.55)
	self.mainPanel.Size = UDim2.fromOffset(
		self.mainPanel.Size.X.Offset * 0.9,
		self.mainPanel.Size.Y.Offset * 0.9
	)

	Core.Animation.tween(self.mainPanel, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(
			Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE.X or Core.CONSTANTS.PANEL_SIZE.X,
			Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE.Y or Core.CONSTANTS.PANEL_SIZE.Y
		)
	}, Core.CONSTANTS.ANIM_BOUNCE, Enum.EasingStyle.Back)

	Core.SoundSystem.play("open")

	task.wait(Core.CONSTANTS.ANIM_BOUNCE)
	Core.State.isAnimating = false

	Core.Events:emit("shopOpened")
end

function Shop:close()
	if not Core.State.isOpen or Core.State.isAnimating then return end

	Core.State.isAnimating = true
	Core.State.isOpen = false

	Core.Animation.tween(self.blur, {
		Size = 0
	}, Core.CONSTANTS.ANIM_FAST)

	Core.Animation.tween(self.mainPanel, {
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(
			self.mainPanel.Size.X.Offset * 0.9,
			self.mainPanel.Size.Y.Offset * 0.9
		)
	}, Core.CONSTANTS.ANIM_FAST)

	Core.SoundSystem.play("close")

	task.wait(Core.CONSTANTS.ANIM_FAST)
	self.gui.Enabled = false
	Core.State.isAnimating = false

	Core.Events:emit("shopClosed")
end

function Shop:toggle()
	if Core.State.isOpen then
		self:close()
	else
		self:open()
	end
end

function Shop:toggleGamepass(product)
	-- This would be implemented based on your specific gamepass functionality
	Core.SoundSystem.play("click")
end

function Shop:setupRemoteHandlers()
	if not Remotes then return end

	local purchaseConfirm = Remotes:FindFirstChild("GamepassPurchased")
	if purchaseConfirm and purchaseConfirm:IsA("RemoteEvent") then
		purchaseConfirm.OnClientEvent:Connect(function(passId)
			Core.ownershipCache:clear()
			self:refreshAllProducts()
			Core.SoundSystem.play("success")
		end)
	end

	local productGrant = Remotes:FindFirstChild("ProductGranted") or Remotes:FindFirstChild("GrantProductCurrency")
	if productGrant and productGrant:IsA("RemoteEvent") then
		productGrant.OnClientEvent:Connect(function(productId, amount)
			Core.SoundSystem.play("success")
		end)
	end
end

function Shop:setupInputHandlers()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.M then
			self:toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and Core.State.isOpen then
			self:close()
		end
	end)

	if UserInputService.GamepadEnabled then
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end

			if input.KeyCode == Enum.KeyCode.ButtonX then
				self:toggle()
			end
		end)
	end
end

function Shop:setupPurchaseHandlers()
	-- Gamepass purchase handler
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if player ~= Player then return end

		local pending = Core.State.purchasePending[passId]
		if not pending then return end

		Core.State.purchasePending[passId] = nil

		if purchased then
			Core.ownershipCache:clear()

			if pending.product.purchaseButton then
				pending.product.purchaseButton.Text = "Owned"
				pending.product.purchaseButton.BackgroundColor3 = UI.Theme:get("success")
				pending.product.purchaseButton.Active = false
			end

			self:showNotification("Purchase Successful!", "You now own " .. pending.product.name, "success")
			Core.SoundSystem.play("success")

			task.wait(0.5)
			self:refreshAllProducts()
		else
			if pending.product.purchaseButton then
				pending.product.purchaseButton.Text = "Purchase"
				pending.product.purchaseButton.Active = true
			end

			self:showNotification("Purchase Cancelled", "Purchase was cancelled", "warning")
		end
	end)

	-- Product purchase handler
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, purchased)
		if player ~= Player then return end

		local pending = Core.State.purchasePending[productId]
		if not pending then return end

		Core.State.purchasePending[productId] = nil

		if purchased then
			self:showNotification("Purchase Successful!", "You received " .. Core.Utils.formatNumber(pending.product.amount) .. " cash!", "success")
			Core.SoundSystem.play("success")

			if Remotes then
				local grantEvent = Remotes:FindFirstChild("GrantProductCurrency")
				if grantEvent and grantEvent:IsA("RemoteEvent") then
					Core.protectedCall(function()
						grantEvent:FireServer(productId)
					end)
				end
			end
		else
			self:showNotification("Purchase Cancelled", "Purchase was cancelled", "warning")
		end
	end)
end

-- Initialize shop
local shop = Shop.new()

-- Handle character respawn
Player.CharacterAdded:Connect(function()
	task.wait(1)
	if not shop.toggleButton or not shop.toggleButton.Parent then
		shop:createToggleButton()
	end
end)

-- Auto-refresh ownership periodically
task.spawn(function()
	while true do
		task.wait(30)
		if Core.State.isOpen then
			shop:refreshAllProducts()
		end
	end
end)

print("[SanrioShop] System initialized successfully!")

return shop