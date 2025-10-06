--[[
  SANRIO SHOP SYSTEM - POLISHED & CLEAN
  Location: StarterPlayer > StarterPlayerScripts
  Script name: CreateMoneyShop
  
  ✨ Polished UI with proper spacing
  ✨ No overlapping tabs
  ✨ Clean, modern design
]]

-- Services
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:FindFirstChild("TycoonRemotes")

-- ========================================
-- CORE
-- ========================================
local Core = {}

Core.CONSTANTS = {
	PANEL_SIZE = Vector2.new(1140, 860),
	PANEL_SIZE_MOBILE = Vector2.new(920, 720),
	CARD_SIZE = Vector2.new(520, 300),
	CARD_SIZE_MOBILE = Vector2.new(480, 280),

	ANIM_FAST = 0.15,
	ANIM_MEDIUM = 0.25,
	ANIM_BOUNCE = 0.3,

	CACHE_PRODUCT_INFO = 300,
	CACHE_OWNERSHIP = 60,

	PURCHASE_TIMEOUT = 15,
}

Core.State = {
	isOpen = false,
	isAnimating = false,
	purchasePending = {},
	settings = { soundEnabled = true, animationsEnabled = true },
}

-- Simple cache
local Cache = {}
Cache.__index = Cache
function Cache.new(d) return setmetatable({data={},duration=d or 300},Cache) end
function Cache:set(k,v) self.data[k]={v=v,t=tick()} end
function Cache:get(k) local e=self.data[k]; if not e then return end; if tick()-e.t>self.duration then self.data[k]=nil return end; return e.v end
function Cache:clear(k) if k then self.data[k]=nil else self.data={} end end

local productCache = Cache.new(Core.CONSTANTS.CACHE_PRODUCT_INFO)
local ownershipCache = Cache.new(Core.CONSTANTS.CACHE_OWNERSHIP)

-- Utils
Core.Utils = {}
function Core.Utils.isMobile()
	local cam = workspace.CurrentCamera; if not cam then return false end
	local v = cam.ViewportSize
	return v.X < 1024 or GuiService:IsTenFootInterface()
end
function Core.Utils.formatNumber(n)
	local s=tostring(n); local k=1; while k~=0 do s,k=s:gsub("^(-?%d+)(%d%d%d)","%1,%2") end; return s
end
function Core.Utils.blend(a,b,t) t=math.clamp(t,0,1); return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t) end

-- Animation
Core.Animation = {}
function Core.Animation.tween(inst,props,d,style,dir)
	if not Core.State.settings.animationsEnabled then for k,v in pairs(props) do inst[k]=v end; return end
	local tw=TweenService:Create(inst,TweenInfo.new(d or Core.CONSTANTS.ANIM_MEDIUM,style or Enum.EasingStyle.Quad,dir or Enum.EasingDirection.Out),props); tw:Play(); return tw
end

-- Sounds (preload)
Core.SoundSystem = {sounds={}}
function Core.SoundSystem.initialize()
	local cfg={
		click={"rbxassetid://876939830",0.45},
		hover={"rbxassetid://10066936758",0.2},
		open={"rbxassetid://452267918",0.5},
		close={"rbxassetid://452267918",0.5},
		success={"rbxassetid://876939830",0.6},
		error={"rbxassetid://876939830",0.5},
	}
	local preload={}
	for name,data in pairs(cfg) do
		local s=Instance.new("Sound"); s.Name="SanrioShop_"..name; s.SoundId=data[1]; s.Volume=data[2]; s.RollOffMode=Enum.RollOffMode.InverseTapered; s.Parent=SoundService
		Core.SoundSystem.sounds[name]=s; table.insert(preload,s)
	end
	task.spawn(function() pcall(function() ContentProvider:PreloadAsync(preload) end) end)
end
function Core.SoundSystem.play(n) if Core.State.settings.soundEnabled and Core.SoundSystem.sounds[n] then Core.SoundSystem.sounds[n]:Play() end end

