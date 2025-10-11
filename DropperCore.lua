--[[
	DropperCore v4.7 - MERGED: Both Run() and RunModel() Working
	✅ Core.Run() for simple single-part drops
	✅ Core.RunModel() for template-based model drops (v4.4 implementation)
	✅ Cross-group collision prevention
	✅ Full scaling, welding, and physics support
]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Core = {}

-- ✅ ALL KNOWN DROPPER GROUPS - Add new groups here!
local ALL_DROPPER_GROUPS = {
	"KuromiOrbs1", "KuromiOrbs2", "KuromiOrbs3",
	"CinnamorollOrbs", "Dropper5Orbs", "KuromiOrbs6",
	"KuromiOrbs8", "KuromiOrbs9", "KuromiOrbs10",
	"KuromiOrbs11", "KuromiOrbs12", "KuromiOrbs13",
	"Drops" -- Default group
}

-- =========================
-- Utility Functions
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

-- Setup collision groups to prevent ALL drop-drop and drop-player collisions
local function setupCollisionGroups(dropGroup, playerGroup)
	-- Register this group
	pcall(function()
		PhysicsService:RegisterCollisionGroup(dropGroup)
		PhysicsService:RegisterCollisionGroup(playerGroup)
	end)

	-- This group doesn't collide with players
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(dropGroup, playerGroup, false)
	end)

	-- This group doesn't collide with itself
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(dropGroup, dropGroup, false)
	end)

	-- ✅ CRITICAL FIX: This group doesn't collide with ANY other dropper groups
	for _, otherGroup in ipairs(ALL_DROPPER_GROUPS) do
		if otherGroup ~= dropGroup then
			pcall(function()
				PhysicsService:RegisterCollisionGroup(otherGroup)
			end)
			pcall(function()
				PhysicsService:CollisionGroupSetCollidable(dropGroup, otherGroup, false)
			end)
		end
	end
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

-- Fade in/out effects
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

local function fadeOut(part, t)
	local tw = TweenService:Create(
		part,
		TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Transparency = 1 }
	)
	tw:Play()
	return tw
end

-- Setup mesh (supports full customization)
local function setupMesh(part, meshConfig)
	if not meshConfig then return nil end

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = meshConfig.meshType or Enum.MeshType.FileMesh
	mesh.MeshId = meshConfig.meshId or ""
	mesh.TextureId = meshConfig.textureId or ""
	mesh.Scale = meshConfig.scale or Vector3.new(1, 1, 1)
	mesh.Parent = part

	return mesh
end

-- Setup custom particles
local function setupParticles(part, particleConfigs)
	if not particleConfigs then return {} end

	local particles = {}
	for _, pConfig in ipairs(particleConfigs) do
		local emitter = Instance.new("ParticleEmitter")

		-- Apply all properties from config
		for property, value in pairs(pConfig) do
			if property ~= "emit" then
				pcall(function()
					emitter[property] = value
				end)
			end
		end

		emitter.Parent = part
		table.insert(particles, emitter)

		-- Handle one-time emit
		if pConfig.emit then
			emitter:Emit(pConfig.emit)
			if pConfig.autoDestroy then
				Debris:AddItem(emitter, pConfig.lifetime or 1)
			end
		end
	end

	return particles
end

