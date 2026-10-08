-- DÉFIS (quêtes), GEMMES DE TRAIT et ZONE ANTI-AFK (punching-balls).
--
-- • Défis PERMANENTS à paliers : « Village Ninja : tue 200 Kabouto » → 1 000 ¥, puis le palier
--   suivant (1 000 Kabouto)... Ceux des univers sont créés automatiquement à partir de
--   Config/Universes (ennemis et boss de chaque univers) : un ennemi ajouté ou renommé là-bas
--   apparaît tout seul ici.
-- • Défis QUOTIDIENS : 4 défis tirés chaque jour (minuit UTC), différents pour chaque joueur,
--   + un coffre bonus quand les 4 sont réclamés.
-- • Les « gemmes de trait » sont les Cristaux de Trait (champ traitCrystals) : 1 gemme = 1 relance
--   de trait. On en gagne en tuant des ennemis, en battant le boss, au punching-ball et en défis.
--
-- Pour changer un objectif ou une récompense : modifie les tables ci-dessous.
-- Récompense = { coins = ¥, gems = gemmes de trait, items = { [idObjet] = n } (objets du marchand) }.

local Universes = require(script.Parent.Universes)
local Characters = require(script.Parent.Characters)

local rgb = Color3.fromRGB

local Quests = {}

------------------------------------------------------------------------
-- Gemmes de trait gagnées en combat (chance par ennemi tué, selon sa force)
------------------------------------------------------------------------

Quests.Gems = {
	-- [force de l'ennemi] = { chance, minimum, maximum } : on en gagne souvent en combat
	-- (« Tue 200 ennemis » ≈ 30 gemmes), le punching-ball reste à 1000 coups = 20 gemmes.
	Tiers = {
		[1] = { chance = 0.08, min = 1, max = 1 },
		[2] = { chance = 0.15, min = 1, max = 1 },
		[3] = { chance = 0.30, min = 1, max = 2 },
	},
	Rival = { chance = 0.5, min = 1, max = 2 }, -- rivaux d'univers (Kakashu, Vejeta...)
	Boss = { min = 5, max = 10 }, -- pour chaque joueur qui a participé au combat
	Name = "Gemme de trait",
	NamePlural = "Gemmes de trait",
	Color = rgb(50, 214, 255),
}

------------------------------------------------------------------------
-- Rivaux d'univers : de temps en temps, un perso de l'univers apparaît comme ennemi
-- (« Village Ninja : tue 200 Kakashu »). Compté avec la clé kill:<idPerso>.
------------------------------------------------------------------------

Quests.RivalChance = 0.15 -- part des apparitions d'ennemis remplacées par un rival
Quests.Rivals = {
	ninja = { "ninja_kakashu", "ninja_sasuki" },
	occulte = { "occ_megumo", "occ_toudo" },
	saiyan = { "sai_vejeta", "sai_piccola" },
	ocean = { "oce_zoru", "oce_sanjo" },
	pourfendeur = { "pou_inosoke", "pou_zenitso" },
}

-- Rivaux valides d'un univers (persos qui existent vraiment ; sinon deux persos de l'univers).
function Quests.rivalsFor(universe: any): { string }
	local list = {}
	if type(universe) ~= "table" then
		return list
	end
	for _, id in Quests.Rivals[universe.id] or {} do
		if Characters.List[id] then
			table.insert(list, id)
		end
	end
	if #list == 0 and type(universe.characters) == "table" then
		for i = #universe.characters - 2, #universe.characters - 3, -1 do
			local id = universe.characters[i]
			if id and Characters.List[id] then
				table.insert(list, id)
			end
		end
	end
	return list
end

-- Nom au pluriel d'un ennemi pour les titres (« Tue 50 Pirates de Buggi »). Les noms propres
-- (Kabouto, Zabouza...) restent tels quels.
Quests.Plurals = {
	ninja_son = "Ninjas du Son",
	occ_fleau = "Fléaux Mineurs",
	sai_soldat = "Soldats de Freezo",
	sai_saibamon = "Saibamons",
	oce_pirate = "Pirates de Buggi",
	oce_marine = "Marines",
	pou_demon = "Démons Inférieurs",
}
function Quests.plural(id: string, name: string): string
	return Quests.Plurals[id] or name
end

------------------------------------------------------------------------
-- Zone anti-AFK : punching-balls
------------------------------------------------------------------------

