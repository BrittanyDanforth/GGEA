--[[
	✅ MyMelody Dropper 12 - FIXED VERSION
	Tier: Tiny Drops (Same as 10-11)
	Cash: $100 | Rate: 1.5s | Size: 0.2x0.2x0.2
--]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = script.Parent.Parent.Parent:WaitForChild("Essentials"):WaitForChild("PartStorage"),
	
	namePrefix = "MyMelodyTiny_",
	dropGroup = "MyMelodyDrops",
	
	dropRate = 1.5,
	cashValue = 100,
	lifetime = 20,
	
	size = Vector3.new(0.2, 0.2, 0.2),
	
	spawn = {
		velocity = Vector3.new(0, -8, 0),
	},
	spawnYOffset = -5,
	
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

print("✅ [MyMelody Dropper 12] Loaded")
