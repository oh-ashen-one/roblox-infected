-- Reward math tests. Run with: lune run tests/run
local Rewards = require("../src/shared/Rewards")

local CONFIG = {
	ZombieKill = 8,
	Conversion = 25,
	FirstBlood = 40,
	SurvivedRound = 75,
	LastSurvivor = 100,
	WinMultiplier = 2,
}

local FULL = { won = false, playerCount = 30, minPlayers = 4, fullRewardCount = 10 }

local tests = {}

function tests.full_lobby_pays_base()
	assert(Rewards.payout(CONFIG, "ZombieKill", FULL) == 8)
	assert(Rewards.payout(CONFIG, "Conversion", FULL) == 25)
	assert(Rewards.payout(CONFIG, "LastSurvivor", FULL) == 100)
end

function tests.win_doubles()
	local opts = { won = true, playerCount = 30, minPlayers = 4, fullRewardCount = 10 }
	assert(Rewards.payout(CONFIG, "SurvivedRound", opts) == 150)
end

function tests.small_lobby_scales_down()
	local opts = { won = false, playerCount = 5, minPlayers = 4, fullRewardCount = 10 }
	assert(Rewards.payout(CONFIG, "LastSurvivor", opts) == 50, "5/10 of 100")
	assert(Rewards.payout(CONFIG, "ZombieKill", opts) == 4)
end

function tests.below_min_pays_zero()
	local opts = { won = true, playerCount = 3, minPlayers = 4, fullRewardCount = 10 }
	assert(Rewards.payout(CONFIG, "Conversion", opts) == 0)
end

function tests.at_full_count_pays_base()
	local opts = { won = false, playerCount = 10, minPlayers = 4, fullRewardCount = 10 }
	assert(Rewards.payout(CONFIG, "FirstBlood", opts) == 40)
end

function tests.rounds_to_nearest_coin()
	local opts = { won = false, playerCount = 7, minPlayers = 4, fullRewardCount = 10 }
	-- 8 * 0.7 = 5.6 -> 6
	assert(Rewards.payout(CONFIG, "ZombieKill", opts) == 6)
end

function tests.unknown_event_errors()
	local ok = pcall(Rewards.payout, CONFIG, "Nonsense", FULL)
	assert(not ok, "unknown event should error")
end

return tests
