--!strict
-- Map lifecycle: build all maps into ServerStorage at boot, run the intermission
-- vote, clone the winner into Workspace per round, destroy it after. Also owns
-- spawn-point selection, including "zombies respawn near the action but out of
-- survivor sightlines".

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")

local Mall = require(script.Parent.Parent.Maps.Mall)
local Suburbia = require(script.Parent.Parent.Maps.Suburbia)
local Facility = require(script.Parent.Parent.Maps.Facility)
local Warehouse = require(script.Parent.Parent.Maps.Warehouse)
local Metro = require(script.Parent.Parent.Maps.Metro)

local MAPS = { Mall, Suburbia, Facility, Warehouse, Metro }
local VOTE_CANDIDATES = 3 -- how many random maps are offered each vote (keeps the 3-button UI)

local MapService = {}
MapService.__index = MapService

export type Deps = {
	remotes: any, -- Remotes.ServerApi
}

local rng = Random.new()

function MapService.new(deps: Deps)
	local self = setmetatable({}, MapService)
	self._deps = deps
	self._storage = Instance.new("Folder")
	self._storage.Name = "Maps"
	self._storage.Parent = ServerStorage
	self._built = {} :: { Model }
	self._active = nil :: Model?
	self._activeIndex = 1
	self._votes = {} :: { [Player]: number } -- player -> candidate slot (1..#candidates)
	self._candidates = {} :: { number } -- actual map indices offered this vote
	self._voteOpen = false

	for _, mapDef in MAPS do
		local model = mapDef.build()
		model.Parent = self._storage
		table.insert(self._built, model)
	end
	return self
end

function MapService:mapNames(): { string }
	local names = {}
	for _, mapDef in MAPS do
		table.insert(names, mapDef.name)
	end
	return names
end

-- Voting -------------------------------------------------------------------------

-- Pick N distinct random map indices to offer this vote.
function MapService:_pickCandidates(): { number }
	local pool = {}
	for i = 1, #MAPS do
		pool[i] = i
	end
	-- Fisher-Yates partial shuffle.
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local out = {}
	for i = 1, math.min(VOTE_CANDIDATES, #MAPS) do
		out[i] = pool[i]
	end
	return out
end

function MapService:openVote()
	table.clear(self._votes)
	self._candidates = self:_pickCandidates()
	self._voteOpen = true
	local names = {}
	for _, index in self._candidates do
		table.insert(names, MAPS[index].name)
	end
	self._deps.remotes.fireAllClients("HordeUpdate", { mapVote = names })
end

-- `slot` is the candidate button index (1..#candidates), not the raw map index.
function MapService:castVote(player: Player, slot: number)
	if self._voteOpen and slot >= 1 and slot <= #self._candidates then
		self._votes[player] = slot
	end
end

function MapService:_tallyWinner(): number
	local candidates = self._candidates
	if #candidates == 0 then
		return rng:NextInteger(1, #MAPS)
	end
	local counts = table.create(#candidates, 0)
	for _, slot in self._votes do
		counts[slot] += 1
	end
	local bestSlot, bestCount = 0, -1
	for i = 1, #candidates do
		if counts[i] > bestCount then
			bestSlot, bestCount = i, counts[i]
		end
	end
	if bestCount <= 0 then
		return candidates[rng:NextInteger(1, #candidates)] -- nobody voted
	end
	return candidates[bestSlot]
end

-- Round lifecycle ------------------------------------------------------------------

function MapService:loadVotedMap(): Model
	self._voteOpen = false
	self:unload()
	local index = self:_tallyWinner()
	self._activeIndex = index
	local clone = self._built[index]:Clone()
	clone.Name = "ActiveMap"
	clone.Parent = workspace

	local lighting = MAPS[index].lighting
	Lighting.Ambient = lighting.Ambient
	Lighting.OutdoorAmbient = lighting.OutdoorAmbient
	Lighting.ClockTime = lighting.ClockTime
	Lighting.FogEnd = lighting.FogEnd
	Lighting.FogColor = lighting.FogColor

	self._active = clone
	return clone
end

function MapService:unload()
	if self._active then
		self._active:Destroy()
		self._active = nil
	end
end

-- A map is always present so players never stand on an empty baseplate. Used during
-- intermission and at server start; a round replaces it via loadVotedMap().
function MapService:loadLobby()
	self:unload()
	local index = rng:NextInteger(1, #MAPS)
	self._activeIndex = index
	local clone = self._built[index]:Clone()
	clone.Name = "ActiveMap"
	clone.Parent = workspace
	local lighting = MAPS[index].lighting
	Lighting.Ambient = lighting.Ambient
	Lighting.OutdoorAmbient = lighting.OutdoorAmbient
	Lighting.ClockTime = lighting.ClockTime
	Lighting.FogEnd = lighting.FogEnd
	Lighting.FogColor = lighting.FogColor
	self._active = clone
	return clone
end

-- Spawns -------------------------------------------------------------------------

function MapService:_spawnsIn(folderName: string): { BasePart }
	local out = {}
	if self._active then
		local folder = self._active:FindFirstChild(folderName)
		if folder then
			for _, marker in folder:GetChildren() do
				if marker:IsA("BasePart") then
					table.insert(out, marker)
				end
			end
		end
	end
	return out
end

function MapService:randomSurvivorSpawn(): CFrame?
	local spawns = self:_spawnsIn("SurvivorSpawns")
	if #spawns == 0 then
		return nil
	end
	return spawns[rng:NextInteger(1, #spawns)].CFrame
end

-- Nearest zombie spawn to any survivor that is >=25 studs away and has no clear
-- line of sight to a survivor; falls back to random.
function MapService:zombieSpawnNearAction(survivorRoots: { BasePart }): CFrame?
	local spawns = self:_spawnsIn("ZombieSpawns")
	if #spawns == 0 then
		return self:randomSurvivorSpawn()
	end
	local best: BasePart? = nil
	local bestDist = math.huge
	for _, marker in spawns do
		local nearest = math.huge
		local visible = false
		for _, root in survivorRoots do
			local offset = root.Position - marker.Position
			local dist = offset.Magnitude
			nearest = math.min(nearest, dist)
			if dist < 120 then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { root.Parent :: Instance }
				local hit = workspace:Raycast(marker.Position, offset, params)
				if hit == nil then
					visible = true
				end
			end
		end
		if nearest >= 25 and not visible and nearest < bestDist then
			best = marker
			bestDist = nearest
		end
	end
	if best == nil then
		best = spawns[rng:NextInteger(1, #spawns)]
	end
	return (best :: BasePart).CFrame
end

function MapService:start()
	self._deps.remotes.onValidated("VoteMap", function(player, payload)
		self:castVote(player, payload.mapIndex)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._votes[player] = nil
	end)
end

return MapService
