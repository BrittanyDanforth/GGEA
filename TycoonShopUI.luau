-- Tycoon Shop UI - Modern Cute Edition
-- LocalScript for StarterPlayer > StarterPlayerScripts
-- Production quality, mobile-first, responsive design

-- Services
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 10)

-- Core Configuration
local Core = {
    VERSION = "6.0.0",
    DEBUG = false,
    CONSTANTS = {
        ANIM_FAST = 0.15,
        ANIM_MED = 0.25,
        ANIM_SLOW = 0.35,
        PURCHASE_TIMEOUT = 15,
        REFRESH_INTERVAL = 30,
        MARGIN_SAFE = 0.06, -- 6% margin for mobile controls
    },
    State = {
        isOpen = false,
        isAnimating = false,
        currentTab = "Cash",
        purchasePending = {},
        initialized = false,
        viewportSize = Vector2.new(1024, 768), -- Default, updated dynamically
    },
}

-- Event Bus
Core.Events = { _handlers = {} }
function Core.Events:on(name, cb)
    self._handlers[name] = self._handlers[name] or {}
    table.insert(self._handlers[name], cb)
    return function()
        local t = self._handlers[name]
        if t then
            local i = table.find(t, cb)
            if i then table.remove(t, i) end
        end
    end
end
function Core.Events:emit(name, ...)
    local t = self._handlers[name]
    if t then
        for _, cb in ipairs(t) do task.spawn(cb, ...) end
    end
end

-- Cache System
local Cache = {}
Cache.__index = Cache
function Cache.new(ttl)
    return setmetatable({ ttl = ttl or 300, data = {} }, Cache)
end
function Cache:set(k, v)
    self.data[k] = { value = v, time = os.clock() }
end
function Cache:get(k)
    local entry = self.data[k]
    if not entry then return nil end
    if os.clock() - entry.time > self.ttl then
        self.data[k] = nil
        return nil
    end
    return entry.value
end
function Cache:clear(k)
    if k then self.data[k] = nil else self.data = {} end
end

local productCache = Cache.new(300)
local ownershipCache = Cache.new(60)

-- Utilities
local Utils = {}
function Utils.isSmallViewport()
    return Core.State.viewportSize.X < 1024
end
function Utils.clamp(a, lo, hi)
    return math.max(lo, math.min(hi, a))
