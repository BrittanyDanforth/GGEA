--[[
	✨ Cinnamoroll Purchase Handler - ULTIMATE FIXED Version with AUTO-COLLECT + 2X CASH
	
	NEW FEATURES:
	✅ Auto-Collect Gamepass with visual indicators
	✅ 2x Cash Gamepass with proper multiplier
	✅ INSTANT MODEL DROP COLLECTION for DropperCore compatibility
	✅ Clean UI indicators for both gamepasses
	✅ DataStore saving for auto-collect preferences
	✅ Proper handling of "Drop_" model drops from Cinnamoroll droppers
--]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

-- ========================================
-- CONFIGURATION SYSTEM
-- ========================================
local CONFIG = {
	-- Gamepass IDs
	AUTO_COLLECT_GAMEPASS_ID = 1412171840,
	DOUBLE_CASH_GAMEPASS_ID = 1398974710,

	-- Colors
	CANNOT_AFFORD_COLOR = BrickColor.new("Really red"),
	CAN_AFFORD_COLOR = BrickColor.new("Lime green"),
	COLLECTOR_IDLE_COLOR = BrickColor.new("Cyan"),
	COLLECTOR_ACTIVE_COLOR = BrickColor.new("Bright red"),

	-- Timing - INSTANT!
	AUTO_COLLECT_DELAY = 0.0,
	DROP_COLLECTION_DELAY = 0.0,
	PURCHASE_COOLDOWN = 0.5,
	COLLECT_COOLDOWN = 0.5,

	-- Animation
	BUTTON_FADE_TIME = 0.4,
	OBJECT_FADE_IN_TIME = 0.5,
}

-- Get settings and references
local Settings = require(script.Parent.Parent.Parent.Settings) 
local Objects = {}
local TeamColor = script.Parent:WaitForChild("TeamColor").Value
local Money = script.Parent:WaitForChild("CurrencyToCollect")
local Stealing = Settings.StealSettings
local CanSteal = true

-- Track purchased items PER PLAYER
local purchasedItems = {}
local currentOwner = nil

-- Store original button states for reset
local originalButtonStates = {}

-- Track dependency connections
local dependencyConnections = {}

-- Track collected parts to prevent double collection
local collectedParts = {}

-- Auto-collect state
local autoCollectConnections = {}
local autoCollectEnabled = {}

-- Ownership cache
local ownershipCache = {}
local OWNERSHIP_CACHE_TTL = 45

-- DataStore for auto-collect preferences
local AUTO_COLLECT_STORE_NAME = "CinnamorollAutoCollect_v1"
local autoCollectStore

local datastoreSuccess, datastoreError = pcall(function()
	autoCollectStore = DataStoreService:GetDataStore(AUTO_COLLECT_STORE_NAME)
end)

if not datastoreSuccess then
	warn("DataStore unavailable:", datastoreError)
end

-- Set spawn colors
local essentials = script.Parent:WaitForChild("Essentials")
local spawn = essentials:WaitForChild("Spawn")
spawn.TeamColor = TeamColor
spawn.BrickColor = TeamColor

-- Get references
local buttons = script.Parent:WaitForChild("Buttons")
local purchases = script.Parent:WaitForChild("Purchases")
local purchasedObjects = script.Parent:WaitForChild("PurchasedObjects")
local tycoonOwner = script.Parent:WaitForChild("Owner")

-- Setup dedicated folders
local remotesFolder = ReplicatedStorage:FindFirstChild("TycoonRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "TycoonRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local autoCollectToggle = remotesFolder:FindFirstChild("AutoCollectToggle")
if not autoCollectToggle then
	autoCollectToggle = Instance.new("RemoteEvent")
	autoCollectToggle.Name = "AutoCollectToggle"
	autoCollectToggle.Parent = remotesFolder
end

local moneyCollectRemote = remotesFolder:FindFirstChild("MoneyCollected")
if not moneyCollectRemote then
	moneyCollectRemote = Instance.new("RemoteEvent")
	moneyCollectRemote.Name = "MoneyCollected"
	moneyCollectRemote.Parent = remotesFolder
end

local gamepassPurchaseRemote = remotesFolder:FindFirstChild("GamepassPurchased")
if not gamepassPurchaseRemote then
	gamepassPurchaseRemote = Instance.new("RemoteEvent")
	gamepassPurchaseRemote.Name = "GamepassPurchased"
	gamepassPurchaseRemote.Parent = remotesFolder
end

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================
local function getCacheKey(userId, passId)
	return tostring(userId) .. "_" .. tostring(passId)
end

local function setOwnershipCache(userId, passId, value)
	ownershipCache[getCacheKey(userId, passId)] = {
		value = value,
		timestamp = tick()
	}
end

local function getOwnershipCache(userId, passId)
	local key = getCacheKey(userId, passId)
	local cached = ownershipCache[key]
	if not cached then return nil end

	if tick() - cached.timestamp > OWNERSHIP_CACHE_TTL then
		ownershipCache[key] = nil
		return nil
	end

	return cached.value
end

local function saveAutoCollectPreference(player, enabled)
	if not autoCollectStore then return false end

	local key = "Player_" .. tostring(player.UserId)
	local success, err = pcall(function()
		autoCollectStore:SetAsync(key, {
			enabled = enabled,
			timestamp = os.time()
		})
	end)

	if not success then
		warn("Failed to save auto-collect preference:", err)
	end

	return success
end

local function loadAutoCollectPreference(player)
	if not autoCollectStore then return nil end

	local key = "Player_" .. tostring(player.UserId)
	local success, data = pcall(function()
		return autoCollectStore:GetAsync(key)
	end)

	if success and data and type(data.enabled) == "boolean" then
		return data.enabled
	end

	return nil
end

-- Simple sound function
local function playSound(part, soundId, volume)
	if not soundId or soundId == 0 then return end
	if soundId == 131961136 or soundId == 131886985 then return end
	if part:FindFirstChild("Sound") then return end

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring(soundId)
	sound.Volume = volume or 0.3
	sound.Parent = part
	sound:Play()

	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

-- Minimal particle effect
local function createMinimalParticles(position)
	local attachment = Instance.new("Attachment")
	attachment.Position = position
	attachment.Parent = workspace.Terrain

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 30
	emitter.Lifetime = NumberRange.new(0.3, 0.5)
	emitter.VelocityInheritance = 0
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Speed = NumberRange.new(3, 5)
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.Color = ColorSequence.new(Color3.fromRGB(180, 210, 235)) -- Light blue for Cinnamoroll
	emitter.Size = NumberSequence.new(0.3)
	emitter.Parent = attachment

	task.wait(0.1)
	emitter.Enabled = false
	Debris:AddItem(attachment, 1)
end

-- ========================================
-- 2X CASH FUNCTIONS
-- ========================================
local function check2xCashOwnership(player)
	if game:GetService("RunService"):IsStudio() then
		if _G.StudioGamepassPurchases then
			local studioKey = tostring(player.UserId) .. "_" .. tostring(CONFIG.DOUBLE_CASH_GAMEPASS_ID)
			if _G.StudioGamepassPurchases[studioKey] then
				return true
			end
		end
	end

	local cached = getOwnershipCache(player.UserId, CONFIG.DOUBLE_CASH_GAMEPASS_ID)
	if cached ~= nil then
		return cached
	end

	local success, hasPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, CONFIG.DOUBLE_CASH_GAMEPASS_ID)
	end)

	if success then
		setOwnershipCache(player.UserId, CONFIG.DOUBLE_CASH_GAMEPASS_ID, hasPass)
		return hasPass
	end
	return false
