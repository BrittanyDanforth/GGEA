--[[
	Hello Kitty Dropper 1 - Model Based (REWRITTEN)
	Uses HelloKittyPL model from ReplicatedStorage
	✅ Much lower spawn height
	✅ Perfect fade behavior
	✅ Better error handling
	✅ Cleaner code structure
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- =================== CONFIG ===================
local DROP_RATE = 1.2
local CASH_VALUE = 10
local SCALE_FACTOR = 0.9
local SPAWN_HEIGHT_OFFSET = -2.5  -- Much more significant lowering
local FADE_TIME = 0.5
local LIFETIME = nil

-- Collector detection
local COLLECTOR_NAMES = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" }
local COLLECTOR_TAGS = { "Collector", "SellZone" }

-- Physics settings
local PHYSICS_DENSITY = 0.4
local PHYSICS_FRICTION = 0.85
local PHYSICS_ELASTICITY = 0.00
-- =================== END CONFIG ===================

-- Initialize services
task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local templateModel = ReplicatedStorage:WaitForChild("HelloKittyPL")
local dropPart = script.Parent:WaitForChild("Drop")

-- Collision Groups
local DROP_GROUP = "HelloKittyOrbs"
local PLAYER_GROUP = "Players"

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

-- Find primary part of model
local function findPrimaryPart(model)
    if model.PrimaryPart then return model.PrimaryPart end
    local largest, vol = nil, 0
    for _, c in ipairs(model:GetDescendants()) do
        if c:IsA("BasePart") then
            local v = c.Size.X * c.Size.Y * c.Size.Z
            if v > vol then
                vol = v
                largest = c
            end
        end
    end
    return largest
end

-- Weld all parts to primary part
local function weldAllParts(model, primary)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and d ~= primary then
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = primary
            weld.Part1 = d
            weld.Parent = primary
        end
    end
end

-- Check if part is a collector
local function isCollectorPart(hit: BasePart)
    if not hit or not hit:IsA("BasePart") then return false end

    -- Check name or parent's name
    local n = string.lower(hit.Name)
    local pn = hit.Parent and string.lower(hit.Parent.Name) or ""
    for _, want in ipairs(COLLECTOR_NAMES) do
        local w = string.lower(want)
        if n == w or pn == w or string.find(n, "collect") or string.find(pn, "collect") then
            return true
        end
    end

    -- Check tags
    for _, t in ipairs(COLLECTOR_TAGS) do
        if CollectionService:HasTag(hit, t) or (hit.Parent and CollectionService:HasTag(hit.Parent, t)) then
            return true
        end
    end

    -- Check attribute or BoolValue
    if hit:GetAttribute("Collector") == true then return true end
    if hit.Parent and hit.Parent:FindFirstChild("Collector") then return true end

    return false
end

-- Apply physics properties to parts
local function setupPhysicsProperties(model)
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            p.Anchored = false
            p.CanTouch = true
            p.CanQuery = true
            p.CollisionGroup = DROP_GROUP

            p.CustomPhysicalProperties = PhysicalProperties.new(
                PHYSICS_DENSITY,
                PHYSICS_FRICTION,
                PHYSICS_ELASTICITY,
                2.0,
                1.0
            )

            -- Add cash value
            local cash = p:FindFirstChild("Cash")
            if not cash then
                cash = Instance.new("IntValue")
                cash.Name = "Cash"
                cash.Value = CASH_VALUE
                cash.Parent = p
            end
        end
    end
end

-- Calculate spawn position
local function calculateSpawnPosition()
    local offsetX = math.random(-2, 2) * 0.1
    local offsetZ = math.random(-2, 2) * 0.1

    -- Much simpler and more direct height calculation
    local spawnY = dropPart.Position.Y + SPAWN_HEIGHT_OFFSET

    local spawnCFrame = CFrame.new(
        dropPart.Position.X - offsetX,
        spawnY,
        dropPart.Position.Z - offsetZ
    ) * CFrame.Angles(math.rad(180), math.rad(-90), 0)

    return spawnCFrame
end

-- Setup fade system
local function setupFadeSystem(model)
    local fadeData = {
        parts = {},
        decals = {},
        tweens = {}
    }

    -- Collect all parts and decals
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            local originalTransparency = d.Transparency
            d.Transparency = 1
            table.insert(fadeData.parts, {
                part = d,
                originalTransparency = originalTransparency
            })
        elseif d:IsA("Decal") or d:IsA("Texture") then
            local originalTransparency = d.Transparency
            d.Transparency = 1
            table.insert(fadeData.decals, {
                decal = d,
                originalTransparency = originalTransparency
            })
        end
    end

    return fadeData
end

-- Fade in function
local function fadeIn(fadeData)
    local tweens = {}

    -- Fade in parts
    for _, data in ipairs(fadeData.parts) do
        local tween = TweenService:Create(
            data.part,
            TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Transparency = data.originalTransparency }
        )
        tween:Play()
        table.insert(tweens, tween)
    end

    -- Fade in decals
    for _, data in ipairs(fadeData.decals) do
        local tween = TweenService:Create(
            data.decal,
            TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Transparency = data.originalTransparency }
        )
        tween:Play()
        table.insert(tweens, tween)
    end

    return tweens
