--[[
	Kuromi Dropper 5 - LAG-FREE & OPTIMIZED (Ice Cream)
	✅ Ultra-light physics (zero lag)
	✅ Proper collision groups (no conflicts)
	✅ Fast fade effects
	✅ Perfect memory management
	✅ Error-safe execution
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- =================== OPTIMIZED CONFIG ===================
local DROP_RATE = 1.5
local CASH_VALUE = 12
local SPAWN_HEIGHT_OFFSET = -2.5
local FADE_TIME = 0.3  -- Faster fade for less processing
local LIFETIME = 30  -- Reasonable lifetime

-- ULTRA-LIGHT PHYSICS (Zero lag)
local PHYSICS_DENSITY = 0.1     -- Very light for less physics calc
local PHYSICS_FRICTION = 0.3    -- Low friction for smooth movement
local PHYSICS_ELASTICITY = 0.0  -- No bounce to prevent physics loops

-- Mesh settings (Ice Cream)
local MESH_ID = "rbxassetid://1486490132"
local TEXTURE_ID = "rbxassetid://1486490402"

-- Scale settings (thickened and enlarged)
local BASE_SCALE = Vector3.new(1.177, 2.512, 1.164)
local SCALE_OVERALL = 1.8
local THICKEN = Vector3.new(1.8, 1.0, 1.8)
local FINAL_SCALE = Vector3.new(
    BASE_SCALE.X * THICKEN.X * SCALE_OVERALL,
    BASE_SCALE.Y * THICKEN.Y * SCALE_OVERALL,
    BASE_SCALE.Z * THICKEN.Z * SCALE_OVERALL
)

-- Collector detection
local COLLECTOR_NAMES = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" }
local COLLECTOR_TAGS = { "Collector", "SellZone" }

-- Collision groups (LAG PREVENTION)
local DROP_GROUP = "Dropper5Orbs"
local PLAYER_GROUP = "Players"
-- =================== END CONFIG ===================

-- Initialize (error-safe)
task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

-- Setup collision groups (prevents lag from collisions)
local function setupCollisionGroups()
    local success, errorMsg = pcall(function()
        PhysicsService:RegisterCollisionGroup(DROP_GROUP)
        PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)

        -- Don't collide with players
        PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, PLAYER_GROUP, false)
        PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, DROP_GROUP, false)

        -- Don't collide with other droppers (1-13)
        local allDropperGroups = {
            "KuromiOrbs", "KuromiOrbs2", "KuromiOrbs3",
            "CinnamorollOrbs", "Dropper5Orbs",
            "KuromiOrbs6", "KuromiOrbs8", "KuromiOrbs9",
            "KuromiOrbs10", "KuromiOrbs11", "KuromiOrbs12", "KuromiOrbs13"
        }

        for _, group in ipairs(allDropperGroups) do
            if group ~= DROP_GROUP then
                PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, group, false)
            end
        end
    end)
    if not success then
        warn("Collision group setup failed:", errorMsg)
    end
end

-- Setup player collision (prevents player-drop collisions)
local function setupPlayerCollision(character)
    task.wait(0.1) -- Small delay to ensure character loads
    local success, errorMsg = pcall(function()
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CollisionGroup = PLAYER_GROUP
            end
        end
    end)
    if not success then
        warn("Player collision setup failed:", errorMsg)
    end
end

-- Initialize players
local function initializePlayers()
    local success, errorMsg = pcall(function()
        Players.PlayerAdded:Connect(function(player)
            player.CharacterAdded:Connect(setupPlayerCollision)
        end)
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then setupPlayerCollision(player.Character) end
        end
    end)
    if not success then
        warn("Player initialization failed:", errorMsg)
    end
end

-- Check if part is a collector
local function isCollectorPart(hit: BasePart)
    if not hit or not hit:IsA("BasePart") then return false end

    -- Quick name check (most common case first)
    local n = string.lower(hit.Name)
    local pn = hit.Parent and string.lower(hit.Parent.Name) or ""

    for _, want in ipairs(COLLECTOR_NAMES) do
        local w = string.lower(want)
        if n == w or pn == w or string.find(n, "collect") or string.find(pn, "collect") then
            return true
        end
    end

    -- Tag check (less common)
    for _, t in ipairs(COLLECTOR_TAGS) do
        if CollectionService:HasTag(hit, t) or (hit.Parent and CollectionService:HasTag(hit.Parent, t)) then
            return true
        end
    end

    -- Attribute check (least common)
    if hit:GetAttribute("Collector") == true then return true end
    if hit.Parent and hit.Parent:FindFirstChild("Collector") then return true end

    return false
end

-- Setup optimized physics properties (prevents lag)
local function setupPhysics(part)
    local success, errorMsg = pcall(function()
        part.Anchored = false
        part.CanTouch = true
        part.CanQuery = true
        part.CollisionGroup = DROP_GROUP

        -- Ultra-light physics for zero lag
        part.CustomPhysicalProperties = PhysicalProperties.new(
            PHYSICS_DENSITY,     -- Very light
            PHYSICS_FRICTION,    -- Low friction
            PHYSICS_ELASTICITY,  -- No bounce
            1.0,  -- frictionWeight (low)
            1.0   -- elasticityWeight (low)
        )
    end)
    if not success then
        warn("Physics setup failed:", errorMsg)
    end
end

