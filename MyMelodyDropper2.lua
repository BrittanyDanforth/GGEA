--[[
	MyMelody Dropper 2 - Beanie Mesh (SIMPLIFIED - NO COLLISIONS!)
	✅ Uses MyMelody BEANIE mesh
	✅ Smaller size (1.1)
	✅ NO collision with players (automatic via dropGroup)
	✅ Perfect fade-in/out
	✅ Smooth spawn effects
	✅ SIMPLIFIED - works like HelloKitty Dropper 2
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "MyMelodyDrop2_",
	dropGroup = "MyMelodyDrops2",

	-- Timing
	dropRate = 1.0,
	cashValue = 30,
	lifetime = 180,

	-- Part properties (smaller beanie)
	size = Vector3.new(1.1, 1.1, 1.1),
	color = Color3.fromRGB(255, 170, 200),
	material = Enum.Material.SmoothPlastic,
	transparency = 0,

	-- Mesh configuration (BEANIE MESH)
	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://95965901192105",      -- MyMelody BEANIE mesh
		textureId = "rbxassetid://79765468782729",   -- MyMelody BEANIE texture
		scale = Vector3.new(1.1, 1.1, 1.1),
		offset = Vector3.new(0, 0.05, 0),
	},

	-- Light configuration
	light = {
		brightness = 0.6,
		range = 4,
		color = Color3.fromRGB(255, 200, 215),
		spawnFlash = true,
		spawnBrightness = 1.5,
		flashDuration = 0.6,
	},

	-- Spawn configuration
	spawn = {
		rotation = CFrame.Angles(0, 0, 0), -- Upright
		velocity = Vector3.new(0, -9, 0),
		angularVelocity = Vector3.new(0, 0, 0),
		randomOffset = Vector3.new(0.15, 0, 0.15),
	},
	spawnYOffset = -1.4,

	-- Animation
	animation = {
		mesh = {
			startScale = Vector3.new(0.5, 0.5, 0.5),
			endScale = Vector3.new(1.1, 1.1, 1.1),
			duration = 0.4,
			style = Enum.EasingStyle.Back,
		},
	},
	fadeTime = 0.45,

	-- Particles
	particles = {
		-- Pink sparkles
		{
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 3,
			Lifetime = NumberRange.new(0.8, 1.5),
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(90, 90),
			LightEmission = 1,
			LightInfluence = 0,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Color = ColorSequence.new(Color3.fromRGB(255, 220, 230)),
		},
		-- Stars
		{
			Texture = "rbxasset://textures/particles/star.dds",
			Rate = 1,
			Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(0.5),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 0.6,
			Size = NumberSequence.new(0.35),
			Color = ColorSequence.new(Color3.fromRGB(255, 182, 193)),
		},
	},

	-- Spawn particles (ring effect)
	spawnParticles = {
		{
			Texture = "rbxassetid://262979222",
			Rate = 0,
			Speed = NumberRange.new(0),
			Lifetime = NumberRange.new(0.4),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 2.3),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = ColorSequence.new(Color3.fromRGB(255, 200, 215)),
			emit = 2,
			autoDestroy = true,
			lifetime = 1,
		},
	},

	-- Physics
	density = 0.25,
	friction = 0.35,
	elasticity = 0.02,
})
