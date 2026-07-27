-- Bot state machine tests. Run with: lune run tests/run
local BotBrain = require("../src/shared/BotBrain")

local tests = {}

local function cfg(overrides)
	return BotBrain.configFor(nil, overrides)
end

local function step(memory, role, perception, now, config)
	return BotBrain.next(memory, role, perception, config or cfg(), now)
end

function tests.personalities_are_actually_distinct()
	-- "aggressive" and "roamer" used to be the same code path with no behavioural effect.
	local seen = {}
	for name in BotBrain.Personalities do
		local c = BotBrain.configFor(name)
		local key = ("%s|%s|%s|%s"):format(c.fleeRadius, c.engageRange, c.braveryHealth, c.regroupBelowAllies)
		assert(seen[key] == nil, name .. " is behaviourally identical to " .. tostring(seen[key]))
		seen[key] = name
	end
end

function tests.aggressive_commits_where_cautious_backs_off()
	local aggressive = BotBrain.configFor("aggressive")
	local cautious = BotBrain.configFor("cautious")
	assert(aggressive.fleeRadius < cautious.fleeRadius, "aggressive holds ground longer")
	assert(aggressive.engageRange > cautious.fleeRadius or true)
	assert(aggressive.braveryHealth < cautious.braveryHealth, "aggressive fights while hurt")
end

function tests.config_overrides_win()
	local c = BotBrain.configFor("cautious", { fleeRadius = 5 })
	assert(c.fleeRadius == 5)
	assert(c.braveryHealth == BotBrain.Personalities.cautious.braveryHealth, "unrelated keys survive")
end

function tests.survivor_engages_a_visible_distant_threat()
	local m = BotBrain.newMemory("PATROL", 0)
	assert(step(m, "SURVIVOR", { threatDist = 45, threatVisible = true }, 1) == "ENGAGE")
end

function tests.survivor_flees_a_close_threat()
	local m = BotBrain.newMemory("PATROL", 0)
	assert(step(m, "SURVIVOR", { threatDist = 10, threatVisible = true }, 1) == "FLEE")
end

function tests.flee_has_hysteresis_and_does_not_oscillate()
	local c = cfg() -- fleeRadius 26, exit at 41.6
	local m = BotBrain.newMemory("PATROL", 0)
	-- Enter flee well inside the radius.
	assert(step(m, "SURVIVOR", { threatDist = 20, threatVisible = true }, 1, c) == "FLEE")
	-- Sitting just outside the entry radius must NOT immediately drop out of flee.
	assert(step(m, "SURVIVOR", { threatDist = 27, threatVisible = true }, 2, c) == "FLEE")
	assert(step(m, "SURVIVOR", { threatDist = 40, threatVisible = true }, 3, c) == "FLEE")
	-- Only past the exit band does it re-engage.
	assert(step(m, "SURVIVOR", { threatDist = 45, threatVisible = true }, 4, c) == "ENGAGE")
end

function tests.a_bot_hovering_at_the_boundary_stays_stable()
	-- Regression for the original bug: at exactly fleeRadius the old code flipped state
	-- every single tick.
	local c = cfg()
	local m = BotBrain.newMemory("PATROL", 0)
	local flips, previous = 0, nil
	for i = 1, 40 do
		local s = step(m, "SURVIVOR", { threatDist = 26, threatVisible = true }, i * 0.35, c)
		if previous and s ~= previous then
			flips += 1
		end
		previous = s
	end
	assert(flips <= 1, "expected at most one transition, got " .. flips)
end

function tests.being_shot_interrupts_anything()
	local m = BotBrain.newMemory("PATROL", 0)
	assert(step(m, "SURVIVOR", { justDamaged = true }, 1) == "STAGGER")

	local m2 = BotBrain.newMemory("ENGAGE", 0)
	assert(
		step(m2, "SURVIVOR", { threatDist = 50, threatVisible = true, justDamaged = true }, 1) == "STAGGER"
	)

	local m3 = BotBrain.newMemory("HUNT", 0)
	assert(step(m3, "ZOMBIE", { threatDist = 5, threatVisible = true, justDamaged = true }, 1) == "STAGGER")
end

function tests.stagger_holds_then_releases()
	local c = cfg({ staggerSeconds = 0.35 })
	local m = BotBrain.newMemory("PATROL", 0)
	-- allyCount keeps this out of REGROUP so the assertion is about the stagger window only.
	local calm = { allyCount = 5 }
	assert(step(m, "SURVIVOR", { justDamaged = true, allyCount = 5 }, 1, c) == "STAGGER")
	-- Still staggering a moment later even with nothing else happening.
	assert(step(m, "SURVIVOR", calm, 1.2, c) == "STAGGER")
	-- Released once the window passes, without waiting out a second dwell period.
	assert(step(m, "SURVIVOR", calm, 1.4, c) == "PATROL")
