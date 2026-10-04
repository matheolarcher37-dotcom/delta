-- Décor de l'univers PLANÈTE DES GUERRIERS (inspiré de Dragon Ball), sur TOUTE la carte :
--   * dans l'anneau : quartier de maisons-dômes blanches (hublots ronds, cheminées-tubes,
--     antennes paraboliques), maisons-capsules numérotées, grande arène du tournoi (ring de dalles,
--     tribunes, temple d'entrée, drapeaux « 天下一 »), capsules spatiales écrasées dans leurs
--     cratères, pics rocheux en strates, arbres ronds bleu-vert ;
--   * une grande porte en pierre et orbes sur la route de la base 270° ;
--   * sur l'île : prairies, bosquets d'arbres ronds, mesas et aiguilles rocheuses ;
--   * au bord de l'île : la tour céleste (immense colonne blanche) et le palais flottant
--     au-dessus des nuages ;
--   * à l'horizon : aiguilles rocheuses dans la mer et la petite île à la maison rose.
--   Étincelles de ki dorées dans l'air.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Build = require(script.Parent.Parent.Parent.Modules.Build)
local Core = require(script.Parent.Parent.Kit.Core)
local Nature = require(script.Parent.Parent.Kit.Nature)
local Archi = require(script.Parent.Parent.Kit.Archi)
local Props = require(script.Parent.Parent.Kit.Props)
local Common = require(script.Parent.Common)

local Saiyan = {}

local rgb = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local shade = Core.shade
local polar = Common.polar
local facing = Common.facing

local WHITE = rgb(240, 240, 236)
local BLUE = rgb(70, 130, 200)
local ORANGE = rgb(240, 140, 40)
local SAND = rgb(206, 170, 118)
local STONE = rgb(214, 206, 190)
local GLASS = rgb(70, 110, 150)

local TOP_RING = Common.TOP_RING

------------------------------------------------------------------------
-- Éléments
------------------------------------------------------------------------

-- Hublot rond sur une surface (`cf` : centre, -Z vers l'extérieur).
local function porthole(parent: Instance, cf: CFrame, d: number, lit: boolean?)
	local frame = Build.deco(
		parent,
		"PortholeFrame",
		Vector3.new(0.3, d + 0.6, d + 0.6),
		cf * CFrame.new(0, 0, -0.05) * CFrame.Angles(0, math.rad(90), 0),
		rgb(180, 184, 190),
		{ Material = Enum.Material.Metal }
	)
	frame.Shape = Enum.PartType.Cylinder
	local glass = Build.deco(parent, "Porthole", Vector3.new(0.3, d, d), cf * CFrame.new(0, 0, -0.18) * CFrame.Angles(0, math.rad(90), 0), lit and rgb(255, 230, 170) or GLASS, {
		Material = lit and Enum.Material.Neon or Enum.Material.Glass,
		Reflectance = lit and 0 or 0.2,
	})
	glass.Shape = Enum.PartType.Cylinder
end

-- Maison-dôme : grand dôme blanc (vraie demi-sphère), bandeau coloré, hublots, porte arrondie,
-- cheminée-tube, parabole, petit dôme annexe.
local function domeHouse(parent: Instance, cf: CFrame, d: number, accent: Color3, rng: Random): Model
	local model = Core.slot(parent, "MaisonDome", cf, d * 0.55 + 6)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	Core.vcyl(model, "DomeBase", cf, 1, d + 2, rgb(190, 186, 176), Enum.Material.Concrete)
	local dome = Build.part(model, "Dome", Vector3.new(d, d, d), cf * CFrame.new(0, 1 - d * 0.05, 0), WHITE, { Material = Enum.Material.SmoothPlastic, Shape = Enum.PartType.Ball })
	dome.CastShadow = true
	Core.vcyl(model, "DomeBand", cf * CFrame.new(0, 2.6, 0), 1.4, d + 0.3, accent, Enum.Material.SmoothPlastic, false)
	local r = d / 2
	for i = 0, 5 do
		local a = (i + 0.5) / 6 * math.pi * 2
		if math.abs(math.cos(a - math.pi)) < 0.85 or i % 2 == 0 then
			local y = r * 0.42
			local inward = math.sqrt(r * r - (y - 0.0) ^ 2)
			porthole(model, cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 1 - d * 0.05 + y, -inward + 0.1) * CFrame.Angles(math.asin(y / r) * -0.5, 0, 0), 2, rng:NextNumber() < 0.3)
		end
	end
	-- porte arrondie et petit sas
	local door = cf * CFrame.new(0, 1, -r + 0.6)
	Build.part(model, "Airlock", Vector3.new(5.4, 7, 3), door * CFrame.new(0, 3.5, -1), WHITE, { Material = Enum.Material.SmoothPlastic })
	local arch =
		Build.part(model, "AirlockTop", Vector3.new(3, 5.4, 5.4), door * CFrame.new(0, 7, -1) * CFrame.Angles(0, math.rad(90), 0), WHITE, { Shape = Enum.PartType.Cylinder })
	arch.CastShadow = true
	Build.deco(model, "Door", Vector3.new(3.4, 5.6, 0.3), door * CFrame.new(0, 2.8, -2.55), accent, { Material = Enum.Material.Metal })
	Build.deco(model, "DoorLight", Vector3.new(2.4, 0.4, 0.2), door * CFrame.new(0, 6.4, -2.6), rgb(255, 230, 160), { Material = Enum.Material.Neon })
	-- cheminée-tube et parabole
	local top = cf * CFrame.new(r * 0.3, 1 + r * 0.85, r * 0.2)
	Core.vcyl(model, "Tube", top, 5, 1.6, rgb(200, 204, 210), Enum.Material.Metal, false)
	Core.ellipsoid(model, "TubeCap", Vector3.new(2.2, 1, 2.2), top * CFrame.new(0, 5.2, 0), accent)
	local dish = cf * CFrame.new(-r * 0.4, 1 + r * 0.8, r * 0.1)
	Build.deco(model, "DishPole", Vector3.new(0.3, 3, 0.3), dish * CFrame.new(0, 1.5, 0), rgb(180, 180, 186), { Material = Enum.Material.Metal })
	Core.ellipsoid(model, "Dish", Vector3.new(3.4, 0.8, 3.4), dish * CFrame.new(0, 3.2, 0) * CFrame.Angles(0.5, 0, 0.3), rgb(230, 230, 236), Enum.Material.Metal)
	-- dôme annexe
	if rng:NextNumber() < 0.7 then
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local annex = cf * CFrame.new(side * (r + d * 0.18), 0, r * 0.2)
		Build.part(model, "Annex", Vector3.new(d * 0.5, d * 0.5, d * 0.5), annex * CFrame.new(0, 0.5, 0), WHITE, { Shape = Enum.PartType.Ball })
		Core.vcyl(model, "AnnexBand", annex, 1.2, d * 0.5 + 0.2, accent, Enum.Material.SmoothPlastic, false)
	end
	return model
end

-- Maison-capsule : cylindre blanc couché sur le flanc ou debout, coiffé d'un dôme, numéro peint.
local function capsuleHouse(parent: Instance, cf: CFrame, accent: Color3, number: number, rng: Random): Model
	local model = Core.slot(parent, "MaisonCapsule", cf, 22)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	Core.vcyl(model, "Pad", cf, 0.6, 20, rgb(190, 186, 176), Enum.Material.Concrete)
	local body = Core.vcyl(model, "Body", cf * CFrame.new(0, 0.6, 0), 12, 16, WHITE, Enum.Material.SmoothPlastic)
	body.CastShadow = true
	Core.vcyl(model, "Stripe", cf * CFrame.new(0, 9.4, 0), 1.6, 16.3, accent, Enum.Material.SmoothPlastic, false)
	Build.part(model, "Cap", Vector3.new(16, 16, 16), cf * CFrame.new(0, 12.6, 0), WHITE, { Shape = Enum.PartType.Ball })
	Core.vcyl(model, "CapRing", cf * CFrame.new(0, 12.4, 0), 0.6, 16.6, rgb(60, 64, 72), Enum.Material.Metal, false)
	local plate = Core.plaqueText(model, cf * CFrame.new(0, 9.4, -8.3), Vector2.new(5, 1.6), "No." .. number, rgb(255, 255, 255), Enum.Font.GothamBlack)
	plate.Name = "Numero"
	for i = 0, 3 do
		local a = (i + 0.5) / 4 * math.pi * 2
		porthole(model, cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 5.4, -8.05), 2.2, rng:NextNumber() < 0.3)
	end
	Archi.door(model, cf * CFrame.new(0, 0.6, -8.05), 3.6, 6.4, { color = accent, step = true })
	Build.deco(model, "Antenna", Vector3.new(0.25, 6, 0.25), cf * CFrame.new(3, 21.5, 0), rgb(180, 180, 186), { Material = Enum.Material.Metal })
	Core.ball(model, "AntennaTip", 0.7, (cf * CFrame.new(3, 24.6, 0)).Position, rgb(255, 70, 60), Enum.Material.Neon)
	return model
