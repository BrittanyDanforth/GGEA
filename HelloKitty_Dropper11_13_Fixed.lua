wait(2)
workspace:WaitForChild("PartStorage")

meshDrop = false
--------------------
-- Mesh Settings: [If you want a mesh drop, set meshDrop to true up on top.]
meshID = "rbxasset://fonts/PaintballGun.mesh"  
textureID = "rbxasset://textures/PaintballGunTex128.png"
--------------------

-- Anti-stack pattern for small parts
local patterns = {
	Vector3.new(0.1, 0, 0.1),
	Vector3.new(-0.1, 0, 0.1),
	Vector3.new(0.1, 0, -0.1),
	Vector3.new(-0.1, 0, -0.1),
	Vector3.new(0, 0, 0),
}
local patternIndex = 1

while true do
	wait(1.5) -- How long in between drops
	local part = Instance.new("Part",workspace.PartStorage)
	local cash = Instance.new("IntValue",part)
	cash.Name = "Cash"
	cash.Value = 100 -- How much the drops are worth
	
	-- Anti-stack pattern position
	local offset = patterns[patternIndex]
	patternIndex = (patternIndex % #patterns) + 1
	
	part.CFrame = script.Parent.Drop.CFrame - Vector3.new(offset.X, 5, offset.Z)
	part.FormFactor = "Custom"
	part.Size=Vector3.new(0.2, 0.2, 0.2) -- Size of the drops
	
	if meshDrop == true then
		local m = Instance.new("SpecialMesh",part)
		m.MeshId = meshID
		m.TextureId = textureID
	end
	
	part.TopSurface = "Smooth"
	part.BottomSurface = "Smooth"
	
	-- Add velocity for spread (less for small parts)
	part.AssemblyLinearVelocity = Vector3.new(offset.X * 1.5, -8, offset.Z * 1.5)
	
	-- Light physics for small parts
	part.CustomPhysicalProperties = PhysicalProperties.new(
		0.1,  -- Very light
		0.3,  -- Some friction
		0.05, -- Very low bounce
		1, 1
	)
	
	game.Debris:AddItem(part,20) -- How long until the drops expire
end