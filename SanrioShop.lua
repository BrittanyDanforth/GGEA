--[[
    SANRIO SHOP SYSTEM - PASTEL SHOWROOM EDITION
    Place this as a LocalScript in StarterPlayer > StarterPlayerScripts
    Name it: SanrioShop

    Visual redesign highlights:
    • Calm pastel palette inspired by Sanrio stationery aisles
    • Balanced column layout with tidy spacing for every section
    • Soft cards with clear hierarchy and ownership callouts
    • Gentle micro-interactions that keep the shop feeling welcoming
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

local Core = {}
Core.VERSION = "2.2.0"

Core.CONSTANTS = {
    PANEL_SIZE = Vector2.new(1180, 820),
    PANEL_SIZE_MOBILE = Vector2.new(940, 720),
    CARD_SIZE = Vector2.new(480, 300),
    CARD_SIZE_MOBILE = Vector2.new(420, 270),

    ANIM_FAST = 0.14,
    ANIM_MEDIUM = 0.25,
    ANIM_BOUNCE = 0.3,

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

local Cache = {}
Cache.__index = Cache

function Cache.new(duration)
    return setmetatable({data = {}, duration = duration or 300}, Cache)
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

Core.SoundSystem = {}

function Core.SoundSystem.initialize()
    local manifest = {
        click = {id = "rbxassetid://876939830", volume = 0.4},
        hover = {id = "rbxassetid://10066936758", volume = 0.2},
        open = {id = "rbxassetid://452267918", volume = 0.45},
        close = {id = "rbxassetid://452267918", volume = 0.35},
        success = {id = "rbxassetid://138081500", volume = 0.5},
        error = {id = "rbxassetid://63384199", volume = 0.45},
    }

    Core.SoundSystem.sounds = {}
    for name, config in pairs(manifest) do
        local sound = Instance.new("Sound")
        sound.Name = "SanrioShop_" .. name
        sound.SoundId = config.id
        sound.Volume = config.volume
        sound.Parent = SoundService
        Core.SoundSystem.sounds[name] = sound
    end
end

function Core.SoundSystem.play(name)
    if Core.State.settings.soundEnabled and Core.SoundSystem.sounds[name] then
        Core.SoundSystem.sounds[name]:Play()
    end
end

Core.DataManager = {}

Core.DataManager.products = {
    cash = {
        {
            id = 1897730242,
            amount = 1000,
            name = "1,000 Cash",
            description = "A gentle top up for finishing early builds.",
            icon = "rbxassetid://10709728059",
            featured = false,
            price = 0,
        },
        {
            id = 1897730373,
            amount = 5000,
            name = "5,000 Cash",
            description = "Great for unlocking the next cozy storefront.",
            icon = "rbxassetid://10709728059",
            featured = true,
            price = 0,
        },
        {
            id = 1897730467,
            amount = 10000,
            name = "10,000 Cash",
            description = "Perfect when you want to refresh half the tycoon.",
            icon = "rbxassetid://10709728059",
            featured = false,
            price = 0,
        },
        {
            id = 1897730581,
            amount = 50000,
            name = "50,000 Cash",
            description = "Your all-day restock bundle for serious shoppers.",
            icon = "rbxassetid://10709728059",
            featured = true,
            price = 0,
        },
    },
    gamepasses = {
        {
            id = 1412171840,
            name = "Auto Collect",
            description = "Scoops every drop for you while you decorate.",
            icon = "rbxassetid://10709727148",
            price = 99,
            hasToggle = true,
        },
        {
            id = 1398974710,
            name = "2x Cash",
            description = "Double every payout so upgrades stay affordable.",
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

local UI = {}

UI.Theme = {
    current = "pastel",
    themes = {
        pastel = {
            background = Color3.fromRGB(252, 247, 243),
            surface = Color3.fromRGB(255, 253, 250),
            surfaceAlt = Color3.fromRGB(248, 237, 242),
            stroke = Color3.fromRGB(222, 208, 211),
            text = Color3.fromRGB(58, 43, 50),
            textSecondary = Color3.fromRGB(134, 118, 126),
            accent = Color3.fromRGB(255, 154, 171),
            accentAlt = Color3.fromRGB(255, 198, 206),
            highlight = Color3.fromRGB(210, 225, 255),
            success = Color3.fromRGB(102, 186, 149),
            warning = Color3.fromRGB(255, 196, 123),
            error = Color3.fromRGB(235, 107, 107),
        }
    }
}

function UI.Theme:get(key)
    local theme = self.themes[self.current]
    return theme and theme[key]
end

UI.Components = {}

local Component = {}
Component.__index = Component

function Component.new(className, props)
    local self = setmetatable({}, Component)
    self.instance = Instance.new(className)
    self.props = props or {}
    self.eventConnections = {}
    return self
end

function Component:apply()
    for key, value in pairs(self.props) do
        if key ~= "children" and key ~= "parent" and key ~= "onClick" and key ~= "cornerRadius" and key ~= "stroke" then
            if type(value) == "function" and key:sub(1, 2) == "on" then
                local eventName = key:sub(3)
                local connection = self.instance[eventName]:Connect(value)
                table.insert(self.eventConnections, connection)
            else
                pcall(function() self.instance[key] = value end)
            end
        end
    end

    if self.props.onClick and self.instance:IsA("TextButton") then
        table.insert(self.eventConnections, self.instance.MouseButton1Click:Connect(self.props.onClick))
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
    if props.BackgroundColor3 == nil then
        props.BackgroundColor3 = UI.Theme:get("surface")
    end
    if props.BorderSizePixel == nil then
        props.BorderSizePixel = 0
    end
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
    if props.TextColor3 == nil then props.TextColor3 = Color3.new(0, 0, 0) end
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
                originalSize.X.Offset + 6,
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
    if props.ScrollBarThickness == nil then props.ScrollBarThickness = 6 end
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
            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                if layoutConfig.type == "List" then
                    if props.ScrollingDirection == Enum.ScrollingDirection.X then
                        component.instance.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X + 24, 0, 0)
                    else
                        component.instance.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 24)
                    end
                else
                    component.instance.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 24)
                end
            end)
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
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
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

UI.Responsive = {}

function UI.Responsive.scale(instance)
    local camera = workspace.CurrentCamera
    if not camera then return end

    local scale = Instance.new("UIScale")
    scale.Parent = instance

    local function updateScale()
        local viewport = camera.ViewportSize
        local factor = math.min(viewport.X / 1920, viewport.Y / 1080)
        factor = Core.Utils.clamp(factor, 0.55, 1.35)
        if Core.Utils.isMobile() then
            factor = factor * 0.9
        end
        scale.Scale = factor
    end

    updateScale()
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

    return scale
end

local Shop = {}
Shop.__index = Shop

function Shop.new()
    local self = setmetatable({}, Shop)
    self.gui = nil
    self.mainPanel = nil
    self.tabContainer = nil
    self.contentContainer = nil
    self.toggleButton = nil
    self.blur = nil
    self.currentTab = nil
    self.tabs = {}
    self.pages = {}
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
    toggleScreen.DisplayOrder = 999
    toggleScreen.Parent = PlayerGui

    self.toggleButton = UI.Components.Button({
        Name = "ShopToggle",
        Text = "",
        Size = UDim2.fromOffset(190, 60),
        Position = UDim2.new(1, -28, 1, -28),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = UI.Theme:get("surface"),
        TextColor3 = UI.Theme:get("text"),
        cornerRadius = UDim.new(1, 0),
        stroke = { color = UI.Theme:get("accent"), thickness = 1, transparency = 0.2 },
        parent = toggleScreen,
        onClick = function()
            self:toggle()
        end,
    }):render()

    local icon = UI.Components.Image({
        Name = "Icon",
        Image = "rbxassetid://17398522865",
        Size = UDim2.fromOffset(32, 32),
        Position = UDim2.fromOffset(18, 14),
        parent = self.toggleButton,
    }):render()

    local label = UI.Components.TextLabel({
        Name = "Label",
        Text = "Sanrio Shop",
        Font = Enum.Font.GothamMedium,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -70, 1, 0),
        Position = UDim2.fromOffset(60, 0),
        parent = self.toggleButton,
    }):render()

    icon.ImageColor3 = UI.Theme:get("accent")
    label.TextColor3 = UI.Theme:get("text")
end

function Shop:createMainInterface()
    self.gui = PlayerGui:FindFirstChild("SanrioShopMain") or Instance.new("ScreenGui")
    self.gui.Name = "SanrioShopMain"
    self.gui.ResetOnSpawn = false
    self.gui.DisplayOrder = 1000
    self.gui.Enabled = false
    self.gui.IgnoreGuiInset = true
    self.gui.Parent = PlayerGui

    self.blur = Lighting:FindFirstChild("SanrioShopBlur") or Instance.new("BlurEffect")
    self.blur.Name = "SanrioShopBlur"
    self.blur.Size = 0
    self.blur.Parent = Lighting

    local dim = UI.Components.Frame({
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.45,
        parent = self.gui,
    }):render()

    local sizeVector = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE

    self.mainPanel = UI.Components.Frame({
        Size = UDim2.fromOffset(sizeVector.X, sizeVector.Y),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(0, 28),
        stroke = { color = UI.Theme:get("stroke"), thickness = 1, transparency = 0.35 },
        parent = self.gui,
    }):render()

    UI.Responsive.scale(self.mainPanel)

    self:createHeader(self.mainPanel)
    self:createTabBar(self.mainPanel)

    self.contentContainer = UI.Components.Frame({
        Name = "ContentContainer",
        Size = UDim2.new(1, -48, 1, -236),
        Position = UDim2.fromOffset(24, 200),
        BackgroundTransparency = 1,
        parent = self.mainPanel,
    }):render()

    self:createPages()
    self:selectTab("Home")
end

function Shop:createHeader(parent)
    local header = UI.Components.Frame({
        Name = "Header",
        Size = UDim2.new(1, -48, 0, 110),
        Position = UDim2.fromOffset(24, 24),
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        cornerRadius = UDim.new(0, 22),
        stroke = { color = UI.Theme:get("stroke"), thickness = 1, transparency = 0.45 },
        parent = parent,
    }):render()

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 20)
    padding.PaddingBottom = UDim.new(0, 20)
    padding.PaddingLeft = UDim.new(0, 24)
    padding.PaddingRight = UDim.new(0, 24)
    padding.Parent = header

    UI.Components.TextLabel({
        Name = "Title",
        Text = "Sanrio Shop",
        Size = UDim2.new(0.6, 0, 0, 38),
        Font = Enum.Font.GothamBold,
        TextSize = 30,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = header,
    }):render()

    UI.Components.TextLabel({
        Name = "Subtitle",
        Text = "Pick up gentle boosts and cute upgrades without the clutter.",
        Size = UDim2.new(0.75, 0, 0, 26),
        Position = UDim2.fromOffset(0, 44),
        Font = Enum.Font.Gotham,
        TextSize = 18,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = header,
    }):render()

    UI.Components.Button({
        Name = "CloseButton",
        Text = "✕",
        Size = UDim2.fromOffset(48, 48),
        Position = UDim2.new(1, -8, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = UI.Theme:get("surface"),
        TextColor3 = UI.Theme:get("text"),
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        cornerRadius = UDim.new(1, 0),
        parent = header,
        onClick = function()
            self:close()
        end,
    }):render()

    local infoRow = UI.Components.Frame({
        Name = "InfoRow",
        Size = UDim2.new(0, 260, 0, 30),
        Position = UDim2.new(1, -280, 0, 8),
        BackgroundTransparency = 1,
        parent = header,
    }):render()

    UI.Layout.stack(infoRow, Enum.FillDirection.Horizontal, 8)

    local function createChip(text)
        local chip = UI.Components.Frame({
            Size = UDim2.new(0, 120, 0, 30),
            BackgroundColor3 = UI.Theme:get("accentAlt"),
            cornerRadius = UDim.new(1, 0),
            parent = infoRow,
        }):render()

        UI.Components.TextLabel({
            Text = text,
            Size = UDim2.fromScale(1, 1),
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            TextColor3 = UI.Theme:get("text"),
            parent = chip,
        }):render()
    end

    createChip("Daily picks")
    createChip("Auto refresh")
end

function Shop:createTabBar(parent)
    local container = UI.Components.Frame({
        Name = "TabContainer",
        Size = UDim2.new(1, -48, 0, 56),
        Position = UDim2.fromOffset(24, 144),
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        cornerRadius = UDim.new(1, 0),
        stroke = { color = UI.Theme:get("stroke"), thickness = 1, transparency = 0.45 },
        parent = parent,
    }):render()

    UI.Layout.stack(container, Enum.FillDirection.Horizontal, 12, {left = 16, right = 16})

    local tabs = {
        {id = "Home", name = "Overview", icon = "rbxassetid://8941080291", color = UI.Theme:get("accent")},
        {id = "Cash", name = "Cash Bundles", icon = "rbxassetid://10709728059", color = UI.Theme:get("highlight")},
        {id = "Gamepasses", name = "Upgrades", icon = "rbxassetid://10709727148", color = Color3.fromRGB(211, 189, 255)},
    }

    for index, data in ipairs(tabs) do
        local button = UI.Components.Button({
            Name = data.id .. "Tab",
            Text = "",
            Size = UDim2.new(1 / #tabs, -8, 1, 0),
            BackgroundColor3 = UI.Theme:get("surface"),
            cornerRadius = UDim.new(1, 0),
            stroke = { color = UI.Theme:get("stroke"), thickness = 1, transparency = 0.5 },
            LayoutOrder = index,
            parent = container,
            onClick = function()
                self:selectTab(data.id)
            end,
        }):render()

        local inner = UI.Components.Frame({
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            parent = button,
        }):render()

        UI.Layout.stack(inner, Enum.FillDirection.Horizontal, 10, {left = 18, right = 18})

        local iconFrame = UI.Components.Frame({
            Size = UDim2.fromOffset(30, 30),
            BackgroundColor3 = data.color,
            cornerRadius = UDim.new(1, 0),
            parent = inner,
        }):render()

        UI.Components.Image({
            Image = data.icon,
            Size = UDim2.fromOffset(20, 20),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            parent = iconFrame,
        }):render()

        local label = UI.Components.TextLabel({
            Text = data.name,
            Size = UDim2.new(1, -70, 1, 0),
            Font = Enum.Font.GothamMedium,
            TextSize = 16,
            TextColor3 = UI.Theme:get("textSecondary"),
            TextXAlignment = Enum.TextXAlignment.Left,
            parent = inner,
        }):render()

        self.tabs[data.id] = {
            button = button,
            label = label,
            iconFrame = iconFrame,
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
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        parent = self.contentContainer,
    }):render()

    local scroll = UI.Components.ScrollingFrame({
        Size = UDim2.fromScale(1, 1),
        layout = { type = "List", Padding = UDim.new(0, 28), HorizontalAlignment = Enum.HorizontalAlignment.Center },
        padding = { top = UDim.new(0, 12), bottom = UDim.new(0, 12) },
        parent = page,
    }):render()

    self:createHeroSection(scroll)

    UI.Components.TextLabel({
        Text = "Today's featured bundles",
        Size = UDim2.new(1, -40, 0, 32),
        Font = Enum.Font.GothamBold,
        TextSize = 24,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,
        parent = scroll,
    }):render()

    UI.Components.TextLabel({
        Text = "Swipe through for gentle boosts curated for this session.",
        Size = UDim2.new(1, -40, 0, 26),
        Font = Enum.Font.Gotham,
        TextSize = 16,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 3,
        parent = scroll,
    }):render()

    local featured = UI.Components.Frame({
        Size = UDim2.new(1, 0, 0, 340),
        BackgroundTransparency = 1,
        LayoutOrder = 4,
        parent = scroll,
    }):render()

    local xScroll = UI.Components.ScrollingFrame({
        Size = UDim2.fromScale(1, 1),
        ScrollingDirection = Enum.ScrollingDirection.X,
        layout = { type = "List", FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 18) },
        padding = { left = UDim.new(0, 10), right = UDim.new(0, 10) },
        parent = featured,
    }):render()

    for _, product in ipairs(Core.DataManager.products.cash) do
        if product.featured then
            self:createProductCard(product, "cash", xScroll, true)
        end
    end

    return page
