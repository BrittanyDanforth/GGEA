--[[
	DropperCore v4.8 - Run() + RunModel() (mesh OR model drops)
	✅ FIXED: Added ALL Cinnamoroll + HelloKitty groups to prevent collision
	✅ NEW: Optional keepUpright parameter prevents models from tipping on conveyors!
	✅ Keeps your v4.6 behavior for single-part/mesh drops
	✅ Adds solid Model-drop pipeline (clone, scale, weld, physics, fade, collect)
	✅ Cross-group collision prevention + players don't collide with drops
	✅ Optional prewarm (set prewarm=0 for no initial burst)
	
	NEW FEATURES:
	- keepUpright: Set to true to prevent model drops from tipping over (great for plushies!)
]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Core = {}

-- ✅ FIXED: Added ALL Cinnamoroll + HelloKitty groups so they don't collide!
local ALL_DROPPER_GROUPS = {
	-- Kuromi groups
	"KuromiOrbs1","KuromiOrbs2","KuromiOrbs3",
	"KuromiOrbs6","KuromiOrbs8","KuromiOrbs9","KuromiOrbs10",
	"KuromiOrbs11","KuromiOrbs12","KuromiOrbs13",
	
	-- Cinnamoroll groups
	"CinnamorollOrbs","CinnamorollOrbs1","CinnamorollOrbs2","CinnamorollOrbs3",
	"CinnamorollOrbs4","CinnamorollOrbs5","CinnamorollOrbs6",
	"CinnamorollOrbs8","CinnamorollOrbs9","CinnamorollOrbs10",
	
	-- HelloKitty groups
	"HelloKittyDrops","HelloKittyDrops1","HelloKittyDrops2","HelloKittyDrops3",
	"HelloKittyDrops4","HelloKittyDrops5","HelloKittyDrops6",
	"HelloKittyDrops8","HelloKittyDrops9","HelloKittyDrops10",
	
	-- Other groups
	"Dropper5Orbs",
	"Drops"
}

--============================
-- Utilities
--============================
local function setupCollisionGroups(dropGroup: string, playerGroup: string)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(dropGroup)
		PhysicsService:RegisterCollisionGroup(playerGroup)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(dropGroup, playerGroup, false)
		PhysicsService:CollisionGroupSetCollidable(dropGroup, dropGroup, false)
	end)
	for _, other in ipairs(ALL_DROPPER_GROUPS) do
		if other ~= dropGroup then
			pcall(function() PhysicsService:RegisterCollisionGroup(other) end)
			pcall(function() PhysicsService:CollisionGroupSetCollidable(dropGroup, other, false) end)
		end
	end
end

local function setupPlayerCollision(playerGroup: string)
	local function tagChar(char: Model)
		task.defer(function()
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") then
					pcall(function() p.CollisionGroup = playerGroup end)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(function(plr) plr.CharacterAdded:Connect(tagChar) end)
	for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then tagChar(plr.Character) end end
end

local function isCollectorPart(hit: Instance?, names: {string}, tags: {string}): boolean
	if not (hit and hit:IsA("BasePart")) then return false end
	local n = string.lower(hit.Name)
	local pn = hit.Parent and string.lower(hit.Parent.Name) or ""

	for _, want in ipairs(names) do
		local w = string.lower(want)
		if n == w or pn == w then return true end
	end
	if n:find("collect") or pn:find("collect") or n:find("sell") or pn:find("sell") then return true end

	for _, t in ipairs(tags) do
		if CollectionService:HasTag(hit, t) or (hit.Parent and CollectionService:HasTag(hit.Parent, t)) then
			return true
		end
	end
	if hit:GetAttribute("Collector") == true then return true end
	if hit.Parent and hit.Parent:FindFirstChild("Collector") then return true end

	return false
end

local function fadeIn(part: BasePart, t: number, to: number)
	part.Transparency = 1
	local tw = TweenService:Create(part, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = to})
	tw:Play()
	return tw
end

local function fadeOut(part: BasePart, t: number)
	local tw = TweenService:Create(part, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1})
	tw:Play()
	return tw
