--[[
	Cinnamoroll Dropper 4 - White Heart Style Fixed
	Optimized with anti-stack
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

local cakeCount = 0

while true do
	task.wait(0.9)
	
	-- Debounce check
	if not AntiStack.CanDrop(0.8) then
		continue
	end
	
	cakeCount = cakeCount + 1

	-- Create white heart
	local cake = Instance.new("Part")
	cake.Name = "WhiteHeart_" .. cakeCount
	cake.Size = Vector3.new(2, 2, 2)
	cake.Material = Enum.Material.SmoothPlastic
	cake.BrickColor = BrickColor.new("Institutional white")
	cake.TopSurface = Enum.SurfaceType.Smooth
	cake.BottomSurface = Enum.SurfaceType.Smooth
	cake.Reflectance = 0.2

	-- Add heart mesh
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://601198887"
	mesh.TextureId = ""
	mesh.Scale = Vector3.new(0.001, 0.001, 0.001) -- Start tiny
	mesh.Parent = cake

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 40
	cash.Parent = cake

	-- Sweet glow
	local glow = Instance.new("PointLight")
	glow.Brightness = 0.6
	glow.Range = 6 -- Reduced
	glow.Color = Color3.fromRGB(255, 204, 204)
	glow.Parent = cake

	-- Minimal particles (performance)
	local berries = Instance.new("ParticleEmitter")
	berries.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	berries.Rate = 4 -- Reduced
	berries.Lifetime = NumberRange.new(1, 1.5)
	berries.Speed = NumberRange.new(0.5)
	berries.SpreadAngle = Vector2.new(20, 20)
	berries.Color = ColorSequence.new(Color3.fromRGB(255, 99, 71))
	berries.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.05)
	}
	berries.LightEmission = 0.4
	berries.Parent = cake

	-- Apply anti-stack physics
	AntiStack.ApplyAntiStackPhysics(cake, dropPart)

	-- Parent to storage
	cake.Parent = PartStorage

	-- Spawn animation
	TweenService:Create(mesh,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Scale = Vector3.new(0.04, 0.04, 0.04)}
	):Play()

	-- Light flash
	glow.Brightness = 1.2
	TweenService:Create(glow,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0.6}
	):Play()

	-- Simple puff effect
	local puff = Instance.new("ParticleEmitter")
	puff.Texture = "rbxassetid://262979222"
	puff.Rate = 0
	puff.Speed = NumberRange.new(0)
	puff.Lifetime = NumberRange.new(0.3)
	puff.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1.5)
	})
	puff.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	puff.Color = ColorSequence.new(Color3.fromRGB(255, 182, 193))
	puff.Parent = cake
	puff:Emit(1)
	Debris:AddItem(puff, 1)

	-- Schedule cleanup
	AntiStack.ScheduleCleanup(cake, 180) -- 3 minutes
end