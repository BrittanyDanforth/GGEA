--[[
    SANRIO SHOP SYSTEM - PASTEL STORYBOOK EDITION
    Place this as a LocalScript in StarterPlayer > StarterPlayerScripts
    Name it: SanrioShop

    Highlights of this refresh:
    • Soft pastel palette inspired by Sanrio storefronts
    • Simplified layout with a spacious hero banner and gentle tab row
    • Refined product cards with clear ownership and toggle states
    • Maintains purchasing, caching, and remote communication logic
--]]

-- Services
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)

-- ========================================
-- CORE MODULE (Embedded)
-- ========================================
local Core = {}
Core.VERSION = "2.1.0"
Core.DEBUG = false

Core.CONSTANTS = {
    PANEL_SIZE = Vector2.new(1180, 780),
    PANEL_SIZE_MOBILE = Vector2.new(960, 680),
    CARD_SIZE = Vector2.new(480, 300),
    CARD_SIZE_MOBILE = Vector2.new(420, 260),

    ANIM_FAST = 0.15,
    ANIM_MEDIUM = 0.25,
    ANIM_SMOOTH = 0.32,

    CACHE_PRODUCT_INFO = 300,
    CACHE_OWNERSHIP = 60,

    PURCHASE_TIMEOUT = 15,
    RETRY_DELAY = 2,
    MAX_RETRIES = 3,
}

Core.State = {
    isOpen = false,
    isAnimating = false,
    currentTab = "Home",
    purchasePending = {},
    ownershipCache = {},
    productCache = {},
    initialized = false,
    settings = {
        soundEnabled = true,
        animationsEnabled = true,
        reducedMotion = false,
    }
}

Core.Events = { handlers = {} }

function Core.Events:on(eventName, handler)
    if not self.handlers[eventName] then
        self.handlers[eventName] = {}
    end
    table.insert(self.handlers[eventName], handler)
    return function()
        local index = table.find(self.handlers[eventName], handler)
        if index then
            table.remove(self.handlers[eventName], index)
        end
    end
end

function Core.Events:emit(eventName, ...)
    local listeners = self.handlers[eventName]
    if not listeners then return end
    for _, fn in ipairs(listeners) do
        task.spawn(fn, ...)
    end
end

-- Cache helper --------------------------------------------------------------
local Cache = {}
Cache.__index = Cache

function Cache.new(duration)
    return setmetatable({
        data = {},
        duration = duration or 300,
    }, Cache)
end

function Cache:set(key, value)
    self.data[key] = {
        value = value,
        timestamp = tick(),
    }
end

function Cache:get(key)
    local entry = self.data[key]
    if not entry then return nil end
    if tick() - entry.timestamp > self.duration then
        self.data[key] = nil
        return nil
    end
    return entry.value
end

function Cache:clear(key)
    if key then
        self.data[key] = nil
    else
        self.data = {}
    end
end

Core.Cache = Cache

local productCache = Cache.new(Core.CONSTANTS.CACHE_PRODUCT_INFO)
local ownershipCache = Cache.new(Core.CONSTANTS.CACHE_OWNERSHIP)

-- Utilities -----------------------------------------------------------------
Core.Utils = {}

function Core.Utils.isMobile()
    local camera = workspace.CurrentCamera
    if not camera then return false end
    local viewportSize = camera.ViewportSize
    return viewportSize.X < 1024 or GuiService:IsTenFootInterface()
end

function Core.Utils.formatNumber(number)
    local formatted = tostring(number)
    local k = 1
    while k ~= 0 do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    end
    return formatted
end

function Core.Utils.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function Core.Utils.blend(a, b, alpha)
    alpha = Core.Utils.clamp(alpha, 0, 1)
    return Color3.new(
        a.R + (b.R - a.R) * alpha,
        a.G + (b.G - a.G) * alpha,
        a.B + (b.B - a.B) * alpha
    )
end

-- Animation -----------------------------------------------------------------
Core.Animation = {}

function Core.Animation.tween(object, properties, duration, easingStyle, easingDirection)
    if not Core.State.settings.animationsEnabled then
        for property, value in pairs(properties) do
            object[property] = value
        end
        return
    end

    local tweenInfo = TweenInfo.new(
        duration or Core.CONSTANTS.ANIM_MEDIUM,
        easingStyle or Enum.EasingStyle.Quad,
        easingDirection or Enum.EasingDirection.Out
    )

    local tween = TweenService:Create(object, tweenInfo, properties)
    tween:Play()
    return tween
end

-- Sound System --------------------------------------------------------------
Core.SoundSystem = {}

function Core.SoundSystem.initialize()
    local sounds = {
        click = {id = "rbxassetid://876939830", volume = 0.45},
        hover = {id = "rbxassetid://10066936758", volume = 0.25},
        open = {id = "rbxassetid://452267918", volume = 0.5},
        close = {id = "rbxassetid://452267918", volume = 0.5},
        success = {id = "rbxassetid://1843528128", volume = 0.5},
        error = {id = "rbxassetid://63384199", volume = 0.45},
    }

    Core.SoundSystem.sounds = {}
    for name, config in pairs(sounds) do
        local sound = Instance.new("Sound")
        sound.Name = "SanrioShop_" .. name
        sound.SoundId = config.id
        sound.Volume = config.volume
        sound.Parent = SoundService
        Core.SoundSystem.sounds[name] = sound
    end
end

function Core.SoundSystem.play(soundName)
    if not Core.State.settings.soundEnabled then return end
    local sound = Core.SoundSystem.sounds[soundName]
    if sound then sound:Play() end
end

-- Data ----------------------------------------------------------------------
Core.DataManager = {}

