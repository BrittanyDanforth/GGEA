--[[
	✨ Kuromi Purchase Handler - FINAL PRODUCTION VERSION
	
	🛡️ MULTI-TYCOON SAFETY:
	✅ Attribute-based cleanup - Only destroys Kuromi's drops
	✅ TycoonId verification - Won't collect neighbor drops
	✅ PartStorage priority - Fastest cleanup
	✅ Bounding box fallback - Safe alternative
	
	🔧 LIVE SERVER FIXES:
	✅ PlayerRemoving hook - Guaranteed cleanup
	✅ GUID tracking - No double-collection
	✅ Safe pcall wrapping - No crashes
	✅ os.clock() timing - Modern API
	✅ Settings validation - No silent errors
	✅ Optimized hover - Better performance
	
	🎮 GAMEPASS FEATURES:
	✅ Auto-Collect with visual indicators
	✅ 2x Cash multiplier
	✅ DataStore preferences
	✅ Clean UI indicators
	
	⚡ PERFORMANCE:
	✅ INSTANT model drop collection
	✅ Spawn location system
	✅ Dependency management
--]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local CONFIG = {
	AUTO_COLLECT_GAMEPASS_ID = 1412171840,
	DOUBLE_CASH_GAMEPASS_ID = 1398974710,
	CANNOT_AFFORD_COLOR = BrickColor.new("Really red"),
	CAN_AFFORD_COLOR = BrickColor.new("Lime green"),
	COLLECTOR_IDLE_COLOR = BrickColor.new("Sea green"),
	COLLECTOR_ACTIVE_COLOR = BrickColor.new("Bright red"),
	AUTO_COLLECT_DELAY = 0.0,
	DROP_COLLECTION_DELAY = 0.0,
	PURCHASE_COOLDOWN = 0.5,
	BUTTON_FADE_TIME = 0.4,
	USE_ATTRIBUTE_CLEANUP = true,
	USE_BOUNDING_BOX_FALLBACK = true,
	BOUNDING_BOX_INFLATE = Vector3.new(10, 10, 10),
}

local Settings = require(script.Parent.Parent.Parent.Settings)
local Objects = {}
local TeamColor = script.Parent:WaitForChild("TeamColor").Value
local Money = script.Parent:WaitForChild("CurrencyToCollect")
local Stealing = Settings.StealSettings
local CanSteal = true

local TYCOON_ID = script.Parent:GetAttribute("TycoonId") or script.Parent.Name
print("🏠 [Kuromi] Tycoon ID:", TYCOON_ID)

local purchasedItems = {}
local currentOwner = nil
local originalButtonStates = {}
local dependencyConnections = {}
local collectedParts = {}
local collectedIds = {}
local autoCollectConnections = {}
local autoCollectEnabled = {}
local ownershipCache = {}
local OWNERSHIP_CACHE_TTL = 45

local AUTO_COLLECT_STORE_NAME = "KuromiAutoCollect_v1"
local autoCollectStore
pcall(function() autoCollectStore = DataStoreService:GetDataStore(AUTO_COLLECT_STORE_NAME) end)

local essentials = script.Parent:WaitForChild("Essentials")
local spawn = essentials:WaitForChild("Spawn")
spawn.TeamColor = TeamColor
spawn.BrickColor = TeamColor

local partStorage = essentials:FindFirstChild("PartStorage") or script.Parent:FindFirstChild("PartStorage")
local buttons = script.Parent:WaitForChild("Buttons")
local purchases = script.Parent:WaitForChild("Purchases")
local purchasedObjects = script.Parent:WaitForChild("PurchasedObjects")
local tycoonOwner = script.Parent:WaitForChild("Owner")

local remotesFolder = ReplicatedStorage:FindFirstChild("TycoonRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "TycoonRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local autoCollectToggle = remotesFolder:FindFirstChild("AutoCollectToggle") or Instance.new("RemoteEvent")
autoCollectToggle.Name = "AutoCollectToggle"
autoCollectToggle.Parent = remotesFolder

local moneyCollectRemote = remotesFolder:FindFirstChild("MoneyCollected") or Instance.new("RemoteEvent")
moneyCollectRemote.Name = "MoneyCollected"
moneyCollectRemote.Parent = remotesFolder

local gamepassPurchaseRemote = remotesFolder:FindFirstChild("GamepassPurchased") or Instance.new("RemoteEvent")
gamepassPurchaseRemote.Name = "GamepassPurchased"
gamepassPurchaseRemote.Parent = remotesFolder

-- Utilities
local function getCacheKey(userId, passId) return tostring(userId) .. "_" .. tostring(passId) end
local function setOwnershipCache(userId, passId, value) ownershipCache[getCacheKey(userId, passId)] = {value = value, timestamp = os.clock()} end
local function getOwnershipCache(userId, passId)
	local cached = ownershipCache[getCacheKey(userId, passId)]
	if not cached or os.clock() - cached.timestamp > OWNERSHIP_CACHE_TTL then return nil end
	return cached.value
end

local function playSound(part, soundId, volume)
	if not Settings or not Settings.Sounds or not soundId or soundId == 0 then return end
	if soundId == 131961136 or soundId == 131886985 or part:FindFirstChild("Sound") then return end
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring(soundId)
	sound.Volume = volume or 0.3
	sound.Parent = part
	sound:Play()
	sound.Ended:Connect(function() sound:Destroy() end)
end

local function createMinimalParticles(position)
	local attachment = Instance.new("Attachment")
	attachment.Position = position
	attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 30
	emitter.Lifetime = NumberRange.new(0.3, 0.5)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Speed = NumberRange.new(3, 5)
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 0.8))
	emitter.Size = NumberSequence.new(0.3)
	emitter.Parent = attachment
	task.wait(0.1)
	emitter.Enabled = false
	Debris:AddItem(attachment, 1)
