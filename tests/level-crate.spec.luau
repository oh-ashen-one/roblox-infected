-- LevelMath + CrateRoll tests. Run with: lune run tests/run
local LevelMath = require("../src/shared/LevelMath")
local CrateRoll = require("../src/shared/CrateRoll")

local tests = {}

function tests.level_curve_is_monotonic()
	local prev = -1
	for level = 1, 60 do
		local xp = LevelMath.xpForLevel(level)
		assert(xp > prev, "xp curve must strictly increase")
		prev = xp
	end
end

function tests.level_for_xp_roundtrips()
	for level = 1, 40 do
		local xp = LevelMath.xpForLevel(level)
		assert(LevelMath.levelForXp(xp) == level, "exact xp should land on the level")
		if level > 1 then
			assert(LevelMath.levelForXp(xp - 1) == level - 1, "one xp short stays below")
		end
	end
end

function tests.progress_never_negative()
	for _, xp in { 0, 1, 99, 100, 250, 10000 } do
		local level, into, needed = LevelMath.progress(xp)
		assert(level >= 1 and into >= 0 and needed > into, "progress invariants")
	end
end

function tests.no_reward_when_level_unchanged()
	local xp = LevelMath.xpForLevel(3)
	local r = LevelMath.levelUpRewards(xp, xp + 1)
	assert(r.levelsGained == 0 and r.coins == 0 and r.keys == 0)
end

function tests.level_up_grants_scaled_reward()
	-- Crossing exactly into level 2.
	local r = LevelMath.levelUpRewards(0, LevelMath.xpForLevel(2))
	assert(r.newLevel == 2 and r.levelsGained == 1)
	assert(r.coins == 100, "50 * level 2")
end

function tests.multiple_levels_sum_rewards()
	-- Jump from level 1 straight to level 6 sums levels 2..6, with a key at level 5.
	local r = LevelMath.levelUpRewards(0, LevelMath.xpForLevel(6))
	assert(r.newLevel == 6 and r.levelsGained == 5)
	local expectedCoins = 50 * (2 + 3 + 4 + 5 + 6)
	assert(r.coins == expectedCoins, "sum of per-level coins")
	assert(r.keys == 1, "one key for crossing level 5")
end

function tests.every_fifth_level_gives_a_key()
	assert(LevelMath.rewardForLevel(5).keys == 1)
	assert(LevelMath.rewardForLevel(10).keys == 1)
	assert(LevelMath.rewardForLevel(7).keys == 0)
	assert(LevelMath.rewardForLevel(1).coins == 0, "starting level pays nothing")
end

local RARITIES = {
	{ name = "Common", weight = 55 },
	{ name = "Rare", weight = 40 },
	{ name = "Legendary", weight = 5 },
}
local CATALOG = {
	{ id = "a", rarity = "Common" },
	{ id = "b", rarity = "Common" },
	{ id = "c", rarity = "Rare" },
	{ id = "d", rarity = "Legendary" },
}

function tests.roll_rarity_respects_weights()
	assert(CrateRoll.rollRarity(RARITIES, function()
		return 0
	end) == "Common")
	assert(CrateRoll.rollRarity(RARITIES, function()
		return 56 / 100
	end) == "Rare")
	assert(CrateRoll.rollRarity(RARITIES, function()
		return 0.99
	end) == "Legendary")
end

function tests.open_returns_winner_and_decoys()
	local seed = 42
	local function lcg(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local winner, decoys = CrateRoll.open(CATALOG, RARITIES, 3, lcg)
	assert(type(winner) == "string" and #winner > 0)
	assert(#decoys == 2)
end

function tests.legendary_rate_is_about_right()
	local seed = 7
	local function lcg(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local legendaries = 0
	local n = 5000
	for _ = 1, n do
		if CrateRoll.rollRarity(RARITIES, lcg) == "Legendary" then
			legendaries += 1
		end
	end
	local rate = legendaries / n
	assert(rate > 0.02 and rate < 0.09, "legendary rate off: " .. rate)
end

return tests
