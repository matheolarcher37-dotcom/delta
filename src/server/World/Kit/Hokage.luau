-- Kit/Hokage : la MONTAGNE DES CHEFS du village ninja (inspirée du mont des Hokages).
--
-- Un grand relief rocheux taillé, comme le monument de référence : 8 TÊTES sculptées en quinconce
-- sur deux rangs, qui remplissent presque tout le relief et se touchent :
--
--        rang du haut :   Hashirama     Hiruzen        Tsunade       Naruto
--        rang du bas  :          Tobirama      Minato         Kakashi        Boruto
--                         (médaillon de la feuille gravé, en bas à gauche)
--
-- La roche : des ROCHERS FACETTÉS (taillés en triangles, à moitié enfoncés) et des blocs
-- anguleux calmes (pavés, coins, roulis de 4 à 14°) en trois tailles, avec des joints sombres ;
-- autour des visages, les rochers avancent davantage et forment le cadre en creux du monument.
-- Un médaillon de pierre porte la spirale de la feuille gravée.
--
-- Les VISAGES sont des surfaces taillées en facettes, comme une sculpture dégrossie au ciseau :
-- un maillage de 110 triangles (deux coins par triangle, Hokage.triangle) qui dessine front,
-- arcades, orbites, nez triangulaire, pommettes, bouche réduite à un trait fin, menton carré et
-- mâchoire. Expression calme. Les cheveux : coiffe facettée (épis : masse + épis plats et effilés
-- qui se dressent ; cheveux longs : raie creusée en V, sillons gravés, grands rideaux facettés
-- jusqu'aux épaules), bandeaux plats avec plaque gravée.
--
-- Tout est dans la même pierre gris ardoise (falaise et têtes, écart de teinte faible) : ce sont
-- les ombres qui dessinent les visages. Le modèle est un emplacement remplaçable (DecorSlot
-- "MontagneDesChefs") : un modèle du même nom rangé dans ServerStorage > ModelesDeco le remplace.
--
-- Budget : ≈ 5 600 pièces en tout, dont ≈ 3 100 pour les 8 têtes (360 à 430 chacune) ; arbres du
-- sommet en version lointaine (clones). Le modèle est en LevelOfDetail « StreamingMesh »
-- (simplifié de loin par le moteur).

local Build = require(script.Parent.Parent.Parent.Modules.Build)
local Core = require(script.Parent.Core)
local Nature = require(script.Parent.Nature)

local Hokage = {}

local rgb = Color3.fromRGB
local V3 = Vector3.new
local shade = Core.shade

-- Palette : une seule famille gris ardoise (± 8) pour la falaise et les têtes.
local ROCK = rgb(120, 122, 128)
local FACE = rgb(126, 128, 134)
local HAIR = rgb(116, 118, 125)
local JOINT = rgb(96, 98, 105) -- joints et creux entre les blocs
local DEEP = rgb(62, 64, 70) -- traits gravés : bouche, symbole
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
Hokage.Height = 240
Hokage.Depth = 150
Hokage.BaseHeight = 22 -- socle taillé (≤ 10 % de la hauteur)

-- Unité de sculpture : une tête mesure ≈ 10 unités du menton au sommet du crâne (≈ 100 studs),
-- soit ≈ 45 % de la hauteur du relief par rang, comme sur le monument.
local U = 10
Hokage.Unit = U

-- Les 8 chefs : position (x, y = hauteur des yeux) sur le relief, coiffure, échelle.
-- (x local positif = à gauche vu depuis le village : Hashirama est à gauche, Naruto à droite.)
Hokage.Heads = {
	{ name = "Hashirama", x = 172, y = 170, style = "longs" },
	{ name = "Hiruzen", x = 58, y = 178, style = "epis" },
	{ name = "Tsunade", x = -58, y = 172, style = "raie" },
	{ name = "Naruto", x = -172, y = 166, style = "bandeau" },
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
}

local function crown(ctx: Ctx, o: CrownSpec)
	for k = 0, o.n - 1 do
		local f = o.n > 1 and k / (o.n - 1) or 0.5
		local a = o.a0 + (o.a1 - o.a0) * f
		local root, normal = capPoint(a, o.p or 0.45, o.inset)
		local da = a * (o.tilt or 1) + (o.lean or 0)
		local len = o.len - math.abs(math.sin(a)) * (o.fall or 0) + (o.wave and math.sin(k * 2.3 + 0.7) * o.wave or 0)
		local out = normal + V3(0, 0, -(o.face or 0.8))
		lock(ctx, root, V3(math.sin(da), math.cos(da), o.back or 0.35), len, o.w, o.t or 0.42, out)
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
	ctx.count += 3
	Build.deco(ctx.model, "Bandeau", V3(5.0, bh, 0.5) * u, band * CFrame.new(0, 0, zc * u) * CFrame.Angles(zForce and 0 or FRONT_TILT, 0, 0), HAIR, {
		Material = CARVE_MAT,
	})
	for _, s in { -1, 1 } do
		Build.deco(
			ctx.model,
			"Bandeau",
			V3(2.4, bh * 0.95, 0.55) * u,
			band * CFrame.new(s * 3.05 * u, 0, (zc + 0.85) * u) * CFrame.Angles(0, -s * 0.8, 0),
			HAIR,
			{ Material = CARVE_MAT }
		)
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
	soft: boolean?, -- traits plus fins (visage féminin, jeune)
	mask: boolean?, -- masque de tissu sur le bas du visage
	hideEye: number?, -- œil caché par le bandeau (-1 ou 1)
	ears: boolean?,
	age: boolean?, -- rides du front et plis du nez
}

