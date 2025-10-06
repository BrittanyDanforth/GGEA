--[[
    SANRIO SHOP - MAIN SCRIPT
    Clean, Professional, Modern Design
    
    Place in: StarterPlayer > StarterPlayerScripts
    
    Fixed Issues:
    ✓ Home page displays correctly on open
    ✓ Tab switching works immediately  
    ✓ Purchase error handling
    ✓ Toggle properly positioned
    ✓ Clean, minimal design
--]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Load modules
local Core = require(script.SanrioShop_Core)
local UI = require(script.SanrioShop_UI)

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)

-- ========================================
-- NOTIFICATION SYSTEM
-- ========================================
local Notifications = {}

function Notifications.show(message, type)
	type = type or "info"
	
	local colors = {
		success = UI.Theme:get("success"),
		error = UI.Theme:get("error"),
		warning = UI.Theme:get("warning"),
		info = UI.Theme:get("accent"),
	}
	
	local icons = {
		success = "✓",
		error = "✕",
		warning = "⚠",
		info = "ⓘ",
	}

	local notifGui = PlayerGui:FindFirstChild("SanrioNotifications") or Instance.new("ScreenGui")
	notifGui.Name = "SanrioNotifications"
	notifGui.ResetOnSpawn = false
	notifGui.DisplayOrder = Core.CONSTANTS.Z_NOTIFICATION
	notifGui.Parent = PlayerGui

	local notif = UI.Components.Frame({
		Size = UDim2.fromOffset(380, 70),
		Position = UDim2.new(0.5, 0, 0, -100),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, 10),
		stroke = {
			color = colors[type],
			thickness = 2,
		},
		parent = notifGui,
	}):render()

	-- Icon
	local iconLabel = UI.Components.TextLabel({
		Text = icons[type],
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(15, 15),
		BackgroundColor3 = colors[type],
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		cornerRadius = UDim.new(1, 0),
		parent = notif,
	}):render()

	-- Message
	local messageLabel = UI.Components.TextLabel({
		Text = message,
		Size = UDim2.new(1, -75, 1, -20),
		Position = UDim2.fromOffset(65, 10),
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		parent = notif,
	}):render()

	Core.Animation.tween(notif, {
		Position = UDim2.new(0.5, 0, 0, 20)
	}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	Core.SoundSystem.play(type == "error" and "error" or (type == "success" and "success" or "notification"))

	task.delay(3.5, function()
		Core.Animation.tween(notif, {
			Position = UDim2.new(0.5, 0, 0, -100)
		}, 0.3)
		task.wait(0.3)
		notif:Destroy()
	end)
end

-- ========================================
-- MAIN SHOP CLASS
-- ========================================
local Shop = {}
Shop.__index = Shop

function Shop.new()
	local self = setmetatable({}, Shop)
	
	self.gui = nil
	self.mainFrame = nil
	self.currentTab = nil
	self.tabs = {}
	self.pages = {}
	self.toggleButton = nil
	
	self:initialize()
	
	return self
end

function Shop:initialize()
	Core.SoundSystem.initialize()
	Core.DataManager.refreshPrices()
	
	self:createToggleButton()
	self:createShopUI()
	self:setupRemotes()
	self:setupInputs()
	
	Core.State.initialized = true
	print("[SanrioShop] ✓ Initialized")
end

-- ========================================
-- TOGGLE BUTTON
-- ========================================
function Shop:createToggleButton()
	local screen = Instance.new("ScreenGui")
	screen.Name = "SanrioShopToggle"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 999
	screen.Parent = PlayerGui

	self.toggleButton = UI.Components.Button({
		Name = "ShopToggle",
		Text = "",
		Size = UDim2.fromOffset(170, 56),
		Position = UDim2.new(1, -20, 1, -20),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, 28),
		stroke = {
			color = UI.Theme:get("accent"),
			thickness = 2,
		},
		parent = screen,
	}):render()

	-- Icon
	local icon = UI.Components.Image({
		Image = "rbxassetid://17398522865",
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(14, 12),
		parent = self.toggleButton,
	}):render()

	-- Label
	local label = UI.Components.TextLabel({
		Text = "Shop",
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromOffset(52, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		parent = self.toggleButton,
	}):render()

	self.toggleButton.MouseButton1Click:Connect(function()
		self:toggle()
	end)

	self:addPulse(self.toggleButton)
end

-- ========================================
-- MAIN SHOP UI
-- ========================================
function Shop:createShopUI()
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "SanrioShopMain"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 1000
	self.gui.Enabled = false
	self.gui.Parent = PlayerGui

	-- Dim background
	local dim = UI.Components.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		parent = self.gui,
	}):render()

	-- Click to close
	local closeButton = Instance.new("TextButton")
	closeButton.Text = ""
	closeButton.BackgroundTransparency = 1
	closeButton.Size = UDim2.fromScale(1, 1)
	closeButton.Parent = dim
	closeButton.MouseButton1Click:Connect(function()
		self:close()
	end)

	-- Main panel
	local panelSize = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE

	self.mainFrame = UI.Components.Frame({
		Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UI.Theme:get("background"),
		cornerRadius = UDim.new(0, 16),
		stroke = {
			color = UI.Theme:get("stroke"),
			thickness = 1,
		},
		parent = self.gui,
	}):render()

	UI.Responsive.scale(self.mainFrame)

	self:createHeader()
	self:createTabBar()
	self:createContent()
	
	-- Select home tab after everything is created
	self:selectTab("Home", true)
