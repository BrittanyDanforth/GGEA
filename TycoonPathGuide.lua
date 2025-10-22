--[[
	CLIENT-ONLY TYCOON PATH GUIDE + TUTORIAL [v6.1 - ULTRA POLISHED]
	✅ Perfect integration with your purchase handler & auto-collect
	✅ Monitors leaderstats.Cash for auto-collect compatibility
	✅ Ultra-smooth simultaneous transitions
	✅ Instant path fade when gate claimed
	✅ Mobile-first responsive design
	
	Place in: StarterPlayer > StarterPlayerScripts as a LocalScript
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")

--============================================================================--
--                              CONFIGURATION
--============================================================================--
local Config = {
	-- Visual Appearance
	Colors = {
		PATH = Color3.fromRGB(255, 179, 212),      -- Light Pink
		GLOW = Color3.fromRGB(255, 204, 229),      -- Lighter Pink Glow
		PULSE = Color3.fromRGB(255, 230, 240),     -- Ultra Light Pink
		TUTORIAL_HIGHLIGHT = Color3.fromRGB(100, 200, 255), -- Blue highlight
		TUTORIAL_CARD_BG = Color3.fromRGB(255, 248, 252),
		TUTORIAL_STROKE = Color3.fromRGB(255, 180, 210),
	},

	-- Path Geometry
	SEGMENT_SIZE = Vector3.new(2, 0.1, 1),
	SEGMENT_SPACING = 2.5,
	MAX_SEGMENTS = 40,
	GROUND_OFFSET = 0.05,
	SCALE_REDUCTION = 0.2,
	PATH_ARC_HEIGHT = 0.08,

	-- Distance Settings
	MIN_DISTANCE = 5,
	MAX_DISTANCE = 300,
	PATH_END_OFFSET = 3,

	-- Animation Parameters
	PULSE_SPEED = 2,
	FLOW_SPEED = 3,
	FADE_IN_TIME = 0.3,
	FADE_OUT_TIME = 0.25, -- Faster fade out
	TEXT_TRANSITION_TIME = 0.25, -- Faster text transition

	-- Smoothing & Performance
	POSITION_SMOOTHING = 0.3,
	TARGET_SMOOTHING = 0.25,
	TRANSPARENCY_SMOOTHING = 0.25, -- Faster transparency changes
	GATE_UPDATE_INTERVAL = 0.3, -- Faster gate checks
	PATH_UPDATE_RATE = 1/30,

	-- Anti-bunching
	BUNCHING_THRESHOLD = 0.6,
	MAX_BUNCH_FADE = 0.7,

	-- Light Settings
	LIGHT_BASE_BRIGHTNESS = 0.2,
	LIGHT_PULSE_BRIGHTNESS = 0.3,
	LIGHT_BASE_RANGE = 8,
	GLOW_BASE_TRANSPARENCY = 0.4,
	GLOW_PULSE_AMOUNT = 0.1,

	-- 🎓 TUTORIAL SETTINGS
	TUTORIAL_ENABLED = true,
	TUTORIAL_STEP_DELAY = 0.3, -- Faster step transitions
	TUTORIAL_STEPS = {
		{
			name = "claim_gate",
			title = "Welcome to Your Tycoon! 🎀",
			description = "Touch the gate to claim your tycoon!",
			target = "gate",
			waitForGateClaim = true,
		},
		{
			name = "buy_dropper1",
			title = "Buy Your First Dropper! 💎",
			description = "This will drop cute items that turn into cash!\n\nWalk to the glowing button and touch it.",
			targetButton = "Begin Working!",
			waitForPurchase = "Dropper1",
		},
		{
			name = "collect_money",
			title = "Earning Cash! 💰",
			description = "Your dropper is working! Cash is being collected automatically.\n\nYou'll need $70 for the next upgrade.",
			target = "collector",
			waitForCash = true,
		},
		{
			name = "buy_dropper2",
			title = "Buy Your Second Dropper! ✨",
			description = "Nice! You have enough cash now.\n\nBuy the second dropper to earn even faster!",
			targetButton = "Buy Dropper - [$70]",
			waitForPurchase = "Dropper2",
		},
		{
			name = "tutorial_complete",
			title = "You're All Set! 🎉",
			description = "Amazing! Keep buying upgrades to grow your tycoon.\n\nTap anywhere to close.",
			target = nil,
			autoClose = 5,
		},
	},
}

--============================================================================--
--                     🎓 TUTORIAL STATE MANAGEMENT
--============================================================================--
local TutorialState = {
	enabled = Config.TUTORIAL_ENABLED,
	currentStep = 1,
	completed = false,
	isTransitioning = false,
	highlightPart = nil,
	tutorialGui = nil,
	skipButton = nil,
	connections = {},
	initialCash = 0,
}

--============================================================================--
--                            STATE MANAGEMENT
--============================================================================--
local PathState = {
	active = false,
	currentTargetGate = nil,
	smoothedStartPos = nil,
	smoothedEndPos = nil,
	pathModel = nil,
	segments = {},
	cachedGates = {},
	lastGateUpdate = 0,
	animationTime = 0,
	ownedTycoon = false,
	playerTycoon = nil,
	fadingOut = false, -- New flag for smooth fade
}

-- Raycast parameters
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
raycastParams.IgnoreWater = true

--============================================================================--
--                     📱 MOBILE DETECTION
--============================================================================--
local function viewport()
	return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
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

--============================================================================--
--                       🎓 TUTORIAL UI SYSTEM
--============================================================================--

local function createTutorialUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialGui"
	gui.DisplayOrder = 10000
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local phone = isPhone()
	local tablet = isTablet()

	-- Responsive sizing
	local cardW = phone and 340 or (tablet and 400 or 450)
	local cardH = phone and 150 or (tablet and 135 or 125)
	local titleSize = phone and 20 or (tablet and 22 or 24)
	local bodySize = phone and 14 or (tablet and 15 or 16)

	-- Subtle overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.Parent = gui

	-- Card container
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, -cardH - 50)
	card.Size = UDim2.fromOffset(cardW, cardH)
	card.BackgroundColor3 = Config.Colors.TUTORIAL_CARD_BG
	card.BorderSizePixel = 0
	card.Parent = gui

	-- Card styling
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Config.Colors.TUTORIAL_STROKE
	stroke.Thickness = 3
	stroke.Transparency = 0
	stroke.Parent = card

	-- Shadow effect
	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.fromScale(0.5, 0.5)
	shadow.Size = UDim2.new(1, 30, 1, 30)
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
	shadow.ImageColor3 = Color3.new(0, 0, 0)
	shadow.ImageTransparency = 0.8
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(10, 10, 10, 10)
	shadow.ZIndex = 0
	shadow.Parent = card

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 16)
	shadowCorner.Parent = shadow

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 20)
	padding.PaddingRight = UDim.new(0, 20)
	padding.Parent = card

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -70, 0, titleSize + 4)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = titleSize
	title.TextColor3 = Color3.fromRGB(255, 105, 180)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Top
	title.TextTransparency = 0
	title.Text = "Loading..."
	title.Parent = card

	-- Body
	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Position = UDim2.new(0, 0, 0, titleSize + 8)
	body.Size = UDim2.new(1, -70, 1, -(titleSize + 20))
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextSize = bodySize
	body.TextColor3 = Color3.fromRGB(120, 100, 130)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.TextTransparency = 0
	body.Text = "Preparing tutorial..."
	body.Parent = card

	-- Skip button
	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipButton"
	skipBtn.AnchorPoint = Vector2.new(1, 0)
	skipBtn.Position = UDim2.new(1, -10, 0, 10)
	skipBtn.Size = UDim2.fromOffset(60, 28)
	skipBtn.BackgroundColor3 = Color3.fromRGB(230, 220, 255)
	skipBtn.Text = "Skip"
	skipBtn.Font = Enum.Font.GothamBold
	skipBtn.TextSize = 13
	skipBtn.TextColor3 = Color3.fromRGB(150, 120, 160)
	skipBtn.BorderSizePixel = 0
	skipBtn.AutoButtonColor = false
	skipBtn.Parent = card

	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 8)
	skipCorner.Parent = skipBtn

	-- Skip button hover
	skipBtn.MouseEnter:Connect(function()
		TweenService:Create(skipBtn, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(220, 210, 245),
			TextColor3 = Color3.fromRGB(130, 100, 140)
		}):Play()
	end)

	skipBtn.MouseLeave:Connect(function()
		TweenService:Create(skipBtn, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(230, 220, 255),
			TextColor3 = Color3.fromRGB(150, 120, 160)
		}):Play()
	end)

	TutorialState.tutorialGui = gui
	TutorialState.skipButton = skipBtn

	-- Store original size for pulse animation
	card:SetAttribute("OriginalWidth", cardW)
	card:SetAttribute("OriginalHeight", cardH)
	card:SetAttribute("OriginalYOffset", phone and 60 or 80)

	-- Initial animation
	task.spawn(function()
		task.wait(0.1)
		
		-- Fade in overlay
		TweenService:Create(overlay, TweenInfo.new(0.3), {
			BackgroundTransparency = 0.95
		}):Play()
		
		-- Slide in card
		task.wait(0.2)
		TweenService:Create(card, 
			TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0, phone and 60 or 80)
		}):Play()
	end)

	return gui
