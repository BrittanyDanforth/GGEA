--[[
    SANRIO SHOP — FINAL MERGED VERSION
    Clean pill buttons + Full shop functionality
    ✨ Mobile-optimized, sales features, gift box, confetti, toggles
--]]

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

-- ======== CORE UTILS ========
local function isMobile() return UserInputService.TouchEnabled and not GuiService:IsTenFootInterface() end
local function isPhone() if not isMobile() then return false end; local cam=workspace.CurrentCamera; local v=cam.ViewportSize; return math.min(v.X,v.Y)<700 end
local function formatNumber(n) local s=tostring(n); local k=1; while k~=0 do s,k=s:gsub("^(-?%d+)(%d%d%d)","%1,%2") end; return s end
local function blend(a,b,t) t=math.clamp(t,0,1); return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t) end

-- ======== DATA ========
local products = {
	cash = {
		{ id = 3366419712, amount = 1000,    name = "1,000 Cash",    description = "Includes 1,000 Cash",    icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3366420012, amount = 5000,    name = "5,000 Cash",    description = "Includes 5,000 Cash",    icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3366420478, amount = 10000,   name = "10,000 Cash",   description = "Includes 10,000 Cash",   icon = "rbxassetid://10709728059", price = 0, bonus = 0.10 },
		{ id = 3366420800, amount = 25000,   name = "25,000 Cash",   description = "Includes 25,000 Cash",   icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3424973374, amount = 50000,   name = "50,000 Cash",   description = "Includes 50,000 Cash",   icon = "rbxassetid://10709728059", price = 0, bonus = 0.25 },
		{ id = 3424974046, amount = 100000,  name = "100,000 Cash",  description = "Includes 100,000 Cash",  icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3424974161, amount = 250000,  name = "250,000 Cash",  description = "Includes 250,000 Cash",  icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3424974327, amount = 500000,  name = "500,000 Cash",  description = "Includes 500,000 Cash",  icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3424974402, amount = 1000000, name = "1,000,000 Cash",description = "Includes 1,000,000 Cash",icon = "rbxassetid://10709728059", price = 0, best = true, bonus = 0.35 },
	},
	gamepasses = {
		{ id = 1412171840, name = "Auto Collect", description = "Automatically collect all cash drops", icon = "rbxassetid://10709727148", price = 99,  hasToggle = true  },
		{ id = 1398974710, name = "2x Cash",      description = "Double all cash earned permanently",   icon = "rbxassetid://10709727148", price = 199, hasToggle = false },
	},
}

-- ======== CACHE ========
local Cache = {}; Cache.__index = Cache
function Cache.new(d) return setmetatable({data={},duration=d or 300},Cache) end
function Cache:set(k,v) self.data[k]={v=v,t=tick()} end
function Cache:get(k) local e=self.data[k]; if not e then return end; if tick()-e.t>self.duration then self.data[k]=nil; return end; return e.v end
function Cache:clear(k) if k then self.data[k]=nil else self.data={} end end

local productCache = Cache.new(300)
local ownershipCache = Cache.new(60)

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

-- ======== SOUND ========
local sounds = {}
local function initSound()
	local cfg={click={"rbxassetid://876939830",0.45},hover={"rbxassetid://10066936758",0.2},open={"rbxassetid://452267918",0.5},success={"rbxassetid://876939830",0.6}}
	for name,data in pairs(cfg) do local s=Instance.new("Sound"); s.Name="SS_"..name; s.SoundId=data[1]; s.Volume=data[2]; s.Parent=SoundService; sounds[name]=s end
end
local function playSound(n) if sounds[n] then sounds[n]:Play() end end

-- ======== EFFECTS ========
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
	self.contentFrame = nil
	self.currentTab = "Cash"
	self.cashBtn = nil
	self.gpBtn = nil
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
	print("[SanrioShop] ✅ Initialized!")
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

