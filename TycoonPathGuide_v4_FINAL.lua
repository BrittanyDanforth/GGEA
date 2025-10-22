--[[
	CLIENT-ONLY TYCOON PATH GUIDE + TUTORIAL [v4.4-ULTRA-POLISHED]
	✅ Auto-Collect Compatible (monitors leaderstats.Cash!)
	✅ Built-in tutorial with cute, specific messages
	✅ INSTANT fade out animation (no more waiting!)
	✅ Clean, minimal UI - no overlapping elements
	✅ Uses workspace.DescendantAdded for reliable purchase detection
	
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
	GATE_UPDATE_INTERVAL = 0.25,
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
			description = "This will drop cute Cinnamoroll backpacks that turn into cash!\n\nWalk to the glowing button and touch it.",
			targetButton = "Begin Working!",
		},
		{
			name = "collect_money",
			title = "Earning Cash! 💰",
			description = "Your dropper is working! Cash is being collected automatically.\n\nYou'll need $70 for the next upgrade.",
			target = "collector",
		},
		{
			name = "buy_dropper2",
			title = "Buy Your Second Dropper! ✨",
			description = "Nice! You have enough cash now.\n\nBuy the second dropper to earn even faster!",
			targetButton = "Buy Dropper - [$70]",
		},
		{
			name = "tutorial_complete",
			title = "You're All Set! 🎉",
			description = "Amazing! You're earning cash like a pro!\n\nKeep buying upgrades to build your dream tycoon. Tap anywhere to close.",
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
--                       🎓 TUTORIAL UI SYSTEM (POLISHED!)
--============================================================================--

local function createTutorialUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialGui"
	gui.DisplayOrder = 9999
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local phone = isPhone()
	local tablet = isTablet()

	local cardW = phone and 340 or (tablet and 400 or 450)
	local cardH = phone and 140 or (tablet and 125 or 115)
	local titleSize = phone and 20 or (tablet and 22 or 24)
	local bodySize = phone and 14 or (tablet and 15 or 16)

	-- Main card
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

	local corner = Instance.new("UICorner", card)
	corner.CornerRadius = UDim.new(0, 16)
	
	local stroke = Instance.new("UIStroke", card)
	stroke.Color = Color3.fromRGB(255, 180, 210)
	stroke.Thickness = 3
	
	local padding = Instance.new("UIPadding", card)
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)

	-- Title
	local title = Instance.new("TextLabel", card)
	title.Name = "Title"
	title.Size = UDim2.new(1, -70, 0, titleSize + 4)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = titleSize
	title.TextColor3 = Color3.fromRGB(255, 105, 180)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Top
	title.Text = "Tutorial"

	-- Body
	local body = Instance.new("TextLabel", card)
	body.Name = "Body"
	body.Position = UDim2.new(0, 0, 0, titleSize + 6)
	body.Size = UDim2.new(1, -70, 1, -(titleSize + 20))
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextSize = bodySize
	body.TextColor3 = Color3.fromRGB(120, 100, 130)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.Text = "Welcome!"

	-- Skip button (top-right, cleaner positioning)
	local skipBtn = Instance.new("TextButton", card)
	skipBtn.Name = "SkipButton"
	skipBtn.AnchorPoint = Vector2.new(1, 0)
	skipBtn.Position = UDim2.new(1, -10, 0, 10)
	skipBtn.Size = UDim2.fromOffset(55, 26)
	skipBtn.BackgroundColor3 = Color3.fromRGB(230, 220, 255)
	skipBtn.Text = "Skip"
	skipBtn.Font = Enum.Font.GothamBold
	skipBtn.TextSize = 12
	skipBtn.TextColor3 = Color3.fromRGB(150, 120, 160)
	skipBtn.BorderSizePixel = 0
	
	local skipCorner = Instance.new("UICorner", skipBtn)
	skipCorner.CornerRadius = UDim.new(0, 8)

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

	task.spawn(function()
		while highlight and highlight.Parent do
			local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			TweenService:Create(highlight, tweenInfo, {Transparency = 0.1}):Play()
			task.wait(0.8)
			if not (highlight and highlight.Parent) then break end
			TweenService:Create(highlight, tweenInfo, {Transparency = 0.5}):Play()
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
		if TutorialState.tutorialGui then TutorialState.tutorialGui:Destroy() end
		if TutorialState.highlightPart then TutorialState.highlightPart:Destroy() end
		return
	end

	print("🎓 [Tutorial] Step " .. TutorialState.currentStep .. ":", step.name)

	if TutorialState.tutorialGui then
		local card = TutorialState.tutorialGui.Card
		card.Title.Text = step.title
		card.Body.Text = step.description
	end

	if TutorialState.highlightPart then TutorialState.highlightPart:Destroy() end

	local targetPart = nil
	if step.targetButton then
		for _, tycoon in pairs(workspace:GetChildren()) do
			local buttonsFolder = tycoon:FindFirstChild("Buttons")
			if buttonsFolder then
				local buttonModel = buttonsFolder:FindFirstChild(step.targetButton)
				if buttonModel then
					targetPart = buttonModel:FindFirstChild("Head")
					if targetPart and targetPart.CanCollide and targetPart.Transparency < 0.5 then
						print("✨ [Tutorial] Highlighting button:", step.targetButton)
						break
					end
				end
			end
		end
	elseif step.target == "collector" and PathState.ownedTycoon then
		for _, tycoon in pairs(workspace:GetChildren()) do
			local ownerVal = tycoon:FindFirstChild("Owner")
			if ownerVal and ownerVal.Value == player then
				local essentials = tycoon:FindFirstChild("Essentials")
				targetPart = essentials and essentials:FindFirstChild("Giver")
				if targetPart then
					print("✨ [Tutorial] Highlighting collector")
					break
				end
			end
		end
	end

	if targetPart then createHighlight(targetPart) end
end

local function nextTutorialStep()
	if not TutorialState.enabled or TutorialState.completed then return end

	local oldStep = TutorialState.currentStep
	TutorialState.currentStep = TutorialState.currentStep + 1
	print("➡️ [Tutorial] Step " .. oldStep .. " → " .. TutorialState.currentStep)

	if TutorialState.tutorialGui then
		local card = TutorialState.tutorialGui.Card
		local originalSize = card.Size
		local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local biggerSize = UDim2.fromOffset(originalSize.X.Offset * 1.05, originalSize.Y.Offset * 1.05)

		local t1 = TweenService:Create(card, tweenInfo, { Size = biggerSize })
		local t2 = TweenService:Create(card, tweenInfo, { Size = originalSize })
		t1:Play()
		t1.Completed:Wait()
		t2:Play()
	end

	updateTutorialStep()
end

local function skipTutorial()
	TutorialState.completed = true
	TutorialState.enabled = false
	
	-- Fast fade out animation!
	if TutorialState.tutorialGui then
		local card = TutorialState.tutorialGui:FindFirstChild("Card")
		if card then
			TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0, -200)
			}):Play()
		end
		task.wait(0.25)
		TutorialState.tutorialGui:Destroy()
	end
	
	if TutorialState.highlightPart then 
		TutorialState.highlightPart:Destroy() 
	end
	
	print("✅ [Tutorial] Completed!")
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

	local pointLight = Instance.new("PointLight", segment)
	pointLight.Brightness = 0
	pointLight.Color = Config.Colors.GLOW
	pointLight.Range = Config.LIGHT_BASE_RANGE

	local selection = Instance.new("SelectionBox", segment)
	selection.Adornee = segment
	selection.Color3 = Config.Colors.GLOW
	selection.LineThickness = 0.05
	selection.Transparency = 1

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
	
	for _, obj in ipairs(workspace:GetDescendants()) do
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
								part = touchPart
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

