--[[
	Kuromi Dropper 1 - Basic Kawaii Style (FIXED FOR v4.4)
	✅ Uses Kuromi mesh (rbxassetid://15014438476)
	✅ Smooth fade-in, collision groups, spawn effects
	✅ Purple/pink Kuromi theme
	✅ FIXED: Now uses Core.RunModel() instead of Core.Run()
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Create a template model for the Kuromi drop
local templateModel = Instance.new("Model")
templateModel.Name = "KuromiDropTemplate"

-- Create the main part
local mainPart = Instance.new("Part")
mainPart.Name = "PrimaryPart"
mainPart.Size = Vector3.new(3.445, 2.552, 2.148)
mainPart.Color = Color3.new(1, 1, 1)
mainPart.Material = Enum.Material.SmoothPlastic
mainPart.Shape = Enum.PartType.Block
mainPart.Transparency = 0
mainPart.Anchored = false
mainPart.CanCollide = true
mainPart.Parent = templateModel

-- Add the Kuromi mesh
local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.FileMesh
mesh.MeshId = "rbxassetid://15014438476"
mesh.TextureId = "rbxassetid://15014443369"
mesh.Scale = Vector3.new(2, 2, 2)
mesh.Parent = mainPart

-- Add point light
local light = Instance.new("PointLight")
light.Brightness = 0.4
light.Range = 3
light.Color = Color3.fromRGB(200, 150, 230)
light.Parent = mainPart

-- Set as primary part
templateModel.PrimaryPart = mainPart

-- Store template in ReplicatedStorage for DropperCore to use
local templateStorage = game.ReplicatedStorage:FindFirstChild("DropperTemplates")
if not templateStorage then
	templateStorage = Instance.new("Folder")
	templateStorage.Name = "DropperTemplates"
	templateStorage.Parent = game.ReplicatedStorage
end

templateModel.Parent = templateStorage

-- Now use the new RunModel function
Core.RunModel({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	templateModel = templateModel, -- Pass the template model

	namePrefix = "KuromiDrop_",
	dropGroup = "KuromiOrbs1",
	playerGroup = "Players",

	-- Timing
	dropRate = 1.2,
	cashValue = 10,
	lifetime = 2000,

	-- Scaling and physics
	scaleFactor = 1.0, -- Keep original size
	density = 0.3,
	friction = 0.5,
	elasticity = 0.1,
	yawDegrees = 0, -- No rotation

	-- Spawn configuration
	extraLower = 2.0, -- Drop height offset
	fadeTime = 0.5,

	-- Cash configuration
	cashOn = "primary", -- Put cash value on primary part only

	-- Collection detection
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags = {"Collector", "SellZone"},
})