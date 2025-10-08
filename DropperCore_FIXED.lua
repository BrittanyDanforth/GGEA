--!strict
-- DropperCore v4.2 — FIXED: Pooling Issue + Collection Issues + FULL DEBUG

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Core = {}

-- =========================
-- small utils
-- =========================
local function findPrimaryPart(model: Model): BasePart?
	if model.PrimaryPart then return model.PrimaryPart end
	local best: BasePart? = nil
	local vol = -1
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > vol then vol = v; best = d end
		end
	end
	return best
end

local function weldAllParts(model: Model, primary: BasePart)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= primary then
			local w = Instance.new("WeldConstraint")
			w.Part0 = primary
			w.Part1 = d
			w.Parent = primary
		end
	end
end

local function setupCollisionGroups(dropGroup: string, playerGroup: string)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(dropGroup)
		PhysicsService:RegisterCollisionGroup(playerGroup)
	end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(dropGroup, playerGroup, false) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(dropGroup, dropGroup,  false) end)
end

local function tagCharacterPartsAsPlayerGroup(playerGroup: string)
	local function setChar(char: Model)
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

local function isCollectorPart(hit: Instance?, names: {string}, tags: {string}): boolean
	local bp = hit
	if not (bp and bp:IsA("BasePart")) then return false end
	local n = string.lower(bp.Name)
	local pn = bp.Parent and string.lower(bp.Parent.Name) or ""
	for _, want in ipairs(names) do
		local w = string.lower(want)
		if n == w or pn == w then return true end
	end
	if n:find("collect") or pn:find("collect") or n:find("sell") or pn:find("sell") then
		return true
	end
	for _, t in ipairs(tags) do
		if CollectionService:HasTag(bp, t) or (bp.Parent and CollectionService:HasTag(bp.Parent, t)) then
			return true
		end
	end
	if bp:GetAttribute("Collector") == true then return true end
	if bp.Parent and bp.Parent:FindFirstChild("Collector") then return true end
	return false
end

-- =========================
-- template prep (weld & scale once)
-- =========================
local preparedTemplates: { [Model]: Model } = setmetatable({}, { __mode = "k" })
local function prepareTemplate(src: Model, scale: number): Model
	local cached = preparedTemplates[src]
	if cached and cached.Parent == nil then
		return cached
	end
	local m = src:Clone()
	local primary = findPrimaryPart(m) or m:FindFirstChildWhichIsA("BasePart", true)
	if primary then m.PrimaryPart = primary end
	for _, j in ipairs(m:GetDescendants()) do
		if j:IsA("WeldConstraint") or j:IsA("Motor6D") then j:Destroy() end
	end
	if scale ~= 1 then
		local pivot = m:GetPivot()
		m:ScaleTo(scale)
		m:PivotTo(pivot)
	end
	if primary then weldAllParts(m, primary) end
	m.Parent = nil
	preparedTemplates[src] = m
	return m
end

-- =========================
-- tiny object pool
-- =========================
type PoolItem = {
	model: Model,
	primary: BasePart,
	parts: {BasePart},
	decals: {Instance},
	conns: { RBXScriptConnection }
}

local function collectRenderable(model: Model): ({BasePart}, {Instance})
	local parts, decals = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		elseif d:IsA("Decal") or d:IsA("Texture") then
			table.insert(decals, d)
		end
	end
	return parts, decals
end

local function buildItemFromClone(
	clone: Model,
	dropGroup: string,
	density: number, friction: number, elasticity: number,
	cashValue: number, cashOn: "primary" | "all"
): PoolItem
	local primary = findPrimaryPart(clone) :: BasePart
	local parts, decals = collectRenderable(clone)
	for _, p in ipairs(parts) do
		p.Anchored = false
		p.CanTouch = true
		p.CanQuery = true
		p.CanCollide = true
		pcall(function() p.CollisionGroup = dropGroup end)
		p.CustomPhysicalProperties = PhysicalProperties.new(density, friction, elasticity, 1, 1)
	end
	-- cash tagging
	if cashOn == "primary" then
		local v = Instance.new("IntValue")
		v.Name = "Cash"; v.Value = cashValue; v.Parent = primary
	else
		for _, p in ipairs(parts) do
			local v = Instance.new("IntValue")
			v.Name = "Cash"; v.Value = cashValue; v.Parent = p
		end
	end
	return { model = clone, primary = primary, parts = parts, decals = decals, conns = {} }
