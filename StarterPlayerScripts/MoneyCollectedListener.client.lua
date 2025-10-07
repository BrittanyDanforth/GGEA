--[[
	MoneyCollectedListener
	Location: StarterPlayer > StarterPlayerScripts
	
	Fixes the "Remote event invocation queue exhausted" warning
	by listening to MoneyCollected events (even if we don't use them).
	
	This prevents the server-side RemoteEvent queue from filling up.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TycoonRemotes = ReplicatedStorage:WaitForChild("TycoonRemotes")
local MoneyCollected = TycoonRemotes:WaitForChild("MoneyCollected")

-- Listen to the event (no-op is fine)
-- You can add SFX/UI here if needed
MoneyCollected.OnClientEvent:Connect(function(amount, who)
	-- Optional: Add sound effects or UI notifications here
	-- For now, just receiving the event prevents queue exhaustion
end)

print("[MoneyCollectedListener] Ready - remote spam prevented")
