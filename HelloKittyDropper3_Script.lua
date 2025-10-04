--[[
	Hello Kitty Dropper 3 - Premium Style
	Uses Hello Kitty mesh with red/pink effects
	NO CLEANUP - Items stay until collected
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

-- Wait for PartStorage
task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")

-- Find the Drop part
local dropPart = script.Parent:WaitForChild("Drop")

-- Create collision groups
local ORB_GROUP = "HelloKittyOrbs3"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(ORB_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:RegisterCollisionGroup("HelloKittyOrbs") -- Dropper 1
	PhysicsService:RegisterCollisionGroup("HelloKittyOrbs2") -- Dropper 2
	-- Orbs don't collide with players
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, PLAYER_GROUP, false)
	-- Orbs don't collide with each other
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, ORB_GROUP, false)
	-- Don't collide with other Hello Kitty droppers
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "HelloKittyOrbs", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "HelloKittyOrbs2", false)
end)

-- Setup player collision groups
local function setupPlayer(character)
	task.wait(0.1)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				part.CollisionGroup = PLAYER_GROUP
			end)
		end
	end
end

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(setupPlayer)
end)

for _, player in ipairs(game.Players:GetPlayers()) do
	if player.Character then
		setupPlayer(player.Character)
	end
end

local dropCount = 0

while true do
	task.wait(0.6) -- Fast drop rate for premium
	dropCount = dropCount + 1

	-- Create Hello Kitty drop part
	local drop = Instance.new("Part")
	drop.Name = "PremiumHelloKitty_" .. dropCount
	drop.Size = Vector3.new(1.817, 1.323, 0.281) -- Hello Kitty mesh size
	drop.Material = Enum.Material.SmoothPlastic -- Clean material for mesh
	drop.Color = Color3.fromRGB(151, 0, 0) -- Red color
	drop.TopSurface = Enum.SurfaceType.Smooth
	drop.BottomSurface = Enum.SurfaceType.Smooth
	drop.Transparency = 0

	-- Add Hello Kitty mesh
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://3071180788" -- Hello Kitty mesh
	mesh.TextureId = "" -- No texture
	mesh.Scale = Vector3.new(6, 6, 6) -- HUGE scale - 4x bigger
	mesh.Parent = drop

	-- COLLISION
	drop.CanCollide = true
	drop.CanTouch = true
	drop.CanQuery = true

	-- Set collision group
	pcall(function()
		drop.CollisionGroup = ORB_GROUP
	end)

	-- Light physics
	drop.CustomPhysicalProperties = PhysicalProperties.new(
		0.2, -- Light
		0.4, -- Medium friction
		0.3, -- Some bounce
		1, 1
	)

	-- Red/pink glow (Hello Kitty premium)
	local glow = Instance.new("PointLight")
	glow.Brightness = 1
	glow.Range = 10
	glow.Color = Color3.fromRGB(255, 100, 150) -- Pink light
	glow.Parent = drop

	-- No sparkles - keeping it clean

	-- Pink star pattern particles
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
	starParticles.Color = ColorSequence.new(Color3.fromRGB(255, 150, 200)) -- Pink stars
	starParticles.LightEmission = 1
	starParticles.Parent = drop

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 50 -- Premium value
	cash.Parent = drop

	-- Position at dropper (laying flat, turned around and left a bit)
	drop.CFrame = (dropPart.CFrame - Vector3.new(0, 1.75, 0)) * CFrame.Angles(math.rad(90), math.rad(195), 0)

	-- Drop with slight spin
	drop.AssemblyLinearVelocity = Vector3.new(0, -10, 0)
	drop.AssemblyAngularVelocity = Vector3.new(0, 5, 0)

	-- Parent to workspace
	drop.Parent = PartStorage

	-- Spawn animation - start tiny, grow to normal
	mesh.Scale = Vector3.new(1.5, 1.5, 1.5)

	TweenService:Create(mesh,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Scale = Vector3.new(6, 6, 6)}
	):Play()

	-- Flash effect
	glow.Brightness = 2
	TweenService:Create(glow,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 1}
	):Play()

	-- Premium spawn ring effect (pink!)
	local spawnRing = Instance.new("Part")
	spawnRing.Name = "SpawnEffect"
	spawnRing.Shape = Enum.PartType.Cylinder
	spawnRing.Size = Vector3.new(0.1, 3, 3)
	spawnRing.Material = Enum.Material.ForceField
	spawnRing.Color = Color3.fromRGB(255, 150, 200) -- Pink ring
	spawnRing.Transparency = 0.3
	spawnRing.Anchored = true
	spawnRing.CanCollide = false
	spawnRing.CFrame = drop.CFrame * CFrame.Angles(0, 0, math.rad(90))
	spawnRing.Parent = PartStorage

	-- Animate spawn ring
	TweenService:Create(spawnRing,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(0.1, 5, 5), Transparency = 1}
	):Play()

	-- Clean up spawn effect
	task.delay(0.4, function()
		spawnRing:Destroy()
	end)

	-- NO CLEANUP - Drops stay until collected!
end
