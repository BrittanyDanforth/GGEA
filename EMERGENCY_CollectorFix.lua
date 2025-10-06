--[[
	🚨 EMERGENCY COLLECTOR FIX - Drop Anywhere
	✅ Auto-finds your tycoon
	✅ Auto-finds collectors
	✅ Auto-finds owner
	✅ Just put it ANYWHERE in your tycoon and it works
	
	PUT IN: Anywhere inside your Kuromi Tycoon folder
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("🚨 EMERGENCY COLLECTOR FIX - Starting...")

-- =================== CONFIG ===================
local BATCH_INTERVAL = 0.2  -- Batch every 0.2 seconds
local MAX_BATCH = 40        -- Max items per batch
-- ==============================================

-- Auto-find tycoon (search up the tree)
local function findTycoon()
	local current = script.Parent
	while current and current ~= workspace do
		-- Look for Owner value (indicates it's a tycoon)
		if current:FindFirstChild("Owner") then
			return current
		end
		current = current.Parent
	end
	-- Fallback: use parent
	return script.Parent
end

local tycoonModel = findTycoon()
local ownerValue = tycoonModel:FindFirstChild("Owner", true)

if not ownerValue then
	warn("⚠️ Could not find Owner value in tycoon!")
end

print("✅ Found tycoon:", tycoonModel:GetFullName())

-- Get remotes safely
local MoneyRemote, CurrencyRemote

task.spawn(function()
	local success, result = pcall(function()
		local tr = ReplicatedStorage:WaitForChild("TycoonRemotes", 5)
		return tr:WaitForChild("MoneyCollected", 5)
	end)
	if success then MoneyRemote = result end
end)

task.spawn(function()
	local success, result = pcall(function()
		local re = ReplicatedStorage:WaitForChild("RemoteEvents", 5)
		return re:WaitForChild("CurrencyUpdated", 5)
	end)
	if success then CurrencyRemote = result end
end)

-- Batching
local pendingMoney = 0
local itemCount = 0

local function sendBatch()
	if pendingMoney <= 0 then return end
	if not ownerValue or not ownerValue.Value then return end
	
	local player = ownerValue.Value
	local amount = pendingMoney
	
	pendingMoney = 0
	itemCount = 0
	
	task.spawn(function()
		if MoneyRemote then
			pcall(function() MoneyRemote:FireClient(player, amount) end)
		end
		if CurrencyRemote then
			pcall(function() CurrencyRemote:FireClient(player, amount) end)
		end
	end)
end

-- Batch loop
task.spawn(function()
	while true do
		task.wait(BATCH_INTERVAL)
		sendBatch()
	end
end)

-- Auto-find and setup collectors
local function setupAllCollectors()
	local count = 0
	local debounce = {}
	
	for _, part in ipairs(tycoonModel:GetDescendants()) do
		if part:IsA("BasePart") then
			local name = string.lower(part.Name)
			
			-- Is it a collector?
			if name:find("collect") or name:find("sell") or name:find("receiver") then
				count = count + 1
				
				-- Setup touch
				part.Touched:Connect(function(hit)
					if debounce[hit] then return end
					
					local cash = hit:FindFirstChild("Cash")
					if not cash or not cash:IsA("IntValue") or cash.Value <= 0 then return end
					
					debounce[hit] = true
					
					-- Add to batch
					pendingMoney = pendingMoney + cash.Value
					itemCount = itemCount + 1
					
					-- Force send if batch is full
					if itemCount >= MAX_BATCH then
						sendBatch()
					end
					
					-- Destroy
					task.defer(function()
						if hit.Parent then
							if hit.Parent:IsA("Model") then
								hit.Parent:Destroy()
							else
								hit:Destroy()
							end
						end
					end)
					
					-- Clear debounce
					task.delay(0.5, function()
						debounce[hit] = nil
					end)
				end)
			end
		end
	end
	
	return count
end

-- Run setup
task.wait(2)
local collectorCount = setupAllCollectors()

if collectorCount == 0 then
	warn("⚠️ EMERGENCY FIX: No collectors found!")
	warn("⚠️ Make sure you have parts named 'Collector', 'Sell', etc.")
else
	print(string.format("✅ EMERGENCY FIX: %d collectors active!", collectorCount))
	print("✅ Remote event lag should be fixed!")
end

-- Cleanup
if ownerValue then
	ownerValue.Changed:Connect(function()
		if not ownerValue.Value then
			pendingMoney = 0
			itemCount = 0
		end
	end)
end
