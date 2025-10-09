--[[
	Dropper 10 NEW - Golden Glass
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

local dropCount = 0

while true do
	task.wait(0.45)
	
	-- Debounce check to prevent spam
	if not AntiStack.CanDrop(0.4) then
		continue
	end
	
	dropCount = dropCount + 1

	-- Create part
	local part = Instance.new("Part")
	part.Name = "GoldenDrop10_" .. dropCount
	part.BrickColor = BrickColor.new("New Yeller")
	part.Material = "Glass"
	part.FormFactor = "Custom"
	part.Size = Vector3.new(1.5, 1.5, 1.5)
	part.TopSurface = "Smooth"
	part.BottomSurface = "Smooth"
	part.Reflectance = 0.4

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 250
	cash.Parent = part

	-- Apply anti-stack physics
	AntiStack.ApplyAntiStackPhysics(part, dropPart)

	-- Parent to storage
	part.Parent = PartStorage

	-- Long lifetime
	AntiStack.ScheduleCleanup(part, 2000)
end
