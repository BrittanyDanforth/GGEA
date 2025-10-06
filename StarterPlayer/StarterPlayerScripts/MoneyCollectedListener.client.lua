-- StarterPlayerScripts/MoneyCollectedListener.client.lua
-- Tiny listener to consume MoneyCollected and prevent remote queue warnings.
local RS = game:GetService("ReplicatedStorage")
local TycoonRemotes = RS:WaitForChild("TycoonRemotes")
local MoneyCollected = TycoonRemotes:WaitForChild("MoneyCollected")
MoneyCollected.OnClientEvent:Connect(function(amount, who)
	-- Intentionally no-op. Hook here if you want SFX/UI.
end)
