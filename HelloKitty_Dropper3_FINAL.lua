--[[
	HelloKitty Dropper 3 - Premium Bow Style
	✅ Uses bow mesh
	✅ Pink particles
	✅ Premium effects
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "PremiumHK_",
	dropGroup = "HelloKittyDrops3",

	dropRate = 0.6,
	cashValue = 50,
	lifetime = 180,

	size = Vector3.new(1.817, 1.323, 0.281),
	color = Color3.fromRGB(151, 0, 0),
	material = Enum.Material.SmoothPlastic,
	transparency = 0,

	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://3071180788",
		textureId = "",
		scale = Vector3.new(4, 4, 4),
	},

	light = {
		brightness = 1,
		range = 8,
		color = Color3.fromRGB(255, 100, 150),
		spawnFlash = true,
		spawnBrightness = 2,
		flashDuration = 0.6,
	},

	spawn = {
		rotation = CFrame.Angles(math.rad(70), 0, math.rad(180)),
		velocity = Vector3.new(0, -10, 0),
	},
	spawnYOffset = -1.75,

	animation = {
		mesh = {
			startScale = Vector3.new(1, 1, 1),
			endScale = Vector3.new(4, 4, 4),
			duration = 0.4,
			style = Enum.EasingStyle.Back,
		},
	},
	fadeTime = 0.4,

	particles = {
		-- Pink sparkles
		{
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 15,
			Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(1, 2),
			SpreadAngle = Vector2.new(45, 45),
			Color = ColorSequence.new(Color3.fromRGB(255, 100, 150)),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 0)
			}),
			LightEmission = 0.8,
		},
		-- Star particles
		{
			Texture = "rbxasset://textures/particles/star.dds",
			Rate = 8,
			Lifetime = NumberRange.new(2, 3),
			Speed = NumberRange.new(1),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(1, 0.1)
			}),
			Color = ColorSequence.new(Color3.fromRGB(255, 182, 193)),
			LightEmission = 1,
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
				NumberSequenceKeypoint.new(1, 3)
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 1)
			}),
			Color = ColorSequence.new(Color3.fromRGB(255, 100, 150)),
			emit = 2,
			autoDestroy = true,
			lifetime = 1,
		},
	},

	density = 0.2,
	friction = 0.4,
	elasticity = 0.3,
})
