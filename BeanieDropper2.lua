--[[
	Beanie Dropper 2 - MODERNIZED
	✅ Uses Beanie mesh (rbxassetid://95965901192105)
	✅ Spawns inline with mesh config
	✅ No ReplicatedStorage template needed
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "BeanieMesh_",
	dropGroup = "BeanieDrops2",
	playerGroup = "Players",

	dropRate = 1.2,
	cashValue = 10,
	lifetime = 180,

	size = Vector3.new(2, 2, 2),
	color = Color3.new(1, 0.8, 0.6), -- Beanie color
	material = Enum.Material.SmoothPlastic,
	transparency = 0,

	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://95965901192105",      -- Beanie mesh
		textureId = "rbxassetid://79765468782729",   -- Beanie color map
		scale = Vector3.new(1.1, 1.1, 1.1),
		offset = Vector3.new(0, 0.05, 0),
	},

	spawn = {
		rotation = CFrame.Angles(0, 0, 0), -- Upright
		velocity = Vector3.new(0, -10, 0),
	},
	spawnYOffset = -1.75,

	animation = {
		mesh = {
			startScale = Vector3.new(0.5, 0.5, 0.5),
			endScale = Vector3.new(1.1, 1.1, 1.1),
			duration = 0.6,
			style = Enum.EasingStyle.Elastic,
		},
	},

	density = 0.8,
	friction = 0.18,
	elasticity = 0.03,
})
