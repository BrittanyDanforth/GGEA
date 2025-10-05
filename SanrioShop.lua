--[[
    SANRIO SHOP SYSTEM – STORYBOOK SHOWCASE EDITION
    Place this LocalScript in StarterPlayer > StarterPlayerScripts
    Name it: SanrioShop

    Goals for this refinement
    • Blend the strongest ideas from earlier versions into a layered boutique layout
    • Introduce a navigation rail, hero spotlight, curated tips, and richer product cards
    • Use a storybook pastel palette with gentle motion and accessible typography
    • Preserve purchase, caching, remote, and toggle behaviour from previous builds
--]]

-- Services -------------------------------------------------------------------
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

-- Core -----------------------------------------------------------------------
local Core = {}
Core.VERSION = "4.0.0"
Core.DEBUG = false

Core.CONSTANTS = {
    PANEL_SIZE = Vector2.new(1240, 820),
    PANEL_SIZE_MOBILE = Vector2.new(980, 720),
    CARD_SIZE = Vector2.new(440, 280),
    CARD_SIZE_MOBILE = Vector2.new(400, 260),

    ANIM_FAST = 0.12,
    ANIM_MEDIUM = 0.22,
    ANIM_SLOW = 0.35,

    CACHE_PRODUCT_INFO = 300,
    CACHE_OWNERSHIP = 60,

    PURCHASE_TIMEOUT = 15,
    RETRY_DELAY = 2,
    MAX_RETRIES = 3,
}

Core.State = {
    isOpen = false,
    isAnimating = false,
    currentTab = "Spotlight",
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
    for _, cb in ipairs(listeners) do
        task.spawn(cb, ...)
    end
end

-- Cache ----------------------------------------------------------------------
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

-- Utilities ------------------------------------------------------------------
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

function Core.Utils.list(parent, direction, spacing, padding)
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = direction or Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, spacing or 12)
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

-- Animation ------------------------------------------------------------------
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

-- Sound ----------------------------------------------------------------------
Core.SoundSystem = {}

