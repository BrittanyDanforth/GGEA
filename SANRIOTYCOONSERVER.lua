--[[
    SANRIO TYCOON SERVER
    Main server initialization for Sanrio Shop system
    Place in: ServerScriptService
    Name: SANRIOTYCOONSERVER
    
    This creates the remote events/functions needed for:
    - Shop UI communication
    - Gamepass handling
    - Auto-collect toggle
]]

local Services = {
	Players = game:GetService("Players"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	RunService = game:GetService("RunService"),
}

print("🌸 [SANRIOTYCOONSERVER] Initializing server...")

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

-- Create TycoonRemotes folder in ReplicatedStorage
local RemotesFolder = GetOrCreateFolder(Services.ReplicatedStorage, "TycoonRemotes")

-- ========================================
-- CREATE REMOTES
-- ========================================

local function CreateRemote(folder, name, className)
	if not folder then 
		warn("⚠️ [SANRIOTYCOONSERVER] Cannot create remote - folder is nil")
		return nil 
	end

	local existing = folder:FindFirstChild(name)
	if existing then 
		print("✓ [SANRIOTYCOONSERVER] Found existing remote:", name)
		return existing 
	end

	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	print("✓ [SANRIOTYCOONSERVER] Created remote:", name, "(" .. className .. ")")
	return remote
end

-- Create all remotes needed for the shop system
local Remotes = {
	-- Gamepass Events
	GamepassPurchased = CreateRemote(RemotesFolder, "GamepassPurchased", "RemoteEvent"),
	
	-- Auto-Collect System
	AutoCollectToggle = CreateRemote(RemotesFolder, "AutoCollectToggle", "RemoteEvent"),
	GetAutoCollectState = CreateRemote(RemotesFolder, "GetAutoCollectState", "RemoteFunction"),
	
	-- Currency (for studio testing fallback)
	GrantProductCurrency = CreateRemote(RemotesFolder, "GrantProductCurrency", "RemoteEvent"),
	
	-- Money collection (for tycoon integration)
	MoneyCollected = CreateRemote(RemotesFolder, "MoneyCollected", "RemoteEvent"),
}

-- ========================================
-- EXPORT FOR OTHER SCRIPTS
-- ========================================

_G.SanrioShopRemotes = Remotes

print("✅ [SANRIOTYCOONSERVER] Server initialized successfully!")
print("📡 Remotes created in: ReplicatedStorage.TycoonRemotes")
for name, remote in pairs(Remotes) do
	print("   •", name, "(" .. remote.ClassName .. ")")
end

return Remotes
