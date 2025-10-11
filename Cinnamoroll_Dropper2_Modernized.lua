--[[
	Cinnamoroll Dropper 2 - MODERNIZED
	✅ Uses Cinnamoroll Plushie mesh (rbxassetid://114684643919279)
	✅ Sparkles + stars particles
	✅ Enhanced kawaii effects
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "CinnamorollMesh_",
	dropGroup = "CinnamorollOrbs2",

	dropRate = 1.0,
	cashValue = 15,
	lifetime = 2000,

	size = Vector3.new(2, 2, 2),
	color = Color3.new(1, 1, 1),
	material = Enum.Material.SmoothPlastic,
	transparency = 0,

	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://114684643919279", -- Cinnamoroll Plushie mesh
		textureId = "rbxassetid://136339015269351", -- Cinnamoroll Plushie texture
		scale = Vector3.new(2, 2, 2),
	},

	light = {
		brightness = 0.6,
		range = 4,
		color = Color3.new(1, 1, 1), -- White light
		spawnFlash = true,
		spawnBrightness = 2,
		flashDuration = 0.8,
	},

	spawn = {
		rotation = CFrame.Angles(0, 0, 0), -- Upright, no rotation
		velocity = Vector3.new(0, -10, 0),
		pattern = {
			Vector3.new(0.2, 0, 0.2),
			Vector3.new(-0.2, 0, 0.2),
			Vector3.new(0.2, 0, -0.2),
			Vector3.new(-0.2, 0, -0.2),
			Vector3.new(0, 0, 0),
		}
	},
	spawnYOffset = -1.75,

	animation = {
		mesh = {
			startScale = Vector3.new(0.5, 0.5, 0.5),
			endScale = Vector3.new(2, 2, 2),
			duration = 0.6,
			style = Enum.EasingStyle.Elastic,
		},
	},

	particles = {
		-- White sparkles to match Cinnamoroll
		{
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 5,
			Lifetime = NumberRange.new(0.5, 1.5),
			Speed = NumberRange.new(0.5, 2),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 1,
			LightInfluence = 0,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(1, 0)
			}),
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
		},
		-- Star particles
		{
			Texture = "rbxasset://textures/particles/star.dds",
			Rate = 2,
			Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(0.5),
			SpreadAngle = Vector2.new(360, 360),
			LightEmission = 0.8,
			Size = NumberSequence.new(0.4),
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		},
	},

	spawnParticles = {
		{
			Texture = "rbxassetid://262979222",
			Rate = 0,
			Speed = NumberRange.new(0),
			Lifetime = NumberRange.new(0.4),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 2.5)
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(0.5, 0.5),
				NumberSequenceKeypoint.new(1, 1)
			}),
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)), -- White cloud
			emit = 2,
			autoDestroy = true,
			lifetime = 1,
		},
	},

	density = 0.2,
	friction = 0.3,
	elasticity = 0,
})
