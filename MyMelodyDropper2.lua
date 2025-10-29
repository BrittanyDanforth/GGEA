--[[
	MyMelody Dropper 2 — v5.1 HARDENED NO-COLLIDE (Beanie Mesh)
	✅ Same beanie mesh/size/feel as you wanted
	✅ No collisions with Players or MyMelodyDrops1 (symmetrically)
	✅ Forces each spawned part into MyMelodyDrops2 (safety)
	✅ Flat, steady land; proper fade; subtle particles
]]

local Core            = require(game.ReplicatedStorage.Modules.DropperCore)
local PhysicsService  = game:GetService("PhysicsService")
local Players         = game:GetService("Players")

task.wait(0.25)

-- ===== Collision matrix safety (mirrors v5.1; redundancy OK) =====
pcall(function()
	PhysicsService:RegisterCollisionGroup("Players")
	PhysicsService:RegisterCollisionGroup("MyMelodyDrops1")
	PhysicsService:RegisterCollisionGroup("MyMelodyDrops2")

	-- Symmetric disables
	PhysicsService:CollisionGroupSetCollidable("MyMelodyDrops2","Players",false)
	PhysicsService:CollisionGroupSetCollidable("Players","MyMelodyDrops2",false)

	PhysicsService:CollisionGroupSetCollidable("MyMelodyDrops2","MyMelodyDrops1",false)
	PhysicsService:CollisionGroupSetCollidable("MyMelodyDrops1","MyMelodyDrops2",false)

	PhysicsService:CollisionGroupSetCollidable("MyMelodyDrops2","MyMelodyDrops2",false)
end)

-- Keep all character parts in Players group (belt stays Default)
local function tagChar(char: Model)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			pcall(function() d.CollisionGroup = "Players" end)
		end
	end
	char.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			pcall(function() d.CollisionGroup = "Players" end)
		end
	end)
end

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(tagChar)
	if plr.Character then tagChar(plr.Character) end
end)
for _, plr in ipairs(Players:GetPlayers()) do
	if plr.Character then tagChar(plr.Character) end
end

-- Force-fix group on spawned parts by prefix (extra safety)
local storage = workspace:FindFirstChild("PartStorage")
local NAME_PREFIX = "MyMelodyDrop2_"
if storage then
	storage.ChildAdded:Connect(function(inst)
		if inst:IsA("BasePart") and string.sub(inst.Name, 1, #NAME_PREFIX) == NAME_PREFIX then
			pcall(function() inst.CollisionGroup = "MyMelodyDrops2" end)
		end
	end)
end

-- ===== Dropper 2 config (beanie mesh unchanged) =====
task.wait(0.25)

Core.Run({
	model       = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix  = NAME_PREFIX,
	dropGroup   = "MyMelodyDrops2",
	playerGroup = "Players",

	-- Timing / value
	dropRate  = 1.0,
	cashValue = 30,
	lifetime  = 180,

	-- Part + mesh
	size         = Vector3.new(1.1, 1.1, 1.1),
	color        = Color3.fromRGB(255,170,200),
	material     = Enum.Material.SmoothPlastic,
	transparency = 0,

	mesh = {
		meshType  = Enum.MeshType.FileMesh,
		meshId    = "rbxassetid://95965901192105",   -- beanie mesh
		textureId = "rbxassetid://79765468782729",   -- beanie texture
		scale     = Vector3.new(1.1, 1.1, 1.1),
		offset    = Vector3.new(0, 0.05, 0),
	},

	-- Light
	light = {
		brightness      = 0.6,
		range           = 4,
		color           = Color3.fromRGB(255,200,215),
		spawnFlash      = true,
		spawnBrightness = 1.5,
		flashDuration   = 0.6,
	},

	-- Upright spawn; no spin; sits on belt
	spawn = {
		rotation        = CFrame.Angles(0, 0, 0),
		velocity        = Vector3.new(0, -9, 0),
		angularVelocity = Vector3.new(0, 0, 0),
		randomOffset    = Vector3.new(0.15, 0, 0.15),
	},
	spawnYOffset = -1.4,

	-- Anim feel
	animation = {
		mesh = {
			startScale = Vector3.new(0.5, 0.5, 0.5),
			endScale   = Vector3.new(1.1, 1.1, 1.1),
			duration   = 0.4,
			style      = Enum.EasingStyle.Back,
		},
	},
	fadeTime = 0.45,

	-- Subtle particles
	particles = {
		{
			Texture         = "rbxasset://textures/particles/sparkles_main.dds",
			Rate            = 3,
			Lifetime        = NumberRange.new(0.8, 1.5),
			Speed           = NumberRange.new(0.5, 1.5),
			SpreadAngle     = Vector2.new(90, 90),
			LightEmission   = 1,
			LightInfluence  = 0,
			Size            = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Color           = ColorSequence.new(Color3.fromRGB(255,220,230)),
		},
		{
			Texture       = "rbxasset://textures/particles/star.dds",
			Rate          = 1,
			Lifetime      = NumberRange.new(1, 2),
			Speed         = NumberRange.new(0.5),
			SpreadAngle   = Vector2.new(180, 180),
			LightEmission = 0.6,
			Size          = NumberSequence.new(0.35),
			Color         = ColorSequence.new(Color3.fromRGB(255,182,193)),
		},
	},

	spawnParticles = {
		{
			Texture       = "rbxassetid://262979222",
			Rate          = 0,
			Speed         = NumberRange.new(0),
			Lifetime      = NumberRange.new(0.4),
			Size          = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 2.3),
			}),
			Transparency  = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color         = ColorSequence.new(Color3.fromRGB(255,200,215)),
			emit          = 2,
			autoDestroy   = true,
			lifetime      = 1,
		},
	},

	-- Physics tuned for soft landing
	density    = 0.25,
	friction   = 0.35,
	elasticity = 0.02,

	collectorNames = {"Collector","CollectorZone","Receiver","Sell","SellPad"},
	collectorTags  = {"Collector","SellZone"},
})
