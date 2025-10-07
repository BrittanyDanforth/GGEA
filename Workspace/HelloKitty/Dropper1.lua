-- Workspace.HelloKitty.Dropper1.Script
-- Uses DropperCore.RunModel for synchronized multi-part fade and physics
local RS = game:GetService("ReplicatedStorage")
local Core = require(RS.Modules.DropperCore)

-- Allow world to settle
task.wait(1)

Core.RunModel({
	model = script.Parent,                                 -- your existing dropper model (kept)
	partStorage = workspace:WaitForChild("PartStorage"),  -- where spawned models go
	templateModel = RS:WaitForChild("HelloKittyPL"),      -- the model to clone per drop

	-- behavior
	namePrefix  = "HelloKitty_",
	dropGroup   = "HelloKittyDrops",
	dropRate    = 1.2,
	cashValue   = 10,
	lifetime    = nil,           -- no auto-despawn; collectors remove

	-- visuals/physics matching your spec
	scaleFactor = 0.9,           -- smaller
	extraLower  = 0.45,          -- spawn lower in world-Y
	fadeTime    = 0.5,           -- synced fades
	density     = 0.7,
	friction    = 0.3,
	elasticity  = 0.05,
	yawDegrees  = -90,           -- upright yaw only

	-- optional: override collector names/tags if different in this map
	collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
	collectorTags  = { "Collector", "SellZone" },
})
