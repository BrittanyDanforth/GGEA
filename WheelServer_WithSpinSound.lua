--!strict
-- WheelServer_v24h_claimAnywhere
-- Spins the wheel; result is claimed via CLAIM.
-- Daily gate can be "24H from claim" or "MIDNIGHT UTC".
-- Studio bypass supported.
-- ✨ NOW WITH SPINNING SOUND!

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local TweenService       = game:GetService("TweenService")
local DataStoreService   = game:GetService("DataStoreService")
local ServerStorage      = game:GetService("ServerStorage")
local RunService         = game:GetService("RunService")
local IS_STUDIO: boolean = RunService:IsStudio()

-- ========= scene / config =========
local spinwheel = workspace:WaitForChild("Spinwheel")
local okConfig, Config = pcall(function() return require(spinwheel:WaitForChild("WheelConfig")) end)
assert(okConfig, "[Wheel] Missing/invalid WheelConfig module")

local function listChildrenNames(parent: Instance): string
	local t = {}
	for _,c in ipairs(parent:GetChildren()) do table.insert(t, c.Name.."("..c.ClassName..")") end
	return table.concat(t, ", ")
end

local rawWheel = spinwheel:WaitForChild(Config.WHEEL_NAME, 15)
if not rawWheel then
	error(("[Wheel] Could not find '%s' under Spinwheel. Children: %s"):format(Config.WHEEL_NAME, listChildrenNames(spinwheel)))
end

local wheelModel: Model
if rawWheel:IsA("Model") then
	wheelModel = rawWheel
else
	wheelModel = Instance.new("Model")
	wheelModel.Name = rawWheel.Name
	wheelModel.Parent = spinwheel
	rawWheel.Parent = wheelModel
end

local function choosePrimaryPart(m: Model): BasePart
	local holder = m:FindFirstChild("Holder", true)
	if holder and holder:IsA("BasePart") then return holder end
	local best: BasePart? = nil; local vol = -1
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > vol then vol = v; best = d end
		end
	end
	assert(best, "[Wheel] No BasePart found in wheel model")
	return best :: BasePart
end
if not wheelModel.PrimaryPart then wheelModel.PrimaryPart = choosePrimaryPart(wheelModel) end

local pointer = spinwheel:WaitForChild(Config.POINTER_NAME, 10)
assert(pointer and pointer:IsA("BasePart"), ("[Wheel] Missing pointer '%s'"):format(Config.POINTER_NAME))

-- ========= remotes =========
local remFolder = ReplicatedStorage:FindFirstChild("WheelRemotes") or Instance.new("Folder")
remFolder.Name = "WheelRemotes"
remFolder.Parent = ReplicatedStorage

local function ensureRemoteEvent(name: string): RemoteEvent
	local r = remFolder:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then return r end
	if r then r:Destroy() end
	local ev = Instance.new("RemoteEvent"); ev.Name = name; ev.Parent = remFolder
	return ev
end
local function ensureRemoteFunction(name: string): RemoteFunction
	local r = remFolder:FindFirstChild(name)
	if r and r:IsA("RemoteFunction") then return r end
	if r then r:Destroy() end
	local fn = Instance.new("RemoteFunction"); fn.Name = name; fn.Parent = remFolder
	return fn
end

local SpinRequestFn: RemoteFunction = ensureRemoteFunction("SpinRequest")
local SpinRequestEv: RemoteEvent    = ensureRemoteEvent("SpinRequestEvent")
local SpinResult   : RemoteEvent    = ensureRemoteEvent("SpinResult")
local SpinBroadcast: RemoteEvent    = ensureRemoteEvent("SpinBroadcast")
local ClaimReward  : RemoteEvent    = ensureRemoteEvent("ClaimReward")

-- ========= gating / cooldowns =========
local dailyDS = DataStoreService:GetDataStore(Config.DS_NAME)
local serverBusy = false
local serverCooldown: {[number]: number} = {}          -- anti-spam cooldown (seconds)
local pending: {[number]: {key: string, amount: number, boost: number}} = {} -- unclaimed result

