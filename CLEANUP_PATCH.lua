-- ========================================
-- 🛡️ IMPROVED CLEANUP HELPERS (ADD TO TOP OF RESET FUNCTION)
-- ========================================

-- 🔒 MUTEX: Prevent overlapping resets
local isResetting = false

-- 🛠️ Helper: Check if object is a Cash value
local function isCashValueObject(obj)
	if (obj:IsA("IntValue") or obj:IsA("NumberValue")) and obj.Name == "Cash" then
		return true
	end
	return false
end

-- 🛠️ Helper: Check if model has ANY cash signal
local function modelHasCashSignal(root)
	-- 1) ValueObjects named Cash anywhere
	for _, d in ipairs(root:GetDescendants()) do
		if isCashValueObject(d) then return true end
	end
	-- 2) Attribute on model/root (Cash or CashValue)
	if root:GetAttribute("Cash") ~= nil or root:GetAttribute("CashValue") ~= nil then
		return true
	end
	-- 3) Tag based (optional if you use it)
	if CollectionService:HasTag(root, "Drop") or CollectionService:HasTag(root, "TycoonDrop") then
		return true
	end
	-- 4) Legacy: BasePart child named Cash
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d:FindFirstChild("Cash") then
			return true
		end
	end
	return false
end

-- 🛠️ Helper: Get TycoonId from instance or ancestors
local function getOwningTycoonId(inst)
	local cur = inst
	while cur do
		local v = cur:GetAttribute("TycoonId")
		if v ~= nil then return tostring(v) end
		cur = cur.Parent
	end
	return nil
end

-- 🛠️ Helper: Check if belongs to THIS tycoon
local function belongsToThisTycoon(inst)
	local v = getOwningTycoonId(inst)
	if not v then return false end
	if v == TYCOON_ID then return true end
	-- case-insensitive match
	return tostring(v):lower() == tostring(TYCOON_ID):lower()
end

-- 🛠️ Helper: Safely destroy
local function destroySafely(inst)
	pcall(function()
		if inst and inst.Parent then inst:Destroy() end
	end)
end
