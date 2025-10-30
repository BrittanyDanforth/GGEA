--[[
	MyMelody Dropper 4 — LOWER SPAWN + UPRIGHT (FIXED)
	✅ Spawns clearly LOWER so it sits on the belt
	✅ Uses same collision setup as Dropper1/2/3
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

	namePrefix = "MyMelodyDrop4_",
	dropGroup = "MyMelodyDrops1",  -- USE SAME GROUP AS DROPPER1/2/3
	playerGroup = "Players",

	-- Timing
	dropRate = 1.2,
	cashValue = 20,
	lifetime = 180,

	-- Part properties
	size = Vector3.new(1.88, 1.64, 1.88),  -- 25% OF ORIGINAL SIZE
	color = Color3.fromRGB(255, 192, 203), -- Pink for MyMelody
	material = Enum.Material.SmoothPlastic,
	transparency = 0,

	-- NO LIGHT/AURA
	light = false,

	-- Mesh configuration
	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://11816850109",      -- MyMelody mesh
		textureId = "rbxassetid://11816850135",   -- MyMelody texture
		scale = Vector3.new(0.25, 0.25, 0.25),  -- 25% SCALE
		offset = Vector3.new(0, 0, 0),
	},

	-- Spawn settings (orientation: 0, 0, 0)
	spawn = {
		rotation = CFrame.Angles(0, 0, 0),
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
			startScale = Vector3.new(0.125, 0.125, 0.125),
			endScale = Vector3.new(0.25, 0.25, 0.25),
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
