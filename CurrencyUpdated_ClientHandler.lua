--[[
	CURRENCY UPDATED - CLIENT HANDLER
	✅ Receives batched currency updates from server
	✅ Updates UI smoothly
	✅ Fixes "did you forget to implement OnClientEvent?" error
	
	PUT IN: StarterPlayer → StarterPlayerScripts
	NAME: CurrencyUpdated_ClientHandler
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

print("💰 [CLIENT] Currency Update Handler - Starting...")

-- Wait for RemoteEvents
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not RemoteEvents then
	warn("[CLIENT] RemoteEvents folder not found!")
	return
end

local CurrencyUpdated = RemoteEvents:WaitForChild("CurrencyUpdated", 10)
if not CurrencyUpdated then
	warn("[CLIENT] CurrencyUpdated remote not found!")
	return
end

-- =================== HANDLE CURRENCY UPDATES ===================
CurrencyUpdated.OnClientEvent:Connect(function(currencies)
	if not currencies then return end
	
	-- Update your UI here
	-- Example: Update coins display
	if currencies.coins then
		-- Your coin UI update logic
		-- e.g., playerGui.CoinDisplay.Amount.Text = tostring(currencies.coins)
	end
	
	if currencies.gems then
		-- Your gems UI update logic
	end
	
	if currencies.tickets then
		-- Your tickets UI update logic
	end
	
	-- If you have a global UI system, update it
	if _G.UpdateCurrencyUI then
		_G.UpdateCurrencyUI(currencies)
	end
end)

print("✅ [CLIENT] Currency Update Handler - Active!")
print("💰 Ready to receive batched currency updates from server")