Core.DataManager.products = {
    cash = {
        {
            id = 1897730242,
            amount = 1000,
            name = "1,000 Cash",
            description = "A light sprinkle to start decorating your tycoon.",
            icon = "rbxassetid://10709728059",
            featured = false,
            price = 0,
        },
        {
            id = 1897730373,
            amount = 5000,
            name = "5,000 Cash",
            description = "Bundle perfect for adding a new section quickly.",
            icon = "rbxassetid://10709728059",
            featured = true,
            price = 0,
        },
        {
            id = 1897730467,
            amount = 10000,
            name = "10,000 Cash",
            description = "A generous boost for steady expansion plans.",
            icon = "rbxassetid://10709728059",
            featured = false,
            price = 0,
        },
        {
            id = 1897730581,
            amount = 50000,
            name = "50,000 Cash",
            description = "Top-tier pack for finishing touches in style.",
            icon = "rbxassetid://10709728059",
            featured = true,
            price = 0,
        },
    },
    gamepasses = {
        {
            id = 1412171840,
            name = "Auto Collect",
            description = "Scoop every drop instantly while you explore.",
            icon = "rbxassetid://10709727148",
            price = 99,
            hasToggle = true,
        },
        {
            id = 1398974710,
            name = "2x Cash",
            description = "Keep your earnings doubled for the entire story.",
            icon = "rbxassetid://10709727148",
            price = 199,
            hasToggle = false,
        },
    },
}

function Core.DataManager.getProductInfo(productId)
    local cached = productCache:get(productId)
    if cached then return cached end

    local success, info = pcall(function()
        return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
    end)

    if success and info then
        productCache:set(productId, info)
        return info
    end

    return nil
end

function Core.DataManager.getGamePassInfo(passId)
    local cached = productCache:get("pass_" .. passId)
    if cached then return cached end

    local success, info = pcall(function()
        return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
    end)

    if success and info then
        productCache:set("pass_" .. passId, info)
        return info
    end

    return nil
end

function Core.DataManager.checkOwnership(passId)
    local cacheKey = Player.UserId .. "_" .. passId
    local cached = ownershipCache:get(cacheKey)
    if cached ~= nil then return cached end

    local success, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, passId)
    end)

    if success then
        ownershipCache:set(cacheKey, owns)
        return owns
    end

    return false
end

function Core.DataManager.refreshPrices()
    for _, product in ipairs(Core.DataManager.products.cash) do
        local info = Core.DataManager.getProductInfo(product.id)
        if info then
            product.price = info.PriceInRobux or 0
        end
    end

    for _, pass in ipairs(Core.DataManager.products.gamepasses) do
        local info = Core.DataManager.getGamePassInfo(pass.id)
        if info and info.PriceInRobux then
            pass.price = info.PriceInRobux
        end
    end
end

-- ========================================
-- UI MODULE (Embedded)
-- ========================================
local UI = {}

UI.Theme = {
    current = "pastel",
    themes = {
        pastel = {
            background = Color3.fromRGB(247, 245, 242),
            surface = Color3.fromRGB(255, 252, 248),
            surfaceAlt = Color3.fromRGB(250, 244, 239),
            header = Color3.fromRGB(255, 240, 245),
            stroke = Color3.fromRGB(228, 210, 208),
            muted = Color3.fromRGB(236, 228, 224),
            text = Color3.fromRGB(56, 48, 56),
            textSecondary = Color3.fromRGB(118, 106, 112),
            accent = Color3.fromRGB(252, 143, 170),
            accentAlt = Color3.fromRGB(194, 204, 255),
            success = Color3.fromRGB(126, 196, 148),
            warning = Color3.fromRGB(246, 196, 102),
            error = Color3.fromRGB(237, 120, 138),

            kitty = Color3.fromRGB(255, 170, 190),
            melody = Color3.fromRGB(255, 202, 218),
            kuromi = Color3.fromRGB(180, 172, 220),
            cinna = Color3.fromRGB(198, 220, 255),
            pompompurin = Color3.fromRGB(250, 215, 140),
        }
    }
}

function UI.Theme:get(key)
    local theme = self.themes[self.current]
    return theme and theme[key] or Color3.new(1, 1, 1)
end

UI.Components = {}

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

function Component:apply()
    for key, value in pairs(self.props) do
        if key ~= "children" and key ~= "parent" and key ~= "onClick" and
            key ~= "cornerRadius" and key ~= "stroke" and key ~= "padding" then

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

    if self.props.padding then
        local padding = Instance.new("UIPadding")
        for axis, value in pairs(self.props.padding) do
            local property = "Padding" .. axis:gsub("^%l", string.upper)
            padding[property] = value
        end
        padding.Parent = self.instance
    end

    if self.props.onClick and self.instance:IsA("TextButton") then
        local connection = self.instance.MouseButton1Click:Connect(self.props.onClick)
        table.insert(self.eventConnections, connection)
    end
end

function Component:render()
    self:apply()

    if self.props.cornerRadius then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = self.props.cornerRadius
        corner.Parent = self.instance
    end

    if self.props.stroke then
        local stroke = Instance.new("UIStroke")
        stroke.Color = self.props.stroke.color or UI.Theme:get("stroke")
        stroke.Thickness = self.props.stroke.thickness or 1
        stroke.Transparency = self.props.stroke.transparency or 0
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = self.instance
    end

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

function UI.Components.Frame(props)
    props = props or {}
    if props.BackgroundColor3 == nil then props.BackgroundColor3 = UI.Theme:get("surface") end
    if props.BorderSizePixel == nil then props.BorderSizePixel = 0 end
    return Component.new("Frame", props)
end

function UI.Components.TextLabel(props)
    props = props or {}
    if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
    if props.TextColor3 == nil then props.TextColor3 = UI.Theme:get("text") end
    if props.Font == nil then props.Font = Enum.Font.Gotham end
    if props.TextWrapped == nil then props.TextWrapped = true end
    return Component.new("TextLabel", props)
