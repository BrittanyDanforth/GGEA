--[[
	Hello Kitty Dropper 1 - Fixed Model Configuration
	✅ Uses Hello Kitty MODEL from ReplicatedStorage (not mesh)
	✅ Properly clones and drops the full model
	✅ Modernized configuration
]]

local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

task.wait(1)

-- Check if it should be RunModel for model-based drops
if Core.RunModel then
	-- Use the original RunModel approach for MODEL drops
	Core.RunModel({
		model         = script.Parent,
		partStorage   = workspace:WaitForChild("PartStorage"),
		templateModel = RS:WaitForChild("HelloKittyPL"),  -- The actual model to clone

		namePrefix    = "Drop_",
		dropGroup     = "Drops",
		playerGroup   = "Players",
		dropRate      = 1.2,
		cashValue     = 10,
		lifetime      = nil,           -- keep until collected

		scaleFactor   = 0.9,
		extraLower    = 0.45,
		fadeTime      = 0.35,
		yawDegrees    = -90,
		prewarm       = 8,
		cashOn        = "primary",     -- fastest

		density       = 0.7,
		friction      = 0.3,
		elasticity    = 0.05,

		collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
		collectorTags  = { "Collector", "SellZone" },
	})
else
	-- Fallback to Core.Run with model template mode
	Core.Run({
		model = script.Parent,
		partStorage = workspace:WaitForChild("PartStorage"),
		
		-- IMPORTANT: Tell it to use a model template, not create a part
		isModelDrop = true,  -- This flag tells it to clone models
		templateModel = RS:WaitForChild("HelloKittyPL"),
		
		-- Naming and groups
		namePrefix = "Drop_",
		dropGroup = "Drops",
		playerGroup = "Players",
		
		-- Timing
		dropRate = 1.2,
		cashValue = 10,
		lifetime = nil,  -- keep until collected (infinite lifetime)
		
		-- Scale configuration for the model
		modelScale = 0.9,  -- This scales the entire model
		
		-- Spawn configuration
		spawn = {
			rotation = CFrame.Angles(0, math.rad(-90), 0),
			velocity = Vector3.new(0, -12, 0),
		},
		spawnYOffset = -0.45,
		
		-- Animation for model
		animation = {
			pop = false,
			scale = {
				startScale = 0.9,
				endScale = 1,
				duration = 0.35,
				style = Enum.EasingStyle.Quad,
			},
		},
		fadeTime = 0.35,
		
		-- Prewarm
		prewarm = 8,
		
		-- Cash collection
		cashOn = "primary",
		
		-- Physics (applied to model's primary part)
		density = 0.7,
		friction = 0.3,
		elasticity = 0.05,
		
		-- Collectors
		collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
		collectorTags = { "Collector", "SellZone" },
	})
end