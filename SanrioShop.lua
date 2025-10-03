--[[
    SANRIO SHOP SYSTEM - NEO REVAMP
    Drop this LocalScript into StarterPlayer > StarterPlayerScripts
    Name it: SanrioShop

    Visual overhaul highlights:
    • Full synthwave-inspired dashboard with side navigation
    • Layered glassmorphism, reactive glow accents, animated gradients
    • Product cards redesigned with modular badges + neon hover states
    • Sidebar quick stats & action button cluster for future expansion
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

Core.VERSION = "4.0.0"
Core.DEBUG = false

Core.CONSTANTS = {
    PANEL_SIZE = Vector2.new(1320, 840),
    PANEL_SIZE_MOBILE = Vector2.new(1040, 780),
    CARD_SIZE = Vector2.new(540, 320),
    CARD_SIZE_MOBILE = Vector2.new(480, 300),

    ANIM_FAST = 0.15,
    ANIM_MEDIUM = 0.25,
    ANIM_SLOW = 0.35,
    ANIM_FLOAT = 0.5,

    CACHE_PRODUCT_INFO = 300,
    CACHE_OWNERSHIP = 60,

    PURCHASE_TIMEOUT = 15,
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
        autoRefresh = true,
    }
}

Core.Events = { handlers = {} }

function Core.Events:on(eventName, handler)
    if not self.handlers[eventName] then
        self.handlers[eventName] = {}
    end
    table.insert(self.handlers[eventName], handler)
    return function()
        local idx = table.find(self.handlers[eventName], handler)
        if idx then
            table.remove(self.handlers[eventName], idx)
        end
    end
end

function Core.Events:emit(eventName, ...)
    local bucket = self.handlers[eventName]
    if not bucket then return end
    for _, fn in ipairs(bucket) do
        task.spawn(fn, ...)
    end
end

-- Cache helper
local Cache = {}
Cache.__index = Cache

function Cache.new(duration)
    return setmetatable({ duration = duration or 300, data = {} }, Cache)
end

function Cache:set(key, value)
    self.data[key] = { value = value, timestamp = tick() }
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

-- Utilities
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
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    end
    return formatted
end

function Core.Utils.blend(a, b, alpha)
    alpha = math.clamp(alpha, 0, 1)
    return Color3.new(
        a.R + (b.R - a.R) * alpha,
        a.G + (b.G - a.G) * alpha,
        a.B + (b.B - a.B) * alpha
    )
end

-- Animation helper
Core.Animation = {}

function Core.Animation.tween(object, properties, duration, easingStyle, easingDirection)
    if not Core.State.settings.animationsEnabled then
        for property, value in pairs(properties) do
            object[property] = value
        end
        return
    end

    local tween = TweenService:Create(
        object,
        TweenInfo.new(
            duration or Core.CONSTANTS.ANIM_MEDIUM,
            easingStyle or Enum.EasingStyle.Quad,
            easingDirection or Enum.EasingDirection.Out
        ),
        properties
    )
    tween:Play()
    return tween
end

-- Sound system
Core.SoundSystem = {}

function Core.SoundSystem.initialize()
    local sounds = {
        click = { id = "rbxassetid://876939830", volume = 0.45 },
        hover = { id = "rbxassetid://10066936758", volume = 0.25 },
        open = { id = "rbxassetid://1841717861", volume = 0.6 },
        close = { id = "rbxassetid://1841717861", volume = 0.6 },
        success = { id = "rbxassetid://183763515", volume = 0.6 },
        error = { id = "rbxassetid://138079675", volume = 0.45 },
    }

    Core.SoundSystem.sounds = {}

    for name, cfg in pairs(sounds) do
        local sound = Instance.new("Sound")
        sound.Name = "SanrioShop_" .. name
        sound.SoundId = cfg.id
        sound.Volume = cfg.volume
        sound.Parent = SoundService
        Core.SoundSystem.sounds[name] = sound
    end
end

function Core.SoundSystem.play(name)
    if not Core.State.settings.soundEnabled then return end
    local sound = Core.SoundSystem.sounds and Core.SoundSystem.sounds[name]
    if sound then sound:Play() end
end
-- Data layer
Core.DataManager = {}

Core.DataManager.products = {
    cash = {
        {
            id = 1897730242,
            amount = 1000,
            name = "Starter Cache",
            description = "Kick off with a neon-sized boost.",
            icon = "rbxassetid://10709728059",
            featured = false,
            price = 0,
        },
        {
            id = 1897730373,
            amount = 5000,
            name = "Urban Vault",
            description = "Enough cash to renovate an entire wing.",
            icon = "rbxassetid://10709728059",
            featured = true,
            price = 0,
        },
        {
            id = 1897730467,
            amount = 10000,
            name = "District Fortune",
            description = "Amplify production with serious capital.",
            icon = "rbxassetid://10709728059",
            featured = false,
            price = 0,
        },
        {
            id = 1897730581,
            amount = 50000,
            name = "Megacity Treasury",
            description = "Full send. Go beyond the skyline.",
            icon = "rbxassetid://10709728059",
            featured = true,
            price = 0,
        },
    },
    gamepasses = {
        {
            id = 1412171840,
            name = "Auto Collect",
            description = "Streamline income with autonomous drones.",
            icon = "rbxassetid://10709727148",
            price = 99,
            features = {
                "Hands-free payout sweep",
                "Stacks with VIP boosts",
                "Optimized for AFK farming",
            },
            hasToggle = true,
        },
        {
            id = 1398974710,
            name = "2x Cash",
            description = "Permanent double yield across the city.",
            icon = "rbxassetid://10709727148",
            price = 199,
            features = {
                "Applies to all generators",
                "Stacks with events",
                "Prime value upgrade",
            },
            hasToggle = false,
        },
    }
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
        if info then product.price = info.PriceInRobux or 0 end
    end
    for _, pass in ipairs(Core.DataManager.products.gamepasses) do
        local info = Core.DataManager.getGamePassInfo(pass.id)
        if info and info.PriceInRobux then
            pass.price = info.PriceInRobux
        end
    end
end

-- ========================================
-- UI MODULE
-- ========================================
local UI = {}

UI.Theme = {
    current = "synth",
    themes = {
        synth = {
            background = Color3.fromRGB(10, 8, 32),
            surface = Color3.fromRGB(20, 18, 48),
            surfaceAlt = Color3.fromRGB(28, 22, 62),
            surfaceSoft = Color3.fromRGB(18, 20, 60),
            stroke = Color3.fromRGB(88, 70, 190),
            text = Color3.fromRGB(235, 240, 255),
            textSecondary = Color3.fromRGB(150, 170, 210),
            accent = Color3.fromRGB(255, 94, 189),
            accentAlt = Color3.fromRGB(70, 192, 255),
            accentGlow = Color3.fromRGB(136, 104, 255),
            success = Color3.fromRGB(74, 222, 128),
            warning = Color3.fromRGB(255, 203, 87),
            error = Color3.fromRGB(255, 89, 112),
            cash = Color3.fromRGB(88, 255, 196),
            pass = Color3.fromRGB(139, 104, 255),
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
    self.connections = {}
    return self
end

function Component:applyProps()
    for key, value in pairs(self.props) do
        if key ~= "children" and key ~= "parent" and key ~= "cornerRadius"
            and key ~= "stroke" and key ~= "onClick" and key ~= "layout"
            and key ~= "padding" and key ~= "shadow" and key ~= "gradient" then
            if type(value) == "function" and key:sub(1, 2) == "on" then
                local eventName = key:sub(3)
                if self.instance[eventName] then
                    table.insert(self.connections, self.instance[eventName]:Connect(value))
                end
            else
                pcall(function()
                    self.instance[key] = value
                end)
            end
        end
    end

    if self.props.onClick and self.instance:IsA("TextButton") then
        table.insert(self.connections, self.instance.MouseButton1Click:Connect(self.props.onClick))
    end
end

function Component:render()
    self:applyProps()

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

    if self.props.gradient then
        local gradient = Instance.new("UIGradient")
        for key, value in pairs(self.props.gradient) do
            pcall(function()
                gradient[key] = value
            end)
        end
        gradient.Parent = self.instance
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

    if self.props.layout then
        local layout = Instance.new("UI" .. (self.props.layout.type or "List") .. "Layout")
        for prop, value in pairs(self.props.layout) do
            if prop ~= "type" then
                pcall(function()
                    layout[prop] = value
                end)
            end
        end
        layout.Parent = self.instance
    end

    if self.props.padding then
        local padding = Instance.new("UIPadding")
        for prop, value in pairs(self.props.padding) do
            pcall(function()
                padding["Padding" .. prop:gsub("^%l", string.upper)] = value
            end)
        end
        padding.Parent = self.instance
    end

    if self.props.parent then
        self.instance.Parent = self.props.parent
    end

    return self.instance
end

function Component:destroy()
    for _, connection in ipairs(self.connections) do
        connection:Disconnect()
    end
    self.instance:Destroy()
end

function UI.Components.Frame(props)
    local defaults = {
        BackgroundColor3 = UI.Theme:get("surface"),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
    }
    props = props or {}
    for key, value in pairs(defaults) do
        if props[key] == nil then props[key] = value end
    end
    return Component.new("Frame", props)
end

function UI.Components.TextLabel(props)
    local defaults = {
        BackgroundTransparency = 1,
        TextColor3 = UI.Theme:get("text"),
        Font = Enum.Font.Gotham,
        TextWrapped = true,
        Size = UDim2.fromScale(1, 1),
    }
    props = props or {}
    for key, value in pairs(defaults) do
        if props[key] == nil then props[key] = value end
    end
    return Component.new("TextLabel", props)
end

function UI.Components.Button(props)
    local defaults = {
        BackgroundColor3 = UI.Theme:get("accent"),
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
        Size = UDim2.fromOffset(120, 40),
    }
    props = props or {}
    for key, value in pairs(defaults) do
        if props[key] == nil then props[key] = value end
    end

    local component = Component.new("TextButton", props)
    component:render()

    if props.hoverScale then
        local baseSize = component.instance.Size
        component.instance.MouseEnter:Connect(function()
            Core.SoundSystem.play("hover")
            Core.Animation.tween(component.instance, { Size = UDim2.new(
                baseSize.X.Scale * props.hoverScale,
                baseSize.X.Offset * props.hoverScale,
                baseSize.Y.Scale * props.hoverScale,
                baseSize.Y.Offset * props.hoverScale
            ) }, Core.CONSTANTS.ANIM_FAST)
        end)
        component.instance.MouseLeave:Connect(function()
            Core.Animation.tween(component.instance, { Size = baseSize }, Core.CONSTANTS.ANIM_FAST)
        end)
    end

    component.instance.MouseButton1Click:Connect(function()
        Core.SoundSystem.play("click")
    end)

    return component
end

function UI.Components.Image(props)
    local defaults = {
        BackgroundTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        Size = UDim2.fromOffset(96, 96),
    }
    props = props or {}
    for key, value in pairs(defaults) do
        if props[key] == nil then props[key] = value end
    end
    return Component.new("ImageLabel", props)
end

function UI.Components.ScrollingFrame(props)
    local defaults = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 6,
        ScrollBarImageColor3 = UI.Theme:get("stroke"),
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = props and props.ScrollingDirection or Enum.ScrollingDirection.Y,
    }
    props = props or {}
    for key, value in pairs(defaults) do
        if props[key] == nil then props[key] = value end
    end

    local component = Component.new("ScrollingFrame", props)
    component:render()

    if props.layout then
        local layout = Instance.new("UI" .. (props.layout.type or "List") .. "Layout")
        for prop, value in pairs(props.layout) do
            if prop ~= "type" then
                pcall(function()
                    layout[prop] = value
                end)
            end
        end
        layout.Parent = component.instance

        task.defer(function()
            local function updateCanvas()
                if props.ScrollingDirection == Enum.ScrollingDirection.X then
                    component.instance.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X + 24, 0, 0)
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
        for prop, value in pairs(props.padding) do
            pcall(function()
                padding["Padding" .. prop:gsub("^%l", string.upper)] = value
            end)
        end
        padding.Parent = component.instance
    end

    return component
end

UI.Responsive = {}

UI.Layout = {}

function UI.Layout.stack(parent, direction, spacing, padding)
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = direction or Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, spacing or 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = parent

    if padding then
        local pad = Instance.new("UIPadding")
        pad.Parent = parent
        if padding.left then pad.PaddingLeft = padding.left end
        if padding.right then pad.PaddingRight = padding.right end
        if padding.top then pad.PaddingTop = padding.top end
        if padding.bottom then pad.PaddingBottom = padding.bottom end
    end

    return layout
end

function UI.Responsive.scale(instance)
    local camera = workspace.CurrentCamera
    if not camera then return end
    local scale = Instance.new("UIScale")
    scale.Parent = instance

    local function updateScale()
        local viewport = camera.ViewportSize
        local factor = math.min(viewport.X / 1920, viewport.Y / 1080)
        factor = math.clamp(factor, 0.55, 1.4)
        if Core.Utils.isMobile() then
            factor *= 0.9
        end
        scale.Scale = factor
    end

    updateScale()
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
-- ========================================
-- SHOP IMPLEMENTATION
-- ========================================
local Shop = {}
Shop.__index = Shop

function Shop.new()
    local self = setmetatable({}, Shop)
    self.gui = nil
    self.mainPanel = nil
    self.sidebar = nil
    self.contentArea = nil
    self.contentContainer = nil
    self.tabContainer = nil
    self.tabs = {}
    self.pages = {}
    self.currentTab = "Home"
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
    local toggleScreen = PlayerGui:FindFirstChild("SanrioShopToggle") or Instance.new("ScreenGui")
    toggleScreen.Name = "SanrioShopToggle"
    toggleScreen.ResetOnSpawn = false
    toggleScreen.DisplayOrder = 999
    toggleScreen.Parent = PlayerGui

    self.toggleButton = UI.Components.Button({
        Name = "ShopToggle",
        Text = "",
        Size = UDim2.fromOffset(74, 74),
        Position = UDim2.new(1, -32, 1, -32),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        cornerRadius = UDim.new(1, 0),
        stroke = {
            color = UI.Theme:get("accent"),
            thickness = 2,
            transparency = 0.2,
        },
        gradient = {
            Rotation = 135,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, UI.Theme:get("accent")),
                ColorSequenceKeypoint.new(1, UI.Theme:get("accentAlt")),
            })
        },
        parent = toggleScreen,
        onClick = function()
            self:toggle()
        end,
    }).instance

    UI.Components.Image({
        Name = "Glyph",
        Image = "rbxassetid://17398522865",
        Size = UDim2.fromOffset(36, 36),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.45),
        parent = self.toggleButton,
    }):render()

    UI.Components.TextLabel({
        Name = "Hint",
        Text = "OPEN",
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.fromScale(0.5, 0.85),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = UI.Theme:get("text"),
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

    UI.Components.Frame({
        Name = "DimLayer",
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
        BackgroundColor3 = UI.Theme:get("background"),
        cornerRadius = UDim.new(0, 32),
        stroke = {
            color = UI.Theme:get("stroke"),
            thickness = 1.5,
            transparency = 0.45,
        },
        parent = self.gui,
    }):render()

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, UI.Theme:get("surface")),
        ColorSequenceKeypoint.new(1, UI.Theme:get("surfaceAlt")),
    })
    gradient.Rotation = 130
    gradient.Parent = self.mainPanel

    local glow = Instance.new("ImageLabel")
    glow.Name = "Glow"
    glow.BackgroundTransparency = 1
    glow.Image = "rbxassetid://1095708"
    glow.ImageColor3 = UI.Theme:get("accentGlow")
    glow.ImageTransparency = 0.85
    glow.Size = UDim2.new(1.4, 0, 1.4, 0)
    glow.Position = UDim2.fromScale(-0.2, -0.2)
    glow.ZIndex = 0
    glow.Parent = self.mainPanel

    UI.Responsive.scale(self.mainPanel)

    local chrome = UI.Components.Frame({
        Name = "Chrome",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -96, 1, -96),
        Position = UDim2.fromOffset(48, 48),
        parent = self.mainPanel,
    }):render()

    local layout = UI.Layout.stack(chrome, Enum.FillDirection.Horizontal, 28)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    self.sidebar = UI.Components.Frame({
        Name = "Sidebar",
        Size = UDim2.new(0, 280, 1, 0),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(0, 26),
        stroke = {
            color = UI.Theme:get("stroke"),
            thickness = 1,
            transparency = 0.3,
        },
        parent = chrome,
    }):render()

    local sidebarGradient = Instance.new("UIGradient")
    sidebarGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, UI.Theme:get("surface")),
        ColorSequenceKeypoint.new(1, UI.Theme:get("surfaceAlt")),
    })
    sidebarGradient.Rotation = 90
    sidebarGradient.Parent = self.sidebar

    self.contentArea = UI.Components.Frame({
        Name = "ContentArea",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -300, 1, 0),
        LayoutOrder = 2,
        parent = chrome,
    }):render()

    self:createSidebar()
    self:createHeader()

    self.contentContainer = UI.Components.Frame({
        Name = "ContentContainer",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -180),
        Position = UDim2.fromOffset(0, 160),
        parent = self.contentArea,
    }):render()

    self:createPages()
    self:selectTab("Home")