end

-- ========================================
-- HEADER
-- ========================================
function Shop:createHeader()
	local header = UI.Components.Frame({
		Size = UDim2.new(1, -40, 0, 70),
		Position = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		parent = self.mainFrame,
	}):render()

	-- Title
	local title = UI.Components.TextLabel({
		Text = "Sanrio Shop",
		Size = UDim2.new(1, -80, 1, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = header,
	}):render()

	-- Close button
	local close = UI.Components.Button({
		Text = "✕",
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.new(1, -50, 0, 10),
		BackgroundColor3 = UI.Theme:get("error"),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		cornerRadius = UDim.new(1, 0),
		parent = header,
	}):render()

	close.MouseButton1Click:Connect(function()
		self:close()
	end)
end

-- ========================================
-- TAB BAR
-- ========================================
function Shop:createTabBar()
	local tabBar = UI.Components.Frame({
		Size = UDim2.new(1, -40, 0, 50),
		Position = UDim2.fromOffset(20, 100),
		BackgroundTransparency = 1,
		parent = self.mainFrame,
	}):render()

	UI.Layout.stack(tabBar, Enum.FillDirection.Horizontal, 12)

	local tabs = {
		{id = "Home", name = "Home", icon = "🏠"},
		{id = "Cash", name = "Cash", icon = "💵"},
		{id = "Gamepasses", name = "Passes", icon = "⭐"},
	}

	for _, data in ipairs(tabs) do
		self:createTab(data, tabBar)
	end
end

function Shop:createTab(data, parent)
	local tab = UI.Components.Button({
		Text = "",
		Size = UDim2.fromOffset(140, 50),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, 10),
		stroke = {
			color = UI.Theme:get("stroke"),
			thickness = 2,
		},
		parent = parent,
	}):render()

	-- Icon
	local icon = UI.Components.TextLabel({
		Text = data.icon,
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.fromOffset(16, 13),
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		parent = tab,
	}):render()

	-- Label
	local label = UI.Components.TextLabel({
		Text = data.name,
		Size = UDim2.new(1, -50, 1, 0),
		Position = UDim2.fromOffset(46, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = tab,
	}):render()

	tab.MouseButton1Click:Connect(function()
		self:selectTab(data.id)
	end)

	self.tabs[data.id] = {
		button = tab,
		icon = icon,
		label = label,
		data = data,
	}
end

-- ========================================
-- CONTENT AREA
-- ========================================
function Shop:createContent()
	local content = UI.Components.Frame({
		Size = UDim2.new(1, -40, 1, -180),
		Position = UDim2.fromOffset(20, 160),
		BackgroundTransparency = 1,
		parent = self.mainFrame,
	}):render()

	self.pages.Home = self:createHomePage(content)
	self.pages.Cash = self:createCashPage(content)
	self.pages.Gamepasses = self:createGamepassPage(content)
end

-- ========================================
-- HOME PAGE
-- ========================================
function Shop:createHomePage(parent)
	local page = UI.Components.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		parent = parent,
	}):render()

	local scroll = UI.Components.ScrollingFrame({
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(0, 0, 0, 800),
		parent = page,
	}):render()

	UI.Layout.stack(scroll, Enum.FillDirection.Vertical, 20, {top = 10, bottom = 10})

	-- Hero banner
	self:createHero(scroll)

	-- Featured title
	local featTitle = UI.Components.TextLabel({
		Text = "Featured Items",
		Size = UDim2.new(1, 0, 0, 32),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		parent = scroll,
	}):render()

	-- Featured products
	local featContainer = UI.Components.Frame({
		Size = UDim2.new(1, 0, 0, 280),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		parent = scroll,
	}):render()

	local featScroll = UI.Components.ScrollingFrame({
		Size = UDim2.fromScale(1, 1),
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(0, 1200, 0, 0),
		parent = featContainer,
	}):render()

	UI.Layout.stack(featScroll, Enum.FillDirection.Horizontal, 16)

	-- Add featured items
	for _, product in ipairs(Core.DataManager.products.cash) do
		if product.featured then
			self:createProductCard(product, "cash", featScroll)
		end
	end

	return page
