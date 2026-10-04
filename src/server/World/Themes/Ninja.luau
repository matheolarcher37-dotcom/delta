-- Décor de l'univers VILLAGE NINJA (inspiré de Naruto), sur TOUTE la carte, en taille réelle :
--   * dans l'anneau, le village : tour ronde rouge du chef (火), académie avec sa balançoire,
--     maisons rondes et immeubles crème à fenêtres encadrées, balcons, volets, climatiseurs,
--     réservoirs d'eau sur pieds avec tuyaux, enseignes verticales, linge qui sèche ; stand de
--     ramen, rue marchande à étals et bannières ; poteaux électriques et câbles, guirlandes de
--     lanternes au-dessus des rues, lanternes de pierre ; terrain d'entraînement, arbres géants ;
--   * la grande porte du village (« あ » « ん ») avec son poste de garde, sur la route de la base 270° ;
--   * sur l'île : la forêt d'arbres géants en bosquets, clairières d'entraînement, petit sanctuaire ;
--   * au bord de l'île : la montagne des chefs avec 5 visages sculptés dans la falaise ;
--   * à l'horizon : une couronne de montagnes vertes. Feuilles qui tombent.
-- Les gros éléments sont des emplacements remplaçables (DecorSlot) : un modèle de la Boîte à
-- outils rangé dans ServerStorage > ModelesDeco sous le même nom les remplace au lancement.

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

local Ninja = {}

local rgb = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local WHITE = Color3.new(1, 1, 1)
local shade = Core.shade
local polar = Common.polar
local facing = Common.facing

local CREAM = rgb(234, 222, 198)
local CREAM_DARK = rgb(206, 190, 164)
local RED = rgb(184, 64, 48)
local RED_ROOF = rgb(194, 76, 54)
local TEAL_ROOF = rgb(62, 112, 106)
local ORANGE_ROOF = rgb(214, 128, 62)
local WOOD = rgb(140, 96, 62)
local WOOD_DARK = rgb(86, 58, 42)
local ROCK = rgb(170, 144, 112)
local ROCK_LIGHT = rgb(192, 168, 134)
local ROCK_DARK = rgb(116, 96, 76)

local TOP_RING = Common.TOP_RING
local TOP_PLAZA = Common.TOP_PLAZA

local SIGNS = { "茶", "宿", "酒", "薬", "本", "花", "団子", "武具" }

------------------------------------------------------------------------
-- Bâtiments du village
------------------------------------------------------------------------

-- Maison cylindrique du village : socle, murs crème, bandeaux d'étage, fenêtres encadrées tout
-- autour, porte à auvent, toit en dôme à débord, réservoir d'eau et climatiseur.
local function roundHouse(parent: Instance, cf: CFrame, diameter: number, floors: number, roof: Color3, rng: Random): Model
	local floorH = 10
	local height = floors * floorH
	local model = Core.slot(parent, "MaisonRonde", cf, height + diameter * 0.3)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	Core.vcyl(model, "Plinth", cf, 1, diameter + 2, rgb(150, 144, 134), Enum.Material.Cobblestone)
	Core.vcyl(model, "Walls", cf * CFrame.new(0, 1, 0), height, diameter, CREAM, Enum.Material.Plaster)
	local count = math.max(5, math.floor(diameter / 3.4))
	for f = 1, floors do
		local y = 1 + (f - 1) * floorH
		if f > 1 then
			Core.vcyl(model, "FloorBand", cf * CFrame.new(0, y - 0.5, 0), 1, diameter + 0.6, shade(roof, -0.1), Enum.Material.SmoothPlastic, false)
		end
		for i = 0, count - 1 do
			local a = (i + 0.5) / count * math.pi * 2
			local front = math.abs(((a + math.pi) % (math.pi * 2)) - math.pi) < 0.45
			if not (f == 1 and front) then
				local wcf = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, y + 5.4, -diameter / 2 - 0.05)
				Archi.window(model, wcf, 2.4, 3, {
					frame = WOOD_DARK,
					shutters = (f > 1 and rng:NextNumber() < 0.35) and shade(roof, -0.05) or nil,
					bars = true,
				})
			end
		end
	end
	Archi.door(model, cf * CFrame.new(0, 1, -diameter / 2 - 0.05), 4.2, 7.5, { awning = roof, color = WOOD, lamp = rgb(255, 196, 120) })
	-- toit : débord, dôme aplati, petite lanterne de faîte
	Core.vcyl(model, "RoofRim", cf * CFrame.new(0, 1 + height, 0), 1.2, diameter + 3.2, shade(roof, -0.18), Enum.Material.SmoothPlastic)
	Core.vcyl(model, "RoofRim2", cf * CFrame.new(0, 2.2 + height, 0), 0.6, diameter + 2, shade(roof, -0.05), Enum.Material.SmoothPlastic, false)
	Core.ellipsoid(model, "RoofDome", Vector3.new(diameter + 1.6, diameter * 0.44, diameter + 1.6), cf * CFrame.new(0, 2.4 + height, 0), roof, Enum.Material.ClayRoofTiles)
	if rng:NextNumber() < 0.65 then
		Archi.waterTank(model, cf * CFrame.new(diameter * 0.14, 1.4 + height + diameter * 0.17, diameter * 0.1), 0.8)
	end
	if rng:NextNumber() < 0.6 then
		local a = rng:NextNumber(0.8, 2.3) * (rng:NextNumber() < 0.5 and -1 or 1)
		Archi.acUnit(model, cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 1 + floorH * 0.8, -diameter / 2))
	end
	return model
end