Quests.Punch = {
	Bags = 3, -- 3 punching-balls : 3 joueurs peuvent taper en même temps, chacun le sien
	Goal = 1000, -- coups pour finir un cycle (le compteur repart à 0 ensuite)
	-- Paliers d'un cycle : { coups, gemmes données en l'atteignant } (total : 20 gemmes / 1000 coups)
	Tiers = {
		{ 100, 2 },
		{ 250, 3 },
		{ 500, 4 },
		{ 750, 4 },
		{ 1000, 7 },
	},
	MinInterval = 0.3, -- cadence maximale comptée (anti-triche) : un coup toutes les 0,3 s au plus
	Reach = 7.5, -- distance max (studs) entre le joueur et le sac pour que le coup compte
	ReleaseDistance = 18, -- le sac est libéré quand son joueur s'éloigne plus loin que ça...
	ReleaseDelay = 4, -- ... pendant ce temps (secondes)
	IdleRelease = 30, -- ou quand il ne tape plus depuis ce temps (secondes)
}

-- Total de gemmes d'un cycle complet.
function Quests.punchCycleGems(): number
	local total = 0
	for _, tier in Quests.Punch.Tiers do
		total += tier[2]
	end
	return total
end

-- Prochain palier du cycle (ou nil si tout est atteint).
function Quests.nextPunchTier(count: number): ({ number }?, number?)
	for index, tier in Quests.Punch.Tiers do
		if count < tier[1] then
			return tier, index
		end
	end
	return nil, nil
end

------------------------------------------------------------------------
-- Compteurs
------------------------------------------------------------------------
-- Clés de compteurs (data.Quests.counters) :
--   kill, kill:<idEnnemi>, killu:<idUnivers>, elite (ennemis forts), boss, boss:<idBoss>,
--   swordkill, punch, reroll, gems
-- Clés lues directement dans la sauvegarde (« stat:... ») :
--   stat:RollCount, stat:evolutions, stat:fusions, stat:hatched, stat:trades, stat:playtime (minutes),
--   stat:totalCoins, stat:skills (cases de l'arbre), stat:index (persos différents découverts)

local function count(t: any): number
	local n = 0
	if type(t) == "table" then
		for _ in t do
			n += 1
		end
	end
	return n
end

function Quests.read(data: any, key: string): number
	if type(data) ~= "table" then
		return 0
	end
	if string.sub(key, 1, 5) == "stat:" then
		local stat = string.sub(key, 6)
		local stats = type(data.stats) == "table" and data.stats or {}
		if stat == "RollCount" then
			return tonumber(data.RollCount) or 0
		elseif stat == "totalCoins" then
			return tonumber(data.totalCoins) or 0
		elseif stat == "skills" then
			return count(data.Skills)
		elseif stat == "index" then
			return count(data.index)
		elseif stat == "playtime" then
			return math.floor((tonumber(stats.playtime) or 0) / 60)
		end
		return tonumber(stats[stat]) or 0
	end
	local quests = type(data.Quests) == "table" and data.Quests or nil
	local counters = quests and type(quests.counters) == "table" and quests.counters or nil
	return counters and tonumber(counters[key]) or 0
end

------------------------------------------------------------------------
-- Défis permanents
------------------------------------------------------------------------

export type Reward = { coins: number?, gems: number?, items: { [string]: number }? }
export type Tier = { goal: number, reward: Reward }
export type Quest = {
	id: string,
	category: string, -- "univers" | "combat" | "progression" | "afk"
	universe: string?,
	rival: string?, -- perso de l'univers à affronter (défis de rivaux)
	title: string, -- « %s » est remplacé par l'objectif (ex. « Tue %s Kabouto »)
	icon: string,
	color: Color3,
	key: string,
	tiers: { Tier },
}

Quests.Categories = {
	{ id = "univers", name = "Univers", icon = "pin", color = rgb(255, 140, 40) },
	{ id = "combat", name = "Combat", icon = "sword", color = rgb(236, 60, 70) },
	{ id = "progression", name = "Progression", icon = "upgrade", color = rgb(70, 214, 96) },
	{ id = "afk", name = "Entraînement", icon = "punchbag", color = rgb(50, 214, 255) },
}

Quests.List = {} :: { Quest }
Quests.ById = {} :: { [string]: Quest }

local function tiers(goals: { number }, coins: { number }, gems: { number }, items: { [number]: { [string]: number } }?): { Tier }
	local list = {}
	for i, goal in goals do
		local reward: Reward = { coins = coins[i], gems = gems[i] }
		if items and items[i] then
			reward.items = items[i]
		end
		if reward.gems == 0 then
			reward.gems = nil
		end
		table.insert(list, { goal = goal, reward = reward })
	end
	return list
end

local function add(quest: Quest)
	table.insert(Quests.List, quest)
	Quests.ById[quest.id] = quest
end

-- Objets du marchand donnés aux derniers paliers des défis d'univers (identifiants de
-- Config/EvolutionItems ; un objet inconnu est remplacé par des pièces, voir QuestService).
Quests.UniverseItems = {
	ninja = { "ninja_parchemin", "ninja_secret", "ninja_interdit" },
	occulte = { "occ_talisman", "occ_doigt", "occ_prison" },
	saiyan = { "sai_capsule", "sai_boule_divine", "sai_dragon" },
	ocean = { "oce_bouteille", "oce_coffre", "oce_fruit" },
	pourfendeur = { "pou_garde", "pou_marque", "pou_lys" },
}
Quests.ItemFallbackCoins = { 4000, 15000, 60000 } -- pièces à la place d'un objet inconnu (par palier)

