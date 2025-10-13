# 🔧 LIVE SERVER FIX GUIDE - Kuromi/Cinnamoroll/HelloKitty/MyMelody

## 🚨 THE PROBLEM

Your tycoons work perfectly in Studio but **DON'T CLEAN UP** when players leave in live Roblox servers. Drops stay floating, purchased objects remain, money doesn't reset.

## ✅ THE FIXES (Applied to Kuromi_PurchaseHandler_LIVE_FIXED.lua)

### 1. **PlayerRemoving Hook** ⭐ MOST IMPORTANT
**Problem:** You rely on `Owner.Value` changing when player leaves. In live servers, this isn't guaranteed to happen or happens too late.

**Fix:** Hook directly to `Players.PlayerRemoving`:
```lua
Players.PlayerRemoving:Connect(function(player)
	if tycoonOwner.Value == player then
		print("👋 PLAYER REMOVING - FORCING CLEANUP")
		
		cleanupAutoCollect(player)
		
		-- Safe spawn cleanup
		pcall(function()
			local spawnLocation = essentials:FindFirstChild("Spawn")
			if spawnLocation and spawnLocation:IsA("SpawnLocation") then
				spawnLocation.Neutral = true
			end
		end)
		
		-- Safe player property cleanup
		pcall(function()
			if player.Parent then
				player.RespawnLocation = nil
				player.Team = nil
			end
		end)
		
		-- Clear owner FIRST so systems see tycoon as free
		tycoonOwner.Value = nil
		
		-- Full reset
		resetTycoonPurchases()
		currentOwner = nil
	end
end)
```

---

### 2. **PartStorage Cleanup** 📦
**Problem:** Your reset only scans `workspace:GetChildren()` but DropperCore puts drops in a **PartStorage folder** you pass to it. That folder never gets cleared.

**Fix:** Cache and clear PartStorage:
```lua
-- At top of script
local partStorage = essentials:FindFirstChild("PartStorage") or script.Parent:FindFirstChild("PartStorage")

-- Inside resetTycoonPurchases()
if partStorage then
	local storageCount = #partStorage:GetChildren()
	for _, child in ipairs(partStorage:GetChildren()) do
		pcall(function() child:Destroy() end)
	end
	print("  ✓ Cleared PartStorage:", storageCount, "drops")
end
```

---

### 3. **GetDescendants() World Sweep** 🌍
**Problem:** You only check `workspace:GetChildren()`, missing drops nested in folders/models.

**Fix:** Use `workspace:GetDescendants()` and destroy entire models:
```lua
-- Wait for physics to settle
task.wait()

local tycoonPosition = script.Parent:GetPivot().Position
local radius = 120

for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("BasePart") then
		local cash = descendant:FindFirstChild("Cash")
		if cash and cash:IsA("IntValue") then
			local distance = (descendant.Position - tycoonPosition).Magnitude
			if distance < radius then
				-- Destroy entire model if part of one
				local rootModel = descendant:FindFirstAncestorOfClass("Model")
				if rootModel then
					pcall(function() rootModel:Destroy() end)
				else
					pcall(function() descendant:Destroy() end)
				end
				destroyedCount = destroyedCount + 1
			end
		end
	end
end
```

---

### 4. **GUID Double-Collection Prevention** 🆔
**Problem:** Live servers can fire `.Touched` twice due to network replication, causing double money awards.

**Fix:** Use GUID tracking:
```lua
-- At top
local HttpService = game:GetService("HttpService")
local collectedIds = {}  -- GUID tracking

-- In collector
local model = part.Parent
local dropId = nil

if model and model:IsA("Model") then
	-- Get or create GUID
	dropId = model:GetAttribute("DropId")
	if not dropId then
		dropId = HttpService:GenerateGUID(false)
		model:SetAttribute("DropId", dropId)
	end
	
	-- ... calculate cash ...
	
	-- Check GUID before awarding
	if dropId and collectedIds[dropId] then 
		return  -- Already collected!
	end
	
	if dropId then
		collectedIds[dropId] = true
	end
	
	Money.Value = Money.Value + modelCashValue
	model:Destroy()
end
```

---

### 5. **Safe pcall() Wrapping** 🛡️
**Problem:** When player disconnects, accessing `player.Team` or `player.RespawnLocation` can error if player already removed from game.

**Fix:** Wrap in pcall:
```lua
pcall(function()
	if player.Parent then
		player.RespawnLocation = nil
		player.Team = nil
	end
end)
```

---

### 6. **ProcessReceipt Conflict** ⚠️ CRITICAL
**Problem:** Each tycoon script sets `MarketplaceService.ProcessReceipt = function()`. In live servers, only the **last assignment wins**, breaking dev product purchases for other tycoons.

**Fix:** Create ONE central script in ServerScriptService:

```lua
-- ServerScriptService/CentralReceiptHandler
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	
	-- Find which tycoon/button this product belongs to
	for _, tycoon in ipairs(workspace:GetDescendants()) do
		if tycoon:IsA("Folder") or tycoon:IsA("Model") then
			local buttons = tycoon:FindFirstChild("Buttons")
			if buttons then
				for _, button in ipairs(buttons:GetChildren()) do
					local devProd = button:FindFirstChild("DevProduct")
					if devProd and devProd.Value == receiptInfo.ProductId then
						-- Fire a BindableEvent to the tycoon's handler
						local purchaseEvent = tycoon:FindFirstChild("ProcessPurchaseEvent")
						if purchaseEvent and purchaseEvent:IsA("BindableEvent") then
							purchaseEvent:Fire(button, player)
							return Enum.ProductPurchaseDecision.PurchaseGranted
						end
					end
				end
			end
		end
	end
	
	return Enum.ProductPurchaseDecision.NotProcessedYet
end
```

