--[[
	HelloKitty Dropper 1 - HelloKittyPL Model Style
	✅ Uses HelloKittyPL model from ReplicatedStorage
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
	templateModel = game.ReplicatedStorage:WaitForChild("HelloKittyPL"),

	namePrefix = "HelloKittyDrop_",
	dropGroup = "HelloKittyDrops1",
	playerGroup = "Players",

	-- Timing
	dropRate = 1.2,
	cashValue = 10,
	lifetime = 180,

	-- Scaling
	scaleFactor = 0.9,
	extraLower = 0.45,
	yawDegrees = -90,

	-- Animation
	fadeTime = 0.35,
	prewarm = 0,

	-- Physics
	density = 0.7,
	friction = 0.3,
	elasticity = 0.05,

	-- Collection
	cashOn = "primary",
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags = {"Collector", "SellZone"},
})
