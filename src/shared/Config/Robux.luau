-- BOUTIQUE ROBUX : passes (achat définitif), produits (packs à racheter) et boosts temporaires.
--
-- ▶ COMMENT BRANCHER LES VRAIS ACHATS (une seule fois, sur le Creator Hub) :
--   1. Publie le jeu (Fichier → Publier sur Roblox).
--   2. Va sur https://create.roblox.com → Créations → ton jeu → Monétisation :
--        • « Passes »            : crée un passe pour chaque ligne de `Robux.Passes` (nom, image, prix) ;
--        • « Produits pour développeurs » : crée un produit pour chaque ligne de `Robux.Products`.
--   3. Copie le NUMÉRO (ID) de chaque passe / produit et colle-le à la place du 0 dans `id = 0`.
--   4. Mets le même prix que `price` (c'est le prix affiché dans la boutique du jeu).
--   Tant qu'un id vaut 0, le bouton affiche « pas encore configuré ». Dans Studio, l'achat est
--   alors SIMULÉ (gratuit) pour que tu puisses tout essayer : voir `Robux.StudioSimulate`.
--
-- Effets (posés sur le joueur par MonetizationService, lus par les autres services) :
--   • attribut "Pass_<Clé>" = true  quand le joueur possède le passe ;
--   • attribut "Boost_<Clé>" = heure de fin (os.time()) pour un boost temporaire (Luck, Coins).

local Robux = {}

-- Studio : un achat dont l'id vaut 0 est simulé (gratuit, uniquement dans Studio) pour essayer.
-- Les passes simulés ne sont JAMAIS appliqués dans le vrai jeu en ligne.
Robux.StudioSimulate = true

-- Bonus du passe VIP.
Robux.VIP = { coins = 1.25, luck = 1.1 }

-- Cases d'unités en plus dans la base avec le passe « Emplacements + » (data.RobuxSlots,
-- ajouté aux cases de la cour et de l'arbre par Formulas.playerStats).
Robux.SlotsBonus = 2

------------------------------------------------------------------------
-- Passes (achat définitif)
------------------------------------------------------------------------

export type Pass = {
	id: number,
	name: string,
	short: string,
	price: number,
	desc: string,
	icon: string,
	badge: string?,
	color: Color3,
	order: number,
	perks: { string }?,
}

Robux.Passes = {
	Roll2 = {
		id = 0,
		name = "Roulage x2",
		short = "Roulage x2",
		price = 149,
		desc = "2 persos tirés à chaque roulage",
		icon = "dice",
		badge = "x2",
		color = Color3.fromRGB(60, 150, 255),
		order = 1,
	},
	Roll3 = {
		id = 0,
		name = "Roulage x3",
		short = "Roulage x3",
		price = 399,
		desc = "3 persos tirés à chaque roulage !",
		icon = "dice",
		badge = "x3",
		color = Color3.fromRGB(255, 100, 50),
		order = 2,
	},
	Coins2 = {
		id = 0,
		name = "x2 Argent",
		short = "x2 Argent",
		price = 199,
		desc = "Toutes tes pièces doublées, à vie",
		icon = "coin",
		badge = "x2",
		color = Color3.fromRGB(255, 195, 40),
		order = 3,
	},
	Luck2 = {
		id = 0,
		name = "x2 Chance",
		short = "x2 Chance",
		price = 249,
		desc = "Chance doublée à chaque roulage",
		icon = "clover",
		badge = "x2",
		color = Color3.fromRGB(70, 210, 90),
		order = 4,
	},
	AutoRoll = {
		id = 0,
		name = "Lancer AFK",
		short = "Lancer AFK",
		price = 29,
		desc = "Roule seul, pause sur tes raretés",
		icon = "robot",
		color = Color3.fromRGB(40, 200, 230),
		order = 5,
	},
	AutoRollPlus = {
		id = 0,
		name = "Roulement automatique +",
		short = "Auto +",
		price = 500,
		desc = "Choisis le perso, la rareté et la variété que tu veux : la machine tourne en AFK et ACHÈTE le perso pour toi.",
		icon = "robot",
		badge = "+",
		color = Color3.fromRGB(255, 70, 160),
		order = 6,
		perks = {
			"Choisis le perso que tu veux",
			"Choisis sa rareté et sa variété",
			"Tourne tout le temps en AFK",
			"ACHÈTE le perso pour toi",
		},
	},
	Slots = {
		id = 0,
		name = "+2 Cases",
		short = "+2 Cases",
		price = 199,
		desc = "2 persos de plus dans ta base",
		icon = "grid",
		badge = "+2",
		color = Color3.fromRGB(60, 200, 170),
		order = 8,
	},
	VIP = {
		id = 0,
		name = "VIP",
		short = "VIP",
		price = 299,
		desc = "+25 % argent, +10 % chance",
		icon = "crown",
		color = Color3.fromRGB(175, 70, 255),
		order = 7,
	},
}

-- Ordre d'affichage dans la boutique.
Robux.PassOrder = { "AutoRollPlus", "Roll2", "Roll3", "Coins2", "Luck2", "AutoRoll", "Slots", "VIP" }

------------------------------------------------------------------------
-- Produits (achats répétables)
------------------------------------------------------------------------

-- kind = "coins"    : base = minimum de pièces, minutes = minutes de revenus (le plus grand des deux)
-- kind = "crystals" : amount = Cristaux de Trait (les gemmes qui servent à relancer les traits)
-- kind = "boost"    : boosts = { "Luck" | "Coins" }, duration = secondes (les boosts s'additionnent)
-- kind = "bundle"   : un peu de tout (pièces comme "coins", `crystals` gemmes, boosts) ; once = un seul achat
Robux.Products = {
	CoinsS = { id = 0, name = "Bourse", price = 19, kind = "coins", base = 5000, minutes = 5, tier = 1, order = 1 },
	CoinsM = { id = 0, name = "Sac de pièces", price = 79, kind = "coins", base = 30000, minutes = 30, tier = 2, order = 2, ribbon = "POPULAIRE" },
	CoinsL = { id = 0, name = "Coffre de pièces", price = 249, kind = "coins", base = 150000, minutes = 120, tier = 3, order = 3 },
	CoinsXL = { id = 0, name = "Trésor du Hokage", price = 699, kind = "coins", base = 600000, minutes = 480, tier = 4, order = 4, ribbon = "MEILLEUR PRIX" },

	GemsS = { id = 0, name = "Poignée de gemmes", price = 25, kind = "crystals", amount = 10, tier = 1, order = 5 },
	GemsM = { id = 0, name = "Bourse de gemmes", price = 99, kind = "crystals", amount = 50, tier = 2, order = 6, ribbon = "+25 %" },
	GemsL = { id = 0, name = "Coffre de gemmes", price = 249, kind = "crystals", amount = 150, tier = 3, order = 7, ribbon = "+50 %" },

	-- Offre unique (un seul achat par joueur, voir data.RobuxOnce) : un peu de tout pour bien démarrer.
	Starter = {
		id = 0,
		name = "Pack de départ",
		price = 99,
		kind = "bundle",
		once = true,
		base = 25000,
		minutes = 20,
		crystals = 20,
		boosts = { "Luck" },
		duration = 900,
		order = 0,
		ribbon = "1 SEUL ACHAT",
	},

	BoostLuck = { id = 0, name = "Chance x2", price = 49, kind = "boost", boosts = { "Luck" }, duration = 900, order = 8 },
	BoostCoins = { id = 0, name = "Argent x2", price = 49, kind = "boost", boosts = { "Coins" }, duration = 900, order = 9 },
	BoostCombo = { id = 0, name = "Combo x2", price = 129, kind = "boost", boosts = { "Luck", "Coins" }, duration = 1800, order = 10, ribbon = "LES DEUX" },
}

Robux.CoinPacks = { "CoinsS", "CoinsM", "CoinsL", "CoinsXL" }
Robux.GemPacks = { "GemsS", "GemsM", "GemsL" }
Robux.BoostPacks = { "BoostLuck", "BoostCoins", "BoostCombo" }

-- Boosts temporaires (attribut "Boost_<Clé>").
Robux.Boosts = {
	Luck = { name = "Chance x2", mult = 2, icon = "clover", color = Color3.fromRGB(70, 210, 90) },
	Coins = { name = "Argent x2", mult = 2, icon = "coin", color = Color3.fromRGB(255, 195, 40) },
}
Robux.BoostOrder = { "Luck", "Coins" }

------------------------------------------------------------------------
-- Aides (serveur ET client : `who` est un Player, ou tout objet avec GetAttribute)
------------------------------------------------------------------------

function Robux.isConfigured(entry): boolean
	return type(entry) == "table" and type(entry.id) == "number" and entry.id > 0
end

function Robux.hasPass(who, key: string): boolean
	local ok, value = pcall(function()
		return who:GetAttribute("Pass_" .. key)
	end)
	return ok and value == true
end

-- Secondes restantes du boost `key` (0 s'il n'est pas actif). `now` : os.time() côté serveur,
-- Workspace:GetServerTimeNow() côté client.
function Robux.boostLeft(who, key: string, now: number?): number
	local ok, value = pcall(function()
		return who:GetAttribute("Boost_" .. key)
	end)
	if not ok or type(value) ~= "number" then
		return 0
	end
	return math.max(0, value - (now or os.time()))
end

-- Multiplicateur de pièces (x2 Argent, boost Argent x2, VIP). Appliqué là où les gains sont calculés.
function Robux.coinMultiplier(who, now: number?): number
	local mult = 1
	if Robux.hasPass(who, "Coins2") then
		mult *= 2
	end
	if Robux.boostLeft(who, "Coins", now) > 0 then
		mult *= Robux.Boosts.Coins.mult
	end
	if Robux.hasPass(who, "VIP") then
		mult *= Robux.VIP.coins
	end
	return mult
end

-- Multiplicateur de chance (x2 Chance, boost Chance x2, VIP).
function Robux.luckMultiplier(who, now: number?): number
	local mult = 1
	if Robux.hasPass(who, "Luck2") then
		mult *= 2
	end
	if Robux.boostLeft(who, "Luck", now) > 0 then
		mult *= Robux.Boosts.Luck.mult
	end
	if Robux.hasPass(who, "VIP") then
		mult *= Robux.VIP.luck
	end
	return mult
end

-- Peut-on lancer l'auto-roulage (« Lancer AFK » ou « Roulement automatique + ») ?
function Robux.canAutoRoll(who): boolean
	return Robux.hasPass(who, "AutoRoll") or Robux.hasPass(who, "AutoRollPlus")
end

-- Nombre de persos par roulage donné par les passes : Roll3 → 3, sinon Roll2 → 2, sinon 1.
function Robux.rollsPerPull(who): number
	if Robux.hasPass(who, "Roll3") then
		return 3
	elseif Robux.hasPass(who, "Roll2") then
		return 2
	end
	return 1
end

-- Pièces d'un pack (le plus grand entre le minimum et N minutes de revenus), arrondi joliment.
function Robux.coinPackAmount(product, incomePerSec: number?): number
	local income = math.max(0, tonumber(incomePerSec) or 0)
	local amount = math.max(product.base or 0, income * (product.minutes or 0) * 60)
	if amount >= 1000 then
		local magnitude = 10 ^ (math.floor(math.log10(amount)) - 1)
		amount = math.floor(amount / magnitude) * magnitude
	end
	return math.floor(amount)
end

local function findById(list, id: number): string?
	if type(id) ~= "number" or id <= 0 then
		return nil
	end
	for key, entry in list do
		if entry.id == id then
			return key
		end
	end
	return nil
end

function Robux.passKeyById(id: number): string?
	return findById(Robux.Passes, id)
end

function Robux.productKeyById(id: number): string?
	return findById(Robux.Products, id)
end

-- Offre à achat unique déjà prise ? (`data` = données du joueur, serveur ou client)
function Robux.onceTaken(data, key: string): boolean
	return type(data) == "table" and type(data.RobuxOnce) == "table" and data.RobuxOnce[key] ~= nil
end

function Robux.get(kind: string, key: string)
	if kind == "pass" then
		return Robux.Passes[key]
	elseif kind == "product" then
		return Robux.Products[key]
	end
	return nil
end

return Robux