function Core.SoundSystem.initialize()
    local sounds = {
        click = {id = "rbxassetid://876939830", volume = 0.45},
        hover = {id = "rbxassetid://10066936758", volume = 0.24},
        open = {id = "rbxassetid://1841381002", volume = 0.52},
        close = {id = "rbxassetid://1841380989", volume = 0.52},
        success = {id = "rbxassetid://1843528128", volume = 0.58},
        error = {id = "rbxassetid://63384199", volume = 0.48},
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
    if sound then
        sound:Play()
    end
end

-- Data -----------------------------------------------------------------------
Core.DataManager = {}

Core.DataManager.products = {
    cash = {
        {
            id = 1897730242,
            amount = 1000,
            name = "Starter Pouch",
            description = "A gentle boost to prep your first display table.",
            icon = "rbxassetid://10709728059",
            featured = true,
            price = 0,
        },
        {
            id = 1897730373,
            amount = 5000,
            name = "Festival Bundle",
            description = "Refresh decor across the boutique before guests arrive.",
            icon = "rbxassetid://10709728059",
            featured = false,
            price = 0,
        },
        {
            id = 1897730467,
            amount = 10000,
            name = "Showcase Chest",
            description = "Unlock themed rooms and signature counters quickly.",
            icon = "rbxassetid://10709728059",
            featured = true,
            price = 0,
        },
        {
            id = 1897730581,
            amount = 50000,
            name = "Grand Opening Vault",
            description = "Fund an entire relaunch with mascots and parades!",
            icon = "rbxassetid://10709728059",
            featured = true,
            price = 0,
        },
    },
    gamepasses = {
        {
            id = 1412171840,
            name = "Auto Collect",
            description = "Assistants tidy each register while you design.",
            icon = "rbxassetid://10709727148",
            price = 99,
            features = {
                "Hands-free pickup",
                "Runs while AFK",
                "Keep floors spotless",
            },
            hasToggle = true,
        },
        {
            id = 1398974710,
            name = "2x Cash",
            description = "Double every sale for the grandest boutique growth.",
            icon = "rbxassetid://10709727148",
            price = 199,
            features = {
                "Permanent boost",
                "Stacks with events",
                "Fastest upgrades",
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
    if cached ~= nil then
        return cached
    end

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
-- Theme ----------------------------------------------------------------------
local UI = {}

UI.Theme = {
    current = "storybook",
    palettes = {
        storybook = {
            background = Color3.fromRGB(250, 246, 242),
            surface = Color3.fromRGB(255, 255, 255),
            surfaceAlt = Color3.fromRGB(244, 236, 236),
            surfaceMuted = Color3.fromRGB(248, 242, 250),
            stroke = Color3.fromRGB(224, 212, 220),
            text = Color3.fromRGB(46, 38, 58),
            textSecondary = Color3.fromRGB(116, 108, 132),
            accent = Color3.fromRGB(255, 145, 185),
            accentAlt = Color3.fromRGB(255, 192, 210),
            accentMint = Color3.fromRGB(178, 224, 214),
            accentLav = Color3.fromRGB(206, 196, 255),
            accentSky = Color3.fromRGB(186, 214, 255),
            success = Color3.fromRGB(125, 194, 144),
            warning = Color3.fromRGB(245, 201, 120),
            danger = Color3.fromRGB(255, 120, 140),
        }
    }
}

function UI.Theme:get(key)
    local palette = self.palettes[self.current] or {}
    return palette[key] or Color3.new(1, 1, 1)
end

-- Component Factory ----------------------------------------------------------
UI.Components = {}

local Component = {}
Component.__index = Component

function Component.new(className, props)
    local self = setmetatable({}, Component)
    self.instance = Instance.new(className)
    self.props = props or {}
    self.connections = {}
    return self
end

local function applyVisualProps(instance, props)
    if props.cornerRadius then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = props.cornerRadius
        corner.Parent = instance
    end

    if props.stroke then
        local stroke = Instance.new("UIStroke")
        stroke.Color = props.stroke.color or UI.Theme:get("stroke")
        stroke.Thickness = props.stroke.thickness or 1
        stroke.Transparency = props.stroke.transparency or 0
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = instance
    end

    if props.padding then
        local padding = Instance.new("UIPadding")
        if props.padding.top then padding.PaddingTop = props.padding.top end
        if props.padding.bottom then padding.PaddingBottom = props.padding.bottom end
        if props.padding.left then padding.PaddingLeft = props.padding.left end
        if props.padding.right then padding.PaddingRight = props.padding.right end
        padding.Parent = instance
    end

    if props.gradient then
        local gradient = Instance.new("UIGradient")
        for key, value in pairs(props.gradient) do
            pcall(function()
                gradient[key] = value
            end)
        end
        gradient.Parent = instance
    end
end

function Component:render()
    for key, value in pairs(self.props) do
        if key ~= "children" and key ~= "parent" and key ~= "onClick" and key ~= "cornerRadius"
            and key ~= "stroke" and key ~= "padding" and key ~= "gradient" and key ~= "hover" then
            pcall(function()
                self.instance[key] = value
            end)
        end
    end

    applyVisualProps(self.instance, self.props)

    if self.props.onClick and self.instance:IsA("TextButton") then
        local connection = self.instance.MouseButton1Click:Connect(self.props.onClick)
        table.insert(self.connections, connection)
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
        Font = Enum.Font.Gotham,
        TextColor3 = UI.Theme:get("text"),
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
        Size = UDim2.fromOffset(140, 44),
        AutoButtonColor = false,
    }
    props = props or {}
    for key, value in pairs(defaults) do
        if props[key] == nil then props[key] = value end
    end

    local component = Component.new("TextButton", props)

    component.instance.MouseButton1Click:Connect(function()
        Core.SoundSystem.play("click")
    end)

    if props.hover then
        local baseColor = props.BackgroundColor3
        component.instance.MouseEnter:Connect(function()
            Core.SoundSystem.play("hover")
            Core.Animation.tween(component.instance, props.hover, Core.CONSTANTS.ANIM_FAST)
        end)
        component.instance.MouseLeave:Connect(function()
            Core.Animation.tween(component.instance, {
                BackgroundColor3 = baseColor,
                Size = props.Size or component.instance.Size,
            }, Core.CONSTANTS.ANIM_FAST)
        end)
    end

    return component
end

function UI.Components.Image(props)
    local defaults = {
        BackgroundTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        Size = UDim2.fromOffset(100, 100),
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
        CanvasSize = UDim2.new(),
    }
    props = props or {}
    for key, value in pairs(defaults) do
        if props[key] == nil then props[key] = value end
    end

    local component = Component.new("ScrollingFrame", props)

    if props.layout then
        local layoutType = props.layout.type or "List"
        local layout = Instance.new("UI" .. layoutType .. "Layout")
        for key, value in pairs(props.layout) do
            if key ~= "type" then
                pcall(function()
                    layout[key] = value
                end)
            end
        end
        layout.Parent = component.instance

        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            component.instance.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 24)
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

UI.Responsive = {}

function UI.Responsive.attachScale(instance)
    local camera = workspace.CurrentCamera
    if not camera then return end

    local scale = Instance.new("UIScale")
    scale.Parent = instance

    local function update()
        local viewport = camera.ViewportSize
        local factor = math.min(viewport.X / 1920, viewport.Y / 1080)
        factor = Core.Utils.clamp(factor, 0.6, 1.2)
        if Core.Utils.isMobile() then
            factor = factor * 0.92
        end
        scale.Scale = factor
    end

    update()
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
    return scale
end
-- Shop -----------------------------------------------------------------------
local Shop = {}
Shop.__index = Shop

local shop -- forward declaration for event closures

function Shop.new()
    local self = setmetatable({}, Shop)

    self.gui = nil
    self.mainPanel = nil
    self.blur = nil
    self.toggleButton = nil
    self.navigationRail = nil
    self.contentArea = nil
    self.heroPanel = nil
    self.tabButtons = {}
    self.pages = {}

    self:initialize()
    return self
end

function Shop:initialize()
    Core.SoundSystem.initialize()
    Core.DataManager.refreshPrices()

    self:createToggleButton()
    self:createInterface()
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
        Text = "",
        Size = UDim2.fromOffset(188, 64),
        Position = UDim2.new(1, -24, 1, -24),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = UI.Theme:get("surface"),
        TextColor3 = UI.Theme:get("text"),
        Font = Enum.Font.GothamBold,
        TextSize = 22,
        cornerRadius = UDim.new(1, 0),
        stroke = {
            color = UI.Theme:get("accent"),
            thickness = 2,
            transparency = 0.15,
        },
        parent = toggleGui,
        onClick = function()
            self:toggle()
        end,
    }):render()

    local pill = UI.Components.Frame({
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        parent = self.toggleButton,
    }):render()

    Core.Utils.list(pill, Enum.FillDirection.Horizontal, 12, {left = 20, right = 20})

    UI.Components.Image({
        Image = "rbxassetid://17398522865",
        Size = UDim2.fromOffset(32, 32),
        LayoutOrder = 1,
        parent = pill,
    }):render()

    UI.Components.TextLabel({
        Text = "Boutique",
        Size = UDim2.new(1, -40, 1, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,
        parent = pill,
    }):render()

    self:addBreathingAnimation(self.toggleButton)
end

function Shop:createInterface()
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
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.55,
        Size = UDim2.fromScale(1, 1),
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
            transparency = 0.4,
        },
        parent = self.gui,
    }):render()

    UI.Responsive.attachScale(self.mainPanel)

    self:createNavigationRail()
    self:createContentArea()
    self:selectTab(Core.State.currentTab)