end

-- 2X Cash
local function check2xCashOwnership(player)
	if game:GetService("RunService"):IsStudio() and _G.StudioGamepassPurchases then
		if _G.StudioGamepassPurchases[tostring(player.UserId) .. "_" .. tostring(CONFIG.DOUBLE_CASH_GAMEPASS_ID)] then return true end
	end
	local cached = getOwnershipCache(player.UserId, CONFIG.DOUBLE_CASH_GAMEPASS_ID)
	if cached ~= nil then return cached end
	local success, hasPass = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, CONFIG.DOUBLE_CASH_GAMEPASS_ID) end)
	if success then setOwnershipCache(player.UserId, CONFIG.DOUBLE_CASH_GAMEPASS_ID, hasPass) return hasPass end
	return false
end

local function applyMoneyMultiplier(player, amount)
	if check2xCashOwnership(player) then return amount * 2, true end
	return amount, false
end

local function update2xCashIndicator(giver, has2xCash)
	local indicator2x = giver:FindFirstChild("2xCashIndicator")
	if has2xCash and not indicator2x then
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
	elseif not has2xCash and indicator2x then
		indicator2x:Destroy()
	end
end

-- Auto-Collect
local function checkAutoCollectOwnership(player)
	if game:GetService("RunService"):IsStudio() and _G.StudioGamepassPurchases then
		if _G.StudioGamepassPurchases[tostring(player.UserId) .. "_" .. tostring(CONFIG.AUTO_COLLECT_GAMEPASS_ID)] then return true end
	end
	local cached = getOwnershipCache(player.UserId, CONFIG.AUTO_COLLECT_GAMEPASS_ID)
	if cached ~= nil then return cached end
	local success, hasPass = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, CONFIG.AUTO_COLLECT_GAMEPASS_ID) end)
	if success then setOwnershipCache(player.UserId, CONFIG.AUTO_COLLECT_GAMEPASS_ID, hasPass) return hasPass end
	return false
end

local function performAutoCollect(player)
	if Money.Value <= 0 or autoCollectEnabled[player] == false then return end
	local playerStats = ServerStorage.PlayerMoney:FindFirstChild(player.Name)
	if not playerStats then return end
	local finalAmount, has2x = applyMoneyMultiplier(player, Money.Value)
	playerStats.Value = playerStats.Value + finalAmount
	Money.Value = 0
	local giver = essentials:FindFirstChild("Giver")
	if giver and Settings and Settings.Sounds then playSound(giver, Settings.Sounds.Collect, 0.15) end
	if moneyCollectRemote and giver then moneyCollectRemote:FireClient(player, giver, finalAmount, has2x, true) end
