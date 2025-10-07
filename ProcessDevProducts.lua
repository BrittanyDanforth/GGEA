-- Process Dev Products for Sanrio Shop
-- Place this in ServerScriptService

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

-- Product ID to Cash amount mapping
local PRODUCT_AMOUNTS = {
	[3366419712] = 1000,   -- 1,000 Cash
	[3366420012] = 5000,   -- 5,000 Cash
	[3366420478] = 10000,  -- 10,000 Cash
	[3366420800] = 25000,  -- 25,000 Cash
}

-- Function to grant currency to player
local function grantCurrency(player, amount)
	-- First try using the global money API if it exists
	if _G.AddPlayerMoney then
		local success = _G.AddPlayerMoney(player.Name, amount)
		if success then
			print("✅ Granted", amount, "cash to", player.Name, "via Global API")
			return true
		end
	end
	
	-- Fallback: Try to find leaderstats
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		-- Look for Cash value (could be IntValue or StringValue)
		local cash = stats:FindFirstChild("Cash")
		if cash then
			if cash:IsA("IntValue") or cash:IsA("NumberValue") then
				cash.Value = cash.Value + amount
				print("✅ Granted", amount, "cash to", player.Name, "via leaderstats")
				return true
			elseif cash:IsA("StringValue") then
				-- Try to parse the string value (might have commas or K/M/B)
				local currentValue = 0
				local cleanValue = cash.Value:gsub(",", ""):gsub("K", "000"):gsub("M", "000000"):gsub("B", "000000000")
				currentValue = tonumber(cleanValue) or 0
				
				-- Update via global API if possible
				if _G.SetPlayerMoney then
					_G.SetPlayerMoney(player.Name, currentValue + amount)
				else
					-- Can't update string value directly
					warn("⚠️ Cash is StringValue but no Global API available")
				end
			end
		end
	end
	
	return false
end

-- Process receipts for dev products
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Player probably left, we'll try again later
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	-- Check if this is one of our cash products
	local amount = PRODUCT_AMOUNTS[receiptInfo.ProductId]
	if amount then
		-- Grant the currency
		local success = grantCurrency(player, amount)
		
		if success then
			print("💰 Purchase processed: Player", player.Name, "bought", amount, "cash")
			return Enum.ProductPurchaseDecision.PurchaseGranted
		else
			warn("❌ Failed to grant currency to", player.Name)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end
	
	-- Not one of our products, let other scripts handle it
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

print("💰 Sanrio Shop Dev Product handler ready!")
print("📦 Handling products:", PRODUCT_AMOUNTS)