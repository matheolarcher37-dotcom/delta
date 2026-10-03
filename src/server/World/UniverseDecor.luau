-- Décor de la zone d'univers : change complètement à chaque rotation (toutes les 30 min).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Build = require(script.Parent.Parent.Modules.Build)

local UniverseDecor = {}

local rgb = Color3.fromRGB
local R = Layout.ZoneRadius

local function polar(angle: number, radius: number, y: number?): Vector3
	return Vector3.new(math.cos(angle) * radius, y or 0, math.sin(angle) * radius)
end

-- CFrame au sol, à un angle/rayon donné, qui regarde vers le centre.
local function facingCenter(angle: number, radius: number): CFrame
	local pos = polar(angle, radius)
	return CFrame.lookAt(pos, Vector3.new(0, 0, 0))
end

local function sectorAngles(): { number }
	local angles = {}
	for _, a in Layout.PlotAngles do
		table.insert(angles, a + math.rad(30))
	end
	return angles
end

local function ambientParticles(parent: Instance, color: ColorSequence, direction: Enum.NormalId, y: number, speed: NumberRange, size: number, rate: number)
	local emitterPart = Build.deco(parent, "Ambient", Vector3.new(R * 1.8, 1, R * 1.8), CFrame.new(0, y, 0), Color3.new(1, 1, 1), { Transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = color
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 0.4) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(6, 10)
	emitter.Rate = rate
	emitter.Speed = speed
	emitter.EmissionDirection = direction
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Parent = emitterPart
end

local function scatter(parent: Instance, rng: Random, count: number, minR: number, maxR: number, fn: (Instance, Vector3, Random) -> ())
	for _ = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(minR, maxR)
		fn(parent, polar(angle, radius, 0.15), rng)
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
	Build.part(parent, "LanternRoof", Vector3.new(2.8, 0.7, 2.8), CFrame.new(base + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, math.rad(45), 0), stone, { Material = Enum.Material.Slate })
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
	Build.part(parent, "Pebble", size, CFrame.new(base + Vector3.new(0, size.Y / 2 - 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), color, { Material = Enum.Material.Slate })
end

local function groundPatches(parent: Instance, rng: Random, color: Color3, count: number)
	for _ = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(10, R - 6)
		local size = rng:NextNumber(3, 7)
		Build.deco(parent, "Patch", Vector3.new(size, 0.06, size * rng:NextNumber(0.6, 1.3)), CFrame.new(polar(angle, radius, 0.16)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), color)
	end
end

local function palmTree(parent: Instance, base: Vector3, rng: Random)
	local model = Build.model(parent, "Palm")
	local lean = rng:NextNumber(0.1, 0.25)
	local dir = rng:NextNumber(0, math.pi * 2)
	local cf = CFrame.new(base) * CFrame.Angles(0, dir, 0)
	for i = 0, 5 do
		cf = cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(lean * 0.35, 0, 0)
		Build.part(model, "Trunk", Vector3.new(1.3 - i * 0.07, 3.2, 1.3 - i * 0.07), cf * CFrame.new(0, 0, 0), rgb(150, 110, 70):Lerp(rgb(120, 85, 55), (i % 2) * 0.6), { Material = Enum.Material.Wood })
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
	Build.part(model, "Trunk", Vector3.new(2.2 * s, 9 * s, 2.2 * s), CFrame.new(base + Vector3.new(0, 4.5 * s, 0)) * CFrame.Angles(0, 0, 0.05), rgb(90, 60, 45), { Material = Enum.Material.Wood })
	Build.part(model, "Branch", Vector3.new(8 * s, 1.2 * s, 1.2 * s), CFrame.new(base + Vector3.new(0, 8.5 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0.15), rgb(90, 60, 45), { Material = Enum.Material.Wood })
	Build.part(model, "Canopy", Vector3.new(13 * s, 2.5 * s, 13 * s), CFrame.new(base + Vector3.new(0, 10 * s, 0)), rgb(90, 140, 80), { Material = Enum.Material.Grass })
	Build.part(model, "Canopy2", Vector3.new(9 * s, 2 * s, 9 * s), CFrame.new(base + Vector3.new(0, 11.8 * s, 0)) * CFrame.Angles(0, 0.4, 0), rgb(100, 150, 90), { Material = Enum.Material.Grass })
	for _ = 1, 16 do
		local x = rng:NextNumber(-5.8, 5.8) * s
		local z = rng:NextNumber(-5.8, 5.8) * s
		local length = rng:NextNumber(2, 4.5) * s
		local purple = rgb(190, 140, 255):Lerp(rgb(240, 200, 255), rng:NextNumber())
		Build.deco(model, "Bloom", Vector3.new(1.1 * s, length, 1.1 * s), CFrame.new(base + Vector3.new(x, 8.8 * s - length / 2, z)), purple, { Material = rng:NextNumber() < 0.5 and Enum.Material.Neon or Enum.Material.SmoothPlastic, Transparency = 0.1 })
	end
end

------------------------------------------------------------------------
-- Thèmes
------------------------------------------------------------------------

local THEMES = {}

-- VILLAGE NINJA ---------------------------------------------------------
THEMES.ninja = function(decor: Instance, rng: Random)
	groundPatches(decor, rng, rgb(130, 90, 60), 28)
	for _, angle in Layout.PlotAngles do
		Build.torii(decor, facingCenter(angle, Layout.ZoneFenceRadius), 15, 13, rgb(230, 90, 30), rgb(60, 40, 30))
	end
	local roofs = { rgb(210, 60, 40), rgb(240, 130, 40), rgb(70, 120, 200) }
	for i, angle in sectorAngles() do
		local cf = facingCenter(angle, 64)
		if i % 3 == 0 then
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
			Build.house(decor, cf, Vector3.new(14, 9, 10), rgb(240, 225, 195), roofs[(i % #roofs) + 1], rgb(120, 80, 50))
		end
		for _, side in { -1, 1 } do
			Build.tree(decor, polar(angle + side * math.rad(17), 68), rng:NextNumber(1.1, 1.5), rgb(70, 170, 70), nil, rng)
		end
		Build.lantern(decor, polar(angle + math.rad(9), 56), rgb(255, 150, 60))
	end
	-- Poteaux d'entraînement.
	for i = 0, 2 do
		local pos = polar(math.rad(i * 120 + 10), 48)
		Build.disc(decor, "TrainingLog", 5, 1.6, pos, rgb(140, 95, 60), { Material = Enum.Material.Wood })
		Build.disc(decor, "Rope", 0.4, 1.7, pos + Vector3.new(0, 3, 0), rgb(220, 200, 150))
	end
	-- Arène centrale (examen ninja).
	Build.disc(decor, "Arena", 1, 26, Vector3.new(0, -0.3, 0), rgb(170, 165, 160), { Material = Enum.Material.Slate })
	Build.disc(decor, "ArenaRing", 1.02, 20, Vector3.new(0, -0.29, 0), rgb(150, 145, 140), { Material = Enum.Material.Slate })
	Build.deco(decor, "Spiral", Vector3.new(6, 0.1, 6), CFrame.new(0, 0.75, 0) * CFrame.Angles(0, math.rad(45), 0), rgb(240, 120, 30))
	Build.deco(decor, "SpiralCore", Vector3.new(3, 0.12, 3), CFrame.new(0, 0.77, 0), rgb(200, 50, 30))
	scatter(decor, rng, 18, 14, 58, kunai)
	scatter(decor, rng, 14, 14, 58, shuriken)
	scatter(decor, rng, 16, 14, 60, smallRock)
	ambientParticles(decor, ColorSequence.new(rgb(90, 190, 70), rgb(160, 220, 90)), Enum.NormalId.Bottom, 45, NumberRange.new(3, 5), 0.6, 18)
end

-- ACADÉMIE OCCULTE ------------------------------------------------------
THEMES.occulte = function(decor: Instance, rng: Random)
	groundPatches(decor, rng, rgb(65, 60, 72), 30)
	-- Dalles de pierre.
	for i = 0, 40 do
		local angle = i * 2.4
		local radius = 14 + (i % 10) * 4.5
		Build.deco(decor, "Tile", Vector3.new(3.6, 0.08, 3.6), CFrame.new(polar(angle, radius, 0.17)) * CFrame.Angles(0, angle, 0), rgb(100, 95, 110))
	end
	for _, angle in Layout.PlotAngles do
		Build.torii(decor, facingCenter(angle, Layout.ZoneFenceRadius), 15, 14, rgb(150, 25, 35), rgb(20, 15, 20))
	end
	for i, angle in sectorAngles() do
		local cf = facingCenter(angle, 64)
		Build.house(decor, cf, Vector3.new(15, 10, 11), rgb(70, 50, 40), rgb(40, 35, 50), rgb(150, 30, 40))
		for _, side in { -1, 1 } do
			Build.pine(decor, polar(angle + side * math.rad(17), 69), rng:NextNumber(1.4, 1.9), rgb(30, 80, 55))
			stoneLantern(decor, polar(angle + side * math.rad(10), 55))
		end
		local _ = i
	end
	-- Cercle rituel au centre.
	Build.disc(decor, "Ritual", 1, 26, Vector3.new(0, -0.3, 0), rgb(30, 25, 40), { Material = Enum.Material.Slate })
	local ring = Build.disc(decor, "RitualRing", 1.05, 22, Vector3.new(0, -0.28, 0), rgb(170, 60, 255), { Material = Enum.Material.Neon })
	ring.Transparency = 0.2
	Build.disc(decor, "RitualInner", 1.1, 20, Vector3.new(0, -0.27, 0), rgb(30, 25, 40), { Material = Enum.Material.Slate })
	for i = 0, 3 do
		local pos = polar(i * math.pi / 2 + math.pi / 4, 11)
		Build.part(decor, "SealPillar", Vector3.new(1.2, 5, 1.2), CFrame.new(pos + Vector3.new(0, 2.5, 0)), rgb(40, 35, 45), { Material = Enum.Material.Slate })
		Build.deco(decor, "SealPaper", Vector3.new(0.8, 1.6, 0.1), CFrame.new(pos + Vector3.new(0, 3.2, 0)) * CFrame.lookAt(Vector3.zero, -pos).Rotation * CFrame.new(0, 0, -0.66), rgb(245, 235, 200))
	end
	scatter(decor, rng, 22, 14, 60, function(parent, base, r)
		Build.deco(parent, "Talisman", Vector3.new(0.8, 0.06, 1.6), CFrame.new(base + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0), rgb(245, 235, 200))
		Build.deco(parent, "TalismanInk", Vector3.new(0.2, 0.07, 1.2), CFrame.new(base + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0), rgb(200, 30, 40))
	end)
	scatter(decor, rng, 18, 14, 60, smallRock)
	ambientParticles(decor, ColorSequence.new(rgb(170, 60, 255), rgb(90, 20, 160)), Enum.NormalId.Top, 0.5, NumberRange.new(1, 3), 1.2, 22)
end

-- PLANÈTE DES GUERRIERS ---------------------------------------------------
THEMES.saiyan = function(decor: Instance, rng: Random)
	groundPatches(decor, rng, rgb(195, 160, 105), 26)
	for _, angle in Layout.PlotAngles do
		local cf = facingCenter(angle, Layout.ZoneFenceRadius)
		for _, side in { -1, 1 } do
			Build.part(decor, "GatePillar", Vector3.new(3, 12, 3), cf * CFrame.new(side * 8, 6, 0), rgb(200, 170, 120), { Material = Enum.Material.Sandstone })
			Build.ball(decor, "GateOrb", 3.2, (cf * CFrame.new(side * 8, 13.6, 0)).Position, rgb(255, 160, 30), { Material = Enum.Material.Glass, Transparency = 0.1 })
			Build.deco(decor, "GateStar", Vector3.new(0.9, 0.9, 0.2), cf * CFrame.new(side * 8, 13.6, -1.65) * CFrame.Angles(0, 0, math.rad(45)), rgb(220, 40, 30), { Material = Enum.Material.Neon })
		end
	end
	for i, angle in sectorAngles() do
		local pos = polar(angle, 64)
		if i % 2 == 0 then
			-- Maison-dôme futuriste.
			Build.ball(decor, "Dome", 14, pos + Vector3.new(0, 2, 0), rgb(250, 250, 250))
			Build.disc(decor, "DomeBand", 1.2, 14.4, pos + Vector3.new(0, 3, 0), rgb(60, 130, 230))
			Build.ball(decor, "DomeTop", 4, pos + Vector3.new(0, 9, 0), rgb(250, 250, 250))
			local dir = (-pos).Unit
			Build.disc(decor, "DomeDoor", 0.4, 4, pos + dir * 6.8 + Vector3.new(0, 0.2, 0), rgb(60, 130, 230))
		else
			-- Pic rocheux.
			local height = rng:NextNumber(22, 34)
			local levels = 5
			for l = 0, levels - 1 do
				local width = (9 - l * 1.4)
				Build.part(decor, "Spire", Vector3.new(width, height / levels + 0.5, width), CFrame.new(pos + Vector3.new(rng:NextNumber(-0.6, 0.6), (l + 0.5) * height / levels, rng:NextNumber(-0.6, 0.6))) * CFrame.Angles(0, l * 0.3, 0), rgb(205, 170, 115):Lerp(rgb(170, 130, 90), l / levels), { Material = Enum.Material.Sandstone })
			end
		end
		for _, side in { -1, 1 } do
			local tree = polar(angle + side * math.rad(18), 68)
			Build.part(decor, "TreeTrunk", Vector3.new(0.8, 8, 0.8), CFrame.new(tree + Vector3.new(0, 4, 0)), rgb(140, 110, 80), { Material = Enum.Material.Wood })
			Build.ball(decor, "TreeTop", 5.5, tree + Vector3.new(0, 9.5, 0), rgb(80, 190, 150), { Material = Enum.Material.Grass })
		end
	end
	-- Ring du tournoi.
	Build.part(decor, "TournamentRing", Vector3.new(26, 1.6, 26), CFrame.new(0, 0.6, 0), rgb(220, 215, 205), { Material = Enum.Material.Slate })
	for x = -2, 2 do
		for z = -2, 2 do
			if (x + z) % 2 == 0 then
				Build.deco(decor, "RingTile", Vector3.new(5, 0.05, 5), CFrame.new(x * 5, 1.42, z * 5), rgb(200, 195, 185))
			end
		end
	end
	scatter(decor, rng, 10, 18, 56, function(parent, base, r)
		local d = r:NextNumber(5, 9)
		Build.disc(parent, "Crater", 0.1, d, base + Vector3.new(0, 0.02, 0), rgb(165, 130, 90), { CanCollide = false })
		Build.disc(parent, "CraterCore", 0.12, d * 0.6, base + Vector3.new(0, 0.03, 0), rgb(140, 105, 70), { CanCollide = false })
	end)
	scatter(decor, rng, 20, 14, 60, smallRock)
	ambientParticles(decor, ColorSequence.new(rgb(255, 230, 90), rgb(255, 160, 40)), Enum.NormalId.Top, 0.5, NumberRange.new(2, 4), 0.5, 16)
end

-- GRAND OCÉAN --------------------------------------------------------------
THEMES.ocean = function(decor: Instance, rng: Random)
	groundPatches(decor, rng, rgb(225, 205, 145), 24)
	for _, angle in Layout.PlotAngles do
		local cf = facingCenter(angle, Layout.ZoneFenceRadius)
		for _, side in { -1, 1 } do
			Build.part(decor, "ArchPost", Vector3.new(1.6, 12, 1.6), cf * CFrame.new(side * 8, 6, 0), rgb(120, 80, 50), { Material = Enum.Material.Wood })
		end
		Build.part(decor, "ArchBeam", Vector3.new(19, 1.4, 1.6), cf * CFrame.new(0, 12, 0), rgb(120, 80, 50), { Material = Enum.Material.Wood })
		Build.deco(decor, "Flag", Vector3.new(6, 4, 0.2), cf * CFrame.new(0, 9.8, -0.3), rgb(25, 25, 30), { Material = Enum.Material.Fabric })
		Build.deco(decor, "Skull", Vector3.new(1.8, 1.6, 0.1), cf * CFrame.new(0, 10.1, -0.45), rgb(245, 245, 245))
		Build.deco(decor, "Bones", Vector3.new(3.4, 0.4, 0.08), cf * CFrame.new(0, 9.2, -0.42) * CFrame.Angles(0, 0, 0.5), rgb(245, 245, 245))
		Build.deco(decor, "Bones", Vector3.new(3.4, 0.4, 0.08), cf * CFrame.new(0, 9.2, -0.42) * CFrame.Angles(0, 0, -0.5), rgb(245, 245, 245))
	end
	for i, angle in sectorAngles() do
		local cf = facingCenter(angle, 63)
		if i == 2 or i == 5 then
			-- Bateau pirate en blocs.
			local ship = Build.model(decor, "PirateShip")
			local shipCF = cf * CFrame.Angles(0, math.rad(90), 0)
			local hull = rgb(130, 80, 45)
			Build.part(ship, "Hull", Vector3.new(7, 3.5, 22), shipCF * CFrame.new(0, 1.75, 0), hull, { Material = Enum.Material.WoodPlanks })
			Build.part(ship, "HullLow", Vector3.new(5, 1.5, 18), shipCF * CFrame.new(0, 0.2, 0), hull:Lerp(Color3.new(0, 0, 0), 0.2), { Material = Enum.Material.WoodPlanks })
			Build.wedge(ship, "Bow", Vector3.new(7, 3.5, 5), shipCF * CFrame.new(0, 1.75, -13.5) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, 0), hull, { Material = Enum.Material.WoodPlanks })
			Build.part(ship, "Cabin", Vector3.new(7, 3, 5), shipCF * CFrame.new(0, 5, 8), hull:Lerp(Color3.new(1, 1, 1), 0.1), { Material = Enum.Material.WoodPlanks })
			Build.part(ship, "Rail", Vector3.new(7.4, 0.8, 22.4), shipCF * CFrame.new(0, 3.9, 0), rgb(240, 200, 90))
			Build.part(ship, "Mast", Vector3.new(0.9, 20, 0.9), shipCF * CFrame.new(0, 13, -1), rgb(110, 70, 40), { Material = Enum.Material.Wood })
			Build.deco(ship, "Sail", Vector3.new(11, 7, 0.3), shipCF * CFrame.new(0, 13, -1.6) * CFrame.Angles(0, math.rad(90), 0), rgb(250, 245, 230), { Material = Enum.Material.Fabric })
			Build.deco(ship, "Sail2", Vector3.new(8, 5, 0.3), shipCF * CFrame.new(0, 19.5, -1.6) * CFrame.Angles(0, math.rad(90), 0), rgb(250, 245, 230), { Material = Enum.Material.Fabric })
			Build.deco(ship, "JollyRoger", Vector3.new(0.2, 2.5, 3.5), shipCF * CFrame.new(0, 24, 0.8), rgb(25, 25, 30), { Material = Enum.Material.Fabric })
			Build.deco(ship, "Figurehead", Vector3.new(2.5, 2.5, 2.5), shipCF * CFrame.new(0, 3.5, -16), rgb(255, 230, 120))
		else
			palmTree(decor, cf.Position, rng)
			for b = 0, 2 do
				local pos = polar(angle + math.rad(6 + b * 3), 57 + b)
				Build.disc(decor, "Barrel", 2.6, 2, pos, rgb(150, 100, 60), { Material = Enum.Material.Wood })
				Build.disc(decor, "BarrelBand", 0.3, 2.1, pos + Vector3.new(0, 1.8, 0), rgb(80, 80, 85), { Material = Enum.Material.Metal })
			end
		end
		for _, side in { -1, 1 } do
			palmTree(decor, polar(angle + side * math.rad(19), 69), rng)
			Build.part(decor, "Crate", Vector3.new(2.6, 2.6, 2.6), CFrame.new(polar(angle - side * math.rad(9), 56, 1.3)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), rgb(170, 125, 75), { Material = Enum.Material.WoodPlanks })
		end
	end
	-- Pont central en bois avec trésor.
	Build.disc(decor, "Deck", 1, 26, Vector3.new(0, -0.3, 0), rgb(160, 110, 70), { Material = Enum.Material.WoodPlanks })
	Build.disc(decor, "DeckRope", 1.02, 26.6, Vector3.new(0, -0.35, 0), rgb(220, 200, 150), { Material = Enum.Material.Fabric })
	for i = 0, 7 do
		local pos = polar(i * math.pi / 4, 12)
		Build.part(decor, "Bollard", Vector3.new(1, 2, 1), CFrame.new(pos + Vector3.new(0, 1.5, 0)), rgb(110, 70, 40), { Material = Enum.Material.Wood })
	end
	-- Petite lagune.
	local lagoon = polar(math.rad(200), 40)
	Build.disc(decor, "Lagoon", 0.3, 14, lagoon + Vector3.new(0, 0.05, 0), rgb(60, 190, 230), { Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
	scatter(decor, rng, 18, 14, 60, function(parent, base, r)
		local colors = { rgb(255, 170, 180), rgb(255, 140, 60), rgb(250, 240, 220) }
		Build.deco(parent, "Shell", Vector3.new(0.7, 0.3, 0.6), CFrame.new(base + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0), colors[r:NextInteger(1, #colors)])
	end)
	scatter(decor, rng, 14, 14, 58, function(parent, base, r)
		Build.deco(parent, "Coin", Vector3.new(0.12, 0.8, 0.8), CFrame.new(base + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, r:NextNumber(0, math.pi), math.rad(90)), rgb(255, 205, 50), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal })
	end)
	ambientParticles(decor, ColorSequence.new(rgb(200, 240, 255), rgb(120, 210, 255)), Enum.NormalId.Top, 0.5, NumberRange.new(1, 2), 0.5, 14)
end

-- ÈRE DES POURFENDEURS -----------------------------------------------------
THEMES.pourfendeur = function(decor: Instance, rng: Random)
	groundPatches(decor, rng, rgb(80, 62, 55), 26)
	for _, angle in Layout.PlotAngles do
		local cf = facingCenter(angle, Layout.ZoneFenceRadius)
		for _, side in { -1, 1 } do
			Build.part(decor, "ArchPost", Vector3.new(1.4, 12, 1.4), cf * CFrame.new(side * 8, 6, 0), rgb(60, 40, 35), { Material = Enum.Material.Wood })
		end
		Build.part(decor, "ArchBeam", Vector3.new(19, 1, 3), cf * CFrame.new(0, 12, 0), rgb(60, 40, 35), { Material = Enum.Material.Wood })
		for i = -3, 3 do
			local length = 2 + (3 - math.abs(i)) * 0.6
			Build.deco(decor, "Bloom", Vector3.new(1, length, 1), cf * CFrame.new(i * 2.4, 11.5 - length / 2, 0), rgb(200, 150, 255), { Material = Enum.Material.Neon, Transparency = 0.15 })
		end
	end
	for i, angle in sectorAngles() do
		local cf = facingCenter(angle, 64)
		if i % 2 == 0 then
			Build.house(decor, cf, Vector3.new(14, 8, 10), rgb(240, 235, 225), rgb(50, 45, 60), rgb(80, 50, 40))
		else
			wisteriaTree(decor, cf.Position, rng, 1.25)
		end
		for _, side in { -1, 1 } do
			wisteriaTree(decor, polar(angle + side * math.rad(18), 69), rng, 0.9)
			local post = polar(angle + side * math.rad(9), 55)
			Build.part(decor, "LanternPost", Vector3.new(0.5, 6, 0.5), CFrame.new(post + Vector3.new(0, 3, 0)), rgb(60, 40, 35), { Material = Enum.Material.Wood })
			paperLantern(decor, post + Vector3.new(0, 6.6, 0), rgb(255, 80, 60))
		end
	end
	-- Plancher de dojo au centre.
	Build.disc(decor, "DojoFloor", 1, 26, Vector3.new(0, -0.3, 0), rgb(200, 160, 110), { Material = Enum.Material.WoodPlanks })
	local circle = Build.disc(decor, "SunCircle", 1.03, 10, Vector3.new(0, -0.28, 0), rgb(220, 40, 40), { Material = Enum.Material.Neon })
	circle.Transparency = 0.3
	-- Grande pleine lune.
	local moon = Build.ball(decor, "Moon", 150, Vector3.new(-350, 420, -650), rgb(255, 250, 220), { Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
	moon.CanQuery = false
	scatter(decor, rng, 30, 14, 62, function(parent, base, r)
		Build.deco(parent, "Petal", Vector3.new(0.6, 0.05, 0.4), CFrame.new(base + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0), rgb(210, 160, 255))
	end)
	scatter(decor, rng, 12, 14, 60, smallRock)
	ambientParticles(decor, ColorSequence.new(rgb(220, 170, 255), rgb(170, 110, 240)), Enum.NormalId.Bottom, 40, NumberRange.new(2, 4), 0.7, 26)
end

------------------------------------------------------------------------

function UniverseDecor.apply(universe, zone: Instance)
	local floor = zone:FindFirstChild("ZoneFloor") :: BasePart?
	if floor then
		floor.Color = universe.theme.ground
	end
	local rim = zone:FindFirstChild("ZoneRim") :: BasePart?
	if rim then
		rim.Color = universe.theme.groundAccent:Lerp(Color3.new(0, 0, 0), 0.15)
	end
	local old = zone:FindFirstChild("Decor")
	if old then
		old:Destroy()
	end
	local decor = Instance.new("Model")
	decor.Name = "Decor"
	local builder = THEMES[universe.theme.decor] or THEMES.ninja
	builder(decor, Random.new(universe.index * 1000 + 7))
	decor.Parent = zone
	return decor
end

return UniverseDecor
