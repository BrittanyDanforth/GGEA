-- Kuromi Dropper 12
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
