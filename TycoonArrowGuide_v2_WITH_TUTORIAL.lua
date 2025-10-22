--[[
	CLIENT-ONLY TYCOON PATH GUIDE + TUTORIAL [v4.1 - FIXED!]
	🎓 TUTORIAL: 4 steps using RemoteEvents (NO ServerStorage!)
	- ✅ Uses MoneyCollected RemoteEvent → works with manual + auto-collect
	- ✅ Shows instantly on load (no waits)
	- ✅ Advances reliably: Claim → Drop1 → Collect → Drop2 → Done
	- ⚡ Path updates every frame for instant response
	- 📱 Mobile-optimized: Touch-friendly, readable text
	- Place in StarterPlayer > StarterPlayerScripts as a LocalScript
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

--============================================================================--
--                              CONFIGURATION
--============================================================================--
local Config = {
	-- Visual Appearance
	Colors = {
		PATH = Color3.fromRGB(255, 179, 212),      -- Light Pink
		GLOW = Color3.fromRGB(255, 204, 229),      -- Lighter Pink Glow
		PULSE = Color3.fromRGB(255, 230, 240),     -- Ultra Light Pink for flow
		TUTORIAL_HIGHLIGHT = Color3.fromRGB(100, 200, 255), -- Blue highlight
		TUTORIAL_ARROW = Color3.fromRGB(255, 220, 100), -- Yellow arrow
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
	FADE_IN_TIME = 0.2,
	FADE_OUT_TIME = 0.2,

	-- Smoothing & Performance
	POSITION_SMOOTHING = 0.3,
	TARGET_SMOOTHING = 0.25,
	TRANSPARENCY_SMOOTHING = 0.15,
	GATE_UPDATE_INTERVAL = 0.25, -- Snappy gate detection!
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

	-- 🎓 TUTORIAL SETTINGS (4 CLEAN STEPS - NO SERVERSTORAGE!)
	TUTORIAL_ENABLED = true,
	TUTORIAL_STEPS = {
		{
			name = "claim_gate",
			title = "Claim a Tycoon",
			body = "Walk to a glowing gate and step on it to claim.",
			goal = "touch_gate"
		},
		{
			name = "buy_dropper1",
			title = "Buy Dropper 1",
			body = "Step on the green button labeled Dropper 1.",
			goal = "spawn_dropper1"
		},
		{
			name = "collect_money",
			title = "Collect Your Cash",
			body = "Go to the green collector to cash in your drops.\n(Auto-Collect also counts!)",
			goal = "first_collect"
		},
		{
			name = "buy_dropper2",
			title = "Buy Dropper 2",
			body = "Gather $70 (or more) and step on the Dropper 2 button.",
			goal = "spawn_dropper2"
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
	highlightPart = nil,
	tutorialGui = nil,
	skipButton = nil,
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
	lastPathUpdate = 0,
	animationTime = 0,
	ownedTycoon = false, -- track if player owns tycoon
}

-- Raycast parameters
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
raycastParams.IgnoreWater = true

--============================================================================--
--                     📱 MOBILE DETECTION (from shop!)
--============================================================================--
local function viewport()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1920, 1080)
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
	gui.DisplayOrder = 9999
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	-- Responsive sizing (BIGGER for phones!)
	local phone = isPhone()
	local tablet = isTablet()

	local cardW = phone and 350 or (tablet and 420 or 480)
	local cardH = phone and 180 or (tablet and 160 or 150)
	local titleSize = phone and 22 or (tablet and 24 or 26)
	local bodySize = phone and 15 or (tablet and 16 or 17)

	-- Card (starts above screen, will slide down!)
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, -cardH - 20) -- Start off-screen!
	card.Size = UDim2.fromOffset(cardW, cardH)
	card.BackgroundColor3 = Color3.fromRGB(255, 248, 252)
	card.BorderSizePixel = 0
	card.Parent = gui
	
	-- ✨ Slide down animation!
	task.spawn(function()
		task.wait(0.3)
		TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0, 80)
		}):Play()
	end)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 180, 210)
	stroke.Thickness = 3
	stroke.Parent = card
	
	-- ✨ Gentle pulse to grab attention
	task.spawn(function()
		while card.Parent do
			TweenService:Create(stroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Thickness = 4
			}):Play()
			task.wait(1.2)
			TweenService:Create(stroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Thickness = 3
			}):Play()
			task.wait(1.2)
		end
	end)

	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.fromScale(0.5, 0.5)
	shadow.Size = UDim2.fromScale(1.05, 1.05)
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
	shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	shadow.ImageTransparency = 0.8
	shadow.ZIndex = -1
	shadow.Parent = card

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 20)
	padding.PaddingRight = UDim.new(0, 20)
	padding.Parent = card

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -40, 0, titleSize + 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = titleSize
	title.TextColor3 = Color3.fromRGB(255, 105, 180)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Top
	title.Text = "Tutorial"
	title.Parent = card

	-- Step indicator (e.g., "1/3")
	local stepIndicator = Instance.new("TextLabel")
	stepIndicator.Name = "StepIndicator"
	stepIndicator.AnchorPoint = Vector2.new(0, 0)
	stepIndicator.Position = UDim2.new(0, 0, 0, 0)
	stepIndicator.Size = UDim2.fromOffset(50, 24)
	stepIndicator.BackgroundColor3 = Color3.fromRGB(255, 180, 210)
	stepIndicator.BorderSizePixel = 0
	stepIndicator.Font = Enum.Font.GothamBold
	stepIndicator.TextSize = 13
	stepIndicator.TextColor3 = Color3.new(1, 1, 1)
	stepIndicator.Text = "1/3"
	stepIndicator.Parent = card

	local stepCorner = Instance.new("UICorner")
	stepCorner.CornerRadius = UDim.new(0, 8)
	stepCorner.Parent = stepIndicator

	-- Body
	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Position = UDim2.new(0, 0, 0, titleSize + 10)
	body.Size = UDim2.new(1, -40, 1, -(titleSize + 26))
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextSize = bodySize
	body.TextColor3 = Color3.fromRGB(120, 100, 130)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.Text = "Welcome!"
	body.Parent = card

	-- Skip button
	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipButton"
	skipBtn.AnchorPoint = Vector2.new(1, 0)
	skipBtn.Position = UDim2.new(1, -12, 0, 12)
	skipBtn.Size = UDim2.fromOffset(60, 28)
	skipBtn.BackgroundColor3 = Color3.fromRGB(230, 220, 255)
	skipBtn.Text = "Skip"
	skipBtn.Font = Enum.Font.GothamBold
	skipBtn.TextSize = 13
	skipBtn.TextColor3 = Color3.fromRGB(150, 120, 160)
	skipBtn.BorderSizePixel = 0
	skipBtn.Parent = card

	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 8)
	skipCorner.Parent = skipBtn

	TutorialState.tutorialGui = gui
	TutorialState.skipButton = skipBtn

	return gui, title, body, skipBtn
