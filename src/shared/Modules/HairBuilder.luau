-- COIFFURES en mèches couchées (v3.4) : comme les cheveux en maillage des avatars d'animé,
-- une CALOTTE qui épouse le crâne, recouverte de MÈCHES qui partent du haut de la tête et
-- tombent en suivant sa forme (frange sur le front, mèches des côtés, nuque), chacune avec un
-- corps arrondi (ellipsoïdes aplatis) et une POINTE effilée (lame de deux coins). La silhouette
-- vient du bout des mèches, pas de piques plantées tout autour (« couronnes »).
--
-- Repère de la tête (CharacterBuilder) : centre de la tête en (0, 0, 0), face vers -Z, tête
-- visible = cylindre arrondi de rayon 0,6 et de hauteur 1,2 (haut en y = 0,6), visage peint
-- sur des plaques à 0,645 du centre (de y = -0,5 à 0,46).
--
-- Une mèche « qui coule » est donnée par sa racine et son bout sur la calotte : azimut a
-- (degrés : 0 = devant, 90 = côté +X, 180 = derrière) et hauteur h (0 = sommet, 1 = tour de
-- tête, au-delà = plus bas le long du cylindre, ~0,6 stud par unité). Une PIQUE (coiffures
-- dressées) part de la calotte dans une direction donnée.

local HairBuilder = {}

local WHITE = Color3.new(1, 1, 1)

-- Calotte (centre et demi-axes) : le haut dépasse la tête de 0,15, reculée pour que l'avant
-- reste derrière les plaques du visage (les mèches de devant cachent le haut du front).
local CAP_C = Vector3.new(0, 0.15, 0.12)
local CAP_R = Vector3.new(0.69, 0.6, 0.7)
-- Surface sur laquelle courent les mèches (un peu au-dessus de la calotte).
local FLOW_C = Vector3.new(0, 0.15, 0.04)
local FLOW_R = Vector3.new(0.71, 0.63, 0.73)
local DROP = 0.6 -- studs par unité de hauteur sous le tour de tête

HairBuilder.CapCenter = CAP_C
HairBuilder.FlowRadii = FLOW_R

local function rad(d: number): number
	return math.rad(d)
end

-- Point de la surface des mèches (azimut a en degrés, hauteur h, décollement `out` en studs) et
-- sa normale sortante.
function HairBuilder.surface(a: number, h: number, out: number?): (Vector3, Vector3)
	local o = out or 0
	local sa, ca = math.sin(rad(a)), math.cos(rad(a))
	if h <= 1 then
		local p = rad(h * 90)
		local sp, cp = math.sin(p), math.cos(p)
		local dir = Vector3.new(sp * sa, cp, -sp * ca)
		local normal = Vector3.new(dir.X / FLOW_R.X, dir.Y / FLOW_R.Y, dir.Z / FLOW_R.Z).Unit
		local point = FLOW_C + Vector3.new(dir.X * FLOW_R.X, dir.Y * FLOW_R.Y, dir.Z * FLOW_R.Z) + normal * o
		return point, normal
	end
	local normal = Vector3.new(sa, 0, -ca)
	local point = Vector3.new(FLOW_C.X + sa * FLOW_R.X, FLOW_C.Y - (h - 1) * DROP, FLOW_C.Z - ca * FLOW_R.Z) + normal * o
	return point, normal
end

-- Repère d'un morceau de mèche : Y le long de la mèche, Z vers l'extérieur (côté plat).
local function frameAlong(center: Vector3, along: Vector3, outward: Vector3): CFrame
	local up = along.Unit
	local right = up:Cross(outward)
	if right.Magnitude < 0.05 then
		right = up:Cross(Vector3.new(0, 0, 1))
		if right.Magnitude < 0.05 then
			right = Vector3.new(1, 0, 0)
		end
	end
	right = right.Unit
	local back = right:Cross(up).Unit
	if back:Dot(outward) < 0 then
		right = -right
		back = -back
	end
	return CFrame.fromMatrix(center, right, up, back)
end

-- Teinte plus sombre et plus saturée (dessous des mèches).
local function deeper(c: Color3, k: number): Color3
	return Color3.new(c.R * (1 - 0.32 * k), c.G * (1 - 0.36 * k), c.B * (1 - 0.3 * k))
end

------------------------------------------------------------------------
-- Primitives
------------------------------------------------------------------------

