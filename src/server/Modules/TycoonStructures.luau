-- Plan de la base tycoon et constructions des 28 améliorations (Economy.Upgrades).
--
-- Repère local d'une base : centre au sol, -Z = entrée (côté hub), +Z = fond.
-- La base fait Layout.PlotSize (140) de côté ; la bande extérieure de 10 studs (|x| ou |z| > 60)
-- est réservée au décor de l'univers (murs, portail : World/BaseDecor.luau).
--
--            (fond, +Z)
--   pagode  autels+marchand  autel d'éveil  sanctuaire   tour
--   dojo          [ gradins ]                            jardin
--   mannequins   [ COUR DES UNITÉS : 24 cases hexagonales ] fontaine
--   tatami                                                 ramen
--   distributeurs+tapis   [ MACHINE ROULER (estrade) ]    arbre de compétences
--   coffre          tapis rouge + torii + lanternes        statue / gong
--            (entrée, -Z, portail)
--
-- Chaque amélioration a ici : pad = position (X, Z) de son bouton d'achat, build(ctx) qui construit.
-- `ctx` : { plot, folder, at(x, y, z, yawDeg?) -> CFrame (monde), rng, bestLook, ghost, coinPaths }
-- `ghost` = vrai pour le fantôme d'aperçu (pas de lumières ni de pièces qui roulent).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local CharacterBuilder = require(Shared.Modules.CharacterBuilder)
local Build = require(script.Parent.Build)
local Kit = require(script.Parent.TycoonKit)
local Conveyor = require(script.Parent.TycoonConveyor)

local Structures = {}

local rgb = Color3.fromRGB
local C = Kit.Colors
local H = Layout.PlotSize / 2

------------------------------------------------------------------------
-- Plan (partagé avec PlotService)
------------------------------------------------------------------------

