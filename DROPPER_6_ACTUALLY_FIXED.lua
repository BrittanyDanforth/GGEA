--[[
	Kuromi Dropper 6 - MODERNIZED & LAG-FREE
	✅ FIXED: Collision groups work like 1-3!
	✅ KEPT: Your Kuromi mesh + all effects!
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local DROP_RATE = 1.5
local CASH_VALUE = 12
local SPAWN_HEIGHT_OFFSET = -2.5
local FADE_TIME = 0.4
local LIFETIME = 20

local PHYSICS_DENSITY = 0.1
local PHYSICS_FRICTION = 0.3
local PHYSICS_ELASTICITY = 0.0

-- YOUR KUROMI MESH
local MESH_ID = "http://www.roblox.com/asset?id=160003363"
local TEXTURE_ID = "http://www.roblox.com/asset/?id=192068356"

local DROP_SIZE = Vector3.new(1, 5, 4)

local COLLECTOR_NAMES = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" }
local COLLECTOR_TAGS = { "Collector", "SellZone" }

local DROP_GROUP = "KuromiOrbs6"
local PLAYER_GROUP = "Players"

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

-- FIX: Register ALL collision groups
local function setupCollisionGroups()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(DROP_GROUP)
		PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
		PhysicsService:RegisterCollisionGroup("KuromiOrbs1")
		PhysicsService:RegisterCollisionGroup("KuromiOrbs2")
		PhysicsService:RegisterCollisionGroup("KuromiOrbs3")
		PhysicsService:RegisterCollisionGroup("CinnamorollOrbs4")
		PhysicsService:RegisterCollisionGroup("CinnamorollOrbs5")
		PhysicsService:RegisterCollisionGroup("KuromiOrbs8")
		PhysicsService:RegisterCollisionGroup("KuromiOrbs9")
		PhysicsService:RegisterCollisionGroup("KuromiOrbs10")
		PhysicsService:RegisterCollisionGroup("KuromiOrbs11")
		PhysicsService:RegisterCollisionGroup("KuromiOrbs12")
		PhysicsService:RegisterCollisionGroup("KuromiOrbs13")

		pcall(function() PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, PLAYER_GROUP, false) end)
		pcall(function() PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, DROP_GROUP, false) end)
		pcall(function() PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, "KuromiOrbs1", false) end)
		pcall(function() PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, "KuromiOrbs2", false) end)
		pcall(function() PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, "KuromiOrbs3", false) end)
		pcall(function() PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, "CinnamorollOrbs4", false) end)
		pcall(function() PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, "CinnamorollOrbs5", false) end)
		pcall(function() PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, "KuromiOrbs8", false) end)
		pcall(function() PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, "KuromiOrbs9", false) end)
		pcall(function() PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, "KuromiOrbs10", false) end)
		pcall(function() PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, "KuromiOrbs11", false) end)
		pcall(function() PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, "KuromiOrbs12", false) end)
		pcall(function() PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, "KuromiOrbs13", false) end)
	end)
end

local function setupPlayerCollision(character)
	task.wait(0.1)
	local success, errorMsg = pcall(function()
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CollisionGroup = PLAYER_GROUP
			end
		end
	end)
	if not success then
		warn("Player collision setup failed:", errorMsg)
	end
end

local function initializePlayers()
	local success, errorMsg = pcall(function()
		Players.PlayerAdded:Connect(function(player)
			player.CharacterAdded:Connect(setupPlayerCollision)
		end)
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then setupPlayerCollision(player.Character) end
		end
	end)
	if not success then
		warn("Player initialization failed:", errorMsg)
	end
end

local function isCollectorPart(hit: BasePart)
	if not hit or not hit:IsA("BasePart") then return false end

	local n = string.lower(hit.Name)
	local pn = hit.Parent and string.lower(hit.Parent.Name) or ""

	for _, want in ipairs(COLLECTOR_NAMES) do
		local w = string.lower(want)
		if n == w or pn == w or string.find(n, "collect") or string.find(pn, "collect") then
			return true
		end
	end

	for _, t in ipairs(COLLECTOR_TAGS) do
		if CollectionService:HasTag(hit, t) or (hit.Parent and CollectionService:HasTag(hit.Parent, t)) then
			return true
		end
	end

	if hit:GetAttribute("Collector") == true then return true end
	if hit.Parent and hit.Parent:FindFirstChild("Collector") then return true end

	return false
end

