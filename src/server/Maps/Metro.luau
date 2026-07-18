--!strict
-- ABANDONED METRO — a subway station: two side platforms flanking a lowered track bed,
-- a row of pillars down each platform, ticket-hall alcoves, and stair ramps connecting the
-- track bed to the platforms so the whole space is one connected walkable surface (good for
-- pathfinding). ~210 x 120 studs, dim underground lighting.

local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local LEN = 210

return {
	name = "Metro",
	build = function(): Model
		local map, geo, survivorSpawns, zombieSpawns = Kit.newMap("Metro")

		local tile = { Color = Color3.fromRGB(70, 72, 80), Material = Enum.Material.Concrete }
		local trackFloor = { Color = Color3.fromRGB(40, 40, 46), Material = Enum.Material.Concrete }
		local wallProps = { Color = Color3.fromRGB(90, 88, 84), Material = Enum.Material.Brick }

		-- Two platforms (raised) + central track bed (lowered), all connected by ramps.
		Kit.floor(geo, 0, -34, LEN, 40, 2, tile) -- north platform (top at y=2)
		Kit.floor(geo, 0, 34, LEN, 40, 2, tile) -- south platform
		Kit.floor(geo, 0, 0, LEN, 30, 0, trackFloor) -- track bed (top at y=0)
		-- Ramps from track bed up to each platform (so bots can traverse everything)
		for _, x in { -70, 0, 70 } do
			Kit.ramp(geo, x, -16, 10, 0, 2, 6, tile)
			Kit.ramp(geo, x, 16, 10, 2, 0, 6, tile)
		end

		-- Outer walls + curved-ceiling suggestion via a high beam
		Kit.wallX(geo, 0, -54, LEN, 18, 2, wallProps)
		Kit.wallX(geo, 0, 54, LEN, 18, 2, wallProps)
		Kit.wallZ(geo, -LEN / 2, 0, 120, 18, 0, wallProps)
		Kit.wallZ(geo, LEN / 2, 0, 120, 18, 0, wallProps)

		-- Pillar rows on each platform (cover + sightline breaks)
		for _, x in { -80, -48, -16, 16, 48, 80 } do
			for _, z in { -40, 40 } do
				Kit.box(geo, x, 2, z, 4, 14, 4, { Color = C.Concrete, Material = Enum.Material.Concrete })
			end
		end

		-- Ceiling strip lights along both platforms
		for _, x in { -80, -40, 0, 40, 80 } do
			for _, z in { -34, 34 } do
				local lamp = Kit.box(
					geo,
					x,
					15,
					z,
					6,
					0.5,
					2,
					{ Color = Color3.fromRGB(210, 230, 255), Material = Enum.Material.Neon }
				)
				Kit.pointLight(lamp, 1.2, 26, Color3.fromRGB(190, 215, 255))
			end
		end

		-- Ticket-hall alcoves at the ends (benches as cover)
		for _, x in { -95, 95 } do
			Kit.box(
				geo,
				x,
				2.2,
				-34,
				12,
				2,
				4,
				{ Color = Color3.fromRGB(80, 70, 60), Material = Enum.Material.WoodPlanks }
			)
			Kit.box(
				geo,
				x,
				2.2,
				34,
				12,
				2,
				4,
				{ Color = Color3.fromRGB(80, 70, 60), Material = Enum.Material.WoodPlanks }
			)
		end

		-- Survivor spawns across both platforms + track
		local spots = {
			{ -80, -34 },
			{ -40, -34 },
			{ 0, -34 },
			{ 40, -34 },
			{ 80, -34 },
			{ -80, 34 },
			{ -40, 34 },
			{ 0, 34 },
			{ 40, 34 },
			{ 80, 34 },
			{ -60, 0 },
			{ -20, 0 },
			{ 20, 0 },
			{ 60, 0 },
			{ -95, -40 },
			{ 95, 40 },
			{ -30, -44 },
			{ 30, 44 },
			{ 0, -44 },
			{ 0, 44 },
			{ -90, 0 },
			{ 90, 0 },
			{ 55, -40 },
			{ -55, 40 },
		}
		for _, spot in spots do
			Kit.spawnMarker(survivorSpawns, spot[1], 3, spot[2])
		end
		-- Tunnel-mouth zombie spawns at each end of the track bed
		Kit.spawnMarker(zombieSpawns, -100, 1, 0)
		Kit.spawnMarker(zombieSpawns, 100, 1, 0)

		return map
	end,
	lighting = {
		Ambient = Color3.fromRGB(20, 22, 28),
		OutdoorAmbient = Color3.fromRGB(30, 34, 44),
		ClockTime = 1,
		FogEnd = 220,
		FogColor = Color3.fromRGB(12, 14, 20),
	},
}
