--[[
	🎀 SANRIO SHOP VERIFICATION SCRIPT
	Run this in Command Bar to verify your setup
	
	Usage:
	1. Open Studio
	2. Press F9 (Command Bar)
	3. Paste this entire script
	4. Press Enter
	5. Check Output for results
]]

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SPScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

print("🔍 VERIFYING SANRIO SHOP ULTIMATE SETUP...")
print("=" .. string.rep("=", 50))

local errors = 0
local warnings = 0
local success = 0

-- ========================================
-- CHECK CLIENT SCRIPT
-- ========================================

print("\n📱 CLIENT SCRIPT:")
if not SPScripts then
	print("  ❌ StarterPlayerScripts not found!")
	errors = errors + 1
else
	local clientScript = SPScripts:FindFirstChild("SanrioShopUltimate") 
		or SPScripts:FindFirstChild("SanrioShop")
	
	if clientScript then
		if clientScript.Name == "SanrioShopUltimate" then
			print("  ✅ SanrioShopUltimate.lua found (CORRECT)")
			success = success + 1
		else
			print("  ⚠️  Old SanrioShop.lua found (should upgrade to Ultimate)")
			warnings = warnings + 1
		end
		
		if clientScript:IsA("LocalScript") then
			print("  ✅ Is LocalScript (CORRECT)")
			success = success + 1
		else
			print("  ❌ Not a LocalScript!")
			errors = errors + 1
		end
	else
		print("  ❌ No shop client script found!")
		print("     Place SanrioShopUltimate.lua in StarterPlayerScripts")
		errors = errors + 1
	end
end

-- ========================================
-- CHECK SERVER SCRIPT
-- ========================================

print("\n🖥️  SERVER SCRIPT:")
local serverScript = SSS:FindFirstChild("SanrioShopServer")

if serverScript then
	print("  ✅ SanrioShopServer.lua found")
	success = success + 1
	
	if serverScript:IsA("Script") then
		print("  ✅ Is Script (CORRECT)")
		success = success + 1
	else
		print("  ❌ Not a Script!")
		errors = errors + 1
	end
else
	print("  ❌ SanrioShopServer.lua not found!")
	print("     Place in ServerScriptService")
	errors = errors + 1
end

-- ========================================
-- CHECK REMOTES
-- ========================================

print("\n📡 REMOTES:")
local TycoonRemotes = RS:FindFirstChild("TycoonRemotes")

if TycoonRemotes then
	print("  ✅ TycoonRemotes folder found")
	success = success + 1
	
	local remoteChecks = {
		{"GamepassPurchased", "RemoteEvent"},
		{"AutoCollectToggle", "RemoteEvent"},
		{"GetAutoCollectState", "RemoteFunction"},
	}
	
	for _, check in ipairs(remoteChecks) do
		local name, className = check[1], check[2]
		local remote = TycoonRemotes:FindFirstChild(name)
		
		if remote then
			if remote:IsA(className) then
				print(string.format("  ✅ %s (%s)", name, className))
				success = success + 1
			else
				print(string.format("  ❌ %s exists but wrong type (should be %s)", name, className))
				errors = errors + 1
			end
		else
			print(string.format("  ⚠️  %s not found (will be auto-created)", name))
			warnings = warnings + 1
		end
	end
else
	print("  ⚠️  TycoonRemotes not found (will be auto-created)")
	warnings = warnings + 1
end

-- ========================================
-- CHECK GAMEPASS IDS
-- ========================================

print("\n🎮 GAMEPASS IDS:")
print("  ℹ️  Make sure these match your actual gamepasses!")
print("  Auto Collect: 1412171840")
print("  2x Cash:      1398974710")
print("\n  To verify, check:")
print("  - SanrioShopUltimate.lua (line ~255)")
print("  - SanrioShopServer.lua (line ~123)")

-- ========================================
-- CHECK INTEGRATION
-- ========================================

print("\n🔗 INTEGRATION:")
local moneyShop = SSS:FindFirstChild("MoneyShop")
if moneyShop then
	print("  ✅ MoneyShop.server.lua found (handles Dev Products)")
	success = success + 1
else
	print("  ⚠️  MoneyShop.server.lua not found")
	print("     Dev Products may not work")
	warnings = warnings + 1
end

local tycoons = workspace:FindFirstChild("Tycoons")
if tycoons then
	local tycoonCount = #tycoons:GetChildren()
	print(string.format("  ✅ Found %d tycoons", tycoonCount))
	success = success + 1
	
	-- Check if any tycoon has a purchase handler
	local hasHandler = false
	for _, tycoon in ipairs(tycoons:GetChildren()) do
		if tycoon:FindFirstChild("PurchaseHandler") then
			hasHandler = true
			break
		end
	end
	
	if hasHandler then
		print("  ✅ Purchase handlers found (will sync with auto-collect)")
		success = success + 1
	else
		print("  ⚠️  No purchase handlers found")
		warnings = warnings + 1
	end
else
	print("  ⚠️  Tycoons folder not found")
	warnings = warnings + 1
end

-- ========================================
-- RESULTS
-- ========================================

print("\n" .. string.rep("=", 50))
print("📊 VERIFICATION RESULTS:")
print(string.rep("=", 50))
print(string.format("  ✅ Success: %d", success))
print(string.format("  ⚠️  Warnings: %d", warnings))
print(string.format("  ❌ Errors: %d", errors))
print(string.rep("=", 50))

if errors == 0 and warnings == 0 then
	print("\n🎉 PERFECT SETUP! You're ready to go!")
	print("   Press F5 and test it out!")
elseif errors == 0 then
	print("\n✅ GOOD SETUP! Minor warnings can be ignored.")
	print("   Most things will auto-create on first run.")
elseif errors <= 2 then
	print("\n⚠️  INCOMPLETE SETUP. Fix the errors above.")
	print("   Check SHOP_INSTALLATION_GUIDE.md for help.")
else
	print("\n❌ SETUP INCOMPLETE! Multiple errors found.")
	print("   Follow SHOP_INSTALLATION_GUIDE.md carefully.")
end

print("\n📖 Documentation:")
print("  - SHOP_INSTALLATION_GUIDE.md — Step-by-step setup")
print("  - SHOP_FIXES_SUMMARY.md — Your issues → solutions")
print("  - SANRIO_SHOP_ULTIMATE_README.md — Full features")

print("\n🎯 Quick Test:")
print("  1. Press F5 in Studio")
print("  2. Press M to open shop")
print("  3. Try purchasing Auto Collect gamepass")
print("  4. Button should show 'Owned' INSTANTLY (no flicker)")
print("  5. Toggle chip should appear")
print("  6. Click Enable/Disable to toggle")

print("\n✨ Done!")
