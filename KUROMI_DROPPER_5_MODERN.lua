--[[
	Kuromi Dropper 5 - Modern Neon Style
	✅ Purple neon ball with intense effects
	✅ Smooth animations, collision groups
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

local dropPattern = 1

local ORB_GROUP = "KuromiOrbs5"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(ORB_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:RegisterCollisionGroup("KuromiOrbs1")
	PhysicsService:RegisterCollisionGroup("KuromiOrbs2")
	PhysicsService:RegisterCollisionGroup("KuromiOrbs3")
	PhysicsService:RegisterCollisionGroup("KuromiOrbs4")
	
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, PLAYER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, ORB_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs1", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs2", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs3", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs4", false)
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
	task.wait(0.6)
	orbCount = orbCount + 1

	local orb = Instance.new("Part")
	orb.Name = "KuromiDrop5_" .. orbCount
	orb.Size = Vector3.new(3, 3, 3)
	orb.Material = Enum.Material.Neon
	orb.Color = Color3.fromRGB(130, 80, 180)
	orb.Shape = Enum.PartType.Ball
	orb.TopSurface = Enum.SurfaceType.Smooth
	orb.BottomSurface = Enum.SurfaceType.Smooth

	orb.CanCollide = true
	orb.CanTouch = true
	orb.CanQuery = true
	pcall(function() orb.CollisionGroup = ORB_GROUP end)
	orb.CustomPhysicalProperties = PhysicalProperties.new(0.15, 0.3, 0.15, 1, 1)

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 60
	cash.Parent = orb

	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 1.2
	pointLight.Range = 7
	pointLight.Color = Color3.fromRGB(200, 130, 240)
	pointLight.Parent = orb

	-- Intense sparkles
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 18
	sparkle.Lifetime = NumberRange.new(1.5, 2.5)
	sparkle.Speed = NumberRange.new(2, 3.5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0)
	}
	sparkle.Color = ColorSequence.new(Color3.fromRGB(200, 130, 240))
	sparkle.Parent = orb

	-- Purple stars
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = "rbxasset://textures/particles/star.dds"
	stars.Rate = 10
	stars.Lifetime = NumberRange.new(2, 3)
	stars.Speed = NumberRange.new(1, 2)
	stars.SpreadAngle = Vector2.new(360, 360)
	stars.LightEmission = 1
	stars.Size = NumberSequence.new(0.6)
	stars.Color = ColorSequence.new(Color3.fromRGB(220, 150, 255))
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

	orb.CFrame = (dropPart.CFrame - Vector3.new(0, 1.75, 0) + offset)
	orb.AssemblyLinearVelocity = Vector3.new(offset.X * 2, -10, offset.Z * 2)
	orb.Transparency = 0.7
	orb:SetAttribute("SpawnTime", tick())
	orb.Parent = PartStorage

	orb.Size = Vector3.new(0.3, 0.3, 0.3)

	TweenService:Create(orb,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0}
	):Play()

	TweenService:Create(orb,
		TweenInfo.new(0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{Size = Vector3.new(3, 3, 3)}
	):Play()

	pointLight.Brightness = 3
	TweenService:Create(pointLight,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 1.2}
	):Play()

	-- Spawn ring
	local spawnRing = Instance.new("Part")
	spawnRing.Shape = Enum.PartType.Cylinder
	spawnRing.Size = Vector3.new(0.1, 3, 3)
	spawnRing.Material = Enum.Material.Neon
	spawnRing.Color = Color3.fromRGB(200, 130, 240)
	spawnRing.Transparency = 0.2
	spawnRing.Anchored = true
	spawnRing.CanCollide = false
	spawnRing.CFrame = orb.CFrame * CFrame.Angles(0, 0, math.rad(90))
	spawnRing.Parent = PartStorage

	TweenService:Create(spawnRing,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(0.1, 7, 7), Transparency = 1}
	):Play()

	task.delay(0.5, function()
		spawnRing:Destroy()
	end)
end
