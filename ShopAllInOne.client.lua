--!strict
--[[
  MODERN CUTE TYCOON SHOP — All-in-One (Luau)
  Drop in: StarterPlayer > StarterPlayerScripts > ShopAllInOne.client.lua

  Controls
  - M or Controller X: Toggle Shop
  - ESC: Close

  Remotes (ReplicatedStorage > TycoonRemotes)
  - RemoteEvent     : GrantProductCurrency(productId:number)
  - RemoteEvent     : GamepassPurchased(passId:number)
  - RemoteEvent     : AutoCollectToggle(enabled:boolean)
  - RemoteFunction? : GetAutoCollectState() -> boolean
]]

--// Services
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--// =========
--// Types
--// =========
type CashProduct = {
	id: number,
	amount: number,
	name: string,
	description: string?,
	icon: string?,
	price: number?, -- runtime filled
	_card: Frame?,
	_priceLabel: TextLabel?,
	_buyButton: TextButton?,
}

type GamePass = {
	id: number,
	name: string,
	description: string?,
	icon: string?,
	hasToggle: boolean?,
	price: number?, -- runtime filled
	_card: Frame?,
	_priceLabel: TextLabel?,
	_buyButton: TextButton?,
}

type ShopConfig = {
	Version: string,
	Debug: boolean,
	Animations: boolean,
	PurchaseTimeout: number,
	RefreshInterval: number,
	Icons: {
		Cash: string,
		Pass: string,
		Shop: string,
		Vignette: string,
	},
	PassIds: {
		AutoCollect: number,
		DoubleCash: number,
	},
	Products: {
		cash: { CashProduct },
		gamepasses: { GamePass },
	},
	RemotesFolderName: string,
}

type ToggleWidget = Frame & {
	GetState: (self: ToggleWidget) -> boolean,
	SetState: (self: ToggleWidget, v: boolean) -> (),
	Changed: RBXScriptSignal,
}

-- Minimal typed Signal (no per-frame allocs)
type TSignal = {
	Connect: (self: TSignal, fn: (...any) -> ()) -> RBXScriptConnection,
	Once: (self: TSignal, fn: (...any) -> ()) -> RBXScriptConnection,
	Fire: (self: TSignal, ...any) -> (),
	Destroy: (self: TSignal) -> (),
}

local Signal = {}
Signal.__index = Signal
function Signal.new(): TSignal
	local self = setmetatable({}, Signal)
	(self :: any)._be = Instance.new("BindableEvent")
	(self :: any)._conns = {}
	return (self :: any) :: TSignal
end
function Signal:Connect(fn: (...any) -> ()): RBXScriptConnection
	local be: BindableEvent = (self :: any)._be
	local c = be.Event:Connect(fn)
	table.insert((self :: any)._conns, c)
	return c
end
function Signal:Once(fn: (...any) -> ()): RBXScriptConnection
	local be: BindableEvent = (self :: any)._be
	local conn: RBXScriptConnection
	conn = be.Event:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	table.insert((self :: any)._conns, conn)
	return conn
end
function Signal:Fire(...: any)
	((self :: any)._be :: BindableEvent):Fire(...)
end
function Signal:Destroy()
	local conns = ((self :: any)._conns :: { RBXScriptConnection }?)
	if conns then
		for i = #conns, 1, -1 do
			conns[i]:Disconnect()
			conns[i] = nil :: any
		end
		(self :: any)._conns = {}
	end
	local be = ((self :: any)._be :: BindableEvent?)
	if be then
		be:Destroy()
	end
	(self :: any)._be = nil
end

--// =========================
--// Design Tokens + Theme
--// =========================
local Tokens = {
	colors = {
		bg          = Color3.fromRGB(250, 247, 245),
		surface     = Color3.fromRGB(255, 255, 255),
		surfaceAlt  = Color3.fromRGB(246, 242, 246),
		stroke      = Color3.fromRGB(224, 214, 220),
		text        = Color3.fromRGB(42, 38, 54),
		text2       = Color3.fromRGB(116, 108, 132),
		mint        = Color3.fromRGB(178, 224, 214),
		lav         = Color3.fromRGB(206, 196, 255),
		sky         = Color3.fromRGB(186, 214, 255),
		ok          = Color3.fromRGB(125, 194, 144),
		warn        = Color3.fromRGB(245, 201, 120),
		danger      = Color3.fromRGB(255, 120, 140),
	},
	radius = {
		xs   = UDim.new(0, 6),
		sm   = UDim.new(0, 10),
		md   = UDim.new(0, 14),
		lg   = UDim.new(0, 20),
		full = UDim.new(1, 0),
	},
	spacing = {
		xxs = 4, xs = 8, sm = 12, md = 16, lg = 20, xl = 24, xxl = 32,
	},
	typography = {
		title   = { font = Enum.Font.GothamBold,   size = 24 },
		section = { font = Enum.Font.GothamBold,   size = 20 },
		label   = { font = Enum.Font.GothamMedium, size = 18 },
		body    = { font = Enum.Font.Gotham,       size = 16 },
		small   = { font = Enum.Font.Gotham,       size = 14 },
	},
}

