--!strict
--[[
	Dropper 1 NEW - HelloKitty Style (FIXED LIKE CINNAMOROLL)
	Collides with conveyor/ground but NOT players or other drops
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
local ORB_GROUP = "HelloKittyDrops1"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(ORB_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	-- Orbs don't collide with players
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, PLAYER_GROUP, false)
	-- Orbs don't collide with each other
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, ORB_GROUP, false)
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

-- Setup existing players
for _, player in ipairs(game.Players:GetPlayers()) do
	if player.Character then
		setupPlayer(player.Character)
	end
end

local dropCount = 0

while true do
	task.wait(1.0) -- Drop rate

	dropCount = dropCount + 1

	-- Create drop
	local orb = Instance.new("Part")
	orb.Name = "HK1Drop_" .. dropCount
	orb.Size = Vector3.new(2, 2, 2)
	orb.Material = Enum.Material.SmoothPlastic
	orb.TopSurface = Enum.SurfaceType.Smooth
	orb.BottomSurface = Enum.SurfaceType.Smooth
	orb.Color = Color3.new(1, 1, 1)
	orb.Transparency = 0.7 -- Start faded for animation

	-- COLLISION: On for world, off for players/other drops
	orb.CanCollide = true -- Collides with conveyor!
	orb.CanTouch = true
	orb.CanQuery = true

	-- Set collision group (NO pcall - direct assignment)
	orb.CollisionGroup = ORB_GROUP

	-- Light physics
	orb.CustomPhysicalProperties = PhysicalProperties.new(
		0.3,  -- Light density
		0.5,  -- Medium friction
		0.2,  -- Low bounce
		1, 1
	)

	-- Cash value - CRITICAL!
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 10
	cash.Parent = orb

	-- Add light
	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 0.6
	pointLight.Range = 4
	pointLight.Color = Color3.new(1, 1, 1)
	pointLight.Parent = orb

	-- Position with small random offset
	local offsetX = math.random(-2, 2) * 0.15
	local offsetZ = math.random(-2, 2) * 0.15
	orb.CFrame = (dropPart.CFrame - Vector3.new(offsetX, 2, offsetZ)) * CFrame.Angles(0, math.rad(math.random(-45, 45)), 0)

	-- Gentle drop velocity
	orb.AssemblyLinearVelocity = Vector3.new(offsetX * 2, -10, offsetZ * 2)

	-- Set spawn time
	orb:SetAttribute("SpawnTime", os.clock())

	-- Parent to storage
	orb.Parent = PartStorage

	-- Smooth fade-in
	local fadeTween = TweenService:Create(orb,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0}
	)
	fadeTween:Play()

	-- Light flash
	pointLight.Brightness = 1.5
	TweenService:Create(pointLight,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0.6}
	):Play()

	-- Spawn ring effect
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
		NumberSequenceKeypoint.new(1, 1)
	})
	spawnRing.Color = ColorSequence.new(Color3.new(1, 1, 1))
	spawnRing.Parent = orb
	spawnRing:Emit(1)
	Debris:AddItem(spawnRing, 1)

	-- Cleanup after 120 seconds
	task.delay(120, function()
		if orb and orb.Parent then
			orb:Destroy()
		end
	end)
end
