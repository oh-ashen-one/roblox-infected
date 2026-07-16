--!strict
-- Procedural map-building kit. Maps are plain Luau (Rojo-managed, diffable) that
-- assemble anchored parts into a Model with the contract MapService expects:
--   <Map Model>
--     Geometry/        all visible parts
--     SurvivorSpawns/  invisible parts marking survivor spawn points
--     ZombieSpawns/    invisible parts marking zombie respawn points

local Kit = {}

export type MapModel = Model

function Kit.newMap(name: string): (Model, Folder, Folder, Folder)
	local model = Instance.new("Model")
	model.Name = name
	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = model
	local survivorSpawns = Instance.new("Folder")
	survivorSpawns.Name = "SurvivorSpawns"
	survivorSpawns.Parent = model
	local zombieSpawns = Instance.new("Folder")
	zombieSpawns.Name = "ZombieSpawns"
	zombieSpawns.Parent = model
	return model, geometry, survivorSpawns, zombieSpawns
end

function Kit.part(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	props: { Color: Color3?, Material: Enum.Material?, Transparency: number?, Name: string? }?
): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		if props.Color then
			part.Color = props.Color
		end
		if props.Material then
			part.Material = props.Material
		end
		if props.Transparency then
			part.Transparency = props.Transparency
		end
		if props.Name then
			part.Name = props.Name
		end
	end
	part.Parent = parent
	return part
end

-- Axis-aligned box position helper: pos is the CENTER of the floor footprint.
function Kit.at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- Floor slab centered at (x,z), top surface at y.
function Kit.floor(parent: Instance, x: number, z: number, w: number, d: number, y: number, props: any?): Part
	return Kit.part(parent, Vector3.new(w, 1, d), CFrame.new(x, y - 0.5, z), props)
end

-- Wall along X axis (facing Z): centered at (x, z), width w, height h, base at y.
function Kit.wallX(parent: Instance, x: number, z: number, w: number, h: number, y: number, props: any?): Part
	return Kit.part(parent, Vector3.new(w, h, 1), CFrame.new(x, y + h / 2, z), props)
end

-- Wall along Z axis (facing X).
function Kit.wallZ(parent: Instance, x: number, z: number, d: number, h: number, y: number, props: any?): Part
	return Kit.part(parent, Vector3.new(1, h, d), CFrame.new(x, y + h / 2, z), props)
end

-- Wall along X with a centered doorway gap (two segments + lintel).
function Kit.wallXDoor(
	parent: Instance,
	x: number,
	z: number,
	w: number,
	h: number,
	y: number,
	doorW: number,
	props: any?
)
	local segW = (w - doorW) / 2
	if segW > 0.5 then
		Kit.wallX(parent, x - (doorW + segW) / 2, z, segW, h, y, props)
		Kit.wallX(parent, x + (doorW + segW) / 2, z, segW, h, y, props)
	end
	local lintelH = h - 7
	if lintelH > 0.5 then
		Kit.part(parent, Vector3.new(doorW, lintelH, 1), CFrame.new(x, y + 7 + lintelH / 2, z), props)
	end
end

-- Wall along Z with a centered doorway gap.
function Kit.wallZDoor(
	parent: Instance,
	x: number,
	z: number,
	d: number,
	h: number,
	y: number,
	doorW: number,
	props: any?
)
	local segD = (d - doorW) / 2
	if segD > 0.5 then
		Kit.wallZ(parent, x, z - (doorW + segD) / 2, segD, h, y, props)
		Kit.wallZ(parent, x, z + (doorW + segD) / 2, segD, h, y, props)
	end
	local lintelH = h - 7
	if lintelH > 0.5 then
		Kit.part(parent, Vector3.new(1, lintelH, doorW), CFrame.new(x, y + 7 + lintelH / 2, z), props)
	end
end

-- Ramp from (x,z) floor y0 up to y1, running along +Z.
function Kit.ramp(
	parent: Instance,
	x: number,
	z: number,
	w: number,
	y0: number,
	y1: number,
	length: number,
	props: any?
): Part
	local rise = y1 - y0
	local slope = math.sqrt(rise * rise + length * length)
	local angle = math.atan2(rise, length)
	local part = Kit.part(
		parent,
		Vector3.new(w, 1, slope),
		CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(-angle, 0, 0),
		props
	)
	return part
end

-- Simple box prop (crate, counter, planter...)
function Kit.box(
	parent: Instance,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	props: any?
): Part
	return Kit.part(parent, Vector3.new(sx, sy, sz), CFrame.new(x, y + sy / 2, z), props)
end

function Kit.spawnMarker(parent: Instance, x: number, y: number, z: number)
	local marker = Instance.new("Part")
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.Transparency = 1
	marker.Size = Vector3.new(2, 1, 2)
	marker.CFrame = CFrame.new(x, y + 3, z)
	marker.Name = "Spawn"
	marker.Parent = parent
end

function Kit.pointLight(parent: Part, brightness: number, range: number, color: Color3?)
	local light = Instance.new("PointLight")
	light.Brightness = brightness
	light.Range = range
	if color then
		light.Color = color
	end
	light.Parent = parent
end

-- Palette shared by maps so materials feel consistent.
Kit.Colors = {
	Concrete = Color3.fromRGB(160, 158, 152),
	DarkFloor = Color3.fromRGB(90, 88, 86),
	Brick = Color3.fromRGB(138, 90, 66),
	Roof = Color3.fromRGB(70, 66, 64),
	Glass = Color3.fromRGB(150, 200, 220),
	Metal = Color3.fromRGB(120, 124, 130),
	Grass = Color3.fromRGB(96, 140, 72),
	Road = Color3.fromRGB(52, 52, 56),
	Accent = Color3.fromRGB(200, 60, 60),
	LabWhite = Color3.fromRGB(222, 224, 226),
}

return Kit
