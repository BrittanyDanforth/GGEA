--[[
	MyMelody Dropper 6 - Basic Block Drop
	✅ Simple block dropper
	✅ No collisions (automatic)
	Cash: $50 | Rate: 0.8s
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "MyMelodyDrop6_",
	dropGroup = "MyMelodyDrops6",

	dropRate = 0.8,
	cashValue = 50,
	lifetime = 180,

	size = Vector3.new(1.7, 1.7, 1.7),
	color = Color3.fromRGB(255, 170, 200),
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
