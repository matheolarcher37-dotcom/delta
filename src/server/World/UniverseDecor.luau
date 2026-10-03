-- Décor de l'ANNEAU D'UNIVERS (autour du hub) : change complètement toutes les 30 min.
--
-- Chaque univers a son sol, ses portes, ses bâtiments et ses petits objets.
-- Dans le fichier fourni, les 5 décors sont déjà construits : celui de l'univers affiché est dans
-- Workspace > World > Zone > Decor, les autres sont rangés dans ServerStorage > DecorsUnivers.
-- Tu peux les modifier dans Studio (glisse-en un dans Workspace pour le voir, puis remets-le) :
-- au changement d'univers, le jeu échange simplement ces dossiers, tes retouches sont gardées.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Build = require(script.Parent.Parent.Modules.Build)

local UniverseDecor = {}

local rgb = Color3.fromRGB
local RING_IN, RING_OUT = Layout.RingInner, Layout.RingOuter
local SECTORS = { 0, 60, 120, 180, 240, 300 } -- entre les chemins (degrés)

local function polar(angle: number, radius: number, y: number?): Vector3
	return Vector3.new(math.cos(angle) * radius, y or 0, math.sin(angle) * radius)
end

-- CFrame au sol qui regarde vers le centre.
local function facingCenter(angle: number, radius: number): CFrame
	return CFrame.lookAt(polar(angle, radius), Vector3.new(0, 0, 0))
end

local function isFree(position: Vector3, margin: number): boolean
	local r = Vector3.new(position.X, 0, position.Z).Magnitude
	return r > RING_IN + margin and r < RING_OUT - margin and not Layout.onPath(position, margin) and not Layout.inBossArena(position, margin + 2)
end

-- Place `count` objets à des endroits libres de l'anneau.
local function scatter(parent: Instance, rng: Random, count: number, minR: number, maxR: number, fn: (Instance, Vector3, Random) -> (), margin: number?)
	local placed, attempts = 0, 0
	while placed < count and attempts < count * 12 do
		attempts += 1
		local pos = polar(rng:NextNumber(0, math.pi * 2), rng:NextNumber(minR, maxR), 0.1)
		if isFree(pos, margin or 2) then
			fn(parent, pos, rng)
			placed += 1
		end
	end
end

local function ground(decor: Instance, theme, material: Enum.Material)
	local main = Build.disc(decor, "Ground", 1, RING_OUT * 2 + 4, Vector3.new(0, -0.95, 0), theme.ground, { Material = material })
	main.CastShadow = false
	local band = Build.disc(decor, "GroundBand", 1.01, 260, Vector3.new(0, -0.95, 0), theme.groundAccent, { Material = material })
	band.CastShadow = false
	local inner = Build.disc(decor, "GroundInner", 1.02, 192, Vector3.new(0, -0.95, 0), theme.ground:Lerp(Color3.new(1, 1, 1), 0.06), { Material = material })
	inner.CastShadow = false
end

local function groundPatches(parent: Instance, rng: Random, color: Color3, count: number)
	scatter(parent, rng, count, RING_IN + 4, RING_OUT - 4, function(p, base, r)
		local size = r:NextNumber(4, 9)
		Build.deco(
			p,
			"Patch",
			Vector3.new(size, 0.06, size * r:NextNumber(0.6, 1.3)),
			CFrame.new(base + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0),
			color
		)
	end, 1)
end

local function ambientParticles(parent: Instance, color: ColorSequence, direction: Enum.NormalId, y: number, speed: NumberRange, size: number, rate: number)
	local emitterPart = Build.deco(parent, "Ambient", Vector3.new(RING_OUT * 2, 1, RING_OUT * 2), CFrame.new(0, y, 0), Color3.new(1, 1, 1), { Transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = color
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 0.4) })
	emitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(6, 10)
	emitter.Rate = rate
	emitter.Speed = speed
	emitter.EmissionDirection = direction
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Parent = emitterPart
end

-- Une porte par chemin, sur la clôture extérieure de l'anneau.
local function gates(builder: (CFrame) -> ())
	for _, angle in Layout.PlotAngles do
		builder(facingCenter(angle, Layout.RingFenceRadius))
	end
end

------------------------------------------------------------------------
-- Éléments réutilisables
------------------------------------------------------------------------