end

local function createHighlight(target)
	if TutorialState.highlightPart then
		TutorialState.highlightPart:Destroy()
		TutorialState.highlightPart = nil
	end
	
	if not target or not target:IsA("BasePart") then return end

	-- Use Highlight instance for better visibility
	local highlight = Instance.new("Highlight")
	highlight.Name = "TutorialHighlight"
	highlight.Adornee = target
	highlight.FillColor = Config.Colors.TUTORIAL_HIGHLIGHT
	highlight.OutlineColor = Config.Colors.TUTORIAL_HIGHLIGHT
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = target.Parent or workspace

	-- Pulse animation
	local pulseConnection
	pulseConnection = RunService.Heartbeat:Connect(function()
		if not highlight or not highlight.Parent then
			pulseConnection:Disconnect()
			return
		end
		local time = tick()
		local pulse = math.sin(time * 3) * 0.2 + 0.3
		highlight.FillTransparency = 0.5 + pulse
		highlight.OutlineTransparency = pulse * 0.5
	end)
	
	table.insert(TutorialState.connections, pulseConnection)
	TutorialState.highlightPart = highlight
end

-- ⚠️ MOVED BEFORE OTHER FUNCTIONS TO FIX NIL ERROR
local function skipTutorial()
	if TutorialState.completed then return end
	
	TutorialState.completed = true
	TutorialState.enabled = false

	print("✅ [Tutorial] Skipping/Completing...")

	-- Disconnect all connections
	for _, connection in pairs(TutorialState.connections) do
		if connection then 
			pcall(function() connection:Disconnect() end)
		end
	end
	TutorialState.connections = {}

	-- Clean up highlight
	if TutorialState.highlightPart then 
		TutorialState.highlightPart:Destroy() 
		TutorialState.highlightPart = nil
	end

	-- Animate out GUI
	if TutorialState.tutorialGui then
		local gui = TutorialState.tutorialGui
		local card = gui:FindFirstChild("Card")
		local overlay = gui:FindFirstChild("Overlay")
		
		if card then
			local skipBtn = card:FindFirstChild("SkipButton")
			if skipBtn then skipBtn.Active = false end
			
			-- Fade out
			local fadeInfo = TweenInfo.new(Config.FADE_OUT_TIME, Enum.EasingStyle.Quad)
			
			TweenService:Create(card, fadeInfo, {
				Position = UDim2.new(0.5, 0, 0, -200),
				BackgroundTransparency = 1
			}):Play()
			
			local stroke = card:FindFirstChild("UIStroke")
			if stroke then
				TweenService:Create(stroke, fadeInfo, {Transparency = 1}):Play()
			end
			
			local shadow = card:FindFirstChild("Shadow")
			if shadow then
				TweenService:Create(shadow, fadeInfo, {ImageTransparency = 1}):Play()
			end
			
			for _, child in pairs(card:GetChildren()) do
				if child:IsA("TextLabel") or child:IsA("TextButton") then
					TweenService:Create(child, fadeInfo, {
						TextTransparency = 1,
						BackgroundTransparency = 1
					}):Play()
				end
			end
			
			if overlay then
				TweenService:Create(overlay, fadeInfo, {BackgroundTransparency = 1}):Play()
			end
			
			task.wait(Config.FADE_OUT_TIME + 0.1)
		end
		
		gui:Destroy()
		TutorialState.tutorialGui = nil
	end

	print("✅ [Tutorial] Completed!")
