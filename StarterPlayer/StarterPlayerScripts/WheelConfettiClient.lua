--!strict
-- Confetti VFX for wheel spinning results

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Wait for remotes
local RemotesFolder = ReplicatedStorage:WaitForChild("WheelRemotes")
local SpinResult = RemotesFolder:WaitForChild("SpinResult")

-- Confetti colors (pink/purple theme to match your UI)
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 182, 193), -- Light pink
	Color3.fromRGB(255, 105, 180), -- Hot pink
	Color3.fromRGB(255, 20, 147),  -- Deep pink
	Color3.fromRGB(218, 112, 214), -- Orchid
	Color3.fromRGB(255, 215, 0),   -- Gold
	Color3.fromRGB(255, 255, 255), -- White
	Color3.fromRGB(173, 216, 230), -- Light blue
	Color3.fromRGB(255, 192, 203), -- Pink
}

-- Create confetti particle
local function createConfettiParticle(position: Vector3)
	local particle = Instance.new("Part")
	particle.Name = "Confetti"
	particle.Size = Vector3.new(0.3, 0.1, 0.3)
	particle.Material = Enum.Material.SmoothPlastic
	particle.Color = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)]
	particle.TopSurface = Enum.SurfaceType.Smooth
	particle.BottomSurface = Enum.SurfaceType.Smooth
	particle.CanCollide = false
	particle.Anchored = false
	particle.Position = position
	particle.Parent = workspace
	
	-- Random rotation
	particle.CFrame = particle.CFrame * CFrame.Angles(
		math.rad(math.random(0, 360)),
		math.rad(math.random(0, 360)),
		math.rad(math.random(0, 360))
	)
	
	-- Add velocity
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.Velocity = Vector3.new(
		math.random(-20, 20),
		math.random(15, 30),
		math.random(-20, 20)
	)
	bodyVelocity.Parent = particle
	
	-- Add spin
	local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
	bodyAngularVelocity.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bodyAngularVelocity.AngularVelocity = Vector3.new(
		math.random(-10, 10),
		math.random(-10, 10),
		math.random(-10, 10)
	)
	bodyAngularVelocity.Parent = particle
	
	-- Fade out
	local startTime = tick()
	local lifetime = math.random(2, 3)
	
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		local alpha = math.max(0, 1 - (elapsed / lifetime))
		
		particle.Transparency = 1 - alpha
		bodyVelocity.Velocity = bodyVelocity.Velocity - Vector3.new(0, 0.5, 0) -- Gravity
		
		if elapsed >= lifetime then
			connection:Disconnect()
			particle:Destroy()
		end
	end)
	
	-- Cleanup just in case
	Debris:AddItem(particle, lifetime + 1)
end

-- Create confetti burst
local function createConfettiBurst(position: Vector3, count: number)
	for i = 1, count do
		task.spawn(function()
			-- Small delay for staggered effect
			task.wait(math.random() * 0.1)
			createConfettiParticle(position)
		end)
	end
	-- NO SPARKLES - just pure confetti
end

-- Listen for spin results
SpinResult.OnClientEvent:Connect(function(ok, phase, label, amount, boostSeconds, resetAtUTC)
	if ok and phase == "done" then
		-- Wait a tiny bit for the wheel to finish
		task.wait(0.1)
		
		-- Find the wheel position
		local spinwheel = workspace:FindFirstChild("Spinwheel")
		if spinwheel then
			local wheelModel = spinwheel:FindFirstChild("Wheel")
			local position = Vector3.new(0, 10, 0) -- Default position
			
			if wheelModel then
				if wheelModel:IsA("Model") and wheelModel.PrimaryPart then
					position = wheelModel.PrimaryPart.Position + Vector3.new(0, 2, 0)
				elseif wheelModel:IsA("BasePart") then
					position = wheelModel.Position + Vector3.new(0, 2, 0)
				end
			end
			
			-- Create multiple bursts for bigger effect
			createConfettiBurst(position, 50)
			
			-- Additional bursts slightly offset
			task.wait(0.1)
			createConfettiBurst(position + Vector3.new(3, 0, 0), 30)
			task.wait(0.1)
			createConfettiBurst(position + Vector3.new(-3, 0, 0), 30)
			
			-- If it's a big win (50K or 2X boost), make it extra special
			if (amount and amount >= 50000) or (boostSeconds and boostSeconds > 0) then
				task.wait(0.2)
				createConfettiBurst(position + Vector3.new(0, 2, 0), 80)
				-- Just extra confetti, no shockwave effect
			end
		end
	end
end)

print("🎊 Wheel Confetti VFX loaded!")