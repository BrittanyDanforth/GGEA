-- Workspace.Dropper1.Script (Server Script)
-- Fixed version using Core.Run() with Hello Kitty mesh (like Dropper3)

local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

task.wait(1)

-- Using Core.Run() with Hello Kitty mesh configuration (matching Dropper3 style)
Core.Run({
	-- Required parameters
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	
	-- Drop identification
	namePrefix = "PremiumHK_",
	dropGroup = "HelloKittyDrops1", -- Unique group for Dropper1
	playerGroup = "Players",
	
	-- Timing
	dropRate = 0.6, -- Same as Dropper3
	lifetime = 180, -- 3 minutes like Dropper3
	
	-- Part properties (matching Dropper3)
	size = Vector3.new(1.817, 1.323, 0.281), -- Hello Kitty mesh base size
	color = Color3.fromRGB(151, 0, 0), -- Dark red like Dropper3
	material = Enum.Material.SmoothPlastic,
	shape = Enum.PartType.Block,
	
	-- Visual properties
	transparency = 0.7, -- Start transparent like Dropper3
	reflectance = 0,
	fadeTime = 0.4,
	
	-- Hello Kitty Mesh configuration
	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://3071180788", -- Hello Kitty mesh ID from Dropper3
		textureId = "", -- No texture, uses part color
		scale = Vector3.new(1, 1, 1) -- Initial scale
	},
	
	-- Physics properties (from Dropper3)
	density = 0.2,
	friction = 0.4,
	elasticity = 0.3,
	
	-- Spawn configuration
	spawnYOffset = -1.75, -- Same as Dropper3
	spawn = {
		rotation = CFrame.Angles(math.rad(70), math.rad(0), math.rad(180)), -- Same rotation as Dropper3
		velocity = Vector3.new(0, -10, 0), -- Downward velocity
		angularVelocity = Vector3.new(0, 0, 0)
	},
	
	-- Animation configuration (matching Dropper3)
	animation = {
		pop = false, -- Disable part size animation since we're using mesh scale
		mesh = {
			startScale = Vector3.new(1, 1, 1), -- Start at normal size
			endScale = Vector3.new(4, 4, 4), -- Scale up to 4x like Dropper3
			duration = 0.4,
			style = Enum.EasingStyle.Back
		}
	},
	
	-- Light configuration (Hello Kitty pink glow)
	light = {
		brightness = 1,
		range = 8,
		color = Color3.fromRGB(255, 100, 150), -- Pink glow from Dropper3
		spawnFlash = true,
		spawnBrightness = 2,
		flashDuration = 0.6,
		collectBrightness = 3
	},
	
	-- Cash value (from your original config)
	cashValue = 10,
	
	-- Collector configuration
	collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
	collectorTags = { "Collector", "SellZone" }
})

--[[
	This version matches your Dropper3 exactly:
	✅ Uses the same Hello Kitty mesh (3071180788)
	✅ Same dark red color (151, 0, 0)
	✅ Same transparency fade (0.7 to 0)
	✅ Same mesh scale animation (1x to 4x)
	✅ Same pink glow effect
	✅ Same physics properties
	✅ Same spawn rotation and velocity
	
	The only differences:
	- Uses "HelloKittyDrops1" collision group (unique for Dropper1)
	- Cash value is 10 (from your original config) instead of 50
	- Uses the DropperCore module instead of inline code
]]