end

local function updateTutorialText(newTitle, newBody)
	if not TutorialState.tutorialGui or TutorialState.isTransitioning then return end
	
	TutorialState.isTransitioning = true
	
	local card = TutorialState.tutorialGui.Card
	local titleLabel = card.Title
	local bodyLabel = card.Body
	
	-- Fade out (faster)
	local fadeOutInfo = TweenInfo.new(Config.TEXT_TRANSITION_TIME * 0.4, Enum.EasingStyle.Quad)
	local fadeOut1 = TweenService:Create(titleLabel, fadeOutInfo, {TextTransparency = 1})
	local fadeOut2 = TweenService:Create(bodyLabel, fadeOutInfo, {TextTransparency = 1})
	
	fadeOut1:Play()
	fadeOut2:Play()
	
	task.wait(Config.TEXT_TRANSITION_TIME * 0.4)
	
	-- Update text
	titleLabel.Text = newTitle
	bodyLabel.Text = newBody
	
	-- Fade in (faster)
	local fadeInInfo = TweenInfo.new(Config.TEXT_TRANSITION_TIME * 0.6, Enum.EasingStyle.Quad)
	local fadeIn1 = TweenService:Create(titleLabel, fadeInInfo, {TextTransparency = 0})
	local fadeIn2 = TweenService:Create(bodyLabel, fadeInInfo, {TextTransparency = 0})
	
	fadeIn1:Play()
	fadeIn2:Play()
	
	task.wait(Config.TEXT_TRANSITION_TIME * 0.6)
	TutorialState.isTransitioning = false
