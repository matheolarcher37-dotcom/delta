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
local Hokage = require(script.Parent.Parent.Kit.Hokage)
local WorldBuilder = require(script.Parent.Parent.WorldBuilder)

local Common = {}

-- Semis de remplissage en attente (préparé par dressIsland, posé à la fin de forest).
Common.pendingFill = nil :: ((trees: { Vector3 }) -> ())?

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
	rimGroves: number?, -- bosquets de lisière (pourtour de l'île), par défaut 80 % de `groves`
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
	local function grove(center: Vector3)
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
			local ok = spec.free(p, 4) and not WorldBuilder.reserved(p, 4 + h * 0.4)
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
				-- détail complet le long de la promenade (vus de près), allégé entre les bases, version
				-- lointaine sur le pourtour de l'île (même silhouette et mêmes couleurs, 5 à 7 pièces) :
				-- on peut ainsi planter des forêts bien plus denses pour le même budget
				local r = Vector3.new(p.X, 0, p.Z).Magnitude
				local detail = r < Layout.WalkwayOuter + 32 and "normal" or (r < 535 and "low" or "far")
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
	end
	Core.scatter(rng, spec.groves, Vector3.zero, minR, maxR, function(p)
		return spec.free(p, 14)
	end, grove)
	-- lisière : bosquets supplémentaires sur le pourtour de l'île, en version lointaine (peu de
	-- pièces), pour que l'île paraisse boisée vue des bases et de haut
	Core.scatter(rng, spec.rimGroves or math.floor(spec.groves * 0.8), Vector3.zero, 552, Layout.IslandRadius - 14, function(p)
		return spec.free(p, 10)
	end, grove)
	-- semis de remplissage de l'habillage (Common.dressIsland), hors des bosquets
	local fill = Common.pendingFill
	if fill then
		Common.pendingFill = nil
		fill(taken)
	end
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
	tree: string?, -- essence des collines boisées (repères)
	treePalette: string?,
	hill: Color3?, -- herbe des collines
	arch: Color3?, -- couleur du grand portique (sinon la pierre)
	archCap: Color3?,
	fillSpacing: number?, -- écart du semis de remplissage (≈ 22 studs)
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

-- Grand rocher facetté posé au sol (repère visible de loin) : six faces de base, une couronne,
-- un sommet, un coussin de mousse et deux petits rochers au pied.
local function boulder(folder: Instance, base: Vector3, r: number, h: number, color: Color3, moss: Color3, rng: Random)
	local model = Core.slot(folder, "GrandRocher", CFrame.new(base), h)
	local ring, mid = {}, {}
	local a0 = rng:NextNumber(0, math.pi * 2)
	for k = 0, 5 do
		local a = a0 + k / 6 * math.pi * 2 + rng:NextNumber(-0.18, 0.18)
		local rr = r * rng:NextNumber(0.85, 1.12)
		ring[k + 1] = base + Vector3.new(math.cos(a) * rr, -1, math.sin(a) * rr)
		local am = a + math.pi / 6
		local rm = r * rng:NextNumber(0.55, 0.75)
		mid[k + 1] = base + Vector3.new(math.cos(am) * rm, h * rng:NextNumber(0.5, 0.7), math.sin(am) * rm)
	end
	local apex = base + Vector3.new(rng:NextNumber(-0.2, 0.2) * r, h, rng:NextNumber(-0.2, 0.2) * r)
	local center = base + Vector3.new(0, h * 0.35, 0)
	local function tri(a: Vector3, b: Vector3, c: Vector3)
		local n = (b - a):Cross(c - a)
		if n.Magnitude < 1e-6 then
			return
		end
		n = n.Unit
		if n:Dot((a + b + c) / 3 - center) < 0 then
			n = -n
		end
		Hokage.triangle(model, a, b, c, n, 3, Core.shade(color, rng:NextNumber(-0.05, 0.04)))
	end
	for k = 1, 6 do
		local k2 = k % 6 + 1
		tri(ring[k], ring[k2], mid[k])
		tri(ring[k2], mid[k2], mid[k])
		tri(mid[k], mid[k2], apex)
	end
	Core.ellipsoid(model, "Mousse", Vector3.new(r * 0.9, 2.2, r * 0.8), CFrame.new(apex + Vector3.new(0, -1.4, 0)), moss, Enum.Material.Grass).CastShadow = false
	for _ = 1, 2 do
		local a = rng:NextNumber(0, math.pi * 2)
		Nature.rock(model, Common.ground(base + Vector3.new(math.cos(a), 0, math.sin(a)) * r * 1.25), r * rng:NextNumber(0.25, 0.4), { rng = rng, color = color, moss = moss })
	end
	return model
end
Common.boulder = boulder