end

function UI.Components.Button(props)
    props = props or {}
    if props.BackgroundColor3 == nil then props.BackgroundColor3 = UI.Theme:get("accent") end
    if props.TextColor3 == nil then props.TextColor3 = Color3.new(1, 1, 1) end
    if props.Font == nil then props.Font = Enum.Font.GothamSemibold end
    if props.AutoButtonColor == nil then props.AutoButtonColor = false end
    if props.Size == nil then props.Size = UDim2.fromOffset(140, 44) end

    local component = Component.new("TextButton", props)
    local originalSize = props.Size

    component.instance.MouseEnter:Connect(function()
        Core.SoundSystem.play("hover")
        Core.Animation.tween(component.instance, {
            Size = UDim2.new(
                originalSize.X.Scale,
                originalSize.X.Offset + 4,
                originalSize.Y.Scale,
                originalSize.Y.Offset + 4
            )
        }, Core.CONSTANTS.ANIM_FAST)
    end)

    component.instance.MouseLeave:Connect(function()
        Core.Animation.tween(component.instance, { Size = originalSize }, Core.CONSTANTS.ANIM_FAST)
    end)

    component.instance.MouseButton1Click:Connect(function()
        Core.SoundSystem.play("click")
    end)

    return component
end

function UI.Components.Image(props)
    props = props or {}
    if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
    if props.Size == nil then props.Size = UDim2.fromOffset(100, 100) end
    if props.ScaleType == nil then props.ScaleType = Enum.ScaleType.Fit end
    return Component.new("ImageLabel", props)
end

function UI.Components.ScrollingFrame(props)
    props = props or {}
    if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
    if props.BorderSizePixel == nil then props.BorderSizePixel = 0 end
    if props.ScrollBarThickness == nil then props.ScrollBarThickness = 8 end
    if props.ScrollBarImageColor3 == nil then props.ScrollBarImageColor3 = UI.Theme:get("stroke") end
    if props.Size == nil then props.Size = UDim2.fromScale(1, 1) end
    if props.CanvasSize == nil then props.CanvasSize = UDim2.new(0, 0, 0, 0) end

    local component = Component.new("ScrollingFrame", props)
    local layoutConfig = props.layout

    if layoutConfig then
        local layout = Instance.new("UI" .. layoutConfig.type .. "Layout")
        for key, value in pairs(layoutConfig) do
            if key ~= "type" then
                layout[key] = value
            end
        end
        layout.Parent = component.instance

        task.defer(function()
            local function updateCanvas()
                if layoutConfig.type == "List" then
                    if props.ScrollingDirection == Enum.ScrollingDirection.X then
                        component.instance.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X + 24, 0, 0)
                    else
                        component.instance.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 24)
                    end
                else
                    component.instance.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 24)
                end
            end

            updateCanvas()
            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
        end)
    end

    if props.padding then
        local padding = Instance.new("UIPadding")
        if props.padding.top then padding.PaddingTop = props.padding.top end
        if props.padding.bottom then padding.PaddingBottom = props.padding.bottom end
        if props.padding.left then padding.PaddingLeft = props.padding.left end
        if props.padding.right then padding.PaddingRight = props.padding.right end
        padding.Parent = component.instance
    end

    return component
end

UI.Layout = {}

function UI.Layout.stack(parent, direction, spacing, padding)
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = direction or Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, spacing or 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = parent

    if padding then
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, padding.top or 0)
        pad.PaddingBottom = UDim.new(0, padding.bottom or 0)
        pad.PaddingLeft = UDim.new(0, padding.left or 0)
        pad.PaddingRight = UDim.new(0, padding.right or 0)
        pad.Parent = parent
    end

    return layout
end

UI.Responsive = {}

function UI.Responsive.scale(instance)
    local camera = workspace.CurrentCamera
    if not camera then return end

    local scale = Instance.new("UIScale")
    scale.Parent = instance

    local function updateScale()
        local viewportSize = camera.ViewportSize
        local scaleFactor = math.min(viewportSize.X / 1920, viewportSize.Y / 1080)
        scaleFactor = Core.Utils.clamp(scaleFactor, 0.6, 1.3)

        if Core.Utils.isMobile() then
            scaleFactor = scaleFactor * 0.9
        end

        scale.Scale = scaleFactor
    end

    updateScale()
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

    return scale
end

-- ========================================
-- MAIN SHOP IMPLEMENTATION
-- ========================================
local Shop = {}
Shop.__index = Shop

local shop

function Shop.new()
    local self = setmetatable({}, Shop)

    self.gui = nil
    self.mainPanel = nil
    self.tabContainer = nil
    self.contentContainer = nil
    self.currentTab = "Home"
    self.tabs = {}
    self.pages = {}
    self.toggleButton = nil
    self.blur = nil

    self:initialize()

    return self
end

function Shop:initialize()
    Core.SoundSystem.initialize()
    Core.DataManager.refreshPrices()

    self:createToggleButton()
    self:createMainInterface()
    self:setupRemoteHandlers()
    self:setupInputHandlers()

    Core.State.initialized = true
    Core.Events:emit("shopInitialized")
end

