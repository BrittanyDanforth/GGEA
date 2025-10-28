-- ========================================
-- CURRENCY BUS - BATCHED CURRENCY UPDATES
-- ========================================
-- Prevents remote event spam by batching currency updates

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RE = ReplicatedStorage:WaitForChild("RemoteEvents")
local CurrencyUpdated = RE:WaitForChild("CurrencyUpdated")

-- Pending updates and balances per player
local PENDING, BAL = {}, {}
local INTERVAL = 0.15 -- ~6.6 updates per second

-- Background task to send batched updates
task.spawn(function()
    while true do
        task.wait(INTERVAL)
        for plr, delta in pairs(PENDING) do
            if delta ~= 0 then
                CurrencyUpdated:FireClient(plr, delta, BAL[plr] or 0)
                PENDING[plr] = 0
            end
        end
    end
end)

local CurrencyBus = {}

-- Initialize player with starting balance
function CurrencyBus:Init(plr, startBalance)
    BAL[plr] = startBalance or 0
    PENDING[plr] = 0
end

-- Add amount to player's pending updates
function CurrencyBus:Add(plr, delta)
    if not plr or not Players:GetPlayerByUserId(plr.UserId) then return end

    BAL[plr] = (BAL[plr] or 0) + delta
    PENDING[plr] = (PENDING[plr] or 0) + delta
end

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(plr)
    PENDING[plr] = nil
    BAL[plr] = nil
end)

return CurrencyBus