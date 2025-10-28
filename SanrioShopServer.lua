--[[
    SANRIO SHOP SERVER (Gamepass Handler)
    Place in: ServerScriptService
    Name: SanrioShopServer
    
    Handles ONLY gamepass-related logic:
    - Gamepass purchase verification and notifications
    - Auto-collect toggle state management
    - State persistence in DataStore
    
    ⚠️ NOTE: Developer Products (cash) are handled by MONEYSHOPSERV script
    ⚠️ This script does NOT set MarketplaceService.ProcessReceipt!
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("🎀 [SanrioShopServer] Initializing gamepass handler...")

-- ========================================
-- SETUP REMOTES
-- ========================================

local function GetOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local RemotesFolder = GetOrCreateFolder(ReplicatedStorage, "TycoonRemotes")

local function CreateRemote(folder, name, className)
	local remote = folder:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		print("✓ [SanrioShopServer] Created remote:", name)
	end
	return remote
end

local GamepassPurchased = CreateRemote(RemotesFolder, "GamepassPurchased", "RemoteEvent")
local AutoCollectToggle = CreateRemote(RemotesFolder, "AutoCollectToggle", "RemoteEvent")
local GetAutoCollectState = CreateRemote(RemotesFolder, "GetAutoCollectState", "RemoteFunction")

-- ========================================
-- DATA STORAGE
-- ========================================

local AutoCollectDataStore = DataStoreService:GetDataStore("AutoCollectStates")
local playerAutoCollectStates = {}

-- ========================================
-- GAMEPASS CONFIGURATION
-- ========================================

local GAMEPASSES = {
	AUTO_COLLECT = 1412171840,
	DOUBLE_CASH = 1398974710,
}

print("🎮 [SanrioShopServer] Gamepasses configured:")
print("   🤖 Auto Collect:", GAMEPASSES.AUTO_COLLECT)
print("   💰 2x Cash:", GAMEPASSES.DOUBLE_CASH)

-- ========================================
-- AUTO-COLLECT TOGGLE HANDLERS
-- ========================================

-- Handle auto-collect toggle from client
AutoCollectToggle.OnServerEvent:Connect(function(player, enabled)
	-- Verify ownership first
	local owns = false
	local success = pcall(function()
		owns = MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASSES.AUTO_COLLECT)
	end)
	
	if not success or not owns then
		warn(string.format("❌ [SanrioShopServer] %s tried to toggle Auto-Collect but doesn't own it", player.Name))
		return
	end
	
	-- Update state
	playerAutoCollectStates[player.UserId] = enabled
	
	-- Save to DataStore
	pcall(function()
		AutoCollectDataStore:SetAsync(tostring(player.UserId), enabled)
	end)
	
	print(string.format("🔄 [SanrioShopServer] Auto-collect %s for %s", 
		enabled and "ENABLED" or "DISABLED", player.Name))
	
	-- TODO: Enable/disable auto collection in your tycoon here
	-- Example: Update the player's tycoon dropper or collection system
end)

-- Get current auto-collect state
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

-- ✅ FIXED: Longer wait time and retry logic for reliable ownership verification
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
	print(string.format("🛍️ [SanrioShopServer] Purchase prompt finished - Player: %s, PassID: %d, Purchased: %s", 
		player.Name, passId, tostring(wasPurchased)))
	
	if wasPurchased then
		print(string.format("⏳ [SanrioShopServer] Waiting for Roblox to register purchase..."))
		
		-- Wait longer for Roblox to fully process the purchase
		task.wait(1.2)
		
		-- Verify ownership
		local verified = false
		pcall(function()
			verified = MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		
		if verified then
			print(string.format("✅ [SanrioShopServer] Ownership verified for %s (passId: %d)", player.Name, passId))
			
			-- Notify client to update UI
			GamepassPurchased:FireClient(player, passId)
			print(string.format("📡 [SanrioShopServer] Sent GamepassPurchased event to %s", player.Name))
			
			-- Special handling for auto-collect
			if passId == GAMEPASSES.AUTO_COLLECT then
				playerAutoCollectStates[player.UserId] = true
				print(string.format("🤖 [SanrioShopServer] Auto-Collect enabled by default for %s", player.Name))
			end
		else
			warn(string.format("⚠️ [SanrioShopServer] Purchase completed but ownership not verified for %s", player.Name))
			warn(string.format("⚠️ [SanrioShopServer] This might mean Roblox is still processing. Retrying..."))
			
			-- Retry once after additional delay
			task.wait(1.0)
			pcall(function()
				verified = MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			
			if verified then
				print(string.format("✅ [SanrioShopServer] Ownership verified on retry for %s", player.Name))
				GamepassPurchased:FireClient(player, passId)
			else
				warn(string.format("❌ [SanrioShopServer] Ownership still not verified for %s (passId: %d)", player.Name, passId))
			end
		end
	else
		print(string.format("❌ [SanrioShopServer] %s cancelled purchase (passId: %d)", player.Name, passId))
	end
end)

-- ========================================
-- PLAYER DATA MANAGEMENT
-- ========================================

-- Load player data when they join
Players.PlayerAdded:Connect(function(player)
	print(string.format("👤 [SanrioShopServer] %s joined - loading gamepass data...", player.Name))
	
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
			print(string.format("✅ [SanrioShopServer] Loaded Auto-Collect state for %s: %s", 
				player.Name, tostring(savedState)))
		else
			playerAutoCollectStates[player.UserId] = true -- Default to enabled
			print(string.format("✅ [SanrioShopServer] Auto-Collect set to default (ON) for %s", player.Name))
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
			print(string.format("📡 [SanrioShopServer] Notified %s about owned pass: %s", player.Name, name))
		end
	end
end)

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(player)
	playerAutoCollectStates[player.UserId] = nil
	print(string.format("👋 [SanrioShopServer] Cleaned up data for %s", player.Name))
end)

-- ========================================
-- INITIALIZATION COMPLETE
-- ========================================

print("✅ [SanrioShopServer] Gamepass handler ready!")
print("📦 Features:")
print("   ✓ Gamepass purchase detection with retry logic")
print("   ✓ Auto-collect toggle system")
print("   ✓ State persistence (DataStore)")
print("   ✓ Ownership verification")
print("⚠️  NOTE: Cash products handled by MONEYSHOPSERV script")
print("⚠️  This script does NOT set ProcessReceipt (no conflicts!)")

return true
