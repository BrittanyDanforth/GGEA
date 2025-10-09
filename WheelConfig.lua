--!strict
local Config = {}

-- ========================================
-- MODEL / PART NAMES (match your hierarchy)
-- ========================================
Config.WHEEL_NAME    = "Wheel"          -- Model or Part containing prize slices
Config.PAD_NAME      = "Detectorfloor"  -- Pad that opens the UI when player stands on it
Config.POINTER_NAME  = "Detector"       -- Arrow/pointer part indicating the winner
Config.AXIS          = "X"              -- Rotation axis: "X" | "Y" | "Z" (usually Y for vertical spin)

-- ========================================
-- ACCESS / GATING
-- ========================================
Config.GROUP_ID      = 986814499        -- Roblox group ID (0 = no group requirement)

-- DataStore name for daily tracking
Config.DS_NAME       = "DailyFreeSpin_v1"

-- Proximity distance (studs) to open UI
Config.OPEN_RANGE    = 12

-- ========================================
-- WHITELIST SYSTEM
-- ========================================
-- Players in this list are treated as "in the group" even if they're not
-- Useful for VIPs, testers, or admins

-- Add exact Roblox usernames here (case-insensitive)
Config.WHITELIST_USERNAMES = {
	"Player1",
	"Player2",
	"Player3",
	"Player4",
	"Player5",
	"Player6",
}

-- Or use numeric UserIds (more reliable if users change names)
Config.WHITELIST_USERIDS = {
	-- 123456789,
	-- 987654321,
}

-- ========================================
-- SPIN ANIMATION / FEEL
-- ========================================
Config.SPIN_TIME_MIN = 3.8              -- Minimum spin duration (seconds)
Config.SPIN_TIME_MAX = 5.2              -- Maximum spin duration (seconds)
Config.EXTRA_TURNS   = {min = 3, max = 5} -- Extra full rotations before landing
Config.COOLDOWN_SEC  = 4                -- Cooldown between spins (seconds)

-- ========================================
-- DEV / TESTING OPTIONS
-- ========================================
Config.DAILY_ENABLED   = true           -- Enable daily limit?
Config.DAILY_IN_STUDIO = false          -- Allow unlimited spins in Studio?

-- ========================================
-- PRIZES (MUST MATCH SLICE NAMES)
-- ========================================
-- Keys must match either:
-- 1. The part/model Name property
-- 2. A StringValue named "Prize" inside the part/model

Config.REWARDS = {
	-- Cash rewards
	["1KCASH"]        = {type = "cash",    amount = 1000},
	["5KCASH"]        = {type = "cash",    amount = 5000},
	["10KCASH"]       = {type = "cash",    amount = 10000},
	["15KCASH"]       = {type = "cash",    amount = 15000},
	["50KCASH"]       = {type = "cash",    amount = 50000},

	-- 2X Cash boosts (temporary)
	["2XCASH2MINUTE"] = {type = "boost2x", minutes = 2},
	["2XCASH5MINUTE"] = {type = "boost2x", minutes = 5},
}

return Config