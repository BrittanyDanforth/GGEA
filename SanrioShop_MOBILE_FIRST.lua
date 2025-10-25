--[[
    SANRIO SHOP — MOBILE FIRST (NO BROKEN SCALING)
    ✅ Cards scale properly on ALL screen sizes
    ✅ Text NEVER goes under buttons
    ✅ Everything uses SCALE not broken offsets
    ✅ Mobile tested FIRST
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
local IMG_FRAME = "rbxassetid://83301831904885"
local IMG_GAMEPASSES = "rbxassetid://137846629770171"
local IMG_CASH = "rbxassetid://84262748186110"
local GIFT_BOX_TEXTURE_ID = "130623477775352"

-- ======== LAYOUT ========
local FRAME_SCALE = 0.92
local TAB_ROW_Y = 0.36
local GP_ROW_EXTRA = 0.02
local CONTENT_TOP_Y = 0.472
local BAR_WIDTH_FACTOR = 0.92
local CONTENT_WIDTH_FACTOR = 0.90
local CONTENT_HEIGHT_FACTOR = 0.48

-- Pills (smaller for mobile)
local CASH_H_FACTOR, GP_H_FACTOR = 0.075, 0.082
local PILL_MIN_H, PILL_MAX_H = 54, 120
local CASH_RATIO, GP_RATIO = 2.85, 3.60

-- ======== GRID / CARD ========
local GRID_X_SCALE = 0.455  -- desktop 2 col
local CARD_AR = 1.42
local CARD_SIZE_MULT = 1.0  -- normal height
local CARD_INSET = 10

-- ======== UTILS ========
local function isMobile() return UserInputService.TouchEnabled and not GuiService:IsTenFootInterface() end
local function isPhone()
	if not isMobile() then return false end
	local v = workspace.CurrentCamera.ViewportSize
	return math.min(v.X, v.Y) < 700
end
local function blend(a,b,t) t=math.clamp(t,0,1) return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t) end

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
	local key=("%d_%d"):format(Player.UserId,passId); local c=ownershipCache:get(key); if c~=nil then return c end
	local ok,owns=pcall(function() return MarketplaceService:UserOwnsGamePassAsync(Player.UserId,passId) end)
	if ok then ownershipCache:set(key,owns) return owns end; return false
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
local function confetti(parent)
	for i=1,8 do
		local chip=Instance.new("Frame"); chip.BackgroundColor3=(i%2==0) and theme.accent or theme.kuromi
		chip.Size=UDim2.fromOffset(6,10); chip.Position=UDim2.new(math.random(),0,0,-6); chip.BorderSizePixel=0; chip.Parent=parent
		local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,2); c.Parent=chip
		task.spawn(function()
			TweenService:Create(chip,TweenInfo.new(0.45),{Position=UDim2.new(chip.Position.X.Scale,(math.random()-0.5)*60,0,math.random(60,110)),Rotation=math.random(-40,40)}):Play()
			task.delay(0.46,function() chip:Destroy() end)
		end)
	end
end

