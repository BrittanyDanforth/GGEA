--[[
	MyMelody Dropper 3 — LOWER SPAWN + UPRIGHT (FIXED)
	✅ Spawns clearly LOWER so it sits on the belt
	✅ Uses same collision setup as Dropper1/Dropper2
	✅ Inline mesh - no ReplicatedStorage needed
	✅ No collisions with players or other droppers
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(0.5)

-- Prevent double-starts
if script.Parent:GetAttribute("DropperRunning") then return end
script.Parent:SetAttribute("DropperRunning", true)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "MyMelodyDrop3_",
	dropGroup = "MyMelodyDrops1",  -- USE SAME GROUP AS DROPPER1/2
	playerGroup = "Players",

	-- Timing
	dropRate = 1.2,
	cashValue = 15,
	lifetime = 180,

	-- Part properties
	size = Vector3.new(0.459, 1.598, 0.546),  -- 70% SMALLER (30% of original)
	color = Color3.fromRGB(255, 192, 203), -- Pink for MyMelody
	material = Enum.Material.SmoothPlastic,
	transparency = 0,

	-- NO LIGHT/AURA
	light = false,

	-- Mesh configuration
	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://2682037588",      -- MyMelody mesh
		textureId = "rbxassetid://2682037631",   -- MyMelody texture
		scale = Vector3.new(0.3, 0.3, 0.3),  -- 70% SMALLER
		offset = Vector3.new(0, 0, 0),
	},

	-- Spawn settings (orientation: 0, -23.462, 90)
	spawn = {
		rotation = CFrame.Angles(0, math.rad(-23.462), math.rad(90)),
		velocity = Vector3.new(0, -10, 0),
	},
	spawnYOffset = -1.75,

	-- Animation
	fadeTime = 0.5,
	animation = {
		pop = true,
		popStartSize = Vector3.new(0.1, 0.1, 0.1),
		popDuration = 0.5,
		popStyle = Enum.EasingStyle.Elastic,
		mesh = {
			startScale = Vector3.new(0.15, 0.15, 0.15),
			endScale = Vector3.new(0.3, 0.3, 0.3),
			duration = 0.6,
			style = Enum.EasingStyle.Elastic,
		},
	},

	-- Physics (same as MyMelody Dropper1)
	density = 0.8,
	friction = 0.18,
	elasticity = 0.03,

	-- Collection
	cashOn = "primary",
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags  = {"Collector", "SellZone"},
})
