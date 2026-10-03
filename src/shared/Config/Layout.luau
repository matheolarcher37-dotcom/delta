-- Disposition de la carte (partagée serveur/client).
--
--   centre (0 → 46)      : le HUB, zone sûre avec les stands (Fusionner, Traits, Forgeron...)
--   46 → 54              : muret du hub (6 portes)
--   54 → 168             : l'ANNEAU D'UNIVERS, la zone de combat qui change toutes les 30 min
--   168 → 190            : clôture + promenade circulaire
--   205 → 305            : les bases des joueurs (6), avec le coin des échanges entre deux bases
--   jusqu'à 330          : l'île (herbe à picots), puis la plage et l'océan

local Layout = {}

local function polar(angleDeg: number, radius: number): Vector3
	local a = math.rad(angleDeg)
	return Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
end
Layout.polar = polar

-- Hub central
Layout.HubRadius = 46
Layout.HubWallRadius = 50

-- Anneau d'univers (zone de combat)
Layout.RingInner = 54
Layout.RingOuter = 168
Layout.RingFenceRadius = 171
Layout.WalkwayInner = 174
Layout.WalkwayOuter = 188

-- Compatibilité : la "zone" de combat est l'anneau.
Layout.ZoneCenter = Vector3.new(0, 0, 0)
Layout.ZoneRadius = Layout.RingOuter
Layout.ZoneFenceRadius = Layout.RingFenceRadius

-- Bandes d'ennemis (du plus faible, près du hub, au plus fort, au bord).
Layout.EnemyBands = {
	{ 62, 92 },
	{ 98, 128 },
	{ 134, 162 },
}

-- Île et océan
Layout.IslandRadius = 330
Layout.BeachRadius = 352
Layout.GroundSize = 720
Layout.GroundTile = 30

-- Bases des joueurs disposées en cercle.
Layout.PlotCount = 6
Layout.PlotRing = 255
Layout.PlotSize = 100

-- Angles (radians) des bases : 30°, 90°, 150°, 210°, 270°, 330°. Les chemins suivent ces angles.
Layout.PlotAngles = {}
for i = 1, Layout.PlotCount do
	Layout.PlotAngles[i] = math.rad((i - 1) * 60 + 30)
end
Layout.PathWidth = 10

-- CFrame d'une base : centrée, regardant vers le centre (-Z local = vers le hub).
function Layout.plotCFrame(index: number): CFrame
	local angle = Layout.PlotAngles[index]
	local position = Vector3.new(math.cos(angle) * Layout.PlotRing, 0, math.sin(angle) * Layout.PlotRing)
	return CFrame.lookAt(position, Vector3.new(0, 0, 0))
end

-- Arène rocheuse du boss, dans l'anneau (entre deux chemins).
Layout.BossArena = polar(0, 112)
Layout.BossArenaRadius = 24

-- Stands du hub (entre les portes). `menu` = menu ouvert côté client.
Layout.StallRadius = 33
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
Layout.TradeCorner = polar(0, 258) -- entre les bases à 330° et 30°
Layout.FusionPortal = Layout.stallPosition("Fusion")
Layout.Leaderboard = polar(120, 232)
Layout.InfoBoard = polar(240, 232)
Layout.Spawn = polar(270, 18)
Layout.GalleryCenter = Vector3.new(0, 0, 470) -- galerie des persos (visible seulement dans Studio)

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

return Layout