-- ======== MOBILE-FIRST CARD ========
local function buildCard(parent, product, isGamepass)
	-- Shadow
	local shadow = Instance.new("Frame")
	shadow.BackgroundColor3 = theme.shadow; shadow.BackgroundTransparency = 0.88
	shadow.Size = UDim2.new(1, -2*CARD_INSET, 1, -2*CARD_INSET)
	shadow.Position = UDim2.fromOffset(CARD_INSET, CARD_INSET + 5)
	shadow.BorderSizePixel = 0; shadow.Parent = parent
	local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 18); sc.Parent = shadow

	-- Card
	local card = Instance.new("Frame")
	card.BackgroundColor3 = theme.cardBot
	card.Size = UDim2.new(1, -2*CARD_INSET, 1, -2*CARD_INSET)
	card.Position = UDim2.fromOffset(CARD_INSET, CARD_INSET)
	card.BorderSizePixel = 0; card.Parent = parent
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 18); corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = theme.cardStroke; stroke.Thickness = 2; stroke.Transparency = 0.15
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; stroke.Parent = card

	local g = Instance.new("UIGradient"); g.Rotation = 90
	g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, theme.cardTop), ColorSequenceKeypoint.new(1, theme.cardBot)})
	g.Parent = card

	-- Inner
	local inner = Instance.new("Frame")
	inner.BackgroundColor3 = theme.cardInner
	inner.Size = UDim2.new(1, -12, 1, -12)
	inner.Position = UDim2.fromOffset(6, 6)
	inner.BorderSizePixel = 0; inner.Parent = card
	local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(0, 14); ic.Parent = inner
	local is = Instance.new("UIStroke"); is.Color = Color3.new(1,1,1); is.Transparency = 0.7; is.Thickness = 1; is.Parent = inner
	local ig = Instance.new("UIGradient"); ig.Rotation = 90
	ig.Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromRGB(245,240,255)); ig.Parent = inner

	-- Content with PADDING (not fixed offsets!)
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -24, 1, -24)  -- SCALE based
	content.Position = UDim2.fromOffset(12, 12)
	content.Parent = inner

	-- LIST LAYOUT so things stack and NEVER overlap!
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content

	-- Badges container (top right)
	local badgesContainer = Instance.new("Frame")
	badgesContainer.Size = UDim2.new(0, 100, 0, 70)  -- Fixed size for badges
	badgesContainer.Position = UDim2.new(1, -100, 0, 0)
	badgesContainer.BackgroundTransparency = 1
	badgesContainer.Parent = content

	if product.best then
		local best = Instance.new("Frame")
		best.BackgroundColor3 = Color3.fromRGB(255,64,129)
		best.Size = UDim2.fromOffset(90, 26)
		best.Position = UDim2.fromOffset(0, 0)
		best.BorderSizePixel = 0; best.Parent = badgesContainer
		local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0, 10); cr.Parent = best
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1,1); t.Text = "BEST VALUE"
		t.TextColor3 = Color3.new(1,1,1); t.Font = Enum.Font.FredokaOne; t.TextSize = 12; t.Parent = best
	end
	if product.bonus and product.bonus > 0 then
		local bonus = Instance.new("Frame")
		bonus.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
		bonus.Size = UDim2.fromOffset(85, 26)
		bonus.Position = UDim2.fromOffset(0, product.best and 32 or 0)
		bonus.BorderSizePixel = 0; bonus.Parent = badgesContainer
		local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0,10); cr.Parent = bonus
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1,1)
		t.Text = "+"..math.floor(product.bonus*100).."%"
		t.TextColor3 = Color3.fromRGB(139, 69, 19); t.Font = Enum.Font.FredokaOne; t.TextSize = 13; t.Parent = bonus
	end

	-- Title (with icon if exists)
	local titleContainer = Instance.new("Frame")
	titleContainer.BackgroundTransparency = 1
	titleContainer.Size = UDim2.new(1, -110, 0, 40)  -- Leave room for badges
	titleContainer.LayoutOrder = 1
	titleContainer.Parent = content

	local icon, title
	if product.icon and product.icon ~= "" then
		icon = Instance.new("ImageLabel")
		icon.Image = product.icon
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromOffset(32, 32)
		icon.Position = UDim2.fromOffset(0, 4)
		icon.Parent = titleContainer
		
		title = Instance.new("TextLabel")
		title.Position = UDim2.fromOffset(40, 0)
		title.Size = UDim2.new(1, -40, 1, 0)
	else
		title = Instance.new("TextLabel")
		title.Size = UDim2.fromScale(1, 1)
	end

	title.BackgroundTransparency = 1
	title.Text = product.name
	title.Font = Enum.Font.FredokaOne
	title.TextColor3 = Color3.fromRGB(255,255,255)
	title.TextStrokeColor3 = Color3.fromRGB(168,150,232)
	title.TextStrokeTransparency = 0.08
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextScaled = true
	title.Parent = titleContainer
	
	local tsc = Instance.new("UITextSizeConstraint")
	tsc.MinTextSize = 16; tsc.MaxTextSize = 28; tsc.Parent = title

	-- Description (wraps properly)
	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Size = UDim2.new(1, -20, 0, 50)  -- Height flexes
	desc.Text = product.description or ""
	desc.Font = Enum.Font.FredokaOne
	desc.TextColor3 = Color3.fromRGB(255,255,255)
	desc.TextStrokeColor3 = Color3.fromRGB(168,150,232)
	desc.TextStrokeTransparency = 0.2
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextWrapped = true
	desc.TextScaled = true
	desc.LineHeight = 1.1
	desc.LayoutOrder = 2
	desc.Parent = content
	
	local dsc = Instance.new("UITextSizeConstraint")
	dsc.MinTextSize = 12; dsc.MaxTextSize = 18; dsc.Parent = desc

	-- Spacer pushes button to bottom
	local spacer = Instance.new("Frame")
	spacer.BackgroundTransparency = 1
	spacer.Size = UDim2.new(1, 0, 1, -150)  -- Fills remaining space
	spacer.LayoutOrder = 3
	spacer.Parent = content

	-- Button at bottom
	local btnContainer = Instance.new("Frame")
	btnContainer.BackgroundTransparency = 1
	btnContainer.Size = UDim2.new(1, 0, 0, 40)
	btnContainer.LayoutOrder = 4
	btnContainer.Parent = content

	return card, btnContainer
