--[[
    SANRIO SHOP CLIENT (FIXED VERSION)
    Place in: StarterPlayer > StarterPlayerScripts
    Name: CREATEMONEYSHOP
    
    Features:
    • Mobile-first design with responsive layout
    • Cash products and Gamepasses
    • Auto Collect with ON/OFF toggle
    • Server-verified purchase updates (no flickering!)
    • No confetti effect
    
    FIXED: Gamepasses now show "OWNED" and toggle properly after purchase
]]

-- Services
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:FindFirstChild("TycoonRemotes")

-- ======== ASSETS ========
local IMG_FRAME      = "rbxassetid://83301831904885"
local IMG_GAMEPASSES = "rbxassetid://137846629770171"
local IMG_CASH       = "rbxassetid://84262748186110"
local GIFT_BOX_TEXTURE_ID = "130623477775352"

-- ======== LAYOUT ========
local FRAME_SCALE = 0.92
local FRAME_SCALE_MOBILE = 0.94

local TAB_ROW_Y = 0.365
local GP_ROW_EXTRA = 0.015

local BAR_WIDTH_FACTOR = 0.95
local CONTENT_WIDTH_FACTOR = 0.82
local CONTENT_HEIGHT_FACTOR = 0.46

local CASH_H_FACTOR_DESKTOP, GP_H_FACTOR_DESKTOP = 0.095, 0.090
local CASH_H_FACTOR_PHONE,   GP_H_FACTOR_PHONE   = 0.018, 0.02325
local PILL_MIN_H, PILL_MAX_H = 33, 140
local CASH_RATIO, GP_RATIO    = 3.25, 4.20
local PILL_BAR_PAD            = 10

local PILL_IMG_PAD_X = 8
local PILL_IMG_PAD_Y = 6

local GRID_X_SCALE = 0.40
local CARD_AR = 1.90
local CARD_MIN_H = 150
local CARD_MAX_H = 220
local CARD_INSET = 8
local TITLE_H = 26
local DESC_H  = 28
local BTN_H   = 30
local CELL_PAD_X = 8
local SECOND_ROW_GAP = 8

local TWO_ROW_BOTTOM_PUSH_PX    = 37
local SINGLE_ROW_BOTTOM_PUSH_PX = 0

-- ======== UTILS ========
local function isMobile() return UserInputService.TouchEnabled and not GuiService:IsTenFootInterface() end
local function isPhone()
	if not isMobile() then return false end
	local v = workspace.CurrentCamera.ViewportSize
	return math.min(v.X, v.Y) < 700
end

-- ======== THEME ========
local theme = {
	accent      = Color3.fromRGB(255,80,140),
	success     = Color3.fromRGB(76,175,80),
	cinna       = Color3.fromRGB(186,214,255),
	kuromi      = Color3.fromRGB(200,190,255),
	cardTop     = Color3.fromRGB(248,243,255),
	cardBot     = Color3.fromRGB(231,220,255),
	cardInner   = Color3.fromRGB(243,235,255),
	cardStroke  = Color3.fromRGB(206,190,248),
	shadow      = Color3.fromRGB(50, 30, 90),
	textDark    = Color3.fromRGB(62, 36, 96),
	textSubtle  = Color3.fromRGB(84, 60, 122),
}

-- ======== CACHE ========
local Cache = {}; Cache.__index = Cache
function Cache.new(d) return setmetatable({data={},duration=d or 300}, Cache) end
function Cache:set(k,v) self.data[k]={v=v,t=tick()} end
function Cache:get(k) local e=self.data[k]; if not e then return end; if tick()-e.t>self.duration then self.data[k]=nil return end; return e.v end
function Cache:clear(k) if k then self.data[k]=nil else self.data={} end end
local productCache = Cache.new(300)
local ownershipCache = Cache.new(60)

-- ======== DATA ========
local products = {
	cash = {
		{ id = 3366419712, amount = 1000,    name = "1,000 Cash",     description = "Perfect starter pack",           icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3366420012, amount = 5000,    name = "5,000 Cash",     description = "Great for early upgrades",       icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3366420478, amount = 10000,   name = "10,000 Cash",    description = "Boost your progress fast",       icon = "rbxassetid://10709728059", price = 0, bonus = 0.10 },
		{ id = 3366420800, amount = 25000,   name = "25,000 Cash",    description = "Popular choice for players",     icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3424973374, amount = 50000,   name = "50,000 Cash",    description = "Major upgrade power",            icon = "rbxassetid://10709728059", price = 0, bonus = 0.25 },
		{ id = 3424974046, amount = 100000,  name = "100,000 Cash",   description = "Supercharge your tycoon",        icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3424974161, amount = 250000,  name = "250,000 Cash",   description = "Mega bundle for big dreams",     icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3424974327, amount = 500000,  name = "500,000 Cash",   description = "Ultimate fortune awaits",        icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3424974402, amount = 1000000, name = "1,000,000 Cash", description = "Max out everything!",            icon = "rbxassetid://10709728059", price = 0, best = true, bonus = 0.35 },
	},
	gamepasses = {
		{ id = 1412171840, name = "Auto Collect", description = "Automatically collect all cash drops", icon = "rbxassetid://10709727148", price = 99,  hasToggle = true  },
		{ id = 1398974710, name = "2x Cash",      description = "Double all cash earned permanently",   icon = "rbxassetid://10709727148", price = 199, hasToggle = false },
	},
}