end

function Shop:createCashPage()
    local page = UI.Components.Frame({
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
            CellPadding = UDim2.fromOffset(24, 24),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
        },
        padding = { top = UDim.new(0, 14), bottom = UDim.new(0, 14), left = UDim.new(0, 14), right = UDim.new(0, 14) },
        parent = page,
    }):render()

    for _, product in ipairs(Core.DataManager.products.cash) do
        self:createProductCard(product, "cash", grid)
    end

    return page
end

function Shop:createGamepassesPage()
    local page = UI.Components.Frame({
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
            CellPadding = UDim2.fromOffset(24, 24),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
        },
        padding = { top = UDim.new(0, 14), bottom = UDim.new(0, 14), left = UDim.new(0, 14), right = UDim.new(0, 14) },
        parent = page,
    }):render()

    for _, pass in ipairs(Core.DataManager.products.gamepasses) do
        self:createProductCard(pass, "gamepass", grid)
    end

    return page
end

function Shop:createHeroSection(parent)
    local hero = UI.Components.Frame({
        Size = UDim2.new(1, -16, 0, 220),
        BackgroundColor3 = UI.Theme:get("accentAlt"),
        cornerRadius = UDim.new(0, 24),
        LayoutOrder = 1,
        parent = parent,
    }):render()

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, UI.Theme:get("accentAlt")),
        ColorSequenceKeypoint.new(1, UI.Theme:get("highlight")),
    })
    gradient.Rotation = -15
    gradient.Parent = hero

    UI.Layout.stack(hero, Enum.FillDirection.Horizontal, 28, {left = 36, right = 36, top = 34, bottom = 34})

    local textColumn = UI.Components.Frame({
        Size = UDim2.new(0.58, 0, 1, 0),
        BackgroundTransparency = 1,
        parent = hero,
    }):render()

    UI.Components.TextLabel({
        Text = "Welcome back, " .. Player.DisplayName .. "!",
        Size = UDim2.new(1, 0, 0, 42),
        Font = Enum.Font.GothamBold,
        TextSize = 30,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = textColumn,
    }):render()

    UI.Components.TextLabel({
        Text = "Refresh your tycoon with soft boosts and premium passes picked for today.",
        Size = UDim2.new(1, 0, 0, 56),
        Position = UDim2.fromOffset(0, 46),
        Font = Enum.Font.Gotham,
        TextSize = 18,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = textColumn,
    }):render()

    local bulletList = UI.Components.Frame({
        Size = UDim2.new(1, 0, 0, 60),
        Position = UDim2.fromOffset(0, 108),
        BackgroundTransparency = 1,
        parent = textColumn,
    }):render()

    UI.Layout.stack(bulletList, Enum.FillDirection.Vertical, 6)

    local points = {
        "Seasonal deals update every 30 minutes",
        "Gamepass toggles right inside the card",
        "Ownership status saved the moment you buy",
    }

    for _, point in ipairs(points) do
        local row = UI.Components.Frame({
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            parent = bulletList,
        }):render()

        UI.Components.TextLabel({
            Text = "• " .. point,
            Size = UDim2.fromScale(1, 1),
            Font = Enum.Font.Gotham,
            TextSize = 16,
            TextColor3 = UI.Theme:get("text"),
            TextXAlignment = Enum.TextXAlignment.Left,
            parent = row,
        }):render()
    end

    UI.Components.Button({
        Text = "Browse cash bundles",
        Size = UDim2.fromOffset(220, 48),
        Position = UDim2.fromOffset(0, 170),
        BackgroundColor3 = UI.Theme:get("surface"),
        TextColor3 = UI.Theme:get("text"),
        cornerRadius = UDim.new(1, 0),
        parent = textColumn,
        onClick = function()
            self:selectTab("Cash")
        end,
    }):render()

    local visual = UI.Components.Frame({
        Size = UDim2.new(0.32, 0, 1.05, 0),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(0, 20),
        parent = hero,
    }):render()

    local visualStroke = Instance.new("UIStroke")
    visualStroke.Color = UI.Theme:get("stroke")
    visualStroke.Thickness = 1
    visualStroke.Transparency = 0.4
    visualStroke.Parent = visual

    UI.Components.Image({
        Image = "rbxassetid://10720927454",
        Size = UDim2.new(1, -20, 1, -20),
        Position = UDim2.fromOffset(10, 10),
        parent = visual,
    }):render()

    return hero
