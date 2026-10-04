-- Décor de l'univers ACADÉMIE OCCULTE (inspiré de Jujutsu Kaisen), sur TOUTE la carte :
--   * dans l'anneau, l'école d'exorcistes : grand pavillon principal en bois sombre à double
--     toit, pagode à cinq étages, clocher (shōrō) et sa cloche de bronze, dortoirs à shoji
--     allumés, galeries couvertes, tunnel de torii rouges (senbon torii), cercles de sceaux
--     violets, cimetière brumeux aux tombes de pierre et flammes spectrales, lanternes de pierre ;
--   * la grande porte du temple (sanmon) sur la route de la base 270°, torii sur les autres routes ;
--   * sur l'île : forêt de cèdres sombres, érables rouges et arbres morts, torii perdus, brume ;
--   * au bord de l'île : le Sanctuaire Malveillant (temple sur un bassin rouge, côtes géantes,
--     crânes cornus) ;
--   * à l'horizon : montagnes violettes dans la brume. Énergie maudite qui monte du sol.

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

local Occulte = {}

local rgb = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local shade = Core.shade
local polar = Common.polar
local facing = Common.facing

local DARK_WOOD = rgb(58, 40, 34)
local WOOD = rgb(96, 66, 50)
local PLASTER = rgb(226, 220, 206)
local ROOF = rgb(46, 44, 54)
local LACQUER = rgb(160, 36, 40)
local STONE = rgb(120, 116, 124)
local CURSE = rgb(170, 70, 255)

local TOP_RING = Common.TOP_RING

------------------------------------------------------------------------
-- Bâtiments
------------------------------------------------------------------------

-- Bâtiment de temple : haut socle de pierre et escalier, véranda (engawa) à balustrade, murs à
-- colombages sombres et panneaux blancs, shoji allumés, toit à double étage aux coins relevés.
local function templeHall(parent: Instance, cf: CFrame, w: number, d: number, h: number, tiers: number, slotName: string, rng: Random): Model
	local model = Core.slot(parent, slotName, cf, h + 14)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	local plinthH = 2.4
	Archi.plinth(model, cf, w + 8, d + 8, plinthH, STONE, Enum.Material.Cobblestone)
	Archi.stairs(model, cf * CFrame.new(0, 0, -d / 2 - 6), 10, plinthH, 4, 4, shade(STONE, 0.08))
	local base = cf * CFrame.new(0, plinthH, 0)
	-- véranda
	Build.part(model, "Engawa", Vector3.new(w + 6, 0.5, d + 6), base * CFrame.new(0, 0.25, 0), WOOD, { Material = Enum.Material.WoodPlanks })
	for _, side in { -1, 1 } do
		Build.deco(model, "EngawaRail", Vector3.new(w + 6, 0.3, 0.3), base * CFrame.new(0, 2.6, side * (d / 2 + 2.8)), DARK_WOOD, { Material = Enum.Material.Wood })
		Build.deco(model, "EngawaRail", Vector3.new(0.3, 0.3, d + 6), base * CFrame.new(side * (w / 2 + 2.8), 2.6, 0), DARK_WOOD, { Material = Enum.Material.Wood })
	end
	for i = 0, math.floor((w + 6) / 3) do
		local x = -(w + 6) / 2 + i * 3
		if math.abs(x) > 5 then
			Build.deco(model, "Baluster", Vector3.new(0.25, 2.4, 0.25), base * CFrame.new(x, 1.4, -(d / 2 + 2.8)), DARK_WOOD, { Material = Enum.Material.Wood })
		end
	end
	local body = base * CFrame.new(0, 0.5, 0)
	Archi.walls(model, body, w, d, h, PLASTER, { frame = DARK_WOOD, spacing = 5, base = DARK_WOOD, baseHeight = 1.6 })
	Archi.door(model, body * CFrame.new(0, 0, -d / 2 - 0.05), 6, 7.6, { sliding = true, color = DARK_WOOD, step = false })
	local cols = math.max(2, math.floor(w / 6))
	Archi.windowRow(model, body * CFrame.new(0, 4.4, -d / 2 - 0.05), w, cols, 2.6, 2.6, { shoji = true, frame = DARK_WOOD, lit = true }, function(x)
		return math.abs(x) < 4.5
	end)
	for _, side in { -1, 1 } do
		Archi.windowRow(model, body * CFrame.new(side * (w / 2 + 0.05), 4.4, 0) * CFrame.Angles(0, side * math.pi / 2, 0), d, math.max(1, math.floor(d / 6)), 2.6, 2.6, {
			shoji = true,
			frame = DARK_WOOD,
			lit = rng:NextNumber() < 0.6,
		})
	end
	-- toits : jupe basse puis toit principal (et étage supérieur si `tiers` > 1)
	Archi.hipRoof(model, body * CFrame.new(0, h, 0), w, d, h * 0.45, 3.4, ROOF, { rafters = DARK_WOOD, trim = DARK_WOOD, ridge = rgb(200, 170, 80) })
	if tiers > 1 then
		local up = body * CFrame.new(0, h + h * 0.3, 0)
		Archi.walls(model, up, w * 0.6, d * 0.6, h * 0.5, PLASTER, { frame = DARK_WOOD, spacing = 4 })
		Archi.gableRoof(model, up * CFrame.new(0, h * 0.5, 0), w * 0.6, d * 0.6, h * 0.42, 3, ROOF, { rafters = DARK_WOOD, upturn = true, trim = DARK_WOOD, gableFill = PLASTER })
	end
	-- lanternes suspendues à l'avant-toit
	for _, x in { -w / 2 + 2, w / 2 - 2 } do
		Props.paperLantern(model, (body * CFrame.new(x, h - 2.4, -d / 2 - 2.6)).Position, rgb(255, 110, 70), 1)
	end
	return model
