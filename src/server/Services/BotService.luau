--!strict
-- Server-controlled bots so a solo player can experience a full round. Bots are
-- lightweight NPC rigs (no avatar assets) with a Humanoid, so the existing combat
-- raycasts hit them. They fill the lobby to a target headcount, get assigned roles
-- alongside the human, and are cleaned up at round end.
--
-- AI: each bot navigates with PathfindingService (paths around walls, recovers when
-- wedged) and has a rolled difficulty tier + personality. Survivors roam / group /
-- flee visible infected and shoot back at visible zombies; infected chase, and the
-- Patient Zero stalks the most isolated survivor. The hidden PZ is never surfaced to
-- bot senses, so their reactions can't leak the mind-game.
--
-- Bot characters are tagged with attributes the combat + AI code reads:
--   IsBot   = true
--   BotRole = "SURVIVOR" | "PATIENT_ZERO" | "ZOMBIE"

local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)

local BotService = {}
BotService.__index = BotService

export type Deps = {
	remotes: any,
	getSurvivorSpawn: () -> CFrame?,
	getZombieSpawn: (survivorRoots: { BasePart }) -> CFrame?,
	-- The human survivors currently alive (for bots to hunt / flee).
	getHumanSurvivors: () -> { Player },
	-- Roots of VISIBLY infected players (ZOMBIE role; excludes the hidden PZ) so survivor
	-- bots flee / shoot human zombies too, not just zombie bots.
	getInfectedPlayerRoots: () -> { BasePart },
	-- An infected bot reached a human survivor -> convert them through RoleService.
	convertHuman: (victim: Player) -> (),
	-- A human killed / converted a bot -> route rewards.
	onBotKilledByHuman: (killer: Player) -> (),
	onBotConvertedByHuman: (killer: Player) -> (),
	-- Any survivor bot became a zombie -> extend the round timer like a real conversion.
	onConversionOccurred: () -> (),
	-- Counts changed -> re-aggregate survivor total for the round machine.
	onCountsChanged: () -> (),
}

type Difficulty = { name: string, weight: number, speedMult: number, reactionMult: number }

type Bot = {
	id: number,
	name: string,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	role: string,
	wanderTarget: Vector3?,
	lastAction: number,
	-- behaviour flavour
	personality: string,
	difficulty: Difficulty,
	baseSpeed: number,
	-- pathfinding nav state
	path: Path?,
	waypoints: { PathWaypoint },
	waypointIndex: number,
	navGoal: Vector3?,
	lastRepath: number,
	computing: boolean,
	lastPos: Vector3,
	lastMoveCheck: number,
	stuckSince: number?,
	-- survivor gunfire
	nextShotAt: number,
	aimingSince: number?,
}

local NAMES = {
	"Ava",
	"Cole",
	"Dax",
	"Enzo",
	"Faye",
	"Gio",
	"Hana",
	"Ivo",
	"Juno",
	"Kai",
	"Lux",
	"Mira",
	"Nix",
	"Oz",
	"Pax",
	"Quill",
	"Remi",
	"Sol",
	"Tess",
	"Vera",
}

local rng = Random.new()

-- Weighted pick of a difficulty tier from config.
local function rollDifficulty(): Difficulty
	local tiers = GameConfig.Bots.Difficulties
	local total = 0
	for _, t in tiers do
		total += t.weight
	end
	local pick = rng:NextNumber(0, total)
	for _, t in tiers do
		pick -= t.weight
		if pick <= 0 then
			return t
		end
	end
	return tiers[1]
end

function BotService.new(deps: Deps)
	local self = setmetatable({}, BotService)
	self._deps = deps
	self._bots = {} :: { [number]: Bot }
	self._nextId = 1
	self._active = false
	return self
end

-- How many bots to field given the human count (fill up to a target headcount).
function BotService:plannedCount(humanCount: number): number
	if humanCount <= 0 then
		return 0
	end
	local target = GameConfig.Bots.TargetPlayers
	return math.clamp(target - humanCount, 0, GameConfig.Bots.MaxBots)
