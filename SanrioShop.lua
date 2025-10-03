--[[
    SANRIO SHOP SYSTEM - NEON EDITION
    Place this as a LocalScript in StarterPlayer > StarterPlayerScripts
    Name it: SanrioShop

    Visual redesign highlights:
    • Vertical neon navigation rail with contextual hints
    • Split glass content shell with gradient hero banner
    • Floating product cards with glow halos and ownership badges
    • Compact toggle button rewritten as a soft neon orb
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
Core.VERSION = "4.0.0"

Core.CONSTANTS = {
    PANEL_SIZE = Vector2.new(1320, 860),
    PANEL_SIZE_MOBILE = Vector2.new(960, 720),
    CARD_SIZE = Vector2.new(500, 320),
    CARD_SIZE_MOBILE = Vector2.new(440, 280),

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
        open = {id = "rbxassetid://184168568", volume = 0.45},
        close = {id = "rbxassetid://184168757", volume = 0.45},
        success = {id = "rbxassetid://138081500", volume = 0.55},
        error = {id = "rbxassetid://63384199", volume = 0.5},
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
            description = "Ignite a quick upgrade with a tiny surge.",
            icon = "rbxassetid://10709728059",
            featured = false,
            price = 0,
        },
        {
            id = 1897730373,
            amount = 5000,
            name = "5,000 Cash",
            description = "Mid-tier burst for expansion momentum.",
            icon = "rbxassetid://10709728059",
            featured = true,
            price = 0,
        },
        {
            id = 1897730467,
            amount = 10000,
            name = "10,000 Cash",
            description = "Double down on facility upgrades instantly.",
            icon = "rbxassetid://10709728059",
            featured = false,
            price = 0,
        },
        {
            id = 1897730581,
            amount = 50000,
            name = "50,000 Cash",
            description = "Flagship bundle for tycoons in overdrive.",
            icon = "rbxassetid://10709728059",
            featured = true,
            price = 0,
        },
    },
    gamepasses = {
        {
            id = 1412171840,
            name = "Auto Collect",
            description = "Magnetize every drop straight to your wallet.",
            icon = "rbxassetid://10709727148",
            price = 99,
            hasToggle = true,
        },
        {
            id = 1398974710,
            name = "2x Cash",
            description = "Permanent double earnings across the board.",
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
    current = "neon",
    themes = {
        neon = {
            background = Color3.fromRGB(13, 17, 26),
            surface = Color3.fromRGB(26, 32, 46),
            surfaceAlt = Color3.fromRGB(36, 44, 62),
            rail = Color3.fromRGB(23, 28, 42),
            stroke = Color3.fromRGB(58, 72, 108),
            text = Color3.fromRGB(229, 236, 255),
            textSecondary = Color3.fromRGB(148, 158, 188),
            accent = Color3.fromRGB(132, 98, 255),
            accentAlt = Color3.fromRGB(60, 205, 255),
            success = Color3.fromRGB(80, 214, 162),
            warning = Color3.fromRGB(255, 200, 120),
            error = Color3.fromRGB(255, 110, 150),
        }
    }
}

function UI.Theme:get(key)
    return self.themes[self.current][key]
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
        Text = "",
        Size = UDim2.fromOffset(88, 88),
        Position = UDim2.new(0, 32, 1, -32),
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = UI.Theme:get("accent"),
        cornerRadius = UDim.new(1, 0),
        stroke = { color = UI.Theme:get("accentAlt"), thickness = 2, transparency = 0.25 },
        parent = toggleScreen,
        onClick = function()
            self:toggle()
        end,
    }):render()

    UI.Components.Image({
        Image = "rbxassetid://17398522865",
        Size = UDim2.fromOffset(44, 44),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
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
    self.gui.IgnoreGuiInset = true
    self.gui.Parent = PlayerGui

    self.blur = Lighting:FindFirstChild("SanrioShopBlur") or Instance.new("BlurEffect")
    self.blur.Name = "SanrioShopBlur"
    self.blur.Size = 0
    self.blur.Parent = Lighting

    local dim = UI.Components.Frame({
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.35,
        parent = self.gui,
    }):render()

    local sizeVector = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE

    self.mainPanel = UI.Components.Frame({
        Size = UDim2.fromOffset(sizeVector.X, sizeVector.Y),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        cornerRadius = UDim.new(0, 28),
        stroke = { color = UI.Theme:get("stroke"), thickness = 2, transparency = 0.25 },
        parent = self.gui,
    }):render()

    UI.Responsive.scale(self.mainPanel)

    local navRail = UI.Components.Frame({
        Size = UDim2.new(0, 240, 1, -40),
        Position = UDim2.fromOffset(24, 20),
        BackgroundColor3 = UI.Theme:get("rail"),
        cornerRadius = UDim.new(0, 24),
        stroke = { color = UI.Theme:get("stroke"), thickness = 1, transparency = 0.3 },
        parent = self.mainPanel,
    }):render()

    UI.Components.TextLabel({
        Text = "SANRIO",
        Size = UDim2.new(1, -40, 0, 40),
        Position = UDim2.fromOffset(20, 18),
        Font = Enum.Font.GothamBlack,
        TextSize = 26,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = UI.Theme:get("textSecondary"),
        parent = navRail,
    }):render()

    self:createTabBar(navRail)

    local contentShell = UI.Components.Frame({
        Size = UDim2.new(1, -300, 1, -80),
        Position = UDim2.fromOffset(280, 40),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(0, 26),
        stroke = { color = UI.Theme:get("stroke"), thickness = 1, transparency = 0.3 },
        parent = self.mainPanel,
    }):render()

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 28)
    padding.PaddingBottom = UDim.new(0, 28)
    padding.PaddingLeft = UDim.new(0, 32)
    padding.PaddingRight = UDim.new(0, 32)
    padding.Parent = contentShell

    self:createHeader(contentShell)

    self.contentContainer = UI.Components.Frame({
        Size = UDim2.new(1, 0, 1, -190),
        Position = UDim2.fromOffset(0, 150),
        BackgroundTransparency = 1,
        parent = contentShell,
    }):render()

    self:createPages()
    self:selectTab("Home")
end

function Shop:createHeader(parent)
    local header = UI.Components.Frame({
        Size = UDim2.new(1, 0, 0, 120),
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        cornerRadius = UDim.new(0, 22),
        stroke = { color = UI.Theme:get("stroke"), thickness = 1, transparency = 0.4 },
        parent = parent,
    }):render()

    local headerPadding = Instance.new("UIPadding")
    headerPadding.PaddingTop = UDim.new(0, 24)
    headerPadding.PaddingBottom = UDim.new(0, 24)
    headerPadding.PaddingLeft = UDim.new(0, 26)
    headerPadding.PaddingRight = UDim.new(0, 26)
    headerPadding.Parent = header

    UI.Components.TextLabel({
        Text = "Sanrio Supply Vault",
        Size = UDim2.new(0.7, 0, 0, 42),
        Font = Enum.Font.GothamBlack,
        TextSize = 32,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = header,
    }):render()

    UI.Components.TextLabel({
        Text = "Curated boosts, pastel tech aesthetics, zero clutter.",
        Size = UDim2.new(0.6, 0, 0, 28),
        Position = UDim2.fromOffset(0, 48),
        Font = Enum.Font.Gotham,
        TextSize = 18,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = header,
    }):render()

    UI.Components.Button({
        Text = "✕",
        Size = UDim2.fromOffset(52, 52),
        Position = UDim2.new(1, -52, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = UI.Theme:get("surface"),
        TextColor3 = UI.Theme:get("text"),
        Font = Enum.Font.GothamBold,
        TextSize = 22,
        cornerRadius = UDim.new(1, 0),
        parent = header,
        onClick = function()
            self:close()
        end,
    }):render()

    local statusRow = UI.Components.Frame({
        Size = UDim2.new(0, 220, 0, 30),
        Position = UDim2.new(1, -230, 0, 16),
        BackgroundTransparency = 1,
        parent = header,
    }):render()

    UI.Layout.stack(statusRow, Enum.FillDirection.Horizontal, 10)

    local function pill(text)
        local frame = UI.Components.Frame({
            Size = UDim2.new(0, 110, 0, 30),
            BackgroundColor3 = Core.Utils.blend(UI.Theme:get("accentAlt"), Color3.new(0, 0, 0), 0.7),
            cornerRadius = UDim.new(1, 0),
            parent = statusRow,
        }):render()
        UI.Components.TextLabel({
            Text = text,
            Size = UDim2.fromScale(1, 1),
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            TextColor3 = UI.Theme:get("accentAlt"),
            parent = frame,
        }):render()
    end

    pill("LIVE")
    pill("AUTO REFRESH")
end

function Shop:createTabBar(parent)
    local container = UI.Components.Frame({
        Size = UDim2.new(1, -40, 1, -120),
        Position = UDim2.fromOffset(20, 70),
        BackgroundTransparency = 1,
        parent = parent,
    }):render()

    local layout = UI.Layout.stack(container, Enum.FillDirection.Vertical, 12)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left

    local tabs = {
        {id = "Home", name = "Highlights", icon = "rbxassetid://8941080291", color = Color3.fromRGB(255, 120, 150)},
        {id = "Cash", name = "Credit Bundles", icon = "rbxassetid://7733772280", color = Color3.fromRGB(72, 190, 255)},
        {id = "Gamepasses", name = "Upgrades", icon = "rbxassetid://10709727148", color = Color3.fromRGB(146, 116, 255)},
    }

    for _, data in ipairs(tabs) do
        local button = UI.Components.Button({
            Text = "",
            Size = UDim2.new(1, 0, 0, 66),
            BackgroundColor3 = Core.Utils.blend(UI.Theme:get("rail"), Color3.new(0, 0, 0), 0.2),
            cornerRadius = UDim.new(0, 20),
            stroke = { color = UI.Theme:get("stroke"), thickness = 1, transparency = 0.5 },
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

        UI.Layout.stack(inner, Enum.FillDirection.Horizontal, 12, {left = 18, right = 18})

        local iconFrame = UI.Components.Frame({
            Size = UDim2.new(0, 38, 0, 38),
            BackgroundColor3 = Core.Utils.blend(data.color, Color3.new(0, 0, 0), 0.5),
            cornerRadius = UDim.new(1, 0),
            parent = inner,
        }):render()

        UI.Components.Image({
            Image = data.icon,
            Size = UDim2.fromOffset(24, 24),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            parent = iconFrame,
        }):render()

        local label = UI.Components.TextLabel({
            Text = data.name,
            Size = UDim2.new(1, -90, 0, 24),
            Position = UDim2.fromOffset(0, 6),
            Font = Enum.Font.GothamBold,
            TextSize = 18,
            TextXAlignment = Enum.TextXAlignment.Left,
            parent = inner,
        }):render()

        UI.Components.TextLabel({
            Text = "Tap to explore",
            Size = UDim2.new(1, -90, 0, 22),
            Position = UDim2.fromOffset(0, 36),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = UI.Theme:get("textSecondary"),
            TextXAlignment = Enum.TextXAlignment.Left,
            parent = inner,
        }):render()

        self.tabs[data.id] = {
            button = button,
            color = data.color,
            iconFrame = iconFrame,
            label = label,
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
        Text = "Trending Bundles",
        Size = UDim2.new(1, -40, 0, 40),
        Font = Enum.Font.GothamBold,
        TextSize = 26,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,
        parent = scroll,
    }):render()

    local featured = UI.Components.Frame({
        Size = UDim2.new(1, 0, 0, 340),
        BackgroundTransparency = 1,
        LayoutOrder = 3,
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
        Size = UDim2.new(1, -20, 0, 220),
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        cornerRadius = UDim.new(0, 24),
        LayoutOrder = 1,
        parent = parent,
    }):render()

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 150, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 140, 210)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(137, 96, 255)),
    })
    gradient.Rotation = -22
    gradient.Parent = hero

    UI.Layout.stack(hero, Enum.FillDirection.Horizontal, 24, {left = 36, right = 36, top = 36, bottom = 36})

    local text = UI.Components.Frame({
        Size = UDim2.new(0.6, 0, 1, 0),
        BackgroundTransparency = 1,
        parent = hero,
    }):render()

    UI.Components.TextLabel({
        Text = "Refit your tycoon with neon calm.",
        Size = UDim2.new(1, 0, 0, 48),
        Font = Enum.Font.GothamBlack,
        TextSize = 32,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = text,
    }):render()

    UI.Components.TextLabel({
        Text = "Holographic cards, smarter bundles, everything within two taps.",
        Size = UDim2.new(1, 0, 0, 54),
        Position = UDim2.fromOffset(0, 56),
        Font = Enum.Font.Gotham,
        TextSize = 18,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = text,
    }):render()

    UI.Components.Button({
        Text = "Jump to Bundles",
        Size = UDim2.fromOffset(200, 50),
        Position = UDim2.fromOffset(0, 120),
        BackgroundColor3 = UI.Theme:get("accentAlt"),
        TextColor3 = Color3.new(0, 0, 0),
        cornerRadius = UDim.new(1, 0),
        parent = text,
        onClick = function()
            self:selectTab("Cash")
        end,
    }):render()

    UI.Components.Image({
        Image = "rbxassetid://10720927454",
        Size = UDim2.new(0.32, 0, 1.1, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        parent = hero,
    }):render()

    return hero
end

function Shop:createProductCard(product, productType, parent, wide)
    local isGamepass = productType == "gamepass"
    local accent = isGamepass and Color3.fromRGB(146, 116, 255) or Color3.fromRGB(72, 190, 255)

    local width = wide and ((Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.X + 40) or (Core.CONSTANTS.CARD_SIZE.X + 60))
        or (Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.X or Core.CONSTANTS.CARD_SIZE.X)
    local height = wide and ((Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.Y + 30) or (Core.CONSTANTS.CARD_SIZE.Y + 20))
        or (Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.Y or Core.CONSTANTS.CARD_SIZE.Y)

    local card = UI.Components.Frame({
        Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        cornerRadius = UDim.new(0, 22),
        stroke = { color = Core.Utils.blend(accent, Color3.new(0, 0, 0), 0.5), thickness = 1, transparency = 0.35 },
        parent = parent,
    }):render()

    self:addCardHoverEffect(card)

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 20)
    padding.PaddingBottom = UDim.new(0, 20)
    padding.PaddingLeft = UDim.new(0, 22)
    padding.PaddingRight = UDim.new(0, 22)
    padding.Parent = card

    local top = UI.Components.Frame({
        Size = UDim2.new(1, 0, 0, 150),
        BackgroundColor3 = Core.Utils.blend(accent, Color3.new(0, 0, 0), 0.7),
        cornerRadius = UDim.new(0, 18),
        parent = card,
    }):render()

    UI.Components.Image({
        Image = product.icon or "rbxassetid://0",
        Size = UDim2.fromScale(0.6, 0.6),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        parent = top,
    }):render()

    local info = UI.Components.Frame({
        Size = UDim2.new(1, 0, 1, -170),
        Position = UDim2.fromOffset(0, 170),
        BackgroundTransparency = 1,
        parent = card,
    }):render()

    UI.Components.TextLabel({
        Text = product.name,
        Size = UDim2.new(1, 0, 0, 30),
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = info,
    }):render()

    UI.Components.TextLabel({
        Text = product.description,
        Size = UDim2.new(1, 0, 0, 46),
        Position = UDim2.fromOffset(0, 36),
        Font = Enum.Font.Gotham,
        TextSize = 15,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = info,
    }):render()

    local price = isGamepass and ("R$" .. tostring(product.price or 0)) or
        ("R$" .. tostring(product.price or 0) .. " • " .. Core.Utils.formatNumber(product.amount) .. " cash")

    UI.Components.TextLabel({
        Text = price,
        Size = UDim2.new(1, 0, 0, 24),
        Position = UDim2.fromOffset(0, 84),
        Font = Enum.Font.GothamSemibold,
        TextSize = 18,
        TextColor3 = accent,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = info,
    }):render()

    local owned = isGamepass and Core.DataManager.checkOwnership(product.id)

    local button = UI.Components.Button({
        Text = owned and "Equipped" or "Purchase",
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.new(0, 0, 1, -44),
        BackgroundColor3 = owned and UI.Theme:get("success") or accent,
        TextColor3 = owned and Color3.new(0, 0, 0) or Color3.new(0, 0, 0),
        cornerRadius = UDim.new(0, 14),
        parent = info,
        onClick = function()
            if not owned then
                self:promptPurchase(product, productType)
            elseif product.hasToggle then
                self:toggleGamepass(product)
            end
        end,
    }):render()

    if owned then
        local badge = UI.Components.TextLabel({
            Text = "OWNED",
            Size = UDim2.new(0, 80, 0, 26),
            Position = UDim2.fromOffset(10, -12),
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextColor3 = UI.Theme:get("success"),
            BackgroundColor3 = Core.Utils.blend(UI.Theme:get("success"), Color3.new(0, 0, 0), 0.7),
            parent = top,
        }):render()
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
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
            Position = UDim2.new(original.X.Scale, original.X.Offset, original.Y.Scale, original.Y.Offset - 10)
        }, Core.CONSTANTS.ANIM_FAST)
    end)
    card.MouseLeave:Connect(function()
        Core.Animation.tween(card, { Position = original }, Core.CONSTANTS.ANIM_FAST)
    end)
