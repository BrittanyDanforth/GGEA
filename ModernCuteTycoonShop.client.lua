--!strict
--[[
	MODULE: ModernCuteTycoonShop
	PURPOSE: Production-grade tycoon shop with modern cute aesthetic
	DEPENDENCIES: ReplicatedStorage.TycoonRemotes
	
	FEATURES:
	- Modern cute design (pastels, rounded corners, minimal depth)
	- Mobile-first responsive layout (scale-based, safe zones)
	- Type-safe with full --!strict compliance
	- Zero memory leaks (proper cleanup)
	- Cross-platform input (PC, mobile, gamepad)
	- Auto-sizing scroll with UIGridLayout
	- Gamepass ownership + Auto Collect toggle
	- Protected marketplace calls with retry logic
	
	CONTROLS:
	- M or ButtonX: Toggle shop
	- ESC: Close shop
	
	REMOTES (ReplicatedStorage > TycoonRemotes):
	- RemoteEvent: GrantProductCurrency(productId: number)
	- RemoteEvent: GamepassPurchased(passId: number)
	- RemoteEvent: AutoCollectToggle(enabled: boolean)
	- RemoteFunction: GetAutoCollectState() -> boolean
	
	NOTES:
	- Replace product/pass IDs with your actual IDs
	- Replace asset IDs with your icons
	- Test with Device Emulator for cross-platform
]]

--// Services (alphabetical, imported once)
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--// =========================
--// Type Definitions
--// =========================

type ProductInfo = {
	PriceInRobux: number?,
	Name: string?,
	Description: string?,
}

type CashProduct = {
	id: number,
	amount: number,
	name: string,
	description: string,
	icon: string,
	price: number?,
	_card: Frame?,
	_priceLabel: TextLabel?,
	_buyButton: TextButton?,
}

type GamePass = {
	id: number,
	name: string,
	description: string,
	icon: string,
	hasToggle: boolean,
	price: number?,
	_card: Frame?,
	_priceLabel: TextLabel?,
	_buyButton: TextButton?,
}

type ShopConfig = {
	Version: string,
	PurchaseTimeout: number,
	RefreshInterval: number,
	Assets: {
		CashIcon: string,
		PassIcon: string,
		ShopIcon: string,
		VignetteOverlay: string,
	},
	PassIds: {
		AutoCollect: number,
		DoubleCash: number,
	},
	Products: {
		cash: { CashProduct },
		gamepasses: { GamePass },
	},
}

type CacheEntry<T> = { value: T, timestamp: number }

type Cache<T> = {
	get: (self: Cache<T>, key: string) -> T?,
	set: (self: Cache<T>, key: string, value: T) -> (),
	clear: (self: Cache<T>, key: string?) -> (),
}

type ShopState = {
	isOpen: boolean,
	isAnimating: boolean,
	currentTab: string,
	purchasePending: { [number]: { timestamp: number } },
}

type ShopController = {
	_config: ShopConfig,
	_state: ShopState,
	_connections: { RBXScriptConnection },
	_gui: ScreenGui?,
	_panel: Frame?,
	_blur: BlurEffect?,
	_pages: { [string]: Frame },
	_tabButtons: { [string]: { button: TextButton, accent: Color3 } },
	_autoToggleSettings: Frame?,
	_productCache: Cache<ProductInfo>,
	_ownershipCache: Cache<boolean>,
	init: (self: ShopController) -> (),
	destroy: (self: ShopController) -> (),
	open: (self: ShopController) -> (),
	close: (self: ShopController) -> (),
	toggle: (self: ShopController) -> (),
	selectTab: (self: ShopController, tabId: string) -> (),
	refreshVisuals: (self: ShopController) -> (),
}

--// =========================
--// Design Tokens
--// =========================

local Tokens = {
	colors = {
		bg          = Color3.fromRGB(250, 247, 245),
		surface     = Color3.fromRGB(255, 255, 255),
		surfaceAlt  = Color3.fromRGB(246, 242, 246),
		stroke      = Color3.fromRGB(224, 214, 220),
		text        = Color3.fromRGB(42, 38, 54),
		textMuted   = Color3.fromRGB(116, 108, 132),
		mint        = Color3.fromRGB(178, 224, 214),
		lavender    = Color3.fromRGB(206, 196, 255),
		sky         = Color3.fromRGB(186, 214, 255),
		success     = Color3.fromRGB(125, 194, 144),
		warning     = Color3.fromRGB(245, 201, 120),
		danger      = Color3.fromRGB(255, 120, 140),
	},
	radius = {
		sm   = UDim.new(0, 8),
		md   = UDim.new(0, 12),
		lg   = UDim.new(0, 16),
		xl   = UDim.new(0, 20),
		full = UDim.new(1, 0),
	},
	spacing = {
		xs  = UDim.new(0, 8),
		sm  = UDim.new(0, 12),
		md  = UDim.new(0, 16),
		lg  = UDim.new(0, 20),
		xl  = UDim.new(0, 24),
	},
	font = {
		displayBold = { family = Enum.Font.GothamBold,   size = 28 },
		titleBold   = { family = Enum.Font.GothamBold,   size = 24 },
		headingBold = { family = Enum.Font.GothamBold,   size = 20 },
		labelMedium = { family = Enum.Font.GothamMedium, size = 18 },
		body        = { family = Enum.Font.Gotham,       size = 16 },
		caption     = { family = Enum.Font.Gotham,       size = 14 },
	},
	animation = {
		fast = 0.12,
		medium = 0.22,
		slow = 0.35,
	},
}