-- Mèche : suite de points (repère de la tête), largeurs aux points, épaisseur, couleurs.
-- Corps = un ellipsoïde aplati par tronçon (ils se chevauchent : ruban lisse qui s'affine),
-- puis pointe effilée (lame) dans le prolongement du dernier tronçon.
-- o = { tip (longueur de la pointe), tipColor, normals (normales sortantes aux points), shine }
function HairBuilder.lock(ctx, color: Color3, points: { Vector3 }, widths: { number }, depth: number, o)
	local opts = o or {}
	local normals = opts.normals
	local n = #points
	for i = 1, n - 1 do
		local a, b = points[i], points[i + 1]
		local seg = b - a
		local len = seg.Magnitude
		if len > 0.01 then
			local outward = normals and (normals[i] + normals[i + 1]) or Vector3.new(a.X + b.X, 0, a.Z + b.Z)
			local w = (widths[i] + widths[i + 1]) / 2
			local tone = color
			if opts.shade and i > 1 then
				tone = color:Lerp(opts.shade, 0.35 * (i - 1) / math.max(1, n - 2))
			end
			ctx.ball("Head", "HairLock", Vector3.new(w, len * 1.42, depth), frameAlong((a + b) / 2, seg, outward), tone)
		end
	end
	local tipLen = opts.tip or 0
	if tipLen > 0.02 and n >= 2 then
		local last, before = points[n], points[n - 1]
		local dir = (last - before).Unit
		if opts.curl then
			dir = (dir + opts.curl).Unit
		end
		local outward = normals and normals[n] or Vector3.new(last.X, 0, last.Z)
		local frame = frameAlong(last - dir * 0.04, dir, outward)
		local w = widths[n] * 0.95
		local tipColor = opts.tipColor or (opts.shade and color:Lerp(opts.shade, 0.35) or color)
		ctx.blade("Head", tipColor, frame, tipLen, w, depth * 0.7, "HairTip")
	end
	if opts.shine and n >= 2 then
		-- reflet : fine bande claire sur le haut de la mèche
		local a, b = points[1], points[2]
		local seg = b - a
		local outward = normals and normals[1] or Vector3.new(a.X, 0, a.Z)
		local frame = frameAlong(a + seg * 0.55, seg, outward)
		ctx.ball("Head", "HairShine", Vector3.new(widths[1] * 0.24, seg.Magnitude * 0.8, depth * 0.5), frame * CFrame.new(widths[1] * 0.12, 0, depth * 0.3), opts.shine)
	end
end

-- LAME : mèche plate et effilée couchée sur la calotte (demi-pyramide : dos plat contre la tête,
-- arête au milieu, moitié éclairée / moitié dans l'ombre, comme les mèches en maillage), de la
-- racine (a0, h0) au bout (a1, h1). La racine s'enfonce dans la calotte (`sink`) : seul le bas
-- de la lame se voit, il épouse le crâne et finit en pointe au-delà du bord.
-- e = { a0, h0, a1, h1, w, d, sink, lift (bout décollé), over (dépassement de la pointe au-delà
--       du bout, en studs), color, dark, tipColor, out }
function HairBuilder.blade(ctx, e, colors)
	local sink = e.sink or 0.08
	local root, n0 = HairBuilder.surface(e.a0, e.h0, (e.out or 0.02) - sink)
	local tip, n1 = HairBuilder.surface(e.a1, e.h1, (e.out or 0.02) + (e.lift or 0.03))
	local dir = tip - root
	local length = dir.Magnitude + (e.over or 0.12)
	local outward = (n0 + n1).Unit
	local up = dir.Unit
	local right = up:Cross(outward)
	if right.Magnitude < 0.05 then
		right = Vector3.new(1, 0, 0)
	end
	right = right.Unit
	local back = right:Cross(up).Unit
	if back:Dot(outward) < 0 then
		right = -right
		back = -back
	end
	local frame = CFrame.fromMatrix(root, right, up, back)
	local color = e.color or colors.main
	local dark = e.dark or colors.mid
	local lit = ctx.litFrame and ctx.litFrame(frame) or frame
	local litLeft = lit ~= frame
	ctx.cone("Head", frame, length, e.w or 0.36, (e.d or 0.13) * 2, litLeft and dark or color, litLeft and color or dark, 1, "HairLock")
	if e.tipColor or colors.tip then
		-- bout coloré (cheveux à pointes d'une autre couleur)
		local k = 0.42
		local tc = e.tipColor or colors.tip
		ctx.cone(
			"Head",
			frame * CFrame.new(0, length * (1 - k), 0),
			length * k + 0.01,
			(e.w or 0.36) * k * 1.05,
			(e.d or 0.13) * 2 * k * 1.1,
			tc,
			tc:Lerp(Color3.new(0, 0, 0), 0.25),
			1,
			"HairTip"
		)
	end
end

-- LOSANGE : mèche fine à la racine, large au milieu, pointue au bout (deux demi-pyramides base
-- contre base), couchée sur la calotte : racine (a0, h0), milieu (am, hm), bout (a1, h1).
-- Les mèches des coiffures « low poly » d'animé : elles convergent vers le sommet sans se
-- dresser, et leurs pointes font le bord découpé.
-- e = { a0, h0, am, hm, a1, h1, w, d, out, lift, over, color, dark, tipColor }
function HairBuilder.diamond(ctx, e, colors)
	local out = e.out or 0.02
	local root, n0 = HairBuilder.surface(e.a0, e.h0, out - 0.03)
	local mid, nm = HairBuilder.surface(e.am or (e.a0 + e.a1) / 2, e.hm or (e.h0 + e.h1) / 2, out)
	local tip, n1 = HairBuilder.surface(e.a1, e.h1, out + (e.lift or 0.03))
	local w = e.w or 0.36
	local depth = (e.d or 0.12) * 2
	local color = e.color or colors.main
	local dark = e.dark or colors.mid
	local function half(from: Vector3, to: Vector3, normal: Vector3, length: number, c1: Color3, c2: Color3, name: string)
		local up = (to - from).Unit
		local right = up:Cross(normal)
		if right.Magnitude < 0.05 then
			right = Vector3.new(1, 0, 0)
		end
		right = right.Unit
		local back = right:Cross(up).Unit
		if back:Dot(normal) < 0 then
			right = -right
			back = -back
		end
		local frame = CFrame.fromMatrix(from, right, up, back)
		local lit = ctx.litFrame and ctx.litFrame(frame) or frame
		local flipped = lit ~= frame
		ctx.cone("Head", frame, length, w, depth, flipped and c2 or c1, flipped and c1 or c2, 1, name)
	end
	-- moitié haute (vers la racine) puis moitié basse (vers la pointe), base commune au milieu
	half(mid, root, (n0 + nm).Unit, (root - mid).Magnitude + 0.02, color, dark, "HairLock")
	local over = e.over or 0.12
	half(mid, tip, (nm + n1).Unit, (tip - mid).Magnitude + over, color, dark, "HairLock")
	local tc = e.tipColor or colors.tip
	if tc then
		local k = 0.45
		local up = (tip - mid).Unit
		local len = (tip - mid).Magnitude + over
		local start = mid + up * len * (1 - k)
		local right = up:Cross(n1)
		right = right.Magnitude > 0.05 and right.Unit or Vector3.new(1, 0, 0)
		local back = right:Cross(up).Unit
		if back:Dot(n1) < 0 then
			right = -right
			back = -back
		end
		ctx.cone("Head", CFrame.fromMatrix(start + n1 * 0.01, right, up, back), len * k + 0.01, w * k * 1.05, depth * k * 1.1, tc, tc:Lerp(Color3.new(0, 0, 0), 0.25), 1, "HairTip")
	end
end

-- Mèche qui coule sur la calotte, de (a0, h0) à (a1, h1), en `steps` tronçons.
-- e = { a0, h0, a1, h1, w (largeur) ou widths (une par point), d (épaisseur), lift (décollement
--       du bout), out (décollement de la racine), taper (largeur au bout / largeur), tip
--       (longueur de la pointe), curl (Vector3 ajouté à la direction de la pointe), color,
--       tipColor, shade, shine, steps }
function HairBuilder.flow(ctx, e, colors)
	local steps = e.steps or 2
	local points, normals, widths = {}, {}, {}
	local lift = e.lift or 0
	local out0 = e.out or 0.02
	local taper = e.taper or 0.72
	for k = 0, steps do
		local t = k / steps
		local a = e.a0 + (e.a1 - e.a0) * t
		local h = e.h0 + (e.h1 - e.h0) * t
		local p, n = HairBuilder.surface(a, h, out0 + lift * t * t)
		table.insert(points, p)
		table.insert(normals, n)
		table.insert(widths, e.widths and e.widths[k + 1] or e.w * (1 - (1 - taper) * t))
	end
	HairBuilder.lock(ctx, e.color or colors.main, points, widths, e.d or 0.15, {
		tip = e.tip or 0.22,
		tipColor = e.tipColor or colors.tip,
		normals = normals,
		curl = e.curl,
		shade = e.shade,
		shine = e.shine,
	})
end

-- Hauteur du bout des mèches selon l'azimut : devant `front`, sur les côtés `side`, derrière
-- `back` (passage progressif).
local function profile(a: number, front: number, side: number, back: number): number
	local t = math.abs(((a + 180) % 360) - 180) / 180
	local function smooth(x: number): number
		return x * x * (3 - 2 * x)
	end
	if t <= 0.5 then
		return front + (side - front) * smooth(t / 0.5)
	end
	return side + (back - side) * smooth((t - 0.5) / 0.5)
end
HairBuilder.profile = profile

-- COURONNE de mèches : `n` longues mèches régulièrement réparties, du sommet jusqu'au bord donné
-- par le profil (front / side / back), légèrement vrillées (twist). Elles se chevauchent sur deux
-- niveaux (une sur deux un peu décollée) : masse continue, séparations nettes entre les mèches.
-- o = { n, front, side, back, w (largeur max), d, tip, lift (bout qui rebique, peut être une
--       fonction de l'azimut), twist, offset (azimut de la 1re mèche), skip (fonction(a) → vrai
--       pour ne pas poser de mèche), h0 }
function HairBuilder.ring(ctx, colors, o, rand)
	local n = o.n or 16
	local w = o.w or (2 * math.pi * 0.72 / n * 1.55)
	for i = 1, n do
		-- azimut ramené entre -180 et 180 (les filtres `skip` testent |a| autour du front)
		local a = ((o.offset or 0) + (i - 1) * 360 / n + rand(-4, 4) + 180) % 360 - 180
		if o.skip and o.skip(a) then
			continue
		end
		local hEnd = o.h1 or (profile(a, o.front or 1.15, o.side or 1.5, o.back or 1.9) + rand(-0.08, 0.08) + (i % 2 == 0 and (o.alternate or 0.1) or 0))
		local h0 = (o.h0 or 0.22) + rand(0, 0.06)
		local hm = h0 + (hEnd - h0) * (o.mid or 0.45)
		local lift = type(o.lift) == "function" and o.lift(a) or (o.lift or 0.03)
		local back = math.abs(((a + 180) % 360) - 180) > 110
		local twist = (o.twist or 6) * (i % 2 == 0 and 1 or -0.6)
		HairBuilder.diamond(ctx, {
			a0 = a - twist * 1.5,
			h0 = h0,
			am = a,
			hm = hm,
			a1 = a + twist,
			h1 = hEnd,
			w = w * (1 + rand(-0.08, 0.08)),
			d = o.d or 0.11,
			out = (i % 2 == 0) and 0.03 or 0.008,
			lift = lift,
			over = (o.tip or 0.14) * (1 + rand(-0.2, 0.3)),
			color = (i % 4 == 1) and colors.main:Lerp(colors.shine, 0.2) or (back and colors.main:Lerp(colors.mid, 0.45) or colors.main),
			dark = back and colors.under or colors.mid,
		}, colors)
	end
end

-- DESSUS : quelques mèches à plat qui partent du sommet (séparations douces sur la calotte).
-- o = { n, h1, w, d, offset }
function HairBuilder.crown(ctx, colors, o, rand)
	local n = o.n or 6
	for i = 1, n do
		local a = (o.offset or 20) + (i - 1) * 360 / n + rand(-10, 10)
		HairBuilder.flow(ctx, {
			a0 = a - 25,
			h0 = 0.02,
			a1 = a + 6,
			h1 = (o.h1 or 0.5) + rand(-0.05, 0.05),
			steps = 1,
			widths = { (o.w or 0.4) * 0.6, o.w or 0.4 },
			d = o.d or 0.12,
			out = -0.01,
			tip = 0,
			color = (i % 2 == 0) and colors.main:Lerp(colors.shine, 0.22) or colors.main,
		}, colors)
	end
end

-- FRANGE : `n` mèches par-dessus la couronne, de -spread à +spread degrés, qui descendent sur
-- le front jusqu'à `h1` (plus long au centre avec vshape > 0, sur un côté avec sweep).
-- o = { n, spread, h0, h1, w, d, tip, lift, part (raie : décalage en degrés), sweep (degrés de
--       glissement vers un côté), fan, vshape, curl, alt (couleur une mèche sur deux), jitter }
function HairBuilder.bangs(ctx, colors, o, rand)
	local n = o.n or 5
	local spread = o.spread or 52
	for i = 1, n do
		local t = n == 1 and 0 or (i - 1) / (n - 1) * 2 - 1
		local a = t * spread + (o.part or 0)
		local j = o.jitter or 0.05
		local sweep = (o.sweep or 0) + t * (o.fan or 10)
		local h0 = (o.h0 or 0.42) + rand(-j, j)
		local h1 = (o.h1 or 1.22) + rand(-j, j) * 2 + (o.vshape or 0) * (1 - math.abs(t))
		HairBuilder.diamond(ctx, {
			a0 = a * 0.55 + (o.part or 0) * 0.45,
			h0 = h0,
			am = a + sweep * 0.4,
			hm = h0 + (h1 - h0) * 0.5,
			a1 = a + sweep,
			h1 = h1,
			w = (o.w or 0.36) * (1 + rand(-0.08, 0.08)),
			d = o.d or 0.1,
			out = 0.05,
			lift = o.lift or 0.02,
			over = (o.tip or 0.14) * (1 + rand(-0.15, 0.25)),
			color = (o.alt and i % 2 == 0) and o.alt or colors.main,
		}, colors)
	end
end

-- MÈCHES DES CÔTÉS (devant les oreilles), par-dessus la couronne : de chaque côté, `n` mèches à
-- partir de l'azimut `a` (degrés), écartées de `gap`.
-- o = { a, n, gap, h0, h1, w, d, tip, lift, curl, step (raccourcit les suivantes) }
function HairBuilder.sides(ctx, colors, o, rand)
	local n = o.n or 1
	for _, side in { -1, 1 } do
		for k = 1, n do
			local a = side * ((o.a or 70) + (k - 1) * (o.gap or 22))
			local e = {
				a0 = a - side * 8,
				h0 = (o.h0 or 0.6) + rand(-0.04, 0.04),
				a1 = a + side * (o.drift or 2),
				h1 = (o.h1 or 1.6) + (k - 1) * (o.step or -0.12) + rand(-0.05, 0.05),
				w = (o.w or 0.34) * (1 + rand(-0.08, 0.08)),
				d = o.d or 0.11,
				out = 0.05,
				lift = o.lift or 0.02,
				over = (o.tip or 0.16) * (1 + rand(-0.1, 0.2)),
				color = colors.main,
			}
			if o.mid then
				e.am = (e.a0 + e.a1) / 2
				e.hm = e.h0 + (e.h1 - e.h0) * o.mid
				HairBuilder.diamond(ctx, e, colors)
			else
				HairBuilder.blade(ctx, e, colors)
			end
		end
	end
end

-- NUQUE : mèches qui tombent derrière, par-dessus la couronne (cheveux mi-longs ou longs).
-- o = { n, spread, h0, h1, w, d, tip, lift (bout qui rebique), round, mid (si donné : mèche en
--       losange, la plus large à cette fraction : cheveux longs larges jusqu'en bas) }
function HairBuilder.back(ctx, colors, o, rand)
	local n = o.n or 5
	local spread = o.spread or 70
	for i = 1, n do
		local t = n == 1 and 0 or (i - 1) / (n - 1) * 2 - 1
		local a = 180 + t * spread
		local e = {
			a0 = 180 + t * spread * 0.8,
			h0 = (o.h0 or 0.55) + rand(-0.05, 0.05),
			a1 = a + t * (o.fan or 6),
			h1 = (o.h1 or 2.1) + rand(-0.1, 0.1) - math.abs(t) * (o.round or 0.15),
			w = (o.w or 0.44) * (1 + rand(-0.06, 0.06)),
			d = o.d or 0.13,
			out = 0.05,
			lift = (o.lift or 0.05) + rand(0, 0.03),
			over = (o.tip or 0.18) * (1 + rand(-0.1, 0.2)),
			color = (i % 2 == 0) and colors.mid or colors.main:Lerp(colors.mid, 0.4),
			dark = colors.under,
		}
		if o.mid then
			e.am = (e.a0 + e.a1) / 2
			e.hm = e.h0 + (e.h1 - e.h0) * o.mid
			HairBuilder.diamond(ctx, e, colors)
		else
			HairBuilder.blade(ctx, e, colors)
		end
	end
end

-- Pique (coiffures dressées) : part de la calotte en (a, h), dans la direction `dir` (repère de
-- la tête) ou, à défaut, la normale relevée de `rise` (0 = à plat, 1 = presque vertical).
-- e = { a, h, len, w, d, dir, rise, color, dark, tipColor }
function HairBuilder.spike(ctx, e, colors)
	local root, normal = HairBuilder.surface(e.a, e.h, -0.08)
	local dir = e.dir
	if not dir then
		dir = (normal + Vector3.new(0, 1, 0) * (e.rise or 0.4)).Unit
	end
	dir = dir.Unit
	local right = dir:Cross(normal)
	if right.Magnitude < 0.05 then
		right = dir:Cross(Vector3.new(0, 0, -1))
	end
	right = right.Unit
	local back = right:Cross(dir).Unit
	local frame = CFrame.fromMatrix(root, right, dir, back)
	local lit = ctx.litFrame and ctx.litFrame(frame) or frame
	local color = e.color or colors.main
	ctx.cone("Head", lit, e.len, e.w, e.d or e.w * 0.62, color, e.dark or colors.mid, nil, "HairSpike")
	local tc = e.tipColor or colors.tip
	if tc then
		-- bout coloré : seulement la moitié tournée vers l'extérieur (2 pièces au lieu de 4 ; la
		-- moitié contre la tête ne se voit pas)
		local k = 0.42
		ctx.cone(
			"Head",
			lit * CFrame.new(0, e.len * (1 - k), 0),
			e.len * k + 0.01,
			e.w * k * 1.05,
			(e.d or e.w * 0.62) * k * 1.1,
			tc,
			tc:Lerp(Color3.new(0, 0, 0), 0.25),
			lit == frame and 1 or -1,
			"HairTip"
		)
	end
end

-- Calotte (et nuque) : volume lisse sous les mèches.
-- o = { nape (false : sans nuque), napeLength, napeColor, grow, lift }
function HairBuilder.cap(ctx, color: Color3, o)
	local opts = o or {}
	local grow = opts.grow or 0
	ctx.ball("Head", "HairCap", Vector3.new(CAP_R.X * 2 + grow, CAP_R.Y * 2 + grow * 0.5, CAP_R.Z * 2 + grow), CFrame.new(CAP_C + Vector3.new(0, opts.lift or 0, 0)), color)
	if opts.nape ~= false then
		local length = opts.napeLength or 1
		-- nuque « soignée » (look.napeTidy) : de la couleur des cheveux, jamais un pavé sombre
		local napeColor = ctx.napeTidy and ctx.napeTidy.color or opts.napeColor or color
		ctx.ball("Head", "HairNape", Vector3.new(1.28 + grow, length, 1.02), CFrame.new(0, 0.2 - length / 2, 0.22), napeColor)
	end
end

-- Teintes d'une coiffure : principale, dessous (ombre), reflet, bout (look.hairTip).
function HairBuilder.colors(c: Color3, look, hairTones): { [string]: Color3 }
	local under, shine = hairTones(c, look)
	local main = c
	if 0.3 * c.R + 0.59 * c.G + 0.11 * c.B < 0.16 then
		-- cheveux noirs : face éclairée des mèches bleu nuit, sinon une masse noire illisible
		main = c:Lerp(Color3.fromRGB(70, 84, 122), 0.5)
	end
	return {
		main = main,
		under = under,
		deep = deeper(under, 0.5),
		shine = shine,
		mid = main:Lerp(under, 0.55),
		tip = look.hairTip,
	}
end

-- Petit hasard déterministe (même coiffure à chaque construction).
local function rng(seed: number)
	local state = math.floor(seed) % 2147483646 + 1
	return function(lo: number, hi: number): number
		state = (state * 48271) % 2147483647
		return lo + (hi - lo) * (state / 2147483647)
	end
end
HairBuilder.rng = rng

-- Hasard ADOUCI (v3.4) : les écarts aléatoires réduits à 35 % autour de leur milieu. Des mèches
-- régulières et symétriques font une coiffure nette ; trop de hasard faisait « verre brisé ».
local function calmRng(seed: number)
	local raw = rng(seed)
	return function(lo: number, hi: number): number
		local mid = (lo + hi) / 2
		return mid + (raw(lo, hi) - mid) * 0.35
	end
end
HairBuilder.calmRng = calmRng

-- Point de la surface des mèches sur un méridien avant-arrière : décalage latéral x (studs),
-- angle t (degrés, 0 = sommet, négatif = vers le front, positif = vers la nuque ; au-delà de 90,
-- la mèche descend le long de la nuque). Sert aux cheveux plaqués vers l'arrière.
function HairBuilder.meridian(x: number, t: number, out: number?): (Vector3, Vector3)
	local o = out or 0
	local k = math.sqrt(math.max(0.05, 1 - (x / FLOW_R.X) ^ 2))
	if t <= 90 and t >= -90 then
		local r = rad(t)
		local normal = Vector3.new(x / (FLOW_R.X * FLOW_R.X), math.cos(r) * k / FLOW_R.Y, math.sin(r) * k / FLOW_R.Z).Unit
		local point = FLOW_C + Vector3.new(x, math.cos(r) * k * FLOW_R.Y, math.sin(r) * k * FLOW_R.Z) + normal * o
		return point, normal
	end
	local sgn = t > 0 and 1 or -1
	local normal = Vector3.new(x / FLOW_R.X * 0.4, 0, sgn).Unit
	local point = FLOW_C + Vector3.new(x, -(math.abs(t) - 90) / 90 * DROP, sgn * k * FLOW_R.Z) + normal * o
	return point, normal
end

-- Direction d'azimut a (degrés) et d'élévation e (degrés : 0 = vers l'extérieur à l'horizontale,
-- 90 = droit vers le haut).
local function dirOf(a: number, e: number): Vector3
	local ca, sa, ce, se = math.cos(rad(a)), math.sin(rad(a)), math.cos(rad(e)), math.sin(rad(e))
	return Vector3.new(sa * ce, se, -ca * ce)
end
HairBuilder.dirOf = dirOf

-- Mèche libre en losange (queue de cheval, mèche qui pend) : de `from` vers `to`, plus large à
-- `mid` (fraction), pyramides complètes (visible de tous les côtés).
function HairBuilder.tail(ctx, from: Vector3, to: Vector3, w: number, d: number, color: Color3, dark: Color3, o)
	local opts = o or {}
	local m = opts.mid or 0.3
	local mid = from:Lerp(to, m) + (opts.bulge or Vector3.zero)
	local function piece(a: Vector3, b: Vector3)
		local up = (b - a).Unit
		local ref = math.abs(up.Y) < 0.9 and Vector3.new(0, 1, 0) or Vector3.new(1, 0, 0)
		local right = up:Cross(ref).Unit
		local back = right:Cross(up).Unit
		local frame = CFrame.fromMatrix(a, right, up, back)
		local lit = ctx.litFrame and ctx.litFrame(frame) or frame
		ctx.cone("Head", lit, (b - a).Magnitude, w, d, color, dark, nil, opts.name or "HairTail")
	end
	piece(mid, from)
	piece(mid, to)
end

-- MÈCHE LISSE (cheveux longs et lisses, v3.4) : un ovale allongé couché sur la surface des
-- mèches, de (a0, h0) à (a1, h1), terminé par une petite pointe (demi-pyramide) : peu de pièces et
-- pas de facettes, comme les cheveux en maillage des modèles de la boutique.
-- e = { a0, h0, a1, h1, w, d, out, lift, tip (longueur de la pointe), color, tipColor, name }
function HairBuilder.smoothLock(ctx, e, colors)
	local p0, n0 = HairBuilder.surface(e.a0, e.h0, e.out or 0.02)
	local p1, n1 = HairBuilder.surface(e.a1, e.h1, (e.out or 0.02) + (e.lift or 0))
	local axis = p1 - p0
	local up = axis.Unit
	local outward = (n0 + n1).Unit
	local right = up:Cross(outward)
	if right.Magnitude < 0.05 then
		right = Vector3.new(1, 0, 0)
	end
	right = right.Unit
	local back = right:Cross(up).Unit
	if back:Dot(outward) < 0 then
		right = -right
		back = -back
	end
	local w = e.w or 0.4
	local d = e.d or 0.22
	local color = e.color or colors.main
	ctx.ball("Head", e.name or "HairLock", Vector3.new(w, axis.Magnitude + w * 0.4, d), CFrame.fromMatrix((p0 + p1) / 2, right, up, back), color)
	local tip = e.tip or 0
	if tip > 0 then
		local frame = CFrame.fromMatrix(p1 - up * (w * 0.1), right, up, back)
		local lit = ctx.litFrame and ctx.litFrame(frame) or frame
		local tc = e.tipColor or colors.tip or color
		ctx.cone("Head", lit, tip + w * 0.1, w * 0.78, d * 0.9, tc, ctx.shadeOf and ctx.shadeOf(tc) or colors.mid, nil, "HairTip")
	end
end

-- Chignon (boule de cheveux + attache) en `at` (repère de la tête).
function HairBuilder.bun(ctx, at: Vector3, size: number, color: Color3, tie: Color3?)
	ctx.ball("Head", "HairBun", Vector3.new(size, size * 0.9, size), CFrame.new(at), color)
	ctx.ball("Head", "HairBunShine", Vector3.new(size * 0.35, size * 0.3, size * 0.2), CFrame.new(at + Vector3.new(size * 0.18, size * 0.22, -size * 0.32)), color:Lerp(WHITE, 0.3))
	if tie then
		ctx.vcyl("Head", "HairTie", size * 0.18, size * 0.55, CFrame.new(at - Vector3.new(0, size * 0.42, 0)), tie)
	end
end

-- Couronne de PIQUES (coiffures dressées) : liste de { azimut, hauteur de racine, élévation,
-- longueur, largeur, couleur? } ; `lean` = Vector3 ajouté à toutes les directions (coiffure
-- couchée d'un côté), `scale` multiplie les longueurs.
function HairBuilder.spikes(ctx, colors, list, o)
	local opts = o or {}
	for _, e in list do
		local dir = (dirOf(e[1], e[3]) + (opts.lean or Vector3.zero)).Unit
		HairBuilder.spike(ctx, {
			a = e[1],
			h = e[2],
			len = e[4] * (opts.scale or 1),
			w = e[5],
			d = e[5] * (opts.depth or 0.62),
			dir = dir,
			color = e[6] or colors.main,
			dark = opts.dark or colors.mid,
		}, colors)
	end
end

-- Mèches plaquées vers l'arrière : `n` losanges sur des méridiens (x de -spread à +spread), du
-- front (angle t0, négatif) jusqu'à la nuque (t1).
function HairBuilder.slicked(ctx, colors, o, rand)
	local n = o.n or 6
	local spread = o.spread or 0.5
	-- bandeau lisse sur le haut du front (sinon le coin du crâne se voit entre les mèches)
	ctx.ball("Head", "HairFront", Vector3.new(1.22, 0.3, 0.5), CFrame.new(0, 0.55, -0.27), colors.mid)
	for i = 1, n do
		local t = n == 1 and 0 or (i - 1) / (n - 1) * 2 - 1
		local x = t * spread
		local r0, n0 = HairBuilder.meridian(x * 0.8, o.t0 or -62, (o.out or 0.02) - 0.02)
		local rm, nm = HairBuilder.meridian(x, (o.tm or 30) + rand(-6, 6), o.out or 0.02)
		local r1, n1 = HairBuilder.meridian(x * 1.05, (o.t1 or 120) + rand(-8, 8), (o.out or 0.02) + (o.lift or 0.04))
		local w = (o.w or 0.34) * (1 + rand(-0.08, 0.08))
		local depth = (o.d or 0.1) * 2
		local color = (i % 2 == 0) and colors.main:Lerp(colors.shine, 0.18) or colors.main
		local function half(a: Vector3, b: Vector3, normal: Vector3, length: number)
			local up = (b - a).Unit
			local right = up:Cross(normal)
			right = right.Magnitude > 0.05 and right.Unit or Vector3.new(1, 0, 0)
			local back = right:Cross(up).Unit
			if back:Dot(normal) < 0 then
				right = -right
				back = -back
			end
			ctx.cone("Head", CFrame.fromMatrix(a, right, up, back), length, w, depth, color, colors.mid, 1, "HairLock")
		end
		half(rm, r0, (n0 + nm).Unit, (r0 - rm).Magnitude + 0.04)
		half(rm, r1, (nm + n1).Unit, (r1 - rm).Magnitude + (o.tip or 0.14))
	end
end

------------------------------------------------------------------------
-- Coiffures
------------------------------------------------------------------------

local function seedOf(c: Color3, style: string): number
	local n = math.floor(c.R * 255) * 65536 + math.floor(c.G * 255) * 256 + math.floor(c.B * 255)
	for i = 1, #style do
		n = (n * 31 + string.byte(style, i)) % 2147483646
	end
	return n
end
HairBuilder.seedOf = seedOf

local Styles = {}
HairBuilder.Styles = Styles

local function has(look, accessory: string): boolean
	for _, a in look.accessories or {} do
		if a == accessory then
			return true
		end
	end
	return false
end

local function headband(look): boolean
	return has(look, "headband") or has(look, "headband_tilted") or has(look, "headband_scratched")
end

-- Cheveux SOUS UN CHAPEAU (Loffy, Usupp...) : pas de calotte (le chapeau couvre le dessus), nuque
-- et côtés en mèches, frange en bataille sous le bord ; pattes peintes au lieu des mèches de côté
-- sous une casquette (look.sideburns).
function HairBuilder.underHat(ctx, c: Color3, look, hairTones)
	local colors, rand = HairBuilder.colors(c, look, hairTones), calmRng(seedOf(c, "underHat"))
	-- nuque « soignée » (look.napeTidy) : de la couleur des cheveux
	ctx.ball("Head", "HairNape", Vector3.new(1.3, 0.75, 1.0), CFrame.new(0, -0.05, 0.24), ctx.napeTidy and ctx.napeTidy.color or colors.mid)
	HairBuilder.ring(ctx, colors, {
		n = 12,
		h0 = 0.62,
		front = 1,
		side = 1.4,
		back = 1.7,
		tip = 0.16,
		twist = 8,
		lift = 0.1,
		alternate = 0.12,
		skip = function(a)
			return math.abs(a) < 55
		end,
	}, rand)
	if not look.sideburns then
		HairBuilder.sides(ctx, colors, { n = 1, a = 72, h0 = 0.6, h1 = 1.45, w = 0.32, tip = 0.16, lift = 0.06 }, rand)
	end
	HairBuilder.bangs(ctx, colors, { n = 5, h0 = 0.6, h1 = 0.95, w = 0.32, spread = 48, tip = 0.14, fan = 20, lift = 0.06, jitter = 0.08 }, rand)
end

-- Préparation commune : teintes, hasard (adouci), longueur (look.hairLength).
local function setup(c: Color3, look, hairTones, name: string)
	return HairBuilder.colors(c, look, hairTones), calmRng(seedOf(c, name)), look.hairLength or 1
end

-- Courte (Yuzi, Zoru, Nanamo...) : couronne de mèches couchées (front au-dessus des sourcils,
-- tempes, nuque courte), frange en pointes par-dessus.
Styles.short = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "short")
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.8, napeColor = colors.under })
	HairBuilder.ring(ctx, colors, { n = 14, front = 0.82, side = 1.38, back = 1.7 + 0.3 * (L - 1), tip = 0.14, twist = 5, lift = 0.07 }, rand)
	HairBuilder.sides(ctx, colors, { n = 1, a = 74, h1 = 1.55, w = 0.32, tip = 0.14 }, rand)
	HairBuilder.bangs(ctx, colors, { n = 5, h0 = 0.36, h1 = 0.9, w = 0.34, spread = 46, tip = 0.1, fan = 8, vshape = 0.08, lift = 0.04 }, rand)
end

-- En bataille (Loffy, Ase, Yamcho...) : mèches de longueurs inégales qui rebiquent, frange
-- croisée, quelques épis sur le dessus.
Styles.messy = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "messy")
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.85, napeColor = colors.under })
	HairBuilder.ring(ctx, colors, { n = 14, front = 0.85, side = 1.4, back = 1.75 + 0.3 * (L - 1), tip = 0.2, twist = 12, lift = 0.13, alternate = 0.2 }, rand)
	HairBuilder.sides(ctx, colors, { n = 1, a = 76, h1 = 1.55, w = 0.32, tip = 0.18, lift = 0.08, curl = 0.3 }, rand)
	HairBuilder.bangs(ctx, colors, { n = 5, h0 = 0.34, h1 = 0.92, w = 0.33, spread = 48, tip = 0.14, fan = 22, vshape = 0.06, lift = 0.07, jitter = 0.1 }, rand)
	HairBuilder.spikes(ctx, colors, {
		{ 25, 0.22, 48, 0.42, 0.32 },
		{ -40, 0.25, 42, 0.38, 0.3 },
		{ 150, 0.3, 35, 0.4, 0.32, colors.mid },
		{ -120, 0.32, 38, 0.36, 0.3 },
	})
