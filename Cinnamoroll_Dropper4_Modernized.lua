--[[
	Cinnamoroll Dropper 4 - MODERNIZED White Heart Style
	✅ Uses White Heart mesh (rbxassetid://601198887)
	✅ Strawberry + cream particles
	✅ Sweet effects
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "WhiteHeart_",
	dropGroup = "CinnamorollOrbs4",

	dropRate = 0.9,
	cashValue = 40,
	lifetime = 2000,

	size = Vector3.new(2, 2, 2),
	color = Color3.fromRGB(255, 255, 255), -- Pure white
	material = Enum.Material.SmoothPlastic,
	transparency = 0,
	reflectance = 0.2, -- Frosting shine

	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://601198887", -- White Heart mesh
		textureId = "", -- No texture
		scale = Vector3.new(1, 1, 1),
	},

	light = {
		brightness = 0.6,
		range = 7,
		color = Color3.fromRGB(255, 204, 204), -- Pink glow
		spawnFlash = true,
		spawnBrightness = 1.5,
		flashDuration = 0.6,
	},

	spawn = {
		rotation = CFrame.Angles(0, 0, 0), -- No rotation
		velocity = Vector3.new(0, -8, 0),
	},
	spawnYOffset = -1.75,

	animation = {
		mesh = {
			startScale = Vector3.new(0.001, 0.001, 0.001),
			endScale = Vector3.new(0.04, 0.04, 0.04),
			duration = 0.4,
			style = Enum.EasingStyle.Back,
		},
	},

	particles = {
		-- Strawberry particles (red)
		{
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 8,
			Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(0.5, 1),
			SpreadAngle = Vector2.new(30, 30),
			Color = ColorSequence.new(Color3.fromRGB(255, 99, 71)), -- Tomato red
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(1, 0.1)
			}),
			LightEmission = 0.5,
		},
		-- Cream particles (white)
		{
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Rate = 5,
			Lifetime = NumberRange.new(1.5, 2.5),
			Speed = NumberRange.new(0.3),
			SpreadAngle = Vector2.new(45, 45),
			Color = ColorSequence.new(Color3.fromRGB(255, 250, 240)), -- Cream white
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.7),
				NumberSequenceKeypoint.new(1, 1)
			}),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4),
				NumberSequenceKeypoint.new(1, 0.8)
			}),
			LightEmission = 0.3,
		},
	},

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
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 1)
			}),
			Color = ColorSequence.new(Color3.fromRGB(255, 182, 193)),
			emit = 1,
			autoDestroy = true,
			lifetime = 1,
		},
	},

	density = 0.4,
	friction = 0.6,
	elasticity = 0.1,
})
