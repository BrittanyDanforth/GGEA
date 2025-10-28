--[[
	WORKING MODERN CUTE TYCOON SHOP
	Place in: StarterPlayer > StarterPlayerScripts
	
	- Clean modern cute aesthetic (pastels, rounded corners)
	- Mobile-first responsive design
	- Cash packs + Game passes
	- Auto Collect toggle
	- Works with your existing remotes
	
	Controls:
	- M or ButtonX: Toggle
	- ESC: Close
]]

-- Services
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Config
local CONFIG = {
	Version = "6.0.0",
	Assets = {
		CashIcon = "rbxassetid://18420350532",
		PassIcon = "rbxassetid://18420350433",
		ShopIcon = "rbxassetid://17398522865",
		Vignette = "rbxassetid://7743879747",
	},
	PassIds = {
		AutoCollect = 1412171840,
		DoubleCash = 1398974710,
	},
	Products = {
		-- Use your actual product IDs here
		{ id = 1897730242, amount = 1000, name = "Starter Pouch", description = "Kickstart upgrades." },
		{ id = 1897730373, amount = 5000, name = "Festival Bundle", description = "Dress your floors." },
		{ id = 1897730467, amount = 10000, name = "Showcase Chest", description = "Unlock new wings." },
		{ id = 1897730581, amount = 50000, name = "Grand Vault", description = "Relaunch fund." },
	},
}

-- Theme
local Colors = {
	bg = Color3.fromRGB(250, 247, 245),
	surface = Color3.fromRGB(255, 255, 255),
	surfaceAlt = Color3.fromRGB(246, 242, 246),
	stroke = Color3.fromRGB(224, 214, 220),
	text = Color3.fromRGB(42, 38, 54),
	textMuted = Color3.fromRGB(116, 108, 132),
	mint = Color3.fromRGB(178, 224, 214),
	lavender = Color3.fromRGB(206, 196, 255),
	success = Color3.fromRGB(125, 194, 144),
}

-- State
local State = {
	isOpen = false,
	isAnimating = false,
	currentTab = "Cash",
	gui = nil,
	panel = nil,
	blur = nil,
}

-- Utils
local function tween(obj, props, duration)
	local info = TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(obj, info, props):Play()
end

local function formatNumber(num)
	local str = tostring(num)
	local k
	repeat
		str, k = str:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return str
end

local function applyCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = instance
	return corner
end