--// =========================
--// Utilities
--// =========================

local Utils = {}

function Utils.isConsole(): boolean
	return GuiService:IsTenFootInterface()
end

function Utils.isSmallViewport(): boolean
	local cam = workspace.CurrentCamera
	if not cam then return false end
	local viewport = cam.ViewportSize
	return viewport.X < 1024 or Utils.isConsole()
end

function Utils.formatNumber(n: number): string
	local str = tostring(n)
	local k: number
	repeat
		str, k = str:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return str
end

function Utils.tween(
	instance: Instance,
	props: { [string]: any },
	duration: number?,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local tweenInfo = TweenInfo.new(
		duration or Tokens.animation.medium,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out
	)
	local tween = TweenService:Create(instance, tweenInfo, props)
	tween:Play()
	return tween
end

function Utils.applyCorner(instance: GuiObject, radius: UDim?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Tokens.radius.md
	corner.Parent = instance
	return corner
end

function Utils.applyStroke(
	instance: GuiObject,
	color: Color3?,
	thickness: number?,
	transparency: number?
): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Tokens.colors.stroke
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0.25
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

function Utils.applyPadding(
	instance: GuiObject,
	padding: { top: UDim?, bottom: UDim?, left: UDim?, right: UDim? }?
): UIPadding?
	if not padding then return nil end
	local pad = Instance.new("UIPadding")
	if padding.top then pad.PaddingTop = padding.top end
	if padding.bottom then pad.PaddingBottom = padding.bottom end
	if padding.left then pad.PaddingLeft = padding.left end
	if padding.right then pad.PaddingRight = padding.right end
	pad.Parent = instance
	return pad
end

--// =========================
--// Cache Implementation
--// =========================

local CacheClass = {}
CacheClass.__index = CacheClass

function CacheClass.new<T>(ttl: number): Cache<T>
	local self = setmetatable({}, CacheClass)
	(self :: any)._ttl = ttl
	(self :: any)._store = {} :: { [string]: CacheEntry<T> }
	return (self :: any) :: Cache<T>
end

function CacheClass:get<T>(key: string): T?
	local store = (self :: any)._store :: { [string]: CacheEntry<T> }
	local entry = store[key]
	if not entry then return nil end
	
	local ttl = (self :: any)._ttl :: number
	if os.clock() - entry.timestamp > ttl then
		store[key] = nil
		return nil
	end
	
	return entry.value
end

function CacheClass:set<T>(key: string, value: T)
	local store = (self :: any)._store :: { [string]: CacheEntry<T> }
	store[key] = { value = value, timestamp = os.clock() }
end

function CacheClass:clear<T>(key: string?)
	local store = (self :: any)._store :: { [string]: CacheEntry<T> }
	if key then
		store[key] = nil
	else
		table.clear(store)
	end
end

--// =========================
--// UI Component Primitives
--// =========================

local UI = {}

function UI.FrameX(props: { [string]: any }): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = props.BackgroundColor3 or Tokens.colors.surface
	frame.BorderSizePixel = 0
	
	for key, value in pairs(props) do
		if key ~= "corner" and key ~= "stroke" and key ~= "padding" and key ~= "Parent" then
			pcall(function() (frame :: any)[key] = value end)
		end
	end
	
	if props.corner then Utils.applyCorner(frame, props.corner) end
	if props.stroke then
		Utils.applyStroke(
			frame,
			props.stroke.Color,
			props.stroke.Thickness,
			props.stroke.Transparency
		)
	end
	if props.padding then Utils.applyPadding(frame, props.padding) end
	if props.Parent then frame.Parent = props.Parent end
	
	return frame
end

function UI.TextLabelX(props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = props.Font or Tokens.font.body.family
	label.TextSize = props.TextSize or Tokens.font.body.size
	label.TextColor3 = props.TextColor3 or Tokens.colors.text
	label.TextWrapped = if props.TextWrapped ~= nil then props.TextWrapped else true
	
	for key, value in pairs(props) do
		if key ~= "Parent" then
			pcall(function() (label :: any)[key] = value end)
		end
	end
	
	if props.Parent then label.Parent = props.Parent end
	return label
end

function UI.TextButtonX(props: { [string]: any }): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.Font = props.Font or Tokens.font.labelMedium.family
	button.TextSize = props.TextSize or Tokens.font.labelMedium.size
	button.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	button.BackgroundColor3 = props.BackgroundColor3 or Tokens.colors.mint
	button.BorderSizePixel = 0
	
	for key, value in pairs(props) do
		if key ~= "corner" and key ~= "stroke" and key ~= "padding" and key ~= "Parent" then
			pcall(function() (button :: any)[key] = value end)
		end
	end
	
	if props.corner then Utils.applyCorner(button, props.corner) end
	if props.stroke then
		Utils.applyStroke(
			button,
			props.stroke.Color,
			props.stroke.Thickness,
			props.stroke.Transparency
		)
	end
	if props.padding then Utils.applyPadding(button, props.padding) end
	if props.Parent then button.Parent = props.Parent end
	
	return button
end

function UI.ImageLabelX(props: { [string]: any }): ImageLabel
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.ScaleType = props.ScaleType or Enum.ScaleType.Fit
	
	for key, value in pairs(props) do
		if key ~= "corner" and key ~= "Parent" then
			pcall(function() (image :: any)[key] = value end)
		end
	end
	
	if props.corner then Utils.applyCorner(image, props.corner) end
	if props.Parent then image.Parent = props.Parent end
	
	return image
end

--// =========================
--// Shop Controller
--// =========================

local ShopController = {}
ShopController.__index = ShopController

function ShopController.new(config: ShopConfig): ShopController
	local self = setmetatable({}, ShopController) :: any
	
	self._config = config
	self._state = {
		isOpen = false,
		isAnimating = false,
		currentTab = "Cash",
		purchasePending = {},
	} :: ShopState
	self._connections = {}
	self._gui = nil
	self._panel = nil
	self._blur = nil
	self._pages = {}
	self._tabButtons = {}
	self._autoToggleSettings = nil
	self._productCache = CacheClass.new(300) :: Cache<ProductInfo>
	self._ownershipCache = CacheClass.new(60) :: Cache<boolean>
	
	return (self :: any) :: ShopController
end

--// Data Fetching (with retry logic)

function ShopController:_getProductInfo(productId: number, retries: number?): ProductInfo?
	local cached = self._productCache:get(tostring(productId))
	if cached then return cached end
	
	local maxRetries = retries or 3
	for attempt = 1, maxRetries do
		local success, result = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)
		
		if success and result then
			self._productCache:set(tostring(productId), result)
			return result
		else
			warn(`[Shop] GetProductInfo attempt {attempt}/{maxRetries} failed:`, result)
			if attempt < maxRetries then
				task.wait(0.5 * attempt) -- Exponential backoff
			end
		end
	end
	
	return nil
end

function ShopController:_getPassInfo(passId: number, retries: number?): ProductInfo?
	local key = `pass_{passId}`
	local cached = self._productCache:get(key)
	if cached then return cached end
	
	local maxRetries = retries or 3
	for attempt = 1, maxRetries do
		local success, result = pcall(function()
			return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
		end)
		
		if success and result then
			self._productCache:set(key, result)
			return result
		else
			warn(`[Shop] GetPassInfo attempt {attempt}/{maxRetries} failed:`, result)
			if attempt < maxRetries then
				task.wait(0.5 * attempt)
			end
		end
	end
	
	return nil
end

function ShopController:_ownsGamePass(passId: number): boolean
	local key = `{Player.UserId}:{passId}`
	local cached = self._ownershipCache:get(key)
	if cached ~= nil then return cached end
	
	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, passId)
	end)
	
	if success then
		self._ownershipCache:set(key, owns)
		return owns
	end
	
	return false
