--[[
    SANRIO SHOP SYSTEM - SOFT PASTEL EDITION
    Place this as a LocalScript in StarterPlayer > StarterPlayerScripts
    Name it: SanrioShop

    Visual philosophy:
    • Calm pastel palette with soft depth instead of neon glow
    • Clean top navigation tabs with spacious layout
    • Product cards emphasize item art, readable text, and ownership states
    • Maintains functional parity with previous versions (purchasing, toggles, caching)
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

-- Remotes (optional but expected)
local Remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)

-- ========================================
-- CORE MODULE
-- ========================================
local Core = {}
Core.VERSION = "2.2.0"

Core.CONSTANTS = {
    PANEL_SIZE = Vector2.new(1180, 820),
    PANEL_SIZE_MOBILE = Vector2.new(920, 700),
    CARD_SIZE = Vector2.new(500, 300),
    CARD_SIZE_MOBILE = Vector2.new(440, 260),

    ANIM_FAST = 0.14,
    ANIM_MEDIUM = 0.25,
    ANIM_BOUNCE = 0.28,

    CACHE_PRODUCT_INFO = 300,
    CACHE_OWNERSHIP = 60,
    PURCHASE_TIMEOUT = 15,
}

Core.State = {
    isOpen = false,
    isAnimating = false,
    currentTab = "Home",
    purchasePending = {},
    initialized = false,
    settings = {
        soundEnabled = true,
        animationsEnabled = true,
    },
}

Core.Events = { handlers = {} }

function Core.Events:on(eventName, handler)
    if not self.handlers[eventName] then
        self.handlers[eventName] = {}
    end
    table.insert(self.handlers[eventName], handler)
    return function()
        local index = table.find(self.handlers[eventName], handler)
        if index then table.remove(self.handlers[eventName], index) end
    end
end

function Core.Events:emit(eventName, ...)
    local listeners = self.handlers[eventName]
    if not listeners then return end
    for _, fn in ipairs(listeners) do
        task.spawn(fn, ...)
    end
end

-- Caching -------------------------------------------------------------
local Cache = {}
Cache.__index = Cache

function Cache.new(duration)
    return setmetatable({ data = {}, duration = duration or 300 }, Cache)
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

-- Utilities -----------------------------------------------------------
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

function Core.Utils.clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

-- Animation ----------------------------------------------------------
Core.Animation = {}

function Core.Animation.tween(instance, properties, duration, easingStyle, easingDirection)
    if not Core.State.settings.animationsEnabled then
        for property, value in pairs(properties) do
            instance[property] = value
        end
        return
    end

    local tweenInfo = TweenInfo.new(
        duration or Core.CONSTANTS.ANIM_MEDIUM,
        easingStyle or Enum.EasingStyle.Quad,
        easingDirection or Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(instance, tweenInfo, properties)
    tween:Play()
    return tween
end

-- Sound --------------------------------------------------------------
Core.SoundSystem = {}

function Core.SoundSystem.initialize()
    local sounds = {
        click = { id = "rbxassetid://876939830", volume = 0.4 },
        hover = { id = "rbxassetid://10066936758", volume = 0.18 },
        open = { id = "rbxassetid://452267918", volume = 0.4 },
        close = { id = "rbxassetid://452267918", volume = 0.4 },
        success = { id = "rbxassetid://876939830", volume = 0.55 },
        notification = { id = "rbxassetid://876939830", volume = 0.4 },
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
    local sound = Core.SoundSystem.sounds and Core.SoundSystem.sounds[soundName]
    if sound then sound:Play() end
end

-- Data ---------------------------------------------------------------
Core.DataManager = {}

Core.DataManager.products = {
    cash = {
        {
            id = 1897730242,
            amount = 1000,
            name = "Starter Cash Bundle",
            description = "Great for unlocking your first upgrades.",
            icon = "rbxassetid://10709728059",
            featured = false,
            price = 0,
        },
        {
            id = 1897730373,
            amount = 5000,
            name = "Builder Cash Bundle",
            description = "Enough to plan out a cozy wing of your tycoon.",
            icon = "rbxassetid://10709728059",
            featured = true,
            price = 0,
        },
        {
            id = 1897730467,
            amount = 10000,
            name = "Designer Cash Bundle",
            description = "Accelerate expansion with a generous boost.",
            icon = "rbxassetid://10709728059",
            featured = false,
            price = 0,
        },
        {
            id = 1897730581,
            amount = 50000,
            name = "Dream Cash Bundle",
            description = "Perfect for completing late-game décor.",
            icon = "rbxassetid://10709728059",
            featured = true,
            price = 0,
        },
    },
    gamepasses = {
        {
            id = 1412171840,
            name = "Auto Collect",
            description = "Collect drops automatically so you can focus on decorating.",
            icon = "rbxassetid://10709727148",
            price = 99,
            features = {
                "Hands-free collection",
                "Works while AFK",
                "Pairs well with events",
            },
            hasToggle = true,
        },
        {
            id = 1398974710,
            name = "2x Cash",
            description = "Double your earnings permanently for faster progress.",
            icon = "rbxassetid://10709727148",
            price = 199,
            features = {
                "2x multiplier",
                "Stacks with boosts",
                "Best long-term value",
            },
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
        if info and info.PriceInRobux then
            product.price = info.PriceInRobux
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
-- UI MODULE
-- ========================================
local UI = {}

UI.Theme = {
    current = "pastel",
    themes = {
        pastel = {
            background = Color3.fromRGB(245, 244, 240),
            surface = Color3.fromRGB(255, 255, 255),
            surfaceAlt = Color3.fromRGB(250, 248, 247),
            stroke = Color3.fromRGB(214, 208, 205),
            divider = Color3.fromRGB(229, 224, 221),
            text = Color3.fromRGB(53, 55, 64),
            textSecondary = Color3.fromRGB(114, 118, 132),
            accent = Color3.fromRGB(240, 170, 180),
            accentAlt = Color3.fromRGB(206, 196, 235),
            highlight = Color3.fromRGB(188, 214, 233),
            success = Color3.fromRGB(104, 178, 130),
            warning = Color3.fromRGB(238, 188, 120),
            error = Color3.fromRGB(220, 120, 120),
        },
    },
}

function UI.Theme:get(key)
    local palette = self.themes[self.current]
    return palette and palette[key] or Color3.new(1, 1, 1)
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
            and key ~= "stroke" and key ~= "onClick" and key ~= "padding" and key ~= "layout" then
            if type(value) == "function" and key:sub(1, 2) == "on" then
                local eventName = key:sub(3)
                local connection = self.instance[eventName]:Connect(value)
                table.insert(self.connections, connection)
            else
                pcall(function()
                    self.instance[key] = value
                end)
            end
        end
    end

    if self.props.onClick and self.instance:IsA("TextButton") then
        local connection = self.instance.MouseButton1Click:Connect(self.props.onClick)
        table.insert(self.connections, connection)
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

    if self.props.padding then
        local padding = Instance.new("UIPadding")
        for axis, value in pairs(self.props.padding) do
            local property = "Padding" .. axis:sub(1, 1):upper() .. axis:sub(2)
            padding[property] = value
        end
        padding.Parent = self.instance
    end

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

        task.defer(function()
            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                if self.instance:IsA("ScrollingFrame") then
                    if self.instance.ScrollingDirection == Enum.ScrollingDirection.X then
                        self.instance.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X + 24, 0, 0)
                    else
                        self.instance.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 24)
                    end
                end
            end)
        end)
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
    for key, value in pairs(defaults) do
        if props[key] == nil then props[key] = value end
    end
    return Component.new("Frame", props)
end

function UI.Components.TextLabel(props)
    local defaults = {
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextColor3 = UI.Theme:get("text"),
        TextWrapped = true,
        Size = UDim2.fromScale(1, 1),
    }
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
        Size = UDim2.fromOffset(140, 44),
        AutoButtonColor = false,
    }
    for key, value in pairs(defaults) do
        if props[key] == nil then props[key] = value end
    end

    local component = Component.new("TextButton", props)

    local hoverScale = props.hoverScale or 1.03
    local originalSize = props.Size or defaults.Size

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
            Size = originalSize,
        }, Core.CONSTANTS.ANIM_FAST)
    end)

    component.instance.MouseButton1Click:Connect(function()
        Core.SoundSystem.play("click")
    end)

    return component