local function applyCorner(inst: Instance, radius: UDim?)
	local r = Instance.new("UICorner")
	r.CornerRadius = radius or Tokens.radius.md
	r.Parent = inst
	return r
end

local function applyStroke(inst: Instance, color: Color3?, thickness: number?, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Tokens.colors.stroke
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.25
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

local function applyPadding(inst: Instance, p: { top: number?, bottom: number?, left: number?, right: number? }?)
	if not p then return end
	local pad = Instance.new("UIPadding")
	if p.top then pad.PaddingTop = UDim.new(0, p.top) end
	if p.bottom then pad.PaddingBottom = UDim.new(0, p.bottom) end
	if p.left then pad.PaddingLeft = UDim.new(0, p.left) end
	if p.right then pad.PaddingRight = UDim.new(0, p.right) end
	pad.Parent = inst
end

--// ===============
--// UI primitives
--// ===============
local function FrameX(props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = props.BackgroundColor3 or Tokens.colors.surface
	f.BorderSizePixel = 0
	for k, v in pairs(props) do
		if k ~= "stroke" and k ~= "corner" and k ~= "padding" then
			(f :: any)[k] = v
		end
	end
	if props.corner then applyCorner(f, props.corner) end
	if props.stroke then applyStroke(f, props.stroke.Color, props.stroke.Thickness, props.stroke.Transparency) end
	if props.padding then applyPadding(f, props.padding) end
	return f
end

local function TextLabelX(props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = props.Font or Tokens.typography.body.font
	t.TextSize = props.TextSize or Tokens.typography.body.size
	t.TextColor3 = props.TextColor3 or Tokens.colors.text
	t.TextWrapped = props.TextWrapped == nil and true or props.TextWrapped
	for k, v in pairs(props) do
		if k ~= "stroke" and k ~= "corner" then
			(t :: any)[k] = v
		end
	end
	return t
end

local function TextButtonX(props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Font = props.Font or Tokens.typography.label.font
	b.TextSize = props.TextSize or Tokens.typography.label.size
	b.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	b.BackgroundColor3 = props.BackgroundColor3 or Tokens.colors.mint
	for k, v in pairs(props) do
		if k ~= "stroke" and k ~= "corner" then
			(b :: any)[k] = v
		end
	end
	if props.corner then applyCorner(b, props.corner) end
	if props.stroke then applyStroke(b, props.stroke.Color, props.stroke.Thickness, props.stroke.Transparency) end
	return b
end

local function ImageX(props: { [string]: any }): ImageLabel
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.ScaleType = Enum.ScaleType.Fit
	for k, v in pairs(props) do
		(i :: any)[k] = v
	end
	return i
end

--// ===============
--// Utils
--// ===============
local function tween(i: Instance, props: { [string]: any }, dur: number, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local ti = TweenInfo.new(dur, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
	local tw = TweenService:Create(i, ti, props)
	tw:Play()
	return tw
end

local function isConsole(): boolean
	return GuiService:IsTenFootInterface()
end

local function isSmallViewport(): boolean
	local cam = workspace.CurrentCamera
	if not cam then return false end
	local v = cam.ViewportSize
	return v.X < 1024 or isConsole()
end

local function fmtNum(n: number): string
	local s = tostring(n)
	local k: number
	repeat
		s, k = s:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return s
end

-- Simple TTL cache
type CacheEntry<T> = { v: T, t: number }

local function newCache<T>(ttl: number)
	local store: { [string]: CacheEntry<T> } = {}
	return {
		get = function(key: string): T?
			local e = store[key]
			if not e then return nil end
			if os.clock() - e.t > ttl then
				store[key] = nil
				return nil
			end
			return e.v
		end,
		set = function(key: string, val: T)
			store[key] = { v = val, t = os.clock() }
		end,
		clear = function(key: string?)
			if key then
				store[key] = nil
			else
				table.clear(store)
			end
		end,
	}
end

--// =========================
--// Shop Controller (class)
--// =========================
type Private = {
	_player: Player,
	_gui: ScreenGui?,
	_panel: Frame?,
	_header: Frame?,
	_nav: Frame?,
	_content: Frame?,
	_pages: { [string]: Frame },
	_tabButtons: { [string]: TextButton },
	_autoToggleSettings: ToggleWidget?,
	_blur: BlurEffect?,
	_remotes: Instance?,
	connected: { RBXScriptConnection },
	productCache: any,
	ownershipCache: any,
	state: {
		open: boolean,
		animating: boolean,
		tab: string,
		pending: { [number]: { t: number } },
	},
	Events: {
		Opened: TSignal,
		Closed: TSignal,
		TabChanged: TSignal,
	},
	cfg: ShopConfig,
}

local ShopController = {}
ShopController.__index = ShopController

-- Toggle widget
local function createToggle(parent: Instance, label: string, initial: boolean, onChangedFn: (boolean) -> ()): ToggleWidget
	local wrap = Instance.new("Frame") :: ToggleWidget
	wrap.Name = "Toggle"
	wrap.BackgroundTransparency = 1
	wrap.Size = UDim2.fromOffset(120, 32)
	wrap.Parent = parent

	local _label = TextLabelX({
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(72, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Tokens.typography.body.font,
		TextSize = Tokens.typography.body.size,
		TextColor3 = Tokens.colors.text2,
		Text = label,
		Parent = wrap,
	})

	local bg = FrameX({
		Size = UDim2.fromOffset(52, 26),
		Position = UDim2.fromOffset(72, 3),
		BackgroundColor3 = initial and Tokens.colors.mint or Tokens.colors.stroke,
		Parent = wrap,
	})
	applyCorner(bg, Tokens.radius.full)

	local dot = FrameX({
		Size = UDim2.fromOffset(22, 22),
		Position = initial and UDim2.fromOffset(28, 2) or UDim2.fromOffset(2, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = bg,
	})
	applyCorner(dot, Tokens.radius.full)

	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.Parent = wrap

	local state = initial
	local function apply()
		tween(bg,  { BackgroundColor3 = state and Tokens.colors.mint or Tokens.colors.stroke }, 0.1)
		tween(dot, { Position = state and UDim2.fromOffset(28, 2) or UDim2.fromOffset(2, 2) }, 0.1)
		wrap:SetAttribute("_state", state)
	end

	hit.MouseButton1Click:Connect(function()
		state = not state
		apply()
		onChangedFn(state)
	end)

	(wrap :: any).GetState = function(self: ToggleWidget)
		local v = self:GetAttribute("_state")
		return (typeof(v) == "boolean" and v) or false
	end
	(wrap :: any).SetState = function(self: ToggleWidget, v: boolean)
		state = v
		apply()
	end
	(wrap :: any).Changed = wrap.AttributeChanged
	apply()
	return wrap
end

-- Element helpers
local function sectionHeader(parent: Instance, title: string)
	local head = FrameX({
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Tokens.colors.surfaceAlt,
		corner = Tokens.radius.sm,
		Parent = parent,
	})
	applyPadding(head, { left = Tokens.spacing.md, right = Tokens.spacing.md })
	TextLabelX({
		Text = title,
		Font = Tokens.typography.section.font,
		TextSize = Tokens.typography.section.size,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.5, 0, 1, 0),
		Parent = head,
	})
	return head
end

function ShopController.new(cfg: ShopConfig)
	local self: Private = (setmetatable({}, ShopController) :: any)
	self._player = Player
	self._gui = nil
	self._panel = nil
	self._header = nil
	self._nav = nil
	self._content = nil
	self._pages = {}
	self._tabButtons = {}
	self._autoToggleSettings = nil
	self._blur = nil
	self._remotes = ReplicatedStorage:FindFirstChild(cfg.RemotesFolderName)
	self.connected = {}
	self.productCache = newCache(300)
	self.ownershipCache = newCache(60)
	self.state = {
		open = false,
		animating = false,
		tab = "Cash",
		pending = {},
	}
	self.Events = {
		Opened = Signal.new(),
		Closed = Signal.new(),
		TabChanged = Signal.new(),
	}
	self.cfg = cfg
	return (self :: any)
end

-- Data helpers
function ShopController:_getProductInfo(id: number): any?
	local cached = self.productCache.get(tostring(id))
	if cached then return cached end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
	end)
	if ok and info then
		self.productCache.set(tostring(id), info)
		return info
	end
	return nil
end

function ShopController:_getPassInfo(id: number): any?
	local key = "pass_" .. id
	local cached = self.productCache.get(key)
	if cached then return cached end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
	end)
	if ok and info then
		self.productCache.set(key, info)
		return info
	end
	return nil
end

function ShopController:_ownsPass(id: number): boolean
	local key = tostring(self._player.UserId) .. ":" .. tostring(id)
	local cached = self.ownershipCache.get(key)
	if cached ~= nil then
		return cached
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(self._player.UserId, id)
	end)
	if ok then
		self.ownershipCache.set(key, owns)
		return owns
	end
	return false
end

function ShopController:_refreshPrices()
	for _, p in ipairs(self.cfg.Products.cash) do
		local info = self:_getProductInfo(p.id)
		if info then p.price = info.PriceInRobux or 0 end
	end
	for _, gp in ipairs(self.cfg.Products.gamepasses) do
		local info = self:_getPassInfo(gp.id)
		if info then gp.price = info.PriceInRobux or 0 end
	end
end

-- Build GUI
function ShopController:_buildGui()
	local g = Instance.new("ScreenGui")
	g.Name = "TycoonShopUI"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 1000
	g.Enabled = false
	g.Parent = PlayerGui

	ImageX({
		Name = "Dim",
		Image = self.cfg.Icons.Vignette,
		ImageTransparency = 0.25,
		ImageColor3 = Color3.new(0, 0, 0),
		Size = UDim2.fromScale(1, 1),
		Parent = g,
	})

	local panel = FrameX({
		Name = "Panel",
		Size = UDim2.new(0.9, 0, 0.85, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Tokens.colors.surface,
		corner = Tokens.radius.lg,
		stroke = { Color = Tokens.colors.stroke, Transparency = 0.5 },
		Parent = g,
	})
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1.6
	ar.DominantAxis = Enum.DominantAxis.Height
	ar.Parent = panel

	self._panel = panel
	self._gui = g

	local blur = Lighting:FindFirstChild("ShopBlur") :: BlurEffect?
	if not blur then
		blur = Instance.new("BlurEffect")
		blur.Name = "ShopBlur"
		blur.Size = 0
		blur.Parent = Lighting
	end
	self._blur = blur
end

function ShopController:_buildHeader()
	assert(self._panel, "panel not built")
	local header = FrameX({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Tokens.colors.surfaceAlt,
		corner = Tokens.radius.lg,
		Parent = self._panel,
	})
	applyPadding(header, { left = Tokens.spacing.md, right = Tokens.spacing.md })

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, Tokens.spacing.sm)
	layout.Parent = header

	ImageX({
		Image = self.cfg.Icons.Shop,
		Size = UDim2.fromOffset(36, 36),
		LayoutOrder = 1,
		Parent = header,
	})

	local title = TextLabelX({
		Text = "Game Shop",
		Font = Tokens.typography.title.font,
		TextSize = Tokens.typography.title.size,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -120, 1, 0),
		LayoutOrder = 2,
		Parent = header,
	})
	title.TextTransparency = 0

	local close = TextButtonX({
		Text = "✕",
		Font = Tokens.typography.title.font,
		TextSize = 20,
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Tokens.colors.surface,
		TextColor3 = Tokens.colors.text,
		corner = Tokens.radius.full,
		LayoutOrder = 3,
		Parent = header,
	})
	close.MouseButton1Click:Connect(function() self:close() end)
	close.MouseEnter:Connect(function() tween(close, { BackgroundColor3 = Tokens.colors.stroke }, 0.1) end)
	close.MouseLeave:Connect(function() tween(close, { BackgroundColor3 = Tokens.colors.surface }, 0.1) end)

	self._header = header
end

function ShopController:_buildNav()
	assert(self._panel, "panel not built")
	local nav = FrameX({
		Name = "Nav",
		Size = UDim2.new(0, 200, 1, -80),
		Position = UDim2.fromOffset(Tokens.spacing.md, 72),
		BackgroundColor3 = Tokens.colors.surfaceAlt,
		corner = Tokens.radius.md,
		stroke = { Color = Tokens.colors.stroke, Transparency = 0.6 },
		Parent = self._panel,
	})
	applyPadding(nav, {
		top = Tokens.spacing.sm, bottom = Tokens.spacing.sm, left = Tokens.spacing.sm, right = Tokens.spacing.sm,
	})

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, Tokens.spacing.sm)
	list.Parent = nav

	local function makeTab(id: string, name: string, accent: Color3)
		local btn = TextButtonX({
			Text = name,
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = Tokens.colors.surface,
			TextColor3 = Tokens.colors.text,
			Font = Tokens.typography.label.font,
			TextSize = 18,
			corner = Tokens.radius.sm,
			Parent = nav,
		})
		btn.MouseButton1Click:Connect(function() self:selectTab(id) end)
		btn.MouseEnter:Connect(function()
			tween(btn, { BackgroundColor3 = accent, TextColor3 = Color3.new(1,1,1) }, 0.1)
		end)
		btn.MouseLeave:Connect(function()
			local active = self.state.tab == id
			tween(btn, { BackgroundColor3 = active and accent or Tokens.colors.surface }, 0.1)
			tween(btn, { TextColor3 = active and Color3.new(1,1,1) or Tokens.colors.text }, 0.1)
		end)
		self._tabButtons[id] = btn
	end

	makeTab("Cash", "Cash Packs", Tokens.colors.mint)
	makeTab("Gamepasses", "Game Passes", Tokens.colors.lav)

	self._nav = nav
end

function ShopController:_buildContent()
	assert(self._panel, "panel not built")
	local content = FrameX({
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -(200 + Tokens.spacing.xl), 1, -96),
		Position = UDim2.fromOffset(200 + Tokens.spacing.lg, 80),
		Parent = self._panel,
	})
	self._content = content

	self._pages.Cash = self:_createCashPage(content)
	self._pages.Gamepasses = self:_createPassPage(content)

	self:selectTab(self.state.tab)
end

function ShopController:_createCashPage(parent: Instance): Frame
	local page = FrameX({
		Name = "CashPage",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})

	sectionHeader(page, "Cash Packs")

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Tokens.colors.stroke
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Size = UDim2.new(1, 0, 1, -56)
	scroll.Position = UDim2.fromOffset(0, 52)
	scroll.Parent = page

	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellPadding = UDim2.fromOffset(Tokens.spacing.md, Tokens.spacing.md)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.FillDirectionMaxCells = 3
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroll

	for i, prod in ipairs(self.cfg.Products.cash) do
		self:_cashCard(prod, scroll, i)
	end

	return page
end

function ShopController:_cashCard(prod: CashProduct, parent: Instance, order: number)
	local card = FrameX({
		Name = prod.name .. "Card",
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Tokens.colors.surface,
		corner = Tokens.radius.md,
		stroke = { Color = Tokens.colors.mint, Transparency = 0.4 },
		Parent = parent,
	})
	card.LayoutOrder = order
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1.55
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = card

	local inner = FrameX({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 1, -24),
		Position = UDim2.fromOffset(12, 12),
		Parent = card,
	})

	local v = Instance.new("UIListLayout")
	v.FillDirection = Enum.FillDirection.Vertical
	v.Padding = UDim.new(0, Tokens.spacing.xs)
	v.Parent = inner

	local row = FrameX({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = inner,
	})
	local h = Instance.new("UIListLayout")
	h.FillDirection = Enum.FillDirection.Horizontal
	h.Padding = UDim.new(0, Tokens.spacing.xs)
	h.Parent = row

	ImageX({ Image = prod.icon or self.cfg.Icons.Cash, Size = UDim2.fromOffset(36,36), Parent = row })
	TextLabelX({
		Text = prod.name,
		Font = Tokens.typography.section.font,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -44, 1, 0),
		Parent = row,
	})

	TextLabelX({
		Text = prod.description or "",
		TextColor3 = Tokens.colors.text2,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = inner,
	})

	local priceText = string.format("R$%s  •  %s Cash", tostring(prod.price or 0), fmtNum(prod.amount))
	local price = TextLabelX({
		Text = priceText,
		Font = Tokens.typography.label.font,
		TextSize = 18,
		TextColor3 = Tokens.colors.mint,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = inner,
	})

	local btn = TextButtonX({
		Text = "Purchase",
		BackgroundColor3 = Tokens.colors.mint,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Tokens.typography.label.font,
		TextSize = 18,
		Size = UDim2.new(1, 0, 0, 40),
		corner = Tokens.radius.sm,
		Parent = inner,
	})
	btn.MouseButton1Click:Connect(function()
		self:_promptPurchase(prod.id, "product")
	end)

	card.MouseEnter:Connect(function()
		if isSmallViewport() then return end
		tween(card, { BackgroundColor3 = Tokens.colors.surfaceAlt }, 0.12)
	end)
	card.MouseLeave:Connect(function()
		tween(card, { BackgroundColor3 = Tokens.colors.surface }, 0.12)
	end)

	prod._card = card
	prod._priceLabel = price
	prod._buyButton = btn
