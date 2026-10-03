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
