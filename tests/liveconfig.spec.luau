-- LiveConfig apply/validation tests. Run with: lune run tests/run
local LiveConfig = require("../src/shared/LiveConfig")

local WL = {
	["Round.IntermissionSeconds"] = { min = 5, max = 120 },
	["Bots.TargetPlayers"] = { min = 1, max = 15 },
}

local function freshConfig()
	return { Round = { IntermissionSeconds = 25 }, Bots = { TargetPlayers = 8 } }
end

local tests = {}

function tests.applies_valid_override()
	local cfg = freshConfig()
	local r = LiveConfig.apply(cfg, { ["Round.IntermissionSeconds"] = 40 }, WL)
	assert(cfg.Round.IntermissionSeconds == 40)
	assert(r.applied["Round.IntermissionSeconds"] == 40)
end

function tests.rejects_non_whitelisted()
	local cfg = freshConfig()
	local r = LiveConfig.apply(cfg, { ["Round.SecretHack"] = 999 }, WL)
	assert(r.rejected["Round.SecretHack"] == "not whitelisted")
end

function tests.rejects_out_of_range()
	local cfg = freshConfig()
	local r = LiveConfig.apply(cfg, { ["Bots.TargetPlayers"] = 99 }, WL)
	assert(cfg.Bots.TargetPlayers == 8, "unchanged")
	assert(r.rejected["Bots.TargetPlayers"] ~= nil)
end

function tests.rejects_wrong_type()
	local cfg = freshConfig()
	local r = LiveConfig.apply(cfg, { ["Bots.TargetPlayers"] = "lots" }, WL)
	assert(cfg.Bots.TargetPlayers == 8)
	assert(r.rejected["Bots.TargetPlayers"] == "not a number")
end

function tests.rejects_nan()
	local cfg = freshConfig()
	local r = LiveConfig.apply(cfg, { ["Bots.TargetPlayers"] = 0 / 0 }, WL)
	assert(cfg.Bots.TargetPlayers == 8)
	assert(r.rejected["Bots.TargetPlayers"] == "NaN")
end

function tests.boundaries_are_inclusive()
	local cfg = freshConfig()
	LiveConfig.apply(cfg, { ["Round.IntermissionSeconds"] = 5 }, WL)
	assert(cfg.Round.IntermissionSeconds == 5)
	LiveConfig.apply(cfg, { ["Round.IntermissionSeconds"] = 120 }, WL)
	assert(cfg.Round.IntermissionSeconds == 120)
end

function tests.mixed_batch_applies_good_rejects_bad()
	local cfg = freshConfig()
	local r = LiveConfig.apply(cfg, {
		["Round.IntermissionSeconds"] = 30,
		["Bots.TargetPlayers"] = -1,
	}, WL)
	assert(cfg.Round.IntermissionSeconds == 30)
	assert(cfg.Bots.TargetPlayers == 8)
	assert(r.applied["Round.IntermissionSeconds"] == 30)
	assert(r.rejected["Bots.TargetPlayers"] ~= nil)
end

local function configWithMods()
	return {
		Round = { IntermissionSeconds = 25 },
		RoundModifiers = {
			{ id = "normal", weight = 10 },
			{ id = "blackout", weight = 3 },
		},
	}
end

function tests.modifier_weight_override_disables_event()
	local cfg = configWithMods()
	local r = LiveConfig.apply(cfg, { ["Modifier.blackout.weight"] = 0 }, WL)
	assert(cfg.RoundModifiers[2].weight == 0, "blackout disabled")
	assert(r.applied["Modifier.blackout.weight"] == 0)
end

function tests.modifier_weight_reweights_event()
	local cfg = configWithMods()
	LiveConfig.apply(cfg, { ["Modifier.normal.weight"] = 2 }, WL)
	assert(cfg.RoundModifiers[1].weight == 2)
end

function tests.unknown_modifier_rejected()
	local cfg = configWithMods()
	local r = LiveConfig.apply(cfg, { ["Modifier.doesnotexist.weight"] = 5 }, WL)
	assert(r.rejected["Modifier.doesnotexist.weight"] == "unknown modifier")
end

function tests.modifier_weight_out_of_range_rejected()
	local cfg = configWithMods()
	local r = LiveConfig.apply(cfg, { ["Modifier.blackout.weight"] = 999 }, WL)
	assert(cfg.RoundModifiers[2].weight == 3, "unchanged")
	assert(r.rejected["Modifier.blackout.weight"] ~= nil)
end

return tests