-- Data
Core.DataManager = {}
Core.DataManager.products = {
	cash = {
		{ id = 3366419712, amount = 1000,  name = "1,000 Cash",  description = "A small boost to get you started", icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3366420012, amount = 5000,  name = "5,000 Cash",  description = "Perfect for mid-game expansion",   icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3366420478, amount = 10000, name = "10,000 Cash", description = "Accelerate your progress",          icon = "rbxassetid://10709728059", price = 0 },
		{ id = 3366420800, amount = 25000, name = "25,000 Cash", description = "Great value bundle",                 icon = "rbxassetid://10709728059", price = 0 },
	},
	gamepasses = {
		{ id = 1412171840, name = "Auto Collect", description = "Automatically collect all cash drops", icon = "rbxassetid://10709727148", price = 99, hasToggle = true },
		{ id = 1398974710, name = "2x Cash",      description = "Double all cash earned permanently",   icon = "rbxassetid://10709727148", price = 199, hasToggle = false },
	},
}

function Core.DataManager.getProductInfo(id)
	local c=productCache:get(id); if c then return c end
	local ok,info=pcall(function() return MarketplaceService:GetProductInfo(id,Enum.InfoType.Product) end)
	if ok and info then productCache:set(id,info) return info end
end
function Core.DataManager.getGamePassInfo(id)
	local key="pass_"..id; local c=productCache:get(key); if c then return c end
	local ok,info=pcall(function() return MarketplaceService:GetProductInfo(id,Enum.InfoType.GamePass) end)
	if ok and info then productCache:set(key,info) return info end
end
function Core.DataManager.checkOwnership(passId)
	local key = ("%d_%d"):format(Player.UserId, passId)
	local c=ownershipCache:get(key); if c~=nil then return c end
	local ok,owns=pcall(function() return MarketplaceService:UserOwnsGamePassAsync(Player.UserId,passId) end)
	if ok then ownershipCache:set(key,owns) return owns end
	return false
end
function Core.DataManager.refreshPrices()
	for _,p in ipairs(Core.DataManager.products.cash) do
		local i=Core.DataManager.getProductInfo(p.id); if i and i.PriceInRobux then p.price=i.PriceInRobux end
	end
	for _,gp in ipairs(Core.DataManager.products.gamepasses) do
		local i=Core.DataManager.getGamePassInfo(gp.id); if i and i.PriceInRobux then gp.price=i.PriceInRobux end
	end
end

-- ========================================
-- UI
-- ========================================
local UI = {}

UI.Theme = {
	current = "light",
	themes = {
		light = {
			background = Color3.fromRGB(253,252,250),
			surface = Color3.fromRGB(255,255,255),
			surfaceAlt = Color3.fromRGB(246,248,252),
			stroke = Color3.fromRGB(222,226,235),
			text = Color3.fromRGB(35,38,46),
			textSecondary = Color3.fromRGB(120,126,140),
			accent = Color3.fromRGB(255,64,129),
			success = Color3.fromRGB(76,175,80),
			cinna = Color3.fromRGB(186,214,255),
			kuromi = Color3.fromRGB(200,190,255),
		}
	}
}
function UI.Theme:get(k) return self.themes[self.current][k] end

-- Base component
local Component = {}; Component.__index = Component
function Component.new(className, props) return setmetatable({instance=Instance.new(className), props=props or {}}, Component) end
function Component:render()
	for k,v in pairs(self.props) do
		if k~="children" and k~="parent" and k~="onClick" and k~="cornerRadius" and k~="stroke" and k~="layout" and k~="padding" then pcall(function() self.instance[k]=v end) end
	end
	if self.props.cornerRadius then local c=Instance.new("UICorner"); c.CornerRadius=self.props.cornerRadius; c.Parent=self.instance end
	if self.props.stroke then local s=Instance.new("UIStroke"); s.Color=self.props.stroke.color or UI.Theme:get("stroke"); s.Thickness=self.props.stroke.thickness or 1; s.Transparency=self.props.stroke.transparency or 0; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Parent=self.instance end
	if self.props.parent then self.instance.Parent=self.props.parent end
	return self.instance
end

UI.Components = {}