local Spots = {
	H = H,
	inner = H - 10, -- limite de la zone de jeu (le reste = décor de l'univers)
	gateHalf = 10, -- demi-largeur de l'entrée
	spawn = Vector3.new(0, 3, -53),
	machine = Vector3.new(0, 0, -30), -- centre de l'estrade ROULER
	carpetLength = 22,
	chest = Vector3.new(-47, 0, -52), -- coffre des revenus (au bout du tapis)
	beltX = -47,
	beltTop = -15, -- début du tapis (côté fond)
	beltEnd = -47, -- fin du tapis (côté coffre)
	beltY = 1.7,
	board = Vector3.new(-30, 0, -57), -- grand compteur d'argent
	skillTree = Vector3.new(46, 0, -44), -- arbre de compétences lumineux
	lectern = Vector3.new(38, 0, -52), -- pupitre qui ouvre l'écran de l'arbre
	merchant = Vector3.new(-32, 0, 54), -- marchand de reliques (ancienne machine à reliques)
	altar = Vector3.new(0, 0, 46), -- autel d'éveil (évolutions)
	pedestals = { Vector3.new(-44, 0, 44), Vector3.new(-37, 0, 44), Vector3.new(-30, 0, 44), Vector3.new(-23, 0, 44) },
	-- Cour des unités : 6 colonnes x 4 rangées de cases hexagonales.
	slotCols = { -26.25, -15.75, -5.25, 5.25, 15.75, 26.25 },
	slotRows = { -8, 2, 12, 22 },
	slotRadius = 3.5,
	slotHeight = 0.6,
	court = { x0 = -34, x1 = 34, z0 = -15, z1 = 29 },
	droppers = { -40, -31, -22 }, -- Z des trois distributeurs (X = beltX - 7.5)
}
Structures.Spots = Spots

------------------------------------------------------------------------
-- Éléments partagés
------------------------------------------------------------------------

-- Petite statue de pierre (komainu stylisé) pour encadrer les entrées.
local function guardian(folder: Instance, cf: CFrame, s: number)
	Build.part(folder, "SocleGardien", Vector3.new(3, 2, 3) * s, cf * CFrame.new(0, 1 * s, 0), C.StoneDark, { Material = Enum.Material.Slate })
	Kit.blob(folder, "Corps", Vector3.new(2, 2.4, 2.6) * s, cf * CFrame.new(0, 3.1 * s, 0.2 * s), C.StoneMid, { Material = Enum.Material.Slate })
	Kit.blob(folder, "Tête", Vector3.new(1.9, 1.8, 1.8) * s, cf * CFrame.new(0, 4.6 * s, -0.6 * s), C.StoneMid, { Material = Enum.Material.Slate })
	Kit.blob(folder, "Crinière", Vector3.new(2.4, 1.6, 1) * s, cf * CFrame.new(0, 4.5 * s, -0.1 * s), C.StoneDark, { Material = Enum.Material.Slate })
	for _, x in { -0.5, 0.5 } do
		Kit.blob(folder, "Oeil", Vector3.new(0.3, 0.3, 0.2) * s, cf * CFrame.new(x * s, 4.9 * s, -1.45 * s), rgb(255, 210, 90), { Material = Enum.Material.Neon })
	end
end
Structures.guardian = guardian

-- Aperçu d'un autel de relique (le vrai autel est construit par PlotService).
local function pedestalPreview(ctx, slot: number)
	if not ctx.ghost then
		return
	end
	local p = Spots.pedestals[slot]
	local base = ctx.at(p.X, 0, p.Z)
	Build.part(ctx.folder, "Base", Vector3.new(5, 1.2, 5), base * CFrame.new(0, 0.6, 0), C.StoneMid)
	Build.part(ctx.folder, "Colonne", Vector3.new(3.4, 2, 3.4), base * CFrame.new(0, 2.2, 0), C.StoneLight)
	Build.part(ctx.folder, "Dessus", Vector3.new(4.4, 0.6, 4.4), base * CFrame.new(0, 3.5, 0), C.StoneMid)
end

local function teamBanners(ctx, side: number, color: Color3)
	for i, dx in { 35, 38.5, 42 } do
		Kit.nobori(ctx.folder, ctx.at(side * dx, 0, -18.5, side > 0 and 180 or 0), color:Lerp(rgb(255, 255, 255), (i - 1) * 0.12), 12, rgb(255, 235, 150))
	end
	Build.part(ctx.folder, "SocleBannieres", Vector3.new(9, 0.6, 2.4), ctx.at(side * 38.5, 0.3, -18.5), C.StoneMid, { Material = Enum.Material.Slate })
end

local function spin(part: BasePart, axis: string, speed: number, bob: number?)
	part:SetAttribute("SpinAxis", axis)
	part:SetAttribute("SpinSpeed", speed)
	if bob then
		part:SetAttribute("Bob", bob)
	end
	CollectionService:AddTag(part, "Spin")
end

local function dropper(ctx, z: number, styleName: string)
	Conveyor.dropper(ctx.folder, ctx.at(Spots.beltX - 7.5, 0, z), 7.5, styleName, ctx.ghost)
	if not ctx.ghost and ctx.coinPaths then
		local style = Conveyor.Styles[styleName]
		local y = Spots.beltY + 0.35
		table.insert(ctx.coinPaths, {
			kind = style.coin,
			interval = style.interval,
			points = {
				ctx.at(Spots.beltX, 6.2, z).Position,
				ctx.at(Spots.beltX, y, z).Position,
				ctx.at(Spots.beltX, y, Spots.beltEnd + 1).Position,
				ctx.at(Spots.chest.X, 3.4, Spots.chest.Z).Position,
			},
		})
	end
end

------------------------------------------------------------------------
-- Constructions
------------------------------------------------------------------------

local S = {}

-- Palier 1 -------------------------------------------------------------

S.distributeur = {
	pad = { -39, -40 },
	build = function(ctx)
		dropper(ctx, Spots.droppers[1], "bronze")
		-- Panneau d'atelier au-dessus du tapis.
		local sign = Build.part(ctx.folder, "PanneauAtelier", Vector3.new(0.5, 3, 12), ctx.at(Spots.beltX - 13, 8.5, -31), C.WoodDark, { Material = Enum.Material.Wood })
		for _, dz in { -5, 5 } do
			Build.part(ctx.folder, "PiedPanneau", Vector3.new(0.6, 10, 0.6), ctx.at(Spots.beltX - 13, 5, -31 + dz), C.WoodDark, { Material = Enum.Material.Wood })
		end
		if not ctx.ghost then
			Build.surfaceText(sign, Enum.NormalId.Right, "ATELIER DES PIÈCES", C.Gold)
		end
	end,
}

S.distributeur2 = {
	pad = { -39, -31 },
	build = function(ctx)
		dropper(ctx, Spots.droppers[2], "gold")
	end,
}

S.distributeur3 = {
	pad = { -39, -22 },
	build = function(ctx)
		dropper(ctx, Spots.droppers[3], "crystal")
		local crystal =
			Kit.blob(ctx.folder, "Cristal", Vector3.new(1.6, 3, 1.6), ctx.at(Spots.beltX - 7.5, 16.5, Spots.droppers[3]), rgb(140, 235, 255), { Material = Enum.Material.Neon })
		spin(crystal, "Y", 1.5, 0.5)
	end,
}

S.lanternes = {
	pad = { -15, -56 },
	build = function(ctx)
		for _, z in { -57, -49, -41 } do
			for _, side in { -1, 1 } do
				Kit.toro(ctx.folder, ctx.at(side * 8.5, 0, z), 1)
			end
		end
	end,
}

S.dallage = {
	pad = { 0, -16 },
	build = function(ctx)
		local court = Spots.court
		local cx, cz = (court.x0 + court.x1) / 2, (court.z0 + court.z1) / 2
		local w, d = court.x1 - court.x0, court.z1 - court.z0
		-- Margelle de pierre autour de la cour + dalles claires.
		Kit.curb(ctx.folder, ctx.at(cx, 0, cz), w, d, 1.2, 0.7, C.StoneMid, Enum.Material.Cobblestone)
		local stones = { rgb(222, 212, 192), rgb(210, 200, 180), rgb(230, 222, 204), rgb(200, 190, 172) }
		Kit.tiles(ctx.folder, ctx.at(cx, 0.32, cz), w, d, 5.5, stones, Enum.Material.Limestone, ctx.rng, { name = "DallesCour", thickness = 0.3 })
		-- Gardiens de pierre à l'entrée de la cour.
		for _, side in { -1, 1 } do
			guardian(ctx.folder, ctx.at(side * 9, 0.3, court.z0 - 1.5, 0), 0.9)
		end
	end,
}

S.tatami = {
	pad = { -39, -4 },
	build = function(ctx)
		local base = ctx.at(-50, 0, -3, 90)
		Build.part(ctx.folder, "Estrade", Vector3.new(18, 0.8, 12), base * CFrame.new(0, 0.4, 0), C.WoodDark, { Material = Enum.Material.Wood })
		for i = 0, 3 do
			Build.part(ctx.folder, "Tatami", Vector3.new(4.1, 0.3, 11), base * CFrame.new(-6.3 + i * 4.2, 0.95, 0), rgb(196, 204, 128), { Material = Enum.Material.Fabric })
			for _, z in { -5.2, 5.2 } do
				Build.deco(ctx.folder, "Galon", Vector3.new(4.12, 0.32, 0.5), base * CFrame.new(-6.3 + i * 4.2, 0.96, z), rgb(40, 60, 50), { Material = Enum.Material.Fabric })
			end
		end
		-- Râtelier d'armes en bois au fond.
		local rack = base * CFrame.new(0, 0, 6.6)
		for _, x in { -4, 4 } do
			Build.part(ctx.folder, "Montant", Vector3.new(0.5, 5, 0.5), rack * CFrame.new(x, 3.3, 0), C.WoodDark, { Material = Enum.Material.Wood })
		end
		for _, y in { 2.4, 4.4 } do
			Build.part(ctx.folder, "Barre", Vector3.new(8.6, 0.4, 0.4), rack * CFrame.new(0, y, 0), C.WoodDark, { Material = Enum.Material.Wood })
		end
		for i = -3, 3 do
			Build.deco(
				ctx.folder,
				"Bokken",
				Vector3.new(0.25, 4.6, 0.25),
				rack * CFrame.new(i * 1.1, 3.4, -0.35) * CFrame.Angles(0.15, 0, 0),
				C.WoodLight,
				{ Material = Enum.Material.Wood }
			)
		end
	end,
}

S.mannequins = {
	pad = { -37, 11 },
	build = function(ctx)
		local base = ctx.at(-50, 0, 11)
		Build.part(ctx.folder, "Sable", Vector3.new(18, 0.5, 9), base * CFrame.new(0, 0.3, 0), C.Sand, { Material = Enum.Material.Sand })
		for i = -1, 1 do
			local cf = base * CFrame.new(i * 5.5, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0)
			Build.part(ctx.folder, "Poteau", Vector3.new(0.9, 6, 0.9), cf * CFrame.new(0, 3, 0), C.Wood, { Material = Enum.Material.Wood })
			Kit.blob(ctx.folder, "Paille", Vector3.new(2.6, 3.2, 1.8), cf * CFrame.new(0, 4.4, 0), rgb(222, 190, 112), { Material = Enum.Material.Fabric })
			for _, y in { 3.6, 5.2 } do
				Build.deco(ctx.folder, "Corde", Vector3.new(2.7, 0.3, 1.9), cf * CFrame.new(0, y, 0), rgb(150, 100, 60), { Material = Enum.Material.Fabric })
			end
			Build.part(ctx.folder, "Bras", Vector3.new(5, 0.6, 0.6), cf * CFrame.new(0, 4.8, 0), C.Wood, { Material = Enum.Material.Wood })
			Kit.blob(ctx.folder, "Tête", Vector3.new(1.7, 1.7, 1.7), cf * CFrame.new(0, 6.8, 0), rgb(222, 190, 112), { Material = Enum.Material.Fabric })
			Build.deco(ctx.folder, "Bandeau", Vector3.new(1.75, 0.35, 1.75), cf * CFrame.new(0, 6.95, 0), C.Lacquer, { Material = Enum.Material.Fabric })
			Kit.cylinder(ctx.folder, "Cible", 0.15, 1.4, cf * CFrame.new(0, 4.6, -0.95) * CFrame.Angles(math.rad(90), 0, 0), rgb(255, 255, 255), { CanCollide = false })
			Kit.cylinder(ctx.folder, "Cible", 0.2, 0.7, cf * CFrame.new(0, 4.6, -0.97) * CFrame.Angles(math.rad(90), 0, 0), C.Lacquer, { CanCollide = false })
		end
	end,
}

S.aimant = {
	pad = { -39, -47 },
	build = function(ctx)
		-- Arche aimantée au-dessus du bout du tapis : attire les pièces vers le coffre.
		local cf = ctx.at(Spots.beltX, 0, -44.5)
		for _, side in { -1, 1 } do
			Build.part(ctx.folder, "Pilier", Vector3.new(1.2, 8, 1.2), cf * CFrame.new(side * 3.4, 4, 0), rgb(90, 92, 104), { Material = Enum.Material.Metal })
		end
		Build.part(ctx.folder, "Traverse", Vector3.new(8, 1.2, 1.6), cf * CFrame.new(0, 8.4, 0), rgb(90, 92, 104), { Material = Enum.Material.Metal })
		for _, side in { -1, 1 } do
			Build.part(ctx.folder, "BrasAimant", Vector3.new(1.4, 3, 1.4), cf * CFrame.new(side * 1.3, 6.3, 0), rgb(220, 40, 40))
			Build.part(ctx.folder, "PoleAimant", Vector3.new(1.45, 0.9, 1.45), cf * CFrame.new(side * 1.3, 4.4, 0), rgb(225, 225, 235), { Material = Enum.Material.Metal })
		end
		Build.part(ctx.folder, "ArcAimant", Vector3.new(4, 1.4, 1.4), cf * CFrame.new(0, 7.6, 0), rgb(220, 40, 40))
		local field = Build.deco(ctx.folder, "Champ", Vector3.new(3, 2, 0.4), cf * CFrame.new(0, 3.2, 0), rgb(120, 200, 255), { Material = Enum.Material.Neon, Transparency = 0.6 })
		if not ctx.ghost then
			Kit.particles(field, {
				Color = ColorSequence.new(rgb(140, 210, 255)),
				Size = NumberSequence.new(0.6, 0),
				Rate = 12,
				Lifetime = NumberRange.new(0.5, 0.9),
				Speed = NumberRange.new(1, 2),
			})
		end
	end,
}

S.remparts = { -- « Allée des Torii » au-dessus du tapis rouge
	pad = { 15, -56 },
	build = function(ctx)
		for i, z in { -56, -50, -44 } do
			Build.torii(ctx.folder, ctx.at(0, 0, z), 13.5, 12.5 - i * 0.4)
		end
		if not ctx.ghost then
			for _, z in { -56, -50, -44 } do
				for _, side in { -1, 1 } do
					Kit.paperLantern(ctx.folder, ctx.at(side * 4.4, 8.6, z), C.Lacquer, 0.8)
				end
			end
		end
	end,
}

S.arene1 = { -- braseros aux quatre coins de la cour
	pad = { 0, -16 },
	build = function(ctx)
		local court = Spots.court
		for _, x in { court.x0 + 1, court.x1 - 1 } do
			for _, z in { court.z0 + 1, court.z1 - 1 } do
				local base = ctx.at(x, 0, z)
				Kit.hexTile(ctx.folder, "SocleBrasero", base * CFrame.new(0, 0.8, 0), 1.6, 0.8, C.StoneDark, { Material = Enum.Material.Slate })
				Build.part(ctx.folder, "PiedBrasero", Vector3.new(1, 3.2, 1), base * CFrame.new(0, 2.4, 0), rgb(60, 56, 54), { Material = Enum.Material.Metal })
				Build.part(ctx.folder, "Brasero", Vector3.new(2.8, 1.2, 2.8), base * CFrame.new(0, 4.4, 0), rgb(60, 56, 54), { Material = Enum.Material.Metal })
				local braises = Build.deco(ctx.folder, "Braises", Vector3.new(2.3, 0.3, 2.3), base * CFrame.new(0, 5.05, 0), rgb(255, 120, 40), { Material = Enum.Material.Neon })
				if not ctx.ghost then
					local fire = Instance.new("Fire")
					fire.Size = 5
					fire.Heat = 7
					fire.Color = rgb(255, 140, 40)
					fire.SecondaryColor = rgb(255, 60, 20)
					fire.Parent = braises
					Kit.light(braises, rgb(255, 160, 70), 18, 1.5)
				end
			end
		end
	end,
}

S.ramen = {
	pad = { 38, -26 },
	build = function(ctx)
		local cf = ctx.at(50, 0, -26, -90) -- ouvert vers la cour
		Build.part(ctx.folder, "Plancher", Vector3.new(14, 0.6, 9), cf * CFrame.new(0, 0.3, 0), C.WoodDark, { Material = Enum.Material.WoodPlanks })
		Build.part(ctx.folder, "Comptoir", Vector3.new(12, 3.2, 2), cf * CFrame.new(0, 2.2, -2.6), C.Wood, { Material = Enum.Material.WoodPlanks })
		Build.part(ctx.folder, "Plan", Vector3.new(12.6, 0.4, 2.6), cf * CFrame.new(0, 3.95, -2.6), C.WoodLight, { Material = Enum.Material.Wood })
		Build.part(ctx.folder, "Fond", Vector3.new(12, 7, 0.6), cf * CFrame.new(0, 4, 4.1), C.Plaster, { Material = Enum.Material.Plaster })
		for _, x in { -6.4, 6.4 } do
			for _, z in { -3.8, 3.8 } do
				Build.part(ctx.folder, "Poteau", Vector3.new(0.7, 8.6, 0.7), cf * CFrame.new(x, 4.6, z), C.WoodDark, { Material = Enum.Material.Wood })
			end
		end
		Kit.roof(ctx.folder, cf * CFrame.new(0, 8.8, 0), 15.6, 11, 2.6, rgb(150, 40, 40), { name = "ToitRamen" })
		for i = -2, 2 do
			Build.deco(
				ctx.folder,
				"Noren",
				Vector3.new(2.2, 2.4, 0.1),
				cf * CFrame.new(i * 2.4, 7.2, -4.1),
				i % 2 == 0 and C.Lacquer or rgb(240, 236, 226),
				{ Material = Enum.Material.Fabric }
			)
		end
		for i = -2, 2 do
			Kit.cylinder(ctx.folder, "Bol", 0.6, 1, cf * CFrame.new(i * 2.2, 4.45, -2.6), rgb(240, 236, 226), { CanCollide = false })
			Kit.cylinder(ctx.folder, "Bouillon", 0.1, 0.8, cf * CFrame.new(i * 2.2, 4.72, -2.6), rgb(230, 170, 90), { CanCollide = false })
			Kit.cylinder(ctx.folder, "Tabouret", 2, 1.6, cf * CFrame.new(i * 2.4, 1.3, -5.2), C.Lacquer, { Material = Enum.Material.SmoothPlastic })
		end
		local pot = Kit.cylinder(ctx.folder, "Marmite", 1.6, 2.2, cf * CFrame.new(-4, 4.9, 2.4), rgb(70, 70, 80), { Material = Enum.Material.Metal })
		if not ctx.ghost then
			Kit.particles(pot, {
				Texture = "rbxasset://textures/particles/smoke_main.dds",
				LightEmission = 0,
				Color = ColorSequence.new(rgb(255, 255, 255)),
				Transparency = NumberSequence.new(0.6, 1),
				Size = NumberSequence.new(0.8, 2.4),
				Rate = 6,
				Lifetime = NumberRange.new(1.2, 2),
				Speed = NumberRange.new(1.5, 2.5),
			})
			for _, x in { -6.4, 6.4 } do
				Kit.paperLantern(ctx.folder, cf * CFrame.new(x, 6.4, -4.6), C.Lacquer, 0.9)
			end
		end
		local sign = Build.part(ctx.folder, "Enseigne", Vector3.new(8, 1.8, 0.3), cf * CFrame.new(0, 9.6, -5.4), rgb(240, 236, 226), { Material = Enum.Material.Wood })
		if not ctx.ghost then
			Build.surfaceText(sign, Enum.NormalId.Front, "🍜 RAMEN", C.Lacquer, { TextStrokeColor3 = rgb(255, 255, 255) })
		end
	end,
}

S.equipe4 = {
	pad = { -29, -16 },
	build = function(ctx)
		teamBanners(ctx, -1, rgb(60, 120, 230))
	end,
}

S.autel2 = {
	pad = { -37, 37 },
	build = function(ctx)
		pedestalPreview(ctx, 2)
	end,
}

-- Palier 2 -------------------------------------------------------------

S.fontaine = {
	pad = { 37, -6 },
	build = function(ctx)
		local base = ctx.at(49, 0, -6)
		local stone = C.StoneLight
		Kit.cylinder(ctx.folder, "Bassin", 1.6, 15, base * CFrame.new(0, 0.8, 0), stone, { Material = Enum.Material.Marble })
		Kit.cylinder(ctx.folder, "Eau", 0.3, 13.6, base * CFrame.new(0, 1.5, 0), C.Water, { Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false })
		Kit.cylinder(ctx.folder, "Colonne", 4.2, 2, base * CFrame.new(0, 3.6, 0), stone, { Material = Enum.Material.Marble })
		Kit.cylinder(ctx.folder, "Vasque", 1, 6.5, base * CFrame.new(0, 5.8, 0), stone, { Material = Enum.Material.Marble })
		Kit.cylinder(ctx.folder, "EauHaut", 0.2, 5.6, base * CFrame.new(0, 6.3, 0), C.Water, { Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false })
		local orb = Build.ball(ctx.folder, "OrbeChakra", 2.6, (base * CFrame.new(0, 8.6, 0)).Position, rgb(90, 190, 255), { Material = Enum.Material.Neon, CanCollide = false })
		orb:SetAttribute("Bob", 0.8)
		CollectionService:AddTag(orb, "Spin")
		if not ctx.ghost then
			Kit.particles(orb, {
				Color = ColorSequence.new(rgb(140, 220, 255)),
				Size = NumberSequence.new(0.6, 0),
				Rate = 18,
				Speed = NumberRange.new(3, 6),
				Lifetime = NumberRange.new(1, 1.6),
				SpreadAngle = Vector2.new(25, 25),
				Acceleration = Vector3.new(0, -12, 0),
			})
			Kit.light(orb, rgb(120, 200, 255), 18, 1.6)
		end
		for i = 0, 3 do
			local a = i * math.pi / 2 + math.pi / 4
			Kit.toro(ctx.folder, base * CFrame.new(math.cos(a) * 10, 0, math.sin(a) * 10), 0.7, rgb(140, 220, 255))
		end
	end,
}

S.portail = { -- « Gong de Guerre »
	pad = { 31, -50 },
	build = function(ctx)
		local cf = ctx.at(32, 0, -41)
		Build.part(ctx.folder, "Estrade", Vector3.new(7.5, 0.6, 4), cf * CFrame.new(0, 0.3, 0), C.StoneMid, { Material = Enum.Material.Slate })
		for _, side in { -1, 1 } do
			Build.part(ctx.folder, "Montant", Vector3.new(0.9, 9, 0.9), cf * CFrame.new(side * 3.2, 5, 0), C.Lacquer)
		end
		Build.part(ctx.folder, "Traverse", Vector3.new(8.4, 0.9, 1.1), cf * CFrame.new(0, 9.5, 0), C.Lacquer)
		Build.part(ctx.folder, "Chapeau", Vector3.new(9.4, 0.5, 1.6), cf * CFrame.new(0, 10.2, 0), rgb(30, 25, 25))
		for _, side in { -1, 1 } do
			Build.deco(ctx.folder, "Corde", Vector3.new(0.15, 1.8, 0.15), cf * CFrame.new(side * 1.6, 8.2, 0), rgb(200, 160, 90))
		end
		local gong = Kit.cylinder(ctx.folder, "Gong", 0.4, 5.6, cf * CFrame.new(0, 5.2, 0) * CFrame.Angles(math.rad(90), 0, 0), rgb(214, 160, 50), {
			Material = Enum.Material.Metal,
			Reflectance = 0.2,
		})
		Kit.cylinder(ctx.folder, "GongCentre", 0.5, 1.8, cf * CFrame.new(0, 5.2, -0.05) * CFrame.Angles(math.rad(90), 0, 0), rgb(240, 200, 90), { Material = Enum.Material.Metal })
		-- Maillet posé sur un support.
		Build.part(ctx.folder, "Maillet", Vector3.new(0.3, 3.4, 0.3), cf * CFrame.new(4.4, 2, -1) * CFrame.Angles(0, 0, 0.4), C.WoodLight, { Material = Enum.Material.Wood })
		Kit.blob(ctx.folder, "TeteMaillet", Vector3.new(1.1, 1.1, 1.1), cf * CFrame.new(5.1, 3.6, -1), rgb(240, 236, 226), { Material = Enum.Material.Fabric })
		local _ = gong
	end,
}

S.autel3 = {
	pad = { -30, 37 },
	build = function(ctx)
		pedestalPreview(ctx, 3)
	end,
}

S.torii = { -- « Pagode à Trois Toits »
	pad = { -53, 39 },
	build = function(ctx)
		local cf = ctx.at(-53, 0, 51)
		Build.part(ctx.folder, "Base", Vector3.new(12, 1.6, 12), cf * CFrame.new(0, 0.8, 0), C.StoneMid, { Material = Enum.Material.Cobblestone })
		local y = 1.6
		for tier, size in { 9, 7.4, 5.8 } do
			local h = tier == 1 and 5 or 4
			Build.part(ctx.folder, "Etage", Vector3.new(size, h, size), cf * CFrame.new(0, y + h / 2, 0), C.Lacquer)
			for i = 0, 3 do
				Build.deco(
					ctx.folder,
					"Porte",
					Vector3.new(size * 0.36, h * 0.6, 0.2),
					cf * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, y + h * 0.45, -size / 2 - 0.1),
					C.PaperLight,
					{
						Material = Enum.Material.Neon,
						Transparency = 0.3,
					}
				)
			end
			y += h
			Kit.eave(ctx.folder, cf * CFrame.new(0, y, 0), size, 2.2, 1.6)
			y += 1.6
		end
		local spire = Build.part(ctx.folder, "Fleche", Vector3.new(0.5, 6, 0.5), cf * CFrame.new(0, y + 3, 0), C.Gold, { Material = Enum.Material.Metal })
		for k = 0, 3 do
			Build.deco(ctx.folder, "Anneau", Vector3.new(1.3, 0.25, 1.3), cf * CFrame.new(0, y + 1 + k * 1.1, 0), C.Gold, { Material = Enum.Material.Metal })
		end
		local _ = spire
	end,
}

