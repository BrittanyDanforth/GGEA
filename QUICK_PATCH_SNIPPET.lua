--[[
	🔧 QUICK PATCH SNIPPET - Copy/Paste into existing handlers
	
	INSTRUCTIONS:
	1. Add these lines at the TOP of your script (after service declarations)
	2. Add the PlayerRemoving hook AFTER your Owner.Changed connection
	3. Replace your resetTycoonPurchases() function with the fixed version
	4. Update your collector Touched handler with GUID tracking
	
	Then test in LIVE server!
]]

-- ========================================
-- 1️⃣ ADD TO TOP OF SCRIPT (after game:GetService lines)
-- ========================================
local HttpService = game:GetService("HttpService")

-- GUID tracking for double-collection prevention
local collectedIds = {}

-- Cache PartStorage for cleanup (CRITICAL for live servers!)
local partStorage = essentials:FindFirstChild("PartStorage") or script.Parent:FindFirstChild("PartStorage")

-- Cleanup radius
local CLEANUP_RADIUS = 120


-- ========================================
-- 2️⃣ ADD PLAYERREMOVING HOOK (paste AFTER tycoonOwner.Changed:Connect)
-- ========================================
Players.PlayerRemoving:Connect(function(player)
	if tycoonOwner.Value == player then
		print("👋 [LIVE FIX] PLAYER REMOVING:", player.Name, "- FORCING CLEANUP")
		
		-- Cleanup auto-collect
		cleanupAutoCollect(player)
		
		-- Release spawn (safe with pcall)
		pcall(function()
			local spawnLocation = essentials:FindFirstChild("Spawn")
			if spawnLocation and spawnLocation:IsA("SpawnLocation") then
				spawnLocation.Neutral = true
			end
		end)
		
		-- Safe player property cleanup
		pcall(function()
			if player.Parent then
				player.RespawnLocation = nil
				player.Team = nil
			end
		end)
		
		-- Clear owner FIRST
		tycoonOwner.Value = nil
		
		-- Full reset
		resetTycoonPurchases()
		currentOwner = nil
	end
end)


-- ========================================
-- 3️⃣ REPLACE YOUR resetTycoonPurchases() WITH THIS
-- ========================================
local function resetTycoonPurchases()
	print("🔄 [LIVE FIX] RESETTING PURCHASE HANDLER...")

	-- Stop all droppers
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

	-- 🔧 LIVE FIX: Wait for physics to settle
	task.wait()

	-- 🔧 LIVE FIX: Clear PartStorage (where DropperCore puts drops!)
	if partStorage then
		local storageCount = #partStorage:GetChildren()
		for _, child in ipairs(partStorage:GetChildren()) do
			pcall(function() child:Destroy() end)
		end
		print("  ✓ [LIVE FIX] Cleared PartStorage:", storageCount, "drops")
	end

	-- 🔧 LIVE FIX: Use GetDescendants() to find ALL drops
	local destroyedCount = 0
	local tycoonPosition = script.Parent:GetPivot().Position

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local cash = descendant:FindFirstChild("Cash")
			if cash and cash:IsA("IntValue") then
				local distance = (descendant.Position - tycoonPosition).Magnitude
				if distance < CLEANUP_RADIUS then
					local rootModel = descendant:FindFirstAncestorOfClass("Model")
					if rootModel then
						pcall(function() rootModel:Destroy() end)
					else
						pcall(function() descendant:Destroy() end)
					end
					destroyedCount = destroyedCount + 1
				end
			end
		end
	end

	print("  ✓ [LIVE FIX] Destroyed", destroyedCount, "cash drops")

	Money.Value = 0

	-- Destroy purchased objects
	local objectCount = #purchasedObjects:GetChildren()
	for _, obj in pairs(purchasedObjects:GetChildren()) do
		for _, descendant in ipairs(obj:GetDescendants()) do
			if descendant:IsA("Script") or descendant:IsA("LocalScript") then
				descendant.Disabled = true
			end
		end
		obj:Destroy()
	end
	print("  ✓ Destroyed", objectCount, "purchased objects")

	-- 🔧 LIVE FIX: Clear GUID tracking
	collectedParts = {}
	collectedIds = {}

	-- Disconnect dependencies
	for button, connections in pairs(dependencyConnections) do
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end
	dependencyConnections = {}

	-- Reset buttons
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
				head.BrickColor = BrickColor.new("Really red")
				addSimpleHoverEffect(button)
			end
		end
	end

	for _, button in pairs(buttons:GetChildren()) do
		setupButtonDependency(button)
	end

	local giver = essentials:FindFirstChild("Giver")
	if giver then
		giver.BrickColor = BrickColor.new("Sea green")
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

	print("✅ [LIVE FIX] Purchase handler fully reset!")
