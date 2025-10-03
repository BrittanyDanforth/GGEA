-- TycoonShopUI (LocalScript) — v6.0.0
-- Place in: StarterPlayer > StarterPlayerScripts
-- Normal Luau (no types). Roblox API only. Production-quality, mobile-first.

-- Services
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Remotes (assume)
local RemotesFolder = ReplicatedStorage:FindFirstChild("TycoonRemotes")

-- Visual Tokens (modern-cute)
local Palette = {
	bg          = Color3.fromRGB(250, 247, 245),
	surface     = Color3.fromRGB(255, 255, 255),
	surfaceAlt  = Color3.fromRGB(246, 242, 246),
	stroke      = Color3.fromRGB(224, 214, 220),
	text        = Color3.fromRGB(42, 38, 54),
	text2       = Color3.fromRGB(116, 108, 132),
	mint        = Color3.fromRGB(178, 224, 214), -- cash accent
	lav         = Color3.fromRGB(206, 196, 255), -- pass accent
	ok          = Color3.fromRGB(125, 194, 144),
	warn        = Color3.fromRGB(245, 201, 120),
	danger      = Color3.fromRGB(255, 120, 140),
}
local Fonts = {
	title = Enum.Font.GothamBold,
	semi  = Enum.Font.GothamSemibold,
	med   = Enum.Font.GothamMedium,
	reg   = Enum.Font.Gotham,
}

-- Asset placeholders (TODO: replace with crisp IDs)
local ICON_CASH = "rbxassetid://18420350532"
local ICON_PASS = "rbxassetid://18420350433"
local ICON_SHOP = "rbxassetid://17398522865"
local VIGNETTE  = "rbxassetid://7743879747"

-- Gamepass IDs (TODO: replace)
local PASS_AUTO_COLLECT = 1412171840
local PASS_2X_CASH      = 1398974710

-- Products (edit to your real IDs)
local ProductsData = {
	cash = {
		{ id = 1111111001, amount = 5000,     name = "5K Cash",  description = "Kickstart upgrades.", icon = ICON_CASH },
		{ id = 1111111002, amount = 10000,    name = "10K Cash", description = "Expand faster.",      icon = ICON_CASH },
		{ id = 1111111003, amount = 15000,    name = "15K Cash", description = "Boost progress.",     icon = ICON_CASH },
		{ id = 1111111004, amount = 50000,    name = "50K Cash", description = "Major upgrade push.", icon = ICON_CASH },
	},
	gamepasses = {
		{ id = PASS_AUTO_COLLECT, name = "Auto Collect", description = "Hands-free register", icon = ICON_PASS, hasToggle = true },
		{ id = PASS_2X_CASH,      name = "2x Cash",      description = "Double every sale",  icon = ICON_PASS, hasToggle = false },
	}
}

-- Timers
local ANIM_FAST, ANIM_MED, ANIM_SLOW = 0.12, 0.22, 0.32
local PURCHASE_TIMEOUT = 15
local PRICE_REFRESH_INTERVAL = 30
local OWNERSHIP_TTL = 60
local PRICE_TTL = 300

-- Cache
local function newCache(ttl) return { ttl = ttl, data = {} } end
local function cacheSet(cache, key, value) cache.data[key] = { v = value, t = os.clock() } end
local function cacheGet(cache, key)
	local e = cache.data[key]
	if not e then return nil end
	if os.clock() - e.t > cache.ttl then cache.data[key] = nil return nil end
	return e.v
end
local priceCache = newCache(PRICE_TTL)
local ownsCache  = newCache(OWNERSHIP_TTL)

-- Utils
local function fmtNum(n)
	local s, k = tostring(n), 0
	repeat s, k = s:gsub("^(%-?%d+)(%d%d%d)", "%1,%2") until k == 0
	return s
end
local function fmtShort(n)
	if n >= 1e9 then return string.format("%.1fB", n/1e9):gsub("%.0B","B") end
	if n >= 1e6 then return string.format("%.1fM", n/1e6):gsub("%.0M","M") end
	if n >= 1e3 then return string.format("%.1fK", n/1e3):gsub("%.0K","K") end
	return tostring(n)