function Shop:createToggleButton()
    local toggleGui = PlayerGui:FindFirstChild("SanrioShopToggle") or Instance.new("ScreenGui")
    toggleGui.Name = "SanrioShopToggle"
    toggleGui.ResetOnSpawn = false
    toggleGui.DisplayOrder = 999
    toggleGui.Parent = PlayerGui

    self.toggleButton = UI.Components.Button({
        Name = "ShopToggle",
        Text = "Shop",
        Size = UDim2.fromOffset(160, 52),
        Position = UDim2.new(1, -24, 1, -24),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = UI.Theme:get("accent"),
        cornerRadius = UDim.new(0.5, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        parent = toggleGui,
        onClick = function()
            self:toggle()
        end,
    }):render()

    local icon = UI.Components.Image({
        Image = "rbxassetid://17398522865",
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.fromOffset(18, 12),
        parent = self.toggleButton,
    }):render()

    local label = UI.Components.TextLabel({
        Text = "Boutique",
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.fromOffset(58, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamMedium,
        TextSize = 18,
        TextColor3 = Color3.new(1, 1, 1),
        parent = self.toggleButton,
    }):render()

    self:addPulseAnimation(self.toggleButton)
end

function Shop:createMainInterface()
    self.gui = PlayerGui:FindFirstChild("SanrioShopMain") or Instance.new("ScreenGui")
    self.gui.Name = "SanrioShopMain"
    self.gui.ResetOnSpawn = false
    self.gui.DisplayOrder = 1000
    self.gui.Enabled = false
    self.gui.Parent = PlayerGui

    self.blur = Lighting:FindFirstChild("SanrioShopBlur") or Instance.new("BlurEffect")
    self.blur.Name = "SanrioShopBlur"
    self.blur.Size = 0
    self.blur.Parent = Lighting

    local dim = UI.Components.Frame({
        Name = "Dim",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.35,
        parent = self.gui,
    }):render()

    local panelSize = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE

    self.mainPanel = UI.Components.Frame({
        Name = "MainPanel",
        Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(0, 28),
        stroke = {
            color = UI.Theme:get("stroke"),
            thickness = 1,
            transparency = 0.2,
        },
        parent = self.gui,
    }):render()

    UI.Responsive.scale(self.mainPanel)

    local interior = UI.Components.Frame({
        Size = UDim2.new(1, -48, 1, -48),
        Position = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
        parent = self.mainPanel,
    }):render()

    self:createHeader(interior)
    self:createTabBar(interior)

    self.contentContainer = UI.Components.Frame({
        Name = "ContentContainer",
        Size = UDim2.new(1, 0, 1, -260),
        Position = UDim2.fromOffset(0, 220),
        BackgroundTransparency = 1,
        parent = interior,
    }):render()

    self:createPages()
    self:selectTab("Home")
end

function Shop:createHeader(parent)
    local header = UI.Components.Frame({
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 180),
        BackgroundColor3 = UI.Theme:get("header"),
        cornerRadius = UDim.new(0, 24),
        stroke = {
            color = UI.Theme:get("stroke"),
            thickness = 1,
            transparency = 0.4,
        },
        parent = parent,
    }):render()

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, UI.Theme:get("header")),
        ColorSequenceKeypoint.new(1, UI.Theme:get("accentAlt"))
    })
    gradient.Rotation = 20
    gradient.Parent = header

    local layout = UI.Layout.stack(header, Enum.FillDirection.Horizontal, 20, {
        left = 32,
        right = 32,
        top = 28,
        bottom = 28,
    })
    layout.VerticalAlignment = Enum.VerticalAlignment.Center

    local textColumn = UI.Components.Frame({
        Size = UDim2.new(0.6, 0, 1, 0),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        parent = header,
    }):render()

    UI.Components.TextLabel({
        Text = "Sanrio Boutique",
        Size = UDim2.new(1, 0, 0, 46),
        Font = Enum.Font.GothamBold,
        TextSize = 36,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = UI.Theme:get("text"),
        parent = textColumn,
    }):render()

    UI.Components.TextLabel({
        Text = "Browse gentle add-ons, boosts, and passes made to match your tycoon story.",
        Size = UDim2.new(1, 0, 0, 52),
        Position = UDim2.fromOffset(0, 54),
        Font = Enum.Font.Gotham,
        TextSize = 18,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = textColumn,
    }):render()

    UI.Components.Button({
        Text = "Close",
        Size = UDim2.fromOffset(120, 42),
        Position = UDim2.new(1, -20, 0, 20),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = UI.Theme:get("accent"),
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamMedium,
        TextSize = 18,
        cornerRadius = UDim.new(0.5, 0),
        parent = header,
        onClick = function()
            self:close()
        end,
    }):render()

    local imageHolder = UI.Components.Frame({
        Size = UDim2.new(0.4, 0, 1, 0),
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        parent = header,
    }):render()

    UI.Components.Image({
        Image = "rbxassetid://17398522865",
        Size = UDim2.fromScale(1, 1),
        ImageColor3 = Color3.new(1, 1, 1),
        parent = imageHolder,
    }):render()
end

function Shop:createTabBar(parent)
    self.tabContainer = UI.Components.Frame({
        Name = "TabContainer",
        Size = UDim2.new(1, 0, 0, 60),
        Position = UDim2.fromOffset(0, 190),
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        cornerRadius = UDim.new(0, 20),
        stroke = {
            color = UI.Theme:get("stroke"),
            thickness = 1,
            transparency = 0.3,
        },
        parent = parent,
        padding = {
            left = UDim.new(0, 20),
            right = UDim.new(0, 20),
            top = UDim.new(0, 10),
            bottom = UDim.new(0, 10),
        }
    }):render()

    local layout = UI.Layout.stack(self.tabContainer, Enum.FillDirection.Horizontal, 12)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = Enum.VerticalAlignment.Center

    local tabs = {
        {id = "Home", name = "Highlights", icon = "rbxassetid://8941080291", color = UI.Theme:get("kitty")},
        {id = "Cash", name = "Cash Bundles", icon = "rbxassetid://10709728059", color = UI.Theme:get("cinna")},
        {id = "Gamepasses", name = "Game Passes", icon = "rbxassetid://10709727148", color = UI.Theme:get("kuromi")},
    }

    for index, data in ipairs(tabs) do
        self:createTabButton(data, index)
    end
end

