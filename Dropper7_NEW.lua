--[[
	Dropper 7 NEW - Transition Dropper
	Uses DropperCore
--]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Create template model
local templateModel = Instance.new("Model")
templateModel.Name = "Dropper7Template"

local mainPart = Instance.new("Part")
mainPart.Name = "PrimaryPart"
mainPart.Size = Vector3.new(1.2, 1.2, 1.2)
mainPart.BrickColor = BrickColor.new("Hot pink")
mainPart.Material = Enum.Material.SmoothPlastic
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

	namePrefix = "Transition7_",
	dropGroup = "HelloKittyDrops7",
	playerGroup = "Players",

	dropRate = 1.2,
	cashValue = 80,
	lifetime = 150,

	scaleFactor = 1.0,
	density = 0.3,
	friction = 0.4,
	elasticity = 0.1,
	
	extraLower = 1.5,
	fadeTime = 0.4,
	
	cashOn = "primary",
	
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags = {"Collector", "SellZone"},
})
