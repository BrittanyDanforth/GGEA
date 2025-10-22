--[[
    🎁 TEXTURE ID FINDER
    
    HOW TO USE:
    1. Paste your ASSET ID below (the number from the website URL)
    2. Run this script in Studio (Command Bar or as a Script)
    3. Copy the TEXTURE ID it prints
    4. Paste that into SanrioShop.lua line ~365
]]

-- ⬇️ PASTE YOUR ASSET ID HERE ⬇️
local YOUR_ASSET_ID = 0 -- Replace 0 with your asset ID number!

-- ========================================
-- Don't touch below this line
-- ========================================

if YOUR_ASSET_ID == 0 then
    error("❌ You need to set YOUR_ASSET_ID first! (Line 12)")
end

print("🔍 Looking up texture ID for asset:", YOUR_ASSET_ID)

-- Create a temporary decal to get the texture ID
local decal = Instance.new("Decal")
decal.Texture = "rbxassetid://" .. YOUR_ASSET_ID
decal.Parent = workspace

-- Wait for Roblox to convert it
task.wait(0.5)

-- Extract the texture ID
local textureUrl = decal.Texture
local textureId = textureUrl:match("rbxassetid://(%d+)")

if textureId then
    print("✅ SUCCESS!")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📋 Your TEXTURE ID:", textureId)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("")
    print("🎯 Copy this line into SanrioShop.lua (around line 365):")
    print('local GIFT_BOX_TEXTURE_ID = "' .. textureId .. '"')
    print("")
else
    warn("❌ Could not get texture ID. Make sure your asset ID is correct!")
end

-- Cleanup
decal:Destroy()
