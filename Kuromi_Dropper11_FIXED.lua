--[[
	✅ Kuromi Dropper 11 - FIXED VERSION
	
	🛑 PROBLEM: Old script had TWO systems running:
	   1. Core.Run() (NEW - Good!)
	   2. while true loop (OLD - BAD! Spawned to workspace.PartStorage!)
	
	✅ SOLUTION: Remove old loop, only use DropperCore!
--]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	
	-- ✅ CRITICAL: Use tycoon's local PartStorage, NOT workspace.PartStorage!
	partStorage = script.Parent.Parent.Parent:WaitForChild("Essentials"):WaitForChild("PartStorage"),
	
	namePrefix = "KuromiDrop_",
	dropGroup = "KuromiOrbs11",
	
	dropRate = 1.0,  -- 1 drop per second
	cashValue = 10,  -- $10 per drop (matches your old value)
	lifetime = 20,
	
	-- ✅ Match your old size: Vector3.new(1.25, 1.7, 1.7)
	size = Vector3.new(1.25, 1.7, 1.7),
	
	-- ✅ Use tycoon's DropColor and MaterialValue
	brickColor = script.Parent.Parent.Parent.DropColor.Value,
	material = script.Parent.Parent.Parent.MaterialValue.Value,
	
	mesh = {
		meshId = "rbxasset://fonts/PaintballGun.mesh",
		textureId = "rbxasset://textures/PaintballGunTex128.png",
		scale = Vector3.new(1, 1, 1),
	},
	
	light = {
		brightness = 1,
		range = 6,
		color = Color3.fromRGB(255, 100, 50),
	},
	
	spawn = {
		velocity = Vector3.new(0, -8, 0),
	},
	spawnYOffset = -1.75,  -- Matches your old offset
	
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

-- ✅ REMOVED: Old while loop that spawned to workspace.PartStorage!
-- That was causing drops to survive because they were outside the tycoon!

print("✅ [Kuromi Dropper 11] Using DropperCore only - drops will clean up properly!")