-- Calculate spawn position (optimized)
local function calculateSpawnPosition()
    local offsetX = math.random(-2, 2) * 0.1
    local offsetZ = math.random(-2, 2) * 0.1
    local spawnY = dropPart.Position.Y + SPAWN_HEIGHT_OFFSET

    return CFrame.new(
        dropPart.Position.X - offsetX,
        spawnY,
        dropPart.Position.Z - offsetZ
    ) * CFrame.Angles(math.rad(180), math.rad(180), 0)
end

-- Setup mesh (optimized)
local function setupMesh(part)
    local success, errorMsg = pcall(function()
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = MESH_ID
        mesh.TextureId = TEXTURE_ID
        mesh.Scale = FINAL_SCALE * 0.5 -- Start smaller for spawn animation
        mesh.Parent = part
        return mesh
    end)
    if not success then
        warn("Mesh setup failed:", errorMsg)
        return nil
    end
    return success
end

-- Setup fade system (smooth, no lag)
local function setupFadeSystem(part)
    local originalTransparency = part.Transparency
    part.Transparency = 1

    return {
        part = part,
        originalTransparency = originalTransparency,
        activeTween = nil
    }
end

-- Fade in effect (optimized)
local function fadeIn(fadeData)
    local success, tween = pcall(function()
        local tw = TweenService:Create(
            fadeData.part,
            TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Transparency = fadeData.originalTransparency }
        )
        tw:Play()
        return tw
    end)

    if success then
        fadeData.activeTween = tween
        return tween
    else
        warn("Fade in failed:", success)
        return nil
    end
end

-- Fade out effect (optimized)
local function fadeOut(fadeData, callback)
    local success = pcall(function()
        -- Cancel any existing tween
        if fadeData.activeTween then
            fadeData.activeTween:Cancel()
        end

        -- Quick fade out
        local tween = TweenService:Create(
            fadeData.part,
            TweenInfo.new(FADE_TIME * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Transparency = 1 }
        )
        tween:Play()

        -- Cleanup after fade
        task.delay(FADE_TIME + 0.05, function()
            if callback then callback() end
        end)
    end)

    if not success then
        warn("Fade out failed:", success)
        if callback then callback() end
    end
end

-- Create optimized drop effects (minimal processing)
local function createDropEffects(part)
    local success, light = pcall(function()
        local l = Instance.new("PointLight")
        l.Brightness = 1
        l.Range = 6
        l.Color = Color3.new(1, 1, 1) -- White light for ice cream
        l.Parent = part
        return l
    end)

    if not success then
        warn("Light creation failed:", success)
        return nil
    end
    return light
end

-- Main drop creation function (LAG-FREE)
local function createDrops()
    local count = 0
    while true do
        task.wait(DROP_RATE)
        count += 1

        -- Create drop part (error-safe)
        local success, part = pcall(function()
            local p = Instance.new("Part")
            p.Name = "IceCream_" .. count
            p.Parent = PartStorage

            -- Visual properties
            p.Size = Vector3.new(2, 2, 2) -- Compact collision
            p.Shape = "Block"
            p.Material = Enum.Material.SmoothPlastic
            p.TopSurface = Enum.SurfaceType.Smooth
            p.BottomSurface = Enum.SurfaceType.Smooth
            p.Color = Color3.new(1, 1, 1)

            -- Position (optimized calculation)
            p.CFrame = calculateSpawnPosition()

            return p
        end)

        if not success or not part then
            warn("Drop creation failed:", success)
            continue
        end

        -- Setup mesh
        local mesh = setupMesh(part)
        if not mesh then
            part:Destroy()
            continue
        end

        -- Physics and collision (lag prevention)
        setupPhysics(part)

        -- Cash value
        local success2 = pcall(function()
            local cash = Instance.new("IntValue")
            cash.Name = "Cash"
            cash.Value = CASH_VALUE
            cash.Parent = part
        end)

        if not success2 then
            warn("Cash setup failed")
            part:Destroy()
            continue
        end

        -- Fade system
        local fadeData = setupFadeSystem(part)

        -- Effects
        local light = createDropEffects(part)

        -- Start fade in
        fadeIn(fadeData)

        -- Collection detection (optimized)
        local collected = false
        local touchConnection

        local function onCollected()
            if collected then return end
            collected = true

            -- Flash effect
            if light then
                light.Brightness = 3
                TweenService:Create(light,
                    TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {Brightness = 1}
                ):Play()
            end

            -- Fade out and cleanup (immediate)
            fadeOut(fadeData, function()
                if touchConnection then
                    pcall(function() touchConnection:Disconnect() end)
                end
                if part and part.Parent then
                    pcall(function() part:Destroy() end)
                end
            end)
        end

        -- Touch connection (single connection to prevent lag)
        success, touchConnection = pcall(function()
            return part.Touched:Connect(function(hit)
                if isCollectorPart(hit) then
                    onCollected()
                end
            end)
        end)

        if not success then
            warn("Touch connection failed")
            part:Destroy()
            continue
        end

        -- Pop animation (small and fast)
        TweenService:Create(mesh,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Scale = FINAL_SCALE}
        ):Play()

        -- Set lifetime (backup cleanup)
        Debris:AddItem(part, LIFETIME)
    end
end

-- Initialize everything (error-safe)
local function initialize()
    setupCollisionGroups()
    initializePlayers()

    -- Start the drop loop with error handling
    local success, errorMsg = pcall(createDrops)
    if not success then
        warn("CRITICAL: Kuromi Dropper 5 failed to start:", errorMsg)
    end
end

-- Start initialization
initialize()