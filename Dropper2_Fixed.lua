-- Dropper2 (Cinnamoroll) - Fixed to use DropperCore
local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

task.wait(1)

-- Create template model for Cinnamoroll
local templateModel = Instance.new("Model")
templateModel.Name = "CinnamorollTemplate"

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
mesh.MeshId = "rbxassetid://114684643919279"
mesh.TextureId = "rbxassetid://136339015269351"
mesh.Scale = Vector3.new(2, 2, 2)
mesh.Parent = templatePart

-- Add visual effects to template
local pointLight = Instance.new("PointLight")
pointLight.Brightness = 0.6
pointLight.Range = 4
pointLight.Color = Color3.new(1, 1, 1)
pointLight.Parent = templatePart

local sparkle = Instance.new("ParticleEmitter")
sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparkle.Rate = 5
sparkle.Lifetime = NumberRange.new(0.5, 1.5)
sparkle.Speed = NumberRange.new(0.5, 2)
sparkle.SpreadAngle = Vector2.new(180, 180)
sparkle.LightEmission = 1
sparkle.LightInfluence = 0
sparkle.Size = NumberSequence.new{
	NumberSequenceKeypoint.new(0, 0.3),
	NumberSequenceKeypoint.new(1, 0)
}
sparkle.Color = ColorSequence.new(Color3.new(1, 1, 1))
sparkle.Parent = templatePart

local stars = Instance.new("ParticleEmitter")
stars.Texture = "rbxasset://textures/particles/star.dds"
stars.Rate = 2
stars.Lifetime = NumberRange.new(1, 2)
stars.Speed = NumberRange.new(0.5)
stars.SpreadAngle = Vector2.new(360, 360)
stars.LightEmission = 0.8
stars.Size = NumberSequence.new(0.4)
stars.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
stars.Parent = templatePart

templateModel.PrimaryPart = templatePart
templateModel.Parent = RS

Core.RunModel({
	model         = script.Parent,
	partStorage   = workspace:WaitForChild("PartStorage"),
	templateModel = templateModel,

	namePrefix    = "CinnamorollMesh_",
	dropGroup     = "Drops2",      -- Unique group for Dropper2
	playerGroup   = "Players",
	dropRate      = 1,
	cashValue     = 15,
	lifetime      = 180,

	scaleFactor   = 1,
	extraLower    = 1.75,
	fadeTime      = 0.6,
	yawDegrees    = 270,
	cashOn        = "primary",

	density       = 0.2,
	friction      = 0.3,
	elasticity    = 0.1,

	collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
	collectorTags  = { "Collector", "SellZone" },
})