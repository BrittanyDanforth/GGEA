--[[
	Dropper 2 NEW - Cinnamoroll Style
	Uses DropperCore
--]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Create template model
local templateModel = Instance.new("Model")
templateModel.Name = "Dropper2Template"

local mainPart = Instance.new("Part")
mainPart.Name = "PrimaryPart"
mainPart.Size = Vector3.new(2, 2, 2)
mainPart.Color = Color3.new(1, 1, 1)
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
mesh.MeshId = "rbxassetid://114684643919279"
mesh.TextureId = "rbxassetid://136339015269351"
mesh.Scale = Vector3.new(2, 2, 2)
mesh.Parent = mainPart

-- Add light
local light = Instance.new("PointLight")
light.Brightness = 0.6
light.Range = 4
light.Color = Color3.new(1, 1, 1)
light.Parent = mainPart

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

-- Run dropper with DropperCore
Core.RunModel({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	templateModel = templateModel,

	namePrefix = "Cinnamoroll2_",
	dropGroup = "HelloKittyDrops2",
	playerGroup = "Players",

	dropRate = 1.0,
	cashValue = 15,
	lifetime = 180,

	scaleFactor = 1.0,
	density = 0.2,
	friction = 0.3,
	elasticity = 0.1,
	
	extraLower = 1.75,
	fadeTime = 0.6,
	
	cashOn = "primary",
	
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags = {"Collector", "SellZone"},
})