local function hidePath()
	if not PathState.active then return end
	PathState.active = false
	
	for _, segmentData in ipairs(PathState.segments) do
		if segmentData and segmentData.part then
			segmentData.targetTransparency = 1
			segmentData.part:SetAttribute("TargetTransparency", 1)
		end
	end
	
	task.delay(Config.FADE_OUT_TIME, function()
		if PathState.pathModel then
			PathState.pathModel:Destroy()
			PathState.pathModel = nil
			PathState.segments = {}
		end
	end)
end

local function updatePath()
	local character = player.Character
	if not character or not character.PrimaryPart or not PathState.currentTargetGate then
		hidePath()
		return
	end
	
	local startPos, endPos = character.PrimaryPart.Position, PathState.currentTargetGate.position
	local direction, distance = (endPos - startPos).Unit, (endPos - startPos).Magnitude

	if distance > Config.PATH_END_OFFSET then
		endPos -= direction * Config.PATH_END_OFFSET
		distance -= Config.PATH_END_OFFSET
	end

	if distance < Config.MIN_DISTANCE or distance > Config.MAX_DISTANCE then
		hidePath()
		return
	end

	if not PathState.smoothedStartPos then PathState.smoothedStartPos = startPos end
	if not PathState.smoothedEndPos then PathState.smoothedEndPos = endPos end

	PathState.smoothedStartPos = PathState.smoothedStartPos:Lerp(startPos, Config.TARGET_SMOOTHING)
	PathState.smoothedEndPos = PathState.smoothedEndPos:Lerp(endPos, Config.TARGET_SMOOTHING)

	local smoothStart, smoothEnd = PathState.smoothedStartPos, PathState.smoothedEndPos
	local smoothDistance = (smoothEnd - smoothStart).Magnitude

	if not PathState.pathModel or not PathState.pathModel.Parent then
		PathState.pathModel = Instance.new("Model", workspace)
		PathState.pathModel.Name = "LocalTycoonPath"
		PathState.segments = {}
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
	PathState.animationTime += deltaTime
	
	for index, segmentData in ipairs(PathState.segments) do
		local segment = segmentData.part
		if segment and segment.Parent then
			local targetTrans = segment:GetAttribute("TargetTransparency") or 1
			local fadeFactor = segment:GetAttribute("FadeFactor") or 0
			local finalTargetTrans = math.max(targetTrans, fadeFactor * 0.8)
			segmentData.currentTransparency += (finalTargetTrans - segmentData.currentTransparency) * Config.TRANSPARENCY_SMOOTHING
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
				segmentData.light.Brightness, segmentData.selection.Transparency = 0, 1
			end
		end
	end