local function applyStroke(instance, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Colors.stroke
	stroke.Thickness = thickness or 1
	stroke.Transparency = 0.25
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

-- Create GUI
local function createShopGUI()
	-- Main ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "TycoonShopUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = PlayerGui
	
	-- Dim background
	local dim = Instance.new("ImageLabel")
	dim.Name = "Dim"
	dim.Image = CONFIG.Assets.Vignette
	dim.ImageTransparency = 0.25
	dim.ImageColor3 = Color3.new(0, 0, 0)
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundTransparency = 1
	dim.Parent = gui
	
	-- Main panel
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0.9, 0, 0.85, 0)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Colors.surface
	panel.BorderSizePixel = 0
	panel.Parent = gui
	applyCorner(panel, 20)
	applyStroke(panel, Colors.stroke)
	
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1.6
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = panel
	
	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 64)
	header.BackgroundColor3 = Colors.surfaceAlt
	header.BorderSizePixel = 0
	header.Parent = panel
	applyCorner(header, 20)
	
	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, 12)
	headerLayout.Parent = header
	
	local headerPad = Instance.new("UIPadding")
	headerPad.PaddingLeft = UDim.new(0, 16)
	headerPad.PaddingRight = UDim.new(0, 16)
	headerPad.Parent = header
	
	-- Shop icon
	local icon = Instance.new("ImageLabel")
	icon.Image = CONFIG.Assets.ShopIcon
	icon.Size = UDim2.fromOffset(36, 36)
	icon.BackgroundTransparency = 1
	icon.LayoutOrder = 1
	icon.Parent = header
	
	-- Title
	local title = Instance.new("TextLabel")
	title.Text = "Game Shop"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24
	title.TextColor3 = Colors.text
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Size = UDim2.new(1, -120, 1, 0)
	title.LayoutOrder = 2
	title.Parent = header
	
	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "✕"
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 20
	closeBtn.Size = UDim2.fromOffset(36, 36)
	closeBtn.BackgroundColor3 = Colors.surface
	closeBtn.TextColor3 = Colors.text
	closeBtn.AutoButtonColor = false
	closeBtn.LayoutOrder = 3
	closeBtn.Parent = header
	applyCorner(closeBtn, 18)
	
	-- Navigation
	local nav = Instance.new("Frame")
	nav.Name = "Nav"
	nav.Size = UDim2.new(0, 200, 1, -80)
	nav.Position = UDim2.fromOffset(16, 72)
	nav.BackgroundColor3 = Colors.surfaceAlt
	nav.BorderSizePixel = 0
	nav.Parent = panel
	applyCorner(nav, 16)
	applyStroke(nav, Colors.stroke)
	
	local navLayout = Instance.new("UIListLayout")
	navLayout.FillDirection = Enum.FillDirection.Vertical
	navLayout.Padding = UDim.new(0, 10)
	navLayout.Parent = nav
	
	local navPad = Instance.new("UIPadding")
	navPad.PaddingTop = UDim.new(0, 12)
	navPad.PaddingBottom = UDim.new(0, 12)
	navPad.PaddingLeft = UDim.new(0, 12)
	navPad.PaddingRight = UDim.new(0, 12)
	navPad.Parent = nav
	
	-- Content area
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -232, 1, -96)
	content.Position = UDim2.fromOffset(216, 80)
	content.Parent = panel
	
	-- Cash page
	local cashPage = Instance.new("Frame")
	cashPage.Name = "CashPage"
	cashPage.BackgroundTransparency = 1
	cashPage.Size = UDim2.fromScale(1, 1)
	cashPage.Visible = true
	cashPage.Parent = content
	
	-- Cash header
	local cashHeader = Instance.new("Frame")
	cashHeader.Size = UDim2.new(1, 0, 0, 44)
	cashHeader.BackgroundColor3 = Colors.surfaceAlt
	cashHeader.BorderSizePixel = 0
	cashHeader.Parent = cashPage
	applyCorner(cashHeader, 10)
	
	local cashHeaderPad = Instance.new("UIPadding")
	cashHeaderPad.PaddingLeft = UDim.new(0, 12)
	cashHeaderPad.Parent = cashHeader
	
	local cashTitle = Instance.new("TextLabel")
	cashTitle.Text = "Cash Packs"
	cashTitle.Font = Enum.Font.GothamBold
	cashTitle.TextSize = 20
	cashTitle.TextColor3 = Colors.text
	cashTitle.BackgroundTransparency = 1
	cashTitle.TextXAlignment = Enum.TextXAlignment.Left
	cashTitle.Size = UDim2.new(1, 0, 1, 0)
	cashTitle.Parent = cashHeader
	
	-- Scroll for cash products
	local cashScroll = Instance.new("ScrollingFrame")
	cashScroll.BackgroundTransparency = 1
	cashScroll.BorderSizePixel = 0
	cashScroll.ScrollBarThickness = 6
	cashScroll.ScrollBarImageColor3 = Colors.stroke
	cashScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	cashScroll.CanvasSize = UDim2.new()
	cashScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	cashScroll.Size = UDim2.new(1, 0, 1, -56)
	cashScroll.Position = UDim2.fromOffset(0, 52)
	cashScroll.Parent = cashPage
	
	local cashGrid = Instance.new("UIGridLayout")
	cashGrid.SortOrder = Enum.SortOrder.LayoutOrder
	cashGrid.CellPadding = UDim2.fromOffset(16, 16)
	cashGrid.FillDirection = Enum.FillDirection.Horizontal
	cashGrid.FillDirectionMaxCells = 3
	cashGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cashGrid.Parent = cashScroll
	
	-- Gamepasses page
	local passPage = Instance.new("Frame")
	passPage.Name = "PassPage"
	passPage.BackgroundTransparency = 1
	passPage.Size = UDim2.fromScale(1, 1)
	passPage.Visible = false
	passPage.Parent = content
	
	-- Pass header
	local passHeader = Instance.new("Frame")
	passHeader.Size = UDim2.new(1, 0, 0, 44)
	passHeader.BackgroundColor3 = Colors.surfaceAlt
	passHeader.BorderSizePixel = 0
	passHeader.Parent = passPage
	applyCorner(passHeader, 10)
	
	local passHeaderPad = Instance.new("UIPadding")
	passHeaderPad.PaddingLeft = UDim.new(0, 12)
	passHeaderPad.Parent = passHeader
	
	local passTitle = Instance.new("TextLabel")
	passTitle.Text = "Game Passes"
	passTitle.Font = Enum.Font.GothamBold
	passTitle.TextSize = 20
	passTitle.TextColor3 = Colors.text
	passTitle.BackgroundTransparency = 1
	passTitle.TextXAlignment = Enum.TextXAlignment.Left
	passTitle.Size = UDim2.new(1, 0, 1, 0)
	passTitle.Parent = passHeader
	
	-- Scroll for gamepasses
	local passScroll = Instance.new("ScrollingFrame")
	passScroll.BackgroundTransparency = 1
	passScroll.BorderSizePixel = 0
	passScroll.ScrollBarThickness = 6
	passScroll.ScrollBarImageColor3 = Colors.stroke
	passScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	passScroll.CanvasSize = UDim2.new()
	passScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	passScroll.Size = UDim2.new(1, 0, 1, -56)
	passScroll.Position = UDim2.fromOffset(0, 52)
	passScroll.Parent = passPage
	
	local passGrid = Instance.new("UIGridLayout")
	passGrid.SortOrder = Enum.SortOrder.LayoutOrder
	passGrid.CellPadding = UDim2.fromOffset(16, 16)
	passGrid.FillDirection = Enum.FillDirection.Horizontal
	passGrid.FillDirectionMaxCells = 3
	passGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	passGrid.Parent = passScroll
	
	-- Blur effect
	local blur = Lighting:FindFirstChild("ShopBlur")
	if not blur then
		blur = Instance.new("BlurEffect")
		blur.Name = "ShopBlur"
		blur.Size = 0
		blur.Parent = Lighting
	end
	
	State.gui = gui
	State.panel = panel
	State.blur = blur
	
	return {
		gui = gui,
		panel = panel,
		blur = blur,
		closeBtn = closeBtn,
		nav = nav,
		cashPage = cashPage,
		cashScroll = cashScroll,
		passPage = passPage,
		passScroll = passScroll,
	}
