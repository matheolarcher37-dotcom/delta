-- Décor de l'univers ÈRE DES POURFENDEURS (inspiré de Demon Slayer), sur TOUTE la carte, de nuit
-- sous une grande lune :
--   * dans l'anneau, une ville de l'ère Taishō : maisons de marchands à étage (machiya) aux
--     façades à claire-voie allumées, rideaux noren, enseignes verticales, auvents de tuiles,
--     balcons, lampadaires à gaz, poteaux et câbles électriques, guirlandes de lanternes rouges ;
--   * le Domaine des Papillons : enceinte blanche à chaperon de tuiles, pavillon à véranda, jardin
--     avec étang, lanternes de pierre, glycine et papillons lumineux ;
--   * un tunnel de treilles de glycine (fujidana) sur la route de la base 150°, des arches de
--     glycine sur les autres routes (la glycine repousse les démons) et la grande porte des
--     Pourfendeurs sur la route 270° ;
--   * le terrain d'entraînement : le rocher fendu en deux, corde sacrée, mannequins ;
--   * des lys araignées rouges (higanbana) un peu partout, des bosquets de bambous ;
--   * sur l'île : forêt de bambous, cèdres et glycines, la forêt aux toiles d'araignée, petits
--     sanctuaires de renards ;
--   * au bord de l'île : le mont Fujikasane, couvert de glycines en fleur toute l'année ;
--   * à l'horizon : montagnes bleu nuit et le Train de l'Infini sur son viaduc de pierre.
--   Pétales de glycine qui tombent, lucioles et brume basse.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Build = require(script.Parent.Parent.Parent.Modules.Build)
local Core = require(script.Parent.Parent.Kit.Core)
local Nature = require(script.Parent.Parent.Kit.Nature)
local Archi = require(script.Parent.Parent.Kit.Archi)
local Props = require(script.Parent.Parent.Kit.Props)
local Relief = require(script.Parent.Parent.Kit.Relief)
local Common = require(script.Parent.Common)

local Pourfendeur = {}

local rgb = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local shade = Core.shade
local polar = Common.polar
local facing = Common.facing

local DARK_WOOD = rgb(52, 38, 32)
local WOOD = rgb(110, 78, 56)
local PLASTER = rgb(222, 214, 196)
local PLASTER_DARK = rgb(150, 132, 112)
local ROOF = rgb(54, 58, 70)
local ROOF_RIDGE = rgb(40, 42, 52)
local STONE = rgb(110, 108, 118)
local WISTERIA = { rgb(120, 86, 186), rgb(156, 120, 220), rgb(192, 160, 242), rgb(226, 204, 255) }
local LANTERN_RED = rgb(255, 90, 60)
local WARM = rgb(255, 196, 120)
local LILY_RED = rgb(210, 24, 34)

local TOP_RING = Common.TOP_RING

local function atomic(model: Model)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
end

------------------------------------------------------------------------
-- Petits éléments
------------------------------------------------------------------------

-- Grappe de glycine qui pend (3 boules de plus en plus petites, du violet profond au lilas).
local function raceme(parent: Instance, top: Vector3, length: number, rng: Random)
	local n = 3
	for i = 1, n do
		local k = (i - 1) / (n - 1)
		local d = length * (0.42 - k * 0.2)
		local color = WISTERIA[math.clamp(i + rng:NextInteger(0, 1), 1, #WISTERIA)]
		local ball = Core.ball(parent, "Raceme", d, top - UP * length * (0.18 + k * 0.62), color, i == n and Enum.Material.Neon or Enum.Material.SmoothPlastic, false)
		if i == n then
			ball.Transparency = 0.25
		end
	end
end

-- Lys araignée rouge (higanbana) : tige, 6 pétales fins recourbés, cœur.
local function spiderLily(parent: Instance, base: Vector3, rng: Random, color: Color3?)
	local h = rng:NextNumber(1.4, 2.1)
	local c = color or LILY_RED
	Core.vcyl(parent, "LilyStem", CFrame.new(base), h, 0.12, rgb(70, 100, 52), Enum.Material.SmoothPlastic, false)
	local head = base + UP * h
	local turn = rng:NextNumber(0, math.pi)
	for k = 0, 5 do
		local cf = CFrame.new(head) * CFrame.Angles(0, turn + k * math.pi / 3, 0) * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, 0, -0.42)
		Build.deco(parent, "LilyPetal", Vector3.new(0.14, 0.06, 0.9), cf, c, { CastShadow = false })
	end
	Core.ball(parent, "LilyHeart", 0.34, head + UP * 0.12, shade(c, 0.15), Enum.Material.Neon, false)
end

-- Touffe de 3 à 5 lys araignées.
local function lilyClump(parent: Instance, base: Vector3, rng: Random, color: Color3?)
	for _ = 1, rng:NextInteger(3, 5) do
		spiderLily(parent, base + Vector3.new(rng:NextNumber(-1.4, 1.4), 0, rng:NextNumber(-1.4, 1.4)), rng, color)
	end
end

-- Mur d'enceinte enduit de blanc, soubassement de pierre, chaperon de tuiles à deux pentes.
local function estateWall(parent: Instance, a: Vector3, b: Vector3, h: number)
	local delta = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, mid + delta) * CFrame.Angles(0, math.pi / 2, 0) -- longueur selon X
	Archi.block(parent, "WallBase", Vector3.new(length, 1.6, 1.8), cf, STONE, Enum.Material.Cobblestone)
	Archi.block(parent, "Wall", Vector3.new(length, h - 1.6, 1.3), cf * CFrame.new(0, 1.6, 0), PLASTER, Enum.Material.Plaster)
	Build.deco(parent, "WallBand", Vector3.new(length, 0.3, 1.4), cf * CFrame.new(0, h - 1, 0), DARK_WOOD, { Material = Enum.Material.Wood })
	for _, side in { -1, 1 } do
		Build.part(parent, "WallCap", Vector3.new(length + 0.6, 0.35, 1.6), cf * CFrame.new(0, h + 0.3, side * 0.6) * CFrame.Angles(side * math.rad(24), 0, 0), ROOF, {
			Material = Enum.Material.Slate,
		})
	end
	Core.beam(parent, "WallRidge", (cf * CFrame.new(-length / 2 - 0.3, h + 0.75, 0)).Position, (cf * CFrame.new(length / 2 + 0.3, h + 0.75, 0)).Position, 0.6, 0.5, ROOF_RIDGE, {
		Material = Enum.Material.Slate,
	})
end

