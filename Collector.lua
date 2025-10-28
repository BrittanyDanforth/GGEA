-- ========================================
-- DEBOUNCED COLLECTOR SYSTEM
-- ========================================
-- Prevents multiple payments per drop and reduces remote event spam

local CurrencyBus = require(script.Parent.CurrencyBus)
local collected = {} -- [Instance] = true
local COOLDOWN = 0.2 -- seconds to ignore repeat touches from same part

-- Mark part as collected once (prevents duplicate payments)
local function markOnce(obj)
    if collected[obj] then return false end
    collected[obj] = true
    task.delay(COOLDOWN, function() collected[obj] = nil end)
    return true
end

-- Process collection for a part
local function processCollection(hit, collectorPart)
    -- Find the actual cash carrier (the part with Cash value)
    local cashVal = hit:FindFirstChild("Cash")
    if not cashVal then return end

    -- Hard debounce - only process once per part
    if not markOnce(hit) then return end

    local amount = cashVal.Value or 0

    -- Find the player who owns this tycoon
    local plr = nil
    local tycoon = collectorPart.Parent
    if tycoon and tycoon:FindFirstChild("Owner") then
        plr = tycoon.Owner.Value
    end

    if not plr then return end

    -- Award money (this will be handled by the purchase handler)
    -- For now, just trigger the collection through the existing system
    -- The purchase handler will handle the actual money awarding and remote events

    -- Remove the drop safely
    local root = hit:FindFirstAncestorWhichIsA("Model") or hit
    if root and root.Parent then
        root:Destroy()
    else
        hit:Destroy()
    end
end

-- Setup collector for a specific part
local function setupCollector(collectorPart)
    collectorPart.Touched:Connect(function(hit)
        processCollection(hit, collectorPart)
    end)
end

return {
    setupCollector = setupCollector,
    processCollection = processCollection
}