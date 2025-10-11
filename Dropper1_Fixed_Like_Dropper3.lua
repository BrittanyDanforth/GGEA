-- Workspace.Dropper1.Script (Server Script)
-- Fixed to work exactly like Dropper3 using Core.Run()

local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

task.wait(1)

-- Using Core.Run() with exact Dropper3 configuration
Core.Run({
	-- Required parameters
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	
	-- Naming and grouping (HelloKittyDrops1 for Dropper1)
	namePrefix = "PremiumHK_",
	dropGroup = "HelloKittyDrops1", -- Unique group for Dropper1
	playerGroup = "Players",
	
	-- Timing (exactly like Dropper3)
	dropRate = 0.6,
	lifetime = 180, -- 3 minutes
	
	-- Part properties (exact match to Dropper3)
	size = Vector3.new(1.817, 1.323, 0.281),
	color = Color3.fromRGB(151, 0, 0), -- Dark red
	material = Enum.Material.SmoothPlastic,
	shape = Enum.PartType.Block,
	
	-- Visual properties
	transparency = 0.7, -- Start at 0.7, will fade to 0
	reflectance = 0,
	fadeTime = 0.4,
	
	-- Hello Kitty Mesh (exact mesh from Dropper3)
	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://3071180788",
		textureId = "", -- No texture
		scale = Vector3.new(1, 1, 1) -- Initial scale
	},
	
	-- Physics (exact values from Dropper3)
	density = 0.2,
	friction = 0.4,
	elasticity = 0.3,
	
	-- Spawn configuration (matching Dropper3 exactly)
	spawnYOffset = -1.75,
	spawn = {
		rotation = CFrame.Angles(math.rad(70), math.rad(0), math.rad(180)),
		velocity = Vector3.new(0, -10, 0) -- Base velocity
	},
	randomVelocity = true, -- Enable random X/Z velocity based on offset
	
	-- Animation (matching Dropper3's tweens)
	animation = {
		pop = false, -- Disable part size animation
		mesh = {
			startScale = Vector3.new(1, 1, 1),
			endScale = Vector3.new(4, 4, 4), -- Scale to 4x
			duration = 0.4,
			style = Enum.EasingStyle.Back
		}
	},
	
	-- Light configuration (exact pink glow from Dropper3)
	light = {
		brightness = 1,
		range = 8,
		color = Color3.fromRGB(255, 100, 150), -- Pink glow
		spawnFlash = true,
		spawnBrightness = 2,
		flashDuration = 0.6
	},
	
	-- Cash value (from your original Dropper1 config)
	cashValue = 10,
	
	-- Add spawn time attribute like Dropper3
	addSpawnTime = true,
	
	-- Collector configuration
	collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
	collectorTags = { "Collector", "SellZone" }
})

--[[
	✅ EXACT MATCH TO DROPPER3:
	- Same Hello Kitty mesh (3071180788)
	- Same dark red color (151, 0, 0)
	- Same transparency fade (0.7 → 0)
	- Same mesh scale animation (1x → 4x)
	- Same pink glow effect
	- Same physics properties (0.2, 0.4, 0.3)
	- Same spawn rotation (70°, 0°, 180°)
	- Same spawn offset (-1.75)
	- Same drop rate (0.6 seconds)
	- Same lifetime (180 seconds)
	
	The only differences:
	- Uses "HelloKittyDrops1" collision group (unique for Dropper1)
	- Cash value is 10 instead of 50 (from your original config)
	- Uses DropperCore module instead of inline code
]]