--[[
	Dropper 10 NEW - Golden Glass
	Uses DropperCore
--]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Create template model
local templateModel = Instance.new("Model")
templateModel.Name = "Dropper10Template"

local mainPart = Instance.new("Part")
mainPart.Name = "PrimaryPart"
mainPart.Size = Vector3.new(1.5, 1.5, 1.5)
mainPart.BrickColor = BrickColor.new("New Yeller")
mainPart.Material = Enum.Material.Glass
mainPart.TopSurface = Enum.SurfaceType.Smooth
mainPart.BottomSurface = Enum.SurfaceType.Smooth
mainPart.Reflectance = 0.4
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

	namePrefix = "Golden10_",
	dropGroup = "HelloKittyDrops10",
	playerGroup = "Players",

	dropRate = 0.45,
	cashValue = 250,
	lifetime = 2000,

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
