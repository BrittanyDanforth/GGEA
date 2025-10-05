-- ========================================
-- PURCHASE HANDLER WITH CURRENCY BUS (FIXED)
-- ========================================
-- Modified to use CurrencyBus for batched remote events

local CurrencyBus = require(script.Parent.CurrencyBus)

-- In the giver.Touched event, replace direct remote firing with:
-- CurrencyBus:Add(player, amount)
-- Instead of: CurrencyUpdated:FireClient(player, amount, newBalance)

-- Example of the modified giver.Touched section:
/*
giver.Touched:Connect(function(hit)
    local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local player = Players:GetPlayerFromCharacter(hit.Parent)
    if not player then return end

    if script.Parent.Owner.Value == player then
        -- Owner collecting
        if autoCollectEnabled[player] ~= false then return end

        if not canPerformAction(player, "collect", CONFIG.COLLECT_COOLDOWN) then return end

        local playerStats = ServerStorage.PlayerMoney:FindFirstChild(player.Name)
        if playerStats and Money.Value > 0 then
            local moneyCollected = Money.Value

            -- Apply 2x multiplier if owned
            local finalAmount, has2x = applyMoneyMultiplier(player, moneyCollected)

            playerStats.Value = playerStats.Value + finalAmount
            Money.Value = 0

            -- USE CURRENCY BUS INSTEAD OF DIRECT REMOTE
            CurrencyBus:Add(player, finalAmount)

            -- Send visual feedback
            local moneyCollectRemote = remotesFolder:FindFirstChild("MoneyCollected")
            if moneyCollectRemote then
                moneyCollectRemote:FireClient(player, giver, finalAmount, has2x, false)
            end
        end
    end
end)
*/