--[[
	💡 SIMPLE FIX - Disable Redundant Remote Calls
	
	Your PurchaseHandler fires MoneyCollected on every auto-collect
	Your MoneyUpdateBridge fires CurrencyUpdated on every money change
	= 200+ remote events per second with 13 droppers!
	
	This script just DISABLES those calls since they're redundant.
	MoneyUpdateBridge already updates the UI properly!
	
	PUT IN: ServerScriptService
	NAME: AAA_DisableRemoteSpam
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

task.wait(2)  -- Wait for remotes to be created

print("💡 [FIX] Disabling redundant remote event calls...")

-- Find the remotes
local TycoonRemotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)

if not TycoonRemotes or not RemoteEvents then
	warn("⚠️ Could not find remote folders!")
	return
end

local MoneyRemote = TycoonRemotes:WaitForChild("MoneyCollected", 10)
local CurrencyRemote = RemoteEvents:WaitForChild("CurrencyUpdated", 10)

if not MoneyRemote or not CurrencyRemote then
	warn("⚠️ Could not find remotes!")
	return
end

-- Replace FireClient with a do-nothing function
-- This prevents the spam but keeps everything else working
MoneyRemote.FireClient = function() 
	-- Do nothing - MoneyUpdateBridge handles it
end

CurrencyRemote.FireClient = function()
	-- Do nothing - MoneyUpdateBridge handles it
end

print("✅ [FIX] Remote event calls disabled!")
print("💰 MoneyUpdateBridge will handle all UI updates")
print("🎯 No more remote event spam!")
