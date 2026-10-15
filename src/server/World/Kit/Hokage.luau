-- Kit/Hokage : la MONTAGNE DES CHEFS du village ninja (inspirée du mont des Hokages).
--
-- Un grand relief rocheux taillé, comme le monument de référence : 8 TÊTES sculptées en quinconce
-- sur deux rangs, qui remplissent presque tout le relief et se touchent :
--
--        rang du haut :   Hashirama     Hiruzen        Tsunade       Naruto
--        rang du bas  :          Tobirama      Minato         Kakashi        Boruto
--                         (médaillon de la feuille gravé, en bas à gauche)
--
-- Le relief : un DÔME comme le monument (bosse au centre, épaules qui descendent en quart de
-- cercle jusqu'au sol, pied évasé et éboulis). La roche est un amas de PIERRES ÉMOUSSÉES
-- (noyau et quatre biseaux, basculées de 4 à 12°) et de rochers taillés en facettes, sans
-- rangées ni arêtes droites ; une crête de rochers de plus en plus petits dessine le contour.
-- Derrière, une COUCHE DE RECUL sombre (ardoise 70,72,78) : joints et niches autour des têtes,
-- qui détachent les visages de loin. Un médaillon de pierre porte la spirale de la feuille.
--
-- Les VISAGES sont des surfaces taillées en facettes (maillage de 110 triangles, deux coins par
-- triangle, Hokage.triangle), chacun avec son caractère : yeux OUVERTS en amande (globe dans
-- une orbite sombre, paupière en coin, iris et pupille gravés), sourcils froncés ou doux,
-- longueur du visage et largeur des pommettes propres, bouche droite, sévère ou souriante,
-- rides et long bouc (Hiruzen), trois moustaches par joue (Naruto). Cheveux : épis épais en
-- trois couches décalées et courbées, aux longueurs irrégulières, sur une calotte facettée ;
-- cheveux longs en rideaux facettés ; bandeaux qui épousent le front.
--
-- Tout est dans la même famille gris ardoise (têtes 6 % plus claires que les rochers). Le modèle
-- est un emplacement remplaçable (DecorSlot "MontagneDesChefs") : un modèle du même nom rangé
-- dans ServerStorage > ModelesDeco le remplace.
--
-- Budget : ≈ 4 700 pièces, dont ≈ 3 070 pour les 8 têtes ; arbres du sommet en version
-- lointaine (clones). Seules la paroi, le sommet et le pied gardent une collision. Le modèle est
-- en LevelOfDetail « StreamingMesh » (simplifié de loin par le moteur).

local Build = require(script.Parent.Parent.Parent.Modules.Build)
local Core = require(script.Parent.Core)
local Nature = require(script.Parent.Nature)

local Hokage = {}

local rgb = Color3.fromRGB
local V3 = Vector3.new
local shade = Core.shade

-- Palette : une seule famille gris ardoise pour la falaise et les têtes. Les têtes sont un peu
-- plus claires (+6 %) que le cadre de rochers ; les creux (paroi du fond, niches derrière les
-- têtes) sont nettement plus sombres : ce sont eux qui détachent les visages, vus de loin.
local ROCK = rgb(120, 122, 128)
local FACE = rgb(134, 136, 142)
local HAIR = rgb(126, 128, 135)
local JOINT = rgb(70, 72, 78) -- couche de recul : paroi du fond, joints, niches
local DEEP = rgb(56, 58, 64) -- traits gravés : bouche, iris, moustaches, symbole
local TONES = {
	rgb(120, 122, 128),
	rgb(113, 115, 121),
	rgb(127, 129, 134),
	rgb(116, 117, 122),
	rgb(124, 125, 131),
	rgb(110, 112, 118),
	rgb(128, 128, 133),
}
local GRASS = rgb(84, 132, 62)
local GRASS_LIGHT = rgb(102, 148, 74)
local MOSS = rgb(88, 120, 62)

local ROCK_MAT = Enum.Material.Rock
local CARVE_MAT = Enum.Material.Slate

-- Dimensions du relief (studs). `cf` = pied du relief au centre, -Z local vers le village.
Hokage.Width = 560
Hokage.Height = 256 -- sommet du dôme (au centre) ; les côtés descendent à ≈ 200
Hokage.Depth = 150
Hokage.BaseHeight = 14 -- pied de pierres émoussées (≤ 10 % de la hauteur)
Hokage.Shoulder = 64 -- épaules arrondies au-delà de la largeur (pied évasé)
Hokage.Reach = Hokage.Width / 2 + Hokage.Shoulder

-- Unité de sculpture : une tête mesure ≈ 10 unités du menton au sommet du crâne (≈ 100 studs),
-- soit ≈ 45 % de la hauteur du relief par rang, comme sur le monument.
local U = 10
Hokage.Unit = U

-- Les 8 chefs : position (x, y = hauteur des yeux) sur le relief, coiffure, échelle.
-- (x local positif = à gauche vu depuis le village : Hashirama est à gauche, Naruto à droite.)
Hokage.Heads = {
	{ name = "Hashirama", x = 172, y = 162, style = "longs" },
	{ name = "Hiruzen", x = 58, y = 178, style = "epis" },
	{ name = "Tsunade", x = -58, y = 172, style = "raie" },
	{ name = "Naruto", x = -172, y = 158, style = "bandeau" },
	{ name = "Tobirama", x = 115, y = 90, style = "plaque" },
	{ name = "Minato", x = 0, y = 88, style = "meches" },
	{ name = "Kakashi", x = -115, y = 90, style = "penche" },
	{ name = "Boruto", x = -224, y = 82, style = "jeune", scale = 0.9 },
}
Hokage.Emblem = { x = 226, y = 80 }

-- Encombrement de chaque coiffure (en unités, autour des yeux) : demi-largeur, haut, bas.
local EXTENT = {
	longs = { 4.4, 6.0, -6.4 },
	epis = { 4.8, 8.6, -6.6 },
	raie = { 4.4, 6.0, -6.4 },
	bandeau = { 4.8, 7.4, -5.8 },
	plaque = { 4.6, 6.4, -5.8 },
	meches = { 4.9, 7.6, -5.8 },
	penche = { 4.7, 8.6, -5.8 },
	jeune = { 4.7, 7.2, -5.8 },
}

-- Avancée de la paroi : les couches du haut reculent (relief légèrement incliné).
local function lean(y: number): number
	return (y / Hokage.Height) * 10
end
Hokage.lean = lean

------------------------------------------------------------------------
-- Outils de sculpture (repère d'une tête : origine entre les yeux, -Z = vers l'avant,
-- +X = un côté du visage, en unités de sculpture)
------------------------------------------------------------------------

type Ctx = { model: Model, cf: CFrame, u: number, count: number }

local function at(ctx: Ctx, x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	local u = ctx.u
	return ctx.cf * CFrame.new(x * u, y * u, z * u) * CFrame.Angles(rx or 0, ry or 0, rz or 0)
end

-- Volume arrondi CACHÉ (crâne, calotte sous les mèches) : jamais sur une surface visible du visage.
local function E(ctx: Ctx, name: string, sx: number, sy: number, sz: number, cf: CFrame, color: Color3?): Part
	ctx.count += 1
	local part = Core.ellipsoid(ctx.model, name, V3(sx, sy, sz) * ctx.u, cf, color or FACE, CARVE_MAT)
	part.CanCollide = false
	part.CanQuery = false
	return part
end

-- Pan taillé (bloc) en unités de sculpture : les visages sont faits de plans nets, comme une
-- sculpture dégrossie au ciseau ; ce sont les ombres entre les plans qui dessinent les traits.
local function B(ctx: Ctx, name: string, sx: number, sy: number, sz: number, cf: CFrame, color: Color3?): Part
	ctx.count += 1
	local part = Build.deco(ctx.model, name, V3(sx, sy, sz) * ctx.u, cf, color or FACE, { Material = CARVE_MAT })
	part.CastShadow = math.min(sx, sy, sz) * ctx.u > 1.2
	return part
end

-- MÈCHE plate et effilée : deux coins dos à dos forment un triangle isocèle (base large de `w`
-- enfoncée à la racine `root`, pointe fine au bout), épais de `t`. Les deux moitiés reculent un peu
-- de part et d'autre de l'arête centrale (`crest`, en radians) : la lumière dessine la mèche.
-- `out` = direction du côté visible de la mèche (vers le village pour les épis vus de face,
-- vers l'extérieur du crâne pour une mèche plaquée).
local function lock(ctx: Ctx, root: Vector3, dir: Vector3, len: number, w: number, t: number, out: Vector3?, crest: number?)
	local a = dir.Unit
	local o = out or V3(0, 0, -1)
	local n = o - a * a:Dot(o)
	if n.Magnitude < 1e-3 then
		n = V3(0, 1, 0) - a * a.Y
	end
	n = n.Unit
	local side = a:Cross(n)
	local c, s = math.cos(crest or 0.3), math.sin(crest or 0.3)
	local u = ctx.u
	for _, k in { 1, -1 } do
		local sd = side * (k * c) - n * s
		local x = sd:Cross(a)
		local center = root + a * (len / 2) + sd * (w / 4)
		ctx.count += 1
		Build.wedge(ctx.model, "Meche", V3(t, len, w / 2) * u, ctx.cf * CFrame.fromMatrix(center * u, x, a, -sd), HAIR, {
			Material = CARVE_MAT,
			CanCollide = false,
			CanQuery = false,
		})
	end
end

-- Frange qui retombe PAR-DESSUS le bandeau : mèches accrochées au bord haut de la bande.
local function bandBangs(ctx: Ctx, n: number, spread: number, bandY: number, low: number, shift: number?)
	for k = 0, n - 1 do
		local f = n > 1 and k / (n - 1) * 2 - 1 or 0
		local x = f * spread
		local root = V3(x * 0.9, bandY + 0.75 - math.abs(f) * 0.15, -3.86 + math.abs(f) * 0.25)
		local tip = V3(x * 1.05 + (shift or 0), low + math.abs(f) * 0.7, -3.98 + math.abs(f) * 0.3)
		local d = tip - root
		lock(ctx, root, d, d.Magnitude, 1.7, 0.4, V3(0, 0.25, -1), 0.3)
	end
end

-- Calotte des cheveux : une masse lisse un peu plus grande que le crâne. Les mèches sont
-- enracinées DANS sa surface et la suivent : on lit une chevelure sculptée dans la masse, pas
-- une auréole de pointes.
local CAP_C = V3(0, 3.3, 1.0)
local CAP_R = V3(3.55, 2.6, 4.05)

-- Point de la calotte dans la direction (a = angle vu de face, 0 = en haut ; p = avancée vers le
-- visage, 0 = sur la silhouette) et normale à la surface en ce point.
local function capPoint(a: number, p: number, inset: number?): (Vector3, Vector3)
	local d = V3(math.sin(a) * math.cos(p), math.cos(a) * math.cos(p), -math.sin(p))
	local pos = CAP_C + d * CAP_R * (inset or 0.93)
	return pos, V3(d.X / CAP_R.X, d.Y / CAP_R.Y, d.Z / CAP_R.Z).Unit
end

-- Rang d'épis : `n` mèches de l'angle `a0` à `a1` (0 = vers le haut), racines dans la calotte à
-- l'avancée `p`, pointes vers l'extérieur et vers l'arrière (`back`), à moitié plaquées sur la
-- surface (`face` = 0 : couchées sur la calotte ; 1 : tournées vers le village).
-- `lean` penche toute la coiffure d'un côté ; `fall` raccourcit les mèches des côtés.
type CrownSpec = {
	n: number,
	a0: number,
	a1: number,
	p: number?,
	len: number,
	w: number,
	t: number?,
	back: number?,
	lean: number?,
	fall: number?,
	wave: number?,
	face: number?,
	inset: number?, -- 1 : racine posée sur la surface (mèche couchée) ; < 1 : enfoncée
	tilt: number?, -- < 1 : les épis des côtés se redressent vers le haut
	bend: number?, -- courbure latérale progressive : les épis des côtés se couchent de plus en plus
	jit: number?, -- irrégularité (angles, longueurs ±30 %, largeurs, racines)
	salt: number?, -- graine de l'irrégularité (une par couche)
}

-- Petit hachage déterministe dans [-1, 1] : une même tête est toujours sculptée pareil.
local function jitter(k: number, salt: number): number
	return ((math.sin(k * 12.9898 + salt * 78.233) * 43758.5453) % 1) * 2 - 1
end

local function crown(ctx: Ctx, o: CrownSpec)
	local step = o.n > 1 and (o.a1 - o.a0) / (o.n - 1) or 0
	local jit = o.jit or 0
	local salt = o.salt or 1
	for k = 0, o.n - 1 do
		local f = o.n > 1 and k / (o.n - 1) or 0.5
		local j1, j2, j3 = jitter(k, salt), jitter(k, salt + 0.37), jitter(k, salt + 0.71)
		local a = o.a0 + (o.a1 - o.a0) * f + j1 * step * 0.4 * jit
		local root, normal = capPoint(a, (o.p or 0.45) + j3 * 0.1 * jit, o.inset)
		local da = a * (o.tilt or 1) + (o.lean or 0) + (o.bend or 0) * a * math.abs(a)
		local len = o.len - math.abs(math.sin(a)) * (o.fall or 0) + (o.wave and math.sin(k * 2.3 + 0.7) * o.wave or 0)
		len *= 1 + j2 * 0.3 * jit
		local out = normal + V3(0, 0, -(o.face or 0.8))
		lock(ctx, root, V3(math.sin(da), math.cos(da), (o.back or 0.35) + j3 * 0.15 * jit), len, o.w * (1 + j3 * 0.15 * jit), o.t or 0.42, out, 0.42)
	end
end

-- Frange : `n` mèches plates qui partent de la lisière et retombent sur le front, réparties de
-- -spread à +spread ; `low` = hauteur des pointes, `shift` les penche toutes d'un côté.
local function bangs(ctx: Ctx, n: number, spread: number, low: number, w: number, shift: number?, tipZ: number?)
	for k = 0, n - 1 do
		local f = n > 1 and k / (n - 1) * 2 - 1 or 0
		local x = f * spread
		local root = V3(x * 0.75, 3.85 - math.abs(f) * 0.4, -3.0 + math.abs(f) * 0.5)
		local tip = V3(x * 1.1 + (shift or 0), low + math.abs(f) * 0.8, (tipZ or -3.6) + math.abs(f) * 0.45)
		local d = tip - root
		lock(ctx, root, d, d.Magnitude, w, 0.36, V3(x * 0.15, 0.45, -1), 0.35)
	end
end

-- Hauteur de la face avant du front (z) à la hauteur `y` : le front recule en montant.
local FRONT_Z, FRONT_Y, FRONT_TILT = -3.25, 2.05, 0.14
local function foreheadZ(y: number): number
	return FRONT_Z + (y - FRONT_Y) * math.sin(FRONT_TILT)
end

-- Bandeau frontal : bande plate qui fait le tour du front (trois pans) et plaque de métal plate
-- (0,6 stud d'épaisseur) collée dessus, gravée de la spirale de la feuille. `roll` incline le
-- bandeau (Kakashi), `h` = hauteur de la bande, `z` force la profondeur (bandeau sur un œil).
local function headband(ctx: Ctx, y: number, roll: number?, h: number?, zForce: number?)
	local u = ctx.u
	local bh = h or 1.0
	local zc = zForce or (foreheadZ(y) - 0.27)
	local band = at(ctx, 0, y, 0, 0, 0, roll or 0)
	local pitch = zForce and 0 or FRONT_TILT
	-- la bande ÉPOUSE le front (cinq pans qui tournent autour du crâne), mince et plaquée : elle
	-- ne déborde pas comme un bord de chapeau
	local panels = {
		{ 0, 0, 0, 2.5 }, -- x, avancée en arrière, angle, largeur
		{ 1.85, 0.47, 0.58, 1.6 },
		{ 2.88, 1.62, 1.12, 1.7 },
	}
	for _, pn in panels do
		for _, s in (pn[1] == 0 and { 1 } or { -1, 1 }) do
			ctx.count += 1
			Build.deco(
				ctx.model,
				"Bandeau",
				V3(pn[4], bh, 0.42) * u,
				band * CFrame.new(s * pn[1] * u, 0, (zc + pn[2]) * u) * CFrame.Angles(pitch, -s * pn[3], 0),
				HAIR,
				{ Material = CARVE_MAT }
			)
		end
	end
	local plate = band * CFrame.new(0, 0, (zc - 0.25) * u - 0.3) * CFrame.Angles(zForce and 0 or FRONT_TILT, 0, 0)
	ctx.count += 1
	Build.deco(ctx.model, "Plaque", V3(2.5 * u, bh * 1.1 * u, 0.6), plate, shade(FACE, 0.07), { Material = CARVE_MAT })
	-- spirale de la feuille gravée : six traits qui s'enroulent et la pointe
	local g = plate * CFrame.new(0, 0, -0.32)
	local r = math.min(0.42, bh * 0.4) * u
	for k = 0, 5 do
		local ang = k * 1.05
		local rr = r * (1 - k * 0.12)
		ctx.count += 1
		Build.deco(
			ctx.model,
			"Gravure",
			V3(rr * 0.95, 0.07 * u, 0.12),
			g * CFrame.new(math.cos(ang) * rr * 0.8, math.sin(ang) * rr * 0.8, 0) * CFrame.Angles(0, 0, ang + math.pi / 2),
			DEEP,
			{ Material = CARVE_MAT, CastShadow = false }
		)
	end
	ctx.count += 1
	Build.deco(ctx.model, "Gravure", V3(r * 0.9, 0.07 * u, 0.12), g * CFrame.new(r * 0.95, -r * 0.7, 0) * CFrame.Angles(0, 0, -0.7), DEEP, {
		Material = CARVE_MAT,
		CastShadow = false,
	})
end

------------------------------------------------------------------------
-- Visage commun : une SURFACE TAILLÉE en facettes (maillage de triangles, deux coins par
-- triangle), comme une sculpture dégrossie au ciseau. Expression calme.
------------------------------------------------------------------------

-- Triangle plein posé avec deux coins (WedgePart), la technique classique pour une surface
-- quelconque. Points en coordonnées monde ; `n` = normale extérieure ; l'épaisseur part vers
-- l'intérieur. Renvoie le nombre de pièces posées.
local function triangle(model: Instance, a: Vector3, b: Vector3, c: Vector3, n: Vector3, thick: number, color: Color3): number
	local off = -n * (thick / 2)
	a, b, c = a + off, b + off, c + off
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab)
	if right.Magnitude < 1e-6 then
		return 0
	end
	right = right.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local props = { Material = CARVE_MAT, CanCollide = false, CanQuery = false }
	local count = 0
	local w1, w2 = math.abs(ab:Dot(back)), math.abs(ac:Dot(back))
	if w1 > 0.02 and height > 0.02 then
		Build.wedge(model, "Facette", V3(thick, height, w1), CFrame.fromMatrix((a + b) / 2, right, up, back), color, props)
		count += 1
	end
	if w2 > 0.02 and height > 0.02 then
		Build.wedge(model, "Facette", V3(thick, height, w2), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color, props)
		count += 1
	end
	return count
end
Hokage.triangle = triangle

-- Sommets d'une moitié du visage (x ≥ 0, en unités ; les sommets « c_ » sont sur l'axe).
local FACE_VERTS: { [string]: { number } } = {
	c_top = { 0, 3.3, -2.9 }, -- lisière des cheveux
	c_fh = { 0, 2.0, -3.3 }, -- front
	c_gl = { 0, 0.8, -3.4 }, -- glabelle
	c_br = { 0, 0.15, -3.3 }, -- racine du nez
	c_tip = { 0, -1.45, -4.15 }, -- bout du nez
	c_sn = { 0, -1.95, -3.5 }, -- sous le nez
	c_m = { 0, -2.78, -3.28 }, -- bouche (trait)
	c_ll = { 0, -3.05, -3.4 }, -- lèvre du bas
	c_mc = { 0, -3.35, -3.25 }, -- creux du menton
	c_ch = { 0, -3.85, -3.45 }, -- menton
	c_cb = { 0, -4.4, -3.0 }, -- dessous du menton
	c_uc = { 0, -4.7, -1.6 }, -- vers le cou
	r_hl = { 2.8, 2.6, -1.8 }, -- lisière à la tempe
	r_fh = { 1.6, 2.0, -3.15 }, -- côté du front
	r_tp = { 3.0, 1.3, -1.9 }, -- tempe
	r_bi = { 0.55, 0.9, -3.42 }, -- sourcil, côté nez
	r_bm = { 1.35, 1.05, -3.4 }, -- sourcil, milieu
	r_bo = { 2.35, 0.75, -2.95 }, -- sourcil, bout
	r_ei = { 0.6, 0.15, -3.02 }, -- coin de l'œil, côté nez
	r_et = { 1.3, 0.42, -2.9 }, -- haut de l'orbite
	r_eo = { 2.05, 0.15, -2.78 }, -- coin de l'œil, dehors
	r_eb = { 1.3, -0.08, -3.0 }, -- bas de l'œil
	r_ue = { 1.25, -0.55, -3.2 }, -- sous l'œil
	r_cb = { 2.2, -0.55, -3.0 }, -- pommette
	r_cs = { 2.95, -0.35, -2.1 }, -- côté de la joue
	r_ns = { 0.42, -0.35, -3.3 }, -- flanc du nez
	r_nw = { 0.6, -1.65, -3.5 }, -- aile du nez
	r_nb = { 0.3, -1.98, -3.5 }, -- narine
	r_ck = { 1.5, -1.55, -3.15 }, -- joue
	r_nl = { 0.95, -2.15, -3.3 }, -- pli du nez
	r_mc = { 0.9, -2.78, -3.1 }, -- coin de la bouche
	r_jm = { 2.35, -2.2, -2.5 }, -- mâchoire
	r_ja = { 2.75, -2.9, -1.3 }, -- angle de la mâchoire
	r_jl = { 1.9, -3.55, -2.55 }, -- bas de la mâchoire
	r_cs2 = { 0.95, -3.7, -3.2 }, -- côté du menton
	r_cbs = { 0.9, -4.3, -2.85 }, -- dessous du menton, côté
	r_uj = { 1.8, -4.05, -1.6 }, -- sous la mâchoire
}

-- Facettes d'une moitié (55 triangles ; l'autre moitié est le miroir).
local FACE_TRIS: { { string } } = {
	-- front
	{ "c_top", "r_hl", "r_fh" },
	{ "c_top", "r_fh", "c_fh" },
	{ "r_hl", "r_tp", "r_fh" },
	{ "c_fh", "r_fh", "r_bi" },
	{ "c_fh", "r_bi", "c_gl" },
	{ "r_fh", "r_bm", "r_bi" },
	{ "r_fh", "r_tp", "r_bm" },
	{ "r_tp", "r_bo", "r_bm" },
	-- dessous de l'arcade (dans l'ombre) et orbite
	{ "c_gl", "r_bi", "r_ei" },
	{ "c_gl", "r_ei", "c_br" },
	{ "r_bi", "r_bm", "r_et" },
	{ "r_bi", "r_et", "r_ei" },
	{ "r_bm", "r_bo", "r_et" },
	{ "r_bo", "r_eo", "r_et" },
	{ "r_ei", "r_et", "r_eo" },
	{ "r_ei", "r_eo", "r_eb" },
	-- tempe
	{ "r_tp", "r_cs", "r_bo" },
	{ "r_bo", "r_cs", "r_eo" },
	-- sous l'œil et pommette
	{ "r_ei", "r_eb", "r_ue" },
	{ "r_eb", "r_eo", "r_cb" },
	{ "r_eb", "r_cb", "r_ue" },
	{ "r_eo", "r_cs", "r_cb" },
	-- nez
	{ "c_br", "r_ei", "r_ns" },
	{ "c_br", "r_ns", "c_tip" },
	{ "r_ns", "r_nw", "c_tip" },
	{ "r_nw", "r_nb", "c_tip" },
	{ "r_nb", "c_sn", "c_tip" },
	{ "r_ei", "r_ue", "r_ns" },
	{ "r_ns", "r_ue", "r_nw" },
	{ "r_ue", "r_ck", "r_nw" },
	-- joue
	{ "r_ue", "r_cb", "r_ck" },
	{ "r_cb", "r_jm", "r_ck" },
	{ "r_cb", "r_cs", "r_jm" },
	{ "r_cs", "r_ja", "r_jm" },
	-- lèvres
	{ "r_nw", "r_ck", "r_nl" },
	{ "r_nw", "r_nl", "r_nb" },
	{ "r_nb", "r_nl", "r_mc" },
	{ "r_nb", "r_mc", "c_sn" },
	{ "c_sn", "r_mc", "c_m" },
	{ "c_m", "r_mc", "c_ll" },
	{ "r_mc", "r_cs2", "c_ll" },
	{ "c_ll", "r_cs2", "c_mc" },
	{ "c_mc", "r_cs2", "c_ch" },
	-- joue vers la mâchoire
	{ "r_nl", "r_ck", "r_jm" },
	{ "r_nl", "r_jm", "r_mc" },
	{ "r_mc", "r_jm", "r_jl" },
	{ "r_mc", "r_jl", "r_cs2" },
	{ "r_jm", "r_ja", "r_jl" },
	-- menton et dessous
	{ "r_cs2", "r_cbs", "c_ch" },
	{ "c_ch", "r_cbs", "c_cb" },
	{ "r_cs2", "r_jl", "r_cbs" },
	{ "r_jl", "r_uj", "r_cbs" },
	{ "r_jl", "r_ja", "r_uj" },
	{ "c_cb", "r_cbs", "c_uc" },
	{ "r_cbs", "r_uj", "c_uc" },
}
Hokage.FaceTriangles = #FACE_TRIS * 2