Then in each tycoon handler, **REMOVE** the `MarketplaceService.ProcessReceipt =` assignment and instead create a BindableEvent to receive purchases.

---

## 📋 CHECKLIST - Apply to ALL Handlers

### ✅ For Kuromi (DONE in Kuromi_PurchaseHandler_LIVE_FIXED.lua)
- [x] PlayerRemoving hook
- [x] PartStorage cleanup
- [x] GetDescendants() sweep
- [x] GUID tracking
- [x] Safe pcall wrapping
- [x] Note about ProcessReceipt

### 🔄 For Cinnamoroll
Apply the same 6 fixes:
1. Add `Players.PlayerRemoving:Connect()` hook
2. Cache `partStorage` and clear it in reset
3. Replace `workspace:GetChildren()` with `workspace:GetDescendants()`
4. Add `HttpService` and `collectedIds` GUID tracking
5. Wrap player cleanup in `pcall()`
6. Remove `ProcessReceipt` assignment

### 🔄 For HelloKitty
Same 6 fixes as Cinnamoroll

### 🔄 For MyMelody
Same 6 fixes as Cinnamoroll

---

## 🎯 HOW TO APPLY

### Option A: Copy the Fixed Kuromi Script
1. Take `Kuromi_PurchaseHandler_LIVE_FIXED.lua`
2. Replace your current Kuromi handler
3. Test in live server

### Option B: Manually Patch Your Scripts
For each handler (Cinnamoroll, HelloKitty, MyMelody):

1. **Add to top:**
   ```lua
   local HttpService = game:GetService("HttpService")
   local collectedIds = {}
   local partStorage = essentials:FindFirstChild("PartStorage") or script.Parent:FindFirstChild("PartStorage")
   ```

2. **Add PlayerRemoving hook** (after tycoonOwner.Changed:Connect):
   ```lua
   Players.PlayerRemoving:Connect(function(player)
       if tycoonOwner.Value == player then
           cleanupAutoCollect(player)
           pcall(function()
               local spawnLocation = essentials:FindFirstChild("Spawn")
               if spawnLocation and spawnLocation:IsA("SpawnLocation") then
                   spawnLocation.Neutral = true
               end
           end)
           pcall(function()
               if player.Parent then
                   player.RespawnLocation = nil
                   player.Team = nil
               end
           end)
           tycoonOwner.Value = nil
           resetTycoonPurchases()
           currentOwner = nil
       end
   end)
   ```

3. **Update resetTycoonPurchases():**
   - Add `task.wait()` at start
   - Add PartStorage clearing
   - Replace workspace cleanup with GetDescendants() version
   - Clear `collectedIds = {}`

4. **Update collector Touched:**
   - Add GUID tracking before awarding money
   - Check `collectedIds[dropId]` before collection

5. **Wrap player cleanup in pcall** (in Owner.Changed):
   ```lua
   pcall(function()
       if currentOwner and currentOwner.Parent then
           currentOwner.RespawnLocation = nil
           currentOwner.Team = nil
       end
   end)
   ```

6. **Comment out or remove ProcessReceipt** assignment

---

## 🧪 TESTING

### In Studio (should still work)
1. Claim tycoon
2. Buy upgrades
3. Leave game
4. Check if drops/objects cleared ✅

### In Live Server (the real test!)
1. Publish game
2. Join with 2 accounts
3. Player 1 claims Tycoon 1, buys stuff
4. Player 2 claims Tycoon 2
5. Player 1 LEAVES
6. **Check Tycoon 1:** Should be completely cleared (no drops, no objects, money = 0)
7. Player 3 joins and can claim Tycoon 1 fresh ✅

---

## 🐛 STILL NOT WORKING?

### Debug Checklist:
1. **Check Output log** - Look for "PLAYER REMOVING - FORCING CLEANUP" message
2. **Verify PartStorage path** - Make sure `partStorage` variable finds the right folder
3. **Check radius** - Increase `CLEANUP_RADIUS` in CONFIG to 150+ if drops are far away
4. **StreamingEnabled?** - If enabled, some parts may not be loaded yet. Add extra `task.wait(0.5)` before cleanup
5. **Multiple tycoon scripts?** - Make sure only ONE script per tycoon has these fixes

### Common Issues:
- **"Player still on team after leaving"** → pcall not wrapping player cleanup
- **"Drops stay floating"** → PartStorage not being cleared OR radius too small
- **"Money not resetting"** → PlayerRemoving hook not firing (check if Owner.Value == player)
- **"Some drops invisible but still there"** → GetDescendants() not checking all parts
- **"Double money awards"** → GUID tracking not implemented

---

## 📞 NEED HELP?

If issues persist after applying all fixes:
1. Check Server Output for error messages
2. Add debug prints: `print("DEBUG: Clearing", #partStorage:GetChildren(), "drops")`
3. Test with ONLY Kuromi tycoon enabled to isolate issue
4. Make sure you're testing in a **published live server**, not Studio

---

## ⚡ PERFORMANCE NOTE

These fixes are **optimized** for live servers:
- `pcall()` prevents crashes
- `GetDescendants()` runs once per reset, not continuously
- GUID table auto-clears on reset
- Physics `task.wait()` is minimal (one heartbeat)

Your game should run **smoother** with these fixes because drops actually get cleaned up instead of accumulating forever! 🚀