-- Défis de chaque univers : ses 3 ennemis (du plus faible au plus fort) et son boss.
for _, universe in Universes.List do
	local items = Quests.UniverseItems[universe.id] or {}
	local enemyPlans = {
		{ goals = { 50, 200, 1000 }, coins = { 300, 1000, 6000 }, gems = { 0, 1, 3 }, items = { [3] = items[1] and { [items[1]] = 1 } or nil } },
		{ goals = { 40, 150, 600 }, coins = { 600, 2500, 12000 }, gems = { 1, 2, 4 }, items = { [3] = items[2] and { [items[2]] = 1 } or nil } },
		{ goals = { 20, 80, 300 }, coins = { 1500, 6000, 25000 }, gems = { 1, 3, 6 }, items = { [3] = items[2] and { [items[2]] = 2 } or nil } },
	}
	-- Rivaux d'abord : « Tue 200 Kakashu » → 1 000 ¥ (premier défi du Village Ninja)
	for index, charId in Quests.rivalsFor(universe) do
		local def = Characters.List[charId]
		add({
			id = "u_" .. universe.id .. "_rival" .. index,
			category = "univers",
			universe = universe.id,
			rival = charId,
			title = "Tue %s " .. def.name,
			icon = "skull",
			color = universe.color,
			key = "kill:" .. charId,
			tiers = tiers({ 200, 600, 1500 }, { 1000, 6000, 25000 }, { 2, 4, 8 }, { [3] = items[2] and { [items[2]] = 1 } or nil }),
		})
	end
	for tier, enemyId in universe.enemies do
		local def = Characters.Enemies[enemyId]
		local plan = enemyPlans[tier]
		if def and plan then
			add({
				id = "u_" .. universe.id .. "_" .. tier,
				category = "univers",
				universe = universe.id,
				title = "Tue %s " .. Quests.plural(enemyId, def.name),
				icon = tier == 3 and "skull" or "sword",
				color = universe.color,
				key = "kill:" .. enemyId,
				tiers = tiers(plan.goals, plan.coins, plan.gems, plan.items),
			})
		end
	end
	local bossDef = Characters.Enemies[universe.boss]
	if bossDef then
		add({
			id = "u_" .. universe.id .. "_boss",
			category = "univers",
			universe = universe.id,
			title = "Bats " .. bossDef.name .. " %s fois",
			icon = "crown",
			color = universe.color,
			key = "boss:" .. universe.boss,
			tiers = tiers({ 1, 3, 10 }, { 5000, 15000, 60000 }, { 2, 4, 8 }, { [3] = items[3] and { [items[3]] = 1 } or nil }),
		})
	end
	add({
		id = "u_" .. universe.id .. "_all",
		category = "univers",
		universe = universe.id,
		title = "Tue %s ennemis dans l'univers " .. universe.name,
		icon = "target",
		color = universe.color,
		key = "killu:" .. universe.id,
		tiers = tiers({ 250, 1500, 6000 }, { 2000, 10000, 40000 }, { 1, 3, 6 }),
	})
