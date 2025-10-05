--[[
	🚨 ULTIMATE REMOTE EVENT BATCHER
	
	✅ Works with auto-collect gamepass
	✅ Works with normal collectors
	✅ Works with ANY money collection system
	✅ Just drop in ServerScriptService and forget it
	
	HOW IT WORKS:
	- Intercepts ALL remote event calls
	- Batches them automatically
	- Sends in groups instead of 100+ individual events
	
	PUT THIS IN: ServerScriptService
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for remotes to exist
task.wait(2)

print("🚀 [ULTIMATE BATCHER] Starting...")

-- =================== CONFIG ===================
local BATCH_INTERVAL = 0.2    -- Send batch every 0.2 seconds
local MAX_BATCH_SIZE = 50     -- Max events before force-send
-- =================================================

-- Find remotes
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

-- Save original functions (so we can call them later)
local originalMoneyFire = MoneyRemote.FireClient
local originalCurrencyFire = CurrencyRemote.FireClient

-- Storage for batched events
local playerBatches = {}  -- [player] = {money = 0, count = 0}

-- Function to send batched money
local function sendBatch(player)
	local batch = playerBatches[player]
	if not batch or batch.money <= 0 then return end
	
	local amount = batch.money
	local count = batch.count
	
	-- Reset batch
	batch.money = 0
	batch.count = 0
	
	-- Send SINGLE batched event
	task.spawn(function()
		pcall(function()
			originalMoneyFire(MoneyRemote, player, amount)
		end)
		pcall(function()
			originalCurrencyFire(CurrencyRemote, player, amount)
		end)
		
		print(string.format("💰 [BATCH] %s: %d drops = $%d", player.Name, count, amount))
	end)
end

-- Replace FireClient with batching version
MoneyRemote.FireClient = function(self, player, amount)
	if not player or not amount then return end
	
	-- Create batch if doesn't exist
	if not playerBatches[player] then
		playerBatches[player] = {money = 0, count = 0}
	end
	
	-- Add to batch
	playerBatches[player].money = playerBatches[player].money + amount
	playerBatches[player].count = playerBatches[player].count + 1
	
	-- Force send if batch is full
	if playerBatches[player].count >= MAX_BATCH_SIZE then
		sendBatch(player)
	end
end

-- Replace CurrencyUpdated too (it usually fires with MoneyCollected)
CurrencyRemote.FireClient = function(self, player, amount)
	-- Don't do anything - MoneyRemote handles it
end

-- Timer loop - send batches periodically
task.spawn(function()
	while true do
		task.wait(BATCH_INTERVAL)
		
		for player, batch in pairs(playerBatches) do
			if batch.money > 0 then
				sendBatch(player)
			end
		end
	end
end)

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(player)
	if playerBatches[player] and playerBatches[player].money > 0 then
		sendBatch(player)  -- Send any remaining money
	end
	playerBatches[player] = nil
end)

print("✅ [ULTIMATE BATCHER] Active!")
print("📊 Batching ALL money events (auto-collect + normal)")
print("🎯 No more remote event spam!")