local function getProductInfo(id)
	local c=productCache:get(id); if c then return c end
	local ok,info=pcall(function() return MarketplaceService:GetProductInfo(id,Enum.InfoType.Product) end)
	if ok and info then productCache:set(id,info) return info end
end
local function getGamePassInfo(id)
	local key="pass_"..id; local c=productCache:get(key); if c then return c end
	local ok,info=pcall(function() return MarketplaceService:GetProductInfo(id,Enum.InfoType.GamePass) end)
	if ok and info then productCache:set(key,info) return info end
end
local function checkOwnership(passId)
	local key = ("%d_%d"):format(Player.UserId, passId)
	local c = ownershipCache:get(key)
	if c ~= nil then return c end

	-- ✅ Ask server first (authoritative - never stale!)
	if Remotes then
		local rf = Remotes:FindFirstChild("CheckPassOwnership")
		if rf and rf:IsA("RemoteFunction") then
			local ok, owns = pcall(function() return rf:InvokeServer(passId) end)
			if ok then
				ownershipCache:set(key, owns)
				print("🔍 [CREATEMONEYSHOP] checkOwnership (server) -", passId, "owns:", owns)
				return owns
			end
		end
	end

	-- Fallback: local API (can be stale in Studio right after purchase)
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, passId)
	end)
	if ok then
		ownershipCache:set(key, owns)
		print("🔍 [CREATEMONEYSHOP] checkOwnership (fallback) -", passId, "owns:", owns)
		return owns
	end
	return false
end
local function refreshPrices()
	for _,p in ipairs(products.cash) do local i=getProductInfo(p.id); if i and i.PriceInRobux then p.price=i.PriceInRobux end end
	for _,gp in ipairs(products.gamepasses) do local i=getGamePassInfo(gp.id); if i and i.PriceInRobux then gp.price=i.PriceInRobux end end
end

-- ======== SOUND ========
local sounds = {}
local function initSound()
	local cfg={click={"rbxassetid://876939830",0.45},hover={"rbxassetid://10066936758",0.2},open={"rbxassetid://452267918",0.5},success={"rbxassetid://876939830",0.6}}
	for n,d in pairs(cfg) do local s=Instance.new("Sound"); s.Name="SS_"..n; s.SoundId=d[1]; s.Volume=d[2]; s.Parent=SoundService; sounds[n]=s end
end
local function playSound(n) if sounds[n] then sounds[n]:Play() end end

-- ======== FX ========
local function pulse(frame)
	local s=frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale"); s.Parent=frame
	TweenService:Create(s,TweenInfo.new(0.1),{Scale=1.06}):Play()
	task.delay(0.1,function() TweenService:Create(s,TweenInfo.new(0.18),{Scale=1}):Play() end)
end

-- ======== CARD BUILDER ========
local function buildCard(parent, product, reservedRows)
	reservedRows = reservedRows or 1
	local reservedPx = (reservedRows * BTN_H) + math.max(0, reservedRows-1) * SECOND_ROW_GAP + 8 + (2 * CARD_INSET)

	local shadow = Instance.new("Frame")
	shadow.BackgroundColor3 = theme.shadow; shadow.BackgroundTransparency = 0.88
	shadow.Size = UDim2.new(1, -2*CARD_INSET, 1, -reservedPx)
	shadow.Position = UDim2.fromOffset(CARD_INSET, CARD_INSET + 4)
	shadow.BorderSizePixel = 0; shadow.Parent = parent; shadow.ZIndex = 11
	local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 14); sc.Parent = shadow

	local card = Instance.new("Frame")
	card.BackgroundColor3 = theme.cardBot
	card.Size = UDim2.new(1, -2*CARD_INSET, 1, -reservedPx)
	card.Position = UDim2.fromOffset(CARD_INSET, CARD_INSET)
	card.BorderSizePixel = 0; card.Parent = parent; card.ZIndex = 12
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 14); corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = theme.cardStroke; stroke.Thickness = 2; stroke.Transparency = 0.15
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; stroke.Parent = card

	local g = Instance.new("UIGradient"); g.Rotation = 90
	g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, theme.cardTop), ColorSequenceKeypoint.new(1, theme.cardBot)})
	g.Parent = card

	local inner = Instance.new("Frame")
	inner.BackgroundColor3 = theme.cardInner
	inner.Size = UDim2.new(1, -8, 1, -8)
	inner.Position = UDim2.fromOffset(4, 4)
	inner.BorderSizePixel = 0; inner.Parent = card; inner.ZIndex = 13
	local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(0, 12); ic.Parent = inner
	local is = Instance.new("UIStroke"); is.Color = Color3.new(1,1,1); is.Transparency = 0.7; is.Thickness = 1; is.Parent = inner
	local ig = Instance.new("UIGradient"); ig.Rotation = 90
	ig.Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromRGB(245,240,255)); ig.Parent = inner

	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -10, 1, -10)
	content.Position = UDim2.fromOffset(5, 5)
	content.Parent = inner; content.ZIndex = 14

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, TITLE_H)
	title.Text = product.name
	title.Font = Enum.Font.FredokaOne
	title.TextColor3 = theme.textDark
	title.TextStrokeColor3 = Color3.fromRGB(255,255,255)
	title.TextStrokeTransparency = 0.85
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextScaled = true; title.ZIndex = 15; title.Parent = content
	local tsc = Instance.new("UITextSizeConstraint")
	tsc.MinTextSize = 11; tsc.MaxTextSize = 20; tsc.Parent = title

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Size = UDim2.new(1, 0, 0, DESC_H)
	desc.Text = product.description or ""
	desc.Font = Enum.Font.FredokaOne
	desc.TextColor3 = theme.textSubtle
	desc.TextStrokeColor3 = Color3.fromRGB(255,255,255)
	desc.TextStrokeTransparency = 0.9
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextWrapped = true; desc.TextScaled = true; desc.LineHeight = 1.0
	desc.ZIndex = 15; desc.Parent = content
	local dsc = Instance.new("UITextSizeConstraint")
	dsc.MinTextSize = 10; dsc.MaxTextSize = 15; dsc.Parent = desc

	local filler = Instance.new("Frame")
	filler.BackgroundTransparency = 1
	filler.Size = UDim2.new(1, 0, 1, -(TITLE_H + DESC_H + 6))
	filler.ZIndex = 14; filler.Parent = content

	return card