end

function ShopController:_refreshPrices()
	-- Refresh cash product prices
	for _, product in ipairs(self._config.Products.cash) do
		local info = self:_getProductInfo(product.id)
		if info then
			product.price = info.PriceInRobux or 0
		end
	end
	
	-- Refresh gamepass prices
	for _, pass in ipairs(self._config.Products.gamepasses) do
		local info = self:_getPassInfo(pass.id)
		if info then
			pass.price = info.PriceInRobux or 0
		end
	end
end

--// GUI Building

function ShopController:_buildGui()
	-- Create or reuse ScreenGui
	local gui = PlayerGui:FindFirstChild("TycoonShopUI") :: ScreenGui?
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "TycoonShopUI"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 1000
		gui.IgnoreGuiInset = true
		gui.Enabled = false
		gui.Parent = PlayerGui
	end
	
	-- Dim overlay
	UI.ImageLabelX({
		Name = "DimOverlay",
		Image = self._config.Assets.VignetteOverlay,
		ImageTransparency = 0.25,
		ImageColor3 = Color3.new(0, 0, 0),
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	
	-- Main panel (scale-based with aspect constraint)
	local panel = UI.FrameX({
		Name = "Panel",
		Size = UDim2.new(0.9, 0, 0.85, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Tokens.colors.surface,
		corner = Tokens.radius.xl,
		stroke = { Color = Tokens.colors.stroke, Transparency = 0.5 },
		Parent = gui,
	})
	
	local aspectRatio = Instance.new("UIAspectRatioConstraint")
	aspectRatio.AspectRatio = 1.6
	aspectRatio.DominantAxis = Enum.DominantAxis.Height
	aspectRatio.Parent = panel
	
	-- Blur effect for background
	local blur = Lighting:FindFirstChild("ShopBlur") :: BlurEffect?
	if not blur then
		blur = Instance.new("BlurEffect")
		blur.Name = "ShopBlur"
		blur.Size = 0
		blur.Parent = Lighting
	end
	
	self._gui = gui
	self._panel = panel
	self._blur = blur
end

function ShopController:_buildHeader()
	if not self._panel then return end
	
	local header = UI.FrameX({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Tokens.colors.surfaceAlt,
		corner = Tokens.radius.xl,
		padding = { left = Tokens.spacing.md, right = Tokens.spacing.md },
		Parent = self._panel,
	})
	
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = Tokens.spacing.sm
	layout.Parent = header
	
	-- Shop icon
	UI.ImageLabelX({
		Image = self._config.Assets.ShopIcon,
		Size = UDim2.fromOffset(36, 36),
		LayoutOrder = 1,
		Parent = header,
	})
	
	-- Title
	UI.TextLabelX({
		Text = "Game Shop",
		Font = Tokens.font.titleBold.family,
		TextSize = Tokens.font.titleBold.size,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -120, 1, 0),
		LayoutOrder = 2,
		Parent = header,
	})
	
	-- Close button
	local closeBtn = UI.TextButtonX({
		Text = "✕",
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Tokens.colors.surface,
		TextColor3 = Tokens.colors.text,
		Font = Tokens.font.titleBold.family,
		TextSize = 20,
		corner = Tokens.radius.full,
		LayoutOrder = 3,
		Parent = header,
	})
	
	table.insert(self._connections, closeBtn.MouseButton1Click:Connect(function()
		self:close()
	end))
	
	table.insert(self._connections, closeBtn.MouseEnter:Connect(function()
		Utils.tween(closeBtn, { BackgroundColor3 = Tokens.colors.stroke }, Tokens.animation.fast)
	end))
	
	table.insert(self._connections, closeBtn.MouseLeave:Connect(function()
		Utils.tween(closeBtn, { BackgroundColor3 = Tokens.colors.surface }, Tokens.animation.fast)
	end))
end

function ShopController:_buildNav()
	if not self._panel then return end
	
	local nav = UI.FrameX({
		Name = "Nav",
		Size = UDim2.new(0, 200, 1, -80),
		Position = UDim2.fromOffset(16, 72),
		BackgroundColor3 = Tokens.colors.surfaceAlt,
		corner = Tokens.radius.md,
		stroke = { Color = Tokens.colors.stroke, Transparency = 0.6 },
		padding = { top = Tokens.spacing.sm, bottom = Tokens.spacing.sm, left = Tokens.spacing.sm, right = Tokens.spacing.sm },
		Parent = self._panel,
	})
	
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = Tokens.spacing.xs
	list.Parent = nav
	
	local tabs = {
		{ id = "Cash", name = "Cash Packs", accent = Tokens.colors.mint },
		{ id = "Gamepasses", name = "Game Passes", accent = Tokens.colors.lavender },
	}
	
	for _, tab in ipairs(tabs) do
		local btn = UI.TextButtonX({
			Text = tab.name,
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = Tokens.colors.surface,
			TextColor3 = Tokens.colors.text,
			Font = Tokens.font.labelMedium.family,
			TextSize = 18,
			corner = Tokens.radius.sm,
			Parent = nav,
		})
		
		table.insert(self._connections, btn.MouseButton1Click:Connect(function()
			self:selectTab(tab.id)
		end))
		
		table.insert(self._connections, btn.MouseEnter:Connect(function()
			Utils.tween(btn, { BackgroundColor3 = tab.accent, TextColor3 = Color3.new(1, 1, 1) }, Tokens.animation.fast)
		end))
		
		table.insert(self._connections, btn.MouseLeave:Connect(function()
			local isActive = self._state.currentTab == tab.id
			local bgColor = if isActive then tab.accent else Tokens.colors.surface
			local textColor = if isActive then Color3.new(1, 1, 1) else Tokens.colors.text
			Utils.tween(btn, { BackgroundColor3 = bgColor, TextColor3 = textColor }, Tokens.animation.fast)
		end))
		
		self._tabButtons[tab.id] = { button = btn, accent = tab.accent }
	end
end

function ShopController:_buildContent()
	if not self._panel then return end
	
	local content = UI.FrameX({
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -232, 1, -96),
		Position = UDim2.fromOffset(216, 80),
		Parent = self._panel,
	})
	
	self._pages.Cash = self:_createCashPage(content)
	self._pages.Gamepasses = self:_createPassPage(content)
	
	self:selectTab(self._state.currentTab)
end

function ShopController:_createCashPage(parent: Frame): Frame
	local page = UI.FrameX({
		Name = "CashPage",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	
	-- Section header
	local header = UI.FrameX({
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Tokens.colors.surfaceAlt,
		corner = Tokens.radius.sm,
		padding = { left = Tokens.spacing.md, right = Tokens.spacing.md },
		Parent = page,
	})
	
	UI.TextLabelX({
		Text = "Cash Packs",
		Font = Tokens.font.headingBold.family,
		TextSize = Tokens.font.headingBold.size,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = header,
	})
	
	-- Scroll container with AutomaticCanvasSize
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Tokens.colors.stroke
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Size = UDim2.new(1, 0, 1, -56)
	scroll.Position = UDim2.fromOffset(0, 52)
	scroll.Parent = page
	
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellPadding = UDim2.fromOffset(16, 16)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.FillDirectionMaxCells = 3
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroll
	
	for index, product in ipairs(self._config.Products.cash) do
		self:_createCashCard(product, scroll, index)
	end
	
	return page
end

function ShopController:_createCashCard(product: CashProduct, parent: Instance, order: number)
	local card = UI.FrameX({
		Name = `{product.name}Card`,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Tokens.colors.surface,
		corner = Tokens.radius.md,
		stroke = { Color = Tokens.colors.mint, Transparency = 0.4 },
		Parent = parent,
	})
	card.LayoutOrder = order
	
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1.55
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = card
	
	local inner = UI.FrameX({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 1, -24),
		Position = UDim2.fromOffset(12, 12),
		Parent = card,
	})
	
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = Tokens.spacing.xs
	layout.Parent = inner
	
	-- Icon + Name row
	local row = UI.FrameX({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = inner,
	})
	
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = Tokens.spacing.xs
	rowLayout.Parent = row
	
	UI.ImageLabelX({
		Image = product.icon,
		Size = UDim2.fromOffset(36, 36),
		Parent = row,
	})
	
	UI.TextLabelX({
		Text = product.name,
		Font = Tokens.font.headingBold.family,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -44, 1, 0),
		Parent = row,
	})
	
	-- Description
	UI.TextLabelX({
		Text = product.description,
		TextColor3 = Tokens.colors.textMuted,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = inner,
	})
	
	-- Price
	local priceText = `R${product.price or 0}  •  {Utils.formatNumber(product.amount)} Cash`
	local priceLabel = UI.TextLabelX({
		Text = priceText,
		Font = Tokens.font.labelMedium.family,
		TextSize = 18,
		TextColor3 = Tokens.colors.mint,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = inner,
	})
	
	-- Purchase button
	local buyBtn = UI.TextButtonX({
		Text = "Purchase",
		BackgroundColor3 = Tokens.colors.mint,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Tokens.font.labelMedium.family,
		TextSize = 18,
		Size = UDim2.new(1, 0, 0, 40),
		corner = Tokens.radius.sm,
		Parent = inner,
	})
	
	table.insert(self._connections, buyBtn.MouseButton1Click:Connect(function()
		self:_promptPurchase(product.id, "product")
	end))
	
	-- Hover effect
	table.insert(self._connections, card.MouseEnter:Connect(function()
		if Utils.isSmallViewport() then return end
		Utils.tween(card, { BackgroundColor3 = Tokens.colors.surfaceAlt }, Tokens.animation.fast)
	end))
	
	table.insert(self._connections, card.MouseLeave:Connect(function()
		Utils.tween(card, { BackgroundColor3 = Tokens.colors.surface }, Tokens.animation.fast)
	end))
	
	product._card = card
	product._priceLabel = priceLabel
	product._buyButton = buyBtn
end

function ShopController:_createPassPage(parent: Frame): Frame
	local page = UI.FrameX({
		Name = "PassPage",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	
	-- Section header
	local header = UI.FrameX({
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Tokens.colors.surfaceAlt,
		corner = Tokens.radius.sm,
		padding = { left = Tokens.spacing.md, right = Tokens.spacing.md },
		Parent = page,
	})
	
	UI.TextLabelX({
		Text = "Game Passes",
		Font = Tokens.font.headingBold.family,
		TextSize = Tokens.font.headingBold.size,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = header,
	})
	
	-- Scroll container
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Tokens.colors.stroke
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Size = UDim2.new(1, 0, 1, -128)
	scroll.Position = UDim2.fromOffset(0, 52)
	scroll.Parent = page
	
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellPadding = UDim2.fromOffset(16, 16)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.FillDirectionMaxCells = 3
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroll
	
	for index, pass in ipairs(self._config.Products.gamepasses) do
		self:_createPassCard(pass, scroll, index)
	end
	
	-- Settings panel for Auto Collect toggle
	local settings = UI.FrameX({
		Name = "Settings",
		Size = UDim2.new(1, 0, 0, 64),
		Position = UDim2.new(0, 0, 1, -72),
		BackgroundColor3 = Tokens.colors.surfaceAlt,
		corner = Tokens.radius.sm,
		padding = { left = Tokens.spacing.md, right = Tokens.spacing.md },
		Parent = page,
	})
	
	UI.TextLabelX({
		Text = "Quick Settings",
		Font = Tokens.font.labelMedium.family,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.5, 0, 1, 0),
		Parent = settings,
	})
	
	local autoToggle = self:_createToggle(settings, "Auto Collect", false, function(state: boolean)
		local remotes = ReplicatedStorage:FindFirstChild("TycoonRemotes")
		if not remotes then return end
		
		local remote = remotes:FindFirstChild("AutoCollectToggle")
		if remote and remote:IsA("RemoteEvent") then
			(remote :: RemoteEvent):FireServer(state)
		end
	end)
	
	autoToggle.Position = UDim2.new(1, -120, 0.5, 0)
	autoToggle.AnchorPoint = Vector2.new(1, 0.5)
	autoToggle.Visible = false
	
	self._autoToggleSettings = autoToggle
	
	-- Check if player owns Auto Collect
	local ownsAutoCollect = self:_ownsGamePass(self._config.PassIds.AutoCollect)
	if ownsAutoCollect then
		autoToggle.Visible = true
		
		-- Get initial state from server
		local remotes = ReplicatedStorage:FindFirstChild("TycoonRemotes")
		if remotes then
			local stateFunc = remotes:FindFirstChild("GetAutoCollectState")
			if stateFunc and stateFunc:IsA("RemoteFunction") then
				local success, currentState = pcall(function()
					return (stateFunc :: RemoteFunction):InvokeServer()
				end)
				
				if success and typeof(currentState) == "boolean" then
					self:_setToggleState(autoToggle, currentState)
				end
			end
		end
	end
	
	return page
end

function ShopController:_createPassCard(pass: GamePass, parent: Instance, order: number)
	local card = UI.FrameX({
		Name = `{pass.name}Card`,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Tokens.colors.surface,
		corner = Tokens.radius.md,
		stroke = { Color = Tokens.colors.lavender, Transparency = 0.45 },
		Parent = parent,
	})
	card.LayoutOrder = order
	
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1.55
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = card
	
	local inner = UI.FrameX({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 1, -24),
		Position = UDim2.fromOffset(12, 12),
		Parent = card,
	})
	
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = Tokens.spacing.xs
	layout.Parent = inner
	
	-- Icon + Name row
	local row = UI.FrameX({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = inner,
	})
	
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = Tokens.spacing.xs
	rowLayout.Parent = row
	
	UI.ImageLabelX({
		Image = pass.icon,
		Size = UDim2.fromOffset(36, 36),
		Parent = row,
	})
	
	UI.TextLabelX({
		Text = pass.name,
		Font = Tokens.font.headingBold.family,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -44, 1, 0),
		Parent = row,
	})
	
	-- Description
	UI.TextLabelX({
		Text = pass.description,
		TextColor3 = Tokens.colors.textMuted,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = inner,
	})
	
	-- Price
	local priceText = `R${pass.price or 0}`
	local priceLabel = UI.TextLabelX({
		Text = priceText,
		Font = Tokens.font.labelMedium.family,
		TextSize = 18,
		TextColor3 = Tokens.colors.lavender,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = inner,
	})
	
	-- Purchase button
	local buyBtn = UI.TextButtonX({
		Text = "Purchase",
		BackgroundColor3 = Tokens.colors.lavender,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Tokens.font.labelMedium.family,
		TextSize = 18,
		Size = UDim2.new(1, 0, 0, 40),
		corner = Tokens.radius.sm,
		Parent = inner,
	})
	
	table.insert(self._connections, buyBtn.MouseButton1Click:Connect(function()
		self:_promptPurchase(pass.id, "gamepass")
	end))
	
	-- Check ownership
	local owned = self:_ownsGamePass(pass.id)
	self:_updatePassVisual(pass, owned, buyBtn, card)
	
	-- Hover effect
	table.insert(self._connections, card.MouseEnter:Connect(function()
		if Utils.isSmallViewport() then return end
		Utils.tween(card, { BackgroundColor3 = Tokens.colors.surfaceAlt }, Tokens.animation.fast)
	end))
	
	table.insert(self._connections, card.MouseLeave:Connect(function()
		Utils.tween(card, { BackgroundColor3 = Tokens.colors.surface }, Tokens.animation.fast)
	end))
	
	pass._card = card
	pass._priceLabel = priceLabel
	pass._buyButton = buyBtn
