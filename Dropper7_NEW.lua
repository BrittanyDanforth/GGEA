--[[
	Dropper 7 NEW - Transition Dropper
	Between basic and advanced droppers
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
	task.wait(1.2)
	
	-- Debounce check
	if not AntiStack.CanDrop(1.1) then
		continue
	end
	
	dropCount = dropCount + 1

	-- Create part
	local part = Instance.new("Part")
	part.Name = "TransitionDrop7_" .. dropCount
	part.BrickColor = BrickColor.new("Hot pink")
	part.Material = "SmoothPlastic"
	part.FormFactor = "Custom"
	part.Size = Vector3.new(1.2, 1.2, 1.2)
	part.TopSurface = "Smooth"
	part.BottomSurface = "Smooth"

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 80
	cash.Parent = part

	-- Apply anti-stack physics
	AntiStack.ApplyAntiStackPhysics(part, dropPart)

	-- Parent to storage
	part.Parent = PartStorage

	-- Cleanup
	AntiStack.ScheduleCleanup(part, 150)
end
