--[[
	🎮 PRO PERFORMANCE MONITOR GUI
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	
	Real-time in-game performance overlay showing:
	- Events per second
	- Batch efficiency
	- Adaptive throttling status
	- Memory usage
	- FPS impact
	- Event queue size
	- Coalescing rate
	
	PUT IN: StarterPlayer > StarterPlayerScripts
	NAME: PRO_PerformanceMonitor
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for Ultra Optimizer to be ready
task.wait(5)

-- Check if player is admin/developer
local ADMIN_LIST = {"kinjys", "Player1"}  -- Add your username here
local isAdmin = table.find(ADMIN_LIST, player.Name) ~= nil

if not isAdmin then
	-- Not an admin, don't show GUI
	return
end

print("🎮 [PRO MONITOR] Initializing admin performance overlay...")

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ProPerformanceMonitor"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 350, 0, 400)
mainFrame.Position = UDim2.new(1, -360, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

-- Title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
title.BorderSizePixel = 0
title.Text = "🔥 ULTRA OPTIMIZER 🔥"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 18
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = title

-- Performance Score (big display)
local scoreFrame = Instance.new("Frame")
scoreFrame.Size = UDim2.new(1, -20, 0, 80)
scoreFrame.Position = UDim2.new(0, 10, 0, 50)
scoreFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
scoreFrame.BorderSizePixel = 0
scoreFrame.Parent = mainFrame

local scoreCorner = Instance.new("UICorner")
scoreCorner.CornerRadius = UDim.new(0, 8)
scoreCorner.Parent = scoreFrame

local scoreLabel = Instance.new("TextLabel")
scoreLabel.Size = UDim2.new(1, 0, 0.4, 0)
scoreLabel.BackgroundTransparency = 1
scoreLabel.Text = "PERFORMANCE SCORE"
scoreLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
scoreLabel.TextSize = 14
scoreLabel.Font = Enum.Font.Gotham
scoreLabel.Parent = scoreFrame

local scoreValue = Instance.new("TextLabel")
scoreValue.Name = "ScoreValue"
scoreValue.Size = UDim2.new(1, 0, 0.6, 0)
scoreValue.Position = UDim2.new(0, 0, 0.4, 0)
scoreValue.BackgroundTransparency = 1
scoreValue.Text = "100%"
scoreValue.TextColor3 = Color3.fromRGB(0, 255, 100)
scoreValue.TextSize = 32
scoreValue.Font = Enum.Font.GothamBold
scoreValue.Parent = scoreFrame

-- Stats Container
local statsContainer = Instance.new("ScrollingFrame")
statsContainer.Size = UDim2.new(1, -20, 1, -150)
statsContainer.Position = UDim2.new(0, 10, 0, 140)
statsContainer.BackgroundTransparency = 1
statsContainer.BorderSizePixel = 0
statsContainer.ScrollBarThickness = 4
statsContainer.Parent = mainFrame

local statsLayout = Instance.new("UIListLayout")
statsLayout.Padding = UDim.new(0, 5)
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
statsLayout.Parent = statsContainer

-- Helper function to create stat display
local function createStat(name, icon)
	local statFrame = Instance.new("Frame")
	statFrame.Size = UDim2.new(1, -10, 0, 35)
	statFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	statFrame.BorderSizePixel = 0
	statFrame.Parent = statsContainer
	
	local statCorner = Instance.new("UICorner")
	statCorner.CornerRadius = UDim.new(0, 6)
	statCorner.Parent = statFrame
	
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(0, 30, 1, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon
	iconLabel.TextSize = 18
	iconLabel.Parent = statFrame
	
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.5, -35, 1, 0)
	nameLabel.Position = UDim2.new(0, 35, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = name
	nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	nameLabel.TextSize = 12
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = statFrame
	
	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.Size = UDim2.new(0.5, -5, 1, 0)
	valueLabel.Position = UDim2.new(0.5, 0, 0, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = "0"
	valueLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	valueLabel.TextSize = 14
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.Parent = statFrame
	
	return statFrame
end

-- Create stats
local stats = {
	eventsReceived = createStat("Events Received", "📥"),
	eventsSent = createStat("Events Sent", "📤"),
	coalesced = createStat("Coalesced", "🔗"),
	batchSize = createStat("Avg Batch Size", "📊"),
	interval = createStat("Batch Interval", "⏱️"),
	queueSize = createStat("Queue Size", "📋"),
	memoryUsage = createStat("Memory Usage", "💾"),
	adaptiveAdj = createStat("Adaptive Adjust", "🎯"),
}

-- Toggle button
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 30, 0, 30)
toggleBtn.Position = UDim2.new(1, -40, 0, 5)
toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
toggleBtn.Text = "—"
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.TextSize = 18
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.Parent = mainFrame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = toggleBtn

local isMinimized = false
toggleBtn.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	if isMinimized then
		mainFrame:TweenSize(UDim2.new(0, 350, 0, 50), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
		toggleBtn.Text = "+"
	else
		mainFrame:TweenSize(UDim2.new(0, 350, 0, 400), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
		toggleBtn.Text = "—"
	end
end)

-- Make draggable
local dragging = false
local dragInput, mousePos, framePos

mainFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		mousePos = input.Position
		framePos = mainFrame.Position
	end
end)

mainFrame.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - mousePos
		mainFrame.Position = UDim2.new(
			framePos.X.Scale,
			framePos.X.Offset + delta.X,
			framePos.Y.Scale,
			framePos.Y.Offset + delta.Y
		)
	end
end)

-- Update loop
task.spawn(function()
	while true do
		task.wait(0.5)
		
		-- Get metrics from Ultra Optimizer
		if _G.UltraOptimizer then
			local metrics = _G.UltraOptimizer.GetMetrics()
			local queueSize = _G.UltraOptimizer.GetQueueSize()
			
			-- Update displays
			stats.eventsReceived.Value.Text = tostring(metrics.totalEventsReceived)
			stats.eventsSent.Value.Text = tostring(metrics.totalEventsSent)
			stats.coalesced.Value.Text = tostring(metrics.eventsCoalesced)
			stats.batchSize.Value.Text = string.format("%.1f", metrics.averageBatchSize)
			stats.interval.Value.Text = string.format("%.3fs", metrics.currentBatchInterval)
			stats.queueSize.Value.Text = tostring(queueSize)
			stats.memoryUsage.Value.Text = string.format("%.1f MB", metrics.memoryUsage / 1024)
			stats.adaptiveAdj.Value.Text = tostring(metrics.adaptiveAdjustments)
			
			-- Update performance score
			scoreValue.Text = string.format("%.1f%%", metrics.performanceScore)
			
			-- Color code performance score
			if metrics.performanceScore >= 90 then
				scoreValue.TextColor3 = Color3.fromRGB(0, 255, 100)
			elseif metrics.performanceScore >= 70 then
				scoreValue.TextColor3 = Color3.fromRGB(255, 200, 0)
			else
				scoreValue.TextColor3 = Color3.fromRGB(255, 50, 50)
			end
			
			-- Calculate efficiency
			if metrics.totalEventsReceived > 0 then
				local efficiency = (metrics.eventsCoalesced / metrics.totalEventsReceived) * 100
				stats.coalesced.Value.Text = string.format("%d (%.1f%%)", metrics.eventsCoalesced, efficiency)
			end
		else
			scoreValue.Text = "WAITING..."
			scoreValue.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
	end
end)

print("✅ [PRO MONITOR] Performance overlay active!")