end

function ShopController:_createPassPage(parent: Instance): Frame
	local page = FrameX({
		Name = "PassPage",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})

	sectionHeader(page, "Game Passes")

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Tokens.colors.stroke
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Size = UDim2.new(1, 0, 1, -56)
	scroll.Position = UDim2.fromOffset(0, 52)
	scroll.Parent = page

	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellPadding = UDim2.fromOffset(Tokens.spacing.md, Tokens.spacing.md)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.FillDirectionMaxCells = 3
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroll

	for i, pass in ipairs(self.cfg.Products.gamepasses) do
		self:_passCard(pass, scroll, i)
	end

	local settings = FrameX({
		Name = "Settings",
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundColor3 = Tokens.colors.surfaceAlt,
		corner = Tokens.radius.sm,
		Position = UDim2.new(0, 0, 1, -80),
		Parent = page,
	})
	applyPadding(settings, { left = Tokens.spacing.md, right = Tokens.spacing.md })

	TextLabelX({
		Text = "Quick Settings",
		Font = Tokens.typography.label.font,
		TextSize = 18,
		Size = UDim2.new(0.5, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = settings,
	})

	local toggle = createToggle(settings, "Auto Collect", false, function(state: boolean)
		if not self._remotes then return end
		local ev = self._remotes:FindFirstChild("AutoCollectToggle")
		if ev and ev:IsA("RemoteEvent") then
			(ev :: RemoteEvent):FireServer(state)
		end
	end)
	toggle.Position = UDim2.new(1, -120, 0.5, 0)
	toggle.AnchorPoint = Vector2.new(1, 0.5)
	self._autoToggleSettings = toggle

	local ownsAuto = self:_ownsPass(self.cfg.PassIds.AutoCollect)
	toggle.Visible = ownsAuto

	local rf = self._remotes and self._remotes:FindFirstChild("GetAutoCollectState")
	if ownsAuto and rf and rf:IsA("RemoteFunction") then
		local ok, st = pcall(function()
			return (rf :: RemoteFunction):InvokeServer()
		end)
		if ok and typeof(st) == "boolean" then
			(toggle :: ToggleWidget):SetState(st)
		end
	end

	return page
end

function ShopController:_updatePassVisual(pass: GamePass, owned: boolean, btn: TextButton?, card: Frame?)
	local b = btn or pass._buyButton
	local c = card or pass._card
	if not b or not c then return end
	b.Text = owned and "Owned" or "Purchase"
	b.Active = not owned
	b.BackgroundColor3 = owned and Tokens.colors.ok or Tokens.colors.lav
	local stroke = c:FindFirstChildOfClass("UIStroke")
	if stroke then (stroke :: UIStroke).Color = owned and Tokens.colors.ok or Tokens.colors.lav end
end

function ShopController:_passCard(pass: GamePass, parent: Instance, order: number)
	local card = FrameX({
		Name = pass.name .. "Card",
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Tokens.colors.surface,
		corner = Tokens.radius.md,
		stroke = { Color = Tokens.colors.lav, Transparency = 0.45 },
		Parent = parent,
	})
	card.LayoutOrder = order

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1.55
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = card

	local inner = FrameX({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 1, -24),
		Position = UDim2.fromOffset(12, 12),
		Parent = card,
	})

	local v = Instance.new("UIListLayout")
	v.FillDirection = Enum.FillDirection.Vertical
	v.Padding = UDim.new(0, Tokens.spacing.xs)
	v.Parent = inner

	local row = FrameX({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = inner })
	local h = Instance.new("UIListLayout")
	h.FillDirection = Enum.FillDirection.Horizontal
	h.Padding = UDim.new(0, Tokens.spacing.xs)
	h.Parent = row

	ImageX({ Image = pass.icon or self.cfg.Icons.Pass, Size = UDim2.fromOffset(36,36), Parent = row })
	TextLabelX({
		Text = pass.name,
		Font = Tokens.typography.section.font,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -44, 1, 0),
		Parent = row,
	})

	TextLabelX({
		Text = pass.description or "",
		TextColor3 = Tokens.colors.text2,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = inner,
	})

	local priceText = string.format("R$%s", tostring(pass.price or 0))
	local price = TextLabelX({
		Text = priceText,
		Font = Tokens.typography.label.font,
		TextSize = 18,
		TextColor3 = Tokens.colors.lav,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = inner,
	})

	local btn = TextButtonX({
		Text = "Purchase",
		BackgroundColor3 = Tokens.colors.lav,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Tokens.typography.label.font,
		TextSize = 18,
		Size = UDim2.new(1, 0, 0, 40),
		corner = Tokens.radius.sm,
		Parent = inner,
	})
	btn.MouseButton1Click:Connect(function()
		self:_promptPurchase(pass.id, "gamepass")
	end)

	local owned = self:_ownsPass(pass.id)
	self:_updatePassVisual(pass, owned, btn, card)

	if pass.id == self.cfg.PassIds.AutoCollect and pass.hasToggle then
		local inlineToggle = createToggle(inner, "Enable", false, function(state: boolean)
			if not self._remotes then return end
			local ev = self._remotes:FindFirstChild("AutoCollectToggle")
			if ev and ev:IsA("RemoteEvent") then
				(ev :: RemoteEvent):FireServer(state)
			end
			if self._autoToggleSettings and self._autoToggleSettings.Visible then
				(self._autoToggleSettings :: ToggleWidget):SetState(state)
			end
		end)
		inlineToggle.Visible = owned
	end

	card.MouseEnter:Connect(function()
		if isSmallViewport() then return end
		tween(card, { BackgroundColor3 = Tokens.colors.surfaceAlt }, 0.12)
	end)
	card.MouseLeave:Connect(function()
		tween(card, { BackgroundColor3 = Tokens.colors.surface }, 0.12)
	end)

	pass._card = card
	pass._priceLabel = price
	pass._buyButton = btn
