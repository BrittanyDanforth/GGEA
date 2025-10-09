--!strict
-- Mobile-first UI. After spin: ALWAYS show CLAIM right away.
-- After CLAIM: require leaving the pad once, then show countdown (if daily-locked).
-- If daily-locked before spinning: show countdown + OK.
-- No bottom hint text.

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")
local GuiService         = game:GetService("GuiService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== scene =====
local spinwheel  = workspace:WaitForChild("Spinwheel")
local okConfig, Config = pcall(function() return require(spinwheel:WaitForChild("WheelConfig")) end)
if not okConfig then warn("[WheelClient] Missing/invalid WheelConfig: ", Config); return end

local function findPad(): BasePart?
	local pad = spinwheel:FindFirstChild(Config.PAD_NAME)
	if pad and pad:IsA("BasePart") then return pad end
	pad = spinwheel:WaitForChild(Config.PAD_NAME, 10)
	if pad and pad:IsA("BasePart") then return pad end
	for _, d in ipairs(spinwheel:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == Config.PAD_NAME then return d end
	end
	return nil
end
local pad = findPad()
if not pad then
	local names = {}
	for _, c in ipairs(spinwheel:GetChildren()) do table.insert(names, c.Name.."("..c.ClassName..")") end
	warn(("[WheelClient] Could not find pad '%s'. Children: %s"):format(tostring(Config.PAD_NAME), table.concat(names, ", ")))
	return
end

-- ===== remotes =====
local RemotesFolder = ReplicatedStorage:WaitForChild("WheelRemotes")
local SpinRequestFn = RemotesFolder:FindFirstChild("SpinRequest")
local SpinRequestEv = RemotesFolder:FindFirstChild("SpinRequestEvent")
local SpinResult    = RemotesFolder:WaitForChild("SpinResult") :: RemoteEvent
local SpinBroadcast = RemotesFolder:WaitForChild("SpinBroadcast") :: RemoteEvent
local ClaimReward   = RemotesFolder:WaitForChild("ClaimReward")   :: RemoteEvent

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name = "WheelGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local darken = Instance.new("Frame")
darken.Size = UDim2.fromScale(1,1)
darken.BackgroundColor3 = Color3.new(0,0,0)
darken.BackgroundTransparency = 1
darken.Parent = gui

local modal = Instance.new("Frame")
modal.AnchorPoint = Vector2.new(0.5,0.5)
modal.Position = UDim2.fromScale(0.5,0.5)
modal.Size = UDim2.fromScale(0.36, 0.36)
modal.BackgroundColor3 = Color3.fromRGB(255,245,252)
modal.BorderSizePixel = 0
modal.Visible = false
modal.Parent = gui
local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,22); corner.Parent = modal
local stroke = Instance.new("UIStroke"); stroke.Thickness = 2; stroke.Color = Color3.fromRGB(255,204,235); stroke.Transparency = 0.3; stroke.Parent = modal

-- mobile zoom-out (phones)
local uiScale = Instance.new("UIScale"); uiScale.Scale = 1; uiScale.Parent = modal
local function applyPhoneScale()
	local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800,600)
	local inset = GuiService:GetGuiInset()
	local short = math.min(v.X, math.max(0, v.Y - inset.Y))
	local s
	if short <= 320 then s = 0.84 elseif short <= 360 then s = 0.87 elseif short <= 375 then s = 0.89
	elseif short <= 393 then s = 0.91 elseif short <= 414 then s = 0.93 else s = 0.95 end
	uiScale.Scale = s
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyPhoneScale)
applyPhoneScale()

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1,0.24)
title.BackgroundTransparency = 1
title.Text = "🎀 Daily Spin"
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255,120,170)
title.Parent = modal

local msg = Instance.new("TextLabel")
msg.Position = UDim2.fromScale(0,0.24)
msg.Size = UDim2.fromScale(1,0.36)
msg.BackgroundTransparency = 1
msg.TextWrapped = true
msg.Text = "Spin once per day for prizes!"
msg.Font = Enum.Font.Gotham
msg.TextScaled = true
msg.TextColor3 = Color3.fromRGB(90,60,80)
msg.Parent = modal

