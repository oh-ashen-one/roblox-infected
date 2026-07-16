--!strict
-- Pure round state machine. No Roblox APIs — time is passed in, side effects come out
-- as an effects list the service layer executes. This keeps the entire round flow
-- unit-testable outside Roblox (see tests/round-machine.spec.luau).

export type State = "WAITING" | "INTERMISSION" | "ACTIVE" | "ROUND_END"

export type Effect =
	{ type: "StartIntermission", endsAt: number }
	| { type: "StartRound", endsAt: number }
	| { type: "ExtendRound", endsAt: number, conversions: number }
	| { type: "EndRound", winner: "SURVIVORS" | "INFECTED" | "NOBODY", endsAt: number }
	| { type: "ReturnToIntermission" }
	| { type: "ReturnToWaiting" }

export type RoundConfig = {
	MinPlayersToStart: number,
	IntermissionSeconds: number,
	BaseRoundSeconds: number,
	SecondsPerConversion: number,
	MaxRoundSeconds: number,
	RevealSeconds: number,
}

export type RoundMachine = {
	state: State,
	deadline: number?, -- unix-ish clock supplied by caller
	roundStartedAt: number?,
	playerCount: number,
	survivorCount: number,
	conversions: number,

	setPlayerCount: (self: RoundMachine, n: number, now: number) -> { Effect },
	forceEnd: (self: RoundMachine, winner: "SURVIVORS" | "INFECTED" | "NOBODY", now: number) -> { Effect },
	setSurvivorCount: (self: RoundMachine, n: number, now: number) -> { Effect },
	recordConversion: (self: RoundMachine, now: number) -> { Effect },
	tick: (self: RoundMachine, now: number) -> { Effect },
}

local RoundMachine = {}
RoundMachine.__index = RoundMachine

local function new(config: RoundConfig): RoundMachine
	local self = setmetatable({
		config = config,
		state = "WAITING" :: State,
		deadline = nil :: number?,
		roundStartedAt = nil :: number?,
		playerCount = 0,
		survivorCount = 0,
		conversions = 0,
	}, RoundMachine)
	return (self :: any) :: RoundMachine
end

local function enterIntermission(self, now: number): Effect
	self.state = "INTERMISSION"
	self.deadline = now + self.config.IntermissionSeconds
	return { type = "StartIntermission", endsAt = self.deadline :: number }
end

local function enterRoundEnd(self, now: number, winner): Effect
	self.state = "ROUND_END"
	self.deadline = now + self.config.RevealSeconds
	return { type = "EndRound", winner = winner, endsAt = self.deadline :: number }
end

function RoundMachine.setPlayerCount(self, n: number, now: number): { Effect }
	self.playerCount = n
	local effects = {}
	if self.state == "WAITING" and n >= self.config.MinPlayersToStart then
		table.insert(effects, enterIntermission(self, now))
	elseif self.state == "INTERMISSION" and n < self.config.MinPlayersToStart then
		self.state = "WAITING"
		self.deadline = nil
		table.insert(effects, { type = "ReturnToWaiting" })
	end
	-- ACTIVE rounds continue even if players leave; survivor/infected counts decide the end.
	return effects
end

function RoundMachine.setSurvivorCount(self, n: number, now: number): { Effect }
	self.survivorCount = n
	local effects = {}
	if self.state == "ACTIVE" and n <= 0 then
		table.insert(effects, enterRoundEnd(self, now, "INFECTED"))
	end
	return effects
end

-- Immediate round end regardless of counts (e.g. Patient Zero left before first blood).
function RoundMachine.forceEnd(self, winner: "SURVIVORS" | "INFECTED" | "NOBODY", now: number): { Effect }
	if self.state ~= "ACTIVE" then
		return {}
	end
	return { enterRoundEnd(self, now, winner) }
end

function RoundMachine.recordConversion(self, _now: number): { Effect }
	if self.state ~= "ACTIVE" then
		return {}
	end
	self.conversions += 1
	local startedAt = self.roundStartedAt :: number
	local maxDeadline = startedAt + self.config.MaxRoundSeconds
	local extended = math.min((self.deadline :: number) + self.config.SecondsPerConversion, maxDeadline)
	self.deadline = extended
	return { { type = "ExtendRound", endsAt = extended, conversions = self.conversions } }
end

function RoundMachine.tick(self, now: number): { Effect }
	local deadline = self.deadline
	if deadline == nil or now < deadline then
		return {}
	end

	if self.state == "INTERMISSION" then
		if self.playerCount >= self.config.MinPlayersToStart then
			self.state = "ACTIVE"
			self.roundStartedAt = now
			self.conversions = 0
			self.survivorCount = self.playerCount
			self.deadline = now + self.config.BaseRoundSeconds
			return { { type = "StartRound", endsAt = self.deadline :: number } }
		else
			self.state = "WAITING"
			self.deadline = nil
			return { { type = "ReturnToWaiting" } }
		end
	elseif self.state == "ACTIVE" then
		-- Timer expired with survivors alive -> survivors win.
		local winner = if self.survivorCount > 0 then "SURVIVORS" else "INFECTED"
		return { enterRoundEnd(self, now, winner) }
	elseif self.state == "ROUND_END" then
		if self.playerCount >= self.config.MinPlayersToStart then
			return { enterIntermission(self, now), { type = "ReturnToIntermission" } }
		else
			self.state = "WAITING"
			self.deadline = nil
			return { { type = "ReturnToWaiting" } }
		end
	end
	return {}
end

return { new = new }
