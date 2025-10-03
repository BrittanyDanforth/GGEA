-- This is the corrected ProductDatabase section
-- Make sure to use this exact structure

-- Product Database
local ProductDatabase = {
	categories = {
		{
			id = "cash",
			name = "Cash Packs",
			icon = Icons.cash,
			color = Theme.colors.success,
			description = "Boost your economy instantly",
		},
		{
			id = "passes",
			name = "Game Passes",
			icon = Icons.gamepass,
			color = Theme.colors.primary,
			description = "Permanent upgrades and benefits",
		},
		{
			id = "powerups",
			name = "Power-Ups",
			icon = Icons.powerups,
			color = Theme.colors.secondary,
			description = "Temporary boosts and effects",
		},
		{
			id = "special",
			name = "Special Offers",
			icon = Icons.special,
			color = Theme.colors.warning,
			description = "Limited time deals",
		},
	},
	
	products = {
		cash = {
			{
				id = 1897730242,
				name = "Starter Pack",
				amount = 1000,
				icon = Icons.coin,
				description = "Perfect for beginners",
				tags = {"popular", "starter"},
				discount = 0,
			},
			{
				id = 1897730373,
				name = "Builder Bundle",
				amount = 5000,
				icon = Icons.coin,
				description = "Expand your tycoon",
				tags = {"value"},
				discount = 10,
			},
			{
				id = 1897730467,
				name = "Pro Package",
				amount = 10000,
				icon = Icons.coin,
				description = "Serious business boost",
				tags = {"popular"},
				discount = 0,
			},
			{
				id = 1897730581,
				name = "Elite Vault",
				amount = 50000,
				icon = Icons.diamond,
				description = "Major expansion fund",
				tags = {"premium"},
				discount = 15,
			},
			{
				id = 1897730682,
				name = "Mega Cache",
				amount = 100000,
				icon = Icons.diamond,
				description = "Transform your empire",
				tags = {"premium", "popular"},
				discount = 20,
			},
			{
				id = 1897730783,
				name = "Quarter Million",
				amount = 250000,
				icon = Icons.crown,
				description = "Investment powerhouse",
				tags = {"premium", "exclusive"},
				discount = 25,
			},
		}, -- End of cash array
		
		passes = {
			{
				id = 1412171840,
				name = "Auto Collect",
				icon = Icons.lightning,
				description = "Automatically collects cash every minute",
				features = {
					"Collects cash automatically",
					"Works while offline",
					"Customizable intervals",
				},
				tags = {"essential", "automation"},
				hasToggle = true,
			},
			{
				id = 1398974710,
				name = "2x Cash",
				icon = Icons.star,
				description = "Double all earnings permanently",
				features = {
					"2x multiplier on all income",
					"Stacks with other bonuses",
					"Permanent upgrade",
				},
				tags = {"essential", "multiplier"},
			},
			{
				id = 1398974811,
				name = "VIP Access",
				icon = Icons.crown,
				description = "Exclusive VIP benefits and areas",
				features = {
					"Access to VIP areas",
					"Exclusive items",
					"Special chat tag",
					"Priority support",
				},
				tags = {"exclusive", "vip"},
			},
			{
				id = 1398974912,
				name = "Speed Boost",
				icon = Icons.lightning,
				description = "25% faster production speed",
				features = {
					"25% speed increase",
					"Affects all machines",
					"Permanent upgrade",
				},
				tags = {"productivity"},
			},
		}, -- End of passes array
		
		powerups = {
			{
				id = 2897730242,
				name = "2x Boost (1 Hour)",
				icon = Icons.fire,
				description = "Double earnings for 1 hour",
				duration = 3600,
				multiplier = 2,
				tags = {"boost", "temporary"},
			},
			{
				id = 2897730343,
				name = "5x Boost (30 Min)",
				icon = Icons.fire,
				description = "5x earnings for 30 minutes",
				duration = 1800,
				multiplier = 5,
				tags = {"boost", "temporary", "powerful"},
			},
		}, -- End of powerups array
		
		special = {
			{
				id = 3897730242,
				name = "Weekend Special",
				originalPrice = 500,
				price = 250,
				icon = Icons.sparkle,
				description = "50% off this weekend only!",
				expiresAt = os.time() + 172800, -- 48 hours
				tags = {"limited", "sale"},
			},
		}, -- End of special array
	}, -- End of products table
} -- End of ProductDatabase table