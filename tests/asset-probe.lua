-- Asset availability probe. Injected by run-in-roblox.
--
-- We want to use free/first-party Roblox content (default animations, avatar bodies, stock
-- meshes) rather than shipping more grey boxes. But a wrong or private asset id renders as
-- nothing, and there is no way to tell from source. This asks the actual engine which ids
-- resolve, so the game only ever ships assets that were observed to load.
--
-- Output lines are machine-greppable: "PROBE <category> <id> OK|FAIL <detail>"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local InsertService = game:GetService("InsertService")

RunService:Run()
task.wait(2)

local function report(category, id, ok, detail)
	print(("PROBE %s %s %s %s"):format(category, tostring(id), ok and "OK" or "FAIL", tostring(detail or "")))
end

-- 1. Default R15 animation set -------------------------------------------------------
-- Candidate ids for Roblox's stock animation package. Loading a track and reading a
-- non-zero Length is proof the asset resolved and contains real keyframes.
local ANIMATION_CANDIDATES = {
	idle1 = 507766666,
	idle2 = 507766951,
	idle3 = 507766388,
	walk = 507777826,
	run = 507767714,
	jump = 507765000,
	fall = 507767968,
	climb = 507765644,
	swim = 507784897,
	swimIdle = 507785072,
	-- Alternate/newer sets worth knowing about
	rthroIdle = 2510196951,
	rthroWalk = 2510202577,
	rthroRun = 2510199791,
}

local rigOk, rig = pcall(function()
	local desc = Instance.new("HumanoidDescription")
	return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
end)
report("api", "CreateHumanoidModelFromDescription", rigOk, rigOk and "rig created" or tostring(rig))

if rigOk and rig then
	rig.Parent = workspace
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator == nil and humanoid then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	report("api", "Animator", animator ~= nil, "")

	if animator then
		for name, id in ANIMATION_CANDIDATES do
			local anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://" .. id
			local ok, err = pcall(function()
				local track = animator:LoadAnimation(anim)
				local length = track.Length
				local deadline = os.clock() + 4
				while length <= 0 and os.clock() < deadline do
					task.wait(0.2)
					length = track.Length
				end
				assert(length > 0, "zero length (asset did not resolve)")
				track:Destroy()
				return length
			end)
			report("anim:" .. name, id, ok, ok and "loaded" or tostring(err))
		end
	end
end

-- 2. Stock meshes via InsertService:CreateMeshPartAsync -------------------------------
-- This is the only runtime path to arbitrary public meshes; LoadAsset is restricted to
-- assets the place owner owns.
local MESH_CANDIDATES = {
	-- Roblox core/classic meshes and commonly-mirrored public meshes
	tree = 1119541209,
	rock = 5257027938,
	crate = 6768917255,
	barrel = 6768917907,
	car = 5691843644,
	streetlamp = 6768918550,
	door = 6768916694,
}
report(
	"api",
	"CreateMeshPartAsync",
	pcall(function()
		return InsertService.CreateMeshPartAsync ~= nil
	end),
	""
)

for name, id in MESH_CANDIDATES do
	local ok, err = pcall(function()
		local part = InsertService:CreateMeshPartAsync(
			"rbxassetid://" .. id,
			Enum.CollisionFidelity.Box,
			Enum.RenderFidelity.Performance
		)
		assert(part ~= nil, "nil meshpart")
		part:Destroy()
		return true
	end)
	report("mesh:" .. name, id, ok, ok and "created" or tostring(err))
end

-- 3. Can we load arbitrary marketplace models at runtime? ------------------------------
-- Expected to FAIL for assets the place owner does not own; probing so the answer is
-- recorded rather than assumed.
local MODEL_CANDIDATES = { classicHouse = 14985684, freeModelTree = 1567446 }
for name, id in MODEL_CANDIDATES do
	local ok, err = pcall(function()
		local obj = InsertService:LoadAsset(id)
		assert(obj ~= nil)
		obj:Destroy()
		return true
	end)
	report("model:" .. name, id, ok, ok and "loaded" or tostring(err))
end

-- 4. Textures/decals resolve by id at runtime (used for signage and grime).
report(
	"api",
	"TextureRuntimeAssign",
	pcall(function()
		local p = Instance.new("Part")
		local d = Instance.new("Decal")
		d.Texture = "rbxassetid://6073763717"
		d.Parent = p
		p:Destroy()
		return true
	end),
	""
)

print("PROBE DONE")