end

function Shop:createProductCard(product, productType, parent, wide)
    local isGamepass = productType == "gamepass"
    local accent = isGamepass and Color3.fromRGB(206, 189, 255) or UI.Theme:get("accent")
    local accentSoft = Core.Utils.blend(accent, Color3.new(1, 1, 1), 0.6)

    local width = wide and ((Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.X + 40) or (Core.CONSTANTS.CARD_SIZE.X + 60))
        or (Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.X or Core.CONSTANTS.CARD_SIZE.X)
    local height = wide and ((Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.Y + 30) or (Core.CONSTANTS.CARD_SIZE.Y + 20))
        or (Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.Y or Core.CONSTANTS.CARD_SIZE.Y)

    local card = UI.Components.Frame({
        Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(0, 22),
        stroke = { color = Core.Utils.blend(accent, UI.Theme:get("stroke"), 0.5), thickness = 1, transparency = 0.25 },
        parent = parent,
    }):render()

    self:addCardHoverEffect(card)

    product.cardAccent = accent

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 20)
    padding.PaddingBottom = UDim.new(0, 20)
    padding.PaddingLeft = UDim.new(0, 22)
    padding.PaddingRight = UDim.new(0, 22)
    padding.Parent = card

    local imageStrip = UI.Components.Frame({
        Size = UDim2.new(1, 0, 0, 136),
        BackgroundColor3 = accentSoft,
        cornerRadius = UDim.new(0, 18),
        parent = card,
    }):render()

    UI.Components.Image({
        Image = product.icon or "rbxassetid://0",
        Size = UDim2.new(0.55, 0, 0.55, 0),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        parent = imageStrip,
    }):render()

    local info = UI.Components.Frame({
        Size = UDim2.new(1, 0, 1, -152),
        Position = UDim2.fromOffset(0, 152),
        BackgroundTransparency = 1,
        parent = card,
    }):render()

    product.infoContainer = info

    if product.featured then
        local badge = UI.Components.TextLabel({
            Name = "FeaturedBadge",
            Text = "featured",
            Size = UDim2.new(0, 100, 0, 26),
            Position = UDim2.fromOffset(12, 12),
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            TextColor3 = UI.Theme:get("text"),
            BackgroundColor3 = UI.Theme:get("surface"),
            parent = card,
        }):render()

        local badgeCorner = Instance.new("UICorner")
        badgeCorner.CornerRadius = UDim.new(1, 0)
        badgeCorner.Parent = badge

        local badgeStroke = Instance.new("UIStroke")
        badgeStroke.Color = accent
        badgeStroke.Thickness = 1
        badgeStroke.Transparency = 0.2
        badgeStroke.Parent = badge
    end

    UI.Components.TextLabel({
        Text = product.name,
        Size = UDim2.new(1, 0, 0, 28),
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = info,
    }):render()

    UI.Components.TextLabel({
        Text = product.description,
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.fromOffset(0, 34),
        Font = Enum.Font.Gotham,
        TextSize = 15,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = info,
    }):render()

    if not isGamepass then
        local amountLabel = UI.Components.TextLabel({
            Text = Core.Utils.formatNumber(product.amount) .. " cash",
            Size = UDim2.new(0, 140, 0, 26),
            Position = UDim2.fromOffset(0, 80),
            Font = Enum.Font.GothamMedium,
            TextSize = 16,
            TextColor3 = UI.Theme:get("text"),
            BackgroundColor3 = accentSoft,
            parent = info,
        }):render()

        local amountCorner = Instance.new("UICorner")
        amountCorner.CornerRadius = UDim.new(1, 0)
        amountCorner.Parent = amountLabel
    end

    local priceText = isGamepass and ("R$" .. tostring(product.price or 0)) or
        ("R$" .. tostring(product.price or 0))

    UI.Components.TextLabel({
        Text = priceText,
        Size = UDim2.new(1, 0, 0, 24),
        Position = UDim2.fromOffset(0, isGamepass and 80 or 112),
        Font = Enum.Font.GothamSemibold,
        TextSize = 18,
        TextColor3 = accent,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = info,
    }):render()

    local owned = isGamepass and Core.DataManager.checkOwnership(product.id)

    local button = UI.Components.Button({
        Text = owned and "Owned" or "Purchase",
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.new(0, 0, 1, -44),
        BackgroundColor3 = owned and UI.Theme:get("success") or accent,
        TextColor3 = owned and Color3.new(1, 1, 1) or UI.Theme:get("text"),
        cornerRadius = UDim.new(0, 14),
        parent = info,
        onClick = function()
            if not owned then
                self:promptPurchase(product, productType)
            end
        end,
    }):render()

    button.Active = not owned

    if owned then
        local badge = UI.Components.TextLabel({
            Name = "OwnedBadge",
            Text = "owned",
            Size = UDim2.new(0, 72, 0, 26),
            Position = UDim2.fromOffset(16, 12),
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            TextColor3 = UI.Theme:get("text"),
            BackgroundColor3 = UI.Theme:get("success"),
            parent = card,
        }):render()

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = badge
    end

    if owned and product.hasToggle then
        self:addToggleSwitch(product, info)
    end

    product.cardInstance = card
    product.purchaseButton = button

    return card
