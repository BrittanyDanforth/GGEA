--[[
    SANRIO SHOP SYSTEM - UI MODULE
    Advanced UI Components and Layout System
--]]

local Core = require(script.Parent.SanrioShop_Core)
local TweenService = game:GetService("TweenService")

local UI = {}

-- Theme System
UI.Theme = {
	current = "light",
	themes = {
		light = {
			background = Color3.fromRGB(253, 252, 250),
			surface = Color3.fromRGB(255, 255, 255),
			surfaceAlt = Color3.fromRGB(246, 248, 252),
			stroke = Color3.fromRGB(222, 226, 235),
			text = Color3.fromRGB(35, 38, 46),
			textSecondary = Color3.fromRGB(120, 126, 140),
			accent = Color3.fromRGB(255, 64, 129),
			accentAlt = Color3.fromRGB(186, 214, 255),
			success = Color3.fromRGB(76, 175, 80),
			warning = Color3.fromRGB(255, 152, 0),
			error = Color3.fromRGB(244, 67, 54),

			-- Character specific colors
			kitty = Color3.fromRGB(255, 64, 64),
			melody = Color3.fromRGB(255, 187, 204),
			kuromi = Color3.fromRGB(200, 190, 255),
			cinna = Color3.fromRGB(186, 214, 255),
			pompom = Color3.fromRGB(255, 220, 110),
		},
		dark = {
			background = Color3.fromRGB(18, 18, 20),
			surface = Color3.fromRGB(28, 28, 32),
			surfaceAlt = Color3.fromRGB(38, 38, 44),
			stroke = Color3.fromRGB(58, 58, 66),
			text = Color3.fromRGB(240, 240, 248),
			textSecondary = Color3.fromRGB(160, 160, 170),
			accent = Color3.fromRGB(255, 64, 129),
			accentAlt = Color3.fromRGB(138, 180, 248),
			success = Color3.fromRGB(76, 175, 80),
			warning = Color3.fromRGB(255, 152, 0),
			error = Color3.fromRGB(244, 67, 54),

			kitty = Color3.fromRGB(255, 80, 80),
			melody = Color3.fromRGB(255, 197, 214),
			kuromi = Color3.fromRGB(210, 200, 255),
			cinna = Color3.fromRGB(196, 224, 255),
			pompom = Color3.fromRGB(255, 230, 120),
		}
	}
}

function UI.Theme:get(key)
	return self.themes[self.current][key] or Color3.new(1, 1, 1)
end

function UI.Theme:switch(themeName)
	if self.themes[themeName] then
		self.current = themeName
		Core.Events:emit("themeChanged", themeName)
	end
end

-- Component Factory
UI.Components = {}

-- Base Component Class
local Component = {}
Component.__index = Component

function Component.new(className, props)
	local self = setmetatable({}, Component)
	self.instance = Instance.new(className)
	self.props = props or {}
	self.children = {}
	self.eventConnections = {}
	return self
end

function Component:applyProps()
	for key, value in pairs(self.props) do
		if key ~= "children" and key ~= "parent" then
			if type(value) == "function" and key:sub(1, 2) == "on" then
				-- Event handler
				local eventName = key:sub(3)
				local connection = self.instance[eventName]:Connect(value)
				table.insert(self.eventConnections, connection)
			else
				-- Property
				self.instance[key] = value
			end
		end
	end
end

function Component:render()
	self:applyProps()

	if self.props.children then
		for _, child in ipairs(self.props.children) do
			if typeof(child) == "table" and child.render then
				child:render()
				child.instance.Parent = self.instance
			elseif typeof(child) == "Instance" then
				child.Parent = self.instance
			end
		end
	end

	if self.props.parent then
		self.instance.Parent = self.props.parent
	end

	return self.instance
end

function Component:destroy()
	for _, connection in ipairs(self.eventConnections) do
		connection:Disconnect()
	end
	self.instance:Destroy()
end

-- Frame Component
function UI.Components.Frame(props)
	local defaultProps = {
		BackgroundColor3 = UI.Theme:get("surface"),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}

	for key, value in pairs(defaultProps) do
		if props[key] == nil then
			props[key] = value
		end
	end

	local component = Component.new("Frame", props)

	-- Add corner radius if specified
	if props.cornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = props.cornerRadius
		corner.Parent = component.instance
	end

	-- Add stroke if specified
	if props.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = props.stroke.color or UI.Theme:get("stroke")
		stroke.Thickness = props.stroke.thickness or 1
		stroke.Transparency = props.stroke.transparency or 0
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = component.instance
	end

	-- Add shadow if specified
	if props.shadow then
		UI.Effects.addShadow(component.instance, props.shadow)
	end

	return component
