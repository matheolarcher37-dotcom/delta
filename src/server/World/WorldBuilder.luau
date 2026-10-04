-- Construit la partie FIXE de la carte, en TAILLE RÉELLE (perso R6 ≈ 5,3 studs, porte ≈ 8 studs) :
--   * une grande île (herbe texturée, taches de couleur, touffes, herbes hautes, fleurs), avec du
--     RELIEF : collines douces entre les bases, caps rocheux et falaises en strates au bord de
--     l'île, plages semées de rochers, un étang avec son pont arqué et un ruisseau qui descend à
--     la mer, un sentier de forêt qui fait le tour de l'île ;
--   * le HUB au centre : place pavée à rosace, fontaine à deux vasques et jets d'eau, grand
--     CRISTAL en gemme taillée qui tourne au-dessus, 6 stands de marché détaillés avec leurs
--     vendeurs, arches d'entrée qui affichent l'univers actuel et le compte à rebours, muret de
--     pierres, cerisiers, lanternes de pierre, bancs et lampadaires ;
--   * l'anneau d'univers (son décor change toutes les 30 min, voir UniverseDecor) et l'arène du boss ;
--   * les rues pavées à bordures vers les bases, la promenade circulaire, le coin des échanges et
--     les panneaux.
--
-- Tout le sol (herbe, collines, falaises, pavés, eau, berges...) est marqué par un rôle
-- (Core.solRole) : sa couleur et son matériau changent avec l'univers (theme.sol). La nature,
-- les bâtiments, l'horizon, le ciel et l'ambiance sont dans le décor de l'univers.
--
-- Si la carte a déjà été construite dans le fichier (Workspace.World avec l'attribut "Baked"),
-- elle est gardée telle quelle : tes modifications faites dans Studio sont conservées.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local CharacterBuilder = require(Shared.Modules.CharacterBuilder)
local Build = require(script.Parent.Parent.Modules.Build)
local Core = require(script.Parent.Kit.Core)
local Nature = require(script.Parent.Kit.Nature)
local Archi = require(script.Parent.Kit.Archi)
local Props = require(script.Parent.Kit.Props)
local Relief = require(script.Parent.Kit.Relief)

local WorldBuilder = {}

local rgb = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local shade = Core.shade

local GRASS = rgb(96, 140, 64)
local STONE = rgb(196, 190, 180)
local STONE_DARK = rgb(140, 134, 126)
local WOOD = rgb(146, 100, 64)
local WOOD_DARK = rgb(88, 60, 42)
local SAND = rgb(226, 206, 156)
local SAND_WET = rgb(196, 176, 130)
local ROCK = rgb(132, 124, 114)

-- Hauteurs du dessus des couches de sol (évite le scintillement entre surfaces superposées).
local TOP_ISLAND = 0
local TOP_PATCH = 0.06
local TOP_RING = 0.08
local TOP_PATH = 0.2
local TOP_HUB = 0.25

local rng = Random.new(20261003)
local polar = Layout.polar

local function polarRad(angle: number, radius: number, y: number?): Vector3
	return Vector3.new(math.cos(angle) * radius, y or 0, math.sin(angle) * radius)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Disque horizontal (cylindre couché) dont le dessus est à `top`.
local function slab(parent: Instance, name: string, radius: number, top: number, thickness: number, color: Color3, material: Enum.Material, center: Vector3?): Part
	local c = center or Vector3.zero
	local part = Build.part(parent, name, Vector3.new(thickness, radius * 2, radius * 2), CFrame.new(c.X, top - thickness / 2, c.Z) * CFrame.Angles(0, 0, math.rad(90)), color, {
		Material = material,
		Shape = Enum.PartType.Cylinder,
	})
	part.CastShadow = false
	return part
end

------------------------------------------------------------------------
-- Relief (positions fixes, partagées avec les décors d'univers)
------------------------------------------------------------------------

-- Collines : { angle (degrés), rayon, rayon d'emprise au sol, hauteur }.
WorldBuilder.Hills = {
	{ -12, 528, 50, 11 },
	{ 13, 530, 44, 9 },
	{ 48, 520, 52, 13 },
	{ 70, 535, 46, 10 },
	{ 108, 528, 50, 12 },
	{ 131, 522, 44, 9 },
	{ 165, 534, 48, 12 },
	{ 195, 532, 50, 13 },
	{ 228, 526, 46, 10 },
	{ 251, 534, 50, 12 },
	{ 290, 528, 48, 11 },
	{ 312, 520, 52, 13 },
	{ 60, 405, 32, 6 },
	{ 300, 405, 34, 7 },
}

-- Caps rocheux au bord de l'île : arcs { de, à } en degrés.
WorldBuilder.CliffArcs = { { -28, 16 }, { 98, 142 }, { 204, 236 } }
WorldBuilder.CliffRadius = 628

-- Étang et ruisseau.
WorldBuilder.Pond = { center = polar(180, 482), radius = 26 }
WorldBuilder.StreamPoints = {
	polar(180, 506),
	polar(181.5, 540),
	polar(178.5, 572),
	polar(181, 604),
	polar(179, 640),
	polar(180, 690),
}
WorldBuilder.TrailRadius = 590
WorldBuilder.BridgeAt = polar(180, WorldBuilder.TrailRadius)

local function hillInfo(h)
	local center = polar(h[1], h[2])
	local rb, height = h[3], h[4]
	local R = (rb * rb + height * height) / (2 * height)
	return center, rb, height, R
end

-- Hauteur du sol (collines comprises) à la verticale de `pos`.
function WorldBuilder.groundY(pos: Vector3): number
	local y = TOP_ISLAND
	for _, h in WorldBuilder.Hills do
		local center, rb, height, R = hillInfo(h)
		local d = (flat(pos) - center).Magnitude
		if d < rb then
			y = math.max(y, height - R + math.sqrt(R * R - d * d))
		end
	end
	return y
end

-- Vrai si `pos` est dans un cap rocheux (bord de l'île).
function WorldBuilder.inCliffs(pos: Vector3, margin: number?): boolean
	local r = flat(pos).Magnitude
	if r < WorldBuilder.CliffRadius - 24 - (margin or 0) then
		return false
	end
	local deg = math.deg(math.atan2(pos.Z, pos.X))
	for _, arc in WorldBuilder.CliffArcs do
		local d = (deg - arc[1]) % 360
		if d <= (arc[2] - arc[1]) % 360 then
			return true
		end
	end
	return false
end

-- Vrai si `pos` est sur l'eau (étang, ruisseau) ou trop près.
function WorldBuilder.nearWater(pos: Vector3, margin: number?): boolean
	local m = margin or 0
	local p = flat(pos)
	if (p - WorldBuilder.Pond.center).Magnitude < WorldBuilder.Pond.radius * 1.6 + 6 + m then
		return true
	end
	local pts = WorldBuilder.StreamPoints
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		if (p - (a + ab * t)).Magnitude < 10 + m then
			return true
		end
	end
	return false
end

-- Vrai si `pos` est sur le sentier de forêt.
function WorldBuilder.onTrail(pos: Vector3, margin: number?): boolean
	return math.abs(flat(pos).Magnitude - WorldBuilder.TrailRadius) < 5 + (margin or 0)
end

local function nearSpecial(position: Vector3, margin: number): boolean
	local p = flat(position)
	for _, spot in { Layout.TradeCorner, Layout.Leaderboard, Layout.InfoBoard } do
		if (p - spot).Magnitude < margin then
			return true
		end
	end
	return false
end

-- Vrai si l'endroit de l'île (hors anneau) est libre : pas sur une base, un chemin, un lieu
-- spécial, l'eau, le sentier ou les caps rocheux.
local function isFree(position: Vector3, margin: number): boolean
	local r = flat(position).Magnitude
	if r < Layout.WalkwayOuter + 4 + margin or r > Layout.IslandRadius - 10 then
		return false
	end
	return not Layout.nearPlot(position, margin)
		and not Layout.onPath(position, margin + 2)
		and not nearSpecial(position, 34 + margin)
		and not WorldBuilder.nearWater(position, margin)
		and not WorldBuilder.onTrail(position, margin * 0.5)
		and not WorldBuilder.inCliffs(position, margin)
end
WorldBuilder.isFree = isFree

------------------------------------------------------------------------
-- Île : sol, collines, caps rocheux, plages, eau, sentier
------------------------------------------------------------------------

local function buildIsland(world: Folder)
	local ground = Build.folder(world, "Ground")
	Core.solRole(slab(ground, "Grass", Layout.IslandRadius, TOP_ISLAND, 6, GRASS, Enum.Material.Grass), "herbe")
	Core.solRole(slab(ground, "Beach", Layout.BeachRadius, TOP_ISLAND - 0.35, 6, SAND, Enum.Material.Sand), "sable")
	Core.solRole(slab(ground, "WetSand", Layout.BeachRadius + 26, TOP_ISLAND - 1.1, 6, SAND_WET, Enum.Material.Sand), "sable", -0.12)
	-- Océan (remplacé par de la vraie eau Terrain quand le jeu tourne) : 4 dalles de 2048.
	for _, offset in { Vector3.new(-1024, 0, -1024), Vector3.new(1024, 0, -1024), Vector3.new(-1024, 0, 1024), Vector3.new(1024, 0, 1024) } do
		local ocean = Build.part(world, "Ocean", Vector3.new(2048, 2, 2048), CFrame.new(offset + Vector3.new(0, -2.2, 0)), rgb(40, 120, 170), {
			Material = Enum.Material.Glass,
			Transparency = 0.2,
			Reflectance = 0.08,
			CanCollide = false,
			CastShadow = false,
		})
		ocean.CanQuery = false
		Core.solRole(ocean, "mer")
		Build.part(world, "OceanFloor", Vector3.new(2048, 2, 2048), CFrame.new(offset + Vector3.new(0, -16, 0)), rgb(30, 90, 130), {
			Material = Enum.Material.Sand,
			CastShadow = false,
		})
	end
	-- Murs invisibles pour ne pas tomber à l'eau.
	local count = 64
	local radius = Layout.BeachRadius + 14
	for i = 0, count - 1 do
		local angle = (i + 0.5) / count * math.pi * 2
		local cf = CFrame.lookAt(polarRad(angle, radius, 40), Vector3.new(0, 40, 0))
		Build.part(ground, "Boundary", Vector3.new(2 * math.pi * radius / count + 2, 90, 2), cf, Color3.new(1, 1, 1), { Transparency = 1, CastShadow = false })
	end

	-- Collines douces (vraies sphères à moitié enterrées : on marche dessus).
	local relief = Build.folder(ground, "Relief")
	for i, h in WorldBuilder.Hills do
		local center, _, height, R = hillInfo(h)
		local hill = Build.part(relief, "Hill", Vector3.new(R * 2, R * 2, R * 2), CFrame.new(center + UP * (height - R)), GRASS, {
			Material = Enum.Material.Grass,
			Shape = Enum.PartType.Ball,
		})
		hill.CastShadow = false
		Core.solRole(hill, i % 3 == 0 and "herbe3" or "herbe", (i % 2 == 0) and 0.03 or -0.03)
	end

	-- Caps rocheux et falaises en strates au bord de l'île, rochers dans l'eau.
	local cliffs = Build.folder(ground, "Falaises")
	for _, arc in WorldBuilder.CliffArcs do
		local span = (arc[2] - arc[1]) % 360
		local steps = math.max(2, math.floor(span / 7))
		for k = 0, steps do
			local deg = arc[1] + span * k / steps
			local edge = k == 0 or k == steps
			local r = WorldBuilder.CliffRadius + rng:NextNumber(-4, 8)
			local pos = polar(deg, r)
			local out = flat(pos).Unit
			local h = edge and rng:NextNumber(8, 14) or rng:NextNumber(16, 32)
			local cf = CFrame.lookAt(pos, pos + out) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0)
			Nature.cliff(cliffs, cf, rng:NextNumber(70, 90), h, rng:NextNumber(36, 48), {
				rng = rng,
				color = ROCK,
				top = GRASS,
				role = "falaise",
				topRole = "herbe",
				slot = "Falaise",
			})
		end
		-- aiguilles de roche dans la mer
		for _ = 1, 3 do
			local deg = arc[1] + span * rng:NextNumber(0.1, 0.9)
			local base = polar(deg, rng:NextNumber(684, 720), -3)
			local h = rng:NextNumber(18, 34)
			local stack = Nature.cliff(cliffs, CFrame.lookAt(base, base + flat(base).Unit), rng:NextNumber(18, 26), h, rng:NextNumber(16, 22), {
				rng = rng,
				color = ROCK,
				top = GRASS,
				role = "falaise",
				topRole = "herbe",
				slot = "AiguilleRocheuse",
				rubble = false,
			})
			stack.Name = "AiguilleRocheuse"
		end
	end

	-- Plages : rochers, galets et bois flotté (hors caps).
	local beach = Build.folder(ground, "Plage")
	Core.scatter(rng, 46, Vector3.zero, Layout.IslandRadius + 4, Layout.BeachRadius + 18, function(p)
		return not WorldBuilder.inCliffs(p, 30) and not WorldBuilder.nearWater(p, 6)
	end, function(p)
		local roll = rng:NextNumber()
		if roll < 0.7 then
			Nature.rock(beach, p + UP * (TOP_ISLAND - 0.6), rng:NextNumber(3, 8), { rng = rng, color = ROCK, slot = "RocherPlage", role = "roche" })
		else
			Nature.log(beach, CFrame.new(p + UP * (TOP_ISLAND - 0.5)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(6, 10), rng:NextNumber(1, 1.6), rng)
		end
	end)

	-- Étang, ruisseau jusqu'à la mer, pont arqué sur le sentier, pas japonais.
	local water = Build.folder(ground, "Eau")
	Relief.pond(water, WorldBuilder.Pond.center, WorldBuilder.Pond.radius, { rng = rng }, Nature)
	Relief.stream(water, WorldBuilder.StreamPoints, 9, { rng = rng }, Nature)
	local bridgeDir = flat(WorldBuilder.BridgeAt).Unit:Cross(UP)
	local bridge = Relief.archBridge(water, WorldBuilder.BridgeAt - bridgeDir * 13, WorldBuilder.BridgeAt + bridgeDir * 13, 7, 3.4, rgb(186, 60, 44))
	for _, item in bridge:GetDescendants() do
		if item:IsA("BasePart") and (item.Name == "Handrail" or item.Name == "MidRail" or item.Name == "RailPost") then
			Core.solRole(item, "laque")
		end
	end
	local pondDir = flat(WorldBuilder.Pond.center).Unit
	Relief.steppingStones(water, WorldBuilder.Pond.center - pondDir * 70, WorldBuilder.Pond.center - pondDir * 33, TOP_PATCH, rng)

	-- Sentier de forêt (terre battue) qui fait le tour de l'île derrière les bases.
	local trail = Build.folder(ground, "Sentier")
	local segments = 120
	for i = 0, segments - 1 do
		local a0 = i / segments * math.pi * 2
		local a1 = (i + 1) / segments * math.pi * 2
		local p0 = polarRad(a0, WorldBuilder.TrailRadius)
		local p1 = polarRad(a1, WorldBuilder.TrailRadius)
		local mid = (p0 + p1) / 2
		if not WorldBuilder.nearWater(mid, -4) then
			local nuance = rng:NextNumber(-0.05, 0.05)
			local part = Build.deco(trail, "Trail", Vector3.new(7 + rng:NextNumber(-0.8, 0.8), 0.3, (p1 - p0).Magnitude + 1), CFrame.lookAt(mid, p1) + UP * (TOP_PATCH + 0.02), GRASS, {
				Material = Enum.Material.Ground,
				CastShadow = false,
			})
			Core.solRole(part, "terre", nuance)
		end
	end

	-- Taches d'herbe et de terre, touffes, herbes hautes, fleurs (hors anneau, bases, eau).
	local details = Build.folder(ground, "Details")
	Core.scatter(rng, 100, Vector3.zero, Layout.WalkwayOuter + 10, Layout.IslandRadius - 20, function(pos)
		return isFree(pos, 10)
	end, function(pos)
		local roll = rng:NextNumber()
		local role = roll < 0.45 and "herbe2" or (roll < 0.9 and "herbe3" or "terre")
		local material = role == "herbe2" and Enum.Material.LeafyGrass or (role == "terre" and Enum.Material.Ground or Enum.Material.Grass)
		local y = WorldBuilder.groundY(pos)
		if y < 0.2 then
			local count = rng:NextInteger(3, 5)
			local size = rng:NextNumber(26, 64)
			for i = 1, count do
				local a = rng:NextNumber(0, math.pi * 2)
				local r = i == 1 and 0 or size * rng:NextNumber(0.2, 0.42)
				local d = size * (i == 1 and 0.8 or rng:NextNumber(0.4, 0.65))
				local disc = Core.flatDisc(details, "Patch", pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), d, TOP_PATCH + (i % 2) * 0.01, GRASS, material)
				Core.solRole(disc, role)
			end
		end
	end)
	Core.scatter(rng, 520, Vector3.zero, Layout.WalkwayOuter + 4, Layout.IslandRadius - 14, function(pos)
		return isFree(pos, 0)
	end, function(pos)
		Nature.tuft(details, pos + UP * (WorldBuilder.groundY(pos) + TOP_PATCH), rng:NextNumber(1.1, 1.9), GRASS, rng, "touffe")
	end)
	Core.scatter(rng, 120, Vector3.zero, Layout.WalkwayOuter + 30, Layout.IslandRadius - 14, function(pos)
		return isFree(pos, 2)
	end, function(pos)
		Nature.tallGrass(details, pos + UP * (WorldBuilder.groundY(pos) + TOP_PATCH), rng:NextNumber(2.6, 4), GRASS, rng, "touffe")
	end)
	local flowerColors = { rgb(240, 110, 140), rgb(250, 206, 80), rgb(170, 130, 240), rgb(250, 250, 246), rgb(120, 180, 250) }
	Core.scatter(rng, 200, Vector3.zero, Layout.WalkwayOuter + 4, Layout.IslandRadius - 14, function(pos)
		return isFree(pos, 1)
	end, function(pos)
		Nature.flower(details, pos + UP * (WorldBuilder.groundY(pos) + TOP_PATCH), flowerColors[rng:NextInteger(1, #flowerColors)], rng)
	end)
end

------------------------------------------------------------------------
-- Rues pavées (du hub aux bases) et promenade
------------------------------------------------------------------------

-- Anneau de blocs (segments tournés vers le centre) entre r1 et r2.
local function band(parent: Instance, name: string, r1: number, r2: number, segments: number, top: number, thickness: number, color: Color3, material: Enum.Material, role: string?)
	for i = 0, segments - 1 do
		local angle = (i + 0.5) / segments * math.pi * 2
		local length = 2 * math.pi * r2 / segments + 0.3
		local mid = (r1 + r2) / 2
		local y = top - thickness / 2
		local cf = CFrame.lookAt(polarRad(angle, mid, y), Vector3.new(0, y, 0))
		local nuance = ((i % 3) - 1) * 0.03
		local part = Build.part(parent, name, Vector3.new(length, thickness, r2 - r1), cf, color, { Material = material, CastShadow = false })
		if role then
			Core.solRole(part, role, nuance)
		end
	end
end

local function buildPaths(world: Folder)
	local paths = Build.folder(world, "Paths")
	local roadRng = Random.new(42)
	for _, angle in Layout.PlotAngles do
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		Relief.road(paths, dir * (Layout.HubWallRadius - 1), dir * (Layout.PlotRing - Layout.PlotSize / 2 + 1), Layout.PathWidth, TOP_PATH, {
			rng = roadRng,
			role = "pave",
			curbRole = "bordure",
		})
	end
	-- Promenade circulaire pavée entre l'anneau et les bases, avec ses bordures.
	band(paths, "Walkway", Layout.WalkwayInner, Layout.WalkwayOuter, 120, TOP_PATH + 0.02, 0.6, rgb(176, 168, 152), Enum.Material.Cobblestone, "promenade")
	band(paths, "WalkwayEdge", Layout.WalkwayInner - 1.2, Layout.WalkwayInner, 120, TOP_PATH + 0.32, 0.9, STONE_DARK, Enum.Material.Slate, "bordure")
	band(paths, "WalkwayEdge", Layout.WalkwayOuter, Layout.WalkwayOuter + 1.2, 120, TOP_PATH + 0.32, 0.9, STONE_DARK, Enum.Material.Slate, "bordure")
end

------------------------------------------------------------------------
-- Le hub central
------------------------------------------------------------------------

local NPC_LOOKS = {
	Defi = {
		skin = rgb(240, 196, 160),
		hair = "spiky",
		hairColor = rgb(200, 40, 40),
		top = rgb(40, 40, 50),
		topAccent = rgb(200, 40, 40),
		bottom = rgb(30, 30, 35),
		outfit = "gi",
		face = "fierce",
		accessories = { "bandana", "wristbands" },
		accColor = rgb(200, 40, 40),
	},
	Fusion = {
		skin = rgb(230, 200, 175),
		hair = "long",
		hairColor = rgb(200, 200, 230),
		top = rgb(90, 50, 160),
		topAccent = rgb(255, 210, 90),
		bottom = rgb(50, 30, 90),
		outfit = "robe",
		face = "calm",
		eyes = rgb(160, 90, 255),
		accessories = { "hood" },
		accColor = rgb(70, 35, 130),
	},
	Traits = {
		skin = rgb(255, 216, 190),
		hair = "bob",
		hairColor = rgb(120, 220, 255),
		top = rgb(240, 250, 255),
		topAccent = rgb(60, 180, 255),
		bottom = rgb(40, 90, 160),
		outfit = "uniform",
		face = "happy",
		eyes = rgb(40, 160, 255),
		blush = true,
		accessories = { "glasses" },
	},
	Forge = {
		skin = rgb(205, 150, 110),
		hair = "bald",
		hairColor = rgb(60, 40, 30),
		top = rgb(110, 80, 55),
		topAccent = rgb(70, 50, 35),
		bottom = rgb(60, 50, 45),
		outfit = "overalls",
		face = "smirk",
		bigBrows = true,
		accessories = { "hammer", "wristbands" },
		accColor = rgb(90, 70, 50),
	},
	Evolution = {
		skin = rgb(240, 200, 170),
		hair = "topknot",
		hairColor = rgb(230, 230, 230),
		top = rgb(90, 170, 80),
		topAccent = rgb(250, 230, 160),
		bottom = rgb(60, 110, 55),
		outfit = "robe",
		face = "calm",
		accessories = { "sash" },
		sashColor = rgb(255, 210, 80),
	},
	Index = {
		skin = rgb(255, 220, 195),
		hair = "ponytail",
		hairColor = rgb(120, 70, 40),
		top = rgb(250, 210, 80),
		topAccent = rgb(200, 80, 60),
		bottom = rgb(60, 60, 90),
		outfit = "sailor",
		face = "happy",
		blush = true,
		accessories = { "glasses" },
	},
}

local NPC_NAMES = {
	Defi = "Maître du Défi",
	Fusion = "Mage du Crossover",
	Traits = "Gardienne des Traits",
	Forge = "Forgeron Kenzo",
	Evolution = "Moine de l'Éveil",
	Index = "Archiviste Yumi",
}

-- Dimensions d'un stand (repère local : -Z = vers le centre du hub).
local STALL_W = 22
local STALL_D = 14
local FLOOR_TOP = TOP_HUB + 0.9
local COUNTER_Z = -3.6
local COUNTER_TOP = FLOOR_TOP + 3.4

local function counterProps(parent: Instance, stall, cf: CFrame)
	-- Petits objets posés sur le comptoir et sur les étagères selon le stand.
	local top = cf * CFrame.new(0, COUNTER_TOP + 0.2, COUNTER_Z)
	local shelf = cf * CFrame.new(0, FLOOR_TOP, STALL_D / 2 - 1.6)
	if stall.id == "Forge" then
		Build.part(parent, "Anvil", Vector3.new(2.4, 1, 1.2), top * CFrame.new(-5, 0.5, 0), rgb(70, 70, 80), { Material = Enum.Material.Metal })
		Build.part(parent, "AnvilHorn", Vector3.new(1, 0.6, 0.7), top * CFrame.new(-6.4, 0.7, 0), rgb(70, 70, 80), { Material = Enum.Material.Metal, CanCollide = false })
		for i = 0, 2 do
			Build.deco(parent, "DisplaySword", Vector3.new(0.3, 3.4, 0.1), top * CFrame.new(2 + i * 1.6, 1.7, 0) * CFrame.Angles(0, 0, 0.15), rgb(210, 215, 225), {
				Material = Enum.Material.Metal,
				Reflectance = 0.2,
			})
			Build.deco(parent, "DisplayHilt", Vector3.new(1, 0.25, 0.25), top * CFrame.new(2 + i * 1.6, 0.2, 0), rgb(120, 70, 40))
		end
		-- forge rougeoyante au fond
		Build.part(parent, "Furnace", Vector3.new(5, 5, 3), shelf * CFrame.new(-5, 2.5, 0), rgb(110, 70, 56), { Material = Enum.Material.Brick })
		local fire = Build.deco(parent, "FurnaceFire", Vector3.new(2.6, 1.8, 0.4), shelf * CFrame.new(-5, 1.8, -1.55), rgb(255, 120, 40), { Material = Enum.Material.Neon })
		Core.light(fire, rgb(255, 140, 60), 16, 1.6)
		Props.weaponRack(parent, shelf * CFrame.new(4, 0, 0.4) * CFrame.Angles(0, math.pi, 0))
	elseif stall.id == "Traits" then
		for i = -1, 1 do
			local crystal = Build.deco(parent, "TraitCrystal", Vector3.new(0.9, 1.8, 0.9), top * CFrame.new(i * 3.5, 1, 0) * CFrame.Angles(0, math.rad(45), 0), stall.color:Lerp(rgb(255, 255, 255), 0.2), {
				Material = Enum.Material.Neon,
				Transparency = 0.1,
			})
			crystal:SetAttribute("Bob", 0.3)
			CollectionService:AddTag(crystal, "Spin")
		end
	elseif stall.id == "Fusion" then
		local orb = Build.ball(parent, "FusionOrb", 2.4, (top * CFrame.new(0, 1.5, 0)).Position, stall.color, { Material = Enum.Material.Neon, Transparency = 0.15, CanCollide = false })
		orb:SetAttribute("Bob", 0.4)
		CollectionService:AddTag(orb, "Spin")
		Core.light(orb, stall.color, 16, 1.2)
	elseif stall.id == "Evolution" then
		for i = -1, 1, 2 do
			local star = Build.deco(parent, "EvoStar", Vector3.new(1.4, 1.4, 0.3), top * CFrame.new(i * 3.5, 1.2, 0) * CFrame.Angles(0, 0, math.rad(45)), rgb(255, 220, 80), {
				Material = Enum.Material.Neon,
			})
			star:SetAttribute("SpinAxis", "Y")
			CollectionService:AddTag(star, "Spin")
		end
	elseif stall.id == "Index" then
		local colors = { rgb(200, 60, 60), rgb(60, 120, 220), rgb(80, 180, 90), rgb(240, 190, 60) }
		for i = 1, 4 do
			Build.part(parent, "Book", Vector3.new(0.7, 1.6, 1.2), top * CFrame.new(-5 + i * 0.75, 0.8, 0), colors[i])
		end
		-- bibliothèque au fond
		Build.part(parent, "Bookcase", Vector3.new(8, 8, 1.6), shelf * CFrame.new(0, 4, 0.2), WOOD_DARK, { Material = Enum.Material.WoodPlanks })
		for row = 0, 2 do
			for k = 0, 8 do
				Build.deco(parent, "Book", Vector3.new(0.6, 1.8, 1), shelf * CFrame.new(-3.4 + k * 0.85, 1.5 + row * 2.5, -0.4), colors[(k + row) % 4 + 1])
			end
		end
	elseif stall.id == "Defi" then
		Build.part(parent, "BossBanner", Vector3.new(3, 2, 0.2), top * CFrame.new(4, 1, 0), rgb(30, 25, 30))
		Build.deco(parent, "BossEye", Vector3.new(0.6, 0.4, 0.1), top * CFrame.new(3.4, 1.2, -0.12), rgb(255, 40, 40), { Material = Enum.Material.Neon })
		Build.deco(parent, "BossEye", Vector3.new(0.6, 0.4, 0.1), top * CFrame.new(4.6, 1.2, -0.12), rgb(255, 40, 40), { Material = Enum.Material.Neon })
		Props.weaponRack(parent, shelf * CFrame.new(-4, 0, 0.4) * CFrame.Angles(0, math.pi, 0))
		Props.trainingPost(parent, (shelf * CFrame.new(5, 0, 0)).Position, Random.new(4))
	end
	if stall.id ~= "Forge" and stall.id ~= "Index" and stall.id ~= "Defi" then
		-- étagères garnies de pots et de fioles
		for row = 0, 1 do
			Build.part(parent, "Shelf", Vector3.new(10, 0.4, 1.4), shelf * CFrame.new(0, 3 + row * 2.6, 0.4), WOOD, { Material = Enum.Material.WoodPlanks })
			for k = 0, 5 do
				local c = stall.color:Lerp(rgb(255, 255, 255), (k % 3) * 0.25)
				Build.deco(parent, "Jar", Vector3.new(0.8, 1.2, 0.8), shelf * CFrame.new(-4 + k * 1.6, 3.8 + row * 2.6, 0.3), c, { Material = Enum.Material.Glass, Transparency = 0.15 })
			end
		end
	end
end

-- Stand de marché japonais détaillé : socle de pierre, plancher, poteaux et poutres, toit de tuiles
-- à débords avec chevrons et coins relevés, rideaux noren aux couleurs du stand, lanternes,
-- enseigne, bannières, caisses et tonneaux autour.
local function buildStall(parent: Instance, stall)
	local position = polar(stall.angle, Layout.StallRadius)
	local cf = CFrame.lookAt(position, Vector3.new(0, 0, 0)) -- -Z local = vers le centre du hub
	local model = Build.model(parent, "Stall_" .. stall.id)
	local color = stall.color
	local light = color:Lerp(rgb(255, 255, 255), 0.6)
	local roofColor = Core.mute(color:Lerp(rgb(40, 34, 40), 0.45), 0.25)
	local hw, hd = STALL_W / 2, STALL_D / 2
	local base = cf + UP * TOP_HUB
	-- Socle de pierre, marches et plancher.
	Archi.plinth(model, base, STALL_W + 2, STALL_D + 2, 0.7, STONE_DARK)
	Build.part(model, "Floor", Vector3.new(STALL_W, 0.3, STALL_D), cf * CFrame.new(0, FLOOR_TOP - 0.15, 0), WOOD, { Material = Enum.Material.WoodPlanks })
	Build.part(model, "Step", Vector3.new(STALL_W - 4, 0.45, 1.6), cf * CFrame.new(0, TOP_HUB + 0.22, -hd - 1.6), STONE, { Material = Enum.Material.Slate })
	-- Mur du fond à colombages et murets latéraux à claire-voie.
	Archi.walls(model, cf * CFrame.new(0, FLOOR_TOP, hd - 0.5), STALL_W, 1, 12, rgb(224, 212, 190), { frame = WOOD_DARK, spacing = 5.5 })
	Build.part(model, "BackPanel", Vector3.new(STALL_W - 6, 4.2, 0.2), cf * CFrame.new(0, FLOOR_TOP + 9, hd - 1.1), light, { Material = Enum.Material.Fabric })
	for _, side in { -1, 1 } do
		Build.part(model, "SideWall", Vector3.new(0.6, 4, STALL_D - 4), cf * CFrame.new(side * (hw - 0.3), FLOOR_TOP + 2, 1.5), WOOD, { Material = Enum.Material.WoodPlanks })
		for k = 0, 3 do
			Build.deco(model, "Lattice", Vector3.new(0.3, 4.4, 0.3), cf * CFrame.new(side * (hw - 0.3), FLOOR_TOP + 6.2, -1.5 + k * 2.4), WOOD_DARK, { Material = Enum.Material.Wood })
		end
		Build.deco(model, "LatticeRail", Vector3.new(0.4, 0.4, STALL_D - 4), cf * CFrame.new(side * (hw - 0.3), FLOOR_TOP + 8.4, 1.5), WOOD_DARK, { Material = Enum.Material.Wood })
	end
	-- Comptoir.
	local counter = Build.part(model, "Counter", Vector3.new(STALL_W - 4, 3.2, 2.8), cf * CFrame.new(0, FLOOR_TOP + 1.6, COUNTER_Z), WOOD, { Material = Enum.Material.WoodPlanks })
	Build.part(model, "CounterTop", Vector3.new(STALL_W - 3.4, 0.4, 3.3), cf * CFrame.new(0, COUNTER_TOP, COUNTER_Z), rgb(184, 136, 92), { Material = Enum.Material.Wood })
	Build.part(model, "CounterStripe", Vector3.new(STALL_W - 4.1, 1.1, 0.14), cf * CFrame.new(0, FLOOR_TOP + 2, COUNTER_Z - 1.45), color, { Material = Enum.Material.Fabric })
	for _, x in { -1, 1 } do
		Build.deco(model, "CounterPost", Vector3.new(0.5, 3.2, 0.5), cf * CFrame.new(x * (hw - 2.4), FLOOR_TOP + 1.6, COUNTER_Z - 1.5), WOOD_DARK, { Material = Enum.Material.Wood })
	end
	-- Poteaux avant, poutre et toit.
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			Build.part(model, "Post", Vector3.new(1.2, 13, 1.2), cf * CFrame.new(x * (hw - 0.6), FLOOR_TOP + 6.5, z * (hd - 0.8)), WOOD_DARK, { Material = Enum.Material.Wood })
		end
		Build.deco(model, "PostBase", Vector3.new(1.6, 0.6, 1.6), cf * CFrame.new(x * (hw - 0.6), FLOOR_TOP + 0.3, -(hd - 0.8)), STONE_DARK, { Material = Enum.Material.Slate })
	end
	local eave = FLOOR_TOP + 13
	Build.part(model, "Beam", Vector3.new(STALL_W + 1, 1, 1), cf * CFrame.new(0, eave - 0.5, -(hd - 0.8)), WOOD_DARK, { Material = Enum.Material.Wood })
	Build.deco(model, "Beam2", Vector3.new(STALL_W - 1, 0.6, 0.7), cf * CFrame.new(0, eave - 2.1, -(hd - 0.8)), WOOD_DARK, { Material = Enum.Material.Wood })
	Archi.gableRoof(model, cf * CFrame.new(0, eave, 0), STALL_W, STALL_D, 5, 2.6, roofColor, {
		rafters = WOOD_DARK,
		trim = shade(roofColor, -0.3),
		upturn = true,
		gableFill = rgb(224, 212, 190),
	})
	-- Rideaux noren sous l'avant-toit.
	Archi.noren(model, cf * CFrame.new(0, eave - 2.5, -(hd - 0.5)), STALL_W - 3.4, 3, color)
	-- Lanternes aux poteaux avant.
	for _, side in { -1, 1 } do
		Props.paperLantern(model, (cf * CFrame.new(side * (hw + 0.5), eave - 3.4, -(hd - 0.8))).Position, rgb(255, 130, 70))
	end
	-- Grande enseigne au-dessus de l'avant-toit (et au dos, visible depuis l'anneau).
	local sign = Build.part(model, "Sign", Vector3.new(16, 3.4, 0.6), cf * CFrame.new(0, eave + 3.2, -(hd + 2.2)) * CFrame.Angles(math.rad(-14), 0, 0), color)
	Build.part(model, "SignFrame", Vector3.new(16.8, 4.2, 0.4), cf * CFrame.new(0, eave + 3.2, -(hd + 1.9)) * CFrame.Angles(math.rad(-14), 0, 0), WOOD_DARK, {
		Material = Enum.Material.Wood,
	})
	Build.surfaceText(sign, Enum.NormalId.Front, stall.icon .. " " .. stall.title, rgb(255, 255, 255))
	local backSign = Build.part(model, "BackSign", Vector3.new(14, 3, 0.4), cf * CFrame.new(0, FLOOR_TOP + 9.4, hd + 0.2), color)
	Build.surfaceText(backSign, Enum.NormalId.Back, stall.icon .. " " .. stall.title, rgb(255, 255, 255))
	local subtitle = Build.part(model, "Subtitle", Vector3.new(12, 1.4, 0.2), cf * CFrame.new(0, FLOOR_TOP + 6.6, hd - 1.05), rgb(255, 255, 255), {
		Transparency = 1,
		CanCollide = false,
	})
	Build.surfaceText(subtitle, Enum.NormalId.Front, stall.subtitle, color:Lerp(rgb(0, 0, 0), 0.35))
	-- Bannières, caisses et tonneaux autour du stand.
	for _, side in { -1, 1 } do
		Props.banner(model, (cf * CFrame.new(side * (hw + 2.4), TOP_HUB, -hd + 1)).Position, 11, color, nil, math.atan2(cf.LookVector.X, cf.LookVector.Z))
	end
	local propRng = Random.new(#stall.id * 17)
	Props.barrel(model, cf * CFrame.new(hw + 1.6, TOP_HUB, 2), 0.85)
	Props.crate(model, cf * CFrame.new(-hw - 1.8, TOP_HUB, 2.5) * CFrame.Angles(0, propRng:NextNumber(-0.3, 0.3), 0), 2.4)
	counterProps(model, stall, cf)
	-- Interaction (touche E, bouton X de la manette, ou toucher sur mobile).
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StallPrompt"
	prompt.ActionText = stall.menu == "Challenge" and "Se téléporter" or "Ouvrir"
	prompt.ObjectText = stall.title .. " · " .. stall.subtitle
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = counter
	model:SetAttribute("Menu", stall.menu)
	model:SetAttribute("StallId", stall.id)
	CollectionService:AddTag(model, "HubStall")
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	-- Vendeur derrière le comptoir.
	local look = NPC_LOOKS[stall.id]
	if look then
		local npc = CharacterBuilder.build(look, { name = NPC_NAMES[stall.id], anchored = true })
		npc:PivotTo(cf * CFrame.new(0, FLOOR_TOP + CharacterBuilder.RootHeight, -0.8))
		npc:SetAttribute("NPC", true)
		npc:SetAttribute("DisplayName", NPC_NAMES[stall.id])
		npc.Parent = model
		CollectionService:AddTag(npc, "AnimeRig")
	end
	return model
end

-- Lanterne de pierre japonaise (tōrō) — gardé pour les autres modules.
function WorldBuilder.stoneLantern(parent: Instance, base: Vector3, scale: number?)
	Props.stoneLantern(parent, base, scale)
end

-- Grand cristal taillé en gemme (couronne + pavillon octogonaux en verre, cœur lumineux),
-- qui tourne et flotte au-dessus de la fontaine. Sa couleur suit l'univers (UniverseTint).
local function buildGem(parent: Instance, center: Vector3): Model
	local gem = Build.model(parent, "Gem")
	local tint = rgb(255, 140, 30)
	local function bipyramid(name: string, width: number, crownH: number, pavilionH: number, material: Enum.Material, transparency: number)
		for k = 0, 1 do
			local turn = CFrame.Angles(0, k * math.pi / 4, 0)
			for _, part in Core.pyramid(gem, name, CFrame.new(center) * turn, width, width, crownH, tint, material) do
				part.Transparency = transparency
				part.CanCollide = false
				part:SetAttribute("UniverseTint", true)
			end
			for _, part in Core.pyramid(gem, name, CFrame.new(center) * turn * CFrame.Angles(math.pi, 0, 0), width, width, pavilionH, tint, material) do
				part.Transparency = transparency
				part.CanCollide = false
				part:SetAttribute("UniverseTint", true)
			end
		end
	end
	bipyramid("GemFacet", 9, 4.2, 9.5, Enum.Material.Glass, 0.25)
	bipyramid("GemCore", 5.2, 2.6, 6, Enum.Material.Neon, 0)
	-- table (dessus plat) et ceinture
	for k = 0, 1 do
		local girdle = Build.deco(gem, "GemGirdle", Vector3.new(8.2, 0.5, 8.2), CFrame.new(center) * CFrame.Angles(0, k * math.pi / 4, 0), tint, { Material = Enum.Material.Glass, Transparency = 0.2 })
		girdle:SetAttribute("UniverseTint", true)
	end
	-- cœur porteur de la lumière et du panneau flottant (cherché par UniverseService)
	local core = Build.deco(gem, "Crystal", Vector3.new(2.4, 2.4, 2.4), CFrame.new(center), tint, { Material = Enum.Material.Neon, Transparency = 0.2 })
	core:SetAttribute("UniverseTint", true)
	local glow = Core.light(core, rgb(255, 160, 60), 46, 2.2)
	glow.Shadows = false
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(1.5, 2.5)
	sparkle.Rate = 12
	sparkle.Speed = NumberRange.new(2, 4)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = core
	gem.PrimaryPart = core
	gem:SetAttribute("SpinSpeed", 0.5)
	gem:SetAttribute("Bob", 0.8)
	CollectionService:AddTag(gem, "SpinModel")
	return gem
end

-- Arche d'entrée du hub (sur une allée) avec un double panneau « univers actuel » mis à jour
-- chaque seconde par UniverseService (tag "UniversePanel", libellés Title / Sub / Timer / Next).
local function buildUniverseArch(parent: Instance, angle: number, radius: number)
	local pos = polarRad(angle, radius, TOP_HUB)
	local cf = CFrame.lookAt(pos, Vector3.new(0, TOP_HUB, 0)) -- -Z local vers le centre
	local model = Build.model(parent, "ArcheUnivers")
	local half = Layout.PathWidth / 2 - 1
	for _, x in { -1, 1 } do
		Archi.block(model, "ArchPost", Vector3.new(1.4, 17, 1.4), cf * CFrame.new(x * half, 0, 0), WOOD_DARK, Enum.Material.Wood)
		Archi.block(model, "ArchFoot", Vector3.new(2.2, 1.4, 2.2), cf * CFrame.new(x * half, 0, 0), STONE_DARK, Enum.Material.Slate)
	end
	Build.part(model, "ArchBeam", Vector3.new(half * 2 + 5, 1.2, 1.8), cf * CFrame.new(0, 17.4, 0), WOOD_DARK, { Material = Enum.Material.Wood })
	Build.part(model, "ArchBeam2", Vector3.new(half * 2 + 2, 0.8, 1.2), cf * CFrame.new(0, 10.6, 0), WOOD_DARK, { Material = Enum.Material.Wood })
	Archi.gableRoof(model, cf * CFrame.new(0, 18, 0), half * 2 + 4, 2.4, 1.6, 1.2, rgb(70, 64, 72), { upturn = true, material = Enum.Material.ClayRoofTiles })
	local header = Build.deco(model, "PanelHeader", Vector3.new(half * 2 - 0.6, 0.8, 0.9), cf * CFrame.new(0, 16.4, 0), rgb(255, 140, 30), { Material = Enum.Material.Neon })
	header:SetAttribute("UniverseTint", true)
	local panel = Build.part(model, "Panel", Vector3.new(half * 2 - 0.6, 5, 0.6), cf * CFrame.new(0, 13.6, 0), rgb(34, 28, 40), { Material = Enum.Material.Wood, CanCollide = false })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "UniverseGui"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 36
		gui.LightInfluence = 0
		gui.Parent = panel
		local title = Build.label(gui, "🌀 VILLAGE NINJA", UDim2.fromScale(0.96, 0.4), UDim2.fromScale(0.02, 0.02), rgb(255, 255, 255))
		title.Name = "Title"
		local timer = Build.label(gui, "⏳ 30:00", UDim2.fromScale(0.6, 0.32), UDim2.fromScale(0.2, 0.42), rgb(255, 225, 90))
		timer.Name = "Timer"
		local nextLabel = Build.label(gui, "Ensuite : ...", UDim2.fromScale(0.9, 0.22), UDim2.fromScale(0.05, 0.76), rgb(190, 220, 255), Enum.Font.GothamBold)
		nextLabel.Name = "Next"
	end
	CollectionService:AddTag(panel, "UniversePanel")
	for _, x in { -1, 1 } do
		Props.hangingLantern(model, (cf * CFrame.new(x * (half + 0.7), 9.8, 0)).Position, cf:VectorToWorldSpace(Vector3.new(x * 1.6, 0, 0)), rgb(255, 190, 90), 0.85)
	end
	return model
end

local function buildHub(world: Folder)
	local hub = Build.folder(world, "Hub")
	local R = Layout.HubWallRadius
	-- Sol : grand pavage, anneau de dalles claires, place centrale en ardoise, rosace.
	slab(hub, "HubFloor", R + 1, TOP_HUB, 1.2, rgb(180, 172, 160), Enum.Material.Cobblestone)
	slab(hub, "HubRing", 72, TOP_HUB + 0.03, 1.2, rgb(218, 204, 180), Enum.Material.Pavement)
	slab(hub, "HubRingInner", 68, TOP_HUB + 0.06, 1.2, rgb(196, 190, 180), Enum.Material.Cobblestone)
	local glowRing = slab(hub, "PlazaGlow", 29, TOP_HUB + 0.08, 1.2, rgb(255, 140, 30), Enum.Material.Neon)
	glowRing:SetAttribute("UniverseTint", true)
	slab(hub, "Plaza", 28, TOP_HUB + 0.1, 1.2, rgb(118, 110, 132), Enum.Material.Slate)
	for i = 0, 15 do
		local a = (i + 0.5) / 16 * math.pi * 2
		local tile = Build.part(hub, "Rosace", Vector3.new(3.2, 0.12, 7.4), CFrame.lookAt(polarRad(a, 23.5, TOP_HUB + 0.12), Vector3.new(0, TOP_HUB + 0.12, 0)), i % 2 == 0 and rgb(214, 196, 150) or rgb(150, 132, 160), {
			Material = Enum.Material.Marble,
			CastShadow = false,
		})
		tile.CanCollide = false
	end
	-- Allées dallées du centre vers chaque porte, avec bordures.
	for _, angle in Layout.PlotAngles do
		local dir = polarRad(angle, 1)
		local mid = dir * ((28 + R) / 2)
		Build.part(hub, "GateLane", Vector3.new(12, 0.3, R - 28), CFrame.lookAt(mid, mid + dir) + Vector3.new(0, TOP_HUB + 0.04, 0), rgb(214, 198, 168), {
			Material = Enum.Material.Pavement,
			CastShadow = false,
		})
		for _, side in { -1, 1 } do
			local edge = mid + dir:Cross(UP) * side * 6.3
			Build.deco(hub, "LaneEdge", Vector3.new(0.7, 0.35, R - 28), CFrame.lookAt(edge, edge + dir) + Vector3.new(0, TOP_HUB + 0.2, 0), STONE_DARK, { Material = Enum.Material.Slate })
		end
	end
	-- Muret de pierres variées (polygone), avec 6 portes sur les rues.
	local wall = Build.folder(hub, "Wall")
	local wallRng = Random.new(88)
	local gateHalf = math.rad(9)
	for k = 0, 5 do
		local a0 = math.rad(k * 60 + 30) + gateHalf
		local a1 = math.rad(k * 60 + 90) - gateHalf
		local pieces = 4
		for i = 0, pieces - 1 do
			local p0 = polarRad(a0 + (a1 - a0) * i / pieces, R, TOP_HUB)
			local p1 = polarRad(a0 + (a1 - a0) * (i + 1) / pieces, R, TOP_HUB)
			local m = Relief.stoneWall(wall, p0, p1, 3.4, 2.6, { rng = wallRng, color = rgb(168, 160, 148), moss = true })
			-- haie taillée derrière le muret
			Nature.hedge(m, p0 * ((R + 2.6) / R) + UP * 0.1, p1 * ((R + 2.6) / R) + UP * 0.1, { height = 5, width = 2.6, palette = "feuillu", rng = wallRng })
		end
	end
	for _, gate in Layout.PlotAngles do
		local dir = polarRad(gate, 1)
		local right = Vector3.new(-dir.Z, 0, dir.X)
		local center = dir * R
		for _, side in { -1, 1 } do
			local pos = center + right * side * (Layout.PathWidth / 2 + 3)
			local pcf = CFrame.lookAt(pos, pos + dir) + Vector3.new(0, TOP_HUB, 0)
			Archi.block(wall, "GatePillar", Vector3.new(3.6, 9.4, 3.6), pcf, STONE, Enum.Material.Cobblestone)
			Build.part(wall, "GatePillarCap", Vector3.new(4.6, 0.8, 4.6), pcf * CFrame.new(0, 9.8, 0), STONE_DARK, { Material = Enum.Material.Slate })
			for _, part in Core.pyramid(wall, "GatePillarRoof", pcf * CFrame.new(0, 10.2, 0), 4.2, 4.2, 1.6, STONE_DARK, Enum.Material.Slate) do
				part.CanCollide = false
			end
			local face = pos - right * side * 1.8 + UP * (TOP_HUB + 6.6)
			Archi.wallLamp(wall, CFrame.lookAt(face, face - right * side), rgb(255, 190, 100))
		end
	end
	-- Fontaine à deux vasques, jets d'eau, et cristal en gemme au centre.
	local center = Build.model(hub, "HubCrystal")
	local base = Vector3.new(0, TOP_HUB + 0.1, 0)
	Build.disc(center, "Basin", 1.6, 38, base, STONE_DARK, { Material = Enum.Material.Cobblestone })
	local water = Build.disc(center, "Water", 0.3, 35.5, base + Vector3.new(0, 1.4, 0), rgb(70, 160, 220), { Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
	water.Reflectance = 0.1
	for i = 0, 31 do
		local angle = (i + 0.5) / 32 * math.pi * 2
		local cf = CFrame.lookAt(polarRad(angle, 18.6, base.Y + 2.1), Vector3.new(0, base.Y + 2.1, 0))
		Build.part(center, "BasinRim", Vector3.new(2 * math.pi * 18.6 / 32 + 0.2, 1.6, 2), cf, i % 2 == 0 and STONE or shade(STONE, -0.06), { Material = Enum.Material.Slate })
	end
	Build.disc(center, "UpperBasinFoot", 3, 7, base, STONE, { Material = Enum.Material.Marble })
	Build.disc(center, "UpperBasin", 1.4, 15, base + Vector3.new(0, 3, 0), STONE, { Material = Enum.Material.Marble })
	Build.disc(center, "UpperWater", 0.25, 13.6, base + Vector3.new(0, 4.3, 0), rgb(80, 170, 230), { Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false })
	Build.disc(center, "Pedestal", 5.2, 5, base + Vector3.new(0, 4.4, 0), STONE, { Material = Enum.Material.Marble })
	Build.disc(center, "PedestalTrim", 0.7, 6, base + Vector3.new(0, 9.6, 0), rgb(220, 180, 70), { Material = Enum.Material.Metal })
	-- jets d'eau (de la vasque haute vers le grand bassin)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local nozzle = Build.deco(center, "Nozzle", Vector3.new(0.6, 0.6, 0.6), CFrame.lookAt(polarRad(a, 7.3, base.Y + 4.4), polarRad(a, 20, base.Y + 9)), rgb(200, 170, 80), {
			Material = Enum.Material.Metal,
			Transparency = 0,
		})
		local jet = Instance.new("ParticleEmitter")
		jet.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		jet.Color = ColorSequence.new(rgb(200, 236, 255))
		jet.LightEmission = 0.5
		jet.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.25) })
		jet.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.9) })
		jet.Lifetime = NumberRange.new(0.9, 1.1)
		jet.Rate = 40
		jet.Speed = NumberRange.new(13, 14)
		jet.Acceleration = Vector3.new(0, -32, 0)
		jet.SpreadAngle = Vector2.new(3, 3)
		jet.EmissionDirection = Enum.NormalId.Front
		jet.Parent = nozzle
	end
	buildGem(center, base + Vector3.new(0, 20, 0))
	local crystal = center:FindFirstChild("Crystal", true) :: BasePart
	local gui = Build.billboard(crystal, UDim2.fromOffset(360, 120), Vector3.new(0, 11, 0), 220)
	gui.Name = "UniverseBillboard"
	local title = Build.label(gui, "", UDim2.fromScale(1, 0.55), UDim2.fromScale(0, 0), rgb(255, 255, 255))
	title.Name = "Title"
	local timer = Build.label(gui, "", UDim2.fromScale(1, 0.4), UDim2.fromScale(0, 0.58), rgb(255, 225, 90))
	timer.Name = "Timer"
	for i = 0, 5 do
		local orb = Build.deco(center, "Orb", Vector3.new(1.2, 2.6, 1.2), CFrame.new(polarRad(i / 6 * math.pi * 2, 10, 16)) * CFrame.Angles(0, i, 0), rgb(255, 255, 255), {
			Material = Enum.Material.Neon,
		})
		orb:SetAttribute("Bob", 0.5 + i * 0.05)
		orb:SetAttribute("SpinAxis", "Y")
		orb:SetAttribute("UniverseTint", true)
		CollectionService:AddTag(orb, "Spin")
	end
	-- Arches « univers actuel » sur les 6 allées.
	local arches = Build.folder(hub, "Arches")
	for _, angle in Layout.PlotAngles do
		buildUniverseArch(arches, angle, 70)
	end
	-- Stands.
	local stalls = Build.folder(hub, "Stalls")
	for _, stall in Layout.Stalls do
		buildStall(stalls, stall)
	end
	-- Cerisiers en bacs, lanternes de pierre, bancs, lampadaires et massifs de fleurs.
	local garden = Build.folder(hub, "Garden")
	local hubRng = Random.new(84)
	for _, stall in Layout.Stalls do
		for _, side in { -1, 1 } do
			local angle = math.rad(stall.angle + side * 17)
			local pos = polarRad(angle, 75)
			Build.disc(garden, "Planter", 1.8, 10, pos + Vector3.new(0, TOP_HUB, 0), STONE_DARK, { Material = Enum.Material.Cobblestone })
			Build.disc(garden, "Soil", 0.3, 9, pos + Vector3.new(0, TOP_HUB + 1.7, 0), rgb(96, 68, 48), { Material = Enum.Material.Ground })
			Nature.tree("Cerisier", garden, pos + Vector3.new(0, TOP_HUB + 1.9, 0), { rng = hubRng, height = 16, detail = "normal" })
			Props.stoneLantern(garden, polarRad(math.rad(stall.angle + side * 11), 45) + Vector3.new(0, TOP_HUB, 0))
		end
	end
	local flowerColors = { rgb(240, 110, 150), rgb(250, 214, 90), rgb(250, 250, 246), rgb(180, 140, 240) }
	for _, angle in Layout.PlotAngles do
		local dir = polarRad(angle, 1)
		local right = Vector3.new(-dir.Z, 0, dir.X)
		for _, side in { -1, 1 } do
			local benchPos = dir * 52 + right * side * 9
			Props.bench(garden, CFrame.lookAt(benchPos, benchPos - right * side) + Vector3.new(0, TOP_HUB, 0))
			Props.lamppost(garden, dir * 32 + right * side * 8 + Vector3.new(0, TOP_HUB, 0))
			local bedPos = dir * (R - 7) + right * side * 16
			Nature.bush(garden, bedPos + Vector3.new(0, TOP_HUB, 0), { rng = hubRng, height = 3.4, flowers = flowerColors[hubRng:NextInteger(1, #flowerColors)] })
			Nature.flowerBed(garden, bedPos + right * side * 3 + Vector3.new(0, TOP_HUB, 0), 3, flowerColors, hubRng, 8)
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(10, 0.6, 10)
	local spawnPos = Layout.Spawn + Vector3.new(0, TOP_HUB + 0.1, 0)
	spawn.CFrame = CFrame.lookAt(spawnPos, Vector3.new(0, spawnPos.Y, 0))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = rgb(230, 190, 90)
	spawn.Material = Enum.Material.Marble
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Transparency = 0.1
	spawn.Parent = hub
end

------------------------------------------------------------------------
-- Anneau d'univers (partie fixe) et arène du boss
------------------------------------------------------------------------

local function buildRing(world: Folder)
	local zone = Build.folder(world, "Zone")
	-- Sol de l'anneau (sa couleur et son matériau suivent l'univers).
	Core.solRole(slab(zone, "RingBase", Layout.RingFenceRadius + 2, TOP_RING, 2, rgb(104, 150, 70), Enum.Material.Grass), "anneau")
	local fence = Build.folder(zone, "Fence")
	Build.fenceRing(fence, Vector3.new(0, TOP_RING, 0), Layout.RingFenceRadius, Layout.PlotAngles, Layout.PathWidth / 2 + 2, 4.5)
	-- Arène rocheuse du boss.
	local arena = Build.model(zone, "BossArena")
	local center = Layout.BossArena
	local radius = Layout.BossArenaRadius
	Build.disc(arena, "ArenaBase", 1.6, radius * 2 + 8, center + Vector3.new(0, -1.2, 0), rgb(112, 104, 98), { Material = Enum.Material.Rock })
	Build.disc(arena, "ArenaFloor", 1, radius * 2, center + Vector3.new(0, -0.4, 0), rgb(146, 138, 128), { Material = Enum.Material.Slate })
	local glowRing = Build.disc(arena, "ArenaGlow", 1.02, radius * 2 - 8, center + Vector3.new(0, -0.4, 0), rgb(255, 120, 40), {
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	glowRing:SetAttribute("UniverseTint", true)
	Build.disc(arena, "ArenaInner", 1.04, radius * 2 - 11, center + Vector3.new(0, -0.4, 0), rgb(136, 128, 118), { Material = Enum.Material.Slate })
	-- dalles fissurées au sol
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(6, radius - 10)
		Build.deco(arena, "ArenaSlab", Vector3.new(rng:NextNumber(3, 6), 0.1, rng:NextNumber(3, 6)), CFrame.new(p + Vector3.new(0, 0.62, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), rgb(120, 112, 104), {
			Material = Enum.Material.Slate,
		})
	end
	local pillars = 18
	for i = 0, pillars - 1 do
		local angle = i / pillars * math.pi * 2
		local pos = center + Vector3.new(math.cos(angle) * (radius + 3), 0, math.sin(angle) * (radius + 3))
		-- On laisse une entrée côté hub.
		if math.abs(math.cos(angle) + 1) > 0.25 then
			local height = rng:NextNumber(9, 18)
			Nature.rock(arena, CFrame.new(pos), rng:NextNumber(5, 8), { rng = rng, color = rgb(116, 110, 104), slot = "RocherArene", role = "roche" })
			local pillar = Build.part(
				arena,
				"RockPillar",
				Vector3.new(rng:NextNumber(3.5, 5.5), height, rng:NextNumber(3.5, 5.5)),
				CFrame.new(pos + Vector3.new(0, height / 2 - 0.5, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 3), rng:NextNumber(-0.15, 0.15)),
				rgb(106, 100, 94),
				{ Material = Enum.Material.Rock }
			)
			Core.solRole(pillar, "roche", -0.08)
			if i % 3 == 0 then
				local shard = Build.deco(
					arena,
					"Shard",
					Vector3.new(1.6, 3.6, 1.6),
					CFrame.new(pos + Vector3.new(0, height + 1, 0)) * CFrame.Angles(0.2, rng:NextNumber(0, 3), 0.2),
					rgb(255, 120, 40),
					{ Material = Enum.Material.Neon }
				)
				shard:SetAttribute("UniverseTint", true)
			end
		end
	end
	local signCF = CFrame.lookAt(center + Vector3.new(-radius - 7, 9, 0), Vector3.new(0, 9, 0))
	Archi.sign(arena, signCF, 14, 3, "👹 ARÈNE DU BOSS", { bg = rgb(60, 36, 36), text = rgb(255, 130, 110), posts = 7.6, both = true })
	Build.folder(zone, "Enemies")
	return zone
end

------------------------------------------------------------------------
-- Coin des échanges (table d'échange)
------------------------------------------------------------------------

local function buildTradeCorner(world: Folder)
	local corner = Build.model(world, "TradeCorner")
	local center = Layout.TradeCorner + Vector3.new(0, TOP_PATH, 0)
	local deck = Build.disc(corner, "Deck", 1, 58, center + Vector3.new(0, -0.5, 0), WOOD, { Material = Enum.Material.WoodPlanks })
	deck.Name = "Deck"
	Build.disc(corner, "DeckEdge", 0.9, 60, center + Vector3.new(0, -0.6, 0), STONE_DARK, { Material = Enum.Material.Cobblestone })
	Build.fenceRing(corner, center + Vector3.new(0, 0.4, 0), 29, { math.pi }, 7, 3.5)

	-- Toit de tissu (auvent) soutenu par 4 poteaux.
	for _, offset in { Vector3.new(16, 0, 16), Vector3.new(-16, 0, 16), Vector3.new(16, 0, -16), Vector3.new(-16, 0, -16) } do
		Build.part(corner, "AwningPole", Vector3.new(1.2, 16, 1.2), CFrame.new(center + offset + Vector3.new(0, 8, 0)), WOOD_DARK, { Material = Enum.Material.Wood })
		Props.hangingLantern(corner, center + offset + Vector3.new(0, 13.5, 0), -offset.Unit * 2, rgb(255, 170, 80), 0.9)
	end
	local stripes = { rgb(214, 70, 64), rgb(246, 238, 222) }
	for i = 0, 7 do
		Build.deco(corner, "Awning", Vector3.new(35, 0.4, 4.3), CFrame.new(center + Vector3.new(0, 16.4, -15 + i * 4.3)), stripes[(i % 2) + 1], { Material = Enum.Material.Fabric })
	end

	-- Deux tables d'échange avec deux tabourets (Seats) chacune.
	for index, offset in { Vector3.new(0, 0, -8), Vector3.new(0, 0, 8) } do
		local tableModel = Build.model(corner, "TradeTable" .. index)
		local base = center + offset
		Build.part(tableModel, "Top", Vector3.new(8, 0.6, 4), CFrame.new(base + Vector3.new(0, 3, 0)), rgb(130, 85, 55), { Material = Enum.Material.Wood })
		Build.part(tableModel, "Cloth", Vector3.new(3, 0.1, 4.2), CFrame.new(base + Vector3.new(0, 3.35, 0)), rgb(200, 50, 60), { Material = Enum.Material.Fabric, CanCollide = false })
		for _, legOffset in { Vector3.new(3.4, 0, 1.6), Vector3.new(-3.4, 0, 1.6), Vector3.new(3.4, 0, -1.6), Vector3.new(-3.4, 0, -1.6) } do
			Build.part(tableModel, "Leg", Vector3.new(0.5, 2.7, 0.5), CFrame.new(base + legOffset + Vector3.new(0, 1.35, 0)), WOOD_DARK, { Material = Enum.Material.Wood })
		end
		for _, side in { "A", "B" } do
			local x = side == "A" and -6 or 6
			local seat = Instance.new("Seat")
			seat.Name = "Seat" .. side
			seat.Size = Vector3.new(2.4, 1, 2.4)
			seat.CFrame = CFrame.new(base + Vector3.new(x, 1.5, 0)) * CFrame.Angles(0, side == "A" and math.rad(-90) or math.rad(90), 0)
			seat.Anchored = true
			seat.Color = rgb(70, 120, 200)
			seat.Material = Enum.Material.Fabric
			seat.TopSurface = Enum.SurfaceType.Smooth
			seat.Parent = tableModel
			Build.part(tableModel, "Stool" .. side, Vector3.new(1, 1, 1), CFrame.new(base + Vector3.new(x, 0.5, 0)), WOOD_DARK, { Material = Enum.Material.Wood })
		end
		CollectionService:AddTag(tableModel, "TradeTable")
	end
	local propRng = Random.new(470)
	Props.cargo(corner, CFrame.new(center + Vector3.new(12, 0, 20)) * CFrame.Angles(0, 0.4, 0), propRng)
	Props.cargo(corner, CFrame.new(center + Vector3.new(10, 0, -20)) * CFrame.Angles(0, -0.3, 0), propRng)

	local signCF = CFrame.lookAt(center + Vector3.new(-33, 10, 0), center + Vector3.new(-70, 10, 0))
	Archi.sign(corner, signCF, 20, 5, "🤝 COIN DES ÉCHANGES", { posts = 7.5, bg = rgb(110, 74, 48) })
	Props.stoneLantern(corner, center + Vector3.new(-26, 0, 22))
	Props.stoneLantern(corner, center + Vector3.new(-26, 0, -22))
end

------------------------------------------------------------------------
-- Panneaux (classement + infos univers)
------------------------------------------------------------------------

local function buildBoards(world: Folder)
	local boards = Build.folder(world, "Boards")
	local function board(name: string, position: Vector3, title: string, color: Color3)
		local model = Build.model(boards, name)
		local face = CFrame.lookAt(position + Vector3.new(0, 15, 0), Vector3.new(0, 15, 0))
		local panel = Build.part(model, "Panel", Vector3.new(28, 20, 1), face, rgb(36, 32, 48))
		Build.part(model, "Frame", Vector3.new(30, 22, 0.8), face * CFrame.new(0, 0, 0.3), WOOD_DARK, { Material = Enum.Material.Wood })
		Build.part(model, "Header", Vector3.new(30, 3.6, 1.4), face * CFrame.new(0, 12, 0), color)
		Archi.gableRoof(model, face * CFrame.new(0, 14.2, 0.4), 31, 3, 2.2, 1.4, rgb(70, 60, 64), { upturn = true })
		for _, side in { -1, 1 } do
			Build.part(model, "Leg", Vector3.new(1.6, 27, 1.6), CFrame.new(position + Vector3.new(0, 13.5, 0)) * (face - face.Position) * CFrame.new(side * 14, 0, 0.6), WOOD_DARK, {
				Material = Enum.Material.Wood,
			})
			Archi.block(model, "LegFoot", Vector3.new(2.6, 1.4, 2.6), CFrame.new(position) * (face - face.Position) * CFrame.new(side * 14, 0, 0.6), STONE_DARK, Enum.Material.Slate)
			local rot = CFrame.new(position) * (face - face.Position)
			Props.hangingLantern(model, (rot * CFrame.new(side * 14.8, 23, 0.6)).Position, rot:VectorToWorldSpace(Vector3.new(side * 1.8, 0, 0)), color, 1)
		end
		local header = model:FindFirstChild("Header") :: BasePart
		Build.surfaceText(header, Enum.NormalId.Front, title, rgb(255, 255, 255))
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Display"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		gui.Parent = panel
		pcall(function()
			model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end)
		return model
	end
	board("Leaderboard", Layout.Leaderboard, "🏆 LES PLUS PUISSANTS", rgb(230, 170, 40))
	board("InfoBoard", Layout.InfoBoard, "🌀 UNIVERS ACTUEL", rgb(120, 90, 230))
end

------------------------------------------------------------------------
-- Éclairage de base (les univers le modifient ensuite)
------------------------------------------------------------------------

function WorldBuilder.setupLighting()
	-- Lighting.Technology (Future) est réglé dans default.project.json : non modifiable par script.
	Lighting.Brightness = 2.6
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.18
	local function ensure(parent: Instance, className: string, name: string)
		local existing = parent:FindFirstChildOfClass(className)
		if existing then
			return existing
		end
		local instance = Instance.new(className)
		instance.Name = name
		instance.Parent = parent
		return instance
	end
	local atmosphere = ensure(Lighting, "Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.22
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	local bloom = ensure(Lighting, "BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.35
	bloom.Size = 26
	bloom.Threshold = 1.8
	local rays = ensure(Lighting, "SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.08
	rays.Spread = 0.55
	local grading = ensure(Lighting, "ColorCorrectionEffect", "Grading") :: ColorCorrectionEffect
	grading.Saturation = 0.04
	grading.Contrast = 0.1
	local depth = ensure(Lighting, "DepthOfFieldEffect", "Profondeur") :: DepthOfFieldEffect
	depth.FarIntensity = 0.12
	depth.FocusDistance = 120
	depth.InFocusRadius = 160
	depth.NearIntensity = 0
	ensure(Lighting, "Sky", "Sky")
	-- Nuages volumétriques (enfant du Terrain).
	pcall(function()
		local terrain = Workspace.Terrain
		local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover = 0.6
		clouds.Density = 0.55
		clouds.Color = Color3.fromRGB(255, 255, 255)
		clouds.Parent = terrain
	end)
end

-- Vraie eau (Terrain) autour de l'île, uniquement en jeu.
function WorldBuilder.fillWater(world: Instance)
	local terrain = Workspace.Terrain
	if terrain:GetAttribute("WaterFilled") then
		return
	end
	local ok = pcall(function()
		local size = 4096
		terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(size, 10, size), Enum.Material.Water)
		terrain.WaterColor = Color3.fromRGB(40, 130, 180)
		terrain.WaterTransparency = 0.55
		terrain.WaterWaveSize = 0.15
		terrain.WaterWaveSpeed = 8
		terrain.WaterReflectance = 0.7
	end)
	if ok then
		terrain:SetAttribute("WaterFilled", true)
		for _, ocean in world:GetChildren() do
			if ocean.Name == "Ocean" and ocean:IsA("BasePart") then
				ocean.Transparency = 1
			end
		end
	end
end

-- Construit la carte (ou garde celle déjà présente dans le fichier).
function WorldBuilder.build(options: { water: boolean? }?)
	local existing = Workspace:FindFirstChild("World")
	if existing and existing:GetAttribute("Baked") then
		WorldBuilder.setupLighting()
		if not options or options.water ~= false then
			WorldBuilder.fillWater(existing)
		end
		Core.replaceSlots(existing)
		return { world = existing, zone = existing:FindFirstChild("Zone") }
	end
	if existing then
		existing:Destroy()
	end
	local world = Build.folder(Workspace, "World")
	WorldBuilder.setupLighting()
	buildIsland(world)
	buildPaths(world)
	buildHub(world)
	local zone = buildRing(world)
	buildTradeCorner(world)
	buildBoards(world)
	Build.folder(world, "Plots")
	if not options or options.water ~= false then
		WorldBuilder.fillWater(world)
	end
	Core.replaceSlots(world)
	return { world = world, zone = zone }
end

return WorldBuilder
