-- Kuromi Dropper 6
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