end
function Shop:createSidebar()
    local header = UI.Components.Frame({
        Name = "SideHeader",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -32, 0, 120),
        Position = UDim2.fromOffset(16, 18),
        parent = self.sidebar,
    }):render()

    UI.Layout.stack(header, Enum.FillDirection.Vertical, 6)

    UI.Components.TextLabel({
        Text = "SANRIO",
        Font = Enum.Font.GothamBlack,
        TextSize = 32,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = header,
        Size = UDim2.new(1, 0, 0, 38),
    }):render()

    UI.Components.TextLabel({
        Text = "NEON MARKETPLACE",
        TextColor3 = UI.Theme:get("textSecondary"),
        Font = Enum.Font.Gotham,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = header,
        Size = UDim2.new(1, 0, 0, 22),
    }):render()

    local pulse = Instance.new("Frame")
    pulse.BackgroundTransparency = 1
    pulse.Size = UDim2.new(1, 0, 0, 8)
    pulse.Parent = header

    local pulseBar = Instance.new("Frame")
    pulseBar.BackgroundColor3 = UI.Theme:get("accent")
    pulseBar.Size = UDim2.new(0.45, 0, 1, 0)
    pulseBar.Parent = pulse
    local pulseCorner = Instance.new("UICorner")
    pulseCorner.CornerRadius = UDim.new(0.5, 0)
    pulseCorner.Parent = pulseBar

    self.tabContainer = UI.Components.Frame({
        Name = "Tabs",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -32, 1, -220),
        Position = UDim2.fromOffset(16, 148),
        parent = self.sidebar,
    }):render()

    UI.Layout.stack(self.tabContainer, Enum.FillDirection.Vertical, 12)

    local quickStats = UI.Components.Frame({
        Name = "QuickStats",
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        Size = UDim2.new(1, -32, 0, 110),
        Position = UDim2.fromOffset(16, self.sidebar.Size.Y.Offset - 120),
        cornerRadius = UDim.new(0, 18),
        stroke = {
            color = UI.Theme:get("stroke"),
            transparency = 0.5,
            thickness = 1,
        },
        parent = self.sidebar,
    }):render()

    local statLayout = UI.Layout.stack(quickStats, Enum.FillDirection.Vertical, 8, {
        left = UDim.new(0, 18),
        right = UDim.new(0, 18),
        top = UDim.new(0, 18),
        bottom = UDim.new(0, 18),
    })
    statLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

    UI.Components.TextLabel({
        Text = "Live Metrics",
        Font = Enum.Font.GothamSemibold,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = quickStats,
        Size = UDim2.new(1, 0, 0, 24),
    }):render()

    local hints = {
        { label = "Season", value = "Bloom Rush" },
        { label = "Daily Boost", value = "+20%" },
        { label = "Next Refresh", value = "02:15" },
    }

    for _, hint in ipairs(hints) do
        local row = UI.Components.Frame({
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            parent = quickStats,
        }):render()

        UI.Components.TextLabel({
            Text = hint.label,
            TextColor3 = UI.Theme:get("textSecondary"),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(0.6, 0, 1, 0),
            parent = row,
        }):render()

        UI.Components.TextLabel({
            Text = hint.value,
            TextColor3 = UI.Theme:get("accentAlt"),
            Font = Enum.Font.GothamBold,
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Right,
            Size = UDim2.new(1, 0, 1, 0),
            parent = row,
        }):render()
    end

    self:createTabBar()
