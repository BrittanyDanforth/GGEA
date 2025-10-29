--[[
	MyMelody Dropper 1 — LOWER SPAWN + UPRIGHT (FIXED FADE OUT!)
	✅ Spawns clearly LOWER so it sits on the belt
	✅ keepUpright so it won't tip
	✅ yaw = 0 (faces straight)
	✅ FADE OUT actually works now!
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(0.5)

-- Prevent double-starts
if script.Parent:GetAttribute("DropperRunning") then return end
script.Parent:SetAttribute("DropperRunning", true)

Core.RunModel({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),
	templateModel = game.ReplicatedStorage:WaitForChild("MyMelody1"),

	namePrefix = "MyMelodyDrop_",
	dropGroup = "MyMelodyDrops1",
	playerGroup = "Players",

	-- Timing
	dropRate = 1.2,
	cashValue = 10,
	lifetime = 180,

	-- Pose / spawn height
	scaleFactor = 0.9,
	extraLower = -0.50,     -- ↓ force noticeably lower
	yawDegrees = 0,

	-- Animation (FIXED: Fade now actually works!)
	fadeTime = 0.35,
	prewarm  = 0,

	-- Physics
	density = 0.8,          -- a bit heavier = steadier
	friction = 0.18,        -- less sticking on belt
	elasticity = 0.03,

	-- Stability
	keepUpright = true,

	-- Collection
	cashOn = "primary",
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags  = {"Collector", "SellZone"},
})
