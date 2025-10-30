--[[
	MyMelody Dropper 11 - Basic Block Drop
	✅ Simple block dropper
	✅ No collisions (automatic)
	Cash: $100 | Rate: 0.5s
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "MyMelodyDrop11_",
	dropGroup = "MyMelodyDrops11",

	dropRate = 0.5,
	cashValue = 100,
	lifetime = 180,

	size = Vector3.new(2.2, 2.2, 2.2),
	color = Color3.fromRGB(255, 192, 203),
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
