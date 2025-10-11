-- Workspace.Dropper1.Script (Server Script)
-- Updated to use Core.Run() instead of deprecated Core.RunModel()

local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

task.wait(1)

-- Using the new Core.Run() with proper configuration
Core.Run({
	-- Required parameters
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	
	-- Basic configuration
	namePrefix = "Drop_",
	dropGroup = "Drops",
	playerGroup = "Players",
	dropRate = 1.2,
	cashValue = 10,
	lifetime = nil, -- keep until collected (will use default 120 if nil)
	
	-- Part properties
	size = Vector3.new(1, 1, 1), -- Adjust as needed based on your drop size
	color = Color3.new(1, 0.8, 0.9), -- Light pink color for Hello Kitty theme
	material = Enum.Material.Neon, -- Makes it glow nicely
	shape = Enum.PartType.Ball, -- Round shape
	
	-- Physics properties
	density = 0.7,
	friction = 0.3,
	elasticity = 0.05,
	
	-- Visual properties
	reflectance = 0.2,
	transparency = 0.2, -- Slightly transparent
	fadeTime = 0.35,
	
	-- Spawn configuration
	spawnYOffset = -2.5,
	spawn = {
		rotation = CFrame.Angles(0, math.rad(-90), 0), -- Convert yawDegrees to rotation
		velocity = Vector3.new(0, -8, 0),
		angularVelocity = Vector3.new(0, 0, 0)
	},
	
	-- Animation configuration
	animation = {
		pop = true,
		popStartSize = Vector3.new(0.1, 0.1, 0.1),
		popDuration = 0.2,
		popStyle = Enum.EasingStyle.Back
	},
	
	-- Light configuration for glowing effect
	light = {
		brightness = 2,
		range = 10,
		color = Color3.fromRGB(255, 182, 193), -- Light pink glow
		spawnFlash = true,
		spawnBrightness = 5,
		flashDuration = 0.6,
		collectBrightness = 3
	},
	
	-- Optional: Add particles for sparkle effect
	particles = {
		{
			Rate = 5,
			Lifetime = NumberRange.new(1, 2),
			SpreadAngle = Vector2.new(10, 10),
			VelocityInheritance = 0.5,
			EmissionDirection = Enum.NormalId.Top,
			Speed = NumberRange.new(2, 4),
			Drag = 1,
			Acceleration = Vector3.new(0, -5, 0),
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 182, 193)),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(0.5, 0.3),
				NumberSequenceKeypoint.new(1, 0)
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.8, 0.3),
				NumberSequenceKeypoint.new(1, 1)
			}),
			LightEmission = 1,
			LightInfluence = 0
		}
	},
	
	-- Spawn particles (one-time burst when drop spawns)
	spawnParticles = {
		{
			Rate = 0,
			Lifetime = NumberRange.new(0.5, 1),
			SpreadAngle = Vector2.new(360, 360),
			VelocityInheritance = 0,
			EmissionDirection = Enum.NormalId.Top,
			Speed = NumberRange.new(5, 10),
			Drag = 3,
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 182, 193)),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0)
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1)
			}),
			LightEmission = 1,
			emit = 10, -- Emit 10 particles on spawn
			autoDestroy = true,
			lifetime = 1
		}
	},
	
	-- Collector configuration
	collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
	collectorTags = { "Collector", "SellZone" }
})