end

-- Pagode à cinq étages avec flèche à anneaux (sōrin).
local function pagoda(parent: Instance, cf: CFrame): Model
	local model = Core.slot(parent, "Pagode", cf, 74)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	Archi.plinth(model, cf, 26, 26, 2.4, STONE, Enum.Material.Cobblestone)
	Archi.stairs(model, cf * CFrame.new(0, 0, -16), 8, 2.4, 4, 4, shade(STONE, 0.08))
	local y = 2.4
	local w = 16
	for i = 1, 5 do
		local storey = 9 - i * 0.6
		local body = cf * CFrame.new(0, y, 0)
		Archi.walls(model, body, w, w, storey, i == 1 and PLASTER or rgb(176, 60, 50), { frame = DARK_WOOD, spacing = w / 2 })
		if i == 1 then
			Archi.door(model, body * CFrame.new(0, 0, -w / 2 - 0.05), 4, 6.4, { sliding = true, color = DARK_WOOD, step = false })
		else
			Archi.window(model, body * CFrame.new(0, storey * 0.5, -w / 2 - 0.05), 3, 2.6, { shoji = true, frame = DARK_WOOD, lit = true })
		end
		Archi.hipRoof(model, body * CFrame.new(0, storey, 0), w, w, 3.6, 4.2, ROOF, { rafters = DARK_WOOD, trim = DARK_WOOD })
		-- clochettes aux coins
		for _, x in { -1, 1 } do
			for _, z in { -1, 1 } do
				Build.deco(model, "Bell", Vector3.new(0.6, 0.9, 0.6), body * CFrame.new(x * (w / 2 + 3.6), storey - 1, z * (w / 2 + 3.6)), rgb(200, 170, 80), { Material = Enum.Material.Metal })
			end
		end
		y += storey + 2.6
		w -= 2.2
	end
	local top = cf * CFrame.new(0, y + 0.6, 0)
	Core.vcyl(model, "Sorin", top, 14, 0.8, rgb(190, 160, 80), Enum.Material.Metal)
	for k = 1, 7 do
		Core.vcyl(model, "SorinRing", top * CFrame.new(0, 2 + k * 1.4, 0), 0.4, 2.4 - k * 0.15, rgb(200, 170, 80), Enum.Material.Metal, false)
	end
	Core.ball(model, "SorinJewel", 1.4, (top * CFrame.new(0, 15, 0)).Position, rgb(230, 190, 90), Enum.Material.Metal)
	return model
