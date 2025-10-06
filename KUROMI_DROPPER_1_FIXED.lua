--[[
	Kuromi Dropper 1 - Basic Kawaii Style
	✅ FIXED: All droppers pass through each other
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

-- Collision groups
local ORB_GROUP = "KuromiOrbs1"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(ORB_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	-- Register other Kuromi dropper groups
	PhysicsService:RegisterCollisionGroup("KuromiOrbs2")
	PhysicsService:RegisterCollisionGroup("KuromiOrbs3")
	
	-- This dropper doesn't collide with players
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, PLAYER_GROUP, false)
	-- This dropper doesn't collide with itself
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, ORB_GROUP, false)
	-- This dropper doesn't collide with other Kuromi droppers
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs2", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs3", false)
end)

-- Setup player collision
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
	task.wait(1.2)
	orbCount = orbCount + 1

	local orb = Instance.new("Part")
	orb.Name = "KuromiDrop_" .. orbCount
	orb.Size = Vector3.new(3.445, 2.552, 2.148)
	orb.Material = Enum.Material.SmoothPlastic
	orb.TopSurface = Enum.SurfaceType.Smooth
	orb.BottomSurface = Enum.SurfaceType.Smooth
	orb.Color = Color3.new(1, 1, 1)
	orb.Transparency = 0

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://15014438476"
	mesh.TextureId = "rbxassetid://15014443369"
	mesh.Scale = Vector3.new(2, 2, 2)
	mesh.Parent = orb

	orb.CanCollide = true
	orb.CanTouch = true
	orb.CanQuery = true
	pcall(function() orb.CollisionGroup = ORB_GROUP end)

	orb.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.5, 0.1, 1, 1)

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 10
	cash.Parent = orb

	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 0.4
	pointLight.Range = 3
	pointLight.Color = Color3.fromRGB(200, 150, 230)
	pointLight.Parent = orb

	local offsetX = math.random(-2, 2) * 0.1
	local offsetZ = math.random(-2, 2) * 0.1
	orb.CFrame = (dropPart.CFrame - Vector3.new(offsetX, 2, offsetZ)) * CFrame.Angles(math.rad(180), 0, 0)
	orb.AssemblyLinearVelocity = Vector3.new(0, -12, 0)
	orb.Transparency = 0.7
	orb:SetAttribute("SpawnTime", tick())
	orb.Parent = PartStorage

	mesh.Scale = Vector3.new(0.5, 0.5, 0.5)
	
	TweenService:Create(orb,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0}
	):Play()

	TweenService:Create(mesh,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Scale = Vector3.new(2, 2, 2)}
	):Play()

	pointLight.Brightness = 1.5
	TweenService:Create(pointLight,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0.4}
	):Play()

	local spawnRing = Instance.new("ParticleEmitter")
	spawnRing.Texture = "rbxassetid://262979222"
	spawnRing.Rate = 0
	spawnRing.Speed = NumberRange.new(0)
	spawnRing.Lifetime = NumberRange.new(0.3)
	spawnRing.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 2)
	})
	spawnRing.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 1)
	})
	spawnRing.Color = ColorSequence.new(Color3.fromRGB(200, 150, 230))
	spawnRing.Parent = orb
	spawnRing:Emit(1)
	Debris:AddItem(spawnRing, 1)
end
