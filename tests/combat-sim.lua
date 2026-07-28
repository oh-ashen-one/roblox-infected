-- Headless combat simulation. Injected by run-in-roblox.
--
-- Boot checks prove the code loads; they prove nothing about whether the game still WORKS.
-- The Phase 2 rewrite replaced one-touch zombie conversion with a telegraphed wind-up, and
-- replaced a coin-flip damage roll with a real spread cone and raycast. Either change could
-- silently make the round unwinnable for one side, and no unit test can see that.
--
-- This drives BotService directly with stub dependencies (no human player required) and
-- watches what actually happens over a simulated round.

-- Tunable by a wrapper script that sets these globals before requiring this file.
local SIM_SECONDS = _G.SIM_SECONDS
local SIM_BOTS = _G.SIM_BOTS
local SIM_HUNTERS = _G.SIM_HUNTERS

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

RunService:Run()
task.wait(3)

local serverFolder = ServerScriptService:WaitForChild("Server")
local BotService = require(serverFolder.Services.BotService)

-- Put a real map down so bots have somewhere to path.
local maps = ServerStorage:WaitForChild("Maps", 20)
local existing = workspace:FindFirstChild("ActiveMap")
if existing then
	existing:Destroy()
end
local mapModel = maps:GetChildren()[1]:Clone()
mapModel.Name = "ActiveMap"
mapModel.Parent = workspace
task.wait(2)
print("[SIM] map:", mapModel.Name)

local survivorSpawns = mapModel.SurvivorSpawns:GetChildren()
local patrolPoints = mapModel.PatrolPoints:GetChildren()

local conversions = 0
local countsChanged = 0

local service = BotService.new({
	remotes = {
		fireAllClients = function() end,
		fireClient = function() end,
		onValidated = function() end,
	},
	getSurvivorSpawn = function()
		local pick = survivorSpawns[math.random(1, #survivorSpawns)]
		return CFrame.new(pick.Position)
	end,
	getZombieSpawn = function()
		local pick = survivorSpawns[math.random(1, #survivorSpawns)]
		return CFrame.new(pick.Position)
	end,
	getHumanSurvivors = function()
		return {}
	end,
	getInfectedPlayerRoots = function()
		return {}
	end,
	convertHuman = function() end,
	onBotKilledByHuman = function() end,
	onBotConvertedByHuman = function() end,
	onConversionOccurred = function()
		conversions += 1
	end,
	onCountsChanged = function()
		countsChanged += 1
	end,
	getPatrolPoint = function()
		if #patrolPoints == 0 then
			return nil
		end
		return patrolPoints[math.random(1, #patrolPoints)].Position
	end,
})

service:spawnForRound(SIM_BOTS or 8, { botIsPZ = false })
service:start()
task.wait(1)

-- Force one bot infected so there is a hunter, mirroring how a round begins.
local ids = {}
for id in service._bots do
	table.insert(ids, id)
end
table.sort(ids)
local hunters = SIM_HUNTERS or 1
for i = 1, math.min(hunters, #ids) do
	service:_applyRole(service._bots[ids[i]], "ZOMBIE")
end
print(("[SIM] spawned=%d hunters=%d horizon=%ds"):format(#ids, hunters, SIM_SECONDS or 45))

-- Observe.
local startSurvivors = service:survivorCount()
local moved, animated = 0, 0
local startPositions = {}
for id, bot in service._bots do
	startPositions[id] = bot.root.Position
end

local simStart = os.clock()
local lastReported = -1
local deadline = os.clock() + (SIM_SECONDS or 45)
local statesSeen = {}
while os.clock() < deadline do
	task.wait(1)
	for _, bot in service._bots do
		if bot.brain and bot.brain.state then
			statesSeen[bot.brain.state] = (statesSeen[bot.brain.state] or 0) + 1
		end
	end
	local remaining = service:survivorCount()
	if remaining ~= lastReported then
		print(("[SIM] t=%ds survivors=%d"):format(math.floor(os.clock() - simStart), remaining))
		lastReported = remaining
	end
	if remaining == 0 then
		break
	end
end

for id, bot in service._bots do
	if startPositions[id] and (bot.root.Position - startPositions[id]).Magnitude > 8 then
		moved += 1
	end
	local humanoid = bot.humanoid
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator and #animator:GetPlayingAnimationTracks() > 0 then
		animated += 1
	end
end

local endSurvivors = service:survivorCount()
print(("[SIM] survivors %d -> %d (converted %d)"):format(startSurvivors, endSurvivors, conversions))
print(("[SIM] bots that moved: %d/%d, animating: %d/%d"):format(moved, #ids, animated, #ids))
local stateList = {}
for state, n in statesSeen do
	table.insert(stateList, ("%s=%d"):format(state, n))
end
table.sort(stateList)
print("[SIM] brain states observed: " .. table.concat(stateList, " "))

-- The two things that would silently break the game.
local convertsWork = conversions > 0 or endSurvivors < startSurvivors
local botsAreAlive = moved >= math.floor(#ids / 2)

print("[SIM] zombies can convert:", convertsWork and "YES" or "NO -- ROUNDS WOULD NEVER END")
print("[SIM] bots actually move:", botsAreAlive and "YES" or "NO")
print("[SIM] VERDICT:", (convertsWork and botsAreAlive) and "PASS" or "FAIL")