function UI.Components.Frame(props)
	local d={ BackgroundColor3=UI.Theme:get("surface"), BorderSizePixel=0, Size=UDim2.fromScale(1,1) }
	for k,v in pairs(d) do if props[k]==nil then props[k]=v end end
	local cmp=Component.new("Frame",props); local inst=cmp:render()
	if props.layout then
		local kind = props.layout.type or "List"
		local layout = Instance.new("UI"..kind.."Layout")
		for k,v in pairs(props.layout) do if k~="type" then pcall(function() layout[k]=v end) end end
		layout.Parent = inst
		local function update()
			if inst.Parent and inst.Parent:IsA("ScrollingFrame") then
				if kind=="List" then
					inst.Parent.CanvasSize = (inst.Parent.ScrollingDirection==Enum.ScrollingDirection.X)
						and UDim2.new(0, layout.AbsoluteContentSize.X+20, 0, 0)
						or  UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y+20)
				else
					inst.Parent.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y+20)
				end
			end
		end
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update); task.defer(update)
	end
	if props.padding then
		local p=Instance.new("UIPadding")
		if props.padding.top then p.PaddingTop = props.padding.top end
		if props.padding.bottom then p.PaddingBottom = props.padding.bottom end
		if props.padding.left then p.PaddingLeft = props.padding.left end
		if props.padding.right then p.PaddingRight = props.padding.right end
		p.Parent = inst
	end
	return { instance=inst, render=function() return inst end }
end

function UI.Components.TextLabel(props)
	local d={ BackgroundTransparency=1, TextColor3=UI.Theme:get("text"), Font=Enum.Font.Gotham, TextWrapped=true }
	for k,v in pairs(d) do if props[k]==nil then props[k]=v end end
	local cmp=Component.new("TextLabel",props); return cmp
end

function UI.Components.Button(props)
	local d={ BackgroundColor3=UI.Theme:get("accent"), TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamMedium, Size=UDim2.fromOffset(120,40), AutoButtonColor=false }
	for k,v in pairs(d) do if props[k]==nil then props[k]=v end end
	local cmp=Component.new("TextButton",props); local inst=cmp:render()
	-- Hover scale (better than position)
	local hoverScale = Instance.new("UIScale")
	hoverScale.Scale = 1
	hoverScale.Parent = inst
	inst.MouseEnter:Connect(function()
		Core.SoundSystem.play("hover")
		Core.Animation.tween(hoverScale,{Scale=1.02},Core.CONSTANTS.ANIM_FAST)
	end)
	inst.MouseLeave:Connect(function() Core.Animation.tween(hoverScale,{Scale=1},Core.CONSTANTS.ANIM_FAST) end)
	if props.onClick then inst.MouseButton1Click:Connect(props.onClick) end
	inst.MouseButton1Click:Connect(function() Core.SoundSystem.play("click") end)
	return cmp
end

function UI.Components.Image(props)
	local d={ BackgroundTransparency=1, ScaleType=Enum.ScaleType.Fit }
	for k,v in pairs(d) do if props[k]==nil then props[k]=v end end
	return Component.new("ImageLabel",props)
end

UI.Layout = {}
function UI.Layout.stack(parent,dir,spacing,padding)
	local l=Instance.new("UIListLayout"); l.FillDirection=dir or Enum.FillDirection.Horizontal; l.Padding=UDim.new(0,spacing or 10); l.SortOrder=Enum.SortOrder.LayoutOrder; l.Parent=parent
	if padding then local p=Instance.new("UIPadding"); p.PaddingTop=UDim.new(0,padding.top or 0); p.PaddingBottom=UDim.new(0,padding.bottom or 0); p.PaddingLeft=UDim.new(0,padding.left or 0); p.PaddingRight=UDim.new(0,padding.right or 0); p.Parent=parent end
	return l
end

UI.Responsive = {}
function UI.Responsive.scale(inst)
	local cam=workspace.CurrentCamera; if not cam then return end
	local s=Instance.new("UIScale"); s.Parent=inst
	local function u() local v=cam.ViewportSize; local f=math.min(v.X/1920,v.Y/1080); f=math.clamp(f,0.5,1.35); if Core.Utils.isMobile() then f=f*0.9 end; s.Scale=f end
	u(); cam:GetPropertyChangedSignal("ViewportSize"):Connect(u)
end

-- ========================================
-- SHOP (POLISHED)
-- ========================================
local Shop = {}; Shop.__index=Shop

function Shop.new()
	local self=setmetatable({},Shop)
	self.gui=nil; self.mainPanel=nil; self.tabContainer=nil; self.contentContainer=nil
	self.currentTab=nil; self.tabs={}; self.pages={}; self.toggleButton=nil; self.blur=nil
	self:initialize()
	return self
end

function Shop:preloadImages()
	local ids={"rbxassetid://17398522865","rbxassetid://10709728059","rbxassetid://10709727148"}
	for _,p in ipairs(Core.DataManager.products.cash) do if p.icon then table.insert(ids,p.icon) end end
	for _,p in ipairs(Core.DataManager.products.gamepasses) do if p.icon then table.insert(ids,p.icon) end end
	task.spawn(function() pcall(function() ContentProvider:PreloadAsync(ids) end) end)
