-- Workspace.Dropper1.Script (Server Script)
-- Version with custom mesh support for Hello Kitty or other custom models

local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

task.wait(1)

-- Using Core.Run() with custom mesh configuration
Core.Run({
	-- Required parameters
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	
	-- Basic configuration
	namePrefix = "HelloKitty_",
	dropGroup = "Drops",
	playerGroup = "Players",
	dropRate = 1.2,
	cashValue = 10,
	lifetime = nil, -- keep until collected (will use default 120 if nil)
	
	-- Part properties (base part that holds the mesh)
	size = Vector3.new(2, 2, 2), -- Size of the collision box
	color = Color3.new(1, 1, 1), -- White base color
	material = Enum.Material.ForceField, -- Gives a nice effect
	shape = Enum.PartType.Block, -- Shape doesn't matter with mesh
	
	-- Mesh configuration (for custom Hello Kitty model)
	mesh = {
		meshType = Enum.MeshType.FileMesh,
		-- Example mesh IDs - replace with your actual Hello Kitty mesh
		meshId = "rbxassetid://YOUR_HELLOKITTY_MESH_ID", -- Replace with actual mesh ID
		textureId = "rbxassetid://YOUR_HELLOKITTY_TEXTURE_ID", -- Replace with actual texture ID
		scale = Vector3.new(0.9, 0.9, 0.9) -- Scale factor from original config
	},
	
	-- Physics properties
	density = 0.7,
	friction = 0.3,
	elasticity = 0.05,
	
	-- Visual properties
	reflectance = 0,
	transparency = 0,
	fadeTime = 0.35,
	
	-- Spawn configuration
	spawnYOffset = -2.5 - 0.45, -- Includes extraLower from original
	spawn = {
		rotation = CFrame.Angles(0, math.rad(-90), 0), -- yawDegrees conversion
		velocity = Vector3.new(0, -8, 0),
		angularVelocity = Vector3.new(0, 2, 0) -- Slight spin
	},
	
	-- Animation configuration with mesh scaling
	animation = {
		pop = true,
		popStartSize = Vector3.new(0.1, 0.1, 0.1),
		popDuration = 0.2,
		popStyle = Enum.EasingStyle.Back,
		
		-- Mesh-specific animation
		mesh = {
			startScale = Vector3.new(0.1, 0.1, 0.1),
			endScale = Vector3.new(0.9, 0.9, 0.9), -- Final scale
			duration = 0.3,
			style = Enum.EasingStyle.Back
		}
	},
	
	-- Light configuration for collection effect
	light = {
		brightness = 1.5,
		range = 8,
		color = Color3.fromRGB(255, 105, 180), -- Hot pink for Hello Kitty
		spawnFlash = true,
		spawnBrightness = 3,
		flashDuration = 0.6,
		collectBrightness = 4
	},
	
	-- Sparkle particles
	particles = {
		{
			Rate = 3,
			Lifetime = NumberRange.new(1, 2),
			SpreadAngle = Vector2.new(15, 15),
			VelocityInheritance = 0.5,
			EmissionDirection = Enum.NormalId.Top,
			Speed = NumberRange.new(1, 3),
			Drag = 1,
			Acceleration = Vector3.new(0, -3, 0),
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 105, 180)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 182, 193)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
			}),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(0.5, 0.4),
				NumberSequenceKeypoint.new(1, 0)
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(0.8, 0.5),
				NumberSequenceKeypoint.new(1, 1)
			}),
			LightEmission = 1,
			LightInfluence = 0,
			RotSpeed = NumberRange.new(-180, 180),
			Rotation = NumberRange.new(0, 360)
		}
	},
	
	-- Spawn burst effect
	spawnParticles = {
		{
			Rate = 0,
			Lifetime = NumberRange.new(0.8, 1.2),
			SpreadAngle = Vector2.new(360, 360),
			VelocityInheritance = 0,
			EmissionDirection = Enum.NormalId.Top,
			Speed = NumberRange.new(8, 15),
			Drag = 4,
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 105, 180)),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.5),
				NumberSequenceKeypoint.new(0.5, 0.8),
				NumberSequenceKeypoint.new(1, 0)
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.7, 0.3),
				NumberSequenceKeypoint.new(1, 1)
			}),
			LightEmission = 1,
			LightInfluence = 0,
			emit = 15, -- Burst of 15 particles
			autoDestroy = true,
			lifetime = 1.5
		}
	},
	
	-- Collector configuration
	collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
	collectorTags = { "Collector", "SellZone" }
})

--[[
	NOTES FOR USING CUSTOM MESH:
	
	1. Replace YOUR_HELLOKITTY_MESH_ID with the actual asset ID of your Hello Kitty mesh
	   Example: "rbxassetid://123456789"
	   
	2. Replace YOUR_HELLOKITTY_TEXTURE_ID with the actual texture asset ID
	   Example: "rbxassetid://987654321"
	   
	3. If you don't have a custom mesh, you can:
	   - Use the first version (Dropper1_Script.lua) which creates simple glowing orbs
	   - Search for free Hello Kitty meshes in the Roblox library
	   - Create your own mesh in Blender and upload it to Roblox
	
	4. The scaleFactor from the original config (0.9) is applied in the mesh.scale property
	
	5. The extraLower value (0.45) is added to the spawnYOffset to lower the spawn point
]]