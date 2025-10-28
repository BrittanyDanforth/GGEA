--[[
    MONEY SHOP SERVER (Developer Products Handler)
    Place in: ServerScriptService
    Name: MoneyShop
    
    Handles ALL developer product (cash) purchases with:
    - Idempotency (no double-grants)
    - Multiple fallback methods for granting currency
    - Studio testing support
    
    ⚠️ IMPORTANT: This is the ONLY script that should set MarketplaceService.ProcessReceipt!
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")
local DataStoreService   = game:GetService("DataStoreService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerStorage      = game:GetService("ServerStorage")
local RunService         = game:GetService("RunService")

print("💰 [MoneyShop] Initializing...")

-- ========================================
-- DEVELOPER PRODUCT CONFIGURATION
-- ========================================

-- Map ALL your Developer Product IDs to cash amounts
local PRODUCT_TO_CASH = {
	[3366419712] = 1000,     -- 1,000 Cash
	[3366420012] = 5000,     -- 5,000 Cash
	[3366420478] = 10000,    -- 10,000 Cash
	[3366420800] = 25000,    -- 25,000 Cash
	[3424973374] = 50000,    -- 50,000 Cash
	[3424974046] = 100000,   -- 100,000 Cash
	[3424974161] = 250000,   -- 250,000 Cash
	[3424974327] = 500000,   -- 500,000 Cash
	[3424974402] = 1000000,  -- 1,000,000 Cash
}

-- Idempotency store to prevent double-grants
local receiptStore = DataStoreService:GetDataStore("Sanrio_PurchaseReceipts")

-- ========================================
-- WAIT FOR GLOBAL MONEY API
-- ========================================

task.spawn(function()
	local t = 0
	while not _G.AddPlayerMoney and t < 30 do
		task.wait(0.5)
		t += 0.5
	end
	if _G.AddPlayerMoney then
		print("✅ [MoneyShop] Connected to Global Money API (_G.AddPlayerMoney)")
	else
		warn("⚠️ [MoneyShop] _G.AddPlayerMoney not available after 30s.")
		warn("⚠️ [MoneyShop] Will use fallback methods (leaderstats or ServerStorage)")
	end
end)

-- ========================================
-- CURRENCY GRANTING FUNCTION
-- ========================================

local function grantCashToPlayer(userId: number, amount: number): boolean
	local player = Players:GetPlayerByUserId(userId)
	if not player then 
		warn("❌ [MoneyShop] Player not found for userId:", userId)
		return false 
	end

	print(string.format("💵 [MoneyShop] Granting %d cash to %s...", amount, player.Name))

	-- METHOD 1: Global Money API (preferred for tycoons)
	if _G.AddPlayerMoney then
		local ok, err = pcall(function()
			return _G.AddPlayerMoney(player.Name, amount)
		end)
		if ok then
			print(string.format("✅ [MoneyShop] Granted via _G.AddPlayerMoney: %d to %s", amount, player.Name))
			return true
		end
		warn("[MoneyShop] _G.AddPlayerMoney failed:", err)
	end

	-- METHOD 2: leaderstats > Cash/Money IntValue
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local cashValue = leaderstats:FindFirstChild("Cash") or leaderstats:FindFirstChild("Money")
		if cashValue and cashValue:IsA("IntValue") then
			cashValue.Value += amount
			print(string.format("✅ [MoneyShop] Granted via leaderstats: %d to %s", amount, player.Name))
			return true
		end
	end

	-- METHOD 3: ServerStorage.PlayerMoney IntValue (fallback)
	local folder = ServerStorage:FindFirstChild("PlayerMoney")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PlayerMoney"
		folder.Parent = ServerStorage
		print("📁 [MoneyShop] Created ServerStorage.PlayerMoney folder")
	end
	
	local intValue = folder:FindFirstChild(player.Name)
	if not intValue then
		intValue = Instance.new("IntValue")
		intValue.Name = player.Name
		intValue.Parent = folder
	end
	intValue.Value += amount
	print(string.format("✅ [MoneyShop] Granted via ServerStorage: %d to %s", amount, player.Name))
	return true
end

-- ========================================
-- PROCESS RECEIPT (MAIN HANDLER)
-- ========================================

local function processReceipt(receiptInfo)
	local productId = receiptInfo.ProductId
	local amount = PRODUCT_TO_CASH[productId]
	
	-- Not our product - let another handler take it (if any)
	if not amount then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Ensure player is in-game; otherwise retry later
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		warn(string.format("⚠️ [MoneyShop] Player not in game for receipt %s, will retry", receiptInfo.PurchaseId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- IDEMPOTENCY: Check if we already processed this purchase
	local key = ("receipt_%s"):format(tostring(receiptInfo.PurchaseId))
	local ok, stateOrErr = pcall(function()
		return receiptStore:UpdateAsync(key, function(oldValue)
			-- If already granted, keep that state
			if oldValue == "granted" then 
				return "granted" 
			end
			-- Mark as pending
			return "pending"
		end)
	end)
	
	if not ok then
		warn("[MoneyShop] DataStore error for receipt:", stateOrErr)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	if stateOrErr == "granted" then
		-- Already processed this purchase
		print(string.format("✓ [MoneyShop] Receipt %s already granted (idempotent)", receiptInfo.PurchaseId))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Grant the currency
	local granted = grantCashToPlayer(receiptInfo.PlayerId, amount)
	if not granted then
		warn("[MoneyShop] Failed to grant currency, will retry")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Mark as granted in DataStore
	pcall(function() 
		receiptStore:SetAsync(key, "granted") 
	end)
	
	print(string.format("🎉 [MoneyShop] Purchase complete! Granted %d cash to %s (productId: %d)", 
		amount, player.Name, productId))

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ⚠️ CRITICAL: Only ONE script in your game should set this!
MarketplaceService.ProcessReceipt = processReceipt

-- ========================================
-- STUDIO TESTING FALLBACK
-- ========================================

do
	local folder = ReplicatedStorage:FindFirstChild("TycoonRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TycoonRemotes"
		folder.Parent = ReplicatedStorage
	end
	
	local grantRemote = folder:FindFirstChild("GrantProductCurrency")
	if not grantRemote then
		grantRemote = Instance.new("RemoteEvent")
		grantRemote.Name = "GrantProductCurrency"
		grantRemote.Parent = folder
	end

	grantRemote.OnServerEvent:Connect(function(player, productId)
		if not RunService:IsStudio() then return end
		
		local amount = PRODUCT_TO_CASH[productId]
		if amount then
			grantCashToPlayer(player.UserId, amount)
			print(string.format("🧪 [MoneyShop] Studio test grant: %d cash to %s (product %d)", 
				amount, player.Name, productId))
		end
	end)
	
	print("🧪 [MoneyShop] Studio testing fallback enabled")
end

-- ========================================
-- INITIALIZATION COMPLETE
-- ========================================

local productCount = 0
for _ in pairs(PRODUCT_TO_CASH) do productCount += 1 end

print("✅ [MoneyShop] Ready!")
print(string.format("📦 %d cash products registered", productCount))
print("💳 Developer products will be processed automatically")

return true