end
local function tween(inst, props, dur, style, dir)
	local info = TweenInfo.new(dur or ANIM_MED, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
	local tw = TweenService:Create(inst, info, props); tw:Play(); return tw
end
local function corner(inst, r) local c = Instance.new("UICorner"); c.CornerRadius = r or UDim.new(0,14); c.Parent = inst end
local function stroke(inst, color, thick, tr)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color or Palette.stroke
	s.Thickness = thick or 1
	s.Transparency = tr or 0.25
	s.Parent = inst
end
local function pad(inst, t, r, b, l)
	local p = Instance.new("UIPadding")
	if t then p.PaddingTop = t end
	if r then p.PaddingRight = r end
	if b then p.PaddingBottom = b end
	if l then p.PaddingLeft = l end
	p.Parent = inst
end
local function textLabel(props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = props.Font or Fonts.reg
	t.Text = props.Text or ""
	t.TextSize = props.TextSize or 18
	t.TextColor3 = props.TextColor3 or Palette.text
	t.TextWrapped = true
	t.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	t.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
	t.Size = props.Size or UDim2.fromScale(1, 0)
	t.AnchorPoint = props.AnchorPoint or Vector2.new(0,0)
	t.Position = props.Position or UDim2.fromScale(0,0)
	t.ZIndex = props.ZIndex or 1
	t.Name = props.Name or "Text"
	if props.Parent then t.Parent = props.Parent end
	return t
end
local function imageLabel(props)
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.Image = props.Image or ""
	i.ImageColor3 = props.ImageColor3 or Color3.new(1,1,1)
	i.ImageTransparency = props.ImageTransparency or 0
	i.ScaleType = props.ScaleType or Enum.ScaleType.Fit
	i.Size = props.Size or UDim2.fromScale(0.1, 0.1)
	i.AnchorPoint = props.AnchorPoint or Vector2.new(0,0)
	i.Position = props.Position or UDim2.fromScale(0,0)
	i.ZIndex = props.ZIndex or 1
	i.Name = props.Name or "Image"
	if props.Parent then i.Parent = props.Parent end
	return i
end
local function button(props)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = props.BackgroundColor3 or Palette.mint
	b.Font = props.Font or Fonts.semi
	b.Text = props.Text or "Button"
	b.TextSize = props.TextSize or 18
	b.TextColor3 = props.TextColor3 or Color3.new(1,1,1)
	b.Size = props.Size or UDim2.fromScale(0.5, 0.12)
	b.AnchorPoint = props.AnchorPoint or Vector2.new(0,0)
	b.Position = props.Position or UDim2.fromScale(0,0)
	b.ZIndex = props.ZIndex or 1
	b.Name = props.Name or "Button"
	if props.Parent then b.Parent = props.Parent end
	corner(b, UDim.new(0,10)); stroke(b, Palette.stroke, 1, 0.4)
	return b
end

-- Data fetchers (cached)
local function getProductInfo(id)
	local c = cacheGet(priceCache, "prod_"..id); if c then return c end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
	end)
	if ok and info then cacheSet(priceCache, "prod_"..id, info); return info end
	return nil
end
local function getPassInfo(id)
	local c = cacheGet(priceCache, "pass_"..id); if c then return c end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
	end)
	if ok and info then cacheSet(priceCache, "pass_"..id, info); return info end
	return nil
end
local function userOwnsPass(id)
	local key = LocalPlayer.UserId .. ":" .. id
	local c = cacheGet(ownsCache, key); if c ~= nil then return c end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, id)
	end)
	if ok then cacheSet(ownsCache, key, owns); return owns end
	return false
end
local function refreshPrices()
	for _, p in ipairs(ProductsData.cash) do
		local info = getProductInfo(p.id)
		if info then p._r = info.PriceInRobux or 0 end
	end
	for _, gp in ipairs(ProductsData.gamepasses) do
		local info = getPassInfo(gp.id)
		if info then gp._r = info.PriceInRobux or gp._r or 0 end
	end
end

-- State
local state = {
	isOpen = false,
	isAnimating = false,
	currentTab = "Cash",
	pending = {},
	ui = {},
	gridConns = {},
}

-- Toggle
local function makeToggle(parent, label, initial, onChanged)
	local wrap = Instance.new("Frame")
	wrap.Name = "Toggle_" .. label
	wrap.BackgroundTransparency = 1
	wrap.Size = UDim2.fromScale(0.32, 0.8)
	wrap.AnchorPoint = Vector2.new(1, 0.5)
	wrap.Position = UDim2.fromScale(0.98, 0.5)
	wrap.ZIndex = 2
	wrap.Parent = parent

	local lbl = textLabel({
		Text = label, Font = Fonts.reg, TextSize = 16, TextColor3 = Palette.text2,
		Size = UDim2.fromScale(0.55, 1), AnchorPoint = Vector2.new(0,0.5), Position = UDim2.fromScale(0,0.5), ZIndex = 2
	}); lbl.Parent = wrap

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = initial and Palette.mint or Palette.stroke
	track.BorderSizePixel = 0
	track.Size = UDim2.fromScale(0.32, 0.7)
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.fromScale(1, 0.5)
	track.ZIndex = 2
	track.Parent = wrap
	corner(track, UDim.new(1,0)); stroke(track, Palette.stroke, 1, 0.5)

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.BackgroundColor3 = Color3.new(1,1,1)
	dot.BorderSizePixel = 0
	dot.Size = UDim2.fromScale(0.46, 0.82)
	dot.AnchorPoint = Vector2.new(0,0.5)
	dot.Position = initial and UDim2.fromScale(0.52, 0.5) or UDim2.fromScale(0.06, 0.5)
	dot.ZIndex = 3
	dot.Parent = track
	corner(dot, UDim.new(1,0))

	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1,1)
	hit.ZIndex = 4
	hit.Parent = wrap

	local val = initial and true or false
	local function apply()
		tween(track, { BackgroundColor3 = val and Palette.mint or Palette.stroke }, ANIM_FAST)
		tween(dot, { Position = val and UDim2.fromScale(0.52, 0.5) or UDim2.fromScale(0.06, 0.5) }, ANIM_FAST)
	end
	hit.MouseButton1Click:Connect(function()
		val = not val; apply(); if onChanged then onChanged(val) end
	end)
	apply()
	return wrap, function(v) val = v and true or false; apply() end
