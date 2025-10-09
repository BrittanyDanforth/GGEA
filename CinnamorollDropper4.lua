--[[
	Cinnamoroll Dropper 4 - White Heart/Strawberry Cake Style
	✅ Uses white heart mesh
	✅ Strawberry + cream particles
	✅ FIXED: Converted to RunModel for consistency
	✅ FIXED: Added playerGroup to prevent player collisions
	✅ Unique dropGroup to prevent collisions with other droppers
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Create a template model
local template = Instance.new("Model")
template.Name = "CinnamorollDrop_Template"

local p = Instance.new("Part")
p.Name = "PrimaryPart"
p.Size = Vector3.new(2, 2, 2)
p.BrickColor = BrickColor.new("Institutional white")
p.Material = Enum.Material.SmoothPlastic
p.Reflectance = 0.2
p.Anchored = false
p.CanCollide = true
p.Parent = template

local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.FileMesh
mesh.MeshId = "rbxassetid://601198887"
mesh.TextureId = ""
mesh.Scale = Vector3.new(1, 1, 1)
mesh.Parent = p

local light = Instance.new("PointLight")
light.Brightness = 0.6
light.Range = 7
light.Color = Color3.fromRGB(255, 204, 204)
light.Parent = p

-- Add strawberry particles
local strawberryParticle = Instance.new("ParticleEmitter")
strawberryParticle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
strawberryParticle.Rate = 8
strawberryParticle.Lifetime = NumberRange.new(1, 2)
strawberryParticle.Speed = NumberRange.new(0.5, 1)
strawberryParticle.SpreadAngle = Vector2.new(30, 30)
strawberryParticle.Color = ColorSequence.new(Color3.fromRGB(255, 99, 71))
strawberryParticle.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.3),
	NumberSequenceKeypoint.new(1, 0.1)
})
strawberryParticle.LightEmission = 0.5
strawberryParticle.Parent = p

-- Add cream particles
local creamParticle = Instance.new("ParticleEmitter")
creamParticle.Texture = "rbxasset://textures/particles/smoke_main.dds"
creamParticle.Rate = 5
creamParticle.Lifetime = NumberRange.new(1.5, 2.5)
creamParticle.Speed = NumberRange.new(0.3)
creamParticle.SpreadAngle = Vector2.new(45, 45)
creamParticle.Color = ColorSequence.new(Color3.fromRGB(255, 250, 240))
creamParticle.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.7),
	NumberSequenceKeypoint.new(1, 1)
})
creamParticle.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.4),
	NumberSequenceKeypoint.new(1, 0.8)
})
creamParticle.LightEmission = 0.3
creamParticle.Parent = p

template.PrimaryPart = p
template.Parent = game.ReplicatedStorage

-- Use RunModel for consistency with other droppers
Core.RunModel({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	templateModel = template,

	namePrefix = "WhiteHeart_",
	dropGroup = "CinnamorollOrbs", -- Unique group to prevent collisions with other droppers
	playerGroup = "Players", -- Prevent collision with players

	dropRate = 0.9,
	cashValue = 40,
	lifetime = 2000,

	scaleFactor = 1.0,
	density = 0.4,
	friction = 0.6,
	elasticity = 0.1,

	yawDegrees = 0,
	fadeTime = 0.4,
	extraLower = 1.75,

	cashOn = "primary",
})