end
function Shop:createNavigationRail()
    self.navigationRail = UI.Components.Frame({
        Name = "NavigationRail",
        Size = UDim2.new(0, 220, 1, -40),
        Position = UDim2.fromOffset(24, 20),
        BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        cornerRadius = UDim.new(0, 22),
        stroke = {
            color = UI.Theme:get("stroke"),
            transparency = 0.45,
        },
        padding = {
            top = UDim.new(0, 28),
            bottom = UDim.new(0, 28),
            left = UDim.new(0, 24),
            right = UDim.new(0, 24),
        },
        parent = self.mainPanel,
    }):render()

    Core.Utils.list(self.navigationRail, Enum.FillDirection.Vertical, 18)

    local crest = UI.Components.Frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 72),
        LayoutOrder = 1,
        parent = self.navigationRail,
    }):render()

    UI.Components.Image({
        Image = "rbxassetid://17398522865",
        Size = UDim2.fromOffset(56, 56),
        parent = crest,
    }):render()

    UI.Components.TextLabel({
        Text = "Sanrio Boutique",
        Size = UDim2.new(1, 0, 0, 28),
        Position = UDim2.fromOffset(0, 52),
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = crest,
    }):render()

    local tabs = {
        {id = "Spotlight", name = "Spotlight", accent = UI.Theme:get("accent")},
        {id = "Cash", name = "Cash Bundles", accent = UI.Theme:get("accentMint")},
        {id = "Gamepasses", name = "Passes", accent = UI.Theme:get("accentLav")},
        {id = "Perks", name = "Boutique Tips", accent = UI.Theme:get("accentSky")},
    }

    for index, tab in ipairs(tabs) do
        local button = UI.Components.Button({
            Text = tab.name,
            Size = UDim2.new(1, 0, 0, 48),
            BackgroundColor3 = UI.Theme:get("surface"),
            TextColor3 = UI.Theme:get("text"),
            Font = Enum.Font.GothamMedium,
            TextSize = 18,
            AutoButtonColor = false,
            cornerRadius = UDim.new(0, 16),
            LayoutOrder = index + 1,
            parent = self.navigationRail,
            onClick = function()
                self:selectTab(tab.id)
            end,
        }):render()

        self.tabButtons[tab.id] = {
            button = button,
            accent = tab.accent,
        }
    end

    local settingsCard = UI.Components.Frame({
        Size = UDim2.new(1, 0, 0, 120),
        BackgroundColor3 = UI.Theme:get("surfaceMuted"),
        cornerRadius = UDim.new(0, 14),
        LayoutOrder = #tabs + 2,
        padding = {
            top = UDim.new(0, 14),
            bottom = UDim.new(0, 14),
            left = UDim.new(0, 18),
            right = UDim.new(0, 18),
        },
        parent = self.navigationRail,
    }):render()

    UI.Components.TextLabel({
        Text = "Quick Settings",
        Size = UDim2.new(1, 0, 0, 24),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = settingsCard,
    }):render()

    local soundToggle = self:createPillToggle(settingsCard, "Sound", Core.State.settings.soundEnabled, function(value)
        Core.State.settings.soundEnabled = value
    end)
    soundToggle.Position = UDim2.fromOffset(0, 44)

    local motionToggle = self:createPillToggle(settingsCard, "Motion", Core.State.settings.animationsEnabled, function(value)
        Core.State.settings.animationsEnabled = value
    end)
    motionToggle.Position = UDim2.fromOffset(0, 78)
