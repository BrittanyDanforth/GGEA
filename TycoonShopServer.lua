--[[
	TYCOON SHOP SERVER HANDLER
	Handles all server-side shop operations
	
	Place in: ServerScriptService
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Create remotes folder
local Remotes = Instance.new("Folder")
Remotes.Name = "TycoonRemotes"
Remotes.Parent = ReplicatedStorage

-- Create remote events and functions
local remotes = {
	-- Events
	CashUpdated = Instance.new("RemoteEvent"),
	GamepassPurchased = Instance.new("RemoteEvent"),
	AutoCollectToggle = Instance.new("RemoteEvent"),
	GrantProductCurrency = Instance.new("RemoteEvent"),
	
	-- Functions
	GetPlayerData = Instance.new("RemoteFunction"),
	GetAutoCollectState = Instance.new("RemoteFunction"),
	PurchaseWithCash = Instance.new("RemoteFunction"),
}

-- Parent all remotes
for name, remote in pairs(remotes) do
	remote.Name = name
	remote.Parent = Remotes
end

-- Data stores
local playerDataStore = DataStoreService:GetDataStore("PlayerData_v1")
local settingsDataStore = DataStoreService:GetDataStore("PlayerSettings_v1")

-- Player data cache
local playerData = {}
local autoCollectStates = {}

-- Product IDs (match with client)
local PRODUCT_IDS = {
	cash = {
		[1897730242] = 1000,
		[1897730373] = 5000,
		[1897730467] = 10000,
		[1897730581] = 50000,
		[1897730682] = 100000,
		[1897730783] = 250000,
	},
	
	passes = {
		[1412171840] = "AutoCollect",
		[1398974710] = "DoubleCash",
		[1398974811] = "VIPAccess",
		[1398974912] = "SpeedBoost",
	},
}

-- Initialize player data
local function initializePlayer(player)
	local data = {
		cash = 0,
		totalEarned = 0,
		totalSpent = 0,
		ownedPasses = {},
		purchaseHistory = {},
		lastSave = os.time(),
	}
	
	-- Load from datastore
	local success, savedData = pcall(function()
		return playerDataStore:GetAsync("Player_" .. player.UserId)
	end)
	
	if success and savedData then
		for key, value in pairs(savedData) do
			data[key] = value
		end
	end
	
	-- Check owned gamepasses
	for passId, passName in pairs(PRODUCT_IDS.passes) do
		local owns = false
		pcall(function()
			owns = MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		
		if owns then
			data.ownedPasses[passId] = true
		end
	end
	
	playerData[player] = data
	
	-- Load settings
	local settingsSuccess, settings = pcall(function()
		return settingsDataStore:GetAsync("Settings_" .. player.UserId)
	end)
	
	if settingsSuccess and settings and settings.autoCollect ~= nil then
		autoCollectStates[player] = settings.autoCollect
	else
		autoCollectStates[player] = false
	end
	
	-- Create leaderstats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = data.cash
	cash.Parent = leaderstats
	
	-- Send initial data
	remotes.CashUpdated:FireClient(player, data.cash)
end

-- Save player data
local function savePlayerData(player)
	local data = playerData[player]
	if not data then return end
	
	data.lastSave = os.time()
	
	pcall(function()
		playerDataStore:SetAsync("Player_" .. player.UserId, data)
	end)
	
	-- Save settings
	pcall(function()
		settingsDataStore:SetAsync("Settings_" .. player.UserId, {
			autoCollect = autoCollectStates[player] or false,
		})
	end)
end

-- Update player cash
local function updatePlayerCash(player, amount, reason)
	local data = playerData[player]
	if not data then return end
	
	data.cash = math.max(0, data.cash + amount)
	
	if amount > 0 then
		data.totalEarned = data.totalEarned + amount
	else
		data.totalSpent = data.totalSpent + math.abs(amount)
	end
	
	-- Update leaderstats
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local cash = leaderstats:FindFirstChild("Cash")
		if cash then
			cash.Value = data.cash
		end
	end
	
	-- Notify client
	remotes.CashUpdated:FireClient(player, data.cash)
	
	-- Log transaction
	table.insert(data.purchaseHistory, {
		amount = amount,
		reason = reason,
		timestamp = os.time(),
	})
	
	-- Keep only last 100 transactions
	if #data.purchaseHistory > 100 then
		table.remove(data.purchaseHistory, 1)
	end
end

-- Remote handlers
remotes.GetPlayerData.OnServerInvoke = function(player)
	local data = playerData[player]
	if not data then return nil end
	
	return {
		cash = data.cash,
		ownedPasses = data.ownedPasses,
		autoCollect = autoCollectStates[player] or false,
	}
end

remotes.GetAutoCollectState.OnServerInvoke = function(player)
	return autoCollectStates[player] or false
end

remotes.AutoCollectToggle.OnServerEvent:Connect(function(player, state)
	if type(state) ~= "boolean" then return end
	
	local data = playerData[player]
	if not data or not data.ownedPasses[1412171840] then return end
	
	autoCollectStates[player] = state
end)

remotes.GamepassPurchased.OnServerEvent:Connect(function(player, passId)
	local data = playerData[player]
	if not data then return end
	
	-- Verify ownership
	local owns = false
	pcall(function()
		owns = MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	
	if owns then
		data.ownedPasses[passId] = true
	end
end)

remotes.PurchaseWithCash.OnServerInvoke = function(player, productId, productType)
	local data = playerData[player]
	if not data then return false, "No player data" end
	
	-- Validate product
	local price = 0
	local productName = ""
	
	if productType == "powerup" then
		-- Handle powerup purchases
		-- You would define powerup prices here
		return false, "Powerups not implemented"
	else
		return false, "Invalid product type"
	end
	
	-- Check if player has enough cash
	if data.cash < price then
		return false, "Insufficient funds"
	end
	
	-- Deduct cash and grant product
	updatePlayerCash(player, -price, "Purchased " .. productName)
	
	-- Grant product effects here
	
	return true, "Purchase successful"
end

-- Process developer product purchases
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	local productId = receiptInfo.ProductId
	local cashAmount = PRODUCT_IDS.cash[productId]
	
	if cashAmount then
		updatePlayerCash(player, cashAmount, "Purchased " .. cashAmount .. " cash")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Auto collect loop
local autoCollectLoop = coroutine.create(function()
	while true do
		for player, enabled in pairs(autoCollectStates) do
			if enabled and player.Parent then
				local data = playerData[player]
				if data and data.ownedPasses[1412171840] then
					-- Grant auto-collect bonus
					local bonus = 100 -- Base amount
					
					-- Apply multipliers
					if data.ownedPasses[1398974710] then -- 2x Cash
						bonus = bonus * 2
					end
					
					updatePlayerCash(player, bonus, "Auto Collect")
				end
			end
		end
		
		task.wait(60) -- Every minute
	end
end)

coroutine.resume(autoCollectLoop)

-- Periodic save
local saveLoop = coroutine.create(function()
	while true do
		for player, _ in pairs(playerData) do
			if player.Parent then
				savePlayerData(player)
			end
		end
		
		task.wait(60) -- Save every minute
	end
end)

coroutine.resume(saveLoop)

-- Player events
Players.PlayerAdded:Connect(initializePlayer)

Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player)
	playerData[player] = nil
	autoCollectStates[player] = nil
end)

-- Server shutdown
game:BindToClose(function()
	for player, _ in pairs(playerData) do
		savePlayerData(player)
	end
	task.wait(2)
end)

print("[TycoonShop Server] Initialized successfully!")