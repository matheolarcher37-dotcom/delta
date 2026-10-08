-- Construit les persos d'animé au format avatar Roblox R6 CLASSIQUE (comme les avatars des jeux
-- d'animé : "Kid Naruto" de la Boîte à outils, les unités des jeux de tirage...) :
--   * proportions R6 exactes : Torso 2x2x1, bras et jambes 1x2x1, tête classique (Part 2x1x1 +
--     SpecialMesh "Head" à l'échelle 1.25), articulations officielles ("Neck", "Left Shoulder"...) :
--     les animations par défaut de Roblox fonctionnent dessus ;
--   * visage façon décalque d'animé, dessiné par Painter sur des plaques invisibles qui épousent
--     la courbe de la tête (il suit la tête de face comme de 3/4) ;
--   * vêtements façon "Shirt / Pants" classiques peints sur toutes les faces (Painter.dress) ;
--   * coiffures en volume (calotte + mèches en deux tons) et accessoires 3D.
--
-- Le modèle est construit pieds au sol en (0,0,0), face vers -Z, puis déplacé via PivotTo.
-- Pour remplacer un perso par ton propre modèle (fait dans Studio ou avec des objets du catalogue),
-- voir Config/Avatars.luau et le dossier ModelesPersos (README).

local Painter = require(script.Parent.Painter)

local CharacterBuilder = {}

local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(25, 22, 28)
local METAL = Color3.fromRGB(190, 198, 210)
local GOLD = Color3.fromRGB(255, 200, 60)

-- Tête classique : la pièce fait 2x1x1, le maillage "Head" (échelle 1.25) se voit comme un
-- cylindre vertical arrondi de 1.2 x 1.2 x 1.2 studs centré sur la pièce.
local HEAD_PART = Vector3.new(2, 1, 1)
local HEAD_MESH_SCALE = Vector3.new(1.25, 1.25, 1.25)
local HEAD_R = 0.6 -- rayon visible
local HEAD_H = 1.2 -- hauteur visible
local TOP = HEAD_H / 2
local FRONT = -HEAD_R
-- Rayon d'un objet qui entoure la tête (bandeau, masque...) : au-dessus des plaques du visage.
local WRAP_R = 0.665

-- Plaques du visage : 6 facettes de 20° (de -60° à +60°) qui suivent la courbe de la tête.
local FACETS = 6
local FACE_ARC = math.rad(120)
local FACE_EDGE_R = 0.645
local FACE_Y0, FACE_Y1 = -0.5, 0.46
CharacterBuilder.Face = {
	width = HEAD_R * FACE_ARC, -- largeur "déroulée" du visage (studs le long de la courbe)
	height = FACE_Y1 - FACE_Y0,
	centerY = (FACE_Y0 + FACE_Y1) / 2, -- hauteur du centre des plaques (repère de la tête)
}

CharacterBuilder.RootHeight = 3 -- hauteur du HumanoidRootPart au-dessus du sol (échelle 1)
CharacterBuilder.Height = 4.5 + TOP -- haut de la tête (échelle 1)
CharacterBuilder.HipHeight = 0 -- R6 : la hauteur vient des jambes
CharacterBuilder.HeadRadius = HEAD_R

local CENTERS = {
	HumanoidRootPart = CFrame.new(0, 3, 0),
	Torso = CFrame.new(0, 3, 0),
	Head = CFrame.new(0, 4.5, 0),
	["Left Arm"] = CFrame.new(-1.5, 3, 0),
	["Right Arm"] = CFrame.new(1.5, 3, 0),
	["Left Leg"] = CFrame.new(-0.5, 1, 0),
	["Right Leg"] = CFrame.new(0.5, 1, 0),
}

local SIZES = {
	HumanoidRootPart = Vector3.new(2, 2, 1),
	Torso = Vector3.new(2, 2, 1),
	Head = HEAD_PART,
	["Left Arm"] = Vector3.new(1, 2, 1),
	["Right Arm"] = Vector3.new(1, 2, 1),
	["Left Leg"] = Vector3.new(1, 2, 1),
	["Right Leg"] = Vector3.new(1, 2, 1),
}

-- Repères officiels des articulations R6.
local ROT_A = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
local ROT_L = CFrame.new(0, 0, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
local ROT_R = CFrame.new(0, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)

local JOINTS = {
	{ "RootJoint", "HumanoidRootPart", "Torso", Vector3.new(0, 0, 0), Vector3.new(0, 0, 0), ROT_A },
	{ "Neck", "Torso", "Head", Vector3.new(0, 1, 0), Vector3.new(0, -0.5, 0), ROT_A },
	{ "Left Shoulder", "Torso", "Left Arm", Vector3.new(-1, 0.5, 0), Vector3.new(0.5, 0.5, 0), ROT_L },
	{ "Right Shoulder", "Torso", "Right Arm", Vector3.new(1, 0.5, 0), Vector3.new(-0.5, 0.5, 0), ROT_R },
	{ "Left Hip", "Torso", "Left Leg", Vector3.new(-1, -1, 0), Vector3.new(-0.5, 1, 0), ROT_L },
	{ "Right Hip", "Torso", "Right Leg", Vector3.new(1, -1, 0), Vector3.new(0.5, 1, 0), ROT_R },
}
CharacterBuilder.JointNames = { "RootJoint", "Neck", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" }

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function scaled(cf: CFrame, s: number): CFrame
	return CFrame.new(cf.Position * s) * cf.Rotation
end

local has = Painter.has

-- Repère dont l'axe Y pointe dans la direction `dir`.
local function alongY(position: Vector3, dir: Vector3): CFrame
	local up = dir.Unit
	local ref = math.abs(up.Y) < 0.95 and Vector3.new(0, 1, 0) or Vector3.new(1, 0, 0)
	local right = ref:Cross(up).Unit
	local back = right:Cross(up).Unit
	return CFrame.fromMatrix(position, right, up, back)
end

------------------------------------------------------------------------
-- Contexte de construction
------------------------------------------------------------------------

local function newContext(model: Model, s: number, paint: string)
	local ctx = { model = model, s = s, limbs = {}, paint = paint, count = 0 }

	local function finish(part: BasePart, limbName: string)
		part.Material = part.Material == Enum.Material.Plastic and Enum.Material.SmoothPlastic or part.Material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Anchored = false
		if ctx.style then
			-- Style imposé à toutes les pièces créées (effets : Neon, transparence...)
			local target: any = part
			for key, value in ctx.style do
				target[key] = value
			end
		end
		part.Parent = model
		local limb = ctx.limbs[limbName]
		if limb then
			local weld = Instance.new("Weld")
			weld.Name = "Weld"
			weld.Part0 = limb
			weld.Part1 = part
			weld.C0 = limb.CFrame:Inverse() * part.CFrame
			weld.Parent = part
		end
		ctx.count += 1
	end

	-- Crée une pièce soudée à un membre. `offset` est relatif au centre du membre (échelle 1).
	function ctx.add(limbName: string, name: string, size: Vector3, offset: CFrame, color: Color3, props: { [string]: any }?): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size * s
		part.CFrame = scaled(CENTERS[limbName] * offset, s)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		if props then
			local target: any = part
			for key, value in props do
				target[key] = value
			end
		end
		finish(part, limbName)
		return part
	end

	-- Ellipsoïde (SpecialMesh "Sphere" étiré à la taille de la pièce).
	function ctx.ball(limbName: string, name: string, size: Vector3, offset: CFrame, color: Color3, props: { [string]: any }?): Part
		local part = ctx.add(limbName, name, size, offset, color, props)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		return part
	end

	-- Cylindre dont l'axe suit l'axe X de `offset`.
	function ctx.cyl(limbName: string, name: string, length: number, diameter: number, offset: CFrame, color: Color3, props: { [string]: any }?): Part
		local part = ctx.add(limbName, name, Vector3.new(length, diameter, diameter), offset, color, props)
		part.Shape = Enum.PartType.Cylinder
		return part
	end

	-- Cylindre vertical (anneau autour de la tête, chapeau...).
	function ctx.vcyl(limbName: string, name: string, height: number, diameter: number, offset: CFrame, color: Color3, props: { [string]: any }?): Part
		return ctx.cyl(limbName, name, height, diameter, offset * CFrame.Angles(0, 0, math.pi / 2), color, props)
	end

	-- Bloc aux arêtes verticales arrondies.
	function ctx.rounded(limbName: string, name: string, size: Vector3, offset: CFrame, color: Color3, radius: number, props: { [string]: any }?)
		local r = math.min(radius, size.X / 2 - 0.01, size.Z / 2 - 0.01)
		local first = ctx.add(limbName, name, Vector3.new(size.X - 2 * r, size.Y, size.Z), offset, color, props)
		ctx.add(limbName, name, Vector3.new(size.X, size.Y, size.Z - 2 * r), offset, color, props)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				ctx.vcyl(limbName, name, size.Y, 2 * r, offset * CFrame.new(sx * (size.X / 2 - r), 0, sz * (size.Z / 2 - r)), color, props)
			end
		end
		return first
	end

	-- Coin (WedgePart) : pente vers l'avant (-Z) et le haut, face verticale à l'arrière.
	function ctx.wedge(limbName: string, name: string, size: Vector3, offset: CFrame, color: Color3): WedgePart
		local part = Instance.new("WedgePart")
		part.Name = name
		part.Size = size * s
		part.CFrame = scaled(CENTERS[limbName] * offset, s)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		finish(part, limbName)
		return part
	end

	-- Lame triangulaire (deux WedgeParts dos à dos) dans le plan (droite, haut) du repère `frame` :
	-- base de largeur `width` en (0,0,0), pointe à `length` le long de l'axe Y.
	local HALF_A = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0))
	local HALF_B = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))
	function ctx.blade(limbName: string, color: Color3, frame: CFrame, length: number, width: number, thickness: number, name: string?)
		for i, half in { HALF_A, HALF_B } do
			local side = i == 1 and 1 or -1
			local cf = frame * CFrame.new(side * width / 4, length / 2, 0) * half
			ctx.wedge(limbName, name or "HairSpike", Vector3.new(thickness, length, width / 2), cf, color)
		end
	end

	-- Coin de pyramide (CornerWedgePart : sommet au coin (+X, +Y, -Z) de la pièce).
	function ctx.cornerWedge(limbName: string, name: string, size: Vector3, offset: CFrame, color: Color3): CornerWedgePart
		local part = Instance.new("CornerWedgePart")
		part.Name = name
		part.Size = size * s
		part.CFrame = scaled(CENTERS[limbName] * offset, s)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		finish(part, limbName)
		return part
	end

	-- Pointe conique : pyramide à base losange faite de 4 CornerWedge (un par quart), sommet sur
	-- l'axe Y du repère `frame` (base en (0,0,0), largeur `width` sur X, épaisseur `depth` sur Z).
	-- Comme les cheveux en maillage des avatars d'animé : arête centrale, une moitié éclairée
	-- (`light`, côté +X du repère) et une moitié dans l'ombre (`dark`).
	-- `half` = 1 ou -1 : demi-pyramide (2 pièces) côté +Z ou -Z seulement, dos plat (posée sur
	-- la calotte ou contre la tête : le dos ne se voit pas).
	local CONE_QUARTERS = {
		-- { signe X, signe Z, rotation autour de Y, axes X/Z échangés }
		{ -1, 1, 0, false },
		{ 1, -1, math.pi, false },
		{ 1, 1, math.pi / 2, true },
		{ -1, -1, -math.pi / 2, true },
	}
	function ctx.cone(limbName: string, frame: CFrame, length: number, width: number, depth: number, light: Color3, dark: Color3?, half: number?, name: string?)
		for _, q in CONE_QUARTERS do
			local sx, sz, turn, swap = q[1], q[2], q[3], q[4]
			if half and sz ~= half then
				continue
			end
			local size = swap and Vector3.new(depth / 2, length, width / 2) or Vector3.new(width / 2, length, depth / 2)
			local cf = frame * CFrame.new(sx * width / 4, length / 2, sz * depth / 4) * CFrame.Angles(0, turn, 0)
			ctx.cornerWedge(limbName, name or "HairSpike", size, cf, sx > 0 and light or (dark or light))
		end
	end

	-- Lumière de référence (haut, côté gauche de l'écran = +X du perso) : choisit la moitié
	-- éclairée d'une pointe.
	local LIGHT = Vector3.new(0.45, 1, -0.35).Unit
	local function litFrame(frame: CFrame): CFrame
		if frame.RightVector:Dot(LIGHT) < 0 then
			return frame * CFrame.Angles(0, math.pi, 0)
		end
		return frame
	end
	ctx.litFrame = litFrame

	-- Teinte de la moitié ombrée d'une mèche.
	local function shadeOf(color: Color3): Color3
		local lum = 0.3 * color.R + 0.59 * color.G + 0.11 * color.B
		if lum < 0.16 then
			return color:Lerp(Color3.new(0, 0, 0), 0.35)
		end
		-- Ombre saturée (comme l'ombrage des cheveux en maillage) : plus sombre, jamais grisâtre
		return Color3.new(color.R * 0.78, color.G * 0.74, color.B * 0.8)
	end
	ctx.shadeOf = shadeOf

	-- Pique de cheveux épaisse partant de `from` dans la direction `dir` : pyramide large tournée
	-- vers l'extérieur (bien lisible de face), ou demi-pyramide à dos plat (`cross = false`,
	-- mèche couchée sur la calotte).
	function ctx.spike(limbName: string, color: Color3, from: Vector3, dir: Vector3, length: number, width: number, o)
		local opts = o or {}
		local d = dir.Unit
		local outward = Vector3.new(from.X, 0, from.Z - 0.05)
		local face = alongY(from, d)
		if outward.Magnitude > 0.05 then
			local n = outward.Unit - d * outward.Unit:Dot(d)
			if n.Magnitude > 0.1 then
				face = CFrame.fromMatrix(from, d:Cross(n.Unit).Unit, d, n.Unit)
			end
		end
		local full = opts.cross ~= false
		local depth = opts.depth or (full and width * 0.62 or math.max(width * 0.5, (opts.thickness or 0.16) * 2.2))
		local dark = opts.dark or shadeOf(color)
		if ctx.hairDarken then
			-- Moitié ombrée plus marquée : chaque pointe se détache de ses voisines (contour)
			dark = dark:Lerp(Color3.new(0.25, 0.18, 0.05), ctx.hairDarken)
		end
		if full then
			ctx.cone(limbName, litFrame(face), length, width, depth, color, dark)
		else
			-- Dos plat contre la calotte : la moitié +Z (vers l'extérieur) seulement.
			local lit = face.RightVector:Dot(LIGHT) >= 0
			ctx.cone(limbName, face, length, width, depth, lit and color or dark, lit and dark or color, 1)
		end
		if opts.tip then
			local tipFrame = face * CFrame.new(0, length * 0.6, 0)
			local k = 0.44
			-- Bout coloré : demi-pyramide côté extérieur seulement (2 pièces au lieu de 4 : budget)
			ctx.cone(limbName, tipFrame, length * 0.4 + 0.01, width * k, depth * k, opts.tip, shadeOf(opts.tip), 1)
		end
	end

	-- Mèches qui jaillissent d'un volume ellipsoïdal (centre, demi-axes) : liste de
	-- { angle autour (degrés, 0 = droite du perso vue de face = -X... voir plus bas), angle depuis
	--   le haut (degrés), longueur, largeur, couleur? }.
	-- Angle autour : 0 = côté +X, 90 = arrière (+Z), 180 = côté -X, 270 = avant (-Z).
	function ctx.burst(limbName: string, center: Vector3, radii: Vector3, color: Color3, list, o)
		local opts = o or {}
		for _, e in list do
			local th, ph = math.rad(e[1]), math.rad(e[2])
			local unit = Vector3.new(math.sin(ph) * math.cos(th), math.cos(ph), math.sin(ph) * math.sin(th))
			local point = center + Vector3.new(unit.X * radii.X, unit.Y * radii.Y, unit.Z * radii.Z) * (opts.sink or 0.8)
			local normal = Vector3.new(unit.X / radii.X, unit.Y / radii.Y, unit.Z / radii.Z).Unit
			local dir = (normal + Vector3.new(0, e[6] or opts.lift or 0.35, 0)).Unit
			ctx.spike(limbName, e[5] or color, point, dir, e[3], e[4], { tip = opts.tip })
		end
	end

	-- Mèche plate qui tombe (frange, mèches qui encadrent le visage) : demi-pyramide à dos plat
	-- contre la tête, arête vers l'extérieur.
	function ctx.lock(limbName: string, color: Color3, from: Vector3, dir: Vector3, length: number, width: number, o)
		local opts = o or {}
		local up = dir.Unit
		local facing = opts.facing or Vector3.new(0, 0, 1)
		local right = up:Cross(facing)
		if right.Magnitude < 0.1 then
			right = Vector3.new(1, 0, 0)
		end
		right = right.Unit
		local back = right:Cross(up).Unit
		local frame = CFrame.fromMatrix(from, right, up, back)
		-- Côté extérieur (loin du centre de la tête) : celui qui se voit.
		local outward = Vector3.new(from.X, 0, from.Z)
		local half = (outward.Magnitude > 0.05 and back:Dot(outward) < 0) and -1 or 1
		local depth = (opts.thickness or 0.14) * 2.4
		local dark = shadeOf(color)
		if ctx.hairDarken then
			dark = dark:Lerp(Color3.new(0.25, 0.18, 0.05), ctx.hairDarken)
		end
		local lit = frame.RightVector:Dot(LIGHT) >= 0
		ctx.cone(limbName, frame, length, width, depth, lit and color or dark, lit and dark or color, half, "HairLock")
		if opts.tip then
			local k = 0.44
			ctx.cone(limbName, frame * CFrame.new(0, length * 0.6, 0), length * 0.4 + 0.01, width * k, depth * k, opts.tip, shadeOf(opts.tip), half, "HairLock")
		end
	end

	-- Mèche arrondie (ellipsoïde), pour les cheveux souples.
	-- `extra` : profondeur (nombre) ou couleur du bout (Color3).
	function ctx.strand(limbName: string, color: Color3, from: Vector3, dir: Vector3, length: number, width: number, extra: any?)
		local d = dir.Unit
		local depth = type(extra) == "number" and extra or width * 0.8
		local part = ctx.ball(limbName, "HairStrand", Vector3.new(width, length, depth), alongY(from + d * (length * 0.45), d), color)
		if typeof(extra) == "Color3" then
			ctx.ball(limbName, "HairStrandTip", Vector3.new(width * 0.72, length * 0.4, depth * 0.75), alongY(from + d * (length * 0.75), d), extra)
		end
		return part
	end

	-- Mèche lisse et souple (cheveux longs ou mi-longs) : suite de 2 à 4 ellipsoïdes plats qui
	-- s'affinent et se courbent (`curl` ajouté à la direction à chaque segment), en deux tons
	-- (le bout plus sombre), avec une bande de reflet claire (`shine`) sur le haut, côté extérieur.
	-- o = { segments, facing (normale sortante), thickness, curl, taper, shine (Color3), dark }
	local function ribbonFrame(center: Vector3, up: Vector3, facing: Vector3): CFrame
		local right = up:Cross(facing)
		if right.Magnitude < 0.05 then
			right = Vector3.new(1, 0, 0)
		end
		right = right.Unit
		return CFrame.fromMatrix(center, right, up, right:Cross(up).Unit)
	end
	function ctx.sleek(limbName: string, color: Color3, from: Vector3, dir: Vector3, length: number, width: number, o)
		local opts = o or {}
		local n = opts.segments or 3
		local facing = opts.facing or Vector3.new(from.X, 0, from.Z)
		if facing.Magnitude < 0.05 then
			facing = Vector3.new(0, 0, -1)
		end
		facing = facing.Unit
		local depth = opts.thickness or math.max(0.1, width * 0.42)
		local curl = opts.curl or Vector3.zero
		local dark = opts.dark or shadeOf(color)
		local d = dir.Unit
		local p = from
		local seg = length / n
		local first
		for i = 1, n do
			local k = 1 - (i - 1) / math.max(1, n - 1) * (opts.taper or 0.5)
			local tone = i == n and color:Lerp(dark, 0.6) or (i == 1 and color or color:Lerp(dark, 0.25))
			local part = ctx.ball(limbName, opts.name or "HairSleek", Vector3.new(width * k, seg * 1.95, depth * k), ribbonFrame(p + d * (seg * 0.5), d, facing), tone)
			first = first or part
			p += d * seg
			if i < n then
				d = (d + curl).Unit
			end
		end
		if opts.point ~= false then
			-- Bout effilé : petite pointe (demi-pyramide côté extérieur) dans le prolongement
			local k = 1 - (opts.taper or 0.5)
			local tone = color:Lerp(dark, 0.6)
			ctx.cone(limbName, ribbonFrame(p - d * (seg * 0.42), d, facing), seg * 0.75, width * k * 0.85, depth * k * 1.6, tone, dark, 1, opts.name or "HairSleek")
		end
		if opts.shine then
			local up = dir.Unit
			local frame = ribbonFrame(from + up * (seg * 0.8), up, facing)
			ctx.ball(limbName, "HairSleekShine", Vector3.new(width * 0.26, seg * 1.15, depth * 0.5), frame * CFrame.new(-width * 0.12, 0, depth * 0.32), opts.shine)
		end
		return first
	end

	-- Peinture (SurfaceGui dans le monde, pièces fines dans les aperçus).
	function ctx.surface(part: BasePart, face: Enum.NormalId, name: string)
		if ctx.paint == "parts" then
			return Painter.canvas(part, face)
		end
		local gui = Instance.new("SurfaceGui")
		gui.Name = name
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.LightInfluence = 1
		-- Au-delà d'environ 55 studs (x la taille du perso) un visage ne fait que quelques pixels :
		-- inutile de faire dessiner des centaines de SurfaceGui aux consoles et aux mobiles.
		gui.MaxDistance = 55 * math.max(1, ctx.s or 1)
		gui.ClipsDescendants = true
		gui.Parent = part
		return gui
	end

	return ctx
end

------------------------------------------------------------------------
-- Corps R6
------------------------------------------------------------------------

-- Plaques invisibles qui portent le visage : chaque facette couvre une portion [u0, u1]
-- de la largeur "déroulée" du visage (u = 0 à gauche vue de face, 1 à droite).
local function facePlates(ctx)
	local plates = {}
	local half = FACE_ARC / FACETS / 2
	local apothem = FACE_EDGE_R * math.cos(half)
	local width = 2 * FACE_EDGE_R * math.sin(half)
	for i = 0, FACETS - 1 do
		local u0, u1 = i / FACETS, (i + 1) / FACETS
		-- angle depuis l'avant, positif vers la droite de l'observateur (-X)
		local phi = ((u0 + u1) / 2 - 0.5) * FACE_ARC
		local cf = CFrame.new(-math.sin(phi) * apothem, (FACE_Y0 + FACE_Y1) / 2, -math.cos(phi) * apothem) * CFrame.Angles(0, phi, 0)
		local plate = ctx.add("Head", "FacePlate", Vector3.new(width, FACE_Y1 - FACE_Y0, 0.02), cf, WHITE, { Transparency = 1, CastShadow = false })
		table.insert(plates, { part = plate, u0 = u0, u1 = u1 })
	end
	return plates
end

local function buildBody(ctx, look)
	local model, s = ctx.model, ctx.s
	local skin = look.skin or Color3.fromRGB(255, 216, 180)
	-- Couleur de base de chaque membre (sous la tenue peinte sur toutes les faces).
	local base = Painter.limbColors(look)
	local colors = {
		HumanoidRootPart = WHITE,
		Torso = base.Torso,
		Head = skin,
		["Left Arm"] = base.Arm,
		["Right Arm"] = base.Arm,
		["Left Leg"] = base.Leg,
		["Right Leg"] = base.Leg,
	}

	for name, size in SIZES do
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size * s
		part.CFrame = scaled(CENTERS[name], s)
		part.Color = colors[name]
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanTouch = false
		part.Anchored = false
		if name == "HumanoidRootPart" then
			part.Transparency = 1
			part.CanCollide = true
			part.CanQuery = true
			part.Massless = false
			part.RootPriority = 127
		else
			part.CanCollide = false
			part.CanQuery = name == "Torso" or name == "Head"
			part.Massless = true
		end
		if name == "Head" then
			-- Tête Roblox classique
			local mesh = Instance.new("SpecialMesh")
			mesh.Name = "Mesh"
			mesh.MeshType = Enum.MeshType.Head
			mesh.Scale = HEAD_MESH_SCALE
			mesh.Parent = part
		end
		part.Parent = model
		ctx.limbs[name] = part
		ctx.count += 1
	end

	for _, joint in JOINTS do
		local name, parentName, childName, c0, c1, rot = joint[1], joint[2], joint[3], joint[4], joint[5], joint[6]
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = ctx.limbs[parentName]
		motor.Part1 = ctx.limbs[childName]
		motor.C0 = CFrame.new(c0 * s) * rot
		motor.C1 = CFrame.new(c1 * s) * rot
		motor:SetAttribute("BaseC0", motor.C0)
		motor.Parent = ctx.limbs[parentName]
	end

	-- Visage (décalque peint sur les plaques) et tenue peinte.
	if not has(look, "boar_head") then
		Painter.face(facePlates(ctx), look, ctx.paint == "parts" and "parts" or nil, CharacterBuilder.Face)
	end
	Painter.dress(ctx.limbs, look, ctx.paint == "parts" and "parts" or nil)
end

------------------------------------------------------------------------
-- Coiffures (repère de la tête : centre de la tête, face vers -Z)
------------------------------------------------------------------------

local function wearsHeadband(look): boolean
	return has(look, "headband") or has(look, "headband_tilted") or has(look, "headband_scratched")
end

-- Teintes des cheveux : dessous sombre (volume), teinte principale, reflets clairs.
local function hairTones(c: Color3, look): (Color3, Color3)
	local lum = 0.3 * c.R + 0.59 * c.G + 0.11 * c.B
	local under, shine
	if lum < 0.16 then
		-- Cheveux noirs : reflets bleutés comme dans les animés
		under = c:Lerp(Color3.new(0, 0, 0), 0.4)
		shine = c:Lerp(Color3.fromRGB(80, 95, 140), 0.3)
	elseif lum > 0.82 and math.max(c.R, c.G, c.B) - math.min(c.R, c.G, c.B) < 0.25 then
		-- Cheveux blancs / argentés : ombres bleu-gris (pas les blonds dorés, très lumineux aussi)
		under = c:Lerp(Color3.fromRGB(150, 160, 195), 0.45)
		shine = WHITE
	else
		-- Dessous plus sombre et plus saturé (un dessous tirant vers le brun se confondait avec la peau)
		under = Color3.new(c.R * 0.72, c.G * 0.66, c.B * 0.7)
		shine = c:Lerp(WHITE, 0.3)
	end
	return look.hairUnder or under, look.hairShine or shine
end
CharacterBuilder.hairTones = hairTones

-- Calotte : volume de cheveux qui recouvre le haut du crâne (front dégagé au-dessus de `hairline`).
-- o = { grow, height, lift, back (false = sans nuque), backLength, color2 (couleur de la nuque) }
local function cap(ctx, color: Color3, o)
	local opts = o or {}
	local grow = opts.grow or 0
	local h = opts.height or 0.84
	ctx.ball("Head", "HairCap", Vector3.new(1.36 + grow, h, 1.38 + grow), CFrame.new(0, 0.5 + (opts.lift or 0), 0.03), color)
	if opts.back ~= false then
		local length = opts.backLength or 1.4
		ctx.ball("Head", "HairNape", Vector3.new(1.24 + grow, length, 0.9 + grow * 0.5), CFrame.new(0, 0.42 - length / 2 + (opts.napeLift or 0), 0.19), opts.color2 or color)
	end
end

-- Mèches de côté (devant les oreilles), de `y` vers le bas.
local function sidelocks(ctx, color: Color3, length: number, width: number?, y: number?, o)
	for _, side in { -1, 1 } do
		ctx.lock(
			"Head",
			color,
			Vector3.new(side * 0.58, y or 0.42, -0.14),
			Vector3.new(side * 0.12, -1, -0.05),
			length,
			width or 0.34,
			{ facing = Vector3.new(side, 0, 0.3), thickness = 0.12, tip = o and o.tip }
		)
	end
end

-- Frange : mèches plates qui tombent sur le front (xs = positions, de gauche à droite vu de face).
local function fringe(ctx, color: Color3, xs: { number }, length: number, width: number, o)
	local opts = o or {}
	for i, x in xs do
		local c = color
		if opts.alt and i % 2 == 0 then
			c = opts.alt
		end
		local z = -math.sqrt(math.max(0, 0.69 * 0.69 - x * x)) - 0.02
		ctx.lock(
			"Head",
			c,
			Vector3.new(x, opts.y or 0.5, z),
			Vector3.new(x * (opts.spread or 0.5), -1, -(opts.out or 0.15)),
			(type(length) == "table" and length[i]) or length,
			width,
			{ facing = Vector3.new(-x * 0.6, 0, 1), thickness = opts.thickness, tip = opts.tip }
		)
	end
end

-- Frange en mèches lisses (cheveux souples) : xs = positions de gauche à droite vu de face.
local function sleekFringe(ctx, color: Color3, xs: { number }, length: any, width: number, o)
	local opts = o or {}
	for i, x in xs do
		local z = -math.sqrt(math.max(0, 0.68 * 0.68 - x * x)) - 0.03
		local dir = Vector3.new(x * (opts.spread or 0.5) + x * (opts.flick or 0), -1, -(opts.out or 0.1))
		ctx.sleek(
			"Head",
			(opts.alt and i % 2 == 0) and opts.alt or color,
			Vector3.new(x, opts.y or 0.58, z),
			dir,
			((type(length) == "table" and length[i]) or length) * (opts.scale or 1),
			width * 0.85,
			{
				segments = 1,
				facing = Vector3.new(x * 0.7, 0, -1),
				thickness = opts.thickness or 0.11,
				taper = 0.3,
			}
		)
	end
end

local HAIR = {}

-- Couronne de pointes vue de face : chaque pointe = { angle dans le plan de face (degrés, 0 = vers
-- le haut, + vers la droite de l'observateur), inclinaison vers l'arrière (degrés, + = arrière),
-- longueur, largeur, couleur?, cross? (lame en travers), r? (enfoncement de la base) }.
local function crown(ctx, color: Color3, center: Vector3, list, o)
	local opts = o or {}
	for _, e in list do
		local a, b = math.rad(e[1]), math.rad(e[2])
		local dir = Vector3.new(-math.sin(a) * math.cos(b), math.cos(a) * math.cos(b), math.sin(b))
		local base = center + dir * (e[7] or opts.r or 0.3)
		ctx.spike("Head", e[5] or color, base, dir, e[3] * (opts.scale or 1), e[4], { tip = e[6] and opts.tip or nil, cross = e[6] or false })
	end
end

-- Mèches couchées en écailles tout autour de la calotte, de la hauteur `y0` vers le haut :
-- elles cachent la calotte lisse et donnent l'aspect "cheveux" (rang avant + côtés/arrière).
-- o = { front = false (pas de rang avant), lift (pente vers le haut), tip }
local function scales(ctx, c: Color3, shine: Color3, under: Color3, y0: number, length: number, o)
	local opts = o or {}
	local lift = opts.lift or 1
	if opts.front ~= false then
		for i, x in { -0.46, -0.23, 0, 0.23, 0.46 } do
			local z = -math.sqrt(math.max(0, 0.36 - x * x)) + 0.06
			ctx.spike("Head", i % 2 == 0 and c or shine, Vector3.new(x, y0, z), Vector3.new(x * 1.2, lift, -0.55), length, 0.5, { cross = false, thickness = 0.16 })
		end
	end
	for i, a in { 20, 55, 90, 125, 160 } do
		local r = math.rad(a)
		ctx.spike(
			"Head",
			i % 2 == 0 and under or c,
			Vector3.new(math.cos(r) * 0.52, y0 - 0.04, math.sin(r) * 0.52 + 0.05),
			Vector3.new(math.cos(r), 0.9 * lift, math.sin(r)),
			length,
			0.52,
			{ cross = false, thickness = 0.16 }
		)
	end
end

HAIR.spiky = function(ctx, c, look)
	-- Tignasse en soleil (Maruto, copie des cheveux en maillage de "Kid Naruto") : éventail de
	-- pointes coniques courtes et larges qui rayonnent tout autour au-dessus du bandeau (silhouette
	-- presque deux fois plus large que la tête, pointes du bord presque horizontales), deuxième rang
	-- décalé derrière, rang arrière couché vers la nuque, petites pointes sous le bandeau dans le dos.
	local under, shine = hairTones(c, look)
	local tip = look.hairTip
	local band = wearsHeadband(look)
	local L = look.hairLength or 1
	local base = band and 0.52 or 0.46
	-- Volume plein (aucun bout de crâne ne doit se voir entre les pointes, même de dos)
	ctx.ball("Head", "HairCap", Vector3.new(1.26, 0.5, 1.3), CFrame.new(0, base + 0.04, 0.06), under)
	ctx.ball("Head", "HairNape", Vector3.new(1.22, 0.96, 0.62), CFrame.new(0, base - 0.42, 0.36), under)
	-- Rang de devant : pointes qui partent du haut du bandeau et montent vers l'avant (cachent
	-- le dessus du crâne de face, comme une frange dressée).
	for _, e in { { -0.4, 0.2, c }, { -0.14, -0.06, shine }, { 0.14, 0.06, c }, { 0.4, -0.2, shine } } do
		local x = e[1]
		local z = -math.sqrt(math.max(0, 0.4 - x * x)) + 0.1
		ctx.spike("Head", e[3], Vector3.new(x, base - 0.02, z), Vector3.new(x * 1.1 + e[2], 1, -0.5), 0.5 * L, 0.52)
	end
	local center = Vector3.new(0, base - 0.04, -0.06)
	crown(ctx, c, center, {
		-- 1er rang (silhouette de face) : { angle, recul, longueur, largeur, couleur, cône entier, base }
		{ 0, 8, 0.6, 0.52, shine, true, 0.3 },
		{ -22, 6, 0.6, 0.5, nil, true, 0.32 },
		{ 22, 6, 0.6, 0.5, shine, true, 0.32 },
		{ -45, 4, 0.62, 0.5, shine, true, 0.36 },
		{ 45, 4, 0.62, 0.5, nil, true, 0.36 },
		{ -68, 4, 0.6, 0.48, nil, true, 0.42 },
		{ 68, 4, 0.6, 0.48, nil, true, 0.42 },
		{ -90, 8, 0.62, 0.46, nil, true, 0.48 },
		{ 90, 8, 0.62, 0.46, nil, true, 0.48 },
		{ -112, 14, 0.52, 0.42, under, true, 0.5 },
		{ 112, 14, 0.52, 0.42, under, true, 0.5 },
	}, { tip = tip, scale = L })
	crown(ctx, c, center + Vector3.new(0, 0.02, 0.2), {
		-- 2e rang, décalé entre les pointes du premier (donne l'épaisseur de la tignasse)
		{ -11, 34, 0.62, 0.5 },
		{ 11, 34, 0.62, 0.5, shine },
		{ -34, 32, 0.62, 0.5 },
		{ 34, 32, 0.62, 0.5 },
		{ -57, 30, 0.6, 0.48, under },
		{ 57, 30, 0.6, 0.48, under },
		{ -80, 30, 0.56, 0.46 },
		{ 80, 30, 0.56, 0.46 },
	}, { scale = L, r = 0.34 })
	-- Rang arrière : pointes couchées vers l'arrière et vers le bas (dessus du crâne vu de dos)
	-- (deux rangs réguliers, en quinconce : 3 larges pointes en haut, 3 en dessous)
	ctx.burst("Head", Vector3.new(0, base + 0.06, 0.1), Vector3.new(0.6, 0.32, 0.58), c, {
		{ 38, 58, 0.6 * L, 0.56, nil, 0.05 },
		{ 90, 58, 0.62 * L, 0.58, under, 0.05 },
		{ 142, 58, 0.6 * L, 0.56, nil, 0.05 },
		{ 60, 82, 0.56 * L, 0.54, under, -0.22 },
		{ 120, 82, 0.56 * L, 0.54, under, -0.22 },
		{ 90, 84, 0.5 * L, 0.5, nil, -0.3 },
	}, { sink = 0.82 })
	-- Petites pointes dans la nuque (sous le bandeau) : la nuque n'est jamais nue.
	for i, a in { 35, 65, 90, 115, 145 } do
		local r = math.rad(a)
		local from = Vector3.new(math.cos(r) * 0.5, base - 0.42, math.sin(r) * 0.5 + 0.06)
		ctx.spike("Head", i % 2 == 0 and c or under, from, Vector3.new(math.cos(r) * 0.5, -1, math.sin(r) * 0.6), 0.36 * L, 0.36, { cross = false, thickness = 0.14 })
	end
	if not band then
		-- Sans bandeau : frange en pointes sur le front
		fringe(ctx, c, { -0.38, -0.13, 0.13, 0.38 }, { 0.42, 0.5, 0.46, 0.4 }, 0.34, { alt = tip or shine, y = 0.56, spread = 0.7 })
	end
	if look.earLocks then
		-- Deux mèches par côté qui descendent sous le bandeau, devant les oreilles
		for _, side in { -1, 1 } do
			ctx.lock(
				"Head",
				c,
				Vector3.new(side * 0.58, base - 0.36, -0.24),
				Vector3.new(side * 0.14, -1, -0.08),
				0.42,
				0.26,
				{ thickness = 0.1, facing = Vector3.new(side, 0, -0.4) }
			)
			ctx.lock("Head", under, Vector3.new(side * 0.61, base - 0.34, -0.04), Vector3.new(side * 0.2, -1, 0), 0.5, 0.28, { thickness = 0.1, facing = Vector3.new(side, 0, 0) })
		end
	end
end

HAIR.short = function(ctx, c, look)
	-- Coupe courte (sabreur, soldat, élève) : calotte + mèches courtes couchées en écailles,
	-- petite frange ; dessous plus sombre (nuque dégradée).
	local under, shine = hairTones(c, look)
	local L = look.hairLength or 1
	cap(ctx, c, { grow = 0.02, height = 0.8, color2 = under, backLength = 1.15 })
	scales(ctx, c, shine, under, 0.5, 0.4 * L, { lift = 1.1 })
	-- Petites pointes sur le dessus
	crown(ctx, c, Vector3.new(0, 0.62, 0.05), {
		{ -25, -10, 0.36, 0.44, shine },
		{ 20, 10, 0.36, 0.44 },
		{ 0, 50, 0.34, 0.44, under },
	}, { scale = L })
	fringe(ctx, c, { -0.3, -0.06, 0.2 }, { 0.26, 0.32, 0.26 }, 0.32, { alt = shine, y = 0.54, spread = 0.6 })
end

HAIR.wild = function(ctx, c, look)
	-- Grandes pointes dressées (guerrier, sorcier aux cheveux blancs, ninja copieur...)
	local under, shine = hairTones(c, look)
	local tip = look.hairTip
	local tilt = look.hairTilt or 0
	local L = look.hairLength or 1
	cap(ctx, c, { color2 = under, backLength = 1.0, napeLift = 0.1 })
	scales(ctx, c, shine, under, 0.5, 0.46 * L, { front = false, tip = tip })
	-- Frange en pointes
	fringe(ctx, c, { -0.36, -0.1, 0.16, 0.4 }, { 0.5, 0.44, 0.4, 0.46 }, 0.36, { alt = shine, y = 0.56, spread = 0.75, out = 0.25, tip = tip })
	ctx.burst("Head", Vector3.new(0, 0.62, 0.05), Vector3.new(0.6, 0.34, 0.62), c, {
		{ 0, 0, 0.95 * L, 0.6, nil, 1 },
		{ 270, 30, 0.85 * L, 0.56, shine, 0.9 },
		{ 225, 35, 0.95 * L, 0.58, nil, 0.8 },
		{ 315, 35, 0.95 * L, 0.58, shine, 0.8 },
		{ 180, 50, 0.9 * L, 0.56, nil, 0.6 },
		{ 0, 50, 0.9 * L, 0.56, nil, 0.6 },
		{ 135, 45, 0.9 * L, 0.56, under, 0.7 },
		{ 45, 45, 0.9 * L, 0.56, under, 0.7 },
		{ 90, 40, 0.9 * L, 0.56, under, 0.6 },
		{ 160, 80, 0.7 * L, 0.5, under, 0.3 },
		{ 20, 80, 0.7 * L, 0.5, under, 0.3 },
		{ 200, 75, 0.62 * L, 0.48, nil, 0.35 },
		{ 340, 75, 0.62 * L, 0.48, nil, 0.35 },
	}, { tip = tip, sink = 0.75, lift = 0.6 })
	if tilt ~= 0 then
		-- Mèches couchées d'un côté (ninja copieur)
		ctx.spike("Head", c, Vector3.new(0, 0.85, 0.05), Vector3.new(tilt * 2, 1, 0.2), 0.9 * L, 0.6, { tip = tip })
		ctx.spike("Head", shine, Vector3.new(tilt * 0.3, 0.8, -0.2), Vector3.new(tilt * 2.2, 0.8, -0.2), 0.8 * L, 0.55, { tip = tip })
	end
	for _, side in { -1, 1 } do
		ctx.spike("Head", c, Vector3.new(side * 0.55, 0.35, 0.0), Vector3.new(side, -0.2, 0.15), 0.5 * L, 0.42, { tip = tip })
	end
	ctx.spike("Head", under, Vector3.new(0, 0.15, 0.55), Vector3.new(0, -0.4, 1), 0.6 * L, 0.5, { tip = tip })
	-- Pointes de la nuque (le dos de la tête ne doit pas être une boule lisse)
	for _, side in { -1, 1 } do
		ctx.spike("Head", side < 0 and c or under, Vector3.new(side * 0.32, 0.3, 0.48), Vector3.new(side * 0.55, -0.55, 1), 0.62 * L, 0.48, { tip = tip })
	end
	ctx.spike("Head", c, Vector3.new(0, 0.5, 0.55), Vector3.new(0, -0.1, 1), 0.66 * L, 0.5, { tip = tip })
end

HAIR.mane = function(ctx, c, look)
	-- Grande crinière hérissée qui tombe dans le dos jusqu'aux reins (ermite) : front dégagé,
	-- couronne de pointes, deux longues mèches qui encadrent le visage, trois rangées de pointes
	-- de plus en plus longues dans le dos.
	local under, shine = hairTones(c, look)
	local L = look.hairLength or 1
	cap(ctx, c, { color2 = under, backLength = 1.25, napeLift = 0.1 })
	scales(ctx, c, shine, under, 0.5, 0.4, { front = false })
	fringe(ctx, c, { -0.36, 0.36 }, { 0.34, 0.34 }, 0.32, { alt = shine, y = 0.6, spread = 1.4, out = 0.3 })
	ctx.burst("Head", Vector3.new(0, 0.62, 0.08), Vector3.new(0.6, 0.34, 0.62), c, {
		{ 0, 15, 0.7, 0.5, shine, 0.8 },
		{ 225, 40, 0.75, 0.52, nil, 0.7 },
		{ 315, 40, 0.75, 0.52, shine, 0.7 },
		{ 180, 55, 0.7, 0.5, nil, 0.5 },
		{ 0, 55, 0.7, 0.5, nil, 0.5 },
		{ 135, 50, 0.8, 0.52, under, 0.5 },
		{ 45, 50, 0.8, 0.52, under, 0.5 },
		{ 90, 45, 0.85, 0.54, nil, 0.5 },
	}, { sink = 0.78, lift = 0.5 })
	for _, side in { -1, 1 } do
		ctx.lock("Head", c, Vector3.new(side * 0.58, 0.42, -0.28), Vector3.new(side * 0.12, -1, -0.12), 1.05, 0.4, { thickness = 0.14, facing = Vector3.new(side, 0, -0.4) })
		ctx.lock("Head", shine, Vector3.new(side * 0.6, 0.3, -0.18), Vector3.new(side * 0.2, -1, -0.05), 0.75, 0.22, { thickness = 0.08, facing = Vector3.new(side, 0, -0.4) })
		ctx.spike("Head", under, Vector3.new(side * 0.6, 0.2, 0.15), Vector3.new(side * 0.5, -1, 0.3), 0.9 * L, 0.5, { cross = false })
	end
	for row = 0, 2 do
		for i, x in { -0.42, -0.14, 0.14, 0.42 } do
			local tone = (i + row) % 3 == 0 and shine or ((i + row) % 3 == 1 and c or under)
			local from = Vector3.new(x * (1 - row * 0.12), 0.32 - row * 0.28, 0.5 + row * 0.08)
			ctx.spike("Head", tone, from, Vector3.new(x * 0.45, -1, 0.4 - row * 0.12), (1.1 + row * 0.6) * L, 0.62 - row * 0.04, { cross = false })
		end
	end
end

HAIR.tall_spiky = function(ctx, c, look)
	HAIR.wild(ctx, c, look)
	-- Très longue crinière jusqu'aux jambes.
	for _, x in { -0.3, 0, 0.3 } do
		ctx.spike("Head", c, Vector3.new(x, 0.3, 0.5), Vector3.new(x * 0.3, -1, 0.25), 3.0, 1.0, { tip = look.hairTip })
	end
	ctx.strand("Head", c, Vector3.new(0, 0.4, 0.55), Vector3.new(0, -1, 0.35), 2.4, 1.0)
end

HAIR.ssj3 = function(ctx, c, look)
	-- Super Saiyan 3 : front dégagé, grosses pointes dressées, mèche de frange, et l'immense
	-- crinière qui descend jusqu'au bas du dos en couches de mèches (visible de face derrière les
	-- épaules), deux tons + reflets.
	local under, shine = hairTones(c, look)
	cap(ctx, c, { color2 = under, backLength = 1.2, height = 0.8 })
	scales(ctx, c, shine, under, 0.52, 0.42, { front = false })
	ctx.burst("Head", Vector3.new(0, 0.6, 0.1), Vector3.new(0.6, 0.34, 0.6), c, {
		{ 270, 30, 0.8, 0.58, shine, 0.9 },
		{ 225, 40, 0.85, 0.58, nil, 0.7 },
		{ 315, 40, 0.85, 0.58, shine, 0.7 },
		{ 180, 55, 0.8, 0.56, under, 0.5 },
		{ 0, 55, 0.8, 0.56, under, 0.5 },
		{ 90, 20, 0.7, 0.56, nil, 0.6 },
	}, { sink = 0.75, lift = 0.5 })
	-- Mèche de frange qui tombe entre les yeux
	ctx.spike("Head", c, Vector3.new(0.05, 0.62, -0.5), Vector3.new(0.1, -1, -0.35), 0.62, 0.32, { cross = false, thickness = 0.12 })
	-- Crinière : couche du fond (large) puis couche de dessus, pointes vers le bas
	for i, x in { -0.62, -0.31, 0, 0.31, 0.62 } do
		local len = 3.1 - math.abs(x) * 0.9
		ctx.spike("Head", i % 2 == 0 and under or c, Vector3.new(x * 0.9, 0.15, 0.56), Vector3.new(x * 0.55, -1, 0.32), len, 0.82, { depth = 0.5 })
	end
	for i, x in { -0.4, 0, 0.4 } do
		ctx.spike("Head", i == 2 and shine or c, Vector3.new(x, 0.45, 0.62), Vector3.new(x * 0.4, -1, 0.42), 2.3, 0.7, { cross = false, thickness = 0.2 })
	end
	-- Côtés : mèches qui tombent derrière les épaules (on les voit de face)
	for _, side in { -1, 1 } do
		ctx.spike("Head", c, Vector3.new(side * 0.55, 0.25, 0.2), Vector3.new(side * 0.75, -1, 0.35), 2.2, 0.7, { depth = 0.44 })
		ctx.spike("Head", shine, Vector3.new(side * 0.5, 0.5, -0.05), Vector3.new(side * 0.9, -0.6, 0.2), 0.9, 0.5, { cross = false, thickness = 0.14 })
	end
end

HAIR.spiky_back = function(ctx, c, look)
	-- Mèches qui encadrent le visage + pointes dressées vers l'arrière (ninja vengeur)
	local under, shine = hairTones(c, look)
	cap(ctx, c, { color2 = under, backLength = 1.3 })
	scales(ctx, c, shine, under, 0.48, 0.42, { front = false })
	sidelocks(ctx, c, 0.95, 0.32, 0.5)
	fringe(ctx, c, { -0.32, -0.08, 0.2 }, { 0.62, 0.5, 0.42 }, 0.34, { alt = shine, y = 0.56, spread = 0.6 })
	ctx.burst("Head", Vector3.new(0, 0.55, 0.15), Vector3.new(0.58, 0.36, 0.55), c, {
		{ 90, 40, 0.85, 0.56, nil, 0.1 },
		{ 60, 55, 0.8, 0.54, shine, 0.15 },
		{ 120, 55, 0.8, 0.54, nil, 0.15 },
		{ 30, 75, 0.62, 0.5, under, 0 },
		{ 150, 75, 0.62, 0.5, under, 0 },
		{ 90, 75, 0.7, 0.54, under, -0.1 },
		{ 0, 20, 0.5, 0.48, nil, 0.6 },
	}, { sink = 0.8 })
end

HAIR.long = function(ctx, c, look)
	-- Longs cheveux lisses : frange en mèches souples, longues mèches qui encadrent le visage et
	-- s'écartent au bout, nappe dans le dos découpée en mèches.
	local under, shine = hairTones(c, look)
	local tip = look.hairTip
	cap(ctx, c, { back = false, height = 0.84 })
	local length = look.hairLength or 2.4
	ctx.ball("Head", "HairBack", Vector3.new(1.34, length, 0.6), CFrame.new(0, TOP - 0.1 - length / 2 + 0.25, 0.4), under)
	if tip then
		ctx.ball("Head", "HairTip", Vector3.new(1.18, 0.8, 0.52), CFrame.new(0, TOP - length + 0.1, 0.5), tip)
	end
	-- Mèches du dos (par-dessus la nappe)
	for _, x in { -0.42, 0, 0.42 } do
		ctx.sleek("Head", x == 0 and c or c:Lerp(under, 0.3), Vector3.new(x, 0.35, 0.62), Vector3.new(x * 0.18, -1, 0.1), length - 0.35, 0.56, {
			facing = Vector3.new(x, 0, 1),
			thickness = 0.16,
			curl = Vector3.new(x * 0.1, 0, 0.04),
			taper = 0.35,
		})
	end
	for _, side in { -1, 1 } do
		ctx.ball("Head", "HairSide", Vector3.new(0.28, 1.5, 0.95), CFrame.new(side * 0.6, 0.0, 0.1), under)
		-- Longue mèche qui encadre le visage, qui s'écarte au bout (deux tons + reflet)
		ctx.sleek("Head", c, Vector3.new(side * 0.6, 0.48, -0.3), Vector3.new(side * 0.1, -1, -0.06), 1.45, 0.3, {
			facing = Vector3.new(side, 0, -0.35),
			curl = Vector3.new(side * 0.14, 0, -0.02),
			shine = shine,
		})
		ctx.sleek("Head", c:Lerp(under, 0.4), Vector3.new(side * 0.62, 0.36, 0.1), Vector3.new(side * 0.16, -1, 0.05), 1.6, 0.36, {
			facing = Vector3.new(side, 0, 0.3),
			curl = Vector3.new(side * 0.12, 0, 0.02),
		})
	end
	if look.bangs == "blunt" then
		-- Frange droite coupée au-dessus des sourcils (princesse) : mèches courtes et serrées
		sleekFringe(ctx, c, { -0.4, -0.2, 0, 0.2, 0.4 }, { 0.2, 0.24, 0.22, 0.24, 0.2 }, 0.27, { y = 0.66, spread = 0.2, out = 0.02 })
	elseif look.forehead then
		-- Front dégagé, raie au milieu : mèches qui partent vers les tempes
		sleekFringe(ctx, c, { -0.3, -0.12, 0.12, 0.3 }, { 0.4, 0.3, 0.3, 0.4 }, 0.26, { y = 0.62, spread = 2.2, out = 0.06, flick = 0.8 })
	else
		sleekFringe(ctx, c, { -0.36, -0.13, 0.1, 0.34 }, { 0.4, 0.46, 0.44, 0.38 }, 0.34, { alt = shine, y = 0.6, spread = 0.45, scale = look.fringeLength })
	end
end

HAIR.ponytail = function(ctx, c, look)
	-- Cheveux tirés en queue de cheval (Itochi, Mako...) : frange, mèches de côté, longue queue.
	local under, shine = hairTones(c, look)
	cap(ctx, c, { color2 = under, backLength = 1.25 })
	sidelocks(ctx, c, look.sidelockLength or 0.9, 0.3, 0.5)
	fringe(ctx, c, { -0.24, 0.02, 0.26 }, { 0.42, 0.36, 0.3 }, 0.32, { alt = shine, y = 0.56, spread = 0.7 })
	ctx.ball("Head", "HairTie", Vector3.new(0.3, 0.26, 0.26), CFrame.new(0, 0.05, 0.64), darken(c, 0.45))
	ctx.strand("Head", c, Vector3.new(0, 0.05, 0.7), Vector3.new(0, -1, 0.3), look.tailLength or 1.7, 0.42, 0.34)
	ctx.strand("Head", under, Vector3.new(0, -0.1, 0.72), Vector3.new(0, -1, 0.2), (look.tailLength or 1.7) * 0.8, 0.3, 0.3)
end

HAIR.long_bangs = function(ctx, c, look)
	-- Cheveux longs noirs à raie au milieu (ninja au manteau à nuages, copie des cheveux en maillage
	-- d'"Ipachi") : longues mèches souples qui encadrent le visage jusqu'au menton, volume sur la
	-- nuque et les épaules, queue de cheval basse.
	local under, shine = hairTones(c, look)
	cap(ctx, c, { back = false, height = 0.86 })
	ctx.ball("Head", "HairBack", Vector3.new(1.4, 1.5, 0.66), CFrame.new(0, -0.12, 0.36), under)
	ctx.ball("Head", "HairBack", Vector3.new(1.34, 1.3, 0.56), CFrame.new(0, -0.02, 0.46), c)
	for _, side in { -1, 1 } do
		-- Mèches de devant : la raie, puis la longue mèche jusqu'au menton qui s'écarte au bout
		ctx.sleek("Head", c, Vector3.new(side * 0.22, 0.66, -0.6), Vector3.new(side * 0.42, -1, -0.1), 1.15, 0.36, {
			facing = Vector3.new(side * 0.35, 0, -1),
			curl = Vector3.new(side * 0.1, 0, 0),
			shine = shine,
		})
		ctx.sleek("Head", under:Lerp(c, 0.4), Vector3.new(side * 0.56, 0.5, -0.34), Vector3.new(side * 0.16, -1, -0.06), 1.3, 0.38, {
			facing = Vector3.new(side, 0, -0.35),
			curl = Vector3.new(side * 0.1, 0, -0.02),
		})
		-- Volume sur les côtés (cache les oreilles)
		ctx.ball("Head", "HairSide", Vector3.new(0.32, 1.25, 1.0), CFrame.new(side * 0.6, -0.02, 0.1), under)
		-- Mèches qui tombent sur les épaules
		ctx.sleek("Head", c, Vector3.new(side * 0.5, -0.05, 0.35), Vector3.new(side * 0.25, -1, 0.2), 0.95, 0.44, {
			segments = 2,
			facing = Vector3.new(side, 0, 0.6),
			curl = Vector3.new(side * 0.15, 0, 0.05),
		})
	end
	-- Petite mèche au milieu du front
	ctx.sleek("Head", c, Vector3.new(0, 0.68, -0.66), Vector3.new(0.05, -1, -0.12), 0.48, 0.24, { segments = 2, facing = Vector3.new(0, 0, -1), thickness = 0.1 })
	-- Queue de cheval basse
	ctx.ball("Head", "HairTie", Vector3.new(0.3, 0.24, 0.24), CFrame.new(0, -0.45, 0.66), darken(c, 0.45))
	ctx.sleek("Head", c, Vector3.new(0, -0.5, 0.72), Vector3.new(0, -1, 0.15), look.tailLength or 1.3, 0.4, { facing = Vector3.new(0, 0, 1), thickness = 0.3, taper = 0.6 })
end

HAIR.side_ponytail = function(ctx, c, look)
	local under, shine = hairTones(c, look)
	cap(ctx, c, { color2 = under, backLength = 1.25 })
	sidelocks(ctx, c, 0.8, 0.3, 0.5)
	fringe(ctx, c, { -0.3, -0.05, 0.2 }, { 0.4, 0.44, 0.38 }, 0.34, { alt = shine, y = 0.56, spread = 0.4 })
	ctx.ball("Head", "HairTie", Vector3.new(0.26, 0.26, 0.26), CFrame.new(0.62, 0.3, 0.25), darken(c, 0.45))
	ctx.strand("Head", c, Vector3.new(0.7, 0.3, 0.3), Vector3.new(0.4, -1, 0.3), 1.3, 0.42)
end

HAIR.ponytail_spiky = function(ctx, c, look)
	-- Queue d'ananas (stratège) : cheveux tirés vers l'arrière, touffe en pointes en éventail.
	local under, shine = hairTones(c, look)
	cap(ctx, c, { color2 = under, backLength = 1.05, height = 0.8 })
	sidelocks(ctx, c, 0.5, 0.26, 0.45)
	local tie = Vector3.new(0, 0.82, 0.42)
	ctx.ball("Head", "HairTie", Vector3.new(0.3, 0.22, 0.3), CFrame.new(tie) * CFrame.Angles(0.5, 0, 0), darken(c, 0.5))
	local center = tie + Vector3.new(0, 0.05, 0.05)
	for _, e in { { 0, 20, 0.6 }, { -35, 30, 0.55 }, { 35, 30, 0.55 }, { -65, 45, 0.48 }, { 65, 45, 0.48 }, { -15, 55, 0.5 }, { 15, 55, 0.5 } } do
		local a, b = math.rad(e[1]), math.rad(e[2])
		local dir = Vector3.new(-math.sin(a) * math.cos(b), math.cos(a) * math.cos(b), math.sin(b))
		ctx.spike("Head", math.abs(e[1]) > 50 and under or (e[1] == 0 and shine or c), center + dir * 0.06, dir, e[3], 0.36, { cross = false, thickness = 0.16 })
	end
end

HAIR.slick = function(ctx, c, look)
	local under, shine = hairTones(c, look)
	cap(ctx, c, { color2 = under, backLength = 1.3 })
	ctx.lock("Head", shine, Vector3.new(-0.25, 0.62, -0.5), Vector3.new(-1, -0.5, -0.1), 0.5, 0.3)
end

HAIR.slick_up = function(ctx, c, look)
	-- Cheveux dressés vers le haut et l'arrière, côtés plus sombres (fléau, prince guerrier)
	local under, shine = hairTones(c, look)
	cap(ctx, c, { color2 = under, backLength = 1.3, height = 0.82 })
	scales(ctx, c, shine, under, 0.48, 0.5, { lift = 1.8, tip = look.hairTip })
	ctx.burst("Head", Vector3.new(0, 0.64, 0.05), Vector3.new(0.56, 0.32, 0.6), c, {
		{ 270, 30, 0.7, 0.52, shine, 0.9 },
		{ 230, 35, 0.7, 0.5, nil, 0.8 },
		{ 310, 35, 0.7, 0.5, shine, 0.8 },
		{ 0, 0, 0.8, 0.56, nil, 1 },
		{ 180, 50, 0.62, 0.5, nil, 0.7 },
		{ 0, 50, 0.62, 0.5, nil, 0.7 },
		{ 90, 40, 0.65, 0.52, under, 0.6 },
		{ 135, 55, 0.55, 0.48, under, 0.4 },
		{ 45, 55, 0.55, 0.48, under, 0.4 },
	}, { tip = look.hairTip, sink = 0.8 })
end

HAIR.mohawk = function(ctx, c, look)
	-- Crête iroquoise : côtés rasés (ombre courte), haute crête de pointes de l'avant à l'arrière,
	-- étroites de face, larges de profil.
	local under, shine = hairTones(c, look)
	local skin = look.skin or Color3.fromRGB(255, 216, 180)
	cap(ctx, under:Lerp(skin, 0.25), { height = 0.7, backLength = 1.1, grow = -0.02 })
	local crest = {
		{ -0.5, 0.62, -0.55, 0.55, shine },
		{ -0.28, 0.82, -0.25, 0.7, c },
		{ -0.04, 0.88, 0.0, 0.74, shine },
		{ 0.2, 0.84, 0.3, 0.7, c },
		{ 0.42, 0.72, 0.6, 0.62, under },
		{ 0.6, 0.52, 0.9, 0.5, c },
	}
	for _, e in crest do
		local z, y, lean, length, color = e[1], e[2], e[3], e[4], e[5]
		local dir = Vector3.new(0, 1, lean).Unit
		local frame = CFrame.fromMatrix(Vector3.new(0, y, z), Vector3.new(1, 0, 0), dir, Vector3.new(1, 0, 0):Cross(dir))
		ctx.cone("Head", frame, length * (look.hairLength or 1), 0.3, 0.46, color, ctx.shadeOf(color))
	end
	-- Petite frange qui retombe sur le front
	ctx.lock("Head", c, Vector3.new(0, 0.66, -0.6), Vector3.new(0.1, -1, -0.3), 0.32, 0.28, { thickness = 0.1 })
end

HAIR.flame_spiky = function(ctx, c, look)
	-- Crinière de flammes (pilier de la flamme) : mèches dorées à bouts rouges balayées vers l'arrière.
	local under, shine = hairTones(c, look)
	local tip = look.hairTip
	cap(ctx, c, { color2 = under, backLength = 1.35, grow = 0.04 })
	scales(ctx, c, shine, under, 0.5, 0.5, { front = false, tip = tip })
	fringe(ctx, c, { -0.38, -0.12, 0.14, 0.4 }, { 0.5, 0.42, 0.42, 0.5 }, 0.36, { alt = shine, y = 0.58, spread = 0.9, out = 0.3, tip = tip })
	ctx.burst("Head", Vector3.new(0, 0.62, 0.1), Vector3.new(0.6, 0.34, 0.6), c, {
		{ 270, 35, 0.75, 0.55, shine, 0.5 },
		{ 230, 45, 0.8, 0.55, nil, 0.3 },
		{ 310, 45, 0.8, 0.55, nil, 0.3 },
		{ 180, 60, 0.8, 0.55, nil, 0.1 },
		{ 0, 60, 0.8, 0.55, nil, 0.1 },
		{ 135, 55, 0.85, 0.55, under, 0 },
		{ 45, 55, 0.85, 0.55, under, 0 },
		{ 90, 50, 0.85, 0.58, under, -0.1 },
		{ 0, 0, 0.7, 0.55, nil, 0.3 },
	}, { tip = tip, sink = 0.75 })
	for _, side in { -1, 1 } do
		ctx.spike("Head", c, Vector3.new(side * 0.55, 0.3, 0.1), Vector3.new(side, -0.3, 0.4), 0.55, 0.42, { tip = tip })
	end
end

HAIR.flame = function(ctx, c, look)
	-- Prince guerrier : front très dégagé avec une pointe en "V" profonde au milieu du front
	-- (widow's peak), tempes dégarnies, et une flamme VERTICALE étroite et haute (environ 1,6 fois
	-- la hauteur de la tête), en deux couches serrées : rien ne part sur les côtés.
	local under, shine = hairTones(c, look)
	local tip = look.hairTip
	local L = look.hairLength or 1
	cap(ctx, c, { color2 = under, backLength = 0.95, height = 0.78, lift = 0.04, napeLift = 0.12 })
	-- Côtés plaqués et relevés vers le haut (pas de mèches qui débordent)
	for _, side in { -1, 1 } do
		ctx.spike("Head", c, Vector3.new(side * 0.52, 0.36, -0.16), Vector3.new(side * 0.22, 1, 0.32), 0.62, 0.46, { cross = false, thickness = 0.14 })
		ctx.spike("Head", under, Vector3.new(side * 0.5, 0.3, 0.26), Vector3.new(side * 0.2, 1, 0.2), 0.66, 0.5, { cross = false, thickness = 0.14 })
	end
	-- Flamme : couche avant (dressée, presque verticale), couche arrière un peu reculée
	crown(ctx, c, Vector3.new(0, 0.72, 0.1), {
		{ 0, 6, 1.95, 0.8, nil, true },
		{ -13, 4, 1.66, 0.74, shine, true },
		{ 13, 4, 1.72, 0.74, nil, true },
		{ -25, 8, 1.35, 0.7, nil, true },
		{ 25, 8, 1.4, 0.7, shine, true },
		{ -36, 12, 0.95, 0.64, under, true },
		{ 36, 12, 0.98, 0.64, nil, true },
		{ -5, 26, 1.72, 0.74, under, true },
		{ 7, 28, 1.6, 0.72, under, true },
		{ -18, 32, 1.2, 0.66, under },
		{ 18, 32, 1.2, 0.66, under },
	}, { tip = tip, r = 0.2, scale = L })
	-- Pointe en "V" au milieu du front + deux petites pointes de golfes qui la dessinent
	ctx.lock("Head", c, Vector3.new(0, 0.66, -0.6), Vector3.new(0, -1, -0.2), 0.46, 0.42, { thickness = 0.14 })
	ctx.lock("Head", shine, Vector3.new(0, 0.66, -0.63), Vector3.new(0, -1, -0.2), 0.32, 0.16, { thickness = 0.06 })
end

HAIR.goku = function(ctx, c, look)
	-- Guerrier au grand cœur : 4 mèches de frange qui retombent sur le front (deux au milieu qui
	-- s'écartent en fourche), 5-6 grosses pointes qui partent vers l'arrière et sur les côtés en
	-- éventail (silhouette en palmier vue de face), une pointe dressée sur le dessus, nuque courte.
	local under, shine = hairTones(c, look)
	local tip = look.hairTip
	local L = look.hairLength or 1
	cap(ctx, c, { color2 = under, backLength = 0.85, napeLift = 0.16, grow = 0.04 })
	scales(ctx, c, shine, under, 0.5, 0.42 * L, { front = false, tip = tip })
	-- Frange : 4 mèches (gauche-écran longue, fourche au milieu, petite à droite)
	local bangs = {
		{ 0.4, 0.6, 0.66, 1.25, shine },
		{ 0.15, 0.62, 0.74, 0.25, c },
		{ -0.1, 0.62, 0.66, -0.35, c },
		{ -0.36, 0.6, 0.54, -1.05, shine },
	}
	for _, b in bangs do
		local x = b[1]
		local z = -math.sqrt(math.max(0, 0.69 * 0.69 - x * x)) - 0.03
		ctx.lock("Head", b[5], Vector3.new(x, b[2], z), Vector3.new(b[4] * 0.45, -1, -0.28), b[3] * L, 0.38, { facing = Vector3.new(-x * 0.6, 0, 1), thickness = 0.13, tip = tip })
	end
	-- Grosses pointes en éventail : { autour, depuis le haut, longueur, largeur, couleur, levée }
	ctx.burst("Head", Vector3.new(0, 0.6, 0.08), Vector3.new(0.62, 0.36, 0.62), c, {
		{ 8, 52, 1.12 * L, 0.68, shine, 0.55 },
		{ 172, 50, 1.1 * L, 0.68, nil, 0.55 },
		{ 350, 80, 0.98 * L, 0.62, nil, 0.22 },
		{ 190, 80, 0.98 * L, 0.62, under, 0.22 },
		{ 92, 28, 1.08 * L, 0.68, nil, 0.42 },
		{ 50, 62, 1.0 * L, 0.64, under, 0.12 },
		{ 132, 62, 1.0 * L, 0.64, under, 0.12 },
		{ 255, 24, 0.82 * L, 0.6, shine, 0.65 },
	}, { tip = tip, sink = 0.78 })
	-- Nuque courte : deux petites pointes vers le bas et l'arrière
	for _, side in { -1, 1 } do
		ctx.spike("Head", under, Vector3.new(side * 0.26, 0.12, 0.5), Vector3.new(side * 0.4, -0.7, 1), 0.5 * L, 0.42, { cross = false, thickness = 0.14 })
	end
end

HAIR.hedgehog = function(ctx, c, look)
	-- Hérisson en boule (invocateur des ombres) : grosse touffe ronde, pointes moyennes dans
	-- TOUS les sens (dessus, côtés, arrière, jusqu'à la nuque), frange de 3 pointes sur le front.
	local under, shine = hairTones(c, look)
	local L = look.hairLength or 1
	cap(ctx, c, { color2 = under, backLength = 1.15, grow = 0.14, height = 0.96 })
	fringe(ctx, c, { -0.3, -0.04, 0.24 }, { 0.46, 0.54, 0.44 }, 0.38, { alt = shine, y = 0.58, spread = 1.0, out = 0.3 })
	L *= 1.25
	ctx.burst("Head", Vector3.new(0, 0.54, 0.12), Vector3.new(0.7, 0.46, 0.7), c, {
		{ 270, 25, 0.62 * L, 0.52, shine, 0.15 },
		{ 0, 15, 0.66 * L, 0.54, nil, 0 },
		{ 220, 50, 0.62 * L, 0.52, nil, 0 },
		{ 320, 50, 0.62 * L, 0.52, shine, 0 },
		{ 180, 62, 0.66 * L, 0.54, nil, 0 },
		{ 0, 62, 0.66 * L, 0.54, under, 0 },
		{ 135, 45, 0.7 * L, 0.54, nil, 0 },
		{ 45, 45, 0.7 * L, 0.54, shine, 0 },
		{ 90, 40, 0.7 * L, 0.56, nil, 0 },
		{ 150, 95, 0.62 * L, 0.5, under, -0.1 },
		{ 30, 95, 0.62 * L, 0.5, under, -0.1 },
		{ 90, 88, 0.66 * L, 0.54, under, -0.15 },
		{ 195, 100, 0.5 * L, 0.46, nil, -0.2 },
		{ 345, 100, 0.5 * L, 0.46, nil, -0.2 },
	}, { sink = 0.8, lift = 0 })
end

HAIR.wild_long = function(ctx, c, look)
	-- Mi-long en bataille (guerrier légendaire) : frange à épis qui tombe sur les yeux, quelques
	-- pointes sur le dessus, et des mèches épaisses qui retombent sur les épaules et le haut du dos.
	local under, shine = hairTones(c, look)
	local L = look.hairLength or 1
	cap(ctx, c, { color2 = under, backLength = 1.5, grow = 0.06 })
	scales(ctx, c, shine, under, 0.5, 0.42, { front = false })
	fringe(ctx, c, { -0.42, -0.2, 0.02, 0.24, 0.44 }, { 0.5, 0.62, 0.7, 0.6, 0.48 }, 0.34, { alt = shine, y = 0.58, spread = 0.9, out = 0.22 })
	ctx.burst("Head", Vector3.new(0, 0.6, 0.08), Vector3.new(0.6, 0.34, 0.62), c, {
		{ 230, 35, 0.62 * L, 0.54, shine, 0.4 },
		{ 310, 35, 0.62 * L, 0.54, nil, 0.4 },
		{ 90, 35, 0.7 * L, 0.56, nil, 0.3 },
		{ 0, 60, 0.62 * L, 0.54, nil, 0.1 },
		{ 180, 60, 0.62 * L, 0.54, under, 0.1 },
	}, { sink = 0.8 })
	for _, side in { -1, 1 } do
		-- Mèches des côtés jusqu'aux épaules
		ctx.spike("Head", c, Vector3.new(side * 0.6, 0.32, -0.05), Vector3.new(side * 0.35, -1, 0.1), 1.05 * L, 0.5, { cross = false, thickness = 0.16 })
		ctx.spike("Head", under, Vector3.new(side * 0.58, 0.3, 0.3), Vector3.new(side * 0.45, -1, 0.3), 1.2 * L, 0.54, { cross = false, thickness = 0.16 })
	end
	-- Dos : deux rangs de mèches en pointe vers le bas
	for row = 0, 1 do
		for i, x in { -0.4, -0.13, 0.13, 0.4 } do
			local tone = (i + row) % 3 == 0 and shine or ((i + row) % 3 == 1 and c or under)
			ctx.spike(
				"Head",
				tone,
				Vector3.new(x, 0.35 - row * 0.3, 0.52 + row * 0.06),
				Vector3.new(x * 0.5, -1, 0.35),
				(1.0 + row * 0.35) * L,
				0.56,
				{ cross = false, thickness = 0.16 }
			)
		end
	end
end

HAIR.curly = function(ctx, c, look)
	-- Tignasse bouclée (tireur au long nez) : grosses boucles rondes tout autour.
	local under, shine = hairTones(c, look)
	cap(ctx, under, { grow = 0.06, backLength = 1.3 })
	local curls = {
		{ -0.42, 0.66, -0.4 },
		{ 0.0, 0.74, -0.46 },
		{ 0.42, 0.66, -0.4 },
		{ -0.55, 0.62, 0.05 },
		{ 0.55, 0.62, 0.05 },
		{ -0.3, 0.92, 0.05 },
		{ 0.3, 0.92, 0.05 },
		{ 0.0, 0.84, 0.42 },
		{ -0.45, 0.5, 0.42 },
		{ 0.45, 0.5, 0.42 },
		{ -0.66, 0.25, 0.15 },
		{ 0.66, 0.25, 0.15 },
		{ 0, 0.25, 0.62 },
	}
	for i, p in curls do
		ctx.ball("Head", "Curl", Vector3.new(0.52, 0.48, 0.52), CFrame.new(p[1], p[2], p[3]), i % 3 == 1 and shine or c)
	end
end

HAIR.messy = function(ctx, c, look)
	-- Tignasse en bataille (pirate au chapeau de paille...) : mèches courtes en tous sens.
	local under, shine = hairTones(c, look)
	cap(ctx, c, { color2 = under, backLength = 1.3 })
	scales(ctx, c, shine, under, 0.48, 0.42, { front = false })
	fringe(ctx, c, { -0.38, -0.14, 0.1, 0.34 }, { 0.44, 0.52, 0.4, 0.48 }, 0.34, { alt = shine, y = 0.56, spread = 0.9, out = 0.2 })
	ctx.burst("Head", Vector3.new(0, 0.6, 0.05), Vector3.new(0.6, 0.34, 0.62), c, {
		{ 230, 40, 0.42, 0.42, shine, 0.6 },
		{ 320, 50, 0.4, 0.42, nil, 0.4 },
		{ 0, 10, 0.42, 0.44, nil, 0.8 },
		{ 160, 60, 0.42, 0.42, nil, 0.2 },
		{ 20, 65, 0.42, 0.42, nil, 0.1 },
		{ 100, 50, 0.45, 0.44, under, 0.2 },
		{ 60, 70, 0.4, 0.42, under, -0.2 },
		{ 130, 75, 0.4, 0.42, under, -0.3 },
	}, { sink = 0.82 })
	for _, side in { -1, 1 } do
		ctx.spike("Head", c, Vector3.new(side * 0.56, 0.3, -0.05), Vector3.new(side, -0.6, 0.0), 0.36, 0.36)
	end
end

HAIR.cover_eye = function(ctx, c, look)
	-- Mèche qui cache un œil (cuisinier)
	local under, shine = hairTones(c, look)
	cap(ctx, c, { color2 = under, backLength = 1.3 })
	sidelocks(ctx, c, 0.7, 0.3, 0.5)
	ctx.lock("Head", c, Vector3.new(-0.2, 0.62, -0.66), Vector3.new(0.05, -1, -0.15), 0.85, 0.5, { thickness = 0.16, facing = Vector3.new(0.3, 0, 1) })
	ctx.lock("Head", shine, Vector3.new(-0.05, 0.6, -0.69), Vector3.new(-0.1, -1, -0.15), 0.6, 0.26, { thickness = 0.06, facing = Vector3.new(0.3, 0, 1) })
	fringe(ctx, c, { 0.25, 0.42 }, { 0.32, 0.28 }, 0.3, { y = 0.56, spread = 0.8 })
end

HAIR.bun = function(ctx, c, look)
	local under, shine = hairTones(c, look)
	cap(ctx, c, { color2 = under, backLength = 1.25 })
	fringe(ctx, c, { -0.25, 0.02, 0.28 }, 0.4, 0.34, { alt = shine, y = 0.56, spread = 0.5 })
	sidelocks(ctx, c, 0.75, 0.28, 0.5)
	ctx.ball("Head", "Bun", Vector3.new(0.58, 0.52, 0.58), CFrame.new(0, 0.95, 0.35), c)
	ctx.ball("Head", "BunTie", Vector3.new(0.44, 0.1, 0.44), CFrame.new(0, 0.74, 0.3), darken(c, 0.4))
end

HAIR.half_bun = function(ctx, c, look)
	-- Demi-chignon du moine maudit : cheveux tirés en un vrai chignon rond haut sur l'arrière du
	-- crâne, le reste lâché jusqu'aux épaules en mèches souples, mèches couchées en pointes sur le
	-- dessus, et LA longue mèche qui tombe sur le front.
	local under, shine = hairTones(c, look)
	cap(ctx, c, { back = false, height = 0.8, lift = 0.06 })
	ctx.ball("Head", "HairBack", Vector3.new(1.36, 1.5, 0.6), CFrame.new(0, -0.15, 0.4), under)
	-- Dessus : mèches couchées vers l'arrière (pointes en CornerWedge), deux tons
	for i, x in { -0.42, -0.14, 0.14, 0.42 } do
		ctx.spike("Head", i % 2 == 0 and c or c:Lerp(shine, 0.35), Vector3.new(x, 0.6, -0.44), Vector3.new(x * 0.3, -0.08, 1), 0.7, 0.42, { cross = false, thickness = 0.12 })
	end
	-- Nuque : mèches souples qui tombent sur les épaules
	for _, x in { -0.45, -0.15, 0.15, 0.45 } do
		ctx.sleek("Head", x < 0 and c or c:Lerp(under, 0.3), Vector3.new(x, 0.1, 0.6), Vector3.new(x * 0.3, -1, 0.15), 1.3, 0.42, {
			segments = 2,
			facing = Vector3.new(x, 0, 1),
			thickness = 0.16,
			curl = Vector3.new(x * 0.2, 0, 0.05),
		})
	end
	for _, side in { -1, 1 } do
		-- Côtés qui couvrent les oreilles, puis mèches souples qui encadrent le visage
		ctx.ball("Head", "HairSide", Vector3.new(0.28, 1.25, 0.9), CFrame.new(side * 0.6, -0.05, 0.12), under)
		ctx.sleek("Head", c, Vector3.new(side * 0.6, 0.48, -0.24), Vector3.new(side * 0.12, -1, -0.04), 1.35, 0.34, {
			facing = Vector3.new(side, 0, -0.3),
			curl = Vector3.new(side * 0.12, 0, 0),
			shine = shine,
		})
		ctx.sleek("Head", under:Lerp(c, 0.5), Vector3.new(side * 0.6, 0.36, 0.18), Vector3.new(side * 0.2, -1, 0.1), 1.4, 0.4, {
			segments = 2,
			facing = Vector3.new(side, 0, 0.4),
			curl = Vector3.new(side * 0.12, 0, 0.04),
		})
	end
	-- Front dégagé : raie au milieu, deux mèches balayées vers les tempes (pointes couchées)
	for _, side in { -1, 1 } do
		ctx.spike("Head", side < 0 and c or c:Lerp(shine, 0.4), Vector3.new(side * 0.06, 0.64, -0.54), Vector3.new(side, -0.7, 0.2), 0.5, 0.34, { cross = false, thickness = 0.11 })
	end
	-- La longue mèche qui tombe devant (côté droit du perso = gauche de l'écran), souple, en S
	-- (sur le côté du front, le long de la tempe : elle ne barre plus le visage)
	ctx.sleek("Head", c, Vector3.new(0.34, 0.66, -0.58), Vector3.new(0.1, -1, -0.1), 1.0, 0.18, {
		facing = Vector3.new(0.4, 0, -1),
		thickness = 0.08,
		curl = Vector3.new(0.1, 0, 0),
		shine = shine,
	})
	-- Vrai chignon rond + reflet + attache
	ctx.ball("Head", "Bun", Vector3.new(0.7, 0.66, 0.68), CFrame.new(0, 0.88, 0.44), c)
	ctx.ball("Head", "Bun", Vector3.new(0.56, 0.5, 0.54), CFrame.new(0.06, 0.98, 0.52), under:Lerp(c, 0.5))
	ctx.ball("Head", "BunShine", Vector3.new(0.34, 0.14, 0.22), CFrame.new(-0.12, 1.1, 0.26) * CFrame.Angles(0.5, 0, 0.25), shine)
	ctx.ball("Head", "BunTie", Vector3.new(0.5, 0.13, 0.5), CFrame.new(0, 0.66, 0.42) * CFrame.Angles(-0.5, 0, 0), darken(c, 0.5))
end

HAIR.topknot = function(ctx, c, look)
	-- Cheveux courts tirés en chignon haut : mèches couchées tout autour (pas de casque lisse),
	-- petite frange, chignon noué.
	local under, shine = hairTones(c, look)
	cap(ctx, c, { color2 = under, backLength = 1.15, height = 0.74 })
	scales(ctx, c, shine, under, 0.48, 0.36, { lift = 1.6 })
	ctx.ball("Head", "Knot", Vector3.new(0.44, 0.4, 0.44), CFrame.new(0, 0.98, 0.18), c)
	ctx.ball("Head", "KnotTie", Vector3.new(0.34, 0.1, 0.34), CFrame.new(0, 0.82, 0.16), darken(c, 0.5))
	ctx.strand("Head", shine, Vector3.new(0, 1.08, 0.22), Vector3.new(0, 1, 0.5), 0.5, 0.24)
end

HAIR.bowl = function(ctx, c, look)
	-- Coupe au bol bien nette et brillante : frange droite au ras des sourcils, côtés jusqu'à la mâchoire.
	local under, shine = hairTones(c, look)
	ctx.ball("Head", "BowlDome", Vector3.new(1.4, 0.9, 1.42), CFrame.new(0, 0.6, 0.02), c, { Reflectance = 0.05 })
	ctx.vcyl("Head", "Bowl", 0.36, 1.4, CFrame.new(0, 0.42, 0.02), c, { Reflectance = 0.05 })
	-- Côtés et nuque (plus bas que la frange)
	ctx.ball("Head", "BowlBack", Vector3.new(1.3, 1.25, 0.9), CFrame.new(0, 0.12, 0.22), under)
	for _, side in { -1, 1 } do
		ctx.ball("Head", "BowlSide", Vector3.new(0.24, 0.95, 0.85), CFrame.new(side * 0.62, 0.1, 0.02), c)
	end
	-- Reflet en bandeau sur le dessus (cheveux brillants)
	ctx.ball("Head", "BowlShine", Vector3.new(0.7, 0.1, 0.34), CFrame.new(-0.12, 0.86, -0.38) * CFrame.Angles(0.5, 0, 0.12), shine)
end

HAIR.bob = function(ctx, c, look)
	-- Carré lisse (androïde, sorcière au marteau) : volume arrondi jusqu'au menton, mèches souples
	-- qui rentrent vers le cou, frange effilée.
	local under, shine = hairTones(c, look)
	cap(ctx, c, { back = false, height = 0.86 })
	ctx.ball("Head", "HairBob", Vector3.new(1.42, 1.3, 1.1), CFrame.new(0, 0.08, 0.2), under)
	for _, side in { -1, 1 } do
		ctx.sleek("Head", c, Vector3.new(side * 0.6, 0.52, -0.26), Vector3.new(side * 0.12, -1, -0.04), 1.1, 0.42, {
			facing = Vector3.new(side, 0, -0.3),
			curl = Vector3.new(-side * 0.16, 0, -0.02),
			shine = shine,
		})
		ctx.sleek("Head", c:Lerp(under, 0.35), Vector3.new(side * 0.56, 0.4, 0.3), Vector3.new(side * 0.16, -1, 0.12), 0.95, 0.52, {
			segments = 2,
			facing = Vector3.new(side, 0, 0.8),
			curl = Vector3.new(-side * 0.18, 0, 0),
		})
	end
	sleekFringe(ctx, c, { -0.32, -0.1, 0.12, 0.34 }, { 0.44, 0.38, 0.42, 0.36 }, 0.32, { alt = shine, y = 0.6, spread = 0.3, scale = look.fringeLength })
end

HAIR.bald = function(ctx, c, look)
	ctx.ball("Head", "Shine", Vector3.new(0.4, 0.06, 0.26), CFrame.new(-0.2, TOP - 0.02, -0.2), lighten(look.skin or WHITE, 0.45), { Transparency = 0.2 })
	local _ = c
end

HAIR.none = function() end

------------------------------------------------------------------------
-- Accessoires
------------------------------------------------------------------------

local ACC = {}
local bossKit -- (défini plus bas, avec les accessoires des boss)
local PAINTED = {
	"whiskers",
	"tear_lines",
	"extra_eyes",
	"scar_eye",
	"scar_cheek",
	"scar_face",
	"scar_forehead",
	"forehead_mark",
	"dots",
	"facepaint",
	"stitches_forehead",
	"brow_ridge",
	"glasses",
	"cyclops",
	"wristbands",
	"tattoos",
}
for _, name in PAINTED do
	ACC[name] = function() end -- dessinés par Painter
end

-- Peint un motif sur une face d'une pièce (haori, cape...).
local function paintPanel(ctx, part: BasePart, face: Enum.NormalId, painter: (any) -> ())
	painter(ctx.surface(part, face, "Pattern"))
end

-- Symbole de la feuille (village caché) gravé sur la plaque frontale.
local function leafSymbol(canvas, ink: Color3, scratched: boolean, metal: Color3?)
	-- Gravure en creux (trait sombre + liseré clair dessous) : spirale à deux tours, pointe de
	-- feuille en haut à droite, petite queue en bas à gauche.
	local glint = Color3.fromRGB(235, 242, 250)
	-- Aperçus "pièces" (metal fourni) : anneaux pleins (un contour coûte une vingtaine de pièces).
	local lite = metal ~= nil
	for pass = lite and 2 or 1, 2 do
		local col = pass == 1 and glint or ink
		local dy = pass == 1 and 0.025 or 0
		local z = pass == 1 and 2 or 3
		if lite and metal then
			Painter.rect(canvas, 0.47, 0.57, 0.5, 0.56, ink, { corner = 0.5, z = 2 })
			Painter.rect(canvas, 0.47, 0.57, 0.36, 0.42, metal, { corner = 0.5, z = 3 })
			Painter.rect(canvas, 0.5, 0.6, 0.22, 0.24, ink, { corner = 0.5, z = 4 })
			Painter.rect(canvas, 0.5, 0.6, 0.12, 0.14, metal, { corner = 0.5, z = 5 })
			z = 6
		else
			Painter.rect(canvas, 0.47, 0.57 + dy, 0.5, 0.56, col, { corner = 0.5, transparency = 1, stroke = col, strokeThickness = 2, z = z })
			Painter.rect(canvas, 0.5, 0.6 + dy, 0.22, 0.24, col, { corner = 0.5, transparency = 1, stroke = col, strokeThickness = 2, z = z })
		end
		Painter.rect(canvas, 0.53, 0.62 + dy, 0.07, 0.08, col, { corner = 0.5, z = z })
		Painter.rect(canvas, 0.64, 0.42 + dy, 0.24, 0.06, col, { corner = 0.5, rotation = -55, z = z })
		Painter.rect(canvas, 0.77, 0.22 + dy, 0.2, 0.18, col, { rotation = 45, z = z })
		Painter.rect(canvas, 0.26, 0.86 + dy, 0.17, 0.05, col, { corner = 0.5, rotation = 35, z = z })
	end
	if scratched then
		Painter.rect(canvas, 0.5, 0.52, 1.1, 0.08, Color3.fromRGB(45, 45, 55), { rotation = -10, z = 3 })
	end
end

-- Bandeau frontal de ninja : bande nouée autour de la tête + plaque métallique (3 facettes
-- qui suivent la courbe) au symbole de la feuille.
local function headbandBase(ctx, look, tilt: number, scratched: boolean)
	local band = look.headbandColor or Color3.fromRGB(22, 34, 84)
	local y = look.headbandY or 0.4
	local BAND_R = look.headbandRadius or WRAP_R
	local rot = CFrame.Angles(0, 0, tilt)
	local frame = CFrame.new(0, y, 0) * rot
	local bandH = look.headbandHeight or 0.36
	ctx.vcyl("Head", "Headband", bandH, 2 * BAND_R, frame, band)
	-- Tissu plissé : liseré clair en haut, ombre en bas
	ctx.vcyl("Head", "HeadbandEdge", 0.03, 2 * BAND_R + 0.012, frame * CFrame.new(0, bandH / 2 - 0.03, 0), lighten(band, 0.22))
	ctx.vcyl("Head", "HeadbandEdge", 0.03, 2 * BAND_R + 0.012, frame * CFrame.new(0, -bandH / 2 + 0.03, 0), darken(band, 0.35))
	local metal = look.plateColor or METAL
	local ink = Color3.fromRGB(60, 72, 92)
	local plateH = bandH * 0.86
	for i = -1, 1 do
		local a = i * math.rad(24)
		local r = BAND_R + 0.02
		local cf = frame * CFrame.new(-math.sin(a) * r, 0, -math.cos(a) * r) * CFrame.Angles(0, a, 0)
		local plate = ctx.add("Head", "Plate", Vector3.new(0.31, plateH, 0.05), cf, metal, { Material = Enum.Material.Metal, Reflectance = 0.15 })
		paintPanel(ctx, plate, Enum.NormalId.Front, function(canvas)
			-- Métal brossé (reflet en diagonale), rebord gravé, rivets aux coins
			Painter.rect(canvas, 0.5, 0.5, 1, 1, metal, { gradient = { lighten(metal, 0.35), metal, darken(metal, 0.18) }, gradientRotation = 70, z = 1 })
			Painter.rect(canvas, 0.5, 0.05, 1, 0.07, lighten(metal, 0.55), { z = 2 })
			Painter.rect(canvas, 0.5, 0.955, 1, 0.08, darken(metal, 0.45), { z = 2 })
			Painter.rect(canvas, 0.5, 0.13, 1, 0.03, darken(metal, 0.3), { transparency = 0.3, z = 2 })
			Painter.rect(canvas, 0.5, 0.87, 1, 0.03, darken(metal, 0.3), { transparency = 0.3, z = 2 })
			if i ~= 0 then
				local x = i < 0 and 0.18 or 0.82
				local edge = i < 0 and 0.03 or 0.97
				Painter.rect(canvas, edge, 0.5, 0.06, 1, darken(metal, 0.4), { z = 2 })
				for _, ry in { 0.24, 0.76 } do
					Painter.rect(canvas, x, ry, 0.1, 0.1 * 0.31 / plateH, darken(metal, 0.5), { corner = 0.5, z = 3 })
					if ctx.paint ~= "parts" then
						Painter.rect(canvas, x - 0.015, ry - 0.02, 0.04, 0.04, lighten(metal, 0.6), { corner = 0.5, z = 4 })
					end
				end
			else
				leafSymbol(canvas, ink, scratched, ctx.paint == "parts" and metal or nil)
			end
		end)
	end
	-- Nœud dans la nuque et deux pans de tissu plats qui tombent
	ctx.ball("Head", "Knot", Vector3.new(0.22, 0.2, 0.14), frame * CFrame.new(0, 0, BAND_R + 0.04), darken(band, 0.15))
	for _, e in { { -1, 0.55, -0.32 }, { 1, 0.48, 0.38 } } do
		local from = (frame * CFrame.new(e[1] * 0.05, -0.04, BAND_R + 0.05)).Position
		ctx.strand("Head", e[1] < 0 and band or darken(band, 0.2), from, Vector3.new(e[3], -1, 0.35), e[2], 0.17, 0.05)
	end
end

ACC.headband = function(ctx, look)
	headbandBase(ctx, look, 0, false)
end

ACC.headband_tilted = function(ctx, look)
	headbandBase(ctx, look, 0.14, false)
end

ACC.headband_scratched = function(ctx, look)
	headbandBase(ctx, look, 0, true)
end

ACC.headband_belt = function(ctx, look)
	local band = look.headbandColor or Color3.fromRGB(200, 40, 40)
	ctx.add("Torso", "BeltBand", Vector3.new(2.06, 0.3, 1.06), CFrame.new(0, -0.78, 0), band)
	ctx.add("Torso", "BeltPlate", Vector3.new(0.62, 0.28, 0.06), CFrame.new(0, -0.78, -0.56), METAL, { Material = Enum.Material.Metal, Reflectance = 0.2 })
end

ACC.mask_lower = function(ctx, look)
	local cloth = look.maskColor or look.accColor or Color3.fromRGB(45, 50, 65)
	ctx.vcyl("Head", "Mask", 0.5, 2 * WRAP_R, CFrame.new(0, -0.32, 0), cloth)
	ctx.ball("Head", "MaskNose", Vector3.new(0.26, 0.22, 0.14), CFrame.new(0, -0.14, -WRAP_R + 0.01), cloth)
	ctx.vcyl("Head", "MaskTop", 0.03, 2 * WRAP_R + 0.01, CFrame.new(0, -0.07, 0), lighten(cloth, 0.12))
end

ACC.mask_bandage = function(ctx, look)
	local cloth = look.maskColor or Color3.fromRGB(235, 230, 220)
	ctx.vcyl("Head", "Bandage", 0.5, 2 * WRAP_R, CFrame.new(0, -0.32, 0), cloth)
	for i = 0, 2 do
		ctx.vcyl("Head", "BandageWrap", 0.025, 2 * WRAP_R + 0.01, CFrame.new(0, -0.48 + i * 0.13, 0) * CFrame.Angles(0, 0, (i - 1) * 0.06), darken(cloth, 0.18))
	end
end

ACC.blindfold = function(ctx, look)
	local cloth = look.blindColor or Color3.fromRGB(20, 20, 26)
	ctx.vcyl("Head", "Blindfold", 0.34, 2 * WRAP_R, CFrame.new(0, 0.05, 0), cloth)
	ctx.vcyl("Head", "BlindfoldFold", 0.03, 2 * WRAP_R + 0.01, CFrame.new(0, 0.02, 0), lighten(cloth, 0.12))
end

ACC.tattoos_blue = function(ctx, look)
	local ink = look.accColor or Color3.fromRGB(60, 80, 220)
	for _, side in { "Left Arm", "Right Arm" } do
		ctx.add(side, "ArmTattoo", Vector3.new(1.02, 0.07, 1.02), CFrame.new(0, 0.25, 0), ink)
		ctx.add(side, "ArmTattoo", Vector3.new(1.02, 0.07, 1.02), CFrame.new(0, -0.15, 0), ink)
	end
	for _, side in { -1, 1 } do
		ctx.add("Torso", "BodyTattoo", Vector3.new(0.05, 1.6, 1.02), CFrame.new(side * 0.99, 0, 0), ink)
	end
end

ACC.stitches = function(ctx, look)
	local thread = Color3.fromRGB(60, 50, 60)
	ctx.add("Torso", "BodyStitch", Vector3.new(2.02, 0.05, 1.02), CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, 0.35), thread)
	local _ = look
end

ACC.earrings = function(ctx, look)
	-- Boucles d'oreilles "hanafuda" (soleil levant)
	for _, side in { -1, 1 } do
		local x = side * (HEAD_R + 0.03)
		ctx.add("Head", "Earring", Vector3.new(0.04, 0.34, 0.2), CFrame.new(x, -0.3, 0.05), WHITE)
		local sun = ctx.add("Head", "EarringSun", Vector3.new(0.05, 0.12, 0.12), CFrame.new(x + side * 0.005, -0.27, 0.05), Color3.fromRGB(220, 40, 40))
		sun.Shape = Enum.PartType.Cylinder
	end
	local _ = look
end

ACC.earrings_stud = function(ctx, look)
	for _, side in { -1, 1 } do
		ctx.ball("Head", "Stud", Vector3.new(0.1, 0.1, 0.1), CFrame.new(side * (HEAD_R + 0.03), -0.15, 0.05), look.accColor or GOLD, { Material = Enum.Material.Metal })
	end
end

ACC.earrings_gold = function(ctx, look)
	for _, side in { -1, 1 } do
		ctx.ball("Head", "GoldRing", Vector3.new(0.06, 0.22, 0.22), CFrame.new(side * (HEAD_R + 0.04), -0.25, 0.05), GOLD, { Material = Enum.Material.Metal, Reflectance = 0.2 })
	end
	local _ = look
end

ACC.cap = function(ctx, look)
	-- Casquette de marine : calotte cylindrique à bords nets, dessus légèrement bombé, bandeau
	-- bleu marine et visière en biseau (épaisse à la base, fine au bord).
	local color = look.accColor or WHITE
	local band = look.capBand or Color3.fromRGB(40, 60, 140)
	local brim = look.capBrim or Color3.fromRGB(30, 34, 60)
	ctx.vcyl("Head", "Cap", 0.5, 1.44, CFrame.new(0, 0.6, 0.02), color)
	ctx.vcyl("Head", "CapTopRim", 0.05, 1.47, CFrame.new(0, 0.85, 0.02), darken(color, 0.06))
	ctx.ball("Head", "CapDome", Vector3.new(1.44, 0.26, 1.44), CFrame.new(0, 0.86, 0.02), color)
	ctx.vcyl("Head", "CapBand", 0.14, 1.475, CFrame.new(0, 0.42, 0.02), band)
	ctx.vcyl("Head", "CapBandLine", 0.03, 1.48, CFrame.new(0, 0.5, 0.02), darken(band, 0.35))
	-- Visière : coin (pente vers l'avant) + bord inférieur sombre
	ctx.wedge("Head", "Brim", Vector3.new(1.12, 0.13, 0.5), CFrame.new(0, 0.38, -0.92) * CFrame.Angles(math.rad(-6), 0, 0), brim)
	ctx.add("Head", "BrimUnder", Vector3.new(1.1, 0.03, 0.48), CFrame.new(0, 0.31, -0.92) * CFrame.Angles(math.rad(-6), 0, 0), darken(brim, 0.45))
end

ACC.bandana = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(200, 40, 40)
	ctx.ball("Head", "BandanaDome", Vector3.new(1.42, 0.95, 1.44), CFrame.new(0, 0.5, 0.02), color)
	ctx.vcyl("Head", "Bandana", 0.22, 1.42, CFrame.new(0, 0.38, 0.02), color)
	ctx.ball("Head", "BandanaKnot", Vector3.new(0.26, 0.22, 0.2), CFrame.new(0.2, 0.36, 0.74), color)
	ctx.strand("Head", color, Vector3.new(0.22, 0.32, 0.76), Vector3.new(0.3, -1, 0.5), 0.5, 0.18)
end

ACC.turban = function(ctx, look)
	local color = look.accColor or WHITE
	ctx.vcyl("Head", "Turban", 0.5, 1.46, CFrame.new(0, 0.45, 0), color)
	ctx.ball("Head", "TurbanTop", Vector3.new(1.46, 0.85, 1.46), CFrame.new(0, 0.72, 0), color)
	ctx.ball("Head", "TurbanGem", Vector3.new(0.2, 0.2, 0.1), CFrame.new(0, 0.5, -0.74), Color3.fromRGB(150, 60, 200), { Material = Enum.Material.Neon })
end

ACC.straw_hat = function(ctx, look)
	local straw = look.accColor or Color3.fromRGB(240, 210, 110)
	ctx.vcyl("Head", "Brim", 0.08, 2.4, CFrame.new(0, 0.62, 0), straw)
	ctx.vcyl("Head", "Crown", 0.42, 1.38, CFrame.new(0, 0.84, 0), straw)
	ctx.ball("Head", "CrownTop", Vector3.new(1.38, 0.28, 1.38), CFrame.new(0, 1.05, 0), straw)
	ctx.vcyl("Head", "Ribbon", 0.15, 1.4, CFrame.new(0, 0.73, 0), Color3.fromRGB(210, 30, 40))
end

ACC.dome = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(150, 60, 200)
	ctx.ball("Head", "Dome", Vector3.new(1.3, 1.0, 1.3), CFrame.new(0, 0.55, 0.03), color, { Reflectance = 0.2 })
	ctx.ball("Head", "DomeShine", Vector3.new(0.3, 0.16, 0.2), CFrame.new(-0.22, 0.95, -0.3), lighten(color, 0.5))
end

ACC.volcano = function(ctx, look)
	-- Tête-volcan : cône à trois étages qui prolonge le crâne, cratère, lave et fumée.
	local rock = look.volcanoColor or look.skin or Color3.fromRGB(80, 60, 50)
	ctx.vcyl("Head", "Volcano1", 0.4, 1.3, CFrame.new(0, 0.62, 0.02), rock)
	ctx.vcyl("Head", "Volcano2", 0.36, 1.06, CFrame.new(0, 0.96, 0.02), darken(rock, 0.06))
	ctx.vcyl("Head", "Volcano3", 0.3, 0.82, CFrame.new(0, 1.26, 0.02), darken(rock, 0.12))
	ctx.vcyl("Head", "Crater", 0.06, 0.66, CFrame.new(0, 1.42, 0.02), darken(rock, 0.5))
	local lava = ctx.vcyl("Head", "Lava", 0.07, 0.5, CFrame.new(0, 1.44, 0.02), Color3.fromRGB(255, 120, 20), { Material = Enum.Material.Neon })
	ctx.ball("Head", "LavaDrip", Vector3.new(0.12, 0.3, 0.1), CFrame.new(0.22, 1.3, -0.3), Color3.fromRGB(255, 120, 20), { Material = Enum.Material.Neon })
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "VolcanoSmoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(80, 70, 70))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 * ctx.s), NumberSequenceKeypoint.new(1, 1.2 * ctx.s) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(1, 2)
	smoke.Rate = 5
	smoke.Speed = NumberRange.new(1 * ctx.s, 2 * ctx.s)
	smoke.Parent = lava
end

ACC.antennae = function(ctx, look)
	for _, side in { -1, 1 } do
		ctx.strand("Head", look.skin, Vector3.new(side * 0.2, 0.62, -0.28), Vector3.new(side * 0.25, 1, -0.45), 0.75, 0.1)
		ctx.ball("Head", "AntennaTip", Vector3.new(0.12, 0.12, 0.12), CFrame.new(side * 0.38, 1.28, -0.58), look.skin)
	end
end

ACC.horns = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(235, 225, 205)
	for _, side in { -1, 1 } do
		ctx.spike("Head", color, Vector3.new(side * 0.36, 0.55, -0.15), Vector3.new(side * 0.45, 1, -0.1), 0.6, 0.36)
	end
end

local function ears(ctx, color: Color3, inner: Color3, size: number)
	for _, side in { -1, 1 } do
		local cf = CFrame.new(side * 0.38, 0.82, 0.05) * CFrame.Angles(0, 0, -0.35 * side)
		ctx.ball("Head", "AnimalEar", Vector3.new(size * 0.7, size, 0.15), cf, color)
		ctx.ball("Head", "AnimalEarInner", Vector3.new(size * 0.4, size * 0.65, 0.16), cf * CFrame.new(0, -0.04, -0.02), inner)
	end
end

ACC.cat_ears = function(ctx, look)
	ears(ctx, look.hairColor or look.skin, Color3.fromRGB(255, 180, 200), 0.5)
end

ACC.fox_ears = function(ctx, look)
	ears(ctx, look.accColor or Color3.fromRGB(255, 120, 20), Color3.fromRGB(40, 20, 20), 0.62)
end

ACC.scouter = function(ctx, look)
	ctx.add(
		"Head",
		"ScouterLens",
		Vector3.new(0.34, 0.28, 0.04),
		CFrame.new(-0.24, 0.05, -WRAP_R - 0.05),
		Color3.fromRGB(80, 255, 120),
		{ Material = Enum.Material.Neon, Transparency = 0.35 }
	)
	ctx.add("Head", "ScouterBody", Vector3.new(0.14, 0.38, 0.38), CFrame.new(-(HEAD_R + 0.06), 0.05, -0.15), Color3.fromRGB(240, 240, 240))
	ctx.add("Head", "ScouterArm", Vector3.new(0.06, 0.06, 0.42), CFrame.new(-(HEAD_R + 0.04), 0.12, -0.5), Color3.fromRGB(240, 240, 240))
	local _ = look
end

ACC.long_nose = function(ctx, look)
	ctx.ball("Head", "LongNose", Vector3.new(0.14, 0.14, 0.75), CFrame.new(0, -0.15, FRONT - 0.32), look.skin)
end

ACC.saw_nose = function(ctx, look)
	local skin = look.skin
	ctx.add("Head", "SawNose", Vector3.new(0.12, 0.09, 0.85), CFrame.new(0, -0.12, FRONT - 0.4), skin)
	for i = 0, 3 do
		ctx.add("Head", "SawTooth", Vector3.new(0.26, 0.05, 0.07), CFrame.new(0, -0.12, FRONT - 0.12 - i * 0.2), WHITE)
	end
end

ACC.clown_nose = function(ctx, look)
	ctx.ball("Head", "ClownNose", Vector3.new(0.26, 0.24, 0.24), CFrame.new(0, -0.18, FRONT - 0.05), Color3.fromRGB(230, 30, 40))
	local _ = look
end

ACC.muzzle = function(ctx, look)
	-- Bâillon de bambou
	local bamboo = Color3.fromRGB(120, 170, 70)
	ctx.cyl("Head", "Bamboo", 0.95, 0.2, CFrame.new(0, -0.36, -WRAP_R + 0.02), bamboo)
	ctx.cyl("Head", "BambooKnot", 0.05, 0.23, CFrame.new(-0.22, -0.36, -WRAP_R + 0.02), darken(bamboo, 0.3))
	ctx.cyl("Head", "BambooKnot", 0.05, 0.23, CFrame.new(0.22, -0.36, -WRAP_R + 0.02), darken(bamboo, 0.3))
	ctx.vcyl("Head", "BambooString", 0.05, 2 * WRAP_R, CFrame.new(0, -0.36, 0), Color3.fromRGB(200, 60, 60))
	local _ = look
end

ACC.boar_head = function(ctx, look)
	-- Tête de sanglier portée comme un masque
	local fur = look.accColor or Color3.fromRGB(110, 110, 120)
	ctx.ball("Head", "BoarHead", Vector3.new(1.5, 1.45, 1.5), CFrame.new(0, 0.12, 0), fur)
	ctx.ball("Head", "BoarSnout", Vector3.new(0.66, 0.5, 0.5), CFrame.new(0, -0.18, -0.68), lighten(fur, 0.35))
	for _, side in { -1, 1 } do
		ctx.ball("Head", "Nostril", Vector3.new(0.1, 0.16, 0.05), CFrame.new(side * 0.13, -0.18, -0.93), BLACK)
		ctx.ball("Head", "BoarEye", Vector3.new(0.22, 0.22, 0.06), CFrame.new(side * 0.33, 0.22, -0.66), Color3.fromRGB(150, 190, 220))
		ctx.ball("Head", "BoarPupil", Vector3.new(0.09, 0.09, 0.06), CFrame.new(side * 0.33, 0.22, -0.69), BLACK)
		ctx.ball("Head", "BoarEar", Vector3.new(0.3, 0.42, 0.12), CFrame.new(side * 0.5, 0.82, 0) * CFrame.Angles(0, 0, -0.5 * side), fur)
		ctx.spike("Head", WHITE, Vector3.new(side * 0.26, -0.38, -0.75), Vector3.new(side * 0.3, 1, -0.6), 0.32, 0.18, { cross = false })
	end
	ctx.strand("Head", darken(fur, 0.35), Vector3.new(0, 0.8, 0.2), Vector3.new(0, 0.6, 1), 0.8, 0.45)
end

ACC.hood = function(ctx, look)
	-- Capuche rouge rabattue (uniforme à capuche) : gros volume dans le dos qui dépasse des
	-- épaules, intérieur sombre, col en anneau, revers qui descendent devant et cordons blancs.
	local color = look.accColor or Color3.fromRGB(200, 30, 40)
	local inner = darken(color, 0.4)
	ctx.ball("Torso", "Hood", Vector3.new(1.8, 1.15, 0.85), CFrame.new(0, 0.9, 0.66) * CFrame.Angles(-0.25, 0, 0), color)
	ctx.ball("Torso", "HoodInner", Vector3.new(1.2, 0.62, 0.3), CFrame.new(0, 1.12, 0.42) * CFrame.Angles(-0.4, 0, 0), inner)
	ctx.add("Torso", "HoodCollar", Vector3.new(2.06, 0.26, 1.08), CFrame.new(0, 0.9, 0), color)
	for _, side in { -1, 1 } do
		ctx.add("Torso", "HoodLapel", Vector3.new(0.3, 0.62, 0.08), CFrame.new(side * 0.36, 0.62, -0.56) * CFrame.Angles(0, 0, -side * 0.3), color)
		ctx.cyl("Torso", "HoodCord", 0.55, 0.06, CFrame.new(side * 0.16, 0.5, -0.58) * CFrame.Angles(0, 0, math.pi / 2), WHITE)
		ctx.ball("Torso", "HoodCordTip", Vector3.new(0.09, 0.12, 0.09), CFrame.new(side * 0.16, 0.2, -0.58), Color3.fromRGB(220, 220, 225))
	end
end

ACC.hood_full = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(25, 25, 30)
	ctx.ball("Head", "HoodTop", Vector3.new(1.55, 1.5, 1.55), CFrame.new(0, 0.2, 0.06), color)
	ctx.ball("Head", "HoodInner", Vector3.new(1.3, 1.1, 0.2), CFrame.new(0, 0.02, -0.68), darken(color, 0.5))
end

ACC.hair_ribbon = function(ctx, look)
	local pink = look.accColor or Color3.fromRGB(255, 120, 170)
	for _, side in { -1, 1 } do
		ctx.ball("Head", "Ribbon", Vector3.new(0.38, 0.26, 0.1), CFrame.new(side * 0.22, 0.42, 0.72) * CFrame.Angles(0, 0, 0.3 * side), pink)
	end
	ctx.ball("Head", "RibbonKnot", Vector3.new(0.14, 0.14, 0.12), CFrame.new(0, 0.42, 0.74), darken(pink, 0.2))
end

ACC.butterfly_clip = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(140, 80, 220)
	for _, side in { -1, 1 } do
		ctx.ball(
			"Head",
			"ButterflyWing",
			Vector3.new(0.1, 0.4, 0.5),
			CFrame.new(0.66, 0.5 + side * 0.13, 0.2 + side * 0.13) * CFrame.Angles(side * 0.6, 0, 0),
			color,
			{ Transparency = 0.15 }
		)
	end
end

-- Corps -----------------------------------------------------------------

ACC.belt = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(30, 30, 30)
	if look.outfit == "gi" then
		return -- ceinture nouée déjà peinte sur le kimono
	end
	ctx.add("Torso", "Belt", Vector3.new(2.05, 0.26, 1.05), CFrame.new(0, -0.8, 0), color)
	ctx.ball("Torso", "BeltKnot", Vector3.new(0.34, 0.28, 0.16), CFrame.new(0.4, -0.8, -0.56), color)
	ctx.strand("Torso", color, Vector3.new(0.45, -0.85, -0.57), Vector3.new(0.15, -1, -0.1), 0.6, 0.18)
end

ACC.sash = function(ctx, look)
	local color = look.sashColor or look.accColor or Color3.fromRGB(240, 200, 80)
	ctx.add("Torso", "Sash", Vector3.new(0.3, 2.55, 1.06), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0.75), color)
end

ACC.cape = function(ctx, look)
	local color = look.capeColor or look.accColor or Color3.fromRGB(200, 40, 40)
	ctx.add("Torso", "Cape", Vector3.new(2.3, 3.5, 0.12), CFrame.new(0, -0.65, 0.66) * CFrame.Angles(0.1, 0, 0), color)
	ctx.add("Torso", "CapeLining", Vector3.new(2.2, 3.4, 0.04), CFrame.new(0, -0.65, 0.58) * CFrame.Angles(0.1, 0, 0), darken(color, 0.3))
	ctx.add("Torso", "CapeCollar", Vector3.new(2.3, 0.35, 1.2), CFrame.new(0, 0.9, 0.05), color)
	for _, side in { -1, 1 } do
		ctx.ball("Torso", "CapeClasp", Vector3.new(0.25, 0.25, 0.12), CFrame.new(side * 0.7, 0.85, -0.58), GOLD, { Material = Enum.Material.Metal })
	end
end

-- Manteau de la marine : même coupe que le manteau de la justice (posé sur les épaules, cape
-- jusqu'aux mollets, épaulettes à franges), défini plus bas.
ACC.marine_coat = function(ctx, look)
	ACC.justice_coat(ctx, look)
end

ACC.cloak_skirt = function(ctx, look)
	-- Pans du long manteau jusqu'aux chevilles (nuages rouges peints sur le manteau à nuages).
	local color = look.skirtColor or look.top or Color3.fromRGB(40, 40, 50)
	local mode = ctx.paint == "parts" and "parts" or nil
	local skirt = ctx.add("Torso", "Skirt", Vector3.new(2.12, 1.9, 1.12), CFrame.new(0, -1.9, 0), color)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Painter.panel(skirt, face, mode, color, function(S)
			if look.outfit == "cloak" then
				Painter.cloud(S.g, face == Enum.NormalId.Front and 0.28 or 0.66, 0.45, 0.3, look.topAccent or Color3.fromRGB(210, 20, 30))
			end
			-- Fente du manteau (devant) + ourlet doublé de rouge
			if face == Enum.NormalId.Front then
				S:line(0.5, 0, 0.5, 1, 0.03, Painter.inkOf(color), { corner = 0, z = 6 })
			end
		end, { folds = true })
	end
	ctx.add("Torso", "SkirtHem", Vector3.new(2.14, 0.1, 1.14), CFrame.new(0, -2.82, 0), look.collarLining or darken(color, 0.3))
end

-- Jupe plissée (uniforme) : pièce 3D par-dessus le haut des jambes, plis peints sur les 4 faces,
-- légèrement évasée (ourlet plus large), ceinture de cuir à boucle.
ACC.pleated_skirt = function(ctx, look)
	local color = look.skirtColor or look.bottom or Color3.fromRGB(30, 32, 50)
	local mode = ctx.paint == "parts" and "parts" or nil
	local length = look.skirtLength or 0.95
	local skirt = ctx.add("Torso", "Skirt", Vector3.new(2.14, length, 1.14), CFrame.new(0, -0.95 - length / 2, 0), color)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		Painter.panel(skirt, face, mode, color, function(S)
			local n = (face == Enum.NormalId.Left or face == Enum.NormalId.Right) and 3 or 6
			for i = 0, n - 1 do
				local x = (i + 0.5) / n
				-- Pli creux : bande ombrée qui s'élargit vers le bas + arête claire
				S:line(x + 0.18 / n, 0.08, x + 0.3 / n, 1, 0.22 / n, Painter.celShadow(color), { corner = 0, transparency = 0.25, z = 3 })
				S:line(x - 0.3 / n, 0.04, x - 0.36 / n, 1, 0.04 / n, Painter.lighten(color, 0.22), { corner = 0, transparency = 0.3, z = 3 })
				S:line(x + 0.05 / n, 0.12, x + 0.1 / n, 1, 0.025, Painter.inkOf(color), { z = 4 })
			end
			Painter.band(S, 0.95, 0.1, Painter.shade(color, 0.1), 5)
		end, { folds = false })
	end
	ctx.add("Torso", "SkirtHem", Vector3.new(2.24, 0.12, 1.22), CFrame.new(0, -0.95 - length + 0.06, 0), Painter.shade(color, 0.12))
	local belt = look.beltColor or Color3.fromRGB(110, 70, 45)
	ctx.add("Torso", "SkirtBelt", Vector3.new(2.06, 0.13, 1.08), CFrame.new(0, -0.9, 0), belt)
	ctx.add("Torso", "SkirtBuckle", Vector3.new(0.26, 0.18, 0.06), CFrame.new(0.3, -0.9, -0.55), GOLD, { Material = Enum.Material.Metal, Reflectance = 0.2 })
end

ACC.collar_high = function(ctx, look)
	-- Col montant qui cache le bas du visage (manteau à nuages, uniforme à col haut)
	local color = look.collarColor or look.topAccent or look.top or Color3.fromRGB(30, 30, 40)
	ctx.vcyl("Torso", "HighCollar", 0.5, 1.5, CFrame.new(0, 0.98, 0), color)
	ctx.vcyl("Torso", "HighCollarLining", 0.03, 1.36, CFrame.new(0, 1.23, 0), look.collarLining or Painter.shade(color, 0.4))
end

ACC.collar_gold = function(ctx, look)
	ctx.add("Torso", "GoldCollar", Vector3.new(2.15, 0.35, 1.15), CFrame.new(0, 0.85, 0), GOLD, { Material = Enum.Material.Metal, Reflectance = 0.2 })
	ctx.ball("Torso", "Gem", Vector3.new(0.3, 0.3, 0.1), CFrame.new(0, 0.75, -0.6), look.gemColor or Color3.fromRGB(80, 200, 255), { Material = Enum.Material.Neon })
end

ACC.scarf_long = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(60, 110, 210)
	ctx.rounded("Torso", "Scarf", Vector3.new(1.6, 0.36, 1.35), CFrame.new(0, 1.05, 0), color, 0.3)
	ctx.add("Torso", "ScarfTail", Vector3.new(0.35, 2.4, 0.1), CFrame.new(0.5, -0.1, 0.62) * CFrame.Angles(0.25, 0, 0.1), color)
	ctx.add("Torso", "ScarfTail", Vector3.new(0.35, 2.0, 0.1), CFrame.new(0.05, 0.0, 0.6) * CFrame.Angles(0.35, 0, -0.15), darken(color, 0.1))
end

ACC.shoulder_pads = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(230, 185, 80)
	for _, side in { "Left Arm", "Right Arm" } do
		ctx.rounded(side, "ShoulderPad", Vector3.new(1.3, 0.32, 1.3), CFrame.new(0, 1.05, 0), color, 0.3)
	end
end

ACC.leg_warmers = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(255, 120, 30)
	for _, side in { "Left Leg", "Right Leg" } do
		ctx.add(side, "LegWarmer", Vector3.new(1.08, 0.75, 1.08), CFrame.new(0, -0.3, 0), color)
	end
end

local HAORI_TOP = 0.95

-- Haori (veste ouverte) : panneaux 3D peints (ombrages, plis, motif) dos, devant et manches.
-- `pattern(S, kind)` dessine le motif sur une feuille ; kind = "back", "front" ou "sleeve".
local function haoriBase(ctx, look, color: Color3, pattern: ((any, string) -> ())?)
	local length = 2.7
	local y = HAORI_TOP - length / 2
	local mode = ctx.paint == "parts" and "parts" or nil
	local backPanel = ctx.add("Torso", "HaoriBack", Vector3.new(2.14, length, 0.1), CFrame.new(0, y, 0.56), color)
	Painter.panel(backPanel, Enum.NormalId.Back, mode, color, pattern and function(S)
		pattern(S, "back")
	end)
	for _, side in { -1, 1 } do
		local front = ctx.add("Torso", "HaoriFront", Vector3.new(0.62, length, 0.1), CFrame.new(side * 0.76, y, -0.56), color)
		Painter.panel(front, Enum.NormalId.Front, mode, color, pattern and function(S)
			pattern(S, "front")
		end, { folds = false, edges = false })
		ctx.add("Torso", "HaoriSide", Vector3.new(0.1, length, 1.22), CFrame.new(side * 1.07, y, 0), color)
	end
	for _, side in { "Left Arm", "Right Arm" } do
		local sleeve = ctx.add(side, "HaoriSleeve", Vector3.new(1.22, 1.3, 1.22), CFrame.new(0, 0.38, 0), color)
		local outer = side == "Left Arm" and Enum.NormalId.Left or Enum.NormalId.Right
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, outer } do
			Painter.panel(sleeve, face, mode, color, pattern and function(S)
				pattern(S, "sleeve")
			end, { folds = false, edges = false })
		end
	end
	local _ = look
end

ACC.haori = function(ctx, look)
	-- Jaune avec des triangles blancs en bas.
	haoriBase(ctx, look, look.accColor or Color3.fromRGB(255, 205, 40), function(S, kind)
		if kind == "sleeve" then
			return
		end
		local n = kind == "back" and 5 or 2
		for i = 0, n - 1 do
			S:rect((i + 0.5) / n, 0.98, 0.7 / n, S:dy(0.5), WHITE, { rotation = 45, z = 2 })
		end
	end)
end

ACC.haori_checker = function(ctx, look)
	-- Damier vert et noir
	local green = look.accColor or Color3.fromRGB(40, 130, 90)
	haoriBase(ctx, look, Color3.fromRGB(28, 28, 32), function(S, kind)
		local cell = 0.52 -- taille d'une case (studs)
		local cols = math.max(1, math.floor(S.w / cell + 0.5))
		local rows = math.max(1, math.floor(S.h / cell + 0.5))
		for r = 0, rows - 1 do
			for col = 0, cols - 1 do
				if (r + col) % 2 == 0 then
					S:rect((col + 0.5) / cols, (r + 0.5) / rows, 1 / cols + 0.002, 1 / rows + 0.002, green, {
						gradient = { Painter.lighten(green, 0.12), green },
						z = 2,
					})
				end
			end
		end
		local _ = kind
	end)
end

ACC.haori_flame = function(ctx, look)
	haoriBase(ctx, look, look.accColor or WHITE, function(S, kind)
		if kind == "sleeve" then
			return
		end
		local n = kind == "back" and 7 or 2
		for i = 0, n - 1 do
			local x = (i + 0.5) / n
			S:rect(x, 0.9, 0.9 / n, 0.32, Color3.fromRGB(230, 50, 20), { corner = 0.5, z = 2 })
			S:rect(x, 0.93, 0.5 / n, 0.18, Color3.fromRGB(255, 170, 40), { corner = 0.5, z = 3 })
		end
	end)
end

ACC.haori_sage = function(ctx, look)
	-- Manteau d'ermite rouge : flammes noires en bas, inscription dans le dos.
	haoriBase(ctx, look, look.accColor or Color3.fromRGB(200, 40, 40), function(S, kind)
		if kind == "sleeve" then
			S:rect(0.5, 0.96, 1, 0.08, BLACK, { z = 2 })
			return
		end
		local n = kind == "back" and 6 or 2
		S:rect(0.5, 0.97, 1, 0.06, BLACK, { z = 2 })
		for i = 0, n - 1 do
			local x = (i + 0.5) / n
			S:line(x - 0.35 / n, 0.99, x + 0.05 / n, 0.84, 0.16, BLACK, { corner = 0.5, z = 2 })
			S:line(x + 0.3 / n, 0.99, x + 0.1 / n, 0.88, 0.1, BLACK, { corner = 0.5, z = 2 })
		end
		if kind == "back" and not S.lite then
			local label = Instance.new("TextLabel")
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Position = UDim2.fromScale(0.5, 0.3)
			label.Size = UDim2.fromScale(0.5, 0.3)
			label.BackgroundTransparency = 1
			label.Text = "仙人"
			label.TextScaled = true
			label.Font = Enum.Font.GothamBlack
			label.TextColor3 = BLACK
			label.ZIndex = 8
			label.Parent = S.g
		end
	end)
end

-- Haori du pilier de l'eau : moitié droite unie bordeaux, moitié gauche à motif d'écaille de
-- tortue (hexagones verts, jaunes et orangés cerclés de sombre).
local function tortoise(S, cols: number, rows: number)
	local ink = Color3.fromRGB(30, 34, 30)
	local tones = { Color3.fromRGB(70, 140, 80), Color3.fromRGB(226, 190, 70), Color3.fromRGB(200, 120, 50), Color3.fromRGB(110, 170, 90) }
	S:rect(0.5, 0.5, 1, 1, ink, { z = 1 })
	if S.lite then
		-- Aperçu en pièces : simple damier de deux tons (budget)
		for r = 0, 2 do
			for col = 0, 1 do
				S:rect((col + 0.5) / 2, (r + 0.5) / 3, 0.46, 0.3, tones[(r + col) % 2 + 1], { z = 2 })
			end
		end
		return
	end
	-- Hexagones à sommets plats (côté `a` en studs) : chacun = trois rectangles a x a*sqrt(3)
	-- tournés de 0, 60 et 120 degrés ; on laisse un liseré sombre entre les écailles.
	local a = S.w / (cols * 1.5)
	local inner = a * 0.86
	local dy = math.sqrt(3) * a
	for col = 0, cols do
		for r = (col % 2 == 1) and -1 or 0, math.ceil(S.h / dy) - 1 do
			local x = (col * 1.5 * a) / S.w
			local y = (r * dy + (col % 2) * dy / 2 + dy / 2) / S.h
			local tone = tones[(col * 2 + r) % #tones + 1]
			for k = 0, 2 do
				S:box(x, y, inner, inner * math.sqrt(3), tone, { rotation = k * 60, z = 2 })
			end
		end
	end
	local _ = rows
end

local function haoriSides(ctx, look, color: Color3, left: (any, string) -> (), right: (any, string) -> ())
	-- Variante de haoriBase : motif différent pour chaque moitié (dos coupé en deux).
	local length = 2.7
	local y = HAORI_TOP - length / 2
	local mode = ctx.paint == "parts" and "parts" or nil
	for _, side in { -1, 1 } do
		local paint = side < 0 and left or right
		local backHalf = ctx.add("Torso", "HaoriBack", Vector3.new(1.07, length, 0.1), CFrame.new(side * 0.535, y, 0.56), color)
		Painter.panel(backHalf, Enum.NormalId.Back, mode, color, function(S)
			paint(S, "back")
		end, { folds = false, edges = false })
		local front = ctx.add("Torso", "HaoriFront", Vector3.new(0.62, length, 0.1), CFrame.new(side * 0.76, y, -0.56), color)
		Painter.panel(front, Enum.NormalId.Front, mode, color, function(S)
			paint(S, "front")
		end, { folds = false, edges = false })
		ctx.add("Torso", "HaoriSide", Vector3.new(0.1, length, 1.22), CFrame.new(side * 1.07, y, 0), color)
		local limb = side < 0 and "Left Arm" or "Right Arm"
		local sleeve = ctx.add(limb, "HaoriSleeve", Vector3.new(1.22, 1.3, 1.22), CFrame.new(0, 0.38, 0), color)
		local outer = side < 0 and Enum.NormalId.Left or Enum.NormalId.Right
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, outer } do
			Painter.panel(sleeve, face, mode, color, function(S)
				paint(S, face == Enum.NormalId.Back and "sleeveBack" or "sleeve")
			end, { folds = false, edges = false })
		end
	end
	local _ = look
end

ACC.haori_giyu = function(ctx, look)
	local maroon = look.accColor or Color3.fromRGB(128, 34, 40)
	local plain = function(S, kind)
		Painter.fold(S, 0.3, 0.2, 0.4, 0.8, maroon, { w = 0.1, z = 4 })
		local _ = kind
	end
	local shell = function(S, kind)
		if kind == "sleeveBack" then
			return plain(S, kind)
		end
		tortoise(S, 2, 0)
	end
	-- Moitié droite (côté +X du perso) unie, moitié gauche en écaille
	haoriSides(ctx, look, maroon, shell, plain)
end

-- Haori du pilier de l'insecte : blanc qui vire au vert d'eau puis au violet vers le bas, avec des
-- nervures noires d'ailes de papillon.
ACC.haori_butterfly = function(ctx, look)
	local white = Color3.fromRGB(246, 246, 250)
	local teal = look.accColor or Color3.fromRGB(80, 200, 180)
	local violet = Color3.fromRGB(150, 90, 200)
	haoriBase(ctx, look, white, function(S, kind)
		S:rect(0.5, 0.75, 1, 0.5, teal, { gradient = { white, teal, violet }, gradientRotation = 90, transparency = 0, z = 2 })
		if S.lite then
			return
		end
		local n = kind == "back" and 4 or (kind == "sleeve" and 2 or 1)
		local ink = Color3.fromRGB(30, 30, 40)
		for i = 0, n - 1 do
			local x = (i + 0.5) / n
			S:line(x, 0.45, x - 0.35 / n, 0.98, 0.02, ink, { z = 3 })
			S:line(x, 0.45, x + 0.35 / n, 0.98, 0.02, ink, { z = 3 })
			S:line(x, 0.5, x, 0.98, 0.015, ink, { z = 3 })
			S:oval(x - 0.22 / n, 0.85, 0.12, 0.12, white, { transparency = 0.2, z = 3 })
			S:oval(x + 0.22 / n, 0.85, 0.12, 0.12, white, { transparency = 0.2, z = 3 })
		end
		S:rect(0.5, 0.985, 1, S:dy(0.06), ink, { z = 4 })
	end)
end

-- Haori rouge de l'ermite aux crapauds : gros cercles jaunes devant et dans le dos.
ACC.haori_jiriya = function(ctx, look)
	local red = look.accColor or Color3.fromRGB(196, 42, 40)
	local yellow = Color3.fromRGB(246, 206, 60)
	haoriBase(ctx, look, red, function(S, kind)
		if kind == "sleeve" then
			S:rect(0.5, 0.96, 1, 0.08, darken(red, 0.4), { z = 2 })
			return
		end
		local d = kind == "back" and 0.42 or 0.5
		S:oval(0.5, 0.42, d * S.w, d * S.w, yellow, { stroke = darken(yellow, 0.5), strokeThickness = 1.4, z = 3 })
		if kind == "back" then
			S:oval(0.5, 0.42, d * S.w * 0.7, d * S.w * 0.7, red, { transparency = 1, stroke = darken(yellow, 0.4), strokeThickness = 1, z = 4 })
		end
		S:rect(0.5, 0.97, 1, 0.06, darken(red, 0.4), { z = 2 })
	end)
end

-- Grand rouleau porté dans le dos (sangle en travers de la poitrine).
ACC.scroll_back = function(ctx, look)
	local paper = Color3.fromRGB(226, 208, 168)
	local cap = look.scrollCap or Color3.fromRGB(130, 40, 36)
	local at = CFrame.new(0.15, -0.1, 0.98) * CFrame.Angles(0, 0, -0.3)
	ctx.vcyl("Torso", "Scroll", 2.5, 0.78, at, paper)
	ctx.vcyl("Torso", "ScrollBand", 0.14, 0.8, at * CFrame.new(0, 0.5, 0), cap)
	for _, y in { -1.32, 1.32 } do
		ctx.vcyl("Torso", "ScrollCap", 0.16, 0.86, at * CFrame.new(0, y, 0), cap)
		ctx.vcyl("Torso", "ScrollKnob", 0.14, 0.4, at * CFrame.new(0, y + (y > 0 and 0.14 or -0.14), 0), darken(cap, 0.3))
	end
	local strap = Color3.fromRGB(70, 50, 40)
	ctx.add("Torso", "ScrollStrap", Vector3.new(0.18, 2.7, 0.06), CFrame.new(0, 0.05, -0.53) * CFrame.Angles(0, 0, 0.62), strap)
end

-- Bandeau à cornes de l'ermite : plaque « 油 » (huile) et deux petites cornes.
ACC.horned_headband = function(ctx, look)
	headbandBase(ctx, look, 0, false)
	local y = look.headbandY or 0.4
	local metal = look.plateColor or METAL
	local plate = ctx.add("Head", "OilPlate", Vector3.new(0.5, 0.42, 0.06), CFrame.new(0, y + 0.02, -0.72), metal, { Material = Enum.Material.Metal, Reflectance = 0.15 })
	local mode = ctx.paint == "parts" and "parts" or nil
	local S = Painter.sheet(plate, Enum.NormalId.Front, mode, "Oil", 120)
	S:rect(0.5, 0.5, 1, 1, metal, { gradient = { lighten(metal, 0.3), metal, darken(metal, 0.2) }, gradientRotation = 70, z = 1 })
	S:rect(0.5, 0.5, 0.86, 0.82, metal, { transparency = 1, stroke = darken(metal, 0.5), strokeThickness = 1.2, z = 2 })
	if not S.lite then
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.52)
		label.Size = UDim2.fromScale(0.8, 0.8)
		label.BackgroundTransparency = 1
		label.Text = "油"
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = Color3.fromRGB(40, 40, 50)
		label.ZIndex = 5
		label.Parent = S.g
	end
	for _, side in { -1, 1 } do
		ctx.cone("Head", CFrame.new(side * 0.2, y + 0.2, -0.72) * CFrame.Angles(0, 0, -side * 0.35), 0.3, 0.13, 0.1, metal, darken(metal, 0.25), nil, "OilHorn")
	end
end

-- Bandeau ninja noué autour du cou (plaque à la feuille sur la gorge).
ACC.headband_neck = function(ctx, look)
	local band = look.headbandColor or Color3.fromRGB(22, 34, 84)
	local metal = look.plateColor or METAL
	ctx.vcyl("Torso", "NeckBand", 0.24, 1.34, CFrame.new(0, 1.08, 0), band)
	local plate = ctx.add("Torso", "NeckPlate", Vector3.new(0.5, 0.22, 0.05), CFrame.new(0, 1.08, -0.68), metal, { Material = Enum.Material.Metal, Reflectance = 0.15 })
	paintPanel(ctx, plate, Enum.NormalId.Front, function(canvas)
		Painter.rect(canvas, 0.5, 0.5, 1, 1, metal, { gradient = { lighten(metal, 0.35), metal, darken(metal, 0.18) }, gradientRotation = 70, z = 1 })
		leafSymbol(canvas, Color3.fromRGB(60, 72, 92), false, ctx.paint == "parts" and metal or nil)
	end)
end

-- Chapeau de cow-boy orange (pirate de feu) : bord relevé sur les côtés, ruban, deux badges
-- (sourire et grimace), cordon qui pend sur la nuque.
ACC.cowboy_hat = function(ctx, look)
	local orange = look.hatColor or Color3.fromRGB(232, 128, 40)
	local band = darken(orange, 0.45)
	local tilt = CFrame.Angles(math.rad(10), 0, 0)
	ctx.vcyl("Head", "HatBrim", 0.08, 2.1, CFrame.new(0, 0.6, 0.06) * tilt, orange)
	for _, side in { -1, 1 } do
		ctx.add("Head", "HatBrimCurl", Vector3.new(0.26, 0.08, 1.0), CFrame.new(side * 0.98, 0.69, 0.06) * tilt * CFrame.Angles(0, 0, side * 0.55), orange)
	end
	ctx.vcyl("Head", "HatCrown", 0.52, 1.3, CFrame.new(0, 0.88, 0.1) * tilt, orange)
	ctx.ball("Head", "HatTop", Vector3.new(1.3, 0.32, 1.3), CFrame.new(0, 1.13, 0.13) * tilt, orange)
	ctx.add("Head", "HatCrease", Vector3.new(0.12, 0.1, 0.9), CFrame.new(0, 1.26, 0.13) * tilt, darken(orange, 0.2))
	ctx.vcyl("Head", "HatBand", 0.12, 1.32, CFrame.new(0, 0.7, 0.08) * tilt, band)
	for i, e in { { -0.22, Color3.fromRGB(250, 220, 60) }, { 0.22, Color3.fromRGB(80, 150, 230) } } do
		local at = CFrame.new(e[1], 0.93, -0.58) * tilt * CFrame.Angles(0, math.pi / 2, 0)
		ctx.cyl("Head", "HatPin", 0.05, 0.2, at, e[2])
		-- yeux et bouche du badge (sourire / grimace)
		for _, dx in { -0.04, 0.04 } do
			ctx.add("Head", "HatPinFace", Vector3.new(0.025, 0.035, 0.02), CFrame.new(e[1] + dx, 0.955, -0.615) * tilt, BLACK)
		end
		ctx.add("Head", "HatPinFace", Vector3.new(0.09, 0.02, 0.02), CFrame.new(e[1], i == 1 and 0.9 or 0.905, -0.615) * tilt * CFrame.Angles(0, 0, i == 1 and 0 or 0.25), BLACK)
	end
	ctx.strand("Head", band, Vector3.new(0, 0.5, 0.62), Vector3.new(0, -1, 0.3), 0.7, 0.05, 0.05)
end

-- Collier de grosses perles rouges.
ACC.bead_necklace = function(ctx, look)
	local red = look.beadColor or Color3.fromRGB(200, 30, 36)
	for i = 0, 11 do
		local a = (i / 12) * math.pi * 2
		local x, z = math.sin(a) * 0.62, -math.cos(a) * 0.62
		local y = 1.02 - (math.cos(a) > 0 and math.cos(a) * 0.22 or 0)
		ctx.ball("Torso", "Bead", Vector3.new(0.2, 0.2, 0.2), CFrame.new(x, y, z * 0.95), red, { Reflectance = 0.1 })
	end
	local _ = look
end

-- Deux petites couettes hérissées sur le haut du crâne (exorciste du sang).
ACC.twin_tufts = function(ctx, look)
	local c = look.hairColor or BLACK
	for _, side in { -1, 1 } do
		ctx.ball("Head", "TuftTie", Vector3.new(0.18, 0.12, 0.18), CFrame.new(side * 0.36, 0.78, 0.15), darken(c, 0.3))
		ctx.spike("Head", c, Vector3.new(side * 0.38, 0.82, 0.15), Vector3.new(side * 0.8, 1, 0.1), 0.5, 0.32)
		ctx.spike("Head", c, Vector3.new(side * 0.4, 0.82, 0.2), Vector3.new(side * 1, 0.4, 0.4), 0.42, 0.28)
	end
end

-- Katana au fourreau, détaillé comme un vrai sabre japonais :
--   * fourreau (saya) laqué avec reflet, embout (kojiri) et embouchure (koiguchi) en métal,
--     bouton (kurikata) et cordon (sageo) noué qui s'enroule ;
--   * garde (tsuba) en disque à liseré doré (ronde, en fleur, carrée ou en flammes) + rondelles ;
--   * poignée (tsuka) au tressage en losanges (ito croisé sur la peau de raie blanche), virole
--     (fuchi), pommeau (kashira) et ornement (menuki) dorés.
-- `cf` = centre du fourreau, axe Y vers la poignée. spec = { handle, sheath, tsuba, trim,
-- guard = "round" | "flower" | "square" | "flame", cord, length, shine }.
local KATANA_GUARDS = {
	round = function(ctx, limb, at, tsuba, trim)
		ctx.cyl(limb, "Tsuba", 0.07, 0.5, at * CFrame.Angles(0, 0, math.pi / 2), tsuba, { Material = Enum.Material.Metal, Reflectance = 0.1 })
		ctx.cyl(limb, "TsubaRim", 0.05, 0.54, at * CFrame.Angles(0, 0, math.pi / 2), trim, { Material = Enum.Material.Metal, Reflectance = 0.25 })
	end,
	flower = function(ctx, limb, at, tsuba, trim)
		-- Garde en fleur : 4 lobes arrondis autour du centre
		ctx.cyl(limb, "Tsuba", 0.07, 0.36, at * CFrame.Angles(0, 0, math.pi / 2), tsuba, { Material = Enum.Material.Metal })
		for i = 0, 3 do
			local a = i * math.pi / 2 + math.pi / 4
			ctx.cyl(limb, "TsubaPetal", 0.06, 0.24, at * CFrame.new(math.cos(a) * 0.17, 0, math.sin(a) * 0.17) * CFrame.Angles(0, 0, math.pi / 2), trim, {
				Material = Enum.Material.Metal,
				Reflectance = 0.2,
			})
		end
	end,
	square = function(ctx, limb, at, tsuba, trim)
		ctx.add(limb, "Tsuba", Vector3.new(0.42, 0.07, 0.48), at, tsuba, { Material = Enum.Material.Metal })
		ctx.add(limb, "TsubaRim", Vector3.new(0.46, 0.05, 0.52), at, trim, { Material = Enum.Material.Metal, Reflectance = 0.2 })
	end,
	flame = function(ctx, limb, at, tsuba, trim)
		-- Garde en flammes (pilier de la flamme) : disque rouge + langues de feu dorées
		ctx.cyl(limb, "Tsuba", 0.07, 0.42, at * CFrame.Angles(0, 0, math.pi / 2), tsuba, { Material = Enum.Material.Metal })
		for i = 0, 5 do
			local a = i * math.pi / 3
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local from = (at * CFrame.new(dir * 0.14)).Position
			local tip = at:VectorToWorldSpace(dir)
			ctx.spike(limb, i % 2 == 0 and trim or tsuba, from, tip, 0.2, 0.14, { cross = true })
		end
	end,
}

local function katana(ctx, limb: string, cf: CFrame, spec)
	local l = spec.length or 2.7
	local sheath = spec.sheath or Color3.fromRGB(28, 26, 32)
	local handle = spec.handle or Color3.fromRGB(30, 30, 36)
	local trim = spec.trim or GOLD
	local tsuba = spec.tsuba or Color3.fromRGB(38, 36, 40)
	local metal = { Material = Enum.Material.Metal, Reflectance = 0.2 }
	-- Fourreau : section ovale (aplati sur X), extrémités en métal
	local saya = ctx.add(limb, "Sheath", Vector3.new(0.15, l, 0.22), cf, sheath, { Reflectance = spec.shine or 0.08 })
	ctx.add(limb, "SheathShine", Vector3.new(0.155, l * 0.86, 0.035), cf * CFrame.new(0, 0, -0.085), lighten(sheath, 0.18))
	ctx.add(limb, "Kojiri", Vector3.new(0.17, 0.14, 0.24), cf * CFrame.new(0, -l / 2 + 0.06, 0), trim, metal)
	ctx.add(limb, "Koiguchi", Vector3.new(0.17, 0.08, 0.24), cf * CFrame.new(0, l / 2 - 0.04, 0), trim, metal)
	-- Bouton du cordon + cordon (sageo) qui s'enroule autour du fourreau
	local cord = spec.cord or lighten(handle, 0.15)
	ctx.add(limb, "Kurikata", Vector3.new(0.19, 0.12, 0.08), cf * CFrame.new(0, l / 2 - 0.42, -0.1), sheath)
	ctx.add(limb, "Sageo", Vector3.new(0.18, 0.05, 0.25), cf * CFrame.new(0, l / 2 - 0.55, 0) * CFrame.Angles(0.5, 0, 0), cord)
	ctx.add(limb, "Sageo", Vector3.new(0.18, 0.05, 0.25), cf * CFrame.new(0, l / 2 - 0.8, 0) * CFrame.Angles(-0.5, 0, 0), cord)
	ctx.add(limb, "SageoTail", Vector3.new(0.04, 0.6, 0.06), cf * CFrame.new(0.1, l / 2 - 1.05, 0.05) * CFrame.Angles(0, 0, 0.1), cord)
	-- Garde (tsuba) et rondelles (seppa)
	local guardAt = cf * CFrame.new(0, l / 2 + 0.05, 0)
	local guard = KATANA_GUARDS[spec.guard or "round"] or KATANA_GUARDS.round
	guard(ctx, limb, guardAt, tsuba, trim)
	ctx.add(limb, "Seppa", Vector3.new(0.16, 0.05, 0.24), cf * CFrame.new(0, l / 2 + 0.11, 0), trim, metal)
	-- Poignée (tsuka) tressée
	local tl = spec.handleLength or 0.86
	local tsukaCf = cf * CFrame.new(0, l / 2 + 0.14 + tl / 2, 0)
	local samegawa = Color3.fromRGB(236, 232, 220)
	local tsuka = ctx.add(limb, "Tsuka", Vector3.new(0.13, tl, 0.19), tsukaCf, samegawa)
	local wraps = 5
	-- (la face arrière, contre le corps, n'est pas peinte : budget de Frames)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Front } do
		local canvas = ctx.surface(tsuka, face, "Ito")
		local lite = ctx.paint == "parts"
		local side = face == Enum.NormalId.Left or face == Enum.NormalId.Right
		for i = 0, wraps - 1 do
			local y = (i + 0.5) / wraps
			-- Deux rubans croisés en "X" : il reste un losange blanc entre chaque croisement
			for _, rot in { 38, -38 } do
				Painter.rect(canvas, 0.5, y, 1.5, 0.42 / wraps, handle, {
					rotation = side and rot or rot * 0.6,
					z = rot > 0 and 2 or 3,
					fine = lite and (not side or rot < 0),
				})
			end
		end
	end
	ctx.add(limb, "Fuchi", Vector3.new(0.15, 0.08, 0.21), cf * CFrame.new(0, l / 2 + 0.17, 0), trim, metal)
	ctx.add(limb, "Kashira", Vector3.new(0.15, 0.09, 0.21), cf * CFrame.new(0, l / 2 + 0.14 + tl + 0.03, 0), trim, metal)
	ctx.ball(limb, "Menuki", Vector3.new(0.16, 0.16, 0.1), tsukaCf, trim, metal)
	local _ = saya
end
CharacterBuilder.katana = katana

-- Ancienne signature (poignée, fourreau, longueur) conservée pour les accessoires.
local function sword(ctx, limb: string, cf: CFrame, handle: Color3, sheath: Color3?, length: number?, extra)
	local spec = extra and table.clone(extra) or {}
	spec.handle = spec.handle or handle
	spec.sheath = spec.sheath or sheath
	spec.length = spec.length or length
	katana(ctx, limb, cf, spec)
end

-- Sabre(s) d'un perso : look.katana = { handle, sheath, tsuba, trim, guard, cord } ou liste de
-- specs pour plusieurs sabres.
local function katanaSpec(look, index: number, fallback)
	local k = look.katana
	if type(k) == "table" and k[1] then
		return k[index] or k[1]
	end
	return k or fallback
end

ACC.sword_hip = function(ctx, look)
	local spec = katanaSpec(look, 1, { handle = look.accColor or WHITE })
	sword(ctx, "Torso", CFrame.new(-1.13, -0.75, 0.05) * CFrame.Angles(math.rad(-70), 0, 0), spec.handle or look.accColor or WHITE, nil, nil, spec)
end

ACC.swords = function(ctx, look)
	-- Trois sabres (Wado blanc, Sandai rouge, Shusui noir par défaut)
	local defaults = {
		{ handle = WHITE, sheath = Color3.fromRGB(240, 240, 238), tsuba = GOLD, trim = GOLD, guard = "flower", cord = Color3.fromRGB(235, 235, 235) },
		{ handle = Color3.fromRGB(200, 40, 40), sheath = Color3.fromRGB(150, 25, 30), guard = "round", cord = Color3.fromRGB(230, 70, 60) },
		{ handle = Color3.fromRGB(30, 30, 30), sheath = Color3.fromRGB(25, 22, 26), tsuba = Color3.fromRGB(60, 50, 40), guard = "square", trim = Color3.fromRGB(200, 170, 90) },
	}
	local spots = {
		CFrame.new(-1.13, -0.75, -0.12) * CFrame.Angles(math.rad(-70), 0, 0),
		CFrame.new(-1.2, -0.82, 0.2) * CFrame.Angles(math.rad(-64), 0, 0),
		CFrame.new(1.13, -0.75, 0.05) * CFrame.Angles(math.rad(-70), 0, 0),
	}
	for i, cf in spots do
		local spec = look.katana and katanaSpec(look, i, defaults[i]) or defaults[i]
		katana(ctx, "Torso", cf, spec)
	end
end

ACC.sword_back = function(ctx, look)
	local spec = katanaSpec(look, 1, { handle = look.accColor or Color3.fromRGB(80, 60, 130) })
	sword(ctx, "Torso", CFrame.new(0, 0, 0.64) * CFrame.Angles(0, 0, 0.75), spec.handle or look.accColor or Color3.fromRGB(80, 60, 130), nil, 3.1, spec)
end

ACC.big_sword = function(ctx, look)
	-- Énorme couperet porté dans le dos.
	local cf = CFrame.new(0.2, 0.2, 0.68) * CFrame.Angles(0, 0, -0.6)
	ctx.add("Torso", "Cleaver", Vector3.new(1.0, 4.2, 0.08), cf, METAL, { Material = Enum.Material.Metal, Reflectance = 0.15 })
	ctx.ball("Torso", "CleaverHole", Vector3.new(0.4, 0.4, 0.1), cf * CFrame.new(0.15, 1.6, 0), BLACK)
	ctx.add("Torso", "CleaverHandle", Vector3.new(0.2, 1.0, 0.2), cf * CFrame.new(0, -2.55, 0), look.accColor or Color3.fromRGB(70, 60, 50))
end

ACC.hammer = function(ctx, look)
	local cf = CFrame.new(0, -0.95, -0.6) * CFrame.Angles(math.rad(90), 0, 0)
	ctx.add("Right Arm", "HammerHandle", Vector3.new(0.18, 1.8, 0.18), cf, look.accColor or Color3.fromRGB(110, 80, 60))
	ctx.add("Right Arm", "HammerHead", Vector3.new(0.9, 0.5, 0.5), cf * CFrame.new(0, 0.9, 0), METAL, { Material = Enum.Material.Metal })
end

ACC.spear = function(ctx, look)
	local cf = CFrame.new(0, -0.9, -0.45)
	ctx.add("Right Arm", "SpearShaft", Vector3.new(0.16, 5.0, 0.16), cf, look.accColor or Color3.fromRGB(120, 100, 70))
	ctx.ball("Right Arm", "SpearTip", Vector3.new(0.3, 0.8, 0.1), cf * CFrame.new(0, 2.8, 0), METAL, { Material = Enum.Material.Metal })
end

ACC.tail = function(ctx, look)
	local color = look.tailColor or Color3.fromRGB(120, 80, 50)
	if look.hair == "none" then
		color = look.skin
	end
	ctx.strand("Torso", color, Vector3.new(0, -0.75, 0.45), Vector3.new(0.1, -0.2, 1), 1.0, 0.3)
	ctx.strand("Torso", color, Vector3.new(0.05, -0.85, 1.2), Vector3.new(0.3, 1, 0.4), 0.8, 0.28)
end

ACC.tails9 = function(ctx, look)
	local fur = look.accColor or Color3.fromRGB(255, 120, 20)
	for i = 0, 8 do
		local a = -1.2 + i * (2.4 / 8)
		ctx.strand("Torso", fur, Vector3.new(0, -0.7, 0.5), Vector3.new(math.sin(a), math.cos(a) * 0.9 + 0.1, 0.8), 3.2, 0.8, lighten(fur, 0.6))
	end
end

ACC.fins = function(ctx, look)
	local fin = look.accColor or Color3.fromRGB(60, 120, 180)
	ctx.ball("Torso", "DorsalFin", Vector3.new(0.12, 1.3, 0.9), CFrame.new(0, 0.5, 0.75) * CFrame.Angles(-0.4, 0, 0), fin)
	for _, side in { "Left Arm", "Right Arm" } do
		ctx.ball(side, "ArmFin", Vector3.new(0.1, 0.8, 0.6), CFrame.new(0, 0.1, 0.6) * CFrame.Angles(-0.3, 0, 0), fin)
	end
end

------------------------------------------------------------------------
-- Boss d'univers : tenues iconiques, effets et lisibilité dans l'arène
------------------------------------------------------------------------

-- Chaîne de segments arrondis passant par une liste de points (queue, cordon...).
local function chain(ctx, limb: string, points: { Vector3 }, widths: { number }, colors: { Color3 })
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local d = b - a
		local w = widths[i] or widths[#widths]
		ctx.ball(limb, "Segment", Vector3.new(w, d.Magnitude + w * 0.6, w), alongY((a + b) / 2, d), colors[i] or colors[#colors])
	end
end

-- Kesa (étole de moine en patchwork) en travers du torse, de l'épaule gauche à la hanche droite
-- (Kenjakou) : vrais carreaux de tissus différents (ocre, brun, olive...) de tailles inégales,
-- coutures en pointillés, bord clair tout autour, peints sur une bande fine, et un petit nœud de
-- cordon sur l'épaule.
local KESA_TONES = {
	Color3.fromRGB(196, 146, 62), -- ocre
	Color3.fromRGB(126, 82, 46), -- brun
	Color3.fromRGB(122, 120, 60), -- olive
	Color3.fromRGB(214, 174, 96), -- ocre clair
	Color3.fromRGB(150, 92, 58), -- brun rouge
	Color3.fromRGB(98, 96, 52), -- olive sombre
}
local function dotted(S, x0: number, y0: number, x1: number, y1: number, color: Color3, n: number, z: number)
	for i = 0, n - 1 do
		local t0, t1 = (i + 0.2) / n, (i + 0.65) / n
		S:line(x0 + (x1 - x0) * t0, y0 + (y1 - y0) * t0, x0 + (x1 - x0) * t1, y0 + (y1 - y0) * t1, 0.02, color, { z = z, fine = true })
	end
end
ACC.kesa = function(ctx, look)
	local base = look.kesaColor or KESA_TONES[1]
	local trim = look.kesaTrim or Color3.fromRGB(232, 206, 140)
	local thread = Color3.fromRGB(246, 226, 170)
	local cf = CFrame.Angles(0, 0, 0.74)
	-- Bande FINE (0,5) en travers du torse : le patchwork est peint, pas construit
	local band = ctx.add("Torso", "Kesa", Vector3.new(0.5, 2.86, 1.06), cf, base, { Material = Enum.Material.Fabric })
	local mode = ctx.paint == "parts" and "parts" or nil
	-- Carreaux : rangées de hauteurs inégales, 2 ou 3 colonnes décalées (motif fixe, pas aléatoire)
	local rows = {
		{ 0.11, { 0.55, 0.45 } },
		{ 0.16, { 0.3, 0.7 } },
		{ 0.12, { 0.62, 0.38 } },
		{ 0.15, { 0.4, 0.6 } },
		{ 0.1, { 0.5, 0.5 } },
		{ 0.17, { 0.68, 0.32 } },
		{ 0.19, { 0.36, 0.64 } },
	}
	for fi, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local S = Painter.sheet(band, face, mode, "Kesa" .. face.Name, 60)
		Painter.cloth(S, base)
		local front = fi == 1 and not S.lite
		local y, k = 0, fi
		local x0, x1 = S:dx(0.07), 1 - S:dx(0.07)
		for r, row in rows do
			local h = row[1]
			local x = x0
			for c, wfrac in row[2] do
				local w = (x1 - x0) * wfrac
				k = k % #KESA_TONES + 1 + ((r + c) % 2)
				local tone = KESA_TONES[(k - 1) % #KESA_TONES + 1]
				S:rect(x + w / 2, y + h / 2, w, h, tone, { gradient = { lighten(tone, 0.12), tone, darken(tone, 0.16) }, gradientRotation = 60 + r * 15, z = 1 })
				-- Petit pli d'étoffe dans le carreau
				if front and h > 0.14 then
					Painter.fold(S, x + w * 0.2, y + h * 0.3, x + w * 0.75, y + h * 0.55, tone, { w = 0.05, z = 2 })
				end
				-- Couture verticale entre deux carreaux
				if c < #row[2] then
					S:rect(x + w, y + h / 2, S:dx(0.035), h, darken(tone, 0.45), { z = 3 })
					if front then
						dotted(S, x + w + S:dx(0.035), y + 0.01, x + w + S:dx(0.035), y + h - 0.01, thread, 3, 4)
					end
				end
				x += w
			end
			y += h
			-- Couture horizontale (ombre + pointillés)
			if r < #rows then
				S:rect(0.5, y, 1, S:dy(0.035), darken(base, 0.5), { z = 3 })
				if front then
					dotted(S, x0, y + S:dy(0.03), x1, y + S:dy(0.03), thread, 3, 4)
				end
			end
		end
		-- Bord clair des deux côtés (galon) avec son trait d'ombre
		for _, side in { 0, 1 } do
			local bx = side == 0 and S:dx(0.035) or 1 - S:dx(0.035)
			S:rect(bx, 0.5, S:dx(0.07), 1, trim, { gradient = { lighten(trim, 0.15), trim, darken(trim, 0.2) }, gradientRotation = 0, z = 5 })
			S:rect(side == 0 and S:dx(0.075) or 1 - S:dx(0.075), 0.5, S:dx(0.014), 1, darken(trim, 0.6), { z = 6 })
		end
	end
	-- Petit nœud de cordon sur l'épaule (au lieu d'un grand anneau) : nœud + deux bouts qui pendent
	local cord = Color3.fromRGB(120, 70, 40)
	local knot = cf * CFrame.new(0, 0.82, -0.56)
	ctx.ball("Torso", "KesaKnot", Vector3.new(0.2, 0.16, 0.12), knot, cord)
	ctx.ball("Torso", "KesaKnotLoop", Vector3.new(0.14, 0.12, 0.08), knot * CFrame.new(-0.1, 0.06, -0.02), lighten(cord, 0.15))
	for i, dx in { -0.05, 0.06 } do
		ctx.strand("Torso", i == 1 and cord or darken(cord, 0.2), (knot * CFrame.new(dx, -0.06, -0.02)).Position, Vector3.new(dx, -1, -0.15), 0.4 - i * 0.06, 0.05)
	end
end

-- Larges manches de kimono : manche droite jusqu'au poignet, qui s'évase en bas (coins en Wedge
-- devant, derrière et sur le côté), ourlet sombre, et le fond de la manche qui pend dans le dos.
ACC.wide_sleeves = function(ctx, look)
	local color = look.sleeveColor or look.top or Color3.fromRGB(40, 38, 46)
	local hem = darken(color, 0.35)
	local flare = lighten(color, 0.04)
	local mode = ctx.paint == "parts" and "parts" or nil
	for _, side in { "Left Arm", "Right Arm" } do
		local sx = side == "Left Arm" and -1 or 1
		local sleeve = ctx.add(side, "KimonoSleeve", Vector3.new(1.2, 1.5, 1.4), CFrame.new(0, 0.2, 0.06), color)
		local outer = sx < 0 and Enum.NormalId.Left or Enum.NormalId.Right
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, outer } do
			local S = Painter.panel(sleeve, face, mode, color, nil, { folds = face ~= Enum.NormalId.Back })
			if face ~= Enum.NormalId.Back and not S.lite then
				Painter.fold(S, 0.45, 0.05, 0.38, 0.9, color, { w = 0.1, z = 6 })
			end
		end
		-- Évasement : trois coins (pente vers l'extérieur, plus large en bas)
		local y = -0.38
		local h = 0.6
		local t = 0.32
		ctx.wedge(side, "KimonoFlare", Vector3.new(1.2, h, t), CFrame.new(0, y, 0.06 - 0.7 - t / 2), flare)
		ctx.wedge(side, "KimonoFlare", Vector3.new(1.2, h, t), CFrame.new(0, y, 0.06 + 0.7 + t / 2) * CFrame.Angles(0, math.pi, 0), flare)
		ctx.wedge(side, "KimonoFlare", Vector3.new(1.4, h, t), CFrame.new(sx * (0.6 + t / 2), y, 0.06) * CFrame.Angles(0, -sx * math.pi / 2, 0), flare)
		-- Ourlet sombre au bas de l'évasement
		ctx.add(side, "KimonoHem", Vector3.new(1.2 + t, 0.08, 1.4 + 2 * t), CFrame.new(sx * t / 2, y - h / 2 + 0.04, 0.06), hem)
		-- Fond de la manche qui pend dans le dos
		ctx.ball(side, "KimonoSleeveBag", Vector3.new(1.1, 0.8, 0.9), CFrame.new(0, -0.55, 0.62), darken(color, 0.1))
	end
end

-- Couture qui fait le tour du front (Kenjakou) : fil sombre en relief, points de suture saillants
-- sur le devant, et une fine lueur violette dans la couture.
ACC.stitch_crown = function(ctx, look)
	local y = (look.eyeY or 0.03) + 0.33
	local glow = look.glowColor or Color3.fromRGB(170, 90, 255)
	-- Couture bien marquée : bourrelet de peau, lueur (Neon) de part et d'autre du fil sombre
	ctx.vcyl("Head", "StitchWelt", 0.07, 1.306, CFrame.new(0, y, 0), Color3.fromRGB(196, 150, 160), { CastShadow = false })
	ctx.vcyl("Head", "StitchGlow", 0.04, 1.314, CFrame.new(0, y, 0), glow, { Material = Enum.Material.Neon, Transparency = 0.1, CastShadow = false })
	ctx.vcyl("Head", "StitchLine", 0.018, 1.322, CFrame.new(0, y, 0), Color3.fromRGB(46, 30, 44), { CastShadow = false })
	for i = -4, 4 do
		local a = math.rad(i * 15)
		local r = 0.664
		ctx.add(
			"Head",
			"StitchPoint",
			Vector3.new(0.032, 0.15, 0.035),
			CFrame.new(-math.sin(a) * r, y, -math.cos(a) * r) * CFrame.Angles(0, a, math.rad(i % 2 == 0 and 14 or -14)),
			Color3.fromRGB(40, 26, 38),
			{ CastShadow = false }
		)
	end
end

-- Carrure massive (brutes, formes ultimes) : deltoïdes et trapèzes en relief, avant-bras épaissis
-- (couleur de la peau ou de la manche selon la tenue).
ACC.bulk = function(ctx, look)
	local c = Painter.palette(look)
	local upper = c.sleeves == "skin" and c.skin or c.sleeve
	local lower = c.sleeves == "long" and c.sleeve or c.skin
	for _, limb in { "Left Arm", "Right Arm" } do
		local out = limb == "Left Arm" and -1 or 1
		ctx.ball(limb, "Deltoid", Vector3.new(1.3, 1.05, 1.22), CFrame.new(out * 0.1, 0.62, 0), upper)
		ctx.ball(limb, "Forearm", Vector3.new(1.16, 0.8, 1.14), CFrame.new(out * 0.04, -0.42, 0), lower)
	end
	ctx.wedge("Torso", "Trapezius", Vector3.new(1.3, 0.34, 0.5), CFrame.new(0, 1.12, 0.22) * CFrame.Angles(0, math.pi, 0), c.top)
end

-- Grosses boucles d'oreilles (écarteurs noirs cerclés de bronze).
ACC.gauge_earrings = function(ctx, look)
	for _, side in { -1, 1 } do
		local cf = CFrame.new(side * (HEAD_R + 0.03), -0.3, 0.04)
		ctx.cyl("Head", "Gauge", 0.06, 0.3, cf, Color3.fromRGB(196, 160, 90), { Material = Enum.Material.Metal, Reflectance = 0.2 })
		ctx.cyl("Head", "GaugeCore", 0.08, 0.2, cf, Color3.fromRGB(18, 16, 20))
	end
	local _ = look
end

-- Armure organique de l'empereur du froid : dôme du crâne, épaules violettes brillantes.
ACC.freezo_gems = function(ctx, look)
	-- Forme finale : crâne lisse un peu allongé vers l'arrière, dôme violet brillant qui épouse le
	-- crâne (pointe sur le front), pommettes et trous d'oreilles, épaulières biseautées.
	local gem = look.gemColor or look.topAccent or Color3.fromRGB(140, 60, 190)
	local skin = look.skin or WHITE
	local shine = { Reflectance = 0.18, Material = Enum.Material.SmoothPlastic }
	ctx.ball("Head", "Skull", Vector3.new(1.2, 1.0, 1.34), CFrame.new(0, 0.22, 0.1), skin)
	ctx.ball("Head", "GemDome", Vector3.new(1.24, 0.66, 1.4), CFrame.new(0, 0.46, 0.12), gem, shine)
	-- Pointe du dôme sur le front
	ctx.blade("Head", gem, CFrame.new(0, 0.46, -0.58) * CFrame.Angles(math.rad(-14), 0, math.pi), 0.22, 0.34, 0.08, "GemDomePeak")
	ctx.ball("Head", "GemDomeShine", Vector3.new(0.36, 0.1, 0.24), CFrame.new(-0.22, 0.72, -0.24) * CFrame.Angles(0.5, 0, 0.2), lighten(gem, 0.6))
	for _, side in { -1, 1 } do
		ctx.ball("Head", "EarHole", Vector3.new(0.04, 0.13, 0.1), CFrame.new(side * 0.6, 0.02, 0.08), darken(gem, 0.45))
		-- Front en V : arcade osseuse qui plonge vers le nez (regard dur, sans sourcils)
		local a = math.rad(side * 24)
		local x = side * 0.17
		ctx.add(
			"Head",
			"BrowRidge",
			Vector3.new(0.3, 0.07, 0.08),
			CFrame.new(x, 0.21, -math.sqrt(0.64 * 0.64 - x * x) + 0.005) * CFrame.Angles(0, side * math.rad(16), 0) * CFrame.Angles(0, 0, a),
			darken(skin, 0.06),
			{ CastShadow = false }
		)
	end
	-- Menton pointu (lame triangulaire sous la bouche) et ombre sous le menton
	ctx.blade("Head", darken(skin, 0.03), CFrame.new(0, -0.47, -0.585) * CFrame.Angles(math.rad(-8), 0, math.pi), 0.26, 0.4, 0.1, "Chin")
	ctx.ball("Head", "ChinShadow", Vector3.new(0.5, 0.06, 0.3), CFrame.new(0, -0.62, -0.42), darken(skin, 0.3), { CastShadow = false })
	-- Épaulières : dômes bombés (armure organique), bord plus sombre, reflet
	for _, limb in { "Left Arm", "Right Arm" } do
		local x = limb == "Left Arm" and -0.05 or 0.05
		local top = CFrame.new(x, 0.92, 0)
		ctx.ball(limb, "GemShoulderRim", Vector3.new(1.2, 0.34, 1.2), top * CFrame.new(0, -0.08, 0), darken(gem, 0.3), shine)
		ctx.ball(limb, "GemShoulder", Vector3.new(1.16, 0.6, 1.16), top, gem, shine)
		ctx.ball(limb, "GemShoulderShine", Vector3.new(0.34, 0.1, 0.26), top * CFrame.new(-0.1, 0.25, -0.18) * CFrame.Angles(0.3, 0, 0), lighten(gem, 0.6))
	end
end

-- Longue queue blanche, ÉPAISSE, qui s'enroule au sol (5 segments qui s'affinent), bout violet.
ACC.freezo_tail = function(ctx, look)
	local skin = look.skin or WHITE
	local gem = look.gemColor or look.topAccent or Color3.fromRGB(140, 60, 190)
	local shadeSkin = skin:Lerp(Color3.fromRGB(176, 166, 206), 0.35)
	local pts = {
		Vector3.new(0, -0.75, 0.42),
		Vector3.new(0.1, -1.4, 1.15),
		Vector3.new(0.7, -2.3, 1.75),
		Vector3.new(1.65, -2.75, 1.5),
		Vector3.new(2.0, -2.8, 0.6),
		Vector3.new(1.45, -2.75, -0.05),
	}
	chain(ctx, "Torso", pts, { 0.72, 0.66, 0.58, 0.48, 0.38 }, { skin, skin, skin, shadeSkin, gem })
	-- Pointe effilée violette au bout
	ctx.ball("Torso", "TailTip", Vector3.new(0.28, 0.5, 0.28), alongY(Vector3.new(1.2, -2.72, -0.3), Vector3.new(-0.7, 0.15, -0.7)), gem, { Reflectance = 0.15 })
end

-- Poing de magma (amiral) : poing en lave incandescente, roche sombre, fumée et braises.
ACC.magma_fist = function(ctx, look)
	-- Poing de magma (amiral) : une coque de lave (Neon) qui ÉPOUSE l'avant-bras et le poing
	-- (à peine plus large que le bras, arêtes arrondies), plaques de roche refroidie, cœur plus
	-- clair sur les jointures, coulures en cônes qui pendent sous le poing, lumière orange,
	-- fumée et braises.
	local lava = Color3.fromRGB(255, 104, 18)
	local core = Color3.fromRGB(255, 196, 80)
	local rock = Color3.fromRGB(62, 24, 16)
	local arm = "Right Arm"
	local s = ctx.s
	local neon = { Material = Enum.Material.Neon }
	local limb = ctx.limbs[arm]
	local mode = ctx.paint == "parts" and "parts" or nil
	-- Lave PEINTE sur l'avant-bras (aucun volume en plus) : dégradé orange -> jaune vers le
	-- poing, fissures de basalte au bord, lumineuse (LightInfluence 0) par-dessus la manche.
	local faces = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
	for fi, face in faces do
		local S = Painter.sheet(limb, face, mode, "MagmaPaint" .. face.Name, 50)
		local top = 0.38
		S:rect(0.5, (top + 1) / 2, 1, 1 - top, lava, { gradient = { Color3.fromRGB(230, 70, 14), lava, core }, gradientRotation = 90, z = 1 })
		-- Bord irrégulier de la lave (dents) et croûte sombre au-dessus
		for i = 0, 2 do
			local x = (i + 0.5) / 3
			local h = 0.06 + ((i + fi) % 3) * 0.035
			S:rect(x, top - h / 2 + 0.01, 0.34, h, lava, { z = 1 })
			S:rect(x + 0.17, top - 0.02, 0.08, 0.09, rock, { rotation = 35 + i * 20, z = 2 })
		end
		-- Fissures sombres dans la lave
		S:line(0.2, 0.5, 0.45, 0.62, 0.05, rock, { z = 2 })
		S:line(0.45, 0.62, 0.38, 0.8, 0.04, rock, { z = 2 })
		S:line(0.7, 0.48, 0.82, 0.7, 0.045, rock, { z = 2 })
		local gui = (S.g :: any)
		if typeof(gui) == "Instance" and gui:IsA("SurfaceGui") then
			gui.LightInfluence = 0
			gui.Brightness = 1.4
			gui:SetAttribute("ZTop", true)
		end
	end
	-- Poing : sphère de lave écrasée, ajustée au poing (bras + 0,2 au plus), cœur plus clair
	local fist = ctx.ball(arm, "MagmaFist", Vector3.new(1.2, 0.66, 1.2), CFrame.new(0, -0.74, 0), lava, neon)
	ctx.ball(arm, "MagmaCore", Vector3.new(0.7, 0.3, 0.12), CFrame.new(0, -0.7, -0.56), core, neon)
	-- Croûtes de basalte noir (CornerWedge) plaquées sur la lave, sans dépasser de plus de 0,1
	for i, e in {
		{ -0.38, -0.2, -0.47, 0 },
		{ 0.4, -0.45, 0.47, math.pi },
		{ 0.47, -0.05, -0.2, math.pi / 2 },
		{ -0.47, -0.6, 0.2, -math.pi / 2 },
		{ 0.15, -0.95, -0.5, math.pi * 0.25 },
	} do
		ctx.cornerWedge(
			arm,
			"MagmaRock",
			Vector3.new(0.34, 0.28 + (i % 2) * 0.08, 0.16),
			CFrame.new(e[1], e[2], e[3]) * CFrame.Angles(0, e[4], 0),
			i % 2 == 0 and rock or Color3.fromRGB(28, 22, 24)
		).Material =
			Enum.Material.Basalt
	end
	-- Deux coulures fines sous le poing
	for _, e in { { 0.22, -0.1, 0.3, 0.16, lava }, { -0.2, 0.16, 0.22, 0.12, core } } do
		ctx.cone(arm, CFrame.new(e[1], -1.02, e[2]) * CFrame.Angles(math.pi, 0, 0), e[3], e[4], e[4], e[5], lava, nil, "MagmaDrip")
	end
	for _, d in ctx.model:GetChildren() do
		if d.Name == "MagmaDrip" then
			(d :: BasePart).Material = Enum.Material.Neon
		end
	end
	local light = Instance.new("PointLight")
	light.Name = "MagmaLight"
	light.Color = Color3.fromRGB(255, 130, 50)
	light.Brightness = 2
	light.Range = math.min(40, 8 * s)
	light.Shadows = false
	light.Parent = fist
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "MagmaSmoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 60, 60))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * s), NumberSequenceKeypoint.new(1, 1.4 * s) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(1, 1.8)
	smoke.Rate = 8
	smoke.Speed = NumberRange.new(0.6 * s, 1.2 * s)
	smoke.Acceleration = Vector3.new(0, 1.5 * s, 0)
	smoke.LightInfluence = 0.6
	smoke.Parent = fist
	local embers = Instance.new("ParticleEmitter")
	embers.Name = "MagmaEmbers"
	embers.Texture = "rbxasset://textures/particles/fire_main.dds"
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 150, 40), Color3.fromRGB(255, 60, 10))
	embers.LightEmission = 1
	embers.LightInfluence = 0
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45 * s), NumberSequenceKeypoint.new(1, 0) })
	embers.Lifetime = NumberRange.new(0.4, 0.8)
	embers.Rate = 14
	embers.Speed = NumberRange.new(0.5 * s, 1 * s)
	embers.Parent = fist
	local _ = look
end

-- Manteau de la justice (amiral) : il tombe en CAPE depuis les épaules (dos fin incliné vers
-- l'arrière jusqu'aux mollets, « 正義 » dans le dos), épaulettes à franges dorées, col relevé,
-- revers sur la poitrine, et des manches en coques ouvertes qui enveloppent les bras (soudées
-- aux bras : elles suivent les mouvements). Bord doré partout.
ACC.justice_coat = function(ctx, look)
	local white = look.coatColor or Color3.fromRGB(246, 246, 248)
	local gold = Color3.fromRGB(222, 176, 60)
	local mode = ctx.paint == "parts" and "parts" or nil
	local h = 3.5
	local back = ctx.add("Torso", "Coat", Vector3.new(2.9, h, 0.15), CFrame.new(0, 1.0, 0.6) * CFrame.Angles(-math.rad(8), 0, 0) * CFrame.new(0, -h / 2, 0), white)
	Painter.panel(back, Enum.NormalId.Back, mode, white, function(S)
		S:rect(0.5, 1 - S:dy(0.06), 1, S:dy(0.12), gold, { gradient = { Color3.fromRGB(255, 220, 110), gold }, z = 3 })
		for _, x in { S:dx(0.05), 1 - S:dx(0.05) } do
			S:rect(x, 0.5, S:dx(0.1), 1, gold, { z = 3 })
		end
	end, { folds = true })
	if mode ~= "parts" then
		local gui = back:FindFirstChildOfClass("SurfaceGui")
		if gui then
			local label = Instance.new("TextLabel")
			label.Name = "Justice"
			label.BackgroundTransparency = 1
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Position = UDim2.fromScale(0.5, 0.26)
			label.Size = UDim2.fromScale(0.8, 0.2)
			label.Text = "正義"
			label.TextScaled = true
			label.Font = Enum.Font.GothamBlack
			label.TextColor3 = Color3.fromRGB(28, 26, 32)
			label.ZIndex = 8
			label.Parent = gui
		end
	end
	-- Col relevé (deux pans inclinés derrière la nuque)
	for _, side in { -1, 1 } do
		ctx.add("Torso", "CoatCollar", Vector3.new(1.0, 0.62, 0.12), CFrame.new(side * 0.55, 1.22, 0.5) * CFrame.Angles(-0.3, side * 0.35, 0), white)
		-- Revers sur la poitrine (de l'épaule vers le bas du torse), bord doré
		local lapel = ctx.add("Torso", "CoatLapel", Vector3.new(0.34, 2.1, 0.1), CFrame.new(side * 0.83, -0.05, -0.56) * CFrame.Angles(0, 0, -side * 0.04), white)
		Painter.panel(lapel, Enum.NormalId.Front, mode, white, function(S)
			S:rect(side > 0 and S:dx(0.05) or 1 - S:dx(0.05), 0.5, S:dx(0.1), 1, gold, { z = 3 })
		end, { folds = false, edges = false })
	end
	for _, side in { -1, 1 } do
		-- Manteau POSÉ sur les épaules (porté en cape, bras libres dans le costume rouge) : un
		-- pan fin incliné de la base du cou jusqu'au bord de l'épaule, qui ne déborde que de 0,1,
		-- terminé par un coin (WedgePart) qui retombe ; liseré doré peint sur le bord.
		local slope = math.rad(4)
		local drape = CFrame.new(side * 1.28, 1.12, 0.04) * CFrame.Angles(0, 0, -side * slope)
		local plate = ctx.add("Torso", "CoatDrape", Vector3.new(1.62, 0.15, 1.2), drape, white)
		Painter.panel(plate, Enum.NormalId.Top, mode, white, function(S)
			S:rect(side > 0 and 1 - S:dx(0.05) or S:dx(0.05), 0.5, S:dx(0.1), 1, gold, { z = 3 })
			S:rect(0.5, S:dy(0.04), 1, S:dy(0.08), gold, { z = 3 })
			S:rect(0.5, 1 - S:dy(0.04), 1, S:dy(0.08), gold, { z = 3 })
		end, { folds = false, edges = false })
		-- Retombée au bord de l'épaule : coin dont la pente part vers l'extérieur
		local fall = CFrame.new(side * 2.06, 0.86, 0.04) * CFrame.Angles(0, -side * math.pi / 2, 0) * CFrame.Angles(math.pi, 0, 0)
		ctx.wedge("Torso", "CoatDrapeFall", Vector3.new(1.2, 0.3, 0.14), fall, white)
		ctx.add("Torso", "CoatDrapeTrim", Vector3.new(0.05, 0.05, 1.22), drape * CFrame.new(side * 0.81, -0.06, 0), gold, { Material = Enum.Material.Metal, Reflectance = 0.15 })
		-- Épaulette : fine plaque dorée + 6 franges fines qui pendent au bord de l'épaule
		local ep = drape * CFrame.new(side * 0.32, 0.1, 0)
		ctx.add("Torso", "Epaulette", Vector3.new(0.9, 0.05, 0.8), ep, gold, { Material = Enum.Material.Metal, Reflectance = 0.2 })
		ctx.add("Torso", "EpauletteRim", Vector3.new(0.92, 0.03, 0.82), ep * CFrame.new(0, -0.035, 0), darken(gold, 0.3), { Material = Enum.Material.Metal })
		ctx.ball("Torso", "EpauletteKnob", Vector3.new(0.16, 0.08, 0.16), ep * CFrame.new(-side * 0.38, 0.04, 0), gold, { Material = Enum.Material.Metal })
		for i = 0, 5 do
			local z = -0.32 + i * 0.128
			local top = ep * CFrame.new(side * 0.47, -0.02, z)
			ctx.vcyl("Torso", "EpauletteFringe", 0.34, 0.08, CFrame.new(top.Position + Vector3.new(0, -0.17, 0)), i % 2 == 0 and gold or darken(gold, 0.15), { Material = Enum.Material.Metal })
		end
	end
end

-- Insigne de la casquette de marine (mouette blanche sur fond bleu).
ACC.cap_badge = function(ctx, look)
	-- Insigne de la casquette : médaillon doré, fond bleu et mouette blanche peinte en relief.
	local band = look.capBand or Color3.fromRGB(40, 60, 140)
	local at = CFrame.new(0, 0.66, -0.735)
	ctx.cyl("Head", "CapBadgeRim", 0.04, 0.42, at * CFrame.Angles(0, math.pi / 2, 0), GOLD, { Material = Enum.Material.Metal, Reflectance = 0.2 })
	ctx.cyl("Head", "CapBadge", 0.05, 0.34, at * CFrame.new(0, 0, -0.012) * CFrame.Angles(0, math.pi / 2, 0), band)
	-- Mouette : deux ailes en « M » aplati
	for _, side in { -1, 1 } do
		ctx.add("Head", "CapBadgeGull", Vector3.new(0.13, 0.035, 0.03), at * CFrame.new(side * 0.06, 0.012, -0.045) * CFrame.Angles(0, 0, side * 0.42), WHITE)
		ctx.add("Head", "CapBadgeGull", Vector3.new(0.08, 0.03, 0.03), at * CFrame.new(side * 0.13, 0.03, -0.045) * CFrame.Angles(0, 0, -side * 0.5), WHITE)
	end
end

-- Ceinture de corde nouée (bleu marine) + deux pans.
ACC.rope_belt = function(ctx, look)
	local color = look.beltColor or Color3.fromRGB(40, 50, 110)
	ctx.add("Torso", "RopeBelt", Vector3.new(2.06, 0.22, 1.06), CFrame.new(0, -0.86, 0), color)
	ctx.add("Torso", "RopeBeltLine", Vector3.new(2.07, 0.04, 1.07), CFrame.new(0, -0.86, 0), lighten(color, 0.3))
	ctx.ball("Torso", "RopeKnot", Vector3.new(0.3, 0.26, 0.2), CFrame.new(-0.35, -0.86, -0.56), color)
	ctx.strand("Torso", color, Vector3.new(-0.38, -0.95, -0.58), Vector3.new(-0.1, -1, -0.05), 0.75, 0.14)
	ctx.strand("Torso", darken(color, 0.15), Vector3.new(-0.3, -0.95, -0.58), Vector3.new(0.12, -1, -0.05), 0.6, 0.13)
end

-- Sceau de la boussole (technique du démon) : flocon lumineux sous ses pieds.
ACC.compass_sigil = function(ctx, look)
	local color = look.sigilColor or Color3.fromRGB(140, 220, 255)
	local props = { Material = Enum.Material.Neon, Transparency = 0.3, CastShadow = false }
	local y = -2.94
	local R = 2.6
	local n = 12
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local len = 2 * R * math.sin(math.pi / n) + 0.04
		ctx.add("HumanoidRootPart", "Sigil", Vector3.new(len, 0.04, 0.09), CFrame.new(math.cos(a) * R, y, math.sin(a) * R) * CFrame.Angles(0, -a + math.pi / 2, 0), color, props)
	end
	for i = 0, 5 do
		local a = i / 6 * math.pi
		ctx.add("HumanoidRootPart", "Sigil", Vector3.new(2 * R + 0.5, 0.04, 0.07), CFrame.new(0, y, 0) * CFrame.Angles(0, a, 0), color, props)
	end
	local _ = look
end

-- Crâne bulbeux veiné (petit guerrier-plante) : cerveau en dôme allongé, nervures, arcades.
ACC.saiba_head = function(ctx, look)
	local skin = look.skin or Color3.fromRGB(90, 170, 70)
	local vein = look.veins or darken(skin, 0.35)
	ctx.ball("Head", "Cranium", Vector3.new(1.34, 1.0, 1.6), CFrame.new(0, 0.52, 0.16), skin)
	for _, x in { -0.32, 0, 0.32 } do
		ctx.ball("Head", "CraniumVein", Vector3.new(0.1, 0.16, 1.5), CFrame.new(x, 0.98 - math.abs(x) * 0.5, 0.16) * CFrame.Angles(0, 0, x * 0.9), vein)
	end
	for _, side in { -1, 1 } do
		ctx.ball("Head", "BrowRidge", Vector3.new(0.5, 0.14, 0.2), CFrame.new(side * 0.26, 0.24, -0.56) * CFrame.Angles(0, 0, side * 0.3), darken(skin, 0.12))
	end
end

-- Crête et ailes de la créature parfaite miniature (carapace verte tachetée).
ACC.cell_crest = function(ctx, look)
	local plate = look.carapace or Color3.fromRGB(70, 150, 90)
	local spot = look.spots or Color3.fromRGB(25, 35, 25)
	ctx.ball("Head", "CrestCap", Vector3.new(1.32, 0.7, 1.4), CFrame.new(0, 0.58, 0.08), plate)
	for _, side in { -1, 1 } do
		ctx.spike("Head", plate, Vector3.new(side * 0.42, 0.72, 0.15), Vector3.new(side * 0.55, 0.9, 0.55), 0.8, 0.44)
		ctx.ball("Head", "CrestSpot", Vector3.new(0.14, 0.1, 0.14), CFrame.new(side * 0.25, 0.9, -0.2), spot)
	end
	-- Ailes (élytres) dans le dos
	for _, side in { -1, 1 } do
		local frame = CFrame.new(side * 0.42, 0.7, 0.58) * CFrame.Angles(0, 0, side * 0.25) * CFrame.Angles(math.pi, 0, 0)
		ctx.blade("Torso", darken(plate, 0.15), frame, 2.2, 0.8, 0.08, "Wing")
	end
end

-- Griffes blanches au bout des mains (créatures).
ACC.claws = function(ctx, look)
	local claw = look.clawColor or Color3.fromRGB(240, 236, 224)
	for _, side in { "Left Arm", "Right Arm" } do
		for i = -1, 1 do
			ctx.spike(side, claw, Vector3.new(i * 0.28, -0.95, -0.35), Vector3.new(i * 0.2, -1, -0.5), 0.3, 0.14)
		end
	end
end

------------------------------------------------------------------------
-- Effets des évolutions (★★ / ★★★) : énergie dans les mains, orbes, vapeur...
------------------------------------------------------------------------

local function glowLight(part: BasePart, color: Color3, range: number, brightness: number?)
	local light = Instance.new("PointLight")
	light.Name = "EvolutionGlow"
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1.5
	light.Shadows = false
	light.Parent = part
	return light
end

local function sparkles(part: BasePart, color: Color3, s: number, rate: number?)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "EvolutionSparks"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 * s), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Rate = rate or 18
	emitter.Speed = NumberRange.new(1 * s, 2.5 * s)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = part
	return emitter
end

-- Aura d'énergie (évolutions, boss) : PAS de plaques plantées derrière le perso. Une enveloppe
-- invisible un peu plus grande que le corps émet des particules depuis sa SURFACE (elles
-- entourent la silhouette au lieu de naître cachées dans le torse), flammes qui montent +
-- étincelles, deux rayons (Beam) qui montent le long du corps, et une lumière.
-- o = { texture ("fire" | "sparkles"), rate, beams (false = sans), light (false = sans), size }
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
local SPARKLES_TEX = "rbxasset://textures/particles/sparkles_main.dds"
local function auraFx(ctx, color: Color3, o)
	local opts = o or {}
	local s = ctx.s
	local hot = color:Lerp(WHITE, 0.45)
	local shell = ctx.add("Torso", "AuraShell", Vector3.new(3.1, 5.2, 1.7), CFrame.new(0, -0.9, 0.1), WHITE, { Transparency = 1, CastShadow = false })
	local flames = Instance.new("ParticleEmitter")
	flames.Name = "AuraFlames"
	flames.Texture = opts.texture == "sparkles" and SPARKLES_TEX or FIRE_TEX
	flames.Color = ColorSequence.new(hot, color)
	flames.LightEmission = 1
	flames.LightInfluence = 0
	flames.Shape = Enum.ParticleEmitterShape.Box
	flames.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	flames.EmissionDirection = Enum.NormalId.Top
	flames.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, (opts.size or 0.9) * s),
		NumberSequenceKeypoint.new(0.6, (opts.size or 0.9) * 0.7 * s),
		NumberSequenceKeypoint.new(1, 0),
	})
	flames.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	flames.Lifetime = NumberRange.new(0.45, 0.85)
	flames.Rate = opts.rate or 34
	flames.Speed = NumberRange.new(1.5 * s, 3 * s)
	flames.SpreadAngle = Vector2.new(12, 12)
	flames.Acceleration = Vector3.new(0, 2 * s, 0)
	flames.Parent = shell
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "AuraSparks"
	sparks.Texture = SPARKLES_TEX
	sparks.Color = ColorSequence.new(WHITE, hot)
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Shape = Enum.ParticleEmitterShape.Box
	sparks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 * s), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.4, 0.8)
	sparks.Rate = 12
	sparks.Speed = NumberRange.new(2 * s, 4 * s)
	sparks.Parent = shell
	if opts.beams ~= false then
		-- Deux rayons qui montent le long du corps (des mollets au-dessus de la tête)
		for _, side in { -1, 1 } do
			local a0 = Instance.new("Attachment")
			a0.Name = "AuraBeamFrom"
			a0.Position = Vector3.new(side * 1.25, -2.4, 0.35) * s
			a0.Parent = shell
			local a1 = Instance.new("Attachment")
			a1.Name = "AuraBeamTo"
			a1.Position = Vector3.new(side * 0.85, 3.4, 0.35) * s
			a1.Parent = shell
			local beam = Instance.new("Beam")
			beam.Name = "AuraBeam"
			beam.Attachment0 = a0
			beam.Attachment1 = a1
			beam.Texture = FIRE_TEX
			beam.TextureMode = Enum.TextureMode.Stretch
			beam.TextureSpeed = 1.6
			beam.Color = ColorSequence.new(color, hot)
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.45),
				NumberSequenceKeypoint.new(0.75, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			})
			beam.Width0 = 1.1 * s
			beam.Width1 = 0.3 * s
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.FaceCamera = true
			beam.Segments = 8
			beam.CurveSize0 = side * 0.6 * s
			beam.Parent = shell
		end
	end
	if opts.light ~= false then
		glowLight(ctx.limbs.Torso, color, 12 * s, 1.4)
	end
	return shell