end

function Shop:createHeader()
    local header = UI.Components.Frame({
        Name = "Header",
        BackgroundColor3 = UI.Theme:get("surface"),
        Size = UDim2.new(1, 0, 0, 140),
        cornerRadius = UDim.new(0, 26),
        stroke = {
            color = UI.Theme:get("stroke"),
            thickness = 1,
            transparency = 0.35,
        },
        parent = self.contentArea,
    }):render()

    local headerGradient = Instance.new("UIGradient")
    headerGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, UI.Theme:get("surface")),
        ColorSequenceKeypoint.new(1, UI.Theme:get("surfaceAlt")),
    })
    headerGradient.Rotation = 135
    headerGradient.Parent = header

    local headerLayout = UI.Layout.stack(header, Enum.FillDirection.Horizontal, 18, {
        left = UDim.new(0, 28),
        right = UDim.new(0, 28),
        top = UDim.new(0, 24),
        bottom = UDim.new(0, 24),
    })
    headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center

    local titleBlock = UI.Components.Frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(0.65, 0, 1, 0),
        parent = header,
    }):render()

    UI.Components.TextLabel({
        Text = "Neon District Hub",
        Font = Enum.Font.GothamBlack,
        TextSize = 34,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 44),
        parent = titleBlock,
    }):render()

    UI.Components.TextLabel({
        Text = "Upgrade your tycoon with curated boosts, shimmering cosmetics, and premium automation.",
        TextColor3 = UI.Theme:get("textSecondary"),
        Font = Enum.Font.Gotham,
        TextSize = 16,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -120, 0, 48),
        Position = UDim2.fromOffset(0, 48),
        parent = titleBlock,
    }):render()

    local quickActions = UI.Components.Frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(0.35, 0, 1, 0),
        parent = header,
    }):render()

    UI.Layout.stack(quickActions, Enum.FillDirection.Horizontal, 12)

    local actionButtons = {
        { label = "Gift Center", icon = "rbxassetid://6034767615" },
        { label = "Codes", icon = "rbxassetid://6031280882" },
        { label = "Support", icon = "rbxassetid://6034509993" },
    }

    for _, action in ipairs(actionButtons) do
        local btn = UI.Components.Button({
            Text = action.label,
            Size = UDim2.fromOffset(130, 42),
            BackgroundColor3 = UI.Theme:get("surfaceAlt"),
            TextColor3 = UI.Theme:get("text"),
            Font = Enum.Font.GothamSemibold,
            TextSize = 15,
            cornerRadius = UDim.new(0, 18),
            stroke = {
                color = UI.Theme:get("stroke"),
                transparency = 0.4,
            },
            parent = quickActions,
            onClick = function()
                Core.SoundSystem.play("hover")
            end,
        }).instance

        UI.Components.Image({
            Image = action.icon,
            Size = UDim2.fromOffset(18, 18),
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.fromScale(0.12, 0.5),
            parent = btn,
        }):render()

        UI.Components.TextLabel({
            Text = action.label,
            Font = Enum.Font.GothamSemibold,
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, -32, 1, 0),
            Position = UDim2.fromScale(0.32, 0),
            parent = btn,
        }):render()
    end

    UI.Components.Button({
        Name = "Close",
        Text = "Exit",
        Size = UDim2.fromOffset(96, 42),
        BackgroundColor3 = UI.Theme:get("error"),
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        cornerRadius = UDim.new(0, 18),
        parent = header,
        onClick = function()
            self:close()
        end,
    }).instance.Position = UDim2.new(1, -108, 0, 20)