end

function BotService:survivorCount(): number
	local n = 0
	for _, bot in self._bots do
		if bot.role == "SURVIVOR" then
			n += 1
		end
	end
	return n
end

function BotService:patientZeroName(): string?
	for _, bot in self._bots do
		if bot.role == "PATIENT_ZERO" then
			return bot.name
		end
	end
	return nil
end

function BotService:survivorNames(): { string }
	local out = {}
	for _, bot in self._bots do
		if bot.role == "SURVIVOR" then
			table.insert(out, bot.name)
		end
	end
	return out
end

-- Rig ---------------------------------------------------------------------------

local function makePart(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("Weld")
	w.Part0 = a
	w.Part1 = b
	w.C0 = a.CFrame:Inverse() * b.CFrame
	w.Parent = a
end

function BotService:_buildRig(name: string, spawnCFrame: CFrame): (Model, Humanoid, BasePart)
	local model = Instance.new("Model")
	model.Name = name

	local skin = Color3.fromRGB(210, 180, 140)
	local shirt = Color3.fromRGB(70, 90, 130)

	local root = makePart("HumanoidRootPart", Vector3.new(2, 2, 1), shirt)
	root.Transparency = 1
	root.CFrame = spawnCFrame + Vector3.new(0, 3, 0)
	root.Parent = model

	local torso = makePart("Torso", Vector3.new(2, 2, 1), shirt)
	torso.CFrame = root.CFrame
	torso.Parent = model
	weld(root, torso)

	local head = makePart("Head", Vector3.new(1.4, 1.2, 1.4), skin)
	head.CFrame = torso.CFrame * CFrame.new(0, 1.6, 0)
	head.Parent = model
	weld(torso, head)

	local legL = makePart("LeftLeg", Vector3.new(0.8, 2, 0.9), Color3.fromRGB(45, 55, 75))
	legL.CFrame = torso.CFrame * CFrame.new(-0.5, -2, 0)
	legL.Parent = model
	weld(torso, legL)
	local legR = makePart("RightLeg", Vector3.new(0.8, 2, 0.9), Color3.fromRGB(45, 55, 75))
	legR.CFrame = torso.CFrame * CFrame.new(0.5, -2, 0)
	legR.Parent = model
	weld(torso, legR)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.MaxHealth = GameConfig.Combat.SurvivorMaxHealth
	humanoid.Health = GameConfig.Combat.SurvivorMaxHealth
	humanoid.WalkSpeed = GameConfig.Movement.BaseWalkSpeed
	humanoid.HipHeight = 2
	humanoid.Parent = model

	local nameTag = Instance.new("BillboardGui")
	nameTag.Size = UDim2.new(0, 100, 0, 24)
	nameTag.StudsOffset = Vector3.new(0, 2.4, 0)
	nameTag.AlwaysOnTop = false
	nameTag.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(230, 230, 235)
	label.TextStrokeTransparency = 0.5
	label.Text = name
	label.Parent = nameTag

	model.PrimaryPart = root
	model.Parent = workspace
	return model, humanoid, root
end

-- Role appearance ----------------------------------------------------------------

function BotService:_applyRole(bot: Bot, role: string)
	bot.role = role
	bot.model:SetAttribute("BotRole", role)
	if role == "ZOMBIE" or role == "PATIENT_ZERO" then
		bot.humanoid.WalkSpeed = GameConfig.Movement.BaseWalkSpeed
			* (if role == "PATIENT_ZERO" then GameConfig.Combat.PatientZero.SprintMult else 1)
		if role == "ZOMBIE" then
			bot.humanoid.MaxHealth = GameConfig.Combat.ZombieBaseHealth
			bot.humanoid.Health = GameConfig.Combat.ZombieBaseHealth
			for _, part in bot.model:GetDescendants() do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.Color = Color3.fromRGB(88, 160, 70)
					part.Material = Enum.Material.Slate
				end
			end
		end
	end
end

-- Lifecycle ----------------------------------------------------------------------

function BotService:spawnForRound(count: number, opts: { botIsPZ: boolean })
	self:clear()
	self._active = true
	local pzIndex = if opts.botIsPZ then rng:NextInteger(1, math.max(1, count)) else -1
	for i = 1, count do
		local spawnCFrame = self._deps.getSurvivorSpawn() or CFrame.new(0, 5, 0)
		local id = self._nextId
		self._nextId += 1
		local name = NAMES[((id - 1) % #NAMES) + 1] .. " [bot]"
		local model, humanoid, root = self:_buildRig(name, spawnCFrame)
		model:SetAttribute("IsBot", true)
		model:SetAttribute("BotId", id)
		local personalities = GameConfig.Bots.Personalities
		local bot: Bot = {
			id = id,
			name = name,
			model = model,
			humanoid = humanoid,
			root = root,
			role = "SURVIVOR",
			wanderTarget = nil,
			lastAction = 0,
			personality = personalities[rng:NextInteger(1, #personalities)],
			difficulty = rollDifficulty(),
			baseSpeed = GameConfig.Movement.BaseWalkSpeed,
			path = nil,
			waypoints = {},
			waypointIndex = 1,
			navGoal = nil,
			lastRepath = 0,
			computing = false,
			lastPos = root.Position,
			lastMoveCheck = 0,
			stuckSince = nil,
			nextShotAt = 0,
			aimingSince = nil,
		}
		self._bots[id] = bot
		self:_applyRole(bot, if i == pzIndex then "PATIENT_ZERO" else "SURVIVOR")
		humanoid.Died:Connect(function()
			self:_onBotDied(bot)
		end)
	end
	self._deps.onCountsChanged()
end

function BotService:clear()
	self._active = false
	for id, bot in self._bots do
		bot.model:Destroy()
		self._bots[id] = nil
	end
end

function BotService:_botFromCharacter(character: Instance): Bot?
	if not character:IsA("Model") then
		return nil
	end
	local id = character:GetAttribute("BotId")
	if type(id) == "number" then
		return self._bots[id]
	end
	return nil
end

-- Combat hooks (called by CombatService when a bot is hit) -----------------------

-- Human gun shot a bot. Returns true if the bot died.
function BotService:damageBot(character: Model, amount: number, attacker: Player?): boolean
	local bot = self:_botFromCharacter(character)
	if bot == nil or bot.role ~= "ZOMBIE" then
		return false
	end
	bot.humanoid:TakeDamage(amount)
	if bot.humanoid.Health <= 0 then
		if attacker then
			self._deps.onBotKilledByHuman(attacker)
		end
		return true
	end
	return false
end

-- Human PZ knife/melee converted a survivor bot.
function BotService:convertBot(character: Model, attacker: Player?): boolean
	local bot = self:_botFromCharacter(character)
	if bot == nil or bot.role ~= "SURVIVOR" then
		return false
	end
	self:_applyRole(bot, "ZOMBIE")
	if attacker then
		self._deps.onBotConvertedByHuman(attacker)
	end
	self._deps.onConversionOccurred()
	local root = character:FindFirstChild("HumanoidRootPart")
	self._deps.remotes.fireAllClients("ConversionAlert", {
		victimName = bot.name,
		killerName = attacker and attacker.DisplayName or nil,
		position = (root and root:IsA("BasePart")) and root.Position or nil,
	})
	self._deps.onCountsChanged()
	return true
end

function BotService:isSurvivorBot(character: Model): boolean
	local bot = self:_botFromCharacter(character)
	return bot ~= nil and bot.role == "SURVIVOR"
end

function BotService:isZombieBot(character: Model): boolean
	local bot = self:_botFromCharacter(character)
	return bot ~= nil and bot.role == "ZOMBIE"
end

-- A short-lived physics ragdoll "corpse" flung on death. It is a SEPARATE throwaway model
-- (cloned mesh parts joined by BallSocketConstraints, Debris-cleaned after a few seconds),
-- completely decoupled from the bot's own rig + lifecycle — so it can never affect game
-- state or the respawn. Being server-made, it replicates to every client.
local function socketJoint(partA: BasePart, posA: Vector3, partB: BasePart, posB: Vector3)
	local a0 = Instance.new("Attachment")
	a0.Position = posA
	a0.Parent = partA
	local a1 = Instance.new("Attachment")
	a1.Position = posB
	a1.Parent = partB
	local bs = Instance.new("BallSocketConstraint")
	bs.Attachment0 = a0
	bs.Attachment1 = a1
	bs.LimitsEnabled = true
	bs.UpperAngle = 60
	bs.Parent = partA
end

function BotService:_spawnCorpse(bot: Bot)
	local src = bot.model
	local corpse = Instance.new("Model")
	corpse.Name = "Corpse"
	local parts: { [string]: BasePart } = {}
	for _, name in { "Torso", "Head", "LeftLeg", "RightLeg" } do
		local orig = src:FindFirstChild(name)
		if orig and orig:IsA("BasePart") then
			local clone = orig:Clone()
			-- Strip welds / name-tag / attachments so the clone is a free physics body.
			for _, child in clone:GetChildren() do
				child:Destroy()
			end
			clone.Anchored = false
			clone.CanCollide = true
			clone.Parent = corpse
			parts[name] = clone
		end
	end
	if parts.Torso == nil then
		return
	end
	corpse.PrimaryPart = parts.Torso
	corpse.Parent = workspace
	if parts.Head then
		socketJoint(parts.Torso, Vector3.new(0, 1, 0), parts.Head, Vector3.new(0, -0.6, 0))
	end
	if parts.LeftLeg then
		socketJoint(parts.Torso, Vector3.new(-0.5, -1, 0), parts.LeftLeg, Vector3.new(0, 1, 0))
	end
	if parts.RightLeg then
		socketJoint(parts.Torso, Vector3.new(0.5, -1, 0), parts.RightLeg, Vector3.new(0, 1, 0))
	end
	-- Flop it: a little pop + spin.
	parts.Torso.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-12, 12), 18, rng:NextNumber(-12, 12))
	parts.Torso.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), 0)
	-- Green death puff.
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(90, 200, 60))
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Parent = parts.Torso
	emitter:Emit(24)
	Debris:AddItem(corpse, 5)
