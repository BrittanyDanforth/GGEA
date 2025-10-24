--[[
    SANRIO SHOP — PERFECT MERGE (CARD BACKGROUNDS FIXED)
    ✅ Beautiful pill buttons
    ✅ Full functionality
    ✅ Card backgrounds fill cells (no tiny cards)
    ✅ Larger gaps between cards
    ✅ Adjusted: grid starts higher, text lower, button higher
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

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:FindFirstChild("TycoonRemotes")

-- ======== ASSETS ========
local IMG_FRAME = "rbxassetid://83301831904885"
local IMG_GAMEPASSES = "rbxassetid://137846629770171"
local IMG_CASH = "rbxassetid://84262748186110"
local GIFT_BOX_TEXTURE_ID = "130623477775352" -- ← YOUR GIFT BOX

-- ======== LAYOUT CONSTANTS ========
local FRAME_SCALE = 0.92
local TAB_ROW_Y = 0.36
local GP_ROW_EXTRA = 0.02

-- Move the content area up a touch
local CONTENT_TOP_Y = 0.472  -- was 0.50 → 0.48; now a bit higher

local BAR_WIDTH_FACTOR = 0.86
local CONTENT_WIDTH_FACTOR = 0.90
local CONTENT_HEIGHT_FACTOR = 0.48

-- Per-pill sizing
local CASH_H_FACTOR = 0.09
local GP_H_FACTOR = 0.095
local PILL_MIN_H = 72
local PILL_MAX_H = 120
local CASH_RATIO = 2.85
local GP_RATIO = 3.60

-- ======== CARD ART / GRID ========
local CARD_IMAGE = "rbxassetid://108251319294182"
local CARD_AR = 1.42               -- card art aspect (width/height)
local GRID_X_SCALE = 0.475         -- ~2 columns + padding
local CARD_INSET = 8               -- inner inset in pixels
local CARD_SIZE_MULT = 1.24        -- overall cell height boost

local USE_9_SLICE = false
local CARD_SLICE = Rect.new(60, 60, 944, 600)

-- ======== CARD CONTENT OFFSETS (fine-tune here) ========
local TITLE_X = 58                 -- Title more right for centering
local DESC_X = 32                  -- Description to the left
local TITLE_Y = 50                 -- Title lower and centered
local DESC_Y  = 80                 -- Below title
local BONUS_Y = 108                -- Below description, above button
local BTN_BOTTOM = -35             -- MUCH HIGHER (closer to bottom)

-- ======== UTILITIES ========
local function isMobile() return UserInputService.TouchEnabled and not GuiService:IsTenFootInterface() end
local function isPhone() if not isMobile() then return false end; local v=workspace.CurrentCamera.ViewportSize; return math.min(v.X,v.Y)<700 end
local function formatNumber(n) local s=tostring(n); local k=1; while k~=0 do s,k=s:gsub("^(-?%d+)(%d%d%d)","%1,%2") end return s end
local function blend(a,b,t) t=math.clamp(t,0,1); return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t) end
local function formatBonusText(b) return b and b > 0 and ("+%d%% Bonus"):format(math.floor(b*100)) or nil end

-- ======== THEME ========
local theme = {
	background = Color3.fromRGB(253,252,250),
	surface = Color3.fromRGB(255,255,255),
	surfaceAlt = Color3.fromRGB(246,248,252),
	stroke = Color3.fromRGB(222,226,235),
	text = Color3.fromRGB(35,38,46),
	textSecondary = Color3.fromRGB(120,126,140),
	accent = Color3.fromRGB(255,80,140),
	success = Color3.fromRGB(76,175,80),
	cinna = Color3.fromRGB(186,214,255),
	kuromi = Color3.fromRGB(200,190,255),
}

-- ======== CACHE ========
local Cache = {}; Cache.__index = Cache
function Cache.new(d) return setmetatable({data={},duration=d or 300},Cache) end
function Cache:set(k,v) self.data[k]={v=v,t=tick()} end
function Cache:get(k) local e=self.data[k]; if not e then return end; if tick()-e.t>self.duration then self.data[k]=nil; return end; return e.v end
function Cache:clear(k) if k then self.data[k]=nil else self.data={} end end

local productCache = Cache.new(300)
local ownershipCache = Cache.new(60)

-- ======== DATA ========
local products = {
	cash = {
		{ id = 3366419712, amount = 1000,    name = "1,000 Cash",    description = "Perfect starter pack", icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3366420012, amount = 5000,    name = "5,000 Cash",    description = "Great for early upgrades", icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3366420478, amount = 10000,   name = "10,000 Cash",   description = "Boost your progress fast", icon = "rbxassetid://10709728059", price = 0, bonus = 0.10 },
		{ id = 3366420800, amount = 25000,   name = "25,000 Cash",   description = "Popular choice for players", icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3424973374, amount = 50000,   name = "50,000 Cash",   description = "Major upgrade power", icon = "rbxassetid://10709728059", price = 0, bonus = 0.25 },
		{ id = 3424974046, amount = 100000,  name = "100,000 Cash",  description = "Supercharge your tycoon", icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3424974161, amount = 250000,  name = "250,000 Cash",  description = "Mega bundle for big dreams", icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3424974327, amount = 500000,  name = "500,000 Cash",  description = "Ultimate fortune awaits", icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3424974402, amount = 1000000, name = "1,000,000 Cash",description = "Max out everything!", icon = "rbxassetid://10709728059", price = 0, best = true, bonus = 0.35 },
	},
	gamepasses = {
		{ id = 1412171840, name = "Auto Collect", description = "Automatically collect all cash drops", icon = "rbxassetid://10709727148", price = 99,  hasToggle = true  },
		{ id = 1398974710, name = "2x Cash",      description = "Double all cash earned permanently",   icon = "rbxassetid://10709727148", price = 199, hasToggle = false },
	},
}

local function getProductInfo(id)
	local c=productCache:get(id); if c then return c end
	local ok,info=pcall(function() return MarketplaceService:GetProductInfo(id,Enum.InfoType.Product) end)
	if ok and info then productCache:set(id,info); return info end
end

local function getGamePassInfo(id)
	local key="pass_"..id; local c=productCache:get(key); if c then return c end
	local ok,info=pcall(function() return MarketplaceService:GetProductInfo(id,Enum.InfoType.GamePass) end)
	if ok and info then productCache:set(key,info); return info end
end

local function checkOwnership(passId)
	local key=("%d_%d"):format(Player.UserId,passId); local c=ownershipCache:get(key); if c~=nil then return c end
	local ok,owns=pcall(function() return MarketplaceService:UserOwnsGamePassAsync(Player.UserId,passId) end)
	if ok then ownershipCache:set(key,owns); return owns end; return false
end

local function refreshPrices()
	for _,p in ipairs(products.cash) do local i=getProductInfo(p.id); if i and i.PriceInRobux then p.price=i.PriceInRobux end end
	for _,gp in ipairs(products.gamepasses) do local i=getGamePassInfo(gp.id); if i and i.PriceInRobux then gp.price=i.PriceInRobux end end
end

-- ======== SOUND & EFFECTS ========
local sounds = {}
local function initSound()
	local cfg={click={"rbxassetid://876939830",0.45},hover={"rbxassetid://10066936758",0.2},open={"rbxassetid://452267918",0.5},success={"rbxassetid://876939830",0.6}}
	for name,data in pairs(cfg) do local s=Instance.new("Sound"); s.Name="SS_"..name; s.SoundId=data[1]; s.Volume=data[2]; s.Parent=SoundService; sounds[name]=s end
end
local function playSound(n) if sounds[n] then sounds[n]:Play() end end

local function pulse(frame)
	local s=frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale"); s.Parent=frame
	TweenService:Create(s,TweenInfo.new(0.1),{Scale=1.06}):Play(); task.delay(0.1,function() TweenService:Create(s,TweenInfo.new(0.18),{Scale=1}):Play() end)
end

local function confetti(parent)
	for i=1,8 do
		local chip=Instance.new("Frame"); chip.BackgroundColor3=(i%2==0) and theme.accent or theme.kuromi; chip.Size=UDim2.fromOffset(6,10); chip.Position=UDim2.new(math.random(),0,0,-6); chip.BorderSizePixel=0; chip.Parent=parent
		local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,2); c.Parent=chip
		task.spawn(function() TweenService:Create(chip,TweenInfo.new(0.45),{Position=UDim2.new(chip.Position.X.Scale,(math.random()-0.5)*60,0,math.random(60,110)),Rotation=math.random(-40,40)}):Play(); task.delay(0.46,function() chip:Destroy() end) end)
	end
