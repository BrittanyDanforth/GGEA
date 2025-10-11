--[[
	DropperCore v4.7 - ULTIMATE FIX with Template Support
	✅ Supports custom meshes, textures, and scales
	✅ Supports custom particle effects
	✅ Supports custom spawn animations
	✅ Preserves all visual characteristics
	✅ FIXED: Cross-group collision prevention (no drops collide with any other drops)
	✅ FIXED: Full Core.Run() implementation restored
	✅ FIXED: Core.RunModel() now works for template-based droppers
	✅ Fade in/out effects
	✅ Single touch collection
	✅ Automatic cleanup
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

-- Fade out a model's parts
local function fadeOutModel(model, t)
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			fadeOut(desc, t)
		end
	end
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

-- Set collision group for all parts in a model
local function setModelCollisionGroup(model, group)
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.CollisionGroup = group
		end
	end
end

-- Get the bounding box of a model
local function getModelSize(model)
	local cf, size = model:GetBoundingBox()
	return size
end

-- ✅ RESTORED: Full Core.Run() implementation
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
	setupPlayerCollision(PLAYER_GRP)

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

-- ✅ FIXED: Core.RunModel() for template-based droppers
function Core.RunModel(config)
	-- REQUIRED:
	-- config.model: the dropper model containing a child "Drop" (BasePart) to spawn from
	-- config.partStorage: Folder where drops go
	-- config.templateModel: Model to clone for drop appearance

	local DROP_RATE = config.dropRate or 0.5
	local CASH_VALUE = config.cashValue or 100
	local LIFETIME = config.lifetime -- nil = keep forever
	local GROUP = config.dropGroup or "Drops"
	local PLAYER_GRP = config.playerGroup or "Players"
	local FADE_TIME = config.fadeTime or 0.3
	local DENSITY = config.density or 0.7
	local FRICTION = config.friction or 0.3
	local ELASTICITY = config.elasticity or 0.05
	local SCALE_FACTOR = config.scaleFactor or 1.0
	local EXTRA_LOWER = config.extraLower or 0
	local YAW_DEGREES = config.yawDegrees or 0
	local PREWARM = config.prewarm or 0
	local CASH_ON = config.cashOn or "primary" -- "primary" or "all"

	local collectorNames = config.collectorNames or {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"}
	local collectorTags = config.collectorTags or {"Collector", "SellZone"}

	local dropPart = config.model:WaitForChild("Drop")
	local storage = config.partStorage
	local template = config.templateModel

	if not template then
		error("RunModel requires config.templateModel!")
	end

	-- ✅ Setup collision groups with cross-group prevention
	setupCollisionGroups(GROUP, PLAYER_GRP)
	setupPlayerCollision(PLAYER_GRP)

	-- Get template size for positioning
	local templateSize = getModelSize(template)

	-- Yaw rotation
	local yawRotation = CFrame.Angles(0, math.rad(YAW_DEGREES), 0)

	local count = 0

	-- Prewarm function to spawn initial drops
	local function spawnDrop(isPrewarm)
		count += 1

		-- Clone the template
		local drop = template:Clone()
		drop.Name = (config.namePrefix or "Drop_") .. count

		-- Scale the model
		if SCALE_FACTOR ~= 1 then
			local pivot = drop:GetPivot()
			for _, desc in ipairs(drop:GetDescendants()) do
				if desc:IsA("BasePart") then
					desc.Size = desc.Size * SCALE_FACTOR
					local offset = desc.Position - pivot.Position
					desc.Position = pivot.Position + (offset * SCALE_FACTOR)
				end
			end
		end

		-- Make all parts physical and set collision
		local primaryPart = drop.PrimaryPart
		for _, desc in ipairs(drop:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Anchored = false
				desc.CanQuery = true
				desc.CanTouch = true
				desc.CollisionGroup = GROUP
				desc.CustomPhysicalProperties = PhysicalProperties.new(DENSITY, FRICTION, ELASTICITY, 0.5, 0.5)
			end
		end

		-- Position the drop
		local ox = math.random(-2, 2) * 0.1
		local oz = math.random(-2, 2) * 0.1
		local yOffset = -(templateSize.Y / 2) - EXTRA_LOWER
		local pos = dropPart.Position + Vector3.new(-ox, yOffset, -oz)
		drop:PivotTo(CFrame.new(pos) * yawRotation)

		-- Add cash value
		local cashTarget = primaryPart or drop:FindFirstChildWhichIsA("BasePart")
		if cashTarget then
			local cash = Instance.new("IntValue")
			cash.Name = "Cash"
			cash.Value = CASH_VALUE
			cash.Parent = cashTarget
		end

		-- Add to world
		drop.Parent = storage

		-- Set initial velocity (only for non-prewarm drops)
		if not isPrewarm and primaryPart then
			primaryPart.AssemblyLinearVelocity = Vector3.new(0, -8, 0)
		end

		-- Collection detection - monitor all parts
		local collected = false
		local connections = {}

		local function onCollect()
			if collected then return end
			collected = true

			-- Anchor all parts
			for _, desc in ipairs(drop:GetDescendants()) do
				if desc:IsA("BasePart") then
					desc.Anchored = true
					desc.CanTouch = false
					desc.CanCollide = false
				end
			end

			-- Fade out
			fadeOutModel(drop, FADE_TIME * 0.7)

			-- Cleanup
			task.delay(FADE_TIME + 0.05, function()
				for _, conn in ipairs(connections) do
					conn:Disconnect()
				end
				if drop and drop.Parent then
					drop:Destroy()
				end
			end)
		end

		-- Connect touch events for all parts
		for _, desc in ipairs(drop:GetDescendants()) do
			if desc:IsA("BasePart") then
				local conn = desc.Touched:Connect(function(hit)
					if collected then return end
					if isCollectorPart(hit, collectorNames, collectorTags) then
						onCollect()
					end
				end)
				table.insert(connections, conn)
			end
		end

		-- Lifetime cleanup
		if LIFETIME then
			Debris:AddItem(drop, LIFETIME)
		end
	end

	-- Prewarm: spawn initial drops
	if PREWARM > 0 then
		for i = 1, PREWARM do
			spawnDrop(true)
			task.wait(0.05)
		end
	end

	-- Main loop
	while true do
		task.wait(DROP_RATE)
		spawnDrop(false)
	end
end
 
return Core
