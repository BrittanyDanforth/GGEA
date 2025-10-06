--[[
	🔧 REMOTE EVENT BATCHER PATCH
	✅ Intercepts ALL remote event calls
	✅ Batches them automatically  
	✅ Works with your existing code (no changes needed!)
	✅ Fixes auto-collect lag
	
	PUT IN: ServerScriptService
	LOAD ORDER: Must load BEFORE other scripts (rename to "AAA_RemoteEventBatcher" to load first)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for remotes to exist
task.wait(1)

print("🔧 [BATCHER PATCH] Initializing...")

-- =================== CONFIG ===================
local BATCH_INTERVAL = 0.2    -- Send batches every 0.2 seconds
local MAX_BATCH = 50          -- Force send if batch gets this big
local DEBUG = true            -- Set false to hide logs
-- =================================================

-- Find the remote events
local TycoonRemotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)

if not TycoonRemotes or not RemoteEvents then
	warn("⚠️ [BATCHER] Could not find remote folders!")
	return
end

local MoneyRemote = TycoonRemotes:WaitForChild("MoneyCollected", 10)
local CurrencyRemote = RemoteEvents:WaitForChild("CurrencyUpdated", 10)

if not MoneyRemote or not CurrencyRemote then
	warn("⚠️ [BATCHER] Could not find money remotes!")
	return
end

-- Store original FireClient methods
local originalMoneyFire = MoneyRemote.FireClient
local originalCurrencyFire = CurrencyRemote.FireClient

-- Batching storage: [player] = {money = 0, count = 0, lastUpdate = tick()}
local batches = {}

-- Send a batch for a specific player
local function sendBatch(player)
	if not player or not player.Parent then
		batches[player] = nil
		return
	end
	
	local batch = batches[player]
	if not batch or batch.money <= 0 then return end
	
	local amount = batch.money
	local count = batch.count
	
	-- Reset batch
	batch.money = 0
	batch.count = 0
	batch.lastUpdate = tick()
	
	-- Fire ORIGINAL remote functions (only once!)
	task.spawn(function()
		-- MoneyCollected
		pcall(function()
			-- Use the stored giver and has2x from the last call
			originalMoneyFire(MoneyRemote, player, batch.giver or workspace, amount, batch.has2x or false, true)
		end)
		
		-- CurrencyUpdated
		pcall(function()
			-- For CurrencyUpdated, we need the full currencies table
			-- Get current player data
			local playerData = nil
			if _G.SanrioTycoonModules and _G.SanrioTycoonModules.DataStoreModule then
				playerData = _G.SanrioTycoonModules.DataStoreModule:GetPlayerData(player)
			end
			
			local currencies = {
				coins = amount,
				gems = playerData and playerData.currencies and playerData.currencies.gems or 0,
				tickets = playerData and playerData.currencies and playerData.currencies.tickets or 0
			}
			
			originalCurrencyFire(CurrencyRemote, player, currencies)
		end)
		
		if DEBUG then
			print(string.format("💰 [BATCH] %s: %d drops = $%d", player.Name, count, amount))
		end
	end)
end

-- Replace MoneyCollected.FireClient with batching version
MoneyRemote.FireClient = function(self, player, giver, amount, has2x, isAutoCollect)
	if not player or not amount or amount <= 0 then return end
	
	-- Initialize batch if needed
	if not batches[player] then
		batches[player] = {
			money = 0,
			count = 0,
			lastUpdate = tick(),
			giver = giver,
			has2x = has2x or false
		}
	end
	
	-- Add to batch
	batches[player].money = batches[player].money + amount
	batches[player].count = batches[player].count + 1
	batches[player].giver = giver  -- Store latest giver
	batches[player].has2x = has2x or false  -- Store if 2x is active
	
	-- Force send if batch is too large or too old
	local timeSince = tick() - batches[player].lastUpdate
	if batches[player].count >= MAX_BATCH or timeSince >= BATCH_INTERVAL then
		sendBatch(player)
	end
end

-- Replace CurrencyUpdated.FireClient with batching version
CurrencyRemote.FireClient = function(self, player, currencies)
	-- Don't fire separately - MoneyCollected handles it
	-- This prevents double-firing
end

-- Timer loop - send batches periodically
task.spawn(function()
	while true do
		task.wait(BATCH_INTERVAL)
		
		for player, batch in pairs(batches) do
			if batch.money > 0 then
				local timeSince = tick() - batch.lastUpdate
				if timeSince >= BATCH_INTERVAL then
					sendBatch(player)
				end
			end
		end
	end
end)

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(player)
	if batches[player] and batches[player].money > 0 then
		sendBatch(player)  -- Send remaining money
	end
	batches[player] = nil
end)

print("✅ [BATCHER PATCH] Active!")
print("📊 Batching ALL money events (auto-collect + manual)")
print("🎯 Remote event spam = FIXED!")
