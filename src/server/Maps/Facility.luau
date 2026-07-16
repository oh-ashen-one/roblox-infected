--!strict
-- RESEARCH FACILITY — corridor grid with labs off each side, every room has two
-- doors, a central server room holdout with three entrances, glass observation
-- walls. Claustrophobic sightlines favor the knife. ~200 x 130 studs.

local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local WALL_H = 11
local W, D = 200, 130

return {
	name = "Research Facility",
	build = function(): Model
		local map, geo, survivorSpawns, zombieSpawns = Kit.newMap("Research Facility")

		local wallProps = { Color = C.LabWhite, Material = Enum.Material.SmoothPlastic }
		local glassProps = { Color = C.Glass, Material = Enum.Material.Glass, Transparency = 0.45 }

		-- Slab + ceiling
		Kit.floor(
			geo,
			0,
			0,
			W,
			D,
			0,
			{ Color = Color3.fromRGB(200, 202, 205), Material = Enum.Material.Marble }
		)
		Kit.part(
			geo,
			Vector3.new(W, 1, D),
			CFrame.new(0, WALL_H + 0.5, 0),
			{ Color = C.Roof, Material = Enum.Material.Concrete }
		)

		-- Perimeter
		Kit.wallXDoor(geo, 0, -D / 2, W, WALL_H, 0, 10, wallProps)
		Kit.wallXDoor(geo, 0, D / 2, W, WALL_H, 0, 10, wallProps)
		Kit.wallZ(geo, -W / 2, 0, D, WALL_H, 0, wallProps)
		Kit.wallZ(geo, W / 2, 0, D, WALL_H, 0, wallProps)

		-- Two long east-west corridors at z = -20 and z = +20 formed by lab blocks.
		-- North lab row (z from -65 to -21), south lab row (21..65), center block between corridors.

		-- Lab rows: 4 labs each side, doors onto the corridor + connecting doors between labs
		local labW = 44
		for i = 0, 3 do
			local x = -W / 2 + 12 + i * (labW + 4) + labW / 2
			-- North row: from perimeter to corridor
			Kit.wallXDoor(geo, x, -21, labW, WALL_H, 0, 7, wallProps) -- corridor door
			if i < 3 then
				Kit.wallZDoor(geo, x + labW / 2 + 2, -43, 44, WALL_H, 0, 6, wallProps) -- lab-to-lab door
			end
			-- South row
			Kit.wallXDoor(geo, x, 21, labW, WALL_H, 0, 7, wallProps)
			if i < 3 then
				Kit.wallZDoor(geo, x + labW / 2 + 2, 43, 44, WALL_H, 0, 6, wallProps)
			end
			-- Lab benches (cover)
			Kit.box(geo, x, 0, -43, 14, 3.5, 4, { Color = C.Metal, Material = Enum.Material.Metal })
			Kit.box(geo, x, 0, 43, 14, 3.5, 4, { Color = C.Metal, Material = Enum.Material.Metal })
			-- Zombie spawns in alternating labs
			if i % 2 == 1 then
				Kit.spawnMarker(zombieSpawns, x, 0, -50)
				Kit.spawnMarker(zombieSpawns, x, 0, 50)
			end
		end

		-- Central server room between the corridors (-20..20): THE holdout.
		-- Three entrances: west door, east door, north glass wall with door.
		local srW, srD = 70, 34
		Kit.wallZDoor(geo, -srW / 2, 0, srD, WALL_H, 0, 7, wallProps) -- west
		Kit.wallZDoor(geo, srW / 2, 0, srD, WALL_H, 0, 7, wallProps) -- east
		Kit.wallXDoor(geo, 0, -srD / 2 + 3, srW, WALL_H, 0, 8, glassProps) -- north (glass, watchable)
		Kit.wallX(geo, 0, srD / 2 - 3, srW, WALL_H, 0, wallProps) -- south solid
		-- Server racks: cover lanes inside
		for _, x in { -22, -8, 8, 22 } do
			Kit.box(
				geo,
				x,
				0,
				0,
				4,
				7,
				16,
				{ Color = Color3.fromRGB(30, 34, 40), Material = Enum.Material.Metal }
			)
		end

		-- Flanking side halls connect the two corridors at both map ends (no single choke)
		-- (the perimeter doors already provide outer rotation)

		-- Ceiling lights: cool white every 30 studs down both corridors
		for _, z in { -20, 20 } do
			for i = 0, 6 do
				local x = -90 + i * 30
				local fixture = Kit.box(
					geo,
					x,
					WALL_H - 1.4,
					z,
					4,
					0.4,
					2,
					{ Color = Color3.fromRGB(220, 235, 255), Material = Enum.Material.Neon }
				)
				Kit.pointLight(fixture, 1.1, 24, Color3.fromRGB(200, 220, 255))
			end
		end
		-- Red emergency light in the server room
		local red =
			Kit.box(geo, 0, WALL_H - 1.4, 0, 2, 0.4, 2, { Color = C.Accent, Material = Enum.Material.Neon })
		Kit.pointLight(red, 1.4, 30, Color3.fromRGB(255, 80, 80))

		-- Survivor spawns: corridor ends, lab corners, server room approaches
		local spots = {
			{ -95, -20 },
			{ -90, -24 },
			{ 95, -20 },
			{ 90, -24 },
			{ -95, 20 },
			{ -90, 24 },
			{ 95, 20 },
			{ 90, 24 },
			{ -60, -20 },
			{ -55, -16 },
			{ 60, 20 },
			{ 55, 16 },
			{ -60, 20 },
			{ 60, -20 },
			{ 0, -24 },
			{ 5, -20 },
			{ 0, 24 },
			{ -5, 20 },
			{ -40, -55 },
			{ -35, -50 },
			{ 40, -55 },
			{ 40, 55 },
			{ -40, 55 },
			{ 35, 50 },
			{ -85, -55 },
			{ 85, -55 },
			{ -85, 55 },
			{ 85, 55 },
			{ 20, -50 },
			{ -20, 50 },
		}
		for _, spot in spots do
			Kit.spawnMarker(survivorSpawns, spot[1], 0, spot[2])
		end
		-- Corridor-end zombie spawns
		Kit.spawnMarker(zombieSpawns, -95, 0, 0)
		Kit.spawnMarker(zombieSpawns, 95, 0, 0)

		return map
	end,
	lighting = {
		Ambient = Color3.fromRGB(52, 56, 64),
		OutdoorAmbient = Color3.fromRGB(60, 64, 74),
		ClockTime = 12,
		FogEnd = 500,
		FogColor = Color3.fromRGB(30, 32, 38),
	},
}