local spinBtn = Instance.new("TextButton")
spinBtn.AnchorPoint = Vector2.new(0.5,1)
spinBtn.Position = UDim2.fromScale(0.5,0.96)
spinBtn.Size = UDim2.fromScale(0.6,0.24)
spinBtn.Text = "Spin"
spinBtn.Font = Enum.Font.GothamBold
spinBtn.TextScaled = true
spinBtn.BackgroundColor3 = Color3.fromRGB(255,180,220)
spinBtn.TextColor3 = Color3.new(1,1,1)
spinBtn.AutoButtonColor = true
spinBtn.Parent = modal
local btnCorner = Instance.new("UICorner"); btnCorner.CornerRadius = UDim.new(1,0); btnCorner.Parent = spinBtn

local claimBtn = Instance.new("TextButton")
claimBtn.AnchorPoint = Vector2.new(0.5,1)
claimBtn.Position = UDim2.fromScale(0.5,0.96)
claimBtn.Size = UDim2.fromScale(0.6,0.24)
claimBtn.Text = "CLAIM"
claimBtn.Font = Enum.Font.GothamBold
claimBtn.TextScaled = true
claimBtn.BackgroundColor3 = Color3.fromRGB(180,235,200)
claimBtn.TextColor3 = Color3.new(1,1,1)
claimBtn.Visible = false
claimBtn.Parent = modal
local claimCorner = Instance.new("UICorner"); claimCorner.CornerRadius = UDim.new(1,0); claimCorner.Parent = claimBtn

-- ===== helpers & state =====
local open = false
local spinning = false
local busy = false
local requireExit = false
local awaitingClaim = false   -- forces CLAIM to show after spin
local claimMode: "award" | "ok" = "award"

-- countdown state (only used AFTER claim or when daily-locked before spin)
local cooldownResetAtUTC: number? = nil

local OPEN_RANGE = (Config.OPEN_RANGE or 12)
local EXIT_RANGE = OPEN_RANGE + 2

local function fmtHMS(sec: number): string
	sec = math.max(0, math.floor(sec))
	local h = math.floor(sec/3600)
	local m = math.floor((sec%3600)/60)
	local s = sec%60
	return string.format("%02d:%02d:%02d", h, m, s)
end

local function updateCountdownUI()
	if not cooldownResetAtUTC then return end
	local now = os.time()
	local remain = math.max(0, cooldownResetAtUTC - now)
	if remain <= 0 then
		cooldownResetAtUTC = nil
		msg.Text = "Spin once per day for prizes!"
		spinBtn.Visible = true
		claimBtn.Visible = false
		return
	end
	msg.Text = "Next spin in "..fmtHMS(remain)
	spinBtn.Visible = false
	claimBtn.Visible = true
	claimBtn.Text = "OK"
	claimMode = "ok"
end

RunService.Heartbeat:Connect(function()
	-- Only tick the countdown when we're *not* waiting for a claim
	if cooldownResetAtUTC and not awaitingClaim then updateCountdownUI() end
end)

local function show()
	if open or spinning or requireExit then return end
	open = true
	modal.Visible = true
	darken.BackgroundTransparency = 1
	TweenService:Create(darken, TweenInfo.new(0.2), {BackgroundTransparency = 0.35}):Play()
	modal.Size = UDim2.fromScale(0.2,0.2)
	TweenService:Create(modal, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.36,0.36)}):Play()

	if awaitingClaim then
		spinBtn.Visible = false
		claimBtn.Visible = true
		claimBtn.Text = "CLAIM"
		claimMode = "award"
	elseif cooldownResetAtUTC then
		updateCountdownUI()
	else
		spinBtn.Visible = true
		claimBtn.Visible = false
		msg.Text = "Spin once per day for prizes!"
	end
end

local function hide()
	if not open then return end
	open = false
	TweenService:Create(darken, TweenInfo.new(0.18), {BackgroundTransparency = 1}):Play()
	modal.Visible = false
end

local function hideAllForSpin()
	spinning = true
	hide()
end

