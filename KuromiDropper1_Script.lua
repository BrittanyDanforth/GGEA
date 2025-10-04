--[[
	Kuromi Dropper 1 - Basic Kawaii Style
	Fixed: Collides with conveyor/ground but not players
	Features: Smooth animations, collision groups, fade effects
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

-- Wait for PartStorage
task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")

-- Find the Drop part
local dropPart = script.Parent:WaitForChild("Drop")

-- Try to find conveyor
local conveyor = nil
local function findConveyor()
	-- Check parent
	conveyor = script.Parent:FindFirstChild("Conveyor") or script.Parent:FindFirstChild("Conv")
	if conveyor then return end

	-- Check siblings
	for _, sibling in pairs(script.Parent:GetChildren()) do
		if sibling.Name:lower():find("conv") then
			conveyor = sibling
			return
		end
	end

	-- Check grandparent
	if script.Parent.Parent then
		conveyor = script.Parent.Parent:FindFirstChild("Conveyor") or script.Parent.Parent:FindFirstChild("Conv")
	end
end
findConveyor()

-- Create collision groups if they don't exist
local ORB_GROUP = "KuromiOrbs"
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

local orbCount = 0

while true do
	task.wait(1.2) -- Drop rate

	orbCount = orbCount + 1

	-- Create cute Kuromi part!
	local orb = Instance.new("Part")
	orb.Name = "KuromiDrop_" .. orbCount
	orb.Size = Vector3.new(3.445, 2.552, 2.148) -- Kuromi mesh size
	orb.Material = Enum.Material.SmoothPlastic  -- Clean material
	orb.TopSurface = Enum.SurfaceType.Smooth
	orb.BottomSurface = Enum.SurfaceType.Smooth
	orb.Color = Color3.new(1, 1, 1) -- White base (texture will show)
	orb.Transparency = 0 -- FULLY VISIBLE

	-- Add Kuromi mesh!
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://15014438476" -- Kuromi mesh
	mesh.TextureId = "rbxassetid://15014443369" -- Kuromi texture!
	mesh.Scale = Vector3.new(2, 2, 2) -- BIGGER scale for visibility
	mesh.Parent = orb

	-- Add a soft purple glow (Kuromi themed!)
	local light = Instance.new("PointLight")
	light.Brightness = 0.5
	light.Range = 10
	light.Color = Color3.fromRGB(150, 100, 200) -- Purple light for Kuromi
	light.Parent = orb

	-- COLLISION: On for world, off for players
	orb.CanCollide = true -- Collides with conveyor!
	orb.CanTouch = true
	orb.CanQuery = true

	-- Set collision group
	pcall(function()
		orb.CollisionGroup = ORB_GROUP
	end)

	-- Light weight for smooth movement
	orb.CustomPhysicalProperties = PhysicalProperties.new(
		0.3,  -- Very light density
		0.5,  -- Medium friction
		0.1,  -- Low bounce
		1, 1
	)

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 10
	cash.Parent = orb

	-- REDUCED GLOW - less bright, smaller range (purple/pink for Kuromi)
	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 0.4  -- Reduced from 1
	pointLight.Range = 3         -- Reduced from 5
	pointLight.Color = Color3.fromRGB(200, 150, 230)  -- Soft purple/pink
	pointLight.Parent = orb

	-- Position with small offset (WITH ROTATION)
	local offsetX = math.random(-2, 2) * 0.1
	local offsetZ = math.random(-2, 2) * 0.1
	-- Rotate 180 degrees vertically to face forward (turned around)
	orb.CFrame = (dropPart.CFrame - Vector3.new(offsetX, 2, offsetZ)) * CFrame.Angles(math.rad(180), math.rad(0), 0)

	-- Gentle drop
	orb.AssemblyLinearVelocity = Vector3.new(0, -12, 0)

	-- Start semi-transparent for fade-in
	orb.Transparency = 0.7  -- More visible from the start

	-- Set spawn time for cleanup
	orb:SetAttribute("SpawnTime", tick())

	-- Parent to storage
	orb.Parent = PartStorage

	-- Smooth fade-in and scale effect
	mesh.Scale = Vector3.new(0.5, 0.5, 0.5)

	-- Fade in
	local fadeTween = TweenService:Create(orb,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0}
	)
	fadeTween:Play()

	-- Scale up
	local spawnTween = TweenService:Create(mesh,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Scale = Vector3.new(2, 2, 2)}
	)
	spawnTween:Play()

	-- POLISH: Add spawn flash
	pointLight.Brightness = 1.5 -- Temporarily bright
	TweenService:Create(pointLight,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0.4} -- Fade back to normal
	):Play()

	-- POLISH: Add spawn ring effect (purple/pink for Kuromi!)
	local spawnRing = Instance.new("ParticleEmitter")
	spawnRing.Texture = "rbxassetid://262979222" -- Ring texture
	spawnRing.Rate = 0
	spawnRing.Speed = NumberRange.new(0)
	spawnRing.Lifetime = NumberRange.new(0.3)
	spawnRing.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 2) -- Expands outwards
	})
	spawnRing.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 1) -- Fades out
	})
	spawnRing.Color = ColorSequence.new(Color3.fromRGB(200, 150, 230)) -- Purple/pink ring
	spawnRing.Parent = orb
	spawnRing:Emit(1) -- Emit one ring
	Debris:AddItem(spawnRing, 1) -- Clean it up

	-- NO CLEANUP - Orbs stay until collected!
end
