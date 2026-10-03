-- Construit la carte statique : herbe en damier, zone d'univers (arène de terre + clôture),
-- chemins, arbres en bordure, coin des échanges, portail de fusion, panneaux et éclairage de base.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Build = require(script.Parent.Parent.Modules.Build)

local WorldBuilder = {}

local GRASS = {
	Color3.fromRGB(112, 200, 76),
	Color3.fromRGB(102, 188, 68),
	Color3.fromRGB(120, 208, 84),
}
local PATH = Color3.fromRGB(222, 196, 148)
local PATH_EDGE = Color3.fromRGB(190, 165, 120)

local rng = Random.new(20261003)

local function nearPlot(position: Vector3, margin: number): boolean
	for i = 1, Layout.PlotCount do
		local cf = Layout.plotCFrame(i)
		local localPos = cf:PointToObjectSpace(position)
		local half = Layout.PlotSize / 2 + margin
		if math.abs(localPos.X) < half and math.abs(localPos.Z) < half then
			return true
		end
	end
	return false
end

local function nearPath(position: Vector3, margin: number): boolean
	local flat = Vector3.new(position.X, 0, position.Z)
	local r = flat.Magnitude
	if math.abs(r - 125) < 6 + margin then
		return true
	end
	if r > 75 and r < 170 then
		for _, angle in Layout.PlotAngles do
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local along = flat:Dot(dir)
			local perp = (flat - dir * along).Magnitude
			if along > 0 and perp < 6 + margin then
				return true
			end
		end
	end
	return false
end

local function nearSpecial(position: Vector3, margin: number): boolean
	for _, spot in { Layout.TradeCorner, Layout.FusionPortal, Layout.Leaderboard, Layout.InfoBoard, Layout.Spawn } do
		if (Vector3.new(position.X, 0, position.Z) - spot).Magnitude < margin then
			return true
		end
	end
	return false
end

local function isFree(position: Vector3, margin: number): boolean
	local r = Vector3.new(position.X, 0, position.Z).Magnitude
	if r < Layout.ZoneFenceRadius + 8 + margin then
		return false
	end
	return not nearPlot(position, margin) and not nearPath(position, margin) and not nearSpecial(position, 30 + margin)
end
WorldBuilder.isFree = isFree

------------------------------------------------------------------------

local function buildGround(world: Folder)
	local ground = Build.folder(world, "Ground")
	local tile = Layout.GroundTile
	local count = math.floor(Layout.GroundSize / tile)
	local start = -Layout.GroundSize / 2 + tile / 2
	for x = 0, count - 1 do
		for z = 0, count - 1 do
			local shade = GRASS[((x + z) % 2) + 1]
			if rng:NextNumber() < 0.12 then
				shade = GRASS[3]
			end
			Build.part(ground, "Grass", Vector3.new(tile, 4, tile), CFrame.new(start + x * tile, -2, start + z * tile), shade)
		end
	end
	-- Murs invisibles en bordure.
	local half = Layout.GroundSize / 2
	for _, data in
		{
			{ Vector3.new(half, 60, 0), Vector3.new(2, 120, Layout.GroundSize) },
			{ Vector3.new(-half, 60, 0), Vector3.new(2, 120, Layout.GroundSize) },
			{ Vector3.new(0, 60, half), Vector3.new(Layout.GroundSize, 120, 2) },
			{ Vector3.new(0, 60, -half), Vector3.new(Layout.GroundSize, 120, 2) },
		}
	do
		Build.part(ground, "Boundary", data[2], CFrame.new(data[1]), Color3.new(1, 1, 1), { Transparency = 1 })
	end
	-- Collines voxel tout autour pour fermer le monde.
	for i = 0, 47 do
		local angle = i / 48 * math.pi * 2
		local dist = half - 12 + rng:NextNumber(-6, 4)
		local height = rng:NextNumber(10, 26)
		local width = rng:NextNumber(30, 50)
		local pos = Vector3.new(math.cos(angle) * dist, height / 2 - 1, math.sin(angle) * dist)
		pos = Vector3.new(math.clamp(pos.X, -half + 10, half - 10), pos.Y, math.clamp(pos.Z, -half + 10, half - 10))
		Build.part(
			ground,
			"Hill",
			Vector3.new(width, height, width),
			CFrame.new(pos) * CFrame.Angles(0, angle, 0),
			GRASS[(i % 2) + 1]:Lerp(Color3.new(0, 0, 0), 0.08),
			{ Material = Enum.Material.Grass }
		)
	end
