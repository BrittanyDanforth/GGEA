--[[
	Kuromi Dropper 6 - Modern Epic Style
	✅ Large purple neon with epic effects
	✅ Smooth animations, collision groups
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

local dropPattern = 1

local ORB_GROUP = "KuromiOrbs6"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(ORB_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	for i = 1, 5 do
		PhysicsService:RegisterCollisionGroup("KuromiOrbs" .. i)
		PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs" .. i, false)
	end
	
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

local orbCount = 0

while true do
	task.wait(0.5)
	orbCount = orbCount + 1

	local orb = Instance.new("Part")
	orb.Name = "KuromiDrop6_" .. orbCount
	orb.Size = Vector3.new(3.5, 3.5, 3.5)
	orb.Material = Enum.Material.Neon
	orb.Color = Color3.fromRGB(140, 90, 190)
	orb.Shape = Enum.PartType.Ball
	orb.TopSurface = Enum.SurfaceType.Smooth
	orb.BottomSurface = Enum.SurfaceType.Smooth

	orb.CanCollide = true
	orb.CanTouch = true
	orb.CanQuery = true
	pcall(function() orb.CollisionGroup = ORB_GROUP end)
	orb.CustomPhysicalProperties = PhysicalProperties.new(0.12, 0.3, 0.2, 1, 1)

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 80
	cash.Parent = orb

	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 1.8
	pointLight.Range = 10
	pointLight.Color = Color3.fromRGB(220, 140, 255)
	pointLight.Parent = orb

	-- Epic sparkles
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 25
	sparkle.Lifetime = NumberRange.new(2, 3)
	sparkle.Speed = NumberRange.new(2, 4)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0)
	}
	sparkle.Color = ColorSequence.new(Color3.fromRGB(220, 140, 255))
	sparkle.Parent = orb

	-- Stars
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = "rbxasset://textures/particles/star.dds"
	stars.Rate = 15
	stars.Lifetime = NumberRange.new(2.5, 3.5)
	stars.Speed = NumberRange.new(1.5, 2.5)
	stars.SpreadAngle = Vector2.new(360, 360)
	stars.LightEmission = 1
	stars.Size = NumberSequence.new(0.8)
	stars.Color = ColorSequence.new(Color3.fromRGB(240, 160, 255))
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
		TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0}
	):Play()

	TweenService:Create(orb,
		TweenInfo.new(0.9, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{Size = Vector3.new(3.5, 3.5, 3.5)}
	):Play()

	pointLight.Brightness = 4
	TweenService:Create(pointLight,
		TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 1.8}
	):Play()

	-- Double spawn rings
	for i = 1, 2 do
		local spawnRing = Instance.new("Part")
		spawnRing.Shape = Enum.PartType.Cylinder
		spawnRing.Size = Vector3.new(0.1, 4, 4)
		spawnRing.Material = Enum.Material.Neon
		spawnRing.Color = Color3.fromRGB(220, 140, 255)
		spawnRing.Transparency = 0.15
		spawnRing.Anchored = true
		spawnRing.CanCollide = false
		spawnRing.CFrame = orb.CFrame * CFrame.Angles(0, 0, math.rad(90))
		spawnRing.Parent = PartStorage

		task.delay(i * 0.1, function()
			TweenService:Create(spawnRing,
				TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Size = Vector3.new(0.1, 9, 9), Transparency = 1}
			):Play()
		end)

		task.delay(0.7, function()
			spawnRing:Destroy()
		end)
	end
end