end

-- Forward declarations for functions used before definition
local findTycoonGates

local function updateTutorialStep()
	if not TutorialState.enabled or TutorialState.completed then return end

	local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
	if not step then
		TutorialState.completed = true
		skipTutorial()
		return
	end

	print("🎓 [Tutorial] Step " .. TutorialState.currentStep .. ":", step.name)

	-- Update text
	if TutorialState.tutorialGui then
		updateTutorialText(step.title, step.description)
	end

	-- Clear old highlight
	if TutorialState.highlightPart then 
		TutorialState.highlightPart:Destroy() 
		TutorialState.highlightPart = nil
	end

	-- Auto-close timer
	if step.autoClose then
		task.delay(step.autoClose, function()
			if TutorialState.enabled and not TutorialState.completed then
				skipTutorial()
			end
		end)
	end

	-- Wait before highlighting (shorter wait)
	task.wait(Config.TUTORIAL_STEP_DELAY * 0.5)
	
	-- Find target to highlight
	local targetPart = nil
	
	if step.targetButton and PathState.playerTycoon then
		-- Look in player's tycoon buttons
		local buttons = PathState.playerTycoon:FindFirstChild("Buttons")
		if buttons then
			local buttonModel = buttons:FindFirstChild(step.targetButton)
			if buttonModel then
				targetPart = buttonModel:FindFirstChild("Head")
				if targetPart and targetPart.Transparency < 0.9 and targetPart.CanCollide then
					print("✨ [Tutorial] Highlighting button:", step.targetButton)
				else
					targetPart = nil
				end
			end
		end
	elseif step.target == "collector" and PathState.playerTycoon then
		-- Find collector in player's tycoon
		local essentials = PathState.playerTycoon:FindFirstChild("Essentials")
		if essentials then
			targetPart = essentials:FindFirstChild("Giver") or essentials:FindFirstChild("Collector")
			if targetPart then
				print("✨ [Tutorial] Highlighting collector")
			end
		end
	elseif step.target == "gate" then
		-- Find nearest unclaimed gate
		local gates = findTycoonGates()
		for _, gateData in ipairs(gates) do
			if not gateData.owner.Value then
				targetPart = gateData.part
				if targetPart then
					print("✨ [Tutorial] Highlighting gate")
					break
				end
			end
		end
	end

	if targetPart then 
		createHighlight(targetPart) 
	end
end

