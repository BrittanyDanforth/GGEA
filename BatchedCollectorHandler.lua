--[[
	BATCHED COLLECTOR HANDLER - Put in Purchases Model
	✅ Batches ALL money from ALL 13 droppers
	✅ Fixes remote event spam (no more dropped events)
	✅ Works with ALL droppers (no need to modify them)
	✅ One script per tycoon
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- =================== CONFIG ===================
local BATCH_INTERVAL = 0.15  -- Batch money every 0.15 seconds (prevents spam)
local ENABLE_DEBUG = false    -- Set to true to see batching in action
-- =================================================

-- Get remote events (adjust if your paths are different)
local TycoonRemotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)

local MoneyCollectedRemote = TycoonRemotes and TycoonRemotes:FindFirstChild("MoneyCollected")
local CurrencyUpdatedRemote = RemoteEvents and RemoteEvents:FindFirstChild("CurrencyUpdated")

-- Find the owner of this tycoon
local tycoonModel = script.Parent.Parent  -- Adjust if needed
local ownerValue = tycoonModel:WaitForChild("Owner", 10)

-- Storage for pending money
local pendingMoney = 0
local lastBatchTime = tick()
local totalItemsCollected = 0

-- Function to send batched money to client
local function sendBatchedMoney()
	if pendingMoney <= 0 then return end
	if not ownerValue.Value then return end
	
	local player = ownerValue.Value
	local amount = pendingMoney
	
	-- Fire SINGLE event with batched total
	if MoneyCollectedRemote then
		pcall(function()
			MoneyCollectedRemote:FireClient(player, amount)
		end)
	end
	
	if CurrencyUpdatedRemote then
		pcall(function()
			CurrencyUpdatedRemote:FireClient(player, amount)
		end)
	end
	
	if ENABLE_DEBUG then
		print(string.format("✅ Batched %d items = $%d sent to %s", totalItemsCollected, amount, player.Name))
	end
	
	-- Reset batch
	pendingMoney = 0
	totalItemsCollected = 0
	lastBatchTime = tick()
end

-- Batch processing loop
task.spawn(function()
	while true do
		task.wait(BATCH_INTERVAL)
		
		-- Send batch if there's pending money
		if pendingMoney > 0 then
			sendBatchedMoney()
		end
	end
end)

-- Find all collector parts in this tycoon
local function findCollectors()
	local collectors = {}
	
	-- Search for parts named "Collector", "Sell", "SellPad", etc.
	for _, descendant in ipairs(tycoonModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local name = string.lower(descendant.Name)
			
			-- Check if it's a collector by name
			if name:find("collect") or name:find("sell") or name == "receiver" then
				table.insert(collectors, descendant)
				if ENABLE_DEBUG then
					print("Found collector:", descendant:GetFullName())
				end
			end
			
			-- Check by CollectionService tag
			local CollectionService = game:GetService("CollectionService")
			if CollectionService:HasTag(descendant, "Collector") or CollectionService:HasTag(descendant, "SellZone") then
				table.insert(collectors, descendant)
				if ENABLE_DEBUG then
					print("Found tagged collector:", descendant:GetFullName())
				end
			end
			
			-- Check by attribute
			if descendant:GetAttribute("Collector") == true then
				table.insert(collectors, descendant)
				if ENABLE_DEBUG then
					print("Found attribute collector:", descendant:GetFullName())
				end
			end
		end
	end
	
	return collectors
end

-- Setup collector to batch money
local function setupCollector(collectorPart)
	if not collectorPart then return end
	
	-- Track what we've already collected (prevent double-collecting)
	local collectedParts = {}
	
	collectorPart.Touched:Connect(function(hit)
		-- Prevent double-collection
		if collectedParts[hit] then return end
		
		-- Check if owner exists
		if not ownerValue.Value then return end
		
		-- Look for Cash value
		local cashValue = hit:FindFirstChild("Cash")
		if not cashValue or not cashValue:IsA("IntValue") then return end
		
		local amount = cashValue.Value
		if amount <= 0 then return end
		
		-- Mark as collected
		collectedParts[hit] = true
		
		-- Add to batch instead of firing event immediately!
		pendingMoney = pendingMoney + amount
		totalItemsCollected = totalItemsCollected + 1
		
		-- Destroy the drop (or its parent if it's a model)
		task.defer(function()
			if hit.Parent then
				if hit.Parent:IsA("Model") then
					hit.Parent:Destroy()
				else
					hit:Destroy()
				end
			end
		end)
		
		-- If batch gets too large, send immediately (prevent huge spikes)
		if pendingMoney >= 1000 or totalItemsCollected >= 50 then
			sendBatchedMoney()
		end
	end)
	
	if ENABLE_DEBUG then
		print("✅ Collector connected:", collectorPart.Name)
	end
end

-- Initialize all collectors
task.wait(2)  -- Wait for tycoon to load

local collectors = findCollectors()

if #collectors == 0 then
	warn("⚠️ No collectors found! Make sure you have parts named 'Collector', 'Sell', etc.")
else
	print(string.format("✅ Found %d collectors - Setting up batched collection...", #collectors))
	
	for _, collector in ipairs(collectors) do
		setupCollector(collector)
	end
	
	print("✅ Batched Collector Handler active - Remote event spam fixed!")
end

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(player)
	if ownerValue.Value == player then
		pendingMoney = 0
		totalItemsCollected = 0
	end
end)