end

--============================================================================--
--                     🎓 TUTORIAL EVENT LISTENERS
--============================================================================--

local function setupTutorialListeners()
	if not TutorialState.enabled then return end

	-- ✅ CASH MONITORING (Auto-Collect Compatible!)
	local leaderstats = player:WaitForChild("leaderstats", 15)
	if not leaderstats then 
		warn("[Tutorial] Leaderstats not found!")
		return 
	end

	local cash = leaderstats:WaitForChild("Cash", 10)
	if not cash then
		warn("[Tutorial] Cash value not found!")
		return
	end

	local lastCashValue = cash.Value
	local moneyConnection

	moneyConnection = cash.Changed:Connect(function(newCashValue)
		if not TutorialState.enabled or TutorialState.completed then 
			if moneyConnection then moneyConnection:Disconnect() end
			return 
		end

		local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]

		if step and step.name == "collect_money" and newCashValue > lastCashValue then
			print("💰 [Tutorial] Cash increased! Advancing step.")
			task.wait(0.3)
			nextTutorialStep()
		end

		lastCashValue = newCashValue
	end)
	print("✅ [Tutorial] Monitoring player.leaderstats.Cash")

	-- ✅ PURCHASE DETECTION
	local purchaseConnection
	purchaseConnection = workspace.DescendantAdded:Connect(function(descendant)
		if not TutorialState.enabled or TutorialState.completed then 
			if purchaseConnection then purchaseConnection:Disconnect() end
			return 
		end
		local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
		if not step then return end

		if descendant.Parent and descendant.Parent.Name == "PurchasedObjects" then
			print("🔍 [Tutorial] Purchase detected:", descendant.Name, "| Current step:", step.name)
			
			if step.name == "buy_dropper1" and descendant.Name == "Dropper1" then
				print("✅ [Tutorial] Dropper1 bought!")
				task.wait(1.5)
				nextTutorialStep()
			elseif step.name == "buy_dropper2" and descendant.Name == "Dropper2" then
				print("🎉 [Tutorial] Dropper2 bought!")
				task.wait(0.5)
				nextTutorialStep()
			end
		end
	end)

	-- Skip button
	if TutorialState.skipButton then
		TutorialState.skipButton.Activated:Connect(skipTutorial)
	end

	-- Last step: tap to dismiss
	local inputConnection
	inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if not TutorialState.enabled or TutorialState.completed then 
			if inputConnection then inputConnection:Disconnect() end
			return 
		end
		local step = Config.TUTORIAL_STEPS[TutorialState.currentStep]
		if step and step.name == "tutorial_complete" then
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				skipTutorial()
			end
		end
	end)
end

--============================================================================--
--                            MAIN LOOP & INITIALIZATION
--============================================================================--

RunService.RenderStepped:Connect(animateSegments)

-- Gate scanning & tutorial progression
task.spawn(function()
	print("🚪 [Tutorial] Gate scanning loop started!")
	while true do
		local targetGate, ownsTycoon = findNearestUnclaimedGate()
		
		if ownsTycoon or not targetGate then
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
						nextTutorialStep()
					end
				end
			end
			PathState.currentTargetGate = nil
			hidePath()
		else
			if not PathState.active then
				PathState.smoothedStartPos, PathState.smoothedEndPos = nil, nil
			end
			PathState.active = true
			PathState.currentTargetGate = targetGate
			updatePath()
		end
		task.wait(Config.GATE_UPDATE_INTERVAL)
	end
end)

-- Cleanup on character removal
player.CharacterRemoving:Connect(function()
	if PathState.pathModel then PathState.pathModel:Destroy() end
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
		ownedTycoon = false
	}
end)

-- Wait for character and initialize
if not player.Character then 
	player.CharacterAdded:Wait() 
end

-- Initialize tutorial
if Config.TUTORIAL_ENABLED then
	task.wait(2)
	createTutorialUI()
	setupTutorialListeners()
	updateTutorialStep()
	print("🎓 [Tutorial] Initialized!")
end

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ Tycoon Path Guide v4.4-ULTRA-POLISHED")
print("⚡ INSTANT fade + Auto-Collect Compatible!")
print("🎀 Cute messages + leaderstats.Cash monitoring")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
