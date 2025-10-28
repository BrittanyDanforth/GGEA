--[[
    SANRIO TYCOON SERVER
    Place in: ServerScriptService
    Name: SANRIOTYCOONSERVER
    
    Handles:
    - Remote events/functions creation
    - Gamepass purchase detection
    - Auto-collect toggle system
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("🌸 [SANRIOTYCOONSERVER] Initializing...")

-- ========================================
-- SETUP REMOTES FOLDER
-- ========================================

local function GetOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
		print("📁 [SANRIOTYCOONSERVER] Created folder:", name)
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
		print("✓ [SANRIOTYCOONSERVER] Created remote:", name)
	end
	return remote
end

-- Create all remotes
local GamepassPurchased = CreateRemote(RemotesFolder, "GamepassPurchased", "RemoteEvent")
local AutoCollectToggle = CreateRemote(RemotesFolder, "AutoCollectToggle", "RemoteEvent")
local GetAutoCollectState = CreateRemote(RemotesFolder, "GetAutoCollectState", "RemoteFunction")
local GrantProductCurrency = CreateRemote(RemotesFolder, "GrantProductCurrency", "RemoteEvent")
local MoneyCollected = CreateRemote(RemotesFolder, "MoneyCollected", "RemoteEvent")

print("✅ [SANRIOTYCOONSERVER] Remotes created!")

-- ========================================
-- GAMEPASS SYSTEM
-- ========================================

local AutoCollectDataStore = DataStoreService:GetDataStore("AutoCollectStates")
local playerAutoCollectStates = {}

-- Track recent purchases to prevent duplicate notifications
local recentPurchases = {}

local GAMEPASSES = {
	AUTO_COLLECT = 1412171840,
	DOUBLE_CASH = 1398974710,
}

print("🎮 [SANRIOTYCOONSERVER] Gamepasses:")
print("   🤖 Auto Collect:", GAMEPASSES.AUTO_COLLECT)
print("   💰 2x Cash:", GAMEPASSES.DOUBLE_CASH)

-- Auto-collect toggle handler
AutoCollectToggle.OnServerEvent:Connect(function(player, enabled)
	local owns = false
	pcall(function()
		owns = MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASSES.AUTO_COLLECT)
	end)
	
	if not owns then
		warn("❌ [SANRIOTYCOONSERVER]", player.Name, "doesn't own Auto-Collect")
		return
	end
	
	playerAutoCollectStates[player.UserId] = enabled
	
	pcall(function()
		AutoCollectDataStore:SetAsync(tostring(player.UserId), enabled)
	end)
	
	print("🔄 [SANRIOTYCOONSERVER] Auto-collect", enabled and "ON" or "OFF", "for", player.Name)
end)

-- Get auto-collect state
GetAutoCollectState.OnServerInvoke = function(player)
	local owns = false
	pcall(function()
		owns = MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASSES.AUTO_COLLECT)
	end)
	
	if not owns then return false end
	
	local state = playerAutoCollectStates[player.UserId]
	if state == nil then state = true end
	
	return state
end

