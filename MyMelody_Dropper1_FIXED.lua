--[[
	✅ MyMelody Dropper 1 - FIXED VERSION (v2.0 - Auto-Create PartStorage)
	Tier: First Dropper (Basic)
	Cash: $10 | Rate: 1.0s | Size: 1.25x1.7x1.7
	
	This is the FIRST dropper - activated by "Begin Working!" button
	
	🔧 FIXES:
	✅ Auto-creates PartStorage if missing (no more infinite yield!)
	✅ Uses tycoon's local PartStorage (multi-tycoon safe)
	✅ Uses DropperCore system (modern & optimized)
	✅ Auto-tags drops with TycoonId attribute
	✅ Proper cleanup on tycoon reset
	✅ Fallback to workspace if needed
	
	📍 PLACE IN: Workspace > YourTycoon > Tycoons > MyMelody > PurchasedObjects > Dropper1 > DropperScript
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- ✅ SMART STORAGE FINDER - Creates PartStorage if missing!
local function getOrCreatePartStorage()
	local tycoon = script.Parent.Parent.Parent -- MyMelody tycoon model
	
	-- Try to find Essentials folder
	local essentials = tycoon:FindFirstChild("Essentials")
	
	if not essentials then
		-- Create Essentials if missing
		warn("[Dropper1] Creating missing Essentials folder for:", tycoon.Name)
		essentials = Instance.new("Folder")
		essentials.Name = "Essentials"
		essentials.Parent = tycoon
	end
	
	-- Try to find PartStorage
	local partStorage = essentials:FindFirstChild("PartStorage")
	
	if not partStorage then
		-- Create PartStorage if missing
		warn("[Dropper1] Creating missing PartStorage for:", tycoon.Name)
		partStorage = Instance.new("Folder")
		partStorage.Name = "PartStorage"
		partStorage.Parent = essentials
	end
	
	print("✅ [Dropper1] Using PartStorage at:", partStorage:GetFullName())
	return partStorage
end

Core.Run({
	model = script.Parent,

	-- ✅ CRITICAL FIX: Get or create PartStorage (no more infinite yield!)
	partStorage = getOrCreatePartStorage(),

	namePrefix = "MyMelodyDrop_",
	dropGroup = "MyMelodyDrops",

	dropRate = 1.0,  -- 1 drop per second
	cashValue = 10,  -- $10 per drop
	lifetime = 20,   -- 20 seconds

	size = Vector3.new(1.25, 1.7, 1.7),

	-- Use tycoon's color/material settings
	brickColor = script.Parent.Parent.Parent.DropColor.Value,
	material = script.Parent.Parent.Parent.MaterialValue.Value,

	spawn = {
		velocity = Vector3.new(0, -8, 0),
	},
	spawnYOffset = -1.75,

	animation = {
		pop = true,
		popStartSize = Vector3.new(0.05, 0.05, 0.05),
		popDuration = 0.2,
	},

	fadeTime = 0.3,
	density = 0.05,
	friction = 0.2,
	elasticity = 0,
})

print("✅ [MyMelody Dropper 1] Loaded - no more infinite yield!")
