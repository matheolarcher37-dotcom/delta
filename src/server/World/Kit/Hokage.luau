-- Kit/Hokage : la MONTAGNE DES CHEFS du village ninja (inspirée du mont des Hokages).
--
-- Un grand relief rocheux taillé, comme le monument de référence : 8 TÊTES sculptées en quinconce
-- sur deux rangs, qui remplissent presque tout le relief et se touchent :
--
--        rang du haut :   Hashirama     Hiruzen        Tsunade       Naruto
--        rang du bas  :          Tobirama      Minato         Kakashi        Boruto
--                         (emblème de la feuille gravé sur un gros rocher, en bas à gauche)
--
-- La roche est faite de GROS BLOCS ANGULEUX (pavés, coins et pointes inclinés de 5 à 25°, de 12 à
-- 42 studs, à moitié enfoncés, avec des joints sombres) : autour des visages, les blocs avancent
-- davantage et forment un cadre en creux. Quelques gros rochers arrondis seulement.
--
-- Les visages sont des volumes nets et calmes : front, arcade continue en coin, orbites creusées
-- (plus sombres, sans paupière en relief), nez triangulaire, pommettes en facettes, bouche réduite
-- à un trait fin, menton carré, oreilles, cou. Les cheveux sont des MÈCHES PLATES ET EFFILÉES
-- (deux coins dos à dos : base large, pointe fine), plaquées contre le crâne et orientées selon la
-- coiffure ; les cheveux longs sont de grandes plaques plates de chaque côté du visage.
--
-- Tout est dans la même pierre gris ardoise (falaise et têtes, écart de teinte faible) : ce sont
-- les ombres qui dessinent les visages. Le modèle est un emplacement remplaçable (DecorSlot
-- "MontagneDesChefs") : un modèle du même nom rangé dans ServerStorage > ModelesDeco le remplace.
--
-- Budget : ≈ 1 100 pièces en tout (têtes ≈ 55 à 75 pièces chacune), arbres clonés depuis des
-- modèles maîtres. Le modèle est en LevelOfDetail « StreamingMesh » (simplifié de loin).

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
local JOINT = rgb(86, 88, 95) -- joints et creux entre les blocs
local DEEP = rgb(62, 64, 70) -- traits gravés : bouche, symbole
local SOCKET = rgb(98, 100, 107) -- orbites creusées
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
-- +X = à gauche du visage vu de face)
------------------------------------------------------------------------

type Ctx = { model: Model, cf: CFrame, u: number, count: number }

local function at(ctx: Ctx, x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	local u = ctx.u
	return ctx.cf * CFrame.new(x * u, y * u, z * u) * CFrame.Angles(rx or 0, ry or 0, rz or 0)
end

-- Grand volume arrondi (crâne, visage, cou) en unités de sculpture.
local function E(ctx: Ctx, name: string, sx: number, sy: number, sz: number, cf: CFrame, color: Color3?): Part
	ctx.count += 1
	return Core.ellipsoid(ctx.model, name, V3(sx, sy, sz) * ctx.u, cf, color or FACE, CARVE_MAT)
end

-- Bloc taillé en unités de sculpture.
local function B(ctx: Ctx, name: string, sx: number, sy: number, sz: number, cf: CFrame, color: Color3?): Part
	ctx.count += 1
	local part = Build.deco(ctx.model, name, V3(sx, sy, sz) * ctx.u, cf, color or FACE, { Material = CARVE_MAT })
	part.CastShadow = math.min(sx, sy) * ctx.u > 1.5
	return part
end

-- Coin (WedgePart) en unités : dessous plat, dos vertical (+Z), pente vers l'avant et le haut.
-- Dans le repère de la tête, c'est exactement la forme d'une arcade ou d'un nez : le dos contre
-- le visage, le dessous dans l'ombre, la pente qui prend la lumière.
local function W(ctx: Ctx, name: string, sx: number, sy: number, sz: number, cf: CFrame, color: Color3?): WedgePart
	ctx.count += 1
	return Build.wedge(ctx.model, name, V3(sx, sy, sz) * ctx.u, cf, color or FACE, { Material = CARVE_MAT, CanCollide = false, CanQuery = false })
end

-- Mèche : une pointe à quatre facettes (pyramide de coins) qui part de `root` (enfoncée dans la
-- calotte) dans la direction `dir`, longue de `len`, large de `w` (vue de face) et épaisse de `d`.
local function spike(ctx: Ctx, root: Vector3, dir: Vector3, len: number, w: number, d: number, color: Color3?)
	local up = dir.Unit
	local ref = V3(0, 0, 1)
	local depth = ref - up * up:Dot(ref)
	if depth.Magnitude < 1e-3 then
		depth = V3(0, 1, 0) - up * up.Y
	end
	depth = depth.Unit
	local right = up:Cross(depth)
	local u = ctx.u
	local frame = ctx.cf * CFrame.fromMatrix(root * u, right, up, depth)
	for _, part in Core.pyramid(ctx.model, "Meche", frame, w * u, d * u, len * u, color or HAIR, CARVE_MAT) do
		part.CanCollide = false
		part.CanQuery = false
	end
	ctx.count += 4
end

-- Couronne de mèches en éventail : `n` pointes de l'angle `a0` à `a1` (0 = vers le haut, positif =
-- vers la gauche du visage vu de face), racines sur une ellipse centrée en (0, y, z), pointes vers
-- l'extérieur et un peu vers l'arrière (`back`). `lean` penche toute la coiffure d'un côté.
type CrownSpec = {
	n: number,
	a0: number,
	a1: number,
	y: number,
	z: number,
	rx: number,
	ry: number,
	len: number,
	fall: number?, -- raccourcissement des mèches vers les côtés
	w: number,
	d: number,
	back: number?,
	lean: number?,
	wave: number?, -- irrégularité des longueurs
}