end

local function setupMesh(part: BasePart, meshConfig)
	if not meshConfig then return nil end
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = meshConfig.meshType or Enum.MeshType.FileMesh
	mesh.MeshId = meshConfig.meshId or ""
	mesh.TextureId = meshConfig.textureId or ""
	mesh.Scale = meshConfig.scale or Vector3.new(1,1,1)
	mesh.Offset = meshConfig.offset or Vector3.new(0,0,0) -- supports vertical offset
	mesh.Parent = part
	return mesh
end

local function setupParticles(part: BasePart, list)
	if not list then return {} end
	local created = {}
	for _, cfg in ipairs(list) do
		local em = Instance.new("ParticleEmitter")
		for k,v in pairs(cfg) do
			if k ~= "emit" and k ~= "autoDestroy" and k ~= "lifetime" then
				pcall(function() em[k] = v end)
			end
		end
		em.Parent = part
		table.insert(created, em)
		if cfg.emit then
			em:Emit(cfg.emit)
			if cfg.autoDestroy then Debris:AddItem(em, cfg.lifetime or 1) end
		end
	end
	return created
end

-- Helpers for Model-drops
local function findPrimaryPart(model: Model): BasePart?
	if model.PrimaryPart then return model.PrimaryPart end
	local best, vol = nil, -1
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > vol then vol = v; best = d end
		end
	end
	if best then model.PrimaryPart = best end
	return best
end

local function weldAllToPrimary(model: Model, primary: BasePart)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= primary then
			local w = Instance.new("WeldConstraint")
			w.Part0 = primary; w.Part1 = d; w.Parent = primary
		end
	end
end

