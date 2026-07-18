--!strict
-- DOCKS WAREHOUSE — one large connected concrete floor (pathfinding-friendly) with rows
-- of shipping-container/shelf cover forming aisles, two corner offices with doored walls,
-- and a loading dock. ~200 x 150 studs, dim industrial lighting. Flat floor so bots path
-- cleanly; cover comes from boxes, not gaps.

local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local W, D, WALL_H = 200, 150, 16

local function container(geo: Instance, x: number, z: number, color: Color3)
	Kit.box(geo, x, 0.2, z, 20, 9, 8, { Color = color, Material = Enum.Material.CorrodedMetal })
end

local function office(geo: Instance, zombieSpawns: Instance, x: number, z: number, doorSide: number)
	local ow, od, oh = 34, 26, 12
	local props = { Color = C.Metal, Material = Enum.Material.Metal }
	Kit.floor(geo, x, z, ow, od, 0.15, { Color = C.DarkFloor, Material = Enum.Material.Concrete })
	-- Two solid walls, two doored walls so it's breachable from multiple sides.
	Kit.wallX(geo, x, z - od / 2, ow, oh, 0, props)
	Kit.wallXDoor(geo, x, z + od / 2, ow, oh, 0, 7, props)
	Kit.wallZDoor(geo, x - ow / 2, z, od, oh, 0, 7, props)
	Kit.wallZ(geo, x + ow / 2, z, od, oh, 0, props)
	Kit.spawnMarker(zombieSpawns, x + doorSide * (ow / 2 + 6), 0, z)
end

return {
	name = "Warehouse",
	build = function(): Model
		local map, geo, survivorSpawns, zombieSpawns = Kit.newMap("Warehouse")

		-- Big connected floor + perimeter walls
		Kit.floor(geo, 0, 0, W, D, 0, { Color = C.Concrete, Material = Enum.Material.Concrete })
		local wallProps = { Color = C.Metal, Material = Enum.Material.Metal }
		Kit.wallX(geo, 0, -D / 2, W, WALL_H, 0, wallProps)
		Kit.wallX(geo, 0, D / 2, W, WALL_H, 0, wallProps)
		Kit.wallZ(geo, -W / 2, 0, D, WALL_H, 0, wallProps)
		Kit.wallZDoor(geo, W / 2, 0, D, WALL_H, 0, 16, wallProps) -- loading-dock opening

		-- Roof beams w/ lights (pools of light on the floor)
		for _, x in { -70, -30, 10, 50, 90 } do
			for _, z in { -40, 0, 40 } do
				local lamp = Kit.box(
					geo,
					x,
					15,
					z,
					3,
					1,
					3,
					{ Color = Color3.fromRGB(255, 245, 210), Material = Enum.Material.Neon }
				)
				Kit.pointLight(lamp, 1.4, 34, Color3.fromRGB(255, 235, 190))
			end
		end

		-- Container aisles: rows of cover with lanes between them
		local colors = {
			Color3.fromRGB(150, 70, 60),
			Color3.fromRGB(60, 90, 130),
			Color3.fromRGB(90, 120, 70),
			Color3.fromRGB(150, 130, 60),
		}
		for row = 0, 2 do
			local z = -35 + row * 35
			for col = 0, 3 do
				local x = -66 + col * 30
				container(geo, x, z, colors[((row + col) % #colors) + 1])
			end
		end
		-- Stacked pallets for extra cover / vertical interest
		for _, spot in { { -85, -55 }, { 85, 55 }, { 40, -55 }, { -40, 55 } } do
			Kit.box(
				geo,
				spot[1],
				0.2,
				spot[2],
				8,
				6,
				8,
				{ Color = Color3.fromRGB(120, 95, 60), Material = Enum.Material.WoodPlanks }
			)
		end

		-- Two corner offices
		office(geo, zombieSpawns, -78, -55, -1)
		office(geo, zombieSpawns, 78, 55, 1)

		-- Survivor spawns spread across the floor
		local spots = {
			{ 0, 0 },
			{ -20, -15 },
			{ 20, 15 },
			{ -50, 20 },
			{ 50, -20 },
			{ -90, 0 },
			{ 90, 0 },
			{ 0, -55 },
			{ 0, 55 },
			{ -30, 45 },
			{ 30, -45 },
			{ 60, 40 },
			{ -60, -40 },
			{ 15, -30 },
			{ -15, 30 },
			{ 45, 0 },
			{ -45, 0 },
			{ 70, -30 },
			{ -70, 30 },
			{ 0, 30 },
			{ 0, -30 },
			{ 25, 55 },
			{ -25, -55 },
			{ 85, -45 },
			{ -85, 45 },
		}
		for _, spot in spots do
			Kit.spawnMarker(survivorSpawns, spot[1], 0, spot[2])
		end
		-- Dock + far-corner zombie spawns
		Kit.spawnMarker(zombieSpawns, 95, 0, 0)
		Kit.spawnMarker(zombieSpawns, -95, 0, 60)

		return map
	end,
	lighting = {
		Ambient = Color3.fromRGB(26, 26, 30),
		OutdoorAmbient = Color3.fromRGB(40, 42, 48),
		ClockTime = 2,
		FogEnd = 260,
		FogColor = Color3.fromRGB(18, 18, 22),
	},
}