-- Position d'un sommet (côté `s`), ajustée selon le visage.
local function faceVertex(name: string, s: number, o: FaceOptions): Vector3
	local p = FACE_VERTS[name]
	local x, y, z = p[1], p[2], p[3]
	local jw = o.jaw or 1
	if y < -1.8 and x > 0 then
		x *= jw -- mâchoire plus large ou plus fine
	end
	if name == "r_bo" then
		y -= o.brow or 0.04
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

local function face(ctx: Ctx, o: FaceOptions)
	local u = ctx.u
	local thick = 1.6
	-- masse intérieure (sombre) et côtés de la tête : elle bouche l'arrière du masque facetté
	E(ctx, "Crane", 6.2, 6.8, 7.0, at(ctx, 0, 1.6, 0.9))
	B(ctx, "Noyau", 5.2, 6.4, 4.0, at(ctx, 0, -1.0, 0.4), shade(FACE, -0.1))
	for _, s in { -1, 1 } do
		B(ctx, "Cote", 0.6, 4.6, 3.0, at(ctx, s * 2.75, -0.9, -0.2, 0, -s * 0.15, 0))
	end
	-- surface du visage
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
				ctx.count += triangle(ctx.model, wa, wb, wc, ctx.cf:VectorToWorldSpace(n), thick, FACE)
			end
		end
	end
	-- yeux clos gravés : un trait fin en arc (deux segments) au fond de l'orbite, sans relief ;
	-- la bouche est aussi un trait fin
	local lid = shade(FACE, -0.3)
	for _, s in { -1, 1 } do
		if o.hideEye ~= s then
			local w = o.soft and 0.5 or 0.56
			for _, k in { -1, 1 } do
				B(ctx, "Oeil", w, 0.08, 0.12, at(ctx, s * 1.3 + k * w * 0.46, 0.1, -3.0, 0, -s * 0.2, -k * 0.1), lid)
			end
		end
	end
	if o.mask then
		B(ctx, "Ourlet", 3.6, 0.12, 0.25, at(ctx, 0, -0.62, -3.35), shade(FACE, -0.12))
	else
		B(ctx, "Trait", o.soft and 1.5 or 1.7, 0.09, 0.2, at(ctx, 0, -2.78, -3.22), DEEP)
	end
	if o.age then
		for _, y in { 2.45, 2.85 } do
			B(ctx, "Ride", 2.4, 0.08, 0.14, at(ctx, 0, y, -3.12 - (2.85 - y) * 0.2, 0.3, 0, 0), shade(FACE, -0.16))
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
	{ { 0, 4.65, -2.55 }, { 1.1, 4.45, -2.42 }, { 2.25, 4.1, -2.0 }, { 3.3, 3.0, -1.42 }, { 3.75, 1.8, -1.0 } },
	{ { 0, 5.7, -0.75 }, { 1.2, 5.45, -0.68 }, { 2.35, 5.05, -0.5 }, { 3.45, 3.8, -0.35 }, { 3.95, 2.1, -0.2 } },
	{ { 0, 5.85, 1.4 }, { 1.25, 5.75, 1.4 }, { 2.5, 5.1, 1.4 }, { 3.65, 3.8, 1.4 }, { 4.05, 2.1, 1.4 } },
}

