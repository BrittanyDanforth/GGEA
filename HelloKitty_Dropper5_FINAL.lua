--[[
	HelloKitty Dropper 5 - Ice Cream Model Style
	✅ Uses HelloKitty2 model from ReplicatedStorage
	✅ Smooth fade-in, collision groups, spawn effects
	✅ Pink HelloKitty theme
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Prevent double-starts
if script.Parent:GetAttribute("DropperRunning") then return end
script.Parent:SetAttribute("DropperRunning", true)

Core.RunModel({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	templateModel = game.ReplicatedStorage:WaitForChild("HelloKitty2"),

	namePrefix = "IceCream_",
	dropGroup = "HelloKittyDrops5",
	playerGroup = "Players",

	-- Timing
	dropRate = 1.5,
	cashValue = 12,
	lifetime = 180,

	-- Scaling
	scaleFactor = 1.0,
	extraLower = 0.1,  -- FIXED: Less lower = won't fall through map!
	yawDegrees = 0,  -- Upright, no rotation

	-- Animation
	fadeTime = 0.35,
	prewarm = 0,

	-- Physics - ULTRA HEAVY AND STABLE!
	density = 3.0,  -- SUPER HEAVY = won't tip over AT ALL!
	friction = 1.0,  -- MAX friction = locked to ground!
	elasticity = 0.0,  -- No bounce = stays put!

	-- Collection
	cashOn = "primary",
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags = {"Collector", "SellZone"},
	
	-- 🎯 KEEP UPRIGHT - Prevents tipping on conveyor!
	keepUpright = true,  -- ✅ Plushies stay standing, won't tip over!
})