end

-- Aura d'énergie générique (look.auraColor, sinon look.energyColor)
ACC.energy_aura = function(ctx, look)
	auraFx(ctx, look.auraColor or look.energyColor or Color3.fromRGB(110, 170, 255))
end

-- Boule d'énergie tenue DANS la main (soudée à l'attache de la main, CFrame (0, -1.1, 0) du
-- bras) : cœur blanc, sphère Neon, enveloppe translucide plus grande, lumière.
local function handOrb(ctx, arm: string, name: string, color: Color3, size: number, core: Color3?)
	local at = CFrame.new(0, -1.1, 0)
	local orb = ctx.ball(arm, name, Vector3.new(size, size, size), at, color, { Material = Enum.Material.Neon, Transparency = 0.15, CastShadow = false })
	ctx.ball(arm, name .. "Core", Vector3.new(size * 0.55, size * 0.55, size * 0.55), at, core or WHITE, { Material = Enum.Material.Neon, CastShadow = false })
	ctx.ball(arm, name .. "Shell", Vector3.new(size * 1.55, size * 1.55, size * 1.55), at, color, { Material = Enum.Material.Neon, Transparency = 0.72, CastShadow = false })
	glowLight(orb, color, 9 * ctx.s, 2)
	return orb
end

-- Mille Oiseaux : boule d'éclairs bleus crépitante tenue dans la main gauche.
ACC.chidori = function(ctx, look)
	local color = look.energyColor or Color3.fromRGB(120, 200, 255)
	local core = handOrb(ctx, "Left Arm", "Chidori", color, 0.8)
	-- Éclairs qui jaillissent de la boule (fines pointes Neon)
	ctx.style = { Material = Enum.Material.Neon, CastShadow = false }
	for i = 0, 5 do
		local a = i * 1.05
		local dir = Vector3.new(math.cos(a), -0.4 + (i % 2) * 0.8, math.sin(a))
		ctx.spike("Left Arm", i % 2 == 0 and color or WHITE, Vector3.new(0, -1.1, 0) + dir.Unit * 0.3, dir, 0.6, 0.1, { cross = false, thickness = 0.04 })
	end
	ctx.style = nil
	sparkles(core, color, ctx.s, 24)
