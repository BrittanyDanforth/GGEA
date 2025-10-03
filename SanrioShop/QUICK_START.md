# 🚀 Quick Start Guide - Sanrio Shop System

## ⚡ 5-Minute Setup

### 1️⃣ Create Folder Structure (30 seconds)
In Roblox Studio:
```
StarterPlayer
└── StarterPlayerScripts
    └── ShopSystem (NEW FOLDER)
```

### 2️⃣ Add Scripts (2 minutes)

| File Name | Type | Source File |
|-----------|------|-------------|
| `SanrioShop` | **LocalScript** | `SanrioShop.lua` |
| `SanrioShop_Core` | **ModuleScript** | `SanrioShop_Core.lua` |
| `SanrioShop_UI` | **ModuleScript** | `SanrioShop_UI.lua` |

**All three scripts must be in the same `ShopSystem` folder!**

### 3️⃣ Setup Remote Events (1 minute)
In `ReplicatedStorage`, create:
```
ReplicatedStorage
└── TycoonRemotes (FOLDER)
    ├── GrantProductCurrency (RemoteEvent)
    ├── GamepassPurchased (RemoteEvent)
    ├── AutoCollectToggle (RemoteEvent)
    └── GetAutoCollectState (RemoteFunction)
```

### 4️⃣ Update Product IDs (1 minute)
Open `SanrioShop_Core` and find this section (around line 350):

```lua
DataManager.products = {
    cash = {
        {
            id = 1897730242,  -- 👈 CHANGE THIS to your product ID
            amount = 1000,
            -- ...
        },
    },
    gamepasses = {
        {
            id = 1412171840,  -- 👈 CHANGE THIS to your gamepass ID
            name = "Auto Collect",
            -- ...
        },
    },
}
```

### 5️⃣ Test! (30 seconds)
1. Play test in Studio
2. Press **M** key to open shop
3. Verify UI appears

## ✅ Verification Checklist

- [ ] All 3 files in `StarterPlayerScripts/ShopSystem`
- [ ] `TycoonRemotes` folder in `ReplicatedStorage`
- [ ] 4 remote objects inside `TycoonRemotes`
- [ ] Product IDs updated to your game's IDs
- [ ] Shop opens when pressing M key

## 🎯 Module Paths

The main script requires modules using:
```lua
local Core = require(script.Parent:WaitForChild("SanrioShop_Core"))
local UI = require(script.Parent:WaitForChild("SanrioShop_UI"))
```

### Alternative Locations

If you want modules in **ReplicatedStorage** instead:

1. Move `SanrioShop_Core` and `SanrioShop_UI` to `ReplicatedStorage`
2. Update the require statements in `SanrioShop.lua`:

```lua
-- Change from:
local Core = require(script.Parent:WaitForChild("SanrioShop_Core"))
local UI = require(script.Parent:WaitForChild("SanrioShop_UI"))

-- To:
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Core = require(ReplicatedStorage:WaitForChild("SanrioShop_Core"))
local UI = require(ReplicatedStorage:WaitForChild("SanrioShop_UI"))
```

## 🎨 Quick Customization

### Change Shop Keybind
In `SanrioShop.lua`, find (around line 1050):
```lua
if input.KeyCode == Enum.KeyCode.M then  -- Change M to another key
```

### Change Theme Colors
In `SanrioShop_Core.lua`, find the theme colors (around line 90):
```lua
accent = Color3.fromRGB(255, 64, 129),  -- Main pink color
```

### Disable Sounds
In `SanrioShop_Core.lua`, find (around line 80):
```lua
settings = {
    soundEnabled = false,  -- Change true to false
    -- ...
}
```

## ❌ Common Issues

### "Module not found" Error
**Problem**: Scripts can't find the modules  
**Solution**: Ensure all 3 scripts are in the same folder

### Shop Doesn't Open
**Problem**: Press M but nothing happens  
**Solution**: Check Output console for errors

### Products Show Wrong Price
**Problem**: Prices are 0 or incorrect  
**Solution**: 
1. Check product IDs are correct
2. Ensure products are published on Roblox
3. Wait 5 minutes for Roblox API cache

### "TycoonRemotes not found" Warning
**Problem**: RemoteEvents not set up  
**Solution**: Create the `TycoonRemotes` folder and remotes as shown in step 3

## 🔗 Need More Help?

- See full documentation: `README.md`
- Enable debug mode: Set `DEBUG = true` in `SanrioShop_Core.lua`
- Check Roblox Output console for error messages

## 📞 Server-Side Example

Quick server script to handle purchases:

```lua
-- Place in ServerScriptService
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("TycoonRemotes")

-- Product receipts
local function processReceipt(receiptInfo)
    local player = game.Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- Give player their cash here
    print("Player", player.Name, "purchased product", receiptInfo.ProductId)
    
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt

-- Auto Collect state (example)
local autoCollectStates = {}

Remotes.GetAutoCollectState.OnServerInvoke = function(player)
    return autoCollectStates[player.UserId] or false
end

Remotes.AutoCollectToggle.OnServerEvent:Connect(function(player, state)
    autoCollectStates[player.UserId] = state
    print(player.Name, "set Auto Collect to", state)
end)
```

---

**That's it! Your shop should now be working. Press M to test it! 🎉**
