--[[
	CLIENT CURRENCY HANDLER
	✅ Receives CurrencyUpdated events from server
	✅ Fixes "did you forget to implement OnClientEvent?" error
	✅ THIS IS THE MISSING PIECE!
	
	PUT IN: StarterPlayer → StarterPlayerScripts
	NAME: CLIENT_CurrencyHandler
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("💰 [CLIENT] Waiting for RemoteEvents...")

-- Wait for the remote event
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 30)
if not RemoteEvents then
	warn("[CLIENT] RemoteEvents folder not found!")
	return
end

local CurrencyUpdated = RemoteEvents:WaitForChild("CurrencyUpdated", 30)
if not CurrencyUpdated then
	warn("[CLIENT] CurrencyUpdated remote not found!")
	return
end

print("💰 [CLIENT] Found CurrencyUpdated remote - Setting up handler...")

-- =================== THIS IS THE CRITICAL LINE ===================
-- This RECEIVES the batched updates from the server!
CurrencyUpdated.OnClientEvent:Connect(function(currencies)
	-- Just receive it - your UI systems will handle the rest
	-- The important part is that we're LISTENING so events don't pile up!
	
	if not currencies then return end
	
	-- Optional: Update global currency data if you have it
	if _G.PlayerCurrencies then
		_G.PlayerCurrencies = currencies
	end
	
	-- Optional: Fire local event for UI systems
	if _G.OnCurrencyUpdated then
		_G.OnCurrencyUpdated(currencies)
	end
end)
-- ================================================================

print("✅ [CLIENT] Currency Update Handler ACTIVE!")
print("💰 Now receiving batched currency updates from server")
print("🎯 Remote event queue errors should be GONE!")