end

function BotService:_onBotDied(bot: Bot)
	-- Zombie bots respawn near the action; keeps the horde pressure up.
	if not self._active or bot.role ~= "ZOMBIE" then
		return
	end
	-- Fling a ragdoll corpse and hide the real rig until it respawns.
	self:_spawnCorpse(bot)
	for _, part in bot.model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Transparency = 1
		end
	end
	task.delay(GameConfig.Round.ZombieRespawnSeconds, function()
		if not self._active or self._bots[bot.id] == nil then
			return
		end
		local roots = {}
		for _, survivor in self._deps.getHumanSurvivors() do
			local char = survivor.Character
			local r = char and char:FindFirstChild("HumanoidRootPart")
			if r and r:IsA("BasePart") then
				table.insert(roots, r)
			end
		end
		local spawnCFrame = self._deps.getZombieSpawn(roots) or CFrame.new(0, 5, 0)
		bot.root.CFrame = spawnCFrame + Vector3.new(0, 3, 0)
		bot.humanoid.Health = bot.humanoid.MaxHealth
		-- Restore the rig now that the corpse has flopped away.
		for _, part in bot.model:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Transparency = 0
			end
		end
	end)
end

-- AI ----------------------------------------------------------------------------

-- All alive survivor targets (human + bot) as {position, player?, model}.
type Target = { pos: Vector3, player: Player?, model: Model, root: BasePart }

