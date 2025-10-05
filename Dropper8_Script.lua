-- Kuromi Dropper 8
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
