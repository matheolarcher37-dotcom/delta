-- Effets signature des attaques (lus par src/client/Controllers/Effects.luau).
--
-- Chaque perso a UN effet signature (attribut "AttackFx" posé sur son modèle par CharacterService).
-- Un effet = une « famille » (le code de l'effet dans Effects.luau) + des réglages :
--   name        nom affiché au-dessus du perso pendant l'attaque spéciale
--   family      famille d'effet (voir la liste plus bas)
--   color       couleur principale ; color2 = couleur secondaire ; core = couleur du cœur (blanc par défaut)
--   size        taille de l'effet (1 = normal)
--   charge      durée de la charge avant l'attaque spéciale (secondes)
--   shake       force de la secousse d'écran (attaque spéciale, seulement pour TES persos)
--   flash       opacité du flash d'écran (0 = aucun)
--   variant     variante de la famille (forme différente)
--
-- Familles signature (effets uniques et complets) :
--   rasengan, chidori, kamehameha, hollow_purple, dismantle, gomu, santoryu, hinokami
-- Familles réutilisables (paramétrées par couleur / forme / variante) :
--   impact (coups de poing / pied), orb (boules d'énergie), beam (rayons), slash (lames),
--   bolt (foudre), flame (flammes), shadow (ombres / malédictions), nails (clous), bullets (tirs)
--
-- Pour changer l'effet d'un perso : modifie la ligne correspondante dans AttackFx.Characters.

local rgb = Color3.fromRGB

local AttackFx = {}

AttackFx.Signatures = {
	------------------------------------------------------------------
	-- Signatures complètes
	------------------------------------------------------------------
	rasengan = {
		name = "Rasengan",
		family = "rasengan",
		color = rgb(80, 180, 255),
		color2 = rgb(190, 240, 255),
		size = 1,
		charge = 0.55,
		shake = 1,
		flash = 0.18,
	},
	rasengan_mini = {
		name = "Mini Rasengan",
		family = "rasengan",
		variant = "mini",
		color = rgb(110, 200, 255),
		color2 = rgb(210, 245, 255),
		size = 0.65,
		charge = 0.35,
		shake = 0.5,
		flash = 0,
	},
	chidori = {
		name = "Chidori",
		family = "chidori",
		color = rgb(120, 190, 255),
		color2 = rgb(225, 240, 255),
		size = 1,
		charge = 0.6,
		shake = 1,
		flash = 0.2,
	},
	raikiri = {
		name = "Raikiri",
		family = "chidori",
		variant = "raikiri",
		color = rgb(170, 220, 255),
		color2 = rgb(255, 255, 255),
		size = 1,
		charge = 0.5,
		shake = 0.9,
		flash = 0.2,
	},
	kamehameha = {
		name = "Kamehameha",
		family = "kamehameha",
		color = rgb(70, 170, 255),
		color2 = rgb(190, 235, 255),
		size = 1.15,
		charge = 0.75,
		shake = 1.4,
		flash = 0.3,
	},
	galick_gun = {
		name = "Canon Galactique",
		family = "kamehameha",
		variant = "galick",
		color = rgb(190, 80, 255),
		color2 = rgb(240, 200, 255),
		size = 1.05,
		charge = 0.65,
		shake = 1.2,
		flash = 0.25,
	},
	masenko = {
		name = "Masenko",
		family = "kamehameha",
		variant = "masenko",
		color = rgb(255, 220, 80),
		color2 = rgb(255, 250, 200),
		size = 0.95,
		charge = 0.55,
		shake = 1,
		flash = 0.22,
	},
	hollow_purple = {
		name = "Violet Imaginaire",
		family = "hollow_purple",
		color = rgb(170, 60, 255),
		color2 = rgb(255, 60, 70), -- rouge (inversion)
		color3 = rgb(60, 140, 255), -- bleu (attraction)
		size = 1.2,
		charge = 0.8,
		shake = 1.6,
		flash = 0.35,
	},
	dismantle = {
		name = "Découpe Démoniaque",
		family = "dismantle",
		color = rgb(255, 40, 60),
		color2 = rgb(20, 0, 5),
		size = 1.1,
		charge = 0.45,
		shake = 1.3,
		flash = 0.25,
	},
	gomu = {
		name = "Gatling... Red Hawk !",
		family = "gomu",
		color = rgb(255, 80, 80),
		color2 = rgb(255, 170, 40),
		skin = rgb(255, 210, 170),
		size = 1,
		charge = 0.45,
		shake = 1.3,
		flash = 0.2,
	},
	santoryu = {
		name = "Santoryu : Oni Giri",
		family = "santoryu",
		color = rgb(110, 255, 140),
		color2 = rgb(220, 255, 230),
		size = 1.05,
		charge = 0.5,
		shake = 1.2,
		flash = 0.15,
	},
	hinokami = {
		name = "Hinokami Kagura",
		family = "hinokami",
		variant = "tanjiru",
		color = rgb(255, 120, 30), -- feu du soleil (attaque spéciale)
		color2 = rgb(255, 230, 120),
		water = rgb(70, 170, 255), -- souffle de l'eau (attaques normales)
		size = 1.05,
		charge = 0.55,
		shake = 1.2,
		flash = 0.2,
	},
	rengoku = {
		name = "Neuvième Forme : Rengoku",
		family = "hinokami",
		variant = "rengoku",
		color = rgb(255, 100, 20),
		color2 = rgb(255, 220, 90),
		size = 1.2,
		charge = 0.6,
		shake = 1.4,
		flash = 0.25,
	},
	sun_dance = {
		name = "Danse du Soleil : 13e Forme",
		family = "hinokami",
		variant = "yoriichi",
		color = rgb(255, 190, 50),
		color2 = rgb(255, 245, 190),
		size = 1.25,
		charge = 0.6,
		shake = 1.4,
		flash = 0.3,
	},

	------------------------------------------------------------------
	-- Familles réutilisables
	------------------------------------------------------------------
	-- Coups (impact)
	lotus = { name = "Lotus Recto", family = "impact", variant = "kick", color = rgb(255, 240, 200), color2 = rgb(255, 150, 60), size = 1, charge = 0.35, shake = 0.8, flash = 0 },
	cherry_fist = {
		name = "Poing Cerisier",
		family = "impact",
		variant = "smash",
		color = rgb(255, 120, 180),
		color2 = rgb(255, 210, 230),
		petals = true,
		size = 1.15,
		charge = 0.4,
		shake = 1.1,
		flash = 0,
	},
	boogie_clap = { name = "Frappe Bravo", family = "impact", variant = "clap", color = rgb(120, 140, 255), color2 = rgb(220, 225, 255), size = 1, charge = 0.35, shake = 0.9, flash = 0 },
	divergent_fist = {
		name = "Poing Divergent",
		family = "impact",
		variant = "divergent",
		color = rgb(60, 90, 255),
		color2 = rgb(10, 0, 30),
		size = 1.05,
		charge = 0.4,
		shake = 1.1,
		flash = 0.15,
	},
	wolf_fang = { name = "Poing du Loup", family = "impact", variant = "multi", color = rgb(255, 240, 150), color2 = rgb(255, 255, 230), size = 0.95, charge = 0.3, shake = 0.7, flash = 0 },
	rokushiki = { name = "Rokushiki", family = "impact", variant = "multi", color = rgb(220, 220, 255), color2 = rgb(255, 255, 255), size = 0.9, charge = 0.3, shake = 0.7, flash = 0 },
	basic_punch = { name = "Coup", family = "impact", variant = "punch", color = rgb(255, 240, 200), color2 = rgb(255, 255, 255), size = 1, charge = 0.3, shake = 0.6, flash = 0 },

	-- Boules d'énergie (orb)
	destructo_disc = { name = "Disque Tranchant", family = "orb", variant = "disc", color = rgb(255, 230, 80), color2 = rgb(255, 255, 210), size = 1, charge = 0.45, shake = 0.9, flash = 0.1 },
	destruction_sphere = {
		name = "Sphère de Destruction",
		family = "orb",
		variant = "destruction",
		color = rgb(255, 120, 40),
		color2 = rgb(150, 40, 255),
		size = 1.35,
		charge = 0.7,
		shake = 1.5,
		flash = 0.3,
	},
	fire_star = { name = "Étoile de Feu", family = "orb", variant = "star", color = rgb(255, 80, 60), color2 = rgb(255, 210, 80), size = 0.9, charge = 0.35, shake = 0.8, flash = 0 },
	basic_orb = { name = "Orbe", family = "orb", variant = "orb", color = rgb(110, 200, 255), color2 = rgb(230, 245, 255), size = 1, charge = 0.4, shake = 0.8, flash = 0.1 },

	-- Rayons (beam)
	special_beam = { name = "Rayon Perforant", family = "beam", variant = "drill", color = rgb(255, 230, 90), color2 = rgb(160, 80, 255), size = 1, charge = 0.6, shake = 1, flash = 0.15 },
	energy_blast = { name = "Rafale Énergétique", family = "beam", variant = "thin", color = rgb(120, 200, 255), color2 = rgb(230, 245, 255), size = 0.9, charge = 0.4, shake = 0.9, flash = 0.1 },
	basic_beam = { name = "Rayon", family = "beam", variant = "thin", color = rgb(255, 230, 90), color2 = rgb(255, 255, 220), size = 1, charge = 0.45, shake = 0.9, flash = 0.1 },

	-- Lames (slash)
	cursed_spear = { name = "Lance Maudite", family = "slash", variant = "thrust", color = rgb(110, 220, 120), color2 = rgb(20, 40, 25), size = 1, charge = 0.35, shake = 0.8, flash = 0 },
	chop_chop = { name = "Découpage", family = "slash", variant = "scatter", color = rgb(255, 200, 120), color2 = rgb(255, 245, 220), size = 0.9, charge = 0.3, shake = 0.6, flash = 0 },
	conqueror_haki = {
		name = "Haki du Conquérant",
		family = "slash",
		variant = "haki",
		color = rgb(255, 40, 40),
		color2 = rgb(15, 0, 0),
		size = 1.3,
		charge = 0.6,
		shake = 1.5,
		flash = 0.25,
	},
	flower_breath = { name = "Souffle des Fleurs", family = "slash", variant = "petals", color = rgb(255, 160, 220), color2 = rgb(255, 230, 245), size = 1, charge = 0.35, shake = 0.7, flash = 0 },
	beast_fangs = { name = "Crocs Sauvages", family = "slash", variant = "serrated", color = rgb(200, 200, 210), color2 = rgb(110, 160, 255), size = 1, charge = 0.3, shake = 0.8, flash = 0 },
	wind_blades = { name = "Lames de Vent", family = "slash", variant = "double", color = rgb(190, 255, 230), color2 = rgb(255, 255, 255), size = 1, charge = 0.3, shake = 0.6, flash = 0 },
	basic_slash = { name = "Entaille", family = "slash", variant = "single", color = rgb(255, 255, 255), color2 = rgb(200, 220, 255), size = 1, charge = 0.3, shake = 0.6, flash = 0 },

	-- Foudre (bolt)
	thunder_storm = { name = "Tempête Électrique", family = "bolt", variant = "sky", color = rgb(255, 240, 80), color2 = rgb(255, 255, 220), size = 1.1, charge = 0.5, shake = 1.1, flash = 0.2 },
	thunderclap = { name = "Premier Mouvement : Éclair", family = "bolt", variant = "dash", color = rgb(255, 230, 40), color2 = rgb(255, 255, 220), size = 1.05, charge = 0.5, shake = 1.1, flash = 0.2 },
	thousand_birds = { name = "Mille Oiseaux", family = "bolt", variant = "arc", color = rgb(130, 200, 255), color2 = rgb(240, 250, 255), size = 1, charge = 0.4, shake = 0.9, flash = 0.1 },
	basic_bolt = { name = "Foudre", family = "bolt", variant = "arc", color = rgb(170, 220, 255), color2 = rgb(255, 255, 255), size = 1, charge = 0.4, shake = 0.9, flash = 0.1 },

	-- Flammes (flame)
	amaterasu = { name = "Amaterasu", family = "flame", variant = "black", color = rgb(70, 20, 90), color2 = rgb(10, 5, 15), size = 1.1, charge = 0.5, shake = 1, flash = 0.15 },
	diable_jambe = { name = "Jambe du Diable", family = "flame", variant = "kick", color = rgb(255, 120, 30), color2 = rgb(255, 220, 100), size = 1, charge = 0.4, shake = 1, flash = 0.1 },
	blood_flames = { name = "Sang Explosif", family = "flame", variant = "burst", color = rgb(255, 90, 160), color2 = rgb(255, 200, 230), size = 1.05, charge = 0.45, shake = 1, flash = 0.12 },
	basic_flame = { name = "Flammes", family = "flame", variant = "burst", color = rgb(255, 120, 30), color2 = rgb(255, 230, 120), size = 1, charge = 0.4, shake = 0.9, flash = 0.1 },

	-- Ombres et malédictions (shadow)
	shadow_bind = { name = "Étreinte d'Ombre", family = "shadow", variant = "tendril", color = rgb(25, 20, 35), color2 = rgb(120, 80, 200), size = 1, charge = 0.4, shake = 0.7, flash = 0 },
	cursed_speech = { name = "Parole Maudite : Explose !", family = "shadow", variant = "voice", color = rgb(120, 90, 200), color2 = rgb(230, 210, 255), size = 1, charge = 0.35, shake = 0.9, flash = 0.1 },
	shadow_dogs = { name = "Chiens d'Ombre", family = "shadow", variant = "dogs", color = rgb(20, 30, 70), color2 = rgb(120, 160, 255), size = 1.05, charge = 0.45, shake = 0.9, flash = 0 },
	basic_shadow = { name = "Ombre", family = "shadow", variant = "tendril", color = rgb(25, 20, 35), color2 = rgb(150, 60, 220), size = 1, charge = 0.4, shake = 0.7, flash = 0 },

	-- Divers
	resonance = { name = "Clous Résonnants", family = "nails", color = rgb(255, 170, 60), color2 = rgb(255, 240, 200), size = 1, charge = 0.4, shake = 0.9, flash = 0.1 },
	demon_shot = { name = "Tir Démoniaque", family = "bullets", color = rgb(230, 230, 255), color2 = rgb(255, 200, 120), size = 1, charge = 0.35, shake = 0.8, flash = 0.08 },
	water_surface = { name = "Souffle de l'Eau", family = "slash", variant = "water", color = rgb(70, 170, 255), color2 = rgb(220, 245, 255), size = 1, charge = 0.35, shake = 0.7, flash = 0 },
	stretch_pistol = { name = "Pistolet Élastique", family = "gomu", variant = "pistol", color = rgb(255, 80, 80), color2 = rgb(255, 170, 40), skin = rgb(255, 210, 170), size = 0.9, charge = 0.35, shake = 0.9, flash = 0 },
}

-- Boss : attaques de zone (évènement "Slam") et coups lourds, par ennemi.
AttackFx.Bosses = {
	default = { name = "Onde de Choc", style = "shock", color = rgb(255, 80, 60), color2 = rgb(255, 200, 120) },
	ninja_kourama = { name = "Rugissement du Renard", style = "fire", color = rgb(255, 120, 20), color2 = rgb(255, 230, 120) },
	ninja_zabouza = { name = "Prison de Brume", style = "shock", color = rgb(150, 200, 255), color2 = rgb(235, 245, 255) },
	occ_kenjakou = { name = "Extension du Territoire", style = "curse", color = rgb(150, 60, 255), color2 = rgb(30, 0, 50) },
	occ_jogou = { name = "Météore Volcanique", style = "magma", color = rgb(255, 90, 30), color2 = rgb(60, 20, 10) },
	occ_mahitto = { name = "Transfiguration", style = "curse", color = rgb(110, 200, 220), color2 = rgb(20, 30, 40) },
	sai_freezo = { name = "Rayon de la Mort", style = "beam", color = rgb(255, 80, 200), color2 = rgb(255, 220, 245) },
	sai_celjr = { name = "Ki Explosif", style = "shock", color = rgb(120, 255, 140), color2 = rgb(230, 255, 230) },
	oce_akaino = { name = "Poing de Magma", style = "magma", color = rgb(255, 70, 20), color2 = rgb(60, 15, 10) },
	oce_arlang = { name = "Requin Tranchant", style = "shock", color = rgb(80, 160, 255), color2 = rgb(220, 240, 255) },
	pou_akazo = { name = "Destruction Mortelle : Compas", style = "shock", color = rgb(110, 220, 255), color2 = rgb(255, 120, 200) },
	pou_enmo = { name = "Rêve Éternel", style = "curse", color = rgb(120, 80, 200), color2 = rgb(20, 10, 30) },
	pou_ruy = { name = "Fils Sanglants", style = "curse", color = rgb(220, 30, 60), color2 = rgb(30, 0, 5) },
}

-- Effet signature de chacun des 40 persos jouables.
AttackFx.Characters = {
	-- Village Ninja
	ninja_rokli = "lotus",
	ninja_konohamaro = "rasengan_mini",
	ninja_sakoura = "cherry_fist",
	ninja_shikamaro = "shadow_bind",
	ninja_sasuki = "chidori",
	ninja_kakashu = "raikiri",
	ninja_maruto = "rasengan",
	ninja_itochi = "amaterasu",
	-- Académie Occulte
	occ_toudo = "boogie_clap",
	occ_inumako = "cursed_speech",
	occ_nobora = "resonance",
	occ_megumo = "shadow_dogs",
	occ_yuzi = "divergent_fist",
	occ_mako = "cursed_spear",
	occ_goju = "hollow_purple",
	occ_sukana = "dismantle",
	-- Planète des Guerriers
	sai_yamcho = "wolf_fang",
	sai_krilin = "destructo_disc",
	sai_piccola = "special_beam",
	sai_c81 = "energy_blast",
	sai_vejeta = "galick_gun",
	sai_gohon = "masenko",
	sai_goko = "kamehameha",
	sai_beeros = "destruction_sphere",
	-- Grand Océan
	oce_kobi = "rokushiki",
	oce_buggi = "chop_chop",
	oce_usupp = "fire_star",
	oce_nomi = "thunder_storm",
	oce_zoru = "santoryu",
	oce_sanjo = "diable_jambe",
	oce_loffy = "gomu",
	oce_shonks = "conqueror_haki",
	-- Pourfendeurs
	pou_genyo = "demon_shot",
	pou_kanoa = "flower_breath",
	pou_zenitso = "thunderclap",
	pou_inosoke = "beast_fangs",
	pou_tanjiru = "hinokami",
	pou_nezoko = "blood_flames",
	pou_rengoko = "rengoku",
	pou_yoriichu = "sun_dance",
}

-- Effet par défaut selon le type d'attaque (persos ajoutés plus tard, fusions...).
AttackFx.Kinds = {
	punch = "basic_punch",
	orb = "basic_orb",
	beam = "basic_beam",
	slash = "basic_slash",
	lightning = "basic_bolt",
	flame = "basic_flame",
	shadow = "basic_shadow",
	stretch = "stretch_pistol",
	ice = "water_surface",
	wind = "wind_blades",
	mist = "wind_blades",
}

-- Plafonds de performance (pièces d'effet simultanées, particules, lumières).
-- La qualité « auto » choisit high sur PC, medium sur console et low sur mobile.
AttackFx.Quality = {
	high = { parts = 450, particles = 1.0, lights = 8, highlights = 8, crater = true, debris = 1.0 },
	medium = { parts = 280, particles = 0.65, lights = 5, highlights = 5, crater = true, debris = 0.6 },
	low = { parts = 160, particles = 0.4, lights = 3, highlights = 3, crater = false, debris = 0.35 },
}

function AttackFx.get(id: string?)
	return id and AttackFx.Signatures[id] or nil
end

-- Identifiant de l'effet d'un perso (avec repli sur le type d'attaque).
function AttackFx.forCharacter(characterId: string?, attackKind: string?): string
	local id = characterId and AttackFx.Characters[characterId]
	if id and AttackFx.Signatures[id] then
		return id
	end
	return AttackFx.Kinds[attackKind or "punch"] or "basic_punch"
end

-- Réglages de boss (par identifiant d'ennemi).
function AttackFx.boss(enemyId: string?)
	return enemyId and AttackFx.Bosses[enemyId] or AttackFx.Bosses.default
end

return AttackFx