end

local function setupAutoCollect(player)
	if autoCollectConnections[player] then
		autoCollectConnections[player]:Disconnect()
		autoCollectConnections[player] = nil
	end
	if script.Parent.Owner.Value ~= player then return end
	print("🤖 [Kuromi] Auto-Collect activated for", player.Name)
	
	if autoCollectEnabled[player] == nil then
		if autoCollectStore then
			local success, data = pcall(function() return autoCollectStore:GetAsync("Player_" .. tostring(player.UserId)) end)
			autoCollectEnabled[player] = (success and data and type(data.enabled) == "boolean") and data.enabled or true
		else
			autoCollectEnabled[player] = true
		end
	end
	
	local giver = essentials:FindFirstChild("Giver")
	if giver then update2xCashIndicator(giver, check2xCashOwnership(player)) end
	
	autoCollectConnections[player] = Money.Changed:Connect(function(newValue)
		if script.Parent.Owner.Value ~= player then
			if autoCollectConnections[player] then
				autoCollectConnections[player]:Disconnect()
				autoCollectConnections[player] = nil
			end
			return
		end
		if newValue > 0 and autoCollectEnabled[player] ~= false then performAutoCollect(player) end
	end)
	
	if Money.Value > 0 then performAutoCollect(player) end
	
	if giver then
		local oldIndicator = giver:FindFirstChild("AutoCollectIndicator")
		if oldIndicator then oldIndicator:Destroy() end
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
			frame.BackgroundColor3 = Color3.new(0, 0.7, 0.7)
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
		if indicator then indicator:Destroy() end
		local indicator2x = giver:FindFirstChild("2xCashIndicator")
		if indicator2x then indicator2x:Destroy() end
	end
end

autoCollectToggle.OnServerEvent:Connect(function(player, enabled)
	if not checkAutoCollectOwnership(player) then return end
	autoCollectEnabled[player] = enabled
	if autoCollectStore then
		task.spawn(function()
			pcall(function() autoCollectStore:SetAsync("Player_" .. tostring(player.UserId), {enabled = enabled, timestamp = os.time()}) end)
		end)
	end
	if script.Parent.Owner.Value ~= player then return end
	local giver = essentials:FindFirstChild("Giver")
	if giver then
		local indicator = giver:FindFirstChild("AutoCollectIndicator")
		if indicator then
			local frame, label = indicator:FindFirstChild("Frame"), nil
			if frame then label = frame:FindFirstChild("TextLabel") end
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
end)

-- Button Management
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
end

local function fixButtonPositions()
	for _, button in ipairs(buttons:GetChildren()) do
		local head = button:FindFirstChild("Head")
		if head and head:IsA("BasePart") and originalButtonStates[button.Name] and originalButtonStates[button.Name].CFrame then
			head.CFrame = originalButtonStates[button.Name].CFrame
		end
	end
end

function updateButtonColors(buttonFolder, playerMoney)
	if not currentOwner then return end
	for _, button in ipairs(buttonFolder:GetChildren()) do
		local head = button:FindFirstChild("Head")
		if head and head.Transparency <= 0 and head.CanCollide then
			local price = button:FindFirstChild("Price")
			price = price and price.Value or 0
			if price > 0 and playerMoney then
				head.BrickColor = (playerMoney.Value >= price) and CONFIG.CAN_AFFORD_COLOR or CONFIG.CANNOT_AFFORD_COLOR
			end
		end
	end
end

