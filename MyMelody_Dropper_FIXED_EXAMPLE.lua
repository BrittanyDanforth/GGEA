--[[
	✅ MyMelody Dropper - FIXED VERSION
	
	🛑 PROBLEM: Old script probably had:
	   while true do
	       local part = Instance.new("Part", workspace.PartStorage)  ← WRONG!
	   end
	
	✅ SOLUTION: Use DropperCore with TYCOON'S PartStorage!
--]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	
	-- ✅ CRITICAL FIX: Use tycoon's local PartStorage!
	-- OLD (BAD):  workspace.PartStorage
	-- NEW (GOOD): script.Parent.Parent.Parent.Essentials.PartStorage
	partStorage = script.Parent.Parent.Parent:WaitForChild("Essentials"):WaitForChild("PartStorage"),
	
	namePrefix = "MyMelodyDrop_",
	dropGroup = "MyMelodyDrops",
	
	dropRate = 1.0,  -- 1 drop per second
	cashValue = 10,  -- $10 per drop
	lifetime = 20,   -- Expires after 20 seconds
	
	-- ✅ Standard drop size (adjust to match your old size)
	size = Vector3.new(1.25, 1.7, 1.7),
	
	-- ✅ Use tycoon's DropColor and MaterialValue if available
	brickColor = script.Parent.Parent.Parent:FindFirstChild("DropColor") 
	             and script.Parent.Parent.Parent.DropColor.Value 
	             or BrickColor.new("Pink"),
	material = script.Parent.Parent.Parent:FindFirstChild("MaterialValue") 
	           and script.Parent.Parent.Parent.MaterialValue.Value 
	           or Enum.Material.SmoothPlastic,
	
	light = {
		brightness = 1,
		range = 6,
		color = Color3.fromRGB(255, 192, 203), -- Pink for MyMelody
	},
	
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

print("✅ [MyMelody Dropper] Using DropperCore with tycoon's PartStorage - drops will clean up properly!")