end
function Utils.fmtNum(n)
    local s = tostring(n)
    local k
    repeat s, k = s:gsub("^(%-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return s
end
function Utils.applyPadding(inst, padding)
    if not padding then return end
    local p = Instance.new("UIPadding")
    if padding.top then p.PaddingTop = padding.top end
    if padding.bottom then p.PaddingBottom = padding.bottom end
    if padding.left then p.PaddingLeft = padding.left end
    if padding.right then p.PaddingRight = padding.right end
    p.Parent = inst
end
function Utils.getSafeInsets()
    local inset = GuiService:GetGuiInset()
    return {
        top = UDim.new(0, math.max(inset.Y, 44)), -- Account for top bar
        bottom = UDim.new(0, math.max(inset.Y, 44)),
        left = UDim.new(0, inset.X),
        right = UDim.new(0, inset.X),
    }
end
function Utils.getDynamicColumns(viewportWidth)
    if viewportWidth < 600 then return 1
    elseif viewportWidth < 950 then return 2
    else return 3 end
end

-- Modern Cute Theme
local Theme = {
    palette = {
        bg = Color3.fromRGB(250, 248, 245), -- Soft cream background
        surface = Color3.fromRGB(255, 255, 255), -- Pure white surfaces
        surfaceAlt = Color3.fromRGB(248, 245, 250), -- Light lavender tint
        stroke = Color3.fromRGB(230, 220, 235), -- Soft purple stroke
        text = Color3.fromRGB(50, 45, 60), -- Dark purple text
        text2 = Color3.fromRGB(120, 110, 140), -- Muted text
        mint = Color3.fromRGB(180, 230, 210), -- Soft mint accent
        lav = Color3.fromRGB(210, 200, 255), -- Lavender accent
        ok = Color3.fromRGB(130, 200, 150), -- Success green
        warn = Color3.fromRGB(250, 210, 130), -- Warning yellow
        danger = Color3.fromRGB(255, 130, 150), -- Error red
    },
    radius = {
        small = UDim.new(0, 8),
        medium = UDim.new(0, 12),
        large = UDim.new(0, 20),
    },
    shadows = {
        soft = Color3.fromRGB(0, 0, 0),
        alpha = 0.1,
    },
}

-- UI Component Factory
local UI = {}

local Component = {}
Component.__index = Component
function Component.new(className, props)
    local self = setmetatable({}, Component)
    self.instance = Instance.new(className)
    self.props = props or {}
    self.connections = {}
    return self
end

function Component:render()
    local inst = self.instance
    for k, v in pairs(self.props) do
        if k ~= "children" and k ~= "parent" and k ~= "onClick" and k ~= "corner" and k ~= "stroke" and k ~= "padding" and k ~= "gradient" and k ~= "shadow" then
            pcall(function() inst[k] = v end)
        end
    end

    -- Apply visual enhancements
    if self.props.corner then
        local c = Instance.new("UICorner")
        c.CornerRadius = self.props.corner
        c.Parent = inst
    end
    if self.props.stroke then
        local s = Instance.new("UIStroke")
        s.Color = self.props.stroke.color or Theme.palette.stroke
        s.Thickness = self.props.stroke.thickness or 1
        s.Transparency = self.props.stroke.transparency or 0.3
        s.Parent = inst
    end
    if self.props.padding then
        Utils.applyPadding(inst, self.props.padding)
    end
    if self.props.gradient then
        local g = Instance.new("UIGradient")
        for prop, value in pairs(self.props.gradient) do
            pcall(function() g[prop] = value end)
        end
        g.Parent = inst
    end
    if self.props.shadow then
        local shadow = Instance.new("Frame")
        shadow.BackgroundColor3 = Theme.shadows.soft
        shadow.BackgroundTransparency = 1 - Theme.shadows.alpha
        shadow.Size = UDim2.new(1, 2, 1, 2)
        shadow.Position = UDim2.fromOffset(1, 1)
        shadow.Parent = inst
        local c = Instance.new("UICorner")
        c.CornerRadius = self.props.corner or Theme.radius.medium
        c.Parent = shadow
    end

    if self.props.onClick and inst:IsA("TextButton") then
        table.insert(self.connections, inst.MouseButton1Click:Connect(self.props.onClick))
    end
    if self.props.children then
        for _, child in ipairs(self.props.children) do
            if type(child) == "table" and child.render then
                child:render()
                child.instance.Parent = inst
            elseif type(child) == "Instance" then
                child.Parent = inst
            end
        end
    end
    if self.props.parent then
        inst.Parent = self.props.parent
    end
    return inst
end

function Component:destroy()
    for _, conn in ipairs(self.connections) do conn:Disconnect() end
    self.instance:Destroy()
end

function UI.Frame(props)
    props = props or {}
    if not props.BackgroundColor3 then props.BackgroundColor3 = Theme.palette.surface end
    if not props.BorderSizePixel then props.BorderSizePixel = 0 end
    return Component.new("Frame", props)
end

function UI.Text(props)
    props = props or {}
    if not props.BackgroundTransparency then props.BackgroundTransparency = 1 end
    if not props.TextColor3 then props.TextColor3 = Theme.palette.text end
    if not props.Font then props.Font = Enum.Font.Gotham end
    if not props.TextWrapped then props.TextWrapped = true end
    return Component.new("TextLabel", props)
end

function UI.Button(props)
    props = props or {}
    if not props.BackgroundColor3 then props.BackgroundColor3 = Theme.palette.mint end
    if not props.TextColor3 then props.TextColor3 = Color3.new(1, 1, 1) end
    if not props.Font then props.Font = Enum.Font.GothamSemibold end
    if not props.AutoButtonColor then props.AutoButtonColor = false end
    if not props.Size then props.Size = UDim2.fromOffset(140, 44) end
    return Component.new("TextButton", props)
end

function UI.Image(props)
    props = props or {}
    if not props.BackgroundTransparency then props.BackgroundTransparency = 1 end
    if not props.ScaleType then props.ScaleType = Enum.ScaleType.Fit end
    return Component.new("ImageLabel", props)
end

function UI.Scroll(props)
    props = props or {}
    if not props.BackgroundTransparency then props.BackgroundTransparency = 1 end
    if not props.BorderSizePixel then props.BorderSizePixel = 0 end
    if not props.ScrollBarThickness then props.ScrollBarThickness = 6 end
    if not props.ScrollBarImageColor3 then props.ScrollBarImageColor3 = Theme.palette.stroke end
    if not props.Size then props.Size = UDim2.fromScale(1, 1) end
    return Component.new("ScrollingFrame", props)
end

-- Tween Helper
local function tween(object, properties, duration, style, direction)
    if not Core.State.animationsEnabled then
        for k, v in pairs(properties) do object[k] = v end
        return
    end
    local ti = TweenInfo.new(duration or Core.CONSTANTS.ANIM_MED, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
    local tw = TweenService:Create(object, ti, properties)
    tw:Play()
    return tw
end

-- Data Manager
local Data = {}

-- Asset IDs (replace with your own)
local ICON_CASH = "rbxassetid://18420350532"
local ICON_PASS = "rbxassetid://18420350433"
local ICON_SHOP = "rbxassetid://17398522865"

-- Product and Game Pass IDs (replace with your actual IDs)
local PASS_AUTO_COLLECT = 1412171840
local PASS_2X_CASH = 1398974710

Data.products = {
    cash = {
        { id = 1897730242, amount = 1000, name = "Starter Pouch", description = "Kickstart your upgrades.", icon = ICON_CASH },
        { id = 1897730373, amount = 5000, name = "Festival Bundle", description = "Dress up your floors.", icon = ICON_CASH },
        { id = 1897730467, amount = 10000, name = "Showcase Chest", description = "Unlock new wings.", icon = ICON_CASH },
        { id = 1897730581, amount = 50000, name = "Grand Vault", description = "Full relaunch fund.", icon = ICON_CASH },
        { id = 1234567001, amount = 100000, name = "Mega Safe", description = "Major expansion.", icon = ICON_CASH },
        { id = 1234567002, amount = 250000, name = "Quarter Million", description = "Serious investment.", icon = ICON_CASH },
        { id = 1234567003, amount = 500000, name = "Half Million", description = "Fast-track builds.", icon = ICON_CASH },
        { id = 1234567004, amount = 1000000, name = "Millionaire Pack", description = "Dominate upgrades.", icon = ICON_CASH },
        { id = 1234567005, amount = 5000000, name = "Tycoon Titan", description = "Finish it all.", icon = ICON_CASH },
        { id = 1234567006, amount = 10000000, name = "Ultimate Vault", description = "Max everything.", icon = ICON_CASH },
    },
    gamepasses = {
        { id = PASS_AUTO_COLLECT, name = "Auto Collect", description = "Hands-free register sweep.", icon = ICON_PASS, hasToggle = true },
        { id = PASS_2X_CASH, name = "2x Cash", description = "Double every sale.", icon = ICON_PASS, hasToggle = false },
    }
}

function Data.getProductInfo(productId)
    local cached = productCache:get(productId)
    if cached then return cached end
    local ok, info = pcall(function()
        return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
    end)
    if ok and info then
        productCache:set(productId, info)
        return info
    end
    return nil
end

function Data.getPassInfo(passId)
    local key = "pass_" .. passId
    local cached = productCache:get(key)
    if cached then return cached end
    local ok, info = pcall(function()
        return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
    end)
    if ok and info then
        productCache:set(key, info)
        return info
    end
    return nil
end

function Data.refreshPrices()
    for _, product in ipairs(Data.products.cash) do
        local info = Data.getProductInfo(product.id)
        if info then product.price = info.PriceInRobux or 0 end
    end
    for _, pass in ipairs(Data.products.gamepasses) do
        local info = Data.getPassInfo(pass.id)
        if info then pass.price = info.PriceInRobux or pass.price or 0 end
    end
end

function Data.userOwnsPass(passId)
    local key = Player.UserId .. ":" .. passId
    local cached = ownershipCache:get(key)
    if cached ~= nil then return cached end
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, passId)
    end)
    if ok then
        ownershipCache:set(key, owns)
        return owns
    end
    return false