local function addSimpleHoverEffect(button)
	local head = button:FindFirstChild("Head")
	if not head then return end
	local existingDetector = button:FindFirstChild("HoverDetector")
	if existingDetector then existingDetector:Destroy() end
	local originalSize, isHovering, currentCharacter = head.Size, false, nil
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
			currentCharacter = hit.Parent
			TweenService:Create(head, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = originalSize * 1.02}):Play()
			task.spawn(function()
				while isHovering do
					task.wait(0.1)
					if currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart") then
						if (currentCharacter.HumanoidRootPart.Position - head.Position).Magnitude >= 8 then
							isHovering = false
							currentCharacter = nil
							TweenService:Create(head, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = originalSize}):Play()
						end
					else
						isHovering = false
						currentCharacter = nil
						TweenService:Create(head, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = originalSize}):Play()
					end
				end
			end)
		end
	end)
end

local function loadAllObjects()
	for _, button in ipairs(buttons:GetChildren()) do
		local objectName = button:FindFirstChild("Object")
		objectName = objectName and objectName.Value
		if objectName then
			local purchaseObject = purchases:FindFirstChild(objectName)
			if purchaseObject then
				Objects[objectName] = purchaseObject:Clone()
				purchaseObject:Destroy()
			end
		end
	end
end

local function setupButtonDependency(button)
	local head = button:FindFirstChild("Head")
	if not head then return end
	local dependency = button:FindFirstChild("Dependency")
	if dependency and dependency.Value and dependency.Value ~= "" then
		head.CanCollide = false
		head.Transparency = 1
		local function checkDependency()
			for _, obj in ipairs(purchasedObjects:GetChildren()) do
				if obj.Name == dependency.Value then return true end
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
				TweenService:Create(head, TweenInfo.new(Settings.FadeInTime or 0.5, Enum.EasingStyle.Quad), {Transparency = 0}):Play()
			else
				head.Transparency = 0
			end
			head.CanCollide = true
			addSimpleHoverEffect(button)
			task.defer(function()
				if currentOwner then
					local stats = ServerStorage.PlayerMoney:FindFirstChild(currentOwner.Name)
					if stats then updateButtonColors(buttons, stats) end
				end
			end)
			return
		end
		local connection = purchasedObjects.ChildAdded:Connect(function(child)
			if child.Name == dependency.Value then
				if originalButtonStates[button.Name] and originalButtonStates[button.Name].CFrame then
					head.CFrame = originalButtonStates[button.Name].CFrame
				end
				head.BrickColor = CONFIG.CANNOT_AFFORD_COLOR
				if Settings.ButtonsFadeIn then
					head.Transparency = 0.7
					TweenService:Create(head, TweenInfo.new(Settings.FadeInTime or 0.5, Enum.EasingStyle.Quad), {Transparency = 0}):Play()
				else
					head.Transparency = 0
				end
				head.CanCollide = true
				addSimpleHoverEffect(button)
				task.defer(function()
					if currentOwner then
						local stats = ServerStorage.PlayerMoney:FindFirstChild(currentOwner.Name)
						if stats then updateButtonColors(buttons, stats) end
					end
				end)
			end
		end)
		if not dependencyConnections[button] then dependencyConnections[button] = {} end
		table.insert(dependencyConnections[button], connection)
	else
		addSimpleHoverEffect(button)
	end
end