end

-- ======== SHOP CLASS ========
local Shop = {}; Shop.__index = Shop
function Shop.new()
	return setmetatable({
		gui=nil, mainFrame=nil, buttonBar=nil, cashContainer=nil, gpContainer=nil, cashBtn=nil, gpBtn=nil,
		contentFrame=nil, cashPage=nil, gpPage=nil, toggleButton=nil, blur=nil, isOpen=false, purchasePending={},
		_cashHL=nil, _gpHL=nil, _cashScale=nil, _gpScale=nil
	}, Shop)
end

function Shop:initialize()
	initSound()
	refreshPrices()
	self:createToggleButton()
	self:createMainInterface()
	self:setupHandlers()
end

function Shop:createToggleButton()
	local sg = Instance.new("ScreenGui")
	sg.Name = "SanrioShopToggle"; sg.ResetOnSpawn = false; sg.DisplayOrder = 999
	sg.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets; sg.Parent = PlayerGui

	local size = isPhone() and UDim2.fromOffset(70,70) or UDim2.fromOffset(90,90)
	local pos = isPhone() and UDim2.new(1,-16,0,76) or UDim2.new(1,-16,0.5,-70)
	local anchor = isPhone() and Vector2.new(1,0) or Vector2.new(1,0.5)

	self.toggleButton = Instance.new("TextButton")
	self.toggleButton.Size = size; self.toggleButton.Position = pos; self.toggleButton.AnchorPoint = anchor
	self.toggleButton.BackgroundColor3 = Color3.fromRGB(255,255,255); self.toggleButton.Text = ""
	self.toggleButton.AutoButtonColor = false; self.toggleButton.Parent = sg
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,16); corner.Parent = self.toggleButton
	local stroke = Instance.new("UIStroke"); stroke.Color = theme.accent; stroke.Thickness = 2; stroke.Parent = self.toggleButton

	local giftSize = isPhone() and 56 or 72
	local img = Instance.new("ImageLabel")
	img.Image = "rbxassetid://" .. GIFT_BOX_TEXTURE_ID; img.Size = UDim2.fromOffset(giftSize, giftSize)
	img.Position = UDim2.fromScale(0.5, 0.5); img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.BackgroundTransparency = 1; img.Parent = self.toggleButton
	self.toggleButton.MouseButton1Click:Connect(function() self:toggle() end)
end

function Shop:makePill(name, imageId, ratio)
	local container = Instance.new("Frame")
	container.Name = name .. "Container"; container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Size = UDim2.fromOffset(260, 86)
	container.ZIndex = 9; container.ClipsDescendants = false
	container.Parent = self.buttonBar
	local ar = Instance.new("UIAspectRatioConstraint"); ar.AspectRatio = ratio; ar.DominantAxis = Enum.DominantAxis.Width; ar.Parent = container

	local inner = Instance.new("Frame")
	inner.Name = name .. "Inner"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.new(1, -2*PILL_IMG_PAD_X, 1, -2*PILL_IMG_PAD_Y)
	inner.BackgroundTransparency = 1; inner.ZIndex = 9; inner.Parent = container

	local btn = Instance.new("ImageButton")
	btn.Name = name .. "Button"; btn.BackgroundTransparency = 1; btn.AutoButtonColor = false
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = UDim2.fromScale(0.5, 0.5)
	btn.Size = UDim2.fromScale(1, 2)
	btn.Image = imageId
	btn.ScaleType = Enum.ScaleType.Crop
	btn.ZIndex = 9; btn.Parent = inner

	local scl = Instance.new("UIScale"); scl.Scale = 1; scl.Parent = container

	local function bump(mult)
		local sx, sy = math.floor(container.Size.X.Offset * mult), math.floor(container.Size.Y.Offset * mult)
		TweenService:Create(container, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(sx, sy)}):Play()
	end
	btn.MouseEnter:Connect(function() playSound("hover"); bump(1.02) end)
	btn.MouseLeave:Connect(function() bump(1.00) end)
	btn.MouseButton1Down:Connect(function() bump(0.98) end)
	btn.MouseButton1Up:Connect(function() bump(1.02) end)

	return container, btn, scl
