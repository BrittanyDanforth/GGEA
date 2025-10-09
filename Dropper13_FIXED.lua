-- Dropper 13 - FIXED COLLISION
local PhysicsService = game:GetService("PhysicsService")

wait(2)
workspace:WaitForChild("PartStorage")

-- Collision groups
local DROP_GROUP = "Dropper13Drops"
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

meshDrop = false
--------------------
-- Mesh Settings: --
meshID = "rbxasset://fonts/PaintballGun.mesh"  
textureID = "rbxasset://textures/PaintballGunTex128.png"
--------------------

while true do
	wait(1.5) -- How long in between drops
	local part = Instance.new("Part",workspace.PartStorage)
	local cash = Instance.new("IntValue",part)
	cash.Name = "Cash"
	cash.Value = 100 -- How much the drops are worth
	part.CFrame = script.Parent.Drop.CFrame - Vector3.new(0,5,0)
	part.FormFactor = "Custom"
	part.Size=Vector3.new(0.2, 0.2, 0.2) -- Size of the drops
	
	-- FIXED: Collision
	part.CanCollide = false
	part.CanTouch = true
	pcall(function()
		part.CollisionGroup = DROP_GROUP
	end)
	
	if meshDrop == true then
		local m = Instance.new("SpecialMesh",part)
		m.MeshId = meshID
		m.TextureId = textureID
	end
	part.TopSurface = "Smooth"
	part.BottomSurface = "Smooth"
	game.Debris:AddItem(part,20) -- How long until the drops expire
end
