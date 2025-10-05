-- Kuromi Dropper 2
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