end

function Shop:updateTabSelection(which)
	local cOn = (which == "cash")
	if self._cashScale then TweenService:Create(self._cashScale, TweenInfo.new(0.12), {Scale = cOn and 1.03 or 1.0}):Play() end
	if self._gpScale   then TweenService:Create(self._gpScale,   TweenInfo.new(0.12), {Scale = cOn and 1.0  or 1.03}):Play() end
end

function Shop:createMainInterface()
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "SanrioShopMain"; self.gui.ResetOnSpawn = false; self.gui.DisplayOrder = 1000
	self.gui.Enabled = false
	self.gui.IgnoreGuiInset = false
	self.gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	self.gui.Parent = PlayerGui

	self.blur = Lighting:FindFirstChild("SanrioShopBlur") or Instance.new("BlurEffect")
	self.blur.Name = "SanrioShopBlur"; self.blur.Size = 0; self.blur.Parent = Lighting

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1); dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.38; dim.BorderSizePixel = 0; dim.Parent = self.gui

	self.mainFrame = Instance.new("ImageLabel")
	self.mainFrame.Name = "MainFrame"; self.mainFrame.BackgroundTransparency = 1
	self.mainFrame.AnchorPoint = Vector2.new(0.5, 0.5); self.mainFrame.Position = UDim2.fromScale(0.5, 0.5)
	local scale = isPhone() and FRAME_SCALE_MOBILE or FRAME_SCALE
	self.mainFrame.Size = UDim2.fromScale(scale, scale)
	self.mainFrame.Image = IMG_FRAME; self.mainFrame.ScaleType = Enum.ScaleType.Fit
	self.mainFrame.ZIndex = 1; self.mainFrame.Parent = self.gui
	local aspect = Instance.new("UIAspectRatioConstraint"); aspect.AspectRatio = 1; aspect.Parent = self.mainFrame

	self.buttonBar = Instance.new("Frame")
	self.buttonBar.Name = "ButtonBar"; self.buttonBar.BackgroundTransparency = 1
	self.buttonBar.AnchorPoint = Vector2.new(0.5, 0); self.buttonBar.Position = UDim2.fromScale(0.5, TAB_ROW_Y)
	self.buttonBar.Size = UDim2.fromScale(BAR_WIDTH_FACTOR, 0)
	self.buttonBar.ZIndex = 8; self.buttonBar.ClipsDescendants = false
	self.buttonBar.Parent = self.mainFrame
	local barPad = Instance.new("UIPadding")
	barPad.PaddingTop = UDim.new(0, PILL_BAR_PAD)
	barPad.PaddingBottom = UDim.new(0, PILL_BAR_PAD)
	barPad.Parent = self.buttonBar

	self.cashContainer, self.cashBtn, self._cashScale = self:makePill("Cash", IMG_CASH, CASH_RATIO)
	self.gpContainer,   self.gpBtn,   self._gpScale   = self:makePill("Gamepasses", IMG_GAMEPASSES, GP_RATIO)

	self.contentFrame = Instance.new("Frame")
	self.contentFrame.Name = "Content"; self.contentFrame.AnchorPoint = Vector2.new(0.5, 0)
	self.contentFrame.Position = UDim2.fromScale(0.5, 0.44)
	self.contentFrame.Size = UDim2.fromScale(CONTENT_WIDTH_FACTOR, CONTENT_HEIGHT_FACTOR)
	self.contentFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
	self.contentFrame.BackgroundTransparency = 0.88
	self.contentFrame.ZIndex = 5; self.contentFrame.Parent = self.mainFrame
	local contentCorner = Instance.new("UICorner"); contentCorner.CornerRadius = UDim.new(0, 20); contentCorner.Parent = self.contentFrame

	self:createPages()
	self:setupDynamicSizing()

	local function selectCash()
		self:showCash()
		self:updateTabSelection("cash")
		playSound("click")
	end
	local function selectGP()
		self:showGamepasses()
		self:updateTabSelection("gp")
		playSound("click")
		pulse(self.gpContainer)
	end

	self.cashBtn.MouseButton1Click:Connect(selectCash)
	self.cashBtn.Activated:Connect(selectCash)
	self.gpBtn.MouseButton1Click:Connect(selectGP)
	self.gpBtn.Activated:Connect(selectGP)

	self:updateTabSelection("cash")
end

local function bindGridAspect(self, grid, bottom_rows)
	bottom_rows = bottom_rows or 1
	local function recalc()
		local pad = grid.Parent:FindFirstChildWhichIsA("UIPadding")
		local left  = pad and pad.PaddingLeft.Offset  or 0
		local right = pad and pad.PaddingRight.Offset or 0
		local usable = math.max(0, grid.Parent.AbsoluteSize.X - (left + right))
		if usable <= 0 then return end

		local wScale = GRID_X_SCALE
		local cellW  = math.floor(usable * wScale)
		local rawH   = math.floor(cellW / CARD_AR)
		local baseH  = math.clamp(rawH, CARD_MIN_H, CARD_MAX_H)

		local extra = math.max(0, bottom_rows - 1) * (BTN_H + SECOND_ROW_GAP)
		local cellH = baseH + extra

		grid.CellSize = UDim2.new(wScale, 0, 0, cellH)
	end
	grid.Parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(recalc)
	self.contentFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(recalc)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(recalc)
	RunService.Heartbeat:Connect(recalc)
	task.defer(recalc)