end

function UI.Components.Image(props)
    local defaults = {
        BackgroundTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
    }
    for key, value in pairs(defaults) do
        if props[key] == nil then props[key] = value end
    end
    return Component.new("ImageLabel", props)
end

function UI.Components.ScrollingFrame(props)
    local defaults = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 8,
        ScrollBarImageColor3 = UI.Theme:get("divider"),
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = props.ScrollingDirection or Enum.ScrollingDirection.Y,
    }
    for key, value in pairs(defaults) do
        if props[key] == nil then props[key] = value end
    end
    return Component.new("ScrollingFrame", props)
end

UI.Responsive = {}

function UI.Responsive.scale(instance)
    local camera = workspace.CurrentCamera
    if not camera then return end

    local scaler = Instance.new("UIScale")
    scaler.Parent = instance

    local function updateScale()
        local viewport = camera.ViewportSize
        local scaleFactor = math.min(viewport.X / 1920, viewport.Y / 1080)
        scaleFactor = Core.Utils.clamp(scaleFactor, 0.6, 1.2)
        if Core.Utils.isMobile() then
            scaleFactor = scaleFactor * 0.88
        end
        scaler.Scale = scaleFactor
    end

    updateScale()
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

    return scaler
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
    self.tabContainer = nil
    self.contentContainer = nil
    self.currentTab = nil
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