local function spikes(ctx: Ctx, len: number, o: { lean: number?, fall: number?, wide: number?, n: number? }?)
	local opt = o or {}
	local lean = opt.lean or 0
	local wide = opt.wide or 1.5
	-- masse facettée de la chevelure (les arêtes alternées dessinent des mèches couchées)
	surface(ctx, SPIKY_TOP, V3(0, 1.5, 0.8), 2.2)
	-- mèches couchées vers l'arrière sur le devant de la masse
	for k = -2, 2 do
		local x = k * 0.95
		lock(ctx, V3(x, 3.35 - math.abs(k) * 0.12, -3.2 + math.abs(k) * 0.12), V3(x * 0.12 + lean * 0.4, 1, 0.42), len * 0.75, 1.9, 0.45, V3(x * 0.2, 0.5, -1), 0.3)
	end
	crown(ctx, {
		n = opt.n or 8,
		a0 = -wide + math.min(lean, 0) * 0.5,
		a1 = wide + math.max(lean, 0) * 0.5,
		p = 0.18,
		len = len,
		fall = opt.fall or 0.4,
		w = 2.4,
		back = 0.4,
		lean = lean,
		tilt = 0.78,
		face = 0.8,
		wave = 0.3,
	})
	crown(ctx, { n = 6, a0 = -wide * 0.8, a1 = wide * 0.8, p = -0.3, len = len * 1.1, w = 2.5, back = 0.5, lean = lean, tilt = 0.75, face = 1.0, wave = 0.3 })
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
	surface(ctx, LONG_TOP, V3(0, 1.5, 0.8), 2.2)
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
					JOINT,
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

-- Hashirama : longs cheveux raides séparés au milieu, jusqu'aux épaules.
STYLES.longs = function(ctx)
	face(ctx, { jaw = 1.03, ears = false })
	longHair(ctx, 10.4, 0.05)
end

-- Hiruzen : front dégagé et ridé, cheveux dressés en flamme, bouc effilé.
STYLES.epis = function(ctx)
	face(ctx, { brow = 0.07, age = true })
	spikes(ctx, 2.7, { fall = 1.0, wide = 1.25, n = 7 })
	-- bouc : une mèche qui descend du menton
	lock(ctx, V3(0, -3.95, -3.1), V3(0, -1, 0.15), 2.2, 1.4, 0.5, V3(0, 0, -1), 0.3)
end

-- Tsunade : cheveux lisses séparés au milieu, longs rideaux, losange plat sur le front.
STYLES.raie = function(ctx)
	face(ctx, { soft = true, jaw = 0.92, ears = false })
	longHair(ctx, 9.4, 0.25)
	for _, s in { -1, 1 } do
		lock(ctx, V3(s * 0.35, 3.25, -3.12), V3(s, -0.55, 0.05), 2.4, 1.7, 0.4, V3(0, 0.4, -1), 0.25)
	end
	B(ctx, "Losange", 0.42, 0.42, 0.12, at(ctx, 0, 1.75, foreheadZ(1.75) - 0.02, FRONT_TILT, 0, math.rad(45)), DEEP)
