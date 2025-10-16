--[[
	GroupJoinPopup - A self-contained LocalScript for Roblox
	Place in StarterPlayerScripts or StarterGui
	
	Creates a professional "Join Group" modal with:
	- Full UI hierarchy (no missing elements)
	- Proper ZIndex layering
	- Smooth animations
	- Group membership detection
	- No external dependencies
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════

local CONFIG = {
	GROUP_ID = 0, -- Set your Roblox group ID here (e.g., 12345678)
	GROUP_URL = "https://www.roblox.com/groups/0/your-group", -- Your group URL
	
	-- Testing flags
	FORCE_SHOW = true, -- Always show popup (ignores membership check)
	ALWAYS_SHOW_IN_STUDIO = true, -- Show in Studio even if member
	
	-- UI Configuration
	CARD_SIZE = UDim2.new(0, 520, 0, 340),
	DIM_TRANSPARENCY = 0.35,
	ANIMATION_SPEED_OPEN = 0.25,
	ANIMATION_SPEED_CLOSE = 0.2,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════════════════════════════════
-- LOGGING
-- ═══════════════════════════════════════════════════════════════════════════

local function log(message)
	print("[GroupPopup]", message)
end

local function logError(message)
	warn("[GroupPopup] ERROR:", message)
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
	log("Creating ScreenGui...")
	
	local gui = Instance.new("ScreenGui")
	gui.Name = "GroupJoinPopup"
	gui.DisplayOrder = 10000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false -- Start hidden, will show after membership check
	
	return gui
end

local function createDim(parent)
	log("Creating Dim overlay...")
	
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.Position = UDim2.new(0, 0, 0, 0)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
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
	log("Creating Card...")
	
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = CONFIG.CARD_SIZE
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	card.BackgroundTransparency = 1 -- Start invisible
	card.BorderSizePixel = 0
	card.ZIndex = 20
	card.Parent = parent
	
	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card
	
	-- Stroke for depth
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(220, 220, 220)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Transparency = 1 -- Start invisible
	stroke.Parent = card
	
	-- Padding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 40)
	padding.PaddingBottom = UDim.new(0, 40)
	padding.PaddingLeft = UDim.new(0, 40)
	padding.PaddingRight = UDim.new(0, 40)
	padding.Parent = card
	
	-- Layout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 20)
	layout.Parent = card
	
	return card, stroke
end

local function createTitle(parent)
	log("Creating Title...")
	
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.Text = "Join Our Group"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 32
	title.TextColor3 = Color3.fromRGB(30, 30, 30)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextTransparency = 1 -- Start invisible
	title.ZIndex = 21
	title.LayoutOrder = 1
	title.Parent = parent
	
	return title
end

local function createBody(parent)
	log("Creating Body text...")
	
	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 0, 80)
	body.BackgroundTransparency = 1
	body.Text = "Join our community to unlock exclusive benefits, participate in events, and connect with other members!"
	body.Font = Enum.Font.Gotham
	body.TextSize = 18
	body.TextColor3 = Color3.fromRGB(80, 80, 80)
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
	log("Creating button: " .. name)
	
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(0, 200, 0, 50)
	button.BackgroundColor3 = isPrimary and Color3.fromRGB(0, 162, 255) or Color3.fromRGB(240, 240, 240)
	button.BackgroundTransparency = 1 -- Start invisible
	button.BorderSizePixel = 0
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.TextColor3 = isPrimary and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(80, 80, 80)
	button.TextTransparency = 1 -- Start invisible
	button.AutoButtonColor = false
	button.ZIndex = 21
	button.LayoutOrder = layoutOrder
	button.Parent = parent
	
	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	
	-- Hover effect
	button.MouseEnter:Connect(function()
		if isPrimary then
			TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(0, 142, 235)}):Play()
		else
			TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(220, 220, 220)}):Play()
		end
	end)
	
	button.MouseLeave:Connect(function()
		if isPrimary then
			TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(0, 162, 255)}):Play()
		else
			TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(240, 240, 240)}):Play()
		end
	end)
	
	return button
end

local function createButtonContainer(parent)
	log("Creating button container...")
	
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
	layout.Padding = UDim.new(0, 16)
	layout.Parent = container
	
	return container
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ANIMATION FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

local function showPopup()
	if isAnimating then return end
	isAnimating = true
	
	log("showPopup() - Opening modal...")
	
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
	log("showPopup() - Modal opened")
end

local function hidePopup()
	if isAnimating then return end
	isAnimating = true
	
	log("hidePopup() - Closing modal...")
	
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
	log("hidePopup() - Modal closed")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- BUTTON HANDLERS
-- ═══════════════════════════════════════════════════════════════════════════

local function openGroupUrl()
	log("openGroupUrl() - Attempting to open: " .. CONFIG.GROUP_URL)
	
	local success, err = pcall(function()
		StarterGui:SetCore("OpenUrl", CONFIG.GROUP_URL)
	end)
	
	if success then
		log("openGroupUrl() - Successfully opened URL")
	else
		logError("openGroupUrl() - Failed to open URL: " .. tostring(err))
		
		-- Fallback: Show notification with URL
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = "Join Our Group",
				Text = "Visit: " .. CONFIG.GROUP_URL,
				Duration = 10
			})
		end)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MAIN BUILD FUNCTION (No early returns - builds everything first)
-- ═══════════════════════════════════════════════════════════════════════════

local function buildUI()
	log("buildUI() - Starting UI construction...")
	
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
	local joinButton = createButton(buttonContainer, "JoinButton", "Join Group", true, 1)
	local notNowButton = createButton(buttonContainer, "NotNowButton", "Not now", false, 2)
	
	-- Step 8: Wire up button handlers (after everything is built)
	joinButton.MouseButton1Click:Connect(function()
		log("Join Group button clicked")
		openGroupUrl()
		hidePopup()
	end)
	
	notNowButton.MouseButton1Click:Connect(function()
		log("Not now button clicked")
		hidePopup()
	end)
	
	dimButton.MouseButton1Click:Connect(function()
		log("Dim overlay clicked")
		hidePopup()
	end)
	
	-- Step 9: Parent to PlayerGui (last step to avoid rendering issues)
	screenGui.Parent = PlayerGui
	
	log("buildUI() - UI construction complete!")
	return screenGui
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MEMBERSHIP CHECK & SHOW LOGIC
-- ═══════════════════════════════════════════════════════════════════════════

local function shouldShowPopup()
	local inStudio = RunService:IsStudio()
	log("Environment check - inStudio: " .. tostring(inStudio))
	
	-- Force show if enabled
	if CONFIG.FORCE_SHOW then
		log("FORCE_SHOW enabled - showing popup")
		return true
	end
	
	-- Always show in Studio if flag is set
	if inStudio and CONFIG.ALWAYS_SHOW_IN_STUDIO then
		log("ALWAYS_SHOW_IN_STUDIO enabled - showing popup")
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
	
	log("Group membership check - isMember: " .. tostring(isMember) .. " (GroupID: " .. CONFIG.GROUP_ID .. ")")
	
	return not isMember
end

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════

local function initialize()
	log("=== GroupJoinPopup Initializing ===")
	log("Script location: " .. script:GetFullName())
	log("Configuration:")
	log("  GROUP_ID: " .. CONFIG.GROUP_ID)
	log("  GROUP_URL: " .. CONFIG.GROUP_URL)
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
	
	log("=== GroupJoinPopup Initialization Complete ===")
end

-- Start the script
initialize()
