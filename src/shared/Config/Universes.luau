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
			ground = rgb(150, 105, 70),
			groundAccent = rgb(130, 90, 60),
			clockTime = 14,
			ambient = rgb(140, 120, 100),
			outdoorAmbient = rgb(150, 140, 120),
			atmosphereColor = rgb(255, 230, 200),
			atmosphereDecay = rgb(255, 180, 120),
			haze = 1,
			tint = rgb(255, 245, 235),
			saturation = 0.15,
			-- Sol de toute l'île { couleur, matériau } : herbe, taches, sol de l'anneau, chemins...
			sol = {
				herbe = { rgb(104, 172, 72), Enum.Material.Grass },
				herbe2 = { rgb(132, 190, 84), Enum.Material.LeafyGrass },
				herbe3 = { rgb(80, 146, 62), Enum.Material.Grass },
				anneau = { rgb(112, 176, 74), Enum.Material.Grass },
				terre = { rgb(196, 158, 108), Enum.Material.Ground },
				chemin = { rgb(206, 170, 120), Enum.Material.Ground },
				bordure = { rgb(150, 144, 136), Enum.Material.Cobblestone },
				promenade = { rgb(186, 176, 160), Enum.Material.Cobblestone },
				touffe = { rgb(96, 168, 64) },
				sable = { rgb(236, 216, 160), Enum.Material.Sand },
			},
			-- Ciel et lumière (Lighting, Atmosphere, Clouds, Sky, effets).
			ciel = {
				clockTime = 14.6,
				latitude = 35,
				brightness = 3,
				exposure = 0.1,
				density = 0.3,
				offset = 0.2,
				glare = 0.25,
				haze = 1.1,
				atmosphereColor = rgb(200, 220, 240),
				atmosphereDecay = rgb(120, 160, 210),
				cloudCover = 0.62,
				cloudDensity = 0.55,
				cloudColor = rgb(255, 255, 255),
				stars = 0,
				sunSize = 16,
				moonSize = 11,
				bloom = 0.45,
				sunRays = 0.12,
				contrast = 0.08,
				water = rgb(40, 150, 210),
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
			ground = rgb(80, 75, 85),
			groundAccent = rgb(65, 60, 72),
			clockTime = 18.2,
			ambient = rgb(110, 80, 140),
			outdoorAmbient = rgb(120, 90, 160),
			atmosphereColor = rgb(190, 150, 255),
			atmosphereDecay = rgb(120, 60, 180),
			haze = 2,
			tint = rgb(235, 220, 255),
			saturation = 0.2,
			-- Sol de toute l'île { couleur, matériau } : herbe, taches, sol de l'anneau, chemins...
			sol = {
				herbe = { rgb(70, 92, 70), Enum.Material.Grass },
				herbe2 = { rgb(84, 104, 80), Enum.Material.LeafyGrass },
				herbe3 = { rgb(56, 74, 60), Enum.Material.Grass },
				anneau = { rgb(80, 75, 85), Enum.Material.Slate },
				terre = { rgb(96, 88, 96), Enum.Material.Ground },
				chemin = { rgb(110, 104, 112), Enum.Material.Pavement },
				bordure = { rgb(70, 66, 76), Enum.Material.Slate },
				promenade = { rgb(96, 92, 104), Enum.Material.Cobblestone },
				touffe = { rgb(70, 96, 72) },
				sable = { rgb(150, 140, 130), Enum.Material.Sand },
			},
			-- Ciel et lumière (Lighting, Atmosphere, Clouds, Sky, effets).
			ciel = {
				clockTime = 18.2,
				latitude = 20,
				brightness = 2,
				exposure = 0,
				density = 0.4,
				offset = 0.1,
				glare = 0.6,
				haze = 2,
				atmosphereColor = rgb(190, 150, 255),
				atmosphereDecay = rgb(120, 60, 180),
				cloudCover = 0.75,
				cloudDensity = 0.7,
				cloudColor = rgb(200, 170, 230),
				stars = 1500,
				sunSize = 20,
				moonSize = 14,
				bloom = 0.7,
				sunRays = 0.2,
				contrast = 0.12,
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
			ground = rgb(215, 180, 120),
			groundAccent = rgb(195, 160, 105),
			clockTime = 12,
			ambient = rgb(140, 140, 120),
			outdoorAmbient = rgb(160, 160, 140),
			atmosphereColor = rgb(220, 240, 255),
			atmosphereDecay = rgb(170, 210, 255),
			haze = 0.5,
			tint = rgb(255, 255, 245),
			saturation = 0.25,
			-- Sol de toute l'île { couleur, matériau } : herbe, taches, sol de l'anneau, chemins...
			sol = {
				herbe = { rgb(120, 180, 110), Enum.Material.Grass },
				herbe2 = { rgb(214, 186, 128), Enum.Material.Sandstone },
				herbe3 = { rgb(96, 160, 100), Enum.Material.Grass },
				anneau = { rgb(215, 180, 120), Enum.Material.Sandstone },
				terre = { rgb(200, 164, 110), Enum.Material.Ground },
				chemin = { rgb(226, 200, 150), Enum.Material.Sandstone },
				bordure = { rgb(180, 150, 110), Enum.Material.Sandstone },
				promenade = { rgb(220, 210, 190), Enum.Material.Pavement },
				touffe = { rgb(110, 176, 104) },
				sable = { rgb(240, 222, 170), Enum.Material.Sand },
			},
			-- Ciel et lumière (Lighting, Atmosphere, Clouds, Sky, effets).
			ciel = {
				clockTime = 12,
				latitude = 10,
				brightness = 3.2,
				exposure = 0.15,
				density = 0.22,
				offset = 0.1,
				glare = 0.2,
				haze = 0.5,
				atmosphereColor = rgb(220, 240, 255),
				atmosphereDecay = rgb(170, 210, 255),
				cloudCover = 0.45,
				cloudDensity = 0.5,
				cloudColor = rgb(255, 255, 255),
				stars = 0,
				sunSize = 22,
				moonSize = 11,
				bloom = 0.5,
				sunRays = 0.15,
				contrast = 0.1,
				water = rgb(50, 170, 220),
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
			ground = rgb(240, 220, 160),
			groundAccent = rgb(225, 205, 145),
			clockTime = 15,
			ambient = rgb(120, 140, 160),
			outdoorAmbient = rgb(140, 160, 180),
			atmosphereColor = rgb(200, 235, 255),
			atmosphereDecay = rgb(100, 180, 255),
			haze = 0.8,
			tint = rgb(240, 250, 255),
			saturation = 0.25,
			-- Sol de toute l'île { couleur, matériau } : herbe, taches, sol de l'anneau, chemins...
			sol = {
				herbe = { rgb(110, 190, 80), Enum.Material.Grass },
				herbe2 = { rgb(236, 220, 160), Enum.Material.Sand },
				herbe3 = { rgb(90, 170, 70), Enum.Material.Grass },
				anneau = { rgb(240, 220, 160), Enum.Material.Sand },
				terre = { rgb(226, 204, 146), Enum.Material.Sand },
				chemin = { rgb(180, 130, 86), Enum.Material.WoodPlanks },
				bordure = { rgb(140, 100, 66), Enum.Material.Wood },
				promenade = { rgb(180, 132, 88), Enum.Material.WoodPlanks },
				touffe = { rgb(110, 190, 80) },
				sable = { rgb(246, 230, 176), Enum.Material.Sand },
			},
			-- Ciel et lumière (Lighting, Atmosphere, Clouds, Sky, effets).
			ciel = {
				clockTime = 15,
				latitude = 5,
				brightness = 3.2,
				exposure = 0.15,
				density = 0.25,
				offset = 0.15,
				glare = 0.3,
				haze = 0.8,
				atmosphereColor = rgb(200, 235, 255),
				atmosphereDecay = rgb(100, 180, 255),
				cloudCover = 0.5,
				cloudDensity = 0.5,
				cloudColor = rgb(255, 255, 255),
				stars = 0,
				sunSize = 18,
				moonSize = 11,
				bloom = 0.5,
				sunRays = 0.12,
				contrast = 0.08,
				water = rgb(30, 170, 220),
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
			ground = rgb(95, 75, 65),
			groundAccent = rgb(80, 62, 55),
			clockTime = 0.5,
			ambient = rgb(90, 80, 130),
			outdoorAmbient = rgb(100, 90, 150),
			atmosphereColor = rgb(170, 150, 230),
			atmosphereDecay = rgb(90, 60, 150),
			haze = 1.5,
			tint = rgb(230, 225, 255),
			saturation = 0.15,
			-- Sol de toute l'île { couleur, matériau } : herbe, taches, sol de l'anneau, chemins...
			sol = {
				herbe = { rgb(58, 92, 62), Enum.Material.Grass },
				herbe2 = { rgb(72, 104, 70), Enum.Material.LeafyGrass },
				herbe3 = { rgb(46, 76, 54), Enum.Material.Grass },
				anneau = { rgb(64, 96, 64), Enum.Material.Grass },
				terre = { rgb(95, 75, 65), Enum.Material.Ground },
				chemin = { rgb(110, 90, 78), Enum.Material.Ground },
				bordure = { rgb(80, 76, 84), Enum.Material.Cobblestone },
				promenade = { rgb(100, 96, 104), Enum.Material.Cobblestone },
				touffe = { rgb(60, 96, 64) },
				sable = { rgb(170, 160, 150), Enum.Material.Sand },
			},
			-- Ciel et lumière (Lighting, Atmosphere, Clouds, Sky, effets).
			ciel = {
				clockTime = 0.5,
				latitude = 30,
				brightness = 1.6,
				exposure = 0,
				density = 0.35,
				offset = 0.15,
				glare = 0.5,
				haze = 1.5,
				atmosphereColor = rgb(170, 150, 230),
				atmosphereDecay = rgb(90, 60, 150),
				cloudCover = 0.5,
				cloudDensity = 0.5,
				cloudColor = rgb(150, 140, 200),
				stars = 3000,
				sunSize = 14,
				moonSize = 26,
				bloom = 0.8,
				sunRays = 0.05,
				contrast = 0.1,
				water = rgb(40, 50, 110),
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