end

-- Poings chargés d'énergie : une boule d'énergie dans chaque main.
ACC.energy_fists = function(ctx, look)
	local color = look.energyColor or Color3.fromRGB(80, 120, 255)
	for _, side in { "Left Arm", "Right Arm" } do
		local orb = handOrb(ctx, side, "EnergyFist", color, 0.78, lighten(color, 0.7))
		if side == "Right Arm" then
			sparkles(orb, color, ctx.s, 12)
		end
	end
end

-- Orbe violet (technique du vide) tenu dans la main droite, anneau d'énergie autour.
ACC.hollow_purple = function(ctx, look)
	local color = look.energyColor or Color3.fromRGB(170, 70, 255)
	local orb = handOrb(ctx, "Right Arm", "HollowPurple", color, 1.0, Color3.fromRGB(245, 225, 255))
	-- Deux demi-orbes (rouge et bleu) qui fusionnent
	ctx.ball(
		"Right Arm",
		"HollowRed",
		Vector3.new(0.32, 0.32, 0.32),
		CFrame.new(0.5, -0.95, -0.1),
		Color3.fromRGB(255, 70, 90),
		{ Material = Enum.Material.Neon, CastShadow = false }
	)
	ctx.ball(
		"Right Arm",
		"HollowBlue",
		Vector3.new(0.32, 0.32, 0.32),
		CFrame.new(-0.5, -1.25, 0.1),
		Color3.fromRGB(80, 150, 255),
		{ Material = Enum.Material.Neon, CastShadow = false }
	)
	sparkles(orb, color, ctx.s, 16)
