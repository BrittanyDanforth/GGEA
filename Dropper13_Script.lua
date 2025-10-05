-- Kuromi Dropper 13
local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)
Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	namePrefix = "Kuromi13_",
	dropGroup = "KuromiOrbs13",
	dropRate = 0.3,
	cashValue = 300,
	lifetime = 120,
	size = Vector3.new(4.5, 4.5, 4.5),
	color = BrickColor.new("Really red"),
	material = Enum.Material.ForceField,
	spawnYOffset = -2.5,
	fadeTime = 0.3,
	density = 0.05,
	friction = 0.2,
	elasticity = 0.0,
	lightColor = Color3.fromRGB(255, 50, 50),
	lightBrightness = 3.5,
})
