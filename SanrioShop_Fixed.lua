--[[
    Sanrio Shop GUI — FIXED SIZING (v3.6)
    
    ✅ FIXES:
    • Reduced pill button size from 14% to 8% of frame height
    • Fixed tabs container width to scale properly
    • Better positioning under the shop header
    • Proper spacing between buttons
    • Buttons now properly sized and not stretched
    
    Art:
      • Main frame (1024x1024): rbxassetid://83301831904885
      • GAMEPASSES pill:       rbxassetid://137846629770171
      • CASH pill:             rbxassetid://84262748186110
--]]

--// Services
local Players       = game:GetService("Players")
local GuiService    = game:GetService("GuiService")
local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Assets
local IMG_FRAME      = "rbxassetid://83301831904885"
local IMG_GAMEPASSES = "rbxassetid://137846629770171"
local IMG_CASH       = "rbxassetid://84262748186110"

--// Player & Gui
local player  = Players.LocalPlayer
local pg      = player:WaitForChild("PlayerGui")

--// Utility: springy tween helper
local function t(obj, ti, props)
	return TweenService:Create(obj, ti, props)
end

--// Utility: clamp
local function clamp(v, a, b)
	if v < a then return a elseif v > b then return b else return v end
end

--// Utility: map screen point to GuiObject local space
local function screenToLocal(guiObject: GuiObject, screenPos: Vector2): Vector2
	local absPos = guiObject.AbsolutePosition
	return Vector2.new(screenPos.X - absPos.X, screenPos.Y - absPos.Y)
end

--// Pill hit test: rounded rectangle with radius = height/2
local function pointInPill(localPoint: Vector2, width: number, height: number): boolean
	if width <= 0 or height <= 0 then return false end
	local r = height * 0.5
	local x, y = localPoint.X, localPoint.Y

	-- Quick reject outside bounding rect
	if x < 0 or y < 0 or x > width or y > height then
		return false
	end

	-- Central rect (excluding rounded ends)
	if x >= r and x <= (width - r) then
		return true
	end

	-- Left circle center at (r, r)
	local dxL = x - r
	local dyL = y - r
	if (dxL * dxL + dyL * dyL) <= (r * r) then
		return true
	end

	-- Right circle center at (width - r, r)
	local dxR = x - (width - r)
	local dyR = y - r
	if (dxR * dxR + dyR * dyR) <= (r * r) then
		return true
	end

	return false
end

--// Strong press/click feedback (no glow)
local function attachTactile(btn: ImageButton)
	local baseW, baseH = btn.Size.X.Offset, btn.Size.Y.Offset
	local hoverW, hoverH = math.floor(baseW * 1.02), math.floor(baseH * 1.02)
	local downW,  downH  = math.floor(baseW * 0.98), math.floor(baseH * 0.98)

	btn.MouseEnter:Connect(function()
		t(btn, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(hoverW, hoverH),
			ImageTransparency = 0.02
		}):Play()
	end)

	local function resetUp()
		t(btn, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(hoverW, hoverH),
			ImageTransparency = 0.00
		}):Play()
	end

	btn.MouseLeave:Connect(function()
		t(btn, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(baseW, baseH),
			ImageTransparency = 0.00
		}):Play()
	end)

	btn.MouseButton1Down:Connect(function()
		t(btn, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(downW, downH)
		}):Play()
	end)

	btn.MouseButton1Up:Connect(function()
		resetUp()
	end)

	-- For touch devices, emulate hover scale when pressed
	btn.TouchLongPress:Connect(function(_, state)
		if state == Enum.UserInputState.Begin then
			t(btn, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(hoverW, hoverH)
			}):Play()
		end
	end)
end

--// Safe container
local gui = Instance.new("ScreenGui")
gui.Name = "SanrioShop"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = true
gui.Parent = pg

local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundTransparency = 1
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromScale(0.94, 0.94)
root.Parent = gui

local pad = Instance.new("UIPadding")
local inset = GuiService:GetGuiInset()
pad.PaddingTop    = UDim.new(0, inset.Y)
pad.PaddingBottom = UDim.new(0, 8)
pad.PaddingLeft   = UDim.new(0, 8)
pad.PaddingRight  = UDim.new(0, 8)
pad.Parent = root

--// Main frame (1024x1024) kept square by aspect
local frame = Instance.new("ImageLabel")
frame.Name = "ShopFrame"
frame.BackgroundTransparency = 1
frame.Image = IMG_FRAME
frame.ScaleType = Enum.ScaleType.Fit
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromScale(1, 1)
frame.Parent = root