-- Toggle Button ------------------------------------------------------
function Shop:createToggleButton()
    local toggleScreen = PlayerGui:FindFirstChild("SanrioShopToggle") or Instance.new("ScreenGui")
    toggleScreen.Name = "SanrioShopToggle"
    toggleScreen.ResetOnSpawn = false
    toggleScreen.DisplayOrder = 999
    toggleScreen.Parent = PlayerGui

    self.toggleButton = UI.Components.Button({
        Name = "ShopToggle",
        Text = "Shop",
        Size = UDim2.fromOffset(150, 48),
        Position = UDim2.new(1, -30, 1, -30),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = UI.Theme:get("accent"),
        cornerRadius = UDim.new(0.5, 0),
        parent = toggleScreen,
        onClick = function()
            self:toggle()
        end,
    }):render()

    local label = UI.Components.TextLabel({
        Name = "Subtitle",
        Text = "Open store",
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.fromOffset(0, 30),
        parent = self.toggleButton,
    }):render()
    label.TextTransparency = 0.2
end

-- Main Interface -----------------------------------------------------
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
        cornerRadius = UDim.new(0, 24),
        stroke = {
            color = UI.Theme:get("divider"),
            thickness = 1,
        },
        parent = self.gui,
    }):render()

    UI.Responsive.scale(self.mainPanel)

    self:createHeader()
    self:createTabBar()

    self.contentContainer = UI.Components.Frame({
        Name = "Content",
        Size = UDim2.new(1, -48, 1, -180),
        Position = UDim2.fromOffset(24, 156),
        BackgroundTransparency = 1,
        parent = self.mainPanel,
    }):render()

    self:createPages()
    self:selectTab("Home")
end

