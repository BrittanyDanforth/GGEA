--[[
	MyMelody Dropper 5 — StrawberryMilkShake UPRIGHT + GLIDE
	✅ Uses fixed upright StrawberryMilkShake model in ReplicatedStorage
	✅ keepUpright so it won't roll
	✅ Smooth slide, no jitter
	✅ Pays 20 cash
	✅ Rotated 90° to stand upright |
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(0.5)

-- Prevent double-starts
if script.Parent:GetAttribute("DropperRunning") then
	return
end
script.Parent:SetAttribute("DropperRunning", true)

Core.RunModel({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	templateModel = game.ReplicatedStorage:WaitForChild("StrawberryMilkShake"),

	namePrefix = "MyMelodyDrop5_",
	dropGroup = "MyMelodyDrops1",
	playerGroup = "Players",

	-- Timing / money
	dropRate = 1.2,
	cashValue = 20,
	lifetime = 180,

	-- Spawn pose / placement
	scaleFactor = 0.9,
	extraLower  = -0.50,  -- sits down on belt
	pitchDegrees = 90,    -- TILT UP 90° TO STAND UPRIGHT |
	yawDegrees  = 0,
	rollDegrees = 0,

	-- Visual fade
	fadeTime = 0.5,
	prewarm  = 0,

	-- Physics / conveyor glide
	density = 0.8,
	friction = 0.12, -- smooth slide, less stick
	elasticity = 0.03,

	-- Stability
	keepUpright = true,

	-- Collection
	cashOn = "primary",
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags  = {"Collector", "SellZone"},
})
