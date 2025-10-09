--!strict
-- Dropper 1 NEW - Using DropperCore (FIXED COLLISION)
local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

task.wait(1)

Core.RunModel({
	model         = script.Parent,
	partStorage   = workspace:WaitForChild("PartStorage"),
	templateModel = RS:WaitForChild("HelloKittyPL"),

	namePrefix    = "HK1Drop_",
	dropGroup     = "HelloKittyDrops1",
	playerGroup   = "Players",
	dropRate      = 1.0,
	cashValue     = 10,
	lifetime      = 120,

	scaleFactor   = 0.9,
	extraLower    = 1.0,
	fadeTime      = 0.35,
	yawDegrees    = -90,
	cashOn        = "primary",

	density       = 0.3,
	friction      = 0.5,
	elasticity    = 0.2,

	collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
	collectorTags  = { "Collector", "SellZone" },
})
