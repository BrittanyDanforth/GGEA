--[[
	MyMelody Dropper 1 - DIFFERENT MYMELODY ITEM
	✅ Uses DIFFERENT MyMelody mesh (NOT the beanie)
	✅ Smooth fade-in, collision groups, spawn effects
	✅ Pink MyMelody theme
	⚠️ TODO: Replace meshId with your OTHER MyMelody mesh asset ID
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(0.5)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "MyMelodyDrop1_",
	dropGroup = "MyMelodyDrops1",

	-- Timing
	dropRate = 1.2,
	cashValue = 10,
	lifetime = 180,

	-- Part properties (larger than beanie)
	size = Vector3.new(1.8, 1.8, 1.8),
	color = Color3.fromRGB(255, 192, 203), -- Pink
	material = Enum.Material.SmoothPlastic,
	transparency = 0,

	-- Mesh configuration
	-- ⚠️ CHANGE THIS: Use your OTHER MyMelody mesh (plushie, backpack, etc. - NOT the beanie)
	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://YOUR_OTHER_MYMELODY_MESH_HERE",      -- ⚠️ REPLACE WITH YOUR MESH ID
		textureId = "rbxassetid://YOUR_OTHER_MYMELODY_TEXTURE_HERE",   -- ⚠️ REPLACE WITH YOUR TEXTURE ID
		scale = Vector3.new(1.8, 1.8, 1.8),
	},

	-- Light configuration
	light = {
		brightness = 0.5,
		range = 3.5,
		color = Color3.fromRGB(255, 192, 203), -- Pink light
		spawnFlash = true,
		spawnBrightness = 1.5,
		flashDuration = 0.6,
	},

	-- Spawn configuration
	spawn = {
		rotation = CFrame.Angles(0, 0, 0), -- Upright, no rotation
		velocity = Vector3.new(0, -10, 0),
		randomOffset = Vector3.new(0.2, 0, 0.2), -- Small random offset
	},
	spawnYOffset = -1.5,

	-- Animation
	animation = {
		mesh = {
			startScale = Vector3.new(0.5, 0.5, 0.5),
			endScale = Vector3.new(1.5, 1.5, 1.5),
			duration = 0.5,
			style = Enum.EasingStyle.Back,
		},
	},
	fadeTime = 0.5,

	-- Particles
	particles = {
		-- Pink sparkles
		{
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 4,
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
		-- Star particles
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

	-- Spawn particles (ring effect)
	spawnParticles = {
		{
			Texture = "rbxassetid://262979222",
			Rate = 0,
			Speed = NumberRange.new(0),
			Lifetime = NumberRange.new(0.4),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 2.2)
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 1)
			}),
			Color = ColorSequence.new(Color3.fromRGB(255, 200, 215)),
			emit = 2,
			autoDestroy = true,
			lifetime = 1,
		},
	},

	-- Physics
	density = 0.3,
	friction = 0.3,
	elasticity = 0.02,
})