end

-- Pic rocheux (aiguille de grès comme dans les plaines de Dragon Ball) : chaque strate est faite
-- de 2 ou 3 blocs décalés et tournés (silhouette irrégulière), la colonne s'affine et penche un
-- peu, des corniches débordent, quelques touffes vertes s'accrochent, sommet herbeux.
local function spire(parent: Instance, base: Vector3, height: number, width: number, rng: Random, grass: boolean?): Model
	local model = Core.slot(parent, "PicRocheux", CFrame.new(base), height)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	local layers = math.max(3, math.floor(height / 7))
	local layerH = height / layers
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * width * 0.012
	local w = width
	local offset = Vector3.zero
	local light, dark = SAND, rgb(170, 116, 80)
	for l = 0, layers - 1 do
		local t = l / layers
		local y = l * layerH
		local tone = shade(light:Lerp(dark, 0.25 + 0.5 * math.abs(math.sin(l * 1.7))), rng:NextNumber(-0.04, 0.04))
		local blocks = l == layers - 1 and 1 or rng:NextInteger(2, 3)
		for b = 1, blocks do
			local bw = w * (b == 1 and rng:NextNumber(0.85, 1) or rng:NextNumber(0.55, 0.8))
			local bd = w * (b == 1 and rng:NextNumber(0.75, 0.95) or rng:NextNumber(0.5, 0.75))
			local shift = b == 1 and Vector3.zero or Vector3.new(rng:NextNumber(-0.3, 0.3) * w, 0, rng:NextNumber(-0.3, 0.3) * w)
			local h = layerH * rng:NextNumber(1.02, 1.25)
			Build.part(
				model,
				"Strata",
				Vector3.new(bw, h, bd),
				CFrame.new(base + offset + shift + UP * (y + h / 2 - 0.4)) * CFrame.Angles(rng:NextNumber(-0.04, 0.04), rng:NextNumber(0, math.pi), rng:NextNumber(-0.04, 0.04)),
				shade(tone, b == 1 and 0 or rng:NextNumber(-0.06, 0.06)),
				{ Material = Enum.Material.Sandstone }
			)
		end
		-- corniche plus claire qui déborde (strate dure)
		if l > 0 and rng:NextNumber() < 0.45 then
			Build.part(
				model,
				"Ledge",
				Vector3.new(w * 1.12, 0.9, w * rng:NextNumber(0.9, 1.1)),
				CFrame.new(base + offset + UP * y) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				shade(light, 0.08),
				{
					Material = Enum.Material.Sandstone,
				}
			)
			if grass ~= false and rng:NextNumber() < 0.5 then
				Core.ellipsoid(
					model,
					"LedgeGrass",
					Vector3.new(w * 0.5, 1.4, w * 0.4),
					CFrame.new(base + offset + UP * (y + 0.8) + Vector3.new(rng:NextNumber(-0.4, 0.4) * w, 0, rng:NextNumber(-0.4, 0.4) * w)),
					rgb(96, 158, 108),
					Enum.Material.Grass
				)
			end
		end
		w *= rng:NextNumber(0.86, 0.97) - t * 0.02
		offset += lean * layerH + Vector3.new(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5))
	end
	if grass ~= false then
		local top = base + offset + UP * (height + 0.2)
		Core.ellipsoid(model, "SpireTop", Vector3.new(w * 1.15, 3.2, w * 1.1), CFrame.new(top), rgb(104, 166, 116), Enum.Material.Grass)
		Core.ellipsoid(model, "SpireTop", Vector3.new(w * 0.7, 2.4, w * 0.6), CFrame.new(top + UP * 1.2 + Vector3.new(w * 0.15, 0, 0)), rgb(120, 180, 126), Enum.Material.Grass)
	end
	-- éboulis au pied
	for _ = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		Nature.rock(model, base + Vector3.new(math.cos(a), 0, math.sin(a)) * width * rng:NextNumber(0.6, 0.9), rng:NextNumber(3, 7), {
			rng = rng,
			color = SAND,
			material = Enum.Material.Sandstone,
			slot = "Eboulis",
		})
	end
	return model