-- ✨ IMPROVED: Simultaneous pulse + text transition
local function nextTutorialStep()
	if not TutorialState.enabled or TutorialState.completed or TutorialState.isTransitioning then return end
	
	local oldStep = TutorialState.currentStep
	TutorialState.currentStep = TutorialState.currentStep + 1
	print("➡️ [Tutorial] Step " .. oldStep .. " → " .. TutorialState.currentStep)

	-- Get next step info immediately
	local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
	if not step then
		skipTutorial()
		return
	end

	-- 🎯 SIMULTANEOUS ANIMATIONS - Pulse card AND change text at the same time!
	if TutorialState.tutorialGui then
		local card = TutorialState.tutorialGui.Card
		local originalW = card:GetAttribute("OriginalWidth") or 450
		local originalH = card:GetAttribute("OriginalHeight") or 125
		local originalY = card:GetAttribute("OriginalYOffset") or 80
		
		local pulseTime = 0.2
		local pulseInfo = TweenInfo.new(pulseTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		
		-- Start pulse animation
		local pulseTween = TweenService:Create(card, pulseInfo, {
			Size = UDim2.fromOffset(originalW + 15, originalH + 8),
		})
		pulseTween:Play()
		
		-- Start text transition immediately (no waiting!)
		task.spawn(function()
			updateTutorialText(step.title, step.description)
		end)
		
		-- Pulse back to normal
		pulseTween.Completed:Connect(function()
			TweenService:Create(card, pulseInfo, {
				Size = UDim2.fromOffset(originalW, originalH),
			}):Play()
		end)
	end

	-- Short delay before highlighting
	task.wait(Config.TUTORIAL_STEP_DELAY)
	
	-- Clear old highlight
	if TutorialState.highlightPart then 
		TutorialState.highlightPart:Destroy() 
		TutorialState.highlightPart = nil
	end
	
	-- Find and highlight new target
	local targetPart = nil
	
	if step.targetButton and PathState.playerTycoon then
		local buttons = PathState.playerTycoon:FindFirstChild("Buttons")
		if buttons then
			local buttonModel = buttons:FindFirstChild(step.targetButton)
			if buttonModel then
				targetPart = buttonModel:FindFirstChild("Head")
				if not (targetPart and targetPart.Transparency < 0.9 and targetPart.CanCollide) then
					targetPart = nil
				end
			end
		end
	elseif step.target == "collector" and PathState.playerTycoon then
		local essentials = PathState.playerTycoon:FindFirstChild("Essentials")
		if essentials then
			targetPart = essentials:FindFirstChild("Giver") or essentials:FindFirstChild("Collector")
		end
	elseif step.target == "gate" then
		local gates = findTycoonGates()
		for _, gateData in ipairs(gates) do
			if not gateData.owner.Value then
				targetPart = gateData.part
				break
			end
		end
	end

	if targetPart then 
		createHighlight(targetPart) 
	end
end

--============================================================================--
--                            UTILITY FUNCTIONS
--============================================================================--

local function quadraticBezier(t, p0, p1, p2)
	local u = 1 - t
	return u * u * p0 + 2 * u * t * p1 + t * t * p2
end

local function getGroundPosition(position, ignoreList, playerHeight)
	raycastParams.FilterDescendantsInstances = ignoreList

	if playerHeight then
		local rayOrigin = Vector3.new(position.X, playerHeight + 5, position.Z)
		local rayDirection = Vector3.new(0, -10, 0)
		local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

		if rayResult and math.abs(rayResult.Position.Y - playerHeight) < 10 then
			return rayResult.Position + Vector3.new(0, Config.GROUND_OFFSET, 0), rayResult.Normal
		end
	end

	local rayOrigin = position + Vector3.new(0, 20, 0)
	local rayDirection = Vector3.new(0, -100, 0)
	local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if rayResult then
		return rayResult.Position + Vector3.new(0, Config.GROUND_OFFSET, 0), rayResult.Normal
	end
	return position, Vector3.new(0, 1, 0)
end

--============================================================================--
--                            SEGMENT CREATION
--============================================================================--

local function createSegment(index)
	local segment = Instance.new("Part")
	segment.Name = "PathSegment" .. index
	segment.Size = Config.SEGMENT_SIZE
	segment.Material = Enum.Material.Neon
	segment.Color = Config.Colors.PATH
	segment.Anchored = true
	segment.CanCollide = false
	segment.CanQuery = false
	segment.CanTouch = false
	segment.CastShadow = false
	segment.Transparency = 1

	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 0
	pointLight.Color = Config.Colors.GLOW
	pointLight.Range = Config.LIGHT_BASE_RANGE
	pointLight.Parent = segment

	local selection = Instance.new("SelectionBox")
	selection.Adornee = segment
	selection.Color3 = Config.Colors.GLOW
	selection.LineThickness = 0.05
	selection.Transparency = 1
	selection.Parent = segment

	segment:SetAttribute("TargetTransparency", 1)
	segment:SetAttribute("FadeFactor", 0)
	segment:SetAttribute("SegmentIndex", index)

	PathState.segments[index] = {
		part = segment,
		light = pointLight,
		selection = selection,
		currentTransparency = 1,
		targetTransparency = 1,
	}

	return segment
end

--============================================================================--
--                          TYCOON GATE DETECTION
--============================================================================--

function findTycoonGates()
	local now = tick()
	if now - PathState.lastGateUpdate < Config.GATE_UPDATE_INTERVAL * 0.5 and #PathState.cachedGates > 0 then
		return PathState.cachedGates
	end
	PathState.lastGateUpdate = now
	PathState.cachedGates = {}

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") then
			local name = obj.Name:lower()
			if name == "touch to claim!" or name:find("gate") or name:find("claim") then
				local touchPart = obj:FindFirstChild("Head") or obj:FindFirstChild("TouchPart") or obj:FindFirstChildWhichIsA("BasePart")
				if touchPart then
					local parent = obj.Parent
					while parent and parent ~= workspace do
						local owner = parent:FindFirstChild("Owner")
						if owner and owner:IsA("ObjectValue") then
							table.insert(PathState.cachedGates, {
								owner = owner,
								position = touchPart.Position,
								part = touchPart,
								tycoon = parent
							})
							break
						end
						parent = parent.Parent
					end
				end
			end
		end
	end
	return PathState.cachedGates
end

local function findNearestUnclaimedGate()
	local character = player.Character
	if not character then return nil, false end
	local humanoidRoot = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRoot then return nil, false end

	local gates = findTycoonGates()
	local nearestGate, nearestDistance = nil, math.huge

	for _, gateData in ipairs(gates) do
		if gateData.owner.Value == player then
			PathState.playerTycoon = gateData.tycoon
			return nil, true
		elseif not gateData.owner.Value then
			local distance = (gateData.position - humanoidRoot.Position).Magnitude
			if distance < nearestDistance then
				nearestDistance, nearestGate = distance, gateData
			end
		end
	end
	return nearestGate, false
end

--============================================================================--
--                            PATH MANAGEMENT
--============================================================================--

-- ✨ IMPROVED: Instant fade-out when gate claimed
local function hidePath()
	if not PathState.active then return end
	PathState.active = false
	PathState.fadingOut = true

	-- Immediately set all segments to fade out
	for _, segmentData in ipairs(PathState.segments) do
		if segmentData and segmentData.part then
			segmentData.targetTransparency = 1
			segmentData.part:SetAttribute("TargetTransparency", 1)
		end
	end

	-- Clean up after short delay
	task.delay(Config.FADE_OUT_TIME * 2, function()
		if PathState.pathModel and PathState.fadingOut then
			PathState.pathModel:Destroy()
			PathState.pathModel = nil
			PathState.segments = {}
			PathState.fadingOut = false
		end
	end)
end

local function updatePath()
	local character = player.Character
	if not character or not character.PrimaryPart or not PathState.currentTargetGate then
		hidePath()
		return
	end

	local startPos = character.PrimaryPart.Position
	local endPos = PathState.currentTargetGate.position
	local direction = (endPos - startPos).Unit
	local distance = (endPos - startPos).Magnitude

	if distance > Config.PATH_END_OFFSET then
		endPos = endPos - (direction * Config.PATH_END_OFFSET)
		distance = distance - Config.PATH_END_OFFSET
	end

	if distance < Config.MIN_DISTANCE or distance > Config.MAX_DISTANCE then
		hidePath()
		return
	end

	if not PathState.smoothedStartPos then PathState.smoothedStartPos = startPos end
	if not PathState.smoothedEndPos then PathState.smoothedEndPos = endPos end

	PathState.smoothedStartPos = PathState.smoothedStartPos:Lerp(startPos, Config.TARGET_SMOOTHING)
	PathState.smoothedEndPos = PathState.smoothedEndPos:Lerp(endPos, Config.TARGET_SMOOTHING)

	local smoothStart = PathState.smoothedStartPos
	local smoothEnd = PathState.smoothedEndPos
	local smoothDistance = (smoothEnd - smoothStart).Magnitude

	if not PathState.pathModel or not PathState.pathModel.Parent then
		PathState.pathModel = Instance.new("Model")
		PathState.pathModel.Name = "LocalTycoonPath"
		PathState.pathModel.Parent = workspace
		PathState.segments = {}
		PathState.fadingOut = false
	end

	local midPoint = (smoothStart + smoothEnd) / 2
	local arcHeight = math.min(smoothDistance * Config.PATH_ARC_HEIGHT, 5)
	local controlPoint = midPoint + Vector3.new(0, arcHeight, 0)
	local segmentCount = math.min(math.floor(smoothDistance / Config.SEGMENT_SPACING), Config.MAX_SEGMENTS)
	local ignoreList = {character, PathState.pathModel}
	local segmentPositions = {}

	for i = 1, segmentCount do
		local segment = (PathState.segments[i] and PathState.segments[i].part) or createSegment(i)
		segment.Parent = PathState.pathModel

		local t = i / (segmentCount + 1)
		local pathPos = quadraticBezier(t, smoothStart, controlPoint, smoothEnd)
		local groundPos, groundNormal = getGroundPosition(pathPos, ignoreList, character.PrimaryPart.Position.Y)
		segmentPositions[i] = groundPos

		local nextPathPos = quadraticBezier(math.min(t + 0.01, 1), smoothStart, controlPoint, smoothEnd)
		local lookDirection = (nextPathPos - pathPos).Unit
		local rightVector = lookDirection:Cross(groundNormal).Unit
		local upVector = rightVector:Cross(lookDirection).Unit
		segment.CFrame = segment.CFrame:Lerp(CFrame.fromMatrix(groundPos, rightVector, upVector, -lookDirection), Config.POSITION_SMOOTHING)

		local scale = 1 - (t * Config.SCALE_REDUCTION)
		segment.Size = Config.SEGMENT_SIZE * scale

		local fadeFactor = 0
		if i > 1 and segmentPositions[i-1] then
			local spacing = (segmentPositions[i] - segmentPositions[i-1]).Magnitude
			local minSpacing = Config.SEGMENT_SPACING * Config.BUNCHING_THRESHOLD
			fadeFactor = spacing < minSpacing and math.clamp(1 - (spacing / minSpacing), 0, Config.MAX_BUNCH_FADE) or 0
		end

		segment:SetAttribute("FadeFactor", fadeFactor)
		segment:SetAttribute("TargetTransparency", 0)
		segment:SetAttribute("Scale", scale)
		PathState.segments[i].targetTransparency = fadeFactor > 0.7 and 1 or 0
	end

	for i = segmentCount + 1, Config.MAX_SEGMENTS do
		if PathState.segments[i] and PathState.segments[i].part then
			PathState.segments[i].targetTransparency = 1
			PathState.segments[i].part:SetAttribute("TargetTransparency", 1)
		end
	end
end

--============================================================================--
--                          ANIMATION SYSTEM
--============================================================================--

local function animateSegments(deltaTime)
	if not PathState.pathModel or not PathState.pathModel.Parent then return end
	PathState.animationTime = PathState.animationTime + deltaTime

	for index, segmentData in ipairs(PathState.segments) do
		local segment = segmentData.part
		if segment and segment.Parent then
			local targetTrans = segment:GetAttribute("TargetTransparency") or 1
			local fadeFactor = segment:GetAttribute("FadeFactor") or 0
			local finalTargetTrans = math.max(targetTrans, fadeFactor * 0.8)
			
			-- Faster transparency smoothing
			local smoothingSpeed = PathState.fadingOut and 0.4 or Config.TRANSPARENCY_SMOOTHING
			segmentData.currentTransparency = segmentData.currentTransparency + 
				(finalTargetTrans - segmentData.currentTransparency) * smoothingSpeed
			segment.Transparency = segmentData.currentTransparency

			if segmentData.currentTransparency < 0.9 then
				local pulse = math.sin(PathState.animationTime * Config.PULSE_SPEED + index * 0.2) * 0.5 + 0.5
				local scale = segment:GetAttribute("Scale") or 1
				segmentData.light.Brightness = (Config.LIGHT_BASE_BRIGHTNESS + (pulse * Config.LIGHT_PULSE_BRIGHTNESS)) * (1 - segmentData.currentTransparency)
				segmentData.light.Range = Config.LIGHT_BASE_RANGE * scale
				segmentData.selection.Transparency = Config.GLOW_BASE_TRANSPARENCY + (pulse * Config.GLOW_PULSE_AMOUNT) + (segmentData.currentTransparency * 0.5)

				local flow = (PathState.animationTime * Config.FLOW_SPEED + index) % 10
				segment.Color = flow < 1 and Config.Colors.GLOW:Lerp(Config.Colors.PULSE, flow) or Config.Colors.PATH
			else
				segmentData.light.Brightness = 0
				segmentData.selection.Transparency = 1
			end
		end
	end
end

--============================================================================--
--                     🎓 TUTORIAL EVENT LISTENERS
--============================================================================--

local function setupTutorialListeners()
	if not TutorialState.enabled then return end

	-- Cash monitoring (works with auto-collect!)
	local function setupCashMonitoring()
		local leaderstats = player:WaitForChild("leaderstats", 10)
		if not leaderstats then return end

		local cash = leaderstats:WaitForChild("Cash", 10)
		if not cash then return end

		-- Store initial cash
		TutorialState.initialCash = cash.Value

		local cashConnection = cash.Changed:Connect(function(newValue)
			if not TutorialState.enabled or TutorialState.completed then return end

			local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
			if not step then return end

			-- For collect_money step, any cash increase works
			if step.waitForCash and newValue > TutorialState.initialCash then
				print("💰 [Tutorial] Cash collected! Advancing...")
				task.wait(0.5)
				nextTutorialStep()
			end
		end)
		
		table.insert(TutorialState.connections, cashConnection)
		print("✅ [Tutorial] Monitoring leaderstats.Cash (Auto-Collect compatible!)")
	end

	-- Purchase detection
	local function setupPurchaseDetection()
		local purchaseConnection = workspace.DescendantAdded:Connect(function(descendant)
			if not TutorialState.enabled or TutorialState.completed then return end
			
			local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
			if not step or not step.waitForPurchase then return end

			-- Check if it's in PurchasedObjects
			if descendant.Parent and descendant.Parent.Name == "PurchasedObjects" then
				local purchasedObjects = descendant.Parent
				local tycoon = purchasedObjects.Parent
				
				-- Verify it's the player's tycoon
				if tycoon and tycoon:FindFirstChild("Owner") and tycoon.Owner.Value == player then
					print("🔍 [Tutorial] Purchase detected:", descendant.Name)
					
					if descendant.Name == step.waitForPurchase then
						print("✅ [Tutorial]", step.waitForPurchase, "purchased!")
						task.wait(1)
						nextTutorialStep()
					end
				end
			end
		end)
		
		table.insert(TutorialState.connections, purchaseConnection)
	end

	-- Skip button
	if TutorialState.skipButton then
		local skipConnection = TutorialState.skipButton.Activated:Connect(function()
			skipTutorial()
		end)
		table.insert(TutorialState.connections, skipConnection)
	end

	-- Tap to dismiss on final step
	local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if not TutorialState.enabled or TutorialState.completed then return end
		
		local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
		if step and step.name == "tutorial_complete" then
			if input.UserInputType == Enum.UserInputType.Touch or 
			   input.UserInputType == Enum.UserInputType.MouseButton1 then
				skipTutorial()
			end
		end
	end)
	table.insert(TutorialState.connections, inputConnection)

	-- Set up monitoring
	setupCashMonitoring()
	setupPurchaseDetection()
