-- Formules partagées serveur/client : puissance, revenus, niveaux, coûts.

local Shared = script.Parent.Parent
local Rarities = require(Shared.Config.Rarities)
local Auras = require(Shared.Config.Auras)
local Characters = require(Shared.Config.Characters)
local Universes = require(Shared.Config.Universes)
local Economy = require(Shared.Config.Economy)
local Traits = require(Shared.Config.Traits)
local SkillTree = require(Shared.Config.SkillTree)

local Formulas = {}

-- Accessoires portés sur la tête (utilisé pour mélanger les looks des fusions).
local HEAD_ACCESSORIES = {
	headband = true,
	mask_lower = true,
	whiskers = true,
	glasses = true,
	blindfold = true,
	tattoos = true,
	tattoos_blue = true,
	extra_eyes = true,
	dots = true,
	turban = true,
	antennae = true,
	cat_ears = true,
	fox_ears = true,
	bandana = true,
	cap = true,
	long_nose = true,
	scar_eye = true,
	scar_cheek = true,
	straw_hat = true,
	earrings = true,
	scar_forehead = true,
	forehead_mark = true,
	muzzle = true,
	facepaint = true,
	cyclops = true,
	horns = true,
	volcano = true,
	stitches = true,
	scouter = true,
	dome = true,
	hood = true,
	hood_full = true,
	boar_head = true,
}
Formulas.HeadAccessories = HEAD_ACCESSORIES

-- Description "virtuelle" d'un personnage possédé (gère les fusions).
-- Retourne { name, rarity, universe, look, attack, isFusion, universes }
function Formulas.describe(entry)
	if entry.fusion then
		local a = Characters.get(entry.fusion.a)
		local b = Characters.get(entry.fusion.b)
		if not a or not b then
			return nil
		end
		return {
			name = (a.fusion and a.fusion.prefix or a.name) .. " " .. (b.fusion and b.fusion.suffix or b.name),
			rarity = "crossover",
			universe = a.universe,
			universes = { a.universe, b.universe },
			look = Formulas.fusionLook(entry.fusion.a, entry.fusion.b, entry.stars),
			attack = { kind = a.attack.kind, color = b.attack.color, name = a.attack.name },
			isFusion = true,
		}
	end
	local def = Characters.get(entry.id)
	if not def then
		return nil
	end
	return {
		name = def.name,
		rarity = def.rarity,
		universe = def.universe,
		universes = { def.universe },
		look = Characters.resolveLook(entry.id, entry.stars),
		attack = def.attack,
		isFusion = false,
	}
end

-- Mélange deux looks : cheveux/visage/accessoires de tête de A, tenue de B.
function Formulas.fusionLook(aId: string, bId: string, stars: number?)
	local a = Characters.resolveLook(aId, 3)
	local b = Characters.resolveLook(bId, 3)
	if not a or not b then
		return nil
	end
	local look = table.clone(b)
	look.skin = a.skin
	look.hair = a.hair
	look.hairColor = a.hairColor
	look.hairTip = a.hairTip
	look.eyes = a.eyes
	look.face = a.face
	local accessories = {}
	for _, acc in a.accessories or {} do
		if HEAD_ACCESSORIES[acc] then
			table.insert(accessories, acc)
		end
	end
	for _, acc in b.accessories or {} do
		if not HEAD_ACCESSORIES[acc] then
			table.insert(accessories, acc)
		end
	end
	look.accessories = accessories
	look.accColor = b.accColor or a.accColor
	-- Les fusions évoluées gagnent une cape aux couleurs du crossover.
	if (stars or 1) >= 2 and not table.find(accessories, "cape") then
		table.insert(accessories, "cape")
		look.capeColor = a.hairColor
	end
	return look
end

function Formulas.basePower(entry): number
	if entry.fusion then
		local a = Characters.get(entry.fusion.a)
		local b = Characters.get(entry.fusion.b)
		local pa = a and Rarities.get(a.rarity).basePower or 0
		local pb = b and Rarities.get(b.rarity).basePower or 0
		return (pa + pb) * 2
	end
	local def = Characters.get(entry.id)
	if not def then
		return 0
	end
	return Rarities.get(def.rarity).basePower
end

function Formulas.levelCap(stars: number?): number
	return Economy.LevelCap[stars or 1] or Economy.LevelCap[1]
end

function Formulas.xpToNext(level: number): number
	return math.floor(10 * level ^ 1.6)
end

function Formulas.auraMultiplier(entry): number
	local aura = Auras.get(entry.aura)
	return aura and aura.multiplier or 1
end

-- Valeur d'un bonus de trait (power, hp, speed, crit, coins, xp, lifesteal, scale).
function Formulas.traitBonus(entry, key: string): number
	local trait = Traits.get(entry.trait)
	if not trait then
		return 0
	end
	return (trait :: any)[key] or 0
