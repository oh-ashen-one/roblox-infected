--!strict
-- Endgame drama: when few survivors remain, ping their positions to everyone
-- (anti-camp, per COD Infected); the final survivor gets Last Stand — damage
-- resist plus the heavy weapon — and a server-wide callout.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)

local EndgameService = {}
EndgameService.__index = EndgameService

export type Deps = {
	remotes: any,
	roleService: any,
	isRoundActive: () -> boolean,
}

function EndgameService.new(deps: Deps)
	local self = setmetatable({}, EndgameService)
	self._deps = deps
	self._lastStandPlayer = nil :: Player?
	self._lastStandAnnounced = false
	return self
end

function EndgameService:isLastStand(player: Player): boolean
	return self._lastStandPlayer == player
end

function EndgameService:resetRound()
	self._lastStandPlayer = nil
	self._lastStandAnnounced = false
end

function EndgameService:_pingSurvivors()
	local positions = {}
	for _, survivor in self._deps.roleService:survivors() do
		local character = survivor.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(positions, {
				userId = survivor.UserId,
				name = survivor.DisplayName,
				x = root.Position.X,
				y = root.Position.Y,
				z = root.Position.Z,
			})
		end
	end
	if #positions > 0 then
		self._deps.remotes.fireAllClients("SurvivorPing", { survivors = positions })
	end
end

function EndgameService:start()
	task.spawn(function()
		while true do
			task.wait(GameConfig.Round.PingIntervalSeconds)
			if not self._deps.isRoundActive() then
				self:resetRound()
				continue
			end
			local survivors = self._deps.roleService:survivors()
			if #survivors > 0 and #survivors <= GameConfig.Round.LastSurvivorsPingCount then
				self:_pingSurvivors()
			end
			if #survivors == 1 then
				local last = survivors[1]
				if self._lastStandPlayer ~= last then
					self._lastStandPlayer = last
					if not self._lastStandAnnounced then
						self._lastStandAnnounced = true
						self._deps.remotes.fireAllClients("KillFeed", {
							text = ("%s is the LAST SURVIVOR — take them down!"):format(last.DisplayName),
						})
						self._deps.remotes.fireClient(
							"RoleAssigned",
							last,
							{ role = "SURVIVOR", lastStand = true }
						)
					end
				end
			elseif #survivors > 1 then
				self._lastStandPlayer = nil
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if self._lastStandPlayer == player then
			self._lastStandPlayer = nil
		end
	end)
end

return EndgameService
