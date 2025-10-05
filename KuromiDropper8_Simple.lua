--[[
	Kuromi Dropper 8 - SIMPLIFIED (Pink Square)
	✅ Simple part dropper (no complex features)
	✅ Basic collision groups
	✅ No remote event spam
	✅ Just works
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

-- Wait for services
task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

-- Simple collision groups
local DROP_GROUP = "KuromiOrbs8"
local PLAYER_GROUP = "Players"

-- Setup collision groups (simple)
pcall(function()
    PhysicsService:RegisterCollisionGroup(DROP_GROUP)
    PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
    PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, PLAYER_GROUP, false)
    PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, DROP_GROUP, false)
end)

-- Setup player collision
local function setupPlayerCollision(character)
    task.wait(0.1)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CollisionGroup = PLAYER_GROUP end)
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(setupPlayerCollision)
end)
for _, player in ipairs(Players:GetPlayers()) do
    if player.Character then setupPlayerCollision(player.Character) end
end

-- Simple drop loop
while true do
    task.wait(0.5) -- Drop rate

    -- Create simple pink part
    local part = Instance.new("Part")
    part.Name = "KuromiDrop_" .. math.random(1000, 9999)
    part.Parent = PartStorage

    -- Simple visual properties
    part.Size = Vector3.new(1, 1, 1)
    part.BrickColor = BrickColor.new("Hot pink")
    part.Material = Enum.Material.SmoothPlastic
    part.Shape = "Block"
    part.TopSurface = "Smooth"
    part.BottomSurface = "Smooth"

    -- Simple position
    local offsetX = math.random(-2, 2) * 0.1
    local offsetZ = math.random(-2, 2) * 0.1
    part.CFrame = dropPart.CFrame - Vector3.new(offsetX, 2.5, offsetZ)

    -- Simple physics
    part.Anchored = false
    part.CanTouch = true
    part.CanQuery = true
    part.CollisionGroup = DROP_GROUP

    -- Simple cash value
    local cash = Instance.new("IntValue")
    cash.Name = "Cash"
    cash.Value = 100
    cash.Parent = part

    -- Simple fade in
    part.Transparency = 1
    TweenService:Create(part,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Transparency = 0}
    ):Play()

    -- Simple collection detection
    local collected = false
    part.Touched:Connect(function(hit)
        if collected then return end

        -- Check if it's a collector
        local isCollector = false
        local hitName = string.lower(hit.Name)
        local parentName = hit.Parent and string.lower(hit.Parent.Name) or ""

        if hitName:find("collect") or parentName:find("collect") or
           hitName:find("sell") or parentName:find("sell") then
            isCollector = true
        end

        if isCollector then
            collected = true

            -- Safety freeze - prevent duplicate touches while fading
            part.Anchored = true
            part.CanCollide = false
            part.CanTouch = false

            -- Simple fade out and destroy (no money collection triggering)
            TweenService:Create(part,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {Transparency = 1}
            ):Play()

            task.delay(0.3, function()
                if part and part.Parent then
                    part:Destroy()
                end
            end)
        end
    end)

    -- Simple lifetime
    Debris:AddItem(part, 20)
end