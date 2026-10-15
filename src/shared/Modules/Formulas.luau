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

-- Majuscules françaises : string.upper ne touche pas aux lettres accentuées (« LéGENDAIRE »).
-- Formulas.upper("Légendaire") → « LÉGENDAIRE ». À utiliser à la place de string.upper.
local ACCENTS = {
	{ "é", "É" },
	{ "è", "È" },
	{ "ê", "Ê" },
	{ "ë", "Ë" },
	{ "à", "À" },
	{ "â", "Â" },
	{ "î", "Î" },
	{ "ï", "Ï" },
	{ "ô", "Ô" },
	{ "û", "Û" },
	{ "ù", "Ù" },
	{ "ü", "Ü" },
	{ "ç", "Ç" },
	{ "œ", "Œ" },
}
function Formulas.upper(text: string): string
	local out = string.upper(tostring(text))
	for _, pair in ACCENTS do
		out = string.gsub(out, pair[1], pair[2])
	end
	return out
end

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
			"rollDiscount",
		}
	do
		stats[key] = tree[key]
	end
	return stats
end

-- Statistiques complètes d'un joueur (améliorations + arbre) à partir de ses données.
function Formulas.playerStats(data)
	local stats = Formulas.upgradeStats(data and data.upgrades, data and data.Skills)
	-- Passe Robux « Emplacements + » (data.RobuxSlots, posé par MonetizationService).
	local bonus = data and tonumber(data.RobuxSlots) or 0
	if bonus > 0 then
		stats.display = math.min(stats.display + math.floor(bonus), Economy.MaxDisplaySlots)
	end
	return stats
end

------------------------------------------------------------------------
-- Machine de roulage
------------------------------------------------------------------------

function Formulas.rollRarity(id: string?)
	return Economy.RollRarities[id or "common"] or Economy.RollRarities.common
end

-- Raretés tirables dans un univers : { [rareté] = { ids des persos } }. Les raretés « facultatives »
-- (Peu commun, Secret) ne comptent que si l'univers a des persos de cette rareté.
function Formulas.rollPools(universeId: string?): { [string]: { string } }
	local universe = Universes.get(universeId or "") or Universes.List[1]
	local pools = {}
	for _, id in universe.characters do
		local def = Characters.get(id)
		if def and Economy.RollRarities[def.rarity] then
			pools[def.rarity] = pools[def.rarity] or {}
			table.insert(pools[def.rarity], id)
		end
	end
	return pools
end

-- Vrai si la rareté peut sortir (les raretés facultatives demandent des persos dans le pool).
local function rarityAvailable(id: string, pools: { [string]: { string } }?): boolean
	local info = Economy.RollRarities[id]
	if not info then
		return false
	end
	if not info.optional then
		return true
	end
	return pools ~= nil and pools[id] ~= nil and #pools[id] > 0
end
Formulas.rollRarityAvailable = rarityAvailable

