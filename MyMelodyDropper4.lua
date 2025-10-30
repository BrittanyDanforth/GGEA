--[[
	MyMelody Dropper 4 - Basic Block Drop
	✅ Simple block dropper
	✅ No collisions (automatic)
	Cash: $30 | Rate: 1.0s
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "MyMelodyDrop4_",
	dropGroup = "MyMelodyDrops4",

	dropRate = 1.0,
	cashValue = 30,
	lifetime = 180,

	size = Vector3.new(1.5, 1.5, 1.5),
	color = Color3.fromRGB(255, 192, 203),
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
