--[[
  Kuromi Dropper 1 — synchronized fade version
  ✅ Slightly smaller (0.9x), spawns lower (EXTRA_LOWER world-Y), upright (yaw only)
  ✅ Cash on EVERY BasePart, welded model, grippy low-bounce physics
  ✅ Fade-IN and fade-OUT are frame-synchronized (no half-fade, no stagger)
  ✅ Purple/black Kuromi theme
--]]

-- Services
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")
local PhysicsService    = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

-- References
task.wait(2)
local PartStorage   = workspace:WaitForChild("PartStorage")
local templateModel = ReplicatedStorage:WaitForChild("KuromiPL") -- CHANGED TO KUROMI
local dropPart      = script.Parent:WaitForChild("Drop")

-- =================== Config ===================
local DROP_RATE    = 1.2
local CASH_VALUE   = 10
local SCALE_FACTOR = 0.9      -- smaller
local EXTRA_LOWER  = 0.45     -- lower in world Y
local FADE_TIME    = 0.5      -- seconds
local LIFETIME     = nil

-- Collector identifiers (adjust if needed)
local COLLECTOR_NAMES = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" }
local COLLECTOR_TAGS  = { "Collector", "SellZone" }

-- Collision Groups
local DROP_GROUP   = "KuromiDrops1" -- CHANGED TO KUROMI
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(DROP_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, PLAYER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, DROP_GROUP,  false)
end)

-- Players -> collision group
local function setupPlayerCollision(char)
	task.wait(0.1)
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function() part.CollisionGroup = PLAYER_GROUP end)
		end
	end
end
Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(setupPlayerCollision) end)
for _, p in ipairs(Players:GetPlayers()) do if p.Character then setupPlayerCollision(p.Character) end end

-- Helpers
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

local function weldAllParts(model, primary)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= primary then
			local w = Instance.new("WeldConstraint")
			w.Part0 = primary; w.Part1 = d; w.Parent = primary
		end
	end
end

local function isCollectorPart(hit: BasePart)
	if not hit or not hit:IsA("BasePart") then return false end
	local n  = string.lower(hit.Name)
	local pn = hit.Parent and string.lower(hit.Parent.Name) or ""
	for _, want in ipairs(COLLECTOR_NAMES) do
		local w = string.lower(want)
		if n == w or pn == w or n:find("collect") or pn:find("collect") then return true end
	end
	for _, t in ipairs(COLLECTOR_TAGS) do
		if CollectionService:HasTag(hit, t) or (hit.Parent and CollectionService:HasTag(hit.Parent, t)) then
			return true
		end
	end
	if hit:GetAttribute("Collector") == true then return true end
	if hit.Parent and hit.Parent:FindFirstChild("Collector") then return true end
	return false
end

-- ===== Renderable gather + synchronized fade =====
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

local function syncFade(parts, decals, toTransparency: number, duration: number, useOriginal: boolean)
	-- Snapshot start transparencies
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

		-- Update EVERYTHING in the same frame
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

	-- Snap exactly to target at the end
	for i, bp in ipairs(parts) do if bp.Parent then bp.Transparency = targetP[i] end end
	for i, dd in ipairs(decals) do if dd.Parent then dd.Transparency = targetD[i] end end
end
-- ================================================

-- ========================================
-- MAIN LOOP
-- ========================================
local count = 0
while true do
	task.wait(DROP_RATE)
	count += 1

	local model = templateModel:Clone()
	model.Name = "Kuromi_" .. tostring(count) -- CHANGED TO KUROMI

	local primary = findPrimaryPart(model)
	if not primary then
		warn("KuromiPL has no BaseParts") -- CHANGED TO KUROMI
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
			pcall(function() p.CollisionGroup = DROP_GROUP end)
			p.CustomPhysicalProperties = PhysicalProperties.new(
				0.7,  -- density
				0.3,  -- friction
				0.05, -- elasticity
				1,    -- elasticityWeight
				1     -- frictionWeight
			)
			local cash = Instance.new("IntValue"); cash.Name = "Cash"; cash.Value = CASH_VALUE; cash.Parent = p
		end
	end

	-- spawn pose (upright yaw only) + lower Y
	local offsetX = math.random(-2, 2) * 0.1
	local offsetZ = math.random(-2, 2) * 0.1
	local ext      = model:GetExtentsSize()
	local sitY     = (ext.Y / 2) - 0.6
	local spawnPos = dropPart.Position + Vector3.new(-offsetX, -(sitY + EXTRA_LOWER), -offsetZ)
	local yawOnly  = CFrame.Angles(0, math.rad(-90), 0)
	local spawnCF  = CFrame.new(spawnPos) * yawOnly
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

	-- ===== synchronized FADE-IN =====
	local partsIn, decalsIn = gatherRenderable(model)
	for _, bp in ipairs(partsIn) do bp:SetAttribute("OrigT", bp.Transparency); bp.Transparency = 1 end
	for _, dd in ipairs(decalsIn) do dd:SetAttribute("OrigT", dd.Transparency); dd.Transparency = 1 end
	model.Parent = PartStorage
	syncFade(partsIn, decalsIn, 0, FADE_TIME, true) -- to originals, in sync

	-- Pop + flash (PURPLE KUROMI THEME)
	local originalSize = primary.Size
	primary.Size = Vector3.new(0.1, 0.1, 0.1)
	TweenService:Create(primary, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = originalSize}):Play()

	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 6
	light.Color = Color3.fromRGB(150, 80, 200) -- PURPLE GLOW
	light.Parent = primary
	TweenService:Create(light, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0.4}):Play()

	local ring = Instance.new("ParticleEmitter")
	ring.Texture = "rbxassetid://262979222"; ring.Rate = 0; ring.Speed = NumberRange.new(0)
	ring.Lifetime = NumberRange.new(0.3)
	ring.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 2)})
	ring.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 1)
	})
	ring.Color = ColorSequence.new(Color3.fromRGB(150, 80, 200)) -- PURPLE RING
	ring.Parent = primary
	ring:Emit(1); Debris:AddItem(ring, 1)

	-- ===== collect → synchronized FADE-OUT =====
	local collected = false
	local touchConn

	local function fadeOutAndDestroy()
		-- freeze & disable
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true; d.CanCollide = false; d.CanTouch = false
			elseif d:IsA("ParticleEmitter") then
				d.Enabled = false; d:Clear()
			end
		end
		-- RESCAN so every MeshPart (e.g., head) is included
		local partsOut, decalsOut = gatherRenderable(model)
		syncFade(partsOut, decalsOut, 1, FADE_TIME, false) -- to 1, in sync

		if touchConn then touchConn:Disconnect() end
		if model and model.Parent then model:Destroy() end
	end

	touchConn = primary.Touched:Connect(function(hit)
		if collected then return end
		if isCollectorPart(hit) then
			collected = true
			fadeOutAndDestroy()
		end
	end)
end