end

local function hide(item: PoolItem)
	for _, p in ipairs(item.parts) do p.Transparency = 1 end
	for _, d in ipairs(item.decals) do
		if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
	end
	item.model.Parent = nil
end

local function setTransparency(item: PoolItem, tVal: number)
	for _, p in ipairs(item.parts) do p.Transparency = tVal end
	for _, d in ipairs(item.decals) do
		if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = tVal end
	end
end

local function tweenSubset(item: PoolItem, to: number, duration: number, subsetMax: number, easeIn: boolean, onDone: (() -> ())?)
	local ti = TweenInfo.new(duration, Enum.EasingStyle.Quad, easeIn and Enum.EasingDirection.In or Enum.EasingDirection.Out)
	local n = 0
	for _, p in ipairs(item.parts) do
		if n < subsetMax then
			local tw = TweenService:Create(p, ti, {Transparency = to})
			tw:Play(); n += 1
		else
			p.Transparency = to
		end
	end
	for _, d in ipairs(item.decals) do
		if n < subsetMax and (d:IsA("Decal") or d:IsA("Texture")) then
			local tw = TweenService:Create(d, ti, {Transparency = to})
			tw:Play(); n += 1
		else
			if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = to end
		end
	end
	if onDone then task.delay(duration + 0.02, onDone) end
end

local Pool = {}
Pool.__index = Pool

function Pool.new(baseTemplate: Model, dropGroup: string, density: number, friction: number, elasticity: number, cashValue: number, cashOn: "primary" | "all", prewarm: number)
	local self = setmetatable({}, Pool)
	self._base = baseTemplate
	self._dropGroup = dropGroup
	self._density = density
	self._friction = friction
	self._elasticity = elasticity
	self._cashValue = cashValue
	self._cashOn = cashOn
	self._items = {} :: {PoolItem}
	self._busy = {}  :: { [Model]: boolean }
	self._prewarm = math.max(prewarm or 4, 0)

	for _ = 1, self._prewarm do
		local c = self._base:Clone()
		local item = buildItemFromClone(c, dropGroup, density, friction, elasticity, cashValue, cashOn)
		hide(item)
		table.insert(self._items, item)
	end
	return self
end

function Pool:acquire(): PoolItem
	local it = table.remove(self._items)
	if it then
		self._busy[it.model] = true
		return it
	end
	local c = self._base:Clone()
	local item = buildItemFromClone(c, self._dropGroup, self._density, self._friction, self._elasticity, self._cashValue, self._cashOn)
	self._busy[item.model] = true
	return item
end

function Pool:release(item: PoolItem)
	-- CRITICAL FIX: Ensure model is properly cleaned up before releasing
	if item.model.Parent then
		item.model.Parent = nil
	end

	-- Disconnect all connections
	for _, conn in ipairs(item.conns) do
		if conn.Connected then conn:Disconnect() end
	end
	table.clear(item.conns)

	-- CRITICAL FIX: Wait a frame to ensure cleanup is complete
	task.wait()

	-- Re-create Cash values (they get removed when collected)
	if self._cashOn == "primary" then
		local existing = item.primary:FindFirstChild("Cash")
		if not existing then
			local v = Instance.new("IntValue")
			v.Name = "Cash"
			v.Value = self._cashValue
			v.Parent = item.primary
		else
			existing.Value = self._cashValue
		end
	else
		for _, p in ipairs(item.parts) do
			local existing = p:FindFirstChild("Cash")
			if not existing then
				local v = Instance.new("IntValue")
				v.Name = "Cash"
				v.Value = self._cashValue
				v.Parent = p
			else
				existing.Value = self._cashValue
			end
		end
	end

	-- Re-weld all parts to primary (in case welds broke)
	for _, p in ipairs(item.parts) do
		if p ~= item.primary then
			-- Check if weld exists, if not create it
			local hasWeld = false
			for _, child in ipairs(item.primary:GetChildren()) do
				if child:IsA("WeldConstraint") and (child.Part0 == p or child.Part1 == p) then
					hasWeld = true
					break
				end
			end
			if not hasWeld then
				local w = Instance.new("WeldConstraint")
				w.Part0 = item.primary
				w.Part1 = p
				w.Parent = item.primary
			end
		end
	end

	-- Reset ALL parts properly
	for _, p in ipairs(item.parts) do
		p.Anchored = false
		p.CanCollide = true
		p.CanTouch = true
		p.CanQuery = true
	end

	-- Clear velocities on primary
	item.primary.AssemblyLinearVelocity = Vector3.zero
	item.primary.AssemblyAngularVelocity = Vector3.zero

	-- Reset transparency
	setTransparency(item, 1)

	-- CRITICAL FIX: Ensure model is completely hidden and unparented
	item.model.Parent = nil

	self._busy[item.model] = nil
	table.insert(self._items, item)
