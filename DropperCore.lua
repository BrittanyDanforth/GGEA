--!strict
-- DropperCore v5.0 — Complete Rewrite: Bulletproof Object Pooling
-- • Immutable template system — no state corruption
-- • Deep clone pool with complete reset between uses
-- • Primary-only collision with welded assembly
-- • Robust collection detection with debouncing
-- • Zero GC spikes, zero falling apart issues

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Core = {}

-- =========================
-- UTILITY FUNCTIONS
-- =========================

local function findPrimaryPart(model: Model): BasePart?
	if model.PrimaryPart then 
		return model.PrimaryPart 
	end
	
	local best: BasePart? = nil
	local largestVolume = -1
	
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
			if volume > largestVolume then
				largestVolume = volume
				best = descendant
			end
		end
	end
	
	return best
end

local function createWeldedAssembly(model: Model, primary: BasePart)
	-- Remove any existing constraints first
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("WeldConstraint") or descendant:IsA("Motor6D") then
			descendant:Destroy()
		end
	end
	
	-- Create new welds
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= primary then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = primary
			weld.Part1 = descendant
			weld.Parent = primary
		end
	end
end

local function setupCollisionGroups(dropGroup: string, playerGroup: string)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(dropGroup)
		PhysicsService:RegisterCollisionGroup(playerGroup)
	end)
	
	pcall(function() 
		PhysicsService:CollisionGroupSetCollidable(dropGroup, playerGroup, false) 
	end)
	pcall(function() 
		PhysicsService:CollisionGroupSetCollidable(dropGroup, dropGroup, false) 
	end)
end

local function tagCharacterParts(playerGroup: string)
	local function tagCharacter(character: Model)
		task.wait(0.1) -- Let character fully load
		for _, descendant in ipairs(character:GetDescendants()) do
			if descendant:IsA("BasePart") then
				pcall(function() 
					descendant.CollisionGroup = playerGroup 
				end)
			end
		end
	end
	
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(tagCharacter)
	end)
	
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then 
			tagCharacter(player.Character) 
		end
	end
end

local function isCollectorPart(hit: Instance?, collectorNames: {string}, collectorTags: {string}): boolean
	if not hit or not hit:IsA("BasePart") then
		return false
	end
	
	local partName = string.lower(hit.Name)
	local parentName = hit.Parent and string.lower(hit.Parent.Name) or ""
	
	-- Check exact name matches
	for _, name in ipairs(collectorNames) do
		local targetName = string.lower(name)
		if partName == targetName or parentName == targetName then
			return true
		end
	end
	
	-- Check fuzzy matches
	if partName:find("collect") or parentName:find("collect") or 
	   partName:find("sell") or parentName:find("sell") then
		return true
	end
	
	-- Check CollectionService tags
	for _, tag in ipairs(collectorTags) do
		if CollectionService:HasTag(hit, tag) or 
		   (hit.Parent and CollectionService:HasTag(hit.Parent, tag)) then
			return true
		end
	end
	
	-- Check attributes
	if hit:GetAttribute("Collector") == true then
		return true
	end
	
	if hit.Parent and hit.Parent:FindFirstChild("Collector") then
		return true
	end
	
	return false
end

-- =========================
-- TEMPLATE MANAGEMENT
-- =========================

local TemplateCache = {}

local function prepareTemplate(sourceModel: Model, scale: number): Model
	local cacheKey = sourceModel
	local cached = TemplateCache[cacheKey]
	
	if cached and cached.Parent == nil then
		return cached
	end
	
	-- Create fresh clone
	local template = sourceModel:Clone()
	local primary = findPrimaryPart(template)
	
	if primary then
		template.PrimaryPart = primary
	end
	
	-- Clean up any existing constraints
	for _, descendant in ipairs(template:GetDescendants()) do
		if descendant:IsA("WeldConstraint") or descendant:IsA("Motor6D") then
			descendant:Destroy()
		end
	end
	
	-- Apply scaling if needed
	if scale ~= 1 then
		local pivot = template:GetPivot()
		template:ScaleTo(scale)
		template:PivotTo(pivot)
	end
	
	-- Create welded assembly
	if primary then
		createWeldedAssembly(template, primary)
	end
	
	-- Hide template
	template.Parent = nil
	TemplateCache[cacheKey] = template
	
	return template
end

-- =========================
-- OBJECT POOL SYSTEM
-- =========================

type DropItem = {
	model: Model,
	primary: BasePart,
	parts: {BasePart},
	decals: {Instance},
	connections: {RBXScriptConnection},
	isActive: boolean
}

local DropPool = {}
DropPool.__index = DropPool

function DropPool.new(template: Model, config: {
	dropGroup: string,
	density: number,
	friction: number,
	elasticity: number,
	cashValue: number,
	cashOn: "primary" | "all",
	prewarmCount: number
})
	local self = setmetatable({}, DropPool)
	
	self._template = template
	self._config = config
	self._availableItems = {} :: {DropItem}
	self._activeItems = {} :: {[Model]: DropItem}
	self._prewarmCount = math.max(config.prewarmCount or 4, 0)
	
	-- Prewarm the pool
	for _ = 1, self._prewarmCount do
		local item = self:_createNewItem()
		self:_resetItem(item)
		table.insert(self._availableItems, item)
	end
	
	return self
