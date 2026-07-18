-- Quest assignment + state logic tests. Run with: lune run tests/run
local Quests = require("../src/shared/Quests")

local tests = {}

function tests.period_math()
	assert(Quests.periodDaily(123) == 123)
	assert(Quests.periodWeekly(0) == 0)
	assert(Quests.periodWeekly(6) == 0)
	assert(Quests.periodWeekly(7) == 1)
	assert(Quests.periodWeekly(14) == 2)
end

function tests.assignment_is_stable_for_same_period_and_user()
	local a = Quests.assignmentFor("daily", 100, 42)
	local b = Quests.assignmentFor("daily", 100, 42)
	assert(#a == Quests.DailyCount)
	for i = 1, #a do
		assert(a[i].id == b[i].id, "same inputs -> same quests")
	end
end

function tests.assignment_changes_across_periods()
	-- Over several days the set should not be frozen to one identical list.
	local first = Quests.assignmentFor("daily", 1, 7)
	local differs = false
	for day = 2, 12 do
		local set = Quests.assignmentFor("daily", day, 7)
		for i = 1, #set do
			if set[i].id ~= first[i].id then
				differs = true
			end
		end
	end
	assert(differs, "daily quests should rotate across days")
end

function tests.assignment_returns_distinct_quests()
	local set = Quests.assignmentFor("daily", 55, 999)
	local seen = {}
	for _, q in set do
		assert(not seen[q.id], "no duplicate quest in a set")
		seen[q.id] = true
	end
end

function tests.weekly_uses_weekly_pool()
	local set = Quests.assignmentFor("weekly", 3, 1)
	assert(#set == Quests.WeeklyCount)
	for _, q in set do
		assert(q.id:sub(1, 2) == "w_", "weekly quests come from the weekly pool")
	end
end

function tests.state_tracks_progress_and_claim()
	local q = { id = "x", desc = "", metric = "kill", target = 10, coins = 1, keys = 0, xp = 1 }
	local s1 = Quests.state(q, 4, false)
	assert(s1.complete == false and s1.claimable == false and s1.progress == 4)
	local s2 = Quests.state(q, 10, false)
	assert(s2.complete == true and s2.claimable == true)
	local s3 = Quests.state(q, 15, false)
	assert(s3.progress == 10, "progress caps at target")
	local s4 = Quests.state(q, 12, true)
	assert(s4.complete == true and s4.claimable == false, "already claimed is not claimable")
end

return tests