end
function Shop:createTabBar()
    local tabData = {
        { id = "Home", name = "Spotlight", icon = "rbxassetid://6023426915", color = UI.Theme:get("accent") },
        { id = "Cash", name = "Cash Vault", icon = "rbxassetid://6031071053", color = UI.Theme:get("cash") },
        { id = "Gamepasses", name = "Elite Passes", icon = "rbxassetid://6034767615", color = UI.Theme:get("pass") },
    }

    for index, data in ipairs(tabData) do
        local tabButton = Instance.new("TextButton")
        tabButton.Name = data.id .. "Tab"
        tabButton.Text = ""
        tabButton.AutoButtonColor = false
        tabButton.Size = UDim2.new(1, 0, 0, 70)
        tabButton.BackgroundColor3 = UI.Theme:get("surfaceAlt")
        tabButton.BackgroundTransparency = 0.15
        tabButton.Parent = self.tabContainer

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 18)
        corner.Parent = tabButton

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1
        stroke.Transparency = 0.5
        stroke.Color = UI.Theme:get("stroke")
        stroke.Parent = tabButton

        local glow = Instance.new("UIGradient")
        glow.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, UI.Theme:get("surface")),
            ColorSequenceKeypoint.new(1, UI.Theme:get("surfaceAlt")),
        })
        glow.Rotation = 90
        glow.Parent = tabButton

        local content = Instance.new("Frame")
        content.BackgroundTransparency = 1
        content.Size = UDim2.new(1, -24, 1, -16)
        content.Position = UDim2.fromOffset(12, 8)
        content.Parent = tabButton

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.Padding = UDim.new(0, 12)
        layout.Parent = content

        local icon = Instance.new("ImageLabel")
        icon.Image = data.icon
        icon.BackgroundTransparency = 1
        icon.Size = UDim2.fromOffset(26, 26)
        icon.ImageColor3 = data.color
        icon.Parent = content

        local texts = Instance.new("Frame")
        texts.BackgroundTransparency = 1
        texts.Size = UDim2.new(1, -40, 1, 0)
        texts.Parent = content

        local textLayout = Instance.new("UIListLayout")
        textLayout.FillDirection = Enum.FillDirection.Vertical
        textLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        textLayout.Parent = texts

        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.Size = UDim2.new(1, 0, 0, 26)
        title.Font = Enum.Font.GothamSemibold
        title.TextSize = 18
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = UI.Theme:get("text")
        title.Text = data.name
        title.Parent = texts

        local hint = Instance.new("TextLabel")
        hint.BackgroundTransparency = 1
        hint.Size = UDim2.new(1, 0, 0, 18)
        hint.Font = Enum.Font.Gotham
        hint.TextSize = 14
        hint.TextXAlignment = Enum.TextXAlignment.Left
        hint.TextColor3 = UI.Theme:get("textSecondary")
        hint.Text = index == 1 and "Featured rotations" or index == 2 and "Boost raw income" or "Permanent perks"
        hint.Parent = texts

        tabButton.MouseButton1Click:Connect(function()
            self:selectTab(data.id)
            Core.SoundSystem.play("click")
        end)

        tabButton.MouseEnter:Connect(function()
            Core.SoundSystem.play("hover")
        end)

        self.tabs[data.id] = {
            button = tabButton,
            icon = icon,
            title = title,
            hint = hint,
            data = data,
        }
    end
