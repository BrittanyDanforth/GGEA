-- Kuromi Dropper 1
-- Put in: Workspace.Kuromi tycoon.Tycoons.Kuromi.Purchases.Dropper1
local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)
Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	
	namePrefix = "Kuromi1_",
	dropGroup = "KuromiOrbs1",
	
	-- Basic starter dropper
	dropRate = 1.2,
	cashValue = 10,
	lifetime = 120,
	
	-- Visuals
	size = Vector3.new(1, 1, 1),
	color = BrickColor.new("Hot pink"),
	material = Enum.Material.SmoothPlastic,
	shape = Enum.PartType.Block,
	
	-- Spawn settings
	spawnYOffset = -2.5,
	fadeTime = 0.3,
	
	-- Physics (light & smooth)
	density = 0.1,
	friction = 0.3,
	elasticity = 0.0,
	
	-- Light
	lightColor = Color3.fromRGB(255, 150, 200),
	lightRange = 6,
	lightBrightness = 1,
})