end

-- Open / Close / Select
function ShopController:open()
	if self.state.open or self.state.animating then return end
	self.state.animating = true
	self.state.open = true

	self:_refreshPrices()
	self:refreshVisuals()

	assert(self._gui and self._panel and self._blur, "gui not built")
	local gui   = self._gui  :: ScreenGui
	local panel = self._panel:: Frame
	local blur  = self._blur :: BlurEffect

	gui.Enabled = true
	tween(blur,  { Size = 28 }, 0.22)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	tween(panel, { Position = UDim2.fromScale(0.5, 0.5) }, 0.35, Enum.EasingStyle.Back)
	task.delay(0.35, function()
		self.state.animating = false
		self.Events.Opened:Fire()
	end)
end

function ShopController:close()
	if not self.state.open or self.state.animating then return end
	self.state.animating = true
	self.state.open = false

	assert(self._gui and self._panel and self._blur, "gui not built")
	local gui   = self._gui  :: ScreenGui
	local panel = self._panel:: Frame
	local blur  = self._blur :: BlurEffect

	tween(blur,  { Size = 0 }, 0.12)
	tween(panel, { Position = UDim2.fromScale(0.5, 0.52) }, 0.12)
	task.delay(0.12, function()
		gui.Enabled = false
		self.state.animating = false
		self.Events.Closed:Fire()
	end)