end

-- Build GUI
local function buildGui()
	local screen = PlayerGui:FindFirstChild("TycoonShopUI")
	if not screen then
		screen = Instance.new("ScreenGui")
		screen.Name = "TycoonShopUI"
		screen.DisplayOrder = 1000
		screen.ResetOnSpawn = false
		screen.IgnoreGuiInset = false
		screen.Enabled = false
		screen.Parent = PlayerGui
	end

	local backdrop = imageLabel({
		Name = "Backdrop", Image = VIGNETTE, ImageColor3 = Color3.new(0,0,0), ImageTransparency = 0.45,
		Size = UDim2.fromScale(1,1), AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5), ZIndex = 1
	}); backdrop.Parent = screen

	local blur = Lighting:FindFirstChild("TycoonShopBlur")
	if not blur then blur = Instance.new("BlurEffect"); blur.Name = "TycoonShopBlur"; blur.Size = 0; blur.Parent = Lighting end

	local wrapper = Instance.new("Frame")
	wrapper.Name = "Wrapper"
	wrapper.BackgroundTransparency = 1
	wrapper.Size = UDim2.fromScale(1,1)
	wrapper.AnchorPoint = Vector2.new(0.5,0.5)
	wrapper.Position = UDim2.fromScale(0.5,0.5)
	wrapper.ZIndex = 2
	wrapper.Parent = screen

	local function applySafePadding()
		local inset = GuiService:GetGuiInset()
		local marginH = 0.06
		local marginTopScale = 0.05
		local marginBottomScale = 0.08
		local padder = wrapper:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
		padder.PaddingTop = UDim.new(marginTopScale, inset.Y)
		padder.PaddingLeft = UDim.new(marginH, inset.X)
		padder.PaddingRight = UDim.new(marginH, 0)
		padder.PaddingBottom = UDim.new(marginBottomScale, 0)
		padder.Parent = wrapper
	end
	applySafePadding()

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = Palette.surface
	panel.BorderSizePixel = 0
	panel.Size = UDim2.fromScale(0.9, 0.85)
	panel.AnchorPoint = Vector2.new(0.5,0.5)
	panel.Position = UDim2.fromScale(0.5,0.5)
	panel.ZIndex = 3
	panel.Parent = wrapper
	corner(panel, UDim.new(0,20)); stroke(panel, Palette.stroke, 1, 0.5)

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
		ColorSequenceKeypoint.new(1, Palette.surfaceAlt),
	})
	grad.Rotation = 90
	grad.Offset = Vector2.new(0,0)
	grad.Transparency = NumberSequence.new(0.05)
	grad.Parent = panel

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = Palette.surfaceAlt
	header.BorderSizePixel = 0
	header.Size = UDim2.fromScale(0.98, 0.12)
	header.AnchorPoint = Vector2.new(0.5,0)
	header.Position = UDim2.fromScale(0.5,0)
	header.ZIndex = 4
	header.Parent = panel
	corner(header, UDim.new(0,16)); pad(header, UDim.new(0,8), UDim.new(0,12), UDim.new(0,8), UDim.new(0,12))

	local hList = Instance.new("UIListLayout")
	hList.FillDirection = Enum.FillDirection.Horizontal
	hList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	hList.VerticalAlignment = Enum.VerticalAlignment.Center
	hList.Padding = UDim.new(0,12)
	hList.Parent = header

	imageLabel({ Name="Icon", Image=ICON_SHOP, Size=UDim2.fromScale(0.06,1), ZIndex=4, Parent=header })
	local title = textLabel({
		Name="Title", Text="Game Shop", Font=Fonts.title, TextSize=24, TextXAlignment=Enum.TextXAlignment.Left,
		TextColor3=Palette.text, Size=UDim2.fromScale(0.72,1), ZIndex=4, Parent=header
	})
	local closeBtn = button({
		Name="Close", Text="Close", Font=Fonts.semi, TextSize=18, BackgroundColor3=Palette.surface, TextColor3=Palette.text,
		Size=UDim2.fromScale(0.22,0.7), ZIndex=4, Parent=header
	})
	closeBtn.MouseEnter:Connect(function() tween(closeBtn, {BackgroundColor3 = Palette.stroke}, ANIM_FAST) end)
	closeBtn.MouseLeave:Connect(function() tween(closeBtn, {BackgroundColor3 = Palette.surface}, ANIM_FAST) end)

	-- Body (nav + content)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(0.98, 0.82)
	body.AnchorPoint = Vector2.new(0.5,1)
	body.Position = UDim2.fromScale(0.5,0.99)
	body.ZIndex = 3
	body.Parent = panel
	local bodyList = Instance.new("UIListLayout")
	bodyList.FillDirection = Enum.FillDirection.Horizontal
	bodyList.Padding = UDim.new(0,12)
	bodyList.Parent = body

	local nav = Instance.new("Frame")
	nav.Name = "Nav"
	nav.BackgroundColor3 = Palette.surfaceAlt
	nav.BorderSizePixel = 0
	nav.Size = UDim2.fromScale(0.3, 1)
	nav.ZIndex = 3
	nav.Parent = body
	corner(nav, UDim.new(0,16)); stroke(nav, Palette.stroke, 1, 0.6); pad(nav, UDim.new(0,12), UDim.new(0,12), UDim.new(0,12), UDim.new(0,12))
	local navList = Instance.new("UIListLayout")
	navList.FillDirection = Enum.FillDirection.Vertical
	navList.Padding = UDim.new(0,10)
	navList.Parent = nav

	local function makeTab(name, accent, id)
		local b = button({
			Name = id.."Tab", Text = name, Font = Fonts.semi, TextSize = 18,
			BackgroundColor3 = Palette.surface, TextColor3 = Palette.text,
			Size = UDim2.fromScale(1, 0.12), Parent = nav
		})
		b.MouseEnter:Connect(function() tween(b, {BackgroundColor3 = accent, TextColor3 = Color3.new(1,1,1)}, ANIM_FAST) end)
		b.MouseLeave:Connect(function()
			local active = state.currentTab == id
			tween(b, {BackgroundColor3 = active and accent or Palette.surface, TextColor3 = active and Color3.new(1,1,1) or Palette.text}, ANIM_FAST)
		end)
		return b
	end
	local cashTab = makeTab("Cash Packs", Palette.mint, "Cash")
	local passTab = makeTab("Game Passes", Palette.lav, "Gamepasses")

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(0.66, 1)
	content.ZIndex = 3
	content.Parent = body

	local pages = Instance.new("Frame")
	pages.Name = "Pages"
	pages.BackgroundTransparency = 1
	pages.Size = UDim2.fromScale(1,1)
	pages.Parent = content

	-- Cash Page
	local cashPage = Instance.new("Frame")
	cashPage.Name = "CashPage"
	cashPage.BackgroundTransparency = 1
	cashPage.Size = UDim2.fromScale(1,1)
	cashPage.Visible = true
	cashPage.Parent = pages

	local cashHeader = Instance.new("Frame")
	cashHeader.Name = "Header"
	cashHeader.BackgroundColor3 = Palette.surfaceAlt
	cashHeader.BorderSizePixel = 0
	cashHeader.Size = UDim2.fromScale(1, 0.1)
	cashHeader.AnchorPoint = Vector2.new(0.5,0)
	cashHeader.Position = UDim2.fromScale(0.5,0)
	cashHeader.Parent = cashPage
	corner(cashHeader, UDim.new(0,10)); pad(cashHeader, UDim.new(0,8), UDim.new(0,12), UDim.new(0,8), UDim.new(0,12))
	textLabel({ Text="Cash Packs", Font=Fonts.title, TextSize=20, Size=UDim2.fromScale(1,1), Parent=cashHeader })

	local cashScroll = Instance.new("ScrollingFrame")
	cashScroll.Name = "Scroll"
	cashScroll.BackgroundTransparency = 1
	cashScroll.BorderSizePixel = 0
	cashScroll.Size = UDim2.fromScale(1, 0.88)
	cashScroll.AnchorPoint = Vector2.new(0.5,1)
	cashScroll.Position = UDim2.fromScale(0.5,1)
	cashScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	cashScroll.ScrollBarThickness = 6
	cashScroll.ScrollBarImageColor3 = Palette.stroke
	cashScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	cashScroll.Parent = cashPage

	local cashGrid = Instance.new("UIGridLayout")
	cashGrid.SortOrder = Enum.SortOrder.LayoutOrder
	cashGrid.FillDirection = Enum.FillDirection.Horizontal
	cashGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cashGrid.CellPadding = UDim2.new(0.03, 0, 0.03, 0)
	cashGrid.FillDirectionMaxCells = 3
	cashGrid.Parent = cashScroll

	-- Pass Page
	local passPage = Instance.new("Frame")
	passPage.Name = "PassPage"
	passPage.BackgroundTransparency = 1
	passPage.Size = UDim2.fromScale(1,1)
	passPage.Visible = false
	passPage.Parent = pages

	local passHeader = Instance.new("Frame")
	passHeader.Name = "Header"
	passHeader.BackgroundColor3 = Palette.surfaceAlt
	passHeader.BorderSizePixel = 0
	passHeader.Size = UDim2.fromScale(1, 0.1)
	passHeader.AnchorPoint = Vector2.new(0.5,0)
	passHeader.Position = UDim2.fromScale(0.5,0)
	passHeader.Parent = passPage
	corner(passHeader, UDim.new(0,10)); pad(passHeader, UDim.new(0,8), UDim.new(0,12), UDim.new(0,8), UDim.new(0,12))
	textLabel({ Text="Game Passes", Font=Fonts.title, TextSize=20, Size=UDim2.fromScale(1,1), Parent=passHeader })

	local passScroll = Instance.new("ScrollingFrame")
	passScroll.Name = "Scroll"
	passScroll.BackgroundTransparency = 1
	passScroll.BorderSizePixel = 0
	passScroll.Size = UDim2.fromScale(1, 0.76)
	passScroll.AnchorPoint = Vector2.new(0.5,0)
	passScroll.Position = UDim2.fromScale(0.5, 0.12)
	passScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	passScroll.ScrollBarThickness = 6
	passScroll.ScrollBarImageColor3 = Palette.stroke
	passScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	passScroll.Parent = passPage

	local passGrid = Instance.new("UIGridLayout")
	passGrid.SortOrder = Enum.SortOrder.LayoutOrder
	passGrid.FillDirection = Enum.FillDirection.Horizontal
	passGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	passGrid.CellPadding = UDim2.new(0.03, 0, 0.03, 0)
	passGrid.FillDirectionMaxCells = 3
	passGrid.Parent = passScroll

	local quick = Instance.new("Frame")
	quick.Name = "QuickSettings"
	quick.BackgroundColor3 = Palette.surfaceAlt
	quick.BorderSizePixel = 0
	quick.Size = UDim2.fromScale(1, 0.12)
	quick.AnchorPoint = Vector2.new(0.5,1)
	quick.Position = UDim2.fromScale(0.5,1)
	quick.Parent = passPage
	corner(quick, UDim.new(0,10)); pad(quick, UDim.new(0,10), UDim.new(0,12), UDim.new(0,10), UDim.new(0,12))
	textLabel({ Text="Quick Settings", Font=Fonts.semi, TextSize=18, Size=UDim2.fromScale(0.5,1), Parent=quick })

	local settingsToggleWrap, setSettingsToggle = makeToggle(quick, "Auto Collect", false, function(val)
		if RemotesFolder then
			local ev = RemotesFolder:FindFirstChild("AutoCollectToggle")
			if ev and ev:IsA("RemoteEvent") then ev:FireServer(val) end
		end
	end)
	settingsToggleWrap.Visible = false

	-- Builders
	local function buildCashCard(prod, order)
		local card = Instance.new("Frame")
		card.Name = "Cash_"..(prod.name or prod.id)
		card.BackgroundColor3 = Palette.surface
		card.BorderSizePixel = 0
		card.ZIndex = 2
		card.Parent = cashScroll
		card.LayoutOrder = order or 1
		corner(card, UDim.new(0,14)); stroke(card, Palette.mint, 1, 0.45)

		local badge = Instance.new("Frame")
		badge.BackgroundColor3 = Palette.mint
		badge.BorderSizePixel = 0
		badge.Size = UDim2.fromScale(0.28, 0.2)
		badge.AnchorPoint = Vector2.new(1,0)
		badge.Position = UDim2.fromScale(0.98, 0.04)
		badge.ZIndex = 3
		badge.Parent = card
		corner(badge, UDim.new(1,0)); stroke(badge, Palette.stroke, 1, 0.35)
		textLabel({
			Text = fmtShort(prod.amount or 0), Font = Fonts.title, TextSize = 20, TextColor3 = Color3.new(1,1,1),
			TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1,1), ZIndex = 4, Parent = badge
		})

		local ar = Instance.new("UIAspectRatioConstraint")
		ar.AspectRatio = 1.55
		ar.DominantAxis = Enum.DominantAxis.Width
		ar.Parent = card

		local inner = Instance.new("Frame")
		inner.BackgroundTransparency = 1
		inner.Size = UDim2.fromScale(0.92, 0.92)
		inner.AnchorPoint = Vector2.new(0.5,0.5)
		inner.Position = UDim2.fromScale(0.5,0.5)
		inner.ZIndex = 2
		inner.Parent = card

		local v = Instance.new("UIListLayout")
		v.FillDirection = Enum.FillDirection.Vertical
		v.Padding = UDim.new(0,8)
		v.Parent = inner

		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, 0.24)
		row.ZIndex = 2
		row.Parent = inner
		local h = Instance.new("UIListLayout")
		h.FillDirection = Enum.FillDirection.Horizontal
		h.Padding = UDim.new(0,8)
		h.Parent = row

		local icon = imageLabel({ Image = prod.icon or ICON_CASH, Size = UDim2.fromScale(0.18, 1), ZIndex = 2, Parent = row })
		local ia = Instance.new("UIAspectRatioConstraint"); ia.AspectRatio = 1; ia.Parent = icon

		textLabel({
			Text = prod.name or "Cash", Font = Fonts.title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(0.78,1), ZIndex = 2, Parent = row
		})

		textLabel({
			Text = prod.description or "", Font = Fonts.reg, TextSize = 16, TextColor3 = Palette.text2,
			Size = UDim2.fromScale(1, 0.28), ZIndex = 2, Parent = inner
		})

		local priceLabel = textLabel({
			Text = "R$—  •  "..fmtNum(prod.amount or 0).." Cash", Font = Fonts.semi, TextSize = 18, TextColor3 = Palette.mint,
			Size = UDim2.fromScale(1, 0.2), ZIndex = 2, Parent = inner
		})
		prod._priceLabel = priceLabel

		local buy = button({
			Text = "Purchase", Font = Fonts.title, TextSize = 18,
			BackgroundColor3 = Palette.mint, TextColor3 = Color3.new(1,1,1),
			Size = UDim2.fromScale(1, 0.24), ZIndex = 2, Parent = inner
		})
		prod._buyButton = buy

		card.MouseEnter:Connect(function() tween(card, {BackgroundColor3 = Palette.surfaceAlt}, ANIM_FAST) end)
		card.MouseLeave:Connect(function() tween(card, {BackgroundColor3 = Palette.surface}, ANIM_FAST) end)

		buy.MouseButton1Click:Connect(function()
			if state.pending[prod.id] then return end
			state.pending[prod.id] = { t = os.clock(), type = "product", item = prod }
			local ok = pcall(function() MarketplaceService:PromptProductPurchase(LocalPlayer, prod.id) end)
			if not ok then state.pending[prod.id] = nil end
		end)
	end

	local function setPassVisual(pass, owned)
		if pass._buyButton then
			pass._buyButton.Text = owned and "Owned" or "Purchase"
			pass._buyButton.Active = not owned
			pass._buyButton.BackgroundColor3 = owned and Palette.ok or Palette.lav
		end
		if pass._card then
			local st = pass._card:FindFirstChildOfClass("UIStroke")
			if st then st.Color = owned and Palette.ok or Palette.lav end
			local ownedBadge = pass._card:FindFirstChild("OwnedBadge")
			if ownedBadge then ownedBadge.Visible = owned end
		end
		if pass.id == PASS_AUTO_COLLECT and pass._inlineToggle then pass._inlineToggle.wrap.Visible = owned end
	end

	local function buildPassCard(pass, order)
		local card = Instance.new("Frame")
		card.Name = "Pass_"..(pass.name or pass.id)
		card.BackgroundColor3 = Palette.surface
		card.BorderSizePixel = 0
		card.ZIndex = 2
		card.Parent = passScroll
		card.LayoutOrder = order or 1
		corner(card, UDim.new(0,14)); stroke(card, Palette.lav, 1, 0.45)

		local ar = Instance.new("UIAspectRatioConstraint")
		ar.AspectRatio = 1.55
		ar.DominantAxis = Enum.DominantAxis.Width
		ar.Parent = card

		local ob = Instance.new("Frame")
		ob.Name = "OwnedBadge"
		ob.BackgroundColor3 = Palette.ok
		ob.BorderSizePixel = 0
		ob.Size = UDim2.fromScale(0.28, 0.2)
		ob.AnchorPoint = Vector2.new(0,0)
		ob.Position = UDim2.fromScale(0.02, 0.04)
		ob.ZIndex = 3
		ob.Parent = card
		corner(ob, UDim.new(1,0)); stroke(ob, Palette.stroke, 1, 0.35)
		textLabel({ Text="Owned", Font=Fonts.semi, TextSize=18, TextColor3=Color3.new(1,1,1), Size=UDim2.fromScale(1,1), ZIndex=4, Parent=ob })

		local inner = Instance.new("Frame")
		inner.BackgroundTransparency = 1
		inner.Size = UDim2.fromScale(0.92, 0.92)
		inner.AnchorPoint = Vector2.new(0.5,0.5)
		inner.Position = UDim2.fromScale(0.5,0.5)
		inner.ZIndex = 2
		inner.Parent = card

		local v = Instance.new("UIListLayout")
		v.FillDirection = Enum.FillDirection.Vertical
		v.Padding = UDim.new(0,8)
		v.Parent = inner

		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, 0.24)
		row.ZIndex = 2
		row.Parent = inner
		local h = Instance.new("UIListLayout")
		h.FillDirection = Enum.FillDirection.Horizontal
		h.Padding = UDim.new(0,8)
		h.Parent = row

		local icon = imageLabel({ Image = pass.icon or ICON_PASS, Size = UDim2.fromScale(0.18,1), ZIndex=2, Parent=row })
		local ia = Instance.new("UIAspectRatioConstraint"); ia.AspectRatio = 1; ia.Parent = icon

		textLabel({
			Text = pass.name or "Game Pass", Font = Fonts.title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(0.78,1), ZIndex = 2, Parent = row
		})
		textLabel({
			Text = pass.description or "", Font = Fonts.reg, TextSize = 16, TextColor3 = Palette.text2,
			Size = UDim2.fromScale(1, 0.28), ZIndex = 2, Parent = inner
		})

		local priceLabel = textLabel({
			Text = "R$—", Font = Fonts.semi, TextSize = 18, TextColor3 = Palette.lav,
			Size = UDim2.fromScale(1, 0.2), ZIndex = 2, Parent = inner
		})
		pass._priceLabel = priceLabel

		local buy = button({
			Text = "Purchase", Font = Fonts.title, TextSize = 18,
			BackgroundColor3 = Palette.lav, TextColor3 = Color3.new(1,1,1),
			Size = UDim2.fromScale(1, 0.24), ZIndex = 2, Parent = inner
		})
		pass._buyButton = buy

		local owned = userOwnsPass(pass.id)
		setPassVisual(pass, owned)

		buy.MouseButton1Click:Connect(function()
			if owned then return end
			if state.pending[pass.id] then return end
			buy.Text = "Processing..."; buy.Active = false
			state.pending[pass.id] = { t = os.clock(), type = "gamepass", item = pass }
			local ok = pcall(function() MarketplaceService:PromptGamePassPurchase(LocalPlayer, pass.id) end)
			if not ok then state.pending[pass.id] = nil; buy.Text = "Purchase"; buy.Active = true end
			task.delay(PURCHASE_TIMEOUT, function()
				if state.pending[pass.id] then state.pending[pass.id] = nil; buy.Text = "Purchase"; buy.Active = true end
			end)
		end)

		if pass.id == PASS_AUTO_COLLECT and pass.hasToggle then
			local tWrap, setInline = makeToggle(inner, "Enable", false, function(val)
				if RemotesFolder then
					local ev = RemotesFolder:FindFirstChild("AutoCollectToggle")
					if ev and ev:IsA("RemoteEvent") then ev:FireServer(val) end
				end
				if settingsToggleWrap.Visible and setSettingsToggle then setSettingsToggle(val) end
			end)
			pass._inlineToggle = { wrap = tWrap, set = setInline }
			tWrap.Visible = owned
		end

		card.MouseEnter:Connect(function() tween(card, {BackgroundColor3 = Palette.surfaceAlt}, ANIM_FAST) end)
		card.MouseLeave:Connect(function() tween(card, {BackgroundColor3 = Palette.surface}, ANIM_FAST) end)
		pass._card = card
	end

	for i, p in ipairs(ProductsData.cash) do buildCashCard(p, i) end
	for i, gp in ipairs(ProductsData.gamepasses) do buildPassCard(gp, i) end

	local ownsAuto = userOwnsPass(PASS_AUTO_COLLECT)
	settingsToggleWrap.Visible = ownsAuto
	if ownsAuto and RemotesFolder then
		local rf = RemotesFolder:FindFirstChild("GetAutoCollectState")
		if rf and rf:IsA("RemoteFunction") then
			local ok, st = pcall(function() return rf:InvokeServer() end)
			if ok and typeof(st) == "boolean" then setSettingsToggle(st) end
		end
	end

	local function selectTab(id)
		state.currentTab = id
		cashPage.Visible = (id == "Cash")
		passPage.Visible = (id == "Gamepasses")
		tween(cashTab, { BackgroundColor3 = (id=="Cash") and Palette.mint or Palette.surface, TextColor3 = (id=="Cash") and Color3.new(1,1,1) or Palette.text }, ANIM_FAST)
		tween(passTab, { BackgroundColor3 = (id=="Gamepasses") and Palette.lav or Palette.surface, TextColor3 = (id=="Gamepasses") and Color3.new(1,1,1) or Palette.text }, ANIM_FAST)
	end
	cashTab.MouseButton1Click:Connect(function() selectTab("Cash") end)
	passTab.MouseButton1Click:Connect(function() selectTab("Gamepasses") end)
	selectTab(state.currentTab)

	closeBtn.MouseButton1Click:Connect(function()
		if state.ui and state.ui.close then state.ui.close() end
	end)

	local toggleGui = PlayerGui:FindFirstChild("ShopToggle")
	if not toggleGui then
		toggleGui = Instance.new("ScreenGui")
		toggleGui.Name = "ShopToggle"
		toggleGui.DisplayOrder = 999
		toggleGui.ResetOnSpawn = false
		toggleGui.IgnoreGuiInset = false
		toggleGui.Parent = PlayerGui
	end
	local pill = button({
		Name="OpenShop", Text="Shop", Font=Fonts.title, TextSize=20, BackgroundColor3=Palette.surface, TextColor3=Palette.text,
		Size=UDim2.fromScale(0.25, 0.12), AnchorPoint=Vector2.new(1,1), Position=UDim2.fromScale(0.9, 0.86), Parent=toggleGui
	})
	corner(pill, UDim.new(1,0))
	pill.MouseEnter:Connect(function() tween(pill, {BackgroundColor3 = Palette.mint, TextColor3 = Color3.new(1,1,1)}, ANIM_FAST) end)
	pill.MouseLeave:Connect(function() tween(pill, {BackgroundColor3 = Palette.surface, TextColor3 = Palette.text}, ANIM_FAST) end)
	pill.MouseButton1Click:Connect(function()
		if state.ui and state.ui.toggle then state.ui.toggle() end
	end)

	local function setNavWidth(px)
		if px < 600 then nav.Size = UDim2.fromScale(0.36, 1); content.Size = UDim2.fromScale(0.6, 1)
		elseif px < 950 then nav.Size = UDim2.fromScale(0.3, 1); content.Size = UDim2.fromScale(0.66, 1)
		else nav.Size = UDim2.fromScale(0.26, 1); content.Size = UDim2.fromScale(0.72, 1) end
	end
	local function setGrid(px)
		local cols = 3
		if px < 600 then cols = 1 elseif px < 950 then cols = 2 end
		cashGrid.FillDirectionMaxCells = cols
		passGrid.FillDirectionMaxCells = cols
		local ws = (cols==1 and 0.96) or (cols==2 and 0.47) or 0.31
		local hs = (cols==1 and 0.30) or (cols==2 and 0.33) or 0.35
		cashGrid.CellSize = UDim2.new(ws, 0, hs, 0)
		passGrid.CellSize = UDim2.new(ws, 0, hs, 0)
	end
	local function responsive()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local px = cam.ViewportSize.X
		setNavWidth(px); setGrid(px)
	end
	responsive()
	local cam = workspace.CurrentCamera
	if cam then table.insert(state.gridConns, cam:GetPropertyChangedSignal("ViewportSize"):Connect(responsive)) end

	state.ui.screen, state.ui.backdrop, state.ui.blur = screen, backdrop, blur
	state.ui.open = function()
		if state.isOpen or state.isAnimating then return end
		state.isAnimating, state.isOpen = true, true
		refreshPrices()
		for _, p in ipairs(ProductsData.cash) do
			if p._priceLabel then
				local r = (p._r ~= nil) and ("R$"..tostring(p._r)) or "R$—"
				p._priceLabel.Text = r.."  •  "..fmtNum(p.amount or 0).." Cash"
			end
		end
		for _, gp in ipairs(ProductsData.gamepasses) do
			if gp._priceLabel then gp._priceLabel.Text = (gp._r ~= nil) and ("R$"..tostring(gp._r)) or "R$—" end
		end
		screen.Enabled = true
		tween(backdrop, { ImageTransparency = 0.25 }, ANIM_SLOW)
		tween(blur, { Size = 28 }, ANIM_MED)
		panel.Position = UDim2.fromScale(0.5, 0.53)
		tween(panel, { Position = UDim2.fromScale(0.5, 0.5) }, ANIM_SLOW, Enum.EasingStyle.Quad)
		task.delay(ANIM_SLOW, function() state.isAnimating = false end)
	end
	state.ui.close = function()
		if not state.isOpen or state.isAnimating then return end
		state.isAnimating = true; state.isOpen = false
		tween(backdrop, { ImageTransparency = 0.45 }, ANIM_FAST)
		tween(blur, { Size = 0 }, ANIM_FAST)
		tween(panel, { Position = UDim2.fromScale(0.5, 0.52) }, ANIM_FAST)
		task.delay(ANIM_FAST, function() screen.Enabled = false; state.isAnimating = false end)
	end
	state.ui.toggle = function() if state.isOpen then state.ui.close() else state.ui.open() end end

	state.ui.applySafePadding = applySafePadding
	state.ui.responsive = responsive

	return screen
