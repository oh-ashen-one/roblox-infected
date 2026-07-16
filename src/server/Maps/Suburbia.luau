--!strict
-- SUBURBAN STREET AT NIGHT — a road with six houses (front + back doors, so every
-- holdout is breachable), fenced yards with gaps, streetlamps. ~240 x 160 studs.

local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local HOUSE_W, HOUSE_D, HOUSE_H = 34, 28, 10

local function house(geo: Instance, zombieSpawns: Instance, x: number, z: number, flip: number)
	-- flip = 1: door faces -Z (toward road at z=0 for north row), -1 for south row
	local front = z - flip * HOUSE_D / 2
	local back = z + flip * HOUSE_D / 2
	local wallProps = { Color = C.Brick, Material = Enum.Material.Brick }

	-- Slab + roof
	Kit.floor(
		geo,
		x,
		z,
		HOUSE_W,
		HOUSE_D,
		0.2,
		{ Color = Color3.fromRGB(120, 100, 80), Material = Enum.Material.WoodPlanks }
	)
	Kit.part(
		geo,
		Vector3.new(HOUSE_W + 2, 1, HOUSE_D + 2),
		CFrame.new(x, HOUSE_H + 0.5, z),
		{ Color = C.Roof, Material = Enum.Material.Slate }
	)

	-- Front + back walls with doors (two entrances, always)
	Kit.wallXDoor(geo, x, front, HOUSE_W, HOUSE_H, 0, 6, wallProps)
	Kit.wallXDoor(geo, x, back, HOUSE_W, HOUSE_H, 0, 6, wallProps)
	-- Side walls with windows (gaps knives can arc through)
	Kit.wallZ(geo, x - HOUSE_W / 2, z, HOUSE_D, 4, 0, wallProps) -- low sill
	Kit.part(
		geo,
		Vector3.new(1, HOUSE_H - 8, HOUSE_D),
		CFrame.new(x - HOUSE_W / 2, 8 + (HOUSE_H - 8) / 2, z),
		wallProps
	)
	Kit.wallZ(geo, x + HOUSE_W / 2, z, HOUSE_D, 4, 0, wallProps)
	Kit.part(
		geo,
		Vector3.new(1, HOUSE_H - 8, HOUSE_D),
		CFrame.new(x + HOUSE_W / 2, 8 + (HOUSE_H - 8) / 2, z),
		wallProps
	)

	-- Interior: one dividing wall with a door, some furniture cover
	Kit.wallZDoor(
		geo,
		x,
		z,
		HOUSE_D,
		HOUSE_H,
		0,
		5,
		{ Color = C.LabWhite, Material = Enum.Material.SmoothPlastic }
	)
	Kit.box(
		geo,
		x - 10,
		0.2,
		z + flip * 6,
		8,
		3,
		4,
		{ Color = Color3.fromRGB(90, 70, 55), Material = Enum.Material.WoodPlanks }
	)
	Kit.box(
		geo,
		x + 9,
		0.2,
		z - flip * 6,
		5,
		3,
		5,
		{ Color = Color3.fromRGB(90, 70, 55), Material = Enum.Material.WoodPlanks }
	)

	-- Backyard zombie spawn
	Kit.spawnMarker(zombieSpawns, x, 0, back + flip * 10)
end