end

function Shop:createHero(parent)
	local hero = UI.Components.Frame({
		Size = UDim2.new(1, 0, 0, 160),
		BackgroundColor3 = UI.Theme:get("accent"),
		cornerRadius = UDim.new(0, 12),
		LayoutOrder = 1,
		parent = parent,
	}):render()

	-- Gradient overlay
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 130)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 160)),
	})
	gradient.Rotation = 45
	gradient.Parent = hero

	-- Content
	local heroTitle = UI.Components.TextLabel({
		Text = "Welcome to Sanrio Shop",
		Size = UDim2.new(1, -40, 0, 36),
		Position = UDim2.fromOffset(20, 30),
		Font = Enum.Font.GothamBold,
		TextSize = 30,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = hero,
	}):render()

	local heroDesc = UI.Components.TextLabel({
		Text = "Get exclusive items and boosts for your tycoon",
		Size = UDim2.new(1, -40, 0, 24),
		Position = UDim2.fromOffset(20, 72),
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = hero,
	}):render()

	local heroBtn = UI.Components.Button({
		Text = "Browse Shop →",
		Size = UDim2.fromOffset(160, 40),
		Position = UDim2.fromOffset(20, 106),
		BackgroundColor3 = Color3.new(1, 1, 1),
		TextColor3 = UI.Theme:get("accent"),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		cornerRadius = UDim.new(0, 8),
		parent = hero,
	}):render()

	heroBtn.MouseButton1Click:Connect(function()
		self:selectTab("Cash")
	end)
end

-- ========================================
-- CASH PAGE
-- ========================================
function Shop:createCashPage(parent)
	local page = UI.Components.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		parent = parent,
	}):render()

	local scroll = UI.Components.ScrollingFrame({
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(0, 0, 0, 700),
		parent = page,
	}):render()

	local grid = UI.Layout.grid(scroll, 
		UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y),
		UDim2.fromOffset(16, 16)
	)

	for _, product in ipairs(Core.DataManager.products.cash) do
		self:createProductCard(product, "cash", scroll)
	end

	return page
end

-- ========================================
-- GAMEPASS PAGE
-- ========================================
function Shop:createGamepassPage(parent)
	local page = UI.Components.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		parent = parent,
	}):render()

	local scroll = UI.Components.ScrollingFrame({
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(0, 0, 0, 700),
		parent = page,
	}):render()

	local grid = UI.Layout.grid(scroll,
		UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y),
		UDim2.fromOffset(16, 16)
	)

	for _, pass in ipairs(Core.DataManager.products.gamepasses) do
		self:createProductCard(pass, "gamepass", scroll)
	end

	return page
end

