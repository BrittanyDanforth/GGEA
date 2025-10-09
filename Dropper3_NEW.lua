--!strict
--[[
	Dropper 3 NEW - Premium HelloKitty (FIXED)
--]]

local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

local ORB_GROUP = "HelloKittyDrops3"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(ORB_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, PLAYER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(ORB_GROUP, ORB_GROUP, false)
end)

local function setupPlayer(character)
	task.wait(0.1)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function() part.CollisionGroup = PLAYER_GROUP end)
		end
	end
end

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(setupPlayer)
end)

for _, player in ipairs(game.Players:GetPlayers()) do
	if player.Character then setupPlayer(player.Character) end
end

local dropCount = 0

while true do
	task.wait(0.6)
	dropCount = dropCount + 1

	local drop = Instance.new("Part")
	drop.Name = "PremiumHK_" .. dropCount
	drop.Size = Vector3.new(1.817, 1.323, 0.281)
	drop.Material = Enum.Material.SmoothPlastic
	drop.Color = Color3.fromRGB(151, 0, 0)
	drop.TopSurface = Enum.SurfaceType.Smooth
	drop.BottomSurface = Enum.SurfaceType.Smooth
	drop.Transparency = 0.7

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://3071180788"
	mesh.TextureId = ""
	mesh.Scale = Vector3.new(1, 1, 1)
	mesh.Parent = drop

	drop.CanCollide = true
	drop.CanTouch = true
	drop.CanQuery = true
	drop.CollisionGroup = ORB_GROUP
	drop.CustomPhysicalProperties = PhysicalProperties.new(0.2, 0.4, 0.3, 1, 1)

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 50
	cash.Parent = drop

	local glow = Instance.new("PointLight")
	glow.Brightness = 1
	glow.Range = 8
	glow.Color = Color3.fromRGB(255, 100, 150)
	glow.Parent = drop

	local offsetX = math.random(-2, 2) * 0.1
	local offsetZ = math.random(-2, 2) * 0.1
	drop.CFrame = (dropPart.CFrame - Vector3.new(offsetX, 1.75, offsetZ)) * CFrame.Angles(math.rad(70), math.rad(0), math.rad(180))
	drop.AssemblyLinearVelocity = Vector3.new(offsetX * 2, -10, offsetZ * 2)
	drop:SetAttribute("SpawnTime", os.clock())
	drop.Parent = PartStorage

	TweenService:Create(drop, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0}):Play()
	TweenService:Create(mesh, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = Vector3.new(4, 4, 4)}):Play()

	glow.Brightness = 2
	TweenService:Create(glow, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Brightness = 1}):Play()

	task.delay(180, function() if drop and drop.Parent then drop:Destroy() end end)
end