end

function DropPool:_createNewItem(): DropItem
	local model = self._template:Clone()
	local primary = findPrimaryPart(model) :: BasePart
	local parts = {}
	local decals = {}
	
	-- Collect all parts and decals
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			table.insert(decals, descendant)
		end
	end
	
	return {
		model = model,
		primary = primary,
		parts = parts,
		decals = decals,
		connections = {},
		isActive = false
	}
end

function DropPool:_resetItem(item: DropItem)
	-- Disconnect all connections
	for _, connection in ipairs(item.connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(item.connections)
	
	-- Clean up any temporary objects
	for _, descendant in ipairs(item.model:GetDescendants()) do
		if descendant:IsA("Attachment") or descendant:IsA("AlignOrientation") or 
		   descendant:IsA("PointLight") or descendant:IsA("IntValue") then
			descendant:Destroy()
		end
	end
	
	-- Reset physics properties
	for _, part in ipairs(item.parts) do
		part.Anchored = false
		part.CanTouch = true
		part.CanQuery = true
		part.CanCollide = (part == item.primary)
		part.Massless = (part ~= item.primary)
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
		part.Transparency = 1
		
		pcall(function()
			part.CollisionGroup = self._config.dropGroup
		end)
		
		part.CustomPhysicalProperties = PhysicalProperties.new(
			self._config.density,
			self._config.friction,
			self._config.elasticity,
			1, 1
		)
	end
	
	-- Reset decal transparency
	for _, decal in ipairs(item.decals) do
		if decal:IsA("Decal") or decal:IsA("Texture") then
			decal.Transparency = 1
		end
	end
	
	-- Hide model
	item.model.Parent = nil
	item.isActive = false
end

function DropPool:_setupItem(item: DropItem)
	-- Add cash values
	if self._config.cashOn == "primary" then
		local cashValue = Instance.new("IntValue")
		cashValue.Name = "Cash"
		cashValue.Value = self._config.cashValue
		cashValue.Parent = item.primary
	else
		for _, part in ipairs(item.parts) do
			local cashValue = Instance.new("IntValue")
			cashValue.Name = "Cash"
			cashValue.Value = self._config.cashValue
			cashValue.Parent = part
		end
	end
	
	item.isActive = true
end

function DropPool:acquire(): DropItem
	local item = table.remove(self._availableItems)
	
	if not item then
		-- Pool exhausted, create new item
		item = self:_createNewItem()
	end
	
	self:_setupItem(item)
	self._activeItems[item.model] = item
	
	return item
end

function DropPool:release(item: DropItem)
	if not item.isActive then
		return -- Already released
	end
	
	self._activeItems[item.model] = nil
	self:_resetItem(item)
	table.insert(self._availableItems, item)
end

-- =========================
-- VISUAL EFFECTS
-- =========================

local function setTransparency(item: DropItem, transparency: number)
	for _, part in ipairs(item.parts) do
		part.Transparency = transparency
	end
	
	for _, decal in ipairs(item.decals) do
		if decal:IsA("Decal") or decal:IsA("Texture") then
			decal.Transparency = transparency
		end
	end
end

local function tweenTransparency(item: DropItem, targetTransparency: number, duration: number, maxTweens: number, easeIn: boolean, onComplete: (() -> ())?)
	local tweenInfo = TweenInfo.new(
		duration,
		Enum.EasingStyle.Quad,
		easeIn and Enum.EasingDirection.In or Enum.EasingDirection.Out
	)
	
	local tweenCount = 0
	
	-- Tween parts
	for _, part in ipairs(item.parts) do
		if tweenCount < maxTweens then
			local tween = TweenService:Create(part, tweenInfo, {Transparency = targetTransparency})
			tween:Play()
			tweenCount += 1
		else
			part.Transparency = targetTransparency
		end
	end
	
	-- Tween decals
	for _, decal in ipairs(item.decals) do
		if tweenCount < maxTweens and (decal:IsA("Decal") or decal:IsA("Texture")) then
			local tween = TweenService:Create(decal, tweenInfo, {Transparency = targetTransparency})
			tween:Play()
			tweenCount += 1
		elseif decal:IsA("Decal") or decal:IsA("Texture") then
			decal.Transparency = targetTransparency
		end
	end
	
	if onComplete then
		task.delay(duration + 0.02, onComplete)
	end
end

local function createSpawnEffects(item: DropItem, fadeTime: number)
	-- Fade in effect
	tweenTransparency(item, 0, fadeTime, 12, false)
	
	-- Size pop effect
	local originalSize = item.primary.Size
	item.primary.Size = Vector3.new(0.1, 0.1, 0.1)
	local sizeTween = TweenService:Create(
		item.primary,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = originalSize}
	)
	sizeTween:Play()
	
	-- Light flash
	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 6
	light.Color = Color3.new(1, 1, 1)
	light.Parent = item.primary
	
	local lightTween = TweenService:Create(
		light,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0.4}
	)
	lightTween:Play()
	
	Debris:AddItem(light, 0.6)