function Shop:createHeader()
    local header = UI.Components.Frame({
        Name = "Header",
        Size = UDim2.new(1, -48, 0, 90),
        Position = UDim2.fromOffset(24, 24),
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        cornerRadius = UDim.new(0, 18),
        parent = self.mainPanel,
    }):render()

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, UI.Theme:get("accent")),
        ColorSequenceKeypoint.new(1, UI.Theme:get("highlight")),
    })
    gradient.Rotation = 15
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 0.65),
    })
    gradient.Parent = header

    local logo = UI.Components.Image({
        Name = "Logo",
        Image = "rbxassetid://17398522865",
        Size = UDim2.fromOffset(68, 68),
        Position = UDim2.fromOffset(18, 11),
        parent = header,
    }):render()

    local title = UI.Components.TextLabel({
        Name = "Title",
        Text = "Sanrio Shop",
        Font = Enum.Font.GothamBold,
        TextSize = 30,
        Size = UDim2.new(1, -200, 0, 32),
        Position = UDim2.fromOffset(102, 14),
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = header,
    }):render()

    local subtitle = UI.Components.TextLabel({
        Name = "Subtitle",
        Text = "Find the perfect boosts for your pastel tycoon.",
        Font = Enum.Font.Gotham,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextSize = 16,
        Size = UDim2.new(1, -200, 0, 24),
        Position = UDim2.fromOffset(102, 50),
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = header,
    }):render()

    local closeButton = UI.Components.Button({
        Name = "CloseButton",
        Text = "Close",
        Size = UDim2.fromOffset(110, 40),
        Position = UDim2.new(1, -120, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = UI.Theme:get("highlight"),
        TextColor3 = UI.Theme:get("text"),
        Font = Enum.Font.GothamMedium,
        cornerRadius = UDim.new(0.5, 0),
        parent = header,
        onClick = function()
            self:close()
        end,
    }):render()
end

function Shop:createTabBar()
    self.tabContainer = UI.Components.Frame({
        Name = "Tabs",
        Size = UDim2.new(1, -48, 0, 54),
        Position = UDim2.fromOffset(24, 122),
        BackgroundTransparency = 1,
        parent = self.mainPanel,
    }):render()

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.Parent = self.tabContainer

    local tabData = {
        { id = "Home", name = "Home", color = UI.Theme:get("accent") },
        { id = "Cash", name = "Cash Bundles", color = UI.Theme:get("highlight") },
        { id = "Gamepasses", name = "Game Passes", color = UI.Theme:get("accentAlt") },
    }

    for index, data in ipairs(tabData) do
        local tabButton = UI.Components.Button({
            Name = data.id .. "Tab",
            Text = data.name,
            Size = UDim2.fromOffset(180, 44),
            BackgroundColor3 = UI.Theme:get("surfaceAlt"),
            TextColor3 = UI.Theme:get("text"),
            Font = Enum.Font.GothamMedium,
            cornerRadius = UDim.new(0.5, 0),
            LayoutOrder = index,
            parent = self.tabContainer,
            onClick = function()
                self:selectTab(data.id)
            end,
        }):render()

        self.tabs[data.id] = {
            button = tabButton,
            color = data.color,
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
        Visible = false,
        parent = self.contentContainer,
    }):render()

    local scrollFrame = UI.Components.ScrollingFrame({
        Size = UDim2.fromScale(1, 1),
        layout = {
            type = "List",
            Padding = UDim.new(0, 24),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
        },
        padding = {
            top = UDim.new(0, 12),
            bottom = UDim.new(0, 12),
        },
        parent = page,
    }):render()

    self:createHeroSection(scrollFrame)

    local featuredTitle = UI.Components.TextLabel({
        Text = "Featured Bundles",
        Font = Enum.Font.GothamBold,
        TextSize = 24,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -40, 0, 40),
        Position = UDim2.fromOffset(20, 0),
        TextColor3 = UI.Theme:get("text"),
        LayoutOrder = 2,
        parent = scrollFrame,
    }):render()

    local featuredFrame = UI.Components.Frame({
        Size = UDim2.new(1, -40, 0, 320),
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        parent = scrollFrame,
    }):render()

    local horizontalScroll = UI.Components.ScrollingFrame({
        Size = UDim2.fromScale(1, 1),
        ScrollingDirection = Enum.ScrollingDirection.X,
        layout = {
            type = "List",
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 18),
        },
        padding = {
            left = UDim.new(0, 10),
            right = UDim.new(0, 10),
            top = UDim.new(0, 6),
            bottom = UDim.new(0, 6),
        },
        parent = featuredFrame,
    }):render()

    for _, product in ipairs(Core.DataManager.products.cash) do
        if product.featured then
            self:createProductCard(product, "cash", horizontalScroll)
        end
    end

    return page
end

