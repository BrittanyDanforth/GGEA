--[[
	Kuromi Dropper 3 - Premium Dark Style
	✅ Uses premium dark mesh
	✅ Star particles
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	
	namePrefix = "PremiumKuromi_",
	dropGroup = "KuromiOrbs3",
	
	dropRate = 0.6,
	cashValue = 50,
	lifetime = 2000,
	
	size = Vector3.new(1.479, 1.158, 0.408),
	color = Color3.fromRGB(17, 17, 17),
	material = Enum.Material.SmoothPlastic,
	
	mesh = {
		meshId = "rbxassetid://431221914",
		textureId = "",
		scale = Vector3.new(0.25, 0.25, 0.25),
	},
	
	light = {
		brightness = 1,
		range = 10,
		color = Color3.fromRGB(200, 150, 230),
		spawnFlash = true,
		spawnBrightness = 2,
		flashDuration = 0.6,
	},
	
	spawn = {
		rotation = CFrame.Angles(math.rad(90), math.rad(195), 0),
		velocity = Vector3.new(0, -10, 0),
		angularVelocity = Vector3.new(0, 5, 0),
	},
	spawnYOffset = -1.75,
	
	animation = {
		mesh = {
			startScale = Vector3.new(0.06, 0.06, 0.06),
			endScale = Vector3.new(0.25, 0.25, 0.25),
			duration = 0.4,
			style = Enum.EasingStyle.Back,
		},
	},
	
	particles = {
		-- Star particles
		{
			Texture = "rbxasset://textures/particles/star.dds",
			Rate = 10,
			Lifetime = NumberRange.new(2, 3),
			Speed = NumberRange.new(1),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(1, 0.1)
			}),
			Color = ColorSequence.new(Color3.fromRGB(255, 150, 220)),
			LightEmission = 1,
		},
	},
	
	density = 0.2,
	friction = 0.4,
	elasticity = 0.3,
})
