--[[
	✨ Cinnamoroll Purchase Handler - FINAL PRODUCTION VERSION
	🛡️ Multi-Tycoon Safe | 🔧 Live Server Fixed | 🎮 All Features | ⚡ Optimized
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
	COLLECTOR_IDLE_COLOR = BrickColor.new("Cyan"),
	COLLECTOR_ACTIVE_COLOR = BrickColor.new("Bright red"),
	PURCHASE_COOLDOWN = 0.5,
	BUTTON_FADE_TIME = 0.4,
	USE_ATTRIBUTE_CLEANUP = true,
	USE_BOUNDING_BOX_FALLBACK = true,
	BOUNDING_BOX_INFLATE = Vector3.new(10, 10, 10),
}

local Settings = require(script.Parent.Parent.Parent.Settings)
local Objects, purchasedItems, currentOwner = {}, {}, nil
local TeamColor = script.Parent:WaitForChild("TeamColor").Value
local Money = script.Parent:WaitForChild("CurrencyToCollect")
local Stealing, CanSteal = Settings.StealSettings, true

local TYCOON_ID = script.Parent:GetAttribute("TycoonId") or script.Parent.Name
print("🏠 [Cinnamoroll] Tycoon ID:", TYCOON_ID)

local originalButtonStates, dependencyConnections = {}, {}
local collectedParts, collectedIds = {}, {}
local autoCollectConnections, autoCollectEnabled = {}, {}
local ownershipCache = {}
local OWNERSHIP_CACHE_TTL = 45

local AUTO_COLLECT_STORE_NAME = "CinnamorollAutoCollect_v1"
local autoCollectStore
pcall(function() autoCollectStore = DataStoreService:GetDataStore(AUTO_COLLECT_STORE_NAME) end)

local essentials = script.Parent:WaitForChild("Essentials")
local spawn = essentials:WaitForChild("Spawn")
spawn.TeamColor, spawn.BrickColor = TeamColor, TeamColor

local partStorage = essentials:FindFirstChild("PartStorage") or script.Parent:FindFirstChild("PartStorage")
local buttons = script.Parent:WaitForChild("Buttons")
local purchases = script.Parent:WaitForChild("Purchases")
local purchasedObjects = script.Parent:WaitForChild("PurchasedObjects")
local tycoonOwner = script.Parent:WaitForChild("Owner")

local remotesFolder = ReplicatedStorage:FindFirstChild("TycoonRemotes")
if not remotesFolder then remotesFolder = Instance.new("Folder") remotesFolder.Name = "TycoonRemotes" remotesFolder.Parent = ReplicatedStorage end
local autoCollectToggle = remotesFolder:FindFirstChild("AutoCollectToggle") or Instance.new("RemoteEvent")
autoCollectToggle.Name = "AutoCollectToggle" autoCollectToggle.Parent = remotesFolder
local moneyCollectRemote = remotesFolder:FindFirstChild("MoneyCollected") or Instance.new("RemoteEvent")
moneyCollectRemote.Name = "MoneyCollected" moneyCollectRemote.Parent = remotesFolder
local gamepassPurchaseRemote = remotesFolder:FindFirstChild("GamepassPurchased") or Instance.new("RemoteEvent")
gamepassPurchaseRemote.Name = "GamepassPurchased" gamepassPurchaseRemote.Parent = remotesFolder

local function getCacheKey(userId, passId) return tostring(userId) .. "_" .. tostring(passId) end
local function setOwnershipCache(userId, passId, value) ownershipCache[getCacheKey(userId, passId)] = {value = value, timestamp = os.clock()} end
local function getOwnershipCache(userId, passId)
	local cached = ownershipCache[getCacheKey(userId, passId)]
	if not cached or os.clock() - cached.timestamp > OWNERSHIP_CACHE_TTL then return nil end
	return cached.value
end

local function playSound(part, soundId, volume)
	if not Settings or not Settings.Sounds or not soundId or soundId == 0 or soundId == 131961136 or soundId == 131886985 or part:FindFirstChild("Sound") then return end
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring(soundId) sound.Volume = volume or 0.3 sound.Parent = part sound:Play()
	sound.Ended:Connect(function() sound:Destroy() end)
end

local function createMinimalParticles(position)
	local attachment = Instance.new("Attachment")
	attachment.Position = position attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate, emitter.Lifetime = 30, NumberRange.new(0.3, 0.5)
	emitter.EmissionDirection, emitter.Speed = Enum.NormalId.Top, NumberRange.new(3, 5)
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.Color = ColorSequence.new(Color3.fromRGB(180, 210, 235))
	emitter.Size = NumberSequence.new(0.3)
	emitter.Parent = attachment
	task.wait(0.1) emitter.Enabled = false Debris:AddItem(attachment, 1)
end

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
		local bb = Instance.new("BillboardGui") bb.Name = "2xCashIndicator" bb.MaxDistance = 100 bb.Size = UDim2.new(3, 0, 1, 0) bb.StudsOffset = Vector3.new(0, 5, 0) bb.AlwaysOnTop = true bb.Parent = giver
		local f = Instance.new("Frame") f.Size = UDim2.new(1, 0, 1, 0) f.BackgroundColor3 = Color3.fromRGB(255, 215, 0) f.BackgroundTransparency = 0.2 f.BorderSizePixel = 0 f.Parent = bb
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0.2, 0) c.Parent = f
		local l = Instance.new("TextLabel") l.Size = UDim2.new(1, 0, 1, 0) l.BackgroundTransparency = 1 l.Text = "2X CASH" l.TextScaled = true l.TextColor3 = Color3.new(1, 1, 1) l.Font = Enum.Font.SourceSansBold l.TextStrokeTransparency = 0 l.TextStrokeColor3 = Color3.new(0, 0, 0) l.Parent = f
	elseif not has2xCash and indicator2x then indicator2x:Destroy() end