-- Whitelist (treated as in-group)
local whitelistNameSet: {[string]: boolean} = {}
for _, n in ipairs(Config.WHITELIST_USERNAMES or {}) do
	if typeof(n) == "string" and n ~= "" then whitelistNameSet[string.lower(n)] = true end
end
local whitelistIdSet: {[number]: boolean} = {}
for _, id in ipairs(Config.WHITELIST_USERIDS or {}) do
	local num = tonumber(id)
	if num then whitelistIdSet[num] = true end
end
local function isWhitelisted(p: Player): boolean
	if whitelistIdSet[p.UserId] then return true end
	if whitelistNameSet[string.lower(p.Name)] then return true end
	return false
end

local function inGroup(p: Player): boolean
	if isWhitelisted(p) then return true end
	if Config.GROUP_ID and Config.GROUP_ID > 0 then
		local ok, res = pcall(function() return p:IsInGroup(Config.GROUP_ID) end)
		return ok and res or false
	end
	return true
end

-- Daily helpers
local function midnightNextUTC(): number
	local t = os.date("!*t")
	return os.time({year=t.year, month=t.month, day=t.day, hour=0, min=0, sec=0}) + 24*60*60
end
local function keyLastClaim(userId: number): string
	return string.format("last:%d", userId)
end

local function getReadyAtUTC(userId: number): number
	local now = os.time()
	if Config.DAILY_MODE == "MIDNIGHT" then
		-- If ever claimed today, the next ready is midnight; otherwise ready now.
		local ok, last = pcall(function() return dailyDS:GetAsync( keyLastClaim(userId) ) end)
		local lastNum = (ok and typeof(last) == "number") and (last :: number) or 0
		if lastNum > 0 then
			-- treat any saved value as "used today" for simplicity
			return midnightNextUTC()
		end
		return now
	else
		-- 24H from claim time
		local ok, last2 = pcall(function() return dailyDS:GetAsync( keyLastClaim(userId) ) end)
		local lastNum2 = (ok and typeof(last2) == "number") and (last2 :: number) or 0
		return lastNum2 + (Config.DAILY_COOLDOWN_SEC or (24*3600))
	end
end

local function setClaimNow(userId: number)
	local now = os.time()
	pcall(function() dailyDS:SetAsync( keyLastClaim(userId), now ) end)
end

-- ========= rotation math =========
local AXIS = string.upper(Config.AXIS or "X")
local function toLocal(v: Vector3): Vector3
	return wheelModel.PrimaryPart.CFrame:PointToObjectSpace(v)
end
local function planarAngleLocal(localPoint: Vector3): number
	if AXIS == "Y" then return math.atan2(localPoint.Z, localPoint.X)
	elseif AXIS == "Z" then return math.atan2(localPoint.Y, localPoint.X)
	else return math.atan2(localPoint.Z, localPoint.Y) end -- "X"
end
local function angleWrap(a: number): number
	while a > math.pi do a -= 2*math.pi end
	while a < -math.pi do a += 2*math.pi end
	return a
end

-- ========= prize indexing =========
type Prize = {name: string, part: BasePart}
local function largestPart(m: Model): BasePart?
	local best: BasePart?; local vol = -1
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then local v = d.Size.X*d.Size.Y*d.Size.Z; if v > vol then vol = v; best = d end end
	end
	return best
end
local function prizeKeyFrom(inst: Instance): string?
	local sv = inst:FindFirstChild("Prize"); if sv and sv:IsA("StringValue") and sv.Value ~= "" then return sv.Value end
	return inst.Name
end

local prizes: {Prize} = {}
for _, child in ipairs(wheelModel:GetChildren()) do
	if child == wheelModel.PrimaryPart then continue end
	if child:IsA("BasePart") then
		local key = prizeKeyFrom(child); if key and Config.REWARDS[key] then table.insert(prizes, {name = key, part = child}) end
	elseif child:IsA("Model") then
		local key = prizeKeyFrom(child)
		if key and Config.REWARDS[key] then
			local anchor = largestPart(child)
			if anchor then table.insert(prizes, {name = key, part = anchor}) else warn("[Wheel] Prize model has no BasePart: ", child:GetFullName()) end
		end
	end
