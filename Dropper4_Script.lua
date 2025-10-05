-- Kuromi Dropper 4
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
