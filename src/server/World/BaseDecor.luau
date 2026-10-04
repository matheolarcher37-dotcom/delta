-- DÉCO DE BASE PAR UNIVERS : sol, murs d'enceinte, portail (avec le panneau du propriétaire)
-- et accessoires de la bande extérieure de chaque base changent avec l'univers (toutes les 30 min).
-- Les éléments de jeu (machine, cases, boutons, coffre...) ne bougent jamais.
--
--   Village Ninja      : enceinte bois et crépi, toits rouges, portail ninja « あ / ん », lanternes,
--                        bannières à spirale
--   Monde Occulte      : bois sombre, grand torii, lanternes de pierre, sceaux, accents violets
--   Planète Guerrière  : dômes façon Capsule, murets blancs à bandes bleues, Dragon Balls
--   Grand Océan        : pont de navire, quai, bastingage, mâts et voile, tonneaux, canons
--   Ère des Pourfendeurs : manoir (crépi blanc et poutres noires), glycines, bannières à damier
--
-- Fonctionnement : chaque univers a un MODÈLE de déco construit une fois (repère local de base,
-- centre au sol en (0, 0, 0), -Z = entrée) et rangé dans ServerStorage.DecorsBase.<univers>.
-- POUR RETOUCHER la déco dans Studio : modifie ServerStorage > DecorsBase > <univers> (le jeu
-- le recopie dans chaque base). Le dossier « Decor » de chaque base est la copie affichée.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Build = require(script.Parent.Parent.Modules.Build)
local Kit = require(script.Parent.Parent.Modules.TycoonKit)

local BaseDecor = {}

local rgb = Color3.fromRGB
local H = Layout.PlotSize / 2 -- 70
local W = H - 5 -- ligne des murs (milieu de la bande de 10 studs)
local GATE = 11 -- demi-ouverture du portail
local FLOOR = 0.2 -- dessus du sol de la base

BaseDecor.FloorY = FLOOR
local registered = {}

------------------------------------------------------------------------
-- Outils communs
------------------------------------------------------------------------

