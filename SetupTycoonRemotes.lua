--[[
	SERVER: Setup TycoonRemotes folder
	Prevents infinite yield errors
	Place in ServerScriptService
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create TycoonRemotes folder
local folder = ReplicatedStorage:FindFirstChild("TycoonRemotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "TycoonRemotes"
	folder.Parent = ReplicatedStorage
end

-- Ensure all RemoteEvents exist
local function ensureRemoteEvent(name)
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	print("[TycoonRemotes] Created RemoteEvent:", name)
	return remote
end

-- Create all needed RemoteEvents
ensureRemoteEvent("MoneyCollected")
ensureRemoteEvent("ButtonHoverEffect")
ensureRemoteEvent("ClaimedTycoon") -- NEW: for tutorial claim detection

print("✅ [TycoonRemotes] All RemoteEvents ready!")
