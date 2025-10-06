--[[
	BATCHED MONEY COLLECTOR - Fixes Remote Event Spam
	✅ Batches money updates every 0.1 seconds
	✅ Prevents remote event queue exhaustion
	✅ Handles unlimited droppers without lag
	✅ Replaces individual money collection calls
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Get your remote events (adjust paths if needed)
local TycoonRemotes = ReplicatedStorage:WaitForChild("TycoonRemotes")
local MoneyCollectedRemote = TycoonRemotes:WaitForChild("MoneyCollected")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local CurrencyUpdatedRemote = RemoteEvents:WaitForChild("CurrencyUpdated")

-- =================== CONFIG ===================
local BATCH_INTERVAL = 0.1  -- Batch updates every 0.1 seconds
local MAX_EVENTS_PER_BATCH = 20  -- Max events per batch (prevents spikes)
-- =================================================

-- Storage for pending money updates
local pendingUpdates = {}  -- {[player] = totalMoney}

-- Function to add money to pending batch
local function addMoneyToBatch(player, amount)
	if not pendingUpdates[player] then
		pendingUpdates[player] = 0
	end
	pendingUpdates[player] = pendingUpdates[player] + amount
end

-- Process batched updates
local function processBatch()
	local updateCount = 0
	
	for player, totalAmount in pairs(pendingUpdates) do
		if player and player.Parent and totalAmount > 0 then
			-- Fire SINGLE event with batched total
			pcall(function()
				MoneyCollectedRemote:FireClient(player, totalAmount)
			end)
			pcall(function()
				CurrencyUpdatedRemote:FireClient(player, totalAmount)
			end)
			
			updateCount = updateCount + 1
			
			-- Prevent too many events in one batch
			if updateCount >= MAX_EVENTS_PER_BATCH then
				task.wait(0.05)  -- Small delay between batches
				updateCount = 0
			end
		end
	end
	
	-- Clear processed updates
	pendingUpdates = {}
end

-- Start batch processing loop
task.spawn(function()
	while true do
		task.wait(BATCH_INTERVAL)
		if next(pendingUpdates) then  -- Only process if there are updates
			processBatch()
		end
	end
end)

-- Clean up disconnected players
Players.PlayerRemoving:Connect(function(player)
	pendingUpdates[player] = nil
end)

-- EXPOSE API for droppers to use
local BatchedCollector = {}

-- Call this instead of firing remote events directly
function BatchedCollector.CollectMoney(player, amount)
	if player and amount > 0 then
		addMoneyToBatch(player, amount)
	end
end

-- Alternative: Auto-detect touched collector parts (if you have a collector part)
function BatchedCollector.SetupCollector(collectorPart, ownerPlayer)
	collectorPart.Touched:Connect(function(hit)
		local cashValue = hit:FindFirstChild("Cash")
		if cashValue and cashValue:IsA("IntValue") then
			local amount = cashValue.Value
			if amount > 0 then
				-- Add to batch instead of firing immediately
				addMoneyToBatch(ownerPlayer, amount)
				
				-- Destroy the part
				if hit.Parent then
					hit.Parent:Destroy()
				else
					hit:Destroy()
				end
			end
		end
	end)
end

return BatchedCollector
