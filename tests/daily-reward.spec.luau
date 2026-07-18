-- Daily-reward streak logic tests. Run with: lune run tests/run
local DailyReward = require("../src/shared/DailyReward")

local tests = {}

function tests.day_number_is_utc_day()
	assert(DailyReward.dayNumber(0) == 0)
	assert(DailyReward.dayNumber(86400) == 1)
	assert(DailyReward.dayNumber(86399) == 0)
	assert(DailyReward.dayNumber(86400 * 100 + 5) == 100)
end

function tests.first_ever_claim_starts_streak_at_one()
	local r = DailyReward.evaluate({ lastClaimDay = 0, streak = 0 }, 20000)
	assert(r.claimable == true)
	assert(r.streak == 1)
	assert(r.reward.coins == 100)
end

function tests.same_day_is_not_claimable()
	local r = DailyReward.evaluate({ lastClaimDay = 500, streak = 3 }, 500)
	assert(r.claimable == false)
	assert(r.alreadyClaimed == true)
	assert(r.reward == nil)
	assert(r.streak == 3, "streak unchanged")
end

function tests.consecutive_day_continues_streak()
	local r = DailyReward.evaluate({ lastClaimDay = 500, streak = 3 }, 501)
	assert(r.claimable == true)
	assert(r.streak == 4)
	assert(r.reward.coins == DailyReward.Ladder[4].coins)
end

function tests.skipped_day_resets_streak()
	local r = DailyReward.evaluate({ lastClaimDay = 500, streak = 6 }, 503)
	assert(r.claimable == true)
	assert(r.streak == 1, "gap of >1 day resets")
	assert(r.reward.coins == 100)
end

function tests.ladder_wraps_after_seven()
	-- streak 8 -> position 1 on the ladder again
	assert(DailyReward.rewardFor(8).coins == DailyReward.Ladder[1].coins)
	assert(DailyReward.rewardFor(14).coins == DailyReward.Ladder[7].coins)
	assert(DailyReward.rewardFor(15).coins == DailyReward.Ladder[1].coins)
end

function tests.day_seven_is_the_big_payout()
	local r = DailyReward.rewardFor(7)
	assert(r.coins == 1500)
	assert(r.keys == 3)
end

return tests