end

function Formulas.power(entry): number
	local base = Formulas.basePower(entry)
	local levelFactor = 1 + (entry.level - 1) * 0.12
	local starMult = Economy.StarMultiplier[entry.stars or 1] or 1
	local traitMult = 1 + Formulas.traitBonus(entry, "power")
	return math.floor(base * levelFactor * starMult * Formulas.auraMultiplier(entry) * traitMult)
end

function Formulas.maxHp(entry): number
	return math.floor(Formulas.power(entry) * 10 * (1 + Formulas.traitBonus(entry, "hp")))
end

-- Temps entre deux attaques (en secondes).
function Formulas.attackCooldown(entry): number
	return Economy.FollowerAttackCooldown * (1 - Formulas.traitBonus(entry, "speed"))
end

function Formulas.critChance(entry): number
	return Economy.CritChance + Formulas.traitBonus(entry, "crit")
end

function Formulas.xpMultiplier(entry): number
	return 1 + Formulas.traitBonus(entry, "xp")
end

-- Revenu passif par seconde quand le perso est exposé sur la base.
function Formulas.income(entry, incomeMult: number?): number
	return Formulas.power(entry) * Economy.IncomeFactor * (incomeMult or 1) * (1 + Formulas.traitBonus(entry, "coins"))
end

function Formulas.sellValue(entry): number
	local desc = Formulas.describe(entry)
	if not desc then
		return 0
	end
	local trait = Traits.get(entry.trait)
	local traitMult = trait and (1 + trait.tier * 0.5) or 1
	local value = Rarities.get(desc.rarity).sellValue * (entry.stars or 1) * Formulas.auraMultiplier(entry) * traitMult
	return math.floor(value * (1 + (entry.level - 1) * 0.02))
end

-- Taille visuelle : les persos grandissent avec leur niveau (comme les poulets !).
function Formulas.visualScale(entry): number
	local scale = 0.85 + math.floor(entry.level / 10) * 0.11 + ((entry.stars or 1) - 1) * 0.1 + Formulas.traitBonus(entry, "scale")
	if entry.fusion then
		scale += 0.15
	end
	return math.min(scale, 2.5)
end

