--[[
	HelloKitty Dropper 5 - ULTIMATE ANTI-TIP FIX
	✅ Uses HelloKitty2 model from ReplicatedStorage
	✅ AlignOrientation keeps it 100% upright
	✅ Heavy + invisible wide base = CANNOT tip over
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)
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
	extraLower = 0.0,  -- FIXED: Don't lower at all = won't embed in ground
	yawDegrees = 180,  -- ✅ Face the other way!

	-- Animation
	fadeTime = 0.35,
	prewarm = 0,

	-- Physics - SUPER HEAVY!
	density = 5.0,     -- VERY HEAVY = stable
	friction = 1.0,    -- MAX friction
	elasticity = 0.0,  -- No bounce

	-- 🎯 ULTIMATE ANTI-TIP SYSTEM (STRONGER!)
	onSpawn = function(model, primary, group)
		-- 1. MASSIVE invisible stabilizer base (won't tip!)
		local base = Instance.new("Part")
		base.Name = "StabilizerBase"
		base.Size = Vector3.new(5, 0.4, 5)  -- ✅ HUGE 5x5 base!
		base.Transparency = 1
		base.Anchored = false
		base.CanCollide = true
		base.CanTouch = false
		base.Massless = false
		base.Material = Enum.Material.SmoothPlastic
		
		-- Position below the model
		local extents = model:GetExtentsSize()
		base.CFrame = primary.CFrame * CFrame.new(0, -(extents.Y/2) - 0.15, 0)
		
		pcall(function() base.CollisionGroup = group end)
		base.CustomPhysicalProperties = PhysicalProperties.new(20, 1.0, 0, 1, 1)  -- ✅ SUPER HEAVY!
		base.Parent = model

		-- Weld base to primary
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = primary
		weld.Part1 = base
		weld.Parent = primary

		-- 2. DUAL LOCK SYSTEM - AlignOrientation + BodyGyro!
		local att = Instance.new("Attachment")
		att.Name = "UprightAttachment"
		att.Parent = primary

		local align = Instance.new("AlignOrientation")
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = att
		align.RigidityEnabled = true
		align.MaxTorque = 1000000  -- ✅ DOUBLED strength!
		align.Responsiveness = 200  -- ✅ INSTANT snap back!
		align.CFrame = CFrame.new(0, 0, 0)  -- Locked upright
		align.Parent = primary
		
		-- 3. BodyGyro backup (extra insurance!)
		local gyro = Instance.new("BodyGyro")
		gyro.MaxTorque = Vector3.new(500000, 0, 500000)  -- Lock X and Z rotation
		gyro.P = 10000  -- Very strong
		gyro.D = 1000   -- Strong damping
		gyro.CFrame = CFrame.new()  -- Upright
		gyro.Parent = primary
	end,

	-- Collection
	cashOn = "primary",
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags = {"Collector", "SellZone"},
})
