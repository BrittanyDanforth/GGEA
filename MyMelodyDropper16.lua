--[[
	MyMelody Dropper 16 - Basic Block Drop (FINAL)
	✅ Simple block dropper
	✅ No collisions (automatic)
	Cash: $250 | Rate: 0.2s
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "MyMelodyDrop16_",
	dropGroup = "MyMelodyDrops16",

	dropRate = 0.2,
	cashValue = 250,
	lifetime = 180,

	size = Vector3.new(2.8, 2.8, 2.8),
	color = Color3.fromRGB(255, 182, 193),
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
