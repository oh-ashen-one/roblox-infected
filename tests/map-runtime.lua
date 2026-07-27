-- Map runtime check. Injected by run-in-roblox.
--
-- Geometry that compiles can still be unplayable: spawns buried inside walls, stairs the
-- navmesh refuses, floors with no floor. This builds each map for real and checks the
-- things a unit test cannot see.

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local PathfindingService = game:GetService("PathfindingService")

print("[MAPS] runtime check started")

local errorCount = 0
game:GetService("ScriptContext").Error:Connect(function(message)
	errorCount += 1
	print("[MAPS] SCRIPT ERROR:", message)
end)

RunService:Run()
task.wait(3)

local mapsFolder = ServerStorage:WaitForChild("Maps", 20)
if mapsFolder == nil then
	print("[MAPS] Maps folder MISSING")
	print("[MAPS] VERDICT: FAIL")
	return
end

local allOk = true
local built = mapsFolder:GetChildren()
print(("[MAPS] maps built: %d"):format(#built))

for _, map in built do
	local parts, lights, signs = 0, 0, 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		elseif d:IsA("PointLight") then
			lights += 1
		elseif d:IsA("SurfaceGui") then
			signs += 1
		end
	end

	local survivors = map:FindFirstChild("SurvivorSpawns")
	local zombies = map:FindFirstChild("ZombieSpawns")
	local patrols = map:FindFirstChild("PatrolPoints")
	local sv = survivors and #survivors:GetChildren() or 0
	local zo = zombies and #zombies:GetChildren() or 0
	local pa = patrols and #patrols:GetChildren() or 0

	print(
		("[MAPS] %s: parts=%d lights=%d signs=%d spawns=%d/%d patrol=%d"):format(
			map.Name,
			parts,
			lights,
			signs,
			sv,
			zo,
			pa
		)
	)

	if sv < 20 or zo < 2 then
		allOk = false
		print(("[MAPS] %s BAD: not enough spawns"):format(map.Name))
	end
	if pa < 5 then
		allOk = false
		print(("[MAPS] %s BAD: too few patrol points (bots would clump)"):format(map.Name))
	end
	if parts < 300 then
		allOk = false
		print(("[MAPS] %s BAD: only %d parts, still a grey box"):format(map.Name, parts))
	end
end

-- Live traversal test on the map that is actually loaded: can the navmesh get from a
-- survivor spawn to a zombie spawn, and does it use the new verticality?
local active = workspace:FindFirstChild("ActiveMap")
if active then
	local sv = active:FindFirstChild("SurvivorSpawns")
	local zo = active:FindFirstChild("ZombieSpawns")
	local svSpawns = sv and sv:GetChildren() or {}
	local zoSpawns = zo and zo:GetChildren() or {}

	local reachable, attempted, maxRise = 0, 0, 0
	for i = 1, math.min(8, #svSpawns) do
		local from = svSpawns[i]
		local to = zoSpawns[((i - 1) % math.max(1, #zoSpawns)) + 1]
		if from and to then
			attempted += 1
			local path = PathfindingService:CreatePath({
				AgentRadius = 2,
				AgentHeight = 5,
				AgentCanJump = true,
			})
			local ok = pcall(function()
				path:ComputeAsync(from.Position, to.Position)
			end)
			if ok and path.Status == Enum.PathStatus.Success then
				reachable += 1
				local lowest, highest = math.huge, -math.huge
				for _, wp in path:GetWaypoints() do
					lowest = math.min(lowest, wp.Position.Y)
					highest = math.max(highest, wp.Position.Y)
				end
				maxRise = math.max(maxRise, highest - lowest)
			end
		end
	end
	print(
		("[MAPS] active=%s pathable=%d/%d maxVerticalRise=%.1f"):format(
			active.Name,
			reachable,
			attempted,
			maxRise
		)
	)
	if attempted > 0 and reachable < attempted * 0.75 then
		allOk = false
		print("[MAPS] BAD: most spawns cannot path to a zombie spawn")
	end
else
	allOk = false
	print("[MAPS] no ActiveMap loaded")
end

print(("[MAPS] errors=%d"):format(errorCount))
print("[MAPS] VERDICT:", (allOk and errorCount == 0) and "PASS" or "FAIL")
