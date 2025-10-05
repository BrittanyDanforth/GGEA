-- MoneyUpdateBridge.lua - FIXED WITH BATCHING
-- This script bridges the tycoon's money system with the Sanrio shop's currency update system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

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

-- =================== BATCHING SYSTEM (NEW) ===================
local BATCH_INTERVAL = 0.2  -- Send updates every 0.2 seconds
local pendingUpdates = {}   -- [player] = {coins = 0, needsUpdate = false}

-- Batch sending loop
task.spawn(function()
	while true do
		task.wait(BATCH_INTERVAL)
		
		for player, update in pairs(pendingUpdates) do
			if update.needsUpdate and player.Parent then  -- Check player still exists
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
				pcall(function()
					CurrencyUpdated:FireClient(player, currencies)
				end)
				
				-- Reset flag
				update.needsUpdate = false
			end
		end
	end
end)
-- ============================================================

-- Track player money values
local playerMoneyValues = {}
local lastUpdateTime = {}

-- Function to find player's money value
local function findPlayerMoneyValue(player)
	-- Check common locations for money values
	local locations = {}

	-- Add valid money values from common locations
	local checkLocations = {
		player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Money"),
		player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash"),
		player:FindFirstChild("Stats") and player.Stats:FindFirstChild("Money"),
		player:FindFirstChild("Stats") and player.Stats:FindFirstChild("Cash"),
		player:FindFirstChild("Data") and player.Data:FindFirstChild("Money"),
		player:FindFirstChild("Data") and player.Data:FindFirstChild("Cash"),
	}

	for _, value in ipairs(checkLocations) do
		if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then
			table.insert(locations, value)
		end
	end

	-- Also check PlayerMoney folder in ServerStorage (created by UnifiedLeaderboard)
	local playerMoneyFolder = game:GetService("ServerStorage"):FindFirstChild("PlayerMoney")
	if playerMoneyFolder then
		-- UnifiedLeaderboard creates an IntValue with the player's name
		local playerValue = playerMoneyFolder:FindFirstChild(player.Name)
		if playerValue and (playerValue:IsA("IntValue") or playerValue:IsA("NumberValue")) then
			print("[MoneyUpdateBridge] Found player money value in ServerStorage:", playerValue:GetFullName())
			table.insert(locations, playerValue)
		end
	end

	-- Check tycoon-specific locations
	local tycoons = {
		workspace:FindFirstChild("New Hellokitty  tycoon") and workspace["New Hellokitty  tycoon"]:FindFirstChild("Tycoons"),
		workspace:FindFirstChild("Zednov's Tycoon Kit") and workspace["Zednov's Tycoon Kit"]:FindFirstChild("Tycoons"),
		workspace:FindFirstChild("Cinnamoroll tycoon") and workspace["Cinnamoroll tycoon"]:FindFirstChild("Tycoons"),
		workspace:FindFirstChild("Kuromi tycoon") and workspace["Kuromi tycoon"]:FindFirstChild("Tycoons")
	}

	for _, tycoonFolder in ipairs(tycoons) do
		if tycoonFolder then
			for _, tycoon in pairs(tycoonFolder:GetChildren()) do
				local owner = tycoon:FindFirstChild("Owner")
				if owner and owner.Value == player then
					-- Found player's tycoon, look for money in various locations
					local cash = tycoon:FindFirstChild("Cash") or tycoon:FindFirstChild("Money")
					if cash then
						table.insert(locations, cash)
					end

					-- Check CurrencyToCollect
					local currencyFolder = tycoon:FindFirstChild("CurrencyToCollect")
					if currencyFolder then
						local curr = currencyFolder:FindFirstChild("Cash") or currencyFolder:FindFirstChild("Money")
						if curr then
							table.insert(locations, curr)
						end
					end

					-- Check inside PurchasedObjects for money values
					local purchasedObjects = tycoon:FindFirstChild("PurchasedObjects")
					if purchasedObjects then
						local moneyObj = purchasedObjects:FindFirstChild("Money") or purchasedObjects:FindFirstChild("Cash")
						if moneyObj then
							table.insert(locations, moneyObj)
						end

						-- Also check for a Collector part with money value
						local collector = purchasedObjects:FindFirstChild("Collector")
						if collector then
							local collectorMoney = collector:FindFirstChild("Cash") or collector:FindFirstChild("Money")
							if collectorMoney then
								table.insert(locations, collectorMoney)
							end
						end
					end

					-- Check Essentials folder
					local essentials = tycoon:FindFirstChild("Essentials")
					if essentials then
						local essentialCash = essentials:FindFirstChild("Cash") or essentials:FindFirstChild("Money")
						if essentialCash then
							table.insert(locations, essentialCash)
						end
					end

					-- Check for PlayerMoney inside tycoon
					local tycoonPlayerMoney = tycoon:FindFirstChild("PlayerMoney")
					if tycoonPlayerMoney then
						local playerValue = tycoonPlayerMoney:FindFirstChild("Value") or tycoonPlayerMoney:FindFirstChild("Money") or tycoonPlayerMoney:FindFirstChild("Cash")
						if playerValue then
							table.insert(locations, playerValue)
						end
					end

					-- Check Values folder
					local values = tycoon:FindFirstChild("Values")
					if values then
						local money = values:FindFirstChild("Money") or values:FindFirstChild("Cash") or values:FindFirstChild("PlayerMoney")
						if money then
							table.insert(locations, money)
						end
					end
				end
			end
		end
	end

	-- Return first valid money value found
	if #locations > 0 then
		local moneyValue = locations[1]
		if moneyValue and moneyValue.Parent then
			print("[MoneyUpdateBridge] Using money value for", player.Name, "at", moneyValue:GetFullName())
			return moneyValue
		end
	end

	-- Debug: no locations found
	print("[MoneyUpdateBridge] No money values found for", player.Name)

	return nil
