--[[
	Tutorial View Tracker - SERVER SCRIPT
	
	Tracks how many times each player has seen the tutorial.
	Place in: ServerScriptService
	
	Works with TycoonPathGuide.lua v7.9+
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local TutorialViewStore
local storeSuccess, storeError = pcall(function()
	TutorialViewStore = DataStoreService:GetDataStore("TycoonTutorialViews_v1")
end)

if not storeSuccess then
	warn("[TutorialTracker] DataStore unavailable:", storeError)
end

-- Setup remotes folder
local remotesFolder = ReplicatedStorage:FindFirstChild("TycoonRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "TycoonRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

-- Create CheckTutorialStatus remote
local checkTutorial = remotesFolder:FindFirstChild("CheckTutorialStatus")
if not checkTutorial then
	checkTutorial = Instance.new("RemoteFunction")
	checkTutorial.Name = "CheckTutorialStatus"
	checkTutorial.Parent = remotesFolder
end

-- Create IncrementTutorialViews remote
local incrementTutorial = remotesFolder:FindFirstChild("IncrementTutorialViews")
if not incrementTutorial then
	incrementTutorial = Instance.new("RemoteFunction")
	incrementTutorial.Name = "IncrementTutorialViews"
	incrementTutorial.Parent = remotesFolder
end

-- Check how many times player has seen tutorial
checkTutorial.OnServerInvoke = function(player)
	if not TutorialViewStore then
		return 0 -- If DataStore fails, always show tutorial (safe fallback)
	end
	
	local key = "Player_" .. tostring(player.UserId)
	local success, data = pcall(function()
		return TutorialViewStore:GetAsync(key)
	end)
	
	if success and data and typeof(data.viewCount) == "number" then
		return data.viewCount
	end
	
	return 0 -- First time!
end

-- Increment tutorial view count
incrementTutorial.OnServerInvoke = function(player)
	if not TutorialViewStore then
		return false
	end
	
	local key = "Player_" .. tostring(player.UserId)
	local success, err = pcall(function()
		local currentData = TutorialViewStore:GetAsync(key) or {viewCount = 0}
		local newCount = (currentData.viewCount or 0) + 1
		
		TutorialViewStore:SetAsync(key, {
			viewCount = newCount,
			lastSeen = os.time()
		})
		
		print("🎓 [TutorialTracker]", player.Name, "tutorial views:", newCount)
	end)
	
	if not success then
		warn("[TutorialTracker] Failed to increment views:", err)
	end
	
	return success
end

print("✅ [TutorialTracker] Loaded!")
print("📊 Tutorial will show max 2 times per player")
