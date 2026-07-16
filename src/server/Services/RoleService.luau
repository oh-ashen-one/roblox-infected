--!strict
-- Owns who is what during a round: SURVIVOR / PATIENT_ZERO / ZOMBIE.
-- Handles conversion on death, zombie respawns, mid-round joiners (join the horde),
-- and Patient Zero disconnects. All role state is server-only; clients get told
-- their own role privately and see zombie appearance changes through replication.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local PatientZero = require(Shared.PatientZero)

export type Role = "SURVIVOR" | "PATIENT_ZERO" | "ZOMBIE" | "NONE"

local RoleService = {}
RoleService.__index = RoleService

export type Deps = {
	remotes: any, -- Remotes.ServerApi
	onConversion: (victim: Player, killer: Player?) -> (), -- extend timer, rewards, alerts
	onSurvivorCountChanged: (count: number) -> (),
	onPatientZeroGone: () -> (), -- PZ left with no zombies yet -> round should end
	getSurvivorSpawn: (() -> CFrame?)?, -- map spawn points (nil -> default spawn)
	getZombieSpawn: ((survivorRoots: { BasePart }) -> CFrame?)?,
	getEquippedGunSkin: ((player: Player) -> string?)?, -- cosmetic gun tint
}

local rng = Random.new()

function RoleService.new(deps: Deps)
	local self = setmetatable({}, RoleService)
	self._deps = deps
	self._roles = {} :: { [Player]: Role }
	self._roundActive = false
	self._patientZero = nil :: Player?
	self._firstBloodDone = false
	-- userId -> rounds since they were PZ (incremented each round start)
	self._pzHistory = {} :: { [number]: number }
	-- Kept for the end-of-round reveal even if PZ dies/leaves mid-round
	self._originalPZ = nil :: { userId: number, name: string }?
	self._charConns = {} :: { [Player]: { RBXScriptConnection } }
	return self
end

-- Appearance ------------------------------------------------------------------

