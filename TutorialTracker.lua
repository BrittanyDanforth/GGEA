--[[
	Tutorial View Tracker - SERVER SCRIPT v2.0
	
	Tracks how many times each player has seen the tutorial.
	Place in: ServerScriptService
	
	Works with TycoonPathGuide.lua v8.0+
	
	⚡ PERFORMANCE OPTIMIZED:
	✅ In-memory cache (5min TTL) - prevents repeated DataStore calls
	✅ Cache cleanup on PlayerRemoving - prevents memory growth
	✅ Safe pcall wrapping - won't break if DataStore fails
	✅ Async-friendly - won't cause lag spikes
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

-- In-memory cache to prevent repeated DataStore calls (performance!)
local viewCountCache = {}
local CACHE_DURATION = 300 -- 5 minutes

-- Check how many times player has seen tutorial
checkTutorial.OnServerInvoke = function(player)
	if not player then return 0 end
	
	-- Check cache first (prevent lag from repeated DataStore calls!)
	local cached = viewCountCache[player.UserId]
	if cached and tick() - cached.timestamp < CACHE_DURATION then
		return cached.viewCount
	end
	
	if not TutorialViewStore then
		return 0 -- If DataStore fails, always show tutorial (safe fallback)
	end
	
	local key = "Player_" .. tostring(player.UserId)
	local success, data = pcall(function()
		return TutorialViewStore:GetAsync(key)
	end)
	
	local viewCount = 0
	if success and data and typeof(data.viewCount) == "number" then
		viewCount = data.viewCount
	end
	
	-- Cache result (prevent repeated calls!)
	viewCountCache[player.UserId] = {
		viewCount = viewCount,
		timestamp = tick()
	}
	
	return viewCount
end

-- Increment tutorial view count
incrementTutorial.OnServerInvoke = function(player)
	if not player or not TutorialViewStore then
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
		
		-- Update cache immediately
		viewCountCache[player.UserId] = {
			viewCount = newCount,
			timestamp = tick()
		}
		
		print("🎓 [TutorialTracker]", player.Name, "tutorial views:", newCount)
	end)
	
	if not success then
		warn("[TutorialTracker] Failed to increment views:", err)
	end
	
	return success
end

-- Clean up cache when player leaves (prevent memory growth!)
Players.PlayerRemoving:Connect(function(player)
	viewCountCache[player.UserId] = nil
end)

print("✅ [TutorialTracker] Loaded!")
print("📊 Tutorial will show max 2 times per player")
print("⚡ Performance: 5-min cache, async operations, auto-cleanup")
print("🛡️ Memory safe: Cache cleaned on PlayerRemoving")
