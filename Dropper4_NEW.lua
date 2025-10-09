--!strict
--[[
	Dropper 4 NEW - White Heart (FIXED)
--]]

local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

local ORB_GROUP = "HelloKittyDrops4"
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
	task.wait(0.9)
	dropCount = dropCount + 1

	local cake = Instance.new("Part")
	cake.Name = "WhiteHeart_" .. dropCount
	cake.Size = Vector3.new(2, 2, 2)
	cake.Material = Enum.Material.SmoothPlastic
	cake.BrickColor = BrickColor.new("Institutional white")
	cake.TopSurface = Enum.SurfaceType.Smooth
	cake.BottomSurface = Enum.SurfaceType.Smooth
	cake.Reflectance = 0.2
	cake.Transparency = 0.7

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://601198887"
	mesh.TextureId = ""
	mesh.Scale = Vector3.new(0.001, 0.001, 0.001)
	mesh.Parent = cake

	cake.CanCollide = true
	cake.CanTouch = true
	cake.CanQuery = true
	cake.CollisionGroup = ORB_GROUP
	cake.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.6, 0.1, 1, 1)

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 40
	cash.Parent = cake

	local glow = Instance.new("PointLight")
	glow.Brightness = 0.6
	glow.Range = 6
	glow.Color = Color3.fromRGB(255, 204, 204)
	glow.Parent = cake

	local offsetX = math.random(-2, 2) * 0.1
	local offsetZ = math.random(-2, 2) * 0.1
	cake.CFrame = (dropPart.CFrame - Vector3.new(offsetX, 1.75, offsetZ))
	cake.AssemblyLinearVelocity = Vector3.new(offsetX * 2, -10, offsetZ * 2)
	cake:SetAttribute("SpawnTime", os.clock())
	cake.Parent = PartStorage

	TweenService:Create(cake, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0}):Play()
	TweenService:Create(mesh, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = Vector3.new(0.04, 0.04, 0.04)}):Play()

	task.delay(180, function() if cake and cake.Parent then cake:Destroy() end end)
end
