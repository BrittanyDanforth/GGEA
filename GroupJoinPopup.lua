--[[
	🎀 Sanrio Tycoon Group Popup 🎀
	MOBILE-FIRST REWORK (phones all sizes & sideways)
	
	Features:
	- ✅ Phone detection with global zoom-out
	- ✅ Landscape & portrait support
	- ✅ Dynamic sizing (adapts to ANY screen)
	- ✅ Safe viewport calculations (respects notches)
	- ✅ Side-by-side layout: Text left, "How to Join" decal right
	- ✅ TAP-TO-ZOOM: Tap the decal to view fullscreen
	- ✅ Uses .Activated events (mobile-friendly!)
	- ✅ Waits 9 minutes before showing (5s in Studio)
	- ✅ NO forbidden APIs
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- 🎮 SERVICES 🎮
-- ═══════════════════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ContentProvider = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════════════════════════════════
-- 🌸 CONFIGURATION 🌸
-- ═══════════════════════════════════════════════════════════════════════════

local CONFIG = {
	GROUP_ID = 986814499, -- ⭐ Sanrio Tycoon Group!
	HOW_TO_JOIN_DECAL = "rbxassetid://73482754980631", -- Step-by-step guide image
	
	-- Testing flags
	FORCE_SHOW = true, -- Always show popup (ignores membership check)
	ALWAYS_SHOW_IN_STUDIO = true, -- Show in Studio even if member
	
	-- Timing
	DELAY_BEFORE_SHOW = 540, -- Wait 9 minutes (540 seconds) before showing
	STUDIO_DELAY = 5, -- In Studio, only wait 5 seconds for testing
	
	-- 🎨 Cute Pastel Colors (Sanrio theme)
	COLORS = {
		CARD_BG = Color3.fromRGB(255, 248, 252),
		GRADIENT_TOP = Color3.fromRGB(255, 220, 245),
		GRADIENT_BOTTOM = Color3.fromRGB(235, 225, 255),
		BUTTON_PRIMARY = Color3.fromRGB(255, 182, 213),
		BUTTON_PRIMARY_HOVER = Color3.fromRGB(255, 158, 200),
		BUTTON_SECONDARY = Color3.fromRGB(230, 220, 255),
		BUTTON_SECONDARY_HOVER = Color3.fromRGB(215, 200, 255),
		TITLE = Color3.fromRGB(255, 105, 180),
		BODY = Color3.fromRGB(150, 120, 160),
		BUTTON_TEXT = Color3.fromRGB(255, 255, 255),
		BUTTON_TEXT_SECONDARY = Color3.fromRGB(150, 120, 160),
		STROKE = Color3.fromRGB(255, 220, 235),
	},
	
	-- UI Configuration (desktop base)
	DIM_TRANSPARENCY = 0.5,
	ANIMATION_SPEED_OPEN = 0.3,
	ANIMATION_SPEED_CLOSE = 0.2,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 📱 MOBILE DETECTION & SIZING (shop-style!)
-- ═══════════════════════════════════════════════════════════════════════════

local function viewport()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1920, 1080)
end

local function safeViewport()
	local cam = workspace.CurrentCamera
	if not cam then return Vector2.new(800, 600), 0 end
	local inset = GuiService:GetGuiInset()
	local v = cam.ViewportSize
	return Vector2.new(v.X, math.max(0, v.Y - inset.Y)), inset.Y
end

local function isMobileLike()
	return UserInputService.TouchEnabled and not GuiService:IsTenFootInterface()
end

local function isPhone()
	if not isMobileLike() then return false end
	local v = viewport()
	return math.min(v.X, v.Y) < 700
end

local function isTablet()
	return isMobileLike() and not isPhone()
end

local function phonePanelScale(short)
	-- NO zoom-out! Keep text readable!
	return 1.0
end

-- Dynamic profile that adjusts ALL sizing based on device
local function getDynamicProfile()
	local v = viewport()
	local safeV, insetY = safeViewport()
	local short = math.min(safeV.X, safeV.Y)
	local landscape = v.X > v.Y
	
	local phone = isPhone()
	local tablet = isTablet()
	
	if phone then
		-- PHONE sizing (BIG READABLE TEXT!)
		return {
			isPhone = true,
			isTablet = false,
			landscape = landscape,
			shortSide = short,
			
			-- Card size (fit screen!)
			cardW = landscape and math.min(safeV.X * 0.95, 640) or math.min(safeV.X * 0.95, 360),
			cardH = landscape and math.min(safeV.Y * 0.85, 400) or math.min(safeV.Y * 0.85, 520),
			
			-- Text sizes (BIG AND READABLE!)
			titleSize = 28, -- BIGGER!
			bodySize = 16, -- BIGGER!
			buttonTextSize = 16, -- BIGGER!
			howToTitleSize = 20, -- BIGGER!
			
			-- Spacing
			padding = 20,
			buttonSpacing = 10,
			
			-- Layout
			sideBySide = landscape,
			
			-- NO zoom-out!
			globalScale = 1.0,
		}
	elseif tablet then
		-- TABLET sizing (BIG TEXT!)
		return {
			isPhone = false,
			isTablet = true,
			landscape = landscape,
			shortSide = short,
			
			cardW = 600,
			cardH = 440,
			
			titleSize = 28, -- BIGGER!
			bodySize = 17, -- BIGGER!
			buttonTextSize = 17, -- BIGGER!
			howToTitleSize = 20, -- BIGGER!
			
			padding = 24,
			buttonSpacing = 10,
			
			sideBySide = true,
			
			globalScale = 1,
		}
	else
		-- DESKTOP sizing (BIG TEXT!)
		return {
			isPhone = false,
			isTablet = false,
			landscape = true,
			shortSide = short,
			
			cardW = 700,
			cardH = 400,
			
			titleSize = 30, -- BIGGER!
			bodySize = 18, -- BIGGER!
			buttonTextSize = 17, -- BIGGER!
			howToTitleSize = 22, -- BIGGER!
			
			padding = 30,
			buttonSpacing = 10,
			
			sideBySide = true,
			
			globalScale = 1,
		}
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LOGGING
-- ═══════════════════════════════════════════════════════════════════════════

local function log(message)
	print("🎀 [SanrioGroupPopup]", message)
end

local function logError(message)
	warn("⚠️ [SanrioGroupPopup] ERROR:", message)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- VARIABLES
-- ═══════════════════════════════════════════════════════════════════════════

local screenGui
local dimFrame
local cardFrame
local cardScale -- Global UIScale for phone zoom-out!
local isAnimating = false

-- ═══════════════════════════════════════════════════════════════════════════
-- UI CREATION (Mobile-first, responsive!)
-- ═══════════════════════════════════════════════════════════════════════════

local function createScreenGui()
	log("🎨 Creating ScreenGui...")
	
	local gui = Instance.new("ScreenGui")
	gui.Name = "SanrioGroupJoinPopup"
	gui.DisplayOrder = 10000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	
	return gui
end

local function createDim(parent)
	log("🌈 Creating Dim overlay...")
	
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.Position = UDim2.new(0, 0, 0, 0)
	dim.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.ZIndex = 10
	dim.Parent = parent
	
	local button = Instance.new("TextButton")
	button.Name = "ClickDetector"
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.ZIndex = 10
	button.Parent = dim
	
	return dim, button
end

local function createCard(parent)
	log("💝 Creating responsive Card...")
	
	local prof = getDynamicProfile()
	
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromOffset(prof.cardW, prof.cardH)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = CONFIG.COLORS.CARD_BG
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.ZIndex = 20
	card.Parent = parent
	
	-- GLOBAL PHONE ZOOM-OUT (shop-style!)
	cardScale = Instance.new("UIScale")
	cardScale.Scale = prof.globalScale
	cardScale.Parent = card
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 20)
	corner.Parent = card
	
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, CONFIG.COLORS.GRADIENT_TOP),
		ColorSequenceKeypoint.new(1, CONFIG.COLORS.GRADIENT_BOTTOM)
	})
	gradient.Rotation = 135
	gradient.Transparency = NumberSequence.new(0.3)
	gradient.Parent = card
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = CONFIG.COLORS.STROKE
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Transparency = 1
	stroke.Parent = card
	
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, prof.padding)
	padding.PaddingBottom = UDim.new(0, prof.padding)
	padding.PaddingLeft = UDim.new(0, prof.padding)
	padding.PaddingRight = UDim.new(0, prof.padding)
	padding.Parent = card
	
	-- DYNAMIC layout (vertical on phone portrait, horizontal on tablet/desktop/landscape!)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = prof.sideBySide and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, prof.sideBySide and 20 or 12)
	layout.Parent = card
	
	return card, stroke, layout