end

local function applyMoneyMultiplier(player, amount)
	if check2xCashOwnership(player) then
		return amount * 2, true
	end
	return amount, false
end

local function update2xCashIndicator(giver, has2xCash)
	local indicator2x = giver:FindFirstChild("2xCashIndicator")

	if has2xCash then
		if not indicator2x then
			local billboard2x = Instance.new("BillboardGui")
			billboard2x.Name = "2xCashIndicator"
			billboard2x.MaxDistance = 100
			billboard2x.Size = UDim2.new(3, 0, 1, 0)
			billboard2x.StudsOffset = Vector3.new(0, 5, 0)
			billboard2x.AlwaysOnTop = true
			billboard2x.Parent = giver

			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(1, 0, 1, 0)
			frame.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
			frame.BackgroundTransparency = 0.2
			frame.BorderSizePixel = 0
			frame.Parent = billboard2x

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.2, 0)
			corner.Parent = frame

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.Text = "2X CASH"
			label.TextScaled = true
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Font = Enum.Font.SourceSansBold
			label.TextStrokeTransparency = 0
			label.TextStrokeColor3 = Color3.new(0, 0, 0)
			label.Parent = frame
		end
	else
		if indicator2x then
			indicator2x:Destroy()
		end
	end
end

-- ========================================
-- AUTO-COLLECT FUNCTIONS
-- ========================================
local function checkAutoCollectOwnership(player)
	if game:GetService("RunService"):IsStudio() then
		if _G.StudioGamepassPurchases then
			local studioKey = tostring(player.UserId) .. "_" .. tostring(CONFIG.AUTO_COLLECT_GAMEPASS_ID)
			if _G.StudioGamepassPurchases[studioKey] then
				return true
			end
		end
	end

	local cached = getOwnershipCache(player.UserId, CONFIG.AUTO_COLLECT_GAMEPASS_ID)
	if cached ~= nil then
		return cached
	end

	local success, hasPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, CONFIG.AUTO_COLLECT_GAMEPASS_ID)
	end)

	if success then
		setOwnershipCache(player.UserId, CONFIG.AUTO_COLLECT_GAMEPASS_ID, hasPass)
		return hasPass
	end
	return false
end

local function performAutoCollect(player)
	if Money.Value <= 0 then return end
	if autoCollectEnabled[player] == false then return end

	local playerStats = ServerStorage.PlayerMoney:FindFirstChild(player.Name)
	if not playerStats then return end

	local moneyToCollect = Money.Value
	if moneyToCollect <= 0 then return end

	local finalAmount, has2x = applyMoneyMultiplier(player, moneyToCollect)

	-- INSTANT money transfer - no delays!
	playerStats.Value = playerStats.Value + finalAmount
	Money.Value = 0

	local giver = essentials:FindFirstChild("Giver")
	if giver then
		playSound(giver, Settings.Sounds.Collect, 0.15)
	end

	if moneyCollectRemote and giver then
		moneyCollectRemote:FireClient(player, giver, finalAmount, has2x, true)
	end
end

