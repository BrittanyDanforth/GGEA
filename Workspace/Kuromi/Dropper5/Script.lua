--[[
	Kuromi Dropper 5 - Ice Cream Style
	✅ Uses ice cream mesh with custom scaling
	✅ Thickened and enlarged
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Scale calculations from original
local BASE_SCALE = Vector3.new(1.177, 2.512, 1.164)
local SCALE_OVERALL = 1.8
local THICKEN = Vector3.new(1.8, 1.0, 1.8)
local FINAL_SCALE = Vector3.new(
	BASE_SCALE.X * THICKEN.X * SCALE_OVERALL,
	BASE_SCALE.Y * THICKEN.Y * SCALE_OVERALL,
	BASE_SCALE.Z * THICKEN.Z * SCALE_OVERALL
)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	
	namePrefix = "IceCream_",
	dropGroup = "Dropper5Orbs",
	
	dropRate = 1.5,
	cashValue = 12,
	lifetime = 30,
	
	size = Vector3.new(2, 2, 2),
	color = Color3.new(1, 1, 1),
	material = Enum.Material.SmoothPlastic,
	
	mesh = {
		meshId = "rbxassetid://1486490132",
		textureId = "rbxassetid://1486490402",
		scale = FINAL_SCALE,
	},
	
	light = {
		brightness = 1,
		range = 6,
		color = Color3.new(1, 1, 1),
	},
	
	spawn = {
		velocity = Vector3.new(0, -8, 0),
	},
	spawnYOffset = -2.5,
	
	animation = {
		mesh = {
			startScale = Vector3.new(0.1, 0.1, 0.1),
			endScale = FINAL_SCALE,
			duration = 0.3,
			style = Enum.EasingStyle.Back,
		},
	},
	
	fadeTime = 0.3,
	density = 0.1,
	friction = 0.3,
	elasticity = 0,
})