end

function Shop:initialize()
	Core.SoundSystem.initialize()
	Core.DataManager.refreshPrices()
	self:preloadImages()
	self:createToggleButton()
	self:createMainInterface()
	self:setupInputHandlers()
end

function Shop:createToggleButton()
	local sg=PlayerGui:FindFirstChild("SanrioShopToggle") or Instance.new("ScreenGui")
	sg.Name="SanrioShopToggle"; sg.ResetOnSpawn=false; sg.DisplayOrder=999; sg.Parent=PlayerGui

	self.toggleButton = UI.Components.Button({
		Text="", Size=UDim2.fromOffset(180,60), Position=UDim2.new(1,-20,1,-20), AnchorPoint=Vector2.new(1,1),
		BackgroundColor3=UI.Theme:get("surface"), cornerRadius=UDim.new(1,0),
		stroke={color=UI.Theme:get("accent"),thickness=2}, parent=sg, onClick=function() self:toggle() end
	}):render()

	UI.Components.Image({ Image="rbxassetid://17398522865", Size=UDim2.fromOffset(32,32), Position=UDim2.fromOffset(16,14), parent=self.toggleButton }):render()
	UI.Components.TextLabel({ Text="Shop", Size=UDim2.new(1,-64,1,0), Position=UDim2.fromOffset(56,0), TextXAlignment=Enum.TextXAlignment.Left, Font=Enum.Font.GothamBold, TextSize=20, parent=self.toggleButton }):render()
end

function Shop:createMainInterface()
	self.gui = PlayerGui:FindFirstChild("SanrioShopMain") or Instance.new("ScreenGui")
	self.gui.Name="SanrioShopMain"; self.gui.ResetOnSpawn=false; self.gui.DisplayOrder=1000; self.gui.Enabled=false; self.gui.Parent=PlayerGui

	self.blur = Lighting:FindFirstChild("SanrioShopBlur") or Instance.new("BlurEffect"); self.blur.Name="SanrioShopBlur"; self.blur.Size=0; self.blur.Parent=Lighting

	local dim = UI.Components.Frame({ Size=UDim2.fromScale(1,1), BackgroundColor3=Color3.new(0,0,0), BackgroundTransparency=0.35, parent=self.gui }):render()
	dim.Active=true; dim.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then self:close() end end)

	local size = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE
	self.mainPanel = UI.Components.Frame({
		Size=UDim2.fromOffset(size.X,size.Y), Position=UDim2.fromScale(0.5,0.5), AnchorPoint=Vector2.new(0.5,0.5),
		BackgroundColor3=UI.Theme:get("background"), cornerRadius=UDim.new(0,24), stroke={color=UI.Theme:get("stroke"),thickness=1}, parent=self.gui
	}):render()
	UI.Responsive.scale(self.mainPanel)

	-- Header (POLISHED)
	local header = UI.Components.Frame({ Size=UDim2.new(1,-48,0,80), Position=UDim2.fromOffset(24,24), BackgroundColor3=UI.Theme:get("surfaceAlt"), cornerRadius=UDim.new(0,18), parent=self.mainPanel }):render()
	UI.Components.Image({ Image="rbxassetid://17398522865", Size=UDim2.fromOffset(60,60), Position=UDim2.fromOffset(16,10), parent=header }):render()
	UI.Components.TextLabel({ Text="Sanrio Shop", Size=UDim2.new(1,-200,1,0), Position=UDim2.fromOffset(92,0), TextXAlignment=Enum.TextXAlignment.Left, Font=Enum.Font.GothamBold, TextSize=32, parent=header }):render()
	UI.Components.Button({ Text="✕", Size=UDim2.fromOffset(48,48), Position=UDim2.new(1,-64,0.5,0), AnchorPoint=Vector2.new(0,0.5), BackgroundColor3=UI.Theme:get("accent"), TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=24, cornerRadius=UDim.new(0.5,0), parent=header, onClick=function() self:close() end }):render()

	-- Tabs (POLISHED - NO MORE OVERLAP!)
	self.tabContainer = UI.Components.Frame({ Size=UDim2.new(1,-48,0,60), Position=UDim2.fromOffset(24,120), BackgroundTransparency=1, parent=self.mainPanel }):render()
	local tabLayout = UI.Layout.stack(self.tabContainer, Enum.FillDirection.Horizontal, 20)
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	
	local tabs={
		{ id="Cash",       name="Cash",   icon="rbxassetid://10709728059", color=UI.Theme:get("cinna")   },
		{ id="Gamepasses", name="Passes", icon="rbxassetid://10709727148", color=UI.Theme:get("kuromi")  },
	}
	for _,d in ipairs(tabs) do
		local tab = UI.Components.Button({
			Text="", Size=UDim2.fromOffset(220,60), BackgroundColor3=UI.Theme:get("surface"), cornerRadius=UDim.new(0,18), stroke={color=UI.Theme:get("stroke"),thickness=2},
			parent=self.tabContainer, onClick=function() self:selectTab(d.id) end
		}):render()
		local content = UI.Components.Frame({ Size=UDim2.fromScale(1,1), BackgroundTransparency=1, parent=tab }):render()
		local contentLayout = UI.Layout.stack(content, Enum.FillDirection.Horizontal, 14)
		contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		contentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		local icon = UI.Components.Image({ Image=d.icon, Size=UDim2.fromOffset(32,32), parent=content }):render()
		local label = UI.Components.TextLabel({ Text=d.name, Size=UDim2.new(0,100,1,0), Font=Enum.Font.GothamBold, TextSize=20, parent=content }):render()
		self.tabs[d.id]={button=tab,data=d,icon=icon,label=label}
	end

	-- Content (POLISHED SPACING)
	self.contentContainer = UI.Components.Frame({ Size=UDim2.new(1,-48,1,-210), Position=UDim2.fromOffset(24,196), BackgroundTransparency=1, parent=self.mainPanel }):render()
	self:createPages()
	self:selectTab("Cash")