end

--============================================================================--
--                            MAIN LOOPS
--============================================================================--

-- Fast path updates
RunService.RenderStepped:Connect(function(deltaTime)
	updatePath()
	animateSegments(deltaTime)
end)

-- Gate scanning loop
task.spawn(function()
	print("🚪 [Tutorial] Gate scanning started!")
	
	while true do
		local targetGate, ownsTycoon = findNearestUnclaimedGate()

		if ownsTycoon or not targetGate then
			if ownsTycoon and not PathState.ownedTycoon then
				print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
				print("🏠 [Tutorial] ✨ TYCOON CLAIMED! ✨")
				print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
				PathState.ownedTycoon = true

				-- Immediately hide path
				hidePath()

				if TutorialState.enabled and not TutorialState.completed then
					local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
					if step and step.waitForGateClaim then
						print("✅ [Tutorial] Gate claimed! Advancing...")
						task.wait(0.8) -- Slightly longer wait for smooth transition
						nextTutorialStep()
					end
				end
			end
			PathState.currentTargetGate = nil
			if not PathState.fadingOut then
				hidePath()
			end
		else
			if not PathState.active then
				PathState.smoothedStartPos, PathState.smoothedEndPos = nil, nil
				PathState.fadingOut = false
			end
			PathState.active = true
			PathState.currentTargetGate = targetGate
		end
		
		task.wait(Config.GATE_UPDATE_INTERVAL)
	end
end)