end

-- =========================
-- PUBLIC: RunModel (pooled)
-- =========================
function Core.RunModel(config: {
	model: Model,
	partStorage: Instance,
	templateModel: Model,

	namePrefix: string?,
	dropGroup: string?,
	playerGroup: string?,
	dropRate: number?,
	cashValue: number?,
	lifetime: number?,

	scaleFactor: number?,
	extraLower: number?,
	fadeTime: number?,
	density: number?,
	friction: number?,
	elasticity: number?,
	yawDegrees: number?,
	prewarm: number?,
	cashOn: ("primary" | "all")?,

	collectorNames: {string}?,
	collectorTags: {string}?,
	})
	local dropModel = config.model
	local dropPart  = dropModel:WaitForChild("Drop") :: BasePart
	local storage   = config.partStorage
	local template  = config.templateModel
	assert(template, "RunModel requires config.templateModel")

	local DROP_RATE   = config.dropRate    or 1.2
	local CASH_VALUE  = config.cashValue   or 10
	local SCALE       = config.scaleFactor or 1.0
	local EXTRA_LOWER = config.extraLower  or 0.35
	local FADE_TIME   = config.fadeTime    or 0.35
	local LIFETIME    = config.lifetime
	local GROUP       = config.dropGroup   or "Drops"
	local PLAYER_GRP  = config.playerGroup or "Players"
	local DENSITY     = config.density     or 0.7
	local FRICTION    = config.friction    or 0.3
	local ELASTICITY  = config.elasticity  or 0.05
	local YAW         = config.yawDegrees  or 0
	local PREWARM     = config.prewarm     or 6
	local CASH_ON     = config.cashOn      or "primary"

	local collectorNames = config.collectorNames or { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" }
	local collectorTags  = config.collectorTags  or { "Collector", "SellZone" }
	local NAME_PREFIX    = config.namePrefix     or "Drop_"

	setupCollisionGroups(GROUP, PLAYER_GRP)
	tagCharacterPartsAsPlayerGroup(PLAYER_GRP)

	local base = prepareTemplate(template, SCALE)
	local pool = Pool.new(base, GROUP, DENSITY, FRICTION, ELASTICITY, CASH_VALUE, CASH_ON, PREWARM)

	local count = 0
	while true do
		task.wait(DROP_RATE)
		count += 1

		local item = pool:acquire()
		item.model.Name = NAME_PREFIX .. tostring(count)

		-- CRITICAL FIX: Ensure model is properly unparented before spawning
		if item.model.Parent then
			item.model.Parent = nil
		end

		-- Reset physics state before spawning
		item.primary.AssemblyLinearVelocity = Vector3.zero
		item.primary.AssemblyAngularVelocity = Vector3.zero

		local offsetX = math.random(-2, 2) * 0.1
		local offsetZ = math.random(-2, 2) * 0.1
		local ext = item.model:GetExtentsSize()
		local sitY = (ext.Y / 2) - 0.6
		local spawnPos = dropPart.Position + Vector3.new(-offsetX, -(sitY + EXTRA_LOWER), -offsetZ)
		local yawOnly = CFrame.Angles(0, math.rad(YAW), 0)
		item.model:PivotTo(CFrame.new(spawnPos) * yawOnly)

		-- Upright stabilizer
		do
			local att = Instance.new("Attachment"); att.Parent = item.primary
			local ao  = Instance.new("AlignOrientation")
			ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
			ao.Attachment0 = att
			ao.RigidityEnabled = true
			ao.Responsiveness = 40
			ao.CFrame = yawOnly
			ao.Parent = item.primary
			Debris:AddItem(ao, 0.35); Debris:AddItem(att, 0.35)
		end

		item.primary.AssemblyLinearVelocity = Vector3.new(0, -8, 0)
		item.primary:SetAttribute("SpawnTime", os.clock())

		setTransparency(item, 1)
		
		-- CRITICAL FIX: Use pcall to safely set parent
		local success, err = pcall(function()
			item.model.Parent = storage
		end)
		
		if not success then
			warn("Failed to set parent for", item.model.Name, ":", err)
			-- Try to recover by releasing the item back to pool
			pool:release(item)
			continue
		end

		tweenSubset(item, 0, FADE_TIME, 12, false)

		-- Pop animation
		do
			local original = item.primary.Size
			item.primary.Size = Vector3.new(0.1, 0.1, 0.1)
			TweenService:Create(item.primary, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = original }):Play()
		end

		-- Light flash
		do
			local light = Instance.new("PointLight")
			light.Brightness = 1.2; light.Range = 6; light.Color = Color3.new(1,1,1); light.Parent = item.primary
			TweenService:Create(light, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0.4 }):Play()
			Debris:AddItem(light, 0.6)
		end

		-- DEBUG: Print when model is spawned
		print(string.format("🎯 [DEBUG] Spawned %s | CanTouch=%s | CanCollide=%s | CollisionGroup=%s", 
			item.model.Name, 
			tostring(item.primary.CanTouch),
			tostring(item.primary.CanCollide),
			item.primary.CollisionGroup
			))

		-- Collection handler
		local collected = false
		local function collectAndReturn()
			if collected then return end
			collected = true

			print(string.format("✅ [COLLECTING] %s", item.model.Name))

			-- Anchor and disable physics
			item.primary.Anchored = true
			item.primary.CanCollide = false
			item.primary.CanTouch = false

			tweenSubset(item, 1, math.max(FADE_TIME * 0.75, 0.2), 10, true, function()
				pool:release(item)
			end)
		end

		-- Touch detection on PRIMARY part
		local touchConn = item.primary.Touched:Connect(function(hit)
			if collected then return end

			if isCollectorPart(hit, collectorNames, collectorTags) then
				-- Check Cash IMMEDIATELY (before it gets destroyed!)
				local cashVal = item.primary:FindFirstChild("Cash")
				if cashVal then
					print(string.format("💰 [CASH DETECTED] %s = $%d - Collecting NOW!", item.model.Name, cashVal.Value))
				else
					warn(string.format("⚠️ [NO CASH!] %s is missing Cash IntValue!", item.model.Name))
				end
				collectAndReturn()
			end
		end)
		table.insert(item.conns, touchConn)

		-- BONUS: Also check all parts for touch (more reliable)
		for _, part in ipairs(item.parts) do
			if part ~= item.primary then
				local conn = part.Touched:Connect(function(hit)
					if collected then return end
					if isCollectorPart(hit, collectorNames, collectorTags) then
						-- Check Cash IMMEDIATELY
						local cashVal = part:FindFirstChild("Cash")
						if cashVal then
							print(string.format("💰 [CASH] %s.%s = $%d", item.model.Name, part.Name, cashVal.Value))
						end
						collectAndReturn()
					end
				end)
				table.insert(item.conns, conn)
			end
		end

		if LIFETIME and LIFETIME > 0 then
			task.delay(LIFETIME, function()
				if not collected then collectAndReturn() end
			end)
		end
	end
end

function Core.Run(_config)
	error("Core.Run not implemented in v4.2; use RunModel() for model droppers.")
end

return Core