-- ========================================
-- PRODUCT CARD
-- ========================================
function Shop:createProductCard(product, productType, parent)
	local isGamepass = productType == "gamepass"

	local card = UI.Components.Frame({
		Size = UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(0, 12),
		stroke = {
			color = UI.Theme:get("stroke"),
			thickness = 1,
		},
		parent = parent,
	}):render()

	-- Image container
	local imgContainer = UI.Components.Frame({
		Size = UDim2.new(1, -24, 0, 140),
		Position = UDim2.fromOffset(12, 12),
		BackgroundColor3 = UI.Theme:get("surfaceAlt"),
		cornerRadius = UDim.new(0, 8),
		parent = card,
	}):render()

	local img = UI.Components.Image({
		Image = product.icon or "rbxassetid://0",
		Size = UDim2.fromScale(0.7, 0.7),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		parent = imgContainer,
	}):render()

	-- Info section
	local info = UI.Components.Frame({
		Size = UDim2.new(1, -24, 0, 136),
		Position = UDim2.fromOffset(12, 164),
		BackgroundTransparency = 1,
		parent = card,
	}):render()

	-- Title
	local title = UI.Components.TextLabel({
		Text = product.name,
		Size = UDim2.new(1, 0, 0, 24),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = info,
	}):render()

	-- Description
	local desc = UI.Components.TextLabel({
		Text = product.description,
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 28),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = UI.Theme:get("textSecondary"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		parent = info,
	}):render()

	-- Price
	local priceText = isGamepass and 
		string.format("R$ %d", product.price or 0) or
		string.format("R$ %d • %s Cash", product.price or 0, Core.Utils.formatNumber(product.amount))

	local price = UI.Components.TextLabel({
		Text = priceText,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 68),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = UI.Theme:get("accent"),
		TextXAlignment = Enum.TextXAlignment.Left,
		parent = info,
	}):render()

	-- Purchase button
	local isOwned = isGamepass and Core.DataManager.checkOwnership(product.id)

	local btn = UI.Components.Button({
		Text = isOwned and "Owned ✓" or "Purchase",
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.fromOffset(0, 94),
		BackgroundColor3 = isOwned and UI.Theme:get("success") or UI.Theme:get("accent"),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		cornerRadius = UDim.new(0, 8),
		parent = info,
	}):render()

	btn.MouseButton1Click:Connect(function()
		if not isOwned then
			self:purchase(product, productType)
		end
	end)

	-- Add toggle for owned gamepasses with toggle
	if isOwned and product.hasToggle then
		self:addToggle(product, card)
	end

	product.cardInstance = card
	product.purchaseButton = btn

	self:addCardHover(card)

	return card
end

-- ========================================
-- TOGGLE SWITCH
-- ========================================
function Shop:addToggle(product, card)
	local toggle = UI.Components.Frame({
		Size = UDim2.fromOffset(60, 32),
		Position = UDim2.new(1, -16, 0, 16),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = UI.Theme:get("stroke"),
		cornerRadius = UDim.new(1, 0),
		stroke = {
			color = UI.Theme:get("stroke"),
			thickness = 2,
		},
		parent = card,
	}):render()

	local knob = UI.Components.Frame({
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.fromOffset(4, 4),
		BackgroundColor3 = UI.Theme:get("surface"),
		cornerRadius = UDim.new(1, 0),
		parent = toggle,
	}):render()

	local state = false

	-- Get initial state
	if Remotes then
		local getState = Remotes:FindFirstChild("GetAutoCollectState")
		if getState and getState:IsA("RemoteFunction") then
			pcall(function()
				state = getState:InvokeServer() or false
			end)
		end
	end

	local function updateVisual()
		if state then
			toggle.BackgroundColor3 = UI.Theme:get("success")
			Core.Animation.tween(knob, {
				Position = UDim2.fromOffset(32, 4)
			}, Core.CONSTANTS.ANIM_FAST, Enum.EasingStyle.Back)
		else
			toggle.BackgroundColor3 = UI.Theme:get("stroke")
			Core.Animation.tween(knob, {
				Position = UDim2.fromOffset(4, 4)
			}, Core.CONSTANTS.ANIM_FAST, Enum.EasingStyle.Back)
		end
	end

	updateVisual()

	local btn = Instance.new("TextButton")
	btn.Text = ""
	btn.BackgroundTransparency = 1
	btn.Size = UDim2.fromScale(1, 1)
	btn.Parent = toggle

	btn.MouseButton1Click:Connect(function()
		state = not state
		updateVisual()

		if Remotes then
			local toggleEvent = Remotes:FindFirstChild("AutoCollectToggle")
			if toggleEvent and toggleEvent:IsA("RemoteEvent") then
				toggleEvent:FireServer(state)
			end
		end

		Core.SoundSystem.play("click")
		Notifications.show(
			state and "Auto Collect Enabled" or "Auto Collect Disabled",
			state and "success" or "info"
		)
	end)
end