function BotService:_survivorTargets(): { Target }
	local out: { Target } = {}
	for _, survivor in self._deps.getHumanSurvivors() do
		local char = survivor.Character
		local r = char and char:FindFirstChild("HumanoidRootPart")
		if char and r and r:IsA("BasePart") then
			table.insert(out, { pos = r.Position, player = survivor, model = char, root = r })
		end
	end
	for _, bot in self._bots do
		if bot.role == "SURVIVOR" and bot.humanoid.Health > 0 then
			table.insert(out, { pos = bot.root.Position, player = nil, model = bot.model, root = bot.root })
		end
	end
	return out
end

-- Visible infected the survivor bots are allowed to react to: ZOMBIE players and
-- zombie bots. The hidden Patient Zero is deliberately excluded — reacting to it would
-- leak the mind-game.
function BotService:_visibleThreats(): { BasePart }
	local out: { BasePart } = {}
	for _, bot in self._bots do
		if bot.role == "ZOMBIE" and bot.humanoid.Health > 0 then
			table.insert(out, bot.root)
		end
	end
	for _, root in self._deps.getInfectedPlayerRoots() do
		table.insert(out, root)
	end
	return out
end

-- Clear line of sight from a bot's eye to a world point (ignores the bot's own body).
function BotService:_lineOfSight(bot: Bot, targetPos: Vector3): boolean
	local eye = bot.root.Position + Vector3.new(0, 1.5, 0)
	local delta = targetPos - eye
	local dist = delta.Magnitude
	if dist > GameConfig.Bots.SightRange then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { bot.model }
	local result = workspace:Raycast(eye, delta, params)
	if result == nil then
		return true
	end
	-- Something was hit; treat as visible only if it's basically at the target.
	return (result.Position - targetPos).Magnitude < 5