end

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
	playerStats.Value, Money.Value = playerStats.Value + finalAmount, 0
	local giver = essentials:FindFirstChild("Giver")
	if giver and Settings and Settings.Sounds then playSound(giver, Settings.Sounds.Collect, 0.15) end
	if moneyCollectRemote and giver then moneyCollectRemote:FireClient(player, giver, finalAmount, has2x, true) end
end

local function setupAutoCollect(player)
	if autoCollectConnections[player] then autoCollectConnections[player]:Disconnect() autoCollectConnections[player] = nil end
	if script.Parent.Owner.Value ~= player then return end
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
			if autoCollectConnections[player] then autoCollectConnections[player]:Disconnect() autoCollectConnections[player] = nil end
			return
		end
		if newValue > 0 and autoCollectEnabled[player] ~= false then performAutoCollect(player) end
	end)
	if Money.Value > 0 then performAutoCollect(player) end
	if giver then
		local oldIndicator = giver:FindFirstChild("AutoCollectIndicator")
		if oldIndicator then oldIndicator:Destroy() end
		local ai = Instance.new("BillboardGui") ai.Name = "AutoCollectIndicator" ai.MaxDistance = 100 ai.Size = UDim2.new(3, 0, 0.8, 0) ai.StudsOffset = Vector3.new(0, 3.5, 0) ai.AlwaysOnTop = true ai.Parent = giver
		local f = Instance.new("Frame") f.Size = UDim2.new(1, 0, 1, 0) f.BorderSizePixel = 0 f.Parent = ai
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0.2, 0) c.Parent = f
		local l = Instance.new("TextLabel") l.Size = UDim2.new(1, 0, 1, 0) l.BackgroundTransparency = 1 l.TextScaled = true l.Font = Enum.Font.SourceSansBold l.TextStrokeTransparency = 0 l.TextStrokeColor3 = Color3.new(0, 0, 0) l.Parent = f
		if autoCollectEnabled[player] ~= false then
			f.BackgroundColor3, f.BackgroundTransparency = Color3.new(0, 0.7, 0.7), 0.2
			l.Text, l.TextColor3 = "AUTO", Color3.new(1, 1, 1)
		else
			f.BackgroundColor3, f.BackgroundTransparency = Color3.new(0.5, 0, 0), 0.2
			l.Text, l.TextColor3 = "AUTO X", Color3.new(1, 0.3, 0.3)
		end
	end
end

