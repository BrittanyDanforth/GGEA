--[[
	Shared Anti-Stack Module for All Droppers
	Prevents drops from stacking and causing lag
--]]

local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local module = {}

-- Create collision groups once
local DROPS_GROUP = "DropperItems"
local PLAYER_GROUP = "Players"
local REGISTERED = false

function module.SetupCollisionGroups()
	if REGISTERED then return end
	
	pcall(function()
		PhysicsService:RegisterCollisionGroup(DROPS_GROUP)
		PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
		-- Drops don't collide with players
		PhysicsService:CollisionGroupSetCollidable(DROPS_GROUP, PLAYER_GROUP, false)
		-- Drops DO collide with each other (prevents stacking)
		PhysicsService:CollisionGroupSetCollidable(DROPS_GROUP, DROPS_GROUP, true)
	end)
	
	REGISTERED = true
end

function module.SetupPlayerCollisions(character)
	task.wait(0.1)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				part.CollisionGroup = PLAYER_GROUP
			end)
		end
	end
end

-- Anti-stack pattern positions
local PATTERNS = {
	Vector3.new(0.3, 0, 0.3),
	Vector3.new(-0.3, 0, 0.3),
	Vector3.new(0.3, 0, -0.3),
	Vector3.new(-0.3, 0, -0.3),
	Vector3.new(0, 0, 0),
	Vector3.new(0.4, 0, 0),
	Vector3.new(-0.4, 0, 0),
	Vector3.new(0, 0, 0.4),
	Vector3.new(0, 0, -0.4),
}

local patternIndex = 1

function module.GetNextPattern()
	local pattern = PATTERNS[patternIndex]
	patternIndex = (patternIndex % #PATTERNS) + 1
	return pattern
end

-- Apply physics to prevent stacking
function module.ApplyAntiStackPhysics(part, dropPart, pattern)
	-- Set collision group
	pcall(function()
		part.CollisionGroup = DROPS_GROUP
	end)
	
	-- Good physics for conveyors
	part.CustomPhysicalProperties = PhysicalProperties.new(
		0.3,  -- Light density
		0.4,  -- Medium friction (good for conveyors)
		0.1,  -- Low elasticity (minimal bounce)
		1, 1
	)
	
	-- Position with pattern offset
	local offset = pattern or module.GetNextPattern()
	part.CFrame = dropPart.CFrame - Vector3.new(offset.X, 1.75, offset.Z)
	
	-- Apply velocity with slight spread
	part.AssemblyLinearVelocity = Vector3.new(
		offset.X * 3,  -- Slight horizontal spread
		-12,           -- Consistent drop speed
		offset.Z * 3
	)
	
	-- Prevent spinning
	part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	
	-- Make sure collision is enabled
	part.CanCollide = true
	part.CanTouch = true
	part.CanQuery = true
end

-- Performance optimization: Cleanup old drops
function module.ScheduleCleanup(part, lifetime)
	if lifetime and lifetime > 0 then
		task.delay(lifetime, function()
			if part and part.Parent then
				part:Destroy()
			end
		end)
	end
end

-- Debounce drop creation to prevent spam
local lastDropTime = 0
function module.CanDrop(minInterval)
	local now = tick()
	if now - lastDropTime < minInterval then
		return false
	end
	lastDropTime = now
	return true
end

return module