end

-- Clocher (shōrō) : quatre poteaux, toit en croupe, grande cloche de bronze et sa poutre.
local function bellTower(parent: Instance, cf: CFrame): Model
	local model = Core.slot(parent, "Clocher", cf, 26)
	Archi.plinth(model, cf, 16, 16, 3, STONE, Enum.Material.Cobblestone)
	local base = cf * CFrame.new(0, 3, 0)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			Archi.block(model, "Post", Vector3.new(1.2, 15, 1.2), base * CFrame.new(x * 6, 0, z * 6), DARK_WOOD, Enum.Material.Wood)
		end
	end
	Build.part(model, "Beam", Vector3.new(14, 1, 1), base * CFrame.new(0, 14, 0), DARK_WOOD, { Material = Enum.Material.Wood })
	Archi.hipRoof(model, base * CFrame.new(0, 15, 0), 13, 13, 6, 3.4, ROOF, { rafters = DARK_WOOD, trim = DARK_WOOD, ridge = rgb(200, 170, 80) })
	Core.vcyl(model, "Bell", base * CFrame.new(0, 7, 0), 6, 5, rgb(96, 110, 90), Enum.Material.Metal, false)
	Core.ellipsoid(model, "BellTop", Vector3.new(5, 2.6, 5), base * CFrame.new(0, 13, 0), rgb(96, 110, 90), Enum.Material.Metal)
	for _, y in { 8, 10.5 } do
		Core.vcyl(model, "BellBand", base * CFrame.new(0, y, 0), 0.3, 5.2, rgb(80, 92, 74), Enum.Material.Metal, false)
	end
	Build.deco(model, "Striker", Vector3.new(8, 0.8, 0.8), base * CFrame.new(-6, 9, 0), WOOD, { Material = Enum.Material.Wood })
	return model
end

-- Galerie couverte entre deux points (poteaux, toit à deux pans, plancher).
local function corridor(parent: Instance, a: Vector3, b: Vector3)
	local delta = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local length = delta.Magnitude
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, mid + delta) * CFrame.Angles(0, math.pi / 2, 0)
	Build.part(parent, "CorridorFloor", Vector3.new(length, 0.6, 6), cf * CFrame.new(0, 0.6, 0), WOOD, { Material = Enum.Material.WoodPlanks })
	local posts = math.max(2, math.floor(length / 7))
	for i = 0, posts do
		local x = -length / 2 + i * length / posts
		for _, z in { -2.6, 2.6 } do
			Archi.block(parent, "CorridorPost", Vector3.new(0.6, 8, 0.6), cf * CFrame.new(x, 0.9, z), DARK_WOOD, Enum.Material.Wood, false)
		end
	end
	Archi.gableRoof(parent, cf * CFrame.new(0, 8.9, 0), length, 5.2, 2, 1.4, ROOF, { trim = DARK_WOOD })
end