S.horloge = {
	pad = { -16, 44 },
	build = function(ctx)
		local base = ctx.at(-16, 0, 53)
		Build.part(ctx.folder, "Socle", Vector3.new(8, 2, 8), base * CFrame.new(0, 1, 0), C.StoneMid, { Material = Enum.Material.Cobblestone })
		Build.part(ctx.folder, "Tour", Vector3.new(6, 16, 6), base * CFrame.new(0, 10, 0), C.Plaster, { Material = Enum.Material.Plaster })
		for _, x in { -3, 3 } do
			for _, z in { -3, 3 } do
				Build.part(ctx.folder, "Arete", Vector3.new(0.7, 16, 0.7), base * CFrame.new(x, 10, z), C.WoodDark, { Material = Enum.Material.Wood })
			end
		end
		Kit.eave(ctx.folder, base * CFrame.new(0, 18, 0), 6, 1.6, 1.4)
		Build.part(ctx.folder, "Cabine", Vector3.new(5, 4, 5), base * CFrame.new(0, 21.4, 0), C.Plaster, { Material = Enum.Material.Plaster })
		Kit.roof(ctx.folder, base * CFrame.new(0, 23.4, 0), 7.6, 7.6, 3, C.RoofTile, { ornament = true })
		Kit.cylinder(ctx.folder, "Cadran", 0.3, 4.4, base * CFrame.new(0, 21.4, -2.6) * CFrame.Angles(math.rad(90), 0, 0), rgb(250, 245, 230), { CanCollide = false })
		Kit.cylinder(
			ctx.folder,
			"Bord",
			0.25,
			4.9,
			base * CFrame.new(0, 21.4, -2.55) * CFrame.Angles(math.rad(90), 0, 0),
			C.Gold,
			{ Material = Enum.Material.Metal, CanCollide = false }
		)
		local hand = Build.deco(ctx.folder, "Aiguille", Vector3.new(0.25, 1.8, 0.2), base * CFrame.new(0, 21.9, -2.85), rgb(30, 30, 30))
		spin(hand, "Z", 1.2)
		Build.deco(ctx.folder, "Aiguille2", Vector3.new(0.3, 1.2, 0.2), base * CFrame.new(0.4, 21.4, -2.85) * CFrame.Angles(0, 0, math.rad(-70)), rgb(30, 30, 30))
	end,
}

