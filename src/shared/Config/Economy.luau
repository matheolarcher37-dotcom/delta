-- Équilibrage : prix, durées, récompenses, améliorations de base.

local Economy = {}

-- Durée d'un univers (en secondes). 30 minutes comme dans le doc de conception.
Economy.UniverseDuration = 30 * 60
-- Intervalle de réapprovisionnement de la Machine à Reliques.
Economy.ShopRestock = 5 * 60
-- Un boss apparaît toutes les X secondes dans la zone d'univers.
Economy.BossInterval = 8 * 60
-- Un événement céleste (météo) se déclenche toutes les X secondes.
Economy.EventInterval = 11 * 60
Economy.EventDuration = 150

Economy.StartingCoins = 250
Economy.StartingTraitCrystals = 2

-- Traits : Cristaux de Trait (relance à l'Autel des Traits, au centre).
Economy.TraitCrystalPrice = 25000
Economy.TraitCrystalBossDrop = { 1, 2 }
Economy.TraitCrystalTier3Chance = 0.04
Economy.StartingRelics = { ninja_r1 = 1 } -- relique offerte au premier lancement

-- Reliques par palier : prix, stock par réapprovisionnement, temps d'ouverture.
Economy.RelicTiers = {
	[1] = { price = 150, stock = 8, hatchTime = 12 },
	[2] = { price = 2500, stock = 3, hatchTime = 60 },
	[3] = { price = 40000, stock = 1, hatchTime = 180, appearChance = 0.6 },
}

-- Niveaux : plafond par nombre d'étoiles (évolutions).
Economy.MaxStars = 3
Economy.LevelCap = { [1] = 30, [2] = 60, [3] = 100 }
Economy.StarMultiplier = { [1] = 1, [2] = 3, [3] = 8 }

-- Coût des évolutions (étoile cible) : matériaux de l'univers du perso + pièces.
Economy.Evolution = {
	[2] = { materials = 8, coins = 4000 },
	[3] = { materials = 30, coins = 60000 },
}
-- Multiplicateur de coût d'évolution selon la rareté.
Economy.EvolutionRarityMult = {
	common = 0.5,
	rare = 1,
	epic = 2,
	legendary = 4,
	mythic = 8,
	crossover = 12,
}

-- Fusion crossover (la "pépite").
Economy.Fusion = {
	minStars = 2,
	minRarityOrder = 3, -- Épique minimum
	coins = 100000,
	materials = 15, -- de CHACUN des deux univers
}

-- Équipe & stockage
Economy.BaseTeamSlots = 3
Economy.BaseDisplaySlots = 6 -- emplacements d'unités au départ (cases hexagonales de la base)
Economy.MaxDisplaySlots = 24 -- cases construites dans la base (les autres sont « ??? » verrouillées)
Economy.BaseIncubators = 1
Economy.MaxCharacters = 150

-- Entraînement passif (XP/s) des persos exposés sur la base.
Economy.PassiveXP = 2
-- Revenu passif : fraction de la puissance versée chaque seconde.
Economy.IncomeFactor = 0.15

------------------------------------------------------------------------
-- MACHINE DE ROULAGE (« ROULER ») : la source principale de persos.
-- Le roulage est gratuit ; les persos tirés attendent sur l'estrade et on les « Collecte »
-- en payant leur prix (¥ = pièces). Chance, multi-tirage, vitesse, x10 et pitié
-- s'améliorent dans l'arbre de compétences (Config/SkillTree.luau).
------------------------------------------------------------------------

-- Raretés de la machine (de la plus commune à la plus rare).
--   charRarity   = rareté des persos tirés (Config/Rarities : common, rare, epic, legendary, mythic)
--   traitMinTier = trait garanti (palier minimum) ; aura = aura garantie
--   odds         = chance en % (avant la chance de l'arbre) ; price = prix de base en ¥ (pièces)
Economy.RollOrder = { "common", "uncommon", "rare", "epic", "legendary", "mythic", "secret" }
Economy.RollRarities = {
	common = {
		id = "common",
		name = "Commun",
		order = 1,
		color = Color3.fromRGB(176, 186, 197),
		gradient = { Color3.fromRGB(225, 230, 236), Color3.fromRGB(140, 152, 166) },
		charRarity = "common",
		odds = 60,
		price = 90,
	},
	uncommon = {
		id = "uncommon",
		name = "Peu commun",
		order = 2,
		color = Color3.fromRGB(90, 220, 100),
		gradient = { Color3.fromRGB(160, 255, 150), Color3.fromRGB(40, 170, 70) },
		charRarity = "common",
		traitMinTier = 1, -- un perso commun, mais avec un trait garanti
		odds = 24,
		price = 260,
	},
	rare = {
		id = "rare",
		name = "Rare",
		order = 3,
		color = Color3.fromRGB(64, 160, 255),
		gradient = { Color3.fromRGB(120, 210, 255), Color3.fromRGB(40, 100, 230) },
		charRarity = "rare",
		odds = 11.5,
		price = 900,
	},
	epic = {
		id = "epic",
		name = "Épique",
		order = 4,
		color = Color3.fromRGB(176, 92, 255),
		gradient = { Color3.fromRGB(220, 150, 255), Color3.fromRGB(120, 50, 220) },
		charRarity = "epic",
		odds = 3.8,
		price = 6000,
	},
	legendary = {
		id = "legendary",
		name = "Légendaire",
		order = 5,
		color = Color3.fromRGB(255, 190, 40),
		gradient = { Color3.fromRGB(255, 236, 110), Color3.fromRGB(255, 140, 20) },
		charRarity = "legendary",
		odds = 0.6,
		price = 45000,
	},
	mythic = {
		id = "mythic",
		name = "Mythique",
		order = 6,
		color = Color3.fromRGB(255, 50, 60),
		gradient = { Color3.fromRGB(255, 120, 110), Color3.fromRGB(200, 10, 40) },
		charRarity = "mythic",
		odds = 0.09,
		price = 350000,
	},
	secret = {
		id = "secret",
		name = "Secret",
		order = 7,
		color = Color3.fromRGB(20, 18, 26),
		gradient = {
			Color3.fromRGB(255, 80, 80),
			Color3.fromRGB(255, 220, 60),
			Color3.fromRGB(80, 255, 120),
			Color3.fromRGB(80, 160, 255),
			Color3.fromRGB(220, 90, 255),
		},
		rainbow = true,
		charRarity = "mythic", -- le Mythique de l'univers, en version Secrète :
		aura = "arcenciel", -- aura Arc-en-ciel garantie
		traitMinTier = 3, -- et un trait rare garanti
		odds = 0.01,
		price = 2000000,
	},
}

Economy.Roll = {
	X10Luck = 10, -- chance multipliée par 10 pendant le roulage « Chance x10 »
	QueueMax = 6, -- persos tirés en attente sur l'estrade (les plus anciens partent)
	-- Pitié : nombre de persos tirés (« rouleaux ») avant une rareté garantie (avant l'arbre).
	Pity = { legendary = 150, mythic = 1200, secret = 8000 },
	PityOrder = { "legendary", "mythic", "secret" },
	FirstCollectFree = true, -- le tout premier perso collecté est offert (pour bien démarrer)...
	FreeCollectMaxOrder = 3, -- ... s'il est Rare ou moins (pas de Légendaire/Mythique gratuit)
}

-- Paliers d'ennemis dans la zone d'univers (anneau extérieur -> centre).
Economy.EnemyTiers = {
	[1] = { hp = 60, damage = 4, coins = 15, xp = 12, materialChance = 0.05, level = 3, scale = 0.9, count = 14 },
	[2] = { hp = 320, damage = 13, coins = 70, xp = 40, materialChance = 0.15, level = 18, scale = 1.15, count = 10 },
	[3] = { hp = 1800, damage = 38, coins = 300, xp = 150, materialChance = 0.4, level = 45, scale = 1.45, count = 6 },
}
Economy.Boss = { hp = 80000, damage = 140, coins = 6000, xp = 2500, materials = { 4, 9 }, relicChance = 0.12, level = 99, scale = 4.2 }
Economy.EnemyRespawn = 6

-- Combat
Economy.FollowerAttackCooldown = 1.1
Economy.FollowerRange = 5.5
Economy.FollowerAggroRange = 45
Economy.FollowerKOTime = 8
Economy.CritChance = 0.12
Economy.SpecialEvery = 6 -- une attaque spéciale toutes les X attaques

-- Événements célestes
Economy.Events = {
	orage = {
		id = "orage",
		name = "Orage Électrique",
		description = "La foudre frappe les bases : certains persos obtiennent l'aura Foudre !",
		aura = "foudre",
		strikeChance = 0.08,
		color = Color3.fromRGB(255, 230, 60),
	},
	eclipse = {
		id = "eclipse",
		name = "Éclipse du Néant",
		description = "Des cubes du Néant tombent du ciel : aura Néant possible !",
		aura = "neant",
		strikeChance = 0.04,
		color = Color3.fromRGB(170, 60, 255),
	},
	pluie_or = {
		id = "pluie_or",
		name = "Pluie d'Or",
		description = "Toutes les pièces gagnées sont doublées !",
		coinMultiplier = 2,
		color = Color3.fromRGB(255, 200, 40),
	},
	lune_sang = {
		id = "lune_sang",
		name = "Lune de Sang",
		description = "Les ennemis lâchent deux fois plus de matériaux !",
		materialMultiplier = 2,
		color = Color3.fromRGB(230, 30, 50),
	},
}
Economy.EventOrder = { "orage", "pluie_or", "eclipse", "lune_sang" }

-- Améliorations de base (boutons « tycoon » à marcher dessus). Chacune construit quelque chose
-- de visible dans la base ; l'emplacement du bouton et de la construction est dans
-- src/server/Modules/TycoonStructures.luau (SITES).
--   requires = id de l'amélioration qui doit être achetée avant (le bouton apparaît alors)
--   tier     = palier (1 = débuts, 2 = milieu de partie, 3 = fin de partie)
--   icon     = emoji affiché sur le panneau du bouton
-- Les ids des anciennes versions sont gardés (les sauvegardes restent valables).
Economy.Upgrades = {
	-- Palier 1 : premiers boutons
	{ id = "distributeur", tier = 1, icon = "🪙", name = "Distributeur de Pièces", price = 400, effect = { income = 0.1 } },
	{ id = "lanternes", tier = 1, icon = "🏮", name = "Lanternes de Pierre", price = 600, effect = { income = 0.1 } },
	{ id = "autel2", tier = 1, icon = "🔮", name = "Autel de Relique #2", price = 1500, effect = { incubators = 1 } },
	{ id = "dallage", tier = 1, icon = "🧱", name = "Cour des Unités", price = 2000, effect = { display = 2 } },
	{ id = "tatami", tier = 1, icon = "🥋", name = "Tatami d'Entraînement", price = 3000, effect = { xp = 0.5 }, requires = "lanternes" },
	{ id = "mannequins", tier = 1, icon = "🎯", name = "Mannequins de Paille", price = 5000, effect = { xp = 0.25 }, requires = "tatami" },
	{ id = "aimant", tier = 1, icon = "🧲", name = "Aimant à Pièces", price = 7500, effect = { combatCoins = 0.25 }, requires = "distributeur" },
	{ id = "remparts", tier = 1, icon = "⛩️", name = "Allée des Torii", price = 9000, effect = { income = 0.1 }, requires = "lanternes" },
	{ id = "arene1", tier = 1, icon = "🔥", name = "Braseros de la Cour", price = 12000, effect = { display = 4 }, requires = "dallage" },
	{ id = "ramen", tier = 1, icon = "🍜", name = "Stand de Ramen", price = 15000, effect = { income = 0.2 }, requires = "lanternes" },
	{ id = "distributeur2", tier = 1, icon = "💰", name = "Distributeur Doré", price = 20000, effect = { income = 0.25 }, requires = "distributeur" },
	{ id = "equipe4", tier = 1, icon = "🚩", name = "Bannière d'Équipe #4", price = 25000, effect = { team = 1 }, requires = "arene1" },
	-- Palier 2 : milieu de partie
	{ id = "fontaine", tier = 2, icon = "⛲", name = "Fontaine de Chakra", price = 35000, effect = { income = 0.25 }, requires = "ramen" },
	{ id = "portail", tier = 2, icon = "🥁", name = "Gong de Guerre", price = 40000, effect = { combatCoins = 0.15 }, requires = "aimant" },
	{ id = "autel3", tier = 2, icon = "🔮", name = "Autel de Relique #3", price = 50000, effect = { incubators = 1 }, requires = "autel2" },
	{ id = "torii", tier = 2, icon = "🏯", name = "Pagode à Trois Toits", price = 60000, effect = { xp = 0.5 }, requires = "fontaine" },
	{ id = "horloge", tier = 2, icon = "🕰️", name = "Horloge Mystique", price = 80000, effect = { hatchSpeed = 0.25 }, requires = "autel2" },
	{ id = "jardin", tier = 2, icon = "🌸", name = "Jardin des Cerisiers", price = 100000, effect = { income = 0.3 }, requires = "fontaine" },
	{ id = "dojo", tier = 2, icon = "🥋", name = "Dojo Légendaire", price = 150000, effect = { xp = 1 }, requires = "mannequins" },
	{ id = "arene2", tier = 2, icon = "🏟️", name = "Gradins de la Cour", price = 220000, effect = { display = 6 }, requires = "arene1" },
	{ id = "coffre", tier = 2, icon = "🎁", name = "Coffre du Shogun", price = 300000, effect = { combatCoins = 0.5 }, requires = "aimant" },
	{ id = "tour", tier = 2, icon = "🗼", name = "Tours de Guet", price = 350000, effect = { combatCoins = 0.25 }, requires = "portail" },
	-- Palier 3 : fin de partie
	{ id = "autel4", tier = 3, icon = "🔮", name = "Autel de Relique #4", price = 450000, effect = { incubators = 1 }, requires = "autel3" },
	{ id = "equipe5", tier = 3, icon = "🚩", name = "Bannière d'Équipe #5", price = 600000, effect = { team = 1 }, requires = "equipe4" },
	{ id = "distributeur3", tier = 3, icon = "💎", name = "Distributeur de Cristal", price = 800000, effect = { income = 0.6 }, requires = "distributeur2" },
	{ id = "statue", tier = 3, icon = "🗿", name = "Statue Dorée", price = 900000, effect = { income = 0.5 }, requires = "dojo" },
	{ id = "sablier", tier = 3, icon = "⏳", name = "Sablier Divin", price = 1500000, effect = { hatchSpeed = 0.25 }, requires = "horloge" },
	{ id = "sanctuaire", tier = 3, icon = "⛩️", name = "Sanctuaire Céleste", price = 3000000, effect = { income = 1, xp = 1 }, requires = "jardin" },
}

Economy.UpgradesById = {}
for _, upgrade in Economy.Upgrades do
	Economy.UpgradesById[upgrade.id] = upgrade
end

return Economy
