-- Outils communs aux décors d'univers (Themes/*.luau) :
--   * zones libres (anneau, île) en évitant chemins, arène, bases, eau, sentier, falaises ;
--   * forêts en bosquets (plusieurs essences, sous-bois : buissons, fougères, souches, rochers) ;
--   * couronne de montagnes d'horizon ;
--   * lampes le long de la promenade et des rues, particules d'ambiance ;
--   * repères polaires (angle en degrés, rayon) avec -Z local tourné vers le centre.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Build = require(script.Parent.Parent.Parent.Modules.Build)
local Core = require(script.Parent.Parent.Kit.Core)
local Nature = require(script.Parent.Parent.Kit.Nature)
local Props = require(script.Parent.Parent.Kit.Props)
local WorldBuilder = require(script.Parent.Parent.WorldBuilder)

local Common = {}

local UP = Vector3.new(0, 1, 0)
Common.TOP_RING = 0.08
Common.TOP_PLAZA = 0.13

function Common.polar(angle: number, radius: number, y: number?): Vector3
	local a = math.rad(angle)
	return Vector3.new(math.cos(a) * radius, y or 0, math.sin(a) * radius)
end

-- Repère au sol à (angle, rayon), -Z local tourné vers le centre de la carte.
function Common.facing(angle: number, radius: number, y: number?): CFrame
	local pos = Common.polar(angle, radius, y)
	return CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
end

-- Écart angulaire (degrés, 0..180).
function Common.angleDiff(a: number, b: number): number
	return math.abs((a - b + 180) % 360 - 180)
end

-- Angle (degrés) d'une position.
function Common.angleOf(pos: Vector3): number
	return math.deg(math.atan2(pos.Z, pos.X)) % 360
end

-- Vrai si la position est dans une bande d'ennemis (on y évite les obstacles qui bloquent).
function Common.inBand(pos: Vector3, pad: number?): boolean
	local r = Vector3.new(pos.X, 0, pos.Z).Magnitude
	local p = pad or 0
	for _, band in Layout.EnemyBands do
		if r > band[1] - p and r < band[2] + p then
			return true
		end
	end
	return false
end

-- Vrai si l'endroit de l'anneau est libre (hors chemins, arène, hub).
function Common.ringFree(pos: Vector3, margin: number): boolean
	local r = Vector3.new(pos.X, 0, pos.Z).Magnitude
	return r > Layout.RingInner + margin and r < Layout.RingOuter - margin and not Layout.onPath(pos, margin + 2) and not Layout.inBossArena(pos, margin + 6)
end