end

-- Open/Close
local function openShop()
	if State.isOpen or State.isAnimating then return end
	State.isAnimating = true
	State.isOpen = true
	
	if State.gui then
		State.gui.Enabled = true
	end
	if State.blur then
		tween(State.blur, {Size = 28}, 0.22)
	end
	if State.panel then
		State.panel.Position = UDim2.fromScale(0.5, 0.52)
		tween(State.panel, {Position = UDim2.fromScale(0.5, 0.5)}, 0.35)
	end
	
	task.delay(0.35, function()
		State.isAnimating = false
	end)
end

local function closeShop()
	if not State.isOpen or State.isAnimating then return end
	State.isAnimating = true
	State.isOpen = false
	
	if State.blur then
		tween(State.blur, {Size = 0}, 0.12)
	end
	if State.panel then
		tween(State.panel, {Position = UDim2.fromScale(0.5, 0.52)}, 0.12)
	end
	
	task.delay(0.12, function()
		if State.gui then
			State.gui.Enabled = false
		end
		State.isAnimating = false
	end)
end

local function toggleShop()
	if State.isOpen then
		closeShop()
	else
		openShop()
	end
end

-- Create product cards
local function createProductCard(parent, product, order)
	local card = Instance.new("Frame")
	card.Name = product.name .. "Card"
	card.Size = UDim2.new(1, 0, 0, 0)
	card.BackgroundColor3 = Colors.surface
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.Parent = parent
	applyCorner(card, 14)
	applyStroke(card, Colors.mint)
	
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1.55
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = card
	
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.new(1, -24, 1, -24)
	inner.Position = UDim2.fromOffset(12, 12)
	inner.Parent = card
	
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 8)
	layout.Parent = inner
	
	-- Icon + Name row
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 40)
	row.Parent = inner
	
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.Parent = row
	
	local icon = Instance.new("ImageLabel")
	icon.Image = CONFIG.Assets.CashIcon
	icon.Size = UDim2.fromOffset(36, 36)
	icon.BackgroundTransparency = 1
	icon.Parent = row
	
	local name = Instance.new("TextLabel")
	name.Text = product.name
	name.Font = Enum.Font.GothamBold
	name.TextSize = 20
	name.TextColor3 = Colors.text
	name.BackgroundTransparency = 1
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Size = UDim2.new(1, -44, 1, 0)
	name.Parent = row
	
	-- Description
	local desc = Instance.new("TextLabel")
	desc.Text = product.description
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 16
	desc.TextColor3 = Colors.textMuted
	desc.BackgroundTransparency = 1
	desc.TextWrapped = true
	desc.Size = UDim2.new(1, 0, 0, 36)
	desc.Parent = inner
	
	-- Price
	local price = Instance.new("TextLabel")
	price.Text = string.format("R$0  •  %s Cash", formatNumber(product.amount))
	price.Font = Enum.Font.GothamMedium
	price.TextSize = 18
	price.TextColor3 = Colors.mint
	price.BackgroundTransparency = 1
	price.Size = UDim2.new(1, 0, 0, 24)
	price.Parent = inner
	
	-- Buy button
	local buyBtn = Instance.new("TextButton")
	buyBtn.Text = "Purchase"
	buyBtn.Font = Enum.Font.GothamBold
	buyBtn.TextSize = 18
	buyBtn.TextColor3 = Color3.new(1, 1, 1)
	buyBtn.BackgroundColor3 = Colors.mint
	buyBtn.Size = UDim2.new(1, 0, 0, 40)
	buyBtn.AutoButtonColor = false
	buyBtn.Parent = inner
	applyCorner(buyBtn, 10)
	
	buyBtn.MouseButton1Click:Connect(function()
		pcall(function()
			MarketplaceService:PromptProductPurchase(Player, product.id)
		end)
	end)
	
	-- Hover effect
	card.MouseEnter:Connect(function()
		tween(card, {BackgroundColor3 = Colors.surfaceAlt}, 0.12)
	end)
	card.MouseLeave:Connect(function()
		tween(card, {BackgroundColor3 = Colors.surface}, 0.12)
	end)
	
	-- Load price
	task.spawn(function()
		local success, info = pcall(function()
			return MarketplaceService:GetProductInfo(product.id, Enum.InfoType.Product)
		end)
		if success and info then
			price.Text = string.format("R$%d  •  %s Cash", info.PriceInRobux or 0, formatNumber(product.amount))
		end
	end)
