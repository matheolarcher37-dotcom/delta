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
Economy.BaseDisplaySlots = 8
Economy.BaseIncubators = 1
Economy.MaxCharacters = 150

-- Entraînement passif (XP/s) des persos exposés sur la base.
Economy.PassiveXP = 2
-- Revenu passif : fraction de la puissance versée chaque seconde.
Economy.IncomeFactor = 0.15

-- Paliers d'ennemis dans la zone d'univers (anneau extérieur -> centre).
Economy.EnemyTiers = {
	[1] = { hp = 60, damage = 4, coins = 15, xp = 12, materialChance = 0.05, level = 3, scale = 0.9, count = 7, ring = { 40, 56 } },
	[2] = { hp = 320, damage = 13, coins = 70, xp = 40, materialChance = 0.15, level = 18, scale = 1.15, count = 5, ring = { 26, 40 } },
	[3] = { hp = 1800, damage = 38, coins = 300, xp = 150, materialChance = 0.4, level = 45, scale = 1.45, count = 3, ring = { 16, 26 } },
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

-- Améliorations de base (boutons "tycoon" à marcher dessus).
-- requires = id de l'amélioration qui doit être achetée avant.
-- slot = position du bouton dans la base (coordonnées locales X, Z).
Economy.Upgrades = {
	{ id = "lanternes", name = "Lanternes de Papier", price = 600, effect = { income = 0.1 }, slot = { -42, -22 } },
	{ id = "autel2", name = "Autel de Relique #2", price = 1500, effect = { incubators = 1 }, slot = { 42, -22 } },
	{ id = "tatami", name = "Tatami d'Entraînement", price = 3000, effect = { xp = 0.5 }, slot = { -42, -13 }, requires = "lanternes" },
	{ id = "aimant", name = "Aimant à Pièces", price = 7500, effect = { combatCoins = 0.25 }, slot = { -33, -22 }, requires = "lanternes" },
	{ id = "arene1", name = "Arène Agrandie", price = 12000, effect = { display = 4 }, slot = { 42, -13 }, requires = "autel2" },
	{ id = "equipe4", name = "Bannière d'Équipe #4", price = 25000, effect = { team = 1 }, slot = { 33, -22 }, requires = "autel2" },
	{ id = "fontaine", name = "Fontaine de Chakra", price = 35000, effect = { income = 0.25 }, slot = { -42, -4 }, requires = "tatami" },
	{ id = "autel3", name = "Autel de Relique #3", price = 50000, effect = { incubators = 1 }, slot = { 42, -4 }, requires = "arene1" },
	{ id = "horloge", name = "Horloge Mystique", price = 80000, effect = { hatchSpeed = 0.25 }, slot = { -33, -13 }, requires = "aimant" },
	{ id = "dojo", name = "Dojo Légendaire", price = 150000, effect = { xp = 1 }, slot = { -42, 5 }, requires = "fontaine" },
	{ id = "arene2", name = "Grande Arène", price = 220000, effect = { display = 6 }, slot = { 42, 5 }, requires = "autel3" },
	{ id = "coffre", name = "Coffre du Shogun", price = 300000, effect = { combatCoins = 0.5 }, slot = { -33, -4 }, requires = "horloge" },
	{ id = "autel4", name = "Autel de Relique #4", price = 450000, effect = { incubators = 1 }, slot = { 33, -13 }, requires = "autel3" },
	{ id = "equipe5", name = "Bannière d'Équipe #5", price = 600000, effect = { team = 1 }, slot = { 33, -4 }, requires = "equipe4" },
	{ id = "statue", name = "Statue Dorée", price = 900000, effect = { income = 0.5 }, slot = { -33, 5 }, requires = "dojo" },
	{ id = "sablier", name = "Sablier Divin", price = 1500000, effect = { hatchSpeed = 0.25 }, slot = { 33, 5 }, requires = "autel4" },
}

Economy.UpgradesById = {}
for _, upgrade in Economy.Upgrades do
	Economy.UpgradesById[upgrade.id] = upgrade
end

return Economy
