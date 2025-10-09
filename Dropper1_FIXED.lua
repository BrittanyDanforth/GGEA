-- Workspace.Dropper1.Script (Server Script) - FIXED
local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

task.wait(1)

Core.RunModel({
	model         = script.Parent,
	partStorage   = workspace:WaitForChild("PartStorage"),
	templateModel = RS:WaitForChild("HelloKittyPL"),  -- or swap any model

	namePrefix    = "Drop_",
	dropGroup     = "Drops",
	playerGroup   = "Players",
	dropRate      = 1.2,
	cashValue     = 10,
	lifetime      = nil,           -- keep until collected

	scaleFactor   = 0.9,
	extraLower    = 0.45,
	fadeTime      = 0.35,
	yawDegrees    = -90,
	prewarm       = 8,
	cashOn        = "primary",     -- fastest

	density       = 0.7,
	friction      = 0.3,
	elasticity    = 0.05,

	collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
	collectorTags  = { "Collector", "SellZone" },
})
