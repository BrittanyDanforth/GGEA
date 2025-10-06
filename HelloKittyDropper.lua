--[[
	Hello Kitty Dropper 1 - Model Based
	Uses HelloKittyPL model from ReplicatedStorage
	✅ True-to-model scale (slightly smaller)
	✅ Perfect conveyor height (lowered a bit)
	✅ No mid-body collision float
	✅ Less wobble on landing (temp AlignOrientation + higher friction)
	✅ Uniform fade-in AND fade-out (single trigger, no stacking)
	✅ Fixed spawn height (spawns lower)
	✅ Fixed fade-out synchronization (all parts fade together)
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local templateModel = ReplicatedStorage:WaitForChild("HelloKittyPL")
local dropPart = script.Parent:WaitForChild("Drop")

-- =================== Config ===================
local DROP_RATE = 1.2
local CASH_VALUE = 10
local SCALE_FACTOR = 0.9   -- ⬅️ a bit smaller than 1x
local EXTRA_LOWER = 0.5    -- ⬅️ INCREASED: spawn much lower (was 0.15)
local FADE_TIME = 0.5      -- in/out duration
local LIFETIME = nil

-- Collector detection (use any that matches your game)
local COLLECTOR_NAMES = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" }
local COLLECTOR_TAGS  = { "Collector", "SellZone" }
-- =================================================

-- Collision Groups
local DROP_GROUP = "HelloKittyOrbs"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(DROP_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, PLAYER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, DROP_GROUP, false)
end)

local function setupPlayerCollision(character)
	task.wait(0.1)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function() part.CollisionGroup = PLAYER_GROUP end)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(setupPlayerCollision)
end)
for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then setupPlayerCollision(player.Character) end
end

local function findPrimaryPart(model)
	if model.PrimaryPart then return model.PrimaryPart end
	local largest, vol = nil, 0
	for _, c in ipairs(model:GetDescendants()) do
		if c:IsA("BasePart") then
			local v = c.Size.X * c.Size.Y * c.Size.Z
			if v > vol then vol = v largest = c end
		end
	end
	return largest
end

local function weldAllParts(model, primary)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= primary then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = primary
			weld.Part1 = d
			weld.Parent = primary
		end
	end
end

local function isCollectorPart(hit: BasePart)
	if not hit or not hit:IsA("BasePart") then return false end
	-- name or parent's name
	local n = string.lower(hit.Name)
	local pn = hit.Parent and string.lower(hit.Parent.Name) or ""
	for _, want in ipairs(COLLECTOR_NAMES) do
		local w = string.lower(want)
		if n == w or pn == w or string.find(n, "collect") or string.find(pn, "collect") then
			return true
		end
	end
	-- tags
	for _, t in ipairs(COLLECTOR_TAGS) do
		if CollectionService:HasTag(hit, t) or (hit.Parent and CollectionService:HasTag(hit.Parent, t)) then
			return true
		end
	end
	-- attribute or BoolValue
	if hit:GetAttribute("Collector") == true then return true end
	if hit.Parent and hit.Parent:FindFirstChild("Collector") then return true end
	return false
end

