--[[
	Hello Kitty Dropper 3 - Premium Style Fixed
	Optimized with anti-stack and rotation lock
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local AntiStack = require(workspace:WaitForChild("DropperAntiStack"))

-- Setup collision groups
AntiStack.SetupCollisionGroups()

-- Setup player collisions
game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(AntiStack.SetupPlayerCollisions)
end)

for _, player in ipairs(game.Players:GetPlayers()) do
	if player.Character then
		AntiStack.SetupPlayerCollisions(player.Character)
	end
end

-- Wait for dependencies
task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

local dropCount = 0

while true do
	task.wait(0.6) -- Fast premium drops
	
	-- Debounce check
	if not AntiStack.CanDrop(0.5) then
		continue
	end
	
	dropCount = dropCount + 1

	-- Create Hello Kitty drop
	local drop = Instance.new("Part")
	drop.Name = "PremiumHelloKitty_" .. dropCount
	drop.Size = Vector3.new(1.817, 1.323, 0.281)
	drop.Material = Enum.Material.SmoothPlastic
	drop.Color = Color3.fromRGB(151, 0, 0)
	drop.TopSurface = Enum.SurfaceType.Smooth
	drop.BottomSurface = Enum.SurfaceType.Smooth
	drop.Transparency = 0

	-- Add Hello Kitty mesh
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://3071180788"
	mesh.TextureId = ""
	mesh.Scale = Vector3.new(1, 1, 1) -- Start small
	mesh.Parent = drop

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 50
	cash.Parent = drop

	-- Pink glow
	local glow = Instance.new("PointLight")
	glow.Brightness = 1
	glow.Range = 8 -- Reduced range
	glow.Color = Color3.fromRGB(255, 100, 150)
	glow.Parent = drop

	-- Minimal star particles
	local starParticles = Instance.new("ParticleEmitter")
	starParticles.Texture = "rbxasset://textures/particles/star.dds"
	starParticles.Rate = 5 -- Reduced
	starParticles.Lifetime = NumberRange.new(1.5, 2.5)
	starParticles.Speed = NumberRange.new(0.5)
	starParticles.SpreadAngle = Vector2.new(90, 90)
	starParticles.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0.05)
	}
	starParticles.Color = ColorSequence.new(Color3.fromRGB(255, 150, 200))
	starParticles.LightEmission = 0.8
	starParticles.Parent = drop

	-- Apply anti-stack physics
	AntiStack.ApplyAntiStackPhysics(drop, dropPart)
	
	-- Set specific rotation
	local spawnCFrame = drop.CFrame * CFrame.Angles(math.rad(70), math.rad(0), math.rad(180))
	drop.CFrame = spawnCFrame

	-- IMPROVED ROTATION LOCK
	local bodyPosition = Instance.new("BodyPosition")
	bodyPosition.MaxForce = Vector3.new(0, math.huge, 0) -- Only affect Y
	bodyPosition.Position = drop.Position
	bodyPosition.Parent = drop

	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bodyGyro.CFrame = spawnCFrame
	bodyGyro.D = 500
	bodyGyro.P = 3000
	bodyGyro.Parent = drop

	-- Parent to storage
	drop.Parent = PartStorage

	-- Spawn animation
	TweenService:Create(mesh,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Scale = Vector3.new(4, 4, 4)}
	):Play()

	-- Light flash
	glow.Brightness = 2
	TweenService:Create(glow,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 1}
	):Play()

	-- Simple spawn ring
	local spawnRing = Instance.new("Part")
	spawnRing.Name = "SpawnEffect"
	spawnRing.Shape = Enum.PartType.Cylinder
	spawnRing.Size = Vector3.new(0.1, 3, 3)
	spawnRing.Material = Enum.Material.ForceField
	spawnRing.Color = Color3.fromRGB(255, 150, 200)
	spawnRing.Transparency = 0.3
	spawnRing.Anchored = true
	spawnRing.CanCollide = false
	spawnRing.CFrame = drop.CFrame * CFrame.Angles(0, 0, math.rad(90))
	spawnRing.Parent = PartStorage

	TweenService:Create(spawnRing,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(0.1, 5, 5), Transparency = 1}
	):Play()

	Debris:AddItem(spawnRing, 0.5)

	-- Schedule cleanup
	AntiStack.ScheduleCleanup(drop, 180) -- 3 minutes
end