local function crown(ctx: Ctx, o: CrownSpec)
	for k = 0, o.n - 1 do
		local t = o.n > 1 and k / (o.n - 1) or 0.5
		local a = o.a0 + (o.a1 - o.a0) * t
		local root = V3(math.sin(a) * o.rx, o.y + math.cos(a) * o.ry, o.z)
		local da = a + (o.lean or 0)
		local len = o.len - math.abs(math.sin(a)) * (o.fall or 0) + (o.wave and math.sin(k * 2.3 + 0.7) * o.wave or 0)
		spike(ctx, root, V3(math.sin(da), math.cos(da), o.back or 0.3), len, o.w, o.d)
	end
end

-- Frange : `n` mèches plates qui partent sous la calotte et retombent sur le front, réparties de
-- -spread à +spread ; `shift` les penche toutes d'un côté, `low` = hauteur des pointes.
local function bangs(ctx: Ctx, n: number, spread: number, low: number, w: number, shift: number?)
	for k = 0, n - 1 do
		local t = n > 1 and k / (n - 1) * 2 - 1 or 0
		local x = t * spread
		local root = V3(x * 0.8, 4.3 - math.abs(t) * 0.5, -1.9 + math.abs(t) * 0.5)
		local tip = V3(x * 1.08 + (shift or 0), low + math.abs(t) * 0.6, -3.45 + math.abs(t) * 0.55)
		local d = tip - root
		spike(ctx, root, d, d.Magnitude, w, 0.9)
	end
end

-- Calotte des cheveux (à peine plus grande que le crâne). `part` > 0 la sépare en deux moitiés
-- inclinées : la raie au milieu se creuse d'elle-même.
local function cap(ctx: Ctx, sx: number?, sy: number?, part: number?)
	if part and part > 0 then
		for _, s in { -1, 1 } do
			E(ctx, "Cheveux", (sx or 7.0) * 0.56, sy or 5.0, 7.6, at(ctx, s * 1.55, 3.2, 1.3, 0, 0, s * part), HAIR)
		end
	else
		E(ctx, "Cheveux", sx or 7.0, sy or 5.0, 7.6, at(ctx, 0, 3.6, 2.0), HAIR)
	end
end

-- Bandeau frontal : bande en cinq pans qui épouse le tour de la tête et plaque de métal plate
-- (0,6 stud) collée au front, gravée du symbole de la feuille. `roll` incline le bandeau.
local RING_X, RING_C = 3.25, 0.15
local function ringAt(phi: number, rz: number): (Vector3, CFrame)
	local pos = V3(math.sin(phi) * RING_X, 0, RING_C - math.cos(phi) * rz)
	local normal = V3(math.sin(phi) / RING_X, 0, -math.cos(phi) / rz).Unit
	return pos, CFrame.lookAt(Vector3.zero, normal)
end

