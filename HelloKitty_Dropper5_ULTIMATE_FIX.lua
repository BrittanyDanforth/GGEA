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

	-- 🎯 ULTIMATE ANTI-TIP SYSTEM
	onSpawn = function(model, primary, group)
		-- 1. Invisible WIDE stabilizer base (like a tripod)
		local base = Instance.new("Part")
		base.Name = "StabilizerBase"
		base.Size = Vector3.new(4, 0.3, 4)  -- WIDE square base
		base.Transparency = 1
		base.Anchored = false
		base.CanCollide = true
		base.CanTouch = false
		base.Massless = false
		base.Material = Enum.Material.SmoothPlastic
		
		-- Position below the model
		local extents = model:GetExtentsSize()
		base.CFrame = primary.CFrame * CFrame.new(0, -(extents.Y/2) - 0.2, 0)
		
		pcall(function() base.CollisionGroup = group end)
		base.CustomPhysicalProperties = PhysicalProperties.new(10, 1, 0, 1, 1)  -- HEAVY base
		base.Parent = model

		-- Weld base to primary
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = primary
		weld.Part1 = base
		weld.Parent = primary

		-- 2. AlignOrientation - LOCKS rotation (better than BodyGyro!)
		local att = Instance.new("Attachment")
		att.Name = "UprightAttachment"
		att.Parent = primary

		local align = Instance.new("AlignOrientation")
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = att
		align.RigidityEnabled = true
		align.MaxTorque = 500000  -- EXTREMELY strong!
		align.Responsiveness = 100  -- INSTANT correction!
		align.CFrame = CFrame.new(0, 0, 0)  -- Locked upright
		align.Parent = primary
	end,

	-- Collection
	cashOn = "primary",
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags = {"Collector", "SellZone"},
})
