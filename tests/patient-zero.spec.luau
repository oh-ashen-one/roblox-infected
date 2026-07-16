-- Patient Zero weighted selection tests. Run with: lune run tests/run
local PatientZero = require("../src/shared/PatientZero")

local tests = {}

function tests.recent_pz_gets_low_weight()
	assert(PatientZero.weightFor(0, 3) == 1)
	assert(PatientZero.weightFor(3, 3) == 1)
	assert(PatientZero.weightFor(4, 3) == 10)
	assert(PatientZero.weightFor(nil, 3) == 10)
end

function tests.selects_deterministically_with_fixed_rng()
	local candidates = {
		{ userId = 1 }, -- weight 10, cumulative 10
		{ userId = 2, roundsSincePZ = 1 }, -- weight 1, cumulative 11
		{ userId = 3 }, -- weight 10, cumulative 21
	}
	-- roll = rng * 21
	assert(PatientZero.select(candidates, 3, function()
		return 0
	end) == 1)
	assert(PatientZero.select(candidates, 3, function()
		return 10.5 / 21
	end) == 2)
	assert(PatientZero.select(candidates, 3, function()
		return 20 / 21
	end) == 3)
end

function tests.rng_edge_of_one_still_selects()
	local candidates = { { userId = 7 }, { userId = 8 } }
	local picked = PatientZero.select(candidates, 3, function()
		return 1 -- roll == total; must not fall through
	end)
	assert(picked == 8, "edge roll should pick last candidate")
end

function tests.single_candidate_always_picked()
	assert(PatientZero.select({ { userId = 42, roundsSincePZ = 0 } }, 3, function()
		return 0.99
	end) == 42)
end

function tests.recent_pz_rarely_repeats_statistically()
	-- 1 recent PZ among 10 players: expected pick rate = 1/91 ≈ 1.1%
	local candidates = {}
	for i = 1, 9 do
		table.insert(candidates, { userId = i })
	end
	table.insert(candidates, { userId = 10, roundsSincePZ = 0 })
	local seed = 12345
	local function lcg(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local repeats = 0
	for _ = 1, 2000 do
		if PatientZero.select(candidates, 3, lcg) == 10 then
			repeats += 1
		end
	end
	assert(repeats < 2000 * 0.05, "recent PZ picked too often: " .. repeats)
end

return tests