S.jardin = {
	pad = { 37, 15 },
	build = function(ctx)
		local rng = ctx.rng
		local center = ctx.at(50, 0, 15)
		Build.part(ctx.folder, "Pelouse", Vector3.new(20, 0.5, 20), center * CFrame.new(0, 0.25, 0), C.Grass, { Material = Enum.Material.Grass })
		Kit.blob(ctx.folder, "Etang", Vector3.new(13, 0.5, 8), center * CFrame.new(0, 0.52, 1), C.Water, { Material = Enum.Material.Glass, Transparency = 0.15 })
		Kit.blob(ctx.folder, "Berge", Vector3.new(14.5, 0.4, 9.5), center * CFrame.new(0, 0.42, 1), C.StoneMid, { Material = Enum.Material.Pebble })
		for i = -3, 3 do
			local x = i * 1.05
			local y = 1.4 + math.cos(i / 3 * math.pi / 2) * 1.4
			Build.part(ctx.folder, "Pont", Vector3.new(1.1, 0.4, 3.2), center * CFrame.new(x, y, 1) * CFrame.Angles(0, 0, -math.sin(i / 3 * math.pi / 2) * 0.5), C.Lacquer)
			if i % 2 == 0 then
				for _, z in { -1.5, 1.5 } do
					Build.part(ctx.folder, "Rambarde", Vector3.new(0.3, 1.5, 0.3), center * CFrame.new(x, y + 0.85, 1 + z), C.Lacquer)
				end
			end
		end
		for _, z in { -0.5, 2.5 } do
			Build.part(ctx.folder, "MainCourante", Vector3.new(7.4, 0.3, 0.3), center * CFrame.new(0, 3.6, z), C.Lacquer)
		end
		for _ = 1, 5 do
			Kit.cylinder(
				ctx.folder,
				"Nenuphar",
				0.1,
				rng:NextNumber(0.9, 1.4),
				center * CFrame.new(rng:NextNumber(-5, 5), 0.8, 1 + rng:NextNumber(-2.5, 2.5)),
				rgb(90, 170, 80),
				{ CanCollide = false }
			)
		end
		Kit.sakura(ctx.folder, (center * CFrame.new(-6.5, 0.5, -6.5)).Position, 1, rng)
		Kit.sakura(ctx.folder, (center * CFrame.new(6.5, 0.5, -6.5)).Position, 0.9, rng, rgb(255, 160, 196))
		Kit.sakura(ctx.folder, (center * CFrame.new(6.5, 0.5, 7)).Position, 1.1, rng)
		Kit.niwaki(ctx.folder, (center * CFrame.new(-7, 0.5, 7)).Position, 0.9, rng)
		for _, p in { { -8.5, 0 }, { 8.5, 1 }, { -2, 8 }, { 2, -7.5 } } do
			Kit.boulder(ctx.folder, (center * CFrame.new(p[1], 0.5, p[2])).Position, 0.8, rng)
		end
	end,
}

