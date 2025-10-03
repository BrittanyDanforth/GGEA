--[[
    SANRIO SHOP SYSTEM - MARKET EDITION
    Place this as a LocalScript in StarterPlayer > StarterPlayerScripts
    Name it: SanrioShop

    Visual direction goals:
    • Soft market-inspired layout with stacked shelves and pastel accents
    • Calm typography and spacing that works on desktop and tablet
    • Product cards resemble packaged goods with clear information bands
    • Maintains the original purchasing and toggle behaviour
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

-- ==================================================
-- CORE
-- ==================================================
local Core = {}
Core.VERSION = "2.2.0"

Core.CONSTANTS = {
    PANEL_SIZE = Vector2.new(1180, 820),
    PANEL_SIZE_MOBILE = Vector2.new(940, 700),
    CARD_SIZE = Vector2.new(520, 280),
    CARD_SIZE_MOBILE = Vector2.new(460, 260),

    ANIM_FAST = 0.12,
    ANIM_MEDIUM = 0.22,
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
        local list = self.handlers[eventName]
        if not list then return end
        local index = table.find(list, handler)
        if index then table.remove(list, index) end
    end
end

function Core.Events:emit(eventName, ...)
    local listeners = self.handlers[eventName]
    if not listeners then return end
    for _, fn in ipairs(listeners) do
        task.spawn(fn, ...)
    end
end

-- Cache ------------------------------------------------
local Cache = {}
Cache.__index = Cache

function Cache.new(duration)
    return setmetatable({ data = {}, duration = duration or 300 }, Cache)
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

-- Utils ------------------------------------------------
Core.Utils = {}

function Core.Utils.isMobile()
    local camera = workspace.CurrentCamera
    if not camera then return false end
    local viewportSize = camera.ViewportSize
    return viewportSize.X < 1024 or GuiService:IsTenFootInterface()
end

function Core.Utils.formatNumber(value)
    local formatted = tostring(value)
    local changed = 1
    while changed ~= 0 do
        formatted, changed = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
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

-- Animation -------------------------------------------
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

-- Sounds ----------------------------------------------
Core.SoundSystem = {}

function Core.SoundSystem.initialize()
    local manifest = {
        click = {id = "rbxassetid://876939830", volume = 0.4},
        hover = {id = "rbxassetid://10066936758", volume = 0.2},
        open = {id = "rbxassetid://184168568", volume = 0.45},
        close = {id = "rbxassetid://184168757", volume = 0.45},
        success = {id = "rbxassetid://138081500", volume = 0.55},
        error = {id = "rbxassetid://63384199", volume = 0.5},
    }

    Core.SoundSystem.sounds = {}
    for name, info in pairs(manifest) do
        local sound = Instance.new("Sound")
        sound.Name = "SanrioShop_" .. name
        sound.SoundId = info.id
        sound.Volume = info.volume
        sound.Parent = SoundService
        Core.SoundSystem.sounds[name] = sound
    end
end

function Core.SoundSystem.play(name)
    if Core.State.settings.soundEnabled and Core.SoundSystem.sounds[name] then
        Core.SoundSystem.sounds[name]:Play()
    end
end

-- Data -------------------------------------------------
Core.DataManager = {}

Core.DataManager.products = {
    cash = {
        {
            id = 1897730242,
            amount = 1000,
            name = "1,000 Cash",
            description = "A tidy bundle for the next shelf upgrade.",
            icon = "rbxassetid://10709728059",
            featured = false,
            price = 0,
        },
        {
            id = 1897730373,
            amount = 5000,
            name = "5,000 Cash",
            description = "Great for unlocking fresh décor quickly.",
            icon = "rbxassetid://10709728059",
            featured = true,
            price = 0,
        },
        {
            id = 1897730467,
            amount = 10000,
            name = "10,000 Cash",
            description = "Stock up for a round of speedy expansions.",
            icon = "rbxassetid://10709728059",
            featured = false,
            price = 0,
        },
        {
            id = 1897730581,
            amount = 50000,
            name = "50,000 Cash",
            description = "Top-tier restock for serious collectors.",
            icon = "rbxassetid://10709728059",
            featured = true,
            price = 0,
        },
    },
    gamepasses = {
        {
            id = 1412171840,
            name = "Auto Collect",
            description = "Keeps tills tidy by gathering every drop.",
            icon = "rbxassetid://10709727148",
            price = 99,
            hasToggle = true,
        },
        {
            id = 1398974710,
            name = "2x Cash",
            description = "Double earnings on every future sale.",
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

-- ==================================================
-- UI TOOLKIT
-- ==================================================
local UI = {}

UI.Theme = {
    current = "market",
    themes = {
        market = {
            background = Color3.fromRGB(248, 244, 240),
            surface = Color3.fromRGB(255, 255, 255),
            surfaceAlt = Color3.fromRGB(244, 239, 236),
            stroke = Color3.fromRGB(214, 206, 198),
            text = Color3.fromRGB(60, 58, 55),
            textSecondary = Color3.fromRGB(120, 114, 108),
            accent = Color3.fromRGB(255, 155, 170),
            accentAlt = Color3.fromRGB(120, 178, 196),
            accentSoft = Color3.fromRGB(255, 211, 160),
            success = Color3.fromRGB(116, 184, 123),
            muted = Color3.fromRGB(210, 204, 198),
        },
    },
}

function UI.Theme:get(key)
    local theme = self.themes[self.current]
    return theme and theme[key] or Color3.new(1, 1, 1)
end

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
        if key ~= "children" and key ~= "parent" and key ~= "cornerRadius" and key ~= "stroke" and key ~= "padding" and key ~= "layout" and key ~= "onClick" then
            if type(value) == "function" and key:sub(1, 2) == "on" then
                local signalName = key:sub(3)
                if self.instance[signalName] then
                    local conn = self.instance[signalName]:Connect(value)
                    table.insert(self.connections, conn)
                end
            else
                pcall(function()
                    self.instance[key] = value
                end)
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
        for name, value in pairs(self.props.padding) do
            local property = "Padding" .. name:gsub("^%l", string.upper)
            if padding[property] then
                padding[property] = value
            end
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
            if layout:IsA("UIListLayout") then
                layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    self.instance.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + (self.props.layout.extraPadding or 0))
                end)
            elseif layout:IsA("UIGridLayout") then
                layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    self.instance.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + (self.props.layout.extraPadding or 0))
                end)
            end
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

UI.Components = {}

function UI.Components.Frame(props)
    local defaults = {
        BackgroundColor3 = UI.Theme:get("surface"),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
    }
    for key, value in pairs(defaults) do
        if props[key] == nil then
            props[key] = value
        end
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
    for key, value in pairs(defaults) do
        if props[key] == nil then
            props[key] = value
        end
    end
    return Component.new("TextLabel", props)
end

function UI.Components.Button(props)
    local defaults = {
        BackgroundColor3 = UI.Theme:get("accent"),
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamMedium,
        Size = UDim2.fromOffset(120, 40),
        AutoButtonColor = false,
    }
    for key, value in pairs(defaults) do
        if props[key] == nil then
            props[key] = value
        end
    end

    local component = Component.new("TextButton", props)
    component.instance.MouseEnter:Connect(function()
        Core.SoundSystem.play("hover")
    end)
    component.instance.MouseButton1Click:Connect(function()
        Core.SoundSystem.play("click")
    end)

    if props.onClick then
        component.instance.MouseButton1Click:Connect(props.onClick)
    end

    return component
end

function UI.Components.Image(props)
    local defaults = {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(100, 100),
        ScaleType = Enum.ScaleType.Fit,
    }
    for key, value in pairs(defaults) do
        if props[key] == nil then
            props[key] = value
        end
    end
    return Component.new("ImageLabel", props)
end

function UI.Components.ScrollingFrame(props)
    local defaults = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 8,
        ScrollBarImageColor3 = UI.Theme:get("muted"),
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
    }
    for key, value in pairs(defaults) do
        if props[key] == nil then
            props[key] = value
        end
    end
    return Component.new("ScrollingFrame", props)
end

UI.Responsive = {}

function UI.Responsive.attachScale(instance)
    local camera = workspace.CurrentCamera
    if not camera then return end

    local scale = Instance.new("UIScale")
    scale.Parent = instance

    local function updateScale()
        local viewport = camera.ViewportSize
        local factor = math.min(viewport.X / 1920, viewport.Y / 1080)
        factor = Core.Utils.clamp(factor, 0.6, 1.35)
        if Core.Utils.isMobile() then
            factor = factor * 0.9
        end
        scale.Scale = factor
    end

    updateScale()
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    return scale
end

-- ==================================================
-- SHOP UI
-- ==================================================
local Shop = {}
Shop.__index = Shop

function Shop.new()
    local self = setmetatable({}, Shop)

    self.gui = nil
    self.mainPanel = nil
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

    Core.Events:emit("shopInitialized")
end

function Shop:createToggleButton()
    local toggleScreen = PlayerGui:FindFirstChild("SanrioShopToggle") or Instance.new("ScreenGui")
    toggleScreen.Name = "SanrioShopToggle"
    toggleScreen.ResetOnSpawn = false
    toggleScreen.DisplayOrder = 20
    toggleScreen.Parent = PlayerGui

    self.toggleButton = UI.Components.Button({
        Name = "ShopToggle",
        Text = "Shop",
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        Size = UDim2.fromOffset(156, 48),
        Position = UDim2.new(1, -24, 1, -24),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = UI.Theme:get("accent"),
        cornerRadius = UDim.new(1, 0),
        parent = toggleScreen,
        onClick = function()
            self:toggle()
        end,
    }):render()

    local subtitle = UI.Components.TextLabel({
        Text = "Open market",
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = UI.Theme:get("surface"),
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -16, 0, 18),
        Position = UDim2.fromOffset(8, 26),
        parent = self.toggleButton,
    }):render()

    self:addPulseAnimation(self.toggleButton)
