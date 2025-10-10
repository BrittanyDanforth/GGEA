--[[
	Kuromi Dropper 1 - Basic Kawaii Style
	✅ Uses Kuromi mesh (rbxassetid://15014438476)
	✅ Smooth fade-in, collision groups, spawn effects
	✅ Purple/pink Kuromi theme
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "KuromiDrop_",
	dropGroup = "KuromiOrbs1",

	-- Timing
	dropRate = 1.2,
	cashValue = 10,
	lifetime = 2000,

	-- Part properties
	size = Vector3.new(3.445, 2.552, 2.148),
	color = Color3.new(1, 1, 1),
	material = Enum.Material.SmoothPlastic,
	shape = Enum.PartType.Block,
	transparency = 0, -- Set to 0 so fade works properly

	-- Mesh configuration
	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://15014438476",
		textureId = "rbxassetid://15014443369",
		scale = Vector3.new(2, 2, 2),
	},

	-- Light configuration
	light = {
		brightness = 0.4,
		range = 3,
		color = Color3.fromRGB(200, 150, 230),
		spawnFlash = true,
		spawnBrightness = 1.5,
		flashDuration = 0.6,
		collectBrightness = 3,
	},

	-- Spawn configuration
	spawn = {
		rotation = CFrame.Angles(0, 0, 0), -- No rotation, face upright
		velocity = Vector3.new(0, -12, 0),
	},
	spawnYOffset = -2,

	-- Animation
	animation = {
		pop = false, -- Don't use pop, we use mesh animation
		mesh = {
			startScale = Vector3.new(0.5, 0.5, 0.5),
			endScale = Vector3.new(2, 2, 2),
			duration = 0.5,
			style = Enum.EasingStyle.Back,
		},
	},
	fadeTime = 0.5,

	-- Spawn particles (ring effect)
	spawnParticles = {
		{
			Texture = "rbxassetid://262979222",
			Rate = 0,
			Speed = NumberRange.new(0),
			Lifetime = NumberRange.new(0.3),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 2)
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 1)
			}),
			Color = ColorSequence.new(Color3.fromRGB(200, 150, 230)),
			emit = 1,
			autoDestroy = true,
			lifetime = 1,
		},
	},

	-- Physics
	density = 0.3,
	friction = 0.5,
	elasticity = 0.1,
})