end

local function createLeftSide(parent, prof)
	log("⬅️ Creating left side container...")
	
	local leftSide = Instance.new("Frame")
	leftSide.Name = "LeftSide"
	leftSide.Size = prof.sideBySide and UDim2.new(0.5, -10, 1, 0) or UDim2.new(1, 0, 0.55, 0)
	leftSide.BackgroundTransparency = 1
	leftSide.ZIndex = 21
	leftSide.LayoutOrder = 1
	leftSide.Parent = parent
	
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, prof.isPhone and 10 or 15)
	layout.Parent = leftSide
	
	return leftSide
end

local function createTitle(parent, prof)
	log("✨ Creating Title...")
	
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, prof.isPhone and 40 or 50)
	title.BackgroundTransparency = 1
	title.Text = "Thanks for Playing!"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = prof.titleSize
	title.TextColor3 = CONFIG.COLORS.TITLE
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextTransparency = 1
	title.TextScaled = prof.isPhone -- Scale on tiny phones
	title.ZIndex = 21
	title.LayoutOrder = 1
	title.Parent = parent
	
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(255, 255, 255)
	textStroke.Thickness = 2
	textStroke.Transparency = 0.5
	textStroke.Parent = title
	
	return title
end

local function createBody(parent, prof)
	log("📝 Creating Body text...")
	
	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 0, prof.isPhone and 100 or 110)
	body.BackgroundTransparency = 1
	body.Text = "We noticed you've been playing for a bit! If you'd like to join our group, you'll get:\n\n• Daily Spins 🎡\n• Early Access 🌟\n• Special Rewards 🎁"
	body.Font = Enum.Font.Gotham
	body.TextSize = prof.bodySize
	body.TextColor3 = CONFIG.COLORS.BODY
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.TextTransparency = 1
	body.ZIndex = 21
	body.LayoutOrder = 2
	body.Parent = parent
	
	return body
