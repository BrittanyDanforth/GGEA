--[[
	Kuromi Dropper 5 - Witch Hat Style
	✅ Uses witch hat mesh
	✅ Made WAY smaller!
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Much smaller size!
local PART_SIZE = Vector3.new(1, 1, 1)

-- Small mesh scale
local MESH_SCALE = Vector3.new(0.8, 0.8, 0.8)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "WitchHat_",
	dropGroup = "Dropper5Orbs",

	dropRate = 1.5,
	cashValue = 12,
	lifetime = 2000,

	size = PART_SIZE,  -- EXACT size you want!
	color = Color3.new(1, 1, 1),
	material = Enum.Material.SmoothPlastic,

	mesh = {
		meshId = "rbxassetid://12396936150",
		textureId = "rbxassetid://12396936197",
		scale = MESH_SCALE,  -- Simple 1:1 scale
	},

	light = {
		brightness = 1,
		range = 6,
		color = Color3.new(1, 1, 1),
		spawnFlash = true,
		spawnBrightness = 2,
		flashDuration = 0.6,
	},

	spawn = {
		velocity = Vector3.new(0, -8, 0),
	},
	spawnYOffset = -2.5,

	animation = {
		mesh = {
			startScale = Vector3.new(0.05, 0.05, 0.05),
			endScale = MESH_SCALE,  -- Animates to 0.8 scale
			duration = 0.4,
			style = Enum.EasingStyle.Back,
		},
	},

	fadeTime = 0.3,
	density = 0.1,
	friction = 0.3,
	elasticity = 0,
})