local function setupAutoCollect(player)
	if autoCollectConnections[player] then
		autoCollectConnections[player]:Disconnect()
		autoCollectConnections[player] = nil
	end

	if script.Parent.Owner.Value ~= player then
		return
	end

	print("☁️ [Cinnamoroll] Auto-Collect activated for", player.Name)

	if autoCollectEnabled[player] == nil then
		local savedPref = loadAutoCollectPreference(player)
		if savedPref ~= nil then
			autoCollectEnabled[player] = savedPref
		else
			autoCollectEnabled[player] = true
		end
	end

	local giver = essentials:FindFirstChild("Giver")
	if giver then
		update2xCashIndicator(giver, check2xCashOwnership(player))
	end

	-- INSTANT auto-collect connection - NO DELAYS!
	autoCollectConnections[player] = Money.Changed:Connect(function(newValue)
		if script.Parent.Owner.Value ~= player then
			if autoCollectConnections[player] then
				autoCollectConnections[player]:Disconnect()
				autoCollectConnections[player] = nil
			end
			return
		end

		if newValue > 0 and autoCollectEnabled[player] ~= false then
			performAutoCollect(player)
		end
	end)

	if Money.Value > 0 then
		performAutoCollect(player)
	end

	-- Create auto-collect indicator
	if giver then
		local oldIndicator = giver:FindFirstChild("AutoCollectIndicator")
		if oldIndicator then
			oldIndicator:Destroy()
		end

		local autoIndicator = Instance.new("BillboardGui")
		autoIndicator.Name = "AutoCollectIndicator"
		autoIndicator.MaxDistance = 100
		autoIndicator.Size = UDim2.new(3, 0, 0.8, 0)
		autoIndicator.StudsOffset = Vector3.new(0, 3.5, 0)
		autoIndicator.AlwaysOnTop = true
		autoIndicator.Parent = giver

		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BorderSizePixel = 0
		frame.Parent = autoIndicator

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = frame

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.SourceSansBold
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.Parent = frame

		if autoCollectEnabled[player] ~= false then
			frame.BackgroundColor3 = Color3.new(0, 0.7, 0.7) -- Cyan
			frame.BackgroundTransparency = 0.2
			label.Text = "AUTO"
			label.TextColor3 = Color3.new(1, 1, 1)
		else
			frame.BackgroundColor3 = Color3.new(0.5, 0, 0)
			frame.BackgroundTransparency = 0.2
			label.Text = "AUTO X"
			label.TextColor3 = Color3.new(1, 0.3, 0.3)
		end
	end
end

local function cleanupAutoCollect(player)
	if autoCollectConnections[player] then
		autoCollectConnections[player]:Disconnect()
		autoCollectConnections[player] = nil
	end

	autoCollectEnabled[player] = nil

	local giver = essentials:FindFirstChild("Giver")
	if giver then
		local indicator = giver:FindFirstChild("AutoCollectIndicator")
		if indicator then
			indicator:Destroy()
		end
		local indicator2x = giver:FindFirstChild("2xCashIndicator")
		if indicator2x then
			indicator2x:Destroy()
		end
	end

	print("☁️ [Cinnamoroll] Auto-Collect deactivated for", player and player.Name or "unknown")
end

-- Auto-collect toggle handler
autoCollectToggle.OnServerEvent:Connect(function(player, enabled)
	if not checkAutoCollectOwnership(player) then return end

	autoCollectEnabled[player] = enabled

	task.spawn(function()
		saveAutoCollectPreference(player, enabled)
	end)

	if script.Parent.Owner.Value ~= player then return end

	local giver = essentials:FindFirstChild("Giver")
	if giver then
		local indicator = giver:FindFirstChild("AutoCollectIndicator")
		if indicator then
			local frame = indicator:FindFirstChild("Frame")
			local label = frame and frame:FindFirstChild("TextLabel")
			if label then
				if enabled then
					label.Text = "AUTO"
					label.TextColor3 = Color3.new(1, 1, 1)
					frame.BackgroundColor3 = Color3.new(0, 0.7, 0.7)
				else
					label.Text = "AUTO X"
					label.TextColor3 = Color3.new(1, 0.3, 0.3)
					frame.BackgroundColor3 = Color3.new(0.5, 0, 0)
				end
			end
		end
	end

	print("🎚️ [Cinnamoroll] Auto-Collect", enabled and "enabled" or "disabled", "for", player.Name)
end)

