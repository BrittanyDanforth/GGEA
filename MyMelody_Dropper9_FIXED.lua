--[[
	✅ MyMelody Dropper 9 - FIXED VERSION
	Tier: Premium Fast Drop (Same as Dropper 7-8)
	Cash: $100 | Rate: 0.5s | Size: 1x1x1 | Color: Lime green
--]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = script.Parent.Parent.Parent:WaitForChild("Essentials"):WaitForChild("PartStorage"),
	
	namePrefix = "MyMelodyPremium_",
	dropGroup = "MyMelodyDrops",
	
	dropRate = 0.5,
	cashValue = 100,
	lifetime = 2000,
	
	size = Vector3.new(1, 1, 1),
	brickColor = BrickColor.new("Lime green"),
	material = Enum.Material.Fabric,
	
	spawn = {
		velocity = Vector3.new(0, -8, 0),
	},
	spawnYOffset = -1.4,
	
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

print("✅ [MyMelody Dropper 9] Loaded")
