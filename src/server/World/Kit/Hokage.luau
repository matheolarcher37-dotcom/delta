-- Kit/Hokage : la MONTAGNE DES CHEFS du village ninja (inspirée du mont des Hokages).
--
-- Une grande falaise naturelle (strates de plusieurs tons, gros blocs arrondis ou anguleux,
-- fissures, corniches moussues, socle de blocs taillés, éboulis au pied, herbe, buissons et arbres
-- au sommet) dans laquelle sont sculptées 7 TÊTES sur deux rangs, comme sur le monument :
--
--        rang du haut :   Hashirama     Hiruzen        Tsunade       Naruto
--        rang du bas  :          Tobirama      Minato         Kakashi
--
-- Chaque tête est une vraie sculpture faite de volumes qui se fondent : crâne, front, arcades,
-- orbites creusées (plus sombres) avec le globe de l'œil et la paupière, nez (arête, bout, ailes),
-- pommettes, mâchoire en V, menton, lèvres, oreilles, cou. Les expressions sont calmes. Chaque chef
-- a sa coiffure (longs cheveux raides, épis dressés, mèches, frange séparée, épis penchés,
-- couronne d'épis...) et ses signes (bandeau frontal gravé, bouc, rides, marques des joues,
-- losange sur le front, masque, moustaches).
--
-- Tout est dans la même roche que la falaise (visages en calcaire taillé, plus lisse). Le modèle
-- est un emplacement remplaçable (DecorSlot "MontagneDesChefs") : un modèle du même nom rangé dans
-- ServerStorage > ModelesDeco le remplace au lancement.
--
-- Budget : ~1 450 pièces en tout (têtes ≈ 70 pièces chacune), arbres clonés depuis des modèles
-- maîtres. Le modèle est en LevelOfDetail « StreamingMesh » : de loin, Roblox l'affiche en un seul
-- maillage simplifié.

local Build = require(script.Parent.Parent.Parent.Modules.Build)
local Core = require(script.Parent.Core)
local Nature = require(script.Parent.Nature)

local Hokage = {}

local rgb = Color3.fromRGB
local V3 = Vector3.new
local shade = Core.shade

-- Palette de la roche (grès gris chaud). Les visages sont un peu plus clairs (pierre taillée).
local ROCK = rgb(148, 143, 135)
local STONE = rgb(164, 159, 151)
local HAIR = rgb(152, 147, 139)
local DARK = rgb(112, 104, 95)
local DEEP = rgb(70, 64, 58) -- creux : orbites, bouche, fissures
local STRATA = {
	rgb(144, 138, 128),
	rgb(160, 154, 144),
	rgb(132, 127, 119),
	rgb(154, 149, 140),
	rgb(138, 132, 122),
	rgb(166, 160, 150),
	rgb(126, 121, 114),
	rgb(150, 144, 133),
}
local GRASS = rgb(84, 132, 62)
local GRASS_LIGHT = rgb(104, 150, 76)
local MOSS = rgb(92, 124, 64)

local ROCK_MAT = Enum.Material.Rock
local CARVE_MAT = Enum.Material.Limestone
local STRATA_MAT = { Enum.Material.Rock, Enum.Material.Slate }

-- Dimensions de la falaise (studs). `cf` = pied de la falaise au centre, -Z local vers le village.
Hokage.Width = 480
Hokage.Height = 236
Hokage.Depth = 150

-- Unité de sculpture : une tête mesure ≈ 10 unités du menton au sommet du crâne (≈ 52 studs).
local U = 6.0
Hokage.Unit = U

-- Les 7 chefs : position (x, y = hauteur des yeux) sur la falaise et coiffure.
Hokage.Heads = {
	{ name = "Hashirama", x = -166, y = 160, style = "longs" },
	{ name = "Hiruzen", x = -58, y = 190, style = "epis" },
	{ name = "Tsunade", x = 56, y = 180, style = "raie" },
	{ name = "Naruto", x = 166, y = 154, style = "bandeau" },
	{ name = "Tobirama", x = -112, y = 100, style = "plaque" },
	{ name = "Minato", x = -2, y = 84, style = "meches" },
	{ name = "Kakashi", x = 110, y = 90, style = "penche" },
}

-- Encombrement de chaque coiffure (en unités, autour des yeux) : demi-largeur, haut, bas.
-- Sert à garder les blocs de roche autour des têtes sans les recouvrir.
local EXTENT = {
	longs = { 4.6, 6.4, -8.5 },
	epis = { 5.0, 9.0, -6.6 },
	raie = { 4.6, 6.6, -8.0 },
	bandeau = { 4.9, 8.0, -6.2 },
	plaque = { 4.5, 7.6, -6.2 },
	meches = { 4.8, 8.2, -6.2 },
	penche = { 4.8, 10.0, -6.2 },
}

-- Avancée de la paroi : les couches du haut reculent (falaise légèrement inclinée).
local function lean(y: number): number
	return (y / Hokage.Height) * 12
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

-- Volume arrondi (ellipsoïde) en unités de sculpture.
local function E(ctx: Ctx, name: string, sx: number, sy: number, sz: number, cf: CFrame, color: Color3?): Part
	ctx.count += 1
	local part = Core.ellipsoid(ctx.model, name, V3(sx, sy, sz) * ctx.u, cf, color or STONE, CARVE_MAT)
	part.CastShadow = sx * ctx.u > 3
	return part
end