-- ========================================
-- BUTTON STATE MANAGEMENT
-- ========================================
local function storeOriginalButtonStates()
	for _, button in ipairs(buttons:GetChildren()) do
		local head = button:FindFirstChild("Head")
		if head then
			originalButtonStates[button.Name] = {
				Transparency = head.Transparency,
				CanCollide = head.CanCollide,
				BrickColor = head.BrickColor,
				CFrame = head.CFrame
			}
		end
	end
	print("📸 [Cinnamoroll] Stored original states for", #buttons:GetChildren(), "buttons")
end

local function fixButtonPositions()
	local fixedCount = 0

	for _, button in ipairs(buttons:GetChildren()) do
		local head = button:FindFirstChild("Head")
		if head and head:IsA("BasePart") and originalButtonStates[button.Name] then
			local originalState = originalButtonStates[button.Name]
			if originalState.CFrame then
				head.CFrame = originalState.CFrame
				fixedCount = fixedCount + 1
			end
		end
	end

	if fixedCount > 0 then
		print("✅ [Cinnamoroll] Restored", fixedCount, "buttons to original positions")
	end
end

-- Update button colors based on money
function updateButtonColors(buttonFolder, playerMoney)
	if not currentOwner then return end

	for _, button in ipairs(buttonFolder:GetChildren()) do
		local head = button:FindFirstChild("Head")
		if not head or head.Transparency > 0 or not head.CanCollide then continue end

		local price = button:FindFirstChild("Price")
		price = price and price.Value or 0

		if price > 0 and playerMoney then
			if playerMoney.Value >= price then
				head.BrickColor = CONFIG.CAN_AFFORD_COLOR
			else
				head.BrickColor = CONFIG.CANNOT_AFFORD_COLOR
			end
		end
	end
end

-- Simple hover effect
local function addSimpleHoverEffect(button)
	local head = button:FindFirstChild("Head")
	if not head then return end

	local existingDetector = button:FindFirstChild("HoverDetector")
	if existingDetector then
		existingDetector:Destroy()
	end

	local originalSize = head.Size
	local isHovering = false

	local detector = Instance.new("Part")
	detector.Name = "HoverDetector"
	detector.Size = head.Size * 1.3
	detector.Transparency = 1
	detector.CanCollide = false
	detector.CFrame = head.CFrame
	detector.Parent = button

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = detector
	weld.Parent = detector

	detector.Touched:Connect(function(hit)
		local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid and not isHovering then
			isHovering = true

			TweenService:Create(head,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Size = originalSize * 1.02}
			):Play()

			task.spawn(function()
				while isHovering do
					task.wait(0.1)
					local stillNear = false
					for _, player in pairs(Players:GetPlayers()) do
						if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
							local distance = (player.Character.HumanoidRootPart.Position - head.Position).Magnitude
							if distance < 8 then
								stillNear = true
								break
							end
						end
					end

					if not stillNear then
						isHovering = false
						TweenService:Create(head,
							TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{Size = originalSize}
						):Play()
					end
				end
			end)
		end
	end)
end

