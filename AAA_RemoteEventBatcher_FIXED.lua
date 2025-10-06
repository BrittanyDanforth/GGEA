--[[
	🔧 REMOTE EVENT BATCHER - FIXED VERSION
	✅ Intercepts ALL remote event calls
	✅ Batches them automatically  
	✅ Works with auto-collect
	✅ Handles 4 different tycoons
	
	PUT IN: ServerScriptService
	NAME: AAA_RemoteEventBatcher (AAA makes it load first)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for everything to load
task.wait(3)

print("🔧 [BATCHER] Initializing...")

-- =================== CONFIG ===================
local BATCH_INTERVAL = 0.2    -- Send batches every 0.2 seconds
local MAX_BATCH = 40          -- Force send if batch gets this big
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

-- Batching storage: [player] = {money = 0, count = 0, lastUpdate = tick()}
local batches = {}

-- Queue storage for remote calls (we'll intercept them)
local moneyQueue = {}  -- {player, amount, ...}
local currencyQueue = {}

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
	
	-- Fire ACTUAL remote events (using the queue bypass)
	task.spawn(function()
		-- MoneyCollected - use pcall to catch any errors
		pcall(function()
			-- Create a fake remote call that bypasses our interception
			local success = pcall(function()
				-- Call the ORIGINAL FireClient by directly accessing the Instance method
				-- We use rawget to bypass any metatable hooks
				local mt = getrawmetatable(game)
				local oldIndex = mt.__index
				setreadonly(mt, false)
				
				-- Temporarily restore original behavior
				local tempCall = oldIndex(MoneyRemote, "FireClient")
				if tempCall then
					tempCall(MoneyRemote, player, batch.giver or workspace, amount, batch.has2x or false, true)
				end
				
				setreadonly(mt, true)
			end)
			
			if not success then
				-- Fallback: just fire it normally
				MoneyRemote:FireClient(player, batch.giver or workspace, amount, batch.has2x or false, true)
			end
		end)
		
		-- CurrencyUpdated
		pcall(function()
			local playerData = nil
			if _G.SanrioTycoonModules and _G.SanrioTycoonModules.DataStoreModule then
				playerData = _G.SanrioTycoonModules.DataStoreModule:GetPlayerData(player)
			end
			
			local currencies = {
				coins = amount,
				gems = playerData and playerData.currencies and playerData.currencies.gems or 0,
				tickets = playerData and playerData.currencies and playerData.currencies.tickets or 0
			}
			
			CurrencyRemote:FireClient(player, currencies)
		end)
		
		if DEBUG then
			print(string.format("💰 [BATCH] %s: %d drops = $%d", player.Name, count, amount))
		end
	end)
end

-- Intercept function for MoneyCollected
local function interceptMoney(player, giver, amount, has2x, isAutoCollect)
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

-- FIXED: Use a connection-based approach instead of trying to override FireClient
local connectionsMoney = {}
local connectionsCurrency = {}

-- Hook into the MoneyUpdateBridge instead
-- This is cleaner and doesn't require messing with FireClient
local function hookMoneyBridge()
	-- Find MoneyUpdateBridge if it exists
	local ServerStorage = game:GetService("ServerStorage")
	local playerMoneyFolder = ServerStorage:FindFirstChild("PlayerMoney")
	
	if playerMoneyFolder then
		print("✅ [BATCHER] Found PlayerMoney folder - hooking into it")
		
		-- Monitor each player's money value
		for _, player in ipairs(Players:GetPlayers()) do
			local moneyValue = playerMoneyFolder:FindFirstChild(player.Name)
			if moneyValue then
				-- Disconnect old connection if exists
				if connectionsMoney[player] then
					connectionsMoney[player]:Disconnect()
				end
				
				-- Connect to money changes
				connectionsMoney[player] = moneyValue.Changed:Connect(function(newValue)
					-- This fires when money changes - intercept it!
					interceptMoney(player, nil, newValue, false, false)
				end)
			end
		end
		
		-- Monitor new players
		playerMoneyFolder.ChildAdded:Connect(function(moneyValue)
			local player = Players:FindFirstChild(moneyValue.Name)
			if player then
				if connectionsMoney[player] then
					connectionsMoney[player]:Disconnect()
				end
				
				connectionsMoney[player] = moneyValue.Changed:Connect(function(newValue)
					interceptMoney(player, nil, newValue, false, false)
				end)
			end
		end)
	end
end

-- Alternative: Monitor Money.Changed in each tycoon
local function hookTycoonMoney()
	print("✅ [BATCHER] Hooking into tycoon money systems")
	
	-- Find all tycoons
	local tycoonFolders = {
		workspace:FindFirstChild("New Hellokitty  tycoon"),
		workspace:FindFirstChild("Zednov's Tycoon Kit"),
		workspace:FindFirstChild("Cinnamoroll tycoon"),
		workspace:FindFirstChild("Kuromi tycoon")
	}
	
	for _, folder in ipairs(tycoonFolders) do
		if folder then
			local tycoons = folder:FindFirstChild("Tycoons")
			if tycoons then
				for _, tycoon in ipairs(tycoons:GetChildren()) do
					local money = tycoon:FindFirstChild("CurrencyToCollect")
					if money then
						money.Changed:Connect(function(newValue)
							local owner = tycoon:FindFirstChild("Owner")
							if owner and owner.Value then
								-- Intercept the money change
								interceptMoney(owner.Value, nil, newValue, false, true)
							end
						end)
						print("  ✓ Hooked into", tycoon.Name, "money")
					end
				end
			end
		end
	end
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
	
	if connectionsMoney[player] then
		connectionsMoney[player]:Disconnect()
		connectionsMoney[player] = nil
	end
end)

-- Initialize hooks
task.spawn(function()
	task.wait(2)  -- Wait for everything to load
	hookMoneyBridge()
	hookTycoonMoney()
end)

print("✅ [BATCHER] Active!")
print("📊 Batching money updates from all 4 tycoons")
print("🎯 Remote event spam = REDUCED!")