end

-- Periodic price refresh (only while open)
task.spawn(function()
	while true do
		task.wait(PRICE_REFRESH_INTERVAL)
		if state.isOpen then
			refreshPrices()
			for _, p in ipairs(ProductsData.cash) do
				if p._priceLabel then
					local r = (p._r ~= nil) and ("R$"..tostring(p._r)) or "R$—"
					p._priceLabel.Text = r.."  •  "..fmtNum(p.amount or 0).." Cash"
				end
			end
			for _, gp in ipairs(ProductsData.gamepasses) do
				if gp._priceLabel then gp._priceLabel.Text = (gp._r ~= nil) and ("R$"..tostring(gp._r)) or "R$—" end
			end
		end
	end
end)

-- Marketplace callbacks
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if player ~= LocalPlayer then return end
	local pend = state.pending[passId]
	state.pending[passId] = nil
	local item
	for _, gp in ipairs(ProductsData.gamepasses) do if gp.id == passId then item = gp break end end
	if not item then return end
	if purchased then
		cacheSet(ownsCache, LocalPlayer.UserId..":"..passId, true)
		if item._buyButton then item._buyButton.Text="Owned"; item._buyButton.Active=false; item._buyButton.BackgroundColor3=Palette.ok end
		if item._card then local st=item._card:FindFirstChildOfClass("UIStroke"); if st then st.Color=Palette.ok end end
		if item.id == PASS_AUTO_COLLECT and item._inlineToggle then item._inlineToggle.wrap.Visible = true end
		if RemotesFolder then
			local ev = RemotesFolder:FindFirstChild("GamepassPurchased")
			if ev and ev:IsA("RemoteEvent") then ev:FireServer(passId) end
		end
	else
		if item._buyButton then item._buyButton.Text="Purchase"; item._buyButton.Active=true end
	end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, purchased)
	if player ~= LocalPlayer then return end
	local pend = state.pending[productId]
	state.pending[productId] = nil
	if purchased and RemotesFolder then
		local grant = RemotesFolder:FindFirstChild("GrantProductCurrency")
		if grant and grant:IsA("RemoteEvent") then grant:FireServer(productId) end
	end
