--!strict
-- DropperCore v4.4 — FIXED: Scaling + Welding + Parent Lock Issue

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
-- ULTIMATE FIX: Simple fresh model creation
-- =========================
local function createFreshDropModel(
	template: Model,
	scale: number,
	dropGroup: string,
	density: number, friction: number, elasticity: number,
	cashValue: number, cashOn: "primary" | "all"
): Model
	-- Clone the template
	local model = template:Clone()
	
	-- Find primary part
	local primary = findPrimaryPart(model) or model:FindFirstChildWhichIsA("BasePart", true)
	if primary then model.PrimaryPart = primary end
	
	-- Remove existing welds
	for _, j in ipairs(model:GetDescendants()) do
		if j:IsA("WeldConstraint") or j:IsA("Motor6D") then j:Destroy() end
	end
	
	-- Apply scaling
	if scale ~= 1 then
		local pivot = model:GetPivot()
		model:ScaleTo(scale)
		model:PivotTo(pivot)
	end
	
	-- Re-weld all parts to primary
	if primary then weldAllParts(model, primary) end
	
	-- Setup all parts
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanTouch = true
			part.CanQuery = true
			part.CanCollide = true
			pcall(function() part.CollisionGroup = dropGroup end)
			part.CustomPhysicalProperties = PhysicalProperties.new(density, friction, elasticity, 1, 1)
		end
	end
	
	-- Add cash values
	if cashOn == "primary" then
		local v = Instance.new("IntValue")
		v.Name = "Cash"; v.Value = cashValue; v.Parent = primary
	else
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				local v = Instance.new("IntValue")
				v.Name = "Cash"; v.Value = cashValue; v.Parent = part
			end
		end
	end
	
	return model
end