end

function Shop:createMainInterface()
    self.gui = PlayerGui:FindFirstChild("SanrioShopMain") or Instance.new("ScreenGui")
    self.gui.Name = "SanrioShopMain"
    self.gui.ResetOnSpawn = false
    self.gui.DisplayOrder = 100
    self.gui.Enabled = false
    self.gui.Parent = PlayerGui

    self.blur = Lighting:FindFirstChild("SanrioShopBlur") or Instance.new("BlurEffect")
    self.blur.Name = "SanrioShopBlur"
    self.blur.Size = 0
    self.blur.Parent = Lighting

    local dimmer = UI.Components.Frame({
        Name = "Dimmer",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.4,
        parent = self.gui,
    }):render()

    local panelSize = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE

    self.mainPanel = UI.Components.Frame({
        Name = "MainPanel",
        Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(0, 26),
        stroke = {
            color = UI.Theme:get("stroke"),
            thickness = 1,
        },
        parent = self.gui,
    }):render()

    UI.Responsive.attachScale(self.mainPanel)

    self:createHeader()
    self:createTabBar()

    self.contentContainer = UI.Components.Frame({
        Name = "ContentContainer",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -64, 1, -200),
        Position = UDim2.fromOffset(32, 168),
        parent = self.mainPanel,
    }):render()

    self:createPages()
    self:selectTab("Home")
