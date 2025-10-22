--[[
	CLIENT-ONLY TYCOON PATH GUIDE + TUTORIAL [v4.3-GIVER-FIX]
	🎓 Built-in tutorial for first 2 droppers!
	🔧 Uses workspace.DescendantAdded (PROVEN TO WORK!)
	🔧 AUTO-SKIPS collect step after 2s (auto-collect fix!)
	🔧 FIXED Giver.Touched detection (searches ALL descendants!)
	- Fast polling: 0.25s for instant gate claim detection
	- Mobile-optimized: Touch-friendly, readable text
	- Place in StarterPlayer > StarterPlayerScripts as a LocalScript
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
		PATH = Color3.fromRGB(255, 179, 212),
		GLOW = Color3.fromRGB(255, 204, 229),
		PULSE = Color3.fromRGB(255, 230, 240),
		TUTORIAL_HIGHLIGHT = Color3.fromRGB(100, 200, 255),
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
	GATE_UPDATE_INTERVAL = 0.25, -- FAST polling!
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
	TUTORIAL_STEPS = {
		{
			name = "claim_gate",
			title = "Welcome to Your Tycoon! 🎀",
			description = "Touch the gate to claim your tycoon!",
			target = "gate",
		},
		{
			name = "buy_dropper1",
			title = "Buy Your First Dropper! 💎",
			description = "This cute Cinnamoroll backpack will drop cash for you!\n\nWalk to the glowing button and touch it.",
			targetButton = "Begin Working!",
		},
		{
			name = "collect_money",
			title = "Collect Your Cash! 💰",
			description = "Walk to the green collector to pick up your cash!\n\nYou'll need it to buy the next dropper.",
			target = "collector",
		},
		{
			name = "buy_dropper2",
			title = "Upgrade Time! ✨",
			description = "Buy the next dropper (Cinnamoroll Plushie) to earn cash faster!\n\nIt costs $70 - collect from your first dropper first.",
			targetButton = "Buy Dropper - [$70]",
		},
		{
			name = "tutorial_complete",
			title = "You're All Set! 🎉",
			description = "Great job! Keep buying upgrades to grow your tycoon.\n\nTap anywhere to dismiss this tutorial.",
			target = nil,
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
	ownedTycoon = false,
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
	gui.DisplayOrder = 9999
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	-- Responsive sizing
	local phone = isPhone()
	local tablet = isTablet()

	local cardW = phone and 340 or (tablet and 400 or 450)
	local cardH = phone and 160 or (tablet and 140 or 130)
	local titleSize = phone and 20 or (tablet and 22 or 24)
	local bodySize = phone and 14 or (tablet and 15 or 16)

	-- Card (starts above screen!)
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, -cardH - 20)
	card.Size = UDim2.fromOffset(cardW, cardH)
	card.BackgroundColor3 = Color3.fromRGB(255, 248, 252)
	card.BorderSizePixel = 0
	card.Parent = gui
	
	-- Slide down animation
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
	
	-- Step indicator
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
	stepIndicator.Text = "1/5"
	stepIndicator.Parent = card

	local stepCorner = Instance.new("UICorner")
	stepCorner.CornerRadius = UDim.new(0, 8)
	stepCorner.Parent = stepIndicator

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

	return gui
end

local function createHighlight(target)
	if TutorialState.highlightPart then
		TutorialState.highlightPart:Destroy()
	end

	if not target or not target:IsA("BasePart") then return end

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

	-- Update UI
	if TutorialState.tutorialGui then
		local card = TutorialState.tutorialGui.Card
		local title = card:FindFirstChild("Title")
		local body = card:FindFirstChild("Body")
		local stepIndicator = card:FindFirstChild("StepIndicator")
		
		if title then title.Text = step.title end
		if body then body.Text = step.description end
		if stepIndicator then
			stepIndicator.Text = TutorialState.currentStep .. "/" .. #Config.TUTORIAL_STEPS
		end
	end

	-- Find and highlight target
	if step.targetButton then
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

	local oldStep = TutorialState.currentStep
	TutorialState.currentStep = TutorialState.currentStep + 1
	print("➡️ [Tutorial] Step " .. oldStep .. " → " .. TutorialState.currentStep)
	
	-- Bounce animation
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
	print("✅ [Tutorial] Skipped!")
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

local function findTycoonGates()
	local now = tick()

	if now - PathState.lastGateUpdate < Config.GATE_UPDATE_INTERVAL * 0.5 and #PathState.cachedGates > 0 then
		return PathState.cachedGates
	end

	PathState.lastGateUpdate = now
	PathState.cachedGates = {}

	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("Model") then
			local name = obj.Name:lower()
			if name == "touch to claim!" or name:find("gate") or name:find("claim") then
				local touchPart = obj:FindFirstChild("Head") or obj:FindFirstChildWhichIsA("BasePart")

				if touchPart then
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
			-- 🔧 FIXED: Don't set PathState.ownedTycoon here!
			return nil, true
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

	for _, segmentData in pairs(PathState.segments) do
		if segmentData and segmentData.part then
			segmentData.targetTransparency = 1
			segmentData.part:SetAttribute("TargetTransparency", 1)
		end
	end

	task.spawn(function()
		task.wait(Config.FADE_OUT_TIME)
		if PathState.pathModel then
			for _, child in pairs(PathState.pathModel:GetChildren()) do
				child:Destroy()
			end
			PathState.pathModel:Destroy()
			PathState.pathModel = nil
		end
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

	local startPos = humanoidRoot.Position
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

	if not PathState.smoothedStartPos then
		PathState.smoothedStartPos = startPos
	end
	if not PathState.smoothedEndPos then
		PathState.smoothedEndPos = endPos
	end

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
	end

	local midPoint = (smoothStart + smoothEnd) / 2
	local arcHeight = math.min(smoothDistance * Config.PATH_ARC_HEIGHT, 5)
	local controlPoint = midPoint + Vector3.new(0, arcHeight, 0)

	local segmentCount = math.min(math.floor(smoothDistance / Config.SEGMENT_SPACING), Config.MAX_SEGMENTS)
	local ignoreList = {character, PathState.pathModel}
	local segmentPositions = {}

	for i = 1, segmentCount do
		local segmentData = PathState.segments[i]
		local segment

		if not segmentData or not segmentData.part or not segmentData.part.Parent then
			segment = createSegment(i)
			segment.Parent = PathState.pathModel
			segmentData = PathState.segments[i]
		else
			segment = segmentData.part
		end

		local t = i / (segmentCount + 1)
		local pathPos = quadraticBezier(t, smoothStart, controlPoint, smoothEnd)

		local playerHeight = humanoidRoot.Position.Y
		local groundPos, groundNormal = getGroundPosition(pathPos, ignoreList, playerHeight)
		segmentPositions[i] = groundPos

		local nextT = math.min(t + 0.01, 1)
		local nextPathPos = quadraticBezier(nextT, smoothStart, controlPoint, smoothEnd)
		local lookDirection = (nextPathPos - pathPos).Unit

		local rightVector = lookDirection:Cross(groundNormal)
		if rightVector.Magnitude > 0.01 then
			rightVector = rightVector.Unit
			local upVector = rightVector:Cross(lookDirection).Unit
			local targetCFrame = CFrame.fromMatrix(groundPos, rightVector, upVector, -lookDirection)

			segment.CFrame = segment.CFrame:Lerp(targetCFrame, Config.POSITION_SMOOTHING)
		end

		local scale = 1 - (t * Config.SCALE_REDUCTION)
		segment.Size = Config.SEGMENT_SIZE * scale

		local fadeFactor = 0
		if i > 1 and segmentPositions[i-1] then
			local spacing = (segmentPositions[i] - segmentPositions[i-1]).Magnitude
			local minSpacing = Config.SEGMENT_SPACING * Config.BUNCHING_THRESHOLD
			if spacing < minSpacing then
				fadeFactor = math.clamp(1 - (spacing / minSpacing), 0, Config.MAX_BUNCH_FADE)
			end
		end

		segment:SetAttribute("FadeFactor", fadeFactor)
		segment:SetAttribute("TargetTransparency", 0)
		segment:SetAttribute("Scale", scale)

		segmentData.targetTransparency = fadeFactor > 0.7 and 1 or 0
	end

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

			local targetTrans = segment:GetAttribute("TargetTransparency") or 1
			local fadeFactor = segment:GetAttribute("FadeFactor") or 0
			local scale = segment:GetAttribute("Scale") or 1

			local finalTargetTrans = math.max(targetTrans, fadeFactor * 0.8)

			segmentData.currentTransparency = segmentData.currentTransparency + 
				(finalTargetTrans - segmentData.currentTransparency) * Config.TRANSPARENCY_SMOOTHING

			segment.Transparency = segmentData.currentTransparency

			local isVisible = segmentData.currentTransparency < 0.9

			if isVisible then
				local pulse = math.sin(PathState.animationTime * Config.PULSE_SPEED + segmentIndex * 0.2) * 0.5 + 0.5

				if segmentData.light then
					local brightness = Config.LIGHT_BASE_BRIGHTNESS + (pulse * Config.LIGHT_PULSE_BRIGHTNESS)
					segmentData.light.Brightness = brightness * (1 - segmentData.currentTransparency)
					segmentData.light.Range = Config.LIGHT_BASE_RANGE * scale
				end

				if segmentData.selection then
					local glowTrans = Config.GLOW_BASE_TRANSPARENCY + (pulse * Config.GLOW_PULSE_AMOUNT)
					segmentData.selection.Transparency = glowTrans + (segmentData.currentTransparency * 0.5)
				end

				local flow = (PathState.animationTime * Config.FLOW_SPEED + segmentIndex) % 10
				if flow < 1 then
					segment.Color = Config.Colors.GLOW:Lerp(Config.Colors.PULSE, flow)
				else
					segment.Color = Config.Colors.PATH
				end
			else
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
--                     🎓 TUTORIAL EVENT LISTENERS (v4.0 APPROACH!)
--============================================================================--

local function setupTutorialListeners()
	if not TutorialState.enabled then return end

	-- ✅ workspace.DescendantAdded (PROVEN TO WORK!)
	workspace.DescendantAdded:Connect(function(descendant)
		if not TutorialState.enabled or TutorialState.completed then return end

		local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
		if not step then return end

		-- Check if a purchased object was added
		if descendant.Parent and descendant.Parent.Name == "PurchasedObjects" then
			print("🔍 [Tutorial] Purchase detected:", descendant.Name, "| Current step:", step.name)
			
			if step.name == "buy_dropper1" and descendant.Name == "Dropper1" then
				print("✅ [Tutorial] Dropper1 bought!")
				task.wait(0.5)
				nextTutorialStep() -- Move to "collect_money"
				
				-- 🔧 AUTO-SKIP collect step after 2 seconds (for auto-collect gamepass users!)
				task.spawn(function()
					task.wait(2)
					if TutorialState.currentStep == 3 and Config.TUTORIAL_STEPS[3].name == "collect_money" then
						print("💰 [Tutorial] Auto-skipping collect step (auto-collect detected!)")
						nextTutorialStep() -- Skip to "buy_dropper2"
					end
				end)
				
			elseif step.name == "buy_dropper2" and descendant.Name == "Dropper2" then
				print("🎉 [Tutorial] Dropper2 bought!")
				task.wait(0.5)
				nextTutorialStep() -- Move to "tutorial_complete"
				
			-- 🔧 SAFETY: If player buys Dropper2 while stuck on collect_money, advance!
			elseif step.name == "collect_money" and descendant.Name == "Dropper2" then
				print("🎉 [Tutorial] Dropper2 bought (while on collect step - skipping ahead!)")
				TutorialState.currentStep = 3 -- Force to step 3
				task.wait(0.5)
				nextTutorialStep() -- Advance to step 4
				nextTutorialStep() -- Advance to step 5 (complete)
			end
		end
	end)

	-- ✅ Giver.Touched for money collection (FIXED - searches all descendants!)
	for _, giver in pairs(workspace:GetDescendants()) do
		if giver.Name == "Giver" and giver:IsA("BasePart") then
			print("🔍 [Tutorial] Found Giver at:", giver:GetFullName())
			giver.Touched:Connect(function(hit)
				if not TutorialState.enabled or TutorialState.completed then return end
				local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
				if step and step.name == "collect_money" then
					local character = player.Character
					if character and hit.Parent == character then
						print("💰 [Tutorial] Money collected via Giver touch!")
						task.wait(0.3)
						nextTutorialStep() -- Move to "buy_dropper2"
					end
				end
			end)
		end
	end

	-- Skip button
	if TutorialState.skipButton then
		TutorialState.skipButton.Activated:Connect(function()
			skipTutorial()
		end)
	end

	-- Last step: tap anywhere to dismiss
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if not TutorialState.enabled or TutorialState.completed then return end

		local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
		if step and step.name == "tutorial_complete" then
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				skipTutorial()
			end
		end
	end)
end

--============================================================================--
--                            MAIN UPDATE LOOP
--============================================================================--

RunService.RenderStepped:Connect(function(deltaTime)
	updatePath()
	animateSegments(deltaTime)
end)

-- Gate scanning loop (FAST: 0.25s)
task.spawn(function()
	print("🚪 [Tutorial] Gate scanning loop started! (interval:", Config.GATE_UPDATE_INTERVAL, "sec)")
	
	while true do
		task.wait(Config.GATE_UPDATE_INTERVAL)

		local targetGate, ownsTycoon = findNearestUnclaimedGate()

		if ownsTycoon or not targetGate then
			PathState.currentTargetGate = nil
			hidePath()

			-- 🎓 TUTORIAL: Player claimed tycoon!
			if ownsTycoon and not PathState.ownedTycoon then
				print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
				print("🏠 [Tutorial] ✨ TYCOON CLAIMED! ✨")
				print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
				
				PathState.ownedTycoon = true
				
				if TutorialState.enabled and not TutorialState.completed then
					local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
					if step and step.name == "claim_gate" then
						print("✅ [Tutorial] Advancing to Buy Dropper 1...")
						task.wait(1)
						nextTutorialStep() -- Move to "buy_dropper1"
					end
				end
			end

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

if not player.Character then
	player.CharacterAdded:Wait()
end

-- 🎓 Initialize tutorial
if Config.TUTORIAL_ENABLED then
	task.wait(2)
	createTutorialUI()
	setupTutorialListeners()
	updateTutorialStep()
	print("🎓 [Tutorial] Initialized!")
end

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ Tycoon Path Guide v4.3-GIVER-FIX")
print("⚡ Fast & Responsive + Tutorial!")
print("🎯 Uses workspace.DescendantAdded (PROVEN!)")
print("🔧 AUTO-SKIPS collect step after 2s (auto-collect fix!)")
print("🔧 FIXED Giver detection (searches ALL descendants!)")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