end

function Shop:createPages()
	-- CASH
	self.cashPage = Instance.new("ScrollingFrame")
	self.cashPage.Name = "CashPage"; self.cashPage.BackgroundTransparency = 1
	self.cashPage.ScrollBarThickness = 6; self.cashPage.ScrollBarImageColor3 = theme.accent
	self.cashPage.Visible = true; self.cashPage.Size = UDim2.fromScale(1, 1); self.cashPage.ZIndex = 5
	self.cashPage.Parent = self.contentFrame

	local cashPad = Instance.new("UIPadding")
	cashPad.PaddingTop = UDim.new(0, 6); cashPad.PaddingBottom = UDim.new(0, 8)
	cashPad.PaddingLeft = UDim.new(0, 6); cashPad.PaddingRight = UDim.new(0, 6); cashPad.Parent = self.cashPage

	local cashGrid = Instance.new("UIGridLayout")
	cashGrid.CellSize = UDim2.new(GRID_X_SCALE, 0, 0, 140)
	cashGrid.CellPadding = UDim2.fromOffset(10, 12)
	cashGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cashGrid.SortOrder = Enum.SortOrder.LayoutOrder
	cashGrid.Parent = self.cashPage
	bindGridAspect(self, cashGrid, 1)

	cashGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.cashPage.CanvasSize = UDim2.new(0, 0, 0, cashGrid.AbsoluteContentSize.Y + 12)
	end)

	for i, p in ipairs(products.cash) do
		p.LayoutOrder = i
		self:createProductItem(p, "cash", self.cashPage)
	end

	-- GAMEPASSES
	self.gpPage = Instance.new("ScrollingFrame")
	self.gpPage.Name = "GamepassPage"; self.gpPage.BackgroundTransparency = 1
	self.gpPage.ScrollBarThickness = 5; self.gpPage.ScrollBarImageColor3 = theme.accent
	self.gpPage.Visible = false; self.gpPage.Size = UDim2.fromScale(1, 1); self.gpPage.ZIndex = 5
	self.gpPage.Parent = self.contentFrame

	local gpPad = Instance.new("UIPadding")
	gpPad.PaddingTop = UDim.new(0, 6); gpPad.PaddingBottom = UDim.new(0, 8)
	gpPad.PaddingLeft = UDim.new(0, 6); gpPad.PaddingRight = UDim.new(0, 6); gpPad.Parent = self.gpPage

	local gpGrid = Instance.new("UIGridLayout")
	gpGrid.CellSize = UDim2.new(GRID_X_SCALE, 0, 0, 140)
	gpGrid.CellPadding = UDim2.fromOffset(10, 12)
	gpGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gpGrid.SortOrder = Enum.SortOrder.LayoutOrder
	gpGrid.Parent = self.gpPage
	bindGridAspect(self, gpGrid, 2)

	gpGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.gpPage.CanvasSize = UDim2.new(0, 0, 0, gpGrid.AbsoluteContentSize.Y + 12)
	end)

	for i, gp in ipairs(products.gamepasses) do
		gp.LayoutOrder = i
		self:createProductItem(gp, "gamepass", self.gpPage)
	end
end

local function makeBottomRow(parentCell, orderFromBottom, text, color, active, extraPushPx)
	local push = math.max(0, extraPushPx or 0)
	local base = (orderFromBottom * BTN_H) + (orderFromBottom-1) * SECOND_ROW_GAP + CARD_INSET
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -2*CELL_PAD_X, 0, BTN_H)
	row.Position = UDim2.new(0.5, 0, 1, -(base - push))
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.BackgroundColor3 = color
	row.AutoButtonColor = active ~= false
	row.Text = text or ""
	row.TextColor3 = Color3.fromRGB(255,255,255)
	row.TextScaled = true
	row.Font = Enum.Font.FredokaOne
	row.TextStrokeColor3 = Color3.fromRGB(72,56,136)
	row.TextStrokeTransparency = 0
	row.BorderSizePixel = 0
	row.ZIndex = 20
	row.Parent = parentCell
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,12); corner.Parent = row
	local tsc = Instance.new("UITextSizeConstraint"); tsc.MinTextSize = 11; tsc.MaxTextSize = 15; tsc.Parent = row
	return row
end

