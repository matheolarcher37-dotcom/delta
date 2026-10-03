-- Disposition de la carte (partagée serveur/client).

local Layout = {}

Layout.GroundSize = 840
Layout.GroundTile = 35

-- Zone d'univers (combat) au centre.
Layout.ZoneCenter = Vector3.new(0, 0, 0)
Layout.ZoneRadius = 76
Layout.ZoneFenceRadius = 79

-- Bases des joueurs disposées en cercle.
Layout.PlotCount = 6
Layout.PlotRing = 215
Layout.PlotSize = 100

-- Angles (radians) des bases : 30°, 90°, 150°, 210°, 270°, 330°.
Layout.PlotAngles = {}
for i = 1, Layout.PlotCount do
	Layout.PlotAngles[i] = math.rad((i - 1) * 60 + 30)
end

-- CFrame d'une base : centrée, regardant vers la zone d'univers (-Z local = vers le centre).
function Layout.plotCFrame(index: number): CFrame
	local angle = Layout.PlotAngles[index]
	local position = Vector3.new(math.cos(angle) * Layout.PlotRing, 0, math.sin(angle) * Layout.PlotRing)
	return CFrame.lookAt(position, Vector3.new(0, 0, 0))
end

-- Lieux spéciaux entre les bases.
Layout.TradeCorner = Vector3.new(232, 0, 0) -- angle 0°
Layout.FusionPortal = Vector3.new(-232, 0, 0) -- angle 180°
Layout.Leaderboard = Vector3.new(math.cos(math.rad(120)) * 220, 0, math.sin(math.rad(120)) * 220)
Layout.InfoBoard = Vector3.new(math.cos(math.rad(300)) * 220, 0, math.sin(math.rad(300)) * 220)
Layout.Spawn = Vector3.new(math.cos(math.rad(300)) * 150, 0, math.sin(math.rad(300)) * 150)

return Layout