end

function Shop:createPillToggle(parent, labelText, initialState, onToggle)
    local container = Instance.new("Frame")
    container.Name = labelText .. "Toggle"
    container.BackgroundTransparency = 1
    container.Size = UDim2.new(1, 0, 0, 28)
    container.Parent = parent

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.Font = Enum.Font.Gotham
    label.TextSize = 16
    label.TextColor3 = UI.Theme:get("textSecondary")
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.Parent = container

    local toggle = Instance.new("Frame")
    toggle.Size = UDim2.fromOffset(54, 26)
    toggle.Position = UDim2.new(1, -54, 0.5, 0)
    toggle.AnchorPoint = Vector2.new(0, 0.5)
    toggle.BackgroundColor3 = initialState and UI.Theme:get("accent") or UI.Theme:get("stroke")
    toggle.Parent = container

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggle

    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(22, 22)
    dot.Position = initialState and UDim2.fromOffset(30, 2) or UDim2.fromOffset(2, 2)
    dot.BackgroundColor3 = Color3.new(1, 1, 1)
    dot.Parent = toggle

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = dot

    local clickArea = Instance.new("TextButton")
    clickArea.BackgroundTransparency = 1
    clickArea.Size = UDim2.fromScale(1, 1)
    clickArea.Text = ""
    clickArea.Parent = toggle

    local state = initialState

    local function update()
        Core.Animation.tween(toggle, {
            BackgroundColor3 = state and UI.Theme:get("accent") or UI.Theme:get("stroke"),
        }, Core.CONSTANTS.ANIM_FAST)
        Core.Animation.tween(dot, {
            Position = state and UDim2.fromOffset(30, 2) or UDim2.fromOffset(2, 2),
        }, Core.CONSTANTS.ANIM_FAST)
    end

    clickArea.MouseButton1Click:Connect(function()
        state = not state
        update()
        Core.SoundSystem.play("click")
        if onToggle then
            onToggle(state)
        end
    end)

    update()
    return container
end
function Shop:createContentArea()
    self.contentArea = UI.Components.Frame({
        Name = "ContentArea",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -280, 1, -60),
        Position = UDim2.fromOffset(260, 30),
        parent = self.mainPanel,
    }):render()

    Core.Utils.list(self.contentArea, Enum.FillDirection.Vertical, 16)

    self.heroPanel = self:createHeroPanel(self.contentArea)
    self.pages.Spotlight = self:createSpotlightPage(self.contentArea)
    self.pages.Cash = self:createCashPage(self.contentArea)
    self.pages.Gamepasses = self:createGamepassPage(self.contentArea)
    self.pages.Perks = self:createPerksPage(self.contentArea)
end

function Shop:createHeroPanel(parent)
    local hero = UI.Components.Frame({
        Name = "HeroPanel",
        Size = UDim2.new(1, 0, 0, 210),
        BackgroundColor3 = UI.Theme:get("surfaceMuted"),
        cornerRadius = UDim.new(0, 22),
        padding = {
            top = UDim.new(0, 28),
            bottom = UDim.new(0, 28),
            left = UDim.new(0, 32),
            right = UDim.new(0, 32),
        },
        gradient = {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, UI.Theme:get("accentAlt")),
                ColorSequenceKeypoint.new(1, UI.Theme:get("accentSky")),
            }),
            Rotation = 40,
        },
        parent = parent,
    }):render()

    local overlay = Instance.new("Frame")
    overlay.BackgroundTransparency = 1
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.Parent = hero

    Core.Utils.list(overlay, Enum.FillDirection.Horizontal, 28)

    local textColumn = Instance.new("Frame")
    textColumn.BackgroundTransparency = 1
    textColumn.Size = UDim2.new(0.6, 0, 1, 0)
    textColumn.Parent = overlay

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Text = "Curate your Sanrio story"
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 32
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Parent = textColumn

    local subtitle = Instance.new("TextLabel")
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Layer pastel displays, welcome mascots, and let each guest leave smiling."
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 18
    subtitle.TextColor3 = Color3.new(1, 1, 1)
    subtitle.TextWrapped = true
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Position = UDim2.fromOffset(0, 48)
    subtitle.Size = UDim2.new(1, 0, 0, 64)
    subtitle.Parent = textColumn

    UI.Components.Button({
        Text = "Browse bundles",
        Size = UDim2.fromOffset(180, 48),
        Position = UDim2.fromOffset(0, 124),
        BackgroundColor3 = Color3.new(1, 1, 1),
        TextColor3 = UI.Theme:get("accent"),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        cornerRadius = UDim.new(0, 16),
        parent = textColumn,
        onClick = function()
            self:selectTab("Cash")
        end,
    }):render()

    local artColumn = Instance.new("Frame")
    artColumn.BackgroundTransparency = 1
    artColumn.Size = UDim2.new(0.4, 0, 1, 0)
    artColumn.Parent = overlay

    local heroImage = Instance.new("ImageLabel")
    heroImage.BackgroundTransparency = 1
    heroImage.Image = "rbxassetid://17398522865"
    heroImage.Size = UDim2.fromScale(0.9, 0.9)
    heroImage.Position = UDim2.fromScale(0.5, 0.5)
    heroImage.AnchorPoint = Vector2.new(0.5, 0.5)
    heroImage.Parent = artColumn

    return hero
