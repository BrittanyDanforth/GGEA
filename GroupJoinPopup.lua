--[[
	🎀 Sanrio Tycoon Group Popup 🎀
	A cute, pastel-themed group join popup for Roblox
	Place in StarterPlayerScripts or StarterGui
	
	Features:
	- Adorable Sanrio-inspired pastel design
	- Modern SocialService group join (NO OpenUrl!)
	- Smooth animations
	- Full UI hierarchy (no missing elements)
	- Group membership detection
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- 🌸 CONFIGURATION 🌸
-- ═══════════════════════════════════════════════════════════════════════════

local CONFIG = {
	GROUP_ID = 0, -- ⭐ SET YOUR GROUP ID HERE! (e.g., 12345678)
	
	-- Testing flags
	FORCE_SHOW = true, -- Always show popup (ignores membership check)
	ALWAYS_SHOW_IN_STUDIO = true, -- Show in Studio even if member
	
	-- 🎨 Cute Pastel Colors (Sanrio theme)
	COLORS = {
		-- Card background - soft white with slight pink tint
		CARD_BG = Color3.fromRGB(255, 250, 252),
		-- Gradient overlay - soft pink to lavender
		GRADIENT_TOP = Color3.fromRGB(255, 228, 240),
		GRADIENT_BOTTOM = Color3.fromRGB(240, 230, 255),
		-- Primary button - cute pink
		BUTTON_PRIMARY = Color3.fromRGB(255, 182, 213),
		BUTTON_PRIMARY_HOVER = Color3.fromRGB(255, 158, 200),
		-- Secondary button - soft lavender
		BUTTON_SECONDARY = Color3.fromRGB(230, 220, 255),
		BUTTON_SECONDARY_HOVER = Color3.fromRGB(215, 200, 255),
		-- Text colors
		TITLE = Color3.fromRGB(255, 105, 180), -- Hot pink but softer
		BODY = Color3.fromRGB(150, 120, 160), -- Soft purple-grey
		BUTTON_TEXT = Color3.fromRGB(255, 255, 255),
		BUTTON_TEXT_SECONDARY = Color3.fromRGB(150, 120, 160),
		-- Border/stroke - very soft pink
		STROKE = Color3.fromRGB(255, 220, 235),
	},
	
	-- UI Configuration
	CARD_SIZE = UDim2.new(0, 480, 0, 360),
	DIM_TRANSPARENCY = 0.4,
	ANIMATION_SPEED_OPEN = 0.3,
	ANIMATION_SPEED_CLOSE = 0.2,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🎮 SERVICES 🎮
-- ═══════════════════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SocialService = game:GetService("SocialService") -- MODERN group join!
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

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
local isAnimating = false

-- ═══════════════════════════════════════════════════════════════════════════
-- UI CREATION (Build entire hierarchy first, no early returns)
-- ═══════════════════════════════════════════════════════════════════════════

local function createScreenGui()
	log("🎨 Creating ScreenGui...")
	
	local gui = Instance.new("ScreenGui")
	gui.Name = "SanrioGroupJoinPopup"
	gui.DisplayOrder = 10000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false -- Start hidden, will show after membership check
	
	return gui
end

local function createDim(parent)
	log("🌈 Creating Dim overlay...")
	
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.Position = UDim2.new(0, 0, 0, 0)
	dim.BackgroundColor3 = Color3.fromRGB(20, 10, 30) -- Slightly purple-tinted
	dim.BackgroundTransparency = 1 -- Start invisible
	dim.BorderSizePixel = 0
	dim.ZIndex = 10
	dim.Parent = parent
	
	-- Make clickable to close
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
	log("💝 Creating Card...")
	
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = CONFIG.CARD_SIZE
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = CONFIG.COLORS.CARD_BG
	card.BackgroundTransparency = 1 -- Start invisible
	card.BorderSizePixel = 0
	card.ZIndex = 20
	card.Parent = parent
	
	-- Cute rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 20) -- More rounded = cuter!
	corner.Parent = card
	
	-- Soft pastel gradient overlay
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, CONFIG.COLORS.GRADIENT_TOP),
		ColorSequenceKeypoint.new(1, CONFIG.COLORS.GRADIENT_BOTTOM)
	})
	gradient.Rotation = 135 -- Diagonal gradient
	gradient.Transparency = NumberSequence.new(0.7) -- Subtle
	gradient.Parent = card
	
	-- Cute pastel stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = CONFIG.COLORS.STROKE
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Transparency = 1 -- Start invisible
	stroke.Parent = card
	
	-- Cozy padding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 35)
	padding.PaddingBottom = UDim.new(0, 35)
	padding.PaddingLeft = UDim.new(0, 35)
	padding.PaddingRight = UDim.new(0, 35)
	padding.Parent = card
	
	-- Layout with cute spacing
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 15)
	layout.Parent = card
	
	return card, stroke