return {
	name = "Suburbia",
	build = function(): Model
		local map, geo, survivorSpawns, zombieSpawns = Kit.newMap("Suburbia")

		-- Ground: grass everywhere, road strip down the middle
		Kit.floor(geo, 0, 0, 240, 160, 0, { Color = C.Grass, Material = Enum.Material.Grass })
		Kit.floor(geo, 0, 0, 240, 24, 0.1, { Color = C.Road, Material = Enum.Material.Asphalt })
		-- Sidewalks
		Kit.floor(geo, 0, -16, 240, 6, 0.15, { Color = C.Concrete, Material = Enum.Material.Concrete })
		Kit.floor(geo, 0, 16, 240, 6, 0.15, { Color = C.Concrete, Material = Enum.Material.Concrete })

		-- Perimeter fence (map boundary)
		local fenceProps = { Color = C.Metal, Material = Enum.Material.Metal }
		Kit.wallX(geo, 0, -80, 240, 8, 0, fenceProps)
		Kit.wallX(geo, 0, 80, 240, 8, 0, fenceProps)
		Kit.wallZ(geo, -120, 0, 160, 8, 0, fenceProps)
		Kit.wallZ(geo, 120, 0, 160, 8, 0, fenceProps)

		-- Six houses: three per side of the road
		for i = 0, 2 do
			local x = -75 + i * 75
			house(geo, zombieSpawns, x, -48, -1) -- north row, doors face road
			house(geo, zombieSpawns, x, 48, 1) -- south row
		end

		-- Yard fences between houses, with gaps (multiple approach angles)
		for i = 0, 1 do
			local x = -37 + i * 75
			Kit.part(
				geo,
				Vector3.new(1, 5, 40),
				CFrame.new(x, 2.5, -55),
				{ Color = Color3.fromRGB(150, 120, 90), Material = Enum.Material.WoodPlanks }
			)
			Kit.part(
				geo,
				Vector3.new(1, 5, 40),
				CFrame.new(x, 2.5, 55),
				{ Color = Color3.fromRGB(150, 120, 90), Material = Enum.Material.WoodPlanks }
			)
		end

		-- Parked cars on the road (cover)
		for _, x in { -90, -40, 15, 65 } do
			local body = Kit.box(
				geo,
				x,
				0.2,
				(x % 2 == 0) and -6 or 6,
				14,
				4,
				7,
				{ Color = Color3.fromRGB(60, 80, 120), Material = Enum.Material.Metal }
			)
			Kit.box(
				geo,
				x,
				4.2,
				(x % 2 == 0) and -6 or 6,
				8,
				2.5,
				6.5,
				{ Color = C.Glass, Material = Enum.Material.Glass, Transparency = 0.4 }
			)
			local _ = body
		end

		-- Streetlamps (pools of light in the dark)
		for _, x in { -100, -50, 0, 50, 100 } do
			for _, z in { -14, 14 } do
				Kit.box(geo, x, 0.2, z, 1, 12, 1, { Color = C.Metal, Material = Enum.Material.Metal })
				local head = Kit.box(
					geo,
					x,
					12.2,
					z,
					2,
					1,
					2,
					{ Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon }
				)
				Kit.pointLight(head, 1.6, 30, Color3.fromRGB(255, 225, 170))
			end
		end

		-- Survivor spawns: driveways, road, yards — grouped 2-3
		local spots = {
			{ -75, -20 },
			{ -70, -24 },
			{ 0, -20 },
			{ 5, -24 },
			{ 75, -20 },
			{ 70, -24 },
			{ -75, 20 },
			{ -70, 24 },
			{ 0, 20 },
			{ 5, 24 },
			{ 75, 20 },
			{ 70, 24 },
			{ -110, 0 },
			{ -105, 4 },
			{ 110, 0 },
			{ 105, -4 },
			{ -37, 0 },
			{ 37, 0 },
			{ -75, -70 },
			{ 0, -70 },
			{ 75, -70 },
			{ -75, 70 },
			{ 0, 70 },
			{ 75, 70 },
			{ -110, -60 },
			{ 110, -60 },
			{ -110, 60 },
			{ 110, 60 },
			{ 30, -40 },
			{ -30, 40 },
		}
		for _, spot in spots do
			Kit.spawnMarker(survivorSpawns, spot[1], 0, spot[2])
		end
		-- Street-end zombie spawns
		Kit.spawnMarker(zombieSpawns, -115, 0, 0)
		Kit.spawnMarker(zombieSpawns, 115, 0, 0)

		return map
	end,
	lighting = {
		Ambient = Color3.fromRGB(18, 20, 32),
		OutdoorAmbient = Color3.fromRGB(38, 42, 60),
		ClockTime = 0, -- midnight
		FogEnd = 320,
		FogColor = Color3.fromRGB(12, 14, 22),
	},
}