end

-- =========================
-- MAIN DROPPER SYSTEM
-- =========================

function Core.RunModel(config: {
	model: Model,
	partStorage: Instance,
	templateModel: Model,
	
	-- Optional configuration
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
	-- Validate required parameters
	local dropModel = config.model
	local dropPart = dropModel:WaitForChild("Drop") :: BasePart
	local storage = config.partStorage
	local template = config.templateModel
	
	assert(template, "RunModel requires config.templateModel")
	
	-- Configuration with defaults
	local settings = {
		namePrefix = config.namePrefix or "Drop_",
		dropGroup = config.dropGroup or "Drops",
		playerGroup = config.playerGroup or "Players",
		dropRate = config.dropRate or 1.2,
		cashValue = config.cashValue or 10,
		lifetime = config.lifetime,
		scaleFactor = config.scaleFactor or 1.0,
		extraLower = config.extraLower or 0.35,
		fadeTime = config.fadeTime or 0.35,
		density = config.density or 0.7,
		friction = config.friction or 0.3,
		elasticity = config.elasticity or 0.05,
		yawDegrees = config.yawDegrees or 0,
		prewarm = config.prewarm or 6,
		cashOn = config.cashOn or "primary",
		collectorNames = config.collectorNames or {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"},
		collectorTags = config.collectorTags or {"Collector", "SellZone"}
	}
	
	-- Setup collision groups
	setupCollisionGroups(settings.dropGroup, settings.playerGroup)
	tagCharacterParts(settings.playerGroup)
	
	-- Prepare template and create pool
	local preparedTemplate = prepareTemplate(template, settings.scaleFactor)
	local pool = DropPool.new(preparedTemplate, {
		dropGroup = settings.dropGroup,
		density = settings.density,
		friction = settings.friction,
		elasticity = settings.elasticity,
		cashValue = settings.cashValue,
		cashOn = settings.cashOn,
		prewarmCount = settings.prewarm
	})
	
	local dropCount = 0
	
	-- Main drop loop
	while true do
		task.wait(settings.dropRate)
		dropCount += 1
		
		local item = pool:acquire()
		item.model.Name = settings.namePrefix .. tostring(dropCount)
		
		-- Calculate spawn position
		local offsetX = math.random(-2, 2) * 0.1
		local offsetZ = math.random(-2, 2) * 0.1
		local extents = item.model:GetExtentsSize()
		local sitY = (extents.Y / 2) - 0.6
		local spawnPosition = dropPart.Position + Vector3.new(-offsetX, -(sitY + settings.extraLower), -offsetZ)
		local yawRotation = CFrame.Angles(0, math.rad(settings.yawDegrees), 0)
		
		item.model:PivotTo(CFrame.new(spawnPosition) * yawRotation)
		
		-- Add orientation stabilizer
		local attachment = Instance.new("Attachment")
		attachment.Parent = item.primary
		
		local alignOrientation = Instance.new("AlignOrientation")
		alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOrientation.Attachment0 = attachment
		alignOrientation.RigidityEnabled = true
		alignOrientation.Responsiveness = 40
		alignOrientation.CFrame = yawRotation
		alignOrientation.Parent = item.primary
		
		Debris:AddItem(alignOrientation, 0.35)
		Debris:AddItem(attachment, 0.35)
		
		-- Set initial velocity and metadata
		item.primary.AssemblyLinearVelocity = Vector3.new(0, -8, 0)
		item.primary:SetAttribute("SpawnTime", os.clock())
		
		-- Show item with effects
		setTransparency(item, 1)
		item.model.Parent = storage
		createSpawnEffects(item, settings.fadeTime)
		
		-- Collection handling
		local collected = false
		local function collectItem()
			if collected then return end
			collected = true
			
			-- Stop physics
			for _, part in ipairs(item.parts) do
				part.Anchored = true
				part.CanCollide = false
				part.CanTouch = false
			end
			
			-- Fade out and return to pool
			tweenTransparency(item, 1, math.max(settings.fadeTime * 0.75, 0.2), 10, true, function()
				pool:release(item)
			end)
		end
		
		-- Setup collection detection
		for _, part in ipairs(item.parts) do
			local connection = part.Touched:Connect(function(hit)
				if isCollectorPart(hit, settings.collectorNames, settings.collectorTags) then
					collectItem()
				end
			end)
			table.insert(item.connections, connection)
		end
		
		-- Optional lifetime cleanup
		if settings.lifetime and settings.lifetime > 0 then
			task.delay(settings.lifetime, function()
				if not collected then
					collectItem()
				end
			end)
		end
	end
end

-- Legacy compatibility
function Core.Run(config)
	error("Core.Run not implemented in v5.0; use RunModel() for model droppers.")
end

return Core