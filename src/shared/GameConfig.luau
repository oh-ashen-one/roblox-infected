--!strict
-- Every tunable number in the game lives here. No other module hardcodes balance values.

export type ZombieClass = {
	name: string,
	hordeThreshold: number, -- fraction of lobby infected before this class unlocks
	maxHealth: number,
	walkSpeedMult: number,
	attacksToKill: number,
	ability: string?, -- "scream" etc.
	abilityCooldown: number?,
}

local GameConfig = {
	Round = {
		MinPlayersToStart = 4,
		FullRewardPlayerCount = 10, -- below this, rewards scale down linearly
		IntermissionSeconds = 25,
		BaseRoundSeconds = 5 * 60,
		SecondsPerConversion = 20,
		MaxRoundSeconds = 8 * 60,
		RevealSeconds = 10,
		ZombieRespawnSeconds = 3,
		SpawnProtectionSeconds = 3,
		LastSurvivorsPingCount = 3, -- last N survivors get pinged
		PingIntervalSeconds = 15,
		PatientZeroRecentRounds = 3, -- rounds a player is deprioritized after being PZ
	},

	Combat = {
		SurvivorMaxHealth = 100,
		PatientZero = {
			SprintMult = 1.2,
			ThrowKnifeOneHit = true,
			MeleeOneHit = true,
			ThrowCooldown = 2.0,
			MeleeCooldown = 0.8,
			ThrowSpeed = 120, -- studs/s initial projectile velocity
			ThrowGravity = 40, -- studs/s^2 applied to knife arc
			MaxThrowRange = 150,
		},
		Zombie = {
			MeleeDamage = 50, -- 2 hits to convert
			MeleeCooldown = 1.0,
			MeleeRange = 7,
		},
		LastStand = {
			DamageResistMult = 0.5, -- takes 50% damage
			WeaponId = "Minigun",
		},
		Guns = {
			-- id = {damagePerShot, fireRateRps, magSize, reloadSeconds, hitscanRange, pellets?}
			AssaultRifle = { Damage = 34, FireRate = 8, Mag = 30, Reload = 2.2, Range = 300 },
			Shotgun = { Damage = 12, FireRate = 1.4, Mag = 6, Reload = 2.8, Range = 60, Pellets = 8 },
			SMG = { Damage = 22, FireRate = 12, Mag = 35, Reload = 1.9, Range = 180 },
			Pistol = { Damage = 30, FireRate = 5, Mag = 12, Reload = 1.5, Range = 200 },
			Minigun = { Damage = 18, FireRate = 25, Mag = 250, Reload = 5.0, Range = 250 },
		},
		ZombieBaseHealth = 120, -- ~2-4 shots depending on gun
	},

	ZombieClasses = {
		{ name = "Walker", hordeThreshold = 0, maxHealth = 120, walkSpeedMult = 1.0, attacksToKill = 2 },
		{ name = "Runner", hordeThreshold = 0.25, maxHealth = 70, walkSpeedMult = 1.35, attacksToKill = 2 },
		{ name = "Tank", hordeThreshold = 0.5, maxHealth = 300, walkSpeedMult = 0.8, attacksToKill = 2 },
		{
			name = "Screamer",
			hordeThreshold = 0.75,
			maxHealth = 100,
			walkSpeedMult = 1.1,
			attacksToKill = 2,
			ability = "scream", -- pulses survivor positions
			abilityCooldown = 30,
		},
	} :: { ZombieClass },

	Rewards = {
		-- Coins; XP mirrors coins 1:1
		ZombieKill = 8, -- survivor kills a zombie
		Conversion = 25, -- infected converts a survivor
		FirstBlood = 40,
		SurvivedRound = 75,
		LastSurvivor = 100,
		WinMultiplier = 2,
	},

	-- Bots fill the lobby so a solo (or under-filled) server still plays a full round.
	Bots = {
		Enabled = true,
		TargetPlayers = 8, -- fill humans + bots up to this headcount
		MaxBots = 11, -- never spawn more than this
		ThinkInterval = 0.35, -- AI tick period (seconds)
	},

	Movement = {
		BaseWalkSpeed = 16,
		SprintWalkSpeed = 24,
		-- AntiCheat: max studs/s tolerated before flagging (sprint * PZ mult + slack)
		MaxToleratedSpeed = 24 * 1.2 * 1.35 + 6, -- fastest legit (Runner sprint) + slack
		TeleportFlagStuds = 80, -- moved more than this in one check window = flag
		CheckIntervalSeconds = 1,
	},

	Economy = {
		CrateCostCoins = 750,
		CrateCostRobuxProductKey = "CrateKey1",
		-- color stored as {r, g, b} 0-255 so this module stays pure (unit-testable outside Roblox)
		Rarities = {
			{ name = "Common", weight = 55, color = { 178, 178, 178 } },
			{ name = "Uncommon", weight = 25, color = { 88, 200, 88 } },
			{ name = "Rare", weight = 12, color = { 70, 130, 240 } },
			{ name = "Epic", weight = 5.5, color = { 170, 80, 230 } },
			{ name = "Legendary", weight = 2, color = { 240, 170, 40 } },
			{ name = "Chroma", weight = 0.5, color = { 255, 90, 160 } },
		},
	},

	-- Roblox audio asset ids; 0 disables a sound. Filled/verified in the Studio pass
	-- (audio must be owned/licensed to play for all users, so IDs are set there).
	-- All Roblox-owned (creator id 1) classic audio — playable in any experience.
	Sounds = {
		GunShot = 12222132, -- "Shoulder fired rocket" (short punchy crack)
		KnifeThrow = 12222200, -- "swoosh"
		Conversion = 9120031442, -- thunder/roar sting
		RoundStart = 12222019, -- "HalloweenLightning"
		SurvivorsWin = 12222253, -- "victory"
		InfectedWin = 12222030, -- "HalloweenThunder"
		Heartbeat = 0, -- no Roblox-owned loop found; disabled until a licensed one is picked
		LobbyMusic = 15675069601, -- "Roblox_UI_Loop_Calm_Music" (95s loop)
	},

	-- Created on Creator Hub 2026-07-17 (universe 10518289514). All start off-sale;
	-- prices go live only after Hari approves them.
	Products = {
		GamePasses = {
			DoubleCoins = 1919414556,
			XPBoost = 1917980542,
			VIP = 1918454539,
			Radio = 1918040566,
		},
		DevProducts = {
			Coins1000 = 3610363831,
			Coins5000 = 3610363881,
			Coins12000 = 3610363919,
			CrateKey1 = 3610364225,
			CrateKey5 = 3610364383,
			PatientZeroToken = 3610364441,
		},
	},
}

return GameConfig
