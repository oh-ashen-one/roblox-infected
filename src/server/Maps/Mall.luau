--!strict
-- ABANDONED MALL — two-floor interior, central atrium, storefronts with two
-- entrances each (breachable holdouts), ramps at both ends, skylight.
-- Footprint ~220 x 140 studs.

local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local FLOOR2_Y = 14
local WALL_H = 13
local W, D = 220, 140 -- overall footprint

return {
	name = "Abandoned Mall",
	build = function(): Model
		local map, geo, survivorSpawns, zombieSpawns = Kit.newMap("Abandoned Mall")

		-- Ground floor slab + roof
		Kit.floor(geo, 0, 0, W, D, 0, { Color = C.DarkFloor, Material = Enum.Material.Concrete })
		-- Second floor: two side galleries leaving an open atrium in the middle
		Kit.floor(geo, 0, -45, W, 50, FLOOR2_Y, { Color = C.Concrete, Material = Enum.Material.Concrete })
		Kit.floor(geo, 0, 45, W, 50, FLOOR2_Y, { Color = C.Concrete, Material = Enum.Material.Concrete })
		-- Roof with a glass skylight strip over the atrium
		Kit.part(
			geo,
			Vector3.new(W, 1, 50),
			CFrame.new(0, FLOOR2_Y + WALL_H + 0.5, -45),
			{ Color = C.Roof, Material = Enum.Material.Concrete }
		)
		Kit.part(
			geo,
			Vector3.new(W, 1, 50),
			CFrame.new(0, FLOOR2_Y + WALL_H + 0.5, 45),
			{ Color = C.Roof, Material = Enum.Material.Concrete }
		)
		Kit.part(geo, Vector3.new(W, 1, 40), CFrame.new(0, FLOOR2_Y + WALL_H + 0.5, 0), {
			Color = C.Glass,
			Material = Enum.Material.Glass,
			Transparency = 0.5,
			Name = "Skylight",
		})

		-- Perimeter walls (both floors high)
		local wallProps = { Color = C.Brick, Material = Enum.Material.Brick }
		Kit.wallXDoor(geo, 0, -D / 2, W, FLOOR2_Y + WALL_H, 0, 14, wallProps) -- north entrance
		Kit.wallXDoor(geo, 0, D / 2, W, FLOOR2_Y + WALL_H, 0, 14, wallProps) -- south entrance
		Kit.wallZ(geo, -W / 2, 0, D, FLOOR2_Y + WALL_H, 0, wallProps)
		Kit.wallZ(geo, W / 2, 0, D, FLOOR2_Y + WALL_H, 0, wallProps)

		-- Storefronts: 5 shops along each side, each with front door + side door (two entrances)
		local shopW, shopD = 36, 30
		for i = 0, 4 do
			local x = -W / 2 + 20 + i * (shopW + 4) + shopW / 2
			for _, side in { -1, 1 } do
				local zBack = side * (D / 2) -- against perimeter
				local zFront = side * (D / 2 - shopD)
				-- Front wall with wide storefront opening
				Kit.wallXDoor(
					geo,
					x,
					zFront,
					shopW,
					WALL_H,
					0,
					10,
					{ Color = C.Concrete, Material = Enum.Material.Concrete }
				)
				-- Side walls, one with a door (second entrance)
				Kit.wallZDoor(
					geo,
					x - shopW / 2,
					(zBack + zFront) / 2,
					shopD,
					WALL_H,
					0,
					6,
					{ Color = C.Concrete, Material = Enum.Material.Concrete }
				)
				Kit.wallZ(
					geo,
					x + shopW / 2,
					(zBack + zFront) / 2,
					shopD,
					WALL_H,
					0,
					{ Color = C.Concrete, Material = Enum.Material.Concrete }
				)
				-- Shop counter (cover)
				Kit.box(
					geo,
					x,
					0,
					side * (D / 2 - shopD / 2),
					12,
					3,
					3,
					{ Color = C.Metal, Material = Enum.Material.Metal }
				)
				-- Zombie respawn tucked in every other shop
				if i % 2 == 0 then
					Kit.spawnMarker(zombieSpawns, x, 0, side * (D / 2 - shopD / 2))
				end
			end
		end

		-- Atrium planters + kiosks (mid cover, knife arcs over them)
		for _, x in { -70, -25, 25, 70 } do
			Kit.box(geo, x, 0, 0, 10, 4, 10, { Color = C.Grass, Material = Enum.Material.Grass })
			Kit.box(geo, x, 0, -14, 6, 5, 6, { Color = C.Metal, Material = Enum.Material.Metal })
			Kit.box(geo, x, 0, 14, 6, 5, 6, { Color = C.Metal, Material = Enum.Material.Metal })
		end

		-- Ramps to second floor at both ends (multiple approach angles)
		Kit.ramp(
			geo,
			-W / 2 + 12,
			-12,
			10,
			0,
			FLOOR2_Y,
			36,
			{ Color = C.Concrete, Material = Enum.Material.Concrete }
		)
		Kit.ramp(
			geo,
			W / 2 - 12,
			12,
			10,
			0,
			FLOOR2_Y,
			36,
			{ Color = C.Concrete, Material = Enum.Material.Concrete }
		)

		-- Gallery railings (see the atrium, throwable over)
		Kit.part(
			geo,
			Vector3.new(W - 20, 3, 1),
			CFrame.new(0, FLOOR2_Y + 1.5, -20),
			{ Color = C.Metal, Material = Enum.Material.Metal }
		)
		Kit.part(
			geo,
			Vector3.new(W - 20, 3, 1),
			CFrame.new(0, FLOOR2_Y + 1.5, 20),
			{ Color = C.Metal, Material = Enum.Material.Metal }
		)

		-- Upstairs cover crates
		for _, x in { -80, -30, 30, 80 } do
			Kit.box(geo, x, FLOOR2_Y, -45, 6, 4, 6, { Color = C.Brick, Material = Enum.Material.WoodPlanks })
			Kit.box(geo, x, FLOOR2_Y, 45, 6, 4, 6, { Color = C.Brick, Material = Enum.Material.WoodPlanks })
		end

		-- Emergency lights (atmosphere)
		for _, x in { -80, -40, 0, 40, 80 } do
			local fixture = Kit.box(
				geo,
				x,
				FLOOR2_Y + WALL_H - 2,
				0,
				2,
				1,
				2,
				{ Color = C.Accent, Material = Enum.Material.Neon }
			)
			Kit.pointLight(fixture, 1.2, 26, Color3.fromRGB(255, 200, 160))
		end

		-- Survivor spawns: scattered in groups of 2-3 across the ground floor
		local survivorSpots = {
			{ -90, -50 },
			{ -85, -45 },
			{ -60, 50 },
			{ -55, 45 },
			{ -30, -50 },
			{ -25, -45 },
			{ 0, 55 },
			{ 5, 50 },
			{ 30, -50 },
			{ 35, -45 },
			{ 60, 50 },
			{ 65, 45 },
			{ 90, -50 },
			{ 85, -45 },
			{ -90, 50 },
			{ 90, 50 },
			{ 0, -55 },
			{ -5, -50 },
			{ -70, 0 },
			{ 70, 0 },
			{ -45, 10 },
			{ 45, -10 },
			{ 20, 8 },
			{ -20, -8 },
			{ 100, 0 },
			{ -100, 0 },
			{ 55, 20 },
			{ -55, -20 },
			{ 10, 30 },
			{ -10, -30 },
		}
		for _, spot in survivorSpots do
			Kit.spawnMarker(survivorSpawns, spot[1], 0, spot[2])
		end
		-- Extra zombie spawns on the upper galleries
		for _, x in { -60, 0, 60 } do
			Kit.spawnMarker(zombieSpawns, x, FLOOR2_Y, -45)
			Kit.spawnMarker(zombieSpawns, x, FLOOR2_Y, 45)
		end

		return map
	end,
	lighting = {
		Ambient = Color3.fromRGB(40, 38, 45),
		OutdoorAmbient = Color3.fromRGB(70, 70, 80),
		ClockTime = 20,
		FogEnd = 400,
		FogColor = Color3.fromRGB(25, 22, 28),
	},
}
