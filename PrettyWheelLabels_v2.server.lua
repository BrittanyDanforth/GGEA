-- PrettyWheelLabels_v2.server.lua  — smart rotation (auto-flip) + tidy layout

local wheel = script.Parent
wheel.Anchored = true

-- Read prize names from WheelConfig if available, else defaults
local names do
	local ok, cfg = pcall(function()
		local m = wheel:FindFirstChild("WheelConfig") or (wheel.Parent and wheel.Parent:FindFirstChild("WheelConfig"))
		return m and require(m)
	end)
	if ok and type(cfg)=="table" and type(cfg.Segments)=="table" and #cfg.Segments>0 then
		names = {}
		for _,s in ipairs(cfg.Segments) do names[#names+1] = s.name or "?" end
	else
		names = { "1,000 Cash","2,500 Cash","5,000 Cash","10,000 Cash","x2 Cash (10 min)","25,000 Cash","50,000 Cash","❤ JACKPOT 100,000" }
	end
end

-- ========= style / layout =========
local N            = 8
local OFFSET_DEG   = 0      -- nudge to line up with your art (+/- 10)
local RADIUS       = 0.46   -- closer to rim
local BOX_W        = 0.34
local BOX_H        = 0.13
local FONT         = Enum.Font.FredokaOne
local STROKE_ALPHA = 0.12
-- Rotation mode: "smart" (tangent + auto-flip), "tangent", or "upright"
local ROTATION_MODE = "smart"
-- ==================================

-- prettify text: 2x→2×, "(10 min)" new line, 50,000→50k
local function prettify(s)
	s = s:gsub("x2", "2×")
	s = s:gsub("%s*%((%d+%s*min)%)", "\n(%1)")
	local num = s:match("(%d[%d,]*)%s*Cash")
	if num then
		local cleaned = (num:gsub(",", ""))
		local n = tonumber(cleaned) or 0
		if n >= 1000 then
			local k = n/1000
			local short = (math.floor(k)==k) and (("%dk Cash"):format(k)) or (("%.1fk Cash"):format(k))
			s = s:gsub(num.."%s*Cash", short)
		end
	end
	return s
end

local function pickFace()
	for _,c in ipairs(wheel:GetChildren()) do
		if c:IsA("Decal") or c:IsA("Texture") then return c.Face end
	end
	local s = wheel.Size
	if s.X <= s.Y and s.X <= s.Z then return Enum.NormalId.Right end
	if s.Y <= s.X and s.Y <= s.Z then return Enum.NormalId.Top end
	return Enum.NormalId.Front
end
local FACE = pickFace()

-- wipe previous overlays
for _,g in ipairs(wheel:GetChildren()) do
	if g:IsA("SurfaceGui") and g.Name:match("^WheelOverlay") then g:Destroy() end
end

-- crisp canvas
local gui = Instance.new("SurfaceGui")
gui.Name = "WheelOverlay_"..FACE.Name
gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
gui.CanvasSize = Vector2.new(2048, 2048)
gui.Face = FACE
gui.LightInfluence = 0
gui.AlwaysOnTop = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Adornee = wheel
gui.Parent = wheel

local SEG = 360/N

-- Create text that curves along each pie slice segment
local function createPieSliceText(i, text)
	local segmentStart = (i - 1) * SEG + OFFSET_DEG
	local segmentEnd = i * SEG + OFFSET_DEG
	local segmentCenter = (segmentStart + segmentEnd) / 2
	
	-- Split text into characters for smooth curve
	local chars = {}
	for char in text:gmatch(".") do
		table.insert(chars, char)
	end
	
	local charCount = #chars
	if charCount == 0 then return end
	
	-- Calculate spacing along the pie slice arc
	local arcSpan = SEG * 0.6 -- Use 60% of segment width for text
	local startAngle = segmentStart + (SEG - arcSpan) / 2 -- Center the text in the slice
	
	for charIndex = 1, charCount do
		local char = chars[charIndex]
		if char ~= " " then -- Skip spaces for cleaner look
			-- Calculate position along the pie slice arc
			local arcProgress = (charIndex - 1) / math.max(charCount - 1, 1)
			local angle = startAngle + (arcProgress * arcSpan)
			local rad = math.rad(90 - angle)
			
			-- Position along the circle (pie slice edge)
			local pos = UDim2.fromScale(
				0.5 + math.cos(rad) * RADIUS,
				0.5 - math.sin(rad) * RADIUS
			)
			
			-- Rotation to be tangent to the circle at this point
			local rotation = -(angle - 90)
			
			-- Auto-flip text if it would be upside down
			local normalizedRot = ((rotation % 360) + 360) % 360
			if normalizedRot > 90 and normalizedRot < 270 then
				rotation = rotation + 180
			end
			
			-- Create holder for this character
			local holder = Instance.new("Frame")
			holder.Name = ("Slice_%02d_Char_%02d"):format(i, charIndex)
			holder.AnchorPoint = Vector2.new(0.5, 0.5)
			holder.Position = pos
			holder.Size = UDim2.fromScale(0.06, 0.10) -- Smaller size for individual chars
			holder.BackgroundTransparency = 1
			holder.Rotation = rotation
			holder.ZIndex = 2
			holder.Parent = gui
			
			-- Create text label for this character
			local tl = Instance.new("TextLabel")
			tl.Size = UDim2.fromScale(1, 1)
			tl.BackgroundTransparency = 1
			tl.TextScaled = true
			tl.Font = FONT
			tl.Text = char
			tl.TextColor3 = Color3.new(1, 1, 1)
			tl.TextStrokeColor3 = Color3.new(0, 0, 0)
			tl.TextStrokeTransparency = STROKE_ALPHA
			tl.TextXAlignment = Enum.TextXAlignment.Center
			tl.TextYAlignment = Enum.TextYAlignment.Center
			tl.Parent = holder
			
			-- Constrain text size
			local maxSize = Instance.new("UITextSizeConstraint")
			maxSize.MaxTextSize = 60
			maxSize.Parent = tl
		end
	end
end

-- Create pie slice text for each segment
for i = 1, N do
	local text = prettify(names[((i-1)%#names)+1])
	
	-- Create curved text along each pie slice
	createPieSliceText(i, text)
end