-- Bloc taillé en unités de sculpture.
local function B(ctx: Ctx, name: string, sx: number, sy: number, sz: number, cf: CFrame, color: Color3?): Part
	ctx.count += 1
	return Build.deco(ctx.model, name, V3(sx, sy, sz) * ctx.u, cf, color or STONE, { Material = CARVE_MAT })
end

-- Pointe en volume (pyramide de 4 coins) : base au repère `cf`, pointe vers +Y local.
local function spike(ctx: Ctx, name: string, cf: CFrame, len: number, width: number, depth: number, color: Color3?)
	local u = ctx.u
	ctx.count += 4
	for _, part in Core.pyramid(ctx.model, name, cf, width * u, depth * u, len * u, color or HAIR, CARVE_MAT) do
		part.CanCollide = false
		part.CanQuery = false
	end
end

-- Mèche en volume : une « flamme » de pierre arrondie qui s'effile (trois fuseaux de plus en plus
-- fins), comme les épis doux d'une sculpture (base au repère `cf`, vers +Y local).
local function tuft(ctx: Ctx, name: string, cf: CFrame, len: number, width: number, depth: number)
	local u = ctx.u
	E(ctx, name, width * 1.15, len * 0.7, depth, cf * CFrame.new(0, len * 0.3 * u, 0), HAIR)
	E(ctx, name, width * 0.8, len * 0.62, depth * 0.76, cf * CFrame.new(0, len * 0.55 * u, -depth * 0.04 * u), HAIR)
	E(ctx, name, width * 0.44, len * 0.46, depth * 0.48, cf * CFrame.new(0, len * 0.77 * u, -depth * 0.08 * u), HAIR)
end

-- Mèche en volume (base enfouie dans la calotte, pointe vers +Y local après rotation `roll`
-- autour de l'axe avant et `rx` vers l'arrière) : un fuseau arrondi prolongé par une pointe.
local function lock(ctx: Ctx, x: number, y: number, z: number, roll: number, len: number, width: number, depth: number, rx: number?)
	tuft(ctx, "Meche", at(ctx, x, y, z, rx or 0, 0, roll), len, width, depth)
end

type FanSpec = {
	n: number,
	spread: number, -- demi-ouverture de l'éventail (radians)
	center: number?, -- inclinaison d'ensemble (coiffure penchée)
	y: number,
	r: number, -- rayon du cercle des racines
	z: number,
	len: number,
	fall: number, -- raccourcissement des mèches vers les côtés
	width: number,
	depth: number,
	rx: number?,
	phase: number?, -- décalage d'une demi-mèche (couches qui s'intercalent)
	jitter: number?,
}

-- Éventail de mèches dressées autour du haut du crâne (vu de face : silhouette en pointes).
local function fan(ctx: Ctx, o: FanSpec)
	local n = o.n
	for k = 0, n - 1 do
		local t = n > 1 and ((k + (o.phase or 0) * 0.5) / (n - 1 + (o.phase or 0))) * 2 - 1 or 0
		local theta = (o.center or 0) + t * o.spread + (o.jitter and math.sin(k * 2.7) * o.jitter or 0)
		local len = o.len - math.abs(t) * o.fall
		lock(ctx, -math.sin(theta) * o.r, o.y + math.cos(theta) * o.r * 0.45, o.z, theta, len, o.width, o.depth, o.rx)
	end
end

-- Bandeau frontal : un anneau qui épouse le crâne, avec sa plaque gravée bombée.
local function headband(ctx: Ctx, y: number, tilt: number?)
	local u = ctx.u
	local band = at(ctx, 0, y, 0, 0, 0, tilt or 0)
	E(ctx, "Bandeau", 7.5, 1.15, 7.7, band * CFrame.new(0, 0, 0.05 * u))
	E(ctx, "Plaque", 3.0, 1.45, 0.9, band * CFrame.new(0, 0, -3.62 * u))
	for _, s in { -1, 1 } do
		E(ctx, "Rivet", 0.24, 0.24, 0.16, band * CFrame.new(s * 1.12 * u, 0.4 * u, -4.04 * u), DARK)
		E(ctx, "Rivet", 0.24, 0.24, 0.16, band * CFrame.new(s * 1.12 * u, -0.4 * u, -4.04 * u), DARK)
	end
	-- symbole gravé de la feuille (spirale stylisée : un creux et sa pointe)
	E(ctx, "Symbole", 0.7, 0.7, 0.16, band * CFrame.new(-0.12 * u, 0, -4.06 * u), DARK)
	B(ctx, "Symbole", 0.18, 0.55, 0.12, band * CFrame.new(0.36 * u, 0.18 * u, -4.06 * u) * CFrame.Angles(0, 0, -0.6), DARK)
end

------------------------------------------------------------------------
-- Visage commun
------------------------------------------------------------------------

type FaceOptions = {
	brow: number?, -- inclinaison des sourcils (calme ≈ 0.05, sévère ≈ 0.2)
	browSize: number?, -- épaisseur des sourcils
	jaw: number?, -- largeur de la mâchoire
	mask: boolean?, -- masque sur le bas du visage
	soft: boolean?, -- traits plus fins (visage féminin)
	ears: boolean?,
	hideEye: number?, -- œil caché par le bandeau (-1 ou 1)
	lids: number?, -- paupières plus basses (regard calme, mi-clos)
	age: boolean?, -- rides, plis des joues
}