end


-- ========================================
-- 4️⃣ UPDATE YOUR COLLECTOR - Find the collector.Touched handler and ADD GUID TRACKING
-- ========================================
-- FIND THIS SECTION IN YOUR SCRIPT:
-- for _, collector in ipairs(essentials:GetChildren()) do
--     if collector.Name == "PartCollector" then
--         collector.Touched:Connect(function(part)

-- REPLACE THE MODEL DROP HANDLING WITH THIS:

collector.Touched:Connect(function(part)
	local model = part.Parent
	local isModelDrop = false
	local modelCashValue = 0
	local dropId = nil  -- 🔧 LIVE FIX: GUID tracking

	if model and model:IsA("Model") and (model.Name:match("^Drop_") or model.Name:match("^KuromiDrop") or model.Name:match("^Cinnamoroll") or model.Name:match("^HelloKitty")) then
		isModelDrop = true
		
		-- 🔧 LIVE FIX: Get or create GUID
		dropId = model:GetAttribute("DropId")
		if not dropId then
			dropId = HttpService:GenerateGUID(false)
			model:SetAttribute("DropId", dropId)
		end

		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant:FindFirstChild("Cash") then
				local cash = descendant:FindFirstChild("Cash")
				if cash and cash:IsA("IntValue") then
					modelCashValue = modelCashValue + cash.Value
				end
			end
		end
	end

	if isModelDrop and modelCashValue > 0 then
		-- 🔧 LIVE FIX: Check GUID to prevent double-collection
		if dropId and collectedIds[dropId] then 
			return 
		end
		if not currentOwner then return end

		-- Mark as collected
		if dropId then
			collectedIds[dropId] = true
		end
		collectedParts[model] = true

		-- Award money
		Money.Value = Money.Value + modelCashValue
		playSound(collector, Settings.Sounds.Collect, 0.1)
		model:Destroy()
		return
	end

	-- ... rest of your single-part collection logic stays the same ...
end)


-- ========================================
-- 5️⃣ UPDATE Owner.Changed - WRAP PLAYER CLEANUP IN PCALL
-- ========================================
-- FIND: if newOwner == nil and currentOwner ~= nil then
-- REPLACE the player cleanup section with:

pcall(function()
	local spawnLocation = essentials:FindFirstChild("Spawn")
	if spawnLocation and spawnLocation:IsA("SpawnLocation") then
		spawnLocation.Neutral = true
	end
end)

pcall(function()
	if currentOwner and currentOwner.Parent then
		currentOwner.RespawnLocation = nil
		currentOwner.Team = nil
	end
end)


-- ========================================
-- 6️⃣ COMMENT OUT OR REMOVE ProcessReceipt (if you have it)
-- ========================================
-- FIND AND COMMENT OUT:
--[[
MarketplaceService.ProcessReceipt = function(receiptInfo)
	-- REMOVE THIS - causes conflicts in live servers!
	-- Move to a central ServerScriptService script instead
end
--]]


-- ========================================
-- ✅ DONE! TEST IN LIVE SERVER
-- ========================================
--[[
	After applying these patches:
	1. Publish your game
	2. Join with 2 accounts
	3. Player 1 claims tycoon
	4. Player 1 LEAVES
	5. Check that tycoon is COMPLETELY CLEARED (no drops, no objects)
	
	If it works: Apply to ALL your handlers (Cinnamoroll, HelloKitty, MyMelody)
	If not: Check the LIVE_SERVER_FIX_GUIDE.md for detailed debugging
]]