-- Avancée du visage (z de la surface au milieu) à la hauteur `y` : suit l'ovale du visage.
local function faceFront(y: number): number
	local dy = math.clamp((y + 0.5) / 4, -0.95, 0.95)
	return -0.8 - 2.6 * math.sqrt(1 - dy * dy)
end

local function headband(ctx: Ctx, y: number, roll: number?)
	local u = ctx.u
	local rz = RING_C - faceFront(y) + 0.05
	local band = at(ctx, 0, y, 0, 0, 0, roll or 0)
	for _, phi in { -1.25, -0.62, 0, 0.62, 1.25 } do
		local pos, rot = ringAt(phi, rz)
		ctx.count += 1
		Build.deco(ctx.model, "Bandeau", V3(2.1, 1.0, 0.5) * u, band * CFrame.new(pos * u) * rot, HAIR, { Material = CARVE_MAT })
	end
	local plate = band * CFrame.new(0, 0, (RING_C - rz - 0.25) * u - 0.3)
	ctx.count += 1
	Build.deco(ctx.model, "Plaque", V3(2.6 * u, 1.15 * u, 0.6), plate, shade(FACE, 0.06), { Material = CARVE_MAT })
	local g = plate * CFrame.new(0, 0, -0.32)
	local function groove(x: number, yy: number, w: number, h: number, r: number)
		ctx.count += 1
		Build.deco(ctx.model, "Gravure", V3(w * u, h * u, 0.12), g * CFrame.new(x * u, yy * u, 0) * CFrame.Angles(0, 0, r), DEEP, { Material = CARVE_MAT, CastShadow = false })
	end
	-- spirale stylisée de la feuille : un anneau de quatre traits et la pointe
	groove(0, 0.27, 0.5, 0.08, 0)
	groove(0, -0.27, 0.5, 0.08, 0)
	groove(-0.27, 0, 0.08, 0.5, 0)
	groove(0.27, 0.03, 0.08, 0.42, 0)
	groove(0.47, -0.18, 0.4, 0.08, -0.7)
end

------------------------------------------------------------------------
-- Visage commun (volumes nets, expression calme)
------------------------------------------------------------------------

type FaceOptions = {
	jaw: number?, -- largeur de la mâchoire
	brow: number?, -- inclinaison de l'arcade (calme ≈ 0, sévère ≈ 0.12)
	soft: boolean?, -- traits plus fins (visage féminin, jeune)
	mask: boolean?, -- masque de tissu sur le bas du visage
	hideEye: number?, -- œil caché par le bandeau (-1 ou 1)
	ears: boolean?,
	age: boolean?, -- rides du front
}

