--[[
	Conveyor Script - ADVANCED with Smart Drop Zone
	✅ Normal speed in middle, slows down at end
	✅ Automatic velocity dampening
	✅ Items drop perfectly straight
]]

local conveyor = script.Parent
local NORMAL_SPEED = 10
local SLOW_ZONE_DISTANCE = 8  -- Start slowing down this far from the end

-- Calculate conveyor end position
local conveyorEnd = conveyor.Position + (conveyor.CFrame.lookVector * (conveyor.Size.Z / 2))

-- Main loop with smart speed control
while true do
	conveyor.Velocity = conveyor.CFrame.lookVector * NORMAL_SPEED
	
	-- Check all parts on conveyor and slow them near the end
	for _, part in ipairs(workspace.PartStorage:GetChildren()) do
		if part:IsA("BasePart") and part:FindFirstChild("Cash") then
			local distance = (part.Position - conveyorEnd).Magnitude
			
			-- If near the end, kill horizontal velocity
			if distance < 3 then
				local vel = part.AssemblyLinearVelocity
				part.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
			-- If in slow zone, reduce velocity
			elseif distance < SLOW_ZONE_DISTANCE then
				local vel = part.AssemblyLinearVelocity
				part.AssemblyLinearVelocity = Vector3.new(
					vel.X * 0.5,
					vel.Y,
					vel.Z * 0.5
				)
			end
		end
	end
	
	task.wait(0.1)
end
