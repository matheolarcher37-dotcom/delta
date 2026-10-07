-- Outils communs aux décors d'univers (Themes/*.luau) :
--   * zones libres (anneau, île) en évitant chemins, arène, bases, eau, sentier, falaises ;
--   * forêts en bosquets (plusieurs essences, sous-bois : buissons, fougères, souches, rochers) ;
--   * couronne de montagnes d'horizon ;
--   * lampes le long de la promenade et des rues, particules d'ambiance ;
--   * repères polaires (angle en degrés, rayon) avec -Z local tourné vers le centre ;
--   * habillage de l'île (coins repos, clôtures, rochers, fleurs, ruines, étals), qui respecte
--     les lieux réservés et leurs accès (WorldBuilder.reserved).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Build = require(script.Parent.Parent.Parent.Modules.Build)
local Core = require(script.Parent.Parent.Kit.Core)
local Nature = require(script.Parent.Parent.Kit.Nature)
local Props = require(script.Parent.Parent.Kit.Props)
local Archi = require(script.Parent.Parent.Kit.Archi)
local Relief = require(script.Parent.Parent.Kit.Relief)
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
			-- les arbres restent loin des lieux réservés et de leurs accès (même leur feuillage)
			local ok = spec.free(p, 4) and not WorldBuilder.reserved(p, 4 + h * 0.25)
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
						Nature.bush(folder, g, {
							rng = rng,
							height = rng:NextNumber(3, 5.5),
							palette = u.palette,
							flowers = (u.flowers and rng:NextNumber() < 0.3) and u.flowers[rng:NextInteger(1, #u.flowers)] or nil,
						})
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
function Common.horizon(
	folder: Instance,
	rng: Random,
	count: number,
	o: { rock: Color3, grass: Color3, snow: Color3?, trees: Color3?, skip: { { number } }?, material: Enum.Material?, scale: number? }
)
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
		if not Layout.onPath(pos, 6) and not Layout.nearPlot(pos, 2) and not WorldBuilder.reserved(pos, 4) then
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

-- Zones où l'on voit les particules d'ambiance : le hub, 6 secteurs de l'anneau et les 6 bases
-- (un seul émetteur géant étalerait ses particules sur toute la carte : presque rien autour du
-- joueur). Chaque zone = { centre, rayon }.
local function ambientZones(radius: number): { { any } }
	local zones = { { Vector3.zero, math.min(radius, 110) } }
	if radius > 150 then
		for i = 0, 5 do
			table.insert(zones, { Common.polar(i * 60, 215), 125 })
		end
	end
	if radius > 380 then
		for _, angle in Layout.PlotAngles do
			table.insert(zones, { Vector3.new(math.cos(angle), 0, math.sin(angle)) * Layout.PlotRing, 110 })
		end
	end
	return zones
end

-- Particules d'ambiance (feuilles, pétales, lucioles, braises, brume...) au-dessus de la carte,
-- réparties dans les zones fréquentées. Renvoie le premier émetteur.
function Common.ambient(folder: Instance, name: string, o: AmbientOptions): ParticleEmitter
	local first: ParticleEmitter? = nil
	local zones = ambientZones(o.radius or Layout.RingOuter)
	for _, zone in zones do
		local r = zone[2]
		local part =
			Build.deco(folder, name, Vector3.new(r * 2, 1, r * 2), CFrame.new(zone[1] + Vector3.new(0, o.y, 0)), Color3.new(1, 1, 1), { Transparency = 1, CastShadow = false })
		part.Name = "Ambient"
		part.CanQuery = false
		part.CanTouch = false
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = name
		emitter.Texture = o.texture or "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = o.colors
		emitter.LightEmission = o.lightEmission or 0.3
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.size), NumberSequenceKeypoint.new(1, o.size * 0.4) })
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, 0.15),
			NumberSequenceKeypoint.new(0.85, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = o.lifetime or NumberRange.new(10, 14)
		-- débit proportionnel à la surface de la zone (densité constante)
		emitter.Rate = math.max(1, o.rate * (r * r) / (125 * 125) * 0.35)
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
		first = first or emitter
	end
	return first :: ParticleEmitter
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
			local part =
				Build.deco(folder, "Street", Vector3.new(r2 - r1 + rng:NextNumber(-1, 1), 0.2, (p1 - p0).Magnitude + 0.6), CFrame.lookAt(m, p1), Color3.new(0.7, 0.6, 0.45), {
					Material = Enum.Material.Ground,
					CastShadow = false,
				})
			Core.solRole(part, role, nuance)
		end
	end
end

-- Détails au sol de l'anneau : taches, touffes, fleurs (couleurs suivant l'univers).
function Common.ringGround(
	folder: Instance,
	rng: Random,
	o: { patches: number, tufts: number, flowers: number, flowerColors: { Color3 }?, patchRole: string?, patchMaterial: Enum.Material? }
)
	Core.scatter(rng, o.patches, Vector3.zero, Layout.RingInner + 6, Layout.RingOuter - 10, function(p)
		return Common.ringFree(p, 6)
	end, function(p)
		-- tache organique : ellipses aplaties qui se chevauchent, nuances proches du sol (pas de
		-- « pois » contrastés), parfois une plaque de terre au milieu
		local count = rng:NextInteger(3, 5)
		local size = rng:NextNumber(20, 42)
		local role = o.patchRole or (rng:NextNumber() < 0.5 and "herbe2" or "herbe3")
		for i = 1, count do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = i == 1 and 0 or size * rng:NextNumber(0.2, 0.45)
			local len = size * (i == 1 and 0.9 or rng:NextNumber(0.45, 0.7))
			local wid = len * rng:NextNumber(0.4, 0.75)
			local nuance = rng:NextNumber(-0.04, 0.04)
			local top = Common.TOP_PLAZA - 0.03 + (i % 3) * 0.006
			local patch = Core.ellipsoid(
				folder,
				"Patch",
				Vector3.new(len, 0.12, wid),
				CFrame.new(p + Vector3.new(math.cos(a) * r, top, math.sin(a) * r)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				Color3.new(0.5, 0.6, 0.4),
				o.patchMaterial or Enum.Material.LeafyGrass
			)
			patch.CastShadow = false
			Core.solRole(patch, role, nuance)
		end
		if rng:NextNumber() < 0.25 then
			local dirt = Core.ellipsoid(
				folder,
				"Patch",
				Vector3.new(size * 0.35, 0.12, size * 0.22),
				CFrame.new(p + Vector3.new(0, Common.TOP_PLAZA, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				Color3.new(0.6, 0.5, 0.4),
				Enum.Material.Ground
			)
			dirt.CastShadow = false
			Core.solRole(dirt, "terre", rng:NextNumber(-0.04, 0.04))
		end
	end)
	-- cailloux et petites pierres plates (sans collision, ne gênent pas les combats)
	Core.scatter(rng, math.floor(o.tufts * 0.35), Vector3.zero, Layout.RingInner + 2, Layout.RingOuter - 2, function(p)
		return Common.ringFree(p, 0)
	end, function(p)
		local size = rng:NextNumber(0.5, 1.4)
		local nuance = rng:NextNumber(-0.1, 0.08)
		local pebble = Core.ellipsoid(
			folder,
			"Pebble",
			Vector3.new(size, size * 0.45, size * rng:NextNumber(0.6, 1)),
			CFrame.new(p + UP * (Common.TOP_RING + size * 0.12)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			Color3.new(0.5, 0.5, 0.5),
			Enum.Material.Slate
		)
		pebble.CastShadow = false
		Core.solRole(pebble, "roche", nuance)
	end)
	-- prés d'herbes hautes fleuries (petits massifs)
	Core.scatter(rng, math.floor(o.tufts * 0.06), Vector3.zero, Layout.RingInner + 4, Layout.RingOuter - 4, function(p)
		return Common.ringFree(p, 2)
	end, function(p)
		for _ = 1, rng:NextInteger(4, 7) do
			local q = p + Vector3.new(rng:NextNumber(-2.4, 2.4), Common.TOP_RING, rng:NextNumber(-2.4, 2.4))
			Nature.tallGrass(folder, q, rng:NextNumber(2.4, 3.8), Color3.new(0.4, 0.6, 0.3), rng, "touffe")
		end
		if o.flowerColors then
			for _ = 1, rng:NextInteger(2, 4) do
				Nature.flower(folder, p + Vector3.new(rng:NextNumber(-2, 2), Common.TOP_RING, rng:NextNumber(-2, 2)), o.flowerColors[rng:NextInteger(1, #o.flowerColors)], rng)
			end
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

------------------------------------------------------------------------
-- Habillage de l'île (entre les bases, autour des chemins et du sentier)
------------------------------------------------------------------------

export type DressStyle = {
	wood: Color3?, -- bancs, clôtures, étals
	stone: Color3?, -- ruines, bornes
	rock: Color3?, -- rochers
	moss: Color3?,
	flowers: { Color3 }?,
	lanternGlow: Color3?,
	lantern: ((Instance, Vector3) -> ())?, -- lanterne propre à l'univers (sinon lanterne de pierre)
	fence: string?, -- style de clôture (Relief.fence)
	stalls: { { any } }?, -- étals près de la promenade : { couleur, marchandise }
	ruins: boolean?,
	extra: ((Instance, CFrame, Random) -> ())?, -- petit objet propre à l'univers près des bancs
}

-- Ruine : socle de dalles, colonnes brisées (hauteurs différentes, sommets éclatés), une colonne
-- couchée, quelques blocs tombés et de la mousse.
local function ruin(folder: Instance, cf: CFrame, stone: Color3, moss: Color3, rng: Random)
	local model = Core.slot(folder, "Ruine", cf, 12)
	Build.part(model, "RuineDalle", Vector3.new(16, 0.8, 10), cf * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, 0.02), Core.shade(stone, -0.08), {
		Material = Enum.Material.Cobblestone,
	})
	for i = 0, 3 do
		local x = -6 + i * 4
		local h = ({ 9, 4.5, 11, 2.5 })[i + 1] + rng:NextNumber(-0.8, 0.8)
		if i ~= 1 or rng:NextNumber() < 0.5 then
			local base = cf * CFrame.new(x, 0.6, -2.5)
			Archi.block(model, "RuineBase", Vector3.new(2.6, 0.8, 2.6), base, Core.shade(stone, -0.05), Enum.Material.Slate)
			Core.vcyl(model, "RuineColonne", base * CFrame.new(0, 0.8, 0), h, 1.9, Core.shade(stone, rng:NextNumber(-0.06, 0.04)), Enum.Material.Limestone)
			Build.deco(
				model,
				"RuineEclat",
				Vector3.new(1.9, 0.9, 1.9),
				base * CFrame.new(0.2, 0.8 + h, 0.1) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 1), rng:NextNumber(-0.4, 0.4)),
				stone,
				{ Material = Enum.Material.Limestone }
			)
			if rng:NextNumber() < 0.6 then
				Core.ellipsoid(model, "RuineMousse", Vector3.new(2.3, 1.1, 2.3), base * CFrame.new(0, 1.1, 0), moss, Enum.Material.Grass).CastShadow = false
			end
		end
	end
	-- linteau encore posé sur les deux grandes colonnes, et colonne tombée
	Build.part(model, "RuineLinteau", Vector3.new(9.5, 1.2, 2.4), cf * CFrame.new(0.5, 10.4, -2.5) * CFrame.Angles(0, 0, -0.12), stone, { Material = Enum.Material.Limestone })
	Core.cylinder(model, "RuineTombee", (cf * CFrame.new(-4, 1.6, 3)).Position, (cf * CFrame.new(4, 1.4, 4.2)).Position, 1.9, Core.shade(stone, -0.04), {
		Material = Enum.Material.Limestone,
	})
	for _ = 1, 3 do
		Build.part(
			model,
			"RuineBloc",
			Vector3.new(rng:NextNumber(1.4, 2.4), rng:NextNumber(1, 1.6), rng:NextNumber(1.4, 2.2)),
			cf * CFrame.new(rng:NextNumber(-8, 8), 0.7, rng:NextNumber(1, 6)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)),
			Core.shade(stone, rng:NextNumber(-0.1, 0.02)),
			{ Material = Enum.Material.Limestone }
		)
	end
	return model
end
Common.ruin = ruin

-- Coin repos au bord du sentier : banc tourné vers le sentier, lanterne, massif de fleurs,
-- parfois un objet propre à l'univers.
local function restSpot(folder: Instance, cf: CFrame, style: DressStyle, rng: Random)
	local model = Build.model(folder, "CoinRepos")
	Props.bench(model, cf, style.wood)
	local lanternAt = (cf * CFrame.new(5.2, 0, 0.6)).Position
	if style.lantern then
		style.lantern(model, lanternAt)
	else
		Props.stoneLantern(model, lanternAt, 0.8, style.lanternGlow)
	end
	if style.flowers then
		Nature.flowerBed(model, (cf * CFrame.new(-5.6, 0, 1)).Position, 2.2, style.flowers, rng, 5)
	end
	if style.extra and rng:NextNumber() < 0.6 then
		style.extra(model, cf * CFrame.new(-1.5, 0, 3.6), rng)
	end
end

-- Habille l'île d'un univers : coins repos et clôtures le long du sentier, amas de rochers,
-- massifs de fleurs, ruines et petits étals près de la promenade. Tout passe par `free`
-- (hors bases, chemins, eau, lieux réservés et leurs accès) et reste peu coûteux.
-- Renvoie un test « libre » qui évite en plus les éléments posés (à donner ensuite à la forêt).
function Common.dressIsland(folder: Instance, rng: Random, style: DressStyle, baseFree: (Vector3, number) -> boolean): (Vector3, number) -> boolean
	local dress = Build.folder(folder, "Habillage")
	local placed = 0
	local taken: { { any } } = {}
	local function free(p: Vector3, margin: number): boolean
		if not baseFree(p, margin) then
			return false
		end
		for _, t in taken do
			if (Vector3.new(p.X, 0, p.Z) - t[1]).Magnitude < t[2] + margin then
				return false
			end
		end
		return true
	end
	local function take(p: Vector3, radius: number)
		table.insert(taken, { Vector3.new(p.X, 0, p.Z), radius })
	end
	local wood = style.wood or Color3.fromRGB(140, 100, 66)
	local stone = style.stone or Color3.fromRGB(176, 170, 160)
	local rock = style.rock or Color3.fromRGB(132, 126, 118)
	local moss = style.moss or Color3.fromRGB(86, 126, 60)
	local trailR = WorldBuilder.TrailRadius
	-- 1) coins repos de part et d'autre du sentier
	for i = 0, 17 do
		local angle = i * 20 + 7 + rng:NextNumber(-3, 3)
		local side = (i % 2 == 0) and -1 or 1
		local r = trailR + side * 9
		local pos = Common.ground(Common.polar(angle, r))
		if free(pos, 5) then
			local look = Vector3.new(pos.X, pos.Y, pos.Z) + Common.polar(angle, -side * 10)
			-- le banc tourne le dos au sentier : on le fait regarder vers le sentier
			local cf = CFrame.lookAt(pos, Vector3.new(look.X, pos.Y, look.Z)) * CFrame.Angles(0, math.pi, 0)
			restSpot(dress, cf, style, rng)
			take(pos, 9)
			placed += 1
		end
	end
	-- 2) clôtures basses le long de quelques tronçons du sentier
	for i = 0, 11 do
		local a0 = i * 30 + 14 + rng:NextNumber(-4, 4)
		local span = rng:NextNumber(4, 7)
		local side = (i % 2 == 0) and 1 or -1
		local r = trailR + side * 5.5
		local p0 = Common.ground(Common.polar(a0, r))
		local p1 = Common.ground(Common.polar(a0 + span / 2, r))
		local p2 = Common.ground(Common.polar(a0 + span, r))
		if free(p0, 1) and free(p1, 1) and free(p2, 1) then
			Relief.fence(dress, p0, p1, style.fence or "bois", 3, wood)
			Relief.fence(dress, p1, p2, style.fence or "bois", 3, wood)
			take(p0, 3)
			take(p1, 3)
			take(p2, 3)
			placed += 1
		end
	end
	-- 3) amas de rochers avec fougères et fleurs
	Core.scatter(rng, 18, Vector3.zero, Layout.WalkwayOuter + 24, Layout.IslandRadius - 16, function(p)
		return free(p, 8)
	end, function(p)
		local g = Common.ground(p)
		local big = rng:NextNumber(5, 9)
		take(p, big * 1.4)
		Nature.rock(dress, g, big, { rng = rng, color = rock, moss = moss })
		for _ = 1, rng:NextInteger(1, 3) do
			local q = Common.ground(p + Common.polar(rng:NextNumber(0, 360), big * rng:NextNumber(0.6, 1)))
			Nature.rock(dress, q, big * rng:NextNumber(0.3, 0.55), { rng = rng, color = rock })
		end
		Nature.fern(dress, Common.ground(p + Common.polar(rng:NextNumber(0, 360), big * 0.8)), rng:NextNumber(2.5, 4), moss, rng)
		if style.flowers then
			for _ = 1, 3 do
				Nature.flower(
					dress,
					Common.ground(p + Common.polar(rng:NextNumber(0, 360), big * rng:NextNumber(0.8, 1.3))),
					style.flowers[rng:NextInteger(1, #style.flowers)],
					rng
				)
			end
		end
		placed += 1
	end)
	-- 4) massifs de fleurs dans l'herbe
	if style.flowers then
		Core.scatter(rng, 14, Vector3.zero, Layout.WalkwayOuter + 12, Layout.IslandRadius - 16, function(p)
			return free(p, 4)
		end, function(p)
			Nature.flowerBed(dress, Common.ground(p), rng:NextNumber(2.2, 3.6), style.flowers, rng, rng:NextInteger(6, 9))
			take(p, 4)
			placed += 1
		end)
	end
	-- 5) ruines
	if style.ruins ~= false then
		local count = 0
		for _, angle in { 52, 128, 232, 308, 18, 162 } do
			if count >= 4 then
				break
			end
			local pos = Common.ground(Common.polar(angle, 618))
			if free(pos, 12) then
				ruin(dress, CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), stone, moss, rng)
				take(pos, 13)
				count += 1
				placed += 1
			end
		end
	end
	-- 6) petits étals près de la promenade (entre les chemins, hors accès des lieux réservés)
	if style.stalls then
		local k = 0
		for i = 0, 5 do
			local angle = i * 60 + 15 + rng:NextNumber(-3, 3)
			local pos = Common.ground(Common.polar(angle, Layout.WalkwayOuter + 16))
			if free(pos, 4) then
				k += 1
				local spec = style.stalls[(k - 1) % #style.stalls + 1]
				local cf = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
				Props.stall(dress, cf, spec[1], spec[2], rng)
				Props.barrel(dress, cf * CFrame.new(5.6, 0, 1), 0.8)
				Props.crate(dress, cf * CFrame.new(-5.4, 0, 1.4) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), 2)
				take(pos, 9)
				placed += 1
			end
		end
	end
	dress:SetAttribute("Elements", placed)
	return free
end

return Common