function Shop:createTabButton(data, order)
    local button = UI.Components.Button({
        Name = data.id .. "Tab",
        Text = "",
        Size = UDim2.fromOffset(170, 40),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(0.5, 0),
        stroke = {
            color = UI.Theme:get("stroke"),
            thickness = 1,
            transparency = 0.5,
        },
        LayoutOrder = order,
        parent = self.tabContainer,
        onClick = function()
            self:selectTab(data.id)
        end,
    }):render()

    local content = UI.Components.Frame({
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        parent = button,
    }):render()

    UI.Layout.stack(content, Enum.FillDirection.Horizontal, 8, {
        left = 14,
        right = 14,
    })

    local icon = UI.Components.Image({
        Image = data.icon,
        Size = UDim2.fromOffset(22, 22),
        LayoutOrder = 1,
        parent = content,
    }):render()

    local label = UI.Components.TextLabel({
        Text = data.name,
        Size = UDim2.new(1, -26, 1, 0),
        Font = Enum.Font.GothamMedium,
        TextSize = 16,
        TextColor3 = UI.Theme:get("text"),
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,
        parent = content,
    }):render()

    self.tabs[data.id] = {
        button = button,
        icon = icon,
        label = label,
        color = data.color,
    }
end

function Shop:createPages()
    self.pages.Home = self:createHomePage()
    self.pages.Cash = self:createCashPage()
    self.pages.Gamepasses = self:createGamepassesPage()
end

function Shop:createHomePage()
    local page = UI.Components.Frame({
        Name = "HomePage",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        parent = self.contentContainer,
    }):render()

    local scroll = UI.Components.ScrollingFrame({
        Size = UDim2.fromScale(1, 1),
        layout = {
            type = "List",
            Padding = UDim.new(0, 24),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
        },
        padding = {
            top = UDim.new(0, 12),
            bottom = UDim.new(0, 24),
            left = UDim.new(0, 12),
            right = UDim.new(0, 12),
        },
        parent = page,
    }):render()

    self:createHeroSection(scroll)

    UI.Components.TextLabel({
        Text = "Featured bundles",
        Size = UDim2.new(1, -48, 0, 34),
        Font = Enum.Font.GothamBold,
        TextSize = 24,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,
        parent = scroll,
    }):render()

    local featuredContainer = UI.Components.Frame({
        Size = UDim2.new(1, 0, 0, 320),
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        parent = scroll,
    }):render()

    local horizontal = UI.Components.ScrollingFrame({
        Size = UDim2.fromScale(1, 1),
        ScrollingDirection = Enum.ScrollingDirection.X,
        layout = {
            type = "List",
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 20),
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
        },
        padding = {
            left = UDim.new(0, 12),
            right = UDim.new(0, 12),
            top = UDim.new(0, 6),
            bottom = UDim.new(0, 6),
        },
        parent = featuredContainer,
    }):render()

    for _, product in ipairs(Core.DataManager.products.cash) do
        if product.featured then
            self:createProductCard(product, "cash", horizontal)
        end
    end

    return page
end

function Shop:createCashPage()
    local page = UI.Components.Frame({
        Name = "CashPage",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        parent = self.contentContainer,
    }):render()

    local grid = UI.Components.ScrollingFrame({
        Size = UDim2.fromScale(1, 1),
        layout = {
            type = "Grid",
            CellSize = Core.Utils.isMobile() and
                UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE_MOBILE.X, Core.CONSTANTS.CARD_SIZE_MOBILE.Y) or
                UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y),
            CellPadding = UDim2.fromOffset(20, 20),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
        },
        padding = {
            top = UDim.new(0, 20),
            bottom = UDim.new(0, 40),
            left = UDim.new(0, 12),
            right = UDim.new(0, 12),
        },
        parent = page,
    }):render()

    for _, product in ipairs(Core.DataManager.products.cash) do
        self:createProductCard(product, "cash", grid)
    end

    return page
end

function Shop:createGamepassesPage()
    local page = UI.Components.Frame({
        Name = "GamepassesPage",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        parent = self.contentContainer,
    }):render()

    local grid = UI.Components.ScrollingFrame({
        Size = UDim2.fromScale(1, 1),
        layout = {
            type = "Grid",
            CellSize = Core.Utils.isMobile() and
                UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE_MOBILE.X, Core.CONSTANTS.CARD_SIZE_MOBILE.Y) or
                UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y),
            CellPadding = UDim2.fromOffset(20, 20),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
        },
        padding = {
            top = UDim.new(0, 20),
            bottom = UDim.new(0, 40),
            left = UDim.new(0, 12),
            right = UDim.new(0, 12),
        },
        parent = page,
    }):render()

    for _, pass in ipairs(Core.DataManager.products.gamepasses) do
        self:createProductCard(pass, "gamepass", grid)
    end

    return page
end