S.dojo = {
	pad = { -34, 22 },
	build = function(ctx)
		local cf = ctx.at(-49.5, 0, 25)
		local w, d = 20, 13
		Build.part(ctx.folder, "Soubassement", Vector3.new(w + 2, 1.6, d + 2), cf * CFrame.new(0, 0.8, 0), C.StoneMid, { Material = Enum.Material.Cobblestone })
		Build.part(ctx.folder, "Engawa", Vector3.new(w + 2.6, 0.5, d + 2.6), cf * CFrame.new(0, 1.85, 0), C.Wood, { Material = Enum.Material.WoodPlanks })
		Build.part(ctx.folder, "Murs", Vector3.new(w, 8, d), cf * CFrame.new(0, 6.1, 0), C.Plaster, { Material = Enum.Material.Plaster })
		for i = 0, 5 do
			local x = -w / 2 + w * i / 5
			Build.deco(ctx.folder, "Poteau", Vector3.new(0.8, 8, d + 0.3), cf * CFrame.new(x, 6.1, 0), C.WoodDark, { Material = Enum.Material.Wood })
			if i < 5 and i ~= 2 then
				Build.deco(ctx.folder, "Shoji", Vector3.new(w / 5 - 1.2, 5.6, 0.2), cf * CFrame.new(x + w / 10, 5.2, -d / 2 - 0.12), C.PaperLight, {
					Material = Enum.Material.Neon,
					Transparency = 0.25,
				})
				for k = 1, 2 do
					Build.deco(
						ctx.folder,
						"Croisillon",
						Vector3.new(w / 5 - 1.2, 0.18, 0.25),
						cf * CFrame.new(x + w / 10, 2.4 + k * 1.9, -d / 2 - 0.14),
						C.WoodDark,
						{ Material = Enum.Material.Wood }
					)
				end
			end
		end
		Build.deco(ctx.folder, "Porte", Vector3.new(w / 5 - 1.2, 6.2, 0.2), cf * CFrame.new(0, 5, -d / 2 - 0.12), rgb(40, 30, 28))
		Build.deco(ctx.folder, "Poutre", Vector3.new(w + 0.6, 0.8, d + 0.6), cf * CFrame.new(0, 10.2, 0), C.WoodDark, { Material = Enum.Material.Wood })
		Kit.roof(ctx.folder, cf * CFrame.new(0, 10.5, 0), w + 5, d + 6, 4, C.RoofTile, { name = "ToitDojo" })
		Build.part(ctx.folder, "Pignon", Vector3.new(w * 0.45, 3, d * 0.5), cf * CFrame.new(0, 15.4, 0), C.Plaster, { Material = Enum.Material.Plaster })
		Kit.roof(ctx.folder, cf * CFrame.new(0, 16.8, 0), w * 0.55, d * 0.75, 2.6, C.RoofTile, { ornament = true, name = "ToitDojoHaut" })
		for i = 0, 2 do
			Build.part(ctx.folder, "Marche", Vector3.new(5, 0.6, 1.3), cf * CFrame.new(0, 0.3 + i * 0.6, -d / 2 - 3.6 + i * 1.1), C.StoneLight, { Material = Enum.Material.Slate })
		end
		local sign = Build.part(ctx.folder, "Enseigne", Vector3.new(7, 2.2, 0.4), cf * CFrame.new(0, 12.2, -d / 2 - 2.1), rgb(30, 25, 25), { Material = Enum.Material.Wood })
		if not ctx.ghost then
			Build.surfaceText(sign, Enum.NormalId.Front, "道場 DOJO", C.Gold)
			for _, side in { -1, 1 } do
				Kit.paperLantern(ctx.folder, cf * CFrame.new(side * (w / 2 - 1), 8.6, -d / 2 - 1.6), C.PaperLight, 1)
			end
		end
	end,
}