end

-- Tignasse en pointes (Maruto, Tanjiru, Zenitso...) : piques larges qui rayonnent au-dessus du
-- front (au-dessus du bandeau s'il y en a un), deuxième rang en quinconce, nuque en pointes.
Styles.spiky = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "spiky")
	local band = headband(look)
	-- bouts d'une autre couleur (Zenitso) : un peu moins de piques, plus larges (budget de pièces)
	local tipped = colors.tip ~= nil
	local ringN, topN, wide = tipped and 8 or 10, tipped and 4 or 6, tipped and 1.15 or 1
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.9, napeColor = colors.mid, grow = 0.04 })
	local list = {}
	for i = 0, ringN - 1 do
		local a = -150 + i * 300 / (ringN - 1) + rand(-6, 6)
		local front = math.abs(a) < 60
		table.insert(list, {
			a,
			front and 0.42 or 0.5,
			front and 32 or 18,
			(front and 0.62 or 0.7) * L + rand(-0.06, 0.08),
			0.5 * wide,
			i % 3 == 0 and colors.main:Lerp(colors.shine, 0.2) or nil,
		})
	end
	for i = 0, topN - 1 do
		local a = -150 + i * 300 / (topN - 1) + rand(-8, 8)
		table.insert(list, { a, 0.18, 48, 0.6 * L + rand(-0.05, 0.08), 0.52 * wide })
	end
	HairBuilder.spikes(ctx, colors, list)
	-- nuque : pointes couchées vers le bas
	HairBuilder.back(ctx, colors, { n = tipped and 4 or 6, spread = 78, h0 = 0.7, h1 = band and 1.75 or 1.85, w = 0.48 * wide, tip = 0.16, lift = 0.08 }, rand)
	if band then
		-- deux petites pointes qui retombent sur le bandeau, et les mèches des tempes
		HairBuilder.bangs(ctx, colors, { n = 3, h0 = 0.25, h1 = 0.62, w = 0.36, spread = 34, tip = 0.14, fan = 18, lift = 0.1 }, rand)
		HairBuilder.sides(ctx, colors, { n = 1, a = 80, h0 = 0.45, h1 = 1.35, w = 0.32, tip = 0.16, lift = 0.06 }, rand)
	else
		HairBuilder.bangs(
			ctx,
			colors,
			{ n = tipped and 4 or 5, h0 = 0.3, h1 = 0.9, w = tipped and 0.42 or 0.36, spread = 50, tip = 0.16, fan = 16, vshape = 0.05, lift = 0.06 },
			rand
		)
		HairBuilder.sides(ctx, colors, { n = 1, a = 78, h1 = 1.5, w = 0.32, tip = 0.16, lift = 0.06 }, rand)
	end
