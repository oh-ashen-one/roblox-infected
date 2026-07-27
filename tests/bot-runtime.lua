-- Bot runtime check. Injected by run-in-roblox.
--
-- The unit tests cover the brain and perception maths, but the things most likely to break
-- a bot are engine-side: does the avatar rig actually build, does it get an Animator, do the
-- animation tracks play, and does a bot physically move. This boots a real round with bots
-- and observes them.

local RunService = game:GetService("RunService")

print("[BOTS] runtime check started")

local errorCount = 0
game:GetService("ScriptContext").Error:Connect(function(message)
	errorCount += 1
	print("[BOTS] SCRIPT ERROR:", message)
end)

RunService:Run()
task.wait(3)

-- Reach into the running server to spawn bots directly; with no human player the round
-- machine won't start one on its own.
-- Build rigs the same way BotService does.
local serverFolder = game:GetService("ServerScriptService"):FindFirstChild("Server")
local rigModule = serverFolder and serverFolder:FindFirstChild("Bots")
rigModule = rigModule and rigModule:FindFirstChild("Rig")
if rigModule == nil then
	print("[BOTS] Rig module MISSING")
	print("[BOTS] VERDICT: FAIL")
	return
end
local Rig = require(rigModule)

local rng = Random.new()
local built, animated, moved = 0, 0, 0
local rigs = {}

for i = 1, 4 do
	local ok, m, h, r = pcall(Rig.build, "ProbeBot" .. i, rng)
	if not ok then
		print("[BOTS] rig build FAILED:", tostring(m))
	else
		m.Parent = workspace
		r.CFrame = CFrame.new(i * 8, 10, 0)
		built += 1

		local isR15 = h.RigType == Enum.HumanoidRigType.R15
		print(
			("[BOTS] rig %d: %s parts=%d rigType=%s"):format(
				i,
				m.Name,
				#m:GetChildren(),
				isR15 and "R15" or "R6"
			)
		)

		local animOk = pcall(Rig.animate, h, rng)
		local animator = h:FindFirstChildOfClass("Animator")
		if animOk and animator then
			animated += 1
			local playing = animator:GetPlayingAnimationTracks()
			print(("[BOTS] rig %d: animator ok, %d track(s) playing"):format(i, #playing))
		else
			print(("[BOTS] rig %d: ANIMATION FAILED"):format(i))
		end
		table.insert(rigs, { model = m, humanoid = h, root = r, start = r.Position })
	end
end

-- Walk them and confirm the Humanoid actually drives the body.
for _, entry in rigs do
	entry.humanoid:MoveTo(entry.root.Position + Vector3.new(0, 0, 25))
end
task.wait(4)
for i, entry in rigs do
	local dist = (entry.root.Position - entry.start).Magnitude
	if dist > 3 then
		moved += 1
	end
	print(("[BOTS] rig %d: moved %.1f studs"):format(i, dist))
end

print(("[BOTS] built=%d animated=%d moved=%d errors=%d"):format(built, animated, moved, errorCount))

local pass = built == 4 and animated == 4 and moved >= 3 and errorCount == 0
print("[BOTS] VERDICT:", pass and "PASS" or "FAIL")
