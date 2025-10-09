-- Kuromi Dropper 2 - Enhanced Kawaii Style (v4.4 FIX)
-- ✅ FIXED: Added playerGroup to prevent player collisions
-- ✅ Unique dropGroup to prevent collisions with other droppers

local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)

-- Create a simple template model
local template = Instance.new("Model")
template.Name = "KuromiDrop2_Template"

local p = Instance.new("Part")
p.Name = "PrimaryPart"
p.Size = Vector3.new(1.782, 1.103, 1.714)
p.Color = Color3.new(1, 1, 1)
p.Material = Enum.Material.SmoothPlastic
p.Anchored = false
p.CanCollide = true
p.Transparency = 0
p.Parent = template

local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.FileMesh
mesh.MeshId = "rbxassetid://17087317963"
mesh.TextureId = "rbxassetid://17087030178"
mesh.Scale = Vector3.new(1.5, 1.5, 1.5)
mesh.Parent = p

local light = Instance.new("PointLight")
light.Brightness = 0.6
light.Range = 4
light.Color = Color3.fromRGB(200, 150, 230)
light.Parent = p

template.PrimaryPart = p
template.Parent = game.ReplicatedStorage

Core.RunModel({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	templateModel = template,

	namePrefix = "KuromiDrop2_",
	dropGroup = "KuromiOrbs2", -- Unique group to prevent collisions with other droppers
	playerGroup = "Players", -- Prevent collision with players

	dropRate = 1.0,
	cashValue = 15,
	lifetime = 2000,

	scaleFactor = 1.0,
	density = 0.2,
	friction = 0.3,
	elasticity = 0,

	yawDegrees = 140,
	fadeTime = 0.6,
	extraLower = 2,

	cashOn = "primary",
})