-- Fabrique un test « île libre » qui évite aussi des zones réservées (repères de l'univers).
-- `reserved` = liste de { centre: Vector3, rayon: number }.
function Common.islandFree(reserved: { { any } }?): (Vector3, number) -> boolean
	return function(pos: Vector3, margin: number): boolean
		if not WorldBuilder.isFree(pos, margin) then
			return false
		end
		for _, zone in reserved or {} do
			if (Vector3.new(pos.X, 0, pos.Z) - zone[1]).Magnitude < zone[2] + margin then
				return false
			end
		end
		return true
	end
end

-- Pied d'un objet posé sur l'île (suit les collines).
function Common.ground(pos: Vector3): Vector3
	return Vector3.new(pos.X, WorldBuilder.groundY(pos), pos.Z)
end

export type ForestSpec = {
	groves: number,
	perGrove: { number },
	radius: { number },
	species: { { any } }, -- { nom, poids, hauteurMin, hauteurMax, palette? }
	free: (Vector3, number) -> boolean,
	minR: number?,
	maxR: number?,
	undergrowth: { palette: any?, ferns: Color3?, flowers: { Color3 }?, rocks: Color3?, mushrooms: boolean? }?,
	spacing: number?,
}

local function pickSpecies(rng: Random, list: { { any } })
	local total = 0
	for _, entry in list do
		total += entry[2]
	end
	local roll = rng:NextNumber(0, total)
	for _, entry in list do
		roll -= entry[2]
		if roll <= 0 then
			return entry
		end
	end
	return list[#list]
end

-- Forêt en bosquets sur l'île. Renvoie le nombre d'arbres plantés.
function Common.forest(folder: Instance, rng: Random, spec: ForestSpec): number
	local planted = 0
	local taken: { Vector3 } = {}
	local minR = spec.minR or (Layout.WalkwayOuter + 16)
	local maxR = spec.maxR or (Layout.IslandRadius - 12)
	Core.scatter(rng, spec.groves, Vector3.zero, minR, maxR, function(p)
		return spec.free(p, 14)
	end, function(center)
		local n = rng:NextInteger(spec.perGrove[1], spec.perGrove[2])
		local gr = rng:NextNumber(spec.radius[1], spec.radius[2])
		for _ = 1, n * 4 do
			if n <= 0 then
				break
			end
			local a = rng:NextNumber(0, math.pi * 2)
			local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * gr * math.sqrt(rng:NextNumber())
			local entry = pickSpecies(rng, spec.species)
			local h = rng:NextNumber(entry[3], entry[4])
			local spacing = (spec.spacing or 0.32) * h
			local ok = spec.free(p, 4)
			if ok then
				for _, other in taken do
					if (other - p).Magnitude < spacing then
						ok = false
						break
					end
				end
			end
			if ok then
				table.insert(taken, p)
				local r = Vector3.new(p.X, 0, p.Z).Magnitude
				local detail = r < 560 and "normal" or "low"
				Nature.tree(entry[1], folder, Common.ground(p), { rng = rng, height = h, palette = entry[5], detail = detail })
				planted += 1
				n -= 1
			end
		end
		-- sous-bois
		local u = spec.undergrowth
		if u then
			for _ = 1, rng:NextInteger(3, 6) do
				local a = rng:NextNumber(0, math.pi * 2)
				local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * gr * rng:NextNumber(0.3, 1.1)
				if spec.free(p, 2) then
					local roll = rng:NextNumber()
					local g = Common.ground(p)
					if roll < 0.45 then
						Nature.bush(folder, g, { rng = rng, height = rng:NextNumber(3, 5.5), palette = u.palette, flowers = (u.flowers and rng:NextNumber() < 0.3) and u.flowers[rng:NextInteger(1, #u.flowers)] or nil })
					elseif roll < 0.7 and u.ferns then
						Nature.fern(folder, g, rng:NextNumber(3, 5), u.ferns, rng)
					elseif roll < 0.85 then
						Nature.rock(folder, g, rng:NextNumber(3, 7), { rng = rng, color = u.rocks, moss = u.ferns })
					elseif roll < 0.93 then
						Nature.stump(folder, g, rng:NextNumber(2, 3.4), rng)
					elseif u.mushrooms then
						for _ = 1, 3 do
							Nature.mushroom(folder, g + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5)), rng:NextNumber(0.8, 1.6), rng)
						end
					else
						Nature.log(folder, CFrame.new(g) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(7, 11), rng:NextNumber(1.4, 2), rng)
					end
				end
			end
		end
	end)
	return planted
end

-- Couronne de montagnes d'horizon (dans la mer). `skip` = { { angle, demi-largeur } } à éviter.
function Common.horizon(folder: Instance, rng: Random, count: number, o: { rock: Color3, grass: Color3, snow: Color3?, trees: Color3?, skip: { { number } }?, material: Enum.Material?, scale: number? })
	for i = 0, count - 1 do
		local angle = i / count * 360 + rng:NextNumber(-4, 4)
		local blocked = false
		for _, s in o.skip or {} do
			if Common.angleDiff(angle, s[1]) < s[2] then
				blocked = true
			end
		end
		if not blocked then
			local radius = rng:NextNumber(Layout.HorizonInner + 70, Layout.HorizonOuter - 40)
			local k = o.scale or 1
			Nature.mountain(folder, Common.polar(angle, radius, -3), rng:NextNumber(150, 240) * k, rng:NextNumber(90, 170) * k, {
				rng = rng,
				rock = o.rock,
				grass = o.grass,
				snow = (o.snow and rng:NextNumber() < 0.45) and o.snow or nil,
				trees = o.trees,
				slot = "MontagneHorizon",
				material = o.material,
			})
		end
	end
end

-- Lampes le long de la promenade (bord extérieur), hors ouvertures des chemins.
-- `place(position)` pose la lampe choisie par l'univers.
function Common.walkwayLamps(_folder: Instance, every: number, place: (Vector3, number) -> ())
	local r = Layout.WalkwayOuter + 2.6
	local steps = math.floor(360 / every)
	for i = 0, steps - 1 do
		local angle = i * every + every / 2
		local pos = Common.polar(angle, r, 0.2)
		if not Layout.onPath(pos, 6) and not Layout.nearPlot(pos, 2) then
			place(pos, angle)
		end
	end
end

-- Objets de part et d'autre des rues dans l'anneau (rayons donnés), ex. lanternes.
function Common.alongRoads(radii: { number }, offset: number, place: (Vector3, number, number) -> ())
	for _, angle in Layout.PlotAngles do
		local deg = math.deg(angle)
		for _, side in { -1, 1 } do
			for _, radius in radii do
				local delta = math.deg((Layout.PathWidth / 2 + offset) / radius) * side
				place(Common.polar(deg + delta, radius, Common.TOP_RING), deg + delta, side)
			end
		end
	end
end

-- Pierre tombale japonaise (haka) ou lanterne : petits objets réutilisés par plusieurs univers.
function Common.stoneLantern(folder: Instance, pos: Vector3, scale: number?, glow: Color3?)
	Props.stoneLantern(folder, pos, scale, glow)
end

export type AmbientOptions = {
	texture: string?,
	colors: ColorSequence,
	size: number,
	rate: number,
	speed: NumberRange,
	direction: Enum.NormalId,
	y: number,
	radius: number?,
	lifetime: NumberRange?,
	lightEmission: number?,
	spin: boolean?,
	acceleration: Vector3?,
}

-- Particules d'ambiance (feuilles, pétales, lucioles, braises, brume...) au-dessus de la carte.
function Common.ambient(folder: Instance, name: string, o: AmbientOptions): ParticleEmitter
	local r = o.radius or Layout.RingOuter
	local part = Build.deco(folder, name, Vector3.new(r * 2, 1, r * 2), CFrame.new(0, o.y, 0), Color3.new(1, 1, 1), { Transparency = 1, CastShadow = false })
	part.Name = "Ambient"
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = o.texture or "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = o.colors
	emitter.LightEmission = o.lightEmission or 0.3
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.size), NumberSequenceKeypoint.new(1, o.size * 0.4) })
	emitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.15), NumberSequenceKeypoint.new(0.85, 0.25), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = o.lifetime or NumberRange.new(10, 14)
	emitter.Rate = o.rate
	emitter.Speed = o.speed
	emitter.EmissionDirection = o.direction
	emitter.SpreadAngle = Vector2.new(25, 25)
	if o.acceleration then
		emitter.Acceleration = o.acceleration
	end
	if o.spin ~= false then
		emitter.RotSpeed = NumberRange.new(-60, 60)
		emitter.Rotation = NumberRange.new(0, 360)
	end
	emitter.Parent = part
	return emitter