-- =========================
-- Model Drop Creation (v4.4)
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
-- PUBLIC: Core.Run() - Single Part Drops
-- =========================
function Core.Run(config)
	-- REQUIRED:
	-- config.model: the dropper model containing a child "Drop" (BasePart) to spawn from
	-- config.partStorage: Folder where drops go

	-- Tuning with defaults:
	local DROP_RATE = config.dropRate or 0.5
	local CASH_VALUE = config.cashValue or 100
	local LIFETIME = config.lifetime or 120
	local SIZE = config.size or Vector3.new(1, 1, 1)
	local COLOR = config.color or Color3.new(1, 1, 1)
	local BRICKCOLOR = config.brickColor or BrickColor.new("White")
	local MATERIAL = typeof(config.material) == "EnumItem" and config.material or Enum.Material.SmoothPlastic
	local SHAPE = config.shape or Enum.PartType.Block
	local GROUP = config.dropGroup or "Drops"
	local PLAYER_GRP = config.playerGroup or "Players"
	local SPAWN_Y_OFF = config.spawnYOffset or -2.5
	local FADE_TIME = config.fadeTime or 0.3
	local DENSITY = config.density or 0.05
	local FRICTION = config.friction or 0.2
	local ELASTICITY = config.elasticity or 0.0
	local REFLECTANCE = config.reflectance or 0
	local TRANSPARENCY = config.transparency or 0

	local collectorNames = config.collectorNames or {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"}
	local collectorTags = config.collectorTags or {"Collector", "SellZone"}

	-- Mesh configuration
	local meshConfig = config.mesh

	-- Particle configurations
	local particleConfigs = config.particles
	local spawnParticleConfigs = config.spawnParticles

	-- Light configuration
	local lightConfig = config.light or {
		brightness = 1,
		range = 6,
		color = Color3.fromRGB(50, 255, 50)
	}

	-- Spawn configuration
	local spawnConfig = config.spawn or {}
	local spawnRotation = spawnConfig.rotation or CFrame.Angles(0, 0, 0)
	local spawnVelocity = spawnConfig.velocity or Vector3.new(0, -8, 0)
	local spawnAngularVelocity = spawnConfig.angularVelocity or Vector3.new(0, 0, 0)

	-- Animation configuration
	local animConfig = config.animation or {}
	local popAnimation = animConfig.pop ~= false -- default true
	local popStartSize = animConfig.popStartSize or Vector3.new(0.1, 0.1, 0.1)
	local popDuration = animConfig.popDuration or 0.2
	local popStyle = animConfig.popStyle or Enum.EasingStyle.Back

	-- Mesh animation (if mesh exists)
	local meshAnimConfig = animConfig.mesh or {}
	local meshStartScale = meshAnimConfig.startScale
	local meshEndScale = meshAnimConfig.endScale
	local meshDuration = meshAnimConfig.duration or 0.3
	local meshStyle = meshAnimConfig.style or Enum.EasingStyle.Back

	local dropPart = config.model:WaitForChild("Drop")
	local storage = config.partStorage

	-- ✅ Setup collision groups with cross-group prevention
	setupCollisionGroups(GROUP, PLAYER_GRP)
	tagCharacterPartsAsPlayerGroup(PLAYER_GRP)

	local count = 0

	while true do
		task.wait(DROP_RATE)
		count += 1

		-- Create part
		local part = Instance.new("Part")
		part.Name = (config.namePrefix or "Drop_") .. count
		part.Size = SIZE

		-- Set color (prefer Color over BrickColor if both provided)
		if config.color then
			part.Color = COLOR
		else
			part.BrickColor = BRICKCOLOR
		end

		part.Material = MATERIAL
		part.Shape = SHAPE
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Reflectance = REFLECTANCE
		part.Transparency = TRANSPARENCY
		part.Anchored = false
		part.CanQuery = true
		part.CanTouch = true
		-- ✅ Set collision group BEFORE parenting
		part.CollisionGroup = GROUP
		part.CustomPhysicalProperties = PhysicalProperties.new(DENSITY, FRICTION, ELASTICITY, 0.5, 0.5)

		-- Spawn position (slightly randomized & offset)
		local ox = math.random(-2, 2) * 0.1
		local oz = math.random(-2, 2) * 0.1
		local pos = dropPart.Position + Vector3.new(-ox, SPAWN_Y_OFF, -oz)
		part.CFrame = CFrame.new(pos) * spawnRotation

		-- Set velocity
		part.AssemblyLinearVelocity = spawnVelocity
		if spawnAngularVelocity.Magnitude > 0 then
			part.AssemblyAngularVelocity = spawnAngularVelocity
		end

		-- Setup mesh (if configured)
		local mesh
		if meshConfig then
			mesh = setupMesh(part, meshConfig)

			-- Set initial scale for animation
			if meshStartScale then
				mesh.Scale = meshStartScale
			end
		end

		-- Cash value
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = CASH_VALUE
		cash.Parent = part

		-- Setup light
		local light
		if lightConfig then
			light = Instance.new("PointLight")
			light.Brightness = lightConfig.brightness or 1
			light.Range = lightConfig.range or 6
			light.Color = lightConfig.color or Color3.fromRGB(50, 255, 50)
			light.Parent = part
		end

		-- Setup continuous particles
		if particleConfigs then
			setupParticles(part, particleConfigs)
		end

		-- Fade in (if transparency > 0)
		if TRANSPARENCY > 0 then
			fadeIn(part, FADE_TIME, TRANSPARENCY)
		end

		-- Add to world
		part.Parent = storage

		-- Spawn particles (one-time)
		if spawnParticleConfigs then
			setupParticles(part, spawnParticleConfigs)
		end

		-- Pop animation (part size)
		if popAnimation then
			local originalSize = part.Size
			part.Size = popStartSize
			TweenService:Create(
				part,
				TweenInfo.new(popDuration, popStyle, Enum.EasingDirection.Out),
				{ Size = originalSize }
			):Play()
		end

		-- Mesh scale animation
		if mesh and meshEndScale then
			TweenService:Create(
				mesh,
				TweenInfo.new(meshDuration, meshStyle, Enum.EasingDirection.Out),
				{ Scale = meshEndScale }
			):Play()
		end

		-- Flash effect on spawn
		if light and lightConfig.spawnFlash then
			local originalBrightness = light.Brightness
			light.Brightness = lightConfig.spawnBrightness or (originalBrightness * 2.5)
			TweenService:Create(
				light,
				TweenInfo.new(lightConfig.flashDuration or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Brightness = originalBrightness }
			):Play()
		end

		-- Collection detection
		local collected = false
		local touchConn
		touchConn = part.Touched:Connect(function(hit)
			if collected then return end
			if not isCollectorPart(hit, collectorNames, collectorTags) then return end

			collected = true
			part.Anchored = true
			part.CanTouch = false
			part.CanCollide = false

			-- Flash effect on collection
			if light then
				light.Brightness = lightConfig.collectBrightness or 3
				TweenService:Create(
					light,
					TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Brightness = lightConfig.brightness or 1 }
				):Play()
			end

			fadeOut(part, FADE_TIME * 0.7)

			task.delay(FADE_TIME + 0.05, function()
				if touchConn then touchConn:Disconnect() end
				if part and part.Parent then part:Destroy() end
			end)
		end)

		-- Lifetime cleanup
		if LIFETIME then
			Debris:AddItem(part, LIFETIME)
		end
	end
