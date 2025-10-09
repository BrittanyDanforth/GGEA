-- Dropper3 (Hello Kitty Premium) - Fixed to use DropperCore
local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

task.wait(1)

-- Create template model for Hello Kitty Premium
local templateModel = Instance.new("Model")
templateModel.Name = "HelloKittyPremiumTemplate"

local templatePart = Instance.new("Part")
templatePart.Name = "MainPart"
templatePart.Size = Vector3.new(1.817, 1.323, 0.281)
templatePart.Material = Enum.Material.SmoothPlastic
templatePart.Color = Color3.fromRGB(151, 0, 0)
templatePart.TopSurface = Enum.SurfaceType.Smooth
templatePart.BottomSurface = Enum.SurfaceType.Smooth
templatePart.Parent = templateModel

local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.FileMesh
mesh.MeshId = "rbxassetid://3071180788"
mesh.TextureId = ""
mesh.Scale = Vector3.new(4, 4, 4)
mesh.Parent = templatePart

-- Red/pink glow
local glow = Instance.new("PointLight")
glow.Brightness = 1
glow.Range = 10
glow.Color = Color3.fromRGB(255, 100, 150)
glow.Parent = templatePart

-- Pink star particles
local starParticles = Instance.new("ParticleEmitter")
starParticles.Texture = "rbxasset://textures/particles/star.dds"
starParticles.Rate = 10
starParticles.Lifetime = NumberRange.new(2, 3)
starParticles.Speed = NumberRange.new(1)
starParticles.SpreadAngle = Vector2.new(180, 180)
starParticles.Size = NumberSequence.new{
	NumberSequenceKeypoint.new(0, 0.3),
	NumberSequenceKeypoint.new(1, 0.1)
}
starParticles.Color = ColorSequence.new(Color3.fromRGB(255, 150, 200))
starParticles.LightEmission = 1
starParticles.Parent = templatePart

templateModel.PrimaryPart = templatePart
templateModel.Parent = RS

Core.RunModel({
	model         = script.Parent,
	partStorage   = workspace:WaitForChild("PartStorage"),
	templateModel = templateModel,

	namePrefix    = "PremiumHelloKitty_",
	dropGroup     = "Drops3",      -- Unique group for Dropper3
	playerGroup   = "Players",
	dropRate      = 0.6,
	cashValue     = 50,
	lifetime      = 180,

	scaleFactor   = 1,
	extraLower    = 1.75,
	fadeTime      = 0.4,
	yawDegrees    = 0,
	cashOn        = "primary",

	density       = 0.2,
	friction      = 0.4,
	elasticity    = 0.3,

	collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
	collectorTags  = { "Collector", "SellZone" },
})