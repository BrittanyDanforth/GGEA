--[[
	Kuromi Dropper 8 - Simple Fabric Style
	✅ No mesh - just fabric blocks
	✅ Lime green color
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	
	namePrefix = "Kuromi8_",
	dropGroup = "KuromiOrbs8",
	
	dropRate = 0.5,
	cashValue = 100,
	lifetime = 2000,
	
	size = Vector3.new(1, 1, 1),
	brickColor = BrickColor.new("Lime green"),
	material = Enum.Material.Fabric,
	
	light = {
		brightness = 1,
		range = 6,
		color = Color3.fromRGB(50, 255, 50),
	},
	
	spawn = {
		velocity = Vector3.new(0, -8, 0),
	},
	spawnYOffset = -2.5,
	
	animation = {
		pop = true,
		popStartSize = Vector3.new(0.1, 0.1, 0.1),
		popDuration = 0.2,
	},
	
	fadeTime = 0.3,
	density = 0.05,
	friction = 0.2,
	elasticity = 0,
})
