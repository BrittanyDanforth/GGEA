# Sanrio Shop System - Installation & Setup Guide

## Version 3.0.1 - Fixed & Polished Edition

### What's Fixed in This Version:
1. ✅ **Home page blank on first open** - Now properly displays content immediately
2. ✅ **Tab selection issues** - Tabs now respond correctly on first click
3. ✅ **Visual improvements** - Enhanced UI with shadows, gradients, and better spacing
4. ✅ **Purchase handling** - Added server script for proper purchase processing
5. ✅ **Auto-collect toggle positioning** - Toggle switch now properly aligned in gamepass cards

### Installation Instructions:

#### Step 1: Install Client Script
1. Open Roblox Studio
2. In Explorer, navigate to `StarterPlayer > StarterPlayerScripts`
3. Right-click on `StarterPlayerScripts` and select "Insert Object" > "LocalScript"
4. Name the LocalScript: `SanrioShop`
5. Copy all contents from `SanrioShop.lua` and paste into the LocalScript

#### Step 2: Install Server Script
1. In Explorer, navigate to `ServerScriptService`
2. Right-click on `ServerScriptService` and select "Insert Object" > "Script"
3. Name the Script: `SanrioShopHandler`
4. Copy all contents from `SanrioShopServer.lua` and paste into the Script

#### Step 3: Currency Integration
The shop needs to integrate with your tycoon's currency system. In the server script, find the `grantCurrency` function and modify it to match your game:

```lua
local function grantCurrency(player, amount)
    -- Replace this with your actual currency system
    -- Example for typical tycoon:
    local tycoon = getTycoonFromPlayer(player) -- Your function
    if tycoon then
        tycoon.Cash.Value = tycoon.Cash.Value + amount
        return true
    end
    return false
end
```

### Product & Gamepass IDs:

#### Cash Products (Developer Products):
- 1,000 Cash: `1897730242`
- 5,000 Cash: `1897730373`
- 10,000 Cash: `1897730467`
- 50,000 Cash: `1897730581`

#### Gamepasses:
- Auto Collect: `1412171840`
- 2x Cash: `1398974710`

### Features:

1. **Responsive Design** - Automatically scales for different screen sizes
2. **Mobile Support** - Optimized layout for mobile devices
3. **Smooth Animations** - Polished transitions and hover effects
4. **Sound Effects** - Audio feedback for interactions
5. **Auto-refresh** - Ownership status updates automatically
6. **Keyboard Shortcuts** - Press 'M' to open/close shop

### Customization:

#### Change Theme Colors:
In the client script, find the `UI.Theme` section and modify colors:

```lua
UI.Theme = {
    themes = {
        light = {
            accent = Color3.fromRGB(255, 64, 129), -- Main accent color
            kitty = Color3.fromRGB(255, 64, 64),   -- Home tab color
            cinna = Color3.fromRGB(186, 214, 255), -- Cash tab color
            kuromi = Color3.fromRGB(200, 190, 255), -- Gamepass tab color
        }
    }
}
```

#### Add New Products:
In the `Core.DataManager.products` section, add new items:

```lua
cash = {
    {
        id = YOUR_PRODUCT_ID,
        amount = 25000,
        name = "25,000 Cash",
        description = "A medium boost pack",
        icon = "rbxassetid://10709728059",
        featured = false,
        price = 0,
    },
}
```

### Troubleshooting:

#### Shop won't open:
- Check F9 console for errors
- Ensure both scripts are properly installed
- Verify the scripts aren't disabled

#### Purchases fail:
- Ensure product IDs match your game's products
- Check that products are active in Game Settings
- Verify MarketplaceService is enabled

#### Currency not granted:
- Modify the `grantCurrency` function to match your system
- Check server console for grant messages
- Ensure your currency values are IntValue or NumberValue

### Visual Improvements in v3.0.1:
- Added drop shadows to cards and buttons
- Gradient overlays on hero section and product images
- Improved spacing and padding throughout
- Enhanced hover effects with shadow animations
- Better toggle switch design for gamepasses
- Statistics section on home page
- Emoji icons for visual appeal

### Support:
If you need help integrating with your specific tycoon system, the main areas to modify are:
1. `grantCurrency` function in server script
2. Remote event names if your tycoon uses different ones
3. Currency display format in the UI

The shop is now fully functional and polished! 🎀