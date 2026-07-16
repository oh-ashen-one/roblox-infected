--!strict
-- Client bootstrap. Phase 1: just subscribe to round state and log it.
-- Later phases add input controllers, weapon viewmodels, and UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local remotes = Remotes.client()

local CombatController = require(script.Controllers.CombatController)
CombatController.start(remotes)

remotes.on("RoundState", function(state)
	print(
		("[INFECTED] Round state: %s (players=%d, survivors=%d)"):format(
			tostring(state.state),
			tonumber(state.playerCount) or 0,
			tonumber(state.survivorCount) or 0
		)
	)
end)

print("[INFECTED] Client booted")
