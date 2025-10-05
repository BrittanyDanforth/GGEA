--[[
	Kuromi Dropper 10 - LAG-FREE & OPTIMIZED
	✅ Ultra-low physics values for zero lag
	✅ Optimized tween management
	✅ Faster fade times
	✅ Perfect memory cleanup
	✅ Error-safe execution
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- =================== OPTIMIZED CONFIG ===================
local DROP_RATE = 0.5
local CASH_VALUE = 100
local SPAWN_HEIGHT_OFFSET = -2.5
local FADE_TIME = 0.3
local LIFETIME = 2000

local PHYSICS_DENSITY = 0.05
local PHYSICS_FRICTION = 0.2
local PHYSICS_ELASTICITY = 0.0

local DROP_COLOR = BrickColor.new("Lime green")
local DROP_MATERIAL = "Fabric"
local DROP_SIZE = Vector3.new(1, 1, 1)

local COLLECTOR_NAMES = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" }
local COLLECTOR_TAGS = { "Collector", "SellZone" }
local DROP_GROUP = "KuromiOrbs10"
local PLAYER_GROUP = "Players"
-- =================== END CONFIG ===================

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

local function setupCollisionGroups()
    pcall(function()
        -- Register our collision groups (safe - won't error if already registered)
        PhysicsService:RegisterCollisionGroup(DROP_GROUP)
        PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)

        -- Set collision relationships (safe - only if groups exist)
        pcall(function() PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, PLAYER_GROUP, false) end)
        pcall(function() PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, DROP_GROUP, false) end)
    end)
end

local function setupPlayerCollision(character)
    task.wait(0.1)
    pcall(function()
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CollisionGroup = PLAYER_GROUP
            end
        end
    end)
end

local function initializePlayers()
    pcall(function()
        Players.PlayerAdded:Connect(function(player)
            player.CharacterAdded:Connect(setupPlayerCollision)
        end)
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then setupPlayerCollision(player.Character) end
        end
    end)
end

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

local function setupPhysics(part)
    pcall(function()
        part.Anchored = false
        part.CanTouch = true
        part.CanQuery = true
        part.CollisionGroup = DROP_GROUP
        part.CustomPhysicalProperties = PhysicalProperties.new(
            PHYSICS_DENSITY, PHYSICS_FRICTION, PHYSICS_ELASTICITY, 0.5, 0.5
        )
    end)
end

local function calculateSpawnPosition()
    local offsetX = math.random(-2, 2) * 0.1
    local offsetZ = math.random(-2, 2) * 0.1
    local spawnY = dropPart.Position.Y + SPAWN_HEIGHT_OFFSET
    return CFrame.new(dropPart.Position.X - offsetX, spawnY, dropPart.Position.Z - offsetZ)
end

local function setupFadeSystem(part)
    local originalTransparency = part.Transparency
    part.Transparency = 1
    return {part = part, originalTransparency = originalTransparency, activeTween = nil}
end

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
    end
    return nil
end

local function fadeOut(fadeData, callback)
    pcall(function()
        if fadeData.activeTween then fadeData.activeTween:Cancel() end
        local tween = TweenService:Create(
            fadeData.part,
            TweenInfo.new(FADE_TIME * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Transparency = 1 }
        )
        tween:Play()
        task.delay(FADE_TIME + 0.02, function() if callback then callback() end end)
    end)
end

local function createDropEffects(part)
    pcall(function()
        local light = Instance.new("PointLight")
        light.Brightness = 1
        light.Range = 6
        light.Color = Color3.fromRGB(50, 255, 50)
        light.Parent = part
    end)
end

local function createDrops()
    local count = 0
    while true do
        task.wait(DROP_RATE)
        count += 1

        local success, part = pcall(function()
            local p = Instance.new("Part")
            p.Name = "KuromiDrop_" .. count
            p.Parent = PartStorage
            p.BrickColor = DROP_COLOR
            p.Material = DROP_MATERIAL
            p.Size = DROP_SIZE
            p.Shape = "Block"
            p.TopSurface = "Smooth"
            p.BottomSurface = "Smooth"
            p.CFrame = calculateSpawnPosition()
            return p
        end)

        if not success or not part then continue end

        setupPhysics(part)
        pcall(function()
            local cash = Instance.new("IntValue")
            cash.Name = "Cash"
            cash.Value = CASH_VALUE
            cash.Parent = part
        end)

        local fadeData = setupFadeSystem(part)
        local light = createDropEffects(part)
        fadeIn(fadeData)

        local collected = false
        local touchConnection

        local function onCollected()
            if collected then return end
            collected = true
            if light then
                light.Brightness = 3
                TweenService:Create(light,
                    TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {Brightness = 1}
                ):Play()
            end
            fadeOut(fadeData, function()
                pcall(function()
                    if touchConnection then touchConnection:Disconnect() end
                    if part and part.Parent then part:Destroy() end
                end)
            end)
        end

        success, touchConnection = pcall(function()
            return part.Touched:Connect(function(hit)
                if isCollectorPart(hit) then onCollected() end
            end)
        end)

        if not success then
            part:Destroy()
            continue
        end

        local originalSize = part.Size
        part.Size = Vector3.new(0.1, 0.1, 0.1)
        TweenService:Create(part,
            TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = originalSize}
        ):Play()

        Debris:AddItem(part, LIFETIME)
    end
end

setupCollisionGroups()
initializePlayers()
local success, errorMsg = pcall(createDrops)
if not success then warn("Kuromi Dropper 10 failed:", errorMsg) end