end

local function createHighlight(target)
	if TutorialState.highlightPart then
		TutorialState.highlightPart:Destroy()
	end

	if not target or not target:IsA("BasePart") then return end

	-- Selection box highlight
	local highlight = Instance.new("SelectionBox")
	highlight.Name = "TutorialHighlight"
	highlight.Adornee = target
	highlight.Color3 = Config.Colors.TUTORIAL_HIGHLIGHT
	highlight.LineThickness = 0.08
	highlight.Transparency = 0.3
	highlight.SurfaceTransparency = 0.7
	highlight.Parent = target

	-- Pulsing effect
	task.spawn(function()
		while highlight.Parent do
			TweenService:Create(highlight, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.1
			}):Play()
			task.wait(0.8)
			TweenService:Create(highlight, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.5
			}):Play()
			task.wait(0.8)
		end
	end)

	TutorialState.highlightPart = highlight
end

local function updateTutorialStep()
	if not TutorialState.enabled or TutorialState.completed then return end

	local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
	if not step then
		TutorialState.completed = true
		if TutorialState.tutorialGui then
			TutorialState.tutorialGui:Destroy()
		end
		if TutorialState.highlightPart then
			TutorialState.highlightPart:Destroy()
		end
		return
	end

	print("🎓 [Tutorial] Step " .. TutorialState.currentStep .. ":", step.name)

	-- Update UI (set Title & Body every time!)
	if TutorialState.tutorialGui then
		local card = TutorialState.tutorialGui.Card
		local title = card:FindFirstChild("Title")
		local bodyLabel = card:FindFirstChild("Body")
		local stepIndicator = card:FindFirstChild("StepIndicator")
		
		if title then title.Text = step.title end
		if bodyLabel then bodyLabel.Text = step.body end
		if stepIndicator then 
			stepIndicator.Text = TutorialState.currentStep .. "/" .. #Config.TUTORIAL_STEPS
		end
	end

	-- Find and highlight target
	if step.targetButton then
		-- Find button in all tycoons
		for _, tycoon in pairs(workspace:GetChildren()) do
			if tycoon:FindFirstChild("Buttons") then
				for _, button in pairs(tycoon.Buttons:GetChildren()) do
					if button.Name == step.targetButton then
						local head = button:FindFirstChild("Head")
						if head and head.CanCollide and head.Transparency < 0.5 then
							createHighlight(head)
							print("✨ [Tutorial] Highlighting button:", step.targetButton)
							break
						end
					end
				end
			end
		end
	elseif step.target == "collector" then
		-- Find Giver part
		for _, tycoon in pairs(workspace:GetChildren()) do
			if tycoon:FindFirstChild("Essentials") then
				local giver = tycoon.Essentials:FindFirstChild("Giver")
				if giver then
					createHighlight(giver)
					print("✨ [Tutorial] Highlighting collector")
					break
				end
			end
		end
	end
