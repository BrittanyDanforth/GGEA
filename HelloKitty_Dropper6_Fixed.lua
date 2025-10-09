--[[
	Hello Kitty Dropper 6 - Custom Mesh Style
	Uses DropperCore
--]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Create template model
local templateModel = Instance.new("Model")
templateModel.Name = "Dropper6Template"

local mainPart = Instance.new("Part")
mainPart.Name = "PrimaryPart"
mainPart.Size = Vector3.new(1, 5, 4)
mainPart.Material = Enum.Material.SmoothPlastic
mainPart.TopSurface = Enum.SurfaceType.Smooth
mainPart.BottomSurface = Enum.SurfaceType.Smooth
mainPart.Transparency = 0
mainPart.Anchored = false
mainPart.CanCollide = true
mainPart.Parent = templateModel

-- Add mesh
local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.FileMesh
mesh.MeshId = "http://www.roblox.com/asset?id=160003363"
mesh.TextureId = "http://www.roblox.com/asset/?id=192068356"
mesh.Scale = Vector3.new(1, 1, 1)
mesh.Parent = mainPart

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

	namePrefix = "Drop6_",
	dropGroup = "HelloKittyDrops6",
	playerGroup = "Players",

	dropRate = 1.5,
	cashValue = 12,
	lifetime = 20,

	scaleFactor = 1.0,
	density = 0.3,
	friction = 0.4,
	elasticity = 0.1,
	
	extraLower = 5.0,
	fadeTime = 0.4,
	
	cashOn = "primary",
	
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags = {"Collector", "SellZone"},
})