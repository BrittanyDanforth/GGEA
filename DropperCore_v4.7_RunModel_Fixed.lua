--[[
	DropperCore v4.7 - WITH FULL RunModel() SUPPORT
	✅ Supports Core.Run() for creating drops from scratch
	✅ Supports Core.RunModel() for cloning template models from ReplicatedStorage
	✅ Cross-group collision prevention (no drops collide with any other drops)
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
	"HelloKittyDrops1", "HelloKittyDrops2", "HelloKittyDrops3",
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

-- Fade in effect for models
local function fadeInModel(model, t)
	local tweens = {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local originalTransparency = part:GetAttribute("OriginalTransparency") or part.Transparency
			part:SetAttribute("OriginalTransparency", originalTransparency)
			part.Transparency = 1
			local tw = TweenService:Create(
				part,
				TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Transparency = originalTransparency }
			)
			tw:Play()
			table.insert(tweens, tw)
		end
	end
	return tweens
end

-- Fade out effect for models
local function fadeOutModel(model, t)
	local tweens = {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local tw = TweenService:Create(
				part,
				TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Transparency = 1 }
			)
			tw:Play()
			table.insert(tweens, tw)
		end
	end
	return tweens
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

-- Get primary part of a model
local function getPrimaryPart(model)
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	
	-- Find first BasePart if no PrimaryPart is set
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			return child
		end
	end
	
	return nil
end

-- Scale model by factor
local function scaleModel(model, scaleFactor)
	if scaleFactor == 1 then return end
	
	local primary = getPrimaryPart(model)
	if not primary then return end
	
	local primaryCF = primary.CFrame
	
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			-- Scale size
			obj.Size = obj.Size * scaleFactor
			
			-- Scale position relative to primary part
			if obj ~= primary then
				local offset = primaryCF:PointToObjectSpace(obj.Position)
				obj.CFrame = primaryCF * CFrame.new(offset * scaleFactor) * (obj.CFrame - obj.Position)
			end
		elseif obj:IsA("SpecialMesh") then
			obj.Scale = obj.Scale * scaleFactor
		elseif obj:IsA("Attachment") then
			obj.Position = obj.Position * scaleFactor
		end
	end
end

-- ✅ Core.RunModel() - Clones template models as drops
function Core.RunModel(config)
	-- REQUIRED:
	-- config.model: the dropper model containing a child "Drop" (BasePart) to spawn from
	-- config.partStorage: Folder where drops go
	-- config.templateModel: The model to clone from ReplicatedStorage

	-- Validate template model
	if not config.templateModel then
		error("RunModel requires a templateModel parameter!")
		return
	end

	-- Tuning with defaults:
	local DROP_RATE = config.dropRate or 0.5
	local CASH_VALUE = config.cashValue or 100
	local LIFETIME = config.lifetime or 120
	local GROUP = config.dropGroup or "Drops"
	local PLAYER_GRP = config.playerGroup or "Players"
	local FADE_TIME = config.fadeTime or 0.3
	local DENSITY = config.density or 0.05
	local FRICTION = config.friction or 0.2
	local ELASTICITY = config.elasticity or 0.0
	
	-- Model-specific settings
	local SCALE_FACTOR = config.scaleFactor or 1
	local EXTRA_LOWER = config.extraLower or 0
	local YAW_DEGREES = config.yawDegrees or 0
	local PREWARM = config.prewarm or 0
	local CASH_ON = config.cashOn or "primary" -- "primary" or "all"

	local collectorNames = config.collectorNames or {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"}
	local collectorTags = config.collectorTags or {"Collector", "SellZone"}

	local dropPart = config.model:WaitForChild("Drop")
	local storage = config.partStorage
	local templateModel = config.templateModel

	-- ✅ Setup collision groups with cross-group prevention
	setupCollisionGroups(GROUP, PLAYER_GRP)
	setupPlayerCollision(PLAYER_GRP)

	local count = 0

	-- Prewarm spawning
	if PREWARM > 0 then
		for i = 1, PREWARM do
			-- Spawn prewarm drops quickly
			local clonedModel = templateModel:Clone()
			clonedModel.Name = (config.namePrefix or "Drop_") .. "Prewarm" .. i
			
			-- Scale the model
			if SCALE_FACTOR ~= 1 then
				scaleModel(clonedModel, SCALE_FACTOR)
			end
			
			-- Get primary part
			local primary = getPrimaryPart(clonedModel)
			if not primary then
				clonedModel:Destroy()
				continue
			end
			
			-- Set collision group and physics for all parts
			for _, part in ipairs(clonedModel:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CollisionGroup = GROUP
					part.CustomPhysicalProperties = PhysicalProperties.new(DENSITY, FRICTION, ELASTICITY, 0.5, 0.5)
					part.CanQuery = true
					part.CanTouch = true
					part.Anchored = false
					part:SetAttribute("OriginalTransparency", part.Transparency)
				end
			end
			
			-- Position randomly around spawn point
			local ox = math.random(-5, 5)
			local oz = math.random(-5, 5)
			local oy = math.random(0, 3)
			local pos = dropPart.Position + Vector3.new(ox, -2.5 - EXTRA_LOWER - oy, oz)
			local rotation = CFrame.Angles(0, math.rad(YAW_DEGREES + math.random(0, 360)), 0)
			
			if clonedModel.PrimaryPart then
				clonedModel:SetPrimaryPartCFrame(CFrame.new(pos) * rotation)
			else
				primary.CFrame = CFrame.new(pos) * rotation
			end
			
			-- Set initial velocity
			primary.AssemblyLinearVelocity = Vector3.new(ox * 0.5, -8, oz * 0.5)
			
			-- Add cash value
			if CASH_ON == "all" then
				for _, part in ipairs(clonedModel:GetDescendants()) do
					if part:IsA("BasePart") then
						local cash = Instance.new("IntValue")
						cash.Name = "Cash"
						cash.Value = CASH_VALUE
						cash.Parent = part
					end
				end
			else
				local cash = Instance.new("IntValue")
				cash.Name = "Cash"
				cash.Value = CASH_VALUE
				cash.Parent = primary
			end
			
			-- Parent to storage
			clonedModel.Parent = storage
			
			-- Setup collection
			local collected = false
			local connections = {}
			
			local function onTouch(hit)
				if collected then return end
				if not isCollectorPart(hit, collectorNames, collectorTags) then return end
				
				collected = true
				
				-- Anchor all parts
				for _, part in ipairs(clonedModel:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = true
						part.CanTouch = false
						part.CanCollide = false
					end
				end
				
				-- Disconnect all connections
				for _, conn in ipairs(connections) do
					conn:Disconnect()
				end
				
				-- Fade out and destroy
				fadeOutModel(clonedModel, FADE_TIME * 0.7)
				
				task.delay(FADE_TIME + 0.05, function()
					if clonedModel and clonedModel.Parent then
						clonedModel:Destroy()
					end
				end)
			end
			
			-- Connect touch detection to all parts
			for _, part in ipairs(clonedModel:GetDescendants()) do
				if part:IsA("BasePart") then
					local conn = part.Touched:Connect(onTouch)
					table.insert(connections, conn)
				end
			end
			
			-- Lifetime cleanup
			if LIFETIME then
				Debris:AddItem(clonedModel, LIFETIME)
			end
			
			task.wait(DROP_RATE / PREWARM)
		end
	end

	-- Main spawning loop
	while true do
		task.wait(DROP_RATE)
		count += 1

		-- Clone the template model
		local clonedModel = templateModel:Clone()
		clonedModel.Name = (config.namePrefix or "Drop_") .. count

		-- Scale the model
		if SCALE_FACTOR ~= 1 then
			scaleModel(clonedModel, SCALE_FACTOR)
		end

		-- Get primary part for positioning
		local primary = getPrimaryPart(clonedModel)
		if not primary then
			warn("Template model has no primary part or BasePart!")
			clonedModel:Destroy()
			continue
		end

		-- Set collision group and physics for all parts
		for _, part in ipairs(clonedModel:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CollisionGroup = GROUP
				part.CustomPhysicalProperties = PhysicalProperties.new(DENSITY, FRICTION, ELASTICITY, 0.5, 0.5)
				part.CanQuery = true
				part.CanTouch = true
				part.Anchored = false
				part:SetAttribute("OriginalTransparency", part.Transparency)
			end
		end

		-- Position the model
		local ox = math.random(-2, 2) * 0.1
		local oz = math.random(-2, 2) * 0.1
		local pos = dropPart.Position + Vector3.new(ox, -2.5 - EXTRA_LOWER, oz)
		local rotation = CFrame.Angles(0, math.rad(YAW_DEGREES), 0)
		
		if clonedModel.PrimaryPart then
			clonedModel:SetPrimaryPartCFrame(CFrame.new(pos) * rotation)
		else
			primary.CFrame = CFrame.new(pos) * rotation
		end

		-- Set velocity
		primary.AssemblyLinearVelocity = Vector3.new(ox * 2, -8, oz * 2)

		-- Add cash value based on cashOn setting
		if CASH_ON == "all" then
			-- Add cash to all parts
			for _, part in ipairs(clonedModel:GetDescendants()) do
				if part:IsA("BasePart") then
					local cash = Instance.new("IntValue")
					cash.Name = "Cash"
					cash.Value = CASH_VALUE
					cash.Parent = part
				end
			end
		else
			-- Add cash to primary part only
			local cash = Instance.new("IntValue")
			cash.Name = "Cash"
			cash.Value = CASH_VALUE
			cash.Parent = primary
		end

		-- Fade in effect
		fadeInModel(clonedModel, FADE_TIME)

		-- Add to world
		clonedModel.Parent = storage

		-- Pop animation (scale all parts)
		local startScale = 0.1
		for _, part in ipairs(clonedModel:GetDescendants()) do
			if part:IsA("BasePart") then
				local originalSize = part.Size
				part.Size = originalSize * startScale
				TweenService:Create(
					part,
					TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Size = originalSize }
				):Play()
			elseif part:IsA("SpecialMesh") then
				local originalScale = part.Scale
				part.Scale = originalScale * startScale
				TweenService:Create(
					part,
					TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Scale = originalScale }
				):Play()
			end
		end

		-- Collection detection
		local collected = false
		local connections = {}
		
		local function onTouch(hit)
			if collected then return end
			if not isCollectorPart(hit, collectorNames, collectorTags) then return end

			collected = true
			
			-- Anchor all parts
			for _, part in ipairs(clonedModel:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanTouch = false
					part.CanCollide = false
				end
			end

			-- Disconnect all connections
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end

			-- Fade out
			fadeOutModel(clonedModel, FADE_TIME * 0.7)

			-- Destroy after fade
			task.delay(FADE_TIME + 0.05, function()
				if clonedModel and clonedModel.Parent then
					clonedModel:Destroy()
				end
			end)
		end

		-- Connect touch detection to all parts
		for _, part in ipairs(clonedModel:GetDescendants()) do
			if part:IsA("BasePart") then
				local conn = part.Touched:Connect(onTouch)
				table.insert(connections, conn)
			end
		end

		-- Lifetime cleanup
		if LIFETIME then
			Debris:AddItem(clonedModel, LIFETIME)
		end
	end
end

-- ✅ Core.Run() - Creates drops from scratch (original implementation)
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
		local pos = dropPart.Position + Vector3.new(ox, SPAWN_Y_OFF, oz)
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
		Debris:AddItem(part, LIFETIME)
	end
end

return Core