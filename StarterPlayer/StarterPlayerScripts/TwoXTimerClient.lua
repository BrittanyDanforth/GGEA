-- StarterPlayerScripts/TwoXTimerClient
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:FindFirstChild("WheelRemotes")
local SpinBroadcast = Remotes and Remotes:FindFirstChild("SpinBroadcast")

local gui = Instance.new("ScreenGui")
gui.Name = "TwoXTimerGUI"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local pill = Instance.new("Frame")
pill.AnchorPoint = Vector2.new(1,1)
pill.Position = UDim2.fromScale(0.99,0.96)
pill.Size = UDim2.fromOffset(220, 42)
pill.BackgroundColor3 = Color3.fromRGB(255,186,220)
pill.BackgroundTransparency = 0.15
pill.Visible = false
pill.Parent = gui
local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,18); corner.Parent = pill

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1,1)
label.BackgroundTransparency = 1
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.TextColor3 = Color3.new(1,1,1)
label.Text = "2× Cash — 05:00"
label.Parent = pill

local function tickUI()
	local untilTs = player:GetAttribute("TwoXUntil") or 0
	local remain = untilTs - os.time()
	if remain > 0 then
		local m = math.floor(remain/60)
		local s = remain % 60
		label.Text = string.format("2× Cash — %02d:%02d", m, s)
		if not pill.Visible then pill.Visible = true end
	else
		if pill.Visible then pill.Visible = false end
	end
end

RunService.RenderStepped:Connect(tickUI)
player:GetAttributeChangedSignal("TwoXUntil"):Connect(tickUI)

if SpinBroadcast then
	SpinBroadcast.OnClientEvent:Connect(function(payload)
		if payload and payload.boostUntil then
			player:SetAttribute("TwoXUntil", payload.boostUntil)
		end
	end)
end