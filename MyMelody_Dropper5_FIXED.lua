--[[
	✅ MyMelody Dropper 5 - FIXED VERSION
	Tier: Special Mesh Drop
	Cash: $12 | Rate: 1.5s | Size: 1x5x4 | Mesh: 160003363
--]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = script.Parent.Parent.Parent:WaitForChild("Essentials"):WaitForChild("PartStorage"),
	
	namePrefix = "MyMelodyMesh_",
	dropGroup = "MyMelodyDrops",
	
	dropRate = 1.5,
	cashValue = 12,
	lifetime = 20,
	
	size = Vector3.new(1, 5, 4),
	
	-- ✅ MESH DROP!
	mesh = {
		meshId = "http://www.roblox.com/asset?id=160003363",
		textureId = "http://www.roblox.com/asset/?id=192068356",
		scale = Vector3.new(1, 1, 1),
	},
	
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

print("✅ [MyMelody Dropper 5] Loaded - Mesh drop!")
