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
local SOCKET = rgb(94, 96, 103) -- orbites creusées
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
-- Outils de sculpture (repère d'une tête : origine entre les yeux, -Z = vers l'avant)
------------------------------------------------------------------------

type Ctx = { model: Model, cf: CFrame, u: number, count: number }

local function at(ctx: Ctx, x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	local u = ctx.u
	return ctx.cf * CFrame.new(x * u, y * u, z * u) * CFrame.Angles(rx or 0, ry or 0, rz or 0)
end

-- Grand volume arrondi (crâne, visage, front, cou) en unités de sculpture.
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
local function W(ctx: Ctx, name: string, sx: number, sy: number, sz: number, cf: CFrame, color: Color3?): WedgePart
	ctx.count += 1
	local part = Build.wedge(ctx.model, name, V3(sx, sy, sz) * ctx.u, cf, color or FACE, { Material = CARVE_MAT, CanCollide = false, CanQuery = false })
	return part
end

-- Mèche plate et effilée, de `base` à `tip` (en unités, repère de la tête) : deux coins dos à
-- dos forment un triangle isocèle (base large de `width`, pointe fine), épais de `thick`, tourné
-- vers l'avant. `cross` > 0 ajoute une arête perpendiculaire (la mèche a du volume vue de biais).
local function strand(ctx: Ctx, base: Vector3, tip: Vector3, width: number, thick: number, cross: number?, color: Color3?)
	local u = ctx.u
	local d = tip - base
	local len = d.Magnitude
	if len < 1e-3 then
		return
	end
	local up = d / len
	local backRef = V3(0, 0, 1)
	local back = backRef - up * up:Dot(backRef)
	if back.Magnitude < 1e-3 then
		back = V3(0, 1, 0) - up * up.Y
	end
	back = back.Unit
	local right = up:Cross(back)
	local mid = base + up * (len / 2)
	local col = color or HAIR
	local function pair(side: Vector3, normal: Vector3, w: number, t: number)
		for _, s in { 1, -1 } do
			local pos = mid + side * (s * w / 4)
			-- dos du coin (+Z local) sur l'axe de la mèche, pente vers le bord
			local frame = CFrame.fromMatrix(pos * u, normal * s, up)
			ctx.count += 1
			Build.wedge(ctx.model, "Meche", V3(t, len, w / 2) * u, ctx.cf * frame, col, { Material = CARVE_MAT, CanCollide = false, CanQuery = false })
		end
	end
	pair(right, back, width, thick)
	if cross and cross > 0 then
		pair(back, -right, cross, thick * 0.8)
	end
end

-- Mèches en éventail autour du crâne : `n` mèches de l'angle `a0` à `a1` (0 = vers le haut,
-- positif = vers la gauche du visage vu de face), racines sur une ellipse, pointes vers l'extérieur
-- et l'arrière.
type FanSpec = {
	n: number,
	a0: number,
	a1: number,
	y: number, -- centre des racines
	rx: number,
	ry: number,
	z: number,
	len: number,
	fall: number?, -- raccourcissement vers les côtés
	width: number,
	thick: number?,
	back: number?, -- inclinaison vers l'arrière (composante Z de la direction)
	lean: number?, -- déviation latérale commune (coiffure penchée)
	cross: number?,
	wave: number?,
}

local function fan(ctx: Ctx, o: FanSpec)
	for k = 0, o.n - 1 do
		local t = o.n > 1 and k / (o.n - 1) or 0.5
		local a = o.a0 + (o.a1 - o.a0) * t
		local root = V3(-math.sin(a) * o.rx, o.y + math.cos(a) * o.ry, o.z)
		local da = a + (o.lean or 0)
		local len = o.len - math.abs(math.sin(a)) * (o.fall or 0) + (o.wave and math.sin(k * 2.3) * o.wave or 0)
		local dir = V3(-math.sin(da), math.cos(da), o.back or 0.25).Unit
		strand(ctx, root, root + dir * len, o.width, o.thick or 0.45, o.cross)
	end
end

