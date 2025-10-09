--[[
	Dropper 3 NEW - Premium Hello Kitty
	Uses DropperCore
--]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Create template model
local templateModel = Instance.new("Model")
templateModel.Name = "HelloKitty3Template"

local mainPart = Instance.new("Part")
mainPart.Name = "PrimaryPart"
mainPart.Size = Vector3.new(1.817, 1.323, 0.281)
mainPart.Color = Color3.fromRGB(151, 0, 0)
mainPart.Material = Enum.Material.SmoothPlastic
mainPart.TopSurface = Enum.SurfaceType.Smooth
mainPart.BottomSurface = Enum.SurfaceType.Smooth
mainPart.Transparency = 0
mainPart.Anchored = false
mainPart.CanCollide = true
mainPart.Parent = templateModel

-- Add Hello Kitty mesh
local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.FileMesh
mesh.MeshId = "rbxassetid://3071180788"
mesh.TextureId = ""
mesh.Scale = Vector3.new(4, 4, 4)
mesh.Parent = mainPart

-- Add pink glow
local light = Instance.new("PointLight")
light.Brightness = 1
light.Range = 10
light.Color = Color3.fromRGB(255, 100, 150)
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

-- Run dropper
Core.RunModel({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	templateModel = templateModel,

	namePrefix = "PremiumHK_",
	dropGroup = "HelloKittyDrops3",
	playerGroup = "Players",

	dropRate = 0.6,
	cashValue = 50,
	lifetime = 180,

	scaleFactor = 1.0,
	density = 0.2,
	friction = 0.4,
	elasticity = 0.3,
	
	extraLower = 1.75,
	fadeTime = 0.4,
	yawDegrees = 70,
	
	cashOn = "primary",
	
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags = {"Collector", "SellZone"},
})