-- Petit sanctuaire de bord de chemin (hokora) gardé par deux renards blancs à bavoir rouge.
local function hokora(parent: Instance, cf: CFrame)
	local model = Core.slot(parent, "Hokora", cf, 7)
	Archi.plinth(model, cf, 4.6, 4, 1.2, STONE, Enum.Material.Cobblestone)
	local base = cf * CFrame.new(0, 1.2, 0.4)
	Archi.walls(model, base, 2.6, 2.4, 2.4, WOOD, { frame = DARK_WOOD, spacing = 1.3 })
	Build.deco(model, "HokoraDoor", Vector3.new(1.4, 1.8, 0.1), base * CFrame.new(0, 1, -1.25), rgb(240, 220, 170), { Material = Enum.Material.Neon, Transparency = 0.25 })
	Archi.gableRoof(model, base * CFrame.new(0, 2.4, 0), 2.6, 2.4, 1.4, 0.8, ROOF, { trim = DARK_WOOD, upturn = true })
	for _, side in { -1, 1 } do
		local f = cf * CFrame.new(side * 1.9, 1.2, -1.4)
		Archi.block(model, "FoxBase", Vector3.new(0.9, 0.5, 0.9), f, shade(STONE, 0.1), Enum.Material.Slate)
		Core.ellipsoid(model, "Fox", Vector3.new(0.8, 1.4, 0.8), f * CFrame.new(0, 1.2, 0), rgb(236, 232, 224))
		Core.ball(model, "FoxHead", 0.7, (f * CFrame.new(0, 2.1, -0.1)).Position, rgb(236, 232, 224))
		for _, e in { -1, 1 } do
			Build.wedge(model, "FoxEar", Vector3.new(0.12, 0.4, 0.25), f * CFrame.new(e * 0.2, 2.5, -0.05), rgb(236, 232, 224), { CanCollide = false })
		end
		Build.deco(model, "FoxBib", Vector3.new(0.7, 0.4, 0.08), f * CFrame.new(0, 1.65, -0.38) * CFrame.Angles(0.2, 0, 0), rgb(200, 30, 36), { Material = Enum.Material.Fabric })
	end
	local candle = Core.ball(model, "Offering", 0.4, (cf * CFrame.new(0, 1.5, -1.6)).Position, WARM, Enum.Material.Neon, false)
	Core.light(candle, WARM, 8, 0.8)
	return model
end

-- Toile d'araignée verticale (rayons et spirale) de rayon `r`, centre `cf` (-Z = face).
local function spiderWeb(parent: Instance, cf: CFrame, r: number)
	local color = rgb(232, 236, 244)
	local props = { Transparency = 0.35, CastShadow = false, Material = Enum.Material.SmoothPlastic }
	local spokes = 8
	for k = 0, spokes - 1 do
		local a = k / spokes * math.pi * 2
		local tip = cf * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0)
		Build.deco(parent, "WebSpoke", Vector3.new(0.06, 0.06, r), CFrame.lookAt(cf:Lerp(tip, 0.5).Position, tip.Position), color, props)
	end
	for ring = 1, 3 do
		local rr = r * ring / 3.4
		for k = 0, spokes - 1 do
			local a0 = k / spokes * math.pi * 2
			local a1 = (k + 1) / spokes * math.pi * 2
			local p0 = (cf * CFrame.new(math.cos(a0) * rr, math.sin(a0) * rr, 0)).Position
			local p1 = (cf * CFrame.new(math.cos(a1) * rr, math.sin(a1) * rr, 0)).Position
			Build.deco(parent, "WebThread", Vector3.new(0.05, 0.05, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), color, props)
		end
	end
end

------------------------------------------------------------------------
-- Bâtiments
------------------------------------------------------------------------

local NOREN = { rgb(40, 60, 110), rgb(120, 30, 36), rgb(60, 90, 70), rgb(70, 50, 100), rgb(40, 40, 46) }
local SIGNS = { "藤", "茶", "宿", "米", "酒", "団子", "呉服", "薬" }