end

-- Compute a fresh path toward `goal` off the hot loop (ComputeAsync yields).
function BotService:_computePath(bot: Bot, goal: Vector3)
	if bot.computing then
		return
	end
	bot.computing = true
	bot.navGoal = goal
	bot.lastRepath = os.clock()
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = GameConfig.Bots.AgentRadius,
			AgentHeight = GameConfig.Bots.AgentHeight,
			AgentCanJump = true,
		})
		local ok = pcall(function()
			path:ComputeAsync(bot.root.Position, goal)
		end)
		bot.computing = false
		if not self._active or self._bots[bot.id] == nil then
			return
		end
		if ok and path.Status == Enum.PathStatus.Success then
			bot.path = path
			bot.waypoints = path:GetWaypoints()
			bot.waypointIndex = 2 -- skip [1] (the bot's current position)
		else
			-- No path: clear so the caller falls back to a direct move.
			bot.path = nil
			bot.waypoints = {}
			bot.waypointIndex = 1
		end
	end)
end

-- Follow the current waypoint list; returns false if there is nothing to follow.
function BotService:_followPath(bot: Bot): boolean
	local waypoints = bot.waypoints
	if #waypoints == 0 or bot.waypointIndex > #waypoints then
		return false
	end
	local wp = waypoints[bot.waypointIndex]
	local flat = Vector3.new(wp.Position.X - bot.root.Position.X, 0, wp.Position.Z - bot.root.Position.Z)
	if flat.Magnitude < GameConfig.Bots.WaypointReached then
		bot.waypointIndex += 1
		if bot.waypointIndex > #waypoints then
			return false
		end
		wp = waypoints[bot.waypointIndex]
	end
	if wp.Action == Enum.PathWaypointAction.Jump then
		bot.humanoid.Jump = true
	end
	bot.humanoid:MoveTo(wp.Position)
	return true
end

