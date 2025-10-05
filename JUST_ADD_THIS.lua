-- MoneyCollectedListener.lua
-- Put in: StarterPlayer → StarterPlayerScripts → MoneyCollectedListener
-- Type: LocalScript
-- THIS IS THE ONLY FILE YOU NEED - FIXES THE SPAM!

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

-- Receive the events so they don't pile up and cause spam
MoneyCollected.OnClientEvent:Connect(function(giver, amount, has2x, isAutoCollect)
	-- Just receive it - your existing UI handles the rest
end)

print("✅ [CLIENT] MoneyCollected Listener ACTIVE!")
print("🎯 MoneyCollected spam = FIXED!")