end

local function createTitle(parent)
	log("✨ Creating Title...")
	
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Text = "Join My Sanrio Tycoon Group!"
	title.Font = Enum.Font.FredokaOne -- Cute rounded font!
	title.TextSize = 28
	title.TextColor3 = CONFIG.COLORS.TITLE
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextTransparency = 1 -- Start invisible
	title.ZIndex = 21
	title.LayoutOrder = 1
	title.Parent = parent
	
	-- Cute text stroke for depth
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(255, 255, 255)
	textStroke.Thickness = 2
	textStroke.Transparency = 0.5
	textStroke.Parent = title
	
	return title
end

local function createBody(parent)
	log("📝 Creating Body text...")
	
	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 0, 90)
	body.BackgroundTransparency = 1
	body.Text = "Join our adorable Sanrio-themed community! Get exclusive perks, chat with fellow Hello Kitty & Kuromi fans, and unlock special rewards in the tycoon!"
	body.Font = Enum.Font.GothamMedium
	body.TextSize = 16
	body.TextColor3 = CONFIG.COLORS.BODY
	body.TextXAlignment = Enum.TextXAlignment.Center
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.TextTransparency = 1 -- Start invisible
	body.ZIndex = 21
	body.LayoutOrder = 2
	body.Parent = parent
	
	return body
end

local function createButton(parent, name, text, isPrimary, layoutOrder)
	log("🔘 Creating button: " .. name)
	
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(0, 180, 0, 48)
	button.BackgroundColor3 = isPrimary and CONFIG.COLORS.BUTTON_PRIMARY or CONFIG.COLORS.BUTTON_SECONDARY
	button.BackgroundTransparency = 1 -- Start invisible
	button.BorderSizePixel = 0
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.TextColor3 = isPrimary and CONFIG.COLORS.BUTTON_TEXT or CONFIG.COLORS.BUTTON_TEXT_SECONDARY
	button.TextTransparency = 1 -- Start invisible
	button.AutoButtonColor = false
	button.ZIndex = 21
	button.LayoutOrder = layoutOrder
	button.Parent = parent
	
	-- Cute rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12) -- More rounded
	corner.Parent = button
	
	-- Soft shadow effect
	local shadow = Instance.new("UIStroke")
	shadow.Color = isPrimary and Color3.fromRGB(255, 150, 190) or Color3.fromRGB(200, 190, 230)
	shadow.Thickness = 0
	shadow.Transparency = 0
	shadow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	shadow.Parent = button
	
	-- Cute bounce hover effect
	button.MouseEnter:Connect(function()
		local hoverColor = isPrimary and CONFIG.COLORS.BUTTON_PRIMARY_HOVER or CONFIG.COLORS.BUTTON_SECONDARY_HOVER
		TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = hoverColor,
			Size = UDim2.new(0, 185, 0, 50) -- Slight grow
		}):Play()
		TweenService:Create(shadow, TweenInfo.new(0.2), {Thickness = 2}):Play()
	end)
	
	button.MouseLeave:Connect(function()
		local normalColor = isPrimary and CONFIG.COLORS.BUTTON_PRIMARY or CONFIG.COLORS.BUTTON_SECONDARY
		TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = normalColor,
			Size = UDim2.new(0, 180, 0, 48) -- Back to normal
		}):Play()
		TweenService:Create(shadow, TweenInfo.new(0.2), {Thickness = 0}):Play()
	end)
	
	return button