S.arene2 = { -- gradins derrière la cour
	pad = { 0, -16 },
	build = function(ctx)
		local z0 = Spots.court.z1 + 1
		for step = 0, 3 do
			local h = 0.8 + step * 0.9
			Build.part(
				ctx.folder,
				"Gradin",
				Vector3.new(36, h, 1.7),
				ctx.at(0, h / 2, z0 + 0.85 + step * 1.7),
				C.WoodLight:Lerp(C.Wood, step * 0.25),
				{ Material = Enum.Material.WoodPlanks }
			)
		end
		for _, side in { -1, 1 } do
			Build.part(ctx.folder, "Joue", Vector3.new(1, 4.4, 7), ctx.at(side * 18.5, 2.2, z0 + 3.4), C.WoodDark, { Material = Enum.Material.Wood })
			for i = 0, 1 do
				local x = side * (8 + i * 8)
				Build.part(ctx.folder, "Perche", Vector3.new(0.4, 8, 0.4), ctx.at(x, 4, z0 + 7), C.WoodDark, { Material = Enum.Material.Wood })
				if not ctx.ghost then
					Kit.paperLantern(ctx.folder, ctx.at(x, 8.6, z0 + 7), i == 0 and C.Lacquer or rgb(255, 205, 80), 1)
				end
			end
		end
		-- Bannière « COUR DES CHAMPIONS ».
		local banner = Build.part(ctx.folder, "Banniere", Vector3.new(20, 2.4, 0.3), ctx.at(0, 7.2, z0 + 7.1), C.Lacquer, { Material = Enum.Material.Fabric })
		if not ctx.ghost then
			Build.surfaceText(banner, Enum.NormalId.Front, "COUR DES CHAMPIONS", C.Gold)
		end
	end,
}

