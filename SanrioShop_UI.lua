--[[
    SANRIO SHOP - UI MODULE
    Place this as a ModuleScript inside CreateMoneyShop LocalScript
    Name: SanrioShop_UI
--]]

local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Core = require(script.Parent.SanrioShop_Core)

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
			
			kitty = Color3.fromRGB(255, 64, 64),
			melody = Color3.fromRGB(255, 187, 204),
			kuromi = Color3.fromRGB(200, 190, 255),
			cinna = Color3.fromRGB(186, 214, 255),
			pompom = Color3.fromRGB(255, 220, 110),
		},
	}
}

function UI.Theme:get(key)
	return self.themes[self.current][key] or Color3.new(1, 1, 1)
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
		if key ~= "children" and key ~= "parent" and key ~= "onClick" and 
			key ~= "cornerRadius" and key ~= "stroke" and key ~= "shadow" and 
			key ~= "layout" and key ~= "padding" then
			
			if type(value) == "function" and key:sub(1, 2) == "on" then
				local eventName = key:sub(3)
				local connection = self.instance[eventName]:Connect(value)
				table.insert(self.eventConnections, connection)
			else
				pcall(function()
					self.instance[key] = value
				end)
			end
		end
	end
	
	if self.props.onClick and self.instance:IsA("TextButton") then
		local connection = self.instance.MouseButton1Click:Connect(self.props.onClick)
		table.insert(self.eventConnections, connection)
	end
end

function Component:render()
	self:applyProps()
	
	-- Add corner radius
	if self.props.cornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = self.props.cornerRadius
		corner.Parent = self.instance
	end
	
	-- Add stroke
	if self.props.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = self.props.stroke.color or UI.Theme:get("stroke")
		stroke.Thickness = self.props.stroke.thickness or 1
		stroke.Transparency = self.props.stroke.transparency or 0
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = self.instance
	end
	
	-- Add layout
	if self.props.layout then
		local layoutType = self.props.layout.type or "List"
		local layout = Instance.new("UI" .. layoutType .. "Layout")
		
		for key, value in pairs(self.props.layout) do
			if key ~= "type" then
				pcall(function()
					layout[key] = value
				end)
			end
		end
		
		layout.Parent = self.instance
		
		-- Auto-size canvas for ScrollingFrames
		if self.instance:IsA("ScrollingFrame") and layoutType == "List" then
			layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				if self.instance.ScrollingDirection == Enum.ScrollingDirection.X then
					self.instance.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X + 20, 0, 0)
				else
					self.instance.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
				end
			end)
		elseif self.instance:IsA("ScrollingFrame") and layoutType == "Grid" then
			layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				self.instance.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
			end)
		end
	end
	
	-- Add padding
	if self.props.padding then
		local padding = Instance.new("UIPadding")
		if self.props.padding.top then padding.PaddingTop = UDim.new(0, self.props.padding.top) end
		if self.props.padding.bottom then padding.PaddingBottom = UDim.new(0, self.props.padding.bottom) end
		if self.props.padding.left then padding.PaddingLeft = UDim.new(0, self.props.padding.left) end
		if self.props.padding.right then padding.PaddingRight = UDim.new(0, self.props.padding.right) end
		padding.Parent = self.instance
	end
	
	-- Render children
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
	
	return Component.new("Frame", props)
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
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollingDirection = props.ScrollingDirection or Enum.ScrollingDirection.Y,
	}
	
	for key, value in pairs(defaultProps) do
		if props[key] == nil then
			props[key] = value
		end
	end
	
	return Component.new("ScrollingFrame", props)
end

-- Layout Utilities
UI.Layout = {}

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

return UI