end

-- Défis généraux.
local GENERAL = {
	{ "c_kill", "combat", "Tue %s ennemis", "sword", rgb(236, 60, 70), "kill", { 100, 500, 2000, 10000, 50000 }, { 800, 3000, 12000, 50000, 200000 }, { 1, 2, 4, 8, 15 } },
	{ "c_elite", "combat", "Tue %s ennemis d'élite (les plus forts)", "skull", rgb(200, 40, 60), "elite", { 25, 150, 800, 3000 }, { 2000, 9000, 40000, 150000 }, { 1, 3, 6, 12 } },
	{ "c_boss", "combat", "Bats %s boss", "crown", rgb(255, 190, 40), "boss", { 1, 5, 25, 100 }, { 4000, 20000, 90000, 300000 }, { 2, 4, 10, 20 } },
	{ "c_sword", "combat", "Tue %s ennemis avec ton épée", "sword", rgb(255, 140, 36), "swordkill", { 25, 250, 2000 }, { 1500, 10000, 60000 }, { 1, 3, 8 } },
	{
		"p_roll",
		"progression",
		"Roule %s fois à la machine",
		"dice",
		rgb(168, 78, 255),
		"stat:RollCount",
		{ 25, 100, 500, 2000, 10000 },
		{ 500, 2000, 10000, 40000, 150000 },
		{ 0, 1, 3, 6, 12 },
	},
	{ "p_collect", "progression", "Collecte %s persos", "unit", rgb(70, 214, 96), "stat:hatched", { 5, 25, 100, 400 }, { 1000, 5000, 20000, 80000 }, { 0, 1, 3, 6 } },
	{ "p_index", "progression", "Découvre %s persos différents", "book", rgb(230, 40, 90), "stat:index", { 5, 15, 30, 60 }, { 2000, 8000, 30000, 120000 }, { 1, 2, 4, 8 } },
	{ "p_evolve", "progression", "Fais évoluer %s persos", "evolve", rgb(150, 70, 255), "stat:evolutions", { 1, 5, 20, 60 }, { 3000, 12000, 50000, 150000 }, { 1, 3, 6, 10 } },
	{ "p_fuse", "progression", "Réalise %s fusions", "fusion", rgb(255, 80, 170), "stat:fusions", { 1, 5, 20 }, { 5000, 25000, 100000 }, { 2, 4, 8 } },
	{ "p_skill", "progression", "Débloque %s cases de l'arbre", "upgrade", rgb(240, 170, 30), "stat:skills", { 5, 20, 40, 56 }, { 2000, 10000, 40000, 150000 }, { 1, 2, 4, 8 } },
	{
		"p_coins",
		"progression",
		"Gagne %s pièces au total",
		"coin",
		rgb(255, 206, 64),
		"stat:totalCoins",
		{ 10000, 100000, 1000000, 10000000, 100000000 },
		{ 1000, 8000, 50000, 300000, 2000000 },
		{ 0, 1, 3, 6, 12 },
	},
	{ "p_reroll", "progression", "Relance %s traits", "gem", rgb(50, 214, 255), "reroll", { 5, 25, 100, 500 }, { 2000, 8000, 30000, 120000 }, { 1, 3, 6, 12 } },
	{ "p_trade", "progression", "Réussis %s échanges", "swap", rgb(60, 140, 240), "stat:trades", { 1, 10, 50 }, { 3000, 20000, 80000 }, { 1, 3, 6 } },
	{ "p_play", "progression", "Joue %s minutes", "hourglass", rgb(120, 200, 255), "stat:playtime", { 30, 120, 600, 3000 }, { 1500, 6000, 30000, 150000 }, { 1, 3, 6, 12 } },
	{ "a_punch", "afk", "Tape %s fois le punching-ball", "punchbag", rgb(50, 214, 255), "punch", { 1000, 5000, 20000, 100000 }, { 3000, 15000, 60000, 250000 }, { 2, 4, 8, 16 } },
	{ "a_gems", "afk", "Récolte %s gemmes de trait", "gem", rgb(80, 230, 255), "gems", { 10, 50, 250, 1000 }, { 2000, 10000, 50000, 200000 }, { 1, 3, 6, 12 } },
}
for _, g in GENERAL do
	add({
		id = g[1],
		category = g[2],
		title = g[3],
		icon = g[4],
		color = g[5],
		key = g[6],
		tiers = tiers(g[7], g[8], g[9]),
	})
