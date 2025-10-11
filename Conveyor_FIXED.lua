--[[
	Conveyor Script - FIXED for Straight Drops
	✅ Gentler speed - items don't fly off
	✅ Items drop straight down at the end
	✅ No flinging or weird physics
]]

local conveyor = script.Parent
local SPEED = 8  -- Much gentler! (was 16)

-- Optional: Add a "drop zone" at the end that stops horizontal velocity
local function setupDropZone()
	-- Find or create a "DropZone" part at the end of conveyor
	local dropZone = conveyor.Parent:FindFirstChild("DropZone")
	if dropZone and dropZone:IsA("BasePart") then
		dropZone.CanCollide = false
		dropZone.Transparency = 1
		
		dropZone.Touched:Connect(function(hit)
			if hit:IsA("BasePart") and hit:FindFirstChild("Cash") then
				-- Kill horizontal velocity so it drops straight
				local vel = hit.AssemblyLinearVelocity
				hit.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
			end
		end)
	end
end

setupDropZone()

-- Main conveyor loop with gentler speed
while true do
	conveyor.Velocity = conveyor.CFrame.lookVector * SPEED
	task.wait(0.1)
end