end

function Shop:createHeader()
    local header = UI.Components.Frame({
        Name = "Header",
        Size = UDim2.new(1, -64, 0, 112),
        Position = UDim2.fromOffset(32, 28),
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        cornerRadius = UDim.new(0, 22),
        stroke = {
            color = UI.Theme:get("stroke"),
            thickness = 1,
            transparency = 0.2,
        },
        parent = self.mainPanel,
    }):render()

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Core.Utils.blend(UI.Theme:get("surfaceAlt"), UI.Theme:get("accent"), 0.08)),
        ColorSequenceKeypoint.new(1, Core.Utils.blend(UI.Theme:get("surfaceAlt"), UI.Theme:get("accentAlt"), 0.08)),
    })
    gradient.Rotation = 45
    gradient.Parent = header

    local logo = UI.Components.Image({
        Name = "Logo",
        Image = "rbxassetid://17398522865",
        Size = UDim2.fromOffset(72, 72),
        Position = UDim2.fromOffset(24, 20),
        parent = header,
    }):render()

    local title = UI.Components.TextLabel({
        Name = "Title",
        Text = "Sanrio Market",
        Font = Enum.Font.GothamBold,
        TextSize = 30,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -220, 0, 36),
        Position = UDim2.fromOffset(110, 24),
        parent = header,
    }):render()

    local subtitle = UI.Components.TextLabel({
        Name = "Subtitle",
        Text = "Curated boosts and collectibles for your tycoon.",
        Font = Enum.Font.Gotham,
        TextSize = 18,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -220, 0, 26),
        Position = UDim2.fromOffset(110, 62),
        parent = header,
    }):render()

    UI.Components.Button({
        Name = "CloseButton",
        Text = "Close",
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        Size = UDim2.fromOffset(120, 40),
        Position = UDim2.new(1, -140, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = UI.Theme:get("accentAlt"),
        TextColor3 = Color3.new(1, 1, 1),
        cornerRadius = UDim.new(1, 0),
        parent = header,
        onClick = function()
            self:close()
        end,
    }):render()
end

function Shop:createTabBar()
    local tabHolder = UI.Components.Frame({
        Name = "TabHolder",
        Size = UDim2.new(1, -64, 0, 56),
        Position = UDim2.fromOffset(32, 148),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(1, 0),
        stroke = {
            color = UI.Theme:get("stroke"),
            thickness = 1,
            transparency = 0.35,
        },
        parent = self.mainPanel,
    }):render()

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 8)
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.Parent = tabHolder

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 16)
    padding.Parent = tabHolder

    local tabData = {
        {id = "Home", name = "Highlights", icon = "rbxassetid://17398522865", color = UI.Theme:get("accent")},
        {id = "Cash", name = "Cash Bundles", icon = "rbxassetid://10709728059", color = UI.Theme:get("accentAlt")},
        {id = "Gamepasses", name = "Passes", icon = "rbxassetid://10709727148", color = UI.Theme:get("accentSoft")},
    }

    for index, data in ipairs(tabData) do
        self:createTab(tabHolder, data, index)
    end
