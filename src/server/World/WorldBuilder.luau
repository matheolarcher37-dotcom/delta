-- Construit la carte statique (inspirée des tycoons d'animé récents) :
--   * une île d'herbe à picots entourée d'une plage et de l'océan ;
--   * le HUB au centre : place pavée, cristal d'univers, 6 stands colorés avec leurs vendeurs
--     (Défi, Fusionner, Traits, Forgeron, Faire évoluer, Index) ;
--   * l'anneau d'univers autour du hub (son décor change toutes les 30 min, voir UniverseDecor),
--     avec l'arène rocheuse du boss ;
--   * des chemins à chevrons vers les bases, la promenade, le coin des échanges et les panneaux.
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

local WorldBuilder = {}

local rgb = Color3.fromRGB
local GRASS = { rgb(110, 200, 70), rgb(98, 186, 62) }
local PATH = rgb(226, 194, 142)
local CHEVRON = rgb(250, 238, 210)
local PATH_EDGE = rgb(176, 146, 104)
local STONE = rgb(214, 210, 200)
local STONE_DARK = rgb(160, 154, 145)
local WOOD = rgb(150, 100, 62)
local WOOD_DARK = rgb(105, 70, 45)
local SAND = rgb(240, 222, 165)
local SAND_WET = rgb(214, 192, 138)

local rng = Random.new(20261003)
local polar = Layout.polar

local function polarRad(angle: number, radius: number, y: number?): Vector3
	return Vector3.new(math.cos(angle) * radius, y or 0, math.sin(angle) * radius)
end

------------------------------------------------------------------------
-- Zones libres (pour placer la nature)
------------------------------------------------------------------------

local function nearPlot(position: Vector3, margin: number): boolean
	for i = 1, Layout.PlotCount do
		local localPos = Layout.plotCFrame(i):PointToObjectSpace(position)
		local half = Layout.PlotSize / 2 + margin
		if math.abs(localPos.X) < half and math.abs(localPos.Z) < half then
			return true
		end
	end
	return false
end

local function nearSpecial(position: Vector3, margin: number): boolean
	local flat = Vector3.new(position.X, 0, position.Z)
	for _, spot in { Layout.TradeCorner, Layout.Leaderboard, Layout.InfoBoard } do
		if (flat - spot).Magnitude < margin then
			return true
		end
	end
	return false
end

local function isFree(position: Vector3, margin: number): boolean
	local r = Vector3.new(position.X, 0, position.Z).Magnitude
	if r < Layout.WalkwayOuter + 4 + margin or r > Layout.IslandRadius - 6 then
		return false
	end
	return not nearPlot(position, margin) and not Layout.onPath(position, margin + 2) and not nearSpecial(position, 30 + margin)
end
WorldBuilder.isFree = isFree

------------------------------------------------------------------------
-- Île, plage et océan
------------------------------------------------------------------------

-- Anneau de blocs (segments tournés vers le centre) entre r1 et r2.
local function band(parent: Instance, name: string, r1: number, r2: number, segments: number, topY: number, thickness: number, color: (number) -> Color3, props)
	for i = 0, segments - 1 do
		local angle = (i + 0.5) / segments * math.pi * 2
		local length = 2 * math.pi * r2 / segments + 0.4
		local mid = (r1 + r2) / 2
		local y = topY - thickness / 2 + (i % 2) * 0.01
		local cf = CFrame.lookAt(polarRad(angle, mid, y), Vector3.new(0, y, 0))
		Build.part(parent, name, Vector3.new(length, thickness, r2 - r1), cf, color(i), props)
	end
end

local function buildIsland(world: Folder)
	local ground = Build.folder(world, "Ground")
	-- Herbe en damier avec des picots (comme les vieux jeux Roblox).
	local tile = Layout.GroundTile
	local count = math.ceil(Layout.IslandRadius * 2 / tile)
	local start = -count * tile / 2 + tile / 2
	for x = 0, count - 1 do
		for z = 0, count - 1 do
			local pos = Vector3.new(start + x * tile, -2, start + z * tile)
			if Vector3.new(pos.X, 0, pos.Z).Magnitude < Layout.IslandRadius - 4 then
				Build.part(ground, "Grass", Vector3.new(tile, 4, tile), CFrame.new(pos), GRASS[((x + z) % 2) + 1], {
					Material = Enum.Material.Plastic,
					TopSurface = Enum.SurfaceType.Studs,
				})
			end
		end
	end
	-- Plage tout autour (recouvre le bord en escalier de l'herbe).
	band(ground, "Beach", Layout.IslandRadius - 16, Layout.IslandRadius + 6, 110, 0.03, 4, function()
		return SAND
	end, { Material = Enum.Material.Sand })
	band(ground, "WetSand", Layout.IslandRadius + 6, Layout.BeachRadius, 120, -0.7, 4, function()
		return SAND_WET
	end, { Material = Enum.Material.Sand })
	-- Océan (remplacé par de la vraie eau Terrain quand le jeu tourne).
	local ocean = Build.part(world, "Ocean", Vector3.new(2048, 2, 2048), CFrame.new(0, -2.2, 0), rgb(40, 160, 230), {
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		Reflectance = 0.05,
		CanCollide = false,
		CastShadow = false,
	})
	ocean.CanQuery = false
	Build.part(world, "OceanFloor", Vector3.new(2048, 2, 2048), CFrame.new(0, -14, 0), rgb(30, 100, 150), { Material = Enum.Material.Sand })
	-- Rochers dans l'eau près du rivage.
	for i = 0, 17 do
		local angle = i / 18 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		Build.rock(ground, polarRad(angle, Layout.BeachRadius + rng:NextNumber(4, 20), -1.5), rng:NextNumber(1.6, 3), rgb(130, 125, 120), rng)
	end
	-- Murs invisibles pour ne pas tomber à l'eau.
	for i = 0, 35 do
		local angle = (i + 0.5) / 36 * math.pi * 2
		local cf = CFrame.lookAt(polarRad(angle, Layout.BeachRadius + 2, 40), Vector3.new(0, 40, 0))
		Build.part(ground, "Boundary", Vector3.new(2 * math.pi * (Layout.BeachRadius + 2) / 36 + 2, 90, 2), cf, Color3.new(1, 1, 1), { Transparency = 1 })
	end
end

------------------------------------------------------------------------
-- Chemins à chevrons
------------------------------------------------------------------------

local function chevronPath(parent: Instance, from: Vector3, to: Vector3)
	local dir = (to - from).Unit
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	local cf = CFrame.lookAt(mid, mid + dir) -- -Z local = vers l'extérieur
	Build.part(parent, "Path", Vector3.new(Layout.PathWidth, 0.3, length), cf + Vector3.new(0, 0.05, 0), PATH)
	for _, side in { -1, 1 } do
		Build.part(parent, "PathEdge", Vector3.new(0.8, 0.4, length), cf * CFrame.new(side * (Layout.PathWidth / 2 + 0.2), 0.08, 0), PATH_EDGE)
	end
	local arm = math.sqrt(4.2 ^ 2 + 3 ^ 2)
	local phi = math.atan2(3, 4.2)
	for d = 3, length - 3, 4.5 do
		local base = CFrame.lookAt(from + dir * d, from + dir * (d + 1)) + Vector3.new(0, 0.22, 0)
		Build.deco(parent, "Chevron", Vector3.new(arm, 0.12, 1.1), base * CFrame.new(2.1, 0, 0) * CFrame.Angles(0, -phi, 0), CHEVRON)
		Build.deco(parent, "Chevron", Vector3.new(arm, 0.12, 1.1), base * CFrame.new(-2.1, 0, 0) * CFrame.Angles(0, phi, 0), CHEVRON)
	end
end

local function buildPaths(world: Folder)
	local paths = Build.folder(world, "Paths")
	for _, angle in Layout.PlotAngles do
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		chevronPath(paths, dir * (Layout.HubWallRadius - 1), dir * (Layout.PlotRing - Layout.PlotSize / 2 + 1))
	end
	-- Promenade circulaire entre l'anneau et les bases.
	band(paths, "Walkway", Layout.WalkwayInner, Layout.WalkwayOuter, 84, 0.12, 0.6, function(i)
		return i % 2 == 0 and PATH or PATH:Lerp(CHEVRON, 0.25)
	end)
	band(paths, "WalkwayEdge", Layout.WalkwayOuter, Layout.WalkwayOuter + 1, 84, 0.16, 0.6, function()
		return PATH_EDGE
	end)
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

local function counterProps(parent: Instance, stall, cf: CFrame)
	-- Petits objets posés sur le comptoir selon le stand.
	local top = cf * CFrame.new(0, 2.95 + 0.2, -2)
	if stall.id == "Forge" then
		Build.part(parent, "Anvil", Vector3.new(2.4, 1, 1.2), top * CFrame.new(-3.5, 0.5, 0), rgb(70, 70, 80), { Material = Enum.Material.Metal })
		for i = 0, 2 do
			Build.deco(parent, "DisplaySword", Vector3.new(0.3, 3.4, 0.1), top * CFrame.new(1.5 + i * 1.3, 1.7, 0) * CFrame.Angles(0, 0, 0.15), rgb(210, 215, 225), {
				Material = Enum.Material.Metal,
				Reflectance = 0.2,
			})
			Build.deco(parent, "DisplayHilt", Vector3.new(1, 0.25, 0.25), top * CFrame.new(1.5 + i * 1.3, 0.2, 0), rgb(120, 70, 40))
		end
	elseif stall.id == "Traits" then
		for i = -1, 1 do
			local crystal = Build.deco(
				parent,
				"TraitCrystal",
				Vector3.new(0.9, 1.8, 0.9),
				top * CFrame.new(i * 3, 1, 0) * CFrame.Angles(0, math.rad(45), 0),
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
			Build.ball(parent, "FusionOrb", 2.2, (top * CFrame.new(0, 1.4, 0)).Position, stall.color, { Material = Enum.Material.Neon, Transparency = 0.15, CanCollide = false })
		orb:SetAttribute("Bob", 0.4)
		CollectionService:AddTag(orb, "Spin")
		local light = Instance.new("PointLight")
		light.Color = stall.color
		light.Range = 14
		light.Parent = orb
	elseif stall.id == "Evolution" then
		for i = -1, 1, 2 do
			local star = Build.deco(
				parent,
				"EvoStar",
				Vector3.new(1.4, 1.4, 0.3),
				top * CFrame.new(i * 3, 1.2, 0) * CFrame.Angles(0, 0, math.rad(45)),
				rgb(255, 220, 80),
				{ Material = Enum.Material.Neon }
			)
			star:SetAttribute("SpinAxis", "Y")
			CollectionService:AddTag(star, "Spin")
		end
	elseif stall.id == "Index" then
		local colors = { rgb(200, 60, 60), rgb(60, 120, 220), rgb(80, 180, 90), rgb(240, 190, 60) }
		for i = 1, 4 do
			Build.part(parent, "Book", Vector3.new(0.7, 1.6, 1.2), top * CFrame.new(-4 + i * 0.75, 0.8, 0), colors[i])
		end
	elseif stall.id == "Defi" then
		Build.part(parent, "BossBanner", Vector3.new(3, 2, 0.2), top * CFrame.new(3, 1, 0), rgb(30, 25, 30))
		Build.deco(parent, "BossEye", Vector3.new(0.6, 0.4, 0.1), top * CFrame.new(2.4, 1.2, -0.12), rgb(255, 40, 40), { Material = Enum.Material.Neon })
		Build.deco(parent, "BossEye", Vector3.new(0.6, 0.4, 0.1), top * CFrame.new(3.6, 1.2, -0.12), rgb(255, 40, 40), { Material = Enum.Material.Neon })
	end
end

local function buildStall(parent: Instance, stall)
	local position = polar(stall.angle, Layout.StallRadius)
	local cf = CFrame.lookAt(position, Vector3.new(0, 0, 0)) -- -Z local = vers le centre du hub
	local model = Build.model(parent, "Stall_" .. stall.id)
	local color = stall.color
	-- Plancher, mur du fond, comptoir.
	Build.part(model, "Floor", Vector3.new(14, 0.4, 9), cf * CFrame.new(0, 0.2, 0.5), WOOD, { Material = Enum.Material.WoodPlanks })
	Build.part(model, "BackWall", Vector3.new(14, 10, 0.8), cf * CFrame.new(0, 5, 4.6), WOOD_DARK, { Material = Enum.Material.WoodPlanks })
	Build.part(model, "BackPanel", Vector3.new(11, 5, 0.2), cf * CFrame.new(0, 6, 4.1), color:Lerp(rgb(255, 255, 255), 0.55))
	local counter = Build.part(model, "Counter", Vector3.new(12, 2.4, 2.6), cf * CFrame.new(0, 1.6, -2), WOOD, { Material = Enum.Material.WoodPlanks })
	Build.part(model, "CounterTop", Vector3.new(12.6, 0.4, 3), cf * CFrame.new(0, 2.95, -2), rgb(190, 140, 90), { Material = Enum.Material.Wood })
	Build.part(model, "CounterStripe", Vector3.new(12.1, 0.9, 0.12), cf * CFrame.new(0, 2.0, -3.33), color)
	-- Poteaux et auvent rayé.
	for _, side in { -1, 1 } do
		Build.part(model, "Post", Vector3.new(0.8, 9, 0.8), cf * CFrame.new(side * 6.6, 4.7, -4), WOOD_DARK, { Material = Enum.Material.Wood })
	end
	local tilt = -math.atan2(2.2, 8.6)
	for i = 0, 5 do
		local x = -6.25 + i * 2.5
		Build.deco(model, "Awning", Vector3.new(2.5, 0.3, 9.4), cf * CFrame.new(x, 9.9, 0.2) * CFrame.Angles(tilt, 0, 0), i % 2 == 0 and color or rgb(255, 250, 240), {
			Material = Enum.Material.Fabric,
		})
	end
	for i = 0, 12 do
		Build.ball(model, "Valance", 1.15, (cf * CFrame.new(-6.6 + i * 1.1, 8.6, -4.3)).Position, i % 2 == 0 and color or rgb(255, 250, 240), {
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
	end
	-- Enseigne.
	local sign = Build.part(model, "Sign", Vector3.new(12, 2.6, 0.5), cf * CFrame.new(0, 12.4, -3.4), color)
	Build.part(model, "SignFrame", Vector3.new(12.8, 3.3, 0.4), cf * CFrame.new(0, 12.4, -3.15), WOOD_DARK, { Material = Enum.Material.Wood })
	Build.surfaceText(sign, Enum.NormalId.Front, stall.icon .. " " .. stall.title, rgb(255, 255, 255))
	-- Enseigne aussi au dos (visible en arrivant par l'anneau).
	local backSign = Build.part(model, "BackSign", Vector3.new(11, 2.4, 0.3), cf * CFrame.new(0, 7.5, 5.1), color)
	Build.surfaceText(backSign, Enum.NormalId.Back, stall.icon .. " " .. stall.title, rgb(255, 255, 255))
	local subtitle = Build.part(model, "Subtitle", Vector3.new(9, 1.1, 0.2), cf * CFrame.new(0, 6.6, 3.95), rgb(255, 255, 255), { Transparency = 1, CanCollide = false })
	Build.surfaceText(subtitle, Enum.NormalId.Front, stall.subtitle, color:Lerp(rgb(0, 0, 0), 0.35))
	counterProps(model, stall, cf)
	-- Interaction.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StallPrompt"
	prompt.ActionText = stall.menu == "Challenge" and "Se téléporter" or "Ouvrir"
	prompt.ObjectText = stall.title .. " · " .. stall.subtitle
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 13
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = counter
	model:SetAttribute("Menu", stall.menu)
	model:SetAttribute("StallId", stall.id)
	CollectionService:AddTag(model, "HubStall")
	-- Vendeur derrière le comptoir.
	local look = NPC_LOOKS[stall.id]
	if look then
		local npc = CharacterBuilder.build(look, { name = NPC_NAMES[stall.id], anchored = true })
		npc:PivotTo(cf * CFrame.new(0, 0.4 + CharacterBuilder.RootHeight, 1.2))
		npc:SetAttribute("NPC", true)
		npc:SetAttribute("DisplayName", NPC_NAMES[stall.id])
		npc.Parent = model
		CollectionService:AddTag(npc, "AnimeRig")
	end
	return model
end

local function buildHub(world: Folder)
	local hub = Build.folder(world, "Hub")
	-- Sol : pavés clairs, anneau décoratif et place centrale.
	Build.disc(hub, "HubFloor", 1, Layout.HubWallRadius * 2, Vector3.new(0, -0.9, 0), STONE, { Material = Enum.Material.Pavement })
	Build.disc(hub, "HubRing", 1.02, 74, Vector3.new(0, -0.9, 0), rgb(232, 200, 150), { Material = Enum.Material.Pavement })
	Build.disc(hub, "HubRingInner", 1.04, 70, Vector3.new(0, -0.9, 0), STONE:Lerp(rgb(255, 255, 255), 0.15), { Material = Enum.Material.Pavement })
	Build.disc(hub, "Plaza", 1.06, 30, Vector3.new(0, -0.9, 0), rgb(120, 110, 140), { Material = Enum.Material.Slate })
	-- Allées colorées du centre vers chaque stand.
	for _, stall in Layout.Stalls do
		local dir = polar(stall.angle, 1)
		local cf = CFrame.lookAt(dir * 21, dir * 30) + Vector3.new(0, 0.2, 0)
		Build.deco(hub, "StallLane", Vector3.new(4, 0.1, 14), cf, stall.color:Lerp(rgb(255, 255, 255), 0.35))
	end
	-- Muret et haies, avec 6 portes sur les chemins.
	local wall = Build.folder(hub, "Wall")
	local segments = 72
	for i = 0, segments - 1 do
		local angle = (i + 0.5) / segments * math.pi * 2
		local onGate = false
		for _, gate in Layout.PlotAngles do
			local diff = math.abs((angle - gate + math.pi) % (math.pi * 2) - math.pi)
			if diff < math.rad(8) then
				onGate = true
			end
		end
		if not onGate then
			local length = 2 * math.pi * Layout.HubWallRadius / segments + 0.3
			local cf = CFrame.lookAt(polarRad(angle, Layout.HubWallRadius, 1), Vector3.new(0, 1, 0))
			Build.part(wall, "Wall", Vector3.new(length, 2, 2.4), cf, STONE_DARK, { Material = Enum.Material.Slate })
			Build.part(wall, "Hedge", Vector3.new(length, 1.6, 1.8), cf * CFrame.new(0, 1.8, 0), rgb(60, 150, 60), { Material = Enum.Material.Grass })
		end
	end
	for _, gate in Layout.PlotAngles do
		for _, side in { -1, 1 } do
			local pos = polarRad(gate + side * math.rad(9), Layout.HubWallRadius)
			Build.part(wall, "GatePillar", Vector3.new(2.6, 6, 2.6), CFrame.new(pos + Vector3.new(0, 3, 0)), STONE, { Material = Enum.Material.Slate })
			Build.lantern(wall, pos + Vector3.new(0, 6, 0), rgb(255, 200, 100), 2)
		end
	end
	-- Cristal d'univers au centre (sa couleur suit l'univers actuel).
	local center = Build.model(hub, "HubCrystal")
	Build.disc(center, "Basin", 1.2, 22, Vector3.new(0, 0, 0), STONE_DARK, { Material = Enum.Material.Slate })
	Build.disc(center, "Water", 0.3, 19.5, Vector3.new(0, 1.05, 0), rgb(80, 180, 255), { Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
	Build.disc(center, "Pedestal", 4, 7, Vector3.new(0, 0.5, 0), STONE, { Material = Enum.Material.Marble })
	Build.disc(center, "PedestalTrim", 0.6, 7.6, Vector3.new(0, 4.2, 0), rgb(255, 200, 60), { Material = Enum.Material.Metal })
	local crystal = Build.deco(center, "Crystal", Vector3.new(4, 7, 4), CFrame.new(0, 10, 0) * CFrame.Angles(0, math.rad(45), 0), rgb(255, 140, 30), {
		Material = Enum.Material.Neon,
		Transparency = 0.1,
	})
	crystal:SetAttribute("SpinAxis", "Y")
	crystal:SetAttribute("SpinSpeed", 0.6)
	crystal:SetAttribute("Bob", 0.8)
	crystal:SetAttribute("UniverseTint", true)
	CollectionService:AddTag(crystal, "Spin")
	local glow = Instance.new("PointLight")
	glow.Range = 30
	glow.Brightness = 2
	glow.Color = rgb(255, 160, 60)
	glow.Parent = crystal
	for i = 0, 5 do
		local orb = Build.ball(center, "Orb", 1.4, polarRad(i / 6 * math.pi * 2, 6.5, 8), rgb(255, 255, 255), { Material = Enum.Material.Neon, CanCollide = false })
		orb:SetAttribute("Bob", 0.5 + i * 0.05)
		orb:SetAttribute("UniverseTint", true)
		CollectionService:AddTag(orb, "Spin")
	end
	local gui = Build.billboard(crystal, UDim2.fromOffset(320, 110), Vector3.new(0, 7, 0), 160)
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
	-- Bancs, lampadaires et pots de fleurs.
	for i = 0, 5 do
		local angle = math.rad(i * 60 + 30)
		local pos = polarRad(angle, 40)
		local cf = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
		for _, side in { -1, 1 } do
			local benchCF = cf * CFrame.new(side * 9, 0, 0)
			Build.part(hub, "Bench", Vector3.new(5, 0.5, 1.8), benchCF * CFrame.new(0, 1.3, 0), WOOD, { Material = Enum.Material.WoodPlanks })
			Build.part(hub, "BenchBack", Vector3.new(5, 1.4, 0.3), benchCF * CFrame.new(0, 2.2, 0.85), WOOD, { Material = Enum.Material.WoodPlanks })
			Build.flower(hub, (cf * CFrame.new(side * 13, 0, 0)).Position, rgb(255, 120, 150))
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(10, 0.6, 10)
	spawn.CFrame = CFrame.new(Layout.Spawn + Vector3.new(0, 0.2, 0))
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
	-- Sol de secours sous le décor (le décor de chaque univers pose son propre sol par-dessus).
	local base = Build.disc(zone, "RingBase", 1, Layout.RingFenceRadius * 2 + 2, Vector3.new(0, -1, 0), rgb(150, 130, 100))
	base.Material = Enum.Material.Ground
	local fence = Build.folder(zone, "Fence")
	Build.fenceRing(fence, Vector3.new(0, 0.1, 0), Layout.RingFenceRadius, Layout.PlotAngles, Layout.PathWidth / 2 + 2, 4.5)
	-- Arène rocheuse du boss.
	local arena = Build.model(zone, "BossArena")
	local center = Layout.BossArena
	local radius = Layout.BossArenaRadius
	Build.disc(arena, "ArenaBase", 1.6, radius * 2 + 6, center + Vector3.new(0, -1.2, 0), rgb(120, 112, 105), { Material = Enum.Material.Rock })
	Build.disc(arena, "ArenaFloor", 1, radius * 2, center + Vector3.new(0, -0.4, 0), rgb(150, 142, 132), { Material = Enum.Material.Slate })
	local glowRing = Build.disc(arena, "ArenaGlow", 1.02, radius * 2 - 6, center + Vector3.new(0, -0.4, 0), rgb(255, 120, 40), {
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	glowRing:SetAttribute("UniverseTint", true)
	Build.disc(arena, "ArenaInner", 1.04, radius * 2 - 8, center + Vector3.new(0, -0.4, 0), rgb(140, 132, 122), { Material = Enum.Material.Slate })
	for i = 0, 13 do
		local angle = i / 14 * math.pi * 2
		local pos = center + Vector3.new(math.cos(angle) * (radius + 2), 0, math.sin(angle) * (radius + 2))
		-- On laisse une entrée côté hub.
		if math.abs(math.cos(angle) + 1) > 0.3 then
			local height = rng:NextNumber(5, 11)
			Build.part(
				arena,
				"RockPillar",
				Vector3.new(rng:NextNumber(3, 5), height, rng:NextNumber(3, 5)),
				CFrame.new(pos + Vector3.new(0, height / 2 - 0.5, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 3), rng:NextNumber(-0.15, 0.15)),
				rgb(110, 104, 98),
				{ Material = Enum.Material.Rock }
			)
			if i % 3 == 0 then
				local shard = Build.deco(
					arena,
					"Shard",
					Vector3.new(1.4, 3, 1.4),
					CFrame.new(pos + Vector3.new(0, height + 0.8, 0)) * CFrame.Angles(0.2, rng:NextNumber(0, 3), 0.2),
					rgb(255, 120, 40),
					{
						Material = Enum.Material.Neon,
					}
				)
				shard:SetAttribute("UniverseTint", true)
			end
		end
	end
	local sign = Build.part(arena, "ArenaSign", Vector3.new(12, 2.6, 0.5), CFrame.lookAt(center + Vector3.new(-radius - 4, 7, 0), Vector3.new(0, 7, 0)), rgb(60, 40, 40))
	Build.surfaceText(sign, Enum.NormalId.Front, "👹 ARÈNE DU BOSS", rgb(255, 120, 100))
	for _, side in { -1, 1 } do
		Build.part(arena, "ArenaSignPost", Vector3.new(0.6, 7, 0.6), CFrame.new(center + Vector3.new(-radius - 4, 3.5, side * 5)), WOOD_DARK, { Material = Enum.Material.Wood })
	end
	Build.folder(zone, "Enemies")
	return zone
end

------------------------------------------------------------------------
-- Nature
------------------------------------------------------------------------

local function palm(parent: Instance, base: Vector3)
	local trunk = rgb(160, 120, 80)
	local height = rng:NextNumber(10, 15)
	local lean = rng:NextNumber(-0.25, 0.25)
	local top = base
	for i = 0, 4 do
		local segment = CFrame.new(base + Vector3.new(lean * i * 1.2, i * height / 5 + height / 10, 0)) * CFrame.Angles(0, 0, -lean * 0.4)
		Build.part(
			parent,
			"PalmTrunk",
			Vector3.new(1.3 - i * 0.12, height / 5 + 0.2, 1.3 - i * 0.12),
			segment,
			trunk:Lerp(rgb(0, 0, 0), (i % 2) * 0.1),
			{ Material = Enum.Material.Wood }
		)
		top = segment.Position + Vector3.new(0, height / 10, 0)
	end
	for i = 0, 6 do
		local angle = i / 7 * math.pi * 2
		local cf = CFrame.new(top) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -2.8) * CFrame.Angles(-0.45, 0, 0)
		Build.deco(parent, "PalmLeaf", Vector3.new(1.8, 0.25, 6), cf, rgb(60, 170, 70), { Material = Enum.Material.Grass })
	end
	Build.ball(parent, "Coconut", 0.9, top + Vector3.new(0.5, -0.5, 0.3), rgb(110, 75, 40))
end

local function buildNature(world: Folder)
	local nature = Build.folder(world, "Nature")
	local flowerColors = { rgb(255, 90, 110), rgb(255, 220, 80), rgb(150, 110, 255), rgb(255, 255, 255), rgb(90, 180, 255) }
	local half = Layout.IslandRadius
	local placed, attempts = 0, 0
	while placed < 70 and attempts < 3000 do
		attempts += 1
		local pos = Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
		if pos.Magnitude > 270 and isFree(pos, 8) then
			if rng:NextNumber() < 0.65 then
				Build.tree(nature, pos, rng:NextNumber(1.1, 1.7), nil, nil, rng)
			else
				Build.pine(nature, pos, rng:NextNumber(1.2, 1.7))
			end
			placed += 1
		end
	end
	for _ = 1, 220 do
		local pos = Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
		if isFree(pos, 2) then
			Build.flower(nature, pos, flowerColors[rng:NextInteger(1, #flowerColors)])
		end
	end
	for _ = 1, 45 do
		local pos = Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
		if isFree(pos, 4) then
			if rng:NextNumber() < 0.6 then
				Build.bush(nature, pos, rng:NextNumber(0.8, 1.4))
			else
				Build.rock(nature, pos, rng:NextNumber(0.8, 1.5), nil, rng)
			end
		end
	end
	-- Palmiers sur la plage.
	for i = 0, 27 do
		local angle = i / 28 * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local pos = polarRad(angle, Layout.IslandRadius - 4 + rng:NextNumber(-2, 4))
		if not nearPlot(pos, 4) then
			palm(nature, pos)
		end
	end
end

------------------------------------------------------------------------
-- Coin des échanges (table d'échange)
------------------------------------------------------------------------

local function buildTradeCorner(world: Folder)
	local corner = Build.model(world, "TradeCorner")
	local center = Layout.TradeCorner
	local deck = Build.disc(corner, "Deck", 1, 46, center + Vector3.new(0, -0.45, 0), WOOD, { Material = Enum.Material.WoodPlanks })
	deck.Name = "Deck"
	Build.fenceRing(corner, center + Vector3.new(0, 0.4, 0), 23, { math.pi }, 6, 3.5)

	-- Toit de tissu (auvent) soutenu par 4 poteaux.
	for _, offset in { Vector3.new(14, 0, 14), Vector3.new(-14, 0, 14), Vector3.new(14, 0, -14), Vector3.new(-14, 0, -14) } do
		Build.part(corner, "AwningPole", Vector3.new(1, 14, 1), CFrame.new(center + offset + Vector3.new(0, 7.4, 0)), WOOD_DARK, { Material = Enum.Material.Wood })
	end
	local stripes = { rgb(240, 70, 70), rgb(255, 245, 230) }
	for i = 0, 7 do
		Build.deco(
			corner,
			"Awning",
			Vector3.new(30, 0.4, 3.75),
			CFrame.new(center + Vector3.new(0, 14.6, -13.1 + i * 3.75)),
			stripes[(i % 2) + 1],
			{ Material = Enum.Material.Fabric }
		)
	end

	-- Deux tables d'échange avec deux tabourets (Seats) chacune.
	for index, offset in { Vector3.new(0, 0, -7), Vector3.new(0, 0, 7) } do
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

	local sign = Build.part(corner, "Sign", Vector3.new(18, 4.5, 0.6), CFrame.lookAt(center + Vector3.new(-25, 9, 0), center + Vector3.new(-60, 9, 0)), rgb(120, 80, 50), {
		Material = Enum.Material.Wood,
	})
	Build.surfaceText(sign, Enum.NormalId.Front, "🤝 COIN DES ÉCHANGES", rgb(255, 230, 120))
	for _, side in { -1, 1 } do
		Build.part(corner, "SignPost", Vector3.new(0.8, 9, 0.8), CFrame.new(center + Vector3.new(-25, 4.5, side * 8)), WOOD_DARK, { Material = Enum.Material.Wood })
	end
	Build.lantern(corner, center + Vector3.new(-20, 0, 18), rgb(255, 200, 90))
	Build.lantern(corner, center + Vector3.new(-20, 0, -18), rgb(255, 200, 90))
end

------------------------------------------------------------------------
-- Panneaux (classement + infos univers)
------------------------------------------------------------------------

local function buildBoards(world: Folder)
	local boards = Build.folder(world, "Boards")
	local function board(name: string, position: Vector3, title: string, color: Color3)
		local model = Build.model(boards, name)
		local face = CFrame.lookAt(position + Vector3.new(0, 12, 0), Vector3.new(0, 12, 0))
		local panel = Build.part(model, "Panel", Vector3.new(22, 16, 1), face, rgb(40, 35, 55))
		Build.part(model, "Frame", Vector3.new(23.5, 17.5, 0.8), face * CFrame.new(0, 0, 0.3), color)
		Build.part(model, "Header", Vector3.new(23.5, 3, 1.4), face * CFrame.new(0, 9.5, 0), color)
		for _, side in { -1, 1 } do
			Build.part(model, "Leg", Vector3.new(1.2, 20, 1.2), CFrame.new(position + Vector3.new(0, 10, 0)) * (face - face.Position) * CFrame.new(side * 10, 0, 0.6), WOOD_DARK, {
				Material = Enum.Material.Wood,
			})
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
end

-- Vraie eau (Terrain) autour de l'île, uniquement en jeu.
function WorldBuilder.fillWater(world: Instance)
	local terrain = Workspace.Terrain
	if terrain:GetAttribute("WaterFilled") then
		return
	end
	local ok = pcall(function()
		terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(2048, 10, 2048), Enum.Material.Water)
		terrain.WaterColor = Color3.fromRGB(30, 150, 220)
		terrain.WaterTransparency = 0.6
		terrain.WaterWaveSize = 0.12
		terrain.WaterWaveSpeed = 8
		terrain.WaterReflectance = 0.6
	end)
	if ok then
		terrain:SetAttribute("WaterFilled", true)
		local ocean = world:FindFirstChild("Ocean") :: BasePart?
		if ocean then
			ocean.Transparency = 1
		end
	end
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.65
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = terrain
end

-- Construit la carte (ou garde celle déjà présente dans le fichier).
function WorldBuilder.build(options: { water: boolean? }?)
	local existing = Workspace:FindFirstChild("World")
	if existing and existing:GetAttribute("Baked") then
		WorldBuilder.setupLighting()
		if not options or options.water ~= false then
			WorldBuilder.fillWater(existing)
		end
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
	buildNature(world)
	buildTradeCorner(world)
	buildBoards(world)
	Build.folder(world, "Plots")
	if not options or options.water ~= false then
		WorldBuilder.fillWater(world)
	end
	return { world = world, zone = zone }
end

return WorldBuilder
