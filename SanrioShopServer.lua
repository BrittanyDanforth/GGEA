--[[
	🎀 SANRIO SHOP SERVER — Gamepass Confirmation Handler
	
	✅ Fires GamepassPurchased event to client
	✅ Provides current auto-collect state
	✅ Source of truth for ownership
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Setup remotes folder
local Remotes = ReplicatedStorage:FindFirstChild("TycoonRemotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "TycoonRemotes"
	Remotes.Parent = ReplicatedStorage
end

-- Create/get remotes
local GamepassPurchased = Remotes:FindFirstChild("GamepassPurchased")
if not GamepassPurchased then
	GamepassPurchased = Instance.new("RemoteEvent")
	GamepassPurchased.Name = "GamepassPurchased"
	GamepassPurchased.Parent = Remotes
end

local AutoCollectToggle = Remotes:FindFirstChild("AutoCollectToggle")
if not AutoCollectToggle then
	AutoCollectToggle = Instance.new("RemoteEvent")
	AutoCollectToggle.Name = "AutoCollectToggle"
	AutoCollectToggle.Parent = Remotes
end

local GetAutoCollectState = Remotes:FindFirstChild("GetAutoCollectState")
if not GetAutoCollectState then
	GetAutoCollectState = Instance.new("RemoteFunction")
	GetAutoCollectState.Name = "GetAutoCollectState"
	GetAutoCollectState.Parent = Remotes
end

-- Auto-collect state (per player)
local autoCollectState = {}

-- ✅ GAMEPASS PURCHASE CONFIRMATION (source of truth)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased then
		print("🎮 [ShopServer] Player", player.Name, "purchased gamepass:", passId)
		
		-- Wait a moment for Roblox to process
		task.wait(0.3)
		
		-- Get current auto-collect state if this is the auto-collect pass
		local currentState = autoCollectState[player.UserId]
		
		-- Fire to client (client trusts this as source of truth)
		GamepassPurchased:FireClient(player, passId, currentState)
		
		print("✅ [ShopServer] Confirmed purchase to client:", player.Name)
	end
end)

-- ✅ AUTO-COLLECT STATE MANAGEMENT
AutoCollectToggle.OnServerEvent:Connect(function(player, enabled)
	autoCollectState[player.UserId] = enabled
	print("🎚️ [ShopServer] Auto-collect for", player.Name, "→", enabled and "ON" or "OFF")
	
	-- You can add your actual auto-collect logic here
	-- For example:
	-- if enabled then
	--     -- Start auto-collecting for this player
	-- else
	--     -- Stop auto-collecting for this player
	-- end
end)

GetAutoCollectState.OnServerInvoke = function(player)
	-- Return current state (defaults to false if not set)
	return autoCollectState[player.UserId] or false
end

-- ✅ CLEANUP on player leave
game.Players.PlayerRemoving:Connect(function(player)
	autoCollectState[player.UserId] = nil
end)

print("✅ [ShopServer] Sanrio Shop server initialized!")
print("  📡 GamepassPurchased: Confirms purchases to clients")
print("  🎚️ AutoCollectToggle: Handles auto-collect state")
print("  📊 GetAutoCollectState: Returns current state")
