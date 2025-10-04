--[[
	Dropper 14 - Modernized Edition
	Features: Smooth animations, collision groups, fade effects, particle effects
	Original: Basic drops
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
local DROP_GROUP = "Dropper14Drops"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(DROP_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	-- Drops don't collide with players
	PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, PLAYER_GROUP, false)
	-- Drops don't collide with each other
	PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, DROP_GROUP, false)
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
	task.wait(0.5) -- Drop rate

	dropCount = dropCount + 1

	-- Create drop part
	local drop = Instance.new("Part")
	drop.Name = "Drop14_" .. dropCount
	drop.Size = Vector3.new(1, 1, 1)
	drop.BrickColor = BrickColor.new("Lime green")
	drop.Material = Enum.Material.Fabric
	drop.TopSurface = Enum.SurfaceType.Smooth
	drop.BottomSurface = Enum.SurfaceType.Smooth
	drop.Transparency = 0

	-- Collision setup
	drop.CanCollide = true
	drop.CanTouch = true
	drop.CanQuery = true

	-- Set collision group
	pcall(function()
		drop.CollisionGroup = DROP_GROUP
	end)

	-- Light weight for smooth movement
	drop.CustomPhysicalProperties = PhysicalProperties.new(
		0.3,  -- Very light density
		0.5,  -- Medium friction
		0.1,  -- Low bounce
		1, 1
	)

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 100
	cash.Parent = drop

	-- Add subtle glow
	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 0.4
	pointLight.Range = 4
	pointLight.Color = Color3.fromRGB(0, 255, 0)  -- Green glow
	pointLight.Parent = drop

	-- Position with small offset
	local offsetX = math.random(-2, 2) * 0.1
	local offsetZ = math.random(-2, 2) * 0.1
	drop.CFrame = dropPart.CFrame - Vector3.new(offsetX, 1.4, offsetZ)

	-- Gentle drop velocity
	drop.AssemblyLinearVelocity = Vector3.new(0, -12, 0)

	-- Set spawn time for cleanup
	drop:SetAttribute("SpawnTime", tick())

	-- Start semi-transparent for fade-in
	drop.Transparency = 0.7

	-- Parent to storage
	drop.Parent = PartStorage

	-- Smooth fade-in
	local fadeTween = TweenService:Create(drop,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0}
	)
	fadeTween:Play()

	-- Scale animation
	local originalSize = drop.Size
	drop.Size = Vector3.new(0.1, 0.1, 0.1)
	
	local scaleTween = TweenService:Create(drop,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = originalSize}
	)
	scaleTween:Play()

	-- Spawn flash
	pointLight.Brightness = 1.5
	TweenService:Create(pointLight,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0.4}
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
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 1)
	})
	spawnRing.Color = ColorSequence.new(Color3.fromRGB(0, 255, 0))  -- Green ring
	spawnRing.Parent = drop
	spawnRing:Emit(1)
	Debris:AddItem(spawnRing, 1)

	-- Cleanup after 2000 seconds
	Debris:AddItem(drop, 2000)
end