local function face(ctx: Ctx, o: FaceOptions)
	local jw = o.jaw or 1
	local brow = o.brow or 0.04
	local soft = o.soft == true
	-- crâne et ovale du visage (un seul grand volume lisse qui s'affine vers le menton), coins de
	-- la mâchoire et menton à peine marqués
	E(ctx, "Crane", 6.6, 7.0, 7.2, at(ctx, 0, 1.6, 1.4))
	E(ctx, "Visage", 5.6 * jw, 8.0, 5.2, at(ctx, 0, -0.5, -0.8))
	E(ctx, "BasVisage", 3.8 * jw, 3.6, 4.4, at(ctx, 0, -2.6, -0.95))
	E(ctx, "Menton", (soft and 1.8 or 2.3) * jw, 1.3, 0.8, at(ctx, 0, -4.0, -2.2))
	-- arcade : un bourrelet continu au-dessus des yeux, qui met les orbites dans l'ombre
	E(ctx, "Arcade", 5.0, 1.2, 1.1, at(ctx, 0, 0.98, -2.72))
	for _, s in { -1, 1 } do
		W(ctx, "Sourcil", 1.9, 0.42, 0.5, at(ctx, s * 1.25, 0.86, -3.36, 0, s * 0.28, s * brow))
	end
	-- orbites creusées (un peu plus sombres) ; l'œil caché par un bandeau n'en a pas
	for _, s in { -1, 1 } do
		if o.hideEye ~= s then
			E(ctx, "Orbite", 1.6, 0.66, 0.4, at(ctx, s * 1.3, 0.3, -2.9, 0, s * 0.28, 0), SOCKET)
		end
	end
	-- nez triangulaire (deux coins biseautés) : étroit à la racine, large à la base, l'arête prend
	-- la lumière et le dessous reste dans l'ombre
	local function nose(w: number, h: number, d: number, y: number, z: number)
		local u = ctx.u
		for _, s in { -1, 1 } do
			local part = Instance.new("CornerWedgePart")
			part.Name = "Nez"
			part.Size = (s > 0 and V3(w / 2, h, d) or V3(d, h, w / 2)) * u
			part.CFrame = at(ctx, s * w / 4, y, z) * CFrame.Angles(0, s > 0 and math.pi or -math.pi / 2, 0)
			part.Color = FACE
			part.Material = CARVE_MAT
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Parent = ctx.model
			ctx.count += 1
		end
	end
	if o.mask then
		-- masque : le bas du visage est lisse, le nez se devine sous le tissu
		E(ctx, "Masque", 4.9 * jw, 4.6, 5.0, at(ctx, 0, -2.3, -0.75))
		nose(1.1, 1.8, 0.7, -0.7, -3.42)
		B(ctx, "BordMasque", 4.4, 0.14, 0.3, at(ctx, 0, -0.32, -3.15), shade(FACE, -0.08))
	else
		nose(soft and 0.95 or 1.1, 2.1, 0.85, -0.75, -3.45)
		-- bouche : un trait fin en creux, la lèvre du bas qui accroche la lumière
		B(ctx, "Bouche", soft and 1.2 or 1.45, 0.12, 0.2, at(ctx, 0, -2.62, -3.14), DEEP)
		E(ctx, "Levre", soft and 0.95 or 1.15, 0.34, 0.36, at(ctx, 0, -2.9, -3.06))
	end
	if o.age then
		for _, y in { 2.3, 2.75 } do
			B(ctx, "Ride", 2.0, 0.08, 0.12, at(ctx, 0, y, -3.28), shade(FACE, -0.12))
		end
	end
	if o.ears ~= false then
		for _, s in { -1, 1 } do
			B(ctx, "Oreille", 0.6, 1.9, 1.2, at(ctx, s * 3.05, -0.2, 0.5, 0, -s * 0.3, 0))
		end
	end
	-- cou qui sort de la roche (les blocs autour le cachent en partie)
	E(ctx, "Cou", 3.8, 4.4, 3.8, at(ctx, 0, -5.0, 1.0))
end

------------------------------------------------------------------------
-- Coiffures et signes distinctifs
------------------------------------------------------------------------

local STYLES: { [string]: (Ctx) -> () } = {}

-- Cheveux longs et lisses : calotte séparée par la raie, pans de frange plats qui suivent le
-- front, grands rideaux plats de chaque côté du visage jusqu'aux épaules.
local function longHair(ctx: Ctx, length: number, open: number)
	cap(ctx, 7.4, 5.4)
	B(ctx, "Raie", 0.14, 1.4, 0.3, at(ctx, 0, 5.0, -1.0, -0.75, 0, 0), JOINT)
	for _, s in { -1, 1 } do
		-- deux mèches plates qui partent de la raie et descendent vers la tempe
		spike(ctx, V3(s * 0.5, 4.9, -1.2), V3(s * (2.6 + open), -3.0, -1.5), 4.4, 2.4, 1.0)
		spike(ctx, V3(s * 1.7, 5.0, 0.0), V3(s * (1.8 + open), -3.4, -1.2), 4.6, 2.4, 1.0)
		-- grande masse lisse de cheveux le long de la joue, jusqu'aux épaules, et ses pointes
		local x = s * (3.15 + open * 0.4)
		E(ctx, "Chevelure", 2.8, length + 2.4, 5.0, at(ctx, x, 5.4 - (length + 2.4) / 2, 0.8, 0, 0, s * 0.1), HAIR)
		E(ctx, "Chevelure", 1.6, length, 2.4, at(ctx, x - s * 0.15, 4.4 - length / 2, -1.2, 0, s * 0.2, s * 0.06), HAIR)
		for k = -1, 1 do
			spike(ctx, V3(x + s * k * 0.3, 3.4 - length * 0.82, 0.6 + k * 1.1), V3(s * 0.12, -1, 0), length * 0.28, 1.5, 1.6)
		end
	end
end

-- Hashirama : longs cheveux raides séparés au milieu, jusqu'aux épaules.
STYLES.longs = function(ctx)
	face(ctx, { jaw = 1.02 })
	longHair(ctx, 8.4, 0.05)
end

-- Hiruzen : grands épis dressés en flamme, front ridé, bouc effilé.
STYLES.epis = function(ctx)
	face(ctx, { brow = 0.06, age = true })
	cap(ctx, 7.0, 4.6)
	crown(ctx, { n = 7, a0 = -1.2, a1 = 1.2, y = 3.0, z = 1.2, rx = 3.0, ry = 2.2, len = 4.6, fall = 2.2, w = 2.4, d = 2.6, back = 0.45, wave = 0.5 })
	crown(ctx, { n = 5, a0 = -0.8, a1 = 0.8, y = 2.4, z = -1.4, rx = 2.6, ry = 1.2, len = 2.6, fall = 0.6, w = 2.2, d = 1.4, back = 0.7, wave = 0.3 })
	-- bouc : une pointe qui descend du menton, et une fine moustache
	spike(ctx, V3(0, -4.0, -2.6), V3(0, -1, 0.15), 2.4, 1.4, 1.0)
	for _, s in { -1, 1 } do
		B(ctx, "Moustache", 1.1, 0.22, 0.3, at(ctx, s * 0.55, -2.42, -3.32, 0, -s * 0.2, -s * 0.15), HAIR)
	end
end

-- Tsunade : cheveux lisses, frange séparée au milieu, longs rideaux, losange plat sur le front.
STYLES.raie = function(ctx)
	face(ctx, { soft = true, jaw = 0.92, ears = false })
	longHair(ctx, 7.6, 0.25)
	B(ctx, "Losange", 0.42, 0.42, 0.12, at(ctx, 0, 2.15, -3.3, 0, 0, math.rad(45)), DEEP)
end

-- Naruto : couronne d'épis au-dessus du bandeau, frange en pointes qui retombe dessus, mèches le
-- long des joues, marques des joues à peine gravées.
STYLES.bandeau = function(ctx)
	face(ctx, { jaw = 0.98 })
	cap(ctx)
	crown(ctx, { n = 7, a0 = -1.35, a1 = 1.35, y = 3.0, z = 1.0, rx = 3.1, ry = 2.3, len = 3.5, fall = 0.6, w = 2.5, d = 2.4, back = 0.45, wave = 0.3 })
	bangs(ctx, 5, 2.1, 2.2, 1.7)
	for _, s in { -1, 1 } do
		spike(ctx, V3(s * 3.0, 2.6, -1.0), V3(s * 0.05, -1, -0.1), 3.2, 1.3, 1.0)
		for k = 0, 2 do
			B(ctx, "Marque", 0.85, 0.07, 0.1, at(ctx, s * 1.95, -1.45 - k * 0.3, -3.05, 0, s * 0.45, -s * (k - 1) * 0.12), shade(FACE, -0.08))
		end
	end
	headband(ctx, 2.35)
end

-- Tobirama : cheveux courts hérissés, bandeau à plaque et protège-oreilles plats.
STYLES.plaque = function(ctx)
	face(ctx, { brow = 0.1, jaw = 1.05, ears = false })
	cap(ctx)
	crown(ctx, { n = 7, a0 = -1.3, a1 = 1.3, y = 3.0, z = 1.0, rx = 3.0, ry = 2.3, len = 2.6, fall = 0.3, w = 2.4, d = 2.3, back = 0.45, wave = 0.3 })
	bangs(ctx, 4, 1.7, 3.3, 1.6)
	headband(ctx, 2.4)
	for _, s in { -1, 1 } do
		B(ctx, "Garde", 0.5, 2.8, 2.6, at(ctx, s * 3.3, 0.8, 0.3, 0, -s * 0.15, 0), HAIR)
	end
end

-- Minato : crinière de grandes pointes, longue frange en pointes sur le front, longues mèches qui
-- encadrent le visage jusqu'à la mâchoire.
STYLES.meches = function(ctx)
	face(ctx, { jaw = 0.98 })
	cap(ctx)
	crown(ctx, { n = 7, a0 = -1.55, a1 = 1.55, y = 2.9, z = 1.0, rx = 3.2, ry = 2.4, len = 3.9, fall = -0.2, w = 2.6, d = 2.4, back = 0.45, wave = 0.4 })
	bangs(ctx, 5, 2.2, 1.4, 1.7)
	for _, s in { -1, 1 } do
		spike(ctx, V3(s * 2.85, 3.0, -1.4), V3(s * 0.12, -1, -0.12), 5.4, 1.5, 1.0)
	end
end

-- Kakashi : grands épis penchés d'un côté, bandeau incliné sur un œil, masque.
STYLES.penche = function(ctx)
	face(ctx, { mask = true, hideEye = -1 })
	cap(ctx)
	crown(ctx, { n = 6, a0 = -1.0, a1 = 1.2, y = 3.0, z = 1.0, rx = 3.0, ry = 2.3, len = 4.5, fall = 0.8, w = 2.6, d = 2.5, back = 0.45, lean = -0.55, wave = 0.3 })
	bangs(ctx, 4, 1.8, 2.6, 1.7, -0.7)
	headband(ctx, 1.75, 0.3)
end

-- Boruto : épis plus courts, une longue mèche qui tombe sur le côté, bandeau sur le front.
STYLES.jeune = function(ctx)
	face(ctx, { soft = true, jaw = 0.95 })
	cap(ctx)
	crown(ctx, { n = 6, a0 = -1.3, a1 = 1.3, y = 3.0, z = 1.0, rx = 3.0, ry = 2.3, len = 3.0, fall = 0.4, w = 2.5, d = 2.3, back = 0.45, wave = 0.3 })
	bangs(ctx, 4, 1.8, 2.4, 1.6)
	spike(ctx, V3(1.0, 4.2, -2.0), V3(0.35, -1, -0.35), 4.2, 1.5, 0.9)
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
		local rot = CFrame.Angles(tilt(1, 6), tilt(1, 7), tilt(5, 25))
		Build.deco(model, "Bloc", V3(sx, sy, depth), where * rot, tone, { Material = ROCK_MAT })
		-- arête du haut abattue : un coin posé sur le dessus, la pente vers le village
		if rng:NextNumber() < 0.45 then
			local h = sy * rng:NextNumber(0.25, 0.4)
			local d = math.min(depth * 0.5, sy * 0.8)
			Build.wedge(model, "Bloc", V3(sx * 0.98, h, d), where * rot * CFrame.new(0, sy / 2 + h / 2 - 0.2, -depth / 2 + d / 2), shade(tone, 0.05), props)
		end
	elseif roll < 0.9 then
		-- coin : pente tournée vers le haut ou un côté (arête vive)
		local quarter = ({ 0, math.pi / 2, -math.pi / 2 })[rng:NextInteger(1, 3)]
		local size = quarter == 0 and V3(sx, sy, depth) or V3(sy, sx, depth)
		Build.wedge(model, "Bloc", size, where * CFrame.Angles(0, 0, quarter + tilt(5, 20)) * CFrame.Angles(tilt(1, 5), 0, 0), tone, props)
	else
		local part = Instance.new("CornerWedgePart")
		part.Name = "Bloc"
		part.Size = V3(sx, sy, depth)
		part.CFrame = where * CFrame.Angles(0, rng:NextInteger(0, 1) * math.pi / 2, tilt(5, 20))
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
		Core.ellipsoid(model, "SommetBosse", V3(colW * 1.4, 18, 80), cf * CFrame.new(x0 + rng:NextNumber(-8, 8), top + 2, 80 + rng:NextNumber(0, 30)), GRASS_LIGHT, Enum.Material.Grass)
	end
	-- flancs : gradins qui descendent et reculent, habillés de blocs anguleux et d'herbe
	for _, s in { -1, 1 } do
		local edge = topAt(s * half)
		for k = 0, 3 do
			local w = rng:NextNumber(30, 40)
			local h = edge * (0.86 - k * 0.2)
			local x = s * (half - 6 + k * 24 + w / 2)
			local z = 14 + k * 16
			Build.part(model, "Flanc", V3(w, h, depth - k * 20), cf * CFrame.new(x, h / 2, z + (depth - k * 20) / 2) * CFrame.Angles(0, s * rng:NextNumber(0.05, 0.2), 0), shade(JOINT, 0.05), {
				Material = ROCK_MAT,
			})
			Build.part(model, "FlancHerbe", V3(w + 4, 4, depth - k * 20 - 6), cf * CFrame.new(x, h + 1, z + 4 + (depth - k * 20 - 6) / 2), shade(GRASS, rng:NextNumber(-0.06, 0.03)), {
				Material = Enum.Material.Grass,
			})
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
	local function place(px: number, py: number, sx: number, sy: number)
		local d = nearHead(px, py, math.min(sx, sy) * 0.3)
		if d < 1.0 or py > topAt(px) - sy * 0.3 then
			return
		end
		local frame = math.clamp((1.55 - d) / 0.55, 0, 1) -- 1 contre une tête, 0 au large
		local front = lean(py) - rng:NextNumber(6, 13) - frame * rng:NextNumber(10, 18)
		rockBlock(model, cf, rng, px, py, sx, sy, front)
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
	for _ = 1, 150 do
		local px = rng:NextNumber(-half + 8, half - 8)
		local py = rng:NextNumber(base + 6, topAt(px) - 6)
		local size = rng:NextNumber(12, 22)
		place(px, py, size * rng:NextNumber(0.9, 1.4), size)
	end
	-- 3) collerette sous chaque menton : la tête sort de la roche
	for _, h in Hokage.Heads do
		local u = U * (h.scale or 1)
		for k = -2, 2 do
			local px = h.x + k * 1.25 * u + rng:NextNumber(-2, 2)
			local py = h.y - (5.9 - math.abs(k) * 0.4) * u + rng:NextNumber(-2, 2)
			if py > base then
				rockBlock(model, cf, rng, px, py, rng:NextNumber(18, 26), rng:NextNumber(14, 20), lean(py) - rng:NextNumber(26, 34))
			end
		end
	end
	-- 4) deux gros rochers arrondis (rayon ≥ 20), à moitié enfoncés, dans les coins du haut
	for _, spot in { { half - 26, 196 }, { -half + 30, 192 } } do
		local px, py = spot[1], spot[2]
		if nearHead(px, py, 20) > 1.0 then
			Core.ellipsoid(
				model,
				"Rocher",
				V3(rng:NextNumber(46, 56), rng:NextNumber(42, 48), 34),
				cf * CFrame.new(px, py, lean(py) - 6) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.5, 0.5)),
				shade(ROCK, rng:NextNumber(-0.04, 0.03)),
				ROCK_MAT
			)
		end
	end
	-- 5) creux sombre derrière chaque tête : elle sort d'une niche de la roche
	for _, h in Hokage.Heads do
		local e = EXTENT[h.style] or EXTENT.longs
		local u = U * (h.scale or 1)
		local cy = h.y + (e[2] + e[3]) / 2 * u
		Build.deco(model, "Niche", V3(e[1] * 1.9 * u, (e[2] - e[3]) * 0.92 * u, 10), cf * CFrame.new(h.x, cy, lean(h.y) + 4), shade(JOINT, -0.08), { Material = ROCK_MAT })
	end
