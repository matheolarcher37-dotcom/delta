-- Petits utilitaires de construction procédurale (pièces, clôtures, arbres, textes...).

local Build = {}

local DEFAULT_MATERIAL = Enum.Material.SmoothPlastic

function Build.part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = DEFAULT_MATERIAL
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	if props then
		local target: any = part
		for key, value in props do
			target[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- Pièce décorative sans collision.
function Build.deco(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?): Part
	local part = Build.part(parent, name, size, cf, color, props)
	part.CanCollide = false
	part.CanQuery = false
	return part
end

function Build.wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?): WedgePart
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = DEFAULT_MATERIAL
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	if props then
		local target: any = part
		for key, value in props do
			target[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- Cylindre vertical (axe Y) posé sur `base` (position du bas).
function Build.disc(parent: Instance, name: string, height: number, diameter: number, base: Vector3, color: Color3, props: { [string]: any }?): Part
	local cf = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local part = Build.part(parent, name, Vector3.new(height, diameter, diameter), cf, color, props)
	part.Shape = Enum.PartType.Cylinder
	return part
end

function Build.ball(parent: Instance, name: string, diameter: number, center: Vector3, color: Color3, props: { [string]: any }?): Part
	local part = Build.part(parent, name, Vector3.new(diameter, diameter, diameter), CFrame.new(center), color, props)
	part.Shape = Enum.PartType.Ball
	return part
end

function Build.model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Build.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

------------------------------------------------------------------------
-- Textes
------------------------------------------------------------------------

function Build.surfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3, props: { [string]: any }?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(30, 20, 20)
	if props then
		local target: any = label
		for key, value in props do
			target[key] = value
		end
	end
	label.Parent = gui
	return label
end

function Build.billboard(adornee: BasePart, size: UDim2, offset: Vector3, maxDistance: number?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffsetWorldSpace = offset
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = maxDistance or 120
	gui.Adornee = adornee
	gui.Parent = adornee
	return gui
end

function Build.label(parent: Instance, text: string, size: UDim2, position: UDim2, color: Color3, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = font or Enum.Font.LuckiestGuy
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(25, 15, 15)
	label.Parent = parent
	return label
end

------------------------------------------------------------------------
-- Clôtures (comme dans Grow a Chicken Fighter)
------------------------------------------------------------------------

local FENCE_WOOD = Color3.fromRGB(105, 70, 48)
local FENCE_DARK = Color3.fromRGB(80, 52, 36)
Build.FenceColor = FENCE_WOOD

function Build.fencePost(parent: Instance, position: Vector3, height: number, color: Color3?)
	local c = color or FENCE_WOOD
	Build.part(parent, "Post", Vector3.new(1.1, height, 1.1), CFrame.new(position + Vector3.new(0, height / 2, 0)), c, { Material = Enum.Material.Wood })
	Build.deco(parent, "PostCap", Vector3.new(1.3, 0.35, 1.3), CFrame.new(position + Vector3.new(0, height + 0.1, 0)), FENCE_DARK, { Material = Enum.Material.Wood })
end

-- Ligne de clôture de a vers b (au sol, y = a.Y).
function Build.fenceLine(parent: Instance, a: Vector3, b: Vector3, height: number?, spacing: number?, color: Color3?)
	local h = height or 4
	local gap = spacing or 7
	local c = color or FENCE_WOOD
	local delta = b - a
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end
	local count = math.max(1, math.floor(length / gap + 0.5))
	for i = 0, count do
		Build.fencePost(parent, a + delta * (i / count), h, c)
	end
	local mid = a + delta / 2
	local cf = CFrame.lookAt(mid, b) -- regarde vers b, la longueur est sur Z
	for _, y in { h * 0.45, h * 0.8 } do
		Build.part(parent, "Rail", Vector3.new(0.45, 0.55, length), cf + Vector3.new(0, y, 0), c, { Material = Enum.Material.Wood })
	end
end

-- Clôture circulaire avec des ouvertures (angles en radians).
function Build.fenceRing(parent: Instance, center: Vector3, radius: number, openings: { number }, openingHalfWidth: number, height: number?)
	local h = height or 4
	local segments = math.floor(2 * math.pi * radius / 7)
	local halfAngle = openingHalfWidth / radius
	local function isOpen(angle: number): boolean
		for _, open in openings do
			local diff = math.abs((angle - open + math.pi) % (2 * math.pi) - math.pi)
			if diff < halfAngle then
				return true
			end
		end
		return false
	end
	for i = 0, segments - 1 do
		local a1 = (i / segments) * 2 * math.pi
		local a2 = ((i + 1) / segments) * 2 * math.pi
		if not isOpen(a1) and not isOpen(a2) then
			local p1 = center + Vector3.new(math.cos(a1) * radius, 0, math.sin(a1) * radius)
			local p2 = center + Vector3.new(math.cos(a2) * radius, 0, math.sin(a2) * radius)
			Build.fencePost(parent, p1, h)
			local mid = (p1 + p2) / 2
			local cf = CFrame.lookAt(mid, p2)
			local length = (p2 - p1).Magnitude
			for _, y in { h * 0.45, h * 0.8 } do
				Build.part(parent, "Rail", Vector3.new(0.45, 0.55, length + 0.4), cf + Vector3.new(0, y, 0), FENCE_WOOD, { Material = Enum.Material.Wood })
			end
		elseif not isOpen(a1) then
			Build.fencePost(parent, center + Vector3.new(math.cos(a1) * radius, 0, math.sin(a1) * radius), h)
		end
	end
end

------------------------------------------------------------------------
-- Décors naturels (style voxel)
------------------------------------------------------------------------

function Build.tree(parent: Instance, base: Vector3, scale: number, leaf: Color3?, trunk: Color3?, rng: Random?)
	local s = scale
	local r = rng or Random.new()
	local model = Build.model(parent, "Tree")
	local trunkColor = trunk or Color3.fromRGB(120, 80, 50)
	local leafColor = leaf or Color3.fromRGB(80, 170, 60)
	local trunkHeight = 6 * s
	Build.part(model, "Trunk", Vector3.new(1.6 * s, trunkHeight, 1.6 * s), CFrame.new(base + Vector3.new(0, trunkHeight / 2, 0)), trunkColor, { Material = Enum.Material.Wood })
	local top = base + Vector3.new(0, trunkHeight, 0)
	local blocks = {
		{ Vector3.new(0, 1.5, 0), Vector3.new(7, 4, 7) },
		{ Vector3.new(0, 4.5, 0), Vector3.new(5, 3, 5) },
		{ Vector3.new(2.5, 0.5, 1), Vector3.new(3.5, 3, 3.5) },
		{ Vector3.new(-2.2, 1, -1.5), Vector3.new(3.5, 3, 3.5) },
	}
	for i, block in blocks do
		local shade = leafColor:Lerp(Color3.new(1, 1, 1), (i % 2) * 0.08)
		Build.part(
			model,
			"Leaves",
			block[2] * s,
			CFrame.new(top + block[1] * s) * CFrame.Angles(0, r:NextNumber(0, 0.5), 0),
			shade,
			{ Material = Enum.Material.Grass, CanCollide = i == 1 }
		)
	end
	return model
end

function Build.pine(parent: Instance, base: Vector3, scale: number, leaf: Color3?)
	local s = scale
	local model = Build.model(parent, "Pine")
	local leafColor = leaf or Color3.fromRGB(40, 110, 60)
	Build.part(model, "Trunk", Vector3.new(1.4 * s, 5 * s, 1.4 * s), CFrame.new(base + Vector3.new(0, 2.5 * s, 0)), Color3.fromRGB(100, 65, 45), { Material = Enum.Material.Wood })
	for i = 0, 3 do
		local width = (7 - i * 1.6) * s
		Build.part(
			model,
			"Layer",
			Vector3.new(width, 2.6 * s, width),
			CFrame.new(base + Vector3.new(0, (5 + i * 2.4) * s, 0)) * CFrame.Angles(0, i * 0.4, 0),
			leafColor:Lerp(Color3.new(0, 0, 0), i * 0.05),
			{ Material = Enum.Material.Grass }
		)
	end
	return model
end

function Build.rock(parent: Instance, base: Vector3, scale: number, color: Color3?, rng: Random?)
	local r = rng or Random.new()
	local c = color or Color3.fromRGB(140, 140, 150)
	local model = Build.model(parent, "Rock")
	local size = Vector3.new(r:NextNumber(2, 3.5), r:NextNumber(1.2, 2.2), r:NextNumber(2, 3.2)) * scale
	Build.part(
		model,
		"Rock",
		size,
		CFrame.new(base + Vector3.new(0, size.Y / 2 - 0.2, 0)) * CFrame.Angles(0, r:NextNumber(0, math.pi), r:NextNumber(-0.15, 0.15)),
		c,
		{ Material = Enum.Material.Slate }
	)
	local small = size * 0.5
	Build.part(
		model,
		"Rock",
		small,
		CFrame.new(base + Vector3.new(size.X * 0.5, small.Y / 2 - 0.1, size.Z * 0.2)) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0),
		c:Lerp(Color3.new(1, 1, 1), 0.1),
		{ Material = Enum.Material.Slate }
	)
	return model
end

function Build.flower(parent: Instance, base: Vector3, color: Color3)
	Build.deco(parent, "Stem", Vector3.new(0.2, 0.8, 0.2), CFrame.new(base + Vector3.new(0, 0.4, 0)), Color3.fromRGB(70, 150, 60))
	Build.deco(parent, "Petals", Vector3.new(0.7, 0.3, 0.7), CFrame.new(base + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, math.rad(45), 0), color)
	Build.deco(parent, "Heart", Vector3.new(0.3, 0.32, 0.3), CFrame.new(base + Vector3.new(0, 0.95, 0)), Color3.fromRGB(255, 220, 80))
end

function Build.bush(parent: Instance, base: Vector3, scale: number, color: Color3?)
	local c = color or Color3.fromRGB(70, 160, 60)
	Build.part(parent, "Bush", Vector3.new(3, 2.2, 3) * scale, CFrame.new(base + Vector3.new(0, 1.1 * scale, 0)), c, { Material = Enum.Material.Grass })
	Build.part(
		parent,
		"Bush",
		Vector3.new(2, 1.6, 2) * scale,
		CFrame.new(base + Vector3.new(1.2 * scale, 0.8 * scale, 0.6 * scale)) * CFrame.Angles(0, 0.5, 0),
		c:Lerp(Color3.new(1, 1, 1), 0.08),
		{ Material = Enum.Material.Grass }
	)
end

function Build.lantern(parent: Instance, base: Vector3, color: Color3?, height: number?)
	local h = height or 6
	local glow = color or Color3.fromRGB(255, 120, 60)
	local model = Build.model(parent, "Lantern")
	Build.part(model, "Pole", Vector3.new(0.5, h, 0.5), CFrame.new(base + Vector3.new(0, h / 2, 0)), Color3.fromRGB(60, 40, 30), { Material = Enum.Material.Wood })
	Build.deco(model, "Arm", Vector3.new(1.8, 0.3, 0.3), CFrame.new(base + Vector3.new(0.7, h - 0.2, 0)), Color3.fromRGB(60, 40, 30), { Material = Enum.Material.Wood })
	local lamp = Build.deco(model, "Lamp", Vector3.new(1.2, 1.6, 1.2), CFrame.new(base + Vector3.new(1.3, h - 1.3, 0)), glow, { Material = Enum.Material.Neon, Transparency = 0.1 })
	Build.deco(model, "LampCap", Vector3.new(1.4, 0.25, 1.4), CFrame.new(base + Vector3.new(1.3, h - 0.4, 0)), Color3.fromRGB(40, 30, 30))
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 14
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = lamp
	return model
end

-- Portique japonais (torii). `cf` = base au centre, regardant à travers le portique.
function Build.torii(parent: Instance, cf: CFrame, width: number, height: number, color: Color3?, top: Color3?)
	local red = color or Color3.fromRGB(210, 40, 35)
	local black = top or Color3.fromRGB(30, 25, 25)
	local model = Build.model(parent, "Torii")
	for _, side in { -1, 1 } do
		Build.part(model, "Pillar", Vector3.new(1.6, height, 1.6), cf * CFrame.new(side * width / 2, height / 2, 0), red)
		Build.part(model, "PillarBase", Vector3.new(2.2, 1, 2.2), cf * CFrame.new(side * width / 2, 0.5, 0), black)
	end
	Build.part(model, "Kasagi", Vector3.new(width + 6, 1.4, 2.4), cf * CFrame.new(0, height + 0.7, 0), black)
	Build.part(model, "Shimaki", Vector3.new(width + 4, 1, 2), cf * CFrame.new(0, height - 0.5, 0), red)
	Build.part(model, "Nuki", Vector3.new(width + 2, 0.9, 1.2), cf * CFrame.new(0, height - 3, 0), red)
	Build.part(model, "Gakuzuka", Vector3.new(1, 2.2, 1.3), cf * CFrame.new(0, height - 1.9, 0), black)
	for _, side in { -1, 1 } do
		Build.wedge(model, "KasagiTip", Vector3.new(2.4, 1.4, 1.6), cf * CFrame.new(side * (width / 2 + 3.8), height + 0.7, 0) * CFrame.Angles(0, side * math.rad(90), 0), black)
	end
	return model
end

-- Petite maison voxel avec toit en pente.
function Build.house(parent: Instance, cf: CFrame, size: Vector3, wall: Color3, roof: Color3, trim: Color3?)
	local model = Build.model(parent, "House")
	local t = trim or Color3.fromRGB(90, 60, 40)
	Build.part(model, "Walls", size, cf * CFrame.new(0, size.Y / 2, 0), wall)
	Build.part(model, "Base", Vector3.new(size.X + 1, 0.8, size.Z + 1), cf * CFrame.new(0, 0.4, 0), t)
	-- Toit à deux pans (wedges).
	local roofHeight = size.Y * 0.45
	for _, side in { -1, 1 } do
		Build.wedge(
			model,
			"Roof",
			Vector3.new(size.X + 2.5, roofHeight, size.Z / 2 + 1.5),
			cf * CFrame.new(0, size.Y + roofHeight / 2, side * (size.Z / 4 + 0.75)) * CFrame.Angles(0, side > 0 and math.pi or 0, 0),
			roof
		)
	end
	Build.part(model, "Ridge", Vector3.new(size.X + 2.7, 0.6, 0.8), cf * CFrame.new(0, size.Y + roofHeight, 0), roof:Lerp(Color3.new(0, 0, 0), 0.25))
	-- Porte et fenêtres.
	Build.deco(model, "Door", Vector3.new(size.X * 0.2, size.Y * 0.55, 0.2), cf * CFrame.new(0, size.Y * 0.275 + 0.4, -size.Z / 2 - 0.05), t)
	for _, side in { -1, 1 } do
		Build.deco(
			model,
			"Window",
			Vector3.new(size.X * 0.15, size.Y * 0.2, 0.2),
			cf * CFrame.new(side * size.X * 0.3, size.Y * 0.6, -size.Z / 2 - 0.05),
			Color3.fromRGB(255, 230, 150),
			{ Material = Enum.Material.Neon, Transparency = 0.2 }
		)
	end
	return model
end

return Build