end

-- Voiture volante arrondie (aéroglisseur de la ville) : carrosserie ovale, bulle vitrée, ailerons,
-- phares, réacteurs lumineux dessous.
local function hoverCar(parent: Instance, cf: CFrame, color: Color3)
	local model = Build.model(parent, "VoitureVolante")
	local body = cf * CFrame.new(0, 2.2, 0)
	Core.ellipsoid(model, "CarBody", Vector3.new(4.6, 2.2, 8.4), body, color, Enum.Material.SmoothPlastic)
	Core.ellipsoid(model, "CarSkirt", Vector3.new(5, 0.9, 8.8), body * CFrame.new(0, -0.6, 0), shade(color, -0.25), Enum.Material.Metal)
	local bubble = Core.ellipsoid(model, "CarBubble", Vector3.new(3.4, 2.2, 3.8), body * CFrame.new(0, 1, 0.6), rgb(150, 200, 230), Enum.Material.Glass)
	bubble.Transparency = 0.35
	for _, x in { -1, 1 } do
		Build.wedge(model, "Fin", Vector3.new(0.3, 1.4, 2), body * CFrame.new(x * 1.6, 1, 3.4), shade(color, -0.1), { CanCollide = false })
		Build.deco(model, "HeadLight", Vector3.new(0.8, 0.4, 0.2), body * CFrame.new(x * 1.3, 0.1, -4.15), rgb(255, 250, 220), { Material = Enum.Material.Neon })
		local jet = Core.ball(model, "Jet", 1, (body * CFrame.new(x * 1.4, -1.2, 2.6)).Position, rgb(120, 210, 255), Enum.Material.Neon)
		jet.Transparency = 0.2
	end
	return model
end