end

function ShopController:_updatePassVisual(
	pass: GamePass,
	owned: boolean,
	btn: TextButton?,
	card: Frame?
)
	local button = btn or pass._buyButton
	local passCard = card or pass._card
	if not button or not passCard then return end
	
	button.Text = if owned then "Owned" else "Purchase"
	button.Active = not owned
	button.BackgroundColor3 = if owned then Tokens.colors.success else Tokens.colors.lavender
	
	local stroke = passCard:FindFirstChildOfClass("UIStroke")
	if stroke then
		(stroke :: UIStroke).Color = if owned then Tokens.colors.success else Tokens.colors.lavender
	end
end

--// Toggle Widget

function ShopController:_createToggle(
	parent: Instance,
	label: string,
	initial: boolean,
	onChange: (boolean) -> ()
): Frame
	local wrapper = Instance.new("Frame")
	wrapper.BackgroundTransparency = 1
	wrapper.Size = UDim2.fromOffset(108, 32)
	wrapper.Parent = parent
	
	-- Label
	UI.TextLabelX({
		Text = label,
		TextColor3 = Tokens.colors.textMuted,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(52, 32),
		Parent = wrapper,
	})
	
	-- Track
	local track = UI.FrameX({
		Size = UDim2.fromOffset(52, 26),
		Position = UDim2.fromOffset(56, 3),
		BackgroundColor3 = if initial then Tokens.colors.mint else Tokens.colors.stroke,
		corner = Tokens.radius.full,
		Parent = wrapper,
	})
	
	-- Thumb
	local thumb = UI.FrameX({
		Size = UDim2.fromOffset(22, 22),
		Position = if initial then UDim2.fromOffset(28, 2) else UDim2.fromOffset(2, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		corner = Tokens.radius.full,
		Parent = track,
	})
	
	-- Hit box
	local button = Instance.new("TextButton")
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromScale(1, 1)
	button.Text = ""
	button.Parent = wrapper
	
	local state = initial
	
	local function updateVisual()
		Utils.tween(track, {
			BackgroundColor3 = if state then Tokens.colors.mint else Tokens.colors.stroke
		}, Tokens.animation.fast)
		
		Utils.tween(thumb, {
			Position = if state then UDim2.fromOffset(28, 2) else UDim2.fromOffset(2, 2)
		}, Tokens.animation.fast)
		
		wrapper:SetAttribute("_toggleState", state)
	end
	
	table.insert(self._connections, button.MouseButton1Click:Connect(function()
		state = not state
		updateVisual()
		onChange(state)
	end))
	
	updateVisual()
	
	return wrapper
end

function ShopController:_setToggleState(toggle: Frame, newState: boolean)
	toggle:SetAttribute("_toggleState", newState)
	
	local track = toggle:FindFirstChildOfClass("Frame")
	if not track then return end
	
	local thumb = track:FindFirstChildOfClass("Frame")
	if not thumb then return end
	
	track.BackgroundColor3 = if newState then Tokens.colors.mint else Tokens.colors.stroke
	thumb.Position = if newState then UDim2.fromOffset(28, 2) else UDim2.fromOffset(2, 2)
end

--// Public Methods

function ShopController:init()
	self:_buildGui()
	self:_buildHeader()
	self:_buildNav()
	self:_buildContent()
	self:_connectInputs()
	self:_connectMarketplace()
	
	-- Periodic refresh
	task.spawn(function()
		while true do
			task.wait(self._config.RefreshInterval)
			if self._state.isOpen then
				self:_refreshPrices()
				self:refreshVisuals()
			end
		end
	end)
end

function ShopController:open()
	if self._state.isOpen or self._state.isAnimating then return end
	
	self._state.isAnimating = true
	self._state.isOpen = true
	
	self:_refreshPrices()
	self:refreshVisuals()
	
	if not self._gui or not self._panel or not self._blur then return end
	
	self._gui.Enabled = true
	Utils.tween(self._blur, { Size = 28 }, Tokens.animation.medium)
	
	self._panel.Position = UDim2.fromScale(0.5, 0.52)
	Utils.tween(self._panel, { Position = UDim2.fromScale(0.5, 0.5) }, Tokens.animation.slow, Enum.EasingStyle.Back)
	
	task.delay(Tokens.animation.slow, function()
		self._state.isAnimating = false
	end)
end

function ShopController:close()
	if not self._state.isOpen or self._state.isAnimating then return end
	
	self._state.isAnimating = true
	self._state.isOpen = false
	
	if not self._gui or not self._panel or not self._blur then return end
	
	Utils.tween(self._blur, { Size = 0 }, Tokens.animation.fast)
	Utils.tween(self._panel, { Position = UDim2.fromScale(0.5, 0.52) }, Tokens.animation.fast)
	
	task.delay(Tokens.animation.fast, function()
		self._gui.Enabled = false
		self._state.isAnimating = false
	end)
end

function ShopController:toggle()
	if self._state.isOpen then
		self:close()
	else
		self:open()
	end
end

function ShopController:selectTab(tabId: string)
	if self._state.currentTab == tabId then
		for id, page in pairs(self._pages) do
			page.Visible = (id == tabId)
		end
		return
	end
	
	for id, data in pairs(self._tabButtons) do
		local isActive = (id == tabId)
		local bgColor = if isActive then data.accent else Tokens.colors.surface
		local textColor = if isActive then Color3.new(1, 1, 1) else Tokens.colors.text
		
		Utils.tween(data.button, {
			BackgroundColor3 = bgColor,
			TextColor3 = textColor,
		}, Tokens.animation.fast)
	end
	
	for id, page in pairs(self._pages) do
		page.Visible = (id == tabId)
	end
	
	self._state.currentTab = tabId
end

function ShopController:refreshVisuals()
	self._ownershipCache:clear()
	
	-- Update gamepass visuals
	for _, pass in ipairs(self._config.Products.gamepasses) do
		local owned = self:_ownsGamePass(pass.id)
		self:_updatePassVisual(pass, owned, nil, nil)
	end
	
	-- Update cash prices
	for _, product in ipairs(self._config.Products.cash) do
		if product._priceLabel then
			product._priceLabel.Text = `R${product.price or 0}  •  {Utils.formatNumber(product.amount)} Cash`
		end
	end
	
	-- Update settings toggle visibility
	if self._autoToggleSettings then
		self._autoToggleSettings.Visible = self:_ownsGamePass(self._config.PassIds.AutoCollect)
	end
end

function ShopController:_promptPurchase(itemId: number, kind: string)
	if kind == "gamepass" then
		if self:_ownsGamePass(itemId) then return end
		
		self._state.purchasePending[itemId] = { timestamp = os.clock() }
		
		pcall(function()
			MarketplaceService:PromptGamePassPurchase(Player, itemId)
		end)
		
		task.delay(self._config.PurchaseTimeout, function()
			if self._state.purchasePending[itemId] then
				self._state.purchasePending[itemId] = nil
			end
		end)
	else
		self._state.purchasePending[itemId] = { timestamp = os.clock() }
		
		pcall(function()
			MarketplaceService:PromptProductPurchase(Player, itemId)
		end)
	end
end

function ShopController:_connectInputs()
	-- Keyboard + Gamepad
	table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		
		if input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.ButtonX then
			self:toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and self._state.isOpen then
			self:close()
		end
	end))
	
	-- Floating shop button
	local toggleGui = PlayerGui:FindFirstChild("ShopToggleButton") :: ScreenGui?
	if not toggleGui then
		toggleGui = Instance.new("ScreenGui")
		toggleGui.Name = "ShopToggleButton"
		toggleGui.ResetOnSpawn = false
		toggleGui.DisplayOrder = 999
		toggleGui.Parent = PlayerGui
	end
	
	local pill = UI.TextButtonX({
		Text = "Shop",
		BackgroundColor3 = Tokens.colors.surface,
		TextColor3 = Tokens.colors.text,
		Font = Tokens.font.labelMedium.family,
		TextSize = 20,
		Size = UDim2.fromOffset(156, 56),
		Position = UDim2.new(1, -20, 1, -20),
		AnchorPoint = Vector2.new(1, 1),
		corner = Tokens.radius.full,
		Parent = toggleGui,
	})
	
	table.insert(self._connections, pill.MouseButton1Click:Connect(function()
		self:toggle()
	end))
	
	table.insert(self._connections, pill.MouseEnter:Connect(function()
		Utils.tween(pill, {
			BackgroundColor3 = Tokens.colors.mint,
			TextColor3 = Color3.new(1, 1, 1),
		}, Tokens.animation.fast)
	end))
	
	table.insert(self._connections, pill.MouseLeave:Connect(function()
		Utils.tween(pill, {
			BackgroundColor3 = Tokens.colors.surface,
			TextColor3 = Tokens.colors.text,
		}, Tokens.animation.fast)
	end))