end

-- Super Saiyan 3 : flammes d'aura dorées autour du corps (lames Neon translucides), lumière et
-- étincelles : le perso est cerné d'un liseré doré lumineux.
ACC.ssj_aura = function(ctx, look)
	-- Aura de super guerrier : flammes dorées (ou couleur de l'aura) qui montent autour du corps
	local gold = look.auraColor or Color3.fromRGB(255, 214, 80)
	local shell = auraFx(ctx, gold, { rate = 40 })
	shell.Name = "SuperSaiyanAura"
	local light = ctx.limbs.Torso:FindFirstChild("EvolutionGlow")
	if light then
		light.Name = "SuperSaiyanGlow"
	end
end

-- Souffle de l'Eau : sabre dégainé dans la main droite, lame bleu nuit au fil clair, et la
-- vague qui s'enroule autour de la lame (rayons Beam bleus + gouttes).
ACC.water_blade = function(ctx, look)
	local water = look.energyColor or Color3.fromRGB(70, 170, 255)
	local arm = "Right Arm"
	local grip = CFrame.new(0, -1.05, -0.05) * CFrame.Angles(math.rad(-58), 0, 0)
	ctx.add(arm, "WaterTsuka", Vector3.new(0.13, 0.7, 0.18), grip * CFrame.new(0, 0.1, 0), Color3.fromRGB(30, 30, 34))
	ctx.cyl(arm, "WaterTsuba", 0.06, 0.42, grip * CFrame.new(0, 0.48, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(40, 38, 42), { Material = Enum.Material.Metal })
	local bladeCf = grip * CFrame.new(0, 0.5 + 1.25, 0)
	local blade = ctx.add(arm, "WaterBlade", Vector3.new(0.05, 2.5, 0.18), bladeCf, Color3.fromRGB(30, 34, 52), { Material = Enum.Material.Metal, Reflectance = 0.3 })
	ctx.add(arm, "WaterEdge", Vector3.new(0.055, 2.5, 0.04), bladeCf * CFrame.new(0, 0, -0.1), Color3.fromRGB(200, 236, 255), { Material = Enum.Material.Neon })
	-- Vague : deux rayons courbes de la garde à la pointe, de part et d'autre de la lame
	for i, side in { -1, 1 } do
		local a0 = Instance.new("Attachment")
		a0.Name = "WaveFrom"
		a0.Position = Vector3.new(0, -1.2, 0) * ctx.s
		a0.Parent = blade
		local a1 = Instance.new("Attachment")
		a1.Name = "WaveTo"
		a1.Position = Vector3.new(0, 1.35, side * 0.1) * ctx.s
		a1.Parent = blade
		local beam = Instance.new("Beam")
		beam.Name = "WaterWave"
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = ColorSequence.new(Color3.fromRGB(150, 220, 255), water)
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.4, 0.3), NumberSequenceKeypoint.new(1, 0.85) })
		beam.Width0 = 0.25 * ctx.s
		beam.Width1 = 0.6 * ctx.s
		beam.CurveSize0 = side * 0.9 * ctx.s
		beam.CurveSize1 = -side * 0.7 * ctx.s
		beam.Segments = 12
		beam.LightEmission = 0.8
		beam.LightInfluence = 0.2
		beam.FaceCamera = true
		beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		beam.TextureSpeed = 2 + i
		beam.Parent = blade
	end
	local drops = Instance.new("ParticleEmitter")
	drops.Name = "WaterDrops"
	drops.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	drops.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255), water)
	drops.LightEmission = 0.7
	drops.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3 * ctx.s), NumberSequenceKeypoint.new(1, 0) })
	drops.Lifetime = NumberRange.new(0.4, 0.8)
	drops.Rate = 14
	drops.Speed = NumberRange.new(0.6 * ctx.s, 1.4 * ctx.s)
	drops.SpreadAngle = Vector2.new(180, 180)
	drops.Acceleration = Vector3.new(0, -3 * ctx.s, 0)
	drops.Parent = blade
	glowLight(blade, water, 8 * ctx.s, 1.2)
	local _ = look