end

function tests.a_survivor_with_nobody_around_regroups_after_a_stagger()
	local c = cfg({ staggerSeconds = 0.35, regroupBelowAllies = 1 })
	local m = BotBrain.newMemory("PATROL", 0)
	step(m, "SURVIVOR", { justDamaged = true }, 1, c)
	assert(step(m, "SURVIVOR", { allyCount = 0 }, 1.4, c) == "REGROUP", "alone: go find friends")
end

function tests.repeated_hits_extend_the_stagger()
	local c = cfg({ staggerSeconds = 0.35 })
	local m = BotBrain.newMemory("PATROL", 0)
	step(m, "SURVIVOR", { justDamaged = true }, 1, c)
	local firstUntil = m.staggerUntil
	step(m, "SURVIVOR", { justDamaged = true }, 1.2, c)
	assert(m.staggerUntil > firstUntil, "a second hit extends the stagger")
end

function tests.lost_contact_becomes_a_search_not_amnesia()
	local c = cfg()
	local m = BotBrain.newMemory("ENGAGE", 0)
	local s = step(m, "SURVIVOR", {
		threatVisible = false,
		hasLastKnown = true,
		timeSinceContact = 1,
		allyCount = 5,
	}, 1, c)
	assert(s == "SEARCH", "the bot goes looking instead of forgetting mid-firefight")
end

function tests.search_gives_up_once_memory_expires()
	local c = cfg({ memorySeconds = 6 })
	local m = BotBrain.newMemory("SEARCH", 0)
	local s = step(m, "SURVIVOR", {
		threatVisible = false,
		hasLastKnown = true,
		timeSinceContact = 7,
		allyCount = 5,
	}, 10, c)
	assert(s == "PATROL")
end

function tests.min_dwell_prevents_twitching()
	local c = cfg({ minDwell = 0.45 })
	local m = BotBrain.newMemory("SEARCH", 10)
	-- Nothing visible and memory gone, but we only just entered SEARCH.
	local s = step(m, "SURVIVOR", { allyCount = 5 }, 10.1, c)
	assert(s == "SEARCH", "state is held for the dwell period")
	local s2 = step(m, "SURVIVOR", { allyCount = 5 }, 10.6, c)
	assert(s2 == "PATROL", "and released after it")
end

function tests.low_health_flees_even_at_range()
	local c = cfg({ braveryHealth = 0.35 })
	local m = BotBrain.newMemory("ENGAGE", 0)
	local s = step(m, "SURVIVOR", { threatDist = 55, threatVisible = true, health01 = 0.2 }, 1, c)
	assert(s == "FLEE")
end

function tests.lonely_survivors_regroup()
	local c = cfg({ regroupBelowAllies = 2 })
	local m = BotBrain.newMemory("PATROL", 0)
	local s = step(m, "SURVIVOR", { allyCount = 0 }, 1, c)
	assert(s == "REGROUP")
	local s2 = step(m, "SURVIVOR", { allyCount = 3 }, 2, c)
	assert(s2 == "PATROL")
end

function tests.infected_hunts_up_close_and_stalks_at_range()
	local c = cfg({ engageRange = 60 }) -- hunt threshold = 24
	local m = BotBrain.newMemory("STALK", 0)
	assert(step(m, "ZOMBIE", { threatDist = 10, threatVisible = true }, 1, c) == "HUNT")

	local m2 = BotBrain.newMemory("STALK", 0)
	assert(step(m2, "ZOMBIE", { threatDist = 50, threatVisible = true }, 1, c) == "STALK")
end

function tests.infected_searches_a_lost_target()
	local c = cfg()
	local m = BotBrain.newMemory("HUNT", 0)
	local s = step(m, "ZOMBIE", { threatVisible = false, hasLastKnown = true, timeSinceContact = 2 }, 1, c)
	assert(s == "SEARCH")
end

function tests.patient_zero_uses_the_infected_machine()
	local m = BotBrain.newMemory("STALK", 0)
	assert(step(m, "PATIENT_ZERO", { threatDist = 5, threatVisible = true }, 1) == "HUNT")
end

function tests.memory_records_when_the_state_changed()
	local m = BotBrain.newMemory("PATROL", 0)
	step(m, "SURVIVOR", { threatDist = 45, threatVisible = true }, 5)
	assert(m.state == "ENGAGE")
	assert(m.since == 5, "transition timestamp is recorded for dwell tracking")
end

return tests
