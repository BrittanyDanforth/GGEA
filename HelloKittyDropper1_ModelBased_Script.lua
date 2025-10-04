--[[
	Hello Kitty Dropper 1 - Model Based
	Uses HelloKittyPL model from ReplicatedStorage
	Fixed: Collides with conveyor/ground but not players
--]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for references
task.wait(2)
local PartStorage = workspace:WaitForChild("PartStorage")
local templateModel = ReplicatedStorage:WaitForChild("HelloKittyPL")
local dropPart = script.Parent:WaitForChild("Drop")

-- Configuration
local DROP_RATE = 1.2
local CASH_VALUE = 10
local LIFETIME = nil -- No cleanup, stays until collected

-- Create collision groups
local DROP_GROUP = "HelloKittyOrbs"
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(DROP_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	-- Drops don't collide with players
	PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, PLAYER_GROUP, false)
	-- Drops don't collide with each other
	PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, DROP_GROUP, false)
end)

-- Setup player collision groups
local function setupPlayerCollision(character)
	task.wait(0.1)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function() part.CollisionGroup = PLAYER_GROUP end)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(setupPlayerCollision)
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then setupPlayerCollision(player.Character) end
end

-- Function to find a suitable primary part
local function findPrimaryPart(model)
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	
	-- Find the largest part by volume
	local largestPart = nil
	local largestVolume = 0
	
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			local volume = child.Size.X * child.Size.Y * child.Size.Z
			if volume > largestVolume then
				largestVolume = volume
				largestPart = child
			end
		end
	end
	
	return largestPart
end

-- Welding function
local function weldAllParts(model, primaryPart)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= primaryPart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = primaryPart
			weld.Part1 = descendant
			weld.Parent = primaryPart
		end
	end
end

local count = 0

while true do
	task.wait(DROP_RATE)
	count += 1

	-- Clone the model
	local newDrop = templateModel:Clone()
	newDrop.Name = "HelloKitty_" .. count

	-- Find primary part (auto-detect if not set)
	local primaryPart = findPrimaryPart(newDrop)
	if not primaryPart then
		warn("ERROR: HelloKittyPL model has no BaseParts!")
		newDrop:Destroy()
		continue
	end

	-- Weld all parts
	weldAllParts(newDrop, primaryPart)

	-- Set physical properties and collision for ALL parts  
	for _, part in ipairs(newDrop:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanTouch = true
			part.CanQuery = true

			-- Only primary part should have collision
			if part == primaryPart then
				part.CanCollide = true
				part.CustomPhysicalProperties = PhysicalProperties.new(
					0.3,  -- Very light density
					0.5,  -- Medium friction
					0.1,  -- Low bounce
					1, 1
				)
			else
				part.CanCollide = false
			end

			pcall(function() part.CollisionGroup = DROP_GROUP end)

			-- Add Cash to every part
			local cash = Instance.new("IntValue")
			cash.Name = "Cash"
			cash.Value = CASH_VALUE
			cash.Parent = part
		end
	end

	-- Position with small offset
	local offsetX = math.random(-2, 2) * 0.1
	local offsetZ = math.random(-2, 2) * 0.1

	-- Position and rotate (manually move all parts relative to primary part)
	local targetCFrame = (dropPart.CFrame - Vector3.new(offsetX, 2, offsetZ)) * CFrame.Angles(math.rad(180), math.rad(180), 0)
	local offset = targetCFrame * primaryPart.CFrame:Inverse()
	
	for _, part in ipairs(newDrop:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CFrame = offset * part.CFrame
		end
	end

	-- Set initial velocity
	primaryPart.AssemblyLinearVelocity = Vector3.new(0, -12, 0)

	-- Set spawn time
	primaryPart:SetAttribute("SpawnTime", tick())

	-- Start semi-transparent for fade-in
	for _, part in ipairs(newDrop:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 0.7
		end
	end

	-- Parent to storage
	newDrop.Parent = PartStorage

	-- Add glow to primary part
	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 0.4
	pointLight.Range = 3
	pointLight.Color = Color3.fromRGB(255, 150, 200) -- Pink glow
	pointLight.Parent = primaryPart

	-- Fade in animation
	for _, part in ipairs(newDrop:GetDescendants()) do
		if part:IsA("BasePart") then
			TweenService:Create(part,
				TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Transparency = part.Transparency == 1 and 1 or 0} -- Keep transparent parts transparent
			):Play()
		end
	end

	-- Scale animation on primary part
	local originalSize = primaryPart.Size
	primaryPart.Size = Vector3.new(0.1, 0.1, 0.1)
	
	TweenService:Create(primaryPart,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = originalSize}
	):Play()

	-- Spawn flash
	pointLight.Brightness = 1.5
	TweenService:Create(pointLight,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0.4}
	):Play()

	-- Spawn ring effect
	local spawnRing = Instance.new("ParticleEmitter")
	spawnRing.Texture = "rbxassetid://262979222"
	spawnRing.Rate = 0
	spawnRing.Speed = NumberRange.new(0)
	spawnRing.Lifetime = NumberRange.new(0.3)
	spawnRing.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 2)
	})
	spawnRing.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 1)
	})
	spawnRing.Color = ColorSequence.new(Color3.fromRGB(255, 150, 200)) -- Pink ring
	spawnRing.Parent = primaryPart
	spawnRing:Emit(1)
	Debris:AddItem(spawnRing, 1)

	-- NO CLEANUP - Stays until collected!
end
