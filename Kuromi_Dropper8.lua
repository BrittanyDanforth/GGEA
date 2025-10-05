--[[
	Kuromi Dropper 8 - Beast Mode
	ForceField material with ultra effects
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

local ORB_GROUP = "KuromiOrbs8"
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
	task.wait(0.5)
	dropCount = dropCount + 1

	local drop = Instance.new("Part")
	drop.Name = "KuromiBeast_" .. dropCount
	drop.Size = Vector3.new(3, 3, 3)
	drop.Material = Enum.Material.ForceField
	drop.Color = Color3.fromRGB(90, 40, 140)
	drop.Shape = Enum.PartType.Ball
	drop.TopSurface = Enum.SurfaceType.Smooth
	drop.BottomSurface = Enum.SurfaceType.Smooth

	drop.CanCollide = true
	drop.CanTouch = true
	drop.CanQuery = true
	pcall(function() drop.CollisionGroup = ORB_GROUP end)
	drop.CustomPhysicalProperties = PhysicalProperties.new(0.1, 0.2, 0.3, 1, 1)

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 100
	cash.Parent = drop

	local glow = Instance.new("PointLight")
	glow.Brightness = 3
	glow.Range = 14
	glow.Color = Color3.fromRGB(180, 100, 220)
	glow.Parent = drop

	-- Ultra sparkles
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 25
	sparkle.Lifetime = NumberRange.new(2, 3)
	sparkle.Speed = NumberRange.new(3, 5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0)
	}
	sparkle.Color = ColorSequence.new(Color3.fromRGB(180, 100, 220))
	sparkle.Parent = drop

	-- Stars
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = "rbxasset://textures/particles/star.dds"
	stars.Rate = 15
	stars.Lifetime = NumberRange.new(2.5, 3.5)
	stars.Speed = NumberRange.new(1.5, 3)
	stars.SpreadAngle = Vector2.new(360, 360)
	stars.LightEmission = 1
	stars.Size = NumberSequence.new(0.8)
	stars.Color = ColorSequence.new(Color3.fromRGB(220, 140, 255))
	stars.Parent = drop

	drop.CFrame = dropPart.CFrame - Vector3.new(0, 1.5, 0)
	drop.AssemblyLinearVelocity = Vector3.new(0, -10, 0)
	drop.Parent = PartStorage

	drop.Transparency = 1
	TweenService:Create(drop,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0}
	):Play()

	drop.Size = Vector3.new(0.3, 0.3, 0.3)
	TweenService:Create(drop,
		TweenInfo.new(0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{Size = Vector3.new(3, 3, 3)}
	):Play()

	glow.Brightness = 6
	TweenService:Create(glow,
		TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 3}
	):Play()

	-- Triple spawn rings
	for i = 1, 3 do
		local spawnRing = Instance.new("Part")
		spawnRing.Shape = Enum.PartType.Cylinder
		spawnRing.Size = Vector3.new(0.1, 3, 3)
		spawnRing.Material = Enum.Material.ForceField
		spawnRing.Color = Color3.fromRGB(180, 100, 220)
		spawnRing.Transparency = 0.1
		spawnRing.Anchored = true
		spawnRing.CanCollide = false
		spawnRing.CFrame = drop.CFrame * CFrame.Angles(0, 0, math.rad(90))
		spawnRing.Parent = PartStorage

		task.delay(i * 0.1, function()
			TweenService:Create(spawnRing,
				TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Size = Vector3.new(0.1, 10, 10), Transparency = 1}
			):Play()
		end)

		task.delay(0.8, function()
			spawnRing:Destroy()
		end)
	end
end
