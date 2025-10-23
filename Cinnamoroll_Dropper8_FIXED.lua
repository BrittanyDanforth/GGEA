--[[
  ✅ Cinnamoroll Dropper 8 — FIXED VERSION (v2.0 - Auto-Create PartStorage)
  Mesh: rbxassetid://1782118851 | Texture: rbxassetid://1782124333
  
  🔧 FIXES:
  ✅ Auto-creates PartStorage if missing (no more infinite yield!)
  ✅ Uses tycoon's local PartStorage (multi-tycoon safe)
  ✅ Uses DropperCore system (modern & optimized)
  ✅ 50% SMALLER mesh scale
  
  📍 PLACE IN: Workspace > YourTycoon > Tycoons > Cinnamoroll > PurchasedObjects > Dropper8 > DropperScript
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)
task.wait(1)

-- === SIZE CONTROLS ===
local BASE_VISIBLE_SCALE = 0.08      -- what you had
local VISUAL_SHRINK      = 0.4       -- 50% smaller (change to 0.6/0.7 if you want slightly larger)
local VISIBLE_SCALE      = BASE_VISIBLE_SCALE * VISUAL_SHRINK

-- keep it a touch flatter on Y so it looks chunky/cute
local SCALE = Vector3.new(VISIBLE_SCALE, VISIBLE_SCALE * 0.9, VISIBLE_SCALE)

-- If you want physics to also be smaller, set to 0.5. Leave at 1.0 to keep current hitbox.
local HITBOX_SHRINK = 1.0

local CASHMERE   = BrickColor.new("Cashmere").Color -- [211,190,150]
local HITBOX_BASE = Vector3.new(1.33, 1.276, 1.286) -- from your inspector
local HITBOX_SIZE = Vector3.new(
	HITBOX_BASE.X * HITBOX_SHRINK,
	HITBOX_BASE.Y * HITBOX_SHRINK,
	HITBOX_BASE.Z * HITBOX_SHRINK
)

-- ✅ SMART STORAGE FINDER - Creates PartStorage if missing!
local function getOrCreatePartStorage()
	local tycoon = script.Parent.Parent.Parent -- Cinnamoroll tycoon model
	
	local essentials = tycoon:FindFirstChild("Essentials")
	if not essentials then
		essentials = Instance.new("Folder")
		essentials.Name = "Essentials"
		essentials.Parent = tycoon
	end
	
	local partStorage = essentials:FindFirstChild("PartStorage")
	if not partStorage then
		partStorage = Instance.new("Folder")
		partStorage.Name = "PartStorage"
		partStorage.Parent = essentials
	end
	
	return partStorage
end

Core.Run({
	model = script.Parent,
	partStorage = getOrCreatePartStorage(),  -- ✅ No more infinite yield!

	namePrefix = "Drop8_",
	dropGroup  = "CinnamorollOrbs8",

	dropRate  = 0.5,
	cashValue = 100,
	lifetime  = 2000,

	-- Hitbox & visuals
	size         = HITBOX_SIZE,
	color        = CASHMERE,
	material     = Enum.Material.SmoothPlastic,
	transparency = 0,

	mesh = {
		meshType  = Enum.MeshType.FileMesh,
		meshId    = "rbxassetid://1782118851",
		textureId = "rbxassetid://1782124333",
		scale     = SCALE,                -- ✅ 50% smaller visual mesh
	},

	light = {
		brightness      = 1.2,
		range           = 8,
		color           = Color3.fromRGB(170, 210, 255),
		spawnFlash      = true,
		spawnBrightness = 2.0,
		flashDuration   = 0.45,
	},

	spawn = {
		rotation     = CFrame.Angles(0, math.rad(90.006), 0), -- ~90° Y as in your part
		velocity     = Vector3.new(0, -12, 0),
		randomOffset = Vector3.new(0.2, 0, 0.2),
	},
	spawnYOffset = -0.6, -- adjust ± if you see clipping/floating

	animation = {
		mesh = {
			startScale = SCALE * 0.55,
			endScale   = SCALE,
			duration   = 0.45,
			style      = Enum.EasingStyle.Back,
		},
	},

	spawnParticles = {
		{
			Texture = "rbxassetid://262979222",
			Rate = 0, Speed = NumberRange.new(0),
			Lifetime = NumberRange.new(0.3),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 2.0),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0,   0.25),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1,   1.0),
			}),
			Color = ColorSequence.new(Color3.fromRGB(170, 210, 255)),
			emit = 1, autoDestroy = true, lifetime = 1,
		},
	},

	density    = 0.3,
	friction   = 0.5,
	elasticity = 0.1,
})

print("✅ [Cinnamoroll Dropper 8] Loaded - no more infinite yield!")
