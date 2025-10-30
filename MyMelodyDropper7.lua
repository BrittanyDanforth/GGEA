--[[
	MyMelody Dropper 7 - Basic Block Drop
	✅ Simple block dropper
	✅ No collisions (automatic)
	Cash: $60 | Rate: 0.7s
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "MyMelodyDrop7_",
	dropGroup = "MyMelodyDrops7",

	dropRate = 0.7,
	cashValue = 60,
	lifetime = 180,

	size = Vector3.new(1.8, 1.8, 1.8),
	color = Color3.fromRGB(255, 200, 215),
	material = Enum.Material.SmoothPlastic,
	transparency = 0,

	spawn = {
		velocity = Vector3.new(0, -8, 0),
	},
	spawnYOffset = -1.75,

	animation = {
		pop = true,
		popStartSize = Vector3.new(0.05, 0.05, 0.05),
		popDuration = 0.2,
	},

	fadeTime = 0.3,
	density = 0.05,
	friction = 0.2,
	elasticity = 0,
})