end

function Shop:createTab(parent, data, order)
    local tabButton = UI.Components.Button({
        Name = data.id .. "Tab",
        Text = "",
        Font = Enum.Font.GothamMedium,
        TextSize = 18,
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        TextColor3 = UI.Theme:get("textSecondary"),
        Size = UDim2.fromOffset(180, 40),
        cornerRadius = UDim.new(1, 0),
        LayoutOrder = order,
        parent = parent,
        onClick = function()
            self:selectTab(data.id)
        end,
    }):render()

    local icon = UI.Components.Image({
        Name = "Icon",
        Image = data.icon,
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.fromOffset(16, 10),
        parent = tabButton,
    }):render()

    local label = UI.Components.TextLabel({
        Text = data.name,
        Font = Enum.Font.GothamMedium,
        TextSize = 18,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -48, 1, 0),
        Position = UDim2.fromOffset(44, 0),
        parent = tabButton,
    }):render()

    self.tabs[data.id] = {
        button = tabButton,
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
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        parent = self.contentContainer,
    }):render()

    local scroll = UI.Components.ScrollingFrame({
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        layout = {
            type = "List",
            Padding = UDim.new(0, 24),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            extraPadding = 48,
        },
        padding = {
            top = UDim.new(0, 4),
            left = UDim.new(0, 8),
            right = UDim.new(0, 8),
        },
        parent = page,
    }):render()

    self:createHeroSection(scroll)

    local featuredTitle = UI.Components.TextLabel({
        Text = "Featured Bundles",
        Font = Enum.Font.GothamBold,
        TextSize = 24,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -40, 0, 32),
        LayoutOrder = 2,
        parent = scroll,
    }):render()

    local shelf = UI.Components.Frame({
        Size = UDim2.new(1, -40, 0, 320),
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        parent = scroll,
    }):render()

    local shelfScroll = UI.Components.ScrollingFrame({
        Size = UDim2.fromScale(1, 1),
        ScrollingDirection = Enum.ScrollingDirection.X,
        CanvasSize = UDim2.new(),
        layout = {
            type = "List",
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 20),
            extraPadding = 40,
        },
        padding = {
            top = UDim.new(0, 16),
            left = UDim.new(0, 20),
        },
        parent = shelf,
    }):render()

    for _, product in ipairs(Core.DataManager.products.cash) do
        if product.featured then
            self:createProductCard(product, "cash", shelfScroll)
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
            CellPadding = UDim2.fromOffset(24, 24),
            CellSize = Core.Utils.isMobile()
                and UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE_MOBILE.X, Core.CONSTANTS.CARD_SIZE_MOBILE.Y)
                or UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Top,
            extraPadding = 40,
        },
        padding = {
            top = UDim.new(0, 20),
            left = UDim.new(0, 16),
            right = UDim.new(0, 16),
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
            CellPadding = UDim2.fromOffset(24, 24),
            CellSize = Core.Utils.isMobile()
                and UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE_MOBILE.X, Core.CONSTANTS.CARD_SIZE_MOBILE.Y)
                or UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Top,
            extraPadding = 40,
        },
        padding = {
            top = UDim.new(0, 20),
            left = UDim.new(0, 16),
            right = UDim.new(0, 16),
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
        Size = UDim2.new(1, -40, 0, 220),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(0, 20),
        stroke = {
            color = UI.Theme:get("stroke"),
            thickness = 1,
            transparency = 0.25,
        },
        LayoutOrder = 1,
        parent = parent,
    }):render()

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Core.Utils.blend(UI.Theme:get("surface"), UI.Theme:get("accent"), 0.12)),
        ColorSequenceKeypoint.new(1, Core.Utils.blend(UI.Theme:get("surface"), UI.Theme:get("accentSoft"), 0.18)),
    })
    gradient.Rotation = 30
    gradient.Parent = hero

    UI.Components.Frame({
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        padding = {
            left = UDim.new(0, 32),
            right = UDim.new(0, 32),
            top = UDim.new(0, 28),
        },
        parent = hero,
        children = {
            UI.Components.TextLabel({
                Text = "Seasonal Showcase",
                Font = Enum.Font.GothamBold,
                TextSize = 28,
                TextColor3 = UI.Theme:get("text"),
                TextXAlignment = Enum.TextXAlignment.Left,
                Size = UDim2.new(0.6, 0, 0, 34),
            }),
            UI.Components.TextLabel({
                Text = "Discover cozy boosts and pastel-perfect add-ons handpicked for your storefront.",
                Font = Enum.Font.Gotham,
                TextSize = 18,
                TextColor3 = UI.Theme:get("textSecondary"),
                TextXAlignment = Enum.TextXAlignment.Left,
                Size = UDim2.new(0.6, 0, 0, 60),
                Position = UDim2.fromOffset(0, 44),
            }),
        },
    }):render()

    UI.Components.Button({
        Text = "Browse Cash Bundles",
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        BackgroundColor3 = UI.Theme:get("accent"),
        TextColor3 = Color3.new(1, 1, 1),
        Size = UDim2.fromOffset(220, 48),
        cornerRadius = UDim.new(1, 0),
        Position = UDim2.fromOffset(32, 150),
        parent = hero,
        onClick = function()
            self:selectTab("Cash")
        end,
    }):render()

    local heroArt = UI.Components.Image({
        Image = "rbxassetid://17398522865",
        Size = UDim2.fromOffset(180, 180),
        Position = UDim2.new(1, -210, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        parent = hero,
    }):render()

    return hero
end

function Shop:createProductCard(product, productType, parent)
    local isGamepass = productType == "gamepass"
    local accentColor = isGamepass and UI.Theme:get("accentAlt") or UI.Theme:get("accent")

    local card = UI.Components.Frame({
        Name = product.name .. "Card",
        BackgroundColor3 = UI.Theme:get("surface"),
        Size = UDim2.fromOffset(
            Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.X or Core.CONSTANTS.CARD_SIZE.X,
            Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.Y or Core.CONSTANTS.CARD_SIZE.Y
        ),
        cornerRadius = UDim.new(0, 18),
        stroke = {
            color = UI.Theme:get("stroke"),
            thickness = 1,
            transparency = 0.3,
        },
        parent = parent,
    }):render()

    local content = UI.Components.Frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -32, 1, -32),
        Position = UDim2.fromOffset(16, 16),
        parent = card,
    }):render()

    local banner = UI.Components.Frame({
        BackgroundColor3 = Core.Utils.blend(accentColor, UI.Theme:get("surface"), 0.6),
        Size = UDim2.new(1, 0, 0, 132),
        cornerRadius = UDim.new(0, 14),
        parent = content,
    }):render()

    UI.Components.Image({
        Image = product.icon or "rbxassetid://0",
        Size = UDim2.fromOffset(120, 120),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        parent = banner,
    }):render()

    local info = UI.Components.Frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -140),
        Position = UDim2.fromOffset(0, 140),
        parent = content,
    }):render()

    product.infoContainer = info

    UI.Components.TextLabel({
        Text = product.name,
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 28),
        parent = info,
    }):render()

    UI.Components.TextLabel({
        Text = product.description,
        Font = Enum.Font.Gotham,
        TextSize = 16,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 48),
        Position = UDim2.fromOffset(0, 32),
        parent = info,
    }):render()

    local priceText
    if isGamepass then
        priceText = "R$" .. tostring(product.price or 0)
    else
        priceText = "R$" .. tostring(product.price or 0) .. " • " .. Core.Utils.formatNumber(product.amount) .. " cash"
    end

    UI.Components.TextLabel({
        Text = priceText,
        Font = Enum.Font.GothamMedium,
        TextSize = 18,
        TextColor3 = accentColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 24),
        Position = UDim2.fromOffset(0, 84),
        parent = info,
    }):render()

    local isOwned = isGamepass and Core.DataManager.checkOwnership(product.id)

    product.purchaseButton = UI.Components.Button({
        Text = isOwned and "Owned" or "Purchase",
        Font = Enum.Font.GothamBold,
        TextSize = 17,
        BackgroundColor3 = isOwned and UI.Theme:get("success") or accentColor,
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.new(0, 0, 1, -44),
        cornerRadius = UDim.new(0, 12),
        parent = info,
        onClick = function()
            if isGamepass then
                if not Core.DataManager.checkOwnership(product.id) then
                    self:promptPurchase(product, "gamepass")
                elseif product.hasToggle then
                    self:toggleGamepass(product)
                end
            else
                self:promptPurchase(product, "cash")
            end
        end,
    }):render()

    if isOwned then
        product.purchaseButton.Active = false
    end

    if isOwned and product.hasToggle then
        self:addToggleSwitch(product, info)
    end

    self:addHoverLift(card)

    product.cardInstance = card
    return card
