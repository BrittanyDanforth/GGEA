--[[
	Cinnamoroll Dropper 9 - MODERNIZED
	✅ Basic green fabric drops
	✅ Smooth animations, collision groups, effects
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "Drop9_",
	dropGroup = "CinnamorollOrbs9",

	dropRate = 0.5,
	cashValue = 100,
	lifetime = 2000,

	size = Vector3.new(1, 1, 1),
	color = Color3.fromRGB(0, 255, 0), -- Lime green
	material = Enum.Material.Fabric,
	transparency = 0,

	light = {
		brightness = 0.4,
		range = 4,
		color = Color3.fromRGB(0, 255, 0), -- Green glow
		spawnFlash = true,
		spawnBrightness = 1.5,
		flashDuration = 0.6,
	},

	spawn = {
		rotation = CFrame.Angles(0, 0, 0),
		velocity = Vector3.new(0, -12, 0),
		randomOffset = Vector3.new(0.2, 0, 0.2),
	},
	spawnYOffset = -1.4,

	animation = {
		pop = true,
		startSize = Vector3.new(0.1, 0.1, 0.1),
		endSize = Vector3.new(1, 1, 1),
		duration = 0.5,
		style = Enum.EasingStyle.Back,
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
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 1)
			}),
			Color = ColorSequence.new(Color3.fromRGB(0, 255, 0)),
			emit = 1,
			autoDestroy = true,
			lifetime = 1,
		},
	},

	density = 0.3,
	friction = 0.5,
	elasticity = 0.1,
})