local function cleanupAutoCollect(player)
	if autoCollectConnections[player] then autoCollectConnections[player]:Disconnect() autoCollectConnections[player] = nil end
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
	if autoCollectStore then task.spawn(function() pcall(function() autoCollectStore:SetAsync("Player_" .. tostring(player.UserId), {enabled = enabled, timestamp = os.time()}) end) end) end
	if script.Parent.Owner.Value ~= player then return end
	local giver = essentials:FindFirstChild("Giver")
	if giver then
		local indicator = giver:FindFirstChild("AutoCollectIndicator")
		if indicator then
			local frame, label = indicator:FindFirstChild("Frame"), nil
			if frame then label = frame:FindFirstChild("TextLabel") end
			if label then
				if enabled then label.Text = "AUTO" label.TextColor3 = Color3.new(1, 1, 1) frame.BackgroundColor3 = Color3.new(0, 0.7, 0.7)
				else label.Text = "AUTO X" label.TextColor3 = Color3.new(1, 0.3, 0.3) frame.BackgroundColor3 = Color3.new(0.5, 0, 0) end
			end
		end
	end
end)

local function storeOriginalButtonStates()
	for _, button in ipairs(buttons:GetChildren()) do
		local head = button:FindFirstChild("Head")
		if head then originalButtonStates[button.Name] = {Transparency = head.Transparency, CanCollide = head.CanCollide, BrickColor = head.BrickColor, CFrame = head.CFrame} end
	end
end

local function fixButtonPositions()
	for _, button in ipairs(buttons:GetChildren()) do
		local head = button:FindFirstChild("Head")
		if head and head:IsA("BasePart") and originalButtonStates[button.Name] and originalButtonStates[button.Name].CFrame then head.CFrame = originalButtonStates[button.Name].CFrame end
	end
end

function updateButtonColors(buttonFolder, playerMoney)
	if not currentOwner then return end
	for _, button in ipairs(buttonFolder:GetChildren()) do
		local head = button:FindFirstChild("Head")
		if head and head.Transparency <= 0 and head.CanCollide then
			local price = button:FindFirstChild("Price") price = price and price.Value or 0
			if price > 0 and playerMoney then head.BrickColor = (playerMoney.Value >= price) and CONFIG.CAN_AFFORD_COLOR or CONFIG.CANNOT_AFFORD_COLOR end
		end
	end
end

local function addSimpleHoverEffect(button)
	local head = button:FindFirstChild("Head")
	if not head then return end
	local existingDetector = button:FindFirstChild("HoverDetector")
	if existingDetector then existingDetector:Destroy() end
	local originalSize, isHovering, currentCharacter = head.Size, false, nil
	local detector = Instance.new("Part") detector.Name = "HoverDetector" detector.Size = head.Size * 1.3 detector.Transparency = 1 detector.CanCollide = false detector.CFrame = head.CFrame detector.Parent = button
	local weld = Instance.new("WeldConstraint") weld.Part0, weld.Part1, weld.Parent = head, detector, detector
	detector.Touched:Connect(function(hit)
		local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid and not isHovering then
			isHovering, currentCharacter = true, hit.Parent
			TweenService:Create(head, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = originalSize * 1.02}):Play()
			task.spawn(function()
				while isHovering do
					task.wait(0.1)
					if currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart") then
						if (currentCharacter.HumanoidRootPart.Position - head.Position).Magnitude >= 8 then
							isHovering, currentCharacter = false, nil
							TweenService:Create(head, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = originalSize}):Play()
						end
					else
						isHovering, currentCharacter = false, nil
						TweenService:Create(head, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = originalSize}):Play()
					end
				end
			end)
		end
	end)
end

local function loadAllObjects()
	for _, button in ipairs(buttons:GetChildren()) do
		local objectName = button:FindFirstChild("Object") objectName = objectName and objectName.Value
		if objectName then
			local purchaseObject = purchases:FindFirstChild(objectName)
			if purchaseObject then Objects[objectName] = purchaseObject:Clone() purchaseObject:Destroy() end
		end
	end
end