end

-- Create gamepass cards
local function createGamepassCard(parent, passId, passName, passDesc, order)
	local card = Instance.new("Frame")
	card.Name = passName .. "Card"
	card.Size = UDim2.new(1, 0, 0, 0)
	card.BackgroundColor3 = Colors.surface
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.Parent = parent
	applyCorner(card, 14)
	applyStroke(card, Colors.lavender)
	
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1.55
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = card
	
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.new(1, -24, 1, -24)
	inner.Position = UDim2.fromOffset(12, 12)
	inner.Parent = card
	
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 8)
	layout.Parent = inner
	
	-- Icon + Name row
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 40)
	row.Parent = inner
	
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.Parent = row
	
	local icon = Instance.new("ImageLabel")
	icon.Image = CONFIG.Assets.PassIcon
	icon.Size = UDim2.fromOffset(36, 36)
	icon.BackgroundTransparency = 1
	icon.Parent = row
	
	local name = Instance.new("TextLabel")
	name.Text = passName
	name.Font = Enum.Font.GothamBold
	name.TextSize = 20
	name.TextColor3 = Colors.text
	name.BackgroundTransparency = 1
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Size = UDim2.new(1, -44, 1, 0)
	name.Parent = row
	
	-- Description
	local desc = Instance.new("TextLabel")
	desc.Text = passDesc
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 16
	desc.TextColor3 = Colors.textMuted
	desc.BackgroundTransparency = 1
	desc.TextWrapped = true
	desc.Size = UDim2.new(1, 0, 0, 36)
	desc.Parent = inner
	
	-- Price
	local price = Instance.new("TextLabel")
	price.Text = "R$0"
	price.Font = Enum.Font.GothamMedium
	price.TextSize = 18
	price.TextColor3 = Colors.lavender
	price.BackgroundTransparency = 1
	price.Size = UDim2.new(1, 0, 0, 24)
	price.Parent = inner
	
	-- Buy button
	local buyBtn = Instance.new("TextButton")
	buyBtn.Text = "Purchase"
	buyBtn.Font = Enum.Font.GothamBold
	buyBtn.TextSize = 18
	buyBtn.TextColor3 = Color3.new(1, 1, 1)
	buyBtn.BackgroundColor3 = Colors.lavender
	buyBtn.Size = UDim2.new(1, 0, 0, 40)
	buyBtn.AutoButtonColor = false
	buyBtn.Parent = inner
	applyCorner(buyBtn, 10)
	
	buyBtn.MouseButton1Click:Connect(function()
		pcall(function()
			MarketplaceService:PromptGamePassPurchase(Player, passId)
		end)
	end)
	
	-- Check ownership
	task.spawn(function()
		local success, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, passId)
		end)
		if success and owns then
			buyBtn.Text = "Owned"
			buyBtn.BackgroundColor3 = Colors.success
			buyBtn.Active = false
		end
	end)
	
	-- Load price
	task.spawn(function()
		local success, info = pcall(function()
			return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
		end)
		if success and info then
			price.Text = string.format("R$%d", info.PriceInRobux or 0)
		end
	end)
	
	-- Hover effect
	card.MouseEnter:Connect(function()
		tween(card, {BackgroundColor3 = Colors.surfaceAlt}, 0.12)
	end)
	card.MouseLeave:Connect(function()
		tween(card, {BackgroundColor3 = Colors.surface}, 0.12)
	end)
