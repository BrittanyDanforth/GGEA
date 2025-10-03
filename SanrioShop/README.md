# Sanrio Shop System v3.0.0

A professional, modular shop system for Roblox with modern UI components and architecture.

## 📁 File Structure

```
StarterPlayer/
└── StarterPlayerScripts/
    └── ShopSystem/              (Folder)
        ├── SanrioShop           (LocalScript - Main)
        ├── SanrioShop_Core      (ModuleScript)
        └── SanrioShop_UI        (ModuleScript)
```

## 🚀 Installation Instructions

### Step 1: Create the Folder Structure
1. Open Roblox Studio
2. Navigate to `StarterPlayer > StarterPlayerScripts`
3. Create a new **Folder** and name it `ShopSystem`

### Step 2: Add the Scripts

#### Main Script (LocalScript)
1. Inside the `ShopSystem` folder, create a **LocalScript**
2. Name it: `SanrioShop`
3. Copy the contents from `SanrioShop.lua` into this script

#### Core Module (ModuleScript)
1. Inside the `ShopSystem` folder, create a **ModuleScript**
2. Name it: `SanrioShop_Core`
3. Copy the contents from `SanrioShop_Core.lua` into this module

#### UI Module (ModuleScript)
1. Inside the `ShopSystem` folder, create a **ModuleScript**
2. Name it: `SanrioShop_UI`
3. Copy the contents from `SanrioShop_UI.lua` into this module

### Step 3: Configure Remote Events (Required)
The shop system requires certain RemoteEvents to be set up in `ReplicatedStorage`:

1. Create a folder in `ReplicatedStorage` named `TycoonRemotes`
2. Add the following RemoteEvents inside it:
   - `GrantProductCurrency` (RemoteEvent) - For product purchases
   - `GamepassPurchased` (RemoteEvent) - For gamepass confirmation
   - `AutoCollectToggle` (RemoteEvent) - For Auto Collect gamepass
   - `GetAutoCollectState` (RemoteFunction) - To get current Auto Collect state

### Step 4: Update Product IDs
In the `SanrioShop_Core` module, update the product IDs to match your game:

```lua
DataManager.products = {
    cash = {
        {
            id = YOUR_PRODUCT_ID, -- Change this
            amount = 1000,
            -- ... rest of config
        },
        -- ... more products
    },
    gamepasses = {
        {
            id = YOUR_GAMEPASS_ID, -- Change this
            name = "Auto Collect",
            -- ... rest of config
        },
        -- ... more gamepasses
    },
}
```

## ✨ Features

### Core Features
- ✅ Modular architecture with clean separation of concerns
- ✅ Advanced state management system
- ✅ Optimized performance with smart caching
- ✅ Smooth animations and transitions
- ✅ Full mobile support with responsive design
- ✅ Robust error handling

### Shop Features
- 💰 Developer Product purchases (Cash packs)
- 🎫 Game Pass purchases with ownership tracking
- 🔄 Auto-refresh product prices from Roblox API
- 🎨 Beautiful modern UI with Sanrio theme
- 📱 Mobile-optimized interface
- 🎵 Sound effects for interactions
- ⌨️ Keyboard shortcuts (M to toggle, ESC to close)
- 🎮 Gamepad support

### UI Components
- Custom component system (Frame, Button, TextLabel, Image, etc.)
- Theme system (Light/Dark mode ready)
- Layout utilities (Stack, Grid, Center)
- Visual effects (Shadow, Glow, Shimmer)
- Responsive scaling

## 🎮 Usage

### Opening the Shop
- **Keyboard**: Press `M` key
- **Click**: Click the shop toggle button (bottom-right corner)
- **Gamepad**: Press `X` button

### Navigation
- Three main tabs: **Home**, **Cash**, **Gamepasses**
- Scroll through products using mouse/touch
- Click/tap to purchase items

### Customization

#### Change Theme Colors
Edit the `UI.Theme.themes.light` table in `SanrioShop_UI.lua`:

```lua
UI.Theme = {
    current = "light",
    themes = {
        light = {
            background = Color3.fromRGB(253, 252, 250),
            surface = Color3.fromRGB(255, 255, 255),
            accent = Color3.fromRGB(255, 64, 129),
            -- ... customize these colors
        }
    }
}
```