-- Grand portique (≈ 21 studs) : deux piliers, traverse, linteau débordant aux bouts relevés.
local function bigArch(folder: Instance, cf: CFrame, color: Color3, cap: Color3, stone: Color3)
	local model = Core.slot(folder, "GrandPortique", cf, 22)
	for _, sx in { -1, 1 } do
		Archi.block(model, "PortiqueSocle", Vector3.new(3.6, 1.6, 3.6), cf * CFrame.new(sx * 7.5, 0.8, 0), stone, Enum.Material.Slate)
		Build.part(model, "PortiquePilier", Vector3.new(2.4, 19.5, 2.4), cf * CFrame.new(sx * 7.5, 10.9, 0), color, { Material = Enum.Material.Wood })
	end
	Build.part(model, "PortiqueTraverse", Vector3.new(17, 1.4, 1.6), cf * CFrame.new(0, 16, 0), color, { Material = Enum.Material.Wood })
	Build.part(model, "PortiqueLinteau", Vector3.new(21, 1.6, 2.6), cf * CFrame.new(0, 19.6, 0), color, { Material = Enum.Material.Wood })
	Build.part(model, "PortiqueChapeau", Vector3.new(19, 1.1, 3.4), cf * CFrame.new(0, 20.9, 0), cap, { Material = Enum.Material.Wood })
	for _, sx in { -1, 1 } do
		Build.wedge(model, "PortiqueBout", Vector3.new(3.4, 1.4, 3.2), cf * CFrame.new(sx * 11, 21.1, 0) * CFrame.Angles(0, sx * math.pi / 2, 0), cap, {
			Material = Enum.Material.Wood,
		})
	end
	Build.part(model, "PortiquePlaque", Vector3.new(2.6, 3.2, 0.5), cf * CFrame.new(0, 17.8, -0.9), cap, { Material = Enum.Material.Wood })
	return model
end