function Shop:createCashPage()
    local page = UI.Components.Frame({
        Name = "CashPage",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        parent = self.contentContainer,
    }):render()

    local grid = UI.Components.ScrollingFrame({
        Size = UDim2.fromScale(1, 1),
        layout = {
            type = "Grid",
            CellSize = Core.Utils.isMobile()
                and UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE_MOBILE.X, Core.CONSTANTS.CARD_SIZE_MOBILE.Y)
                or UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y),
            CellPadding = UDim2.fromOffset(18, 18),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
        },
        padding = {
            top = UDim.new(0, 12),
            bottom = UDim.new(0, 12),
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
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        parent = self.contentContainer,
    }):render()

    local grid = UI.Components.ScrollingFrame({
        Size = UDim2.fromScale(1, 1),
        layout = {
            type = "Grid",
            CellSize = Core.Utils.isMobile()
                and UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE_MOBILE.X, Core.CONSTANTS.CARD_SIZE_MOBILE.Y)
                or UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y),
            CellPadding = UDim2.fromOffset(18, 18),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
        },
        padding = {
            top = UDim.new(0, 12),
            bottom = UDim.new(0, 12),
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
        Name = "Hero",
        Size = UDim2.new(1, -40, 0, 210),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(0, 18),
        LayoutOrder = 1,
        parent = parent,
    }):render()

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, UI.Theme:get("highlight")),
        ColorSequenceKeypoint.new(1, UI.Theme:get("accentAlt")),
    })
    gradient.Rotation = 0
    gradient.Transparency = NumberSequence.new(0.35)
    gradient.Parent = hero

    local heroContent = UI.Components.Frame({
        Size = UDim2.new(1, -48, 1, -48),
        Position = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
        parent = hero,
    }):render()

    local title = UI.Components.TextLabel({
        Text = "Create a gentle shopping moment",
        Font = Enum.Font.GothamBold,
        TextSize = 28,
        Size = UDim2.new(1, 0, 0, 32),
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = heroContent,
    }):render()

    local desc = UI.Components.TextLabel({
        Text = "Stock up on currency and passes to keep your Sanrio space charming and efficient.",
        Font = Enum.Font.Gotham,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextSize = 18,
        Size = UDim2.new(1, 0, 0, 50),
        Position = UDim2.fromOffset(0, 40),
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = heroContent,
    }):render()

    local exploreButton = UI.Components.Button({
        Text = "View Cash Bundles",
        Size = UDim2.fromOffset(200, 46),
        Position = UDim2.fromOffset(0, 110),
        BackgroundColor3 = UI.Theme:get("accent"),
        Font = Enum.Font.GothamMedium,
        TextSize = 18,
        cornerRadius = UDim.new(0.5, 0),
        parent = heroContent,
        onClick = function()
            self:selectTab("Cash")
        end,
    }):render()

    return hero
end

function Shop:createProductCard(product, productType, parent)
    local isGamepass = productType == "gamepass"
    local accentColor = isGamepass and UI.Theme:get("accentAlt") or UI.Theme:get("highlight")

    local card = UI.Components.Frame({
        Name = product.name .. "Card",
        Size = UDim2.fromOffset(
            Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.X or Core.CONSTANTS.CARD_SIZE.X,
            Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.Y or Core.CONSTANTS.CARD_SIZE.Y
        ),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(0, 18),
        stroke = {
            color = UI.Theme:get("divider"),
            thickness = 1,
        },
        parent = parent,
    }):render()

    self:addCardHover(card)

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 16)
    padding.PaddingBottom = UDim.new(0, 16)
    padding.PaddingLeft = UDim.new(0, 18)
    padding.PaddingRight = UDim.new(0, 18)
    padding.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 12)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = card

    local imageContainer = UI.Components.Frame({
        Size = UDim2.new(1, 0, 0, 140),
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        cornerRadius = UDim.new(0, 14),
        LayoutOrder = 1,
        parent = card,
    }):render()

    local image = UI.Components.Image({
        Image = product.icon or "rbxassetid://0",
        Size = UDim2.fromScale(0.8, 0.8),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        parent = imageContainer,
    }):render()

    local title = UI.Components.TextLabel({
        Text = product.name,
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        LayoutOrder = 2,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 28),
        parent = card,
    }):render()

    local description = UI.Components.TextLabel({
        Text = product.description,
        Font = Enum.Font.Gotham,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 44),
        LayoutOrder = 3,
        parent = card,
    }):render()

    local priceText
    if isGamepass then
        priceText = string.format("R$%d", product.price or 0)
    else
        priceText = string.format("R$%d • %s Cash", product.price or 0, Core.Utils.formatNumber(product.amount))
    end

    local priceLabel = UI.Components.TextLabel({
        Text = priceText,
        Font = Enum.Font.GothamMedium,
        TextColor3 = accentColor,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 24),
        LayoutOrder = 4,
        parent = card,
    }):render()

    local button = UI.Components.Button({
        Text = "Purchase",
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = accentColor,
        TextColor3 = UI.Theme:get("text"),
        Font = Enum.Font.GothamMedium,
        cornerRadius = UDim.new(0.5, 0),
        LayoutOrder = 5,
        parent = card,
        onClick = function()
            if not isGamepass then
                self:promptPurchase(product, productType)
            else
                if Core.DataManager.checkOwnership(product.id) then
                    if product.hasToggle then
                        self:toggleGamepass(product)
                    end
                else
                    self:promptPurchase(product, productType)
                end
            end
        end,
    }):render()

    local owned = isGamepass and Core.DataManager.checkOwnership(product.id)
    if owned then
        button.Text = product.hasToggle and "Toggle" or "Owned"
        button.BackgroundColor3 = UI.Theme:get("success")
        if not product.hasToggle then
            button.Active = false
        end
    end

    if isGamepass and product.hasToggle then
        self:addToggleSwitch(product, card)
    end

    product.cardInstance = card
    product.purchaseButton = button

    return card