end

function Shop:createPages()
	-- Cash (POLISHED)
	local cashPage = UI.Components.Frame({ Name="CashPage", Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Visible=false, parent=self.contentContainer }):render()
	local sfCash = Instance.new("ScrollingFrame")
	sfCash.BackgroundTransparency=1; sfCash.ScrollBarThickness=6; sfCash.ScrollBarImageColor3=UI.Theme:get("accent"); sfCash.BorderSizePixel=0; sfCash.Size=UDim2.fromScale(1,1); sfCash.Parent=cashPage
	local gridCash=Instance.new("UIGridLayout"); gridCash.CellPadding=UDim2.fromOffset(24,24)
	gridCash.CellSize = Core.Utils.isMobile() and UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE_MOBILE.X, Core.CONSTANTS.CARD_SIZE_MOBILE.Y) or UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y)
	gridCash.HorizontalAlignment=Enum.HorizontalAlignment.Center; gridCash.Parent=sfCash
	gridCash:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() sfCash.CanvasSize=UDim2.new(0,0,0,gridCash.AbsoluteContentSize.Y+40) end)
	for _,p in ipairs(Core.DataManager.products.cash) do self:createProductCard(p, "cash", sfCash) end

	-- Passes (POLISHED)
	local passPage = UI.Components.Frame({ Name="GamepassesPage", Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Visible=false, parent=self.contentContainer }):render()
	local sfPass = Instance.new("ScrollingFrame")
	sfPass.BackgroundTransparency=1; sfPass.ScrollBarThickness=6; sfPass.ScrollBarImageColor3=UI.Theme:get("accent"); sfPass.BorderSizePixel=0; sfPass.Size=UDim2.fromScale(1,1); sfPass.Parent=passPage
	local gridPass=Instance.new("UIGridLayout"); gridPass.CellPadding=UDim2.fromOffset(24,24)
	gridPass.CellSize = Core.Utils.isMobile() and UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE_MOBILE.X, Core.CONSTANTS.CARD_SIZE_MOBILE.Y) or UDim2.fromOffset(Core.CONSTANTS.CARD_SIZE.X, Core.CONSTANTS.CARD_SIZE.Y)
	gridPass.HorizontalAlignment=Enum.HorizontalAlignment.Center; gridPass.Parent=sfPass
	gridPass:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() sfPass.CanvasSize=UDim2.new(0,0,0,gridPass.AbsoluteContentSize.Y+40) end)
	for _,gp in ipairs(Core.DataManager.products.gamepasses) do self:createProductCard(gp, "gamepass", sfPass) end

	self.pages = { Cash=cashPage, Gamepasses=passPage }
