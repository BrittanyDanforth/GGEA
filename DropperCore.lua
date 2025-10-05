-- DropperCore.lua
-- Put in: ReplicatedStorage → Modules → DropperCore
-- Ultra-optimized, zero-lag dropper engine for all tycoons

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Core = {}

-- =================== COLLISION SETUP ===================
local function setupCollisionGroups(dropGroup, playerGroup)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(dropGroup)
		PhysicsService:RegisterCollisionGroup(playerGroup)
	end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(dropGroup, playerGroup, false) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(dropGroup, dropGroup, false) end)
end

local function setupPlayerCollision(playerGroup)
	local function setChar(char)
		task.wait(0.1)
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then
				pcall(function() p.CollisionGroup = playerGroup end)
			end
		end
	end
	Players.PlayerAdded:Connect(function(plr) plr.CharacterAdded:Connect(setChar) end)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then setChar(plr.Character) end
	end
end

-- =================== COLLECTOR DETECTION ===================
local function isCollectorPart(hit, names, tags)
	if not (hit and hit:IsA("BasePart")) then return false end
	local n = string.lower(hit.Name)
	local pn = hit.Parent and string.lower(hit.Parent.Name) or ""
	for _, want in ipairs(names) do
		local w = string.lower(want)
		if n == w or pn == w or n:find("collect") or pn:find("collect") or n:find("sell") or pn:find("sell") then
			return true
		end
	end
	for _, t in ipairs(tags) do
		if CollectionService:HasTag(hit, t) or (hit.Parent and CollectionService:HasTag(hit.Parent, t)) then
			return true
		end
	end
	if hit:GetAttribute("Collector") == true then return true end
	if hit.Parent and hit.Parent:FindFirstChild("Collector") then return true end
	return false
end

-- =================== FADE EFFECTS ===================
local function fadeIn(part, t, targetTransparency)
	part.Transparency = 1
	local tw = TweenService:Create(part, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = targetTransparency})
	tw:Play()
	return tw
end

local function fadeOut(part, t)
	local tw = TweenService:Create(part, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1})
	tw:Play()
	return tw
end

-- =================== MAIN DROPPER ENGINE ===================
function Core.Run(config)
	-- Required params
	local model = config.model
	local storage = config.partStorage
	
	-- Tuning
	local DROP_RATE = config.dropRate or 0.5
	local CASH_VALUE = config.cashValue or 100
	local LIFETIME = config.lifetime or 120
	local SIZE = config.size or Vector3.new(1, 1, 1)
	local COLOR = config.color or BrickColor.new("Hot pink")
	local MATERIAL = typeof(config.material) == "EnumItem" and config.material or Enum.Material.SmoothPlastic
	local SHAPE = config.shape or Enum.PartType.Block
	local GROUP = config.dropGroup or "Drops"
	local PLAYER_GRP = config.playerGroup or "Players"
	local SPAWN_Y_OFF = config.spawnYOffset or -2.5
	local FADE_TIME = config.fadeTime or 0.3
	local DENSITY = config.density or 0.05
	local FRICTION = config.friction or 0.2
	local ELASTICITY = config.elasticity or 0.0
	local NAME_PREFIX = config.namePrefix or "Drop_"
	local LIGHT_COLOR = config.lightColor or Color3.fromRGB(50, 255, 50)
	local LIGHT_RANGE = config.lightRange or 6
	local LIGHT_BRIGHTNESS = config.lightBrightness or 1
	
	local collectorNames = config.collectorNames or {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"}
	local collectorTags = config.collectorTags or {"Collector", "SellZone"}
	
	local dropPart = model:WaitForChild("Drop")
	
	-- Setup collision once
	setupCollisionGroups(GROUP, PLAYER_GRP)
	setupPlayerCollision(PLAYER_GRP)
	
	local count = 0
	while true do
		task.wait(DROP_RATE)
		count += 1
		
		-- Create part (fast, no overhead)
		local part = Instance.new("Part")
		part.Name = NAME_PREFIX .. count
		part.Size = SIZE
		part.BrickColor = COLOR
		part.Material = MATERIAL
		part.Shape = SHAPE
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = false
		part.CanQuery = true
		part.CanTouch = true
		part.CollisionGroup = GROUP
		part.CustomPhysicalProperties = PhysicalProperties.new(DENSITY, FRICTION, ELASTICITY, 0.5, 0.5)
		
		-- Spawn position (randomized & lower)
		local ox = math.random(-2, 2) * 0.1
		local oz = math.random(-2, 2) * 0.1
		local pos = dropPart.Position + Vector3.new(-ox, SPAWN_Y_OFF, -oz)
		part.CFrame = CFrame.new(pos)
		
		-- Cash value
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = CASH_VALUE
		cash.Parent = part
		
		-- Light (optional but nice)
		local light = Instance.new("PointLight")
		light.Brightness = LIGHT_BRIGHTNESS
		light.Range = LIGHT_RANGE
		light.Color = LIGHT_COLOR
		light.Parent = part
		
		-- Parent to world BEFORE fading
		part.Parent = storage
		
		-- Fade in
		fadeIn(part, FADE_TIME, 0)
		
		-- Pop animation
		local originalSize = part.Size
		part.Size = Vector3.new(0.1, 0.1, 0.1)
		TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = originalSize}):Play()
		
		-- Collection (SINGLE connection, clean debounce)
		local collected = false
		local touchConn
		
		touchConn = part.Touched:Connect(function(hit)
			if collected then return end
			if not isCollectorPart(hit, collectorNames, collectorTags) then return end
			
			collected = true
			
			-- Disable physics immediately
			part.Anchored = true
			part.CanTouch = false
			part.CanCollide = false
			
			-- Flash effect
			if light then
				light.Brightness = 3
				TweenService:Create(light, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Brightness = 1}):Play()
			end
			
			-- Fade out
			fadeOut(part, FADE_TIME * 0.7)
			
			-- Cleanup
			task.delay(FADE_TIME + 0.05, function()
				if touchConn then touchConn:Disconnect() end
				if part and part.Parent then part:Destroy() end
			end)
		end)
		
		-- Lifetime cleanup
		Debris:AddItem(part, LIFETIME)
	end
end

return Core