-- ========================================
-- TAB SELECTION
-- ========================================
function Shop:selectTab(tabId, silent)
	if self.currentTab == tabId and not silent then return end

	-- Update tab appearance
	for id, tab in pairs(self.tabs) do
		local isActive = id == tabId
		local stroke = tab.button:FindFirstChildOfClass("UIStroke")

		if isActive then
			tab.button.BackgroundColor3 = UI.Theme:get("accent")
			tab.label.TextColor3 = Color3.new(1, 1, 1)
			tab.icon.TextColor3 = Color3.new(1, 1, 1)
			if stroke then stroke.Thickness = 0 end
		else
			tab.button.BackgroundColor3 = UI.Theme:get("surface")
			tab.label.TextColor3 = UI.Theme:get("text")
			tab.icon.TextColor3 = UI.Theme:get("text")
			if stroke then stroke.Thickness = 2 end
		end
	end

	-- Update page visibility
	for id, page in pairs(self.pages) do
		page.Visible = id == tabId
	end

	self.currentTab = tabId
	Core.State.currentTab = tabId

	if not silent then
		Core.SoundSystem.play("click")
	end
end

-- ========================================
-- PURCHASE HANDLING
-- ========================================
function Shop:purchase(product, productType)
	if productType == "gamepass" then
		-- Check ownership first
		if Core.DataManager.checkOwnership(product.id) then
			self:refreshProduct(product, productType)
			return
		end

		product.purchaseButton.Text = "Processing..."
		product.purchaseButton.Active = false

		Core.State.purchasePending[product.id] = {
			product = product,
			type = productType,
			timestamp = tick(),
		}

		local success, err = pcall(function()
			MarketplaceService:PromptGamePassPurchase(Player, product.id)
		end)

		if not success then
			product.purchaseButton.Text = "Purchase"
			product.purchaseButton.Active = true
			Core.State.purchasePending[product.id] = nil
			Notifications.show("Failed to open purchase prompt", "error")
			warn("[SanrioShop] Purchase error:", err)
		end

		task.delay(Core.CONSTANTS.PURCHASE_TIMEOUT, function()
			if Core.State.purchasePending[product.id] then
				product.purchaseButton.Text = "Purchase"
				product.purchaseButton.Active = true
				Core.State.purchasePending[product.id] = nil
			end
		end)
	else
		-- Dev product
		Core.State.purchasePending[product.id] = {
			product = product,
			type = productType,
			timestamp = tick(),
		}

		local success, err = pcall(function()
			MarketplaceService:PromptProductPurchase(Player, product.id)
		end)

		if not success then
			Core.State.purchasePending[product.id] = nil
			Notifications.show("Failed to open purchase prompt", "error")
			warn("[SanrioShop] Purchase error:", err)
		end
	end
end

function Shop:refreshProduct(product, productType)
	if productType == "gamepass" then
		local isOwned = Core.DataManager.checkOwnership(product.id)

		if product.purchaseButton then
			product.purchaseButton.Text = isOwned and "Owned ✓" or "Purchase"
			product.purchaseButton.BackgroundColor3 = isOwned and 
				UI.Theme:get("success") or UI.Theme:get("accent")
			product.purchaseButton.Active = not isOwned
		end
	end
end

function Shop:refreshAll()
	for _, pass in ipairs(Core.DataManager.products.gamepasses) do
		self:refreshProduct(pass, "gamepass")
	end
end

-- ========================================
-- ANIMATIONS
-- ========================================
function Shop:addPulse(instance)
	local original = instance.Size
	local running = true

	task.spawn(function()
		while running and instance.Parent do
			Core.Animation.tween(instance, {
				Size = UDim2.fromOffset(original.X.Offset * 1.03, original.Y.Offset * 1.03)
			}, 1.5, Enum.EasingStyle.Sine)
			task.wait(1.5)

			if not running or not instance.Parent then break end

			Core.Animation.tween(instance, {
				Size = original
			}, 1.5, Enum.EasingStyle.Sine)
			task.wait(1.5)
		end
	end)
end

function Shop:addCardHover(card)
	local original = card.Position
	local stroke = card:FindFirstChildOfClass("UIStroke")

	card.MouseEnter:Connect(function()
		Core.Animation.tween(card, {
			Position = UDim2.new(original.X.Scale, original.X.Offset, original.Y.Scale, original.Y.Offset - 6)
		}, Core.CONSTANTS.ANIM_FAST, Enum.EasingStyle.Back)
		
		if stroke then
			stroke.Color = UI.Theme:get("accent")
		end
	end)

	card.MouseLeave:Connect(function()
		Core.Animation.tween(card, {
			Position = original
		}, Core.CONSTANTS.ANIM_FAST)
		
		if stroke then
			stroke.Color = UI.Theme:get("stroke")
		end
	end)
end