end

function Shop:addToggleSwitch(product, parent)
    local container = UI.Components.Frame({
        Size = UDim2.fromOffset(72, 32),
        Position = UDim2.new(1, -76, 0, 86),
        BackgroundColor3 = Core.Utils.blend(UI.Theme:get("surfaceAlt"), Color3.new(0, 0, 0), 0.5),
        cornerRadius = UDim.new(1, 0),
        stroke = { color = UI.Theme:get("stroke"), thickness = 1, transparency = 0.35 },
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
            container.BackgroundColor3 = UI.Theme:get("success")
            Core.Animation.tween(knob, { Position = UDim2.fromOffset(42, 2) }, Core.CONSTANTS.ANIM_FAST)
        else
            container.BackgroundColor3 = Core.Utils.blend(UI.Theme:get("surfaceAlt"), Color3.new(0, 0, 0), 0.5)
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
            BackgroundColor3 = active and Core.Utils.blend(color, UI.Theme:get("rail"), 0.7) or Core.Utils.blend(UI.Theme:get("rail"), Color3.new(0, 0, 0), 0.2)
        }, Core.CONSTANTS.ANIM_FAST)

        local stroke = tab.button:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = active and color or UI.Theme:get("stroke")
        end

        tab.label.TextColor3 = active and color or UI.Theme:get("text")
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
            product.purchaseButton.Text = owned and "Equipped" or "Purchase"
            product.purchaseButton.BackgroundColor3 = owned and UI.Theme:get("success") or Color3.fromRGB(146, 116, 255)
            product.purchaseButton.Active = not owned
        end

        if product.cardInstance then
            local stroke = product.cardInstance:FindFirstChildOfClass("UIStroke")
            if stroke then
                stroke.Color = owned and UI.Theme:get("success") or Color3.fromRGB(146, 116, 255)
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

print("[SanrioShop] Neon edition initialized.")

return shop