-- Calotte lisse des cheveux (le haut du crâne, à peine plus grande que lui).
local function cap(ctx: Ctx, sx: number?, sy: number?)
	E(ctx, "Cheveux", sx or 7.2, sy or 4.6, 7.6, at(ctx, 0, 3.2, 1.5), HAIR)
end

-- Anneau qui suit le tour de la tête à la hauteur `y` (repère de la tête) : renvoie la position
-- (en unités) et l'orientation (face avant tournée vers l'extérieur) au point d'angle `phi`
-- (0 = devant, positif = vers la gauche du visage vu de face).
local RING_X, RING_Z, RING_C = 3.3, 3.45, 0.2
local function ringAt(phi: number): (Vector3, CFrame)
	local pos = V3(-math.sin(phi) * RING_X, 0, RING_C - math.cos(phi) * RING_Z)
	local normal = V3(-math.sin(phi) / RING_X, 0, -math.cos(phi) / RING_Z).Unit
	return pos, CFrame.lookAt(Vector3.zero, normal)
end

-- Bandeau frontal : bande de tissu en cinq pans qui épouse le tour de la tête, et plaque de
-- métal plate collée au front, gravée du symbole de la feuille (traits plats, aucun objet en
-- volume). `roll` incline tout le bandeau (bandeau de travers).
local function headband(ctx: Ctx, y: number, roll: number?)
	local u = ctx.u
	local band = at(ctx, 0, y, 0, 0, 0, roll or 0)
	for _, phi in { -1.15, -0.58, 0, 0.58, 1.15 } do
		local pos, rot = ringAt(phi)
		ctx.count += 1
		Build.deco(ctx.model, "Bandeau", V3(2.05, 1.1, 0.45) * u, band * CFrame.new(pos * u) * rot, HAIR, { Material = CARVE_MAT })
	end
	-- plaque plate (0,6 stud d'épaisseur) et son symbole gravé
	local plate = band * CFrame.new(0, 0, (RING_C - RING_Z - 0.23) * u - 0.3)
	ctx.count += 1
	Build.deco(ctx.model, "Plaque", V3(2.8 * u, 1.25 * u, 0.6), plate, shade(FACE, 0.05), { Material = CARVE_MAT })
	local g = plate * CFrame.new(0, 0, -0.32)
	local function groove(x: number, yy: number, w: number, h: number, r: number)
		ctx.count += 1
		Build.deco(ctx.model, "Gravure", V3(w * u, h * u, 0.12), g * CFrame.new(x * u, yy * u, 0) * CFrame.Angles(0, 0, r), DEEP, { Material = CARVE_MAT, CastShadow = false })
	end
	-- spirale stylisée : un anneau de quatre traits et la pointe de la feuille
	groove(0, 0.27, 0.48, 0.08, 0)
	groove(0, -0.27, 0.48, 0.08, 0)
	groove(-0.27, 0, 0.08, 0.48, 0)
	groove(0.27, 0.03, 0.08, 0.4, 0)
	groove(0.46, -0.17, 0.38, 0.08, -0.7)
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
	local brow = o.brow or 0.03
	local soft = o.soft == true
	-- grands volumes : crâne, ovale du visage, front, bas du visage (mâchoire)
	E(ctx, "Crane", 7.0, 7.4, 7.6, at(ctx, 0, 1.4, 1.4))
	E(ctx, "Visage", 5.9 * jw, 8.2, 6.2, at(ctx, 0, -0.7, -0.5))
	E(ctx, "Front", 5.4, 3.6, 2.5, at(ctx, 0, 2.0, -1.9))
	-- menton carré, à fleur du bas du visage
	B(ctx, "Menton", (soft and 1.5 or 1.9) * jw, 0.9, 0.8, at(ctx, 0, -4.2, -2.0))
	-- arcade continue (deux coins qui suivent le front) : son dessous plat met les yeux dans l'ombre
	for _, s in { -1, 1 } do
		W(ctx, "Arcade", 2.6, 0.7, 0.55, at(ctx, s * 1.35, 1.0, -3.1, 0, -s * 0.3, -s * brow))
	end
	W(ctx, "Glabelle", 0.9, 0.6, 0.45, at(ctx, 0, 0.92, -3.42))
	-- orbites creusées (plus sombres, dans l'ombre de l'arcade), regard calme ; sous le bandeau
	-- de travers, l'œil caché n'a pas d'orbite
	for _, s in { -1, 1 } do
		if o.hideEye ~= s then
			E(ctx, "Orbite", 1.75, 0.66, 0.12, at(ctx, s * 1.3, 0.36, -3.16, 0, -s * 0.3, -s * 0.06), SOCKET)
			B(ctx, "Pupille", 0.3, 0.26, 0.08, at(ctx, s * 1.22, 0.32, -3.24, 0, -s * 0.3, 0), shade(SOCKET, -0.25))
		end
	end
	if o.mask then
		-- masque : le bas du visage est lisse, le nez se devine sous le tissu
		E(ctx, "Masque", 5.0 * jw, 4.6, 5.0, at(ctx, 0, -2.6, -0.85))
		W(ctx, "Nez", 0.95, 1.9, 0.8, at(ctx, 0, -0.75, -3.55))
		for _, s in { -1, 1 } do
			B(ctx, "BordMasque", 2.6, 0.12, 0.25, at(ctx, s * 1.3, -0.35, -3.3, 0, -s * 0.35, s * 0.08), shade(FACE, -0.1))
		end
	else
		-- nez triangulaire (coin) et ses ailes ; le dessous reste dans l'ombre
		W(ctx, "Nez", soft and 0.62 or 0.74, 2.3, 0.8, at(ctx, 0, -0.8, -3.55))
		-- bouche : un simple trait fin en creux, et l'ombre sous la lèvre
		B(ctx, "Bouche", soft and 1.2 or 1.45, 0.09, 0.12, at(ctx, 0, -2.7, -3.32), DEEP)
	end
	if o.age then
		for _, y in { 2.3, 2.75 } do
			B(ctx, "Ride", 2.0, 0.08, 0.1, at(ctx, 0, y, -3.27), shade(FACE, -0.12))
		end
	end
	if o.ears ~= false then
		for _, s in { -1, 1 } do
			B(ctx, "Oreille", 0.6, 2.0, 1.3, at(ctx, s * 3.0, -0.2, 0.3, 0, s * 0.3, 0))
		end
	end
	-- cou qui sort de la roche (les blocs autour le cachent en partie)
	E(ctx, "Cou", 3.6, 4.6, 3.6, at(ctx, 0, -5.1, 1.2))
end

------------------------------------------------------------------------
-- Coiffures et signes distinctifs
------------------------------------------------------------------------

local STYLES: { [string]: (Ctx) -> () } = {}

-- Cheveux longs et lisses : calotte, raie au milieu, deux pans de frange plats qui suivent le
-- front, et deux grands rideaux plats de chaque côté du visage jusqu'aux épaules.
local function longHair(ctx: Ctx, bangs: number, length: number)
	cap(ctx, 7.6, 5.4)
	B(ctx, "Raie", 0.12, 1.2, 0.2, at(ctx, 0, 4.4, -2.0, 0.6, 0, 0), JOINT)
	for _, s in { -1, 1 } do
		-- frange : trois mèches plates qui partent de la raie et descendent vers la tempe
		strand(ctx, V3(s * 0.2, 4.6, -2.3), V3(s * 2.9, 1.8 - bangs, -3.0), 2.4, 0.4)
		strand(ctx, V3(s * 0.4, 5.3, -1.2), V3(s * 3.3, 1.4 - bangs, -2.5), 2.4, 0.4)
		strand(ctx, V3(s * 1.2, 5.5, 0.2), V3(s * 3.7, 0.8 - bangs, -1.6), 2.4, 0.4)
		-- grand rideau le long de la joue, jusqu'aux épaules
		B(ctx, "Rideau", 1.5, length, 3.6, at(ctx, s * 3.45, 2.0 - length / 2, 0.1, 0, 0, s * 0.06), HAIR)
		B(ctx, "Rideau", 0.5, length * 0.8, 1.6, at(ctx, s * 3.05, 1.8 - length * 0.4, -1.75, 0, -s * 0.35, s * 0.05), HAIR)
		strand(ctx, V3(s * 3.6, 2.4 - length, -0.2), V3(s * 3.9, 1.0 - length, -0.3), 1.6, 0.45)
	end
end

-- Hashirama : longs cheveux raides séparés au milieu.
STYLES.longs = function(ctx)
	face(ctx, { jaw = 1.03 })
	longHair(ctx, 0.0, 8.6)
	-- mèches qui descendent du sommet de part et d'autre de la raie
	for _, s in { -1, 1 } do
		strand(ctx, V3(s * 0.6, 5.0, -1.4), V3(s * 2.9, 1.6, -2.6), 1.4, 0.3)
	end
end

-- Frange : `n` mèches plates qui partent du haut du crâne et retombent sur le front, réparties
-- de -spread à +spread ; `shift` les penche toutes d'un côté.
local function bangs(ctx: Ctx, n: number, spread: number, y1: number, width: number, shift: number?)
	for k = 0, n - 1 do
		local t = n > 1 and k / (n - 1) * 2 - 1 or 0
		local x = t * spread
		local tip = V3(x * 1.1 + (shift or 0), y1 - math.abs(t) * 0.5, -3.5 + math.abs(t) * 0.6)
		strand(ctx, V3(x * 0.6, 4.7, -2.3 + math.abs(t) * 0.4), tip, width, 0.4)
	end
end

-- Hiruzen : grands épis dressés en flamme, front dégarni et ridé, bouc effilé.
STYLES.epis = function(ctx)
	face(ctx, { brow = 0.06, age = true })
	cap(ctx, 7.2, 4.6)
	fan(ctx, { n = 6, a0 = 1.1, a1 = -1.1, y = 3.1, rx = 3.0, ry = 2.3, z = 1.0, len = 4.6, fall = 2.0, width = 2.6, back = 0.15, cross = 1.2, wave = 0.5 })
	fan(ctx, { n = 5, a0 = 1.3, a1 = -1.3, y = 3.0, rx = 3.1, ry = 2.0, z = -0.6, len = 2.8, fall = 0.8, width = 2.4, back = -0.05 })
	-- bouc : une pointe qui descend du menton, et une fine moustache
	strand(ctx, V3(0, -4.2, -2.75), V3(0, -6.2, -2.5), 1.3, 0.4, 0.7)
	for _, s in { -1, 1 } do
		B(ctx, "Moustache", 1.1, 0.2, 0.3, at(ctx, s * 0.55, -2.42, -3.3, 0, -s * 0.2, s * 0.12), HAIR)
	end
end

-- Tsunade : cheveux lisses, frange séparée au milieu, longs rideaux, losange plat sur le front.
STYLES.raie = function(ctx)
	face(ctx, { soft = true, jaw = 0.93, ears = false })
	longHair(ctx, 0.2, 8.0)
	B(ctx, "Losange", 0.4, 0.4, 0.1, at(ctx, 0, 2.15, -3.28, 0, 0, math.rad(45)), DEEP)
end

-- Naruto : couronne d'épis au-dessus du bandeau, frange qui retombe dessus, mèches le long des
-- joues, marques des joues à peine gravées.
STYLES.bandeau = function(ctx)
	face(ctx, { jaw = 0.98 })
	cap(ctx)
	fan(ctx, { n = 5, a0 = 1.15, a1 = -1.15, y = 3.1, rx = 3.0, ry = 2.3, z = 1.0, len = 3.4, fall = 0.4, width = 2.6, back = 0.15, cross = 1.2, wave = 0.3 })
	fan(ctx, { n = 6, a0 = 1.7, a1 = -1.7, y = 3.0, rx = 3.3, ry = 2.0, z = -0.6, len = 2.8, fall = 0.2, width = 2.4, back = -0.05, wave = 0.25 })
	bangs(ctx, 5, 2.2, 2.3, 1.6)
	for _, s in { -1, 1 } do
		strand(ctx, V3(s * 3.1, 2.4, -1.3), V3(s * 3.15, -0.7, -1.9), 1.3, 0.35)
		for k = 0, 2 do
			B(ctx, "Marque", 0.9, 0.06, 0.08, at(ctx, s * 1.95, -1.5 - k * 0.3, -3.18, 0, -s * 0.45, s * (k - 1) * 0.12), shade(FACE, -0.07))
		end
	end
	headband(ctx, 2.75)
end

-- Tobirama : bandeau à plaque et protège-oreilles, cheveux courts hérissés.
STYLES.plaque = function(ctx)
	face(ctx, { brow = 0.1, jaw = 1.05, ears = false })
	cap(ctx)
	fan(ctx, { n = 6, a0 = 1.3, a1 = -1.3, y = 3.1, rx = 3.0, ry = 2.3, z = 0.6, len = 2.4, fall = 0.3, width = 2.4, back = 0.2, wave = 0.35 })
	fan(ctx, { n = 6, a0 = 1.5, a1 = -1.5, y = 3.0, rx = 3.2, ry = 2.0, z = -0.6, len = 2.0, width = 2.2, back = -0.05, wave = 0.3 })
	bangs(ctx, 4, 1.8, 3.4, 1.6)
	headband(ctx, 2.8)
	-- protège-oreilles plats
	for _, s in { -1, 1 } do
		B(ctx, "Garde", 0.45, 2.8, 2.4, at(ctx, s * 3.25, 0.7, 0.2, 0, s * 0.18, 0), HAIR)
	end
end

-- Minato : grandes mèches en pointes écartées (crinière), longue frange effilée sur le front,
-- longues mèches qui encadrent le visage jusqu'à la mâchoire.
STYLES.meches = function(ctx)
	face(ctx, { jaw = 0.98 })
	cap(ctx)
	fan(ctx, { n = 5, a0 = 1.2, a1 = -1.2, y = 3.1, rx = 3.0, ry = 2.3, z = 1.0, len = 4.0, fall = 0.6, width = 2.6, back = 0.15, cross = 1.2, wave = 0.4 })
	fan(ctx, { n = 6, a0 = 1.95, a1 = -1.95, y = 2.6, rx = 3.5, ry = 2.0, z = -0.2, len = 3.2, fall = -0.6, width = 2.4, back = 0.0 })
	bangs(ctx, 6, 2.5, 1.7, 1.5)
	for _, s in { -1, 1 } do
		strand(ctx, V3(s * 2.95, 3.0, -1.6), V3(s * 3.05, -2.3, -2.2), 1.4, 0.35)
	end
end

-- Kakashi : grands épis penchés d'un côté, bandeau incliné sur un œil, masque.
STYLES.penche = function(ctx)
	face(ctx, { mask = true, hideEye = 1 })
	cap(ctx)
	fan(ctx, { n = 5, a0 = 0.9, a1 = -1.1, y = 3.1, rx = 3.0, ry = 2.3, z = 1.0, len = 4.6, fall = 1.0, width = 2.6, back = 0.15, lean = 0.6, cross = 1.2, wave = 0.3 })
	fan(ctx, { n = 5, a0 = 1.3, a1 = -1.3, y = 3.0, rx = 3.2, ry = 2.0, z = -0.6, len = 3.0, fall = 0.6, width = 2.4, back = -0.05, lean = 0.45 })
	bangs(ctx, 4, 1.9, 2.8, 1.6, -0.6)
	headband(ctx, 1.85, -0.3)
end

-- Boruto : épis plus courts, une longue mèche qui tombe sur le côté, bandeau sur le front.
STYLES.jeune = function(ctx)
	face(ctx, { soft = true, jaw = 0.95 })
	cap(ctx)
	fan(ctx, { n = 5, a0 = 1.15, a1 = -1.15, y = 3.1, rx = 3.0, ry = 2.3, z = 1.0, len = 3.0, fall = 0.4, width = 2.5, back = 0.15, cross = 1.1, wave = 0.3 })
	fan(ctx, { n = 6, a0 = 1.7, a1 = -1.7, y = 3.0, rx = 3.3, ry = 2.0, z = -0.6, len = 2.4, width = 2.2, back = -0.05 })
	bangs(ctx, 4, 1.9, 2.5, 1.5)
	strand(ctx, V3(-1.1, 4.4, -2.2), V3(-2.4, 0.4, -3.3), 1.6, 0.35)
	headband(ctx, 2.75)
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
	-- flancs : gradins de gros blocs qui descendent et reculent, couverts d'herbe et de buissons
	for _, s in { -1, 1 } do
		local edge = topAt(s * half)
		for k = 0, 3 do
			local w = rng:NextNumber(30, 40)
			local h = edge * (0.86 - k * 0.2)
			local x = s * (half - 6 + k * 24 + w / 2)
			local z = 14 + k * 16
			local tone = TONES[rng:NextInteger(1, #TONES)]
			Build.part(model, "Flanc", V3(w, h, depth - k * 20), cf * CFrame.new(x, h / 2, z + (depth - k * 20) / 2) * CFrame.Angles(0, s * rng:NextNumber(0.05, 0.2), 0), tone, {
				Material = ROCK_MAT,
			})
			Build.part(model, "FlancHerbe", V3(w + 4, 4, depth - k * 20 - 6), cf * CFrame.new(x, h + 1, z + 4 + (depth - k * 20 - 6) / 2), shade(GRASS, rng:NextNumber(-0.06, 0.03)), {
				Material = Enum.Material.Grass,
			})
		end
	end
end

-- Un bloc de roche anguleux (pavé, coin ou pointe), incliné de 5 à 25°, à moitié enfoncé :
-- sa face avant arrive à `protrude` studs devant la paroi.
local function rockBlock(model: Model, cf: CFrame, rng: Random, px: number, py: number, size: number, protrude: number)
	local depth = math.max(size * 0.9, protrude + 8)
	local sx = size * rng:NextNumber(0.85, 1.35)
	local sy = size * rng:NextNumber(0.65, 1.0)
	local z = lean(py) - protrude + depth / 2
	local function tilt(): number
		local a = math.rad(rng:NextNumber(5, 18))
		return rng:NextNumber() < 0.5 and -a or a
	end
	local tone = shade(TONES[rng:NextInteger(1, #TONES)], rng:NextNumber(-0.03, 0.04))
	local where = cf * CFrame.new(px, py, z)
	local roll = rng:NextNumber()
	if roll < 0.68 then
		-- pavé : la face avant reste tournée vers le village (faible bascule), roulis franc
		local brick = where * CFrame.Angles(tilt() * 0.3, tilt() * 0.35, tilt())
		Build.deco(model, "Bloc", V3(sx, sy, depth), brick, tone, { Material = ROCK_MAT })
		-- arête du haut abattue (chanfrein) : le bloc a l'air taillé dans la roche, pas d'une brique
		if rng:NextNumber() < 0.6 then
			local h = sy * rng:NextNumber(0.22, 0.34)
			local d = math.min(depth * 0.45, sy)
			Build.wedge(model, "Bloc", V3(sx * 0.98, h, d), brick * CFrame.new(0, sy / 2 + h / 2, -depth / 2 + d / 2), shade(tone, 0.04), {
				Material = ROCK_MAT,
				CanCollide = false,
				CanQuery = false,
			})
		end
	elseif roll < 0.9 then
		-- coin : la pente tournée vers le haut, un côté ou le bas (arête vive)
		local quarter = rng:NextInteger(0, 3) * math.pi / 2
		Build.wedge(model, "Bloc", V3(sx, sy, depth), where * CFrame.Angles(0, 0, quarter + tilt() * 0.5) * CFrame.Angles(tilt() * 0.5, 0, 0), tone, {
			Material = ROCK_MAT,
			CanCollide = false,
			CanQuery = false,
		})
	else
		local part = Instance.new("CornerWedgePart")
		part.Name = "Bloc"
		part.Size = V3(sx, sy, depth)
		part.CFrame = where * CFrame.Angles(0, rng:NextInteger(0, 3) * math.pi / 2, tilt())
		part.Color = tone
		part.Material = ROCK_MAT
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = model
	end
	-- un peu de mousse posée sur le dessus de certains blocs du haut
	if py > Hokage.Height * 0.7 and rng:NextNumber() < 0.18 then
		Build.deco(model, "Mousse", V3(sx * 0.7, 1.4, depth * 0.5), cf * CFrame.new(px, py + sy / 2, z - depth * 0.15), MOSS, { Material = Enum.Material.Grass })
	end
end

-- Relief de la paroi : gros blocs anguleux en 4 tailles autour des têtes. Près des visages, les
-- blocs avancent davantage (cadre en creux) ; plus loin, ils restent près de la paroi.
local function cliffFace(model: Model, cf: CFrame, rng: Random)
	local half = Hokage.Width / 2
	local base = Hokage.BaseHeight
	local step = 30
	local row = 0
	-- 1) gros blocs (24 à 42 studs) sur une grille décalée, jamais devant une tête
	for y = base + 12, Hokage.Height + 6, step * 0.8 do
		row += 1
		for x = -half + 14 + (row % 2) * step / 2, half - 10, step do
			local px = x + rng:NextNumber(-6, 6)
			local py = y + rng:NextNumber(-5, 5)
			local size = rng:NextNumber(24, 42)
			local d = nearHead(px, py, size * 0.35)
			if py < topAt(px) - 2 and d > 1.0 then
				local frame = math.clamp(1.5 - d, 0, 0.5) / 0.5 -- 1 contre une tête, 0 au large
				local protrude = rng:NextNumber(12, 20) + frame * rng:NextNumber(14, 22)
				rockBlock(model, cf, rng, px, py, size * (1 - frame * 0.2), protrude)
			end
		end
	end
	-- 2) blocs moyens et petits (12 à 22 studs) qui comblent les creux contre les têtes
	for _ = 1, 220 do
		local px = rng:NextNumber(-half + 8, half - 8)
		local py = rng:NextNumber(base + 6, topAt(px) - 4)
		local size = rng:NextNumber(12, 22)
		local d = nearHead(px, py, size * 0.35)
		if d > 1.0 and d < 1.3 then
			rockBlock(model, cf, rng, px, py, size, rng:NextNumber(26, 36))
		elseif d > 0.8 and d <= 1.0 then
			-- dans les creux entre les têtes : blocs en retrait (derrière les visages et les mèches)
			rockBlock(model, cf, rng, px, py, size * 1.2, rng:NextNumber(4, 9))
		end
	end
	-- 3) collerette sous chaque menton : la tête sort de la roche
	for _, h in Hokage.Heads do
		local u = U * (h.scale or 1)
		for k = -2, 2 do
			local px = h.x + k * 1.3 * u + rng:NextNumber(-2, 2)
			local py = h.y - (6.4 - math.abs(k) * 0.5) * u + rng:NextNumber(-2, 2)
			if py > base then
				rockBlock(model, cf, rng, px, py, rng:NextNumber(16, 24), rng:NextNumber(30, 38))
			end
		end
	end
	-- 4) quelques gros rochers arrondis (rayon ≥ 20), à moitié enfoncés, dans les coins
	for _, spot in { { half - 30, 204 }, { -half + 34, 200 }, { 0, 232 } } do
		local px, py = spot[1], spot[2]
		if py < topAt(px) + 4 then
			Core.ellipsoid(
				model,
				"Rocher",
				V3(rng:NextNumber(44, 56), rng:NextNumber(40, 48), 30),
				cf * CFrame.new(px, py, lean(py) - 4) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.5, 0.5)),
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
		Build.deco(model, "Niche", V3(e[1] * 1.9 * u, (e[2] - e[3]) * 0.92 * u, 10), cf * CFrame.new(h.x, cy, lean(h.y) + 10), shade(JOINT, -0.05), { Material = ROCK_MAT })
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