-- Load all objects at start
local function loadAllObjects()
	for _, button in ipairs(buttons:GetChildren()) do
		local objectName = button:FindFirstChild("Object")
		objectName = objectName and objectName.Value
		if objectName then
			local purchaseObject = purchases:FindFirstChild(objectName)
			if purchaseObject then
				Objects[objectName] = purchaseObject:Clone()
				purchaseObject:Destroy()
			else
				warn("[Cinnamoroll] Object missing for button:", button.Name, "- Object:", objectName)
			end
		end
	end
	print("📦 [Cinnamoroll] Loaded", #Objects, "objects")
end

-- Setup button dependency system
local function setupButtonDependency(button)
	local head = button:FindFirstChild("Head")
	if not head then return end

	local dependency = button:FindFirstChild("Dependency")
	if dependency and dependency.Value and dependency.Value ~= "" then
		head.CanCollide = false
		head.Transparency = 1

		local function checkDependency()
			for _, obj in ipairs(purchasedObjects:GetChildren()) do
				if obj.Name == dependency.Value then
					return true
				end
			end
			return false
		end

		if checkDependency() then
			if originalButtonStates[button.Name] and originalButtonStates[button.Name].CFrame then
				head.CFrame = originalButtonStates[button.Name].CFrame
			end

			head.BrickColor = CONFIG.CANNOT_AFFORD_COLOR

			if Settings.ButtonsFadeIn then
				head.Transparency = 0.7
				TweenService:Create(head,
					TweenInfo.new(Settings.FadeInTime or 0.5, Enum.EasingStyle.Quad),
					{Transparency = 0}
				):Play()
			else
				head.Transparency = 0
			end
			head.CanCollide = true
			addSimpleHoverEffect(button)

			task.defer(function()
				if currentOwner then
					local stats = ServerStorage.PlayerMoney:FindFirstChild(currentOwner.Name)
					if stats then
						updateButtonColors(buttons, stats)
					end
				end
			end)
			return
		end

		local connection = purchasedObjects.ChildAdded:Connect(function(child)
			if child.Name == dependency.Value then
				print("✅ [Cinnamoroll] Dependency met for", button.Name, "- Required object spawned:", dependency.Value)

				if originalButtonStates[button.Name] and originalButtonStates[button.Name].CFrame then
					head.CFrame = originalButtonStates[button.Name].CFrame
				end

				head.BrickColor = CONFIG.CANNOT_AFFORD_COLOR

				if Settings.ButtonsFadeIn then
					head.Transparency = 0.7
					TweenService:Create(head,
						TweenInfo.new(Settings.FadeInTime or 0.5, Enum.EasingStyle.Quad),
						{Transparency = 0}
					):Play()
				else
					head.Transparency = 0
				end
				head.CanCollide = true

				addSimpleHoverEffect(button)

				task.defer(function()
					if currentOwner then
						local stats = ServerStorage.PlayerMoney:FindFirstChild(currentOwner.Name)
						if stats then
							updateButtonColors(buttons, stats)
						end
					end
				end)
			end
		end)

		if not dependencyConnections[button] then
			dependencyConnections[button] = {}
		end
		table.insert(dependencyConnections[button], connection)

		print("📎 [Cinnamoroll] Set up dependency for", button.Name, "waiting for", dependency.Value)
	else
		addSimpleHoverEffect(button)
	end
end

-- ========================================
-- COMPLETE RESET FUNCTION
-- ========================================
local function resetTycoonPurchases()
	print("🔄 [Cinnamoroll] RESETTING PURCHASE HANDLER...")

	-- ✅ STOP ALL DROPPERS + DISABLE THEIR SCRIPTS!
	for _, dropper in ipairs(script.Parent:GetChildren()) do
		if dropper.Name:find("Dropper") then
			-- Disable ALL scripts in dropper
			for _, script in ipairs(dropper:GetDescendants()) do
				if script:IsA("Script") or script:IsA("LocalScript") then
					script.Disabled = true
				end
			end
			dropper:SetAttribute("DropperRunning", false)
			print("  ⏸️ [Cinnamoroll] Stopped dropper:", dropper.Name)
		end
	end

	purchasedItems = {}

	-- ✅ DESTROY ALL CASH PARTS (including models!)
	local destroyedParts = 0
	local tycoonPosition = script.Parent:GetPivot().Position
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:FindFirstChild("Cash") and descendant:IsA("BasePart") then
			local distance = (descendant.Position - tycoonPosition).Magnitude
			if distance < 100 then
				descendant:Destroy()
				destroyedParts = destroyedParts + 1
			end
		end
	end
	print("  ✓ [Cinnamoroll] Destroyed", destroyedParts, "cash parts")

	Money.Value = 0

	-- ✅ DISABLE SCRIPTS IN PURCHASED OBJECTS BEFORE DESTROYING!
	local objectCount = #purchasedObjects:GetChildren()
	for _, obj in pairs(purchasedObjects:GetChildren()) do
		for _, descendant in ipairs(obj:GetDescendants()) do
			if descendant:IsA("Script") or descendant:IsA("LocalScript") then
				descendant.Disabled = true
			end
		end
		obj:Destroy()
	end
	print("  ✓ [Cinnamoroll] Destroyed", objectCount, "purchased objects")

	collectedParts = {}

	for button, connections in pairs(dependencyConnections) do
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end
	dependencyConnections = {}

	for _, button in pairs(buttons:GetChildren()) do
		local head = button:FindFirstChild("Head")
		if head and originalButtonStates[button.Name] then
			local originalState = originalButtonStates[button.Name]

			local hoverDetector = button:FindFirstChild("HoverDetector")
			if hoverDetector then
				hoverDetector:Destroy()
			end

			local dependency = button:FindFirstChild("Dependency")
			if dependency and dependency.Value and dependency.Value ~= "" then
				head.CanCollide = false
				head.Transparency = 1
			else
				head.CanCollide = originalState.CanCollide
				head.Transparency = originalState.Transparency
				head.BrickColor = CONFIG.CANNOT_AFFORD_COLOR
				addSimpleHoverEffect(button)
			end
		end
	end

	for _, button in pairs(buttons:GetChildren()) do
		setupButtonDependency(button)
	end

	local giver = essentials:FindFirstChild("Giver")
	if giver then
		giver.BrickColor = CONFIG.COLLECTOR_IDLE_COLOR
	end

	local buyObject = script.Parent:FindFirstChild("BuyObject")
	if buyObject then
		for _, child in pairs(buyObject:GetChildren()) do
			child:Destroy()
		end
	end

	CanSteal = true

	task.wait(0.1)
	fixButtonPositions()

	print("✅ [Cinnamoroll] Purchase handler fully reset!")
end

-- Monitor owner changes
tycoonOwner.Changed:Connect(function()
	local newOwner = tycoonOwner.Value

	if newOwner == nil and currentOwner ~= nil then
		-- Owner left: relax spawn and clear respawn
		local spawnLocation = essentials:FindFirstChild("Spawn")
		if spawnLocation and spawnLocation:IsA("SpawnLocation") then
			spawnLocation.Neutral = true
		end
		-- ✅ FIXED: Check if player still exists before clearing team!
		if currentOwner and currentOwner.Parent then
			currentOwner.RespawnLocation = nil
			currentOwner.Team = nil
		end

		cleanupAutoCollect(currentOwner)
		print("👋 [Cinnamoroll] Owner left, resetting purchases...")
		resetTycoonPurchases()
		currentOwner = nil
	elseif newOwner ~= nil and currentOwner == nil then
		currentOwner = newOwner
		print("👤 [Cinnamoroll] New owner:", currentOwner.Name)

		-- ✅ START ALL DROPPERS!
		for _, dropper in ipairs(script.Parent:GetChildren()) do
			if dropper.Name:find("Dropper") then
				local dropperScript = dropper:FindFirstChildOfClass("Script")
				if dropperScript then
					dropper:SetAttribute("DropperRunning", false)  -- Clear flag
					dropperScript.Disabled = false
					print("  ▶️ [Cinnamoroll] Started dropper:", dropper.Name)
				end
			end
		end

		-- ✅ SPAWN LOCATION SETUP - Player will respawn at their tycoon (on death only!)
		local teams = game:GetService("Teams")
		local spawnPart = essentials:WaitForChild("Spawn")

		-- Convert to SpawnLocation if needed
		if not spawnPart:IsA("SpawnLocation") then
			local s = Instance.new("SpawnLocation")
			s.Name = "Spawn"
			s.Size = spawnPart.Size
			s.CFrame = spawnPart.CFrame
			s.Anchored = true
			s.CanCollide = spawnPart.CanCollide
			s.BrickColor = spawnPart.BrickColor
			s.TeamColor = TeamColor
			s.Parent = essentials
			spawnPart:Destroy()
			spawnPart = s
		end

		-- Configure spawn for this tycoon
		spawnPart.Neutral = false
		spawnPart.TeamColor = TeamColor
		spawnPart.Enabled = true
		spawnPart.Duration = 0

		-- Put player on the tycoon team and set their respawn point
		local team = teams:FindFirstChild(script.Parent.Name)
		if team then
			team.TeamColor = TeamColor
			newOwner.Team = team
		end
		newOwner.TeamColor = TeamColor
		newOwner.RespawnLocation = spawnPart

		local giver = essentials:FindFirstChild("Giver")
		if giver then
			update2xCashIndicator(giver, check2xCashOwnership(newOwner))
		end

		local playerStats = ServerStorage.PlayerMoney:FindFirstChild(newOwner.Name)
		if playerStats then
			updateButtonColors(buttons, playerStats)

			playerStats.Changed:Connect(function()
				updateButtonColors(buttons, playerStats)
			end)
		end

		-- Check for auto-collect gamepass
		print("🔍 [Cinnamoroll] Checking if", newOwner.Name, "owns auto-collect gamepass...")
		local ownsAutoCollect = checkAutoCollectOwnership(newOwner)
		print("  Result:", ownsAutoCollect)

		if ownsAutoCollect then
			setupAutoCollect(newOwner)
		end
	end
end)

-- ========================================
-- INSTANT PART COLLECTOR FOR MODEL DROPS
-- ========================================
for _, collector in ipairs(essentials:GetChildren()) do
	if collector.Name == "PartCollector" then
		collector.CanCollide = false

		collector.Touched:Connect(function(part)
			-- INSTANT: Check if this part belongs to a Model with Cash
			local model = part.Parent
			local isModelDrop = false
			local modelCashValue = 0

			-- Check for Cinnamoroll drop patterns AND generic Drop_ pattern
			if model and model:IsA("Model") and (
				model.Name:match("^Drop_") or 
				model.Name:match("^Cinnamoroll") or 
				model.Name:match("^IceCream") or
				model.Name:match("^CinnamonRoll") or
				model.Name:match("^WhiteHeart")
			) then
				isModelDrop = true

				-- Find Cash value in ANY part of the model
				for _, descendant in ipairs(model:GetDescendants()) do
					if descendant:IsA("BasePart") and descendant:FindFirstChild("Cash") then
						local cash = descendant:FindFirstChild("Cash")
						if cash and cash:IsA("IntValue") then
							modelCashValue = modelCashValue + cash.Value
						end
					end
				end
			end

			-- Handle model drops INSTANTLY
			if isModelDrop and modelCashValue > 0 then
				if collectedParts[model] then 
					return 
				end
				if not currentOwner then return end

				collectedParts[model] = true

				-- INSTANT money addition - no delays!
				Money.Value = Money.Value + modelCashValue

				playSound(collector, Settings.Sounds.Collect, 0.1)

				-- Destroy the ENTIRE model
				model:Destroy()
				return
			end

			-- Original logic for simple parts with Cash - INSTANT
			if collectedParts[part] then return end
			if not currentOwner then return end

			local cashValue = part:FindFirstChild("Cash")
			if cashValue then
				collectedParts[part] = true

				-- INSTANT money addition - no delays!
				Money.Value = Money.Value + cashValue.Value

				playSound(collector, Settings.Sounds.Collect, 0.1)

				part.Anchored = true
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false

				if part:IsA("BasePart") then
					TweenService:Create(part,
						TweenInfo.new(0.3, Enum.EasingStyle.Linear),
						{Transparency = 1}
					):Play()

					for _, child in ipairs(part:GetDescendants()) do
						if child:IsA("Decal") or child:IsA("Texture") then
							TweenService:Create(child, TweenInfo.new(0.3), {Transparency = 1}):Play()
						elseif child:IsA("ParticleEmitter") then
							child.Enabled = false
						elseif child:IsA("PointLight") or child:IsA("SpotLight") then
							TweenService:Create(child, TweenInfo.new(0.3), {Brightness = 0}):Play()
						end
					end
				end

				task.wait(0.3)
				part:Destroy()

				task.delay(1, function()
					collectedParts[part] = nil
				end)
			end
		end)
	end
end

-- ========================================
-- MONEY COLLECTOR WITH 2X CASH
-- ========================================
local collectorDebounce = {}
local giver = essentials:WaitForChild("Giver")

giver.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player then return end

	if script.Parent.Owner.Value == player then
		-- Owner collecting - skip if auto-collect is active
		if autoCollectConnections[player] and autoCollectEnabled[player] ~= false then
			return
		end

		if collectorDebounce[player] then return end
		collectorDebounce[player] = true

		local originalColor = giver.BrickColor
		giver.BrickColor = BrickColor.new("Bright red")

		local originalSize = giver.Size
		TweenService:Create(giver,
			TweenInfo.new(0.1, Enum.EasingStyle.Quad),
			{Size = originalSize * 1.05}
		):Play()

		local playerStats = ServerStorage.PlayerMoney:FindFirstChild(player.Name)
		if playerStats and Money.Value > 0 then
			local moneyCollected = Money.Value

			-- Apply 2x multiplier if owned
			local finalAmount, has2x = applyMoneyMultiplier(player, moneyCollected)

			playerStats.Value = playerStats.Value + finalAmount
			Money.Value = 0

			-- Create cash notification
			local billboardGui = Instance.new("BillboardGui")
			billboardGui.Size = UDim2.new(0, 100, 0, 50)
			billboardGui.StudsOffset = Vector3.new(0, 3, 0)
			billboardGui.Parent = giver

			local textLabel = Instance.new("TextLabel")
			textLabel.Size = UDim2.new(1, 0, 1, 0)
			textLabel.BackgroundTransparency = 1
			textLabel.Text = "+$" .. tostring(finalAmount) .. (has2x and " (2X!)" or "")
			textLabel.TextScaled = true
			textLabel.TextColor3 = has2x and Color3.fromRGB(255, 215, 0) or Color3.new(0, 1, 0)
			textLabel.Font = Enum.Font.SourceSansBold
			textLabel.TextStrokeTransparency = 0
			textLabel.Parent = billboardGui

			TweenService:Create(billboardGui,
				TweenInfo.new(0.8, Enum.EasingStyle.Linear),
				{StudsOffset = Vector3.new(0, 6, 0)}
			):Play()

			TweenService:Create(textLabel,
				TweenInfo.new(0.8, Enum.EasingStyle.Linear),
				{TextTransparency = 1}
			):Play()

			Debris:AddItem(billboardGui, 0.8)
		end

		task.wait(0.1)
		TweenService:Create(giver,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad),
			{Size = originalSize}
		):Play()

		task.wait(0.4)
		giver.BrickColor = originalColor
		collectorDebounce[player] = nil

	elseif Stealing.Stealing and CanSteal then
		CanSteal = false
		task.delay(Stealing.PlayerProtection, function()
			CanSteal = true
		end)

		local playerStats = ServerStorage.PlayerMoney:FindFirstChild(player.Name)
		if playerStats then
			local stealAmount = math.floor(Money.Value * Stealing.StealPrecent)
			if stealAmount > 0 then
				playerStats.Value = playerStats.Value + stealAmount
				Money.Value = Money.Value - stealAmount
			end
		end
	else
		playSound(essentials, Settings.Sounds.ErrorBuy, 0.2)
	end
