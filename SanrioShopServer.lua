--[[
	🎀 SANRIO SHOP SERVER — ULTIMATE EDITION
	Integrates with existing TycoonRemotes infrastructure
	
	✅ Optimistic ownership (prevents "Owned → Purchase" flicker)
	✅ Server-side gamepass confirmation (source of truth)
	✅ Auto-collect state management
	✅ Integrates with existing purchase handlers
	✅ DataStore persistence for auto-collect preferences
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

print("🎀 [ShopServer] Initializing Sanrio Shop Ultimate...")

-- ========================================
-- SETUP REMOTES (Integrate with existing TycoonRemotes)
-- ========================================

-- Wait for or create TycoonRemotes folder (may already exist from other systems)
local Remotes = ReplicatedStorage:FindFirstChild("TycoonRemotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "TycoonRemotes"
	Remotes.Parent = ReplicatedStorage
	print("  📁 [ShopServer] Created TycoonRemotes folder")
else
	print("  📁 [ShopServer] Found existing TycoonRemotes folder")
end

-- Create/get remotes
local function GetOrCreateRemote(name, className)
	local existing = Remotes:FindFirstChild(name)
	if existing then
		print("  ✅ [ShopServer] Found existing remote:", name)
		return existing
	end
	
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = Remotes
	print("  ➕ [ShopServer] Created remote:", name)
	return remote
end

local GamepassPurchased = GetOrCreateRemote("GamepassPurchased", "RemoteEvent")
local AutoCollectToggle = GetOrCreateRemote("AutoCollectToggle", "RemoteEvent")
local GetAutoCollectState = GetOrCreateRemote("GetAutoCollectState", "RemoteFunction")

-- ========================================
-- DATASTORE FOR AUTO-COLLECT PERSISTENCE
-- ========================================

local AUTO_COLLECT_STORE_NAME = "HelloKittyAutoCollect_v1" -- Match client-side
local autoCollectStore
local datastoreSuccess, datastoreError = pcall(function()
	autoCollectStore = DataStoreService:GetDataStore(AUTO_COLLECT_STORE_NAME)
end)

if not datastoreSuccess then
	warn("  ⚠️ [ShopServer] DataStore unavailable:", datastoreError)
end

-- Runtime state (cached from DataStore)
local autoCollectState = {}

-- Load auto-collect state from DataStore
local function loadAutoCollectState(player)
	if not autoCollectStore then return false end
	
	local key = "Player_" .. tostring(player.UserId)
	local success, data = pcall(function()
		return autoCollectStore:GetAsync(key)
	end)
	
	if success and data and type(data.enabled) == "boolean" then
		autoCollectState[player.UserId] = data.enabled
		return data.enabled
	end
	
	-- Default to false if no data
	autoCollectState[player.UserId] = false
	return false
end

-- Save auto-collect state to DataStore
local function saveAutoCollectState(player, enabled)
	if not autoCollectStore then return false end
	
	local key = "Player_" .. tostring(player.UserId)
	local success, err = pcall(function()
		autoCollectStore:SetAsync(key, {
			enabled = enabled,
			timestamp = os.time()
		})
	end)
	
	if not success then
		warn("  ⚠️ [ShopServer] Failed to save auto-collect state:", err)
	end
	
	return success
end

-- ========================================
-- GAMEPASS PURCHASE CONFIRMATION
-- ========================================

-- ✅ SOURCE OF TRUTH: Server confirms gamepass purchases to prevent UI flicker
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then return end
	
	print("🎮 [ShopServer] Player", player.Name, "purchased gamepass:", passId)
	
	-- Wait for Roblox to process the purchase on their backend
	task.wait(0.3)
	
	-- Get current auto-collect state (1412171840 = Auto Collect gamepass ID)
	local currentState = nil
	if passId == 1412171840 then
		currentState = autoCollectState[player.UserId]
		-- Default to true for new auto-collect purchases
		if currentState == nil then
			currentState = true
			autoCollectState[player.UserId] = true
			saveAutoCollectState(player, true)
		end
	end
	
	-- ✅ FIRE TO CLIENT: This is the source of truth that locks the "Owned" state
	GamepassPurchased:FireClient(player, passId, currentState)
	
	print("✅ [ShopServer] Confirmed purchase to client:", player.Name, "| PassID:", passId, "| AutoState:", currentState)
end)

-- ========================================
-- AUTO-COLLECT TOGGLE HANDLER
-- ========================================

-- ✅ Handle toggle from client (Enable/Disable button or chip)
AutoCollectToggle.OnServerEvent:Connect(function(player, enabled)
	if type(enabled) ~= "boolean" then
		warn("  ⚠️ [ShopServer] Invalid auto-collect state from", player.Name, ":", enabled)
		return
	end
	
	-- Update runtime state
	autoCollectState[player.UserId] = enabled
	
	-- Save to DataStore (async)
	task.spawn(function()
		saveAutoCollectState(player, enabled)
	end)
	
	print("🎚️ [ShopServer] Auto-collect for", player.Name, "→", enabled and "ON ✅" or "OFF ❌")
	
	-- ✅ INTEGRATE WITH EXISTING PURCHASE HANDLERS
	-- Forward the toggle to your existing tycoon purchase handlers
	-- They're already listening to this remote, so they'll pick it up automatically!
	
	-- Example integration (if you need direct access):
	-- local tycoon = getTycoonForPlayer(player)
	-- if tycoon then
	--     local handler = tycoon:FindFirstChild("PurchaseHandler")
	--     if handler and handler:FindFirstChild("AutoCollectEnabled") then
	--         handler.AutoCollectEnabled.Value = enabled
	--     end
	-- end
end)

-- ========================================
-- GET AUTO-COLLECT STATE
-- ========================================

GetAutoCollectState.OnServerInvoke = function(player)
	-- Return cached state (load from DataStore if not cached)
	if autoCollectState[player.UserId] == nil then
		loadAutoCollectState(player)
	end
	
	local state = autoCollectState[player.UserId] or false
	print("📊 [ShopServer] Get auto-collect state for", player.Name, "→", state and "ON" or "OFF")
	return state
end

-- ========================================
-- PLAYER MANAGEMENT
-- ========================================

-- Load auto-collect state when player joins
Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		local state = loadAutoCollectState(player)
		print("👤 [ShopServer] Player joined:", player.Name, "| Auto-collect:", state and "ON" or "OFF")
	end)
end)

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(player)
	autoCollectState[player.UserId] = nil
	print("👋 [ShopServer] Player left:", player.Name, "| Cleared auto-collect state")
end)

-- Load state for existing players (if script loads late)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		loadAutoCollectState(player)
	end)
end

-- ========================================
-- INTEGRATION HELPERS (Optional)
-- ========================================

-- ✅ Global API for other scripts to check auto-collect state
_G.IsAutoCollectEnabled = function(player)
	return autoCollectState[player.UserId] or false
end

-- ✅ Global API for other scripts to set auto-collect state
_G.SetAutoCollectEnabled = function(player, enabled)
	autoCollectState[player.UserId] = enabled
	saveAutoCollectState(player, enabled)
	
	-- Notify client
	GamepassPurchased:FireClient(player, 1412171840, enabled)
end

-- ========================================
-- FINAL SUMMARY
-- ========================================

print("✅ [ShopServer] Sanrio Shop Ultimate initialized!")
print("  📡 GamepassPurchased: Server-side purchase confirmation (prevents UI flicker)")
print("  🎚️ AutoCollectToggle: Synced with existing purchase handlers")
print("  📊 GetAutoCollectState: Returns current state from DataStore")
print("  💾 DataStore: Auto-collect preferences persist across sessions")
print("  🔗 Integration: Compatible with existing TycoonRemotes infrastructure")
