-- OBJETS D'ÉVOLUTION, lâchés par les ENNEMIS de la zone de combat (surtout au centre, voir
-- `Drops`) et vendus par le MARCHAND ambulant (pièces ¥).
-- Ils servent EXCLUSIVEMENT à faire évoluer les persos (★ → ★★ → ★★★), en plus du niveau, des
-- pièces et des matériaux que l'évolution demandait déjà.
--
-- • Chaque univers a 3 objets « de base » (palier 1, 2, 3) qui servent à tous ses persos.
-- • Les grands persos ont leur objet SIGNATURE : Goko a besoin d'une Boule du Dragon pour passer
--   Super Guerrier, Maruto d'un Parchemin d'Ermite puis du Chakra du Renard, Loffy d'un Fruit du
--   Démon, Tanjiru du Souffle du Soleil...
-- • Un perso qu'on ajoute plus tard (sans ligne dans `ByCharacter`) prend automatiquement les
--   objets de base de son univers : rien d'autre à faire.
--
-- Pour changer un prix, un nom ou ce que demande un perso : modifie les tables ci-dessous.

local Characters = require(script.Parent.Characters)

local rgb = Color3.fromRGB

local EvolutionItems = {}

-- Paliers d'objets : nom, couleur, quantité en stock par passage du marchand (par joueur),
-- poids dans le tirage du stock.
EvolutionItems.Tiers = {
	[1] = { name = "Commun", label = "COMMUN", color = rgb(64, 160, 255), stock = 5, weight = 10 },
	[2] = { name = "Rare", label = "RARE", color = rgb(176, 92, 255), stock = 3, weight = 6 },
	[3] = { name = "Légendaire", label = "LÉGENDAIRE", color = rgb(255, 190, 40), stock = 1, weight = 2.6 },
}

-- Majuscules françaises : string.upper ne touche pas aux lettres accentuées (« LéGENDAIRE »).
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
	{ "ç", "Ç" },
	{ "œ", "Œ" },
}
function EvolutionItems.upper(text: string): string
	local out = string.upper(text)
	for _, pair in ACCENTS do
		out = string.gsub(out, pair[1], pair[2])
	end
	return out
end

-- Le marchand ambulant : il change de coin (Layout.MerchantSpots) et renouvelle son stock toutes
-- les `Period` secondes (identique sur tous les serveurs).
EvolutionItems.Merchant = {
	Period = 8 * 60,
	Slots = 7, -- objets différents en vente à chaque passage
	BoostCurrentUniverse = 3, -- les objets de l'univers actuel sortent 3 fois plus souvent
	BuyDistance = 30, -- distance max (studs) pour acheter
	Color = rgb(214, 92, 255), -- couleur du rayon et de l'étiquette (violet magique)
	Color2 = rgb(255, 214, 120), -- liseré doré
}

-- Groupes de rareté des persos : « bas » (Commun, Rare) ou « haut » (Épique et plus).
local HIGH_RARITY = { epic = true, legendary = true, mythic = true, secret = true, crossover = true }

------------------------------------------------------------------------
-- Catalogue
------------------------------------------------------------------------
-- look.kind : forme du modèle 3D (voir « Modèles 3D » plus bas).

