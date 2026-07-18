-- Titles unlock logic tests. Run with: lune run tests/run
local Titles = require("../src/shared/Titles")

local tests = {}

function tests.get_by_id()
	assert(Titles.get("rookie").text == "Rookie")
	assert(Titles.get("nope") == nil)
end

function tests.rookie_unlocked_from_level_one()
	local u = Titles.unlockedAt(1)
	assert(#u == 1 and u[1].id == "rookie")
end

function tests.higher_levels_unlock_more()
	assert(#Titles.unlockedAt(10) > #Titles.unlockedAt(5))
	local u = Titles.unlockedAt(50)
	local hasApex = false
	for _, t in u do
		if t.id == "apex" then
			hasApex = true
		end
	end
	assert(hasApex, "apex unlocked at 50")
end

function tests.top_title_needs_high_level()
	local at74 = Titles.unlockedAt(74)
	for _, t in at74 do
		assert(t.id ~= "undying", "undying not unlocked before 75")
	end
	assert(#Titles.unlockedAt(75) == #Titles.All, "all titles unlocked at 75")
end

return tests
