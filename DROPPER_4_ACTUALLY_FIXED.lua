--[[
	Cinnamoroll Dropper 4 - Strawberry Cake Style
	Uses Strawberry Cake Slice mesh with sweet effects
	NO CLEANUP - Items stay until collected
	✅ FIXED: Collision groups now work like Kuromi 1-3!
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

local ORB_GROUP = "CinnamorollOrbs4"
local PLAYER_GROUP = "Players"

-- FIX: Register ALL collision groups and set them to not collide
pcall(function()
	PhysicsService:RegisterCollisionGroup(ORB_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:RegisterCollisionGroup("KuromiOrbs1")
	PhysicsService:RegisterCollisionGroup("KuromiOrbs2")
	PhysicsService:RegisterCollisionGroup("KuromiOrbs3")
	PhysicsService:RegisterCollisionGroup("CinnamorollOrbs5")
	PhysicsService:RegisterCollisionGroup("KuromiOrbs6")
	PhysicsService:RegisterCollisionGroup("KuromiOrbs8")
	PhysicsService:RegisterCollisionGroup("KuromiOrbs9")
	PhysicsService:RegisterCollisionGroup("KuromiOrbs10")
	PhysicsService:RegisterCollisionGroup("KuromiOrbs11")
	PhysicsService:RegisterCollisionGroup("KuromiOrbs12")
	PhysicsService:RegisterCollisionGroup("KuromiOrbs13")
	
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, PLAYER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, ORB_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs1", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs2", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs3", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "CinnamorollOrbs5", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs6", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs8", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs9", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs10", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs11", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs12", false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, "KuromiOrbs13", false)
end)

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

local cakeCount = 0

while true do
	task.wait(0.9)
	cakeCount = cakeCount + 1

	local cake = Instance.new("Part")
	cake.Name = "WhiteHeart_" .. cakeCount
	cake.Size = Vector3.new(2, 2, 2)
	cake.Material = Enum.Material.SmoothPlastic
	cake.BrickColor = BrickColor.new("Institutional white")
	cake.TopSurface = Enum.SurfaceType.Smooth
	cake.BottomSurface = Enum.SurfaceType.Smooth

	-- YOUR WHITE HEART MESH
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://601198887"
	mesh.TextureId = ""
	mesh.Scale = Vector3.new(1, 1, 1)
	mesh.Parent = cake

	cake.Reflectance = 0.2
	cake.CanCollide = true
	cake.CanTouch = true
	cake.CanQuery = true

	pcall(function()
		cake.CollisionGroup = ORB_GROUP
	end)

	cake.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.6, 0.1, 1, 1)

	local glow = Instance.new("PointLight")
	glow.Brightness = 0.6
	glow.Range = 7
	glow.Color = Color3.fromRGB(255, 204, 204)
	glow.Parent = cake

	-- YOUR STRAWBERRY PARTICLES
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

	-- YOUR CREAM PARTICLES
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

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 40
	cash.Parent = cake

	cake.CFrame = dropPart.CFrame - Vector3.new(0, 1.75, 0)
	cake.AssemblyLinearVelocity = Vector3.new(0, -8, 0)
	cake.Parent = PartStorage

	mesh.Scale = Vector3.new(0.001, 0.001, 0.001)

	TweenService:Create(mesh,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Scale = Vector3.new(0.04, 0.04, 0.04)}
	):Play()

	glow.Brightness = 1.5
	TweenService:Create(glow,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0.6}
	):Play()

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
end