local function setupButtonDependency(button)
	local head = button:FindFirstChild("Head")
	if not head then return end
	local dependency = button:FindFirstChild("Dependency")
	if dependency and dependency.Value and dependency.Value ~= "" then
		head.CanCollide, head.Transparency = false, 1
		local function checkDependency()
			for _, obj in ipairs(purchasedObjects:GetChildren()) do if obj.Name == dependency.Value then return true end end
			return false
		end
		if checkDependency() then
			if originalButtonStates[button.Name] and originalButtonStates[button.Name].CFrame then head.CFrame = originalButtonStates[button.Name].CFrame end
			head.BrickColor = CONFIG.CANNOT_AFFORD_COLOR
			if Settings.ButtonsFadeIn then head.Transparency = 0.7 TweenService:Create(head, TweenInfo.new(Settings.FadeInTime or 0.5, Enum.EasingStyle.Quad), {Transparency = 0}):Play()
			else head.Transparency = 0 end
			head.CanCollide = true addSimpleHoverEffect(button)
			task.defer(function() if currentOwner then local stats = ServerStorage.PlayerMoney:FindFirstChild(currentOwner.Name) if stats then updateButtonColors(buttons, stats) end end end)
			return
		end
		local connection = purchasedObjects.ChildAdded:Connect(function(child)
			if child.Name == dependency.Value then
				if originalButtonStates[button.Name] and originalButtonStates[button.Name].CFrame then head.CFrame = originalButtonStates[button.Name].CFrame end
				head.BrickColor = CONFIG.CANNOT_AFFORD_COLOR
				if Settings.ButtonsFadeIn then head.Transparency = 0.7 TweenService:Create(head, TweenInfo.new(Settings.FadeInTime or 0.5, Enum.EasingStyle.Quad), {Transparency = 0}):Play()
				else head.Transparency = 0 end
				head.CanCollide = true addSimpleHoverEffect(button)
				task.defer(function() if currentOwner then local stats = ServerStorage.PlayerMoney:FindFirstChild(currentOwner.Name) if stats then updateButtonColors(buttons, stats) end end end)
			end
		end)
		if not dependencyConnections[button] then dependencyConnections[button] = {} end
		table.insert(dependencyConnections[button], connection)
	else
		addSimpleHoverEffect(button)
	end
end