-- Maison de marchand à étage (machiya) : façade à claire-voie allumée au rez-de-chaussée, porte
-- coulissante et noren, auvent de tuiles, étage à fenêtres de papier, toit de tuiles à deux pans.
local function machiya(parent: Instance, cf: CFrame, w: number, rng: Random): Model
	local d = rng:NextNumber(11, 13)
	local h1, h2 = 9, rng:NextNumber(6, 7.2)
	local model = Core.slot(parent, "Machiya", cf, h1 + h2 + 5)
	atomic(model)
	Archi.plinth(model, cf, w + 1, d + 1, 0.6, STONE, Enum.Material.Slate)
	local base = cf * CFrame.new(0, 0.6, 0)
	local wall = rng:NextNumber() < 0.5 and PLASTER_DARK or shade(PLASTER, -0.08)
	Archi.walls(model, base, w, d, h1, wall, { frame = DARK_WOOD, spacing = 4, base = DARK_WOOD, baseHeight = 1.2 })
	-- façade : porte d'un côté, claire-voie (koshi) devant une pièce allumée de l'autre
	local doorX = (rng:NextNumber() < 0.5 and -1 or 1) * (w / 2 - 3)
	Archi.door(model, base * CFrame.new(doorX, 0, -d / 2 - 0.05), 4.2, 7.2, {
		sliding = true,
		color = DARK_WOOD,
		noren = NOREN[rng:NextInteger(1, #NOREN)],
		norenText = rng:NextNumber() < 0.6 and SIGNS[rng:NextInteger(1, #SIGNS)] or nil,
		step = false,
	})
	local x0 = doorX < 0 and doorX + 3 or -w / 2 + 0.8
	local x1 = doorX < 0 and w / 2 - 0.8 or doorX - 3
	local span = x1 - x0
	if span > 2 then
		local mid = (x0 + x1) / 2
		local glow = Build.deco(
			model,
			"KoshiGlow",
			Vector3.new(span, 4.6, 0.1),
			base * CFrame.new(mid, 4, -d / 2 - 0.08),
			rgb(255, 196, 120),
			{ Material = Enum.Material.Neon, Transparency = 0.15 }
		)
		if rng:NextNumber() < 0.5 then
			Core.light(glow, WARM, 12, 0.8)
		end
		Build.deco(model, "KoshiRail", Vector3.new(span, 0.3, 0.3), base * CFrame.new(mid, 1.6, -d / 2 - 0.3), DARK_WOOD, { Material = Enum.Material.Wood })
		Build.deco(model, "KoshiRail", Vector3.new(span, 0.3, 0.3), base * CFrame.new(mid, 6.4, -d / 2 - 0.3), DARK_WOOD, { Material = Enum.Material.Wood })
		local slats = math.floor(span / 0.7)
		for i = 0, slats do
			Build.deco(
				model,
				"KoshiSlat",
				Vector3.new(0.2, 4.8, 0.2),
				base * CFrame.new(x0 + i * span / slats, 4, -d / 2 - 0.3),
				DARK_WOOD,
				{ Material = Enum.Material.Wood, CastShadow = false }
			)
		end
	end
	-- auvent de tuiles entre les deux niveaux, sur consoles
	Build.part(
		model,
		"Hisashi",
		Vector3.new(w + 1.2, 0.4, 3.4),
		base * CFrame.new(0, h1 + 0.1, -d / 2 - 1.3) * CFrame.Angles(math.rad(-16), 0, 0),
		ROOF,
		{ Material = Enum.Material.Slate }
	)
	Build.deco(model, "HisashiTrim", Vector3.new(w + 1.3, 0.35, 0.3), base * CFrame.new(0, h1 - 0.45, -d / 2 - 2.9), DARK_WOOD, { Material = Enum.Material.Wood })
	for _, x in { -w / 2 + 0.6, 0, w / 2 - 0.6 } do
		Build.wedge(
			model,
			"Bracket",
			Vector3.new(0.4, 1.2, 1.4),
			base * CFrame.new(x, h1 - 0.9, -d / 2 - 0.7) * CFrame.Angles(0, math.pi, math.pi),
			DARK_WOOD,
			{ CanCollide = false }
		)
	end
	-- étage
	local up = base * CFrame.new(0, h1, 0)
	Archi.walls(model, up, w, d, h2, PLASTER, { frame = DARK_WOOD, spacing = w / 3 })
	Archi.windowRow(model, up * CFrame.new(0, h2 * 0.55, -d / 2 - 0.05), w, w > 13 and 3 or 2, 2.8, 2.2, { shoji = true, frame = DARK_WOOD, lit = rng:NextNumber() < 0.8 })
	if rng:NextNumber() < 0.35 then
		Archi.balcony(model, up * CFrame.new(0, 0.4, -d / 2), w - 2, 1.8, DARK_WOOD)
	end
	-- toit
	Archi.gableRoof(model, up * CFrame.new(0, h2, 0), w, d, 4.4, 2, ROOF, { rafters = DARK_WOOD, trim = DARK_WOOD, ridge = ROOF_RIDGE, gableFill = PLASTER })
	-- enseigne verticale et lanterne
	local side = doorX < 0 and 1 or -1
	if rng:NextNumber() < 0.7 then
		Archi.verticalSign(model, base * CFrame.new(side * (w / 2 - 0.8), h1 + h2 * 0.5, -d / 2 - 0.4), 4.4, SIGNS[rng:NextInteger(1, #SIGNS)], rgb(36, 30, 28), rgb(236, 210, 150))
	end
	Props.hangingLantern(
		model,
		(base * CFrame.new(doorX + 2.6, 7.6, -d / 2)).Position,
		(base - base.Position) * Vector3.new(0, 0, -1.4),
		rng:NextNumber() < 0.7 and LANTERN_RED or WARM,
		0.8
	)
	-- accessoires devant
	if rng:NextNumber() < 0.6 then
		Props.barrel(model, base * CFrame.new(-side * (w / 2 - 1), 0, -d / 2 - 1.4), 0.8, WOOD)
	end
	if rng:NextNumber() < 0.5 then
		Props.pottedPlant(model, (base * CFrame.new(doorX - 2.8 * side, 0, -d / 2 - 1)).Position, rng)
	end
	return model
end

-- Pavillon japonais à véranda (engawa) et toit irimoya (croupe + pignon), pour le domaine.
local function pavilion(parent: Instance, cf: CFrame, w: number, d: number, h: number, slotName: string, rng: Random): Model
	local model = Core.slot(parent, slotName, cf, h + 12)
	atomic(model)
	local plinthH = 1.8
	Archi.plinth(model, cf, w + 7, d + 7, plinthH, STONE, Enum.Material.Cobblestone)
	Archi.stairs(model, cf * CFrame.new(0, 0, -d / 2 - 5), 8, plinthH, 3, 3, shade(STONE, 0.08))
	local base = cf * CFrame.new(0, plinthH, 0)
	Build.part(model, "Engawa", Vector3.new(w + 5, 0.5, d + 5), base * CFrame.new(0, 0.25, 0), WOOD, { Material = Enum.Material.WoodPlanks })
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			Archi.block(model, "VerandaPost", Vector3.new(0.6, h, 0.6), base * CFrame.new(x * (w / 2 + 2.2), 0.5, z * (d / 2 + 2.2)), DARK_WOOD, Enum.Material.Wood, false)
		end
	end
	local body = base * CFrame.new(0, 0.5, 0)
	Archi.walls(model, body, w, d, h, PLASTER, { frame = DARK_WOOD, spacing = 4.5, base = DARK_WOOD, baseHeight = 1.2 })
	Archi.windowRow(
		model,
		body * CFrame.new(0, h * 0.48, -d / 2 - 0.05),
		w,
		math.max(2, math.floor(w / 5)),
		3,
		h * 0.62,
		{ shoji = true, frame = DARK_WOOD, lit = true },
		function(x)
			return math.abs(x) < 3.5
		end
	)
	Archi.door(model, body * CFrame.new(0, 0, -d / 2 - 0.05), 5, h - 1.4, { sliding = true, color = DARK_WOOD, step = false })
	for _, side in { -1, 1 } do
		Archi.windowRow(model, body * CFrame.new(side * (w / 2 + 0.05), h * 0.48, 0) * CFrame.Angles(0, side * math.pi / 2, 0), d, math.max(1, math.floor(d / 5)), 3, h * 0.62, {
			shoji = true,
			frame = DARK_WOOD,
			lit = rng:NextNumber() < 0.7,
		})
	end
	Archi.hipRoof(model, body * CFrame.new(0, h, 0), w + 3, d + 3, h * 0.42, 2.6, ROOF, { rafters = DARK_WOOD, trim = DARK_WOOD })
	Archi.gableRoof(
		model,
		body * CFrame.new(0, h + h * 0.34, 0),
		w * 0.62,
		d * 0.5,
		h * 0.38,
		1.8,
		ROOF,
		{ trim = DARK_WOOD, upturn = true, ridge = ROOF_RIDGE, gableFill = DARK_WOOD }
	)
	for _, x in { -w / 2 - 1.4, w / 2 + 1.4 } do
		Props.paperLantern(model, (body * CFrame.new(x, h - 1.8, -d / 2 - 2.2)).Position, rgb(255, 230, 190), 0.9)
	end
	return model
end

-- Le Domaine des Papillons : enceinte, portail, pavillon, jardin et étang, papillons lumineux.
local function butterflyEstate(parent: Instance, cf: CFrame, rng: Random): Model
	local model = Build.model(parent, "DomaineDesPapillons")
	local W, D = 64, 36
	local function at(x: number, z: number): Vector3
		return (cf * CFrame.new(x, 0, z)).Position
	end
	-- enceinte (portail au milieu de la façade)
	estateWall(model, at(-W / 2, -D / 2), at(-6, -D / 2), 6)
	estateWall(model, at(6, -D / 2), at(W / 2, -D / 2), 6)
	estateWall(model, at(-W / 2, -D / 2), at(-W / 2, D / 2), 6)
	estateWall(model, at(W / 2, -D / 2), at(W / 2, D / 2), 6)
	estateWall(model, at(-W / 2, D / 2), at(W / 2, D / 2), 6)
	-- portail couvert
	local gate = cf * CFrame.new(0, 0, -D / 2)
	for _, x in { -5.4, 5.4 } do
		Archi.block(model, "GatePost", Vector3.new(1.4, 9, 1.4), gate * CFrame.new(x, 0, 0), DARK_WOOD, Enum.Material.Wood)
	end
	Build.part(model, "GateBeam", Vector3.new(13, 1, 1.4), gate * CFrame.new(0, 8.4, 0), DARK_WOOD, { Material = Enum.Material.Wood })
	Archi.gableRoof(model, gate * CFrame.new(0, 9, 0), 12, 3, 2.4, 1.6, ROOF, { trim = DARK_WOOD, upturn = true, ridge = ROOF_RIDGE, rafters = DARK_WOOD })
	Archi.sign(model, gate * CFrame.new(0, 7, -0.9), 5.6, 1.6, "蝶屋敷", { bg = rgb(40, 30, 28), text = rgb(236, 210, 150) })
	for _, x in { -7.4, 7.4 } do
		Props.paperLantern(model, (gate * CFrame.new(x, 6.4, -1.4)).Position, rgb(255, 160, 210), 0.9)
	end
	-- dalles du portail au pavillon
	local slabs = Build.folder(model, "Allee")
	for z = -D / 2 + 1.5, 4, 2.4 do
		local stone =
			Core.flatDisc(slabs, "Slab", at(rng:NextNumber(-0.4, 0.4), z), rng:NextNumber(2, 2.5), TOP_RING + 0.08, shade(STONE, rng:NextNumber(-0.1, 0.08)), Enum.Material.Slate)
		Core.solRole(stone, "dalle", rng:NextNumber(-0.08, 0.06))
	end
	-- gravier ratissé
	local gravel = Build.part(
		model,
		"Gravel",
		Vector3.new(W - 3, 0.2, D - 3),
		cf * CFrame.new(0, TOP_RING + 0.02, 0),
		rgb(196, 190, 178),
		{ Material = Enum.Material.Pebble, CastShadow = false }
	)
	Core.solRole(gravel, "dalle", 0.12)
	-- pavillon principal et annexe
	pavilion(model, cf * CFrame.new(0, 0, 8), 26, 12, 8, "PavillonPapillons", rng)
	pavilion(model, cf * CFrame.new(-22, 0, 7) * CFrame.Angles(0, math.rad(90), 0), 14, 9, 7, "Annexe", rng)
	-- jardin : étang, lanternes, glycine, buissons taillés
	local pondAt = at(19, -6)
	Relief.pond(model, pondAt, 6, { rng = rng, lilies = true, reeds = false, color = rgb(40, 60, 100) })
	Relief.steppingStones(model, at(10, -14), at(26, -12), TOP_RING + 0.1, rng)
	Props.stoneLantern(model, at(12, -2), 0.9, rgb(255, 200, 230))
	Props.stoneLantern(model, at(27, -1), 0.8, rgb(255, 200, 230))
	Nature.tree("Glycine", model, at(26, 6), { rng = rng, height = 16, detail = "hero" })
	Nature.tree("Glycine", model, at(-26, -11), { rng = rng, height = 14, detail = "normal" })
	for _, p in { at(-12, -12), at(-16, -14), at(12, -15), at(-8, -6) } do
		Nature.bush(model, p, { rng = rng, height = rng:NextNumber(2.6, 3.4), palette = "nuit", flowers = rng:NextNumber() < 0.5 and rgb(240, 160, 210) or nil })
	end
	-- linge (draps blancs) et lits de malades sur la véranda : petite touche du domaine
	Archi.laundry(model, at(-28, 12) + UP * 7, at(-16, 14) + UP * 7, rng)
	-- papillons lumineux
	local flutter = Build.deco(model, "Papillons", Vector3.new(W - 6, 1, D - 6), cf * CFrame.new(0, 4, 0), Color3.new(1, 1, 1), { Transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Papillons"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(rgb(200, 140, 255), rgb(255, 170, 220))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.4) })
	emitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.1), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(4, 7)
	emitter.Rate = 10
	emitter.Speed = NumberRange.new(0.6, 1.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.RotSpeed = NumberRange.new(-120, 120)
	emitter.Parent = flutter
	return model
end

-- Treille de glycine (fujidana) au-dessus de la route : poteaux de part et d'autre, poutres,
-- lattis et grappes qui pendent. `cf` = milieu de la route, -Z dans le sens de la route.
local function trellis(parent: Instance, cf: CFrame, width: number, length: number, rng: Random)
	local half = width / 2 + 1.2
	for _, z in { -length / 2, length / 2 } do
		for _, side in { -1, 1 } do
			Archi.block(parent, "TrellisPost", Vector3.new(0.8, 10, 0.8), cf * CFrame.new(side * half, 0, z), WOOD, Enum.Material.Wood)
		end
		Build.part(parent, "TrellisBeam", Vector3.new(width + 4.4, 0.7, 0.7), cf * CFrame.new(0, 10.2, z), DARK_WOOD, { Material = Enum.Material.Wood })
	end
	for i = 0, 4 do
		local x = -half + i * (half * 2) / 4
		Build.deco(parent, "TrellisLath", Vector3.new(0.35, 0.35, length + 1.2), cf * CFrame.new(x, 10.7, 0), DARK_WOOD, { Material = Enum.Material.Wood })
	end
	-- feuillage sur le dessus
	for _ = 1, 4 do
		local p = cf * CFrame.new(rng:NextNumber(-half, half), 11.2, rng:NextNumber(-length / 2, length / 2))
		Core.ellipsoid(
			parent,
			"TrellisLeaves",
			Vector3.new(rng:NextNumber(4, 6), 1.4, rng:NextNumber(3, 5)),
			p,
			shade(rgb(64, 96, 58), rng:NextNumber(-0.1, 0.06)),
			Enum.Material.Grass
		)
	end
	for _ = 1, 9 do
		local p = (cf * CFrame.new(rng:NextNumber(-half, half), 10.5, rng:NextNumber(-length / 2, length / 2))).Position
		raceme(parent, p, rng:NextNumber(2.4, 3.6), rng)
	end
end

-- Arche de glycine au-dessus d'une route (poteaux, arc de 5 segments, grappes).
local function wisteriaArch(parent: Instance, cf: CFrame, width: number, rng: Random)
	local half = width / 2 + 1
	local points = {}
	for i = 0, 6 do
		local t = i / 6
		local x = -half + t * half * 2
		local y = 11 + math.sin(t * math.pi) * 3.4
		table.insert(points, (cf * CFrame.new(x, y, 0)).Position)
	end
	for _, side in { -1, 1 } do
		Archi.block(parent, "ArchPost", Vector3.new(1, 11, 1), cf * CFrame.new(side * half, 0, 0), DARK_WOOD, Enum.Material.Wood)
		Props.paperLantern(parent, (cf * CFrame.new(side * (half - 1.4), 8.6, 0)).Position, rgb(220, 180, 255), 0.8)
	end
	for i = 1, #points - 1 do
		Core.cylinder(parent, "ArchBeam", points[i], points[i + 1], 0.8, DARK_WOOD, { Material = Enum.Material.Wood, CanCollide = false })
		Core.ellipsoid(
			parent,
			"ArchLeaves",
			Vector3.new(4, 1.8, 2.4),
			CFrame.lookAt((points[i] + points[i + 1]) / 2 + UP * 0.6, points[i + 1]) * CFrame.Angles(0, math.pi / 2, 0),
			shade(rgb(64, 96, 58), rng:NextNumber(-0.1, 0.06)),
			Enum.Material.Grass
		)
		raceme(parent, (points[i] + points[i + 1]) / 2, rng:NextNumber(2.2, 3.4), rng)
	end
end

-- Grande porte des Pourfendeurs (porte à toit de tuiles, battants ouverts, murs latéraux).
local function slayerGate(parent: Instance, cf: CFrame, rng: Random): Model
	local model = Core.slot(parent, "PortePourfendeurs", cf, 24)
	atomic(model)
	local w = Layout.PathWidth + 6
	Archi.plinth(model, cf, w + 4, 10, 0.8, STONE, Enum.Material.Cobblestone)
	for _, side in { -1, 1 } do
		-- poteaux principaux et secondaires (kōraimon)
		Archi.block(model, "MainPost", Vector3.new(2, 15, 2), cf * CFrame.new(side * w / 2, 0.8, 0), DARK_WOOD, Enum.Material.Wood)
		Archi.block(model, "BackPost", Vector3.new(1.2, 9, 1.2), cf * CFrame.new(side * w / 2, 0.8, 4), DARK_WOOD, Enum.Material.Wood)
		Build.deco(model, "Brace", Vector3.new(0.8, 0.8, 4), cf * CFrame.new(side * w / 2, 8.6, 2), DARK_WOOD, { Material = Enum.Material.Wood })
		Archi.gableRoof(model, cf * CFrame.new(side * w / 2, 9.8, 4), 3, 3, 1.2, 0.8, ROOF, { trim = DARK_WOOD })
		-- battants ouverts, ferrures noires
		local leaf =
			Build.part(model, "Door", Vector3.new(0.6, 12, w / 2 - 1), cf * CFrame.new(side * (w / 2 - 1.2), 7.2, w / 4 + 0.2), WOOD, { Material = Enum.Material.WoodPlanks })
		for _, y in { -4, 0, 4 } do
			Build.deco(model, "DoorIron", Vector3.new(0.7, 0.4, w / 2 - 1), leaf.CFrame * CFrame.new(0, y, 0), rgb(30, 30, 34), { Material = Enum.Material.Metal })
		end
		-- murs latéraux à chaperon
		estateWall(model, (cf * CFrame.new(side * (w / 2 + 1), 0, 0)).Position, (cf * CFrame.new(side * (w / 2 + 16), 0, 0)).Position, 7)
		-- grandes bannières verticales
		Props.banner(model, (cf * CFrame.new(side * (w / 2 + 4), 0, -2.4)).Position, 13, side < 0 and rgb(30, 30, 36) or rgb(120, 30, 40), side < 0 and "滅" or "鬼", 0)
	end
	Build.part(model, "Kabuki", Vector3.new(w + 3, 1.6, 1.8), cf * CFrame.new(0, 14.6, 0), DARK_WOOD, { Material = Enum.Material.Wood })
	Archi.gableRoof(model, cf * CFrame.new(0, 15.6, 0), w + 2, 4, 3.4, 2.2, ROOF, { rafters = DARK_WOOD, trim = DARK_WOOD, upturn = true, ridge = ROOF_RIDGE })
	Archi.sign(model, cf * CFrame.new(0, 12.4, -1.2), 9, 2.4, "鬼殺隊", { bg = rgb(30, 26, 26), text = rgb(236, 210, 150) })
	for _, side in { -1, 1 } do
		Props.hangingLantern(model, (cf * CFrame.new(side * (w / 2 - 1.5), 13.6, -1)).Position, (cf - cf.Position) * Vector3.new(0, 0, -1.2), LANTERN_RED, 1.1)
		Nature.tree("Glycine", model, (cf * CFrame.new(side * (w / 2 + 20), 0, -3)).Position, { rng = rng, height = 15, detail = "normal" })
	end
	return model
end

-- Le rocher fendu (terrain d'entraînement) : deux moitiés écartées à face plane, corde sacrée.
local function splitBoulder(parent: Instance, cf: CFrame): Model
	local model = Core.slot(parent, "RocherFendu", cf, 13)
	atomic(model)
	local rock = rgb(118, 116, 124)
	for _, side in { -1, 1 } do
		local half = cf * CFrame.new(side * 0.7, 0, 0) * CFrame.Angles(0, 0, side * math.rad(-5))
		-- cylindre couché selon X : sa face plane (la coupe) est tournée vers l'autre moitié
		Build.part(model, "CutFace", Vector3.new(4.6, 12, 12), half * CFrame.new(side * 2.3, 6, 0), shade(rock, 0.08), {
			Material = Enum.Material.Slate,
			Shape = Enum.PartType.Cylinder,
		})
		Core.ellipsoid(model, "BoulderHalf", Vector3.new(8, 12, 12), half * CFrame.new(side * 4.6, 6, 0), rock, Enum.Material.Rock)
		Core.ellipsoid(model, "Moss", Vector3.new(5, 2, 7), half * CFrame.new(side * 5.4, 11.2, 0.6), rgb(62, 86, 56), Enum.Material.Grass)
	end
	-- corde sacrée (shimenawa) et papiers en zigzag
	for k = 0, 11 do
		local a0 = k / 12 * math.pi * 2
		local a1 = (k + 1) / 12 * math.pi * 2
		local p0 = (cf * CFrame.new(math.cos(a0) * 9.4, 7, math.sin(a0) * 6.6)).Position
		local p1 = (cf * CFrame.new(math.cos(a1) * 9.4, 7, math.sin(a1) * 6.6)).Position
		Core.cylinder(model, "Shimenawa", p0, p1, 0.7, rgb(214, 196, 140), { Material = Enum.Material.Fabric, CanCollide = false })
		if k % 3 == 0 then
			Build.deco(model, "Shide", Vector3.new(0.6, 1.4, 0.06), CFrame.new(p0 - UP * 1) * CFrame.Angles(0, -a0, 0), rgb(250, 248, 240))
		end
	end
	return model
end

-- Train de l'Infini (locomotive à vapeur et voitures) sur un viaduc de pierre à arches.
-- `cf` = centre du viaduc au niveau de la mer, X = sens de la voie.
local function infinityTrain(parent: Instance, cf: CFrame, rng: Random): Model
	local model = Core.slot(parent, "TrainInfini", cf, 60)
	pcall(function()
		model.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	end)
	local length, deckY = 260, 28
	local stone = rgb(96, 94, 104)
	-- piles et arches
	for x = -length / 2, length / 2, 26 do
		Archi.block(model, "Pier", Vector3.new(6, deckY + 4, 9), cf * CFrame.new(x, -4, 0), shade(stone, rng:NextNumber(-0.06, 0.04)), Enum.Material.Cobblestone)
		if x < length / 2 then
			for k = 1, 5 do
				local t0 = (k - 1) / 5
				local t1 = k / 5
				local function arc(t: number): Vector3
					return (cf * CFrame.new(x + 3 + t * 20, deckY - 8 + math.sin(t * math.pi) * 6, 0)).Position
				end
				Core.beam(model, "Arch", arc(t0), arc(t1), 9, 2.4, stone, { Material = Enum.Material.Cobblestone, CanCollide = false })
			end
		end
	end
	Build.part(model, "Deck", Vector3.new(length + 6, 2, 10), cf * CFrame.new(0, deckY, 0), shade(stone, -0.08), { Material = Enum.Material.Slate })
	for _, z in { -2, 2 } do
		Build.deco(model, "Rail", Vector3.new(length + 6, 0.4, 0.4), cf * CFrame.new(0, deckY + 1.2, z), rgb(70, 70, 76), { Material = Enum.Material.Metal })
	end
	for _, z in { -4.8, 4.8 } do
		Build.deco(model, "Parapet", Vector3.new(length + 6, 1.4, 0.6), cf * CFrame.new(0, deckY + 1.7, z), stone, { Material = Enum.Material.Cobblestone })
	end
	local rail = cf * CFrame.new(-40, deckY + 1.4, 0)
	local black = rgb(28, 28, 32)
	local red = rgb(150, 30, 34)
	-- locomotive
	local boilerA = (rail * CFrame.new(-2, 5.4, 0)).Position
	local boilerB = (rail * CFrame.new(-20, 5.4, 0)).Position
	Core.cylinder(model, "Boiler", boilerA, boilerB, 6.4, black, { Material = Enum.Material.Metal, CanCollide = false })
	for k = 0, 3 do
		Core.cylinder(
			model,
			"BoilerBand",
			(rail * CFrame.new(-4 - k * 4.4, 5.4, 0)).Position,
			(rail * CFrame.new(-4.4 - k * 4.4, 5.4, 0)).Position,
			6.6,
			rgb(170, 140, 70),
			{ Material = Enum.Material.Metal, CanCollide = false }
		)
	end
	Core.cylinder(model, "SmokeBox", boilerB, (rail * CFrame.new(-21.4, 5.4, 0)).Position, 6.8, rgb(40, 40, 44), { Material = Enum.Material.Metal, CanCollide = false })
	local plate = Build.deco(model, "FrontPlate", Vector3.new(0.3, 2, 3), rail * CFrame.new(-21.6, 5.4, 0), red, { Material = Enum.Material.Metal })
	Build.surfaceText(plate, Enum.NormalId.Left, "無限", rgb(250, 230, 160), { TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
	local headlamp = Core.ball(model, "HeadLamp", 1.4, (rail * CFrame.new(-21.6, 8.8, 0)).Position, rgb(255, 240, 200), Enum.Material.Neon, false)
	Core.light(headlamp, rgb(255, 236, 190), 40, 2)
	local chimney = rail * CFrame.new(-18, 8, 0)
	Core.vcyl(model, "Chimney", chimney, 4.6, 2.2, black, Enum.Material.Metal, false)
	Core.vcyl(model, "ChimneyLip", chimney * CFrame.new(0, 4.4, 0), 0.8, 2.8, black, Enum.Material.Metal, false)
	Core.ellipsoid(model, "SteamDome", Vector3.new(2.6, 2.2, 2.6), rail * CFrame.new(-11, 8.6, 0), rgb(170, 140, 70), Enum.Material.Metal)
	Archi.block(model, "Cab", Vector3.new(8, 9, 7.6), rail * CFrame.new(2, 1.6, 0), black, Enum.Material.Metal)
	Build.part(model, "CabRoof", Vector3.new(10, 0.6, 8.6), rail * CFrame.new(2, 10.9, 0), red, { Material = Enum.Material.Metal })
	for _, z in { -3.85, 3.85 } do
		Build.deco(model, "CabWindow", Vector3.new(3, 2.6, 0.1), rail * CFrame.new(2, 7.4, z), rgb(255, 200, 120), { Material = Enum.Material.Neon })
	end
	Build.wedge(model, "Pilot", Vector3.new(6, 2.4, 3), rail * CFrame.new(-23, 1.2, 0) * CFrame.Angles(0, math.rad(90), 0), red, { CanCollide = false })
	for k = 0, 2 do
		for _, z in { -3.3, 3.3 } do
			local wheel = Build.deco(
				model,
				"Wheel",
				Vector3.new(0.6, 4.2, 4.2),
				rail * CFrame.new(-17 + k * 5.4, 2.1, z) * CFrame.Angles(0, math.rad(90), 0),
				red,
				{ Material = Enum.Material.Metal }
			)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	for _, z in { -3.6, 3.6 } do
		Build.deco(model, "Rod", Vector3.new(11, 0.4, 0.3), rail * CFrame.new(-11.6, 2.1, z), rgb(180, 180, 186), { Material = Enum.Material.Metal })
	end
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Fumee"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(rgb(90, 88, 96), rgb(40, 40, 46))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 14) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(5, 8)
	smoke.Rate = 6
	smoke.Speed = NumberRange.new(6, 9)
	smoke.Acceleration = Vector3.new(2, 1, 0)
	smoke.EmissionDirection = Enum.NormalId.Top
	local chimneyTop = Build.deco(model, "ChimneyTop", Vector3.new(1, 0.2, 1), chimney * CFrame.new(0, 5.4, 0), black, { Transparency = 1 })
	smoke.Parent = chimneyTop
	-- tender et voitures (bois sombre, fenêtres allumées, toit bombé)
	Archi.block(model, "Tender", Vector3.new(9, 6, 7.4), rail * CFrame.new(12, 1.6, 0), black, Enum.Material.Metal)
	local carColor = rgb(70, 26, 30)
	for c = 0, 3 do
		local x = 24 + c * 25
		local car = rail * CFrame.new(x + 10, 1.8, 0)
		Archi.block(model, "Car", Vector3.new(22, 8, 7.6), car, carColor, Enum.Material.WoodPlanks)
		Build.deco(model, "CarBand", Vector3.new(22.2, 0.5, 7.8), car * CFrame.new(0, 2.4, 0), rgb(170, 140, 70), { Material = Enum.Material.Metal })
		Core.ellipsoid(model, "CarRoof", Vector3.new(23, 2.4, 8.4), car * CFrame.new(0, 8, 0), rgb(36, 34, 38), Enum.Material.Metal)
		for _, z in { -3.85, 3.85 } do
			for k = 0, 5 do
				Build.deco(model, "CarWindow", Vector3.new(2.2, 2.4, 0.1), car * CFrame.new(-8.5 + k * 3.4, 5.2, z), rgb(255, 206, 130), { Material = Enum.Material.Neon })
			end
			for _, wx in { -8, -5.6, 5.6, 8 } do
				local wheel = Build.deco(
					model,
					"CarWheel",
					Vector3.new(0.5, 2.4, 2.4),
					car * CFrame.new(wx, -0.6, z * 0.85) * CFrame.Angles(0, math.rad(90), 0),
					black,
					{ Material = Enum.Material.Metal }
				)
				wheel.Shape = Enum.PartType.Cylinder
			end
		end
	end
	return model
end

------------------------------------------------------------------------
-- Construction du décor
------------------------------------------------------------------------

local MOUNT_ANGLE = 270
local MOUNT_RADIUS = 742
local TRAIN_ANGLE = 112
local ESTATE_ANGLE = 120
local TRAINING_ANGLE = 186

-- Maisons de la ville (angle, rayon). Les secteurs du domaine et du terrain d'entraînement
-- sont laissés libres.
local function townSlots(rng: Random): { { number } }
	local slots = {}
	for i = 0, 47 do
		local angle = i * 7.5 + 3.75 + rng:NextNumber(-0.8, 0.8)
		for _, radius in { 312, 290 } do
			local pos = polar(angle, radius)
			local nearEstate = Common.angleDiff(angle, ESTATE_ANGLE) < 9
			local nearTraining = Common.angleDiff(angle, TRAINING_ANGLE) < 7
			if not nearEstate and not nearTraining and not Layout.onPath(pos, 12) and not Layout.inBossArena(pos, 18) then
				if radius == 312 or i % 2 == 0 then
					table.insert(slots, { angle, radius })
				end
			end
		end
	end
	return slots
end

function Pourfendeur.build(decor: Instance, rng: Random, _theme)
	local ring = Build.folder(decor, "Anneau")
	local island = Build.folder(decor, "Ile")
	local horizon = Build.folder(decor, "Horizon")
	local town = Build.folder(ring, "Ville")

	-- 1) La ville de l'ère Taishō : deux rangées de maisons de marchands.
	local housePositions = {}
	for _, slot in townSlots(rng) do
		local cf = facing(slot[1], slot[2] + rng:NextNumber(-1.5, 1.5), TOP_RING)
		machiya(town, cf, rng:NextNumber(12, 16), rng)
		if slot[2] == 312 then
			table.insert(housePositions, cf)
		end
	end
	-- guirlandes de lanternes rouges entre maisons voisines de la rangée extérieure
	for i = 1, #housePositions - 1, 2 do
		local a = (housePositions[i] * CFrame.new(0, 12.5, -11)).Position
		local b = (housePositions[i + 1] * CFrame.new(0, 12.5, -11)).Position
		if (a - b).Magnitude < 48 then
			Archi.lanternString(town, a, b, 5, { LANTERN_RED, rgb(255, 220, 160) }, 1.2)
		end
	end
	Common.ringStreet(town, 264, 281, "pave", rng)

	-- 2) Lampadaires à gaz, poteaux électriques et câbles.
	local street = Build.folder(ring, "Rue")
	local prevLeft, prevRight, prevAngle = nil, nil, nil
	for i = 0, 71 do
		local angle = i * 5 + 2.5
		local pos = polar(angle, 276, TOP_RING)
		if Layout.onPath(pos, 4) or Layout.inBossArena(pos, 8) then
			prevLeft = nil
		elseif i % 2 == 0 then
			local left, right = Archi.pole(street, pos, 15, math.rad(-angle), i % 8 == 0)
			if prevLeft and Common.angleDiff(angle, prevAngle) < 11 then
				Archi.cable(street, prevLeft, left, 1.4)
				Archi.cable(street, prevRight, right, 1.4)
			end
			prevLeft, prevRight, prevAngle = left, right, angle
		else
			Props.lamppost(street, polar(angle, 266, TOP_RING), nil, rgb(255, 214, 150))
		end
	end
	Common.alongRoads({ 104, 176, 240 }, 5, function(pos)
		Props.lamppost(street, pos, nil, rgb(255, 214, 150))
	end)
	for _, plotAngle in Layout.PlotAngles do
		local deg = math.deg(plotAngle)
		local radius = 300
		local half = math.deg((Layout.PathWidth / 2 + 4) / radius)
		local a = polar(deg - half, radius, TOP_RING)
		local b = polar(deg + half, radius, TOP_RING)
		if Common.angleDiff(deg, MOUNT_ANGLE) > 5 then
			for _, p in { a, b } do
				Core.vcyl(street, "LanternPost", CFrame.new(p), 13, 0.6, DARK_WOOD, Enum.Material.Wood)
			end
			Archi.lanternString(street, a + UP * 12.6, b + UP * 12.6, 6, { LANTERN_RED, rgb(255, 220, 160) }, 1.4)
		end
	end

	-- 3) Le Domaine des Papillons.
	butterflyEstate(ring, facing(ESTATE_ANGLE, 304, TOP_RING), rng)

	-- 4) Tunnel de glycine sur la route de la base 150°, arches de glycine sur les autres routes,
	--    grande porte sur la route 270°.
	local sacred = Build.folder(ring, "Glycines")
	for r = 116, 196, 10 do
		trellis(sacred, facing(150, r, TOP_RING), Layout.PathWidth, 9, rng)
	end
	slayerGate(ring, facing(270, Layout.RingFenceRadius + 3, TOP_RING), rng)
	for _, plotAngle in Layout.PlotAngles do
		local deg = math.deg(plotAngle)
		if Common.angleDiff(deg, 270) > 5 then
			wisteriaArch(sacred, facing(deg, Layout.RingFenceRadius + 2, TOP_RING), Layout.PathWidth, rng)
			wisteriaArch(sacred, facing(deg, Layout.RingInner + 4, TOP_RING), Layout.PathWidth, rng)
		end
	end

	-- 5) Terrain d'entraînement : rocher fendu, mannequins, palissade.
	local training = Build.folder(ring, "Entrainement")
	local trainingCF = facing(TRAINING_ANGLE, 304, TOP_RING)
	splitBoulder(training, trainingCF)
	for k = -1, 1, 2 do
		Props.trainingPost(training, (trainingCF * CFrame.new(k * 13, 0, -8)).Position, rng)
		Props.trainingPost(training, (trainingCF * CFrame.new(k * 15, 0, 2)).Position, rng)
	end
	Props.weaponRack(training, trainingCF * CFrame.new(0, 0, 14) * CFrame.Angles(0, math.pi, 0))
	Relief.fence(training, (trainingCF * CFrame.new(-20, 0, 18)).Position, (trainingCF * CFrame.new(20, 0, 18)).Position, "bois", 4)
	hokora(training, trainingCF * CFrame.new(-17, 0, 12))

	-- 6) Arbres de l'anneau : glycines, bambous, cèdres ; buissons, rochers ; lys araignées.
	Core.scatter(rng, 24, Vector3.zero, Layout.RingInner + 6, 110, function(p)
		return Common.ringFree(p, 6)
	end, function(p)
		local roll = rng:NextNumber()
		local species = roll < 0.5 and "Glycine" or (roll < 0.8 and "Bambou" or "Cerisier")
		Nature.tree(species, ring, p + UP * TOP_RING, {
			rng = rng,
			height = species == "Bambou" and rng:NextNumber(22, 30) or rng:NextNumber(13, 18),
			detail = "normal",
			palette = species == "Cerisier" and "glycine" or nil,
		})
	end)
	Core.scatter(rng, 12, Vector3.zero, 168, 178, function(p)
		return Common.ringFree(p, 12)
	end, function(p)
		Nature.tree("Cedre", ring, p + UP * TOP_RING, { rng = rng, height = rng:NextNumber(32, 44), detail = "normal" })
	end)
	-- bosquets de bambous serrés dans la bande libre 234-245
	Core.scatter(rng, 10, Vector3.zero, 236, 243, function(p)
		return Common.ringFree(p, 10)
	end, function(center)
		for _ = 1, rng:NextInteger(3, 6) do
			local p = center + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
			if Common.ringFree(p, 2) then
				Nature.tree("Bambou", ring, p + UP * TOP_RING, { rng = rng, height = rng:NextNumber(24, 34), detail = "normal" })
			end
		end
	end)
	-- (hors de la ville : les maisons commencent vers 284)
	Core.scatter(rng, 60, Vector3.zero, Layout.RingInner + 6, 262, function(p)
		return Common.ringFree(p, 4)
	end, function(p)
		local roll = rng:NextNumber()
		if roll < 0.5 then
			Nature.bush(ring, p + UP * TOP_RING, { rng = rng, height = rng:NextNumber(3, 4.5), palette = "nuit", flowers = rng:NextNumber() < 0.25 and WISTERIA[3] or nil })
		elseif roll < 0.85 then
			Nature.rock(ring, p + UP * TOP_RING, rng:NextNumber(2.5, 5), { rng = rng, color = rgb(96, 96, 108), moss = rgb(60, 84, 62) })
		else
			Nature.stump(ring, p + UP * TOP_RING, rng:NextNumber(2, 3), rng)
		end
	end)
	Core.scatter(rng, 36, Vector3.zero, Layout.RingInner + 3, 262, function(p)
		return Common.ringFree(p, 2)
	end, function(p)
		lilyClump(ring, p + UP * TOP_RING, rng)
	end)
	Common.ringGround(ring, rng, { patches = 24, tufts = 300, flowers = 70, flowerColors = { WISTERIA[2], WISTERIA[4], rgb(240, 240, 250) }, patchRole = "herbe" })

	-- 7) Île : forêt de bambous, cèdres et glycines, forêt aux toiles, sanctuaires de renards.
	local spiderAt = polar(150, 600)
	local free = Common.islandFree({ { polar(MOUNT_ANGLE, 650), 110 }, { spiderAt, 26 } })
	Common.forest(island, rng, {
		groves = 30,
		perGrove = { 5, 8 },
		radius = { 20, 38 },
		free = free,
		spacing = 0.26,
		species = {
			{ "Bambou", 3.5, 26, 38 },
			{ "Cedre", 3, 30, 48 },
			{ "Glycine", 1.6, 14, 20 },
			{ "Sapin", 1.4, 24, 34, "nuit" },
			{ "ArbreFeuillu", 1, 20, 28, "nuit" },
		},
		undergrowth = { palette = "nuit", ferns = rgb(48, 74, 56), flowers = { WISTERIA[3], LILY_RED }, rocks = rgb(90, 90, 104), mushrooms = true },
	})
	-- la forêt aux toiles d'araignée : sapins sombres en cercle reliés par des toiles, cocons
	local webs = Build.folder(island, "ForetAuxToiles")
	local spiderGround = Common.ground(spiderAt)
	local trunks = {}
	for k = 0, 5 do
		local p = Common.ground(spiderAt + polar(k * 60 + rng:NextNumber(-10, 10), rng:NextNumber(12, 17)))
		Nature.tree("ArbreMort", webs, p, { rng = rng, height = rng:NextNumber(20, 26), detail = "normal" })
		table.insert(trunks, p)
	end
	for k = 1, #trunks do
		local a = trunks[k]
		local b = trunks[k % #trunks + 1]
		local mid = (a + b) / 2 + UP * rng:NextNumber(7, 10)
		spiderWeb(webs, CFrame.lookAt(mid, mid + (b - a):Cross(UP)), math.min(6, (b - a).Magnitude * 0.42))
	end
	for _ = 1, 4 do
		local p = spiderGround + Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(6, 10), rng:NextNumber(-8, 8))
		Core.ellipsoid(webs, "Cocon", Vector3.new(1.8, 3.4, 1.8), CFrame.new(p), rgb(226, 228, 232), Enum.Material.Fabric)
		Build.deco(webs, "Fil", Vector3.new(0.06, 8, 0.06), CFrame.new(p + UP * 5.6), rgb(232, 236, 244), { Transparency = 0.3 })
	end
	for _, angle in { 20, 80, 200, 330 } do
		local p = Common.ground(polar(angle, 596))
		if free(p, 4) then
			hokora(island, CFrame.lookAt(p, Vector3.new(0, p.Y, 0)))
			lilyClump(island, p + Vector3.new(4, 0, 2), rng)
		end
	end
	Core.scatter(rng, 28, Vector3.zero, Layout.WalkwayOuter + 6, Layout.IslandRadius - 10, function(p)
		return free(p, 2)
	end, function(p)
		lilyClump(island, Common.ground(p), rng)
	end)

	-- 8) Le mont Fujikasane au bord de l'île, ceint de glycines en fleur, torii au pied.
	local mount = Build.folder(horizon, "MontFujikasane")
	Nature.mountain(mount, polar(MOUNT_ANGLE, MOUNT_RADIUS, -3), 230, 150, {
		rng = rng,
		rock = rgb(66, 66, 82),
		grass = rgb(42, 60, 56),
		trees = rgb(30, 44, 42),
		slot = "MontFujikasane",
	})
	local openGround = Common.islandFree()
	for k = 0, 23 do
		local angle = MOUNT_ANGLE - 17 + k * (34 / 23) + rng:NextNumber(-0.6, 0.6)
		local p = Common.ground(polar(angle, rng:NextNumber(578, 622)))
		if openGround(p, 3) then
			Nature.tree("Glycine", mount, p, { rng = rng, height = rng:NextNumber(16, 24), detail = k % 3 == 0 and "hero" or "normal" })
		end
	end
	local foot = Common.ground(polar(MOUNT_ANGLE, 600))
	for k = 0, 3 do
		local p = Common.ground(polar(MOUNT_ANGLE, 560 + k * 9))
		Build.torii(mount, CFrame.lookAt(p, Vector3.new(0, p.Y, 0)), 10, 12, rgb(170, 40, 44), rgb(30, 22, 24))
	end
	Archi.sign(
		mount,
		CFrame.lookAt(foot + UP * 4, Vector3.new(0, foot.Y + 4, 0)) * CFrame.new(9, 0, 0),
		6,
		2,
		"藤襲山",
		{ posts = 3, bg = rgb(40, 30, 28), text = rgb(236, 210, 150) }
	)
	for _, side in { -1, 1 } do
		Props.stoneLantern(mount, (CFrame.lookAt(foot, Vector3.new(0, foot.Y, 0)) * CFrame.new(side * 7, 0, -32)).Position, 1, rgb(220, 180, 255))
	end

	-- 9) Horizon : montagnes bleu nuit et le Train de l'Infini sur son viaduc.
	Common.horizon(horizon, rng, 22, {
		rock = rgb(52, 54, 74),
		grass = rgb(34, 48, 50),
		trees = rgb(24, 36, 38),
		snow = rgb(196, 204, 232),
		skip = { { MOUNT_ANGLE, 18 }, { TRAIN_ANGLE, 14 } },
	})
	local trainPos = polar(TRAIN_ANGLE, 790, 0)
	local tangent = Vector3.new(-trainPos.Z, 0, trainPos.X).Unit
	infinityTrain(horizon, CFrame.lookAt(trainPos, trainPos + tangent) * CFrame.Angles(0, math.pi / 2, 0), rng)

	-- 10) Lampes de la promenade, pétales de glycine, lucioles, brume basse.
	Common.walkwayLamps(ring, 15, function(pos)
		Props.lamppost(ring, pos, nil, rgb(255, 214, 150))
	end)
	Common.ambient(decor, "Petales", {
		colors = ColorSequence.new(rgb(196, 160, 245), rgb(240, 220, 255)),
		size = 0.6,
		rate = 46,
		speed = NumberRange.new(2, 4),
		direction = Enum.NormalId.Bottom,
		y = 60,
		radius = 420,
	})
	local fireflies = Common.ambient(decor, "Lucioles", {
		colors = ColorSequence.new(rgb(220, 255, 140), rgb(170, 230, 90)),
		size = 0.35,
		rate = 36,
		speed = NumberRange.new(0.3, 1.2),
		direction = Enum.NormalId.Top,
		y = 1.5,
		radius = 600,
		lifetime = NumberRange.new(5, 9),
		lightEmission = 1,
		spin = false,
	})
	CollectionService:AddTag(fireflies.Parent, "Ambiance")
	Common.ambient(decor, "Brume", {
		texture = "rbxasset://textures/particles/smoke_main.dds",
		colors = ColorSequence.new(rgb(130, 140, 190)),
		size = 14,
		rate = 12,
		speed = NumberRange.new(0.3, 1),
		direction = Enum.NormalId.Top,
		y = 1,
		radius = 600,
		lifetime = NumberRange.new(8, 12),
		lightEmission = 0,
		spin = false,
	})
end

return Pourfendeur
