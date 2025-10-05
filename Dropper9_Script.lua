-- Kuromi Dropper 9
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
