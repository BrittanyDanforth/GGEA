--[[
	ULTRA BATCHED COLLECTOR - Even More Aggressive
	✅ Batches money every 0.2 seconds (even less spam)
	✅ Caps max items per batch (prevents spikes)
	✅ Auto-detects collectors (no setup needed)
	✅ Works with unlimited droppers
	
	PUT THIS IN: YourTycoon > Purchases (or wherever your collector is)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- =================== ULTRA CONFIG ===================
local BATCH_INTERVAL = 0.25       -- Batch every 0.25 seconds (very aggressive)
local MAX_BATCH_SIZE = 30         -- Max items per batch (prevents huge spikes)
local ENABLE_DEBUG = false        -- Set true to debug
-- ===================================================

-- Get remote events
local MoneyCollectedRemote, CurrencyUpdatedRemote

pcall(function()
	local TycoonRemotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 5)
	MoneyCollectedRemote = TycoonRemotes:WaitForChild("MoneyCollected", 5)
end)

pcall(function()
	local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 5)
	CurrencyUpdatedRemote = RemoteEvents:WaitForChild("CurrencyUpdated", 5)
end)

-- Find tycoon owner
local tycoonModel = script.Parent.Parent or script.Parent
local ownerValue = tycoonModel:FindFirstChild("Owner", true)

if not ownerValue then
	warn("⚠️ Could not find Owner value - Batched collector may not work!")
end

-- Batching system
local pendingMoney = 0
local itemsInBatch = 0
local isProcessing = false

-- Send batch (with rate limiting)
local function sendBatch()
	if isProcessing then return end
	if pendingMoney <= 0 then return end
	if not ownerValue or not ownerValue.Value then return end
	
	isProcessing = true
	
	local player = ownerValue.Value
	local amount = pendingMoney
	local count = itemsInBatch
	
	-- Reset BEFORE firing to prevent issues
	pendingMoney = 0
	itemsInBatch = 0
	
	-- Fire events with pcall protection
	task.spawn(function()
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
			print(string.format("💰 Batched: %d items = $%d → %s", count, amount, player.Name))
		end
		
		task.wait(0.05)  -- Small delay between batches
		isProcessing = false
	end)
end

-- Batch loop (continuous monitoring)
task.spawn(function()
	while true do
		task.wait(BATCH_INTERVAL)
		sendBatch()
	end
end)

-- Add money to batch
local function addToBatch(amount)
	pendingMoney = pendingMoney + amount
	itemsInBatch = itemsInBatch + 1
	
	-- Force send if batch is full
	if itemsInBatch >= MAX_BATCH_SIZE then
		sendBatch()
	end
end

-- Find collectors automatically
local function setupCollectors()
	local collectors = {}
	
	-- Search entire tycoon
	for _, obj in ipairs(tycoonModel:GetDescendants()) do
		if obj:IsA("BasePart") then
			local name = string.lower(obj.Name)
			
			-- Match collector names
			if name:find("collect") or name:find("sell") or name:find("receiver") or name == "collectorzone" or name == "sellpad" then
				table.insert(collectors, obj)
			end
			
			-- Match tags
			local CollectionService = game:GetService("CollectionService")
			if CollectionService:HasTag(obj, "Collector") or CollectionService:HasTag(obj, "SellZone") then
				if not table.find(collectors, obj) then
					table.insert(collectors, obj)
				end
			end
		end
	end
	
	return collectors
end

-- Setup touch detection
local function connectCollector(collectorPart)
	local processedParts = {}  -- Debounce
	
	collectorPart.Touched:Connect(function(hit)
		-- Debounce
		if processedParts[hit] then return end
		processedParts[hit] = true
		
		-- Cleanup debounce after 1 second
		task.delay(1, function()
			processedParts[hit] = nil
		end)
		
		-- Check for cash
		local cash = hit:FindFirstChild("Cash")
		if not cash or not cash:IsA("IntValue") then return end
		if cash.Value <= 0 then return end
		
		-- Add to batch!
		addToBatch(cash.Value)
		
		-- Destroy drop
		task.defer(function()
			if hit.Parent then
				if hit.Parent:IsA("Model") then
					hit.Parent:Destroy()
				else
					hit:Destroy()
				end
			end
		end)
	end)
end

-- Initialize
task.wait(2)

local collectors = setupCollectors()

if #collectors == 0 then
	warn("⚠️ BatchedCollector: No collectors found in", tycoonModel:GetFullName())
	warn("⚠️ Make sure you have parts named 'Collector', 'Sell', etc.")
else
	for _, collector in ipairs(collectors) do
		connectCollector(collector)
	end
	
	print(string.format("✅ ULTRA Batched Collector: %d collectors active (Batch every %.2fs)", #collectors, BATCH_INTERVAL))
end

-- Cleanup on player leave
if ownerValue then
	ownerValue.Changed:Connect(function()
		if not ownerValue.Value then
			pendingMoney = 0
			itemsInBatch = 0
		end
	end)
end