end)

-- ========================================
-- INITIALIZE
-- ========================================
task.defer(function()
	storeOriginalButtonStates()
	fixButtonPositions()
	loadAllObjects()

	for _, button in ipairs(buttons:GetChildren()) do
		setupButtonDependency(button)
	end
end)

-- ========================================
-- BUTTON TOUCH HANDLING
-- ========================================
for _, button in ipairs(buttons:GetChildren()) do
	task.spawn(function()
		local head = button:FindFirstChild("Head")
		if not head then return end

		local purchaseDebounce = {}
		head.Touched:Connect(function(hit)
			if not head.CanCollide or head.Transparency > 0 then return end
			if not currentOwner then return end

			local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then return end

			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player or player ~= currentOwner then return end

			if purchaseDebounce[player] then return end
			purchaseDebounce[player] = true

			task.defer(function()
				task.wait(CONFIG.PURCHASE_COOLDOWN)
				purchaseDebounce[player] = nil
			end)

			local playerStats = ServerStorage.PlayerMoney:FindFirstChild(player.Name)
			if not playerStats then return end

			local originalCFrame = head.CFrame
			TweenService:Create(head,
				TweenInfo.new(0.05, Enum.EasingStyle.Linear),
				{CFrame = originalCFrame * CFrame.new(0, -0.05, 0)}
			):Play()

			task.wait(0.05)
			TweenService:Create(head,
				TweenInfo.new(0.05, Enum.EasingStyle.Linear),
				{CFrame = originalCFrame}
			):Play()

			local gamepass = button:FindFirstChild("Gamepass")
			if gamepass and gamepass.Value >= 1 then
				local hasPass = false
				local success, result = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepass.Value)
				end)

				if success then hasPass = result end

				if hasPass then
					processPurchase(button, playerStats)
				else
					MarketplaceService:PromptGamePassPurchase(player, gamepass.Value)
				end
				return
			end

			local devProduct = button:FindFirstChild("DevProduct")
			if devProduct and devProduct.Value >= 1 then
				MarketplaceService:PromptProductPurchase(player, devProduct.Value)
				return
			end

			local price = button:FindFirstChild("Price")
			price = price and price.Value or 0

			if playerStats.Value >= price then
				processPurchase(button, playerStats)
			else
				playSound(head, Settings.Sounds.ErrorBuy, 0.2)

				local originalColor = head.BrickColor
				head.BrickColor = CONFIG.CANNOT_AFFORD_COLOR
				task.wait(0.15)
				head.BrickColor = originalColor
			end
		end)
	end)