-- =========================
-- PUBLIC: RunModel (fresh models)
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
	local CASH_ON     = config.cashOn      or "primary"

	local collectorNames = config.collectorNames or { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" }
	local collectorTags  = config.collectorTags  or { "Collector", "SellZone" }
	local NAME_PREFIX    = config.namePrefix     or "Drop_"

	setupCollisionGroups(GROUP, PLAYER_GRP)
	tagCharacterPartsAsPlayerGroup(PLAYER_GRP)

	local count = 0
	while true do
		task.wait(DROP_RATE)
		count += 1

		-- Create fresh model with proper scaling and welding
		local model = createFreshDropModel(template, SCALE, GROUP, DENSITY, FRICTION, ELASTICITY, CASH_VALUE, CASH_ON)
		model.Name = NAME_PREFIX .. tostring(count)

		local primary = findPrimaryPart(model) :: BasePart
		local parts = {}
		local decals = {}
		
		-- Collect all parts and decals
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			elseif d:IsA("Decal") or d:IsA("Texture") then
				table.insert(decals, d)
			end
		end

		-- Reset physics state
		primary.AssemblyLinearVelocity = Vector3.zero
		primary.AssemblyAngularVelocity = Vector3.zero

		local offsetX = math.random(-2, 2) * 0.1
		local offsetZ = math.random(-2, 2) * 0.1
		local ext = model:GetExtentsSize()
		local sitY = (ext.Y / 2) - 0.6
		local spawnPos = dropPart.Position + Vector3.new(-offsetX, -(sitY + EXTRA_LOWER), -offsetZ)
		local yawOnly = CFrame.Angles(0, math.rad(YAW), 0)
		model:PivotTo(CFrame.new(spawnPos) * yawOnly)

		-- Upright stabilizer
		do
			local att = Instance.new("Attachment"); att.Parent = primary
			local ao  = Instance.new("AlignOrientation")
			ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
			ao.Attachment0 = att
			ao.RigidityEnabled = true
			ao.Responsiveness = 40
			ao.CFrame = yawOnly
			ao.Parent = primary
			Debris:AddItem(ao, 0.35); Debris:AddItem(att, 0.35)
		end

		primary.AssemblyLinearVelocity = Vector3.new(0, -8, 0)
		primary:SetAttribute("SpawnTime", os.clock())

		-- Set initial transparency
		for _, p in ipairs(parts) do p.Transparency = 1 end
		for _, d in ipairs(decals) do
			if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
		end

		-- Spawn the model
		model.Parent = storage

		-- Fade in animation
		local ti = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		for i, p in ipairs(parts) do
			if i <= 12 then -- Limit simultaneous tweens
				TweenService:Create(p, ti, {Transparency = 0}):Play()
			else
				p.Transparency = 0
			end
		end
		for i, d in ipairs(decals) do
			if i <= 12 and (d:IsA("Decal") or d:IsA("Texture")) then
				TweenService:Create(d, ti, {Transparency = 0}):Play()
			else
				if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 0 end
			end
		end

		-- Pop animation
		do
			local original = primary.Size
			primary.Size = Vector3.new(0.1, 0.1, 0.1)
			TweenService:Create(primary, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = original }):Play()
		end

		-- Light flash
		do
			local light = Instance.new("PointLight")
			light.Brightness = 1.2; light.Range = 6; light.Color = Color3.new(1,1,1); light.Parent = primary
			TweenService:Create(light, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0.4 }):Play()
			Debris:AddItem(light, 0.6)
		end

		-- DEBUG: Print when model is spawned (DISABLED TO REDUCE SPAM)
		-- print(string.format("🎯 [DEBUG] Spawned %s | CanTouch=%s | CanCollide=%s | CollisionGroup=%s | Scale=%.2f", 
		--	model.Name, 
		--	tostring(primary.CanTouch),
		--	tostring(primary.CanCollide),
		--	primary.CollisionGroup,
		--	SCALE
		--	))

		-- Collection handler
		local collected = false
		local connections = {}
		
		local function collectAndReturn()
			if collected then return end
			collected = true

			-- print(string.format("✅ [COLLECTING] %s", model.Name)) -- DISABLED TO REDUCE SPAM

			-- Disconnect all connections
			for _, conn in ipairs(connections) do
				if conn.Connected then conn:Disconnect() end
			end

			-- Anchor and disable physics
			primary.Anchored = true
			primary.CanCollide = false
			primary.CanTouch = false

			-- Fade out animation
			local fadeOutTi = TweenInfo.new(math.max(FADE_TIME * 0.75, 0.2), Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			for i, p in ipairs(parts) do
				if i <= 10 then
					TweenService:Create(p, fadeOutTi, {Transparency = 1}):Play()
				else
					p.Transparency = 1
				end
			end
			for i, d in ipairs(decals) do
				if i <= 10 and (d:IsA("Decal") or d:IsA("Texture")) then
					TweenService:Create(d, fadeOutTi, {Transparency = 1}):Play()
				else
					if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
				end
			end

			-- Destroy after fade
			task.delay(math.max(FADE_TIME * 0.75, 0.2) + 0.1, function()
				model:Destroy()
			end)
		end

		-- Touch detection on PRIMARY part
		local touchConn = primary.Touched:Connect(function(hit)
			if collected then return end

			if isCollectorPart(hit, collectorNames, collectorTags) then
				-- Check Cash IMMEDIATELY (before it gets destroyed!)
				local cashVal = primary:FindFirstChild("Cash")
				if cashVal then
					-- print(string.format("💰 [CASH DETECTED] %s = $%d - Collecting NOW!", model.Name, cashVal.Value)) -- DISABLED TO REDUCE SPAM
				else
					warn(string.format("⚠️ [NO CASH!] %s is missing Cash IntValue!", model.Name))
				end
				collectAndReturn()
			end
		end)
		table.insert(connections, touchConn)

		-- BONUS: Also check all parts for touch (more reliable)
		for _, part in ipairs(parts) do
			if part ~= primary then
				local conn = part.Touched:Connect(function(hit)
					if collected then return end
					if isCollectorPart(hit, collectorNames, collectorTags) then
						-- Check Cash IMMEDIATELY
						local cashVal = part:FindFirstChild("Cash")
						if cashVal then
							-- print(string.format("💰 [CASH] %s.%s = $%d", model.Name, part.Name, cashVal.Value)) -- DISABLED TO REDUCE SPAM
						end
						collectAndReturn()
					end
				end)
				table.insert(connections, conn)
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
	error("Core.Run not implemented in v4.4; use RunModel() for model droppers.")
end

return Core