end

-- Initialize
local ui = createShopGUI()

-- Create nav tabs
local function createTab(name, accent, onClick)
	local btn = Instance.new("TextButton")
	btn.Text = name
	btn.Size = UDim2.new(1, 0, 0, 46)
	btn.BackgroundColor3 = Colors.surface
	btn.TextColor3 = Colors.text
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 18
	btn.AutoButtonColor = false
	btn.Parent = ui.nav
	applyCorner(btn, 10)
	
	btn.MouseButton1Click:Connect(onClick)
	
	btn.MouseEnter:Connect(function()
		tween(btn, {BackgroundColor3 = accent, TextColor3 = Color3.new(1, 1, 1)}, 0.1)
	end)
	
	btn.MouseLeave:Connect(function()
		local active = (name == "Cash Packs" and ui.cashPage.Visible) or (name == "Game Passes" and ui.passPage.Visible)
		tween(btn, {
			BackgroundColor3 = active and accent or Colors.surface,
			TextColor3 = active and Color3.new(1, 1, 1) or Colors.text
		}, 0.1)
	end)
	
	return btn
end

createTab("Cash Packs", Colors.mint, function()
	ui.cashPage.Visible = true
	ui.passPage.Visible = false
end)

createTab("Game Passes", Colors.lavender, function()
	ui.cashPage.Visible = false
	ui.passPage.Visible = true
end)

-- Populate products
for i, product in ipairs(CONFIG.Products) do
	createProductCard(ui.cashScroll, product, i)
end

-- Populate gamepasses
createGamepassCard(ui.passScroll, CONFIG.PassIds.AutoCollect, "Auto Collect", "Hands-free register sweep.", 1)
createGamepassCard(ui.passScroll, CONFIG.PassIds.DoubleCash, "2x Cash", "Double every sale.", 2)

-- Close button
ui.closeBtn.MouseButton1Click:Connect(closeShop)

-- Input handling
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	
	if input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.ButtonX then
		toggleShop()
	elseif input.KeyCode == Enum.KeyCode.Escape and State.isOpen then
		closeShop()
	end
end)

-- Toggle button
local toggleGui = Instance.new("ScreenGui")
toggleGui.Name = "ShopToggle"
toggleGui.ResetOnSpawn = false
toggleGui.DisplayOrder = 999
toggleGui.Parent = PlayerGui

local pill = Instance.new("TextButton")
pill.Text = "Shop"
pill.Font = Enum.Font.GothamBold
pill.TextSize = 20
pill.Size = UDim2.fromOffset(156, 56)
pill.Position = UDim2.new(1, -20, 1, -20)
pill.AnchorPoint = Vector2.new(1, 1)
pill.BackgroundColor3 = Colors.surface
pill.TextColor3 = Colors.text
pill.AutoButtonColor = false
pill.Parent = toggleGui
applyCorner(pill, 28)

pill.MouseButton1Click:Connect(toggleShop)

pill.MouseEnter:Connect(function()
	tween(pill, {BackgroundColor3 = Colors.mint, TextColor3 = Color3.new(1, 1, 1)}, 0.1)
end)

pill.MouseLeave:Connect(function()
	tween(pill, {BackgroundColor3 = Colors.surface, TextColor3 = Colors.text}, 0.1)
end)

print("[TycoonShop] Working Modern Cute Edition ready (v" .. CONFIG.Version .. ")")