end

-- Fade out function
local function fadeOut(fadeData, callback)
    -- Cancel any existing tweens
    for _, tween in ipairs(fadeData.tweens) do
        pcall(function() tween:Cancel() end)
    end

    -- Fade out parts
    for _, data in ipairs(fadeData.parts) do
        TweenService:Create(
            data.part,
            TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Transparency = 1 }
        ):Play()
    end

    -- Fade out decals
    for _, data in ipairs(fadeData.decals) do
        TweenService:Create(
            data.decal,
            TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Transparency = 1 }
        ):Play()
    end

    -- Cleanup after fade
    task.delay(FADE_TIME + 0.05, function()
        if callback then callback() end
    end)
end

-- Create drop effects
local function createDropEffects(primaryPart)
    -- Light effect
    local light = Instance.new("PointLight")
    light.Brightness = 1
    light.Range = 8
    light.Color = Color3.fromRGB(255, 150, 200)
    light.Parent = primaryPart

    -- Ring effect
    local ring = Instance.new("ParticleEmitter")
    ring.Texture = "rbxassetid://262979222"
    ring.Rate = 0
    ring.Speed = NumberRange.new(0)
    ring.Lifetime = NumberRange.new(0.3)
    ring.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 3)
    })
    ring.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.5, 0.6),
        NumberSequenceKeypoint.new(1, 1)
    })
    ring.Color = ColorSequence.new(Color3.fromRGB(255, 150, 200))
    ring.Parent = primaryPart
    ring:Emit(1)
    Debris:AddItem(ring, 1)

    return light
end

-- Main drop creation function
local function createDrop()
    local count = 0
    while true do
        task.wait(DROP_RATE)
        count += 1

        -- Clone and setup model
        local newDrop = templateModel:Clone()
        newDrop.Name = "HelloKitty_" .. count

        local primaryPart = findPrimaryPart(newDrop)
        if not primaryPart then
            warn("HelloKittyPL has no BaseParts")
            newDrop:Destroy()
            continue
        end

        -- Clean up existing constraints
        for _, w in ipairs(newDrop:GetDescendants()) do
            if w:IsA("WeldConstraint") or w:IsA("Motor6D") then
                w:Destroy()
            end
        end

        -- Scale and weld
        local pivot = newDrop:GetPivot()
        newDrop:ScaleTo(SCALE_FACTOR)
        newDrop:PivotTo(pivot)
        weldAllParts(newDrop, primaryPart)

        -- Setup physics
        setupPhysicsProperties(newDrop)

        -- Calculate spawn position (much lower)
        local spawnCFrame = calculateSpawnPosition()
        newDrop:PivotTo(spawnCFrame)

        -- Setup upright damper
        do
            local att = Instance.new("Attachment")
            att.Parent = primaryPart
            local ao = Instance.new("AlignOrientation")
            ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
            ao.Attachment0 = att
            ao.Responsiveness = 30
            ao.RigidityEnabled = true
            ao.CFrame = spawnCFrame
            ao.Parent = primaryPart
            Debris:AddItem(ao, 0.5)
            Debris:AddItem(att, 0.5)
        end

        -- Set initial velocity
        primaryPart.AssemblyLinearVelocity = Vector3.new(0, -8, 0)
        primaryPart:SetAttribute("SpawnTime", tick())

        -- Setup fade system
        local fadeData = setupFadeSystem(newDrop)

        -- Parent to storage and create effects
        newDrop.Parent = PartStorage
        local light = createDropEffects(primaryPart)

        -- Start fade in
        fadeData.tweens = fadeIn(fadeData)

        -- Collection detection
        local collected = false
        local touchConnection

        local function onCollected()
            if collected then return end
            collected = true

            -- Flash effect
            light.Brightness = 3
            TweenService:Create(light,
                TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Brightness = 1}
            ):Play()

            -- Fade out and cleanup
            fadeOut(fadeData, function()
                if touchConnection then touchConnection:Disconnect() end
                if newDrop and newDrop.Parent then
                    newDrop:Destroy()
                end
            end)

            -- Safety cleanup
            Debris:AddItem(newDrop, FADE_TIME + 1.0)
        end

        touchConnection = primaryPart.Touched:Connect(function(hit)
            if isCollectorPart(hit) then
                onCollected()
            end
        end)

        -- Pop animation
        local originalSize = primaryPart.Size
        primaryPart.Size = Vector3.new(0.1, 0.1, 0.1)
        TweenService:Create(primaryPart,
            TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = originalSize}
        ):Play()
    end
end

-- Initialize everything
setupCollisionGroups()
initializePlayers()

-- Start the drop loop
local success, errorMsg = pcall(createDrop)
if not success then
    warn("Error in HelloKitty dropper:", errorMsg)
end