function Shop:createMainInterface()
	-- Main ScreenGui
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "SanrioShopMain"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 1000
	self.gui.Enabled = false
	self.gui.IgnoreGuiInset = true
	self.gui.Parent = PlayerGui

	-- Blur
	self.blur = Lighting:FindFirstChild("SanrioShopBlur") or Instance.new("BlurEffect")
	self.blur.Name = "SanrioShopBlur"
	self.blur.Size = 0
	self.blur.Parent = Lighting

	-- Dim background
	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.38
	dim.BorderSizePixel = 0
	dim.Parent = self.gui

	-- Main frame with background image
	self.mainFrame = Instance.new("ImageLabel")
	self.mainFrame.Name = "MainFrame"
	self.mainFrame.Size = UDim2.fromScale(0.75, 0.75)
	self.mainFrame.Position = UDim2.fromScale(0.5, 0.5)
	self.mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.mainFrame.Image = IMG_FRAME
	self.mainFrame.ScaleType = Enum.ScaleType.Fit
	self.mainFrame.BackgroundTransparency = 1
	self.mainFrame.Parent = self.gui

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = self.mainFrame

	-- Button bar (for pill buttons)
	self.buttonBar = Instance.new("Frame")
	self.buttonBar.Name = "ButtonBar"
	self.buttonBar.BackgroundTransparency = 1
	self.buttonBar.AnchorPoint = Vector2.new(0.5, 0)
	self.buttonBar.Position = UDim2.fromScale(0.5, 0.30) -- Positioned nicely under header
	self.buttonBar.Size = UDim2.fromScale(0.80, 0) -- Height set dynamically
	self.buttonBar.Parent = self.mainFrame

	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	buttonLayout.Padding = UDim.new(0, 18)
	buttonLayout.Parent = self.buttonBar

	-- Create pill buttons
	self.cashBtn = self:createPillButton("Cash", IMG_CASH, self.buttonBar)
	self.gpBtn = self:createPillButton("Gamepasses", IMG_GAMEPASSES, self.buttonBar)

	-- Content area
	self.contentFrame = Instance.new("Frame")
	self.contentFrame.Name = "Content"
	self.contentFrame.AnchorPoint = Vector2.new(0.5, 0)
	self.contentFrame.Position = UDim2.fromScale(0.5, 0.50) -- Below buttons
	self.contentFrame.Size = UDim2.fromScale(0.85, 0.42)
	self.contentFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	self.contentFrame.BackgroundTransparency = 0.88
	self.contentFrame.BorderSizePixel = 0
	self.contentFrame.Parent = self.mainFrame

	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = UDim.new(0, 20)
	contentCorner.Parent = self.contentFrame

	-- Pages
	self:createPages()

	-- Dynamic sizing
	self:setupDynamicSizing()
end

function Shop:createPillButton(name, imageId, parent)
	local container = Instance.new("Frame")
	container.Name = name .. "Container"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromOffset(240, 80) -- Placeholder
	container.Parent = parent

	local btn = Instance.new("ImageButton")
	btn.Name = name .. "Button"
	btn.Size = UDim2.fromScale(1, 1)
	btn.BackgroundTransparency = 1
	btn.Image = imageId
	btn.ScaleType = Enum.ScaleType.Crop
	btn.AutoButtonColor = false
	btn.Parent = container

	-- Hover effects
	local function bump(mult)
		local sx = math.floor(container.Size.X.Offset * mult)
		local sy = math.floor(container.Size.Y.Offset * mult)
		TweenService:Create(container, TweenInfo.new(0.12), {Size = UDim2.fromOffset(sx, sy)}):Play()
	end

	btn.MouseEnter:Connect(function() playSound("hover"); bump(1.02) end)
	btn.MouseLeave:Connect(function() bump(1.00) end)
	btn.MouseButton1Down:Connect(function() bump(0.98) end)
	btn.MouseButton1Up:Connect(function() bump(1.02) end)

	btn.MouseButton1Click:Connect(function()
		playSound("click")
		if name == "Cash" then
			self:showCash()
		else
			self:showGamepasses()
		end
	end)

	return container
end

