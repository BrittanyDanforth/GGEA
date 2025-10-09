--[[
	Dropper 11 NEW - Ruby Red Metallic
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
	task.wait(0.4)
	
	-- Debounce check
	if not AntiStack.CanDrop(0.35) then
		continue
	end
	
	dropCount = dropCount + 1

	-- Create part
	local part = Instance.new("Part")
	part.Name = "RubyDrop11_" .. dropCount
	part.BrickColor = BrickColor.new("Really red")
	part.Material = Enum.Material.Metal
	part.FormFactor = "Custom"
	part.Size = Vector3.new(0.3, 0.3, 0.3)
	part.TopSurface = "Smooth"
	part.BottomSurface = "Smooth"

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 350
	cash.Parent = part

	-- Apply anti-stack physics (with higher drop offset for small parts)
	local dropPartClone = Instance.new("Part")
	dropPartClone.CFrame = dropPart.CFrame - Vector3.new(0, 3.25, 0)
	AntiStack.ApplyAntiStackPhysics(part, dropPartClone)
	dropPartClone:Destroy()

	-- Parent to storage
	part.Parent = PartStorage

	-- Schedule cleanup
	AntiStack.ScheduleCleanup(part, 25)
end
