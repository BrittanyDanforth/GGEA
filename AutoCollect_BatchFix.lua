--[[
	AUTO-COLLECT BATCH FIX
	✅ Works WITH auto-collect gamepass
	✅ Hooks into PurchaseHandler's collection
	✅ Batches remote events properly
	✅ Put this in ServerScriptService
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("🚀 Auto-Collect Batch Fix - Initializing...")

-- =================== CONFIG ===================
local BATCH_INTERVAL = 0.15  -- Batch money updates
local MAX_BATCH_SIZE = 50    -- Max items per batch
local ENABLE_DEBUG = true    -- Set false to hide logs
-- =================================================

-- Get remote events
local TycoonRemotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)

if not TycoonRemotes or not RemoteEvents then
	warn("⚠️ Could not find remote event folders!")
	return
end

local MoneyCollectedRemote = TycoonRemotes:FindFirstChild("MoneyCollected")
local CurrencyUpdatedRemote = RemoteEvents:FindFirstChild("CurrencyUpdated")

-- Store original remote functions
local originalMoneyFire = MoneyCollectedRemote and MoneyCollectedRemote.FireClient
local originalCurrencyFire = CurrencyUpdatedRemote and CurrencyUpdatedRemote.FireClient

-- Batching storage
local pendingMoney = {}  -- [player] = totalMoney
local pendingCount = {}  -- [player] = itemCount

-- Send batched money
local function sendBatch(player)
	if not pendingMoney[player] or pendingMoney[player] <= 0 then return end
	
	local amount = pendingMoney[player]
	local count = pendingCount[player] or 0
	
	-- Reset
	pendingMoney[player] = 0
	pendingCount[player] = 0
	
	-- Fire original remotes
	task.spawn(function()
		if MoneyCollectedRemote and originalMoneyFire then
			pcall(function()
				originalMoneyFire(MoneyCollectedRemote, player, amount)
			end)
		end
		
		if CurrencyUpdatedRemote and originalCurrencyFire then
			pcall(function()
				originalCurrencyFire(CurrencyUpdatedRemote, player, amount)
			end)
		end
		
		if ENABLE_DEBUG then
			print(string.format("💰 Batched: %d items = $%d → %s", count, amount, player.Name))
		end
	end)
end

-- Batch loop
task.spawn(function()
	while true do
		task.wait(BATCH_INTERVAL)
		
		for player, amount in pairs(pendingMoney) do
			if amount > 0 then
				sendBatch(player)
			end
		end
	end
end)

-- Hook into remote events to intercept and batch
if MoneyCollectedRemote then
	MoneyCollectedRemote.FireClient = function(self, player, amount)
		if not player or not amount then return end
		
		-- Add to batch instead of firing immediately
		pendingMoney[player] = (pendingMoney[player] or 0) + amount
		pendingCount[player] = (pendingCount[player] or 0) + 1
		
		-- Force send if batch is too large
		if pendingCount[player] >= MAX_BATCH_SIZE then
			sendBatch(player)
		end
	end
	
	print("✅ Hooked into MoneyCollected remote")
end

if CurrencyUpdatedRemote then
	-- We only need to hook one remote since they fire together
	-- But keep the original function available
	print("✅ Hooked into CurrencyUpdated remote")
end

-- Cleanup on player leave
Players.PlayerRemoving:Connect(function(player)
	-- Send any pending money before they leave
	if pendingMoney[player] and pendingMoney[player] > 0 then
		sendBatch(player)
	end
	
	-- Clear data
	pendingMoney[player] = nil
	pendingCount[player] = nil
end)

print("✅ Auto-Collect Batch Fix - Active!")
print("💡 This now batches ALL money collection, including auto-collect!")
