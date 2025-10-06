--[[
	MONEY BRIDGE BATCH PATCH
	✅ Patches your existing MoneyUpdateBridge to batch updates
	✅ Works with auto-collect gamepass
	✅ Prevents remote event spam
	✅ Put this in ServerScriptService (loads AFTER MoneyUpdateBridge)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

task.wait(3)  -- Wait for MoneyUpdateBridge to load first

print("🔧 Money Bridge Batch Patch - Initializing...")

-- =================== CONFIG ===================
local BATCH_INTERVAL = 0.2   -- Batch every 0.2 seconds
local MAX_QUEUE = 40         -- Max events per batch
local ENABLE_DEBUG = true    -- Debug logs
-- =================================================

-- Get the remotes
local TycoonRemotes = ReplicatedStorage:FindFirstChild("TycoonRemotes")
local RemoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")

if not TycoonRemotes or not RemoteEvents then
	warn("⚠️ Could not find remote event folders!")
	return
end

local MoneyCollectedRemote = TycoonRemotes:FindFirstChild("MoneyCollected")
local CurrencyUpdatedRemote = RemoteEvents:FindFirstChild("CurrencyUpdated")

if not MoneyCollectedRemote or not CurrencyUpdatedRemote then
	warn("⚠️ Could not find money remotes!")
	return
end

-- Store original fire functions
local originalMoney = MoneyCollectedRemote.FireClient
local originalCurrency = CurrencyUpdatedRemote.FireClient

-- Batching system
local batches = {}  -- [player] = {total = 0, count = 0, lastUpdate = 0}

-- Send batch for a player
local function sendBatch(player)
	local batch = batches[player]
	if not batch or batch.total <= 0 then return end
	
	local amount = batch.total
	local count = batch.count
	
	-- Reset batch
	batch.total = 0
	batch.count = 0
	batch.lastUpdate = tick()
	
	-- Fire original remotes (safely)
	task.spawn(function()
		pcall(function()
			originalMoney(MoneyCollectedRemote, player, amount)
		end)
		
		pcall(function()
			originalCurrency(CurrencyUpdatedRemote, player, amount)
		end)
		
		if ENABLE_DEBUG then
			print(string.format("💰 [BATCH] %s: %d events = $%d", player.Name, count, amount))
		end
	end)
end

-- Replace FireClient with batching version
MoneyCollectedRemote.FireClient = function(self, player, amount)
	if not player or not amount or amount <= 0 then return end
	
	-- Initialize batch if needed
	if not batches[player] then
		batches[player] = {total = 0, count = 0, lastUpdate = tick()}
	end
	
	-- Add to batch
	batches[player].total = batches[player].total + amount
	batches[player].count = batches[player].count + 1
	
	-- Force send if batch is full or too old
	local timeSinceUpdate = tick() - batches[player].lastUpdate
	if batches[player].count >= MAX_QUEUE or timeSinceUpdate >= BATCH_INTERVAL then
		sendBatch(player)
	end
end

-- Also patch CurrencyUpdated (but it won't fire since MoneyCollected handles it)
CurrencyUpdatedRemote.FireClient = function(self, player, amount)
	-- Do nothing, let MoneyCollected handle batching
end

-- Batch loop (backup timer)
task.spawn(function()
	while true do
		task.wait(BATCH_INTERVAL)
		
		for player, batch in pairs(batches) do
			if batch.total > 0 then
				local timeSinceUpdate = tick() - batch.lastUpdate
				if timeSinceUpdate >= BATCH_INTERVAL then
					sendBatch(player)
				end
			end
		end
	end
end)

-- Cleanup on player leave
Players.PlayerRemoving:Connect(function(player)
	if batches[player] and batches[player].total > 0 then
		sendBatch(player)
	end
	batches[player] = nil
end)

print("✅ Money Bridge Batch Patch - Active!")
print(string.format("📊 Batching: Max %d events every %.2fs", MAX_QUEUE, BATCH_INTERVAL))
print("💡 This intercepts ALL money updates and batches them!")