local function face(ctx: Ctx, o: FaceOptions)
	local jaw = o.jaw or 1
	local brow = o.brow or 0.06
	local browSize = o.browSize or 1
	local soft = o.soft == true
	local lids = o.lids or 0
	-- Grands volumes qui se fondent : crâne, front, milieu du visage, bas du visage, mâchoire en V.
	E(ctx, "Crane", 7.0, 7.6, 7.8, at(ctx, 0, 1.3, 1.3))
	E(ctx, "Front", 5.7, 3.6, 3.2, at(ctx, 0, 2.1, -2.1))
	E(ctx, "Visage", 6.0 * jaw, 4.2, 4.6, at(ctx, 0, -0.5, -1.6))
	E(ctx, "BasVisage", 4.8 * jaw, 4.4, 4.6, at(ctx, 0, -2.7, -1.5))
	for _, s in { -1, 1 } do
		E(ctx, "Machoire", 2.4 * jaw, 5.0, 4.4, at(ctx, s * 1.4 * jaw, -2.6, -0.9, 0, 0, -s * (soft and 0.36 or 0.3)))
		E(ctx, "Pommette", 1.6, 1.2, 1.3, at(ctx, s * 1.85 * jaw, -0.8, -2.85, 0, s * 0.3, 0))
	end
	E(ctx, "Menton", soft and 1.9 or 2.3, 1.7, 2.0, at(ctx, 0, -4.3, -2.85))
	-- arcades : un bourrelet qui fait de l'ombre sur les yeux, et la racine du nez
	E(ctx, "Arcades", 5.6, 1.15, 1.6, at(ctx, 0, 0.95, -3.3))
	E(ctx, "RacineNez", 1.2, 1.2, 1.0, at(ctx, 0, 0.4, -3.7))
	-- yeux : orbite creusée (sombre), globe, paupière, iris, sourcil
	for _, s in { -1, 1 } do
		E(ctx, "Orbite", 1.95, 1.05, 0.8, at(ctx, s * 1.35, 0.1, -3.5), shade(STONE, -0.34))
		if o.hideEye ~= s then
			E(ctx, "Oeil", 1.45, 0.7, 0.6, at(ctx, s * 1.35, 0.08, -3.72), shade(STONE, -0.05))
			E(ctx, "Paupiere", 1.6, 0.3 + lids * 0.7, 0.5, at(ctx, s * 1.35, 0.34 - lids * 0.35, -3.8, 0, 0, -s * 0.06))
			E(ctx, "Iris", 0.5, 0.5, 0.12, at(ctx, s * 1.28, 0.02, -3.98), shade(STONE, -0.12))
		end
		E(ctx, "Sourcil", 2.1, 0.42 * browSize, 0.6, at(ctx, s * 1.45, 1.12, -3.95, 0, s * 0.18, -s * brow))
	end
	if o.mask then
		-- masque de tissu : le bas du visage est lisse, le nez se devine sous le tissu
		E(ctx, "Masque", 5.4 * jaw, 4.9, 4.8, at(ctx, 0, -2.4, -1.75))
		E(ctx, "Nez", 1.3, 2.2, 1.3, at(ctx, 0, -0.7, -3.75, 0.3, 0, 0))
		B(ctx, "PliMasque", 4.4, 0.14, 0.4, at(ctx, 0, 0.05, -3.62), shade(STONE, -0.12))
		for _, s in { -1, 1 } do
			E(ctx, "PliMasque", 0.2, 2.2, 0.4, at(ctx, s * 1.05, -2.3, -3.9, 0, 0, s * 0.3), shade(STONE, -0.1))
		end
	else
		-- nez : arête, bout et ailes
		E(ctx, "Nez", soft and 0.8 or 0.95, 2.6, 1.1, at(ctx, 0, -0.6, -3.85, 0.3, 0, 0))
		E(ctx, "BoutNez", soft and 1.0 or 1.15, 0.85, 1.0, at(ctx, 0, -1.6, -4.12))
		for _, s in { -1, 1 } do
			E(ctx, "AileNez", 0.65, 0.55, 0.7, at(ctx, s * 0.5, -1.7, -3.9))
			E(ctx, "Narine", 0.28, 0.16, 0.2, at(ctx, s * 0.3, -1.98, -4.08), DEEP)
		end
		-- bouche : lèvres fines, fente sombre, petit creux sous la lèvre
		E(ctx, "LevreHaut", soft and 1.6 or 1.8, 0.4, 0.55, at(ctx, 0, -2.55, -3.78))
		B(ctx, "Bouche", soft and 1.45 or 1.65, 0.11, 0.3, at(ctx, 0, -2.76, -3.93), DEEP)
		E(ctx, "LevreBas", soft and 1.3 or 1.45, 0.42, 0.55, at(ctx, 0, -2.98, -3.72))
		E(ctx, "Creux", 1.0, 0.3, 0.3, at(ctx, 0, -3.42, -3.78), shade(STONE, -0.1))
		if o.age then
			for _, s in { -1, 1 } do
				E(ctx, "Pli", 0.2, 1.6, 0.35, at(ctx, s * 1.25, -2.25, -3.66, 0, 0, s * 0.35), DARK)
			end
		end
	end
	-- oreilles
	if o.ears ~= false then
		for _, s in { -1, 1 } do
			E(ctx, "Oreille", 0.85, 2.2, 1.5, at(ctx, s * 3.25, -0.1, 0.4, 0, s * 0.35, 0))
			E(ctx, "OreilleCreux", 0.35, 1.4, 0.8, at(ctx, s * 3.48, -0.1, 0.25, 0, s * 0.35, 0), DARK)
		end
	end
	-- cou et épaules qui sortent de la roche (les blocs autour les cachent en partie)
	E(ctx, "Cou", 3.8, 4.6, 3.8, at(ctx, 0, -5.1, 0.6))
