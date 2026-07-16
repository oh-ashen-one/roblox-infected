--!strict
-- Server bootstrap. Order matters: remotes first (clients WaitForChild on the folder),
-- then services, wired together here so each service stays decoupled.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)

-- Fast timers in Studio so a full round loop plays out in under a minute of testing.
if game:GetService("RunService"):IsStudio() then
	GameConfig.Round.IntermissionSeconds = 8
	GameConfig.Round.BaseRoundSeconds = 40
	GameConfig.Round.MaxRoundSeconds = 90
	GameConfig.Round.RevealSeconds = 6
	GameConfig.Round.MinPlayersToStart = 2
end
local RoundService = require(script.Services.RoundService)
local RoleService = require(script.Services.RoleService)
local CombatService = require(script.Services.CombatService)
local AntiCheatService = require(script.Services.AntiCheatService)
local MapService = require(script.Services.MapService)

local remotes = Remotes.server()

local roundService
local roleService

local mapService = MapService.new({ remotes = remotes })

roleService = RoleService.new({
	getSurvivorSpawn = function()
		return mapService:randomSurvivorSpawn()
	end,
	getZombieSpawn = function(survivorRoots)
		return mapService:zombieSpawnNearAction(survivorRoots)
	end,
	remotes = remotes,
	onConversion = function(victim: Player, killer: Player?)
		roundService:recordConversion()
		remotes.fireAllClients("ConversionAlert", {
			victimName = victim.DisplayName,
			killerName = killer and killer.DisplayName or nil,
		})
	end,
	onSurvivorCountChanged = function(count: number)
		roundService:setSurvivorCount(count)
	end,
	onPatientZeroGone = function()
		-- PZ left before creating any zombies: survivors win by default
		roundService:forceEnd("SURVIVORS")
	end,
})

roundService = RoundService.new({
	remotes = remotes,
	onRoundStart = function(playersInRound)
		mapService:loadVotedMap()
		roleService:assignRoles(playersInRound)
	end,
	onRoundEnd = function(winner)
		local originalPZ = roleService:getOriginalPatientZero()
		local survivorNames = {}
		for _, survivor in roleService:survivors() do
			table.insert(survivorNames, survivor.DisplayName)
		end
		remotes.fireAllClients("RevealScreen", {
			winner = winner,
			patientZeroName = originalPZ and originalPZ.name or "?",
			survivors = survivorNames,
		})
		roleService:endRound()
	end,
	onIntermission = function()
		mapService:unload()
		mapService:openVote()
	end,
})

local combatService = CombatService.new({
	remotes = remotes,
	roleService = roleService,
	isRoundActive = function()
		return roundService:getState() == "ACTIVE"
	end,
	onZombieKilled = function(_killer: Player, _victim: Player)
		-- EconomyService hooks in here in Phase 5
	end,
})

local antiCheatService = AntiCheatService.new({
	remotes = remotes,
	combatService = combatService,
})

roleService:start()
roundService:start()
combatService:start()
antiCheatService:start()
mapService:start()

-- Studio-only smoke test: exercises the whole round loop with fast timers and
-- scripted deaths so a local multi-client playtest verifies itself in the Output.
if game:GetService("RunService"):IsStudio() then
	local SmokeTest = require(script.StudioSmokeTest)
	SmokeTest.run(roundService, roleService)
end

print("[INFECTED] Server booted")