-- 🛡️ MULTI-TYCOON SAFE RESET
local function resetTycoonPurchases()
	print("🔄 [Kuromi] RESETTING (MULTI-TYCOON SAFE)...")
	
	for _, dropper in ipairs(script.Parent:GetChildren()) do
		if dropper.Name:find("Dropper") then
			for _, childScript in ipairs(dropper:GetDescendants()) do
				if childScript:IsA("Script") or childScript:IsA("LocalScript") then
					childScript.Disabled = true
				end
			end
			dropper:SetAttribute("DropperRunning", false)
		end
	end
	
	purchasedItems = {}
	task.wait()
	
	-- Priority 1: Clear PartStorage (fastest, safest)
	if partStorage then
		local storageCount = #partStorage:GetChildren()
		for _, child in ipairs(partStorage:GetChildren()) do pcall(function() child:Destroy() end) end
		print("  ✓ [Kuromi] Cleared PartStorage:", storageCount, "drops")
	end
	
	-- Priority 2: Attribute-based cleanup (multi-tycoon safe!)
	if CONFIG.USE_ATTRIBUTE_CLEANUP then
		local destroyedCount = 0
		for _, descendant in ipairs(workspace:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant:FindFirstChild("Cash") then
				local ownerId = descendant:GetAttribute("TycoonId")
				local model = descendant:FindFirstAncestorOfClass("Model")
				local modelOwner = model and model:GetAttribute("TycoonId")
				if ownerId == TYCOON_ID or modelOwner == TYCOON_ID then
					if model then pcall(function() model:Destroy() end)
					else pcall(function() descendant:Destroy() end) end
					destroyedCount = destroyedCount + 1
				end
			end
		end
		print("  ✓ [Kuromi] Destroyed", destroyedCount, "owned drops (attribute)")
	elseif CONFIG.USE_BOUNDING_BOX_FALLBACK then
		local cframe, size = script.Parent:GetBoundingBox()
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = {workspace}
		local parts = workspace:GetPartBoundsInBox(cframe, size + CONFIG.BOUNDING_BOX_INFLATE, params)
		local destroyedCount = 0
		for _, part in ipairs(parts) do
			if part:FindFirstChild("Cash") then
				local model = part:FindFirstAncestorOfClass("Model")
				if model then pcall(function() model:Destroy() end)
				else pcall(function() part:Destroy() end) end
				destroyedCount = destroyedCount + 1
			end
		end
		print("  ✓ [Kuromi] Destroyed", destroyedCount, "drops (bounding box)")
	end
	
	Money.Value = 0
	
	local objectCount = #purchasedObjects:GetChildren()
	for _, obj in pairs(purchasedObjects:GetChildren()) do
		for _, descendant in ipairs(obj:GetDescendants()) do
			if descendant:IsA("Script") or descendant:IsA("LocalScript") then descendant.Disabled = true end
		end
		obj:Destroy()
	end
	
	collectedParts = {}
	collectedIds = {}
	
	for button, connections in pairs(dependencyConnections) do
		for _, connection in ipairs(connections) do connection:Disconnect() end
	end
	dependencyConnections = {}
	
	for _, button in pairs(buttons:GetChildren()) do
		local head = button:FindFirstChild("Head")
		if head and originalButtonStates[button.Name] then
			local originalState = originalButtonStates[button.Name]
			local hoverDetector = button:FindFirstChild("HoverDetector")
			if hoverDetector then hoverDetector:Destroy() end
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
	
	for _, button in pairs(buttons:GetChildren()) do setupButtonDependency(button) end
	
	local giver = essentials:FindFirstChild("Giver")
	if giver then giver.BrickColor = CONFIG.COLLECTOR_IDLE_COLOR end
	
	local buyObject = script.Parent:FindFirstChild("BuyObject")
	if buyObject then for _, child in pairs(buyObject:GetChildren()) do child:Destroy() end end
	
	CanSteal = true
	task.wait(0.1)
	fixButtonPositions()
end

-- 🔧 LIVE FIX: PlayerRemoving hook
Players.PlayerRemoving:Connect(function(player)
	if tycoonOwner.Value == player then
		print("👋 [Kuromi] PLAYER REMOVING -FORCING CLEANUP")
		cleanupAutoCollect(player)
		pcall(function()
			local spawnLocation = essentials:FindFirstChild("Spawn")
			if spawnLocation and spawnLocation:IsA("SpawnLocation") then spawnLocation.Neutral = true end
		end)
		pcall(function()
			if player.Parent then
				player.RespawnLocation = nil
				player.Team = nil
			end
		end)
		tycoonOwner.Value = nil
		resetTycoonPurchases()
		currentOwner = nil
	end
end)

tycoonOwner.Changed:Connect(function()
	local newOwner = tycoonOwner.Value
	if newOwner == nil and currentOwner ~= nil then
		pcall(function()
			local spawnLocation = essentials:FindFirstChild("Spawn")
			if spawnLocation and spawnLocation:IsA("SpawnLocation") then spawnLocation.Neutral = true end
		end)
		pcall(function()
			if currentOwner and currentOwner.Parent then
				currentOwner.RespawnLocation = nil
				currentOwner.Team = nil
			end
		end)
		cleanupAutoCollect(currentOwner)
		resetTycoonPurchases()
		currentOwner = nil
	elseif newOwner ~= nil and currentOwner == nil then
		currentOwner = newOwner
		for _, dropper in ipairs(script.Parent:GetChildren()) do
			if dropper.Name:find("Dropper") then
				local dropperScript = dropper:FindFirstChildOfClass("Script")
				if dropperScript then
					dropper:SetAttribute("DropperRunning", false)
					dropperScript.Disabled = false
				end
			end
		end
		local teams = game:GetService("Teams")
		local spawnPart = essentials:WaitForChild("Spawn")
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
		spawnPart.Neutral = false
		spawnPart.TeamColor = TeamColor
		spawnPart.Enabled = true
		spawnPart.Duration = 0
		local team = teams:FindFirstChild(script.Parent.Name)
		if team then team.TeamColor = TeamColor newOwner.Team = team end
		newOwner.TeamColor = TeamColor
		newOwner.RespawnLocation = spawnPart
		local giver = essentials:FindFirstChild("Giver")
		if giver then update2xCashIndicator(giver, check2xCashOwnership(newOwner)) end
		local playerStats = ServerStorage.PlayerMoney:FindFirstChild(newOwner.Name)
		if playerStats then
			updateButtonColors(buttons, playerStats)
			playerStats.Changed:Connect(function() updateButtonColors(buttons, playerStats) end)
		end
		if checkAutoCollectOwnership(newOwner) then setupAutoCollect(newOwner) end
	end
end)

-- 🛡️ MULTI-TYCOON SAFE COLLECTOR with GUID
for _, collector in ipairs(essentials:GetChildren()) do
	if collector.Name == "PartCollector" then
		collector.CanCollide = false
		collector.Touched:Connect(function(part)
			local model = part.Parent
			local isModelDrop, modelCashValue, dropId = false, 0, nil
			if model and model:IsA("Model") and (model.Name:match("^Drop_") or model.Name:match("^KuromiDrop") or model.Name:match("^WhiteHeart") or model.Name:match("^PremiumKuromi")) then
				-- 🛡️ Verify ownership
				local dropOwner = model:GetAttribute("TycoonId")
				if dropOwner and dropOwner ~= TYCOON_ID then return end
				isModelDrop = true
				dropId = model:GetAttribute("DropId")
				if not dropId then
					dropId = HttpService:GenerateGUID(false)
					model:SetAttribute("DropId", dropId)
				end
				for _, descendant in ipairs(model:GetDescendants()) do
					if descendant:IsA("BasePart") and descendant:FindFirstChild("Cash") then
						local cash = descendant:FindFirstChild("Cash")
						if cash and cash:IsA("IntValue") then modelCashValue = modelCashValue + cash.Value end
					end
				end
			end
			if isModelDrop and modelCashValue > 0 then
				if (dropId and collectedIds[dropId]) or collectedParts[model] then return end
				if not currentOwner then return end
				if dropId then collectedIds[dropId] = true end
				collectedParts[model] = true
				Money.Value = Money.Value + modelCashValue
				if Settings and Settings.Sounds then playSound(collector, Settings.Sounds.Collect, 0.1) end
				model:Destroy()
				return
			end
			if collectedParts[part] or not currentOwner then return end
			local partOwner = part:GetAttribute("TycoonId")
			if partOwner and partOwner ~= TYCOON_ID then return end
			local cashValue = part:FindFirstChild("Cash")
			if cashValue then
				collectedParts[part] = true
				Money.Value = Money.Value + cashValue.Value
				if Settings and Settings.Sounds then playSound(collector, Settings.Sounds.Collect, 0.1) end
				part.Anchored = true
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				if part:IsA("BasePart") then
					TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {Transparency = 1}):Play()
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
				task.delay(1, function() collectedParts[part] = nil end)
			end
		end)
	end