end

function Shop:addCardHoverEffect(card)
    local original = card.Position
    card.MouseEnter:Connect(function()
        Core.Animation.tween(card, {
            Position = UDim2.new(original.X.Scale, original.X.Offset, original.Y.Scale, original.Y.Offset - 6)
        }, Core.CONSTANTS.ANIM_FAST)
    end)
    card.MouseLeave:Connect(function()
        Core.Animation.tween(card, { Position = original }, Core.CONSTANTS.ANIM_FAST)
    end)
end

function Shop:addToggleSwitch(product, parent)
    local container = UI.Components.Frame({
        Name = "ToggleContainer",
        Size = UDim2.fromOffset(72, 32),
        Position = UDim2.new(1, -76, 0, 86),
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        cornerRadius = UDim.new(1, 0),
        stroke = { color = product.cardAccent or UI.Theme:get("accent"), thickness = 1, transparency = 0.3 },
        parent = parent,
    }):render()

    local knob = UI.Components.Frame({
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(1, 0),
        parent = container,
    }):render()

    local state = false
    if Remotes then
        local getState = Remotes:FindFirstChild("GetAutoCollectState")
        if getState and getState:IsA("RemoteFunction") then
            local ok, value = pcall(function()
                return getState:InvokeServer()
            end)
            if ok and type(value) == "boolean" then
                state = value
            end
        end
    end

    local function updateVisual()
        if state then
            Core.Animation.tween(container, {
                BackgroundColor3 = product.cardAccent or UI.Theme:get("accent")
            }, Core.CONSTANTS.ANIM_FAST)
            Core.Animation.tween(knob, { Position = UDim2.fromOffset(42, 2) }, Core.CONSTANTS.ANIM_FAST)
        else
            Core.Animation.tween(container, {
                BackgroundColor3 = UI.Theme:get("surfaceAlt")
            }, Core.CONSTANTS.ANIM_FAST)
            Core.Animation.tween(knob, { Position = UDim2.fromOffset(2, 2) }, Core.CONSTANTS.ANIM_FAST)
        end
    end

    updateVisual()

    local button = Instance.new("TextButton")
    button.Text = ""
    button.BackgroundTransparency = 1
    button.Size = UDim2.fromScale(1, 1)
    button.Parent = container

    button.MouseButton1Click:Connect(function()
        state = not state
        updateVisual()
        if Remotes then
            local toggle = Remotes:FindFirstChild("AutoCollectToggle")
            if toggle and toggle:IsA("RemoteEvent") then
                toggle:FireServer(state)
            end
        end
        Core.SoundSystem.play("click")
    end)
