--[[
	Kuromi Dropper 3 - Premium Dark Style
	✅ FIXED: All droppers pass through each other
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

-- Collision groups
local ORB_GROUP = "KuromiOrbs3"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(ORB_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	-- Register other Kuromi dropper groups
	PhysicsService:RegisterCollisionGroup("KuromiOrbs1")
	PhysicsService:RegisterCollisionGroup("KuromiOrbs2")
	
	-- This dropper doesn't collide with players
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, PLAYER_GROUP, false)
	-- This dropper doesn't collide with itself
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, ORB_GROUP, false)
	-- This dropper doesn't collide with other Kuromi droppers
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs1", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs2", false)
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
	drop.Name = "PremiumKuromi_" .. dropCount
	drop.Size = Vector3.new(1.479, 1.158, 0.408)
	drop.Material = Enum.Material.SmoothPlastic
	drop.Color = Color3.fromRGB(17, 17, 17)
	drop.TopSurface = Enum.SurfaceType.Smooth
	drop.BottomSurface = Enum.SurfaceType.Smooth
	drop.Transparency = 0

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://431221914"
	mesh.TextureId = ""
	mesh.Scale = Vector3.new(0.25, 0.25, 0.25)
	mesh.Parent = drop

	drop.CanCollide = true
	drop.CanTouch = true
	drop.CanQuery = true
	pcall(function() drop.CollisionGroup = ORB_GROUP end)

	drop.CustomPhysicalProperties = PhysicalProperties.new(0.2, 0.4, 0.3, 1, 1)

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 50
	cash.Parent = drop

	local glow = Instance.new("PointLight")
	glow.Brightness = 1
	glow.Range = 10
	glow.Color = Color3.fromRGB(200, 150, 230)
	glow.Parent = drop

	-- Star particles
	local starParticles = Instance.new("ParticleEmitter")
	starParticles.Texture = "rbxasset://textures/particles/star.dds"
	starParticles.Rate = 10
	starParticles.Lifetime = NumberRange.new(2, 3)
	starParticles.Speed = NumberRange.new(1)
	starParticles.SpreadAngle = Vector2.new(180, 180)
	starParticles.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0.1)
	}
	starParticles.Color = ColorSequence.new(Color3.fromRGB(255, 150, 220))
	starParticles.LightEmission = 1
	starParticles.Parent = drop

	drop.CFrame = (dropPart.CFrame - Vector3.new(0, 1.75, 0)) * CFrame.Angles(math.rad(90), math.rad(195), 0)
	drop.AssemblyLinearVelocity = Vector3.new(0, -10, 0)
	drop.AssemblyAngularVelocity = Vector3.new(0, 5, 0)
	drop.Parent = PartStorage

	mesh.Scale = Vector3.new(0.06, 0.06, 0.06)

	TweenService:Create(mesh,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Scale = Vector3.new(0.25, 0.25, 0.25)}
	):Play()

	glow.Brightness = 2
	TweenService:Create(glow,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 1}
	):Play()

	-- Spawn ring
	local spawnRing = Instance.new("Part")
	spawnRing.Name = "SpawnEffect"
	spawnRing.Shape = Enum.PartType.Cylinder
	spawnRing.Size = Vector3.new(0.1, 3, 3)
	spawnRing.Material = Enum.Material.ForceField
	spawnRing.Color = Color3.fromRGB(200, 150, 230)
	spawnRing.Transparency = 0.3
	spawnRing.Anchored = true
	spawnRing.CanCollide = false
	spawnRing.CFrame = drop.CFrame * CFrame.Angles(0, 0, math.rad(90))
	spawnRing.Parent = PartStorage

	TweenService:Create(spawnRing,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(0.1, 5, 5), Transparency = 1}
	):Play()

	task.delay(0.4, function()
		spawnRing:Destroy()
	end)
end
