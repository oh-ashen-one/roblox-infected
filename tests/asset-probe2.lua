-- Second asset probe: what else is free and first-party that we aren't using yet.
--
-- Same rule as the first probe — ask the engine, don't trust a remembered id.
-- Output: "PROBE2 <category> <id> OK|FAIL <detail>"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

RunService:Run()
task.wait(2)

local function report(category, id, ok, detail)
	print(
		("PROBE2 %s %s %s %s"):format(category, tostring(id), ok and "OK" or "FAIL", tostring(detail or ""))
	)
end

-- 1. Emote animations. STATUS.md lists emotes as blocked on "animation assets uploaded to
-- the account" — but Roblox's own emote set is public, which would unblock the feature.
local EMOTES = {
	wave = 507770239,
	point = 507770453,
	dance = 507771019,
	dance2 = 507776043,
	dance3 = 507777268,
	laugh = 507770818,
	cheer = 507770677,
}

local rigOk, rig = pcall(function()
	return Players:CreateHumanoidModelFromDescription(
		Instance.new("HumanoidDescription"),
		Enum.HumanoidRigType.R15
	)
end)
if rigOk and rig then
	rig.Parent = workspace
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator == nil and humanoid then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	for name, id in EMOTES do
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. id
		local ok, err = pcall(function()
			local track = animator:LoadAnimation(anim)
			local deadline = os.clock() + 4
			while track.Length <= 0 and os.clock() < deadline do
				task.wait(0.2)
			end
			assert(track.Length > 0, "zero length")
			track:Destroy()
		end)
		report("emote:" .. name, id, ok, ok and "loaded" or tostring(err))
	end
end

-- 2. Default character sounds. A hidden-infection game lives on hearing someone behind you,
-- and right now bots and players move in total silence.
local SOUNDS = {
	running = 5765485163,
	jumping = 5153726241,
	landing = 5153725701,
	freeFalling = 5153696148,
	died = 5762129396,
	climbing = 5766351873,
	getUp = 5153696148,
	-- classic-era alternates
	classicRun = 131961136,
	classicDied = 111896685,
}
for name, id in SOUNDS do
	local ok, err = pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. id
		sound.Parent = workspace
		local deadline = os.clock() + 5
		while not sound.IsLoaded and os.clock() < deadline do
			task.wait(0.2)
		end
		assert(sound.IsLoaded, "never loaded")
		local len = sound.TimeLength
		sound:Destroy()
		return len
	end)
	report("sound:" .. name, id, ok, ok and "loaded" or tostring(err))
end

-- 3. Terrain: entirely first-party, no assets, and would replace Suburbia's flat green slab
-- with actual ground.
local terrainOk, terrainErr = pcall(function()
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -400, 0), Vector3.new(64, 16, 64), Enum.Material.Grass)
	local region = Region3.new(Vector3.new(-32, -408, -32), Vector3.new(32, -392, 32))
	region = region:ExpandToGrid(4)
	local materials = terrain:ReadVoxels(region, 4)
	terrain:FillBlock(CFrame.new(0, -400, 0), Vector3.new(64, 16, 64), Enum.Material.Air)
	return materials ~= nil
end)
report("api", "Terrain", terrainOk, terrainOk and "fill/read ok" or tostring(terrainErr))

-- 4. MaterialVariant / MaterialService: free PBR surface upgrades with no asset ids.
local matOk, matErr = pcall(function()
	local service = game:GetService("MaterialService")
	local variant = Instance.new("MaterialVariant")
	variant.BaseMaterial = Enum.Material.Concrete
	variant.Name = "ProbeVariant"
	variant.Parent = service
	variant:Destroy()
	return true
end)
report("api", "MaterialVariant", matOk, matOk and "created" or tostring(matErr))

-- 5. Sky: a custom skybox needs six textures, but confirm the instance works so Suburbia can
-- at least get a night sky with stars rather than the default day dome.
local skyOk, skyErr = pcall(function()
	local sky = Instance.new("Sky")
	sky.StarCount = 5000
	sky.Parent = game:GetService("Lighting")
	sky:Destroy()
	return true
end)
report("api", "Sky", skyOk, skyOk and "created" or tostring(skyErr))

print("PROBE2 DONE")