type FaceOptions = {
	jaw: number?, -- largeur de la mâchoire
	brow: number?, -- bout du sourcil plus bas (calme > 0) ou plus haut (sévère < 0)
	frown: number?, -- sourcils froncés (0 = calme, 1 = très froncés, < 0 = doux, relevés)
	long: number?, -- longueur du visage sous les yeux (1 = normal, ±10 %)
	cheek: number?, -- largeur des pommettes
	soft: boolean?, -- traits plus fins (visage féminin, jeune)
	mask: boolean?, -- masque de tissu sur le bas du visage
	hideEye: number?, -- œil caché par le bandeau (-1 ou 1)
	lid: number?, -- paupière supérieure plus basse (regard las : Kakashi)
	gaze: number?, -- regard tourné d'un côté (iris décalés)
	mouth: string?, -- "calme" (trait droit), "severe" (coins tombants), "sourire" (coins relevés)
	whiskers: boolean?, -- trois moustaches gravées par joue (Naruto, Boruto : deux)
	whiskerCount: number?,
	ears: boolean?,
	age: boolean?, -- rides du front, plis des joues et poches sous les yeux
}

-- Position d'un sommet (côté `s`), ajustée selon le visage.
local function faceVertex(name: string, s: number, o: FaceOptions): Vector3
	local p = FACE_VERTS[name]
	local x, y, z = p[1], p[2], p[3]
	local jw = o.jaw or 1
	if y < -1.8 and x > 0 then
		x *= jw -- mâchoire plus large ou plus fine
	end
	if y < 0 then
		y *= o.long or 1 -- visage plus long ou plus court sous les yeux
	end
	if name == "r_cb" or name == "r_cs" or name == "r_jm" then
		x *= o.cheek or 1
	end
	if name == "r_bo" then
		y -= o.brow or 0.04
	end
	local frown = o.frown or 0
	if name == "r_bi" then
		-- sourcil froncé : la tête du sourcil descend et avance vers la racine du nez
		y -= frown * 0.24
		z -= frown * 0.06
	elseif name == "r_bm" then
		y -= frown * 0.05
	elseif name == "r_bo" then
		y += frown * 0.1
	end
	if o.soft then
		-- nez plus fin, menton plus petit et plus rond, mâchoire plus douce
		if name == "c_tip" then
			z += 0.2
		elseif name == "r_nw" or name == "r_nb" then
			x *= 0.85
		elseif name == "c_ch" or name == "c_cb" then
			z += 0.1
		elseif name == "r_cs2" or name == "r_cbs" then
			x *= 0.8
		elseif name == "r_jl" then
			x *= 0.92
		end
	end
	if o.mask then
		-- sous le masque, le bas du visage est une surface lisse : la bouche disparaît, le nez s'aplatit
		if name == "c_tip" then
			z += 0.3
		elseif name == "c_sn" or name == "c_m" or name == "c_ll" or name == "c_mc" then
			z = -3.42 + (y + 1.95) * 0.03
		elseif name == "r_nb" or name == "r_nl" or name == "r_mc" then
			z = -3.3
		end
	end
	return V3(x * s, y, z)
