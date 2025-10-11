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
	extraLower = 0.5,  -- Lower to ground for stability
	yawDegrees = 0,  -- Upright, no rotation

	-- Animation
	fadeTime = 0.35,
	prewarm = 0,

	-- Physics - HEAVY AND STABLE!
	density = 1.5,  -- Much heavier = won't tip over!
	friction = 0.8,  -- High friction = grips ground!
	elasticity = 0.0,  -- No bounce = stays put!

	-- Collection
	cashOn = "primary",
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags = {"Collector", "SellZone"},
	
	-- 🎯 KEEP UPRIGHT CALLBACK - Prevents tipping on conveyor!
	onSpawn = function(model)
		local primary = model.PrimaryPart
		if not primary then return end
		
		-- Add attachment for AlignOrientation
		local att = Instance.new("Attachment")
		att.Name = "StandUpright"
		att.Parent = primary
		
		-- Keep it standing upright ALWAYS (even on conveyor!)
		local alignOrientation = Instance.new("AlignOrientation")
		alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOrientation.Attachment0 = att
		alignOrientation.RigidityEnabled = true
		alignOrientation.MaxTorque = 50000  -- Strong enough to resist conveyor!
		alignOrientation.Responsiveness = 40  -- Fast correction
		alignOrientation.CFrame = CFrame.new(0, 0, 0)  -- Keep upright (no rotation)
		alignOrientation.Parent = primary
	end,
})