function Shop:createPages()
	-- Cash page
	self.cashPage = Instance.new("ScrollingFrame")
	self.cashPage.Name = "CashPage"
	self.cashPage.Size = UDim2.fromScale(1, 1)
	self.cashPage.BackgroundTransparency = 1
	self.cashPage.BorderSizePixel = 0
	self.cashPage.ScrollBarThickness = 6
	self.cashPage.ScrollBarImageColor3 = theme.accent
	self.cashPage.Visible = true
	self.cashPage.Parent = self.contentFrame

	local cashGrid = Instance.new("UIGridLayout")
	cashGrid.CellSize = UDim2.new(0.48, 0, 0, 110)
	cashGrid.CellPadding = UDim2.fromOffset(12, 12)
	cashGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cashGrid.SortOrder = Enum.SortOrder.LayoutOrder
	cashGrid.Parent = self.cashPage

	cashGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.cashPage.CanvasSize = UDim2.new(0, 0, 0, cashGrid.AbsoluteContentSize.Y + 20)
	end)

	for _, p in ipairs(products.cash) do
		self:createProductCard(p, "cash", self.cashPage)
	end

	-- Gamepasses page
	self.gpPage = Instance.new("ScrollingFrame")
	self.gpPage.Name = "GamepassPage"
	self.gpPage.Size = UDim2.fromScale(1, 1)
	self.gpPage.BackgroundTransparency = 1
	self.gpPage.BorderSizePixel = 0
	self.gpPage.ScrollBarThickness = 6
	self.gpPage.ScrollBarImageColor3 = theme.accent
	self.gpPage.Visible = false
	self.gpPage.Parent = self.contentFrame

	local gpGrid = Instance.new("UIGridLayout")
	gpGrid.CellSize = UDim2.new(0.48, 0, 0, 110)
	gpGrid.CellPadding = UDim2.fromOffset(12, 12)
	gpGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gpGrid.SortOrder = Enum.SortOrder.LayoutOrder
	gpGrid.Parent = self.gpPage

	gpGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.gpPage.CanvasSize = UDim2.new(0, 0, 0, gpGrid.AbsoluteContentSize.Y + 20)
	end)

	for _, gp in ipairs(products.gamepasses) do
		self:createProductCard(gp, "gamepass", self.gpPage)
	end
end

function Shop:createProductCard(product, productType, parent)
	local isGamepass = (productType == "gamepass")
	local cardColor = isGamepass and theme.kuromi or theme.cinna

	local card = Instance.new("TextButton")
	card.Name = product.name .. "Card"
	card.BackgroundColor3 = theme.surface
	card.BorderSizePixel = 0
	card.AutoButtonColor = false
	card.Text = ""
	card.Parent = parent

	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 12); corner.Parent = card
	local stroke = Instance.new("UIStroke"); stroke.Color = cardColor; stroke.Thickness = 2; stroke.Transparency = 0.5; stroke.Parent = card

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 24)
	title.Position = UDim2.fromOffset(8, 8)
	title.BackgroundTransparency = 1
	title.Text = product.name
	title.TextColor3 = theme.text
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Parent = card

	-- Description
	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -16, 0, 32)
	desc.Position = UDim2.fromOffset(8, 34)
	desc.BackgroundTransparency = 1
	desc.Text = isGamepass and product.description or (formatNumber(product.amount) .. " Cash")
	desc.TextColor3 = theme.textSecondary
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 13
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextWrapped = true
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.Parent = card

	-- Price + Button
	local btnY = isGamepass and 70 or 66
	local owned = isGamepass and checkOwnership(product.id)

	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(1, -16, 0, 32)
	buyBtn.Position = UDim2.fromOffset(8, btnY)
	buyBtn.BackgroundColor3 = owned and theme.success or cardColor
	buyBtn.Text = owned and "✓ Owned" or ("R$" .. tostring(product.price or 0))
	buyBtn.TextColor3 = Color3.new(1, 1, 1)
	buyBtn.Font = Enum.Font.GothamBold
	buyBtn.TextSize = 15
	buyBtn.AutoButtonColor = false
	buyBtn.Active = not owned
	buyBtn.Parent = card

	local btnCorner = Instance.new("UICorner"); btnCorner.CornerRadius = UDim.new(0, 8); btnCorner.Parent = buyBtn

	buyBtn.MouseButton1Click:Connect(function()
		if owned then return end
		buyBtn.Text = "..."
		buyBtn.Active = false
		self:promptPurchase(product, productType, buyBtn)
	end)

	-- Toggle for Auto Collect
	if isGamepass and product.hasToggle and owned then
		self:addToggleSwitch(product, card)
	end

	product.cardInstance = card
	product.purchaseButton = buyBtn
