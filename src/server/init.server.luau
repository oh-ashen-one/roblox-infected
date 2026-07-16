--!strict
-- Server bootstrap. Order matters: remotes first (clients WaitForChild on the folder),
-- then services, wired together here so each service stays decoupled.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)

local RoundService = require(script.Services.RoundService)
local RoleService = require(script.Services.RoleService)
local CombatService = require(script.Services.CombatService)
local AntiCheatService = require(script.Services.AntiCheatService)
local MapService = require(script.Services.MapService)
local DataService = require(script.Services.DataService)
local EconomyService = require(script.Services.EconomyService)
local MonetizationService = require(script.Services.MonetizationService)
local EndgameService = require(script.Services.EndgameService)

-- Fast timers in Studio so a full round loop plays out in under a minute of testing.
if game:GetService("RunService"):IsStudio() then
	GameConfig.Round.IntermissionSeconds = 8
	GameConfig.Round.BaseRoundSeconds = 40
	GameConfig.Round.MaxRoundSeconds = 90
	GameConfig.Round.RevealSeconds = 6
	GameConfig.Round.MinPlayersToStart = 2
	-- Solo play-test (run-in-roblox headless verification): let a 1-player round run
	task.delay(5, function()
		if #Players:GetPlayers() <= 1 then
			GameConfig.Round.MinPlayersToStart = 1
		end
	end)
end

local remotes = Remotes.server()

-- Forward declarations: service closures below reference these before assignment
local roundService
local roleService
local endgameService

local mapService = MapService.new({ remotes = remotes })
local dataService = DataService.new({ remotes = remotes })
local economyService = EconomyService.new({ remotes = remotes, dataService = dataService })
local monetizationService =
	MonetizationService.new({ dataService = dataService, economyService = economyService })

roleService = RoleService.new({
	remotes = remotes,
	getSurvivorSpawn = function()
		return mapService:randomSurvivorSpawn()
	end,
	getZombieSpawn = function(survivorRoots)
		return mapService:zombieSpawnNearAction(survivorRoots)
	end,
	getEquippedGunSkin = function(player: Player)
		local data = dataService:get(player)
		return data and data.equipped and data.equipped.Gun or nil
	end,
	onConversion = function(victim: Player, killer: Player?)
		roundService:recordConversion()
		economyService:onConversion(killer)
		remotes.fireAllClients("ConversionAlert", {
			victimName = victim.DisplayName,
			killerName = killer and killer.DisplayName or nil,
		})
	end,
	onSurvivorCountChanged = function(count: number)
		roundService:setSurvivorCount(count)
		endgameService:onSurvivorCountChanged(count)
	end,
	onPatientZeroGone = function()
		-- PZ left before creating any zombies: survivors win by default
		roundService:forceEnd("SURVIVORS")
	end,
})

endgameService = EndgameService.new({
	remotes = remotes,
	roleService = roleService,
	isRoundActive = function()
		return roundService ~= nil and roundService:getState() == "ACTIVE"
	end,
})

local combatService = CombatService.new({
	remotes = remotes,
	roleService = roleService,
	isRoundActive = function()
		return roundService:getState() == "ACTIVE"
	end,
	onZombieKilled = function(killer: Player, _victim: Player)
		economyService:onZombieKilled(killer)
	end,
	isLastStand = function(player: Player)
		return endgameService:isLastStand(player)
	end,
	getPrimary = function(player: Player)
		local data = dataService:get(player)
		return data and data.loadout.primary or "AssaultRifle"
	end,
})

local antiCheatService = AntiCheatService.new({
	remotes = remotes,
	combatService = combatService,
})

roundService = RoundService.new({
	remotes = remotes,
	onRoundStart = function(playersInRound)
		economyService:resetRound()
		combatService:resetRound()
		endgameService:resetRound()
		mapService:loadVotedMap()
		roleService:assignRoles(playersInRound)
	end,
	onRoundEnd = function(winner)
		local originalPZ = roleService:getOriginalPatientZero()
		local survivors = roleService:survivors()
		local survivorNames = {}
		for _, survivor in survivors do
			table.insert(survivorNames, survivor.DisplayName)
		end
		economyService:onRoundEnd(winner, survivors, Players:GetPlayers())
		local earnings = {}
		for player, coins in economyService:roundEarnings() do
			earnings[tostring(player.UserId)] = coins
		end
		remotes.fireAllClients("RevealScreen", {
			winner = winner,
			patientZeroName = originalPZ and originalPZ.name or "?",
			survivors = survivorNames,
			earnings = earnings,
		})
		roleService:endRound()
	end,
	onIntermission = function()
		mapService:unload()
		mapService:openVote()
	end,
})

dataService:start()
roleService:start()
roundService:start()
combatService:start()
antiCheatService:start()
mapService:start()
economyService:start()
monetizationService:start()
endgameService:start()

-- Studio-only smoke test: exercises the whole round loop with fast timers and
-- scripted deaths so a local multi-client playtest verifies itself in the Output.
if game:GetService("RunService"):IsStudio() then
	local SmokeTest = require(script.StudioSmokeTest)
	SmokeTest.run(roundService, roleService)
end

print("[INFECTED] Server booted")
