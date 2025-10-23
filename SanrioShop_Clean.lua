--[[
    Sanrio Shop GUI — CLEAN SIMPLE VERSION
    
    Simple, clean button design with proper images
    No weird hit testing or complex code
--]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

-- Assets
local IMG_FRAME = "rbxassetid://83301831904885"
local IMG_GAMEPASSES = "rbxassetid://137846629770171"
local IMG_CASH = "rbxassetid://84262748186110"

-- Create ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name = "SanrioShop"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = pg

-- Main Frame with background
local mainFrame = Instance.new("ImageLabel")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.fromScale(0.8, 0.8)
mainFrame.Position = UDim2.fromScale(0.5, 0.5)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Image = IMG_FRAME
mainFrame.ScaleType = Enum.ScaleType.Fit
mainFrame.BackgroundTransparency = 1
mainFrame.Parent = gui

-- Keep it square
local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = 1
aspect.Parent = mainFrame

-- Button Container
local buttonContainer = Instance.new("Frame")
buttonContainer.Name = "ButtonContainer"
buttonContainer.Size = UDim2.new(0.8, 0, 0, 100)
buttonContainer.Position = UDim2.fromScale(0.5, 0.3)
buttonContainer.AnchorPoint = Vector2.new(0.5, 0.5)
buttonContainer.BackgroundTransparency = 1
buttonContainer.Parent = mainFrame

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
buttonLayout.Padding = UDim.new(0, 20)
buttonLayout.Parent = buttonContainer

-- Helper: Create a clean button with image
local function createButton(name, imageId)
	-- Container for the button (so image doesn't stretch)
	local btnContainer = Instance.new("Frame")
	btnContainer.Name = name .. "Container"
	btnContainer.Size = UDim2.fromOffset(280, 90)
	btnContainer.BackgroundTransparency = 1
	btnContainer.Parent = buttonContainer
	
	-- The actual clickable button
	local btn = Instance.new("TextButton")
	btn.Name = name .. "Button"
	btn.Size = UDim2.fromScale(1, 1)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = btnContainer
	
	-- Image on top
	local img = Instance.new("ImageLabel")
	img.Name = "Image"
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = imageId
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = btn
	
	-- Simple hover effect
	local originalSize = btnContainer.Size
	
	btn.MouseEnter:Connect(function()
		TweenService:Create(btnContainer, TweenInfo.new(0.15), {
			Size = UDim2.fromOffset(290, 95)
		}):Play()
	end)
	
	btn.MouseLeave:Connect(function()
		TweenService:Create(btnContainer, TweenInfo.new(0.15), {
			Size = originalSize
		}):Play()
	end)
	
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(btnContainer, TweenInfo.new(0.08), {
			Size = UDim2.fromOffset(270, 85)
		}):Play()
	end)
	
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(btnContainer, TweenInfo.new(0.1), {
			Size = UDim2.fromOffset(290, 95)
		}):Play()
	end)
	
	return btn
end

-- Create buttons
local cashBtn = createButton("Cash", IMG_CASH)
local gpBtn = createButton("Gamepasses", IMG_GAMEPASSES)

-- Content area
local contentFrame = Instance.new("Frame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(0.85, 0, 0.5, 0)
contentFrame.Position = UDim2.fromScale(0.5, 0.65)
contentFrame.AnchorPoint = Vector2.new(0.5, 0.5)
contentFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
contentFrame.BackgroundTransparency = 0.85
contentFrame.Parent = mainFrame

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 20)
contentCorner.Parent = contentFrame

-- Pages
local cashPage = Instance.new("ScrollingFrame")
cashPage.Name = "CashPage"
cashPage.Size = UDim2.fromScale(1, 1)
cashPage.BackgroundTransparency = 1
cashPage.BorderSizePixel = 0
cashPage.ScrollBarThickness = 6
cashPage.Visible = true
cashPage.Parent = contentFrame

local cashGrid = Instance.new("UIGridLayout")
cashGrid.CellSize = UDim2.new(0.48, 0, 0, 120)
cashGrid.CellPadding = UDim2.fromOffset(15, 15)
cashGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
cashGrid.Parent = cashPage

local gpPage = Instance.new("ScrollingFrame")
gpPage.Name = "GamepassPage"
gpPage.Size = UDim2.fromScale(1, 1)
gpPage.BackgroundTransparency = 1
gpPage.BorderSizePixel = 0
gpPage.ScrollBarThickness = 6
gpPage.Visible = false
gpPage.Parent = contentFrame

local gpGrid = Instance.new("UIGridLayout")
gpGrid.CellSize = UDim2.new(0.48, 0, 0, 120)
gpGrid.CellPadding = UDim2.fromOffset(15, 15)
gpGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
gpGrid.Parent = gpPage

-- Add demo items
for i = 1, 8 do
	local card = Instance.new("TextButton")
	card.Name = "CashCard" .. i
	card.Text = "💰 " .. (i * 1000) .. " Cash\nR$" .. (i * 10)
	card.TextSize = 18
	card.Font = Enum.Font.GothamBold
	card.TextColor3 = Color3.fromRGB(255, 255, 255)
	card.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
	card.AutoButtonColor = false
	card.Parent = cashPage
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card
	
	card.MouseButton1Click:Connect(function()
		print("Clicked Cash Pack " .. i)
	end)
end

local passNames = {"Auto-Collect", "2x Cash", "Faster Drops", "VIP Pass", "Boombox", "Extra Slots"}
for i, name in ipairs(passNames) do
	local card = Instance.new("TextButton")
	card.Name = "PassCard" .. i
	card.Text = "🎫 " .. name .. "\nR$" .. (i * 50)
	card.TextSize = 18
	card.Font = Enum.Font.GothamBold
	card.TextColor3 = Color3.fromRGB(255, 255, 255)
	card.BackgroundColor3 = Color3.fromRGB(200, 150, 255)
	card.AutoButtonColor = false
	card.Parent = gpPage
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card
	
	card.MouseButton1Click:Connect(function()
		print("Clicked Gamepass: " .. name)
	end)
end

-- Button clicks
cashBtn.MouseButton1Click:Connect(function()
	cashPage.Visible = true
	gpPage.Visible = false
	print("💰 Cash tab")
end)

gpBtn.MouseButton1Click:Connect(function()
	cashPage.Visible = false
	gpPage.Visible = true
	print("🎫 Gamepasses tab")
end)

-- Auto-resize canvas
cashGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	cashPage.CanvasSize = UDim2.new(0, 0, 0, cashGrid.AbsoluteContentSize.Y + 20)
end)

gpGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	gpPage.CanvasSize = UDim2.new(0, 0, 0, gpGrid.AbsoluteContentSize.Y + 20)
end)

print("✅ [SanrioShop] Clean version loaded!")