--============================
-- PUBLIC: Core.Run (single Part + optional mesh)
--============================
function Core.Run(config)
	-- Required references
	local dropPart = config.model:WaitForChild("Drop")
	local storage  = config.partStorage

	-- Defaults
	local DROP_RATE   = config.dropRate or 0.5
	local CASH_VALUE  = config.cashValue or 100
	local LIFETIME    = config.lifetime or 120
	local SIZE        = config.size or Vector3.new(1, 1, 1)
	local COLOR       = config.color or Color3.new(1, 1, 1)
	local BRICKCOLOR  = config.brickColor or BrickColor.new("White")
	local MATERIAL    = typeof(config.material) == "EnumItem" and config.material or Enum.Material.SmoothPlastic
	local SHAPE       = config.shape or Enum.PartType.Block
	local GROUP       = config.dropGroup or "Drops"
	local PLAYER_GRP  = config.playerGroup or "Players"
	local SPAWN_Y_OFF = config.spawnYOffset or -2.5
	local FADE_TIME   = config.fadeTime or 0.3
	local DENSITY     = config.density or 0.05
	local FRICTION    = config.friction or 0.2
	local ELASTICITY  = config.elasticity or 0.0
	local REFLECTANCE = config.reflectance or 0
	local TRANSPARENCY= config.transparency or 0

	local collectorNames = config.collectorNames or {"Collector","CollectorZone","Receiver","Sell","SellPad"}
	local collectorTags  = config.collectorTags  or {"Collector","SellZone"}

	local meshConfig   = config.mesh
	local particlesCfg = config.particles
	local spawnParticlesCfg = config.spawnParticles

	local lightConfig = config.light or {brightness=1, range=6, color=Color3.fromRGB(50,255,50)}
	local spawnConfig = config.spawn or {}
	local spawnRotation        = spawnConfig.rotation or CFrame.Angles(0,0,0)
	local spawnVelocity        = spawnConfig.velocity or Vector3.new(0,-8,0)
	local spawnAngularVelocity = spawnConfig.angularVelocity or Vector3.new(0,0,0)

	local animConfig     = config.animation or {}
	local popAnimation   = animConfig.pop ~= false
	local popStartSize   = animConfig.popStartSize or Vector3.new(0.1,0.1,0.1)
	local popDuration    = animConfig.popDuration or 0.2
	local popStyle       = animConfig.popStyle or Enum.EasingStyle.Back

	local meshAnimConfig = animConfig.mesh or {}
	local meshStartScale = meshAnimConfig.startScale
	local meshEndScale   = meshAnimConfig.endScale
	local meshDuration   = meshAnimConfig.duration or 0.3
	local meshStyle      = meshAnimConfig.style or Enum.EasingStyle.Back

	-- Collision
	setupCollisionGroups(GROUP, PLAYER_GRP)
	setupPlayerCollision(PLAYER_GRP)

	local count = 0
	while true do
		task.wait(DROP_RATE)
		count += 1

		-- Part
		local part = Instance.new("Part")
		part.Name = (config.namePrefix or "Drop_") .. count
		part.Size = SIZE
		if config.color then part.Color = COLOR else part.BrickColor = BRICKCOLOR end
		part.Material = MATERIAL
		part.Shape = SHAPE
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Reflectance = REFLECTANCE
		part.Transparency = TRANSPARENCY
		part.Anchored = false
		part.CanQuery = true
		part.CanTouch = true
		pcall(function() part.CollisionGroup = GROUP end)
		part.CustomPhysicalProperties = PhysicalProperties.new(DENSITY, FRICTION, ELASTICITY, 0.5, 0.5)

		local ox = math.random(-2,2) * 0.1
		local oz = math.random(-2,2) * 0.1
		local pos = dropPart.Position + Vector3.new(-ox, SPAWN_Y_OFF, -oz)
		part.CFrame = CFrame.new(pos) * spawnRotation

		part.AssemblyLinearVelocity = spawnVelocity
		if spawnAngularVelocity.Magnitude > 0 then part.AssemblyAngularVelocity = spawnAngularVelocity end

		local mesh
		if meshConfig then
			mesh = setupMesh(part, meshConfig)
			if meshStartScale then mesh.Scale = meshStartScale end
		end

		-- Cash
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"; cash.Value = CASH_VALUE; cash.Parent = part

		-- Light
		local light
		if lightConfig then
			light = Instance.new("PointLight")
			light.Brightness = lightConfig.brightness or 1
			light.Range = lightConfig.range or 6
			light.Color = lightConfig.color or Color3.fromRGB(50, 255, 50)
			light.Parent = part
		end

		if particlesCfg then setupParticles(part, particlesCfg) end

		-- Fade
		if TRANSPARENCY > 0 then fadeIn(part, FADE_TIME, TRANSPARENCY) end

		-- Parent (after setup)
		part.Parent = storage

		-- Spawn particles
		if spawnParticlesCfg then setupParticles(part, spawnParticlesCfg) end

		-- Part pop
		if popAnimation then
			local originalSize = part.Size
			part.Size = popStartSize
			TweenService:Create(part, TweenInfo.new(popDuration, popStyle, Enum.EasingDirection.Out), {Size = originalSize}):Play()
		end

		-- Mesh scale anim
		if mesh and meshEndScale then
			TweenService:Create(mesh, TweenInfo.new(meshDuration, meshStyle, Enum.EasingDirection.Out), {Scale = meshEndScale}):Play()
		end

		-- Flash
		if light and (lightConfig.spawnFlash) then
			local originalBrightness = light.Brightness
			light.Brightness = lightConfig.spawnBrightness or (originalBrightness * 2.5)
			TweenService:Create(light, TweenInfo.new(lightConfig.flashDuration or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Brightness = originalBrightness}):Play()
		end

		-- Collect
		local collected = false
		local touchConn
		touchConn = part.Touched:Connect(function(hit)
			if collected then return end
			if not isCollectorPart(hit, collectorNames, collectorTags) then return end
			collected = true
			part.Anchored = true
			part.CanTouch = false
			part.CanCollide = false
			if light then
				light.Brightness = (lightConfig.collectBrightness or 3)
				TweenService:Create(light, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Brightness = lightConfig.brightness or 1}):Play()
			end
			fadeOut(part, FADE_TIME * 0.7)
			task.delay(FADE_TIME + 0.05, function()
				if touchConn then touchConn:Disconnect() end
				if part and part.Parent then part:Destroy() end
			end)
		end)

		-- Cleanup
		if LIFETIME then Debris:AddItem(part, LIFETIME) end
	end
