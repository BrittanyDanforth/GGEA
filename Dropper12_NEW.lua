--[[
	Dropper 12 NEW - Diamond Blue Neon
	Uses DropperCore
--]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Create template model
local templateModel = Instance.new("Model")
templateModel.Name = "Dropper12Template"

local mainPart = Instance.new("Part")
mainPart.Name = "PrimaryPart"
mainPart.Size = Vector3.new(0.4, 0.4, 0.4)
mainPart.BrickColor = BrickColor.new("Cyan")
mainPart.Material = Enum.Material.Neon
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

	namePrefix = "Diamond12_",
	dropGroup = "HelloKittyDrops12",
	playerGroup = "Players",

	dropRate = 0.35,
	cashValue = 500,
	lifetime = 30,

	scaleFactor = 1.0,
	density = 0.3,
	friction = 0.4,
	elasticity = 0.1,
	
	extraLower = 3.25,
	fadeTime = 0.3,
	
	cashOn = "primary",
	
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags = {"Collector", "SellZone"},
})
