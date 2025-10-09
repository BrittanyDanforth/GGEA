--[[
	Hello Kitty Dropper 3 - Premium Style
	Uses Hello Kitty mesh with red/pink effects
	Built-in anti-stack and rotation lock
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
	-- Orbs don't collide with players
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, PLAYER_GROUP, false)
	-- Orbs DO collide with each other to prevent stacking
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, ORB_GROUP, true)
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

-- Anti-stack patterns
local dropCount = 0
local patterns = {
	Vector3.new(0.3, 0, 0.3),
	Vector3.new(-0.3, 0, 0.3),
	Vector3.new(0.3, 0, -0.3),
	Vector3.new(-0.3, 0, -0.3),
	Vector3.new(0, 0, 0),
	Vector3.new(0.4, 0, 0),
	Vector3.new(-0.4, 0, 0),
}
local patternIndex = 1

while true do
	task.wait(0.6) -- Fast drop rate for premium
	dropCount = dropCount + 1

	-- Create Hello Kitty drop part
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
	mesh.Scale = Vector3.new(4, 4, 4)
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

	-- Red/pink glow
	local glow = Instance.new("PointLight")
	glow.Brightness = 1
	glow.Range = 10
	glow.Color = Color3.fromRGB(255, 100, 150)
	glow.Parent = drop

	-- Pink star particles
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
	starParticles.Color = ColorSequence.new(Color3.fromRGB(255, 150, 200))
	starParticles.LightEmission = 1
	starParticles.Parent = drop

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 50
	cash.Parent = drop

	-- Anti-stack pattern position
	local offset = patterns[patternIndex]
	patternIndex = (patternIndex % #patterns) + 1

	-- Position at dropper with pattern offset
	local spawnCFrame = (dropPart.CFrame - Vector3.new(offset.X, 1.75, offset.Z)) * CFrame.Angles(math.rad(70), math.rad(0), math.rad(180))
	drop.CFrame = spawnCFrame

	-- LOCK ROTATION - Keep the angle!
	local attachment = Instance.new("Attachment")
	attachment.Parent = drop

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.MaxTorque = 100000
	alignOrientation.Responsiveness = 200
	alignOrientation.CFrame = spawnCFrame
	alignOrientation.Parent = drop

	-- Drop with slight spread (anti-stack)
	drop.AssemblyLinearVelocity = Vector3.new(offset.X * 3, -10, offset.Z * 3)
	drop.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

	-- Parent to workspace
	drop.Parent = PartStorage

	-- Spawn animation - start tiny, grow to normal
	mesh.Scale = Vector3.new(1, 1, 1)

	TweenService:Create(mesh,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Scale = Vector3.new(4, 4, 4)}
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
	spawnRing.Color = Color3.fromRGB(255, 150, 200)
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

	-- Cleanup after 3 minutes
	task.delay(180, function()
		if drop and drop.Parent then
			drop:Destroy()
		end
	end)
end