end

function ShopController:toggle()
	if self.state.open then self:close() else self:open() end
end

function ShopController:selectTab(id: string)
	if self.state.tab == id then
		for k, pg in pairs(self._pages) do
			pg.Visible = (k == id)
		end
		return
	end
	for key, btn in pairs(self._tabButtons) do
		local active = (key == id)
		local accent = key == "Cash" and Tokens.colors.mint or Tokens.colors.lav
		tween(btn, { BackgroundColor3 = active and accent or Tokens.colors.surface }, 0.12)
		tween(btn, { TextColor3 = active and Color3.new(1,1,1) or Tokens.colors.text }, 0.12)
	end
	for k, pg in pairs(self._pages) do
		pg.Visible = (k == id)
	end
	self.state.tab = id
	self.Events.TabChanged:Fire(id)
end

function ShopController:refreshVisuals()
	self.ownershipCache.clear()
	for _, pass in ipairs(self.cfg.Products.gamepasses) do
		local owned = self:_ownsPass(pass.id)
		self:_updatePassVisual(pass, owned, nil, nil)
	end
	for _, prod in ipairs(self.cfg.Products.cash) do
		if prod._priceLabel then
			prod._priceLabel.Text = string.format("R$%s  •  %s Cash", tostring(prod.price or 0), fmtNum(prod.amount))
		end
	end
	if self._autoToggleSettings then
		self._autoToggleSettings.Visible = self:_ownsPass(self.cfg.PassIds.AutoCollect)
	end