end

local function nextTutorialStep()
	if not TutorialState.enabled or TutorialState.completed then return end

	TutorialState.currentStep = TutorialState.currentStep + 1
	
	-- ✨ Bounce animation when moving to next step
	if TutorialState.tutorialGui then
		local card = TutorialState.tutorialGui.Card
		local originalSize = card.Size
		
		TweenService:Create(card, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(originalSize.X.Offset * 1.05, originalSize.Y.Offset * 1.05)
		}):Play()
		
		task.wait(0.15)
		
		TweenService:Create(card, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = originalSize
		}):Play()
	end
	
	updateTutorialStep()
end

local function skipTutorial()
	TutorialState.completed = true
	TutorialState.enabled = false
	if TutorialState.tutorialGui then
		TutorialState.tutorialGui:Destroy()
	end
	if TutorialState.highlightPart then
		TutorialState.highlightPart:Destroy()
	end
	print("✅ Tutorial skipped!")
end

--============================================================================--
--                            UTILITY FUNCTIONS
--============================================================================--

-- Quadratic Bezier curve interpolation
local function quadraticBezier(t, p0, p1, p2)
	local u = 1 - t
	return u * u * p0 + 2 * u * t * p1 + t * t * p2
end

-- Get ground position with raycast (prefers player's ground level)
local function getGroundPosition(position, ignoreList, playerHeight)
	raycastParams.FilterDescendantsInstances = ignoreList

	-- First, try from player's height level
	if playerHeight then
		local rayOrigin = Vector3.new(position.X, playerHeight + 5, position.Z)
		local rayDirection = Vector3.new(0, -10, 0)
		local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

		if rayResult and math.abs(rayResult.Position.Y - playerHeight) < 10 then
			-- Found ground near player's level
			return rayResult.Position + Vector3.new(0, Config.GROUND_OFFSET, 0), rayResult.Normal
		end
	end

	-- Fallback: cast from above
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

	-- Point light for glow
	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 0
	pointLight.Color = Config.Colors.GLOW
	pointLight.Range = Config.LIGHT_BASE_RANGE
	pointLight.Parent = segment

	-- Selection box for outline glow
	local selection = Instance.new("SelectionBox")
	selection.Adornee = segment
	selection.Color3 = Config.Colors.GLOW
	selection.LineThickness = 0.05
	selection.Transparency = 1
	selection.Parent = segment

	-- Attributes for smooth animation
	segment:SetAttribute("TargetTransparency", 1)
	segment:SetAttribute("FadeFactor", 0)
	segment:SetAttribute("SegmentIndex", index)

	-- Store in state
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

local function findTycoonGates()
	local now = tick()

	-- Use cache if recent
	if now - PathState.lastGateUpdate < Config.GATE_UPDATE_INTERVAL * 0.5 and #PathState.cachedGates > 0 then
		return PathState.cachedGates
	end

	PathState.lastGateUpdate = now
	PathState.cachedGates = {}

	-- Search for tycoon gates
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("Model") then
			local name = obj.Name:lower()
			if name == "touch to claim!" or name:find("gate") or name:find("claim") then
				local touchPart = obj:FindFirstChild("Head") or obj:FindFirstChildWhichIsA("BasePart")

				if touchPart then
					-- Find the tycoon owner value
					local parent = obj.Parent
					while parent and parent ~= workspace do
						local owner = parent:FindFirstChild("Owner")
						if owner and owner:IsA("ObjectValue") then
							table.insert(PathState.cachedGates, {
								owner = owner,
								position = touchPart.Position,
								part = touchPart,
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
	local nearestGate = nil
	local nearestDistance = math.huge

	for _, gateData in pairs(gates) do
		if gateData.owner.Value == player then
			PathState.ownedTycoon = true
			return nil, true -- Player owns a tycoon
		elseif not gateData.owner.Value then
			local distance = (gateData.position - humanoidRoot.Position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestGate = gateData
			end
		end
	end

	return nearestGate, false
end

--============================================================================--
--                            PATH MANAGEMENT
--============================================================================--

local function hidePath()
	if not PathState.active then return end
	PathState.active = false

	-- Fade out all segments
	for _, segmentData in pairs(PathState.segments) do
		if segmentData and segmentData.part then
			segmentData.targetTransparency = 1
			segmentData.part:SetAttribute("TargetTransparency", 1)
		end
	end

	-- Immediate cleanup - don't wait
	task.spawn(function()
		task.wait(Config.FADE_OUT_TIME)
		if PathState.pathModel then
			-- Destroy all children first
			for _, child in pairs(PathState.pathModel:GetChildren()) do
				child:Destroy()
			end
			PathState.pathModel:Destroy()
			PathState.pathModel = nil
		end
		-- Clear segments table
		PathState.segments = {}
	end)
end

local function updatePath()
	local character = player.Character
	if not character then
		hidePath()
		return
	end

	local humanoidRoot = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRoot or not PathState.currentTargetGate then
		hidePath()
		return
	end

	-- Use actual positions for more responsive feel
	local startPos = humanoidRoot.Position
	local endPos = PathState.currentTargetGate.position

	-- Calculate adjusted end position (stop before the gate)
	local direction = (endPos - startPos).Unit
	local distance = (endPos - startPos).Magnitude

	-- Adjust end position to stop PATH_END_OFFSET studs before the gate
	if distance > Config.PATH_END_OFFSET then
		endPos = endPos - (direction * Config.PATH_END_OFFSET)
		distance = distance - Config.PATH_END_OFFSET
	end

	-- Check distance constraints
	if distance < Config.MIN_DISTANCE or distance > Config.MAX_DISTANCE then
		hidePath()
		return
	end

	-- Initialize smoothed positions if needed
	if not PathState.smoothedStartPos then
		PathState.smoothedStartPos = startPos
	end
	if not PathState.smoothedEndPos then
		PathState.smoothedEndPos = endPos
	end

	-- Update smoothed positions (more responsive)
	PathState.smoothedStartPos = PathState.smoothedStartPos:Lerp(startPos, Config.TARGET_SMOOTHING)
	PathState.smoothedEndPos = PathState.smoothedEndPos:Lerp(endPos, Config.TARGET_SMOOTHING)

	-- Use smoothed positions for path
	local smoothStart = PathState.smoothedStartPos
	local smoothEnd = PathState.smoothedEndPos
	local smoothDistance = (smoothEnd - smoothStart).Magnitude

	-- Create path model if needed
	if not PathState.pathModel or not PathState.pathModel.Parent then
		PathState.pathModel = Instance.new("Model")
		PathState.pathModel.Name = "LocalTycoonPath"
		PathState.pathModel.Parent = workspace
		PathState.segments = {} -- Reset segments table
	end

	-- Calculate bezier curve control point for arc
	-- Keep arc low to avoid going over structures
	local midPoint = (smoothStart + smoothEnd) / 2
	local arcHeight = math.min(smoothDistance * Config.PATH_ARC_HEIGHT, 5) -- Cap arc height at 5 studs
	local controlPoint = midPoint + Vector3.new(0, arcHeight, 0)

	local segmentCount = math.min(math.floor(smoothDistance / Config.SEGMENT_SPACING), Config.MAX_SEGMENTS)
	local ignoreList = {character, PathState.pathModel}
	local segmentPositions = {}

	-- Update each segment
	for i = 1, segmentCount do
		local segmentData = PathState.segments[i]
		local segment

		-- Get or create segment
		if not segmentData or not segmentData.part or not segmentData.part.Parent then
			segment = createSegment(i)
			segment.Parent = PathState.pathModel
			segmentData = PathState.segments[i]
		else
			segment = segmentData.part
		end

		-- Calculate position on bezier curve
		local t = i / (segmentCount + 1)
		local pathPos = quadraticBezier(t, smoothStart, controlPoint, smoothEnd)

		-- Get ground position (prefer player's height level)
		local playerHeight = humanoidRoot.Position.Y
		local groundPos, groundNormal = getGroundPosition(pathPos, ignoreList, playerHeight)
		segmentPositions[i] = groundPos

		-- Calculate direction
		local nextT = math.min(t + 0.01, 1)
		local nextPathPos = quadraticBezier(nextT, smoothStart, controlPoint, smoothEnd)
		local lookDirection = (nextPathPos - pathPos).Unit

		-- Orient segment
		local rightVector = lookDirection:Cross(groundNormal)
		if rightVector.Magnitude > 0.01 then
			rightVector = rightVector.Unit
			local upVector = rightVector:Cross(lookDirection).Unit
			local targetCFrame = CFrame.fromMatrix(groundPos, rightVector, upVector, -lookDirection)

			-- Faster position update for responsiveness
			segment.CFrame = segment.CFrame:Lerp(targetCFrame, Config.POSITION_SMOOTHING)
		end

		-- Scale taper
		local scale = 1 - (t * Config.SCALE_REDUCTION)
		segment.Size = Config.SEGMENT_SIZE * scale

		-- Anti-bunching calculation
		local fadeFactor = 0
		if i > 1 and segmentPositions[i-1] then
			local spacing = (segmentPositions[i] - segmentPositions[i-1]).Magnitude
			local minSpacing = Config.SEGMENT_SPACING * Config.BUNCHING_THRESHOLD
			if spacing < minSpacing then
				fadeFactor = math.clamp(1 - (spacing / minSpacing), 0, Config.MAX_BUNCH_FADE)
			end
		end

		-- Set attributes
		segment:SetAttribute("FadeFactor", fadeFactor)
		segment:SetAttribute("TargetTransparency", 0) -- Always visible unless bunched heavily
		segment:SetAttribute("Scale", scale)

		-- Update segment data
		segmentData.targetTransparency = fadeFactor > 0.7 and 1 or 0
	end

	-- Hide unused segments
	for i = segmentCount + 1, Config.MAX_SEGMENTS do
		local segmentData = PathState.segments[i]
		if segmentData and segmentData.part then
			segmentData.targetTransparency = 1
			segmentData.part:SetAttribute("TargetTransparency", 1)
		end
	end
end

--============================================================================--
--                          ANIMATION SYSTEM
--============================================================================--

local function animateSegments(deltaTime)
	if not PathState.pathModel or not PathState.pathModel.Parent then return end

	PathState.animationTime = PathState.animationTime + deltaTime

	for index, segmentData in pairs(PathState.segments) do
		if segmentData and segmentData.part and segmentData.part.Parent then
			local segment = segmentData.part
			local segmentIndex = segment:GetAttribute("SegmentIndex") or index

			-- Get animation parameters
			local targetTrans = segment:GetAttribute("TargetTransparency") or 1
			local fadeFactor = segment:GetAttribute("FadeFactor") or 0
			local scale = segment:GetAttribute("Scale") or 1

			-- Calculate final target transparency
			local finalTargetTrans = math.max(targetTrans, fadeFactor * 0.8) -- Less aggressive fade

			-- Smooth transparency update
			segmentData.currentTransparency = segmentData.currentTransparency + 
				(finalTargetTrans - segmentData.currentTransparency) * Config.TRANSPARENCY_SMOOTHING

			segment.Transparency = segmentData.currentTransparency

			-- Determine visibility
			local isVisible = segmentData.currentTransparency < 0.9

			if isVisible then
				-- Pulse animation
				local pulse = math.sin(PathState.animationTime * Config.PULSE_SPEED + segmentIndex * 0.2) * 0.5 + 0.5

				-- Light animation
				if segmentData.light then
					local brightness = Config.LIGHT_BASE_BRIGHTNESS + (pulse * Config.LIGHT_PULSE_BRIGHTNESS)
					segmentData.light.Brightness = brightness * (1 - segmentData.currentTransparency)
					segmentData.light.Range = Config.LIGHT_BASE_RANGE * scale
				end

				-- Selection box animation
				if segmentData.selection then
					local glowTrans = Config.GLOW_BASE_TRANSPARENCY + (pulse * Config.GLOW_PULSE_AMOUNT)
					segmentData.selection.Transparency = glowTrans + (segmentData.currentTransparency * 0.5)
				end

				-- Color flow effect
				local flow = (PathState.animationTime * Config.FLOW_SPEED + segmentIndex) % 10
				if flow < 1 then
					segment.Color = Config.Colors.GLOW:Lerp(Config.Colors.PULSE, flow)
				else
					segment.Color = Config.Colors.PATH
				end
			else
				-- Hide effects when invisible
				if segmentData.light then
					segmentData.light.Brightness = 0
				end
				if segmentData.selection then
					segmentData.selection.Transparency = 1
				end
			end
		end
	end
end

--============================================================================--
--                     🎓 TUTORIAL EVENT LISTENERS
--============================================================================--

-- 🎓 Track session cash (NO ServerStorage on client!)
local SessionCash = 0

local function setupTutorialListeners()
	if not TutorialState.enabled then return end

	-- 💰 Listen for money collection via RemoteEvent (works with manual + auto-collect!)
	local Remotes = ReplicatedStorage:WaitForChild("TycoonRemotes")
	local MoneyCollectedRE = Remotes:WaitForChild("MoneyCollected")
	
	local function onMoneyCollected(giver, amount, has2x, wasAuto)
		if not TutorialState.enabled or TutorialState.completed then return end
		SessionCash += tonumber(amount) or 0
		
		local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
		if not step then return end
		
		print("💰 [Tutorial] Money collected: +" .. amount .. " | Total session: $" .. SessionCash .. " | Step:", step.name)
		
		-- Step 3: first collect → advance immediately
		if step.name == "collect_money" then
			print("✅ [Tutorial] First cash collected! Moving to Dropper 2 step...")
			task.defer(nextTutorialStep)
			return
		end
		
		-- Step 4 gate: $70 accumulated → advance
		if step.name == "buy_dropper2" and SessionCash >= 70 then
			print("✅ [Tutorial] Has $70! Auto-advancing...")
			task.defer(nextTutorialStep)
		end
	end
	
	MoneyCollectedRE.OnClientEvent:Connect(onMoneyCollected)
	print("🎓 [Tutorial] Listening for MoneyCollected RemoteEvent")

	-- Listen for tycoon claims + purchases
	workspace.DescendantAdded:Connect(function(d)
		if not TutorialState.enabled or TutorialState.completed then return end
		local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
		if not step then return end

		-- When tycoon claimed (Owner set to player) → advance claim step
		if step.name == "claim_gate" then
			local owner = d:IsA("ObjectValue") and d.Name == "Owner" and d.Value
			if owner == player then
				print("✅ [Tutorial] Tycoon claimed! Advancing...")
				task.defer(nextTutorialStep)
			end
			return
		end

		-- Model spawns land in PurchasedObjects; check names only
		if d.Parent and d.Parent.Name == "PurchasedObjects" then
			if step.name == "buy_dropper1" and d.Name == "Dropper1" then
				print("✅ [Tutorial] Dropper1 spawned! Advancing...")
				task.defer(nextTutorialStep)
			elseif step.name == "buy_dropper2" and d.Name == "Dropper2" then
				print("🎉 [Tutorial] Dropper2 spawned! Tutorial complete!")
				task.defer(function()
					nextTutorialStep() -- completes tutorial
					task.wait(0.8)
					skipTutorial()     -- fade out card
				end)
			end
		end
	end)

	-- Skip button
	if TutorialState.skipButton then
		TutorialState.skipButton.Activated:Connect(function()
			print("⏭️ [Tutorial] Player clicked Skip")
			skipTutorial()
		end)
	end
end

--============================================================================--
--                            MAIN UPDATE LOOP
--============================================================================--

RunService.RenderStepped:Connect(function(deltaTime)
	-- Always update path every frame for responsiveness
	updatePath()

	-- Always animate
	animateSegments(deltaTime)
end)

-- Gate scanning loop (separate)
task.spawn(function()
	while true do
		task.wait(Config.GATE_UPDATE_INTERVAL)

		local targetGate, ownsTycoon = findNearestUnclaimedGate()

		if ownsTycoon or not targetGate then
			PathState.currentTargetGate = nil
			hidePath()

			-- Force cleanup if player owns tycoon
			if ownsTycoon and PathState.pathModel then
				for _, child in pairs(PathState.pathModel:GetChildren()) do
					child:Destroy()
				end
				PathState.pathModel:Destroy()
				PathState.pathModel = nil
				PathState.segments = {}
			end
		else
			if not PathState.active then
				-- Reset smoothed positions for instant response
				PathState.smoothedStartPos = nil
				PathState.smoothedEndPos = nil
			end
			PathState.active = true
			PathState.currentTargetGate = targetGate
		end
	end
end)

--============================================================================--
--                            CLEANUP HANDLERS
--============================================================================--

player.CharacterRemoving:Connect(function()
	if PathState.pathModel then
		PathState.pathModel:Destroy()
		PathState.pathModel = nil
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
		lastPathUpdate = 0,
		animationTime = 0,
		ownedTycoon = false,
	}
end)

--============================================================================--
--                            INITIALIZATION
--============================================================================--

-- Wait for character
if not player.Character then
	player.CharacterAdded:Wait()
end

-- 🎓 Tutorial initialization (NO WAITS - INSTANT!)
if Config.TUTORIAL_ENABLED then
	local shouldShowTutorial = true
	
	-- Check if player already owns tycoon and has Dropper2 → skip tutorial
	for _, tycoon in ipairs(workspace:GetChildren()) do
		local owner = tycoon:FindFirstChild("Owner")
		if owner and owner.Value == player then
			local purchased = tycoon:FindFirstChild("PurchasedObjects")
			if purchased and purchased:FindFirstChild("Dropper2") then
				shouldShowTutorial = false
				print("🎓 [Tutorial] SKIPPED - player already owns Dropper2")
				break
			end
		end
	end
	
	if shouldShowTutorial then
		-- Start tutorial INSTANTLY (no waits!)
		createTutorialUI()
		TutorialState.enabled = true
		TutorialState.completed = false
		TutorialState.currentStep = TutorialState.currentStep or 1
		setupTutorialListeners()
		updateTutorialStep() -- Sets card Title/Body immediately
		print("🎓 [Tutorial] Started instantly - 4 steps!")
	else
		TutorialState.enabled = false
		TutorialState.completed = true
	end
end

print("✅ Tycoon Path Guide v4.0 + Tutorial (FIXED!)")
print("⚡ Instant response - no ServerStorage polling!")
print("🎓 Tutorial: 4 steps using RemoteEvents → Claim → Drop1 → Collect → Drop2 → Done!")
