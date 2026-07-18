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

return tests
