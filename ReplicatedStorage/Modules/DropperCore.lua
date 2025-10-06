-- ReplicatedStorage/Modules/DropperCore
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Core = {}

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
	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(setChar)
	end)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then setChar(plr.Character) end
	end
end

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

local function fadeIn(part, t, to)
	part.Transparency = 1
	local tw = TweenService:Create(part, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = to })
	tw:Play()
	return tw
end

local function fadeOut(part, t)
	local tw = TweenService:Create(part, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
	tw:Play()
	return tw
end

function Core.Run(config)
	-- REQUIRED
	local dropModel = config.model
	local dropPart = dropModel:WaitForChild("Drop")
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
	local collectorNames = config.collectorNames or { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" }
	local collectorTags = config.collectorTags or { "Collector", "SellZone" }
	local namePrefix = config.namePrefix or "KuromiDrop_"

	setupCollisionGroups(GROUP, PLAYER_GRP)
	setupPlayerCollision(PLAYER_GRP)

	local count = 0
	while true do
		task.wait(DROP_RATE)
		count += 1

		local part = Instance.new("Part")
		part.Name = namePrefix .. count
		part.Size = SIZE
		part.BrickColor = COLOR
		part.Material = MATERIAL
		part.Shape = SHAPE
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = false
		part.CanQuery = true
		part.CanTouch = true
		pcall(function() part.CollisionGroup = GROUP end)
		part.CustomPhysicalProperties = PhysicalProperties.new(DENSITY, FRICTION, ELASTICITY, 0.5, 0.5)

		local ox = math.random(-2, 2) * 0.1
		local oz = math.random(-2, 2) * 0.1
		local pos = dropPart.Position + Vector3.new(-ox, SPAWN_Y_OFF, -oz)
		part.CFrame = CFrame.new(pos)

		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = CASH_VALUE
		cash.Parent = part

		local light = Instance.new("PointLight")
		light.Brightness = 1
		light.Range = 6
		light.Color = Color3.fromRGB(50, 255, 50)
		light.Parent = part

		fadeIn(part, FADE_TIME, 0)
		part.Parent = storage

		local orig = part.Size
		part.Size = Vector3.new(0.1, 0.1, 0.1)
		TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = orig }):Play()

		local collected = false
		local touchConn
		touchConn = part.Touched:Connect(function(hit)
			if collected then return end
			if not isCollectorPart(hit, collectorNames, collectorTags) then return end
			collected = true
			part.Anchored = true
			part.CanTouch = false
			part.CanCollide = false
			light.Brightness = 3
			TweenService:Create(light, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 1 }):Play()
			fadeOut(part, FADE_TIME * 0.7)
			task.delay(FADE_TIME + 0.05, function()
				if touchConn then touchConn:Disconnect() end
				if part and part.Parent then part:Destroy() end
			end)
		end)

		Debris:AddItem(part, LIFETIME)
	end
end

return Core