local function P(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- Tronçons de mur (repère local) : de part et d'autre du portail, puis les trois autres côtés.
local function wallRuns()
	return {
		{ Vector3.new(-W, 0, -W), Vector3.new(-GATE - 2, 0, -W) },
		{ Vector3.new(GATE + 2, 0, -W), Vector3.new(W, 0, -W) },
		{ Vector3.new(W, 0, -W), Vector3.new(W, 0, W) },
		{ Vector3.new(W, 0, W), Vector3.new(-W, 0, W) },
		{ Vector3.new(-W, 0, W), Vector3.new(-W, 0, -W) },
	}
end

-- CFrame d'un tronçon : centre, longueur sur X local, +Z local vers l'intérieur de la base.
local function runFrame(a: Vector3, b: Vector3): (CFrame, number)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	local up = Vector3.new(0, 1, 0)
	local inward = -Vector3.new(mid.X, 0, mid.Z).Unit
	return CFrame.fromMatrix(mid, up:Cross(inward), up, inward), length
end

-- Mur générique : soubassement, corps, chaperon (toit à 2 pans ou simple couvertine), poteaux.
local function themedWall(model: Instance, spec)
	for _, run in wallRuns() do
		local cf, length = runFrame(run[1], run[2])
		local seg = Build.model(model, "Mur")
		local baseH, bodyH = spec.baseH, spec.bodyH
		local t = spec.thickness or 2.2
		Build.part(seg, "Soubassement", Vector3.new(length + t, baseH, t + 0.6), cf * P(0, baseH / 2, 0), spec.baseColor, { Material = spec.baseMat })
		if bodyH > 0 then
			Build.part(seg, "Corps", Vector3.new(length + t * 0.6, bodyH, t), cf * P(0, baseH + bodyH / 2, 0), spec.bodyColor, { Material = spec.bodyMat })
		end
		local topY = baseH + bodyH
		if spec.roofColor then
			Kit.roof(seg, cf * P(0, topY, 0), length + t + 1, t + 2.4, spec.roofH or 1.3, spec.roofColor, { curve = false, name = "Chaperon" })
		elseif spec.capColor then
			Build.part(seg, "Couvertine", Vector3.new(length + t + 0.4, 0.5, t + 0.5), cf * P(0, topY + 0.25, 0), spec.capColor, { Material = spec.capMat or Enum.Material.Slate })
		end
		if spec.stripe then
			for _, side in { -1, 1 } do
				Build.deco(seg, "Bande", Vector3.new(length + t * 0.6, spec.stripe.h, 0.12), cf * P(0, spec.stripe.y, side * (t / 2 + 0.06)), spec.stripe.color, {
					Material = spec.stripe.mat or Enum.Material.SmoothPlastic,
				})
			end
		end
		if spec.postColor then
			local every = spec.postEvery or 8
			local n = math.max(1, math.floor(length / every + 0.5))
			for i = 0, n do
				local x = -length / 2 + length * i / n
				local postH = spec.postHeight or (topY + 0.6)
				if spec.postShape == "round" then
					Build.part(seg, "Poteau", Vector3.new(postH, spec.postSize or 1.6, spec.postSize or 1.6), cf * P(x, postH / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), spec.postColor, {
						Shape = Enum.PartType.Cylinder,
						Material = spec.postMat or Enum.Material.Wood,
					})
					if spec.postCap then
						Build.ball(seg, "Boule", (spec.postSize or 1.6) * 1.2, (cf * P(x, postH + 0.5, 0)).Position, spec.postCap, { Material = Enum.Material.SmoothPlastic })
					end
				else
					Build.deco(seg, "Poteau", Vector3.new(spec.postSize or 0.7, bodyH, t + 0.15), cf * P(x, baseH + bodyH / 2, 0), spec.postColor, { Material = spec.postMat or Enum.Material.Wood })
				end
				if spec.onPost then
					spec.onPost(seg, cf * P(x, 0, 0), i, n)
				end
			end
		end
		if spec.onRun then
			spec.onRun(seg, cf, length)
		end
	end
end

-- Sol : grande dalle + bande extérieure + allée de l'entrée + cour des unités.
local function floor(model: Instance, spec)
	local ground = Build.model(model, "Sol")
	Build.part(ground, "Dalle", Vector3.new(H * 2, 1, H * 2), P(0, FLOOR - 0.5, 0), spec.main[1], { Material = spec.main[2] })
	if spec.band then
		for _, side in { -1, 1 } do
			Build.part(ground, "Bande", Vector3.new(H * 2, 0.1, 10), P(0, FLOOR + 0.02, side * (H - 5)), spec.band[1], { Material = spec.band[2] })
			Build.part(ground, "Bande", Vector3.new(10, 0.1, H * 2 - 20), P(side * (H - 5), FLOOR + 0.02, 0), spec.band[1], { Material = spec.band[2] })
		end
	end
	if spec.path then
		Build.part(ground, "Allee", Vector3.new(16, 0.12, 32), P(0, FLOOR + 0.03, -H + 16), spec.path[1], { Material = spec.path[2] })
		-- Allées latérales vers les côtés de la base.
		Build.part(ground, "AlleeTransversale", Vector3.new(H * 2 - 22, 0.1, 8), P(0, FLOOR + 0.025, -19.5), spec.path[1], { Material = spec.path[2] })
		Build.part(ground, "AlleeFond", Vector3.new(H * 2 - 22, 0.1, 6), P(0, FLOOR + 0.025, 34), spec.path[1], { Material = spec.path[2] })
	end
	if spec.court then
		Build.part(ground, "Cour", Vector3.new(70, 0.11, 46), P(0, FLOOR + 0.028, 7), spec.court[1], { Material = spec.court[2] })
	end
	return ground
end

-- Panneau du propriétaire (deux faces) : « BASE DE ... » / « BASE LIBRE ».
local function ownerSign(model: Instance, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, textColor: Color3?)
	local sign = Build.part(model, "OwnerSign", size, cf, color, { Material = material or Enum.Material.Wood })
	Build.surfaceText(sign, Enum.NormalId.Front, "BASE LIBRE", textColor or rgb(255, 255, 255))
	Build.surfaceText(sign, Enum.NormalId.Back, "BASE LIBRE", textColor or rgb(255, 255, 255))
	return sign
end

local function emblemText(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?)
	return Build.surfaceText(part, face, text, color, { Font = font or Enum.Font.GothamBlack })
end

-- Lanterne de papier SANS lumière (les lumières sont limitées pour les performances).
local function chochin(parent: Instance, cf: CFrame, color: Color3, s: number?)
	local k = s or 1
	Kit.blob(parent, "Chochin", Vector3.new(1.4, 1.8, 1.4) * k, cf, color, { Material = Enum.Material.Neon })
	Build.deco(parent, "ChochinHaut", Vector3.new(0.9, 0.25, 0.9) * k, cf * P(0, 0.95 * k, 0), rgb(30, 25, 25))
	Build.deco(parent, "ChochinBas", Vector3.new(0.9, 0.25, 0.9) * k, cf * P(0, -0.95 * k, 0), rgb(30, 25, 25))
end

local function corners(): { Vector3 }
	return { Vector3.new(-W, 0, -W), Vector3.new(W, 0, -W), Vector3.new(W, 0, W), Vector3.new(-W, 0, W) }
end

-- Positions régulières dans la bande intérieure (entre la zone de jeu et le mur), hors entrée.
local function innerBandSpots(spacing: number): { CFrame }
	local list = {}
	local d = W - 3.2
	for x = -d + 6, d - 6, spacing do
		if math.abs(x) > GATE + 6 then
			table.insert(list, P(x, FLOOR, -d))
		end
		table.insert(list, P(x, FLOOR, d) * CFrame.Angles(0, math.pi, 0))
	end
	for z = -d + 6, d - 6, spacing do
		table.insert(list, P(-d, FLOOR, z) * CFrame.Angles(0, math.rad(90), 0))
		table.insert(list, P(d, FLOOR, z) * CFrame.Angles(0, math.rad(-90), 0))
	end
	return list
end

------------------------------------------------------------------------
-- VILLAGE NINJA
------------------------------------------------------------------------

local function spiralBanner(parent: Instance, cf: CFrame, color: Color3)
	local banner = Kit.nobori(parent, cf, color, 11, rgb(255, 245, 210))
	local cloth = banner:FindFirstChild("Tissu") :: BasePart?
	if cloth then
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			emblemText(cloth, face, "🌀", rgb(255, 255, 255))
		end
	end
	return banner
end

local function buildNinja(model: Model, rng: Random)
	floor(model, {
		main = { rgb(200, 164, 116), Enum.Material.Ground },
		band = { rgb(110, 172, 74), Enum.Material.Grass },
		path = { rgb(172, 164, 152), Enum.Material.Cobblestone },
		court = { rgb(224, 202, 160), Enum.Material.Sandstone },
	})
	local roofRed = rgb(186, 48, 40)
	themedWall(model, {
		baseH = 1.8,
		baseColor = rgb(150, 145, 138),
		baseMat = Enum.Material.Cobblestone,
		bodyH = 6,
		bodyColor = rgb(240, 230, 204),
		bodyMat = Enum.Material.Plaster,
		roofColor = roofRed,
		roofH = 1.5,
		postColor = rgb(110, 72, 46),
		postEvery = 8,
		onPost = function(seg, cf, i)
			if i % 2 == 0 then
				chochin(seg, cf * P(0, 6.4, 2.2), rgb(235, 70, 50), 0.8)
			end
		end,
	})
	-- Tourelles d'angle à toit rouge.
	for _, c in corners() do
		local t = Build.model(model, "Tourelle")
		local cf = CFrame.new(c)
		Build.part(t, "Base", Vector3.new(7, 2.2, 7), cf * P(0, 1.1, 0), rgb(150, 145, 138), { Material = Enum.Material.Cobblestone })
		Build.part(t, "Corps", Vector3.new(6, 8, 6), cf * P(0, 6.2, 0), rgb(240, 230, 204), { Material = Enum.Material.Plaster })
		for _, x in { -3, 3 } do
			for _, z in { -3, 3 } do
				Build.deco(t, "Arete", Vector3.new(0.6, 8, 0.6), cf * P(x, 6.2, z), rgb(110, 72, 46), { Material = Enum.Material.Wood })
			end
		end
		Kit.eave(t, cf * P(0, 10.2, 0), 6, 1.8, 1.6, roofRed)
		Kit.roof(t, cf * P(0, 11.8, 0), 4.6, 4.6, 2.4, roofRed, { ornament = true })
	end
	-- Portail ninja : piliers massifs, portes vertes ouvertes « あ » / « ん », toit rouge, emblème.
	local gate = Build.model(model, "Portail")
	local g = P(0, 0, -W)
	for _, side in { -1, 1 } do
		Build.part(gate, "Pilier", Vector3.new(3, 17, 3), g * P(side * (GATE + 1.5), 8.5, 0), rgb(150, 100, 60), { Material = Enum.Material.Wood })
		Build.part(gate, "PiedPilier", Vector3.new(3.8, 1.4, 3.8), g * P(side * (GATE + 1.5), 0.7, 0), rgb(120, 115, 108), { Material = Enum.Material.Cobblestone })
		local door = Build.part(gate, "Porte", Vector3.new(10, 13, 0.8), g * P(side * (GATE - 0.2), 6.7, 1.8) * CFrame.Angles(0, side * math.rad(78), 0) * P(side * -5, 0, 0), rgb(70, 120, 74), {
			Material = Enum.Material.WoodPlanks,
		})
		emblemText(door, Enum.NormalId.Front, side < 0 and "あ" or "ん", rgb(255, 230, 120), Enum.Font.GothamBlack)
	end
	Build.part(gate, "Linteau", Vector3.new(GATE * 2 + 8, 2, 3.6), g * P(0, 16.5, 0), rgb(150, 100, 60), { Material = Enum.Material.Wood })
	Build.part(gate, "Linteau2", Vector3.new(GATE * 2 + 5, 1.2, 3.2), g * P(0, 14.2, 0), rgb(120, 78, 48), { Material = Enum.Material.Wood })
	Kit.roof(gate, g * P(0, 17.5, 0), GATE * 2 + 12, 7, 3, roofRed, { ornament = true, name = "ToitPortail" })
	ownerSign(gate, g * P(0, 11.6, -0.2), Vector3.new(16, 3.4, 0.7), rgb(96, 62, 40), Enum.Material.Wood, rgb(255, 235, 170))
	local disc = Build.part(gate, "Embleme", Vector3.new(0.6, 5, 5), g * P(0, 21.6, -1.2) * CFrame.Angles(0, math.rad(90), 0), rgb(240, 120, 30), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.SmoothPlastic,
	})
	emblemText(disc, Enum.NormalId.Right, "🍃", rgb(255, 255, 255))
	emblemText(disc, Enum.NormalId.Left, "🍃", rgb(255, 255, 255))
	Kit.light(disc, rgb(255, 170, 80), 22, 1.2)
	-- Bannières à spirale et lanternes de pierre.
	for i, cf in innerBandSpots(26) do
		if i % 2 == 0 then
			spiralBanner(model, cf, rgb(250, 130, 30))
		end
	end
	for _, side in { -1, 1 } do
		spiralBanner(model, P(side * (GATE + 5), FLOOR, -W + 3) * CFrame.Angles(0, side > 0 and math.pi or 0, 0), rgb(250, 130, 30))
		Kit.toro(model, P(side * (GATE + 5), FLOOR, -W - 4), 1.1)
	end
	-- Arbres dans les coins de la bande extérieure.
	for _, x in { -1, 1 } do
		for _, z in { -40, 0, 40 } do
			Build.tree(model, Vector3.new(x * (H + 1), FLOOR, z), 1.1, rgb(80, 150, 60), nil, rng)
		end
	end
