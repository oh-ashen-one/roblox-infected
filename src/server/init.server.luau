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

local remotes = Remotes.server()

local roundService
local roleService

roleService = RoleService.new({
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
	onIntermission = function() end,
})

roleService:start()
roundService:start()

-- Studio-only smoke test: exercises the whole round loop with fast timers and
-- scripted deaths so a local multi-client playtest verifies itself in the Output.
if game:GetService("RunService"):IsStudio() then
	local SmokeTest = require(script.StudioSmokeTest)
	SmokeTest.run(roundService, roleService)
end

print("[INFECTED] Server booted")
