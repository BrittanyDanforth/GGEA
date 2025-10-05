--[[
	Kuromi Dropper 4 - Modern Style
	✅ Purple ball with enhanced effects
	✅ Smooth animations, collision groups
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

local dropPattern = 1

local ORB_GROUP = "KuromiOrbs4"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(ORB_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:RegisterCollisionGroup("KuromiOrbs1")
	PhysicsService:RegisterCollisionGroup("KuromiOrbs2")
	PhysicsService:RegisterCollisionGroup("KuromiOrbs3")
	
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, PLAYER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, ORB_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs1", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs2", false)
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
	task.wait(0.7)
	orbCount = orbCount + 1

	local orb = Instance.new("Part")
	orb.Name = "KuromiDrop4_" .. orbCount
	orb.Size = Vector3.new(2.5, 2.5, 2.5)
	orb.Material = Enum.Material.Neon
	orb.Color = Color3.fromRGB(110, 60, 160)
	orb.Shape = Enum.PartType.Ball
	orb.TopSurface = Enum.SurfaceType.Smooth
	orb.BottomSurface = Enum.SurfaceType.Smooth

	orb.CanCollide = true
	orb.CanTouch = true
	orb.CanQuery = true
	pcall(function() orb.CollisionGroup = ORB_GROUP end)
	orb.CustomPhysicalProperties = PhysicalProperties.new(0.2, 0.3, 0.1, 1, 1)

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 40
	cash.Parent = orb

	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 0.8
	pointLight.Range = 5
	pointLight.Color = Color3.fromRGB(180, 110, 220)
	pointLight.Parent = orb

	-- Enhanced sparkles
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 12
	sparkle.Lifetime = NumberRange.new(1, 2)
	sparkle.Speed = NumberRange.new(1, 2.5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0)
	}
	sparkle.Color = ColorSequence.new(Color3.fromRGB(180, 110, 220))
	sparkle.Parent = orb

	-- Purple stars
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = "rbxasset://textures/particles/star.dds"
	stars.Rate = 6
	stars.Lifetime = NumberRange.new(1.5, 2.5)
	stars.Speed = NumberRange.new(0.8, 1.5)
	stars.SpreadAngle = Vector2.new(360, 360)
	stars.LightEmission = 0.9
	stars.Size = NumberSequence.new(0.5)
	stars.Color = ColorSequence.new(Color3.fromRGB(200, 130, 240))
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
		TweenInfo.new(0.7, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{Size = Vector3.new(2.5, 2.5, 2.5)}
	):Play()

	pointLight.Brightness = 2.5
	TweenService:Create(pointLight,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0.8}
	):Play()

	local spawnPuff = Instance.new("ParticleEmitter")
	spawnPuff.Texture = "rbxassetid://262979222"
	spawnPuff.Rate = 0
	spawnPuff.Speed = NumberRange.new(0)
	spawnPuff.Lifetime = NumberRange.new(0.4)
	spawnPuff.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 3)
	})
	spawnPuff.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1)
	})
	spawnPuff.Color = ColorSequence.new(Color3.fromRGB(180, 110, 220))
	spawnPuff.Parent = orb
	spawnPuff:Emit(2)
	Debris:AddItem(spawnPuff, 1)
end
