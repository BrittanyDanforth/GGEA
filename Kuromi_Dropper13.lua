--[[
	Kuromi Dropper 13 - OMEGA FINAL
	MASSIVE ForceField with INSANE effects
	THE ULTIMATE DROPPER
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

local ORB_GROUP = "KuromiOrbs13"
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
	task.wait(0.3) -- FASTEST!
	dropCount = dropCount + 1

	local drop = Instance.new("Part")
	drop.Name = "KuromiOMEGA_" .. dropCount
	drop.Size = Vector3.new(5.5, 5.5, 5.5) -- MASSIVE
	drop.Material = Enum.Material.ForceField
	drop.Color = Color3.fromRGB(150, 100, 200)
	drop.Shape = Enum.PartType.Ball
	drop.TopSurface = Enum.SurfaceType.Smooth
	drop.BottomSurface = Enum.SurfaceType.Smooth

	drop.CanCollide = true
	drop.CanTouch = true
	drop.CanQuery = true
	pcall(function() drop.CollisionGroup = ORB_GROUP end)
	drop.CustomPhysicalProperties = PhysicalProperties.new(0.05, 0.2, 0.35, 1, 1)

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 300 -- OMEGA VALUE
	cash.Parent = drop

	local glow = Instance.new("PointLight")
	glow.Brightness = 6 -- INSANE GLOW
	glow.Range = 25 -- HUGE RANGE
	glow.Color = Color3.fromRGB(230, 150, 255)
	glow.Parent = drop

	-- OMEGA sparkles
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 50 -- MAX SPARKLES
	sparkle.Lifetime = NumberRange.new(3.5, 5)
	sparkle.Speed = NumberRange.new(5, 10)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0)
	}
	sparkle.Color = ColorSequence.new(Color3.fromRGB(230, 150, 255))
	sparkle.Parent = drop

	-- OMEGA Stars
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = "rbxasset://textures/particles/star.dds"
	stars.Rate = 40 -- MAX STARS
	stars.Lifetime = NumberRange.new(4, 6)
	stars.Speed = NumberRange.new(3, 6)
	stars.SpreadAngle = Vector2.new(360, 360)
	stars.LightEmission = 1
	stars.Size = NumberSequence.new(1.5) -- HUGE STARS
	stars.Color = ColorSequence.new(Color3.fromRGB(255, 170, 255))
	stars.Parent = drop

	drop.CFrame = dropPart.CFrame - Vector3.new(0, 1.5, 0)
	drop.AssemblyLinearVelocity = Vector3.new(0, -10, 0)
	drop.Parent = PartStorage

	drop.Transparency = 1
	TweenService:Create(drop,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0}
	):Play()

	drop.Size = Vector3.new(0.3, 0.3, 0.3)
	TweenService:Create(drop,
		TweenInfo.new(1.3, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{Size = Vector3.new(5.5, 5.5, 5.5)}
	):Play()

	glow.Brightness = 12 -- EXPLOSIVE FLASH
	TweenService:Create(glow,
		TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 6}
	):Play()

	-- OMEGA spawn effect - 10 RINGS!
	for i = 1, 10 do
		local spawnRing = Instance.new("Part")
		spawnRing.Shape = Enum.PartType.Cylinder
		spawnRing.Size = Vector3.new(0.1, 6, 6)
		spawnRing.Material = Enum.Material.ForceField
		spawnRing.Color = Color3.fromRGB(230, 150, 255)
		spawnRing.Transparency = 0.05
		spawnRing.Anchored = true
		spawnRing.CanCollide = false
		spawnRing.CFrame = drop.CFrame * CFrame.Angles(0, 0, math.rad(90))
		spawnRing.Parent = PartStorage

		task.delay(i * 0.06, function()
			TweenService:Create(spawnRing,
				TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Size = Vector3.new(0.1, 20, 20), Transparency = 1}
			):Play()
		end)

		task.delay(1.3, function()
			spawnRing:Destroy()
		end)
	end
end
