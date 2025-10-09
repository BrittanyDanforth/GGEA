-- Kuromi Dropper 3 - Premium Dark Style (v4.4 FIX)
-- ✅ FIXED: Added playerGroup to prevent player collisions
-- ✅ Unique dropGroup to prevent collisions with other droppers

local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)

local template = Instance.new("Model")
template.Name = "KuromiDrop3_Template"

local p = Instance.new("Part")
p.Name = "PrimaryPart"
p.Size = Vector3.new(1.479, 1.158, 0.408)
p.Color = Color3.fromRGB(17, 17, 17)
p.Material = Enum.Material.SmoothPlastic
p.Anchored = false
p.CanCollide = true
p.Parent = template

local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.FileMesh
mesh.MeshId = "rbxassetid://431221914"
mesh.TextureId = ""
mesh.Scale = Vector3.new(0.25, 0.25, 0.25)
mesh.Parent = p

local light = Instance.new("PointLight")
light.Brightness = 1
light.Range = 10
light.Color = Color3.fromRGB(200, 150, 230)
light.Parent = p

template.PrimaryPart = p
template.Parent = game.ReplicatedStorage

Core.RunModel({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	templateModel = template,

	namePrefix = "PremiumKuromi_",
	dropGroup = "KuromiOrbs3", -- Unique group to prevent collisions with other droppers
	playerGroup = "Players", -- Prevent collision with players

	dropRate = 0.6,
	cashValue = 50,
	lifetime = 2000,

	scaleFactor = 1.0,
	density = 0.2,
	friction = 0.4,
	elasticity = 0.3,

	yawDegrees = 195,
	fadeTime = 0.5,
	extraLower = 2,

	cashOn = "primary",
})