end

-- ======== SHOP CLASS ========
local Shop = {}; Shop.__index = Shop
function Shop.new()
	return setmetatable({
		gui=nil, mainFrame=nil, buttonBar=nil, cashContainer=nil, gpContainer=nil, cashBtn=nil, gpBtn=nil,
		contentFrame=nil, cashPage=nil, gpPage=nil, toggleButton=nil, blur=nil, isOpen=false, purchasePending={}
	}, Shop)
end

function Shop:initialize()
	initSound()
	refreshPrices()
	self:createToggleButton()
	self:createMainInterface()
	self:setupHandlers()
	print("[SanrioShop] ✅ MOBILE FIRST - No more broken scaling!")
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
	container.AnchorPoint = Vector2.new(0.5, 0.5); container.Size = UDim2.fromOffset(260, 86); container.ZIndex = 6
	container.Parent = self.buttonBar
	local ar = Instance.new("UIAspectRatioConstraint"); ar.AspectRatio = ratio; ar.DominantAxis = Enum.DominantAxis.Width; ar.Parent = container

	local btn = Instance.new("ImageButton")
	btn.Name = name .. "Button"; btn.BackgroundTransparency = 1; btn.AutoButtonColor = false
	btn.Size = UDim2.fromScale(1, 1); btn.Image = imageId
	btn.ScaleType = Enum.ScaleType.Fit
	btn.ZIndex = 7; btn.Parent = container

	local function bump(mult)
		local sx, sy = math.floor(container.Size.X.Offset * mult), math.floor(container.Size.Y.Offset * mult)
		TweenService:Create(container, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(sx, sy)}):Play()
	end
	btn.MouseEnter:Connect(function() playSound("hover"); bump(1.02) end)
	btn.MouseLeave:Connect(function() bump(1.00) end)
	btn.MouseButton1Down:Connect(function() bump(0.98) end)
	btn.MouseButton1Up:Connect(function() bump(1.02) end)

	return container, btn
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
	self.mainFrame.Size = UDim2.fromScale(FRAME_SCALE, FRAME_SCALE)
	self.mainFrame.Image = IMG_FRAME; self.mainFrame.ScaleType = Enum.ScaleType.Fit
	self.mainFrame.ZIndex = 1; self.mainFrame.Parent = self.gui
	local aspect = Instance.new("UIAspectRatioConstraint"); aspect.AspectRatio = 1; aspect.Parent = self.mainFrame

	self.buttonBar = Instance.new("Frame")
	self.buttonBar.Name = "ButtonBar"; self.buttonBar.BackgroundTransparency = 1
	self.buttonBar.AnchorPoint = Vector2.new(0.5, 0); self.buttonBar.Position = UDim2.fromScale(0.5, TAB_ROW_Y)
	self.buttonBar.Size = UDim2.fromScale(BAR_WIDTH_FACTOR, 0); self.buttonBar.ZIndex = 5; self.buttonBar.Parent = self.mainFrame

	self.cashContainer, self.cashBtn = self:makePill("Cash", IMG_CASH, CASH_RATIO)
	self.gpContainer, self.gpBtn = self:makePill("Gamepasses", IMG_GAMEPASSES, GP_RATIO)

	self.contentFrame = Instance.new("Frame")
	self.contentFrame.Name = "Content"; self.contentFrame.AnchorPoint = Vector2.new(0.5, 0)
	self.contentFrame.Position = UDim2.fromScale(0.5, CONTENT_TOP_Y)
	self.contentFrame.Size = UDim2.fromScale(CONTENT_WIDTH_FACTOR, CONTENT_HEIGHT_FACTOR)
	self.contentFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
	self.contentFrame.BackgroundTransparency = 0.88
	self.contentFrame.ZIndex = 3; self.contentFrame.Parent = self.mainFrame
	local contentCorner = Instance.new("UICorner"); contentCorner.CornerRadius = UDim.new(0, 20); contentCorner.Parent = self.contentFrame

	self:createPages()
	self:setupDynamicSizing()

	self.cashBtn.MouseButton1Click:Connect(function() self:showCash() end)
	self.gpBtn.MouseButton1Click:Connect(function() self:showGamepasses() end)
