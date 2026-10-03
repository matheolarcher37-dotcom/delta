-- Construit la partie FIXE de la carte, en TAILLE RÉELLE (perso R6 ≈ 5,3 studs, porte ≈ 8 studs) :
--   * une grande île (sol en herbe texturée, taches de couleur, touffes, fleurs : plus de picots),
--     entourée d'une plage et de l'océan ;
--   * le HUB au centre : place pavée, fontaine et cristal d'univers, 6 stands de marché avec leurs
--     vendeurs (Défi, Fusionner, Traits, Forgeron, Faire évoluer, Index), muret, portes, cerisiers ;
--   * l'anneau d'univers (son décor change toutes les 30 min, voir UniverseDecor) et l'arène du boss ;
--   * les routes de terre vers les bases, la promenade pavée, le coin des échanges et les panneaux.
--
-- La nature de l'île, les bâtiments de l'anneau et l'horizon dépendent de l'univers : ils sont dans
-- le décor de l'univers (UniverseDecor). Le sol de la carte (pièces taguées "TeinteSol") change de
-- couleur et de matériau avec l'univers.
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
local DecorKit = require(script.Parent.DecorKit)

local WorldBuilder = {}

local rgb = Color3.fromRGB
local GRASS = rgb(104, 172, 72)
local PATH = rgb(206, 170, 120)
local PATH_EDGE = rgb(150, 144, 136)
local STONE = rgb(204, 198, 188)
local STONE_DARK = rgb(150, 144, 136)
local WOOD = rgb(150, 102, 64)
local WOOD_DARK = rgb(98, 66, 44)
local SAND = rgb(236, 216, 160)
local SAND_WET = rgb(206, 184, 132)

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
-- Zones libres (pour placer la nature)
------------------------------------------------------------------------

local function nearSpecial(position: Vector3, margin: number): boolean
	local flat = Vector3.new(position.X, 0, position.Z)
	for _, spot in { Layout.TradeCorner, Layout.Leaderboard, Layout.InfoBoard } do
		if (flat - spot).Magnitude < margin then
			return true
		end
	end
	return false
end

-- Vrai si l'endroit de l'île (hors anneau) est libre : pas sur une base, un chemin, un lieu spécial.
local function isFree(position: Vector3, margin: number): boolean
	local r = Vector3.new(position.X, 0, position.Z).Magnitude
	if r < Layout.WalkwayOuter + 4 + margin or r > Layout.IslandRadius - 10 then
		return false
	end
	return not Layout.nearPlot(position, margin) and not Layout.onPath(position, margin + 2) and not nearSpecial(position, 34 + margin)
end
WorldBuilder.isFree = isFree

------------------------------------------------------------------------
-- Île, plage et océan
------------------------------------------------------------------------