EvolutionItems.List = {
	-- VILLAGE NINJA
	{
		id = "ninja_parchemin",
		name = "Parchemin d'Entraînement",
		universe = "ninja",
		tier = 1,
		price = 1200,
		desc = "Techniques de base du village. Fait évoluer les ninjas Communs et Rares.",
		look = { kind = "scroll", color = rgb(70, 140, 230), accent = rgb(240, 220, 170) },
	},
	{
		id = "ninja_secret",
		name = "Parchemin Secret",
		universe = "ninja",
		tier = 2,
		price = 9000,
		desc = "Une technique secrète scellée. Pour les ninjas Épiques et plus.",
		look = { kind = "scroll", color = rgb(210, 40, 50), accent = rgb(245, 230, 190) },
	},
	{
		id = "ninja_interdit",
		name = "Parchemin Interdit",
		universe = "ninja",
		tier = 3,
		price = 60000,
		desc = "Le rouleau que personne ne doit ouvrir. Éveil ultime des grands ninjas.",
		look = { kind = "scroll", color = rgb(120, 40, 160), accent = rgb(255, 210, 70) },
	},
	{
		id = "ninja_ermite",
		name = "Parchemin d'Ermite",
		universe = "ninja",
		tier = 2,
		price = 18000,
		signature = true,
		desc = "Le pacte des crapauds du mont sacré : Maruto passe en Mode Ermite.",
		look = { kind = "scroll", color = rgb(230, 110, 30), accent = rgb(150, 210, 110) },
	},
	{
		id = "ninja_renard",
		name = "Chakra du Renard",
		universe = "ninja",
		tier = 3,
		price = 125000,
		signature = true,
		desc = "La flamme du démon renard à neuf queues. Éveil ★★★ de Maruto.",
		look = { kind = "flame", color = rgb(255, 80, 10), accent = rgb(255, 160, 40) },
	},
	{
		id = "ninja_oeil",
		name = "Œil du Clan",
		universe = "ninja",
		tier = 2,
		price = 15000,
		signature = true,
		desc = "L'œil rouge aux trois virgules. Éveille Sasuki, Kakashu et Itochi.",
		look = { kind = "eye", color = rgb(220, 20, 30), accent = rgb(20, 14, 16) },
	},
	{
		id = "ninja_oeil_eternel",
		name = "Œil Éternel",
		universe = "ninja",
		tier = 3,
		price = 150000,
		signature = true,
		desc = "La forme ultime de l'œil du clan. Éveil ★★★ de Sasuki et Itochi.",
		look = { kind = "eye", color = rgb(200, 10, 30), accent = rgb(10, 8, 12), eternal = true },
	},

	-- ACADÉMIE OCCULTE
	{
		id = "occ_talisman",
		name = "Talisman Scellé",
		universe = "occulte",
		tier = 1,
		price = 1200,
		desc = "Un sceau d'exorciste. Fait évoluer les exorcistes Communs et Rares.",
		look = { kind = "talisman", color = rgb(245, 235, 200), accent = rgb(200, 30, 40) },
	},
	{
		id = "occ_doigt",
		name = "Doigt Maudit",
		universe = "occulte",
		tier = 2,
		price = 10000,
		signature = true,
		desc = "Un doigt du Roi des Fléaux. Yuzi en a besoin… et Sukana en réclame plusieurs !",
		look = { kind = "finger", color = rgb(110, 70, 60), accent = rgb(60, 20, 30) },
	},
	{
		id = "occ_prison",
		name = "Coffret de la Prison",
		universe = "occulte",
		tier = 3,
		price = 60000,
		desc = "Un cube qui scelle n'importe quoi. Éveil ultime des grands exorcistes.",
		look = { kind = "box", color = rgb(60, 30, 80), accent = rgb(200, 160, 60) },
	},
	{
		id = "occ_bandeau",
		name = "Bandeau des Six Yeux",
		universe = "occulte",
		tier = 2,
		price = 20000,
		signature = true,
		desc = "Le bandeau qui retient un regard trop puissant. Éveil ★★ de Goju.",
		look = { kind = "blindfold", color = rgb(24, 24, 30), accent = rgb(120, 220, 255) },
	},
	{
		id = "occ_infini",
		name = "Fragment d'Infini",
		universe = "occulte",
		tier = 3,
		price = 140000,
		signature = true,
		desc = "Le bleu et le rouge réunis en violet. Éveil ★★★ de Goju.",
		look = { kind = "infinity", color = rgb(170, 70, 255), accent = rgb(80, 150, 255) },
	},

	-- PLANÈTE DES GUERRIERS
	{
		id = "sai_capsule",
		name = "Capsule d'Entraînement",
		universe = "saiyan",
		tier = 1,
		price = 1200,
		desc = "Une capsule pleine de matériel d'entraînement. Pour les guerriers Communs et Rares.",
		look = { kind = "capsule", color = rgb(245, 245, 245), accent = rgb(230, 50, 50) },
	},
	{
		id = "sai_haricot",
		name = "Haricot Magique",
		universe = "saiyan",
		tier = 2,
		price = 9000,
		desc = "Un seul haricot redonne toutes ses forces. Pour les guerriers Épiques et plus.",
		look = { kind = "bean", color = rgb(110, 190, 70), accent = rgb(170, 130, 80) },
	},
	{
		id = "sai_boule_divine",
		name = "Boule Divine",
		universe = "saiyan",
		tier = 3,
		price = 60000,
		desc = "Une sphère d'énergie divine. Éveil ultime des grands guerriers.",
		look = { kind = "orb", color = rgb(255, 230, 90), accent = rgb(255, 255, 255) },
	},
	{
		id = "sai_dragon",
		name = "Boule du Dragon",
		universe = "saiyan",
		tier = 2,
		price = 20000,
		signature = true,
		desc = "La boule à quatre étoiles. Goko passe SUPER GUERRIER (★★), comme Vejeta et Gohon.",
		look = { kind = "dragonball", color = rgb(255, 140, 20), accent = rgb(200, 20, 20), stars = 4 },
	},
	{
		id = "sai_ki_divin",
		name = "Ki Divin",
		universe = "saiyan",
		tier = 3,
		price = 150000,
		signature = true,
		desc = "L'aura des dieux de la destruction. Éveil ★★★ de Goko, Vejeta et Beeros.",
		look = { kind = "aura", color = rgb(70, 170, 255), accent = rgb(255, 255, 255) },
	},

	-- GRAND OCÉAN
	{
		id = "oce_bouteille",
		name = "Bouteille à la Mer",
		universe = "ocean",
		tier = 1,
		price = 1200,
		desc = "Une vieille carte au trésor. Pour les pirates Communs et Rares.",
		look = { kind = "bottle", color = rgb(120, 220, 200), accent = rgb(240, 225, 180) },
	},
	{
		id = "oce_coffre",
		name = "Coffre au Trésor",
		universe = "ocean",
		tier = 2,
		price = 9000,
		desc = "Un coffre plein d'or. Pour les pirates Épiques et plus.",
		look = { kind = "chest", color = rgb(140, 90, 50), accent = rgb(255, 200, 60) },
	},
	{
		id = "oce_fruit",
		name = "Fruit du Démon",
		universe = "ocean",
		tier = 3,
		price = 60000,
		signature = true,
		desc = "Un fruit aux spirales étranges. Loffy en a besoin pour son éveil ★★.",
		look = { kind = "fruit", color = rgb(150, 60, 200), accent = rgb(60, 160, 60) },
	},
	{
		id = "oce_haki",
		name = "Haki du Conquérant",
		universe = "ocean",
		tier = 3,
		price = 150000,
		signature = true,
		desc = "La volonté des rois. Éveil ★★★ de Loffy, et de Shonks.",
		look = { kind = "haki", color = rgb(30, 10, 30), accent = rgb(255, 40, 40) },
	},

	-- ÈRE DES POURFENDEURS
	{
		id = "pou_garde",
		name = "Garde de Sabre",
		universe = "pourfendeur",
		tier = 1,
		price = 1200,
		desc = "La garde d'un sabre de novice. Pour les pourfendeurs Communs et Rares.",
		look = { kind = "tsuba", color = rgb(60, 60, 70), accent = rgb(200, 170, 80) },
	},
	{
		id = "pou_marque",
		name = "Marque du Pourfendeur",
		universe = "pourfendeur",
		tier = 2,
		price = 10000,
		signature = true,
		desc = "La marque des plus grands épéistes. Pour les pourfendeurs Épiques et plus.",
		look = { kind = "crest", color = rgb(150, 20, 30), accent = rgb(250, 240, 220) },
	},
	{
		id = "pou_lys",
		name = "Lys Araignée Bleu",
		universe = "pourfendeur",
		tier = 3,
		price = 60000,
		desc = "La fleur que tous les démons cherchent. Éveil ultime des grands pourfendeurs.",
		look = { kind = "lily", color = rgb(60, 120, 255), accent = rgb(40, 120, 60) },
	},
	{
		id = "pou_soleil",
		name = "Souffle du Soleil",
		universe = "pourfendeur",
		tier = 3,
		price = 140000,
		signature = true,
		desc = "La première de toutes les respirations. Éveil ★★★ de Tanjiru, et de Yoriichu.",
		look = { kind = "flame", color = rgb(255, 70, 30), accent = rgb(255, 230, 120), sun = true },
	},

	-- TOUS LES UNIVERS (secours pour un perso sans univers connu)
	{
		id = "pierre_eveil",
		name = "Pierre d'Éveil",
		universe = nil,
		tier = 2,
		price = 12000,
		desc = "Un cristal neutre, utile à n'importe quel perso venu d'un autre monde.",
		look = { kind = "crystal", color = rgb(120, 230, 255), accent = rgb(255, 255, 255) },
	},
}

