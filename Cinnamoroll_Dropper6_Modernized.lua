--[[
	Cinnamoroll Dropper 6 - MODERNIZED Model Dropper
	✅ Uses DropperCore.RunModel() for CinnamonRoll model from ReplicatedStorage
	✅ Clean implementation with all the polish
	✅ Proper collision, fade, collection
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

Core.RunModel({
	-- Model references
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	templateModel = game.ReplicatedStorage:WaitForChild("CinnamonRoll"),

	namePrefix = "CinnamonRoll_",
	dropGroup = "CinnamorollOrbs6",

	-- Timing
	dropRate = 1.5,
	cashValue = 12,
	lifetime = 2000, -- Cleanup after 2000 seconds

	-- Scaling
	scaleFactor = 1.2, -- Make it 20% bigger
	extraLower = 0.35, -- How much to lower from pivot point

	-- Spawn settings
	yawDegrees = 0, -- Upright, no rotation
	prewarm = 0, -- No initial burst

	-- Animation
	fadeTime = 0.5,

	-- Physics
	density = 0.7,
	friction = 0.3,
	elasticity = 0.05,

	-- Cash placement: "primary" = only on PrimaryPart, "all" = on all parts
	cashOn = "all", -- Matches your original implementation

	-- Collision
	playerGroup = "Players",
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags = {"Collector", "SellZone"},
})
