--[[
	MyMelody Dropper 4 — 15% BIGGER VERSION
	✅ Scaled up ~15% (looks chunkier/cuter)
	✅ Hitbox also scaled so physics still matches
	✅ Raised spawn so feet don't sink
	✅ Still same drop group / behavior
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(0.5)

-- Prevent double-starts
if script.Parent:GetAttribute("DropperRunning") then
	return
end
script.Parent:SetAttribute("DropperRunning", true)

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "MyMelodyDrop4_",
	dropGroup = "MyMelodyDrops1", -- same group as Dropper1/2/3
	playerGroup = "Players",

	-- Timing
	dropRate = 1.2,
	cashValue = 20,
	lifetime = 180,

	-- Part properties
	-- hitbox scaled up 15% too so it still matches mesh
	size = Vector3.new(0.92, 0.92, 0.92),
	color = Color3.fromRGB(255, 192, 203),
	material = Enum.Material.SmoothPlastic,
	transparency = 0,

	-- No glow/light aura
	light = false,

	-- Mesh configuration (visual look)
	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://11816850109",      -- MyMelody mesh
		textureId = "rbxassetid://11816850135",   -- MyMelody texture
		scale = Vector3.new(0.69, 0.69, 0.69),    -- was 0.6, now ~15% bigger
		offset = Vector3.new(0, 0, 0),
	},

	-- Spawn settings (upright)
	spawn = {
		rotation = CFrame.Angles(0, 0, 0),
		velocity = Vector3.new(0, -10, 0),
	},

	-- slight raise because she's larger now so feet don't clip
	-- was -1.7, now -1.65
	spawnYOffset = -1.65,

	-- Animation
	fadeTime = 0.5,
	animation = {
		pop = true,
		popStartSize = Vector3.new(0.1, 0.1, 0.1),
		popDuration = 0.5,
		popStyle = Enum.EasingStyle.Elastic,
		mesh = {
			startScale = Vector3.new(0.3, 0.3, 0.3),
			endScale   = Vector3.new(0.69, 0.69, 0.69), -- match new final size
			duration   = 0.6,
			style      = Enum.EasingStyle.Elastic,
		},
	},

	-- Physics
	density = 0.8,
	friction = 0.18,
	elasticity = 0.03,

	-- Collection
	cashOn = "primary",
	collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
	collectorTags  = {"Collector", "SellZone"},
})