-- Siège de la Capsule Corporation : immense dôme blanc sur socle, bandeau et enseigne, aile en
-- cylindre à hublots, petit dôme, tour-antenne, parking de voitures volantes, palmiers.
local function capsuleCorp(parent: Instance, cf: CFrame, rng: Random): Model
	local model = Core.slot(parent, "CapsuleCorp", cf, 40)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	local D = 42
	Core.vcyl(model, "Plaza", cf, 0.4, D + 22, rgb(200, 198, 192), Enum.Material.Pavement)
	Core.vcyl(model, "Base", cf * CFrame.new(0, 0.4, 0), 4, D + 4, rgb(214, 212, 206), Enum.Material.Concrete)
	local dome = Build.part(model, "Dome", Vector3.new(D, D, D), cf * CFrame.new(0, 4.4 - D * 0.08, 0), WHITE, { Shape = Enum.PartType.Ball })
	dome.CastShadow = true
	Core.vcyl(model, "Band", cf * CFrame.new(0, 7, 0), 3, D + 0.6, rgb(70, 110, 190), Enum.Material.SmoothPlastic, false)
	-- rangée de hublots sur tout le tour
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		if math.abs(math.sin(a)) > 0.25 or math.cos(a) > 0 then
			porthole(model, cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 14, -(D / 2) * 0.93) * CFrame.Angles(-0.35, 0, 0), 2.6, rng:NextNumber() < 0.5)
		end
	end
	-- entrée et enseigne
	local front = cf * CFrame.new(0, 0, -D / 2 + 1)
	Build.part(model, "Entrance", Vector3.new(12, 10, 8), front * CFrame.new(0, 5.4, -3), WHITE, { Material = Enum.Material.SmoothPlastic })
	Build.deco(model, "Door", Vector3.new(7, 7, 0.3), front * CFrame.new(0, 4, -7.05), rgb(90, 140, 200), { Material = Enum.Material.Glass, Transparency = 0.2 })
	Archi.sign(model, front * CFrame.new(0, 12.6, -7.2), 16, 3.4, "CAPSULE CORP.", { bg = rgb(250, 250, 248), text = rgb(60, 100, 190), font = Enum.Font.GothamBlack })
	-- aile cylindrique couchée à hublots
	local wing = cf * CFrame.new(D * 0.62, 0, 4)
	local tube = Build.part(model, "Wing", Vector3.new(26, 14, 14), wing * CFrame.new(0, 7.4, 0) * CFrame.Angles(0, math.rad(90), 0), WHITE, { Shape = Enum.PartType.Cylinder })
	tube.CastShadow = true
	Core.ball(model, "WingCap", 14, (wing * CFrame.new(0, 7.4, -13)).Position, WHITE)
	for k = -2, 2 do
		porthole(model, wing * CFrame.new(-7.05, 8, k * 4.6) * CFrame.Angles(0, math.rad(-90), 0), 2.2, true)
	end
	-- petit dôme et tour-antenne
	local small = cf * CFrame.new(-D * 0.6, 0, 6)
	Build.part(model, "SmallDome", Vector3.new(18, 18, 18), small * CFrame.new(0, 1, 0), WHITE, { Shape = Enum.PartType.Ball })
	Core.vcyl(model, "SmallBand", small * CFrame.new(0, 1.6, 0), 1.6, 18.3, ORANGE, Enum.Material.SmoothPlastic, false)
	local tower = cf * CFrame.new(-D * 0.25, 0, D * 0.36)
	Core.vcyl(model, "Tower", tower, 34, 5, rgb(226, 226, 222), Enum.Material.SmoothPlastic)
	Core.ball(model, "TowerBall", 7, (tower * CFrame.new(0, 36, 0)).Position, WHITE)
	Build.deco(model, "Antenna", Vector3.new(0.4, 10, 0.4), tower * CFrame.new(0, 44, 0), rgb(180, 180, 186), { Material = Enum.Material.Metal })
	local beacon = Core.ball(model, "Beacon", 1, (tower * CFrame.new(0, 49.4, 0)).Position, rgb(255, 60, 50), Enum.Material.Neon)
	Core.light(beacon, rgb(255, 80, 60), 16, 1)
	-- parking et palmiers
	local colors = { rgb(240, 200, 60), rgb(220, 70, 60), rgb(70, 140, 220), rgb(250, 250, 248) }
	for k = 0, 3 do
		hoverCar(model, cf * CFrame.new(-D / 2 - 4 + k * 6, 0.4, -D / 2 - 8) * CFrame.Angles(0, math.rad(rng:NextNumber(-8, 8)), 0), colors[k + 1])
	end
	for _, x in { -1, 1 } do
		Nature.tree("Palmier", model, (cf * CFrame.new(x * (D / 2 + 6), 0.4, -D / 2 - 2)).Position, { rng = rng, height = rng:NextNumber(20, 26), detail = "normal" })
	end
	return model
end

-- Cratère de combat sur l'île : sol creusé, bourrelet de roches, fissures et rochers projetés.
local function battleCrater(parent: Instance, center: Vector3, radius: number, rng: Random)
	local model = Build.model(parent, "CratereDeCombat")
	Build.disc(model, "CraterFloor", 0.3, radius * 2, center, rgb(150, 116, 82), { Material = Enum.Material.Ground, CanCollide = false })
	Build.disc(model, "CraterCore", 0.34, radius * 1.1, center, rgb(118, 90, 66), { Material = Enum.Material.Ground, CanCollide = false })
	local n = math.floor(radius * 0.9)
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * rng:NextNumber(0.95, 1.1)
		Build.part(
			model,
			"CraterRim",
			Vector3.new(rng:NextNumber(4, 7), rng:NextNumber(1.4, 3), rng:NextNumber(2.5, 4)),
			CFrame.lookAt(p, center) * CFrame.Angles(-0.45, 0, rng:NextNumber(-0.2, 0.2)),
			shade(SAND, rng:NextNumber(-0.12, 0)),
			{
				Material = Enum.Material.Rock,
			}
		)
	end
	for k = 0, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local len = radius * rng:NextNumber(0.4, 0.8)
		local mid = center + Vector3.new(math.cos(a), 0, math.sin(a)) * len * 0.5
		Build.deco(
			model,
			"Crack",
			Vector3.new(0.5, 0.1, len),
			CFrame.lookAt(mid + UP * 0.36, center + UP * 0.36) * CFrame.Angles(0, k * 0.1, 0),
			rgb(60, 44, 34),
			{ CastShadow = false }
		)
	end
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		Nature.rock(
			model,
			center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * rng:NextNumber(1.3, 1.9),
			rng:NextNumber(2.5, 5),
			{ rng = rng, color = SAND, material = Enum.Material.Sandstone }
		)
	end
end

