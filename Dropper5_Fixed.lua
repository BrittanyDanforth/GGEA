-- Dropper5 (Polished) - Fixed to use DropperCore
local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

task.wait(1)

-- Create template model for Ice Cream
local templateModel = Instance.new("Model")
templateModel.Name = "IceCreamTemplate"

local templatePart = Instance.new("Part")
templatePart.Name = "MainPart"
templatePart.Size = Vector3.new(2, 2, 2)
templatePart.Material = Enum.Material.SmoothPlastic
templatePart.TopSurface = Enum.SurfaceType.Smooth
templatePart.BottomSurface = Enum.SurfaceType.Smooth
templatePart.Color = Color3.new(1, 1, 1)
templatePart.Parent = templateModel

local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.FileMesh
mesh.MeshId = "rbxassetid://1486490132"
mesh.TextureId = "rbxassetid://1486490402"
-- Apply the thickened scale directly to the mesh
local BASE_SCALE = Vector3.new(1.177, 2.512, 1.164)
local THICKEN = Vector3.new(1.8, 1.0, 1.8)
local SCALE_OVERALL = 1.8
mesh.Scale = Vector3.new(
	BASE_SCALE.X * THICKEN.X * SCALE_OVERALL,
	BASE_SCALE.Y * THICKEN.Y * SCALE_OVERALL,
	BASE_SCALE.Z * THICKEN.Z * SCALE_OVERALL
)
mesh.Parent = templatePart

local light = Instance.new("PointLight")
light.Brightness = 0.4
light.Range = 6
light.Color = Color3.new(1, 1, 1)
light.Parent = templatePart

templateModel.PrimaryPart = templatePart
templateModel.Parent = RS

Core.RunModel({
	model         = script.Parent,
	partStorage   = workspace:WaitForChild("PartStorage"),
	templateModel = templateModel,

	namePrefix    = "IceCream_",
	dropGroup     = "Drops5",      -- Unique group for Dropper5
	playerGroup   = "Players",
	dropRate      = 1.5,
	cashValue     = 12,
	lifetime      = nil,

	scaleFactor   = 1,             -- Scale already applied to mesh
	extraLower    = 2,
	fadeTime      = 0.5,
	yawDegrees    = 180,
	cashOn        = "primary",

	density       = 0.3,
	friction      = 0.5,
	elasticity    = 0.1,

	collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
	collectorTags  = { "Collector", "SellZone" },
})