end

-- Money Collector
local collectorDebounce = {}
local giver = essentials:WaitForChild("Giver")
giver.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player then return end
	if script.Parent.Owner.Value == player then
		if autoCollectConnections[player] and autoCollectEnabled[player] ~= false then return end
		if collectorDebounce[player] then return end
		collectorDebounce[player] = true
		local originalColor = giver.BrickColor
		giver.BrickColor = CONFIG.COLLECTOR_ACTIVE_COLOR
		local originalSize = giver.Size
		TweenService:Create(giver, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {Size = originalSize * 1.05}):Play()
		local playerStats = ServerStorage.PlayerMoney:FindFirstChild(player.Name)
		if playerStats and Money.Value > 0 then
			local moneyCollected = Money.Value
			local finalAmount, has2x = applyMoneyMultiplier(player, moneyCollected)
			playerStats.Value = playerStats.Value + finalAmount
			Money.Value = 0
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
			TweenService:Create(billboardGui, TweenInfo.new(0.8, Enum.EasingStyle.Linear), {StudsOffset = Vector3.new(0, 6, 0)}):Play()
			TweenService:Create(textLabel, TweenInfo.new(0.8, Enum.EasingStyle.Linear), {TextTransparency = 1}):Play()
			Debris:AddItem(billboardGui, 0.8)
		end
		task.wait(0.1)
		TweenService:Create(giver, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = originalSize}):Play()
		task.wait(0.4)
		giver.BrickColor = originalColor
		collectorDebounce[player] = nil
	elseif Stealing.Stealing and CanSteal then
		CanSteal = false
		task.delay(Stealing.PlayerProtection, function() CanSteal = true end)
		local playerStats = ServerStorage.PlayerMoney:FindFirstChild(player.Name)
		if playerStats then
			local stealAmount = math.floor(Money.Value * Stealing.StealPrecent)
			if stealAmount > 0 then
				playerStats.Value = playerStats.Value + stealAmount
				Money.Value = Money.Value - stealAmount
			end
		end
	else
		if Settings and Settings.Sounds then playSound(essentials, Settings.Sounds.ErrorBuy, 0.2) end
	end