local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = 1
aspect.Parent = frame

--// Tabs region (properly sized now!)
local tabs = Instance.new("Frame")
tabs.Name = "Tabs"
tabs.BackgroundTransparency = 1
tabs.AnchorPoint = Vector2.new(0.5, 0)
tabs.Position = UDim2.fromScale(0.5, 0.28) -- positioned under SHOP header
tabs.Size = UDim2.fromScale(0.75, 0)       -- width as scale, height set in resize()
tabs.Parent = frame

local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Horizontal
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.VerticalAlignment = Enum.VerticalAlignment.Center
list.Padding = UDim.new(0, 16) -- spacing between buttons
list.Parent = tabs

--// Content area (real pages)
local content = Instance.new("Frame")
content.Name = "Content"
content.BackgroundTransparency = 1
content.AnchorPoint = Vector2.new(0.5, 0)
content.Position = UDim2.fromScale(0.5, 0.44) -- positioned below tabs
content.Size = UDim2.fromScale(0.86, 0.48) -- adjusted for better fit
content.Parent = frame

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
panel.BackgroundTransparency = 0.9
panel.Size = UDim2.fromScale(1, 1)
panel.ClipsDescendants = true
panel.Parent = content
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 18)
panelCorner.Parent = panel

local pages = Instance.new("Folder")
pages.Name = "Pages"
pages.Parent = content

--// Create pill image button with controlled hit test
local function createPillButton(name: string, imageId: string): ImageButton
	local btn = Instance.new("ImageButton")
	btn.Name = name .. "Pill"
	btn.BackgroundTransparency = 1
	btn.AutoButtonColor = false
	btn.Image = imageId
	btn.ScaleType = Enum.ScaleType.Stretch  -- Fills the button
	btn.Size = UDim2.fromOffset(200, 60)   -- placeholder, resized later
	btn.ZIndex = 10
	btn.Parent = tabs

	-- Attach tactile feedback
	attachTactile(btn)

	-- Strict pill hit test (no transparent-click cheating)
	local pressing = false
	local insideWhenPressed = false

	local function hitTestPointer(pointerPos: Vector2): boolean
		local lp = screenToLocal(btn, pointerPos)
		local w, h = btn.AbsoluteSize.X, btn.AbsoluteSize.Y
		return pointInPill(lp, w, h)
	end

	-- Intercept normal Activated; we'll manually emit
	btn.Activated:Connect(function()
		-- Swallow; our custom path fires handlers instead.
	end)

	-- Mouse/Touch pathways
	btn.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			pressing = true
			insideWhenPressed = hitTestPointer(input.Position)
		end
	end)

	btn.InputChanged:Connect(function(input: InputObject)
		if not pressing then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			-- (Optional: live hover/press visuals based on inside/outside)
		end
	end)

	btn.InputEnded:Connect(function(input: InputObject)
		if not pressing then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			pressing = false
			local endedInside = hitTestPointer(input.Position)
			if insideWhenPressed and endedInside then
				-- Fire a custom signal (BindableEvent per-button)
				local ev = btn:FindFirstChild("Pressed")
				if not ev then
					ev = Instance.new("BindableEvent")
					ev.Name = "Pressed"
					ev.Parent = btn
				end
				ev:Fire()
			end
		end
	end)

	return btn
end

--// Sections (pages) factory
local function createSection(name: string): Frame
	local page = Instance.new("Frame")
	page.Name = name
	page.BackgroundTransparency = 1
	page.Size = UDim2.fromScale(1,1)
	page.Visible = false
	page.Parent = pages

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.BackgroundTransparency = 1
	scroll.Size = UDim2.fromScale(1,1)
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = page

	local grid = Instance.new("UIGridLayout")
	grid.FillDirectionMaxCells = 2
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.CellSize = UDim2.new(0.49, 0, 0, 110)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	return page
end

--// Instantiate tabs and pages
local cashTab = createPillButton("Cash", IMG_CASH)
local gpTab   = createPillButton("Gamepasses", IMG_GAMEPASSES)

local cashPage = createSection("Cash")
local gpPage   = createSection("Gamepasses")