end

function Shop:addCardHover(card)
    local scaler = card:FindFirstChild("HoverScale")
    if not scaler then
        scaler = Instance.new("UIScale")
        scaler.Name = "HoverScale"
        scaler.Scale = 1
        scaler.Parent = card
    end

    card.MouseEnter:Connect(function()
        Core.Animation.tween(card, {
            BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        }, Core.CONSTANTS.ANIM_FAST)
        Core.Animation.tween(scaler, {
            Scale = 1.03,
        }, Core.CONSTANTS.ANIM_FAST)
    end)

    card.MouseLeave:Connect(function()
        Core.Animation.tween(card, {
            BackgroundColor3 = UI.Theme:get("surface"),
        }, Core.CONSTANTS.ANIM_FAST)
        Core.Animation.tween(scaler, {
            Scale = 1,
        }, Core.CONSTANTS.ANIM_FAST)
    end)
end

function Shop:addToggleSwitch(product, parent)
    local toggleFrame = UI.Components.Frame({
        Name = "Toggle",
        Size = UDim2.fromOffset(70, 34),
        BackgroundColor3 = UI.Theme:get("divider"),
        cornerRadius = UDim.new(0.5, 0),
        parent = parent,
        LayoutOrder = 6,
    }):render()

    local knob = UI.Components.Frame({
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(0.5, 0),
        parent = toggleFrame,
    }):render()

    local toggleState = false
    if Remotes then
        local getState = Remotes:FindFirstChild("GetAutoCollectState")
        if getState and getState:IsA("RemoteFunction") then
            local success, state = pcall(function()
                return getState:InvokeServer()
            end)
            if success and type(state) == "boolean" then
                toggleState = state
            end
        end
    end

    local function updateToggle()
        if toggleState then
            toggleFrame.BackgroundColor3 = UI.Theme:get("success")
            Core.Animation.tween(knob, { Position = UDim2.fromOffset(38, 2) }, Core.CONSTANTS.ANIM_FAST)
        else
            toggleFrame.BackgroundColor3 = UI.Theme:get("divider")
            Core.Animation.tween(knob, { Position = UDim2.fromOffset(2, 2) }, Core.CONSTANTS.ANIM_FAST)
        end
    end

    updateToggle()

    local clickArea = Instance.new("TextButton")
    clickArea.Text = ""
    clickArea.BackgroundTransparency = 1
    clickArea.Size = UDim2.fromScale(1, 1)
    clickArea.Parent = toggleFrame

    clickArea.MouseButton1Click:Connect(function()
        toggleState = not toggleState
        updateToggle()
        if Remotes then
            local toggleRemote = Remotes:FindFirstChild("AutoCollectToggle")
            if toggleRemote and toggleRemote:IsA("RemoteEvent") then
                toggleRemote:FireServer(toggleState)
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
            BackgroundColor3 = active and tab.color or UI.Theme:get("surfaceAlt"),
            TextColor3 = active and UI.Theme:get("text") or UI.Theme:get("textSecondary"),
        }, Core.CONSTANTS.ANIM_FAST)
    end

    for id, page in pairs(self.pages) do
        page.Visible = id == tabId
        if id == tabId then
            page.Position = UDim2.fromOffset(0, 16)
            Core.Animation.tween(page, {
                Position = UDim2.fromOffset(0, 0),
            }, Core.CONSTANTS.ANIM_BOUNCE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
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

        if product.purchaseButton then
            product.purchaseButton.Text = "Processing..."
            product.purchaseButton.Active = false
        end

        Core.State.purchasePending[product.id] = {
            product = product,
            type = productType,
            timestamp = tick(),
        }

        local success = pcall(function()
            MarketplaceService:PromptGamePassPurchase(Player, product.id)
        end)

        if not success then
            if product.purchaseButton then
                product.purchaseButton.Text = "Purchase"
                product.purchaseButton.Active = true
            end
            Core.State.purchasePending[product.id] = nil
        end
    else
        Core.State.purchasePending[product.id] = {
            product = product,
            type = productType,
            timestamp = tick(),
        }

        local success = pcall(function()
            MarketplaceService:PromptProductPurchase(Player, product.id)
        end)

        if not success then
            Core.State.purchasePending[product.id] = nil
        end
    end

    task.delay(Core.CONSTANTS.PURCHASE_TIMEOUT, function()
        local pending = Core.State.purchasePending[product.id]
        if pending then
            Core.State.purchasePending[product.id] = nil
            if product.purchaseButton then
                product.purchaseButton.Text = "Purchase"
                product.purchaseButton.Active = true
            end
        end
    end)
end

function Shop:refreshProduct(product, productType)
    if productType == "gamepass" then
        local owned = Core.DataManager.checkOwnership(product.id)
        if product.purchaseButton then
            if owned then
                product.purchaseButton.Text = product.hasToggle and "Toggle" or "Owned"
                product.purchaseButton.BackgroundColor3 = UI.Theme:get("success")
                product.purchaseButton.Active = product.hasToggle
            else
                product.purchaseButton.Text = "Purchase"
                product.purchaseButton.BackgroundColor3 = UI.Theme:get("accentAlt")
                product.purchaseButton.Active = true
            end
        end

        if product.cardInstance then
            local stroke = product.cardInstance:FindFirstChildOfClass("UIStroke")
            if stroke then
                stroke.Color = owned and UI.Theme:get("success") or UI.Theme:get("divider")
            end
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

    Core.Animation.tween(self.blur, { Size = 18 }, Core.CONSTANTS.ANIM_MEDIUM)

    local panelSize = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE
    self.mainPanel.Position = UDim2.fromScale(0.5, 0.52)
    self.mainPanel.Size = UDim2.fromOffset(panelSize.X * 0.92, panelSize.Y * 0.92)

    Core.Animation.tween(self.mainPanel, {
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
    }, Core.CONSTANTS.ANIM_BOUNCE, Enum.EasingStyle.Back)

    Core.SoundSystem.play("open")

    task.wait(Core.CONSTANTS.ANIM_BOUNCE)
    Core.State.isAnimating = false
    Core.Events:emit("shopOpened")
end

function Shop:close()
    if not Core.State.isOpen or Core.State.isAnimating then return end

    Core.State.isAnimating = true
    Core.State.isOpen = false

    Core.Animation.tween(self.blur, { Size = 0 }, Core.CONSTANTS.ANIM_FAST)

    Core.Animation.tween(self.mainPanel, {
        Position = UDim2.fromScale(0.5, 0.52),
        Size = UDim2.fromOffset(
            self.mainPanel.Size.X.Offset * 0.92,
            self.mainPanel.Size.Y.Offset * 0.92
        ),
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

function Shop:toggleGamepass(product)
    if not product or not product.hasToggle then return end
    if not Remotes then return end

    local desiredState
    local getState = Remotes:FindFirstChild("GetAutoCollectState")
    if getState and getState:IsA("RemoteFunction") then
        local success, state = pcall(function()
            return getState:InvokeServer()
        end)
        if success and type(state) == "boolean" then
            desiredState = not state
        end
    end

    local toggleRemote = Remotes:FindFirstChild("AutoCollectToggle")
    if toggleRemote and toggleRemote:IsA("RemoteEvent") then
        if desiredState == nil then
            desiredState = true
        end
        toggleRemote:FireServer(desiredState)
        Core.SoundSystem.play("click")
    end
end

-- Marketplace callbacks ---------------------------------------------
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
    if player ~= Player then return end

    local pending = Core.State.purchasePending[passId]
    if not pending then return end

    Core.State.purchasePending[passId] = nil

    if purchased then
        ownershipCache:clear()
        if pending.product.purchaseButton then
            pending.product.purchaseButton.Text = pending.product.hasToggle and "Toggle" or "Owned"
            pending.product.purchaseButton.BackgroundColor3 = UI.Theme:get("success")
            pending.product.purchaseButton.Active = pending.product.hasToggle
        end
        Core.SoundSystem.play("success")
        task.wait(0.4)
        shop:refreshAllProducts()
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

-- Initialize ---------------------------------------------------------
local shop = Shop.new()

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

print("[SanrioShop] Soft pastel shop ready! Version " .. Core.VERSION)

return shop
