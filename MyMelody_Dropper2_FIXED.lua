--[[
	✅ MyMelody Dropper 2 - FIXED VERSION (v2.0 - Auto-Create PartStorage)
	Tier: Basic Drop
	Cash: $30 | Rate: 1.0s | Size: 1.25x1.7x1.7
	
	🔧 FIXES:
	✅ Auto-creates PartStorage if missing (no more infinite yield!)
	✅ Uses tycoon's local PartStorage (multi-tycoon safe)
	✅ Uses DropperCore system (modern & optimized)
	✅ Auto-tags drops with TycoonId attribute
	✅ Proper cleanup on tycoon reset
	
	📍 PLACE IN: Workspace > YourTycoon > Tycoons > MyMelody > PurchasedObjects > Dropper2 > DropperScript
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- ✅ SMART STORAGE FINDER - Creates PartStorage if missing!
local function getOrCreatePartStorage()
	local tycoon = script.Parent.Parent.Parent -- MyMelody tycoon model
	
	local essentials = tycoon:FindFirstChild("Essentials")
	if not essentials then
		essentials = Instance.new("Folder")
		essentials.Name = "Essentials"
		essentials.Parent = tycoon
	end
	
	local partStorage = essentials:FindFirstChild("PartStorage")
	if not partStorage then
		partStorage = Instance.new("Folder")
		partStorage.Name = "PartStorage"
		partStorage.Parent = essentials
	end
	
	return partStorage
end

Core.Run({
	model = script.Parent,
	partStorage = getOrCreatePartStorage(),

	namePrefix = "MyMelodyDrop_",
	dropGroup = "MyMelodyDrops",

	dropRate = 1.0,
	cashValue = 30,  -- $30 per drop (3x Dropper1!)
	lifetime = 20,

	size = Vector3.new(1.25, 1.7, 1.7),
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

print("✅ [MyMelody Dropper 2] Loaded - no more infinite yield!")