S.coffre = { -- « Coffre du Shogun »
	pad = { -55, -46.5 },
	build = function(ctx)
		local base = ctx.at(-55, 0, -56)
		Build.part(ctx.folder, "Estrade", Vector3.new(9, 1, 6.6), base * CFrame.new(0, 0.5, 0), C.StoneMid, { Material = Enum.Material.Slate })
		Build.part(ctx.folder, "Coffre", Vector3.new(7, 4, 4.6), base * CFrame.new(0, 3, 0), C.LacquerDark, { Material = Enum.Material.SmoothPlastic })
		Build.part(ctx.folder, "Couvercle", Vector3.new(7.3, 1.4, 4.9), base * CFrame.new(0, 5.7, 0), rgb(30, 25, 25), { Material = Enum.Material.SmoothPlastic })
		for _, x in { -2.6, 0, 2.6 } do
			Build.deco(ctx.folder, "Bande", Vector3.new(0.5, 5.5, 5), base * CFrame.new(x, 3.8, 0), C.Gold, { Material = Enum.Material.Metal })
		end
		Build.deco(
			ctx.folder,
			"Embleme",
			Vector3.new(1.6, 1.6, 0.3),
			base * CFrame.new(0, 3.2, -2.45) * CFrame.Angles(0, 0, math.rad(45)),
			C.Gold,
			{ Material = Enum.Material.Neon }
		)
		for i = 1, 8 do
			Kit.coin(ctx.folder, base * CFrame.new(-3 + i * 0.7, 6.55 + (i % 3) * 0.25, -1 + (i % 2)) * CFrame.Angles(0.3 * (i % 3), 0, 0.2), 1.3)
		end
	end,
}

S.tour = { -- « Tours de Guet » (yagura dans l'angle du fond)
	pad = { 50, 37 },
	build = function(ctx)
		local cf = ctx.at(53, 0, 53)
		Build.part(ctx.folder, "Base", Vector3.new(13, 5, 13), cf * CFrame.new(0, 2.5, 0), C.StoneMid, { Material = Enum.Material.Cobblestone })
		Build.part(ctx.folder, "Base2", Vector3.new(11.5, 3, 11.5), cf * CFrame.new(0, 6.5, 0), C.StoneMid:Lerp(C.StoneDark, 0.2), { Material = Enum.Material.Cobblestone })
		local y = 8
		for tier, size in { 10, 8, 6.4 } do
			local h = tier == 1 and 6 or 5
			Build.part(ctx.folder, "Etage", Vector3.new(size, h, size), cf * CFrame.new(0, y + h / 2, 0), C.Plaster, { Material = Enum.Material.Plaster })
			for _, x in { -size / 2, size / 2 } do
				for _, z in { -size / 2, size / 2 } do
					Build.deco(ctx.folder, "Arete", Vector3.new(0.6, h, 0.6), cf * CFrame.new(x, y + h / 2, z), C.WoodDark, { Material = Enum.Material.Wood })
				end
			end
			for i = 0, 3 do
				Build.deco(
					ctx.folder,
					"Fenetre",
					Vector3.new(size * 0.35, 1.2, 0.2),
					cf * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, y + h * 0.6, -size / 2 - 0.1),
					rgb(40, 30, 28),
					{ Material = Enum.Material.Wood }
				)
			end
			y += h
			Kit.eave(ctx.folder, cf * CFrame.new(0, y, 0), size, 2.2, 1.6)
			y += 1.6
		end
		Kit.roof(ctx.folder, cf * CFrame.new(0, y, 0), 7.4, 7.4, 3.2, C.RoofTile, { ornament = true })
		local beacon = Build.deco(ctx.folder, "Fanal", Vector3.new(1.4, 1.4, 1.4), cf * CFrame.new(0, y + 4.4, 0), rgb(255, 210, 90), { Material = Enum.Material.Neon })
		if not ctx.ghost then
			Kit.light(beacon, rgb(255, 210, 90), 30, 2)
		end
	end,
}

-- Palier 3 -------------------------------------------------------------

S.autel4 = {
	pad = { -23, 37 },
	build = function(ctx)
		pedestalPreview(ctx, 4)
	end,
}

S.equipe5 = {
	pad = { 29, -16 },
	build = function(ctx)
		teamBanners(ctx, 1, rgb(230, 60, 90))
	end,
}

S.statue = {
	pad = { 24, -56 },
	build = function(ctx)
		local base = ctx.at(22, 0, -46)
		Build.part(ctx.folder, "Socle", Vector3.new(9, 1, 9), base * CFrame.new(0, 0.5, 0), C.StoneMid, { Material = Enum.Material.Marble })
		Build.part(ctx.folder, "Piedestal", Vector3.new(6.5, 3, 6.5), base * CFrame.new(0, 2.5, 0), C.Marble, { Material = Enum.Material.Marble })
		Build.part(ctx.folder, "Corniche", Vector3.new(7.2, 0.6, 7.2), base * CFrame.new(0, 4.3, 0), C.Gold, { Material = Enum.Material.Metal })
		local look = ctx.bestLook
		if look and not ctx.ghost then
			local statue = CharacterBuilder.build(look, { scale = 1.8, name = "StatueDoree" })
			for _, part in statue:GetDescendants() do
				if part:IsA("SurfaceGui") or part:IsA("Decal") then
					part:Destroy()
				elseif part:IsA("BasePart") then
					part.Anchored = true
					part.Color = rgb(255, 200, 60):Lerp(part.Color, 0.15)
					part.Material = Enum.Material.Metal
					part.Reflectance = 0.15
					part.CanCollide = false
				end
			end
			statue:PivotTo(base * CFrame.new(0, 4.6 + CharacterBuilder.RootHeight * 1.8, 0))
			statue.Parent = ctx.folder
		else
			Kit.blob(ctx.folder, "Silhouette", Vector3.new(3, 8, 2), base * CFrame.new(0, 8.6, 0), rgb(255, 200, 60), { Material = Enum.Material.Metal })
		end
	end,
}

