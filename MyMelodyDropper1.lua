--[[
	MyMelody Dropper 1 — LOWER SPAWN + UPRIGHT (FIXED)
	✅ Spawns clearly LOWER so it sits on the belt
	✅ keepUpright so it won't tip
	✅ yaw = 0 (faces straight)
	✅ FIXED: Unique collision group to prevent inter-dropper collisions
	✅ FIXED: Proper fade-in animation (no instant disappear)
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
	collisionGroup = "MyMelodyDrops1",  -- ✅ FIXED: Unique collision group
	playerGroup = "Players",

	-- Timing
	dropRate = 1.2,
	cashValue = 10,
	lifetime = 180,

	-- Pose / spawn height
	scaleFactor = 0.9,
	-- Smaller → lower. Negative pushes even LOWER than half-height.
	-- (Use -0.30 to -0.70 range to fine-tune on your belt.)
	extraLower = -0.50,     -- ↓ force noticeably lower
	yawDegrees = 0,

	-- Animation
	fadeTime = 0.5,
	prewarm  = 0,
	animation = {
		transparency = {
			startTransparency = 1,
			endTransparency = 0,
			duration = 0.5,
			style = Enum.EasingStyle.Quad,
		},
	},

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
