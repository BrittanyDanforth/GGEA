--[[
	Cinnamoroll Dropper 2 - Fixed Version
	Optimized with anti-stack and proper collision handling
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

local orbCount = 0

while true do
	task.wait(1)
	
	-- Debounce check
	if not AntiStack.CanDrop(0.9) then
		continue
	end
	
	orbCount = orbCount + 1

	-- Create the drop
	local orb = Instance.new("Part")
	orb.Name = "CinnamorollMesh_" .. orbCount
	orb.Size = Vector3.new(2, 2, 2)
	orb.Material = Enum.Material.SmoothPlastic
	orb.TopSurface = Enum.SurfaceType.Smooth
	orb.BottomSurface = Enum.SurfaceType.Smooth
	orb.Color = Color3.new(1, 1, 1)
	orb.Transparency = 0.7 -- Start faded

	-- Add mesh
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://114684643919279"
	mesh.TextureId = "rbxassetid://136339015269351"
	mesh.Scale = Vector3.new(0.5, 0.5, 0.5) -- Start small
	mesh.Parent = orb

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 15
	cash.Parent = orb

	-- Reduced glow
	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 0.6
	pointLight.Range = 4
	pointLight.Color = Color3.new(1, 1, 1)
	pointLight.Parent = orb

	-- Simple sparkles (less particles = less lag)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 3 -- Reduced
	sparkle.Lifetime = NumberRange.new(0.5, 1)
	sparkle.Speed = NumberRange.new(0.5, 1.5)
	sparkle.SpreadAngle = Vector2.new(90, 90) -- Less spread
	sparkle.LightEmission = 0.8
	sparkle.LightInfluence = 0
	sparkle.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0)
	}
	sparkle.Color = ColorSequence.new(Color3.new(1, 1, 1))
	sparkle.Parent = orb

	-- Apply anti-stack physics and positioning
	AntiStack.ApplyAntiStackPhysics(orb, dropPart)
	
	-- Face forward
	orb.CFrame = orb.CFrame * CFrame.Angles(math.rad(180), math.rad(270), 0)

	-- Parent to storage
	orb.Parent = PartStorage

	-- Smooth animations
	TweenService:Create(orb,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0}
	):Play()

	TweenService:Create(mesh,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Scale = Vector3.new(2, 2, 2)}
	):Play()

	-- Light flash
	pointLight.Brightness = 1.5
	TweenService:Create(pointLight,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0.6}
	):Play()

	-- Simple spawn puff (less particles)
	local spawnPuff = Instance.new("ParticleEmitter")
	spawnPuff.Texture = "rbxassetid://262979222"
	spawnPuff.Rate = 0
	spawnPuff.Speed = NumberRange.new(0)
	spawnPuff.Lifetime = NumberRange.new(0.3)
	spawnPuff.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 2)
	})
	spawnPuff.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	spawnPuff.Color = ColorSequence.new(Color3.new(1, 1, 1))
	spawnPuff.Parent = orb
	spawnPuff:Emit(1)
	Debris:AddItem(spawnPuff, 1)

	-- Schedule cleanup
	AntiStack.ScheduleCleanup(orb, 180) -- 3 minutes
end