end

-- Shop Class
local Shop = {}
Shop.__index = Shop

function Shop.new()
    local self = setmetatable({}, Shop)
    self.gui = nil
    self.blur = nil
    self.panel = nil
    self.header = nil
    self.nav = nil
    self.content = nil
    self.pages = {}
    self.tabButtons = {}
    self.autoToggle = nil
    self.gridConnections = {}
    self:build()
    self:connectViewportListener()
    Core.State.initialized = true
    Core.Events:emit("shopInitialized")
    return self
end

-- Build GUI Structure
function Shop:createGui()
    local gui = PlayerGui:FindFirstChild("TycoonShopUI") or Instance.new("ScreenGui")
    gui.Name = "TycoonShopUI"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 1000
    gui.IgnoreGuiInset = false -- Respect safe areas
    gui.Enabled = false
    gui.Parent = PlayerGui

    -- Dim backdrop
    local dim = UI.Image({
        Name = "Dim",
        Image = "rbxassetid://7743879747", -- Soft vignette
        ImageTransparency = 0.3,
        Size = UDim2.fromScale(1, 1),
        ImageColor3 = Color3.new(0, 0, 0),
        parent = gui,
    }):render()

    -- Main panel with safe insets
    local insets = Utils.getSafeInsets()
    self.panel = UI.Frame({
        Name = "Panel",
        Size = UDim2.new(0.9, 0, 0.85, 0),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.palette.surface,
        corner = Theme.radius.large,
        stroke = { color = Theme.palette.stroke, transparency = 0.5 },
        padding = insets,
        parent = gui,
    }):render()

    -- Aspect ratio for tall screens
    local ar = Instance.new("UIAspectRatioConstraint")
    ar.AspectRatio = 1.6
    ar.DominantAxis = Enum.DominantAxis.Height
    ar.Parent = self.panel

    -- Blur effect
    self.blur = Lighting:FindFirstChild("ShopBlur") or Instance.new("BlurEffect")
    self.blur.Name = "ShopBlur"
    self.blur.Size = 0
    self.blur.Parent = Lighting

    self.gui = gui
end