end

-- Mode Ermite : les deux vieux crapauds sages perchés sur les épaules (corps trapu vert-gris,
-- gros yeux, petite cape, sourcils blancs).
ACC.sage_toads = function(ctx, look)
	local skins = { Color3.fromRGB(122, 140, 96), Color3.fromRGB(146, 150, 104) }
	local capes = { Color3.fromRGB(150, 40, 40), Color3.fromRGB(220, 200, 140) }
	for i, side in { -1, 1 } do
		local skin = skins[i]
		local at = CFrame.new(side * 1.5, 1.3, 0.05)
		ctx.ball("Torso", "ToadBody", Vector3.new(0.82, 0.6, 0.72), at * CFrame.new(0, 0.28, 0), skin)
		ctx.ball("Torso", "ToadBelly", Vector3.new(0.6, 0.42, 0.3), at * CFrame.new(0, 0.22, -0.26), skin:Lerp(Color3.fromRGB(236, 226, 190), 0.6))
		ctx.ball("Torso", "ToadCape", Vector3.new(0.9, 0.36, 0.7), at * CFrame.new(0, 0.42, 0.08), capes[i])
		for _, e in { -1, 1 } do
			ctx.ball("Torso", "ToadEye", Vector3.new(0.24, 0.24, 0.2), at * CFrame.new(e * 0.2, 0.62, -0.18), Color3.fromRGB(250, 246, 220))
			ctx.ball("Torso", "ToadPupil", Vector3.new(0.12, 0.06, 0.06), at * CFrame.new(e * 0.2, 0.62, -0.28), Color3.fromRGB(30, 26, 20))
			ctx.ball("Torso", "ToadBrow", Vector3.new(0.2, 0.06, 0.08), at * CFrame.new(e * 0.22, 0.76, -0.18) * CFrame.Angles(0, 0, -e * 0.3), WHITE)
		end
	end
	local _ = look