end

local FACE_CENTER = V3(0, -0.5, 0.6)

-- Facettes de l'orbite (le creux autour de l'œil) : plus sombres, l'œil s'y détache.
local ORBIT = { r_ei = true, r_et = true, r_eo = true, r_eb = true }

-- Trait gravé (sombre) entre deux points du visage (unités), posé sur la surface.
local function groove(ctx: Ctx, a: Vector3, b: Vector3, w: number, color: Color3?, name: string?)
	local u = ctx.u
	local d = b - a
	ctx.count += 1
	Build.deco(
		ctx.model,
		name or "Gravure",
		V3(w * u, w * 1.4 * u, d.Magnitude * u + w * 0.5 * u),
		ctx.cf * CFrame.lookAt((a + b) / 2 * u, (a + b) / 2 * u + d.Unit, V3(0, 0, -1)),
		color or DEEP,
		{ Material = CARVE_MAT, CastShadow = false }
	)
end

-- Œil OUVERT taillé en amande : globe bombé dans l'orbite sombre, paupière supérieure en coin
-- qui le couvre en partie (ombre), iris gravé, pli de la paupière. `s` = côté.
local function openEye(ctx: Ctx, s: number, o: FaceOptions)
	local u = ctx.u
	local lid = o.lid or 0
	local soft = o.soft and 0.92 or 1
	local cx, cy = s * 1.32, 0.15
	-- globe : un ovale aplati qui sort de l'orbite ; son contour sur les facettes dessine l'amande
	ctx.count += 1
	local ball = Core.ellipsoid(ctx.model, "Oeil", V3(1.42 * soft, 0.62, 0.9) * u, at(ctx, cx, cy, -2.74, 0, -s * 0.18, s * 0.06), shade(FACE, 0.05), CARVE_MAT)
	ball.CanCollide = false
	ball.CanQuery = false
	-- iris gravé : un disque en creux (plus sombre que la pierre) et la pupille percée au centre ;
	-- le regard part un peu vers le bas, vers le village
	local gx = (o.gaze or 0) * 0.12
	local irisAt = at(ctx, cx + gx - s * 0.02, cy - 0.02 - lid * 0.06, -3.16, 0, math.pi / 2 - s * 0.18, 0)
	ctx.count += 2
	Build.deco(ctx.model, "Iris", V3(0.06 * u, 0.44 * u, 0.44 * u), irisAt, shade(FACE, -0.3), {
		Material = CARVE_MAT,
		CastShadow = false,
		Shape = Enum.PartType.Cylinder,
	})
	Build.deco(ctx.model, "Iris", V3(0.08 * u, 0.15 * u, 0.15 * u), irisAt, DEEP, {
		Material = CARVE_MAT,
		CastShadow = false,
		Shape = Enum.PartType.Cylinder,
	})
	-- paupière supérieure : deux pans en coin qui suivent l'arc de l'œil et avancent au-dessus du globe
	for _, k in { -1, 1 } do
		local lx = cx + k * s * 0.36 * soft
		local ly = cy + 0.25 - lid * 0.16 - (k * s > 0 and 0.05 or 0)
		ctx.count += 1
		Build.wedge(
			ctx.model,
			"Paupiere",
			V3(0.8 * soft * u, (0.2 + lid * 0.12) * u, 0.42 * u),
			at(ctx, lx, ly, -3.07, 0, -s * 0.18, -k * s * 0.2) * CFrame.Angles(0, math.pi, 0),
			shade(FACE, 0.02),
			{ Material = CARVE_MAT, CanCollide = false, CanQuery = false }
		)
	end
	-- pli de la paupière (trait sombre au-dessus de l'œil) et dessous de l'œil
	groove(ctx, V3(cx - s * 0.62 * soft, cy + 0.36, -3.05), V3(cx + s * 0.62 * soft, cy + 0.38, -2.93), 0.07, shade(FACE, -0.32), "Pli")
	if o.age then
		groove(ctx, V3(cx - s * 0.5, cy - 0.42, -3.1), V3(cx + s * 0.55, cy - 0.38, -2.98), 0.07, shade(FACE, -0.25), "Ride")
	end
end

local function face(ctx: Ctx, o: FaceOptions)
	local u = ctx.u
	local thick = 1.6
	-- masse intérieure (sombre) et côtés de la tête : elle bouche l'arrière du masque facetté
	E(ctx, "Crane", 6.2, 6.8, 7.0, at(ctx, 0, 1.6, 0.9))
	B(ctx, "Noyau", 5.2, 6.4, 4.0, at(ctx, 0, -1.0, 0.4), shade(FACE, -0.1))
	for _, s in { -1, 1 } do
		B(ctx, "Cote", 0.6, 4.6, 3.0, at(ctx, s * 2.75, -0.9, -0.2, 0, -s * 0.15, 0))
	end
	-- surface du visage (l'orbite plus sombre : l'œil s'y détache)
	local socket = shade(FACE, -0.16)
	for _, s in { -1, 1 } do
		for _, t in FACE_TRIS do
			local la, lb, lc = faceVertex(t[1], s, o), faceVertex(t[2], s, o), faceVertex(t[3], s, o)
			local n = (lb - la):Cross(lc - la)
			if n.Magnitude > 1e-6 then
				n = n.Unit
				if n:Dot((la + lb + lc) / 3 - FACE_CENTER) < 0 then
					n = -n
				end
				local wa, wb, wc = ctx.cf * (la * u), ctx.cf * (lb * u), ctx.cf * (lc * u)
				local dark = ORBIT[t[1]] and ORBIT[t[2]] and ORBIT[t[3]] and o.hideEye ~= s
				ctx.count += triangle(ctx.model, wa, wb, wc, ctx.cf:VectorToWorldSpace(n), thick, dark and socket or FACE)
			end
		end
	end
	-- sourcils : arête taillée en coin au-dessus de chaque œil ; froncés (tête du sourcil basse),
	-- calmes ou doux (relevés) selon le personnage
	local frown = o.frown or 0
	for _, s in { -1, 1 } do
		if o.hideEye ~= s then
			local tilt = 0.08 + frown * 0.3
			ctx.count += 1
			Build.wedge(
				ctx.model,
				"Sourcil",
				V3((o.soft and 1.5 or 1.75) * u, (0.3 + math.max(frown, 0) * 0.08) * u, 0.5 * u),
				at(ctx, s * 1.36, 0.8 - frown * 0.08, -3.3 + frown * 0.04, 0, -s * 0.2, s * tilt) * CFrame.Angles(0, math.pi, 0),
				FACE,
				{ Material = CARVE_MAT, CanCollide = false, CanQuery = false }
			)
		end
	end
	-- yeux ouverts en amande (l'œil caché par le bandeau n'en a pas)
	for _, s in { -1, 1 } do
		if o.hideEye ~= s then
			openEye(ctx, s, o)
		end
	end
	if frown > 0.3 then
		-- plis entre les sourcils (regard sévère)
		for _, s in { -1, 1 } do
			groove(ctx, V3(s * 0.2, 0.55, -3.42), V3(s * 0.3, 1.1, -3.38), 0.07, shade(FACE, -0.3), "Pli")
		end
	end
	-- bouche : un trait taillé, droit (calme), aux coins tombants (sévère) ou relevés (sourire)
	local ly = -2.78 * (o.long or 1)
	if o.mask then
		B(ctx, "Ourlet", 3.6, 0.12, 0.25, at(ctx, 0, -0.62, -3.35), shade(FACE, -0.12))
	else
		local w = o.soft and 0.72 or 0.82
		local corner = o.mouth == "severe" and -0.16 or (o.mouth == "sourire" and 0.2 or -0.03)
		for _, s in { -1, 1 } do
			groove(ctx, V3(0, ly, -3.3), V3(s * w, ly + corner, -3.14), 0.12, DEEP, "Trait")
		end
	end
	-- moustaches gravées sur les joues (trois traits, du nez vers l'oreille)
	if o.whiskers then
		local n = o.whiskerCount or 3
		for _, s in { -1, 1 } do
			for k = 1, n do
				local y = (-0.95 - (k - 1) * 0.34) * (o.long or 1)
				groove(ctx, V3(s * 1.45, y + 0.04, -3.2), V3(s * 2.45, y - 0.06 + (k - 2) * 0.08, -2.85), 0.13, DEEP, "Moustache")
			end
		end
	end
	if o.age then
		for _, y in { 2.45, 2.85 } do
			B(ctx, "Ride", 2.4, 0.08, 0.14, at(ctx, 0, y, -3.12 - (2.85 - y) * 0.2, 0.3, 0, 0), shade(FACE, -0.16))
		end
		-- plis des joues, du nez vers les coins de la bouche
		for _, s in { -1, 1 } do
			groove(ctx, V3(s * 0.72, -1.7 * (o.long or 1), -3.42), V3(s * 1.12, ly - 0.15, -3.18), 0.08, shade(FACE, -0.28), "Ride")
		end
	end
	if o.ears ~= false then
		for _, s in { -1, 1 } do
			B(ctx, "Oreille", 0.55, 1.9, 1.2, at(ctx, s * 3.1, -0.2, -0.6, 0, -s * 0.35, 0))
		end
	end
	-- cou (dans l'ombre) qui sort de la roche ; les blocs autour le cachent en partie
	B(ctx, "Cou", 3.0, 3.2, 3.0, at(ctx, 0, -5.4, 0.6), shade(FACE, -0.12))
end

------------------------------------------------------------------------
-- Coiffures et signes distinctifs
------------------------------------------------------------------------

local STYLES: { [string]: (Ctx) -> () } = {}

-- Surface facettée symétrique : `rows` = rangées de sommets (moitié x ≥ 0, en unités), reliées
-- deux à deux par des triangles ; `center` sert à orienter l'épaisseur vers l'intérieur.
local function surface(ctx: Ctx, rows: { { { number } } }, center: Vector3, thick: number, color: Color3?)
	local u = ctx.u
	for _, s in { -1, 1 } do
		local function P(p: { number }): Vector3
			return V3(p[1] * s, p[2], p[3])
		end
		local function tri(a: Vector3, b: Vector3, c: Vector3)
			local n = (b - a):Cross(c - a)
			if n.Magnitude < 1e-6 then
				return
			end
			n = n.Unit
			if n:Dot((a + b + c) / 3 - center) < 0 then
				n = -n
			end
			ctx.count += triangle(ctx.model, ctx.cf * (a * u), ctx.cf * (b * u), ctx.cf * (c * u), ctx.cf:VectorToWorldSpace(n), thick, color or HAIR)
		end
		for i = 1, #rows - 1 do
			local r0, r1 = rows[i], rows[i + 1]
			for j = 1, #r0 - 1 do
				local a, b, c, d = P(r0[j]), P(r0[j + 1]), P(r1[j]), P(r1[j + 1])
				tri(a, b, d)
				tri(a, d, c)
			end
		end
	end
end

-- Chevelure en épis : les mèches de devant et du dessus sont couchées sur la masse (elles la
-- recouvrent), celles de la silhouette se dressent vers le haut et les côtés, celles du fond
-- remplissent. `len` = longueur des épis ; `lean` penche tout d'un côté.
local SPIKY_TOP = {
	{ { 0, 3.2, -3.12 }, { 1.1, 3.15, -2.98 }, { 2.2, 2.8, -2.52 }, { 3.1, 2.0, -1.92 }, { 3.45, 1.15, -1.45 } },
	{ { 0, 4.75, -2.6 }, { 1.15, 4.55, -2.46 }, { 2.35, 4.15, -2.02 }, { 3.4, 3.05, -1.42 }, { 3.85, 1.8, -1.0 } },
	{ { 0, 5.9, -0.75 }, { 1.25, 5.65, -0.68 }, { 2.45, 5.2, -0.5 }, { 3.6, 3.9, -0.35 }, { 4.1, 2.1, -0.2 } },
}

-- Chevelure en épis SCULPTÉE EN VOLUME : une calotte facettée bombée (le crâne a du volume),
-- des mèches couchées sur le devant, puis trois couches d'épis épais (≥ 1,6 de large, ≥ 0,9
-- d'épaisseur) décalées en profondeur, courbées vers les côtés, aux longueurs et angles
-- irréguliers (± 30 %) : on lit une chevelure taillée dans la masse, pas une couronne.
local function spikes(ctx: Ctx, len: number, o: { lean: number?, fall: number?, wide: number?, n: number?, bend: number? }?)
	local opt = o or {}
	local lean = opt.lean or 0
	local wide = opt.wide or 1.5
	local n = opt.n or 8
	local bend = opt.bend or 0.18
	surface(ctx, SPIKY_TOP, V3(0, 1.5, 0.8), 2.2)
	-- mèches épaisses couchées vers l'arrière sur le devant de la masse
	for k = -2, 2 do
		local x = k * 0.95
		local j = jitter(k, 5.1)
		lock(
			ctx,
			V3(x, 3.4 - math.abs(k) * 0.12, -3.15 + math.abs(k) * 0.12),
			V3(x * 0.16 + lean * 0.4 + j * 0.12, 1, 0.42),
			len * (0.7 + j * 0.15),
			2.1,
			0.9,
			V3(x * 0.2, 0.5, -1),
			0.42
		)
	end
	local a0, a1 = -wide + math.min(lean, 0) * 0.5, wide + math.max(lean, 0) * 0.5
	local common = { lean = lean, tilt = 0.8, bend = bend, jit = 1, t = 0.95, fall = opt.fall or 0.4 }
	local function layer(spec: { [string]: any })
		for key, value in common do
			if spec[key] == nil then
				spec[key] = value
			end
		end
		crown(ctx, spec :: any)
	end
	-- couche de devant : épis plus courts, tournés vers le village
	layer({ n = math.max(n - 2, 4), a0 = a0 * 0.8, a1 = a1 * 0.8, p = 0.32, len = len * 0.78, w = 2.2, back = 0.25, face = 1.0, salt = 1.3 })
	-- couche du milieu : la silhouette
	layer({ n = n, a0 = a0, a1 = a1, p = 0.02, len = len, w = 2.5, back = 0.4, face = 0.85, salt = 2.9 })
	-- couche du fond, décalée d'un demi-pas : remplit entre les épis
	local half = (a1 - a0) / math.max(n - 1, 1) * 0.5
	layer({ n = math.max(n - 1, 3), a0 = a0 + half, a1 = a1 - half, p = -0.42, len = len * 1.12, w = 2.7, back = 0.55, face = 1.1, salt = 4.7 })
end

-- Cheveux longs et lisses : une coiffe facettée (raie au milieu creusée en V, mèches en
-- côtes de la raie vers les côtés), puis de grands rideaux facettés de chaque côté du visage,
-- jusqu'aux épaules, aux pointes inégales.
local LONG_TOP = {
	{ { 0, 3.05, -3.08 }, { 0.4, 3.12, -3.05 }, { 1.1, 3.05, -2.9 }, { 2.2, 2.65, -2.45 }, { 3.15, 1.6, -1.75 }, { 3.5, 0.5, -1.4 } },
	{ { 0, 4.3, -2.5 }, { 0.4, 4.58, -2.45 }, { 1.1, 4.5, -2.3 }, { 2.2, 4.0, -1.95 }, { 3.35, 2.75, -1.35 }, { 3.8, 1.3, -0.95 } },
	{ { 0, 5.38, -0.75 }, { 0.4, 5.7, -0.72 }, { 1.1, 5.6, -0.62 }, { 2.3, 5.0, -0.5 }, { 3.5, 3.6, -0.35 }, { 4.0, 1.7, -0.2 } },
	{ { 0, 5.8, 1.4 }, { 0.4, 5.85, 1.4 }, { 1.2, 5.75, 1.4 }, { 2.5, 5.1, 1.4 }, { 3.7, 3.6, 1.4 }, { 4.1, 1.7, 1.4 } },
}

local function longHair(ctx: Ctx, length: number, open: number)
	-- la rangée du fond (dessus du crâne, jamais vue d'en bas) est laissée au crâne caché
	surface(ctx, { LONG_TOP[1], LONG_TOP[2], LONG_TOP[3] }, V3(0, 1.5, 0.8), 2.2)
	-- sillons gravés entre les mèches, de la raie vers les côtés (sur les arêtes des facettes)
	local u = ctx.u
	for _, s in { -1, 1 } do
		for _, t in { 0.5, 1.45 } do
			local i = math.floor(t) + 1
			local f = t - math.floor(t)
			local r0, r1 = LONG_TOP[i], LONG_TOP[i + 1]
			local function pt(j: number): Vector3
				local a, b = r0[j], r1[j]
				return V3((a[1] + (b[1] - a[1]) * f) * s, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f)
			end
			for j = 2, #r0 - 1 do
				local a, b = pt(j), pt(j + 1)
				local mid = (a + b) / 2
				local outward = (mid - V3(0, 1.5, 0.8)).Unit
				local p = mid + outward * 0.06
				local d = b - a
				ctx.count += 1
				Build.deco(
					ctx.model,
					"Sillon",
					V3(0.12 * u, 0.1 * u, d.Magnitude * u),
					ctx.cf * CFrame.lookAt(p * u, (p + d) * u, outward),
					shade(HAIR, -0.22),
					{ Material = CARVE_MAT, CastShadow = false }
				)
			end
		end
	end
	-- rideaux : colonnes de l'avant vers l'arrière, rangées du haut vers le bas
	local o = open
	local y2 = -2.3
	local y3 = 4.6 - length
	local curtain = {
		{ LONG_TOP[1][6], LONG_TOP[2][6], LONG_TOP[3][6], LONG_TOP[4][6] },
		{ { 3.35 + o * 0.5, y2, -1.6 }, { 3.85 + o * 0.5, y2, -0.75 }, { 4.1 + o * 0.5, y2, 0.15 }, { 4.15 + o * 0.5, y2, 1.4 } },
		{ { 3.4 + o, y3, -1.55 }, { 3.95 + o, y3 + 1.1, -0.8 }, { 4.2 + o, y3 - 0.5, 0.1 }, { 4.25 + o, y3 + 0.7, 1.4 } },
	}
	-- les rideaux sont des surfaces à part (la normale « extérieure » part sur le côté)
	for _, s in { 1 } do
		local _ = s
		surface(ctx, curtain, V3(0, -1, 0.4), 3.0)
	end
	-- deux mèches fines devant les oreilles, qui encadrent le visage, et les pointes des rideaux
	for _, s in { -1, 1 } do
		lock(ctx, V3(s * 3.3, 1.4, -1.65), V3(s * 0.05, -1, -0.05), length * 0.62, 1.4, 0.4, V3(s * 0.5, 0, -1), 0.2)
		lock(ctx, V3(s * (3.45 + o), y3 + 0.4, -1.5), V3(s * 0.06, -1, 0), 1.6, 1.3, 0.5, V3(s * 0.6, 0, -1), 0.2)
		lock(ctx, V3(s * (4.15 + o), y3 + 0.2, 0.1), V3(s * 0.08, -1, 0), 1.8, 1.6, 0.5, V3(s, 0, -0.4), 0.2)
	end
end

-- Hashirama : longs cheveux raides séparés au milieu, jusqu'aux épaules ; regard calme et ouvert.
STYLES.longs = function(ctx)
	face(ctx, { jaw = 1.03, long = 1.06, cheek = 1.0, frown = 0.15, mouth = "calme", ears = false })
	longHair(ctx, 10.4, 0.05)
end

-- Hiruzen : visage long et ridé, sourcils froncés, cheveux dressés en flamme, long bouc pointu.
STYLES.epis = function(ctx)
	face(ctx, { brow = 0.07, age = true, frown = 0.8, long = 1.1, cheek = 1.08, mouth = "severe", jaw = 0.96 })
	spikes(ctx, 2.8, { fall = 1.0, wide = 1.25, n = 7, bend = 0.12 })
	-- bouc : une longue mèche épaisse qui descend du menton et avance un peu (bien visible de face)
	lock(ctx, V3(0, -4.1, -3.15), V3(0, -1, -0.32), 4.2, 2.0, 0.9, V3(0, 0.1, -1), 0.45)
	lock(ctx, V3(0, -4.0, -2.9), V3(0, -1, 0.05), 3.0, 1.5, 0.7, V3(0, 0.1, -1), 0.4)
	-- petite moustache de chaque côté de la bouche
	for _, s in { -1, 1 } do
		lock(ctx, V3(s * 0.45, -2.25 * 1.1, -3.5), V3(s * 0.5, -1, -0.05), 1.5, 0.8, 0.4, V3(0, 0, -1), 0.3)
	end
end

-- Tsunade : cheveux lisses séparés au milieu, longs rideaux, losange sur le front, regard sévère.
STYLES.raie = function(ctx)
	face(ctx, { soft = true, jaw = 0.92, long = 0.97, cheek = 0.94, frown = 0.55, mouth = "severe", ears = false })
	longHair(ctx, 9.4, 0.25)
	for _, s in { -1, 1 } do
		lock(ctx, V3(s * 0.35, 3.25, -3.12), V3(s, -0.55, 0.05), 2.4, 1.7, 0.5, V3(0, 0.4, -1), 0.3)
	end
	B(ctx, "Losange", 0.5, 0.5, 0.14, at(ctx, 0, 1.75, foreheadZ(1.75) - 0.02, FRONT_TILT, 0, math.rad(45)), DEEP)
end

-- Naruto : visage rond et court, petit sourire, trois moustaches gravées par joue, épis en
-- bataille au-dessus du bandeau, frange en pointes qui retombe dessus.
STYLES.bandeau = function(ctx)
	face(ctx, { jaw = 0.98, long = 0.94, cheek = 1.04, frown = -0.2, mouth = "sourire", whiskers = true })
	spikes(ctx, 3.0, { wide = 1.6, n = 9, bend = 0.22 })
	bandBangs(ctx, 5, 2.0, 2.35, 1.35)
	for _, s in { -1, 1 } do
		lock(ctx, V3(s * 2.95, 2.9, -1.3), V3(s * 0.12, -1, -0.15), 3.2, 1.7, 0.6, V3(s * 0.5, 0, -1))
	end
	headband(ctx, 2.35)
end

-- Tobirama : visage long et anguleux, sourcils très froncés, cheveux courts hérissés au-dessus
-- d'un bandeau qui épouse le front, protège-oreilles plats.
STYLES.plaque = function(ctx)
	face(ctx, { brow = -0.05, jaw = 1.05, long = 1.08, cheek = 1.06, frown = 0.95, mouth = "severe", ears = false })
	spikes(ctx, 2.3, { wide = 1.45, n = 7, bend = 0.1 })
	headband(ctx, 2.4)
	for _, s in { -1, 1 } do
		B(ctx, "Garde", 0.5, 2.6, 2.2, at(ctx, s * 3.3, 0.5, 0.1, 0, -s * 0.15, 0), HAIR)
	end
end

-- Minato : visage doux, crinière de grandes pointes, longue frange, longues mèches qui encadrent
-- le visage jusqu'à la mâchoire.
STYLES.meches = function(ctx)
	face(ctx, { jaw = 0.98, long = 1.02, cheek = 0.98, frown = -0.15, mouth = "calme" })
	spikes(ctx, 3.3, { fall = -0.4, wide = 1.7, n = 9, bend = 0.25 })
	bangs(ctx, 5, 2.2, 1.35, 1.7)
	for _, s in { -1, 1 } do
		lock(ctx, V3(s * 2.9, 3.1, -1.5), V3(s * 0.12, -1, -0.2), 5.4, 1.8, 0.6, V3(s * 0.5, 0, -1))
	end
end

-- Kakashi : regard las (paupière basse), grands épis penchés d'un côté, bandeau incliné sur un
-- œil, masque.
STYLES.penche = function(ctx)
	face(ctx, { mask = true, hideEye = -1, lid = 1, frown = 0.1, long = 1.03 })
	spikes(ctx, 3.8, { lean = -0.6, fall = 0.9, wide = 1.3, bend = 0.2 })
	bangs(ctx, 3, 1.6, 2.7, 1.8, -0.7)
	headband(ctx, 1.3, 0.42, 1.2, -3.72)
end

-- Boruto : visage jeune et court, regard doux, deux moustaches par joue, épis plus courts, une
-- longue mèche qui tombe sur le côté, bandeau sur le front.
STYLES.jeune = function(ctx)
	face(ctx, { soft = true, jaw = 0.95, long = 0.92, cheek = 0.96, frown = -0.3, mouth = "calme", whiskers = true, whiskerCount = 2, gaze = 1 })
	spikes(ctx, 2.6, { wide = 1.5, n = 8, bend = 0.2 })
	bandBangs(ctx, 4, 1.8, 2.35, 1.5)
	lock(ctx, V3(1.2, 3.9, -2.3), V3(0.35, -1, -0.3), 4.4, 1.7, 0.6, V3(0.3, 0.2, -1))
	headband(ctx, 2.35)
end

-- Sculpte une tête au repère `cf` (entre les yeux, -Z vers l'avant). Renvoie le nombre de pièces.
function Hokage.head(model: Model, cf: CFrame, style: string, u: number?): number
	local ctx: Ctx = { model = model, cf = cf, u = u or U, count = 0 }
	local build = STYLES[style] or STYLES.longs
	build(ctx)
	return ctx.count
end

------------------------------------------------------------------------
-- Relief
------------------------------------------------------------------------

-- Contour du sommet en `x` : un DÔME comme le monument (bosse au centre, épaules qui descendent
-- sur les côtés, ± 12 studs de bosses), puis deux épaules arrondies en quart de cercle jusqu'au
-- sol, au-delà de la largeur du relief (pied évasé).
local function topAt(x: number): number
	local half = Hokage.Width / 2
	local h = Hokage.Height * (0.78 + 0.22 * math.cos(x / Hokage.Width * math.pi)) + 7 * math.sin(x * 0.041 + 0.6) + 5 * math.cos(x * 0.107 + 1.3)
	local s0 = half - 40
	local a = math.abs(x)
	if a > s0 then
		local f = math.min((a - s0) / (Hokage.Reach - s0), 1)
		h *= math.sqrt(math.max(1 - f * f, 0))
	end
	return h
end
Hokage.topAt = topAt

-- Part de l'épaule en `x` (0 au centre du relief, 1 au pied de l'épaule) : les rochers y
-- rapetissent.
local function shoulderAt(x: number): number
	local s0 = Hokage.Width / 2 - 40
	return math.clamp((math.abs(x) - s0) / (Hokage.Reach - s0), 0, 1)
end

-- Distance (dans le plan du relief) à la tête la plus proche, normalisée par son encombrement
-- (< 1 : dans la silhouette de la tête).
-- `pad` (studs) élargit chaque silhouette (pour un bloc de demi-taille `pad`).
local function nearHead(x: number, y: number, pad: number?): number
	local p = pad or 0
	local best = math.huge
	for _, h in Hokage.Heads do
		local e = EXTENT[h.style] or EXTENT.longs
		local u = U * (h.scale or 1)
		local dx = (x - h.x) / (e[1] * u + p)
		local cy = h.y + (e[2] + e[3]) / 2 * u
		local dy = (y - cy) / ((e[2] - e[3]) / 2 * u + p)
		best = math.min(best, math.sqrt(dx * dx + dy * dy))
	end
	local em = Hokage.Emblem
	local de = math.sqrt(((x - em.x) / (34 + p)) ^ 2 + ((y - em.y) / (32 + p)) ^ 2)
	return math.min(best, de)
end
Hokage.nearHead = nearHead

local function tiltAngle(rng: Random, lo: number, hi: number): number
	local a = math.rad(rng:NextNumber(lo, hi))
	return rng:NextNumber() < 0.5 and -a or a
end

-- ROCHER ARRONDI (taillé en triangles) à moitié enfoncé dans la paroi. `front` = avancée du
-- sommet (z local, négatif = devant la paroi). Deux finesses :
--   * complet : base à cinq côtés, une couronne de facettes et un sommet (15 facettes) ;
--   * léger (`lite`) : base à six côtés et une arête de deux sommets (8 facettes), pour la masse.
-- Renvoie le nombre de pièces.
local function facetRock(model: Model, cf: CFrame, rng: Random, px: number, py: number, r: number, front: number, deep: number?, lite: boolean?): number
	local tone = shade(TONES[rng:NextInteger(1, #TONES)], rng:NextNumber(-0.05, 0.02))
	local center = V3(px, py, front + r * 1.1)
	local zb = front + r * (deep or 0.85)
	local a0 = rng:NextNumber(0, math.pi * 2)
	local count = 0
	local function tri(a: Vector3, b: Vector3, c: Vector3)
		local n = (b - a):Cross(c - a)
		if n.Magnitude < 1e-6 then
			return
		end
		n = n.Unit
		if n:Dot((a + b + c) / 3 - center) < 0 then
			n = -n
		end
		count += triangle(model, cf * a, cf * b, cf * c, cf:VectorToWorldSpace(n), 2.5, shade(tone, rng:NextNumber(-0.03, 0.03)))
	end
	if lite then
		local b = {}
		for k = 0, 5 do
			local a = a0 + k / 6 * math.pi * 2 + rng:NextNumber(-0.16, 0.16)
			local rr = r * rng:NextNumber(0.9, 1.12)
			b[k + 1] = V3(px + math.cos(a) * rr, py + math.sin(a) * rr * 0.82, zb)
		end
		local half = r * rng:NextNumber(0.3, 0.42)
		local d = V3(math.cos(a0) * half, math.sin(a0) * half * 0.82, 0)
		local lift = V3(0, r * 0.08, 0)
		local r1 = V3(px, py, front + r * rng:NextNumber(0, 0.12)) + d + lift
		local r2 = V3(px, py, front + r * rng:NextNumber(0, 0.12)) - d + lift
		tri(b[6], b[1], r1)
		tri(b[1], b[2], r1)
		tri(b[2], r2, r1)
		tri(b[2], b[3], r2)
		tri(b[3], b[4], r2)
		tri(b[4], b[5], r2)
		tri(b[5], r1, r2)
		tri(b[5], b[6], r1)
		return count
	end
	local base, mid = {}, {}
	for k = 0, 4 do
		local a = a0 + k / 5 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local rr = r * rng:NextNumber(0.9, 1.15)
		base[k + 1] = V3(px + math.cos(a) * rr, py + math.sin(a) * rr * 0.8, zb)
		local am = a + math.pi / 5 + rng:NextNumber(-0.15, 0.15)
		local rm = r * rng:NextNumber(0.5, 0.68)
		mid[k + 1] = V3(px + math.cos(am) * rm, py + math.sin(am) * rm * 0.8, front + r * rng:NextNumber(0.2, 0.35))
	end
	local apex = V3(px + rng:NextNumber(-0.2, 0.2) * r, py + rng:NextNumber(0, 0.25) * r, front)
	for k = 1, 5 do
		local k2 = k % 5 + 1
		tri(base[k], base[k2], mid[k])
		tri(base[k2], mid[k2], mid[k])
		tri(mid[k], mid[k2], apex)
	end
	return count
end
Hokage.facetRock = facetRock

-- Pierre BISEAUTÉE (5 pièces) : un noyau et quatre pans en biseau autour de sa face avant, comme
-- un rocher émoussé ; bascule de 4 à 12° sur les trois axes (aucune arête droite alignée).
-- `front` = face avant (z local, négatif = devant la paroi). Renvoie le nombre de pièces.
local function bevelRock(model: Model, cf: CFrame, rng: Random, px: number, py: number, sx: number, sy: number, front: number, name: string?): number
	local tone = shade(TONES[rng:NextInteger(1, #TONES)], rng:NextNumber(-0.06, 0.03))
	local b = math.min(sx, sy) * rng:NextNumber(0.34, 0.44)
	local depth = math.max(sx, sy) * 0.6 + 8
	local o = cf * CFrame.new(px, py, front) * CFrame.Angles(tiltAngle(rng, 4, 9), tiltAngle(rng, 4, 9), tiltAngle(rng, 4, 12))
	local props = { Material = ROCK_MAT, CanCollide = false, CanQuery = false }
	local nm = name or "Pierre"
	Build.deco(model, nm, V3(sx - 2 * b, sy - 2 * b, depth), o * CFrame.new(0, 0, depth / 2), tone, { Material = ROCK_MAT })
	local lit = shade(tone, 0.04)
	Build.wedge(model, nm, V3(sx - 2 * b, b, b), o * CFrame.new(0, sy / 2 - b / 2, b / 2), lit, props)
	Build.wedge(model, nm, V3(sx - 2 * b, b, b), o * CFrame.new(0, -(sy / 2 - b / 2), b / 2) * CFrame.Angles(0, 0, math.pi), shade(tone, -0.05), props)
	Build.wedge(model, nm, V3(sy - 2 * b, b, b), o * CFrame.new(sx / 2 - b / 2, 0, b / 2) * CFrame.Angles(0, 0, -math.pi / 2), tone, props)
	Build.wedge(model, nm, V3(sy - 2 * b, b, b), o * CFrame.new(-(sx / 2 - b / 2), 0, b / 2) * CFrame.Angles(0, 0, math.pi / 2), tone, props)
	return 5
end
Hokage.bevelRock = bevelRock

-- Corps du relief : la COUCHE DE RECUL (paroi sombre en ardoise, loin derrière les rochers : les
-- joints et les creux autour des têtes), qui suit le contour en dôme, et le sommet herbeux en
-- retrait.
local function cliffBody(model: Model, cf: CFrame, rng: Random)
	local reach = Hokage.Reach
	local depth = Hokage.Depth
	local colW = 20
	local x = -reach
	local k = 0
	while x < reach do
		local x0 = x + colW / 2
		local top = math.max(topAt(x0) - 6, 6)
		k += 1
		Build.part(
			model,
			"Paroi",
			V3(colW + 2, top, depth - 14),
			cf * CFrame.new(x0, top / 2, 14 + (depth - 14) / 2) * CFrame.Angles(0, rng:NextNumber(-0.015, 0.015), 0),
			shade(JOINT, rng:NextNumber(-0.04, 0.04)),
			{ Material = CARVE_MAT }
		)
		if top > 20 then
			Build.part(
				model,
				"Sommet",
				V3(colW + 6, 5, depth - 30),
				cf * CFrame.new(x0, top + 1, 30 + (depth - 30) / 2) * CFrame.Angles(0, rng:NextNumber(-0.03, 0.03), rng:NextNumber(-0.03, 0.03)),
				shade(GRASS, rng:NextNumber(-0.05, 0.04)),
				{ Material = Enum.Material.Grass }
			)
		end
		if k % 3 == 0 and top > 60 then
			Core.ellipsoid(
				model,
				"SommetBosse",
				V3(colW * 3.2, 18, 80),
				cf * CFrame.new(x0 + rng:NextNumber(-8, 8), top + 2, 80 + rng:NextNumber(0, 30)),
				GRASS_LIGHT,
				Enum.Material.Grass
			)
		end
		x += colW
	end
end

-- Paroi : un amas de ROCHERS ARRONDIS empilés (sans rangées), en trois tailles, avec des joints
-- sombres. Autour des visages, les rochers avancent davantage et forment le cadre en creux d'où
-- sortent les têtes ; le long du contour, une crête de rochers qui rapetissent vers les épaules
-- dessine la silhouette bombée.
local function cliffFace(model: Model, cf: CFrame, rng: Random)
	local reach = Hokage.Reach
	local base = Hokage.BaseHeight
	local function frameOf(d: number): number
		return math.clamp((1.5 - d) / 0.5, 0, 1) -- 1 contre une tête, 0 au large
	end
	-- 1) la masse : pierres biseautées de 18 à 32 studs, posées en quinconce irrégulier
	local y = base + 4
	local row = 0
	while y < Hokage.Height + 10 do
		row += 1
		local rowH = rng:NextNumber(26, 34)
		local x = -reach + 4 - (row % 2) * 16
		while x < reach - 4 do
			local g = 1 - shoulderAt(x) * 0.5
			local w = rng:NextNumber(28, 44) * g
			local px, py = x + w / 2 + rng:NextNumber(-3, 3), y + rng:NextNumber(-5, 5)
			local h = rowH * rng:NextNumber(0.9, 1.3) * g
			local d = nearHead(px, py, math.min(w, h) * 0.3)
			if d >= 1.0 and py < topAt(px) - h * 0.45 and py > 6 then
				local front = lean(py) - rng:NextNumber(5, 12) - frameOf(d) * rng:NextNumber(8, 16)
				bevelRock(model, cf, rng, px, py, w * 1.08, h, front)
			end
			x += w * rng:NextNumber(0.7, 0.84)
		end
		y += rowH * 0.78
	end
	-- 1 bis) fond : pierres en retrait qui comblent les grands trous entre les têtes (les têtes
	-- passent devant ; juste autour de chaque visage, la niche sombre reste visible)
	local filled = 0
	for _ = 1, 260 do
		local px = rng:NextNumber(-Hokage.Width / 2 + 20, Hokage.Width / 2 - 20)
		local py = rng:NextNumber(base + 20, topAt(px) - 30)
		local w = rng:NextNumber(22, 32)
		local d = nearHead(px, py, w * 0.3)
		if d > 0.86 and d < 1.0 and filled < 16 then
			filled += 1
			bevelRock(model, cf, rng, px, py, w, w * rng:NextNumber(0.75, 0.95), lean(py) - rng:NextNumber(1, 5))
		end
	end
	-- 2) rochers arrondis plus en avant, qui cassent la masse (et cachent les joints droits)
	for _ = 1, 14 do
		local px = rng:NextNumber(-reach + 30, reach - 30)
		local py = rng:NextNumber(base + 10, topAt(px) - 14)
		local r = rng:NextNumber(9, 14) * (1 - shoulderAt(px) * 0.4)
		if nearHead(px, py, r * 0.6) > 1.0 then
			facetRock(model, cf, rng, px, py, r, lean(py) - rng:NextNumber(16, 22), 1.6, true)
		end
	end
	-- 3) collerette sous chaque menton : la tête sort de la roche (sous le menton, jamais devant)
	for _, h in Hokage.Heads do
		local u = U * (h.scale or 1)
		for k = -2, 2 do
			local px = h.x + k * 1.3 * u + rng:NextNumber(-2, 2)
			local py = h.y - (6.9 - math.abs(k) * 0.35) * u + rng:NextNumber(-2, 2)
			if py > base then
				bevelRock(model, cf, rng, px, py, rng:NextNumber(18, 24), rng:NextNumber(13, 17), lean(py) - rng:NextNumber(20, 28))
			end
		end
	end
	-- 4) gros rochers arrondis serrés contre les têtes : le cadre en creux du monument
	local placed = 0
	for _ = 1, 400 do
		if placed >= 18 then
			break
		end
		local px = rng:NextNumber(-reach + 40, reach - 40)
		local py = rng:NextNumber(base + 20, topAt(px) - 16)
		local r = rng:NextNumber(13, 19)
		local d = nearHead(px, py, r * 0.6)
		if d > 1.0 and d < 1.3 then
			if placed % 3 == 0 then
				facetRock(model, cf, rng, px, py, r, lean(py) - rng:NextNumber(20, 28), nil, true)
			else
				bevelRock(model, cf, rng, px, py, r * rng:NextNumber(1.8, 2.2), r * rng:NextNumber(1.5, 1.9), lean(py) - rng:NextNumber(20, 28))
			end
			placed += 1
		end
	end
	-- 5) CRÊTE : rochers arrondis le long du contour, de plus en plus petits vers les épaules ;
	-- ils dessinent la silhouette bombée et cachent le haut de la paroi
	local x = -reach + 6
	while x < reach - 6 do
		local f = shoulderAt(x)
		local r = rng:NextNumber(11, 15) * (1 - f * 0.55)
		local top = topAt(x)
		local py = top - r * 0.65
		if py > 8 and nearHead(x, py, r * 0.5) > 1.0 then
			bevelRock(model, cf, rng, x, py, r * rng:NextNumber(1.7, 2.1), r * rng:NextNumber(1.4, 1.7), lean(py) - rng:NextNumber(3, 9), "Crete")
		end
		local slope = (topAt(x + 2) - topAt(x - 2)) / 4
		x += r * 1.45 / math.sqrt(1 + slope * slope)
	end
	-- 6) creux sombre derrière chaque tête (couche de recul) : elle sort d'une niche de la roche
	for _, h in Hokage.Heads do
		local e = EXTENT[h.style] or EXTENT.longs
		local u = U * (h.scale or 1)
		local bottom = h.y + (e[3] - 0.5) * u
		local top = math.min(h.y + e[2] * u, topAt(h.x) - 14)
		Build.deco(model, "Niche", V3(e[1] * 2.1 * u, top - bottom, 10), cf * CFrame.new(h.x, (top + bottom) / 2, lean(h.y) + 9), shade(JOINT, -0.04), {
			Material = CARVE_MAT,
		})
	end
end

-- Emblème de la feuille gravé sur un gros rocher arrondi (en bas à gauche vu du village, à côté de Tobirama).
local function emblem(model: Model, cf: CFrame)
	local em = Hokage.Emblem
	-- médaillon taillé : un disque de pierre épais, bordé d'un anneau en relief
	local c = cf * CFrame.new(em.x, em.y, lean(em.y) - 16)
	local disc = Build.deco(model, "Emblème", V3(12, 64, 64), c * CFrame.Angles(0, math.pi / 2, 0), ROCK, { Material = CARVE_MAT })
	disc.Shape = Enum.PartType.Cylinder
	local rim = Build.deco(model, "Emblème", V3(8, 72, 72), c * CFrame.new(0, 0, 4) * CFrame.Angles(0, math.pi / 2, 0), shade(ROCK, -0.08), { Material = ROCK_MAT })
	rim.Shape = Enum.PartType.Cylinder
	local face = c * CFrame.new(0, 0, -6.2)
	local function groove(a: Vector3, b: Vector3, w: number)
		local mid = (a + b) / 2
		local d = b - a
		Build.deco(model, "Gravure", V3(d.Magnitude + w * 0.6, w, 1.2), face * CFrame.new(mid) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)), DEEP, {
			Material = CARVE_MAT,
			CastShadow = false,
		})
	end
	-- spirale de la feuille (un tour et quart, qui s'élargit) puis la pointe de la feuille
	local function spiral(t: number): Vector3
		local r = 3 + t * 3.6
		return V3(math.cos(t + 1.2) * r, math.sin(t + 1.2) * r, 0)
	end
	local steps = 14
	local last = spiral(0)
	for k = 1, steps do
		local p = spiral(k / steps * math.pi * 2.6)
		groove(last, p, 2.6)
		last = p
	end
	groove(last, last + V3(10, -12, 0), 2.6)
	groove(last + V3(10, -12, 0), last + V3(-2, -6, 0), 2.6)
	-- anneau gravé autour
	for k = 0, 15 do
		local a0, a1 = k / 16 * math.pi * 2, (k + 1) / 16 * math.pi * 2
		groove(V3(math.cos(a0) * 28, math.sin(a0) * 28, 0), V3(math.cos(a1) * 28, math.sin(a1) * 28, 0), 1.6)
	end
end

-- Pied du relief : une rangée IRRÉGULIÈRE de pierres émoussées (8 à 22 studs de haut, basculées,
-- enfoncées inégalement : aucune arête droite ne traverse la largeur), puis des éboulis qui
-- s'étalent devant et autour des épaules (pied évasé).
local function cliffBase(model: Model, cf: CFrame, rng: Random)
	local reach = Hokage.Reach
	local x = -reach + 4
	while x < reach - 4 do
		local w = rng:NextNumber(14, 26) * (1 - shoulderAt(x) * 0.3)
		local h = rng:NextNumber(8, 22)
		bevelRock(model, cf, rng, x + w / 2, h / 2 - rng:NextNumber(1, 5), w, h, -rng:NextNumber(4, 14), "Socle")
		x += w * rng:NextNumber(0.8, 0.95)
	end
	-- éboulis : devant la paroi, et en éventail au pied des épaules
	for k = 1, 14 do
		local px, pz
		if k <= 8 then
			px, pz = rng:NextNumber(-reach + 30, reach - 30), rng:NextNumber(-36, -18)
		else
			local s = k % 2 == 0 and 1 or -1
			local a = rng:NextNumber(0, math.pi / 2)
			px, pz = s * (reach - 30 + math.sin(a) * rng:NextNumber(20, 46)), -math.cos(a) * rng:NextNumber(14, 40) + 20
		end
		Nature.rock(model, (cf * CFrame.new(px, 0, pz)).Position, rng:NextNumber(3.5, 9), {
			rng = rng,
			color = shade(ROCK, rng:NextNumber(-0.08, 0.04)),
			slot = "RocherFalaise",
			moss = MOSS,
		})
	end
end

-- Végétation : arbres (version lointaine, peu de pièces) et buissons sur le sommet et les épaules.
local function cliffGreenery(model: Model, cf: CFrame, rng: Random)
	local reach = Hokage.Reach
	local function clear(x: number): boolean
		for _, h in Hokage.Heads do
			local e = EXTENT[h.style] or EXTENT.longs
			local u = U * (h.scale or 1)
			if h.y + e[2] * u > topAt(x) - 24 and math.abs(x - h.x) < e[1] * u + 6 then
				return false
			end
		end
		return true
	end
	local count = 26
	for i = 1, count do
		local x = -reach + 40 + (i - 0.5) / count * (reach * 2 - 80) + rng:NextNumber(-8, 8)
		local deep = i % 3 == 0
		local z = deep and rng:NextNumber(50, 110) or rng:NextNumber(30, 44)
		if (clear(x) or deep) and topAt(x) > 40 then
			local species = rng:NextNumber() < 0.55 and "ArbreFeuillu" or "Sapin"
			Nature.tree(species, model, (cf * CFrame.new(x, topAt(x) - 3, z)).Position, {
				rng = rng,
				height = rng:NextNumber(36, 58) * (1 - shoulderAt(x) * 0.3),
				palette = "foret",
				detail = "far",
			})
		end
	end
	-- buissons le long de la crête et sur les épaules
	for _ = 1, 14 do
		local x = rng:NextNumber(-reach + 20, reach - 20)
		if clear(x) and topAt(x) > 16 then
			Nature.bush(model, (cf * CFrame.new(x, topAt(x) - 4, rng:NextNumber(24, 34))).Position, {
				rng = rng,
				height = rng:NextNumber(7, 11),
				palette = "foret",
			})
		end
	end
end

-- Construit la montagne complète au repère `cf` (pied au centre, -Z local vers le village).
function Hokage.mountain(parent: Instance, cf: CFrame, rng: Random): Model
	local model = Core.slot(parent, "MontagneDesChefs", cf, Hokage.Height + 30)
	pcall(function()
		model.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	end)
	cliffBody(model, cf, rng)
	cliffFace(model, cf, rng)
	emblem(model, cf)
	cliffBase(model, cf, rng)
	local heads = Instance.new("Model")
	heads.Name = "Tetes"
	heads.Parent = model
	local total = 0
	for _, h in Hokage.Heads do
		local headModel = Instance.new("Model")
		headModel.Name = h.name
		headModel.Parent = heads
		-- la tête sort de la paroi et penche un peu vers le village (regard vers le bas)
		local u = U * (h.scale or 1)
		local headCF = cf * CFrame.new(h.x, h.y, lean(h.y) - 1.4 * u) * CFrame.Angles(-0.06, 0, 0)
		local count = Hokage.head(headModel, headCF, h.style, u)
		headModel:SetAttribute("Pieces", count)
		total += count
	end
	heads:SetAttribute("Pieces", total)
	cliffGreenery(model, cf, rng)
	-- seules la paroi, le sommet et le pied gardent une collision ; tout le reste (sculptures,
	-- rochers, végétation) n'est ni touché ni interrogé par le moteur
	local solid = { Paroi = true, Sommet = true, Socle = true }
	local parts = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			d.CanTouch = false
			if not solid[d.Name] then
				d.CanCollide = false
				d.CanQuery = false
			end
		end
	end
	model:SetAttribute("Pieces", parts)
	return model
end

return Hokage