local function stoneLantern(parent: Instance, base: Vector3)
	local stone = rgb(150, 150, 155)
	Build.part(parent, "LanternBase", Vector3.new(2.4, 0.8, 2.4), CFrame.new(base + Vector3.new(0, 0.4, 0)), stone, { Material = Enum.Material.Slate })
	Build.part(parent, "LanternPost", Vector3.new(1, 3, 1), CFrame.new(base + Vector3.new(0, 2.3, 0)), stone, { Material = Enum.Material.Slate })
	local light = Build.part(parent, "LanternLight", Vector3.new(1.8, 1.4, 1.8), CFrame.new(base + Vector3.new(0, 4.5, 0)), rgb(255, 190, 110), { Material = Enum.Material.Neon })
	Build.part(
		parent,
		"LanternRoof",
		Vector3.new(2.8, 0.7, 2.8),
		CFrame.new(base + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, math.rad(45), 0),
		stone,
		{ Material = Enum.Material.Slate }
	)
	local point = Instance.new("PointLight")
	point.Color = rgb(255, 180, 100)
	point.Range = 16
	point.Brightness = 1.5
	point.Parent = light
end

local function paperLantern(parent: Instance, position: Vector3, color: Color3)
	local lamp = Build.deco(parent, "PaperLantern", Vector3.new(1.4, 1.8, 1.4), CFrame.new(position), color, { Material = Enum.Material.Neon, Transparency = 0.05 })
	Build.deco(parent, "LanternTop", Vector3.new(1.0, 0.25, 1.0), CFrame.new(position + Vector3.new(0, 1.0, 0)), rgb(40, 30, 30))
	Build.deco(parent, "LanternBottom", Vector3.new(1.0, 0.25, 1.0), CFrame.new(position - Vector3.new(0, 1.0, 0)), rgb(40, 30, 30))
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12
	light.Brightness = 1.2
	light.Parent = lamp
end

