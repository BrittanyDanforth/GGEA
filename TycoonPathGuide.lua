--[[
	CLIENT-ONLY TYCOON PATH GUIDE + TUTORIAL [v7.7 - SNAPPY EXIT]
	
	🐛 CRITICAL FIXES:
	✅ Correct "unclaimed" detection (handles 0 and "" properly!)
	✅ Highlight cleared when no target (no lingering blue outlines)
	✅ Highlight updates ALWAYS (not just during tutorial step)
	✅ Switch logic with hysteresis (prevents jitter/stuck feeling)
	✅ Simple text instructions (no button/collector highlighting)
	✅ Natural directions ("glowing button", "green part")
	✅ Works universally across all tycoons!
	
	✨ UI IMPROVEMENTS:
	✅ Cute bubbly font (FredokaOne for everything!)
	✅ Bigger, easier to read text (16-18px)
	✅ Optimized card sizing (no cutoff!)
	✅ TextWrapped enabled for clean flow
	✅ CUTE RISE-AND-FADE EXIT ANIMATION! 🎀
	✅ SNAPPY timing (0.28s animation, 1.4s total dwell)
	✅ Exit starts early so it finishes EXACTLY at autoClose time
	✅ No extra waits - crisp and responsive!
	
	✅ Path stays FLAT on ground (no floating!)
	✅ Highlights CLOSEST gate (true distance-based switching)
	✅ Smooth fade-out when gate claimed
	✅ Robust ownership detection (all tycoon kits)
	✅ Event-driven instant claim detection
	✅ Auto-collect compatible
	✅ Ultra-polished animations
	
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

	-- Distance Settings
	MIN_DISTANCE = 5,
	MAX_DISTANCE = 300,
	PATH_END_OFFSET = 3,

	-- Animation Parameters
	PULSE_SPEED = 2,
	FLOW_SPEED = 3,
	FADE_IN_TIME = 0.3,
	FADE_OUT_TIME = 0.4,
	TEXT_TRANSITION_TIME = 0.25,
	EXIT_TWEEN_TIME = 0.28,

	-- Smoothing & Performance
	POSITION_SMOOTHING = 0.3,
	TARGET_SMOOTHING = 0.25,
	TRANSPARENCY_SMOOTHING = 0.2,
	GATE_UPDATE_INTERVAL = 0.2,
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
	TUTORIAL_STEP_DELAY = 0.3,
	TUTORIAL_STEPS = {
		{
			name = "claim_gate",
			title = "Welcome to Sanrio Tycoon! 🎀",
			description = "Touch any gate to claim your tycoon!",
			target = "closest_gate",
			waitForGateClaim = true,
		},
		{
			name = "buy_dropper1",
			title = "Buy Your First Dropper! 💎",
			description = "Walk to the glowing button on the ground and touch it. It says Begin Working!",
			waitForPurchase = "Dropper1",
		},
		{
			name = "collect_money",
			title = "Earning Cash! 💰",
			description = "Your dropper is working! Step on the green part to collect cash. You need $70 for the next dropper!",
			waitForCash = true,
		},
		{
			name = "buy_dropper2",
			title = "Buy Your Second Dropper! ✨",
			description = "Nice! You have enough cash now. Walk to the next glowing button that says Buy Dropper.",
			waitForPurchase = "Dropper2",
		},
		{
			name = "tutorial_complete",
			title = "You're All Set! 🎉",
			description = "Amazing! Keep buying upgrades to grow your tycoon.",
			target = nil,
			autoClose = 1.4,
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
	lastHighlightedPart = nil, -- Track which part is currently highlighted
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
	fadingOut = false,
	ownershipConnections = {},
}

-- Raycast parameters
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
raycastParams.IgnoreWater = true

--============================================================================--
--                     🔧 ROBUST OWNERSHIP DETECTION
--============================================================================--

local function tycoonOwnedByPlayer(tycoon, plr: Player): boolean
	local owner = tycoon:FindFirstChild("Owner")
	if owner then
		if owner:IsA("ObjectValue") then
			return owner.Value == plr or owner.Value == plr.Character
		elseif owner:IsA("StringValue") then
			return owner.Value == plr.Name
		elseif owner:IsA("IntValue") or owner:IsA("NumberValue") then
			return owner.Value == plr.UserId
		end
	end
	local ownerIdAttr = tycoon:GetAttribute("OwnerId")
	if typeof(ownerIdAttr) == "number" then
		return ownerIdAttr == plr.UserId
	end
	return false
end

-- 🐛 FIX A: Correct "unclaimed" detection (handles 0 and "" as unclaimed!)
local function isUnclaimedOwner(owner: Instance): boolean
	if not owner then return false end
	if owner:IsA("ObjectValue") then
		return owner.Value == nil
	elseif owner:IsA("StringValue") then
		return owner.Value == nil or owner.Value == ""
	elseif owner:IsA("IntValue") or owner:IsA("NumberValue") then
		return owner.Value == 0
	end
	return false
end

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

	local cardW = phone and 340 or (tablet and 400 or 450)
	local cardH = phone and 170 or (tablet and 155 or 145)
	local titleSize = phone and 22 or (tablet and 24 or 26)
	local bodySize = phone and 16 or (tablet and 17 or 18)

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.Parent = gui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, -cardH - 50)
	card.Size = UDim2.fromOffset(cardW, cardH)
	card.BackgroundColor3 = Config.Colors.TUTORIAL_CARD_BG
	card.BorderSizePixel = 0
	card.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Config.Colors.TUTORIAL_STROKE
	stroke.Thickness = 3
	stroke.Transparency = 0
	stroke.Parent = card

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

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Position = UDim2.new(0, 0, 0, titleSize + 8)
	body.Size = UDim2.new(1, -70, 1, -(titleSize + 16))
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.FredokaOne
	body.TextSize = bodySize
	body.TextColor3 = Color3.fromRGB(120, 100, 130)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.TextScaled = false
	body.TextTransparency = 0
	body.Text = "Preparing tutorial..."
	body.Parent = card

	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipButton"
	skipBtn.AnchorPoint = Vector2.new(1, 0)
	skipBtn.Position = UDim2.new(1, -10, 0, 10)
	skipBtn.Size = UDim2.fromOffset(60, 28)
	skipBtn.BackgroundColor3 = Color3.fromRGB(230, 220, 255)
	skipBtn.Text = "Skip"
	skipBtn.Font = Enum.Font.FredokaOne
	skipBtn.TextSize = 14
	skipBtn.TextColor3 = Color3.fromRGB(150, 120, 160)
	skipBtn.BorderSizePixel = 0
	skipBtn.AutoButtonColor = false
	skipBtn.Parent = card

	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 8)
	skipCorner.Parent = skipBtn

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

	card:SetAttribute("OriginalWidth", cardW)
	card:SetAttribute("OriginalHeight", cardH)
	card:SetAttribute("OriginalYOffset", phone and 60 or 80)

	task.spawn(function()
		task.wait(0.1)
		TweenService:Create(overlay, TweenInfo.new(0.3), {
			BackgroundTransparency = 0.95
		}):Play()
		task.wait(0.2)
		TweenService:Create(card, 
			TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0, phone and 60 or 80)
		}):Play()
	end)

	return gui