end

-- =================== MODIFIED FUNCTION (BATCHED) ===================
-- Function to update player currencies - NOW BATCHES INSTEAD OF IMMEDIATE
local function updatePlayerCurrencies(player, newCoins)
	-- Initialize pending update if needed
	if not pendingUpdates[player] then
		pendingUpdates[player] = {coins = 0, needsUpdate = false}
	end
	
	-- Store the new value and mark for update
	pendingUpdates[player].coins = newCoins
	pendingUpdates[player].needsUpdate = true
	
	-- The batch loop will send this in the next cycle (every 0.2s)
end
-- ================================================================

-- Track player money OBJECTS, not just values
local playerMoneyObjects = {}
local playerConnections = {}

local function monitorPlayerMoney(player)
	-- Wait a bit for PlayerMoney folder to be created by UnifiedLeaderboard
	task.wait(2)

	-- Try to find the money value object
	local moneyValue = findPlayerMoneyValue(player)

	if not moneyValue then
		-- If not found, wait for tycoon setup and try again
		for i = 1, 5 do
			task.wait(2)
			moneyValue = findPlayerMoneyValue(player)
			if moneyValue then break end
		end
	end

	if not moneyValue then
		warn("[MoneyUpdateBridge] Could not find money value for player after several retries:", player.Name)
		return
	end

	print("[MoneyUpdateBridge] Successfully found and now monitoring money for:", player.Name)
	playerMoneyObjects[player] = moneyValue

	-- Send the initial value right away
	updatePlayerCurrencies(player, moneyValue.Value)

	-- Connect to the .Changed event. This is VERY efficient.
	local connection = moneyValue.Changed:Connect(function(newValue)
		updatePlayerCurrencies(player, newValue)  -- NOW BATCHED!
	end)

	-- Store the connection so we can disconnect it later
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
	playerMoneyValues[player] = nil
	lastUpdateTime[player] = nil
	
	-- =================== NEW: Send any pending updates before cleanup ===================
	if pendingUpdates[player] and pendingUpdates[player].needsUpdate then
		-- Get player data
		local playerData = nil
		if _G.SanrioTycoonModules and _G.SanrioTycoonModules.DataStoreModule then
			playerData = _G.SanrioTycoonModules.DataStoreModule:GetPlayerData(player)
		end

		-- Create currency table
		local currencies = {
			coins = pendingUpdates[player].coins,
			gems = playerData and playerData.currencies and playerData.currencies.gems or 0,
			tickets = playerData and playerData.currencies and playerData.currencies.tickets or 0
		}

		-- Fire the update one last time
		pcall(function()
			CurrencyUpdated:FireClient(player, currencies)
		end)
	end
	pendingUpdates[player] = nil
	-- =================================================================================
end

-- Connect existing players
for _, player in ipairs(Players:GetPlayers()) do
	spawn(function()
		monitorPlayerMoney(player)
	end)
end

-- Connect new players
Players.PlayerAdded:Connect(monitorPlayerMoney)

-- Handle existing players in the game
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(monitorPlayerMoney, player)
end

-- Clean up when a player leaves
Players.PlayerRemoving:Connect(stopMonitoringPlayer)

print("[MoneyUpdateBridge] Initialized - Monitoring with BATCHED updates (every 0.2s) - LAG FIXED! ✅")
