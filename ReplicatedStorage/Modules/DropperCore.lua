-- ReplicatedStorage/Modules/DropperCore
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Core = {}

-- Utility: find a reasonable primary part in a model
local function findPrimaryPart(model)
    if model.PrimaryPart then return model.PrimaryPart end
    local best, vol = nil, 0
    for _, c in ipairs(model:GetDescendants()) do
        if c:IsA("BasePart") then
            local v = c.Size.X * c.Size.Y * c.Size.Z
            if v > vol then vol = v; best = c end
        end
    end
    return best
end

-- Utility: weld all baseparts to a primary for stable physics
local function weldAllParts(model, primary)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and d ~= primary then
            local w = Instance.new("WeldConstraint")
            w.Part0 = primary
            w.Part1 = d
            w.Parent = primary
        end
    end
end

-- Utility: collect renderables for synchronized fades
local function gatherRenderable(model)
    local parts, decals = {}, {}
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            parts[#parts+1] = d
        elseif d:IsA("Decal") or d:IsA("Texture") then
            decals[#decals+1] = d
        end
    end
    return parts, decals
end

-- Exact frame-synchronized fade for multiple parts/decals
local RunService = game:GetService("RunService")
local function syncFade(parts, decals, toTransparency, duration, useOriginal)
    local startP, startD, targetP, targetD = {}, {}, {}, {}
    for i, bp in ipairs(parts) do
        startP[i]  = bp.Transparency
        targetP[i] = useOriginal and (bp:GetAttribute("OrigT") or 0) or toTransparency
    end
    for i, dd in ipairs(decals) do
        startD[i]  = dd.Transparency
        targetD[i] = useOriginal and (dd:GetAttribute("OrigT") or 0) or toTransparency
    end
    local t = 0
    while t < duration do
        local dt = RunService.Heartbeat:Wait()
        t += dt
        local alpha = math.clamp(t / duration, 0, 1)
        for i, bp in ipairs(parts) do
            if bp.Parent then
                bp.Transparency = startP[i] + (targetP[i] - startP[i]) * alpha
            end
        end
        for i, dd in ipairs(decals) do
            if dd.Parent then
                dd.Transparency = startD[i] + (targetD[i] - startD[i]) * alpha
            end
        end
    end
    for i, bp in ipairs(parts) do if bp.Parent then bp.Transparency = targetP[i] end end
    for i, dd in ipairs(decals) do if dd.Parent then dd.Transparency = targetD[i] end end
end

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

-- Run a model-spawning dropper with synchronized multi-part fades
function Core.RunModel(config)
    -- Required refs
    local dropModel = config.model
    local dropPart = dropModel:WaitForChild("Drop")
    local storage = config.partStorage
    local template = config.templateModel
    assert(template, "RunModel requires config.templateModel (a Model in ReplicatedStorage)")

    -- Tuning
    local DROP_RATE = config.dropRate or 1.2
    local CASH_VALUE = config.cashValue or 10
    local SCALE_FACTOR = config.scaleFactor or 0.9
    local EXTRA_LOWER = config.extraLower or 0.45
    local FADE_TIME = config.fadeTime or 0.5
    local LIFETIME = config.lifetime -- may be nil to disable Debris
    local GROUP = config.dropGroup or "HelloKittyDrops"
    local PLAYER_GRP = config.playerGroup or "Players"
    local DENSITY = config.density or 0.7
    local FRICTION = config.friction or 0.3
    local ELASTICITY = config.elasticity or 0.05
    local yawDegrees = config.yawDegrees or -90
    local namePrefix = config.namePrefix or "HelloKitty_"

    setupCollisionGroups(GROUP, PLAYER_GRP)
    setupPlayerCollision(PLAYER_GRP)

    local count = 0
    while true do
        task.wait(DROP_RATE)
        count += 1

        local model = template:Clone()
        model.Name = namePrefix .. tostring(count)

        local primary = findPrimaryPart(model)
        if not primary then
            warn("[DropperCore] templateModel has no BaseParts")
            model:Destroy()
            continue
        end

        -- remove pre-welds that might fight ours
        for _, j in ipairs(model:GetDescendants()) do
            if j:IsA("WeldConstraint") or j:IsA("Motor6D") then j:Destroy() end
        end

        -- scale & weld
        local pivot = model:GetPivot()
        model:ScaleTo(SCALE_FACTOR)
        model:PivotTo(pivot)
        weldAllParts(model, primary)

        -- physics + cash
        for _, p in ipairs(model:GetDescendants()) do
            if p:IsA("BasePart") then
                p.Anchored = false; p.CanTouch = true; p.CanQuery = true
                pcall(function() p.CollisionGroup = GROUP end)
                p.CustomPhysicalProperties = PhysicalProperties.new(DENSITY, FRICTION, ELASTICITY, 1, 1)
                local cash = Instance.new("IntValue"); cash.Name = "Cash"; cash.Value = CASH_VALUE; cash.Parent = p
            end
        end

        -- spawn pose (upright yaw only) + lower Y
        local offsetX = math.random(-2, 2) * 0.1
        local offsetZ = math.random(-2, 2) * 0.1
        local ext = model:GetExtentsSize()
        local sitY = (ext.Y / 2) - 0.6
        local spawnPos = dropPart.Position + Vector3.new(-offsetX, -(sitY + EXTRA_LOWER), -offsetZ)
        local yawOnly = CFrame.Angles(0, math.rad(yawDegrees), 0)
        local spawnCF = CFrame.new(spawnPos) * yawOnly
        model:PivotTo(spawnCF)

        -- short upright damper
        do
            local att = Instance.new("Attachment"); att.Parent = primary
            local ao  = Instance.new("AlignOrientation")
            ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
            ao.Attachment0 = att
            ao.Responsiveness = 30
            ao.RigidityEnabled = true
            ao.CFrame = yawOnly
            ao.Parent = primary
            Debris:AddItem(ao, 0.5); Debris:AddItem(att, 0.5)
        end

        -- gentle drop
        primary.AssemblyLinearVelocity = Vector3.new(0, -8, 0)
        primary:SetAttribute("SpawnTime", tick())

        -- synchronized FADE-IN
        local partsIn, decalsIn = gatherRenderable(model)
        for _, bp in ipairs(partsIn) do bp:SetAttribute("OrigT", bp.Transparency); bp.Transparency = 1 end
        for _, dd in ipairs(decalsIn) do dd:SetAttribute("OrigT", dd.Transparency); dd.Transparency = 1 end
        model.Parent = storage
        syncFade(partsIn, decalsIn, 0, FADE_TIME, true)

        -- pop/flash
        local originalSize = primary.Size
        primary.Size = Vector3.new(0.1, 0.1, 0.1)
        TweenService:Create(primary, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = originalSize }):Play()

        local light = Instance.new("PointLight")
        light.Brightness = 1.2; light.Range = 6; light.Color = Color3.new(1,1,1); light.Parent = primary
        TweenService:Create(light, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0.4 }):Play()

        -- collect → synchronized FADE-OUT
        local collected = false
        local function fadeOutAndDestroy()
            for _, d in ipairs(model:GetDescendants()) do
                if d:IsA("BasePart") then
                    d.Anchored = true; d.CanCollide = false; d.CanTouch = false
                elseif d:IsA("ParticleEmitter") then
                    d.Enabled = false; d:Clear()
                end
            end
            local partsOut, decalsOut = gatherRenderable(model)
            syncFade(partsOut, decalsOut, 1, FADE_TIME, false)
            if model and model.Parent then model:Destroy() end
        end

        local touchConn
        touchConn = primary.Touched:Connect(function(hit)
            if collected then return end
            if not isCollectorPart(hit, config.collectorNames or {"Collector","CollectorZone","Receiver","Sell","SellPad"}, config.collectorTags or {"Collector","SellZone"}) then return end
            collected = true
            if touchConn then touchConn:Disconnect() end
            fadeOutAndDestroy()
        end)

        if LIFETIME and type(LIFETIME) == "number" and LIFETIME > 0 then
            Debris:AddItem(model, LIFETIME)
        end
    end
end

return Core
