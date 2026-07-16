--!strict
-- Client combat input + immediate cosmetic feedback. The server is the only
-- authority on damage; everything here is input capture and visuals.
--   Survivor / hidden PZ blending in: LMB fire gun, R reload, Shift sprint
--   Patient Zero: F (or LMB with knife out, mobile button) throws the knife
--   Zombie / PZ: LMB near a survivor = melee
-- Touch controls come in Phase 5; keyboard+mouse first.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)

local LocalPlayer = Players.LocalPlayer

local CombatController = {}

local state = {
	role = "NONE" :: string,
	primary = "AssaultRifle" :: string,
	sprinting = false,
}

local function myOriginAndDirection(): (Vector3?, Vector3?)
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil, nil
	end
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	return root.Position + Vector3.new(0, 1.5, 0), ray.Direction.Unit
end

local function nearestSurvivorTarget(maxRange: number): number?
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local best: Player? = nil
	local bestDist = maxRange
	for _, other in Players:GetPlayers() do
		if other ~= LocalPlayer and other.Character then
			local otherRoot = other.Character:FindFirstChild("HumanoidRootPart")
			if otherRoot and otherRoot:IsA("BasePart") then
				local d = (otherRoot.Position - root.Position).Magnitude
				if d < bestDist then
					best = other
					bestDist = d
				end
			end
		end
	end
	return best and best.UserId or nil
end

-- Cosmetic tracer so shots feel instant (server re-simulates the real hit)
local function drawTracer(origin: Vector3, direction: Vector3, range: number)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 220, 120)
	local length = math.min(range, 100)
	part.Size = Vector3.new(0.08, 0.08, length)
	part.CFrame = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -length / 2)
	part.Parent = workspace
	Debris:AddItem(part, 0.06)
end

function CombatController.start(remotes: any)
	local actions = {}

	function actions.fire()
		local origin, direction = myOriginAndDirection()
		if origin == nil or direction == nil then
			return
		end
		if state.role == "SURVIVOR" or state.role == "PATIENT_ZERO" then
			local spec = (GameConfig.Combat.Guns :: any)[state.primary]
			drawTracer(origin, direction, spec.Range)
			remotes.fire("FireWeapon", { origin = origin, direction = direction, weaponId = state.primary })
		end
	end

	function actions.throwKnife()
		local origin, direction = myOriginAndDirection()
		if origin and direction and state.role == "PATIENT_ZERO" then
			remotes.fire("ThrowKnife", { origin = origin, direction = direction })
		end
	end

	function actions.melee()
		local target = nearestSurvivorTarget(GameConfig.Combat.Zombie.MeleeRange)
		if target then
			remotes.fire("MeleeAttack", { targetUserId = target })
		end
	end

	function actions.reload()
		remotes.fire("Reload", { weaponId = state.primary })
	end

	function actions.setSprint(on: boolean)
		state.sprinting = on
		remotes.fire("SprintState", { sprinting = on and "on" or "off" })
	end

	remotes.on("RoleAssigned", function(payload)
		state.role = payload.role
	end)

	remotes.on("ProfileSync", function(profile)
		if profile.loadout and profile.loadout.primary then
			state.primary = profile.loadout.primary
		end
	end)

	remotes.on("ShotFired", function(payload)
		if payload.shooterUserId ~= LocalPlayer.UserId then
			drawTracer(payload.origin, payload.direction, 100)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if state.role == "ZOMBIE" then
				actions.melee()
			else
				actions.fire()
			end
		elseif input.KeyCode == Enum.KeyCode.F and state.role == "PATIENT_ZERO" then
			actions.throwKnife()
		elseif input.KeyCode == Enum.KeyCode.E and state.role == "PATIENT_ZERO" then
			actions.melee()
		elseif input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonX then
			actions.reload()
		elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
			actions.setSprint(true)
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			-- Gamepad: trigger fires / claws depending on role
			if state.role == "ZOMBIE" then
				actions.melee()
			else
				actions.fire()
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
			if state.role == "PATIENT_ZERO" then
				actions.throwKnife()
			else
				actions.melee()
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if
			(input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3)
			and state.sprinting
		then
			actions.setSprint(false)
		end
	end)

	return actions
end

return CombatController
