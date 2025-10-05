-- Kuromi Dropper 3
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
