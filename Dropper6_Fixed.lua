-- Dropper6 - Fixed to use DropperCore
local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

task.wait(1)

-- Create template model
local templateModel = Instance.new("Model")
templateModel.Name = "Dropper6Template"

local templatePart = Instance.new("Part")
templatePart.Name = "MainPart"
templatePart.Size = Vector3.new(1, 5, 4)
templatePart.FormFactor = "Custom"
templatePart.TopSurface = "Smooth"
templatePart.BottomSurface = "Smooth"
templatePart.Parent = templateModel

local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.FileMesh
mesh.MeshId = "http://www.roblox.com/asset?id=160003363"
mesh.TextureId = "http://www.roblox.com/asset/?id=192068356"
mesh.Parent = templatePart

templateModel.PrimaryPart = templatePart
templateModel.Parent = RS

Core.RunModel({
	model         = script.Parent,
	partStorage   = workspace:WaitForChild("PartStorage"),
	templateModel = templateModel,

	namePrefix    = "Drop6_",
	dropGroup     = "Drops6",      -- Unique group for Dropper6
	playerGroup   = "Players",
	dropRate      = 1.5,
	cashValue     = 12,
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