function Shop:createHeader()
    self.header = UI.Frame({
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 64),
        BackgroundColor3 = Theme.palette.surfaceAlt,
        corner = Theme.radius.large,
        parent = self.panel,
    }):render()

    local padding = { left = UDim.new(0, 16), right = UDim.new(0, 16) }
    Utils.applyPadding(self.header, padding)

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 12)
    layout.Parent = self.header

    -- Icon
    UI.Image({
        Image = ICON_SHOP,
        Size = UDim2.fromOffset(36, 36),
        LayoutOrder = 1,
        parent = self.header,
    }):render()

    -- Title
    UI.Text({
        Text = "Game Shop",
        Font = Enum.Font.GothamBold,
        TextSize = 24,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -120, 1, 0),
        LayoutOrder = 2,
        parent = self.header,
    }):render()

    -- Close button
    local closeBtn = UI.Button({
        Text = "✕",
        Size = UDim2.fromOffset(36, 36),
        BackgroundColor3 = Theme.palette.surface,
        TextColor3 = Theme.palette.text,
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        AutoButtonColor = false,
        corner = Theme.radius.small,
        LayoutOrder = 3,
        parent = self.header,
        onClick = function() self:close() end,
    }):render()

    -- Hover effects
    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, { BackgroundColor3 = Theme.palette.stroke }, Core.CONSTANTS.ANIM_FAST)
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, { BackgroundColor3 = Theme.palette.surface }, Core.CONSTANTS.ANIM_FAST)
    end)
end

function Shop:createNav()
    self.nav = UI.Frame({
        Name = "Nav",
        Size = UDim2.new(0, 200, 1, -80),
        Position = UDim2.fromOffset(16, 72),
        BackgroundColor3 = Theme.palette.surfaceAlt,
        corner = Theme.radius.medium,
        stroke = { color = Theme.palette.stroke, transparency = 0.6 },
        parent = self.panel,
    }):render()

    local padding = { top = UDim.new(0, 12), bottom = UDim.new(0, 12), left = UDim.new(0, 12), right = UDim.new(0, 12) }
    Utils.applyPadding(self.nav, padding)

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 10)
    layout.Parent = self.nav

    local tabs = {
        { id = "Cash", name = "Cash Packs", accent = Theme.palette.mint },
        { id = "Gamepasses", name = "Game Passes", accent = Theme.palette.lav },
    }

    for _, tab in ipairs(tabs) do
        local btn = UI.Button({
            Text = tab.name,
            Size = UDim2.new(1, 0, 0, 46),
            BackgroundColor3 = Theme.palette.surface,
            TextColor3 = Theme.palette.text,
            Font = Enum.Font.GothamSemibold,
            TextSize = 18,
            AutoButtonColor = false,
            corner = Theme.radius.small,
            parent = self.nav,
            onClick = function() self:selectTab(tab.id) end,
        }):render()

        btn.MouseEnter:Connect(function()
            tween(btn, { BackgroundColor3 = tab.accent, TextColor3 = Color3.new(1, 1, 1) }, Core.CONSTANTS.ANIM_FAST)
        end)
        btn.MouseLeave:Connect(function()
            local active = Core.State.currentTab == tab.id
            tween(btn, { BackgroundColor3 = active and tab.accent or Theme.palette.surface, TextColor3 = active and Color3.new(1, 1, 1) or Theme.palette.text }, Core.CONSTANTS.ANIM_FAST)
        end)

        self.tabButtons[tab.id] = { button = btn, accent = tab.accent }
    end
end

function Shop:createContent()
    self.content = UI.Frame({
        Name = "Content",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -232, 1, -96),
        Position = UDim2.fromOffset(216, 80),
        parent = self.panel,
    }):render()

    self.pages.Cash = self:createCashPage(self.content)
    self.pages.Gamepasses = self:createPassPage(self.content)

    self:selectTab(Core.State.currentTab)
end