local function showResult(label: string, amount: number?, boostSecs: number?)
	modal.Visible = true
	open = true
	darken.BackgroundTransparency = 0.35
	if boostSecs and boostSecs > 0 then
		msg.Text = string.format("You won: %s (2x active %dm) 🎉", label, math.floor(boostSecs/60))
	elseif amount and amount > 0 then
		msg.Text = string.format("You won: %s (+%s) 🎉", label, tostring(amount))
	else
		msg.Text = "You won: "..tostring(label).." 🎉"
	end
	spinBtn.Visible = false
	claimBtn.Visible = true
	claimBtn.Text = "CLAIM"
	claimMode = "award"
	
	-- Add a pulse animation to the modal for big wins
	if (amount and amount >= 50000) or (boostSecs and boostSecs > 0) then
		local originalSize = modal.Size
		TweenService:Create(modal, 
			TweenInfo.new(0.3, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
			{Size = originalSize + UDim2.fromScale(0.05, 0.05)}
		):Play()
		task.wait(0.3)
		TweenService:Create(modal,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{Size = originalSize}
		):Play()
	end
end

-- ===== proximity with exit logic & claim priority =====
RunService.RenderStepped:Connect(function()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local d = (hrp.Position - pad.Position).Magnitude
	local within = (d <= OPEN_RANGE)
	local clearlyOutside = (d >= EXIT_RANGE)

	if requireExit then
		if clearlyOutside then
			requireExit = false
		else
			hide()
		end
		return
	end

	if within then
		if awaitingClaim then
			show(); return
		end
		if not spinning then show() end
	else
		hide()
	end
end)

-- ===== spin & claim =====
local function requestSpin()
	if busy or spinning or requireExit or cooldownResetAtUTC or awaitingClaim then return end
	busy = true
	spinBtn.AutoButtonColor = false
	spinBtn.BackgroundTransparency = 0.3
	spinBtn.Text = "Spinning..."
	hideAllForSpin()

	if SpinRequestFn and SpinRequestFn:IsA("RemoteFunction") then
		pcall(function() (SpinRequestFn :: RemoteFunction):InvokeServer() end)
	elseif SpinRequestEv and SpinRequestEv:IsA("RemoteEvent") then
		(SpinRequestEv :: RemoteEvent):FireServer()
	else
		warn("[WheelClient] No SpinRequest remote found")
	end
end
spinBtn.MouseButton1Click:Connect(requestSpin)

claimBtn.MouseButton1Click:Connect(function()
	if claimMode == "award" then
		if ClaimReward and ClaimReward:IsA("RemoteEvent") then
			ClaimReward:FireServer()
		end
	end
	requireExit = true
	open = false
	spinning = false
	busy = false
	awaitingClaim = false
	modal.Visible = false
	darken.BackgroundTransparency = 1
end)

-- ===== result stream =====
-- SpinResult: (ok, phase, label, amount, boostSeconds, resetAtUTC)
SpinResult.OnClientEvent:Connect(function(ok, phase, label, amount, boostSeconds, resetAtUTC)
	if not ok then
		if phase == "daily" then
			cooldownResetAtUTC = tonumber(resetAtUTC)
			awaitingClaim = false
			open = true
			modal.Visible = true
			darken.BackgroundTransparency = 0.35
			updateCountdownUI()
			return
		end

		spinning = false
		busy = false
		darken.BackgroundTransparency = 0.35
		modal.Visible = true
		open = true
		spinBtn.Visible = true
		claimBtn.Visible = false

		if phase == "group" then
			msg.Text = "Join the group to spin."
		elseif phase == "cooldown" or phase == "busy" then
			msg.Text = "Please wait…"
		else
			msg.Text = "Not ready. Try again."
		end

		spinBtn.AutoButtonColor = true
		spinBtn.BackgroundTransparency = 0
		spinBtn.Text = "Spin"
		return
	end

	if phase == "spinning" then
		return
	elseif phase == "done" then
		awaitingClaim = true
		cooldownResetAtUTC = nil
		spinning = false
		busy = false
		showResult(tostring(label), tonumber(amount), tonumber(boostSeconds))
	elseif phase == "claimed" then
		awaitingClaim = false
		cooldownResetAtUTC = tonumber(resetAtUTC)
	end
end)

-- ===== NEW: mirror server boost timestamp when it goes live (post-claim) =====
SpinBroadcast.OnClientEvent:Connect(function(payload)
	if typeof(payload) == "table" and payload.player == player and payload.boostUntil then
		player:SetAttribute("TwoXUntil", payload.boostUntil)
	end
end)