end

-- Grandes pointes dressées (Kakashu, Goju, Akazo...) : volume haut, couché d'un côté
-- (look.hairTilt), frange en pointes.
Styles.wild = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "wild")
	local lean = Vector3.new(look.hairTilt or 0.25, 0, 0.15)
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.85, napeColor = colors.under, grow = 0.04 })
	HairBuilder.ring(ctx, colors, { n = 12, front = 0.8, side = 1.3, back = 1.6, tip = 0.16, twist = 8, lift = 0.1 }, rand)
	local list = {}
	for i = 0, 8 do
		local a = -160 + i * 40 + rand(-6, 6)
		table.insert(list, { a, 0.3, 55 + rand(-8, 8), (0.8 + rand(-0.08, 0.12)) * L, 0.5, i % 3 == 1 and colors.main:Lerp(colors.shine, 0.2) or nil })
	end
	table.insert(list, { 10, 0.08, 75, 0.85 * L, 0.55 })
	table.insert(list, { 170, 0.12, 68, 0.8 * L, 0.55, colors.mid })
	HairBuilder.spikes(ctx, colors, list, { lean = lean })
	HairBuilder.bangs(ctx, colors, { n = 4, h0 = 0.3, h1 = 0.88, w = 0.38, spread = 42, tip = 0.16, fan = 14, lift = 0.06 }, rand)
