--[[
	Kuromi Dropper 5 - Neon Style
	Purple neon with intense glow
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

local ORB_GROUP = "KuromiOrbs5"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(ORB_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, PLAYER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, ORB_GROUP, false)
end)

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
	task.wait(0.6)
	dropCount = dropCount + 1

	local drop = Instance.new("Part")
	drop.Name = "KuromiNeon_" .. dropCount
	drop.Size = Vector3.new(2.5, 2.5, 2.5)
	drop.Material = Enum.Material.Neon
	drop.Color = Color3.fromRGB(130, 70, 180)
	drop.Shape = Enum.PartType.Ball
	drop.TopSurface = Enum.SurfaceType.Smooth
	drop.BottomSurface = Enum.SurfaceType.Smooth

	drop.CanCollide = true
	drop.CanTouch = true
	drop.CanQuery = true
	pcall(function() drop.CollisionGroup = ORB_GROUP end)
	drop.CustomPhysicalProperties = PhysicalProperties.new(0.15, 0.3, 0.2, 1, 1)

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 60
	cash.Parent = drop

	local glow = Instance.new("PointLight")
	glow.Brightness = 2
	glow.Range = 10
	glow.Color = Color3.fromRGB(200, 120, 240)
	glow.Parent = drop

	-- Intense sparkles
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 15
	sparkle.Lifetime = NumberRange.new(1, 2)
	sparkle.Speed = NumberRange.new(2, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0)
	}
	sparkle.Color = ColorSequence.new(Color3.fromRGB(200, 120, 240))
	sparkle.Parent = drop

	-- Purple stars
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = "rbxasset://textures/particles/star.dds"
	stars.Rate = 8
	stars.Lifetime = NumberRange.new(2, 3)
	stars.Speed = NumberRange.new(1, 2)
	stars.SpreadAngle = Vector2.new(360, 360)
	stars.LightEmission = 1
	stars.Size = NumberSequence.new(0.6)
	stars.Color = ColorSequence.new(Color3.fromRGB(220, 140, 255))
	stars.Parent = drop

	drop.CFrame = dropPart.CFrame - Vector3.new(0, 1.5, 0)
	drop.AssemblyLinearVelocity = Vector3.new(0, -10, 0)
	drop.Parent = PartStorage

	drop.Transparency = 1
	TweenService:Create(drop,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0}
	):Play()

	drop.Size = Vector3.new(0.3, 0.3, 0.3)
	TweenService:Create(drop,
		TweenInfo.new(0.7, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{Size = Vector3.new(2.5, 2.5, 2.5)}
	):Play()

	glow.Brightness = 4
	TweenService:Create(glow,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 2}
	):Play()

	-- Spawn ring
	local spawnRing = Instance.new("Part")
	spawnRing.Shape = Enum.PartType.Cylinder
	spawnRing.Size = Vector3.new(0.1, 3, 3)
	spawnRing.Material = Enum.Material.Neon
	spawnRing.Color = Color3.fromRGB(200, 120, 240)
	spawnRing.Transparency = 0.2
	spawnRing.Anchored = true
	spawnRing.CanCollide = false
	spawnRing.CFrame = drop.CFrame * CFrame.Angles(0, 0, math.rad(90))
	spawnRing.Parent = PartStorage

	TweenService:Create(spawnRing,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(0.1, 7, 7), Transparency = 1}
	):Play()

	task.delay(0.5, function()
		spawnRing:Destroy()
	end)
end
