--[[
	MyMelody Dropper 2 - Beanie Mesh
	✅ Uses beanie mesh directly
	✅ No collisions
	✅ Proper sizing
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "MyMelodyBeanie_",
	dropGroup = "MyMelodyDrops2",

	dropRate = 1.0,
	cashValue = 30,
	lifetime = 180,

	size = Vector3.new(1.1, 1.1, 1.1),
	color = Color3.fromRGB(255, 170, 200),
	material = Enum.Material.SmoothPlastic,
	transparency = 0,

	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://95965901192105",
		textureId = "rbxassetid://79765468782729",
		scale = Vector3.new(1.1, 1.1, 1.1),
	},

	light = {
		brightness = 0.6,
		range = 4,
		color = Color3.fromRGB(255, 200, 215),
		spawnFlash = true,
		spawnBrightness = 1.5,
		flashDuration = 0.6,
	},

	spawn = {
		rotation = CFrame.Angles(0, 0, 0),
		velocity = Vector3.new(0, -10, 0),
	},
	spawnYOffset = -1.75,

	animation = {
		mesh = {
			startScale = Vector3.new(0.5, 0.5, 0.5),
			endScale = Vector3.new(1.1, 1.1, 1.1),
			duration = 0.5,
			style = Enum.EasingStyle.Back,
		},
	},
	fadeTime = 0.5,

	particles = {
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
			Color = ColorSequence.new(Color3.fromRGB(255, 200, 215)),
		},
		{
			Texture = "rbxasset://textures/particles/star.dds",
			Rate = 2,
			Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(0.5),
			SpreadAngle = Vector2.new(360, 360),
			LightEmission = 0.8,
			Size = NumberSequence.new(0.35),
			Color = ColorSequence.new(Color3.fromRGB(255, 182, 193)),
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
			Color = ColorSequence.new(Color3.fromRGB(255, 182, 193)),
			emit = 2,
			autoDestroy = true,
			lifetime = 1,
		},
	},

	density = 0.2,
	friction = 0.3,
	elasticity = 0.1,
})