-- Champ de fleurs (≈ 30 studs) : taches de couleur au ras du sol et fleurs dressées.
local function flowerField(folder: Instance, center: Vector3, radius: number, colors: { Color3 }, rng: Random)
	local model = Core.slot(folder, "ChampDeFleurs", CFrame.new(center), 2)
	for k = 1, 7 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * math.sqrt(rng:NextNumber()) * 0.75
		Core.flatDisc(model, "TacheFleurs", p, rng:NextNumber(7, 12), Common.ground(p).Y + 0.12 + k * 0.01, colors[(k - 1) % #colors + 1], Enum.Material.Grass)
	end
	for _ = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * math.sqrt(rng:NextNumber())
		Nature.flower(model, Common.ground(p), colors[rng:NextInteger(1, #colors)], rng)
	end
	return model
end

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

-- SEMIS DE REMPLISSAGE : de petits groupes peu coûteux (1 à 8 pièces) tous les ≈ 22 studs dans
-- l'herbe libre (hors chemins, bases, lieux réservés et leurs accès) : hautes touffes d'herbe,
-- grappes de 5 à 9 fleurs, cailloux, souches, petits buissons. Les grandes pelouses unies
-- disparaissent sans alourdir la carte. Renvoie le nombre de groupes posés.
local function fillGrass(folder: Instance, rng: Random, style: DressStyle, free: (Vector3, number) -> boolean, spacing: number, avoid: { Vector3 }?): number
	local fill = Build.folder(folder, "Semis")
	local grass = style.hill or Core.shade(style.moss or Color3.fromRGB(86, 126, 60), 0.06)
	local dark = Core.shade(grass, -0.16)
	local rock = style.rock or Color3.fromRGB(132, 126, 118)
	local flowers = style.flowers
	local leaf = Enum.Material.Grass
	local groups = 0
	local r0, r1 = Layout.WalkwayOuter + 10, Layout.IslandRadius - 8
	local function tuft(p: Vector3, h: number)
		local yaw = rng:NextNumber(0, math.pi * 2)
		for k = 0, 2 do
			local a = yaw + k * 2.1
			local hh = h * rng:NextNumber(0.75, 1.1)
			Build.wedge(
				fill,
				"Touffe",
				Vector3.new(0.5, hh, h * 0.4),
				CFrame.new(p + Vector3.new(0, hh / 2 - 0.1, 0)) * CFrame.Angles(0, a, 0) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.2, 0.2)),
				Core.shade(k == 1 and dark or grass, rng:NextNumber(-0.05, 0.05)),
				{ Material = leaf, CanCollide = false, CanQuery = false, CastShadow = false }
			)
		end
	end
	local x = -r1
	while x < r1 do
		local z = -r1
		while z < r1 do
			local p = Vector3.new(x + rng:NextNumber(-spacing, spacing) * 0.4, 0, z + rng:NextNumber(-spacing, spacing) * 0.4)
			local r = Vector3.new(p.X, 0, p.Z).Magnitude
			local open = r > r0 and r < r1 and free(p, 2) and not WorldBuilder.reserved(p, 3)
			if open and avoid then
				-- sous les arbres, le sous-bois de la forêt suffit
				for _, t in avoid do
					if math.abs(t.X - p.X) < 8 and math.abs(t.Z - p.Z) < 8 then
						open = false
						break
					end
				end
			end
			if open then
				local g = Common.ground(p)
				local roll = rng:NextNumber()
				local function patch(d: number)
					-- tache d'herbe d'une autre nuance (plus claire, plus sombre ou plus sèche)
					local tint = ({ 0.07, -0.07, 0.04 })[rng:NextInteger(1, 3)]
					local c = Core.shade(grass, tint)
					if tint == 0.04 then
						c = c:Lerp(Color3.fromRGB(176, 170, 96), 0.25)
					end
					Core.flatDisc(fill, "Tache", g, d, g.Y + 0.06 + rng:NextNumber(0, 0.04), c, leaf).CastShadow = false
				end
				if roll < 0.32 then
					-- tache d'herbe et haute touffe
					patch(rng:NextNumber(8, 15))
					tuft(g + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)), rng:NextNumber(2.6, 4.2))
				elseif roll < 0.5 and flowers then
					-- grappe de fleurs : un coussin de feuilles et 5 corolles
					local c = flowers[rng:NextInteger(1, #flowers)]
					Core.ellipsoid(fill, "Feuillage", Vector3.new(4.6, 1.2, 3.6), CFrame.new(g + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), dark, leaf).CastShadow =
						false
					for _ = 1, 5 do
						local q = g + Vector3.new(rng:NextNumber(-1.9, 1.9), rng:NextNumber(0.9, 1.4), rng:NextNumber(-1.5, 1.5))
						Core.ellipsoid(fill, "Corolle", Vector3.new(1.1, 0.42, 1.1), CFrame.new(q), Core.shade(c, rng:NextNumber(-0.06, 0.08)), Enum.Material.SmoothPlastic).CastShadow =
							false
					end
				elseif roll < 0.66 then
					-- cailloux (et parfois une tache d'herbe sèche autour)
					for k = 1, 2 do
						local sz = rng:NextNumber(1.3, 2.6) / k ^ 0.4
						Build.deco(
							fill,
							"Caillou",
							Vector3.new(sz * 1.3, sz * 0.7, sz),
							CFrame.new(g + Vector3.new(rng:NextNumber(-1.8, 1.8), sz * 0.2, rng:NextNumber(-1.8, 1.8)))
								* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)),
							Core.shade(rock, rng:NextNumber(-0.08, 0.06)),
							{ Material = Enum.Material.Slate }
						)
					end
					if rng:NextNumber() < 0.4 then
						patch(rng:NextNumber(7, 11))
					end
				elseif roll < 0.9 then
					-- petit buisson (deux boules de feuillage)
					local h = rng:NextNumber(2.6, 4)
					Core.ellipsoid(fill, "Buissonnet", Vector3.new(h * 1.6, h, h * 1.4), CFrame.new(g + Vector3.new(0, h * 0.35, 0)), Core.shade(grass, -0.1), leaf)
					Core.ellipsoid(fill, "Buissonnet", Vector3.new(h * 1.1, h * 0.8, h), CFrame.new(g + Vector3.new(h * 0.5, h * 0.55, h * 0.2)), Core.shade(grass, 0.0), leaf)
				elseif roll < 0.96 then
					-- grande tache d'herbe seule (casse la pelouse unie de loin)
					patch(rng:NextNumber(12, 20))
				else
					-- souche
					local d = rng:NextNumber(1.6, 2.6)
					Core.vcyl(fill, "Souche", CFrame.new(g - Vector3.new(0, 0.2, 0)), d * 0.6, d, Color3.fromRGB(104, 76, 52), Enum.Material.Wood)
					Core.vcyl(fill, "Souche", CFrame.new(g + Vector3.new(0, d * 0.6 - 0.18, 0)), 0.2, d * 0.82, Color3.fromRGB(196, 160, 112), Enum.Material.Wood)
				end
				groups += 1
			end
			z += spacing
		end
		x += spacing
	end
	fill:SetAttribute("Groupes", groups)
	return groups
end
Common.fillGrass = fillGrass

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
	-- 7) GRANDS REPÈRES, visibles de loin, dans les grandes étendues d'herbe (entre et derrière
	-- les bases) : grand rocher moussu, colline boisée, grand portique, champ de fleurs, étang
	local kinds = { "rocher", "colline", "portique", "fleurs", "etang", "colline", "rocher", "fleurs" }
	local hill = style.hill or Core.shade(moss, 0.1)
	local landmarks = 0
	for i = 0, 299 do
		if landmarks >= 14 then
			break
		end
		-- un repère par secteur de 30° autant que possible, puis au hasard
		local angle = (i < 120) and ((i % 12) * 30 + 15 + rng:NextNumber(-12, 12)) or rng:NextNumber(0, 360)
		local r = rng:NextNumber(430, 612)
		local pos = Common.ground(Common.polar(angle, r))
		local kind = kinds[landmarks % #kinds + 1]
		if kind == "fleurs" and not style.flowers then
			kind = "rocher"
		end
		local size = (kind == "colline" or kind == "fleurs") and 22 or 16
		if free(pos, size) then
			local face = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
			if kind == "rocher" then
				boulder(dress, pos, rng:NextNumber(13, 17), rng:NextNumber(12, 17), rock, moss, rng)
			elseif kind == "colline" then
				local model = Core.slot(dress, "CollineBoisee", face, 30)
				Core.ellipsoid(model, "Colline", Vector3.new(48, 15, 38), face * CFrame.new(0, -2.5, 0) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0), hill, Enum.Material.Grass)
				for k = 0, 2 do
					local q = (face * CFrame.new((k - 1) * 11 + rng:NextNumber(-2, 2), 0, rng:NextNumber(-6, 6))).Position
					local top = pos.Y + 4.6 - math.abs(k - 1) * 1.6
					Nature.tree(style.tree or "ArbreFeuillu", model, Vector3.new(q.X, top, q.Z), {
						rng = rng,
						height = rng:NextNumber(22, 32),
						palette = style.treePalette,
						detail = "low",
					})
				end
				Nature.rock(model, (face * CFrame.new(16, 0, 10)).Position, 5, { rng = rng, color = rock, moss = moss })
			elseif kind == "portique" then
				bigArch(dress, face, style.arch or stone, style.archCap or Core.shade(style.arch or stone, -0.35), Core.shade(stone, -0.1))
				Props.stoneLantern(dress, (face * CFrame.new(-12, 0, -4)).Position, 0.9, style.lanternGlow)
				Props.stoneLantern(dress, (face * CFrame.new(12, 0, -4)).Position, 0.9, style.lanternGlow)
				-- petit chemin de dalles qui traverse le portique, et des buissons à ses pieds : il ne
				-- flotte plus seul dans la prairie
				for k = -4, 4 do
					local q = Common.ground((face * CFrame.new(rng:NextNumber(-0.6, 0.6), 0, k * 4.2)).Position)
					Build.part(
						dress,
						"Dalle",
						Vector3.new(rng:NextNumber(3.4, 4.4), 0.5, rng:NextNumber(2.6, 3.4)),
						CFrame.new(q + Vector3.new(0, 0.15, 0)) * (face - face.Position) * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0),
						Core.shade(stone, rng:NextNumber(-0.1, 0.03)),
						{ Material = Enum.Material.Slate, CanCollide = false }
					)
				end
				for _, side in { -1, 1 } do
					Nature.bush(dress, Common.ground((face * CFrame.new(side * rng:NextNumber(10, 13), 0, rng:NextNumber(4, 8))).Position), {
						rng = rng,
						height = rng:NextNumber(3.5, 5),
						palette = style.treePalette,
						flowers = style.flowers and style.flowers[rng:NextInteger(1, #style.flowers)] or nil,
					})
				end
				Nature.rock(dress, Common.ground((face * CFrame.new(-15, 0, 6)).Position), 2.6, { rng = rng, color = rock, moss = moss })
			elseif kind == "fleurs" then
				flowerField(dress, pos, 15, style.flowers :: { Color3 }, rng)
			else
				Relief.pond(dress, pos, 10, { rng = rng }, Nature)
				for k = 0, 2 do
					local a = math.rad(angle) + k * 2.1
					Nature.rock(dress, Common.ground(pos + Vector3.new(math.cos(a), 0, math.sin(a)) * 15), rng:NextNumber(2.5, 4), { rng = rng, color = rock, moss = moss })
				end
			end
			take(pos, size + 4)
			landmarks += 1
			placed += 1
		end
	end
	dress:SetAttribute("Landmarks", landmarks)
	dress:SetAttribute("Elements", placed)
	-- 8) semis de remplissage dans l'herbe restée libre : posé par Common.forest, une fois les
	-- bosquets plantés (rien sous les arbres, déjà garnis de sous-bois)
	Common.pendingFill = function(trees: { Vector3 })
		dress:SetAttribute("Semis", fillGrass(dress, rng, style, free, style.fillSpacing or 22, trees))
	end
	return free
end

return Common
