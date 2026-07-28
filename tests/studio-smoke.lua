-- Injected by run-in-roblox. run-in-roblox opens the place in EDIT mode, so we must
-- RunService:Run() to actually boot the server scripts, then observe that the game comes
-- up cleanly: Remotes created, a lobby map loaded, no boot-time script errors. With 0
-- players a full round can't start (needs a human for bots to fill around), so this is a
-- boot/regression smoke check, not a round test. It prints a verdict the shell greps.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")

print("[HEADLESS] boot-check started")

local errorCount = 0
ScriptContext.Error:Connect(function(message)
	errorCount += 1
	print("[HEADLESS] SCRIPT ERROR:", message)
end)

-- Boot the game scripts.
RunService:Run()

local sawRemotes = ReplicatedStorage:WaitForChild("Remotes", 25) ~= nil
print("[HEADLESS] remotes folder:", sawRemotes and "OK" or "MISSING")

-- Give the boot + lobby load a moment.
local sawMap = false
local deadline = os.clock() + 20
while os.clock() < deadline do
	if workspace:FindFirstChild("ActiveMap") then
		sawMap = true
		break
	end
	task.wait(0.5)
end
print("[HEADLESS] lobby map loaded:", sawMap and "OK" or "NEVER")

-- Let any deferred boot work settle so late errors surface.
task.wait(5)
print("[HEADLESS] script errors during boot:", errorCount)

-- Validate every built map has survivor + zombie spawn markers (catches a malformed map).
local ServerStorage = game:GetService("ServerStorage")
local mapsOk = true
local mapsFolder = ServerStorage:FindFirstChild("Maps")
if mapsFolder then
	for _, mapModel in mapsFolder:GetChildren() do
		local sv = mapModel:FindFirstChild("SurvivorSpawns")
		local zo = mapModel:FindFirstChild("ZombieSpawns")
		local svCount = sv and #sv:GetChildren() or 0
		local zoCount = zo and #zo:GetChildren() or 0
		if svCount == 0 or zoCount == 0 then
			mapsOk = false
			print(
				("[HEADLESS] MAP %s BAD: survivorSpawns=%d zombieSpawns=%d"):format(
					mapModel.Name,
					svCount,
					zoCount
				)
			)
		else
			print(
				("[HEADLESS] map %s: %d survivor / %d zombie spawns"):format(mapModel.Name, svCount, zoCount)
			)
		end
	end
else
	mapsOk = false
	print("[HEADLESS] Maps folder MISSING")
end

-- Load every client module. There is no LocalPlayer in a headless boot so we cannot run the
-- client, but requiring each module still catches the failure that actually bites: a bad
-- require path or a load-time error in code that otherwise ships completely unexercised.
local StarterPlayer = game:GetService("StarterPlayer")
local clientOk = true
local clientRoot = StarterPlayer:FindFirstChild("StarterPlayerScripts")
clientRoot = clientRoot and clientRoot:FindFirstChild("Client")
if clientRoot then
	local loaded = 0
	for _, module in clientRoot:GetDescendants() do
		if module:IsA("ModuleScript") then
			local ok, err = pcall(require, module)
			if ok then
				loaded += 1
			else
				clientOk = false
				print(("[HEADLESS] CLIENT MODULE FAILED %s: %s"):format(module:GetFullName(), tostring(err)))
			end
		end
	end
	print(("[HEADLESS] client modules loaded: %d"):format(loaded))
else
	clientOk = false
	print("[HEADLESS] client folder MISSING")
end

local pass = sawRemotes and sawMap and errorCount == 0 and mapsOk and clientOk
print("[HEADLESS] VERDICT:", pass and "PASS" or "FAIL")
