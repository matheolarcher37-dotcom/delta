-- Disposition de la carte (partagée serveur/client), en TAILLE RÉELLE :
-- un perso R6 mesure ~5,3 studs, une porte ~8 studs, les bâtiments 20 à 60 studs.
--
--   centre (0 → 84)      : le HUB, zone sûre avec les stands (Fusionner, Traits, Forgeron...)
--   84 → 96              : muret du hub (6 portes)
--   96 → 330             : l'ANNEAU D'UNIVERS, la zone de combat qui change toutes les 30 min
--   330 → 358            : clôture (ou rempart de l'univers) + promenade circulaire
--   390 → 530            : les bases des joueurs (6), avec le coin des échanges entre deux bases
--   jusqu'à 640          : l'île (forêts et décor de l'univers), puis la plage et l'océan
--   720 → 980            : l'horizon de l'univers (montagnes, falaises...) posé dans la mer

local Layout = {}

local function polar(angleDeg: number, radius: number): Vector3
	local a = math.rad(angleDeg)
	return Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
end
Layout.polar = polar

-- Hub central
Layout.HubRadius = 84
Layout.HubWallRadius = 88

-- Anneau d'univers (zone de combat)
Layout.RingInner = 96
Layout.RingOuter = 330
Layout.RingFenceRadius = 334
Layout.WalkwayInner = 340
Layout.WalkwayOuter = 358

-- Compatibilité : la "zone" de combat est l'anneau.
Layout.ZoneCenter = Vector3.new(0, 0, 0)
Layout.ZoneRadius = Layout.RingOuter
Layout.ZoneFenceRadius = Layout.RingFenceRadius

-- Bandes d'ennemis (du plus faible, près du hub, au plus fort, au bord).
-- Les bandes laissent libres le bord intérieur (96 → 110) et le bord extérieur (280 → 330),
-- où le décor de l'univers pose ses bâtiments.
Layout.EnemyBands = {
	{ 112, 165 },
	{ 180, 232 },
	{ 246, 274 },
}
Layout.RingBuildInner = 280 -- bâtiments du décor entre ce rayon et RingOuter

-- Île et océan
Layout.IslandRadius = 640
Layout.BeachRadius = 676
Layout.GroundSize = 1400
Layout.GroundTile = 60

-- Décor d'horizon de l'univers (dans la mer, au-delà de la plage).
Layout.HorizonInner = 720
Layout.HorizonOuter = 980

-- Bases des joueurs disposées en cercle.
Layout.PlotCount = 6
Layout.PlotRing = 460
Layout.PlotSize = 140

-- Angles (radians) des bases : 30°, 90°, 150°, 210°, 270°, 330°. Les chemins suivent ces angles.
Layout.PlotAngles = {}
for i = 1, Layout.PlotCount do
	Layout.PlotAngles[i] = math.rad((i - 1) * 60 + 30)
end
Layout.PathWidth = 16

-- CFrame d'une base : centrée, regardant vers le centre (-Z local = vers le hub).
function Layout.plotCFrame(index: number): CFrame
	local angle = Layout.PlotAngles[index]
	local position = Vector3.new(math.cos(angle) * Layout.PlotRing, 0, math.sin(angle) * Layout.PlotRing)
	return CFrame.lookAt(position, Vector3.new(0, 0, 0))
end

-- Arène rocheuse du boss, dans l'anneau (entre deux chemins).
Layout.BossArena = polar(0, 215)
Layout.BossArenaRadius = 34

-- Stands du hub (entre les portes). `menu` = menu ouvert côté client.
Layout.StallRadius = 60
Layout.Stalls = {
	{ id = "Defi", angle = 0, title = "DÉFI", subtitle = "Affronter le boss", icon = "⚔️", color = Color3.fromRGB(230, 60, 60), menu = "Challenge" },
	{ id = "Fusion", angle = 60, title = "FUSIONNER", subtitle = "Portail crossover", icon = "🌀", color = Color3.fromRGB(150, 80, 255), menu = "Fusion" },
	{ id = "Traits", angle = 120, title = "TRAITS", subtitle = "Autel des traits", icon = "💎", color = Color3.fromRGB(60, 200, 255), menu = "Traits" },
	{ id = "Forge", angle = 180, title = "FORGERON", subtitle = "Épées et armes", icon = "🗡️", color = Color3.fromRGB(255, 140, 40), menu = "Forge" },
	{ id = "Evolution", angle = 240, title = "FAIRE ÉVOLUER", subtitle = "Les unités", icon = "⭐", color = Color3.fromRGB(80, 210, 90), menu = "Evolution" },
	{ id = "Index", angle = 300, title = "INDEX", subtitle = "Ta collection", icon = "📖", color = Color3.fromRGB(255, 200, 50), menu = "Index" },
}
function Layout.stallPosition(stallId: string): Vector3
	for _, stall in Layout.Stalls do
		if stall.id == stallId then
			return polar(stall.angle, Layout.StallRadius)
		end
	end
	return Vector3.zero
end

-- Lieux spéciaux
Layout.TradeCorner = polar(0, 470) -- entre les bases à 330° et 30°
Layout.FusionPortal = Layout.stallPosition("Fusion")
Layout.Leaderboard = polar(120, 405)
Layout.InfoBoard = polar(240, 405)
Layout.Spawn = polar(270, 30)
Layout.GalleryCenter = Vector3.new(0, 0, 1250) -- galerie des persos (visible seulement dans Studio)

-- Vrai si la position est sur un des chemins radiaux (avec une marge).
function Layout.onPath(position: Vector3, margin: number?): boolean
	local flat = Vector3.new(position.X, 0, position.Z)
	local half = Layout.PathWidth / 2 + (margin or 0)
	for _, angle in Layout.PlotAngles do
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local along = flat:Dot(dir)
		if along > 0 and (flat - dir * along).Magnitude < half then
			return true
		end
	end
	return false
end

-- Vrai si la position est dans l'anneau de combat (hors chemins et arène si demandé).
function Layout.inRing(position: Vector3, margin: number?): boolean
	local r = Vector3.new(position.X, 0, position.Z).Magnitude
	local m = margin or 0
	return r > Layout.RingInner - m and r < Layout.RingOuter + m
end

function Layout.inBossArena(position: Vector3, margin: number?): boolean
	local flat = Vector3.new(position.X, 0, position.Z)
	return (flat - Layout.BossArena).Magnitude < Layout.BossArenaRadius + (margin or 0)
end

-- Vrai si la position touche une base (avec une marge), pour garder les bases dégagées.
function Layout.nearPlot(position: Vector3, margin: number?): boolean
	for i = 1, Layout.PlotCount do
		local localPos = Layout.plotCFrame(i):PointToObjectSpace(position)
		local half = Layout.PlotSize / 2 + (margin or 0)
		if math.abs(localPos.X) < half and math.abs(localPos.Z) < half then
			return true
		end
	end
	return false
end

return Layout
