-- ZONE ANTI-AFK (dojo d'entraînement) posée à Layout.AfkZone, entre deux bases.
--
-- Exactement 3 punching-balls : 3 joueurs peuvent taper en même temps, chacun le sien (le sac est
-- réservé au joueur qui tape et libéré quand il s'en va). Les sacs n'attaquent pas : rien dans la
-- zone ne fait de dégâts. On tape avec son épée (clic, gâchette de la manette, ou l'invite
-- « Frapper » : E / X / toucher) ; les coups sont comptés par le serveur (QuestService).
-- 1000 coups = 20 gemmes de trait (= 20 relances), avec des paliers en chemin.
--
-- Construction : dalle de pierre ronde, plancher de dojo, muret ouvert côté hub, portique
-- d'entrée avec son enseigne, les 3 postes (potence de bois, chaîne, sac de cuir, tapis numéroté,
-- compteur au-dessus), deux tableaux (paliers et mode d'emploi), lanternes, bannières, bancs et
-- une grande balise visible de loin.
--
-- Repère local : -Z = vers le hub (entrée), +Z = fond de la zone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Quests = require(Shared.Config.Quests)
local Build = require(script.Parent.Parent.Modules.Build)
local Core = require(script.Parent.Kit.Core)
local Props = require(script.Parent.Kit.Props)

local AfkZone = {}

local rgb = Color3.fromRGB
local shade = Core.shade

local FLOOR_TOP = 0.9
local ZONE_RADIUS = 36
local STONE = rgb(150, 144, 136)
local STONE_DARK = rgb(108, 102, 96)
local WOOD_DARK = rgb(84, 58, 40)
local PLANK = rgb(196, 160, 112)
local LEATHER = rgb(178, 38, 34)
local LEATHER_DARK = rgb(52, 30, 26)
local METAL = rgb(70, 72, 78)
local CREAM = rgb(248, 236, 206)

-- Couleur du tapis de chaque poste.
AfkZone.StationColors = { rgb(214, 64, 52), rgb(56, 120, 214), rgb(236, 170, 40) }

-- Angle (degrés, repère local) et distance au centre de chaque poste.
local STATION_ANGLES = { -42, 0, 42 }
local STATION_RADIUS = 17

-- Planche peinte : cadre de bois, panneau, lettres peintes (police à caractère).
local function plank(parent: Instance, cf: CFrame, w: number, h: number, text: string, opts: { [string]: any }?)
	local o = opts or {}
	Build.deco(parent, "PlankFrame", Vector3.new(w + 0.7, h + 0.7, 0.36), cf, o.frame or WOOD_DARK, { Material = Enum.Material.Wood })
	local panel = Build.deco(parent, "Plank", Vector3.new(w, h, 0.5), cf, o.bg or rgb(92, 62, 40), { Material = Enum.Material.WoodPlanks })
	-- ferrures aux coins
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			Build.deco(parent, "PlankBolt", Vector3.new(0.35, 0.35, 0.2), cf * CFrame.new(x * (w / 2 - 0.35), y * (h / 2 - 0.35), -0.28), METAL, {
				Material = Enum.Material.Metal,
			})
		end
	end
	if text ~= "" then
		local label = Build.surfaceText(panel, Enum.NormalId.Front, text, o.text or CREAM, {
			Font = o.font or Enum.Font.Bangers,
			TextStrokeTransparency = 0.55,
			TextStrokeColor3 = rgb(40, 24, 16),
		})
		if o.both then
			Build.surfaceText(panel, Enum.NormalId.Back, text, o.text or CREAM, {
				Font = o.font or Enum.Font.Bangers,
				TextStrokeTransparency = 0.55,
				TextStrokeColor3 = rgb(40, 24, 16),
			})
		end
		return panel, label
	end
	return panel, nil
end

------------------------------------------------------------------------
-- Un poste : potence, chaîne, sac, tapis, compteur, invite
------------------------------------------------------------------------

local function counterGui(adornee: BasePart, index: number, color: Color3): BillboardGui
	local gui = Build.billboard(adornee, UDim2.fromOffset(260, 132), Vector3.new(0, 9.2, 0), 70)
	gui.Name = "Counter"
	gui.LightInfluence = 0
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = rgb(16, 16, 24)
	card.BackgroundTransparency = 0.15
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = card
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(rgb(46, 46, 66), rgb(16, 16, 24))
	gradient.Rotation = 90
	gradient.Parent = card

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.Size = UDim2.fromOffset(34, 34)
	badge.Position = UDim2.fromOffset(10, 8)
	badge.BackgroundColor3 = color
	badge.Parent = card
	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(1, 0)
	badgeCorner.Parent = badge
	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = rgb(10, 10, 14)
	badgeStroke.Thickness = 2
	badgeStroke.Parent = badge
	local number = Build.label(badge, tostring(index), UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1), rgb(255, 255, 255), Enum.Font.GothamBlack)
	number.Name = "Number"

	local owner = Build.label(card, "LIBRE", UDim2.new(1, -60, 0, 26), UDim2.fromOffset(52, 12), rgb(130, 240, 150), Enum.Font.GothamBlack)
	owner.Name = "Owner"
	owner.TextXAlignment = Enum.TextXAlignment.Left

	local count = Build.label(card, "Sors ton épée et frappe !", UDim2.new(1, -20, 0, 38), UDim2.fromOffset(10, 46), rgb(255, 255, 255), Enum.Font.GothamBlack)
	count.Name = "Count"

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.new(1, -20, 0, 14)
	bar.Position = UDim2.fromOffset(10, 88)
	bar.BackgroundColor3 = rgb(8, 8, 12)
	bar.Parent = card
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = rgb(80, 230, 255)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new(rgb(160, 250, 255), rgb(40, 170, 255))
	fillGradient.Rotation = 90
	fillGradient.Parent = fill

	local nextTier = Build.label(card, "1000 coups = 20 relances de trait", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 106), rgb(150, 236, 255), Enum.Font.GothamBold)
	nextTier.Name = "Next"
	return gui
