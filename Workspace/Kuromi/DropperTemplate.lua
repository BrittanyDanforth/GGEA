-- Workspace.Kuromi.DropperX.Script (template)
local Core = require(game.ReplicatedStorage.Modules.DropperCore)

-- Delay slightly to let world finish initializing
task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix   = "KuromiX_",
	dropGroup    = "KuromiOrbsX",

	-- tuning
	dropRate     = 0.50,
	cashValue    = 100,
	lifetime     = 2000,

	-- visuals/physics
	size         = Vector3.new(1,1,1),
	color        = BrickColor.new("Lime green"),
	material     = Enum.Material.Fabric,
	shape        = Enum.PartType.Block,

	-- spawn lower & same as working ones
	spawnYOffset = -2.5,
	fadeTime     = 0.30,

	density      = 0.05,
	friction     = 0.2,
	elasticity   = 0.0,
})