local function resetTycoonPurchases()
	for _, dropper in ipairs(script.Parent:GetChildren()) do
		if dropper.Name:find("Dropper") then
			for _, childScript in ipairs(dropper:GetDescendants()) do
				if childScript:IsA("Script") or childScript:IsA("LocalScript") then childScript.Disabled = true end
			end
			dropper:SetAttribute("DropperRunning", false)
		end
	end
	purchasedItems = {} task.wait()
	if partStorage then
		local storageCount = #partStorage:GetChildren()
		for _, child in ipairs(partStorage:GetChildren()) do pcall(function() child:Destroy() end) end
		print("  ✓ [Cinnamoroll] Cleared PartStorage:", storageCount)
	end
	if CONFIG.USE_ATTRIBUTE_CLEANUP then
		local destroyedCount = 0
		for _, descendant in ipairs(workspace:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant:FindFirstChild("Cash") then
				local ownerId = descendant:GetAttribute("TycoonId")
				local model = descendant:FindFirstAncestorOfClass("Model")
				local modelOwner = model and model:GetAttribute("TycoonId")
				if ownerId == TYCOON_ID or modelOwner == TYCOON_ID then
					if model then pcall(function() model:Destroy() end) else pcall(function() descendant:Destroy() end) end
					destroyedCount = destroyedCount + 1
				end
			end
		end
		print("  ✓ [Cinnamoroll] Destroyed", destroyedCount, "owned drops")
	elseif CONFIG.USE_BOUNDING_BOX_FALLBACK then
		local cframe, size = script.Parent:GetBoundingBox()
		local params = OverlapParams.new() params.FilterType = Enum.RaycastFilterType.Include params.FilterDescendantsInstances = {workspace}
		local parts = workspace:GetPartBoundsInBox(cframe, size + CONFIG.BOUNDING_BOX_INFLATE, params)
		local destroyedCount = 0
		for _, part in ipairs(parts) do
			if part:FindFirstChild("Cash") then
				local model = part:FindFirstAncestorOfClass("Model")
				if model then pcall(function() model:Destroy() end) else pcall(function() part:Destroy() end) end
				destroyedCount = destroyedCount + 1
			end
		end
		print("  ✓ [Cinnamoroll] Destroyed", destroyedCount, "drops (box)")
	end
	Money.Value = 0
	for _, obj in pairs(purchasedObjects:GetChildren()) do
		for _, descendant in ipairs(obj:GetDescendants()) do
			if descendant:IsA("Script") or descendant:IsA("LocalScript") then descendant.Disabled = true end
		end
		obj:Destroy()
	end
	collectedParts, collectedIds = {}, {}
	for button, connections in pairs(dependencyConnections) do for _, connection in ipairs(connections) do connection:Disconnect() end end
	dependencyConnections = {}
	for _, button in pairs(buttons:GetChildren()) do
		local head = button:FindFirstChild("Head")
		if head and originalButtonStates[button.Name] then
			local originalState = originalButtonStates[button.Name]
			local hoverDetector = button:FindFirstChild("HoverDetector")
			if hoverDetector then hoverDetector:Destroy() end
			local dependency = button:FindFirstChild("Dependency")
			if dependency and dependency.Value and dependency.Value ~= "" then head.CanCollide, head.Transparency = false, 1
			else head.CanCollide, head.Transparency, head.BrickColor = originalState.CanCollide, originalState.Transparency, CONFIG.CANNOT_AFFORD_COLOR addSimpleHoverEffect(button) end
		end
	end
	for _, button in pairs(buttons:GetChildren()) do setupButtonDependency(button) end
	local giver = essentials:FindFirstChild("Giver")
	if giver then giver.BrickColor = CONFIG.COLLECTOR_IDLE_COLOR end
	local buyObject = script.Parent:FindFirstChild("BuyObject")
	if buyObject then for _, child in pairs(buyObject:GetChildren()) do child:Destroy() end end
	CanSteal = true task.wait(0.1) fixButtonPositions()
end

Players.PlayerRemoving:Connect(function(player)
	if tycoonOwner.Value == player then
		cleanupAutoCollect(player)
		pcall(function() local s = essentials:FindFirstChild("Spawn") if s and s:IsA("SpawnLocation") then s.Neutral = true end end)
		pcall(function() if player.Parent then player.RespawnLocation, player.Team = nil, nil end end)
		tycoonOwner.Value = nil
		resetTycoonPurchases()
		currentOwner = nil
	end
end)

tycoonOwner.Changed:Connect(function()
	local newOwner = tycoonOwner.Value
	if newOwner == nil and currentOwner ~= nil then
		pcall(function() local s = essentials:FindFirstChild("Spawn") if s and s:IsA("SpawnLocation") then s.Neutral = true end end)
		pcall(function() if currentOwner and currentOwner.Parent then currentOwner.RespawnLocation, currentOwner.Team = nil, nil end end)
		cleanupAutoCollect(currentOwner) resetTycoonPurchases() currentOwner = nil
	elseif newOwner ~= nil and currentOwner == nil then
		currentOwner = newOwner
		for _, dropper in ipairs(script.Parent:GetChildren()) do
			if dropper.Name:find("Dropper") then
				local dropperScript = dropper:FindFirstChildOfClass("Script")
				if dropperScript then dropper:SetAttribute("DropperRunning", false) dropperScript.Disabled = false end
			end
		end
		local teams, spawnPart = game:GetService("Teams"), essentials:WaitForChild("Spawn")
		if not spawnPart:IsA("SpawnLocation") then
			local s = Instance.new("SpawnLocation") s.Name, s.Size, s.CFrame, s.Anchored, s.CanCollide, s.BrickColor, s.TeamColor, s.Parent = "Spawn", spawnPart.Size, spawnPart.CFrame, true, spawnPart.CanCollide, spawnPart.BrickColor, TeamColor, essentials
			spawnPart:Destroy() spawnPart = s
		end
		spawnPart.Neutral, spawnPart.TeamColor, spawnPart.Enabled, spawnPart.Duration = false, TeamColor, true, 0
		local team = teams:FindFirstChild(script.Parent.Name)
		if team then team.TeamColor = TeamColor newOwner.Team = team end
		newOwner.TeamColor, newOwner.RespawnLocation = TeamColor, spawnPart
		local giver = essentials:FindFirstChild("Giver")
		if giver then update2xCashIndicator(giver, check2xCashOwnership(newOwner)) end
		local playerStats = ServerStorage.PlayerMoney:FindFirstChild(newOwner.Name)
		if playerStats then updateButtonColors(buttons, playerStats) playerStats.Changed:Connect(function() updateButtonColors(buttons, playerStats) end) end
		if checkAutoCollectOwnership(newOwner) then setupAutoCollect(newOwner) end
	end
end)

for _, collector in ipairs(essentials:GetChildren()) do
	if collector.Name == "PartCollector" then
		collector.CanCollide = false
		collector.Touched:Connect(function(part)
			local model = part.Parent
			local isModelDrop, modelCashValue, dropId = false, 0, nil
			if model and model:IsA("Model") and (model.Name:match("^Drop_") or model.Name:match("^Cinnamoroll") or model.Name:match("^IceCream") or model.Name:match("^CinnamonRoll") or model.Name:match("^WhiteHeart")) then
				local dropOwner = model:GetAttribute("TycoonId")
				if dropOwner and dropOwner ~= TYCOON_ID then return end
				isModelDrop = true
				dropId = model:GetAttribute("DropId")
				if not dropId then dropId = HttpService:GenerateGUID(false) model:SetAttribute("DropId", dropId) end
				for _, descendant in ipairs(model:GetDescendants()) do
					if descendant:IsA("BasePart") and descendant:FindFirstChild("Cash") then
						local cash = descendant:FindFirstChild("Cash")
						if cash and cash:IsA("IntValue") then modelCashValue = modelCashValue + cash.Value end
					end
				end
			end
			if isModelDrop and modelCashValue > 0 then
				if (dropId and collectedIds[dropId]) or collectedParts[model] or not currentOwner then return end
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
				part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
				if part:IsA("BasePart") then
					TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {Transparency = 1}):Play()
					for _, child in ipairs(part:GetDescendants()) do
						if child:IsA("Decal") or child:IsA("Texture") then TweenService:Create(child, TweenInfo.new(0.3), {Transparency = 1}):Play()
						elseif child:IsA("ParticleEmitter") then child.Enabled = false
						elseif child:IsA("PointLight") or child:IsA("SpotLight") then TweenService:Create(child, TweenInfo.new(0.3), {Brightness = 0}):Play() end
					end
				end
				task.wait(0.3) part:Destroy()
				task.delay(1, function() collectedParts[part] = nil end)
			end
		end)
	end