end

local function buildStation(parent: Instance, index: number, base: CFrame)
	local color = AfkZone.StationColors[index] or rgb(200, 200, 200)
	local station = Build.model(parent, "Station" .. index)
	station:SetAttribute("Station", index)
	station:SetAttribute("Count", 0)
	station:SetAttribute("HitTick", 0)

	-- Tapis numéroté (bord blanc) sur le plancher.
	Build.deco(station, "MatEdge", Vector3.new(9.4, 0.12, 9.4), base * CFrame.new(0, 0.06, 0), CREAM, { Material = Enum.Material.Fabric })
	local mat = Build.deco(station, "Mat", Vector3.new(8.6, 0.16, 8.6), base * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, math.pi, 0), color, { Material = Enum.Material.Fabric })
	Build.surfaceText(mat, Enum.NormalId.Top, tostring(index), shade(color, 0.35), {
		Font = Enum.Font.Bangers,
		TextStrokeTransparency = 1,
		TextTransparency = 0.25,
	})

	-- Marque au sol devant le sac : « place-toi ici » (cercle blanc + flèche)
	local spot = base * CFrame.new(0, 0.12, -5.8)
	Build.deco(station, "StandRing", Vector3.new(0.05, 3.2, 3.2), spot * CFrame.Angles(0, 0, math.rad(90)), CREAM, {
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Cylinder,
	})
	Build.deco(station, "StandDot", Vector3.new(0.06, 2.5, 2.5), spot * CFrame.new(0, 0.01, 0) * CFrame.Angles(0, 0, math.rad(90)), shade(color, -0.25), {
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Cylinder,
	})
	-- Potence : deux poteaux, poutre, jambes de force, pieds en pierre.
	local postX = 3.6
	local beamY = 11.2
	for _, side in { -1, 1 } do
		Build.part(station, "Post", Vector3.new(0.9, beamY, 0.9), base * CFrame.new(side * postX, beamY / 2, 2.4), WOOD_DARK, { Material = Enum.Material.Wood })
		Build.part(station, "PostFoot", Vector3.new(1.7, 0.8, 1.7), base * CFrame.new(side * postX, 0.4, 2.4), STONE_DARK, { Material = Enum.Material.Slate })
		Build.deco(station, "Brace", Vector3.new(0.5, 3.6, 0.5), base * CFrame.new(side * (postX - 1.1), beamY - 1.4, 2.4) * CFrame.Angles(0, 0, side * math.rad(42)), WOOD_DARK, {
			Material = Enum.Material.Wood,
		})
		Build.deco(station, "BackLeg", Vector3.new(0.6, 6, 0.6), base * CFrame.new(side * postX, 2.6, 4.2) * CFrame.Angles(math.rad(-28), 0, 0), WOOD_DARK, {
			Material = Enum.Material.Wood,
		})
	end
	Build.part(station, "Beam", Vector3.new(postX * 2 + 1.6, 0.9, 1), base * CFrame.new(0, beamY + 0.2, 2.4), WOOD_DARK, { Material = Enum.Material.Wood })
	-- Bras qui avance au-dessus du sac
	Build.part(station, "Arm", Vector3.new(0.7, 0.7, 3.2), base * CFrame.new(0, beamY + 0.2, 0.9), WOOD_DARK, { Material = Enum.Material.Wood })
	-- Petite plaque numérotée sur la poutre
	plank(station, base * CFrame.new(0, beamY + 1.35, 2.4), 2.2, 1.2, tostring(index), { bg = shade(color, -0.2), both = true })

	-- Sac suspendu : modèle à part (pivot = crochet) que les clients font balancer.
	local hookPos = (base * CFrame.new(0, beamY - 0.2, 0)).Position
	local bag = Build.model(station, "Bag")
	local hook = Build.deco(bag, "Hook", Vector3.new(0.5, 0.4, 0.5), CFrame.new(hookPos) * (base - base.Position), METAL, { Material = Enum.Material.Metal })
	bag.PrimaryPart = hook
	local rot = base - base.Position
	local function at(y: number): CFrame
		return CFrame.new(hookPos + Vector3.new(0, y, 0)) * rot
	end
	-- Chaînes (maillons alternés) jusqu'à l'anneau
	for k = 0, 4 do
		local link = Build.deco(bag, "ChainLink", Vector3.new(0.18, 0.55, k % 2 == 0 and 0.42 or 0.18), at(-0.5 - k * 0.42), METAL, {
			Material = Enum.Material.Metal,
			Reflectance = 0.15,
		})
		link.CastShadow = false
	end
	Build.deco(bag, "Ring", Vector3.new(0.25, 1.1, 1.1), at(-2.75) * CFrame.Angles(0, 0, math.rad(90)), METAL, {
		Material = Enum.Material.Metal,
		Shape = Enum.PartType.Cylinder,
	})
	for _, a in { 0, 120, 240 } do
		local strapCF = at(-3.2) * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 0, 0.62) * CFrame.Angles(math.rad(-30), 0, 0)
		Build.deco(bag, "Strap", Vector3.new(0.22, 1.1, 0.12), strapCF, LEATHER_DARK, { Material = Enum.Material.Leather })
	end
	local bagLength = 5.2
	local bagTop = -3.7
	local function vcyl(name: string, y: number, height: number, diameter: number, color3: Color3, material: Enum.Material)
		local part = Build.deco(bag, name, Vector3.new(height, diameter, diameter), at(y) * CFrame.Angles(0, 0, math.rad(90)), color3, {
			Material = material,
			Shape = Enum.PartType.Cylinder,
		})
		return part
	end
	vcyl("TopCap", bagTop - 0.2, 0.45, 2.7, LEATHER_DARK, Enum.Material.Leather)
	local body = vcyl("Body", bagTop - bagLength / 2, bagLength, 2.8, LEATHER, Enum.Material.Leather)
	body.CanQuery = true
	vcyl("Band", bagTop - 0.9, 0.35, 2.86, CREAM, Enum.Material.Leather)
	vcyl("Band", bagTop - bagLength + 0.9, 0.35, 2.86, CREAM, Enum.Material.Leather)
	vcyl("Seam", bagTop - bagLength / 2, bagLength - 0.6, 2.82, shade(LEATHER, -0.12), Enum.Material.Leather).Transparency = 0.6
	vcyl("BottomCap", bagTop - bagLength - 0.15, 0.4, 2.6, LEATHER_DARK, Enum.Material.Leather)
	-- Écusson (cercle crème avec le numéro) devant et derrière
	for _, side in { -1, 1 } do
		local crest = Build.deco(bag, "Crest", Vector3.new(0.06, 1.5, 1.5), at(bagTop - bagLength / 2 + 0.2) * CFrame.new(0, 0, side * 1.41) * CFrame.Angles(0, math.rad(90), 0), CREAM, {
			Material = Enum.Material.SmoothPlastic,
			Shape = Enum.PartType.Cylinder,
		})
		crest.CastShadow = false
	end

	-- Point fixe (ne bouge pas) : invite « Frapper » + compteur au-dessus du sac.
	local anchor = Build.deco(station, "PromptAnchor", Vector3.new(1, 1, 1), at(bagTop - bagLength / 2), color, { Transparency = 1 })
	anchor.CastShadow = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PunchPrompt"
	prompt.ActionText = "Frapper"
	prompt.ObjectText = "Punching-ball n°" .. index
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Parent = anchor
	counterGui(anchor, index, color)
	pcall(function()
		station.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	return station
end

------------------------------------------------------------------------
-- La zone
------------------------------------------------------------------------

function AfkZone.build(world: Instance): Model
	local existing = world:FindFirstChild("AfkZone")
	if existing then
		existing:Destroy()
	end
	local zone = Build.model(world, "AfkZone")
	local center = Layout.AfkZone
	local cf = CFrame.lookAt(center, Vector3.zero) -- -Z vers le hub
	local floorCF = cf + Vector3.new(0, FLOOR_TOP, 0)
	zone:SetAttribute("Center", center)

	-- Dalle, bordure de pierre et plancher de dojo
	Build.disc(zone, "Slab", FLOOR_TOP - 0.2, ZONE_RADIUS * 2 + 4, center + Vector3.new(0, 0.1, 0), STONE_DARK, { Material = Enum.Material.Cobblestone })
	Build.disc(zone, "Border", 0.3, ZONE_RADIUS * 2, center + Vector3.new(0, FLOOR_TOP - 0.3, 0), STONE, { Material = Enum.Material.Slate })
	Build.disc(zone, "Floor", 0.25, ZONE_RADIUS * 2 - 6, center + Vector3.new(0, FLOOR_TOP - 0.2, 0), PLANK, { Material = Enum.Material.WoodPlanks })
	Build.disc(zone, "FloorRing", 0.27, 30, center + Vector3.new(0, FLOOR_TOP - 0.2, 0), shade(PLANK, -0.18), { Material = Enum.Material.WoodPlanks })
	Build.disc(zone, "FloorHeart", 0.29, 26, center + Vector3.new(0, FLOOR_TOP - 0.2, 0), PLANK, { Material = Enum.Material.WoodPlanks })
	-- Emblème peint au centre (cible rouge et blanche)
	for k, info in ipairs({ { 15, rgb(170, 44, 36) }, { 12.6, CREAM }, { 9.6, rgb(170, 44, 36) }, { 6.6, CREAM }, { 3.4, rgb(170, 44, 36) } }) do
		Build.disc(zone, "Emblem", 0.05, info[1], center + Vector3.new(0, 1.0 + k * 0.012, 0), info[2], { Material = Enum.Material.SmoothPlastic }).CastShadow = false
	end
	-- Chemin pavé depuis la promenade jusqu'à l'entrée (pour venir à pied)
	local inward = (Vector3.zero - Vector3.new(center.X, 0, center.Z)).Unit
	local startR = center.Magnitude - ZONE_RADIUS - 4
	local endR = Layout.WalkwayOuter - 2
	local pathLength = startR - endR
	if pathLength > 4 then
		local mid = center.Unit * ((startR + endR) / 2)
		local pathCF = CFrame.lookAt(mid, mid + inward)
		Build.part(zone, "Path", Vector3.new(10, 0.3, pathLength), pathCF + Vector3.new(0, 0.1, 0), rgb(176, 168, 156), { Material = Enum.Material.Cobblestone }).CastShadow = false
		for _, side in { -1, 1 } do
			Build.part(zone, "PathEdge", Vector3.new(0.8, 0.45, pathLength), pathCF * CFrame.new(side * 5.4, 0.12, 0), STONE_DARK, { Material = Enum.Material.Slate }).CastShadow = false
		end
		-- Panneau au bord de la promenade
		local signBase = (pathCF * CFrame.new(7.5, 0, pathLength / 2 - 2)).Position
		local signFace = CFrame.lookAt(signBase, signBase + inward)
		Build.part(zone, "SignPole", Vector3.new(0.6, 7, 0.6), signFace * CFrame.new(0, 3.5, 0), WOOD_DARK, { Material = Enum.Material.Wood })
		plank(zone, signFace * CFrame.new(0, 6.2, -0.4), 6, 1.6, "ZONE ANTI-AFK", { both = true, bg = rgb(70, 46, 30) })
		plank(zone, signFace * CFrame.new(0, 4.6, -0.4), 5, 1, "punching-balls", { both = true, bg = rgb(60, 40, 28), font = Enum.Font.Fantasy, text = rgb(255, 214, 150) })
		for _, side in { -1, 1 } do
			Props.lamppost(zone, (pathCF * CFrame.new(side * 7, 0, -pathLength / 2 + 3)).Position, "bois", rgb(255, 190, 110))
		end
	end
	-- Marches d'entrée (côté hub)
	for k = 0, 1 do
		Build.part(zone, "Step", Vector3.new(16, 0.45, 2.2), cf * CFrame.new(0, 0.22 + k * 0.33, -(ZONE_RADIUS + 3.4 - k * 1.6)), STONE, { Material = Enum.Material.Slate })
	end

	-- Muret de bois ouvert côté hub (et un passage plus petit au fond).
	local hubAngle = math.atan2(-center.Z, -center.X)
	Build.fenceRing(zone, center + Vector3.new(0, FLOOR_TOP - 0.1, 0), ZONE_RADIUS - 1, { hubAngle }, 9, 3.4)

	-- Portique d'entrée et enseigne
	local gateCF = cf * CFrame.new(0, FLOOR_TOP - 0.1, -(ZONE_RADIUS - 1))
	Build.torii(zone, gateCF, 16, 13, rgb(170, 44, 36), rgb(36, 28, 26))
	plank(zone, gateCF * CFrame.new(0, 10.6, -0.9) * CFrame.Angles(0, math.pi, 0), 11, 2.4, "ZONE ANTI-AFK", { both = true, bg = rgb(70, 46, 30) })
	plank(zone, gateCF * CFrame.new(0, 8.1, -0.9) * CFrame.Angles(0, math.pi, 0), 8, 1.2, "Dojo des punching-balls", {
		both = true,
		bg = rgb(60, 40, 28),
		font = Enum.Font.Fantasy,
		text = rgb(255, 214, 150),
	})
	for _, side in { -1, 1 } do
		Props.stoneLantern(zone, (gateCF * CFrame.new(side * 12.5, 0, -3.5)).Position)
		Props.banner(zone, (gateCF * CFrame.new(side * 9.8, 0, -1.5)).Position, 9, side < 0 and rgb(170, 44, 36) or rgb(40, 90, 170), nil, math.atan2(cf.LookVector.X, cf.LookVector.Z))
	end

	-- Les 3 postes en arc de cercle, face à l'entrée
	local stations = Build.folder(zone, "Stations")
	for index, angle in STATION_ANGLES do
		if index > Quests.Punch.Bags then
			break
		end
		local a = math.rad(angle)
		local local_ = Vector3.new(math.sin(a) * STATION_RADIUS, 0, math.cos(a) * STATION_RADIUS)
		local pos = (floorCF * CFrame.new(local_)).Position
		-- le poste regarde le centre de la zone (le joueur tape depuis le centre)
		local look = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
		-- base : -Z vers le centre ; la potence est derrière le sac (+Z)
		buildStation(stations, index, look)
	end

	-- Tableaux : paliers (gauche) et mode d'emploi (droite), tournés vers le centre
	local function board(name: string, angle: number, title: string, lines: string)
		local a = math.rad(angle)
		local pos = (floorCF * CFrame.new(math.sin(a) * 29, 0, math.cos(a) * 29)).Position
		local face = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
		local model = Build.model(zone, name)
		for _, x in { -1, 1 } do
			Build.part(model, "BoardLeg", Vector3.new(0.8, 9.5, 0.8), face * CFrame.new(x * 5.4, 4.75, 0.3), WOOD_DARK, { Material = Enum.Material.Wood })
		end
		plank(model, face * CFrame.new(0, 9.1, 0), 11.6, 1.8, title, { bg = rgb(70, 46, 30) })
		local panel = plank(model, face * CFrame.new(0, 5.2, 0), 11, 5.6, "", { bg = rgb(232, 218, 186), frame = WOOD_DARK })
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Text"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.3
		gui.Parent = panel
		local label = Instance.new("TextLabel")
		label.Name = "Lines"
		label.Size = UDim2.new(1, -40, 1, -30)
		label.Position = UDim2.fromOffset(20, 15)
		label.BackgroundTransparency = 1
		label.Text = lines
		label.TextColor3 = rgb(60, 36, 24)
		label.TextScaled = true
		label.Font = Enum.Font.Fantasy
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.Parent = gui
		-- toit de planches
		Build.deco(model, "BoardRoof", Vector3.new(13.4, 0.4, 2.4), face * CFrame.new(0, 10.4, 0.4) * CFrame.Angles(math.rad(-12), 0, 0), rgb(70, 48, 34), {
			Material = Enum.Material.WoodPlanks,
		})
		return model
	end
	local tierLines = {}
	local cumul = 0
	for _, tier in Quests.Punch.Tiers do
		cumul += tier[2]
		table.insert(tierLines, string.format("%d coups  →  +%d gemmes", tier[1], tier[2]))
	end
	table.insert(tierLines, string.format("Total : %d relances de trait", cumul))
	board("TiersBoard", -100, "PALIERS (pour 1000 coups)", table.concat(tierLines, "\n"))
	board(
		"HowToBoard",
		100,
		"COMMENT ÇA MARCHE",
		"1. Prends un punching-ball libre.\n2. Sors ton épée et tape-le\n    (ou l'invite « Frapper »).\n3. 1000 coups = 20 gemmes de trait.\nLes sacs ne t'attaquent jamais !"
	)

	-- Décor paisible : lanternes suspendues, bancs, plantes
	local deco = Build.folder(zone, "Deco")
	for _, angle in { -150, 150 } do
		local a = math.rad(angle)
		local pos = (floorCF * CFrame.new(math.sin(a) * 30, 0, math.cos(a) * 30)).Position
		local face = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
		Props.bench(deco, face * CFrame.Angles(0, math.pi, 0))
	end
	local plantRng = Random.new(1802)
	for _, angle in { -70, 70 } do
		local a = math.rad(angle)
		Props.pottedPlant(deco, (floorCF * CFrame.new(math.sin(a) * 32, 0, math.cos(a) * 32)).Position, plantRng)
	end
	for _, angle in { -20, 20 } do
		local a = math.rad(angle)
		local pos = (floorCF * CFrame.new(math.sin(a) * 31.5, 0, math.cos(a) * 31.5)).Position
		Build.part(deco, "LanternPole", Vector3.new(0.6, 9, 0.6), CFrame.new(pos + Vector3.new(0, 4.5, 0)), WOOD_DARK, { Material = Enum.Material.Wood })
		Props.hangingLantern(deco, pos + Vector3.new(0, 8.6, 0), (Vector3.new(center.X, pos.Y, center.Z) - pos).Unit * 2, rgb(255, 170, 90), 1)
	end

	-- Balise visible de loin : grand mât, drapeau et étiquette.
	local mastBase = (floorCF * CFrame.new(0, 0, ZONE_RADIUS - 3)).Position
	Build.part(zone, "MastFoot", Vector3.new(2.6, 1, 2.6), CFrame.new(mastBase + Vector3.new(0, 0.5, 0)), STONE_DARK, { Material = Enum.Material.Slate })
	local mast = Core.vcyl(zone, "Mast", CFrame.new(mastBase), 30, 0.7, WOOD_DARK, Enum.Material.Wood)
	mast.Name = "Mast"
	local flagCF = CFrame.new(mastBase + Vector3.new(0, 27.2, 0)) * (cf - cf.Position) * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(3.7, 0, 0)
	local flag = Build.deco(zone, "Flag", Vector3.new(7, 4.2, 0.12), flagCF, rgb(40, 150, 230), { Material = Enum.Material.Fabric })
	Build.surfaceText(flag, Enum.NormalId.Front, "AFK", CREAM, { Font = Enum.Font.Bangers, TextStrokeTransparency = 0.6 })
	Build.surfaceText(flag, Enum.NormalId.Back, "AFK", CREAM, { Font = Enum.Font.Bangers, TextStrokeTransparency = 0.6 })
	local top = Build.deco(zone, "MastTop", Vector3.new(1.2, 1.2, 1.2), CFrame.new(mastBase + Vector3.new(0, 30.4, 0)), rgb(255, 210, 90), {
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Ball,
	})
	Core.light(top, rgb(120, 220, 255), 30, 1.4)
	local beacon = Build.billboard(top, UDim2.fromOffset(300, 64), Vector3.new(0, 4, 0), 900)
	beacon.Name = "Beacon"
	local beaconCard = Instance.new("Frame")
	beaconCard.Size = UDim2.fromScale(1, 1)
	beaconCard.BackgroundColor3 = rgb(16, 16, 24)
	beaconCard.BackgroundTransparency = 0.2
	beaconCard.Parent = beacon
	local beaconCorner = Instance.new("UICorner")
	beaconCorner.CornerRadius = UDim.new(0, 12)
	beaconCorner.Parent = beaconCard
	local beaconStroke = Instance.new("UIStroke")
	beaconStroke.Color = rgb(80, 220, 255)
	beaconStroke.Thickness = 3
	beaconStroke.Parent = beaconCard
	local beaconTitle = Build.label(beaconCard, "ZONE ANTI-AFK", UDim2.new(1, -16, 0.58, 0), UDim2.fromOffset(8, 4), rgb(255, 255, 255), Enum.Font.GothamBlack)
	beaconTitle.Name = "Title"
	local beaconSub = Build.label(beaconCard, "1000 coups = 20 relances de trait", UDim2.new(1, -16, 0.36, 0), UDim2.new(0, 8, 0.6, 0), rgb(130, 230, 255), Enum.Font.GothamBold)
	beaconSub.Name = "Subtitle"

	pcall(function()
		zone.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	return zone
end

-- Construit la zone si elle manque (carte pré-construite plus ancienne) ; sinon la garde.
function AfkZone.ensure(world: Instance): Model
	local existing = world:FindFirstChild("AfkZone")
	if existing and existing:IsA("Model") and existing:FindFirstChild("Stations") then
		return existing
	end
	return AfkZone.build(world)
end

-- Les postes (modèles "StationN") de la zone, dans l'ordre.
function AfkZone.stations(world: Instance): { Model }
	local list = {}
	local zone = world:FindFirstChild("AfkZone")
	local folder = zone and zone:FindFirstChild("Stations")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("Station") then
				table.insert(list, child)
			end
		end
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute("Station") or 0) < (b:GetAttribute("Station") or 0)
	end)
	return list
end

return AfkZone
