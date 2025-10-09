--[[
	Dropper 4 NEW - White Heart Style
	Uses DropperCore
--]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Create template model
local templateModel = Instance.new("Model")
templateModel.Name = "WhiteHeartTemplate"

local mainPart = Instance.new("Part")
mainPart.Name = "PrimaryPart"
mainPart.Size = Vector3.new(2, 2, 2)
mainPart.BrickColor = BrickColor.new("Institutional white")
mainPart.Material = Enum.Material.SmoothPlastic
mainPart.TopSurface = Enum.SurfaceType.Smooth
mainPart.BottomSurface = Enum.SurfaceType.Smooth
mainPart.Reflectance = 0.2
mainPart.Transparency = 0
mainPart.Anchored = false
mainPart.CanCollide = true
mainPart.Parent = templateModel

-- Add heart mesh
local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.FileMesh
mesh.MeshId = "rbxassetid://601198887"
mesh.TextureId = ""
mesh.Scale = Vector3.new(0.04, 0.04, 0.04)
mesh.Parent = mainPart

-- Add sweet glow
local light = Instance.new("PointLight")
light.Brightness = 0.6
light.Range = 7
light.Color = Color3.fromRGB(255, 204, 204)
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

	namePrefix = "WhiteHeart_",
	dropGroup = "HelloKittyDrops4",
	playerGroup = "Players",

	dropRate = 0.9,
	cashValue = 40,
	lifetime = 180,

	scaleFactor = 1.0,
	density = 0.4,
	friction = 0.6,
	elasticity = 0.1,
	
	extraLower = 1.75,
	fadeTime = 0.4,
	
	cashOn = "primary",
	
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags = {"Collector", "SellZone"},
})
