--[[
	Droppers 11-13 - Small Part Droppers Fixed
	Optimized with anti-stack
	(Use this same script for Droppers 11, 12, and 13)
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

-- Mesh settings (disabled by default as in original)
local meshDrop = false
local meshID = "rbxasset://fonts/PaintballGun.mesh"
local textureID = "rbxasset://textures/PaintballGunTex128.png"

local dropCount = 0

while true do
	task.wait(1.5)
	
	-- Debounce check
	if not AntiStack.CanDrop(1.4) then
		continue
	end
	
	dropCount = dropCount + 1

	-- Create small part
	local part = Instance.new("Part")
	part.Name = "SmallDrop_" .. dropCount
	part.FormFactor = "Custom"
	part.Size = Vector3.new(0.2, 0.2, 0.2) -- Small size
	part.TopSurface = "Smooth"
	part.BottomSurface = "Smooth"
	part.Material = Enum.Material.SmoothPlastic

	-- Add mesh if enabled
	if meshDrop then
		local m = Instance.new("SpecialMesh")
		m.MeshId = meshID
		m.TextureId = textureID
		m.Parent = part
	end

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 100
	cash.Parent = part

	-- Apply anti-stack physics (with higher drop offset for small parts)
	local dropPartClone = Instance.new("Part")
	dropPartClone.CFrame = dropPart.CFrame - Vector3.new(0, 3.25, 0) -- Higher offset
	AntiStack.ApplyAntiStackPhysics(part, dropPartClone)
	dropPartClone:Destroy()

	-- Parent to storage
	part.Parent = PartStorage

	-- Schedule cleanup (20 seconds as original)
	AntiStack.ScheduleCleanup(part, 20)
end