-- Coût de la prochaine évolution, ou nil si déjà au maximum.
function Formulas.evolutionCost(entry)
	local nextStar = (entry.stars or 1) + 1
	local cost = Economy.Evolution[nextStar]
	if not cost then
		return nil
	end
	local desc = Formulas.describe(entry)
	if not desc then
		return nil
	end
	local mult = Economy.EvolutionRarityMult[desc.rarity] or 1
	local materials = {}
	for _, universeId in desc.universes do
		local universe = Universes.get(universeId)
		materials[universe.material.id] = math.max(1, math.ceil(cost.materials * mult / #desc.universes))
	end
	return {
		stars = nextStar,
		coins = math.floor(cost.coins * mult),
		materials = materials,
		levelRequired = Formulas.levelCap(entry.stars),
	}
end

-- Statistiques dérivées des améliorations de base ET de l'arbre de compétences (`skills`,
-- facultatif : { [idDeNœud] = true }). Les champs de l'arbre (luck, rollsPerPull, damage, crit...)
-- sont recopiés à plat ; `stats.tree` contient le détail (voir Config/SkillTree.luau).
function Formulas.upgradeStats(upgrades, skills: { [string]: boolean }?)
	local stats: { [string]: any } = {
		incubators = Economy.BaseIncubators,
		team = Economy.BaseTeamSlots,
		display = Economy.BaseDisplaySlots,
		income = 1,
		xp = 1,
		combatCoins = 1,
		hatchSpeed = 1,
	}
	for _, upgrade in Economy.Upgrades do
		if upgrades and upgrades[upgrade.id] then
			local effect = upgrade.effect
			stats.incubators += effect.incubators or 0
			stats.team += effect.team or 0
			stats.display += effect.display or 0
			stats.income += effect.income or 0
			stats.xp += effect.xp or 0
			stats.combatCoins += effect.combatCoins or 0
			stats.hatchSpeed -= effect.hatchSpeed or 0
		end
	end
	stats.hatchSpeed = math.max(stats.hatchSpeed, 0.3)

	local tree = SkillTree.stats(skills)
	stats.tree = tree
	stats.income += tree.income - 1
	stats.xp += tree.xp
	stats.combatCoins += tree.loot
	stats.display = math.min(stats.display + tree.unitSlots, Economy.MaxDisplaySlots)
	for _, key in
		{
			"luck",
			"rollsPerPull",
			"rollCooldown",
			"x10Every",
			"pityMult",
			"autoRoll",
			"damage",
			"crit",
			"critDamage",
			"unitSlots",
			"attackSpeed",
			"auraLuck",
			"traitLuck",
			"walkSpeed",
			"loot",
		}
	do
		stats[key] = tree[key]
	end
	return stats
end

-- Statistiques complètes d'un joueur (améliorations + arbre) à partir de ses données.
function Formulas.playerStats(data)
	return Formulas.upgradeStats(data and data.upgrades, data and data.Skills)
end

------------------------------------------------------------------------
-- Machine de roulage
------------------------------------------------------------------------

function Formulas.rollRarity(id: string?)
	return Economy.RollRarities[id or "common"] or Economy.RollRarities.common
end

-- Probabilités (0-1) de chaque rareté de la machine pour une chance donnée.
-- La chance multiplie les raretés Rare et plus (la racine carrée pour Peu commun) ; si le total
-- déborde, ce sont les raretés les plus communes qui cèdent leur place (le Commun garde 5 %).
function Formulas.rollOdds(luck: number?): { [string]: number }
	local l = math.max(1, luck or 1)
	local wanted = {}
	for _, id in Economy.RollOrder do
		local info = Economy.RollRarities[id]
		if info.order >= 3 then
			wanted[id] = info.odds * l
		elseif info.order == 2 then
			wanted[id] = info.odds * math.sqrt(l)
		end
	end
	local odds = {}
	local remaining = 95
	for i = #Economy.RollOrder, 2, -1 do
		local id = Economy.RollOrder[i]
		local take = math.min(wanted[id] or 0, remaining)
		odds[id] = take / 100
		remaining -= take
	end
	odds.common = (100 - 95 + remaining) / 100
	return odds
end

-- Seuil de pitié (nombre de persos tirés) d'une rareté, après l'arbre.
function Formulas.pityThreshold(rarityId: string, pityMult: number?): number
	local base = Economy.Roll.Pity[rarityId] or 0
	return math.max(1, math.floor(base * (pityMult or 1) + 0.5))
end

-- Prix (en ¥ = pièces) d'un perso tiré : rareté de la machine, aura et trait.
function Formulas.rollPrice(rarityId: string, auraId: string?, traitId: string?): number
	local info = Formulas.rollRarity(rarityId)
	local aura = Auras.get(auraId)
	local trait = Traits.get(traitId)
	-- Ce que la rareté GARANTIT (aura Arc-en-ciel et trait rare du Secret, trait du Peu commun)
	-- est déjà compris dans son prix de base : seul le « bonus » au-delà est compté.
	local auraMult = (aura and aura.id ~= info.aura) and aura.multiplier or 1
	local tierBonus = trait and math.max(0, trait.tier - (info.traitMinTier or 0)) or 0
	local price = info.price * auraMult * (1 + tierBonus * 0.3)
	-- Arrondi « joli » (2 chiffres significatifs).
	local magnitude = 10 ^ math.max(0, math.floor(math.log10(math.max(price, 1))) - 1)
	return math.floor(price / magnitude + 0.5) * magnitude
end

-- Le tout premier perso collecté est offert, mais seulement jusqu'à la rareté
-- Economy.Roll.FreeCollectMaxOrder (sinon on pourrait rouler jusqu'à un Mythique gratuit).
function Formulas.rollCollectFree(data, rarityId: string?): boolean
	if not Economy.Roll.FirstCollectFree or not data or data.FirstCollectDone then
		return false
	end
	local info = Economy.RollRarities[rarityId or "common"]
	return info ~= nil and info.order <= (Economy.Roll.FreeCollectMaxOrder or 0)
end

-- Dégâts par seconde d'un perso (affichés au-dessus des persos tirés).
function Formulas.dps(entry): number
	return Formulas.power(entry) / math.max(0.2, Formulas.attackCooldown(entry))
end

-- Index (collection) : clé unique pour un perso ou une fusion.
function Formulas.indexKey(entry): string
	if entry.fusion then
		return "fusion:" .. entry.fusion.a .. "+" .. entry.fusion.b
	end
	return entry.id
end

-- 1234567 -> "1,23 M"
function Formulas.formatNumber(n: number): string
	n = math.floor(n)
	local abs = math.abs(n)
	local suffixes = { { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "k" } }
	for _, pair in suffixes do
		if abs >= pair[1] then
			local value = n / pair[1]
			local text
			if math.abs(value) >= 100 then
				text = string.format("%d", math.floor(value))
			elseif math.abs(value) >= 10 then
				text = string.format("%.1f", value)
			else
				text = string.format("%.2f", value)
			end
			if text:find("%.") then
				text = text:gsub("0+$", "")
				text = text:gsub("%.$", "")
			end
			text = text:gsub("%.", ",")
			return text .. " " .. pair[2]
		end
	end
	return tostring(n)
end

-- 754 -> "12:34"
function Formulas.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%02d:%02d", minutes, secs)
end

return Formulas
