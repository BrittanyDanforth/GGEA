--[[
	Conveyor Script - PERFECT Balance
	✅ Normal speed in middle
	✅ Just a TINY slowdown at end (not too much!)
	✅ Items drop perfectly straight
]]

local conveyor = script.Parent
local NORMAL_SPEED = 10
local SLOW_ZONE_DISTANCE = 5  -- Shorter slow zone (was 8)

-- Calculate conveyor end position
local conveyorEnd = conveyor.Position + (conveyor.CFrame.lookVector * (conveyor.Size.Z / 2))

-- Main loop with GENTLE speed control
while true do
	conveyor.Velocity = conveyor.CFrame.lookVector * NORMAL_SPEED
	
	-- Check all parts on conveyor and GENTLY slow them near the end
	for _, part in ipairs(workspace.PartStorage:GetChildren()) do
		if part:IsA("BasePart") and part:FindFirstChild("Cash") then
			local distance = (part.Position - conveyorEnd).Magnitude
			
			-- If VERY near the end (2 studs), kill horizontal velocity for straight drop
			if distance < 2 then
				local vel = part.AssemblyLinearVelocity
				part.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
			-- If in slow zone, reduce velocity GENTLY (70% speed instead of 50%)
			elseif distance < SLOW_ZONE_DISTANCE then
				local vel = part.AssemblyLinearVelocity
				part.AssemblyLinearVelocity = Vector3.new(
					vel.X * 0.7,  -- Keep 70% speed (was 0.5 = 50%)
					vel.Y,
					vel.Z * 0.7
				)
			end
		end
	end
	
	task.wait(0.1)
end
