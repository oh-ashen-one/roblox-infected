-- Season-pass logic tests. Run with: lune run tests/run
local SeasonPass = require("../src/shared/SeasonPass")

local tests = {}

function tests.season_id_from_day()
	assert(SeasonPass.seasonId(0) == 0)
	assert(SeasonPass.seasonId(27) == 0)
	assert(SeasonPass.seasonId(28) == 1)
	assert(SeasonPass.seasonId(56) == 2)
end

function tests.tier_for_xp()
	assert(SeasonPass.tierForXp(0) == 0)
	assert(SeasonPass.tierForXp(999) == 0)
	assert(SeasonPass.tierForXp(1000) == 1)
	assert(SeasonPass.tierForXp(2500) == 2)
end

function tests.tier_caps_at_max()
	local huge = SeasonPass.XpPerTier * (SeasonPass.MaxTier + 50)
	assert(SeasonPass.tierForXp(huge) == SeasonPass.MaxTier)
end

function tests.progress_within_tier()
	local tier, into, span = SeasonPass.progress(1500)
	assert(tier == 1 and into == 500 and span == SeasonPass.XpPerTier)
end

function tests.xp_for_known_events_only()
	assert(SeasonPass.xpForEvent("win") == 200)
	assert(SeasonPass.xpForEvent("convert") == 50)
	assert(SeasonPass.xpForEvent("nonsense") == 0)
end

function tests.rewards_escalate_and_hit_milestones()
	local t5 = SeasonPass.rewardAt(5)
	assert(t5.free.keys == 1, "free key every 5 tiers")
	local t10 = SeasonPass.rewardAt(10)
	assert(t10.premium.pzTokens == 1, "premium pz token every 10 tiers")
	assert(SeasonPass.rewardAt(20).free.coins > SeasonPass.rewardAt(5).free.coins, "coins scale up")
end

return tests
