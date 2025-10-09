--!strict
--[[
	Dropper 8 NEW - Lime Green Fabric (FIXED)
--]]

local PhysicsService = game:GetService("PhysicsService")

task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

local ORB_GROUP = "HelloKittyDrops8"
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

	local part = Instance.new("Part")
	part.Name = "Fabric8_" .. dropCount
	part.Size = Vector3.new(1, 1, 1)
	part.BrickColor = BrickColor.new("Lime green")
	part.Material = Enum.Material.Fabric
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	part.CanCollide = true
	part.CanTouch = true
	part.CanQuery = true
	part.CollisionGroup = ORB_GROUP
	part.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.4, 0.1, 1, 1)

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 120
	cash.Parent = part

	local offsetX = math.random(-2, 2) * 0.1
	local offsetZ = math.random(-2, 2) * 0.1
	part.CFrame = (dropPart.CFrame - Vector3.new(offsetX, 1.5, offsetZ))
	part.AssemblyLinearVelocity = Vector3.new(offsetX * 2, -10, offsetZ * 2)
	part:SetAttribute("SpawnTime", os.clock())
	part.Parent = PartStorage

	task.delay(2000, function() if part and part.Parent then part:Destroy() end end)
end
