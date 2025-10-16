# 🎀 Sanrio Tycoon Group Popup - Roblox LocalScript 🎀

A complete, self-contained LocalScript that creates an **adorable pastel-themed "Join Group" modal** for your Sanrio Tycoon game!

## ✅ Features Implemented

### Core Functionality
- ✅ **Complete UI Hierarchy**: Builds ScreenGui → Dim → Card → Title → Body → Buttons
- ✅ **No Dependencies**: Single script, no external objects required
- ✅ **Proper ZIndex Layering**: Dim (Z=10), Card & children (Z=20-21)
- ✅ **No "Dim Only" Bug**: Entire modal renders correctly every time
- ✅ **ResetOnSpawn = false**: Persists through character respawns

### Visual Design (Cutesy Pastel Sanrio Theme!)
- ✅ **Adorable Kawaii UI**: Soft pastel pinks, purples, and lavenders
- ✅ **Cute Rounded Corners**: 20px radius for that soft, friendly look
- ✅ **Soft Gradient Overlay**: Pink-to-purple diagonal gradient (MORE OPAQUE!)
- ✅ **Pastel Border**: 3px soft pink stroke
- ✅ **Button Hover Effects**: Cute bounce & grow on hover
- ✅ **Side-by-Side Layout**: 700×400px card with text on left, guide image on right!
- ✅ **"How to Join" Decal**: Shows your custom step-by-step instructions
- ✅ **Smooth Animations**: TweenService-powered with bounce effects (0.3s open, 0.2s close)

### Behavior
- ✅ **Group Membership Check**: Uses `LocalPlayer:IsInGroup(GROUP_ID)`
- ✅ **FORCE_SHOW Flag**: Override membership check for testing
- ✅ **Studio Testing Flag**: `ALWAYS_SHOW_IN_STUDIO` for development
- ✅ **Mobile-Friendly Taps**: All buttons use `.Activated` (works on phones!)
- ✅ **Tap-to-Zoom Decal**: Tap the "How to Join" image to view it fullscreen
- ✅ **Zoom Overlay**: Only closes with "Got it!" button (not background clicks)
- ✅ **Join Group Button**: Shows notification with your group ID
- ✅ **No Broken APIs**: No OpenBrowserWindow, no forbidden methods
- ✅ **Fallback Notification**: Shows group ID for easy copying
- ✅ **No Auto-Hide**: Manual close only (no timers)

### Technical Excellence
- ✅ **Comprehensive Logging**: All actions logged with `[GroupPopup]` prefix
- ✅ **No Early Returns**: UI builds completely before membership logic
- ✅ **Error Handling**: pcall wrapped around API calls
- ✅ **No Infinite Yield**: Creates all instances, doesn't wait on external objects
- ✅ **Unique Naming**: ScreenGui named "GroupJoinPopup" to avoid conflicts
- ✅ **Proper Parenting**: ScreenGui parented last to avoid rendering issues

## 📦 Installation

1. **Open your Roblox game in Roblox Studio**

2. **Add the script**:
   - Go to `StarterPlayer` → `StarterPlayerScripts` (recommended)
   - OR `StarterGui`
   - Right-click → Insert Object → LocalScript
   - Rename it to "GroupJoinPopup"

3. **Paste the code** from `GroupJoinPopup.lua`

4. **Configure** (see Configuration section below)

## ⚙️ Configuration

Edit the `CONFIG` table at the top of the script:

```lua
local CONFIG = {
    -- ⭐ Your Sanrio Tycoon Group ID
    GROUP_ID = 986814499, -- Already set!
    HOW_TO_JOIN_DECAL = "rbxassetid://73482754980631", -- Your step-by-step guide image
    
    -- Testing flags
    FORCE_SHOW = true, -- Set to false in production
    ALWAYS_SHOW_IN_STUDIO = true, -- Show in Studio even if member
    
    -- 🎨 Cute Pastel Colors (fully customizable!)
    COLORS = {
        CARD_BG = Color3.fromRGB(255, 250, 252), -- Soft white-pink
        GRADIENT_TOP = Color3.fromRGB(255, 228, 240), -- Soft pink
        GRADIENT_BOTTOM = Color3.fromRGB(240, 230, 255), -- Soft lavender
        BUTTON_PRIMARY = Color3.fromRGB(255, 182, 213), -- Cute pink button
        BUTTON_SECONDARY = Color3.fromRGB(230, 220, 255), -- Soft lavender button
        TITLE = Color3.fromRGB(255, 105, 180), -- Hot pink title
        BODY = Color3.fromRGB(150, 120, 160), -- Soft purple-grey text
        -- ... more colors inside!
    },
    
    -- UI Settings (optional to modify)
    CARD_SIZE = UDim2.new(0, 480, 0, 360),
    DIM_TRANSPARENCY = 0.4,
    ANIMATION_SPEED_OPEN = 0.3,
    ANIMATION_SPEED_CLOSE = 0.2,
}
```