function Shop:createHeroSection(parent)
    local hero = UI.Components.Frame({
        Name = "HeroSection",
        Size = UDim2.new(1, 0, 0, 260),
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        cornerRadius = UDim.new(0, 22),
        LayoutOrder = 1,
        stroke = {
            color = UI.Theme:get("stroke"),
            thickness = 1,
            transparency = 0.35,
        },
        parent = parent,
    }):render()

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, UI.Theme:get("surfaceAlt")),
        ColorSequenceKeypoint.new(1, UI.Theme:get("muted")),
    })
    gradient.Rotation = -10
    gradient.Parent = hero

    local heroLayout = UI.Layout.stack(hero, Enum.FillDirection.Horizontal, 20, {
        left = 28,
        right = 28,
        top = 32,
        bottom = 32,
    })
    heroLayout.VerticalAlignment = Enum.VerticalAlignment.Center

    local textColumn = UI.Components.Frame({
        Size = UDim2.new(0.6, 0, 1, 0),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        parent = hero,
    }):render()

    UI.Components.TextLabel({
        Text = "Your story, your pace",
        Size = UDim2.new(1, 0, 0, 40),
        Font = Enum.Font.GothamBold,
        TextSize = 28,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = textColumn,
    }):render()

    UI.Components.TextLabel({
        Text = "Stack cozy upgrades and unlock helpers whenever you are ready. Sanrio friends are cheering for you!",
        Size = UDim2.new(1, 0, 0, 72),
        Position = UDim2.fromOffset(0, 48),
        Font = Enum.Font.Gotham,
        TextSize = 16,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = textColumn,
    }):render()

    UI.Components.Button({
        Text = "View cash bundles",
        Size = UDim2.fromOffset(200, 46),
        Position = UDim2.fromOffset(0, 140),
        BackgroundColor3 = UI.Theme:get("accent"),
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamMedium,
        TextSize = 18,
        cornerRadius = UDim.new(0.5, 0),
        parent = textColumn,
        onClick = function()
            self:selectTab("Cash")
        end,
    }):render()

    local imageColumn = UI.Components.Frame({
        Size = UDim2.new(0.4, 0, 1, 0),
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        parent = hero,
    }):render()

    UI.Components.Image({
        Image = "rbxassetid://11427491081",
        Size = UDim2.fromScale(1, 1),
        ImageTransparency = 0,
        parent = imageColumn,
    }):render()

    return hero
end

function Shop:createProductCard(product, productType, parent)
    local isGamepass = productType == "gamepass"
    local accentColor = isGamepass and UI.Theme:get("kuromi") or UI.Theme:get("cinna")

    local card = UI.Components.Frame({
        Name = product.name .. "Card",
        Size = UDim2.fromOffset(
            Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.X or Core.CONSTANTS.CARD_SIZE.X,
            Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.Y or Core.CONSTANTS.CARD_SIZE.Y
        ),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(0, 18),
        stroke = {
            color = accentColor,
            thickness = 1,
            transparency = 0.4,
        },
        parent = parent,
    }):render()

    self:addCardHoverEffect(card)

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 16)
    padding.PaddingBottom = UDim.new(0, 16)
    padding.PaddingLeft = UDim.new(0, 18)
    padding.PaddingRight = UDim.new(0, 18)
    padding.Parent = card

    local layout = UI.Layout.stack(card, Enum.FillDirection.Vertical, 10)

    local header = UI.Components.Frame({
        Size = UDim2.new(1, 0, 0, 140),
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        cornerRadius = UDim.new(0, 14),
        parent = card,
        LayoutOrder = 1,
    }):render()

    UI.Components.Image({
        Image = product.icon or "rbxassetid://0",
        Size = UDim2.fromScale(0.7, 0.7),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        parent = header,
    }):render()

    local body = UI.Components.Frame({
        Size = UDim2.new(1, 0, 1, -150),
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        parent = card,
    }):render()

    UI.Components.TextLabel({
        Text = product.name,
        Size = UDim2.new(1, 0, 0, 28),
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = body,
    }):render()

    UI.Components.TextLabel({
        Text = product.description,
        Size = UDim2.new(1, 0, 0, 46),
        Position = UDim2.fromOffset(0, 30),
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = body,
    }):render()

    local priceText
    if isGamepass then
        priceText = string.format("R$%d", product.price or 0)
    else
        priceText = string.format("R$%d • %s Cash", product.price or 0, Core.Utils.formatNumber(product.amount))
    end

    UI.Components.TextLabel({
        Text = priceText,
        Size = UDim2.new(1, 0, 0, 22),
        Position = UDim2.fromOffset(0, 78),
        Font = Enum.Font.GothamMedium,
        TextSize = 16,
        TextColor3 = accentColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = body,
    }):render()

    local ownedAtRender = isGamepass and Core.DataManager.checkOwnership(product.id)

    local purchaseButton = UI.Components.Button({
        Text = ownedAtRender and "Owned" or "Purchase",
        Size = UDim2.new(1, 0, 0, 40),
        Position = UDim2.new(0, 0, 1, -40),
        BackgroundColor3 = ownedAtRender and UI.Theme:get("success") or accentColor,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        cornerRadius = UDim.new(0, 10),
        parent = body,
        onClick = function()
            if isGamepass and Core.DataManager.checkOwnership(product.id) then
                if product.hasToggle then
                    self:toggleGamepass(product)
                end
                return
            end
            self:promptPurchase(product, productType)
        end,
    }):render()

    product.cardInstance = card
    product.purchaseButton = purchaseButton

    if ownedAtRender and product.hasToggle then
        self:addToggleSwitch(product, body, accentColor)
    end

    return card
end

function Shop:addCardHoverEffect(card)
    local originalPosition = card.Position

    card.MouseEnter:Connect(function()
        Core.Animation.tween(card, {
            Position = UDim2.new(
                originalPosition.X.Scale,
                originalPosition.X.Offset,
                originalPosition.Y.Scale,
                originalPosition.Y.Offset - 6
            )
        }, Core.CONSTANTS.ANIM_FAST)
    end)

    card.MouseLeave:Connect(function()
        Core.Animation.tween(card, {
            Position = originalPosition
        }, Core.CONSTANTS.ANIM_FAST)
    end)
end