function Shop:createCashPage(parent)
    local page = UI.Frame({
        Name = "CashPage",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        parent = parent,
    }):render()

    -- Header
    local head = UI.Frame({
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Theme.palette.surfaceAlt,
        corner = Theme.radius.small,
        parent = page,
    }):render()
    Utils.applyPadding(head, { left = UDim.new(0, 12), right = UDim.new(0, 12) })
    UI.Text({
        Text = "Cash Packs",
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        Size = UDim2.new(0.5, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = head,
    }):render()

    -- Scrollable grid
    local scroll = UI.Scroll({
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Size = UDim2.new(1, 0, 1, -56),
        Position = UDim2.fromOffset(0, 52),
        parent = page,
    }):render()

    local grid = Instance.new("UIGridLayout")
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.CellPadding = UDim2.fromOffset(16, 16)
    grid.FillDirection = Enum.FillDirection.Horizontal
    grid.FillDirectionMaxCells = Utils.getDynamicColumns(Core.State.viewportSize.X)
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
    grid.Parent = scroll

    -- Connect grid to viewport changes
    table.insert(self.gridConnections, grid:GetPropertyChangedSignal("FillDirectionMaxCells"):Connect(function()
        -- Update on resize
    end))

    for i, product in ipairs(Data.products.cash) do
        self:createCashCard(product, scroll, i)
    end

    return page
end

function Shop:createCashCard(product, parent, order)
    local card = UI.Frame({
        Name = product.name .. "Card",
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Theme.palette.surface,
        corner = Theme.radius.medium,
        stroke = { color = Theme.palette.mint, transparency = 0.4 },
        parent = parent,
    }):render()
    card.LayoutOrder = order

    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 1.55
    aspect.DominantAxis = Enum.DominantAxis.Width
    aspect.Parent = card

    local inner = Instance.new("Frame")
    inner.BackgroundTransparency = 1
    inner.Size = UDim2.new(1, -24, 1, -24)
    inner.Position = UDim2.fromOffset(12, 12)
    inner.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 8)
    layout.Parent = inner

    -- Icon and name row
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 40)
    row.Parent = inner

    local hLayout = Instance.new("UIListLayout")
    hLayout.FillDirection = Enum.FillDirection.Horizontal
    hLayout.Padding = UDim.new(0, 8)
    hLayout.Parent = row

    UI.Image({
        Image = product.icon or ICON_CASH,
        Size = UDim2.fromOffset(36, 36),
        parent = row,
    }):render()
    UI.Text({
        Text = product.name,
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -44, 1, 0),
        parent = row,
    }):render()

    -- Description
    UI.Text({
        Text = product.description or "",
        TextColor3 = Theme.palette.text2,
        TextSize = 16,
        Size = UDim2.new(1, 0, 0, 36),
        parent = inner,
    }):render()

    -- Price
    local priceText = string.format("R$%s • %s Cash", tostring(product.price or 0), Utils.fmtNum(product.amount))
    local priceLabel = UI.Text({
        Text = priceText,
        Font = Enum.Font.GothamSemibold,
        TextSize = 18,
        TextColor3 = Theme.palette.mint,
        Size = UDim2.new(1, 0, 0, 24),
        parent = inner,
    }):render()

    -- Purchase button
    local buyBtn = UI.Button({
        Text = "Purchase",
        BackgroundColor3 = Theme.palette.mint,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        Size = UDim2.new(1, 0, 0, 40),
        corner = Theme.radius.small,
        parent = inner,
        onClick = function() self:promptPurchase(product, "product") end,
    }):render()

    -- Hover effects
    card.MouseEnter:Connect(function()
        if Utils.isSmallViewport() then return end
        tween(card, { BackgroundColor3 = Theme.palette.surfaceAlt }, Core.CONSTANTS.ANIM_FAST)
    end)
    card.MouseLeave:Connect(function()
        tween(card, { BackgroundColor3 = Theme.palette.surface }, Core.CONSTANTS.ANIM_FAST)
    end)

    product._card = card
    product._priceLabel = priceLabel
    product._buyButton = buyBtn
end

