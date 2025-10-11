-- Workspace.Dropper1.Script (Server Script)
-- This version works with the updated DropperCore that supports RunModel()

local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

task.wait(1)

-- ✅ Core.RunModel() now works! It clones entire models as drops
Core.RunModel({
	model         = script.Parent,
	partStorage   = workspace:WaitForChild("PartStorage"),
	templateModel = RS:WaitForChild("HelloKittyPL"),  -- Your Hello Kitty model

	namePrefix    = "Drop_",
	dropGroup     = "Drops",
	playerGroup   = "Players",
	dropRate      = 1.2,
	cashValue     = 10,
	lifetime      = nil,           -- keep until collected (defaults to 120 if nil)

	scaleFactor   = 0.9,           -- Scales the entire model
	extraLower    = 0.45,          -- Additional lowering of spawn position
	fadeTime      = 0.35,
	yawDegrees    = -90,           -- Rotation on spawn
	prewarm       = 8,             -- Prewarm spawns
	cashOn        = "primary",     -- "primary" or "all" parts

	density       = 0.7,
	friction      = 0.3,
	elasticity    = 0.05,

	collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
	collectorTags  = { "Collector", "SellZone" },
})

--[[
	HOW IT WORKS:
	
	1. The dropper clones the "HelloKittyPL" model from ReplicatedStorage
	2. Each clone is scaled by scaleFactor (0.9 = 90% size)
	3. The model spawns at the Drop part position with extraLower offset
	4. All parts in the model have collision disabled with players and other drops
	5. The model has a pop animation when spawning
	6. Cash value is added based on cashOn setting:
	   - "primary" = only the primary part has cash value
	   - "all" = all parts in the model have cash value
	7. The entire model fades in/out with smooth transitions
	8. When any part touches a collector, the entire model is collected
	
	REQUIREMENTS:
	- Your dropper model needs a "Drop" part (the spawn point)
	- The templateModel ("HelloKittyPL") should be in ReplicatedStorage
	- The templateModel should have a PrimaryPart set, or at least one BasePart
	- PartStorage folder should exist in workspace
]]