function Shop:addToggleSwitch(product, parent, accentColor)
    local toggleContainer = UI.Components.Frame({
        Name = "ToggleContainer",
        Size = UDim2.fromOffset(64, 32),
        Position = UDim2.new(1, -70, 0, 78),
        BackgroundColor3 = UI.Theme:get("muted"),
        cornerRadius = UDim.new(0.5, 0),
        parent = parent,
    }):render()

    local knob = UI.Components.Frame({
        Name = "Knob",
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(0.5, 0),
        parent = toggleContainer,
    }):render()

    local toggleState = false
    if Remotes then
        local getter = Remotes:FindFirstChild("GetAutoCollectState")
        if getter and getter:IsA("RemoteFunction") then
            local success, state = pcall(function()
                return getter:InvokeServer()
            end)
            if success and type(state) == "boolean" then
                toggleState = state
            end
        end
    end

    local function updateVisual()
        toggleContainer.BackgroundColor3 = toggleState and accentColor or UI.Theme:get("muted")
        Core.Animation.tween(knob, {
            Position = toggleState and UDim2.fromOffset(34, 2) or UDim2.fromOffset(2, 2)
        }, Core.CONSTANTS.ANIM_FAST)
    end

    updateVisual()

    product.toggleContainer = toggleContainer
    product.toggleKnob = knob
    product.toggleState = toggleState

    local clickArea = Instance.new("TextButton")
    clickArea.Text = ""
    clickArea.BackgroundTransparency = 1
    clickArea.Size = UDim2.fromScale(1, 1)
    clickArea.Parent = toggleContainer

    clickArea.MouseButton1Click:Connect(function()
        toggleState = not toggleState
        updateVisual()

        product.toggleState = toggleState

        if Remotes then
            local toggleRemote = Remotes:FindFirstChild("AutoCollectToggle")
            if toggleRemote and toggleRemote:IsA("RemoteEvent") then
                toggleRemote:FireServer(toggleState)
            end
        end

        Core.SoundSystem.play("click")
    end)
end

function Shop:toggleGamepass(product)
    if not product or not product.toggleContainer then return end

    local container = product.toggleContainer
    Core.Animation.tween(container, {
        Size = UDim2.fromOffset(72, 36)
    }, Core.CONSTANTS.ANIM_FAST)

    task.delay(Core.CONSTANTS.ANIM_FAST, function()
        if container.Parent then
            Core.Animation.tween(container, {
                Size = UDim2.fromOffset(64, 32)
            }, Core.CONSTANTS.ANIM_FAST)
        end
    end)
end

