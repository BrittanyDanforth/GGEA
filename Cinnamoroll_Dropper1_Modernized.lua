--[[
	Cinnamoroll Dropper 1 - MODERNIZED
	✅ Uses Cinnamoroll Backpack mesh (rbxassetid://9434530930)
	✅ Smooth fade-in, collision groups, spawn effects
	✅ Blue/white Cinnamoroll theme
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "CinnamorollBackpack_",
	dropGroup = "CinnamorollOrbs1",

	-- Timing
	dropRate = 1.2,
	cashValue = 10,
	lifetime = 2000,

	-- Part properties
	size = Vector3.new(2, 2, 2),
	color = Color3.new(1, 1, 1), -- White base for texture
	material = Enum.Material.SmoothPlastic,
	shape = Enum.PartType.Block,
	transparency = 0,

	-- Mesh configuration
	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://9434530930", -- Cinnamoroll Backpack mesh
		textureId = "rbxassetid://9434566192", -- Cinnamoroll texture
		scale = Vector3.new(2, 2, 2),
	},

	-- Light configuration
	light = {
		brightness = 0.4,
		range = 3,
		color = Color3.new(1, 1, 1), -- White/blue light
		spawnFlash = true,
		spawnBrightness = 1.5,
		flashDuration = 0.6,
		collectBrightness = 3,
	},

	-- Spawn configuration
	spawn = {
		rotation = CFrame.Angles(math.rad(180), math.rad(180), 0), -- 180 degrees vertical + horizontal
		velocity = Vector3.new(0, -12, 0),
		randomOffset = Vector3.new(0.2, 0, 0.2), -- Small random offset
	},
	spawnYOffset = -2,

	-- Animation
	animation = {
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
			Color = ColorSequence.new(Color3.new(1, 1, 1)), -- White ring
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