function Shop:createPassPage(parent)
    local page = UI.Frame({
        Name = "PassPage",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        parent = parent,
    }):render()

    -- Header
    local head = UI.Frame({
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Theme.palette.surfaceAlt,
        corner = Theme.radius.small,
        parent = page,
    }):render()
    Utils.applyPadding(head, { left = UDim.new(0, 12), right = UDim.new(0, 12) })
    UI.Text({
        Text = "Game Passes",
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        Size = UDim2.new(0.5, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = head,
    }):render()

    -- Scrollable grid
    local scroll = UI.Scroll({
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Size = UDim2.new(1, 0, 1, -108),
        Position = UDim2.fromOffset(0, 52),
        parent = page,
    }):render()

    local grid = Instance.new("UIGridLayout")
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.CellPadding = UDim2.fromOffset(16, 16)
    grid.FillDirection = Enum.FillDirection.Horizontal
    grid.FillDirectionMaxCells = Utils.getDynamicColumns(Core.State.viewportSize.X)
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
    grid.Parent = scroll

    for i, pass in ipairs(Data.products.gamepasses) do
        self:createPassCard(pass, scroll, i)
    end

    -- Settings area
    local settings = UI.Frame({
        Name = "Settings",
        Size = UDim2.new(1, 0, 0, 72),
        BackgroundColor3 = Theme.palette.surfaceAlt,
        corner = Theme.radius.small,
        Position = UDim2.new(0, 0, 1, -80),
        parent = page,
    }):render()
    Utils.applyPadding(settings, { left = UDim.new(0, 12), right = UDim.new(0, 12) })

    UI.Text({
        Text = "Quick Settings",
        Font = Enum.Font.GothamSemibold,
        TextSize = 18,
        Size = UDim2.new(0.5, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        parent = settings,
    }):render()

    self.autoToggle = self:createToggle(settings, "Auto Collect", false, function(state)
        if Remotes then
            local event = Remotes:FindFirstChild("AutoCollectToggle")
            if event and event:IsA("RemoteEvent") then
                event:FireServer(state)
            end
        end
    end)
    self.autoToggle.Position = UDim2.new(1, -120, 0.5, 0)
    self.autoToggle.AnchorPoint = Vector2.new(1, 0.5)

    return page
end

function Shop:createPassCard(pass, parent, order)
    local card = UI.Frame({
        Name = pass.name .. "Card",
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Theme.palette.surface,
        corner = Theme.radius.medium,
        stroke = { color = Theme.palette.lav, transparency = 0.45 },
        parent = parent,
    }):render()
    card.LayoutOrder = order

    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 1.55
    aspect.DominantAxis = Enum.DominantAxis.Width
    aspect.Parent = card

    local inner = Instance.new("Frame")
    inner.BackgroundTransparency = 1
    inner.Size = UDim2.new(1, -24, 1, -24)
    inner.Position = UDim2.fromOffset(12, 12)
    inner.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 8)
    layout.Parent = inner

    -- Icon and name
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 40)
    row.Parent = inner

    local hLayout = Instance.new("UIListLayout")
    hLayout.FillDirection = Enum.FillDirection.Horizontal
    hLayout.Padding = UDim.new(0, 8)
    hLayout.Parent = row

    UI.Image({
        Image = pass.icon or ICON_PASS,
        Size = UDim2.fromOffset(36, 36),
        parent = row,
    }):render()
    UI.Text({
        Text = pass.name,
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -44, 1, 0),
        parent = row,
    }):render()

    -- Description
    UI.Text({
        Text = pass.description or "",
        TextColor3 = Theme.palette.text2,
        TextSize = 16,
        Size = UDim2.new(1, 0, 0, 36),
        parent = inner,
    }):render()

    -- Price
    local priceText = string.format("R$%s", tostring(pass.price or 0))
    local priceLabel = UI.Text({
        Text = priceText,
        Font = Enum.Font.GothamSemibold,
        TextSize = 18,
        TextColor3 = Theme.palette.lav,
        Size = UDim2.new(1, 0, 0, 24),
        parent = inner,
    }):render()

    -- Purchase button
    local buyBtn = UI.Button({
        Text = "Purchase",
        BackgroundColor3 = Theme.palette.lav,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        Size = UDim2.new(1, 0, 0, 40),
        corner = Theme.radius.small,
        parent = inner,
        onClick = function() self:promptPurchase(pass, "gamepass") end,
    }):render()

    -- Owned state
    local owned = Data.userOwnsPass(pass.id)
    self:updatePassVisual(pass, owned, buyBtn, card)

    -- Inline toggle for Auto Collect
    if pass.id == PASS_AUTO_COLLECT and pass.hasToggle then
        local inlineToggle = self:createToggle(inner, "Enable", owned, function(state)
            if Remotes then
                local event = Remotes:FindFirstChild("AutoCollectToggle")
                if event and event:IsA("RemoteEvent") then
                    event:FireServer(state)
                end
            end
            if self.autoToggle then
                self:setToggle(self.autoToggle, state)
            end
        end)
        inlineToggle.Visible = owned
    end

    -- Hover effects
    card.MouseEnter:Connect(function()
        if Utils.isSmallViewport() then return end
        tween(card, { BackgroundColor3 = Theme.palette.surfaceAlt }, Core.CONSTANTS.ANIM_FAST)
    end)
    card.MouseLeave:Connect(function()
        tween(card, { BackgroundColor3 = Theme.palette.surface }, Core.CONSTANTS.ANIM_FAST)
    end)

    pass._card = card
    pass._priceLabel = priceLabel
    pass._buyButton = buyBtn
end

function Shop:createToggle(parent, label, initial, onChanged)
    local wrap = Instance.new("Frame")
    wrap.BackgroundTransparency = 1
    wrap.Size = UDim2.fromOffset(108, 32)
    wrap.Parent = parent

    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromOffset(52, 26)
    bg.Position = UDim2.fromOffset(56, 3)
    bg.BackgroundColor3 = initial and Theme.palette.mint or Theme.palette.stroke
    bg.Parent = wrap
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = bg

    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(22, 22)
    dot.Position = initial and UDim2.fromOffset(28, 2) or UDim2.fromOffset(2, 2)
    dot.BackgroundColor3 = Color3.new(1, 1, 1)
    dot.Parent = bg
    local cd = Instance.new("UICorner")
    cd.CornerRadius = UDim.new(1, 0)
    cd.Parent = dot

    local lbl = UI.Text({
        Text = label or "Toggle",
        TextColor3 = Theme.palette.text2,
        TextSize = 16,
        Size = UDim2.fromOffset(52, 32),
        parent = wrap,
    }):render()
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton")
    btn.BackgroundTransparency = 1
    btn.Size = UDim2.fromScale(1, 1)
    btn.Text = ""
    btn.Parent = wrap

    local state = initial
    local function apply()
        tween(bg, { BackgroundColor3 = state and Theme.palette.mint or Theme.palette.stroke }, Core.CONSTANTS.ANIM_FAST)
        tween(dot, { Position = state and UDim2.fromOffset(28, 2) or UDim2.fromOffset(2, 2) }, Core.CONSTANTS.ANIM_FAST)
    end
    btn.MouseButton1Click:Connect(function()
        state = not state
        apply()
        if onChanged then onChanged(state) end
    end)
    apply()
    wrap:SetAttribute("_toggle_state", state)
    return wrap
