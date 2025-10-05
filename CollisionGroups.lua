-- ========================================
-- SHARED COLLISION GROUP MANAGEMENT
-- ========================================
-- This ensures all collision groups are registered properly and in the right order

local PhysicsService = game:GetService("PhysicsService")
local registeredGroups = {}

-- Collision group definitions
local COLLISION_GROUPS = {
    -- Dropper collision groups (1-13)
    "KuromiOrbs", "KuromiOrbs2", "KuromiOrbs3", "CinnamorollOrbs", "Dropper5Orbs",
    "KuromiOrbs6", "KuromiOrbs8", "KuromiOrbs9", "KuromiOrbs10", "KuromiOrbs11", "KuromiOrbs12", "KuromiOrbs13",

    -- Purchase handler groups
    "Players", "TycoonFloor", "TycoonButtons",

    -- Other groups
    "HelloKittyOrbs"
}

-- Register all collision groups upfront
local function registerAllCollisionGroups()
    for _, groupName in ipairs(COLLISION_GROUPS) do
        if not registeredGroups[groupName] then
            pcall(function()
                PhysicsService:RegisterCollisionGroup(groupName)
                registeredGroups[groupName] = true
            end)
        end
    end
end

-- Set collision relationships for a specific dropper
local function setupDropperCollisions(dropperGroup)
    pcall(function()
        -- Don't collide with players
        PhysicsService:CollisionGroupSetCollidable(dropperGroup, "Players", false)
        PhysicsService:CollisionGroupSetCollidable(dropperGroup, dropperGroup, false)

        -- Don't collide with other droppers
        for _, group in ipairs(COLLISION_GROUPS) do
            if group ~= dropperGroup and string.find(group, "Orbs") then
                PhysicsService:CollisionGroupSetCollidable(dropperGroup, group, false)
            end
        end
    end)
end

-- Setup collision groups for droppers
local function setupDropperCollisionGroup(dropperGroup)
    registerAllCollisionGroups()
    setupDropperCollisions(dropperGroup)
end

-- Setup collision groups for purchase handler
local function setupPurchaseHandlerCollisionGroups()
    registerAllCollisionGroups()

    pcall(function()
        -- Tycoon floor vs buttons
        PhysicsService:CollisionGroupSetCollidable("TycoonFloor", "TycoonButtons", false)
        PhysicsService:CollisionGroupSetCollidable("TycoonFloor", "TycoonFloor", true)
        PhysicsService:CollisionGroupSetCollidable("TycoonButtons", "TycoonButtons", true)
    end)
end

return {
    registerAllCollisionGroups = registerAllCollisionGroups,
    setupDropperCollisionGroup = setupDropperCollisionGroup,
    setupPurchaseHandlerCollisionGroups = setupPurchaseHandlerCollisionGroups,
    COLLISION_GROUPS = COLLISION_GROUPS
}