-- =================================================================
-- Hello Kitty Model Dropper - Based on Working Script
-- Uses HelloKittyPL model from ReplicatedStorage
-- =================================================================

-- Services
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- References
local PartStorage = workspace:WaitForChild("PartStorage")
local templateModel = ReplicatedStorage:WaitForChild("HelloKittyPL")
local dropPart = script.Parent:WaitForChild("Drop")

-- Configuration
local DROP_RATE = 1.2
local CASH_VALUE = 10
local LIFETIME = nil -- NO CLEANUP - stays until collected

-- =================================================================
-- COLLISION GROUPS
-- =================================================================
local DROP_GROUP = "HelloKittyOrbs"  -- Unique group name
local PLAYER_GROUP = "Players"

pcall(function()
	PhysicsService:RegisterCollisionGroup(DROP_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:RegisterCollisionGroup("HelloKittyOrbs2")
	PhysicsService:RegisterCollisionGroup("HelloKittyOrbs3")
	-- Drops don't collide with players
	PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, PLAYER_GROUP, false)
	-- Drops don't collide with EACH OTHER (prevents bouncing off each other)
	PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, DROP_GROUP, false)
	-- Don't collide with other Hello Kitty droppers
	PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, "HelloKittyOrbs2", false)
	PhysicsService:CollisionGroupSetCollidable(DROP_GROUP, "HelloKittyOrbs3", false)
end)

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

-- Short wait to ensure physics are ready
task.wait(1)

-- =================================================================
-- MAIN DROPPER LOOP
-- =================================================================
local count = 0
while true do
	task.wait(DROP_RATE)
	count += 1

	-- 1. Create the Clone
	local newDrop = templateModel:Clone()
	newDrop.Name = "HelloKitty_" .. count

	-- 1.5. Find primary part (auto-detect if not set)
	local primaryPart = findPrimaryPart(newDrop)
	if not primaryPart then
		warn("ERROR: HelloKittyPL model has no BaseParts!")
		newDrop:Destroy()
		continue
	end

	-- 2. Weld all parts
	weldAllParts(newDrop, primaryPart)

	-- 3. Set physical properties and collision for ALL parts
	-- CRITICAL: Add Cash value to EVERY BasePart so collector can find it
	for _, part in ipairs(newDrop:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanTouch = true  -- Important for touch detection
			part.CanQuery = true

			-- Only primary part should have collision (prevents bouncing)
			if part == primaryPart then
				part.CanCollide = true
				-- Softer physics to prevent bouncing
				part.CustomPhysicalProperties = PhysicalProperties.new(
					0.7,  -- Density (lower = lighter)
					0.3,  -- Friction  
					0.05, -- Elasticity (VERY LOW to prevent bouncing)
					1,    -- ElasticityWeight
					1     -- FrictionWeight
				)
			else
				-- Other parts don't collide (prevents weird physics)
				part.CanCollide = false
			end

			pcall(function() part.CollisionGroup = DROP_GROUP end)

			-- ADD CASH TO EVERY PART (like your working dropper)
			local cash = Instance.new("IntValue")
			cash.Name = "Cash"
			cash.Value = CASH_VALUE
			cash.Parent = part
		end
	end

	-- 4. Position and scale the model
	local offsetX = (math.random(-2, 2) * 0.1)
	local offsetZ = (math.random(-2, 2) * 0.1)

	-- Scale up the model (bigger size)
	local scaleFactor = 1.8
	for _, part in ipairs(newDrop:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Size = part.Size * scaleFactor
			if part:FindFirstChild("Mesh") then
				part.Mesh.Scale = part.Mesh.Scale * scaleFactor
			end
		elseif part:IsA("SpecialMesh") then
			part.Scale = part.Scale * scaleFactor
		end
	end

	-- Position BELOW the dropper with proper orientation
	-- Add 180 degree rotation to flip it right-side up + turn left a bit
	local targetCFrame = dropPart.CFrame * CFrame.new(offsetX, 3.5, offsetZ) * CFrame.Angles(math.rad(180), math.rad(15), 0)
	
	-- Move all parts relative to primary part
	local offset = targetCFrame * primaryPart.CFrame:Inverse()
	for _, part in ipairs(newDrop:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CFrame = offset * part.CFrame
		end
	end

	-- Better drop control using AlignOrientation to prevent flipping
	local attachment = Instance.new("Attachment")
	attachment.Parent = primaryPart

	-- Keep it oriented properly (no spinning/flipping)
	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.MaxTorque = 10000
	alignOrientation.Responsiveness = 10
	alignOrientation.CFrame = primaryPart.CFrame
	alignOrientation.Parent = primaryPart

	-- Controlled descent (not too fast)
	local vectorForce = Instance.new("VectorForce")
	vectorForce.Attachment0 = attachment
	vectorForce.Force = Vector3.new(0, workspace.Gravity * primaryPart.AssemblyMass * 0.8, 0) -- Counteract some gravity
	vectorForce.Parent = primaryPart

	-- Give initial downward push
	primaryPart.AssemblyLinearVelocity = Vector3.new(0, -10, 0)

	-- Remove controls after a short time
	task.delay(0.8, function()
		if alignOrientation and alignOrientation.Parent then
			alignOrientation:Destroy()
		end
		if vectorForce and vectorForce.Parent then
			vectorForce:Destroy()
		end
	end)

	-- 5. Set spawn time attribute (some collectors use this)
	primaryPart:SetAttribute("SpawnTime", tick())

	-- 6. Fade-in effect (matching your working dropper)
	for _, part in ipairs(newDrop:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 0.7
			TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 0
			}):Play()
		elseif part:IsA("Decal") or part:IsA("Texture") then
			local originalTransparency = part.Transparency
			part.Transparency = 1
			TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = originalTransparency
			}):Play()
		end
	end

	-- 7. Effects (on PrimaryPart) - PINK THEME!
	-- Light flash (pink)
	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 6
	light.Color = Color3.fromRGB(255, 150, 200) -- Pink light
	light.Parent = primaryPart
	TweenService:Create(light, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0.4
	}):Play()

	-- Spawn ring (pink)
	local ring = Instance.new("ParticleEmitter")
	ring.Texture = "rbxassetid://262979222"
	ring.Rate = 0
	ring.Speed = NumberRange.new(0)
	ring.Lifetime = NumberRange.new(0.3)
	ring.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 2)
	})
	ring.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 1)
	})
	ring.Color = ColorSequence.new(Color3.fromRGB(255, 150, 200)) -- Pink ring
	ring.Parent = primaryPart
	ring:Emit(1)
	Debris:AddItem(ring, 1)

	-- 8. Parent to workspace (matching your working dropper)
	newDrop.Parent = PartStorage

	-- 9. NO CLEANUP - Stays until collected!
	if LIFETIME then
		Debris:AddItem(newDrop, LIFETIME)
	end
end
