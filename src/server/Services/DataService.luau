--!strict
-- Player persistence on ProfileStore (session-locked; prevents dupes across servers).
-- Everything the player owns lives in the profile; ProfileSync pushes a projection
-- to the client whenever it changes.

local Players = game:GetService("Players")

local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore)

local PROFILE_TEMPLATE = {
	coins = 0,
	xp = 0,
	ownedSkins = {} :: { [string]: boolean },
	equipped = { Knife = "knife_steel", Gun = "gun_carbon" },
	loadout = { primary = "AssaultRifle" },
	stats = { kills = 0, conversions = 0, wins = 0, rounds = 0, firstBloods = 0, lastSurvivor = 0 },
	receipts = {} :: { [string]: boolean }, -- processed dev-product receipts (idempotency)
	pzTokens = 0,
}

export type Profile = typeof(PROFILE_TEMPLATE)

local DataService = {}
DataService.__index = DataService

export type Deps = {
	remotes: any, -- Remotes.ServerApi
}

function DataService.new(deps: Deps)
	local self = setmetatable({}, DataService)
	self._deps = deps
	self._store = ProfileStore.New("PlayerData_v1", PROFILE_TEMPLATE)
	self._profiles = {} :: { [Player]: any }
	return self
end

function DataService:get(player: Player): Profile?
	local profile = self._profiles[player]
	return profile and profile.Data or nil
end

function DataService:sync(player: Player)
	local data = self:get(player)
	if data then
		self._deps.remotes.fireClient("ProfileSync", player, {
			coins = data.coins,
			xp = data.xp,
			ownedSkins = data.ownedSkins,
			equipped = data.equipped,
			loadout = data.loadout,
			stats = data.stats,
			pzTokens = data.pzTokens,
		})
	end
end

function DataService:_load(player: Player)
	local profile = self._store:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Your data is loaded on another server. Rejoin in a moment.")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		self._profiles[player] = nil
		player:Kick("Data session ended. Please rejoin.")
	end)
	if player.Parent == Players then
		self._profiles[player] = profile
		self:sync(player)
	else
		profile:EndSession()
	end
end

function DataService:start()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_load(player)
		end)
	end
	Players.PlayerAdded:Connect(function(player)
		self:_load(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local profile = self._profiles[player]
		if profile then
			profile:EndSession()
		end
	end)
	-- ProfileStore hooks BindToClose internally; sessions flush on shutdown.
end

return DataService