end

function Shop:createPages()
    self.pages.Home = self:createHomePage()
    self.pages.Cash = self:createCashPage()
    self.pages.Gamepasses = self:createGamepassesPage()
end

function Shop:createHomePage()
    local page = UI.Components.Frame({
        Name = "HomePage",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        parent = self.contentContainer,
        Visible = false,
    }):render()

    local scroll = UI.Components.ScrollingFrame({
        Size = UDim2.fromScale(1, 1),
        layout = {
            type = "List",
            Padding = UDim.new(0, 28),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
        },
        padding = {
            top = UDim.new(0, 12),
            bottom = UDim.new(0, 18),
            left = UDim.new(0, 4),
            right = UDim.new(0, 4),
        },
        parent = page,
    }):render()

    self:createHeroSection(scroll)

    local spotlight = UI.Components.Frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -24, 0, 360),
        parent = scroll,
        LayoutOrder = 2,
    }):render()

    UI.Components.TextLabel({
        Text = "Spotlight Offers",
        Font = Enum.Font.GothamBold,
        TextSize = 26,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 34),
        parent = spotlight,
    }):render()

    local spotlightRail = UI.Components.ScrollingFrame({
        Size = UDim2.new(1, 0, 1, -54),
        Position = UDim2.fromOffset(0, 54),
        ScrollingDirection = Enum.ScrollingDirection.X,
        layout = {
            type = "List",
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 20),
        },
        parent = spotlight,
    }):render()

    for _, product in ipairs(Core.DataManager.products.cash) do
        if product.featured then
            self:createProductCard(product, "cash", spotlightRail.instance)
        end
    end

    return page
