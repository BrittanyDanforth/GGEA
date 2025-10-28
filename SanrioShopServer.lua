--[[
    SANRIO SHOP SERVER HANDLER (FIXED - NO PROCESSRECEIPT CONFLICT)
    Place this as a Script in ServerScriptService
    Name it: SanrioShopServer
    
    This handles ONLY:
    1. Gamepass ownership verification
    2. Auto-collect toggle state
    3. Gamepass purchase notifications to client
    
    NOTE: Developer Products (cash) are handled by MoneyShop.server.lua
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("🛍️ [SanrioShop] Initializing gamepass handler...")

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
local AutoCollectToggle = createRemote("AutoCollectToggle", "RemoteEvent")
local GetAutoCollectState = createRemote("GetAutoCollectState", "RemoteFunction")

-- Data store for auto-collect states
local AutoCollectDataStore = DataStoreService:GetDataStore("AutoCollectStates")
local playerAutoCollectStates = {}

-- Gamepass IDs
local GAMEPASSES = {
	AUTO_COLLECT = 1412171840,
	DOUBLE_CASH = 1398974710,
}

print("🛍️ [SanrioShop] Gamepasses configured:")
print("   🤖 Auto Collect: " .. GAMEPASSES.AUTO_COLLECT)
print("   💰 2x Cash: " .. GAMEPASSES.DOUBLE_CASH)

-- ========================================
-- AUTO-COLLECT TOGGLE HANDLERS
-- ========================================

-- Handle auto-collect toggle
AutoCollectToggle.OnServerEvent:Connect(function(player, enabled)
	-- Verify ownership
	local owns = false
	local success = pcall(function()
		owns = MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASSES.AUTO_COLLECT)
	end)
	
	if not success or not owns then
		warn(string.format("[SanrioShop] ❌ %s tried to toggle Auto-Collect but doesn't own it", player.Name))
		return
	end
	
	-- Update state
	playerAutoCollectStates[player.UserId] = enabled
	
	-- Save to datastore
	pcall(function()
		AutoCollectDataStore:SetAsync(tostring(player.UserId), enabled)
	end)
	
	print(string.format("[SanrioShop] 🔄 Auto-collect %s for %s", enabled and "ENABLED" or "DISABLED", player.Name))
	
	-- Here you would enable/disable auto collection in your tycoon
	-- Example: Enable/disable the collection loop for this player
end)

-- Get auto-collect state
GetAutoCollectState.OnServerInvoke = function(player)
	-- Verify ownership
	local owns = false
	pcall(function()
		owns = MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASSES.AUTO_COLLECT)
	end)
	
	if not owns then
		return false
	end
	
	-- Return saved state (default to true if not set)
	local state = playerAutoCollectStates[player.UserId]
	if state == nil then
		state = true -- Default to enabled
	end
	
	return state
end

-- ========================================
-- GAMEPASS PURCHASE DETECTION
-- ========================================

-- Handle gamepass purchases (for immediate UI updates)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
	print(string.format("🛍️ [SanrioShop] Purchase prompt finished - Player: %s, PassID: %d, Purchased: %s", 
		player.Name, passId, tostring(wasPurchased)))
	
	if wasPurchased then
		print(string.format("⏳ [SanrioShop] Waiting for Roblox to register purchase..."))
		
		-- Wait longer for Roblox to fully process the purchase
		task.wait(1.2)
		
		-- Verify ownership
		local verified = false
		pcall(function()
			verified = MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		
		if verified then
			print(string.format("✅ [SanrioShop] Ownership verified for %s (passId: %d)", player.Name, passId))
			
			-- Notify client to update UI
			GamepassPurchased:FireClient(player, passId)
			print(string.format("📡 [SanrioShop] Sent GamepassPurchased event to %s", player.Name))
			
			-- Special handling for auto-collect
			if passId == GAMEPASSES.AUTO_COLLECT then
				playerAutoCollectStates[player.UserId] = true
				print(string.format("🤖 [SanrioShop] Auto-Collect enabled by default for %s", player.Name))
			end
		else
			warn(string.format("⚠️ [SanrioShop] Purchase completed but ownership not verified for %s", player.Name))
			warn(string.format("⚠️ [SanrioShop] This might mean Roblox is still processing. Retrying..."))
			
			-- Retry once after additional delay
			task.wait(1.0)
			pcall(function()
				verified = MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			
			if verified then
				print(string.format("✅ [SanrioShop] Ownership verified on retry for %s", player.Name))
				GamepassPurchased:FireClient(player, passId)
			else
				warn(string.format("❌ [SanrioShop] Ownership still not verified for %s (passId: %d)", player.Name, passId))
			end
		end
	else
		print(string.format("❌ [SanrioShop] %s cancelled purchase (passId: %d)", player.Name, passId))
	end
end)

-- ========================================
-- PLAYER DATA MANAGEMENT
-- ========================================

-- Load player data when they join
Players.PlayerAdded:Connect(function(player)
	print(string.format("[SanrioShop] 👤 %s joined - loading gamepass data...", player.Name))
	
	-- Check Auto-Collect ownership
	local ownsAutoCollect = false
	pcall(function()
		ownsAutoCollect = MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASSES.AUTO_COLLECT)
	end)
	
	if ownsAutoCollect then
		-- Load saved auto-collect state
		local success, savedState = pcall(function()
			return AutoCollectDataStore:GetAsync(tostring(player.UserId))
		end)
		
		if success and savedState ~= nil then
			playerAutoCollectStates[player.UserId] = savedState
			print(string.format("[SanrioShop] ✅ Loaded Auto-Collect state for %s: %s", 
				player.Name, tostring(savedState)))
		else
			playerAutoCollectStates[player.UserId] = true -- Default to enabled
			print(string.format("[SanrioShop] ✅ Auto-Collect set to default (ON) for %s", player.Name))
		end
	end
	
	-- Small delay then notify client of owned gamepasses
	task.wait(1)
	
	for name, passId in pairs(GAMEPASSES) do
		local owns = false
		pcall(function()
			owns = MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		
		if owns then
			GamepassPurchased:FireClient(player, passId)
			print(string.format("[SanrioShop] 📡 Notified %s about owned pass: %s", player.Name, name))
		end
	end
end)

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(player)
	playerAutoCollectStates[player.UserId] = nil
	print(string.format("[SanrioShop] 👋 Cleaned up data for %s", player.Name))
end)

-- ========================================
-- INITIALIZATION COMPLETE
-- ========================================

print("✅ [SanrioShop] Server handler ready!")
print("📦 Features:")
print("   ✓ Gamepass purchase detection")
print("   ✓ Auto-collect toggle system")
print("   ✓ State persistence (DataStore)")
print("   ✓ Ownership verification")
print("⚠️  NOTE: Cash products handled by MoneyShop.server.lua")

return true
