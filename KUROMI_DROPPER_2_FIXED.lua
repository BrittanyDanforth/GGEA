--[[
	Kuromi Dropper 2 - Enhanced Kawaii Style
	✅ FIXED: All droppers pass through each other
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

local dropPattern = 1

-- Collision groups
local ORB_GROUP = "KuromiOrbs2"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(ORB_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	-- Register other Kuromi dropper groups
	PhysicsService:RegisterCollisionGroup("KuromiOrbs1")
	PhysicsService:RegisterCollisionGroup("KuromiOrbs3")
	
	-- This dropper doesn't collide with players
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, PLAYER_GROUP, false)
	-- This dropper doesn't collide with itself
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, ORB_GROUP, false)
	-- This dropper doesn't collide with other Kuromi droppers
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs1", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs3", false)
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

local orbCount = 0

while true do
	task.wait(1)
	orbCount = orbCount + 1

	local orb = Instance.new("Part")
	orb.Name = "KuromiDrop2_" .. orbCount
	orb.Size = Vector3.new(1.782, 1.103, 1.714)
	orb.Material = Enum.Material.SmoothPlastic
	orb.TopSurface = Enum.SurfaceType.Smooth
	orb.BottomSurface = Enum.SurfaceType.Smooth
	orb.Color = Color3.new(1, 1, 1)
	orb.Transparency = 0

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://17087317963"
	mesh.TextureId = "rbxassetid://17087030178"
	mesh.Scale = Vector3.new(1.5, 1.5, 1.5)
	mesh.Parent = orb

	orb.CanCollide = true
	orb.CanTouch = true
	orb.CanQuery = true
	pcall(function() orb.CollisionGroup = ORB_GROUP end)

	orb.CustomPhysicalProperties = PhysicalProperties.new(0.2, 0.3, 0, 1, 1)

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 15
	cash.Parent = orb

	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 0.6
	pointLight.Range = 4
	pointLight.Color = Color3.fromRGB(200, 150, 230)
	pointLight.Parent = orb

	-- Sparkles
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 5
	sparkle.Lifetime = NumberRange.new(0.5, 1.5)
	sparkle.Speed = NumberRange.new(0.5, 2)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.LightInfluence = 0
	sparkle.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0)
	}
	sparkle.Color = ColorSequence.new(Color3.fromRGB(200, 150, 230))
	sparkle.Parent = orb

	-- Stars
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = "rbxasset://textures/particles/star.dds"
	stars.Rate = 2
	stars.Lifetime = NumberRange.new(1, 2)
	stars.Speed = NumberRange.new(0.5)
	stars.SpreadAngle = Vector2.new(360, 360)
	stars.LightEmission = 0.8
	stars.Size = NumberSequence.new(0.4)
	stars.Color = ColorSequence.new(Color3.fromRGB(255, 150, 220))
	stars.Parent = orb

	local patterns = {
		Vector3.new(0.2, 0, 0.2),
		Vector3.new(-0.2, 0, 0.2),
		Vector3.new(0.2, 0, -0.2),
		Vector3.new(-0.2, 0, -0.2),
		Vector3.new(0, 0, 0),
	}
	local offset = patterns[dropPattern]
	dropPattern = (dropPattern % #patterns) + 1

	orb.CFrame = (dropPart.CFrame - Vector3.new(0, 1.75, 0) + offset) * CFrame.Angles(math.rad(180), math.rad(320), 0)
	orb.AssemblyLinearVelocity = Vector3.new(offset.X * 2, -10, offset.Z * 2)
	orb.Transparency = 0.7
	orb:SetAttribute("SpawnTime", tick())
	orb.Parent = PartStorage

	mesh.Scale = Vector3.new(0.4, 0.4, 0.4)

	TweenService:Create(orb,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0}
	):Play()

	TweenService:Create(mesh,
		TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{Scale = Vector3.new(1.5, 1.5, 1.5)}
	):Play()

	pointLight.Brightness = 2
	TweenService:Create(pointLight,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0.6}
	):Play()

	local spawnPuff = Instance.new("ParticleEmitter")
	spawnPuff.Texture = "rbxassetid://262979222"
	spawnPuff.Rate = 0
	spawnPuff.Speed = NumberRange.new(0)
	spawnPuff.Lifetime = NumberRange.new(0.4)
	spawnPuff.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 2.5)
	})
	spawnPuff.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1)
	})
	spawnPuff.Color = ColorSequence.new(Color3.fromRGB(200, 150, 230))
	spawnPuff.Parent = orb
	spawnPuff:Emit(2)
	Debris:AddItem(spawnPuff, 1)
end
