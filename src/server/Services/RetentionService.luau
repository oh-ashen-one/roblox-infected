--!strict
-- Retention loops: daily login-streak rewards (Phase C). Owns the server side of the
-- daily reward — evaluates streak state on join, grants on claim, and pushes status to
-- the client. Quests/season live in their own slices but will hang off this service.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyReward = require(Shared.DailyReward)

local RetentionService = {}
RetentionService.__index = RetentionService

export type Deps = {
	remotes: any,
	dataService: any,
	-- Injectable clock so tests / Studio can control "today"; defaults to os.time.
	now: (() -> number)?,
}

function RetentionService.new(deps: Deps)
	local self = setmetatable({}, RetentionService)
	self._deps = deps
	self._now = deps.now or os.time
	return self
end

function RetentionService:_today(): number
	return DailyReward.dayNumber(self._now())
end

-- Push the player's current daily status (claimable? which reward? streak?) to the client.
function RetentionService:pushStatus(player: Player)
	local data = self._deps.dataService:get(player)
	if data == nil then
		return
	end
	local result = DailyReward.evaluate(data.daily, self:_today())
	self._deps.remotes.fireClient("DailyStatus", player, {
		claimable = result.claimable,
		streak = result.claimable and result.streak or data.daily.streak,
		reward = result.reward,
	})
end

function RetentionService:claim(player: Player)
	local data = self._deps.dataService:get(player)
	if data == nil then
		return
	end
	local result = DailyReward.evaluate(data.daily, self:_today())
	if not result.claimable or result.reward == nil then
		self:pushStatus(player) -- resend so the client UI reflects reality
		return
	end
	local reward = result.reward
	data.daily.streak = result.streak
	data.daily.lastClaimDay = self:_today()
	data.coins += reward.coins
	data.xp += reward.xp
	data.crateKeys += reward.keys
	self._deps.dataService:sync(player)
	self._deps.remotes.fireClient("DailyClaimed", player, {
		streak = result.streak,
		reward = reward,
	})
	self:pushStatus(player)
end

-- Called by DataService once a player's profile is ready.
function RetentionService:onPlayerReady(player: Player)
	self:pushStatus(player)
end

function RetentionService:start()
	self._deps.remotes.onValidated("ClaimDaily", function(player)
		self:claim(player)
	end)
	-- Any players already in (Studio start / hot reload) get their status pushed.
	for _, player in Players:GetPlayers() do
		if self._deps.dataService:get(player) ~= nil then
			self:pushStatus(player)
		end
	end
end

return RetentionService
