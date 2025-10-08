-- Draw 8 large labels FLAT on the correct wheel face (Right/Left).
-- Put this Script under the Wheel Part (the image lives on this Part).

local wheel = script.Parent :: BasePart
wheel.Anchored = true

-- Prize names (fallback). If you have a WheelConfig with Segments, we'll use those names.
local names do
	local ok, cfg = pcall(function()
		local m = wheel:FindFirstChild("WheelConfig") or wheel:FindFirstAncestorOfClass("Model"):FindFirstChild("WheelConfig")
		return m and require(m)
	end)
	if ok and type(cfg)=="table" and type(cfg.Segments)=="table" and #cfg.Segments>0 then
		names = {}
		for _,s in ipairs(cfg.Segments) do names[#names+1] = s.name or "?" end
	else
		names = { "1k", "2.5k", "5k", "10k", "x2 (10m)", "25k", "50k", "100k" }
	end
end

-- === layout tweaks ===
local N = 8                       -- 8 slices on the art
local OFFSET_DEG = 0              -- nudge if labels aren't centered on colors
local RADIUS = 0.38               -- 0.28–0.40 = in/out from center
local BOX = 0.32                  -- label box size (fraction of face)
local ORIENT: "upright" | "tangent" = "tangent"  -- Changed to tangent for proper orientation
-- =======================

-- pick the CORRECT face automatically:
local function pickFace(): Enum.NormalId
	-- Prefer the face used by a Decal/Texture if present
	for _,c in ipairs(wheel:GetChildren()) do
		if c:IsA("Decal") or c:IsA("Texture") then
			return c.Face
		end
	end
	-- Otherwise, choose the face orthogonal to the SMALLEST axis:
	local s = wheel.Size
	if s.X <= s.Y and s.X <= s.Z then return Enum.NormalId.Right end  -- 0.5 × 10 × 10 ⇒ Right/Left
	if s.Y <= s.X and s.Y <= s.Z then return Enum.NormalId.Top end
	return Enum.NormalId.Front
end

local FACE = pickFace()
print("[WheelOverlay] using face:", FACE.Name, "size:", wheel.Size)

-- clear any old overlays we created before
for _,g in ipairs(wheel:GetChildren()) do
	if g:IsA("SurfaceGui") and g.Name:match("^WheelOverlay") then g:Destroy() end
end

-- Make a big, crisp canvas that's flat on the correct face
local gui = Instance.new("SurfaceGui")
gui.Name = "WheelOverlay_"..FACE.Name
gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
gui.CanvasSize = Vector2.new(2048, 2048)   -- VERY crisp
gui.Face = FACE
gui.LightInfluence = 0
gui.AlwaysOnTop = true                     -- render over the wheel art
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Adornee = wheel
gui.Parent = wheel

-- Create a container frame to hold all labels for easy rotation
local labelContainer = Instance.new("Frame")
labelContainer.Name = "LabelContainer"
labelContainer.Size = UDim2.fromScale(1, 1)
labelContainer.Position = UDim2.fromScale(0, 0)
labelContainer.BackgroundTransparency = 1
labelContainer.Parent = gui

local SEG = 360 / N
local function pos(i: number): UDim2
	-- center of each slice, clockwise from 12 o'clock
	local a = (i - 0.5) * SEG + OFFSET_DEG
	local rad = math.rad(90 - a)       -- convert to SurfaceGui coords
	local x = 0.5 + math.cos(rad) * RADIUS
	local y = 0.5 - math.sin(rad) * RADIUS
	return UDim2.fromScale(x, y)
end

for i = 1, N do
	local label = Instance.new("TextLabel")
	label.Name = ("Slice_%02d"):format(i)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = pos(i)
	label.Size = UDim2.fromScale(BOX, BOX)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1,1,1)
	label.TextStrokeColor3 = Color3.new(0,0,0)
	label.TextStrokeTransparency = 0.2
	label.Text = names[((i-1)%#names)+1]

	-- Rotate each label to match its slice orientation
	-- This makes text appear correctly oriented for each segment
	local sliceAngle = (i - 0.5) * SEG + OFFSET_DEG
	label.Rotation = -sliceAngle + 90  -- Adjust so text reads naturally in each slice

	label.Parent = labelContainer
end

-- Add a comment for future rotation functionality
-- To rotate the entire wheel with labels: labelContainer.Rotation = desiredAngle