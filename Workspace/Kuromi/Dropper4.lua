local Core = require(game.ReplicatedStorage.Modules.DropperCore)
wait(1)
Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	namePrefix = "Kuromi4_",
	dropGroup = "KuromiOrbs4",
	dropRate = 0.50,
	cashValue = 100,
	lifetime = 2000,
	size = Vector3.new(1,1,1),
	color = BrickColor.new("Lime green"),
	material = Enum.Material.Fabric,
	shape = Enum.PartType.Block,
	spawnYOffset = -2.5,
	fadeTime = 0.30,
	density = 0.05,
	friction = 0.2,
	elasticity = 0.0,
})