end

function Shop:createTabHighlight(tabId)
    for id, tab in pairs(self.tabs) do
        local active = id == tabId
        local color = tab.color
        Core.Animation.tween(tab.button, {
            BackgroundColor3 = active and Core.Utils.blend(color, Color3.new(1, 1, 1), 0.3) or UI.Theme:get("surface")
        }, Core.CONSTANTS.ANIM_FAST)

        local stroke = tab.button:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = active and color or UI.Theme:get("stroke")
        end

        tab.label.TextColor3 = active and UI.Theme:get("text") or UI.Theme:get("textSecondary")

        Core.Animation.tween(tab.iconFrame, {
            BackgroundColor3 = active and color or UI.Theme:get("accentAlt")
        }, Core.CONSTANTS.ANIM_FAST)
    end
end

function Shop:selectTab(tabId)
    if self.currentTab == tabId then return end

    self:createTabHighlight(tabId)

    for id, page in pairs(self.pages) do
        page.Visible = id == tabId
        if id == tabId then
            page.Position = UDim2.fromOffset(0, 20)
            Core.Animation.tween(page, { Position = UDim2.new() }, Core.CONSTANTS.ANIM_BOUNCE, Enum.EasingStyle.Back)
        end
    end

    self.currentTab = tabId
    Core.State.currentTab = tabId
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

        Core.State.purchasePending[product.id] = { product = product, type = productType }

        local ok = pcall(function()
            MarketplaceService:PromptGamePassPurchase(Player, product.id)
        end)

        if not ok then
            product.purchaseButton.Text = "Purchase"
            product.purchaseButton.Active = true
            Core.State.purchasePending[product.id] = nil
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
        Core.State.purchasePending[product.id] = { product = product, type = productType }
        local ok = pcall(function()
            MarketplaceService:PromptProductPurchase(Player, product.id)
        end)
        if not ok then
            Core.State.purchasePending[product.id] = nil
        end
    end