end

------------------------------------------------------------------------
-- MONDE OCCULTE (Jujutsu / Gojo)
------------------------------------------------------------------------

local function ofuda(parent: Instance, cf: CFrame)
	local paper = Build.deco(parent, "Sceau", Vector3.new(0.9, 2.4, 0.08), cf, rgb(244, 238, 220), { Material = Enum.Material.SmoothPlastic })
	emblemText(paper, Enum.NormalId.Front, "封", rgb(200, 30, 40), Enum.Font.GothamBlack)
	emblemText(paper, Enum.NormalId.Back, "封", rgb(200, 30, 40), Enum.Font.GothamBlack)
	return paper
end

local function buildOcculte(model: Model, rng: Random)
	local purple = rgb(150, 80, 255)
	floor(model, {
		main = { rgb(70, 70, 82), Enum.Material.Slate },
		band = { rgb(150, 150, 156), Enum.Material.Pebble },
		path = { rgb(96, 94, 106), Enum.Material.Cobblestone },
		court = { rgb(118, 114, 126), Enum.Material.Pebble },
	})
	themedWall(model, {
		baseH = 1.6,
		baseColor = rgb(90, 90, 100),
		baseMat = Enum.Material.Cobblestone,
		bodyH = 6.4,
		bodyColor = rgb(58, 42, 38),
		bodyMat = Enum.Material.WoodPlanks,
		roofColor = rgb(36, 36, 46),
		roofH = 1.4,
		postColor = rgb(26, 20, 20),
		postEvery = 9,
		stripe = { y = 7.7, h = 0.25, color = purple, mat = Enum.Material.Neon },
		onPost = function(seg, cf, i)
			if i % 2 == 1 then
				ofuda(seg, cf * P(0, 5, 1.25))
			end
		end,
	})
	-- Grand torii sombre avec corde sacrée (shimenawa) et papiers en zigzag.
	local gate = Build.model(model, "Portail")
	local g = P(0, 0, -W)
	local red = rgb(150, 28, 34)
	for _, side in { -1, 1 } do
		Build.part(gate, "Pilier", Vector3.new(19, 2.4, 2.4), g * P(side * (GATE + 1), 9.5, 0) * CFrame.Angles(0, 0, math.rad(90)), red, {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.SmoothPlastic,
		})
		Build.part(gate, "Socle", Vector3.new(3.4, 1.6, 3.4), g * P(side * (GATE + 1), 0.8, 0), rgb(30, 28, 32), { Material = Enum.Material.Slate })
	end
	Build.part(gate, "Nuki", Vector3.new(GATE * 2 + 6, 1.4, 1.4), g * P(0, 14, 0), red, { Material = Enum.Material.SmoothPlastic })
	Build.part(gate, "Kasagi", Vector3.new(GATE * 2 + 12, 1.6, 2.6), g * P(0, 18.6, 0), rgb(24, 22, 26), { Material = Enum.Material.SmoothPlastic })
	Build.part(gate, "Shimaki", Vector3.new(GATE * 2 + 10, 1.2, 2.2), g * P(0, 17.3, 0), red, { Material = Enum.Material.SmoothPlastic })
	for _, side in { -1, 1 } do
		Build.wedge(gate, "Bec", Vector3.new(2.6, 1.2, 2.6), g * P(side * (GATE + 7.2), 19.6, 0) * CFrame.Angles(0, side > 0 and math.rad(90) or math.rad(-90), 0), rgb(24, 22, 26))
	end
	ownerSign(gate, g * P(0, 15.9, -0.9), Vector3.new(12, 2.4, 0.5), rgb(20, 18, 24), Enum.Material.Wood, rgb(210, 170, 255))
	local rope = Build.part(gate, "Shimenawa", Vector3.new(GATE * 2 + 2, 1.1, 1.1), g * P(0, 12.4, 0), rgb(214, 186, 120), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Fabric })
	local _ = rope
	for k = -3, 3 do
		Build.deco(gate, "Shide", Vector3.new(0.6, 1.8, 0.08), g * P(k * 3, 11.1, -0.6) * CFrame.Angles(0, 0, math.rad(k % 2 == 0 and 8 or -8)), rgb(250, 250, 245))
	end
	local seal = Build.part(gate, "SceauCentral", Vector3.new(3, 3, 0.3), g * P(0, 9.4, -0.4) * CFrame.Angles(0, 0, math.rad(45)), purple, { Material = Enum.Material.Neon })
	Kit.light(seal, purple, 20, 1.6)
	-- Lanternes de pierre à lueur violette, petits sanctuaires dans les coins.
	for i, cf in innerBandSpots(18) do
		if i % 2 == 1 then
			Kit.toro(model, cf, 0.9, rgb(180, 120, 255))
		end
	end
	for _, side in { -1, 1 } do
		Kit.toro(model, P(side * (GATE + 5), FLOOR, -W - 3.5), 1.2, rgb(180, 120, 255))
	end
	for _, c in corners() do
		local shrine = Build.model(model, "Hokora")
		local cf = CFrame.new(c.X - math.sign(c.X) * 0.5, FLOOR, c.Z - math.sign(c.Z) * 0.5) * CFrame.Angles(0, math.atan2(c.X, c.Z), 0)
		Build.part(shrine, "Socle", Vector3.new(6, 2, 6), cf * P(0, 1, 0), rgb(80, 80, 90), { Material = Enum.Material.Slate })
		Build.part(shrine, "Corps", Vector3.new(4, 4, 4), cf * P(0, 4, 0), rgb(50, 36, 32), { Material = Enum.Material.WoodPlanks })
		Kit.roof(shrine, cf * P(0, 6, 0), 5.6, 6, 2, rgb(36, 36, 46), { ornament = false })
		local flame = Build.deco(shrine, "FlammeMaudite", Vector3.new(1.2, 1.6, 1.2), cf * P(0, 9.6, 0), purple, { Material = Enum.Material.Neon })
		Kit.particles(flame, {
			Color = ColorSequence.new(rgb(190, 120, 255)),
			Texture = "rbxasset://textures/particles/fire_main.dds",
			Size = NumberSequence.new(1.2, 0),
			Rate = 10,
			Lifetime = NumberRange.new(0.6, 1),
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(10, 10),
		})
	end
	local _ = rng
