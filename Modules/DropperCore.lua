--!strict

-- DropperCore v4.5 — Collision-safe, weld-safe, scale-safe
-- - Drops collide with world/conveyors, NOT with players, NOT with other drops
-- - Fresh clone per drop (no shared state), stable orientation at spawn, smooth fade
-- - Collector detection by name/tag/attribute

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Core = {}

type CashOn = "primary" | "all"

type RunModelConfig = {
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
	cashOn: CashOn?,

	collectorNames: {string}?,
	collectorTags: {string}?,
}

-- Utils
local function findPrimaryPart(model: Model): BasePart?
	if model.PrimaryPart then return model.PrimaryPart end
	local best: BasePart? = nil
	local bestVolume = -1.0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > bestVolume then
				bestVolume = v
				best = d
			end
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
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(playerGroup)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(dropGroup, playerGroup, false)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(dropGroup, dropGroup, false)
	end)
end

local function tagCharacterPartsAsPlayerGroup(playerGroup: string)
	local function setCharacterGroup(character: Model)
		task.wait(0.1)
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("BasePart") then
				pcall(function()
					d.CollisionGroup = playerGroup
				end)
			end
		end
	end

	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(setCharacterGroup)
	end)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then setCharacterGroup(plr.Character) end
	end
end

local function isCollectorPart(hit: Instance?, names: {string}, tags: {string}): boolean
	local part = hit
	if not (part and part:IsA("BasePart")) then return false end
	local lowerName = string.lower(part.Name)
	local parentLower = part.Parent and string.lower(part.Parent.Name) or ""

	for _, want in ipairs(names) do
		local w = string.lower(want)
		if lowerName == w or parentLower == w then return true end
	end
	if lowerName:find("collect") or parentLower:find("collect") or lowerName:find("sell") or parentLower:find("sell") then
		return true
	end
	for _, t in ipairs(tags) do
		if CollectionService:HasTag(part, t) or (part.Parent and CollectionService:HasTag(part.Parent, t)) then
			return true
		end
	end
	if part:GetAttribute("Collector") == true then return true end
	if part.Parent and part.Parent:FindFirstChild("Collector") then return true end
	return false
end

local function createFreshDropModel(
	template: Model,
	scale: number,
	dropGroup: string,
	density: number, friction: number, elasticity: number,
	cashValue: number, cashOn: CashOn
): Model
	local model = template:Clone()
	local primary = findPrimaryPart(model) or model:FindFirstChildWhichIsA("BasePart", true)
	if primary then model.PrimaryPart = primary end

	for _, j in ipairs(model:GetDescendants()) do
		if j:IsA("WeldConstraint") or j:IsA("Motor6D") then j:Destroy() end
	end

	if scale ~= 1 then
		local pivot = model:GetPivot()
		model:ScaleTo(scale)
		model:PivotTo(pivot)
	end

	if primary then weldAllParts(model, primary) end

	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanTouch = true
			p.CanQuery = true
			p.CanCollide = true
			pcall(function() p.CollisionGroup = dropGroup end)
			p.CustomPhysicalProperties = PhysicalProperties.new(density, friction, elasticity, 1, 1)
		end
	end

	if cashOn == "primary" then
		if primary then
			local v = Instance.new("IntValue")
			v.Name = "Cash"
			v.Value = cashValue
			v.Parent = primary
		end
	else
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				local v = Instance.new("IntValue")
				v.Name = "Cash"
				v.Value = cashValue
				v.Parent = p
			end
		end
	end

	return model
end

