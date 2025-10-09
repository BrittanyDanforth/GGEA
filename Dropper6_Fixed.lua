--[[
	Dropper 6 - Mesh Dropper Fixed
	Optimized with anti-stack
--]]

local AntiStack = require(workspace:WaitForChild("DropperAntiStack"))

-- Setup collision groups
AntiStack.SetupCollisionGroups()

-- Setup player collisions
game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(AntiStack.SetupPlayerCollisions)
end)

for _, player in ipairs(game.Players:GetPlayers()) do
	if player.Character then
		AntiStack.SetupPlayerCollisions(player.Character)
	end
end

-- Wait for dependencies
task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local dropPart = script.Parent:WaitForChild("Drop")

-- Mesh settings
local meshDrop = true
local meshID = "http://www.roblox.com/asset?id=160003363"
local textureID = "http://www.roblox.com/asset/?id=192068356"

local dropCount = 0

while true do
	task.wait(1.5)
	
	-- Debounce check
	if not AntiStack.CanDrop(1.4) then
		continue
	end
	
	dropCount = dropCount + 1

	-- Create part
	local part = Instance.new("Part")
	part.Name = "MeshDrop_" .. dropCount
	part.FormFactor = "Custom"
	part.Size = Vector3.new(1, 5, 4)
	part.TopSurface = "Smooth"
	part.BottomSurface = "Smooth"
	part.Material = Enum.Material.SmoothPlastic

	-- Add mesh
	if meshDrop then
		local m = Instance.new("SpecialMesh")
		m.MeshId = meshID
		m.TextureId = textureID
		m.Parent = part
	end

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 12
	cash.Parent = part

	-- Apply anti-stack physics
	AntiStack.ApplyAntiStackPhysics(part, dropPart)

	-- Parent to storage
	part.Parent = PartStorage

	-- Schedule cleanup (20 seconds as original)
	AntiStack.ScheduleCleanup(part, 20)
end