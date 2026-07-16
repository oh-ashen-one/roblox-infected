--!strict
-- Server bootstrap. Order matters: remotes first (clients WaitForChild on the folder),
-- then services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local RoundService = require(script.Services.RoundService)

local remotes = Remotes.server()

local roundService = RoundService.new({
	remotes = remotes,
	onRoundStart = function(playersInRound)
		print(("[INFECTED] Round started with %d players"):format(#playersInRound))
	end,
	onRoundEnd = function(winner)
		print(("[INFECTED] Round over — winner: %s"):format(winner))
	end,
	onIntermission = function()
		print("[INFECTED] Intermission started")
	end,
})

roundService:start()

print("[INFECTED] Server booted")