end

function Shop:createSpotlightPage(parent)
    local page = UI.Components.Frame({
        Name = "SpotlightPage",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 320),
        Visible = false,
        parent = parent,
    }):render()

    Core.Utils.list(page, Enum.FillDirection.Vertical, 18)

    UI.Components.TextLabel({
        Text = "Featured collections",
        Size = UDim2.new(1, 0, 0, 32),
        Font = Enum.Font.GothamBold,
        TextSize = 26,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = page,
    }):render()

    local carousel = UI.Components.ScrollingFrame({
        Size = UDim2.new(1, 0, 0, 220),
        ScrollingDirection = Enum.ScrollingDirection.X,
        layout = {
            type = "List",
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 18),
        },
        padding = {
            top = UDim.new(0, 6),
            bottom = UDim.new(0, 6),
        },
        parent = page,
    }):render()

    for _, product in ipairs(Core.DataManager.products.cash) do
        if product.featured then
            self:createShowcaseCard(product, carousel)
        end
    end

    UI.Components.TextLabel({
        Text = "Pair a grand bundle with a helper pass for even more sparkle!",
        Size = UDim2.new(1, 0, 0, 40),
        Font = Enum.Font.Gotham,
        TextSize = 18,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = page,
    }):render()

    return page
end
function Shop:createShowcaseCard(product, parent)
    local card = UI.Components.Frame({
        Size = UDim2.new(0, 320, 1, -12),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(0, 18),
        stroke = {
            color = UI.Theme:get("accent"),
            transparency = 0.4,
        },
        padding = {
            top = UDim.new(0, 18),
            bottom = UDim.new(0, 18),
            left = UDim.new(0, 18),
            right = UDim.new(0, 18),
        },
        parent = parent,
    }):render()

    Core.Utils.list(card, Enum.FillDirection.Vertical, 10)

    UI.Components.TextLabel({
        Text = product.name,
        Size = UDim2.new(1, 0, 0, 26),
        Font = Enum.Font.GothamBold,
        TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = card,
    }):render()

    UI.Components.TextLabel({
        Text = product.description,
        Size = UDim2.new(1, 0, 0, 60),
        Font = Enum.Font.Gotham,
        TextSize = 16,
        TextColor3 = UI.Theme:get("textSecondary"),
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = card,
    }):render()

    UI.Components.TextLabel({
        Text = string.format("R$%s  •  %s Cash", tostring(product.price or 0), Core.Utils.formatNumber(product.amount)),
        Size = UDim2.new(1, 0, 0, 24),
        Font = Enum.Font.GothamSemibold,
        TextSize = 18,
        TextColor3 = UI.Theme:get("text"),
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = card,
    }):render()

    UI.Components.Button({
        Text = "Open bundle",
        Size = UDim2.new(0, 150, 0, 40),
        BackgroundColor3 = UI.Theme:get("accent"),
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 17,
        cornerRadius = UDim.new(0, 12),
        parent = card,
        onClick = function()
            self:selectTab("Cash")
        end,
    }):render()

    return card
end

function Shop:createCashPage(parent)
    local page = UI.Components.Frame({
        Name = "CashPage",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -210),
        Visible = false,
        parent = parent,
    }):render()

    local scroll = UI.Components.ScrollingFrame({
        Size = UDim2.fromScale(1, 1),
        layout = {
            type = "Grid",
            CellSize = Core.Utils.isMobile() and
                UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE_MOBILE.X, Core.CONSTANTS.CARD_SIZE_MOBILE.Y) or
                UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y),
            CellPadding = UDim2.fromOffset(22, 22),
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
        },
        padding = {
            top = UDim.new(0, 12),
            left = UDim.new(0, 6),
            right = UDim.new(0, 6),
            bottom = UDim.new(0, 20),
        },
        parent = page,
    }):render()

    for _, product in ipairs(Core.DataManager.products.cash) do
        self:createProductCard(product, "cash", scroll)
    end

    return page
end

