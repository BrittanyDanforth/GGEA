--[[
	Conveyor Script - ALTERNATIVE (Even Gentler)
	✅ Super slow and controlled
	✅ Items barely move forward
	✅ Perfect for straight drops
]]

local conveyor = script.Parent
local SPEED = 5  -- Even slower!

-- Main loop
while true do
	conveyor.Velocity = conveyor.CFrame.lookVector * SPEED
	task.wait(0.1)
end
