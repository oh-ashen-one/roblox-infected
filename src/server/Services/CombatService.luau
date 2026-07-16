--!strict
-- All combat lives here, fully server-authoritative:
--   Guns  : client claims origin+direction; server verifies the claim against the
--           character, enforces per-weapon cooldown and ammo, then raycasts itself.
--   Knives: Patient Zero's throwing knife is a real projectile simulated on the
--           server in Heartbeat segments (client renders a cosmetic copy).
--   Melee : range + cooldown validated server-side.
-- Damage rules (spec):
--   Guns damage zombies and the *hidden* Patient Zero (the MM2 mind-game), never
--   plain survivors. PZ knife = one-hit conversion. Zombie claws = 2 hits.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)

local CombatService = {}
CombatService.__index = CombatService

export type Deps = {
	remotes: any, -- Remotes.ServerApi
	roleService: any,
	isRoundActive: () -> boolean,
	onZombieKilled: (killer: Player, victim: Player) -> (), -- rewards
	isLastStand: ((player: Player) -> boolean)?, -- damage resist + Minigun access
	getPrimary: ((player: Player) -> string)?, -- selected loadout (nil -> allow all)
}

-- Claimed fire origin may be at most this far from the character's actual head
-- (covers latency); beyond it the shot is rejected and flagged.
local ORIGIN_TOLERANCE = 12

type WeaponState = { mag: number, lastShot: number, reloadingUntil: number }

function CombatService.new(deps: Deps)
	local self = setmetatable({}, CombatService)
	self._deps = deps
	self._weaponState = {} :: { [Player]: { [string]: WeaponState } }
	self._lastThrow = {} :: { [Player]: number }
	self._lastMelee = {} :: { [Player]: number }
	self._flags = {} :: { [Player]: number }
	Players.PlayerRemoving:Connect(function(player)
		self._weaponState[player] = nil
		self._lastThrow[player] = nil
		self._lastMelee[player] = nil
		self._flags[player] = nil
	end)
	return self
end

function CombatService:getFlags(player: Player): number
	return self._flags[player] or 0
end

function CombatService:_flag(player: Player)
	self._flags[player] = (self._flags[player] or 0) + 1
end

function CombatService:resetRound()
	table.clear(self._weaponState)
	table.clear(self._lastThrow)
	table.clear(self._lastMelee)
end

-- Helpers ----------------------------------------------------------------------

