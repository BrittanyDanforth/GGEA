--[[
	Kuromi Dropper 8 - MODERNIZED
	✅ Proper collision groups
	✅ Physics properties for better behavior
	✅ Fade in/out effects
	✅ Better spawn positioning
	✅ Improved cleanup
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- =================== CONFIG ===================
local DROP_RATE = 0.5
local CASH_VALUE = 100
local SPAWN_HEIGHT_OFFSET = -2.5
local FADE_TIME = 0.5
local LIFETIME = 2000

-- Physics settings
local PHYSICS_DENSITY = 0.3
local PHYSICS_FRICTION = 0.7
local PHYSICS_ELASTICITY = 0.1

-- Visual settings
local DROP_COLOR = BrickColor.new("Lime green")
local DROP_MATERIAL = "Fabric"
local DROP_SIZE = Vector3.new(1, 1, 1)

-- Collector detection
local COLLECTOR_NAMES = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" }
local COLLECTOR_TAGS = { "Collector", "SellZone" }

-- Collision groups
local DROP_GROUP = "KuromiDrops"
local PLAYER_GROUP = "Players"
-- =================== END CONFIG ===================

-- Initialize
task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

-- Setup collision groups
local function setupCollisionGroups()
    pcall(function()
        PhysicsService:RegisterCollisionGroup(DROP_GROUP)
        PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
        PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, PLAYER_GROUP, false)
        PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, DROP_GROUP, false)
    end)
end

-- Setup player collision
local function setupPlayerCollision(character)
    task.wait(0.1)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CollisionGroup = PLAYER_GROUP end)
        end
    end
end

-- Initialize players
local function initializePlayers()
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(setupPlayerCollision)
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then setupPlayerCollision(player.Character) end
    end
end

-- Check if part is a collector
local function isCollectorPart(hit: BasePart)
    if not hit or not hit:IsA("BasePart") then return false end

    local n = string.lower(hit.Name)
    local pn = hit.Parent and string.lower(hit.Parent.Name) or ""
    for _, want in ipairs(COLLECTOR_NAMES) do
        local w = string.lower(want)
        if n == w or pn == w or string.find(n, "collect") or string.find(pn, "collect") then
            return true
        end
    end

    for _, t in ipairs(COLLECTOR_TAGS) do
        if CollectionService:HasTag(hit, t) or (hit.Parent and CollectionService:HasTag(hit.Parent, t)) then
            return true
        end
    end

    if hit:GetAttribute("Collector") == true then return true end
    if hit.Parent and hit.Parent:FindFirstChild("Collector") then return true end

    return false
end

-- Setup physics properties
local function setupPhysics(part)
    part.Anchored = false
    part.CanTouch = true
    part.CanQuery = true
    part.CollisionGroup = DROP_GROUP

    part.CustomPhysicalProperties = PhysicalProperties.new(
        PHYSICS_DENSITY,
        PHYSICS_FRICTION,
        PHYSICS_ELASTICITY,
        2.0,
        1.0
    )
end

-- Calculate spawn position
local function calculateSpawnPosition()
    local offsetX = math.random(-2, 2) * 0.1
    local offsetZ = math.random(-2, 2) * 0.1
    local spawnY = dropPart.Position.Y + SPAWN_HEIGHT_OFFSET

    return CFrame.new(
        dropPart.Position.X - offsetX,
        spawnY,
        dropPart.Position.Z - offsetZ
    )
end

-- Setup fade system
local function setupFadeSystem(part)
    local originalTransparency = part.Transparency
    part.Transparency = 1

    return {
        part = part,
        originalTransparency = originalTransparency,
        activeTween = nil
    }
end

-- Fade in effect
local function fadeIn(fadeData)
    fadeData.activeTween = TweenService:Create(
        fadeData.part,
        TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Transparency = fadeData.originalTransparency }
    )
    fadeData.activeTween:Play()
    return fadeData.activeTween
end

-- Fade out effect
local function fadeOut(fadeData, callback)
    if fadeData.activeTween then
        pcall(function() fadeData.activeTween:Cancel() end)
    end

    local tween = TweenService:Create(
        fadeData.part,
        TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Transparency = 1 }
    )
    tween:Play()

    task.delay(FADE_TIME + 0.05, function()
        if callback then callback() end
    end)
end

-- Create drop effects
local function createDropEffects(part)
    local light = Instance.new("PointLight")
    light.Brightness = 1
    light.Range = 6
    light.Color = Color3.fromRGB(50, 255, 50) -- Lime green
    light.Parent = part

    return light
end

-- Main drop creation function
local function createDrops()
    local count = 0
    while true do
        task.wait(DROP_RATE)
        count += 1

        -- Create drop part
        local part = Instance.new("Part")
        part.Name = "KuromiDrop_" .. count
        part.Parent = PartStorage

        -- Visual properties
        part.BrickColor = DROP_COLOR
        part.Material = DROP_MATERIAL
        part.Size = DROP_SIZE
        part.Shape = "Block"
        part.TopSurface = "Smooth"
        part.BottomSurface = "Smooth"

        -- Position
        part.CFrame = calculateSpawnPosition()

        -- Physics and collision
        setupPhysics(part)

        -- Cash value
        local cash = Instance.new("IntValue")
        cash.Name = "Cash"
        cash.Value = CASH_VALUE
        cash.Parent = part

        -- Fade system
        local fadeData = setupFadeSystem(part)

        -- Effects
        local light = createDropEffects(part)

        -- Start fade in
        fadeIn(fadeData)

        -- Collection detection
        local collected = false
        local touchConnection

        local function onCollected()
            if collected then return end
            collected = true

            -- Flash effect
            light.Brightness = 3
            TweenService:Create(light,
                TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Brightness = 1}
            ):Play()

            -- Fade out and cleanup
            fadeOut(fadeData, function()
                if touchConnection then touchConnection:Disconnect() end
                if part and part.Parent then
                    part:Destroy()
                end
            end)
        end

        touchConnection = part.Touched:Connect(function(hit)
            if isCollectorPart(hit) then
                onCollected()
            end
        end)

        -- Pop animation
        local originalSize = part.Size
        part.Size = Vector3.new(0.1, 0.1, 0.1)
        TweenService:Create(part,
            TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = originalSize}
        ):Play()

        -- Set lifetime
        Debris:AddItem(part, LIFETIME)
    end
end

-- Initialize everything
setupCollisionGroups()
initializePlayers()

-- Start the drop loop
local success, errorMsg = pcall(createDrops)
if not success then
    warn("Error in Kuromi Dropper 8:", errorMsg)
end