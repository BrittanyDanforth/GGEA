--[[
	✅ MyMelody Dropper 7 - FIXED VERSION
	Tier: Premium Fast Drop
	Cash: $100 | Rate: 0.5s | Size: 1x1x1 | Color: Lime green | Material: Fabric
--]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = script.Parent.Parent.Parent:WaitForChild("Essentials"):WaitForChild("PartStorage"),
	
	namePrefix = "MyMelodyPremium_",
	dropGroup = "MyMelodyDrops",
	
	dropRate = 0.5,  -- ✅ FAST! 2 drops per second
	cashValue = 100,  -- ✅ HIGH VALUE!
	lifetime = 2000,  -- ✅ Long lifetime (was 2000 in original)
	
	size = Vector3.new(1, 1, 1),
	
	-- ✅ OVERRIDE: Lime green + Fabric (not using tycoon's DropColor)
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

print("✅ [MyMelody Dropper 7] Loaded - PREMIUM FAST DROP!")
