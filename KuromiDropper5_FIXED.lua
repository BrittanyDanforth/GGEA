--[[
	Kuromi Dropper 5 - Witch Hat Style
	✅ Uses witch hat mesh
	✅ Final visual size: 2.674, 1.996, 2.37
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Part size
local PART_SIZE = Vector3.new(2, 2, 2)

-- Desired final visual size
local DESIRED_SIZE = Vector3.new(2.674, 1.996, 2.37)

-- Calculate correct mesh scale (mesh scale = desired size / part size)
local MESH_SCALE = Vector3.new(
	DESIRED_SIZE.X / PART_SIZE.X,  -- 2.674 / 2 = 1.337
	DESIRED_SIZE.Y / PART_SIZE.Y,  -- 1.996 / 2 = 0.998
	DESIRED_SIZE.Z / PART_SIZE.Z   -- 2.37 / 2 = 1.185
)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "WitchHat_",
	dropGroup = "Dropper5Orbs",

	dropRate = 1.5,
	cashValue = 12,
	lifetime = 2000,

	size = PART_SIZE,
	color = Color3.new(1, 1, 1),
	material = Enum.Material.SmoothPlastic,

	mesh = {
		meshId = "rbxassetid://12396936150",
		textureId = "rbxassetid://12396936197",
		scale = MESH_SCALE,  -- Now correctly calculated!
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
			startScale = Vector3.new(0.2, 0.2, 0.2),
			endScale = MESH_SCALE,  -- Use correct mesh scale for animation
			duration = 0.4,
			style = Enum.EasingStyle.Back,
		},
	},

	fadeTime = 0.3,
	density = 0.1,
	friction = 0.3,
	elasticity = 0,
})
