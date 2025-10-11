--[[
	Cinnamoroll Dropper 3 - MODERNIZED Premium Star Style
	✅ Uses Kawaii Cat mesh (rbxassetid://1652187761)
	✅ Rainbow sparkles + star particles
	✅ Premium effects
]]

local Core = require(game.ReplicatedStorage.Modules.DropperCore)

task.wait(1)

-- Soft pastel rainbow function
local function getRainbowColor(time)
	local hue = (time * 0.05) % 1
	local sat = 0.3 -- Low saturation for pastel
	local val = 0.95
	return Color3.fromHSV(hue, sat, val)
end

Core.Run({
	model = script.Parent,
	partStorage = workspace:WaitForChild("PartStorage"),

	namePrefix = "PremiumStar_",
	dropGroup = "CinnamorollOrbs3",

	dropRate = 0.6,
	cashValue = 50,
	lifetime = 2000,

	size = Vector3.new(0.785, 2.065, 2.252),
	color = Color3.new(1, 1, 1),
	material = Enum.Material.SmoothPlastic,
	transparency = 0,

	mesh = {
		meshType = Enum.MeshType.FileMesh,
		meshId = "rbxassetid://1652187761", -- Cat mesh
		textureId = "rbxassetid://1652088642", -- Cat texture
		scale = Vector3.new(0.2, 0.2, 0.2),
	},

	light = {
		brightness = 1,
		range = 10,
		color = Color3.new(1, 1, 1),
		spawnFlash = true,
		spawnBrightness = 2,
		flashDuration = 0.6,
	},

	spawn = {
		rotation = CFrame.Angles(0, 0, 0), -- Upright, no rotation
		velocity = Vector3.new(0, -10, 0),
		angularVelocity = Vector3.new(0, 5, 0), -- Gentle spin
	},
	spawnYOffset = -1.75,

	animation = {
		mesh = {
			startScale = Vector3.new(0.05, 0.05, 0.05),
			endScale = Vector3.new(0.2, 0.2, 0.2),
			duration = 0.4,
			style = Enum.EasingStyle.Back,
		},
	},

	particles = {
		-- Rainbow sparkles
		{
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 25,
			Lifetime = NumberRange.new(1.5, 2.5),
			Speed = NumberRange.new(1, 2),
			SpreadAngle = Vector2.new(45, 45),
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, getRainbowColor(tick())),
				ColorSequenceKeypoint.new(0.5, getRainbowColor(tick() + 0.5)),
				ColorSequenceKeypoint.new(1, getRainbowColor(tick() + 1))
			}),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 0)
			}),
			LightEmission = 0.8,
			VelocityInheritance = 0.3,
		},
		-- Star particles
		{
			Texture = "rbxasset://textures/particles/star.dds",
			Rate = 10,
			Lifetime = NumberRange.new(2, 3),
			Speed = NumberRange.new(1),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(1, 0.1)
			}),
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 200)),
			LightEmission = 1,
		},
	},

	spawnParticles = {
		-- Premium spawn ring
		{
			Texture = "rbxassetid://262979222",
			Rate = 0,
			Speed = NumberRange.new(0),
			Lifetime = NumberRange.new(0.4),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 3)
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 1)
			}),
			Color = ColorSequence.new(Color3.fromRGB(255, 200, 200)),
			emit = 2,
			autoDestroy = true,
			lifetime = 1,
		},
	},

	density = 0.2,
	friction = 0.4,
	elasticity = 0.3,
})
