--[[
	Kuromi Dropper 8 - Modern Beast Style
	✅ Huge purple ForceField ball with ultra effects
	✅ Smooth animations, collision groups
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

local dropPattern = 1

local ORB_GROUP = "KuromiOrbs8"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(ORB_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	for i = 1, 6 do
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
	orb.Name = "KuromiDrop8_" .. orbCount
	orb.Size = Vector3.new(4, 4, 4)
	orb.Material = Enum.Material.ForceField
	orb.Color = Color3.fromRGB(90, 50, 140)
	orb.Shape = Enum.PartType.Ball
	orb.TopSurface = Enum.SurfaceType.Smooth
	orb.BottomSurface = Enum.SurfaceType.Smooth

	orb.CanCollide = true
	orb.CanTouch = true
	orb.CanQuery = true
	pcall(function() orb.CollisionGroup = ORB_GROUP end)
	orb.CustomPhysicalProperties = PhysicalProperties.new(0.1, 0.2, 0.25, 1, 1)

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 100
	cash.Parent = orb

	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 2.5
	pointLight.Range = 13
	pointLight.Color = Color3.fromRGB(180, 110, 230)
	pointLight.Parent = orb

	-- Beast sparkles
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 30
	sparkle.Lifetime = NumberRange.new(2, 3.5)
	sparkle.Speed = NumberRange.new(3, 5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0)
	}
	sparkle.Color = ColorSequence.new(Color3.fromRGB(180, 110, 230))
	sparkle.Parent = orb

	-- Stars
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = "rbxasset://textures/particles/star.dds"
	stars.Rate = 20
	stars.Lifetime = NumberRange.new(3, 4)
	stars.Speed = NumberRange.new(2, 3)
	stars.SpreadAngle = Vector2.new(360, 360)
	stars.LightEmission = 1
	stars.Size = NumberSequence.new(1)
	stars.Color = ColorSequence.new(Color3.fromRGB(230, 150, 255))
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
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0}
	):Play()

	TweenService:Create(orb,
		TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{Size = Vector3.new(4, 4, 4)}
	):Play()

	pointLight.Brightness = 5
	TweenService:Create(pointLight,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 2.5}
	):Play()

	-- Triple spawn rings
	for i = 1, 3 do
		local spawnRing = Instance.new("Part")
		spawnRing.Shape = Enum.PartType.Cylinder
		spawnRing.Size = Vector3.new(0.1, 4, 4)
		spawnRing.Material = Enum.Material.ForceField
		spawnRing.Color = Color3.fromRGB(180, 110, 230)
		spawnRing.Transparency = 0.1
		spawnRing.Anchored = true
		spawnRing.CanCollide = false
		spawnRing.CFrame = orb.CFrame * CFrame.Angles(0, 0, math.rad(90))
		spawnRing.Parent = PartStorage

		task.delay(i * 0.1, function()
			TweenService:Create(spawnRing,
				TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Size = Vector3.new(0.1, 11, 11), Transparency = 1}
			):Play()
		end)

		task.delay(0.8, function()
			spawnRing:Destroy()
		end)
	end
end