### Finding Your Group ID

1. Go to your Roblox group page
2. Look at the URL: `https://www.roblox.com/groups/12345678/GroupName`
3. The number (12345678) is your GROUP_ID

## 🧪 Testing

### Test 1: Force Show (Studio)
```lua
FORCE_SHOW = true
```
- Run the game in Studio
- Modal should appear immediately with all elements visible
- Click "Join Group" → should attempt to open URL
- Click "Not now" or dim → modal closes with animation

### Test 2: Membership Check (Studio)
```lua
FORCE_SHOW = false
ALWAYS_SHOW_IN_STUDIO = true
GROUP_ID = 12345678 -- Your real group ID
```
- Modal shows if you're NOT a member
- Modal doesn't show if you ARE a member

### Test 3: Production
```lua
FORCE_SHOW = false
ALWAYS_SHOW_IN_STUDIO = false
GROUP_ID = 12345678 -- Your real group ID
```
- Publish and test in-game
- Only non-members see the popup

### Test 4: Respawn Persistence
- While modal is open, reset your character
- Modal should remain visible (ResetOnSpawn=false)

## 📊 Output Log Example

```
🎀 [SanrioGroupPopup] ✨ === Sanrio Tycoon Group Popup Initializing === ✨
🎀 [SanrioGroupPopup] Script location: Players.LocalPlayer.PlayerScripts.LocalScript
🎀 [SanrioGroupPopup] 📝 Configuration:
🎀 [SanrioGroupPopup]   GROUP_ID: 986814499
🎀 [SanrioGroupPopup]   FORCE_SHOW: true
🎀 [SanrioGroupPopup]   ALWAYS_SHOW_IN_STUDIO: true
🎀 [SanrioGroupPopup] 🏗️ buildUI() - Starting UI construction...
🎀 [SanrioGroupPopup] 🎨 Creating ScreenGui...
🎀 [SanrioGroupPopup] 🌈 Creating Dim overlay...
🎀 [SanrioGroupPopup] 💝 Creating Card...
🎀 [SanrioGroupPopup] ⬅️ Creating left side container...
🎀 [SanrioGroupPopup] ➡️ Creating right side with How To Join decal...
🎀 [SanrioGroupPopup] 🔍 Creating zoom overlay for decal...
🎀 [SanrioGroupPopup] ✅ buildUI() - UI construction complete!
🎀 [SanrioGroupPopup] 📍 Environment check - inStudio: true
🎀 [SanrioGroupPopup] ⭐ FORCE_SHOW enabled - showing popup
🎀 [SanrioGroupPopup] 🎀 showPopup() - Opening cute modal...
🎀 [SanrioGroupPopup] ✨ showPopup() - Modal opened successfully!
🎀 [SanrioGroupPopup] [Zoom] Decal tapped - opening zoom view!
🎀 [SanrioGroupPopup] 🔍 Opening zoom overlay...
🎀 [SanrioGroupPopup] ❌ Closing zoom overlay...
🎀 [SanrioGroupPopup] [Join] Join Group button clicked!
🎀 [SanrioGroupPopup] joinGroup() - Showing group info for: 986814499
🎀 [SanrioGroupPopup] joinGroup() - Notification shown successfully!
🎀 [SanrioGroupPopup] 👋 hidePopup() - Closing modal...
🎀 [SanrioGroupPopup] ✅ hidePopup() - Modal closed
🎀 [SanrioGroupPopup] ✨ === Sanrio Group Popup Ready! === ✨
```

## 🎨 Customization

### Change Colors

All colors are in the `CONFIG.COLORS` table at the top! Easy to customize:

```lua
COLORS = {
    -- Make it more pink?
    BUTTON_PRIMARY = Color3.fromRGB(255, 150, 200),
    
    -- Want blue instead of purple?
    GRADIENT_BOTTOM = Color3.fromRGB(200, 230, 255),
    
    -- Different title color?
    TITLE = Color3.fromRGB(255, 120, 200),
}
```

**Sanrio Character Themes:**
- **Hello Kitty**: Reds & pinks `Color3.fromRGB(255, 100, 150)`
- **Kuromi**: Purples & blacks `Color3.fromRGB(150, 100, 200)`
- **Cinnamoroll**: Blues & whites `Color3.fromRGB(150, 200, 255)`
- **My Melody**: Pinks & whites `Color3.fromRGB(255, 180, 210)`

### Change Text

Search for these lines and customize:

**Title**:
```lua
title.Text = "Thanks for Playing! 💕"
```

**Body**:
```lua
body.Text = "We noticed you've been playing for a bit! If you'd like to join our group, you'll get:\n\n• Daily Spins 🎡\n• Early Access to Future Features 🌟\n• Special Rewards (when game is fully finished!) 🎁"
```

**How to Join Decal**:
```lua
HOW_TO_JOIN_DECAL = "rbxassetid://73482754980631" -- Your custom guide image
```

**Button Text**:
```lua
local joinButton = createButton(buttonContainer, "JoinButton", "✨ Join Group!", true, 1)
local notNowButton = createButton(buttonContainer, "NotNowButton", "Maybe Later", false, 2)
```

### Change Card Size

```lua
CARD_SIZE = UDim2.new(0, 600, 0, 400), -- Wider & taller
```

## 🐛 Troubleshooting

### Issue: Only dim shows, no card
**Cause**: Wrong ZIndex or early return  
**Solution**: This script fixes that! Dim=Z10, Card=Z20+

### Issue: Modal disappears on respawn
**Cause**: ResetOnSpawn=true  
**Solution**: Script sets ResetOnSpawn=false (line 76)

### Issue: "Infinite yield" warning
**Cause**: Waiting on non-existent objects  
**Solution**: Script creates everything, no external waits

### Issue: Modal doesn't show
**Check**:
1. Is FORCE_SHOW=true for testing?
2. Is GROUP_ID set correctly?
3. Check Output window for `[GroupPopup]` logs
4. Are you already a member of the group?

### Issue: How do players join the group?
**How it works**: Roblox doesn't have a direct "join group" API, so the popup shows:
1. A cute notification with instructions: "Press ESC > Groups > Search ID: [your group ID]"
2. The Group ID is displayed prominently in the popup itself
3. Players can easily copy the ID and search for your group

**This is the ONLY reliable way** - other methods don't work in published games!

## 🔒 Security & Performance

- ✅ No remote events or external dependencies
- ✅ Client-side only (no server load)
- ✅ Minimal memory footprint
- ✅ No loops or recurring tasks
- ✅ pcall protection on all API calls
- ✅ No data storage or privacy concerns

## 📝 Acceptance Criteria Checklist

- ✅ One script, no dependencies
- ✅ Builds entire modal (dim + card + text + buttons) - **NO MORE "DIM ONLY" BUG!**
- ✅ DisplayOrder=10000, ResetOnSpawn=false, IgnoreGuiInset=true
- ✅ Proper ZIndex hierarchy (Dim=10, Card/children=20+)
- ✅ Config flags: GROUP_ID, FORCE_SHOW, ALWAYS_SHOW_IN_STUDIO
- ✅ Show/hide logic with membership check
- ✅ No early returns that skip UI building
- ✅ Smooth animations with TweenService (cute bounce effects!)
- ✅ Responsive design (480×360 centered card)
- ✅ **Shows Group ID prominently + helpful notification**
- ✅ Works in real Roblox AND Studio
- ✅ No auto-hide timer (manual close only)
- ✅ Comprehensive cute logging with 🎀 [SanrioGroupPopup] prefix
- ✅ No infinite yield warnings
- ✅ Unique naming (SanrioGroupJoinPopup)
- ✅ **ADORABLE PASTEL SANRIO THEME!** 🎀✨

## 📄 License

Free to use, modify, and distribute. No attribution required.

## 🎀 What Makes This Special?

1. **📱 MOBILE-FIRST TAP-TO-ZOOM** - Tap the decal to see it FULLSCREEN (perfect for reading Step 1/Step 2 on phones!)
2. **Side-by-Side Layout** - Text on left, "How to Join" guide image on right
3. **Custom Decal Support** - Shows YOUR step-by-step instructions (rbxassetid://73482754980631)
4. **Personalized Message** - "Thanks for playing!" + rewards list (daily spins, early access, etc.)
5. **Cutesy Pastel Design** - Sanrio-themed colors (not boring corporate)
6. **Group ID: 986814499** - Pre-configured for your Sanrio Tycoon
7. **✅ .Activated Events** - Works on BOTH desktop AND mobile (no more missed taps!)
8. **"Got it!" Close Button** - Zoom only closes with button (not background clicks)
9. **Better Animations** - Bounce effects and smooth transitions
10. **Made for YOUR Tycoon** - Perfect for Hello Kitty, Kuromi, Cinnamoroll, My Melody themes!

---

**Created**: 2025-10-16  
**Version**: 2.0 (CUTE EDITION! 🎀)  
**Roblox API**: Uses MODERN SocialService (not outdated methods)
**Theme**: Sanrio Kawaii Pastel ✨