end

-- Purchase
function ShopController:_promptPurchase(id: number, kind: string)
	if kind == "gamepass" then
		if self:_ownsPass(id) then return end
		self.state.pending[id] = { t = os.clock() }
		pcall(function() MarketplaceService:PromptGamePassPurchase(self._player, id) end)
		task.delay(self.cfg.PurchaseTimeout, function()
			if self.state.pending[id] then self.state.pending[id] = nil end
		end)
	else
		self.state.pending[id] = { t = os.clock() }
		pcall(function() MarketplaceService:PromptProductPurchase(self._player, id) end)
	end
end

-- Inputs & Marketplace wiring
function ShopController:_wireInputs()
	table.insert(self.connected, UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.M then
			self:toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and self.state.open then
			self:close()
		end
	end))
	if UserInputService.GamepadEnabled then
		table.insert(self.connected, UserInputService.InputBegan:Connect(function(input, gp)
			if gp then return end
			if input.KeyCode == Enum.KeyCode.ButtonX then
				self:toggle()
			end
		end))
	end

	local toggleGui = PlayerGui:FindFirstChild("ShopToggle") :: ScreenGui?
	if not toggleGui then
		toggleGui = Instance.new("ScreenGui")
		toggleGui.Name = "ShopToggle"
		toggleGui.ResetOnSpawn = false
		toggleGui.DisplayOrder = 999
		toggleGui.Parent = PlayerGui
	end
	local pill = TextButtonX({
		Text = "Shop",
		BackgroundColor3 = Tokens.colors.surface,
		TextColor3 = Tokens.colors.text,
		Font = Tokens.typography.label.font,
		TextSize = 20,
		Size = UDim2.fromOffset(156, 56),
		Position = UDim2.new(1, -20, 1, -20),
		AnchorPoint = Vector2.new(1, 1),
		corner = Tokens.radius.full,
		Parent = toggleGui,
	})
	pill.MouseButton1Click:Connect(function() self:toggle() end)
	pill.MouseEnter:Connect(function()
		tween(pill, { BackgroundColor3 = Tokens.colors.mint, TextColor3 = Color3.new(1,1,1) }, 0.1)
	end)
	pill.MouseLeave:Connect(function()
		tween(pill, { BackgroundColor3 = Tokens.colors.surface, TextColor3 = Tokens.colors.text }, 0.1)
	end)
