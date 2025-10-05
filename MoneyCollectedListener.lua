-- MoneyCollectedListener.lua
-- Put in: StarterPlayer → StarterPlayerScripts
-- Receives MoneyCollected events (fixes "did you forget to implement OnClientEvent?" error)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("💰 [CLIENT] MoneyCollected Listener - Starting...")

local TycoonRemotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 30)
if not TycoonRemotes then
	warn("[CLIENT] TycoonRemotes folder not found!")
	return
end

local MoneyCollected = TycoonRemotes:WaitForChild("MoneyCollected", 30)
if not MoneyCollected then
	warn("[CLIENT] MoneyCollected remote not found!")
	return
end

-- =================== LISTENER ===================
-- This receives the events from server so they don't pile up
MoneyCollected.OnClientEvent:Connect(function(giver, amount, has2x, isAutoCollect)
	-- Just receive it - no need to do anything fancy
	-- Your UI systems handle the rest
	
	-- Optional: Add client-side effects here if you want
	-- e.g., play a sound, show a particle effect, etc.
end)

print("✅ [CLIENT] MoneyCollected Listener ACTIVE!")
print("🎯 Now receiving money collection events from server")
