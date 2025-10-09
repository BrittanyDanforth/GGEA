wait(2)
workspace:WaitForChild("PartStorage")

-- Anti-stack pattern
local patterns = {
	Vector3.new(0.15, 0, 0.15),
	Vector3.new(-0.15, 0, 0.15),
	Vector3.new(0.15, 0, -0.15),
	Vector3.new(-0.15, 0, -0.15),
	Vector3.new(0, 0, 0),
}
local patternIndex = 1

while true do
	wait(0.5) -- How long in between drops
	local part = Instance.new("Part",workspace.PartStorage)
	part.BrickColor=BrickColor.new("Lime green")
	part.Material="Fabric"
	local cash = Instance.new("IntValue",part)
	cash.Name = "Cash"
	cash.Value = 100 -- How much the drops are worth
	
	-- Anti-stack pattern position
	local offset = patterns[patternIndex]
	patternIndex = (patternIndex % #patterns) + 1
	
	part.CFrame = script.Parent.Drop.CFrame - Vector3.new(offset.X, 1.4, offset.Z)
	part.FormFactor = "Custom"
	part.Size=Vector3.new(1, 1, 1) -- Size of the drops
	part.TopSurface = "Smooth"
	part.BottomSurface = "Smooth"
	
	-- Add velocity for spread
	part.AssemblyLinearVelocity = Vector3.new(offset.X * 2, -8, offset.Z * 2)
	
	-- Better physics
	part.CustomPhysicalProperties = PhysicalProperties.new(
		0.2,  -- Light density
		0.4,  -- Medium friction
		0.1,  -- Low bounce
		1, 1
	)
	
	game.Debris:AddItem(part,2000) -- How long until the drops expire
end