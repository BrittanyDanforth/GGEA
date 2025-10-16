# GroupJoinPopup - Roblox LocalScript

A complete, self-contained LocalScript that creates a professional "Join Group" modal UI for Roblox games.

## ✅ Features Implemented

### Core Functionality
- ✅ **Complete UI Hierarchy**: Builds ScreenGui → Dim → Card → Title → Body → Buttons
- ✅ **No Dependencies**: Single script, no external objects required
- ✅ **Proper ZIndex Layering**: Dim (Z=10), Card & children (Z=20-21)
- ✅ **No "Dim Only" Bug**: Entire modal renders correctly every time
- ✅ **ResetOnSpawn = false**: Persists through character respawns

### Visual Design
- ✅ **Professional AAA UI**: Clean, modern design with no emojis
- ✅ **Rounded Corners**: 16px corner radius on card
- ✅ **Subtle Border**: 2px stroke for depth
- ✅ **Responsive Layout**: 520×340px card, centered, works on all devices
- ✅ **Smooth Animations**: TweenService-powered fade in/out (0.25s open, 0.2s close)

### Behavior
- ✅ **Group Membership Check**: Uses `LocalPlayer:IsInGroup(GROUP_ID)`
- ✅ **FORCE_SHOW Flag**: Override membership check for testing
- ✅ **Studio Testing Flag**: `ALWAYS_SHOW_IN_STUDIO` for development
- ✅ **Click to Close**: Dim overlay and "Not now" button both close popup
- ✅ **Join Group Button**: Opens group URL via `SetCore("OpenUrl")`
- ✅ **Fallback Notification**: Shows URL in notification if browser open fails
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
    -- Your Roblox group ID (find it in the group URL)
    GROUP_ID = 0, -- Change to your group ID (e.g., 12345678)
    
    -- Your group URL
    GROUP_URL = "https://www.roblox.com/groups/0/your-group",
    
    -- Testing flags
    FORCE_SHOW = true, -- Set to false in production
    ALWAYS_SHOW_IN_STUDIO = true, -- Show in Studio even if member
    
    -- UI Settings (optional to modify)
    CARD_SIZE = UDim2.new(0, 520, 0, 340),
    DIM_TRANSPARENCY = 0.35,
    ANIMATION_SPEED_OPEN = 0.25,
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
[GroupPopup] === GroupJoinPopup Initializing ===
[GroupPopup] Script location: Players.LocalPlayer.PlayerScripts.GroupJoinPopup
[GroupPopup] Configuration:
[GroupPopup]   GROUP_ID: 12345678
[GroupPopup]   GROUP_URL: https://www.roblox.com/groups/12345678/MyGroup
[GroupPopup]   FORCE_SHOW: true
[GroupPopup]   ALWAYS_SHOW_IN_STUDIO: true
[GroupPopup] buildUI() - Starting UI construction...
[GroupPopup] Creating ScreenGui...
[GroupPopup] Creating Dim overlay...
[GroupPopup] Creating Card...
[GroupPopup] Creating Title...
[GroupPopup] Creating Body text...
[GroupPopup] Creating button container...
[GroupPopup] Creating button: JoinButton
[GroupPopup] Creating button: NotNowButton
[GroupPopup] buildUI() - UI construction complete!
[GroupPopup] Environment check - inStudio: true
[GroupPopup] FORCE_SHOW enabled - showing popup
[GroupPopup] showPopup() - Opening modal...
[GroupPopup] showPopup() - Modal opened
[GroupPopup] Join Group button clicked
[GroupPopup] openGroupUrl() - Attempting to open: https://www.roblox.com/groups/12345678/MyGroup
[GroupPopup] openGroupUrl() - Successfully opened URL
[GroupPopup] hidePopup() - Closing modal...
[GroupPopup] hidePopup() - Modal closed
[GroupPopup] === GroupJoinPopup Initialization Complete ===
```

## 🎨 Customization

### Change Colors

**Primary Button** (Join Group):
```lua
BackgroundColor3 = Color3.fromRGB(0, 162, 255) -- Line ~212
```

**Secondary Button** (Not now):
```lua
BackgroundColor3 = Color3.fromRGB(240, 240, 240) -- Line ~212
```

**Card Background**:
```lua
BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- Line ~119
```

### Change Text

**Title** (line ~168):
```lua
title.Text = "Join Our Group"
```

**Body** (line ~185):
```lua
body.Text = "Join our community to unlock exclusive benefits, participate in events, and connect with other members!"
```

**Button Text** (lines ~437-438):
```lua
local joinButton = createButton(buttonContainer, "JoinButton", "Join Group", true, 1)
local notNowButton = createButton(buttonContainer, "NotNowButton", "Not now", false, 2)
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

### Issue: URL doesn't open
**Check**:
1. Is the GROUP_URL correct?
2. Look for fallback notification with the URL
3. Check Output for error messages

## 🔒 Security & Performance

- ✅ No remote events or external dependencies
- ✅ Client-side only (no server load)
- ✅ Minimal memory footprint
- ✅ No loops or recurring tasks
- ✅ pcall protection on all API calls
- ✅ No data storage or privacy concerns

## 📝 Acceptance Criteria Checklist

- ✅ One script, no dependencies
- ✅ Builds entire modal (dim + card + text + buttons)
- ✅ DisplayOrder=10000, ResetOnSpawn=false, IgnoreGuiInset=true
- ✅ Proper ZIndex hierarchy (Dim=10, Card/children=20+)
- ✅ Config flags: GROUP_ID, GROUP_URL, FORCE_SHOW, ALWAYS_SHOW_IN_STUDIO
- ✅ Show/hide logic with membership check
- ✅ No early returns that skip UI building
- ✅ Animations with TweenService (open/close)
- ✅ Responsive design (520×340 centered card)
- ✅ SetCore("OpenUrl") with pcall and fallback notification
- ✅ No auto-hide timer (manual close only)
- ✅ Comprehensive logging with [GroupPopup] prefix
- ✅ No infinite yield warnings
- ✅ Unique naming (GroupJoinPopup)

## 📄 License

Free to use, modify, and distribute. No attribution required.

---

**Created**: 2025-10-16  
**Version**: 1.0  
**Roblox API**: Compatible with current Roblox Luau
