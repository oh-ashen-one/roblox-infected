-- Bot perception tests. Run with: lune run tests/run
local BotVision = require("../src/shared/BotVision")

local tests = {}

function tests.yaw_delta_handles_wraparound()
	assert(BotVision.yawDelta(0, 0) == 0)
	assert(BotVision.yawDelta(10, 350) == 20, "shortest way round the circle, not 340")
	assert(BotVision.yawDelta(350, 10) == 20)
	assert(BotVision.yawDelta(0, 180) == 180)
	assert(BotVision.yawDelta(-90, 90) == 180)
end

function tests.cone_boundary_is_half_the_width_each_side()
	assert(BotVision.inCone(0, 55, 110), "just inside a 110 degree cone")
	assert(BotVision.inCone(0, -55, 110))
	assert(not BotVision.inCone(0, 56, 110), "just outside")
	assert(BotVision.inCone(0, 0, 110), "dead ahead")
end

function tests.bots_can_now_be_flanked()
	-- The whole point: something directly behind is not visible.
	assert(not BotVision.inCone(0, 180, 110), "directly behind")
	assert(not BotVision.inCone(0, 120, 110))
end

function tests.can_see_requires_range_cone_and_line_of_sight()
	local facing, target = 0, 10
	assert(BotVision.canSee(50, facing, target, true, 80, 110))
	assert(not BotVision.canSee(90, facing, target, true, 80, 110), "out of range")
	assert(not BotVision.canSee(50, facing, target, false, 80, 110), "blocked by geometry")
	assert(not BotVision.canSee(50, facing, 170, true, 80, 110), "outside the cone")
end

function tests.point_blank_targets_bypass_the_cone()
	-- Someone standing on top of you is noticed even if they are behind.
	assert(BotVision.canSee(3, 0, 180, true, 80, 110, 8))
	-- ...but not through a wall.
	assert(not BotVision.canSee(3, 0, 180, false, 80, 110, 8))
	-- ...and not once they back off past the peripheral radius.
	assert(not BotVision.canSee(20, 0, 180, true, 80, 110, 8))
end

function tests.memory_expires_at_the_configured_horizon()
	assert(not BotVision.memoryExpired(0, 6))
	assert(not BotVision.memoryExpired(5.9, 6))
	assert(BotVision.memoryExpired(6, 6))
	assert(BotVision.memoryExpired(99, 6))
end

function tests.hearing_falls_off_with_distance_and_cuts_out_of_range()
	assert(BotVision.hearing(0, 90) == 1, "a shot at your feet is unmistakable")
	assert(BotVision.hearing(90, 90) == 0, "at the edge it is inaudible")
	assert(BotVision.hearing(120, 90) == 0, "beyond range is silent")
	local near, far = BotVision.hearing(10, 90), BotVision.hearing(70, 90)
	assert(near > far, "closer gunfire is louder")
	assert(far > 0)
end

function tests.hearing_rejects_nonsense_distance()
	assert(BotVision.hearing(-5, 90) == 0)
end

function tests.search_radius_grows_as_the_trail_goes_cold()
	local a = BotVision.searchRadius(0, 10, 4)
	local b = BotVision.searchRadius(3, 10, 4)
	assert(a == 10)
	assert(b == 22)
	assert(b > a, "a staler memory searches a wider area")
	assert(BotVision.searchRadius(-9, 10, 4) == 10, "negative age never shrinks the radius")
end

return tests