-- ========================================
-- OPEN/CLOSE
-- ========================================
function Shop:open()
	if Core.State.isOpen or Core.State.isAnimating then return end

	Core.State.isAnimating = true
	Core.State.isOpen = true

	Core.DataManager.refreshPrices()
	self:refreshAll()

	self.gui.Enabled = true

	local panelSize = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE

	self.mainFrame.Position = UDim2.fromScale(0.5, 0.55)
	self.mainFrame.Size = UDim2.fromOffset(panelSize.X * 0.95, panelSize.Y * 0.95)

	Core.Animation.tween(self.mainFrame, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(panelSize.X, panelSize.Y)
	}, Core.CONSTANTS.ANIM_BOUNCE, Enum.EasingStyle.Back)

	Core.SoundSystem.play("open")

	task.wait(Core.CONSTANTS.ANIM_BOUNCE)
	Core.State.isAnimating = false
end

function Shop:close()
	if not Core.State.isOpen or Core.State.isAnimating then return end

	Core.State.isAnimating = true
	Core.State.isOpen = false

	local panelSize = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE

	Core.Animation.tween(self.mainFrame, {
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(panelSize.X * 0.95, panelSize.Y * 0.95)
	}, Core.CONSTANTS.ANIM_FAST)

	Core.SoundSystem.play("close")

	task.wait(Core.CONSTANTS.ANIM_FAST)
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

-- ========================================
-- REMOTES & INPUTS
-- ========================================
function Shop:setupRemotes()
	if not Remotes then 
		warn("[SanrioShop] Warning: TycoonRemotes not found")
		return 
	end

	local purchased = Remotes:FindFirstChild("GamepassPurchased")
	if purchased and purchased:IsA("RemoteEvent") then
		purchased.OnClientEvent:Connect(function(passId)
			self:refreshAll()
			Core.SoundSystem.play("success")
			Notifications.show("Purchase successful!", "success")
		end)
	end

	local granted = Remotes:FindFirstChild("ProductGranted") or Remotes:FindFirstChild("GrantProductCurrency")
	if granted and granted:IsA("RemoteEvent") then
		granted.OnClientEvent:Connect(function(productId, amount)
			Core.SoundSystem.play("success")
			if amount then
				Notifications.show(string.format("Received %s cash!", Core.Utils.formatNumber(amount)), "success")
			end
		end)
	end
end

function Shop:setupInputs()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end

		if input.KeyCode == Enum.KeyCode.M then
			self:toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and Core.State.isOpen then
			self:close()
		end
	end)
end

-- ========================================
-- MARKETPLACE CALLBACKS
-- ========================================
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if player ~= Player then return end

	local pending = Core.State.purchasePending[passId]
	if not pending then return end

	Core.State.purchasePending[passId] = nil

	if purchased then
		if pending.product.purchaseButton then
			pending.product.purchaseButton.Text = "Owned ✓"
			pending.product.purchaseButton.BackgroundColor3 = UI.Theme:get("success")
			pending.product.purchaseButton.Active = false
		end

		Core.SoundSystem.play("success")
		Notifications.show("Purchase successful!", "success")

		task.wait(0.5)
		shop:refreshAll()
	else
		if pending.product.purchaseButton then
			pending.product.purchaseButton.Text = "Purchase"
			pending.product.purchaseButton.Active = true
		end
		Notifications.show("Purchase cancelled", "info")
	end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, purchased)
	if player ~= Player then return end

	local pending = Core.State.purchasePending[productId]
	if not pending then return end

	Core.State.purchasePending[productId] = nil

	if purchased then
		Core.SoundSystem.play("success")

		if Remotes then
			local grant = Remotes:FindFirstChild("GrantProductCurrency")
			if grant and grant:IsA("RemoteEvent") then
				grant:FireServer(productId)
			else
				Notifications.show("Purchase successful!", "success")
			end
		end
	else
		Notifications.show("Purchase cancelled", "info")
	end
end)

-- ========================================
-- INITIALIZE
-- ========================================
local shop = Shop.new()

-- Handle respawn
Player.CharacterAdded:Connect(function()
	task.wait(1)
	if not shop.toggleButton or not shop.toggleButton.Parent then
		shop:createToggleButton()
	end
end)

-- Auto refresh
task.spawn(function()
	while true do
		task.wait(30)
		if Core.State.isOpen then
			shop:refreshAll()
		end
	end
end)

return shop
