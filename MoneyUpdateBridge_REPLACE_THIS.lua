-- MoneyUpdateBridge.lua - BATCHED VERSION (ACTUALLY WORKS)
-- ⚠️ REPLACE YOUR EXISTING MoneyUpdateBridge WITH THIS! ⚠️

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

print("💰 [MoneyUpdateBridge] BATCHED VERSION - Starting...")

-- Wait for remotes to be created
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not RemoteEvents then
	warn("[MoneyUpdateBridge] RemoteEvents folder not found!")
	return
end

local CurrencyUpdated = RemoteEvents:WaitForChild("CurrencyUpdated", 10)
if not CurrencyUpdated then
	warn("[MoneyUpdateBridge] CurrencyUpdated remote not found!")
	return
end

-- =================== BATCHING SYSTEM ===================
local BATCH_INTERVAL = 0.2  -- Send updates every 0.2 seconds
local pendingUpdates = {}   -- [player] = {coins = 0, needsUpdate = false}

-- Function to send batched update
local function sendBatchedUpdate(player)
	local update = pendingUpdates[player]
	if not update or not update.needsUpdate then return end
	
	-- Get player data from DataStore module if available
	local playerData = nil
	if _G.SanrioTycoonModules and _G.SanrioTycoonModules.DataStoreModule then
		playerData = _G.SanrioTycoonModules.DataStoreModule:GetPlayerData(player)
	end

	-- Create currency table
	local currencies = {
		coins = update.coins,
		gems = playerData and playerData.currencies and playerData.currencies.gems or 0,
		tickets = playerData and playerData.currencies and playerData.currencies.tickets or 0
	}

	-- Fire the update
	CurrencyUpdated:FireClient(player, currencies)
	
	-- Reset flag
	update.needsUpdate = false
end

-- Batch sending loop
task.spawn(function()
	while true do
		task.wait(BATCH_INTERVAL)
		
		for player, update in pairs(pendingUpdates) do
			if update.needsUpdate then
				sendBatchedUpdate(player)
			end
		end
	end
end)

-- Function to update player currencies (BATCHED VERSION)
local function updatePlayerCurrencies(player, newCoins)
	-- Initialize if needed
	if not pendingUpdates[player] then
		pendingUpdates[player] = {coins = 0, needsUpdate = false}
	end
	
	-- Update coins value
	pendingUpdates[player].coins = newCoins
	pendingUpdates[player].needsUpdate = true
	
	-- Note: Actual remote call happens in the batch loop
end

-- Track player money connections
local playerMoneyObjects = {}
local playerConnections = {}

local function findPlayerMoneyValue(player)
	-- Check PlayerMoney folder in ServerStorage (created by UnifiedLeaderboard)
	local playerMoneyFolder = ServerStorage:FindFirstChild("PlayerMoney")
	if playerMoneyFolder then
		local playerValue = playerMoneyFolder:FindFirstChild(player.Name)
		if playerValue and (playerValue:IsA("IntValue") or playerValue:IsA("NumberValue")) then
			print("[MoneyUpdateBridge] Found player money value:", playerValue:GetFullName())
			return playerValue
		end
	end

	print("[MoneyUpdateBridge] No money value found for", player.Name)
	return nil
end

-- Monitor player money with BATCHED updates
local function monitorPlayerMoney(player)
	task.wait(2)  -- Wait for PlayerMoney folder

	local moneyValue = findPlayerMoneyValue(player)
	if not moneyValue then
		for i = 1, 5 do
			task.wait(2)
			moneyValue = findPlayerMoneyValue(player)
			if moneyValue then break end
		end
	end

	if not moneyValue then
		warn("[MoneyUpdateBridge] Could not find money value for:", player.Name)
		return
	end

	print("[MoneyUpdateBridge] Monitoring money for:", player.Name)
	playerMoneyObjects[player] = moneyValue

	-- Send initial value
	updatePlayerCurrencies(player, moneyValue.Value)

	-- Connect to changes - BATCHED!
	local connection = moneyValue.Changed:Connect(function(newValue)
		updatePlayerCurrencies(player, newValue)
	end)

	playerConnections[player] = connection
end

local function stopMonitoringPlayer(player)
	if playerConnections[player] then
		playerConnections[player]:Disconnect()
		playerConnections[player] = nil
	end
	if playerMoneyObjects[player] then
		playerMoneyObjects[player] = nil
	end
	if pendingUpdates[player] then
		sendBatchedUpdate(player)  -- Send any pending
		pendingUpdates[player] = nil
	end
end

-- Connect players
Players.PlayerAdded:Connect(monitorPlayerMoney)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(monitorPlayerMoney, player)
end

Players.PlayerRemoving:Connect(stopMonitoringPlayer)

print("✅ [MoneyUpdateBridge] BATCHED version active - Remote spam fixed!")