-- Gamepass purchase detection (FIXED: Waits for Roblox to register)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
	print("🛍️ [SANRIOTYCOONSERVER] Purchase prompt:", player.Name, passId, wasPurchased)
	
	if wasPurchased then
		print("⏳ [SANRIOTYCOONSERVER] Waiting for Roblox to register purchase...")
		
		-- Wait longer for Roblox to process
		task.wait(1.2)
		
		-- Verify ownership
		local verified = false
		pcall(function()
			verified = MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		
		if verified then
			print("✅ [SANRIOTYCOONSERVER] Ownership verified for", player.Name)
			
			-- Track this purchase to prevent duplicate notifications
			local purchaseKey = tostring(player.UserId) .. "_" .. tostring(passId)
			recentPurchases[purchaseKey] = tick()
			
			-- Notify client to update UI
			GamepassPurchased:FireClient(player, passId)
			print("📡 [SANRIOTYCOONSERVER] Sent GamepassPurchased event")
			
			-- Enable auto-collect by default
			if passId == GAMEPASSES.AUTO_COLLECT then
				playerAutoCollectStates[player.UserId] = true
				print("🤖 [SANRIOTYCOONSERVER] Auto-Collect enabled for", player.Name)
			end
		else
			warn("⚠️ [SANRIOTYCOONSERVER] Ownership not verified, retrying...")
			
			-- Retry once
			task.wait(1.0)
			pcall(function()
				verified = MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			
			if verified then
				print("✅ [SANRIOTYCOONSERVER] Verified on retry!")
				
				-- Track this purchase to prevent duplicate notifications
				local purchaseKey = tostring(player.UserId) .. "_" .. tostring(passId)
				recentPurchases[purchaseKey] = tick()
				
				GamepassPurchased:FireClient(player, passId)
			else
				warn("❌ [SANRIOTYCOONSERVER] Still not verified for", player.Name, passId)
			end
		end
	end
end)

-- Player join: load auto-collect state
Players.PlayerAdded:Connect(function(player)
	print("👤 [SANRIOTYCOONSERVER]", player.Name, "joined")
	
	local ownsAutoCollect = false
	pcall(function()
		ownsAutoCollect = MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASSES.AUTO_COLLECT)
	end)
	
	if ownsAutoCollect then
		local success, savedState = pcall(function()
			return AutoCollectDataStore:GetAsync(tostring(player.UserId))
		end)
		
		if success and savedState ~= nil then
			playerAutoCollectStates[player.UserId] = savedState
			print("✅ [SANRIOTYCOONSERVER] Loaded Auto-Collect state:", savedState)
		else
			playerAutoCollectStates[player.UserId] = true
			print("✅ [SANRIOTYCOONSERVER] Auto-Collect default: ON")
		end
	end
	
	-- Notify client of owned gamepasses (skip recently purchased ones to avoid duplicates)
	task.wait(1)
	
	for name, passId in pairs(GAMEPASSES) do
		local owns = false
		pcall(function()
			owns = MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		
		if owns then
			-- Check if this was recently purchased (within last 30 seconds)
			local purchaseKey = tostring(player.UserId) .. "_" .. tostring(passId)
			local recentTime = recentPurchases[purchaseKey]
			
			if recentTime and (tick() - recentTime) < 30 then
				print("⏸️ [SANRIOTYCOONSERVER] Skipping notification for", name, "- recently purchased")
			else
				GamepassPurchased:FireClient(player, passId)
				print("📡 [SANRIOTYCOONSERVER] Notified", player.Name, "owns", name)
			end
		end
	end
end)

-- Player leave: cleanup
Players.PlayerRemoving:Connect(function(player)
	playerAutoCollectStates[player.UserId] = nil
	
	-- Clean up recent purchases for this player
	for key in pairs(recentPurchases) do
		if key:match("^" .. tostring(player.UserId) .. "_") then
			recentPurchases[key] = nil
		end
	end
	
	print("👋 [SANRIOTYCOONSERVER] Cleaned up", player.Name)
end)

-- Periodic cleanup of old purchase records (every 60 seconds)
task.spawn(function()
	while true do
		task.wait(60)
		local now = tick()
		local cleaned = 0
		for key, time in pairs(recentPurchases) do
			if now - time > 60 then
				recentPurchases[key] = nil
				cleaned = cleaned + 1
			end
		end
		if cleaned > 0 then
			print("🧹 [SANRIOTYCOONSERVER] Cleaned", cleaned, "old purchase records")
		end
	end
end)

-- ========================================
-- DONE
-- ========================================

print("✅ [SANRIOTYCOONSERVER] Ready!")
print("📦 Features:")
print("   ✓ Remotes created in TycoonRemotes")
print("   ✓ Gamepass purchase detection")
print("   ✓ Auto-collect toggle system")
print("   ✓ State persistence")
print("⚠️  Cash products handled by MONEYSHOPSERV")

return true