end

-- Longs cheveux lisses (Sakoura, Hinato, Nezoko...) : mèches qui encadrent le visage jusqu'à la
-- mâchoire, nappe dans le dos (look.hairLength), frange (droite si look.bangs = "blunt").
Styles.long = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "long")
	local back = 2.2 + 1.1 * L
	HairBuilder.cap(ctx, colors.main, { napeLength = 1.1, napeColor = colors.main })
	-- nappe LISSE dans le dos (cheveux d'un seul tenant) et longues mèches lisses par-dessus : peu
	-- de pièces, pas de facettes ; seules les pointes du bas et la frange sont anguleuses
	local hem = FLOW_C.Y - (back - 1) * DROP
	local top = 0.4
	ctx.ball("Head", "HairCurtain", Vector3.new(1.46, top - hem, 0.56), CFrame.new(0, (top + hem) / 2, 0.55), colors.main)
	local deep = colors.main:Lerp(colors.mid, 0.5)
	for _, sx in { -1, 1 } do
		-- mèche qui encadre le visage (devant l'oreille) jusqu'au menton
		HairBuilder.smoothLock(ctx, { a0 = sx * 60, h0 = 0.4, a1 = sx * 66, h1 = 1.95, w = 0.4, d = 0.24, out = 0.03, tip = 0.2 }, colors)
		-- côté et arrière du côté
		HairBuilder.smoothLock(ctx, { a0 = sx * 98, h0 = 0.5, a1 = sx * 104, h1 = back - 0.25, w = 0.52, d = 0.3, out = 0.0, tip = 0.22, color = deep }, colors)
		HairBuilder.smoothLock(ctx, { a0 = sx * 140, h0 = 0.55, a1 = sx * 146, h1 = back - 0.1, w = 0.66, d = 0.2, out = 0.02, tip = 0.24 }, colors)
	end
	HairBuilder.smoothLock(ctx, { a0 = 180, h0 = 0.6, a1 = 180, h1 = back, w = 0.7, d = 0.2, out = 0.03, tip = 0.26, color = deep }, colors)
	-- frange sans bout coloré (Nezoko : bouts orangés seulement au bas des longueurs)
	local plain = table.clone(colors)
	plain.tip = nil
	if look.bangs == "blunt" then
		HairBuilder.bangs(ctx, plain, { n = 6, h0 = 0.34, h1 = 0.88, w = 0.3, spread = 50, tip = 0.05, fan = 4, jitter = 0, lift = 0.02 }, rand)
	elseif not headband(look) then
		-- raie au milieu : 4 mèches symétriques qui s'écartent du centre (avec un bandeau sur la
		-- tête, front dégagé : seules les longues mèches encadrent le visage, comme Sakoura)
		HairBuilder.bangs(ctx, plain, { n = 4, h0 = 0.32, h1 = 0.88, w = 0.42, spread = 40, tip = 0.08, fan = 10, jitter = 0, lift = 0.03 }, rand)
	end
	local _ = L
end

-- Carré (Nobora, Shinobo, C81...) : volume arrondi jusqu'au menton, bouts qui rentrent vers le
-- cou, frange effilée.
Styles.bob = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "bob")
	local hem = 1.72 + 0.2 * (L - 1)
	HairBuilder.cap(ctx, colors.main, { napeLength = 1.0, napeColor = colors.under, grow = 0.03 })
	-- avec un bandeau sur la tête (Sakoura ★2) : front dégagé, rien par-dessus le bandeau
	local band = headband(look)
	HairBuilder.ring(ctx, colors, {
		n = 15,
		front = 0.82,
		side = hem,
		back = hem + 0.05,
		tip = 0.1,
		twist = 3,
		lift = 0.0,
		alternate = 0.04,
		skip = band and function(a)
			return math.abs(a) < 48
		end or nil,
	}, rand)
	HairBuilder.sides(ctx, colors, { n = 2, a = 66, gap = 20, h0 = 0.45, h1 = hem, step = 0, w = 0.36, tip = 0.1, lift = -0.01 }, rand)
	if not band then
		HairBuilder.bangs(ctx, colors, { n = 5, h0 = 0.34, h1 = 0.9, w = 0.34, spread = 50, tip = 0.1, fan = 6, part = 10, sweep = 6 }, rand)
	end
end

-- Queue de cheval (Mako, Yoriichu, Giyo...) : cheveux tirés vers la nuque, attache, longue queue
-- qui pend dans le dos (look.hairLength).
local function ponytail(ctx, colors, at: Vector3, length: number, w: number, tie: Color3?, outward: Vector3?)
	local dir = (Vector3.new(0, -1, 0) + (outward or Vector3.new(0, 0, 0.35))).Unit
	local from = at + Vector3.new(0, 0.02, 0)
	HairBuilder.tail(ctx, from, from + dir * length, w, w * 0.8, colors.main, colors.mid, { mid = 0.25 })
	HairBuilder.tail(ctx, from + dir * 0.1, from + dir * length * 0.8 + Vector3.new(0.08, 0, 0.05), w * 0.7, w * 0.55, colors.mid, colors.under, { mid = 0.3 })
	ctx.vcyl("Head", "HairTie", 0.14, w * 0.7, CFrame.new(from) * CFrame.Angles(math.rad(-25), 0, 0), tie or colors.deep)
end
HairBuilder.ponytail = ponytail

Styles.ponytail = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "ponytail")
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.7, napeColor = colors.under })
	HairBuilder.ring(ctx, colors, { n = 14, front = 0.8, side = 1.32, back = 1.25, tip = 0.1, twist = 4, lift = 0.02 }, rand)
	HairBuilder.sides(ctx, colors, { n = 1, a = 72, h0 = 0.45, h1 = 1.6, w = 0.3, tip = 0.14, lift = 0.03 }, rand)
	HairBuilder.bangs(ctx, colors, { n = 4, h0 = 0.34, h1 = 0.9, w = 0.36, spread = 42, tip = 0.12, fan = 12, vshape = 0.05 }, rand)
	local tie = HairBuilder.surface(180, 0.85, 0.05)
	ponytail(ctx, colors, tie, 1.3 * L, 0.42, look.hairTieColor)
end