end

function Shop:addToggleSwitch(product, card)
	local toggle = Instance.new("Frame")
	toggle.Name = "Toggle"
	toggle.Size = UDim2.fromOffset(140, 28)
	toggle.Position = UDim2.new(1, -8, 0, 8)
	toggle.AnchorPoint = Vector2.new(1, 0)
	toggle.BackgroundColor3 = theme.surface
	toggle.BorderSizePixel = 0
	toggle.Parent = card

	local toggleCorner = Instance.new("UICorner"); toggleCorner.CornerRadius = UDim.new(0, 14); toggleCorner.Parent = toggle
	local toggleStroke = Instance.new("UIStroke"); toggleStroke.Color = theme.stroke; toggleStroke.Thickness = 1; toggleStroke.Parent = toggle

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Auto: OFF"
	label.TextColor3 = theme.text
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.Parent = toggle

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromScale(1, 1)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = toggle

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
			toggle.BackgroundColor3 = theme.success
			toggleStroke.Color = theme.success
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Text = "Auto: ON"
		else
			toggle.BackgroundColor3 = theme.surface
			toggleStroke.Color = theme.stroke
			label.TextColor3 = theme.text
			label.Text = "Auto: OFF"
		end
	end

	paint(state)

	btn.MouseButton1Click:Connect(function()
		local nextState = not state
		paint(nextState)
		playSound("click")
		if Remotes then
			local ev = Remotes:FindFirstChild("AutoCollectToggle")
			if ev and ev:IsA("RemoteEvent") then ev:FireServer(nextState) end
		end
	end)
end

function Shop:setupDynamicSizing()
	local function resize()
		local H = self.mainFrame.AbsoluteSize.Y
		if H <= 0 then return end

		-- Button sizing: 7% of frame height, clamped
		local btnH = math.clamp(math.floor(H * 0.075), 65, 95)
		local cashW = math.floor(btnH * 3.2) -- aspect ratio for cash
		local gpW = math.floor(btnH * 3.5)   -- slightly wider for gamepasses

		self.buttonBar.Size = UDim2.new(0.80, 0, 0, btnH)

		self.cashBtn.Size = UDim2.fromOffset(cashW, btnH)
		self.gpBtn.Size = UDim2.fromOffset(gpW, btnH)
	end

	self.mainFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	RunService.Heartbeat:Connect(resize)
	task.defer(resize)
end

function Shop:showCash()
	self.cashPage.Visible = true
	self.gpPage.Visible = false
	self.currentTab = "Cash"
end

function Shop:showGamepasses()
	self.cashPage.Visible = false
	self.gpPage.Visible = true
	self.currentTab = "Gamepasses"
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
	local sz = self.mainFrame.Size
	self.mainFrame.Size = UDim2.new(sz.X.Scale * 0.94, 0, sz.Y.Scale * 0.94, 0)
	TweenService:Create(self.mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = sz
	}):Play()

	self:showCash()
	playSound("open")
end

function Shop:close()
	if not self.isOpen then return end
	self.isOpen = false
	TweenService:Create(self.blur, TweenInfo.new(0.15), {Size = 0}):Play()
	TweenService:Create(self.mainFrame, TweenInfo.new(0.15), {
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(self.mainFrame.Size.X.Scale * 0.94, 0, self.mainFrame.Size.Y.Scale * 0.94, 0)
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
	-- Input
	UserInputService.InputBegan:Connect(function(i, gp)
		if gp then return end
		if i.KeyCode == Enum.KeyCode.M then self:toggle() end
		if i.KeyCode == Enum.KeyCode.Escape and self.isOpen then self:close() end
	end)

	-- Remotes
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

	-- Purchase callbacks
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

-- ======== BOOT ========
local shop = Shop.new()
shop:initialize()

Player.CharacterAdded:Connect(function()
	task.wait(1)
	if not shop.toggleButton or not shop.toggleButton.Parent then
		shop:createToggleButton()
	end
end)

print("[SanrioShop] ✅ Final merged version loaded!")
print("[SanrioShop] 🎁 Gift box texture:", GIFT_BOX_TEXTURE_ID)
return shop
