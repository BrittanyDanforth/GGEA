--[[
	Dropper 5 - Ice Cream Style Fixed
	Optimized with anti-stack and proper scaling
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local AntiStack = require(workspace:WaitForChild("DropperAntiStack"))

-- Setup collision groups
AntiStack.SetupCollisionGroups()

-- Setup player collisions
game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(AntiStack.SetupPlayerCollisions)
end)

for _, player in ipairs(game.Players:GetPlayers()) do
	if player.Character then
		AntiStack.SetupPlayerCollisions(player.Character)
	end
end

-- Wait for dependencies
task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

-- Ice cream settings
local MESH_ID = "rbxassetid://1486490132"
local TEXTURE_ID = "rbxassetid://1486490402"
local BASE_SCALE = Vector3.new(1.177, 2.512, 1.164)
local SCALE_OVERALL = 1.8
local THICKEN = Vector3.new(1.8, 1.0, 1.8)
local FINAL_SCALE = Vector3.new(
	BASE_SCALE.X * THICKEN.X * SCALE_OVERALL,
	BASE_SCALE.Y * THICKEN.Y * SCALE_OVERALL,
	BASE_SCALE.Z * THICKEN.Z * SCALE_OVERALL
)

local count = 0

while true do
	task.wait(1.5)
	
	-- Debounce check
	if not AntiStack.CanDrop(1.4) then
		continue
	end
	
	count = count + 1

	-- Create ice cream
	local orb = Instance.new("Part")
	orb.Name = "IceCream_" .. count
	orb.Size = Vector3.new(2, 2, 2)
	orb.Material = Enum.Material.SmoothPlastic
	orb.TopSurface = Enum.SurfaceType.Smooth
	orb.BottomSurface = Enum.SurfaceType.Smooth
	orb.Color = Color3.new(1, 1, 1)
	orb.Transparency = 0.7 -- Start faded

	-- Add mesh
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = MESH_ID
	mesh.TextureId = TEXTURE_ID
	mesh.Scale = FINAL_SCALE * 0.5 -- Start smaller
	mesh.Parent = orb

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 12
	cash.Parent = orb

	-- Simple light
	local light = Instance.new("PointLight")
	light.Brightness = 0.4
	light.Range = 5 -- Reduced
	light.Color = Color3.new(1, 1, 1)
	light.Parent = orb

	-- Apply anti-stack physics
	AntiStack.ApplyAntiStackPhysics(orb, dropPart)
	
	-- Rotate for ice cream orientation
	orb.CFrame = orb.CFrame * CFrame.Angles(math.rad(180), math.rad(180), 0)

	-- Parent to storage
	orb.Parent = PartStorage

	-- Smooth animations
	TweenService:Create(orb,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0}
	):Play()

	TweenService:Create(mesh,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Scale = FINAL_SCALE}
	):Play()

	-- Light flash
	light.Brightness = 1.2
	TweenService:Create(light,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0.4}
	):Play()

	-- Simple spawn effect
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
		NumberSequenceKeypoint.new(1, 1)
	})
	ring.Color = ColorSequence.new(Color3.new(1, 1, 1))
	ring.Parent = orb
	ring:Emit(1)
	Debris:AddItem(ring, 1)

	-- Schedule cleanup
	AntiStack.ScheduleCleanup(orb, 180) -- 3 minutes
end