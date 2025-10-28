--[[
    SANRIO TYCOON SERVER
    Main server initialization for Sanrio Shop system
    Place in: ServerScriptService
    
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

print("🌸 [SanrioTycoon] Initializing server...")

-- ========================================
-- SETUP REMOTES FOLDER
-- ========================================

local function GetOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
		print("📁 [SanrioTycoon] Created folder:", name)
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
		warn("⚠️ [SanrioTycoon] Cannot create remote - folder is nil")
		return nil 
	end

	local existing = folder:FindFirstChild(name)
	if existing then 
		print("✓ [SanrioTycoon] Found existing remote:", name)
		return existing 
	end

	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	print("✓ [SanrioTycoon] Created remote:", name, "(" .. className .. ")")
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

print("✅ [SanrioTycoon] Server initialized successfully!")
print("📡 Remotes created:", #Remotes)
print("📂 Location: ReplicatedStorage.TycoonRemotes")

return Remotes
