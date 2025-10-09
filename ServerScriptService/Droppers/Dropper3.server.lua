local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

local template = RS:FindFirstChild("HelloKittyPL") or RS:WaitForChild("HelloKittyPL")

task.wait(1)

Core.RunModel({
	model         = script.Parent,
	partStorage   = workspace:WaitForChild("PartStorage"),
	templateModel = template,

	namePrefix    = "HK_Premium_",
	dropGroup     = "Drops",
	playerGroup   = "Players",
	dropRate      = 0.6,
	cashValue     = 50,
	lifetime      = nil,

	scaleFactor   = 1.0,
	extraLower    = 0.45,
	fadeTime      = 0.35,
	yawDegrees    = 70,
	cashOn        = "primary",

	density       = 0.7,
	friction      = 0.3,
	elasticity    = 0.05,

	collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
	collectorTags  = { "Collector", "SellZone" },
})