#### Change Sound Effects
Edit the sound IDs in `SanrioShop_Core.lua`:

```lua
function SoundSystem.initialize()
    local sounds = {
        click = {id = "rbxassetid://876939830", volume = 0.4},
        hover = {id = "rbxassetid://10066936758", volume = 0.2},
        -- ... change these IDs
    }
end
```

#### Adjust Panel Size
Modify constants in `SanrioShop_Core.lua`:

```lua
local CONSTANTS = {
    PANEL_SIZE = Vector2.new(1140, 860),
    PANEL_SIZE_MOBILE = Vector2.new(920, 720),
    CARD_SIZE = Vector2.new(520, 300),
    -- ... adjust these
}
```

## 🔧 Server-Side Setup (Required)

You'll need server scripts to handle purchases. Here's a basic example:

```lua
-- ServerScriptService
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("TycoonRemotes")
local GrantProductCurrency = Remotes:WaitForChild("GrantProductCurrency")

-- Product ID to Cash Amount mapping
local PRODUCTS = {
    [1897730242] = 1000,
    [1897730373] = 5000,
    [1897730467] = 10000,
    [1897730581] = 50000,
}

-- Handle product purchases
local function processReceipt(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    local productId = receiptInfo.ProductId
    local cashAmount = PRODUCTS[productId]
    
    if cashAmount then
        -- Give player cash (implement your own cash system)
        -- player.leaderstats.Cash.Value += cashAmount
        
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.ProcessReceipt = processReceipt

-- Handle gamepass verification
game.Players.PlayerAdded:Connect(function(player)
    -- Check gamepasses and grant benefits
end)
```

## 📊 Events System

The shop emits various events you can listen to:

```lua
-- In your other scripts
local Core = require(path.to.SanrioShop_Core)

-- Listen to shop opened
Core.Events:on("shopOpened", function()
    print("Shop was opened!")
end)

-- Listen to shop closed
Core.Events:on("shopClosed", function()
    print("Shop was closed!")
end)

-- Listen to tab changes
Core.Events:on("tabChanged", function(tabName)
    print("Switched to tab:", tabName)
end)

-- Listen to errors (when DEBUG = true)
Core.Events:on("error", function(errorData)
    warn("Shop error:", errorData.context, errorData.error)
end)
```

## 🐛 Debugging

Enable debug mode in `SanrioShop_Core.lua`:

```lua
local SanrioShop = {
    VERSION = "3.0.0",
    DEBUG = true,  -- Change to true
}
```

This will:
- Print detailed error messages
- Emit error events
- Show more console output

## 📝 API Reference

### Core Module

#### Core.CONSTANTS
Configuration constants (timings, sizes, z-indices, etc.)

#### Core.State
Current state of the shop (isOpen, currentTab, etc.)

#### Core.Events
Event system for pub/sub pattern

#### Core.Utils
Utility functions (isMobile, formatNumber, lerp, clamp, etc.)

#### Core.Animation
Animation helpers (tween, spring, sequence)

#### Core.SoundSystem
Sound management (initialize, play)

#### Core.DataManager
Product data and marketplace API calls

### UI Module

#### UI.Theme
Theme system with color management

#### UI.Components
UI component factory (Frame, Button, TextLabel, etc.)

#### UI.Effects
Visual effects (shadow, glow, shimmer)

#### UI.Layout
Layout utilities (stack, grid, center)

#### UI.Responsive
Responsive design helpers (scale, breakpoint)

## 🤝 Support

If you encounter issues:

1. Check the Output console for error messages
2. Verify all RemoteEvents are properly set up
3. Ensure product IDs match your game
4. Enable DEBUG mode for detailed logs
5. Check that modules are in the correct hierarchy

## 📜 License

This shop system is provided as-is for use in Roblox games.

## 🔄 Version History

### v3.0.0 (Current)
- Modular architecture
- Separated Core and UI modules
- Fixed layout property errors
- Updated sound asset IDs
- Improved mobile support
- Added comprehensive documentation

---

**Happy developing! 🎮**