-- Crinière lourde (Brolo, Radama, Kaydo) : gros volume qui tombe jusqu'aux épaules et dans le dos
-- (jamais devant le visage), frange à épis sur les yeux.
Styles.heavy_long = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "heavy_long")
	local back = 2.4 + 0.8 * L
	HairBuilder.cap(ctx, colors.main, { napeLength = 1.2, napeColor = colors.main, grow = 0.08 })
	-- masse lisse dans le dos (crinière d'un seul tenant) : moins de mèches, plus larges
	local hem = FLOW_C.Y - (back - 1) * DROP
	ctx.ball("Head", "HairCurtain", Vector3.new(1.6, 0.4 - hem, 0.66), CFrame.new(0, (0.4 + hem) / 2, 0.58), colors.main:Lerp(colors.mid, 0.3))
	HairBuilder.ring(ctx, colors, {
		n = 9,
		offset = 20,
		front = 0.8,
		side = 1.9,
		back = back,
		w = 0.66,
		tip = 0.22,
		twist = 6,
		lift = 0.16,
		alternate = 0.1,
		skip = function(a)
			return math.abs(a) < 45
		end,
	}, rand)
	HairBuilder.back(ctx, colors, { n = 4, spread = 70, h0 = 0.8, h1 = back + 0.2, w = 0.66, tip = 0.24, lift = 0.18, round = 0.4 }, rand)
	HairBuilder.sides(ctx, colors, { n = 1, a = 76, h0 = 0.4, h1 = 1.95, w = 0.46, tip = 0.2, lift = 0.1 }, rand)
	HairBuilder.bangs(ctx, colors, { n = 4, h0 = 0.3, h1 = 0.98, w = 0.46, spread = 48, tip = 0.18, fan = 18, vshape = 0.08, lift = 0.08, jitter = 0.08 }, rand)
end

-- Mèches longues à raie au milieu (Itochi, Robine) : longues mèches qui encadrent le visage
-- jusqu'au menton, volume sur la nuque, petite queue basse.
Styles.long_bangs = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "long_bangs")
	HairBuilder.cap(ctx, colors.main, { napeLength = 1.0, napeColor = colors.under })
	HairBuilder.ring(ctx, colors, { n = 14, front = 0.78, side = 1.85, back = 1.9 + 0.4 * (L - 1), tip = 0.14, twist = 4, lift = 0.05 }, rand)
	HairBuilder.sides(ctx, colors, { n = 2, a = 52, gap = 18, h0 = 0.35, h1 = 1.98, step = -0.15, w = 0.36, tip = 0.16, lift = 0.04 }, rand)
	HairBuilder.bangs(ctx, colors, { n = 2, h0 = 0.3, h1 = 0.95, w = 0.3, spread = 20, tip = 0.12, fan = 10, part = 0 }, rand)
	local tie = HairBuilder.surface(180, 1.45, 0.06)
	ponytail(ctx, colors, tie, 0.85 * L, 0.32, nil, Vector3.new(0, 0, 0.2))
end

-- Guerrier au grand cœur (Goko, Gojita) : frange en fourche, grosses pointes en éventail vers
-- l'arrière et les côtés (palmier vu de face), une pointe sur le dessus, nuque courte.
Styles.goku = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "goku")
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.9, napeColor = colors.under, grow = 0.05 })
	local sh = colors.main:Lerp(colors.shine, 0.22)
	HairBuilder.spikes(ctx, colors, {
		-- éventail : côtés (presque à l'horizontale) puis arrière
		{ -95, 0.45, 18, 0.85, 0.58 },
		{ 95, 0.45, 18, 0.85, 0.58, sh },
		{ -130, 0.4, 28, 0.95, 0.6, sh },
		{ 130, 0.4, 28, 0.95, 0.6 },
		{ -160, 0.38, 22, 0.9, 0.6 },
		{ 160, 0.38, 22, 0.9, 0.6, colors.mid },
		{ 180, 0.55, 5, 0.75, 0.58, colors.mid },
		-- dessus : une grande pointe dressée vers l'arrière
		{ 160, 0.1, 62, 0.9, 0.62, sh },
		{ -60, 0.25, 45, 0.7, 0.55 },
		{ 60, 0.25, 45, 0.7, 0.55 },
	}, { scale = L })
	-- frange : fourche au milieu, mèche longue côté gauche de l'écran, petite à droite
	HairBuilder.diamond(ctx, { a0 = -6, h0 = 0.3, am = -10, hm = 0.62, a1 = -24, h1 = 1.0, w = 0.42, d = 0.12, out = 0.06, lift = 0.08, over = 0.18 }, colors)
	HairBuilder.diamond(ctx, { a0 = 6, h0 = 0.3, am = 10, hm = 0.62, a1 = 20, h1 = 0.95, w = 0.4, d = 0.12, out = 0.06, lift = 0.08, over = 0.16, color = sh }, colors)
	HairBuilder.diamond(ctx, { a0 = -30, h0 = 0.35, am = -40, hm = 0.65, a1 = -50, h1 = 1.05, w = 0.38, d = 0.12, out = 0.05, lift = 0.06, over = 0.16 }, colors)
	HairBuilder.diamond(ctx, { a0 = 34, h0 = 0.35, am = 40, hm = 0.62, a1 = 46, h1 = 0.9, w = 0.36, d = 0.12, out = 0.05, lift = 0.06, over = 0.12 }, colors)
	HairBuilder.sides(ctx, colors, { n = 1, a = 78, h0 = 0.5, h1 = 1.4, w = 0.34, tip = 0.14, lift = 0.06 }, rand)
	HairBuilder.back(ctx, colors, { n = 3, spread = 40, h0 = 0.85, h1 = 1.75, w = 0.46, tip = 0.14, lift = 0.06 }, rand)
end

-- Mèche qui cache un œil (Sanjo, Yuuto).
Styles.cover_eye = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "cover_eye")
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.85, napeColor = colors.under })
	HairBuilder.ring(ctx, colors, { n = 14, front = 0.8, side = 1.45, back = 1.75 + 0.3 * (L - 1), tip = 0.12, twist = 5, lift = 0.05 }, rand)
	HairBuilder.sides(ctx, colors, { n = 1, a = 76, h1 = 1.55, w = 0.32, tip = 0.14 }, rand)
	-- la grande mèche (côté gauche de l'écran) qui couvre l'œil, et une plus petite dessous
	HairBuilder.diamond(ctx, { a0 = 10, h0 = 0.28, am = -12, hm = 0.75, a1 = -24, h1 = 1.3, w = 0.52, d = 0.12, out = 0.07, lift = 0.05, over = 0.16 }, colors)
	HairBuilder.diamond(
		ctx,
		{ a0 = -10, h0 = 0.34, am = -30, hm = 0.85, a1 = -38, h1 = 1.35, w = 0.42, d = 0.11, out = 0.06, lift = 0.04, over = 0.14, color = colors.main:Lerp(colors.shine, 0.18) },
		colors
	)
	HairBuilder.bangs(ctx, colors, { n = 2, h0 = 0.36, h1 = 0.85, w = 0.32, spread = 16, part = 34, tip = 0.1, fan = 8 }, rand)
end

-- Plaqués en arrière (Doma, Tengan).
Styles.slick = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "slick")
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.9 + 0.3 * (L - 1), napeColor = colors.under })
	HairBuilder.slicked(ctx, colors, { n = 7, spread = 0.52, t0 = -60, tm = 25, t1 = 110 + 25 * (L - 1), w = 0.36, tip = 0.16 }, rand)
	HairBuilder.ring(ctx, colors, {
		n = 10,
		offset = 18,
		skip = function(a)
			return math.abs(((a + 180) % 360) - 180) < 60
		end,
		front = 1,
		side = 1.35,
		back = 1.7 + 0.4 * (L - 1),
		tip = 0.12,
		twist = 4,
		lift = 0.04,
		h0 = 0.4,
	}, rand)
end

-- Dressés vers le haut et l'arrière, côtés sombres (Sukana).
Styles.slick_up = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "slick_up")
	HairBuilder.cap(ctx, colors.under, { napeLength = 0.75 })
	HairBuilder.ring(ctx, colors, {
		n = 12,
		front = 0.7,
		side = 1.15,
		back = 1.4,
		tip = 0.08,
		twist = 3,
		lift = 0.0,
		skip = function(a)
			return math.abs(a) < 50
		end,
	}, rand)
	local list = {}
	for i = 0, 6 do
		local x = -45 + i * 15
		table.insert(
			list,
			{ x + rand(-3, 3), 0.42 + math.abs(x) / 200, 58 + rand(-6, 6), (0.62 + rand(-0.05, 0.08)) * L, 0.42, i % 2 == 0 and colors.main:Lerp(colors.shine, 0.2) or nil }
		)
	end
	for i = 0, 4 do
		table.insert(list, { 130 + i * 25, 0.25, 40, 0.55 * L, 0.45, colors.mid })
	end
	HairBuilder.spikes(ctx, colors, list, { lean = Vector3.new(0, 0.2, 0.55) })
end

-- Coupe au bol nette et brillante (Rokli) : frange droite au ras des sourcils.
Styles.bowl = function(ctx, c: Color3, look, hairTones)
	local colors, rand = setup(c, look, hairTones, "bowl")
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.9, napeColor = colors.main, grow = 0.04 })
	HairBuilder.ring(ctx, colors, { n = 18, front = 0.98, side = 1.55, back = 1.6, tip = 0.03, twist = 0, lift = 0.01, alternate = 0 }, function()
		return 0
	end)
	-- reflet en bandeau
	ctx.ball("Head", "HairShine", Vector3.new(0.9, 0.12, 0.2), CFrame.new(0, 0.62, -0.48) * CFrame.Angles(math.rad(-40), 0, 0), colors.shine)
	local _ = rand
end

-- Queue d'ananas (Shikamaro) : tiré en arrière, touffe en pointes en éventail.
Styles.ponytail_spiky = function(ctx, c: Color3, look, hairTones)
	local colors, rand = setup(c, look, hairTones, "ponytail_spiky")
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.75, napeColor = colors.under })
	HairBuilder.slicked(ctx, colors, { n = 7, spread = 0.5, t0 = -68, tm = 18, t1 = 75, w = 0.38, tip = 0.04 }, rand)
	HairBuilder.sides(ctx, colors, { n = 1, a = 82, h0 = 0.5, h1 = 1.4, w = 0.3, tip = 0.12 }, rand)
	local tie = HairBuilder.surface(180, 0.45, 0.04)
	ctx.vcyl("Head", "HairTie", 0.12, 0.3, CFrame.new(tie) * CFrame.Angles(math.rad(60), 0, 0), colors.deep)
	for i, e in { { -50, 0.5 }, { -20, 0.62 }, { 10, 0.66 }, { 38, 0.58 }, { 62, 0.48 } } do
		local dir = (Vector3.new(math.sin(math.rad(e[1])) * 0.9, 0.75, 0.6)).Unit
		local root = tie + Vector3.new(0, 0.02, 0.02)
		local frame = CFrame.fromMatrix(root, dir:Cross(Vector3.new(0, 0, 1)).Unit, dir, dir:Cross(Vector3.new(0, 0, 1)).Unit:Cross(dir).Unit)
		local lit = ctx.litFrame and ctx.litFrame(frame) or frame
		ctx.cone("Head", lit, e[2], 0.3, 0.2, i % 2 == 0 and colors.main:Lerp(colors.shine, 0.2) or colors.main, colors.mid, nil, "HairSpike")
	end