function Shop:addPulseAnimation(instance)
    local running = true

    task.spawn(function()
        while running and instance.Parent do
            Core.Animation.tween(instance, {
                Size = UDim2.fromOffset(166, 56)
            }, 1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(1.6)
            if not running or not instance.Parent then break end
            Core.Animation.tween(instance, {
                Size = UDim2.fromOffset(160, 52)
            }, 1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(1.6)
        end
    end)

    instance.AncestryChanged:Connect(function()
        if not instance.Parent then
            running = false
        end
    end)
end

function Shop:selectTab(tabId)
    if self.currentTab == tabId then return end

    for id, tab in pairs(self.tabs) do
        local isActive = id == tabId
        Core.Animation.tween(tab.button, {
            BackgroundColor3 = isActive and Core.Utils.blend(tab.color, UI.Theme:get("surface"), 0.5) or UI.Theme:get("surface"),
        }, Core.CONSTANTS.ANIM_FAST)

        local stroke = tab.button:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = isActive and tab.color or UI.Theme:get("stroke")
            stroke.Transparency = isActive and 0.15 or 0.5
        end

        tab.icon.ImageColor3 = isActive and tab.color or UI.Theme:get("text")
        tab.label.TextColor3 = isActive and tab.color or UI.Theme:get("text")
    end

    for id, page in pairs(self.pages) do
        page.Visible = id == tabId
        if id == tabId then
            page.Position = UDim2.fromOffset(0, 12)
            Core.Animation.tween(page, {
                Position = UDim2.new()
            }, Core.CONSTANTS.ANIM_SMOOTH, Enum.EasingStyle.Quad)
        end
    end

    self.currentTab = tabId
    Core.SoundSystem.play("click")
    Core.Events:emit("tabChanged", tabId)
end

function Shop:promptPurchase(product, productType)
    if productType == "gamepass" then
        if Core.DataManager.checkOwnership(product.id) then
            self:refreshProduct(product, productType)
            return
        end

        product.purchaseButton.Text = "Processing..."
        product.purchaseButton.Active = false

        Core.State.purchasePending[product.id] = {
            product = product,
            timestamp = tick(),
            type = productType,
        }

        local success = pcall(function()
            MarketplaceService:PromptGamePassPurchase(Player, product.id)
        end)

        if not success then
            product.purchaseButton.Text = "Purchase"
            product.purchaseButton.Active = true
            Core.State.purchasePending[product.id] = nil
        end

        task.delay(Core.CONSTANTS.PURCHASE_TIMEOUT, function()
            if Core.State.purchasePending[product.id] then
                product.purchaseButton.Text = "Purchase"
                product.purchaseButton.Active = true
                Core.State.purchasePending[product.id] = nil
            end
        end)
    else
        Core.State.purchasePending[product.id] = {
            product = product,
            timestamp = tick(),
            type = productType,
        }

        local success = pcall(function()
            MarketplaceService:PromptProductPurchase(Player, product.id)
        end)

        if not success then
            Core.State.purchasePending[product.id] = nil
        end
    end
end

function Shop:refreshProduct(product, productType)
    if productType == "gamepass" then
        local isOwned = Core.DataManager.checkOwnership(product.id)
        if product.purchaseButton then
            product.purchaseButton.Text = isOwned and "Owned" or "Purchase"
            product.purchaseButton.BackgroundColor3 = isOwned and UI.Theme:get("success") or UI.Theme:get("kuromi")
            product.purchaseButton.Active = true
        end

        if product.cardInstance then
            local stroke = product.cardInstance:FindFirstChildOfClass("UIStroke")
            if stroke then
                stroke.Color = isOwned and UI.Theme:get("success") or UI.Theme:get("kuromi")
            end
        end

        if isOwned and product.hasToggle and not product.toggleContainer and product.purchaseButton then
            local accent = UI.Theme:get("kuromi")
            self:addToggleSwitch(product, product.purchaseButton.Parent, accent)
        elseif not isOwned and product.toggleContainer then
            product.toggleContainer:Destroy()
            product.toggleContainer = nil
            product.toggleKnob = nil
            product.toggleState = nil
        end
    end
end

function Shop:refreshAllProducts()
    ownershipCache:clear()

    for _, pass in ipairs(Core.DataManager.products.gamepasses) do
        self:refreshProduct(pass, "gamepass")
    end

    Core.Events:emit("productsRefreshed")
end

function Shop:open()
    if Core.State.isOpen or Core.State.isAnimating then return end

    Core.State.isAnimating = true
    Core.State.isOpen = true

    Core.DataManager.refreshPrices()
    self:refreshAllProducts()

    self.gui.Enabled = true

    Core.Animation.tween(self.blur, {
        Size = 20
    }, Core.CONSTANTS.ANIM_MEDIUM)

    self.mainPanel.Position = UDim2.fromScale(0.5, 0.55)
    self.mainPanel.Size = UDim2.fromOffset(
        self.mainPanel.Size.X.Offset * 0.92,
        self.mainPanel.Size.Y.Offset * 0.92
    )

    Core.Animation.tween(self.mainPanel, {
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(
            Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE.X or Core.CONSTANTS.PANEL_SIZE.X,
            Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE.Y or Core.CONSTANTS.PANEL_SIZE.Y
        )
    }, Core.CONSTANTS.ANIM_SMOOTH, Enum.EasingStyle.Back)

    Core.SoundSystem.play("open")

    task.wait(Core.CONSTANTS.ANIM_SMOOTH)
    Core.State.isAnimating = false

    Core.Events:emit("shopOpened")
end

function Shop:close()
    if not Core.State.isOpen or Core.State.isAnimating then return end

    Core.State.isAnimating = true
    Core.State.isOpen = false

    Core.Animation.tween(self.blur, {
        Size = 0
    }, Core.CONSTANTS.ANIM_FAST)

    Core.Animation.tween(self.mainPanel, {
        Position = UDim2.fromScale(0.5, 0.55),
        Size = UDim2.fromOffset(
            self.mainPanel.Size.X.Offset * 0.92,
            self.mainPanel.Size.Y.Offset * 0.92
        )
    }, Core.CONSTANTS.ANIM_FAST)

    Core.SoundSystem.play("close")

    task.wait(Core.CONSTANTS.ANIM_FAST)
    self.gui.Enabled = false
    Core.State.isAnimating = false

    Core.Events:emit("shopClosed")
end

function Shop:toggle()
    if Core.State.isOpen then
        self:close()
    else
        self:open()
    end
end

function Shop:setupRemoteHandlers()
    if not Remotes then return end

    local purchaseConfirm = Remotes:FindFirstChild("GamepassPurchased")
    if purchaseConfirm and purchaseConfirm:IsA("RemoteEvent") then
        purchaseConfirm.OnClientEvent:Connect(function(passId)
            ownershipCache:clear()
            self:refreshAllProducts()
            Core.SoundSystem.play("success")
        end)
    end

    local productGrant = Remotes:FindFirstChild("ProductGranted") or Remotes:FindFirstChild("GrantProductCurrency")
    if productGrant and productGrant:IsA("RemoteEvent") then
        productGrant.OnClientEvent:Connect(function()
            Core.SoundSystem.play("success")
        end)
    end
end

function Shop:setupInputHandlers()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if input.KeyCode == Enum.KeyCode.M then
            self:toggle()
        elseif input.KeyCode == Enum.KeyCode.Escape and Core.State.isOpen then
            self:close()
        end
    end)

    if UserInputService.GamepadEnabled then
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == Enum.KeyCode.ButtonX then
                self:toggle()
            end
        end)
    end
end

-- Purchase callbacks --------------------------------------------------------
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
    if player ~= Player then return end

    local pending = Core.State.purchasePending[passId]
    if not pending then return end

    Core.State.purchasePending[passId] = nil

    if purchased then
        ownershipCache:clear()

        if pending.product.purchaseButton then
            pending.product.purchaseButton.Text = "Owned"
            pending.product.purchaseButton.BackgroundColor3 = UI.Theme:get("success")
            pending.product.purchaseButton.Active = true
        end

        Core.SoundSystem.play("success")

        task.wait(0.5)
        if pending.product.purchaseButton then
            pending.product.purchaseButton.Active = true
        end
        if shop and shop.refreshAllProducts then
            shop:refreshAllProducts()
        end
    else
        if pending.product.purchaseButton then
            pending.product.purchaseButton.Text = "Purchase"
            pending.product.purchaseButton.Active = true
        end
    end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, purchased)
    if player ~= Player then return end

    local pending = Core.State.purchasePending[productId]
    if not pending then return end

    Core.State.purchasePending[productId] = nil

    if purchased then
        Core.SoundSystem.play("success")

        if Remotes then
            local grantEvent = Remotes:FindFirstChild("GrantProductCurrency")
            if grantEvent and grantEvent:IsA("RemoteEvent") then
                grantEvent:FireServer(productId)
            end
        end
    end
end)

-- Initialize ----------------------------------------------------------------
shop = Shop.new()

Player.CharacterAdded:Connect(function()
    task.wait(1)
    if not shop.toggleButton or not shop.toggleButton.Parent then
        shop:createToggleButton()
    end
end)

-- Periodic refresh while open
task.spawn(function()
    while true do
        task.wait(30)
        if Core.State.isOpen then
            shop:refreshAllProducts()
        end
    end
end)

print("[SanrioShop] Pastel boutique ready!")

return shop
