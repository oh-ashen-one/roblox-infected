-- Anti-cheat movement classifier tests. Run with: lune run tests/run
local AntiCheatMath = require("../src/shared/AntiCheatMath")

local tests = {}

-- Config mirrors GameConfig.Movement: maxSpeed ~= 44.88, teleport 80, interval 1.
local MAX = 24 * 1.2 * 1.35 + 6
local TELE = 80

function tests.normal_walking_is_ok()
	assert(AntiCheatMath.classify(16, 1, MAX, TELE) == "ok")
	assert(AntiCheatMath.classify(24, 1, MAX, TELE) == "ok", "sprint is fine")
	assert(AntiCheatMath.classify(MAX, 1, MAX, TELE) == "ok", "exactly at the limit is ok")
end

function tests.moderate_speed_hack_is_caught()
	-- The old max(speedLimit, teleport) logic let this slip because 60 < 80.
	assert(AntiCheatMath.classify(60, 1, MAX, TELE) == "speed", "1.3x hack between limit and teleport")
end

function tests.hard_teleport_is_classified_teleport()
	assert(AntiCheatMath.classify(200, 1, MAX, TELE) == "teleport")
	assert(AntiCheatMath.classify(TELE + 0.1, 1, MAX, TELE) == "teleport")
end

function tests.interval_scales_the_speed_limit()
	-- Over a 2s window twice the distance is legit.
	assert(AntiCheatMath.classify(MAX * 2 - 1, 2, MAX, TELE) == "ok")
	assert(AntiCheatMath.classify(MAX * 2 + 1, 2, MAX, TELE) == "speed")
end

function tests.teleport_budget_scales_with_window()
	-- Over a 5s window, 85 studs is a legit ~17 studs/s, so it must NOT be a teleport.
	assert(AntiCheatMath.classify(TELE + 5, 5, MAX, TELE) == "ok")
	-- But a genuine blink past the scaled budget is caught.
	assert(AntiCheatMath.classify(TELE * 5 + 1, 5, MAX, TELE) == "teleport")
end

return tests