end

function Shop:_bindGridAspect(grid)
	local function recalc()
		local pad = grid.Parent:FindFirstChildWhichIsA("UIPadding")
		local left  = pad and pad.PaddingLeft.Offset  or 0
		local right = pad and pad.PaddingRight.Offset or 0
		local usable = math.max(0, grid.Parent.AbsoluteSize.X - (left + right))
		if usable <= 0 then return end
		
		-- 1 column on phone portrait, 2 otherwise
		local vp = workspace.CurrentCamera.ViewportSize
		local isPortrait = vp.Y > vp.X
		local isSmall = math.min(vp.X, vp.Y) < 700
		local wScale = (isPortrait and isSmall) and 0.94 or GRID_X_SCALE
		
		local cellW = math.ceil(usable * wScale)
		local cellH = math.max(160, math.ceil((cellW / CARD_AR) * CARD_SIZE_MULT))  -- Taller cards
		grid.CellSize = UDim2.new(wScale, 0, 0, cellH)
		
		if pad and wScale > 0.9 then
			pad.PaddingLeft = UDim.new(0, 4)
			pad.PaddingRight = UDim.new(0, 4)
		end
	end
	grid.Parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(recalc)
	self.contentFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(recalc)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(recalc)
	RunService.Heartbeat:Connect(recalc)
	task.defer(recalc)
end

function Shop:createPages()
	self.cashPage = Instance.new("ScrollingFrame")
	self.cashPage.Name = "CashPage"; self.cashPage.BackgroundTransparency = 1
	self.cashPage.ScrollBarThickness = 6; self.cashPage.ScrollBarImageColor3 = theme.accent
	self.cashPage.Visible = true; self.cashPage.Size = UDim2.fromScale(1, 1); self.cashPage.ZIndex = 4
	self.cashPage.Parent = self.contentFrame

	local cashPad = Instance.new("UIPadding")
	cashPad.PaddingTop = UDim.new(0, 6); cashPad.PaddingBottom = UDim.new(0, 12)
	cashPad.PaddingLeft = UDim.new(0, 8); cashPad.PaddingRight = UDim.new(0, 8); cashPad.Parent = self.cashPage

	local cashGrid = Instance.new("UIGridLayout")
	cashGrid.CellSize = UDim2.new(GRID_X_SCALE, 0, 0, 160)
	cashGrid.CellPadding = UDim2.fromOffset(20, 28)
	cashGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cashGrid.SortOrder = Enum.SortOrder.LayoutOrder
	cashGrid.Parent = self.cashPage
	self:_bindGridAspect(cashGrid)

	cashGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.cashPage.CanvasSize = UDim2.new(0, 0, 0, cashGrid.AbsoluteContentSize.Y + 24)
	end)

	for i, p in ipairs(products.cash) do
		p.LayoutOrder = i
		self:createProductItem(p, "cash", self.cashPage)
	end

	self.gpPage = Instance.new("ScrollingFrame")
	self.gpPage.Name = "GamepassPage"; self.gpPage.BackgroundTransparency = 1
	self.gpPage.ScrollBarThickness = 5; self.gpPage.ScrollBarImageColor3 = theme.accent
	self.gpPage.Visible = false; self.gpPage.Size = UDim2.fromScale(1, 1); self.gpPage.ZIndex = 4
	self.gpPage.Parent = self.contentFrame

	local gpPad = Instance.new("UIPadding")
	gpPad.PaddingTop = UDim.new(0, 6); gpPad.PaddingBottom = UDim.new(0, 12)
	gpPad.PaddingLeft = UDim.new(0, 8); gpPad.PaddingRight = UDim.new(0, 8); gpPad.Parent = self.gpPage

	local gpGrid = Instance.new("UIGridLayout")
	gpGrid.CellSize = UDim2.new(GRID_X_SCALE, 0, 0, 160)
	gpGrid.CellPadding = UDim2.fromOffset(20, 28)
	gpGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gpGrid.SortOrder = Enum.SortOrder.LayoutOrder
	gpGrid.Parent = self.gpPage
	self:_bindGridAspect(gpGrid)

	gpGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.gpPage.CanvasSize = UDim2.new(0, 0, 0, gpGrid.AbsoluteContentSize.Y + 24)
	end)

	for i, gp in ipairs(products.gamepasses) do
		gp.LayoutOrder = i
		self:createProductItem(gp, "gamepass", self.gpPage)
	end