S.sablier = {
	pad = { 7, 55 },
	build = function(ctx)
		local base = ctx.at(-6, 0, 56)
		Build.part(ctx.folder, "Estrade", Vector3.new(7, 1, 7), base * CFrame.new(0, 0.5, 0), C.Marble, { Material = Enum.Material.Marble })
		Kit.cylinder(ctx.folder, "Base", 0.8, 5, base * CFrame.new(0, 1.4, 0), C.Gold, { Material = Enum.Material.Metal })
		Kit.cylinder(ctx.folder, "Haut", 0.8, 5, base * CFrame.new(0, 10.6, 0), C.Gold, { Material = Enum.Material.Metal })
		for i = 0, 2 do
			local a = i * math.pi * 2 / 3
			Build.part(ctx.folder, "Tige", Vector3.new(0.45, 8.6, 0.45), base * CFrame.new(math.cos(a) * 2.1, 6, math.sin(a) * 2.1), C.Gold, { Material = Enum.Material.Metal })
		end
		Kit.blob(ctx.folder, "VerreHaut", Vector3.new(3.2, 4, 3.2), base * CFrame.new(0, 8.2, 0), rgb(200, 240, 255), { Material = Enum.Material.Glass, Transparency = 0.5 })
		Kit.blob(ctx.folder, "VerreBas", Vector3.new(3.2, 4, 3.2), base * CFrame.new(0, 3.8, 0), rgb(200, 240, 255), { Material = Enum.Material.Glass, Transparency = 0.5 })
		Kit.blob(ctx.folder, "Sable", Vector3.new(2.4, 1.6, 2.4), base * CFrame.new(0, 2.9, 0), rgb(255, 210, 120), { Material = Enum.Material.Neon })
		Build.deco(ctx.folder, "Filet", Vector3.new(0.25, 3.4, 0.25), base * CFrame.new(0, 5.6, 0), rgb(255, 220, 140), { Material = Enum.Material.Neon })
	end,
}

S.sanctuaire = {
	pad = { 30, 36 },
	build = function(ctx)
		local cf = ctx.at(28, 0, 50)
		local w, d = 24, 12
		for i = 0, 2 do
			Build.part(
				ctx.folder,
				"Terrasse",
				Vector3.new(w + 8 - i * 2.4, 1, d + 6 - i * 1.6),
				cf * CFrame.new(0, 0.5 + i, -0.4 + i * 0.3),
				C.Marble:Lerp(C.StoneMid, 0.2 - i * 0.08),
				{
					Material = Enum.Material.Marble,
				}
			)
		end
		local floorY = 3
		for i = 0, 6 do
			for _, z in { -d / 2, d / 2 } do
				Build.part(ctx.folder, "Pilier", Vector3.new(1.3, 10, 1.3), cf * CFrame.new(-w / 2 + w * i / 6, floorY + 5, z), C.Lacquer)
			end
		end
		Build.part(ctx.folder, "Murs", Vector3.new(w - 2, 8.4, d - 2), cf * CFrame.new(0, floorY + 4.2, 0.4), C.Plaster, { Material = Enum.Material.Plaster })
		Build.deco(ctx.folder, "Porte", Vector3.new(5, 6.4, 0.2), cf * CFrame.new(0, floorY + 3.2, -d / 2 + 1.3), C.Gold, { Material = Enum.Material.Neon, Transparency = 0.2 })
		Build.part(ctx.folder, "Poutre", Vector3.new(w + 2, 1.1, d + 2), cf * CFrame.new(0, floorY + 10.5, 0), C.Lacquer)
		Build.deco(ctx.folder, "Frise", Vector3.new(w + 2.2, 0.5, d + 2.2), cf * CFrame.new(0, floorY + 9.9, 0), C.Gold, { Material = Enum.Material.Metal })
		Kit.roof(ctx.folder, cf * CFrame.new(0, floorY + 11, 0), w + 7, d + 8, 4.6, C.RoofTile, { ornament = true, name = "ToitSanctuaire" })
		Build.part(ctx.folder, "Etage", Vector3.new(w * 0.5, 3.6, d * 0.55), cf * CFrame.new(0, floorY + 17.2, 0), C.Lacquer)
		Kit.roof(ctx.folder, cf * CFrame.new(0, floorY + 19, 0), w * 0.6, d * 0.85, 3.4, C.RoofTile, { ornament = true, name = "ToitSanctuaireHaut" })
		local orb =
			Build.ball(ctx.folder, "JoyauCeleste", 3.6, (cf * CFrame.new(0, floorY + 27, 0)).Position, rgb(255, 230, 120), { Material = Enum.Material.Neon, CanCollide = false })
		orb:SetAttribute("Bob", 1)
		CollectionService:AddTag(orb, "Spin")
		if not ctx.ghost then
			Kit.light(orb, rgb(255, 220, 120), 40, 2)
		end
		for _, side in { -1, 1 } do
			guardian(ctx.folder, cf * CFrame.new(side * 6, 3, -d / 2 - 3.2), 0.85)
		end
	end,
}

Structures.List = S

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

-- Position locale du bouton d'une amélioration (Vector3, au sol).
function Structures.padPosition(upgradeId: string): Vector3?
	local def = S[upgradeId]
	if not def then
		return nil
	end
	return Vector3.new(def.pad[1], 0, def.pad[2])
end

-- Construit la structure `upgradeId` dans un nouveau modèle sous `parent`.
function Structures.build(upgradeId: string, plot, parent: Instance, options: { [string]: any }?): Model?
	local def = S[upgradeId]
	if not def then
		return nil
	end
	local o = options or {}
	local model = Build.model(parent, upgradeId)
	local seed = 0
	for i = 1, #upgradeId do
		seed += string.byte(upgradeId, i) * i
	end
	local ctx = {
		plot = plot,
		folder = model,
		rng = Random.new(seed + plot.index * 1000),
		bestLook = o.bestLook,
		ghost = o.ghost == true,
		coinPaths = o.coinPaths,
		at = function(x: number, y: number, z: number, yaw: number?): CFrame
			return plot.cf * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
		end,
	}
	def.build(ctx)
	return model
end

return Structures
