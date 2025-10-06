--[[
	DropperCore - Unified Dropper System
	Location: ReplicatedStorage/Modules/DropperCore
	
	Handles all dropper logic with per-dropper config.
	Features:
	- Collision groups for performance
	- Fade in/out effects
	- Single touch collection
	- Automatic cleanup
	- Customizable per dropper
]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Core = {}

-- Setup collision groups to prevent drop-drop and drop-player collisions
local function setupCollisionGroups(dropGroup, playerGroup)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(dropGroup)
		PhysicsService:RegisterCollisionGroup(playerGroup)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(dropGroup, playerGroup, false)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(dropGroup, dropGroup, false)
	end)
end

-- Make all player parts not collide with drops
local function setupPlayerCollision(playerGroup)
	local function setChar(char)
		task.wait(0.1)
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then
				pcall(function()
					p.CollisionGroup = playerGroup
				end)
			end
		end
	end
	
	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(setChar)
	end)
	
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			setChar(plr.Character)
		end
	end
end

-- Check if a part is a collector using multiple methods
local function isCollectorPart(hit, names, tags)
	if not (hit and hit:IsA("BasePart")) then return false end
	
	local n = string.lower(hit.Name)
	local pn = hit.Parent and string.lower(hit.Parent.Name) or ""
	
	-- Check against provided names
	for _, want in ipairs(names) do
		local w = string.lower(want)
		if n == w or pn == w or n:find("collect") or pn:find("collect") or n:find("sell") or pn:find("sell") then
			return true
		end
	end
	
	-- Check CollectionService tags
	for _, t in ipairs(tags) do
		if CollectionService:HasTag(hit, t) or (hit.Parent and CollectionService:HasTag(hit.Parent, t)) then
			return true
		end
	end
	
	-- Check attributes
	if hit:GetAttribute("Collector") == true then return true end
	if hit.Parent and hit.Parent:FindFirstChild("Collector") then return true end
	
	return false
end

-- Fade in effect
local function fadeIn(part, t, to)
	part.Transparency = 1
	local tw = TweenService:Create(
		part,
		TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = to }
	)
	tw:Play()
	return tw
end

-- Fade out effect
local function fadeOut(part, t)
	local tw = TweenService:Create(
		part,
		TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Transparency = 1 }
	)
	tw:Play()
	return tw
end

-- Main dropper logic
function Core.Run(config)
	-- REQUIRED:
	-- config.model: the dropper model containing a child "Drop" (BasePart) to spawn from
	-- config.partStorage: Folder where drops go
	
	-- Tuning with defaults:
	local DROP_RATE = config.dropRate or 0.5
	local CASH_VALUE = config.cashValue or 100
	local LIFETIME = config.lifetime or 120
	local SIZE = config.size or Vector3.new(1, 1, 1)
	local COLOR = config.color or BrickColor.new("Hot pink")
	local MATERIAL = typeof(config.material) == "EnumItem" and config.material or Enum.Material.SmoothPlastic
	local SHAPE = config.shape or Enum.PartType.Block
	local GROUP = config.dropGroup or "Drops"
	local PLAYER_GRP = config.playerGroup or "Players"
	local SPAWN_Y_OFF = config.spawnYOffset or -2.5 -- negative = lower
	local FADE_TIME = config.fadeTime or 0.3
	local DENSITY = config.density or 0.05
	local FRICTION = config.friction or 0.2
	local ELASTICITY = config.elasticity or 0.0
	local collectorNames = config.collectorNames or {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"}
	local collectorTags = config.collectorTags or {"Collector", "SellZone"}
	
	local dropPart = config.model:WaitForChild("Drop")
	local storage = config.partStorage
	
	setupCollisionGroups(GROUP, PLAYER_GRP)
	setupPlayerCollision(PLAYER_GRP)
	
	local count = 0
	
	while true do
		task.wait(DROP_RATE)
		count += 1
		
		-- Create part fast
		local part = Instance.new("Part")
		part.Name = (config.namePrefix or "KuromiDrop_") .. count
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
		
		-- Spawn slightly randomized & LOWER
		local ox = math.random(-2, 2) * 0.1
		local oz = math.random(-2, 2) * 0.1
		local pos = dropPart.Position + Vector3.new(-ox, SPAWN_Y_OFF, -oz)
		part.CFrame = CFrame.new(pos)
		
		-- Cash value
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = CASH_VALUE
		cash.Parent = part
		
		-- Effects (optional)
		local light = Instance.new("PointLight")
		light.Brightness = 1
		light.Range = 6
		light.Color = Color3.fromRGB(50, 255, 50)
		light.Parent = part
		
		-- Fade in
		fadeIn(part, FADE_TIME, 0)
		
		-- Add to world
		part.Parent = storage
		
		-- Pop effect
		local orig = part.Size
		part.Size = Vector3.new(0.1, 0.1, 0.1)
		TweenService:Create(
			part,
			TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = orig }
		):Play()
		
		-- Collect once
		local collected = false
		local touchConn
		touchConn = part.Touched:Connect(function(hit)
			if collected then return end
			if not isCollectorPart(hit, collectorNames, collectorTags) then return end
			
			collected = true
			part.Anchored = true
			part.CanTouch = false
			part.CanCollide = false
			
			-- Flash effect
			light.Brightness = 3
			TweenService:Create(
				light,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Brightness = 1 }
			):Play()
			
			fadeOut(part, FADE_TIME * 0.7)
			
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
