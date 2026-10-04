-- Les univers qui tournent toutes les 30 minutes.
-- Chaque univers a : ses reliques (= les "œufs"), ses ennemis, son boss,
-- son matériau d'évolution, son décor et son ambiance lumineuse.

local rgb = Color3.fromRGB

local Universes = {}

Universes.List = {
	{
		id = "ninja",
		name = "Village Ninja",
		inspiration = "Naruto",
		color = rgb(255, 140, 30),
		material = { id = "chakra", name = "Fragment de Chakra", color = rgb(70, 170, 255) },
		relics = {
			{
				id = "ninja_r1",
				name = "Parchemin d'Entraînement",
				tier = 1,
				look = { kind = "scroll", color = rgb(70, 140, 230), accent = rgb(240, 220, 170) },
				odds = { common = 70, rare = 25, epic = 4.5, legendary = 0.5 },
			},
			{
				id = "ninja_r2",
				name = "Parchemin Secret",
				tier = 2,
				look = { kind = "scroll", color = rgb(210, 40, 50), accent = rgb(245, 230, 190) },
				odds = { common = 25, rare = 45, epic = 24, legendary = 5.5, mythic = 0.5 },
			},
			{
				id = "ninja_r3",
				name = "Parchemin Interdit",
				tier = 3,
				look = { kind = "scroll", color = rgb(120, 40, 160), accent = rgb(255, 210, 70) },
				odds = { rare = 20, epic = 50, legendary = 25, mythic = 5 },
			},
		},
		characters = { "ninja_rokli", "ninja_konohamaro", "ninja_sakoura", "ninja_shikamaro", "ninja_sasuki", "ninja_kakashu", "ninja_maruto", "ninja_itochi" },
		enemies = { "ninja_son", "ninja_kabouto", "ninja_zabouza" },
		boss = "ninja_kourama",
		theme = {
			decor = "ninja",
			-- Compatibilité (ancien décor) : couleurs de base du sol de l'anneau.
			ground = rgb(104, 146, 68),
			groundAccent = rgb(88, 130, 52),
			clockTime = 14.4,
			ambient = rgb(120, 110, 100),
			outdoorAmbient = rgb(132, 128, 120),
			atmosphereColor = rgb(198, 214, 232),
			atmosphereDecay = rgb(110, 150, 200),
			haze = 1.3,
			tint = rgb(255, 248, 240),
			saturation = 0.04,
			-- Sol de TOUTE la carte { couleur, matériau } (pièces marquées par un rôle, voir World/Kit/Core) :
			-- herbe, collines, falaises, pavés, eau, berges, sol de l'anneau, plages, mer...
			sol = {
				herbe = { rgb(98, 142, 66), Enum.Material.Grass },
				herbe2 = { rgb(118, 156, 74), Enum.Material.LeafyGrass },
				herbe3 = { rgb(80, 124, 58), Enum.Material.Grass },
				anneau = { rgb(104, 146, 68), Enum.Material.Grass },
				terre = { rgb(178, 142, 100), Enum.Material.Ground },
				chemin = { rgb(186, 152, 108), Enum.Material.Ground },
				pave = { rgb(166, 156, 140), Enum.Material.Cobblestone },
				bordure = { rgb(140, 134, 126), Enum.Material.Slate },
				promenade = { rgb(176, 166, 148), Enum.Material.Cobblestone },
				touffe = { rgb(92, 136, 60) },
				sable = { rgb(224, 204, 156), Enum.Material.Sand },
				roche = { rgb(134, 128, 120), Enum.Material.Rock },
				falaise = { rgb(146, 128, 106), Enum.Material.Rock },
				berge = { rgb(120, 100, 76), Enum.Material.Ground },
				lit = { rgb(56, 72, 62), Enum.Material.Mud },
				eau = { rgb(64, 128, 136), Enum.Material.Glass },
				dalle = { rgb(150, 146, 140), Enum.Material.Slate },
				laque = { rgb(186, 60, 44), Enum.Material.SmoothPlastic },
				mer = { rgb(40, 120, 170), Enum.Material.Glass },
			},
			-- Ciel et lumière (Lighting, Atmosphere, Clouds, Sky, effets).
			ciel = {
				clockTime = 14.4,
				latitude = 35,
				brightness = 2.6,
				exposure = 0.05,
				density = 0.3,
				offset = 0.22,
				glare = 0.2,
				haze = 1.3,
				atmosphereColor = rgb(198, 214, 232),
				atmosphereDecay = rgb(110, 150, 200),
				cloudCover = 0.62,
				cloudDensity = 0.5,
				cloudColor = rgb(255, 255, 255),
				stars = 0,
				sunSize = 16,
				moonSize = 11,
				bloom = 0.35,
				sunRays = 0.08,
				contrast = 0.1,
				water = rgb(40, 120, 170),
			},
		},
	},
	{
		id = "occulte",
		name = "Académie Occulte",
		inspiration = "Jujutsu Kaisen",
		color = rgb(150, 70, 255),
		material = { id = "maudite", name = "Énergie Maudite", color = rgb(170, 60, 255) },
		relics = {
			{
				id = "occulte_r1",
				name = "Talisman Scellé",
				tier = 1,
				look = { kind = "talisman", color = rgb(245, 235, 200), accent = rgb(200, 30, 40) },
				odds = { common = 70, rare = 25, epic = 4.5, legendary = 0.5 },
			},
			{
				id = "occulte_r2",
				name = "Coffret Maudit",
				tier = 2,
				look = { kind = "box", color = rgb(60, 30, 80), accent = rgb(200, 160, 60) },
				odds = { common = 25, rare = 45, epic = 24, legendary = 5.5, mythic = 0.5 },
			},
			{
				id = "occulte_r3",
				name = "Doigt du Roi",
				tier = 3,
				look = { kind = "finger", color = rgb(110, 70, 60), accent = rgb(60, 20, 30) },
				odds = { rare = 20, epic = 50, legendary = 25, mythic = 5 },
			},
		},
		characters = { "occ_toudo", "occ_inumako", "occ_nobora", "occ_megumo", "occ_yuzi", "occ_mako", "occ_goju", "occ_sukana" },
		enemies = { "occ_fleau", "occ_jogou", "occ_mahitto" },
		boss = "occ_kenjakou",
		theme = {
			decor = "occulte",
			-- Compatibilité (ancien décor) : couleurs de base du sol de l'anneau.
			ground = rgb(104, 100, 106),
			groundAccent = rgb(88, 84, 90),
			clockTime = 18.4,
			ambient = rgb(90, 70, 120),
			outdoorAmbient = rgb(110, 92, 150),
			atmosphereColor = rgb(170, 140, 230),
			atmosphereDecay = rgb(110, 60, 170),
			haze = 2.4,
			tint = rgb(236, 222, 255),
			saturation = 0,
			-- Sol de TOUTE la carte { couleur, matériau } (pièces marquées par un rôle, voir World/Kit/Core) :
			-- herbe, collines, falaises, pavés, eau, berges, sol de l'anneau, plages, mer...
			sol = {
				herbe = { rgb(64, 78, 62), Enum.Material.Grass },
				herbe2 = { rgb(76, 88, 70), Enum.Material.LeafyGrass },
				herbe3 = { rgb(52, 64, 54), Enum.Material.Grass },
				anneau = { rgb(104, 100, 106), Enum.Material.Pebble },
				terre = { rgb(92, 84, 88), Enum.Material.Ground },
				chemin = { rgb(100, 94, 100), Enum.Material.Ground },
				pave = { rgb(98, 94, 104), Enum.Material.Cobblestone },
				bordure = { rgb(68, 64, 72), Enum.Material.Slate },
				promenade = { rgb(90, 86, 98), Enum.Material.Cobblestone },
				touffe = { rgb(66, 84, 64) },
				sable = { rgb(140, 132, 128), Enum.Material.Sand },
				roche = { rgb(92, 88, 98), Enum.Material.Rock },
				falaise = { rgb(84, 80, 92), Enum.Material.Slate },
				berge = { rgb(70, 62, 66), Enum.Material.Ground },
				lit = { rgb(30, 28, 40), Enum.Material.Mud },
				eau = { rgb(70, 50, 110), Enum.Material.Glass },
				dalle = { rgb(110, 106, 116), Enum.Material.Slate },
				laque = { rgb(150, 30, 40), Enum.Material.SmoothPlastic },
				mer = { rgb(50, 40, 90), Enum.Material.Glass },
			},
			-- Ciel et lumière (Lighting, Atmosphere, Clouds, Sky, effets).
			ciel = {
				clockTime = 18.4,
				latitude = 20,
				brightness = 1.6,
				exposure = -0.05,
				density = 0.42,
				offset = 0.12,
				glare = 0.6,
				haze = 2.4,
				atmosphereColor = rgb(170, 140, 230),
				atmosphereDecay = rgb(110, 60, 170),
				cloudCover = 0.72,
				cloudDensity = 0.65,
				cloudColor = rgb(190, 160, 220),
				stars = 2000,
				sunSize = 22,
				moonSize = 14,
				bloom = 0.6,
				sunRays = 0.18,
				contrast = 0.14,
				water = rgb(60, 40, 110),
			},
		},
	},
	{
		id = "saiyan",
		name = "Planète des Guerriers",
		inspiration = "Dragon Ball",
		color = rgb(255, 200, 40),
		material = { id = "ki", name = "Éclat de Ki", color = rgb(255, 190, 40) },
		relics = {
			{
				id = "saiyan_r1",
				name = "Petite Capsule",
				tier = 1,
				look = { kind = "capsule", color = rgb(245, 245, 245), accent = rgb(230, 50, 50) },
				odds = { common = 70, rare = 25, epic = 4.5, legendary = 0.5 },
			},
			{
				id = "saiyan_r2",
				name = "Boule de Cristal",
				tier = 2,
				look = { kind = "orb", color = rgb(255, 160, 30), accent = rgb(230, 40, 30) },
				odds = { common = 25, rare = 45, epic = 24, legendary = 5.5, mythic = 0.5 },
			},
			{
				id = "saiyan_r3",
				name = "Boule Divine",
				tier = 3,
				look = { kind = "orb", color = rgb(255, 230, 90), accent = rgb(255, 255, 255) },
				odds = { rare = 20, epic = 50, legendary = 25, mythic = 5 },
			},
		},
		characters = { "sai_yamcho", "sai_krilin", "sai_piccola", "sai_c81", "sai_vejeta", "sai_gohon", "sai_goko", "sai_beeros" },
		enemies = { "sai_soldat", "sai_saibamon", "sai_celjr" },
		boss = "sai_freezo",
		theme = {
			decor = "saiyan",
			-- Compatibilité (ancien décor) : couleurs de base du sol de l'anneau.
			ground = rgb(196, 172, 128),
			groundAccent = rgb(180, 156, 112),
			clockTime = 12.8,
			ambient = rgb(130, 140, 125),
			outdoorAmbient = rgb(150, 165, 145),
			atmosphereColor = rgb(190, 236, 200),
			atmosphereDecay = rgb(140, 210, 170),
			haze = 1.4,
			tint = rgb(245, 255, 245),
			saturation = 0.08,
			-- Sol de TOUTE la carte { couleur, matériau } (pièces marquées par un rôle, voir World/Kit/Core) :
			-- herbe, collines, falaises, pavés, eau, berges, sol de l'anneau, plages, mer...
			sol = {
				herbe = { rgb(112, 170, 128), Enum.Material.Grass },
				herbe2 = { rgb(130, 186, 140), Enum.Material.LeafyGrass },
				herbe3 = { rgb(92, 150, 112), Enum.Material.Grass },
				anneau = { rgb(196, 172, 128), Enum.Material.Ground },
				terre = { rgb(196, 164, 118), Enum.Material.Ground },
				chemin = { rgb(206, 180, 134), Enum.Material.Ground },
				pave = { rgb(214, 206, 190), Enum.Material.Pavement },
				bordure = { rgb(176, 168, 152), Enum.Material.Concrete },
				promenade = { rgb(220, 212, 196), Enum.Material.Pavement },
				touffe = { rgb(100, 160, 118) },
				sable = { rgb(232, 220, 180), Enum.Material.Sand },
				roche = { rgb(196, 160, 112), Enum.Material.Sandstone },
				falaise = { rgb(200, 158, 108), Enum.Material.Sandstone },
				berge = { rgb(170, 150, 110), Enum.Material.Ground },
				lit = { rgb(60, 120, 110), Enum.Material.Sand },
				eau = { rgb(70, 190, 170), Enum.Material.Glass },
				dalle = { rgb(220, 214, 200), Enum.Material.Pavement },
				laque = { rgb(236, 236, 230), Enum.Material.SmoothPlastic },
				mer = { rgb(60, 170, 160), Enum.Material.Glass },
			},
			-- Ciel et lumière (Lighting, Atmosphere, Clouds, Sky, effets).
			ciel = {
				clockTime = 12.8,
				latitude = 10,
				brightness = 3,
				exposure = 0.15,
				density = 0.26,
				offset = 0.3,
				glare = 0.3,
				haze = 1.4,
				atmosphereColor = rgb(190, 236, 200),
				atmosphereDecay = rgb(140, 210, 170),
				cloudCover = 0.45,
				cloudDensity = 0.4,
				cloudColor = rgb(240, 255, 240),
				stars = 0,
				sunSize = 20,
				moonSize = 11,
				bloom = 0.4,
				sunRays = 0.14,
				contrast = 0.08,
				water = rgb(60, 170, 160),
			},
		},
	},
	{
		id = "ocean",
		name = "Grand Océan",
		inspiration = "One Piece",
		color = rgb(40, 170, 255),
		material = { id = "perle", name = "Perle des Abysses", color = rgb(60, 230, 220) },
		relics = {
			{
				id = "ocean_r1",
				name = "Bouteille à la Mer",
				tier = 1,
				look = { kind = "bottle", color = rgb(120, 220, 200), accent = rgb(240, 225, 180) },
				odds = { common = 70, rare = 25, epic = 4.5, legendary = 0.5 },
			},
			{
				id = "ocean_r2",
				name = "Coffre au Trésor",
				tier = 2,
				look = { kind = "chest", color = rgb(140, 90, 50), accent = rgb(255, 200, 60) },
				odds = { common = 25, rare = 45, epic = 24, legendary = 5.5, mythic = 0.5 },
			},
			{
				id = "ocean_r3",
				name = "Fruit du Démon",
				tier = 3,
				look = { kind = "fruit", color = rgb(150, 60, 200), accent = rgb(60, 160, 60) },
				odds = { rare = 20, epic = 50, legendary = 25, mythic = 5 },
			},
		},
		characters = { "oce_kobi", "oce_buggi", "oce_usupp", "oce_nomi", "oce_zoru", "oce_sanjo", "oce_loffy", "oce_shonks" },
		enemies = { "oce_pirate", "oce_marine", "oce_arlang" },
		boss = "oce_akaino",
		theme = {
			decor = "ocean",
			-- Compatibilité (ancien décor) : couleurs de base du sol de l'anneau.
			ground = rgb(226, 206, 156),
			groundAccent = rgb(210, 190, 140),
			clockTime = 13.2,
			ambient = rgb(130, 130, 120),
			outdoorAmbient = rgb(150, 150, 140),
			atmosphereColor = rgb(200, 230, 250),
			atmosphereDecay = rgb(120, 180, 230),
			haze = 1.0,
			tint = rgb(255, 250, 240),
			saturation = 0.1,
			-- Sol de TOUTE la carte { couleur, matériau } (pièces marquées par un rôle, voir World/Kit/Core) :
			-- herbe, collines, falaises, pavés, eau, berges, sol de l'anneau, plages, mer...
			sol = {
				herbe = { rgb(96, 156, 70), Enum.Material.Grass },
				herbe2 = { rgb(118, 172, 80), Enum.Material.LeafyGrass },
				herbe3 = { rgb(78, 138, 60), Enum.Material.Grass },
				anneau = { rgb(226, 206, 156), Enum.Material.Sand },
				terre = { rgb(214, 190, 140), Enum.Material.Sand },
				chemin = { rgb(220, 198, 150), Enum.Material.Sand },
				pave = { rgb(196, 176, 148), Enum.Material.Cobblestone },
				bordure = { rgb(170, 156, 134), Enum.Material.Slate },
				promenade = { rgb(170, 128, 86), Enum.Material.WoodPlanks },
				touffe = { rgb(100, 160, 70) },
				sable = { rgb(240, 224, 176), Enum.Material.Sand },
				roche = { rgb(180, 170, 150), Enum.Material.Limestone },
				falaise = { rgb(196, 184, 160), Enum.Material.Limestone },
				berge = { rgb(220, 200, 150), Enum.Material.Sand },
				lit = { rgb(60, 160, 170), Enum.Material.Sand },
				eau = { rgb(60, 190, 210), Enum.Material.Glass },
				dalle = { rgb(210, 200, 180), Enum.Material.Slate },
				laque = { rgb(140, 96, 60), Enum.Material.Wood },
				mer = { rgb(30, 150, 190), Enum.Material.Glass },
			},
			-- Ciel et lumière (Lighting, Atmosphere, Clouds, Sky, effets).
			ciel = {
				clockTime = 13.2,
				latitude = 5,
				brightness = 3.2,
				exposure = 0.15,
				density = 0.24,
				offset = 0.3,
				glare = 0.35,
				haze = 1.0,
				atmosphereColor = rgb(200, 230, 250),
				atmosphereDecay = rgb(120, 180, 230),
				cloudCover = 0.5,
				cloudDensity = 0.45,
				cloudColor = rgb(255, 255, 255),
				stars = 0,
				sunSize = 18,
				moonSize = 11,
				bloom = 0.4,
				sunRays = 0.16,
				contrast = 0.1,
				water = rgb(30, 150, 190),
			},
		},
	},
	{
		id = "pourfendeur",
		name = "Ère des Pourfendeurs",
		inspiration = "Demon Slayer",
		color = rgb(230, 50, 70),
		material = { id = "sang", name = "Sang de Démon", color = rgb(220, 30, 50) },
		relics = {
			{
				id = "pourfendeur_r1",
				name = "Garde de Sabre",
				tier = 1,
				look = { kind = "tsuba", color = rgb(60, 60, 70), accent = rgb(200, 170, 80) },
				odds = { common = 70, rare = 25, epic = 4.5, legendary = 0.5 },
			},
			{
				id = "pourfendeur_r2",
				name = "Masque de Renard",
				tier = 2,
				look = { kind = "mask", color = rgb(245, 245, 240), accent = rgb(220, 40, 50) },
				odds = { common = 25, rare = 45, epic = 24, legendary = 5.5, mythic = 0.5 },
			},
			{
				id = "pourfendeur_r3",
				name = "Lys Araignée Bleu",
				tier = 3,
				look = { kind = "lily", color = rgb(60, 120, 255), accent = rgb(40, 120, 60) },
				odds = { rare = 20, epic = 50, legendary = 25, mythic = 5 },
			},
		},
		characters = { "pou_genyo", "pou_kanoa", "pou_zenitso", "pou_inosoke", "pou_tanjiru", "pou_nezoko", "pou_rengoko", "pou_yoriichu" },
		enemies = { "pou_demon", "pou_ruy", "pou_enmo" },
		boss = "pou_akazo",
		theme = {
			decor = "pourfendeur",
			-- Compatibilité (ancien décor) : couleurs de base du sol de l'anneau.
			ground = rgb(84, 74, 70),
			groundAccent = rgb(68, 58, 54),
			clockTime = 0.5,
			ambient = rgb(70, 70, 110),
			outdoorAmbient = rgb(92, 98, 145),
			atmosphereColor = rgb(100, 110, 170),
			atmosphereDecay = rgb(60, 60, 120),
			haze = 1.6,
			tint = rgb(220, 226, 255),
			saturation = -0.02,
			-- Sol de TOUTE la carte { couleur, matériau } (pièces marquées par un rôle, voir World/Kit/Core) :
			-- herbe, collines, falaises, pavés, eau, berges, sol de l'anneau, plages, mer...
			sol = {
				herbe = { rgb(46, 70, 58), Enum.Material.Grass },
				herbe2 = { rgb(56, 80, 64), Enum.Material.LeafyGrass },
				herbe3 = { rgb(38, 58, 50), Enum.Material.Grass },
				anneau = { rgb(84, 74, 70), Enum.Material.Ground },
				terre = { rgb(92, 80, 72), Enum.Material.Ground },
				chemin = { rgb(96, 86, 80), Enum.Material.Ground },
				pave = { rgb(84, 82, 92), Enum.Material.Cobblestone },
				bordure = { rgb(60, 58, 66), Enum.Material.Slate },
				promenade = { rgb(80, 78, 90), Enum.Material.Cobblestone },
				touffe = { rgb(48, 74, 60) },
				sable = { rgb(120, 116, 120), Enum.Material.Sand },
				roche = { rgb(76, 76, 88), Enum.Material.Rock },
				falaise = { rgb(70, 70, 84), Enum.Material.Rock },
				berge = { rgb(56, 52, 56), Enum.Material.Ground },
				lit = { rgb(20, 24, 36), Enum.Material.Mud },
				eau = { rgb(40, 60, 110), Enum.Material.Glass },
				dalle = { rgb(96, 94, 104), Enum.Material.Slate },
				laque = { rgb(120, 36, 40), Enum.Material.SmoothPlastic },
				mer = { rgb(20, 40, 80), Enum.Material.Glass },
			},
			-- Ciel et lumière (Lighting, Atmosphere, Clouds, Sky, effets).
			ciel = {
				clockTime = 0.5,
				latitude = 40,
				brightness = 1.4,
				exposure = 0.35,
				density = 0.36,
				offset = 0.1,
				glare = 0,
				haze = 1.6,
				atmosphereColor = rgb(100, 110, 170),
				atmosphereDecay = rgb(60, 60, 120),
				cloudCover = 0.4,
				cloudDensity = 0.4,
				cloudColor = rgb(120, 120, 170),
				stars = 4000,
				sunSize = 16,
				moonSize = 30,
				bloom = 0.7,
				sunRays = 0.05,
				contrast = 0.15,
				water = rgb(20, 40, 80),
			},
		},
	},
}

Universes.ById = {}
for index, universe in Universes.List do
	universe.index = index
	Universes.ById[universe.id] = universe
end

-- Toutes les reliques indexées par id.
Universes.Relics = {}
for _, universe in Universes.List do
	for _, relic in universe.relics do
		relic.universe = universe.id
		Universes.Relics[relic.id] = relic
	end
end

-- Tous les matériaux indexés par id.
Universes.Materials = {}
for _, universe in Universes.List do
	universe.material.universe = universe.id
	Universes.Materials[universe.material.id] = universe.material
end

function Universes.get(id: string)
	return Universes.ById[id]
end

function Universes.getRelic(id: string)
	return Universes.Relics[id]
end

function Universes.getMaterial(id: string)
	return Universes.Materials[id]
end

return Universes
