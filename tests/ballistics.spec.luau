-- Spread model tests. Run with: lune run tests/run
local Ballistics = require("../src/shared/Ballistics")

local tests = {}

local GUNS = { "AssaultRifle", "SMG", "Pistol", "Shotgun", "Minigun" }

function tests.every_configured_gun_has_a_weapon_profile()
	for _, id in GUNS do
		local w = Ballistics.weapon(id)
		assert(w.baseSpreadDeg > 0, id .. " has a resting cone")
		assert(w.maxSpreadDeg > w.baseSpreadDeg, id .. " can bloom above its resting cone")
		assert(w.adsMult < 1, id .. " rewards aiming")
		assert(w.sprintMult > w.moveMult, id .. " punishes sprinting more than walking")
	end
end

function tests.unknown_weapon_falls_back_instead_of_erroring()
	assert(Ballistics.spread("Banana") > 0)
end

function tests.spread_grows_monotonically_with_shots_and_clamps()
	for _, id in GUNS do
		local w = Ballistics.weapon(id)
		local prev = -1
		for shots = 0, 60 do
			local deg = Ballistics.spread(id, { shotsInBurst = shots })
			assert(deg >= prev, id .. " spread never shrinks as the burst continues")
			assert(deg <= w.maxSpreadDeg + 1e-9, id .. " spread respects maxSpreadDeg")
			prev = deg
		end
		assert(prev == w.maxSpreadDeg, id .. " reaches its ceiling on a long burst")
	end
end

function tests.negative_shot_count_is_treated_as_rest()
	assert(Ballistics.spread("SMG", { shotsInBurst = -5 }) == Ballistics.spread("SMG", { shotsInBurst = 0 }))
end

function tests.ads_tightens_and_movement_widens()
	for _, id in GUNS do
		local rest = Ballistics.spread(id, {})
		assert(Ballistics.spread(id, { ads = true }) < rest, id .. ": ADS tightens")
		assert(Ballistics.spread(id, { moving = true }) > rest, id .. ": walking widens")
		assert(Ballistics.spread(id, { sprinting = true }) > Ballistics.spread(id, { moving = true }))
		assert(Ballistics.spread(id, { airborne = true }) > rest, id .. ": jumping widens")
	end
end

function tests.ads_still_helps_while_moving()
	local moving = Ballistics.spread("AssaultRifle", { moving = true })
	local movingAds = Ballistics.spread("AssaultRifle", { moving = true, ads = true })
	assert(movingAds < moving)
end

function tests.airborne_supersedes_sprint_and_walk()
	-- A player can be flagged as all three at once; the widest single stance should win
	-- rather than the multipliers stacking into an absurd cone.
	local both = Ballistics.spread("SMG", { airborne = true, sprinting = true, moving = true })
	local air = Ballistics.spread("SMG", { airborne = true })
	assert(math.abs(both - air) < 1e-9)
end

function tests.decay_is_monotonic_and_floors_at_zero()
	for _, id in GUNS do
		local shots = Ballistics.maxShots(id)
		for _ = 1, 400 do
			local next_ = Ballistics.decayShots(shots, id, 1 / 60)
			assert(next_ <= shots, id .. ": decay never adds bloom")
			assert(next_ >= 0, id .. ": bloom never goes negative")
			shots = next_
		end
		assert(shots == 0, id .. ": bloom fully recovers when you stop firing")
	end
end

function tests.decayed_bloom_returns_spread_to_rest()
	local id = "AssaultRifle"
	local rest = Ballistics.spread(id, { shotsInBurst = 0 })
	local shots = Ballistics.decayShots(Ballistics.maxShots(id), id, 10)
	assert(math.abs(Ballistics.spread(id, { shotsInBurst = shots }) - rest) < 1e-9)
end

function tests.decay_ignores_negative_dt()
	assert(Ballistics.decayShots(5, "SMG", -10) == 5)
end

function tests.max_shots_reaches_exactly_the_ceiling()
	for _, id in GUNS do
		local w = Ballistics.weapon(id)
		local deg = Ballistics.spread(id, { shotsInBurst = Ballistics.maxShots(id) })
		assert(math.abs(deg - w.maxSpreadDeg) < 1e-9, id .. ": maxShots saturates the cone")
	end
end

function tests.zero_spread_produces_exactly_no_offset()
	for r1 = 0, 1, 0.25 do
		for r2 = 0, 1, 0.25 do
			local o = Ballistics.coneOffset(0, r1, r2)
			assert(o.yawDeg == 0 and o.pitchDeg == 0, "a zero cone is perfectly accurate")
		end
	end
end

function tests.cone_offset_never_escapes_the_cone()
	local spread = 4.0
	for i = 0, 40 do
		for j = 0, 40 do
			local o = Ballistics.coneOffset(spread, i / 40, j / 40)
			local mag = math.sqrt(o.yawDeg ^ 2 + o.pitchDeg ^ 2)
			assert(mag <= spread + 1e-9, "offset magnitude stays inside the cone")
		end
	end
end

function tests.cone_offset_clamps_out_of_range_randoms()
	local o = Ballistics.coneOffset(3, 99, 0.5)
	local mag = math.sqrt(o.yawDeg ^ 2 + o.pitchDeg ^ 2)
	assert(mag <= 3 + 1e-9)
end

function tests.cone_offset_spans_the_disc()
	-- r1 drives radius, r2 drives angle: the two randoms must not be redundant.
	local inner = Ballistics.coneOffset(5, 0.05, 0.3)
	local outer = Ballistics.coneOffset(5, 1, 0.3)
	local innerMag = math.sqrt(inner.yawDeg ^ 2 + inner.pitchDeg ^ 2)
	local outerMag = math.sqrt(outer.yawDeg ^ 2 + outer.pitchDeg ^ 2)
	assert(outerMag > innerMag, "r1 controls how far from centre the shot lands")

	local a = Ballistics.coneOffset(5, 1, 0)
	local b = Ballistics.coneOffset(5, 1, 0.25)
	assert(math.abs(a.yawDeg - b.yawDeg) > 1e-6, "r2 controls the direction around the disc")
end

function tests.crosshair_gap_is_zero_at_zero_spread_and_monotonic()
	assert(Ballistics.crosshairGap(0, 70, 1080) == 0)
	local prev = -1
	for deg = 0, 10, 0.5 do
		local gap = Ballistics.crosshairGap(deg, 70, 1080)
		assert(gap >= prev, "a wider cone never draws a tighter crosshair")
		prev = gap
	end
end

function tests.crosshair_gap_survives_degenerate_viewports()
	assert(Ballistics.crosshairGap(3, 70, 0) == 0)
	assert(Ballistics.crosshairGap(3, 0, 1080) > 0, "an absurd FOV must not divide by zero")
end

function tests.zooming_in_widens_the_on_screen_gap()
	-- Same cone, narrower FOV => the cone covers more of the screen.
	local wide = Ballistics.crosshairGap(3, 90, 1080)
	local zoomed = Ballistics.crosshairGap(3, 45, 1080)
	assert(zoomed > wide)
end

function tests.safe_up_axis_avoids_the_degenerate_lookat()
	-- Straight up / straight down must switch axis or CFrame.lookAt produces NaN.
	assert(Ballistics.safeUpAxis(1) == "Z")
	assert(Ballistics.safeUpAxis(-1) == "Z")
	assert(Ballistics.safeUpAxis(0) == "Y")
	assert(Ballistics.safeUpAxis(0.9) == "Y")
end

return tests
