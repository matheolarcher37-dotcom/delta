-- ARBRE DE COMPÉTENCES (hexagonal, comme les arbres des jeux de tirage).
--
-- Chaque nœud est une case hexagonale repérée par ses coordonnées AXIALES (q, r) :
--   voisins d'une case = (q+1, r) (q-1, r) (q, r+1) (q, r-1) (q+1, r-1) (q-1, r+1).
--   Pour dessiner (hexagones « pointe en haut ») : x = taille * √3 * (q + r/2), y = taille * 1,5 * r.
-- Le cœur (0, 0) est au centre ; six grandes branches partent dans les six directions :
--   haut (0,-1)        : CHANCE (+ Chance x10, Instinct des traits)
--   haut-droite (1,-1) : TIRAGE (Taux d'apparition, Multi-tirage, Auto-roulage)
--   droite (1,0)       : REVENU (+ Butin, Entraînement)
--   bas (0,1)          : DÉGÂTS (+ Vitesse d'attaque)
--   bas-gauche (-1,1)  : CRITIQUE (+ Dégâts critiques)
--   gauche (-1,0)      : EMPLACEMENTS (+ Pas légers, Pitié, Œil céleste)
--
-- Champs d'un nœud : id, name, icon (emoji), q, r, cost, currency ("Coins"), requires = { ids },
-- effect = { stat, add }, desc, branch (nom de la branche, pour la couleur de l'écran).
-- Pour équilibrer : changer `cost` ou `add` ici suffit (le serveur et l'écran lisent ce fichier).

local SkillTree = {}

-- Valeurs de départ (sans aucun nœud acheté).
SkillTree.Base = {
	luck = 1, -- multiplicateur de chance des raretés Rare et plus
	rollsPerPull = 1, -- persos tirés par roulage (1 → 2 → 3)
	rollCooldown = 3.5, -- secondes entre deux roulages
	x10Every = 10, -- un roulage « Chance x10 » tous les N roulages
	pityMult = 1, -- multiplicateur des seuils de pitié (plus petit = pitié plus rapide)
	autoRoll = false, -- auto-roulage débloqué ?
	income = 1, -- multiplicateur de revenu des unités exposées
	damage = 1, -- multiplicateur de dégâts de l'équipe
	crit = 0, -- chance de critique ajoutée (0,05 = +5 %)
	critDamage = 2, -- multiplicateur des coups critiques
	unitSlots = 0, -- emplacements d'unités en plus dans la base
	loot = 0, -- pièces de combat en plus (0,1 = +10 %)
	xp = 0, -- XP passive en plus
	attackSpeed = 0, -- attaques plus rapides (0,05 = -5 % de temps entre deux attaques)
	auraLuck = 1, -- multiplicateur de chance d'aura sur les persos tirés
	traitLuck = 1, -- multiplicateur de chance de trait sur les persos tirés
	walkSpeed = 0, -- vitesse de marche en plus (studs/s)
}

-- Limites (pour que l'équilibrage reste sain même si on ajoute des nœuds).
SkillTree.Limits = {
	rollCooldown = 0.8,
	x10Every = 4,
	pityMult = 0.4,
	rollsPerPull = 3,
}

SkillTree.Branches = {
	coeur = { name = "Cœur", color = Color3.fromRGB(255, 255, 255) },
	chance = { name = "Chance", color = Color3.fromRGB(80, 230, 120) },
	tirage = { name = "Tirage", color = Color3.fromRGB(80, 200, 255) },
	revenu = { name = "Revenu", color = Color3.fromRGB(255, 205, 60) },
	degats = { name = "Dégâts", color = Color3.fromRGB(255, 80, 70) },
	critique = { name = "Critique", color = Color3.fromRGB(255, 120, 210) },
	domaine = { name = "Domaine", color = Color3.fromRGB(180, 130, 255) },
}

local function node(branch: string, id: string, name: string, icon: string, q: number, r: number, cost: number, requires: { string }, stat: string, add: number, desc: string)
	return {
		id = id,
		name = name,
		icon = icon,
		q = q,
		r = r,
		cost = cost,
		currency = "Coins",
		requires = requires,
		effect = { stat = stat, add = add },
		desc = desc,
		branch = branch,
	}
end

SkillTree.Nodes = {
	-- Cœur
	node("coeur", "coeur", "Éveil", "✨", 0, 0, 150, {}, "luck", 0.05, "+5 % de chance. Débloque les six branches."),

	-- CHANCE (haut)
	node("chance", "chance1", "Chance I", "🍀", 0, -1, 600, { "coeur" }, "luck", 0.15, "+15 % de chance (Rare et plus)."),
	node("chance", "chance2", "Chance II", "🍀", 0, -2, 4000, { "chance1" }, "luck", 0.2, "+20 % de chance."),
	node("chance", "chance3", "Chance III", "🍀", 0, -3, 25000, { "chance2" }, "luck", 0.25, "+25 % de chance."),
	node("chance", "chance4", "Chance IV", "🍀", 0, -4, 150000, { "chance3" }, "luck", 0.35, "+35 % de chance."),
	node("chance", "chance5", "Chance V", "🍀", 0, -5, 900000, { "chance4" }, "luck", 0.5, "+50 % de chance."),
	node("chance", "chance_divine", "Chance Divine", "🌈", 0, -6, 12000000, { "chance5" }, "luck", 1, "+100 % de chance : les Mythiques arrivent !"),
	node("chance", "x10_1", "Chance x10 I", "🔟", 1, -3, 18000, { "chance2" }, "x10Every", -1, "Le roulage « Chance x10 » arrive 1 roulage plus tôt."),
	node("chance", "x10_2", "Chance x10 II", "🔟", 1, -4, 120000, { "x10_1" }, "x10Every", -1, "Encore 1 roulage plus tôt."),
	node("chance", "x10_3", "Chance x10 III", "🔟", 1, -5, 750000, { "x10_2" }, "x10Every", -1, "Encore 1 roulage plus tôt."),
	node("chance", "instinct", "Instinct", "🧬", 1, -2, 3000, { "chance1" }, "traitLuck", 0.5, "+50 % de chance d'obtenir un trait rare sur les persos tirés."),

	-- TIRAGE (haut-droite)
	node("tirage", "taux1", "Taux d'apparition I", "⏩", 1, -1, 800, { "coeur" }, "rollCooldown", -0.4, "Roulage 0,4 s plus rapide."),
	node("tirage", "multi1", "Multi-tirage I", "👥", 2, -2, 75000, { "taux1" }, "rollsPerPull", 1, "Tire 2 persos à la fois au lieu d'1 !"),
	node("tirage", "taux2", "Taux d'apparition II", "⏩", 3, -3, 220000, { "multi1" }, "rollCooldown", -0.4, "Roulage encore 0,4 s plus rapide."),
	node("tirage", "multi2", "Multi-tirage II", "🎲", 4, -4, 4000000, { "taux2" }, "rollsPerPull", 1, "Tire 3 persos à la fois !"),
	node("tirage", "taux3", "Taux d'apparition III", "⏩", 3, -2, 600000, { "multi1" }, "rollCooldown", -0.4, "Roulage encore 0,4 s plus rapide."),
	node("tirage", "turbo", "Machine Survoltée", "⚡", 5, -5, 15000000, { "multi2" }, "rollCooldown", -0.5, "Roulage 0,5 s plus rapide."),
	node("tirage", "autoroll", "Auto-roulage", "🤖", 2, -1, 30000, { "taux1" }, "autoRoll", 1, "La machine roule toute seule (à activer dans le menu)."),

	-- REVENU (droite)
	node("revenu", "revenu1", "Revenu I", "💰", 1, 0, 500, { "coeur" }, "income", 0.1, "+10 % de revenus des unités exposées."),
	node("revenu", "revenu2", "Revenu II", "💰", 2, 0, 3500, { "revenu1" }, "income", 0.15, "+15 % de revenus."),
	node("revenu", "revenu3", "Revenu III", "💰", 3, 0, 22000, { "revenu2" }, "income", 0.2, "+20 % de revenus."),
	node("revenu", "revenu4", "Revenu IV", "💰", 4, 0, 140000, { "revenu3" }, "income", 0.3, "+30 % de revenus."),
	node("revenu", "revenu5", "Revenu V", "💰", 5, 0, 850000, { "revenu4" }, "income", 0.5, "+50 % de revenus."),
	node("revenu", "tresor", "Trésor du Shogun", "👑", 6, 0, 10000000, { "revenu5" }, "income", 1, "+100 % de revenus !"),
	node("revenu", "butin1", "Butin I", "🪙", 2, 1, 6000, { "revenu2" }, "loot", 0.1, "+10 % de pièces gagnées en combat."),
	node("revenu", "butin2", "Butin II", "🪙", 3, 1, 45000, { "butin1" }, "loot", 0.15, "+15 % de pièces en combat."),
	node("revenu", "butin3", "Butin III", "🪙", 4, 1, 300000, { "butin2" }, "loot", 0.25, "+25 % de pièces en combat."),
	node("revenu", "entrainement1", "Entraînement I", "📈", 1, 1, 1500, { "revenu1" }, "xp", 0.25, "+25 % d'XP passive sur la base."),
	node("revenu", "entrainement2", "Entraînement II", "📈", 1, 2, 12000, { "entrainement1" }, "xp", 0.5, "+50 % d'XP passive."),

	-- DÉGÂTS (bas)
	node("degats", "degats1", "Dégâts I", "⚔️", 0, 1, 700, { "coeur" }, "damage", 0.1, "+10 % de dégâts de ton équipe."),
	node("degats", "degats2", "Dégâts II", "⚔️", 0, 2, 4500, { "degats1" }, "damage", 0.15, "+15 % de dégâts."),
	node("degats", "degats3", "Dégâts III", "⚔️", 0, 3, 28000, { "degats2" }, "damage", 0.2, "+20 % de dégâts."),
	node("degats", "degats4", "Dégâts IV", "⚔️", 0, 4, 170000, { "degats3" }, "damage", 0.3, "+30 % de dégâts."),
	node("degats", "degats5", "Dégâts V", "⚔️", 0, 5, 1000000, { "degats4" }, "damage", 0.5, "+50 % de dégâts."),
	node("degats", "frappe", "Frappe Titanesque", "💥", 0, 6, 12000000, { "degats5" }, "damage", 1, "+100 % de dégâts !"),
	node("degats", "vitesse1", "Vitesse I", "💨", -1, 2, 5000, { "degats1" }, "attackSpeed", 0.05, "Ton équipe frappe plus vite : +5 % de DPS."),
	node("degats", "vitesse2", "Vitesse II", "💨", -1, 3, 40000, { "vitesse1" }, "attackSpeed", 0.07, "Frappes plus rapides : +7 % de DPS."),
	node("degats", "vitesse3", "Vitesse III", "💨", -1, 4, 260000, { "vitesse2" }, "attackSpeed", 0.1, "Frappes plus rapides : +10 % de DPS."),

	-- CRITIQUE (bas-gauche)
	node("critique", "crit1", "Critique I", "🎯", -1, 1, 900, { "coeur" }, "crit", 0.03, "+3 % de chance de coup critique."),
	node("critique", "crit2", "Critique II", "🎯", -2, 2, 7000, { "crit1" }, "crit", 0.04, "+4 % de chance de critique."),
	node("critique", "crit3", "Critique III", "🎯", -3, 3, 60000, { "crit2" }, "crit", 0.05, "+5 % de chance de critique."),
	node("critique", "critdmg1", "Dégâts critiques I", "💢", -3, 2, 20000, { "crit2" }, "critDamage", 0.25, "Coups critiques +25 % plus forts."),
	node("critique", "critdmg2", "Dégâts critiques II", "💢", -4, 3, 160000, { "critdmg1" }, "critDamage", 0.35, "Coups critiques +35 % plus forts."),
	node("critique", "critdmg3", "Dégâts critiques III", "💢", -5, 4, 1100000, { "critdmg2" }, "critDamage", 0.5, "Coups critiques +50 % plus forts."),
	node("critique", "lame", "Lame du Destin", "🗡️", -4, 4, 9000000, { "crit3" }, "critDamage", 0.75, "Coups critiques +75 % plus forts !"),

	-- DOMAINE (gauche)
	node("domaine", "slots1", "Emplacements I", "🔷", -1, 0, 1000, { "coeur" }, "unitSlots", 1, "+1 emplacement d'unité dans ta base."),
	node("domaine", "slots2", "Emplacements II", "🔷", -2, 0, 9000, { "slots1" }, "unitSlots", 1, "+1 emplacement d'unité."),
	node("domaine", "slots3", "Emplacements III", "🔷", -3, 0, 80000, { "slots2" }, "unitSlots", 1, "+1 emplacement d'unité."),
	node("domaine", "slots4", "Emplacements IV", "🔷", -4, 0, 600000, { "slots3" }, "unitSlots", 1, "+1 emplacement d'unité."),
	node("domaine", "domaine", "Grand Domaine", "🏯", -5, 0, 6000000, { "slots4" }, "unitSlots", 2, "+2 emplacements d'unités !"),
	node("domaine", "pas1", "Pas Légers I", "👟", -2, 1, 4000, { "slots1" }, "walkSpeed", 2, "Tu cours un peu plus vite."),
	node("domaine", "pas2", "Pas Légers II", "👟", -3, 1, 35000, { "pas1" }, "walkSpeed", 3, "Tu cours encore plus vite."),
	node("domaine", "pitie1", "Pitié I", "🛡️", -1, -1, 10000, { "chance1" }, "pityMult", -0.15, "Les garanties (Légendaire, Mythique, Secret) arrivent 15 % plus tôt."),
	node("domaine", "pitie2", "Pitié II", "🛡️", -1, -2, 200000, { "pitie1" }, "pityMult", -0.15, "Les garanties arrivent encore 15 % plus tôt."),
	node("domaine", "oeil1", "Œil Céleste I", "👁️", -2, -1, 25000, { "pitie1" }, "auraLuck", 0.5, "+50 % de chance d'aura sur les persos tirés."),
	node("domaine", "oeil2", "Œil Céleste II", "👁️", -2, -2, 400000, { "oeil1" }, "auraLuck", 1, "+100 % de chance d'aura."),
}

SkillTree.ById = {}
for index, n in SkillTree.Nodes do
	n.order = index
	SkillTree.ById[n.id] = n
end

function SkillTree.get(id: string)
	return SkillTree.ById[id]
end

-- Vrai si tous les prérequis du nœud sont possédés.
function SkillTree.canUnlock(owned: { [string]: boolean }?, id: string): boolean
	local n = SkillTree.ById[id]
	if not n then
		return false
	end
	for _, req in n.requires do
		if not (owned and owned[req]) then
			return false
		end
	end
	return true
end

-- Statistiques totales pour une liste de nœuds possédés ({ [id] = true }).
function SkillTree.stats(owned: { [string]: boolean }?)
	local s = table.clone(SkillTree.Base)
	local autoRoll = 0
	for id, has in owned or {} do
		local n = has and SkillTree.ById[id]
		if n then
			local stat, add = n.effect.stat, n.effect.add
			if stat == "autoRoll" then
				autoRoll += add
			elseif type(s[stat]) == "number" then
				s[stat] += add
			end
		end
	end
	s.autoRoll = autoRoll > 0
	s.rollCooldown = math.max(SkillTree.Limits.rollCooldown, s.rollCooldown)
	s.x10Every = math.max(SkillTree.Limits.x10Every, math.floor(s.x10Every + 0.5))
	s.pityMult = math.max(SkillTree.Limits.pityMult, s.pityMult)
	s.rollsPerPull = math.clamp(math.floor(s.rollsPerPull + 0.5), 1, SkillTree.Limits.rollsPerPull)
	return s
end

-- Distance hexagonale entre deux cases (utile pour l'écran : anneaux autour du cœur).
function SkillTree.distance(q1: number, r1: number, q2: number, r2: number): number
	return (math.abs(q1 - q2) + math.abs(q1 + r1 - q2 - r2) + math.abs(r1 - r2)) / 2
end

return SkillTree
