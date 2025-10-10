--[[ 
  Kuromi Dropper 5 – Witch Hat (small)
  Mesh: rbxassetid://12396936150
  Texture: rbxassetid://12396936197
  Visual shrink via mesh.Scale (Part.Size is hitbox only)
  Cash: 12  |  Rate: 1.5s
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)

-- Author scale of this hat is huge; keep this tiny
local BASE_SCALE = Vector3.new(1.177, 2.512, 1.164)
local SCALE_OVERALL = 0.065            -- tweak smaller/bigger here (0.04–0.08 typical)
local THICKEN      = Vector3.new(1.0, 0.60, 1.0)  -- a bit shorter on Y

local FINAL_SCALE = Vector3.new(
	BASE_SCALE.X * THICKEN.X * SCALE_OVERALL,
	BASE_SCALE.Y * THICKEN.Y * SCALE_OVERALL,
	BASE_SCALE.Z * THICKEN.Z * SCALE_OVERALL
)

-- Physics hitbox (not visual size)
local PART_SIZE = Vector3.new(0.9, 0.9, 0.9)

Core.Run({
	-- Required refs
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	-- Identity
	namePrefix = "WitchHat_",
	dropGroup  = "Dropper5Orbs",   -- Core prevents collisions with players & other drops

	-- Economy / timing
	dropRate  = 1.5,
	cashValue = 12,
	lifetime  = 2000,

	-- Base part (hitbox)
	size         = PART_SIZE,
	color        = Color3.new(1, 1, 1),
	material     = Enum.Material.SmoothPlastic,
	transparency = 0,              -- use fade tween only if >0

	-- Witch hat visual
	mesh = {
		meshId   = "rbxassetid://12396936150",
		textureId= "rbxassetid://12396936197",
		scale    = FINAL_SCALE,
	},

	-- Light & spawn flash
	light = {
		brightness      = 0.7,
		range           = 6,
		color           = Color3.new(1, 1, 1),
		spawnFlash      = true,
		spawnBrightness = 2.2,
		flashDuration   = 0.5,
	},

	-- Spawn motion
	spawn = {
		rotation        = CFrame.Angles(0, 0, 0),
		velocity        = Vector3.new(0, -8, 0),
		angularVelocity = Vector3.new(0, 0, 0),
	},
	spawnYOffset = -2.2,

	-- Mesh pop-in anim
	animation = {
		mesh = {
			startScale = FINAL_SCALE * 0.5,
			endScale   = FINAL_SCALE,
			duration   = 0.35,
			style      = Enum.EasingStyle.Back,
		},
	},

	-- Optional spawn ring burst
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

	-- Physics
	density     = 0.1,
	friction    = 0.3,
	elasticity  = 0,
	fadeTime    = 0.3,

	-- Collectors (kept default, works with your setup)
	collectorNames = {"Collector","CollectorZone","Receiver","Sell","SellPad"},
	collectorTags  = {"Collector","SellZone"},
})
