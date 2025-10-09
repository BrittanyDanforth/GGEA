--[[
	Droppers 8-10 - Lime Green Fabric Fixed
	Optimized with anti-stack
	(Use this same script for Droppers 8, 9, and 10)
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

local dropCount = 0

while true do
	task.wait(0.5)
	
	-- Debounce check to prevent spam
	if not AntiStack.CanDrop(0.45) then
		continue
	end
	
	dropCount = dropCount + 1

	-- Create part
	local part = Instance.new("Part")
	part.Name = "FabricDrop_" .. dropCount
	part.BrickColor = BrickColor.new("Lime green")
	part.Material = "Fabric"
	part.FormFactor = "Custom"
	part.Size = Vector3.new(1, 1, 1)
	part.TopSurface = "Smooth"
	part.BottomSurface = "Smooth"

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 150
	cash.Parent = part

	-- Apply anti-stack physics
	AntiStack.ApplyAntiStackPhysics(part, dropPart)

	-- Parent to storage
	part.Parent = PartStorage

	-- Long lifetime (2000 seconds as original)
	AntiStack.ScheduleCleanup(part, 2000)
end