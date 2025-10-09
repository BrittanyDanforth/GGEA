# 🔧 Quick Fix Reference - 2X Cash Wheel Integration

## 🎯 THE ONLY CHANGE YOU NEED

Replace this function in your `PurchaseHandler.server.lua`:

### ❌ OLD (Line ~328):
```lua
local function applyMoneyMultiplier(player, amount)
	if check2xCashOwnership(player) then
		return amount * 2, true
	end
	return amount, false
end
```

### ✅ NEW (Line ~328):
```lua
local function applyMoneyMultiplier(player, amount)
	-- Check source 1: Permanent 2X Cash Gamepass
	local hasGamepass = check2xCashOwnership(player)
	
	-- Check source 2: Temporary Wheel Boost (TwoXUntil attribute from daily spin)
	local hasWheelBoost = false
	local untilTs = player:GetAttribute("TwoXUntil")
	if typeof(untilTs) == "number" and untilTs > os.time() then
		hasWheelBoost = true
	end
	
	-- Apply 2X if EITHER is active (don't stack to 4X)
	if hasGamepass or hasWheelBoost then
		return amount * 2, true
	end
	return amount, false
end
```

---

## 📦 BONUS: Real-Time Indicator Support

Add this new function after `update2xCashIndicator()` (around line ~380):

```lua
-- 🎯 NEW: Monitor player's TwoXUntil attribute and update indicator in real-time
local function setupWheelBoostMonitor(player)
	if script.Parent.Owner.Value ~= player then return end
	
	local giver = essentials:FindFirstChild("Giver")
	if not giver then return end
	
	-- Update indicator when attribute changes
	player:GetAttributeChangedSignal("TwoXUntil"):Connect(function()
		local untilTs = player:GetAttribute("TwoXUntil")
		local hasWheelBoost = (typeof(untilTs) == "number" and untilTs > os.time())
		local hasGamepass = check2xCashOwnership(player)
		
		-- Show indicator if EITHER boost is active
		update2xCashIndicator(giver, hasGamepass or hasWheelBoost)
	end)
	
	-- Initial check
	local untilTs = player:GetAttribute("TwoXUntil")
	local hasWheelBoost = (typeof(untilTs) == "number" and untilTs > os.time())
	local hasGamepass = check2xCashOwnership(player)
	update2xCashIndicator(giver, hasGamepass or hasWheelBoost)
end
```

---

## 🔄 Then Call It Here

In your `setupAutoCollect()` function (around line ~480), add ONE line:

```lua
local function setupAutoCollect(player)
	if autoCollectConnections[player] then
		autoCollectConnections[player]:Disconnect()
		autoCollectConnections[player] = nil
	end

	if script.Parent.Owner.Value ~= player then
		return
	end

	print("🤖 Auto-Collect activated for", player.Name)

	-- ... existing code ...

	-- 🆕 ADD THIS LINE:
	setupWheelBoostMonitor(player)

	-- ... rest of function ...
end
```

---

## 🚀 THAT'S IT!

**3 simple changes = Full wheel boost integration**

1. ✅ Update `applyMoneyMultiplier()` to check wheel boost
2. ✅ Add `setupWheelBoostMonitor()` function
3. ✅ Call it in `setupAutoCollect()`

**OR** just replace your entire `PurchaseHandler.server.lua` with `PurchaseHandler_FIXED.server.lua`

---

## 🧪 Test It

1. Spin the wheel
2. Win 2X Cash boost
3. Claim it
4. Collect money
5. See it doubled! 💰💰

**No changes to WheelServer or WheelClient needed!**
