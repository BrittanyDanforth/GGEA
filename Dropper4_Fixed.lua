-- Dropper4 (Strawberry Cake Style) - Fixed to use DropperCore
local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

task.wait(1)

-- Create template model for White Heart
local templateModel = Instance.new("Model")
templateModel.Name = "WhiteHeartTemplate"

local templatePart = Instance.new("Part")
templatePart.Name = "MainPart"
templatePart.Size = Vector3.new(2, 2, 2)
templatePart.Material = Enum.Material.SmoothPlastic
templatePart.BrickColor = BrickColor.new("Institutional white")
templatePart.TopSurface = Enum.SurfaceType.Smooth
templatePart.BottomSurface = Enum.SurfaceType.Smooth
templatePart.Reflectance = 0.2
templatePart.Parent = templateModel

local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.FileMesh
mesh.MeshId = "rbxassetid://601198887"
mesh.TextureId = ""
mesh.Scale = Vector3.new(1, 1, 1)
mesh.Parent = templatePart

-- Sweet glow
local glow = Instance.new("PointLight")
glow.Brightness = 0.6
glow.Range = 7
glow.Color = Color3.fromRGB(255, 204, 204)
glow.Parent = templatePart

-- Strawberry particles
local berries = Instance.new("ParticleEmitter")
berries.Texture = "rbxasset://textures/particles/sparkles_main.dds"
berries.Rate = 8
berries.Lifetime = NumberRange.new(1, 2)
berries.Speed = NumberRange.new(0.5, 1)
berries.SpreadAngle = Vector2.new(30, 30)
berries.Color = ColorSequence.new(Color3.fromRGB(255, 99, 71))
berries.Size = NumberSequence.new{
	NumberSequenceKeypoint.new(0, 0.3),
	NumberSequenceKeypoint.new(1, 0.1)
}
berries.LightEmission = 0.5
berries.Parent = templatePart

-- Cream particles
local cream = Instance.new("ParticleEmitter")
cream.Texture = "rbxasset://textures/particles/smoke_main.dds"
cream.Rate = 5
cream.Lifetime = NumberRange.new(1.5, 2.5)
cream.Speed = NumberRange.new(0.3)
cream.SpreadAngle = Vector2.new(45, 45)
cream.Color = ColorSequence.new(Color3.fromRGB(255, 250, 240))
cream.Transparency = NumberSequence.new{
	NumberSequenceKeypoint.new(0, 0.7),
	NumberSequenceKeypoint.new(1, 1)
}
cream.Size = NumberSequence.new{
	NumberSequenceKeypoint.new(0, 0.4),
	NumberSequenceKeypoint.new(1, 0.8)
}
cream.LightEmission = 0.3
cream.Parent = templatePart

templateModel.PrimaryPart = templatePart
templateModel.Parent = RS

Core.RunModel({
	model         = script.Parent,
	partStorage   = workspace:WaitForChild("PartStorage"),
	templateModel = templateModel,

	namePrefix    = "WhiteHeart_",
	dropGroup     = "Drops4",      -- Unique group for Dropper4
	playerGroup   = "Players",
	dropRate      = 0.9,
	cashValue     = 40,
	lifetime      = 180,

	scaleFactor   = 0.04,          -- The mesh needs to be scaled down
	extraLower    = 1.75,
	fadeTime      = 0.4,
	yawDegrees    = 0,
	cashOn        = "primary",

	density       = 0.4,
	friction      = 0.6,
	elasticity    = 0.1,

	collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
	collectorTags  = { "Collector", "SellZone" },
})