local function kunai(parent: Instance, base: Vector3, rng: Random)
	local cf = CFrame.new(base + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	Build.deco(parent, "KunaiBlade", Vector3.new(0.35, 0.08, 1.0), cf, rgb(190, 195, 205), { Material = Enum.Material.Metal })
	Build.deco(parent, "KunaiGrip", Vector3.new(0.15, 0.1, 0.7), cf * CFrame.new(0, 0, 0.8), rgb(40, 40, 50))
	Build.deco(parent, "KunaiRing", Vector3.new(0.3, 0.1, 0.3), cf * CFrame.new(0, 0, 1.25), rgb(190, 195, 205), { Material = Enum.Material.Metal })
end

local function shuriken(parent: Instance, base: Vector3, rng: Random)
	local cf = CFrame.new(base + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	Build.deco(parent, "Shuriken", Vector3.new(1.2, 0.08, 0.3), cf, rgb(80, 85, 95), { Material = Enum.Material.Metal })
	Build.deco(parent, "Shuriken", Vector3.new(0.3, 0.08, 1.2), cf, rgb(80, 85, 95), { Material = Enum.Material.Metal })
end

local function smallRock(parent: Instance, base: Vector3, rng: Random)
	local color = rgb(130, 125, 125):Lerp(rgb(170, 165, 160), rng:NextNumber())
	local size = Vector3.new(rng:NextNumber(0.8, 2), rng:NextNumber(0.5, 1.2), rng:NextNumber(0.8, 1.8))
	Build.part(
		parent,
		"Pebble",
		size,
		CFrame.new(base + Vector3.new(0, size.Y / 2 - 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		color,
		{ Material = Enum.Material.Slate }
	)
end

local function palmTree(parent: Instance, base: Vector3, rng: Random)
	local model = Build.model(parent, "Palm")
	local lean = rng:NextNumber(0.1, 0.25)
	local dir = rng:NextNumber(0, math.pi * 2)
	local cf = CFrame.new(base) * CFrame.Angles(0, dir, 0)
	for i = 0, 5 do
		cf = cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(lean * 0.35, 0, 0)
		Build.part(
			model,
			"Trunk",
			Vector3.new(1.3 - i * 0.07, 3.2, 1.3 - i * 0.07),
			cf * CFrame.new(0, 0, 0),
			rgb(150, 110, 70):Lerp(rgb(120, 85, 55), (i % 2) * 0.6),
			{ Material = Enum.Material.Wood }
		)
		cf = cf * CFrame.new(0, 1.6, 0)
	end
	local top = cf.Position
	for i = 0, 6 do
		local leafCF = CFrame.new(top) * CFrame.Angles(0, i * math.pi * 2 / 7, 0) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, 0, -3.2)
		Build.deco(model, "Leaf", Vector3.new(1.8, 0.3, 6.5), leafCF, rgb(60, 170, 70):Lerp(rgb(90, 200, 80), (i % 2) * 0.5), { Material = Enum.Material.Grass })
	end
	for i = 0, 2 do
		Build.ball(model, "Coconut", 1, top + Vector3.new(math.cos(i * 2.1) * 0.7, -0.6, math.sin(i * 2.1) * 0.7), rgb(110, 70, 40))
	end
end

local function wisteriaTree(parent: Instance, base: Vector3, rng: Random, scale: number)
	local model = Build.model(parent, "Wisteria")
	local s = scale
	Build.part(
		model,
		"Trunk",
		Vector3.new(2.2 * s, 9 * s, 2.2 * s),
		CFrame.new(base + Vector3.new(0, 4.5 * s, 0)) * CFrame.Angles(0, 0, 0.05),
		rgb(90, 60, 45),
		{ Material = Enum.Material.Wood }
	)
	Build.part(
		model,
		"Branch",
		Vector3.new(8 * s, 1.2 * s, 1.2 * s),
		CFrame.new(base + Vector3.new(0, 8.5 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0.15),
		rgb(90, 60, 45),
		{ Material = Enum.Material.Wood }
	)
	-- Feuillage en dôme : vert à la base, couvert de grappes de glycine violettes.
	Build.part(model, "Canopy", Vector3.new(12 * s, 2.4 * s, 12 * s), CFrame.new(base + Vector3.new(0, 10 * s, 0)), rgb(80, 120, 75), { Material = Enum.Material.Grass })
	Build.part(
		model,
		"Canopy2",
		Vector3.new(9 * s, 2.2 * s, 9 * s),
		CFrame.new(base + Vector3.new(0, 11.8 * s, 0)) * CFrame.Angles(0, 0.4, 0),
		rgb(170, 120, 230),
		{ Material = Enum.Material.SmoothPlastic }
	)
	Build.part(
		model,
		"Canopy3",
		Vector3.new(5.5 * s, 1.8 * s, 5.5 * s),
		CFrame.new(base + Vector3.new(0, 13.4 * s, 0)) * CFrame.Angles(0, 0.9, 0),
		rgb(205, 165, 255),
		{ Material = Enum.Material.SmoothPlastic }
	)
	for i = 0, 5 do
		local angle = i * math.pi / 3 + rng:NextNumber(0, 0.4)
		Build.part(
			model,
			"Cluster",
			Vector3.new(3.2, 2.4, 3.2) * s,
			CFrame.new(base + Vector3.new(math.cos(angle) * 5.2 * s, 10.6 * s, math.sin(angle) * 5.2 * s)) * CFrame.Angles(0, angle, 0),
			rgb(185, 140, 245):Lerp(rgb(230, 200, 255), rng:NextNumber()),
			{ Material = Enum.Material.SmoothPlastic }
		)
	end
	for _ = 1, 16 do
		local x = rng:NextNumber(-5.8, 5.8) * s
		local z = rng:NextNumber(-5.8, 5.8) * s
		local length = rng:NextNumber(2, 4.5) * s
		local purple = rgb(190, 140, 255):Lerp(rgb(240, 200, 255), rng:NextNumber())
		Build.deco(
			model,
			"Bloom",
			Vector3.new(1.1 * s, length, 1.1 * s),
			CFrame.new(base + Vector3.new(x, 8.8 * s - length / 2, z)),
			purple,
			{ Material = rng:NextNumber() < 0.5 and Enum.Material.Neon or Enum.Material.SmoothPlastic, Transparency = 0.1 }
		)
	end
end

-- Végétation dans les bandes intérieure et extérieure (la bande du milieu reste dégagée pour les combats).
local function foliage(decor: Instance, rng: Random, count: number, fn: (Instance, Vector3, Random) -> ())
	scatter(decor, rng, math.ceil(count * 0.4), RING_IN + 8, 92, fn, 5)
	scatter(decor, rng, math.floor(count * 0.6), 132, RING_OUT - 8, fn, 5)
end

------------------------------------------------------------------------
-- Thèmes (positions dans l'anneau : secteurs entre les chemins)
------------------------------------------------------------------------

local THEMES = {}

-- VILLAGE NINJA ---------------------------------------------------------
THEMES.ninja = function(decor: Instance, rng: Random, theme)
	ground(decor, theme, Enum.Material.Ground)
	groundPatches(decor, rng, rgb(130, 90, 60), 40)
	gates(function(cf)
		Build.torii(decor, cf, 15, 13, rgb(230, 90, 30), rgb(60, 40, 30))
	end)
	foliage(decor, rng, 22, function(parent, base, r)
		if r:NextNumber() < 0.7 then
			Build.tree(parent, base, r:NextNumber(0.9, 1.4), rgb(70, 170, 70), nil, r)
		else
			Build.bush(parent, base, r:NextNumber(0.9, 1.3), rgb(80, 160, 60))
		end
	end)
	local roofs = { rgb(210, 60, 40), rgb(240, 130, 40), rgb(70, 120, 200) }
	for i, deg in SECTORS do
		local angle = math.rad(deg)
		local cf = facingCenter(angle, 148)
		if i == 3 or i == 6 then
			-- Château d'eau iconique.
			local base = cf.Position
			for _, off in { Vector3.new(3, 0, 3), Vector3.new(-3, 0, 3), Vector3.new(3, 0, -3), Vector3.new(-3, 0, -3) } do
				Build.part(decor, "Stilt", Vector3.new(0.8, 14, 0.8), CFrame.new(base + off + Vector3.new(0, 7, 0)), rgb(110, 75, 50), { Material = Enum.Material.Wood })
			end
			Build.disc(decor, "Tank", 7, 10, base + Vector3.new(0, 14, 0), rgb(235, 225, 200))
			Build.disc(decor, "TankBand", 1, 10.4, base + Vector3.new(0, 16.5, 0), rgb(210, 60, 40))
			Build.disc(decor, "TankRoof", 1.5, 11.5, base + Vector3.new(0, 21, 0), rgb(210, 60, 40))
			Build.disc(decor, "TankRoof2", 1.2, 7, base + Vector3.new(0, 22.5, 0), rgb(210, 60, 40))
		else
			Build.house(decor, cf, Vector3.new(16, 10, 11), rgb(240, 225, 195), roofs[(i % #roofs) + 1], rgb(120, 80, 50))
		end
		for _, side in { -1, 1 } do
			Build.tree(decor, polar(angle + side * math.rad(17), 152), rng:NextNumber(1.2, 1.6), rgb(70, 170, 70), nil, rng)
			Build.lantern(decor, polar(angle + side * math.rad(10), 72), rgb(255, 150, 60))
		end
		if i ~= 1 then
			Build.house(decor, facingCenter(angle, 112), Vector3.new(11, 7, 8), rgb(245, 235, 210), roofs[((i + 1) % #roofs) + 1], rgb(120, 80, 50))
		end
		-- Poteaux d'entraînement.
		local post = polar(angle + math.rad(4), 80)
		Build.disc(decor, "TrainingLog", 5, 1.6, post, rgb(140, 95, 60), { Material = Enum.Material.Wood })
		Build.disc(decor, "Rope", 0.4, 1.7, post + Vector3.new(0, 3, 0), rgb(220, 200, 150))
	end
	scatter(decor, rng, 30, RING_IN + 4, RING_OUT - 4, kunai)
	scatter(decor, rng, 24, RING_IN + 4, RING_OUT - 4, shuriken)
	scatter(decor, rng, 26, RING_IN + 4, RING_OUT - 4, smallRock)
	ambientParticles(decor, ColorSequence.new(rgb(90, 190, 70), rgb(160, 220, 90)), Enum.NormalId.Bottom, 45, NumberRange.new(3, 5), 0.6, 30)
end

-- ACADÉMIE OCCULTE ------------------------------------------------------
THEMES.occulte = function(decor: Instance, rng: Random, theme)
	ground(decor, theme, Enum.Material.Slate)
	groundPatches(decor, rng, rgb(65, 60, 72), 40)
	gates(function(cf)
		Build.torii(decor, cf, 15, 14, rgb(150, 25, 35), rgb(20, 15, 20))
	end)
	foliage(decor, rng, 20, function(parent, base, r)
		if r:NextNumber() < 0.7 then
			Build.pine(parent, base, r:NextNumber(1.1, 1.6), rgb(30, 80, 55))
		else
			Build.rock(parent, base, r:NextNumber(0.9, 1.5), rgb(70, 65, 80), r)
		end
	end)
	for i, deg in SECTORS do
		local angle = math.rad(deg)
		Build.house(decor, facingCenter(angle, 148), Vector3.new(17, 11, 12), rgb(70, 50, 40), rgb(40, 35, 50), rgb(150, 30, 40))
		for _, side in { -1, 1 } do
			Build.pine(decor, polar(angle + side * math.rad(17), 152), rng:NextNumber(1.5, 2), rgb(30, 80, 55))
			stoneLantern(decor, polar(angle + side * math.rad(10), 72))
		end
		if i % 2 == 0 then
			-- Cercle rituel de sceau.
			local center = polar(angle, 112)
			Build.disc(decor, "Ritual", 0.3, 18, center, rgb(30, 25, 40), { Material = Enum.Material.Slate })
			local ring = Build.disc(decor, "RitualRing", 0.32, 15, center, rgb(170, 60, 255), { Material = Enum.Material.Neon })
			ring.Transparency = 0.2
			Build.disc(decor, "RitualInner", 0.34, 13.5, center, rgb(30, 25, 40), { Material = Enum.Material.Slate })
			for k = 0, 3 do
				local pos = center + polar(k * math.pi / 2 + math.pi / 4, 7.5)
				Build.part(decor, "SealPillar", Vector3.new(1.2, 5, 1.2), CFrame.new(pos + Vector3.new(0, 2.5, 0)), rgb(40, 35, 45), { Material = Enum.Material.Slate })
				Build.deco(
					decor,
					"SealPaper",
					Vector3.new(0.8, 1.6, 0.1),
					CFrame.lookAt(pos + Vector3.new(0, 3.2, 0), center + Vector3.new(0, 3.2, 0)) * CFrame.new(0, 0, -0.66),
					rgb(245, 235, 200)
				)
			end
		end
	end
	scatter(decor, rng, 36, RING_IN + 4, RING_OUT - 4, function(parent, base, r)
		Build.deco(parent, "Talisman", Vector3.new(0.8, 0.06, 1.6), CFrame.new(base + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0), rgb(245, 235, 200))
		Build.deco(parent, "TalismanInk", Vector3.new(0.2, 0.07, 1.2), CFrame.new(base + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0), rgb(200, 30, 40))
	end)
	scatter(decor, rng, 26, RING_IN + 4, RING_OUT - 4, smallRock)
	ambientParticles(decor, ColorSequence.new(rgb(170, 60, 255), rgb(90, 20, 160)), Enum.NormalId.Top, 0.5, NumberRange.new(1, 3), 1.2, 34)
end

-- PLANÈTE DES GUERRIERS ---------------------------------------------------
THEMES.saiyan = function(decor: Instance, rng: Random, theme)
	ground(decor, theme, Enum.Material.Sandstone)
	groundPatches(decor, rng, rgb(195, 160, 105), 34)
	gates(function(cf)
		for _, side in { -1, 1 } do
			Build.part(decor, "GatePillar", Vector3.new(3, 12, 3), cf * CFrame.new(side * 8, 6, 0), rgb(200, 170, 120), { Material = Enum.Material.Sandstone })
			Build.ball(decor, "GateOrb", 3.2, (cf * CFrame.new(side * 8, 13.6, 0)).Position, rgb(255, 160, 30), { Material = Enum.Material.Glass, Transparency = 0.1 })
			Build.deco(decor, "GateStar", Vector3.new(0.9, 0.9, 0.2), cf * CFrame.new(side * 8, 13.6, -1.65) * CFrame.Angles(0, 0, math.rad(45)), rgb(220, 40, 30), {
				Material = Enum.Material.Neon,
			})
		end
	end)
	foliage(decor, rng, 18, function(parent, base, r)
		if r:NextNumber() < 0.6 then
			Build.part(parent, "TreeTrunk", Vector3.new(0.8, 7, 0.8), CFrame.new(base + Vector3.new(0, 3.5, 0)), rgb(140, 110, 80), { Material = Enum.Material.Wood })
			Build.ball(parent, "TreeTop", r:NextNumber(4.5, 6), base + Vector3.new(0, 8.5, 0), rgb(80, 190, 150), { Material = Enum.Material.Grass })
		else
			Build.rock(parent, base, r:NextNumber(1, 1.8), rgb(200, 165, 115), r)
		end
	end)
	for i, deg in SECTORS do
		local angle = math.rad(deg)
		local pos = polar(angle, 148)
		if i % 2 == 0 then
			-- Maison-dôme futuriste.
			Build.ball(decor, "Dome", 16, pos + Vector3.new(0, 1, 0), rgb(250, 250, 250))
			Build.disc(decor, "DomeBand", 0.7, 16.15, pos + Vector3.new(0, 0.9, 0), rgb(60, 130, 230))
			Build.disc(decor, "DomeTop", 1, 4.5, pos + Vector3.new(0, 8.6, 0), rgb(60, 130, 230))
			local face = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
			Build.part(decor, "DomeDoor", Vector3.new(3, 4.5, 1), face * CFrame.new(0, 2.25, -7.6), rgb(60, 130, 230))
		else
			-- Pic rocheux.
			local height = rng:NextNumber(24, 36)
			local levels = 5
			for l = 0, levels - 1 do
				local width = 10 - l * 1.6
				Build.part(
					decor,
					"Spire",
					Vector3.new(width, height / levels + 0.5, width),
					CFrame.new(pos + Vector3.new(rng:NextNumber(-0.6, 0.6), (l + 0.5) * height / levels, rng:NextNumber(-0.6, 0.6))) * CFrame.Angles(0, l * 0.3, 0),
					rgb(205, 170, 115):Lerp(rgb(170, 130, 90), l / levels),
					{
						Material = Enum.Material.Sandstone,
					}
				)
			end
		end
		for _, side in { -1, 1 } do
			local tree = polar(angle + side * math.rad(16), 152)
			Build.part(decor, "TreeTrunk", Vector3.new(0.8, 8, 0.8), CFrame.new(tree + Vector3.new(0, 4, 0)), rgb(140, 110, 80), { Material = Enum.Material.Wood })
			Build.ball(decor, "TreeTop", 6, tree + Vector3.new(0, 9.5, 0), rgb(80, 190, 150), { Material = Enum.Material.Grass })
		end
		if i == 4 then
			-- Ring du tournoi.
			local center = polar(angle, 112)
			Build.part(
				decor,
				"TournamentRing",
				Vector3.new(22, 1.2, 22),
				CFrame.new(center + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, angle, 0),
				rgb(220, 215, 205),
				{ Material = Enum.Material.Slate }
			)
		end
	end
	scatter(decor, rng, 16, RING_IN + 6, RING_OUT - 6, function(parent, base, r)
		local d = r:NextNumber(5, 9)
		Build.disc(parent, "Crater", 0.1, d, base - Vector3.new(0, 0.05, 0), rgb(165, 130, 90), { CanCollide = false })
		Build.disc(parent, "CraterCore", 0.12, d * 0.6, base - Vector3.new(0, 0.04, 0), rgb(140, 105, 70), { CanCollide = false })
	end, 5)
	scatter(decor, rng, 30, RING_IN + 4, RING_OUT - 4, smallRock)
	ambientParticles(decor, ColorSequence.new(rgb(255, 230, 90), rgb(255, 160, 40)), Enum.NormalId.Top, 0.5, NumberRange.new(2, 4), 0.5, 24)
end

-- GRAND OCÉAN --------------------------------------------------------------
local function pirateShip(decor: Instance, shipCF: CFrame)
	local ship = Build.model(decor, "PirateShip")
	local hull = rgb(130, 80, 45)
	Build.part(ship, "Hull", Vector3.new(7, 3.5, 22), shipCF * CFrame.new(0, 1.75, 0), hull, { Material = Enum.Material.WoodPlanks })
	Build.part(ship, "HullLow", Vector3.new(5, 1.5, 18), shipCF * CFrame.new(0, 0.2, 0), hull:Lerp(Color3.new(0, 0, 0), 0.2), { Material = Enum.Material.WoodPlanks })
	Build.wedge(ship, "Bow", Vector3.new(7, 3.5, 5), shipCF * CFrame.new(0, 1.75, -13.5) * CFrame.Angles(0, math.pi, 0), hull, { Material = Enum.Material.WoodPlanks })
	Build.part(ship, "Cabin", Vector3.new(7, 3, 5), shipCF * CFrame.new(0, 5, 8), hull:Lerp(Color3.new(1, 1, 1), 0.1), { Material = Enum.Material.WoodPlanks })
	Build.part(ship, "Deck", Vector3.new(6.4, 0.3, 21), shipCF * CFrame.new(0, 3.4, 0), rgb(190, 140, 90), { Material = Enum.Material.WoodPlanks })
	for _, side in { -1, 1 } do
		Build.part(ship, "Rail", Vector3.new(0.5, 1, 22.4), shipCF * CFrame.new(side * 3.45, 4, 0), rgb(240, 200, 90))
	end
	Build.part(ship, "Mast", Vector3.new(0.9, 20, 0.9), shipCF * CFrame.new(0, 13, -1), rgb(110, 70, 40), { Material = Enum.Material.Wood })
	Build.deco(ship, "Sail", Vector3.new(11, 7, 0.3), shipCF * CFrame.new(0, 13, -1.6) * CFrame.Angles(0, math.rad(90), 0), rgb(250, 245, 230), { Material = Enum.Material.Fabric })
	Build.deco(
		ship,
		"Sail2",
		Vector3.new(8, 5, 0.3),
		shipCF * CFrame.new(0, 19.5, -1.6) * CFrame.Angles(0, math.rad(90), 0),
		rgb(250, 245, 230),
		{ Material = Enum.Material.Fabric }
	)
	Build.deco(ship, "JollyRoger", Vector3.new(0.2, 2.5, 3.5), shipCF * CFrame.new(0, 24, 0.8), rgb(25, 25, 30), { Material = Enum.Material.Fabric })
	Build.deco(ship, "Figurehead", Vector3.new(2.5, 2.5, 2.5), shipCF * CFrame.new(0, 3.5, -16), rgb(255, 230, 120))
end

THEMES.ocean = function(decor: Instance, rng: Random, theme)
	ground(decor, theme, Enum.Material.Sand)
	groundPatches(decor, rng, rgb(225, 205, 145), 34)
	gates(function(cf)
		for _, side in { -1, 1 } do
			Build.part(decor, "ArchPost", Vector3.new(1.6, 12, 1.6), cf * CFrame.new(side * 8, 6, 0), rgb(120, 80, 50), { Material = Enum.Material.Wood })
		end
		Build.part(decor, "ArchBeam", Vector3.new(19, 1.4, 1.6), cf * CFrame.new(0, 12, 0), rgb(120, 80, 50), { Material = Enum.Material.Wood })
		Build.deco(decor, "Flag", Vector3.new(6, 4, 0.2), cf * CFrame.new(0, 9.8, -0.3), rgb(25, 25, 30), { Material = Enum.Material.Fabric })
		Build.deco(decor, "Skull", Vector3.new(1.8, 1.6, 0.1), cf * CFrame.new(0, 10.1, -0.45), rgb(245, 245, 245))
	end)
	foliage(decor, rng, 16, function(parent, base, r)
		if r:NextNumber() < 0.6 then
			palmTree(parent, base, r)
		else
			Build.rock(parent, base, r:NextNumber(0.8, 1.4), rgb(170, 160, 140), r)
		end
	end)
	for i, deg in SECTORS do
		local angle = math.rad(deg)
		local cf = facingCenter(angle, 148)
		if i == 2 or i == 5 then
			pirateShip(decor, cf * CFrame.Angles(0, math.rad(90), 0))
		else
			palmTree(decor, cf.Position, rng)
			for b = 0, 2 do
				local pos = polar(angle + math.rad(5 + b * 2.5), 140 + b)
				Build.disc(decor, "Barrel", 2.6, 2, pos, rgb(150, 100, 60), { Material = Enum.Material.Wood })
				Build.disc(decor, "BarrelBand", 0.3, 2.1, pos + Vector3.new(0, 1.8, 0), rgb(80, 80, 85), { Material = Enum.Material.Metal })
			end
		end
		for _, side in { -1, 1 } do
			palmTree(decor, polar(angle + side * math.rad(17), 152), rng)
			palmTree(decor, polar(angle + side * math.rad(12), 74), rng)
			Build.part(
				decor,
				"Crate",
				Vector3.new(2.6, 2.6, 2.6),
				CFrame.new(polar(angle - side * math.rad(8), 82, 1.3)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0),
				rgb(170, 125, 75),
				{
					Material = Enum.Material.WoodPlanks,
				}
			)
		end
		if i == 4 then
			local lagoon = polar(angle, 112)
			Build.disc(decor, "Lagoon", 0.3, 20, lagoon - Vector3.new(0, 0.1, 0), rgb(60, 190, 230), { Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
		end
	end
	scatter(decor, rng, 30, RING_IN + 4, RING_OUT - 4, function(parent, base, r)
		local colors = { rgb(255, 170, 180), rgb(255, 140, 60), rgb(250, 240, 220) }
		Build.deco(
			parent,
			"Shell",
			Vector3.new(0.7, 0.3, 0.6),
			CFrame.new(base + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0),
			colors[r:NextInteger(1, #colors)]
		)
	end)
	scatter(decor, rng, 24, RING_IN + 4, RING_OUT - 4, function(parent, base, r)
		Build.deco(
			parent,
			"Coin",
			Vector3.new(0.12, 0.8, 0.8),
			CFrame.new(base + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, r:NextNumber(0, math.pi), math.rad(90)),
			rgb(255, 205, 50),
			{
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Metal,
			}
		)
	end)
	ambientParticles(decor, ColorSequence.new(rgb(200, 240, 255), rgb(120, 210, 255)), Enum.NormalId.Top, 0.5, NumberRange.new(1, 2), 0.5, 22)
end

-- ÈRE DES POURFENDEURS -----------------------------------------------------
THEMES.pourfendeur = function(decor: Instance, rng: Random, theme)
	ground(decor, theme, Enum.Material.Grass)
	groundPatches(decor, rng, rgb(80, 62, 55), 34)
	gates(function(cf)
		for _, side in { -1, 1 } do
			Build.part(decor, "ArchPost", Vector3.new(1.4, 12, 1.4), cf * CFrame.new(side * 8, 6, 0), rgb(60, 40, 35), { Material = Enum.Material.Wood })
		end
		Build.part(decor, "ArchBeam", Vector3.new(19, 1, 3), cf * CFrame.new(0, 12, 0), rgb(60, 40, 35), { Material = Enum.Material.Wood })
		for k = -3, 3 do
			local length = 2 + (3 - math.abs(k)) * 0.6
			Build.deco(
				decor,
				"Bloom",
				Vector3.new(1, length, 1),
				cf * CFrame.new(k * 2.4, 11.5 - length / 2, 0),
				rgb(200, 150, 255),
				{ Material = Enum.Material.Neon, Transparency = 0.15 }
			)
		end
	end)
	foliage(decor, rng, 16, function(parent, base, r)
		if r:NextNumber() < 0.55 then
			wisteriaTree(parent, base, r, r:NextNumber(0.6, 0.85))
		else
			Build.bush(parent, base, r:NextNumber(0.9, 1.3), rgb(60, 90, 60))
		end
	end)
	for i, deg in SECTORS do
		local angle = math.rad(deg)
		local cf = facingCenter(angle, 148)
		if i % 2 == 0 then
			Build.house(decor, cf, Vector3.new(16, 9, 11), rgb(240, 235, 225), rgb(50, 45, 60), rgb(80, 50, 40))
		else
			wisteriaTree(decor, cf.Position, rng, 1.35)
		end
		for _, side in { -1, 1 } do
			wisteriaTree(decor, polar(angle + side * math.rad(17), 153), rng, 0.95)
			local post = polar(angle + side * math.rad(10), 72)
			Build.part(decor, "LanternPost", Vector3.new(0.5, 6, 0.5), CFrame.new(post + Vector3.new(0, 3, 0)), rgb(60, 40, 35), { Material = Enum.Material.Wood })
			paperLantern(decor, post + Vector3.new(0, 6.6, 0), rgb(255, 80, 60))
		end
		if i == 3 then
			Build.disc(decor, "DojoFloor", 0.6, 20, polar(angle, 112) - Vector3.new(0, 0.2, 0), rgb(200, 160, 110), { Material = Enum.Material.WoodPlanks })
		end
	end
	-- Grande pleine lune.
	local moon = Build.ball(decor, "Moon", 150, Vector3.new(-350, 420, -650), rgb(255, 250, 220), { Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
	moon.CanQuery = false
	scatter(decor, rng, 50, RING_IN + 4, RING_OUT - 4, function(parent, base, r)
		Build.deco(parent, "Petal", Vector3.new(0.6, 0.05, 0.4), CFrame.new(base + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0), rgb(210, 160, 255))
	end, 1)
	scatter(decor, rng, 20, RING_IN + 4, RING_OUT - 4, smallRock)
	ambientParticles(decor, ColorSequence.new(rgb(220, 170, 255), rgb(170, 110, 240)), Enum.NormalId.Bottom, 40, NumberRange.new(2, 4), 0.7, 40)
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

-- Construit le décor d'un univers (sans le placer).
function UniverseDecor.build(universe): Model
	local decor = Instance.new("Model")
	decor.Name = "Decor"
	local builder = THEMES[universe.theme.decor] or THEMES.ninja
	builder(decor, Random.new(universe.index * 1000 + 7), universe.theme)
	decor:SetAttribute("UniverseId", universe.id)
	return decor
end

local function storage(): Folder
	local folder = ServerStorage:FindFirstChild("DecorsUnivers")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "DecorsUnivers"
		folder.Parent = ServerStorage
	end
	return folder :: Folder
end

-- Colore les éléments marqués "UniverseTint" (cristal du hub, arène...) aux couleurs de l'univers.
function UniverseDecor.tint(universe, root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("UniverseTint") then
			descendant.Color = universe.color
			local light = descendant:FindFirstChildOfClass("PointLight")
			if light then
				light.Color = universe.color
			end
		end
	end
end

-- Affiche le décor d'un univers dans l'anneau. Les décors déjà construits (ou retouchés dans
-- Studio) sont simplement échangés avec ServerStorage.DecorsUnivers.
function UniverseDecor.apply(universe, zone: Instance)
	local store = storage()
	local current = zone:FindFirstChild("Decor")
	if current then
		local id = current:GetAttribute("UniverseId")
		if id == universe.id then
			UniverseDecor.tint(universe, zone.Parent or zone)
			return current
		end
		if id and not store:FindFirstChild(id) then
			current.Name = id
			current.Parent = store
		else
			current:Destroy()
		end
	end
	local decor = store:FindFirstChild(universe.id)
	if decor then
		decor.Name = "Decor"
	else
		decor = UniverseDecor.build(universe)
	end
	decor.Parent = zone
	UniverseDecor.tint(universe, zone.Parent or zone)
	return decor
end

return UniverseDecor
