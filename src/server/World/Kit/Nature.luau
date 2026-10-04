-- Kit/Nature : la végétation et les roches de la carte, façon « jeux phares » de Roblox.
--
-- ARBRES : tronc noueux effilé (segments + nœuds), racines évasées, vraies branches qui se
-- divisent, et un feuillage fait de NOMBREUX amas de boules (40 à 140 pièces) : cœur sombre,
-- dessus et pointes clairs, silhouette irrégulière. Essences : feuillu, arbre géant, sapin, cèdre
-- du Japon (sugi), cerisier, érable rouge, glycine, saule pleureur, palmier, bambous, arbre mort,
-- arbre rond (Planète des Guerriers).
-- Chaque essence est construite une fois par variante (modèle maître), puis clonée, tournée et
-- mise à l'échelle (voir Core.placeClone) : rapide à construire, rendu groupé par Roblox.
-- Chaque arbre est un emplacement remplaçable (DecorSlot) : un modèle de ServerStorage >
-- ModelesDeco portant le même nom (ex. "ArbreFeuillu") le remplace au lancement.
--
-- AUSSI : buissons, haies, fleurs, herbes hautes, fougères, roseaux, nénuphars, champignons,
-- souches et troncs couchés, rochers, falaises en strates, montagnes d'horizon.

local Build = require(script.Parent.Parent.Parent.Modules.Build)
local Core = require(script.Parent.Core)

local Nature = {}

local rgb = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local shade = Core.shade
local cylinder = Core.cylinder

local WOOD = Enum.Material.Wood
local LEAF = Enum.Material.Grass

-- Palettes de feuillage : { profond, sombre, moyen, clair, pointe }.
Nature.Palettes = {
	feuillu = { rgb(36, 70, 38), rgb(50, 94, 46), rgb(72, 124, 56), rgb(104, 154, 70), rgb(150, 188, 94) },
	foret = { rgb(28, 58, 36), rgb(40, 80, 46), rgb(58, 106, 56), rgb(86, 136, 68), rgb(126, 168, 86) },
	clair = { rgb(58, 100, 50), rgb(82, 132, 60), rgb(110, 160, 74), rgb(144, 186, 94), rgb(186, 212, 122) },
	sapin = { rgb(20, 50, 40), rgb(28, 68, 48), rgb(40, 88, 56), rgb(60, 112, 68), rgb(92, 140, 84) },
	cerisier = { rgb(170, 88, 120), rgb(206, 120, 152), rgb(232, 156, 184), rgb(248, 192, 212), rgb(255, 224, 234) },
	erable = { rgb(110, 30, 28), rgb(150, 44, 34), rgb(190, 70, 42), rgb(222, 112, 56), rgb(244, 168, 88) },
	automne = { rgb(122, 60, 26), rgb(166, 88, 34), rgb(204, 124, 44), rgb(230, 164, 66), rgb(246, 204, 110) },
	glycine = { rgb(88, 58, 146), rgb(120, 86, 186), rgb(156, 120, 220), rgb(192, 160, 242), rgb(226, 204, 255) },
	palmier = { rgb(40, 90, 42), rgb(58, 118, 50), rgb(82, 146, 60), rgb(116, 172, 76), rgb(158, 198, 98) },
	saule = { rgb(54, 92, 46), rgb(76, 120, 56), rgb(104, 148, 68), rgb(138, 174, 84), rgb(176, 200, 110) },
	maudit = { rgb(34, 34, 46), rgb(48, 46, 62), rgb(64, 60, 80), rgb(86, 80, 104), rgb(118, 108, 136) },
	guerrier = { rgb(26, 94, 88), rgb(40, 122, 110), rgb(62, 150, 130), rgb(94, 180, 150), rgb(138, 208, 176) },
	tropical = { rgb(30, 92, 50), rgb(44, 120, 58), rgb(66, 150, 70), rgb(100, 178, 84), rgb(146, 206, 104) },
	nuit = { rgb(22, 44, 40), rgb(32, 60, 50), rgb(44, 78, 60), rgb(62, 100, 72), rgb(90, 126, 90) },
	-- compatibilité avec l'ancien kit (4 tons : sombre, base, clair, reflet)
	vert = { rgb(50, 94, 46), rgb(72, 124, 56), rgb(104, 154, 70), rgb(150, 188, 94) },
	bambou = { rgb(70, 104, 46), rgb(96, 136, 58), rgb(128, 166, 74), rgb(164, 192, 96), rgb(200, 216, 128) },
}

local TRUNK = rgb(104, 76, 56)
local BARK_DARK = rgb(78, 58, 46)

