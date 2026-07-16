-- Round state machine transition tests. Run with: lune run tests/run
local RoundMachine = require("../src/shared/RoundMachine")

local CONFIG = {
	MinPlayersToStart = 4,
	IntermissionSeconds = 25,
	BaseRoundSeconds = 300,
	SecondsPerConversion = 20,
	MaxRoundSeconds = 480,
	RevealSeconds = 10,
}

local tests = {}

local function effectTypes(effects)
	local out = {}
	for _, e in effects do
		table.insert(out, e.type)
	end
	return table.concat(out, ",")
end

function tests.starts_waiting()
	local m = RoundMachine.new(CONFIG)
	assert(m.state == "WAITING", "should start WAITING")
end

function tests.waits_below_min_players()
	local m = RoundMachine.new(CONFIG)
	local fx = m:setPlayerCount(3, 0)
	assert(#fx == 0, "no effects below min players")
	assert(m.state == "WAITING")
end

function tests.enters_intermission_at_min_players()
	local m = RoundMachine.new(CONFIG)
	local fx = m:setPlayerCount(4, 100)
	assert(effectTypes(fx) == "StartIntermission", effectTypes(fx))
	assert(m.state == "INTERMISSION")
	assert(m.deadline == 125, "deadline should be now + 25")
end

function tests.returns_to_waiting_if_players_leave_intermission()
	local m = RoundMachine.new(CONFIG)
	m:setPlayerCount(4, 0)
	local fx = m:setPlayerCount(3, 5)
	assert(effectTypes(fx) == "ReturnToWaiting", effectTypes(fx))
	assert(m.state == "WAITING" and m.deadline == nil)
end

function tests.starts_round_when_intermission_expires()
	local m = RoundMachine.new(CONFIG)
	m:setPlayerCount(6, 0)
	assert(#m:tick(24) == 0, "no transition before deadline")
	local fx = m:tick(25)
	assert(effectTypes(fx) == "StartRound", effectTypes(fx))
	assert(m.state == "ACTIVE")
	assert(m.deadline == 325, "round deadline = start + 300")
	assert(m.survivorCount == 5, "everyone but Patient Zero starts as a survivor")
end

function tests.conversion_extends_deadline_capped()
	local m = RoundMachine.new(CONFIG)
	m:setPlayerCount(6, 0)
	m:tick(25) -- round starts at t=25, deadline 325, cap = 25+480 = 505
	local fx = m:recordConversion(30)
	assert(effectTypes(fx) == "ExtendRound")
	assert(m.deadline == 345, "one conversion adds 20s")
	for _ = 1, 20 do
		m:recordConversion(31)
	end
	assert(m.deadline == 505, "deadline must cap at start + MaxRoundSeconds, got " .. tostring(m.deadline))
end

function tests.conversion_ignored_outside_active()
	local m = RoundMachine.new(CONFIG)
	assert(#m:recordConversion(0) == 0)
	m:setPlayerCount(5, 0)
	assert(#m:recordConversion(1) == 0, "no conversions during intermission")
end

function tests.survivors_win_on_timer()
	local m = RoundMachine.new(CONFIG)
	m:setPlayerCount(5, 0)
	m:tick(25)
	m:setSurvivorCount(2, 100)
	local fx = m:tick(325)
	assert(#fx == 1 and fx[1].type == "EndRound" and fx[1].winner == "SURVIVORS", effectTypes(fx))
	assert(m.state == "ROUND_END")
end

function tests.infected_win_on_full_conversion()
	local m = RoundMachine.new(CONFIG)
	m:setPlayerCount(5, 0)
	m:tick(25)
	local fx = m:setSurvivorCount(0, 60)
	assert(#fx == 1 and fx[1].type == "EndRound" and fx[1].winner == "INFECTED", effectTypes(fx))
	assert(m.state == "ROUND_END")
end

function tests.round_end_flows_back_to_intermission()
	local m = RoundMachine.new(CONFIG)
	m:setPlayerCount(5, 0)
	m:tick(25)
	m:setSurvivorCount(0, 60) -- ends at 60, reveal until 70
	assert(#m:tick(69) == 0)
	local fx = m:tick(70)
	assert(effectTypes(fx):find("StartIntermission") ~= nil, effectTypes(fx))
	assert(m.state == "INTERMISSION")
end

function tests.round_end_goes_to_waiting_if_lobby_emptied()
	local m = RoundMachine.new(CONFIG)
	m:setPlayerCount(5, 0)
	m:tick(25)
	m:setSurvivorCount(0, 60)
	m:setPlayerCount(2, 61)
	local fx = m:tick(70)
	assert(effectTypes(fx) == "ReturnToWaiting", effectTypes(fx))
	assert(m.state == "WAITING")
end

function tests.active_round_survives_player_leaving()
	local m = RoundMachine.new(CONFIG)
	m:setPlayerCount(5, 0)
	m:tick(25)
	local fx = m:setPlayerCount(2, 50) -- below min, but round already active
	assert(#fx == 0, "active round continues below min players")
	assert(m.state == "ACTIVE")
end

function tests.force_end_only_when_active()
	local m = RoundMachine.new(CONFIG)
	assert(#m:forceEnd("SURVIVORS", 0) == 0, "no force end while waiting")
	m:setPlayerCount(5, 0)
	assert(#m:forceEnd("SURVIVORS", 1) == 0, "no force end during intermission")
	m:tick(25)
	local fx = m:forceEnd("SURVIVORS", 30)
	assert(#fx == 1 and fx[1].type == "EndRound" and fx[1].winner == "SURVIVORS")
	assert(m.state == "ROUND_END")
	assert(#m:forceEnd("INFECTED", 31) == 0, "cannot force end twice")
end

return tests