function Shop:createProductItem(product, productType, parent)
	local isGamepass = (productType == "gamepass")
	local accentColor = isGamepass and theme.kuromi or theme.cinna

	local container = Instance.new("Frame")
	container.Name = product.name .. "Cell"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.LayoutOrder = product.LayoutOrder or 1
	container.ZIndex = 12
	container.Parent = parent

	local reservedRows = (parent == self.gpPage) and 2 or 1
	local card = buildCard(container, product, reservedRows)
	card.ZIndex = 12

	if isGamepass then
		local owned = checkOwnership(product.id)

		if product.hasToggle and owned then
			local push = TWO_ROW_BOTTOM_PUSH_PX
			makeBottomRow(container, 2, "OWNED", theme.success, false, push)

			local current = false
			if Remotes then
				local rf = Remotes:FindFirstChild("GetAutoCollectState")
				if rf and rf:IsA("RemoteFunction") then
					local ok, val = pcall(function() return rf:InvokeServer() end)
					if ok and type(val)=="boolean" then current = val end
				end
			end
			local toggle = makeBottomRow(container, 1, current and "ON" or "OFF", current and theme.success or theme.cardStroke, true, push)
			local function paint(state)
				toggle.Text = state and "ON" or "OFF"
				toggle.BackgroundColor3 = state and theme.success or theme.cardStroke
			end
			paint(current)
			toggle.MouseButton1Click:Connect(function()
				current = not current
				paint(current)
				if Remotes then
					local ev = Remotes:FindFirstChild("AutoCollectToggle")
					if ev and ev:IsA("RemoteEvent") then ev:FireServer(current) end
				end
			end)

		else
			local info = getGamePassInfo(product.id)
			local price = (info and info.PriceInRobux) or product.price or 0
			local text = owned and "OWNED" or (isPhone() and "BUY" or ("BUY - R$"..tostring(price)))
			local buyBtn = makeBottomRow(container, 1, text, owned and theme.success or accentColor, not owned, SINGLE_ROW_BOTTOM_PUSH_PX)
			if not owned then
				local function prompt()
					playSound("click")
					pulse(card)
					buyBtn.Text = "..."
					buyBtn.Active = false
					self:promptPurchase(product, "gamepass", buyBtn)
				end
				buyBtn.MouseButton1Click:Connect(prompt)
				buyBtn.Activated:Connect(prompt)
				product.purchaseButton = buyBtn
			end
		end
	else
		local info = getProductInfo(product.id)
		local price = (info and info.PriceInRobux) or product.price or 0
		local buyBtn = makeBottomRow(container, 1, isPhone() and "BUY" or ("BUY - R$"..tostring(price)), accentColor, true, 0)
		local function prompt()
			playSound("click")
			pulse(card)
			buyBtn.Text = "..."
			buyBtn.Active = false
			self:promptPurchase(product, "cash", buyBtn)
		end
		buyBtn.MouseButton1Click:Connect(prompt)
		buyBtn.Activated:Connect(prompt)
		product.purchaseButton = buyBtn
	end

	product.cardInstance = card
	product.containerInstance = container
end

function Shop:setupDynamicSizing()
	local function resize()
		local H = self.mainFrame.AbsoluteSize.Y
		local W = self.mainFrame.AbsoluteSize.X
		if H <= 0 or W <= 0 then return end

		local cf = isPhone() and CASH_H_FACTOR_PHONE or CASH_H_FACTOR_DESKTOP
		local gf = isPhone() and GP_H_FACTOR_PHONE   or GP_H_FACTOR_DESKTOP
		local cashH = math.clamp(math.floor(H * cf), PILL_MIN_H, PILL_MAX_H)
		local gpH   = math.clamp(math.floor(H * gf), PILL_MIN_H, PILL_MAX_H)

		self.buttonBar.Size = UDim2.new(0, math.floor(W * BAR_WIDTH_FACTOR), 0, math.max(cashH, gpH) + PILL_BAR_PAD*2)

		local cashW = math.floor(cashH * CASH_RATIO)
		self.cashContainer.Size = UDim2.fromOffset(cashW, cashH)
		self.cashContainer.Position = UDim2.fromScale(0.30, 0.64)

		local gpW = math.floor(gpH * GP_RATIO)
		self.gpContainer.Size = UDim2.fromOffset(gpW, gpH)
		self.gpContainer.Position = UDim2.fromScale(0.70, 0.64 + GP_ROW_EXTRA)

		local barBottom = self.buttonBar.AbsolutePosition.Y + self.buttonBar.AbsoluteSize.Y
		local frameTop  = self.mainFrame.AbsolutePosition.Y
		local gap = math.floor(math.max(cashH, gpH) * 0.44)
		local relY = math.clamp((barBottom - frameTop + gap) / H, 0.42, 0.52)

		self.contentFrame.Size = UDim2.new(0, math.floor(W * CONTENT_WIDTH_FACTOR), 0, math.floor(H * CONTENT_HEIGHT_FACTOR))
		self.contentFrame.Position = UDim2.new(0.5, 0, relY, 0)
	end
	self.mainFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	self.buttonBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	RunService.Heartbeat:Connect(resize)
	task.defer(resize)
end

function Shop:showCash() self.cashPage.Visible = true; self.gpPage.Visible = false end
function Shop:showGamepasses() self.cashPage.Visible = false; self.gpPage.Visible = true end