-- Immeuble carré : murs crème, bandeau coloré, fenêtres encadrées, balcon, auvent, toit-terrasse
-- avec parapet, réservoir d'eau, antenne, climatiseurs et enseigne verticale.
local function boxHouse(parent: Instance, cf: CFrame, size: Vector3, accent: Color3, rng: Random): Model
	local model = Core.slot(parent, "Immeuble", cf, size.Y + 8)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	local hx, hz = size.X / 2, size.Z / 2
	Archi.plinth(model, cf, size.X + 2, size.Z + 2, 1, rgb(150, 144, 134))
	local base = cf * CFrame.new(0, 1, 0)
	Archi.walls(model, base, size.X, size.Z, size.Y, CREAM, { band = accent })
	Archi.block(model, "Parapet", Vector3.new(size.X + 0.8, 1.4, size.Z + 0.8), base * CFrame.new(0, size.Y, 0), CREAM_DARK, Enum.Material.Concrete)
	Archi.block(model, "Roof", Vector3.new(size.X - 0.4, 0.3, size.Z - 0.4), base * CFrame.new(0, size.Y + 0.9, 0), rgb(146, 136, 124), Enum.Material.Concrete, false)
	local floors = math.max(1, math.floor(size.Y / 9.5))
	for f = 0, floors - 1 do
		local y = 5.4 + f * 9.5
		local cols = math.max(1, math.floor(size.X / 6))
		Archi.windowRow(model, base * CFrame.new(0, y, -hz - 0.05), size.X, cols, 2.6, 3.2, { frame = WOOD_DARK, bars = true, box = (f == 0) and rgb(230, 90, 110) or nil }, function(x)
			return f == 0 and math.abs(x) < 3.5
		end)
		local rows = math.max(1, math.floor(size.Z / 6.5))
		for _, side in { -1, 1 } do
			local scf = base * CFrame.new(side * (hx + 0.05), y, 0) * CFrame.Angles(0, side * math.pi / 2, 0)
			Archi.windowRow(model, scf, size.Z, rows, 2.4, 3.2, { frame = WOOD_DARK, shutters = rng:NextNumber() < 0.4 and accent or nil })
		end
	end
	Archi.door(model, base * CFrame.new(0, 0, -hz - 0.05), 4.4, 7.6, { awning = accent, color = WOOD })
	if floors >= 2 then
		Archi.balcony(model, base * CFrame.new(rng:NextNumber(-hx * 0.3, hx * 0.3), 9.5, -hz), math.min(size.X - 3, 10), 3, WOOD_DARK)
	end
	Archi.acUnit(model, base * CFrame.new(hx * 0.55, 4.2, -hz))
	if size.Y > 12 then
		Archi.acUnit(model, base * CFrame.new(hx + 0.05, size.Y * 0.6, hz * 0.3) * CFrame.Angles(0, math.pi / 2, 0))
	end
	if rng:NextNumber() < 0.75 then
		Archi.waterTank(model, base * CFrame.new(-hx * 0.35, size.Y + 1, hz * 0.15), 0.9)
	end
	-- antenne
	local mast = (base * CFrame.new(hx * 0.6, size.Y + 1, hz * 0.5)).Position
	Build.deco(model, "Antenna", Vector3.new(0.2, 5, 0.2), CFrame.new(mast + UP * 2.5), rgb(80, 80, 86), { Material = Enum.Material.Metal })
	Build.deco(model, "AntennaBar", Vector3.new(2.4, 0.15, 0.15), CFrame.new(mast + UP * 4.2), rgb(80, 80, 86), { Material = Enum.Material.Metal })
	if rng:NextNumber() < 0.55 then
		local text = SIGNS[rng:NextInteger(1, #SIGNS)]
		Archi.verticalSign(model, base * CFrame.new(hx + 0.9, size.Y * 0.55, -hz + 1.6), 6, text, shade(accent, -0.2))
	end
	return model
end

-- Maison de commerce en bois (machiya) : rez-de-chaussée ouvert à noren, étage à shoji,
-- toit de tuiles à deux pans avec chevrons, enseigne.
local function shopHouse(parent: Instance, cf: CFrame, w: number, d: number, color: Color3, text: string, rng: Random): Model
	local model = Core.slot(parent, "Boutique", cf, 20)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	Archi.plinth(model, cf, w + 1.5, d + 1.5, 0.8, rgb(146, 140, 130))
	local base = cf * CFrame.new(0, 0.8, 0)
	Archi.walls(model, base, w, d, 8.5, rgb(226, 214, 192), { frame = WOOD_DARK, spacing = 5, base = WOOD, baseHeight = 2 })
	Archi.door(model, base * CFrame.new(0, 0, -d / 2 - 0.05), 5, 6.6, { sliding = true, noren = color, norenText = text, step = true })
	for _, x in { -w / 2 + 2.6, w / 2 - 2.6 } do
		Archi.window(model, base * CFrame.new(x, 3.8, -d / 2 - 0.05), 2.4, 2.6, { shoji = true, frame = WOOD_DARK, lit = rng:NextNumber() < 0.3 })
	end
	-- étage en retrait
	local up = base * CFrame.new(0, 8.5, 1)
	Archi.gableRoof(model, base * CFrame.new(0, 8.5, 0), w, d, 2.2, 1.6, shade(TEAL_ROOF, -0.1), { rafters = WOOD_DARK, material = Enum.Material.ClayRoofTiles })
	Archi.walls(model, up * CFrame.new(0, 1.4, 0), w - 2, d - 3, 6, rgb(226, 214, 192), { frame = WOOD_DARK, spacing = 4.5 })
	Archi.windowRow(model, up * CFrame.new(0, 4.4, -(d - 3) / 2 - 0.05), w - 2, 2, 3, 2.6, { shoji = true, frame = WOOD_DARK })
	Archi.gableRoof(model, up * CFrame.new(0, 7.4, 0), w - 2, d - 3, 3.6, 2, TEAL_ROOF, { rafters = WOOD_DARK, upturn = true, trim = WOOD_DARK, gableFill = rgb(226, 214, 192) })
	Archi.sign(model, base * CFrame.new(0, 9.6, -d / 2 - 1.4), w * 0.55, 1.8, text, { bg = rgb(60, 40, 30), text = rgb(255, 226, 160) })
	return model
end

-- Tour ronde rouge du chef du village, plaque « 火 », escalier, porche, terrasse sur le toit.
local function chiefTower(parent: Instance, cf: CFrame): Model
	local model = Core.slot(parent, "TourDuChef", cf, 60)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	local d1, d2 = 46, 40
	Core.vcyl(model, "Plinth", cf, 1.6, d1 + 8, rgb(160, 152, 140), Enum.Material.Cobblestone)
	Core.vcyl(model, "Level1", cf * CFrame.new(0, 1.6, 0), 22, d1, RED, Enum.Material.Plaster)
	Core.vcyl(model, "Band", cf * CFrame.new(0, 23.6, 0), 2.2, d1 + 1.6, CREAM, Enum.Material.SmoothPlastic)
	Core.vcyl(model, "Level2", cf * CFrame.new(0, 25.8, 0), 11, d2, RED, Enum.Material.Plaster)
	Core.vcyl(model, "RoofRim", cf * CFrame.new(0, 36.8, 0), 1.6, d1 + 4, rgb(104, 42, 34), Enum.Material.SmoothPlastic)
	Core.ellipsoid(model, "RoofDome", Vector3.new(d1, 14, d1), cf * CFrame.new(0, 38.4, 0), RED_ROOF, Enum.Material.ClayRoofTiles)
	Core.vcyl(model, "Lookout", cf * CFrame.new(0, 42, 0), 6, 12, CREAM, Enum.Material.Plaster)
	Core.ellipsoid(model, "LookoutRoof", Vector3.new(15, 5, 15), cf * CFrame.new(0, 48.4, 0), RED_ROOF, Enum.Material.ClayRoofTiles)
	Build.deco(model, "FlagPole", Vector3.new(0.4, 10, 0.4), cf * CFrame.new(0, 54, 0), rgb(80, 70, 60), { Material = Enum.Material.Metal })
	Build.deco(model, "Flag", Vector3.new(0.1, 3, 5), cf * CFrame.new(0, 57.4, 2.6), rgb(240, 120, 40), { Material = Enum.Material.Fabric })
	-- fenêtres encadrées sur trois étages
	for _, row in { { d1, 8.6, 16, true }, { d1, 17.2, 16, false }, { d2, 30.2, 14, true } } do
		local d, y, count, skipFront = row[1], row[2], row[3], row[4]
		for i = 0, count - 1 do
			local a = (i + 0.5) / count * math.pi * 2
			local front = math.abs(((a + math.pi) % (math.pi * 2)) - math.pi) < 0.35
			if not (skipFront and front) then
				Archi.window(model, cf * CFrame.Angles(0, a, 0) * CFrame.new(0, y, -d / 2 - 0.05), 2.6, 4, { frame = rgb(80, 30, 26), bars = true })
			end
		end
	end
	-- plaque blanche ronde « 火 »
	local plaqueCF = cf * CFrame.new(0, 30.8, -d2 / 2 - 0.6)
	local disc = Build.deco(model, "Plaque", Vector3.new(0.8, 9, 9), plaqueCF * CFrame.Angles(0, math.rad(90), 0), WHITE)
	disc.Shape = Enum.PartType.Cylinder
	Core.plaqueText(model, plaqueCF * CFrame.new(0, 0, -0.5), Vector2.new(7, 7), "火", RED)
	-- grande porte, porche à poteaux, escalier et lanternes
	local door = cf * CFrame.new(0, 1.6, -d1 / 2 - 0.05)
	Archi.door(model, door, 8, 10.5, { color = WOOD_DARK, step = false })
	Archi.gableRoof(model, door * CFrame.new(0, 12, -3.4), 16, 6, 2.4, 1.4, RED_ROOF, { rafters = WOOD_DARK, upturn = true, trim = rgb(90, 36, 30) })
	for _, side in { -1, 1 } do
		Archi.block(model, "PorchPost", Vector3.new(1, 12, 1), door * CFrame.new(side * 7, -0.2, -6), rgb(90, 36, 30), Enum.Material.Wood)
		Props.paperLantern(model, (door * CFrame.new(side * 7, 8.6, -6.9)).Position, rgb(255, 120, 60), 1.1)
	end
	Archi.stairs(model, cf * CFrame.new(0, 0, -d1 / 2 - 8), 14, 1.6, 4, 4, rgb(170, 162, 150))
	-- balustrade de la terrasse du 2e niveau
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		Build.deco(model, "Railing", Vector3.new(0.3, 2, 0.3), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 24.8 + 1, -d1 / 2 - 0.4), rgb(90, 36, 30), { Material = Enum.Material.Wood })
	end
	Core.vcyl(model, "RailTop", cf * CFrame.new(0, 26.9, 0), 0.3, d1 + 1.2, rgb(90, 36, 30), Enum.Material.Wood, false).Transparency = 0
	return model
end

-- Académie ninja : long bâtiment à deux étages, toit rouge, horloge, et l'arbre à la balançoire.
local function academy(parent: Instance, cf: CFrame, rng: Random): Model
	local model = Core.slot(parent, "Academie", cf, 28)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	local w, d = 46, 18
	Archi.plinth(model, cf, w + 2, d + 2, 1.2, rgb(150, 144, 134))
	local base = cf * CFrame.new(0, 1.2, 0)
	Archi.walls(model, base, w, d, 19, rgb(214, 160, 96), { band = RED, base = rgb(160, 110, 70), baseHeight = 1.6 })
	for f = 0, 1 do
		Archi.windowRow(model, base * CFrame.new(0, 5.4 + f * 9.4, -d / 2 - 0.05), w, 7, 3, 3.6, { frame = WOOD_DARK, bars = true }, function(x)
			return f == 0 and math.abs(x) < 4
		end)
	end
	Archi.door(model, base * CFrame.new(0, 0, -d / 2 - 0.05), 6, 8, { color = WOOD_DARK, awning = RED_ROOF })
	Archi.hipRoof(model, base * CFrame.new(0, 19, 0), w, d, 7, 2.6, RED_ROOF, { rafters = WOOD_DARK, trim = rgb(110, 40, 30) })
	-- horloge et emblème
	local clock = Build.deco(model, "Clock", Vector3.new(0.6, 4.4, 4.4), base * CFrame.new(0, 21.4, -d / 2 - 2.5) * CFrame.Angles(0, math.rad(90), 0), WHITE)
	clock.Shape = Enum.PartType.Cylinder
	Core.plaqueText(model, base * CFrame.new(0, 21.4, -d / 2 - 2.85) * CFrame.Angles(0, 0, 0), Vector2.new(3.4, 3.4), "忍", RED)
	Archi.sign(model, base * CFrame.new(0, 10.2, -d / 2 - 0.6), 14, 2, "ACADÉMIE NINJA", { bg = rgb(250, 240, 220), text = rgb(170, 50, 40), frame = WOOD_DARK })
	-- arbre à la balançoire
	local treePos = (cf * CFrame.new(w / 2 + 10, 0, -d / 2 - 6)).Position
	Nature.tree("ArbreFeuillu", model, treePos, { rng = rng, height = 28, detail = "normal", variant = 2 })
	local branch = treePos + UP * 10.4 + cf.RightVector * -3.4
	for _, z in { -1.1, 1.1 } do
		Build.deco(model, "SwingRope", Vector3.new(0.12, 6.4, 0.12), CFrame.new(branch + cf.LookVector * z - UP * 3.2), rgb(200, 180, 130), { Material = Enum.Material.Fabric })
	end
	Build.part(model, "Swing", Vector3.new(1.2, 0.3, 3), CFrame.lookAt(branch - UP * 6.5, branch - UP * 6.5 + cf.RightVector), WOOD, { Material = Enum.Material.WoodPlanks })
	return model
end

-- Stand de ramen : cuisine, comptoir et tabourets, noren « ラーメン », lanternes rouges, enseigne.
local function ramenStand(parent: Instance, cf: CFrame): Model
	local model = Core.slot(parent, "StandRamen", cf, 15)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	local w, d = 18, 11
	Build.part(model, "Floor", Vector3.new(w + 2, 0.6, d + 2), cf * CFrame.new(0, 0.3, 0), rgb(160, 152, 140), { Material = Enum.Material.Cobblestone })
	Archi.walls(model, cf * CFrame.new(0, 0.6, d / 2 - 2), w, 4, 10, CREAM, { frame = WOOD_DARK, spacing = 6 })
	Build.part(model, "Counter", Vector3.new(w - 2, 3.4, 2.4), cf * CFrame.new(0, 2.3, -1), WOOD, { Material = Enum.Material.WoodPlanks })
	Build.part(model, "CounterTop", Vector3.new(w - 1.4, 0.4, 3), cf * CFrame.new(0, 4.2, -1), rgb(184, 136, 90), { Material = Enum.Material.Wood })
	for i = -2, 2 do
		local stool = cf * CFrame.new(i * 3.2, 0.6, -4)
		Core.vcyl(model, "StoolLeg", stool, 2.2, 0.6, rgb(80, 80, 86), Enum.Material.Metal)
		Core.vcyl(model, "StoolSeat", stool * CFrame.new(0, 2.2, 0), 0.5, 2, RED, Enum.Material.SmoothPlastic)
		Core.ball(model, "Bowl", 1.1, (cf * CFrame.new(i * 3.2, 4.8, -1.2)).Position, rgb(250, 246, 236))
		Build.deco(model, "Noodles", Vector3.new(0.8, 0.1, 0.8), cf * CFrame.new(i * 3.2, 5.05, -1.2), rgb(240, 210, 130))
	end
	-- marmites fumantes
	for _, x in { -5, 5 } do
		local pot = Core.vcyl(model, "Pot", cf * CFrame.new(x, 4.4, 2.6), 1.6, 2.4, rgb(70, 72, 78), Enum.Material.Metal, false)
		local steam = Instance.new("ParticleEmitter")
		steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
		steam.Color = ColorSequence.new(rgb(250, 250, 250))
		steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
		steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.4) })
		steam.Lifetime = NumberRange.new(1.5, 2.5)
		steam.Rate = 6
		steam.Speed = NumberRange.new(2, 3)
		steam.EmissionDirection = Enum.NormalId.Top
		steam.Parent = pot
	end
	for _, side in { -1, 1 } do
		Build.part(model, "Post", Vector3.new(0.9, 11, 0.9), cf * CFrame.new(side * (w / 2 - 0.4), 6, -d / 2 + 0.5), WOOD_DARK, { Material = Enum.Material.Wood })
	end
	Archi.gableRoof(model, cf * CFrame.new(0, 11.4, 0), w, d, 3, 1.8, rgb(140, 50, 38), { rafters = WOOD_DARK, upturn = true, trim = WOOD_DARK })
	Build.part(model, "Beam", Vector3.new(w + 1, 0.9, 0.9), cf * CFrame.new(0, 10.8, -d / 2 + 0.5), WOOD_DARK, { Material = Enum.Material.Wood })
	-- noren blancs « ラーメン »
	local panels = 5
	for i = 0, panels - 1 do
		local x = -w / 2 + 1 + (i + 0.5) * (w - 2) / panels
		local panel = Build.deco(model, "Noren", Vector3.new((w - 2) / panels - 0.25, 3.4, 0.15), cf * CFrame.new(x, 8.6, -d / 2 + 0.3), rgb(248, 244, 236), {
			Material = Enum.Material.Fabric,
		})
		local text = ({ "🍜", "ン", "メ", "ー", "ラ" })[i + 1]
		Build.surfaceText(panel, Enum.NormalId.Front, text, RED, { TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
	end
	Archi.sign(model, cf * CFrame.new(0, 16.2, -d / 2 + 0.8) * CFrame.Angles(math.rad(-8), 0, 0), 12, 3, "RAMEN", { bg = rgb(120, 40, 32), text = rgb(255, 236, 190) })
	for _, side in { -1, 1 } do
		Props.paperLantern(model, (cf * CFrame.new(side * (w / 2 + 0.7), 8.4, -d / 2 + 0.5)).Position, rgb(255, 70, 50), 1.2)
	end
	Props.barrel(model, cf * CFrame.new(w / 2 + 2, 0, 2), 0.9)
	Props.crate(model, cf * CFrame.new(-w / 2 - 2.4, 0, 2.6), 2.4)
	return model
end

-- Grande porte du village à cheval sur la route, battants verts ouverts, rempart, poste de garde.
local function villageGate(parent: Instance, cf: CFrame): Model
	local model = Core.slot(parent, "PorteDuVillage", cf, 48)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	local frame = rgb(170, 74, 48)
	local opening = 28
	local h = 34
	for _, side in { -1, 1 } do
		local x = side * (opening / 2 + 3)
		Build.part(model, "Pillar", Vector3.new(6, h, 8), cf * CFrame.new(x, h / 2, 0), frame, { Material = Enum.Material.WoodPlanks })
		Build.part(model, "PillarBase", Vector3.new(7.4, 3, 9.4), cf * CFrame.new(x, 1.5, 0), rgb(146, 140, 130), { Material = Enum.Material.Cobblestone })
		for _, y in { 8, 18, 28 } do
			Build.deco(model, "PillarBand", Vector3.new(6.3, 0.8, 8.3), cf * CFrame.new(x, y, 0), rgb(110, 46, 32), { Material = Enum.Material.Wood })
		end
		-- battant ouvert vers l'intérieur, avec son caractère
		local hinge = cf * CFrame.new(side * opening / 2, 0, -4)
		local leaf = hinge * CFrame.Angles(0, side * math.rad(-80), 0) * CFrame.new(-side * opening / 4, h * 0.42, 0)
		local door = Build.part(model, "DoorLeaf", Vector3.new(opening / 2, h * 0.84, 1.2), leaf, rgb(66, 124, 88), { Material = Enum.Material.WoodPlanks })
		Build.surfaceText(door, Enum.NormalId.Front, side < 0 and "あ" or "ん", rgb(196, 58, 40), { TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
		Build.surfaceText(door, Enum.NormalId.Back, side < 0 and "あ" or "ん", rgb(196, 58, 40), { TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
		-- rempart de part et d'autre (crépi orangé, chaperon de tuiles vertes)
		local wallLen = 34
		local wx = side * (opening / 2 + 6 + wallLen / 2)
		Build.part(model, "Rampart", Vector3.new(wallLen, 15, 4), cf * CFrame.new(wx, 7.5, 1), rgb(196, 112, 76), { Material = Enum.Material.Plaster })
		Archi.gableRoof(model, cf * CFrame.new(wx, 15, 1), wallLen, 4, 1.4, 1, TEAL_ROOF, { material = Enum.Material.ClayRoofTiles })
		Build.part(model, "RampartBase", Vector3.new(wallLen, 2.4, 5), cf * CFrame.new(wx, 1.2, 1), rgb(146, 140, 130), { Material = Enum.Material.Cobblestone })
	end
	Build.part(model, "Lintel", Vector3.new(opening + 16, 4, 9), cf * CFrame.new(0, h + 2, 0), frame, { Material = Enum.Material.WoodPlanks })
	Build.part(model, "Lintel2", Vector3.new(opening + 10, 2, 7), cf * CFrame.new(0, h - 4, 0), frame, { Material = Enum.Material.WoodPlanks })
	Archi.gableRoof(model, cf * CFrame.new(0, h + 4, 0), opening + 18, 9, 6, 3, TEAL_ROOF, { rafters = rgb(110, 46, 32), upturn = true, trim = rgb(40, 70, 66) })
	for _, z in { -4.6, 4.6 } do
		local plaque = Build.part(model, "Plaque", Vector3.new(9, 7, 0.6), cf * CFrame.new(0, h - 0.5, z), rgb(244, 232, 206), { CanCollide = false })
		Build.surfaceText(plaque, z < 0 and Enum.NormalId.Front or Enum.NormalId.Back, "忍", rgb(196, 50, 40), { TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
	end
	-- poste de garde (côté village)
	local booth = cf * CFrame.new(opening / 2 + 14, 0, -12)
	Archi.plinth(model, booth, 12, 8, 0.8)
	Archi.walls(model, booth * CFrame.new(0, 0.8, 1), 10, 5, 7, CREAM, { frame = WOOD_DARK, spacing = 5 })
	Build.part(model, "BoothCounter", Vector3.new(10, 3, 1.6), booth * CFrame.new(0, 2.3, -2.2), WOOD, { Material = Enum.Material.WoodPlanks })
	for _, x in { -4.6, 4.6 } do
		Build.part(model, "BoothPost", Vector3.new(0.6, 7, 0.6), booth * CFrame.new(x, 4.3, -2.8), WOOD_DARK, { Material = Enum.Material.Wood })
	end
	Archi.gableRoof(model, booth * CFrame.new(0, 7.8, -0.5), 10, 7, 2, 1.4, TEAL_ROOF, { upturn = true })
	Archi.sign(model, booth * CFrame.new(0, 6.6, -3.2), 6, 1.2, "受付", { bg = rgb(250, 244, 230), text = rgb(60, 40, 30) })
	for _, side in { -1, 1 } do
		Props.banner(model, (cf * CFrame.new(side * (opening / 2 + 7), 0, -9)).Position, 12, rgb(214, 96, 40), "忍")
	end
	return model
end

-- Montagne des chefs : falaise de roche avec 5 visages sculptés. `cf` = pied de la falaise,
-- -Z local vers le village. Largeur ≈ 460, hauteur ≈ 150.
local function chiefMountain(parent: Instance, cf: CFrame, rng: Random): Model
	local model = Core.slot(parent, "MontagneDesChefs", cf, 160)
	pcall(function()
		model.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	end)
	-- corps de la falaise : grands piliers de roche en strates, inclinés (silhouette irrégulière)
	local blocks = {
		{ -205, 118, 104, 0.06 },
		{ -128, 150, 112, -0.04 },
		{ -42, 160, 104, 0.03 },
		{ 44, 156, 110, -0.05 },
		{ 130, 142, 104, 0.04 },
		{ 210, 108, 90, -0.06 },
	}
	for i, b in blocks do
		local x, h, w, tilt = b[1], b[2], b[3], b[4]
		local layers = 4
		for l = 0, layers - 1 do
			local lh = h / layers
			local inset = l * 3
			Build.part(
				model,
				"Cliff",
				Vector3.new(w - l * 4 + rng:NextNumber(-4, 4), lh + 2, 150 - inset),
				cf * CFrame.new(x + rng:NextNumber(-3, 3), l * lh + lh / 2 - 2, 80 + inset / 2 + (i % 2) * 6) * CFrame.Angles(0, tilt + rng:NextNumber(-0.04, 0.04), tilt * 0.5),
				shade(ROCK, ((i + l) % 2 == 0 and 0.04 or -0.05) + rng:NextNumber(-0.03, 0.03)),
				{ Material = Enum.Material.Rock }
			)
		end
		-- sommet herbeux et bosquets
		Core.ellipsoid(model, "CliffTop", Vector3.new(w * 1.06, 40, 164), cf * CFrame.new(x, h - 8, 86), rgb(84, 132, 64), Enum.Material.Grass)
		Core.ellipsoid(model, "CliffTop", Vector3.new(w * 0.6, 26, 90), cf * CFrame.new(x + rng:NextNumber(-12, 12), h + 4, 104), rgb(98, 146, 74), Enum.Material.Grass)
		-- coulées de roche plus sombre (fissures verticales)
		for _ = 1, 2 do
			Build.deco(model, "Crack", Vector3.new(rng:NextNumber(2, 4), h * rng:NextNumber(0.3, 0.6), 2), cf * CFrame.new(x + rng:NextNumber(-w / 2.5, w / 2.5), h * rng:NextNumber(0.2, 0.45), 4.4), ROCK_DARK, {
				Material = Enum.Material.Rock,
			})
		end
	end
	for _ = 1, 16 do
		local x = rng:NextNumber(-220, 220)
		local top = 0
		for _, b in blocks do
			if math.abs(x - b[1]) < b[3] / 2 then
				top = math.max(top, b[2])
			end
		end
		if top > 0 then
			local species = rng:NextNumber() < 0.6 and "ArbreFeuillu" or "Sapin"
			Nature.tree(species, model, (cf * CFrame.new(x, top + 4, rng:NextNumber(60, 130))).Position, { rng = rng, height = rng:NextNumber(26, 36), palette = "foret", detail = "low" })
		end
	end
	-- éboulis au pied
	for _ = 1, 18 do
		Nature.rock(model, (cf * CFrame.new(rng:NextNumber(-230, 230), 0, rng:NextNumber(-14, 2))).Position, rng:NextNumber(6, 16), {
			rng = rng,
			color = ROCK_DARK,
			slot = "RocherFalaise",
			moss = rgb(84, 126, 62),
		})
	end
	-- les 5 visages (yeux, sourcils, nez, bouche, cheveux différents)
	local faces = { -168, -84, 0, 84, 168 }
	for i, x in faces do
		local head = cf * CFrame.new(x, 92 + (i == 3 and 6 or 0), -4)
		Core.ellipsoid(model, "Face", Vector3.new(40, 50, 22), head, ROCK_LIGHT, Enum.Material.Rock)
		Core.ellipsoid(model, "Jaw", Vector3.new(28, 20, 16), head * CFrame.new(0, -20, -2), ROCK_LIGHT, Enum.Material.Rock)
		for _, side in { -1, 1 } do
			local tilt = side * math.rad(i % 2 == 0 and 12 or -6)
			Build.part(model, "Brow", Vector3.new(13, 3.2, 5), head * CFrame.new(side * 9, 9, -9.5) * CFrame.Angles(0, 0, tilt), ROCK, { Material = Enum.Material.Rock })
			Core.ellipsoid(model, "Eye", Vector3.new(9, 4.2, 3), head * CFrame.new(side * 9, 4, -9.6), shade(ROCK, -0.08), Enum.Material.Rock)
			Build.part(model, "Pupil", Vector3.new(2.6, 2.6, 1.2), head * CFrame.new(side * 8.4, 3.8, -10.9), ROCK_DARK, { Material = Enum.Material.Rock })
			Build.part(model, "Cheek", Vector3.new(2, 8, 2), head * CFrame.new(side * 13, -8, -9) * CFrame.Angles(0, 0, side * 0.3), shade(ROCK, -0.1), { Material = Enum.Material.Rock })
			Build.part(model, "Ear", Vector3.new(4, 10, 6), head * CFrame.new(side * 20.5, 0, 0), shade(ROCK, -0.04), { Material = Enum.Material.Rock })
		end
		Build.wedge(model, "Nose", Vector3.new(6, 11, 6), head * CFrame.new(0, -3, -12) * CFrame.Angles(0, math.pi, 0), ROCK_LIGHT, { Material = Enum.Material.Rock })
		Build.part(model, "Mouth", Vector3.new(12, 1.6, 2), head * CFrame.new(0, -14, -10.5), shade(ROCK, -0.2), { Material = Enum.Material.Rock })
		if i == 1 then
			Core.ellipsoid(model, "Hair", Vector3.new(46, 24, 26), head * CFrame.new(0, 22, 2), ROCK, Enum.Material.Rock)
			for _, side in { -1, 1 } do
				Build.part(model, "HairSide", Vector3.new(9, 52, 14), head * CFrame.new(side * 22, -6, 4) * CFrame.Angles(0, 0, side * 0.06), ROCK, { Material = Enum.Material.Rock })
			end
		elseif i == 2 then
			for k = -2, 2 do
				Build.wedge(model, "Spike", Vector3.new(10, 14, 12), head * CFrame.new(k * 8, 26, 0) * CFrame.Angles(0, 0, k * 0.25), ROCK, { Material = Enum.Material.Rock })
			end
			Core.ellipsoid(model, "Hair", Vector3.new(42, 16, 24), head * CFrame.new(0, 20, 2), ROCK, Enum.Material.Rock)
		elseif i == 3 then
			Core.ellipsoid(model, "Hat", Vector3.new(60, 10, 30), head * CFrame.new(0, 22, 0), ROCK, Enum.Material.Rock)
			Core.ellipsoid(model, "HatTop", Vector3.new(30, 22, 22), head * CFrame.new(0, 30, 2), ROCK, Enum.Material.Rock)
			Build.part(model, "Beard", Vector3.new(14, 8, 4), head * CFrame.new(0, -27, -6), ROCK, { Material = Enum.Material.Rock })
		elseif i == 4 then
			for k = -3, 3 do
				local spike = head * CFrame.new(k * 7, 24 + (3 - math.abs(k)) * 1.5, -2) * CFrame.Angles(math.rad(-20), 0, k * 0.32)
				Build.wedge(model, "Spike", Vector3.new(8, 18, 10), spike * CFrame.Angles(0, math.pi, 0), ROCK, { Material = Enum.Material.Rock })
			end
			for _, side in { -1, 1 } do
				Build.wedge(model, "Bang", Vector3.new(8, 20, 8), head * CFrame.new(side * 19, 4, -4) * CFrame.Angles(0, 0, side * 0.2), ROCK, { Material = Enum.Material.Rock })
			end
		else
			Core.ellipsoid(model, "Hair", Vector3.new(44, 22, 24), head * CFrame.new(0, 21, 2), ROCK, Enum.Material.Rock)
			for _, side in { -1, 1 } do
				Core.ellipsoid(model, "Pigtail", Vector3.new(10, 40, 12), head * CFrame.new(side * 25, -12, 4), ROCK, Enum.Material.Rock)
			end
			Build.part(model, "Mark", Vector3.new(3, 3, 1), head * CFrame.new(0, 12, -11) * CFrame.Angles(0, 0, math.rad(45)), ROCK_DARK, { Material = Enum.Material.Rock })
		end
	end
	return model
end

-- Petit sanctuaire de forêt : torii, autel (hokora), lanternes, cordes sacrées.
local function forestShrine(parent: Instance, cf: CFrame)
	local model = Core.slot(parent, "Sanctuaire", cf, 14)
	Build.torii(model, cf * CFrame.new(0, 0, -10), 9, 10, rgb(196, 60, 40), rgb(40, 32, 30))
	Archi.plinth(model, cf, 7, 6, 1.4, rgb(150, 146, 140))
	Archi.walls(model, cf * CFrame.new(0, 1.4, 0), 4.4, 3.6, 4, WOOD, { frame = WOOD_DARK })
	Archi.gableRoof(model, cf * CFrame.new(0, 5.4, 0), 4.4, 3.6, 2, 1.2, rgb(60, 54, 60), { upturn = true })
	Build.deco(model, "Shimenawa", Vector3.new(5, 0.5, 0.5), cf * CFrame.new(0, 4.6, -2.1), rgb(230, 210, 150), { Material = Enum.Material.Fabric })
	for _, x in { -1, 0, 1 } do
		Build.deco(model, "Shide", Vector3.new(0.5, 1.2, 0.1), cf * CFrame.new(x * 1.4, 3.8, -2.2), WHITE, { Material = Enum.Material.Fabric })
	end
	for _, x in { -4.5, 4.5 } do
		Props.stoneLantern(model, (cf * CFrame.new(x, 0, -4)).Position, 0.7)
	end
end

------------------------------------------------------------------------
-- Construction du décor
------------------------------------------------------------------------

local MOUNTAIN_ANGLE = 270
local MOUNTAIN_RADIUS = 612

-- Les bâtiments du village : { angle, rayon, type, paramètres }.
local BUILDINGS = {
	{ 300, 303, "tower" },
	{ 283, 318, "box", Vector3.new(16, 20, 14), ORANGE_ROOF },
	{ 318, 318, "box", Vector3.new(18, 24, 14), RED },
	{ 257, 316, "ramen" },
	{ 244, 312, "round", 24, 2, RED_ROOF },
	{ 230, 314, "shop", 16, 12, rgb(70, 90, 160), "茶屋" },
	{ 217, 320, "box", Vector3.new(14, 16, 12), TEAL_ROOF },
	{ 196, 311, "round", 18, 3, TEAL_ROOF },
	{ 181, 318, "box", Vector3.new(20, 22, 14), RED },
	{ 165, 312, "round", 26, 2, RED_ROOF },
	{ 120, 306, "academy" },
	{ 136, 320, "shop", 16, 12, rgb(160, 60, 50), "団子" },
	{ 104, 319, "box", Vector3.new(16, 18, 12), TEAL_ROOF },
	{ 77, 311, "round", 24, 2, TEAL_ROOF },
	{ 61, 318, "box", Vector3.new(22, 16, 14), ORANGE_ROOF },
	{ 45, 312, "round", 22, 3, RED_ROOF },
	{ 13, 312, "round", 22, 2, ORANGE_ROOF },
	{ 357, 319, "box", Vector3.new(16, 22, 12), RED },
	{ 343, 314, "shop", 16, 12, rgb(60, 120, 90), "宿" },
}

-- Deuxième rangée de petites maisons (juste devant la première).
local SECOND_ROW = { 350, 0, 6, 17, 22, 38, 50, 53, 68, 74, 82, 98, 108, 112, 142, 150, 158, 172, 180, 188, 203, 210, 222, 236, 250, 262, 278, 290, 312, 324, 330, 337 }

-- Place en terre battue (taches organiques qui suivent la couleur « terre » de l'univers).
local function plaza(parent: Instance, center: Vector3, size: number, rng: Random)
	local count = rng:NextInteger(3, 5)
	for i = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = i == 1 and 0 or size * rng:NextNumber(0.2, 0.42)
		local d = size * (i == 1 and 0.8 or rng:NextNumber(0.4, 0.65))
		local disc = Core.flatDisc(parent, "Patch", center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), d, TOP_PLAZA + (i % 2) * 0.01, rgb(190, 152, 104), Enum.Material.Ground)
		Core.solRole(disc, "terre")
	end
end

function Ninja.build(decor: Instance, rng: Random, _theme)
	local ring = Build.folder(decor, "Anneau")
	local island = Build.folder(decor, "Ile")
	local horizon = Build.folder(decor, "Horizon")

	-- 1) Village dans l'anneau.
	local village = Build.folder(ring, "Village")
	for _, b in BUILDINGS do
		local angle, radius, kind = b[1], b[2], b[3]
		local cf = facing(angle, radius, TOP_RING)
		plaza(ring, polar(angle, radius - ((kind == "tower" or kind == "academy") and 34 or 18)), (kind == "tower" or kind == "academy") and 42 or 30, rng)
		if kind == "tower" then
			chiefTower(village, cf)
		elseif kind == "box" then
			boxHouse(village, cf, b[4], b[5], rng)
		elseif kind == "round" then
			roundHouse(village, cf, b[4], b[5], b[6], rng)
		elseif kind == "ramen" then
			ramenStand(village, cf)
		elseif kind == "shop" then
			shopHouse(village, cf, b[4], b[5], b[6], b[7], rng)
		elseif kind == "academy" then
			academy(village, cf, rng)
		end
	end
	local roofs = { RED_ROOF, ORANGE_ROOF, TEAL_ROOF }
	local rowPositions = {}
	for i, angle in SECOND_ROW do
		local a = angle + rng:NextNumber(-1.5, 1.5)
		local cf = facing(a, 288 + rng:NextNumber(-2, 2), TOP_RING)
		table.insert(rowPositions, cf)
		if i % 2 == 0 then
			roundHouse(village, cf, rng:NextNumber(13, 16), rng:NextInteger(1, 2), roofs[rng:NextInteger(1, 3)], rng)
		else
			boxHouse(village, cf, Vector3.new(rng:NextNumber(12, 15), rng:NextNumber(11, 15), rng:NextNumber(10, 12)), roofs[rng:NextInteger(1, 3)], rng)
		end
	end
	-- linge qui sèche entre quelques maisons voisines
	for i = 1, #rowPositions - 1, 3 do
		local a = rowPositions[i].Position + UP * 9
		local b = rowPositions[i + 1].Position + UP * 9
		if (a - b).Magnitude < 30 then
			Archi.laundry(village, a, b, rng)
		end
	end

	-- rue de terre battue devant le village
	Common.ringStreet(village, 262, 280, "chemin", rng)

	-- 2) Poteaux électriques et câbles le long du village, guirlandes de lanternes sur les rues.
	local street = Build.folder(ring, "Rue")
	local poleRadius = 274
	local prevLeft, prevRight, prevAngle = nil, nil, nil
	for i = 0, 71 do
		local angle = i * 5 + 2.5
		local pos = polar(angle, poleRadius, TOP_RING)
		if Layout.onPath(pos, 4) or Layout.inBossArena(pos, 8) then
			prevLeft = nil
		elseif i % 2 == 0 then
			local left, right = Archi.pole(street, pos, 15, math.rad(-angle), i % 6 == 0)
			if prevLeft and Common.angleDiff(angle, prevAngle) < 11 then
				Archi.cable(street, prevLeft, left, 1.6)
				Archi.cable(street, prevRight, right, 1.6)
			end
			prevLeft, prevRight, prevAngle = left, right, angle
		end
	end
	local lanternColors = { rgb(255, 90, 60), rgb(255, 200, 90), rgb(255, 250, 236) }
	for _, plotAngle in Layout.PlotAngles do
		local deg = math.deg(plotAngle)
		if Common.angleDiff(deg, MOUNTAIN_ANGLE) > 5 then
			for _, radius in { 296, 230 } do
				local half = math.deg((Layout.PathWidth / 2 + 4) / radius)
				local a = polar(deg - half, radius, TOP_RING)
				local b = polar(deg + half, radius, TOP_RING)
				for _, p in { a, b } do
					Core.vcyl(street, "LanternPost", CFrame.new(p), 13, 0.6, WOOD_DARK, Enum.Material.Wood)
				end
				Archi.lanternString(street, a + UP * 12.6, b + UP * 12.6, 6, lanternColors, 1.4)
			end
		end
	end
	Common.alongRoads({ 104, 200, 262 }, 5, function(pos)
		Props.stoneLantern(street, pos, 0.9)
	end)

	-- 3) Rue marchande (étals, bannières, tonneaux) devant la rangée de maisons, côté 220°-250°.
	local market = Build.folder(ring, "Marche")
	local goods = { "fruits", "fish", "bowls", "masks" }
	local colors = { rgb(200, 70, 50), rgb(60, 110, 180), rgb(230, 150, 50), rgb(90, 150, 80) }
	for i, angle in { 222, 228, 236, 242, 247 } do
		local cf = facing(angle, 270, TOP_RING) * CFrame.Angles(0, math.pi, 0)
		Props.stall(market, cf, colors[(i - 1) % 4 + 1], goods[(i - 1) % 4 + 1], rng)
		if i % 2 == 1 then
			Props.banner(market, polar(angle + 2.6, 266, TOP_RING), 10, colors[i % 4 + 1], ({ "祭", "団子", "茶" })[i % 3 + 1])
		end
	end
	for _, angle in { 10, 66, 128, 190, 318 } do
		Props.cargo(market, facing(angle, 278, TOP_RING) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), rng)
	end
	for _, angle in { 34, 150, 205, 330 } do
		Props.vendingMachine(market, facing(angle, 280, TOP_RING) * CFrame.Angles(0, math.pi, 0))
		Props.bench(market, facing(angle + 2.5, 280, TOP_RING) * CFrame.Angles(0, math.pi, 0))
	end
	for _, angle in { 52, 112, 173, 268, 352 } do
		Props.well(market, polar(angle, 266, TOP_RING))
	end

	-- 4) Terrain d'entraînement et arbres.
	local training = polar(180, 140, TOP_RING)
	plaza(ring, training, 36, rng)
	for k = -1, 1 do
		Props.trainingPost(ring, training + Vector3.new(k * 7, 0, rng:NextNumber(-3, 3)), rng)
	end
	Props.weaponRack(ring, CFrame.lookAt(training + Vector3.new(0, 0, 12), training) * CFrame.Angles(0, 0, 0))
	Relief.fence(ring, training + Vector3.new(-16, 0, -14), training + Vector3.new(16, 0, -14), "bois", 3.6)
	Core.scatter(rng, 9, Vector3.zero, 170, 176, function(p)
		return Common.ringFree(p, 16)
	end, function(p)
		Nature.tree("ArbreGeant", ring, p + UP * TOP_RING, { rng = rng, height = rng:NextNumber(46, 58), detail = "normal" })
	end)
	Core.scatter(rng, 26, Vector3.zero, Layout.RingInner + 6, 110, function(p)
		return Common.ringFree(p, 6)
	end, function(p)
		local species = rng:NextNumber() < 0.6 and "ArbreFeuillu" or "Cerisier"
		Nature.tree(species, ring, p + UP * TOP_RING, { rng = rng, height = rng:NextNumber(16, 24), detail = "normal", palette = species == "ArbreFeuillu" and "clair" or nil })
	end)
	Core.scatter(rng, 22, Vector3.zero, 234, 245, function(p)
		return Common.ringFree(p, 8)
	end, function(p)
		Nature.tree("ArbreFeuillu", ring, p + UP * TOP_RING, { rng = rng, height = rng:NextNumber(20, 28), detail = "normal" })
	end)
	Core.scatter(rng, 70, Vector3.zero, Layout.RingInner + 6, Layout.RingOuter - 6, function(p)
		return Common.ringFree(p, 4)
	end, function(p)
		local roll = rng:NextNumber()
		if roll < 0.55 then
			Nature.bush(ring, p + UP * TOP_RING, { rng = rng, height = rng:NextNumber(3, 5), flowers = rng:NextNumber() < 0.2 and rgb(240, 140, 170) or nil })
		elseif roll < 0.85 then
			Nature.rock(ring, p + UP * TOP_RING, rng:NextNumber(2.5, 5), { rng = rng, color = rgb(140, 134, 126) })
		else
			Nature.stump(ring, p + UP * TOP_RING, rng:NextNumber(2, 3), rng)
		end
	end)
	Common.ringGround(ring, rng, { patches = 26, tufts = 380, flowers = 110, flowerColors = { rgb(240, 110, 140), rgb(250, 210, 80), rgb(250, 250, 246) } })

	-- 5) Grande porte du village sur la route de la base à 270°.
	villageGate(ring, facing(270, Layout.RingFenceRadius + 3, TOP_RING))

	-- 6) Sur l'île : forêt d'arbres géants en bosquets, clairières et sanctuaire.
	local mountainCF = facing(MOUNTAIN_ANGLE, MOUNTAIN_RADIUS)
	local shrineAt = polar(60, 470)
	local free = Common.islandFree({ { polar(MOUNTAIN_ANGLE, 640), 240 }, { shrineAt, 22 } })
	Common.forest(island, rng, {
		groves = 34,
		perGrove = { 5, 9 },
		radius = { 24, 44 },
		free = free,
		species = {
			{ "ArbreGeant", 1.6, 50, 78, "foret" },
			{ "ArbreFeuillu", 4, 20, 32, "feuillu" },
			{ "ArbreFeuillu", 2, 18, 26, "clair" },
			{ "Sapin", 2, 22, 34 },
			{ "Cerisier", 0.6, 16, 22 },
		},
		undergrowth = { palette = "feuillu", ferns = rgb(70, 116, 54), flowers = { rgb(240, 140, 170), rgb(250, 230, 120) }, rocks = rgb(132, 126, 118), mushrooms = true },
	})
	forestShrine(island, CFrame.lookAt(Common.ground(shrineAt), Vector3.zero))
	for _, angle in { 18, 140, 205, 330 } do
		local clearing = Common.ground(polar(angle, 600))
		if free(clearing, 0) then
			for k = 1, 3 do
				Props.trainingPost(island, clearing + Vector3.new(k * 4 - 8, 0, rng:NextNumber(-2, 2)), rng)
			end
		end
	end

	-- 7) Montagne des chefs au bord de l'île, derrière la base 270°.
	chiefMountain(horizon, mountainCF, rng)

	-- 8) Couronne de montagnes vertes à l'horizon.
	Common.horizon(horizon, rng, 24, { rock = rgb(126, 116, 102), grass = rgb(74, 122, 60), trees = rgb(44, 82, 46), skip = { { MOUNTAIN_ANGLE, 30 } } })

	-- 9) Lampes de la promenade et feuilles qui tombent.
	Common.walkwayLamps(ring, 15, function(pos)
		Props.lamppost(ring, pos, "bois", rgb(255, 196, 120))
	end)
	Common.ambient(decor, "Feuilles", {
		colors = ColorSequence.new(rgb(120, 190, 80), rgb(190, 220, 100)),
		size = 0.7,
		rate = 40,
		speed = NumberRange.new(3, 5),
		direction = Enum.NormalId.Bottom,
		y = 60,
		radius = 420,
	})
end

return Ninja