end

local collectorDebounce, giver = {}, essentials:WaitForChild("Giver")
giver.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player then return end
	if script.Parent.Owner.Value == player then
		if autoCollectConnections[player] and autoCollectEnabled[player] ~= false then return end
		if collectorDebounce[player] then return end
		collectorDebounce[player] = true
		local originalColor, originalSize = giver.BrickColor, giver.Size
		giver.BrickColor = CONFIG.COLLECTOR_ACTIVE_COLOR
		TweenService:Create(giver, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {Size = originalSize * 1.05}):Play()
		local playerStats = ServerStorage.PlayerMoney:FindFirstChild(player.Name)
		if playerStats and Money.Value > 0 then
			local finalAmount, has2x = applyMoneyMultiplier(player, Money.Value)
			playerStats.Value, Money.Value = playerStats.Value + finalAmount, 0
			local bb = Instance.new("BillboardGui") bb.Size, bb.StudsOffset, bb.Parent = UDim2.new(0, 100, 0, 50), Vector3.new(0, 3, 0), giver
			local tl = Instance.new("TextLabel") tl.Size, tl.BackgroundTransparency, tl.Text, tl.TextScaled, tl.TextColor3, tl.Font, tl.TextStrokeTransparency, tl.Parent = UDim2.new(1, 0, 1, 0), 1, "+$" .. tostring(finalAmount) .. (has2x and " (2X!)" or ""), true, has2x and Color3.fromRGB(255, 215, 0) or Color3.new(0, 1, 0), Enum.Font.SourceSansBold, 0, bb
			TweenService:Create(bb, TweenInfo.new(0.8, Enum.EasingStyle.Linear), {StudsOffset = Vector3.new(0, 6, 0)}):Play()
			TweenService:Create(tl, TweenInfo.new(0.8, Enum.EasingStyle.Linear), {TextTransparency = 1}):Play()
			Debris:AddItem(bb, 0.8)
		end
		task.wait(0.1) TweenService:Create(giver, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = originalSize}):Play()
		task.wait(0.4) giver.BrickColor = originalColor collectorDebounce[player] = nil
	elseif Stealing.Stealing and CanSteal then
		CanSteal = false task.delay(Stealing.PlayerProtection, function() CanSteal = true end)
		local playerStats = ServerStorage.PlayerMoney:FindFirstChild(player.Name)
		if playerStats then
			local stealAmount = math.floor(Money.Value * Stealing.StealPrecent)
			if stealAmount > 0 then playerStats.Value, Money.Value = playerStats.Value + stealAmount, Money.Value - stealAmount end
		end
	else
		if Settings and Settings.Sounds then playSound(essentials, Settings.Sounds.ErrorBuy, 0.2) end
	end