end

--============================
-- PUBLIC: Core.RunModel (clone + drop a Model)
--============================
function Core.RunModel(config)
	-- Required
	local dropModel      = config.model
	local storage        = config.partStorage
	local template       = config.templateModel
	assert(dropModel and storage and template and template:IsA("Model"), "RunModel: templateModel must be a Model")

	-- Tunables
	local DROP_RATE   = config.dropRate    or 1.2
	local CASH_VALUE  = config.cashValue   or 10
	local LIFETIME    = config.lifetime    -- nil = until collected
	local SCALE       = config.scaleFactor or 1.0
	local EXTRA_LOWER = config.extraLower  or 0.35
	local FADE_TIME   = config.fadeTime    or 0.35
	local YAW         = math.rad(config.yawDegrees or 0)
	local PREWARM     = config.prewarm     or 0   -- set 0 to avoid initial burst
	local GROUP       = config.dropGroup   or "Drops"
	local PLAYER_GRP  = config.playerGroup or "Players"
	local DENSITY     = config.density     or 0.7
	local FRICTION    = config.friction    or 0.3
	local ELASTICITY  = config.elasticity  or 0.05
	local CASH_ON     = (config.cashOn == "all") and "all" or "primary"
	local NAME_PREFIX = config.namePrefix  or "Drop_"

	local collectorNames = config.collectorNames or {"Collector","CollectorZone","Receiver","Sell","SellPad"}
	local collectorTags  = config.collectorTags  or {"Collector","SellZone"}

	-- Collision
	setupCollisionGroups(GROUP, PLAYER_GRP)
	setupPlayerCollision(PLAYER_GRP)

	local dropPart = dropModel:WaitForChild("Drop") :: BasePart
	local count = 0

	local function createModel(): Model
		local m = template:Clone()
		local primary = findPrimaryPart(m) or m:FindFirstChildWhichIsA("BasePart", true)
		assert(primary, "RunModel: templateModel has no BasePart")
		m.PrimaryPart = primary

		-- remove existing welds/motors for clean physics
		for _, j in ipairs(m:GetDescendants()) do
			if j:IsA("WeldConstraint") or j:IsA("Motor6D") then j:Destroy() end
		end

		-- scale
		if SCALE ~= 1 then
			local pv = m:GetPivot()
			m:ScaleTo(SCALE)
			m:PivotTo(pv)
		end

		weldAllToPrimary(m, primary)

		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = false
				p.CanTouch = true
				p.CanQuery = true
				p.CanCollide = true
				pcall(function() p.CollisionGroup = GROUP end)
				p.CustomPhysicalProperties = PhysicalProperties.new(DENSITY, FRICTION, ELASTICITY, 1, 1)
			end
		end

		-- cash
		if CASH_ON == "primary" then
			local v = Instance.new("IntValue")
			v.Name = "Cash"; v.Value = CASH_VALUE; v.Parent = primary
		else
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") then
					local v = Instance.new("IntValue")
					v.Name = "Cash"; v.Value = CASH_VALUE; v.Parent = p
				end
			end
		end

		return m
	end

	local function spawnOne(isPrewarm)
		count += 1
		local model = createModel()
		model.Name = NAME_PREFIX .. count

		local primary = model.PrimaryPart :: BasePart

		-- compute spawn pose
		local yawOnly = CFrame.Angles(0, YAW, 0)
		local ext = model:GetExtentsSize()
		local sitY = (ext.Y/2) - EXTRA_LOWER
		local ox = math.random(-2,2) * 0.1
		local oz = math.random(-2,2) * 0.1
		model:PivotTo(CFrame.new(dropPart.Position + Vector3.new(-ox, -sitY, -oz)) * yawOnly)

		-- prepare fade-in
		local parts, decals = {}, {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then d.Transparency = 1; table.insert(parts, d)
			elseif d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1; table.insert(decals, d) end
		end

		-- parent to world
		model.Parent = storage

		-- ✅ KEEP UPRIGHT FEATURE - Prevents tipping on conveyor!
		local keepUprightEnabled = config.keepUpright
		local stabilizeAtt, stabilizeAO
		
		if not isPrewarm then
			primary.AssemblyLinearVelocity = Vector3.new(0,-10,0)
			
			-- Create attachment for stabilization
			stabilizeAtt = Instance.new("Attachment")
			stabilizeAtt.Name = "StabilizeAttachment"
			stabilizeAtt.Parent = primary
			
			stabilizeAO = Instance.new("AlignOrientation")
			stabilizeAO.Mode = Enum.OrientationAlignmentMode.OneAttachment
			stabilizeAO.Attachment0 = stabilizeAtt
			stabilizeAO.RigidityEnabled = true
			stabilizeAO.MaxTorque = keepUprightEnabled and 100000 or math.huge  -- Stronger if keepUpright!
			stabilizeAO.Responsiveness = keepUprightEnabled and 50 or 40  -- Faster correction if keepUpright!
			stabilizeAO.CFrame = yawOnly
			stabilizeAO.Parent = primary
			
			-- If keepUpright is disabled, remove after brief spawn stabilization
			if not keepUprightEnabled then
				Debris:AddItem(stabilizeAO, 0.35)
				Debris:AddItem(stabilizeAtt, 0.35)
			end
			-- If keepUpright is enabled, constraint stays forever (prevents conveyor tipping!)
		end

		-- ✅ CUSTOM onSpawn CALLBACK - Add custom logic after spawn!
		if config.onSpawn and type(config.onSpawn) == "function" then
			pcall(function()
				config.onSpawn(model, primary, GROUP)
			end)
		end

		-- fade-in (limit tween count to avoid spikes)
		local ti = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		-- FIX: Fade more parts on spawn too! Limit to 50 tweens for performance
		for i, p in ipairs(parts) do 
			if i <= 50 then 
				TweenService:Create(p, ti, {Transparency=0}):Play() 
			else 
				p.Transparency = 0 
			end 
		end
		for i, d in ipairs(decals) do 
			if i <= 50 then 
				TweenService:Create(d, ti, {Transparency=0}):Play() 
			else 
				d.Transparency = 0 
			end 
		end

		-- collection
		local collected = false
		local function collect()
			if collected then return end
			collected = true
			primary.Anchored = true
			primary.CanCollide = false
			primary.CanTouch = false
			local outTi = TweenInfo.new(math.max(FADE_TIME*0.75, 0.2), Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			-- FIX: Fade ALL parts, not just first 10! Limit to 50 tweens max for performance
			for i, p in ipairs(parts) do 
				if i <= 50 then 
					TweenService:Create(p, outTi, {Transparency=1}):Play() 
				else 
					p.Transparency = 1 
				end 
			end
			for i, d in ipairs(decals) do 
				if i <= 50 then 
					TweenService:Create(d, outTi, {Transparency=1}):Play() 
				else 
					d.Transparency = 1 
				end 
			end
			task.delay(math.max(FADE_TIME*0.75,0.2)+0.1, function() if model then model:Destroy() end end)
		end

		primary.Touched:Connect(function(hit) if isCollectorPart(hit, collectorNames, collectorTags) then collect() end end)
		for _, p in ipairs(parts) do
			if p ~= primary then
				p.Touched:Connect(function(hit) if isCollectorPart(hit, collectorNames, collectorTags) then collect() end end)
			end
		end

		if LIFETIME and LIFETIME > 0 then
			task.delay(LIFETIME, function() if not collected then collect() end end)
		end
	end

	-- optional prewarm (set prewarm=0 to prevent initial burst)
	for i = 1, PREWARM do spawnOne(true) task.wait(0.05) end

	while true do
		task.wait(DROP_RATE)
		spawnOne(false)
	end
end

return Core