end

-- ======== SHOP CLASS ========
local Shop = {}
Shop.__index = Shop

function Shop.new()
	local self = setmetatable({}, Shop)
	self.gui = nil
	self.mainFrame = nil
	self.buttonBar = nil
	self.cashContainer = nil
	self.gpContainer = nil
	self.cashBtn = nil
	self.gpBtn = nil
	self.contentFrame = nil
	self.cashPage = nil
	self.gpPage = nil
	self.toggleButton = nil
	self.blur = nil
	self.isOpen = false
	self.purchasePending = {}
	return self
end

function Shop:initialize()
	initSound()
	refreshPrices()
	self:createToggleButton()
	self:createMainInterface()
	self:setupHandlers()
	print("[SanrioShop] ✅ Perfect merge loaded!")
end

function Shop:createToggleButton()
	local sg = Instance.new("ScreenGui")
	sg.Name = "SanrioShopToggle"
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 999
	sg.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	sg.Parent = PlayerGui

	local size = isPhone() and UDim2.fromOffset(70,70) or UDim2.fromOffset(90,90)
	local pos = isPhone() and UDim2.new(1,-16,0,76) or UDim2.new(1,-16,0.5,-70)
	local anchor = isPhone() and Vector2.new(1,0) or Vector2.new(1,0.5)

	self.toggleButton = Instance.new("TextButton")
	self.toggleButton.Size = size
	self.toggleButton.Position = pos
	self.toggleButton.AnchorPoint = anchor
	self.toggleButton.BackgroundColor3 = theme.surface
	self.toggleButton.Text = ""
	self.toggleButton.AutoButtonColor = false
	self.toggleButton.Parent = sg

	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,16); corner.Parent = self.toggleButton
	local stroke = Instance.new("UIStroke"); stroke.Color = theme.accent; stroke.Thickness = 2; stroke.Parent = self.toggleButton

	local giftSize = isPhone() and 56 or 72
	local img = Instance.new("ImageLabel")
	img.Image = "rbxassetid://" .. GIFT_BOX_TEXTURE_ID
	img.Size = UDim2.fromOffset(giftSize, giftSize)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.BackgroundTransparency = 1
	img.Parent = self.toggleButton

	self.toggleButton.MouseButton1Click:Connect(function() self:toggle() end)