EvolutionItems.ById = {}
for index, item in EvolutionItems.List do
	item.order = index
	EvolutionItems.ById[item.id] = item
end

-- Objets de base de chaque univers (palier 1, 2, 3).
EvolutionItems.Universe = {
	ninja = { "ninja_parchemin", "ninja_secret", "ninja_interdit" },
	occulte = { "occ_talisman", "occ_doigt", "occ_prison" },
	saiyan = { "sai_capsule", "sai_haricot", "sai_boule_divine" },
	ocean = { "oce_bouteille", "oce_coffre", "oce_fruit" },
	pourfendeur = { "pou_garde", "pou_marque", "pou_lys" },
}
EvolutionItems.Fallback = "pierre_eveil"

-- BUTIN DES ENNEMIS (v3.4) : les ennemis de la zone de combat lâchent les objets d'évolution de
-- l'univers actif (le Marchand ambulant en vend toujours). Plus on va vers le centre, plus ils en
-- lâchent et plus ils sont rares ; le boss en donne à coup sûr.
--   chance = probabilité par ennemi vaincu ; picks = poids des paliers d'objets (1, 2, 3) et des
--   objets signature de l'univers (« signature »).
EvolutionItems.Drops = {
	[1] = { chance = 0.05, picks = { [1] = 1 } },
	[2] = { chance = 0.1, picks = { [1] = 0.5, [2] = 0.5 } },
	[3] = { chance = 0.18, picks = { [2] = 0.35, [3] = 0.4, signature = 0.25 } },
	boss = { count = 2, picks = { [3] = 0.5, signature = 0.5 } },
}