end

function Shop:addToggleSwitch(product, imageContainer)
	local container=Instance.new("Frame"); container.Name="ToggleContainer"; container.Size=UDim2.fromOffset(56,28); container.Position=UDim2.new(1,-64,0,8)
	container.BackgroundColor3=UI.Theme:get("stroke"); container.BorderSizePixel=0; container.ZIndex=2; container.Parent=imageContainer
	local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0.5,0); c.Parent=container
	local knob=Instance.new("Frame"); knob.Name="Knob"; knob.Size=UDim2.fromOffset(24,24); knob.Position=UDim2.fromOffset(2,2); knob.BackgroundColor3=UI.Theme:get("surface"); knob.BorderSizePixel=0; knob.Parent=container
	local kc=Instance.new("UICorner"); kc.CornerRadius=UDim.new(0.5,0); kc.Parent=knob
	local click=Instance.new("TextButton"); click.BackgroundTransparency=1; click.Text=""; click.Size=UDim2.fromScale(1,1); click.Parent=container

	local state=false
	if Remotes then
		local rf=Remotes:FindFirstChild("GetAutoCollectState")
		if rf and rf:IsA("RemoteFunction") then local ok,val=pcall(function() return rf:InvokeServer() end); if ok and type(val)=="boolean" then state=val end end
	end
	local function render()
		if state then container.BackgroundColor3=UI.Theme:get("success"); Core.Animation.tween(knob,{Position=UDim2.fromOffset(30,2)},Core.CONSTANTS.ANIM_FAST)
		else container.BackgroundColor3=UI.Theme:get("stroke"); Core.Animation.tween(knob,{Position=UDim2.fromOffset(2,2)},Core.CONSTANTS.ANIM_FAST) end
	end
	render()
	click.MouseButton1Click:Connect(function()
		state=not state; render()
		if Remotes then local ev=Remotes:FindFirstChild("AutoCollectToggle"); if ev and ev:IsA("RemoteEvent") then ev:FireServer(state) end end
		Core.SoundSystem.play("click")
	end)
end

