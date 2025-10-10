--[[
	Kuromi Dropper 5 - Witch Hat Style
	✅ Uses witch hat mesh with proper scaling
	✅ FIXED: Much smaller visual + hitbox size
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Calculate final mesh scale using your formula
local BASE_SCALE = Vector3.new(1.177, 2.512, 1.164)
local SCALE_OVERALL = 0.28         -- was 1.8 (WAY smaller now!)
local THICKEN = Vector3.new(1.1, 0.75, 1.1)  -- slightly thicker, shorter height

local FINAL_SCALE = Vector3.new(
	BASE_SCALE.X * THICKEN.X * SCALE_OVERALL,
	BASE_SCALE.Y * THICKEN.Y * SCALE_OVERALL,
	BASE_SCALE.Z * THICKEN.Z * SCALE_OVERALL
)

-- Smaller hitbox (was 2, 2, 2)
local PART_SIZE = Vector3.new(1, 1, 1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "WitchHat_",
	dropGroup = "Dropper5Orbs",

	dropRate = 1.5,
	cashValue = 12,
	lifetime = 2000,

	size = PART_SIZE,  -- Smaller hitbox for better physics
	color = Color3.new(1, 1, 1),
	material = Enum.Material.SmoothPlastic,

	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://12396936150",
		textureId = "rbxassetid://12396936197",
		scale = FINAL_SCALE,  -- Calculated proper scale
		offset = Vector3.new(0, 0.35, 0), -- ✅ Lift mesh so it doesn't sink into conveyor
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
	spawnYOffset = -1.6, -- ✅ Raised from -2.5 to avoid touching conveyor

	animation = {
		mesh = {
			startScale = FINAL_SCALE * 0.5,  -- Starts at 50% of final
			endScale = FINAL_SCALE,          -- Tweens to final scale
			duration = 0.4,
			style = Enum.EasingStyle.Back,
		},
	},

	fadeTime = 0.3,
	density = 0.1,
	friction = 0.3,
	elasticity = 0,
})
