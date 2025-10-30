--[[
	Beanie Dropper 2 — LOWER SPAWN + UPRIGHT (FIXED)
	✅ Spawns clearly LOWER so it sits on the belt
	✅ Uses same collision setup as MyMelody Dropper 1
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

	namePrefix = "BeanieDrop_",
	dropGroup = "BeanieDrops2",
	playerGroup = "Players",

	-- Timing
	dropRate = 1.2,
	cashValue = 10,
	lifetime = 180,

	-- Part properties
	size = Vector3.new(1.5, 1.5, 1.5),
	color = Color3.fromRGB(255, 204, 153), -- Beanie color
	material = Enum.Material.SmoothPlastic,
	transparency = 0,

	-- Mesh configuration
	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://95965901192105",      -- Beanie mesh
		textureId = "rbxassetid://79765468782729",   -- Beanie color map
		scale = Vector3.new(1.1, 1.1, 1.1),
		offset = Vector3.new(0, 0.05, 0),
	},

	-- Spawn settings
	spawn = {
		rotation = CFrame.Angles(0, 0, 0), -- Upright
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
			startScale = Vector3.new(0.5, 0.5, 0.5),
			endScale = Vector3.new(1.1, 1.1, 1.1),
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
