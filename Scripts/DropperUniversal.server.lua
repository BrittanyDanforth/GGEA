--!strict

-- Universal Dropper Script (1–13, skip 7)
-- - Requires ReplicatedStorage/Modules/DropperCore
-- - Set optional attributes on this Script:
--   TemplateName (string)   → name of template Model in ReplicatedStorage (default: "HelloKittyPL")
--   NamePrefix  (string)    → default "Drop_"
--   DropGroup   (string)    → default "Drops" (no drop-vs-drop collisions)
--   DropRate    (number)    → default 1.2
--   CashValue   (number)    → default 10
--   Lifetime    (number)    → nil keeps until collected
--   Scale       (number)    → default 0.9
--   ExtraLower  (number)    → default 0.45
--   FadeTime    (number)    → default 0.35
--   YawDegrees  (number)    → default -90
--   CashOn      (string)    → "primary" | "all" (default "primary")

local RS = game:GetService("ReplicatedStorage")
local Core = require(RS:WaitForChild("Modules"):WaitForChild("DropperCore"))

local templateName = script:GetAttribute("TemplateName") or "HelloKittyPL"
local templateModel = RS:WaitForChild(templateName) :: Model

local function getString(name: string, default: string): string
	local v = script:GetAttribute(name)
	if typeof(v) == "string" and v ~= "" then return v :: string end
	return default
end

local function getNumber(name: string, default: number): number
	local v = script:GetAttribute(name)
	if typeof(v) == "number" then return v :: number end
	return default
end

local function getOptionalNumber(name: string): number?
	local v = script:GetAttribute(name)
	if typeof(v) == "number" then return v :: number end
	return nil
end

local function getCashOn(name: string, default: string): ("primary" | "all")
	local v = script:GetAttribute(name)
	if v == "primary" or v == "all" then
		return v
	end
	return default == "all" and "all" or "primary"
end

-- Wait for PartStorage in workspace
local partStorage = workspace:WaitForChild("PartStorage")

Core.RunModel({
	model = script.Parent,
	partStorage = partStorage,
	templateModel = templateModel,

	namePrefix = getString("NamePrefix", "Drop_"),
	dropGroup = getString("DropGroup", "Drops"),
	playerGroup = "Players",
	dropRate = getNumber("DropRate", 1.2),
	cashValue = getNumber("CashValue", 10),
	lifetime = getOptionalNumber("Lifetime"),

	scaleFactor = getNumber("Scale", 0.9),
	extraLower = getNumber("ExtraLower", 0.45),
	fadeTime = getNumber("FadeTime", 0.35),
	yawDegrees = getNumber("YawDegrees", -90),
	cashOn = getCashOn("CashOn", "primary"),

	density = 0.7,
	friction = 0.3,
	elasticity = 0.05,

	collectorNames = { "Collector", "CollectorZone", "Receiver", "Sell", "SellPad" },
	collectorTags = { "Collector", "SellZone" },
})