end

function Shop:makePill(name, imageId, ratio)
	local container = Instance.new("Frame")
	container.Name = name .. "Container"
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Size = UDim2.fromOffset(260, 86)
	container.ZIndex = 6
	container.Parent = self.buttonBar

	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = ratio
	ar.DominantAxis = Enum.DominantAxis.Width
	ar.Parent = container

	local btn = Instance.new("ImageButton")
	btn.Name = name .. "Button"
	btn.BackgroundTransparency = 1
	btn.AutoButtonColor = false
	btn.Size = UDim2.fromScale(1, 1)
	btn.Image = imageId
	btn.ScaleType = Enum.ScaleType.Crop
	btn.ZIndex = 7
	btn.Parent = container

	local function bump(mult)
		local sx = math.floor(container.Size.X.Offset * mult)
		local sy = math.floor(container.Size.Y.Offset * mult)
		TweenService:Create(container, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = UDim2.fromOffset(sx, sy)}):Play()
	end

	btn.MouseEnter:Connect(function() playSound("hover"); bump(1.02) end)
	btn.MouseLeave:Connect(function() bump(1.00) end)
	btn.MouseButton1Down:Connect(function() bump(0.98) end)
	btn.MouseButton1Up:Connect(function() bump(1.02) end)

	return container, btn