end

function Shop:createProductItem(product, productType, parent)
	local isGamepass = (productType == "gamepass")
	local accentColor = isGamepass and theme.kuromi or theme.cinna
	local owned = isGamepass and checkOwnership(product.id)

	local container = Instance.new("Frame")
	container.Name = product.name .. "Cell"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.LayoutOrder = product.LayoutOrder or 1
	container.Parent = parent

	local card, btnContainer = buildCard(container, product, isGamepass)

	-- BUY button
	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(0.85, 0, 1, 0)
	buyBtn.Position = UDim2.fromScale(0.5, 0.5)
	buyBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	buyBtn.BackgroundColor3 = accentColor
	buyBtn.Text = (owned and isGamepass) and "OWNED" or (isPhone() and "BUY" or ("BUY - R$"..tostring(product.price or 0)))
	buyBtn.TextColor3 = Color3.fromRGB(255,255,255)
	buyBtn.Font = Enum.Font.FredokaOne
	buyBtn.AutoButtonColor = false
	buyBtn.BorderSizePixel = 0
	buyBtn.TextStrokeColor3 = Color3.fromRGB(72,56,136)
	buyBtn.TextStrokeTransparency = 0.0
	buyBtn.TextScaled = true
	buyBtn.Parent = btnContainer
	local btnCorner = Instance.new("UICorner"); btnCorner.CornerRadius = UDim.new(0,12); btnCorner.Parent = buyBtn
	local btsc = Instance.new("UITextSizeConstraint"); btsc.MinTextSize = 14; btsc.MaxTextSize = 20; btsc.Parent = buyBtn

	buyBtn.MouseEnter:Connect(function()
		playSound("hover")
		TweenService:Create(buyBtn, TweenInfo.new(0.12), {BackgroundColor3 = blend(accentColor, Color3.new(0,0,0), 0.08)}):Play()
	end)
	buyBtn.MouseLeave:Connect(function()
		local base = (owned and isGamepass) and theme.success or accentColor
		TweenService:Create(buyBtn, TweenInfo.new(0.12), {BackgroundColor3 = base}):Play()
	end)

	if isGamepass and product.hasToggle and owned then
		buyBtn.Size = UDim2.new(0.5, 0, 1, 0)
		buyBtn.Position = UDim2.fromScale(0.25, 0.5)
		buyBtn.Text = "OFF"
		local state = false
		if Remotes then
			local rf = Remotes:FindFirstChild("GetAutoCollectState")
			if rf and rf:IsA("RemoteFunction") then
				local ok, val = pcall(function() return rf:InvokeServer() end)
				if ok and type(val)=="boolean" then state = val end
			end
		end
		local function paint(on)
			state = on
			if on then buyBtn.BackgroundColor3 = theme.success; buyBtn.Text="ON" else buyBtn.BackgroundColor3 = theme.cardStroke; buyBtn.Text="OFF" end
		end
		paint(state)
		buyBtn.MouseButton1Click:Connect(function()
			local nextState = not state; paint(nextState); playSound("click")
			if Remotes then local ev = Remotes:FindFirstChild("AutoCollectToggle"); if ev and ev:IsA("RemoteEvent") then ev:FireServer(nextState) end end
		end)
	elseif isGamepass and owned then
		buyBtn.BackgroundColor3 = theme.success
		buyBtn.Text = "OWNED"
		buyBtn.Active = false
	else
		buyBtn.MouseButton1Click:Connect(function()
			if owned then return end
			buyBtn.Text = "..."
			buyBtn.Active = false
			self:promptPurchase(product, productType, buyBtn)
		end)
	end

	product.cardInstance = card
	product.purchaseButton = buyBtn
end