end

local function createButtonContainer(parent)
	log("🎯 Creating button container...")
	
	local container = Instance.new("Frame")
	container.Name = "ButtonContainer"
	container.Size = UDim2.new(1, 0, 0, 50)
	container.BackgroundTransparency = 1
	container.ZIndex = 21
	container.LayoutOrder = 3
	container.Parent = parent
	
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 12) -- Cute spacing between buttons
	layout.Parent = container
	
	return container
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ANIMATION FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

local function showPopup()
	if isAnimating then return end
	isAnimating = true
	
	log("🎀 showPopup() - Opening cute modal...")
	
	screenGui.Enabled = true
	
	-- Animation info
	local tweenInfoOpen = TweenInfo.new(
		CONFIG.ANIMATION_SPEED_OPEN,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	
	-- Fade in dim
	local dimTween = TweenService:Create(dimFrame, tweenInfoOpen, {
		BackgroundTransparency = 1 - CONFIG.DIM_TRANSPARENCY
	})
	
	-- Fade in card
	local cardTween = TweenService:Create(cardFrame, tweenInfoOpen, {
		BackgroundTransparency = 0
	})
	
	-- Fade in stroke
	local strokeTween = TweenService:Create(cardFrame.UIStroke, tweenInfoOpen, {
		Transparency = 0
	})
	
	-- Fade in all children
	local childTweens = {}
	for _, child in ipairs(cardFrame:GetDescendants()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			table.insert(childTweens, TweenService:Create(child, tweenInfoOpen, {
				TextTransparency = 0,
				BackgroundTransparency = child:IsA("TextButton") and 0 or 1
			}))
		end
	end
	
	-- Play all tweens
	dimTween:Play()
	cardTween:Play()
	strokeTween:Play()
	for _, tween in ipairs(childTweens) do
		tween:Play()
	end
	
	-- Wait for completion
	cardTween.Completed:Wait()
	isAnimating = false
	log("✨ showPopup() - Modal opened successfully!")
end

local function hidePopup()
	if isAnimating then return end
	isAnimating = true
	
	log("👋 hidePopup() - Closing modal...")
	
	-- Animation info
	local tweenInfoClose = TweenInfo.new(
		CONFIG.ANIMATION_SPEED_CLOSE,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	
	-- Fade out dim
	local dimTween = TweenService:Create(dimFrame, tweenInfoClose, {
		BackgroundTransparency = 1
	})
	
	-- Fade out card
	local cardTween = TweenService:Create(cardFrame, tweenInfoClose, {
		BackgroundTransparency = 1
	})
	
	-- Fade out stroke
	local strokeTween = TweenService:Create(cardFrame.UIStroke, tweenInfoClose, {
		Transparency = 1
	})
	
	-- Fade out all children
	local childTweens = {}
	for _, child in ipairs(cardFrame:GetDescendants()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			table.insert(childTweens, TweenService:Create(child, tweenInfoClose, {
				TextTransparency = 1,
				BackgroundTransparency = 1
			}))
		end
	end
	
	-- Play all tweens
	dimTween:Play()
	cardTween:Play()
	strokeTween:Play()
	for _, tween in ipairs(childTweens) do
		tween:Play()
	end
	
	-- Wait for completion then disable
	cardTween.Completed:Wait()
	screenGui.Enabled = false
	isAnimating = false
	log("✅ hidePopup() - Modal closed")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 💖 BUTTON HANDLERS 💖
-- ═══════════════════════════════════════════════════════════════════════════

local function joinGroup()
	if CONFIG.GROUP_ID == 0 then
		logError("GROUP_ID not set! Please configure your group ID.")
		return
	end
	
	log("joinGroup() - Opening group join prompt for group: " .. CONFIG.GROUP_ID)
	
	-- Use MODERN SocialService (works in real Roblox!)
	local success, err = pcall(function()
		SocialService:PromptGroupJoin(CONFIG.GROUP_ID)
	end)
	
	if success then
		log("joinGroup() - Successfully opened group join prompt!")
	else
		logError("joinGroup() - Failed to open prompt: " .. tostring(err))
		
		-- Fallback notification
		pcall(function()
			game:GetService("StarterGui"):SetCore("SendNotification", {
				Title = "Join Sanrio Tycoon Group",
				Text = "Search for group ID: " .. CONFIG.GROUP_ID,
				Duration = 8
			})
		end)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MAIN BUILD FUNCTION (No early returns - builds everything first)
-- ═══════════════════════════════════════════════════════════════════════════

local function buildUI()
	log("🏗️ buildUI() - Starting UI construction...")
	
	-- Step 1: Create ScreenGui
	screenGui = createScreenGui()
	
	-- Step 2: Create Dim overlay (ZIndex 10)
	local dimButton
	dimFrame, dimButton = createDim(screenGui)
	
	-- Step 3: Create Card (ZIndex 20)
	local cardStroke
	cardFrame, cardStroke = createCard(screenGui)
	
	-- Step 4: Create Title (ZIndex 21)
	local titleLabel = createTitle(cardFrame)
	
	-- Step 5: Create Body (ZIndex 21)
	local bodyLabel = createBody(cardFrame)
	
	-- Step 6: Create Button Container (ZIndex 21)
	local buttonContainer = createButtonContainer(cardFrame)
	
	-- Step 7: Create Buttons (ZIndex 21)
	local joinButton = createButton(buttonContainer, "JoinButton", "✨ Join Group!", true, 1)
	local notNowButton = createButton(buttonContainer, "NotNowButton", "Maybe Later", false, 2)
	
	-- Step 8: Wire up button handlers (after everything is built)
	joinButton.MouseButton1Click:Connect(function()
		log("🎀 Join Group button clicked!")
		joinGroup()
		hidePopup()
	end)
	
	notNowButton.MouseButton1Click:Connect(function()
		log("🚫 Maybe later button clicked")
		hidePopup()
	end)
	
	dimButton.MouseButton1Click:Connect(function()
		log("✨ Dim overlay clicked - closing popup")
		hidePopup()
	end)
	
	-- Step 9: Parent to PlayerGui (last step to avoid rendering issues)
	screenGui.Parent = PlayerGui
	
	log("✅ buildUI() - UI construction complete!")
	return screenGui
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MEMBERSHIP CHECK & SHOW LOGIC
-- ═══════════════════════════════════════════════════════════════════════════

local function shouldShowPopup()
	local inStudio = RunService:IsStudio()
	log("📍 Environment check - inStudio: " .. tostring(inStudio))
	
	-- Force show if enabled
	if CONFIG.FORCE_SHOW then
		log("⭐ FORCE_SHOW enabled - showing popup")
		return true
	end
	
	-- Always show in Studio if flag is set
	if inStudio and CONFIG.ALWAYS_SHOW_IN_STUDIO then
		log("🎮 ALWAYS_SHOW_IN_STUDIO enabled - showing popup")
		return true
	end
	
	-- Check group membership
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
		return true -- Show on error to be safe
	end
	
	log("👥 Group membership check - isMember: " .. tostring(isMember) .. " (GroupID: " .. CONFIG.GROUP_ID .. ")")
	
	return not isMember
end

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════

local function initialize()
	log("✨ === Sanrio Tycoon Group Popup Initializing === ✨")
	log("Script location: " .. script:GetFullName())
	log("📝 Configuration:")
	log("  GROUP_ID: " .. CONFIG.GROUP_ID)
	log("  FORCE_SHOW: " .. tostring(CONFIG.FORCE_SHOW))
	log("  ALWAYS_SHOW_IN_STUDIO: " .. tostring(CONFIG.ALWAYS_SHOW_IN_STUDIO))
	
	-- CRITICAL: Build UI first, ALWAYS (no early returns)
	buildUI()
	
	-- THEN check if we should show it
	if shouldShowPopup() then
		wait(0.5) -- Small delay for better UX
		showPopup()
	else
		log("Popup not shown - player is already a member")
	end
	
	log("✨ === Sanrio Group Popup Ready! === ✨")
end

-- Start the script
initialize()