function Shop:promptPurchase(product, kind, button)
	self.purchasePending[product.id] = { product = product, type = kind, button = button }
	local ok
	if kind == "gamepass" then
		ok = pcall(function() MarketplaceService:PromptGamePassPurchase(Player, product.id) end)
	else
		ok = pcall(function() MarketplaceService:PromptProductPurchase(Player, product.id) end)
	end
	task.delay(1.0, function()
		local pend = self.purchasePending[product.id]
		if pend and button and button.Parent then
			button.Text = (kind=="gamepass") and "BUY" or (isPhone() and "BUY" or ("BUY - R$"..tostring(product.price or 0)))
			button.Active = true
		end
	end)
	if not ok then
		if button and button.Parent then
			button.Text = isPhone() and "BUY" or ("BUY - R$"..tostring(product.price or 0))
			button.Active = true
		end
		self.purchasePending[product.id] = nil
	end
end

-- ✅ NEW: Smoothly update gamepass UI in place (NO DESTROY/RECREATE!)
function Shop:updateGamepassUI(passId)
	print("🔄 [CREATEMONEYSHOP] updateGamepassUI() for passId:", passId)
	
	-- Find the gamepass product data
	local gpData = nil
	for _, gp in ipairs(products.gamepasses) do
		if gp.id == passId then
			gpData = gp
			break
		end
	end
	
	if not gpData then
		warn("❌ [CREATEMONEYSHOP] Gamepass data not found for:", passId)
		return
	end
	
	-- Find the card container
	local container = gpData.containerInstance
	if not container or not container.Parent then
		warn("❌ [CREATEMONEYSHOP] Card container not found for:", gpData.name)
		return
	end
	
	print("✅ [CREATEMONEYSHOP] Found card for:", gpData.name)
	
	-- Check if this gamepass has a toggle
	local hasToggle = gpData.hasToggle
	
	-- Destroy old bottom buttons
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	
	-- Create new UI based on ownership
	if hasToggle then
		-- Auto Collect: OWNED + toggle
		local push = TWO_ROW_BOTTOM_PUSH_PX
		makeBottomRow(container, 2, "OWNED", theme.success, false, push)
		
		-- Get current auto-collect state from server
		local current = false
		if Remotes then
			local rf = Remotes:FindFirstChild("GetAutoCollectState")
			if rf and rf:IsA("RemoteFunction") then
				local ok, val = pcall(function() return rf:InvokeServer() end)
				if ok and type(val) == "boolean" then current = val end
			end
		end
		
		local toggle = makeBottomRow(container, 1, current and "ON" or "OFF", current and theme.success or theme.cardStroke, true, push)
		local function paint(state)
			toggle.Text = state and "ON" or "OFF"
			toggle.BackgroundColor3 = state and theme.success or theme.cardStroke
		end
		paint(current)
		
		toggle.MouseButton1Click:Connect(function()
			current = not current
			paint(current)
			if Remotes then
				local ev = Remotes:FindFirstChild("AutoCollectToggle")
				if ev and ev:IsA("RemoteEvent") then ev:FireServer(current) end
			end
		end)
		
		print("✅ [CREATEMONEYSHOP] Added OWNED + toggle for:", gpData.name)
	else
		-- Regular gamepass: just OWNED
		makeBottomRow(container, 1, "OWNED", theme.success, false, SINGLE_ROW_BOTTOM_PUSH_PX)
		print("✅ [CREATEMONEYSHOP] Added OWNED button for:", gpData.name)
	end
	
	-- Smooth fade-in animation
	local card = gpData.cardInstance
	if card then
		local originalTransparency = card.BackgroundTransparency
		card.BackgroundTransparency = 1
		TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = originalTransparency
		}):Play()
		pulse(card)
	end
	
	playSound("success")
	print("🎉 [CREATEMONEYSHOP] Gamepass UI updated smoothly!")
end

-- ✅ NEW: Refresh all products smoothly (no destroy/recreate)
function Shop:refreshAllProducts()
	print("🔄 [CREATEMONEYSHOP] refreshAllProducts() called")
	
	-- Update cash products (prices may have changed)
	for _, p in ipairs(products.cash) do
		if p.purchaseButton and p.purchaseButton.Parent then
			local info = getProductInfo(p.id)
			local price = (info and info.PriceInRobux) or p.price or 0
			p.purchaseButton.Text = isPhone() and "BUY" or ("BUY - R$" .. tostring(price))
		end
	end
	
	-- Update gamepass products (check ownership)
	for _, gp in ipairs(products.gamepasses) do
		local owned = checkOwnership(gp.id)
		print("🔍 [CREATEMONEYSHOP] Checking", gp.name, "- Owned:", owned)
		
		-- If owned and has a toggle, update to OWNED + toggle UI
		if owned and gp.hasToggle then
			-- Check if UI already shows toggle
			local hasToggleUI = false
			if gp.containerInstance then
				for _, child in ipairs(gp.containerInstance:GetChildren()) do
					if child:IsA("TextButton") and (child.Text == "ON" or child.Text == "OFF") then
						hasToggleUI = true
						break
					end
				end
			end
			
			-- Only update if not already showing toggle
			if not hasToggleUI then
				print("🔄 [CREATEMONEYSHOP] Needs toggle UI for:", gp.name)
				self:updateGamepassUI(gp.id)
			end
		elseif owned and not gp.hasToggle then
			-- Regular owned gamepass
			if gp.purchaseButton and gp.purchaseButton.Parent then
				gp.purchaseButton.Text = "OWNED"
				gp.purchaseButton.BackgroundColor3 = theme.success
				gp.purchaseButton.Active = false
			end
		else
			-- Not owned - show BUY button
			if gp.purchaseButton and gp.purchaseButton.Parent then
				local info = getGamePassInfo(gp.id)
				local price = (info and info.PriceInRobux) or gp.price or 0
				gp.purchaseButton.Text = isPhone() and "BUY" or ("BUY - R$" .. tostring(price))
				gp.purchaseButton.BackgroundColor3 = theme.kuromi
				gp.purchaseButton.Active = true
			end
		end
	end
	
	print("✅ [CREATEMONEYSHOP] All products refreshed")