end

function ShopController:_wireMarketplace()
	table.insert(self.connected, MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if player ~= self._player then return end
		if not self.state.pending[passId] then return end
		self.state.pending[passId] = nil
		if purchased then
			self.ownershipCache.clear()
			for _, pass in ipairs(self.cfg.Products.gamepasses) do
				if pass.id == passId and pass._buyButton then
					pass._buyButton.Text = "Owned"
					pass._buyButton.BackgroundColor3 = Tokens.colors.ok
					pass._buyButton.Active = false
				end
			end
			self:refreshVisuals()
			if self._remotes then
				local ev = self._remotes:FindFirstChild("GamepassPurchased")
				if ev and ev:IsA("RemoteEvent") then
					(ev :: RemoteEvent):FireServer(passId)
				end
			end
		end
	end))

	table.insert(self.connected, MarketplaceService.PromptProductPurchaseFinished:Connect(function(player: Player, productId: number, purchased: boolean)
		if player ~= self._player then return end
		if not self.state.pending[productId] then return end
		self.state.pending[productId] = nil
		if purchased and self._remotes then
			local ev = self._remotes:FindFirstChild("GrantProductCurrency") or self._remotes:FindFirstChild("ProductGranted")
			if ev and ev:IsA("RemoteEvent") then
				(ev :: RemoteEvent):FireServer(productId)
			end
		end
	end))
