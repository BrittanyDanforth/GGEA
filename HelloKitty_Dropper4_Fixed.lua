--[[
	Cinnamoroll Dropper 4 - Strawberry Cake Style
	Uses White Heart mesh with sweet effects
	Built-in anti-stack patterns
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
local ORB_GROUP = "CinnamorollOrbs"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(ORB_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, PLAYER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, ORB_GROUP, true)
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

for _, player in ipairs(game.Players:GetPlayers()) do
	if player.Character then
		setupPlayer(player.Character)
	end
end

-- Anti-stack pattern
local cakeCount = 0
local dropPattern = 1
local patterns = {
	Vector3.new(0.2, 0, 0.2),
	Vector3.new(-0.2, 0, 0.2),
	Vector3.new(0.2, 0, -0.2),
	Vector3.new(-0.2, 0, -0.2),
	Vector3.new(0, 0, 0),
}

while true do
	task.wait(0.9) -- Medium-fast drop rate
	cakeCount = cakeCount + 1

	-- Create white heart part
	local cake = Instance.new("Part")
	cake.Name = "WhiteHeart_" .. cakeCount
	cake.Size = Vector3.new(2, 2, 2)
	cake.Material = Enum.Material.SmoothPlastic
	cake.BrickColor = BrickColor.new("Institutional white")
	cake.TopSurface = Enum.SurfaceType.Smooth
	cake.BottomSurface = Enum.SurfaceType.Smooth

	-- Add white heart mesh
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://601198887"
	mesh.TextureId = ""
	mesh.Scale = Vector3.new(1, 1, 1)
	mesh.Parent = cake

	-- Frosting shine
	cake.Reflectance = 0.2

	-- COLLISION
	cake.CanCollide = true
	cake.CanTouch = true
	cake.CanQuery = true

	-- Set collision group
	pcall(function()
		cake.CollisionGroup = ORB_GROUP
	end)

	-- Cake physics
	cake.CustomPhysicalProperties = PhysicalProperties.new(
		0.4, -- Medium density
		0.6, -- Good friction
		0.1, -- Low bounce
		1, 1
	)

	-- Sweet glow
	local glow = Instance.new("PointLight")
	glow.Brightness = 0.6
	glow.Range = 7
	glow.Color = Color3.fromRGB(255, 204, 204)
	glow.Parent = cake

	-- Strawberry particles
	local berries = Instance.new("ParticleEmitter")
	berries.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	berries.Rate = 8
	berries.Lifetime = NumberRange.new(1, 2)
	berries.Speed = NumberRange.new(0.5, 1)
	berries.SpreadAngle = Vector2.new(30, 30)
	berries.Color = ColorSequence.new(Color3.fromRGB(255, 99, 71))
	berries.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0.1)
	}
	berries.LightEmission = 0.5
	berries.Parent = cake

	-- Cream particles
	local cream = Instance.new("ParticleEmitter")
	cream.Texture = "rbxasset://textures/particles/smoke_main.dds"
	cream.Rate = 5
	cream.Lifetime = NumberRange.new(1.5, 2.5)
	cream.Speed = NumberRange.new(0.3)
	cream.SpreadAngle = Vector2.new(45, 45)
	cream.Color = ColorSequence.new(Color3.fromRGB(255, 250, 240))
	cream.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 1)
	}
	cream.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0.8)
	}
	cream.LightEmission = 0.3
	cream.Parent = cake

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 40
	cash.Parent = cake

	-- Anti-stack pattern position
	local offset = patterns[dropPattern]
	dropPattern = (dropPattern % #patterns) + 1

	-- Position at dropper with offset
	cake.CFrame = dropPart.CFrame - Vector3.new(offset.X, 1.75, offset.Z)

	-- Drop with slight spread
	cake.AssemblyLinearVelocity = Vector3.new(offset.X * 2, -8, offset.Z * 2)

	-- Parent to workspace
	cake.Parent = PartStorage

	-- Spawn animation - start small, grow to normal
	mesh.Scale = Vector3.new(0.001, 0.001, 0.001)

	TweenService:Create(mesh,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Scale = Vector3.new(0.04, 0.04, 0.04)}
	):Play()

	-- Flash effect
	glow.Brightness = 1.5
	TweenService:Create(glow,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0.6}
	):Play()

	-- Cake spawn puff
	local puff = Instance.new("ParticleEmitter")
	puff.Texture = "rbxassetid://262979222"
	puff.Rate = 0
	puff.Speed = NumberRange.new(0)
	puff.Lifetime = NumberRange.new(0.3)
	puff.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 2)
	})
	puff.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1)
	})
	puff.Color = ColorSequence.new(Color3.fromRGB(255, 182, 193))
	puff.Parent = cake
	puff:Emit(1)
	Debris:AddItem(puff, 1)

	-- Cleanup after 3 minutes
	task.delay(180, function()
		if cake and cake.Parent then
			cake:Destroy()
		end
	end)
end