end
if #prizes == 0 then
	for _, d in ipairs(wheelModel:GetDescendants()) do
		if d:IsA("BasePart") and d ~= wheelModel.PrimaryPart then
			local key = prizeKeyFrom(d); if key and Config.REWARDS[key] then table.insert(prizes, {name = key, part = d}) end
		end
	end
end
assert(#prizes > 0, "[Wheel] No prize parts/models match keys in Config.REWARDS")

-- ========= rigid pose =========
local function weldChildren(model: Model)
	local primary = model.PrimaryPart
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= primary then
			if not d:FindFirstChildOfClass("WeldConstraint") then
				local w = Instance.new("WeldConstraint"); w.Part0 = primary; w.Part1 = d; w.Parent = d
			end
			d.Anchored = false
		end
	end
	primary.Anchored = true
end
weldChildren(wheelModel)
local baseCFrame = wheelModel:GetPivot()

local function rotateWheelToAngle(delta: number, timeSec: number)
	local tracker = Instance.new("NumberValue"); tracker.Value = 0
	local tween = TweenService:Create(tracker, TweenInfo.new(timeSec, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Value = delta})
	local conn = tracker.Changed:Connect(function(v)
		local rotCF = (AXIS=="Y") and CFrame.Angles(0,v,0) or (AXIS=="Z") and CFrame.Angles(0,0,v) or CFrame.Angles(v,0,0)
		wheelModel:PivotTo(baseCFrame * rotCF)
	end)
	tween:Play(); tween.Completed:Wait(); conn:Disconnect(); tracker:Destroy()
	baseCFrame = wheelModel:GetPivot()
end

local function pointerAngle(): number
	local center = wheelModel.PrimaryPart.Position
	return planarAngleLocal(toLocal(center + (pointer.Position - center)))
end
local function prizeAngle(part: BasePart): number
	return planarAngleLocal(toLocal(part.Position))
end
local function pickPrize(): Prize
	return prizes[math.random(1, #prizes)]
end

-- ========= award integration =========
local function addCashToPlayer(p: Player, amount: number)
	if amount <= 0 then return end

	-- Try global API if present
	local g = rawget(_G, "AddPlayerMoney")
	if type(g) == "function" then
		local ok, res = pcall(function() return g(p.Name, amount) end)
		if ok and res == true then return end
	end

	-- Fallback ServerStorage
	local PlayerMoney = ServerStorage:FindFirstChild("PlayerMoney")
	if PlayerMoney then
		local playerValue = PlayerMoney:FindFirstChild(p.Name)
		if not playerValue then
			playerValue = Instance.new("IntValue")
			playerValue.Name = p.Name
			playerValue.Value = 0
			playerValue.Parent = PlayerMoney
		end
		playerValue.Value = playerValue.Value + amount
	end
end

local function award(p: Player, key: string)
	local info = Config.REWARDS[key]; if not info then return end
	if info.type == "cash" then
		addCashToPlayer(p, info.amount or 0)
	elseif info.type == "boost2x" then
		local seconds = math.max(0, math.floor((info.minutes or 0) * 60))
		p:SetAttribute("TwoXUntil", os.time() + seconds)
	end
end

-- ========= flow =========
local function canSpin(p: Player): (boolean, string, number?)
	-- spam cooldown
	if (serverCooldown[p.UserId] or 0) > os.clock() then return false, "cooldown_short", nil end
	if serverBusy then return false, "busy", nil end
	if pending[p.UserId] then return false, "unclaimed", nil end
	if not inGroup(p) then return false, "group", nil end

	-- Daily gate (skip in Studio if configured)
	if Config.DAILY_ENABLED and not (IS_STUDIO and Config.DAILY_IN_STUDIO) then
		local now = os.time()
		local readyAt = getReadyAtUTC(p.UserId)
		if now < readyAt then
			return false, "daily", readyAt
		end
	end
	return true, "ok", nil
end

local function doSpin(p: Player): (boolean, string, any)
	serverBusy = true
	local shortCD = (IS_STUDIO and (Config.COOLDOWN_IN_STUDIO_SEC or 0)) or (Config.COOLDOWN_SEC or 0)
	serverCooldown[p.UserId] = os.clock() + shortCD

	SpinResult:FireClient(p, true, "spinning", "…", nil, nil, nil)

	local prize = pickPrize()
	local delta = angleWrap(pointerAngle() - prizeAngle(prize.part))
	local extra = math.random(Config.EXTRA_TURNS.min, Config.EXTRA_TURNS.max)
	local finalDelta = delta + extra * 2 * math.pi
	
	-- ✨ FASTER spin time to match 2-second audio!
	local t = 2.5 -- Fast spin (2.5 seconds to match ~2 second audio + slowdown)
	
	-- 🎵 Play spinning sound DURING the spin!
	local spinSound = Instance.new("Sound")
	spinSound.SoundId = "rbxassetid://3847946070" -- 2-second spinning audio
	spinSound.Volume = 0.6
	spinSound.Parent = wheelModel.PrimaryPart
	spinSound:Play()
	
	-- Rotate wheel (this takes 2.5 seconds)
	rotateWheelToAngle(finalDelta, t)
	
	-- Clean up spinning sound
	if spinSound then spinSound:Destroy() end

	local info = Config.REWARDS[prize.name]
	local boostSec = (info and info.type == "boost2x") and math.floor((info.minutes or 0) * 60) or 0
	local amount   = (info and info.type == "cash")    and (info.amount or 0) or 0

	pending[p.UserId] = {key = prize.name, amount = amount, boost = boostSec}

	-- send done (timer begins on CLAIM)
	SpinResult:FireClient(p, true, "done", prize.name, amount, boostSec, nil)
	SpinBroadcast:FireAllClients({player = p, name = prize.name, boostUntil = p:GetAttribute("TwoXUntil")})

	-- 🎉 Celebration sound at the END (after spin)
	local celebSound = Instance.new("Sound")
	celebSound.SoundId = "rbxassetid://17417730290"
	celebSound.Volume = 0.5
	celebSound.Parent = wheelModel.PrimaryPart
	celebSound:Play()
	celebSound.Ended:Connect(function() celebSound:Destroy() end)

	serverBusy = false
	return true, "done", prize.name
end

ClaimReward.OnServerEvent:Connect(function(p: Player)
	local pend = pending[p.UserId]
	if not pend then return end

	-- Award (cash or boost)
	award(p, pend.key)
	pending[p.UserId] = nil

	-- Start cooldown *now* unless Studio bypass
	if Config.DAILY_ENABLED and not (IS_STUDIO and Config.DAILY_IN_STUDIO) then
		setClaimNow(p.UserId)
	end

	local readyAt = getReadyAtUTC(p.UserId) -- now+24h or next midnight
	SpinResult:FireClient(p, true, "claimed", pend.key, pend.amount, pend.boost, readyAt)
	SpinBroadcast:FireAllClients({ player = p, name = pend.key, boostUntil = p:GetAttribute("TwoXUntil") })
end)

SpinRequestFn.OnServerInvoke = function(p: Player)
	local ok, why, readyAt = canSpin(p)
	if not ok then
		SpinResult:FireClient(p, false, why, nil, nil, nil, readyAt)
		return false, why, ""
	end
	local ok2, status, label = doSpin(p)
	return ok2, status, label
end

SpinRequestEv.OnServerEvent:Connect(function(p: Player)
	local ok, why, readyAt = canSpin(p)
	if not ok then
		SpinResult:FireClient(p, false, why, nil, nil, nil, readyAt)
		return
	end
	doSpin(p)
end)

print(("[Wheel] Server ready — prizes:%d axis:%s wheel:%s pointer:%s (DailyMode=%s, StudioBypass=%s)")
	:format((function() local c=0 for _ in pairs(Config.REWARDS) do c+=1 end; return c end)(),
	string.upper(Config.AXIS or "X"), wheelModel.Name, pointer.Name, tostring(Config.DAILY_MODE), tostring(Config.DAILY_IN_STUDIO)))