end

function Shop:setToggle(toggleWrap, value)
    if not toggleWrap then return end
    toggleWrap:SetAttribute("_toggle_state", value)
    local bg = toggleWrap:FindFirstChildOfClass("Frame")
    if not bg then return end
    local dot = bg:FindFirstChildOfClass("Frame")
    if not dot then return end
    bg.BackgroundColor3 = value and Theme.palette.mint or Theme.palette.stroke
    dot.Position = value and UDim2.fromOffset(28, 2) or UDim2.fromOffset(2, 2)
end

function Shop:updatePassVisual(pass, owned, btn, card)
    btn = btn or pass._buyButton
    card = card or pass._card
    if not btn or not card then return end
    btn.Text = owned and "Owned" or "Purchase"
    btn.Active = not owned
    btn.BackgroundColor3 = owned and Theme.palette.ok or Theme.palette.lav
    local stroke = card:FindFirstChildOfClass("UIStroke")
    if stroke then stroke.Color = owned and Theme.palette.ok or Theme.palette.lav end
end

function Shop:build()
    self:createGui()
    self:createHeader()
    self:createNav()
    self:createContent()
end

function Shop:connectViewportListener()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local conn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        Core.State.viewportSize = camera.ViewportSize
        self:updateResponsiveLayout()
    end)
    table.insert(self.gridConnections, conn)
    Core.State.viewportSize = camera.ViewportSize
end

function Shop:updateResponsiveLayout()
    -- Update grid columns
    for _, page in pairs(self.pages) do
        local scroll = page:FindFirstChildOfClass("ScrollingFrame")
        if scroll then
            local grid = scroll:FindFirstChildOfClass("UIGridLayout")
            if grid then
                grid.FillDirectionMaxCells = Utils.getDynamicColumns(Core.State.viewportSize.X)
            end
        end
    end
    -- Update safe insets
    local insets = Utils.getSafeInsets()
    if self.panel then
        Utils.applyPadding(self.panel, insets)
    end
end

function Shop:open()
    if Core.State.isOpen or Core.State.isAnimating then return end
    Core.State.isAnimating = true
    Core.State.isOpen = true

    Data.refreshPrices()
    self:refreshVisuals()

    self.gui.Enabled = true
    tween(self.blur, { Size = 28 }, Core.CONSTANTS.ANIM_MED)
    self.panel.Position = UDim2.fromScale(0.5, 0.52)
    tween(self.panel, { Position = UDim2.fromScale(0.5, 0.5) }, Core.CONSTANTS.ANIM_SLOW, Enum.EasingStyle.Back)
    task.delay(Core.CONSTANTS.ANIM_SLOW, function()
        Core.State.isAnimating = false
        Core.Events:emit("shopOpened")
    end)
end

function Shop:close()
    if not Core.State.isOpen or Core.State.isAnimating then return end
    Core.State.isAnimating = true
    Core.State.isOpen = false

    tween(self.blur, { Size = 0 }, Core.CONSTANTS.ANIM_FAST)
    tween(self.panel, { Position = UDim2.fromScale(0.5, 0.52) }, Core.CONSTANTS.ANIM_FAST)
    task.delay(Core.CONSTANTS.ANIM_FAST, function()
        self.gui.Enabled = false
        Core.State.isAnimating = false
        Core.Events:emit("shopClosed")
    end)
end

function Shop:toggle()
    if Core.State.isOpen then self:close() else self:open() end
end

function Shop:selectTab(id)
    if Core.State.currentTab == id then
        for k, pg in pairs(self.pages) do pg.Visible = (k == id) end
        return
    end
    for k, data in pairs(self.tabButtons) do
        local active = (k == id)
        tween(data.button, {
            BackgroundColor3 = active and data.accent or Theme.palette.surface,
            TextColor3 = active and Color3.new(1, 1, 1) or Theme.palette.text,
        }, Core.CONSTANTS.ANIM_FAST)
    end
    for k, pg in pairs(self.pages) do pg.Visible = (k == id) end
    Core.State.currentTab = id
    Core.Events:emit("tabChanged", id)
end

function Shop:refreshVisuals()
    ownershipCache:clear()
    for _, pass in ipairs(Data.products.gamepasses) do
        local owned = Data.userOwnsPass(pass.id)
        self:updatePassVisual(pass, owned)
    end
    for _, product in ipairs(Data.products.cash) do
        if product._priceLabel then
            product._priceLabel.Text = string.format("R$%s • %s Cash", tostring(product.price or 0), Utils.fmtNum(product.amount))
        end
    end
    -- Update toggle visibility
    local ownsAuto = Data.userOwnsPass(PASS_AUTO_COLLECT)
    if self.autoToggle then self.autoToggle.Visible = ownsAuto end