end

local function buildPaths(world: Folder)
	local paths = Build.folder(world, "Paths")
	-- Chemins radiaux : de chaque base vers la zone.
	for _, angle in Layout.PlotAngles do
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local a = dir * (Layout.ZoneFenceRadius + 1)
		local b = dir * (Layout.PlotRing - Layout.PlotSize / 2 + 2)
		local mid = (a + b) / 2
		local length = (b - a).Magnitude
		local cf = CFrame.lookAt(mid, b)
		Build.part(paths, "Path", Vector3.new(10, 0.3, length), cf + Vector3.new(0, -0.07, 0), PATH)
		for _, side in { -1, 1 } do
			Build.part(paths, "PathEdge", Vector3.new(0.8, 0.4, length), cf * CFrame.new(side * 5.2, -0.02, 0), PATH_EDGE)
		end
		-- Pierres de gué décoratives.
		for i = 1, math.floor(length / 9) do
			local p = a + dir * (i * 9 - 4)
			Build.deco(
				paths,
				"Stone",
				Vector3.new(3, 0.12, 2.2),
				CFrame.new(p + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, angle + rng:NextNumber(-0.3, 0.3), 0),
				PATH_EDGE:Lerp(Color3.new(1, 1, 1), 0.15)
			)
		end
	end
	-- Chemin circulaire qui relie toutes les bases.
	local segments = 72
	local radius = 125
	for i = 0, segments - 1 do
		local a1 = i / segments * math.pi * 2
		local a2 = (i + 1) / segments * math.pi * 2
		local p1 = Vector3.new(math.cos(a1) * radius, 0, math.sin(a1) * radius)
		local p2 = Vector3.new(math.cos(a2) * radius, 0, math.sin(a2) * radius)
		local cf = CFrame.lookAt((p1 + p2) / 2, p2)
		Build.part(paths, "RingPath", Vector3.new(8, 0.3, (p2 - p1).Magnitude + 0.6), cf + Vector3.new(0, -0.04, 0), PATH)
	end
end

local function buildZoneBase(world: Folder)
	local zone = Build.folder(world, "Zone")
	local floor = Build.disc(zone, "ZoneFloor", 1, Layout.ZoneRadius * 2, Vector3.new(0, -0.85, 0), Color3.fromRGB(150, 105, 70))
	floor.Material = Enum.Material.SmoothPlastic
	local rim = Build.disc(zone, "ZoneRim", 0.8, Layout.ZoneRadius * 2 + 4, Vector3.new(0, -0.7, 0), Color3.fromRGB(120, 85, 55))
	rim.CanCollide = false
	local fence = Build.folder(zone, "Fence")
	Build.fenceRing(fence, Vector3.new(0, 0.1, 0), Layout.ZoneFenceRadius, Layout.PlotAngles, 7, 4.5)
	Build.folder(zone, "Decor")
	Build.folder(zone, "Enemies")
	return zone
end

