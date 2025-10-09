--[[
	Dropper 13 NEW - Epic Purple Crystal
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
	task.wait(0.3)
	
	-- Debounce check
	if not AntiStack.CanDrop(0.25) then
		continue
	end
	
	dropCount = dropCount + 1

	-- Create part
	local part = Instance.new("Part")
	part.Name = "CrystalDrop13_" .. dropCount
	part.BrickColor = BrickColor.new("Royal purple")
	part.Material = Enum.Material.Neon
	part.FormFactor = "Custom"
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.TopSurface = "Smooth"
	part.BottomSurface = "Smooth"

	-- Add sparkle effect
	local sparkle = Instance.new("Sparkles")
	sparkle.Parent = part

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 750
	cash.Parent = part

	-- Apply anti-stack physics (with higher drop offset for small parts)
	local dropPartClone = Instance.new("Part")
	dropPartClone.CFrame = dropPart.CFrame - Vector3.new(0, 3.25, 0)
	AntiStack.ApplyAntiStackPhysics(part, dropPartClone)
	dropPartClone:Destroy()

	-- Parent to storage
	part.Parent = PartStorage

	-- Schedule cleanup
	AntiStack.ScheduleCleanup(part, 35)
end
