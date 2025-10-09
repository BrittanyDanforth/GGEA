-- Dropper 9 - FIXED COLLISION
local PhysicsService = game:GetService("PhysicsService")

wait(2)
workspace:WaitForChild("PartStorage")

-- Collision groups
local DROP_GROUP = "Dropper9Drops"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(DROP_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, PLAYER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, DROP_GROUP, false)
end)

local function setupPlayer(character)
	task.wait(0.1)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				part.CollisionGroup = PLAYER_GROUP
			end)
		end
	end
end

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(setupPlayer)
end)

for _, player in ipairs(game.Players:GetPlayers()) do
	if player.Character then
		setupPlayer(player.Character)
	end
end

while true do
	wait(0.5) -- How long in between drops
	local part = Instance.new("Part",workspace.PartStorage)
	part.BrickColor=BrickColor.new("Lime green")
	part.Material="Fabric"
	local cash = Instance.new("IntValue",part)
	cash.Name = "Cash"
	cash.Value = 100 -- How much the drops are worth
	part.CFrame = script.Parent.Drop.CFrame - Vector3.new(0,1.4,0)
	part.FormFactor = "Custom"
	part.Size=Vector3.new(1, 1, 1) -- Size of the drops
	
	-- FIXED: Collision
	part.CanCollide = false
	part.CanTouch = true
	pcall(function()
		part.CollisionGroup = DROP_GROUP
	end)
	
	part.TopSurface = "Smooth"
	part.BottomSurface = "Smooth"
	game.Debris:AddItem(part,2000) -- How long until the drops expire
end