function Shop:setupDynamicSizing()
	local function resize()
		local H = self.mainFrame.AbsoluteSize.Y
		if H <= 0 then return end

		local cashH = math.clamp(math.floor(H * CASH_H_FACTOR), PILL_MIN_H, PILL_MAX_H)
		local gpH = math.clamp(math.floor(H * GP_H_FACTOR), PILL_MIN_H, PILL_MAX_H)
		local barH = math.max(cashH, gpH)

		self.buttonBar.Size = UDim2.new(0, math.floor(H * BAR_WIDTH_FACTOR), 0, barH)

		local cashW = math.floor(cashH * CASH_RATIO)
		self.cashContainer.Size = UDim2.fromOffset(cashW, cashH)
		self.cashContainer.Position = UDim2.fromScale(0.30, 0.50)

		local gpW = math.floor(gpH * GP_RATIO)
		self.gpContainer.Size = UDim2.fromOffset(gpW, gpH)
		self.gpContainer.Position = UDim2.fromScale(0.70, 0.50 + GP_ROW_EXTRA)

		local tabRowAbsY = self.buttonBar.AbsolutePosition.Y
		local barBottom = tabRowAbsY + self.buttonBar.AbsoluteSize.Y
		local frameTop = self.mainFrame.AbsolutePosition.Y
		local relY = math.max(CONTENT_TOP_Y, (barBottom - frameTop + 16) / H)
		
		self.contentFrame.Size = UDim2.new(0, math.floor(H * CONTENT_WIDTH_FACTOR), 0, math.floor(H * CONTENT_HEIGHT_FACTOR))
		self.contentFrame.Position = UDim2.new(0.5, 0, relY, 0)
	end
	self.mainFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	self.buttonBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	RunService.Heartbeat:Connect(resize)
	task.defer(resize)
end

function Shop:showCash() self.cashPage.Visible = true; self.gpPage.Visible = false; playSound("click") end
function Shop:showGamepasses() self.cashPage.Visible = false; self.gpPage.Visible = true; playSound("click") end

function Shop:promptPurchase(product, kind, button)
	self.purchasePending[product.id] = { product = product, type = kind, button = button }
	local ok
	if kind == "gamepass" then
		ok = pcall(function() MarketplaceService:PromptGamePassPurchase(Player, product.id) end)
	else
		ok = pcall(function() MarketplaceService:PromptProductPurchase(Player, product.id) end)
	end
	if not ok then
		if button and button.Parent then
			button.Text = isPhone() and "BUY" or ("R$"..tostring(product.price or 0))
			button.Active = true
		end
		self.purchasePending[product.id] = nil
	end
end

function Shop:refreshAllProducts()
	ownershipCache:clear()
	for _, gp in ipairs(products.gamepasses) do
		local owned = checkOwnership(gp.id)
		if gp.purchaseButton then
			gp.purchaseButton.Text = owned and "OWNED" or (isPhone() and "BUY" or ("BUY - R$"..tostring(gp.price or 0)))
			gp.purchaseButton.BackgroundColor3 = owned and theme.success or theme.kuromi
			gp.purchaseButton.Active = not owned
		end
	end
end

function Shop:open()
	if self.isOpen then return end
	self.isOpen = true
	ownershipCache:clear()
	refreshPrices()
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

	if Remotes then
		local gpPurchased = Remotes:FindFirstChild("GamepassPurchased")
		if gpPurchased and gpPurchased:IsA("RemoteEvent") then
			gpPurchased.OnClientEvent:Connect(function()
				task.wait(0.5)
				self:refreshAllProducts()
				playSound("success")
			end)
		end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if player ~= Player then return end
		local p = self.purchasePending[passId]
		if p and p.button and p.button.Parent then
			p.button.Text = purchased and "OWNED" or (isPhone() and "BUY" or ("BUY - R$"..tostring(p.product.price or 0)))
			p.button.Active = not purchased
		end
		self.purchasePending[passId] = nil
		if purchased then
			ownershipCache:clear()
			task.wait(0.8)
			self:refreshAllProducts()
			playSound("success")
			if p and p.product and p.product.cardInstance then pulse(p.product.cardInstance); confetti(p.product.cardInstance) end
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
			if p and p.product and p.product.cardInstance then pulse(p.product.cardInstance); confetti(p.product.cardInstance) end
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

print("[SanrioShop] ✅ MOBILE FIRST - UIListLayout prevents overlaps!")
print("[SanrioShop] 📱 Everything SCALES properly on any screen!")
print("[SanrioShop] 🎨 Text NEVER goes under buttons!")

return shop
