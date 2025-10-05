-- Kuromi Dropper 5
local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)
Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	namePrefix = "Kuromi5_",
	dropGroup = "KuromiOrbs5",
	dropRate = 0.7,
	cashValue = 60,
	lifetime = 120,
	size = Vector3.new(2, 2, 2),
	color = BrickColor.new("Institutional white"),
	material = Enum.Material.Neon,
	spawnYOffset = -2.5,
	fadeTime = 0.3,
	density = 0.08,
	friction = 0.3,
	elasticity = 0.0,
	lightColor = Color3.fromRGB(255, 255, 255),
	lightBrightness = 1.5,
})