end

-- ========================================
-- PURCHASE FUNCTION
-- ========================================
function processPurchase(button, playerStats)
	if not button or not playerStats then
		warn("[Cinnamoroll] processPurchase called with nil arguments")
		return
	end

	local price = button:FindFirstChild("Price")
	price = price and price.Value or 0

	local objectName = button:FindFirstChild("Object")
	objectName = objectName and objectName.Value

	playerStats.Value = playerStats.Value - price

	purchasedItems[button.Name] = true
	if objectName then
		purchasedItems[objectName] = true
	end

	if objectName and Objects[objectName] then
		local newObject = Objects[objectName]:Clone()
		newObject.Parent = purchasedObjects

		print("🎁 [Cinnamoroll] Spawned: " .. objectName .. " (from button: " .. button.Name .. ")")

		if objectName:find("Door") or objectName:find("door") then
			for _, part in ipairs(newObject:GetDescendants()) do
				if part:IsA("BasePart") then
					part.BrickColor = BrickColor.new("White")
					if part.Material == Enum.Material.Neon then
						part.Material = Enum.Material.SmoothPlastic
					end
				end
			end
		end

		if newObject:IsA("Model") and newObject.PrimaryPart then
			for _, part in ipairs(newObject:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Size = part.Size * 0.95
				end
			end

			for _, part in ipairs(newObject:GetDescendants()) do
				if part:IsA("BasePart") then
					TweenService:Create(part,
						TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{Size = part.Size / 0.95}
					):Play()
				end
			end

			createMinimalParticles(newObject.PrimaryPart.Position)
		end

		for _, descendant in ipairs(newObject:GetDescendants()) do
			if descendant:IsA("Script") then
				descendant.Disabled = false
			end
		end
	end

	local head = button:FindFirstChild("Head")
	if head then
		local originalCFrame = originalButtonStates[button.Name] and originalButtonStates[button.Name].CFrame or head.CFrame

		head.CanCollide = false

		TweenService:Create(head,
			TweenInfo.new(CONFIG.BUTTON_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				CFrame = head.CFrame + Vector3.new(0, 3, 0),
				Transparency = 1
			}
		):Play()

		createMinimalParticles(head.Position)

		task.wait(CONFIG.BUTTON_FADE_TIME)
		if head and head.Parent then
			head.CFrame = originalCFrame
		end
	end

	updateButtonColors(buttons, playerStats)
end

-- Handle BuyObject folder
local buyObject = script.Parent:WaitForChild("BuyObject")
buyObject.ChildAdded:Connect(function(child)
	task.wait(0.1)

	local cost = child:FindFirstChild("Cost")
	local button = child:FindFirstChild("Button")
	local stats = child:FindFirstChild("Stats")

	if cost and button and stats and button.Value and stats.Value then
		processPurchase(button.Value, stats.Value)
	end

	task.wait(10)
	if child.Parent then
		child:Destroy()
	end
end)

-- Handle gamepass purchases
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then return end

	if game:GetService("RunService"):IsStudio() then
		if not _G.StudioGamepassPurchases then
			_G.StudioGamepassPurchases = {}
		end
		local studioKey = tostring(player.UserId) .. "_" .. tostring(gamePassId)
		_G.StudioGamepassPurchases[studioKey] = true
	end

	if gamepassPurchaseRemote then
		gamepassPurchaseRemote:FireClient(player, gamePassId)
	end

	if gamePassId == CONFIG.AUTO_COLLECT_GAMEPASS_ID then
		if script.Parent.Owner.Value == player then
			setupAutoCollect(player)
		end
	elseif gamePassId == CONFIG.DOUBLE_CASH_GAMEPASS_ID then
		setOwnershipCache(player.UserId, CONFIG.DOUBLE_CASH_GAMEPASS_ID, true)

		if script.Parent.Owner.Value == player then
			local giver = essentials:FindFirstChild("Giver")
			if giver then
				update2xCashIndicator(giver, true)
			end
		end
	end

	for _, button in ipairs(buttons:GetChildren()) do
		local gamepass = button:FindFirstChild("Gamepass")
		if gamepass and gamepass.Value == gamePassId then
			local playerStats = ServerStorage.PlayerMoney:FindFirstChild(player.Name)
			if playerStats then
				processPurchase(button, playerStats)
			end
			break
		end
	end
end)

