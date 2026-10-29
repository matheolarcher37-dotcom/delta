-- Équilibrage : prix, durées, récompenses, améliorations de base.

local Economy = {}

local Rarities = require(script.Parent.Rarities)

-- Durée d'un univers (en secondes). 30 minutes comme dans le doc de conception.
Economy.UniverseDuration = 30 * 60
-- Intervalle de réapprovisionnement du marchand ambulant.
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
	secret = 16,
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
Economy.MaxDisplaySlots = 24 -- cases du jeu gratuit (améliorations + arbre) ; le passe « +2 Cases » en ajoute 2 (26 construites)
Economy.MaxCharacters = 150

-- Entraînement passif (XP/s) des persos exposés sur la base.
Economy.PassiveXP = 2
-- Revenu passif : fraction de la puissance versée chaque seconde.
Economy.IncomeFactor = 0.15

------------------------------------------------------------------------
-- MACHINE DE ROULAGE (« ROULER ») : la source principale de persos.
--
-- Chaque roulage tire UN perso (deux ou trois avec les passes Robux « Roulage x2 / x3 ») :
--   1) la machine tire une RARETÉ selon les chances ci-dessous (chance de l'arbre, potions...) ;
--   2) puis un perso de CETTE rareté dans le pool de l'univers actuel : chaque perso garde sa
--      rareté de base (Config/Characters : Maruto est Épique, il reste Épique) ;
--   3) une MUTATION peut s'ajouter par-dessus (Config/Mutations : Or, Diamant, Sakura...).
-- Le perso tiré s'affiche sur l'estrade : on le « Collecte » en payant son prix (¥ = pièces),
-- ou on le laisse passer en roulant de nouveau. Pas de garantie, sauf la pitié du MYTHIQUE.
------------------------------------------------------------------------

-- Raretés de la machine (de la plus commune à la plus rare) = raretés des persos.
--   odds     = chance en % (avant la chance du joueur) ; price = prix de base en ¥ (pièces)
--   optional = rareté qui ne compte que si l'univers a des persos de cette rareté
--              (Peu commun : aucun perso du jeu ne l'a pour l'instant ; Secret : 1 perso par univers)
Economy.RollOrder = { "common", "uncommon", "rare", "epic", "legendary", "mythic", "secret" }

local function rarityInfo(id: string, order: number, odds: number, price: number, extra: { [string]: any }?)
	local base = Rarities.List[id]
	local info: { [string]: any } = {
		id = id,
		name = base and base.name or id,
		order = order,
		color = base and base.color or Color3.new(1, 1, 1),
		gradient = base and base.gradient or { Color3.new(1, 1, 1), Color3.new(0.6, 0.6, 0.6) },
		charRarity = id,
		odds = odds,
		price = price,
	}
	for key, value in extra or {} do
		info[key] = value
	end
	return info
end

Economy.RollRarities = {
	common = rarityInfo("common", 1, 70, 90),
	uncommon = rarityInfo("uncommon", 2, 15, 260, {
		name = "Peu commun",
		color = Color3.fromRGB(90, 220, 100),
		gradient = { Color3.fromRGB(160, 255, 150), Color3.fromRGB(40, 170, 70) },
		optional = true,
	}),
	rare = rarityInfo("rare", 3, 22, 900),
	epic = rarityInfo("epic", 4, 6.5, 6000),
	legendary = rarityInfo("legendary", 5, 1.3, 45000),
	mythic = rarityInfo("mythic", 6, 0.2, 350000),
	secret = rarityInfo("secret", 7, 0.02, 2000000, {
		name = "Secret",
		color = Color3.fromRGB(246, 240, 255), -- blanc nacré (même couleur unie que Rarities.secret)
		gradient = {
			Color3.fromRGB(255, 80, 80),
			Color3.fromRGB(255, 220, 60),
			Color3.fromRGB(80, 255, 120),
			Color3.fromRGB(80, 160, 255),
			Color3.fromRGB(220, 90, 255),
		},
		rainbow = true,
		optional = true,
	}),
}

Economy.Roll = {
	QueueMax = 3, -- l'estrade montre les persos du DERNIER roulage (1, 2 ou 3)
	MaxPerRoll = 3, -- 1 par défaut, 2 avec le passe « Roulage x2 », 3 avec « Roulage x3 »
	-- Pitié : UNIQUEMENT pour le Mythique (tout le reste est du pur hasard).
	PityRarity = "mythic",
	Pity = { mythic = 1000 }, -- Mythique garanti au bout de 1000 persos tirés sans Mythique
	PityOrder = { "mythic" },
	-- Légendaire et plus : le premier appui sur ROULER demande confirmation avant de le laisser passer.
	ProtectOrder = 5,
	ConfirmWindow = 6, -- secondes pour confirmer
	-- Bonus de chance (posés par le domaine Robux sur le joueur) : passe « x2 Chance »
	-- (attribut Pass_Luck2) et potion de chance (attribut Boost_Luck = fin, os.time()).
	PassLuck = 2,
	BoostLuck = 2,
	FirstCollectFree = true, -- le tout premier perso collecté est offert (pour bien démarrer)...
	FreeCollectMaxOrder = 3, -- ... s'il est Rare ou moins (pas de Légendaire/Mythique gratuit)
	AutoStep = 0.25, -- l'auto-roulage vérifie toutes les X secondes s'il peut rouler
	-- Zone « à la machine » (repère local de la machine : estrade, bouton, panneau, tapis rouge).
	-- Le client n'affiche la barre ROULER que dedans ; le serveur refuse le remote Roll hors de
	-- cette zone (+ MachineMargin), sauf pour l'auto-roulage des passes Robux.
	MachineZone = { halfX = 34, zMin = -32, zMax = 10, maxY = 24 },
	MachineMargin = 6,
}