-- Capsule spatiale écrasée dans son cratère.
local function crashPod(parent: Instance, center: Vector3, rng: Random)
	local model = Core.slot(parent, "CapsuleSpatiale", CFrame.new(center), 8)
	Build.disc(model, "Crater", 0.3, 26, center, rgb(150, 120, 86), { Material = Enum.Material.Ground, CanCollide = false })
	Build.disc(model, "CraterCore", 0.32, 16, center, rgb(110, 86, 64), { Material = Enum.Material.Ground, CanCollide = false })
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * 13
		Build.part(
			model,
			"CraterRim",
			Vector3.new(rng:NextNumber(4, 6), rng:NextNumber(1.2, 2.4), 3),
			CFrame.lookAt(p, center) * CFrame.Angles(-0.4, 0, 0),
			rgb(170, 140, 100),
			{ Material = Enum.Material.Rock }
		)
	end
	local pod = Build.part(model, "Pod", Vector3.new(7, 7, 7), CFrame.new(center + UP * 2.4), WHITE, { Shape = Enum.PartType.Ball, Material = Enum.Material.Metal })
	pod.CastShadow = true
	local window = Build.deco(
		model,
		"PodWindow",
		Vector3.new(4.6, 4.6, 4.6),
		CFrame.new(center + UP * 2.8 + Vector3.new(0.6, 0, -0.6)),
		rgb(150, 30, 50),
		{ Shape = Enum.PartType.Ball, Material = Enum.Material.Glass }
	)
	window.Transparency = 0.1
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(rgb(90, 86, 84))
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
	smoke.Lifetime = NumberRange.new(3, 5)
	smoke.Rate = 4
	smoke.Speed = NumberRange.new(2, 4)
	smoke.Parent = pod
end

-- Grande arène du tournoi : ring de dalles surélevé, escaliers, tribunes, temple d'entrée,
-- drapeaux, tableau des combats.
local function tournament(parent: Instance, cf: CFrame, rng: Random): Model
	local model = Core.slot(parent, "AreneDuTournoi", cf, 30)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	local size = 44
	Archi.block(model, "RingBase", Vector3.new(size + 2, 3.6, size + 2), cf, rgb(176, 168, 152), Enum.Material.Concrete)
	Archi.block(model, "Ring", Vector3.new(size, 0.4, size), cf * CFrame.new(0, 3.6, 0), STONE, Enum.Material.Pavement)
	for k = -3, 3 do
		Build.deco(model, "Joint", Vector3.new(size, 0.06, 0.25), cf * CFrame.new(0, 4.02, k * size / 7), rgb(150, 144, 132))
		Build.deco(model, "Joint", Vector3.new(0.25, 0.06, size), cf * CFrame.new(k * size / 7, 4.02, 0), rgb(150, 144, 132))
	end
	for _, side in { -1, 1 } do
		Archi.stairs(model, cf * CFrame.new(side * (size / 2 + 3.4), 0, 0) * CFrame.Angles(0, side * math.pi / 2, 0), 8, 3.6, 5, 5, rgb(176, 168, 152))
	end
	-- coins : lampes rondes sur pilier
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local p = cf * CFrame.new(x * (size / 2 + 2), 0, z * (size / 2 + 2))
			Archi.block(model, "CornerPillar", Vector3.new(2, 8, 2), p, rgb(200, 192, 176), Enum.Material.Concrete)
			local lamp = Core.ball(model, "CornerLamp", 2.4, (p * CFrame.new(0, 9.2, 0)).Position, rgb(255, 230, 160), Enum.Material.Neon)
			Core.light(lamp, rgb(255, 220, 160), 20, 1)
		end
	end
	-- tribunes sur les côtés
	for _, side in { -1, 1 } do
		local stand = cf * CFrame.new(side * (size / 2 + 22), 0, 0) * CFrame.Angles(0, side * math.pi / 2, 0)
		for row = 0, 4 do
			Archi.block(
				model,
				"Bleacher",
				Vector3.new(40, 1.4 + row * 1.4, 3),
				stand * CFrame.new(0, 0, row * 3),
				shade(rgb(200, 80, 60), (row % 2) * 0.08),
				Enum.Material.Concrete
			)
		end
		for k = -2, 2 do
			Props.banner(model, (stand * CFrame.new(k * 8, 7, 14)).Position, 10, k % 2 == 0 and ORANGE or BLUE, "武")
		end
	end
	-- temple d'entrée derrière le ring
	local temple = cf * CFrame.new(0, 0, size / 2 + 16)
	Archi.plinth(model, temple, 30, 14, 1.4, rgb(176, 168, 152))
	Archi.walls(model, temple * CFrame.new(0, 1.4, 0), 26, 10, 12, rgb(240, 226, 190), { frame = rgb(170, 60, 40), spacing = 6.5 })
	Archi.door(model, temple * CFrame.new(0, 1.4, -5.05), 6, 8, { color = rgb(170, 60, 40), step = false })
	Archi.hipRoof(model, temple * CFrame.new(0, 13.4, 0), 26, 10, 4, 3, ORANGE, { trim = rgb(170, 60, 40), rafters = rgb(120, 50, 36) })
	Archi.walls(model, temple * CFrame.new(0, 16, 0), 14, 7, 5, rgb(240, 226, 190), { frame = rgb(170, 60, 40), spacing = 4.5 })
	Archi.gableRoof(model, temple * CFrame.new(0, 21, 0), 14, 7, 4, 2.6, ORANGE, { upturn = true, trim = rgb(170, 60, 40), gableFill = rgb(240, 226, 190) })
	Archi.sign(model, temple * CFrame.new(0, 10.6, -5.6), 12, 2.6, "天下一武道会", { bg = rgb(170, 50, 36), text = rgb(255, 230, 150) })
	-- tableau des combats
	local board = cf * CFrame.new(-size / 2 - 8, 0, size / 2 + 6)
	Archi.sign(model, board * CFrame.new(0, 9, 0) * CFrame.Angles(0, math.rad(-30), 0), 8, 6, "1 VS 2", { posts = 6, bg = rgb(30, 40, 60), text = rgb(255, 230, 120) })
	local _ = rng
	return model