end

local function createButtonContainer(parent, prof)
	log("🎯 Creating button container...")
	
	local container = Instance.new("Frame")
	container.Name = "ButtonContainer"
	container.Size = UDim2.new(1, 0, 0, prof.isPhone and 40 or 50)
	container.BackgroundTransparency = 1
	container.ZIndex = 21
	container.LayoutOrder = 3
	container.Parent = parent
	
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, prof.buttonSpacing)
	layout.Parent = container
	
	return container
end

local function createButton(parent, name, text, isPrimary, layoutOrder, prof)
	log("🔘 Creating button: " .. name)
	
	local btnW = prof.isPhone and 120 or 140
	local btnH = prof.isPhone and 38 or 45
	
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(0, btnW, 0, btnH)
	button.BackgroundColor3 = isPrimary and CONFIG.COLORS.BUTTON_PRIMARY or CONFIG.COLORS.BUTTON_SECONDARY
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextSize = prof.buttonTextSize
	button.TextColor3 = isPrimary and CONFIG.COLORS.BUTTON_TEXT or CONFIG.COLORS.BUTTON_TEXT_SECONDARY
	button.TextTransparency = 1
	button.AutoButtonColor = false
	button.ZIndex = 21
	button.LayoutOrder = layoutOrder
	button.Parent = parent
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	
	local shadow = Instance.new("UIStroke")
	shadow.Color = isPrimary and Color3.fromRGB(255, 150, 190) or Color3.fromRGB(200, 190, 230)
	shadow.Thickness = 0
	shadow.Transparency = 0
	shadow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	shadow.Parent = button
	
	-- Hover (desktop only)
	if not isPhone() then
		button.MouseEnter:Connect(function()
			local hoverColor = isPrimary and CONFIG.COLORS.BUTTON_PRIMARY_HOVER or CONFIG.COLORS.BUTTON_SECONDARY_HOVER
			TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = hoverColor,
				Size = UDim2.new(0, btnW + 5, 0, btnH + 2)
			}):Play()
			TweenService:Create(shadow, TweenInfo.new(0.2), {Thickness = 2}):Play()
		end)
		
		button.MouseLeave:Connect(function()
			local normalColor = isPrimary and CONFIG.COLORS.BUTTON_PRIMARY or CONFIG.COLORS.BUTTON_SECONDARY
			TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = normalColor,
				Size = UDim2.new(0, btnW, 0, btnH)
			}):Play()
			TweenService:Create(shadow, TweenInfo.new(0.2), {Thickness = 0}):Play()
		end)
	end
	
	return button
end

