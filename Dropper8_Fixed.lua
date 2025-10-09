-- Dropper8 - Fixed to use DropperCore
local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

task.wait(1)

-- Create template model (simple green cube)
local templateModel = Instance.new("Model")
templateModel.Name = "GreenCubeTemplate"

local templatePart = Instance.new("Part")
templatePart.Name = "MainPart"
templatePart.Size = Vector3.new(1, 1, 1)
templatePart.BrickColor = BrickColor.new("Lime green")
templatePart.Material = "Fabric"
templatePart.TopSurface = "Smooth"
templatePart.BottomSurface = "Smooth"
templatePart.Parent = templateModel

templateModel.PrimaryPart = templatePart
templateModel.Parent = RS

Core.RunModel({
	model         = script.Parent,
	partStorage   = workspace:WaitForChild("PartStorage"),
	templateModel = templateModel,

	namePrefix    = "GreenCube_",
	dropGroup     = "Drops8",      -- Unique group for Dropper8
	playerGroup   = "Players",
	dropRate      = 0.5,
	cashValue     = 100,
	lifetime      = 2000,

	scaleFactor   = 1,
	extraLower    = 1.4,
	fadeTime      = 0.2,
	yawDegrees    = 0,
	cashOn        = "primary",

	density       = 0.7,
	friction      = 0.3,
	elasticity    = 0.05,

	collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
	collectorTags  = { "Collector", "SellZone" },
})