-- Kuromi Dropper 11
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