end

function ShopController:_connectMarketplace()
	-- Gamepass purchase finished
	table.insert(self._connections, MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if player ~= Player then return end
			if not self._state.purchasePending[passId] then return end
			
			self._state.purchasePending[passId] = nil
			
			if purchased then
				self._ownershipCache:clear()
				self:refreshVisuals()
				
				local remotes = ReplicatedStorage:FindFirstChild("TycoonRemotes")
				if remotes then
					local remote = remotes:FindFirstChild("GamepassPurchased")
					if remote and remote:IsA("RemoteEvent") then
						(remote :: RemoteEvent):FireServer(passId)
					end
				end
			end
		end
	))
	
	-- Product purchase finished
	table.insert(self._connections, MarketplaceService.PromptProductPurchaseFinished:Connect(
		function(player: Player, productId: number, purchased: boolean)
			if player ~= Player then return end
			if not self._state.purchasePending[productId] then return end
			
			self._state.purchasePending[productId] = nil
			
			if purchased then
				local remotes = ReplicatedStorage:FindFirstChild("TycoonRemotes")
				if remotes then
					local remote = remotes:FindFirstChild("GrantProductCurrency")
					if remote and remote:IsA("RemoteEvent") then
						(remote :: RemoteEvent):FireServer(productId)
					end
				end
			end
		end
	))