local function buildScatter(world: Folder)
	local nature = Build.folder(world, "Nature")
	local flowerColors = {
		Color3.fromRGB(255, 90, 110),
		Color3.fromRGB(255, 220, 80),
		Color3.fromRGB(150, 110, 255),
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(90, 180, 255),
	}
	local half = Layout.GroundSize / 2 - 30
	-- Arbres (surtout en bordure).
	local placed = 0
	local attempts = 0
	while placed < 85 and attempts < 2000 do
		attempts += 1
		local pos = Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
		local r = pos.Magnitude
		if r > 285 and isFree(pos, 8) then
			if rng:NextNumber() < 0.7 then
				Build.tree(nature, pos, rng:NextNumber(1.1, 1.8), nil, nil, rng)
			else
				Build.pine(nature, pos, rng:NextNumber(1.2, 1.8))
			end
			placed += 1
		end
	end
	-- Fleurs, buissons et rochers dans les espaces libres.
	for _ = 1, 260 do
		local pos = Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
		if isFree(pos, 2) then
			Build.flower(nature, pos, flowerColors[rng:NextInteger(1, #flowerColors)])
		end
	end
	for _ = 1, 50 do
		local pos = Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
		if isFree(pos, 4) then
			Build.bush(nature, pos, rng:NextNumber(0.8, 1.4))
		end
	end
	for _ = 1, 40 do
		local pos = Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
		if isFree(pos, 4) then
			Build.rock(nature, pos, rng:NextNumber(0.8, 1.6), nil, rng)
		end
	end
end

------------------------------------------------------------------------
-- Coin des échanges (table d'échange)
------------------------------------------------------------------------

local function buildTradeCorner(world: Folder)
	local corner = Build.model(world, "TradeCorner")
	local center = Layout.TradeCorner
	local wood = Color3.fromRGB(160, 110, 70)
	local deck = Build.disc(corner, "Deck", 1, 46, center + Vector3.new(0, -0.6, 0), wood, { Material = Enum.Material.WoodPlanks })
	deck.Name = "Deck"
	Build.fenceRing(corner, center + Vector3.new(0, 0.4, 0), 23, { math.pi }, 6, 3.5)

	-- Toit de tissu (auvent) soutenu par 4 poteaux.
	for _, offset in { Vector3.new(14, 0, 14), Vector3.new(-14, 0, 14), Vector3.new(14, 0, -14), Vector3.new(-14, 0, -14) } do
		Build.part(corner, "AwningPole", Vector3.new(1, 14, 1), CFrame.new(center + offset + Vector3.new(0, 7.4, 0)), Color3.fromRGB(90, 60, 40), { Material = Enum.Material.Wood })
	end
	local stripes = { Color3.fromRGB(240, 70, 70), Color3.fromRGB(255, 245, 230) }
	for i = 0, 7 do
		Build.deco(
			corner,
			"Awning",
			Vector3.new(30, 0.4, 3.75),
			CFrame.new(center + Vector3.new(0, 14.6, -13.1 + i * 3.75)) * CFrame.Angles(0, 0, 0),
			stripes[(i % 2) + 1],
			{ Material = Enum.Material.Fabric }
		)
	end

	-- Deux tables d'échange avec deux tabourets (Seats) chacune.
	for index, offset in { Vector3.new(0, 0, -7), Vector3.new(0, 0, 7) } do
		local tableModel = Build.model(corner, "TradeTable" .. index)
		local base = center + offset
		Build.part(tableModel, "Top", Vector3.new(8, 0.6, 4), CFrame.new(base + Vector3.new(0, 3, 0)), Color3.fromRGB(130, 85, 55), { Material = Enum.Material.Wood })
		Build.part(
			tableModel,
			"Cloth",
			Vector3.new(3, 0.1, 4.2),
			CFrame.new(base + Vector3.new(0, 3.35, 0)),
			Color3.fromRGB(200, 50, 60),
			{ Material = Enum.Material.Fabric, CanCollide = false }
		)
		for _, legOffset in { Vector3.new(3.4, 0, 1.6), Vector3.new(-3.4, 0, 1.6), Vector3.new(3.4, 0, -1.6), Vector3.new(-3.4, 0, -1.6) } do
			Build.part(
				tableModel,
				"Leg",
				Vector3.new(0.5, 2.7, 0.5),
				CFrame.new(base + legOffset + Vector3.new(0, 1.35, 0)),
				Color3.fromRGB(100, 65, 45),
				{ Material = Enum.Material.Wood }
			)
		end
		for _, side in { "A", "B" } do
			local x = side == "A" and -6 or 6
			local seat = Instance.new("Seat")
			seat.Name = "Seat" .. side
			seat.Size = Vector3.new(2.4, 1, 2.4)
			seat.CFrame = CFrame.new(base + Vector3.new(x, 1.5, 0)) * CFrame.Angles(0, side == "A" and math.rad(-90) or math.rad(90), 0)
			seat.Anchored = true
			seat.Color = Color3.fromRGB(70, 140, 220)
			seat.Material = Enum.Material.SmoothPlastic
			seat.TopSurface = Enum.SurfaceType.Smooth
			seat.Parent = tableModel
			Build.part(tableModel, "Stool" .. side, Vector3.new(1, 1, 1), CFrame.new(base + Vector3.new(x, 0.5, 0)), Color3.fromRGB(100, 65, 45), { Material = Enum.Material.Wood })
		end
		CollectionService:AddTag(tableModel, "TradeTable")
	end

	-- Panneau.
	local sign = Build.part(
		corner,
		"Sign",
		Vector3.new(18, 4.5, 0.6),
		CFrame.lookAt(center + Vector3.new(-25, 9, 0), center + Vector3.new(-60, 9, 0)),
		Color3.fromRGB(120, 80, 50),
		{ Material = Enum.Material.Wood }
	)
	Build.surfaceText(sign, Enum.NormalId.Front, "🤝 COIN DES ÉCHANGES", Color3.fromRGB(255, 230, 120))
	for _, side in { -1, 1 } do
		Build.part(
			corner,
			"SignPost",
			Vector3.new(0.8, 9, 0.8),
			CFrame.new(center + Vector3.new(-25, 4.5, side * 8)),
			Color3.fromRGB(90, 60, 40),
			{ Material = Enum.Material.Wood }
		)
	end
	Build.lantern(corner, center + Vector3.new(-20, 0, 18), Color3.fromRGB(255, 200, 90))
	Build.lantern(corner, center + Vector3.new(-20, 0, -18), Color3.fromRGB(255, 200, 90))
end

------------------------------------------------------------------------
-- Portail de fusion (la pépite)
------------------------------------------------------------------------

local function buildFusionPortal(world: Folder)
	local portal = Build.model(world, "FusionPortal")
	local center = Layout.FusionPortal
	local stone = Color3.fromRGB(120, 115, 140)
	Build.disc(portal, "Platform", 1.5, 40, center + Vector3.new(0, -1, 0), stone, { Material = Enum.Material.Slate })
	Build.disc(portal, "Platform2", 1, 30, center + Vector3.new(0, 0, 0), stone:Lerp(Color3.new(1, 1, 1), 0.15), { Material = Enum.Material.Slate })
	-- Marches
	for i = 0, 2 do
		Build.part(portal, "Step", Vector3.new(8, 0.6, 3), CFrame.new(center + Vector3.new(21 + i * 2, -0.3 - i * 0.3, 0)), stone, { Material = Enum.Material.Slate })
	end

	-- Anneau vertical de blocs lumineux, face à l'est (vers la carte).
	local ringCenter = center + Vector3.new(-4, 13, 0)
	local ringColors = { Color3.fromRGB(80, 255, 220), Color3.fromRGB(110, 120, 255), Color3.fromRGB(255, 90, 230) }
	for i = 0, 31 do
		local angle = i / 32 * math.pi * 2
		local pos = ringCenter + Vector3.new(0, math.sin(angle) * 11, math.cos(angle) * 11)
		Build.deco(portal, "RingBlock", Vector3.new(2, 2.4, 2.4), CFrame.new(pos) * CFrame.Angles(angle, 0, 0), ringColors[(i % 3) + 1], { Material = Enum.Material.Neon })
	end
	local vortex = Build.deco(
		portal,
		"Vortex",
		Vector3.new(0.4, 20, 20),
		CFrame.new(ringCenter),
		Color3.fromRGB(120, 80, 255),
		{ Material = Enum.Material.Neon, Transparency = 0.45, Shape = Enum.PartType.Cylinder }
	)
	vortex:SetAttribute("SpinAxis", "X")
	vortex:SetAttribute("SpinSpeed", 1.5)
	CollectionService:AddTag(vortex, "Spin")
	local inner = Build.deco(
		portal,
		"VortexCore",
		Vector3.new(0.5, 9, 9),
		CFrame.new(ringCenter),
		Color3.fromRGB(255, 255, 255),
		{ Material = Enum.Material.Neon, Transparency = 0.3, Shape = Enum.PartType.Cylinder }
	)
	inner:SetAttribute("SpinAxis", "X")
	inner:SetAttribute("SpinSpeed", -3)
	CollectionService:AddTag(inner, "Spin")
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 110, 255)
	light.Range = 40
	light.Brightness = 3
	light.Parent = vortex
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(80, 255, 220), Color3.fromRGB(255, 90, 230))
	particles.LightEmission = 1
	particles.Size = NumberSequence.new(0.6, 0)
	particles.Rate = 25
	particles.Lifetime = NumberRange.new(1.5, 2.5)
	particles.Speed = NumberRange.new(4, 8)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Parent = vortex

	-- Piliers latéraux
	for _, side in { -1, 1 } do
		Build.part(portal, "Pillar", Vector3.new(3, 26, 3), CFrame.new(center + Vector3.new(-4, 13, side * 14)), stone, { Material = Enum.Material.Slate })
		Build.deco(
			portal,
			"PillarGem",
			Vector3.new(2, 2, 2),
			CFrame.new(center + Vector3.new(-4, 27.5, side * 14)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			ringColors[side > 0 and 1 or 3],
			{ Material = Enum.Material.Neon }
		)
	end

	-- Autel d'activation (prompt).
	local altar =
		Build.part(portal, "FusionAltar", Vector3.new(4, 3.5, 4), CFrame.new(center + Vector3.new(8, 1.75, 0)), Color3.fromRGB(70, 60, 100), { Material = Enum.Material.Slate })
	Build.deco(
		portal,
		"AltarGem",
		Vector3.new(1.6, 1.6, 1.6),
		CFrame.new(center + Vector3.new(8, 4.6, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Color3.fromRGB(80, 255, 220),
		{ Material = Enum.Material.Neon }
	)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FusionPrompt"
	prompt.ActionText = "Fusionner"
	prompt.ObjectText = "Portail Crossover"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = altar

	local sign = Build.part(
		portal,
		"Sign",
		Vector3.new(20, 4, 0.6),
		CFrame.lookAt(center + Vector3.new(19, 8.5, -16), center + Vector3.new(60, 8.5, -16)),
		Color3.fromRGB(60, 50, 90),
		{ Material = Enum.Material.Slate }
	)
	Build.surfaceText(sign, Enum.NormalId.Front, "🌀 PORTAIL CROSSOVER", Color3.fromRGB(120, 255, 230))
end

------------------------------------------------------------------------
-- Panneaux (classement + infos univers) et point d'apparition
------------------------------------------------------------------------

local function buildBoards(world: Folder)
	local boards = Build.folder(world, "Boards")
	local function board(name: string, position: Vector3, title: string, color: Color3)
		local model = Build.model(boards, name)
		local face = CFrame.lookAt(position + Vector3.new(0, 12, 0), Vector3.new(0, 12, 0))
		local panel = Build.part(model, "Panel", Vector3.new(22, 16, 1), face, Color3.fromRGB(40, 35, 55))
		Build.part(model, "Frame", Vector3.new(23.5, 17.5, 0.8), face * CFrame.new(0, 0, 0.3), color)
		Build.part(model, "Header", Vector3.new(23.5, 3, 1.4), face * CFrame.new(0, 9.5, 0), color)
		for _, side in { -1, 1 } do
			Build.part(
				model,
				"Leg",
				Vector3.new(1.2, 20, 1.2),
				CFrame.new(position + Vector3.new(0, 10, 0)) * (face - face.Position) * CFrame.new(side * 10, 0, 0.6),
				Color3.fromRGB(90, 60, 40),
				{ Material = Enum.Material.Wood }
			)
		end
		local header = model:FindFirstChild("Header") :: BasePart
		Build.surfaceText(header, Enum.NormalId.Front, title, Color3.fromRGB(255, 255, 255))
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Display"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		gui.Parent = panel
		return model
	end
	board("Leaderboard", Layout.Leaderboard, "🏆 LES PLUS PUISSANTS", Color3.fromRGB(255, 190, 40))
	board("InfoBoard", Layout.InfoBoard, "🌀 UNIVERS ACTUEL", Color3.fromRGB(120, 90, 255))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(Layout.Spawn + Vector3.new(0, 0.5, 0))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(255, 200, 60)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = world
end

------------------------------------------------------------------------
-- Éclairage de base (les univers le modifient ensuite)
------------------------------------------------------------------------

local function setupLighting()
	-- Lighting.Technology (Future) est réglé dans default.project.json : non modifiable par script.
	Lighting.Brightness = 2.6
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	local function ensure(className: string, name: string)
		local existing = Lighting:FindFirstChild(name)
		if existing then
			return existing
		end
		local instance = Instance.new(className)
		instance.Name = name
		instance.Parent = Lighting
		return instance
	end
	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Glare = 0.4
	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	local rays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.08
	rays.Spread = 0.6
	local grading = ensure("ColorCorrectionEffect", "Grading") :: ColorCorrectionEffect
	grading.Saturation = 0.15
	grading.Contrast = 0.08
	ensure("Sky", "Sky")

	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.65
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = Workspace.Terrain
end

function WorldBuilder.build()
	local world = Workspace:FindFirstChild("World") or Build.folder(Workspace, "World")
	setupLighting()
	buildGround(world)
	buildPaths(world)
	local zone = buildZoneBase(world)
	buildScatter(world)
	buildTradeCorner(world)
	buildFusionPortal(world)
	buildBoards(world)
	Build.folder(world, "Plots")
	return { world = world, zone = zone }
end

return WorldBuilder
