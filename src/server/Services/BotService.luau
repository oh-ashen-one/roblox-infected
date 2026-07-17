--!strict
-- Server-controlled bots so a solo player can experience a full round. Bots are
-- lightweight NPC rigs (no avatar assets) with a Humanoid, so the existing combat
-- raycasts hit them and Humanoid:MoveTo drives their AI. They fill the lobby to a
-- target headcount, get assigned roles alongside the human, wander / hunt / convert,
-- and are cleaned up at round end.
--
-- Bot characters are tagged with attributes the combat + AI code reads:
--   IsBot   = true
--   BotRole = "SURVIVOR" | "PATIENT_ZERO" | "ZOMBIE"

local RunService = game:GetService("RunService")
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

type Bot = {
	id: number,
	name: string,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	role: string,
	wanderTarget: Vector3?,
	lastAction: number,
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
		local bot: Bot = {
			id = id,
			name = name,
			model = model,
			humanoid = humanoid,
			root = root,
			role = "SURVIVOR",
			wanderTarget = nil,
			lastAction = 0,
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
	self._deps.remotes.fireAllClients("ConversionAlert", {
		victimName = bot.name,
		killerName = attacker and attacker.DisplayName or nil,
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

function BotService:_onBotDied(bot: Bot)
	-- Zombie bots respawn near the action; keeps the horde pressure up.
	if not self._active or bot.role ~= "ZOMBIE" then
		return
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
	end)
end

-- AI ----------------------------------------------------------------------------

local function nearestSurvivorTarget(self, fromPos: Vector3): (BasePart?, Player?)
	local best: BasePart? = nil
	local bestPlayer: Player? = nil
	local bestDist = math.huge
	for _, survivor in self._deps.getHumanSurvivors() do
		local char = survivor.Character
		local r = char and char:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") then
			local d = (r.Position - fromPos).Magnitude
			if d < bestDist then
				best, bestPlayer, bestDist = r, survivor, d
			end
		end
	end
	for _, bot in self._bots do
		if bot.role == "SURVIVOR" and bot.humanoid.Health > 0 then
			local d = (bot.root.Position - fromPos).Magnitude
			if d < bestDist then
				best, bestPlayer, bestDist = bot.root, nil, d
			end
		end
	end
	return best, bestPlayer
end

function BotService:_stepBot(bot: Bot, now: number)
	if bot.humanoid.Health <= 0 then
		return
	end
	local pos = bot.root.Position

	if bot.role == "SURVIVOR" then
		-- Wander to random points; flee if an infected is very close.
		if bot.wanderTarget == nil or (bot.wanderTarget - pos).Magnitude < 6 then
			local spawnCFrame = self._deps.getSurvivorSpawn()
			bot.wanderTarget = spawnCFrame and spawnCFrame.Position
				or (pos + Vector3.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30)))
		end
		bot.humanoid:MoveTo(bot.wanderTarget :: Vector3)
	else
		-- Infected: chase nearest survivor and convert on contact.
		local target, targetPlayer = nearestSurvivorTarget(self, pos)
		if target then
			bot.humanoid:MoveTo(target.Position)
			local range = GameConfig.Combat.Zombie.MeleeRange
			if (target.Position - pos).Magnitude <= range and now - bot.lastAction > 1 then
				bot.lastAction = now
				if targetPlayer then
					self._deps.convertHuman(targetPlayer)
				else
					local victimModel = target.Parent
					if victimModel and victimModel:IsA("Model") then
						self:convertBot(victimModel, nil)
					end
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