end

-- Rue circulaire (terre battue ou pavés) dans l'anneau, entre `r1` et `r2`, interrompue sur
-- les chemins et l'arène. Le rôle donne la couleur et le matériau de l'univers.
function Common.ringStreet(folder: Instance, r1: number, r2: number, role: string, rng: Random, segments: number?)
	local n = segments or 140
	local mid = (r1 + r2) / 2
	for i = 0, n - 1 do
		local a0 = i / n * 360
		local a1 = (i + 1) / n * 360
		local p0 = Common.polar(a0, mid, Common.TOP_PLAZA - 0.02)
		local p1 = Common.polar(a1, mid, Common.TOP_PLAZA - 0.02)
		local m = (p0 + p1) / 2
		if not Layout.inBossArena(m, 4) then
			local nuance = rng:NextNumber(-0.05, 0.05)
			local part = Build.deco(folder, "Street", Vector3.new(r2 - r1 + rng:NextNumber(-1, 1), 0.2, (p1 - p0).Magnitude + 0.6), CFrame.lookAt(m, p1), Color3.new(0.7, 0.6, 0.45), {
				Material = Enum.Material.Ground,
				CastShadow = false,
			})
			Core.solRole(part, role, nuance)
		end
	end
end

-- Détails au sol de l'anneau : taches, touffes, fleurs (couleurs suivant l'univers).
function Common.ringGround(folder: Instance, rng: Random, o: { patches: number, tufts: number, flowers: number, flowerColors: { Color3 }?, patchRole: string?, patchMaterial: Enum.Material? })
	Core.scatter(rng, o.patches, Vector3.zero, Layout.RingInner + 6, Layout.RingOuter - 10, function(p)
		return Common.ringFree(p, 6)
	end, function(p)
		local count = rng:NextInteger(3, 5)
		local size = rng:NextNumber(18, 36)
		for i = 1, count do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = i == 1 and 0 or size * rng:NextNumber(0.2, 0.42)
			local d = size * (i == 1 and 0.8 or rng:NextNumber(0.4, 0.65))
			local disc = Core.flatDisc(folder, "Patch", p + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), d, Common.TOP_PLAZA - 0.02 + (i % 2) * 0.01, Color3.new(0.5, 0.6, 0.4), o.patchMaterial or Enum.Material.LeafyGrass)
			Core.solRole(disc, o.patchRole or "herbe2")
		end
	end)
	Core.scatter(rng, o.tufts, Vector3.zero, Layout.RingInner + 2, Layout.RingOuter - 2, function(p)
		return Common.ringFree(p, 0)
	end, function(p)
		if rng:NextNumber() < 0.85 then
			Nature.tuft(folder, p + UP * Common.TOP_RING, rng:NextNumber(1.1, 1.8), Color3.new(0.4, 0.6, 0.3), rng, "touffe")
		else
			Nature.tallGrass(folder, p + UP * Common.TOP_RING, rng:NextNumber(2.4, 3.6), Color3.new(0.4, 0.6, 0.3), rng, "touffe")
		end
	end)
	if o.flowerColors then
		Core.scatter(rng, o.flowers, Vector3.zero, Layout.RingInner + 2, Layout.RingOuter - 2, function(p)
			return Common.ringFree(p, 0)
		end, function(p)
			Nature.flower(folder, p + UP * Common.TOP_RING, o.flowerColors[rng:NextInteger(1, #o.flowerColors)], rng)
		end)
	end
end

return Common