end

function Shop:promptPurchase(item, kind)
    if kind == "gamepass" then
        if Data.userOwnsPass(item.id) then
            self:updatePassVisual(item, true)
            return
        end
        item._buyButton.Text = "Processing..."
        item._buyButton.Active = false
        Core.State.purchasePending[item.id] = { item = item, type = kind, time = os.clock() }
        local ok = pcall(function()
            MarketplaceService:PromptGamePassPurchase(Player, item.id)
        end)
        if not ok then
            item._buyButton.Text = "Purchase"
            item._buyButton.Active = true
            Core.State.purchasePending[item.id] = nil
        end
        task.delay(Core.CONSTANTS.PURCHASE_TIMEOUT, function()
            if Core.State.purchasePending[item.id] then
                item._buyButton.Text = "Purchase"
                item._buyButton.Active = true
                Core.State.purchasePending[item.id] = nil
            end
        end)
    else
        Core.State.purchasePending[item.id] = { item = item, type = kind, time = os.clock() }
        local ok = pcall(function()
            MarketplaceService:PromptProductPurchase(Player, item.id)
        end)
        if not ok then
            Core.State.purchasePending[item.id] = nil
        end
    end
end

-- Input Handling
function Shop:connectInputs()
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.M then
            self:toggle()
        elseif input.KeyCode == Enum.KeyCode.Escape and Core.State.isOpen then
            self:close()
        end
    end)

    -- Floating toggle button
    local toggleGui = PlayerGui:FindFirstChild("ShopToggle") or Instance.new("ScreenGui")
    toggleGui.Name = "ShopToggle"
    toggleGui.ResetOnSpawn = false
    toggleGui.DisplayOrder = 999
    toggleGui.Parent = PlayerGui

    local pill = UI.Button({
        Text = "Shop",
        BackgroundColor3 = Theme.palette.surface,
        TextColor3 = Theme.palette.text,
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        Size = UDim2.fromOffset(156, 56),
        Position = UDim2.new(1, -20, 1, -20),
        AnchorPoint = Vector2.new(1, 1),
        corner = Theme.radius.small,
        parent = toggleGui,
        onClick = function() self:toggle() end,
    }):render()

    pill.MouseEnter:Connect(function()
        tween(pill, { BackgroundColor3 = Theme.palette.mint, TextColor3 = Color3.new(1, 1, 1) }, Core.CONSTANTS.ANIM_FAST)
    end)
    pill.MouseLeave:Connect(function()
        tween(pill, { BackgroundColor3 = Theme.palette.surface, TextColor3 = Theme.palette.text }, Core.CONSTANTS.ANIM_FAST)
    end)
end

-- Marketplace Callbacks
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
    if player ~= Player then return end
    local pending = Core.State.purchasePending[passId]
    if not pending then return end
    Core.State.purchasePending[passId] = nil
    local item = pending.item
    if purchased then
        ownershipCache:clear()
        if item and item._buyButton then
            item._buyButton.Text = "Owned"
            item._buyButton.BackgroundColor3 = Theme.palette.ok
            item._buyButton.Active = false
        end
        if shop then shop:refreshVisuals() end
        if Remotes then
            local event = Remotes:FindFirstChild("GamepassPurchased")
            if event and event:IsA("RemoteEvent") then
                event:FireServer(passId)
            end
        end
    else
        if item and item._buyButton then
            item._buyButton.Text = "Purchase"
            item._buyButton.Active = true
        end
    end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, purchased)
    if player ~= Player then return end
    local pending = Core.State.purchasePending[productId]
    if not pending then return end
    Core.State.purchasePending[productId] = nil
    if purchased and Remotes then
        local event = Remotes:FindFirstChild("GrantProductCurrency")
        if event and event:IsA("RemoteEvent") then
            event:FireServer(productId)
        end
    end
end

-- Initialization
local shop = Shop.new()
shop:connectInputs()

Player.CharacterAdded:Connect(function()
    task.wait(1)
    local toggleGui = PlayerGui:FindFirstChild("ShopToggle")
    if not toggleGui then shop:connectInputs() end
end)

-- Periodic refresh
task.spawn(function()
    while true do
        task.wait(Core.CONSTANTS.REFRESH_INTERVAL)
        if Core.State.isOpen then
            Data.refreshPrices()
            if shop then shop:refreshVisuals() end
        end
    end
end)

print("[TycoonShop] Modern Cute UI ready (v" .. Core.VERSION .. ")")

-- Exposed API
function Core.OpenShop() if shop then shop:open() end end
function Core.CloseShop() if shop then shop:close() end end
function Core.ToggleShop() if shop then shop:toggle() end end

return shop