local function applyZombieAppearance(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = GameConfig.Combat.ZombieBaseHealth
		humanoid.Health = GameConfig.Combat.ZombieBaseHealth
		humanoid.WalkSpeed = GameConfig.Movement.BaseWalkSpeed
	end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = Color3.fromRGB(88, 160, 70)
			part.Material = Enum.Material.Slate
		elseif part:IsA("Shirt") or part:IsA("Pants") or part:IsA("ShirtGraphic") then
			part:Destroy()
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local particles = Instance.new("ParticleEmitter")
		particles.Name = "InfectionAura"
		particles.Color = ColorSequence.new(Color3.fromRGB(90, 200, 60))
		particles.Lifetime = NumberRange.new(0.4, 0.9)
		particles.Rate = 12
		particles.Speed = NumberRange.new(0.5, 1.5)
		particles.Size = NumberSequence.new(0.25)
		particles.Transparency = NumberSequence.new(0.4)
		particles.Parent = root
	end
end

local function applySpawnProtection(character: Model)
	local ff = Instance.new("ForceField")
	ff.Parent = character
	task.delay(GameConfig.Round.SpawnProtectionSeconds, function()
		ff:Destroy()
	end)
end

-- Role queries ----------------------------------------------------------------

function RoleService:getRole(player: Player): Role
	return self._roles[player] or "NONE"
end

function RoleService:isInfected(player: Player): boolean
	local role = self:getRole(player)
	return role == "PATIENT_ZERO" or role == "ZOMBIE"
end

function RoleService:getPatientZero(): Player?
	return self._patientZero
end

function RoleService:getOriginalPatientZero(): { userId: number, name: string }?
	return self._originalPZ
end

function RoleService:survivorCount(): number
	local n = 0
	for _, role in self._roles do
		if role == "SURVIVOR" then
			n += 1
		end
	end
	return n
end

function RoleService:survivors(): { Player }
	local out = {}
	for player, role in self._roles do
		if role == "SURVIVOR" then
			table.insert(out, player)
		end
	end
	return out
end

-- Round lifecycle ---------------------------------------------------------------

function RoleService:assignRoles(playersInRound: { Player })
	self._roundActive = true
	self._firstBloodDone = false
	table.clear(self._roles)

	-- age the PZ history one round
	for userId, rounds in self._pzHistory do
		self._pzHistory[userId] = rounds + 1
	end

	local candidates = {}
	for _, player in playersInRound do
		table.insert(candidates, { userId = player.UserId, roundsSincePZ = self._pzHistory[player.UserId] })
	end
	local pzUserId = PatientZero.select(candidates, GameConfig.Round.PatientZeroRecentRounds, function()
		return rng:NextNumber()
	end)

	for _, player in playersInRound do
		if player.UserId == pzUserId then
			self._roles[player] = "PATIENT_ZERO"
			self._patientZero = player
			self._originalPZ = { userId = player.UserId, name = player.DisplayName }
			self._pzHistory[player.UserId] = 0
		else
			self._roles[player] = "SURVIVOR"
		end
	end

	-- Everyone (re)spawns fresh for the round
	for _, player in playersInRound do
		player:LoadCharacter()
		local character = player.Character or player.CharacterAdded:Wait()
		if self._deps.getSurvivorSpawn then
			local spawnCFrame = self._deps.getSurvivorSpawn()
			local root = character:WaitForChild("HumanoidRootPart", 5)
			if spawnCFrame and root and root:IsA("BasePart") then
				root.CFrame = spawnCFrame
			end
		end
		applySpawnProtection(character)
		self:_watchCharacter(player, character)
		-- Everyone holds a gun — the hidden PZ must be indistinguishable
		local WeaponVisuals = require(script.Parent.WeaponVisuals)
		local gunSkin = self._deps.getEquippedGunSkin and self._deps.getEquippedGunSkin(player) or nil
		WeaponVisuals.attachGun(character, gunSkin)
		local role = self._roles[player]
		if role == "PATIENT_ZERO" then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = GameConfig.Movement.BaseWalkSpeed -- sprint mult applied by sprint system
			end
		end
		-- Private role card — the ONLY place a client learns its role
		self._deps.remotes.fireClient("RoleAssigned", player, { role = role })
	end

	self._deps.onSurvivorCountChanged(self:survivorCount())
end

function RoleService:endRound()
	self._roundActive = false
	self._patientZero = nil
	for player in self._roles do
		self:_unwatchCharacter(player)
	end
	table.clear(self._roles)
end

-- Conversion ------------------------------------------------------------------

function RoleService:convert(victim: Player, killer: Player?)
	if not self._roundActive then
		return
	end
	local role = self._roles[victim]
	if role ~= "SURVIVOR" then
		return -- already infected or not in round
	end
	self._roles[victim] = "ZOMBIE"

	self._deps.onConversion(victim, killer)
	self._deps.remotes.fireClient("RoleAssigned", victim, { role = "ZOMBIE" })
	self._deps.onSurvivorCountChanged(self:survivorCount())

	-- Respawn as zombie after a beat
	task.delay(GameConfig.Round.ZombieRespawnSeconds, function()
		if self._roundActive and self._roles[victim] == "ZOMBIE" and victim.Parent ~= nil then
			self:_spawnAsZombie(victim)
		end
	end)
end

function RoleService:_hordeFraction(): number
	local total, infected = 0, 0
	for _, role in self._roles do
		total += 1
		if role == "ZOMBIE" or role == "PATIENT_ZERO" then
			infected += 1
		end
	end
	if total == 0 then
		return 0
	end
	return infected / total
end

function RoleService:_pickZombieClass(): GameConfig.ZombieClass
	local fraction = self:_hordeFraction()
	local unlocked = {}
	for _, class in GameConfig.ZombieClasses do
		if fraction >= class.hordeThreshold then
			table.insert(unlocked, class)
		end
	end
	return unlocked[rng:NextInteger(1, math.max(1, #unlocked))] or GameConfig.ZombieClasses[1]
end

function RoleService:_applyZombieClass(player: Player, character: Model, class: GameConfig.ZombieClass)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = class.maxHealth
		humanoid.Health = class.maxHealth
		humanoid.WalkSpeed = GameConfig.Movement.BaseWalkSpeed * class.walkSpeedMult
	end
	character:SetAttribute("ZombieClass", class.name)
	self._deps.remotes.fireClient("HordeUpdate", player, { yourClass = class.name })

	if class.ability == "scream" and class.abilityCooldown then
		-- Screamer: pulses survivor positions to the whole horde while alive
		task.spawn(function()
			while
				self._roundActive
				and self._roles[player] == "ZOMBIE"
				and player.Character == character
				and humanoid
				and humanoid.Health > 0
			do
				task.wait(class.abilityCooldown)
				if self._roundActive and player.Character == character and humanoid.Health > 0 then
					local positions = {}
					for _, survivor in self:survivors() do
						local sRoot = survivor.Character
							and survivor.Character:FindFirstChild("HumanoidRootPart")
						if sRoot and sRoot:IsA("BasePart") then
							table.insert(positions, {
								userId = survivor.UserId,
								name = survivor.DisplayName,
								x = sRoot.Position.X,
								y = sRoot.Position.Y,
								z = sRoot.Position.Z,
							})
						end
					end
					if #positions > 0 then
						self._deps.remotes.fireAllClients(
							"SurvivorPing",
							{ survivors = positions, scream = true }
						)
					end
				end
			end
		end)
	end
end

function RoleService:_spawnAsZombie(player: Player)
	player:LoadCharacter()
	local character = player.Character or player.CharacterAdded:Wait()
	if self._deps.getZombieSpawn then
		local survivorRoots = {}
		for _, survivor in self:survivors() do
			local sChar = survivor.Character
			local sRoot = sChar and sChar:FindFirstChild("HumanoidRootPart")
			if sRoot and sRoot:IsA("BasePart") then
				table.insert(survivorRoots, sRoot)
			end
		end
		local spawnCFrame = self._deps.getZombieSpawn(survivorRoots)
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if spawnCFrame and root and root:IsA("BasePart") then
			root.CFrame = spawnCFrame
		end
	end
	applyZombieAppearance(character)
	self:_applyZombieClass(player, character, self:_pickZombieClass())
	applySpawnProtection(character)
	self:_watchCharacter(player, character)
end

-- Death & connection plumbing ---------------------------------------------------

function RoleService:_watchCharacter(player: Player, character: Model)
	self:_unwatchCharacter(player)
	local conns = {}
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		table.insert(
			conns,
			humanoid.Died:Connect(function()
				self:_onDied(player)
			end)
		)
	end
	self._charConns[player] = conns
end

function RoleService:_unwatchCharacter(player: Player)
	local conns = self._charConns[player]
	if conns then
		for _, conn in conns do
			conn:Disconnect()
		end
		self._charConns[player] = nil
	end
end

function RoleService:_onDied(player: Player)
	if not self._roundActive then
		return
	end
	local role = self._roles[player]
	if role == "SURVIVOR" then
		-- ANY death converts (fall damage included, per spec)
		local killerValue = player.Character and player.Character:FindFirstChild("KilledBy")
		local killer = nil
		if killerValue and killerValue:IsA("ObjectValue") and killerValue.Value then
			local killerPlayer = killerValue.Value
			if killerPlayer:IsA("Player") then
				killer = killerPlayer
			end
		end
		self:convert(player, killer)
	elseif role == "ZOMBIE" then
		task.delay(GameConfig.Round.ZombieRespawnSeconds, function()
			if self._roundActive and self._roles[player] == "ZOMBIE" and player.Parent ~= nil then
				self:_spawnAsZombie(player)
			end
		end)
	elseif role == "PATIENT_ZERO" then
		-- Unmasked and killed: PZ becomes a regular (visible) zombie — apex threat ends
		self._roles[player] = "ZOMBIE"
		self._patientZero = nil
		self._deps.remotes.fireAllClients("KillFeed", { text = "Patient Zero has been unmasked!" })
		task.delay(GameConfig.Round.ZombieRespawnSeconds, function()
			if self._roundActive and player.Parent ~= nil then
				self:_spawnAsZombie(player)
			end
		end)
	end
end

function RoleService:start()
	Players.PlayerAdded:Connect(function(player)
		if self._roundActive then
			-- Mid-round joiners join the horde: keeps them playing immediately
			self._roles[player] = "ZOMBIE"
			self._deps.remotes.fireClient("RoleAssigned", player, { role = "ZOMBIE" })
			task.defer(function()
				self:_spawnAsZombie(player)
			end)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local role = self._roles[player]
		self._roles[player] = nil
		self:_unwatchCharacter(player)
		if not self._roundActive then
			return
		end
		if role == "PATIENT_ZERO" then
			self._patientZero = nil
			-- Hand the infection to a random zombie; if none exist, round can't continue
			local zombies = {}
			for p, r in self._roles do
				if r == "ZOMBIE" then
					table.insert(zombies, p)
				end
			end
			if #zombies > 0 then
				local heir = zombies[rng:NextInteger(1, #zombies)]
				self._roles[heir] = "PATIENT_ZERO"
				self._patientZero = heir
				self._deps.remotes.fireClient("RoleAssigned", heir, { role = "PATIENT_ZERO" })
			else
				self._deps.onPatientZeroGone()
			end
		elseif role == "SURVIVOR" then
			self._deps.onSurvivorCountChanged(self:survivorCount())
		end
	end)
end

return RoleService
