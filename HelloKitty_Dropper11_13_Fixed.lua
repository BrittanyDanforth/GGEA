--[[
	Hello Kitty Droppers 11-13 - Small Part Style
	Uses DropperCore for proper collision handling
--]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Create template model
local templateModel = Instance.new("Model")
templateModel.Name = "SmallDropTemplate"

local mainPart = Instance.new("Part")
mainPart.Name = "PrimaryPart"
mainPart.Size = Vector3.new(0.2, 0.2, 0.2)
mainPart.Material = Enum.Material.SmoothPlastic
mainPart.TopSurface = Enum.SurfaceType.Smooth
mainPart.BottomSurface = Enum.SurfaceType.Smooth
mainPart.Transparency = 0
mainPart.Anchored = false
mainPart.CanCollide = true
mainPart.Parent = templateModel

-- Note: meshDrop is set to false in original, so no mesh added

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

	namePrefix = "SmallDrop_",
	dropGroup = "SmallDrops",
	playerGroup = "Players",

	dropRate = 1.5,
	cashValue = 100,
	lifetime = 20,

	scaleFactor = 1.0,
	density = 0.1,
	friction = 0.3,
	elasticity = 0.05,
	
	extraLower = 5.0,
	fadeTime = 0.3,
	
	cashOn = "primary",
	
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags = {"Collector", "SellZone"},
})