end

function ShopController:init()
	self:_buildGui()
	self:_buildHeader()
	self:_buildNav()
	self:_buildContent()
	self:_wireInputs()
	self:_wireMarketplace()
end

function ShopController:destroy()
	for i = #self.connected, 1, -1 do
		self.connected[i]:Disconnect()
		self.connected[i] = nil :: any
	end
	if self._gui then self._gui:Destroy() end
end

--// =========================
--// CONFIG + BOOT
--// =========================

local ICON_CASH = "rbxassetid://18420350532"
local ICON_PASS = "rbxassetid://18420350433"
local ICON_SHOP = "rbxassetid://17398522865"
local ICON_VIGNETTE = "rbxassetid://7743879747"

local PASS_AUTO_COLLECT = 1412171840
local PASS_2X_CASH     = 1398974710

local CFG: ShopConfig = {
	Version = "6.0.0-revamp",
	Debug = false,
	Animations = true,
	PurchaseTimeout = 15,
	RefreshInterval = 30,
	Icons = {
		Cash = ICON_CASH,
		Pass = ICON_PASS,
		Shop = ICON_SHOP,
		Vignette = ICON_VIGNETTE,
	},
	PassIds = {
		AutoCollect = PASS_AUTO_COLLECT,
		DoubleCash = PASS_2X_CASH,
	},
	Products = {
		cash = {
			{ id = 1897730242, amount = 1000,    name = "Starter Pouch",   description = "Kickstart upgrades.", icon = ICON_CASH },
			{ id = 1897730373, amount = 5000,    name = "Festival Bundle", description = "Dress your floors.",  icon = ICON_CASH },
			{ id = 1897730467, amount = 10000,   name = "Showcase Chest",  description = "Unlock new wings.",   icon = ICON_CASH },
			{ id = 1897730581, amount = 50000,   name = "Grand Vault",     description = "Relaunch fund.",      icon = ICON_CASH },
			{ id = 1234567001, amount = 100000,  name = "Mega Safe",       description = "Major expansion.",     icon = ICON_CASH },
			{ id = 1234567002, amount = 250000,  name = "Quarter Million", description = "Serious invest.",      icon = ICON_CASH },
			{ id = 1234567003, amount = 500000,  name = "Half Million",    description = "Fast-track builds.",   icon = ICON_CASH },
			{ id = 1234567004, amount = 1000000, name = "Millionaire Pack",description = "Dominate upgrades.",   icon = ICON_CASH },
			{ id = 1234567005, amount = 5000000, name = "Tycoon Titan",    description = "Finish it all.",       icon = ICON_CASH },
			{ id = 1234567006, amount = 10000000,name = "Ultimate Vault",  description = "Max everything.",      icon = ICON_CASH },
		},
		gamepasses = {
			{ id = PASS_AUTO_COLLECT, name = "Auto Collect", description = "Hands-free register sweep.", icon = ICON_PASS, hasToggle = true },
			{ id = PASS_2X_CASH,     name = "2x Cash",      description = "Double every sale.",         icon = ICON_PASS, hasToggle = false },
		},
	},
	RemotesFolderName = "TycoonRemotes",
}

local controller = (ShopController.new(CFG) :: any)
controller:init()

task.spawn(function()
	while true do
		task.wait(CFG.RefreshInterval)
		controller:refreshVisuals()
	end
end)

Player.CharacterAdded:Connect(function()
	task.wait(1)
end)

_G.TycoonShop = {
	Open = function() controller:open() end,
	Close = function() controller:close() end,
	Toggle = function() controller:toggle() end,
}

print("[Shop] Modern Cute Revamp ready v" .. CFG.Version)
