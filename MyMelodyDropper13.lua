--[[
	MyMelody Dropper 13 - Basic Block Drop
	✅ Simple block dropper
	✅ No collisions (automatic)
	Cash: $150 | Rate: 0.4s
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "MyMelodyDrop13_",
	dropGroup = "MyMelodyDrops13",

	dropRate = 0.4,
	cashValue = 150,
	lifetime = 180,

	size = Vector3.new(2.4, 2.4, 2.4),
	color = Color3.fromRGB(255, 170, 200),
	material = Enum.Material.Neon,
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