end

-- Danse du dieu du feu : sabre noir dégainé dans la main droite, embrasé (flammes Neon
-- orange et jaunes le long de la lame), et flammes qui s'enroulent autour du bras.
ACC.sun_flames = function(ctx, look)
	local fire = look.energyColor or Color3.fromRGB(255, 120, 30)
	local hot = Color3.fromRGB(255, 220, 90)
	local arm = "Right Arm"
	-- Corps de flammes (look.fireBody) : pas de sabre, les deux avant-bras s'embrasent
	local arms = look.fireBody and { "Right Arm", "Left Arm" } or { arm }
	if not look.fireBody then
		-- Sabre tenu pointe vers l'avant
		local grip = CFrame.new(0, -1.05, -0.05) * CFrame.Angles(math.rad(-58), 0, 0)
		ctx.add(arm, "FireTsuka", Vector3.new(0.13, 0.7, 0.18), grip * CFrame.new(0, 0.1, 0), Color3.fromRGB(30, 30, 34))
		ctx.cyl(arm, "FireTsuba", 0.06, 0.42, grip * CFrame.new(0, 0.48, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(40, 38, 42), { Material = Enum.Material.Metal })
		local bladeCf = grip * CFrame.new(0, 0.5 + 1.25, 0)
		ctx.add(arm, "FireBlade", Vector3.new(0.05, 2.5, 0.18), bladeCf, Color3.fromRGB(26, 24, 30), { Material = Enum.Material.Metal, Reflectance = 0.25 })
		ctx.add(arm, "FireEdge", Vector3.new(0.055, 2.5, 0.04), bladeCf * CFrame.new(0, 0, -0.1), hot, { Material = Enum.Material.Neon })
		-- Flammes le long de la lame (lames triangulaires inclinées vers l'arrière)
		ctx.style = { Material = Enum.Material.Neon, Transparency = 0.15, CastShadow = false }
		for i = 0, 4 do
			local t = -1.0 + i * 0.5
			ctx.blade(arm, i % 2 == 0 and fire or hot, bladeCf * CFrame.new(0, t, 0.05) * CFrame.Angles(math.rad(-55), 0, 0), 0.75 - i * 0.06, 0.32, 0.05, "SunFlame")
		end
	end
	ctx.style = { Material = Enum.Material.Neon, Transparency = 0.15, CastShadow = false }
	-- Flammes autour de l'avant-bras
	for _, limb in arms do
		for i = 0, 3 do
			local a = i * (math.pi / 2) + 0.4
			local from = Vector3.new(math.cos(a) * 0.52, -0.55 + (i % 2) * 0.25, math.sin(a) * 0.52)
			local big = look.fireBody and 1.5 or 1
			ctx.blade(
				limb,
				i % 2 == 0 and hot or fire,
				CFrame.new(from) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.cos(a) * 0.3),
				0.8 * big,
				0.34 * big,
				0.05,
				"SunFlame"
			)
		end
		if look.fireBody then
			-- Avant-bras changé en flammes : enveloppe orangée translucide
			ctx.style = { Material = Enum.Material.Neon, Transparency = 0.5, CastShadow = false }
			ctx.ball(limb, "FireArm", Vector3.new(1.2, 1.4, 1.2), CFrame.new(0, -0.55, 0), fire)
			ctx.style = { Material = Enum.Material.Neon, Transparency = 0.15, CastShadow = false }
		end
	end
	ctx.style = nil
	local core =
		ctx.ball(arm, "SunFlameCore", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, -1.05, -0.3), hot, { Material = Enum.Material.Neon, Transparency = 0.3, CastShadow = false })
	glowLight(core, fire, 9 * ctx.s, 1.8)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "SunFlames"
	emitter.Texture = "rbxasset://textures/particles/fire_main.dds"
	emitter.Color = ColorSequence.new(hot, fire)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * ctx.s), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Rate = 20
	emitter.Speed = NumberRange.new(1 * ctx.s, 2 * ctx.s)
	emitter.Parent = core