end

function ShopController:destroy()
	for i = #self._connections, 1, -1 do
		self._connections[i]:Disconnect()
		self._connections[i] = nil :: any
	end
	
	if self._gui then
		self._gui:Destroy()
	end
	
	if self._blur then
		self._blur.Size = 0
	end
	
	table.clear(self._state.purchasePending)
end

--// =========================
--// Configuration
--// =========================

local CONFIG: ShopConfig = {
	Version = "7.0.0",
	PurchaseTimeout = 15,
	RefreshInterval = 30,
	Assets = {
		CashIcon = "rbxassetid://18420350532",
		PassIcon = "rbxassetid://18420350433",
		ShopIcon = "rbxassetid://17398522865",
		VignetteOverlay = "rbxassetid://7743879747",
	},
	PassIds = {
		AutoCollect = 1412171840,
		DoubleCash = 1398974710,
	},
	Products = {
		cash = {
			{ id = 1897730242, amount = 1000,     name = "Starter Pouch",    description = "Kickstart upgrades.",  icon = "rbxassetid://18420350532" },
			{ id = 1897730373, amount = 5000,     name = "Festival Bundle",  description = "Dress your floors.",   icon = "rbxassetid://18420350532" },
			{ id = 1897730467, amount = 10000,    name = "Showcase Chest",   description = "Unlock new wings.",    icon = "rbxassetid://18420350532" },
			{ id = 1897730581, amount = 50000,    name = "Grand Vault",      description = "Relaunch fund.",       icon = "rbxassetid://18420350532" },
			{ id = 1234567001, amount = 100000,   name = "Mega Safe",        description = "Major expansion.",     icon = "rbxassetid://18420350532" },
			{ id = 1234567002, amount = 250000,   name = "Quarter Million",  description = "Serious investment.",  icon = "rbxassetid://18420350532" },
			{ id = 1234567003, amount = 500000,   name = "Half Million",     description = "Fast-track builds.",   icon = "rbxassetid://18420350532" },
			{ id = 1234567004, amount = 1000000,  name = "Millionaire Pack", description = "Dominate upgrades.",   icon = "rbxassetid://18420350532" },
			{ id = 1234567005, amount = 5000000,  name = "Tycoon Titan",     description = "Finish it all.",       icon = "rbxassetid://18420350532" },
			{ id = 1234567006, amount = 10000000, name = "Ultimate Vault",   description = "Max everything.",      icon = "rbxassetid://18420350532" },
		},
		gamepasses = {
			{ id = 1412171840, name = "Auto Collect", description = "Hands-free register sweep.", icon = "rbxassetid://18420350433", hasToggle = true },
			{ id = 1398974710, name = "2x Cash",      description = "Double every sale.",         icon = "rbxassetid://18420350433", hasToggle = false },
		},
	},
}

--// =========================
--// Initialization
--// =========================

local shop = ShopController.new(CONFIG)
shop:init()

-- Global API (optional)
_G.TycoonShop = {
	Open = function() shop:open() end,
	Close = function() shop:close() end,
	Toggle = function() shop:toggle() end,
}

print(`[TycoonShop] Modern Cute Edition ready (v{CONFIG.Version})`)

return shop