end

function Shop:createMainInterface()
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "SanrioShopMain"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 1000
	self.gui.Enabled = false
	self.gui.IgnoreGuiInset = true
	self.gui.Parent = PlayerGui

	self.blur = Lighting:FindFirstChild("SanrioShopBlur") or Instance.new("BlurEffect")
	self.blur.Name = "SanrioShopBlur"
	self.blur.Size = 0
	self.blur.Parent = Lighting

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.38
	dim.BorderSizePixel = 0
	dim.Parent = self.gui

	self.mainFrame = Instance.new("ImageLabel")
	self.mainFrame.Name = "MainFrame"
	self.mainFrame.BackgroundTransparency = 1
	self.mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.mainFrame.Position = UDim2.fromScale(0.5, 0.5)
	self.mainFrame.Size = UDim2.fromScale(FRAME_SCALE, FRAME_SCALE)
	self.mainFrame.Image = IMG_FRAME
	self.mainFrame.ScaleType = Enum.ScaleType.Fit
	self.mainFrame.ZIndex = 1
	self.mainFrame.Parent = self.gui

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = self.mainFrame

	self.buttonBar = Instance.new("Frame")
	self.buttonBar.Name = "ButtonBar"
	self.buttonBar.BackgroundTransparency = 1
	self.buttonBar.AnchorPoint = Vector2.new(0.5, 0)
	self.buttonBar.Position = UDim2.fromScale(0.5, TAB_ROW_Y)
	self.buttonBar.Size = UDim2.fromScale(BAR_WIDTH_FACTOR, 0)
	self.buttonBar.ZIndex = 5
	self.buttonBar.Parent = self.mainFrame

	self.cashContainer, self.cashBtn = self:makePill("Cash", IMG_CASH, CASH_RATIO)
	self.gpContainer, self.gpBtn = self:makePill("Gamepasses", IMG_GAMEPASSES, GP_RATIO)

	self.contentFrame = Instance.new("Frame")
	self.contentFrame.Name = "Content"
	self.contentFrame.AnchorPoint = Vector2.new(0.5, 0)
	self.contentFrame.Position = UDim2.fromScale(0.5, CONTENT_TOP_Y)
	self.contentFrame.Size = UDim2.fromScale(CONTENT_WIDTH_FACTOR, CONTENT_HEIGHT_FACTOR)
	self.contentFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	self.contentFrame.BackgroundTransparency = 0.88
	self.contentFrame.ZIndex = 3
	self.contentFrame.Parent = self.mainFrame

	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = UDim.new(0, 20)
	contentCorner.Parent = self.contentFrame

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

		local cellW = math.ceil(usable * GRID_X_SCALE)
		local cellH = math.max(120, math.ceil((cellW / CARD_AR) * CARD_SIZE_MULT))
		grid.CellSize = UDim2.new(GRID_X_SCALE, 0, 0, cellH)
	end

	grid.Parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(recalc)
	self.contentFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(recalc)
	RunService.Heartbeat:Connect(recalc)
	task.defer(recalc)
end

