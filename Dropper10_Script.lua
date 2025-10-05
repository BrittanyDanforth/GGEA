-- Kuromi Dropper 10
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