end

-- Mèches qui encadrent le visage + pointes dressées vers l'arrière (Sasuki).
Styles.spiky_back = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "spiky_back")
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.8, napeColor = colors.under, grow = 0.03 })
	HairBuilder.ring(ctx, colors, {
		n = 12,
		front = 0.8,
		side = 1.4,
		back = 1.5,
		tip = 0.12,
		twist = 5,
		lift = 0.05,
		skip = function(a)
			return math.abs(((a + 180) % 360) - 180) > 120
		end,
	}, rand)
	HairBuilder.sides(ctx, colors, { n = 1, a = 60, h0 = 0.38, h1 = 1.95, w = 0.38, tip = 0.16, lift = 0.05 }, rand)
	HairBuilder.bangs(ctx, colors, { n = 3, h0 = 0.32, h1 = 0.95, w = 0.38, spread = 30, tip = 0.14, fan = 16, vshape = 0.08 }, rand)
	local list = {}
	for i = 0, 6 do
		local a = 125 + i * 18.3 + rand(-4, 4)
		table.insert(list, { a, 0.35 + (i % 2) * 0.25, 30 + (i % 2) * 15, (0.75 + rand(-0.06, 0.1)) * L, 0.5, i % 2 == 0 and colors.mid or nil })
	end
	HairBuilder.spikes(ctx, colors, list)
end

-- Cheveux courts tirés en chignon haut (Toudo).
Styles.topknot = function(ctx, c: Color3, look, hairTones)
	local colors, rand = setup(c, look, hairTones, "topknot")
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.7, napeColor = colors.under })
	HairBuilder.slicked(ctx, colors, { n = 8, spread = 0.54, t0 = -64, tm = 10, t1 = 62, w = 0.4, tip = 0.03 }, rand)
	HairBuilder.ring(ctx, colors, {
		n = 10,
		offset = 18,
		front = 1,
		side = 1.25,
		back = 1.35,
		tip = 0.08,
		twist = 3,
		lift = 0.02,
		h0 = 0.45,
		skip = function(a)
			return math.abs(a) < 60
		end,
	}, rand)
	HairBuilder.bun(ctx, Vector3.new(0, 0.8, 0.22), 0.42, colors.main, colors.deep)
end

-- Hérisson en boule (Megumo) : pointes moyennes dans tous les sens, frange de 3 pointes.
Styles.hedgehog = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "hedgehog")
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.9, napeColor = colors.under, grow = 0.06 })
	local list = {}
	for i = 0, 9 do
		local a = -162 + i * 36 + rand(-6, 6)
		table.insert(list, { a, 0.5, 30 + rand(-5, 8), (0.5 + rand(-0.04, 0.07)) * L, 0.46, i % 3 == 0 and colors.mid or nil })
	end
	for i = 0, 5 do
		local a = -150 + i * 60 + rand(-8, 8)
		table.insert(list, { a, 0.22, 45 + rand(-8, 8), (0.55 + rand(-0.05, 0.08)) * L, 0.46, i % 2 == 0 and colors.main:Lerp(colors.shine, 0.2) or nil })
	end
	table.insert(list, { 180, 0.95, -25, 0.5 * L, 0.42, colors.mid })
	HairBuilder.spikes(ctx, colors, list)
	HairBuilder.bangs(ctx, colors, { n = 3, h0 = 0.3, h1 = 0.88, w = 0.38, spread = 30, tip = 0.16, fan = 14, lift = 0.08 }, rand)
end

-- Prince guerrier (Vejeta) : front dégagé en « V » avec tempes dégarnies, grande flamme qui monte
-- en s'évasant (éventail de piques, plus hautes au milieu), deuxième couche plus sombre derrière.
Styles.flame = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "flame")
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.8, napeColor = colors.mid })
	HairBuilder.ring(ctx, colors, {
		n = 10,
		offset = 18,
		front = 0.65,
		side = 1.05,
		back = 1.3,
		w = 0.6,
		tip = 0.06,
		twist = 0,
		lift = 0.02,
		alternate = 0,
		h0 = 0.5,
		skip = function(a)
			return math.abs(a) < 40
		end,
	}, rand)
	-- petit volume au pied de la flamme (bouche les trous entre les piques, ne dépasse pas)
	ctx.ball("Head", "HairFlame", Vector3.new(0.85, 0.6, 0.8), CFrame.new(0, 0.72, 0.2), colors.main)
	-- flamme en trois étages symétriques : haute et droite au centre, de plus en plus courte et
	-- ouverte sur les côtés ; rang arrière plus sombre
	local shine = colors.main:Lerp(colors.shine, 0.22)
	local list = {
		{ 0, 0.04, 88, 1.15 * L, 0.56, shine },
		{ -22, 0.1, 80, 1.02 * L, 0.54 },
		{ 22, 0.1, 80, 1.02 * L, 0.54 },
		{ -46, 0.2, 70, 0.86 * L, 0.52, shine },
		{ 46, 0.2, 70, 0.86 * L, 0.52, shine },
		{ -72, 0.3, 58, 0.7 * L, 0.5 },
		{ 72, 0.3, 58, 0.7 * L, 0.5 },
		{ -100, 0.38, 46, 0.56 * L, 0.48 },
		{ 100, 0.38, 46, 0.56 * L, 0.48 },
		{ 180, 0.12, 82, 1.05 * L, 0.58, colors.mid },
		{ -145, 0.18, 74, 0.92 * L, 0.56, colors.mid },
		{ 145, 0.18, 74, 0.92 * L, 0.56, colors.mid },
	}
	HairBuilder.spikes(ctx, colors, list, { lean = Vector3.new(0, 0, 0.1), depth = 0.7 })
	-- pointe en « V » au milieu du front, deux petites mèches aux tempes (front dégagé)
	HairBuilder.diamond(ctx, { a0 = 0, h0 = 0.25, am = 0, hm = 0.55, a1 = 0, h1 = 0.88, w = 0.38, d = 0.1, out = 0.05, lift = 0.02, over = 0.14 }, colors)
	for _, sx in { -1, 1 } do
		HairBuilder.diamond(ctx, { a0 = sx * 30, h0 = 0.3, am = sx * 36, hm = 0.52, a1 = sx * 42, h1 = 0.74, w = 0.32, d = 0.1, out = 0.04, lift = 0.02, over = 0.08 }, colors)
	end
end

-- Courts en bataille, raie sur le côté (Gaaro) : la frange part d'un seul côté et laisse l'autre
-- moitié du front dégagée (marque du front visible).
Styles.parted = function(ctx, c: Color3, look, hairTones)
	local colors, rand = setup(c, look, hairTones, "parted")
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.85, napeColor = colors.mid, grow = 0.04 })
	HairBuilder.ring(ctx, colors, {
		n = 12,
		front = 0.8,
		side = 1.35,
		back = 1.6,
		w = 0.52,
		tip = 0.16,
		twist = 6,
		lift = 0.1,
		alternate = 0.1,
		skip = function(a)
			return a > -55 and a < 15
		end,
	}, rand)
	HairBuilder.bangs(ctx, colors, { n = 3, h0 = 0.3, h1 = 0.84, w = 0.4, spread = 22, part = 34, tip = 0.14, fan = 14, lift = 0.06, jitter = 0.04 }, rand)
	-- deux mèches dressées sur le dessus, en bataille
	HairBuilder.spikes(ctx, colors, {
		{ -20, 0.12, 52, 0.42, 0.46 },
		{ 150, 0.16, 46, 0.42, 0.46, colors.mid },
	})
end

-- Ébouriffés et plats (Gohon) : volume bas, une grande mèche unique sur le front.
Styles.tousled = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "tousled")
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.85, napeColor = colors.under })
	HairBuilder.ring(ctx, colors, { n = 14, front = 0.8, side = 1.4, back = 1.7, tip = 0.16, twist = 14, lift = 0.1, alternate = 0.12 }, rand)
	HairBuilder.diamond(ctx, { a0 = 8, h0 = 0.25, am = -8, hm = 0.65, a1 = -22, h1 = 1.08, w = 0.5, d = 0.12, out = 0.07, lift = 0.08, over = 0.2 }, colors)
	HairBuilder.bangs(ctx, colors, { n = 2, h0 = 0.38, h1 = 0.8, w = 0.3, spread = 20, part = 36, tip = 0.1, fan = 10 }, rand)
	local _ = L
end

-- Tignasse bouclée (Usupp) : grosses boucles rondes tout autour.
Styles.curly = function(ctx, c: Color3, look, hairTones)
	local colors, rand = setup(c, look, hairTones, "curly")
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.95, napeColor = colors.under, grow = 0.1 })
	local k = 0
	for row, h in { 0.22, 0.55, 0.9, 1.25 } do
		local n = ({ 5, 9, 11, 9 })[row]
		for i = 1, n do
			local a = (i - 1) * 360 / n + row * 17 + rand(-6, 6)
			local front = math.abs(((a + 180) % 360) - 180) < (row >= 3 and 70 or 0)
			if not front then
				k += 1
				local p, nrm = HairBuilder.surface(a, h, 0.02)
				local size = 0.36 + rand(-0.04, 0.06)
				ctx.ball("Head", "HairCurl", Vector3.new(size, size, size * 0.85), CFrame.lookAt(p, p + nrm), k % 3 == 0 and colors.mid or colors.main)
			end
		end
	end
	HairBuilder.bangs(ctx, colors, { n = 3, h0 = 0.38, h1 = 0.82, w = 0.36, spread = 34, tip = 0.08, fan = 10 }, rand)