-- ========================================
-- DROP LOOP
-- ========================================
local count = 0
while true do
	task.wait(DROP_RATE)
	count += 1

	local newDrop = templateModel:Clone()
	newDrop.Name = "HelloKitty_" .. count
	local primaryPart = findPrimaryPart(newDrop)
	if not primaryPart then
		warn("HelloKittyPL has no BaseParts")
		newDrop:Destroy()
		continue
	end

	for _, w in ipairs(newDrop:GetDescendants()) do
		if w:IsA("WeldConstraint") or w:IsA("Motor6D") then w:Destroy() end
	end

	local pivot = newDrop:GetPivot()
	newDrop:ScaleTo(SCALE_FACTOR)  -- ⬅️ smaller
	newDrop:PivotTo(pivot)
	weldAllParts(newDrop, primaryPart)

	-- Physics/material: grippier, no bounce
	for _, p in ipairs(newDrop:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanTouch  = true
			p.CanQuery  = true
			pcall(function() p.CollisionGroup = DROP_GROUP end)
			p.CustomPhysicalProperties = PhysicalProperties.new(
				0.4,  -- density
				0.85, -- friction
				0.00, -- elasticity
				2.0,  -- frictionWeight
				1.0   -- elasticityWeight
			)
			local cash = Instance.new("IntValue"); cash.Name = "Cash"; cash.Value = CASH_VALUE; cash.Parent = p
		end
	end

	-- Spawn pose/height
	local offsetX = math.random(-2, 2) * 0.1
	local offsetZ = math.random(-2, 2) * 0.1
	local size = newDrop:GetExtentsSize()
	local heightOffset = (size.Y / 2) - 0.6

	-- ⬇️ spawn a bit lower by subtracting EXTRA_LOWER on Y
	local spawnCFrame =
		(dropPart.CFrame + Vector3.new(-offsetX, -heightOffset - EXTRA_LOWER, -offsetZ))
		* CFrame.Angles(math.rad(180), math.rad(-90), 0)
	newDrop:PivotTo(spawnCFrame)

	-- TEMP UPRIGHT DAMPER (short)
	do
		local att = Instance.new("Attachment"); att.Parent = primaryPart
		local ao = Instance.new("AlignOrientation")
		ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
		ao.Attachment0 = att
		ao.Responsiveness = 30
		ao.RigidityEnabled = true
		ao.CFrame = spawnCFrame
		ao.Parent = primaryPart
		Debris:AddItem(ao, 0.5)
		Debris:AddItem(att, 0.5)
	end

	-- gentle drop
	primaryPart.AssemblyLinearVelocity = Vector3.new(0, -8, 0)
	primaryPart:SetAttribute("SpawnTime", tick())

	-- ====== UNIFORM FADE-IN (FIXED: properly collect all parts/decals) ======
	local fadeParts, fadeDecals, activeTweens = {}, {}, {}

	-- Store ALL parts and decals in one clean loop
	for _, d in ipairs(newDrop:GetDescendants()) do
		if d:IsA("BasePart") then
			d:SetAttribute("OrigT", d.Transparency)
			table.insert(fadeParts, d)
			d.Transparency = 1
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d:SetAttribute("OrigT", d.Transparency)
			table.insert(fadeDecals, d)  -- ⬅️ FIXED: use correct table name
			d.Transparency = 1
		end
	end

	newDrop.Parent = PartStorage

	local light = Instance.new("PointLight")
	light.Brightness = 1
	light.Range = 8
	light.Color = Color3.fromRGB(255, 150, 200)
	light.Parent = primaryPart

	-- Fade in all parts
	for _, bp in ipairs(fadeParts) do
		local t = TweenService:Create(bp, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Transparency = bp:GetAttribute("OrigT") or 0 })
		activeTweens[#activeTweens+1] = t; t:Play()
	end
	-- Fade in all decals
	for _, dd in ipairs(fadeDecals) do
		local t = TweenService:Create(dd, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Transparency = dd:GetAttribute("OrigT") or 0 })
		activeTweens[#activeTweens+1] = t; t:Play()
	end
	-- ========================================================

	-- Single, clean fade-out on collect (one connection, one debounce)
	local collected = false
	local touchConn

	local function fadeOutAndDestroy()
		if collected then return end  -- ⬅️ ADDED: extra safety check
		collected = true
		
		-- Cancel any active fade-in tweens to avoid conflicts
		for _, tw in ipairs(activeTweens) do
			pcall(function() tw:Cancel() end)
		end
		
		-- FIXED: Fade out ALL parts uniformly at the same time
		local fadeOutTweens = {}
		for _, bp in ipairs(fadeParts) do
			local tween = TweenService:Create(bp, 
				TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Transparency = 1 }
			)
			table.insert(fadeOutTweens, tween)
			tween:Play()
		end
		for _, dd in ipairs(fadeDecals) do
			local tween = TweenService:Create(dd, 
				TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Transparency = 1 }
			)
			table.insert(fadeOutTweens, tween)
			tween:Play()
		end

		-- Disconnect listener and hard-destroy after fade completes
		if touchConn then touchConn:Disconnect() end
		task.delay(FADE_TIME + 0.05, function()
			if newDrop and newDrop.Parent then newDrop:Destroy() end
		end)
		-- Belt-and-suspenders cleanup
		Debris:AddItem(newDrop, FADE_TIME + 1.0)
	end

	touchConn = primaryPart.Touched:Connect(function(hit)
		if collected then return end
		if isCollectorPart(hit) then
			fadeOutAndDestroy()
		end
	end)

	-- Pop animation (kept)
	local originalSize = primaryPart.Size
	primaryPart.Size = Vector3.new(0.1, 0.1, 0.1)
	TweenService:Create(primaryPart,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = originalSize}
	):Play()

	-- Flash (kept)
	light.Brightness = 3
	TweenService:Create(light,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 1}
	):Play()

	-- Ring (kept)
	local ring = Instance.new("ParticleEmitter")
	ring.Texture = "rbxassetid://262979222"
	ring.Rate = 0
	ring.Speed = NumberRange.new(0)
	ring.Lifetime = NumberRange.new(0.3)
	ring.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 3)
	})
	ring.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 1)
	})
	ring.Color = ColorSequence.new(Color3.fromRGB(255, 150, 200))
	ring.Parent = primaryPart
	ring:Emit(1)
	Debris:AddItem(ring, 1)
end