local function characterOf(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if character == nil then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function playerFromHit(instance: Instance): Player?
	local model = instance:FindFirstAncestorOfClass("Model")
	if model then
		return Players:GetPlayerFromCharacter(model)
	end
	return nil
end

local function tagKiller(victim: Player, killer: Player)
	local character = victim.Character
	if character == nil then
		return
	end
	local tag = character:FindFirstChild("KilledBy")
	if tag == nil then
		tag = Instance.new("ObjectValue")
		tag.Name = "KilledBy"
		tag.Parent = character
	end
	local tagValue = tag :: ObjectValue
	tagValue.Value = killer
end

local function isProtected(character: Model): boolean
	return character:FindFirstChildOfClass("ForceField") ~= nil
end

-- Guns ---------------------------------------------------------------------------

function CombatService:_weaponStateFor(player: Player, weaponId: string): WeaponState
	local perPlayer = self._weaponState[player]
	if perPlayer == nil then
		perPlayer = {}
		self._weaponState[player] = perPlayer
	end
	local state = perPlayer[weaponId]
	if state == nil then
		local spec = (GameConfig.Combat.Guns :: any)[weaponId]
		state = { mag = spec.Mag, lastShot = 0, reloadingUntil = 0 }
		perPlayer[weaponId] = state
	end
	return state
end

function CombatService:handleFireWeapon(
	player: Player,
	payload: { origin: Vector3, direction: Vector3, weaponId: string }
)
	if not self._deps.isRoundActive() then
		return
	end
	local role = self._deps.roleService:getRole(player)
	-- Only non-zombies shoot. Hidden PZ may also shoot (they must blend in!).
	if role ~= "SURVIVOR" and role ~= "PATIENT_ZERO" then
		self:_flag(player)
		return
	end

	-- Weapon must be in the player's loadout: selected primary, the Pistol sidearm,
	-- or the Minigun during Last Stand.
	if self._deps.getPrimary then
		local allowed = payload.weaponId == self._deps.getPrimary(player)
			or payload.weaponId == "Pistol"
			or (
				payload.weaponId == "Minigun"
				and self._deps.isLastStand ~= nil
				and self._deps.isLastStand(player)
			)
		if not allowed then
			self:_flag(player)
			return
		end
	end

	local spec = (GameConfig.Combat.Guns :: any)[payload.weaponId]
	local character, _, root = characterOf(player)
	if character == nil or root == nil then
		return
	end

	-- Origin must be near the actual character (anti "shoot from anywhere")
	if (payload.origin - (root :: BasePart).Position).Magnitude > ORIGIN_TOLERANCE then
		self:_flag(player)
		return
	end

	local state = self:_weaponStateFor(player, payload.weaponId)
	local now = os.clock()
	if now < state.reloadingUntil then
		return -- still reloading; not hostile, just ignore
	end
	if now - state.lastShot < (1 / spec.FireRate) * 0.9 then -- 10% slack for jitter
		self:_flag(player)
		return
	end
	if state.mag <= 0 then
		return
	end
	state.lastShot = now
	state.mag -= 1

	local pellets = spec.Pellets or 1
	local rng = Random.new()
	for _ = 1, pellets do
		local direction = payload.direction
		if pellets > 1 then
			direction = (direction + Vector3.new(
				rng:NextNumber(-0.06, 0.06),
				rng:NextNumber(-0.06, 0.06),
				rng:NextNumber(-0.06, 0.06)
			)).Unit
		end
		self:_hitscan(player, character :: Model, payload.origin, direction, spec)
	end

	-- Broadcast for tracer/sound rendering on other clients
	self._deps.remotes.fireAllClients("ShotFired", {
		shooterUserId = player.UserId,
		origin = payload.origin,
		direction = payload.direction,
		weaponId = payload.weaponId,
	})
end

function CombatService:_hitscan(
	shooter: Player,
	shooterChar: Model,
	origin: Vector3,
	direction: Vector3,
	spec: any
)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { shooterChar }
	local result = workspace:Raycast(origin, direction * spec.Range, params)
	if result == nil then
		return
	end
	local victim = playerFromHit(result.Instance)
	if victim == nil then
		return
	end
	local victimRole = self._deps.roleService:getRole(victim)
	local victimChar, victimHumanoid = characterOf(victim)
	if victimChar == nil or victimHumanoid == nil or isProtected(victimChar :: Model) then
		return
	end

	if victimRole == "ZOMBIE" then
		tagKiller(victim, shooter)
		local vh = victimHumanoid :: Humanoid
		vh:TakeDamage(spec.Damage)
		if (victimHumanoid :: Humanoid).Health <= 0 then
			self._deps.onZombieKilled(shooter, victim)
		end
		self._deps.remotes.fireClient(
			"HitConfirm",
			shooter,
			{ killed = (victimHumanoid :: Humanoid).Health <= 0 }
		)
	elseif victimRole == "PATIENT_ZERO" then
		-- The mind game: shooting the hidden PZ works
		tagKiller(victim, shooter)
		local vh = victimHumanoid :: Humanoid
		vh:TakeDamage(spec.Damage)
		self._deps.remotes.fireClient(
			"HitConfirm",
			shooter,
			{ killed = (victimHumanoid :: Humanoid).Health <= 0 }
		)
	else
		-- Survivor shot survivor: no damage, no feedback (prevents role-scanning by shooting)
		return
	end
end

function CombatService:handleReload(player: Player, payload: { weaponId: string })
	local spec = (GameConfig.Combat.Guns :: any)[payload.weaponId]
	local state = self:_weaponStateFor(player, payload.weaponId)
	local now = os.clock()
	if state.mag >= spec.Mag or now < state.reloadingUntil then
		return
	end
	state.reloadingUntil = now + spec.Reload
	task.delay(spec.Reload, function()
		if player.Parent ~= nil then
			state.mag = spec.Mag
		end
	end)
end

-- Knives -------------------------------------------------------------------------

function CombatService:handleThrowKnife(player: Player, payload: { origin: Vector3, direction: Vector3 })
	if not self._deps.isRoundActive() then
		return
	end
	if self._deps.roleService:getRole(player) ~= "PATIENT_ZERO" then
		self:_flag(player) -- only PZ throws
		return
	end
	local character, _, root = characterOf(player)
	if character == nil or root == nil then
		return
	end
	if (payload.origin - (root :: BasePart).Position).Magnitude > ORIGIN_TOLERANCE then
		self:_flag(player)
		return
	end
	local now = os.clock()
	local last = self._lastThrow[player] or 0
	if now - last < GameConfig.Combat.PatientZero.ThrowCooldown * 0.9 then
		self:_flag(player)
		return
	end
	self._lastThrow[player] = now

	self._deps.remotes.fireAllClients("KnifeThrown", {
		throwerUserId = player.UserId,
		origin = payload.origin,
		direction = payload.direction,
	})
	self:_simulateKnife(player, character :: Model, payload.origin, payload.direction)
end

function CombatService:_simulateKnife(
	thrower: Player,
	throwerChar: Model,
	origin: Vector3,
	direction: Vector3
)
	local pzConfig = GameConfig.Combat.PatientZero
	task.spawn(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { throwerChar }

		local position = origin
		local velocity = direction * pzConfig.ThrowSpeed
		local traveled = 0
		while traveled < pzConfig.MaxThrowRange do
			local dt = task.wait() -- Heartbeat step
			local step = velocity * dt
			local result = workspace:Raycast(position, step, params)
			if result ~= nil then
				local victim = playerFromHit(result.Instance)
				if victim ~= nil and victim ~= thrower then
					local victimChar, victimHumanoid = characterOf(victim)
					local role = self._deps.roleService:getRole(victim)
					if
						victimChar ~= nil
						and victimHumanoid ~= nil
						and role == "SURVIVOR"
						and not isProtected(victimChar :: Model)
					then
						tagKiller(victim, thrower)
						local vh = victimHumanoid :: Humanoid
						local damage = vh.MaxHealth
						if self._deps.isLastStand and self._deps.isLastStand(victim) then
							damage *= GameConfig.Combat.LastStand.DamageResistMult
						end
						vh:TakeDamage(damage)
					end
				end
				return -- knife stops on any hit
			end
			position += step
			traveled += step.Magnitude
			velocity -= Vector3.new(0, pzConfig.ThrowGravity * dt, 0)
		end
	end)
end

-- Melee --------------------------------------------------------------------------

function CombatService:handleMelee(player: Player, payload: { targetUserId: number })
	if not self._deps.isRoundActive() then
		return
	end
	local role = self._deps.roleService:getRole(player)
	if role ~= "PATIENT_ZERO" and role ~= "ZOMBIE" then
		self:_flag(player)
		return
	end
	local cooldown = if role == "PATIENT_ZERO"
		then GameConfig.Combat.PatientZero.MeleeCooldown
		else GameConfig.Combat.Zombie.MeleeCooldown

	local now = os.clock()
	local last = self._lastMelee[player] or 0
	if now - last < cooldown * 0.9 then
		self:_flag(player)
		return
	end

	local target = Players:GetPlayerByUserId(payload.targetUserId)
	if target == nil or target == player then
		return
	end
	if self._deps.roleService:getRole(target) ~= "SURVIVOR" then
		return -- infected can't hurt infected
	end
	local _, _, myRoot = characterOf(player)
	local targetChar, targetHumanoid, targetRoot = characterOf(target)
	if myRoot == nil or targetChar == nil or targetHumanoid == nil or targetRoot == nil then
		return
	end
	if isProtected(targetChar :: Model) then
		return
	end
	local range = GameConfig.Combat.Zombie.MeleeRange
	if ((myRoot :: BasePart).Position - (targetRoot :: BasePart).Position).Magnitude > range + 3 then -- +3 latency slack
		self:_flag(player)
		return
	end
	self._lastMelee[player] = now

	tagKiller(target, player)
	local th = targetHumanoid :: Humanoid
	local damage = if role == "PATIENT_ZERO" then th.MaxHealth else GameConfig.Combat.Zombie.MeleeDamage
	if self._deps.isLastStand and self._deps.isLastStand(target) then
		damage *= GameConfig.Combat.LastStand.DamageResistMult
	end
	th:TakeDamage(damage)
end

-- Sprint -------------------------------------------------------------------------

function CombatService:handleSprint(player: Player, payload: { sprinting: string })
	local _, humanoid = characterOf(player)
	if humanoid == nil then
		return
	end
	local sprinting = payload.sprinting == "on"
	local speed = if sprinting then GameConfig.Movement.SprintWalkSpeed else GameConfig.Movement.BaseWalkSpeed
	if self._deps.roleService:getRole(player) == "PATIENT_ZERO" and sprinting then
		speed *= GameConfig.Combat.PatientZero.SprintMult
	end
	local h = humanoid :: Humanoid
	h.WalkSpeed = speed
end

-- Wiring -------------------------------------------------------------------------

function CombatService:start()
	local remotes = self._deps.remotes
	remotes.onValidated("FireWeapon", function(player, payload)
		self:handleFireWeapon(player, payload)
	end)
	remotes.onValidated("ThrowKnife", function(player, payload)
		self:handleThrowKnife(player, payload)
	end)
	remotes.onValidated("MeleeAttack", function(player, payload)
		self:handleMelee(player, payload)
	end)
	remotes.onValidated("Reload", function(player, payload)
		self:handleReload(player, payload)
	end)
	remotes.onValidated("SprintState", function(player, payload)
		self:handleSprint(player, payload)
	end)
end

return CombatService
