--[[
	Hello Kitty Dropper 1 - Modernized Configuration
	✅ Uses Hello Kitty template model from ReplicatedStorage
	✅ Smooth fade-in, collision groups, spawn effects
	✅ Modernized to match Core.Run() structure
]]

local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

task.wait(1)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	
	-- Template model (for model-based drops instead of mesh)
	templateModel = RS:WaitForChild("HelloKittyPL"),
	
	-- Naming and groups
	namePrefix = "Drop_",
	dropGroup = "Drops",
	playerGroup = "Players",
	
	-- Timing
	dropRate = 1.2,
	cashValue = 10,
	lifetime = nil,  -- keep until collected (infinite lifetime)
	
	-- Spawn configuration
	spawn = {
		rotation = CFrame.Angles(0, math.rad(-90), 0),  -- Convert yawDegrees to rotation
		velocity = Vector3.new(0, -12, 0),  -- Standard drop velocity
	},
	spawnYOffset = -0.45,  -- Using extraLower as offset
	
	-- Animation
	animation = {
		pop = false,
		mesh = {
			startScale = Vector3.new(0.9, 0.9, 0.9),  -- Using scaleFactor
			endScale = Vector3.new(1, 1, 1),
			duration = 0.35,  -- Using fadeTime
			style = Enum.EasingStyle.Quad,
		},
	},
	fadeTime = 0.35,
	
	-- Prewarm setting (spawn initial drops)
	prewarm = 8,
	
	-- Cash collection mode
	cashOn = "primary",  -- fastest collection mode
	
	-- Physics properties
	density = 0.7,
	friction = 0.3,
	elasticity = 0.05,
	
	-- Light configuration (optional, adds visual appeal)
	light = {
		brightness = 0.3,
		range = 4,
		color = Color3.fromRGB(255, 182, 193),  -- Pink Hello Kitty theme
		spawnFlash = true,
		spawnBrightness = 1.2,
		flashDuration = 0.4,
		collectBrightness = 2.5,
	},
	
	-- Spawn particles (optional sparkle effect)
	spawnParticles = {
		{
			Texture = "rbxassetid://241650934",  -- Sparkle texture
			Rate = 0,
			Speed = NumberRange.new(0),
			Lifetime = NumberRange.new(0.3),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 1.5)
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 1)
			}),
			Color = ColorSequence.new(Color3.fromRGB(255, 182, 193)),
			emit = 1,
			autoDestroy = true,
			lifetime = 1,
		},
	},
	
	-- Collector configuration
	collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
	collectorTags = { "Collector", "SellZone" },
})