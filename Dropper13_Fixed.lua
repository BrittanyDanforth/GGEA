-- Dropper13 - Fixed to use DropperCore (same as Dropper11/12)
local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

task.wait(1)

-- Create template model (no mesh)
local templateModel = Instance.new("Model")
templateModel.Name = "Dropper13Template"

local templatePart = Instance.new("Part")
templatePart.Name = "MainPart"
templatePart.Size = Vector3.new(0.2, 0.2, 0.2)
templatePart.FormFactor = "Custom"
templatePart.TopSurface = "Smooth"
templatePart.BottomSurface = "Smooth"
templatePart.Parent = templateModel

templateModel.PrimaryPart = templatePart
templateModel.Parent = RS

Core.RunModel({
	model         = script.Parent,
	partStorage   = workspace:WaitForChild("PartStorage"),
	templateModel = templateModel,

	namePrefix    = "Drop13_",
	dropGroup     = "Drops13",     -- Unique group for Dropper13
	playerGroup   = "Players",
	dropRate      = 1.5,
	cashValue     = 100,
	lifetime      = 20,

	scaleFactor   = 1,
	extraLower    = 5,
	fadeTime      = 0.3,
	yawDegrees    = 0,
	cashOn        = "primary",

	density       = 0.7,
	friction      = 0.3,
	elasticity    = 0.05,

	collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
	collectorTags  = { "Collector", "SellZone" },
})