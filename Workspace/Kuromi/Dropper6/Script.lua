--[[
	Kuromi Dropper 6 - Classic Kuromi Style
	✅ Uses classic Kuromi mesh
	✅ Purple glow
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	
	namePrefix = "KuromiDrop_",
	dropGroup = "KuromiOrbs6",
	
	dropRate = 1.5,
	cashValue = 12,
	lifetime = 20,
	
	size = Vector3.new(1, 5, 4),
	material = Enum.Material.SmoothPlastic,
	
	mesh = {
		meshId = "http://www.roblox.com/asset?id=160003363",
		textureId = "http://www.roblox.com/asset/?id=192068356",
		scale = Vector3.new(1, 1, 1),
	},
	
	light = {
		brightness = 1,
		range = 8,
		color = Color3.fromRGB(200, 100, 255),
	},
	
	spawn = {
		velocity = Vector3.new(0, -8, 0),
	},
	spawnYOffset = -2.5,
	
	animation = {
		pop = true,
		popStartSize = Vector3.new(0.1, 0.1, 0.1),
		popDuration = 0.3,
	},
	
	fadeTime = 0.4,
	density = 0.1,
	friction = 0.3,
	elasticity = 0,
})