function Shop:createProductCard(product, productType, parent)
	local isGamepass = (productType=="gamepass")
	local cardColor = isGamepass and UI.Theme:get("kuromi") or UI.Theme:get("cinna")

	local card = UI.Components.Frame({
		Name=product.name.."Card",
		Size=UDim2.fromOffset(Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.X or Core.CONSTANTS.CARD_SIZE.X,
			Core.Utils.isMobile() and Core.CONSTANTS.CARD_SIZE_MOBILE.Y or Core.CONSTANTS.CARD_SIZE.Y),
		BackgroundColor3=UI.Theme:get("surface"), cornerRadius=UDim.new(0,18),
		stroke={color=cardColor,thickness=2,transparency=0.4}, parent=parent
	}):render()

	-- Hover scale (POLISHED - no position jumps!)
	local hoverScale = Instance.new("UIScale")
	hoverScale.Scale = 1
	hoverScale.Parent = card
	card.MouseEnter:Connect(function()
		Core.SoundSystem.play("hover")
		Core.Animation.tween(hoverScale,{Scale=1.03},Core.CONSTANTS.ANIM_FAST)
	end)
	card.MouseLeave:Connect(function() Core.Animation.tween(hoverScale,{Scale=1},Core.CONSTANTS.ANIM_FAST) end)

	local content=Instance.new("Frame"); content.BackgroundTransparency=1; content.Size=UDim2.new(1,-24,1,-24); content.Position=UDim2.fromOffset(12,12); content.Parent=card

	-- Image container (POLISHED with gradient)
	local imageContainer=Instance.new("Frame"); imageContainer.Size=UDim2.new(1,0,0,140); imageContainer.BackgroundColor3=UI.Theme:get("surfaceAlt"); imageContainer.BorderSizePixel=0; imageContainer.Parent=content
	local ic=Instance.new("UICorner"); ic.CornerRadius=UDim.new(0,14); ic.Parent=imageContainer
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromRGB(250,250,252))
	gradient.Rotation = 90
	gradient.Parent = imageContainer
	UI.Components.Image({ Image=product.icon or "rbxassetid://0", Size=UDim2.fromScale(0.7,0.7), Position=UDim2.fromScale(0.5,0.5), AnchorPoint=Vector2.new(0.5,0.5), parent=imageContainer }):render()

	local info=Instance.new("Frame"); info.BackgroundTransparency=1; info.Size=UDim2.new(1,0,1,-160); info.Position=UDim2.fromOffset(0,160); info.Parent=content
	UI.Components.TextLabel({ Text=product.name, Size=UDim2.new(1,0,0,28), Font=Enum.Font.GothamBold, TextSize=20, TextXAlignment=Enum.TextXAlignment.Left, parent=info }):render()

	local descText = isGamepass and product.description or ("Includes "..Core.Utils.formatNumber(product.amount).." Cash")
	UI.Components.TextLabel({ Text=descText, Size=UDim2.new(1,0,0,40), Position=UDim2.fromOffset(0,32), Font=Enum.Font.Gotham, TextSize=14, TextColor3=UI.Theme:get("textSecondary"), TextXAlignment=Enum.TextXAlignment.Left, parent=info }):render()

	local priceText = isGamepass and ("R$"..tostring(product.price or 0)) or "Tap to purchase"
	UI.Components.TextLabel({ Text=priceText, Size=UDim2.new(1,0,0,24), Position=UDim2.fromOffset(0,76), Font=Enum.Font.GothamBold, TextSize=18, TextColor3=cardColor, TextXAlignment=Enum.TextXAlignment.Left, parent=info }):render()

	local owned = isGamepass and Core.DataManager.checkOwnership(product.id)
	local btnInst = UI.Components.Button({
		Text = owned and "Owned" or "Purchase",
		Size = UDim2.new(1,0,0,44), Position=UDim2.new(0,0,1,-44),
		BackgroundColor3 = owned and UI.Theme:get("success") or cardColor,
		TextColor3 = Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=16, cornerRadius=UDim.new(0,10),
		parent=info
	}):render()

	btnInst.Active = not owned

	btnInst.MouseButton1Click:Connect(function()
		if not btnInst or not btnInst.Parent then return end
		if isGamepass then
			if Core.DataManager.checkOwnership(product.id) then return end
			btnInst.Text, btnInst.Active = "Processing...", false
			self:promptPurchase(product, "gamepass", btnInst)
		else
			btnInst.Text, btnInst.Active = "Processing...", false
			self:promptPurchase(product, "cash", btnInst)
		end
	end)

	if isGamepass and product.hasToggle and owned then
		self:addToggleSwitch(product, imageContainer)
	end

	product.cardInstance = card
	product.purchaseButton = btnInst
end

function Shop:selectTab(tabId)
	if self.currentTab == tabId and self.pages[tabId] and self.pages[tabId].Visible then return end
	for id,tab in pairs(self.tabs) do
		local active = (id==tabId); local d=tab.data
		Core.Animation.tween(tab.button,{ BackgroundColor3 = active and Core.Utils.blend(d.color, Color3.new(1,1,1), 0.85) or UI.Theme:get("surface") }, Core.CONSTANTS.ANIM_FAST)
		local s=tab.button:FindFirstChildOfClass("UIStroke"); if s then s.Color = active and d.color or UI.Theme:get("stroke"); s.Thickness = active and 3 or 2 end
		tab.icon.ImageColor3 = active and d.color or UI.Theme:get("text")
		tab.label.TextColor3 = active and d.color or UI.Theme:get("text")
	end
	for id,page in pairs(self.pages) do
		page.Visible = (id==tabId)
		if page.Visible then page.Position=UDim2.fromOffset(0,20); Core.Animation.tween(page,{Position=UDim2.new()},Core.CONSTANTS.ANIM_BOUNCE,Enum.EasingStyle.Back) end
	end
	self.currentTab = tabId
	Core.SoundSystem.play("click")
end

function Shop:promptPurchase(product, kind, button)
	Core.State.purchasePending[product.id] = { product=product, type=kind, button=button }
	local ok,err
	if kind=="gamepass" then ok=pcall(function() MarketplaceService:PromptGamePassPurchase(Player, product.id) end)
	else ok=pcall(function() MarketplaceService:PromptProductPurchase(Player, product.id) end) end
	if not ok then
		if button and button.Parent then button.Text, button.Active = "Purchase", true end
		Core.State.purchasePending[product.id] = nil
		Core.SoundSystem.play("error"); warn("[SanrioShop] Prompt failed:", err)
	else
		task.delay(Core.CONSTANTS.PURCHASE_TIMEOUT,function()
			local p=Core.State.purchasePending[product.id]; if p and p.button and p.button.Parent then p.button.Text, p.button.Active = "Purchase", true end
			Core.State.purchasePending[product.id]=nil
		end)
	end
