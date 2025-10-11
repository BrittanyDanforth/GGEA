--[[
	Kuromi Dropper 5 – Witch Hat (FIXED - won't fall through map!)
	✅ Uses cubic hitbox (no rolling)
	✅ Fixed spawn height to prevent falling through
	✅ Heavier physics for stability
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)

local BASE_SCALE   = Vector3.new(1.177, 2.512, 1.164)
local SCALE_OVERALL = 0.065
local THICKEN       = Vector3.new(1.0, 0.60, 1.0)

local FINAL_SCALE = Vector3.new(
	BASE_SCALE.X * THICKEN.X * SCALE_OVERALL,
	BASE_SCALE.Y * THICKEN.Y * SCALE_OVERALL,
	BASE_SCALE.Z * THICKEN.Z * SCALE_OVERALL
)

-- Changed shape to cube, a little taller to feel balanced
local PART_SIZE = Vector3.new(0.9, 0.8, 0.9)

Core.Run({
	model       = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "WitchHat_",
	dropGroup  = "Dropper5Orbs",

	dropRate  = 1.5,
	cashValue = 12,
	lifetime  = 2000,

	size         = PART_SIZE,
	color        = Color3.new(1, 1, 1),
	material     = Enum.Material.SmoothPlastic,
	shape        = Enum.PartType.Block,  -- ✅ square hitbox, no spin
	transparency = 0,

	mesh = {
		meshId    = "rbxassetid://12396936150",
		textureId = "rbxassetid://12396936197",
		scale     = FINAL_SCALE,
	},

	light = {
		brightness      = 0.7,
		range           = 6,
		color           = Color3.new(1, 1, 1),
		spawnFlash      = true,
		spawnBrightness = 2.2,
		flashDuration   = 0.5,
	},

	spawn = {
		rotation        = CFrame.Angles(math.rad(8), math.rad(10), math.rad(4)),
		velocity        = Vector3.new(0, -8, 0),
		angularVelocity = Vector3.new(0, 1.2, 0),
	},
	spawnYOffset = -0.5,  -- FIXED: Less negative = won't fall through map!

	animation = {
		mesh = {
			startScale = FINAL_SCALE * 0.5,
			endScale   = FINAL_SCALE,
			duration   = 0.35,
			style      = Enum.EasingStyle.Back,
		},
	},

	spawnParticles = {
		{
			Texture = "rbxassetid://262979222",
			Rate = 0, Speed = NumberRange.new(0), Lifetime = NumberRange.new(0.35),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.12),
				NumberSequenceKeypoint.new(1, 1.8),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			emit = 1, autoDestroy = true, lifetime = 1,
		},
	},

	density     = 0.3,   -- FIXED: Heavier = won't phase through!
	friction    = 0.5,   -- More friction for stability
	elasticity  = 0.05,
	fadeTime    = 0.3,

	collectorNames = {"Collector","CollectorZone","Receiver","Sell","SellPad"},
	collectorTags  = {"Collector","SellZone"},
})