end

-- Text Label Component
function UI.Components.TextLabel(props)
	local defaultProps = {
		BackgroundTransparency = 1,
		TextColor3 = UI.Theme:get("text"),
		Font = Enum.Font.Gotham,
		TextScaled = false,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 1),
	}

	for key, value in pairs(defaultProps) do
		if props[key] == nil then
			props[key] = value
		end
	end

	return Component.new("TextLabel", props)
end

-- Button Component
function UI.Components.Button(props)
	local defaultProps = {
		BackgroundColor3 = UI.Theme:get("accent"),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamMedium,
		TextScaled = false,
		Size = UDim2.fromOffset(120, 40),
		AutoButtonColor = false,
	}

	for key, value in pairs(defaultProps) do
		if props[key] == nil then
			props[key] = value
		end
	end

	local component = Component.new("TextButton", props)

	-- Add hover effects
	local originalSize = props.Size or defaultProps.Size
	local hoverScale = props.hoverScale or 1.05

	component.instance.MouseEnter:Connect(function()
		Core.SoundSystem.play("hover")
		Core.Animation.tween(component.instance, {
			Size = UDim2.new(
				originalSize.X.Scale * hoverScale,
				originalSize.X.Offset * hoverScale,
				originalSize.Y.Scale * hoverScale,
				originalSize.Y.Offset * hoverScale
			)
		}, Core.CONSTANTS.ANIM_FAST)
	end)

	component.instance.MouseLeave:Connect(function()
		Core.Animation.tween(component.instance, {
			Size = originalSize
		}, Core.CONSTANTS.ANIM_FAST)
	end)

	component.instance.MouseButton1Click:Connect(function()
		Core.SoundSystem.play("click")
	end)

	return component
end

-- Image Component
function UI.Components.Image(props)
	local defaultProps = {
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(100, 100),
	}

	for key, value in pairs(defaultProps) do
		if props[key] == nil then
			props[key] = value
		end
	end

	return Component.new("ImageLabel", props)
end

-- ScrollingFrame Component
function UI.Components.ScrollingFrame(props)
	local defaultProps = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UI.Theme:get("stroke"),
		Size = UDim2.fromScale(1, 1),
	}

	for key, value in pairs(defaultProps) do
		if props[key] == nil then
			props[key] = value
		end
	end

	local component = Component.new("ScrollingFrame", props)

	-- Add layout if specified
	if props.layout then
		local layoutType = props.layout.type or "List"
		local layout = Instance.new("UI" .. layoutType .. "Layout")

		for key, value in pairs(props.layout) do
			if key ~= "type" and layout[key] ~= nil then
				layout[key] = value
			end
		end

		layout.Parent = component.instance
	end

	-- Add padding if specified
	if props.padding then
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = props.padding.top or UDim.new(0, 0)
		padding.PaddingBottom = props.padding.bottom or UDim.new(0, 0)
		padding.PaddingLeft = props.padding.left or UDim.new(0, 0)
		padding.PaddingRight = props.padding.right or UDim.new(0, 0)
		padding.Parent = component.instance
	end

	return component
end

-- Input Field Component
function UI.Components.Input(props)
	local defaultProps = {
		BackgroundColor3 = UI.Theme:get("surfaceAlt"),
		TextColor3 = UI.Theme:get("text"),
		PlaceholderColor3 = UI.Theme:get("textSecondary"),
		Font = Enum.Font.Gotham,
		TextScaled = false,
		ClearTextOnFocus = false,
		Size = UDim2.fromOffset(200, 40),
	}

	for key, value in pairs(defaultProps) do
		if props[key] == nil then
			props[key] = value
		end
	end

	return Component.new("TextBox", props)
end

-- Effects Library
UI.Effects = {}

function UI.Effects.addShadow(instance, config)
	config = config or {}
	local shadowFrame = Instance.new("Frame")
	shadowFrame.Name = "Shadow"
	shadowFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	shadowFrame.BackgroundTransparency = config.transparency or 0.8
	shadowFrame.BorderSizePixel = 0
	shadowFrame.Size = UDim2.new(1, config.size or 10, 1, config.size or 10)
	shadowFrame.Position = UDim2.new(0, config.offset or 5, 0, config.offset or 5)
	shadowFrame.ZIndex = instance.ZIndex - 1
	shadowFrame.Parent = instance.Parent

	if instance:FindFirstChildOfClass("UICorner") then
		local corner = instance:FindFirstChildOfClass("UICorner"):Clone()
		corner.Parent = shadowFrame
	end

	local blur = Instance.new("ImageLabel")
	blur.Name = "Blur"
	blur.BackgroundTransparency = 1
	blur.Image = "rbxassetid://8992230853"
	blur.ImageColor3 = Color3.new(0, 0, 0)
	blur.ImageTransparency = config.blur or 0.5
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(99, 99, 99, 99)
	blur.Size = UDim2.new(1, 30, 1, 30)
	blur.Position = UDim2.new(0, -15, 0, -15)
	blur.ZIndex = instance.ZIndex - 2
	blur.Parent = shadowFrame

	return shadowFrame
