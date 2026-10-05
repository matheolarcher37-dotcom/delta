-- Kit/Hokage : la MONTAGNE DES CHEFS du village ninja (inspirée du mont des Hokages).
--
-- Une grande falaise naturelle (strates de plusieurs tons, blocs, fissures, corniches moussues,
-- éboulis au pied, herbe et arbres au sommet) dans laquelle sont sculptées 7 TÊTES sur deux rangs,
-- disposées comme sur le monument de référence :
--
--        rang du haut :   Hashirama   Hiruzen          Tsunade          Naruto
--        rang du bas  :          Tobirama      Minato          Kakashi
--
-- Chaque tête est une vraie sculpture faite de volumes : crâne, front, arcades, orbites creusées
-- (plus sombres), yeux et paupières, nez (arête + bout + ailes), pommettes, mâchoire en V, menton,
-- lèvres, oreilles, cou et épaules qui se fondent dans la roche. Chaque chef a sa coiffure
-- (cheveux longs, pointes, mèches, bandeau frontal, cheveux en épis inclinés...) et ses signes
-- (bouc, rides, marques des joues, losange sur le front, masque).
--
-- Tout est dans la même roche que la falaise. Le modèle est un emplacement remplaçable
-- (DecorSlot "MontagneDesChefs") : un modèle du même nom rangé dans ServerStorage > ModelesDeco
-- le remplace au lancement.

local Build = require(script.Parent.Parent.Parent.Modules.Build)
local Core = require(script.Parent.Core)
local Nature = require(script.Parent.Nature)

local Hokage = {}

local rgb = Color3.fromRGB
local V3 = Vector3.new
local shade = Core.shade

-- Palette de la roche (grès gris chaud, comme une falaise sculptée).
local ROCK = rgb(160, 149, 133)
local STONE = rgb(170, 160, 145) -- surface taillée des visages (un peu plus claire)
local DARK = rgb(118, 109, 99)
local DEEP = rgb(78, 72, 66) -- creux : orbites, bouche, fissures
local STRATA = {
	rgb(150, 139, 124),
	rgb(166, 155, 139),
	rgb(138, 129, 117),
	rgb(158, 150, 137),
	rgb(144, 133, 119),
	rgb(172, 162, 147),
	rgb(134, 126, 115),
	rgb(156, 145, 129),
}
local GRASS = rgb(86, 134, 64)
local GRASS_LIGHT = rgb(104, 150, 76)
local MOSS = rgb(96, 126, 66)

local ROCK_MAT = Enum.Material.Rock
local CARVE_MAT = Enum.Material.Rock
local STRATA_MAT = { Enum.Material.Rock, Enum.Material.Slate }

-- Dimensions de la falaise (studs). `cf` = pied de la falaise au centre, -Z local vers le village.
Hokage.Width = 470
Hokage.Height = 212
Hokage.Depth = 150

-- Unité de sculpture : hauteur d'une tête ≈ 11 unités (menton → sommet du crâne).
local U = 4.4

-- Les 7 chefs : position (x, y = centre du visage) sur la falaise, et style.
Hokage.Heads = {
	{ name = "Hashirama", x = -150, y = 152, style = "longs" },
	{ name = "Tobirama", x = -94, y = 112, style = "plaque" },
	{ name = "Hiruzen", x = -50, y = 176, style = "epis" },
	{ name = "Minato", x = -16, y = 76, style = "meches" },
	{ name = "Tsunade", x = 46, y = 176, style = "raie" },
	{ name = "Kakashi", x = 86, y = 90, style = "penche" },
	{ name = "Naruto", x = 150, y = 150, style = "bandeau" },
}

------------------------------------------------------------------------
-- Outils de sculpture (repère d'une tête : origine au centre du visage, -Z = vers l'avant)
------------------------------------------------------------------------

type Ctx = { model: Model, cf: CFrame, u: number, count: number }