end

-- Emblème de la feuille gravé sur un gros rocher arrondi (en bas à gauche vu du village, à côté de Tobirama).
local function emblem(model: Model, cf: CFrame)
	local em = Hokage.Emblem
	local c = cf * CFrame.new(em.x, em.y, lean(em.y) - 14)
	Core.ellipsoid(model, "Emblème", V3(68, 62, 44), c, ROCK, CARVE_MAT)
	local face = c * CFrame.new(0, 0, -21)
	local function groove(x: number, y: number, w: number, h: number, r: number)
		Build.deco(model, "Gravure", V3(w, h, 2), face * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, r), DEEP, { Material = CARVE_MAT, CastShadow = false })
	end
	-- spirale : anneau de 8 traits, branche intérieure et pointe de la feuille
	for k = 0, 7 do
		local a = k * math.pi / 4
		groove(math.cos(a) * 12, math.sin(a) * 12, 10.5, 2.4, a + math.pi / 2)
	end
	groove(-3, 2, 9, 2.2, -0.6)
	groove(15, -14, 14, 2.4, -0.75)
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

-- Végétation : arbres et buissons sur le sommet et les flancs, coulées de lierre plates.
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
	local count = 24
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
				detail = "low",
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
					detail = "low",
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
	-- coulées de lierre plates qui pendent du sommet entre les têtes
	for _ = 1, 8 do
		local x = rng:NextNumber(-half + 16, half - 16)
		local top = topAt(x)
		if nearHead(x, top - 18) > 1.15 then
			local len = rng:NextNumber(20, 40)
			for k = 0, 2 do
				local y = top - len * (k + 0.5) / 3
				Build.deco(
					model,
					"Lierre",
					V3(rng:NextNumber(9, 14) * (1 - k * 0.25), len / 3 + 3, 3),
					cf * CFrame.new(x + rng:NextNumber(-3, 3), y, lean(y) - 22) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.25, 0.25)),
					shade(MOSS, rng:NextNumber(-0.14, 0.02)),
					{ Material = Enum.Material.LeafyGrass }
				)
			end
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
