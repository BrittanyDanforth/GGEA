--[[
	Kuromi Dropper 1 - Basic Starter
	Purple/black theme, basic effects
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

-- Collision groups
local ORB_GROUP = "KuromiOrbs1"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(ORB_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, PLAYER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, ORB_GROUP, false)
end)

-- Setup player collision
local function setupPlayer(character)
	task.wait(0.1)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function() part.CollisionGroup = PLAYER_GROUP end)
		end
	end
end

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(setupPlayer)
end)

for _, player in ipairs(game.Players:GetPlayers()) do
	if player.Character then setupPlayer(player.Character) end
end

local dropCount = 0

while true do
	task.wait(1.2) -- Starter speed
	dropCount = dropCount + 1

	local drop = Instance.new("Part")
	drop.Name = "Kuromi_" .. dropCount
	drop.Size = Vector3.new(1.5, 1.5, 1.5)
	drop.Material = Enum.Material.SmoothPlastic
	drop.Color = Color3.fromRGB(90, 60, 130) -- Dark purple
	drop.Shape = Enum.PartType.Ball
	drop.TopSurface = Enum.SurfaceType.Smooth
	drop.BottomSurface = Enum.SurfaceType.Smooth
	drop.Transparency = 0

	drop.CanCollide = true
	drop.CanTouch = true
	drop.CanQuery = true

	pcall(function() drop.CollisionGroup = ORB_GROUP end)

	drop.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.3, 0.1, 1, 1)

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 10
	cash.Parent = drop

	-- Purple glow
	local glow = Instance.new("PointLight")
	glow.Brightness = 0.8
	glow.Range = 5
	glow.Color = Color3.fromRGB(130, 80, 180)
	glow.Parent = drop

	-- Spawn position
	drop.CFrame = dropPart.CFrame - Vector3.new(0, 1.5, 0)
	drop.AssemblyLinearVelocity = Vector3.new(0, -8, 0)
	drop.Parent = PartStorage

	-- Fade in
	drop.Transparency = 1
	TweenService:Create(drop,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0}
	):Play()

	-- Pop animation
	drop.Size = Vector3.new(0.3, 0.3, 0.3)
	TweenService:Create(drop,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = Vector3.new(1.5, 1.5, 1.5)}
	):Play()

	-- Flash
	glow.Brightness = 2
	TweenService:Create(glow,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0.8}
	):Play()
end
