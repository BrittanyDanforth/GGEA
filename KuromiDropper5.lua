--[[ 
	Kuromi Dropper 5 - Witch Hat (SMALL + NO SINKING)
	✅ Proper visual size
	✅ Mesh offset so it doesn't sink into the conveyor
	✅ Cross-group non-colliding drops (via DropperCore)
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- final scale using your earlier formula (but small)
local BASE_SCALE = Vector3.new(1.177, 2.512, 1.164)
local SCALE_OVERALL = 0.28
local THICKEN = Vector3.new(1.1, 0.75, 1.1)

local FINAL_SCALE = Vector3.new(
	BASE_SCALE.X * THICKEN.X * SCALE_OVERALL,
	BASE_SCALE.Y * THICKEN.Y * SCALE_OVERALL,
	BASE_SCALE.Z * THICKEN.Z * SCALE_OVERALL
)

-- compact hitbox
local PART_SIZE = Vector3.new(1, 1, 1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "WitchHat_",
	dropGroup  = "Dropper5Orbs",

	dropRate   = 1.5,
	cashValue  = 12,
	lifetime   = 2000,

	size       = PART_SIZE,
	color      = Color3.new(1, 1, 1),
	material   = Enum.Material.SmoothPlastic,
	shape      = Enum.PartType.Block,
	transparency = 0, -- fade works from opaque

	-- ⭐ Mesh with vertical offset so it doesn't clip into the belt
	mesh = {
		meshType  = Enum.MeshType.FileMesh,
		meshId    = "rbxassetid://12396936150",
		textureId = "rbxassetid://12396936197",
		scale     = FINAL_SCALE,
		offset    = Vector3.new(0, 0.35, 0), -- raise visual ~0.35 studs (tweak 0.25–0.45)
	},

	light = {
		brightness = 1,
		range = 6,
		color = Color3.new(1, 1, 1),
		spawnFlash = true,
		spawnBrightness = 2,
		flashDuration = 0.6,
	},

	spawn = {
		velocity = Vector3.new(0, -8, 0),
	},
	spawnYOffset = -1.6, -- was lower; raised to avoid touching conveyor

	animation = {
		mesh = {
			startScale = FINAL_SCALE * 0.5,
			endScale   = FINAL_SCALE,
			duration   = 0.4,
			style      = Enum.EasingStyle.Back,
		},
	},

	fadeTime   = 0.3,
	density    = 0.1,
	friction   = 0.3,
	elasticity = 0,
})