local function setupPhysics(part)
	local success, errorMsg = pcall(function()
		part.Anchored = false
		part.CanTouch = true
		part.CanQuery = true
		part.CollisionGroup = DROP_GROUP

		part.CustomPhysicalProperties = PhysicalProperties.new(
			PHYSICS_DENSITY,
			PHYSICS_FRICTION,
			PHYSICS_ELASTICITY,
			1.0,
			1.0
		)
	end)
	if not success then
		warn("Physics setup failed:", errorMsg)
	end
end

local function calculateSpawnPosition()
	local offsetX = math.random(-2, 2) * 0.1
	local offsetZ = math.random(-2, 2) * 0.1
	local spawnY = dropPart.Position.Y + SPAWN_HEIGHT_OFFSET

	return CFrame.new(
		dropPart.Position.X - offsetX,
		spawnY,
		dropPart.Position.Z - offsetZ
	)
end

local function setupMesh(part)
	local success, errorMsg = pcall(function()
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshId = MESH_ID
		mesh.TextureId = TEXTURE_ID
		mesh.Parent = part
		return mesh
	end)
	if not success then
		warn("Mesh setup failed:", errorMsg)
		return nil
	end
	return success
end

local function setupFadeSystem(part)
	local originalTransparency = part.Transparency
	part.Transparency = 1

	return {
		part = part,
		originalTransparency = originalTransparency,
		activeTween = nil
	}
end

local function fadeIn(fadeData)
	local success, tween = pcall(function()
		local tw = TweenService:Create(
			fadeData.part,
			TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Transparency = fadeData.originalTransparency }
		)
		tw:Play()
		return tw
	end)

	if success then
		fadeData.activeTween = tween
		return tween
	else
		warn("Fade in failed:", success)
		return nil
	end
end

local function fadeOut(fadeData, callback)
	local success = pcall(function()
		if fadeData.activeTween then
			fadeData.activeTween:Cancel()
		end

		local tween = TweenService:Create(
			fadeData.part,
			TweenInfo.new(FADE_TIME * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Transparency = 1 }
		)
		tween:Play()

		task.delay(FADE_TIME + 0.05, function()
			if callback then callback() end
		end)
	end)

	if not success then
		warn("Fade out failed:", success)
		if callback then callback() end
	end
end

local function createDropEffects(part)
	local success, light = pcall(function()
		local l = Instance.new("PointLight")
		l.Brightness = 1
		l.Range = 8
		l.Color = Color3.fromRGB(200, 100, 255)
		l.Parent = part
		return l
	end)

	if not success then
		warn("Light creation failed:", success)
		return nil
	end
	return light
end

local function createDrops()
	local count = 0
	while true do
		task.wait(DROP_RATE)
		count += 1

		local success, part = pcall(function()
			local p = Instance.new("Part")
			p.Name = "KuromiDrop_" .. count
			p.Parent = PartStorage

			p.Size = DROP_SIZE
			p.Shape = "Block"
			p.TopSurface = "Smooth"
			p.BottomSurface = "Smooth"

			p.CFrame = calculateSpawnPosition()

			return p
		end)

		if not success or not part then
			warn("Drop creation failed:", success)
			continue
		end

		local mesh = setupMesh(part)
		if not mesh then
			part:Destroy()
			continue
		end

		setupPhysics(part)

		local success2 = pcall(function()
			local cash = Instance.new("IntValue")
			cash.Name = "Cash"
			cash.Value = CASH_VALUE
			cash.Parent = part
		end)

		if not success2 then
			warn("Cash setup failed")
			part:Destroy()
			continue
		end

		local fadeData = setupFadeSystem(part)
		local light = createDropEffects(part)

		fadeIn(fadeData)

		local collected = false
		local touchConnection

		local function onCollected()
			if collected then return end
			collected = true

			if light then
				light.Brightness = 3
				TweenService:Create(light,
					TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{Brightness = 1}
				):Play()
			end

			fadeOut(fadeData, function()
				if touchConnection then
					pcall(function() touchConnection:Disconnect() end)
				end
				if part and part.Parent then
					pcall(function() part:Destroy() end)
				end
			end)
		end

		success, touchConnection = pcall(function()
			return part.Touched:Connect(function(hit)
				if isCollectorPart(hit) then
					onCollected()
				end
			end)
		end)

		if not success then
			warn("Touch connection failed")
			part:Destroy()
			continue
		end

		local originalSize = part.Size
		part.Size = Vector3.new(0.1, 0.1, 0.1)
		TweenService:Create(part,
			TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{Size = originalSize}
		):Play()

		Debris:AddItem(part, LIFETIME)
	end
end

setupCollisionGroups()
initializePlayers()

local success, errorMsg = pcall(createDrops)
if not success then
	warn("CRITICAL: Kuromi Dropper 6 failed to start:", errorMsg)
end