end

function Shop:open()
	if self.isOpen then return end
	self.isOpen = true

	ownershipCache:clear()
	refreshPrices()

	-- ✅ Preload authoritative ownership states from server
	if Remotes then
		local rf = Remotes:FindFirstChild("GetOwnedPasses")
		if rf and rf:IsA("RemoteFunction") then
			local ok, ownedMap = pcall(function() return rf:InvokeServer() end)
			if ok and type(ownedMap) == "table" then
				print("📥 [CREATEMONEYSHOP] Preloaded ownership from server:")
				for id, owns in pairs(ownedMap) do
					local key = ("%d_%d"):format(Player.UserId, tonumber(id))
					ownershipCache:set(key, owns and true or false)
					print("  ", id, "→", owns)
				end
			end
		end
	end

	self:refreshAllProducts()

	self.gui.Enabled = true
	TweenService:Create(self.blur, TweenInfo.new(0.25), {Size = 24}):Play()
	self.mainFrame.Position = UDim2.fromScale(0.5, 0.52)
	TweenService:Create(self.mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = UDim2.fromScale(0.5, 0.5)}):Play()
	self:showCash()
	playSound("open")
end

function Shop:close()
	if not self.isOpen then return end
	self.isOpen = false
	TweenService:Create(self.blur, TweenInfo.new(0.15), {Size = 0}):Play()
	TweenService:Create(self.mainFrame, TweenInfo.new(0.15), {Position = UDim2.fromScale(0.5, 0.52)}):Play()
	task.wait(0.15)
	self.gui.Enabled = false
end

function Shop:toggle() if self.isOpen then self:close() else self:open() end end

function Shop:setupHandlers()
	UserInputService.InputBegan:Connect(function(i, gp)
		if gp then return end
		if i.KeyCode == Enum.KeyCode.M then self:toggle() end
		if i.KeyCode == Enum.KeyCode.Escape and self.isOpen then self:close() end
	end)

	-- ✅ FIXED: Wait for server confirmation before updating UI
	local recreateDebounce = {}
	
	if Remotes then
		local gpPurchased = Remotes:FindFirstChild("GamepassPurchased")
		if gpPurchased and gpPurchased:IsA("RemoteEvent") then
			gpPurchased.OnClientEvent:Connect(function(passId)
				print("✅ [CREATEMONEYSHOP] Server confirmed gamepass purchase:", passId)
				
				-- Debounce: Prevent multiple rapid updates for same pass
				if recreateDebounce[passId] then
					print("⏸️ [CREATEMONEYSHOP] Already processing", passId, "- skipping duplicate")
					return
				end
				recreateDebounce[passId] = true
				
				-- ✅ CRITICAL: Trust the server - cache TRUE immediately
				local key = ("%d_%d"):format(Player.UserId, passId)
				ownershipCache:set(key, true)
				print("✅ [CREATEMONEYSHOP] Cached ownership as TRUE for passId:", passId)
				
				-- ✅ NEW: Smoothly update just this gamepass (no destroy/recreate!)
				task.wait(0.2)
				self:updateGamepassUI(passId)
				
				-- Clear debounce
				task.delay(3, function()
					recreateDebounce[passId] = nil
				end)
			end)
		end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if player ~= Player then return end
		local p = self.purchasePending[passId]
		self.purchasePending[passId] = nil

		if purchased then
			-- Don't recreate here - let server event handle it!
			playSound("success")
			print("🛍️ [CREATEMONEYSHOP] Gamepass purchased, waiting for server confirmation...")
		else
			if p and p.button and p.button.Parent then
				p.button.Text = isPhone() and "BUY" or ("BUY - R$"..tostring(p.product.price or 0))
				p.button.Active = true
			end
			print("❌ [CREATEMONEYSHOP] Gamepass purchase cancelled")
		end
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, purchased)
		if player ~= Player then return end
		local p = self.purchasePending[productId]
		if p and p.button and p.button.Parent then
			p.button.Text = isPhone() and "BUY" or ("BUY - R$"..tostring(p.product.price or 0))
			p.button.Active = true
		end
		self.purchasePending[productId] = nil
		if purchased then
			playSound("success")
			if p and p.product and p.product.cardInstance then 
				pulse(p.product.cardInstance)
			end
		end
	end)
end

local shop = Shop.new()
shop:initialize()

Player.CharacterAdded:Connect(function()
	task.wait(1)
	if not shop.toggleButton or not shop.toggleButton.Parent then
		shop:createToggleButton()
	end
end)

return shop