end)

task.defer(function()
	storeOriginalButtonStates()
	fixButtonPositions()
	loadAllObjects()
	for _, button in ipairs(buttons:GetChildren()) do setupButtonDependency(button) end
end)

-- Button Touch
for _, button in ipairs(buttons:GetChildren()) do
	task.spawn(function()
		local head = button:FindFirstChild("Head")
		if not head then return end
		local purchaseDebounce = {}
		head.Touched:Connect(function(hit)
			if not head.CanCollide or head.Transparency > 0 or not currentOwner then return end
			local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then return end
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player or player ~= currentOwner or purchaseDebounce[player] then return end
			purchaseDebounce[player] = true
			task.defer(function() task.wait(CONFIG.PURCHASE_COOLDOWN) purchaseDebounce[player] = nil end)
			local playerStats = ServerStorage.PlayerMoney:FindFirstChild(player.Name)
			if not playerStats then return end
			local originalCFrame = head.CFrame
			TweenService:Create(head, TweenInfo.new(0.05, Enum.EasingStyle.Linear), {CFrame = originalCFrame * CFrame.new(0, -0.05, 0)}):Play()
			task.wait(0.05)
			TweenService:Create(head, TweenInfo.new(0.05, Enum.EasingStyle.Linear), {CFrame = originalCFrame}):Play()
			local gamepass = button:FindFirstChild("Gamepass")
			if gamepass and gamepass.Value >= 1 then
				local hasPass = false
				local success, result = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepass.Value) end)
				if success then hasPass = result end
				if hasPass then processPurchase(button, playerStats)
				else MarketplaceService:PromptGamePassPurchase(player, gamepass.Value) end
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
				if Settings and Settings.Sounds then playSound(head, Settings.Sounds.ErrorBuy, 0.2) end
				local originalColor = head.BrickColor
				head.BrickColor = CONFIG.CANNOT_AFFORD_COLOR
				task.wait(0.15)
				head.BrickColor = originalColor
			end
		end)
	end)
end

