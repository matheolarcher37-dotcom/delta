-- Tous les personnages jouables et les ennemis.
-- Les noms sont légèrement modifiés (Naruto -> Maruto...) : change-les librement ici.
--
-- Apparence intégrée (avatar R6 "peint", utilisée si aucun avatar du catalogue n'est configuré) :
-- look = {
--   skin, hair (style), hairColor, hairTip?, eyes?, face? ("angry" | "calm" | "smirk" | "happy" | "fierce"),
--   top, topAccent?, bottom, shoes?, outfit? (voir Painter.luau : "jacket", "uniform", "gi", "suit"...),
--   logo? = { kind = "spiral" | "kanji" | "fan" | "circle", color, bg?, text?, back? },
--   eyeShadow?, blush?, bigBrows?, accessories = { ... }, accColor?, sleeveless?, shirtless?
--   Tenue peinte (v3, toutes les faces du torse, des bras et des jambes ; voir Painter.dress) :
--   shoulders? (épaules / empiècement), collar? ("fur"), collarColor?, sleeves? ("long" | "short" |
--   "skin" | "wide"), sleeveColor?, sleeveEnd?, cuffColor?, hemColor?, armWarmers?, armWarmerStraps?,
--   armband?, shoulderMark? (symbole sur l'épaule), shoulderMarkLeft?, waistband? (ceinture d'étoffe),
--   pants? ("long" | "shorts" | "kimono"), shortsLength?, hemBottom?, legWraps? (bandes des tibias),
--   legWrapTop?, legWrapStraps?, holster? (bandage + étui sur la cuisse), footwear? ("shoes" |
--   "sandals" | "zori" | "boots" | "barefoot"), bootTop?, bootTrim?, bootLace?, frontZip?,
--   collarButton?, chestScar?, pattern? ("asanoha"), patternColor?, obiCord?, obiBow?,
--   hairTilt?, hairUnder? (dessous des cheveux), hairShine? (reflets)
--   v3 classique (avatars R6 comme "Kid Naruto", voir CharacterBuilder) :
--   Visage : eyeX?, eyeY? (position des yeux, studs depuis le centre de la tête), eyeWidth?, eyeHeight?,
--     eyeScale?, pupil? ("bar" | "slit" | "ring" | "tomoe" | "none"), pupilColor?, scleraColor?,
--     lashColor?, lashThickness?, lashes? (cils longs), browColor?, browY?, mouthWidth?, mouthY?,
--     whiskerColor?, glassesColor?, scarSide? ("left"), face "sad" en plus.
--   Cheveux : hairLength? (taille des pointes / longueur), tailLength? (queue de cheval),
--     sidelockLength? (mèches de côté), forehead? (front dégagé, cheveux longs).
--   Bandeau : headbandY?, headbandRadius? (porté sur les cheveux), plateColor?.
--   Tenue : pantsStyle? ("plain" = sans les plis de la texture classique), holsterStyle? ("band" =
--     sangle de cuisse comme Kid Naruto), handTop? (début de la main sur le bras), sandalTop?,
--     collarColor?, collarLining? (col montant), maskColor?.
--   napeTidy? (nuque remontée dans les cheveux, de leur couleur, prolongée de petites mèches).
--   props? = objets sur mesure (voir plus bas et CharacterBuilder : buildProps).
-- }
-- Pour utiliser de vrais objets du catalogue Roblox (cheveux, vêtements, visage) : voir Config/Avatars.luau
-- attack = { kind = "punch" | "orb" | "beam" | "slash" | "lightning" | "flame" | "shadow" | "stretch" | "ice", color, name }
-- evolve = { [2] = changements du look, [3] = changements du look }  (optionnel, false = retirer)

local rgb = Color3.fromRGB

local SKIN = rgb(255, 216, 180)
local SKIN_TAN = rgb(226, 178, 138)

local Characters = {}

------------------------------------------------------------------------
-- Objets sur mesure des persos (look.props, voir CharacterBuilder : buildProps)
-- Repères : chaque membre a son centre en (0, 0, 0) ; l'avant du perso est -Z, le dos +Z ;
-- torse 2 x 2 x 1 (dos en z = 0.5), tête de rayon 0.6, main au bout du bras en y = -1.
------------------------------------------------------------------------

local V = Vector3.new
local METAL_DARK = rgb(58, 56, 66)
local GOLD = rgb(236, 190, 70)

-- Concatène plusieurs listes de pièces.
local function join(...)
	local out = {}
	for _, list in { ... } do
		for _, p in list do
			table.insert(out, p)
		end
	end
	return out
end

-- Chaîne de segments arrondis passant par des points (queue, fouet, chaîne).
local function chain(limb: string, points, widths, colors, extra)
	local out = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local w = widths[i] or widths[#widths]
		local d = (b - a).Unit
		local color = typeof(colors) == "Color3" and colors or (colors[i] or colors[#colors])
		table.insert(out, {
			shape = "ball",
			limb = limb,
			at = a - d * (w * 0.25),
			dir = d,
			size = V(w, (b - a).Magnitude + w * 0.5, w * ((extra and extra.flat) or 1)),
			color = color,
			material = extra and extra.material,
			transparency = extra and extra.transparency,
		})
	end
	return out
end

-- Tiges rigides (cylindres bout à bout, légèrement chevauchés) passant par des points : côtes,
-- arceaux, cornes fines. Plus lisibles que `chain` (ellipsoïdes) pour une structure osseuse.
local function rods(limb: string, points, diameters, color: Color3, extra)
	local out = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local w = diameters[i] or diameters[#diameters]
		local d = (b - a).Unit
		table.insert(out, {
			shape = "cyl",
			limb = limb,
			at = a - d * (w * 0.3),
			dir = d,
			size = V((b - a).Magnitude + w * 0.6, w, 0),
			color = color,
			material = extra and extra.material,
			transparency = extra and extra.transparency,
		})
	end
	return out
end

-- Deux vecteurs perpendiculaires à `d`.
local function across(d: Vector3)
	local ref = math.abs(d.Unit.Y) < 0.9 and V(0, 1, 0) or V(1, 0, 0)
	local a = d.Unit:Cross(ref).Unit
	return a, d.Unit:Cross(a).Unit
end

-- Massue à piques (kanabo) tenue en main : poignée, fût épais cerclé d'or, clous en losange.
local function kanabo(limb: string, from: Vector3, dir: Vector3, length: number, thick: number)
	local d = dir.Unit
	local out: { any } = {
		{ shape = "cyl", limb = limb, at = from - d * 0.3, dir = d, size = V(1.0, thick * 0.42, 0), color = rgb(92, 62, 40) },
		{ shape = "cyl", limb = limb, at = from + d * 0.6, dir = d, size = V(length - 0.6, thick, 0), color = METAL_DARK, material = "Metal" },
		{ shape = "ball", limb = limb, at = from + d * (length - 0.25), dir = d, size = V(thick * 1.02, 0.5, thick * 1.02), color = METAL_DARK, material = "Metal" },
	}
	for _, t in { 0.66, length - 0.05 } do
		table.insert(out, { shape = "cyl", limb = limb, at = from + d * t, dir = d, size = V(0.14, thick * 1.08, 0), color = GOLD, material = "Metal" })
	end
	local a, b = across(d)
	for i, t in { 1.3, 2.45 } do
		if t < length - 0.3 then
			for k, side in { a, b, -a, -b } do
				local off = (i % 2 == 0) and (side + (k % 2 == 0 and a or b)).Unit or side
				table.insert(out, {
					shape = "block",
					limb = limb,
					at = from + d * t + off * (thick * 0.5),
					dir = off,
					rot = V(0, 45, 0),
					size = V(0.17, 0.2, 0.17),
					color = rgb(196, 192, 200),
					material = "Metal",
				})
			end
		end
	end
	for _, p in out do
		p.name = "Kanabo"
	end
	return out
end

-- Grand éventail de guerre rond (gunbai) : disque crème cerclé de rouge, trois virgules noires.
local function gunbai(limb: string, center: Vector3, handleFrom: Vector3, facing: number?)
	local yaw = facing or 0
	local out = {
		{ shape = "cyl", limb = limb, at = handleFrom, dir = center - handleFrom, size = V((center - handleFrom).Magnitude - 0.7, 0.15, 0), color = rgb(70, 46, 34) },
		{ shape = "cyl", limb = limb, at = center, rot = V(0, 90 + yaw, 0), size = V(0.09, 1.95, 0), color = rgb(132, 34, 36) },
		{ shape = "cyl", limb = limb, at = center, rot = V(0, 90 + yaw, 0), size = V(0.12, 1.7, 0), color = rgb(236, 226, 200) },
		{ shape = "cyl", limb = limb, at = center, rot = V(0, 90 + yaw, 0), size = V(0.14, 0.34, 0), color = rgb(132, 34, 36) },
	}
	local back = CFrame.Angles(0, math.rad(yaw), 0):VectorToWorldSpace(V(0, 0, 1))
	for k = 0, 2 do
		local ang = math.rad(90 + k * 120)
		local side = CFrame.Angles(0, math.rad(yaw), 0):VectorToWorldSpace(V(math.cos(ang), math.sin(ang), 0))
		for _, s in { 1, -1 } do
			table.insert(out, {
				shape = "ball",
				limb = limb,
				at = center + side * 0.5 + back * (0.07 * s),
				size = V(0.3, 0.3, 0.03),
				color = rgb(26, 22, 28),
			})
		end
	end
	return out
end

-- Gourde de sable dans le dos (beige, deux renflements, bouchon), sangle portée en bandoulière.
local function gourd(color: Color3)
	return {
		{ shape = "ball", limb = "Torso", at = V(0.15, -0.3, 1.02), size = V(1.55, 1.45, 1.1), color = color },
		{ shape = "ball", limb = "Torso", at = V(0.22, 0.78, 0.94), size = V(1.0, 0.9, 0.82), color = color },
		{ shape = "cyl", limb = "Torso", at = V(0.26, 0.48, 0.96), rot = V(0, 0, 90), size = V(0.12, 0.92, 0), color = rgb(150, 70, 52) },
		{ shape = "cyl", limb = "Torso", at = V(0.27, 1.3, 0.92), rot = V(0, 0, 90), size = V(0.3, 0.36, 0), color = color },
		{ shape = "ball", limb = "Torso", at = V(0.27, 1.5, 0.92), size = V(0.42, 0.24, 0.42), color = rgb(120, 70, 46) },
		{ shape = "ball", limb = "Torso", at = V(-0.18, -0.1, 1.5), size = V(0.34, 0.24, 0.1), color = rgb(150, 70, 52) },
	}
end

-- Chapeau mou (fedora) : bord large, calotte pincée, ruban.
local function fedora(color: Color3, band: Color3)
	return {
		{ shape = "cyl", limb = "Head", at = V(0, 0.66, 0.04), rot = V(6, 0, 90), size = V(0.07, 2.05, 0), color = color },
		{ shape = "cyl", limb = "Head", at = V(0, 0.95, 0.07), rot = V(6, 0, 90), size = V(0.56, 1.34, 0), color = color },
		{ shape = "ball", limb = "Head", at = V(0, 1.22, 0.1), rot = V(6, 0, 0), size = V(1.34, 0.32, 1.34), color = color },
		{ shape = "block", limb = "Head", at = V(0, 1.34, 0.1), rot = V(6, 0, 0), size = V(0.16, 0.1, 0.86), color = color:Lerp(rgb(0, 0, 0), 0.18) },
		{ shape = "cyl", limb = "Head", at = V(0, 0.76, 0.05), rot = V(6, 0, 90), size = V(0.15, 1.37, 0), color = band },
	}
end

-- Bonnet tacheté du chirurgien : calotte blanche duveteuse, bord épais, taches brunes.
local function spottedHat()
	local white, spot = rgb(242, 240, 232), rgb(96, 72, 52)
	local out = {
		{ shape = "strand", limb = "Head", at = V(-0.6, 0.3, -0.12), dir = V(-0.1, -1, 0), length = 0.5, width = 0.16, depth = 0.1, color = rgb(26, 24, 30) },
		{ shape = "strand", limb = "Head", at = V(0.6, 0.3, -0.12), dir = V(0.1, -1, 0), length = 0.5, width = 0.16, depth = 0.1, color = rgb(26, 24, 30) },
		-- cheveux courts de la nuque : une seule plaque de la couleur des cheveux qui rentre dans le
		-- crâne (pas de fente), prolongée de 4 petites mèches
		{ shape = "ball", limb = "Head", at = V(0, 0.1, 0.4), size = V(1.22, 0.8, 0.56), color = rgb(26, 24, 30), name = "HairNape" },
		{ shape = "spike", limb = "Head", at = V(-0.39, -0.08, 0.56), dir = V(-0.12, -1, 0.3), length = 0.3, width = 0.34, color = rgb(26, 24, 30) },
		{ shape = "spike", limb = "Head", at = V(-0.13, -0.08, 0.56), dir = V(-0.04, -1, 0.3), length = 0.3, width = 0.34, color = rgb(26, 24, 30) },
		{ shape = "spike", limb = "Head", at = V(0.13, -0.08, 0.56), dir = V(0.04, -1, 0.3), length = 0.3, width = 0.34, color = rgb(26, 24, 30) },
		{ shape = "spike", limb = "Head", at = V(0.39, -0.08, 0.56), dir = V(0.12, -1, 0.3), length = 0.3, width = 0.34, color = rgb(26, 24, 30) },
		{ shape = "ball", limb = "Head", at = V(0, 0.62, 0.03), size = V(1.42, 1.06, 1.44), color = white },
		{ shape = "cyl", limb = "Head", at = V(0, 0.36, 0.03), rot = V(0, 0, 90), size = V(0.3, 1.5, 0), color = white:Lerp(rgb(0, 0, 0), 0.06) },
	}
	for _, s in { { 0.0, 0.93, -0.42 }, { -0.42, 0.78, -0.34 }, { 0.44, 0.74, -0.3 }, { 0.2, 1.06, 0.1 }, { -0.5, 0.66, 0.36 }, { 0.36, 0.7, 0.5 } } do
		table.insert(out, { shape = "ball", limb = "Head", at = V(s[1], s[2], s[3]), size = V(0.26, 0.2, 0.26), color = spot })
	end
	for _, x in { -0.5, 0, 0.5 } do
		table.insert(out, { shape = "ball", limb = "Head", at = V(x, 0.36, -0.72), size = V(0.2, 0.2, 0.08), color = spot })
	end
	return out
end

-- Jolly Roger souriant (équipage du chirurgien) sur la poitrine : disque, os croisés, sourire.
local function smileyRoger(face: Color3)
	local ink = rgb(22, 20, 24)
	local z = -0.5
	return {
		{ shape = "block", limb = "Torso", at = V(0, 0.25, z - 0.02), rot = V(0, 0, 40), size = V(0.12, 1.3, 0.03), color = ink },
		{ shape = "block", limb = "Torso", at = V(0, 0.25, z - 0.02), rot = V(0, 0, -40), size = V(0.12, 1.3, 0.03), color = ink },
		{ shape = "cyl", limb = "Torso", at = V(0, 0.25, z - 0.03), rot = V(0, 90, 0), size = V(0.05, 0.8, 0), color = ink },
		{ shape = "cyl", limb = "Torso", at = V(0, 0.25, z - 0.05), rot = V(0, 90, 0), size = V(0.05, 0.62, 0), color = face },
		{ shape = "ball", limb = "Torso", at = V(-0.11, 0.33, z - 0.08), size = V(0.07, 0.12, 0.03), color = ink },
		{ shape = "ball", limb = "Torso", at = V(0.11, 0.33, z - 0.08), size = V(0.07, 0.12, 0.03), color = ink },
		{ shape = "ball", limb = "Torso", at = V(0, 0.15, z - 0.08), size = V(0.34, 0.12, 0.03), color = ink },
		{ shape = "ball", limb = "Torso", at = V(0, 0.19, z - 0.09), size = V(0.3, 0.07, 0.03), color = face },
	}
end

-- Tambours du dieu de la foudre : anneau doré dans le dos portant `n` tambours (4 au ★1, 6 au ★2+),
-- `arcs` = arcs électriques bleus (zigzags néon) qui sautent d'un tambour à l'autre.
local function drumRing(n: number?, arcs: boolean?)
	local count = n or 4
	local out = {}
	local center, r = V(0, 0.35, 0.95), 1.25
	for k = 0, 7 do
		local a0, a1 = k * math.pi / 4, (k + 1) * math.pi / 4
		local p0 = center + V(math.cos(a0) * r, math.sin(a0) * r, 0)
		local p1 = center + V(math.cos(a1) * r, math.sin(a1) * r, 0)
		table.insert(out, { shape = "cyl", limb = "Torso", at = p0, dir = p1 - p0, size = V((p1 - p0).Magnitude + 0.08, 0.12, 0), color = rgb(240, 180, 60), material = "Metal" })
	end
	local drums = {}
	for k = 0, count - 1 do
		local a = math.pi / 2 + (k + 0.5) * 2 * math.pi / count
		local at = center + V(math.cos(a) * r, math.sin(a) * r, 0.05)
		drums[k + 1] = at
		table.insert(out, { shape = "cyl", limb = "Torso", at = at, rot = V(0, 90, 0), size = V(0.36, 0.66, 0), color = rgb(226, 120, 40) })
		table.insert(out, { shape = "cyl", limb = "Torso", at = at + V(0, 0, 0.12), rot = V(0, 90, 0), size = V(0.14, 0.5, 0), color = rgb(250, 236, 200) })
	end
	if arcs then
		for k = 1, count do
			local a, b = drums[k], drums[k % count + 1]
			local mid = (a + b) / 2
			local out2 = (mid - center).Unit
			local zig = { a + V(0, 0, 0.15), mid + out2 * 0.38 + V(0, 0, 0.22), b + V(0, 0, 0.15) }
			for _, p in rods("Torso", zig, { 0.07 }, rgb(160, 220, 255), { material = "Neon", transparency = 0.05 }) do
				table.insert(out, p)
			end
		end
	end
	return out
end

-- Couperet du pilier du son : lame large au biseau clair, anneau au talon de la lame, garde
-- dorée, poignée blanche enroulée de deux bandes sombres, pommeau doré.
local function cleaver(limb: string, guard: Vector3, dir: Vector3, roll: number?)
	local d = dir.Unit
	local turn = V(0, roll or 0, 0)
	local steel = { color = rgb(150, 152, 166), material = "Metal" }
	return {
		{ shape = "block", limb = limb, at = guard, dir = d, rot = turn, size = V(0.66, 2.3, 0.07), color = steel.color, material = steel.material },
		{ shape = "block", limb = limb, at = guard, dir = d, rot = turn, shift = V(0.27, 0.04, 0), size = V(0.14, 2.24, 0.09), color = rgb(228, 232, 240), material = "Metal" },
		{ shape = "ball", limb = limb, at = guard, dir = d, rot = turn, shift = V(-0.16, 0.12, 0), size = V(0.42, 0.42, 0.1), color = GOLD, material = "Metal" },
		{ shape = "ball", limb = limb, at = guard, dir = d, rot = turn, shift = V(-0.16, 0.12, 0), size = V(0.22, 0.22, 0.12), color = rgb(30, 28, 34) },
		{ shape = "cyl", limb = limb, at = guard - d * 0.06, dir = d, size = V(0.12, 0.62, 0), color = GOLD, material = "Metal" },
		{ shape = "cyl", limb = limb, at = guard - d * 0.8, dir = d, size = V(0.75, 0.2, 0), color = rgb(236, 232, 222) },
		{ shape = "cyl", limb = limb, at = guard - d * 0.36, dir = d, size = V(0.08, 0.23, 0), color = rgb(40, 34, 40) },
		{ shape = "cyl", limb = limb, at = guard - d * 0.62, dir = d, size = V(0.08, 0.23, 0), color = rgb(40, 34, 40) },
		{ shape = "cyl", limb = limb, at = guard - d * 0.98, dir = d, size = V(0.16, 0.3, 0), color = GOLD, material = "Metal" },
	}
end

-- Les deux couperets croisés dans le dos, reliés par une chaîne entre les pommeaux.
local function crossedCleavers()
	local ga, gb = V(0.52, 0.55, 0.62), V(-0.52, 0.55, 0.62)
	local da, db = V(-0.55, -1, 0.05), V(0.55, -1, 0.05)
	local pa, pb = ga - da.Unit * 1.05, gb - db.Unit * 1.05
	local mid = (pa + pb) / 2 + V(0, -0.35, 0.12)
	return join(
		cleaver("Torso", ga, da),
		cleaver("Torso", gb, db),
		chain("Torso", { pa, (pa + mid) / 2 + V(0, -0.08, 0), mid, (pb + mid) / 2 + V(0, -0.08, 0), pb }, { 0.13 }, rgb(196, 170, 90), { material = "Metal" })
	)
end

-- Bandeau à gemmes (pilier du son) : bande argentée, gemmes rouges et bleues.
local function gemHeadband()
	local out = {
		-- bandeau métallique : bande autour de la tête + plaque frontale
		{ shape = "cyl", limb = "Head", at = V(0, 0.42, 0.02), rot = V(0, 0, 90), size = V(0.2, 1.42, 0), color = rgb(206, 206, 216), material = "Metal", name = "GemBand" },
		{ shape = "block", limb = "Head", at = V(0, 0.42, -0.7), size = V(0.78, 0.24, 0.06), color = rgb(220, 220, 230), material = "Metal", name = "GemBand" },
	}
	-- gemmes : petits losanges en néon (rouge au centre, bleues, vertes sur les côtés)
	for i, g in
		{
			{ 0, -0.74, rgb(235, 40, 70) },
			{ -0.27, -0.72, rgb(60, 140, 255) },
			{ 0.27, -0.72, rgb(60, 140, 255) },
			{ -0.6, -0.4, rgb(60, 220, 120) },
			{ 0.6, -0.4, rgb(60, 220, 120) },
		}
	do
		table.insert(out, {
			shape = "block",
			limb = "Head",
			cf = CFrame.new(g[1], 0.42, g[2]) * CFrame.Angles(0, math.atan2(g[1], -g[2]), 0) * CFrame.Angles(0, 0, math.rad(45)),
			size = i == 1 and V(0.18, 0.18, 0.06) or V(0.13, 0.13, 0.06),
			color = g[3],
			material = "Neon",
			name = "Gem",
		})
	end
	return out
end

-- Mèches plates posées SUR le crâne (coins couchés sur la calotte) : `phi` = angle depuis le
-- sommet, `a` = angle autour de la tête (0 = devant), `back` = la pointe file vers l'arrière
-- (cheveux plaqués) au lieu de tomber.
local function headLock(phi: number, a: number, r: number, size: Vector3, color: Color3, name: string, back: boolean?, twist: number?)
	local ph, an = math.rad(phi), math.rad(a)
	local out = V(math.sin(ph) * math.sin(an), math.cos(ph), -math.sin(ph) * math.cos(an))
	local down = V(math.cos(ph) * math.sin(an), -math.sin(ph), -math.cos(ph) * math.cos(an))
	local side = V(math.cos(an), 0, math.sin(an))
	local tipDir = ((back and -down or down) + side * (twist or 0)).Unit
	local z = -tipDir
	local y = (out - z * out:Dot(z)).Unit
	return {
		shape = "wedge",
		limb = "Head",
		cf = CFrame.fromMatrix(V(0, 0.12, 0.02) + out * r, y:Cross(z), y, z),
		size = size,
		color = color,
		name = name,
	}
end
-- Tengan : cheveux blancs plaqués vers l'arrière, 4 mèches plates seulement (pas de hérisson)
local TENGAN_LOCKS = {}
for i, a in { -40, -14, 14, 40 } do
	table.insert(TENGAN_LOCKS, headLock(30, a, 0.78, V(0.36, 0.14, 0.95), i % 2 == 0 and rgb(255, 255, 255) or rgb(226, 226, 234), "TenganLock", true, a / 120))
end

-- Éventail doré (ouvert : baleines en éventail ; fermé : simple latte) tenu dans la main.
local function fan(limb: string, open: boolean, tint: Color3?)
	if not open then
		return { { shape = "block", limb = limb, at = V(0, -1.0, -0.35), rot = V(-60, 0, 0), size = V(0.16, 0.95, 0.2), color = GOLD, material = "Metal" } }
	end
	local out = {}
	local pivot = V(0, -1.15, -0.6)
	for k = -3, 3 do
		local a = math.rad(k * 20)
		table.insert(out, {
			shape = "block",
			limb = limb,
			at = pivot,
			dir = V(math.sin(a), math.cos(a), -0.15),
			size = V(0.4, 1.35, 0.04),
			color = k % 2 == 0 and GOLD or (tint or rgb(250, 220, 120)),
			material = k % 2 == 0 and "Metal" or "SmoothPlastic",
		})
	end
	return out
end

-- Kunai à trois branches (éclair jaune) tenu dans la main : poignée, lame en feuille, branches
-- latérales d'une seule pièce (3 pièces en tout).
local function kunai3(limb: string, pos: Vector3?, dir: Vector3?)
	local at, d = pos or V(0, -1.05, -0.2), (dir or V(0, -0.15, -1)).Unit
	return {
		{ shape = "cyl", limb = limb, at = at - d * 0.42, dir = d, size = V(0.5, 0.12, 0), color = rgb(30, 30, 34) },
		{ shape = "ball", limb = limb, at = at, dir = d, size = V(0.24, 0.85, 0.06), color = rgb(206, 206, 216), material = "Metal" },
		{ shape = "block", limb = limb, at = at + d * 0.12, rot = V(0, 0, 0), size = V(0.62, 0.08, 0.05), color = rgb(190, 190, 200), material = "Metal" },
	}
end

-- Kunais marqués lancés autour du perso (téléportation de l'éclair jaune), pointe vers le bas :
-- 2 pièces chacun (poignée sombre + lame en feuille), pour garder de la marge de pièces.
local MINATU_KUNAIS = {}
for _, k in { { -2.3, 1.2, -0.6, 25 }, { 2.7, 1.5, -0.8, -20 }, { -1.9, -1.6, -1.1, 10 } } do
	local a = math.rad(k[4])
	local at, d = V(k[1], k[2], k[3]), V(math.sin(a), -1, 0).Unit
	table.insert(MINATU_KUNAIS, { shape = "cyl", limb = "Torso", at = at - d * 0.45, dir = d, size = V(0.5, 0.12, 0), color = rgb(30, 30, 34) })
	table.insert(MINATU_KUNAIS, { shape = "ball", limb = "Torso", at = at, dir = d, size = V(0.26, 0.8, 0.06), color = rgb(206, 206, 216), material = "Metal" })
end

-- Katana dégainé tenu dans la main (lame, garde ronde, poignée tressée).
local function katanaInHand(limb: string, dir: Vector3, blade: Color3?, glow: boolean?)
	local at, d = V(0, -1.05, -0.15), dir.Unit
	return {
		{ shape = "cyl", limb = limb, at = at - d * 0.5, dir = d, size = V(0.62, 0.17, 0), color = rgb(30, 28, 34) },
		{ shape = "cyl", limb = limb, at = at + d * 0.1, dir = d, size = V(0.06, 0.4, 0), color = rgb(190, 170, 110), material = "Metal" },
		{
			shape = "block",
			limb = limb,
			at = at + d * 0.14,
			dir = d,
			size = V(0.05, 2.6, 0.16),
			color = blade or rgb(214, 220, 232),
			material = glow and "Neon" or "Metal",
		},
	}
end

-- Gants blancs épais (main entière) ou gros poignets.
local function cuffs(color: Color3, height: number, y: number)
	return {
		{ shape = "cyl", limb = "Left Arm", at = V(0, y, 0), rot = V(0, 0, 90), size = V(height, 1.14, 0), color = color },
		{ shape = "cyl", limb = "Right Arm", at = V(0, y, 0), rot = V(0, 0, 90), size = V(height, 1.14, 0), color = color },
	}
end

-- Carrure massive (colosses, formes ultimes) SANS les sphères « bulk » : deltoïdes intégrés au
-- sommet du bras (bloc arrondi de la couleur du bras, `k` = épaisseur) et trapèze large qui
-- monte du dos vers le cou (couleur du haut).
local function brawn(arm: Color3, top: Color3, k: number?)
	local m = k or 1
	local out = {}
	for _, side in { { "Left Arm", -1 }, { "Right Arm", 1 } } do
		table.insert(out, {
			shape = "rounded",
			limb = side[1],
			at = V(side[2] * 0.04 * m, 0.66, 0),
			size = V(1.08 * m, 0.7, 1.08 * m),
			radius = 0.24,
			color = arm,
			name = "Deltoid",
		})
	end
	table.insert(out, { shape = "wedge", limb = "Torso", at = V(0, 1.15, 0.2), rot = V(0, 180, 0), size = V(1.6, 0.4, 0.56), color = top, name = "Trapezius" })
	return out
end

-- Toja : t-shirt noir moulant (petits deltoïdes intégrés au bras, plis de tissu tendu peints sur
-- le torse) ; ★2 : le ver-arsenal enroulé en travers du torse, de la hanche à l'épaule.
local TOJA_SHIRT = {
	{ shape = "ball", limb = "Left Arm", at = V(-0.06, 0.66, 0), size = V(1.12, 0.72, 1.1), color = rgb(30, 30, 36) },
	{ shape = "ball", limb = "Right Arm", at = V(0.06, 0.66, 0), size = V(1.12, 0.72, 1.1), color = rgb(30, 30, 36) },
	{
		shape = "block",
		limb = "Torso",
		at = V(0, 0, -0.505),
		size = V(2, 2, 0.02),
		color = rgb(30, 30, 36),
		paint = {
			kind = "strokes",
			faces = { "Front" },
			bg = false,
			ink = rgb(62, 62, 74),
			lines = {
				{ 0.1, 0.36, 0.47, 0.44, 0.05 },
				{ 0.53, 0.44, 0.9, 0.36, 0.05 },
				{ 0.5, 0.46, 0.5, 0.92, 0.035 },
				{ 0.18, 0.58, 0.4, 0.72, 0.03 },
				{ 0.82, 0.58, 0.6, 0.72, 0.03 },
				{ 0.34, 0.8, 0.46, 0.84, 0.03 },
				{ 0.66, 0.8, 0.54, 0.84, 0.03 },
			},
		},
	},
}
local TOJA_WORM = join(
	chain(
		"Torso",
		{ V(-1.0, -0.75, -0.62), V(-1.2, -0.45, 0.2), V(-0.6, 0.0, 0.78), V(0.35, 0.5, 0.8), V(1.05, 0.95, 0.35), V(1.0, 1.25, -0.4) },
		{ 0.46, 0.44, 0.42, 0.4, 0.38 },
		{ rgb(130, 108, 160), rgb(106, 86, 136) }
	),
	{
		{ shape = "ball", limb = "Torso", at = V(0.98, 1.32, -0.62), size = V(0.6, 0.5, 0.62), color = rgb(150, 126, 180), name = "WormHead" },
		{ shape = "ball", limb = "Torso", at = V(0.98, 1.28, -0.92), size = V(0.36, 0.14, 0.12), color = rgb(40, 20, 40) },
	}
)

-- Pièces propres à chaque nouveau perso v3.2 ------------------------------------------------

-- Radama : crinière lourde (coiffure « heavy_long » : dessus arrondi couché vers l'arrière, mèches
-- qui retombent jusqu'à la taille) + l'épaisse mèche qui couvre l'œil droit jusqu'à la joue et
-- deux longues mèches en éventail dans le bas du dos.
local function RADAMA_MANE(c: Color3)
	local deep = c:Lerp(rgb(0, 0, 0), 0.25)
	return {
		{ shape = "strand", limb = "Head", at = V(0.22, 0.62, -0.7), dir = V(0.12, -1, -0.12), length = 1.0, width = 0.42, depth = 0.14, color = c },
		{ shape = "strand", limb = "Head", at = V(0.36, 0.5, -0.66), dir = V(0.2, -1, -0.05), length = 0.8, width = 0.26, depth = 0.12, color = deep },
		{ shape = "strand", limb = "Torso", at = V(-0.5, 1.2, 0.72), dir = V(-0.32, -1, 0.12), length = 2.4, width = 0.62, depth = 0.2, color = deep, noPreview = true },
		{ shape = "strand", limb = "Torso", at = V(0.5, 1.2, 0.72), dir = V(0.32, -1, 0.12), length = 2.4, width = 0.62, depth = 0.2, color = c, noPreview = true },
	}
end

-- Radama : armure lamellaire rouge (rangées de plaques lacées et rivetées) sur une sous-tenue
-- noire : plastron (le dos est caché par la crinière), tassettes jusqu'au-dessus des genoux, épaulières en 3 lamelles
-- empilées, protège-avant-bras (coudes et genoux noirs visibles).
local RADAMA_RED, RADAMA_INK, RADAMA_RIVET = rgb(150, 34, 40), rgb(44, 14, 20), rgb(214, 182, 120)
local function lamellar(rows: number, faces, extra)
	local paint = { kind = "lamellar", rows = rows, faces = faces, ink = RADAMA_INK, rivet = RADAMA_RIVET }
	for k, v in extra or {} do
		paint[k] = v
	end
	return paint
end
local RADAMA_ARMOR = {
	{ shape = "block", limb = "Torso", at = V(0, 0.08, -0.54), size = V(2.04, 1.5, 0.08), color = RADAMA_RED, paint = lamellar(4, { "Front" }) },
	-- Tassettes : jupe de lamelles fendue devant, qui s'arrête au-dessus des genoux
	{
		shape = "block",
		limb = "Torso",
		at = V(0, -1.55, 0),
		size = V(2.16, 1.1, 1.16),
		color = RADAMA_RED,
		paint = lamellar(3, { "Front", "Back" }, { slit = true, rim = RADAMA_INK, rivet = false }),
	},
	{ shape = "block", limb = "Torso", at = V(0, -0.94, 0), size = V(2.1, 0.16, 1.12), color = rgb(30, 26, 34) },
}
for _, side in { { "Left Arm", -1 }, { "Right Arm", 1 } } do
	local limb, s = side[1], side[2]
	-- épaulière : un seul bloc incliné peint de 3 rangées de lamelles (face et côté extérieur ;
	-- le dos, sous la crinière, reste uni : budget de peinture)
	table.insert(RADAMA_ARMOR, {
		shape = "block",
		limb = limb,
		at = V(s * 0.12, 0.84, 0),
		rot = V(0, 0, -s * 12),
		size = V(1.18, 0.66, 1.22),
		color = RADAMA_RED,
		paint = lamellar(3, { "Front", s < 0 and "Left" or "Right" }, { rivet = false }),
	})
	-- Protège-avant-bras rouge (le coude reste noir)
	table.insert(RADAMA_ARMOR, { shape = "block", limb = limb, at = V(0, -0.5, 0), size = V(1.08, 0.72, 1.08), color = RADAMA_RED })
end

-- Radama ★2 : Susanoo squelettique — un squelette géant spectral qui l'ENVELOPPE par derrière,
-- entièrement en blocs et en coins (aucune sphère, ni en jeu ni dans les menus) :
--   • colonne de vertèbres anguleuses CENTRÉE sur l'axe du torse, juste derrière le dos ;
--   • côtes en planches fines (coins effilés au bout), symétriques (4 de chaque côté), qui partent
--     de la colonne en descendant, contournent les bras par l'extérieur et s'enroulent vers
--     l'avant : de face, leurs pointes encadrent Radama des deux côtés ;
--   • crâne anguleux centré derrière la tête (boîte crânienne, arcade, orbites en coins sombres,
--     pommettes et mâchoire en coins, rangée de dents, cornes plates vers l'arrière).
local SUSANOO_BLUE = rgb(90, 130, 255)
local SUSANOO_LIT = rgb(150, 185, 255)
local SUSANOO_Z = 0.78 -- axe de la colonne : juste derrière le dos (dos du torse à +0.5)
local SUSANOO_RIBS = {
	{
		shape = "block",
		limb = "Torso",
		at = V(0, 0.3, SUSANOO_Z + 0.05),
		size = V(0.14, 3.3, 0.14),
		color = SUSANOO_LIT,
		material = "Neon",
		transparency = 0.2,
		light = SUSANOO_BLUE,
		lightRange = 10,
		flames = rgb(110, 160, 255),
		name = "SusanooSpine",
	},
}
-- vertèbres : blocs plats anguleux, plus larges en haut
for k = 0, 7 do
	table.insert(SUSANOO_RIBS, {
		shape = "block",
		limb = "Torso",
		at = V(0, 1.72 - k * 0.4, SUSANOO_Z),
		size = V(0.5 - k * 0.02, 0.22, 0.3),
		color = SUSANOO_LIT,
		material = "Neon",
		transparency = 0.2,
		name = "SusanooVertebra",
	})
end
-- Côtes : arcs d'ellipse (vue de dessus) centrés devant la colonne — de la colonne (θ = 8°) aux
-- pointes devant lui (θ = 124°), en dehors des bras ; chaque côte descend le long de l'arc.
local RIB_A, RIB_B, RIB_C = 3.1, 1.35, -0.45 -- demi-largeur, demi-profondeur, centre (z)
local RIB_T = { 8, 38, 68, 96, 124 }
local function ribPoint(s: number, y0: number, w: number, deg: number): Vector3
	local th = math.rad(deg)
	return V(s * RIB_A * w * math.sin(th), y0 - 0.8 * (deg / 124) ^ 1.25, RIB_C + RIB_B * math.cos(th))
end
for _, s in { -1, 1 } do
	for k, y0 in { 1.42, 0.86, 0.3, -0.26 } do
		local w = 1 - (k - 1) * 0.03
		for i = 1, #RIB_T - 1 do
			local a, b = ribPoint(s, y0, w, RIB_T[i]), ribPoint(s, y0, w, RIB_T[i + 1])
			local d = (b - a).Unit
			local up = (V(0, 1, 0) - d * d.Y).Unit
			local len = (b - a).Magnitude + 0.06
			local tip = i == #RIB_T - 1
			table.insert(SUSANOO_RIBS, {
				shape = tip and "wedge" or "block",
				limb = "Torso",
				-- planche : longueur le long de l'arc, hauteur verticale, 0.08 d'épaisseur ; la
				-- pointe est un coin qui s'effile vers l'avant
				cf = tip and CFrame.fromMatrix((a + b) / 2, up:Cross(-d), up, -d) or CFrame.fromMatrix((a + b) / 2, d, up),
				size = tip and V(0.08, 0.24, len) or V(len, 0.24 - i * 0.01, 0.08),
				color = i <= 2 and SUSANOO_LIT or SUSANOO_BLUE,
				material = "Neon",
				-- segments du dos (derrière lui) plus estompés : l'armure reste lisible à travers
				transparency = i <= 2 and 0.45 or 0.25,
				name = "SusanooRib",
			})
		end
	end
end
-- Crâne anguleux centré derrière la tête (repère de la tête, X = 0)
local SKULL_HOLE = rgb(20, 30, 90)
local SKULL_TEETH = rgb(205, 222, 255)
local function skullPart(name: string, shape: string, cf: CFrame, size: Vector3, color: Color3, transparency: number)
	table.insert(SUSANOO_RIBS, {
		shape = shape,
		limb = "Head",
		cf = cf,
		size = size,
		color = color,
		material = color == SKULL_HOLE and "SmoothPlastic" or "Neon",
		transparency = transparency,
		name = name,
	})
end
-- Le crâne est un peu plus haut que la tête : de face, son visage (arcade lumineuse, orbites en
-- coins sombres sous l'arcade, pommettes) se lit juste au-dessus des cheveux ; mâchoire et dents
-- derrière la tête (visibles de profil et de 3/4).
local SK_Y, SK_Z = 1.05, 0.35 -- hauteur du centre du crâne, plan du visage du crâne
-- boîte crânienne + calotte en biseau (coins sur les arêtes du dessus et de l'arrière)
skullPart("SusanooSkull", "block", CFrame.new(0, SK_Y, SK_Z + 0.8), V(1.9, 1.3, 1.6), SUSANOO_BLUE, 0.35)
for _, s in { -1, 1 } do
	skullPart("SusanooSkull", "wedge", CFrame.new(s * 0.62, SK_Y + 0.8, SK_Z + 0.8) * CFrame.Angles(0, math.rad(-s * 90), 0), V(1.6, 0.3, 0.66), SUSANOO_BLUE, 0.35)
end
skullPart("SusanooSkull", "block", CFrame.new(0, SK_Y + 0.8, SK_Z + 0.75), V(0.6, 0.3, 1.5), SUSANOO_BLUE, 0.35)
-- arcade sourcilière lumineuse en « V » froncé (deux barres qui descendent vers le nez), un peu
-- plus large que la boîte crânienne
for _, s in { -1, 1 } do
	skullPart("SusanooBrow", "block", CFrame.new(s * 0.52, SK_Y + 0.4, SK_Z - 0.04) * CFrame.Angles(0, 0, math.rad(s * 14)), V(1.08, 0.18, 0.3), SUSANOO_LIT, 0.15)
end
for _, s in { -1, 1 } do
	-- orbites : creux sombres anguleux sous l'arcade (coin intérieur plus bas, regard dur)
	skullPart("SusanooOrbit", "block", CFrame.new(s * 0.47, SK_Y + 0.13, SK_Z - 0.06) * CFrame.Angles(0, 0, math.rad(s * 12)), V(0.56, 0.3, 0.1), SKULL_HOLE, 0.1)
	-- pommettes en coins, de part et d'autre du haut de la tête
	skullPart("SusanooCheek", "wedge", CFrame.new(s * 0.98, SK_Y - 0.38, SK_Z + 0.25), V(0.3, 0.5, 0.8), SUSANOO_LIT, 0.3)
	-- cornes plates recourbées vers l'arrière
	table.insert(SUSANOO_RIBS, {
		shape = "wedge",
		limb = "Head",
		at = V(s * 0.8, SK_Y + 0.75, SK_Z + 1.25),
		dir = V(s * 0.3, 0.55, 1),
		size = V(0.16, 1.3, 0.5),
		color = SUSANOO_BLUE,
		material = "Neon",
		transparency = 0.3,
		name = "SusanooHorn",
	})
end
-- cavité nasale (coin sombre)
skullPart("SusanooNose", "wedge", CFrame.new(0, SK_Y - 0.16, SK_Z - 0.05) * CFrame.Angles(0, math.rad(90), math.pi), V(0.1, 0.26, 0.24), SKULL_HOLE, 0.1)
-- mâchoire en coin et rangée de dents (blocs clairs séparés), derrière la tête
skullPart("SusanooJaw", "wedge", CFrame.new(0, SK_Y - 0.95, SK_Z + 0.6) * CFrame.Angles(math.pi, 0, 0), V(1.6, 0.4, 1.1), SUSANOO_BLUE, 0.35)
for i = -2, 2 do
	skullPart("SusanooTooth", "block", CFrame.new(i * 0.24, SK_Y - 0.58, SK_Z + 0.02), V(0.17, 0.26, 0.1), SKULL_TEETH, 0.15)
end

local TRUTH_ORBS = {}
for k = 0, 5 do
	local a = math.rad(90 + k * 60)
	table.insert(TRUTH_ORBS, { shape = "ball", limb = "Torso", at = V(math.cos(a) * 1.55, 0.5 + math.sin(a) * 1.55, 1.2), size = V(0.5, 0.5, 0.5), color = rgb(18, 16, 24) })
end

-- Gaaro ★2/★3 : le sable SORT DE LA GOURDE (ouverture derrière l'épaule) et tourbillonne plus
-- bas, autour du bras droit et du flanc (jamais plus haut que l'épaule) : beaucoup de petits blocs
-- irréguliers en matériau Sable ocre (deux tons), tournés au hasard, avec des grains qui s'en
-- échappent (particules). Au ★3, le sable forme en plus un bouclier mural sur son côté gauche.
local SAND = rgb(194, 160, 100)
local SAND_DEEP = rgb(166, 130, 76)
local SAND_LIGHT = rgb(214, 184, 126)
-- pseudo-hasard déterministe (même rendu à chaque construction)
local function jitter(i: number, k: number): number
	local x = math.sin(i * 12.9898 + k * 78.233) * 43758.5453
	return (x - math.floor(x)) * 2 - 1
end
local function sandBlock(list, at: Vector3, size: number, i: number, name: string?)
	table.insert(list, {
		shape = "block",
		limb = "Torso",
		at = at,
		rot = V(jitter(i, 1) * 40, jitter(i, 2) * 60, jitter(i, 3) * 40),
		size = V(size * (1 + jitter(i, 4) * 0.25), size * (0.8 + jitter(i, 5) * 0.2), size * (1 + jitter(i, 6) * 0.2)),
		color = i % 3 == 0 and SAND_DEEP or (i % 3 == 1 and SAND or SAND_LIGHT),
		material = "Sand",
		name = name or "Sand",
	})
end
-- flot de sable le long d'un chemin : 3 petits blocs par segment (qui rapetissent vers le bout)
-- autour de la ligne, plus des grains isolés
local function sandStream(points, size0: number, seed: number)
	local out = {}
	local n = 0
	for i = 1, #points - 1 do
		local a0, a1 = points[i], points[i + 1]
		for k = 0, 2 do
			n += 1
			local t = k / 3
			local p = a0:Lerp(a1, t)
			local sz = size0 * (1 - (i - 1 + t) / #points * 0.55)
			local off = V(jitter(n + seed, 7), jitter(n + seed, 8), jitter(n + seed, 9)) * (sz * 0.45)
			sandBlock(out, p + off, sz, n + seed)
		end
		-- grain détaché
		n += 1
		sandBlock(out, a0:Lerp(a1, 0.5) + V(jitter(n + seed, 10), 0.2 + jitter(n + seed, 11) * 0.2, jitter(n + seed, 12)) * 0.45, 0.15, n + seed)
	end
	out[1].name = "SandWave"
	out[1].dust = SAND_LIGHT
	out[1].dustRate = 18
	return out
end
-- ★2 : de l'ouverture de la gourde (dos, derrière l'épaule droite), le sable descend en
-- tourbillon autour du bras droit, passe devant la main et revient sur la hanche
local SAND_SHIELD = sandStream({
	V(0.3, 1.28, 0.95),
	V(0.95, 1.2, 1.1),
	V(1.75, 0.8, 0.85),
	V(2.35, 0.25, 0.15),
	V(2.3, -0.35, -0.7),
	V(1.6, -0.8, -1.1),
	V(0.95, -1.15, -0.9),
}, 0.5, 0)
-- ★3 : bouclier mural de sable sur le côté gauche (blocs empilés en mur légèrement courbé vers
-- l'avant, arête du haut déchiquetée), alimenté par un flot qui part de la gourde
local SAND_WALL = sandStream({ V(0.3, 1.28, 0.95), V(-0.6, 1.25, 1.15), V(-1.6, 0.95, 0.85), V(-2.35, 0.7, 0.25) }, 0.45, 40)
do
	local n = 80
	for row = 0, 3 do
		for col = -1, 1 do
			n += 1
			local ang = math.rad(col * 22)
			local at = V(-2.45 + (1 - math.cos(ang)) * 1.6, -2.35 + row * 0.82, -0.35 + math.sin(ang) * 1.6)
			table.insert(SAND_WALL, {
				shape = "block",
				limb = "Torso",
				at = at + V(jitter(n, 1) * 0.06, jitter(n, 2) * 0.08, 0),
				rot = V(jitter(n, 3) * 6, 90 - col * 22 + jitter(n, 4) * 6, jitter(n, 5) * 6),
				size = V(0.78 + jitter(n, 6) * 0.1, 0.84, 0.34 + jitter(n, 7) * 0.06),
				color = (row + col) % 2 == 0 and SAND or SAND_DEEP,
				material = "Sand",
				name = "SandWall",
			})
		end
	end
	-- arête du haut déchiquetée : coins de hauteurs différentes
	for col = -1, 1 do
		n += 1
		local ang = math.rad(col * 22)
		table.insert(SAND_WALL, {
			shape = "wedge",
			limb = "Torso",
			at = V(-2.45 + (1 - math.cos(ang)) * 1.6, 0.72 + 0.1 * (col % 2), -0.35 + math.sin(ang) * 1.6),
			rot = V(0, 90 - col * 22 + (col == 0 and 180 or 0), 0),
			size = V(0.34, 0.45 + 0.2 * (col % 2), 0.8),
			color = SAND_LIGHT,
			material = "Sand",
			name = "SandWall",
		})
	end
end
-- Gaaro : cheveux rouge brique courts, en pointes courtes qui partent dans tous les sens depuis
-- tout le crâne (dessus, côtés, nuque), front dégagé côté gauche du perso (kanji peint).
local GAARO_RED = rgb(170, 40, 30)
local GAARO_LIT = rgb(214, 84, 62)
local GAARO_HAIR = {
	{ shape = "ball", limb = "Head", at = V(0, 0.42, 0.1), size = V(1.36, 0.96, 1.36), color = GAARO_RED, name = "HairCap" },
	{ shape = "ball", limb = "Head", at = V(0, 0.08, 0.3), size = V(1.28, 0.8, 0.86), color = rgb(140, 30, 26), name = "HairNape" },
}
for i, m in
	{
		-- front : deux pointes à droite du perso et une petite au centre (le côté gauche reste dégagé)
		{ V(0.32, 0.72, -0.5), V(0.45, 0.1, -1), 0.42 },
		{ V(0.05, 0.82, -0.52), V(0.05, 0.25, -1), 0.38 },
		{ V(0.5, 0.5, -0.42), V(0.8, -0.3, -0.7), 0.36 },
		-- dessus
		{ V(-0.3, 0.92, -0.15), V(-0.5, 1, -0.3), 0.42 },
		{ V(0.25, 0.95, -0.1), V(0.45, 1, -0.2), 0.44 },
		{ V(-0.15, 0.96, 0.3), V(-0.25, 1, 0.6), 0.42 },
		{ V(0.25, 0.9, 0.38), V(0.4, 0.8, 0.8), 0.4 },
		-- côtés (au-dessus des oreilles)
		{ V(-0.64, 0.5, -0.05), V(-1, 0.2, -0.2), 0.4 },
		{ V(-0.62, 0.35, 0.3), V(-1, -0.3, 0.4), 0.38 },
		{ V(0.64, 0.5, -0.05), V(1, 0.2, -0.2), 0.4 },
		{ V(0.62, 0.35, 0.3), V(1, -0.3, 0.4), 0.38 },
		-- nuque
		{ V(-0.3, 0.1, 0.62), V(-0.4, -0.6, 1), 0.4 },
		{ V(0.05, 0.05, 0.68), V(0, -0.5, 1), 0.42 },
		{ V(0.36, 0.12, 0.6), V(0.45, -0.55, 1), 0.38 },
	}
do
	table.insert(GAARO_HAIR, {
		shape = "spike",
		limb = "Head",
		at = m[1],
		dir = m[2],
		length = m[3],
		width = 0.38,
		color = (i % 4 == 1) and GAARO_LIT or GAARO_RED,
	})
end
-- Gaaro ★1 : liseré gris clair du col (la bandoulière grise de la gourde est l'accessoire « sash »)
-- + gilet gris clair à pans croisés (plastron) et large ceinture grise, qui cassent le bordeaux
local GAARO_GREY, GAARO_GREY_DARK = rgb(176, 172, 160), rgb(128, 124, 116)
local GAARO_STRAP = {
	{ shape = "block", limb = "Torso", at = V(0, 0.96, -0.5), size = V(0.9, 0.1, 0.06), color = rgb(196, 192, 182) },
	{ shape = "block", limb = "Torso", at = V(-0.6, 0.3, -0.53), size = V(0.66, 1.25, 0.06), color = GAARO_GREY },
	{ shape = "block", limb = "Torso", at = V(0.6, 0.3, -0.53), size = V(0.66, 1.25, 0.06), color = GAARO_GREY },
	{ shape = "block", limb = "Torso", at = V(0, -0.58, 0), size = V(2.06, 0.46, 1.08), color = GAARO_GREY_DARK },
	{ shape = "block", limb = "Torso", at = V(0, -0.58, -0.55), size = V(0.34, 0.3, 0.04), color = rgb(196, 192, 182) },
}
local GAARO_KANJI = {
	shape = "block",
	limb = "Head",
	at = V(-0.27, 0.37, -0.605),
	size = V(0.3, 0.3, 0.02),
	color = rgb(250, 224, 200),
	transparency = 1,
	name = "Kanji",
	paint = {
		kind = "strokes",
		faces = { "Front" },
		bg = false,
		ink = rgb(196, 30, 40),
		lines = {
			{ 0.3, 0.1, 0.78, 0.04, 0.025 },
			{ 0.3, 0.17, 0.36, 0.26, 0.022 },
			{ 0.52, 0.16, 0.52, 0.26, 0.022 },
			{ 0.72, 0.16, 0.66, 0.26, 0.022 },
			{ 0.12, 0.33, 0.88, 0.33, 0.025 },
			{ 0.12, 0.33, 0.12, 0.43, 0.022 },
			{ 0.88, 0.33, 0.88, 0.43, 0.022 },
			{ 0.26, 0.47, 0.34, 0.6, 0.022 },
			{ 0.34, 0.6, 0.7, 0.6, 0.022 },
			{ 0.5, 0.45, 0.56, 0.53, 0.022 },
			{ 0.74, 0.45, 0.8, 0.54, 0.022 },
			{ 0.36, 0.7, 0.78, 0.7, 0.025 },
			{ 0.48, 0.66, 0.22, 0.96, 0.025 },
			{ 0.74, 0.7, 0.34, 0.95, 0.025 },
			{ 0.5, 0.8, 0.86, 0.97, 0.025 },
		},
	},
}

-- Hakaro : banane (pompadour) — vague de 3 coins qui part du front vers l'avant et le haut et
-- retombe en pointe au-dessus du front ; dessus plaqué vers l'arrière, strié de mèches fines ;
-- tempes rasées (duvet gris foncé) sur les côtés de la tête seulement, nuque dégagée.
local HAKARO_SILVER = rgb(190, 190, 180)
local function HAKARO_HAIR(c: Color3)
	local shine = c:Lerp(rgb(255, 255, 255), 0.4)
	local deep = c:Lerp(rgb(0, 0, 0), 0.35)
	local out = {
		-- dessus plaqué vers l'arrière : calotte basse et étroite (les côtés restent rasés)
		{ shape = "ball", limb = "Head", at = V(0, 0.5, 0.16), size = V(1.08, 0.66, 1.3), color = c, name = "HairCap" },
		-- banane : haut mur de cheveux qui monte du front en penchant vers l'avant...
		{ shape = "strand", limb = "Head", at = V(0, 0.55, -0.4), dir = V(0, 1, -0.55), length = 0.95, width = 0.82, depth = 0.55, color = c },
		-- ... et s'enroule vers l'avant au sommet (vague)
		{ shape = "strand", limb = "Head", at = V(0, 1.12, -0.5), dir = V(0, -0.15, -1), length = 0.78, width = 0.74, depth = 0.4, color = c },
		{ shape = "strand", limb = "Head", at = V(0.18, 1.2, -0.45), dir = V(0.05, -0.1, -1), length = 0.62, width = 0.3, depth = 0.18, color = shine },
		{ shape = "strand", limb = "Head", at = V(-0.2, 1.17, -0.48), dir = V(-0.05, -0.12, -1), length = 0.6, width = 0.16, depth = 0.12, color = deep },
		-- pointe qui retombe au-dessus du front (déborde de ~0.5 stud devant le front)
		{ shape = "spike", limb = "Head", at = V(0.04, 1.04, -1.12), dir = V(0.05, -0.85, -0.45), length = 0.42, width = 0.34, color = c },
	}
	-- stries du dessus (mèches fines lissées vers l'arrière)
	for i, x in { -0.36, -0.2, -0.05, 0.1, 0.25, 0.38 } do
		table.insert(out, {
			shape = "strand",
			limb = "Head",
			at = V(x, 0.84, -0.05),
			dir = V(x * 0.25, -0.35, 1),
			length = 0.95,
			width = 0.08,
			depth = 0.05,
			color = i % 2 == 0 and shine or deep,
		})
	end
	-- côtés de la banane lissés vers l'arrière (raccord avec la calotte)
	for _, sx in { -1, 1 } do
		table.insert(out, { shape = "strand", limb = "Head", at = V(sx * 0.36, 0.84, -0.38), dir = V(sx * 0.08, -0.3, 1), length = 0.72, width = 0.22, depth = 0.3, color = deep })
	end
	-- tempes rasées : duvet gris foncé sur les CÔTÉS seulement (au-dessus des oreilles, sous la
	-- calotte) ; la nuque reste couleur peau (pas de bande qui fait le tour de la tête)
	for _, sx in { -1, 1 } do
		table.insert(out, {
			shape = "ball",
			limb = "Head",
			at = V(sx * 0.53, 0.3, 0.1),
			size = V(0.14, 0.32, 0.6),
			color = rgb(92, 88, 84),
			name = "Shaved",
		})
	end
	return out
end

-- Minatu ★3 : mode chakra du renard — flammes noires sur le torse et les manches, tomoe en
-- cercle sur le ventre, col noir, manteau de chakra au bas découpé en flammes.
local KCM_INK = rgb(24, 20, 18)
local KCM_GOLD = rgb(255, 176, 40)
local function flameLines(x: number, flip: number)
	return {
		{ x, 0.02, x + 0.06 * flip, 0.18, 0.06 },
		{ x + 0.06 * flip, 0.18, x - 0.02 * flip, 0.3, 0.05 },
		{ x - 0.02 * flip, 0.3, x + 0.08 * flip, 0.44, 0.04 },
	}
end
local KCM_FRONT = { { 0.08, 0.04, 0.92, 0.04, 0.16 } }
for _, x in { 0.14, 0.86 } do
	for _, l in flameLines(x, x < 0.5 and 1 or -1) do
		table.insert(KCM_FRONT, l)
	end
end
local KCM_TOMOE = {}
for k = 0, 5 do
	local a = math.rad(k * 60)
	table.insert(KCM_TOMOE, { 0.5 + math.cos(a) * 0.15, 0.66 + math.sin(a) * 0.15, 0.13, 0.13 })
end
table.insert(KCM_TOMOE, { 0.5, 0.66, 0.1, 0.1 })
local MINATU_KCM = {
	{
		shape = "block",
		limb = "Torso",
		at = V(0, 0, -0.515),
		size = V(2.0, 2.0, 0.02),
		color = KCM_GOLD,
		transparency = 1,
		paint = { kind = "strokes", faces = { "Front" }, bg = false, ink = KCM_INK, lines = KCM_FRONT, dots = KCM_TOMOE },
	},
}
for _, side in { { "Left Arm", "Left" }, { "Right Arm", "Right" } } do
	table.insert(MINATU_KCM, {
		shape = "block",
		limb = side[1],
		at = V(0, 0, 0),
		size = V(1.03, 2.02, 1.03),
		color = KCM_GOLD,
		transparency = 1,
		paint = {
			kind = "strokes",
			faces = { "Front", "Back", side[2] },
			bg = false,
			ink = KCM_INK,
			lines = { { 0.2, 0.06, 0.32, 0.26, 0.07 }, { 0.32, 0.26, 0.22, 0.4, 0.05 }, { 0.75, 0.08, 0.66, 0.3, 0.06 }, { 0.0, 0.86, 1.0, 0.86, 0.05 } },
		},
	})
end
-- Manteau de chakra dans le dos, bas découpé en langues de flamme (deux demi-coins en miroir
-- par flamme, néon léger)
local KCM_COAT_LINES = { { 0.06, 0.04, 0.94, 0.04, 0.14 } }
for _, x in { 0.12, 0.36, 0.64, 0.88 } do
	table.insert(KCM_COAT_LINES, { x, 0.98, x + 0.05, 0.78, 0.07 })
	table.insert(KCM_COAT_LINES, { x + 0.05, 0.78, x - 0.03, 0.62, 0.05 })
end
table.insert(MINATU_KCM, {
	shape = "block",
	limb = "Torso",
	at = V(0, -0.35, 0.6),
	rot = V(6, 0, 0),
	size = V(2.2, 2.4, 0.08),
	color = rgb(255, 160, 40),
	paint = { kind = "strokes", faces = { "Back" }, ink = KCM_INK, lines = KCM_COAT_LINES, dots = { { 0.5, 0.3, 0.5, 0.5, rgb(255, 214, 90) } } },
	noPreview = true, -- dos du manteau : invisible dans les aperçus des menus (vus de face)
})
for i, x in { -0.81, -0.27, 0.27, 0.81 } do
	local h = (i % 2 == 0) and 0.95 or 0.7
	local color = (i % 2 == 0) and rgb(255, 120, 24) or rgb(255, 196, 64)
	for _, side in { -1, 1 } do
		table.insert(MINATU_KCM, {
			shape = "wedge",
			limb = "Torso",
			at = V(x + side * 0.135, -1.55 - h / 2, 0.68),
			rot = V(180, side * 90, 0),
			size = V(0.06, h, 0.27),
			color = color,
			material = "Neon",
			transparency = 0.1,
		})
	end
end

-- Yuuto ★2/★3 : l'esprit maudit (Rika) surgit derrière son épaule gauche, collée à lui (une
-- seule silhouette) — crâne anguleux gris-violet (blocs et coins, pas de sphères), grande
-- bouche noire garnie de dents blanches peintes, petits yeux rouges luisants ; dos voûté en deux
-- segments et épaules osseuses ; bras longs et fins (tiges) qui entourent les épaules de Yuuto,
-- mains à griffes.
local RIKA_GREY = rgb(110, 100, 130)
local RIKA_DARK = rgb(78, 70, 96)
local RIKA_BONE = rgb(132, 122, 150)
local RIKA_GHOST = { transparency = 0.15 }
local RIKA_TEETH = {}
for i = 0, 6 do
	local x = 0.1 + i * 0.133
	-- crocs du haut et du bas (pointes vers l'intérieur de la bouche)
	table.insert(RIKA_TEETH, { x - 0.05, 0.02, x, 0.36, 0.07 })
	table.insert(RIKA_TEETH, { x + 0.05, 0.02, x, 0.36, 0.07 })
	table.insert(RIKA_TEETH, { x - 0.05, 0.98, x + 0.02, 0.66, 0.07 })
	table.insert(RIKA_TEETH, { x + 0.06, 0.98, x + 0.02, 0.66, 0.07 })
end
-- repère du crâne : juste derrière et au-dessus de l'épaule gauche, penché vers l'avant et vers
-- la tête de Yuuto (le haut du crâne arrive à hauteur du sommet de sa tête)
local RIKA_SKULL = CFrame.new(-1.15, 2.35, 0.55) * CFrame.Angles(math.rad(-16), math.rad(-8), math.rad(14))
local function rikaAt(x: number, y: number, z: number): CFrame
	return RIKA_SKULL * CFrame.new(x, y, z)
end
local RIKA_BUST = {
	-- dos voûté en deux segments (bas du dos large, haut du dos + nuque qui monte vers le crâne)
	{ shape = "block", limb = "Torso", at = V(-0.75, 1.3, 1.0), rot = V(-14, 0, 10), size = V(1.45, 0.8, 0.7), color = RIKA_DARK, transparency = 0.15, name = "RikaBack" },
	{ shape = "block", limb = "Torso", at = V(-1.0, 1.85, 0.85), rot = V(-32, 0, 16), size = V(0.95, 0.72, 0.62), color = RIKA_DARK, transparency = 0.15 },
	-- épaules osseuses : deux coins pointus de part et d'autre du haut du dos
	{ shape = "wedge", limb = "Torso", at = V(-1.62, 1.72, 1.0), rot = V(0, 90, 18), size = V(0.6, 0.5, 0.42), color = RIKA_BONE, transparency = 0.15 },
	{ shape = "wedge", limb = "Torso", at = V(-0.2, 1.62, 1.08), rot = V(0, -90, -12), size = V(0.6, 0.46, 0.4), color = RIKA_BONE, transparency = 0.15 },
	-- crâne anguleux : boîte + dessus en coin (front fuyant) + arcade sourcilière sombre
	{ shape = "block", limb = "Torso", cf = rikaAt(0, 0, 0), size = V(0.96, 0.82, 0.88), color = RIKA_GREY, transparency = 0.15, name = "RikaHead" },
	{ shape = "wedge", limb = "Torso", cf = rikaAt(0, 0.56, 0.1), size = V(0.9, 0.3, 0.7), color = RIKA_GREY, transparency = 0.15 },
	-- joues creuses : deux coins qui affinent la mâchoire de part et d'autre
	{ shape = "wedge", limb = "Torso", cf = rikaAt(-0.5, -0.3, -0.1) * CFrame.Angles(0, math.rad(90), math.pi), size = V(0.8, 0.5, 0.22), color = RIKA_DARK, transparency = 0.15 },
	{ shape = "wedge", limb = "Torso", cf = rikaAt(0.5, -0.3, -0.1) * CFrame.Angles(0, math.rad(-90), math.pi), size = V(0.8, 0.5, 0.22), color = RIKA_DARK, transparency = 0.15 },
	{ shape = "block", limb = "Torso", cf = rikaAt(0, 0.2, -0.47), size = V(0.96, 0.12, 0.08), color = RIKA_DARK },
	-- mâchoire qui avance sous la bouche
	{ shape = "wedge", limb = "Torso", cf = rikaAt(0, -0.58, -0.12) * CFrame.Angles(math.pi, 0, 0), size = V(0.84, 0.26, 0.8), color = RIKA_DARK, transparency = 0.15 },
	-- bouche béante : grand panneau noir peint de dents blanches
	{
		shape = "block",
		limb = "Torso",
		cf = rikaAt(0, -0.2, -0.48),
		size = V(0.8, 0.44, 0.06),
		color = rgb(22, 8, 18),
		paint = { kind = "strokes", faces = { "Front" }, ink = rgb(246, 242, 232), lines = RIKA_TEETH },
		name = "RikaMouth",
	},
}
-- longues mèches sombres qui tombent du crâne dans le dos (cheveux de Rika)
for i, x in { -0.32, -0.08, 0.18, 0.38 } do
	local base = rikaAt(x, 0.5, 0.25).Position
	table.insert(RIKA_BUST, {
		shape = "strand",
		limb = "Torso",
		at = base,
		dir = V(x * 0.4 - 0.15, -1, 0.55),
		length = 0.9 + (i % 2) * 0.35,
		width = 0.22,
		depth = 0.1,
		color = rgb(34, 28, 40),
	})
end
-- petits yeux rouges luisants (lueur rose)
for _, x in { -0.24, 0.24 } do
	table.insert(RIKA_BUST, {
		shape = "ball",
		limb = "Torso",
		cf = rikaAt(x, 0.1, -0.48),
		size = V(0.17, 0.11, 0.06),
		color = rgb(255, 50, 80),
		material = "Neon",
		name = "RikaEye",
	})
end
RIKA_BUST[#RIKA_BUST].light = rgb(255, 120, 170)
RIKA_BUST[#RIKA_BUST].lightRange = 6
RIKA_BUST[#RIKA_BUST].lightBrightness = 2
-- Bras long et fin (tiges osseuses) : de l'épaule de Rika, par-dessus l'épaule de Yuuto, jusque
-- devant son torse ; `s` = -1 : bras sur l'épaule gauche ; 1 : bras qui passe derrière la
-- nuque jusqu'à l'épaule droite
local function rikaArm(s: number)
	local pts = s < 0 and { V(-1.5, 1.75, 1.05), V(-1.6, 1.75, 0.35), V(-1.25, 1.3, -0.62), V(-0.55, 0.65, -0.82) }
		or { V(-0.4, 1.75, 1.15), V(0.5, 1.75, 0.95), V(1.55, 1.55, 0.2), V(1.3, 1.0, -0.66), V(0.6, 0.45, -0.85) }
	local out = rods("Torso", pts, { 0.26, 0.22, 0.2, 0.18 }, RIKA_GREY, RIKA_GHOST)
	local hand = pts[#pts]
	local back = (hand - pts[#pts - 1]).Unit
	table.insert(out, { shape = "block", limb = "Torso", at = hand, dir = back, size = V(0.34, 0.3, 0.16), color = RIKA_GREY, transparency = 0.15 })
	-- griffes : longues lames noires qui prolongent les doigts
	for i, off in { -0.12, 0, 0.12 } do
		table.insert(out, {
			shape = "blade",
			limb = "Torso",
			at = hand + back * 0.25 + V(0, off, -0.05),
			dir = back + V(0, off * 1.5 - 0.3, 0),
			rot = V(0, 90, 0),
			length = i == 2 and 0.6 or 0.48,
			width = 0.12,
			depth = 0.05,
			color = rgb(28, 22, 34),
		})
	end
	return out
end
local RIKA_HAND = join(RIKA_BUST, rikaArm(-1))
local RIKA_HAND_LEFT = rikaArm(1)

-- Hakaro ★2 : liserés vert fluo du jackpot sur la veste ouverte et aux poignets
local JACKPOT = rgb(90, 255, 140)
local JACKPOT_TRIM = {
	{ shape = "block", limb = "Torso", at = V(-0.34, -0.05, -0.53), size = V(0.07, 1.9, 0.03), color = JACKPOT, material = "Neon" },
	{ shape = "block", limb = "Torso", at = V(0.34, -0.05, -0.53), size = V(0.07, 1.9, 0.03), color = JACKPOT, material = "Neon" },
	{ shape = "cyl", limb = "Left Arm", at = V(0, -0.55, 0), rot = V(0, 0, 90), size = V(0.08, 1.06, 0), color = JACKPOT, material = "Neon" },
	{ shape = "cyl", limb = "Right Arm", at = V(0, -0.55, 0), rot = V(0, 0, 90), size = V(0.08, 1.06, 0), color = JACKPOT, material = "Neon" },
}
-- Hakaro ★3 : billes de jackpot en orbite
local JACKPOT_BALLS = {}
for k = 0, 6 do
	local a = math.rad(k * 360 / 7)
	table.insert(JACKPOT_BALLS, {
		shape = "ball",
		limb = "Torso",
		at = V(math.cos(a) * 2.1, 0.6 + math.sin(a * 2) * 0.35, math.sin(a) * 1.5),
		size = V(0.32, 0.32, 0.32),
		color = k % 2 == 0 and rgb(220, 224, 236) or JACKPOT,
		material = k % 2 == 0 and "Metal" or "Neon",
	})
end

-- Gojita : bords orange du gilet, épaulettes jaunes, épaisse ceinture bleue nouée, gros poignets
local GOJITA_KIT = join({
	{ shape = "block", limb = "Torso", at = V(-0.5, 0, -0.52), size = V(0.11, 2.02, 0.03), color = rgb(240, 136, 36) },
	{ shape = "block", limb = "Torso", at = V(0.5, 0, -0.52), size = V(0.11, 2.02, 0.03), color = rgb(240, 136, 36) },
	{ shape = "block", limb = "Torso", at = V(-0.66, 1.03, 0), size = V(0.66, 0.16, 1.1), color = rgb(250, 196, 50) },
	{ shape = "block", limb = "Torso", at = V(0.66, 1.03, 0), size = V(0.66, 0.16, 1.1), color = rgb(250, 196, 50) },
	{ shape = "block", limb = "Torso", at = V(0, 1.0, 0.52), size = V(1.1, 0.24, 0.1), color = rgb(240, 136, 36) },
	-- dos du gilet : liseré orange (bas et emmanchures) et pli du tissu au milieu
	{
		shape = "block",
		limb = "Torso",
		at = V(0, 0.2, 0.515),
		size = V(2.0, 1.6, 0.02),
		color = rgb(30, 30, 38),
		transparency = 1,
		name = "GojitaBack",
		paint = {
			kind = "strokes",
			faces = { "Back" },
			bg = false,
			ink = rgb(240, 136, 36),
			lines = {
				{ 0.03, 0.96, 0.97, 0.96, 0.06 },
				{ 0.04, 0.05, 0.04, 0.96, 0.05 },
				{ 0.96, 0.05, 0.96, 0.96, 0.05 },
				{ 0.5, 0.12, 0.5, 0.9, 0.03, rgb(62, 62, 76) },
				{ 0.36, 0.3, 0.46, 0.62, 0.025, rgb(54, 54, 66) },
				{ 0.64, 0.3, 0.54, 0.62, 0.025, rgb(54, 54, 66) },
			},
		},
	},
	{ shape = "block", limb = "Torso", at = V(0, -0.8, 0), size = V(2.1, 0.42, 1.12), color = rgb(64, 112, 214) },
	{ shape = "ball", limb = "Torso", at = V(-0.5, -0.82, -0.6), size = V(0.44, 0.36, 0.26), color = rgb(52, 96, 196) },
	{ shape = "block", limb = "Torso", at = V(-0.44, -1.25, -0.6), rot = V(0, 0, 8), size = V(0.22, 0.6, 0.05), color = rgb(64, 112, 214) },
	{ shape = "block", limb = "Torso", at = V(-0.64, -1.2, -0.59), rot = V(0, 0, -14), size = V(0.2, 0.5, 0.05), color = rgb(52, 96, 196) },
}, cuffs(rgb(244, 244, 240), 0.62, -0.62))

-- Cel : crête en deux grandes nageoires plates (vertes bordées de noir) qui partent des tempes,
-- collées au crâne, et montent vers l'arrière ; calotte verte tachée qui couvre le haut et
-- l'arrière du crâne ; plastron vert à taches noires, abdos segmentés blanc rosé, ailes noires
-- décollées du dos qui dépassent des épaules. `k` = hauteur de la crête (plus haute en forme
-- parfaite).
local CEL_SKIN, CEL_SPOT, CEL_BLACK = rgb(242, 228, 234), rgb(14, 22, 16), rgb(20, 24, 22)
local function CEL_CREST(color: Color3, k: number)
	local out = {
		-- calotte vert foncé : arrière, dessus du crâne et haut du front (le visage clair se
		-- limite au masque, des sourcils au menton)
		{ shape = "ball", limb = "Head", at = V(0, 0.32, 0.14), size = V(1.34, 1.04, 1.32), color = color, name = "CelCap" },
		-- dessus du crâne : cylindre ajusté à la tête (rayon 0.665), du haut du front au sommet
		{ shape = "cyl", limb = "Head", at = V(0, 0.42, 0), dir = V(0, 1, 0), size = V(0.24, 1.33, 0), color = color, name = "CelCap" },
		{ shape = "ball", limb = "Head", at = V(0, -0.12, 0.3), size = V(1.28, 0.95, 0.92), color = color },
	}
	for _, s in { -1, 1 } do
		-- crête : deux lames symétriques qui partent des tempes vers l'arrière et vers le haut
		-- (~35°), pointes sous le sommet du crâne + 0.6 ; liseré noir derrière la lame verte
		-- lame dans un plan presque vertical (vue de face : une fine pointe de chaque côté, pas
		-- une oreille ; vue de profil : la nageoire entière)
		-- (écartées vers l'extérieur : de 3/4, la lame du côté opposé dépasse aussi de la tête)
		local dir = V(s * 0.75, 0.7, 0.45).Unit
		local right = V(s, 0, 0):Cross(dir).Unit
		local L = 1.05 * k
		for i, b in { { CEL_BLACK, L + 0.14, 0.7, 0.5 }, { color, L, 0.54, 0.56 } } do
			local base = V(s * b[4], 0.04 + (i - 1) * 0.04, -0.02)
			table.insert(out, {
				shape = "blade",
				limb = "Head",
				cf = CFrame.fromMatrix(base, right, dir, right:Cross(dir)),
				length = b[2],
				width = b[3],
				depth = 0.1,
				color = b[1],
				name = "CelCrest",
			})
		end
	end
	-- taches noires sur la calotte (dessus et arrière du crâne)
	for _, t in { { 0, 0.72, 0.3 }, { -0.3, 0.44, 0.7 }, { 0.32, 0.28, 0.76 }, { 0, -0.1, 0.78 }, { -0.5, -0.2, 0.5 }, { 0.5, -0.06, 0.48 } } do
		table.insert(out, { shape = "ball", limb = "Head", at = V(t[1], t[2], t[3]), size = V(0.15, 0.12, 0.15), color = CEL_SPOT })
	end
	return out
end
local function CEL_BODY(plate: Color3, wing: Color3?)
	local dots = {}
	for _, d in { { 0.14, 0.3 }, { 0.3, 0.62 }, { 0.42, 0.26 }, { 0.6, 0.7 }, { 0.72, 0.3 }, { 0.88, 0.56 }, { 0.22, 0.78 }, { 0.8, 0.82 } } do
		table.insert(dots, { d[1], d[2], 0.16, 0.13 })
	end
	-- abdos : 3 rangées de 2 plaques blanc rosé, sillons violets
	local abs = {}
	for _, y in { 0.2, 0.52, 0.84 } do
		for _, x in { 0.27, 0.73 } do
			table.insert(abs, { x, y, 0.4, 0.29, CEL_SKIN })
			table.insert(abs, { x - 0.04, y - 0.05, 0.18, 0.08, rgb(255, 248, 252) })
		end
	end
	local out = {
		-- abdos segmentés (posés sous le bord du plastron)
		{
			shape = "block",
			limb = "Torso",
			at = V(0, -0.45, -0.525),
			size = V(0.9, 1.02, 0.05),
			color = rgb(186, 156, 190),
			paint = { kind = "strokes", faces = { "Front" }, ink = rgb(150, 116, 160), dots = abs },
		},
		-- plastron taché : son bord bas chevauche le haut des abdos
		{
			shape = "block",
			limb = "Torso",
			at = V(0, 0.5, -0.545),
			size = V(1.98, 0.98, 0.08),
			color = plate,
			paint = {
				kind = "strokes",
				faces = { "Front" },
				ink = CEL_SPOT,
				dots = dots,
				lines = { { 0.5, 0.05, 0.5, 0.95, 0.04, rgb(40, 70, 40) }, { 0.3, 0.97, 0.7, 0.97, 0.05, rgb(40, 70, 40) } },
			},
		},
		{ shape = "block", limb = "Torso", at = V(0, 1.02, -0.12), size = V(0.66, 0.08, 0.6), color = CEL_SKIN },
	}
	-- Ailes : deux lames noires triangulaires à liseré vert, décollées du dos (0.15 stud), en V
	-- (±25°) : angle droit en haut près de la colonne, pointe en bas, coin extérieur qui dépasse
	-- sur les côtés du torse vu de face (et ne cadre pas la tête comme un col)
	local a = math.rad(25)
	for _, s in { -1, 1 } do
		local down = V(-s * math.sin(a), -math.cos(a), 0) -- du haut vers la pointe (vers la colonne)
		local inward = V(-s * math.cos(a), math.sin(a), 0)
		local thick = V(0, 0, -s)
		for i, w in { { 2.75, 1.45, plate, 0.66 }, { 2.55, 1.3, wing or CEL_BLACK, 0.71 } } do
			local L, W = w[1], w[2]
			-- coin à angle droit (haut, côté colonne) ; centre de la pièce
			local corner = V(s * 1.28, 1.2 - (i - 1) * 0.06, w[4])
			local center = corner + down * (L / 2) - inward * (W / 2)
			table.insert(out, {
				shape = "wedge",
				limb = "Torso",
				cf = CFrame.fromMatrix(center, thick, down, thick:Cross(down)),
				size = V(0.06 + (i - 1) * 0.01, L, W),
				color = w[3],
				name = "CelWing",
			})
		end
	end
	return out
end
-- Queue à dard (forme imparfaite) : 3 segments coniques qui s'affinent et se recourbent vers le
-- haut, joints arrondis, dard blanc au bout.
local CEL_TAIL = join(rods("Torso", { V(0, -0.85, 0.5), V(0, -1.65, 1.35), V(0.15, -1.9, 2.35), V(0.35, -1.3, 3.05) }, { 0.5, 0.38, 0.26 }, rgb(54, 84, 46)), {
	{ shape = "ball", limb = "Torso", at = V(0, -1.65, 1.35), size = V(0.46, 0.46, 0.46), color = rgb(54, 84, 46) },
	{ shape = "ball", limb = "Torso", at = V(0.15, -1.9, 2.35), size = V(0.34, 0.34, 0.34), color = CEL_SPOT },
	{ shape = "spike", limb = "Torso", at = V(0.38, -1.25, 3.08), dir = V(0.15, 1, 0.45), length = 0.8, width = 0.3, color = rgb(236, 226, 206) },
})
-- Cel ★3 : arcs électriques bleus (zigzags néon) autour des bras et du torse
local CEL_SPARKS = {}
for _, arc in
	{
		{ "Torso", { V(-1.3, 1.4, -0.6), V(-1.6, 0.9, -0.7), V(-1.25, 0.5, -0.6), V(-1.7, -0.1, -0.7) } },
		{ "Torso", { V(1.35, 1.2, -0.65), V(1.75, 0.7, -0.6), V(1.35, 0.25, -0.7), V(1.8, -0.4, -0.6) } },
		{ "Torso", { V(-0.6, 2.4, 0.2), V(-0.2, 2.75, 0.1), V(0.25, 2.5, 0.3), V(0.6, 2.9, 0.2) } },
		{ "Torso", { V(-1.1, -1.4, -0.7), V(-0.7, -1.8, -0.8), V(-1.0, -2.3, -0.7) } },
		{ "Torso", { V(1.0, -1.5, -0.7), V(0.7, -2.0, -0.8), V(1.05, -2.5, -0.7) } },
	}
do
	for _, p in rods(arc[1], arc[2], { 0.09 }, rgb(150, 220, 255), { material = "Neon", transparency = 0.05 }) do
		table.insert(CEL_SPARKS, p)
	end
end

-- Jirène : grand crâne lisse, arcades massives, oreilles pointues
local JIRENE_HEAD = {}
for _, s in { -1, 1 } do
	table.insert(JIRENE_HEAD, { shape = "ball", limb = "Head", at = V(s * 0.66, 0.0, 0.05), size = V(0.16, 0.5, 0.32), color = rgb(150, 160, 178) })
	table.insert(JIRENE_HEAD, { shape = "spike", limb = "Head", at = V(s * 0.68, 0.18, 0.06), dir = V(s * 0.5, 1, 0.15), length = 0.36, width = 0.2, color = rgb(150, 160, 178) })
end

-- Inel : long bâton doré (chargé de foudre au ★3)
local function INEL_STAFF(glow: boolean)
	return {
		{
			shape = "cyl",
			limb = "Right Arm",
			at = V(0, -2.75, -0.42),
			dir = V(0, 1, 0.04),
			size = V(4.7, 0.16, 0),
			color = glow and rgb(190, 230, 255) or GOLD,
			material = glow and "Neon" or "Metal",
		},
		{ shape = "ball", limb = "Right Arm", at = V(0, 1.98, -0.24), size = V(0.32, 0.32, 0.32), color = GOLD, material = "Metal" },
		{ shape = "cyl", limb = "Right Arm", at = V(0, 1.6, -0.25), rot = V(0, 0, 90), size = V(0.1, 0.26, 0), color = rgb(226, 120, 40) },
	}
end

-- Lao ★2/★3 : salle d'opération (dôme bleu translucide) autour de la main gauche
local ROOM_DOME = {
	{ shape = "ball", limb = "Left Arm", at = V(0, -1.05, -0.2), size = V(1.6, 1.6, 1.6), color = rgb(110, 190, 255), material = "Neon", transparency = 0.65 },
}
-- Lao ★3 : la « Room » en grand dôme translucide (7 studs) centré sur lui, bord en champ de force
-- bleu clair (omise dans les aperçus des menus, où elle masquerait le perso)
local ROOM_BIG = {
	{
		shape = "ball",
		limb = "Torso",
		at = V(0, 0.2, 0),
		size = V(7.2, 6.6, 7.2),
		color = rgb(150, 210, 255),
		material = "ForceField",
		transparency = 0.45,
		noPreview = true,
		name = "OperationRoom",
		light = rgb(130, 200, 255),
		lightRange = 10,
	},
	-- coque lisse très transparente (le champ de force seul est presque invisible en jeu)
	{ shape = "ball", limb = "Torso", at = V(0, 0.2, 0), size = V(7.0, 6.4, 7.0), color = rgb(120, 190, 255), material = "SmoothPlastic", transparency = 0.85, noPreview = true },
}
-- anneau lumineux au sol, au pied du dôme (12 segments)
for k = 0, 11 do
	local a = math.rad(k * 30 + 15)
	table.insert(ROOM_BIG, {
		shape = "block",
		limb = "Torso",
		at = V(math.cos(a) * 3.5, -2.95, math.sin(a) * 3.5),
		rot = V(0, -k * 30 - 15 + 90, 0),
		size = V(1.86, 0.08, 0.16),
		color = rgb(140, 210, 255),
		material = "Neon",
		transparency = 0.15,
		noPreview = true,
	})
end

-- Kaydo : cornes (taille selon l'évolution), moustache tombante. Au ★2/★3 (`curl`), les cornes
-- sont plus grandes et recourbées vers l'arrière (deux segments qui s'affinent + pointe).
local function KAYDO_HORNS(k: number, color: Color3?, curl: boolean?)
	local c = color or rgb(238, 230, 210)
	local root = c:Lerp(rgb(90, 70, 50), 0.35)
	local out = {}
	for _, s in { -1, 1 } do
		local p0 = V(s * 0.38, 0.6, -0.2)
		if curl then
			local p1 = p0 + V(s * 0.32, 0.72, 0.1) * k
			local p2 = p1 + V(s * 0.12, 0.42, 0.42) * k
			for _, r in rods("Head", { p0, p1, p2 }, { 0.32 * k, 0.24 * k }, c) do
				r.name = "KaydoHorn"
				table.insert(out, r)
			end
			table.insert(out, { shape = "spike", limb = "Head", at = p2 - V(0, 0, 0.05), dir = V(0, 0.25, 1), length = 0.6 * k, width = 0.22 * k, color = c })
		else
			table.insert(out, { shape = "ball", limb = "Head", at = p0, size = V(0.34, 0.2, 0.34) * k, color = root })
			table.insert(out, { shape = "spike", limb = "Head", at = p0 + V(0, 0.02, 0), dir = V(s * 0.45, 1, 0.32), length = 1.0 * k, width = 0.4 * k, color = c })
		end
	end
	return out
end
-- moustache : part sous le nez vers les côtés puis retombe le long des joues (plus longue au ★2,
-- avec une barbiche au menton) ; rien devant les yeux
local function KAYDO_FACE(k: number)
	local ink = rgb(26, 24, 30)
	local out = {}
	for _, s in { -1, 1 } do
		table.insert(out, { shape = "strand", limb = "Head", at = V(s * 0.08, -0.2, -0.66), dir = V(s, -0.3, -0.1), length = 0.55, width = 0.09, depth = 0.09, color = ink })
		table.insert(out, {
			shape = "strand",
			limb = "Head",
			at = V(s * 0.52, -0.33, -0.6),
			dir = V(s * 0.3, -1, -0.1),
			length = 0.6 * k,
			width = 0.08 + 0.02 * (k - 1),
			depth = 0.08,
			color = ink,
		})
	end
	if k > 1 then
		table.insert(out, { shape = "strand", limb = "Head", at = V(0, -0.5, -0.58), dir = V(0, -1, -0.3), length = 0.55 * k, width = 0.2, depth = 0.12, color = ink })
	end
	return out
end
-- Kaydo : torse de colosse — deltoïdes et trapèze intégrés, pectoraux, abdos et cicatrices
-- peints sur le torse nu (calque transparent, la peau du torse reste dessous)
local KAYDO_SKIN = rgb(230, 186, 148)
local KAYDO_INK = rgb(150, 98, 70)
local KAYDO_SCAR = rgb(204, 132, 120)
local KAYDO_BODY = join(brawn(KAYDO_SKIN, KAYDO_SKIN, 1.1), {
	{
		shape = "block",
		limb = "Torso",
		at = V(0, 0, -0.515),
		size = V(2.0, 2.0, 0.02),
		color = KAYDO_SKIN,
		transparency = 1,
		name = "KaydoChest",
		paint = {
			kind = "strokes",
			faces = { "Front" },
			bg = false,
			ink = KAYDO_INK,
			lines = {
				-- bas des pectoraux (deux arcs)
				{ 0.08, 0.36, 0.26, 0.45, 0.05 },
				{ 0.26, 0.45, 0.47, 0.42, 0.05 },
				{ 0.92, 0.36, 0.74, 0.45, 0.05 },
				{ 0.74, 0.45, 0.53, 0.42, 0.05 },
				-- sillon central et abdos
				{ 0.5, 0.14, 0.5, 0.9, 0.03 },
				{ 0.32, 0.6, 0.46, 0.6, 0.03 },
				{ 0.54, 0.6, 0.68, 0.6, 0.03 },
				{ 0.34, 0.74, 0.46, 0.75, 0.03 },
				{ 0.54, 0.75, 0.66, 0.74, 0.03 },
				-- cicatrices claires en travers de la poitrine
				{ 0.18, 0.18, 0.44, 0.34, 0.035, KAYDO_SCAR },
				{ 0.62, 0.22, 0.86, 0.12, 0.03, KAYDO_SCAR },
				{ 0.6, 0.62, 0.82, 0.8, 0.03, KAYDO_SCAR },
			},
		},
	},
})
local KAYDO_WHISKERS = {}
for _, s in { -1, 1 } do
	table.insert(
		KAYDO_WHISKERS,
		{ shape = "strand", limb = "Head", at = V(s * 0.5, 0.05, -0.5), dir = V(s, 0.25, -0.35), length = 1.5, width = 0.08, depth = 0.08, color = rgb(240, 200, 90) }
	)
end
-- Kaydo ★2/★3 (forme hybride du dragon) : écailles bleues PLATES — petits coins triangulaires
-- fins (0.08 d'épaisseur) plaqués sur les deux avant-bras (face avant ET face extérieure), sur
-- l'avant des épaules et sur les pommettes ; ils alternent de sens et de ton comme des écailles
-- (pas de pastilles ni de boules).
local KAYDO_SCALE_BLUE, KAYDO_SCALE_DEEP = rgb(80, 140, 210), rgb(56, 104, 170)
local KAYDO_SCALES = {}
local function kaydoScale(limb: string, at: Vector3, rot: Vector3, size: Vector3, k: number)
	table.insert(KAYDO_SCALES, {
		shape = "wedge",
		limb = limb,
		at = at,
		rot = rot,
		size = size,
		color = k % 2 == 0 and KAYDO_SCALE_BLUE or KAYDO_SCALE_DEEP,
		name = "KaydoScale",
	})
end
for _, side in { { "Left Arm", -1 }, { "Right Arm", 1 } } do
	local limb, s = side[1], side[2]
	for k = 0, 1 do
		-- face extérieure de l'avant-bras
		kaydoScale(limb, V(s * 0.53, -0.22 - k * 0.4, (k % 2 == 0) and -0.12 or 0.12), V(180, 0, 0), V(0.08, 0.46, 0.5), k)
	end
	for k = 0, 1 do
		-- face avant de l'avant-bras (bien visibles de face)
		kaydoScale(limb, V((k % 2 == 0) and -0.13 or 0.13, -0.26 - k * 0.36, -0.53), V(0, (k % 2 == 0) and 90 or -90, 0), V(0.08, 0.4, 0.44), k + 1)
	end
	-- avant de l'épaule (sur le deltoïde)
	kaydoScale(limb, V(s * 0.1, 0.74, -0.62), V(0, s * 90, 0), V(0.08, 0.46, 0.56), 1)
	-- pommette (petites écailles plaquées sur le visage, sous l'œil)
	kaydoScale("Head", V(s * 0.46, -0.08, -0.6), V(0, s * 90, 0), V(0.05, 0.2, 0.26), (s + 1) / 2)
end
-- Queue du dragon : part du bas du dos, plonge derrière lui puis REMONTE en S sur son flanc
-- gauche (du côté opposé à la massue) et dépasse de sa silhouette de face ; tiges cylindriques
-- qui s'affinent et crête de piques ivoire sur le dessus
local KAYDO_TAIL_PTS = { V(-0.2, -0.85, 0.5), V(-0.75, -1.5, 1.25), V(-1.75, -1.3, 1.55), V(-2.45, -0.35, 1.0), V(-2.6, 0.85, 0.35) }
local KAYDO_TAIL = rods("Torso", KAYDO_TAIL_PTS, { 0.62, 0.5, 0.38, 0.27 }, rgb(70, 128, 200))
for _, r in KAYDO_TAIL do
	r.name = "KaydoTail"
end
for i = 2, #KAYDO_TAIL_PTS - 2 do
	local a, b = KAYDO_TAIL_PTS[i], KAYDO_TAIL_PTS[i + 1]
	local d = (b - a).Unit
	-- côté « dessus » de la queue : vers l'arrière et l'extérieur (crête bien visible)
	local up = (V(-0.6, 0.3, 0.75) - d * d:Dot(V(-0.6, 0.3, 0.75))).Unit
	table.insert(KAYDO_TAIL, {
		shape = "spike",
		limb = "Torso",
		at = (a + b) / 2 + up * (0.3 - i * 0.04),
		dir = (up + d * 0.5).Unit,
		length = 0.62 - i * 0.08,
		width = 0.3 - i * 0.04,
		color = rgb(240, 236, 224),
	})
end

-- Massue de Kaydo tenue VERTICALE le long de son flanc droit, tête cloutée posée au sol (jamais
-- devant le visage ni derrière la tête, sous aucun angle)
local KAYDO_CLUB = kanabo("Right Arm", V(0.72, 0.25, -0.15), V(0.1, -1, -0.04), 3.35, 0.56)

-- Muzon : cravate rouge ; fouets de chair dans le dos (★2/★3)
local MUZON_TIE = {
	{ shape = "block", limb = "Torso", at = V(0, 0.42, -0.515), size = V(0.17, 0.82, 0.03), color = rgb(176, 20, 38) },
	{ shape = "block", limb = "Torso", at = V(0, 0.86, -0.52), size = V(0.22, 0.14, 0.05), color = rgb(150, 16, 32) },
}
local function MUZON_WHIPS(n: number)
	local out = {}
	for k = 1, n do
		local s = k % 2 == 0 and 1 or -1
		local lift = math.floor((k - 1) / 2) * 0.55
		for _, p in
			chain("Torso", {
				V(s * 0.3, 0.5 - lift * 0.4, 0.55),
				V(s * 1.0, 1.3 + lift, 1.35),
				V(s * 1.9, 1.7 + lift, 1.6),
				V(s * 2.7, 1.2 + lift * 1.2, 1.15),
			}, { 0.32, 0.26, 0.2 }, { rgb(120, 18, 40), rgb(168, 36, 60) })
		do
			table.insert(out, p)
		end
	end
	return out
end

-- Muzon ★2/★3 : boucles courtes et serrées en VAGUES — petits coins plats couchés sur le crâne
-- (pointe vers le bas, sens alterné gauche/droite d'une boucle à l'autre), en rangées autour de
-- la tête, deux tons ; pas de sphères ni de boudins.
local MUZON_CURLS = {}
do
	local n = 0
	for _, row in { { 16, 5, 0.75, false }, { 46, 9, 0.75, false }, { 76, 9, 0.72, true } } do
		for j = 0, row[2] - 1 do
			local a = j * 360 / row[2] + (row[1] == 48 and 20 or 0)
			-- rangée basse : rien devant le visage (front et yeux dégagés)
			if not (row[4] and math.cos(math.rad(a)) > 0.55) then
				n += 1
				local color = n % 3 == 0 and rgb(58, 54, 70) or rgb(20, 18, 24)
				table.insert(MUZON_CURLS, headLock(row[1], a, row[3], V(0.4, 0.1, 0.42), color, "MuzonCurl", false, n % 2 == 0 and 0.75 or -0.75))
			end
		end
	end
end

-- Doma : cheveux blond très pâle LISSES — mèches longues et PLATES (planches fines effilées au
-- bout, comme des rubans) qui encadrent le visage et tombent dans le dos, frange plate en
-- quatre mèches couchées sur le front, et sommet du crâne taché de sang (éclaboussures plates
-- posées sur la calotte, pas de boudins).
local DOMA_HAIR, DOMA_HAIR_DEEP = rgb(240, 232, 212), rgb(214, 202, 176)
local DOMA_BLOOD = {}
-- mèche plate : planche (largeur w, épaisseur 0.07) de `top` vers le bas, tournée vers `facing`,
-- terminée par un coin qui s'effile
local function flatLock(top: Vector3, dir: Vector3, length: number, w: number, facing: Vector3, color: Color3)
	local d = dir.Unit
	local n = (facing - d * facing:Dot(d)).Unit
	local x = d:Cross(n).Unit -- largeur de la mèche
	local body = length * 0.78
	local tipLen = length - body
	table.insert(DOMA_BLOOD, {
		shape = "block",
		limb = "Head",
		cf = CFrame.fromMatrix(top + d * (body / 2), x, d, n),
		size = V(w, body, 0.07),
		color = color,
		name = "DomaLock",
	})
	-- pointe : coin couché dans le plan de la mèche (s'effile vers le bas)
	table.insert(DOMA_BLOOD, {
		shape = "wedge",
		limb = "Head",
		cf = CFrame.fromMatrix(top + d * (body + tipLen / 2 - 0.02), n, d),
		size = V(0.07, tipLen, w),
		color = color,
		name = "DomaLock",
	})
end
-- nappe du dos : grande plaque lisse jusqu'au milieu du dos, et deux plaques sur les côtés
table.insert(DOMA_BLOOD, { shape = "block", limb = "Head", at = V(0, -0.5, 0.66), size = V(1.3, 1.9, 0.14), color = DOMA_HAIR_DEEP, name = "DomaLock" })
for _, s in { -1, 1 } do
	table.insert(DOMA_BLOOD, { shape = "block", limb = "Head", at = V(s * 0.66, -0.2, 0.22), size = V(0.14, 1.3, 0.8), color = DOMA_HAIR_DEEP, name = "DomaLock" })
end
for _, s in { -1, 1 } do
	-- mèches qui encadrent le visage (devant les oreilles, jusqu'à la poitrine)
	flatLock(V(s * 0.66, 0.5, -0.3), V(s * 0.08, -1, -0.03), 1.55, 0.3, V(s * 0.6, 0, -0.8), DOMA_HAIR)
end
for i, x in { -0.45, -0.15, 0.15, 0.45 } do
	-- mèches du dos, sur la nappe (deux tons alternés)
	flatLock(V(x, 0.42, 0.76), V(x * 0.12, -1, 0.06), 1.95, 0.34, V(x * 0.5, 0, 1), i % 2 == 0 and DOMA_HAIR or DOMA_HAIR_DEEP)
end
-- frange : quatre mèches plates plaquées sur le front, pointe vers le bas (yeux dégagés)
for i, x in { -0.36, -0.12, 0.12, 0.36 } do
	flatLock(V(x, 0.62, -0.64), V(x * 0.25, -1, -0.12), 0.48, 0.28, V(x * 0.3, 0.2, -1), i % 2 == 0 and DOMA_HAIR or rgb(255, 250, 236))
end
-- sang sur le sommet : éclaboussures plates de tailles différentes + deux coulures
for _, b in
	{
		{ 6, 0, V(0.62, 0.06, 0.62) },
		{ 22, -60, V(0.4, 0.05, 0.5) },
		{ 24, 70, V(0.36, 0.05, 0.44) },
		{ 30, 170, V(0.44, 0.05, 0.5) },
		{ 40, 25, V(0.18, 0.04, 0.42) },
		{ 44, -110, V(0.16, 0.04, 0.4) },
	}
do
	table.insert(DOMA_BLOOD, headLock(b[1], b[2], 0.8, b[3], rgb(168, 18, 30), "DomaBlood", false, 0))
end
-- Doma ★3 : cristaux de glace sur les épaules
local ICE_CRYSTALS = {}
for _, s in { -1, 1 } do
	table.insert(ICE_CRYSTALS, { shape = "spike", limb = "Torso", at = V(s * 1.1, 1.0, 0.1), dir = V(s * 0.5, 1, 0.25), length = 1.0, width = 0.36, color = rgb(200, 236, 255) })
	table.insert(ICE_CRYSTALS, { shape = "spike", limb = "Torso", at = V(s * 1.35, 0.85, 0.35), dir = V(s * 1, 0.7, 0.5), length = 0.7, width = 0.28, color = rgb(170, 220, 255) })
end

-- Tengan ★2 : un couperet dans chaque main, chaîne entre les pommeaux
local TENGAN_DUAL = {}
do
	local gr, dr = V(0, -1.05, -0.2), V(0.18, -0.25, -1)
	local gl, dl = V(0, -1.05, -0.2), V(-0.18, -0.25, -1)
	TENGAN_DUAL = join(cleaver("Right Arm", gr, dr, 90), cleaver("Left Arm", gl, dl, 90))
	local pr = V(1.5, 0, 0) + gr - dr.Unit * 1.05
	local pl = V(-1.5, 0, 0) + gl - dl.Unit * 1.05
	local mid = (pr + pl) / 2 + V(0, -0.6, 0.15)
	for _, p in chain("Torso", { pr, (pr + mid) / 2 + V(0, -0.15, 0), mid, (pl + mid) / 2 + V(0, -0.15, 0), pl }, { 0.13 }, rgb(196, 170, 90), { material = "Metal" }) do
		table.insert(TENGAN_DUAL, p)
	end
end
-- Tengan ★3 : perles explosives en suspension
local BEADS = {}
for k = 0, 4 do
	local a = math.rad(-40 + k * 20)
	table.insert(BEADS, {
		shape = "ball",
		limb = "Torso",
		at = V(math.sin(a) * 2.2, 1.6 + (k % 2) * 0.3, -math.cos(a) * 1.4),
		size = V(0.3, 0.3, 0.3),
		color = rgb(255, 150, 60),
		material = "Neon",
	})
end

-- Ijichu : talisman de papier (ofuda) tenu dans la main ; ★3 : talismans en orbite
local function ofuda(limb: string, at: Vector3, rot: Vector3)
	return {
		shape = "block",
		limb = limb,
		at = at,
		rot = rot,
		size = V(0.3, 0.7, 0.03),
		color = rgb(244, 236, 214),
		paint = {
			kind = "strokes",
			faces = { "Front", "Back" },
			ink = rgb(176, 28, 36),
			lines = { { 0.5, 0.12, 0.5, 0.88, 0.04 }, { 0.25, 0.3, 0.75, 0.3, 0.03 }, { 0.3, 0.55, 0.7, 0.62, 0.03 }, { 0.25, 0.78, 0.75, 0.74, 0.03 } },
		},
	}
end
local IJICHU_TIE = {
	{ shape = "block", limb = "Torso", at = V(0, 0.42, -0.515), size = V(0.16, 0.82, 0.03), color = rgb(30, 34, 52) },
	{ shape = "block", limb = "Torso", at = V(0, 0.86, -0.52), size = V(0.2, 0.13, 0.05), color = rgb(24, 26, 40) },
}
local IJICHU_ORBIT = {}
for k = 0, 4 do
	local a = math.rad(k * 72 + 20)
	table.insert(IJICHU_ORBIT, ofuda("Torso", V(math.cos(a) * 2.1, 0.9 + (k % 2) * 0.4, math.sin(a) * 1.6), V(0, -math.deg(a) + 90, (k % 2) * 14 - 7)))
end

Characters.List = {
	------------------------------------------------------------------
	-- VILLAGE NINJA (inspiré de Naruto)
	------------------------------------------------------------------
	ninja_rokli = {
		name = "Rok Li",
		universe = "ninja",
		rarity = "common",
		look = {
			skin = SKIN,
			hair = "bowl",
			hairColor = rgb(20, 20, 25),
			top = rgb(70, 150, 60),
			topAccent = rgb(45, 110, 40),
			bottom = rgb(70, 150, 60),
			outfit = "jumpsuit",
			face = "fierce",
			eyeStyle = "round",
			mouthStyle = "smile",
			browStyle = "thick",
			bigBrows = true,
			accessories = { "leg_warmers", "headband_belt" },
			accColor = rgb(255, 120, 30),
			eyes = rgb(25, 25, 30),
			eyeWidth = 0.24,
			eyeHeight = 0.22,
			mouthWidth = 0.36,
		},
		evolve = {
			-- ★★ : portes ouvertes (peau rougie, vapeur)
			[2] = { skin = rgb(255, 176, 150), armVeins = rgb(196, 70, 80), accessories = { "leg_warmers", "headband_belt", "steam" } },
			-- ★★★ : huitième porte (aura de sang verte, yeux blancs)
			[3] = {
				skin = rgb(255, 150, 130),
				armVeins = rgb(196, 70, 80),
				eyes = rgb(240, 255, 240),
				pupil = "none",
				accessories = { "leg_warmers", "headband_belt", "steam", "ssj_aura" },
				auraColor = rgb(120, 255, 150),
			},
		},
		attack = { kind = "punch", color = rgb(255, 240, 200), name = "Lotus Recto" },
		fusion = { prefix = "Fougueux", suffix = "de la Jeunesse" },
	},
	ninja_konohamaro = {
		name = "Konohamaro",
		universe = "ninja",
		rarity = "common",
		look = {
			eyes = rgb(70, 48, 34),
			skin = SKIN,
			hair = "spiky",
			hairColor = rgb(120, 75, 40),
			top = rgb(235, 200, 90),
			topAccent = rgb(200, 160, 60),
			bottom = rgb(90, 95, 110),
			outfit = "shirt",
			face = "happy",
			eyeStyle = "round",
			mouthStyle = "smile",
			browStyle = "bold",
			accessories = { "scarf_long", "headband" },
			accColor = rgb(60, 110, 210),
		},
		evolve = {
			-- ★★ : orbe spirale dans la main
			[2] = { accessories = { "scarf_long", "headband", "energy_fists" }, energyColor = rgb(110, 180, 255) },
			-- ★★★ : adulte (cheveux en bataille, gilet de ninja confirmé)
			[3] = { hair = "messy", outfit = "flakvest", top = rgb(90, 110, 70), accessories = { "scarf_long", "headband", "energy_fists" }, energyColor = rgb(110, 180, 255) },
		},
		attack = { kind = "orb", color = rgb(110, 200, 255), name = "Mini Orbe" },
		fusion = { prefix = "Petit", suffix = "Apprenti" },
	},
	ninja_sakoura = {
		name = "Sakoura",
		universe = "ninja",
		rarity = "rare",
		look = {
			skin = SKIN,
			hair = "long",
			hairColor = rgb(255, 150, 190),
			top = rgb(210, 40, 55),
			topAccent = rgb(240, 240, 240),
			bottom = rgb(70, 60, 70),
			outfit = "qipao",
			logo = { kind = "circle", color = rgb(245, 245, 245), back = true },
			eyes = rgb(60, 180, 100),
			face = "fierce",
			eyeStyle = "feminine",
			mouthStyle = "pout",
			browStyle = "arched",
			blush = true,
			accessories = { "headband" },
			sleeveless = true,
			forehead = true,
			headbandY = 0.62,
			headbandRadius = 0.73,
			headbandColor = rgb(200, 30, 45),
		},
		evolve = {
			-- ★★ : cheveux coupés court, poings chargés
			[2] = { hair = "bob", accessories = { "headband", "energy_fists" }, energyColor = rgb(255, 130, 190) },
			-- ★★★ : sceau des cent (marques violettes) et aura rose
			[3] = {
				hair = "bob",
				accessories = { "headband", "energy_fists", "energy_aura", "tattoos_blue" },
				energyColor = rgb(255, 130, 190),
				auraColor = rgb(255, 150, 200),
				eyeGlow = true,
			},
		},
		attack = { kind = "punch", color = rgb(255, 120, 180), name = "Poing Cerisier" },
		fusion = { prefix = "Cerisier", suffix = "du Cerisier" },
	},
	ninja_shikamaro = {
		name = "Shikamaro",
		universe = "ninja",
		rarity = "rare",
		look = {
			eyes = rgb(44, 40, 38),
			skin = SKIN,
			hair = "ponytail_spiky",
			hairColor = rgb(35, 35, 45),
			top = rgb(70, 80, 100),
			topAccent = rgb(100, 115, 70),
			bottom = rgb(45, 55, 75),
			outfit = "flakvest",
			face = "calm",
			eyeStyle = "sleepy",
			mouthStyle = "sad",
			browStyle = "flat",
			accessories = { "earrings_stud" },
		},
		evolve = {
			-- ★★ : ombres qui s'étendent (poings d'ombre)
			[2] = { accessories = { "earrings_stud", "energy_fists" }, energyColor = rgb(50, 40, 70), eyes = rgb(70, 60, 50) },
			-- ★★★ : stratège (gilet sombre, cape, aura d'ombre)
			[3] = { top = rgb(56, 66, 56), accessories = { "earrings_stud", "cape", "energy_aura" }, capeColor = rgb(40, 44, 40), auraColor = rgb(90, 70, 130) },
		},
		attack = { kind = "shadow", color = rgb(25, 20, 35), name = "Étreinte d'Ombre" },
		fusion = { prefix = "Stratège", suffix = "des Ombres" },
	},
	ninja_sasuki = {
		name = "Sasuki",
		universe = "ninja",
		rarity = "epic",
		look = {
			headScale = Vector3.new(0.92, 1.03, 0.96), -- visage étroit
			skin = SKIN,
			hair = "spiky_back",
			hairColor = rgb(34, 36, 62),
			top = rgb(40, 52, 104),
			topAccent = rgb(30, 38, 80),
			bottom = rgb(236, 236, 242),
			pants = "shorts",
			shortsLength = 0.55,
			outfit = "highcollar",
			sleeveEnd = 0.36,
			logo = { kind = "fan", color = rgb(220, 30, 40), back = true },
			armWarmers = rgb(226, 228, 238),
			legWraps = rgb(238, 234, 226),
			legWrapTop = 0.62,
			footwear = "sandals",
			shoes = rgb(40, 50, 100),
			eyes = rgb(220, 20, 30),
			face = "angry",
			eyeStyle = "sharp",
			mouthStyle = "frown",
			browStyle = "frown",
			accessories = { "sword_back" },
			accColor = rgb(90, 60, 140),
			pupil = "tomoe",
		},
		attack = { kind = "lightning", color = rgb(130, 200, 255), name = "Mille Oiseaux" },
		evolve = {
			-- ★★ : marque maudite + Mille Oiseaux dans la main
			[2] = { accessories = { "sword_back", "curse_mark", "chidori" }, curseSpread = true, eyeGlow = true },
			-- ★★★ : tenue de l'exil (chemise blanche ouverte, corde violette)
			[3] = {
				top = rgb(240, 240, 245),
				topAccent = rgb(120, 70, 190),
				bottom = rgb(35, 35, 50),
				outfit = "openrobe",
				logo = false,
				pants = false,
				sleeveEnd = false,
				armWarmers = false,
				accessories = { "sword_back", "chidori", "rope_belt" },
				beltColor = rgb(110, 60, 170),
				energyColor = rgb(170, 120, 255),
				curseSpread = false,
			},
		},
		fusion = { prefix = "Vengeur", suffix = "Vengeur" },
	},
	ninja_kakashu = {
		name = "Kakashu",
		universe = "ninja",
		rarity = "epic",
		look = {
			skin = SKIN,
			hair = "wild",
			hairColor = rgb(214, 218, 228),
			hairTilt = -0.4,
			top = rgb(44, 54, 86),
			topAccent = rgb(100, 120, 72),
			bottom = rgb(44, 54, 86),
			outfit = "flakvest",
			logo = { kind = "spiral", color = rgb(200, 40, 40), back = true },
			shoulderMark = { kind = "spiral", color = rgb(200, 40, 40) },
			holster = rgb(44, 54, 86),
			legWraps = rgb(236, 232, 224),
			legWrapTop = 0.64,
			footwear = "sandals",
			shoes = rgb(44, 54, 86),
			eyes = rgb(30, 30, 30),
			face = "calm",
			eyeStyle = "sleepy",
			mouthStyle = "line",
			browStyle = "raised",
			accessories = { "mask_lower", "headband_tilted" },
			accColor = rgb(44, 54, 86),
		},
		evolve = {
			-- ★★ : bandeau relevé (œil rouge et cicatrice) et lame d'éclairs dans la main
			[2] = { accessories = { "mask_lower", "headband", "scar_eye", "chidori" }, eyes = rgb(60, 60, 70), energyColor = rgb(150, 210, 255) },
			-- ★★★ : cape blanche du chef du village, aura bleue
			[3] = { accessories = { "mask_lower", "headband", "scar_eye", "cape", "energy_aura" }, capeColor = rgb(240, 240, 245), auraColor = rgb(120, 180, 255), eyeGlow = true },
		},
		attack = { kind = "lightning", color = rgb(170, 220, 255), name = "Lame Foudroyante" },
		fusion = { prefix = "Copieur", suffix = "Copieur" },
	},
	ninja_maruto = {
		name = "Maruto",
		universe = "ninja",
		rarity = "epic",
		-- Copie fidèle de l'avatar "Kid Naruto" (couleurs prises à la pipette sur la capture).
		look = {
			skin = rgb(248, 210, 168),
			hair = "spiky",
			hairColor = rgb(242, 227, 58),
			hairUnder = rgb(201, 181, 32),
			hairShine = rgb(250, 244, 135),
			hairDarken = 0.3,
			earLocks = true,
			browColor = rgb(200, 182, 40),
			top = rgb(206, 122, 56),
			shoulders = rgb(18, 34, 92),
			collar = "fur",
			collarColor = rgb(226, 232, 238),
			bottom = rgb(206, 122, 56),
			outfit = "jacket",
			pantsStyle = "ninja",
			logo = { kind = "spiral", color = rgb(210, 40, 35), bg = rgb(245, 245, 245), back = true },
			holster = rgb(18, 34, 92),
			holsterStyle = "band",
			footwear = "sandals",
			shoes = rgb(22, 38, 98),
			headbandColor = rgb(18, 32, 90),
			headbandY = 0.3,
			headbandHeight = 0.42,
			plateColor = rgb(176, 192, 208),
			eyes = rgb(22, 70, 190),
			-- Yeux grands comme sur la référence (~40 % de la largeur du visage), un peu plus bas
			eyeX = 0.3,
			eyeY = -0.105,
			eyeWidth = 0.39,
			eyeHeight = 0.247,
			browY = 0.135,
			browThin = true,
			face = "fierce",
			eyeStyle = "round",
			mouthStyle = "toothy",
			browStyle = "thin",
			lashThickness = 0.04,
			accessories = { "headband", "whiskers" },
			whiskerColor = rgb(200, 150, 120),
			mouthWidth = 0.13,
			mouthY = -0.42,
			noseY = -0.29,
		},
		attack = { kind = "orb", color = rgb(90, 190, 255), name = "Orbe Spirale" },
		evolve = {
			-- ★★ : Mode Ermite (comme "Maturo (Sage)")
			[2] = {
				eyes = rgb(255, 170, 30),
				eyeShadow = rgb(255, 120, 30),
				accessories = { "headband", "whiskers", "haori_sage" },
				accColor = rgb(200, 40, 40),
			},
			-- ★★★ : Mode Démon Renard
			[3] = {
				top = rgb(255, 200, 50),
				topAccent = rgb(30, 30, 30),
				bottom = rgb(30, 30, 30),
				outfit = "chakra",
				shoulders = false,
				collar = false,
				shoulderMark = false,
				holster = false,
				eyes = rgb(255, 110, 0),
				eyeShadow = false,
				accessories = { "whiskers", "cape" },
				accColor = rgb(255, 180, 40),
			},
		},
		fusion = { prefix = "Renard", suffix = "du Renard" },
	},
	ninja_itochi = {
		name = "Itochi",
		universe = "ninja",
		rarity = "mythic",
		look = {
			headScale = Vector3.new(0.92, 1.03, 0.96), -- visage étroit
			skin = SKIN,
			hair = "long_bangs",
			hairColor = rgb(22, 22, 28),
			top = rgb(22, 22, 28),
			topAccent = rgb(210, 20, 30),
			bottom = rgb(22, 22, 28),
			outfit = "cloak",
			eyes = rgb(220, 20, 30),
			face = "calm",
			eyeStyle = "narrow",
			mouthStyle = "line",
			browStyle = "short",
			accessories = { "cloak_skirt", "headband_scratched", "tear_lines", "collar_high" },
			accColor = rgb(22, 22, 28),
			pupil = "tomoe",
			collarColor = rgb(22, 22, 28),
			collarLining = rgb(200, 25, 35),
			tailLength = 1.3,
			sidelockLength = 0.62,
		},
		evolve = {
			-- ★★ : yeux rouges à trois virgules, illusion (aura rouge sombre)
			[2] = {
				eyes = rgb(220, 20, 30),
				pupil = "tomoe",
				eyeGlow = true,
				accessories = { "cloak_skirt", "headband_scratched", "tear_lines", "collar_high", "energy_aura" },
				auraColor = rgb(170, 20, 40),
			},
			-- ★★★ : kaléidoscope (anneaux) et armure spectrale de flammes rouges
			[3] = {
				eyes = rgb(220, 20, 30),
				pupil = "ring",
				eyeGlow = true,
				accessories = { "cloak_skirt", "headband_scratched", "tear_lines", "collar_high", "ssj_aura" },
				auraColor = rgb(255, 90, 70),
			},
		},
		attack = { kind = "flame", color = rgb(70, 20, 90), name = "Flammes Noires" },
		fusion = { prefix = "Écarlate", suffix = "Écarlate" },
	},

	------------------------------------------------------------------
	-- ACADÉMIE OCCULTE (inspiré de Jujutsu Kaisen)
	------------------------------------------------------------------
	occ_toudo = {
		name = "Toudo",
		universe = "occulte",
		rarity = "epic",
		look = {
			eyes = rgb(80, 56, 40),
			headScale = Vector3.new(1.1, 0.97, 1.05), -- mâchoire large de brute
			jawShade = true,
			skin = SKIN_TAN,
			hair = "topknot",
			hairColor = rgb(40, 30, 25),
			top = rgb(32, 36, 58),
			underColor = rgb(245, 245, 240),
			bottom = rgb(40, 45, 70),
			outfit = "openjacket",
			sleeves = "short",
			sleeveEnd = 0.5,
			hemColor = rgb(52, 58, 88),
			waistband = rgb(30, 30, 40),
			face = "fierce",
			eyeStyle = "narrow",
			mouthStyle = "smirk",
			browStyle = "thick",
			accessories = { "scar_eye" },
		},
		evolve = {
			-- ★★ : carrure de brute (deltoïdes, trapèzes)
			[2] = { accessories = { "scar_eye", "bulk" } },
			-- ★★★ : torse nu, aura (frappe noire)
			[3] = { outfit = "shirtless", accessories = { "scar_eye", "bulk", "energy_aura" }, auraColor = rgb(40, 30, 50) },
		},
		attack = { kind = "punch", color = rgb(120, 140, 255), name = "Frappe Bravo" },
		fusion = { prefix = "Frère", suffix = "Fraternel" },
	},
	occ_inumako = {
		name = "Inumako",
		universe = "occulte",
		rarity = "rare",
		look = {
			skin = SKIN,
			hair = "short",
			hairColor = rgb(235, 235, 245),
			top = rgb(35, 32, 43),
			bottom = rgb(35, 32, 43),
			hemColor = rgb(44, 40, 54),
			outfit = "highcollar",
			frontZip = true,
			eyes = rgb(120, 150, 200),
			face = "calm",
			eyeStyle = "soft",
			mouthStyle = "line",
			browStyle = "flat",
			accessories = { "collar_high" },
			accColor = rgb(35, 32, 43),
			collarColor = rgb(35, 32, 43),
		},
		evolve = {
			-- ★★ : col baissé (la parole maudite), aura violette
			[2] = { accessories = { "energy_aura" }, mouthStyle = "shout", auraColor = rgb(170, 90, 255) },
			-- ★★★ : yeux qui brillent, ondes d'énergie dans les mains
			[3] = { accessories = { "energy_aura", "energy_fists" }, mouthStyle = "shout", eyes = rgb(190, 120, 255), eyeGlow = true, energyColor = rgb(170, 90, 255) },
		},
		attack = { kind = "shadow", color = rgb(120, 90, 200), name = "Parole Maudite" },
		fusion = { prefix = "Murmurant", suffix = "Maudit" },
	},
	occ_nobora = {
		name = "Nobora",
		universe = "occulte",
		rarity = "common",
		look = {
			skin = SKIN,
			hair = "bob",
			fringeLength = 0.7,
			hairColor = rgb(175, 95, 55),
			top = rgb(36, 34, 54),
			bottom = rgb(24, 22, 28),
			pantsStyle = "plain",
			skirtColor = rgb(36, 34, 54),
			beltColor = rgb(120, 78, 48),
			footwear = "boots",
			shoes = rgb(70, 45, 35),
			outfit = "uniform",
			eyes = rgb(120, 70, 40),
			face = "fierce",
			eyeStyle = "feminine",
			mouthStyle = "smirk",
			browStyle = "bold",
			accessories = { "pleated_skirt", "hammer" },
			accColor = rgb(110, 80, 60),
		},
		evolve = {
			-- ★★ : résonance (clous chargés dans la main)
			[2] = { accessories = { "pleated_skirt", "hammer", "energy_fists" }, energyColor = rgb(120, 200, 255) },
			-- ★★★ : cicatrice et aura de résonance
			[3] = { accessories = { "pleated_skirt", "hammer", "scar_eye", "energy_aura" }, auraColor = rgb(120, 200, 255), eyeGlow = true },
		},
		attack = { kind = "slash", color = rgb(255, 170, 60), name = "Clous Résonnants" },
		fusion = { prefix = "Marteau", suffix = "Résonnant" },
	},
	occ_megumo = {
		name = "Megumo",
		universe = "occulte",
		rarity = "rare",
		look = {
			skin = SKIN,
			hair = "hedgehog",
			hairColor = rgb(22, 24, 40),
			top = rgb(27, 31, 51),
			bottom = rgb(27, 31, 51),
			outfit = "uniform",
			uniformStyle = "spiral",
			eyes = rgb(40, 100, 120),
			face = "calm",
			eyeStyle = "narrow",
			mouthStyle = "frown",
			browStyle = "flat",
		},
		evolve = {
			-- ★★ : ombres des shikigamis dans les mains
			[2] = { accessories = { "energy_fists" }, energyColor = rgb(40, 30, 80), eyes = rgb(70, 110, 150) },
			-- ★★★ : possédé (marques noires, yeux rouges, aura sombre)
			[3] = { accessories = { "tattoos", "energy_aura" }, eyes = rgb(200, 30, 50), auraColor = rgb(160, 30, 60) },
		},
		attack = { kind = "shadow", color = rgb(20, 30, 70), name = "Chiens d'Ombre" },
		fusion = { prefix = "Invocateur", suffix = "des Ombres Divines" },
	},
	occ_yuzi = {
		name = "Yuzi",
		universe = "occulte",
		rarity = "epic",
		look = {
			skin = SKIN,
			hair = "short",
			hairColor = rgb(255, 140, 165),
			top = rgb(30, 34, 58),
			bottom = rgb(30, 34, 58),
			outfit = "uniform",
			eyes = rgb(130, 75, 45),
			face = "fierce",
			eyeStyle = "round",
			mouthStyle = "smile",
			browStyle = "bold",
			accessories = { "hood" },
			accColor = rgb(210, 35, 45),
			hairLength = 1.5,
			hairUnder = rgb(90, 50, 55),
		},
		attack = { kind = "punch", color = rgb(60, 90, 255), name = "Poing Divergent" },
		evolve = {
			-- ★★ : poings divergents (énergie maudite bleue)
			-- (marques de Sukana sous les yeux, ongles noirs)
			[2] = {
				accessories = { "hood", "energy_fists", "energy_aura", "scar_cheek" },
				energyColor = rgb(70, 110, 255),
				eyeMarks = rgb(30, 22, 30),
				nails = rgb(30, 22, 30),
			},
			-- ★★★ : le roi des fléaux prend le dessus (tenue blanche, marques, éclair noir et rouge)
			[3] = {
				top = rgb(238, 236, 232),
				topAccent = rgb(40, 36, 44),
				outfit = "robe",
				accessories = { "tattoos", "energy_fists", "energy_aura" },
				energyColor = rgb(230, 30, 50),
				auraColor = rgb(200, 30, 50),
				eyes = rgb(200, 30, 40),
				eyeMarks = false,
				nails = rgb(30, 22, 30),
			},
		},
		fusion = { prefix = "Divergent", suffix = "Divergent" },
	},
	occ_mako = {
		name = "Mako",
		universe = "occulte",
		rarity = "epic",
		look = {
			skin = SKIN,
			hair = "ponytail",
			hairColor = rgb(40, 75, 55),
			top = rgb(34, 38, 44),
			bottom = rgb(34, 38, 44),
			outfit = "uniform",
			uniformStyle = "zip",
			beltColor = rgb(95, 70, 50),
			pants = "kimono",
			kimonoLength = 0.8,
			eyes = rgb(150, 110, 60),
			face = "fierce",
			eyeStyle = "narrow",
			mouthStyle = "frown",
			browStyle = "arched",
			accessories = { "glasses", "spear" },
			accColor = rgb(120, 100, 70),
		},
		evolve = {
			-- ★★ : lunettes retirées, cheveux courts
			[2] = { hair = "short", accessories = { "spear" }, eyeStyle = "sharp" },
			-- ★★★ : corps céleste (cicatrices, aura)
			[3] = { hair = "short", accessories = { "spear", "scar_face", "energy_aura" }, eyeStyle = "sharp", auraColor = rgb(120, 230, 160), eyes = rgb(90, 200, 130) },
		},
		attack = { kind = "slash", color = rgb(110, 220, 120), name = "Lance Maudite" },
		fusion = { prefix = "Héritière", suffix = "Maudite" },
	},
	occ_goju = {
		name = "Goju",
		universe = "occulte",
		rarity = "mythic",
		look = {
			skin = SKIN,
			hair = "wild",
			hairColor = rgb(245, 246, 255),
			top = rgb(26, 28, 40),
			bottom = rgb(26, 28, 40),
			hemColor = rgb(32, 34, 48),
			outfit = "highcollar",
			frontZip = true,
			collarButton = rgb(70, 78, 110),
			shoes = rgb(22, 22, 28),
			eyes = rgb(80, 210, 255),
			face = "smirk",
			eyeStyle = "soft",
			mouthStyle = "smirk",
			browStyle = "raised",
			accessories = { "blindfold" },
			accColor = rgb(22, 22, 30),
			hairLength = 0.85,
		},
		attack = { kind = "orb", color = rgb(170, 60, 255), name = "Violet Imaginaire" },
		evolve = {
			-- ★★ : il retire le bandeau (cheveux qui retombent, les Six Yeux brillent)
			[2] = { accessories = {}, hair = "messy", eyeShadow = rgb(150, 230, 255), eyeGlow = true },
			-- ★★★ : orbe violet de la technique du vide et aura violette
			[3] = { accessories = { "hollow_purple", "energy_aura" }, hair = "messy", eyeShadow = rgb(150, 230, 255), eyeGlow = true, auraColor = rgb(170, 80, 255) },
		},
		fusion = { prefix = "Infini", suffix = "de l'Infini" },
	},
	occ_sukana = {
		name = "Sukana",
		universe = "occulte",
		rarity = "secret",
		look = {
			skin = SKIN,
			hair = "slick_up",
			hairColor = rgb(255, 150, 175),
			hairUnder = rgb(120, 60, 70),
			top = rgb(245, 240, 232),
			topAccent = rgb(30, 30, 30),
			bottom = rgb(34, 32, 38),
			outfit = "robe",
			sleeves = "short",
			sleeveEnd = 0.5,
			footwear = "zori",
			shoes = rgb(70, 50, 45),
			eyes = rgb(200, 30, 40),
			face = "smirk",
			eyeStyle = "sharp",
			mouthStyle = "fang",
			browStyle = "frown",
			accessories = { "tattoos", "extra_eyes" },
		},
		evolve = {
			-- ★★ : énergie maudite rouge dans les mains, yeux qui brillent
			[2] = { accessories = { "tattoos", "extra_eyes", "energy_fists" }, energyColor = rgb(200, 20, 40), eyeGlow = true },
			-- ★★★ : vraie forme (kimono noir, flèche de feu, aura)
			[3] = {
				top = rgb(34, 28, 34),
				accessories = { "tattoos", "extra_eyes", "sun_flames", "energy_aura" },
				energyColor = rgb(255, 110, 40),
				auraColor = rgb(200, 30, 40),
				eyeGlow = true,
			},
		},
		attack = { kind = "slash", color = rgb(255, 40, 60), name = "Découpe Démoniaque" },
		fusion = { prefix = "Fléau", suffix = "des Fléaux" },
	},

	------------------------------------------------------------------
	-- PLANÈTE DES GUERRIERS (inspiré de Dragon Ball)
	------------------------------------------------------------------
	sai_yamcho = {
		name = "Yamcho",
		universe = "saiyan",
		rarity = "common",
		look = {
			eyes = rgb(66, 46, 34),
			skin = SKIN,
			hair = "messy",
			hairColor = rgb(25, 25, 30),
			top = rgb(255, 125, 25),
			topAccent = rgb(40, 70, 170),
			bottom = rgb(255, 125, 25),
			outfit = "gi",
			face = "fierce",
			eyeStyle = "bold",
			mouthStyle = "smirk",
			browStyle = "bold",
			accessories = { "scar_cheek", "belt" },
			accColor = rgb(40, 70, 170),
		},
		evolve = {
			-- ★★ : poing du loup (énergie bleue)
			[2] = { accessories = { "scar_cheek", "belt", "energy_fists" }, energyColor = rgb(110, 170, 255) },
			-- ★★★ : cheveux courts, cicatrice à l'œil, aura
			[3] = { hair = "short", accessories = { "scar_cheek", "scar_eye", "belt", "energy_aura" }, auraColor = rgb(120, 180, 255) },
		},
		attack = { kind = "punch", color = rgb(255, 240, 150), name = "Poing du Loup" },
		fusion = { prefix = "Loup", suffix = "du Désert" },
	},
	sai_krilin = {
		name = "Krilin",
		universe = "saiyan",
		rarity = "common",
		look = {
			eyes = rgb(46, 42, 42),
			skin = SKIN,
			hair = "bald",
			hairColor = SKIN,
			top = rgb(255, 125, 25),
			topAccent = rgb(40, 70, 170),
			bottom = rgb(255, 125, 25),
			outfit = "gi",
			logo = { kind = "kanji", text = "亀", color = rgb(20, 20, 20), bg = rgb(255, 255, 255) },
			face = "happy",
			eyeStyle = "round",
			mouthStyle = "smile",
			browStyle = "raised",
			accessories = { "dots", "belt" },
			accColor = rgb(40, 70, 170),
		},
		evolve = {
			-- ★★ : cheveux qui ont repoussé
			[2] = { hair = "short", hairColor = rgb(25, 22, 28) },
			-- ★★★ : disque destructeur au-dessus de la main
			[3] = { hair = "short", hairColor = rgb(25, 22, 28), accessories = { "dots", "belt", "energy_fists" }, energyColor = rgb(255, 230, 80) },
		},
		attack = { kind = "slash", color = rgb(255, 230, 80), name = "Disque Tranchant" },
		fusion = { prefix = "Moine", suffix = "Chauve" },
	},
	sai_piccola = {
		name = "Piccola",
		universe = "saiyan",
		rarity = "rare",
		look = {
			skin = rgb(110, 190, 90),
			hair = "none",
			hairColor = rgb(110, 190, 90),
			top = rgb(100, 50, 140),
			topAccent = rgb(70, 35, 100),
			bottom = rgb(100, 50, 140),
			outfit = "gi",
			eyes = rgb(30, 30, 30),
			face = "angry",
			eyeStyle = "sharp",
			mouthStyle = "frown",
			browStyle = "frown",
			accessories = { "turban", "cape", "antennae", "belt" },
			accColor = rgb(245, 245, 245),
		},
		evolve = {
			-- ★★ : turban et cape retirés
			[2] = { accessories = { "antennae", "belt" } },
			-- ★★★ : rayon spécial (doigts chargés, yeux qui brillent)
			[3] = { accessories = { "antennae", "belt", "energy_fists", "energy_aura" }, energyColor = rgb(230, 255, 120), auraColor = rgb(200, 255, 140), eyeGlow = true },
		},
		attack = { kind = "beam", color = rgb(255, 230, 90), name = "Rayon Perforant" },
		fusion = { prefix = "Namek", suffix = "Perforant" },
	},
	sai_c81 = {
		name = "Androïde 81",
		universe = "saiyan",
		rarity = "rare",
		look = {
			skin = SKIN,
			hair = "bob",
			hairColor = rgb(255, 225, 130),
			top = rgb(70, 110, 170),
			topAccent = rgb(30, 30, 35),
			bottom = rgb(70, 110, 170),
			outfit = "denim",
			eyes = rgb(60, 140, 220),
			face = "calm",
		},
		evolve = {
			-- ★★ : rafale d'énergie dans les mains
			[2] = { accessories = { "energy_fists" }, energyColor = rgb(120, 200, 255) },
			-- ★★★ : cheveux longs, foulard, aura
			[3] = { hair = "long", accessories = { "scarf_long", "energy_aura" }, accColor = rgb(230, 120, 60), auraColor = rgb(140, 210, 255) },
		},
		attack = { kind = "beam", color = rgb(120, 200, 255), name = "Rafale Énergétique" },
		fusion = { prefix = "Androïde", suffix = "Infinie" },
	},
	sai_vejeta = {
		name = "Vejeta",
		universe = "saiyan",
		rarity = "epic",
		look = {
			eyes = rgb(40, 38, 52),
			skin = SKIN,
			hair = "flame",
			hairColor = rgb(22, 22, 32),
			top = rgb(35, 55, 160),
			topAccent = rgb(245, 245, 235),
			bottom = rgb(35, 55, 160),
			shoes = rgb(245, 245, 235),
			outfit = "armor",
			face = "angry",
			eyeStyle = "sharp",
			mouthStyle = "frown",
			browStyle = "frown",
			accessories = { "shoulder_pads" },
			accColor = rgb(235, 200, 90),
		},
		attack = { kind = "beam", color = rgb(200, 90, 255), name = "Canon Galactique" },
		evolve = {
			-- ★★ : super guerrier (cheveux dorés, aura dorée)
			[2] = { hairColor = rgb(255, 220, 60), eyes = rgb(60, 200, 160), accessories = { "shoulder_pads", "ssj_aura" } },
			-- ★★★ : divin (cheveux et yeux bleus, aura bleue)
			[3] = { hairColor = rgb(80, 140, 255), eyes = rgb(80, 140, 255), accessories = { "shoulder_pads", "energy_aura" }, auraColor = rgb(90, 160, 255) },
		},
		fusion = { prefix = "Prince", suffix = "Galactique" },
	},
	sai_gohon = {
		name = "Gohon",
		universe = "saiyan",
		rarity = "epic",
		look = {
			eyes = rgb(40, 40, 56),
			skin = SKIN,
			hair = "tousled",
			hairColor = rgb(22, 22, 32),
			top = rgb(110, 50, 150),
			topAccent = rgb(230, 60, 50),
			bottom = rgb(110, 50, 150),
			outfit = "gi",
			face = "fierce",
			eyeStyle = "soft",
			mouthStyle = "smile",
			browStyle = "raised",
			accessories = { "belt" },
			accColor = rgb(230, 60, 50),
		},
		attack = { kind = "beam", color = rgb(110, 190, 255), name = "Masenko" },
		evolve = {
			-- ★★ : super guerrier 2 (cheveux dorés, éclairs dans l'aura)
			[2] = { hairColor = rgb(255, 220, 60), eyes = rgb(60, 200, 160), accessories = { "belt", "ssj_aura" } },
			-- ★★★ : forme bête (cheveux argentés dressés, yeux rouges)
			[3] = {
				hair = "wild",
				hairLength = 1.2,
				hairColor = rgb(232, 232, 242),
				eyes = rgb(220, 30, 40),
				accessories = { "belt", "energy_aura" },
				auraColor = rgb(220, 60, 90),
			},
		},
		fusion = { prefix = "Prodige", suffix = "Prodige" },
	},
	sai_goko = {
		name = "Goko",
		universe = "saiyan",
		rarity = "mythic",
		look = {
			eyes = rgb(34, 32, 44),
			skin = SKIN,
			hair = "goku",
			hairColor = rgb(22, 22, 32),
			top = rgb(255, 125, 25),
			topAccent = rgb(35, 60, 170),
			bottom = rgb(255, 125, 25),
			sleeveColor = rgb(35, 60, 170),
			hemColor = rgb(28, 48, 140),
			shoes = rgb(35, 60, 170),
			footwear = "boots",
			bootTop = 0.7,
			bootTrim = rgb(225, 45, 40),
			bootLace = rgb(240, 200, 60),
			outfit = "gi",
			logo = { kind = "kanji", text = "悟", color = rgb(20, 20, 20), bg = rgb(255, 255, 255), back = true },
			face = "fierce",
			eyeStyle = "bold",
			mouthStyle = "grin",
			browStyle = "bold",
			mouthWidth = 0.21,
			accessories = { "tail", "wristbands" },
			accColor = rgb(35, 60, 170),
		},
		attack = { kind = "beam", color = rgb(70, 170, 255), name = "Vague Déferlante" },
		evolve = {
			-- ★★ : Super Saiyan (mèches dressées vers le haut, une seule mèche de frange)
			[2] = { hair = "wild", hairColor = rgb(255, 220, 60), eyes = rgb(60, 200, 160) },
			-- ★★★ : Super Saiyan 3 (crinière jusqu'au bas du dos, sans sourcils, aura dorée)
			[3] = {
				hair = "ssj3",
				hairColor = rgb(255, 216, 58),
				eyes = rgb(60, 200, 160),
				browStyle = "none",
				mouthStyle = "teeth",
				accessories = { "tail", "wristbands", "brow_ridge", "ssj_aura" },
			},
		},
		fusion = { prefix = "Saiyen", suffix = "Légendaire" },
	},
	sai_beeros = {
		name = "Beeros",
		universe = "saiyan",
		rarity = "mythic",
		look = {
			skin = rgb(150, 110, 200),
			hair = "none",
			hairColor = rgb(150, 110, 200),
			top = rgb(20, 20, 25),
			topAccent = rgb(255, 200, 60),
			bottom = rgb(245, 240, 230),
			outfit = "egyptian",
			eyes = rgb(255, 230, 80),
			face = "smirk",
			eyeStyle = "sleepy",
			mouthStyle = "smirk",
			browStyle = "flat",
			accessories = { "cat_ears", "collar_gold" },
			accColor = rgb(255, 200, 60),
		},
		evolve = {
			-- ★★ : orbe de destruction
			[2] = { accessories = { "cat_ears", "collar_gold", "hollow_purple" }, energyColor = rgb(170, 70, 255) },
			-- ★★★ : dieu de la destruction (aura violette, yeux qui brillent)
			[3] = { accessories = { "cat_ears", "collar_gold", "hollow_purple", "energy_aura" }, energyColor = rgb(170, 70, 255), auraColor = rgb(170, 90, 255), eyeGlow = true },
		},
		attack = { kind = "orb", color = rgb(255, 120, 40), name = "Sphère de Destruction" },
		fusion = { prefix = "Destructeur", suffix = "de la Destruction" },
	},

	------------------------------------------------------------------
	-- GRAND OCÉAN (inspiré de One Piece)
	------------------------------------------------------------------
	oce_kobi = {
		name = "Kobi",
		universe = "ocean",
		rarity = "common",
		look = {
			eyes = rgb(96, 136, 190),
			skin = SKIN,
			hair = "short",
			hairColor = rgb(255, 160, 190),
			top = rgb(245, 245, 250),
			topAccent = rgb(40, 90, 200),
			bottom = rgb(40, 90, 200),
			outfit = "sailor",
			face = "happy",
			eyeStyle = "round",
			mouthStyle = "o",
			browStyle = "raised",
			accessories = { "glasses", "cap" },
			accColor = rgb(245, 245, 250),
		},
		evolve = {
			-- ★★ : capitaine de la marine (manteau de la justice)
			[2] = { accessories = { "cap", "marine_coat" } },
			-- ★★★ : sans casquette, cheveux en bataille, techniques de combat
			[3] = { hair = "messy", accessories = { "marine_coat", "energy_fists" }, energyColor = rgb(200, 220, 255) },
		},
		attack = { kind = "punch", color = rgb(220, 220, 255), name = "Rokushiki" },
		fusion = { prefix = "Recrue", suffix = "de la Marine" },
	},
	oce_buggi = {
		name = "Buggi",
		universe = "ocean",
		rarity = "common",
		look = {
			eyes = rgb(130, 46, 46),
			skin = rgb(250, 235, 225),
			hair = "long",
			hairColor = rgb(80, 140, 230),
			top = rgb(210, 40, 45),
			topAccent = rgb(255, 210, 70),
			bottom = rgb(240, 230, 210),
			outfit = "coat",
			face = "smirk",
			eyeStyle = "wide",
			mouthStyle = "teeth",
			browStyle = "raised",
			accessories = { "clown_nose", "bandana" },
			accColor = rgb(240, 230, 210),
		},
		evolve = {
			-- ★★ : capitaine (bandana retiré, cape)
			[2] = { accessories = { "clown_nose", "cape" }, capeColor = rgb(200, 40, 50) },
			-- ★★★ : empereur (manteau doré, sabre)
			[3] = { top = rgb(200, 150, 50), accessories = { "clown_nose", "cape", "sword_hip" }, capeColor = rgb(200, 40, 50) },
		},
		attack = { kind = "slash", color = rgb(255, 200, 120), name = "Découpage" },
		fusion = { prefix = "Clown", suffix = "Farceur" },
	},
	oce_usupp = {
		name = "Usupp",
		universe = "ocean",
		rarity = "rare",
		look = {
			eyes = rgb(76, 52, 36),
			skin = SKIN_TAN,
			hair = "curly",
			hairColor = rgb(30, 25, 25),
			top = rgb(210, 170, 100),
			topAccent = rgb(130, 95, 55),
			bottom = rgb(130, 95, 55),
			outfit = "overalls",
			face = "happy",
			eyeStyle = "wide",
			mouthStyle = "shout",
			browStyle = "raised",
			accessories = { "long_nose", "bandana" },
			accColor = rgb(240, 220, 120),
		},
		evolve = {
			-- ★★ : lunettes de tireur
			[2] = { accessories = { "long_nose", "bandana", "round_glasses" } },
			-- ★★★ : roi des tireurs (fluide de l'observation)
			[3] = { accessories = { "long_nose", "bandana", "round_glasses", "energy_aura" }, auraColor = rgb(255, 220, 90), eyeGlow = true },
		},
		attack = { kind = "orb", color = rgb(255, 80, 60), name = "Étoile de Feu" },
		fusion = { prefix = "Tireur", suffix = "Conteur" },
	},
	oce_nomi = {
		name = "Nomi",
		universe = "ocean",
		rarity = "rare",
		look = {
			skin = SKIN,
			hair = "long",
			hairColor = rgb(255, 130, 40),
			top = rgb(245, 245, 245),
			topAccent = rgb(60, 140, 220),
			bottom = rgb(60, 140, 220),
			outfit = "striped",
			eyes = rgb(140, 80, 40),
			face = "smirk",
			eyeStyle = "feminine",
			mouthStyle = "smile",
			browStyle = "arched",
			blush = true,
			sleeveless = true,
		},
		evolve = {
			-- ★★ : bâton climatique
			[2] = { accessories = { "spear" }, eyes = rgb(150, 90, 40) },
			-- ★★★ : nuage d'orage (aura électrique)
			[3] = { accessories = { "spear", "energy_aura" }, auraColor = rgb(120, 180, 255), eyeGlow = true, eyes = rgb(150, 90, 40) },
		},
		attack = { kind = "lightning", color = rgb(255, 240, 80), name = "Tempête Électrique" },
		fusion = { prefix = "Tempête", suffix = "des Tempêtes" },
	},
	oce_zoru = {
		name = "Zoru",
		universe = "ocean",
		rarity = "epic",
		look = {
			eyes = rgb(52, 52, 48),
			skin = SKIN_TAN,
			hair = "short",
			hairColor = rgb(95, 200, 95),
			top = rgb(245, 245, 245),
			bottom = rgb(32, 32, 36),
			outfit = "shirt",
			waistband = rgb(40, 120, 55),
			armband = rgb(26, 26, 30),
			footwear = "boots",
			bootTop = 0.7,
			shoes = rgb(28, 28, 32),
			face = "angry",
			eyeStyle = "narrow",
			mouthStyle = "frown",
			browStyle = "frown",
			accessories = { "swords", "scar_eye", "earrings_gold" },
			accColor = rgb(40, 110, 50),
		},
		evolve = {
			-- ★★ : bandana noué sur la tête (trois sabres)
			[2] = { accessories = { "swords", "scar_eye", "earrings_gold", "bandana" }, accColor = rgb(30, 30, 36) },
			-- ★★★ : roi des enfers (aura verte et noire, yeux qui brillent)
			[3] = { accessories = { "swords", "scar_eye", "earrings_gold", "bandana", "ssj_aura" }, accColor = rgb(30, 30, 36), auraColor = rgb(90, 200, 120), eyeGlow = true },
		},
		attack = { kind = "slash", color = rgb(120, 255, 140), name = "Trois Lames" },
		fusion = { prefix = "Sabreur", suffix = "aux Trois Lames" },
	},
	oce_sanjo = {
		name = "Sanjo",
		universe = "ocean",
		rarity = "epic",
		look = {
			eyes = rgb(70, 120, 190),
			skin = SKIN,
			hair = "cover_eye",
			hairColor = rgb(255, 220, 110),
			top = rgb(25, 25, 30),
			topAccent = rgb(245, 245, 245),
			bottom = rgb(25, 25, 30),
			outfit = "suit",
			face = "smirk",
			eyeStyle = "sleepy",
			mouthStyle = "smirk",
			browStyle = "raised",
			accessories = {},
		},
		evolve = {
			-- ★★ : jambe du diable (flammes)
			[2] = { accessories = { "sun_flames" }, energyColor = rgb(255, 130, 40) },
			-- ★★★ : flammes bleues, veste retirée
			[3] = { outfit = "shirt", top = rgb(240, 240, 245), accessories = { "sun_flames", "energy_aura" }, energyColor = rgb(90, 160, 255), auraColor = rgb(90, 160, 255) },
		},
		attack = { kind = "flame", color = rgb(255, 120, 30), name = "Jambe du Diable" },
		fusion = { prefix = "Flamboyant", suffix = "Flamboyant" },
	},
	oce_loffy = {
		name = "Loffy",
		universe = "ocean",
		rarity = "legendary",
		look = {
			eyes = rgb(34, 30, 30),
			skin = SKIN,
			hair = "messy",
			hairColor = rgb(22, 22, 28),
			top = rgb(215, 30, 40),
			bottom = rgb(60, 110, 205),
			pants = "shorts",
			shortsLength = 0.55,
			hemBottom = rgb(242, 242, 242),
			hemBottomSize = 0.07,
			waistband = rgb(240, 205, 100),
			chestScar = true,
			footwear = "sandals",
			shoes = rgb(150, 110, 70),
			outfit = "openvest",
			face = "happy",
			eyeStyle = "round",
			mouthStyle = "wide_grin",
			browStyle = "bold",
			accessories = { "straw_hat", "scar_cheek" },
			accColor = rgb(240, 210, 110),
			sleeveless = true,
		},
		attack = { kind = "stretch", color = rgb(255, 80, 80), name = "Pistolet Élastique" },
		evolve = {
			-- ★★ : deuxième vitesse (peau rougie, vapeur)
			[2] = { skin = rgb(255, 178, 160), accessories = { "straw_hat", "scar_cheek", "steam" }, armVeins = rgb(196, 70, 80) },
			-- ★★★ : cinquième vitesse
			[3] = {
				skin = SKIN,
				accessories = { "straw_hat", "scar_cheek" },
				hairColor = rgb(250, 250, 250),
				top = rgb(250, 250, 250),
				bottom = rgb(250, 250, 250),
				eyes = rgb(255, 60, 60),
				eyeShadow = rgb(255, 255, 255),
			},
		},
		fusion = { prefix = "Élastique", suffix = "Élastique" },
	},
	oce_shonks = {
		name = "Shonks",
		universe = "ocean",
		rarity = "mythic",
		look = {
			eyes = rgb(46, 40, 40),
			skin = SKIN,
			hair = "messy",
			hairColor = rgb(200, 30, 30),
			top = rgb(245, 245, 245),
			bottom = rgb(90, 70, 50),
			outfit = "openshirt",
			face = "smirk",
			eyeStyle = "soft",
			mouthStyle = "smile",
			browStyle = "flat",
			accessories = { "cape", "scar_eye", "sword_hip", "sash" },
			accColor = rgb(25, 25, 30),
		},
		evolve = {
			-- ★★ : fluide royal (aura rouge et noire)
			[2] = { accessories = { "cape", "scar_eye", "sword_hip", "sash", "energy_aura" }, auraColor = rgb(200, 30, 40), eyeGlow = true },
			-- ★★★ : sabre chargé, yeux rouges
			[3] = {
				accessories = { "cape", "scar_eye", "sword_hip", "sash", "energy_aura", "energy_fists" },
				auraColor = rgb(200, 30, 40),
				energyColor = rgb(40, 10, 20),
				eyeGlow = true,
				eyes = rgb(200, 40, 40),
			},
		},
		attack = { kind = "slash", color = rgb(255, 40, 40), name = "Haki du Conquérant" },
		fusion = { prefix = "Empereur", suffix = "des Mers" },
	},

	------------------------------------------------------------------
	-- ÈRE DES POURFENDEURS (inspiré de Demon Slayer)
	------------------------------------------------------------------
	pou_genyo = {
		name = "Genyo",
		universe = "pourfendeur",
		rarity = "common",
		look = {
			eyes = rgb(130, 60, 150),
			skin = SKIN,
			hair = "mohawk",
			hairColor = rgb(30, 30, 35),
			top = rgb(34, 29, 44),
			topAccent = rgb(235, 232, 225),
			bottom = rgb(34, 29, 44),
			uniformStyle = "zip",
			outfit = "uniform",
			face = "angry",
			eyeStyle = "wide",
			mouthStyle = "teeth",
			browStyle = "frown",
			accessories = { "scar_face", "belt", "sword_hip" },
			accColor = rgb(245, 245, 245),
		},
		evolve = {
			-- ★★ : il dévore les démons (yeux de démon, veines, souffle brûlant)
			[2] = { eyes = rgb(220, 30, 40), pupil = "slit", armVeins = rgb(120, 40, 60), accessories = { "scar_face", "belt", "sword_hip", "steam" } },
			-- ★★★ : cornes et crocs
			[3] = { eyes = rgb(220, 30, 40), pupil = "slit", armVeins = rgb(120, 40, 60), mouthStyle = "fang", accessories = { "scar_face", "belt", "sword_hip", "horns" } },
		},
		attack = { kind = "slash", color = rgb(230, 230, 255), name = "Tir Démoniaque" },
		fusion = { prefix = "Rebelle", suffix = "Rebelle" },
	},
	pou_kanoa = {
		name = "Kanoa",
		universe = "pourfendeur",
		rarity = "common",
		look = {
			skin = SKIN,
			hair = "side_ponytail",
			hairColor = rgb(25, 22, 30),
			top = rgb(25, 25, 35),
			topAccent = rgb(245, 245, 245),
			bottom = rgb(25, 25, 35),
			outfit = "uniform",
			eyes = rgb(170, 110, 200),
			face = "calm",
			eyeStyle = "feminine",
			mouthStyle = "pout",
			browStyle = "arched",
			blush = true,
			accessories = { "cape", "sword_hip", "butterfly_clip" },
			accColor = rgb(245, 245, 250),
		},
		evolve = {
			-- ★★ : souffle de la fleur (aura rose, yeux roses qui brillent)
			[2] = { accessories = { "cape", "sword_hip", "butterfly_clip", "energy_aura" }, auraColor = rgb(255, 150, 200), eyes = rgb(240, 110, 170), eyeGlow = true },
			-- ★★★ : yeux de la fleur (rouges), lame rose au lieu du sabre
			[3] = {
				accessories = { "cape", "butterfly_clip", "water_blade", "energy_aura" },
				energyColor = rgb(255, 140, 200),
				auraColor = rgb(255, 150, 200),
				eyes = rgb(230, 40, 70),
				eyeGlow = true,
			},
		},
		attack = { kind = "slash", color = rgb(255, 160, 220), name = "Souffle des Fleurs" },
		fusion = { prefix = "Florale", suffix = "des Fleurs" },
	},
	pou_zenitso = {
		name = "Zenitso",
		universe = "pourfendeur",
		rarity = "rare",
		look = {
			skin = SKIN,
			hair = "spiky",
			hairColor = rgb(255, 215, 40),
			hairTip = rgb(255, 140, 20),
			top = rgb(25, 25, 35),
			topAccent = rgb(245, 245, 245),
			bottom = rgb(25, 25, 35),
			outfit = "uniform",
			eyes = rgb(140, 100, 40),
			face = "happy",
			eyeStyle = "wide",
			mouthStyle = "o",
			browStyle = "raised",
			accessories = { "haori", "sword_hip" },
			accColor = rgb(255, 210, 40),
		},
		evolve = {
			-- ★★ : il dort et frappe (yeux fermés, éclairs autour du corps)
			[2] = { eyeStyle = "sleepy", accessories = { "haori", "sword_hip", "energy_aura" }, auraColor = rgb(255, 230, 80) },
			-- ★★★ : dieu du tonnerre (lame d'éclairs, aura dorée)
			[3] = { eyeStyle = "sharp", accessories = { "haori", "water_blade", "ssj_aura" }, energyColor = rgb(255, 230, 80), auraColor = rgb(255, 220, 60), eyeGlow = true },
		},
		attack = { kind = "lightning", color = rgb(255, 230, 40), name = "Éclair Foudroyant" },
		fusion = { prefix = "Tonnerre", suffix = "du Tonnerre" },
	},
	pou_inosoke = {
		name = "Inosoke",
		universe = "pourfendeur",
		rarity = "rare",
		look = {
			eyes = rgb(70, 150, 100),
			skin = SKIN,
			hair = "none",
			hairColor = rgb(80, 80, 90),
			top = SKIN,
			bottom = rgb(110, 105, 100),
			outfit = "shirtless",
			face = "angry",
			eyeStyle = "sharp",
			mouthStyle = "teeth",
			browStyle = "frown",
			accessories = { "boar_head", "swords" },
			accColor = rgb(115, 115, 125),
			shirtless = true,
		},
		evolve = {
			-- ★★ : tête de sanglier retirée (visage et cheveux)
			[2] = { hair = "messy", hairColor = rgb(30, 40, 70), accessories = { "swords" } },
			-- ★★★ : instinct de la bête (tête de sanglier, aura)
			[3] = { hair = "none", accessories = { "boar_head", "swords", "energy_aura" }, auraColor = rgb(120, 170, 255) },
		},
		attack = { kind = "slash", color = rgb(200, 200, 210), name = "Crocs Sauvages" },
		fusion = { prefix = "Sanglier", suffix = "Sauvage" },
	},
	pou_tanjiru = {
		name = "Tanjiru",
		universe = "pourfendeur",
		rarity = "epic",
		look = {
			skin = SKIN,
			hair = "spiky",
			hairColor = rgb(125, 35, 35),
			top = rgb(26, 26, 36),
			topAccent = rgb(245, 245, 245),
			bottom = rgb(26, 26, 36),
			outfit = "uniform",
			legWraps = rgb(240, 238, 232),
			legWrapTop = 0.56,
			legWrapStraps = rgb(40, 40, 46),
			footwear = "zori",
			shoes = rgb(130, 95, 60),
			eyes = rgb(160, 40, 40),
			face = "fierce",
			eyeStyle = "bold",
			mouthStyle = "smile",
			browStyle = "bold",
			accessories = { "haori_checker", "earrings", "scar_forehead", "sword_hip" },
			accColor = rgb(40, 130, 90),
		},
		attack = { kind = "ice", color = rgb(70, 170, 255), name = "Souffle de l'Eau" },
		evolve = {
			-- ★★ : marque du pourfendeur, souffle de l'eau (lame et aura d'eau, yeux bleus)
			[2] = {
				accessories = { "haori_checker", "earrings", "forehead_mark", "water_blade", "energy_aura" },
				auraColor = rgb(80, 170, 255),
				eyes = rgb(70, 140, 220),
				eyeGlow = true,
			},
			-- ★★★ : danse du dieu du feu (flammes autour du bras)
			[3] = { accessories = { "haori_checker", "earrings", "forehead_mark", "sun_flames" }, markLarge = true, mouthStyle = "shout", eyes = rgb(220, 50, 30), eyeGlow = true },
		},
		fusion = { prefix = "Pourfendeur", suffix = "de l'Eau" },
	},
	pou_nezoko = {
		name = "Nezoko",
		universe = "pourfendeur",
		rarity = "epic",
		look = {
			skin = SKIN,
			hair = "long",
			hairColor = rgb(25, 20, 25),
			hairTip = rgb(255, 120, 60),
			top = rgb(255, 160, 190),
			topAccent = rgb(110, 40, 30),
			bottom = rgb(255, 160, 190),
			pants = "kimono",
			pattern = "asanoha",
			patternColor = rgb(230, 115, 150),
			obiCord = rgb(240, 225, 190),
			footwear = "zori",
			shoes = rgb(120, 80, 60),
			outfit = "kimono",
			eyes = rgb(255, 120, 170),
			face = "calm",
			eyeStyle = "round",
			mouthStyle = "line",
			browStyle = "raised",
			blush = true,
			accessories = { "muzzle", "hair_ribbon" },
			accColor = rgb(255, 160, 190),
		},
		evolve = {
			-- ★★ : forme démoniaque (bâillon retiré, cornes, crocs, veines)
			[2] = { accessories = { "hair_ribbon", "horns" }, mouthStyle = "fang", pupil = "slit", armVeins = rgb(220, 90, 140), eyeGlow = true },
			-- ★★★ : flammes de sang roses
			[3] = {
				accessories = { "hair_ribbon", "horns", "sun_flames" },
				mouthStyle = "fang",
				pupil = "slit",
				armVeins = rgb(220, 90, 140),
				eyeGlow = true,
				energyColor = rgb(255, 100, 170),
			},
		},
		attack = { kind = "flame", color = rgb(255, 90, 160), name = "Sang Explosif" },
		fusion = { prefix = "Démoniaque", suffix = "Démoniaque" },
	},
	pou_rengoko = {
		name = "Rengoko",
		universe = "pourfendeur",
		rarity = "legendary",
		look = {
			skin = SKIN,
			hair = "flame_spiky",
			hairColor = rgb(255, 210, 50),
			hairTip = rgb(230, 40, 20),
			top = rgb(25, 25, 35),
			topAccent = rgb(245, 245, 245),
			bottom = rgb(25, 25, 35),
			outfit = "uniform",
			eyes = rgb(255, 170, 30),
			eyeShadow = rgb(230, 60, 30),
			face = "happy",
			eyeStyle = "wide",
			mouthStyle = "smile",
			browStyle = "thick",
			accessories = { "haori_flame", "sword_hip" },
			accColor = rgb(245, 245, 245),
		},
		evolve = {
			-- ★★ : souffle de la flamme (bras en feu)
			[2] = { accessories = { "haori_flame", "sun_flames" }, energyColor = rgb(255, 130, 30) },
			-- ★★★ : marque du pourfendeur et aura de feu
			[3] = { accessories = { "haori_flame", "sun_flames", "forehead_mark", "ssj_aura" }, energyColor = rgb(255, 130, 30), auraColor = rgb(255, 150, 40), markLarge = true },
		},
		attack = { kind = "flame", color = rgb(255, 120, 20), name = "Souffle du Feu" },
		fusion = { prefix = "Flamme", suffix = "de la Flamme" },
	},
	pou_yoriichu = {
		name = "Yoriichu",
		universe = "pourfendeur",
		rarity = "mythic",
		look = {
			skin = SKIN,
			hair = "ponytail",
			hairColor = rgb(90, 25, 25),
			top = rgb(170, 30, 30),
			topAccent = rgb(25, 25, 25),
			bottom = rgb(25, 25, 25),
			outfit = "robe",
			eyes = rgb(200, 60, 40),
			face = "calm",
			eyeStyle = "soft",
			mouthStyle = "line",
			browStyle = "flat",
			accessories = { "earrings", "forehead_mark", "sword_hip" },
			accColor = rgb(170, 30, 30),
		},
		evolve = {
			-- ★★ : souffle du soleil (flammes), marque agrandie
			[2] = { accessories = { "earrings", "forehead_mark", "sun_flames" }, markLarge = true },
			-- ★★★ : monde transparent (aura dorée, yeux qui brillent)
			[3] = { accessories = { "earrings", "forehead_mark", "sun_flames", "ssj_aura" }, markLarge = true, auraColor = rgb(255, 190, 60), eyeGlow = true },
		},
		attack = { kind = "flame", color = rgb(255, 200, 60), name = "Danse du Soleil" },
		fusion = { prefix = "Solaire", suffix = "du Soleil" },
	},
	------------------------------------------------------------------
	-- NOUVEAUX PERSOS (v3.2) : deux de plus par univers
	------------------------------------------------------------------
	ninja_hinato = {
		name = "Hinato",
		universe = "ninja",
		rarity = "rare",
		look = {
			skin = SKIN,
			hair = "long",
			bangs = "blunt",
			hairLength = 2.2,
			hairColor = rgb(44, 46, 92),
			top = rgb(224, 216, 238),
			topAccent = rgb(150, 124, 196),
			collar = "fur",
			collarColor = rgb(240, 236, 248),
			bottom = rgb(40, 46, 88),
			outfit = "jacket",
			pantsStyle = "ninja",
			footwear = "sandals",
			shoes = rgb(40, 46, 88),
			eyes = rgb(214, 210, 236),
			pupil = "none",
			face = "calm",
			eyeStyle = "feminine",
			mouthStyle = "pout",
			browStyle = "arched",
			blush = true,
			accessories = { "headband_neck" },
			headbandColor = rgb(30, 40, 92),
		},
		evolve = {
			-- ★★ : Byakugan (yeux qui brillent, veines) et poings de lion
			[2] = { eyes = rgb(225, 225, 255), eyeGlow = true, eyeShadow = rgb(200, 205, 255), accessories = { "headband_neck", "energy_fists" }, energyColor = rgb(140, 180, 255) },
			-- ★★★ : veste violette de l'après-guerre et aura des deux lions
			[3] = { top = rgb(150, 120, 190), accessories = { "headband_neck", "energy_fists", "energy_aura" }, energyColor = rgb(140, 180, 255), auraColor = rgb(160, 190, 255) },
		},
		attack = { kind = "punch", color = rgb(170, 200, 255), name = "Paume du Hakké" },
		fusion = { prefix = "Douce", suffix = "aux Yeux Blancs" },
	},
	ninja_jiriya = {
		name = "Jiriya",
		universe = "ninja",
		rarity = "legendary",
		look = {
			skin = SKIN_TAN,
			hair = "mane",
			hairColor = rgb(236, 236, 242),
			top = rgb(76, 116, 74),
			topAccent = rgb(48, 74, 48),
			underColor = rgb(58, 58, 66),
			bottom = rgb(76, 116, 74),
			outfit = "robe",
			footwear = "zori",
			shoes = rgb(110, 80, 52),
			eyes = rgb(40, 36, 36),
			face = "happy",
			eyeStyle = "bold",
			mouthStyle = "grin",
			browStyle = "thick",
			accessories = { "horned_headband", "sage_lines", "haori_jiriya", "scroll_back" },
			headbandColor = rgb(62, 62, 70),
			headbandY = 0.36,
			accColor = rgb(196, 42, 40),
		},
		attack = { kind = "flame", color = rgb(255, 140, 40), name = "Huile Ardente du Crapaud" },
		evolve = {
			-- ★★ : mode Ermite (pigments autour des yeux, verrues de crapaud)
			[2] = {
				eyeShadow = rgb(255, 150, 60),
				eyes = rgb(240, 180, 40),
				accessories = { "horned_headband", "sage_lines", "haori_jiriya", "scroll_back", "sage_toads" },
			},
			-- ★★★ : orbe spirale géant dans la main
			[3] = {
				accessories = { "horned_headband", "sage_lines", "haori_jiriya", "scroll_back", "energy_fists" },
				energyColor = rgb(90, 190, 255),
			},
		},
		fusion = { prefix = "Ermite", suffix = "des Crapauds" },
	},
	occ_nanamo = {
		name = "Nanamo",
		universe = "occulte",
		rarity = "epic",
		look = {
			skin = SKIN,
			hair = "short",
			hairColor = rgb(236, 206, 120),
			top = rgb(222, 206, 160),
			topAccent = rgb(70, 92, 150),
			bottom = rgb(222, 206, 160),
			outfit = "suit",
			pantsStyle = "plain",
			shoes = rgb(60, 45, 35),
			eyes = rgb(110, 90, 60),
			face = "calm",
			eyeStyle = "sleepy",
			mouthStyle = "frown",
			browStyle = "flat",
			accessories = { "glasses", "sword_back" },
			glassesColor = rgb(40, 60, 50),
			accColor = rgb(232, 226, 206),
		},
		evolve = {
			-- ★★ : technique du ratio (lame chargée)
			[2] = { accessories = { "glasses", "sword_back", "energy_fists" }, energyColor = rgb(255, 210, 90) },
			-- ★★★ : veste retirée (chemise), aura dorée
			[3] = { outfit = "shirt", top = rgb(240, 236, 220), accessories = { "glasses", "sword_back", "energy_aura" }, auraColor = rgb(255, 210, 90) },
		},
		attack = { kind = "slash", color = rgb(255, 220, 120), name = "Ratio 7:3" },
		fusion = { prefix = "Méthodique", suffix = "du Ratio" },
	},
	occ_ijichu = {
		-- L'assistant superviseur : costume noir, chemise blanche et cravate sombre, lunettes,
		-- cheveux courts plaqués sur le côté, air inquiet ; il abaisse le Voile (talisman)
		name = "Ijichu",
		universe = "occulte",
		rarity = "common",
		look = {
			skin = SKIN,
			hair = "short",
			hairLength = 0.8,
			hairColor = rgb(40, 34, 30),
			napeTidy = true,
			top = rgb(30, 30, 36),
			topAccent = rgb(240, 238, 232),
			bottom = rgb(30, 30, 36),
			outfit = "suit",
			pantsStyle = "plain",
			footwear = "shoes",
			shoes = rgb(26, 24, 28),
			eyes = rgb(70, 56, 46),
			face = "sad",
			eyeStyle = "soft",
			mouthStyle = "line",
			browStyle = "raised",
			accessories = { "glasses" },
			glassesColor = rgb(40, 40, 46),
			props = IJICHU_TIE,
		},
		evolve = {
			-- ★★ : veste ouverte et talisman du Voile dans la main
			[2] = {
				outfit = "openjacket",
				underColor = rgb(240, 238, 232),
				accessories = { "glasses" },
				props = join(IJICHU_TIE, { ofuda("Right Arm", V(0, -1.25, -0.25), V(-20, 0, 0)) }),
			},
			-- ★★★ : « Voile, descends ! » (talismans en orbite, voile sombre dans les mains)
			[3] = {
				outfit = "openjacket",
				underColor = rgb(240, 238, 232),
				eyeGlow = true,
				eyes = rgb(150, 120, 220),
				accessories = { "glasses", "energy_fists" },
				energyColor = rgb(60, 40, 90),
				props = join(IJICHU_TIE, { ofuda("Right Arm", V(0, -1.25, -0.25), V(-20, 0, 0)) }, IJICHU_ORBIT),
			},
		},
		attack = { kind = "shadow", color = rgb(60, 40, 90), name = "Voile : Descends !" },
		fusion = { prefix = "Dévoué", suffix = "du Voile" },
	},
	occ_chosu = {
		name = "Chosu",
		universe = "occulte",
		rarity = "rare",
		look = {
			skin = SKIN,
			hair = "messy",
			hairColor = rgb(28, 24, 30),
			top = rgb(240, 236, 232),
			topAccent = rgb(110, 84, 146),
			underColor = rgb(58, 48, 70),
			bottom = rgb(92, 72, 116),
			pants = "kimono",
			kimonoLength = 0.8,
			outfit = "robe",
			footwear = "zori",
			shoes = rgb(60, 50, 60),
			eyes = rgb(110, 40, 40),
			face = "calm",
			eyeStyle = "sleepy",
			mouthStyle = "frown",
			browStyle = "flat",
			accessories = { "twin_tufts", "nose_line" },
			markColor = rgb(60, 24, 40),
		},
		evolve = {
			-- ★★ : sang manipulé autour des mains
			[2] = { accessories = { "twin_tufts", "nose_line", "energy_fists" }, energyColor = rgb(200, 20, 40) },
			-- ★★★ : convergence (cheveux lâchés, aura de sang, yeux rouges)
			[3] = {
				hair = "wild",
				accessories = { "nose_line", "energy_fists", "energy_aura" },
				energyColor = rgb(200, 20, 40),
				auraColor = rgb(220, 30, 50),
				eyes = rgb(200, 30, 40),
			},
		},
		attack = { kind = "beam", color = rgb(200, 20, 40), name = "Hémorragie Perçante" },
		fusion = { prefix = "Grand Frère", suffix = "du Sang" },
	},
	sai_trunk = {
		name = "Trunk",
		universe = "saiyan",
		rarity = "epic",
		look = {
			skin = SKIN,
			hair = "bob",
			hairColor = rgb(176, 150, 214),
			top = rgb(46, 56, 120),
			underColor = rgb(32, 32, 38),
			outfit = "openjacket",
			buttonColor = rgb(46, 56, 120),
			shoulderMark = { kind = "kanji", text = "CC", color = rgb(46, 56, 120), bg = rgb(240, 240, 240) },
			bottom = rgb(116, 120, 134),
			pantsStyle = "plain",
			footwear = "boots",
			shoes = rgb(232, 178, 40),
			eyes = rgb(60, 110, 200),
			face = "fierce",
			eyeStyle = "bold",
			mouthStyle = "smirk",
			browStyle = "bold",
			accessories = { "sword_back" },
			accColor = rgb(120, 90, 60),
		},
		attack = { kind = "slash", color = rgb(180, 220, 255), name = "Tranche du Futur" },
		evolve = {
			-- ★★ : Super guerrier doré
			[2] = { hairColor = rgb(250, 222, 70), eyes = rgb(60, 180, 200), accessories = { "sword_back", "ssj_aura" } },
			-- ★★★ : super guerrier en colère (cheveux dressés, cape longue, éclairs bleus)
			[3] = {
				hair = "tall_spiky",
				hairColor = rgb(255, 236, 140),
				eyes = rgb(60, 180, 200),
				eyeGlow = true,
				accessories = { "sword_back", "cape", "ssj_aura", "energy_aura" },
				capeColor = rgb(50, 46, 60),
				auraColor = rgb(255, 230, 110),
				energyColor = rgb(120, 190, 255),
			},
		},
		fusion = { prefix = "Voyageur", suffix = "du Futur" },
	},
	sai_brolo = {
		name = "Brolo",
		universe = "saiyan",
		rarity = "legendary",
		look = {
			headScale = Vector3.new(1.1, 0.98, 1.05), -- mâchoire large de brute
			jawShade = true,
			skin = SKIN_TAN,
			hair = "heavy_long",
			hairColor = rgb(25, 25, 30),
			hairLength = 1.25,
			top = SKIN_TAN,
			bottom = rgb(238, 234, 228),
			outfit = "shirtless",
			shirtless = true,
			waistband = rgb(196, 36, 40),
			pantsStyle = "plain",
			footwear = "boots",
			shoes = rgb(222, 180, 60),
			eyes = rgb(30, 30, 30),
			face = "angry",
			eyeStyle = "sharp",
			mouthStyle = "snarl",
			browStyle = "frown",
			bigBrows = true,
			accessories = { "collar_gold" },
			gemColor = rgb(80, 220, 120),
		},
		attack = { kind = "orb", color = rgb(120, 255, 120), name = "Météore Oméga" },
		evolve = {
			-- ★★ : Super guerrier légendaire (cheveux vert-doré, yeux blancs, aura verte)
			[2] = { hairColor = rgb(196, 238, 80), eyes = rgb(240, 255, 240), pupil = "none", accessories = { "collar_gold", "ssj_aura" }, auraColor = rgb(140, 255, 120) },
			-- ★★★ : forme ultime, plus massif (deltoïdes et avant-bras énormes), cheveux plus longs
			[3] = {
				hairColor = rgb(196, 238, 80),
				hairLength = 1.6,
				eyes = rgb(240, 255, 240),
				pupil = "none",
				eyeGlow = true,
				accessories = { "collar_gold", "bulk", "ssj_aura", "steam" },
				auraColor = rgb(140, 255, 120),
			},
		},
		fusion = { prefix = "Légendaire", suffix = "Légendaire" },
	},
	oce_robine = {
		name = "Robine",
		universe = "ocean",
		rarity = "rare",
		look = {
			skin = rgb(236, 200, 170),
			hair = "long_bangs",
			hairColor = rgb(25, 22, 30),
			top = rgb(110, 60, 140),
			topAccent = rgb(240, 236, 240),
			bottom = rgb(50, 40, 60),
			outfit = "coat",
			pantsStyle = "plain",
			footwear = "boots",
			shoes = rgb(60, 40, 60),
			eyes = rgb(60, 110, 180),
			face = "calm",
			eyeStyle = "soft",
			lashes = true,
			mouthStyle = "smile",
			browStyle = "arched",
			accessories = { "earrings_gold" },
		},
		evolve = {
			-- ★★ : chapeau de cow-boy (désert)
			[2] = { accessories = { "earrings_gold", "cowboy_hat" }, hatColor = rgb(150, 90, 160) },
			-- ★★★ : mille fleurs (aura rose, tenue violette)
			[3] = { top = rgb(110, 60, 120), accessories = { "earrings_gold", "energy_aura" }, auraColor = rgb(255, 130, 200) },
		},
		attack = { kind = "stretch", color = rgb(200, 140, 255), name = "Mille Fleurs" },
		fusion = { prefix = "Archéologue", suffix = "des Fleurs" },
	},
	oce_ase = {
		name = "Ase",
		universe = "ocean",
		rarity = "legendary",
		look = {
			skin = SKIN_TAN,
			hair = "messy",
			hairColor = rgb(28, 24, 26),
			top = SKIN_TAN,
			bottom = rgb(36, 34, 40),
			outfit = "shirtless",
			shirtless = true,
			pants = "shorts",
			shortsLength = 0.72,
			waistband = rgb(232, 128, 40),
			footwear = "boots",
			shoes = rgb(50, 40, 36),
			eyes = rgb(40, 30, 30),
			face = "happy",
			eyeStyle = "bold",
			mouthStyle = "smile",
			browStyle = "bold",
			accessories = { "cowboy_hat", "bead_necklace", "freckles" },
		},
		attack = { kind = "flame", color = rgb(255, 120, 30), name = "Poing Ardent" },
		evolve = {
			-- ★★ : poings de feu
			[2] = { accessories = { "cowboy_hat", "bead_necklace", "freckles", "energy_fists", "energy_aura" }, energyColor = rgb(255, 120, 30), armVeins = rgb(255, 140, 40) },
			-- ★★★ : corps de flammes (les bras s'embrasent)
			[3] = { accessories = { "cowboy_hat", "bead_necklace", "freckles", "sun_flames" }, fireBody = true },
		},
		fusion = { prefix = "Ardent", suffix = "des Flammes" },
	},
	pou_giyo = {
		name = "Giyo",
		universe = "pourfendeur",
		rarity = "legendary",
		look = {
			skin = SKIN,
			hair = "ponytail",
			hairColor = rgb(26, 24, 34),
			top = rgb(24, 24, 34),
			topAccent = rgb(235, 232, 225),
			bottom = rgb(24, 24, 34),
			outfit = "uniform",
			footwear = "zori",
			shoes = rgb(90, 70, 50),
			eyes = rgb(40, 70, 160),
			face = "calm",
			eyeStyle = "sleepy",
			mouthStyle = "frown",
			browStyle = "flat",
			accessories = { "haori_giyu", "sword_hip" },
			accColor = rgb(128, 34, 40),
		},
		evolve = {
			-- ★★ : souffle de l'eau (lame d'eau)
			[2] = { accessories = { "haori_giyu", "water_blade" }, energyColor = rgb(70, 170, 255) },
			-- ★★★ : marque du pourfendeur et calme absolu (aura d'eau)
			[3] = { accessories = { "haori_giyu", "water_blade", "forehead_mark", "energy_aura" }, energyColor = rgb(70, 170, 255), auraColor = rgb(90, 180, 255) },
		},
		attack = { kind = "ice", color = rgb(80, 160, 255), name = "Calme Plat" },
		fusion = { prefix = "Silencieux", suffix = "de l'Eau" },
	},
	pou_shinobo = {
		name = "Shinobo",
		universe = "pourfendeur",
		rarity = "epic",
		look = {
			skin = SKIN,
			hair = "bob",
			fringeLength = 0.55,
			hairColor = rgb(24, 20, 32),
			hairUnder = rgb(120, 70, 170),
			top = rgb(26, 26, 36),
			topAccent = rgb(235, 232, 225),
			bottom = rgb(26, 26, 36),
			outfit = "uniform",
			footwear = "zori",
			shoes = rgb(90, 70, 90),
			eyes = rgb(170, 110, 220),
			face = "happy",
			eyeStyle = "feminine",
			mouthStyle = "smile",
			browStyle = "arched",
			blush = true,
			accessories = { "haori_butterfly", "butterfly_clip", "sword_hip" },
			accColor = rgb(80, 200, 180),
		},
		evolve = {
			-- ★★ : dard de poison (lame violette)
			[2] = { accessories = { "haori_butterfly", "butterfly_clip", "water_blade" }, energyColor = rgb(190, 110, 255) },
			-- ★★★ : danse du papillon (aura violette, yeux qui brillent)
			[3] = {
				accessories = { "haori_butterfly", "butterfly_clip", "water_blade", "energy_aura" },
				energyColor = rgb(190, 110, 255),
				auraColor = rgb(200, 140, 255),
				eyeGlow = true,
			},
		},
		attack = { kind = "slash", color = rgb(200, 120, 255), name = "Danse du Papillon" },
		fusion = { prefix = "Papillon", suffix = "de l'Insecte" },
	},

	------------------------------------------------------------------
	-- NOUVEAUX PERSOS v3.2 (roster élargi : 3 de plus par univers)
	-- Chaque étoile change la silhouette ou les couleurs (pas seulement l'aura) ; objets propres
	-- à chaque perso dans `props` (voir les fonctions en haut du fichier).
	------------------------------------------------------------------
	-- Village Ninja ---------------------------------------------------
	ninja_radama = {
		-- Le fantôme du clan à l'éventail : armure rouge sombre, immense crinière noire en pointes
		-- jusqu'au milieu du dos, éventail de guerre rond dans le dos
		name = "Radama",
		universe = "ninja",
		rarity = "secret",
		look = {
			headScale = Vector3.new(0.96, 1.02, 0.98),
			skin = rgb(250, 222, 196),
			hair = "heavy_long",
			hairColor = rgb(26, 24, 30),
			hairUnder = rgb(18, 16, 22),
			hairShine = rgb(60, 58, 66),
			hairLength = 1.45,
			top = rgb(36, 30, 40),
			topAccent = rgb(150, 34, 40),
			bottom = rgb(36, 30, 40),
			outfit = "armor",
			sleeveColor = rgb(36, 30, 40),
			sleeves = "long",
			pantsStyle = "plain", -- jambes à moitié cachées par les tassettes (budget de peinture)
			legWraps = rgb(58, 52, 64),
			footwear = "sandals",
			shoes = rgb(30, 28, 36),
			eyes = rgb(220, 24, 34),
			pupil = "tomoe",
			face = "smirk",
			eyeStyle = "sharp",
			mouthStyle = "smirk",
			browStyle = "frown",
			accessories = {},
			accColor = rgb(150, 34, 40),
			collarColor = rgb(36, 30, 40),
			collarLining = rgb(150, 34, 40),
			props = join(RADAMA_MANE(rgb(26, 24, 30)), RADAMA_ARMOR, gunbai("Torso", V(-0.72, 1.45, 0.86), V(0.45, -0.85, 0.66))),
		},
		evolve = {
			-- ★★ : yeux éternels, éventail en main et cage thoracique spectrale bleue (Susanoo)
			[2] = {
				pupil = "ring",
				eyes = rgb(170, 60, 220),
				eyeGlow = true,
				accessories = { "energy_aura" },
				auraColor = rgb(80, 110, 255),
				props = join(RADAMA_MANE(rgb(26, 24, 30)), RADAMA_ARMOR, gunbai("Right Arm", V(0, -0.2, -2.2), V(0, -1.0, -0.2), 0), SUSANOO_RIBS),
			},
			-- ★★★ : sage des six chemins (cheveux blancs, robe blanche, orbes noirs en couronne)
			[3] = {
				hairColor = rgb(232, 232, 240),
				hairShine = rgb(255, 255, 255),
				top = rgb(236, 234, 238),
				topAccent = rgb(40, 34, 46),
				bottom = rgb(36, 30, 40),
				outfit = "highcollar",
				eyes = rgb(176, 150, 230),
				pupil = "ring",
				eyeGlow = true,
				accessories = { "cloak_skirt", "ssj_aura" },
				collarColor = rgb(236, 234, 238),
				skirtColor = rgb(236, 234, 238),
				auraColor = rgb(170, 150, 255),
				props = join(RADAMA_MANE(rgb(232, 232, 240)), TRUTH_ORBS, {
					{ shape = "cyl", limb = "Right Arm", at = V(0, -2.7, -0.4), dir = V(0, 1, -0.05), size = V(4.6, 0.12, 0), color = rgb(30, 26, 36) },
					{ shape = "ball", limb = "Right Arm", at = V(0, 1.85, -0.62), size = V(0.4, 0.4, 0.4), color = rgb(30, 26, 36) },
				}),
			},
		},
		attack = { kind = "orb", color = rgb(255, 110, 40), name = "Météore Céleste" },
		fusion = { prefix = "Spectral", suffix = "du Clan Maudit" },
	},
	ninja_minatu = {
		-- L'éclair jaune : cheveux blonds en pointes, gilet de ninja confirmé, haori blanc à flammes
		name = "Minatu",
		universe = "ninja",
		rarity = "mythic",
		look = {
			skin = SKIN,
			hair = "spiky",
			hairColor = rgb(250, 222, 84),
			hairUnder = rgb(214, 176, 40),
			hairShine = rgb(255, 246, 170),
			sidelockLength = 0.85,
			hairRoots = 2, -- coiffure très fournie : peu de bases arrondies (marge de pièces)
			earLocks = true,
			top = rgb(84, 106, 70),
			topAccent = rgb(60, 80, 50),
			sleeveColor = rgb(32, 42, 78),
			bottom = rgb(32, 42, 78),
			outfit = "flakvest",
			pantsStyle = "ninja",
			holster = rgb(32, 42, 78),
			holsterStyle = "band",
			footwear = "sandals",
			shoes = rgb(32, 42, 78),
			eyes = rgb(50, 110, 200),
			face = "happy",
			eyeStyle = "soft",
			mouthStyle = "smile",
			browStyle = "flat",
			accessories = { "headband", "haori_flame" },
			haoriText = "四代目火影", -- « Quatrième Hokage » en colonne rouge dans le dos du haori
			headbandColor = rgb(30, 40, 90),
			accColor = rgb(240, 238, 232),
		},
		evolve = {
			-- ★★ : kunai à trois branches dans la main droite, orbe spirale dans la gauche, kunais marqués
			-- lancés tout autour de lui (bien visibles de face)
			[2] = {
				accessories = { "headband", "haori_flame" },
				props = join(kunai3("Right Arm"), MINATU_KUNAIS),
			},
			-- ★★★ : mode chakra du renard (corps doré à motifs noirs, cape)
			[3] = {
				top = KCM_GOLD,
				topAccent = KCM_INK,
				sleeveColor = KCM_GOLD,
				sleeves = "long",
				bottom = rgb(30, 28, 30),
				outfit = "jumpsuit",
				eyes = rgb(255, 120, 10),
				pupil = "slit",
				holster = false,
				accessories = { "headband", "ssj_aura" },
				accColor = rgb(255, 180, 40),
				auraColor = rgb(255, 210, 90),
				props = join(MINATU_KCM, kunai3("Right Arm")),
			},
		},
		attack = { kind = "lightning", color = rgb(255, 230, 80), name = "Dieu de l'Éclair" },
		fusion = { prefix = "Fulgurant", suffix = "de l'Éclair Jaune" },
	},
	ninja_gaaro = {
		-- Le maître du sable : cheveux roux courts (front dégagé, marque rouge), cernes noirs épais,
		-- grosse gourde de sable dans le dos
		name = "Gaaro",
		universe = "ninja",
		rarity = "epic",
		look = {
			headScale = Vector3.new(0.95, 1.0, 0.97),
			skin = rgb(250, 224, 200),
			hair = "none",
			hairColor = rgb(170, 40, 30),
			hairUnder = rgb(140, 30, 26),
			eyeY = -0.05,
			top = rgb(126, 42, 44),
			topAccent = rgb(196, 176, 140),
			bottom = rgb(110, 36, 40),
			outfit = "coat",
			pantsStyle = "ninja",
			footwear = "sandals",
			shoes = rgb(60, 40, 40),
			eyes = rgb(120, 200, 190),
			eyeShadow = rgb(14, 8, 12),
			lashColor = rgb(10, 6, 8),
			lashThickness = 0.1,
			face = "calm",
			eyeStyle = "wide",
			eyeScale = 0.86,
			mouthStyle = "line",
			browStyle = "none",
			accessories = { "sash" },
			sashColor = rgb(176, 172, 164),
			accColor = rgb(214, 186, 132),
			props = join(GAARO_HAIR, { GAARO_KANJI }, gourd(rgb(214, 186, 136)), GAARO_STRAP),
		},
		evolve = {
			-- ★★ : tenue de l'après-guerre (gilet gris, manches rouges) et bouclier de sable
			[2] = {
				top = rgb(120, 112, 100),
				topAccent = rgb(90, 84, 76),
				sleeveColor = rgb(126, 42, 44),
				outfit = "flakvest",
				accessories = { "sash", "energy_fists" },
				energyColor = rgb(222, 190, 120),
				props = join(GAARO_HAIR, { GAARO_KANJI }, gourd(rgb(214, 186, 136)), SAND_SHIELD),
			},
			-- ★★★ : robe blanche et bleue du chef du village du sable
			[3] = {
				top = rgb(236, 234, 228),
				topAccent = rgb(60, 110, 200),
				bottom = rgb(236, 234, 228),
				outfit = "robe",
				accessories = { "energy_fists", "ssj_aura" },
				energyColor = rgb(222, 190, 120),
				auraColor = rgb(240, 210, 140),
				props = join(GAARO_HAIR, { GAARO_KANJI }, gourd(rgb(214, 186, 136)), SAND_WALL),
			},
		},
		attack = { kind = "shadow", color = rgb(222, 190, 120), name = "Cercueil de Sable" },
		fusion = { prefix = "Sablonneux", suffix = "du Désert" },
	},
	-- Académie Occulte -----------------------------------------------
	occ_toja = {
		-- Le tueur de sorciers : t-shirt noir moulant, pantalon ample, cicatrice à la bouche, lance dans le dos
		name = "Toja",
		universe = "occulte",
		rarity = "mythic",
		look = {
			headScale = Vector3.new(1.03, 1.0, 1.0),
			skin = rgb(240, 206, 172),
			hair = "messy",
			napeTidy = true,
			hairColor = rgb(22, 22, 26),
			top = rgb(30, 30, 36),
			sleeves = "short",
			bottom = rgb(226, 222, 214),
			pants = "kimono",
			kimonoLength = 0.85,
			waistband = rgb(30, 30, 36),
			footwear = "shoes",
			shoes = rgb(30, 30, 34),
			outfit = "shirt",
			eyes = rgb(70, 112, 94),
			face = "smirk",
			eyeStyle = "sharp",
			mouthStyle = "smirk",
			browStyle = "low",
			accessories = { "scar_cheek", "spear" },
			accColor = rgb(120, 110, 150),
			props = TOJA_SHIRT,
		},
		evolve = {
			-- ★★ : le ver-arsenal enroulé autour du torse, sabre de l'âme fendue à la hanche,
			-- chaleur du combat (vapeur)
			[2] = {
				accessories = { "scar_cheek", "spear", "sword_hip", "steam" },
				props = join(TOJA_SHIRT, TOJA_WORM),
				katana = { handle = rgb(40, 36, 44), sheath = rgb(30, 28, 34), cord = rgb(150, 130, 200), guard = "square" },
				steamColor = rgb(230, 230, 240),
			},
			-- ★★★ : revenu d'entre les morts (torse nu, yeux noirs, aura sombre)
			[3] = {
				outfit = "shirtless",
				shirtless = true,
				eyes = rgb(26, 26, 30),
				eyeGlow = true,
				accessories = { "scar_cheek", "spear", "sword_hip", "energy_aura" },
				katana = { handle = rgb(40, 36, 44), sheath = rgb(30, 28, 34), cord = rgb(150, 130, 200), guard = "square" },
				auraColor = rgb(80, 70, 110),
				props = join(TOJA_WORM, brawn(rgb(240, 206, 172), rgb(240, 206, 172), 1.04)),
			},
		},
		attack = { kind = "slash", color = rgb(150, 130, 200), name = "Lance Inversée du Ciel" },
		fusion = { prefix = "Chasseur", suffix = "Sans Énergie" },
	},
	occ_yuuto = {
		-- Le sorcier maudit par amour : uniforme blanc, cernes, katana dans le dos
		name = "Yuuto",
		universe = "occulte",
		rarity = "legendary",
		look = {
			skin = SKIN,
			hair = "cover_eye",
			napeTidy = true,
			hairColor = rgb(28, 26, 34),
			hairUnder = rgb(50, 46, 64),
			top = rgb(238, 238, 234),
			topAccent = rgb(214, 214, 210),
			bottom = rgb(238, 238, 234),
			outfit = "uniform",
			uniformStyle = "zip",
			pantsStyle = "plain",
			footwear = "shoes",
			shoes = rgb(40, 36, 44),
			eyes = rgb(40, 36, 52),
			eyeShadow = rgb(120, 100, 130),
			face = "calm",
			eyeStyle = "sleepy",
			mouthStyle = "line",
			browStyle = "raised",
			accessories = { "sword_back" },
			katana = { handle = rgb(30, 28, 34), sheath = rgb(26, 24, 30), cord = rgb(236, 236, 240), guard = "round" },
			accColor = rgb(30, 28, 34),
		},
		evolve = {
			-- ★★ : katana dégainé, et l'esprit maudit sort son énorme main derrière son épaule
			[2] = {
				accessories = { "energy_fists" },
				energyColor = rgb(255, 170, 220),
				props = join(katanaInHand("Right Arm", V(0, 0.35, -1)), RIKA_HAND),
			},
			-- ★★★ : manifestation complète (manteau noir ouvert, lame chargée, deux bras de l'esprit)
			[3] = {
				top = rgb(26, 24, 30),
				topAccent = rgb(26, 24, 30),
				underColor = rgb(236, 236, 232),
				outfit = "openjacket",
				eyeGlow = true,
				eyes = rgb(255, 120, 190),
				accessories = { "energy_fists", "ssj_aura" },
				energyColor = rgb(255, 150, 210),
				auraColor = rgb(255, 210, 240),
				props = join(katanaInHand("Right Arm", V(0, 0.35, -1), rgb(255, 170, 220), true), RIKA_HAND, RIKA_HAND_LEFT),
			},
		},
		attack = { kind = "beam", color = rgb(255, 170, 220), name = "Amour Pur" },
		fusion = { prefix = "Maudit", suffix = "de l'Amour Pur" },
	},
	occ_hakaro = {
		-- Le flambeur : banane gris-vert, uniforme fermé gris-vert, boucles d'oreilles
		name = "Hakaro",
		universe = "occulte",
		rarity = "epic",
		look = {
			skin = rgb(244, 210, 176),
			hair = "none",
			hairColor = HAKARO_SILVER,
			hairUnder = rgb(120, 120, 112),
			top = rgb(70, 78, 66),
			topAccent = rgb(54, 60, 50),
			bottom = rgb(38, 40, 44),
			outfit = "uniform",
			uniformStyle = "zip",
			pantsStyle = "plain",
			footwear = "shoes",
			shoes = rgb(236, 236, 236),
			eyes = rgb(60, 50, 40),
			face = "smirk",
			eyeStyle = "bold",
			mouthStyle = "teeth", -- dents blanches cerclées de noir (pas de bouche rouge)
			browStyle = "bold",
			accessories = { "earrings_gold" },
			props = HAKARO_HAIR(HAKARO_SILVER),
		},
		evolve = {
			-- ★★ : jackpot ! (veste ouverte au col de fourrure, liserés vert fluo, billes de jackpot)
			[2] = {
				top = rgb(52, 58, 50),
				topAccent = rgb(230, 226, 214),
				underColor = rgb(230, 226, 214),
				collar = "fur",
				collarColor = rgb(214, 196, 160),
				outfit = "openjacket",
				accessories = { "earrings_gold", "steam" },
				steamColor = rgb(140, 255, 170),
				props = join(HAKARO_HAIR(HAKARO_SILVER), JACKPOT_TRIM),
			},
			-- ★★★ : jackpot infini (veste tombée, yeux verts, aura flamboyante)
			[3] = {
				outfit = "shirtless",
				shirtless = true,
				top = rgb(244, 210, 176),
				eyeGlow = true,
				eyes = rgb(80, 220, 120),
				accessories = { "earrings_gold", "steam", "energy_fists", "ssj_aura" },
				steamColor = rgb(140, 255, 170),
				energyColor = rgb(110, 255, 150),
				auraColor = rgb(150, 255, 170),
				props = join(HAKARO_HAIR(HAKARO_SILVER), JACKPOT_BALLS),
			},
		},
		attack = { kind = "punch", color = rgb(110, 255, 150), name = "Jackpot Fiévreux" },
		fusion = { prefix = "Chanceux", suffix = "du Jackpot" },
	},
	-- Planète des Guerriers ---------------------------------------------
	sai_gojita = {
		-- La fusion parfaite : gilet noir bordé d'orange et de jaune, épaisse ceinture bleue,
		-- pantalon blanc, gros poignets blancs
		name = "Gojita",
		universe = "saiyan",
		rarity = "secret",
		look = {
			skin = SKIN,
			hair = "goku",
			napeTidy = true,
			hairColor = rgb(22, 22, 28),
			top = rgb(30, 30, 38),
			topAccent = rgb(236, 130, 40),
			noButtons = true,
			bottom = rgb(240, 240, 236),
			outfit = "openvest",
			pantsStyle = "plain",
			footwear = "boots",
			shoes = rgb(30, 30, 36),
			bootTrim = rgb(240, 240, 236),
			eyes = rgb(30, 30, 30),
			face = "smirk",
			eyeStyle = "sharp",
			mouthStyle = "smirk",
			browStyle = "frown",
			accessories = {},
			accColor = rgb(240, 240, 236),
			props = GOJITA_KIT,
		},
		evolve = {
			-- ★★ : super guerrier doré
			[2] = { hairColor = rgb(252, 222, 70), eyes = rgb(60, 170, 190), accessories = { "ssj_aura" }, auraColor = rgb(255, 226, 90) },
			-- ★★★ : super guerrier divin bleu
			[3] = {
				hairColor = rgb(70, 176, 255),
				eyes = rgb(70, 176, 255),
				eyeGlow = true,
				accessories = { "ssj_aura", "energy_aura" },
				auraColor = rgb(90, 190, 255),
			},
		},
		attack = { kind = "beam", color = rgb(90, 190, 255), name = "Kaméha Big Bang" },
		fusion = { prefix = "Fusionné", suffix = "de la Fusion Parfaite" },
	},
	sai_cel = {
		-- La créature parfaite : visage blanc rosé masqué (joues violettes à deux traits), crête en
		-- deux cornes plates vertes bordées de noir, plastron vert clair taché de noir, ventre blanc,
		-- ailes noires dans le dos. ★1 forme imparfaite (vert sombre, longue queue à dard),
		-- ★2 forme parfaite (crête plus haute, vert franc), ★3 super parfait (éclairs bleus)
		name = "Cel",
		universe = "saiyan",
		rarity = "legendary",
		look = {
			skin = CEL_SKIN,
			hair = "none",
			hairColor = rgb(50, 110, 64),
			top = rgb(84, 112, 66),
			bottom = rgb(84, 112, 66),
			outfit = "creature",
			spots = CEL_SPOT,
			sleeves = "long",
			sleeveColor = rgb(84, 112, 66),
			footwear = "barefoot",
			eyes = rgb(150, 40, 60),
			cheekShade = rgb(150, 90, 170),
			lipColor = rgb(150, 90, 160),
			face = "angry",
			eyeStyle = "sharp",
			mouthStyle = "snarl",
			browStyle = "none",
			accessories = { "claws" },
			accColor = rgb(50, 110, 64),
			props = join(CEL_CREST(rgb(46, 82, 42), 0.85), CEL_BODY(rgb(110, 150, 84)), CEL_TAIL),
		},
		evolve = {
			-- ★★ : forme parfaite (crête plus haute, vert franc, plastron net, plus de queue)
			[2] = {
				top = rgb(120, 200, 110),
				bottom = rgb(120, 200, 110),
				sleeveColor = rgb(120, 200, 110),
				spots = rgb(20, 30, 22),
				eyes = rgb(200, 60, 170),
				face = "smirk",
				mouthStyle = "smirk",
				accessories = { "claws" },
				accColor = rgb(70, 150, 90),
				props = join(CEL_CREST(rgb(48, 118, 60), 1.15), CEL_BODY(rgb(150, 222, 130))),
			},
			-- ★★★ : super parfait (carrure massive, plastron pâle, yeux luisants, arcs électriques et
			-- aura bleus qui crépitent autour de lui)
			[3] = {
				top = rgb(150, 220, 140),
				bottom = rgb(150, 220, 140),
				sleeveColor = rgb(150, 220, 140),
				eyes = rgb(140, 220, 255),
				face = "smirk",
				mouthStyle = "smirk",
				eyeGlow = true,
				accessories = { "claws", "energy_aura" },
				auraColor = rgb(90, 170, 255),
				props = join(CEL_CREST(rgb(72, 150, 82), 1.25), CEL_BODY(rgb(196, 240, 176), rgb(26, 34, 60)), CEL_SPARKS, brawn(rgb(150, 220, 140), rgb(150, 220, 140), 1.06)),
			},
		},
		attack = { kind = "beam", color = rgb(110, 190, 255), name = "Kaméha Parfait" },
		fusion = { prefix = "Parfait", suffix = "Parfait" },
	},
	sai_jirene = {
		-- Le guerrier de la fierté : peau grise, crâne lisse et massif, oreilles pointues, yeux noirs
		-- à pupilles rouges, uniforme rouge et noir des troupes de la fierté, gants blancs
		name = "Jirène",
		universe = "saiyan",
		rarity = "legendary",
		look = {
			headScale = Vector3.new(1.08, 1.06, 1.04),
			skin = rgb(156, 166, 184),
			hair = "bald",
			hairColor = rgb(156, 166, 184),
			top = rgb(200, 30, 40),
			topAccent = rgb(30, 30, 36),
			sleeveColor = rgb(30, 30, 36),
			bottom = rgb(30, 30, 36),
			outfit = "jumpsuit",
			waistband = rgb(30, 30, 36),
			footwear = "boots",
			shoes = rgb(240, 240, 240),
			eyes = rgb(220, 36, 40),
			scleraColor = rgb(22, 22, 28),
			face = "angry",
			eyeStyle = "wide",
			mouthStyle = "frown",
			browStyle = "none",
			accessories = { "brow_ridge" },
			accColor = rgb(240, 240, 240),
			props = join(JIRENE_HEAD, cuffs(rgb(244, 244, 244), 0.62, -0.68), brawn(rgb(30, 30, 36), rgb(200, 30, 40), 1.06)),
		},
		evolve = {
			-- ★★ : haut d'uniforme arraché (débardeur noir et rouge), veines rouges, poings chargés
			[2] = {
				top = rgb(30, 30, 36),
				topAccent = rgb(200, 30, 40),
				outfit = "tank",
				waistband = rgb(200, 30, 40),
				hemBottom = rgb(200, 30, 40),
				armVeins = rgb(220, 40, 40),
				accessories = { "brow_ridge", "energy_fists" },
				energyColor = rgb(255, 60, 50),
				props = join(JIRENE_HEAD, cuffs(rgb(244, 244, 244), 0.62, -0.68), brawn(rgb(156, 166, 184), rgb(30, 30, 36), 1.06)),
			},
			-- ★★★ : pleine puissance (torse nu, yeux brillants, aura flamboyante)
			[3] = {
				outfit = "shirtless",
				shirtless = true,
				top = rgb(156, 166, 184),
				waistband = rgb(200, 30, 40),
				armVeins = rgb(220, 40, 40),
				eyeGlow = true,
				accessories = { "brow_ridge", "ssj_aura", "steam" },
				props = join(JIRENE_HEAD, cuffs(rgb(244, 244, 244), 0.62, -0.68), brawn(rgb(156, 166, 184), rgb(156, 166, 184), 1.08)),
				auraColor = rgb(255, 70, 50),
				steamColor = rgb(255, 180, 170),
			},
		},
		attack = { kind = "punch", color = rgb(255, 60, 50), name = "Poing de la Fierté" },
		fusion = { prefix = "Fier", suffix = "de la Justice" },
	},
	-- Grand Océan --------------------------------------------------------
	oce_inel = {
		-- Le dieu de la foudre : bandana blanc, lobes d'oreille dorés, torse nu, pantalon orange,
		-- ceinture de corde, long bâton doré
		name = "Inel",
		universe = "ocean",
		rarity = "mythic",
		look = {
			skin = rgb(250, 220, 190),
			hair = "short",
			napeTidy = true,
			hairColor = rgb(240, 214, 120),
			top = rgb(250, 220, 190),
			bottom = rgb(236, 132, 40),
			outfit = "shirtless",
			shirtless = true,
			pants = "kimono",
			kimonoLength = 0.95,
			armband = rgb(230, 186, 60),
			footwear = "barefoot",
			eyes = rgb(40, 34, 30),
			face = "smirk",
			eyeStyle = "narrow",
			mouthStyle = "teeth", -- large rictus de dents (pas de bouche rouge)
			mouthWidth = 0.24,
			browStyle = "raised",
			accessories = { "bandana", "earrings_gold", "rope_belt" },
			accColor = rgb(244, 244, 240),
			beltColor = rgb(70, 130, 220),
			props = join(INEL_STAFF(false), drumRing(4)),
		},
		evolve = {
			-- ★★ : anneau complet de 6 tambours reliés par des arcs électriques, veines de foudre
			[2] = {
				armVeins = rgb(120, 190, 255),
				accessories = { "bandana", "earrings_gold", "rope_belt", "energy_aura" },
				auraColor = rgb(170, 220, 255),
				props = join(INEL_STAFF(false), drumRing(6, true)),
			},
			-- ★★★ : corps de foudre (peau bleu électrique, bâton chargé, yeux brillants)
			[3] = {
				skin = rgb(176, 214, 255),
				top = rgb(176, 214, 255),
				eyeGlow = true,
				eyes = rgb(230, 245, 255),
				accessories = { "bandana", "earrings_gold", "rope_belt", "ssj_aura" },
				auraColor = rgb(170, 220, 255),
				props = join(INEL_STAFF(true), drumRing(6, true)),
			},
		},
		attack = { kind = "lightning", color = rgb(150, 210, 255), name = "Jugement Divin" },
		fusion = { prefix = "Divin", suffix = "de la Foudre" },
	},
	oce_lao = {
		-- Le chirurgien de la mort : bonnet blanc tacheté, sweat jaune aux manches noires frappé du
		-- Jolly Roger souriant, cernes, long sabre dans le dos
		name = "Lao",
		universe = "ocean",
		rarity = "legendary",
		look = {
			skin = rgb(232, 196, 160),
			hair = "none",
			hairColor = rgb(26, 24, 30),
			top = rgb(244, 204, 44),
			topAccent = rgb(30, 30, 36),
			sleeveColor = rgb(30, 30, 36),
			bottom = rgb(196, 176, 140),
			outfit = "shirt",
			pantsStyle = "plain",
			footwear = "shoes",
			shoes = rgb(40, 34, 30),
			eyes = rgb(150, 120, 60),
			eyeShadow = rgb(90, 60, 56),
			face = "calm",
			eyeStyle = "sleepy",
			mouthStyle = "smirk",
			browStyle = "low",
			accessories = { "earrings_gold", "sword_back" },
			katana = { handle = rgb(30, 30, 34), sheath = rgb(24, 22, 26), cord = rgb(236, 236, 236), tsuba = rgb(230, 200, 60), guard = "square" },
			props = join(spottedHat(), smileyRoger(rgb(244, 204, 44))),
		},
		evolve = {
			-- ★★ : long manteau noir à col, salle d'opération (dôme bleu) autour de la main
			[2] = {
				accessories = { "earrings_gold", "sword_back", "cape" },
				capeColor = rgb(30, 30, 36),
				props = join(spottedHat(), smileyRoger(rgb(244, 204, 44)), ROOM_DOME),
			},
			-- ★★★ : grande salle d'opération autour de lui, Kikoku dégainé (lame bleue), yeux brillants
			[3] = {
				eyeGlow = true,
				accessories = { "earrings_gold", "cape", "ssj_aura" },
				capeColor = rgb(30, 30, 36),
				auraColor = rgb(130, 200, 255),
				props = join(spottedHat(), smileyRoger(rgb(244, 204, 44)), ROOM_BIG, katanaInHand("Right Arm", V(0, 0.5, -1), rgb(140, 210, 255), true)),
			},
		},
		attack = { kind = "slash", color = rgb(110, 190, 255), name = "Salle d'Opération : Shambles" },
		fusion = { prefix = "Chirurgien", suffix = "de la Mort" },
	},
	oce_kaydo = {
		-- La créature la plus forte : grandes cornes, longue crinière noire, moustache, torse massif,
		-- corde sacrée, manteau violet, énorme massue à piques
		name = "Kaydo",
		universe = "ocean",
		rarity = "secret",
		look = {
			headScale = Vector3.new(1.1, 1.02, 1.05),
			skin = rgb(230, 186, 148),
			hair = "heavy_long",
			hairColor = rgb(26, 24, 30),
			hairLength = 1.7,
			hairSweep = 92, -- mèches latérales derrière les oreilles (rien sur le visage)
			top = rgb(230, 186, 148),
			bottom = rgb(232, 228, 216),
			outfit = "shirtless",
			shirtless = true,
			pants = "kimono",
			kimonoLength = 0.9,
			armband = rgb(214, 170, 60),
			footwear = "zori",
			shoes = rgb(90, 70, 50),
			eyes = rgb(30, 26, 26),
			face = "angry",
			eyeStyle = "sharp",
			mouthStyle = "snarl",
			browStyle = "frown",
			bigBrows = true,
			bodyScale = 1.28, -- géant : nettement plus grand que les autres persos et que l'avatar joueur
			minScale = 1.35, -- dès le niveau 1 : ~35 % de plus que l'avatar joueur
			accessories = { "rope_belt", "cape" },
			accColor = rgb(232, 226, 210),
			beltColor = rgb(222, 200, 150),
			capeColor = rgb(96, 70, 140),
			props = join(KAYDO_HORNS(1), KAYDO_FACE(1), KAYDO_BODY, KAYDO_CLUB),
		},
		evolve = {
			-- ★★ : forme hybride du dragon — cornes plus grandes recourbées, yeux dorés luisants,
			-- écailles bleues (avant-bras, épaules, pommettes), longue moustache et barbiche, queue
			-- de dragon qui remonte sur son flanc, cape bleu-vert
			[2] = {
				eyes = rgb(250, 196, 60),
				eyeGlow = true,
				accessories = { "rope_belt", "cape" },
				capeColor = rgb(38, 104, 124),
				beltColor = rgb(150, 210, 230),
				props = join(KAYDO_HORNS(1.5, nil, true), KAYDO_FACE(1.8), KAYDO_BODY, KAYDO_SCALES, KAYDO_TAIL, KAYDO_CLUB),
			},
			-- ★★★ : haki du conquérant (cornes dorées, griffes, yeux rouges, éclairs noirs et rouges)
			[3] = {
				eyeGlow = true,
				eyes = rgb(230, 40, 40),
				accessories = { "rope_belt", "cape", "ssj_aura", "steam" },
				auraColor = rgb(230, 40, 50),
				steamColor = rgb(80, 40, 60),
				props = join(KAYDO_HORNS(1.65, rgb(240, 200, 90), true), KAYDO_FACE(1.8), KAYDO_BODY, KAYDO_WHISKERS, KAYDO_SCALES, KAYDO_TAIL, KAYDO_CLUB),
			},
		},
		attack = { kind = "flame", color = rgb(255, 100, 40), name = "Souffle du Dragon" },
		fusion = { prefix = "Indestructible", suffix = "des Cent Bêtes" },
	},
	-- Ère des Pourfendeurs -----------------------------------------------
	pou_muzon = {
		-- Le roi des démons : chapeau mou blanc, costume noir, chemise blanche et cravate rouge,
		-- peau pâle, yeux rouges fendus et luisants
		name = "Muzon",
		universe = "pourfendeur",
		rarity = "secret",
		look = {
			headScale = Vector3.new(0.94, 1.03, 0.96),
			skin = rgb(250, 232, 224),
			hair = "short",
			napeTidy = true,
			hairColor = rgb(20, 18, 24),
			top = rgb(24, 24, 30),
			topAccent = rgb(242, 240, 236),
			bottom = rgb(24, 24, 30),
			outfit = "suit",
			pantsStyle = "plain",
			footwear = "shoes",
			shoes = rgb(20, 20, 24),
			eyes = rgb(220, 30, 44),
			pupil = "slit",
			eyeGlow = true,
			face = "calm",
			eyeStyle = "narrow",
			mouthStyle = "sneer",
			browStyle = "flat",
			accessories = { "earrings_stud" },
			accColor = rgb(214, 28, 40),
			props = join(fedora(rgb(244, 242, 236), rgb(30, 28, 34)), MUZON_TIE, cuffs(rgb(244, 242, 236), 0.4, -0.8)),
		},
		evolve = {
			-- ★★ : chapeau ôté, cheveux ondulés, fouets de chair dans le dos, griffes
			[2] = {
				hair = "slick", -- calotte lisse sous les boucles en vagues
				accessories = { "earrings_stud", "claws" },
				clawColor = rgb(180, 20, 40),
				props = join(MUZON_CURLS, MUZON_TIE, MUZON_WHIPS(4)),
			},
			-- ★★★ : forme démoniaque ultime (longs cheveux blancs, veines rouges, six fouets)
			[3] = {
				hair = "wild_long",
				hairColor = rgb(240, 238, 244),
				armVeins = rgb(180, 30, 50),
				accessories = { "claws", "ssj_aura", "steam" },
				clawColor = rgb(180, 20, 40),
				auraColor = rgb(200, 20, 50),
				steamColor = rgb(120, 20, 40),
				props = join(MUZON_TIE, MUZON_WHIPS(6)),
			},
		},
		attack = { kind = "shadow", color = rgb(170, 20, 40), name = "Fouets de Chair" },
		fusion = { prefix = "Démoniaque", suffix = "des Démons" },
	},
	pou_doma = {
		-- La deuxième lune : cheveux clairs tachés de sang sur le dessus, yeux arc-en-ciel gravés,
		-- sourire figé, haori, éventails dorés
		name = "Doma",
		universe = "pourfendeur",
		rarity = "mythic",
		look = {
			skin = rgb(250, 234, 224),
			-- calotte lisse ; toute la chevelure (nappe du dos, mèches, frange) est faite de mèches
			-- plates (DOMA_BLOOD) : aucun boudin
			hair = "slick",
			hairColor = DOMA_HAIR,
			hairShine = rgb(255, 250, 236),
			hairUnder = rgb(196, 178, 148), -- nappe du dos plus sombre (les mèches s'y détachent)
			irisRainbow = true,
			top = rgb(34, 30, 36),
			topAccent = rgb(170, 30, 40),
			bottom = rgb(34, 30, 36),
			outfit = "kimono",
			pants = "kimono",
			obiCord = rgb(170, 30, 40),
			footwear = "zori",
			shoes = rgb(60, 50, 50),
			eyes = rgb(170, 140, 240),
			eyeKanji = rgb(60, 40, 120),
			face = "happy",
			eyeStyle = "soft",
			mouthStyle = "smile",
			browStyle = "raised",
			accessories = { "haori" },
			accColor = rgb(236, 232, 226),
			props = join(DOMA_BLOOD, fan("Right Arm", false), fan("Left Arm", false)),
		},
		evolve = {
			-- ★★ : éventails ouverts, chargés de glace (glace bleue dans les mains)
			[2] = {
				accessories = { "haori", "energy_fists" },
				energyColor = rgb(170, 220, 255),
				props = join(DOMA_BLOOD, fan("Right Arm", true, rgb(170, 220, 255)), fan("Left Arm", true, rgb(170, 220, 255))),
			},
			-- ★★★ : bodhisattva de glace (peau givrée, cristaux de glace sur les épaules)
			[3] = {
				skin = rgb(226, 238, 250),
				hairColor = rgb(236, 244, 255),
				eyeGlow = true,
				accessories = { "haori", "energy_fists", "ssj_aura" },
				energyColor = rgb(170, 220, 255),
				auraColor = rgb(190, 230, 255),
				props = join(DOMA_BLOOD, fan("Right Arm", true, rgb(170, 220, 255)), fan("Left Arm", true, rgb(170, 220, 255)), ICE_CRYSTALS),
			},
		},
		attack = { kind = "ice", color = rgb(170, 220, 255), name = "Lotus de Glace" },
		fusion = { prefix = "Glacial", suffix = "de la Deuxième Lune" },
	},
	pou_tengan = {
		-- Le pilier du son : cheveux blancs, bandeau à gemmes, maquillage rouge à l'œil, sans manches,
		-- deux couperets croisés dans le dos reliés par une chaîne
		name = "Tengan",
		universe = "pourfendeur",
		rarity = "legendary",
		look = {
			headScale = Vector3.new(1.0, 1.03, 1.0),
			skin = rgb(246, 214, 186),
			hair = "slick", -- plaqués vers l'arrière (+ 4 mèches plates)
			hairColor = rgb(240, 240, 246),
			top = rgb(24, 24, 34),
			topAccent = rgb(235, 232, 225),
			bottom = rgb(24, 24, 34),
			outfit = "uniform",
			sleeveless = true,
			armband = rgb(230, 190, 70),
			footwear = "zori",
			shoes = rgb(80, 60, 50),
			eyes = rgb(150, 50, 90),
			eyeMarks = rgb(200, 60, 110),
			face = "smirk",
			eyeStyle = "sharp",
			mouthStyle = "grin",
			browStyle = "bold",
			accessories = { "earrings_gold", "wristbands" },
			accColor = rgb(160, 160, 170),
			props = join(gemHeadband(), TENGAN_LOCKS, crossedCleavers()),
		},
		evolve = {
			-- ★★ : partition de combat : un couperet dans chaque main, chaîne tendue
			[2] = {
				accessories = { "earrings_gold", "wristbands", "energy_aura" },
				auraColor = rgb(255, 150, 80),
				props = join(gemHeadband(), TENGAN_LOCKS, TENGAN_DUAL),
			},
			-- ★★★ : cheveux lâchés, œil balafré, perles explosives
			[3] = {
				hair = "wild_long",
				eyeGlow = true,
				accessories = { "earrings_gold", "wristbands", "scar_eye", "ssj_aura" },
				auraColor = rgb(255, 160, 90),
				props = join(gemHeadband(), TENGAN_DUAL, BEADS),
			},
		},
		attack = { kind = "flame", color = rgb(255, 140, 80), name = "Souffle du Son : Explosion" },
		fusion = { prefix = "Flamboyant", suffix = "du Son" },
	},
}

-- Ennemis (ne peuvent pas être obtenus). Utilisés par le système de combat.
Characters.Enemies = {
	-- Village Ninja
	ninja_son = {
		name = "Ninja du Son",
		look = {
			skin = SKIN,
			hair = "short",
			hairColor = rgb(60, 60, 60),
			top = rgb(110, 100, 130),
			bottom = rgb(70, 65, 85),
			outfit = "shirt",
			face = "angry",
			eyeStyle = "sharp",
			mouthStyle = "snarl",
			browStyle = "frown",
			accessories = { "mask_lower", "headband" },
			accColor = rgb(70, 65, 85),
		},
	},
	ninja_kabouto = {
		name = "Kabouto",
		look = {
			skin = SKIN,
			hair = "ponytail",
			hairColor = rgb(200, 200, 210),
			top = rgb(110, 70, 150),
			bottom = rgb(60, 50, 80),
			outfit = "highcollar",
			face = "smirk",
			eyeStyle = "narrow",
			mouthStyle = "smirk",
			browStyle = "flat",
			accessories = { "glasses", "headband" },
		},
	},
	ninja_zabouza = {
		name = "Zabouza",
		look = {
			skin = SKIN,
			hair = "short",
			hairColor = rgb(40, 40, 40),
			top = SKIN,
			bottom = rgb(80, 90, 110),
			outfit = "shirtless",
			face = "angry",
			eyeStyle = "sharp",
			mouthStyle = "line",
			browStyle = "none",
			accessories = { "mask_bandage", "big_sword", "headband_tilted" },
			accColor = rgb(230, 230, 230),
			shirtless = true,
		},
	},
	ninja_kourama = {
		name = "Kourama, Démon Renard",
		look = {
			creature = "kurama", -- vrai renard à neuf queues (Modules/CreatureBuilder), pas un perso R6
			skin = rgb(255, 120, 20),
			hair = "none",
			hairColor = rgb(255, 120, 20),
			top = rgb(255, 120, 20),
			bottom = rgb(230, 90, 10),
			outfit = "fur",
			eyes = rgb(255, 40, 20),
			face = "fierce",
			accessories = { "fox_ears", "tails9", "whiskers" },
			accColor = rgb(255, 120, 20),
		},
	},

	-- Académie Occulte
	occ_fleau = {
		-- Fléau cyclope : chair violette veinée, cornes, gueule dentée sur le ventre
		name = "Fléau Mineur",
		look = {
			skin = rgb(146, 116, 176),
			hair = "none",
			hairColor = rgb(146, 116, 176),
			top = rgb(146, 116, 176),
			bottom = rgb(146, 116, 176),
			outfit = "creature",
			pants = "shorts",
			shortsLength = 0.05,
			footwear = "barefoot",
			veins = rgb(96, 60, 130),
			maw = true,
			eyes = rgb(255, 226, 60),
			pupil = "slit",
			face = "angry",
			eyeStyle = "wide",
			mouthStyle = "snarl",
			browStyle = "frown",
			accessories = { "cyclops", "horns", "claws" },
			accColor = rgb(70, 46, 92),
		},
	},
	occ_jogou = {
		-- Fléau du volcan : tête-volcan fumante, œil unique, kimono clair et ceinture sombre
		name = "Jogou",
		look = {
			skin = rgb(228, 216, 192),
			hair = "none",
			hairColor = rgb(80, 60, 50),
			top = rgb(196, 172, 128),
			topAccent = rgb(44, 34, 34),
			underColor = rgb(228, 216, 192),
			bottom = rgb(70, 58, 50),
			pantsStyle = "hakama",
			outfit = "robe",
			footwear = "zori",
			shoes = rgb(60, 46, 40),
			eyes = rgb(60, 40, 30),
			face = "fierce",
			eyeStyle = "sharp",
			mouthStyle = "snarl",
			browStyle = "frown",
			accessories = { "volcano", "cyclops" },
			volcanoColor = rgb(218, 204, 180),
			accColor = rgb(80, 60, 50),
		},
	},
	occ_mahitto = {
		name = "Mahitto",
		look = {
			skin = rgb(200, 210, 220),
			hair = "long",
			hairColor = rgb(100, 120, 150),
			top = rgb(40, 40, 50),
			bottom = rgb(40, 40, 50),
			outfit = "shirt",
			eyes = rgb(100, 180, 200),
			face = "smirk",
			eyeStyle = "wide",
			mouthStyle = "teeth",
			browStyle = "raised",
			accessories = { "stitches" },
		},
	},
	occ_kenjakou = {
		-- Boss de l'Académie Occulte : moine maudit (demi-chignon, kesa en patchwork, couture au front)
		name = "Kenjakou",
		look = {
			skin = rgb(226, 222, 198), -- pâle, légèrement vert : la lumière violette de l'arène la rosit
			hair = "half_bun",
			hairColor = rgb(24, 22, 30),
			hairShine = rgb(92, 88, 120),
			top = rgb(62, 69, 96),
			topAccent = rgb(96, 104, 134),
			underColor = rgb(232, 228, 220),
			bottom = rgb(48, 53, 76),
			pantsStyle = "hakama",
			footwear = "zori",
			shoes = rgb(70, 56, 46),
			outfit = "robe",
			eyes = rgb(96, 60, 92),
			eyeWidth = 0.3,
			face = "smirk",
			eyeStyle = "heavy",
			mouthStyle = "sneer",
			mouthWidth = 0.24,
			browStyle = "low",
			cheekShade = rgb(150, 130, 150),
			kesaColor = rgb(196, 146, 62),
			glowColor = rgb(176, 96, 255),
			accessories = { "stitches_forehead", "stitch_crown", "kesa", "wide_sleeves", "gauge_earrings" },
			accColor = rgb(60, 50, 80),
			boss = { rim = rgb(196, 150, 255), light = rgb(226, 210, 255), aura = rgb(150, 80, 240), paintLight = 0.45 },
		},
	},

	-- Planète des Guerriers
	sai_soldat = {
		name = "Soldat de Freezo",
		look = {
			skin = rgb(200, 150, 200),
			hair = "short",
			hairColor = rgb(60, 30, 60),
			top = rgb(60, 60, 70),
			topAccent = rgb(235, 235, 220),
			bottom = rgb(60, 60, 70),
			outfit = "armor",
			face = "angry",
			eyeStyle = "sharp",
			mouthStyle = "frown",
			browStyle = "frown",
			accessories = { "shoulder_pads", "scouter" },
			accColor = rgb(235, 235, 220),
		},
	},
	sai_saibamon = {
		-- Petit guerrier-plante : crâne bulbeux veiné, yeux rouges sans pupille, griffes
		name = "Saibamon",
		look = {
			skin = rgb(92, 170, 72),
			hair = "none",
			hairColor = rgb(92, 170, 72),
			top = rgb(92, 170, 72),
			bottom = rgb(92, 170, 72),
			outfit = "creature",
			pants = "shorts",
			shortsLength = 0.05,
			footwear = "barefoot",
			veins = rgb(52, 112, 44),
			eyes = rgb(225, 30, 30),
			pupil = "none",
			scleraColor = rgb(225, 40, 40),
			face = "angry",
			eyeStyle = "sharp",
			mouthStyle = "snarl",
			browStyle = "frown",
			accessories = { "saiba_head", "claws" },
			accColor = rgb(60, 140, 50),
		},
	},
	sai_celjr = {
		-- Créature parfaite miniature : peau bleue, carapace verte tachetée, crête et ailes
		name = "Cel Junior",
		look = {
			skin = rgb(120, 176, 236),
			hair = "none",
			hairColor = rgb(70, 150, 90),
			top = rgb(120, 176, 236),
			bottom = rgb(120, 176, 236),
			outfit = "creature",
			carapace = rgb(70, 152, 92),
			limbPlates = rgb(70, 152, 92),
			spots = rgb(24, 36, 26),
			pants = "shorts",
			shortsLength = 0.05,
			footwear = "barefoot",
			eyes = rgb(220, 60, 200),
			face = "smirk",
			eyeStyle = "wide",
			mouthStyle = "smirk",
			browStyle = "none",
			accessories = { "cell_crest", "claws" },
			accColor = rgb(70, 152, 92),
		},
	},
	sai_freezo = {
		-- Boss de la Planète des Guerriers : empereur du froid (forme finale, armure organique violette)
		name = "Freezo",
		look = {
			skin = rgb(246, 246, 252),
			hair = "none",
			hairColor = rgb(246, 246, 252),
			top = rgb(246, 246, 252),
			topAccent = rgb(146, 62, 196),
			bottom = rgb(246, 246, 252),
			outfit = "biosuit",
			sleeves = "skin",
			pants = "shorts",
			shortsLength = 0.05,
			hemBottom = rgb(232, 232, 242),
			footwear = "barefoot",
			eyes = rgb(214, 22, 52),
			face = "smirk",
			eyeStyle = "sharp",
			mouthStyle = "smirk",
			browStyle = "none",
			eyeMarks = rgb(110, 50, 140),
			lipColor = rgb(120, 44, 150),
			headShade = rgb(168, 156, 204),
			cheekShade = rgb(150, 136, 186),
			armPlates = rgb(146, 62, 196),
			shinPlates = rgb(146, 62, 196),
			gemColor = rgb(146, 62, 196),
			accessories = { "freezo_gems", "freezo_tail" },
			accColor = rgb(146, 62, 196),
			boss = { rim = rgb(226, 180, 255), light = rgb(255, 240, 255), aura = rgb(196, 120, 255), paintLight = 0.35, outline = 0.15 },
		},
	},

	-- Grand Océan
	oce_pirate = {
		name = "Pirate de Buggi",
		look = {
			skin = SKIN_TAN,
			hair = "messy",
			hairColor = rgb(60, 40, 30),
			top = rgb(140, 40, 40),
			topAccent = rgb(240, 230, 210),
			bottom = rgb(70, 60, 50),
			outfit = "striped",
			face = "angry",
			eyeStyle = "sharp",
			mouthStyle = "teeth",
			browStyle = "frown",
			accessories = { "bandana", "scar_eye" },
			accColor = rgb(30, 30, 30),
		},
	},
	oce_marine = {
		name = "Marine",
		look = {
			skin = SKIN,
			hair = "short",
			hairColor = rgb(40, 40, 40),
			top = rgb(245, 245, 250),
			topAccent = rgb(40, 90, 200),
			bottom = rgb(40, 90, 200),
			outfit = "sailor",
			face = "angry",
			eyeStyle = "bold",
			mouthStyle = "frown",
			browStyle = "frown",
			accessories = { "cap" },
			accColor = rgb(245, 245, 250),
		},
	},
	oce_arlang = {
		name = "Arlang",
		look = {
			skin = rgb(80, 150, 200),
			hair = "spiky",
			hairColor = rgb(30, 60, 120),
			top = rgb(250, 220, 120),
			bottom = rgb(40, 60, 100),
			outfit = "openshirt",
			face = "angry",
			eyeStyle = "sharp",
			mouthStyle = "snarl",
			browStyle = "frown",
			accessories = { "saw_nose", "fins" },
			accColor = rgb(60, 120, 180),
			sleeveless = true,
		},
	},
	oce_akaino = {
		-- Boss du Grand Océan : amiral magma (costume rouge à roses, manteau de la justice, poing de lave)
		name = "Amiral Akaino",
		look = {
			skin = rgb(236, 196, 160),
			hair = "short",
			hairColor = rgb(25, 25, 28),
			top = rgb(168, 24, 34),
			topAccent = rgb(30, 28, 32),
			bottom = rgb(168, 24, 34),
			outfit = "suit",
			pattern = "roses",
			pantsStyle = "plain",
			shoes = rgb(40, 30, 30),
			face = "angry",
			eyeStyle = "sharp",
			mouthStyle = "frown",
			browStyle = "glower",
			bigBrows = true,
			headScale = 1.13,
			sideburns = rgb(25, 25, 28),
			visorShadow = 0.55,
			jawShade = true,
			eyes = rgb(60, 40, 30),
			eyeHeight = 0.13,
			accessories = { "cap", "cap_badge", "justice_coat", "magma_fist" },
			accColor = rgb(246, 246, 248),
			capBand = rgb(40, 60, 140),
			boss = { rim = rgb(255, 160, 90), light = rgb(255, 210, 170), aura = rgb(255, 100, 30), paintLight = 0.35 },
		},
	},

	-- Ère des Pourfendeurs
	pou_demon = {
		name = "Démon Inférieur",
		look = {
			skin = rgb(170, 160, 150),
			hair = "wild",
			hairColor = rgb(40, 30, 30),
			top = rgb(70, 60, 50),
			bottom = rgb(50, 40, 35),
			outfit = "shirt",
			eyes = rgb(230, 30, 30),
			face = "angry",
			eyeStyle = "wide",
			mouthStyle = "snarl",
			browStyle = "frown",
			accessories = { "horns" },
			accColor = rgb(230, 220, 200),
		},
	},
	pou_ruy = {
		name = "Ruy",
		look = {
			skin = rgb(245, 240, 240),
			hair = "short",
			hairColor = rgb(245, 245, 250),
			top = rgb(245, 245, 250),
			topAccent = rgb(220, 40, 60),
			bottom = rgb(245, 245, 250),
			outfit = "robe",
			eyes = rgb(230, 30, 30),
			face = "calm",
			eyeStyle = "narrow",
			mouthStyle = "line",
			browStyle = "flat",
			accessories = { "facepaint" },
			accColor = rgb(220, 40, 60),
		},
	},
	pou_enmo = {
		name = "Enmo",
		look = {
			skin = rgb(230, 220, 225),
			hair = "short",
			hairColor = rgb(30, 30, 40),
			top = rgb(40, 30, 60),
			topAccent = rgb(120, 200, 230),
			bottom = rgb(40, 30, 60),
			outfit = "robe",
			eyes = rgb(200, 30, 60),
			face = "smirk",
			eyeStyle = "sleepy",
			mouthStyle = "smirk",
			browStyle = "raised",
			accessories = { "facepaint" },
			accColor = rgb(40, 30, 60),
		},
	},
	pou_akazo = {
		-- Boss de l'Ère des Pourfendeurs : lune supérieure (cheveux roses, lignes tatouées, veste
		-- magenta ouverte, sceau de la boussole sous les pieds)
		name = "Akazo",
		look = {
			skin = rgb(244, 210, 204),
			hair = "wild",
			hairLength = 0.62,
			hairColor = rgb(250, 130, 172),
			top = rgb(206, 64, 128),
			outfit = "openvest",
			noButtons = true,
			sleeves = "short",
			bottom = rgb(238, 236, 242),
			pants = "shorts",
			shortsLength = 0.72,
			footwear = "barefoot",
			eyes = rgb(255, 214, 60),
			scleraColor = rgb(214, 236, 252),
			lashColor = rgb(36, 60, 170),
			eyeKanji = rgb(30, 40, 120),
			face = "fierce",
			eyeStyle = "wide",
			mouthStyle = "fang",
			browStyle = "frown",
			bodyTattoo = rgb(50, 80, 210),
			beltColor = rgb(40, 50, 110),
			accessories = { "tattoos_blue", "rope_belt", "compass_sigil" },
			accColor = rgb(50, 80, 210),
			boss = { rim = rgb(170, 225, 255), light = rgb(225, 238, 255), aura = rgb(130, 205, 255), paintLight = 0.35 },
		},
	},
}

function Characters.get(id: string)
	return Characters.List[id]
end

-- Retourne le look final d'un personnage selon ses étoiles (évolutions).
function Characters.resolveLook(id: string, stars: number?)
	local def = Characters.List[id]
	if not def then
		return nil
	end
	local look = table.clone(def.look)
	if def.rarity == "secret" then
		-- Persos Secrets : un peu plus grands que les autres, et un éclat arc-en-ciel discret à leurs
		-- pieds dès le ★1 (exclusivité visible de loin)
		look.bodyScale = look.bodyScale or 1.12
		-- plancher de taille en jeu (après la taille de niveau) : jamais plus petits que l'avatar
		look.minScale = look.minScale or 1.05
	end
	if def.evolve and stars then
		for s = 2, stars do
			local overrides = def.evolve[s]
			if overrides then
				for key, value in overrides do
					if value == false then
						look[key] = nil
					else
						look[key] = value
					end
				end
			end
		end
	end
	if def.rarity == "secret" then
		look.accessories = join(look.accessories or {}, { "secret_glint" })
	end
	return look
end

return Characters