end

-- Naruto : épis en bataille au-dessus du bandeau, frange en pointes qui retombe dessus, mèches le
-- long des joues.
STYLES.bandeau = function(ctx)
	face(ctx, { jaw = 0.98 })
	spikes(ctx, 3.0, { wide = 1.6, n = 9 })
	bandBangs(ctx, 5, 2.0, 2.35, 1.35)
	for _, s in { -1, 1 } do
		lock(ctx, V3(s * 2.95, 2.9, -1.3), V3(s * 0.12, -1, -0.15), 3.2, 1.6, 0.42, V3(s * 0.5, 0, -1))
	end
	headband(ctx, 2.35)
end

-- Tobirama : cheveux courts hérissés, bandeau à plaque et protège-oreilles plats.
STYLES.plaque = function(ctx)
	face(ctx, { brow = -0.05, jaw = 1.05, ears = false })
	spikes(ctx, 2.2, { wide = 1.5 })
	bandBangs(ctx, 4, 1.7, 2.4, 1.9)
	headband(ctx, 2.4)
	for _, s in { -1, 1 } do
		B(ctx, "Garde", 0.5, 2.8, 2.4, at(ctx, s * 3.3, 0.4, 0.2, 0, -s * 0.15, 0), HAIR)
	end
end

-- Minato : crinière de grandes pointes, longue frange en pointes, longues mèches qui encadrent le
-- visage jusqu'à la mâchoire.
STYLES.meches = function(ctx)
	face(ctx, { jaw = 0.98 })
	spikes(ctx, 3.3, { fall = -0.4, wide = 1.7, n = 9 })
	bangs(ctx, 5, 2.2, 1.35, 1.7)
	for _, s in { -1, 1 } do
		lock(ctx, V3(s * 2.9, 3.1, -1.5), V3(s * 0.12, -1, -0.2), 5.4, 1.7, 0.42, V3(s * 0.5, 0, -1))
	end
end

-- Kakashi : grands épis penchés d'un côté, bandeau incliné sur un œil, masque.
STYLES.penche = function(ctx)
	face(ctx, { mask = true, hideEye = -1 })
	spikes(ctx, 3.8, { lean = -0.6, fall = 0.9, wide = 1.3 })
	bangs(ctx, 3, 1.6, 2.7, 1.8, -0.7)
	headband(ctx, 1.3, 0.42, 1.2, -3.72)
end

-- Boruto : épis plus courts, une longue mèche qui tombe sur le côté, bandeau sur le front.
STYLES.jeune = function(ctx)
	face(ctx, { soft = true, jaw = 0.95 })
	spikes(ctx, 2.6, { wide = 1.5 })
	bandBangs(ctx, 4, 1.8, 2.35, 1.5)
	lock(ctx, V3(1.2, 3.9, -2.3), V3(0.35, -1, -0.3), 4.4, 1.6, 0.4, V3(0.3, 0.2, -1))
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

-- Hauteur du sommet du relief en `x` (coins arrondis, bosselé).
local function topAt(x: number): number
	local t = x / (Hokage.Width / 2)
	return Hokage.Height - 14 * t * t - 60 * t ^ 8 + 5 * math.sin(x * 0.05) + 3 * math.cos(x * 0.13)
end
Hokage.topAt = topAt

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

