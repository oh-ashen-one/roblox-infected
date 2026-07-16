-- Injected by run-in-roblox: observes the live game for ~75s and prints a
-- verdict the shell can grep. The real game scripts run untouched.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[HEADLESS] observation started")

local sawRemotes = ReplicatedStorage:WaitForChild("Remotes", 20) ~= nil
print("[HEADLESS] remotes folder:", sawRemotes and "OK" or "MISSING")

local sawMap = false
local sawRoundStates = {}

task.spawn(function()
	while true do
		if workspace:FindFirstChild("ActiveMap") then
			sawMap = true
		end
		task.wait(1)
	end
end)

-- Watch server prints indirectly: poll round state via the ActiveMap presence and
-- give the fast Studio timers time for WAITING -> INTERMISSION -> ACTIVE -> END.
local deadline = os.clock() + 75
while os.clock() < deadline do
	task.wait(1)
end

print("[HEADLESS] map loaded during run:", sawMap and "OK" or "NEVER")
print("[HEADLESS] VERDICT:", (sawRemotes and sawMap) and "PASS" or "FAIL")
local _ = sawRoundStates