-- Drive the bot toward `goal`, recomputing the path only when worthwhile, and recovering
-- from getting wedged on geometry.
function BotService:_navigateTo(bot: Bot, goal: Vector3, now: number, speed: number)
	bot.humanoid.WalkSpeed = speed

	-- Stuck detection: barely moved since the last check while we still have distance to go.
	if now - bot.lastMoveCheck > 0.4 then
		local moved = (bot.root.Position - bot.lastPos).Magnitude
		local movedSpeed = moved / math.max(0.001, now - bot.lastMoveCheck)
		bot.lastPos = bot.root.Position
		bot.lastMoveCheck = now
		if movedSpeed < GameConfig.Bots.StuckSpeed and (goal - bot.root.Position).Magnitude > 6 then
			bot.stuckSince = bot.stuckSince or now
			if now - (bot.stuckSince :: number) > GameConfig.Bots.StuckRepathAfter then
				bot.humanoid.Jump = true
				bot.stuckSince = nil
				bot.navGoal = nil -- force a repath below
			end
		else
			bot.stuckSince = nil
		end
	end

	local needRepath = bot.navGoal == nil
		or (goal - (bot.navGoal :: Vector3)).Magnitude > GameConfig.Bots.RepathDistance
		or (now - bot.lastRepath > GameConfig.Bots.RepathInterval and bot.waypointIndex > #bot.waypoints)
	if needRepath then
		self:_computePath(bot, goal)
	end

	if not self:_followPath(bot) then
		-- Fallback while a path is still computing or unavailable: head straight there.
		bot.humanoid:MoveTo(goal)
	end
end

-- Survivor bots shoot VISIBLE zombie bots (and only those — see _visibleThreats). Purely
-- to make the battlefield feel alive; damage is applied without crediting any player.
function BotService:_survivorGunfire(bot: Bot, now: number)
	if now < bot.nextShotAt then
		return
	end
	local target: BasePart? = nil
	local bestDist = GameConfig.Bots.ShootRange
	for _, threatRoot in self:_visibleThreats() do
		local d = (threatRoot.Position - bot.root.Position).Magnitude
		if d < bestDist and self:_lineOfSight(bot, threatRoot.Position) then
			target, bestDist = threatRoot, d
		end
	end
	if target == nil then
		bot.aimingSince = nil
		return
	end
	-- Human-like: take a beat to "aim" before the first shot.
	if bot.aimingSince == nil then
		bot.aimingSince = now
			+ rng:NextNumber(GameConfig.Bots.ShootReactionMin, GameConfig.Bots.ShootReactionMax)
				* bot.difficulty.reactionMult
		return
	end
	if now < (bot.aimingSince :: number) then
		return
	end
	bot.nextShotAt = now + GameConfig.Bots.ShootInterval
	local origin = bot.root.Position + Vector3.new(0, 1.5, 0)
	local direction = (target.Position - origin).Unit
	self._deps.remotes.fireAllClients("ShotFired", {
		shooterUserId = -bot.id, -- negative id marks a bot shooter (no real player)
		origin = origin,
		direction = direction,
		weaponId = "AssaultRifle",
	})
	-- Accuracy roll: some shots visibly miss.
	if rng:NextNumber(0, 1) <= GameConfig.Bots.ShootAccuracy then
		local victim = self:_botFromCharacter(target.Parent :: Instance)
		if victim and victim.role == "ZOMBIE" then
			victim.humanoid:TakeDamage(GameConfig.Combat.Guns.AssaultRifle.Damage)
		end
	end
end

-- Pick a target for the Patient Zero: the most isolated survivor (fewest neighbours),
-- so the hidden infected stalks stragglers instead of charging the pack.
function BotService:_isolatedTarget(targets: { Target }): Target?
	local best: Target? = nil
	local bestScore = math.huge
	for _, t in targets do
		local neighbours = 0
		for _, other in targets do
			if other ~= t and (other.pos - t.pos).Magnitude < GameConfig.Bots.GroupRadius then
				neighbours += 1
			end
		end
		if neighbours < bestScore then
			best, bestScore = t, neighbours
		end
	end
	return best
end

function BotService:_stepBot(bot: Bot, now: number)
	if bot.humanoid.Health <= 0 then
		return
	end
	local pos = bot.root.Position

	if bot.role == "SURVIVOR" then
		self:_survivorGunfire(bot, now)

		-- Flee the nearest visible threat if it's close.
		local threat: BasePart? = nil
		local threatDist = GameConfig.Bots.FleeRadius
		for _, threatRoot in self:_visibleThreats() do
			local d = (threatRoot.Position - pos).Magnitude
			if d < threatDist and self:_lineOfSight(bot, threatRoot.Position) then
				threat, threatDist = threatRoot, d
			end
		end
		if threat then
			local away = (pos - (threat :: BasePart).Position)
			away = Vector3.new(away.X, 0, away.Z)
			local flee = pos + (away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)) * 30
			self:_navigateTo(
				bot,
				flee,
				now,
				bot.baseSpeed * GameConfig.Movement.SprintWalkSpeed / GameConfig.Movement.BaseWalkSpeed
			)
			return
		end

		-- Otherwise behave by personality.
		local reached = bot.wanderTarget == nil or (bot.wanderTarget - pos).Magnitude < 8
		if bot.personality == "grouper" then
			-- Drift toward the centroid of nearby survivors.
			local sum, count = Vector3.zero, 0
			for _, t in self:_survivorTargets() do
				if t.root ~= bot.root and (t.pos - pos).Magnitude < GameConfig.Bots.GroupRadius then
					sum += t.pos
					count += 1
				end
			end
			if count > 0 then
				bot.wanderTarget = sum / count
			elseif reached then
				local spawn = self._deps.getSurvivorSpawn()
				bot.wanderTarget = spawn and spawn.Position
					or (pos + Vector3.new(rng:NextNumber(-24, 24), 0, rng:NextNumber(-24, 24)))
			end
		elseif reached then
			local spawn = self._deps.getSurvivorSpawn()
			local spread = bot.personality == "cautious" and 16 or 34
			bot.wanderTarget = spawn and spawn.Position
				or (pos + Vector3.new(rng:NextNumber(-spread, spread), 0, rng:NextNumber(-spread, spread)))
		end
		self:_navigateTo(bot, bot.wanderTarget or pos, now, bot.baseSpeed)
	else
		-- Infected: chase (PZ stalks the most isolated survivor) and convert on contact.
		local targets = self:_survivorTargets()
		local target: Target? = if bot.role == "PATIENT_ZERO" then self:_isolatedTarget(targets) else nil
		if target == nil then
			local bestDist = math.huge
			for _, t in targets do
				local d = (t.pos - pos).Magnitude
				if d < bestDist then
					target, bestDist = t, d
				end
			end
		end
		if target then
			local chaseSpeed = GameConfig.Movement.BaseWalkSpeed
				* (if bot.role == "PATIENT_ZERO" then GameConfig.Combat.PatientZero.SprintMult else 1)
				* bot.difficulty.speedMult
			self:_navigateTo(bot, (target :: Target).pos, now, chaseSpeed)
			local range = GameConfig.Combat.Zombie.MeleeRange
			local reactionGate = 1 * bot.difficulty.reactionMult
			if ((target :: Target).pos - pos).Magnitude <= range and now - bot.lastAction > reactionGate then
				bot.lastAction = now
				local t = target :: Target
				if t.player then
					self._deps.convertHuman(t.player)
				else
					self:convertBot(t.model, nil)
				end
			end
		end
	end
end

function BotService:start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < GameConfig.Bots.ThinkInterval then
			return
		end
		accumulator = 0
		if not self._active then
			return
		end
		local now = os.clock()
		for _, bot in self._bots do
			self:_stepBot(bot, now)
		end
	end)
end

return BotService