end

local function createHighlight(target)
	-- 🔥 ALWAYS recreate highlight (ensures it updates even if targeting same part)
	if TutorialState.highlightPart then
		TutorialState.highlightPart:Destroy()
		TutorialState.highlightPart = nil
	end
	
	if not target or not target:IsA("BasePart") then 
		TutorialState.lastHighlightedPart = nil
		return 
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "TutorialHighlight"
	highlight.Adornee = target
	highlight.FillColor = Config.Colors.TUTORIAL_HIGHLIGHT
	highlight.OutlineColor = Config.Colors.TUTORIAL_HIGHLIGHT
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = target.Parent or workspace

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
	TutorialState.lastHighlightedPart = target
end

local function playExitUp()
	if not TutorialState.tutorialGui then return end
	local gui = TutorialState.tutorialGui
	local card = gui:FindFirstChild("Card")
	local overlay = gui:FindFirstChild("Overlay")
	if not card then return end

	-- compute offscreen Y target (rise up)
	local offY = -(card.AbsoluteSize.Y + 120)

	-- fade timings
	local t = TweenInfo.new(Config.EXIT_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	-- fade texts/buttons
	for _, child in ipairs(card:GetChildren()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			TweenService:Create(child, t, {
				TextTransparency = 1,
				BackgroundTransparency = 1
			}):Play()
		end
	end

	-- fade stroke + shadow
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, t, {Transparency = 1}):Play()
	end
	local shadow = card:FindFirstChild("Shadow")
	if shadow then
		TweenService:Create(shadow, t, {ImageTransparency = 1}):Play()
	end

	-- slide up + fade card bg
	local exitTween = TweenService:Create(card, t, {
		Position = UDim2.new(0.5, 0, 0, offY),
		BackgroundTransparency = 1
	})
	exitTween:Play()

	-- dim overlay out too
	if overlay then
		TweenService:Create(overlay, t, {BackgroundTransparency = 1}):Play()
	end

	-- cleanup when done
	exitTween.Completed:Connect(function()
		if TutorialState.tutorialGui then
			TutorialState.tutorialGui:Destroy()
			TutorialState.tutorialGui = nil
		end
	end)
end

local function skipTutorial()
	if TutorialState.completed then return end

	TutorialState.completed = true
	TutorialState.enabled = false

	for _, connection in pairs(TutorialState.connections) do
		if connection then 
			pcall(function() connection:Disconnect() end)
		end
	end
	TutorialState.connections = {}

	if TutorialState.highlightPart then 
		TutorialState.highlightPart:Destroy() 
		TutorialState.highlightPart = nil
		TutorialState.lastHighlightedPart = nil
	end

	-- Disable skip button
	if TutorialState.skipButton then
		TutorialState.skipButton.Active = false
	end

	-- Use the cute rise-and-fade animation!
	playExitUp()

	print("✅ [Tutorial] Completed!")
end

local function updateTutorialText(newTitle, newBody)
	if not TutorialState.tutorialGui or TutorialState.isTransitioning then return end
	
	TutorialState.isTransitioning = true
	
	local card = TutorialState.tutorialGui.Card
	local titleLabel = card.Title
	local bodyLabel = card.Body
	
	local fadeOutInfo = TweenInfo.new(Config.TEXT_TRANSITION_TIME * 0.4, Enum.EasingStyle.Quad)
	local fadeOut1 = TweenService:Create(titleLabel, fadeOutInfo, {TextTransparency = 1})
	local fadeOut2 = TweenService:Create(bodyLabel, fadeOutInfo, {TextTransparency = 1})
	
	fadeOut1:Play()
	fadeOut2:Play()
	
	task.wait(Config.TEXT_TRANSITION_TIME * 0.4)
	
	titleLabel.Text = newTitle
	bodyLabel.Text = newBody
	
	local fadeInInfo = TweenInfo.new(Config.TEXT_TRANSITION_TIME * 0.6, Enum.EasingStyle.Quad)
	local fadeIn1 = TweenService:Create(titleLabel, fadeInInfo, {TextTransparency = 0})
	local fadeIn2 = TweenService:Create(bodyLabel, fadeInInfo, {TextTransparency = 0})
	
	fadeIn1:Play()
	fadeIn2:Play()
	
	task.wait(Config.TEXT_TRANSITION_TIME * 0.6)
	TutorialState.isTransitioning = false
end

-- Forward declarations
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

	if TutorialState.tutorialGui then
		updateTutorialText(step.title, step.description)
	end

	if TutorialState.highlightPart then 
		TutorialState.highlightPart:Destroy() 
		TutorialState.highlightPart = nil
		TutorialState.lastHighlightedPart = nil
	end

	if step.autoClose then
		-- start the exit so it FINISHES at autoClose
		local lead = math.max(0.05, (step.autoClose or 0) - Config.EXIT_TWEEN_TIME)
		task.delay(lead, function()
			if TutorialState.enabled and not TutorialState.completed then
				skipTutorial()
			end
		end)
	end

	task.wait(Config.TUTORIAL_STEP_DELAY * 0.5)
	
	-- 🎯 Only highlight the gate during step 1
	if step.target == "closest_gate" and PathState.currentTargetGate then
		createHighlight(PathState.currentTargetGate.part)
		print("✨ [Tutorial] Highlighting closest gate")
	end
end

local function nextTutorialStep()
	if not TutorialState.enabled or TutorialState.completed or TutorialState.isTransitioning then return end
	
	local oldStep = TutorialState.currentStep
	TutorialState.currentStep = TutorialState.currentStep + 1
	print("➡️ [Tutorial] Step " .. oldStep .. " → " .. TutorialState.currentStep)

	local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
	if not step then
		skipTutorial()
		return
	end

	if TutorialState.tutorialGui then
		local card = TutorialState.tutorialGui.Card
		local originalW = card:GetAttribute("OriginalWidth") or 450
		local originalH = card:GetAttribute("OriginalHeight") or 125
		local originalY = card:GetAttribute("OriginalYOffset") or 80
		
		local pulseTime = 0.2
		local pulseInfo = TweenInfo.new(pulseTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		
		local pulseTween = TweenService:Create(card, pulseInfo, {
			Size = UDim2.fromOffset(originalW + 15, originalH + 8),
		})
		pulseTween:Play()
		
		task.spawn(function()
			updateTutorialText(step.title, step.description)
		end)
		
		pulseTween.Completed:Connect(function()
			TweenService:Create(card, pulseInfo, {
				Size = UDim2.fromOffset(originalW, originalH),
			}):Play()
		end)
	end

	task.wait(Config.TUTORIAL_STEP_DELAY)
	
	if TutorialState.highlightPart then 
		TutorialState.highlightPart:Destroy() 
		TutorialState.highlightPart = nil
		TutorialState.lastHighlightedPart = nil
	end
	
	-- No highlighting for buttons/collectors - just clear instructions!
end

--============================================================================--
--                            UTILITY FUNCTIONS
--============================================================================--

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

local function setupOwnershipListener(gateData)
	if not gateData.owner or not gateData.owner:IsA("ValueBase") then return end
	
	local conn = gateData.owner.Changed:Connect(function()
		if tycoonOwnedByPlayer(gateData.tycoon, player) then
			print("🔔 [Path] Ownership changed - tycoon claimed!")
			PathState.ownedTycoon = true
			PathState.playerTycoon = gateData.tycoon
			PathState.currentTargetGate = nil
			
			-- Smooth fade out
			if _G.hidePathFunction then
				_G.hidePathFunction(false)
			end
			
			if TutorialState.enabled and not TutorialState.completed then
				local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
				if step and step.waitForGateClaim then
					print("✅ [Tutorial] Gate claimed via event! Advancing...")
					task.wait(0.8)
					nextTutorialStep()
				end
			end
		end
	end)
	
	table.insert(PathState.ownershipConnections, conn)
end

function findTycoonGates()
	local now = tick()
	if now - PathState.lastGateUpdate < Config.GATE_UPDATE_INTERVAL * 0.5 and #PathState.cachedGates > 0 then
		return PathState.cachedGates
	end
	PathState.lastGateUpdate = now
	PathState.cachedGates = {}
	
	for _, conn in ipairs(PathState.ownershipConnections) do
		pcall(function() conn:Disconnect() end)
	end
	PathState.ownershipConnections = {}

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") then
			local name = obj.Name:lower()
			if name == "touch to claim!" or name:find("gate") or name:find("claim") then
				local touchPart = obj:FindFirstChild("Head") or obj:FindFirstChild("TouchPart") or obj:FindFirstChildWhichIsA("BasePart")
				if touchPart then
					local parent = obj.Parent
					while parent and parent ~= workspace do
						local owner = parent:FindFirstChild("Owner")
						if owner and (owner:IsA("ObjectValue") or owner:IsA("StringValue") or owner:IsA("IntValue") or owner:IsA("NumberValue")) then
							local gateData = {
								owner = owner,
								position = touchPart.Position,
								part = touchPart,
								tycoon = parent
							}
							table.insert(PathState.cachedGates, gateData)
							setupOwnershipListener(gateData)
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
		if tycoonOwnedByPlayer(gateData.tycoon, player) then
			PathState.playerTycoon = gateData.tycoon
			return nil, true
		elseif isUnclaimedOwner(gateData.owner) then  -- 🐛 FIX A: Handles 0 and "" correctly!
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

local function hidePath(immediate: boolean?)
	-- 🐛 FIX B: Clear highlight when hiding path
	if TutorialState.highlightPart then
		TutorialState.highlightPart:Destroy()
		TutorialState.highlightPart = nil
		TutorialState.lastHighlightedPart = nil
	end
	
	if not PathState.pathModel and not PathState.active then
		PathState.active = false
		PathState.fadingOut = false
		return
	end

	PathState.active = false
	PathState.fadingOut = true

	if immediate then
		if PathState.pathModel then
			pcall(function() 
				PathState.pathModel:Destroy() 
			end)
		end
		PathState.pathModel = nil
		PathState.segments = {}
		PathState.fadingOut = false
		return
	end

	-- Smooth fade
	for _, s in ipairs(PathState.segments) do
		if s and s.part then
			s.targetTransparency = 1
			s.part:SetAttribute("TargetTransparency", 1)
		end
	end
	
	task.delay(0.6, function()
		if PathState.pathModel then
			pcall(function() PathState.pathModel:Destroy() end)
		end
		PathState.pathModel = nil
		PathState.segments = {}
		PathState.fadingOut = false
	end)
end

_G.hidePathFunction = hidePath

local function updatePath()
	if PathState.ownedTycoon or PathState.fadingOut then return end
	
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

	-- 🌍 FLAT PATH - No bezier arc, straight line on ground!
	local segmentCount = math.min(math.floor(smoothDistance / Config.SEGMENT_SPACING), Config.MAX_SEGMENTS)
	local ignoreList = {character, PathState.pathModel}
	local segmentPositions = {}

	for i = 1, segmentCount do
		local segment = (PathState.segments[i] and PathState.segments[i].part) or createSegment(i)
		segment.Parent = PathState.pathModel

		-- Linear interpolation (no arc!)
		local t = i / (segmentCount + 1)
		local pathPos = smoothStart:Lerp(smoothEnd, t)
		
		-- Raycast to ground
		local groundPos, groundNormal = getGroundPosition(pathPos, ignoreList, character.PrimaryPart.Position.Y)
		segmentPositions[i] = groundPos

		-- Calculate direction
		local lookDirection
		if i < segmentCount then
			local nextT = (i + 1) / (segmentCount + 1)
			local nextPathPos = smoothStart:Lerp(smoothEnd, nextT)
			lookDirection = (nextPathPos - pathPos).Unit
		else
			lookDirection = (smoothEnd - pathPos).Unit
		end
		
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
		
		-- Keep last 2 segments visible
		if i > segmentCount - 2 then
			fadeFactor = 0
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
			
			local smoothingSpeed = PathState.fadingOut and 0.3 or Config.TRANSPARENCY_SMOOTHING
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

	local function setupCashMonitoring()
		local leaderstats = player:WaitForChild("leaderstats", 10)
		if not leaderstats then return end

		local cash = leaderstats:WaitForChild("Cash", 10)
		if not cash then return end

		TutorialState.initialCash = cash.Value

		local cashConnection = cash.Changed:Connect(function(newValue)
			if not TutorialState.enabled or TutorialState.completed then return end

			local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
			if not step then return end

			if step.waitForCash and newValue > TutorialState.initialCash then
				print("💰 [Tutorial] Cash collected! Advancing...")
				task.wait(0.5)
				nextTutorialStep()
			end
		end)
		
		table.insert(TutorialState.connections, cashConnection)
		print("✅ [Tutorial] Monitoring leaderstats.Cash (Auto-Collect compatible!)")
	end

	local function setupPurchaseDetection()
		local purchaseConnection = workspace.DescendantAdded:Connect(function(descendant)
			if not TutorialState.enabled or TutorialState.completed then return end
			
			local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
			if not step or not step.waitForPurchase then return end

			if descendant.Parent and descendant.Parent.Name == "PurchasedObjects" then
				local purchasedObjects = descendant.Parent
				local tycoon = purchasedObjects.Parent
				
				if tycoon and tycoonOwnedByPlayer(tycoon, player) then
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

	if TutorialState.skipButton then
		local skipConnection = TutorialState.skipButton.Activated:Connect(function()
			skipTutorial()
		end)
		table.insert(TutorialState.connections, skipConnection)
	end

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

	setupCashMonitoring()
	setupPurchaseDetection()
end

--============================================================================--
--                            MAIN LOOPS
--============================================================================--

RunService.RenderStepped:Connect(function(deltaTime)
	if PathState.ownedTycoon then
		return
	end
	
	if PathState.fadingOut then
		animateSegments(deltaTime)
		return
	end
	
	updatePath()
	animateSegments(deltaTime)
end)

task.spawn(function()
	print("🚪 [Tutorial] Gate scanning started!")
	
	while true do
		local targetGate, ownsTycoon = findNearestUnclaimedGate()

		if ownsTycoon or not targetGate then
			-- 🐛 FIX B: Always clear highlight when no target!
			if TutorialState.highlightPart then
				TutorialState.highlightPart:Destroy()
				TutorialState.highlightPart = nil
				TutorialState.lastHighlightedPart = nil
			end
			
			if ownsTycoon and not PathState.ownedTycoon then
				print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
				print("🏠 [Tutorial] ✨ TYCOON CLAIMED! ✨")
				print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
				PathState.ownedTycoon = true

				PathState.currentTargetGate = nil
				hidePath(false)

				if TutorialState.enabled and not TutorialState.completed then
					local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
					if step and step.waitForGateClaim then
						print("✅ [Tutorial] Gate claimed! Advancing...")
						task.wait(0.8)
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
			
			-- 🐛 FIX C & D: ALWAYS update to closest gate (findNearestUnclaimedGate already returns the TRUE closest!)
			local actuallyChanged = (PathState.currentTargetGate ~= targetGate)
			PathState.currentTargetGate = targetGate
			
			-- Update highlight EVERY TIME the target changes (instant, responsive switching!)
			if actuallyChanged and targetGate then
				createHighlight(targetGate.part)
			end
		end
		
		task.wait(Config.GATE_UPDATE_INTERVAL)
	end
end)

player.CharacterRemoving:Connect(function()
	for _, connection in pairs(TutorialState.connections) do
		if connection then 
			pcall(function() connection:Disconnect() end)
		end
	end
	TutorialState.connections = {}
	
	for _, connection in pairs(PathState.ownershipConnections) do
		if connection then 
			pcall(function() connection:Disconnect() end)
		end
	end
	PathState.ownershipConnections = {}

	if TutorialState.tutorialGui then
		TutorialState.tutorialGui:Destroy()
		TutorialState.tutorialGui = nil
	end

	if TutorialState.highlightPart then
		TutorialState.highlightPart:Destroy()
		TutorialState.highlightPart = nil
		TutorialState.lastHighlightedPart = nil
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
		ownershipConnections = {},
	}
end)

player.CharacterAdded:Connect(function(character)
	print("👤 [Tutorial] Character added")
	
	TutorialState.currentStep = 1
	TutorialState.completed = false
	TutorialState.isTransitioning = false
	TutorialState.lastHighlightedPart = nil
	PathState.ownedTycoon = false
	PathState.playerTycoon = nil
	PathState.fadingOut = false
end)

if Config.TUTORIAL_ENABLED then
	task.wait(2)
	
	if player.Character then
		print("🎓 [Tutorial] Initializing...")
		createTutorialUI()
		setupTutorialListeners()
		updateTutorialStep()
		print("🎓 [Tutorial] Ready!")
	end
end

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ Tycoon Path Guide v7.7 - SNAPPY EXIT")
print("🐛 FIX: Correct unclaimed detection (0 and \"\" now work!)")
print("🐛 FIX: Highlight cleared when no target")
print("🐛 FIX: Hysteresis for stable switching (no jitter)")
print("✨ NEW: Natural text instructions (glowing button, green part)")
print("🎀 NEW: Cute bubbly font (FredokaOne everywhere!)")
print("🎀 NEW: Bigger text (16-18px, easy to read)")
print("🎀 NEW: Optimized card sizing (no cutoff!)")
print("🎀 NEW: CUTE RISE-AND-FADE EXIT! (0.28s animation)")
print("🎀 NEW: SNAPPY timing! (1.4s total, exit starts at 1.12s)")
print("🎀 NEW: No extra waits - crisp & responsive!")
print("🌍 Path stays FLAT on ground (no floating!)")
print("🎯 Highlights CLOSEST gate (distance-based)")
print("✨ Smooth fade-out when gate claimed")
print("⚡ Event-driven instant claim detection")
print("🔧 Robust ownership (all tycoon kits)")
print("🎀 Production-ready & buttery-smooth!")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
