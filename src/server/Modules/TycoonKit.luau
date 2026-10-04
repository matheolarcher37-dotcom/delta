-- Boîte à outils de la base « tycoon » : boutons d'achat (socle + anneau Neon + grand panneau),
-- fantômes de prévisualisation, animation de construction, sols sans picots (planches, dalles,
-- marbre) et petits décors d'animé réutilisables (lanterne de pierre, cerisier, toits japonais...).
--
-- Tout est construit à partir d'un CFrame (jamais de coordonnées absolues) : les modules
-- TycoonStructures et PlotService passent le CFrame de la base.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Build = require(script.Parent.Build)

local Kit = {}

local rgb = Color3.fromRGB

Kit.Colors = {
	Afford = rgb(80, 220, 110),
	AffordDark = rgb(30, 120, 55),
	TooExpensive = rgb(240, 70, 80),
	TooExpensiveDark = rgb(130, 30, 40),
	Gold = rgb(255, 205, 60),
	Panel = rgb(28, 24, 48),
	Stroke = rgb(12, 10, 22),
	TextDim = rgb(205, 198, 240),
	Ghost = rgb(150, 220, 255),
	-- Matières (couleurs « animé », saturées mais douces).
	Grass = rgb(118, 178, 82),
	GrassDark = rgb(98, 156, 68),
	StoneLight = rgb(214, 208, 196),
	StoneMid = rgb(184, 178, 168),
	StoneDark = rgb(120, 116, 112),
	Joint = rgb(92, 88, 84),
	Wood = rgb(160, 108, 66),
	WoodLight = rgb(196, 146, 96),
	WoodDark = rgb(92, 60, 40),
	Lacquer = rgb(196, 38, 38),
	LacquerDark = rgb(140, 24, 28),
	RoofTile = rgb(58, 66, 86),
	RoofTileDark = rgb(40, 46, 62),
	Plaster = rgb(244, 240, 228),
	Marble = rgb(236, 234, 228),
	MarbleVein = rgb(206, 202, 196),
	Sand = rgb(232, 206, 150),
	Water = rgb(70, 170, 235),
	Sakura = rgb(255, 176, 206),
	SakuraLight = rgb(255, 206, 226),
	PaperLight = rgb(255, 236, 190),
}
local C = Kit.Colors

------------------------------------------------------------------------
-- Primitives
------------------------------------------------------------------------

-- Ellipsoïde (Part + SpecialMesh Sphere) : feuillages, rochers arrondis, nuages.
function Kit.blob(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?): Part
	local part = Build.deco(parent, name, size, cf, color, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Cylindre dont l'axe suit le Y local de `cf` (centre du cylindre).
function Kit.cylinder(parent: Instance, name: string, height: number, diameter: number, cf: CFrame, color: Color3, props: { [string]: any }?): Part
	local part = Build.part(parent, name, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.rad(90)), color, props)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Pièce (monnaie) dorée : un disque posé à plat.
function Kit.coin(parent: Instance, cf: CFrame, diameter: number?): Part
	local d = diameter or 1.6
	local coin = Kit.cylinder(parent, "Coin", 0.3, d, cf, C.Gold, { Material = Enum.Material.Metal, Reflectance = 0.2, CanCollide = false, CanQuery = false })
	return coin
end