end

function Shop:refreshProduct(product, productType)
    if productType == "gamepass" then
        local owned = Core.DataManager.checkOwnership(product.id)
        if product.purchaseButton then
            product.purchaseButton.Text = owned and "Owned" or "Purchase"
            product.purchaseButton.BackgroundColor3 = owned and UI.Theme:get("success") or product.cardAccent or UI.Theme:get("accent")
            product.purchaseButton.TextColor3 = owned and Color3.new(1, 1, 1) or UI.Theme:get("text")
            product.purchaseButton.Active = not owned
        end

        if product.cardInstance then
            local stroke = product.cardInstance:FindFirstChildOfClass("UIStroke")
            if stroke then
                stroke.Color = owned and UI.Theme:get("success") or product.cardAccent or UI.Theme:get("accent")
            end

            local ownedBadge = product.cardInstance:FindFirstChild("OwnedBadge")
            if owned and not ownedBadge then
                ownedBadge = UI.Components.TextLabel({
                    Name = "OwnedBadge",
                    Text = "owned",
                    Size = UDim2.new(0, 72, 0, 26),
                    Position = UDim2.fromOffset(16, 12),
                    Font = Enum.Font.GothamMedium,
                    TextSize = 14,
                    TextColor3 = UI.Theme:get("text"),
                    BackgroundColor3 = UI.Theme:get("success"),
                    parent = product.cardInstance,
                }):render()

                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(1, 0)
                corner.Parent = ownedBadge
            elseif not owned and ownedBadge then
                ownedBadge:Destroy()
            end

            if product.hasToggle and product.infoContainer then
                local toggle = product.infoContainer:FindFirstChild("ToggleContainer")
                if owned and not toggle then
                    self:addToggleSwitch(product, product.infoContainer)
                elseif not owned and toggle then
                    toggle:Destroy()
                end
            end
        end
    end
