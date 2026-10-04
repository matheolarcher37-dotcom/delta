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
local HEAD_W, HEAD_D = 2 * HEAD_R, 2 * HEAD_R
local TOP = HEAD_H / 2
local FRONT = -HEAD_R
local BACK = HEAD_R
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

	-- Pique de cheveux épaisse partant de `from` dans la direction `dir` : une lame large tournée
	-- vers l'extérieur (bien lisible de face) + une lame plus étroite en travers (volume de profil).
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
		local thick = opts.thickness or math.clamp(width * 0.34, 0.08, 0.22)
		ctx.blade(limbName, color, face, length, width, thick)
		if opts.cross ~= false then
			ctx.blade(limbName, opts.crossColor or color, face * CFrame.Angles(0, math.pi / 2, 0), length * 0.9, width * 0.55, thick)
		end
		if opts.tip then
			local tipFrame = face * CFrame.new(0, length * 0.62, 0)
			ctx.blade(limbName, opts.tip, tipFrame, length * 0.38, width * 0.38, thick + 0.01)
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

	-- Mèche plate tournée vers l'avant (frange, mèches qui encadrent le visage).
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
		ctx.blade(limbName, color, frame, length, width, opts.thickness or 0.14, "HairLock")
		if opts.tip then
			ctx.blade(limbName, opts.tip, frame * CFrame.new(0, length * 0.6, -0.01), length * 0.4, width * 0.42, (opts.thickness or 0.14) + 0.01, "HairLock")
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
		gui.MaxDistance = 140
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
	elseif lum > 0.82 then
		-- Cheveux blancs / argentés : ombres bleu-gris
		under = c:Lerp(Color3.fromRGB(150, 160, 195), 0.45)
		shine = WHITE
	else
		under = c:Lerp(Color3.fromRGB(120, 60, 30), 0.32)
		shine = c:Lerp(WHITE, 0.28)
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
		ctx.ball(
			"Head",
			"HairNape",
			Vector3.new(1.24 + grow, length, 0.9 + grow * 0.5),
			CFrame.new(0, 0.42 - length / 2 + (opts.napeLift or 0), 0.19),
			opts.color2 or color
		)
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
	-- Tignasse en pointes compactes (Maruto, comme "Kid Naruto") : calotte + couronne de pointes
	-- qui rayonnent en étoile au-dessus du bandeau, pointes sur les côtés et dans la nuque.
	local under, shine = hairTones(c, look)
	local tip = look.hairTip
	local band = wearsHeadband(look)
	local L = look.hairLength or 1
	cap(ctx, c, { color2 = under, backLength = 0.95, lift = band and 0.07 or 0.02, height = 0.9 })
	local center = Vector3.new(0, band and 0.74 or 0.68, 0.06)
	-- Mèches couchées en écailles juste au-dessus du bandeau (cachent la calotte)
	scales(ctx, c, shine, under, band and 0.6 or 0.5, 0.46 * L, { tip = tip })
	crown(ctx, c, center, {
		-- rang du milieu (silhouette de face, en étoile)
		{ 0, 5, 0.66, 0.62, nil, true },
		{ -30, 0, 0.66, 0.6, nil, true },
		{ 30, 0, 0.66, 0.6, shine, true },
		{ -58, 0, 0.7, 0.6, nil, true },
		{ 58, 0, 0.7, 0.6, nil, true },
		{ -86, 5, 0.66, 0.56, under, true },
		{ 86, 5, 0.66, 0.56, under, true },
		-- rang de devant (penché vers l'avant)
		{ -45, -35, 0.5, 0.56, shine },
		{ -12, -38, 0.5, 0.56 },
		{ 18, -35, 0.5, 0.56, shine },
		{ 50, -32, 0.5, 0.54 },
		-- rang de derrière
		{ -65, 40, 0.58, 0.58, under },
		{ -25, 45, 0.6, 0.6, under },
		{ 20, 45, 0.6, 0.6, under },
		{ 62, 40, 0.58, 0.58, under },
		{ 0, 75, 0.55, 0.58, under, nil, 0.36 },
	}, { tip = tip, scale = L })
	-- Pointes qui dépassent sur les côtés, sous le haut du bandeau, et dans la nuque
	for _, side in { -1, 1 } do
		ctx.spike("Head", c, Vector3.new(side * 0.5, 0.5, 0.0), Vector3.new(side, -0.2, 0.05), 0.55 * L, 0.44, { tip = tip, cross = false })
		ctx.spike("Head", under, Vector3.new(side * 0.36, 0.3, 0.4), Vector3.new(side * 0.6, -0.6, 0.7), 0.4 * L, 0.42, { tip = tip, cross = false })
	end
	ctx.spike("Head", under, Vector3.new(0, 0.2, 0.5), Vector3.new(0, -0.7, 1), 0.42 * L, 0.46, { tip = tip, cross = false })
	if not band then
		-- Sans bandeau : frange en pointes sur le front
		fringe(ctx, c, { -0.38, -0.13, 0.13, 0.38 }, { 0.42, 0.5, 0.46, 0.4 }, 0.34, { alt = shine, y = 0.56, spread = 0.7, tip = tip })
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
	cap(ctx, c, { color2 = under, backLength = 1.35 })
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
end

HAIR.tall_spiky = function(ctx, c, look)
	HAIR.wild(ctx, c, look)
	-- Très longue crinière jusqu'aux jambes.
	for _, x in { -0.3, 0, 0.3 } do
		ctx.spike("Head", c, Vector3.new(x, 0.3, 0.5), Vector3.new(x * 0.3, -1, 0.25), 3.0, 1.0, { tip = look.hairTip })
	end
	ctx.strand("Head", c, Vector3.new(0, 0.4, 0.55), Vector3.new(0, -1, 0.35), 2.4, 1.0)
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
	-- Longs cheveux lisses : frange écartée sur le front, longues mèches de côté, nappe dans le dos.
	local under, shine = hairTones(c, look)
	local tip = look.hairTip
	cap(ctx, c, { back = false, height = 0.84 })
	local length = look.hairLength or 2.4
	ctx.ball("Head", "HairBack", Vector3.new(1.34, length, 0.6), CFrame.new(0, TOP - 0.1 - length / 2 + 0.25, 0.4), under)
	ctx.ball("Head", "HairBack", Vector3.new(1.28, length * 0.94, 0.5), CFrame.new(0, TOP - 0.1 - length / 2 + 0.2, 0.5), c)
	if tip then
		ctx.ball("Head", "HairTip", Vector3.new(1.18, 0.8, 0.52), CFrame.new(0, TOP - length + 0.1, 0.5), tip)
	end
	for _, side in { -1, 1 } do
		ctx.ball("Head", "HairSide", Vector3.new(0.28, 1.5, 0.95), CFrame.new(side * 0.6, 0.0, 0.1), under)
		-- Mèche longue qui encadre le visage (deux tons)
		ctx.strand("Head", c, Vector3.new(side * 0.62, 0.45, -0.28), Vector3.new(side * 0.14, -1, -0.06), 1.25, 0.24, 0.2)
		ctx.strand("Head", shine, Vector3.new(side * 0.6, 0.45, -0.36), Vector3.new(side * 0.12, -1, -0.08), 0.7, 0.12, 0.1)
	end
	if look.forehead then
		-- Front dégagé, raie au milieu : deux mèches courbées
		fringe(ctx, c, { -0.28, 0.28 }, { 0.34, 0.34 }, 0.42, { y = 0.58, spread = 1.1, out = 0.1, thickness = 0.16 })
	else
		fringe(ctx, c, { -0.36, -0.13, 0.1, 0.34 }, { 0.36, 0.42, 0.4, 0.34 }, 0.36, { alt = shine, y = 0.58, spread = 0.5, thickness = 0.16 })
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
	local under, _ = hairTones(c, look)
	-- Côtés rasés (ombre), crête de pointes au milieu
	cap(ctx, under, { height = 0.7, backLength = 1.1, grow = -0.02 })
	for i = 0, 4 do
		local z = -0.45 + i * 0.24
		ctx.spike("Head", c, Vector3.new(0, 0.82, z), Vector3.new(0, 1, (i - 1.5) * 0.35), 0.62 + (i == 1 and 0.15 or 0), 0.42, { tip = look.hairTip, cross = false, thickness = 0.22 })
	end
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
	-- Flamme dressée (prince guerrier) : front dégagé en pointe ("V"), grande flamme en éventail.
	local under, shine = hairTones(c, look)
	local tip = look.hairTip
	cap(ctx, c, { color2 = under, backLength = 1.1, height = 0.84 })
	scales(ctx, c, shine, under, 0.5, 0.5, { lift = 2.2, tip = tip })
	crown(ctx, c, Vector3.new(0, 0.75, 0.12), {
		{ 0, 12, 1.15, 0.66, nil, true },
		{ -20, 8, 1.0, 0.62, shine, true },
		{ 20, 8, 1.0, 0.62, nil, true },
		{ -40, 12, 0.85, 0.6 },
		{ 40, 12, 0.85, 0.6, shine },
		{ -58, 18, 0.65, 0.56, under },
		{ 58, 18, 0.65, 0.56, under },
		{ -10, 40, 0.95, 0.62, under },
		{ 12, 40, 0.95, 0.62, under },
		{ 0, -20, 0.8, 0.6, shine },
	}, { tip = tip, r = 0.22 })
	-- Pointe de cheveux au milieu du front (racine en "V")
	ctx.lock("Head", c, Vector3.new(0, 0.62, -0.62), Vector3.new(0, -1, -0.15), 0.32, 0.38)
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

HAIR.topknot = function(ctx, c, look)
	local under, _ = hairTones(c, look)
	cap(ctx, c, { color2 = under, backLength = 1.15, height = 0.74 })
	ctx.ball("Head", "Knot", Vector3.new(0.44, 0.4, 0.44), CFrame.new(0, 0.95, 0.2), c)
	ctx.strand("Head", c, Vector3.new(0, 1.05, 0.25), Vector3.new(0, 1, 0.5), 0.5, 0.26)
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
	-- Carré court (sorcière au marteau, androïde) : volume arrondi qui descend au menton.
	local under, shine = hairTones(c, look)
	cap(ctx, c, { back = false, height = 0.84 })
	ctx.ball("Head", "HairBob", Vector3.new(1.46, 1.4, 1.36), CFrame.new(0, 0.05, 0.1), under)
	for _, side in { -1, 1 } do
		ctx.ball("Head", "HairBobSide", Vector3.new(0.28, 1.15, 0.95), CFrame.new(side * 0.62, -0.05, -0.05), c)
	end
	fringe(ctx, c, { -0.32, -0.1, 0.12, 0.34 }, 0.4, 0.32, { alt = shine, y = 0.56, spread = 0.3 })
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
local function leafSymbol(canvas, ink: Color3, scratched: boolean)
	-- Spirale (anneau + petit tourbillon), pointe de feuille en haut à droite, queue en bas à gauche
	Painter.rect(canvas, 0.5, 0.55, 0.42, 0.58, ink, { corner = 0.5, transparency = 1, stroke = ink, strokeThickness = 2, z = 2 })
	Painter.rect(canvas, 0.54, 0.6, 0.12, 0.18, ink, { corner = 0.5, z = 2 })
	Painter.rect(canvas, 0.48, 0.47, 0.16, 0.06, ink, { corner = 0.5, rotation = -30, z = 2 })
	Painter.rect(canvas, 0.7, 0.28, 0.3, 0.09, ink, { corner = 0.3, rotation = -42, z = 2 })
	Painter.rect(canvas, 0.3, 0.84, 0.16, 0.08, ink, { corner = 0.5, rotation = 25, z = 2 })
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
	ctx.vcyl("Head", "Headband", 0.36, 2 * BAND_R, frame, band)
	local metal = look.plateColor or METAL
	local ink = Color3.fromRGB(70, 82, 100)
	for i = -1, 1 do
		local a = i * math.rad(24)
		local r = BAND_R + 0.02
		local cf = frame * CFrame.new(-math.sin(a) * r, 0, -math.cos(a) * r) * CFrame.Angles(0, a, 0)
		local plate = ctx.add("Head", "Plate", Vector3.new(0.3, 0.3, 0.05), cf, metal, { Material = Enum.Material.Metal, Reflectance = 0.15 })
		paintPanel(ctx, plate, Enum.NormalId.Front, function(canvas)
			-- Rebord et rivets
			Painter.rect(canvas, 0.5, 0.06, 1, 0.08, lighten(metal, 0.4), { z = 1 })
			Painter.rect(canvas, 0.5, 0.95, 1, 0.08, darken(metal, 0.3), { z = 1 })
			if i ~= 0 then
				local x = i < 0 and 0.2 or 0.8
				Painter.rect(canvas, x, 0.22, 0.09, 0.09, ink, { corner = 0.5, z = 2 })
				Painter.rect(canvas, x, 0.78, 0.09, 0.09, ink, { corner = 0.5, z = 2 })
			else
				leafSymbol(canvas, ink, scratched)
			end
		end)
	end
	ctx.ball("Head", "Knot", Vector3.new(0.24, 0.22, 0.18), frame * CFrame.new(0, 0, BAND_R + 0.06), band)
	ctx.strand("Head", band, (frame * CFrame.new(-0.06, -0.03, BAND_R + 0.08)).Position, Vector3.new(-0.3, -1, 0.5), 0.7, 0.14)
	ctx.strand("Head", band, (frame * CFrame.new(0.06, -0.03, BAND_R + 0.08)).Position, Vector3.new(0.35, -1, 0.4), 0.62, 0.14)
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
	-- Casquette de marine
	local color = look.accColor or WHITE
	ctx.ball("Head", "CapDome", Vector3.new(1.42, 0.86, 1.44), CFrame.new(0, 0.58, 0.02), color)
	ctx.vcyl("Head", "Cap", 0.3, 1.42, CFrame.new(0, 0.42, 0.02), color)
	ctx.vcyl("Head", "CapBand", 0.1, 1.44, CFrame.new(0, 0.31, 0.02), look.capBand or Color3.fromRGB(40, 60, 140))
	ctx.add("Head", "Brim", Vector3.new(1.0, 0.07, 0.5), CFrame.new(0, 0.3, -0.86) * CFrame.Angles(math.rad(-8), 0, 0), look.capBrim or Color3.fromRGB(30, 30, 40))
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
	local rock = look.accColor or Color3.fromRGB(80, 60, 50)
	ctx.vcyl("Head", "Volcano1", 0.45, 1.25, CFrame.new(0, 0.7, 0), rock)
	ctx.vcyl("Head", "Volcano2", 0.4, 0.9, CFrame.new(0, 1.1, 0), rock)
	ctx.vcyl("Head", "Lava", 0.08, 0.62, CFrame.new(0, 1.32, 0), Color3.fromRGB(255, 120, 20), { Material = Enum.Material.Neon })
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
	ctx.add("Head", "ScouterLens", Vector3.new(0.34, 0.28, 0.04), CFrame.new(-0.24, 0.05, -WRAP_R - 0.05), Color3.fromRGB(80, 255, 120), { Material = Enum.Material.Neon, Transparency = 0.35 })
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
	-- Capuche rabattue dans le dos (sweat à capuche)
	local color = look.accColor or Color3.fromRGB(200, 30, 40)
	ctx.ball("Torso", "Hood", Vector3.new(1.5, 0.85, 0.65), CFrame.new(0, 0.95, 0.6), color)
	ctx.add("Torso", "HoodCollar", Vector3.new(2.04, 0.26, 1.06), CFrame.new(0, 0.88, 0), color)
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

ACC.marine_coat = function(ctx, look)
	local white = WHITE
	ctx.add("Torso", "Coat", Vector3.new(2.4, 3.4, 0.12), CFrame.new(0, -0.55, 0.62) * CFrame.Angles(0.08, 0, 0), white)
	for _, side in { -1, 1 } do
		ctx.add("Torso", "CoatShoulder", Vector3.new(1.3, 0.3, 1.3), CFrame.new(side * 1.5, 1.05, 0.05), white)
		ctx.add("Torso", "CoatSleeve", Vector3.new(0.12, 2.6, 1.1), CFrame.new(side * 2.1, -0.4, 0.15), white)
	end
	local _ = look
end

ACC.cloak_skirt = function(ctx, look)
	local color = look.skirtColor or look.top or Color3.fromRGB(40, 40, 50)
	ctx.add("Torso", "Skirt", Vector3.new(2.1, 1.6, 1.1), CFrame.new(0, -1.7, 0), color)
	ctx.add("Torso", "SkirtHem", Vector3.new(2.12, 0.12, 1.12), CFrame.new(0, -2.45, 0), darken(color, 0.3))
end

ACC.collar_high = function(ctx, look)
	-- Col montant qui cache le bas du visage (manteau à nuages, uniforme à col haut)
	local color = look.collarColor or look.topAccent or look.top or Color3.fromRGB(30, 30, 40)
	ctx.vcyl("Torso", "HighCollar", 0.56, 1.5, CFrame.new(0, 1.0, 0), color)
	ctx.vcyl("Torso", "HighCollarLining", 0.03, 1.36, CFrame.new(0, 1.28, 0), look.collarLining or Painter.shade(color, 0.4))
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
		local cell = 0.4 -- taille d'une case (studs)
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

local function sword(ctx, limb: string, cf: CFrame, handle: Color3, sheath: Color3?, length: number?)
	local l = length or 2.8
	ctx.add(limb, "Sheath", Vector3.new(0.2, l, 0.2), cf, sheath or Color3.fromRGB(30, 30, 35))
	ctx.cyl(limb, "Guard", 0.08, 0.45, cf * CFrame.new(0, l / 2 + 0.04, 0) * CFrame.Angles(0, 0, math.pi / 2), GOLD, { Material = Enum.Material.Metal })
	ctx.add(limb, "Handle", Vector3.new(0.18, 0.8, 0.18), cf * CFrame.new(0, l / 2 + 0.48, 0), handle)
end

ACC.sword_hip = function(ctx, look)
	sword(ctx, "Torso", CFrame.new(-1.12, -0.75, 0.05) * CFrame.Angles(math.rad(-70), 0, 0), look.accColor or WHITE)
end

ACC.swords = function(ctx, look)
	local handle = look.accColor or WHITE
	sword(ctx, "Torso", CFrame.new(-1.12, -0.75, -0.1) * CFrame.Angles(math.rad(-70), 0, 0), handle)
	sword(ctx, "Torso", CFrame.new(-1.15, -0.8, 0.2) * CFrame.Angles(math.rad(-65), 0, 0), Color3.fromRGB(200, 40, 40))
	sword(ctx, "Torso", CFrame.new(1.12, -0.75, 0.05) * CFrame.Angles(math.rad(-70), 0, 0), Color3.fromRGB(30, 30, 30))
end

ACC.sword_back = function(ctx, look)
	sword(ctx, "Torso", CFrame.new(0, 0, 0.62) * CFrame.Angles(0, 0, 0.75), look.accColor or Color3.fromRGB(80, 60, 130), nil, 3.2)
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

local HATS = { "boar_head", "hood_full", "straw_hat", "volcano", "dome", "turban", "cap", "bandana" }

function CharacterBuilder.build(look, options: BuildOptions?): Model
	local opts = options or {}
	local s = opts.scale or 1
	local model = Instance.new("Model")
	model.Name = opts.name or "Character"

	local ctx = newContext(model, s, opts.paint or "gui")
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
	elseif (has(look, "straw_hat") or has(look, "cap") or has(look, "bandana")) and look.hair ~= "none" and look.hair ~= "bald" then
		-- Cheveux visibles sous le chapeau : nuque, mèches sur les côtés et frange en bataille.
		local under, shine = hairTones(hairColor, look)
		cap(ctx, under, { height = 0.7, lift = -0.06, backLength = 1.3 })
		fringe(ctx, hairColor, { -0.36, -0.12, 0.12, 0.36 }, { 0.3, 0.36, 0.3, 0.32 }, 0.32, { alt = shine, y = 0.36, spread = 0.45, out = 0.06 })
		for _, side in { -1, 1 } do
			ctx.lock("Head", hairColor, Vector3.new(side * 0.6, 0.3, -0.1), Vector3.new(side * 0.15, -1, 0), 0.4, 0.36, { facing = Vector3.new(side, 0, 0.2), thickness = 0.12 })
			ctx.spike("Head", under, Vector3.new(side * 0.3, 0.05, 0.55), Vector3.new(side * 0.3, -0.8, 0.8), 0.36, 0.42, { cross = false })
		end
	end

	for _, accessory in look.accessories or {} do
		local builder = ACC[accessory]
		if builder then
			builder(ctx, look)
		end
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