end

------------------------------------------------------------------------
-- Coiffures et signes distinctifs
------------------------------------------------------------------------

-- Calotte de cheveux (le haut du crâne), naissance des cheveux vers y ≈ 3.3 sur le front.
local function capHair(ctx: Ctx, sy: number?, sx: number?)
	E(ctx, "Cheveux", sx or 7.6, sy or 6.0, 8.2, at(ctx, 0, 2.9, 1.1), HAIR)
end

local STYLES: { [string]: (Ctx) -> () } = {}

-- Hashirama : longs cheveux raides séparés au milieu, qui tombent derrière les épaules.
STYLES.longs = function(ctx)
	face(ctx, { brow = 0.05, jaw = 1.02, lids = 0.06 })
	capHair(ctx, 6.4, 7.9)
	for _, s in { -1, 1 } do
		-- frange séparée en deux pans qui encadrent le front
		E(ctx, "Frange", 3.2, 1.9, 2.4, at(ctx, s * 1.65, 3.55, -2.5, 0, 0, s * 0.42), HAIR)
		-- rideaux de cheveux le long des joues jusqu'aux épaules
		E(ctx, "Rideau", 2.2, 10.6, 3.4, at(ctx, s * 3.75, -2.7, 0.3, 0, 0, s * 0.04), HAIR)
		E(ctx, "Meche", 1.4, 7.4, 2.0, at(ctx, s * 3.3, -1.6, -1.3, 0, 0, s * 0.05), HAIR)
		-- pointes des mèches en bas
		lock(ctx, s * 3.6, -6.8, -0.4, math.pi - s * 0.06, 2.2, 2.0, 1.7)
	end
	B(ctx, "Raie", 0.18, 1.6, 0.3, at(ctx, 0, 4.3, -2.3, -0.6, 0, 0), DARK)
	E(ctx, "Nuque", 7.6, 10, 4.0, at(ctx, 0, -2.4, 2.8), HAIR)
end

-- Hiruzen : grands épis dressés en flamme (deux couches), front ridé, bouc pointu (sage et calme).
STYLES.epis = function(ctx)
	face(ctx, { brow = 0.1, browSize = 1.2, lids = 0.12, age = true })
	capHair(ctx, 6.0)
	-- couche arrière : longues mèches qui montent en éventail
	fan(ctx, { n = 6, spread = 0.95, y = 3.4, r = 3.0, z = 1.4, len = 6.4, fall = 2.4, width = 2.7, depth = 2.3, rx = -0.18, phase = 0.5 })
	-- couche avant : mèches plus courtes qui encadrent le front
	fan(ctx, { n = 7, spread = 1.15, y = 3.1, r = 3.2, z = 0.5, len = 4.6, fall = 1.6, width = 2.5, depth = 2.1, rx = -0.1 })
	-- naissance des cheveux : petites mèches dressées au-dessus du front dégarni
	for k = -2, 2 do
		lock(ctx, k * 1.05, 3.85, -1.9, -k * 0.3, 2.2, 1.6, 1.4, -0.35)
	end
	-- rides du front et petites pattes d'oie
	for _, y in { 2.2, 2.7 } do
		E(ctx, "Ride", 2.4, 0.14, 0.3, at(ctx, 0, y, -3.6), shade(STONE, -0.14))
	end
	for _, s in { -1, 1 } do
		B(ctx, "Ride", 0.7, 0.1, 0.2, at(ctx, s * 2.35, 0.0, -3.42, 0, s * 0.5, s * 0.3), DARK)
	end
	-- bouc et moustache fine
	lock(ctx, 0, -4.2, -2.75, math.pi, 1.9, 1.5, 1.1, 0.35)
	E(ctx, "Moustache", 2.4, 0.38, 0.55, at(ctx, 0, -2.32, -3.86), HAIR)
end

-- Tsunade : cheveux lisses, frange séparée au milieu, longs rideaux, losange sur le front.
STYLES.raie = function(ctx)
	face(ctx, { brow = 0.03, browSize = 0.75, soft = true, jaw = 0.94, ears = false, lids = 0.05 })
	capHair(ctx, 6.6)
	for _, s in { -1, 1 } do
		E(ctx, "Frange", 3.4, 2.4, 2.5, at(ctx, s * 1.85, 3.45, -2.45, 0, 0, s * 0.55), HAIR)
		E(ctx, "Rideau", 2.4, 10.0, 3.6, at(ctx, s * 3.6, -2.2, -0.1, 0, 0, s * 0.03), HAIR)
		E(ctx, "Meche", 1.4, 6.6, 2.0, at(ctx, s * 3.15, -0.8, -1.7, 0, 0, s * 0.06), HAIR)
		lock(ctx, s * 3.5, -6.0, -0.4, math.pi - s * 0.08, 2.2, 1.9, 1.6)
	end
	E(ctx, "Nuque", 7.8, 9.0, 4.0, at(ctx, 0, -1.9, 2.8), HAIR)
	B(ctx, "Losange", 0.5, 0.5, 0.25, at(ctx, 0, 2.0, -3.72, 0, 0, math.rad(45)), DARK)
