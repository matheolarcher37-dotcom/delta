-- Formules partagées serveur/client : puissance, revenus, niveaux, coûts.

local Shared = script.Parent.Parent
local Rarities = require(Shared.Config.Rarities)
local Auras = require(Shared.Config.Auras)
local Characters = require(Shared.Config.Characters)
local Universes = require(Shared.Config.Universes)
local Economy = require(Shared.Config.Economy)

local Formulas = {}

-- Accessoires portés sur la tête (utilisé pour mélanger les looks des fusions).
local HEAD_ACCESSORIES = {
	headband = true, mask_lower = true, whiskers = true, glasses = true, blindfold = true,
	tattoos = true, tattoos_blue = true, extra_eyes = true, dots = true, turban = true,
	antennae = true, cat_ears = true, fox_ears = true, bandana = true, cap = true,
	long_nose = true, scar_eye = true, scar_cheek = true, straw_hat = true, earrings = true,
	scar_forehead = true, forehead_mark = true, muzzle = true, facepaint = true, cyclops = true,
	horns = true, volcano = true, stitches = true, scouter = true, dome = true, hood = true,
	hood_full = true, boar_head = true,
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

function Formulas.power(entry): number
	local base = Formulas.basePower(entry)
	local levelFactor = 1 + (entry.level - 1) * 0.12
	local starMult = Economy.StarMultiplier[entry.stars or 1] or 1
	return math.floor(base * levelFactor * starMult * Formulas.auraMultiplier(entry))
end

function Formulas.maxHp(entry): number
	return Formulas.power(entry) * 10
end

-- Revenu passif par seconde quand le perso est exposé sur la base.
function Formulas.income(entry, incomeMult: number?): number
	return Formulas.power(entry) * Economy.IncomeFactor * (incomeMult or 1)
end

function Formulas.sellValue(entry): number
	local desc = Formulas.describe(entry)
	if not desc then
		return 0
	end
	local value = Rarities.get(desc.rarity).sellValue * (entry.stars or 1) * Formulas.auraMultiplier(entry)
	return math.floor(value * (1 + (entry.level - 1) * 0.02))
end

-- Taille visuelle : les persos grandissent avec leur niveau (comme les poulets !).
function Formulas.visualScale(entry): number
	local scale = 0.85 + math.floor(entry.level / 10) * 0.11 + ((entry.stars or 1) - 1) * 0.1
	if entry.fusion then
		scale += 0.15
	end
	return math.min(scale, 2.3)
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

-- Statistiques dérivées des améliorations de base.
function Formulas.upgradeStats(upgrades)
	local stats = {
		incubators = Economy.BaseIncubators,
		team = Economy.BaseTeamSlots,
		display = Economy.BaseDisplaySlots,
		income = 1,
		xp = 1,
		combatCoins = 1,
		hatchSpeed = 1,
	}
	for _, upgrade in Economy.Upgrades do
		if upgrades[upgrade.id] then
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
	return stats
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