end

-- Grande porte de pierre à orbes (route de la base 270°).
local function orbGate(parent: Instance, cf: CFrame): Model
	local model = Core.slot(parent, "PorteDesOrbes", cf, 34)
	for _, side in { -1, 1 } do
		local p = cf * CFrame.new(side * 13, 0, 0)
		Archi.block(model, "GatePillar", Vector3.new(5, 24, 5), p, rgb(200, 170, 120), Enum.Material.Sandstone)
		for _, y in { 6, 14, 22 } do
			Build.deco(model, "PillarBand", Vector3.new(5.4, 1, 5.4), p * CFrame.new(0, y, 0), rgb(176, 140, 96), { Material = Enum.Material.Sandstone })
		end
		local orb = Core.ball(model, "GateOrb", 5, (p * CFrame.new(0, 27.6, 0)).Position, ORANGE, Enum.Material.Glass)
		orb.Transparency = 0.1
		for k = 1, 4 do
			Build.deco(
				model,
				"OrbStar",
				Vector3.new(0.7, 0.7, 0.2),
				p * CFrame.new((k - 2.5) * 0.9, 27.6 + (k % 2) * 0.8, -2.45) * CFrame.Angles(0, 0, math.rad(45)),
				rgb(220, 40, 30),
				{
					Material = Enum.Material.Neon,
				}
			)
		end
		Core.light(orb, ORANGE, 18, 1.4)
	end
	Build.part(model, "GateBeam", Vector3.new(34, 3, 5), cf * CFrame.new(0, 22.6, 0), rgb(190, 160, 112), { Material = Enum.Material.Sandstone })
	Archi.sign(model, cf * CFrame.new(0, 18.6, -2.8), 14, 3, "PLANÈTE DES GUERRIERS", { bg = rgb(40, 60, 110), text = rgb(255, 220, 90) })
	return model
end

