-- Auto Collect Toggle Handler
-- Place this in ServerScriptService

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Configuration
local AUTO_COLLECT_PASS_ID = 1412171840

-- Get or create remotes folder
local remotesFolder = ReplicatedStorage:FindFirstChild("TycoonRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "TycoonRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

-- Create remotes if they don't exist
local toggleRemote = remotesFolder:FindFirstChild("AutoCollectToggle")
if not toggleRemote then
	toggleRemote = Instance.new("RemoteEvent")
	toggleRemote.Name = "AutoCollectToggle"
	toggleRemote.Parent = remotesFolder
end

local stateRemote = remotesFolder:FindFirstChild("GetAutoCollectState")
if not stateRemote then
	stateRemote = Instance.new("RemoteFunction")
	stateRemote.Name = "GetAutoCollectState"
	stateRemote.Parent = remotesFolder
end

-- Handle toggle requests
toggleRemote.OnServerEvent:Connect(function(player, requestedState)
	-- Verify ownership
	local ownsPass = false
	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, AUTO_COLLECT_PASS_ID)
	end)
	
	if success then
		ownsPass = result
	else
		warn("Failed to check gamepass ownership:", result)
		return
	end
	
	if not ownsPass then
		warn("Player", player.Name, "tried to toggle auto-collect without owning the pass!")
		return
	end
	
	-- Set the state as an attribute
	player:SetAttribute("AutoCollectEnabled", requestedState == true)
	print("✅ Auto-collect", requestedState and "enabled" or "disabled", "for", player.Name)
	
	-- Here you would implement the actual auto-collect logic
	-- For example, starting/stopping a collection loop for this player
	if requestedState then
		-- Start auto collection for this player
		-- This is where you'd connect to your tycoon's collection system
	else
		-- Stop auto collection for this player
	end
end)

-- Handle state queries
stateRemote.OnServerInvoke = function(player)
	-- First check if they own the pass
	local ownsPass = false
	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, AUTO_COLLECT_PASS_ID)
	end)
	
	if success and result then
		-- Return their saved state
		return player:GetAttribute("AutoCollectEnabled") == true
	end
	
	return false
end

-- Initialize new players
Players.PlayerAdded:Connect(function(player)
	-- Set default state
	player:SetAttribute("AutoCollectEnabled", false)
end)

print("🔄 Auto Collect handler ready!")
print("🎫 Pass ID:", AUTO_COLLECT_PASS_ID)