end

-- Petites lunettes de soleil rondes (remplacent le bandeau : on devine les Six Yeux).
ACC.round_glasses = function(ctx, look)
	local frame = Color3.fromRGB(20, 20, 26)
	local y = (look.eyeY or 0.03) + 0.0
	for _, side in { -1, 1 } do
		local x = side * (look.eyeX or 0.25)
		local z = -math.sqrt(math.max(0, (HEAD_R + 0.03) ^ 2 - x * x))
		ctx.cyl("Head", "Lens", 0.03, 0.26, CFrame.new(x, y - 0.04, z) * CFrame.Angles(0, math.pi / 2 - math.asin(x / (HEAD_R + 0.03)), 0), frame, { Reflectance = 0.3 })
	end
	ctx.add("Head", "GlassesBridge", Vector3.new(0.22, 0.03, 0.03), CFrame.new(0, y, -HEAD_R - 0.02), frame)
end

-- Vapeur rose qui s'échappe du corps (deuxième vitesse).
ACC.steam = function(ctx, look)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Steam"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(look.steamColor or Color3.fromRGB(255, 210, 210))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * ctx.s), NumberSequenceKeypoint.new(1, 1.6 * ctx.s) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Rate = 10
	emitter.Speed = NumberRange.new(1 * ctx.s, 2 * ctx.s)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.Parent = ctx.limbs.Torso
