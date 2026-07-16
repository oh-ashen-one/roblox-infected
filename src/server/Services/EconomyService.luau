--!strict
-- Awards coins/XP for round events, applies win bonuses and gamepass multipliers,
-- owns the shop actions (crates, equipping skins). All grants are server-side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Rewards = require(Shared.Rewards)
local SkinCatalog = require(Shared.SkinCatalog)
local CrateRoll = require(Shared.CrateRoll)

local EconomyService = {}
EconomyService.__index = EconomyService

export type Deps = {
	remotes: any,
	dataService: any,
}

local rng = Random.new()

function EconomyService.new(deps: Deps)
	local self = setmetatable({}, EconomyService)
	self._deps = deps
	self._firstBloodClaimed = false
	self._roundEarnings = {} :: { [Player]: number } -- for reveal-screen MVP stats
	self._gamepassCache = {} :: { [Player]: { [number]: boolean } }
	Players.PlayerRemoving:Connect(function(player)
		self._roundEarnings[player] = nil
		self._gamepassCache[player] = nil
	end)
	return self
end

function EconomyService:_ownsGamePass(player: Player, passId: number): boolean
	if passId == 0 then
		return false -- not created yet
	end
	local cache = self._gamepassCache[player]
	if cache == nil then
		cache = {}
		self._gamepassCache[player] = cache
	end
	if cache[passId] == nil then
		local ok, owns =
			pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
		cache[passId] = ok and owns or false
	end
	return cache[passId] :: boolean
end

function EconomyService:resetRound()
	self._firstBloodClaimed = false
	table.clear(self._roundEarnings)
end

function EconomyService:award(player: Player, event: string, won: boolean)
	local data = self._deps.dataService:get(player)
	if data == nil then
		return
	end
	local playerCount = #Players:GetPlayers()
	local amount = Rewards.payout(GameConfig.Rewards :: any, event :: any, {
		won = won,
		playerCount = playerCount,
		minPlayers = GameConfig.Round.MinPlayersToStart,
		fullRewardCount = GameConfig.Round.FullRewardPlayerCount,
	})
	local coins = amount
	local xp = amount
	if self:_ownsGamePass(player, GameConfig.Products.GamePasses.DoubleCoins) then
		coins *= 2
	end
	if self:_ownsGamePass(player, GameConfig.Products.GamePasses.XPBoost) then
		xp = math.floor(xp * 1.5)
	end
	data.coins += coins
	data.xp += xp
	self._roundEarnings[player] = (self._roundEarnings[player] or 0) + coins
	self._deps.dataService:sync(player)
end

-- Round-event helpers (called from the service wiring) ---------------------------

function EconomyService:onConversion(killer: Player?)
	if killer == nil then
		return
	end
	if not self._firstBloodClaimed then
		self._firstBloodClaimed = true
		local data = self._deps.dataService:get(killer)
		if data then
			data.stats.firstBloods += 1
		end
		self:award(killer, "FirstBlood", false)
	end
	local data = self._deps.dataService:get(killer)
	if data then
		data.stats.conversions += 1
	end
	self:award(killer, "Conversion", false)
end

function EconomyService:onZombieKilled(shooter: Player)
	local data = self._deps.dataService:get(shooter)
	if data then
		data.stats.kills += 1
	end
	self:award(shooter, "ZombieKill", false)
end

function EconomyService:onRoundEnd(winner: string, survivors: { Player }, everyone: { Player })
	for _, player in everyone do
		local data = self._deps.dataService:get(player)
		if data then
			data.stats.rounds += 1
		end
	end
	local survivorsWon = winner == "SURVIVORS"
	for _, survivor in survivors do
		self:award(survivor, "SurvivedRound", survivorsWon)
		local data = self._deps.dataService:get(survivor)
		if data and survivorsWon then
			data.stats.wins += 1
		end
	end
	if #survivors == 1 then
		self:award(survivors[1], "LastSurvivor", survivorsWon)
		local data = self._deps.dataService:get(survivors[1])
		if data then
			data.stats.lastSurvivor += 1
		end
	end
	for _, player in everyone do
		self._deps.dataService:sync(player)
	end
end

function EconomyService:roundEarnings(): { [Player]: number }
	return self._roundEarnings
end

-- Shop ----------------------------------------------------------------------------

function EconomyService:openCrate(player: Player, viaRobux: boolean): boolean
	local data = self._deps.dataService:get(player)
	if data == nil then
		return false
	end
	if not viaRobux then
		if data.coins < GameConfig.Economy.CrateCostCoins then
			return false
		end
		data.coins -= GameConfig.Economy.CrateCostCoins
	end
	local winnerId, decoys = CrateRoll.open(
		SkinCatalog :: any,
		GameConfig.Economy.Rarities :: any,
		3,
		function()
			return rng:NextNumber()
		end
	)
	local duplicate = data.ownedSkins[winnerId] == true
	if duplicate then
		-- Duplicate converts to coins (30% of crate cost)
		data.coins += math.floor(GameConfig.Economy.CrateCostCoins * 0.3)
	else
		data.ownedSkins[winnerId] = true
	end
	self._deps.remotes.fireClient("CrateResult", player, {
		winner = winnerId,
		decoys = decoys,
		duplicate = duplicate,
	})
	self._deps.dataService:sync(player)
	return true
end

function EconomyService:equipSkin(player: Player, skinId: string)
	local data = self._deps.dataService:get(player)
	if data == nil or data.ownedSkins[skinId] ~= true then
		return
	end
	for _, skin in SkinCatalog do
		if skin.id == skinId then
			data.equipped[skin.slot] = skinId
			self._deps.dataService:sync(player)
			return
		end
	end
end

function EconomyService:setLoadout(player: Player, primary: string)
	local data = self._deps.dataService:get(player)
	if data then
		data.loadout.primary = primary
		self._deps.dataService:sync(player)
	end
end

function EconomyService:start()
	local remotes = self._deps.remotes
	remotes.onValidated("BuyCrate", function(player, _payload)
		self:openCrate(player, false)
	end)
	remotes.onValidated("EquipSkin", function(player, payload)
		self:equipSkin(player, payload.skinId)
	end)
	remotes.onValidated("SelectLoadout", function(player, payload)
		self:setLoadout(player, payload.primary)
	end)
end

return EconomyService
