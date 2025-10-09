--[[
  Dropper 5 – Polished (matches Dropper1) - FIXED COLLISION
  - Mesh: rbxassetid://1486490132
  - Texture: rbxassetid://1486490402
  - Scale: thickened and enlarged (not skinny)
  - No collision with players or other drops
  - Fade-in, light flash, spawn ring
  - Cash value: 12
  - Drop rate: 1.5s
]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")

local dropPart = script.Parent:WaitForChild("Drop")

-- Collision groups
local ORB_GROUP = "Dropper5Orbs"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(ORB_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	-- FIXED: No collision with players
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, PLAYER_GROUP, false)
	-- FIXED: No collision between drops
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, ORB_GROUP, false)
end)

local function setupPlayerCollision(character)
	task.wait(0.1)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				part.CollisionGroup = PLAYER_GROUP
			end)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(setupPlayerCollision)
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		setupPlayerCollision(player.Character)
	end
end

-- Mesh/texture and sizing
local MESH_ID = "rbxassetid://1486490132"
local TEXTURE_ID = "rbxassetid://1486490402"

-- Your provided base scale
local BASE_SCALE = Vector3.new(1.177, 2.512, 1.164)

-- MODIFIED: Made shorter (Y axis) and thicker (X/Z axes)
local SCALE_OVERALL = 1.8
local THICKEN = Vector3.new(1.8, 1.0, 1.8)
local FINAL_SCALE = Vector3.new(
	BASE_SCALE.X * THICKEN.X * SCALE_OVERALL,
	BASE_SCALE.Y * THICKEN.Y * SCALE_OVERALL,
	BASE_SCALE.Z * THICKEN.Z * SCALE_OVERALL
)

local DROP_RATE = 1.5
local CASH_VALUE = 12

local count = 0
while true do
	task.wait(DROP_RATE)
	count += 1

	local orb = Instance.new("Part")
	orb.Name = "IceCream_" .. count
	orb.Size = Vector3.new(2, 2, 2)
	orb.Material = Enum.Material.SmoothPlastic
	orb.TopSurface = Enum.SurfaceType.Smooth
	orb.BottomSurface = Enum.SurfaceType.Smooth
	orb.Color = Color3.new(1, 1, 1)
	-- FIXED: CanCollide = false
	orb.CanCollide = false
	orb.CanTouch = true
	orb.CanQuery = true

	pcall(function()
		orb.CollisionGroup = ORB_GROUP
	end)

	orb.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.5, 0.1, 1, 1)

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = CASH_VALUE
	cash.Parent = orb

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = MESH_ID
	mesh.TextureId = TEXTURE_ID
	mesh.Scale = FINAL_SCALE * 0.5 -- start smaller for spawn tween
	mesh.Parent = orb

	local light = Instance.new("PointLight")
	light.Brightness = 0.4
	light.Range = 6
	light.Color = Color3.new(1, 1, 1)
	light.Parent = orb

	-- Position and orientation (same style as Dropper1)
	local offsetX = (math.random(-2, 2) * 0.1)
	local offsetZ = (math.random(-2, 2) * 0.1)
	orb.CFrame = (dropPart.CFrame - Vector3.new(offsetX, 2, offsetZ)) * CFrame.Angles(math.rad(180), math.rad(180), 0)
	orb.AssemblyLinearVelocity = Vector3.new(0, -12, 0)

	-- Fade-in
	orb.Transparency = 0.7
	orb:SetAttribute("SpawnTime", tick())
	orb.Parent = PartStorage

	TweenService:Create(orb, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0}):Play()
	TweenService:Create(mesh, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = FINAL_SCALE}):Play()

	-- Flash
	light.Brightness = 1.2
	TweenService:Create(light, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Brightness = 0.4}):Play()

	-- Spawn ring
	local ring = Instance.new("ParticleEmitter")
	ring.Texture = "rbxassetid://262979222"
	ring.Rate = 0
	ring.Speed = NumberRange.new(0)
	ring.Lifetime = NumberRange.new(0.3)
	ring.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 2)
	})
	ring.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 1)
	})
	ring.Color = ColorSequence.new(Color3.new(1, 1, 1))
	ring.Parent = orb
	ring:Emit(1)
	Debris:AddItem(ring, 1)
end