function Shop:createGamepassPage(parent)
    local page = UI.Components.Frame({
        Name = "GamepassPage",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -210),
        Visible = false,
        parent = parent,
    }):render()

    local scroll = UI.Components.ScrollingFrame({
        Size = UDim2.fromScale(1, 1),
        layout = {
            type = "Grid",
            CellSize = Core.Utils.isMobile() and
                UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE_MOBILE.X, Core.CONSTANTS.CARD_SIZE_MOBILE.Y) or
                UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y),
            CellPadding = UDim2.fromOffset(22, 22),
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
        },
        padding = {
            top = UDim.new(0, 12),
            left = UDim.new(0, 6),
            right = UDim.new(0, 6),
            bottom = UDim.new(0, 20),
        },
        parent = page,
    }):render()

    for _, pass in ipairs(Core.DataManager.products.gamepasses) do
        self:createProductCard(pass, "gamepass", scroll)
    end

    return page
end

function Shop:createPerksPage(parent)
    local page = UI.Components.Frame({
        Name = "PerksPage",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 240),
        Visible = false,
        parent = parent,
    }):render()

    Core.Utils.list(page, Enum.FillDirection.Vertical, 16)

    UI.Components.TextLabel({
        Text = "Boutique tips",
        Size = UDim2.new(1, 0, 0, 32),
        Font = Enum.Font.GothamBold,
        TextSize = 24,
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = page,
    }):render()

    local tips = {
        "Rotate themed displays every 15 minutes to keep regulars delighted.",
        "Pair Auto Collect with large bundles so you can focus on styling.",
        "Use different game passes to craft helper, decor, and ambience sets.",
    }

    for _, tip in ipairs(tips) do
        UI.Components.Frame({
            Size = UDim2.new(1, 0, 0, 56),
            BackgroundColor3 = UI.Theme:get("surfaceAlt"),
            cornerRadius = UDim.new(0, 12),
            stroke = {
                color = UI.Theme:get("stroke"),
                transparency = 0.6,
            },
            padding = {
                left = UDim.new(0, 18),
                right = UDim.new(0, 18),
            },
            children = {
                UI.Components.TextLabel({
                    Text = tip,
                    Size = UDim2.new(1, 0, 1, 0),
                    Font = Enum.Font.Gotham,
                    TextSize = 18,
                    TextColor3 = UI.Theme:get("textSecondary"),
                    TextXAlignment = Enum.TextXAlignment.Left,
                })
            },
            parent = page,
        }):render()
    end

    return page
end
function Shop:createProductCard(product, productType, parent)
    local isGamepass = productType == "gamepass"
    local accent = isGamepass and UI.Theme:get("accentLav") or UI.Theme:get("accentMint")

    local card = UI.Components.Frame({
        Name = product.name .. "Card",
        Size = UDim2.fromOffset(
            Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.X or Core.CONSTANTS.CARD_SIZE.X,
            Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.Y or Core.CONSTANTS.CARD_SIZE.Y
        ),
        BackgroundColor3 = UI.Theme:get("surface"),
        cornerRadius = UDim.new(0, 18),
        stroke = {
            color = accent,
            transparency = 0.45,
        },
        parent = parent,
    }):render()

    self:addCardMotion(card)

    local container = Instance.new("Frame")
    container.BackgroundTransparency = 1
    container.Size = UDim2.new(1, -32, 1, -32)
    container.Position = UDim2.fromOffset(16, 16)
    container.Parent = card

    Core.Utils.list(container, Enum.FillDirection.Vertical, 8)

    local header = Instance.new("Frame")
    header.BackgroundTransparency = 1
    header.Size = UDim2.new(1, 0, 0, 48)
    header.Parent = container

    local icon = Instance.new("ImageLabel")
    icon.BackgroundTransparency = 1
    icon.Image = product.icon or "rbxassetid://0"
    icon.Size = UDim2.fromOffset(44, 44)
    icon.Position = UDim2.fromOffset(0, 2)
    icon.Parent = header

    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1
    name.Text = product.name
    name.Font = Enum.Font.GothamBold
    name.TextSize = 20
    name.TextColor3 = UI.Theme:get("text")
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.Position = UDim2.fromOffset(56, 0)
    name.Size = UDim2.new(1, -56, 0, 24)
    name.Parent = header

    local description = Instance.new("TextLabel")
    description.BackgroundTransparency = 1
    description.Text = product.description
    description.Font = Enum.Font.Gotham
    description.TextSize = 16
    description.TextColor3 = UI.Theme:get("textSecondary")
    description.TextWrapped = true
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.Size = UDim2.new(1, 0, 0, 48)
    description.Parent = container

    if isGamepass and product.features then
        local featureList = Instance.new("Frame")
        featureList.BackgroundTransparency = 1
        featureList.Size = UDim2.new(1, 0, 0, 60)
        featureList.Parent = container

        Core.Utils.list(featureList, Enum.FillDirection.Vertical, 6)
        for _, feature in ipairs(product.features) do
            local row = Instance.new("TextLabel")
            row.BackgroundTransparency = 1
            row.Text = "• " .. feature
            row.Font = Enum.Font.Gotham
            row.TextSize = 15
            row.TextColor3 = UI.Theme:get("textSecondary")
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.Size = UDim2.new(1, 0, 0, 18)
            row.Parent = featureList
        end
    end

    local priceText
    if isGamepass then
        priceText = string.format("R$%s", tostring(product.price or 0))
    else
        priceText = string.format("R$%s  •  %s Cash", tostring(product.price or 0), Core.Utils.formatNumber(product.amount))
    end

    local priceLabel = Instance.new("TextLabel")
    priceLabel.BackgroundTransparency = 1
    priceLabel.Text = priceText
    priceLabel.Font = Enum.Font.GothamSemibold
    priceLabel.TextSize = 18
    priceLabel.TextColor3 = accent
    priceLabel.TextXAlignment = Enum.TextXAlignment.Left
    priceLabel.Size = UDim2.new(1, 0, 0, 22)
    priceLabel.Parent = container

    local button = UI.Components.Button({
        Text = "Purchase",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = accent,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 17,
        cornerRadius = UDim.new(0, 12),
        parent = container,
        onClick = function()
            self:promptPurchase(product, productType)
        end,
    }):render()

    product.cardInstance = card
    product.purchaseButton = button

    if isGamepass then
        local owned = Core.DataManager.checkOwnership(product.id)
        self:updateOwnershipVisual(product, owned)
        if product.hasToggle and owned then
            self:addGamepassToggle(product, container)
        end
    end

    return card