-- Objet lâché par un ennemi de l'univers `universeId` : `roll` et `pick` sont deux nombres tirés
-- dans [0, 1[ (le premier choisit le palier, le second l'objet signature).
function EvolutionItems.dropFor(universeId: string?, picks, roll: number, pick: number): string?
	local set = universeId and EvolutionItems.Universe[universeId]
	if not set or type(picks) ~= "table" then
		return nil
	end
	local total = 0
	for _, w in picks do
		total += w
	end
	local x = roll * total
	local choice = nil
	for _, key in { 1, 2, 3, "signature" } do
		local w = picks[key]
		if w then
			if x < w then
				choice = key
				break
			end
			x -= w
		end
	end
	choice = choice or 1
	if choice == "signature" then
		local signatures = EvolutionItems.signatures(universeId)
		if #signatures > 0 then
			return signatures[math.clamp(math.floor(pick * #signatures) + 1, 1, #signatures)]
		end
		choice = 3
	end
	return set[choice :: number]
end

-- Objets SIGNATURE : { [idDuPerso] = { [étoile visée] = { item, amount } } }.
EvolutionItems.ByCharacter = {
	ninja_maruto = { [2] = { item = "ninja_ermite", amount = 1 }, [3] = { item = "ninja_renard", amount = 1 } },
	ninja_sasuki = { [2] = { item = "ninja_oeil", amount = 1 }, [3] = { item = "ninja_oeil_eternel", amount = 1 } },
	ninja_kakashu = { [2] = { item = "ninja_oeil", amount = 1 } },
	ninja_itochi = { [2] = { item = "ninja_oeil", amount = 2 }, [3] = { item = "ninja_oeil_eternel", amount = 1 } },
	occ_yuzi = { [2] = { item = "occ_doigt", amount = 1 }, [3] = { item = "occ_doigt", amount = 3 } },
	occ_sukana = { [2] = { item = "occ_doigt", amount = 3 }, [3] = { item = "occ_doigt", amount = 6 } },
	occ_goju = { [2] = { item = "occ_bandeau", amount = 1 }, [3] = { item = "occ_infini", amount = 1 } },
	sai_goko = { [2] = { item = "sai_dragon", amount = 1 }, [3] = { item = "sai_ki_divin", amount = 1 } },
	sai_vejeta = { [2] = { item = "sai_dragon", amount = 1 }, [3] = { item = "sai_ki_divin", amount = 1 } },
	sai_gohon = { [2] = { item = "sai_dragon", amount = 1 } },
	sai_beeros = { [2] = { item = "sai_ki_divin", amount = 1 }, [3] = { item = "sai_ki_divin", amount = 2 } },
	oce_loffy = { [2] = { item = "oce_fruit", amount = 1 }, [3] = { item = "oce_haki", amount = 1 } },
	oce_shonks = { [2] = { item = "oce_haki", amount = 1 }, [3] = { item = "oce_haki", amount = 2 } },
	pou_tanjiru = { [2] = { item = "pou_marque", amount = 1 }, [3] = { item = "pou_soleil", amount = 1 } },
	pou_yoriichu = { [2] = { item = "pou_soleil", amount = 1 }, [3] = { item = "pou_soleil", amount = 2 } },
	-- Nouveaux persos v3.2 (Mythiques et Secrets)
	ninja_minatu = { [2] = { item = "ninja_interdit", amount = 1 }, [3] = { item = "ninja_renard", amount = 1 } },
	ninja_radama = { [2] = { item = "ninja_oeil", amount = 2 }, [3] = { item = "ninja_oeil_eternel", amount = 2 } },
	occ_toja = { [2] = { item = "occ_prison", amount = 1 }, [3] = { item = "occ_infini", amount = 1 } },
	occ_yuuto = { [2] = { item = "occ_doigt", amount = 2 }, [3] = { item = "occ_prison", amount = 2 } },
	sai_jirene = { [2] = { item = "sai_boule_divine", amount = 1 }, [3] = { item = "sai_ki_divin", amount = 1 } },
	sai_gojita = { [2] = { item = "sai_dragon", amount = 2 }, [3] = { item = "sai_ki_divin", amount = 2 } },
	oce_lao = { [2] = { item = "oce_fruit", amount = 1 }, [3] = { item = "oce_haki", amount = 1 } },
	oce_kaydo = { [2] = { item = "oce_fruit", amount = 2 }, [3] = { item = "oce_haki", amount = 2 } },
	pou_muzon = { [2] = { item = "pou_lys", amount = 2 }, [3] = { item = "pou_soleil", amount = 2 } },
	pou_doma = { [2] = { item = "pou_lys", amount = 1 }, [3] = { item = "pou_lys", amount = 2 } },
}

function EvolutionItems.get(id: string?)
	return id and EvolutionItems.ById[id] or nil
end

-- Objet demandé pour la PROCHAINE évolution d'un perso possédé ({ id, stars, fusion? }).
-- Retourne { item = idObjet, amount = n } ou nil (déjà ★★★ / perso inconnu).
function EvolutionItems.requirement(entry)
	if type(entry) ~= "table" then
		return nil
	end
	local nextStar = (entry.stars or 1) + 1
	if nextStar > 3 then
		return nil
	end
	local universeId, rarity
	if type(entry.fusion) == "table" then
		local a = Characters.get(entry.fusion.a)
		universeId = a and a.universe
		rarity = "crossover"
	else
		local override = EvolutionItems.ByCharacter[entry.id]
		if override and override[nextStar] then
			return { item = override[nextStar].item, amount = override[nextStar].amount }
		end
		local def = Characters.get(entry.id)
		if not def then
			return nil
		end
		universeId = def.universe
		rarity = def.rarity
	end
	local high = HIGH_RARITY[rarity or "common"] == true
	local tier = if nextStar == 2 then (high and 2 or 1) else (high and 3 or 2)
	local set = universeId and EvolutionItems.Universe[universeId]
	if not set then
		return { item = EvolutionItems.Fallback, amount = nextStar == 3 and 2 or 1 }
	end
	return { item = set[tier], amount = (nextStar == 3 and not high) and 2 or 1 }
end

-- Persos (identifiants) qui ont besoin de cet objet, pour l'expliquer dans les menus.
-- Persos qui demandent cet objet : { { id, stars = étoiles visées } }, triés par nom.
function EvolutionItems.usedByIds(itemId: string): { { id: string, stars: number } }
	local out = {}
	for charId in Characters.List do
		for star = 2, 3 do
			local need = EvolutionItems.requirement({ id = charId, stars = star - 1 })
			if need and need.item == itemId then
				table.insert(out, { id = charId, stars = star })
				break
			end
		end
	end
	table.sort(out, function(a, b)
		local na, nb = Characters.List[a.id].name, Characters.List[b.id].name
		if na == nb then
			return a.id < b.id
		end
		return na < nb
	end)
	return out
end

function EvolutionItems.usedBy(itemId: string): { string }
	local names, seen = {}, {}
	for charId, def in Characters.List do
		for star = 2, 3 do
			local need = EvolutionItems.requirement({ id = charId, stars = star - 1 })
			if need and need.item == itemId and not seen[charId] then
				seen[charId] = true
				table.insert(names, def.name)
			end
		end
	end
	table.sort(names)
	return names
end

------------------------------------------------------------------------
-- Passages du marchand (déterministes : identiques sur tous les serveurs)
------------------------------------------------------------------------

function EvolutionItems.window(now: number): number
	return math.floor(now / EvolutionItems.Merchant.Period)
end

-- Coin occupé pendant un passage : jamais deux fois de suite le même.
function EvolutionItems.spotIndex(window: number, count: number): number
	if count <= 1 then
		return 1
	end
	return ((window * 5 + math.floor(window / count)) % count) + 1
end

-- Objets signature d'un univers (hors objets de base déjà garantis), dans l'ordre du catalogue.
function EvolutionItems.signatures(universeId: string?): { string }
	local result = {}
	local set = universeId and EvolutionItems.Universe[universeId]
	if not set then
		return result
	end
	for _, item in EvolutionItems.List do
		if item.signature and item.universe == universeId and item.id ~= set[1] and item.id ~= set[2] then
			table.insert(result, item.id)
		end
	end
	return result
end

local function hashString(text: string?): number
	local h = 0
	for i = 1, #(text or "") do
		h = (h * 31 + string.byte(text :: string, i)) % 1000003
	end
	return h
end

-- Stock d'un passage : { { id, stock } } (stock par joueur). Les objets de base (palier 1 et 2)
-- de l'univers actuel sont toujours là ; le reste est tiré au sort.
function EvolutionItems.stock(window: number, universeId: string?)
	local rng = Random.new(window * 7919 + hashString(universeId) + 13)
	local chosen: { [string]: boolean } = {}
	local result = {}
	local function add(id: string)
		local item = EvolutionItems.ById[id]
		if item and not chosen[id] then
			chosen[id] = true
			table.insert(result, { id = id, stock = EvolutionItems.Tiers[item.tier].stock })
		end
	end
	local set = universeId and EvolutionItems.Universe[universeId]
	if set then
		add(set[1])
		add(set[2])
	end
	-- Objets SIGNATURE de l'univers actuel : toujours au moins un en vente (deux si l'univers en a
	-- 3 ou plus), et ils tournent d'un passage à l'autre. Exemple : en univers Guerriers, la Boule
	-- du Dragon revient un passage sur deux.
	local signatures = EvolutionItems.signatures(universeId)
	if #signatures > 0 then
		local count = #signatures >= 3 and 2 or 1
		for k = 0, count - 1 do
			add(signatures[((window * count + k) % #signatures) + 1])
		end
	end
	local merchant = EvolutionItems.Merchant
	while #result < merchant.Slots do
		local total, pool = 0, {}
		for _, item in EvolutionItems.List do
			if not chosen[item.id] then
				local weight = EvolutionItems.Tiers[item.tier].weight
				if item.universe == nil then
					weight *= 0.4
				elseif item.universe == universeId then
					weight *= merchant.BoostCurrentUniverse
				end
				total += weight
				table.insert(pool, { id = item.id, weight = weight })
			end
		end
		if total <= 0 then
			break
		end
		local roll = rng:NextNumber() * total
		local picked = pool[#pool].id
		for _, option in pool do
			roll -= option.weight
			if roll <= 0 then
				picked = option.id
				break
			end
		end
		add(picked)
	end
	-- Ordre d'affichage : palier puis catalogue.
	table.sort(result, function(a, b)
		local ia, ib = EvolutionItems.ById[a.id], EvolutionItems.ById[b.id]
		if ia.tier ~= ib.tier then
			return ia.tier < ib.tier
		end
		return ia.order < ib.order
	end)
	return result
end

------------------------------------------------------------------------
-- Modèles 3D des objets (menus, étagères du marchand)
------------------------------------------------------------------------
-- Modèle centré en (0, 0, 0), posé à y = 0, environ 2,5 studs de haut. Pièces ancrées.

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local NEON = Enum.Material.Neon
local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder
local FACE = CFrame.Angles(0, math.rad(90), 0) -- cylindre tourné vers -Z (disque de face)
local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylindre vertical

local function newContext(model: Model, s: number)
	local ctx = {}
	function ctx.add(name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size * s
		part.CFrame = CFrame.new(cf.Position * s) * cf.Rotation
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		if props then
			local target: any = part
			for key, value in props do
				target[key] = value
			end
		end
		part.Parent = model
		return part
	end
	-- Étoile à 8 branches (deux carrés croisés), face -Z.
	function ctx.star(name: string, size: number, cf: CFrame, color: Color3)
		ctx.add(name, Vector3.new(size, size, 0.06), cf, color, { Material = NEON })
		ctx.add(name, Vector3.new(size, size, 0.06), cf * CFrame.Angles(0, 0, math.rad(45)), color, { Material = NEON })
	end
	-- Petit coussin de présentation (velours) sous l'objet.
	function ctx.cushion(color: Color3)
		ctx.add("Cushion", Vector3.new(0.5, 2.2, 2.2), CFrame.new(0, 0.25, 0) * UP, color, { Shape = CYL, Material = Enum.Material.Fabric })
		ctx.add("CushionTrim", Vector3.new(0.12, 2.28, 2.28), CFrame.new(0, 0.46, 0) * UP, rgb(230, 190, 80), { Shape = CYL, Material = Enum.Material.Fabric })
	end
	return ctx
end

local KINDS = {}

-- Boule du Dragon : sphère de verre orange vif, étoiles rouges bien nettes collées à la surface,
-- petit reflet arrondi, coussin de velours.
KINDS.dragonball = function(ctx, look)
	ctx.cushion(rgb(150, 30, 40))
	local center = CFrame.new(0, 1.45, 0)
	ctx.add("Orb", Vector3.new(2.1, 2.1, 2.1), center, look.color, { Shape = BALL, Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.15 })
	-- Lueur intérieure très légère (la boule reste orange franc, pas une tache floue).
	ctx.add("Core", Vector3.new(1.5, 1.5, 1.5), center, lighten(look.color, 0.35), { Shape = BALL, Material = NEON, Transparency = 0.9 })
	local positions = {
		[1] = { Vector2.new(0, 0) },
		[2] = { Vector2.new(-0.3, 0.2), Vector2.new(0.3, -0.2) },
		[3] = { Vector2.new(0, 0.36), Vector2.new(-0.34, -0.22), Vector2.new(0.34, -0.22) },
		[4] = { Vector2.new(0, 0.46), Vector2.new(-0.46, 0), Vector2.new(0.46, 0), Vector2.new(0, -0.46) },
	}
	for _, p in positions[math.clamp(look.stars or 4, 1, 4)] do
		-- Posée juste sur la surface du verre (rayon 1,05), à plat, pour rester nette.
		local z = -math.sqrt(math.max(0, 1.06 * 1.06 - p.X * p.X - p.Y * p.Y))
		local spot = Vector3.new(p.X, p.Y, z)
		ctx.star("Star", 0.4, center * CFrame.lookAt(Vector3.zero, spot) * CFrame.new(0, 0, -spot.Magnitude), look.accent)
	end
	-- Reflet : petit ovale blanc, en haut à gauche.
	local shine = ctx.add(
		"Shine",
		Vector3.new(0.5, 0.3, 0.1),
		center * CFrame.new(-0.48, 0.55, -0.78) * CFrame.Angles(0.5, -0.45, math.rad(30)),
		rgb(255, 255, 255),
		{ Material = NEON, Transparency = 0.4 }
	)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = shine
end

-- Œil du clan : médaillon doré, iris rouge, pupille, virgules (ou motif « éternel »).
KINDS.eye = function(ctx, look)
	ctx.add("Stand", Vector3.new(1.4, 0.3, 0.9), CFrame.new(0, 0.15, 0), rgb(70, 46, 34), { Material = Enum.Material.Wood })
	ctx.add("StandPost", Vector3.new(0.3, 0.5, 0.3), CFrame.new(0, 0.5, 0.1), rgb(70, 46, 34), { Material = Enum.Material.Wood })
	local center = CFrame.new(0, 1.55, 0)
	ctx.add("Frame", Vector3.new(0.3, 2.3, 2.3), center * FACE * CFrame.new(0, 0, 0), rgb(214, 170, 70), { Shape = CYL, Material = Enum.Material.Metal })
	ctx.add("White", Vector3.new(0.34, 2.0, 2.0), center * FACE, rgb(250, 246, 240), { Shape = CYL })
	ctx.add("Ring", Vector3.new(0.36, 1.6, 1.6), center * FACE, look.accent, { Shape = CYL })
	ctx.add("Iris", Vector3.new(0.38, 1.45, 1.45), center * FACE, look.color, { Shape = CYL, Material = NEON })
	ctx.add("Pupil", Vector3.new(0.42, 0.42, 0.42), center * FACE, look.accent, { Shape = CYL })
	if look.eternal then
		for i = 0, 2 do
			local a = i * math.pi * 2 / 3
			ctx.add("Blade", Vector3.new(0.62, 0.16, 0.08), center * CFrame.Angles(0, 0, a) * CFrame.new(0.38, 0, -0.22) * CFrame.Angles(0, 0, 0.5), look.accent)
			ctx.add("BladeTip", Vector3.new(0.3, 0.12, 0.08), center * CFrame.Angles(0, 0, a) * CFrame.new(0.62, 0.16, -0.22) * CFrame.Angles(0, 0, 1.2), look.accent)
		end
	else
		ctx.add("InnerRing", Vector3.new(0.4, 1.0, 1.0), center * FACE, darken(look.color, 0.25), { Shape = CYL, Transparency = 0.5 })
		for i = 0, 2 do
			local a = i * math.pi * 2 / 3 + 0.4
			local p = Vector3.new(math.cos(a) * 0.5, math.sin(a) * 0.5, -0.22)
			ctx.add("Tomoe", Vector3.new(0.24, 0.24, 0.08), center * CFrame.new(p), look.accent, { Shape = BALL })
			ctx.add("TomoeTail", Vector3.new(0.22, 0.08, 0.08), center * CFrame.new(p) * CFrame.Angles(0, 0, a + 1.9) * CFrame.new(0.12, 0.02, 0), look.accent)
		end
	end
end

-- Flamme (Chakra du Renard, Souffle du Soleil) dans une coupe de bronze.
KINDS.flame = function(ctx, look)
	ctx.add("Foot", Vector3.new(0.3, 1.4, 1.4), CFrame.new(0, 0.15, 0) * UP, rgb(70, 52, 40), { Shape = CYL, Material = Enum.Material.Metal })
	ctx.add("Stem", Vector3.new(0.7, 0.4, 0.4), CFrame.new(0, 0.6, 0) * UP, rgb(150, 110, 60), { Shape = CYL, Material = Enum.Material.Metal })
	ctx.add("Bowl", Vector3.new(0.5, 1.9, 1.9), CFrame.new(0, 1.05, 0) * UP, rgb(170, 120, 60), { Shape = CYL, Material = Enum.Material.Metal })
	ctx.add("BowlRim", Vector3.new(0.12, 2.0, 2.0), CFrame.new(0, 1.3, 0) * UP, rgb(230, 190, 90), { Shape = CYL, Material = Enum.Material.Metal })
	local layers = {
		{ 1.5, 1.2, 1.7, look.color, 0.1 },
		{ 1.1, 1.5, 1.95, lighten(look.color, 0.2), 0.05 },
		{ 0.7, 1.3, 2.2, look.accent, 0 },
		{ 0.35, 0.8, 2.75, rgb(255, 255, 230), 0 },
	}
	for _, layer in layers do
		local part = ctx.add("Flame", Vector3.new(layer[1], layer[2], layer[1]), CFrame.new(0, layer[3], 0), layer[4], { Material = NEON, Transparency = layer[5] })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	-- Langues de flamme (les queues du renard / les rayons du soleil).
	local tongues = look.sun and 8 or 5
	for i = 1, tongues do
		local a = i * math.pi * 2 / tongues
		local tongue = ctx.add(
			"Tongue",
			Vector3.new(0.3, 1.0, 0.3),
			CFrame.new(math.cos(a) * 0.55, 2.2, math.sin(a) * 0.55) * CFrame.Angles(math.sin(a) * 0.5, 0, -math.cos(a) * 0.5),
			look.color,
			{ Material = NEON, Transparency = 0.15 }
		)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = tongue
	end
	if look.sun then
		ctx.add("SunRing", Vector3.new(0.1, 2.6, 2.6), CFrame.new(0, 2.2, 0.3) * FACE, look.accent, { Shape = CYL, Material = NEON, Transparency = 0.6 })
	end
end

-- Bandeau des Six Yeux : bande noire nouée autour d'un support, deux pans, lueur bleue.
KINDS.blindfold = function(ctx, look)
	ctx.cushion(rgb(60, 70, 110))
	-- Buste de porcelaine (tête blanche) qui porte le bandeau noir, la lueur des Six Yeux dessous.
	local center = CFrame.new(0, 1.55, 0)
	ctx.add("Head", Vector3.new(1.75, 1.75, 1.75), center, rgb(246, 244, 240), { Shape = BALL })
	ctx.add("Hair", Vector3.new(1.85, 0.9, 1.85), center * CFrame.new(0, 0.55, 0.06), rgb(236, 240, 250), { Shape = BALL })
	ctx.add("Band", Vector3.new(0.5, 1.84, 1.84), center * CFrame.new(0, 0.08, 0) * UP, look.color, { Shape = CYL, Material = Enum.Material.Fabric })
	for _, side in { -1, 1 } do
		ctx.add(
			"Tail",
			Vector3.new(0.32, 1.1, 0.08),
			center * CFrame.new(side * 0.22, -0.45, 0.95) * CFrame.Angles(0.3, 0, side * 0.35),
			look.color,
			{ Material = Enum.Material.Fabric }
		)
		ctx.star("Spark", 0.24, center * CFrame.new(side * 0.34, -0.3, -0.82), look.accent)
	end
	ctx.add("Knot", Vector3.new(0.4, 0.4, 0.3), center * CFrame.new(0, 0.08, 0.92), darken(look.color, 0.2), { Material = Enum.Material.Fabric })
end

-- Fragment d'Infini : sphère violette en verre entre une bille bleue et une bille rouge.
KINDS.infinity = function(ctx, look)
	ctx.add("Base", Vector3.new(0.35, 1.6, 1.6), CFrame.new(0, 0.18, 0) * UP, rgb(40, 34, 60), { Shape = CYL, Material = Enum.Material.Slate })
	local center = CFrame.new(0, 1.5, 0)
	ctx.add("Orb", Vector3.new(1.7, 1.7, 1.7), center, look.color, { Shape = BALL, Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.2 })
	ctx.add("Core", Vector3.new(1.1, 1.1, 1.1), center, lighten(look.color, 0.3), { Shape = BALL, Material = NEON, Transparency = 0.2 })
	ctx.add("Blue", Vector3.new(0.6, 0.6, 0.6), center * CFrame.new(-1.15, 0.2, 0), look.accent, { Shape = BALL, Material = NEON })
	ctx.add("Red", Vector3.new(0.6, 0.6, 0.6), center * CFrame.new(1.15, -0.2, 0), rgb(255, 60, 70), { Shape = BALL, Material = NEON })
	for i = 0, 11 do
		local a = i * math.pi / 6
		ctx.add(
			"Ring",
			Vector3.new(0.5, 0.06, 0.06),
			center * CFrame.Angles(0.35, 0, 0) * CFrame.new(math.cos(a) * 1.25, 0, math.sin(a) * 1.25) * CFrame.Angles(0, -a + math.pi / 2, 0),
			rgb(230, 210, 255),
			{
				Material = NEON,
				Transparency = 0.3,
			}
		)
	end
end

-- Haricot magique : petite bourse en tissu et trois haricots.
KINDS.bean = function(ctx, look)
	local sack = ctx.add("Pouch", Vector3.new(1.5, 1.5, 1.4), CFrame.new(0.3, 0.75, 0.4), look.accent, { Material = Enum.Material.Fabric })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = sack
	ctx.add("PouchNeck", Vector3.new(0.5, 0.6, 0.6), CFrame.new(0.3, 1.55, 0.4) * UP, darken(look.accent, 0.15), { Shape = CYL, Material = Enum.Material.Fabric })
	ctx.add("PouchTie", Vector3.new(0.14, 0.66, 0.66), CFrame.new(0.3, 1.45, 0.4) * UP, rgb(200, 60, 50), { Shape = CYL, Material = Enum.Material.Fabric })
	for i, p in { Vector3.new(-0.7, 0.3, -0.5), Vector3.new(-0.15, 0.3, -0.75), Vector3.new(-0.6, 0.72, -0.25) } do
		local bean = ctx.add("Bean", Vector3.new(0.75, 0.5, 0.5), CFrame.new(p) * CFrame.Angles(0, i * 0.9, 0.2), look.color)
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = bean
	end
end

-- Haki du Conquérant : sphère noire entourée d'éclairs rouges.
KINDS.haki = function(ctx, look)
	ctx.add("Base", Vector3.new(0.35, 1.5, 1.5), CFrame.new(0, 0.18, 0) * UP, rgb(60, 20, 24), { Shape = CYL, Material = Enum.Material.Slate })
	local center = CFrame.new(0, 1.5, 0)
	ctx.add("Shell", Vector3.new(2.0, 2.0, 2.0), center, rgb(80, 20, 70), { Shape = BALL, Material = Enum.Material.Glass, Transparency = 0.45 })
	ctx.add("Core", Vector3.new(1.4, 1.4, 1.4), center, look.color, { Shape = BALL, Material = Enum.Material.SmoothPlastic })
	local rng = Random.new(7)
	for i = 1, 7 do
		local a = i * math.pi * 2 / 7
		local r = 1.05
		local p = Vector3.new(math.cos(a) * r, rng:NextNumber(-0.7, 0.7), math.sin(a) * r)
		ctx.add("Bolt", Vector3.new(0.08, 0.7, 0.08), center * CFrame.new(p) * CFrame.Angles(0, -a, rng:NextNumber(-0.8, 0.8)), look.accent, { Material = NEON })
		ctx.add(
			"Bolt",
			Vector3.new(0.07, 0.45, 0.07),
			center * CFrame.new(p + Vector3.new(0, 0.42, 0)) * CFrame.Angles(0, -a, rng:NextNumber(-1.4, 1.4)),
			look.accent,
			{ Material = NEON }
		)
	end
end

-- Marque du Pourfendeur : médaillon rouge, caractère blanc « 滅 » stylisé, gland doré.
KINDS.crest = function(ctx, look)
	ctx.add("Stand", Vector3.new(1.4, 0.3, 0.9), CFrame.new(0, 0.15, 0), rgb(60, 40, 30), { Material = Enum.Material.Wood })
	local center = CFrame.new(0, 1.5, 0)
	ctx.add("Rim", Vector3.new(0.24, 2.3, 2.3), center * FACE, rgb(30, 24, 26), { Shape = CYL, Material = Enum.Material.Wood })
	ctx.add("Plate", Vector3.new(0.3, 2.0, 2.0), center * FACE, look.color, { Shape = CYL, Material = Enum.Material.Wood })
	local strokes = {
		{ -0.42, 0.35, 0.12, 0.5, 0.3 },
		{ -0.5, 0.0, 0.12, 0.45, -0.2 },
		{ -0.45, -0.38, 0.12, 0.45, 0.5 },
		{ 0.15, 0.48, 0.9, 0.1, 0 },
		{ 0.1, 0.0, 0.12, 0.95, 0 },
		{ 0.3, 0.12, 0.6, 0.1, 0 },
		{ 0.35, -0.22, 0.12, 0.6, 0.4 },
		{ 0.05, -0.28, 0.5, 0.1, -0.5 },
	}
	for _, s in strokes do
		ctx.add("Stroke", Vector3.new(s[3], s[4], 0.06), center * CFrame.new(s[1], s[2], -0.17) * CFrame.Angles(0, 0, s[5]), look.accent)
	end
	ctx.add("Cord", Vector3.new(0.08, 0.6, 0.08), center * CFrame.new(0, -1.25, 0), rgb(230, 190, 80), { Material = Enum.Material.Fabric })
end

-- Pierre d'Éveil : trois éclats de cristal.
KINDS.crystal = function(ctx, look)
	ctx.add("Rock", Vector3.new(1.6, 0.45, 1.3), CFrame.new(0, 0.22, 0), rgb(90, 86, 96), { Material = Enum.Material.Slate })
	local shards = { { 0, 1.2, 0, 0.7, 1.9, 0 }, { -0.5, 0.85, 0.15, 0.5, 1.2, 0.45 }, { 0.5, 0.8, -0.1, 0.45, 1.0, -0.5 } }
	for _, s in shards do
		ctx.add("Shard", Vector3.new(s[4], s[5], s[4]), CFrame.new(s[1], s[2], s[3]) * CFrame.Angles(0, math.rad(45), s[6]), look.color, {
			Material = Enum.Material.Glass,
			Transparency = 0.2,
			Reflectance = 0.2,
		})
		ctx.add("ShardCore", Vector3.new(s[4] * 0.45, s[5] * 0.8, s[4] * 0.45), CFrame.new(s[1], s[2], s[3]) * CFrame.Angles(0, math.rad(45), s[6]), look.accent, {
			Material = NEON,
			Transparency = 0.3,
		})
	end
end

-- Aura divine : orbe de ki bleu avec anneaux d'énergie.
KINDS.aura = function(ctx, look)
	ctx.add("Base", Vector3.new(0.35, 1.5, 1.5), CFrame.new(0, 0.18, 0) * UP, rgb(40, 50, 80), { Shape = CYL, Material = Enum.Material.Slate })
	local center = CFrame.new(0, 1.5, 0)
	ctx.add("Aura", Vector3.new(2.1, 2.1, 2.1), center, look.color, { Shape = BALL, Material = NEON, Transparency = 0.6 })
	ctx.add("Orb", Vector3.new(1.4, 1.4, 1.4), center, lighten(look.color, 0.3), { Shape = BALL, Material = NEON, Transparency = 0.15 })
	ctx.add("Core", Vector3.new(0.7, 0.7, 0.7), center, look.accent, { Shape = BALL, Material = NEON })
	for k, tilt in { 0.5, -0.5 } do
		for i = 0, 9 do
			local a = i * math.pi / 5 + k
			ctx.add(
				"Ring",
				Vector3.new(0.6, 0.07, 0.07),
				center * CFrame.Angles(tilt, 0, tilt * 0.6) * CFrame.new(math.cos(a) * 1.2, 0, math.sin(a) * 1.2) * CFrame.Angles(0, -a + math.pi / 2, 0),
				look.accent,
				{
					Material = NEON,
					Transparency = 0.25,
				}
			)
		end
	end
end

function EvolutionItems.build(itemId: string, scale: number?): Model
	local item = EvolutionItems.ById[itemId] or EvolutionItems.ById[EvolutionItems.Fallback]
	local s = scale or 1
	local builder = KINDS[item.look.kind]
	local model
	if builder then
		model = Instance.new("Model")
		local ctx = newContext(model, s)
		local root = ctx.add("Root", Vector3.new(1, 1, 1), CFrame.new(0, 1.2, 0), Color3.new(1, 1, 1), { Transparency = 1 })
		model.PrimaryPart = root
		builder(ctx, item.look)
	else
		-- Formes partagées avec les anciennes reliques (parchemin, doigt, capsule, fruit...).
		local RelicBuilder = require(script.Parent.Parent.Modules.RelicBuilder)
		model = RelicBuilder.build(item.look, item.tier, s)
	end
	model.Name = "Item_" .. item.id
	model:SetAttribute("ItemId", item.id)
	if item.tier >= 2 and model.PrimaryPart and not model.PrimaryPart:FindFirstChildOfClass("PointLight") then
		local light = Instance.new("PointLight")
		light.Color = item.look.color
		light.Brightness = item.tier == 3 and 2.5 or 1.2
		light.Range = 8 * s
		light.Parent = model.PrimaryPart
	end
	return model
end

return EvolutionItems
