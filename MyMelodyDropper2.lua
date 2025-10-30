--[[
	MyMelody Dropper 2 — BEANIE (RunModel - NO COLLISIONS!)
	✅ Uses MyMelody2 beanie templateModel from ReplicatedStorage
	✅ Spawns lower, sits on belt
	✅ NO collisions with players or other droppers
	✅ Same system as Dropper 1
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Prevent double-starts
if script.Parent:GetAttribute("DropperRunning") then return end
script.Parent:SetAttribute("DropperRunning", true)

Core.RunModel({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	templateModel = game.ReplicatedStorage:WaitForChild("MyMelody2"),  -- Beanie template

	namePrefix = "MyMelodyDrop2_",
	dropGroup = "MyMelodyDrops2",
	playerGroup = "Players",  -- ✅ This prevents player collision!

	-- Timing
	dropRate = 1.0,
	cashValue = 30,
	lifetime = 180,

	-- Pose / spawn height
	scaleFactor = 0.7,  -- Smaller for beanie
	extraLower = -0.40,
	yawDegrees = 0,

	-- Animation
	fadeTime = 0.45,
	prewarm = 0,

	-- Physics
	density = 0.25,
	friction = 0.35,
	elasticity = 0.02,

	-- Stability
	keepUpright = true,

	-- Collection
	cashOn = "primary",
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags = {"Collector", "SellZone"},
})
