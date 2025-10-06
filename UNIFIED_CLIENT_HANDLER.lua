--[[
	UNIFIED CLIENT HANDLER
	Put in: StarterPlayer → StarterPlayerScripts
	Type: LocalScript
	
	✅ Handles BOTH CurrencyUpdated AND MoneyCollected
	✅ Stops ALL remote event spam
	✅ ONE script instead of two!
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("💰 [CLIENT] Unified Handler - Starting...")

-- =================== CURRENCY UPDATED HANDLER ===================
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 30)
if RemoteEvents then
	local CurrencyUpdated = RemoteEvents:WaitForChild("CurrencyUpdated", 30)
	if CurrencyUpdated then
		print("💰 [CLIENT] Found CurrencyUpdated remote - Setting up handler...")
		
		CurrencyUpdated.OnClientEvent:Connect(function(currencies)
			-- Receive batched currency updates from MoneyUpdateBridge
			-- Optional: Update global currency data or fire local event for UI systems
			if _G.UpdateCurrencyUI then
				_G.UpdateCurrencyUI(currencies)
			end
		end)
		
		print("✅ [CLIENT] CurrencyUpdated Handler ACTIVE!")
	else
		warn("[CLIENT] CurrencyUpdated remote not found!")
	end
else
	warn("[CLIENT] RemoteEvents folder not found!")
end

-- =================== MONEY COLLECTED HANDLER ===================
local TycoonRemotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 30)
if TycoonRemotes then
	local MoneyCollected = TycoonRemotes:WaitForChild("MoneyCollected", 30)
	if MoneyCollected then
		print("💰 [CLIENT] Found MoneyCollected remote - Setting up handler...")
		
		MoneyCollected.OnClientEvent:Connect(function(giver, amount, has2x, isAutoCollect)
			-- Receive money collected events
			-- Just receive it - your existing UI handles the rest
		end)
		
		print("✅ [CLIENT] MoneyCollected Handler ACTIVE!")
	else
		warn("[CLIENT] MoneyCollected remote not found!")
	end
else
	warn("[CLIENT] TycoonRemotes folder not found!")
end

-- =================== ALL DONE! ===================
print("🎯 [CLIENT] All remote event handlers active!")
print("🔥 NO MORE SPAM ERRORS!")