-- Character cleanup
player.CharacterRemoving:Connect(function()
	for _, connection in pairs(TutorialState.connections) do
		if connection then 
			pcall(function() connection:Disconnect() end)
		end
	end
	TutorialState.connections = {}

	if TutorialState.tutorialGui then
		TutorialState.tutorialGui:Destroy()
		TutorialState.tutorialGui = nil
	end

	if TutorialState.highlightPart then
		TutorialState.highlightPart:Destroy()
		TutorialState.highlightPart = nil
	end

	if PathState.pathModel then 
		PathState.pathModel:Destroy() 
	end
	
	PathState = {
		active = false,
		currentTargetGate = nil,
		smoothedStartPos = nil,
		smoothedEndPos = nil,
		pathModel = nil,
		segments = {},
		cachedGates = {},
		lastGateUpdate = 0,
		animationTime = 0,
		ownedTycoon = false,
		playerTycoon = nil,
		fadingOut = false,
	}
end)

-- Character respawn
player.CharacterAdded:Connect(function(character)
	print("👤 [Tutorial] Character added")
	
	-- Reset states for respawn
	TutorialState.currentStep = 1
	TutorialState.completed = false
	TutorialState.isTransitioning = false
	PathState.ownedTycoon = false
	PathState.playerTycoon = nil
	PathState.fadingOut = false
end)

-- Initialize
if Config.TUTORIAL_ENABLED then
	task.wait(2) -- Wait for game to load
	
	if player.Character then
		print("🎓 [Tutorial] Initializing...")
		createTutorialUI()
		setupTutorialListeners()
		updateTutorialStep()
		print("🎓 [Tutorial] Ready!")
	end
end

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ Tycoon Path Guide v6.1 - ULTRA POLISHED")
print("⚡ Instant path fade & smooth simultaneous transitions!")
print("💎 Works with your purchase handler & auto-collect!")
print("🎀 Buttery-smooth mobile-first design!")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