end

function Shop:addHoverLift(card)
    local original = card.Position
    card.MouseEnter:Connect(function()
        Core.Animation.tween(card, {
            Position = UDim2.new(original.X.Scale, original.X.Offset, original.Y.Scale, original.Y.Offset - 6)
        }, Core.CONSTANTS.ANIM_FAST)
    end)
    card.MouseLeave:Connect(function()
        Core.Animation.tween(card, {
            Position = original
        }, Core.CONSTANTS.ANIM_FAST)
    end)
end

function Shop:addToggleSwitch(product, parent)
    if product.toggleSwitch and product.toggleSwitch.Parent then
        product.toggleSwitch:Destroy()
        product.toggleSwitch = nil
    end

    local container = UI.Components.Frame({
        Name = "Toggle",
        BackgroundColor3 = UI.Theme:get("muted"),
        Size = UDim2.fromOffset(64, 32),
        Position = UDim2.new(1, -70, 0, 88),
        cornerRadius = UDim.new(1, 0),
        parent = parent,
    }):render()

    product.toggleSwitch = container

    local knob = UI.Components.Frame({
        BackgroundColor3 = UI.Theme:get("surface"),
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.fromOffset(2, 2),
        cornerRadius = UDim.new(1, 0),
        parent = container,
    }):render()

    local toggleState = false
    if Remotes then
        local request = Remotes:FindFirstChild("GetAutoCollectState")
        if request and request:IsA("RemoteFunction") then
            local success, state = pcall(function()
                return request:InvokeServer()
            end)
            if success and type(state) == "boolean" then
                toggleState = state
            end
        end
    end

    local function refresh()
        if toggleState then
            container.BackgroundColor3 = UI.Theme:get("success")
            Core.Animation.tween(knob, { Position = UDim2.fromOffset(34, 2) }, Core.CONSTANTS.ANIM_FAST)
        else
            container.BackgroundColor3 = UI.Theme:get("muted")
            Core.Animation.tween(knob, { Position = UDim2.fromOffset(2, 2) }, Core.CONSTANTS.ANIM_FAST)
        end
    end

    refresh()

    local hitArea = Instance.new("TextButton")
    hitArea.Text = ""
    hitArea.BackgroundTransparency = 1
    hitArea.Size = UDim2.fromScale(1, 1)
    hitArea.Parent = container

    hitArea.MouseButton1Click:Connect(function()
        toggleState = not toggleState
        refresh()
        Core.SoundSystem.play("click")

        if Remotes then
            local toggleRemote = Remotes:FindFirstChild("AutoCollectToggle")
            if toggleRemote and toggleRemote:IsA("RemoteEvent") then
                toggleRemote:FireServer(toggleState)
            end
        end
    end)