end

function Shop:refreshAllProducts()
    ownershipCache:clear()
    for _, pass in ipairs(Core.DataManager.products.gamepasses) do
        self:refreshProduct(pass, "gamepass")
    end
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
    }, Core.CONSTANTS.ANIM_BOUNCE, Enum.EasingStyle.Back)

    Core.SoundSystem.play("open")

    task.delay(Core.CONSTANTS.ANIM_BOUNCE, function()
        Core.State.isAnimating = false
    end)

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

    task.delay(Core.CONSTANTS.ANIM_FAST, function()
        self.gui.Enabled = false
        Core.State.isAnimating = false
    end)

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
            Core.Animation.tween(button, { Size = UDim2.fromOffset(94, 94) }, 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(1.5)
            if not running or not button.Parent then break end
            Core.Animation.tween(button, { Size = UDim2.fromOffset(88, 88) }, 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(1.5)
        end
    end)

    button.AncestryChanged:Connect(function(_, parent)
        if not parent then running = false end
    end)
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

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
    if player ~= Player then return end
    local pending = Core.State.purchasePending[passId]
    if not pending then return end
    Core.State.purchasePending[passId] = nil

    if purchased then
        ownershipCache:clear()
        if pending.product.purchaseButton then
            pending.product.purchaseButton.Text = "Equipped"
            pending.product.purchaseButton.BackgroundColor3 = UI.Theme:get("success")
            pending.product.purchaseButton.Active = false
        end
        Core.SoundSystem.play("success")
        task.delay(0.4, function()
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

local shop = Shop.new()

Player.CharacterAdded:Connect(function()
    task.wait(1)
    if not shop.toggleButton or not shop.toggleButton.Parent then
        shop:createToggleButton()
    end
end)

spawn(function()
    while true do
        task.wait(30)
        if Core.State.isOpen then
            shop:refreshAllProducts()
        end
    end
end)

print("[SanrioShop] Pastel showroom initialized.")

return shop