end

-- Naruto : couronne d'épis tout autour au-dessus du bandeau, mèches le long des joues,
-- moustaches sur les joues.
STYLES.bandeau = function(ctx)
	face(ctx, { brow = 0.08, jaw = 0.98 })
	capHair(ctx, 6.0)
	fan(ctx, { n = 7, spread = 1.0, y = 3.2, r = 3.1, z = 1.5, len = 5.0, fall = 1.0, width = 2.6, depth = 2.2, rx = -0.25, phase = 0.5 })
	fan(ctx, { n = 9, spread = 1.45, y = 2.9, r = 3.4, z = 0.4, len = 4.0, fall = 0.6, width = 2.3, depth = 2.0, rx = -0.08 })
	for _, s in { -1, 1 } do
		-- mèches qui tombent devant les oreilles
		lock(ctx, s * 3.0, 2.0, -2.0, math.pi - s * 0.12, 3.6, 1.6, 1.3)
		for k = 0, 2 do
			B(ctx, "Moustache", 1.4, 0.15, 0.22, at(ctx, s * 2.0, -1.5 - k * 0.4, -3.4, 0, s * 0.4, s * (k - 1) * 0.18), DARK)
		end
	end
	headband(ctx, 2.75)
end

-- Tobirama : cheveux courts hérissés en désordre, bandeau à plaque, marques sur les joues et le menton.
STYLES.plaque = function(ctx)
	face(ctx, { brow = 0.18, browSize = 1.1, jaw = 1.04 })
	capHair(ctx, 6.4)
	fan(ctx, { n = 6, spread = 0.9, y = 3.5, r = 2.9, z = 1.2, len = 4.0, fall = 0.8, width = 2.6, depth = 2.3, rx = -0.3, phase = 0.5 })
	fan(ctx, { n = 8, spread = 1.3, y = 3.2, r = 3.3, z = 0.5, len = 3.2, fall = 0.5, width = 2.2, depth = 2.0, rx = -0.15, jitter = 0.18 })
	for _, s in { -1, 1 } do
		B(ctx, "Marque", 0.3, 1.5, 0.25, at(ctx, s * 1.62, -1.5, -3.55, 0, s * 0.3, s * 0.08), DARK)
	end
	B(ctx, "Marque", 0.32, 0.9, 0.25, at(ctx, 0, -4.35, -3.86), DARK)
	headband(ctx, 2.8)
end

-- Minato : grandes mèches en pointes écartées sur les côtés (crinière), frange qui tombe sur le
-- front, longues mèches le long du visage jusqu'à la mâchoire.
STYLES.meches = function(ctx)
	face(ctx, { brow = 0.05, lids = 0.04 })
	capHair(ctx, 6.4, 8.0)
	fan(ctx, { n = 7, spread = 1.25, y = 3.0, r = 3.3, z = 1.4, len = 5.6, fall = 1.2, width = 2.7, depth = 2.3, rx = -0.2, phase = 0.5 })
	fan(ctx, { n = 6, spread = 1.75, y = 2.4, r = 3.7, z = 0.7, len = 4.6, fall = 0.4, width = 2.4, depth = 2.1, rx = -0.05 })
	-- frange : mèches pointues qui tombent sur le front
	local bangs = { { -1.7, 0.3 }, { -0.6, 0.12 }, { 0.5, -0.1 }, { 1.6, -0.28 } }
	for i, b in bangs do
		lock(ctx, b[1], 4.4, -2.55 - (i % 2) * 0.15, math.pi + b[2], 2.6 + (i % 2) * 0.5, 1.7, 1.3, 0.2)
	end
	-- longues mèches qui encadrent le visage
	for _, s in { -1, 1 } do
		lock(ctx, s * 3.15, 2.6, -1.6, math.pi - s * 0.06, 6.2, 1.8, 1.5)
	end
end

-- Kakashi : grands épis penchés d'un côté, bandeau incliné sur un œil, masque.
STYLES.penche = function(ctx)
	face(ctx, { brow = 0.04, mask = true, hideEye = 1, lids = 0.14 })
	capHair(ctx, 6.0)
	fan(ctx, { n = 6, spread = 0.7, center = 0.45, y = 3.3, r = 3.1, z = 1.3, len = 6.6, fall = 1.8, width = 2.8, depth = 2.4, rx = -0.2, phase = 0.5 })
	fan(ctx, { n = 6, spread = 0.8, center = 0.35, y = 3.0, r = 3.3, z = 0.5, len = 5.0, fall = 1.4, width = 2.5, depth = 2.1, rx = -0.08 })
	for k = 0, 2 do
		lock(ctx, -1.8 + k * 1.5, 3.9, -2.4, math.pi + 0.35, 2.4, 1.6, 1.3, 0.25)
	end
	headband(ctx, 1.65, -0.3)
end

