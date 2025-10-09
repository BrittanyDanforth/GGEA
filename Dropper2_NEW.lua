--!strict
--[[
	Dropper 2 NEW - Cinnamoroll Style (FIXED)
	Collides with conveyor/ground but NOT players or other drops
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

local ORB_GROUP = "HelloKittyDrops2"
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
	task.wait(1.0)
	dropCount = dropCount + 1

	local orb = Instance.new("Part")
	orb.Name = "Cinnamoroll2_" .. dropCount
	orb.Size = Vector3.new(2, 2, 2)
	orb.Material = Enum.Material.SmoothPlastic
	orb.TopSurface = Enum.SurfaceType.Smooth
	orb.BottomSurface = Enum.SurfaceType.Smooth
	orb.Color = Color3.new(1, 1, 1)
	orb.Transparency = 0.7

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://114684643919279"
	mesh.TextureId = "rbxassetid://136339015269351"
	mesh.Scale = Vector3.new(0.5, 0.5, 0.5)
	mesh.Parent = orb

	orb.CanCollide = true
	orb.CanTouch = true
	orb.CanQuery = true
	orb.CollisionGroup = ORB_GROUP
	orb.CustomPhysicalProperties = PhysicalProperties.new(0.2, 0.3, 0.1, 1, 1)

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 15
	cash.Parent = orb

	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 0.6
	pointLight.Range = 4
	pointLight.Color = Color3.new(1, 1, 1)
	pointLight.Parent = orb

	local offsetX = math.random(-2, 2) * 0.1
	local offsetZ = math.random(-2, 2) * 0.1
	orb.CFrame = (dropPart.CFrame - Vector3.new(offsetX, 1.75, offsetZ)) * CFrame.Angles(math.rad(180), math.rad(270), 0)
	orb.AssemblyLinearVelocity = Vector3.new(offsetX * 2, -10, offsetZ * 2)
	orb:SetAttribute("SpawnTime", os.clock())
	orb.Parent = PartStorage

	TweenService:Create(orb, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0}):Play()
	TweenService:Create(mesh, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = Vector3.new(2, 2, 2)}):Play()

	pointLight.Brightness = 1.5
	TweenService:Create(pointLight, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Brightness = 0.6}):Play()

	task.delay(180, function() if orb and orb.Parent then orb:Destroy() end end)
end