end

-- Palier en cours d'un défi permanent (claimed = paliers déjà réclamés).
-- Renvoie : palier (ou nil si tout est fini), numéro, progression, objectif.
function Quests.status(data: any, quest: Quest): (Tier?, number, number, number)
	local claimed = 0
	local q = type(data) == "table" and type(data.Quests) == "table" and data.Quests or nil
	if q and type(q.claimed) == "table" then
		claimed = math.max(0, math.floor(tonumber(q.claimed[quest.id]) or 0))
	end
	local index = claimed + 1
	local tier = quest.tiers[index]
	local progress = Quests.read(data, quest.key)
	if not tier then
		local last = quest.tiers[#quest.tiers]
		return nil, #quest.tiers + 1, progress, last and last.goal or 0
	end
	return tier, index, progress, tier.goal
end

------------------------------------------------------------------------
-- Défis quotidiens
------------------------------------------------------------------------

export type Daily = {
	id: string,
	title: string,
	icon: string,
	color: Color3,
	key: string,
	goal: number,
	incomeMinutes: number?,
	reward: Reward,
}

Quests.DailyCount = 4
Quests.DailyPool = {
	{ id = "d_kill", title = "Tue %s ennemis", icon = "sword", color = rgb(236, 60, 70), key = "kill", goal = 150, reward = { coins = 2500, gems = 2 } },
	{ id = "d_elite", title = "Tue %s ennemis d'élite", icon = "skull", color = rgb(200, 40, 60), key = "elite", goal = 25, reward = { coins = 4000, gems = 2 } },
	{ id = "d_boss", title = "Bats %s boss", icon = "crown", color = rgb(255, 190, 40), key = "boss", goal = 1, reward = { coins = 5000, gems = 3 } },
	{ id = "d_sword", title = "Tue %s ennemis à l'épée", icon = "sword", color = rgb(255, 140, 36), key = "swordkill", goal = 40, reward = { coins = 3000, gems = 2 } },
	{ id = "d_roll", title = "Roule %s fois", icon = "dice", color = rgb(168, 78, 255), key = "stat:RollCount", goal = 40, reward = { coins = 2000, gems = 1 } },
	{ id = "d_collect", title = "Collecte %s persos", icon = "unit", color = rgb(70, 214, 96), key = "stat:hatched", goal = 6, reward = { coins = 2500, gems = 1 } },
	{ id = "d_punch", title = "Tape %s fois le punching-ball", icon = "punchbag", color = rgb(50, 214, 255), key = "punch", goal = 300, reward = { coins = 1500, gems = 2 } },
	{ id = "d_reroll", title = "Relance %s traits", icon = "gem", color = rgb(50, 214, 255), key = "reroll", goal = 5, reward = { coins = 3000, gems = 3 } },
	{
		id = "d_coins",
		title = "Gagne %s pièces",
		icon = "coin",
		color = rgb(255, 206, 64),
		key = "stat:totalCoins",
		goal = 50000,
		incomeMinutes = 20, -- objectif réel : 20 min du revenu du joueur au moment du tirage (≥ 50 000)
		reward = { coins = 5000, gems = 1 },
	},
	{ id = "d_play", title = "Joue %s minutes", icon = "hourglass", color = rgb(120, 200, 255), key = "stat:playtime", goal = 30, reward = { coins = 2000, gems = 2 } },
	{ id = "d_evolve", title = "Fais évoluer %s perso", icon = "evolve", color = rgb(150, 70, 255), key = "stat:evolutions", goal = 1, reward = { coins = 4000, gems = 2 } },
} :: { Daily }
Quests.DailyById = {} :: { [string]: Daily }
for _, daily in Quests.DailyPool do
	Quests.DailyById[daily.id] = daily
end
Quests.DailyBonus = { coins = 10000, gems = 5 } -- coffre quand les 4 défis du jour sont réclamés

-- Numéro du jour (UTC) et heure du prochain renouvellement.
function Quests.day(now: number): number
	return math.floor(now / 86400)
end
function Quests.nextReset(now: number): number
	return (Quests.day(now) + 1) * 86400
end

-- Les défis du jour d'un joueur : tirage stable (même jour + même joueur = mêmes défis).
function Quests.pickDaily(day: number, userId: number): { string }
	local rng = Random.new(day * 7919 + (userId % 100003) * 31 + 17)
	local pool = {}
	for _, daily in Quests.DailyPool do
		table.insert(pool, daily.id)
	end
	local picked = {}
	for _ = 1, math.min(Quests.DailyCount, #pool) do
		local index = rng:NextInteger(1, #pool)
		table.insert(picked, table.remove(pool, index))
	end
	return picked
end

-- Arrondi « joli » (2 chiffres significatifs) : 1 234 567 → 1 200 000.
function Quests.niceRound(n: number): number
	if n < 100 then
		return math.max(1, math.floor(n + 0.5))
	end
	local p = 10 ^ (math.floor(math.log10(n)) - 1)
	return math.floor(n / p + 0.5) * p
end

-- Objectif d'un défi du jour adapté au joueur au moment du tirage (défis de pièces : quelques
-- minutes de son revenu, pour qu'un joueur riche ne le réussisse pas instantanément).
function Quests.dailyGoalFor(daily: Daily, incomePerSec: number): number
	if daily.incomeMinutes then
		return math.max(daily.goal, Quests.niceRound((tonumber(incomePerSec) or 0) * 60 * daily.incomeMinutes))
	end
	return daily.goal
end

-- Progression d'un défi du jour (compteur actuel - valeur au début de la journée).
function Quests.dailyProgress(data: any, dailyId: string): (number, number)
	local daily = Quests.DailyById[dailyId]
	if not daily then
		return 0, 1
	end
	local q = type(data) == "table" and type(data.Quests) == "table" and data.Quests or nil
	local d = q and type(q.daily) == "table" and q.daily or nil
	local base = d and type(d.base) == "table" and tonumber(d.base[daily.key]) or 0
	local goal = d and type(d.goals) == "table" and tonumber(d.goals[dailyId]) or daily.goal
	return math.max(0, Quests.read(data, daily.key) - (base or 0)), math.max(1, goal or daily.goal)
end

local function dailyState(data: any)
	local q = type(data) == "table" and type(data.Quests) == "table" and data.Quests or nil
	local d = q and type(q.daily) == "table" and q.daily or nil
	local list = d and type(d.list) == "table" and d.list or {}
	local claimed = d and type(d.claimed) == "table" and d.claimed or {}
	return d, list, claimed
end

-- Défi du jour prêt à réclamer ?
function Quests.dailyReady(data: any, dailyId: string): boolean
	local _, list, claimed = dailyState(data)
	if not table.find(list, dailyId) or claimed[dailyId] then
		return false
	end
	local progress, goal = Quests.dailyProgress(data, dailyId)
	return progress >= goal
end

-- Coffre du jour prêt (les défis du jour sont tous réclamés) ?
function Quests.bonusReady(data: any): boolean
	local d, list, claimed = dailyState(data)
	if not d or d.bonus == true or #list == 0 then
		return false
	end
	for _, id in list do
		if not claimed[id] then
			return false
		end
	end
	return true
end

-- Défi permanent prêt à réclamer ?
function Quests.questReady(data: any, quest: Quest): boolean
	local tier, _, progress, goal = Quests.status(data, quest)
	return tier ~= nil and progress >= goal
end

-- Nombre de récompenses prêtes à réclamer (pastille du bouton Défis).
function Quests.readyCount(data: any, category: string?): number
	local n = 0
	if category == nil or category == "daily" then
		local _, list = dailyState(data)
		for _, id in list do
			if Quests.dailyReady(data, id) then
				n += 1
			end
		end
		if Quests.bonusReady(data) then
			n += 1
		end
	end
	for _, quest in Quests.List do
		if (category == nil or quest.category == category) and Quests.questReady(data, quest) then
			n += 1
		end
	end
	return n
end

------------------------------------------------------------------------
-- Affichage
------------------------------------------------------------------------

function Quests.formatNumber(n: number): string
	n = math.floor(n)
	if n >= 1e9 then
		return string.format("%.3g", n / 1e9):gsub("%.", ",") .. " Md"
	elseif n >= 1e6 then
		return string.format("%.3g", n / 1e6):gsub("%.", ",") .. " M"
	end
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^ ", ""))
end

function Quests.title(quest: { title: string }, goal: number): string
	return (string.gsub(quest.title, "%%s", Quests.formatNumber(goal)))
end

return Quests