local function buildIsland(world: Folder)
	local ground = Build.folder(world, "Ground")
	-- Herbe : un seul grand disque texturé (matériau Grass), puis des taches de couleur.
	DecorKit.solRole(slab(ground, "Grass", Layout.IslandRadius, TOP_ISLAND, 6, GRASS, Enum.Material.Grass), "herbe")
	-- Plage (légèrement plus basse que l'herbe) puis sable mouillé.
	DecorKit.solRole(slab(ground, "Beach", Layout.BeachRadius, TOP_ISLAND - 0.35, 6, SAND, Enum.Material.Sand), "sable")
	DecorKit.solRole(slab(ground, "WetSand", Layout.BeachRadius + 26, TOP_ISLAND - 1.1, 6, SAND_WET, Enum.Material.Sand), "sable", -0.12)
	-- Océan (remplacé par de la vraie eau Terrain quand le jeu tourne) : 4 dalles de 2048.
	for _, offset in { Vector3.new(-1024, 0, -1024), Vector3.new(1024, 0, -1024), Vector3.new(-1024, 0, 1024), Vector3.new(1024, 0, 1024) } do
		local ocean = Build.part(world, "Ocean", Vector3.new(2048, 2, 2048), CFrame.new(offset + Vector3.new(0, -2.2, 0)), rgb(40, 150, 210), {
			Material = Enum.Material.Glass,
			Transparency = 0.2,
			Reflectance = 0.05,
			CanCollide = false,
			CastShadow = false,
		})
		ocean.CanQuery = false
		Build.part(world, "OceanFloor", Vector3.new(2048, 2, 2048), CFrame.new(offset + Vector3.new(0, -16, 0)), rgb(30, 100, 150), {
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
	-- Taches d'herbe plus claire / plus foncée et de terre, touffes et fleurs (hors anneau et bases).
	local details = Build.folder(ground, "Details")
	DecorKit.scatter(rng, 110, Vector3.zero, Layout.WalkwayOuter + 10, Layout.IslandRadius - 20, function(pos)
		return isFree(pos, 10)
	end, function(pos)
		local roll = rng:NextNumber()
		local role = roll < 0.45 and "herbe2" or (roll < 0.9 and "herbe3" or "terre")
		local material = role == "herbe2" and Enum.Material.LeafyGrass or (role == "terre" and Enum.Material.Ground or Enum.Material.Grass)
		DecorKit.patch(details, pos, rng:NextNumber(26, 70), TOP_PATCH + rng:NextNumber(0, 0.02), GRASS, material, rng, role)
	end)
	DecorKit.scatter(rng, 760, Vector3.zero, Layout.WalkwayOuter + 4, Layout.IslandRadius - 14, function(pos)
		return isFree(pos, 0)
	end, function(pos)
		DecorKit.tuft(details, pos + Vector3.new(0, TOP_PATCH, 0), rng:NextNumber(1.1, 1.8), rgb(96, 168, 64), rng, "touffe")
	end)
	local flowerColors = { rgb(255, 110, 140), rgb(255, 214, 80), rgb(160, 120, 255), rgb(255, 255, 255), rgb(110, 190, 255) }
	DecorKit.scatter(rng, 240, Vector3.zero, Layout.WalkwayOuter + 4, Layout.IslandRadius - 14, function(pos)
		return isFree(pos, 1)
	end, function(pos)
		DecorKit.flower(details, pos + Vector3.new(0, TOP_PATCH, 0), flowerColors[rng:NextInteger(1, #flowerColors)], rng)
	end)
end

------------------------------------------------------------------------
-- Routes de terre (du hub aux bases) et promenade pavée
------------------------------------------------------------------------

local function road(parent: Instance, from: Vector3, to: Vector3)
	local width = Layout.PathWidth
	local dir = (to - from).Unit
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	local cf = CFrame.lookAt(mid, mid + dir)
	local main = Build.part(parent, "Road", Vector3.new(width, 0.6, length), CFrame.new(mid.X, TOP_PATH - 0.3, mid.Z) * (cf - cf.Position), PATH, {
		Material = Enum.Material.Ground,
		CastShadow = false,
	})
	DecorKit.solRole(main, "chemin")
	-- Bords irréguliers (disques de terre) et pierres posées le long de la route.
	local right = dir:Cross(Vector3.new(0, 1, 0))
	for d = 2, length - 2, 4.2 do
		for _, side in { -1, 1 } do
			local pos = from + dir * (d + rng:NextNumber(-1, 1)) + right * side * (width / 2 + rng:NextNumber(-0.6, 0.4))
			local nuance = rng:NextNumber(-0.06, 0.04)
			local disc = DecorKit.flatDisc(parent, "RoadEdge", pos, rng:NextNumber(3.2, 5), TOP_PATH - 0.03, PATH, Enum.Material.Ground)
			DecorKit.solRole(disc, "chemin", nuance)
			if rng:NextNumber() < 0.22 then
				local stonePos = from + dir * d + right * side * (width / 2 + rng:NextNumber(1.6, 2.6))
				local size = rng:NextNumber(0.9, 1.7)
				local stone = Build.part(
					parent,
					"RoadStone",
					Vector3.new(size * 1.3, size * 0.6, size),
					CFrame.new(stonePos + Vector3.new(0, TOP_PATCH + size * 0.15, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)),
					PATH_EDGE,
					{ Material = Enum.Material.Rock, CanCollide = false }
				)
				DecorKit.solRole(stone, "bordure", rng:NextNumber(-0.1, 0.1))
			end
		end
	end
	-- Ornières claires au milieu.
	for _, lateral in { -3.2, 3.2 } do
		local rut = Build.deco(parent, "Rut", Vector3.new(1.6, 0.05, length - 4), cf * CFrame.new(lateral, TOP_PATH + 0.02 - mid.Y, 0), PATH, {
			Material = Enum.Material.Ground,
			CastShadow = false,
		})
		DecorKit.solRole(rut, "chemin", 0.08)
	end
end

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
			DecorKit.solRole(part, role, nuance)
		end
	end
end

local function buildPaths(world: Folder)
	local paths = Build.folder(world, "Paths")
	for _, angle in Layout.PlotAngles do
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		road(paths, dir * (Layout.HubWallRadius - 1), dir * (Layout.PlotRing - Layout.PlotSize / 2 + 1))
	end
	-- Promenade circulaire pavée entre l'anneau et les bases, avec ses bordures.
	band(paths, "Walkway", Layout.WalkwayInner, Layout.WalkwayOuter, 120, TOP_PATH + 0.02, 0.6, rgb(186, 176, 160), Enum.Material.Cobblestone, "promenade")
	band(paths, "WalkwayEdge", Layout.WalkwayInner - 1.2, Layout.WalkwayInner, 120, TOP_PATH + 0.12, 0.6, PATH_EDGE, Enum.Material.Slate, "bordure")
	band(paths, "WalkwayEdge", Layout.WalkwayOuter, Layout.WalkwayOuter + 1.2, 120, TOP_PATH + 0.12, 0.6, PATH_EDGE, Enum.Material.Slate, "bordure")
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
local FLOOR_TOP = TOP_HUB + 0.6
local COUNTER_Z = -3.6
local COUNTER_TOP = FLOOR_TOP + 3.4

local function counterProps(parent: Instance, stall, cf: CFrame)
	-- Petits objets posés sur le comptoir selon le stand.
	local top = cf * CFrame.new(0, COUNTER_TOP + 0.2, COUNTER_Z)
	if stall.id == "Forge" then
		Build.part(parent, "Anvil", Vector3.new(2.4, 1, 1.2), top * CFrame.new(-5, 0.5, 0), rgb(70, 70, 80), { Material = Enum.Material.Metal })
		for i = 0, 2 do
			Build.deco(parent, "DisplaySword", Vector3.new(0.3, 3.4, 0.1), top * CFrame.new(2 + i * 1.6, 1.7, 0) * CFrame.Angles(0, 0, 0.15), rgb(210, 215, 225), {
				Material = Enum.Material.Metal,
				Reflectance = 0.2,
			})
			Build.deco(parent, "DisplayHilt", Vector3.new(1, 0.25, 0.25), top * CFrame.new(2 + i * 1.6, 0.2, 0), rgb(120, 70, 40))
		end
	elseif stall.id == "Traits" then
		for i = -1, 1 do
			local crystal = Build.deco(
				parent,
				"TraitCrystal",
				Vector3.new(0.9, 1.8, 0.9),
				top * CFrame.new(i * 3.5, 1, 0) * CFrame.Angles(0, math.rad(45), 0),
				stall.color:Lerp(rgb(255, 255, 255), 0.2),
				{
					Material = Enum.Material.Neon,
					Transparency = 0.1,
				}
			)
			crystal:SetAttribute("Bob", 0.3)
			CollectionService:AddTag(crystal, "Spin")
		end
	elseif stall.id == "Fusion" then
		local orb =
			Build.ball(parent, "FusionOrb", 2.4, (top * CFrame.new(0, 1.5, 0)).Position, stall.color, { Material = Enum.Material.Neon, Transparency = 0.15, CanCollide = false })
		orb:SetAttribute("Bob", 0.4)
		CollectionService:AddTag(orb, "Spin")
		local light = Instance.new("PointLight")
		light.Color = stall.color
		light.Range = 16
		light.Parent = orb
	elseif stall.id == "Evolution" then
		for i = -1, 1, 2 do
			local star = Build.deco(
				parent,
				"EvoStar",
				Vector3.new(1.4, 1.4, 0.3),
				top * CFrame.new(i * 3.5, 1.2, 0) * CFrame.Angles(0, 0, math.rad(45)),
				rgb(255, 220, 80),
				{ Material = Enum.Material.Neon }
			)
			star:SetAttribute("SpinAxis", "Y")
			CollectionService:AddTag(star, "Spin")
		end
	elseif stall.id == "Index" then
		local colors = { rgb(200, 60, 60), rgb(60, 120, 220), rgb(80, 180, 90), rgb(240, 190, 60) }
		for i = 1, 4 do
			Build.part(parent, "Book", Vector3.new(0.7, 1.6, 1.2), top * CFrame.new(-5 + i * 0.75, 0.8, 0), colors[i])
		end
	elseif stall.id == "Defi" then
		Build.part(parent, "BossBanner", Vector3.new(3, 2, 0.2), top * CFrame.new(4, 1, 0), rgb(30, 25, 30))
		Build.deco(parent, "BossEye", Vector3.new(0.6, 0.4, 0.1), top * CFrame.new(3.4, 1.2, -0.12), rgb(255, 40, 40), { Material = Enum.Material.Neon })
		Build.deco(parent, "BossEye", Vector3.new(0.6, 0.4, 0.1), top * CFrame.new(4.6, 1.2, -0.12), rgb(255, 40, 40), { Material = Enum.Material.Neon })
	end
end

-- Lanterne de papier lumineuse.
local function paperLantern(parent: Instance, position: Vector3, color: Color3, size: number?)
	local s = size or 1
	local lamp = DecorKit.ellipsoid(parent, "PaperLantern", Vector3.new(1.6, 2.1, 1.6) * s, CFrame.new(position), color, Enum.Material.Neon)
	lamp.Transparency = 0.05
	Build.deco(parent, "LanternCap", Vector3.new(1.1, 0.3, 1.1) * s, CFrame.new(position + Vector3.new(0, 1.1 * s, 0)), rgb(40, 30, 30))
	Build.deco(parent, "LanternCap", Vector3.new(1.1, 0.3, 1.1) * s, CFrame.new(position - Vector3.new(0, 1.1 * s, 0)), rgb(40, 30, 30))
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = lamp
	return lamp
end

-- Stand de marché japonais : plancher, comptoir, toit de tuiles à deux pans, rideaux (noren)
-- aux couleurs du stand, lanternes et grande enseigne.
local function buildStall(parent: Instance, stall)
	local position = polar(stall.angle, Layout.StallRadius)
	local cf = CFrame.lookAt(position, Vector3.new(0, 0, 0)) -- -Z local = vers le centre du hub
	local model = Build.model(parent, "Stall_" .. stall.id)
	local color = stall.color
	local light = color:Lerp(rgb(255, 255, 255), 0.6)
	local roofColor = color:Lerp(rgb(30, 25, 30), 0.35)
	local hw, hd = STALL_W / 2, STALL_D / 2
	-- Socle de pierre et plancher.
	Build.part(model, "Base", Vector3.new(STALL_W + 2, 0.6, STALL_D + 2), cf * CFrame.new(0, TOP_HUB + 0.1, 0), STONE_DARK, { Material = Enum.Material.Cobblestone })
	Build.part(model, "Floor", Vector3.new(STALL_W, 0.4, STALL_D), cf * CFrame.new(0, FLOOR_TOP - 0.2, 0), WOOD, { Material = Enum.Material.WoodPlanks })
	-- Mur du fond et murets latéraux.
	Build.part(model, "BackWall", Vector3.new(STALL_W, 12, 0.8), cf * CFrame.new(0, FLOOR_TOP + 6, hd - 0.4), WOOD_DARK, { Material = Enum.Material.WoodPlanks })
	Build.part(model, "BackPanel", Vector3.new(STALL_W - 5, 5.5, 0.2), cf * CFrame.new(0, FLOOR_TOP + 6.8, hd - 0.9), light, { Material = Enum.Material.Fabric })
	for _, side in { -1, 1 } do
		Build.part(model, "SideWall", Vector3.new(0.6, 5, STALL_D - 4), cf * CFrame.new(side * (hw - 0.3), FLOOR_TOP + 2.5, 1.5), WOOD, { Material = Enum.Material.WoodPlanks })
	end
	-- Comptoir.
	local counter = Build.part(model, "Counter", Vector3.new(STALL_W - 4, 3.2, 2.8), cf * CFrame.new(0, FLOOR_TOP + 1.6, COUNTER_Z), WOOD, { Material = Enum.Material.WoodPlanks })
	Build.part(model, "CounterTop", Vector3.new(STALL_W - 3.4, 0.4, 3.3), cf * CFrame.new(0, COUNTER_TOP, COUNTER_Z), rgb(196, 146, 96), { Material = Enum.Material.Wood })
	Build.part(model, "CounterStripe", Vector3.new(STALL_W - 4.1, 1.1, 0.14), cf * CFrame.new(0, FLOOR_TOP + 2, COUNTER_Z - 1.45), color, { Material = Enum.Material.Fabric })
	-- Poteaux.
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			Build.part(model, "Post", Vector3.new(1.2, 13, 1.2), cf * CFrame.new(x * (hw - 0.6), FLOOR_TOP + 6.5, z * (hd - 0.8)), WOOD_DARK, { Material = Enum.Material.Wood })
		end
	end
	-- Toit de tuiles à deux pans (faîtage parallèle à la façade).
	local eave = FLOOR_TOP + 13
	local roofH = 5
	for _, side in { -1, 1 } do
		Build.wedge(
			model,
			"Roof",
			Vector3.new(STALL_W + 5, roofH, hd + 2.5),
			cf * CFrame.new(0, eave + roofH / 2, side * (hd + 2.5) / 2) * CFrame.Angles(0, side > 0 and math.pi or 0, 0),
			roofColor,
			{ Material = Enum.Material.ClayRoofTiles }
		)
	end
	Build.part(model, "Ridge", Vector3.new(STALL_W + 6, 1, 1.4), cf * CFrame.new(0, eave + roofH + 0.2, 0), roofColor:Lerp(rgb(0, 0, 0), 0.35), {
		Material = Enum.Material.Slate,
	})
	Build.part(model, "Beam", Vector3.new(STALL_W + 1, 1, 1), cf * CFrame.new(0, eave - 0.3, -(hd - 0.8)), WOOD_DARK, { Material = Enum.Material.Wood })
	-- Rideaux noren sous l'avant-toit.
	local panels = 6
	for i = 0, panels - 1 do
		local x = -hw + 1.6 + (i + 0.5) * (STALL_W - 3.2) / panels
		Build.deco(model, "Noren", Vector3.new((STALL_W - 3.2) / panels - 0.25, 3.2, 0.15), cf * CFrame.new(x, eave - 2.3, -(hd - 0.6)), i % 2 == 0 and color or light, {
			Material = Enum.Material.Fabric,
		})
	end
	-- Lanternes aux poteaux avant.
	for _, side in { -1, 1 } do
		paperLantern(model, (cf * CFrame.new(side * (hw + 0.4), eave - 3, -(hd - 0.8))).Position, rgb(255, 120, 70))
	end
	-- Grande enseigne au-dessus de l'avant-toit (et au dos, visible depuis l'anneau).
	local sign = Build.part(model, "Sign", Vector3.new(16, 3.4, 0.6), cf * CFrame.new(0, eave + 2.6, -(hd + 1.6)) * CFrame.Angles(math.rad(-12), 0, 0), color)
	Build.part(model, "SignFrame", Vector3.new(16.8, 4.2, 0.4), cf * CFrame.new(0, eave + 2.6, -(hd + 1.3)) * CFrame.Angles(math.rad(-12), 0, 0), WOOD_DARK, {
		Material = Enum.Material.Wood,
	})
	Build.surfaceText(sign, Enum.NormalId.Front, stall.icon .. " " .. stall.title, rgb(255, 255, 255))
	local backSign = Build.part(model, "BackSign", Vector3.new(14, 3, 0.4), cf * CFrame.new(0, FLOOR_TOP + 8.5, hd + 0.1), color)
	Build.surfaceText(backSign, Enum.NormalId.Back, stall.icon .. " " .. stall.title, rgb(255, 255, 255))
	local subtitle =
		Build.part(model, "Subtitle", Vector3.new(12, 1.4, 0.2), cf * CFrame.new(0, FLOOR_TOP + 7.2, hd - 1.05), rgb(255, 255, 255), { Transparency = 1, CanCollide = false })
	Build.surfaceText(subtitle, Enum.NormalId.Front, stall.subtitle, color:Lerp(rgb(0, 0, 0), 0.35))
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

-- Lanterne de pierre japonaise (tōrō).
local function stoneLantern(parent: Instance, base: Vector3, scale: number?)
	local s = scale or 1
	local stone = rgb(170, 166, 160)
	Build.part(parent, "LanternBase", Vector3.new(2.6, 0.8, 2.6) * s, CFrame.new(base + Vector3.new(0, 0.4 * s, 0)), stone, { Material = Enum.Material.Slate })
	Build.disc(parent, "LanternPost", 3.2 * s, 1.1 * s, base + Vector3.new(0, 0.8 * s, 0), stone, { Material = Enum.Material.Slate })
	Build.part(parent, "LanternSeat", Vector3.new(2.4, 0.5, 2.4) * s, CFrame.new(base + Vector3.new(0, 4.2 * s, 0)), stone, { Material = Enum.Material.Slate })
	local light = Build.part(parent, "LanternLight", Vector3.new(1.7, 1.5, 1.7) * s, CFrame.new(base + Vector3.new(0, 5.2 * s, 0)), rgb(255, 200, 120), {
		Material = Enum.Material.Neon,
	})
	Build.wedge(
		parent,
		"LanternRoof",
		Vector3.new(3.2 * s, 0.9 * s, 1.6 * s),
		CFrame.new(base + Vector3.new(0, 6.4 * s, 0.8 * s)) * CFrame.Angles(0, math.pi, 0),
		stone,
		{ Material = Enum.Material.Slate }
	)
	Build.wedge(parent, "LanternRoof", Vector3.new(3.2 * s, 0.9 * s, 1.6 * s), CFrame.new(base + Vector3.new(0, 6.4 * s, -0.8 * s)), stone, { Material = Enum.Material.Slate })
	Build.ball(parent, "LanternTop", 0.8 * s, base + Vector3.new(0, 7.1 * s, 0), stone, { Material = Enum.Material.Slate })
	local point = Instance.new("PointLight")
	point.Color = rgb(255, 190, 110)
	point.Range = 18
	point.Brightness = 1.4
	point.Parent = light
end
WorldBuilder.stoneLantern = stoneLantern

local function buildHub(world: Folder)
	local hub = Build.folder(world, "Hub")
	local R = Layout.HubWallRadius
	-- Sol : grand pavage, anneau de dalles claires, place centrale en ardoise.
	slab(hub, "HubFloor", R + 1, TOP_HUB, 1.2, rgb(188, 180, 168), Enum.Material.Cobblestone)
	slab(hub, "HubRing", 72, TOP_HUB + 0.03, 1.2, rgb(226, 212, 186), Enum.Material.Pavement)
	slab(hub, "HubRingInner", 68, TOP_HUB + 0.06, 1.2, rgb(204, 198, 188), Enum.Material.Cobblestone)
	local glowRing = slab(hub, "PlazaGlow", 29, TOP_HUB + 0.08, 1.2, rgb(255, 140, 30), Enum.Material.Neon)
	glowRing:SetAttribute("UniverseTint", true)
	slab(hub, "Plaza", 28, TOP_HUB + 0.1, 1.2, rgb(126, 116, 142), Enum.Material.Slate)
	-- Allées dallées du centre vers chaque porte.
	for _, angle in Layout.PlotAngles do
		local dir = polarRad(angle, 1)
		local mid = dir * ((28 + R) / 2)
		Build.part(hub, "GateLane", Vector3.new(12, 0.3, R - 28), CFrame.lookAt(mid, mid + dir) + Vector3.new(0, TOP_HUB + 0.04, 0), rgb(222, 206, 176), {
			Material = Enum.Material.Pavement,
			CastShadow = false,
		})
	end
	-- Muret de pierre surmonté d'une haie arrondie, avec 6 portes sur les routes.
	local wall = Build.folder(hub, "Wall")
	local segments = 96
	local gateHalf = (Layout.PathWidth / 2 + 4) / R
	for i = 0, segments - 1 do
		local angle = (i + 0.5) / segments * math.pi * 2
		local onGate = false
		for _, gate in Layout.PlotAngles do
			local diff = math.abs((angle - gate + math.pi) % (math.pi * 2) - math.pi)
			if diff < gateHalf + math.pi / segments then
				onGate = true
			end
		end
		if not onGate then
			local length = 2 * math.pi * R / segments + 0.3
			local cf = CFrame.lookAt(polarRad(angle, R, TOP_HUB + 1.6), Vector3.new(0, TOP_HUB + 1.6, 0))
			Build.part(wall, "Wall", Vector3.new(length, 3.2, 2.6), cf, rgb(176, 170, 160), { Material = Enum.Material.Cobblestone })
			Build.part(wall, "WallCap", Vector3.new(length, 0.4, 3), cf * CFrame.new(0, 1.8, 0), STONE_DARK, { Material = Enum.Material.Slate })
			local hedge = Build.part(wall, "Hedge", Vector3.new(length + 0.6, 2.4, 2.4), cf * CFrame.new(0, 3, 0), rgb(70, 140, 64), {
				Material = Enum.Material.LeafyGrass,
				Shape = Enum.PartType.Cylinder,
				CanCollide = false,
			})
			hedge.CastShadow = true
		end
	end
	for _, gate in Layout.PlotAngles do
		local dir = polarRad(gate, 1)
		local right = Vector3.new(-dir.Z, 0, dir.X)
		local center = dir * R
		for _, side in { -1, 1 } do
			local pos = center + right * side * (Layout.PathWidth / 2 + 3)
			Build.part(
				wall,
				"GatePillar",
				Vector3.new(3.6, 10, 3.6),
				CFrame.lookAt(pos, pos + dir) + Vector3.new(0, TOP_HUB + 5, 0),
				STONE,
				{ Material = Enum.Material.Cobblestone }
			)
			Build.part(wall, "GatePillarCap", Vector3.new(4.4, 0.8, 4.4), CFrame.lookAt(pos, pos + dir) + Vector3.new(0, TOP_HUB + 10.3, 0), STONE_DARK, {
				Material = Enum.Material.Slate,
			})
			paperLantern(wall, pos + Vector3.new(0, TOP_HUB + 12.2, 0), rgb(255, 190, 90), 1.2)
		end
	end
	-- Fontaine et cristal d'univers au centre (sa couleur suit l'univers actuel).
	local center = Build.model(hub, "HubCrystal")
	local base = Vector3.new(0, TOP_HUB + 0.1, 0)
	Build.disc(center, "Basin", 1.6, 38, base, STONE_DARK, { Material = Enum.Material.Cobblestone })
	Build.disc(center, "Water", 0.3, 35.5, base + Vector3.new(0, 1.6, 0), rgb(70, 170, 240), { Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false })
	-- Margelle (anneau de blocs autour de l'eau).
	for i = 0, 31 do
		local angle = (i + 0.5) / 32 * math.pi * 2
		local cf = CFrame.lookAt(polarRad(angle, 18.6, base.Y + 2.1), Vector3.new(0, base.Y + 2.1, 0))
		Build.part(center, "BasinRim", Vector3.new(2 * math.pi * 18.6 / 32 + 0.2, 1.6, 2), cf, STONE, { Material = Enum.Material.Slate })
	end
	Build.disc(center, "Pedestal", 6.5, 10, base, STONE, { Material = Enum.Material.Marble })
	Build.disc(center, "PedestalTrim", 0.8, 11, base + Vector3.new(0, 6.5, 0), rgb(255, 200, 60), { Material = Enum.Material.Metal })
	local crystal = Build.deco(center, "Crystal", Vector3.new(6, 11, 6), CFrame.new(base + Vector3.new(0, 15, 0)) * CFrame.Angles(0, math.rad(45), 0), rgb(255, 140, 30), {
		Material = Enum.Material.Neon,
	})
	crystal:SetAttribute("SpinAxis", "Y")
	crystal:SetAttribute("SpinSpeed", 0.6)
	crystal:SetAttribute("Bob", 0.8)
	crystal:SetAttribute("UniverseTint", true)
	CollectionService:AddTag(crystal, "Spin")
	local glow = Instance.new("PointLight")
	glow.Range = 40
	glow.Brightness = 2
	glow.Color = rgb(255, 160, 60)
	glow.Parent = crystal
	for i = 0, 5 do
		local orb = Build.ball(center, "Orb", 1.8, polarRad(i / 6 * math.pi * 2, 9, 12), rgb(255, 255, 255), { Material = Enum.Material.Neon, CanCollide = false })
		orb:SetAttribute("Bob", 0.5 + i * 0.05)
		orb:SetAttribute("UniverseTint", true)
		CollectionService:AddTag(orb, "Spin")
	end
	local gui = Build.billboard(crystal, UDim2.fromOffset(360, 120), Vector3.new(0, 9, 0), 220)
	gui.Name = "UniverseBillboard"
	local title = Build.label(gui, "", UDim2.fromScale(1, 0.55), UDim2.fromScale(0, 0), rgb(255, 255, 255))
	title.Name = "Title"
	local timer = Build.label(gui, "", UDim2.fromScale(1, 0.4), UDim2.fromScale(0, 0.58), rgb(255, 225, 90))
	timer.Name = "Timer"
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
			local pos = polarRad(angle, 74)
			Build.disc(garden, "Planter", 1.8, 10, pos + Vector3.new(0, TOP_HUB, 0), STONE_DARK, { Material = Enum.Material.Cobblestone })
			Build.disc(garden, "Soil", 0.3, 9, pos + Vector3.new(0, TOP_HUB + 1.7, 0), rgb(110, 76, 52), { Material = Enum.Material.Ground })
			DecorKit.cherryTree(garden, pos + Vector3.new(0, TOP_HUB + 1.9, 0), { rng = hubRng, height = 15 })
			stoneLantern(garden, polarRad(math.rad(stall.angle + side * 11), 46) + Vector3.new(0, TOP_HUB, 0))
		end
	end
	for _, angle in Layout.PlotAngles do
		local dir = polarRad(angle, 1)
		local right = Vector3.new(-dir.Z, 0, dir.X)
		for _, side in { -1, 1 } do
			local benchPos = dir * 52 + right * side * 9
			local benchCF = CFrame.lookAt(benchPos, benchPos - right * side) + Vector3.new(0, TOP_HUB, 0)
			Build.part(garden, "Bench", Vector3.new(6, 0.5, 2), benchCF * CFrame.new(0, 1.6, 0), WOOD, { Material = Enum.Material.WoodPlanks })
			Build.part(garden, "BenchBack", Vector3.new(6, 1.6, 0.3), benchCF * CFrame.new(0, 2.6, 0.95), WOOD, { Material = Enum.Material.WoodPlanks })
			for _, x in { -2.5, 2.5 } do
				Build.part(garden, "BenchLeg", Vector3.new(0.4, 1.4, 1.8), benchCF * CFrame.new(x, 0.7, 0), WOOD_DARK, { Material = Enum.Material.Wood })
			end
			-- Lampadaire.
			local lampPos = dir * 32 + right * side * 8 + Vector3.new(0, TOP_HUB, 0)
			Build.disc(garden, "LampPost", 10, 0.6, lampPos, rgb(50, 44, 40), { Material = Enum.Material.Metal })
			local lamp = Build.ball(garden, "Lamp", 1.6, lampPos + Vector3.new(0, 10.6, 0), rgb(255, 232, 170), { Material = Enum.Material.Neon, CanCollide = false })
			local point = Instance.new("PointLight")
			point.Color = rgb(255, 220, 150)
			point.Range = 20
			point.Brightness = 1.2
			point.Parent = lamp
			-- Massif de fleurs au pied du muret.
			local bedPos = dir * (R - 6) + right * side * 16
			DecorKit.bush(garden, bedPos + Vector3.new(0, TOP_HUB, 0), { rng = hubRng, height = 3.2 })
			for _ = 1, 5 do
				local p = bedPos + Vector3.new(hubRng:NextNumber(-3, 3), TOP_HUB, hubRng:NextNumber(-3, 3))
				DecorKit.flower(garden, p, ({ rgb(255, 110, 150), rgb(255, 220, 90), rgb(255, 255, 255) })[hubRng:NextInteger(1, 3)], hubRng)
			end
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(10, 0.6, 10)
	spawn.CFrame = CFrame.new(Layout.Spawn + Vector3.new(0, TOP_HUB + 0.1, 0))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = rgb(255, 200, 60)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Transparency = 0.2
	spawn.Parent = hub
end

------------------------------------------------------------------------
-- Anneau d'univers (partie fixe) et arène du boss
------------------------------------------------------------------------

local function buildRing(world: Folder)
	local zone = Build.folder(world, "Zone")
	-- Sol de l'anneau (sa couleur et son matériau suivent l'univers).
	DecorKit.solRole(slab(zone, "RingBase", Layout.RingFenceRadius + 2, TOP_RING, 2, rgb(112, 176, 74), Enum.Material.Grass), "anneau")
	local fence = Build.folder(zone, "Fence")
	Build.fenceRing(fence, Vector3.new(0, TOP_RING, 0), Layout.RingFenceRadius, Layout.PlotAngles, Layout.PathWidth / 2 + 2, 4.5)
	-- Arène rocheuse du boss.
	local arena = Build.model(zone, "BossArena")
	local center = Layout.BossArena
	local radius = Layout.BossArenaRadius
	Build.disc(arena, "ArenaBase", 1.6, radius * 2 + 8, center + Vector3.new(0, -1.2, 0), rgb(120, 112, 105), { Material = Enum.Material.Rock })
	Build.disc(arena, "ArenaFloor", 1, radius * 2, center + Vector3.new(0, -0.4, 0), rgb(150, 142, 132), { Material = Enum.Material.Slate })
	local glowRing = Build.disc(arena, "ArenaGlow", 1.02, radius * 2 - 8, center + Vector3.new(0, -0.4, 0), rgb(255, 120, 40), {
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	glowRing:SetAttribute("UniverseTint", true)
	Build.disc(arena, "ArenaInner", 1.04, radius * 2 - 11, center + Vector3.new(0, -0.4, 0), rgb(140, 132, 122), { Material = Enum.Material.Slate })
	local pillars = 18
	for i = 0, pillars - 1 do
		local angle = i / pillars * math.pi * 2
		local pos = center + Vector3.new(math.cos(angle) * (radius + 3), 0, math.sin(angle) * (radius + 3))
		-- On laisse une entrée côté hub.
		if math.abs(math.cos(angle) + 1) > 0.25 then
			local height = rng:NextNumber(9, 18)
			DecorKit.rock(arena, CFrame.new(pos), rng:NextNumber(5, 8), { rng = rng, color = rgb(120, 114, 108), slot = "RocherArene" })
			Build.part(
				arena,
				"RockPillar",
				Vector3.new(rng:NextNumber(3.5, 5.5), height, rng:NextNumber(3.5, 5.5)),
				CFrame.new(pos + Vector3.new(0, height / 2 - 0.5, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 3), rng:NextNumber(-0.15, 0.15)),
				rgb(110, 104, 98),
				{ Material = Enum.Material.Rock }
			)
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
	local sign = Build.part(arena, "ArenaSign", Vector3.new(14, 3, 0.5), CFrame.lookAt(center + Vector3.new(-radius - 6, 8, 0), Vector3.new(0, 8, 0)), rgb(60, 40, 40))
	Build.surfaceText(sign, Enum.NormalId.Front, "👹 ARÈNE DU BOSS", rgb(255, 120, 100))
	for _, side in { -1, 1 } do
		Build.part(arena, "ArenaSignPost", Vector3.new(0.6, 8, 0.6), CFrame.new(center + Vector3.new(-radius - 6, 4, side * 6)), WOOD_DARK, { Material = Enum.Material.Wood })
	end
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
	Build.fenceRing(corner, center + Vector3.new(0, 0.4, 0), 29, { math.pi }, 7, 3.5)

	-- Toit de tissu (auvent) soutenu par 4 poteaux.
	for _, offset in { Vector3.new(16, 0, 16), Vector3.new(-16, 0, 16), Vector3.new(16, 0, -16), Vector3.new(-16, 0, -16) } do
		Build.part(corner, "AwningPole", Vector3.new(1.2, 16, 1.2), CFrame.new(center + offset + Vector3.new(0, 8, 0)), WOOD_DARK, { Material = Enum.Material.Wood })
	end
	local stripes = { rgb(240, 70, 70), rgb(255, 245, 230) }
	for i = 0, 7 do
		Build.deco(corner, "Awning", Vector3.new(35, 0.4, 4.3), CFrame.new(center + Vector3.new(0, 16.4, -15 + i * 4.3)), stripes[(i % 2) + 1], { Material = Enum.Material.Fabric })
	end

	-- Deux tables d'échange avec deux tabourets (Seats) chacune.
	for index, offset in { Vector3.new(0, 0, -8), Vector3.new(0, 0, 8) } do
		local tableModel = Build.model(corner, "TradeTable" .. index)
		local base = center + offset
		Build.part(tableModel, "Top", Vector3.new(8, 0.6, 4), CFrame.new(base + Vector3.new(0, 3, 0)), rgb(130, 85, 55), { Material = Enum.Material.Wood })
		Build.part(
			tableModel,
			"Cloth",
			Vector3.new(3, 0.1, 4.2),
			CFrame.new(base + Vector3.new(0, 3.35, 0)),
			rgb(200, 50, 60),
			{ Material = Enum.Material.Fabric, CanCollide = false }
		)
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
			seat.Color = rgb(70, 140, 220)
			seat.Material = Enum.Material.SmoothPlastic
			seat.TopSurface = Enum.SurfaceType.Smooth
			seat.Parent = tableModel
			Build.part(tableModel, "Stool" .. side, Vector3.new(1, 1, 1), CFrame.new(base + Vector3.new(x, 0.5, 0)), WOOD_DARK, { Material = Enum.Material.Wood })
		end
		CollectionService:AddTag(tableModel, "TradeTable")
	end

	local sign = Build.part(corner, "Sign", Vector3.new(20, 5, 0.6), CFrame.lookAt(center + Vector3.new(-32, 10, 0), center + Vector3.new(-70, 10, 0)), rgb(120, 80, 50), {
		Material = Enum.Material.Wood,
	})
	Build.surfaceText(sign, Enum.NormalId.Front, "🤝 COIN DES ÉCHANGES", rgb(255, 230, 120))
	for _, side in { -1, 1 } do
		Build.part(corner, "SignPost", Vector3.new(0.8, 10, 0.8), CFrame.new(center + Vector3.new(-32, 5, side * 9)), WOOD_DARK, { Material = Enum.Material.Wood })
	end
	stoneLantern(corner, center + Vector3.new(-26, 0, 22))
	stoneLantern(corner, center + Vector3.new(-26, 0, -22))
end

------------------------------------------------------------------------
-- Panneaux (classement + infos univers)
------------------------------------------------------------------------

local function buildBoards(world: Folder)
	local boards = Build.folder(world, "Boards")
	local function board(name: string, position: Vector3, title: string, color: Color3)
		local model = Build.model(boards, name)
		local face = CFrame.lookAt(position + Vector3.new(0, 15, 0), Vector3.new(0, 15, 0))
		local panel = Build.part(model, "Panel", Vector3.new(28, 20, 1), face, rgb(40, 35, 55))
		Build.part(model, "Frame", Vector3.new(30, 22, 0.8), face * CFrame.new(0, 0, 0.3), color)
		Build.part(model, "Header", Vector3.new(30, 3.6, 1.4), face * CFrame.new(0, 12, 0), color)
		for _, side in { -1, 1 } do
			Build.part(
				model,
				"Leg",
				Vector3.new(1.4, 25, 1.4),
				CFrame.new(position + Vector3.new(0, 12.5, 0)) * (face - face.Position) * CFrame.new(side * 13, 0, 0.6),
				WOOD_DARK,
				{
					Material = Enum.Material.Wood,
				}
			)
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
		return model
	end
	board("Leaderboard", Layout.Leaderboard, "🏆 LES PLUS PUISSANTS", rgb(255, 190, 40))
	board("InfoBoard", Layout.InfoBoard, "🌀 UNIVERS ACTUEL", rgb(120, 90, 255))
end

------------------------------------------------------------------------
-- Éclairage de base (les univers le modifient ensuite)
------------------------------------------------------------------------

function WorldBuilder.setupLighting()
	-- Lighting.Technology (Future) est réglé dans default.project.json : non modifiable par script.
	Lighting.Brightness = 3
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	local function ensure(parent: Instance, className: string, name: string)
		local existing = parent:FindFirstChild(name)
		if existing then
			return existing
		end
		local instance = Instance.new(className)
		instance.Name = name
		instance.Parent = parent
		return instance
	end
	local atmosphere = ensure(Lighting, "Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.2
	atmosphere.Glare = 0.25
	local bloom = ensure(Lighting, "BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.45
	bloom.Size = 30
	bloom.Threshold = 1.6
	local rays = ensure(Lighting, "SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.1
	rays.Spread = 0.6
	local grading = ensure(Lighting, "ColorCorrectionEffect", "Grading") :: ColorCorrectionEffect
	grading.Saturation = 0.15
	grading.Contrast = 0.08
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
		terrain.WaterColor = Color3.fromRGB(40, 150, 210)
		terrain.WaterTransparency = 0.6
		terrain.WaterWaveSize = 0.12
		terrain.WaterWaveSpeed = 8
		terrain.WaterReflectance = 0.6
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
		DecorKit.replaceSlots(existing)
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
	DecorKit.replaceSlots(world)
	return { world = world, zone = zone }
end

return WorldBuilder
