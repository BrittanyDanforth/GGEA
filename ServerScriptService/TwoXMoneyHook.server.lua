--!strict
-- TwoXMoneyHook: Integrates the wheel's 2X boost with your purchase handler
-- This works with your existing ServerStorage.PlayerMoney system

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

-- Wait for PlayerMoney folder
local PlayerMoney = ServerStorage:WaitForChild("PlayerMoney", 30)
if not PlayerMoney then
    warn("[TwoXMoneyHook] PlayerMoney folder not found in ServerStorage!")
    return
end

-- Create a wrapper for AddPlayerMoney that other scripts can use
_G.AddPlayerMoney = function(playerName: string, amount: number)
    amount = tonumber(amount) or 0
    if amount == 0 then return true end
    
    local playerValue = PlayerMoney:FindFirstChild(playerName)
    if not playerValue then
        -- Create if doesn't exist
        playerValue = Instance.new("IntValue")
        playerValue.Name = playerName
        playerValue.Value = 0
        playerValue.Parent = PlayerMoney
    end
    
    -- Check for 2X boost
    local player = Players:FindFirstChild(playerName)
    local mult = 1
    if player then
        local untilTs = player:GetAttribute("TwoXUntil")
        if typeof(untilTs) == "number" and untilTs > os.time() then
            mult = 2
        end
    end
    
    local final = math.floor(amount * mult)
    playerValue.Value = playerValue.Value + final
    
    return true
end

-- Hook into existing PlayerMoney changes to apply 2X boost
local function setupPlayerMoneyHook(playerName: string)
    local playerValue = PlayerMoney:FindFirstChild(playerName)
    if not playerValue then return end
    
    local player = Players:FindFirstChild(playerName)
    if not player then return end
    
    -- Store the last value to detect changes
    local lastValue = playerValue.Value
    
    local connection
    connection = playerValue.Changed:Connect(function(newValue)
        -- Only apply multiplier to increases
        local diff = newValue - lastValue
        if diff > 0 then
            local untilTs = player:GetAttribute("TwoXUntil")
            if typeof(untilTs) == "number" and untilTs > os.time() then
                -- Add the bonus amount (so 2x total)
                playerValue.Value = newValue + diff
                print(string.format("[2X BOOST] Doubled %d for %s (now %d)", diff, playerName, playerValue.Value))
            end
        end
        lastValue = playerValue.Value
    end)
    
    -- Clean up when player leaves
    player.AncestryChanged:Connect(function()
        if not player.Parent then
            connection:Disconnect()
        end
    end)
end

-- Set up hooks for existing players
for _, player in ipairs(Players:GetPlayers()) do
    setupPlayerMoneyHook(player.Name)
end

-- Set up hooks for new players
Players.PlayerAdded:Connect(function(player)
    -- Wait a bit for their money value to be created
    task.wait(1)
    setupPlayerMoneyHook(player.Name)
end)

print("[TwoXMoneyHook] Loaded - 2X boost will apply to all money gains!")