function Shop:createPages()
	self.cashPage = Instance.new("ScrollingFrame")
	self.cashPage.Name = "CashPage"
	self.cashPage.BackgroundTransparency = 1
	self.cashPage.BorderSizePixel = 0
	self.cashPage.ScrollBarThickness = 6
	self.cashPage.ScrollBarImageColor3 = theme.accent
	self.cashPage.Visible = true
	self.cashPage.Size = UDim2.fromScale(1, 1)
	self.cashPage.ZIndex = 4
	self.cashPage.Parent = self.contentFrame

	-- Padding (slightly smaller on top so cards start higher)
	local cashPad = Instance.new("UIPadding")
	cashPad.PaddingTop = UDim.new(0, 6)       -- was 12
	cashPad.PaddingBottom = UDim.new(0, 12)
	cashPad.PaddingLeft = UDim.new(0, 8)
	cashPad.PaddingRight = UDim.new(0, 8)
	cashPad.Parent = self.cashPage

	-- CASH GRID
	local cashGrid = Instance.new("UIGridLayout")
	cashGrid.CellSize = UDim2.new(GRID_X_SCALE, 0, 0, 120) -- temp; auto-height overrides
	cashGrid.CellPadding = UDim2.fromOffset(18, 40)
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
	self.gpPage.Name = "GamepassPage"
	self.gpPage.BackgroundTransparency = 1
	self.gpPage.BorderSizePixel = 0
	self.gpPage.ScrollBarThickness = 5
	self.gpPage.ScrollBarImageColor3 = theme.accent
	self.gpPage.Visible = false
	self.gpPage.Size = UDim2.fromScale(1, 1)
	self.gpPage.ZIndex = 4
	self.gpPage.Parent = self.contentFrame

	local gpPad = Instance.new("UIPadding")
	gpPad.PaddingTop = UDim.new(0, 6)         -- was 8
	gpPad.PaddingBottom = UDim.new(0, 12)
	gpPad.PaddingLeft = UDim.new(0, 8)
	gpPad.PaddingRight = UDim.new(0, 8)
	gpPad.Parent = self.gpPage

	-- GP GRID
	local gpGrid = Instance.new("UIGridLayout")
	gpGrid.CellSize = UDim2.new(GRID_X_SCALE, 0, 0, 120)
	gpGrid.CellPadding = UDim2.fromOffset(18, 40)
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

	-- Cell container (fills the grid cell; no visual)
	local container = Instance.new("Frame")
	container.Name = product.name .. "Cell"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.LayoutOrder = product.LayoutOrder or 1
	container.Parent = parent

	-- Visible card background (fills the cell with a small inset)
	local bg = Instance.new("ImageLabel")
	bg.Name = "CardBG"
	bg.BackgroundTransparency = 1
	bg.Image = CARD_IMAGE
	bg.Position = UDim2.fromOffset(CARD_INSET, CARD_INSET)
	bg.Size = UDim2.new(1, -2*CARD_INSET, 1, -2*CARD_INSET)
	bg.Parent = container

	if USE_9_SLICE then
		bg.ScaleType = Enum.ScaleType.Slice
		bg.SliceCenter = CARD_SLICE
	else
		bg.ScaleType = Enum.ScaleType.Crop
	end

	-- Inner content
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -32, 1, -24)
	content.Position = UDim2.fromOffset(16, 12)
	content.BackgroundTransparency = 1
	content.Parent = bg

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.80, 0, 0, 32)  -- Nice size
	nameLabel.Position = UDim2.fromOffset(TITLE_X, TITLE_Y)  -- More right, centered
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = product.name
	nameLabel.TextColor3 = theme.text
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextSize = 21  -- BIGGER (was 19)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = content

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(0.85, 0, 0, 36)
	descLabel.Position = UDim2.fromOffset(DESC_X, DESC_Y)  -- More to the left
	descLabel.BackgroundTransparency = 1
	descLabel.Text = product.description
	descLabel.TextColor3 = theme.textSecondary
	descLabel.Font = Enum.Font.FredokaOne
	descLabel.TextSize = 14
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextWrapped = true
	descLabel.Parent = content

	-- Bonus badge
	if product.bonus and product.bonus > 0 then
		local bonusBadge = Instance.new("Frame")
		bonusBadge.Size = UDim2.fromOffset(80, 26)  -- Slightly bigger
		bonusBadge.Position = UDim2.fromOffset(DESC_X, BONUS_Y)  -- Same X as description
		bonusBadge.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
		bonusBadge.BorderSizePixel = 0
		bonusBadge.Parent = content
		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0, 8)
		badgeCorner.Parent = bonusBadge

		local bonusText = Instance.new("TextLabel")
		bonusText.Size = UDim2.fromScale(1, 1)
		bonusText.BackgroundTransparency = 1
		bonusText.Text = "+" .. math.floor(product.bonus * 100) .. "% Bonus"
		bonusText.TextColor3 = Color3.fromRGB(139, 69, 19)
		bonusText.Font = Enum.Font.FredokaOne
		bonusText.TextSize = 12  -- Slightly bigger (was 11)
		bonusText.Parent = bonusBadge
	end

	-- Best value badge
	if product.best then
		local bestBadge = Instance.new("Frame")
		bestBadge.Size = UDim2.fromOffset(90, 26)
		bestBadge.Position = UDim2.new(1, -96, 0, 10)
		bestBadge.BackgroundColor3 = Color3.fromRGB(255, 64, 129)
		bestBadge.BorderSizePixel = 0
		bestBadge.Parent = content
		local bestCorner = Instance.new("UICorner")
		bestCorner.CornerRadius = UDim.new(0, 10)
		bestCorner.Parent = bestBadge

		local bestText = Instance.new("TextLabel")
		bestText.Size = UDim2.fromScale(1, 1)
		bestText.BackgroundTransparency = 1
		bestText.Text = "BEST VALUE"
		bestText.TextColor3 = Color3.new(1, 1, 1)
		bestText.Font = Enum.Font.FredokaOne
		bestText.TextSize = 12
		bestText.Parent = bestBadge
	end

	-- Purchase / Toggle button (raised a bit)
	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(0.78, 0, 0, 36)
	buyBtn.Position = UDim2.new(0.48, 0, 1, BTN_BOTTOM)  -- Slightly left (was 0.5, now 0.48)
	buyBtn.AnchorPoint = Vector2.new(0.5, 0)
	buyBtn.BackgroundColor3 = accentColor
	buyBtn.Text = "BUY - R$" .. tostring(product.price or 0)
	buyBtn.TextColor3 = Color3.new(1, 1, 1)
	buyBtn.Font = Enum.Font.FredokaOne
	buyBtn.TextSize = 15
	buyBtn.AutoButtonColor = false
	buyBtn.BorderSizePixel = 0
	buyBtn.Parent = content
	local btnCorner = Instance.new("UICorner"); btnCorner.CornerRadius = UDim.new(0, 12); btnCorner.Parent = buyBtn

	buyBtn.MouseEnter:Connect(function()
		playSound("hover")
		TweenService:Create(buyBtn,TweenInfo.new(0.12),{BackgroundColor3=blend(accentColor, Color3.new(1,1,1), 0.2)}):Play()
	end)
	buyBtn.MouseLeave:Connect(function()
		if not owned or (isGamepass and product.hasToggle) then
			TweenService:Create(buyBtn,TweenInfo.new(0.12),{BackgroundColor3=accentColor}):Play()
		end
	end)

	if isGamepass and product.hasToggle and owned then
		buyBtn.Size = UDim2.new(0.6, 0, 0, 36)
		buyBtn.Position = UDim2.new(0.3, 0, 1, BTN_BOTTOM)
		buyBtn.AnchorPoint = Vector2.new(0, 0)
		buyBtn.Text = "OFF"
		local state = false
		if Remotes then
			local rf = Remotes:FindFirstChild("GetAutoCollectState")
			if rf and rf:IsA("RemoteFunction") then
				local ok, val = pcall(function() return rf:InvokeServer() end)
				if ok and type(val) == "boolean" then state = val end
			end
		end

		local function paint(on)
			state = on
			if on then
				buyBtn.BackgroundColor3 = theme.success
				buyBtn.Text = "ON"
			else
				buyBtn.BackgroundColor3 = theme.stroke
				buyBtn.Text = "OFF"
			end
		end
		paint(state)

		buyBtn.MouseButton1Click:Connect(function()
			local nextState = not state
			paint(nextState)
			playSound("click")
			if Remotes then
				local ev = Remotes:FindFirstChild("AutoCollectToggle")
				if ev and ev:IsA("RemoteEvent") then ev:FireServer(nextState) end
			end
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

	-- Effects target the visible bg
	product.cardInstance = bg
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

		self.contentFrame.Size = UDim2.new(0, math.floor(H * CONTENT_WIDTH_FACTOR), 0, math.floor(H * CONTENT_HEIGHT_FACTOR))
		self.contentFrame.Position = UDim2.fromScale(0.5, CONTENT_TOP_Y)
	end

	self.mainFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	RunService.Heartbeat:Connect(resize)
	task.defer(resize)
end

function Shop:showCash()
	self.cashPage.Visible = true
	self.gpPage.Visible = false
	playSound("click")
end

function Shop:showGamepasses()
	self.cashPage.Visible = false
	self.gpPage.Visible = true
	playSound("click")
end

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
			button.Text = "R$" .. tostring(product.price or 0)
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
			gp.purchaseButton.Text = owned and "✓ Owned" or ("R$" .. tostring(gp.price or 0))
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
	TweenService:Create(self.mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.fromScale(0.5, 0.5)
	}):Play()

	self:showCash()
	playSound("open")