-- Probabilités (0-1) de chaque rareté de la machine pour une chance donnée (`pools` : raretés
-- présentes dans l'univers, voir rollPools ; sans `pools`, seules les raretés non facultatives).
-- La chance multiplie les raretés Rare et plus (la racine carrée pour Peu commun) ; si le total
-- déborde, c'est le Commun qui cède sa place (il garde toujours au moins 5 %).
function Formulas.rollOdds(luck: number?, pools: { [string]: { string } }?): { [string]: number }
	local l = math.max(1, luck or 1)
	local total = 0
	for _, id in Economy.RollOrder do
		if rarityAvailable(id, pools) then
			total += Economy.RollRarities[id].odds
		end
	end
	total = math.max(total, 0.0001)
	local odds = {}
	local remaining = 95
	for i = #Economy.RollOrder, 2, -1 do
		local id = Economy.RollOrder[i]
		local info = Economy.RollRarities[id]
		if rarityAvailable(id, pools) then
			local base = info.odds / total * 100
			local wanted = info.order >= 3 and base * l or base * math.sqrt(l)
			local take = math.min(wanted, remaining)
			odds[id] = take / 100
			remaining -= take
		else
			odds[id] = 0
		end
	end
	odds.common = (100 - 95 + remaining) / 100
	return odds
end

-- Chance totale du joueur à la machine : arbre de compétences × passe « x2 Chance » (attribut
-- Pass_Luck2) × potion de chance (attribut Boost_Luck = heure de fin) × événement éventuel.
-- `player` peut être nil (aperçus) ; `now` = os.time() côté serveur.
function Formulas.rollLuck(stats, player: Player?, now: number?, extra: number?): number
	local luck = (stats and stats.luck or 1) * (extra or 1)
	if player then
		if player:GetAttribute("Pass_Luck2") == true then
			luck *= Economy.Roll.PassLuck or 2
		end
		local boost = tonumber(player:GetAttribute("Boost_Luck"))
		if boost and boost > (now or os.time()) then
			luck *= Economy.Roll.BoostLuck or 2
		end
	end
	return luck
end

-- Nombre de persos par roulage selon les passes Robux (Pass_Roll3 > Pass_Roll2 > 1) et le choix
-- du joueur (`wanted`, 1 à 3 : on peut repasser à 1 même avec un passe).
function Formulas.rollsPerRoll(player: Player?, wanted: number?): number
	local owned = 1
	if player then
		if player:GetAttribute("Pass_Roll3") == true then
			owned = 3
		elseif player:GetAttribute("Pass_Roll2") == true then
			owned = 2
		end
	end
	local choice = math.floor(tonumber(wanted) or owned)
	return math.clamp(choice, 1, math.min(owned, Economy.Roll.MaxPerRoll or 3))
end

-- Seuil de pitié (nombre de persos tirés) d'une rareté, après l'arbre. Seul le Mythique en a une.
function Formulas.pityThreshold(rarityId: string?, pityMult: number?): number
	local base = Economy.Roll.Pity[rarityId or Economy.Roll.PityRarity] or 0
	return math.max(1, math.floor(base * (pityMult or 1) + 0.5))
end

-- Prix (en ¥ = pièces) d'un perso tiré : rareté du perso, mutation, trait, réduction de l'arbre.
function Formulas.rollPrice(rarityId: string, mutationId: string?, traitId: string?, discount: number?): number
	local info = Formulas.rollRarity(rarityId)
	local mutation = Auras.get(mutationId)
	local trait = Traits.get(traitId)
	local tierBonus = trait and trait.tier or 0
	local price = info.price * (mutation and mutation.multiplier or 1) * (1 + tierBonus * 0.3) * (1 - math.clamp(discount or 0, 0, 0.9))
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

-- Vrai si un perso tiré correspond aux cibles de l'auto-roulage : `filter` = { characters = { [id] = true },
-- rarities = { [rareté] = true }, mutations = { [mutation ou "aucune"] = true } }. Un groupe vide
-- n'impose rien ; si les trois sont vides, rien ne correspond.
function Formulas.rollMatches(item, filter): boolean
	if type(item) ~= "table" or type(filter) ~= "table" then
		return false
	end
	local any = false
	local function check(set, value): boolean
		if type(set) ~= "table" or next(set) == nil then
			return true
		end
		any = true
		return set[value] == true
	end
	local mutation = Auras.get(item.aura)
	local okChar = check(filter.characters, item.id)
	local okRarity = check(filter.rarities, item.rarity)
	local okMutation = check(filter.mutations, mutation and mutation.id or "aucune")
	return any and okChar and okRarity and okMutation
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

-- PANNEAUX D'ACHAT de la base : place à l'écran et désencombrement (client + tests).
-- Rectangle à l'écran d'un panneau dont le BORD BAS est en `pos` (il pousse vers le haut) :
-- taille = studs (rapetissent avec la distance) + pixels (fixes). `view` = { eye, forward, right,
-- up, focal (pixels), w, h } ; renvoie nil si le panneau est derrière la caméra ou hors écran.
function Formulas.boardRect(view, pos: Vector3, studsW: number, pixelsW: number, studsH: number, pixelsH: number)
	local d = pos - view.eye
	local z = d:Dot(view.forward)
	if z <= 1 then
		return nil
	end
	local sx = view.w / 2 + d:Dot(view.right) * view.focal / z
	local sy = view.h / 2 - d:Dot(view.up) * view.focal / z
	local w = studsW * view.focal / z + pixelsW
	local h = studsH * view.focal / z + pixelsH
	if sx + w / 2 < 0 or sx - w / 2 > view.w or sy < 0 or sy - h > view.h then
		return nil
	end
	return { x0 = sx - w / 2, x1 = sx + w / 2, y0 = sy - h, y1 = sy, dist = d.Magnitude }
end

-- Désencombrement : du plus proche au plus loin, un panneau qui recouvrirait un panneau déjà
-- affiché (plus de `maxOverlap` de la plus petite surface) est caché ; il réapparaît dès qu'on
-- s'approche. Renvoie { [index] = true } pour les panneaux à afficher. `conflicts(i, j)`
-- (facultatif) dit si deux panneaux peuvent être affichés ensemble (tests).
Formulas.BoardMaxOverlap = 0.04
function Formulas.declutterBoards(rects: { any }, maxOverlap: number?, conflicts: ((number, number) -> boolean)?): { [number]: boolean }
	local limit = maxOverlap or Formulas.BoardMaxOverlap
	local order = {}
	for i, rect in rects do
		if rect then
			table.insert(order, i)
		end
	end
	table.sort(order, function(a, b)
		return rects[a].dist < rects[b].dist
	end)
	local shown, kept = {}, {}
	for _, i in order do
		local a = rects[i]
		local ok = true
		for _, j in kept do
			local b = rects[j]
			if conflicts and not conflicts(i, j) then
				continue
			end
			local ox = math.max(0, math.min(a.x1, b.x1) - math.max(a.x0, b.x0))
			local oy = math.max(0, math.min(a.y1, b.y1) - math.max(a.y0, b.y0))
			local area = math.min((a.x1 - a.x0) * (a.y1 - a.y0), (b.x1 - b.x0) * (b.y1 - b.y0))
			if ox * oy > limit * area then
				ok = false
				break
			end
		end
		if ok then
			shown[i] = true
			table.insert(kept, i)
		end
	end
	return shown
end

return Formulas