end

function Shop:refreshAllProducts()
	ownershipCache:clear()
	for _,gp in ipairs(Core.DataManager.products.gamepasses) do
		local owned=Core.DataManager.checkOwnership(gp.id)
		if gp.purchaseButton then gp.purchaseButton.Text=owned and "Owned" or "Purchase"; gp.purchaseButton.BackgroundColor3=owned and UI.Theme:get("success") or UI.Theme:get("kuromi"); gp.purchaseButton.Active=not owned end
	end
end

function Shop:open()
	if Core.State.isOpen or Core.State.isAnimating then return end
	Core.State.isAnimating=true; Core.State.isOpen=true
	Core.DataManager.refreshPrices(); self:refreshAllProducts(); self.gui.Enabled=true
	Core.Animation.tween(self.blur,{Size=24},Core.CONSTANTS.ANIM_MEDIUM)
	local size = Core.Utils.isMobile() and Core.CONSTANTS.PANEL_SIZE_MOBILE or Core.CONSTANTS.PANEL_SIZE
	self.mainPanel.Position=UDim2.fromScale(0.5,0.55); self.mainPanel.Size=UDim2.fromOffset(size.X*0.92,size.Y*0.92)
	Core.Animation.tween(self.mainPanel,{Position=UDim2.fromScale(0.5,0.5), Size=UDim2.fromOffset(size.X,size.Y)},Core.CONSTANTS.ANIM_BOUNCE,Enum.EasingStyle.Back)
	self:selectTab(self.currentTab or "Cash")
	Core.SoundSystem.play("open"); task.wait(Core.CONSTANTS.ANIM_BOUNCE); Core.State.isAnimating=false
end

function Shop:close()
	if not Core.State.isOpen or Core.State.isAnimating then return end
	Core.State.isAnimating=true; Core.State.isOpen=false
	Core.Animation.tween(self.blur,{Size=0},Core.CONSTANTS.ANIM_FAST)
	Core.Animation.tween(self.mainPanel,{Position=UDim2.fromScale(0.5,0.55), Size=UDim2.fromOffset(self.mainPanel.Size.X.Offset*0.92,self.mainPanel.Size.Y.Offset*0.92)},Core.CONSTANTS.ANIM_FAST)
	Core.SoundSystem.play("close"); task.wait(Core.CONSTANTS.ANIM_FAST); self.gui.Enabled=false; Core.State.isAnimating=false
end

function Shop:toggle() if Core.State.isOpen then self:close() else self:open() end end
function Shop:setupInputHandlers()
	UserInputService.InputBegan:Connect(function(i,gp)
		if gp then return end
		if i.KeyCode==Enum.KeyCode.M then self:toggle()
		elseif i.KeyCode==Enum.KeyCode.Escape and Core.State.isOpen then self:close() end
	end)
end

-- Boot
Core.SoundSystem.initialize()
local shop = Shop.new()

-- Purchase callbacks
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if player~=Player then return end
	local p=Core.State.purchasePending[passId]; if p and p.button and p.button.Parent then p.button.Text, p.button.Active = "Purchase", true end
	Core.State.purchasePending[passId]=nil
	if purchased then ownershipCache:clear(); shop:refreshAllProducts(); Core.SoundSystem.play("success") end
end)
MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, purchased)
	if player~=Player then return end
	local p=Core.State.purchasePending[productId]; if p and p.button and p.button.Parent then p.button.Text, p.button.Active = "Purchase", true end
	Core.State.purchasePending[productId]=nil
	if purchased then Core.SoundSystem.play("success"); if Remotes then local grant=Remotes:FindFirstChild("GrantProductCurrency"); if grant and grant:IsA("RemoteEvent") then grant:FireServer(productId) end end end
end)

-- Ensure toggle button persists across respawn
Player.CharacterAdded:Connect(function()
	task.wait(1)
	if not shop.toggleButton or not shop.toggleButton.Parent then shop:createToggleButton() end
end)

-- Periodic refresh while open
task.spawn(function() while true do task.wait(30); if Core.State.isOpen then shop:refreshAllProducts() end end end)

print("[SanrioShop] ✨ Polished & ready! No more overlap!")
return shop