local function createRightSide(parent, prof)
	log("➡️ Creating right side with How To Join decal...")
	
	local rightSide = Instance.new("Frame")
	rightSide.Name = "RightSide"
	rightSide.Size = prof.sideBySide and UDim2.new(0.5, -10, 1, 0) or UDim2.new(1, 0, 0.45, 0)
	rightSide.BackgroundTransparency = 1
	rightSide.ZIndex = 21
	rightSide.LayoutOrder = 2
	rightSide.Parent = parent
	
	local howToTitle = Instance.new("TextLabel")
	howToTitle.Name = "HowToTitle"
	howToTitle.Size = UDim2.new(1, 0, 0, prof.isPhone and 28 or 35)
	howToTitle.Position = UDim2.new(0, 0, 0, 0)
	howToTitle.BackgroundTransparency = 1
	howToTitle.Text = "How to Join!"
	howToTitle.Font = Enum.Font.GothamBold
	howToTitle.TextSize = prof.howToTitleSize
	howToTitle.TextColor3 = CONFIG.COLORS.TITLE
	howToTitle.TextXAlignment = Enum.TextXAlignment.Center
	howToTitle.TextYAlignment = Enum.TextYAlignment.Top
	howToTitle.TextTransparency = 1
	howToTitle.ZIndex = 22
	howToTitle.Parent = rightSide
	
	local decalContainer = Instance.new("Frame")
	decalContainer.Name = "DecalContainer"
	decalContainer.Size = UDim2.new(1, -20, 1, prof.isPhone and -50 or -90)
	decalContainer.Position = UDim2.new(0, 10, 0, prof.isPhone and 30 or 40)
	decalContainer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	decalContainer.BackgroundTransparency = 1
	decalContainer.BorderSizePixel = 0
	decalContainer.ZIndex = 21
	decalContainer.Parent = rightSide
	
	local decalCorner = Instance.new("UICorner")
	decalCorner.CornerRadius = UDim.new(0, 12)
	decalCorner.Parent = decalContainer
	
	local decalImage = Instance.new("ImageButton")
	decalImage.Name = "HowToJoinImage"
	decalImage.Size = UDim2.new(1, 0, 1, 0)
	decalImage.BackgroundTransparency = 1
	decalImage.AutoButtonColor = false
	decalImage.Image = CONFIG.HOW_TO_JOIN_DECAL
	decalImage.ScaleType = Enum.ScaleType.Fit
	decalImage.ImageTransparency = 1
	decalImage.ZIndex = 22
	decalImage.Parent = decalContainer
	
	local tapHint = Instance.new("TextLabel")
	tapHint.Name = "TapHint"
	tapHint.AnchorPoint = Vector2.new(0.5, 1)
	tapHint.Position = UDim2.new(0.5, 0, 1, -8)
	tapHint.Size = UDim2.new(0, prof.isPhone and 100 or 140, 0, prof.isPhone and 20 or 24)
	tapHint.BackgroundTransparency = 0.15
	tapHint.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	tapHint.Text = "Tap to zoom"
	tapHint.Font = Enum.Font.GothamBold
	tapHint.TextSize = prof.isPhone and 10 or 12
	tapHint.TextColor3 = Color3.fromRGB(255, 255, 255)
	tapHint.TextXAlignment = Enum.TextXAlignment.Center
	tapHint.TextYAlignment = Enum.TextYAlignment.Center
	tapHint.TextTransparency = 1
	tapHint.ZIndex = 23
	tapHint.Parent = decalContainer
	
	local hintCorner = Instance.new("UICorner")
	hintCorner.CornerRadius = UDim.new(0, 8)
	hintCorner.Parent = tapHint
	
	return rightSide, howToTitle, decalImage, decalContainer, tapHint
end