end

function Shop:createCashPage()
    local page = UI.Components.Frame({
        Name = "CashPage",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        parent = self.contentContainer,
        Visible = false,
    }):render()

    local scroll = UI.Components.ScrollingFrame({
        Size = UDim2.fromScale(1, 1),
        layout = {
            type = "Grid",
            CellSize = Core.Utils.isMobile() and
                UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE_MOBILE.X, Core.CONSTANTS.CARD_SIZE_MOBILE.Y) or
                UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y),
            CellPadding = UDim2.fromOffset(24, 24),
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

    for _, product in ipairs(Core.DataManager.products.cash) do
        self:createProductCard(product, "cash", scroll.instance)
    end

    return page
end

function Shop:createGamepassesPage()
    local page = UI.Components.Frame({
        Name = "GamepassesPage",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        parent = self.contentContainer,
        Visible = false,
    }):render()

    local scroll = UI.Components.ScrollingFrame({
        Size = UDim2.fromScale(1, 1),
        layout = {
            type = "Grid",
            CellSize = Core.Utils.isMobile() and
                UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE_MOBILE.X, Core.CONSTANTS.CARD_SIZE_MOBILE.Y) or
                UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y),
            CellPadding = UDim2.fromOffset(24, 24),
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

    for _, pass in ipairs(Core.DataManager.products.gamepasses) do
        self:createProductCard(pass, "gamepass", scroll.instance)
    end

    return page
end
function Shop:createHeroSection(parent)
    local hero = UI.Components.Frame({
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        Size = UDim2.new(1, -24, 0, 220),
        cornerRadius = UDim.new(0, 26),
        stroke = {
            color = UI.Theme:get("stroke"),
            transparency = 0.4,
            thickness = 1,
        },
        parent = parent,
        LayoutOrder = 1,
    }):render()

    local heroGradient = Instance.new("UIGradient")
    heroGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, UI.Theme:get("accent")),
        ColorSequenceKeypoint.new(1, UI.Theme:get("accentAlt")),
    })
    heroGradient.Rotation = 120
    heroGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.25),
        NumberSequenceKeypoint.new(1, 0.4),
    })
    heroGradient.Parent = hero

    local heroLayout = UI.Layout.stack(hero, Enum.FillDirection.Horizontal, 26, {
        left = UDim.new(0, 32),
        right = UDim.new(0, 32),
        top = UDim.new(0, 32),
        bottom = UDim.new(0, 32),
    })
    heroLayout.VerticalAlignment = Enum.VerticalAlignment.Center

    local textColumn = UI.Components.Frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(0.6, 0, 1, 0),
        parent = hero,
    }):render()

    UI.Components.TextLabel({
        Text = "Seasonal Bloom Drop",
        Font = Enum.Font.GothamBlack,
        TextSize = 32,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 40),
        parent = textColumn,
    }):render()

    UI.Components.TextLabel({
        Text = "Exclusive cherry blossom cosmetics + stacked economy boosts available for a limited rotation.",
        TextColor3 = UI.Theme:get("textSecondary"),
        Font = Enum.Font.Gotham,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 60),
        Position = UDim2.fromOffset(0, 46),
        parent = textColumn,
    }):render()

    local cta = UI.Components.Button({
        Text = "View Bloom Bundle",
        Size = UDim2.fromOffset(200, 48),
        BackgroundColor3 = UI.Theme:get("accent"),
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        cornerRadius = UDim.new(0, 20),
        parent = textColumn,
        onClick = function()
            self:selectTab("Gamepasses")
        end,
    }).instance
    cta.Position = UDim2.fromOffset(0, 120)

    local holoColumn = UI.Components.Frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(0.4, 0, 1, 0),
        parent = hero,
    }):render()

    UI.Components.Image({
        Image = "rbxassetid://10709727148",
        Size = UDim2.new(0.85, 0, 0.85, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        parent = holoColumn,
    }):render()

    local glow = Instance.new("ImageLabel")
    glow.Image = "rbxassetid://1095708"
    glow.BackgroundTransparency = 1
    glow.Size = UDim2.new(1.2, 0, 1.2, 0)
    glow.Position = UDim2.fromScale(-0.1, -0.1)
    glow.ImageTransparency = 0.7
    glow.ImageColor3 = UI.Theme:get("accentGlow")
    glow.Parent = holoColumn
end

function Shop:createProductCard(product, productType, parent)
    local isGamepass = productType == "gamepass"
    local accentColor = isGamepass and UI.Theme:get("pass") or UI.Theme:get("cash")

    local card = Instance.new("Frame")
    card.Name = product.name .. "Card"
    card.BackgroundColor3 = UI.Theme:get("surface")
    card.Size = UDim2.fromOffset(
        Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.X or Core.CONSTANTS.CARD_SIZE.X,
        Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.Y or Core.CONSTANTS.CARD_SIZE.Y
    )
    card.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 24)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = accentColor
    stroke.Thickness = 1
    stroke.Transparency = 0.35
    stroke.Parent = card

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Core.Utils.blend(accentColor, UI.Theme:get("surface"), 0.85)),
        ColorSequenceKeypoint.new(1, UI.Theme:get("surfaceAlt")),
    })
    gradient.Rotation = 120
    gradient.Parent = card

    local glass = Instance.new("Frame")
    glass.BackgroundColor3 = Color3.new(1, 1, 1)
    glass.BackgroundTransparency = 0.88
    glass.Size = UDim2.new(1, -28, 1, -28)
    glass.Position = UDim2.fromOffset(14, 14)
    glass.Parent = card

    local glassCorner = Instance.new("UICorner")
    glassCorner.CornerRadius = UDim.new(0, 20)
    glassCorner.Parent = glass

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 12)
    layout.Parent = glass

    local badge = Instance.new("Frame")
    badge.BackgroundColor3 = Core.Utils.blend(accentColor, Color3.new(0, 0, 0), 0.6)
    badge.BackgroundTransparency = 0.2
    badge.Size = UDim2.new(0, 120, 0, 26)
    badge.Parent = glass

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0, 12)
    badgeCorner.Parent = badge

    local badgeLabel = Instance.new("TextLabel")
    badgeLabel.BackgroundTransparency = 1
    badgeLabel.Size = UDim2.new(1, 0, 1, 0)
    badgeLabel.Font = Enum.Font.GothamSemibold
    badgeLabel.TextSize = 14
    badgeLabel.TextColor3 = Color3.new(1, 1, 1)
    badgeLabel.Text = isGamepass and "Premium Pass" or (product.featured and "Featured" or "Bundle")
    badgeLabel.Parent = badge

    local info = Instance.new("Frame")
    info.BackgroundTransparency = 1
    info.Size = UDim2.new(1, 0, 0, 96)
    info.Parent = glass

    local infoLayout = Instance.new("UIListLayout")
    infoLayout.FillDirection = Enum.FillDirection.Vertical
    infoLayout.Parent = info

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 32)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = UI.Theme:get("text")
    title.Text = product.name
    title.Parent = info

    local desc = Instance.new("TextLabel")
    desc.BackgroundTransparency = 1
    desc.Size = UDim2.new(1, 0, 0, 42)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 15
    desc.TextWrapped = true
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextColor3 = UI.Theme:get("textSecondary")
    desc.Text = product.description
    desc.Parent = info

    local iconWrap = Instance.new("Frame")
    iconWrap.BackgroundColor3 = Core.Utils.blend(accentColor, UI.Theme:get("surface"), 0.3)
    iconWrap.Size = UDim2.new(1, 0, 0, 120)
    iconWrap.Parent = glass

    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 18)
    iconCorner.Parent = iconWrap

    local icon = Instance.new("ImageLabel")
    icon.Image = product.icon or "rbxassetid://0"
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(0.6, 0, 0.6, 0)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.Parent = iconWrap

    local price = Instance.new("TextLabel")
    price.BackgroundTransparency = 1
    price.Size = UDim2.new(1, 0, 0, 26)
    price.Font = Enum.Font.GothamBold
    price.TextSize = 18
    price.TextXAlignment = Enum.TextXAlignment.Left
    price.TextColor3 = accentColor
    price.Text = isGamepass
        and ("R$" .. tostring(product.price or 0))
        or ("R$" .. tostring(product.price or 0) .. " · " .. Core.Utils.formatNumber(product.amount) .. " Cash")
    price.Parent = glass

    local footer = Instance.new("Frame")
    footer.BackgroundTransparency = 1
    footer.Size = UDim2.new(1, 0, 0, 40)
    footer.Parent = glass

    local purchaseButton = Instance.new("TextButton")
    purchaseButton.Text = "Purchase"
    purchaseButton.Font = Enum.Font.GothamBold
    purchaseButton.TextSize = 16
    purchaseButton.TextColor3 = Color3.new(1, 1, 1)
    purchaseButton.AutoButtonColor = false
    purchaseButton.BackgroundColor3 = accentColor
    purchaseButton.Size = UDim2.new(0.65, 0, 1, 0)
    purchaseButton.Parent = footer

    local purchaseCorner = Instance.new("UICorner")
    purchaseCorner.CornerRadius = UDim.new(0, 16)
    purchaseCorner.Parent = purchaseButton

    local owned = isGamepass and Core.DataManager.checkOwnership(product.id)
    if owned then
        purchaseButton.Text = "Owned"
        purchaseButton.BackgroundColor3 = UI.Theme:get("success")
        purchaseButton.Active = false
    end

    purchaseButton.MouseButton1Click:Connect(function()
        if not owned then
            self:promptPurchase(product, productType)
        elseif product.hasToggle then
            self:toggleGamepass(product)
        end
    end)

    local badgeInfo = Instance.new("TextLabel")
    badgeInfo.BackgroundTransparency = 1
    badgeInfo.Size = UDim2.new(0.32, 0, 1, 0)
    badgeInfo.Font = Enum.Font.Gotham
    badgeInfo.TextSize = 13
    badgeInfo.TextColor3 = UI.Theme:get("textSecondary")
    badgeInfo.TextXAlignment = Enum.TextXAlignment.Right
    badgeInfo.Text = isGamepass and "Permanent" or "Instant delivery"
    badgeInfo.Parent = footer

    self:addCardHoverEffect(card)

    product.cardInstance = card
    product.purchaseButton = purchaseButton

    if owned and product.hasToggle then
        self:addToggleSwitch(product, footer)
    end

    return card
