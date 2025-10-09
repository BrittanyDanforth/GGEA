wait(2)
workspace:WaitForChild("PartStorage")

meshDrop = true
--------------------
-- Mesh Settings:
meshID = "http://www.roblox.com/asset?id=160003363"  
textureID = "http://www.roblox.com/asset/?id=192068356"
--------------------

-- Anti-stack pattern
local patterns = {
	Vector3.new(0.2, 0, 0.2),
	Vector3.new(-0.2, 0, 0.2),
	Vector3.new(0.2, 0, -0.2),
	Vector3.new(-0.2, 0, -0.2),
	Vector3.new(0, 0, 0),
}
local patternIndex = 1

while true do
	wait(1.5) -- How long in between drops
	local part = Instance.new("Part",workspace.PartStorage)
	local cash = Instance.new("IntValue",part)
	cash.Name = "Cash"
	cash.Value = 12 -- How much the drops are worth
	
	-- Anti-stack pattern position
	local offset = patterns[patternIndex]
	patternIndex = (patternIndex % #patterns) + 1
	
	part.CFrame = script.Parent.Drop.CFrame - Vector3.new(offset.X, 5, offset.Z)
	part.FormFactor = "Custom"
	part.Size=Vector3.new(1, 5, 4) -- Size of the drops
	
	if meshDrop == true then
		local m = Instance.new("SpecialMesh",part)
		m.MeshId = meshID
		m.TextureId = textureID
	end
	
	part.TopSurface = "Smooth"
	part.BottomSurface = "Smooth"
	
	-- Add velocity for spread
	part.AssemblyLinearVelocity = Vector3.new(offset.X * 3, -10, offset.Z * 3)
	
	game.Debris:AddItem(part,20) -- How long until the drops expire
end