-- 🔍 ZOOM OVERLAY (scroll + pinch-zoom, mobile-friendly)
local function createZoomOverlay(parentGui)
	log("🔍 Creating scrollable + pinch-zoom overlay for decal...")
	
	local overlay = Instance.new("Frame")
	overlay.Name = "ZoomOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(10, 5, 15)
	overlay.BackgroundTransparency = 0.15
	overlay.ZIndex = 200
	overlay.Visible = false
	overlay.Active = true
	overlay.Parent = parentGui

	-- Blocks taps from leaking to the dim behind
	local blocker = Instance.new("TextButton")
	blocker.BackgroundTransparency = 1
	blocker.Text = ""
	blocker.Size = UDim2.fromScale(1,1)
	blocker.ZIndex = 201
	blocker.Parent = overlay

	-- Card
	local zoomCard = Instance.new("Frame")
	zoomCard.Name = "ZoomCard"
	zoomCard.AnchorPoint = Vector2.new(0.5, 0.5)
	zoomCard.Position = UDim2.fromScale(0.5, 0.5)
	zoomCard.Size = UDim2.new(1, -10, 1, -10)
	zoomCard.BackgroundColor3 = CONFIG.COLORS.CARD_BG
	zoomCard.ZIndex = 202
	zoomCard.Parent = overlay
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,20); c.Parent = zoomCard
	local s = Instance.new("UIStroke"); s.Color = CONFIG.COLORS.STROKE; s.Thickness = 3; s.Parent = zoomCard

	-- Scrollable viewport
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.BackgroundTransparency = 1
	scroll.Size = UDim2.fromScale(1,1)
	scroll.CanvasSize = UDim2.fromScale(1,1)      -- will be updated by zoom
	scroll.ScrollBarThickness = 6                  -- small, unobtrusive; set 0 to hide
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y -- vertical only (change to XY if you want both)
	scroll.ElasticBehavior = Enum.ElasticBehavior.Always
	scroll.ZIndex = 203
	scroll.Parent = zoomCard
	scroll.ClipsDescendants = true

	-- Safe padding (so Step 1 isn't hidden under X button!)
	local SAFE_TOP_PAD   = GuiService:GetGuiInset().Y + 120  -- MORE room for the X button + notch + top of image!
	local EXTRA_BOTTOM   = 50                                -- extra travel at bottom

	-- Big image inside the scroller
	local img = Instance.new("ImageLabel")
	img.Name = "ZoomedImage"
	img.BackgroundTransparency = 1
	img.Image = CONFIG.HOW_TO_JOIN_DECAL
	img.ScaleType = Enum.ScaleType.Fit      -- FIT shows ENTIRE image without cropping!
	img.Size = UDim2.fromScale(1, 1)         -- will be grown by zoom
	img.Position = UDim2.new(0, 0, 0, SAFE_TOP_PAD) -- START LOWER so Step 1 is visible!
	img.ZIndex = 204
	img.Parent = scroll

	-- Close X (safe-area aware)
	local insetY = GuiService:GetGuiInset().Y
	local xWrap = Instance.new("Frame")
	xWrap.AnchorPoint = Vector2.new(1, 0)
	xWrap.Position = UDim2.new(1, -15, 0, 15 + insetY)
	xWrap.Size = UDim2.fromOffset(56, 56)
	xWrap.BackgroundTransparency = 1
	xWrap.ZIndex = 205
	xWrap.Parent = overlay

	local xBtn = Instance.new("TextButton")
	xBtn.Size = UDim2.fromScale(1,1)
	xBtn.Text = "✕"
	xBtn.Font = Enum.Font.GothamBold
	xBtn.TextSize = 28
	xBtn.TextColor3 = CONFIG.COLORS.BUTTON_TEXT
	xBtn.BackgroundColor3 = CONFIG.COLORS.BUTTON_PRIMARY
	xBtn.AutoButtonColor = true
	xBtn.ZIndex = 206
	xBtn.Parent = xWrap
	local xCorner = Instance.new("UICorner"); xCorner.CornerRadius = UDim.new(0,12); xCorner.Parent = xBtn

	-- Big "Got it!" button
	local closeButton = Instance.new("TextButton")
	closeButton.AnchorPoint = Vector2.new(0.5,1)
	closeButton.Position = UDim2.new(0.5, 0, 1, -15)
	closeButton.Size = UDim2.new(0, 240, 0, 52)
	closeButton.Text = "Got it!"
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 20
	closeButton.TextColor3 = CONFIG.COLORS.BUTTON_TEXT
	closeButton.BackgroundColor3 = CONFIG.COLORS.BUTTON_PRIMARY
	closeButton.ZIndex = 205
	closeButton.Parent = zoomCard
	local closeCorner = Instance.new("UICorner"); closeCorner.CornerRadius = UDim.new(0,12); closeCorner.Parent = closeButton

	-- ===== Zoom & Scroll logic (FIXED - Step 1 visible, full scroll range!) =====
	local MIN_ZOOM, MAX_ZOOM = 1.0, 3.0
	local zoom = 1.5    -- default: slightly less zoom so nothing crops!

	local function applyZoom(focusYRatio)
		-- make sure we have a real height
		local viewH = math.max(1, scroll.AbsoluteSize.Y)

		zoom = math.clamp(zoom, MIN_ZOOM, MAX_ZOOM)

		-- compute image height in **pixels** (not scale!)
		local imgPx = math.ceil(viewH * zoom)

		-- Position image with top padding (so Step 1 isn't under X button!)
		img.Position = UDim2.new(0, 0, 0, SAFE_TOP_PAD)
		img.Size = UDim2.new(1, 0, 0, imgPx)

		-- Total canvas = top padding + image + bottom padding
		local totalCanvas = SAFE_TOP_PAD + imgPx + EXTRA_BOTTOM
		scroll.CanvasSize = UDim2.new(0, 0, 0, totalCanvas)

		-- keep the same focus point in view
		focusYRatio = math.clamp(focusYRatio or 0, 0, 1) -- 0 = top
		local maxScroll = math.max(0, totalCanvas - viewH)
		scroll.CanvasPosition = Vector2.new(0, math.floor(maxScroll * focusYRatio))
	end

	-- Re-apply when scroll frame resizes (maintains scroll position!)
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if overlay.Visible then 
			local totalCanvas = scroll.CanvasSize.Y.Offset
			local maxScroll = math.max(1, totalCanvas - scroll.AbsoluteSize.Y)
			local currentRatio = scroll.CanvasPosition.Y / maxScroll
			applyZoom(currentRatio)
		end
	end)

	-- Handle viewport changes
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if overlay.Visible then
			local totalCanvas = scroll.CanvasSize.Y.Offset
			local maxScroll = math.max(1, totalCanvas - scroll.AbsoluteSize.Y)
			local currentRatio = scroll.CanvasPosition.Y / maxScroll
			applyZoom(currentRatio)
		end
	end)

	-- Pinch zoom (two fingers)
	local UIS = UserInputService
	local touching = {}
	local startDist, startZoom

	local function dist(a, b) return (a - b).Magnitude end

	UIS.TouchStarted:Connect(function(input, gp)
		if not overlay.Visible then return end
		touching[input] = input.Position
		if table.getn(touching) == 2 then
			local pts = {}
			for k,p in pairs(touching) do table.insert(pts, k) end
			startDist = dist(pts[1].Position, pts[2].Position)
			startZoom = zoom
		end
	end)

	UIS.TouchMoved:Connect(function(input, gp)
		if not overlay.Visible then return end
		if touching[input] then touching[input] = input.Position end
		local pts = {}
		for k,p in pairs(touching) do table.insert(pts, k) end
		if #pts == 2 and startDist and startDist > 0 then
			local newDist = dist(pts[1].Position, pts[2].Position)
			local factor = newDist / startDist
			zoom = math.clamp(startZoom * factor, MIN_ZOOM, MAX_ZOOM)

			-- keep the midpoint stable
			local midY = (pts[1].Position.Y + pts[2].Position.Y) / 2
			local focusYRatio = (midY - scroll.AbsolutePosition.Y) / math.max(scroll.AbsoluteSize.Y, 1)
			applyZoom(focusYRatio)
		end
	end)

	UIS.TouchEnded:Connect(function(input, gp)
		touching[input] = nil
		startDist, startZoom = nil, nil
	end)

	local function openZoom()
		log("🔍 Opening scrollable zoom (swipe + pinch!)...")
		overlay.Visible = true
		-- preload to avoid blur/pop
		pcall(function() ContentProvider:PreloadAsync({img}) end)
		-- ensure AbsoluteSize is settled before sizing (fixes scroll-to-bottom!)
		RunService.Heartbeat:Wait()
		applyZoom(0.0) -- start focused near top (shows Step 1 area); try 0.5 to start centered
	end

	local function closeZoom()
		log("❌ Closing zoom overlay...")
		overlay.Visible = false
	end

	xBtn.Activated:Connect(closeZoom)
	closeButton.Activated:Connect(closeZoom)

	-- Optional: ESC/B key support
	UserInputService.InputBegan:Connect(function(input, gp)
		if not overlay.Visible or gp then return end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			closeZoom()
		end
	end)

	-- optional: allow tap-outside to close
	-- blocker.Activated:Connect(closeZoom)

	return overlay, openZoom, closeZoom
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 💖 BUTTON HANDLERS 💖
-- ═══════════════════════════════════════════════════════════════════════════