end

function Shop:addCardMotion(card)
    local basePosition = card.Position
    card.MouseEnter:Connect(function()
        Core.Animation.tween(card, {
            Position = UDim2.new(basePosition.X.Scale, basePosition.X.Offset, basePosition.Y.Scale, basePosition.Y.Offset - 8),
            BackgroundColor3 = UI.Theme:get("surfaceAlt"),
        }, Core.CONSTANTS.ANIM_FAST, Enum.EasingStyle.Sine)
    end)
    card.MouseLeave:Connect(function()
        Core.Animation.tween(card, {
            Position = basePosition,
            BackgroundColor3 = UI.Theme:get("surface"),
        }, Core.CONSTANTS.ANIM_FAST, Enum.EasingStyle.Sine)
    end)
end

function Shop:addGamepassToggle(product, parent)
    local toggleWrapper = Instance.new("Frame")
    toggleWrapper.Name = "EnableToggle"
    toggleWrapper.BackgroundTransparency = 1
    toggleWrapper.Size = UDim2.new(1, 0, 0, 32)
    toggleWrapper.Parent = parent

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Text = "Enable in store"
    label.Font = Enum.Font.Gotham
    label.TextSize = 16
    label.TextColor3 = UI.Theme:get("textSecondary")
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Parent = toggleWrapper

    local toggle = Instance.new("Frame")
    toggle.Size = UDim2.fromOffset(54, 26)
    toggle.Position = UDim2.new(1, -54, 0.5, 0)
    toggle.AnchorPoint = Vector2.new(0, 0.5)
    toggle.BackgroundColor3 = UI.Theme:get("accentLav")
    toggle.Parent = toggleWrapper

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggle

    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(22, 22)
    dot.Position = UDim2.fromOffset(30, 2)
    dot.BackgroundColor3 = Color3.new(1, 1, 1)
    dot.Parent = toggle

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = dot

    local clickArea = Instance.new("TextButton")
    clickArea.BackgroundTransparency = 1
    clickArea.Size = UDim2.fromScale(1, 1)
    clickArea.Text = ""
    clickArea.Parent = toggle

    local toggleState = false
    if Remotes then
        local getState = Remotes:FindFirstChild("GetAutoCollectState")
        if getState and getState:IsA("RemoteFunction") then
            local success, state = pcall(function()
                return getState:InvokeServer()
            end)
            if success and typeof(state) == "boolean" then
                toggleState = state
            end
        end
    end

    local function update()
        Core.Animation.tween(toggle, {
            BackgroundColor3 = toggleState and UI.Theme:get("accent") or UI.Theme:get("stroke"),
        }, Core.CONSTANTS.ANIM_FAST)
        Core.Animation.tween(dot, {
            Position = toggleState and UDim2.fromOffset(30, 2) or UDim2.fromOffset(2, 2),
        }, Core.CONSTANTS.ANIM_FAST)
    end

    clickArea.MouseButton1Click:Connect(function()
        toggleState = not toggleState
        update()
        Core.SoundSystem.play("click")
        if Remotes then
            local toggleRemote = Remotes:FindFirstChild("AutoCollectToggle")
            if toggleRemote and toggleRemote:IsA("RemoteEvent") then
                toggleRemote:FireServer(toggleState)
            end
        end
    end)

    update()
end

