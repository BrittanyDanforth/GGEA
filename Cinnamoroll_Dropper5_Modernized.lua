--[[
	Cinnamoroll Dropper 5 - MODERNIZED Ice Cream Style
	✅ Uses Ice Cream mesh (rbxassetid://1486490132)
	✅ Thickened and enlarged (not skinny)
	✅ Polished effects
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Your provided base scale
local BASE_SCALE = Vector3.new(1.177, 2.512, 1.164)

-- MODIFIED: Made shorter (Y axis) and thicker (X/Z axes)
local SCALE_OVERALL = 1.8
local THICKEN = Vector3.new(1.8, 1.0, 1.8)
local FINAL_SCALE = Vector3.new(
	BASE_SCALE.X * THICKEN.X * SCALE_OVERALL,
	BASE_SCALE.Y * THICKEN.Y * SCALE_OVERALL,
	BASE_SCALE.Z * THICKEN.Z * SCALE_OVERALL
)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "IceCream_",
	dropGroup = "CinnamorollOrbs5",

	dropRate = 1.5,
	cashValue = 12,
	lifetime = 2000,

	size = Vector3.new(2, 2, 2), -- Compact collision
	color = Color3.new(1, 1, 1),
	material = Enum.Material.SmoothPlastic,
	transparency = 0,

	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://1486490132",
		textureId = "rbxassetid://1486490402",
		scale = FINAL_SCALE,
	},

	light = {
		brightness = 0.4,
		range = 6,
		color = Color3.new(1, 1, 1),
		spawnFlash = true,
		spawnBrightness = 1.2,
		flashDuration = 0.5,
	},

	spawn = {
		rotation = CFrame.Angles(math.rad(180), math.rad(180), 0),
		velocity = Vector3.new(0, -12, 0),
		randomOffset = Vector3.new(0.2, 0, 0.2),
	},
	spawnYOffset = -2,

	animation = {
		mesh = {
			startScale = FINAL_SCALE * 0.5,
			endScale = FINAL_SCALE,
			duration = 0.5,
			style = Enum.EasingStyle.Back,
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
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 1)
			}),
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			emit = 1,
			autoDestroy = true,
			lifetime = 1,
		},
	},

	density = 0.3,
	friction = 0.5,
	elasticity = 0.1,
})