end
function Shop:addCardHoverEffect(card)
    local scale = Instance.new("UIScale")
    scale.Scale = 1
    scale.Parent = card

    card.MouseEnter:Connect(function()
        Core.Animation.tween(scale, { Scale = 1.04 }, Core.CONSTANTS.ANIM_FAST, Enum.EasingStyle.Sine)
    end)

    card.MouseLeave:Connect(function()
        Core.Animation.tween(scale, { Scale = 1 }, Core.CONSTANTS.ANIM_FAST, Enum.EasingStyle.Sine)
    end)
end

function Shop:addToggleSwitch(product, parent)
    local toggleContainer = Instance.new("Frame")
    toggleContainer.Name = "ToggleContainer"
    toggleContainer.BackgroundColor3 = UI.Theme:get("surfaceAlt")
    toggleContainer.Size = UDim2.fromOffset(60, 26)
    toggleContainer.Position = UDim2.new(1, -70, 0.5, -13)
    toggleContainer.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = toggleContainer

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(24, 24)
    knob.Position = UDim2.fromOffset(2, 1)
    knob.BackgroundColor3 = UI.Theme:get("text")
    knob.Parent = toggleContainer

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0.5, 0)
    knobCorner.Parent = knob

    local state = false
    if Remotes then
        local getStateRemote = Remotes:FindFirstChild("GetAutoCollectState")
        if getStateRemote and getStateRemote:IsA("RemoteFunction") then
            local success, result = pcall(function()
                return getStateRemote:InvokeServer()
            end)
            if success and type(result) == "boolean" then
                state = result
            end
        end
    end

    local function refresh()
        toggleContainer.BackgroundColor3 = state and UI.Theme:get("success") or UI.Theme:get("surfaceAlt")
        Core.Animation.tween(knob, {
            Position = state and UDim2.fromOffset(34, 1) or UDim2.fromOffset(2, 1)
        }, Core.CONSTANTS.ANIM_FAST, Enum.EasingStyle.Sine)
    end

    refresh()

    local click = Instance.new("TextButton")
    click.BackgroundTransparency = 1
    click.Text = ""
    click.Size = UDim2.fromScale(1, 1)
    click.Parent = toggleContainer

    click.MouseButton1Click:Connect(function()
        state = not state
        refresh()
        if Remotes then
            local toggleRemote = Remotes:FindFirstChild("AutoCollectToggle")
            if toggleRemote and toggleRemote:IsA("RemoteEvent") then
                toggleRemote:FireServer(state)
            end
        end
        Core.SoundSystem.play("click")
    end)