end

------------------------------------------------------------------------
-- PLANÈTE GUERRIÈRE (dômes façon Capsule)
------------------------------------------------------------------------

local function dragonBall(parent: Instance, position: Vector3, stars: number)
	local ball = Build.ball(parent, "DragonBall", 1.8, position, rgb(255, 150, 30), { Material = Enum.Material.Glass, Transparency = 0.1 })
	local stand = Build.part(parent, "Support", Vector3.new(1.6, 1.4, 1.6), CFrame.new(position - Vector3.new(0, 1.5, 0)), rgb(230, 230, 236), { Material = Enum.Material.Concrete })
	local _ = stand
	local star = Build.deco(parent, "Etoiles", Vector3.new(1.2, 1.2, 0.05), CFrame.new(position + Vector3.new(0, 0, -0.92)), rgb(255, 150, 30), { Transparency = 1 })
	emblemText(star, Enum.NormalId.Front, string.rep("★", stars), rgb(220, 30, 30))
	return ball
end

local function capsuleDome(parent: Instance, cf: CFrame, radius: number, label: string?)
	local dome = Build.model(parent, "Dome")
	Build.ball(dome, "Coque", radius * 2, (cf * P(0, 0, 0)).Position, rgb(246, 246, 250), { Material = Enum.Material.SmoothPlastic })
	Build.part(dome, "Ceinture", Vector3.new(0.8, radius * 2.04, radius * 2.04), cf * P(0, radius * 0.38, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(60, 120, 220), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.SmoothPlastic,
	})
	for k = 0, 2 do
		local a = math.rad(-40 + k * 40)
		local pos = cf * CFrame.Angles(0, a, 0) * P(0, radius * 0.62, -radius * 0.78)
		Build.part(dome, "Hublot", Vector3.new(0.3, 1.6, 1.6), pos * CFrame.Angles(0, math.rad(90), 0), rgb(40, 60, 90), {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Glass,
			Transparency = 0.1,
		})
	end
	local door = Build.part(dome, "Porte", Vector3.new(2.6, 3.6, 0.4), cf * P(0, 1.8, -radius + 0.4), rgb(70, 80, 100), { Material = Enum.Material.Metal })
	if label then
		local plate = Build.part(dome, "Logo", Vector3.new(5, 1.2, 0.2), cf * P(0, radius * 1.05, -radius * 0.42) * CFrame.Angles(math.rad(-30), 0, 0), rgb(246, 246, 250), { Transparency = 1 })
		emblemText(plate, Enum.NormalId.Front, label, rgb(60, 120, 220), Enum.Font.GothamBlack)
	end
	local _ = door
	return dome
