-- ========================================
-- ALL KUROMI DROPPER SCRIPTS (1-6, 8-13)
-- Copy each section to its dropper
-- ========================================

-- =================== DROPPER 1 ===================
-- Put in: Dropper1 folder
local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)
Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	namePrefix = "Kuromi1_",
	dropGroup = "KuromiOrbs1",
	dropRate = 1.2,
	cashValue = 10,
	lifetime = 120,
	size = Vector3.new(1, 1, 1),
	color = BrickColor.new("Hot pink"),
	material = Enum.Material.SmoothPlastic,
	spawnYOffset = -2.5,
	fadeTime = 0.3,
	density = 0.1,
	friction = 0.3,
	elasticity = 0.0,
	lightColor = Color3.fromRGB(255, 150, 200),
})

-- =================== DROPPER 2 ===================
-- Put in: Dropper2 folder
local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)
Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	namePrefix = "Kuromi2_",
	dropGroup = "KuromiOrbs2",
	dropRate = 1.0,
	cashValue = 15,
	lifetime = 120,
	size = Vector3.new(1.2, 1.2, 1.2),
	color = BrickColor.new("Magenta"),
	material = Enum.Material.SmoothPlastic,
	spawnYOffset = -2.5,
	fadeTime = 0.3,
	density = 0.1,
	friction = 0.3,
	elasticity = 0.0,
	lightColor = Color3.fromRGB(200, 150, 230),
})

-- =================== DROPPER 3 ===================
-- Put in: Dropper3 folder
local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)
Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	namePrefix = "Kuromi3_",
	dropGroup = "KuromiOrbs3",
	dropRate = 0.8,
	cashValue = 25,
	lifetime = 120,
	size = Vector3.new(1.5, 1.5, 1.5),
	color = BrickColor.new("Alder"),
	material = Enum.Material.SmoothPlastic,
	spawnYOffset = -2.5,
	fadeTime = 0.3,
	density = 0.1,
	friction = 0.3,
	elasticity = 0.0,
	lightColor = Color3.fromRGB(200, 100, 255),
})

-- =================== DROPPER 4 (Cinnamoroll style) ===================
-- Put in: Dropper4 folder
local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)
Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	namePrefix = "Kuromi4_",
	dropGroup = "KuromiOrbs4",
	dropRate = 0.9,
	cashValue = 40,
	lifetime = 120,
	size = Vector3.new(1.8, 1.8, 1.8),
	color = BrickColor.new("Pastel Blue"),
	material = Enum.Material.SmoothPlastic,
	spawnYOffset = -2.5,
	fadeTime = 0.3,
	density = 0.1,
	friction = 0.3,
	elasticity = 0.0,
	lightColor = Color3.fromRGB(255, 204, 204),
})

-- =================== DROPPER 5 ===================
-- Put in: Dropper5 folder
local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)
Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	namePrefix = "Kuromi5_",
	dropGroup = "KuromiOrbs5",
	dropRate = 0.7,
	cashValue = 60,
	lifetime = 120,
	size = Vector3.new(2, 2, 2),
	color = BrickColor.new("Institutional white"),
	material = Enum.Material.Neon,
	spawnYOffset = -2.5,
	fadeTime = 0.3,
	density = 0.08,
	friction = 0.3,
	elasticity = 0.0,
	lightColor = Color3.fromRGB(255, 255, 255),
	lightBrightness = 1.5,
})

-- =================== DROPPER 6 ===================
-- Put in: Dropper6 folder
local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)
Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	namePrefix = "Kuromi6_",
	dropGroup = "KuromiOrbs6",
	dropRate = 0.6,
	cashValue = 80,
	lifetime = 120,
	size = Vector3.new(2.2, 2.2, 2.2),
	color = BrickColor.new("Royal purple"),
	material = Enum.Material.Neon,
	spawnYOffset = -2.5,
	fadeTime = 0.3,
	density = 0.08,
	friction = 0.3,
	elasticity = 0.0,
	lightColor = Color3.fromRGB(200, 100, 255),
	lightBrightness = 1.5,
})