function Kit.light(parent: Instance, color: Color3, range: number, brightness: number?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1.5
	light.Shadows = false
	light.Parent = parent
	return light
end

------------------------------------------------------------------------
-- Sols (aucun picot : planches, dalles, marbre)
------------------------------------------------------------------------

-- Dallage : `cf` = centre de la surface (dessus du sol), dalles de `tile` studs séparées par
-- des joints sombres. `colors` est une liste de teintes tirées au hasard (motif irrégulier).
function Kit.tiles(parent: Instance, cf: CFrame, sizeX: number, sizeZ: number, tile: number, colors: { Color3 }, material: Enum.Material, rng: Random, opts: { [string]: any }?)
	local o = opts or {}
	local thickness = o.thickness or 0.6
	local joint = o.joint or 0.35
	local jointColor = o.jointColor or C.Joint
	local folder = Build.model(parent, o.name or "Dallage")
	Build.part(folder, "Joints", Vector3.new(sizeX, thickness, sizeZ), cf * CFrame.new(0, -thickness / 2 - 0.05, 0), jointColor, { Material = Enum.Material.Concrete })
	local nx = math.max(1, math.floor(sizeX / tile + 0.5))
	local nz = math.max(1, math.floor(sizeZ / tile + 0.5))
	local tx, tz = sizeX / nx, sizeZ / nz
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			local color = colors[rng:NextInteger(1, #colors)]
			if o.checker then
				color = colors[((ix + iz) % #colors) + 1]
			end
			local lift = o.flat and 0 or rng:NextNumber(0, 0.06)
			Build.part(
				folder,
				"Dalle",
				Vector3.new(tx - joint, thickness, tz - joint),
				cf * CFrame.new(-sizeX / 2 + tx * (ix + 0.5), -thickness / 2 + lift, -sizeZ / 2 + tz * (iz + 0.5)),
				color,
				{ Material = material }
			)
		end
	end
	return folder
end

-- Plancher de bois : lames parallèles à l'axe X local, joints décalés comme un vrai parquet.
function Kit.planks(parent: Instance, cf: CFrame, sizeX: number, sizeZ: number, rng: Random, opts: { [string]: any }?)
	local o = opts or {}
	local width = o.width or 1.6
	local thickness = o.thickness or 0.5
	local colors = o.colors or { C.Wood, C.WoodLight:Lerp(C.Wood, 0.5), C.Wood:Lerp(C.WoodDark, 0.25) }
	local folder = Build.model(parent, o.name or "Plancher")
	Build.part(folder, "Sous-plancher", Vector3.new(sizeX, thickness, sizeZ), cf * CFrame.new(0, -thickness / 2 - 0.05, 0), C.WoodDark, { Material = Enum.Material.Wood })
	local rows = math.max(1, math.floor(sizeZ / width + 0.5))
	local w = sizeZ / rows
	local plankLength = o.length or 12
	for row = 0, rows - 1 do
		local x = -sizeX / 2 - (row % 3) * plankLength / 3
		while x < sizeX / 2 do
			local x0 = math.max(x, -sizeX / 2)
			local x1 = math.min(x + plankLength, sizeX / 2)
			if x1 - x0 > 0.4 then
				Build.part(
					folder,
					"Lame",
					Vector3.new(x1 - x0 - 0.12, thickness, w - 0.14),
					cf * CFrame.new((x0 + x1) / 2, -thickness / 2 + 0.02, -sizeZ / 2 + w * (row + 0.5)),
					colors[rng:NextInteger(1, #colors)],
					{ Material = Enum.Material.WoodPlanks }
				)
			end
			x += plankLength
		end
	end
	return folder
end

-- Bordure de pierre (margelle) le long d'un rectangle centré sur `cf`.
function Kit.curb(parent: Instance, cf: CFrame, sizeX: number, sizeZ: number, width: number, height: number, color: Color3, material: Enum.Material?)
	local m = material or Enum.Material.Cobblestone
	for _, side in { -1, 1 } do
		Build.part(parent, "Bordure", Vector3.new(sizeX + width * 2, height, width), cf * CFrame.new(0, height / 2, side * (sizeZ / 2 + width / 2)), color, { Material = m })
		Build.part(parent, "Bordure", Vector3.new(width, height, sizeZ), cf * CFrame.new(side * (sizeX / 2 + width / 2), height / 2, 0), color, { Material = m })
	end
end

------------------------------------------------------------------------
-- Architecture japonaise
------------------------------------------------------------------------

-- Toit à deux pans. `cf` = centre du bas du toit ; la faîtière suit l'axe X local.
-- `curve` relève légèrement les bords (avant-toits typiques des temples).
function Kit.roof(parent: Instance, cf: CFrame, width: number, depth: number, height: number, color: Color3?, opts: { [string]: any }?)
	local o = opts or {}
	local c = color or C.RoofTile
	local model = Build.model(parent, o.name or "Toit")
	for _, side in { -1, 1 } do
		Build.wedge(
			model,
			"Pan",
			Vector3.new(width, height, depth / 2),
			cf * CFrame.new(0, height / 2, side * depth / 4) * CFrame.Angles(0, side > 0 and math.pi or 0, 0),
			c,
			{ Material = Enum.Material.Slate }
		)
		-- Bord de l'avant-toit (épais, plus sombre) : donne l'aspect « tuiles ».
		Build.part(model, "Rive", Vector3.new(width + 0.4, 0.5, 1), cf * CFrame.new(0, 0.1, side * (depth / 2 - 0.4)), C.RoofTileDark, { Material = Enum.Material.Slate })
		if o.curve ~= false then
			for _, end_ in { -1, 1 } do
				Build.wedge(
					model,
					"Relevé",
					Vector3.new(0.8, 0.9, 1.6),
					cf * CFrame.new(end_ * (width / 2 + 0.2), 0.45, side * (depth / 2 - 0.6)) * CFrame.Angles(0, side > 0 and 0 or math.pi, 0),
					C.RoofTileDark,
					{ Material = Enum.Material.Slate }
				)
			end
		end
	end
	Build.part(model, "Faîtière", Vector3.new(width + 1.2, 0.8, 1.1), cf * CFrame.new(0, height + 0.15, 0), C.RoofTileDark, { Material = Enum.Material.Slate })
	if o.ornament then
		for _, end_ in { -1, 1 } do
			Build.part(model, "Shachi", Vector3.new(0.8, 1.4, 0.8), cf * CFrame.new(end_ * (width / 2 + 0.4), height + 0.9, 0), C.Gold, { Material = Enum.Material.Metal })
		end
	end
	return model
end

-- Avant-toit à quatre pentes (pagode) autour d'un carré de côté `size` ; `cf` = centre, bas du toit.
function Kit.eave(parent: Instance, cf: CFrame, size: number, overhang: number, height: number, color: Color3?)
	local c = color or C.RoofTile
	local model = Build.model(parent, "AvantToit")
	local outer = size + overhang * 2
	for i = 0, 3 do
		local rot = cf * CFrame.Angles(0, i * math.pi / 2, 0)
		Build.wedge(
			model,
			"Pente",
			Vector3.new(outer, height, overhang + 0.6),
			rot * CFrame.new(0, height / 2, -(size / 2 + overhang / 2 - 0.3)),
			c,
			{ Material = Enum.Material.Slate }
		)
		Build.part(model, "Rive", Vector3.new(outer + 0.3, 0.45, 0.7), rot * CFrame.new(0, 0.1, -(size / 2 + overhang - 0.1)), C.RoofTileDark, { Material = Enum.Material.Slate })
		Build.wedge(
			model,
			"Relevé",
			Vector3.new(0.7, 0.9, 1.4),
			rot * CFrame.new(outer / 2 - 0.2, 0.4, -(size / 2 + overhang - 0.4)),
			C.RoofTileDark,
			{ Material = Enum.Material.Slate }
		)
	end
	Build.part(model, "Coeur", Vector3.new(size + 0.2, height, size + 0.2), cf * CFrame.new(0, height / 2, 0), c, { Material = Enum.Material.Slate })
	return model
end

-- Mur d'enceinte de château japonais : soubassement en pierre, mur blanchi, chaperon de tuiles.
-- `a` et `b` = positions au sol (monde). Hauteur totale ≈ `height`.
function Kit.castleWall(parent: Instance, a: Vector3, b: Vector3, height: number?)
	local h = height or 9
	local delta = b - a
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end
	local model = Build.model(parent, "Rempart")
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0) -- longueur sur X
	local stoneH = h * 0.38
	Build.part(model, "Soubassement", Vector3.new(length + 1.2, stoneH, 3.4), cf * CFrame.new(0, stoneH / 2, 0), C.StoneMid, { Material = Enum.Material.Cobblestone })
	Build.part(model, "Corniche", Vector3.new(length + 1.2, 0.4, 3.0), cf * CFrame.new(0, stoneH + 0.2, 0), C.StoneDark, { Material = Enum.Material.Slate })
	local plasterH = h - stoneH - 1.6
	Build.part(model, "Enduit", Vector3.new(length + 0.4, plasterH, 2.2), cf * CFrame.new(0, stoneH + 0.4 + plasterH / 2, 0), C.Plaster, { Material = Enum.Material.Plaster })
	-- Poutres apparentes + meurtrières.
	local posts = math.max(1, math.floor(length / 8))
	for i = 0, posts do
		local x = -length / 2 + length * i / posts
		Build.deco(model, "Poteau", Vector3.new(0.6, plasterH, 2.35), cf * CFrame.new(x, stoneH + 0.4 + plasterH / 2, 0), C.WoodDark, { Material = Enum.Material.Wood })
		if i < posts then
			for _, side in { -1, 1 } do
				Build.deco(
					model,
					"Meurtrière",
					Vector3.new(0.9, 0.9, 0.1),
					cf * CFrame.new(x + length / posts / 2, stoneH + 0.4 + plasterH * 0.55, side * 1.13),
					C.WoodDark,
					{ Material = Enum.Material.Wood }
				)
			end
		end
	end
	Kit.roof(model, cf * CFrame.new(0, h - 1.25, 0), length + 1.6, 4.4, 1.3, C.RoofTile, { curve = false })
	return model
end

-- Lanterne de pierre (tōrō). `cf` = base au sol.
function Kit.toro(parent: Instance, cf: CFrame, scale: number?, glow: Color3?)
	local s = scale or 1
	local light = glow or rgb(255, 196, 110)
	local model = Build.model(parent, "Toro")
	local stone = C.StoneMid
	Build.part(model, "Socle", Vector3.new(2.6, 0.6, 2.6) * s, cf * CFrame.new(0, 0.3 * s, 0), C.StoneDark, { Material = Enum.Material.Slate })
	Kit.cylinder(model, "Fût", 3 * s, 1.1 * s, cf * CFrame.new(0, 2.1 * s, 0), stone, { Material = Enum.Material.Slate })
	Build.part(model, "Plateau", Vector3.new(2.2, 0.5, 2.2) * s, cf * CFrame.new(0, 3.85 * s, 0), stone, { Material = Enum.Material.Slate })
	local lamp = Build.deco(model, "Lumière", Vector3.new(1.3, 1.3, 1.3) * s, cf * CFrame.new(0, 4.75 * s, 0), light, { Material = Enum.Material.Neon })
	for _, x in { -0.75, 0.75 } do
		for _, z in { -0.75, 0.75 } do
			Build.deco(model, "Montant", Vector3.new(0.35, 1.4, 0.35) * s, cf * CFrame.new(x * s, 4.75 * s, z * s), stone, { Material = Enum.Material.Slate })
		end
	end
	Build.part(model, "Chapeau", Vector3.new(3, 0.45, 3) * s, cf * CFrame.new(0, 5.65 * s, 0), stone, { Material = Enum.Material.Slate })
	Build.part(model, "Chapeau2", Vector3.new(1.9, 0.45, 1.9) * s, cf * CFrame.new(0, 6.05 * s, 0), stone, { Material = Enum.Material.Slate })
	Build.ball(model, "Pointe", 0.8 * s, (cf * CFrame.new(0, 6.6 * s, 0)).Position, stone, { Material = Enum.Material.Slate, CanCollide = false })
	Kit.light(lamp, light, 16 * s, 1.6)
	return model
end

-- Lanterne de papier rouge suspendue (chōchin).
function Kit.paperLantern(parent: Instance, cf: CFrame, color: Color3?, size: number?)
	local s = size or 1
	local c = color or rgb(235, 60, 50)
	local lamp = Kit.blob(parent, "Chochin", Vector3.new(1.4, 1.8, 1.4) * s, cf, c, { Material = Enum.Material.Neon, Transparency = 0.05 })
	Build.deco(parent, "ChochinHaut", Vector3.new(0.9, 0.25, 0.9) * s, cf * CFrame.new(0, 0.95 * s, 0), rgb(30, 25, 25))
	Build.deco(parent, "ChochinBas", Vector3.new(0.9, 0.25, 0.9) * s, cf * CFrame.new(0, -0.95 * s, 0), rgb(30, 25, 25))
	Kit.light(lamp, c:Lerp(rgb(255, 220, 160), 0.4), 10 * s, 1.2)
	return lamp
end

-- Cerisier japonais (sakura) : tronc courbé en plusieurs segments + houppiers arrondis.
function Kit.sakura(parent: Instance, base: Vector3, scale: number, rng: Random, color: Color3?)
	local s = scale
	local pink = color or C.Sakura
	local model = Build.model(parent, "Cerisier")
	local bark = rgb(96, 64, 56)
	local p = base
	local lean = rng:NextNumber(0, math.pi * 2)
	local segments = { { 3.4, 1.3, 0.12 }, { 3, 1.05, 0.28 }, { 2.4, 0.8, 0.4 } }
	for i, seg in segments do
		local len, thick, tilt = seg[1] * s, seg[2] * s, seg[3]
		local dir = Vector3.new(math.cos(lean) * math.sin(tilt), math.cos(tilt), math.sin(lean) * math.sin(tilt))
		local mid = p + dir * len / 2
		Build.part(model, "Tronc", Vector3.new(thick, len + thick * 0.4, thick), CFrame.lookAt(mid, mid + dir) * CFrame.Angles(math.rad(90), 0, 0), bark, {
			Material = Enum.Material.Wood,
			CanCollide = i == 1,
		})
		p += dir * len
		lean += rng:NextNumber(-0.9, 0.9)
	end
	-- Branches secondaires.
	for k = 1, 3 do
		local a = lean + k * 2.1
		local dir = Vector3.new(math.cos(a) * 0.8, 0.6, math.sin(a) * 0.8).Unit
		local len = rng:NextNumber(2.2, 3.2) * s
		local start = p - Vector3.new(0, 1.2 * s, 0)
		local mid = start + dir * len / 2
		Build.deco(model, "Branche", Vector3.new(0.5 * s, len, 0.5 * s), CFrame.lookAt(mid, mid + dir) * CFrame.Angles(math.rad(90), 0, 0), bark, { Material = Enum.Material.Wood })
	end
	-- Houppier : grosses boules + petites boules plus claires.
	local crown = p + Vector3.new(0, 1 * s, 0)
	Kit.blob(model, "Fleurs", Vector3.new(8, 5.2, 8) * s, CFrame.new(crown), pink, { Material = Enum.Material.Grass })
	for k = 1, 7 do
		local a = k * 0.9 + rng:NextNumber(0, 0.5)
		local r = rng:NextNumber(2.6, 3.8) * s
		local offset = Vector3.new(math.cos(a) * r, rng:NextNumber(-1.2, 1.6) * s, math.sin(a) * r)
		local size = rng:NextNumber(3.2, 4.6) * s
		local tone = pink:Lerp(k % 2 == 0 and C.SakuraLight or rgb(240, 140, 180), rng:NextNumber(0.2, 0.6))
		Kit.blob(model, "Fleurs", Vector3.new(size, size * 0.75, size), CFrame.new(crown + offset), tone, { Material = Enum.Material.Grass })
	end
	-- Pétales tombés au sol.
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(1.5, 5) * s
		Build.deco(
			model,
			"Pétales",
			Vector3.new(rng:NextNumber(0.8, 1.6), 0.06, rng:NextNumber(0.8, 1.6)) * s,
			CFrame.new(base + Vector3.new(math.cos(a) * r, 0.04, math.sin(a) * r)) * CFrame.Angles(0, a, 0),
			C.SakuraLight
		)
	end
	return model
end

-- Pin japonais taillé (niwaki) : plateaux de feuillage arrondis.
function Kit.niwaki(parent: Instance, base: Vector3, scale: number, rng: Random)
	local s = scale
	local model = Build.model(parent, "Pin")
	local bark = rgb(90, 64, 50)
	Build.part(model, "Tronc", Vector3.new(0.9, 6, 0.9) * s, CFrame.new(base + Vector3.new(0, 3 * s, 0)) * CFrame.Angles(0, 0, 0.12), bark, { Material = Enum.Material.Wood })
	local greens = { rgb(58, 120, 70), rgb(70, 138, 78), rgb(50, 104, 62) }
	for k, pad in { { 0, 6.4, 0, 4.6 }, { 2.2, 4.4, 0.6, 3.6 }, { -2, 3.6, -0.8, 3.4 }, { 0.4, 7.8, 0.2, 3 } } do
		Kit.blob(
			model,
			"Feuillage",
			Vector3.new(pad[4], pad[4] * 0.5, pad[4]) * s,
			CFrame.new(base + Vector3.new(pad[1], pad[2], pad[3]) * s),
			greens[(k % #greens) + 1]:Lerp(rgb(0, 0, 0), rng:NextNumber(0, 0.08)),
			{ Material = Enum.Material.Grass }
		)
	end
	return model
end

-- Rocher arrondi (ellipsoïdes), pour les jardins.
function Kit.boulder(parent: Instance, base: Vector3, scale: number, rng: Random, color: Color3?)
	local c = color or rgb(150, 148, 146)
	local size = Vector3.new(rng:NextNumber(2.6, 3.6), rng:NextNumber(1.6, 2.4), rng:NextNumber(2.2, 3.2)) * scale
	Kit.blob(parent, "Rocher", size, CFrame.new(base + Vector3.new(0, size.Y * 0.32, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), c, {
		Material = Enum.Material.Slate,
		CanCollide = true,
	})
	local small = size * 0.55
	Kit.blob(
		parent,
		"Rocher",
		small,
		CFrame.new(base + Vector3.new(size.X * 0.55, small.Y * 0.3, size.Z * 0.15)),
		c:Lerp(rgb(255, 255, 255), 0.08),
		{ Material = Enum.Material.Slate }
	)
end

-- Bannière verticale (nobori) sur un mât. `cf` = pied du mât, la bannière s'étend vers +X.
function Kit.nobori(parent: Instance, cf: CFrame, color: Color3, height: number?, emblem: Color3?)
	local h = height or 12
	local model = Build.model(parent, "Nobori")
	Build.part(model, "Mât", Vector3.new(0.45, h, 0.45), cf * CFrame.new(0, h / 2, 0), C.WoodDark, { Material = Enum.Material.Wood })
	Build.deco(model, "Traverse", Vector3.new(3.2, 0.25, 0.25), cf * CFrame.new(1.5, h - 0.4, 0), C.WoodDark, { Material = Enum.Material.Wood })
	local cloth = Build.deco(model, "Tissu", Vector3.new(2.8, h * 0.6, 0.12), cf * CFrame.new(1.65, h - 0.6 - h * 0.3, 0), color, { Material = Enum.Material.Fabric })
	Build.deco(model, "Bande", Vector3.new(2.8, 0.5, 0.14), cf * CFrame.new(1.65, h - 0.85, 0), color:Lerp(rgb(255, 255, 255), 0.6), { Material = Enum.Material.Fabric })
	Build.deco(
		model,
		"Emblème",
		Vector3.new(1.3, 1.3, 0.16),
		cf * CFrame.new(1.65, h - 0.6 - h * 0.22, 0) * CFrame.Angles(0, 0, math.rad(45)),
		emblem or rgb(255, 235, 150),
		{ Material = Enum.Material.Neon }
	)
	local _ = cloth
	return model
end

------------------------------------------------------------------------
-- Boutons d'achat (façon tycoon classique)
------------------------------------------------------------------------

local EFFECT_TEXT = {
	income = function(v)
		return string.format("+%d %% de revenus", math.floor(v * 100 + 0.5))
	end,
	xp = function(v)
		return string.format("+%d %% d'XP", math.floor(v * 100 + 0.5))
	end,
	combatCoins = function(v)
		return string.format("+%d %% de pièces en combat", math.floor(v * 100 + 0.5))
	end,
	hatchSpeed = function(v)
		return string.format("Reliques %d %% plus rapides", math.floor(v * 100 + 0.5))
	end,
	incubators = function(v)
		return string.format("+%d autel de relique", v)
	end,
	team = function(v)
		return string.format("+%d place d'équipe", v)
	end,
	display = function(v)
		return string.format("+%d places d'exposition", v)
	end,
}
local EFFECT_ORDER = { "incubators", "team", "display", "income", "xp", "combatCoins", "hatchSpeed" }

-- « +10 % de revenus · +50 % d'XP »
function Kit.effectText(effect): string
	local bits = {}
	for _, key in EFFECT_ORDER do
		local value = effect and effect[key]
		if value and value ~= 0 and EFFECT_TEXT[key] then
			table.insert(bits, EFFECT_TEXT[key](value))
		end
	end
	return table.concat(bits, " · ")
end

local function corner(parent: Instance, scale: number?, offset: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale or 0, offset or 0)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function text(parent: Instance, name: string, value: string, pos: UDim2, size: UDim2, color: Color3, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Text = value
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = font
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = C.Stroke
	label.Parent = parent
	return label
end

-- Panneau flottant d'un bouton : nom (+ icône), effet, prix dans une pastille verte/rouge.
-- Taille mixte (studs + pixels) : lisible de loin comme de près, à la télé comme sur mobile.
function Kit.priceBoard(adornee: BasePart, title: string, effectLine: string, priceText: string, offset: Vector3): (BillboardGui, { [string]: Instance })
	local gui = Instance.new("BillboardGui")
	gui.Name = "PriceGui"
	gui.Size = UDim2.new(4.6, 120, 2.3, 60)
	gui.StudsOffsetWorldSpace = offset
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	gui.Adornee = adornee
	gui.Parent = adornee

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = C.Panel
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.Parent = gui
	corner(card, 0.16, 0)
	local cardStroke = stroke(card, C.Afford, 3)

	text(card, "Title", title, UDim2.fromScale(0.05, 0.05), UDim2.fromScale(0.9, 0.36), Color3.new(1, 1, 1), Enum.Font.LuckiestGuy)
	text(card, "Effect", effectLine, UDim2.fromScale(0.06, 0.42), UDim2.fromScale(0.88, 0.17), C.TextDim, Enum.Font.GothamBold)

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.Position = UDim2.fromScale(0.14, 0.63)
	pill.Size = UDim2.fromScale(0.72, 0.32)
	pill.BackgroundColor3 = C.Afford
	pill.BorderSizePixel = 0
	pill.Parent = card
	corner(pill, 0.5, 0)
	stroke(pill, C.Stroke, 2)
	local price = text(pill, "Price", priceText, UDim2.fromScale(0.04, 0.08), UDim2.fromScale(0.92, 0.84), Color3.new(1, 1, 1), Enum.Font.LuckiestGuy)

	return gui, { card = card, cardStroke = cardStroke, pill = pill, price = price }
end

-- Socle surélevé + anneau Neon + bouton (« Pad », marcher dessus) + flèche flottante.
-- `cf` = centre au sol. Renvoie le modèle et les éléments à recolorer.
function Kit.buyButton(parent: Instance, cf: CFrame, name: string): (Model, { [string]: Instance })
	local model = Build.model(parent, name)
	local plinth = Kit.cylinder(model, "Socle", 0.9, 7.4, cf * CFrame.new(0, 0.45, 0), C.StoneDark, { Material = Enum.Material.Slate })
	Kit.cylinder(model, "Liseré", 0.2, 7.8, cf * CFrame.new(0, 0.95, 0), C.Gold, { Material = Enum.Material.Metal, CanCollide = false })
	local ring = Kit.cylinder(model, "Anneau", 0.3, 6.6, cf * CFrame.new(0, 1.05, 0), C.Afford, { Material = Enum.Material.Neon, CanCollide = false })
	local pad = Kit.cylinder(model, "Pad", 0.5, 5.2, cf * CFrame.new(0, 1.15, 0), C.Afford, { Material = Enum.Material.SmoothPlastic })
	pad.CanTouch = true
	-- Pièce géante qui tourne au-dessus du bouton (repère visuel de loin).
	local token = Kit.cylinder(model, "Jeton", 0.35, 2.2, cf * CFrame.new(0, 3.6, 0) * CFrame.Angles(math.rad(90), 0, 0), C.Gold, {
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
	})
	token:SetAttribute("SpinAxis", "Y")
	token:SetAttribute("SpinSpeed", 2.4)
	token:SetAttribute("Bob", 0.35)
	CollectionService:AddTag(token, "Spin")
	local glow = Kit.light(ring, C.Afford, 10, 1.4)
	local _ = plinth
	return model, { pad = pad, ring = ring, glow = glow }
end

-- Couleurs « abordable » (vert) / « trop cher » (rouge) du bouton et de son panneau.
function Kit.setAffordable(refs: { [string]: any }, affordable: boolean)
	local main = affordable and C.Afford or C.TooExpensive
	if refs.ring then
		refs.ring.Color = main
	end
	if refs.pad then
		refs.pad.Color = main
	end
	if refs.glow then
		refs.glow.Color = main
	end
	if refs.pill then
		refs.pill.BackgroundColor3 = main
	end
	if refs.cardStroke then
		refs.cardStroke.Color = main
	end
end

------------------------------------------------------------------------
-- Fantôme et animation de construction
------------------------------------------------------------------------

local GHOST_STRIP = {
	"Light",
	"ParticleEmitter",
	"Fire",
	"Smoke",
	"Sparkles",
	"Beam",
	"Trail",
	"BillboardGui",
	"SurfaceGui",
	"ProximityPrompt",
	"Sound",
	"Humanoid",
	"AnimationController",
}

-- Transforme un modèle en « fantôme » semi-transparent (aperçu de ce que le bouton construit).
function Kit.ghostify(root: Instance)
	for _, d in root:GetDescendants() do
		local strip = false
		for _, className in GHOST_STRIP do
			if d:IsA(className) then
				strip = true
				break
			end
		end
		if strip then
			d:Destroy()
		end
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Material = Enum.Material.SmoothPlastic
			d.Color = d.Color:Lerp(C.Ghost, 0.45)
			-- Les grandes pièces plates (sols) restent très discrètes pour ne pas masquer le décor.
			local flat = d.Size.Y < 1.2 and d.Size.X * d.Size.Z > 30
			d.Transparency = math.max(d.Transparency, flat and 0.8 or 0.62)
			for _, tag in d:GetTags() do
				d:RemoveTag(tag)
			end
		end
	end
	if root:IsA("Model") then
		for _, tag in root:GetTags() do
			root:RemoveTag(tag)
		end
	end
end

-- Animation de construction : chaque pièce tombe à sa place (du bas vers le haut, en cascade).
function Kit.animateBuild(root: Instance, duration: number?)
	local total = duration or 1.6
	local parts = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		return
	end
	table.sort(parts, function(a, b)
		return a.CFrame.Y < b.CFrame.Y
	end)
	local step = math.min(0.03, total * 0.6 / #parts)
	for i, part in parts do
		local finalCF = part.CFrame
		local finalT = part.Transparency
		local collide = part.CanCollide
		part.CFrame = finalCF * CFrame.new(0, 8, 0) * CFrame.Angles(0, 0.5, 0)
		part.Transparency = 1
		part.CanCollide = false
		local info = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, (i - 1) * step)
		TweenService:Create(part, info, { CFrame = finalCF, Transparency = finalT }):Play()
		task.delay((i - 1) * step + 0.5, function()
			-- Sécurité : la pièce peut avoir été détruite entre-temps (base libérée).
			pcall(function()
				part.CFrame = finalCF
				part.Transparency = finalT
				part.CanCollide = collide
			end)
		end)
	end
end

------------------------------------------------------------------------
-- Hexagones, étiquettes de rareté, effets
------------------------------------------------------------------------

-- Hexagone plein (« pointe » sur ±X) : union de 3 blocs tournés de 60°.
-- `cf` = centre du dessus ; `radius` = distance centre → sommet.
function Kit.hexTile(parent: Instance, name: string, cf: CFrame, radius: number, height: number, color: Color3, props: { [string]: any }?): { Part }
	local parts = {}
	local w = radius * math.sqrt(3)
	for i = 0, 2 do
		local part = Build.part(parent, name, Vector3.new(radius, height, w), cf * CFrame.Angles(0, math.rad(60 * i), 0) * CFrame.new(0, -height / 2, 0), color, props)
		table.insert(parts, part)
	end
	return parts
end

-- Hexagone dressé (posé verticalement, face vers -Z local de `cf`), pour les gros boutons.
function Kit.hexPlate(parent: Instance, name: string, cf: CFrame, radius: number, depth: number, color: Color3, props: { [string]: any }?): { Part }
	return Kit.hexTile(parent, name, cf * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, depth / 2, 0), radius, depth, color, props)
end

-- Dégradé de couleurs (UIGradient) sur un objet d'interface.
function Kit.gradient(parent: Instance, colors: { Color3 }, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	local keys = {}
	if #colors == 1 then
		keys = { ColorSequenceKeypoint.new(0, colors[1]), ColorSequenceKeypoint.new(1, colors[1]) }
	else
		for i, c in colors do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
		end
	end
	g.Color = ColorSequence.new(keys)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

function Kit.text(parent: Instance, name: string, value: string, pos: UDim2, size: UDim2, color: Color3, font: Enum.Font?, strokeColor: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Text = value
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = font or Enum.Font.LuckiestGuy
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = strokeColor or C.Stroke
	label.Parent = parent
	return label
end

-- Étiquette d'une unité (au-dessus de la tête), style jeux de tirage :
--   lignes = liste de { text, colors = {..} | color, font?, weight (hauteur relative) }
-- Nommée « AnimeTag » : le client n'ajoute alors pas sa propre étiquette.
function Kit.unitTag(adornee: BasePart, lines: { any }, heightStuds: number, offsetY: number, maxDistance: number?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "AnimeTag"
	gui.Adornee = adornee
	gui.Size = UDim2.new(8, 60, heightStuds, 24)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = maxDistance or 90
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui.Parent = adornee
	local total = 0
	for _, line in lines do
		total += line.weight or 1
	end
	local y = 0
	for i, line in lines do
		local h = (line.weight or 1) / total
		local label = Kit.text(gui, line.name or ("Ligne" .. i), line.text, UDim2.fromScale(0, y), UDim2.fromScale(1, h), line.colors and Color3.new(1, 1, 1) or (line.color or Color3.new(1, 1, 1)), line.font)
		if line.colors then
			Kit.gradient(label, line.colors, line.rotation or 90)
		end
		y += h
	end
	return gui
end

-- Silhouette « ??? » d'un emplacement verrouillé (comme les jeux de tirage).
function Kit.silhouetteTag(adornee: BasePart, offsetY: number, caption: string?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Silhouette"
	gui.Adornee = adornee
	gui.Size = UDim2.new(4.2, 0, 5.4, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 110
	gui.Parent = adornee
	local function block(name: string, pos: UDim2, size: UDim2, round: boolean?)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.Position = pos
		frame.Size = size
		frame.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
		frame.BorderSizePixel = 0
		frame.Parent = gui
		local s = Instance.new("UIStroke")
		s.Color = Color3.new(1, 1, 1)
		s.Thickness = 2
		s.Parent = frame
		if round then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = frame
		end
		return frame
	end
	-- Corps R6 : tête, torse, bras, jambes.
	block("Tete", UDim2.fromScale(0.33, 0.02), UDim2.fromScale(0.34, 0.2), true)
	local torso = block("Torse", UDim2.fromScale(0.25, 0.24), UDim2.fromScale(0.5, 0.36))
	block("BrasG", UDim2.fromScale(0.03, 0.24), UDim2.fromScale(0.2, 0.34))
	block("BrasD", UDim2.fromScale(0.77, 0.24), UDim2.fromScale(0.2, 0.34))
	block("JambeG", UDim2.fromScale(0.26, 0.62), UDim2.fromScale(0.23, 0.36))
	block("JambeD", UDim2.fromScale(0.51, 0.62), UDim2.fromScale(0.23, 0.36))
	Kit.text(torso, "Mystere", "???", UDim2.fromScale(0.05, 0.25), UDim2.fromScale(0.9, 0.5), Color3.new(1, 1, 1), Enum.Font.GothamBlack)
	if caption then
		Kit.text(gui, "Legende", caption, UDim2.fromScale(-0.4, 1.0), UDim2.fromScale(1.8, 0.16), Color3.fromRGB(255, 230, 120), Enum.Font.GothamBold)
	end
	return gui
end

-- Émetteur de particules avec les textures intégrées de Roblox.
function Kit.particles(parent: Instance, props: { [string]: any }): ParticleEmitter
	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.LightEmission = 1
	p.Rate = 0
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- Faisceau lumineux animé (la texture défile toute seule, sans script) entre deux points
-- exprimés dans le repère de `part`.
function Kit.beam(part: BasePart, a: Vector3, b: Vector3, props: { [string]: any }): Beam
	local a0 = Instance.new("Attachment")
	a0.Name = "BeamA"
	a0.Position = a
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Name = "BeamB"
	a1.Position = b
	a1.Parent = part
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 4
	beam.TextureSpeed = 1
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Segments = 1
	for key, value in props do
		(beam :: any)[key] = value
	end
	beam.Parent = part
	return beam
end

return Kit
