--!strict
-- HelloKitty Dropper v5.0 — Converted to Bulletproof Architecture
-- • Uses DropperCore's object pooling system
-- • Fresh templates from ReplicatedStorage every time
-- • No more corruption or falling apart issues
-- • Same visual effects and behavior as before

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- References
local PartStorage = workspace:WaitForChild("PartStorage")
local templateModel = ReplicatedStorage:WaitForChild("CinnamonRoll")
local dropPart = script.Parent:WaitForChild("Drop")

-- Configuration
local DROP_RATE = 1.5
local CASH_VALUE = 12
local LIFETIME = 20
local SCALE_FACTOR = 1.2

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
	
	-- Also make sure they don't collide with ice cream drops
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(dropGroup, "Dropper5Orbs", false)
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

local function prepareTemplate(sourceModel: Model, scale: number): Model
	-- ALWAYS create fresh clone from ReplicatedStorage - no caching!
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
		for _, part in ipairs(template:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Size = part.Size * scale
				if part:FindFirstChild("Mesh") then
					part.Mesh.Scale = part.Mesh.Scale * scale
				end
			elseif part:IsA("SpecialMesh") then
				part.Scale = part.Scale * scale
			end
		end
	end
	
	-- Create welded assembly
	if primary then
		createWeldedAssembly(template, primary)
	end
	
	-- Hide template
	template.Parent = nil
	
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

function DropPool.new(sourceModel: Model, scale: number, config: {
	dropGroup: string,
	density: number,
	friction: number,
	elasticity: number,
	cashValue: number,
	cashOn: "primary" | "all",
	prewarmCount: number
})
	local self = setmetatable({}, DropPool)
	
	self._sourceModel = sourceModel
	self._scale = scale
	self._config = config
	self._availableItems = {} :: {DropItem}
	self._activeItems = {} :: {[Model]: DropItem}
	self._prewarmCount = math.max(config.prewarmCount or 4, 0)
	
	-- Prewarm the pool with fresh templates
	for _ = 1, self._prewarmCount do
		local item = self:_createNewItem()
		self:_resetItem(item)
		table.insert(self._availableItems, item)
	end
	
	return self
end

function DropPool:_createNewItem(): DropItem
	-- Create fresh template from source model each time
	local template = prepareTemplate(self._sourceModel, self._scale)
	local model = template:Clone()
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
		   descendant:IsA("PointLight") or descendant:IsA("IntValue") or
		   descendant:IsA("VectorForce") or descendant:IsA("ParticleEmitter") then
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
		part.Transparency = 0.7 -- Start with slight transparency for fade-in
		
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
	-- Add cash values to ALL parts (matching original behavior)
	for _, part in ipairs(item.parts) do
		local cashValue = Instance.new("IntValue")
		cashValue.Name = "Cash"
		cashValue.Value = self._config.cashValue
		cashValue.Parent = part
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

local function createSpawnEffects(item: DropItem)
	-- Fade-in effect (matching original)
	for _, part in ipairs(item.parts) do
		TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 0
		}):Play()
	end
	
	for _, decal in ipairs(item.decals) do
		if decal:IsA("Decal") or decal:IsA("Texture") then
			local originalTransparency = decal.Transparency
			decal.Transparency = 1
			TweenService:Create(decal, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = originalTransparency
			}):Play()
		end
	end
	
	-- Light flash
	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 6
	light.Color = Color3.new(1, 1, 1)
	light.Parent = item.primary
	TweenService:Create(light, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0.4
	}):Play()
	Debris:AddItem(light, 0.6)
	
	-- Spawn ring particle effect
	local ring = Instance.new("ParticleEmitter")
	ring.Texture = "rbxassetid://262979222"
	ring.Rate = 0
	ring.Speed = NumberRange.new(0)
	ring.Lifetime = NumberRange.new(0.3)
	ring.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 2)
	})
	ring.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 1)
	})
	ring.Color = ColorSequence.new(Color3.new(1, 1, 1))
	ring.Parent = item.primary
	ring:Emit(1)
	Debris:AddItem(ring, 1)
end

-- =========================
-- MAIN DROPPER SYSTEM
-- =========================

-- Check PrimaryPart
if not templateModel.PrimaryPart then
	warn("ERROR: CinnamonRoll model needs PrimaryPart set!")
	return
end

-- Setup collision groups
local DROP_GROUP = "CinnamonRollDrops"
local PLAYER_GROUP = "Players"

setupCollisionGroups(DROP_GROUP, PLAYER_GROUP)
tagCharacterParts(PLAYER_GROUP)

-- Create pool
local pool = DropPool.new(templateModel, SCALE_FACTOR, {
	dropGroup = DROP_GROUP,
	density = 0.7,
	friction = 0.3,
	elasticity = 0.05,
	cashValue = CASH_VALUE,
	cashOn = "all", -- Cash on all parts like original
	prewarmCount = 6
})

local collectorNames = {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad"}
local collectorTags = {"Collector", "SellZone"}

local dropCount = 0

-- Main drop loop
while true do
	task.wait(DROP_RATE)
	dropCount += 1
	
	local item = pool:acquire()
	item.model.Name = "CinnamonRoll_" .. dropCount
	
	-- Calculate spawn position with rotation (matching original)
	local offsetX = math.random(-2, 2) * 0.1
	local offsetZ = math.random(-2, 2) * 0.1
	
	-- Position BELOW the dropper with 180 degree rotation to flip it right-side up
	local spawnCFrame = dropPart.CFrame * CFrame.new(offsetX, 2, offsetZ) * CFrame.Angles(math.rad(180), 0, 0)
	item.model:SetPrimaryPartCFrame(spawnCFrame)
	
	-- Add orientation stabilizer (matching original)
	local attachment = Instance.new("Attachment")
	attachment.Parent = item.primary
	
	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.MaxTorque = 10000
	alignOrientation.Responsiveness = 10
	alignOrientation.CFrame = item.primary.CFrame
	alignOrientation.Parent = item.primary
	
	-- Controlled descent (matching original)
	local vectorForce = Instance.new("VectorForce")
	vectorForce.Attachment0 = attachment
	vectorForce.Force = Vector3.new(0, workspace.Gravity * item.primary.AssemblyMass * 0.8, 0)
	vectorForce.Parent = item.primary
	
	-- Give initial downward push
	item.primary.AssemblyLinearVelocity = Vector3.new(0, -10, 0)
	
	-- Remove controls after a short time
	task.delay(0.8, function()
		if alignOrientation and alignOrientation.Parent then
			alignOrientation:Destroy()
		end
		if vectorForce and vectorForce.Parent then
			vectorForce:Destroy()
		end
	end)
	
	-- Set spawn time attribute
	item.primary:SetAttribute("SpawnTime", tick())
	
	-- Show item with effects
	item.model.Parent = PartStorage
	createSpawnEffects(item)
	
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
		for _, part in ipairs(item.parts) do
			TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1
			}):Play()
		end
		
		task.delay(0.3, function()
			pool:release(item)
		end)
	end
	
	-- Setup collection detection
	for _, part in ipairs(item.parts) do
		local connection = part.Touched:Connect(function(hit)
			if isCollectorPart(hit, collectorNames, collectorTags) then
				collectItem()
			end
		end)
		table.insert(item.connections, connection)
	end
	
	-- Lifetime cleanup
	task.delay(LIFETIME, function()
		if not collected then
			collectItem()
		end
	end)
end