-- Passes Robux de la machine : seulement les descriptions longues. Le NOM et le PRIX viennent
-- d'une seule source, Config/Robux.luau (Robux.Passes), pour ne jamais afficher deux prix.
Economy.RollPasses = {
	Roll2 = { desc = "Tire 2 persos à chaque roulage." },
	Roll3 = { desc = "Tire 3 persos à chaque roulage." },
	AutoRoll = { desc = "Lancer AFK : la machine roule toute seule et s'arrête sur les raretés et mutations choisies." },
	AutoRollPlus = {
		desc = "Achat automatique : choisis les persos, raretés et mutations voulus, la machine roule et les ACHÈTE pour toi.",
	},
}
-- Paliers d'ennemis dans la zone d'univers (anneau extérieur -> centre).
Economy.EnemyTiers = {
	[1] = { hp = 60, damage = 4, coins = 15, xp = 12, materialChance = 0.05, level = 3, scale = 0.9, count = 14 },
	[2] = { hp = 320, damage = 13, coins = 70, xp = 40, materialChance = 0.15, level = 18, scale = 1.15, count = 10 },
	[3] = { hp = 1800, damage = 38, coins = 300, xp = 150, materialChance = 0.4, level = 45, scale = 1.45, count = 6 },
}
Economy.Boss = { hp = 80000, damage = 140, coins = 6000, xp = 2500, materials = { 4, 9 }, level = 99, scale = 4.2 }
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
-- Les ids des anciennes versions sont gardés (les sauvegardes restent valables) ; les autels de
-- reliques (autel2 à autel4), retirés en v3.3, sont remboursés au chargement (DataService).
Economy.Upgrades = {
	-- Palier 1 : premiers boutons
	{ id = "distributeur", tier = 1, icon = "🪙", name = "Distributeur de Pièces", price = 400, effect = { income = 0.1 } },
	{ id = "lanternes", tier = 1, icon = "🏮", name = "Lanternes de Pierre", price = 600, effect = { income = 0.1 } },
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
	{ id = "torii", tier = 2, icon = "🏯", name = "Pagode à Trois Toits", price = 60000, effect = { xp = 0.5 }, requires = "fontaine" },
	{ id = "horloge", tier = 2, icon = "🕰️", name = "Horloge Mystique", price = 80000, effect = { income = 0.25 }, requires = "ramen" },
	{ id = "jardin", tier = 2, icon = "🌸", name = "Jardin des Cerisiers", price = 100000, effect = { income = 0.3 }, requires = "fontaine" },
	{ id = "dojo", tier = 2, icon = "🥋", name = "Dojo Légendaire", price = 150000, effect = { xp = 1 }, requires = "mannequins" },
	{ id = "arene2", tier = 2, icon = "🏟️", name = "Gradins de la Cour", price = 220000, effect = { display = 6 }, requires = "arene1" },
	{ id = "coffre", tier = 2, icon = "🎁", name = "Coffre du Shogun", price = 300000, effect = { combatCoins = 0.5 }, requires = "aimant" },
	{ id = "tour", tier = 2, icon = "🗼", name = "Tours de Guet", price = 350000, effect = { combatCoins = 0.25 }, requires = "portail" },
	-- Palier 3 : fin de partie
	{ id = "equipe5", tier = 3, icon = "🚩", name = "Bannière d'Équipe #5", price = 600000, effect = { team = 1 }, requires = "equipe4" },
	{ id = "distributeur3", tier = 3, icon = "💎", name = "Distributeur de Cristal", price = 800000, effect = { income = 0.6 }, requires = "distributeur2" },
	{ id = "statue", tier = 3, icon = "🗿", name = "Statue Dorée", price = 900000, effect = { income = 0.5 }, requires = "dojo" },
	{ id = "sablier", tier = 3, icon = "⏳", name = "Sablier Divin", price = 1500000, effect = { income = 0.5 }, requires = "horloge" },
	{ id = "sanctuaire", tier = 3, icon = "⛩️", name = "Sanctuaire Céleste", price = 3000000, effect = { income = 1, xp = 1 }, requires = "jardin" },
}

Economy.UpgradesById = {}
for _, upgrade in Economy.Upgrades do
	Economy.UpgradesById[upgrade.id] = upgrade
end

return Economy