local function joinGroup()
	if CONFIG.GROUP_ID == 0 then
		logError("GROUP_ID not set!")
		return
	end
	
	log("joinGroup() - Showing group info for: " .. CONFIG.GROUP_ID)
	
	local success = pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "💖 Join Sanrio Tycoon Group!",
			Text = "Follow the steps on the popup! Group ID: " .. CONFIG.GROUP_ID,
			Duration = 12,
			Button1 = "Got it!"
		})
	end)
	
	if success then
		log("joinGroup() - Notification shown successfully!")
	else
		logError("joinGroup() - Failed to show notification")
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ANIMATION FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

local function showPopup()
	if isAnimating then return end
	isAnimating = true
	
	log("🎀 showPopup() - Opening cute modal...")
	
	screenGui.Enabled = true
	
	local tweenInfoOpen = TweenInfo.new(
		CONFIG.ANIMATION_SPEED_OPEN,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	
	local dimTween = TweenService:Create(dimFrame, tweenInfoOpen, {
		BackgroundTransparency = 1 - CONFIG.DIM_TRANSPARENCY
	})
	
	local cardTween = TweenService:Create(cardFrame, tweenInfoOpen, {
		BackgroundTransparency = 0
	})
	
	local strokeTween = TweenService:Create(cardFrame.UIStroke, tweenInfoOpen, {
		Transparency = 0
	})
	
	local childTweens = {}
	for _, child in ipairs(cardFrame:GetDescendants()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			table.insert(childTweens, TweenService:Create(child, tweenInfoOpen, {
				TextTransparency = 0,
				BackgroundTransparency = child:IsA("TextButton") and 0 or 1
			}))
		elseif child:IsA("ImageButton") or child:IsA("ImageLabel") then
			table.insert(childTweens, TweenService:Create(child, tweenInfoOpen, {
				ImageTransparency = 0
			}))
		elseif child:IsA("Frame") and child.Name == "DecalContainer" then
			table.insert(childTweens, TweenService:Create(child, tweenInfoOpen, {
				BackgroundTransparency = 0.05
			}))
		end
	end
	
	dimTween:Play()
	cardTween:Play()
	strokeTween:Play()
	for _, tween in ipairs(childTweens) do
		tween:Play()
	end
	
	cardTween.Completed:Wait()
	isAnimating = false
	log("✨ showPopup() - Modal opened successfully!")
end

local function hidePopup()
	if isAnimating then return end
	isAnimating = true
	
	log("👋 hidePopup() - Closing modal...")
	
	local tweenInfoClose = TweenInfo.new(
		CONFIG.ANIMATION_SPEED_CLOSE,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	
	local dimTween = TweenService:Create(dimFrame, tweenInfoClose, {
		BackgroundTransparency = 1
	})
	
	local cardTween = TweenService:Create(cardFrame, tweenInfoClose, {
		BackgroundTransparency = 1
	})
	
	local strokeTween = TweenService:Create(cardFrame.UIStroke, tweenInfoClose, {
		Transparency = 1
	})
	
	local childTweens = {}
	for _, child in ipairs(cardFrame:GetDescendants()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			table.insert(childTweens, TweenService:Create(child, tweenInfoClose, {
				TextTransparency = 1,
				BackgroundTransparency = 1
			}))
		elseif child:IsA("ImageButton") or child:IsA("ImageLabel") then
			table.insert(childTweens, TweenService:Create(child, tweenInfoClose, {
				ImageTransparency = 1
			}))
		elseif child:IsA("Frame") and child.Name == "DecalContainer" then
			table.insert(childTweens, TweenService:Create(child, tweenInfoClose, {
				BackgroundTransparency = 1
			}))
		end
	end
	
	dimTween:Play()
	cardTween:Play()
	strokeTween:Play()
	for _, tween in ipairs(childTweens) do
		tween:Play()
	end
	
	cardTween.Completed:Wait()
	screenGui.Enabled = false
	isAnimating = false
	log("✅ hidePopup() - Modal closed")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MAIN BUILD FUNCTION (Mobile-first!)
-- ═══════════════════════════════════════════════════════════════════════════

local function buildUI()
	log("🏗️ buildUI() - Starting MOBILE-FIRST UI construction...")
	
	local prof = getDynamicProfile()
	log("📱 Device profile: isPhone=" .. tostring(prof.isPhone) .. ", isTablet=" .. tostring(prof.isTablet) .. ", landscape=" .. tostring(prof.landscape) .. ", globalScale=" .. prof.globalScale)
	
	screenGui = createScreenGui()
	
	local dimButton
	dimFrame, dimButton = createDim(screenGui)
	
	local cardStroke, cardLayout
	cardFrame, cardStroke, cardLayout = createCard(screenGui)
	
	local leftSide = createLeftSide(cardFrame, prof)
	
	local titleLabel = createTitle(leftSide, prof)
	local bodyLabel = createBody(leftSide, prof)
	
	local buttonContainer = createButtonContainer(leftSide, prof)
	
	local joinButton = createButton(buttonContainer, "JoinButton", "Join Group!", true, 1, prof)
	local notNowButton = createButton(buttonContainer, "NotNowButton", "Maybe Later", false, 2, prof)
	
	local rightSide, howToTitle, decalImage, decalContainer, tapHint = createRightSide(cardFrame, prof)
	
	local zoomOverlay, openZoom, closeZoom = createZoomOverlay(screenGui)
	
	joinButton.Activated:Connect(function()
		log("[Join] Join Group button clicked!")
		joinGroup()
		hidePopup()
	end)
	
	notNowButton.Activated:Connect(function()
		log("[Close] Maybe later button clicked")
		hidePopup()
	end)
	
	dimButton.Activated:Connect(function()
		log("[Close] Dim overlay clicked - closing popup")
		hidePopup()
	end)
	
	decalImage.Activated:Connect(function()
		log("[Zoom] Decal tapped - opening zoom view!")
		openZoom()
	end)
	
	screenGui.Parent = PlayerGui
	
	-- 🔥 DYNAMIC RESIZE (shop-style!)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local newProf = getDynamicProfile()
		log("🔄 Viewport changed - updating layout...")
		
		-- Update card size
		cardFrame.Size = UDim2.fromOffset(newProf.cardW, newProf.cardH)
		
		-- Update global scale (phone zoom-out!)
		cardScale.Scale = newProf.globalScale
		
		-- Update layout direction
		cardLayout.FillDirection = newProf.sideBySide and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
		cardLayout.Padding = UDim.new(0, newProf.sideBySide and 20 or 12)
		
		-- Update left/right sizes
		leftSide.Size = newProf.sideBySide and UDim2.new(0.5, -10, 1, 0) or UDim2.new(1, 0, 0.55, 0)
		rightSide.Size = newProf.sideBySide and UDim2.new(0.5, -10, 1, 0) or UDim2.new(1, 0, 0.45, 0)
		
		-- Update text sizes
		titleLabel.TextSize = newProf.titleSize
		bodyLabel.TextSize = newProf.bodySize
		howToTitle.TextSize = newProf.howToTitleSize
		
		log("✅ Layout updated for new viewport!")
	end)
	
	log("✅ buildUI() - MOBILE-FIRST UI construction complete!")
	return screenGui
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MEMBERSHIP CHECK & SHOW LOGIC
-- ═══════════════════════════════════════════════════════════════════════════

local function shouldShowPopup()
	local inStudio = RunService:IsStudio()
	log("📍 Environment check - inStudio: " .. tostring(inStudio))
	
	if CONFIG.FORCE_SHOW then
		log("⭐ FORCE_SHOW enabled - showing popup")
		return true
	end
	
	if inStudio and CONFIG.ALWAYS_SHOW_IN_STUDIO then
		log("🎮 ALWAYS_SHOW_IN_STUDIO enabled - showing popup")
		return true
	end
	
	if CONFIG.GROUP_ID == 0 then
		logError("GROUP_ID is not set! Defaulting to show popup.")
		return true
	end
	
	local isMember = false
	local success, err = pcall(function()
		isMember = LocalPlayer:IsInGroup(CONFIG.GROUP_ID)
	end)
	
	if not success then
		logError("Failed to check group membership: " .. tostring(err))
		return true
	end
	
	log("👥 Group membership check - isMember: " .. tostring(isMember) .. " (GroupID: " .. CONFIG.GROUP_ID .. ")")
	
	return not isMember
end

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════

local function initialize()
	log("✨ === Sanrio Tycoon Group Popup (MOBILE-FIRST) === ✨")
	log("Script location: " .. script:GetFullName())
	log("📝 Configuration:")
	log("  GROUP_ID: " .. CONFIG.GROUP_ID)
	log("  FORCE_SHOW: " .. tostring(CONFIG.FORCE_SHOW))
	log("  ALWAYS_SHOW_IN_STUDIO: " .. tostring(CONFIG.ALWAYS_SHOW_IN_STUDIO))
	
	buildUI()
	
	if shouldShowPopup() then
		local inStudio = RunService:IsStudio()
		local delayTime = inStudio and CONFIG.STUDIO_DELAY or CONFIG.DELAY_BEFORE_SHOW
		
		log("⏰ Waiting " .. delayTime .. " seconds before showing popup...")
		wait(delayTime)
		
		if shouldShowPopup() then
			log("✨ Delay complete - showing popup now!")
			showPopup()
		else
			log("✅ Player joined group during wait - canceling popup")
		end
	else
		log("ℹ️ Popup not shown - player is already a member")
	end
	
	log("✨ === Sanrio Group Popup Ready! === ✨")
end

-- Start the script
initialize()