-- Sculpte une tête au repère `cf` (entre les yeux, -Z vers l'avant). Renvoie le nombre de pièces.
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
	return Hokage.Height - 22 * t * t - 46 * t ^ 6 + 6 * math.sin(x * 0.045) + 4 * math.cos(x * 0.11)
end
Hokage.topAt = topAt

-- Distance (dans le plan de la falaise) à la tête la plus proche, normalisée par son encombrement
-- (< 1 : dans la silhouette de la tête).
local function nearHead(x: number, y: number): number
	local best = math.huge
	for _, h in Hokage.Heads do
		local e = EXTENT[h.style] or EXTENT.longs
		local dx = (x - h.x) / (e[1] * U)
		local cy = h.y + (e[2] + e[3]) / 2 * U
		local dy = (y - cy) / ((e[2] - e[3]) / 2 * U)
		best = math.min(best, math.sqrt(dx * dx + dy * dy))
	end
	return best
end
Hokage.nearHead = nearHead

local function cliffBody(model: Model, cf: CFrame, rng: Random): { number }
	local half = Hokage.Width / 2
	local depth = Hokage.Depth
	-- strates horizontales communes à toute la falaise (comme de vraies couches de roche)
	local bands = { 0 }
	local y = 0
	while y < Hokage.Height + 30 do
		y += rng:NextNumber(20, 30)
		table.insert(bands, y)
	end
	local cols = 12
	local colW = Hokage.Width / cols
	for c = 0, cols - 1 do
		local x0 = -half + (c + 0.5) * colW
		local top = topAt(x0) + rng:NextNumber(-5, 5)
		local dip = rng:NextNumber(-0.02, 0.02)
		for b = 1, #bands - 1 do
			local y0 = bands[b] + rng:NextNumber(-2, 2)
			local y1 = math.min(bands[b + 1] + rng:NextNumber(-2, 2), top)
			if y0 >= top - 2 then
				break
			end
			local h = y1 - y0
			local front = lean(y0) + rng:NextNumber(-2.5, 2.5)
			Build.part(
				model,
				"Strate",
				V3(colW + rng:NextNumber(2, 8), h + 1.5, depth - front),
				cf * CFrame.new(x0 + rng:NextNumber(-2, 2), y0 + h / 2, front + (depth - front) / 2) * CFrame.Angles(0, rng:NextNumber(-0.035, 0.035), dip),
				shade(STRATA[(b - 1) % #STRATA + 1], rng:NextNumber(-0.03, 0.03)),
				{ Material = STRATA_MAT[(b % 3 == 0) and 2 or 1] }
			)
		end
		-- herbe du sommet (déborde un peu sur le bord avant) et bosses herbeuses
		Build.part(
			model,
			"Sommet",
			V3(colW + 6, 6, depth - 6),
			cf * CFrame.new(x0, top + 1, lean(top) + 2 + (depth - 6) / 2) * CFrame.Angles(0, rng:NextNumber(-0.03, 0.03), dip),
			shade(GRASS, rng:NextNumber(-0.05, 0.04)),
			{ Material = Enum.Material.Grass }
		)
		Core.ellipsoid(
			model,
			"SommetBosse",
			V3(colW * 1.3, 16, 70),
			cf * CFrame.new(x0 + rng:NextNumber(-8, 8), top + 3, 70 + rng:NextNumber(0, 40)),
			GRASS_LIGHT,
			Enum.Material.Grass
		)
		-- lèvre d'herbe et de mousse qui pend sur le bord
		Build.deco(
			model,
			"BordHerbe",
			V3(colW * rng:NextNumber(0.7, 1.05), 4, 5),
			cf * CFrame.new(x0 + rng:NextNumber(-6, 6), top - 0.8, lean(top) + 0.5) * CFrame.Angles(0.4, 0, rng:NextNumber(-0.06, 0.06)),
			MOSS,
			{ Material = Enum.Material.Grass }
		)
	end
	-- flancs : pentes de roche qui descendent jusqu'au sol aux deux bouts
	for _, s in { -1, 1 } do
		local edge = topAt(s * half) - 10
		for k = 0, 2 do
			local w = 36 - k * 6
			local h = edge * (1 - k * 0.28)
			local wedgeCF = cf * CFrame.new(s * (half + w / 2 + k * 18 - 6), h / 2, 70 - k * 4) * CFrame.Angles(0, s * math.pi / 2, 0)
			Build.wedge(model, "Flanc", V3(depth - k * 16, h, w), wedgeCF, shade(STRATA[(k + 2) % #STRATA + 1], -0.02), { Material = ROCK_MAT })
			Build.part(model, "FlancHerbe", V3(w * 0.6, 3, depth - k * 16), cf * CFrame.new(s * (half + k * 18 + 4), h - 2, 70 - k * 4) * CFrame.Angles(0, 0, -s * 0.9), GRASS, {
				Material = Enum.Material.Grass,
				CanCollide = false,
			})
			-- gros blocs éboulés sur le flanc
			Core.ellipsoid(
				model,
				"Bloc",
				V3(26 - k * 4, 18 - k * 3, 22),
				cf * CFrame.new(s * (half + k * 18 + 2), 6 - k, -8 - k * 4) * CFrame.Angles(0, 0, rng:NextNumber(-0.4, 0.4)),
				shade(STRATA[(k + 4) % #STRATA + 1], 0.02),
				ROCK_MAT
			)
		end
	end
	return bands
end

-- Un bloc de roche de la paroi : arrondi (ellipsoïde enfoncé) ou anguleux (bloc incliné),
-- parfois accompagné d'un plus petit (amas).
local function boulder(model: Model, cf: CFrame, rng: Random, px: number, py: number, size: number)
	local front = lean(py)
	local tone = shade(STRATA[rng:NextInteger(1, #STRATA)]:Lerp(ROCK, 0.4), rng:NextNumber(-0.02, 0.05))
	local roll = rng:NextNumber()
	if roll < 0.75 then
		Core.ellipsoid(
			model,
			"Bloc",
			V3(size * rng:NextNumber(1.05, 1.4), size * rng:NextNumber(0.8, 1.0), size * 0.62),
			cf * CFrame.new(px, py, front + size * 0.12) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.6, 0.6)),
			tone,
			ROCK_MAT
		)
	else
		Build.deco(
			model,
			"Bloc",
			V3(size * rng:NextNumber(0.9, 1.25), size * rng:NextNumber(0.65, 0.9), size * 0.8),
			cf * CFrame.new(px, py, front + size * 0.22) * CFrame.Angles(rng:NextNumber(-0.18, 0.1), rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.3, 0.3)),
			tone,
			{ Material = ROCK_MAT }
		)
	end
	if rng:NextNumber() < 0.28 then
		local s2 = size * rng:NextNumber(0.4, 0.6)
		Core.ellipsoid(
			model,
			"Bloc",
			V3(s2 * 1.2, s2, s2 * 0.8),
			cf * CFrame.new(px + rng:NextNumber(-0.5, 0.5) * size, py + rng:NextNumber(-0.45, 0.45) * size, front - size * 0.05),
			shade(tone, rng:NextNumber(-0.06, 0.06)),
			ROCK_MAT
		)
	end
end

-- Relief de la paroi : blocs serrés tout autour des têtes (comme sur le monument), corniches
-- moussues, fissures et creux sombres derrière les têtes.
local function cliffFace(model: Model, cf: CFrame, rng: Random, bands: { number })
	local half = Hokage.Width / 2
	local step = 18
	local row = 0
	for y = 26, Hokage.Height + 10, step * 0.8 do
		row += 1
		for x = -half + 8 + (row % 2) * step / 2, half - 6, step do
			local px = x + rng:NextNumber(-5, 5)
			local py = y + rng:NextNumber(-4, 4)
			local d = nearHead(px, py)
			if py < topAt(px) - 8 and math.abs(px) < half - 12 and d > 1.05 and rng:NextNumber() < 0.9 then
				-- plus petits contre les têtes : ils les encadrent sans les cacher
				local size = rng:NextNumber(17, 28) * math.clamp(0.6 + (d - 1.05) * 0.9, 0.6, 1)
				boulder(model, cf, rng, px, py, size)
			end
		end
	end
	-- collerette de petits blocs sous chaque menton (la tête sort de la roche)
	for _, h in Hokage.Heads do
		for k = -3, 3 do
			local px = h.x + k * 1.25 * U + rng:NextNumber(-2, 2)
			local py = h.y - (7.0 - math.abs(k) * 0.35) * U + rng:NextNumber(-2, 2)
			boulder(model, cf, rng, px, py, rng:NextNumber(11, 16))
		end
	end
	-- corniches le long des strates, certaines couvertes de mousse
	for b = 2, #bands - 1 do
		local by = bands[b]
		for _ = 1, 3 do
			local x = rng:NextNumber(-half + 20, half - 20)
			if by < topAt(x) - 14 and nearHead(x, by) > 1.25 then
				local w = rng:NextNumber(18, 36)
				local front = lean(by) - 6
				Build.deco(
					model,
					"Corniche",
					V3(w, 2.6, 8),
					cf * CFrame.new(x, by, front) * CFrame.Angles(0, rng:NextNumber(-0.06, 0.06), 0),
					shade(STRATA[(b % #STRATA) + 1], 0.06),
					{
						Material = Enum.Material.Slate,
					}
				)
				if rng:NextNumber() < 0.65 then
					Core.ellipsoid(model, "Mousse", V3(w * 0.7, 3, 7), cf * CFrame.new(x + rng:NextNumber(-4, 4), by + 1.6, front), MOSS, Enum.Material.Grass)
				end
			end
		end
	end
	-- fissures verticales sombres entre les blocs
	for _ = 1, 20 do
		local x = rng:NextNumber(-half + 8, half - 8)
		local len = rng:NextNumber(18, 44)
		local y = rng:NextNumber(30, topAt(x) * 0.8)
		if nearHead(x, y) > 1.2 and y + len / 2 < topAt(x) - 6 then
			Build.deco(
				model,
				"Fissure",
				V3(rng:NextNumber(0.8, 1.4), len, 2),
				cf * CFrame.new(x, y, lean(y) - 0.4) * CFrame.Angles(0, 0, rng:NextNumber(-0.25, 0.25)),
				shade(DARK, -0.25),
				{
					Material = Enum.Material.Slate,
					CastShadow = false,
				}
			)
		end
	end
	-- creux sombre derrière chaque tête : elle semble sortir d'une niche de la roche
	for _, h in Hokage.Heads do
		local e = EXTENT[h.style] or EXTENT.longs
		local cy = h.y + (e[2] + e[3]) / 2 * U
		Core.ellipsoid(model, "Niche", V3(e[1] * 2.3 * U, (e[2] - e[3]) * 1.04 * U, 3 * U), cf * CFrame.new(h.x, cy, lean(h.y) + 0.6 * U), shade(ROCK, -0.3), ROCK_MAT)
	end
end

-- Pied de la falaise : gros blocs taillés en deux rangées (comme le socle du monument) et éboulis.
local function cliffBase(model: Model, cf: CFrame, rng: Random)
	local half = Hokage.Width / 2
	local x = -half - 6
	while x < half + 6 do
		local w = rng:NextNumber(22, 36)
		local h = rng:NextNumber(16, 22)
		Build.part(
			model,
			"Socle",
			V3(w - 1.5, h, 24),
			cf * CFrame.new(x + w / 2, h / 2 - 1, -10 + rng:NextNumber(-2, 2)) * CFrame.Angles(0, rng:NextNumber(-0.05, 0.05), rng:NextNumber(-0.03, 0.03)),
			shade(STRATA[rng:NextInteger(1, #STRATA)], rng:NextNumber(-0.06, 0.0)),
			{ Material = ROCK_MAT }
		)
		x += w
	end
	x = -half + 4
	while x < half - 4 do
		local w = rng:NextNumber(18, 30)
		local h = rng:NextNumber(12, 17)
		local cx = x + w / 2
		if nearHead(cx, 30) > 1.0 then
			Build.part(
				model,
				"Socle",
				V3(w - 1.5, h, 20),
				cf * CFrame.new(cx, 20 + h / 2 - 2, -4 + rng:NextNumber(-2, 2)) * CFrame.Angles(0, rng:NextNumber(-0.05, 0.05), rng:NextNumber(-0.04, 0.04)),
				shade(STRATA[rng:NextInteger(1, #STRATA)], rng:NextNumber(-0.04, 0.02)),
				{ Material = ROCK_MAT }
			)
		end
		x += w
	end
	-- éboulis devant le socle, avec un peu de mousse
	for _ = 1, 14 do
		Nature.rock(model, (cf * CFrame.new(rng:NextNumber(-half - 10, half + 10), 0, rng:NextNumber(-38, -24))).Position, rng:NextNumber(5, 12), {
			rng = rng,
			color = shade(DARK, rng:NextNumber(-0.05, 0.1)),
			slot = "RocherFalaise",
			moss = MOSS,
		})
	end
end

-- Végétation : arbres et buissons sur le sommet (près du bord pour être vus d'en bas), touffes
-- de mousse accrochées à la paroi. Rien juste derrière les épis qui dépassent du sommet.
local function cliffGreenery(model: Model, cf: CFrame, rng: Random)
	local half = Hokage.Width / 2
	local function clear(x: number): boolean
		for _, h in Hokage.Heads do
			local e = EXTENT[h.style] or EXTENT.longs
			if h.y + e[2] * U > topAt(x) - 30 and math.abs(x - h.x) < e[1] * U + 8 then
				return false
			end
		end
		return true
	end
	local count = 26
	for i = 1, count do
		local x = -half + 14 + (i - 0.5) / count * (Hokage.Width - 28) + rng:NextNumber(-8, 8)
		local z = lean(topAt(x)) + ((i % 3 == 0) and rng:NextNumber(40, 100) or rng:NextNumber(14, 30))
		if clear(x) or z > 60 then
			local species = rng:NextNumber() < 0.55 and "ArbreFeuillu" or "Sapin"
			Nature.tree(species, model, (cf * CFrame.new(x, topAt(x) + 2, z)).Position, {
				rng = rng,
				height = rng:NextNumber(38, 64),
				palette = "foret",
				detail = "low",
			})
		end
	end
	for _ = 1, 12 do
		local x = rng:NextNumber(-half + 10, half - 10)
		if clear(x) then
			Nature.bush(model, (cf * CFrame.new(x, topAt(x) + 1, lean(topAt(x)) + rng:NextNumber(6, 12))).Position, {
				rng = rng,
				height = rng:NextNumber(6, 10),
				palette = "foret",
			})
		end
	end
	-- coulées de végétation qui pendent sur la paroi (lierre)
	for _ = 1, 10 do
		local x = rng:NextNumber(-half + 16, half - 16)
		local top = topAt(x)
		if nearHead(x, top - 20) > 1.2 then
			local len = rng:NextNumber(18, 40)
			-- grappe de lobes de plus en plus petits vers le bas (pas une simple capsule)
			local lobes = rng:NextInteger(3, 5)
			for k = 0, lobes - 1 do
				local t = k / lobes
				local w = rng:NextNumber(9, 14) * (1 - t * 0.55)
				local y = top + 1 - t * len
				Core.ellipsoid(
					model,
					"Lierre",
					V3(w, len / lobes * 1.7, 2.6),
					cf * CFrame.new(x + rng:NextNumber(-3, 3), y, lean(y) - 0.4) * CFrame.Angles(0, 0, rng:NextNumber(-0.3, 0.3)),
					shade(MOSS, rng:NextNumber(-0.16, 0.02)),
					Enum.Material.LeafyGrass
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
	local bands = cliffBody(model, cf, rng)
	cliffFace(model, cf, rng, bands)
	cliffBase(model, cf, rng)
	local heads = Instance.new("Model")
	heads.Name = "Tetes"
	heads.Parent = model
	local total = 0
	for _, h in Hokage.Heads do
		local headModel = Instance.new("Model")
		headModel.Name = h.name
		headModel.Parent = heads
		-- la tête avance devant la paroi et penche un peu vers le village (regard vers le bas)
		local headCF = cf * CFrame.new(h.x, h.y, lean(h.y) - 0.8 * U) * CFrame.Angles(-0.08, 0, 0)
		local count = Hokage.head(headModel, headCF, h.style)
		headModel:SetAttribute("Pieces", count)
		total += count
	end
	heads:SetAttribute("Pieces", total)
	cliffGreenery(model, cf, rng)
	return model
end

return Hokage
