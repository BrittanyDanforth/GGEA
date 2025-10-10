--[[
	Kuromi Dropper 5 - Ice Cream Style
	✅ Uses ice cream mesh with custom scaling
	✅ Exact size: 2.674, 1.996, 2.37
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Exact scale you want
local FINAL_SCALE = Vector3.new(2.674, 1.996, 2.37)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "IceCream_",
	dropGroup = "Dropper5Orbs",

	dropRate = 1.5,
	cashValue = 12,
	lifetime = 2000,

	size = Vector3.new(2, 2, 2),
	color = Color3.new(1, 1, 1),
	material = Enum.Material.SmoothPlastic,

	mesh = {
		meshId = "rbxassetid://12396936150",
		textureId = "rbxassetid://12396936197",
		scale = FINAL_SCALE,
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
			endScale = FINAL_SCALE,
			duration = 0.4,
			style = Enum.EasingStyle.Back,
		},
	},

	fadeTime = 0.3,
	density = 0.1,
	friction = 0.3,
	elasticity = 0,
})