end

function Shop:selectTab(tabId)
    if self.currentTab == tabId then return end

    for id, tab in pairs(self.tabs) do
        local active = id == tabId
        Core.Animation.tween(tab.button, {
            BackgroundColor3 = active and Core.Utils.blend(tab.data.color, UI.Theme:get("surface"), 0.7) or UI.Theme:get("surfaceAlt"),
            BackgroundTransparency = active and 0.05 or 0.2,
        }, Core.CONSTANTS.ANIM_FAST)

        local stroke = tab.button:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = active and tab.data.color or UI.Theme:get("stroke")
            stroke.Transparency = active and 0.1 or 0.5
        end

        tab.icon.ImageColor3 = active and tab.data.color or UI.Theme:get("textSecondary")
        tab.title.TextColor3 = active and tab.data.color or UI.Theme:get("text")
        tab.hint.TextColor3 = active and Core.Utils.blend(tab.data.color, UI.Theme:get("textSecondary"), 0.6) or UI.Theme:get("textSecondary")
    end

    for id, page in pairs(self.pages) do
        page.Visible = id == tabId
        if id == tabId then
            page.Position = UDim2.fromOffset(0, 12)
            Core.Animation.tween(page, { Position = UDim2.new() }, Core.CONSTANTS.ANIM_FLOAT, Enum.EasingStyle.Back)
        end
    end

    self.currentTab = tabId
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
    if productType ~= "gamepass" then return end

    local isOwned = Core.DataManager.checkOwnership(product.id)
    if product.purchaseButton then
        product.purchaseButton.Text = isOwned and "Owned" or "Purchase"
        product.purchaseButton.BackgroundColor3 = isOwned and UI.Theme:get("success") or UI.Theme:get("pass")
        product.purchaseButton.Active = not isOwned
    end

    if product.cardInstance then
        local stroke = product.cardInstance:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = isOwned and UI.Theme:get("success") or UI.Theme:get("pass")
            stroke.Transparency = isOwned and 0.15 or 0.35
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

    Core.Animation.tween(self.blur, { Size = 24 }, Core.CONSTANTS.ANIM_MEDIUM)

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
    }, Core.CONSTANTS.ANIM_FLOAT, Enum.EasingStyle.Back)

    Core.SoundSystem.play("open")

    task.wait(Core.CONSTANTS.ANIM_FLOAT)
    Core.State.isAnimating = false
    Core.Events:emit("shopOpened")
end

function Shop:close()
    if not Core.State.isOpen or Core.State.isAnimating then return end

    Core.State.isAnimating = true
    Core.State.isOpen = false

    Core.Animation.tween(self.blur, { Size = 0 }, Core.CONSTANTS.ANIM_FAST)
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
function Shop:toggleGamepass(product)
    if not product.hasToggle then return end
    if Remotes then
        local toggleRemote = Remotes:FindFirstChild("AutoCollectToggle")
        if toggleRemote and toggleRemote:IsA("RemoteEvent") then
            toggleRemote:FireServer()
        end
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
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.M then
            self:toggle()
        elseif input.KeyCode == Enum.KeyCode.Escape and Core.State.isOpen then
            self:close()
        end
    end)

    if UserInputService.GamepadEnabled then
        UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.KeyCode == Enum.KeyCode.ButtonX then
                self:toggle()
            end
        end)
    end
end

function Shop:addPulseAnimation(instance)
    local scale = Instance.new("UIScale")
    scale.Scale = 1
    scale.Parent = instance

    task.spawn(function()
        while instance.Parent do
            Core.Animation.tween(scale, { Scale = 1.08 }, 1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(1.4)
            if not instance.Parent then break end
            Core.Animation.tween(scale, { Scale = 1 }, 1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(1.4)
        end
    end)
end

-- Marketplace callbacks
local shop
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
            pending.product.purchaseButton.Active = false
        end
        Core.SoundSystem.play("success")
        task.wait(0.3)
        if shop then
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

shop = Shop.new()

Player.CharacterAdded:Connect(function()
    task.wait(1)
    if not shop.toggleButton or not shop.toggleButton.Parent then
        shop:createToggleButton()
    end
end)

task.spawn(function()
    while true do
        task.wait(30)
        if Core.State.isOpen then
            shop:refreshAllProducts()
        end
    end
end)

print("[SanrioShop] Neo revamp initialized!")

return shop