end

function Shop:selectTab(tabId)
    if self.currentTab == tabId then return end

    for id, tab in pairs(self.tabs) do
        local isActive = id == tabId
        Core.Animation.tween(tab.button, {
            BackgroundColor3 = isActive and Core.Utils.blend(tab.color, UI.Theme:get("surface"), 0.3) or UI.Theme:get("surfaceAlt"),
        }, Core.CONSTANTS.ANIM_FAST)

        if tab.icon then
            tab.icon.ImageColor3 = isActive and tab.color or UI.Theme:get("textSecondary")
        end

        if tab.label then
            Core.Animation.tween(tab.label, {
                TextColor3 = isActive and UI.Theme:get("text") or UI.Theme:get("textSecondary"),
            }, Core.CONSTANTS.ANIM_FAST)
        end
    end

    for id, page in pairs(self.pages) do
        local isActive = id == tabId
        page.Visible = isActive
        if isActive then
            page.Position = UDim2.fromOffset(0, 16)
            Core.Animation.tween(page, { Position = UDim2.fromOffset(0, 0) }, Core.CONSTANTS.ANIM_BOUNCE, Enum.EasingStyle.Back)
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
            type = productType,
            timestamp = tick(),
        }

        local success = pcall(function()
            MarketplaceService:PromptGamePassPurchase(Player, product.id)
        end)

        if not success then
            product.purchaseButton.Text = "Purchase"
            product.purchaseButton.Active = true
            Core.State.purchasePending[product.id] = nil
            return
        end

        task.delay(Core.CONSTANTS.PURCHASE_TIMEOUT, function()
            local pending = Core.State.purchasePending[product.id]
            if pending then
                product.purchaseButton.Text = "Purchase"
                product.purchaseButton.Active = true
                Core.State.purchasePending[product.id] = nil
            end
        end)
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
end

