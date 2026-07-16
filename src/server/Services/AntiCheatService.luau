--!strict
-- Movement sanity + violation aggregation. Speed is the #1 exploit surface here
-- (a speed-hacked infected ruins rounds), so every player's displacement is checked
-- each window against the fastest legitimately-attainable speed. Flagged players are
-- snapped back; repeat offenders are kicked.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)

local KICK_THRESHOLD = 12 -- combined flags before kick
local SNAP_THRESHOLD = 3 -- movement flags before we start snapping back

local AntiCheatService = {}
AntiCheatService.__index = AntiCheatService

export type Deps = {
	remotes: any, -- Remotes.ServerApi (invalid-payload violations)
	combatService: any, -- combat flags
}

function AntiCheatService.new(deps: Deps)
	local self = setmetatable({}, AntiCheatService)
	self._deps = deps
	self._lastPos = {} :: { [Player]: Vector3 }
	self._movementFlags = {} :: { [Player]: number }
	return self
end

function AntiCheatService:_checkPlayer(player: Player, interval: number)
	local character = player.Character
	if character == nil then
		self._lastPos[player] = nil
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local pos = root.Position
	local last = self._lastPos[player]
	self._lastPos[player] = pos
	if last == nil then
		return
	end

	-- Horizontal displacement only: falling is legitimate vertical speed.
	local delta = pos - last
	local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local maxLegit = GameConfig.Movement.MaxToleratedSpeed * interval

	if horizontal > math.max(maxLegit, GameConfig.Movement.TeleportFlagStuds * interval) then
		local flags = (self._movementFlags[player] or 0) + 1
		self._movementFlags[player] = flags
		if flags >= SNAP_THRESHOLD then
			root.CFrame = CFrame.new(last) -- snap back
		end
	end
end

function AntiCheatService:totalFlags(player: Player): number
	return (self._movementFlags[player] or 0)
		+ self._deps.remotes.getViolations(player)
		+ self._deps.combatService:getFlags(player)
end

function AntiCheatService:start()
	Players.PlayerRemoving:Connect(function(player)
		self._lastPos[player] = nil
		self._movementFlags[player] = nil
	end)

	task.spawn(function()
		local interval = GameConfig.Movement.CheckIntervalSeconds
		while true do
			task.wait(interval)
			for _, player in Players:GetPlayers() do
				self:_checkPlayer(player, interval)
				if self:totalFlags(player) >= KICK_THRESHOLD then
					player:Kick("Suspicious activity detected.")
				end
			end
		end
	end)
end

return AntiCheatService