end)

-- Inputs: M / gamepad X toggle; Esc closes
local function bindInputs()
	local function onToggle(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		if state.ui and state.ui.toggle then state.ui.toggle() end
		return Enum.ContextActionResult.Sink
	end
	local function onClose(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		if state.isOpen and state.ui and state.ui.close then state.ui.close() end
		return Enum.ContextActionResult.Sink
	end
	ContextActionService:BindAction("ShopToggleM", onToggle, true, Enum.KeyCode.M, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction("ShopCloseEsc", onClose, true, Enum.KeyCode.Escape)
end

-- Build + init
local screen = buildGui()
bindInputs()

-- Safety + responsive
local function reapply()
	if state.ui and state.ui.applySafePadding then state.ui.applySafePadding() end
	if state.ui and state.ui.responsive then state.ui.responsive() end
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() task.wait(0.05); reapply() end)
LocalPlayer.CharacterAdded:Connect(function() task.wait(1); reapply() end)

-- Public
_G.TycoonShopUI = {
	Open = function() if state.ui and state.ui.open then state.ui.open() end end,
	Close = function() if state.ui and state.ui.close then state.ui.close() end end,
	Toggle = function() if state.ui and state.ui.toggle then state.ui.toggle() end end,
}

print("[TycoonShopUI] Ready v6.0.0")
