--[[
	🛡️ DROPPER ATTRIBUTE SETUP - Multi-Tycoon Safety
	
	Add this to your DropperCore script OR individual dropper scripts
	to tag drops with their owning tycoon.
	
	This prevents cleanup from nuking neighboring tycoons' drops!
]]

--========================================
-- OPTION 1: Add to DropperCore (BEST - applies to all droppers automatically)
--========================================

-- At the TOP of your DropperCore.Run() and DropperCore.RunModel() functions:

-- Get the tycoon ID (add this once at module level)
local function getTycoonId(dropperModel)
	local tycoon = dropperModel:FindFirstAncestor("Tycoon") 
		or dropperModel:FindFirstAncestor("Kuromi") 
		or dropperModel:FindFirstAncestor("Cinnamoroll")
		or dropperModel:FindFirstAncestor("HelloKitty")
		or dropperModel:FindFirstAncestor("MyMelody")
	
	if tycoon then
		return tycoon:GetAttribute("TycoonId") or tycoon.Name
	end
	
	return "Unknown"
end

-- Then in Core.Run() - AFTER creating the part but BEFORE parenting:

function Core.Run(config)
	-- ... your existing code ...
	
	local TYCOON_ID = getTycoonId(config.model)  -- ← ADD THIS
	
	while true do
		task.wait(DROP_RATE)
		count += 1

		local part = Instance.new("Part")
		-- ... setup part properties ...
		
		-- 🛡️ TAG THE DROP WITH TYCOON ID (before parenting!)
		part:SetAttribute("TycoonId", TYCOON_ID)
		
		-- Cash value
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = CASH_VALUE
		cash.Parent = part

		-- ... rest of your code ...
		part.Parent = storage  -- Parent AFTER setting attribute!
	end
end

-- And in Core.RunModel() - AFTER creating model but BEFORE parenting:

function Core.RunModel(config)
	-- ... your existing code ...
	
	local TYCOON_ID = getTycoonId(dropModel)  -- ← ADD THIS
	
	local function createModel(): Model
		local m = template:Clone()
		local primary = findPrimaryPart(m) or m:FindFirstChildWhichIsA("BasePart", true)
		
		-- 🛡️ TAG THE MODEL WITH TYCOON ID
		m:SetAttribute("TycoonId", TYCOON_ID)
		
		-- ... rest of setup ...
		
		-- ALSO tag all parts (optional but safer for cleanup)
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p:SetAttribute("TycoonId", TYCOON_ID)
			end
		end
		
		-- ... rest of your code ...
		return m
	end
	
	-- ... rest of your code ...
end


--========================================
-- OPTION 2: Add to EACH Individual Dropper Script (if you don't use DropperCore)
--========================================

-- At the TOP of your dropper script:

local TYCOON_ID = script:FindFirstAncestor("Tycoon"):GetAttribute("TycoonId") 
	or script:FindFirstAncestor("Tycoon").Name

-- Then when creating drops:

local drop = Instance.new("Part")
-- ... setup properties ...

-- 🛡️ TAG IT!
drop:SetAttribute("TycoonId", TYCOON_ID)

local cash = Instance.new("IntValue")
cash.Name = "Cash"
cash.Value = 100
cash.Parent = drop

drop.Parent = workspace -- or your storage folder


--========================================
-- OPTION 3: Set TycoonId Attribute on Each Tycoon Model (REQUIRED!)
--========================================

-- In your main tycoon setup script or manually in Studio:

local tycoons = {
	workspace.Kuromi,
	workspace.Cinnamoroll,
	workspace.HelloKitty,
	workspace.MyMelody
}

for i, tycoon in ipairs(tycoons) do
	-- Set unique ID for each tycoon
	tycoon:SetAttribute("TycoonId", tycoon.Name)  -- or use a unique number
	print("✅ Set TycoonId for", tycoon.Name, "=", tycoon.Name)
end


--========================================
-- VERIFICATION: Check if Attributes Are Set
--========================================

-- Run this in a test script to verify drops are being tagged:

task.wait(5)  -- Let some drops spawn

local foundDrops = 0
local taggedDrops = 0

for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("BasePart") and descendant:FindFirstChild("Cash") then
		foundDrops = foundDrops + 1
		
		local tycoonId = descendant:GetAttribute("TycoonId")
		if tycoonId then
			taggedDrops = taggedDrops + 1
			print("✅ Drop tagged with TycoonId:", tycoonId)
		else
			warn("⚠️ Drop NOT tagged! Name:", descendant.Name)
		end
	end
end

print("📊 Found", foundDrops, "drops,", taggedDrops, "properly tagged")

if taggedDrops < foundDrops then
	warn("⚠️ Some drops are NOT tagged! Update your dropper script!")
else
	print("✅ All drops properly tagged! Multi-tycoon cleanup is SAFE!")
end


--========================================
-- SUMMARY: What to Do
--========================================

--[[
	1. Set TycoonId attribute on each tycoon model:
	   workspace.Kuromi:SetAttribute("TycoonId", "Kuromi")
	   workspace.Cinnamoroll:SetAttribute("TycoonId", "Cinnamoroll")
	   workspace.HelloKitty:SetAttribute("TycoonId", "HelloKitty")
	   workspace.MyMelody:SetAttribute("TycoonId", "MyMelody")
	
	2. Update your DropperCore or dropper scripts to:
	   - Get the TYCOON_ID from ancestor
	   - Call :SetAttribute("TycoonId", TYCOON_ID) on every drop/model
	
	3. Use the MULTI_TYCOON_SAFE handler which:
	   - Only destroys drops with matching TycoonId
	   - Won't accidentally nuke neighbors
	
	4. Verify with the test script above
	
	5. Test in live server:
	   - Player 1 joins Tycoon 1, drops spawn
	   - Player 2 joins Tycoon 2, drops spawn
	   - Player 1 LEAVES
	   - Check: Only Tycoon 1 drops should be gone!
	   - Tycoon 2 drops should still be there ✅
]]
