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

local pass = sawRemotes and sawMap and errorCount == 0
print("[HEADLESS] VERDICT:", pass and "PASS" or "FAIL")