-- Tombe japonaise (haka) : socle, pierre haute gravée, plaquettes de bois (sotoba), encens.
local function grave(parent: Instance, cf: CFrame, rng: Random)
	local stone = shade(rgb(130, 128, 134), rng:NextNumber(-0.12, 0.08))
	Archi.block(parent, "GraveBase", Vector3.new(4, 0.8, 4), cf, shade(stone, -0.1), Enum.Material.Slate)
	Archi.block(parent, "GraveBase2", Vector3.new(3, 0.8, 3), cf * CFrame.new(0, 0.8, 0), stone, Enum.Material.Slate)
	local tall = Archi.block(parent, "Gravestone", Vector3.new(1.8, rng:NextNumber(3.4, 4.6), 1.8), cf * CFrame.new(0, 1.6, 0), shade(stone, 0.05), Enum.Material.Granite)
	Build.surfaceText(tall, Enum.NormalId.Front, ({ "霊", "墓", "魂", "呪" })[rng:NextInteger(1, 4)], rgb(40, 34, 40), { TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
	for k = 1, rng:NextInteger(2, 4) do
		Build.deco(parent, "Sotoba", Vector3.new(0.5, rng:NextNumber(4.5, 6), 0.12), cf * CFrame.new(-1.2 + k * 0.5, 2.6, 1.9) * CFrame.Angles(0, 0, rng:NextNumber(-0.06, 0.06)), rgb(200, 180, 140), {
			Material = Enum.Material.Wood,
		})
	end
	if rng:NextNumber() < 0.4 then
		local flame = Core.ball(parent, "GhostFlame", 0.8, (cf * CFrame.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(4, 6), -1.5)).Position, rgb(140, 120, 255), Enum.Material.Neon)
		flame.Transparency = 0.2
		flame:SetAttribute("Bob", 0.6)
		game:GetService("CollectionService"):AddTag(flame, "Spin")
		Core.light(flame, rgb(150, 110, 255), 10, 1.2)
	end
end

-- Cercle de sceau maudit : disque sombre, anneaux violets lumineux, piliers à talismans.
local function sealCircle(parent: Instance, center: Vector3, radius: number)
	Build.disc(parent, "Ritual", 0.3, radius * 2, center, rgb(30, 24, 40), { Material = Enum.Material.Slate, CanCollide = false })
	for k, r in { radius * 1.7, radius * 1.25 } do
		local ring = Build.disc(parent, "RitualRing", 0.32 + k * 0.01, r, center, CURSE, { Material = Enum.Material.Neon, CanCollide = false })
		ring.Transparency = 0.2
		Build.disc(parent, "RitualInner", 0.33 + k * 0.01, r - 1.2, center, rgb(30, 24, 40), { Material = Enum.Material.Slate, CanCollide = false })
	end
	for k = 0, 3 do
		local pos = center + polar(k * 90 + 45, radius * 0.85)
		Archi.block(parent, "SealPillar", Vector3.new(1.4, 6, 1.4), CFrame.new(pos), rgb(40, 34, 46), Enum.Material.Slate)
		Build.deco(parent, "SealPaper", Vector3.new(0.9, 2, 0.1), CFrame.lookAt(pos + UP * 4, center + UP * 4) * CFrame.new(0, 0, -0.76), rgb(245, 235, 200))
		Build.deco(parent, "SealRope", Vector3.new(0.25, 0.25, (pos - (center + polar(k * 90 + 135, radius * 0.85))).Magnitude), CFrame.lookAt((pos + center + polar(k * 90 + 135, radius * 0.85)) / 2 + UP * 5, center + polar(k * 90 + 135, radius * 0.85) + UP * 5), rgb(230, 210, 150), {
			Material = Enum.Material.Fabric,
		})
	end
	local core = Build.deco(parent, "CurseCore", Vector3.new(2, 2, 2), CFrame.new(center + UP * 3) * CFrame.Angles(0.6, 0.6, 0), CURSE, { Material = Enum.Material.Neon })
	core:SetAttribute("Bob", 0.6)
	game:GetService("CollectionService"):AddTag(core, "Spin")
	Core.light(core, CURSE, 18, 1.6)
end

-- Grande porte du temple (sanmon) à deux étages sur la route.
local function sanmon(parent: Instance, cf: CFrame): Model
	local model = Core.slot(parent, "Sanmon", cf, 40)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	local w, d = 34, 12
	Archi.plinth(model, cf, w + 4, d + 4, 1, STONE, Enum.Material.Cobblestone)
	for _, x in { -w / 2 + 1, -6, 6, w / 2 - 1 } do
		for _, z in { -d / 2 + 1, d / 2 - 1 } do
			Archi.block(model, "Pillar", Vector3.new(1.8, 16, 1.8), cf * CFrame.new(x, 1, z), LACQUER, Enum.Material.Wood)
		end
	end
	-- statues gardiennes dans les travées latérales
	for _, side in { -1, 1 } do
		local g = cf * CFrame.new(side * 11.5, 1, 0)
		Archi.block(model, "GuardianBase", Vector3.new(4, 1.4, 4), g, STONE, Enum.Material.Slate)
		Core.ellipsoid(model, "Guardian", Vector3.new(3.4, 8, 2.6), g * CFrame.new(0, 5.4, 0), rgb(110, 60, 50), Enum.Material.Wood)
		Core.ball(model, "GuardianHead", 2.2, (g * CFrame.new(0, 10.4, 0)).Position, rgb(110, 60, 50), Enum.Material.Wood)
		Build.deco(model, "Lattice", Vector3.new(9, 12, 0.3), g * CFrame.new(0, 7, -d / 2 + 1), DARK_WOOD, { Material = Enum.Material.Wood, Transparency = 0.4 })
	end
	Build.part(model, "Lintel", Vector3.new(w + 2, 1.6, d), cf * CFrame.new(0, 17.8, 0), DARK_WOOD, { Material = Enum.Material.Wood })
	Archi.hipRoof(model, cf * CFrame.new(0, 18.6, 0), w, d, 3, 3.6, ROOF, { rafters = DARK_WOOD, trim = DARK_WOOD })
	local up = cf * CFrame.new(0, 21.6, 0)
	Archi.walls(model, up, w * 0.86, d * 0.8, 8, LACQUER, { frame = DARK_WOOD, spacing = 4.5 })
	Archi.windowRow(model, up * CFrame.new(0, 4, -d * 0.4 - 0.05), w * 0.86, 4, 2.8, 2.6, { shoji = true, frame = DARK_WOOD, lit = true })
	Archi.gableRoof(model, up * CFrame.new(0, 8, 0), w * 0.86, d * 0.8, 6, 4, ROOF, { rafters = DARK_WOOD, upturn = true, trim = DARK_WOOD, gableFill = PLASTER })
	Archi.sign(model, cf * CFrame.new(0, 15.6, -d / 2 - 0.6), 9, 2.4, "呪術高専", { bg = rgb(30, 24, 26), text = rgb(230, 200, 120) })
	for _, side in { -1, 1 } do
		Props.stoneLantern(model, (cf * CFrame.new(side * (w / 2 + 4), 0, -d / 2 - 4)).Position, 1.1, rgb(200, 150, 255))
	end
	return model
end

-- Le Sanctuaire Malveillant : temple sombre sur un bassin rouge, côtes géantes, crânes cornus.
local function malevolentShrine(parent: Instance, cf: CFrame, rng: Random): Model
	local model = Core.slot(parent, "SanctuaireMalveillant", cf, 70)
	pcall(function()
		model.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	end)
	-- bassin de sang
	local pool = Build.part(model, "BloodPool", Vector3.new(0.4, 130, 130), cf * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(110, 16, 24), {
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
	})
	pool.Reflectance = 0.3
	Build.part(model, "PoolBed", Vector3.new(0.4, 134, 134), cf * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(40, 10, 14), {
		Material = Enum.Material.Basalt,
		Shape = Enum.PartType.Cylinder,
	})
	-- plateforme et temple
	Archi.plinth(model, cf, 40, 34, 4, rgb(40, 34, 36), Enum.Material.Basalt)
	local base = cf * CFrame.new(0, 4, 0)
	Archi.walls(model, base, 28, 22, 14, rgb(40, 30, 30), { frame = rgb(20, 14, 14), spacing = 5 })
	-- façade en gueule : dents blanches autour de la porte
	for i = -3, 3 do
		Build.wedge(model, "Tooth", Vector3.new(1.4, 3, 1.4), base * CFrame.new(i * 1.6, 11.6, -11.6) * CFrame.Angles(math.pi, 0, 0), rgb(236, 230, 216), { CanCollide = false })
	end
	local maw = Build.deco(model, "Maw", Vector3.new(11, 10, 0.4), base * CFrame.new(0, 5, -11.2), rgb(120, 10, 20), { Material = Enum.Material.Neon })
	Core.light(maw, rgb(255, 40, 40), 30, 2)
	for k = 0, 2 do
		Archi.hipRoof(model, base * CFrame.new(0, 14 + k * 7, 0), 28 - k * 6, 22 - k * 5, 5, 5 - k, rgb(30, 20, 22), { rafters = rgb(20, 14, 14), trim = rgb(90, 20, 24) })
		if k < 2 then
			Archi.block(model, "TierWall", Vector3.new(20 - k * 6, 3, 15 - k * 5), base * CFrame.new(0, 15.2 + k * 7, 0), rgb(40, 30, 30), Enum.Material.Wood, false)
		end
	end
	-- côtes géantes en arc autour du temple
	for k = 0, 7 do
		for _, side in { -1, 1 } do
			local anchor = cf * CFrame.new(side * (24 + k * 1.5), 0, -30 + k * 8)
			local p0 = anchor.Position
			local p1 = p0 + UP * 26 + cf.RightVector * side * 6
			local p2 = p1 + UP * 14 - cf.RightVector * side * 12
			Core.cylinder(model, "Rib", p0, p1, 3, rgb(232, 226, 210), { Material = Enum.Material.SmoothPlastic, CanCollide = false })
			Core.ball(model, "RibJoint", 3, p1, rgb(232, 226, 210))
			Core.cylinder(model, "Rib", p1, p2, 2.4, rgb(232, 226, 210), { Material = Enum.Material.SmoothPlastic, CanCollide = false })
		end
	end
	-- crânes cornus en tas
	for _ = 1, 12 do
		local p = cf * CFrame.new(rng:NextNumber(-34, 34), 4, rng:NextNumber(-28, 20))
		if math.abs((p.Position - cf.Position):Dot(cf.RightVector)) > 16 or (p.Position - cf.Position):Dot(cf.LookVector) > 14 then
			Core.ellipsoid(model, "Skull", Vector3.new(3, 2.6, 3.4), p * CFrame.Angles(0, rng:NextNumber(0, 6), 0), rgb(226, 220, 204))
			for _, side in { -1, 1 } do
				Build.wedge(model, "Horn", Vector3.new(0.8, 3.2, 1.2), p * CFrame.new(side * 1.4, 1.8, 0) * CFrame.Angles(0, 0, side * -0.5), rgb(60, 50, 46), { CanCollide = false })
			end
		end
	end
	-- grand torii rouge devant
	Build.torii(model, cf * CFrame.new(0, 0, -58), 26, 30, LACQUER, rgb(20, 16, 18))
	return model
end

------------------------------------------------------------------------
-- Construction du décor
------------------------------------------------------------------------

local SHRINE_ANGLE = 270
local SHRINE_RADIUS = 640

function Occulte.build(decor: Instance, rng: Random, _theme)
	local ring = Build.folder(decor, "Anneau")
	local island = Build.folder(decor, "Ile")
	local horizon = Build.folder(decor, "Horizon")
	local school = Build.folder(ring, "Ecole")

	-- 1) L'école : pavillon principal, pagode, clocher, dortoirs, galeries.
	templeHall(school, facing(300, 300, TOP_RING), 34, 22, 12, 2, "PavillonPrincipal", rng)
	pagoda(school, facing(120, 302, TOP_RING))
	bellTower(school, facing(62, 310, TOP_RING))
	local dorms = { 18, 44, 80, 102, 140, 160, 200, 222, 246, 318, 342 }
	local dormCF = {}
	for _, angle in dorms do
		local cf = facing(angle, 310 + rng:NextNumber(-3, 3), TOP_RING)
		dormCF[angle] = cf
		templeHall(school, cf, rng:NextNumber(18, 24), rng:NextNumber(11, 13), 8, 1, "Dortoir", rng)
	end
	corridor(school, polar(18, 300, TOP_RING), polar(44, 300, TOP_RING))
	corridor(school, polar(140, 300, TOP_RING), polar(160, 300, TOP_RING))
	corridor(school, polar(318, 300, TOP_RING), polar(342, 300, TOP_RING))
	corridor(school, polar(200, 300, TOP_RING), polar(222, 300, TOP_RING))
	-- allée de gravier devant l'école
	Common.ringStreet(school, 268, 284, "dalle", rng)

	-- 2) Cimetière brumeux (entre 170° et 192°).
	local cemetery = Build.folder(ring, "Cimetiere")
	for row = 0, 3 do
		for k = 0, 6 do
			local angle = 172 + k * 3 + (row % 2) * 1.5
			local cf = facing(angle, 292 + row * 9, TOP_RING) * CFrame.Angles(0, rng:NextNumber(-0.1, 0.1), 0)
			grave(cemetery, cf, rng)
		end
	end
	for _, angle in { 170, 194 } do
		Nature.tree("ArbreMort", cemetery, polar(angle, 300, TOP_RING), { rng = rng, height = rng:NextNumber(18, 24), detail = "normal" })
	end
	Relief.stoneWall(cemetery, polar(169, 286, TOP_RING), polar(195, 286, TOP_RING), 2.6, 1.6, { rng = rng, color = rgb(110, 106, 112), moss = true })
	local mist = Instance.new("ParticleEmitter")
	local mistPart = Build.deco(cemetery, "Brume", Vector3.new(30, 1, 30), CFrame.new(polar(182, 305, 1)), Color3.new(1, 1, 1), { Transparency = 1 })
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(rgb(190, 170, 230))
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) })
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 12) })
	mist.Lifetime = NumberRange.new(6, 9)
	mist.Rate = 8
	mist.Speed = NumberRange.new(0.5, 1.5)
	mist.Parent = mistPart

	-- 3) Tunnel de torii rouges le long de la route de la base 150°, cercles de sceaux, lanternes.
	local sacred = Build.folder(ring, "Sacre")
	for r = 116, 196, 6 do
		Build.torii(sacred, facing(150, r, TOP_RING), Layout.PathWidth + 2, 11, LACQUER, rgb(30, 22, 24))
	end
	for _, angle in { 60, 240, 0 } do
		local center = polar(angle, angle == 0 and 140 or 104, TOP_RING + 0.05)
		if not Layout.inBossArena(center, 10) then
			sealCircle(sacred, center, 9)
		end
	end
	Common.alongRoads({ 104, 170, 240, 262 }, 5, function(pos)
		Props.stoneLantern(sacred, pos, 1, rgb(210, 160, 255))
	end)

	-- 4) Porte du temple sur la route 270°, torii sur les autres routes.
	sanmon(ring, facing(270, Layout.RingFenceRadius + 3, TOP_RING))
	for _, plotAngle in Layout.PlotAngles do
		local deg = math.deg(plotAngle)
		if Common.angleDiff(deg, 270) > 5 then
			Build.torii(ring, facing(deg, Layout.RingFenceRadius + 2, TOP_RING), Layout.PathWidth + 2, 16, LACQUER, rgb(30, 22, 24))
		end
	end

	-- 5) Arbres de l'anneau : cèdres, érables rouges, arbres morts.
	Core.scatter(rng, 14, Vector3.zero, 168, 178, function(p)
		return Common.ringFree(p, 12)
	end, function(p)
		Nature.tree("Cedre", ring, p + UP * TOP_RING, { rng = rng, height = rng:NextNumber(34, 46), detail = "normal" })
	end)
	Core.scatter(rng, 30, Vector3.zero, Layout.RingInner + 6, 110, function(p)
		return Common.ringFree(p, 6)
	end, function(p)
		local roll = rng:NextNumber()
		local species = roll < 0.5 and "Erable" or (roll < 0.8 and "Cedre" or "ArbreMort")
		Nature.tree(species, ring, p + UP * TOP_RING, { rng = rng, height = species == "Erable" and rng:NextNumber(12, 16) or rng:NextNumber(18, 28), detail = "normal" })
	end)
	Core.scatter(rng, 22, Vector3.zero, 234, 245, function(p)
		return Common.ringFree(p, 8)
	end, function(p)
		Nature.tree(rng:NextNumber() < 0.5 and "Erable" or "Cedre", ring, p + UP * TOP_RING, { rng = rng, height = rng:NextNumber(14, 30), detail = "normal" })
	end)
	Core.scatter(rng, 60, Vector3.zero, Layout.RingInner + 6, Layout.RingOuter - 6, function(p)
		return Common.ringFree(p, 4)
	end, function(p)
		if rng:NextNumber() < 0.5 then
			Nature.bush(ring, p + UP * TOP_RING, { rng = rng, height = rng:NextNumber(3, 4.5), palette = "nuit" })
		else
			Nature.rock(ring, p + UP * TOP_RING, rng:NextNumber(2.5, 5), { rng = rng, color = rgb(96, 92, 104), moss = rgb(70, 90, 64) })
		end
	end)
	-- talismans tombés au sol
	Core.scatter(rng, 40, Vector3.zero, Layout.RingInner + 4, Layout.RingOuter - 4, function(p)
		return Common.ringFree(p, 1)
	end, function(p)
		Build.deco(ring, "Talisman", Vector3.new(0.8, 0.06, 1.6), CFrame.new(p + UP * (TOP_RING + 0.05)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), rgb(245, 235, 200), { CastShadow = false })
	end)
	Common.ringGround(ring, rng, { patches = 24, tufts = 260, flowers = 40, flowerColors = { rgb(200, 40, 50), rgb(140, 100, 200) }, patchRole = "herbe" })

	-- 6) Île : forêt de cèdres sombres, érables rouges, arbres morts, torii perdus.
	local shrineCF = facing(SHRINE_ANGLE, SHRINE_RADIUS)
	local free = Common.islandFree({ { polar(SHRINE_ANGLE, 650), 110 } })
	Common.forest(island, rng, {
		groves = 34,
		perGrove = { 5, 9 },
		radius = { 22, 40 },
		free = free,
		species = {
			{ "Cedre", 5, 30, 50 },
			{ "Sapin", 2, 24, 36, "nuit" },
			{ "Erable", 2.5, 12, 18 },
			{ "ArbreMort", 1, 16, 24 },
			{ "ArbreFeuillu", 1, 20, 28, "nuit" },
		},
		undergrowth = { palette = "nuit", ferns = rgb(54, 76, 54), rocks = rgb(92, 88, 100), mushrooms = true },
	})
	for _, angle in { 20, 100, 160, 230, 320 } do
		local p = Common.ground(polar(angle, 600))
		if free(p, 2) then
			Build.torii(island, CFrame.lookAt(p, Vector3.new(0, p.Y, 0)), 10, 11, LACQUER, rgb(30, 22, 24))
			Props.stoneLantern(island, p + Vector3.new(6, 0, 0), 0.8, rgb(200, 150, 255))
		end
	end
	malevolentShrine(horizon, shrineCF, rng)

	-- 7) Horizon : montagnes violettes dans la brume.
	Common.horizon(horizon, rng, 22, { rock = rgb(70, 64, 84), grass = rgb(52, 64, 58), trees = rgb(34, 44, 40), skip = { { SHRINE_ANGLE, 16 } } })

	-- 8) Lampes de la promenade, énergie maudite qui monte, brume basse.
	Common.walkwayLamps(ring, 15, function(pos)
		Props.stoneLantern(ring, pos, 0.85, rgb(210, 160, 255))
	end)
	Common.ambient(decor, "EnergieMaudite", {
		colors = ColorSequence.new(rgb(180, 90, 255), rgb(90, 30, 170)),
		size = 1.1,
		rate = 40,
		speed = NumberRange.new(1, 3),
		direction = Enum.NormalId.Top,
		y = 0.6,
		radius = 360,
		lightEmission = 0.8,
	})
	Common.ambient(decor, "Brume", {
		texture = "rbxasset://textures/particles/smoke_main.dds",
		colors = ColorSequence.new(rgb(170, 150, 210)),
		size = 14,
		rate = 14,
		speed = NumberRange.new(0.3, 1),
		direction = Enum.NormalId.Top,
		y = 1,
		radius = 600,
		lifetime = NumberRange.new(8, 12),
		lightEmission = 0,
		spin = false,
	})
end

return Occulte