--// Demo population (replace with real SKUs)
local function newCard(title: string): TextButton
	local card = Instance.new("TextButton")
	card.AutoButtonColor = false
	card.Text = title
	card.Font = Enum.Font.GothamBold
	card.TextScaled = true
	card.TextColor3 = Color3.fromRGB(75, 60, 120)
	card.BackgroundColor3 = Color3.fromRGB(255,255,255)
	card.BackgroundTransparency = 0.86
	card.Size = UDim2.fromScale(1, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 16)
	c.Parent = card

	-- sample tap feedback
	card.MouseButton1Click:Connect(function()
		t(card, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.80}):Play()
		task.delay(0.10, function()
			t(card, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.86}):Play()
		end)
	end)

	return card
end

local function populateCash(parentPage: Frame)
	local scroll = parentPage:FindFirstChild("Scroll") :: ScrollingFrame
	for i = 1, 8 do
		newCard(("Cash Pack %d"):format(i)).Parent = scroll
	end
end

local function populateGamepasses(parentPage: Frame)
	local scroll = parentPage:FindFirstChild("Scroll") :: ScrollingFrame
	local names = {"Auto-Collect", "2x Cash", "Faster Drops", "Cute Boombox", "Cloud Ride", "VIP Badge"}
	for i, n in ipairs(names) do
		newCard(("Pass: %s"):format(n)).Parent = scroll
	end
end

populateCash(cashPage)
populateGamepasses(gpPage)

--// Toggle logic
local function show(which: "cash" | "gp")
	cashPage.Visible = (which == "cash")
	gpPage.Visible   = (which == "gp")

	-- tiny slide-in animation for the active page
	local active = (which == "cash") and cashPage or gpPage
	active.Position = UDim2.fromScale(1.02, 0)
	active.Visible = true
	t(active, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.fromScale(0, 0)}):Play()
end

-- default
show("cash")

-- Precise press handlers (only fire when pill test passes)
local function onCashTabPressed()
	print("💰 Cash tab pressed!")
	show("cash")
end

local function onGamepassesTabPressed()
	print("🎫 Gamepasses tab pressed!")
	show("gp")
end

-- Wire our custom Pressed events
do
	local evC = cashTab:FindFirstChild("Pressed") or Instance.new("BindableEvent")
	evC.Name = "Pressed"; evC.Parent = cashTab
	evC.Event:Connect(onCashTabPressed)

	local evG = gpTab:FindFirstChild("Pressed") or Instance.new("BindableEvent")
	evG.Name = "Pressed"; evG.Parent = gpTab
	evG.Event:Connect(onGamepassesTabPressed)
end

--// ✅ FIXED RESIZE LOGIC - PROPER BUTTON SIZING!
local function resizeSafe()
	local H = frame.AbsoluteSize.Y
	if H <= 0 then return end

	-- ✅ FIXED: Reduced from 14% to 8% of frame height
	local tabPx = clamp(math.floor(H * 0.08), 60, 90)  -- Much smaller!
	local pillRatio = 3.5  -- width = height * 3.5 (slightly adjusted)
	local tabW = math.floor(tabPx * pillRatio)

	-- ✅ FIXED: Tabs container now properly sized
	-- Height is the button height, width scales with frame width (not height!)
	tabs.Size = UDim2.new(0.75, 0, 0, tabPx)
	
	-- Set button sizes
	cashTab.Size = UDim2.fromOffset(tabW, tabPx)
	gpTab.Size   = UDim2.fromOffset(tabW, tabPx)

	-- Content panel proportional to frame
	local contentH = math.floor(H * 0.48)
	content.Size = UDim2.new(0.86, 0, 0, contentH)
end

-- Connect resize to frame changes and heartbeat
frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeSafe)
RunService.Heartbeat:Connect(function() resizeSafe() end)
resizeSafe()

print("✅ [SanrioShop] FIXED - Button sizing now correct!")

--------------------------------------------------------------------------------
-- OPTIONAL: expose a simple toggle API for other scripts
--------------------------------------------------------------------------------
local RemotesFolder = ReplicatedStorage:FindFirstChild("TycoonRemotes") or Instance.new("Folder")
RemotesFolder.Name = "TycoonRemotes"
RemotesFolder.Parent = ReplicatedStorage

local ToggleShopEvent = RemotesFolder:FindFirstChild("ToggleShopEvent") or Instance.new("BindableEvent")
ToggleShopEvent.Name = "ToggleShopEvent"
ToggleShopEvent.Parent = RemotesFolder

ToggleShopEvent.Event:Connect(function(open)
	gui.Enabled = (open ~= false)
end)

--------------------------------------------------------------------------------
-- END
--------------------------------------------------------------------------------