end

function Shop:close()
	if not self.isOpen then return end
	self.isOpen = false
	TweenService:Create(self.blur, TweenInfo.new(0.15), {Size = 0}):Play()
	TweenService:Create(self.mainFrame, TweenInfo.new(0.15), {
		Position = UDim2.fromScale(0.5, 0.52)
	}):Play()
	task.wait(0.15)
	self.gui.Enabled = false
end

function Shop:toggle()
	if self.isOpen then
		self:close()
	else
		self:open()
	end
end

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
			p.button.Text = purchased and "✓ Owned" or ("R$" .. tostring(p.product.price or 0))
			p.button.Active = not purchased
		end
		self.purchasePending[passId] = nil
		if purchased then
			ownershipCache:clear()
			task.wait(0.8)
			self:refreshAllProducts()
			playSound("success")
			if p and p.product and p.product.cardInstance then
				pulse(p.product.cardInstance)
				confetti(p.product.cardInstance)
			end
		end
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, purchased)
		if player ~= Player then return end
		local p = self.purchasePending[productId]
		if p and p.button and p.button.Parent then
			p.button.Text = "R$" .. tostring(p.product.price or 0)
			p.button.Active = true
		end
		self.purchasePending[productId] = nil
		if purchased then
			playSound("success")
			if p and p.product and p.product.cardInstance then
				pulse(p.product.cardInstance)
				confetti(p.product.cardInstance)
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

print("[SanrioShop] ✨ GODLY POLISHED - Dynamic aspect-ratio sizing!")
print("[SanrioShop] 🎨 Cards properly sized with optimized constants!")
print("[SanrioShop] 📐 Grid: " .. GRID_X_SCALE .. " scale, " .. CARD_SIZE_MULT .. "x mult, " .. CARD_INSET .. "px inset")
print("[SanrioShop] 🎚️ Offsets → TEXT_X:"..TEXT_X..", TITLE_Y:"..TITLE_Y..", DESC_Y:"..DESC_Y..", BONUS_Y:"..BONUS_Y..", BTN_BOTTOM:"..BTN_BOTTOM)
print("[SanrioShop] 💎 Clean layout with proper descriptions & badges")
print("[SanrioShop] 🎁 Gift box texture:", GIFT_BOX_TEXTURE_ID)

return shop