-- Handle dev product purchases
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	for _, button in ipairs(buttons:GetChildren()) do
		local devProduct = button:FindFirstChild("DevProduct")
		if devProduct and devProduct.Value == receiptInfo.ProductId then
			local playerStats = ServerStorage.PlayerMoney:FindFirstChild(player.Name)
			if playerStats then
				processPurchase(button, playerStats)
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Initial setup
local initialOwner = script.Parent.Owner.Value
if initialOwner then
	currentOwner = initialOwner
	local initialStats = ServerStorage.PlayerMoney:FindFirstChild(initialOwner.Name)
	if initialStats then
		task.defer(function()
			updateButtonColors(buttons, initialStats)
		end)
	end
end

print("✅ [Cinnamoroll] Purchase Handler ULTIMATE FIXED loaded with AUTO-COLLECT + 2X CASH!")
print("🔄 [Cinnamoroll] Dependencies now check for spawned objects, not button names")
print("📋 [Cinnamoroll] Properly resets and re-initializes everything")
print("⚡ [Cinnamoroll] INSTANT MODEL DROP COLLECTION for DropperCore compatibility")
print("☁️ [Cinnamoroll] Auto-Collect Gamepass ID:", CONFIG.AUTO_COLLECT_GAMEPASS_ID)
print("💵 [Cinnamoroll] 2x Cash Gamepass ID:", CONFIG.DOUBLE_CASH_GAMEPASS_ID)

-- Debug: Print button dependencies
task.wait(1)
print("\n📋 [Cinnamoroll] Button Dependencies:")
for _, button in ipairs(buttons:GetChildren()) do
	local dep = button:FindFirstChild("Dependency")
	local obj = button:FindFirstChild("Object")
	if dep and dep.Value and dep.Value ~= "" then
		print("  " .. button.Name .. " → waits for object: '" .. dep.Value .. "' | spawns: '" .. (obj and obj.Value or "nothing") .. "'")
	else
		print("  " .. button.Name .. " → no dependency (first button) | spawns: '" .. (obj and obj.Value or "nothing") .. "'")
	end
end