-- Un bloc de roche anguleux (pavé, coin ou coin d'angle), roulis de 5 à 25°, faible bascule
-- (sa face avant reste tournée vers le village), à moitié enfoncé : sa face avant arrive à
-- `front` (z local, négatif = devant la paroi). `cf` = repère du relief.
local function rockBlock(model: Model, cf: CFrame, rng: Random, px: number, py: number, sx: number, sy: number, front: number)
	local depth = math.max(sx, sy) * 0.8 + 10
	local function tilt(lo: number, hi: number): number
		local a = math.rad(rng:NextNumber(lo, hi))
		return rng:NextNumber() < 0.5 and -a or a
	end
	local tone = shade(TONES[rng:NextInteger(1, #TONES)], rng:NextNumber(-0.04, 0.04))
	local where = cf * CFrame.new(px, py, front + depth / 2)
	local roll = rng:NextNumber()
	local props = { Material = ROCK_MAT, CanCollide = false, CanQuery = false }
	if roll < 0.66 then
		local rot = CFrame.Angles(tilt(0, 2.5), tilt(0, 3), tilt(4, 14))
		Build.deco(model, "Bloc", V3(sx, sy, depth), where * rot, tone, { Material = ROCK_MAT })
		-- arête du haut abattue : un coin posé sur le dessus, la pente vers le village
		if rng:NextNumber() < 0.4 then
			local h = sy * rng:NextNumber(0.25, 0.4)
			local d = math.min(depth * 0.5, sy * 0.8)
			Build.wedge(model, "Bloc", V3(sx * 0.98, h, d), where * rot * CFrame.new(0, sy / 2 + h / 2 - 0.2, -depth / 2 + d / 2), shade(tone, 0.05), props)
		end
	elseif roll < 0.9 then
		-- coin : pente tournée vers le haut ou un côté (arête vive)
		local quarter = ({ 0, math.pi / 2, -math.pi / 2 })[rng:NextInteger(1, 3)]
		local size = quarter == 0 and V3(sx, sy, depth) or V3(sy, sx, depth)
		Build.wedge(model, "Bloc", size, where * CFrame.Angles(0, 0, quarter + tilt(4, 14)) * CFrame.Angles(tilt(0, 3), 0, 0), tone, props)
	else
		local part = Instance.new("CornerWedgePart")
		part.Name = "Bloc"
		part.Size = V3(sx, sy, depth)
		part.CFrame = where * CFrame.Angles(0, rng:NextInteger(0, 1) * math.pi / 2, tilt(4, 14))
		part.Color = tone
		part.Material = ROCK_MAT
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = model
	end
	-- mousse sur le dessus de quelques blocs du haut
	if py > Hokage.Height * 0.75 and rng:NextNumber() < 0.15 then
		Build.deco(model, "Mousse", V3(sx * 0.7, 1.4, depth * 0.4), cf * CFrame.new(px, py + sy * 0.45, front + depth * 0.25), MOSS, { Material = Enum.Material.Grass })
	end
end
Hokage.rockBlock = rockBlock

-- Rocher facetté (taillé en triangles) à moitié enfoncé dans la paroi : base à cinq côtés dans
-- la roche, une couronne de facettes, un sommet. `front` = avancée du sommet (z local, négatif =
-- devant la paroi). Renvoie le nombre de pièces.
local function facetRock(model: Model, cf: CFrame, rng: Random, px: number, py: number, r: number, front: number, deep: number?): number
	local tone = shade(TONES[rng:NextInteger(1, #TONES)], rng:NextNumber(-0.05, 0.02))
	local center = V3(px, py, front + r * 1.1)
	local a0 = rng:NextNumber(0, math.pi * 2)
	local base, mid = {}, {}
	for k = 0, 4 do
		local a = a0 + k / 5 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local rr = r * rng:NextNumber(0.9, 1.15)
		base[k + 1] = V3(px + math.cos(a) * rr, py + math.sin(a) * rr * 0.8, front + r * (deep or 0.85))
		local am = a + math.pi / 5 + rng:NextNumber(-0.15, 0.15)
		local rm = r * rng:NextNumber(0.5, 0.68)
		mid[k + 1] = V3(px + math.cos(am) * rm, py + math.sin(am) * rm * 0.8, front + r * rng:NextNumber(0.2, 0.35))
	end
	local apex = V3(px + rng:NextNumber(-0.2, 0.2) * r, py + rng:NextNumber(0, 0.25) * r, front)
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
	for k = 1, 5 do
		local k2 = k % 5 + 1
		tri(base[k], base[k2], mid[k])
		tri(base[k2], mid[k2], mid[k])
		tri(mid[k], mid[k2], apex)
	end
	return count
end
Hokage.facetRock = facetRock

-- Corps du relief : un mur de roche sombre (il sert de « joint » entre les blocs), sommet
-- herbeux, flancs en gradins de gros blocs qui reculent.
local function cliffBody(model: Model, cf: CFrame, rng: Random)
	local half = Hokage.Width / 2
	local depth = Hokage.Depth
	local cols = 10
	local colW = Hokage.Width / cols
	for c = 0, cols - 1 do
		local x0 = -half + (c + 0.5) * colW
		local top = topAt(x0)
		Build.part(
			model,
			"Paroi",
			V3(colW + 4, top, depth - 14),
			cf * CFrame.new(x0, top / 2, 14 + (depth - 14) / 2) * CFrame.Angles(0, rng:NextNumber(-0.02, 0.02), 0),
			shade(JOINT, rng:NextNumber(-0.03, 0.04)),
			{ Material = ROCK_MAT }
		)
		-- sommet herbeux et bosse d'herbe en retrait
		Build.part(
			model,
			"Sommet",
			V3(colW + 8, 5, depth - 14),
			cf * CFrame.new(x0, top + 1, 20 + (depth - 14) / 2) * CFrame.Angles(0, rng:NextNumber(-0.03, 0.03), rng:NextNumber(-0.03, 0.03)),
			shade(GRASS, rng:NextNumber(-0.05, 0.04)),
			{ Material = Enum.Material.Grass }
		)
		Core.ellipsoid(
			model,
			"SommetBosse",
			V3(colW * 1.4, 18, 80),
			cf * CFrame.new(x0 + rng:NextNumber(-8, 8), top + 2, 80 + rng:NextNumber(0, 30)),
			GRASS_LIGHT,
			Enum.Material.Grass
		)
	end
	-- flancs : gradins qui descendent et reculent, habillés de blocs anguleux et d'herbe
	for _, s in { -1, 1 } do
		local edge = topAt(s * half)
		for k = 0, 3 do
			local w = rng:NextNumber(30, 40)
			local h = edge * (0.86 - k * 0.2)
			local x = s * (half - 6 + k * 24 + w / 2)
			local z = 14 + k * 16
			Build.part(
				model,
				"Flanc",
				V3(w, h, depth - k * 20),
				cf * CFrame.new(x, h / 2, z + (depth - k * 20) / 2) * CFrame.Angles(0, s * rng:NextNumber(0.05, 0.2), 0),
				shade(JOINT, 0.05),
				{
					Material = ROCK_MAT,
				}
			)
			Build.part(
				model,
				"FlancHerbe",
				V3(w + 4, 4, depth - k * 20 - 6),
				cf * CFrame.new(x, h + 1, z + 4 + (depth - k * 20 - 6) / 2),
				shade(GRASS, rng:NextNumber(-0.06, 0.03)),
				{
					Material = Enum.Material.Grass,
				}
			)
			local y = 8
			while y < h - 8 do
				local bh = rng:NextNumber(16, 26)
				rockBlock(model, cf, rng, x + rng:NextNumber(-4, 4), y + bh / 2, w * rng:NextNumber(0.6, 0.9), bh, z - rng:NextNumber(4, 10))
				y += bh * 0.9
			end
		end
	end
end

-- Paroi : maçonnerie naturelle de gros blocs anguleux en trois tailles, serrés, avec des joints
-- sombres (la paroi derrière). Autour des visages, les blocs avancent davantage et forment un
-- cadre en creux d'où sortent les têtes.
local function cliffFace(model: Model, cf: CFrame, rng: Random)
	local half = Hokage.Width / 2
	local base = Hokage.BaseHeight
	local facetShare = 0.7
	local function place(px: number, py: number, sx: number, sy: number)
		local d = nearHead(px, py, math.min(sx, sy) * 0.3)
		if d < 1.0 or py > topAt(px) - sy * 0.3 then
			return
		end
		local frame = math.clamp((1.55 - d) / 0.55, 0, 1) -- 1 contre une tête, 0 au large
		local front = lean(py) - rng:NextNumber(6, 13) - frame * rng:NextNumber(10, 18)
		if rng:NextNumber() < facetShare then
			-- rocher facetté (sa base rejoint la paroi du fond)
			local r = math.max(sx, sy) * rng:NextNumber(0.55, 0.66)
			facetRock(model, cf, rng, px, py, r, front - 2, math.max(0.85, (16 - front) / r))
		else
			rockBlock(model, cf, rng, px, py, sx, sy, front)
		end
	end
	-- 1) gros blocs (26 à 40 studs) en rangées décalées
	local rowH = 24
	local row = 0
	for y = base + 10, Hokage.Height + 4, rowH do
		row += 1
		local x = -half + 6 - (row % 2) * 14
		while x < half - 4 do
			local w = rng:NextNumber(26, 40)
			place(x + w / 2 + rng:NextNumber(-2, 2), y + rng:NextNumber(-3, 3), w * 1.05, rowH * rng:NextNumber(1.0, 1.35))
			x += w
		end
	end
	-- 2) blocs moyens et petits (12 à 22 studs) un peu plus en avant, qui cassent les rangées
	facetShare = 0.25
	for _ = 1, 50 do
		local px = rng:NextNumber(-half + 8, half - 8)
		local py = rng:NextNumber(base + 6, topAt(px) - 6)
		local size = rng:NextNumber(12, 22)
		place(px, py, size * rng:NextNumber(0.9, 1.4), size)
	end
	-- 3) collerette sous chaque menton : la tête sort de la roche (sous le menton, jamais devant)
	for _, h in Hokage.Heads do
		local u = U * (h.scale or 1)
		for k = -2, 2 do
			local px = h.x + k * 1.3 * u + rng:NextNumber(-2, 2)
			local py = h.y - (6.9 - math.abs(k) * 0.35) * u + rng:NextNumber(-2, 2)
			if py > base then
				if k % 2 == 0 then
					facetRock(model, cf, rng, px, py, rng:NextNumber(12, 16), lean(py) - rng:NextNumber(24, 30))
				else
					rockBlock(model, cf, rng, px, py, rng:NextNumber(20, 28), rng:NextNumber(14, 18), lean(py) - rng:NextNumber(20, 26))
				end
			end
		end
	end
	-- 3 bis) gros rochers facettés serrés contre les têtes : le cadre en creux du monument
	local placed = 0
	for _ = 1, 400 do
		if placed >= 22 then
			break
		end
		local px = rng:NextNumber(-half + 20, half - 20)
		local py = rng:NextNumber(base + 20, topAt(px) - 16)
		local r = rng:NextNumber(14, 22)
		local d = nearHead(px, py, r * 0.6)
		if d > 1.0 and d < 1.35 then
			facetRock(model, cf, rng, px, py, r, lean(py) - rng:NextNumber(20, 28))
			placed += 1
		end
	end
	-- 4) gros éperons anguleux dans les coins du haut (trois blocs qui se chevauchent)
	for _, spot in { { half - 28, 192 }, { -half + 30, 188 } } do
		for k = 0, 2 do
			local px, py = spot[1] + rng:NextNumber(-14, 14), spot[2] + k * 16 - 14
			if nearHead(px, py, 16) > 1.0 and py < topAt(px) - 6 then
				rockBlock(model, cf, rng, px, py, rng:NextNumber(30, 42), rng:NextNumber(24, 32), lean(py) - rng:NextNumber(12, 20))
			end
		end
	end
	-- 5) creux sombre derrière chaque tête : elle sort d'une niche de la roche
	for _, h in Hokage.Heads do
		local e = EXTENT[h.style] or EXTENT.longs
		local u = U * (h.scale or 1)
		local cy = h.y + (e[2] + e[3]) / 2 * u
		Build.deco(model, "Niche", V3(e[1] * 1.9 * u, (e[2] - e[3]) * 0.92 * u, 10), cf * CFrame.new(h.x, cy, lean(h.y) + 4), shade(JOINT, 0.02), { Material = ROCK_MAT })
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

-- Socle taillé (≤ 10 % de la hauteur) et éboulis au pied.
local function cliffBase(model: Model, cf: CFrame, rng: Random)
	local half = Hokage.Width / 2
	local x = -half - 4
	while x < half + 4 do
		local w = rng:NextNumber(24, 38)
		local h = rng:NextNumber(Hokage.BaseHeight - 6, Hokage.BaseHeight + 2)
		Build.part(
			model,
			"Socle",
			V3(w - 2, h, 30),
			cf * CFrame.new(x + w / 2, h / 2 - 1, -6 + rng:NextNumber(-3, 3)) * CFrame.Angles(rng:NextNumber(-0.04, 0.04), rng:NextNumber(-0.06, 0.06), rng:NextNumber(-0.04, 0.04)),
			shade(TONES[rng:NextInteger(1, #TONES)], rng:NextNumber(-0.06, 0.0)),
			{ Material = ROCK_MAT }
		)
		x += w
	end
	for _ = 1, 12 do
		Nature.rock(model, (cf * CFrame.new(rng:NextNumber(-half - 10, half + 10), 0, rng:NextNumber(-40, -26))).Position, rng:NextNumber(5, 11), {
			rng = rng,
			color = shade(ROCK, rng:NextNumber(-0.08, 0.04)),
			slot = "RocherFalaise",
			moss = MOSS,
		})
	end
end

-- Végétation : arbres et buissons sur le sommet et les flancs.
local function cliffGreenery(model: Model, cf: CFrame, rng: Random)
	local half = Hokage.Width / 2
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
	local count = 30
	for i = 1, count do
		local x = -half + 10 + (i - 0.5) / count * (Hokage.Width - 20) + rng:NextNumber(-8, 8)
		local deep = i % 3 == 0
		local z = deep and rng:NextNumber(50, 110) or rng:NextNumber(22, 36)
		if clear(x) or deep then
			local species = rng:NextNumber() < 0.55 and "ArbreFeuillu" or "Sapin"
			Nature.tree(species, model, (cf * CFrame.new(x, topAt(x) + 2, z)).Position, {
				rng = rng,
				height = rng:NextNumber(36, 60),
				palette = "foret",
				detail = "far",
			})
		end
	end
	-- arbres et buissons sur les gradins des flancs
	for _, s in { -1, 1 } do
		for k = 0, 3 do
			local x = s * (half + 12 + k * 24)
			local h = topAt(s * half) * (0.86 - k * 0.2)
			if k % 2 == 1 then
				Nature.tree(rng:NextNumber() < 0.5 and "Sapin" or "ArbreFeuillu", model, (cf * CFrame.new(x, h + 2, 40 + k * 16)).Position, {
					rng = rng,
					height = rng:NextNumber(30, 44),
					palette = "foret",
					detail = "far",
				})
			end
			Nature.bush(model, (cf * CFrame.new(x + rng:NextNumber(-6, 6), h + 2, 26 + k * 16)).Position, { rng = rng, height = rng:NextNumber(7, 11), palette = "foret" })
		end
	end
	for _ = 1, 10 do
		local x = rng:NextNumber(-half + 10, half - 10)
		if clear(x) then
			Nature.bush(model, (cf * CFrame.new(x, topAt(x) + 2, rng:NextNumber(16, 24))).Position, {
				rng = rng,
				height = rng:NextNumber(6, 10),
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
	return model
end

return Hokage
