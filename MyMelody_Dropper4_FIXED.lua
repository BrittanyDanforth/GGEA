--[[
	✅ MyMelody Dropper 4 - FIXED VERSION
	Tier: Basic Drop (Same as Dropper 2-3)
	Cash: $30 | Rate: 1.0s | Size: 1.25x1.7x1.7
	
	🔧 FIXES:
	✅ Uses tycoon's PartStorage (not workspace.PartStorage!)
	✅ Uses DropperCore system (modern, multi-tycoon safe)
	✅ Auto-tags drops with TycoonId attribute
	✅ Proper cleanup on tycoon reset
	✅ No infinite yield warnings
	
	📍 PLACE IN: Workspace > YourTycoon > Tycoons > MyMelody > PurchasedObjects > Dropper4 > DropperScript
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = script.Parent.Parent.Parent:WaitForChild("Essentials"):WaitForChild("PartStorage"),

	namePrefix = "MyMelodyDrop_",
	dropGroup = "MyMelodyDrops",

	dropRate = 1.0,
	cashValue = 30,
	lifetime = 20,

	size = Vector3.new(1.25, 1.7, 1.7),
	brickColor = script.Parent.Parent.Parent.DropColor.Value,
	material = script.Parent.Parent.Parent.MaterialValue.Value,

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

print("✅ [MyMelody Dropper 4] Loaded - spawns to tycoon's PartStorage!")