-- =================== DROPPER 8 ===================
-- Put in: Dropper8 folder
local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)
Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	namePrefix = "Kuromi8_",
	dropGroup = "KuromiOrbs8",
	dropRate = 0.5,
	cashValue = 100,
	lifetime = 120,
	size = Vector3.new(2.5, 2.5, 2.5),
	color = BrickColor.new("Lime green"),
	material = Enum.Material.ForceField,
	spawnYOffset = -2.5,
	fadeTime = 0.3,
	density = 0.05,
	friction = 0.2,
	elasticity = 0.0,
	lightColor = Color3.fromRGB(50, 255, 50),
	lightBrightness = 2,
})

-- =================== DROPPER 9 ===================
-- Put in: Dropper9 folder
local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)
Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	namePrefix = "Kuromi9_",
	dropGroup = "KuromiOrbs9",
	dropRate = 0.5,
	cashValue = 120,
	lifetime = 120,
	size = Vector3.new(2.8, 2.8, 2.8),
	color = BrickColor.new("Bright green"),
	material = Enum.Material.Neon,
	spawnYOffset = -2.5,
	fadeTime = 0.3,
	density = 0.05,
	friction = 0.2,
	elasticity = 0.0,
	lightColor = Color3.fromRGB(50, 255, 100),
	lightBrightness = 2,
})

-- =================== DROPPER 10 ===================
-- Put in: Dropper10 folder
local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)
Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	namePrefix = "Kuromi10_",
	dropGroup = "KuromiOrbs10",
	dropRate = 0.5,
	cashValue = 150,
	lifetime = 120,
	size = Vector3.new(3, 3, 3),
	color = BrickColor.new("Electric blue"),
	material = Enum.Material.Neon,
	spawnYOffset = -2.5,
	fadeTime = 0.3,
	density = 0.05,
	friction = 0.2,
	elasticity = 0.0,
	lightColor = Color3.fromRGB(100, 150, 255),
	lightBrightness = 2.5,
})

-- =================== DROPPER 11 ===================
-- Put in: Dropper11 folder
local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)
Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	namePrefix = "Kuromi11_",
	dropGroup = "KuromiOrbs11",
	dropRate = 0.4,
	cashValue = 200,
	lifetime = 120,
	size = Vector3.new(3.5, 3.5, 3.5),
	color = BrickColor.new("Toothpaste"),
	material = Enum.Material.Neon,
	spawnYOffset = -2.5,
	fadeTime = 0.3,
	density = 0.05,
	friction = 0.2,
	elasticity = 0.0,
	lightColor = Color3.fromRGB(100, 255, 255),
	lightBrightness = 3,
})

-- =================== DROPPER 12 ===================
-- Put in: Dropper12 folder
local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)
Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	namePrefix = "Kuromi12_",
	dropGroup = "KuromiOrbs12",
	dropRate = 0.4,
	cashValue = 250,
	lifetime = 120,
	size = Vector3.new(4, 4, 4),
	color = BrickColor.new("Bright violet"),
	material = Enum.Material.Neon,
	spawnYOffset = -2.5,
	fadeTime = 0.3,
	density = 0.05,
	friction = 0.2,
	elasticity = 0.0,
	lightColor = Color3.fromRGB(200, 100, 255),
	lightBrightness = 3,
})

-- =================== DROPPER 13 ===================
-- Put in: Dropper13 folder
local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)
Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	namePrefix = "Kuromi13_",
	dropGroup = "KuromiOrbs13",
	dropRate = 0.3,
	cashValue = 300,
	lifetime = 120,
	size = Vector3.new(4.5, 4.5, 4.5),
	color = BrickColor.new("Really red"),
	material = Enum.Material.ForceField,
	spawnYOffset = -2.5,
	fadeTime = 0.3,
	density = 0.05,
	friction = 0.2,
	elasticity = 0.0,
	lightColor = Color3.fromRGB(255, 50, 50),
	lightBrightness = 3.5,
})