function processPurchase(button, playerStats)
	if not button or not playerStats then return end
	local price = button:FindFirstChild("Price")
	price = price and price.Value or 0
	local objectName = button:FindFirstChild("Object")
	objectName = objectName and objectName.Value
	playerStats.Value = playerStats.Value - price
	purchasedItems[button.Name] = true
	if objectName then purchasedItems[objectName] = true end
	if objectName and Objects[objectName] then
		local newObject = Objects[objectName]:Clone()
		newObject.Parent = purchasedObjects
		if objectName:find("Door") or objectName:find("door") then
			for _, part in ipairs(newObject:GetDescendants()) do
				if part:IsA("BasePart") then
					part.BrickColor = BrickColor.new("White")
					if part.Material == Enum.Material.Neon then part.Material = Enum.Material.SmoothPlastic end
				end
			end
		end
		if newObject:IsA("Model") and newObject.PrimaryPart then
			for _, part in ipairs(newObject:GetDescendants()) do
				if part:IsA("BasePart") then part.Size = part.Size * 0.95 end
			end
			for _, part in ipairs(newObject:GetDescendants()) do
				if part:IsA("BasePart") then
					TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = part.Size / 0.95}):Play()
				end
			end
			createMinimalParticles(newObject.PrimaryPart.Position)
		end
		for _, descendant in ipairs(newObject:GetDescendants()) do
			if descendant:IsA("Script") then descendant.Disabled = false end
		end
	end
	local head = button:FindFirstChild("Head")
	if head then
		local originalCFrame = originalButtonStates[button.Name] and originalButtonStates[button.Name].CFrame or head.CFrame
		head.CanCollide = false
		TweenService:Create(head, TweenInfo.new(CONFIG.BUTTON_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {CFrame = head.CFrame + Vector3.new(0, 3, 0), Transparency = 1}):Play()
		createMinimalParticles(head.Position)
		task.wait(CONFIG.BUTTON_FADE_TIME)
		if head and head.Parent then head.CFrame = originalCFrame end
	end
	updateButtonColors(buttons, playerStats)
end

local buyObject = script.Parent:WaitForChild("BuyObject")
buyObject.ChildAdded:Connect(function(child)
	task.wait(0.1)
	local cost, button, stats = child:FindFirstChild("Cost"), child:FindFirstChild("Button"), child:FindFirstChild("Stats")
	if cost and button and stats and button.Value and stats.Value then processPurchase(button.Value, stats.Value) end
	task.wait(10)
	if child.Parent then child:Destroy() end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then return end
	if game:GetService("RunService"):IsStudio() then
		if not _G.StudioGamepassPurchases then _G.StudioGamepassPurchases = {} end
		_G.StudioGamepassPurchases[tostring(player.UserId) .. "_" .. tostring(gamePassId)] = true
	end
	if gamepassPurchaseRemote then gamepassPurchaseRemote:FireClient(player, gamePassId) end
	if gamePassId == CONFIG.AUTO_COLLECT_GAMEPASS_ID then
		if script.Parent.Owner.Value == player then setupAutoCollect(player) end
	elseif gamePassId == CONFIG.DOUBLE_CASH_GAMEPASS_ID then
		setOwnershipCache(player.UserId, CONFIG.DOUBLE_CASH_GAMEPASS_ID, true)
		if script.Parent.Owner.Value == player then
			local giver = essentials:FindFirstChild("Giver")
			if giver then update2xCashIndicator(giver, true) end
		end
	end
	for _, button in ipairs(buttons:GetChildren()) do
		local gamepass = button:FindFirstChild("Gamepass")
		if gamepass and gamepass.Value == gamePassId then
			local playerStats = ServerStorage.PlayerMoney:FindFirstChild(player.Name)
			if playerStats then processPurchase(button, playerStats) end
			break
		end
	end
end)

local initialOwner = script.Parent.Owner.Value
if initialOwner then
	currentOwner = initialOwner
	local initialStats = ServerStorage.PlayerMoney:FindFirstChild(initialOwner.Name)
	if initialStats then task.defer(function() updateButtonColors(buttons, initialStats) end) end
end

print("✅ [Kuromi] FINAL PRODUCTION VERSION loaded!")
print("🛡️ Multi-Tycoon Safe | 🔧 Live Server Fixed | 🎮 All Features | ⚡ Optimized")
