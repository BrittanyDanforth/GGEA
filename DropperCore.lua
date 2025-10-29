--[[
	DropperCore v5.1 - FIXED FADE OUT + MULTI-TYCOON SAFE
	
	🔧 NEW IN v5.1:
	✅ FIXED: Fade out actually works now (was destroying too fast!)
	✅ FIXED: Fades ALL parts (removed 50-part limit)
	✅ FIXED: Waits for tweens to complete before destroying
	✅ FIXED: Stops physics during fade (no jitter)
	✅ FIXED: Destroys stabilization constraints during collection
	✅ ADDED: Debug logging to see fade in action
	
	🛡️ MULTI-TYCOON FEATURES:
	✅ Auto-tags drops with TycoonId attribute
	✅ Auto-tags drops with DropId GUID
	✅ getTycoonId() helper finds parent tycoon
	✅ Safe for 4+ tycoons
]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local Core = {}

-- All dropper groups for collision prevention
local ALL_DROPPER_GROUPS = {
	"KuromiOrbs1", "KuromiOrbs2", "KuromiOrbs3",
	"KuromiOrbs6", "KuromiOrbs8", "KuromiOrbs9", "KuromiOrbs10",
	"KuromiOrbs11", "KuromiOrbs12", "KuromiOrbs13",
	"CinnamorollOrbs", "CinnamorollOrbs1", "CinnamorollOrbs2", "CinnamorollOrbs3",
	"CinnamorollOrbs4", "CinnamorollOrbs5", "CinnamorollOrbs6",
	"CinnamorollOrbs8", "CinnamorollOrbs9", "CinnamorollOrbs10",
	"HelloKittyDrops", "HelloKittyDrops1", "HelloKittyDrops2", "HelloKittyDrops3",
	"HelloKittyDrops4", "HelloKittyDrops5", "HelloKittyDrops6",
	"HelloKittyDrops8", "HelloKittyDrops9", "HelloKittyDrops10",
	"MyMelodyDrops", "MyMelodyDrops1", "MyMelodyDrops2",
	"Dropper5Orbs",
	"Drops"
}

--============================
-- 🛡️ MULTI-TYCOON HELPER
--============================
local function getTycoonId(dropperModel)
	local possibleAncestors = {
		"Tycoon", "Kuromi", "Cinnamoroll", "HelloKitty", "Hellokitty", "MyMelody", "Tycoons"
	}

	local tycoon = nil
	for _, ancestorName in ipairs(possibleAncestors) do
		tycoon = dropperModel:FindFirstAncestor(ancestorName)
		if tycoon then break end
	end

	if not tycoon then
		local current = dropperModel.Parent
		local searchDepth = 0
		while current and current ~= game and current ~= workspace do
			local lowerName = string.lower(current.Name)
			if lowerName:find("tycoon") or lowerName:find("kuromi") or 
			   lowerName:find("cinnamoroll") or lowerName:find("hello") or 
			   lowerName:find("kitty") or lowerName:find("melody") then
				tycoon = current
				break
			end
			current = current.Parent
			searchDepth = searchDepth + 1
			if searchDepth > 15 then break end
		end
	end

	if tycoon then
		local id = tycoon:GetAttribute("TycoonId")
		if id then
			return id, tycoon
		else
			return tycoon.Name, tycoon
		end
	end

	warn("[DropperCore] ❌ Could not find parent tycoon for dropper:", dropperModel:GetFullName())
	return nil, nil
end

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
	for _, plr in ipairs(Players:GetPlayers()) do 
		if plr.Character then tagChar(plr.Character) end 
	end
end

local function isCollectorPart(hit: Instance?, names: {string}, tags: {string}): boolean
	if not (hit and hit:IsA("BasePart")) then return false end

	local n = string.lower(hit.Name)
	local pn = hit.Parent and string.lower(hit.Parent.Name) or ""

	for _, want in ipairs(names) do
		local w = string.lower(want)
		if n == w or pn == w then return true end
	end

	if n:find("collect") or pn:find("collect") or n:find("sell") or pn:find("sell") then 
		return true 
	end

	for _, t in ipairs(tags) do
		if CollectionService:HasTag(hit, t) or (hit.Parent and CollectionService:HasTag(hit.Parent, t)) then
			return true
		end
	end

	if hit:GetAttribute("Collector") == true then return true end
	if hit.Parent and hit.Parent:FindFirstChild("Collector") then return true end

	return false
end

local function findPrimaryPart(model: Model): BasePart?
	if model.PrimaryPart then return model.PrimaryPart end

	local best, vol = nil, -1
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > vol then 
				vol = v
				best = d 
			end
		end
	end

	if best then model.PrimaryPart = best end
	return best
end

local function weldAllToPrimary(model: Model, primary: BasePart)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= primary then
			local w = Instance.new("WeldConstraint")
			w.Part0 = primary
			w.Part1 = d
			w.Parent = primary
		end
	end
end

--============================
-- PUBLIC: Core.RunModel (FIXED FADE OUT!)
--============================
function Core.RunModel(config)
	local dropModel = config.model
	local storage = config.partStorage
	local template = config.templateModel
	assert(dropModel and storage and template and template:IsA("Model"), "RunModel: templateModel must be a Model")

	local TYCOON_ID, TYCOON_INST = getTycoonId(dropModel)
	if not TYCOON_ID or not TYCOON_INST then
		warn("[DropperCore.RunModel] ❌ No tycoon found. Refusing to spawn.")
		return
	end

	if not config.partStorage or not config.partStorage:IsDescendantOf(TYCOON_INST) then
		local essentials = TYCOON_INST:FindFirstChild("Essentials")
		local fallback = essentials and essentials:FindFirstChild("PartStorage")
		if fallback then
			config.partStorage = fallback
			storage = fallback
		end
	end

	local DROP_RATE = config.dropRate or 1.2
	local CASH_VALUE = config.cashValue or 10
	local LIFETIME = config.lifetime
	local SCALE = config.scaleFactor or 1.0
	local EXTRA_LOWER = config.extraLower or 0.35
	local FADE_TIME = config.fadeTime or 0.35
	local YAW = math.rad(config.yawDegrees or 0)
	local PREWARM = config.prewarm or 0
	local GROUP = config.dropGroup or "Drops"
	local PLAYER_GRP = config.playerGroup or "Players"
	local DENSITY = config.density or 0.7
	local FRICTION = config.friction or 0.3
	local ELASTICITY = config.elasticity or 0.05
	local CASH_ON = (config.cashOn == "all") and "all" or "primary"
	local NAME_PREFIX = config.namePrefix or "Drop_"

	local collectorNames = config.collectorNames or {"Collector", "CollectorZone", "Receiver", "Sell", "SellPad", "PartCollector"}
	local collectorTags = config.collectorTags or {"Collector", "SellZone"}

	setupCollisionGroups(GROUP, PLAYER_GRP)
	setupPlayerCollision(PLAYER_GRP)

	local dropPart = dropModel:WaitForChild("Drop") :: BasePart
	local count = 0

	local function createModel(): Model
		local m = template:Clone()
		local primary = findPrimaryPart(m) or m:FindFirstChildWhichIsA("BasePart", true)
		assert(primary, "RunModel: templateModel has no BasePart")
		m.PrimaryPart = primary

		for _, j in ipairs(m:GetDescendants()) do
			if j:IsA("WeldConstraint") or j:IsA("Motor6D") then j:Destroy() end
		end

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
				p:SetAttribute("TycoonId", TYCOON_ID)
				CollectionService:AddTag(p, "TycoonDrop")
			end
		end

		if CASH_ON == "primary" then
			local v = Instance.new("IntValue")
			v.Name = "Cash"
			v.Value = CASH_VALUE
			v.Parent = primary
		else
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") then
					local v = Instance.new("IntValue")
					v.Name = "Cash"
					v.Value = CASH_VALUE
					v.Parent = p
				end
			end
		end

		return m
	end

	local function spawnOne(isPrewarm)
		count += 1
		local model = createModel()
		model.Name = NAME_PREFIX .. count

		model:SetAttribute("TycoonId", TYCOON_ID)
		model:SetAttribute("DropId", HttpService:GenerateGUID(false))
		CollectionService:AddTag(model, "TycoonDrop")

		local primary = model.PrimaryPart :: BasePart

		local yawOnly = CFrame.Angles(0, YAW, 0)
		local ext = model:GetExtentsSize()
		local sitY = (ext.Y / 2) - EXTRA_LOWER
		local ox = math.random(-2, 2) * 0.1
		local oz = math.random(-2, 2) * 0.1
		model:PivotTo(CFrame.new(dropPart.Position + Vector3.new(-ox, -sitY, -oz)) * yawOnly)

		-- Prepare fade-in
		local parts, decals = {}, {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 1
				table.insert(parts, d)
			elseif d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = 1
				table.insert(decals, d)
			end
		end

		model.Parent = storage

		-- ✅ KEEP UPRIGHT FEATURE
		local keepUprightEnabled = config.keepUpright
		local stabilizeAtt, stabilizeAO

		if not isPrewarm then
			primary.AssemblyLinearVelocity = Vector3.new(0, -10, 0)

			stabilizeAtt = Instance.new("Attachment")
			stabilizeAtt.Name = "StabilizeAttachment"
			stabilizeAtt.Parent = primary

			stabilizeAO = Instance.new("AlignOrientation")
			stabilizeAO.Mode = Enum.OrientationAlignmentMode.OneAttachment
			stabilizeAO.Attachment0 = stabilizeAtt
			stabilizeAO.RigidityEnabled = true
			stabilizeAO.MaxTorque = keepUprightEnabled and 100000 or math.huge
			stabilizeAO.Responsiveness = keepUprightEnabled and 50 or 40
			stabilizeAO.CFrame = yawOnly
			stabilizeAO.Parent = primary

			if not keepUprightEnabled then
				Debris:AddItem(stabilizeAO, 0.35)
				Debris:AddItem(stabilizeAtt, 0.35)
			end
		end

		-- ✅ FIXED: Fade-in animation (fade ALL parts, no limit!)
		if not isPrewarm then
			local ti = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

			for _, p in ipairs(parts) do
				if p and p.Parent then
					TweenService:Create(p, ti, {Transparency = 0}):Play()
				end
			end

			for _, d in ipairs(decals) do
				if d and d.Parent then
					TweenService:Create(d, ti, {Transparency = 0}):Play()
				end
			end
		else
			for _, p in ipairs(parts) do p.Transparency = 0 end
			for _, d in ipairs(decals) do d.Transparency = 0 end
		end

		-- ✅ FIXED: Collection logic with PROPER fade out!
		local collected = false

		local function collect()
			if collected then return end
			collected = true

			print("💰 [DropperCore] Collecting:", model.Name)

			-- ✅ STOP PHYSICS IMMEDIATELY (prevents jitter during fade)
			primary.Anchored = true
			primary.CanCollide = false
			primary.CanTouch = false
			primary.AssemblyLinearVelocity = Vector3.zero
			primary.AssemblyAngularVelocity = Vector3.zero

			-- ✅ DESTROY STABILIZATION (prevents constraint interference)
			if stabilizeAO and stabilizeAO.Parent then stabilizeAO:Destroy() end
			if stabilizeAtt and stabilizeAtt.Parent then stabilizeAtt:Destroy() end

			-- ✅ CALCULATE FADE DURATION
			local fadeDuration = math.max(FADE_TIME * 0.75, 0.25)
			local outTi = TweenInfo.new(fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

			print("✨ [DropperCore] Fading out over", fadeDuration, "seconds...")

			-- ✅ FADE OUT ALL PARTS (NO 50-PART LIMIT!)
			local tweens = {}
			for _, p in ipairs(parts) do
				if p and p.Parent then
					local tw = TweenService:Create(p, outTi, {Transparency = 1})
					tw:Play()
					table.insert(tweens, tw)
				end
			end

			-- ✅ FADE OUT ALL DECALS
			for _, d in ipairs(decals) do
				if d and d.Parent then
					local tw = TweenService:Create(d, outTi, {Transparency = 1})
					tw:Play()
					table.insert(tweens, tw)
				end
			end

			print("🎬 [DropperCore] Started", #tweens, "fade tweens")

			-- ✅ WAIT FOR TWEENS TO COMPLETE BEFORE DESTROYING!
			task.delay(fadeDuration + 0.15, function()
				if model and model.Parent then
					print("🗑️ [DropperCore] Destroying:", model.Name)
					model:Destroy()
				end
			end)
		end

		-- Connect collection to primary part
		primary.Touched:Connect(function(hit)
			if isCollectorPart(hit, collectorNames, collectorTags) then
				print("👆 [DropperCore] Primary part touched collector:", hit.Name)
				collect()
			end
		end)

		-- Connect collection to all other parts (for "cashOn = all" mode)
		if CASH_ON == "all" then
			for _, p in ipairs(parts) do
				if p ~= primary then
					p.Touched:Connect(function(hit)
						if isCollectorPart(hit, collectorNames, collectorTags) then
							print("👆 [DropperCore] Secondary part touched collector:", hit.Name)
							collect()
						end
					end)
				end
			end
		end

		-- ✅ Auto-despawn after lifetime (uses fade, not instant destroy!)
		if LIFETIME and LIFETIME > 0 then
			task.delay(LIFETIME, function()
				if not collected then
					print("⏱️ [DropperCore] Lifetime expired for:", model.Name)
					collect()  -- Fade out instead of instant destroy!
				end
			end)
		end
	end

	-- Prewarm
	for i = 1, PREWARM do
		spawnOne(true)
		task.wait(0.05)
	end

	-- Main drop loop
	while true do
		task.wait(DROP_RATE)
		spawnOne(false)
	end
end

return Core