function Core.RunModel(config: RunModelConfig)
	local dropModel = config.model
	local dropPart = dropModel:WaitForChild("Drop") :: BasePart
	local storage = config.partStorage
	local template = config.templateModel
	assert(template, "RunModel requires config.templateModel")

	local DROP_RATE = config.dropRate or 1.2
	local CASH_VALUE = config.cashValue or 10
	local SCALE = config.scaleFactor or 1.0
	local EXTRA_LOWER = config.extraLower or 0.35
	local FADE_TIME = config.fadeTime or 0.35
	local LIFETIME = config.lifetime
	local GROUP = config.dropGroup or "Drops"
	local PLAYER_GRP = config.playerGroup or "Players"
	local DENSITY = config.density or 0.7
	local FRICTION = config.friction or 0.3
	local ELASTICITY = config.elasticity or 0.05
	local YAW = config.yawDegrees or 0
	local CASH_ON: CashOn = config.cashOn or "primary"

	local collectorNames = config.collectorNames or { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" }
	local collectorTags = config.collectorTags or { "Collector", "SellZone" }
	local NAME_PREFIX = config.namePrefix or "Drop_"

	setupCollisionGroups(GROUP, PLAYER_GRP)
	tagCharacterPartsAsPlayerGroup(PLAYER_GRP)

	local patternIndex = 1
	local spawnOffsets = {
		Vector3.new(0.25, 0, 0.25),
		Vector3.new(-0.25, 0, 0.25),
		Vector3.new(0.25, 0, -0.25),
		Vector3.new(-0.25, 0, -0.25),
		Vector3.new(0, 0, 0),
	}

	local count = 0
	while true do
		task.wait(DROP_RATE)
		count += 1

		local model = createFreshDropModel(template, SCALE, GROUP, DENSITY, FRICTION, ELASTICITY, CASH_VALUE, CASH_ON)
		model.Name = NAME_PREFIX .. tostring(count)

		local primary = findPrimaryPart(model) :: BasePart
		local parts: {BasePart} = {}
		local decals: {Instance} = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then table.insert(parts, d) end
			if d:IsA("Decal") or d:IsA("Texture") then table.insert(decals, d) end
		end

		primary.AssemblyLinearVelocity = Vector3.zero
		primary.AssemblyAngularVelocity = Vector3.zero

		local offset = spawnOffsets[patternIndex]
		patternIndex = (patternIndex % #spawnOffsets) + 1

		local extents = model:GetExtentsSize()
		local sitY = (extents.Y / 2) - 0.6
		local spawnPos = dropPart.Position + Vector3.new(-offset.X, -(sitY + EXTRA_LOWER), -offset.Z)
		local yawCFrame = CFrame.Angles(0, math.rad(YAW), 0)
		model:PivotTo(CFrame.new(spawnPos) * yawCFrame)

		do
			local att = Instance.new("Attachment"); att.Parent = primary
			local ao = Instance.new("AlignOrientation")
			ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
			ao.Attachment0 = att
			ao.RigidityEnabled = true
			ao.Responsiveness = 40
			ao.CFrame = yawCFrame
			ao.Parent = primary
			Debris:AddItem(ao, 0.4); Debris:AddItem(att, 0.4)
		end

		primary.AssemblyLinearVelocity = Vector3.new(0, -9, 0)
		primary:SetAttribute("SpawnTime", os.clock())

		for _, p in ipairs(parts) do p.Transparency = 1 end
		for _, d in ipairs(decals) do
			if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
		end

		model.Parent = storage

		local ti = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		for i, p in ipairs(parts) do
			if i <= 12 then
				TweenService:Create(p, ti, { Transparency = 0 }):Play()
			else
				p.Transparency = 0
			end
		end
		for i, d in ipairs(decals) do
			if i <= 12 and (d:IsA("Decal") or d:IsA("Texture")) then
				TweenService:Create(d, ti, { Transparency = 0 }):Play()
			else
				if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 0 end
			end
		end

		do
			local light = Instance.new("PointLight")
			light.Brightness = 1.0; light.Range = 6; light.Color = Color3.new(1,1,1); light.Parent = primary
			TweenService:Create(light, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0.35 }):Play()
			Debris:AddItem(light, 0.6)
		end

		local collected = false
		local connections: {RBXScriptConnection} = {}

		local function collectAndFade()
			if collected then return end
			collected = true
			for _, c in ipairs(connections) do if c.Connected then c:Disconnect() end end

			primary.Anchored = true
			primary.CanCollide = false
			primary.CanTouch = false

			local fadeOut = TweenInfo.new(math.max(FADE_TIME * 0.75, 0.2), Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			for i, p in ipairs(parts) do
				if i <= 10 then
					TweenService:Create(p, fadeOut, { Transparency = 1 }):Play()
				else
					p.Transparency = 1
				end
			end
			for i, d in ipairs(decals) do
				if i <= 10 and (d:IsA("Decal") or d:IsA("Texture")) then
					TweenService:Create(d, fadeOut, { Transparency = 1 }):Play()
				else
					if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
				end
			end

			task.delay(math.max(FADE_TIME * 0.75, 0.2) + 0.1, function()
				model:Destroy()
			end)
		end

		local primaryTouched = primary.Touched:Connect(function(hit)
			if collected then return end
			if isCollectorPart(hit, collectorNames, collectorTags) then collectAndFade() end
		end)
		table.insert(connections, primaryTouched)

		for _, p in ipairs(parts) do
			if p ~= primary then
				local conn = p.Touched:Connect(function(hit)
					if collected then return end
					if isCollectorPart(hit, collectorNames, collectorTags) then collectAndFade() end
				end)
				table.insert(connections, conn)
			end
		end

		if LIFETIME and LIFETIME > 0 then
			task.delay(LIFETIME, function()
				if not collected then collectAndFade() end
			end)
		end
	end
end

function Core.Run(_)
	error("Use RunModel(config) in DropperCore v4.5")
end

return Core