end

-- =========================
-- PUBLIC: Core.RunModel() - Template Model Drops (v4.4)
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
	local PREWARM     = config.prewarm     or 0
	local CASH_ON     = config.cashOn      or "primary"

	local collectorNames = config.collectorNames or { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" }
	local collectorTags  = config.collectorTags  or { "Collector", "SellZone" }
	local NAME_PREFIX    = config.namePrefix     or "Drop_"

	setupCollisionGroups(GROUP, PLAYER_GRP)
	tagCharacterPartsAsPlayerGroup(PLAYER_GRP)

	local count = 0
	
	local function spawnDrop(isPrewarm)
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
		if not isPrewarm then
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

		if not isPrewarm then
			primary.AssemblyLinearVelocity = Vector3.new(0, -8, 0)
		end
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
		if not isPrewarm then
			local original = primary.Size
			primary.Size = Vector3.new(0.1, 0.1, 0.1)
			TweenService:Create(primary, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = original }):Play()
		end

		-- Light flash
		if not isPrewarm then
			local light = Instance.new("PointLight")
			light.Brightness = 1.2; light.Range = 6; light.Color = Color3.new(1,1,1); light.Parent = primary
			TweenService:Create(light, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0.4 }):Play()
			Debris:AddItem(light, 0.6)
		end

		-- Collection handler
		local collected = false
		local connections = {}

		local function collectAndReturn()
			if collected then return end
			collected = true

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

	-- Prewarm: spawn initial drops without animations
	if PREWARM > 0 then
		for i = 1, PREWARM do
			spawnDrop(true)
			task.wait(0.05)
		end
	end

	-- Main drop loop
	while true do
		task.wait(DROP_RATE)
		spawnDrop(false)
	end
end

return Core