function Shop:updateOwnershipVisual(product, owned)
    if product.purchaseButton then
        product.purchaseButton.Text = owned and "Owned" or "Purchase"
        product.purchaseButton.BackgroundColor3 = owned and UI.Theme:get("success") or UI.Theme:get("accentLav")
        product.purchaseButton.Active = not owned
    end

    if product.cardInstance then
        local stroke = product.cardInstance:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = owned and UI.Theme:get("success") or UI.Theme:get("accentLav")
        end
    end
end

function Shop:addBreathingAnimation(instance)
    local running = true
    task.spawn(function()
        while running and instance.Parent do
            Core.Animation.tween(instance, {
                Size = UDim2.fromOffset(196, 68),
            }, 1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(1.4)
            if not running or not instance.Parent then break end
            Core.Animation.tween(instance, {
                Size = UDim2.fromOffset(188, 64),
            }, 1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(1.4)
        end
    end)

    instance.AncestryChanged:Connect(function()
        if not instance.Parent then
            running = false
        end
    end)
end

function Shop:selectTab(tabId)
    if Core.State.currentTab == tabId then
        for id, page in pairs(self.pages) do
            page.Visible = (id == tabId)
        end
        return
    end

    for id, info in pairs(self.tabButtons) do
        local active = id == tabId
        Core.Animation.tween(info.button, {
            BackgroundColor3 = active and info.accent or UI.Theme:get("surface"),
            TextColor3 = active and Color3.new(1, 1, 1) or UI.Theme:get("text"),
        }, Core.CONSTANTS.ANIM_FAST)
    end

    for id, page in pairs(self.pages) do
        local show = id == tabId
        page.Visible = show
        if show then
            page.Position = UDim2.fromOffset(0, 18)
            Core.Animation.tween(page, {
                Position = UDim2.new(),
            }, Core.CONSTANTS.ANIM_SLOW, Enum.EasingStyle.Back)
        end
    end

    Core.State.currentTab = tabId
    Core.SoundSystem.play("click")
    Core.Events:emit("tabChanged", tabId)
end
function Shop:promptPurchase(product, productType)
    if productType == "gamepass" then
        if Core.DataManager.checkOwnership(product.id) then
            self:updateOwnershipVisual(product, true)
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
            Core.SoundSystem.play("error")
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
            Core.SoundSystem.play("error")
        end
    end
end

function Shop:refreshProduct(product, productType)
    if productType == "gamepass" then
        local owned = Core.DataManager.checkOwnership(product.id)
        self:updateOwnershipVisual(product, owned)
        if product.hasToggle and owned then
            local hasToggle = false
            for _, child in ipairs(product.purchaseButton.Parent:GetChildren()) do
                if child.Name == "EnableToggle" then
                    hasToggle = true
                    break
                end
            end
            if not hasToggle then
                self:addGamepassToggle(product, product.purchaseButton.Parent)
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

    Core.Animation.tween(self.blur, {
        Size = 28,
    }, Core.CONSTANTS.ANIM_MEDIUM)

    self.mainPanel.Position = UDim2.fromScale(0.5, 0.52)
    Core.Animation.tween(self.mainPanel, {
        Position = UDim2.fromScale(0.5, 0.5),
    }, Core.CONSTANTS.ANIM_SLOW, Enum.EasingStyle.Back)

    Core.SoundSystem.play("open")

    task.wait(Core.CONSTANTS.ANIM_SLOW)
    Core.State.isAnimating = false
    Core.Events:emit("shopOpened")
end

function Shop:close()
    if not Core.State.isOpen or Core.State.isAnimating then return end

    Core.State.isAnimating = true
    Core.State.isOpen = false

    Core.Animation.tween(self.blur, {
        Size = 0,
    }, Core.CONSTANTS.ANIM_FAST)

    Core.Animation.tween(self.mainPanel, {
        Position = UDim2.fromScale(0.5, 0.52),
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
            for _, pass in ipairs(Core.DataManager.products.gamepasses) do
                if pass.id == passId then
                    self:updateOwnershipVisual(pass, true)
                    if pass.hasToggle then
                        self:addGamepassToggle(pass, pass.purchaseButton.Parent)
                    end
                    break
                end
            end
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
            pending.product.purchaseButton.Text = "Owned"
            pending.product.purchaseButton.BackgroundColor3 = UI.Theme:get("success")
            pending.product.purchaseButton.Active = false
        end
        Core.SoundSystem.play("success")
        task.wait(0.5)
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

-- Initialise -----------------------------------------------------------------
shop = Shop.new()

Player.CharacterAdded:Connect(function()
    task.wait(1)
    if not shop.toggleButton or not shop.toggleButton.Parent then
        shop:createToggleButton()
    end
end)

-- Periodic refresh -----------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(30)
        if Core.State.isOpen then
            shop:refreshAllProducts()
        end
    end
end)

print("[SanrioShop] Storybook showcase ready!")

return shop