local function at(ctx: Ctx, x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	local u = ctx.u
	return ctx.cf * CFrame.new(x * u, y * u, z * u) * CFrame.Angles(rx or 0, ry or 0, rz or 0)
end

-- Volume arrondi (ellipsoïde) en unités de sculpture.
local function E(ctx: Ctx, name: string, sx: number, sy: number, sz: number, cf: CFrame, color: Color3?): Part
	ctx.count += 1
	return Core.ellipsoid(ctx.model, name, V3(sx, sy, sz) * ctx.u, cf, color or STONE, CARVE_MAT)
end

-- Bloc taillé en unités de sculpture.
local function B(ctx: Ctx, name: string, sx: number, sy: number, sz: number, cf: CFrame, color: Color3?): Part
	ctx.count += 1
	return Build.deco(ctx.model, name, V3(sx, sy, sz) * ctx.u, cf, color or STONE, { Material = CARVE_MAT })
end

-- Coin (WedgePart) : arête haute à l'arrière, pente vers l'avant-bas (profil d'un nez).
local function W(ctx: Ctx, name: string, sx: number, sy: number, sz: number, cf: CFrame, color: Color3?): WedgePart
	ctx.count += 1
	local part = Build.wedge(ctx.model, name, V3(sx, sy, sz) * ctx.u, cf, color or STONE, { Material = CARVE_MAT })
	part.CanCollide = false
	part.CanQuery = false
	return part
end

-- Mèche plate en triangle (deux coins dos à dos) : base au repère `cf`, pointe vers +Y local,
-- face large vers l'avant. `len`, `width`, `thick` en unités.
local function blade(ctx: Ctx, name: string, cf: CFrame, len: number, width: number, thick: number, color: Color3?)
	local u = ctx.u
	local size = V3(thick, len, width / 2) * u
	for _, side in { -1, 1 } do
		ctx.count += 1
		local part = Build.wedge(
			ctx.model,
			name,
			size,
			cf * CFrame.new(side * width / 4 * u, len / 2 * u, 0) * CFrame.Angles(0, -side * math.pi / 2, 0),
			color or STONE,
			{ Material = CARVE_MAT }
		)
		part.CanCollide = false
		part.CanQuery = false
	end
end

-- Pointe en volume (pyramide de 4 coins) : base au repère `cf`, pointe vers +Y local.
local function spike(ctx: Ctx, name: string, cf: CFrame, len: number, width: number, depth: number, color: Color3?)
	local u = ctx.u
	ctx.count += 4
	for _, part in Core.pyramid(ctx.model, name, cf, width * u, depth * u, len * u, color or STONE, CARVE_MAT) do
		part.CanCollide = false
		part.CanQuery = false
	end
end

-- Bandeau frontal (trois segments qui épousent le front) avec sa plaque gravée.
local function headband(ctx: Ctx, y: number, tilt: number?)
	local rz = tilt or 0
	local band = at(ctx, 0, y, 0, 0, 0, rz)
	B(ctx, "Bandeau", 5.4, 1.15, 1.2, band * CFrame.new(0, 0, -3.75 * ctx.u))
	for _, side in { -1, 1 } do
		B(ctx, "Bandeau", 2.6, 1.15, 1.2, band * CFrame.new(side * 3.15 * ctx.u, 0, -2.75 * ctx.u) * CFrame.Angles(0, side * 0.75, 0))
		B(ctx, "Bandeau", 1.4, 1.1, 2.6, band * CFrame.new(side * 3.9 * ctx.u, 0, -0.9 * ctx.u))
	end
	B(ctx, "Plaque", 2.9, 1.45, 0.4, band * CFrame.new(0, 0, -4.42 * ctx.u))
	-- symbole gravé de la feuille (spirale stylisée : un creux et sa pointe)
	E(ctx, "Symbole", 0.75, 0.75, 0.2, band * CFrame.new(-0.1 * ctx.u, 0.05 * ctx.u, -4.62 * ctx.u), DARK)
	B(ctx, "Symbole", 0.2, 0.6, 0.15, band * CFrame.new(0.42 * ctx.u, 0.2 * ctx.u, -4.62 * ctx.u) * CFrame.Angles(0, 0, -0.6), DARK)
end

------------------------------------------------------------------------
-- Visage commun
------------------------------------------------------------------------

type FaceOptions = {
	brow: number?, -- inclinaison des sourcils (calme ≈ 0.05, sévère ≈ 0.2)
	browSize: number?, -- épaisseur des arcades
	jaw: number?, -- largeur de la mâchoire
	mask: boolean?, -- masque sur le bas du visage
	soft: boolean?, -- traits plus fins (visage féminin)
	ears: boolean?,
	hideEye: number?, -- œil caché par le bandeau (-1 ou 1)
}

local function face(ctx: Ctx, o: FaceOptions)
	local jaw = o.jaw or 1
	local brow = o.brow or 0.06
	local browSize = o.browSize or 1
	-- Volumes principaux. Le visage est fait de grands volumes qui se fondent (crâne, haut du
	-- visage, mâchoire en V) ; les détails (arcades, pommettes, lèvres...) ne dépassent que de
	-- quelques dixièmes d'unité, comme une sculpture.
	E(ctx, "Crane", 7.0, 8.0, 7.4, at(ctx, 0, 1.0, 0.9))
	E(ctx, "Visage", 6.0 * jaw, 6.6, 5.4, at(ctx, 0, 0.3, -1.0))
	for _, s in { -1, 1 } do
		-- mâchoire : deux volumes inclinés qui se rejoignent au menton (visage en V)
		E(ctx, "Machoire", 2.7 * jaw, 5.8, 4.6, at(ctx, s * 0.95 * jaw, -2.3, -1.25, 0, 0, s * (o.soft and 0.4 or 0.32)))
		E(ctx, "Joue", 2.2, 2.2, 2.4, at(ctx, s * 1.75 * jaw, -1.0, -2.25))
	end
	E(ctx, "Menton", o.soft and 1.7 or 2.1, 1.5, 1.9, at(ctx, 0, -4.45, -2.5))
	E(ctx, "Bas", 2.8, 2.6, 2.4, at(ctx, 0, -2.7, -2.2))
	-- front et arcades : un bourrelet qui fait de l'ombre sur les yeux
	E(ctx, "Front", 5.4, 2.8, 2.6, at(ctx, 0, 2.3, -2.45))
	E(ctx, "Arcades", 5.5, 1.0 * browSize, 1.5, at(ctx, 0, 1.15, -3.18))
	-- yeux : orbite creusée (sombre), globe, paupière, pupille, sourcil
	for _, s in { -1, 1 } do
		E(ctx, "Orbite", 2.0, 1.05, 0.6, at(ctx, s * 1.35, 0.4, -3.22), DEEP)
		if o.hideEye ~= s then
			E(ctx, "Oeil", 1.55, 0.72, 0.5, at(ctx, s * 1.35, 0.36, -3.36), shade(STONE, -0.06))
			E(ctx, "Paupiere", 1.75, 0.36, 0.5, at(ctx, s * 1.35, 0.64, -3.42, 0, 0, s * -0.06))
			B(ctx, "Pupille", 0.36, 0.42, 0.16, at(ctx, s * 1.22, 0.33, -3.6), DEEP)
		end
		E(ctx, "Sourcil", 2.2, 0.42 * browSize, 0.6, at(ctx, s * 1.4, 1.3, -3.72, 0, 0, -s * brow))
	end
	if o.mask then
		-- masque de tissu : le bas du visage est lisse, le nez se devine
		E(ctx, "Masque", 5.6 * jaw, 4.8, 4.6, at(ctx, 0, -2.5, -1.6))
		E(ctx, "Nez", 1.2, 2.0, 1.2, at(ctx, 0, -0.7, -3.55, 0.3, 0, 0))
		B(ctx, "PliMasque", 3.6, 0.14, 0.3, at(ctx, 0, -0.15, -3.55), shade(STONE, -0.14))
	else
		-- nez : arête, bout et ailes
		E(ctx, "Nez", o.soft and 0.75 or 0.9, 2.5, 1.1, at(ctx, 0, -0.45, -3.72, 0.28, 0, 0))
		E(ctx, "BoutNez", o.soft and 0.95 or 1.1, 0.8, 0.95, at(ctx, 0, -1.5, -3.98))
		for _, s in { -1, 1 } do
			E(ctx, "Narine", 0.62, 0.5, 0.6, at(ctx, s * 0.48, -1.62, -3.7))
		end
		-- bouche : lèvres fines et fente sombre, plis légers
		E(ctx, "LevreHaut", o.soft and 1.6 or 1.85, 0.42, 0.55, at(ctx, 0, -2.55, -3.32))
		B(ctx, "Bouche", o.soft and 1.5 or 1.75, 0.12, 0.3, at(ctx, 0, -2.78, -3.42), DEEP)
		E(ctx, "LevreBas", o.soft and 1.35 or 1.5, 0.46, 0.55, at(ctx, 0, -3.02, -3.24))
	end
	-- oreilles
	if o.ears ~= false then
		for _, s in { -1, 1 } do
			E(ctx, "Oreille", 0.8, 2.2, 1.5, at(ctx, s * 3.15, 0.3, 0.3, 0, s * 0.35, 0))
			E(ctx, "OreilleCreux", 0.35, 1.4, 0.8, at(ctx, s * 3.4, 0.3, 0.15, 0, s * 0.35, 0), DARK)
		end
	end
	-- cou et épaules qui sortent de la roche
	E(ctx, "Cou", 3.4, 6.0, 3.4, at(ctx, 0, -5.4, 0.6))
	E(ctx, "Epaules", 11.0, 4.2, 5.0, at(ctx, 0, -8.2, 1.4), ROCK)
end

------------------------------------------------------------------------
-- Coiffures et signes distinctifs
------------------------------------------------------------------------

local function capHair(ctx: Ctx, sy: number?)
	E(ctx, "Cheveux", 7.9, sy or 6.0, 8.0, at(ctx, 0, 2.7, 1.0))
end

local STYLES: { [string]: (Ctx) -> () } = {}

-- 1er : longs cheveux raides séparés au milieu, bandeau frontal.
STYLES.longs = function(ctx)
	face(ctx, { brow = 0.08, jaw = 1.02 })
	capHair(ctx, 6.4)
	for _, s in { -1, 1 } do
		E(ctx, "Frange", 3.6, 2.0, 2.4, at(ctx, s * 1.75, 3.7, -2.55, 0, 0, s * 0.32))
		E(ctx, "Rideau", 2.3, 10.5, 3.4, at(ctx, s * 3.75, -2.6, 0.2, 0, 0, s * 0.05))
		E(ctx, "Meche", 1.6, 7.0, 2.2, at(ctx, s * 3.35, -1.2, -1.5, 0, 0, s * 0.04))
	end
	E(ctx, "Nuque", 7.6, 10, 4.0, at(ctx, 0, -2.0, 2.8))
	headband(ctx, 2.75)
end

-- 2e : cheveux courts rejetés en arrière, bandeau, marques sur les joues et le menton.
STYLES.plaque = function(ctx)
	face(ctx, { brow = 0.2, browSize = 1.1 })
	capHair(ctx, 6.6)
	for k = -3, 3 do
		local cf = at(ctx, k * 0.95, 4.6 - math.abs(k) * 0.35, 0.6, -0.9, 0, -k * 0.22)
		spike(ctx, "Epi", cf, 3.0, 1.8, 1.6)
	end
	for _, s in { -1, 1 } do
		B(ctx, "Marque", 0.32, 1.5, 0.25, at(ctx, s * 1.65, -1.55, -3.6, 0, 0, s * 0.08), DARK)
	end
	B(ctx, "Marque", 0.32, 1.0, 0.25, at(ctx, 0, -4.45, -3.78), DARK)
	headband(ctx, 2.8)
end

-- 3e : grands épis dressés, front ridé, bouc pointu.
STYLES.epis = function(ctx)
	face(ctx, { brow = 0.14, browSize = 1.15 })
	capHair(ctx, 6.2)
	local n = 9
	for k = 0, n - 1 do
		local t = (k / (n - 1)) * 2 - 1
		local cf = at(ctx, t * 2.6, 4.4 + (1 - math.abs(t)) * 0.8, 0.6 + math.abs(t) * 0.4, -0.25, 0, -t * 0.95)
		spike(ctx, "Epi", cf, 4.6 - math.abs(t) * 1.4, 2.2, 2.0)
	end
	for k = -2, 2 do
		local cf = at(ctx, k * 1.0, 4.1, -1.6, -0.45, 0, -k * 0.35)
		spike(ctx, "Epi", cf, 2.6, 1.6, 1.4)
	end
	-- rides du front et plis des joues
	for _, y in { 2.05, 2.6 } do
		B(ctx, "Ride", 2.8, 0.12, 0.25, at(ctx, 0, y, -3.88), DARK)
	end
	for _, s in { -1, 1 } do
		E(ctx, "Pli", 0.25, 1.8, 0.4, at(ctx, s * 1.15, -2.25, -3.62, 0, 0, s * 0.35), DARK)
	end
	-- bouc
	local goatee = at(ctx, 0, -5.0, -2.95) * CFrame.Angles(0, 0, math.pi)
	blade(ctx, "Bouc", goatee, 3.0, 1.7, 1.0)
	E(ctx, "Moustache", 2.6, 0.45, 0.6, at(ctx, 0, -2.5, -3.62))
end

-- 4e : mèches en pointes qui tombent sur le front, longues mèches le long du visage.
STYLES.meches = function(ctx)
	face(ctx, { brow = 0.06 })
	capHair(ctx, 6.4)
	for k = -3, 3 do
		local cf = at(ctx, k * 1.05, 5.0 - math.abs(k) * 0.3, 1.2, -0.7, 0, -k * 0.3)
		spike(ctx, "Epi", cf, 3.2, 2.0, 1.8)
	end
	local bangs = { { -2.2, 0.45 }, { -1.1, 0.2 }, { 0.1, -0.05 }, { 1.2, -0.25 }, { 2.3, -0.45 } }
	for i, b in bangs do
		local cf = at(ctx, b[1], 4.4, -3.0 - (i % 2) * 0.15, 0.25, 0, math.pi + b[2])
		blade(ctx, "Frange", cf, 2.6 + (i % 2) * 0.6, 1.6, 0.8)
	end
	for _, s in { -1, 1 } do
		local cf = at(ctx, s * 3.25, 1.6, -2.0, 0, 0, math.pi - s * 0.08)
		blade(ctx, "Meche", cf, 6.0, 1.7, 1.0)
	end
end

-- 5e : cheveux lisses avec raie au milieu, longs rideaux, losange sur le front.
STYLES.raie = function(ctx)
	face(ctx, { brow = 0.04, browSize = 0.75, soft = true, jaw = 0.95, ears = false })
	capHair(ctx, 6.6)
	for _, s in { -1, 1 } do
		E(ctx, "Frange", 3.7, 2.3, 2.6, at(ctx, s * 1.95, 3.55, -2.45, 0, 0, s * 0.5))
		E(ctx, "Rideau", 2.4, 10.0, 3.6, at(ctx, s * 3.65, -2.0, -0.2, 0, 0, s * 0.04))
		E(ctx, "Meche", 1.5, 6.5, 2.0, at(ctx, s * 3.2, -0.6, -1.8, 0, 0, s * 0.06))
	end
	E(ctx, "Nuque", 7.8, 9.0, 4.0, at(ctx, 0, -1.6, 2.8))
	B(ctx, "Losange", 0.55, 0.55, 0.25, at(ctx, 0, 2.05, -3.92, 0, 0, math.rad(45)), DARK)
end

-- 6e : cheveux en épis penchés d'un côté, bandeau incliné sur un œil, masque.
STYLES.penche = function(ctx)
	face(ctx, { brow = 0.04, mask = true, hideEye = 1 })
	capHair(ctx, 6.0)
	for k = 0, 6 do
		local t = k / 6
		local cf = at(ctx, -2.6 + t * 5.0, 4.2 + math.sin(t * math.pi) * 0.9, 0.5, -0.2, 0, 0.55 - t * 0.35)
		spike(ctx, "Epi", cf, 5.0 + math.sin(t * math.pi) * 2.5, 2.4, 2.0)
	end
	for k = 0, 2 do
		local cf = at(ctx, -1.8 + k * 1.6, 3.8, -2.2, 0.35, 0, math.pi + 0.35)
		blade(ctx, "Frange", cf, 2.2, 1.5, 0.8)
	end
	headband(ctx, 1.75, -0.32)
end

-- 7e : couronne d'épis au-dessus du bandeau, mèches sur les côtés, moustaches sur les joues.
STYLES.bandeau = function(ctx)
	face(ctx, { brow = 0.1 })
	capHair(ctx, 6.0)
	local n = 9
	for k = 0, n - 1 do
		local t = (k / (n - 1)) * 2 - 1
		local cf = at(ctx, t * 3.0, 3.9 + (1 - math.abs(t)) * 0.9, -0.6 + math.abs(t) * 0.6, -0.15, 0, -t * 0.85)
		spike(ctx, "Epi", cf, 3.8 - math.abs(t) * 0.8, 2.0, 1.8)
	end
	for _, s in { -1, 1 } do
		local cf = at(ctx, s * 2.85, 2.4, -2.9, 0, 0, math.pi - s * 0.1)
		blade(ctx, "Meche", cf, 3.4, 1.4, 0.8)
		for k = 0, 2 do
			B(ctx, "Moustache", 1.5, 0.16, 0.22, at(ctx, s * 2.05, -1.55 - k * 0.42, -3.4, 0, s * 0.35, s * (k - 1) * 0.18), DARK)
		end
	end
	headband(ctx, 2.75)
end

-- Sculpte une tête au repère `cf` (centre du visage, -Z vers l'avant). Renvoie le nombre de pièces.
function Hokage.head(model: Model, cf: CFrame, style: string, u: number?): number
	local ctx: Ctx = { model = model, cf = cf, u = u or U, count = 0 }
	local build = STYLES[style] or STYLES.longs
	build(ctx)
	return ctx.count
end

------------------------------------------------------------------------
-- Falaise
------------------------------------------------------------------------

-- Hauteur du sommet de la falaise en `x` (bosselée, plus haute au centre).
local function topAt(x: number): number
	local t = x / (Hokage.Width / 2)
	return Hokage.Height - 36 * t * t + 6 * math.sin(x * 0.045) + 4 * math.cos(x * 0.11)
end
Hokage.topAt = topAt

-- Distance (dans le plan de la falaise) au visage le plus proche, normalisée par sa taille.
local function nearHead(x: number, y: number): number
	local best = math.huge
	for _, h in Hokage.Heads do
		local dx = (x - h.x) / (4.6 * U)
		local dy = (y - (h.y - 1.0 * U)) / (7.6 * U)
		best = math.min(best, math.sqrt(dx * dx + dy * dy))
	end
	return best
end

local function cliffBody(model: Model, cf: CFrame, rng: Random)
	local half = Hokage.Width / 2
	local depth = Hokage.Depth
	-- strates horizontales communes à toute la falaise (comme de vraies couches de roche)
	local bands = { 0 }
	local y = 0
	while y < Hokage.Height + 30 do
		y += rng:NextNumber(20, 32)
		table.insert(bands, y)
	end
	local cols = 12
	local colW = Hokage.Width / cols
	for c = 0, cols - 1 do
		local x0 = -half + (c + 0.5) * colW
		local top = topAt(x0) + rng:NextNumber(-6, 6)
		local dip = rng:NextNumber(-0.025, 0.025)
		for b = 1, #bands - 1 do
			local y0 = bands[b] + rng:NextNumber(-2.5, 2.5)
			local y1 = math.min(bands[b + 1] + rng:NextNumber(-2.5, 2.5), top)
			if y0 >= top - 2 then
				break
			end
			local h = y1 - y0
			-- les couches du haut reculent un peu (falaise légèrement inclinée vers l'arrière)
			local front = rng:NextNumber(-3, 3) + (y0 / Hokage.Height) * 10
			Build.part(
				model,
				"Strate",
				V3(colW + rng:NextNumber(2, 9), h + 1.5, depth - front),
				cf * CFrame.new(x0 + rng:NextNumber(-2, 2), y0 + h / 2, front + (depth - front) / 2) * CFrame.Angles(
					0,
					rng:NextNumber(-0.04, 0.04),
					dip
				),
				shade(STRATA[(b - 1) % #STRATA + 1], rng:NextNumber(-0.03, 0.03)),
				{ Material = STRATA_MAT[(b % 3 == 0) and 2 or 1] }
			)
		end
		-- herbe du sommet (déborde un peu sur le bord avant)
		Build.part(
			model,
			"Sommet",
			V3(colW + 6, 6, depth - 6),
			cf * CFrame.new(x0, top + 1, 6 + (depth - 6) / 2) * CFrame.Angles(0, rng:NextNumber(-0.03, 0.03), dip),
			shade(GRASS, rng:NextNumber(-0.05, 0.04)),
			{ Material = Enum.Material.Grass }
		)
		Core.ellipsoid(model, "SommetBosse", V3(colW * 1.3, 18, 80), cf * CFrame.new(x0 + rng:NextNumber(-8, 8), top + 3, 60 + rng:NextNumber(0, 40)), GRASS_LIGHT, Enum.Material.Grass)
		-- lèvre d'herbe qui pend sur le bord
		Build.deco(
			model,
			"BordHerbe",
			V3(colW * rng:NextNumber(0.6, 1.0), 3.5, 5),
			cf * CFrame.new(x0 + rng:NextNumber(-6, 6), top - 0.5, 4 + (top / Hokage.Height) * 10 - 2) * CFrame.Angles(0.35, 0, rng:NextNumber(-0.06, 0.06)),
			MOSS,
			{ Material = Enum.Material.Grass }
		)
	end
	-- flancs : pentes de roche qui descendent jusqu'au sol aux deux bouts
	for _, s in { -1, 1 } do
		local edge = topAt(s * half) - 10
		for k = 0, 2 do
			local w = 34 - k * 6
			local h = edge * (1 - k * 0.28)
			local wedgeCF = cf * CFrame.new(s * (half + w / 2 + k * 18 - 6), h / 2, 70 - k * 4) * CFrame.Angles(0, s * math.pi / 2, 0)
			Build.wedge(model, "Flanc", V3(depth - k * 16, h, w), wedgeCF, shade(STRATA[(k + 2) % #STRATA + 1], -0.02), { Material = ROCK_MAT })
			Build.part(model, "FlancHerbe", V3(w * 0.6, 3, depth - k * 16), cf * CFrame.new(s * (half + k * 18 + 4), h - 2, 70 - k * 4) * CFrame.Angles(0, 0, -s * 0.9), GRASS, {
				Material = Enum.Material.Grass,
				CanCollide = false,
			})
		end
	end
	return bands
end

-- Relief de la paroi : blocs arrondis, blocs anguleux, corniches, fissures (hors des visages).
local function cliffFace(model: Model, cf: CFrame, rng: Random, bands: { number })
	local half = Hokage.Width / 2
	-- blocs sur une grille décalée, comme les rochers qui entourent les têtes du monument
	local step = 24
	local row = 0
	for y = 30, Hokage.Height + 10, step * 0.85 do
		row += 1
		for x = -half + 10 + (row % 2) * step / 2, half - 8, step do
			local px = x + rng:NextNumber(-6, 6)
			local py = y + rng:NextNumber(-5, 5)
			local d = nearHead(px, py)
			if py < topAt(px) - 10 and d > 1.12 and rng:NextNumber() < 0.82 then
				local size = rng:NextNumber(16, 28) * (d < 1.6 and 0.85 or 1)
				local front = (py / Hokage.Height) * 10 - 2
				local tone = shade(STRATA[rng:NextInteger(1, #STRATA)], rng:NextNumber(-0.02, 0.05))
				if rng:NextNumber() < 0.6 then
					Core.ellipsoid(
						model,
						"Bloc",
						V3(size * rng:NextNumber(0.9, 1.3), size * rng:NextNumber(0.7, 1.0), size * 0.7),
						cf * CFrame.new(px, py, front) * CFrame.Angles(0, 0, rng:NextNumber(-0.5, 0.5)),
						tone,
						ROCK_MAT
					)
				else
					Build.deco(
						model,
						"Bloc",
						V3(size * rng:NextNumber(0.8, 1.2), size * rng:NextNumber(0.6, 0.9), size * 0.6),
						cf * CFrame.new(px, py, front + 2) * CFrame.Angles(rng:NextNumber(-0.25, 0.1), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.35, 0.35)),
						tone,
						{ Material = ROCK_MAT }
					)
				end
			end
		end
	end
	-- corniches le long des strates, certaines couvertes de mousse
	for b = 2, #bands - 1 do
		local by = bands[b]
		for _ = 1, 3 do
			local x = rng:NextNumber(-half + 20, half - 20)
			if by < topAt(x) - 14 and nearHead(x, by) > 1.2 then
				local w = rng:NextNumber(18, 40)
				local front = (by / Hokage.Height) * 10 - 4
				Build.deco(model, "Corniche", V3(w, 2.6, 7), cf * CFrame.new(x, by, front) * CFrame.Angles(0, rng:NextNumber(-0.06, 0.06), 0), shade(STRATA[(b % #STRATA) + 1], 0.06), {
					Material = Enum.Material.Slate,
				})
				if rng:NextNumber() < 0.6 then
					Core.ellipsoid(model, "Mousse", V3(w * 0.7, 3, 6), cf * CFrame.new(x + rng:NextNumber(-4, 4), by + 1.6, front), MOSS, Enum.Material.Grass)
				end
			end
		end
	end
	-- fissures verticales sombres
	for _ = 1, 22 do
		local x = rng:NextNumber(-half + 8, half - 8)
		local y0 = rng:NextNumber(10, topAt(x) * 0.7)
		local len = rng:NextNumber(18, 50)
		local y = y0 + len / 2
		if nearHead(x, y) > 1.15 and y + len / 2 < topAt(x) - 6 then
			local front = (y / Hokage.Height) * 10 - 3.2
			Build.deco(model, "Fissure", V3(rng:NextNumber(1.2, 2.4), len, 3), cf * CFrame.new(x, y, front) * CFrame.Angles(0, 0, rng:NextNumber(-0.25, 0.25)), DEEP, {
				Material = ROCK_MAT,
			})
		end
	end
	-- auréole sombre derrière chaque tête : la tête semble sortir d'un creux de la roche
	for _, h in Hokage.Heads do
		Core.ellipsoid(model, "Niche", V3(11.5 * U, 13.5 * U, 4 * U), cf * CFrame.new(h.x, h.y - 0.6 * U, (h.y / Hokage.Height) * 10 + 1.2 * U), DARK, ROCK_MAT)
	end
end

-- Pied de la falaise : gros blocs taillés en deux rangées (comme le socle du monument) et éboulis.
local function cliffBase(model: Model, cf: CFrame, rng: Random)
	local half = Hokage.Width / 2
	local x = -half - 6
	while x < half + 6 do
		local w = rng:NextNumber(22, 38)
		local h = rng:NextNumber(16, 24)
		local cx = x + w / 2
		Build.part(model, "Socle", V3(w - 1.5, h, 22), cf * CFrame.new(cx, h / 2 - 1, -8 + rng:NextNumber(-2, 2)) * CFrame.Angles(0, rng:NextNumber(-0.06, 0.06), rng:NextNumber(-0.03, 0.03)), shade(STRATA[rng:NextInteger(1, #STRATA)], rng:NextNumber(-0.06, 0.0)), {
			Material = ROCK_MAT,
		})
		x += w
	end
	x = -half + 4
	while x < half - 4 do
		local w = rng:NextNumber(18, 30)
		local h = rng:NextNumber(12, 18)
		local cx = x + w / 2
		if nearHead(cx, 30) > 1.0 then
			Build.part(model, "Socle", V3(w - 1.5, h, 18), cf * CFrame.new(cx, 22 + h / 2 - 2, -2 + rng:NextNumber(-2, 2)) * CFrame.Angles(0, rng:NextNumber(-0.05, 0.05), rng:NextNumber(-0.04, 0.04)), shade(STRATA[rng:NextInteger(1, #STRATA)], rng:NextNumber(-0.04, 0.02)), {
				Material = ROCK_MAT,
			})
		end
		x += w
	end
	-- éboulis devant
	for _ = 1, 16 do
		Nature.rock(model, (cf * CFrame.new(rng:NextNumber(-half - 10, half + 10), 0, rng:NextNumber(-34, -18))).Position, rng:NextNumber(5, 13), {
			rng = rng,
			color = shade(DARK, rng:NextNumber(-0.05, 0.08)),
			slot = "RocherFalaise",
			moss = MOSS,
		})
	end
end

-- Végétation : arbres et buissons sur le sommet (surtout près du bord pour être vus d'en bas),
-- touffes accrochées à la paroi.
local function cliffGreenery(model: Model, cf: CFrame, rng: Random)
	local half = Hokage.Width / 2
	for i = 1, 22 do
		local x = -half + 12 + (i - 0.5) / 22 * (Hokage.Width - 24) + rng:NextNumber(-8, 8)
		local z = (i % 3 == 0) and rng:NextNumber(40, 110) or rng:NextNumber(14, 34)
		-- pas d'arbre juste derrière les épis qui dépassent du sommet
		if math.abs(x - Hokage.Heads[3].x) > 26 then
			local species = rng:NextNumber() < 0.55 and "ArbreFeuillu" or "Sapin"
			Nature.tree(species, model, (cf * CFrame.new(x, topAt(x) + 2, z)).Position, {
				rng = rng,
				height = rng:NextNumber(24, 38),
				palette = "foret",
				detail = "low",
			})
		end
	end
	for _ = 1, 10 do
		local x = rng:NextNumber(-half + 10, half - 10)
		if math.abs(x - Hokage.Heads[3].x) > 26 then
			Nature.bush(model, (cf * CFrame.new(x, topAt(x) + 1, rng:NextNumber(6, 12))).Position, { rng = rng, height = rng:NextNumber(5, 8), palette = "foret" })
		end
	end
end

-- Construit la montagne complète au repère `cf` (pied au centre, -Z local vers le village).
function Hokage.mountain(parent: Instance, cf: CFrame, rng: Random): Model
	local model = Core.slot(parent, "MontagneDesChefs", cf, Hokage.Height + 30)
	pcall(function()
		model.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	end)
	local bands = cliffBody(model, cf, rng)
	cliffFace(model, cf, rng, bands)
	cliffBase(model, cf, rng)
	local heads = Instance.new("Model")
	heads.Name = "Tetes"
	heads.Parent = model
	for _, h in Hokage.Heads do
		local headModel = Instance.new("Model")
		headModel.Name = h.name
		headModel.Parent = heads
		local front = (h.y / Hokage.Height) * 10
		local count = Hokage.head(headModel, cf * CFrame.new(h.x, h.y, front - 1.4 * U), h.style)
		headModel:SetAttribute("Pieces", count)
	end
	cliffGreenery(model, cf, rng)
	return model
end

return Hokage
