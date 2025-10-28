--[[
    SANRIO SHOP SERVER HANDLER
    Place this as a Script in ServerScriptService
    Name it: SanrioShopHandler
    
    This handles:
    1. Product purchases
    2. Gamepass verification
    3. Currency granting
    4. Auto-collect toggle state
--]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create remotes folder
local Remotes = ReplicatedStorage:FindFirstChild("TycoonRemotes") or Instance.new("Folder")
Remotes.Name = "TycoonRemotes"
Remotes.Parent = ReplicatedStorage

-- Create remote events/functions
local function createRemote(name, className)
	local remote = Remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote
end

local GamepassPurchased = createRemote("GamepassPurchased", "RemoteEvent")
local ProductGranted = createRemote("ProductGranted", "RemoteEvent")
local GrantProductCurrency = createRemote("GrantProductCurrency", "RemoteEvent")
local AutoCollectToggle = createRemote("AutoCollectToggle", "RemoteEvent")
local GetAutoCollectState = createRemote("GetAutoCollectState", "RemoteFunction")

-- Data stores
local AutoCollectDataStore = DataStoreService:GetDataStore("AutoCollectStates")
local playerAutoCollectStates = {}

-- Product IDs mapping (UPDATED TO MATCH YOUR GAME)
local PRODUCTS = {
	[3366419712] = {amount = 1000, name = "1,000 Cash"},
	[3366420012] = {amount = 5000, name = "5,000 Cash"},
	[3366420478] = {amount = 10000, name = "10,000 Cash"},
	[3366420800] = {amount = 25000, name = "25,000 Cash"},
	[3424973374] = {amount = 50000, name = "50,000 Cash"},
	[3424974046] = {amount = 100000, name = "100,000 Cash"},
	[3424974161] = {amount = 250000, name = "250,000 Cash"},
	[3424974327] = {amount = 500000, name = "500,000 Cash"},
	[3424974402] = {amount = 1000000, name = "1,000,000 Cash"},
}

-- Gamepass IDs
local GAMEPASSES = {
	AUTO_COLLECT = 1412171840,
	DOUBLE_CASH = 1398974710,
}

-- Helper function to grant currency
local function grantCurrency(player, amount)
	-- Try ServerStorage.PlayerMoney first (your system)
	local ServerStorage = game:GetService("ServerStorage")
	local PlayerMoney = ServerStorage:FindFirstChild("PlayerMoney")
	if PlayerMoney then
		local playerMoney = PlayerMoney:FindFirstChild(player.Name)
		if playerMoney and (playerMoney:IsA("IntValue") or playerMoney:IsA("NumberValue")) then
			playerMoney.Value = playerMoney.Value + amount
			print(string.format("[SanrioShop] ✅ Granted %d cash via ServerStorage.PlayerMoney", amount))
			return true
		end
	end
	
	-- Fallback: Try leaderstats
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local cash = leaderstats:FindFirstChild("Cash") or leaderstats:FindFirstChild("Money")
		if cash and (cash:IsA("IntValue") or cash:IsA("NumberValue")) then
			cash.Value = cash.Value + amount
			print(string.format("[SanrioShop] ✅ Granted %d cash via leaderstats", amount))
			return true
		end
	end
	
	-- Alternative: Look for a player data module
	local playerData = player:FindFirstChild("Data")
	if playerData then
		local cash = playerData:FindFirstChild("Cash")
		if cash and (cash:IsA("IntValue") or cash:IsA("NumberValue")) then
			cash.Value = cash.Value + amount
			print(string.format("[SanrioShop] ✅ Granted %d cash via Data folder", amount))
			return true
		end
	end
	
	warn(string.format("[SanrioShop] ❌ Could not find money value for %s", player.Name))
	return false
end

-- Handle product purchases
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	local productInfo = PRODUCTS[receiptInfo.ProductId]
	if productInfo then
		-- Grant the currency
		local success = grantCurrency(player, productInfo.amount)
		
		if success then
			-- Fire client event
			ProductGranted:FireClient(player, receiptInfo.ProductId, productInfo.amount)
			
			print(string.format("[SanrioShop] Granted %d cash to %s", productInfo.amount, player.Name))
			return Enum.ProductPurchaseDecision.PurchaseGranted
		else
			warn(string.format("[SanrioShop] Failed to grant currency to %s", player.Name))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end
	
	-- Unknown product
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Handle auto-collect toggle
AutoCollectToggle.OnServerEvent:Connect(function(player, enabled)
	if not MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASSES.AUTO_COLLECT) then
		return -- Player doesn't own the gamepass
	end
	
	playerAutoCollectStates[player.UserId] = enabled
	
	-- Save to datastore
	pcall(function()
		AutoCollectDataStore:SetAsync(tostring(player.UserId), enabled)
	end)
	
	-- Here you would enable/disable auto collection for the player
	-- This depends on your tycoon implementation
	
	print(string.format("[SanrioShop] Auto-collect set to %s for %s", tostring(enabled), player.Name))
end)

-- Get auto-collect state
GetAutoCollectState.OnServerInvoke = function(player)
	if not MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASSES.AUTO_COLLECT) then
		return false
	end
	
	return playerAutoCollectStates[player.UserId] or false
end

-- Load player data
Players.PlayerAdded:Connect(function(player)
	-- Load auto-collect state
	if MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASSES.AUTO_COLLECT) then
		local success, state = pcall(function()
			return AutoCollectDataStore:GetAsync(tostring(player.UserId))
		end)
		
		if success and state ~= nil then
			playerAutoCollectStates[player.UserId] = state
		else
			playerAutoCollectStates[player.UserId] = true -- Default to enabled
		end
	end
	
	-- Check gamepass ownership and notify client
	task.wait(1)
	for name, passId in pairs(GAMEPASSES) do
		if MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId) then
			GamepassPurchased:FireClient(player, passId)
		end
	end
end)

-- Clean up on player leave
Players.PlayerRemoving:Connect(function(player)
	playerAutoCollectStates[player.UserId] = nil
end)

-- Handle gamepass purchases (for immediate updates)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	print(string.format("🛍️ [SanrioShop] PromptGamePassPurchaseFinished - Player: %s, PassID: %d, Purchased: %s", player.Name, passId, tostring(purchased)))
	
	if purchased then
		-- Wait a moment for Roblox systems to register the purchase
		task.wait(0.5)
		
		-- Verify ownership
		local verified = false
		pcall(function()
			verified = MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		
		print(string.format("🔍 [SanrioShop] Ownership verified: %s", tostring(verified)))
		
		-- Notify the client immediately
		GamepassPurchased:FireClient(player, passId)
		print(string.format("📡 [SanrioShop] Fired GamepassPurchased to client for passId: %d", passId))
		
		-- Special handling for auto-collect
		if passId == GAMEPASSES.AUTO_COLLECT then
			playerAutoCollectStates[player.UserId] = true
			print("🤖 [SanrioShop] Auto-Collect enabled for " .. player.Name)
		end
		
		print(string.format("✅ [SanrioShop] %s successfully purchased gamepass %d", player.Name, passId))
	else
		print(string.format("❌ [SanrioShop] %s cancelled gamepass %d purchase", player.Name, passId))
	end
end)

-- Alternative currency grant method (if direct remote is used)
GrantProductCurrency.OnServerEvent:Connect(function(player, productId)
	-- This is a backup method - normally ProcessReceipt should handle it
	-- Only use this if ProcessReceipt isn't working in your game
	
	warn("[SanrioShop] GrantProductCurrency called - this should be handled by ProcessReceipt")
end)

print("[SanrioShop] Server handler initialized")

return true