-- Tour céleste et palais flottant (repère géant au bord de l'île).
local function skyTower(parent: Instance, cf: CFrame): Model
	local model = Core.slot(parent, "TourCeleste", cf, 360)
	pcall(function()
		model.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	end)
	-- temple au pied
	Archi.plinth(model, cf, 40, 40, 3, rgb(200, 190, 170))
	Archi.walls(model, cf * CFrame.new(0, 3, 0), 26, 26, 12, rgb(236, 226, 200), { frame = rgb(170, 60, 40), spacing = 6.5 })
	Archi.tieredRoof(model, cf * CFrame.new(0, 15, 0), 26, 26, 2, 8, ORANGE, { trim = rgb(170, 60, 40) })
	-- la colonne
	local h = 250
	Core.vcyl(model, "Column", cf * CFrame.new(0, 15, 0), h, 10, rgb(236, 228, 210), Enum.Material.Marble)
	for k = 1, 24 do
		Core.vcyl(model, "ColumnRing", cf * CFrame.new(0, 15 + k * (h / 25), 0), 1.4, 11, rgb(206, 196, 176), Enum.Material.Marble, false)
	end
	-- maison bulbe au sommet
	local top = cf * CFrame.new(0, 15 + h, 0)
	Core.vcyl(model, "TopDeck", top, 2, 30, rgb(220, 210, 190), Enum.Material.Marble)
	Core.ellipsoid(model, "Bulb", Vector3.new(24, 26, 24), top * CFrame.new(0, 13, 0), rgb(236, 228, 210), Enum.Material.Marble)
	Core.ellipsoid(model, "BulbTop", Vector3.new(8, 10, 8), top * CFrame.new(0, 28, 0), ORANGE)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		porthole(model, top * CFrame.Angles(0, a, 0) * CFrame.new(0, 12, -12), 3, true)
	end
	-- fil vers le palais flottant
	Core.vcyl(model, "Pole", top * CFrame.new(0, 30, 0), 60, 1, rgb(220, 210, 190), Enum.Material.Metal, false)
	-- palais flottant
	local deck = top * CFrame.new(0, 96, 0)
	local plate = Build.part(
		model,
		"SkyDeck",
		Vector3.new(3, 130, 130),
		deck * CFrame.Angles(0, 0, math.rad(90)),
		rgb(230, 222, 204),
		{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Marble }
	)
	plate.CastShadow = true
	Core.ellipsoid(model, "SkyRock", Vector3.new(124, 60, 124), deck * CFrame.new(0, -14, 0), rgb(200, 170, 120), Enum.Material.Sandstone)
	Core.ellipsoid(model, "SkyRockTip", Vector3.new(50, 50, 50), deck * CFrame.new(0, -40, 0), rgb(180, 150, 104), Enum.Material.Sandstone)
	Core.ball(model, "PalaceDome", 34, (deck * CFrame.new(0, 2, 10)).Position, WHITE, Enum.Material.Marble)
	for _, x in { -1, 1 } do
		Core.vcyl(model, "PalaceTower", deck * CFrame.new(x * 24, 1.5, 14), 22, 7, WHITE, Enum.Material.Marble)
		Core.ellipsoid(model, "PalaceTowerTop", Vector3.new(9, 9, 9), deck * CFrame.new(x * 24, 24, 14), ORANGE)
	end
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		Nature.tree("Palmier", model, (deck * CFrame.new(math.cos(a) * 52, 1.5, math.sin(a) * 52)).Position, { rng = Random.new(i + 3), height = 20, detail = "low" })
	end
	return model
end

-- Petite île à la maison rose (horizon).
local function pinkHouseIsland(parent: Instance, center: Vector3, rng: Random)
	local model = Core.slot(parent, "IleMaisonRose", CFrame.new(center), 30)
	Build.part(model, "Islet", Vector3.new(60, 60, 60), CFrame.new(center + UP * -24), rgb(236, 220, 170), { Shape = Enum.PartType.Ball, Material = Enum.Material.Sand })
	local base = CFrame.new(center + UP * 5.8)
	Archi.walls(model, base, 16, 12, 9, rgb(240, 150, 170), { band = rgb(250, 250, 240) })
	Archi.windowRow(model, base * CFrame.new(0, 5, -6.05), 16, 2, 2.6, 2.6, { frame = rgb(250, 250, 240) })
	Archi.door(model, base * CFrame.new(0, 0, -6.05), 3.4, 6.4, { color = rgb(120, 70, 50) })
	Archi.hipRoof(model, base * CFrame.new(0, 9, 0), 16, 12, 5, 1.6, rgb(200, 60, 50), { trim = rgb(150, 40, 36) })
	Archi.sign(model, base * CFrame.new(0, 11, -7.4), 7, 1.6, "KAME", { bg = rgb(250, 250, 240), text = rgb(200, 50, 40) })
	Nature.tree("Palmier", model, center + Vector3.new(14, 5.8, 6), { rng = rng, height = 22, detail = "normal" })
	Nature.tree("Palmier", model, center + Vector3.new(-12, 5.8, 9), { rng = rng, height = 18, detail = "normal" })
end

------------------------------------------------------------------------
-- Construction du décor
------------------------------------------------------------------------

local TOWER_ANGLE = 270
local TOWER_RADIUS = 650

function Saiyan.build(decor: Instance, rng: Random, _theme)
	local ring = Build.folder(decor, "Anneau")
	local island = Build.folder(decor, "Ile")
	local horizon = Build.folder(decor, "Horizon")
	local quarter = Build.folder(ring, "Quartier")

	-- 1) Quartier de maisons-dômes et maisons-capsules.
	local accents = { BLUE, rgb(220, 70, 60), rgb(80, 170, 110), ORANGE, rgb(150, 90, 200) }
	local number = 1
	for i = 0, 35 do
		local angle = i * 10 + 5 + rng:NextNumber(-2, 2)
		local outer = i % 2 == 0
		local pos = polar(angle, outer and 314 or 292)
		local inTournament = Common.angleDiff(angle, 120) < 14 or Common.angleDiff(angle, 60) < 12
		if not Layout.onPath(pos, 12) and not inTournament and not Layout.inBossArena(pos, 16) then
			local cf = facing(angle, outer and 314 or 292, TOP_RING)
			if rng:NextNumber() < 0.7 then
				domeHouse(quarter, cf, rng:NextNumber(16, 24), accents[rng:NextInteger(1, #accents)], rng)
			else
				capsuleHouse(quarter, cf, accents[rng:NextInteger(1, #accents)], number, rng)
				number += 1
			end
		end
	end
	Common.ringStreet(quarter, 264, 280, "dalle", rng)
	-- lampadaires ronds et petits jardins
	Common.alongRoads({ 110, 200, 262 }, 5, function(pos)
		Core.vcyl(quarter, "LampPost", CFrame.new(pos), 9, 0.6, rgb(230, 230, 226), Enum.Material.Metal)
		local lamp = Core.ball(quarter, "Lamp", 2, pos + UP * 10, rgb(255, 236, 190), Enum.Material.Neon)
		Core.light(lamp, rgb(255, 230, 180), 18, 1.1)
	end)

	-- 1 bis) Siège de la Capsule Corporation (secteur 60°) et voitures volantes dans les rues.
	capsuleCorp(ring, facing(60, 300, TOP_RING), rng)
	local carColors = { rgb(240, 200, 60), rgb(220, 70, 60), rgb(70, 140, 220), rgb(250, 250, 248), rgb(120, 200, 120) }
	for k = 0, 13 do
		local angle = k * 25.7 + 9
		local pos = polar(angle, 272, TOP_RING)
		if not Layout.onPath(pos, 8) and not Layout.inBossArena(pos, 10) and Common.angleDiff(angle, 120) > 16 then
			local tangent = Vector3.new(-pos.Z, 0, pos.X).Unit
			hoverCar(quarter, CFrame.lookAt(pos, pos + tangent), carColors[k % #carColors + 1])
		end
	end
	for _, angle in { 24, 98, 166, 232, 300 } do
		Props.vendingMachine(quarter, facing(angle, 282, TOP_RING) * CFrame.Angles(0, math.pi, 0), rgb(60, 110, 200))
		Props.bench(quarter, facing(angle + 2.4, 282, TOP_RING) * CFrame.Angles(0, math.pi, 0))
	end

	-- 2) Arène du tournoi (secteur 120°).
	tournament(ring, facing(120, 296, TOP_RING), rng)

	-- 3) Pics rocheux, capsules écrasées, arbres ronds.
	for _, spec in { { 18, 172, 46 }, { 64, 240, 58 }, { 160, 176, 40 }, { 196, 238, 52 }, { 248, 174, 44 }, { 306, 238, 62 }, { 340, 176, 38 }, { 100, 104, 30 } } do
		local pos = polar(spec[1], spec[2], TOP_RING)
		if Common.ringFree(pos, 10) then
			spire(ring, pos, spec[3], rng:NextNumber(12, 18), rng)
		end
	end
	for _, spec in { { 44, 140 }, { 222, 206 }, { 282, 140 } } do
		local pos = polar(spec[1], spec[2], TOP_RING)
		if Common.ringFree(pos, 14) then
			crashPod(ring, pos, rng)
		end
	end
	Core.scatter(rng, 50, Vector3.zero, Layout.RingInner + 6, Layout.RingOuter - 30, function(p)
		return Common.ringFree(p, 6) and not Common.inBand(p, -6)
	end, function(p)
		Nature.tree("ArbreRond", ring, p + UP * TOP_RING, { rng = rng, height = rng:NextNumber(14, 22), detail = "normal" })
	end)
	Core.scatter(rng, 60, Vector3.zero, Layout.RingInner + 6, Layout.RingOuter - 6, function(p)
		return Common.ringFree(p, 4)
	end, function(p)
		if rng:NextNumber() < 0.45 then
			Nature.bush(ring, p + UP * TOP_RING, { rng = rng, height = rng:NextNumber(3, 4.5), palette = "guerrier" })
		else
			Nature.rock(ring, p + UP * TOP_RING, rng:NextNumber(2.5, 6), { rng = rng, color = SAND, material = Enum.Material.Sandstone })
		end
	end)
	Common.ringGround(ring, rng, { patches = 30, tufts = 220, flowers = 50, flowerColors = { rgb(250, 250, 240), rgb(250, 200, 90) }, patchRole = "herbe" })

	-- 4) Grande porte sur la route 270°, arches simples sur les autres routes.
	orbGate(ring, facing(270, Layout.RingFenceRadius + 3, TOP_RING))
	for _, plotAngle in Layout.PlotAngles do
		local deg = math.deg(plotAngle)
		if Common.angleDiff(deg, 270) > 5 then
			local cf = facing(deg, Layout.RingFenceRadius + 2, TOP_RING)
			for _, side in { -1, 1 } do
				Archi.block(ring, "ArchPillar", Vector3.new(3, 14, 3), cf * CFrame.new(side * 10.5, 0, 0), rgb(200, 170, 120), Enum.Material.Sandstone)
				local orb = Core.ball(ring, "ArchOrb", 3, (cf * CFrame.new(side * 10.5, 15.6, 0)).Position, ORANGE, Enum.Material.Glass)
				orb.Transparency = 0.1
				Core.light(orb, ORANGE, 12, 1)
			end
			Build.part(ring, "ArchBeam", Vector3.new(24, 1.6, 2.6), cf * CFrame.new(0, 13.4, 0), rgb(190, 160, 112), { Material = Enum.Material.Sandstone })
		end
	end

	-- 5) Île : prairies, bosquets d'arbres ronds, mesas et aiguilles.
	local free = Common.islandFree({ { polar(TOWER_ANGLE, 650), 60 } })
	Common.forest(island, rng, {
		groves = 40,
		perGrove = { 6, 10 },
		radius = { 22, 40 },
		free = free,
		spacing = 0.38,
		species = {
			{ "ArbreRond", 6, 14, 26 },
			{ "ArbreRond", 2, 20, 30, "clair" },
			{ "Palmier", 1, 18, 26 },
			{ "ArbreFeuillu", 1, 18, 26, "guerrier" },
		},
		undergrowth = { palette = "guerrier", rocks = SAND, flowers = { rgb(250, 250, 240) } },
	})
	Core.scatter(rng, 16, Vector3.zero, Layout.WalkwayOuter + 30, Layout.IslandRadius - 30, function(p)
		return free(p, 18)
	end, function(p)
		spire(island, Common.ground(p), rng:NextNumber(30, 80), rng:NextNumber(14, 24), rng)
	end)
	-- cratères de combat
	Core.scatter(rng, 7, Vector3.zero, Layout.WalkwayOuter + 30, Layout.IslandRadius - 30, function(p)
		return free(p, 20)
	end, function(p)
		battleCrater(island, Common.ground(p), rng:NextNumber(9, 15), rng)
	end)
	skyTower(horizon, facing(TOWER_ANGLE, TOWER_RADIUS))

	-- 6) Horizon : aiguilles rocheuses dans la mer et l'île à la maison rose.
	for i = 0, 19 do
		local angle = i * 18 + rng:NextNumber(-5, 5)
		if Common.angleDiff(angle, TOWER_ANGLE) > 14 and Common.angleDiff(angle, 100) > 10 then
			local pos = polar(angle, rng:NextNumber(Layout.HorizonInner + 40, Layout.HorizonOuter - 40), -4)
			spire(horizon, pos, rng:NextNumber(60, 150), rng:NextNumber(30, 60), rng)
		end
	end
	pinkHouseIsland(horizon, polar(100, 770, -1), rng)

	-- 7) Lampes de la promenade et étincelles de ki.
	Common.walkwayLamps(ring, 15, function(pos)
		Core.vcyl(ring, "LampPost", CFrame.new(pos), 9, 0.6, rgb(230, 230, 226), Enum.Material.Metal)
		local lamp = Core.ball(ring, "Lamp", 2, pos + UP * 10, rgb(255, 236, 190), Enum.Material.Neon)
		Core.light(lamp, rgb(255, 230, 180), 18, 1.1)
	end)
	local ki = Common.ambient(decor, "Ki", {
		colors = ColorSequence.new(rgb(255, 230, 90), rgb(255, 160, 40)),
		size = 0.5,
		rate = 30,
		speed = NumberRange.new(2, 4),
		direction = Enum.NormalId.Top,
		y = 0.5,
		radius = 360,
		lightEmission = 1,
	})
	CollectionService:AddTag(ki.Parent, "Ambiance")
end

return Saiyan