end

function UI.Effects.addGlow(instance, color, size, transparency)
	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.Image = "rbxassetid://5028857084"
	glow.ImageColor3 = color or UI.Theme:get("accent")
	glow.ImageTransparency = transparency or 0.8
	glow.ScaleType = Enum.ScaleType.Slice
	glow.SliceCenter = Rect.new(24, 24, 24, 24)
	glow.Size = UDim2.new(1, size or 30, 1, size or 30)
	glow.Position = UDim2.new(0.5, 0, 0.5, 0)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.ZIndex = instance.ZIndex - 1
	glow.Parent = instance

	return glow
end

function UI.Effects.addShimmer(instance, speed)
	speed = speed or 2

	local shimmer = Instance.new("Frame")
	shimmer.Name = "Shimmer"
	shimmer.BackgroundColor3 = Color3.new(1, 1, 1)
	shimmer.BackgroundTransparency = 0.6
	shimmer.BorderSizePixel = 0
	shimmer.Size = UDim2.new(0, 100, 1, 0)
	shimmer.Position = UDim2.new(-0.5, 0, 0, 0)
	shimmer.ZIndex = instance.ZIndex + 1
	shimmer.Parent = instance

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Rotation = 45
	gradient.Parent = shimmer

	local connection
	connection = Core.Events:on("themeChanged", function()
		shimmer.BackgroundColor3 = UI.Theme:get("accent")
	end)

	local running = true
	task.spawn(function()
		while running and shimmer.Parent do
			Core.Animation.tween(shimmer, {
				Position = UDim2.new(1.5, 0, 0, 0)
			}, speed, Enum.EasingStyle.Linear)
			task.wait(speed + 1)
			shimmer.Position = UDim2.new(-0.5, 0, 0, 0)
		end
	end)

	return {
		instance = shimmer,
		stop = function()
			running = false
			if connection then connection() end
			shimmer:Destroy()
		end
	}
end

-- Layout Utilities
UI.Layout = {}

function UI.Layout.center(instance)
	instance.Position = UDim2.fromScale(0.5, 0.5)
	instance.AnchorPoint = Vector2.new(0.5, 0.5)
end

function UI.Layout.stack(parent, direction, spacing, padding)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction or Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, spacing or 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent

	if padding then
		local uiPadding = Instance.new("UIPadding")
		uiPadding.PaddingTop = UDim.new(0, padding.top or 0)
		uiPadding.PaddingBottom = UDim.new(0, padding.bottom or 0)
		uiPadding.PaddingLeft = UDim.new(0, padding.left or 0)
		uiPadding.PaddingRight = UDim.new(0, padding.right or 0)
		uiPadding.Parent = parent
	end

	return layout
end

function UI.Layout.grid(parent, cellSize, cellPadding, fillDirection)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = cellSize or UDim2.fromOffset(100, 100)
	layout.CellPadding = cellPadding or UDim2.fromOffset(10, 10)
	layout.FillDirection = fillDirection or Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent

	return layout
end

-- Responsive Design
UI.Responsive = {}

function UI.Responsive.scale(instance, baseSize)
	local camera = workspace.CurrentCamera
	if not camera then return end

	local scale = Instance.new("UIScale")
	scale.Parent = instance

	local function updateScale()
		local viewportSize = camera.ViewportSize
		local scaleFactor = math.min(viewportSize.X / 1920, viewportSize.Y / 1080)
		scaleFactor = Core.Utils.clamp(scaleFactor, 0.5, 1.5)

		if Core.Utils.isMobile() then
			scaleFactor = scaleFactor * 0.85
		end

		scale.Scale = scaleFactor
	end

	updateScale()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

	return scale
end

function UI.Responsive.breakpoint(instance, breakpoints)
	local camera = workspace.CurrentCamera
	if not camera then return end

	local function update()
		local width = camera.ViewportSize.X

		for breakpoint, properties in pairs(breakpoints) do
			if width <= breakpoint then
				for prop, value in pairs(properties) do
					instance[prop] = value
				end
				break
			end
		end
	end

	update()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
end

return UI