end

local function buildSaiyan(model: Model, rng: Random)
	local blue = rgb(60, 120, 220)
	floor(model, {
		main = { rgb(214, 214, 220), Enum.Material.Concrete },
		band = { rgb(96, 190, 80), Enum.Material.Grass },
		path = { rgb(236, 236, 240), Enum.Material.Concrete },
		court = { rgb(170, 186, 210), Enum.Material.Slate },
	})
	themedWall(model, {
		baseH = 0.8,
		baseColor = rgb(200, 200, 208),
		baseMat = Enum.Material.Concrete,
		bodyH = 3.4,
		bodyColor = rgb(246, 246, 250),
		bodyMat = Enum.Material.SmoothPlastic,
		capColor = rgb(230, 230, 236),
		capMat = Enum.Material.SmoothPlastic,
		thickness = 1.6,
		stripe = { y = 2.6, h = 0.7, color = blue },
		postColor = rgb(246, 246, 250),
		postShape = "round",
		postSize = 2,
		postCap = rgb(255, 150, 30),
		postEvery = 12,
		postMat = Enum.Material.SmoothPlastic,
	})
	-- Dômes dans les angles.
	for i, c in corners() do
		local cf = CFrame.new(c.X - math.sign(c.X) * 0.5, FLOOR, c.Z - math.sign(c.Z) * 0.5) * CFrame.Angles(0, math.atan2(-c.X, -c.Z), 0)
		capsuleDome(model, cf, 5, i % 2 == 0 and "CAPSULE" or nil)
	end
	-- Portail futuriste : piliers arrondis, arche bleue lumineuse, Dragon Ball au sommet.
	local gate = Build.model(model, "Portail")
	local g = P(0, 0, -W)
	for _, side in { -1, 1 } do
		Build.part(gate, "Pilier", Vector3.new(14, 3.2, 3.2), g * P(side * (GATE + 1.6), 7, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(246, 246, 250), {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.SmoothPlastic,
		})
		Build.ball(gate, "Sommet", 3.4, (g * P(side * (GATE + 1.6), 14, 0)).Position, rgb(246, 246, 250), { Material = Enum.Material.SmoothPlastic })
		Build.part(gate, "Anneau", Vector3.new(0.6, 3.5, 3.5), g * P(side * (GATE + 1.6), 4, 0) * CFrame.Angles(0, 0, math.rad(90)), blue, { Shape = Enum.PartType.Cylinder })
	end
	local arch = Build.part(gate, "Arche", Vector3.new(GATE * 2 + 6, 2.4, 2.6), g * P(0, 15, 0), rgb(246, 246, 250), { Material = Enum.Material.SmoothPlastic })
	local _ = arch
	local neon = Build.deco(gate, "ArcheNeon", Vector3.new(GATE * 2 + 6.2, 0.4, 2.7), g * P(0, 13.7, 0), rgb(90, 180, 255), { Material = Enum.Material.Neon })
	Kit.light(neon, rgb(90, 180, 255), 22, 1.4)
	ownerSign(gate, g * P(0, 11.4, -0.4), Vector3.new(15, 2.6, 0.5), blue, Enum.Material.SmoothPlastic, rgb(255, 255, 255))
	dragonBall(gate, (g * P(0, 18.4, 0)).Position, 4)
	-- Les 7 Dragon Balls cachées dans la bande extérieure.
	local spots = innerBandSpots(30)
	for k = 1, 7 do
		local cf = spots[((k * 5) % #spots) + 1]
		dragonBall(model, (cf * P(0, 2.4, 0)).Position, k)
	end
	-- Palmiers (île de la Tortue) à l'extérieur des murs.
	for _, c in corners() do
		local base = Vector3.new(c.X - math.sign(c.X) * 10, FLOOR, c.Z + math.sign(c.Z) * 2.5)
		local trunk = Build.model(model, "Palmier")
		local pos = base
		for k = 0, 4 do
			Build.part(trunk, "Tronc", Vector3.new(1.2 - k * 0.1, 2.4, 1.2 - k * 0.1), CFrame.new(pos + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(6)), rgb(150, 110, 70), {
				Material = Enum.Material.Wood,
			})
			pos += Vector3.new(0.25, 2.3, 0)
		end
		for k = 0, 5 do
			local a = k * math.pi / 3
			Kit.blob(trunk, "Palme", Vector3.new(6, 0.5, 2), CFrame.new(pos + Vector3.new(math.cos(a) * 2.6, -0.6, math.sin(a) * 2.6)) * CFrame.Angles(0, -a, math.rad(-18)), rgb(70, 160, 60), {
				Material = Enum.Material.Grass,
			})
		end
	end
	local _ = rng
end

------------------------------------------------------------------------
-- GRAND OCÉAN (pont de navire et quai)
------------------------------------------------------------------------

local function barrel(parent: Instance, cf: CFrame)
	Build.part(parent, "Tonneau", Vector3.new(2.8, 2.2, 2.2), cf * P(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(140, 92, 54), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.WoodPlanks,
	})
	for _, y in { 0.6, 2.2 } do
		Build.deco(parent, "Cercle", Vector3.new(0.25, 2.3, 2.3), cf * P(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(70, 70, 76), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal })
	end
end

local function crate(parent: Instance, cf: CFrame, s: number)
	Build.part(parent, "Caisse", Vector3.new(2.6, 2.6, 2.6) * s, cf * P(0, 1.3 * s, 0), rgb(176, 130, 80), { Material = Enum.Material.WoodPlanks })
	Build.deco(parent, "Latte", Vector3.new(2.7, 0.3, 2.7) * s, cf * P(0, 1.3 * s, 0), rgb(130, 90, 54), { Material = Enum.Material.Wood })
end

local function cannon(parent: Instance, cf: CFrame)
	Build.part(parent, "Affut", Vector3.new(2.6, 1.2, 3.4), cf * P(0, 0.8, 0), rgb(110, 70, 40), { Material = Enum.Material.Wood })
	for _, x in { -1.3, 1.3 } do
		for _, z in { -1.2, 1.2 } do
			Build.part(parent, "Roue", Vector3.new(0.4, 1.2, 1.2), cf * P(x, 0.6, z), rgb(80, 52, 30), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Wood })
		end
	end
	Build.part(parent, "Canon", Vector3.new(4.4, 1.4, 1.4), cf * P(0, 1.9, -1) * CFrame.Angles(0, math.rad(90), math.rad(10)), rgb(40, 40, 46), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Metal,
	})
end

local function buildOcean(model: Model, rng: Random)
	floor(model, {
		main = { rgb(168, 118, 74), Enum.Material.WoodPlanks },
		band = { rgb(150, 146, 140), Enum.Material.Cobblestone },
		path = { rgb(196, 150, 100), Enum.Material.WoodPlanks },
		court = { rgb(186, 136, 88), Enum.Material.WoodPlanks },
	})
	-- Lignes de calfatage du pont (bandes sombres).
	local deck = Build.model(model, "Calfatage")
	for x = -54, 54, 12 do
		Build.deco(deck, "Joint", Vector3.new(0.25, 0.04, 116), P(x, FLOOR + 0.035, 0), rgb(90, 60, 40), { Material = Enum.Material.Wood })
	end
	-- Bastingage : poteaux, deux lisses, cordages ; bollards sur le quai.
	themedWall(model, {
		baseH = 0.6,
		baseColor = rgb(100, 66, 40),
		baseMat = Enum.Material.Wood,
		bodyH = 0,
		thickness = 1.2,
		postColor = rgb(96, 62, 38),
		postEvery = 5,
		postSize = 0.8,
		postHeight = 5.2,
		postShape = "round",
		postMat = Enum.Material.Wood,
		onRun = function(seg, cf, length)
			for _, y in { 2.6, 4.4 } do
				Build.part(seg, "Lisse", Vector3.new(length + 1, 0.6, 0.8), cf * P(0, y, 0), rgb(130, 86, 52), { Material = Enum.Material.Wood })
			end
			Build.deco(seg, "Cordage", Vector3.new(length, 0.25, 0.25), cf * P(0, 1.6, 0), rgb(214, 186, 130), { Material = Enum.Material.Fabric })
		end,
	})
	-- Portail : deux mâts, vergue, voile roulée, drapeau pirate et échelles de corde.
	local gate = Build.model(model, "Portail")
	local g = P(0, 0, -W)
	for _, side in { -1, 1 } do
		Build.part(gate, "Mat", Vector3.new(24, 1.8, 1.8), g * P(side * (GATE + 1), 12, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(130, 86, 52), {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Wood,
		})
		Build.part(gate, "Hune", Vector3.new(3.4, 0.6, 3.4), g * P(side * (GATE + 1), 20, 0), rgb(110, 70, 40), { Material = Enum.Material.WoodPlanks })
		for k = 0, 4 do
			Build.deco(gate, "Enfléchure", Vector3.new(0.15, 0.15, 3.4), g * P(side * (GATE + 1), 3 + k * 3.2, 1.2), rgb(214, 186, 130), { Material = Enum.Material.Fabric })
		end
	end
	Build.part(gate, "Vergue", Vector3.new(GATE * 2 + 8, 1, 1), g * P(0, 17, 0), rgb(110, 70, 40), { Material = Enum.Material.Wood })
	Build.part(gate, "VoileRoulee", Vector3.new(GATE * 2 + 4, 1.6, 1.6), g * P(0, 16, 0.2) * CFrame.Angles(0, 0, 0), rgb(240, 234, 216), { Material = Enum.Material.Fabric })
	local flag = Build.part(gate, "Drapeau", Vector3.new(6, 4, 0.1), g * P(0, 25, 0), rgb(20, 20, 24), { Material = Enum.Material.Fabric })
	Build.part(gate, "MatDrapeau", Vector3.new(0.3, 6, 0.3), g * P(-3.2, 24, 0), rgb(110, 70, 40), { Material = Enum.Material.Wood })
	emblemText(flag, Enum.NormalId.Front, "☠", rgb(255, 255, 255))
	emblemText(flag, Enum.NormalId.Back, "☠", rgb(255, 255, 255))
	ownerSign(gate, g * P(0, 12.6, -0.4), Vector3.new(14, 2.8, 0.5), rgb(120, 78, 46), Enum.Material.WoodPlanks, rgb(255, 230, 160))
	local lamp = Build.deco(gate, "Fanal", Vector3.new(1.2, 1.6, 1.2), g * P(0, 10.2, -0.8), rgb(255, 210, 120), { Material = Enum.Material.Neon })
	Kit.light(lamp, rgb(255, 210, 120), 20, 1.4)
	-- Tonneaux, caisses, canons, ancres le long du bastingage.
	for i, cf in innerBandSpots(14) do
		local kind = i % 4
		if kind == 0 then
			barrel(model, cf)
		elseif kind == 1 then
			crate(model, cf, 1)
			crate(model, cf * P(0, 2.6, 0) * CFrame.Angles(0, 0.4, 0), 0.7)
		elseif kind == 2 then
			cannon(model, cf * CFrame.Angles(0, math.pi, 0))
		end
	end
	for _, c in corners() do
		local anchorCF = CFrame.new(c.X - math.sign(c.X) * 2, FLOOR, c.Z - math.sign(c.Z) * 2)
		local a = Build.model(model, "Ancre")
		Build.part(a, "Tige", Vector3.new(0.8, 7, 0.8), anchorCF * P(0, 4, 0), rgb(60, 62, 70), { Material = Enum.Material.Metal })
		Build.part(a, "Jas", Vector3.new(4, 0.6, 0.6), anchorCF * P(0, 7, 0), rgb(60, 62, 70), { Material = Enum.Material.Metal })
		Build.part(a, "Bras", Vector3.new(5, 0.8, 0.8), anchorCF * P(0, 1.2, 0), rgb(60, 62, 70), { Material = Enum.Material.Metal })
		for _, side in { -1, 1 } do
			Build.wedge(a, "Patte", Vector3.new(0.8, 1.6, 1.4), anchorCF * P(side * 2.6, 1.8, 0) * CFrame.Angles(0, side > 0 and math.rad(90) or math.rad(-90), 0), rgb(60, 62, 70))
		end
		Build.part(a, "Anneau", Vector3.new(0.3, 1.6, 1.6), anchorCF * P(0, 8, 0) * CFrame.Angles(0, math.rad(90), 0), rgb(60, 62, 70), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal })
	end
	local _ = rng
end

------------------------------------------------------------------------
-- ÈRE DES POURFENDEURS (manoir et glycines)
------------------------------------------------------------------------

local WISTERIA = { rgb(186, 146, 236), rgb(160, 118, 220), rgb(206, 176, 246), rgb(140, 100, 206) }

local function wisteriaCluster(parent: Instance, top: Vector3, rng: Random, length: number?)
	local len = length or 3
	for k = 0, 2 do
		local size = (1.5 - k * 0.35)
		Kit.blob(parent, "Glycine", Vector3.new(size, len * 0.5, size), CFrame.new(top - Vector3.new(rng:NextNumber(-0.3, 0.3), k * len * 0.33, rng:NextNumber(-0.3, 0.3))), WISTERIA[rng:NextInteger(1, #WISTERIA)], {
			Material = Enum.Material.Grass,
		})
	end
end

local function checkerBanner(parent: Instance, cf: CFrame)
	local pole = Build.part(parent, "Mat", Vector3.new(0.45, 11, 0.45), cf * P(0, 5.5, 0), rgb(40, 30, 28), { Material = Enum.Material.Wood })
	local _ = pole
	local cloth = Build.deco(parent, "Damier", Vector3.new(3, 6, 0.1), cf * P(1.7, 7.4, 0), rgb(30, 30, 30), { Material = Enum.Material.Fabric })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.Parent = cloth
		for i = 0, 2 do
			for j = 0, 5 do
				if (i + j) % 2 == 0 then
					local f = Instance.new("Frame")
					f.BorderSizePixel = 0
					f.BackgroundColor3 = rgb(40, 150, 90)
					f.Position = UDim2.fromScale(i / 3, j / 6)
					f.Size = UDim2.fromScale(1 / 3, 1 / 6)
					f.Parent = gui
				end
			end
		end
	end
end

local function buildPourfendeur(model: Model, rng: Random)
	floor(model, {
		main = { rgb(206, 200, 188), Enum.Material.Pebble },
		band = { rgb(96, 150, 70), Enum.Material.Grass },
		path = { rgb(150, 146, 140), Enum.Material.Slate },
		court = { rgb(226, 216, 190), Enum.Material.Sand },
	})
	-- Murs de manoir : crépi blanc, poutres noires, tuiles gris foncé, glycines retombantes.
	themedWall(model, {
		baseH = 1.6,
		baseColor = rgb(120, 116, 112),
		baseMat = Enum.Material.Cobblestone,
		bodyH = 6.2,
		bodyColor = rgb(244, 240, 230),
		bodyMat = Enum.Material.Plaster,
		roofColor = rgb(52, 54, 64),
		roofH = 1.4,
		postColor = rgb(32, 26, 24),
		postEvery = 7,
		stripe = { y = 4.6, h = 0.45, color = rgb(32, 26, 24), mat = Enum.Material.Wood },
		onPost = function(seg, cf, i)
			if i % 2 == 0 then
				wisteriaCluster(seg, (cf * P(0, 8.6, 2.2)).Position, rng, 3.4)
			end
		end,
	})
	-- Pergolas de glycines dans les angles.
	for _, c in corners() do
		local pergola = Build.model(model, "Pergola")
		local cf = CFrame.new(c.X - math.sign(c.X) * 6, FLOOR, c.Z - math.sign(c.Z) * 6)
		for _, x in { -3.5, 3.5 } do
			for _, z in { -3.5, 3.5 } do
				Build.part(pergola, "Poteau", Vector3.new(0.7, 9, 0.7), cf * P(x, 4.5, z), rgb(70, 48, 36), { Material = Enum.Material.Wood })
			end
		end
		for _, z in { -3.5, 0, 3.5 } do
			Build.part(pergola, "Poutre", Vector3.new(9, 0.5, 0.5), cf * P(0, 9.2, z), rgb(70, 48, 36), { Material = Enum.Material.Wood })
		end
		Kit.blob(pergola, "Feuillage", Vector3.new(9, 1.4, 9), cf * P(0, 9.8, 0), rgb(90, 140, 70), { Material = Enum.Material.Grass })
		for x = -3, 3, 2 do
			for z = -3, 3, 2 do
				wisteriaCluster(pergola, (cf * P(x, 9, z)).Position, rng, 2.8)
			end
		end
	end
	-- Portail du manoir (yakuimon) : piliers épais, toit noir, portes sombres, glycines en arche.
	local gate = Build.model(model, "Portail")
	local g = P(0, 0, -W)
	for _, side in { -1, 1 } do
		Build.part(gate, "Pilier", Vector3.new(2.6, 14, 2.6), g * P(side * (GATE + 1.3), 7, 0), rgb(46, 36, 32), { Material = Enum.Material.Wood })
		Build.part(gate, "PilierArriere", Vector3.new(1.6, 11, 1.6), g * P(side * (GATE + 1.3), 5.5, 4), rgb(46, 36, 32), { Material = Enum.Material.Wood })
		Build.part(gate, "Porte", Vector3.new(9.6, 11, 0.7), g * P(side * (GATE - 0.2), 5.7, 4.6) * CFrame.Angles(0, side * math.rad(80), 0) * P(side * -4.8, 0, 0), rgb(60, 44, 36), {
			Material = Enum.Material.WoodPlanks,
		})
		checkerBanner(gate, g * P(side * (GATE + 5.5), FLOOR, -3) * CFrame.Angles(0, side > 0 and math.pi or 0, 0))
	end
	Build.part(gate, "Linteau", Vector3.new(GATE * 2 + 6, 1.8, 3), g * P(0, 13.6, 0.6), rgb(46, 36, 32), { Material = Enum.Material.Wood })
	Kit.roof(gate, g * P(0, 14.5, 1), GATE * 2 + 11, 9, 3.6, rgb(52, 54, 64), { ornament = true, name = "ToitPortail" })
	ownerSign(gate, g * P(0, 10.8, -0.3), Vector3.new(13, 2.6, 0.5), rgb(244, 240, 230), Enum.Material.Wood, rgb(60, 30, 80))
	for x = -GATE - 3, GATE + 3, 2.2 do
		wisteriaCluster(gate, (g * P(x, 15.2, -2.6)).Position, rng, 3)
	end
	local lantern = Build.deco(gate, "Lanterne", Vector3.new(1.4, 1.8, 1.4), g * P(0, 8.4, -0.8), rgb(255, 220, 160), { Material = Enum.Material.Neon })
	Kit.light(lantern, rgb(255, 220, 170), 20, 1.4)
	-- Lanternes de pierre le long des murs.
	for i, cf in innerBandSpots(20) do
		if i % 3 == 0 then
			Kit.toro(model, cf, 0.85)
		end
	end
end

------------------------------------------------------------------------
-- Construction, modèles, application
------------------------------------------------------------------------

local BUILDERS = {
	ninja = buildNinja,
	occulte = buildOcculte,
	saiyan = buildSaiyan,
	ocean = buildOcean,
	pourfendeur = buildPourfendeur,
}

local function keyOf(universe): string
	return (universe.theme and universe.theme.decor) or universe.id
end

-- Construit le modèle de déco d'un univers (repère local, centre au sol en (0, 0, 0)).
function BaseDecor.build(universe): Model
	local model = Instance.new("Model")
	model.Name = keyOf(universe)
	local pivot = Build.part(model, "Pivot", Vector3.new(1, 1, 1), CFrame.new(), Color3.new(1, 1, 1), {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	model.PrimaryPart = pivot
	local builder = BUILDERS[keyOf(universe)] or buildNinja
	local seed = 0
	for i = 1, #universe.id do
		seed += string.byte(universe.id, i) * i
	end
	builder(model, Random.new(seed))
	model:SetAttribute("UniverseId", universe.id)
	return model
end

local function store(): Folder
	local folder = ServerStorage:FindFirstChild("DecorsBase") :: Folder?
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "DecorsBase"
		folder.Parent = ServerStorage
	end
	return folder :: Folder
end

-- Modèle de déco d'un univers (construit une fois, puis repris de ServerStorage.DecorsBase :
-- les retouches faites dans Studio sont donc conservées).
function BaseDecor.template(universe): Model
	local folder = store()
	local key = keyOf(universe)
	local existing = folder:FindFirstChild(key)
	if existing and existing:IsA("Model") then
		return existing
	end
	local model = BaseDecor.build(universe)
	model.Name = key
	model.Parent = folder
	return model
end

-- Construit tous les modèles (utilisé par tools/bake.luau pour les voir dans Studio).
function BaseDecor.buildAllTemplates(universes)
	for _, universe in universes do
		BaseDecor.template(universe)
	end
end

-- Libellés du panneau du propriétaire dans la déco affichée d'une base.
local function signLabels(decor: Instance): { TextLabel }
	local labels = {}
	for _, d in decor:GetDescendants() do
		if d:IsA("TextLabel") then
			local gui = d.Parent
			local part = gui and gui.Parent
			if gui and gui:IsA("SurfaceGui") and part and part.Name == "OwnerSign" then
				table.insert(labels, d)
			end
		end
	end
	return labels
end

-- Applique la déco de `universe` à une base (remplace le dossier « Decor » de la base).
function BaseDecor.apply(plot, universe)
	local model = plot.model
	local current = model:FindFirstChild("Decor")
	if current and current:GetAttribute("UniverseId") == universe.id then
		plot.signLabels = signLabels(current)
		for _, label in plot.signLabels do
			label.Text = plot.signText or "BASE LIBRE"
		end
		return current
	end
	if current then
		current:Destroy()
	end
	local clone = BaseDecor.template(universe):Clone()
	clone.Name = "Decor"
	clone.PrimaryPart = clone:FindFirstChild("Pivot") :: BasePart
	clone:SetAttribute("UniverseId", universe.id)
	clone:PivotTo(plot.cf)
	clone.Parent = model
	plot.signLabels = signLabels(clone)
	for _, label in plot.signLabels do
		label.Text = plot.signText or "BASE LIBRE"
	end
	return clone
end

-- Enregistre une base (PlotService le fait pour chacune) pour BaseDecor.applyAll.
function BaseDecor.register(plot)
	if not table.find(registered, plot) then
		table.insert(registered, plot)
	end
end

-- Applique la déco de `universe` à toutes les bases enregistrées (ou à `plots`).
function BaseDecor.applyAll(universe, plots)
	for _, plot in plots or registered do
		local ok, err = pcall(BaseDecor.apply, plot, universe)
		if not ok then
			warn("[AnimeTycoon] Déco de base : " .. tostring(err))
		end
	end
end

-- Met à jour le texte du panneau du propriétaire.
function BaseDecor.setSign(plot, text: string)
	plot.signText = text
	for _, label in plot.signLabels or {} do
		label.Text = text
	end
end

return BaseDecor
