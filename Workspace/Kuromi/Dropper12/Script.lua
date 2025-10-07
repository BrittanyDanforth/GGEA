--[[
	Kuromi Dropper 12 - Paintball Gun Style
	✅ Uses paintball gun mesh
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	
	namePrefix = "PaintballDrop_",
	dropGroup = "KuromiOrbs12",
	
	dropRate = 1.5,
	cashValue = 100,
	lifetime = 20,
	
	size = Vector3.new(0.2, 0.2, 0.2),
	material = Enum.Material.SmoothPlastic,
	
	mesh = {
		meshId = "rbxasset://fonts/PaintballGun.mesh",
		textureId = "rbxasset://textures/PaintballGunTex128.png",
		scale = Vector3.new(1, 1, 1),
	},
	
	light = {
		brightness = 1,
		range = 6,
		color = Color3.fromRGB(255, 100, 50),
	},
	
	spawn = {
		velocity = Vector3.new(0, -8, 0),
	},
	spawnYOffset = -2.5,
	
	animation = {
		pop = true,
		popStartSize = Vector3.new(0.05, 0.05, 0.05),
		popDuration = 0.2,
	},
	
	fadeTime = 0.3,
	density = 0.05,
	friction = 0.2,
	elasticity = 0,
})