end

-- Crête iroquoise (Genyo) : côtés rasés, haute crête de pointes de l'avant à l'arrière.
Styles.mohawk = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "mohawk")
	-- côtés rasés (crâne nu) : seule la crête dépasse
	for i = 0, 6 do
		local t = -50 + i * 26
		local root, nrm = HairBuilder.meridian(0, t, -0.06)
		local dir = (nrm + Vector3.new(0, 0.3, 0.25 * (t / 90))).Unit
		local right = Vector3.new(1, 0, 0)
		local back = right:Cross(dir).Unit
		local frame = CFrame.fromMatrix(root, right, dir, back)
		local len = (0.62 + (i == 2 and 0.15 or 0) + rand(-0.05, 0.08)) * L
		ctx.cone("Head", frame, len, 0.22, 0.5, i % 2 == 0 and colors.main or colors.main:Lerp(colors.shine, 0.2), colors.mid, nil, "HairSpike")
	end
	HairBuilder.diamond(ctx, { a0 = 0, h0 = 0.3, am = 4, hm = 0.6, a1 = 10, h1 = 0.88, w = 0.26, d = 0.1, out = 0.04, lift = 0.04, over = 0.12 }, colors)
end

-- Queue de cheval sur le côté (Kanoa).
Styles.side_ponytail = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "side_ponytail")
	HairBuilder.cap(ctx, colors.main, { napeLength = 0.85, napeColor = colors.under })
	HairBuilder.ring(ctx, colors, { n = 14, front = 0.8, side = 1.5, back = 1.6, tip = 0.12, twist = 4, lift = 0.04 }, rand)
	HairBuilder.bangs(ctx, colors, { n = 5, h0 = 0.34, h1 = 0.9, w = 0.34, spread = 48, tip = 0.1, fan = 8, vshape = 0.05 }, rand)
	local tie = HairBuilder.surface(110, 0.62, 0.05)
	ponytail(ctx, colors, tie, 1.0 * L, 0.36, look.hairTieColor, Vector3.new(0.45, 0, 0.2))
end

-- Crinière de flammes (Rengoko) : longues mèches dorées qui tombent jusqu'aux épaules, bouts
-- rouges seulement au bord (nuque, côtés, frange), volume du dessus balayé vers l'arrière.
Styles.flame_spiky = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "flame_spiky")
	HairBuilder.cap(ctx, colors.main, { napeLength = 1.15, napeColor = colors.main:Lerp(colors.mid, 0.4), grow = 0.08 })
	HairBuilder.ring(ctx, colors, {
		n = 10,
		front = 0.8,
		side = 1.75,
		back = 2.3 + 0.4 * (L - 1),
		w = 0.64,
		tip = 0.14,
		twist = 6,
		lift = 0.08,
		alternate = 0.08,
		skip = function(a)
			return math.abs(((a + 180) % 360) - 180) < 45
		end,
	}, rand)
	HairBuilder.back(ctx, colors, { n = 4, spread = 60, h0 = 0.8, h1 = 2.5 + 0.4 * (L - 1), w = 0.56, tip = 0.16, lift = 0.12, round = 0.3 }, rand)
	HairBuilder.sides(ctx, colors, { n = 1, a = 66, h0 = 0.35, h1 = 1.9, w = 0.42, tip = 0.16, lift = 0.08, curl = 0.25 }, rand)
	HairBuilder.bangs(ctx, colors, { n = 4, h0 = 0.28, h1 = 0.94, w = 0.46, spread = 48, tip = 0.14, fan = 12, vshape = 0.06, lift = 0.06 }, rand)
end

-- Grande crinière hérissée jusqu'aux reins (Jiriya) : front dégagé, deux longues mèches qui
-- encadrent le visage, rangées de pointes de plus en plus longues dans le dos.
Styles.mane = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "mane")
	HairBuilder.cap(ctx, colors.main, { napeLength = 1.2, napeColor = colors.under, grow = 0.06 })
	HairBuilder.ring(ctx, colors, {
		n = 12,
		front = 0.6,
		side = 1.6,
		back = 2.6,
		w = 0.48,
		tip = 0.22,
		twist = 8,
		lift = 0.16,
		alternate = 0.12,
		skip = function(a)
			return math.abs(a) < 45
		end,
	}, rand)
	for row, h in { 1.0, 1.8, 2.6 } do
		HairBuilder.back(ctx, colors, { n = 5, spread = 70 - row * 8, h0 = h - 0.45, h1 = h + 1.0 * L, w = 0.5, tip = 0.26, lift = 0.15 + row * 0.05, round = 0.2 }, rand)
	end
	HairBuilder.sides(ctx, colors, { n = 1, a = 56, h0 = 0.4, h1 = 2.05, w = 0.36, tip = 0.2, lift = 0.05 }, rand)
	HairBuilder.spikes(ctx, colors, {
		{ -25, 0.25, 60, 0.55, 0.44 },
		{ 25, 0.25, 60, 0.55, 0.44 },
		{ -90, 0.35, 40, 0.6, 0.46 },
		{ 90, 0.35, 40, 0.6, 0.46 },
		{ 180, 0.2, 45, 0.65, 0.5, colors.mid },
	}, { scale = L })
end

-- Demi-chignon (Kenjakou) : chignon rond haut sur l'arrière, le reste lâché jusqu'aux épaules,
-- longue mèche qui tombe sur le côté du front.
Styles.half_bun = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "half_bun")
	HairBuilder.cap(ctx, colors.main, { napeLength = 1.05, napeColor = colors.under })
	HairBuilder.slicked(ctx, colors, { n = 6, spread = 0.46, t0 = -58, tm = 15, t1 = 70, w = 0.34, tip = 0.04 }, rand)
	HairBuilder.ring(ctx, colors, {
		n = 11,
		offset = 16,
		front = 1,
		side = 1.85,
		back = 2.1 + 0.3 * (L - 1),
		tip = 0.14,
		twist = 4,
		lift = 0.06,
		h0 = 0.5,
		skip = function(a)
			return math.abs(a) < 55
		end,
	}, rand)
	HairBuilder.bun(ctx, Vector3.new(0, 0.62, 0.48), 0.44, colors.main, colors.deep)
	HairBuilder.diamond(ctx, { a0 = 30, h0 = 0.3, am = 42, hm = 0.85, a1 = 46, h1 = 1.55, w = 0.32, d = 0.1, out = 0.07, lift = 0.05, over = 0.16 }, colors)
end

-- Mi-long en bataille (guerrier légendaire) : frange à épis sur les yeux, pointes sur le dessus,
-- mèches épaisses jusqu'aux épaules.
Styles.wild_long = function(ctx, c: Color3, look, hairTones)
	local colors, rand, L = setup(c, look, hairTones, "wild_long")
	HairBuilder.cap(ctx, colors.main, { napeLength = 1.1, napeColor = colors.under, grow = 0.05 })
	HairBuilder.ring(ctx, colors, { n = 13, front = 0.82, side = 1.85, back = 2.2 + 0.4 * (L - 1), w = 0.46, tip = 0.2, twist = 10, lift = 0.14, alternate = 0.14 }, rand)
	HairBuilder.bangs(ctx, colors, { n = 5, h0 = 0.3, h1 = 0.98, w = 0.38, spread = 50, tip = 0.18, fan = 20, vshape = 0.08, lift = 0.08, jitter = 0.08 }, rand)
	HairBuilder.spikes(ctx, colors, {
		{ -50, 0.22, 50, 0.55, 0.42 },
		{ 40, 0.22, 52, 0.55, 0.42 },
		{ 170, 0.2, 45, 0.6, 0.46, colors.mid },
	}, { scale = L })
end

-- Très longue crinière dressée (super guerrier ★★★, look.hair = "ssj3" / "tall_spiky") : front
-- dégagé, grosses pointes dressées, immense crinière jusqu'au bas du dos.
local function giantMane(ctx, c: Color3, look, hairTones, name: string)
	local colors, rand, L = setup(c, look, hairTones, name)
	HairBuilder.cap(ctx, colors.main, { napeLength = 1.3, napeColor = colors.under, grow = 0.08 })
	HairBuilder.spikes(ctx, colors, {
		{ -40, 0.22, 60, 0.75, 0.52 },
		{ 40, 0.22, 60, 0.75, 0.52, colors.main:Lerp(colors.shine, 0.2) },
		{ -100, 0.4, 35, 0.8, 0.55 },
		{ 100, 0.4, 35, 0.8, 0.55 },
		{ 180, 0.15, 55, 0.8, 0.56, colors.mid },
	}, { scale = L })
	for row, h in { 0.9, 1.9, 2.9 } do
		HairBuilder.back(ctx, colors, { n = 6, spread = 85 - row * 10, h0 = h - 0.4, h1 = h + 1.3 * L, w = 0.56, tip = 0.3, lift = 0.18 + row * 0.06, round = 0.2 }, rand)
	end
	HairBuilder.sides(ctx, colors, { n = 2, a = 95, gap = 20, h0 = 0.5, h1 = 2.6, step = 0.2, w = 0.46, tip = 0.24, lift = 0.25 }, rand)
	HairBuilder.diamond(ctx, { a0 = 6, h0 = 0.3, am = 4, hm = 0.65, a1 = -6, h1 = 1.05, w = 0.36, d = 0.11, out = 0.06, lift = 0.06, over = 0.16 }, colors)
end
Styles.ssj3 = function(ctx, c: Color3, look, hairTones)
	giantMane(ctx, c, look, hairTones, "ssj3")
end
Styles.tall_spiky = function(ctx, c: Color3, look, hairTones)
	giantMane(ctx, c, look, hairTones, "tall_spiky")
end

return HairBuilder
