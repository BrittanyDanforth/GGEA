--[[
	Hello Kitty Droppers 8-10 - Lime Green Fabric Style
	Uses DropperCore for proper collision handling
--]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Create template model
local templateModel = Instance.new("Model")
templateModel.Name = "FabricDropTemplate"

local mainPart = Instance.new("Part")
mainPart.Name = "PrimaryPart"
mainPart.Size = Vector3.new(1, 1, 1)
mainPart.BrickColor = BrickColor.new("Lime green")
mainPart.Material = Enum.Material.Fabric
mainPart.TopSurface = Enum.SurfaceType.Smooth
mainPart.BottomSurface = Enum.SurfaceType.Smooth
mainPart.Transparency = 0
mainPart.Anchored = false
mainPart.CanCollide = true
mainPart.Parent = templateModel

-- Set primary part
templateModel.PrimaryPart = mainPart

-- Store template
local templateStorage = game.ReplicatedStorage:FindFirstChild("DropperTemplates")
if not templateStorage then
	templateStorage = Instance.new("Folder")
	templateStorage.Name = "DropperTemplates"
	templateStorage.Parent = game.ReplicatedStorage
end
templateModel.Parent = templateStorage

-- Run dropper
Core.RunModel({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	templateModel = templateModel,

	namePrefix = "FabricDrop_",
	dropGroup = "FabricDrops",
	playerGroup = "Players",

	dropRate = 0.5,
	cashValue = 100,
	lifetime = 2000,

	scaleFactor = 1.0,
	density = 0.2,
	friction = 0.4,
	elasticity = 0.1,
	
	extraLower = 1.4,
	fadeTime = 0.3,
	
	cashOn = "primary",
	
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags = {"Collector", "SellZone"},
})