end)

task.defer(function() storeOriginalButtonStates() fixButtonPositions() loadAllObjects() for _, button in ipairs(buttons:GetChildren()) do setupButtonDependency(button) end end)

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
				if hasPass then processPurchase(button, playerStats) else MarketplaceService:PromptGamePassPurchase(player, gamepass.Value) end
				return
			end
			local devProduct = button:FindFirstChild("DevProduct")
			if devProduct and devProduct.Value >= 1 then MarketplaceService:PromptProductPurchase(player, devProduct.Value) return end
			local price = button:FindFirstChild("Price") price = price and price.Value or 0
			if playerStats.Value >= price then processPurchase(button, playerStats)
			else
				if Settings and Settings.Sounds then playSound(head, Settings.Sounds.ErrorBuy, 0.2) end
				local originalColor = head.BrickColor head.BrickColor = CONFIG.CANNOT_AFFORD_COLOR task.wait(0.15) head.BrickColor = originalColor
			end
		end)
	end)
end

function processPurchase(button, playerStats)
	if not button or not playerStats then return end
	local price = button:FindFirstChild("Price") price = price and price.Value or 0
	local objectName = button:FindFirstChild("Object") objectName = objectName and objectName.Value
	playerStats.Value = playerStats.Value - price
	purchasedItems[button.Name] = true
	if objectName then purchasedItems[objectName] = true end
	if objectName and Objects[objectName] then
		local newObject = Objects[objectName]:Clone()
		newObject.Parent = purchasedObjects
		if objectName:find("Door") or objectName:find("door") then
			for _, part in ipairs(newObject:GetDescendants()) do
				if part:IsA("BasePart") then part.BrickColor = BrickColor.new("White") if part.Material == Enum.Material.Neon then part.Material = Enum.Material.SmoothPlastic end end
			end
		end
		if newObject:IsA("Model") and newObject.PrimaryPart then
			for _, part in ipairs(newObject:GetDescendants()) do if part:IsA("BasePart") then part.Size = part.Size * 0.95 end end
			for _, part in ipairs(newObject:GetDescendants()) do if part:IsA("BasePart") then TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = part.Size / 0.95}):Play() end end
			createMinimalParticles(newObject.PrimaryPart.Position)
		end
		for _, descendant in ipairs(newObject:GetDescendants()) do if descendant:IsA("Script") then descendant.Disabled = false end end
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
	task.wait(10) if child.Parent then child:Destroy() end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then return end
	if game:GetService("RunService"):IsStudio() then
		if not _G.StudioGamepassPurchases then _G.StudioGamepassPurchases = {} end
		_G.StudioGamepassPurchases[tostring(player.UserId) .. "_" .. tostring(gamePassId)] = true
	end
	if gamepassPurchaseRemote then gamepassPurchaseRemote:FireClient(player, gamePassId) end
	if gamePassId == CONFIG.AUTO_COLLECT_GAMEPASS_ID and script.Parent.Owner.Value == player then setupAutoCollect(player)
	elseif gamePassId == CONFIG.DOUBLE_CASH_GAMEPASS_ID then
		setOwnershipCache(player.UserId, CONFIG.DOUBLE_CASH_GAMEPASS_ID, true)
		if script.Parent.Owner.Value == player then local g = essentials:FindFirstChild("Giver") if g then update2xCashIndicator(g, true) end end
	end
	for _, b in ipairs(buttons:GetChildren()) do
		local gp = b:FindFirstChild("Gamepass")
		if gp and gp.Value == gamePassId then
			local ps = ServerStorage.PlayerMoney:FindFirstChild(player.Name)
			if ps then processPurchase(b, ps) end
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

print("✅ [Cinnamoroll] FINAL PRODUCTION VERSION loaded!")
print("🛡️ Multi-Tycoon Safe | 🔧 Live Server Fixed | 🎮 All Features | ⚡ Optimized")