-- Couleur interpolée dans une palette (t = 0 : profond/intérieur, t = 1 : pointe au soleil).
local function tone(pal: { Color3 }, t: number, rng: Random?): Color3
	local v = math.clamp(t + (rng and rng:NextNumber(-0.07, 0.07) or 0), 0, 1)
	local idx = v * (#pal - 1) + 1
	local i = math.floor(idx)
	if i >= #pal then
		return pal[#pal]
	end
	return pal[i]:Lerp(pal[i + 1], idx - i)
end
Nature.tone = tone

local function leaf(model: Instance, center: Vector3, diameter: number, color: Color3, material: Enum.Material?)
	local part = Core.ball(model, "Leaves", diameter, center, color, material or LEAF)
	return part
end

local function wood(model: Instance, name: string, a: Vector3, b: Vector3, d: number, color: Color3, collide: boolean?)
	return cylinder(model, name, a, b, d, color, { Material = WOOD, CanCollide = collide == true, CanQuery = collide == true })
end

local function knot(model: Instance, center: Vector3, d: number, color: Color3)
	return Core.ball(model, "Knot", d, center, color, WOOD)
end

-- Direction horizontale (angle en radians).
local function hdir(angle: number): Vector3
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

-- Direction inclinée de `tilt` radians par rapport à la verticale.
local function tilted(angle: number, tilt: number): Vector3
	return Vector3.new(math.cos(angle) * math.sin(tilt), math.cos(tilt), math.sin(angle) * math.sin(tilt))
end

------------------------------------------------------------------------
-- Éléments d'arbre
------------------------------------------------------------------------

-- Tronc effilé et un peu tordu. Renvoie la liste des points (du pied au sommet).
local function trunk(model: Instance, rng: Random, height: number, d0: number, d1: number, color: Color3, segments: number, wobble: number): { Vector3 }
	local lean = hdir(rng:NextNumber(0, math.pi * 2)) * height * rng:NextNumber(0.02, 0.08)
	local pts = { Vector3.new(0, -0.8, 0) }
	for i = 1, segments do
		local t = i / segments
		local jitter = i < segments and hdir(rng:NextNumber(0, math.pi * 2)) * height * wobble * rng:NextNumber(0.3, 1) or Vector3.zero
		table.insert(pts, Vector3.new(0, height * t, 0) + lean * (t ^ 1.5) + jitter)
	end
	for i = 1, segments do
		local d = d0 + (d1 - d0) * ((i - 1) / math.max(1, segments - 1))
		local c = shade(color, ((i % 2) - 0.5) * 0.06)
		wood(model, "Trunk", pts[i], pts[i + 1], d, c, i <= 2)
		if i < segments then
			knot(model, pts[i + 1], d * 0.98, c)
		end
	end
	return pts
end

-- Racines évasées qui plongent dans le sol.
local function roots(model: Instance, rng: Random, d0: number, count: number, color: Color3, reach: number?)
	local turn = rng:NextNumber(0, math.pi * 2)
	local k = reach or 1
	for i = 1, count do
		local dir = hdir(turn + i / count * math.pi * 2 + rng:NextNumber(-0.25, 0.25))
		local from = UP * d0 * rng:NextNumber(0.7, 1.1) + dir * d0 * 0.15
		local mid = dir * d0 * 0.72 * k + UP * d0 * 0.18
		local to = dir * d0 * rng:NextNumber(1.25, 1.7) * k - UP * 0.35
		local c = shade(color, -0.05)
		wood(model, "Root", from, mid, d0 * 0.44, c)
		wood(model, "Root", mid, to, d0 * 0.3, c)
	end
end

-- Amas de feuillage : un cœur sombre entouré de boules, plus claires vers le haut et vers
-- l'extérieur, et quelques petites pointes lumineuses sur le dessus.
local function cluster(model: Instance, rng: Random, center: Vector3, radius: number, pal: { Color3 }, count: number, outward: Vector3?, flat: number?)
	local f = flat or 1
	leaf(model, center - UP * radius * 0.22 * f, radius * 1.45, tone(pal, 0.1, rng))
	local turn = rng:NextNumber(0, math.pi * 2)
	for i = 1, count do
		local a = turn + i / count * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local y = rng:NextNumber(-0.35, 0.9)
		local h = math.sqrt(1 - y * y)
		local dir = Vector3.new(math.cos(a) * h, y * f, math.sin(a) * h)
		if outward then
			dir = (dir + outward * 0.35).Unit
		end
		local dist = radius * rng:NextNumber(0.5, 0.85)
		local size = radius * rng:NextNumber(0.72, 1.06) * (1 - 0.16 * y)
		local t = 0.36 + 0.4 * y + (outward and 0.14 * dir:Dot(outward) or 0)
		leaf(model, center + dir * dist, size, tone(pal, t, rng))
	end
	-- petits bourgeons en surface : silhouette détaillée et irrégulière, plus clairs au soleil
	local buds = math.max(2, count - 1)
	for i = 1, buds do
		local a = turn + 0.5 + i / buds * math.pi * 2 + rng:NextNumber(-0.5, 0.5)
		local y = rng:NextNumber(-0.1, 0.95)
		local h = math.sqrt(1 - y * y)
		local dir = Vector3.new(math.cos(a) * h, y * f, math.sin(a) * h)
		if outward then
			dir = (dir + outward * 0.3).Unit
		end
		local t = 0.55 + 0.4 * y + (outward and 0.1 * dir:Dot(outward) or 0)
		leaf(model, center + dir * radius * rng:NextNumber(0.88, 1.05), radius * rng:NextNumber(0.34, 0.48), tone(pal, t, rng))
	end
	for _ = 1, 2 do
		local a = rng:NextNumber(0, math.pi * 2)
		local pos = center + hdir(a) * radius * rng:NextNumber(0.1, 0.4) + UP * radius * 0.78 * f
		leaf(model, pos, radius * rng:NextNumber(0.4, 0.55), tone(pal, rng:NextNumber(0.84, 1), rng))
	end
end
Nature.cluster = cluster

-- Branche en deux tronçons (légèrement courbée) ; renvoie le milieu et le bout.
local function limb(model: Instance, from: Vector3, dir: Vector3, length: number, d: number, color: Color3, curve: number): (Vector3, Vector3)
	local mid = from + dir * length * 0.55
	local dir2 = (dir + UP * curve).Unit
	local tip = mid + dir2 * length * 0.45
	wood(model, "Branch", from, mid, d, color)
	knot(model, mid, d * 0.92, color)
	wood(model, "Branch", mid, tip, d * 0.7, color)
	return mid, tip
end

------------------------------------------------------------------------
-- Construction des essences (dans le repère du modèle maître : pied en (0, 0, 0))
------------------------------------------------------------------------

export type Detail = "hero" | "normal" | "low"

local PUFFS = { hero = 6, normal = 5, low = 3 }

-- Feuillu (chêne / hêtre stylisé). H = 30.
local function buildBroadleaf(model: Model, rng: Random, pal: { Color3 }, detail: Detail, trunkColor: Color3)
	local H = 30
	local d0 = H * 0.09
	local pts = trunk(model, rng, H * 0.4, d0, d0 * 0.58, trunkColor, detail == "low" and 3 or 4, 0.03)
	if detail ~= "low" then
		roots(model, rng, d0, 5, trunkColor)
		if rng:NextNumber() < 0.6 then
			knot(model, pts[2] + hdir(rng:NextNumber(0, 6.28)) * d0 * 0.45 + UP * H * 0.05, d0 * 0.5, shade(trunkColor, -0.08))
		end
	end
	local top = pts[#pts]
	local limbs = detail == "low" and 3 or rng:NextInteger(4, 5)
	local turn = rng:NextNumber(0, math.pi * 2)
	local puffs = PUFFS[detail]
	local tips = {}
	-- deux silhouettes selon la variante : couronne ronde (chêne) ou étalée (parasol)
	local round = rng:NextNumber() < 0.55
	local tiltMin, tiltMax = 0.8, 1.12
	if round then
		tiltMin, tiltMax = 0.55, 0.9
	end
	for i = 1, limbs do
		local a = turn + i / limbs * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local t = rng:NextNumber(0.55, 1)
		local start = pts[#pts - 1]:Lerp(top, t)
		local dir = tilted(a, rng:NextNumber(tiltMin, tiltMax))
		local length = H * rng:NextNumber(0.25, 0.32)
		local mid, tip = limb(model, start, dir, length, d0 * 0.45, trunkColor, 0.5)
		table.insert(tips, { tip, hdir(a) })
		if detail ~= "low" and rng:NextNumber() < (detail == "hero" and 0.9 or 0.6) then
			local side = rng:NextNumber() < 0.5 and -1 or 1
			local subDir = tilted(a + side * rng:NextNumber(0.5, 0.8), rng:NextNumber(0.6, 1.0))
			local subTip = mid + subDir * length * 0.48
			wood(model, "Branch", mid, subTip, d0 * 0.26, trunkColor)
			table.insert(tips, { subTip, hdir(a + side * 0.6) })
		end
	end
	for _, entry in tips do
		cluster(model, rng, entry[1] + UP * H * 0.04, H * rng:NextNumber(0.14, 0.17), pal, puffs, entry[2], 0.85)
	end
	if round then
		cluster(model, rng, top + UP * H * 0.27, H * 0.23, pal, puffs + 2, nil, 1)
	else
		cluster(model, rng, top + UP * H * 0.2, H * 0.19, pal, puffs + 1, nil, 0.9)
	end
end

-- Arbre géant (forêt du Village Ninja) : tronc énorme à contreforts, longues branches presque
-- horizontales chargées de grappes à plusieurs étages. H = 70.
local function buildGiant(model: Model, rng: Random, pal: { Color3 }, detail: Detail, trunkColor: Color3)
	local H = 70
	local d0 = H * 0.085
	local pts = trunk(model, rng, H * 0.6, d0, d0 * 0.55, trunkColor, 4, 0.02)
	roots(model, rng, d0, detail == "low" and 4 or 6, trunkColor, 1.25)
	-- lianes et bosses sur le tronc
	if detail ~= "low" then
		for _ = 1, 2 do
			knot(model, pts[2]:Lerp(pts[3], rng:NextNumber()) + hdir(rng:NextNumber(0, 6.28)) * d0 * 0.42, d0 * 0.45, shade(trunkColor, -0.1))
		end
	end
	local top = pts[#pts]
	local count = detail == "low" and 4 or 6
	local turn = rng:NextNumber(0, math.pi * 2)
	local puffs = PUFFS[detail]
	for i = 1, count do
		local a = turn + i / count * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local t = 0.45 + (i % 3) * 0.2 + rng:NextNumber(0, 0.08)
		local seg = math.clamp(math.floor(t * 4) + 1, 2, #pts - 1)
		local start = pts[seg]:Lerp(pts[seg + 1], rng:NextNumber())
		local dir = tilted(a, rng:NextNumber(0.95, 1.25))
		local length = H * rng:NextNumber(0.22, 0.3)
		local mid, tip = limb(model, start, dir, length, d0 * 0.42, trunkColor, 0.45)
		cluster(model, rng, tip + UP * H * 0.03, H * rng:NextNumber(0.1, 0.125), pal, puffs, hdir(a), 0.8)
		if detail ~= "low" then
			local subDir = tilted(a + rng:NextNumber(-0.9, 0.9), rng:NextNumber(0.5, 0.8))
			local subTip = mid + subDir * length * 0.42
			wood(model, "Branch", mid, subTip, d0 * 0.22, trunkColor)
			cluster(model, rng, subTip + UP * H * 0.02, H * rng:NextNumber(0.08, 0.1), pal, puffs - 1, hdir(a), 0.8)
		end
	end
	cluster(model, rng, top + UP * H * 0.09, H * 0.15, pal, puffs + 2, nil, 0.85)
	for _ = 1, 2 do
		local a = rng:NextNumber(0, math.pi * 2)
		cluster(model, rng, top + hdir(a) * H * 0.12 + UP * H * 0.04, H * 0.1, pal, puffs - 1, hdir(a), 0.8)
	end
end

-- Conifère en étages de boules (sapin) ; `narrow` = cèdre du Japon élancé. H = 30.
local function buildConifer(model: Model, rng: Random, pal: { Color3 }, detail: Detail, trunkColor: Color3, narrow: boolean)
	local H = 30
	local d0 = H * (narrow and 0.05 or 0.06)
	wood(model, "Trunk", Vector3.new(0, -0.6, 0), Vector3.new(0, H * 0.55, 0), d0, trunkColor, true)
	if detail ~= "low" then
		roots(model, rng, d0, 4, trunkColor)
	end
	local tiers = narrow and (detail == "low" and 6 or 9) or (detail == "low" and 5 or 7)
	local base = narrow and 0.26 or 0.16
	local r0 = H * (narrow and 0.17 or 0.26)
	for i = 0, tiers - 1 do
		local t = i / (tiers - 1)
		local y = H * (base + t * (0.9 - base))
		local r = r0 * (1 - t * 0.82) + 0.4
		local center = Vector3.new(rng:NextNumber(-0.2, 0.2), y, rng:NextNumber(-0.2, 0.2))
		leaf(model, center + UP * r * 0.1, r * 0.95, tone(pal, 0.08 + t * 0.2, rng))
		-- rameaux : ellipsoïdes allongés vers l'extérieur et inclinés vers le bas (jupe)
		local k = math.max(4, math.floor((narrow and 6 or 8) - t * 3 + 0.5))
		local turn = rng:NextNumber(0, math.pi * 2)
		for j = 1, k do
			local a = turn + j / k * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
			local out = hdir(a)
			local len = r * rng:NextNumber(1.05, 1.3)
			local pos = center + out * len * 0.45 - UP * r * 0.18
			local cf = CFrame.lookAt(pos, pos + out) * CFrame.Angles(math.rad(-rng:NextNumber(14, 26)), 0, 0)
			Core.ellipsoid(model, "Leaves", Vector3.new(r * 0.62, r * 0.42, len), cf, tone(pal, 0.3 + t * 0.4 + rng:NextNumber(0, 0.2), rng), LEAF)
		end
	end
	leaf(model, Vector3.new(0, H * 0.96, 0), r0 * 0.3, tone(pal, 0.95, rng))
end

-- Cerisier : tronc court et noueux, longues branches presque horizontales, nuages roses aplatis.
-- H = 22.
local function buildCherry(model: Model, rng: Random, pal: { Color3 }, detail: Detail, trunkColor: Color3)
	local H = 22
	local d0 = H * 0.085
	local pts = trunk(model, rng, H * 0.34, d0, d0 * 0.7, trunkColor, 3, 0.05)
	if detail ~= "low" then
		roots(model, rng, d0, 4, trunkColor)
	end
	local top = pts[#pts]
	local count = detail == "low" and 3 or 4
	local turn = rng:NextNumber(0, math.pi * 2)
	local puffs = PUFFS[detail]
	for i = 1, count do
		local a = turn + i / count * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local dir = tilted(a, rng:NextNumber(0.9, 1.2))
		local length = H * rng:NextNumber(0.3, 0.38)
		local mid, tip = limb(model, top, dir, length, d0 * 0.5, trunkColor, 0.3)
		cluster(model, rng, tip + UP * H * 0.06, H * rng:NextNumber(0.15, 0.18), pal, puffs, hdir(a), 0.7)
		if detail == "hero" or (detail == "normal" and i % 2 == 0) then
			local subTip = mid + tilted(a + rng:NextNumber(-0.8, 0.8), 0.7) * length * 0.4
			wood(model, "Branch", mid, subTip, d0 * 0.26, trunkColor)
			cluster(model, rng, subTip + UP * H * 0.05, H * 0.13, pal, puffs - 1, hdir(a), 0.7)
		end
	end
	cluster(model, rng, top + UP * H * 0.2, H * 0.2, pal, puffs + 1, nil, 0.72)
	-- pétales tombés au pied de l'arbre
	if detail ~= "low" then
		for _ = 1, 5 do
			local pos = hdir(rng:NextNumber(0, 6.28)) * rng:NextNumber(2, H * 0.45) + UP * 0.06
			Build.deco(model, "Petal", Vector3.new(0.9, 0.06, 0.6), CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), pal[4], { CastShadow = false })
		end
	end
end

-- Érable du Japon : silhouette basse et large, plateaux de feuillage étagés. H = 16.
local function buildMaple(model: Model, rng: Random, pal: { Color3 }, detail: Detail, trunkColor: Color3)
	local H = 16
	local d0 = H * 0.075
	local pts = trunk(model, rng, H * 0.3, d0, d0 * 0.7, trunkColor, 3, 0.06)
	local top = pts[#pts]
	local count = detail == "low" and 3 or 5
	local turn = rng:NextNumber(0, math.pi * 2)
	for i = 1, count do
		local a = turn + i / count * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local dir = tilted(a, rng:NextNumber(0.75, 1.1))
		local length = H * rng:NextNumber(0.3, 0.42)
		local _, tip = limb(model, top, dir, length, d0 * 0.45, trunkColor, 0.4)
		cluster(model, rng, tip + UP * H * 0.04, H * rng:NextNumber(0.13, 0.17), pal, PUFFS[detail] - 1, hdir(a), 0.55)
	end
	cluster(model, rng, top + UP * H * 0.3, H * 0.19, pal, PUFFS[detail], nil, 0.6)
end

-- Glycine : tronc tordu, ombrelle verte et mauve, grappes de fleurs pendantes (certaines
-- lumineuses). H = 20.
local function buildWisteria(model: Model, rng: Random, pal: { Color3 }, detail: Detail, trunkColor: Color3)
	local H = 20
	local d0 = H * 0.08
	local pts = trunk(model, rng, H * 0.5, d0, d0 * 0.6, trunkColor, 4, 0.05)
	if detail ~= "low" then
		roots(model, rng, d0, 4, trunkColor)
	end
	local top = pts[#pts]
	local mixed = { Nature.Palettes.saule[2], pal[1], pal[2], pal[3], pal[5] }
	local count = detail == "low" and 3 or 5
	local turn = rng:NextNumber(0, math.pi * 2)
	local anchors = {}
	for i = 1, count do
		local a = turn + i / count * math.pi * 2
		local _, tip = limb(model, top, tilted(a, 1.0), H * 0.3, d0 * 0.42, trunkColor, 0.25)
		cluster(model, rng, tip + UP * H * 0.04, H * 0.15, mixed, PUFFS[detail] - 1, hdir(a), 0.55)
		table.insert(anchors, tip)
	end
	cluster(model, rng, top + UP * H * 0.12, H * 0.2, mixed, PUFFS[detail], nil, 0.55)
	local racemes = detail == "low" and 8 or (detail == "hero" and 22 or 16)
	for _ = 1, racemes do
		local anchor = anchors[rng:NextInteger(1, #anchors)]
		local from = anchor + hdir(rng:NextNumber(0, 6.28)) * H * rng:NextNumber(0.02, 0.16) - UP * H * 0.02
		local length = H * rng:NextNumber(0.14, 0.26)
		local glow = rng:NextNumber() < 0.22
		local material = glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
		Core.ellipsoid(model, "Bloom", Vector3.new(H * 0.05, length, H * 0.05), CFrame.new(from - UP * length * 0.45), tone(pal, rng:NextNumber(0.35, 0.7), rng), material)
		Core.ellipsoid(model, "Bloom", Vector3.new(H * 0.032, length * 0.45, H * 0.032), CFrame.new(from - UP * length * 0.95), tone(pal, rng:NextNumber(0.7, 1), rng), material)
	end
end

-- Saule pleureur (bord de l'étang) : rideaux de feuillage qui tombent jusqu'au sol. H = 22.
local function buildWillow(model: Model, rng: Random, pal: { Color3 }, detail: Detail, trunkColor: Color3)
	local H = 22
	local d0 = H * 0.085
	local pts = trunk(model, rng, H * 0.48, d0, d0 * 0.65, trunkColor, 3, 0.05)
	roots(model, rng, d0, detail == "low" and 3 or 5, trunkColor)
	local top = pts[#pts]
	local turn = rng:NextNumber(0, math.pi * 2)
	local count = detail == "low" and 3 or 4
	for i = 1, count do
		local a = turn + i / count * math.pi * 2
		local _, tip = limb(model, top, tilted(a, 0.8), H * 0.26, d0 * 0.42, trunkColor, 0.2)
		cluster(model, rng, tip + UP * H * 0.03, H * 0.14, pal, PUFFS[detail] - 1, hdir(a), 0.75)
	end
	cluster(model, rng, top + UP * H * 0.12, H * 0.19, pal, PUFFS[detail], nil, 0.8)
	local strands = detail == "low" and 14 or 30
	for i = 1, strands do
		local a = turn + i / strands * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local r = H * rng:NextNumber(0.3, 0.42)
		local length = H * rng:NextNumber(0.45, 0.62)
		local topY = top.Y + H * rng:NextNumber(0.02, 0.12)
		local pos = Vector3.new(math.cos(a) * r, topY - length / 2, math.sin(a) * r)
		Core.ellipsoid(model, "Leaves", Vector3.new(H * 0.045, length, H * 0.022), CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)), tone(pal, rng:NextNumber(0.4, 0.95), rng), LEAF)
	end
end

-- Palmier : tronc courbé annelé, deux couronnes de palmes arquées, noix de coco. H = 24.
local function buildPalm(model: Model, rng: Random, pal: { Color3 }, detail: Detail, _trunkColor: Color3)
	local H = 24
	local segments = detail == "low" and 5 or 8
	local bend = rng:NextNumber(0.25, 0.55)
	local p = Vector3.new(0, -0.6, 0)
	local dir = UP
	local side = hdir(rng:NextNumber(0, 6.28))
	for i = 1, segments do
		local nextDir = (dir + side * bend * 0.18).Unit
		local q = p + nextDir * (H * 0.86 / segments)
		local d = H * (0.075 - i * 0.003)
		local color = (i % 2 == 0) and rgb(156, 120, 82) or rgb(132, 100, 70)
		wood(model, "Trunk", p, q + nextDir * 0.2, d, color, i <= 2)
		if detail ~= "low" then
			Core.ball(model, "TrunkRing", d * 1.1, q, rgb(108, 82, 58), WOOD)
		end
		p, dir = q, nextDir
	end
	local fronds = detail == "low" and 7 or 11
	for i = 1, fronds do
		local a = i / fronds * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local out = hdir(a)
		local upper = i % 2 == 0
		local lift = upper and rng:NextNumber(0.06, 0.12) or rng:NextNumber(0.0, 0.05)
		local reach = upper and 0.34 or 0.4
		local points = {
			p,
			p + out * H * reach * 0.35 + UP * H * (0.06 + lift),
			p + out * H * reach * 0.7 + UP * H * lift * 0.6,
			p + out * H * reach - UP * H * (upper and 0.05 or 0.11),
		}
		for k = 1, 3 do
			local a0, b0 = points[k], points[k + 1]
			local length = (b0 - a0).Magnitude
			local width = H * (0.11 - k * 0.022)
			local c = tone(pal, (upper and 0.55 or 0.35) + k * 0.1, rng)
			Core.ellipsoid(model, "Leaves", Vector3.new(width, H * 0.012, length * 1.25), CFrame.lookAt((a0 + b0) / 2, b0), c, LEAF)
		end
	end
	leaf(model, p, H * 0.08, pal[1])
	if detail ~= "low" then
		for i = 1, 3 do
			Core.ball(model, "Coconut", H * 0.05, p + Vector3.new(math.cos(i * 2.1) * H * 0.035, -H * 0.04, math.sin(i * 2.1) * H * 0.035), rgb(96, 70, 44))
		end
	end
end

-- Touffe de bambous : tiges annelées de hauteurs variées et petits bouquets de feuilles. H = 30.
local function buildBamboo(model: Model, rng: Random, pal: { Color3 }, detail: Detail, _trunkColor: Color3)
	local H = 30
	local stalks = detail == "low" and 5 or (detail == "hero" and 10 or 8)
	for i = 1, stalks do
		local base = hdir(rng:NextNumber(0, 6.28)) * rng:NextNumber(0, 3.2)
		local h = H * rng:NextNumber(0.7, 1)
		local lean = hdir(rng:NextNumber(0, 6.28)) * h * rng:NextNumber(0.03, 0.1) + base * 0.25
		local top = base + UP * h + lean
		local d = rng:NextNumber(0.55, 0.85)
		local stalk = tone(pal, rng:NextNumber(0.35, 0.7), rng)
		wood(model, "Stalk", base - UP * 0.4, top, d, stalk, i <= 3).Material = Enum.Material.SmoothPlastic
		local nodes = detail == "low" and 2 or 3
		for k = 1, nodes do
			local q = base:Lerp(top, k / (nodes + 1))
			local node = cylinder(model, "Node", q - (top - base).Unit * 0.12, q + (top - base).Unit * 0.12, d * 1.18, shade(stalk, -0.15), { Material = Enum.Material.SmoothPlastic, CanCollide = false })
			node.CanQuery = false
		end
		local leaves = detail == "low" and 1 or 2
		for k = 1, leaves do
			local q = base:Lerp(top, 0.75 + k * 0.1)
			local a = rng:NextNumber(0, 6.28)
			local pos = q + hdir(a) * 1.6
			Core.ellipsoid(model, "Leaves", Vector3.new(0.5, 1.4, 4.2), CFrame.lookAt(pos, q) * CFrame.Angles(rng:NextNumber(-0.4, 0.2), 0, 0), tone(pal, rng:NextNumber(0.5, 1), rng), LEAF)
		end
		for k = 1, 3 do
			local a = rng:NextNumber(0, 6.28) + k * 2.1
			local pos = top + hdir(a) * 1.5 - UP * 0.4
			Core.ellipsoid(model, "Leaves", Vector3.new(0.6, 0.25, 4.4), CFrame.lookAt(pos, top + UP * 0.5) * CFrame.Angles(rng:NextNumber(0.1, 0.4), 0, 0), tone(pal, rng:NextNumber(0.55, 1), rng), LEAF)
		end
	end
end

-- Arbre mort tordu (cimetière, Académie Occulte). H = 20.
local function buildDead(model: Model, rng: Random, _pal: { Color3 }, detail: Detail, trunkColor: Color3)
	local H = 20
	local d0 = H * 0.07
	local pts = trunk(model, rng, H * 0.55, d0, d0 * 0.5, trunkColor, 4, 0.06)
	roots(model, rng, d0, 4, trunkColor)
	local count = detail == "low" and 3 or 5
	local turn = rng:NextNumber(0, math.pi * 2)
	for i = 1, count do
		local a = turn + i / count * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local start = pts[math.clamp(#pts - (i % 3), 2, #pts)]
		local dir = tilted(a, rng:NextNumber(0.6, 1.1))
		local mid, tip = limb(model, start, dir, H * rng:NextNumber(0.25, 0.35), d0 * 0.35, trunkColor, rng:NextNumber(-0.2, 0.5))
		for _ = 1, detail == "low" and 1 or 2 do
			local twig = tip + tilted(a + rng:NextNumber(-1, 1), rng:NextNumber(0.3, 1.2)) * H * rng:NextNumber(0.08, 0.14)
			wood(model, "Branch", tip, twig, d0 * 0.14, trunkColor)
		end
		local spur = mid + tilted(a + rng:NextNumber(-1.2, 1.2), 0.6) * H * 0.1
		wood(model, "Branch", mid, spur, d0 * 0.16, trunkColor)
	end
end

-- Arbre rond style « Planète des Guerriers » : tronc fin courbé et grosse boule de feuillage. H = 18.
local function buildOrbTree(model: Model, rng: Random, pal: { Color3 }, detail: Detail, trunkColor: Color3)
	local H = 18
	local d0 = H * 0.06
	local pts = trunk(model, rng, H * 0.58, d0, d0 * 0.7, trunkColor, 3, 0.04)
	local top = pts[#pts] + UP * H * 0.14
	local r = H * 0.22
	leaf(model, top, r * 2, tone(pal, 0.35, rng))
	local n = detail == "low" and 6 or 11
	for i = 1, n do
		local y = -0.5 + (i / n) * 1.3
		local a = i * 2.4
		local h = math.sqrt(math.max(0, 1 - math.min(1, y * y)))
		local pos = top + Vector3.new(math.cos(a) * h, y, math.sin(a) * h) * r * 0.75
		leaf(model, pos, r * rng:NextNumber(0.7, 0.95), tone(pal, 0.35 + y * 0.45, rng))
	end
end

local SPECIES = {
	ArbreFeuillu = { build = buildBroadleaf, height = 30, palette = "feuillu", trunk = TRUNK },
	ArbreGeant = { build = buildGiant, height = 70, palette = "foret", trunk = rgb(112, 82, 62) },
	Sapin = { build = buildConifer, height = 30, palette = "sapin", trunk = BARK_DARK },
	Cedre = { build = buildConifer, height = 30, palette = "sapin", trunk = rgb(96, 60, 44), narrow = true },
	Cerisier = { build = buildCherry, height = 22, palette = "cerisier", trunk = rgb(78, 54, 50) },
	Erable = { build = buildMaple, height = 16, palette = "erable", trunk = rgb(72, 54, 46) },
	Glycine = { build = buildWisteria, height = 20, palette = "glycine", trunk = rgb(86, 64, 54) },
	Saule = { build = buildWillow, height = 22, palette = "saule", trunk = rgb(96, 80, 62) },
	Palmier = { build = buildPalm, height = 24, palette = "palmier", trunk = TRUNK },
	Bambou = { build = buildBamboo, height = 30, palette = "bambou", trunk = TRUNK },
	ArbreMort = { build = buildDead, height = 20, palette = "maudit", trunk = rgb(70, 62, 64) },
	ArbreRond = { build = buildOrbTree, height = 18, palette = "guerrier", trunk = rgb(150, 116, 84) },
}
Nature.Species = SPECIES

local VARIANTS = 4

local function paletteOf(value: any, fallback: string): ({ Color3 }, string)
	if typeof(value) == "table" then
		return value, tostring(value)
	end
	local name = value or fallback
	return Nature.Palettes[name] or Nature.Palettes[fallback], name
end

export type TreeOptions = {
	height: number?,
	palette: any?,
	trunk: Color3?,
	rng: Random?,
	slot: string?,
	detail: Detail?,
	variant: number?,
}

-- Plante un arbre de l'essence `species` (voir SPECIES) au pied `base` (Vector3 ou CFrame).
function Nature.tree(species: string, parent: Instance, base: Vector3 | CFrame, options: TreeOptions?): Model
	local o = options or {}
	local spec = SPECIES[species] or SPECIES.ArbreFeuillu
	local rng = o.rng or Random.new()
	local pal, palName = paletteOf(o.palette, spec.palette)
	local detail: Detail = o.detail or "normal"
	local variant = o.variant or rng:NextInteger(1, VARIANTS)
	local trunkColor = o.trunk or spec.trunk
	local slotName = o.slot or species
	local key = table.concat({ species, palName, detail, tostring(variant), trunkColor:ToHex() }, "|")
	local master = Core.master(key, function()
		local model = Instance.new("Model")
		model.Name = slotName
		model:SetAttribute("Slot", slotName)
		model:SetAttribute("TargetHeight", spec.height)
		local mrng = Random.new(variant * 7919 + #species * 131 + #palName)
		spec.build(model, mrng, pal, detail, trunkColor, spec.narrow == true)
		return model
	end)
	local cf = Core.asCFrame(base, rng)
	local h = o.height or spec.height
	local model = Core.placeClone(master, parent, cf, h / spec.height, rng:NextNumber(-0.05, 0.05))
	model.Name = slotName
	model:SetAttribute("Slot", slotName)
	return model
end

-- Raccourcis (compatibles avec l'ancien kit).
function Nature.roundTree(parent: Instance, base: Vector3 | CFrame, options: TreeOptions?): Model
	local o = table.clone(options or {})
	o.slot = o.slot or "ArbreFeuillu"
	return Nature.tree("ArbreFeuillu", parent, base, o)
end
function Nature.giantTree(parent: Instance, base: Vector3 | CFrame, options: TreeOptions?): Model
	return Nature.tree("ArbreGeant", parent, base, options)
end
function Nature.pine(parent: Instance, base: Vector3 | CFrame, options: TreeOptions?): Model
	return Nature.tree("Sapin", parent, base, options)
end
function Nature.cherryTree(parent: Instance, base: Vector3 | CFrame, options: TreeOptions?): Model
	return Nature.tree("Cerisier", parent, base, options)
end
function Nature.wisteriaTree(parent: Instance, base: Vector3 | CFrame, options: TreeOptions?): Model
	return Nature.tree("Glycine", parent, base, options)
end
function Nature.palmTree(parent: Instance, base: Vector3 | CFrame, options: TreeOptions?): Model
	return Nature.tree("Palmier", parent, base, options)
end

------------------------------------------------------------------------
-- Buissons, haies
------------------------------------------------------------------------

-- Buisson arrondi (5 à 9 boules dégradées), fleuri si `flowers` (couleur des fleurs).
function Nature.bush(parent: Instance, base: Vector3 | CFrame, options: { height: number?, palette: any?, rng: Random?, slot: string?, flowers: Color3? }?): Model
	local o = options or {}
	local rng = o.rng or Random.new()
	local h = o.height or 4
	local pal = paletteOf(o.palette, "feuillu")
	local cf = Core.asCFrame(base, rng)
	local model = Core.slot(parent, o.slot or "Buisson", cf, h)
	local p0 = cf.Position
	leaf(model, p0 + UP * h * 0.35, h * 1.3, tone(pal, 0.2, rng))
	local count = rng:NextInteger(5, 8)
	local turn = rng:NextNumber(0, math.pi * 2)
	for i = 1, count do
		local a = turn + i / count * math.pi * 2
		local y = rng:NextNumber(0.2, 0.7)
		local pos = p0 + hdir(a) * h * rng:NextNumber(0.4, 0.6) + UP * h * y
		leaf(model, pos, h * rng:NextNumber(0.65, 0.9), tone(pal, 0.3 + y * 0.6, rng))
	end
	leaf(model, p0 + UP * h * 0.82, h * 0.6, tone(pal, 0.9, rng))
	if o.flowers then
		for _ = 1, 6 do
			local a = rng:NextNumber(0, math.pi * 2)
			local y = rng:NextNumber(0.4, 0.9)
			local pos = p0 + hdir(a) * h * 0.62 * math.sqrt(1 - (y - 0.4) * 0.8) + UP * h * y
			Core.ball(model, "Flower", h * rng:NextNumber(0.14, 0.2), pos, shade(o.flowers, rng:NextNumber(-0.08, 0.12)))
		end
	end
	return model
end

-- Haie taillée de `a` à `b` : socle feuillu et dessus arrondi (boules).
function Nature.hedge(parent: Instance, a: Vector3, b: Vector3, options: { height: number?, width: number?, palette: any?, rng: Random? }?): Model
	local o = options or {}
	local rng = o.rng or Random.new()
	local h = o.height or 3.6
	local w = o.width or 2.8
	local pal = paletteOf(o.palette, "feuillu")
	local model = Instance.new("Model")
	model.Name = "Haie"
	model.Parent = parent
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local length = flat.Magnitude
	if length < 0.5 then
		return model
	end
	local mid = (a + b) / 2
	Build.part(model, "HedgeBody", Vector3.new(w, h * 0.7, length), CFrame.lookAt(mid + UP * h * 0.35, mid + UP * h * 0.35 + flat), tone(pal, 0.3, rng), { Material = LEAF })
	local count = math.max(2, math.floor(length / (w * 0.9)))
	for i = 0, count do
		local p = a:Lerp(b, i / count) + UP * h * 0.72
		leaf(model, p + Vector3.new(rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.1, 0.15), rng:NextNumber(-0.2, 0.2)), w * rng:NextNumber(1.05, 1.2), tone(pal, rng:NextNumber(0.45, 0.8), rng))
	end
	return model
end

------------------------------------------------------------------------
-- Détails du sol
------------------------------------------------------------------------

-- Touffe d'herbe : 4 brins pointus (coins) en éventail. Avec `role`, les brins suivent la couleur
-- d'herbe de l'univers.
function Nature.tuft(parent: Instance, base: Vector3, height: number, color: Color3, rng: Random, role: string?)
	local yaw = rng:NextNumber(0, math.pi * 2)
	for i = 1, 4 do
		local h = height * rng:NextNumber(0.6, 1.1)
		local angle = yaw + i * 1.6
		local cf = CFrame.new(base) * CFrame.Angles(0, angle, 0) * CFrame.Angles(rng:NextNumber(0.12, 0.42), 0, 0) * CFrame.new(0, h / 2, 0)
		local nuance = rng:NextNumber(-0.12, 0.1)
		local blade = Build.wedge(parent, "Grass", Vector3.new(0.18, h, height * 0.42), cf, shade(color, nuance), {
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		if role then
			Core.solRole(blade, role, nuance)
		end
	end
end

-- Herbes hautes : longs brins souples et quelques épis.
function Nature.tallGrass(parent: Instance, base: Vector3, height: number, color: Color3, rng: Random, role: string?)
	local yaw = rng:NextNumber(0, math.pi * 2)
	for i = 1, 6 do
		local h = height * rng:NextNumber(0.55, 1)
		local cf = CFrame.new(base + hdir(rng:NextNumber(0, 6.28)) * rng:NextNumber(0, 0.6))
			* CFrame.Angles(0, yaw + i * 1.05, 0)
			* CFrame.Angles(rng:NextNumber(0.08, 0.35), 0, 0)
			* CFrame.new(0, h / 2, 0)
		local nuance = rng:NextNumber(-0.14, 0.12)
		local blade = Build.wedge(parent, "TallGrass", Vector3.new(0.16, h, 0.55), cf, shade(color, nuance), { CanCollide = false, CanQuery = false, CastShadow = false })
		if role then
			Core.solRole(blade, role, nuance)
		end
	end
	for _ = 1, 2 do
		local h = height * rng:NextNumber(1, 1.25)
		local top = base + hdir(rng:NextNumber(0, 6.28)) * rng:NextNumber(0.1, 0.5) + UP * h
		Build.deco(parent, "Stalk", Vector3.new(0.1, h, 0.1), CFrame.new(top - UP * h / 2), shade(color, -0.1), { CastShadow = false })
		Core.ellipsoid(parent, "Seed", Vector3.new(0.32, 1.1, 0.32), CFrame.new(top), rgb(214, 196, 140)).CastShadow = false
	end
end

-- Fougère : frondes arquées en éventail.
function Nature.fern(parent: Instance, base: Vector3, size: number, color: Color3, rng: Random)
	local yaw = rng:NextNumber(0, math.pi * 2)
	for i = 1, 6 do
		local a = yaw + i * (math.pi * 2 / 6) + rng:NextNumber(-0.2, 0.2)
		local pos = base + hdir(a) * size * 0.42 + UP * size * 0.32
		local cf = CFrame.lookAt(pos, base + UP * size * 0.05) * CFrame.Angles(math.rad(rng:NextNumber(-28, -12)), 0, 0)
		local part = Core.ellipsoid(parent, "Fern", Vector3.new(size * 0.32, size * 0.06, size * 0.95), cf, shade(color, rng:NextNumber(-0.1, 0.12)), LEAF)
		part.CastShadow = false
	end
end

-- Roseaux et massettes (bord de l'eau).
function Nature.reeds(parent: Instance, base: Vector3, height: number, rng: Random)
	local green = rgb(96, 128, 62)
	for _ = 1, 6 do
		local h = height * rng:NextNumber(0.6, 1)
		local p = base + hdir(rng:NextNumber(0, 6.28)) * rng:NextNumber(0, 1.2)
		local tilt = CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
		Build.deco(parent, "Reed", Vector3.new(0.18, h, 0.18), CFrame.new(p) * tilt * CFrame.new(0, h / 2, 0), shade(green, rng:NextNumber(-0.1, 0.1)), { CastShadow = false })
	end
	for _ = 1, 2 do
		local h = height * rng:NextNumber(0.8, 1.05)
		local p = base + hdir(rng:NextNumber(0, 6.28)) * rng:NextNumber(0, 0.8)
		Build.deco(parent, "Reed", Vector3.new(0.16, h, 0.16), CFrame.new(p + UP * h / 2), green, { CastShadow = false })
		Core.ellipsoid(parent, "Cattail", Vector3.new(0.45, 1.6, 0.45), CFrame.new(p + UP * (h - 0.6)), rgb(104, 70, 46))
	end
end

-- Nénuphar (feuille ronde fendue et parfois une fleur).
function Nature.lilyPad(parent: Instance, center: Vector3, size: number, rng: Random)
	local pad = Build.deco(
		parent,
		"LilyPad",
		Vector3.new(0.12, size, size),
		CFrame.new(center) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(90)),
		shade(rgb(70, 130, 60), rng:NextNumber(-0.1, 0.1)),
		{ Shape = Enum.PartType.Cylinder, CastShadow = false }
	)
	pad.Material = LEAF
	if rng:NextNumber() < 0.35 then
		Core.ball(parent, "LilyFlower", size * 0.32, center + UP * size * 0.12, rgb(250, 200, 220))
	end
end

-- Petite fleur (tige + corolle + cœur).
function Nature.flower(parent: Instance, base: Vector3, color: Color3, rng: Random)
	local h = rng:NextNumber(0.7, 1.3)
	Build.deco(parent, "Stem", Vector3.new(0.12, h, 0.12), CFrame.new(base + Vector3.new(0, h / 2, 0)), rgb(70, 120, 56), { CastShadow = false })
	Core.ellipsoid(parent, "Petals", Vector3.new(0.85, 0.28, 0.85), CFrame.new(base + Vector3.new(0, h, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), color).CastShadow = false
	Core.ellipsoid(parent, "Heart", Vector3.new(0.3, 0.32, 0.3), CFrame.new(base + Vector3.new(0, h + 0.08, 0)), rgb(255, 210, 90)).CastShadow = false
end

-- Massif de fleurs : feuillage bas et fleurs de plusieurs couleurs.
function Nature.flowerBed(parent: Instance, center: Vector3, radius: number, colors: { Color3 }, rng: Random, count: number?)
	for _ = 1, math.max(2, math.floor(radius)) do
		local p = center + hdir(rng:NextNumber(0, 6.28)) * rng:NextNumber(0, radius * 0.8)
		Core.ball(parent, "Leaves", rng:NextNumber(1.2, 2), p + UP * 0.3, shade(rgb(70, 116, 54), rng:NextNumber(-0.1, 0.1)), LEAF).CastShadow = false
	end
	for _ = 1, count or math.floor(radius * 3) do
		local p = center + hdir(rng:NextNumber(0, 6.28)) * rng:NextNumber(0, radius)
		Nature.flower(parent, p, colors[rng:NextInteger(1, #colors)], rng)
	end
end

-- Champignon (chapeau tacheté ou brun).
function Nature.mushroom(parent: Instance, base: Vector3, size: number, rng: Random, capColor: Color3?)
	local cap = capColor or (rng:NextNumber() < 0.5 and rgb(196, 60, 46) or rgb(150, 110, 76))
	Build.deco(parent, "MushStem", Vector3.new(size * 0.3, size * 0.7, size * 0.3), CFrame.new(base + UP * size * 0.35), rgb(236, 226, 206))
	Core.ellipsoid(parent, "MushCap", Vector3.new(size, size * 0.55, size), CFrame.new(base + UP * size * 0.75), cap)
end

-- Souche coupée (cernes clairs sur le dessus).
function Nature.stump(parent: Instance, base: Vector3, diameter: number, rng: Random): Model
	local model = Core.slot(parent, "Souche", CFrame.new(base), diameter * 0.7)
	local h = diameter * rng:NextNumber(0.5, 0.8)
	Core.vcyl(model, "Stump", CFrame.new(base - UP * 0.3), h, diameter, TRUNK, WOOD)
	Core.vcyl(model, "StumpTop", CFrame.new(base + UP * (h - 0.32)), 0.1, diameter * 0.86, rgb(196, 160, 116), WOOD, false)
	for i = 1, 3 do
		local dir = hdir(i * 2.1 + rng:NextNumber(-0.3, 0.3))
		wood(model, "Root", base + UP * h * 0.4 + dir * diameter * 0.3, base + dir * diameter * 0.8 - UP * 0.3, diameter * 0.3, shade(TRUNK, -0.05))
	end
	return model
end

-- Tronc couché moussu.
function Nature.log(parent: Instance, cf: CFrame, length: number, diameter: number, rng: Random): Model
	local model = Core.slot(parent, "TroncCouche", cf, diameter)
	local a = (cf * CFrame.new(-length / 2, diameter / 2 - 0.2, 0)).Position
	local b = (cf * CFrame.new(length / 2, diameter / 2 - 0.2, 0)).Position
	wood(model, "Log", a, b, diameter, TRUNK, true)
	for _, p in { a, b } do
		Core.vcyl(model, "LogEnd", CFrame.lookAt(p, p + (b - a)) * CFrame.Angles(math.rad(-90), 0, 0), 0.1, diameter * 0.85, rgb(190, 154, 110), WOOD, false)
	end
	for _ = 1, 3 do
		local p = a:Lerp(b, rng:NextNumber(0.15, 0.85)) + UP * diameter * 0.42
		Core.ellipsoid(model, "Moss", Vector3.new(diameter * 0.9, diameter * 0.25, diameter * 0.9), CFrame.new(p), rgb(84, 130, 60), LEAF)
	end
	return model
end

------------------------------------------------------------------------
-- Rochers, falaises, montagnes
------------------------------------------------------------------------

-- Rocher irrégulier à facettes : blocs inclinés à moitié enterrés qui s'interpénètrent, plus un
-- éclat clair sur le dessus et de la mousse si demandé.
function Nature.rock(
	parent: Instance,
	base: Vector3 | CFrame,
	size: number,
	options: { color: Color3?, rng: Random?, material: Enum.Material?, slot: string?, moss: Color3?, role: string? }?
): Model
	local o = options or {}
	local rng = o.rng or Random.new()
	local cf = Core.asCFrame(base, rng)
	local color = o.color or rgb(132, 128, 122)
	local model = Core.slot(parent, o.slot or "Rocher", cf, size * 0.75)
	local material = o.material or Enum.Material.Rock
	local blocks = rng:NextInteger(3, 5)
	for i = 1, blocks do
		local s = size * (i == 1 and 1 or rng:NextNumber(0.45, 0.7))
		local dims = Vector3.new(s * rng:NextNumber(0.8, 1.1), s * rng:NextNumber(0.55, 0.85), s * rng:NextNumber(0.7, 1))
		local offset = i == 1 and Vector3.zero or Vector3.new(rng:NextNumber(-0.5, 0.5) * size, 0, rng:NextNumber(-0.5, 0.5) * size)
		local tilt = CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, math.pi), rng:NextNumber(-0.6, 0.6))
		local pos = cf * CFrame.new(offset + Vector3.new(0, dims.Y * (i == 1 and 0.16 or 0.04), 0))
		local nuance = rng:NextNumber(-0.1, 0.1)
		local part = Build.part(model, "Rock", dims, CFrame.new(pos.Position) * tilt, shade(color, nuance), { Material = material })
		if o.role then
			Core.solRole(part, o.role, nuance)
		end
	end
	-- éclat clair (arête usée au soleil)
	local chip = Build.part(
		model,
		"Rock",
		Vector3.new(size * 0.5, size * 0.18, size * 0.42),
		cf * CFrame.new(rng:NextNumber(-0.15, 0.15) * size, size * 0.5, rng:NextNumber(-0.15, 0.15) * size) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)),
		shade(color, 0.12),
		{ Material = material, CanCollide = false }
	)
	if o.role then
		Core.solRole(chip, o.role, 0.12)
	end
	if o.moss then
		Core.ellipsoid(model, "Moss", Vector3.new(size * 0.8, size * 0.22, size * 0.7), cf * CFrame.new(0, size * 0.58, 0), o.moss, LEAF)
	end
	return model
end

-- Falaise en strates : grands blocs empilés (couches alternées), dessus herbeux et éboulis.
-- `cf` = pied de la falaise au centre, -Z local = face visible. Rôles de sol facultatifs
-- (`role` = roche, `topRole` = herbe du dessus) pour suivre l'univers.
function Nature.cliff(
	parent: Instance,
	cf: CFrame,
	width: number,
	height: number,
	depth: number,
	options: { rng: Random?, color: Color3?, top: Color3?, role: string?, topRole: string?, slot: string?, rubble: boolean? }?
): Model
	local o = options or {}
	local rng = o.rng or Random.new()
	local color = o.color or rgb(132, 122, 110)
	local model = Core.slot(parent, o.slot or "Falaise", cf, height)
	local layers = math.max(2, math.floor(height / 9))
	local layerH = height / layers
	for l = 0, layers - 1 do
		local inset = l * rng:NextNumber(0.6, 1.6)
		local pieces = math.max(1, math.floor(width / 26))
		for k = 0, pieces - 1 do
			local w = width / pieces * rng:NextNumber(1.05, 1.25)
			local x = -width / 2 + (k + 0.5) * width / pieces + rng:NextNumber(-2, 2)
			local h = layerH * rng:NextNumber(1.05, 1.3)
			local nuance = ((l + k) % 2 == 0 and 0.04 or -0.05) + rng:NextNumber(-0.04, 0.04)
			local part = Build.part(
				model,
				"Cliff",
				Vector3.new(w, h, depth - inset),
				cf * CFrame.new(x, l * layerH + h / 2 - 0.5, inset / 2 + rng:NextNumber(-1, 1)) * CFrame.Angles(rng:NextNumber(-0.04, 0.04), rng:NextNumber(-0.08, 0.08), rng:NextNumber(-0.05, 0.05)),
				shade(color, nuance),
				{ Material = Enum.Material.Rock }
			)
			if o.role then
				Core.solRole(part, o.role, nuance)
			end
		end
	end
	if o.top then
		local cap = Build.part(model, "CliffTop", Vector3.new(width * 1.02, 1.4, depth), cf * CFrame.new(0, height + 0.4, layers * 0.6), o.top, { Material = LEAF })
		if o.topRole then
			Core.solRole(cap, o.topRole)
		end
		for _ = 1, math.max(2, math.floor(width / 14)) do
			local lip = Core.ellipsoid(
				model,
				"CliffGrass",
				Vector3.new(rng:NextNumber(8, 14), rng:NextNumber(2.2, 3.4), rng:NextNumber(5, 8)),
				cf * CFrame.new(rng:NextNumber(-width / 2, width / 2), height + 0.6, -depth / 2 + layers * 0.8 + rng:NextNumber(0, 2)),
				shade(o.top, rng:NextNumber(-0.06, 0.06)),
				LEAF
			)
			if o.topRole then
				Core.solRole(lip, o.topRole, rng:NextNumber(-0.06, 0.06))
			end
		end
	end
	if o.rubble ~= false then
		for _ = 1, math.max(2, math.floor(width / 16)) do
			Nature.rock(model, cf * CFrame.new(rng:NextNumber(-width / 2, width / 2), 0, -depth / 2 - rng:NextNumber(1, 5)), rng:NextNumber(3, 7), {
				rng = rng,
				color = shade(color, -0.06),
				slot = "Eboulis",
				role = o.role,
			})
		end
	end
	return model
end

-- Colline arrondie : vraie sphère à moitié enterrée (on marche dessus).
function Nature.hill(parent: Instance, center: Vector3, size: Vector3, color: Color3, material: Enum.Material?): Part
	local d = math.max(size.X, size.Z)
	local part = Build.part(parent, "Hill", Vector3.new(d, d, d), CFrame.new(center), color, {
		Material = material or LEAF,
		Shape = Enum.PartType.Ball,
	})
	part.CastShadow = false
	return part
end

-- Montagne d'horizon escarpée : massif de roche (pics inclinés), pentes vertes, petits bosquets,
-- neige facultative. `base` = centre au niveau de la mer.
function Nature.mountain(
	parent: Instance,
	base: Vector3,
	width: number,
	height: number,
	options: { rock: Color3?, grass: Color3?, snow: Color3?, rng: Random?, slot: string?, trees: Color3?, material: Enum.Material? }?
): Model
	local o = options or {}
	local rng = o.rng or Random.new()
	local rock = o.rock or rgb(118, 110, 102)
	local grass = o.grass or rgb(76, 120, 62)
	local model = Core.slot(parent, o.slot or "Montagne", CFrame.new(base), height)
	pcall(function()
		model.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	end)
	local material = o.material or Enum.Material.Rock
	local function peak(pos: Vector3, w: number, h: number, color: Color3)
		local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08))
		for _, part in Core.pyramid(model, "Peak", cf, w, w * rng:NextNumber(0.75, 1), h, color, material) do
			part.CastShadow = false
		end
	end
	-- pics de roche
	local peaks = rng:NextInteger(3, 5)
	for i = 1, peaks do
		local main = i == 1
		local pos = base + (main and Vector3.zero or hdir(rng:NextNumber(0, 6.28)) * width * rng:NextNumber(0.15, 0.3))
		local h = height * (main and 1 or rng:NextNumber(0.55, 0.8))
		local w = width * (main and 0.42 or rng:NextNumber(0.26, 0.36))
		peak(pos, w, h, shade(rock, rng:NextNumber(-0.08, 0.06)))
		if o.snow and (main or rng:NextNumber() < 0.4) then
			for _, part in Core.pyramid(model, "Snow", CFrame.new(pos + UP * h * 0.68) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), w * 0.36, w * 0.34, h * 0.34, o.snow, Enum.Material.Snow) do
				part.CastShadow = false
				part.CanCollide = false
			end
		end
	end
	-- contreforts verts (pyramides basses et larges, facettes nettes) au pied
	local slopes = rng:NextInteger(4, 6)
	for i = 1, slopes do
		local a = i / slopes * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local pos = base + hdir(a) * width * rng:NextNumber(0.2, 0.34) - UP * height * 0.05
		local s = width * rng:NextNumber(0.4, 0.55)
		local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		for _, part in Core.pyramid(model, "Slope", cf, s, s * rng:NextNumber(0.7, 1), height * rng:NextNumber(0.3, 0.5), shade(grass, rng:NextNumber(-0.1, 0.05)), LEAF) do
			part.CastShadow = false
		end
	end
	-- forêt de conifères au pied (petites pyramides foncées)
	local treeColor = o.trees or shade(grass, -0.28)
	for _ = 1, rng:NextInteger(4, 7) do
		local a = rng:NextNumber(0, math.pi * 2)
		local pos = base + hdir(a) * width * rng:NextNumber(0.42, 0.55)
		local s = width * rng:NextNumber(0.05, 0.08)
		for _, part in Core.pyramid(model, "Grove", CFrame.new(pos) * CFrame.Angles(0, a, 0), s, s, s * rng:NextNumber(1.6, 2.4), shade(treeColor, rng:NextNumber(-0.08, 0.08)), LEAF) do
			part.CastShadow = false
		end
	end
	return model
end

return Nature