end

-- Effets communs des boss (look.boss = { rim, light, aura, paintLight }) :
--   * liseré lumineux (Highlight) qui détache la silhouette du décor, même dans une arène de nuit ;
--   * lumière douce sur lui + lumière de face (visage et tenue lisibles) ;
--   * aura de particules ;
--   * peinture moins sensible à l'éclairage ambiant (tenue et visage lisibles dans la pénombre).
bossKit = function(ctx, look)
	local spec = look.boss
	local model, s = ctx.model, ctx.s
	local rim = spec.rim or WHITE
	-- Liseré lumineux : CONTOUR seul (un remplissage coloré délavait la peinture et la peau)
	local highlight = Instance.new("Highlight")
	highlight.Name = "BossRim"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = rim
	highlight.FillTransparency = 1
	highlight.OutlineColor = rim
	highlight.OutlineTransparency = spec.outline or 0.3
	highlight.Parent = model
	-- Halo de la couleur de l'univers autour du corps (discret)
	local glow = Instance.new("PointLight")
	glow.Name = "BossGlow"
	glow.Color = spec.light or rim
	glow.Brightness = spec.brightness or 0.5
	glow.Range = math.min(60, 7 * s)
	glow.Shadows = false
	glow.Parent = ctx.limbs.Torso
	-- Lumière de face blanc chaud (pas la couleur de l'univers : la peau garde sa couleur), sur
	-- une pièce invisible devant la poitrine
	local warm = Color3.fromRGB(255, 240, 225)
	local key = ctx.add("Torso", "BossKeyLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 1.2, -3), WHITE, { Transparency = 1, CastShadow = false })
	local front = Instance.new("PointLight")
	front.Name = "BossKey"
	front.Color = warm
	front.Brightness = spec.keyBrightness or 0.8
	front.Range = math.min(60, 6 * s)
	front.Shadows = false
	front.Parent = key
	-- Lumière douce sous le visage : éclaire le visage de face et d'un peu en dessous (un
	-- visage de boss ne doit jamais être une tache sombre sous ses cheveux)
	local chin = ctx.add(
		"Torso",
		"BossFaceLight",
		Vector3.new(0.6, 0.6, 0.1),
		CFrame.new(0, 1.0, -2.2) * CFrame.Angles(math.rad(-25), 0, 0),
		WHITE,
		{ Transparency = 1, CastShadow = false }
	)
	local faceLight = Instance.new("SurfaceLight")
	faceLight.Name = "BossFaceLight"
	faceLight.Face = Enum.NormalId.Back
	faceLight.Angle = 70
	faceLight.Color = warm
	faceLight.Brightness = 0.4
	faceLight.Range = math.min(40, 4 * s)
	faceLight.Shadows = false
	faceLight.Parent = chin
	if spec.aura then
		-- Aura de particules autour de la silhouette (émise depuis une enveloppe invisible)
		local shell = auraFx(ctx, spec.aura, { texture = "sparkles", rate = 22, beams = false, light = false, size = 0.7 })
		shell.Name = "BossAura"
	end
	for _, d in model:GetDescendants() do
		if d:IsA("SurfaceGui") and not d:GetAttribute("ZTop") then
			d.LightInfluence = spec.paintLight or 0.45
			d.Brightness = 1.15
		end
	end
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

export type BuildOptions = {
	scale: number?,
	name: string?,
	humanoid: boolean?,
	anchored: boolean?,
	walkSpeed: number?,
	collisionGroup: string?,
	paint: string?, -- "gui" (par défaut) ou "parts" (aperçus des menus)
}

-- Forme de la tête propre au perso : `look.headScale` = nombre (tête plus grande, ex. 1.12 pour un
-- boss trop « petite tête ») ou Vector3 (largeur, hauteur, profondeur : mâchoire large des brutes,
-- visage étroit des persos fins). Tout ce qui est soudé à la tête (cheveux, visage peint,
-- chapeau...) suit : positions et tailles mises à l'échelle autour du centre de la tête, et la
-- tête monte pour que le cou reste en place.
local function reshapeHead(ctx, k: Vector3)
	local head = ctx.limbs.Head
	local torso = ctx.limbs.Torso
	local hcf = head.CFrame
	local lift = (k.Y - 1) * TOP * ctx.s
	local welds = {}
	for _, d in ctx.model:GetDescendants() do
		if d:IsA("Weld") then
			table.insert(welds, d)
		end
	end
	local group = { [head] = true }
	local grew = true
	while grew do
		grew = false
		for _, w in welds do
			if w.Part0 and group[w.Part0] and w.Part1 and not group[w.Part1] then
				group[w.Part1] = true
				grew = true
			end
		end
	end
	local target = hcf * CFrame.new(0, lift, 0)
	for part in group do
		local rel = hcf:ToObjectSpace(part.CFrame)
		local p = rel.Position
		local rot = rel.Rotation
		if part ~= head then
			local fx = (rot.RightVector * k).Magnitude
			local fy = (rot.UpVector * k).Magnitude
			local fz = (rot.LookVector * k).Magnitude
			part.Size = Vector3.new(part.Size.X * fx, part.Size.Y * fy, part.Size.Z * fz)
		end
		part.CFrame = target * CFrame.new(p.X * k.X, p.Y * k.Y, p.Z * k.Z) * rot
	end
	local mesh = head:FindFirstChild("Mesh") :: SpecialMesh?
	if mesh then
		mesh.Scale = HEAD_MESH_SCALE * k
	end
	for _, w in welds do
		if w.Part1 and group[w.Part1] and w.Part0 then
			w.C0 = w.Part0.CFrame:Inverse() * w.Part1.CFrame
		end
	end
	local neck = torso:FindFirstChild("Neck") :: Motor6D?
	if neck then
		neck.C1 = head.CFrame:Inverse() * torso.CFrame * neck.C0
	end
end

local HATS = { "boar_head", "hood_full", "straw_hat", "volcano", "dome", "turban", "cap", "bandana", "cowboy_hat" }

function CharacterBuilder.build(look, options: BuildOptions?): Model
	local opts = options or {}
	local s = opts.scale or 1
	local model = Instance.new("Model")
	model.Name = opts.name or "Character"

	local ctx = newContext(model, s, opts.paint or "gui")
	ctx.hairDarken = look.hairDarken
	Painter.scale = s
	buildBody(ctx, look)

	local hairColor = look.hairColor or BLACK
	local covered = false
	for _, hat in HATS do
		if has(look, hat) then
			covered = true
			break
		end
	end
	if not covered then
		local builder = HAIR[look.hair or "short"] or HAIR.short
		builder(ctx, hairColor, look)
	elseif (has(look, "straw_hat") or has(look, "cap") or has(look, "bandana") or has(look, "cowboy_hat")) and look.hair ~= "none" and look.hair ~= "bald" then
		-- Cheveux visibles sous le chapeau : nuque, mèches sur les côtés et frange en bataille.
		local under, shine = hairTones(hairColor, look)
		cap(ctx, under, { height = 0.7, lift = -0.06, backLength = 1.3 })
		fringe(ctx, hairColor, { -0.4, -0.15, 0.12, 0.38 }, { 0.2, 0.24, 0.2, 0.22 }, 0.28, { alt = shine, y = 0.34, spread = 0.6, out = 0.04, thickness = 0.1 })
		for _, side in { -1, 1 } do
			-- Cheveux courts sous la casquette (`sideburns`) : pattes peintes, pas de mèches longues
			if not look.sideburns then
				ctx.lock("Head", hairColor, Vector3.new(side * 0.6, 0.3, -0.1), Vector3.new(side * 0.15, -1, 0), 0.4, 0.36, { facing = Vector3.new(side, 0, 0.2), thickness = 0.12 })
			end
			ctx.spike("Head", under, Vector3.new(side * 0.3, 0.05, 0.55), Vector3.new(side * 0.3, -0.8, 0.8), 0.36, 0.42, { cross = false })
		end
	end

	for _, accessory in look.accessories or {} do
		local builder = ACC[accessory]
		if builder then
			builder(ctx, look)
		end
	end

	if look.boss then
		bossKit(ctx, look)
	end
	if look.headScale then
		local k = look.headScale
		reshapeHead(ctx, typeof(k) == "Vector3" and k or Vector3.new(k, k, k))
	end
	Painter.scale = 1
	model:SetAttribute("BaseScale", s)
	if look.variety then
		CharacterBuilder.applyVariety(model, look.variety)
	end
	if ctx.paint ~= "parts" then
		-- Niveau de détail intermédiaire (tenue lisible de 55 à ~140 studs : persos sur la base)
		Painter.lods(model)
		model:SetAttribute("Lod", true)
	end

	local root = ctx.limbs.HumanoidRootPart
	model.PrimaryPart = root
	if opts.anchored then
		root.Anchored = true
	end

	if opts.collisionGroup then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CollisionGroup = opts.collisionGroup
			end
		end
	end

	if opts.humanoid then
		local humanoid = Instance.new("Humanoid")
		humanoid.RigType = Enum.HumanoidRigType.R6
		humanoid.WalkSpeed = opts.walkSpeed or 16
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.AutoJumpEnabled = true
		humanoid.MaxHealth = 1e9
		humanoid.Health = 1e9
		humanoid.Parent = model
		local animator = Instance.new("Animator")
		animator.Parent = humanoid
	else
		local controller = Instance.new("AnimationController")
		controller.Parent = model
		local animator = Instance.new("Animator")
		animator.Parent = controller
	end

	model:SetAttribute("BaseScale", s)
	model:SetAttribute("RootHeight", CharacterBuilder.RootHeight * s)
	return model
end

------------------------------------------------------------------------
-- Variétés (mutations) : la rareté de BASE du perso ne change pas, la variété se voit en plus,
-- sur TOUT le perso, sans noyer la peinture : les couleurs de chaque forme peinte sont
-- re-teintées (dégradé de teinte selon la luminosité, mélangé à 50 % : les traits encrés, les
-- plis et les ombres restent lisibles), quelques reflets fins en diagonale pour l'Or et le
-- Diamant ; cheveux et accessoires changent de couleur ET de matière (or poli Foil, cristal
-- Glass) ; particules propres à la variété ; pièces en plus (auréole, ailes, fleur) ; liseré
-- coloré (Highlight, contour seul) pour l'Ombre et l'Arc-en-ciel.
------------------------------------------------------------------------

local VARIETY_ALIASES = {
	dore = "gold",
	["doré"] = "gold",
	["or"] = "gold",
	golden = "gold",
	diamant = "diamond",
	blossom = "sakura",
	cerisier = "sakura",
	angelique = "angelic",
	["angélique"] = "angelic",
	ange = "angelic",
	ombre = "shadow",
	arcenciel = "rainbow",
	["arc-en-ciel"] = "rainbow",
	galaxie = "galaxy",
	givre = "frost",
	flamme = "fire",
	foudre = "lightning",
	neant = "void",
	["néant"] = "void",
}

local rgb = Color3.fromRGB
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

-- hair/mix : teinte des cheveux (+ matière) ; acc = couleur/matière des accessoires ;
-- ramp/rampMix = teinte de la peinture (sombre, moyen, clair selon la luminosité) ;
-- desat/dim = peinture et peau désaturées/assombries ; glint = reflets fins en diagonale ;
-- motif = "stars" | "petals" sur le torse ; outline = liseré (Highlight) ; fx = particules.
local VARIETIES = {
	gold = {
		hair = rgb(232, 181, 48),
		mix = 0.8,
		material = Enum.Material.Foil,
		reflectance = 0.25,
		acc = { color = rgb(232, 181, 48), mix = 0.78, material = Enum.Material.Foil, reflectance = 0.25 },
		ramp = { rgb(110, 66, 12), rgb(236, 178, 46), rgb(255, 240, 168) },
		rampMix = 0.62,
		glint = true,
		fx = { texture = SPARK, colors = { rgb(255, 230, 120), rgb(255, 170, 30) }, size = 0.32, rate = 10, light = rgb(255, 210, 110) },
	},
	diamond = {
		hair = rgb(191, 239, 255),
		mix = 0.82,
		material = Enum.Material.Glass,
		reflectance = 0.3,
		transparency = 0.05,
		acc = { color = rgb(191, 239, 255), mix = 0.72, material = Enum.Material.Glass, reflectance = 0.3 },
		-- Bleu glacé saturé (un bleu trop gris rendait la tenue « délavée »)
		ramp = { rgb(16, 58, 128), rgb(70, 178, 255), rgb(214, 246, 255) },
		rampMix = 0.86,
		glint = true,
		fx = { texture = SPARK, colors = { rgb(255, 255, 255), rgb(150, 230, 255) }, size = 0.28, rate = 9, light = rgb(170, 230, 255) },
	},
	sakura = {
		hair = rgb(255, 168, 204),
		mix = 0.6,
		flower = true,
		acc = { color = rgb(255, 176, 208), mix = 0.45 },
		ramp = { rgb(120, 44, 80), rgb(250, 146, 188), rgb(255, 228, 240) },
		rampMix = 0.4,
		motif = "petals",
		fx = { texture = SPARK, colors = { rgb(255, 200, 222), rgb(255, 140, 190) }, size = 0.34, rate = 7, fall = true },
	},
	angelic = {
		hair = rgb(255, 248, 226),
		mix = 0.82,
		halo = true,
		wings = true,
		acc = { color = rgb(255, 246, 225), mix = 0.55 },
		ramp = { rgb(150, 120, 70), rgb(255, 236, 190), rgb(255, 255, 250) },
		rampMix = 0.42,
		fx = { texture = SPARK, colors = { rgb(255, 250, 220), rgb(255, 220, 130) }, size = 0.3, rate = 8, light = rgb(255, 240, 190) },
	},
	shadow = {
		hair = rgb(36, 20, 56),
		mix = 0.7,
		acc = { color = rgb(40, 26, 60), mix = 0.5 },
		desat = 0.35,
		dim = 0.25,
		skin = true,
		outline = rgb(150, 70, 255),
		fx = { texture = SMOKE, colors = { rgb(60, 30, 100), rgb(10, 6, 18) }, size = 0.9, rate = 6, smoke = true },
	},
	galaxy = {
		hair = rgb(46, 34, 120),
		mix = 0.7,
		material = Enum.Material.Neon,
		neonHalf = true,
		acc = { color = rgb(60, 36, 130), mix = 0.6 },
		ramp = { rgb(14, 8, 40), rgb(80, 40, 160), rgb(196, 170, 255) },
		rampMix = 0.55,
		motif = "stars",
		fx = { texture = SPARK, colors = { rgb(255, 255, 255), rgb(190, 150, 255) }, size = 0.22, rate = 10, light = rgb(150, 100, 255) },
	},
	rainbow = {
		-- Seulement les cheveux (chaque mèche d'une couleur) et le contour : la tenue reste intacte
		rainbow = true,
		outline = rgb(255, 150, 230),
		fx = { texture = SPARK, colors = { rgb(255, 90, 90), rgb(255, 230, 80), rgb(90, 200, 255), rgb(210, 110, 255) }, size = 0.3, rate = 10 },
	},
	frost = { hair = rgb(170, 230, 255), mix = 0.45, material = Enum.Material.Ice },
	fire = { hair = rgb(255, 120, 40), mix = 0.4 },
	lightning = { hair = rgb(255, 236, 90), mix = 0.35 },
	void = { hair = rgb(120, 50, 200), mix = 0.45 },
}
CharacterBuilder.Varieties = VARIETIES

local function isHair(part: BasePart): boolean
	local n = part.Name
	return string.sub(n, 1, 4) == "Hair" or n == "Bun" or n == "BunShine" or n == "Knot" or n == "Cranium"
end

local LIMB_NAMES = { Torso = true, ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true }

local function sequence(colors: { Color3 }): ColorSequence
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), c))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, colors[1]))
	end
	return ColorSequence.new(keys)
end

local function numbers(values: { number }): NumberSequence
	local keys = {}
	for i, v in values do
		table.insert(keys, NumberSequenceKeypoint.new((i - 1) / math.max(1, #values - 1), v))
	end
	if #keys == 1 then
		table.insert(keys, NumberSequenceKeypoint.new(1, values[1]))
	end
	return NumberSequence.new(keys)
end

-- Teinte d'une couleur selon la variété : dégradé de teinte choisi par la luminosité (les
-- encres restent sombres, les reflets clairs), mélangé à la couleur d'origine ; ou désaturation.
local function luminance(c: Color3): number
	return 0.3 * c.R + 0.59 * c.G + 0.11 * c.B
end

local function tintColor(c: Color3, spec): Color3
	if spec.ramp then
		local l = luminance(c)
		local ramp = spec.ramp
		local target = l < 0.5 and ramp[1]:Lerp(ramp[2], l / 0.5) or ramp[2]:Lerp(ramp[3], (l - 0.5) / 0.5)
		c = c:Lerp(target, spec.rampMix or 0.5)
	end
	if spec.desat then
		local l = luminance(c)
		c = c:Lerp(Color3.new(l, l, l), spec.desat):Lerp(Color3.new(0.05, 0.03, 0.08), spec.dim or 0)
	end
	return c
end

-- Re-teinte toutes les formes d'une face peinte (+ reflets ou motif sur le torse).
local function tintGui(gui: SurfaceGui, spec, onTorso: boolean)
	for _, f in gui:GetDescendants() do
		if f:IsA("Frame") then
			local gradient = f:FindFirstChildOfClass("UIGradient")
			if gradient then
				-- Dégradé : c'est lui qui porte les couleurs (fond blanc multiplié)
				local keys = {}
				for _, k in gradient.Color.Keypoints do
					table.insert(keys, ColorSequenceKeypoint.new(k.Time, tintColor(k.Value, spec)))
				end
				gradient.Color = ColorSequence.new(keys)
				if f.BackgroundColor3 ~= Color3.new(1, 1, 1) then
					f.BackgroundColor3 = tintColor(f.BackgroundColor3, spec)
				end
			else
				f.BackgroundColor3 = tintColor(f.BackgroundColor3, spec)
			end
		elseif f:IsA("UIStroke") then
			f.Color = tintColor(f.Color, spec)
		end
	end
	local function dot(x: number, y: number, w: number, h: number, color: Color3, transparency: number, rotation: number?, round: boolean?)
		local f = Instance.new("Frame")
		f.Name = "VarietyMotif"
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency
		f.BorderSizePixel = 0
		f.Rotation = rotation or 0
		f.ZIndex = 61
		if round ~= false then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = f
		end
		f.Parent = gui
	end
	if spec.glint and onTorso and gui.Face == Enum.NormalId.Front then
		-- Reflets fins en diagonale (métal poli / cristal), seulement sur le devant du torse :
		-- partout, ils faisaient « vitre » par-dessus la tenue
		dot(0.3, 0.45, 0.035, 1.5, Color3.new(1, 1, 1), 0.6, 32, false)
		dot(0.4, 0.5, 0.016, 1.5, Color3.new(1, 1, 1), 0.6, 32, false)
		dot(0.8, 0.55, 0.022, 1.5, Color3.new(1, 1, 1), 0.65, 32, false)
	end
	if not onTorso then
		return
	end
	if spec.motif == "stars" then
		-- Ciel étoilé : points blancs de tailles variées, deux étoiles en croix
		local stars = { { 0.15, 0.2, 0.05 }, { 0.72, 0.14, 0.035 }, { 0.42, 0.42, 0.03 }, { 0.85, 0.55, 0.045 }, { 0.25, 0.7, 0.035 }, { 0.6, 0.82, 0.05 }, { 0.5, 0.12, 0.025 } }
		for _, st in stars do
			dot(st[1], st[2], st[3], st[3] * 0.9, Color3.new(1, 1, 1), 0.05)
		end
		for _, p in { { 0.32, 0.3 }, { 0.75, 0.68 } } do
			dot(p[1], p[2], 0.11, 0.018, Color3.fromRGB(230, 220, 255), 0.1)
			dot(p[1], p[2], 0.018, 0.11, Color3.fromRGB(230, 220, 255), 0.1)
		end
	elseif spec.motif == "petals" then
		-- Pétales de cerisier qui tombent
		local petals = { { 0.18, 0.18, 30 }, { 0.7, 0.28, -20 }, { 0.4, 0.55, 60 }, { 0.82, 0.72, 15 }, { 0.22, 0.82, -40 } }
		for _, p in petals do
			dot(p[1], p[2], 0.14, 0.08, Color3.fromRGB(255, 196, 220), 0.1, p[3])
			dot(p[1] + 0.02, p[2] - 0.005, 0.06, 0.03, Color3.fromRGB(255, 240, 246), 0.2, p[3])
		end
	end
end

-- Particules propres à la variété (dans le monde, autour du torse).
local function varietyFx(torso: BasePart, fx, s: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "VarietyFx"
	emitter.Texture = fx.texture
	emitter.Color = sequence(fx.colors)
	emitter.LightEmission = fx.smoke and 0 or 1
	emitter.LightInfluence = fx.smoke and 0.5 or 0
	emitter.Size = numbers(fx.smoke and { fx.size * s, fx.size * 2.2 * s } or { fx.size * s, fx.size * 0.6 * s, 0 })
	emitter.Transparency = numbers(fx.smoke and { 0.55, 1 } or { 0.1, 0.3, 1 })
	emitter.Lifetime = NumberRange.new(fx.fall and 1.6 or 0.8, fx.fall and 2.4 or 1.5)
	emitter.Rate = fx.rate
	emitter.Speed = NumberRange.new(0.4 * s, 1.2 * s)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Acceleration = Vector3.new(0, (fx.fall and -1.2 or 0.8) * s, 0)
	-- Depuis la SURFACE du torse (nées dans le volume, elles restaient cachées dedans)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.Parent = torso
	if fx.light then
		local light = Instance.new("PointLight")
		light.Name = "VarietyGlow"
		light.Color = fx.light
		light.Range = 7 * s
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = torso
	end
end

-- Applique une variété à un perso déjà construit (marche aussi sur les modèles perso R6).
-- `variety` : identifiant français ou anglais ("Or", "Diamant", "Sakura", "Angélique"...).
-- Renvoie true si la variété est connue.
function CharacterBuilder.applyVariety(model: Model, variety: string?): boolean
	if not variety or variety == "" then
		return false
	end
	local key = string.lower(variety)
	key = VARIETY_ALIASES[key] or key
	local spec = VARIETIES[key]
	if not spec then
		return false
	end
	if model:GetAttribute("Variety") == key then
		return true
	end
	model:SetAttribute("Variety", key)
	local s = model:GetAttribute("BaseScale") or 1
	local head = model:FindFirstChild("Head") :: BasePart?
	local torso = model:FindFirstChild("Torso") :: BasePart?
	local i = 0
	local guis = {}
	local paints = spec.ramp ~= nil or spec.desat ~= nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and isHair(d) then
			i += 1
			if spec.rainbow then
				d.Color = Color3.fromHSV((i * 0.13) % 1, 0.55, 1)
			elseif spec.hair then
				d.Color = d.Color:Lerp(spec.hair, spec.mix or 0.6)
				if spec.material and (not spec.neonHalf or i % 3 == 0) then
					d.Material = spec.material
				end
				if spec.reflectance then
					d.Reflectance = spec.reflectance
				end
				if spec.transparency then
					d.Transparency = spec.transparency
				end
			end
		elseif d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Name ~= "FacePlate" and d.Transparency < 0.9 and d.Material ~= Enum.Material.Neon then
			local painted = d:FindFirstChildOfClass("SurfaceGui") ~= nil
			if d.Name == "Head" then
				-- Peau : seulement l'Ombre (désaturée)
				if spec.skin then
					d.Color = tintColor(d.Color, spec)
				end
			elseif painted or LIMB_NAMES[d.Name] then
				-- Membres et pièces peintes : même teinte que leur peinture (vue de loin)
				if paints then
					d.Color = tintColor(d.Color, spec)
				end
			elseif spec.acc then
				-- Accessoires en relief : couleur et matière de la variété
				d.Color = d.Color:Lerp(spec.acc.color, spec.acc.mix)
				if spec.acc.material then
					d.Material = spec.acc.material
				end
				if spec.acc.reflectance then
					d.Reflectance = spec.acc.reflectance
				end
			end
		elseif d:IsA("SurfaceGui") and paints and not d:GetAttribute("LodNear") and (d.Name ~= "Face" or spec.skin) then
			table.insert(guis, d)
		end
	end
	for _, gui in guis do
		local onTorso = gui.Parent == torso and (gui.Face == Enum.NormalId.Front or gui.Face == Enum.NormalId.Back)
		tintGui(gui, spec, onTorso)
	end
	if spec.outline then
		-- Liseré coloré (contour seul, sans remplissage : la peinture reste nette)
		local rim = Instance.new("Highlight")
		rim.Name = "VarietyRim"
		rim.FillTransparency = 1
		rim.OutlineColor = spec.outline
		rim.OutlineTransparency = 0.25
		rim.DepthMode = Enum.HighlightDepthMode.Occluded
		rim.Parent = model
	end
	if spec.fx and torso then
		varietyFx(torso, spec.fx, s)
	end
	if model:GetAttribute("Lod") then
		-- Le LOD reprend les couleurs teintées
		Painter.lods(model)
	end
	if not head then
		return true
	end
	local function attach(base: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, props)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size * s
		part.CFrame = base.CFrame * CFrame.new(offset.Position * s) * offset.Rotation
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Anchored = base.Anchored
		part.CastShadow = false
		for k, v in props or {} do
			if k == "sphere" then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = part
			else
				(part :: any)[k] = v
			end
		end
		local weld = Instance.new("Weld")
		weld.Part0 = base
		weld.Part1 = part
		weld.C0 = base.CFrame:Inverse() * part.CFrame
		weld.Parent = part
		part.Parent = model
		return part
	end
	if spec.halo then
		-- Auréole dorée lumineuse au-dessus de la tête
		local halo = attach(head, "VarietyHalo", Vector3.new(0.1, 1.4, 1.4), CFrame.new(0, 1.4, 0.05) * CFrame.Angles(0, 0, math.pi / 2), rgb(255, 226, 120), {
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Cylinder,
		})
		attach(head, "VarietyHaloHole", Vector3.new(0.12, 1.02, 1.02), CFrame.new(0, 1.4, 0.05) * CFrame.Angles(0, 0, math.pi / 2), rgb(255, 250, 230), {
			Shape = Enum.PartType.Cylinder,
			Transparency = 0.6,
		})
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 236, 170)
		light.Range = 8 * s
		light.Brightness = 1
		light.Shadows = false
		light.Parent = halo
	end
	if spec.wings and torso then
		-- Grandes ailes blanches dans le dos : elles dépassent largement des épaules, on les voit
		-- de face. Une arête (os de l'aile) + quatre rémiges en éventail par côté.
		for _, side in { -1, 1 } do
			local shoulder = CFrame.new(side * 0.45, 0.55, 0.62)
			attach(torso, "VarietyWing", Vector3.new(0.34, 2.3, 0.2), shoulder * CFrame.Angles(0, 0, -side * 1.05) * CFrame.new(0, 1.05, 0), rgb(255, 255, 252), {
				sphere = true,
			})
			local boneDir = Vector3.new(side * 0.87, 0.5, 0)
			for k = 0, 3 do
				-- Rémiges : les plus longues au bout de l'aile, pendantes vers le bas et l'extérieur
				local len = 2.3 - k * 0.38
				local pos = shoulder.Position + boneDir * (2.05 - k * 0.5) + Vector3.new(0, 0, 0.05 + k * 0.03)
				local tilt = side * (0.42 - k * 0.12)
				local color = rgb(255, 255, 255):Lerp(rgb(214, 226, 255), k * 0.22)
				attach(torso, "VarietyWing", Vector3.new(0.62, len, 0.12), CFrame.new(pos) * CFrame.Angles(0, 0, tilt) * CFrame.new(0, -len * 0.45, 0), color, {
					sphere = true,
				})
			end
		end
	end
	if spec.flower then
		-- Fleur de cerisier dans les cheveux (5 pétales + cœur)
		local center = CFrame.new(0.45, 0.62, -0.35) * CFrame.Angles(0, -0.6, 0)
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			attach(head, "VarietyPetal", Vector3.new(0.2, 0.2, 0.06), center * CFrame.new(math.cos(a) * 0.12, math.sin(a) * 0.12, 0), rgb(255, 186, 214), {
				sphere = true,
			})
		end
		attach(head, "VarietyFlowerCore", Vector3.new(0.1, 0.1, 0.1), center * CFrame.new(0, 0, -0.03), rgb(255, 230, 120), { sphere = true })
	end
	return true
end

-- Modèle ancré pour les aperçus des menus (visage et tenue en pièces : visibles en ViewportFrame).
function CharacterBuilder.buildPreview(look): Model
	local model = CharacterBuilder.build(look, { scale = 1, name = "Preview", paint = "parts" })
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	return model
end

return CharacterBuilder