function Shop:refreshProduct(product, productType)
    if productType == "gamepass" then
        local owned = Core.DataManager.checkOwnership(product.id)
        if product.purchaseButton then
            product.purchaseButton.Text = owned and "Owned" or "Purchase"
            product.purchaseButton.BackgroundColor3 = owned and UI.Theme:get("success") or UI.Theme:get("accentAlt")
            product.purchaseButton.Active = not owned
        end

        if product.cardInstance then
            local stroke = product.cardInstance:FindFirstChildOfClass("UIStroke")
            if stroke then
                stroke.Color = owned and UI.Theme:get("success") or UI.Theme:get("stroke")
            end
        end

        if owned and product.hasToggle and product.infoContainer then
            self:addToggleSwitch(product, product.infoContainer)
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

    local size = self.mainPanel.Size
    self.mainPanel.Size = UDim2.fromOffset(size.X.Offset * 0.92, size.Y.Offset * 0.92)
    Core.Animation.tween(self.mainPanel, {
        Size = UDim2.fromOffset(size.X.Offset, size.Y.Offset),
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

    local size = self.mainPanel.Size
    Core.Animation.tween(self.mainPanel, {
        Size = UDim2.fromOffset(size.X.Offset * 0.96, size.Y.Offset * 0.96),
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

function Shop:addPulseAnimation(button)
    local running = true
    task.spawn(function()
        while running and button.Parent do
            Core.Animation.tween(button, { Size = UDim2.fromOffset(160, 50) }, 1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(1.2)
            if not running or not button.Parent then break end
            Core.Animation.tween(button, { Size = UDim2.fromOffset(156, 48) }, 1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(1.2)
        end
    end)

    button.AncestryChanged:Connect(function(_, parent)
        if not parent then
            running = false
        end
    end)
end

function Shop:setupRemoteHandlers()
    if not Remotes then return end

    local purchaseConfirm = Remotes:FindFirstChild("GamepassPurchased")
    if purchaseConfirm and purchaseConfirm:IsA("RemoteEvent") then
        purchaseConfirm.OnClientEvent:Connect(function()
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

function Shop:toggleGamepass(product)
    -- Placeholder toggle logic for designers to hook into remotes
    if Remotes then
        local toggleRemote = Remotes:FindFirstChild("AutoCollectToggle")
        if toggleRemote and toggleRemote:IsA("RemoteEvent") then
            toggleRemote:FireServer()
        end
    end
end

local shop = Shop.new()

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
    if player ~= Player then return end
    local pending = Core.State.purchasePending[passId]
    if not pending then return end

    Core.State.purchasePending[passId] = nil

    if purchased then
        ownershipCache:clear()
        Core.SoundSystem.play("success")
        if pending.product.purchaseButton then
            pending.product.purchaseButton.Text = "Owned"
            pending.product.purchaseButton.BackgroundColor3 = UI.Theme:get("success")
            pending.product.purchaseButton.Active = false
        end
        task.delay(0.3, function()
            shop:refreshAllProducts()
        end)
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
            local grant = Remotes:FindFirstChild("GrantProductCurrency")
            if grant and grant:IsA("RemoteEvent") then
                grant:FireServer(productId)
            end
        end
    end
end)

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

print("[SanrioShop] Market interface ready.")

return shop
